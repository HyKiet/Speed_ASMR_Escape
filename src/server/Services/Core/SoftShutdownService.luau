--!strict
-- Server: nhận lệnh quản trị qua chat/MessagingService rồi chuyển phiên bằng TeleportService.
-- Shutdown của nền tảng chỉ gửi thông báo; server trung chuyển đưa người chơi về matchmaking.
--[[
	SoftShutdownService.luau — chuyển người chơi sang server MỚI mà không đá họ ra ngoài.

	── VẤN ĐỀ (user gặp 2026-08-27) ────────────────────────────────────────────────────────
	Publish bản mới lên LIVE nhưng người chơi vẫn thấy nội dung cũ. Không phải lỗi publish:
	**Roblox không bao giờ cập nhật một server đang chạy.** Bản mới chỉ áp cho server sinh ra
	SAU đó. Server cũ sống tới khi nó rỗng và tự đóng — mà chừng nào còn người trong đó và nó
	chưa đầy, matchmaking lại tiếp tục nhét người mới vào chính nó. Với `MaxPlayers = 12` và
	vài người chơi, một bản cập nhật có thể mắc kẹt hàng giờ.

	Cách thô là "Shut Down All Servers" trên Creator Dashboard: người chơi bị ĐÁ RA màn hình
	lỗi giữa lúc đang chạy stage. Với game speedrun thì đó là mất trắng một lượt chạy.

	══ ĐỌC MỤC NÀY TRƯỚC KHI DÙNG (cập nhật 2026-08-27) ════════════════════════════════════
	**Cách làm ĐÚNG cho việc phát hành bản mới là dùng tính năng SẴN CÓ của Roblox**, không
	phải service này:

	    Creator Dashboard → Configure → Server Management → **Restart Servers**
	    ☑ chỉ restart server có phiên bản CŨ    ☑ delay 1–60 phút cho người chơi tự rời

	Nó ngừng matchmaking vào server cũ (script KHÔNG có API nào làm được), chờ hết delay, rồi
	tự teleport người còn lại sang server đã cập nhật. Nguồn: tài liệu chính thức
	`create.roblox.com/docs/projects/update-experiences`.

	Service này còn tồn tại vì MỘT lý do hẹp: bấm được lệnh từ trong game (`/update`) khi
	không tiện mở Dashboard. Nó KHÔNG ngừng được matchmaking, nên vẫn kém tính năng gốc.
	Nếu thấy nó gây rắc rối thì xoá cả file — không có gì khác phụ thuộc vào nó.

	── CÁCH LÀM ────────────────────────────────────────────────────────────────────────────
	Soft shutdown kinh điển, chỉ cần MỘT place (không cần place trung chuyển):

	  1. Server nhận lệnh (qua MessagingService, hoặc qua `BindToClose` khi Roblox tự tắt).
	  2. Báo cho người chơi biết, chờ `WARN_SECONDS` để họ đọc kịp.
	  3. `TeleportService:ReserveServer(game.PlaceId)` → một server RIÊNG của chính place này.
	  4. Teleport toàn bộ người chơi sang đó, mang theo cờ `softShutdownReturn = true`.
	  5. Server riêng đó nhận ra cờ (xem `handleReturningPlayer`) và LẬP TỨC teleport họ
	     ngược về place công khai.
	  6. Lúc họ quay lại, server cũ đã rỗng và đang đóng ⇒ matchmaking buộc phải cấp server
	     MỚI, tức là build mới.

	Bước 3–5 là thứ khiến nó hoạt động. Teleport thẳng về cùng place mà không đi vòng thì
	Roblox rất có thể ném họ trở lại ĐÚNG server cũ (nó chưa đầy, và vẫn còn sống vì họ chưa
	kịp rời) — vòng lặp vô nghĩa. Server riêng cắt sợi dây đó: trong lúc họ ở bên kia, server
	cũ rỗng hoàn toàn và bắt đầu tắt.

	── AN TOÀN ─────────────────────────────────────────────────────────────────────────────
	Mọi lời gọi mạng đều `pcall`. Nếu `ReserveServer` hay `TeleportAsync` hỏng thì KHÔNG được
	để người chơi mắc kẹt: ta chỉ đơn giản không di chuyển họ nữa, và server sống tiếp như
	bình thường. Thà bản cập nhật ra chậm còn hơn đá người chơi vào hư không.

	── TRONG STUDIO ────────────────────────────────────────────────────────────────────────
	`MessagingService` và `TeleportService` đều không dùng được trong Studio. Toàn bộ service
	tự tắt ở đó — nếu không, mỗi lần playtest sẽ đầy warning không liên quan.
]]

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local GroupChestConfig = require(ReplicatedStorage.Shared.Config.GroupChest)
local NetRateLimit = require(ReplicatedStorage.Shared.Util.NetRateLimit)

