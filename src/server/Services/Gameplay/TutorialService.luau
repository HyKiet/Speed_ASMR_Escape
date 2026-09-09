--!strict
-- Server: nhận mốc từ gameplay, lưu bước tutorial và báo TutorialController vẽ hướng dẫn.
-- Yêu cầu Skip chỉ kết thúc hướng dẫn; phần thưởng thuộc hệ thống khác.
--[[
	TutorialService.luau — dẫn đường 3 bước cho người chơi mới.

	── VÌ SAO 3 BƯỚC, VÀ VÌ SAO KHÔNG CÓ HỘP THOẠI ────────────────────────────────────────
	Người chơi Roblox phần lớn 9–16 tuổi và bấm Skip trên mọi hộp thoại có chữ trước khi kịp
	đọc. Nên tutorial này KHÔNG chặn điều khiển, không làm tối màn hình, không có trang chữ:
	client chỉ vẽ một tia sáng chỉ tới đích và một dòng nhắc ngắn (xem TutorialController).

	Mỗi bước gắn vào một sự kiện gameplay mà server VỐN ĐÃ biết, nên không có packet
	"tôi đã xong bước này" nào để giả mạo:

	    Bước 1 (Claim) ← chốt Wins ở pad vàng cuối Stage 1 (AwardWins reason="stage")
	    Bước 2 (Pad2)  ← mở khoá / đứng lên Multiplier Pad 2 (MultiplierPadService)
	    Bước 3 (Farm)  ← bước lên Treadmill (ProgressionService.SetTreadmillState isOn)

	⚠️ Bước 3 KHÔNG dùng "lần đầu nhận Speed": Multiplier Pad ở bước 2 cũng sinh Speed, nên
	mốc đó sẽ tự bật ngay lúc còn đang ở bước 2 và tutorial nhảy cóc. Phải là sự kiện riêng
	của treadmill.

	── THỨ TỰ CÁC BƯỚC ────────────────────────────────────────────────────────────────────
	Cố ý đi NGƯỢC tutorial simulator thường thấy (farm trước, chạy sau): bước 1 ném thẳng
	người chơi vào Obby + khoảnh khắc ăn Wins — phần vui nhất và khác biệt nhất của game —
	trong vòng một phút đầu. Cày cuốc để sau, khi họ đã có lý do để cày.

	Chốt Wins xong game tự teleport về Lobby, nên bước 2 khởi đầu ngay tại Lobby: mạch đi
	liền không có đoạn chạy bộ vô nghĩa nào.

	── KHÔNG CÓ PHẦN THƯỞNG (chốt 2026-08-10) ─────────────────────────────────────────────
	Tutorial KHÔNG phát bất cứ thứ gì — không Wins, không Speed, không vé quay. Phần thưởng
	của người chơi mới nằm trọn ở Daily Ngày 1, phát TRƯỚC khi tutorial bắt đầu.

	Vì vậy `TutorialService` KHÔNG được đụng vào kinh tế. Ràng buộc còn lại chỉ là một phép so:

	    Stage 1 = 2 Wins  ≥  giá mua Pad 2 = 1 Win   (bước 1 phải TỰ nuôi được bước 2)

	⚠️ Hai con số đó khoá chặt nhau. Đổi `MultiplierPads.pad_2.requiredWins` hay
	`Stages.STAGE_WINS[1]` thì PHẢI kiểm lại phép so này — lệch xuống là bước 2 thành ngõ cụt
	"Need N Wins" và người chơi mới kẹt ở đó không có đường ra.
	(Từ 2026-09-06 pad là MUA ĐỨT: chạm pad chưa sở hữu sẽ TRỪ `TotalWins` rồi ghi vĩnh viễn
	vào `HighestPadIndex`. Vừa đủ vẫn qua được — phép so là `≥`, không cần dư.)

	⚠️ 2026-08-17: Daily đã chuyển TỪ đầu phiên XUỐNG bước cuối, nên KHÔNG còn được tính +2 Wins
	của Ngày 1 vào phép so trên — trước đây chính khoản đó gánh cho Pad 2 giá 3. Xem
	`TutorialController.runDailyFinale` để biết vì sao đổi chỗ; Group Chest vẫn mở sau cùng.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)
local NetRateLimit = require(ReplicatedStorage.Shared.Util.NetRateLimit)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local TutorialService = {}

-- ⚠️ Đổi thứ tự/ý nghĩa các bước = làm gãy dữ liệu phễu lịch sử. Chỉ được THÊM vào cuối.
local STEP_INDEX: { [string]: number } = {
	Claim = 1,
	Pad2 = 2,
	Farm = 3,
}
local STEP_COUNT = 3

local DataService: any
local TelemetryService: any

local function isActive(data: any): boolean
	return (tonumber(data.TutorialStep) or 0) < STEP_COUNT and not data.TutorialSkipped
end

local function sendState(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	GamePackets.tutorialState.sendTo({
		step = math.clamp(tonumber(data.TutorialStep) or 0, 0, 255),
		active = isActive(data),
	}, player)
end

--[[
	Đóng sổ tutorial: ghi telemetry + báo client để nó chạy nốt phần cuối (mở Group Chest).
	KHÔNG phát thưởng — xem khối "KHÔNG CÓ PHẦN THƯỞNG" ở đầu file.

	`TutorialRewarded` giữ nguyên tên trường (dữ liệu đã lưu của người chơi đang dùng nó)
	nhưng giờ chỉ còn một nhiệm vụ: chặn gói tin kết thúc bắn hai lần.
]]
local function finishTutorial(player: Player, skipped: boolean): boolean
	local data = DataService.GetData(player)
	if not data or data.TutorialRewarded then
		return false
	end
	data.TutorialRewarded = true

	if TelemetryService then
		TelemetryService.Custom(player, if skipped then "TutorialSkipped" else "TutorialCompleted", 1)
	end

	GamePackets.tutorialComplete.sendTo({
		wins = 0,
		spins = 0,
		skipped = skipped,
	}, player)
	return true
end

--[[
	Gọi từ ProgressionService mỗi khi một sự kiện mốc xảy ra. An toàn khi gọi lặp: chỉ nhích
	khi `stepKey` đúng là bước KẾ TIẾP, nên người chơi làm lệch thứ tự (ví dụ mua teleport
	rồi chốt Wins trước khi lên Level 2) không nhảy cóc qua các bước chưa đạt.
]]
function TutorialService.Notify(player: Player, stepKey: string)
	local index = STEP_INDEX[stepKey]
	if not index then
		warn(`[TutorialService] Bước không tồn tại: {stepKey}`)
		return
	end

	local data = DataService and DataService.GetData(player)
	if not data or not isActive(data) then
		return
	end

	local current = tonumber(data.TutorialStep) or 0
	if index ~= current + 1 then
		return
	end

	data.TutorialStep = index
	sendState(player)

	if index >= STEP_COUNT then
		finishTutorial(player, false)
	end
end

function TutorialService.Init()
	-- Chỉ cần DataService + Telemetry: tutorial không phát thưởng nên không đụng tới
	-- ProgressionService/RouletteService nữa.
	DataService = ServiceLocator.Get("DataService")
	TelemetryService = ServiceLocator.Get("TelemetryService")
end

function TutorialService.Start()
	GamePackets.requestTutorialSkip.listen(function(_payload, player)
		if not player or NetRateLimit.ShouldDrop(player, "tutorialSkip") then
			return
		end
		local data = DataService.GetData(player)
		if not data or not isActive(data) then
			return
		end
		data.TutorialSkipped = true
		sendState(player)
		finishTutorial(player, true)
	end)

	local function pushWhenReady(player: Player)
		task.spawn(function()
			local tries = 0
			while not DataService.IsLoaded(player) and tries < 200 and player.Parent == Players do
				task.wait(0.1)
				tries += 1
			end
			if player.Parent ~= Players or not DataService.IsLoaded(player) then
				return
			end

			local data = DataService.GetData(player)
			-- Người chơi CŨ (đã chơi từ trước khi tutorial ra đời) thì đánh dấu xong ngay:
			-- một tài khoản Level 120 mà bị chỉ đường "Run Stage 1" thì vô duyên.
			-- Tutorial giờ không phát thưởng nên đây thuần tuý là chuyện lịch sự, không còn
			-- là chốt chặn kinh tế nữa.
			if data and data.TutorialStep == 0 and (data.TotalWins > 0 or data.Level > 1) then
				data.TutorialStep = STEP_COUNT
				data.TutorialRewarded = true
			end
			sendState(player)

			-- QA: nói thẳng ra vì sao không thấy tutorial. Đã mất một vòng hỏi đi hỏi lại
			-- "sao test không thấy gì" chỉ vì tài khoản test có sẵn 1M Wins.
			if RunService:IsStudio() and data and not isActive(data) then
				print(
					`[TutorialService] {player.Name} đã qua tutorial (step={data.TutorialStep}, `
						.. `skipped={tostring(data.TutorialSkipped)}). Muốn xem lại: `
						.. `game.Players["{player.Name}"]:SetAttribute("StudioTutorialReset", true)`
				)
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		pushWhenReady(player)
	end
	Players.PlayerAdded:Connect(pushWhenReady)

	--[[
		Studio-only: chạy lại tutorial trên tài khoản đã chơi lâu.
		    game.Players.<Tên>:SetAttribute("StudioTutorialReset", true)

		Dùng ATTRIBUTE chứ không phải packet vì `execute_luau` của MCP chạy trong một VM
		RIÊNG: require ở đó tạo một bản ByteNet khác, gói tin gửi đi không tới được client
		thật (đã dính đúng bẫy này khi nghiệm thu). Attribute thì nằm trên Instance chung
		nên mọi VM đều thấy — cùng cách RouletteService đang phát vé test.
	]]
	if RunService:IsStudio() then
		local function watch(player: Player)
			player:GetAttributeChangedSignal("StudioTutorialReset"):Connect(function()
				if not player:GetAttribute("StudioTutorialReset") then
					return
				end
				player:SetAttribute("StudioTutorialReset", false)

				local data = DataService.GetData(player)
				if not data then
					return
				end
				data.TutorialStep = 0
				data.TutorialSkipped = false
				data.TutorialRewarded = false
				sendState(player)
				Log.Info(`[TutorialService] Đã reset tutorial cho {player.Name} (Studio).`)
			end)
		end
		for _, player in Players:GetPlayers() do
			watch(player)
		end
		Players.PlayerAdded:Connect(watch)
	end
end

return TutorialService
