--!strict
--[[
	KineticParkourController.luau — ORCHESTRATOR (bản "The Accessible Flow" — tối giản).

	Chỉ còn 2 cơ chế cho game thủ casual:
	  • Power Slide [C]
	  • Wall Run (TỰ ĐỘNG khi nhảy sát tường lúc có đà) + Wall Jump [Space]
	cùng locomotion Walk F / Sprint F.

	Vai trò: lắng nghe CharacterAdded → dựng Session mỗi nhân vật (dọn sạch khi respawn qua Sweeper);
	nhận Input; chạy 1 vòng lặp RenderStepped duy nhất. Logic vật lý ở các module con.
	Mọi thông số game feel ở ParkourConfig.luau.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sweeper = require(ReplicatedStorage.Packages.Janitor) -- gói "Janitor" thực chất là Sweeper

local ParkourConfig = require(script.Parent.ParkourConfig)
local ParkourTypes = require(script.Parent.ParkourTypes)
local ParkourAnimator = require(script.Parent.ParkourAnimator)
local ParkourSlide = require(script.Parent.ParkourSlide)
local ParkourBrake = require(script.Parent.ParkourBrake)

type Session = ParkourTypes.Session

local States = ParkourConfig.States
local Keys = ParkourConfig.Keys
local GamepadKeys = ParkourConfig.GamepadKeys

local localPlayer = Players.LocalPlayer

local KineticParkourController = {}

-- Session của nhân vật hiện tại (nil khi chưa spawn / đã chết).
local currentSession: Session? = nil

-- ─────────────────────────────────────────────────────────────────────
-- DỰNG SESSION cho 1 nhân vật
-- ─────────────────────────────────────────────────────────────────────
local function buildSession(character: Model): Session
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = humanoid:WaitForChild("Animator") :: Animator

	local sweeper = Sweeper.new()

	-- Attachment gốc dùng chung cho mọi constraint vật lý.
	local attachment = Instance.new("Attachment")
	attachment.Name = "ParkourRoot"
	attachment.Parent = root
	sweeper:Add(attachment, "Destroy")

	-- Cast qua any để bỏ qua các field instance sẽ gán trong Setup.
	local session: Session = ({
		player = localPlayer,
		character = character,
		humanoid = humanoid,
		root = root,
		animator = animator,
		janitor = sweeper,

		state = States.Grounded,
		attachment = attachment,
		tracks = {},

		sprinting = false,
		originalRunAnimId = nil,
		originalWalkAnimId = nil,

		slideSpeed = 0,
		slideInitialSpeed = 0,
		slideDir = Vector3.zero,
		slideStartClock = 0,
		slideEndClock = 0,
		lastSlideClock = 0,
		originalHipHeight = humanoid.HipHeight,
		wallGuardUntil = 0,

		wallNormal = Vector3.zero,
		wallSide = 0,
		wallRunActiveTime = 0,
		wallRunClingTime = 0,
		wallRunStartClock = 0,
		lastWallSide = 0,
		lastWallDetachClock = 0,
		originalAutoRotate = humanoid.AutoRotate,
	} :: any) :: Session

	-- Khởi tạo từng cơ chế (tạo constraint, nạp anim, set giá trị mặc định).
	ParkourAnimator.Setup(session)
	ParkourSlide.Setup(session)
	ParkourBrake.Setup(session)

	-- Tự động kích hoạt leo (climbing state) lập tức và triệt tiêu đà ngang khi lao vào Obby Stair ở tốc độ cao
	local lastJumpTime = 0
	local jumpConn = humanoid.Jumping:Connect(function()
		lastJumpTime = os.clock()
	end)
	sweeper:Add(jumpConn)

	local function onTouched(hit)
		if hit.Name == "Obby Stair" and hit:IsA("TrussPart") then
			if os.clock() - lastJumpTime > 0.5 then
				if humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
					humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
					root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
				end
			end
		end
	end

	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") then
			local conn = part.Touched:Connect(onTouched)
			sweeper:Add(conn)
		end
	end

	return session
end

local function disposeSession()
	if currentSession then
		currentSession.janitor:Sweep()
		currentSession = nil
	end
end

local function onCharacterAdded(character: Model)
	disposeSession()
	currentSession = buildSession(character)
end

-- ─────────────────────────────────────────────────────────────────────
-- INPUT
-- ─────────────────────────────────────────────────────────────────────
local function handleAction(action: string)
	local session = currentSession
	if not session then
		return
	end

	if action == "Slide" then
		if ParkourSlide.CanStart(session) then
			ParkourSlide.Begin(session)
		end
	end
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return -- bỏ qua khi đang gõ chat / thao tác UI
	end
	local kc = input.KeyCode

	if kc == Keys.Slide or kc == GamepadKeys.Slide then
		handleAction("Slide")
	end
end

-- ─────────────────────────────────────────────────────────────────────
-- VÒNG LẶP CHÍNH (mỗi frame)
-- ─────────────────────────────────────────────────────────────────────
local function onRenderStepped(dt: number)
	local session = currentSession
	if not session then
		return
	end
	-- Nhân vật đã chết / bị xóa → bỏ qua (chờ respawn).
	if not session.character.Parent or session.humanoid.Health <= 0 then
		return
	end

	-- Nền: cập nhật anim Sprint/Walk theo WalkSpeed.
	ParkourAnimator.UpdateSprint(session)

	-- Active Braking + Grip + Turn Assist + Anti-Fling (tự bỏ qua khi không Grounded).
	ParkourBrake.Update(session, dt)

	-- Cập nhật cơ chế đang active; nếu đang Grounded + trên không thì thử bám tường.
	local state = session.state
	if state == States.Sliding then
		ParkourSlide.Update(session, dt)
	end
end

-- ─────────────────────────────────────────────────────────────────────
-- LIFECYCLE
-- ─────────────────────────────────────────────────────────────────────
function KineticParkourController.Start()
	localPlayer.CharacterAdded:Connect(onCharacterAdded)
	localPlayer.CharacterRemoving:Connect(disposeSession)

	-- Nếu nhân vật đã tồn tại trước khi controller chạy.
	if localPlayer.Character then
		task.spawn(onCharacterAdded, localPlayer.Character)
	end

	UserInputService.InputBegan:Connect(onInputBegan)
	RunService.RenderStepped:Connect(onRenderStepped)

	print("[KineticParkour] The Accessible Flow — Slide [C] + Active Braking (Wall Run/Jump disabled)")
end

return KineticParkourController
