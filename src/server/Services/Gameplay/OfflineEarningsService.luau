--!strict
--[[
	OfflineEarningsService.luau — Treadmill vẫn chạy khi người chơi đã thoát game.

	Toàn bộ lý do thiết kế + ba tầng chặn lạm phát nằm ở `Shared/Config/OfflineEarnings.luau`.
	File này lo phần cơ khí: đóng dấu thời điểm rời game, quy đổi lúc quay lại, và giữ phần
	thưởng ở trạng thái CHỜ NHẬN cho tới khi người chơi tự bấm.

	── CÔNG THỨC ─────────────────────────────────────────────────────────────────────────────
	    elapsed = clamp(os.time() − LastOnlineTime, 0, MAX_SECONDS)
	    ticks   = elapsed / SPEED_GAIN_INTERVAL          -- cùng nhịp với vòng tick online
	    speed   = padStep × offlineMultiplier × RATE × ticks

	Dùng đúng `SPEED_GAIN_INTERVAL` của vòng lặp online chứ không phải một hằng số riêng: có
	như vậy thì `RATE` mới đọc được đúng nghĩa "bằng 25% ngồi treadmill", và khi ai đó chỉnh
	nhịp tick thì hai bên không lệch nhau trong im lặng.

	`padStep` lấy theo `HighestPadIndex` — pad TỐT NHẤT người chơi đã mở, không phải pad họ
	tình cờ đang đứng lúc thoát. Offline thì không ai đứng trên pad nào cả, nên chọn mốc mà
	người chơi cảm thấy công bằng: thứ họ đã cày ra được.

	── VÌ SAO PHẢI BẤM NHẬN, KHÔNG TỰ CỘNG (2026-08-27) ─────────────────────────────────────
	Bản đầu cộng thẳng Speed rồi hiện một banner. Đổi sang modal Claim / Double It vì khoảnh
	khắc người chơi vừa quay lại và đang NHÌN con số của mình là điểm bán hàng tự nhiên nhất
	trong cả game — cộng lặng lẽ là vứt nó đi. Số chờ nhận nằm ở `PendingOfflineSpeed` trong
	profile (không phải bộ nhớ phiên): đóng modal rồi thoát game KHÔNG mất phần thưởng.

	── ⚠️ BỐN CÁI BẪY ĐÃ CHẶN ────────────────────────────────────────────────────────────────
	1. `os.time()` là ĐỒNG HỒ TƯỜNG của máy chủ, không phải đồng hồ đơn điệu. Hai server khác
	   nhau có thể lệch nhau vài giây ⇒ `elapsed` ÂM là chuyện bình thường, không phải gian lận.
	   `math.max(0, …)` xử lý, và tuyệt đối KHÔNG được cảnh báo hay trừng phạt vì chuyện đó.

	2. PHẢI đóng dấu ở CẢ `PlayerRemoving` LẪN `BindToClose`. Thiếu vế hai thì mỗi lần Roblox
	   tắt server (update, restart, hết người) là dấu thời gian của mọi người đang chơi bị kẹt
	   ở lần thoát TRƯỚC ĐÓ — họ vào lại và được trả công cho quãng thời gian họ đang… chơi.

	3. Đóng dấu TRƯỚC khi `DataService` gọi `profile:EndSession()`. `PlayerRemoving` chạy các
	   listener theo thứ tự đăng ký, mà DataService kết thúc phiên ngay trong listener của nó;
	   ghi sau đó là ghi vào một profile đã đóng — mất trắng, không có lỗi nào được ném ra.
	   Bootstrapper `Start()` các service song song bằng `task.spawn` nên thứ tự KHÔNG đảm bảo.
	   Cách chắc chắn duy nhất không phụ thuộc thứ tự nằm ở khối `stampLeave` bên dưới.

	4. Hoá đơn "Double It" mua khi không còn gì chờ nhận PHẢI trả `PurchaseGranted` kèm đền bù.
	   Xem khối lý do trong `ProcessReceipt` — trả `NotProcessedYet` là tạo một vòng thử lại
	   vĩnh viễn trên tài khoản đó.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local OfflineConfig = require(ReplicatedStorage.Shared.Config.OfflineEarnings)
local Products = require(ReplicatedStorage.Shared.Config.Economy.Products)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local OfflineEarningsService = {}

local DataService: any
local ProgressionService: any

--[[
	Bước tốc độ của pad TỐT NHẤT đã mở khoá.

	Kẹp chỉ số vào biên bảng: `HighestPadIndex` từng vượt số pad có thật trong map (sự cố
	pad_9 tháng 8/2026), và một chỉ số lạc ở đây sẽ thành `nil.speedPerStep`.
]]
local function highestPadStep(data: any): number
	local pads = Constants.MULTIPLIER_PADS
	local index = math.clamp(math.floor(tonumber(data.HighestPadIndex) or 1), 1, #pads)
	return math.max(1, pads[index].speedPerStep)
end

--[[
	Quy đổi thời gian offline → Speed. Trả về (speed, secondsCredited).
	speed = 0 nghĩa là không có gì để phát (chưa từng thoát, thoát quá ngắn, hoặc số quá nhỏ).
]]
local function computeOffline(player: Player, data: any): (number, number)
	local last = tonumber(data.LastOnlineTime) or 0
	if last <= 0 then
		-- Tài khoản có trước tính năng này: bỏ qua lượt đầu, bắt đầu đếm từ lần thoát kế tiếp.
		return 0, 0
	end

	-- Bẫy 1: lệch đồng hồ giữa hai server cho ra elapsed âm. Bình thường, không phải gian lận.
	local elapsed = math.max(0, os.time() - last)
	if elapsed < OfflineConfig.MIN_SECONDS then
		return 0, 0
	end

	local credited = math.min(elapsed, OfflineConfig.MAX_SECONDS)
	local ticks = credited / Constants.SPEED_GAIN_INTERVAL
	local multiplier = ProgressionService.GetOfflineMultiplier(player, data)
	local speed = math.floor(highestPadStep(data) * multiplier * OfflineConfig.RATE * ticks)

	if speed < OfflineConfig.MIN_SPEED_TO_GRANT then
		return 0, 0
	end
	return speed, credited
end

local function pendingOf(data: any): number
	return math.max(0, math.floor(tonumber(data.PendingOfflineSpeed) or 0))
end

--[[
	Gửi số Speed đang chờ nhận xuống client. `speed = 0` ⇒ client đóng modal.

	`pcall` vì hàm này chạy cả lúc người chơi vừa vào — kênh gửi riêng của họ có thể chưa kịp
	dựng (xem khối cảnh báo ở đầu `server/init.server.luau`).
]]
local function sendState(player: Player, data: any, seconds: number)
	pcall(GamePackets.offlineEarnings.sendTo, {
		speed = pendingOf(data),
		seconds = math.max(0, seconds),
	}, player)
end

--[[
	Phát phần thưởng đang chờ. `multiplier` = 1 (Claim) hoặc 2 (mua Double It).

	Số tiền đọc TỪ PROFILE, không bao giờ từ gói tin của client — `requestOfflineClaim` cố ý
	không mang theo con số nào.

	Xoá về 0 TRƯỚC khi cộng Speed: `GrantSpeed` có thể kích chuỗi level-up → auto-rebirth, và
	nếu chuỗi đó chạy trong khi `PendingOfflineSpeed` còn nguyên thì hai gói tin tới sát nhau
	sẽ phát thưởng hai lượt.
]]
local function payout(player: Player, multiplier: number): boolean
	local data = DataService.GetData(player)
	if not data then
		return false
	end
	local pending = pendingOf(data)
	if pending <= 0 then
		return false
	end

	data.PendingOfflineSpeed = 0
	local total = pending * multiplier
	ProgressionService.GrantSpeed(player, total)
	sendState(player, data, 0)

	pcall(GamePackets.purchaseCelebration.sendTo, {
		itemName = if multiplier > 1 then "OFFLINE SPEED DOUBLED" else "OFFLINE SPEED CLAIMED",
		subtitle = `+{Format.Number(total)} Speed from your treadmill`,
	}, player)

	Log.Info(`[OfflineEarningsService] {player.Name} nhận {total} Speed (x{multiplier})`)
	return true
end

local function onJoin(player: Player)
	local tries = 0
	while not DataService.IsLoaded(player) and tries < 200 and player.Parent == Players do
		tries += 1
		task.wait(0.1)
	end
	if not DataService.IsLoaded(player) or player.Parent ~= Players then
		return
	end

	local data = DataService.GetData(player)
	if not data then
		return
	end

	local speed, credited = computeOffline(player, data)

	--[[
		Đóng dấu LẠI ngay lúc vào, dù có cộng thêm gì hay không.

		Nếu chỉ ghi lúc rời game thì một phiên bị crash / mất điện sẽ để lại dấu cũ, và lần vào
		kế tiếp trả công cho cả quãng thời gian người chơi đã ngồi chơi trong phiên bị crash đó.
		Ghi ở đây biến mốc thành "lần cuối server NHÌN THẤY người này", đúng thứ ta muốn đo.
	]]
	data.LastOnlineTime = os.time()

	-- CỘNG DỒN chứ không ghi đè: người chơi có thể đã đóng modal lần trước mà chưa bấm nhận.
	if speed > 0 then
		data.PendingOfflineSpeed = pendingOf(data) + speed
	end

	if pendingOf(data) <= 0 then
		return
	end

	-- Chờ HUD dựng xong rồi mới bảo nó mở modal; bắn ngay lúc này thì client chưa có gì để mở.
	task.wait(2)
	if player.Parent ~= Players then
		return
	end
	sendState(player, data, credited)
end

--[[
	Đóng dấu thời điểm rời game.

	⚠️ Bẫy 3 ở đầu file: `DataService` gọi `profile:EndSession()` ngay trong listener
	`PlayerRemoving` của nó, và bootstrapper `Start()` các service song song nên không có gì
	đảm bảo listener nào chạy trước. Cách chắc chắn duy nhất không phụ thuộc thứ tự là ghi vào
	bảng `data` — `DataService.GetData` trả về `profile.Data`, tức chính bảng ProfileStore đang
	theo dõi; nếu phiên đã đóng thì `GetData` trả nil và ta lặng lẽ bỏ qua (giá trị cũ vẫn còn,
	chỉ là mất chính xác vài giây — chấp nhận được, và không bao giờ trả công thừa).
]]
local function stampLeave(player: Player)
	local data = DataService.GetData(player)
	if data then
		data.LastOnlineTime = os.time()
	end
end

--[[
	[Studio-only test hook] GIẢ LẬP MỘT LẦN THOÁT GAME.

	    game.Players["<tên>"]:SetAttribute("StudioOfflineSeconds", 10800)

	Vì sao BẮT BUỘC phải có: trong Studio `DataService` dùng `playerStore.Mock`, tức mỗi lần
	bấm Play là một profile mới tinh với `LastOnlineTime = 0` ⇒ nhánh phát thưởng KHÔNG BAO GIỜ
	chạy. Không có hook thì cách duy nhất để nghiệm thu là publish lên QA rồi ngồi chờ.

	Attribute chứ không phải gọi hàm: `execute_luau` chạy ở một VM riêng nên không với tới hàm
	local trong file này. Cùng lý do với `StudioTestSpin` / `StudioTutorialFinale`.
]]
local function watchStudioOfflineHook(player: Player)
	player:GetAttributeChangedSignal("StudioOfflineSeconds"):Connect(function()
		local seconds = tonumber(player:GetAttribute("StudioOfflineSeconds"))
		if not seconds then
			return
		end
		player:SetAttribute("StudioOfflineSeconds", nil)

		local data = DataService.GetData(player)
		if not data then
			return
		end
		data.LastOnlineTime = os.time() - math.floor(seconds)
		local speed, credited = computeOffline(player, data)
		data.LastOnlineTime = os.time()
		data.PendingOfflineSpeed = pendingOf(data) + speed
		Log.Info(`[OfflineEarningsService] (Studio) giả lập {seconds}s offline → +{speed} Speed chờ nhận`)
		sendState(player, data, credited)
	end)
end

function OfflineEarningsService.ProcessReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	if Products.OFFLINE_DOUBLE_PRODUCT_ID <= 0 or receiptInfo.ProductId ~= Products.OFFLINE_DOUBLE_PRODUCT_ID then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if payout(player, 2) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	--[[
		Bẫy 4: không còn gì chờ nhận (người chơi bấm Claim trong lúc hộp thoại mua đang mở).

		VẪN phải trả `PurchaseGranted`. Trả `NotProcessedYet` khiến Roblox thử lại hoá đơn này
		ở mọi phiên sau, mãi mãi — người chơi đã bị trừ Robux nên không có đường lùi nào sạch.
		Đền bằng đúng một lượt offline kịch trần để không ai mất trắng.
	]]
	local data = DataService.GetData(player)
	if data then
		local refund = math.floor(
			highestPadStep(data)
				* ProgressionService.GetOfflineMultiplier(player, data)
				* OfflineConfig.RATE
				* (OfflineConfig.MAX_SECONDS / Constants.SPEED_GAIN_INTERVAL)
		)
		ProgressionService.GrantSpeed(player, refund)
		warn(`[OfflineEarningsService] {player.Name} mua Double khi không còn gì chờ — đền {refund} Speed`)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function OfflineEarningsService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
end

function OfflineEarningsService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onJoin, player)
	end)

	GamePackets.requestOfflineClaim.listen(function(_data, player)
		payout(player, 1)
	end)

	Players.PlayerRemoving:Connect(stampLeave)

	if RunService:IsStudio() then
		for _, player in Players:GetPlayers() do
			watchStudioOfflineHook(player)
		end
		Players.PlayerAdded:Connect(watchStudioOfflineHook)
	end

	--[[
		Bẫy 2: server tắt (update / restart / hết người) KHÔNG bắn `PlayerRemoving` cho mọi
		người kịp thời. Thiếu nhánh này thì cả phòng bị kẹt dấu thời gian ở lần thoát trước và
		được trả công cho quãng họ vừa ngồi chơi.
	]]
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			stampLeave(player)
		end
	end)
end

return OfflineEarningsService
