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

	── v2 (2026-08-27): CONTROLLER NÀY GIỜ VẼ LUÔN CẢ KHỐI ─────────────────────────────
	User: "bẫy ở mọi zone giật giật khi stage đông người — không phải lag game, giống lag
	mạng". Ping đo được 390ms (PC) / ~350ms (iPhone 13).

	Khối lava là bẫy CUỐI CÙNG trong game còn để server dời part thật, và là cái tệ nhất về
	hình ảnh: nó rơi 350 studs/s. Part neo do script dời thì client KHÔNG nội suy — nó nhảy
	thẳng tới giá trị mới mỗi khi gói replicate tới, nên cú rơi 0.64 giây chỉ hiện ra thành
	vài chục nấc, và stage càng đông người thì gói càng thưa. Đó chính là "giật như lag mạng"
	mà FPS không hề tụt.

	`Zone10RisingKillBlockScript` v5 trong map giờ KHÔNG dời khối nữa: nó công bố các hằng số
	nhịp một lần, rồi mỗi lần bẫy thức thì ghi ĐÚNG MỘT attribute `BlockWakeAt` (giờ server
	lúc thức). Controller này dựng lại chiều cao khối bằng cùng một hàm thuần `yFor` — server
	và client không thể lệch nhau, và tốn 0 byte cho cả chu kỳ.

	⚠️ Bẫy này KHÔNG chạy tự do như Zone 3/8: nó vẫn NGỦ khi không có ai trong bán kính 260 và
	reset về đáy (đó là thứ giữ cửa sổ leo của người vừa vào, tức gate 150 WS). Vì vậy pha
	tính từ `BlockWakeAt` chứ không phải từ giờ server thô. `BlockWakeAt` = nil ⇒ khối ở đáy.

	── VÌ SAO PHẦN TIẾNG VẪN ĐỌC VỊ TRÍ ─────────────────────────────────────────────────
	Logic tiếng bên dưới suy pha từ `block.Position.Y` giữa hai frame. Giữ nguyên: giờ chính
	controller này ghi cái Position đó, nên phép đo đúng hơn bản cũ chứ không kém — và nó tự
	động đúng cả khi khối đang ngủ.

	Volume viết cứng là đúng ý đồ: `AudioMixController` tự nhận nuôi mọi Sound trong Workspace
	vào kênh `sfx` rồi nhân hệ số slider lên trên.
]]

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

local killBlock: BasePart? = nil
local rumble: Sound? = nil
local impact: Sound? = nil

--[[
	── DÒNG DUNG NHAM CHẢY (v3, 2026-08-27) ────────────────────────────────────────────────
	Trước đây là một Script SERVER (`KillBlock.TextureScroller`) cộng `OffsetStudsU/V` mỗi
	Heartbeat. Mỗi lần cộng là một thay đổi thuộc tính phải REPLICATE cho mọi client — 60 lần
	mỗi giây, VĨNH VIỄN, kể cả khi cả server đang ở lobby và không ai nhìn thấy khối.

	Cùng họ bệnh với quạt Zone 12 và khối lava: hiệu ứng thuần TRANG TRÍ mà lại đi qua đường
	mạng, nên nó vừa tốn băng thông vừa chảy giật theo nhịp gói. Ở ping 350–400ms nhìn ra là
	dung nham "nhấp nháy" chứ không chảy.

	Ở client thì nó chỉ là một phép cộng cục bộ, và tự động ngủ theo cùng cổng LOD với phần
	tiếng bên dưới — không ai nhìn thấy thì không tốn gì.
]]
local TEXTURE_SPEED_U = 1.5
local TEXTURE_SPEED_V = 3.0
local textures: { Texture } = {}

--[[
	── NHỊP KHỐI (v2) ───────────────────────────────────────────────────────────────────────
	CHÉP NGUYÊN hàm `yFor` của Zone10RisingKillBlockScript v5. Đây là hợp đồng: sửa một vế mà
	không sửa vế kia là hình và phán xử lệch nhau, người chơi chết oan hoặc đi xuyên khối.
	Các hằng số đọc từ attribute do server ghi, KHÔNG chép số — để đổi nhịp chỉ phải sửa một chỗ.
]]
local mechanicsFolder: Instance? = nil
local yBottom, yTop, vRise, vFall, waitTop, waitBottom = -121, 102, 220, 350, 1.0, 1.75
local blockCycle = 0
local blockBaseX, blockBaseZ = 0, 0
local blockReady = false

local function recomputeCycle()
	blockCycle = waitBottom + (yTop - yBottom) / vRise + waitTop + (yTop - yBottom) / vFall