local SoftShutdownService = {}

-- Chủ đề MessagingService. Một tin nhắn tới MỌI server của universe cùng lúc.
local TOPIC = "SoftShutdown"
-- Cờ mang theo trong TeleportData để server riêng biết đây là người đang quay vòng.
local RETURN_FLAG = "softShutdownReturn"

-- Bao lâu cho người chơi đọc thông báo trước khi bị dời. Đủ để hiểu chuyện gì đang xảy ra,
-- đủ ngắn để `BindToClose` (ngân sách ~30s của Roblox) vẫn kịp làm nốt phần teleport.
local WARN_SECONDS = 6
-- Rank tối thiểu trong group để gọi lệnh `/update`. 250+ = nhóm quản trị của group.
local ADMIN_MIN_RANK = 250

local shuttingDown = false

--[[
	Server này có phải server RIÊNG dùng làm trạm trung chuyển không?

	`PrivateServerId ~= ""` là "server riêng"; `PrivateServerOwnerId == 0` phân biệt server
	RESERVED (do code tạo) với VIP server (do người chơi mua). Ta chỉ tạo loại reserved.
]]
local function isReservedServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function notify(message: string)
	for _, player in Players:GetPlayers() do
		pcall(GamePackets.toast.sendTo, { kind = "teleport", message = message, amount = 0 }, player)
	end
end

--[[
	Đưa một danh sách người chơi sang server riêng rồi để họ tự quay về.
	Trả về true nếu lệnh teleport đã được nhận (KHÔNG đảm bảo họ tới nơi).
]]
local function migrate(players: { Player }): boolean
	if #players == 0 then
		return true
	end

	local ok, accessCode = pcall(function()
		return TeleportService:ReserveServerAsync(game.PlaceId)
	end)
	if not ok or type(accessCode) ~= "string" then
		warn(`[SoftShutdownService] ReserveServer hỏng: {tostring(accessCode)}`)
		return false
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({ [RETURN_FLAG] = true })

	local sent, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players, options)
	end)
	if not sent then
		warn(`[SoftShutdownService] TeleportAsync hỏng: {tostring(err)}`)
		return false
	end
	return true
end

-- Chỉ chạy từ lệnh quản trị; BindToClose đã giao việc chuyển server cho Roblox.
local function beginSoftShutdown()
	if shuttingDown then
		return
	end
	shuttingDown = true

	notify("Server is updating — moving you to a fresh one")
	task.wait(WARN_SECONDS)

	if not migrate(Players:GetPlayers()) then
		-- Không dời được thì THÔI, không đá ai cả. Server sống tiếp; lần publish sau hoặc
		-- lúc nó tự rỗng sẽ giải quyết.
		notify("Update deferred — you can keep playing")
		shuttingDown = false
		return
	end

	-- Ai vào SAU lúc này (matchmaking vẫn có thể nhét người vào) cũng phải được dời theo,
	-- nếu không họ mắc kẹt trên một server sắp chết.
	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		if player.Parent then
			migrate({ player })
		end
	end)
end

--[[
	Người chơi vừa tới SERVER RIÊNG mang cờ quay vòng ⇒ đẩy ngược về place công khai ngay.

	Không `TeleportOptions` nào ở đây: teleport "trần" về `game.PlaceId` là đi qua matchmaking
	công khai, và vì server cũ của họ đang tắt nên họ sẽ rơi vào một server MỚI (build mới).
]]
local function handleReturningPlayer(player: Player)
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if type(teleportData) ~= "table" or teleportData[RETURN_FLAG] ~= true then
		return
	end

	task.spawn(function()
		GamePackets.toast.sendTo({ kind = "teleport", message = "Loading the new version…", amount = 0 }, player)
		-- Một nhịp thở để client kịp dựng UI trước khi màn hình teleport phủ lên.
		task.wait(1)
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player })
		end)
		if not ok then
			warn(`[SoftShutdownService] không trả người chơi về được: {tostring(err)}`)
		end
	end)
end

