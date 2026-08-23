--!strict
--[[
	MovementController.luau — ORCHESTRATOR của hệ di chuyển.

	Thay thế toàn bộ thư mục Parkour/ cũ. Bốn lý do phải VIẾT LẠI chứ không vá tiếp:

	  1. SAI PHA. Bản cũ chạy mọi phép kẹp vận tốc trên RenderStepped — tức là TRƯỚC bước
	     physics của cùng khung hình. Kẹp xong thì physics ghi đè ngay, nên cú hất DO va
	     chạm sinh ra không bao giờ bị chặn. Bản này xử lý ở Heartbeat, tức SAU bước
	     physics — chỗ duy nhất đọc được kết quả va chạm thật.

	  2. TRANH QUYỀN GHI. Năm hệ (TurnAssist, Grip, WallGuard, constraint phanh, constraint
	     slide) cùng đọc-ghi AssemblyLinearVelocity trong một khung hình, không có thứ tự
	     ưu tiên. Kết quả phụ thuộc thứ tự gọi → giật và khó tinh chỉnh. Nay mỗi pha
	     đọc-sửa-ghi đúng một lần, thứ tự viết rõ trong MovementStabilizer.

	  3. RÁC GC. `MakeRaycastParams` dựng RaycastParams mới + duyệt toàn bộ Players ở MỖI
	     lần quét, 2 lần/khung hình, 60Hz. Nay params nằm trong session và chỉ dựng lại
	     khi có người vào/ra.

	  4. CODE CHẾT. WallRun/WallJump đã tắt nhưng vẫn còn nguyên config, 8 trường trong
	     Session, và các trường animation locomotion không ai dùng.

	Cấu trúc: mỗi nhân vật một Session (dọn sạch bằng Sweeper khi respawn), và ĐÚNG MỘT
	vòng lặp Heartbeat. Không có vòng RenderStepped (không gì cần nhịp render) và không
	có vòng Stepped (không can thiệp gì trước va chạm — game này sống bằng tốc độ, ghì
	player lúc đang tới gần vật thể là hỏng cảm giác).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Sweeper = require(ReplicatedStorage.Packages.Janitor) -- gói "Janitor" thực chất là Sweeper

local MovementAnimator = require(script.Parent.MovementAnimator)
local MovementConfig = require(script.Parent.MovementConfig)
local MovementSlide = require(script.Parent.MovementSlide)
local MovementStabilizer = require(script.Parent.MovementStabilizer)
local MovementTypes = require(script.Parent.MovementTypes)
local MovementUtil = require(script.Parent.MovementUtil)

type Session = MovementTypes.Session

local States = MovementConfig.States
local Keys = MovementConfig.Keys
local GamepadKeys = MovementConfig.GamepadKeys

local localPlayer = Players.LocalPlayer

local MovementController = {}

local currentSession: Session? = nil

-- ─────────────────────────────────────────────────────────────────────
-- CHỐNG NGÃ
-- ─────────────────────────────────────────────────────────────────────
--[[
	Xem khối lý do dài trong `MovementConfig.AntiTopple`. Tóm tắt: ở 100–250 WS, Humanoid
	hay rơi vào `FallingDown`/`Ragdoll` rồi phải bò dậy — tắt hẳn mấy trạng thái đó là
	nhân vật không còn đường nào để nằm xuống. Chết vẫn chết bình thường (`Dead` không
	nằm trong danh sách).

	Chạy lại cho MỖI nhân vật: `SetStateEnabled` gắn với instance Humanoid nên respawn là
	mất, và accessory có thể đến SAU character (đó là lý do có `DescendantAdded`).
]]
local function applyAntiTopple(session: Session)
	local cfg = MovementConfig.AntiTopple
	if not cfg.Enabled then
		return
	end

	local humanoid = session.humanoid
	for _, state in cfg.DisabledStates do
		humanoid:SetStateEnabled(state, false)
	end

	-- Lưới an toàn: nếu có script nào (hoặc engine) vẫn ép được vào trạng thái nằm, kéo
	-- dậy ngay trong frame đó thay vì để người chơi xem hoạt ảnh bò dậy 2 giây.
	session.sweeper:Add(humanoid.StateChanged:Connect(function(_, new: Enum.HumanoidStateType)
		if new == Enum.HumanoidStateType.FallingDown or new == Enum.HumanoidStateType.Ragdoll then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		elseif new == Enum.HumanoidStateType.PlatformStanding then
			humanoid.PlatformStand = false
		end
	end))

	if not cfg.MasslessAccessories then
		return
	end
	-- Khối lượng của mũ/cánh/ba lô nằm cao trên trục = cánh tay đòn làm lật người.
	local function lighten(instance: Instance)
		if instance:IsA("BasePart") and instance.Parent and instance.Parent:IsA("Accessory") then
			instance.Massless = true
		end
	end
	for _, descendant in session.character:GetDescendants() do
		lighten(descendant)
	end
	session.sweeper:Add(session.character.DescendantAdded:Connect(lighten))
end

-- ─────────────────────────────────────────────────────────────────────
-- SESSION
-- ─────────────────────────────────────────────────────────────────────
local function buildSession(character: Model): Session
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = humanoid:WaitForChild("Animator") :: Animator

	local sweeper = Sweeper.new()

	local attachment = Instance.new("Attachment")
	attachment.Name = "MovementRoot"
	attachment.Parent = root
	sweeper:Add(attachment, "Destroy")

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	-- Chỉ vật cản VẬT LÝ THẬT mới tính là tường: part CanCollide=false (cổng thuỷ tinh
	-- Zone 13, tường năng lượng Zone 5 — thứ để đâm xuyên) không được cắt đà.
	rayParams.RespectCanCollide = true

	local session: Session = (
		{
			player = localPlayer,
			character = character,
			humanoid = humanoid,
			root = root,
			animator = animator,
			sweeper = sweeper,

			state = States.Grounded,
			attachment = attachment,
			tracks = {},

			rayParams = rayParams,
			rayParamsDirty = true,

			slideSpeed = 0,
			slideInitialSpeed = 0,
			slideDir = Vector3.zero,
			slideStartClock = 0,
			slideEndClock = 0,
			lastSlideClock = -math.huge,
			originalHipHeight = humanoid.HipHeight,

			lastVelocity = root.AssemblyLinearVelocity,
			lastJumpClock = -math.huge,
		} :: any
	) :: Session

	MovementUtil.RebuildRayParams(session)
	MovementAnimator.Setup(session)
	MovementSlide.Setup(session)
	applyAntiTopple(session)

	-- Lao vào Obby Stair ở tốc độ cao thì bật ngay trạng thái leo + triệt tiêu đà ngang,
	-- nếu không nhân vật bị TrussPart hất ngược ra.
	-- `lastJumpClock` nằm trong session vì MovementStabilizer cũng cần nó (miễn trừ cú
	-- nhảy khỏi phép kẹp "bật cóc khi đang bám đất").
	sweeper:Add(humanoid.Jumping:Connect(function()
		session.lastJumpClock = os.clock()
	end))

	local function onTouched(hit: BasePart)
		if hit.Name ~= "Obby Stair" or not hit:IsA("TrussPart") then
			return
		end
		if os.clock() - session.lastJumpClock <= 0.5 then
			return -- vừa nhảy: đừng cướp quyền điều khiển giữa không trung
		end
		if humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
			humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
	end

	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			sweeper:Add(part.Touched:Connect(onTouched))
		end
	end

	return session
end

local function disposeSession()
	if currentSession then
		currentSession.sweeper:Sweep()
		currentSession = nil
	end
end

local function onCharacterAdded(character: Model)
	disposeSession()
	currentSession = buildSession(character)
end

-- Nhân vật còn sống và còn trong Workspace?
local function activeSession(): Session?
	local session = currentSession
	if not session then
		return nil
	end
	if not session.character.Parent or session.humanoid.Health <= 0 then
		return nil
	end
	return session
end

-- ─────────────────────────────────────────────────────────────────────
-- INPUT
-- ─────────────────────────────────────────────────────────────────────
--[[
	CỬA VÀO DUY NHẤT của lệnh slide. Phím [C], nút L3 tay cầm và nút SLIDE cảm ứng
	(`Movement/MobileSlideButton`) đều đi qua đây — kiểm tra điều kiện nằm ở MỘT chỗ, không
	có bản copy nào lệch pha khi `MovementSlide.CanStart` đổi luật.

	Trả về `true` nếu cú slide thật sự bắt đầu, để nút cảm ứng biết có nên nháy phản hồi hay
	không (bấm lúc đang cooldown / đang trên không thì nút phải im, không "ăn" cú bấm rồi
	chẳng có gì xảy ra).
]]
function MovementController.TrySlide(): boolean
	local session = activeSession()
	if session and MovementSlide.CanStart(session) then
		MovementSlide.Begin(session)
		return true
	end
	return false
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return -- đang gõ chat / bấm UI
	end
	local kc = input.KeyCode
	if kc ~= Keys.Slide and kc ~= GamepadKeys.Slide then
		return
	end
	MovementController.TrySlide()
end

-- ─────────────────────────────────────────────────────────────────────
-- LIFECYCLE
-- ─────────────────────────────────────────────────────────────────────
function MovementController.Start()
	localPlayer.CharacterAdded:Connect(onCharacterAdded)
	localPlayer.CharacterRemoving:Connect(disposeSession)
	if localPlayer.Character then
		task.spawn(onCharacterAdded, localPlayer.Character)
	end

	-- Bộ lọc raycast phải loại trừ mọi nhân vật khác; đánh dấu bẩn khi danh sách đổi
	-- thay vì dựng lại mỗi khung hình.
	local function markDirty()
		if currentSession then
			currentSession.rayParamsDirty = true
		end
	end
	Players.PlayerAdded:Connect(markDirty)
	Players.PlayerRemoving:Connect(markDirty)
	for _, other in Players:GetPlayers() do
		other.CharacterAdded:Connect(markDirty)
	end
	Players.PlayerAdded:Connect(function(other)
		other.CharacterAdded:Connect(markDirty)
	end)

	UserInputService.InputBegan:Connect(onInputBegan)

	-- MỘT vòng lặp duy nhất, chạy SAU bước physics. Không còn pha trước-physics: mọi
	-- can thiệp đều là sửa kết quả va chạm đã xảy ra, không bao giờ ghì player lúc
	-- đang tới gần vật thể.
	RunService.Heartbeat:Connect(function(dt: number)
		local session = activeSession()
		if not session then
			return
		end
		MovementStabilizer.PostStep(session, dt)
		if session.state == States.Sliding then
			MovementSlide.Update(session, dt)
		end
	end)

	print(
		"[Movement] Hệ di chuyển — Slide [C], giảm nhẹ cú văng hậu va chạm, chống bật cóc + chống ngã (1 vòng Heartbeat)"
	)
end

return MovementController