end
recomputeCycle()

local function yFor(elapsed: number): number
	local t = elapsed % blockCycle
	if t < waitBottom then
		return yBottom
	end
	t -= waitBottom
	local riseT = (yTop - yBottom) / vRise
	if t < riseT then
		return yBottom + vRise * t
	end
	t -= riseT
	if t < waitTop then
		return yTop
	end
	return yTop - vFall * (t - waitTop)
end

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

	table.clear(textures)
	for _, child in block:GetChildren() do
		if child:IsA("Texture") then
			table.insert(textures, child)
		end
	end

	-- Hằng số nhịp do server công bố (xem Zone10RisingBlockService).
	mechanicsFolder = mechanics
	blockReady = mechanics ~= nil and mechanics:GetAttribute("BlockReady") == true
	if mechanics and blockReady then
		local function num(name: string, fallback: number): number
			local v = mechanics:GetAttribute(name)
			return if type(v) == "number" then v else fallback
		end
		yBottom = num("BlockYBottom", yBottom)
		yTop = num("BlockYTop", yTop)
		vRise = num("BlockVRise", vRise)
		vFall = num("BlockVFall", vFall)
		waitTop = num("BlockWaitTop", waitTop)
		waitBottom = num("BlockWaitBottom", waitBottom)
		blockBaseX = num("BlockBaseX", block.Position.X)
		blockBaseZ = num("BlockBaseZ", block.Position.Z)
		recomputeCycle()
	end
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

	-- Gốc nhân vật tra MỘT lần mỗi frame cho cả bảy controller bẫy, không phải mỗi
	-- controller một lần `FindFirstChild` — xem `ZoneLod.Root`.
	if not ZoneLod.Root() then
		return
	end
	local pos = ZoneLod.RootPosition()
	-- Khối chỉ đi theo Y nên X/Z là hằng số — dùng `blockBaseX/Z` chứ không đọc `block.Position`
	-- (từ v2 chính controller này ghi Position, đọc lại là vòng luẩn quẩn không cần thiết).
	local dx = pos.X - blockBaseX
	local dz = pos.Z - blockBaseZ
	if dx * dx + dz * dz > ZoneLod.RadiusSq(RENDER_RADIUS) then
		if awake then
			awake = false
			lastY = nil
			lastPhase = "idle"
			silence()
			-- Ngủ: hạ khối về đáy ĐÚNG MỘT LẦN. Bỏ qua bước này thì nhìn từ zone khác sẽ thấy
			-- khối treo lơ lửng giữa tháp, tưởng bẫy hỏng (đúng lỗi đã phàn nàn ở các zone khác).
			if blockReady then
				block.Position = Vector3.new(blockBaseX, yBottom, blockBaseZ)
			end
		end
		return
	end
	awake = true

	--[[
		VẼ KHỐI (v2). `BlockWakeAt` = giờ server lúc bẫy thức, do map script ghi đúng một lần
		mỗi lần ngủ↔thức. nil ⇒ zone trống ⇒ khối nằm đáy.

		`ZoneLod.Now()` chứ không phải `GetServerTimeNow()`: đồng hồ đã làm trơn, xem khối
		"ĐỒNG HỒ TRƠN" trong ZoneLod. Ở ping 350–400ms đây mới là thứ giữ cho khối không giật.
	]]
	if blockReady then
		local wakeAt = mechanicsFolder and mechanicsFolder:GetAttribute("BlockWakeAt")
		local targetY = if type(wakeAt) == "number" then yFor(ZoneLod.Now() - wakeAt) else yBottom
		block.Position = Vector3.new(blockBaseX, targetY, blockBaseZ)
	end

	-- Dung nham chảy (xem khối lý do ở đầu file). Nằm SAU cổng LOD nên khối ở ngoài tầm là
	-- không tốn gì.
	for i = 1, #textures do
		local tex = textures[i]
		tex.OffsetStudsU += TEXTURE_SPEED_U * dt
		tex.OffsetStudsV += TEXTURE_SPEED_V * dt
	end

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
			-- `not blockReady` cũng phải resolve lại: lần đầu có thể chạy TRƯỚC khi map script
			-- kịp ghi attribute, và nếu chỉ xét `alive()` thì controller sẽ mắc kẹt vĩnh viễn ở
			-- trạng thái "thấy part nhưng không biết nhịp" — khối đứng im cả phiên.
			if not alive() or not blockReady then
				resolve()
			end
			task.wait(RESOLVE_INTERVAL)
		end
	end)
end

return Zone10RisingBlockController
