--!strict
--[[
	Zone10RisingBlockController.luau — TIẾNG cho khối lava dâng/rơi trong tháp Stage 10.

	── VÌ SAO CẦN ───────────────────────────────────────────────────────────────────────
	Bẫy Zone 10 là một khối lava lấp gần trọn lòng tháp, dâng lên 220 studs/s rồi RƠI xuống
	350 studs/s. Nó vốn hoàn toàn CÂM: người chơi đang leo, camera chúi lên trên, khối rơi từ
	phía trên đầu xuống mà không có một dấu hiệu nào ngoài hình ảnh — mà đúng lúc đó mắt họ
	đang bận tìm chỗ đặt chân. Chết kiểu đó đọc ra là "game ăn gian", không phải "mình dở".

	Tiếng ở đây làm đúng một việc: cho biết khối đang ở PHA nào mà không cần nhìn.
	  • RỀN (loop) — khối đang di chuyển. To dần theo tốc độ nên lúc rơi nghe khác lúc dâng.
	  • HÚ dâng — khối vừa rời đáy, sắp đuổi lên.
	  • HÚ rơi (trầm hơn, to hơn) — khối vừa rời đỉnh. Đây là cảnh báo QUAN TRỌNG NHẤT: sau
	    tiếng này người chơi có chưa tới một giây để thoát khỏi lòng tháp.
	  • NỆN — khối chạm đáy. Đóng nhịp, cho biết chu kỳ mới bắt đầu.

	── VÌ SAO Ở CLIENT, VÀ VÌ SAO ĐỌC VỊ TRÍ THAY VÌ NGHE EVENT ─────────────────────────
	Khối do một Script trong map dời (Zones.Zone10.Mechanics.Zone10RisingKillBlockScript) —
	một part Anchored được server đặt lại Position mỗi Heartbeat, nên vị trí của nó ĐÃ replicate
	sẵn về mọi client. Suy pha từ chính vị trí đó thì không cần thêm một packet nào, và không
	phải sửa script trong map (script đó không nằm trong git — xem tools/zone10_risingkill_inline.luau).

	⚠️ Bẫy này KHÔNG chạy theo đồng hồ tất định như Zone 3/8: script trong map cho khối NGỦ khi
	không có ai trong bán kính 260 và reset về đáy. Vì thế không thể tính pha bằng công thức —
	phải đo chuyển động thật của part.

	Volume viết cứng là đúng ý đồ: `AudioMixController` tự nhận nuôi mọi Sound trong Workspace
	vào kênh `sfx` rồi nhân hệ số slider lên trên.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ZoneLod = require(script.Parent.ZoneLod)

local Zone10RisingBlockController = {}

-- Bán kính SÀN. Tầm thức thật do `ZoneLod.RadiusSq` quyết định theo WalkSpeed — xem ZoneLod.
-- Rộng hơn các zone khác vì tháp cao: đứng dưới chân tháp vẫn phải nghe được khối trên đỉnh.
local RENDER_RADIUS = 360
local RESOLVE_INTERVAL = 0.5

-- Hai ID đã ĐO trong Studio 2026-08-12 (IsLoaded = true, đúng loại Audio):
--   687874741       gió/rền — 4.08s, loop được, hạ pitch xuống thành tiếng ầm ầm của khối đá.
--   9116771817      "Metal Pops Denting Car In Out 2" — 1.51s, cú nện nặng cho lúc chạm đáy.
-- (9119669295 "launch" đã gỡ — xem ghi chú ở chỗ đổi pha trong `step`.)
local RUMBLE_ID = "rbxassetid://687874741"
local IMPACT_ID = "rbxassetid://9116771817"

-- Tháp cao ~223 studs (Y_BOTTOM -121 → Y_TOP 102), nên tầm nghe phải phủ hết chiều cao đó.
local ROLLOFF_MIN = 45
local ROLLOFF_MAX = 420

local RUMBLE_VOLUME_RISE = 0.30
local RUMBLE_VOLUME_FALL = 0.55
-- Ngưỡng phân biệt "đang đi" với "đứng yên". Khối chạy 220–350 studs/s, còn lúc chờ thì đứng
-- im tuyệt đối; 8 studs/s đủ rộng để một frame replicate trễ không bị đọc nhầm thành đứng yên.
local MOVING_SPEED = 8

local player = Players.LocalPlayer

local killBlock: BasePart? = nil
local rumble: Sound? = nil
local impact: Sound? = nil

local awake = false
-- Y của frame trước. nil = chưa có gì để so (vừa vào tầm hoặc part vừa được stream về): frame
-- đầu tiên KHÔNG phát cue nào, nếu không người chơi vừa tới nơi đã ăn ngay một cú nện lạc nhịp.
local lastY: number? = nil
local lastPhase = "idle" -- "idle" | "rise" | "fall"

local function ensureSound(parent: BasePart, name: string, id: string, volume: number, pitch: number): Sound
	local existing = parent:FindFirstChild(name)
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
	sound.Parent = parent
	return sound
end

local function resolve()
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone10")
	local mechanics = zone and zone:FindFirstChild("Mechanics")
	local block = mechanics and mechanics:FindFirstChild("KillBlock")
	if not block or not block:IsA("BasePart") then
		killBlock = nil
		return
	end

	killBlock = block
	lastY = nil
	--[[
		Mỗi tiếng một Sound RIÊNG sống sẵn trên khối, không dựng lại mỗi nhịp và không bao giờ
		gán lại `SoundId`: gán id ngay trước `Play()` làm tiếng ra trễ vài trăm ms (đã đo, xem
		ghi chú trong ASMR/Engine/SoundPool) — với một cảnh báo "khối sắp rơi vào đầu" thì trễ
		như thế là vô dụng.
		Tiếng rền đổi ÂM LƯỢNG theo pha (dâng 0.30 · rơi 0.55) thay cho hai cú hú đã gỡ: tai vẫn
		phân biệt được khối đang lên hay đang xuống mà không cần nhìn.
	]]
	rumble = ensureSound(block, "Zone10Rumble", RUMBLE_ID, 0, 0.55)
	if rumble then
		rumble.Looped = true
	end
	impact = ensureSound(block, "Zone10Impact", IMPACT_ID, 0.85, 0.7)

	-- Dọn Sound whoosh còn sót trên khối từ phiên chạy trước (script cũ dựng chúng một lần rồi
	-- để nguyên trên part). Không dọn thì file place cũ vẫn kêu dù code đã gỡ.
	for _, name in { "Zone10RiseWhoosh", "Zone10FallWhoosh" } do
		local stale = block:FindFirstChild(name)
		if stale then
			stale:Destroy()
		end
	end
end

local function alive(): boolean
	local block = killBlock
	return block ~= nil and block:IsDescendantOf(Workspace)
end

local function silence()
	if rumble then
		rumble:Stop()
	end
end

local function step(dt: number)
	if not alive() then
		return
	end
	local block = killBlock :: BasePart

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local pos = root.Position
	local dx = pos.X - block.Position.X
	local dz = pos.Z - block.Position.Z
	if dx * dx + dz * dz > ZoneLod.RadiusSq(RENDER_RADIUS) then
		if awake then
			awake = false
			lastY = nil
			lastPhase = "idle"
			silence()
		end
		return
	end
	awake = true

	local y = block.Position.Y
	local prev = lastY
	lastY = y
	if prev == nil then
		return -- frame đầu sau khi vào tầm: chưa có gì để so
	end

	-- Chia cho dt chứ không so thẳng "dy mỗi frame": ở 30fps mỗi frame khối đi gấp đôi ở
	-- 60fps, ngưỡng tính theo frame sẽ đọc ra hai kết quả khác nhau trên hai máy.
	local speed = if dt > 0 then (y - prev) / dt else 0

	local phase = "idle"
	if speed > MOVING_SPEED then
		phase = "rise"
	elseif speed < -MOVING_SPEED then
		phase = "fall"
	end

	if phase ~= lastPhase then
		-- ĐÃ GỠ 2026-08-12 (user nghe thử rồi bác): hai cú "whoosh" lúc khối dâng và lúc khối
		-- rơi. Cả hai dùng chung mẫu 9119669295 chỉ khác pitch, và nghe ra là tiếng pháo hoa
		-- phóng (đúng nguồn gốc của mẫu đó ở Zone 5) chứ không phải khối đá nặng chuyển động.
		-- Giờ cảnh báo chỉ còn hai lớp, và cả hai đều đúng vật lý: tiếng RỀN liên tục theo
		-- chuyển động (nghe càng to là khối càng gần) + cú NỆN khi chạm đáy.
		if phase == "idle" and lastPhase == "fall" and impact then
			-- Đứng lại sau khi RƠI = vừa chạm đáy. Dừng lại sau khi DÂNG là tới đỉnh — chỗ đó
			-- khối chỉ đứng chờ, không có va chạm gì nên cố ý im.
			impact:Play()
		end
		lastPhase = phase
	end

	if rumble then
		if phase == "idle" then
			if rumble.IsPlaying then
				rumble:Stop()
			end
		else
			rumble.Volume = if phase == "fall" then RUMBLE_VOLUME_FALL else RUMBLE_VOLUME_RISE
			if not rumble.IsPlaying then
				rumble:Play()
			end
		end
	end
end

function Zone10RisingBlockController.Init() end

function Zone10RisingBlockController.Start()
	RunService.RenderStepped:Connect(step)

	task.spawn(function()
		while true do
			if not alive() then
				resolve()
			end
			task.wait(RESOLVE_INTERVAL)
		end
	end)
end

return Zone10RisingBlockController
