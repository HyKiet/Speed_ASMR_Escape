--!strict
--[[
	Zone3CrusherController.luau — render local 6 máy ép Stage 3.

	Server không dời piston (xem Zone3CrusherService): vị trí suy ra từ
	`workspace:GetServerTimeNow()` nên mọi client thấy y hệt nhau mà không tốn băng thông.
	Piston vẫn `CanCollide = true` — nhân vật do chính client mô phỏng nên vẫn bị đẩy/ép
	đúng như hình đang thấy.

	Cull một lần cho cả cụm: 6 máy ép nằm gọn trong 140 studs nên dùng chung một tâm là đủ
	(khác Zone 15 trải 3.800 studs phải cull theo từng cụm).

	── TIẾNG MÁY ÉP (2026-08-11) ─────────────────────────────────────────────────────────
	Máy ép trước đây CÂM: người chơi chỉ đọc được nhịp bằng mắt, mà lúc chạy 200+ WS thì mắt
	đang dán vào lối đi phía trước chứ không nhìn piston. Tiếng nện cho họ nghe được nhịp
	trước cả khi nhìn thấy máy.

	Tiếng cũng suy từ ĐỒNG HỒ như vị trí piston (không có event từ server, không có Touched):
	mỗi frame so pha chu kỳ của frame trước với frame này, thấy vượt qua mốc `SlamTime` thì
	nện, vượt mốc kết thúc giữ ép thì rít hơi thu về.

	Ba chi tiết đắt giá:
	  • CHỈ piston "_Left" của mỗi cặp phát tiếng. Hai piston đối diện nhau vài chục studs
	    phát CÙNG một mẫu chỉ lệch vài ms sẽ cộng pha thành tiếng méo (xem docs/AUDIO.md).
	  • Sound sống SẴN trên piston, không dựng lại mỗi nhịp: gán `SoundId` ngay trước `Play()`
	    làm tiếng ra trễ vài trăm ms — ở tốc độ của game này là trễ vài chục studs.
	  • Vừa vào tầm (`awake` từ false → true) thì KHÔNG phát ngay: chưa có pha của frame trước
	    để so, phát bừa sẽ thành tiếng nện lạc nhịp đúng lúc người chơi mới nhìn thấy máy.

	Volume viết cứng ở đây là đúng ý đồ — `AudioMixController` tự nhận nuôi mọi Sound trong
	Workspace vào kênh `sfx` rồi nhân hệ số slider lên trên.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Zone3Crushers = require(ReplicatedStorage.Shared.Config.Zones.Zone3Crushers)
local ZoneLod = require(script.Parent.ZoneLod)

-- Bán kính SÀN. Tầm thức thật do `ZoneLod.RadiusSq` quyết định theo WalkSpeed (ở 250 WS là
-- 800 studs) — xem lời giải thích trong ZoneLod.
local RENDER_RADIUS = 320
local RESOLVE_INTERVAL = 0.5

-- Cả hai ID đã ĐO trong Studio 2026-08-11 (IsLoaded = true, đúng loại Audio):
--   9116771817  "Metal Pops Denting Car In Out 2" — 1.51s, cú nện kim loại nặng, đục.
--   119819642430931 "door_piston_sound"          — 1.44s, tiếng hơi/piston cho lúc thu về.
local SLAM_SOUND_ID = "rbxassetid://9116771817"
local HISS_SOUND_ID = "rbxassetid://119819642430931"

local SLAM_VOLUME = 0.7
local HISS_VOLUME = 0.32
-- Nghe rõ khi tới gần nhưng không đè lên tiếng sàn ASMR ở stage bên cạnh.
local ROLLOFF_MIN = 28
local ROLLOFF_MAX = 240

local Zone3CrusherController = {}

type Crusher = {
	piston: BasePart,
	rot: CFrame,
	group: number,
	startX: number,
	endX: number,
	y: number,
	z: number,
	slam: Sound?,
	hiss: Sound?,
}

local crushers: { Crusher } = {}
local centerX, centerZ = 0, 0
local awake = false
local nextFarStep = 0
local connection: RBXScriptConnection? = nil

-- Pha chu kỳ của frame TRƯỚC, theo từng nhóm. nil = chưa có gì để so (vừa vào tầm).
local lastPhase: { [number]: number? } = {}

-- Dựng sẵn một giọng cố định trên piston. Đã có rồi (resolve chạy lại) thì dùng lại luôn.
local function ensureSound(piston: BasePart, name: string, id: string, volume: number, pitch: number): Sound
	local existing = piston:FindFirstChild(name)
	if existing and existing:IsA("Sound") then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = ROLLOFF_MIN
	sound.RollOffMaxDistance = ROLLOFF_MAX
	sound.Parent = piston
	return sound
end

-- Pha chạy vòng 0..Cycle, nên "đã vượt mốc" phải xét cả trường hợp vừa quay vòng.
local function crossed(prev: number, now: number, mark: number): boolean
	if now < prev then
		return mark > prev or mark <= now
	end
	return mark > prev and mark <= now
end

local function resolve()
	table.clear(crushers)

	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone3")
	local mechanics = zone and zone:FindFirstChild("Mechanics")
	local folder = mechanics and mechanics:FindFirstChild(Zone3Crushers.FolderName)
	if not folder then
		return
	end

	local sumX, sumZ = 0, 0
	for _, model in folder:GetChildren() do
		local group = model:GetAttribute("GroupIndex")
		local piston = model:FindFirstChild("Piston")
		local startX = model:GetAttribute("StartX")
		local endX = model:GetAttribute("EndX")
		local pistonY = model:GetAttribute("PistonY")

		if
			typeof(group) == "number"
			and piston
			and piston:IsA("BasePart")
			and typeof(startX) == "number"
			and typeof(endX) == "number"
		then
			--[[
				Chỉ piston TRÁI của mỗi cặp mang giọng — phải cũng nện thì hai bản sao cùng
				mẫu lệch vài ms sẽ cộng pha thành tiếng méo (docs/AUDIO.md). Lệch pitch nhẹ
				theo tên cặp để ba cặp không nghe như một mẫu lặp lại y hệt.
			]]
			local isLead = string.find(model.Name, "_Left", 1, true) ~= nil
			local slam: Sound? = nil
			local hiss: Sound? = nil
			if isLead then
				local pitch = 0.94 + 0.05 * (#crushers % 3)
				slam = ensureSound(piston, "Zone3CrusherSlam", SLAM_SOUND_ID, SLAM_VOLUME, pitch)
				hiss = ensureSound(piston, "Zone3CrusherHiss", HISS_SOUND_ID, HISS_VOLUME, pitch)
			end

			-- Piston chỉ trượt dọc X: Y/Z lấy từ attribute + vị trí gốc nên KHÔNG bị trôi
			-- dù controller đã dời part (khác trục X, không đọc lại bao giờ).
			table.insert(crushers, {
				piston = piston,
				rot = piston.CFrame.Rotation,
				group = group,
				startX = startX,
				endX = endX,
				y = if typeof(pistonY) == "number" then pistonY else piston.Position.Y,
				z = piston.Position.Z,
				slam = slam,
				hiss = hiss,
			})
			sumX += (startX + endX) * 0.5
			sumZ += piston.Position.Z
		end
	end

	-- Thiếu máy ép nào đó (streaming nạp lẻ) → bỏ hết, lượt poll sau thử lại.
	local expected = 0
	for _ in Zone3Crushers.GroupOf do
		expected += 1
	end
	if #crushers ~= expected then
		table.clear(crushers)
		return
	end

	centerX, centerZ = sumX / #crushers, sumZ / #crushers
end

local function alive(): boolean
	return #crushers > 0 and crushers[1].piston:IsDescendantOf(Workspace)
end

local function step()
	if not alive() then
		return
	end

	-- Gốc nhân vật tra MỘT lần mỗi frame cho cả bảy controller bẫy, không phải mỗi
	-- controller một lần `FindFirstChild` — xem `ZoneLod.Root`.
	if not ZoneLod.Root() then
		return
	end
	local pos = ZoneLod.RootPosition()
	local dx, dz = pos.X - centerX, pos.Z - centerZ
	local distSq = dx * dx + dz * dz
	if distSq > ZoneLod.RadiusSq(RENDER_RADIUS) then
		-- SLEEP: đưa piston về đúng tư thế nghỉ MỘT LẦN rồi thôi động vào part nữa,
		-- tránh cảnh máy ép đứng chết cứng giữa nhịp khi nhìn từ xa.
		if awake then
			awake = false
			table.clear(lastPhase)
			for i = 1, #crushers do
				local c = crushers[i]
				c.piston.CFrame = CFrame.new(c.startX, c.y, c.z) * c.rot
				if c.slam then
					c.slam:Stop()
				end
				if c.hiss then
					c.hiss:Stop()
				end
			end
		end
		return
	end
	awake = true

	local now = ZoneLod.Now()
	local shouldStep: boolean
	shouldStep, nextFarStep = ZoneLod.ShouldStepFar(distSq, now, nextFarStep)
	if not shouldStep then
		return
	end

	for i = 1, #crushers do
		local c = crushers[i]
		local x = Zone3Crushers.PistonX(now, c.group, c.startX, c.endX)
		c.piston.CFrame = CFrame.new(x, c.y, c.z) * c.rot
	end

	--[[
		Tiếng: mốc NỆN là lúc piston chạm đáy (hết `SlamTime`), mốc RÍT HƠI là lúc bắt đầu
		thu về (hết `HoldTime`). Tính pha một lần cho mỗi NHÓM rồi mới duyệt piston — cả
		nhóm ép cùng lúc nên chúng phải dùng chung một phép so, không so lẻ từng cái.
	]]
	local slamMark = Zone3Crushers.SlamTime
	local hissMark = Zone3Crushers.SlamTime + Zone3Crushers.HoldTime
	for group, start in Zone3Crushers.GroupStart do
		local phase = (now - start) % Zone3Crushers.Cycle
		local prev = lastPhase[group]
		lastPhase[group] = phase
		if prev == nil then
			continue -- vừa vào tầm: chờ frame sau mới có gì để so
		end

		local hitSlam = crossed(prev, phase, slamMark)
		local hitHiss = crossed(prev, phase, hissMark)
		if not hitSlam and not hitHiss then
			continue
		end

		for i = 1, #crushers do
			local c = crushers[i]
			if c.group == group then
				if hitSlam and c.slam then
					c.slam:Play()
				end
				if hitHiss and c.hiss then
					c.hiss:Play()
				end
			end
		end
	end
end

function Zone3CrusherController.Init() end

function Zone3CrusherController.Start()
	connection = RunService.RenderStepped:Connect(step)

	task.spawn(function()
		while true do
			if not alive() then
				resolve()
			end
			task.wait(RESOLVE_INTERVAL)
		end
	end)
end

function Zone3CrusherController.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return Zone3CrusherController
