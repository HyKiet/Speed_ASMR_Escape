--!strict
--[[
	Zone4BossController.luau — vẽ MonkeyBoss ở đúng FPS của máy người chơi.

	── VẤN ĐỀ (user hỏi 2026-08-27: "có cách nào cho MonkeyBoss chạy 60fps không") ──────────
	Bản cũ để server `PivotTo` con boss 30 lần mỗi giây. Nhưng part NEO do script dời thì
	client KHÔNG nội suy — nó NHẢY thẳng tới giá trị mới mỗi khi gói replicate tới, và gói đó
	đi theo nhịp gửi của MẠNG, không theo nhịp server cũng không theo nhịp hình.

	Nên câu trả lời cho "nâng server lên 60Hz" là: KHÔNG ăn thua. Client vẫn nhận chừng ấy
	gói, nhìn y hệt, chỉ tốn gấp đôi băng thông và CPU. Ở ping 350–400ms của game thì càng tệ.

	── CÁCH LÀM ────────────────────────────────────────────────────────────────────────────
	Tách AUTHORITY khỏi HÌNH, giống mọi bẫy khác trong game:
	  • `Zone4BossService` giữ 30Hz, vẫn quyết định boss ở đâu và ai chết, và công bố một
	    CFrame duy nhất qua attribute `BossCF`.
	  • Controller này NỘI SUY MƯỢT tới `BossCF` mỗi RenderStepped.

	CHỈ GHI `HumanoidRootPart.CFrame`, không đụng 8 part còn lại: chúng nối vào root bằng
	Motor6D và do Animator đặt tư thế mỗi frame. Ghi thẳng CFrame của tay/chân là ĐÁNH NHAU
	với animator — rig sẽ giật hoặc rã ra.

	── VÌ SAO LÀ NỘI SUY MŨ, KHÔNG PHẢI LERP THEO dt ───────────────────────────────────────
	`alpha = 1 - exp(-k·dt)` độc lập với framerate: máy 30fps và máy 144fps hội tụ cùng một
	tốc độ theo THỜI GIAN THẬT. Viết `lerp(cur, goal, 0.2)` thẳng thì máy 144fps đuổi kịp
	nhanh gấp 5 lần máy 30fps — cùng một con boss chạy hai tốc độ khác nhau trên hai máy.

	Hằng số thời gian 1/SMOOTH_K ≈ 55ms: đủ để nuốt trọn khoảng cách giữa hai gói mạng, mà
	vẫn bám sát boss thật trong ~3 studs ở tốc độ 56 studs/s. Trễ thêm 55ms này KHÔNG làm
	người chơi chết oan vì server phán xử chạm theo LỊCH SỬ có bù trễ (xem LagComp trong
	Zone4BossService) — hai thứ được thiết kế cùng nhau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local ZoneLod = require(script.Parent.ZoneLod)

local Zone4BossController = {}

-- Bán kính SÀN. Tầm thức thật do `ZoneLod.RadiusSq` quyết định theo WalkSpeed/tầm nhìn.
-- Arena rộng ~270×355 studs nên 400 phủ trọn kể cả khi đứng ở góc xa nhất.
local RENDER_RADIUS = 400
local RESOLVE_INTERVAL = 0.5

--[[
	Hệ số hội tụ (1/giây). 18 ⇒ hằng số thời gian ~55ms.

	⚠️ HỢP ĐỒNG: `Zone4BossService.VISUAL_SMOOTH_LAG` phải luôn bằng `1 / SMOOTH_K`. Server
	dùng nó để lùi thêm ngần ấy giây khi phán xử chạm, vì bộ lọc này làm hình người chơi thấy
	CHẬM hơn boss thật đúng `1/k` giây (sai số xác lập của lọc mũ bám mục tiêu đi đều = v/k).
	Đổi số ở đây mà quên sửa bên kia là boss giết lệch — đúng loại lỗi khó lần ra nhất.
]]
local SMOOTH_K = 18
-- Lệch hơn ngần này thì NHẢY thẳng thay vì nội suy: đó là boss vừa được đặt về nhà, vừa
-- respawn, hoặc client vừa stream zone về. Nội suy qua một khoảng như thế sẽ cho ra cảnh con
-- khỉ trượt ngang cả arena.
local SNAP_DISTANCE = 40

local bossModel: Model? = nil
local bossRoot: BasePart? = nil
local visualCF: CFrame? = nil

local function resolve()
	bossModel = nil
	bossRoot = nil
	visualCF = nil

	local zones = Workspace:FindFirstChild("Zones")
	local zone4 = zones and zones:FindFirstChild("Zone4")
	local mechanics = zone4 and zone4:FindFirstChild("Mechanics")
	local model = mechanics and mechanics:FindFirstChild("MonkeyBoss")
	if not model or not model:IsA("Model") then
		return
	end
	if model:GetAttribute("BossReady") ~= true then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	bossModel = model
	bossRoot = root
	-- Bắt đầu từ chỗ boss ĐANG được server công bố, không phải từ `root.CFrame`: dưới
	-- StreamingEnabled part có thể vừa về tới ở tư thế cũ.
	local goal = model:GetAttribute("BossCF")
	visualCF = if typeof(goal) == "CFrame" then goal else root.CFrame
end

local function alive(): boolean
	local root = bossRoot
	return root ~= nil and root:IsDescendantOf(Workspace)
end

local function step(dt: number)
	if not alive() then
		return
	end
	local model = bossModel :: Model
	local root = bossRoot :: BasePart

	local goal = model:GetAttribute("BossCF")
	if typeof(goal) ~= "CFrame" then
		return
	end

	-- Ngoài tầm: ghim thẳng vào tư thế server công bố MỘT LẦN rồi thôi. Không nội suy cho
	-- thứ không ai nhìn, nhưng cũng không để nó đứng chết ở tư thế dở dang.
	if not ZoneLod.Root() then
		return
	end
	local pos = ZoneLod.RootPosition()
	local dx = pos.X - goal.Position.X
	local dz = pos.Z - goal.Position.Z
	if dx * dx + dz * dz > ZoneLod.RadiusSq(RENDER_RADIUS) then
		if visualCF ~= goal then
			visualCF = goal
			root.CFrame = goal
		end
		return
	end

	local current = visualCF or goal
	if (goal.Position - current.Position).Magnitude > SNAP_DISTANCE then
		current = goal
	else
		-- Độc lập framerate — xem khối lý do ở đầu file.
		current = current:Lerp(goal, 1 - math.exp(-SMOOTH_K * dt))
	end

	visualCF = current
	root.CFrame = current
end

function Zone4BossController.Init() end

function Zone4BossController.Start()
	RunService.RenderStepped:Connect(step)

	task.spawn(function()
		while true do
			if not alive() then
				resolve()
			end
			task.wait(RESOLVE_INTERVAL)
		end
	end)

	Log.Boot("[Zone4BossController] boss nội suy mượt theo FPS máy (server 30Hz vẫn giữ quyền)")
end

return Zone4BossController
