--!strict
-- Server: đọc ConfigService theo chu kỳ, kiểm tra giá trị rồi cung cấp hệ số cho ProgressionService.
-- Khi tên hoặc hệ số event đổi, gửi trạng thái mới để HUD cập nhật.
--[[
	RemoteConfigService.luau — Hệ số event thời vụ chỉnh được TỪ XA, không cần publish game.

	Đọc Roblox Configs (`ConfigService`) để đổi hệ số event ngay trên server đang chạy: bật x2
	Wins cuối tuần, hạ về x1 khi hết, tắt khẩn cấp một event hỏng — tất cả trong ~1 phút thay
	vì một vòng publish + restart toàn bộ server.

	Tạo/sửa giá trị ở: Creator Hub → Configs, hoặc Studio → File → Open Configs.
	Publish xong mất 15 giây–1 phút để tới server, cộng thêm tối đa `REFRESH_SECONDS` nữa vì
	snapshot KHÔNG tự cập nhật — phải chủ động lấy lại (đây là điểm dễ hiểu nhầm nhất của API).

	══ BA LỚP AN TOÀN ══
	1. FALLBACK: mọi key đều có giá trị mặc định trong `DEFAULTS`. ConfigService không tồn tại,
	   gọi lỗi, key chưa tạo, hay sai kiểu → dùng mặc định. Game KHÔNG BAO GIỜ chết vì Configs.
	2. KẸP BIÊN: hệ số bị kẹp trong `[MIN_MULTIPLIER, MAX_MULTIPLIER]`. Gõ nhầm 100 thay vì 1.0
	   trên dashboard là thổi bay cả nền kinh tế trong vài phút mà không có cách nào lấy lại —
	   lớp kẹp này là thứ đứng giữa một lần gõ nhầm và một lần wipe dữ liệu.
	3. CHỈ SERVER: `ConfigService` vốn không gọi được từ client. Hệ số nhân luôn tính ở server
	   nên client không có đường tự phong event cho mình.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local RemoteConfigService = {}

-- Khoảng lấy lại snapshot. Configs là công cụ LiveOps (phút), không phải kênh realtime (giây)
-- — kéo xuống vài giây chỉ tốn request chứ không làm event mượt hơn.
local REFRESH_SECONDS = 60
local JITTER_SECONDS = 15

-- Trần/sàn cho MỌI hệ số đọc từ xa. Xem lớp an toàn số 2 ở trên.
local MIN_MULTIPLIER = 1
local MAX_MULTIPLIER = 10

-- Key trên dashboard → giá trị dùng khi không đọc được. Đây cũng là danh sách key hợp lệ:
-- key không có ở đây thì `getRaw` không bao giờ trả về.
local DEFAULTS: { [string]: any } = {
	-- Nhân vào tốc độ farm được (cộng chung rổ liveOps với Playtime/Friends/ServerBoost).
	event_speed_multiplier = 1,
	-- Nhân vào Wins nhận khi qua stage.
	event_wins_multiplier = 1,
	-- Tên event để hiện lên HUD. Rỗng = không có event nào đang chạy.
	event_name = "",
	-- Công tắc tổng. false ⇒ mọi hệ số trên bị ép về 1 bất kể dashboard ghi gì.
	event_enabled = false,
}

local values: { [string]: any } = table.clone(DEFAULTS)
local configService: any = nil
local lastFetchOk = false

--[[
	══ HÃM SPAM CẢNH BÁO CỦA CHÍNH ROBLOX ═════════════════════════════════════════════════

	Đo trên Error Report của QA ngày 2026-08-21: **396 warning** — nhiều gấp 20 lần mọi thứ
	khác cộng lại — nội dung `ConfigService: Config value not found for key "..."`. Chia ra
	đúng 4 key × 99 lần refresh (60 s/lần ≈ 99 phút uptime).

	KHÔNG phải lỗi của code này: 4 key chưa được tạo trên Creator Hub, `refresh()` đã xử lý
	nil đúng và fallback đúng. Cái warn đó do CHÍNH `snapshot:GetValue()` in ra từ bên trong
	engine, nên `pcall` không nuốt được — không có cách nào tắt từ phía gọi.

	Vấn đề thật không phải hiệu năng mà là **che mất lỗi thật**: bảng Error Report xếp theo
	số lần, nên 396 dòng vô hại này đẩy mọi lỗi đáng đọc xuống dưới.

	Cách hãm: key nào trả nil thì ghi nhớ, và chỉ THỬ LẠI mỗi `MISSING_REPROBE_EVERY` lần
	refresh. Vẫn tự nhận ra khi bạn tạo key trên dashboard (chậm nhất ~10 phút), mà số warning
	tụt còn 1/10.

	⚠️ Cách chữa TRIỆT ĐỂ vẫn là tạo 4 key trên Creator Hub → Configs. Khối này chỉ hạ tiếng
	ồn xuống, không làm cho việc đó thành không cần thiết.
]]
local MISSING_REPROBE_EVERY = 10
local missingKeys: { [string]: boolean } = {}
local refreshCount = 0

local function getRaw(key: string): any
	local fallback = DEFAULTS[key]
	if fallback == nil then
		warn(`[RemoteConfigService] Key không khai báo trong DEFAULTS: {key}`)
		return nil
	end
	local current = values[key]
	-- Sai kiểu (ai đó đổi String thành Number trên dashboard) thì coi như không có.
	if current == nil or typeof(current) ~= typeof(fallback) then
		return fallback
	end
	return current
end

--[[
	[Studio-only test hook] — QA event mà không phải đụng vào Configs thật.

	Event là công cụ LiveOps: muốn thử "cuối tuần x2" thì bình thường phải bật cờ trên
	Creator Hub, tức là bật cho CẢ GAME ĐANG LIVE chỉ để xem HUD hiển thị đúng chưa.
	Thay vào đó, trong Studio đặt 2 attribute trên `Workspace`:
	    TestEventName        (string)  ví dụ "Weekend Double Speed"
	    TestEventSpeed       (number)  ví dụ 2
	    TestEventWins        (number)  ví dụ 1   — không đặt thì mặc định 1
	Xoá attribute là trở lại đọc Configs thật. Ngoài Studio hook này KHÔNG tồn tại.
]]
local function studioTestEvent(): { name: string, speed: number, wins: number }?
	if not RunService:IsStudio() then
		return nil
	end
	local name = Workspace:GetAttribute("TestEventName")
	if typeof(name) ~= "string" or name == "" then
		return nil
	end
	local speed = Workspace:GetAttribute("TestEventSpeed")
	local wins = Workspace:GetAttribute("TestEventWins")
	return {
		name = name,
		speed = if typeof(speed) == "number" then math.clamp(speed, MIN_MULTIPLIER, MAX_MULTIPLIER) else 1,
		wins = if typeof(wins) == "number" then math.clamp(wins, MIN_MULTIPLIER, MAX_MULTIPLIER) else 1,
	}
end

local function readMultiplier(key: string): number
	local test = studioTestEvent()
	if test then
		return if key == "event_wins_multiplier" then test.wins else test.speed
	end
	if not getRaw("event_enabled") then
		return 1
	end
	local raw = getRaw(key)
	if typeof(raw) ~= "number" or raw ~= raw then -- raw ~= raw bắt NaN
		return 1
	end
	return math.clamp(raw, MIN_MULTIPLIER, MAX_MULTIPLIER)
end

--[[
	Lấy lại snapshot và nạp vào `values`. Trả về true nếu thành công.

	`GetConfigAsync` trả về một ConfigSnapshot — ảnh chụp tại một thời điểm. Đọc từng giá trị
	bằng `snapshot:GetValue(key)`.
]]
local function refresh(): boolean
	if not configService then
		return false
	end

	local ok, snapshot = pcall(function()
		return configService:GetConfigAsync()
	end)
	if not ok or not snapshot then
		if lastFetchOk then
			warn(
				`[RemoteConfigService] Không lấy được config, giữ giá trị đang dùng: {tostring(snapshot)}`
			)
		end
		return false
	end

	refreshCount += 1
	local reprobeMissing = refreshCount % MISSING_REPROBE_EVERY == 1

	for key, fallback in DEFAULTS do
		-- Key đã biết là chưa tạo: bỏ qua hẳn lượt này để engine khỏi in warning (xem khối
		-- "HÃM SPAM CẢNH BÁO" bên trên). Giá trị vẫn là fallback, hành vi không đổi.
		if missingKeys[key] and not reprobeMissing then
			values[key] = fallback
			continue
		end

		local readOk, value = pcall(function()
			return snapshot:GetValue(key)
		end)
		-- Key chưa tạo trên dashboard trả về nil — đó là chuyện BÌNH THƯỜNG, không phải lỗi:
		-- cứ dùng mặc định cho tới khi bạn tạo nó.
		if readOk and value ~= nil and typeof(value) == typeof(fallback) then
			missingKeys[key] = nil
			values[key] = value
		else
			missingKeys[key] = value == nil or not readOk
			values[key] = fallback
		end
	end
	return true
end

-- ── API công khai ────────────────────────────────────────────────────────────

-- Hệ số event nhân vào tốc độ farm. Luôn trả về số hợp lệ ≥ 1.
function RemoteConfigService.GetEventSpeedMultiplier(): number
	return readMultiplier("event_speed_multiplier")
end

-- Hệ số event nhân vào Wins nhận khi qua stage. Luôn trả về số hợp lệ ≥ 1.
function RemoteConfigService.GetEventWinsMultiplier(): number
	return readMultiplier("event_wins_multiplier")
end

-- Tên event đang chạy, hoặc chuỗi rỗng nếu không có.
function RemoteConfigService.GetEventName(): string
	local test = studioTestEvent()
	if test then
		return test.name
	end
	if not getRaw("event_enabled") then
		return ""
	end
	local name = getRaw("event_name")
	return if typeof(name) == "string" then name else ""
end

function RemoteConfigService.IsEventActive(): boolean
	return RemoteConfigService.GetEventName() ~= ""
		or RemoteConfigService.GetEventSpeedMultiplier() > 1
		or RemoteConfigService.GetEventWinsMultiplier() > 1
end

-- Đẩy trạng thái event xuống client để HUD hiện dòng "Event x2.0 (Tên event)".
-- `player = nil` ⇒ phát cho cả server (dùng khi event vừa đổi giữa phiên).
function RemoteConfigService.PushEventState(player: Player?)
	local payload = {
		name = RemoteConfigService.GetEventName(),
		speedMultiplier = RemoteConfigService.GetEventSpeedMultiplier(),
		winsMultiplier = RemoteConfigService.GetEventWinsMultiplier(),
	}
	if player then
		pcall(GamePackets.eventState.sendTo, payload, player)
	else
		pcall(GamePackets.eventState.sendToAll, payload)
	end
end

-- Ép lấy lại ngay, không chờ hết chu kỳ. Dùng khi test trong Studio.
function RemoteConfigService.ForceRefresh(): boolean
	local ok = refresh()
	lastFetchOk = ok
	return ok
end

function RemoteConfigService.Init()
	-- `ConfigService` chưa chắc có trên mọi build engine / mọi universe. Không có thì service
	-- vẫn chạy bình thường và trả toàn bộ giá trị mặc định.
	local ok, service = pcall(function()
		return game:GetService("ConfigService")
	end)
	configService = if ok then service else nil
	if not configService then
		warn(
			"[RemoteConfigService] ConfigService không khả dụng — chạy hoàn toàn bằng giá trị mặc định."
		)
	end
end

function RemoteConfigService.Start()
	-- Người vào sau khi server đã lấy config xong vẫn phải biết event đang chạy.
	-- Chờ 1 nhịp cho client kịp dựng HUD và đăng ký listener rồi mới gửi.
	local function pushToJoiner(player: Player)
		task.delay(2, function()
			if player.Parent == Players then
				RemoteConfigService.PushEventState(player)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		pushToJoiner(player)
	end
	Players.PlayerAdded:Connect(pushToJoiner)

	task.spawn(function()
		lastFetchOk = refresh()
		RemoteConfigService.PushEventState()
		if lastFetchOk then
			Log.Boot(
				`[RemoteConfigService] Configs sẵn sàng — event "{RemoteConfigService.GetEventName()}" `
					.. `speed x{RemoteConfigService.GetEventSpeedMultiplier()} wins x{RemoteConfigService.GetEventWinsMultiplier()}`
			)
		end

		while true do
			-- Jitter vì lý do y hệt LeaderboardService: cả trăm server khởi động cùng lúc sau
			-- một đợt update sẽ gọi dồn vào đúng một giây.
			task.wait(REFRESH_SECONDS + math.random() * JITTER_SECONDS)

			local previousSpeed = RemoteConfigService.GetEventSpeedMultiplier()
			local previousWins = RemoteConfigService.GetEventWinsMultiplier()
			local previousName = RemoteConfigService.GetEventName()
			lastFetchOk = refresh()

			local newSpeed = RemoteConfigService.GetEventSpeedMultiplier()
			local newWins = RemoteConfigService.GetEventWinsMultiplier()
			if
				newSpeed ~= previousSpeed
				or newWins ~= previousWins
				or RemoteConfigService.GetEventName() ~= previousName
			then
				RemoteConfigService.PushEventState()
				print(
					`[RemoteConfigService] Hệ số event đổi: speed x{previousSpeed}→x{newSpeed} `
						.. `wins x{previousWins}→x{newWins} ({#Players:GetPlayers()} người đang chơi)`
				)
			end
		end
	end)
end

return RemoteConfigService