--[[
	Lệnh `/update` trong khung chat, chỉ dành cho quản trị group.

	Vì sao là lệnh chat chứ không phải Open Cloud: Open Cloud MessagingService cần API key mà
	dự án chưa cấu hình. Lệnh chat chạy được ngay hôm nay, từ điện thoại, không cần công cụ gì.
	Nó chỉ PHÁT tin nhắn — chính server đang chứa người gõ cũng nhận lại qua MessagingService,
	nên không có nhánh xử lý riêng nào để lệch nhau.
]]
local function registerAdminCommand()
	local command = Instance.new("TextChatCommand")
	command.Name = "SoftShutdownCommand"
	command.PrimaryAlias = "/update"
	command.SecondaryAlias = "/softshutdown"
	command.Parent = TextChatService

	command.Triggered:Connect(function(source: TextSource)
		local player = Players:GetPlayerByUserId(source.UserId)
		if not player or NetRateLimit.ShouldDrop(player, "softShutdownCommand") then
			return
		end
		local ok, rank = pcall(function()
			return player:GetRankInGroup(GroupChestConfig.GROUP_ID)
		end)
		if not ok or type(rank) ~= "number" or rank < ADMIN_MIN_RANK then
			GamePackets.toast.sendTo({ kind = "error", message = "Not allowed", amount = 0 }, player)
			return
		end

		local sent, err = pcall(function()
			MessagingService:PublishAsync(TOPIC, tostring(os.time()))
		end)
		if sent then
			print(`[SoftShutdownService] {player.Name} đã phát lệnh soft shutdown cho toàn universe`)
		else
			warn(`[SoftShutdownService] PublishAsync hỏng: {tostring(err)}`)
			GamePackets.toast.sendTo({ kind = "error", message = "Broadcast failed", amount = 0 }, player)
		end
	end)
end

function SoftShutdownService.Init() end

function SoftShutdownService.Start()
	if RunService:IsStudio() then
		-- MessagingService/TeleportService không chạy trong Studio; im lặng thoát để playtest
		-- không đầy warning không liên quan.
		return
	end

	if isReservedServer() then
		-- Trạm trung chuyển: KHÔNG đăng ký gì khác, chỉ đẩy người quay về.
		for _, player in Players:GetPlayers() do
			handleReturningPlayer(player)
		end
		Players.PlayerAdded:Connect(handleReturningPlayer)
		print("[SoftShutdownService] server trung chuyển — trả người chơi về place công khai")
		return
	end

	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function()
			task.spawn(beginSoftShutdown)
		end)
	end)
	if not ok then
		warn(`[SoftShutdownService] SubscribeAsync hỏng: {tostring(err)}`)
	end

	--[[
		⚠️ SỬA 2026-08-27 — KHÔNG teleport trong `BindToClose` nữa. CHỈ báo cho người chơi.

		Bản đầu tiên chạy trọn soft shutdown ở đây, với lý do "biến cú đá thô của Dashboard
		thành chuyển server êm". Lý do đó SAI, vì nó dựa trên một giả định chưa kiểm chứng về
		nền tảng. Tra lại tài liệu chính thức (create.roblox.com/docs/projects/update-experiences):

		Creator Dashboard đã có sẵn **Configure → Server Management → Restart Servers**, và nó
		làm ĐÚNG việc này, tốt hơn ta làm được:
		  • NGỪNG MATCHMAKING vào server cũ — script không có API nào làm được điều đó.
		  • Chờ một khoảng do bạn đặt, 1–60 phút, cho người chơi tự rời (bleed-off).
		  • Rồi TỰ ĐỘNG teleport người còn lại sang server thay thế đã cập nhật.

		Tức là Roblox đã tự teleport người chơi khi `BindToClose` nổ. Nếu ta CŨNG teleport họ
		sang một reserved server ở đúng lúc đó thì hai bên giành nhau một người chơi: thêm một
		màn hình loading, và tệ hơn là họ đi vòng qua một server khác nên phiên dữ liệu bị
		churn thêm một nhịp không cần thiết.

		Giữ lại đúng phần Roblox KHÔNG làm: một dòng báo cho người chơi hiểu chuyện gì đang xảy
		ra. Phần teleport để nền tảng lo.
	]]
	game:BindToClose(function()
		notify("Server is updating — you'll be moved automatically")
		-- Nhịp thở để gói toast kịp đi trước khi server đóng. KHÔNG chặn lâu: Roblox chỉ giữ
		-- server sống chừng nào callback này chưa trả về, mà nó còn phải teleport người chơi.
		task.wait(1)
	end)

	pcall(registerAdminCommand)
end

return SoftShutdownService
