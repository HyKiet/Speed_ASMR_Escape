--!strict
-- Server đọc điểm từ DataService, ghi bảng xếp hạng rồi cập nhật SurfaceGui trong map.
-- OrderedDataStore chỉ là chỉ mục xếp hạng; dữ liệu người chơi vẫn do ProfileStore giữ.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Env = require(ReplicatedStorage.Shared.Util.Env)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

type BoardConfig = {
	modelName: string,
	title: string,
	-- Chuỗi dán TRƯỚC/SAU con số. Bảng Donate dùng prefix là ký tự Robux thay vì hậu tố
	-- " R$" (xem ROBUX_GLYPH).
	valuePrefix: string?,
	valueSuffix: string,
	storeName: string,
	dataKey: string,
	accent: Color3,
	darkAccent: Color3,
}

-- CHỈ giữ userId + value. Tên và ảnh đại diện tra từ cache TẠI LÚC VẼ, không nhúng vào
-- entry — xem khối "TRA CỨU TÊN/ẢNH" bên dưới để hiểu vì sao.
type RankedEntry = {
	userId: number,
	value: number,
}

local TOP_LIMIT = 50
local MAX_ORDERED_VALUE = 9e15

--[[
	NHỊP ĐỘ Ở QUY MÔ HÀNG NGÀN CCU
	==============================
	Bản cũ: một vòng lặp 60s làm CẢ ba việc (ghi điểm mọi người chơi + đọc 3 bảng + vẽ lại 3
	bảng). Ở vài trăm CCU thì không sao; ở vài ngàn (≈100+ server chạy song song) thì hỏng ở
	ba chỗ khác nhau, nên giờ tách thành ba nhịp riêng:

	1. `PUBLISH_SECONDS` (ghi OrderedDataStore) — 120s. Điểm của một người chơi thay đổi liên
	   tục nhưng bảng chỉ hiện TOP 50 TOÀN GAME, ghi dày hơn không làm bảng chính xác hơn chút
	   nào. Vẫn ghi ngay lúc người chơi rời (`PlayerRemoving`) nên không mất điểm.

	2. `REFRESH_SECONDS` (đọc `GetSortedAsync`) — 180s. Đây là lệnh ĐẮT nhất và bị bóp theo
	   TOÀN GAME chứ không theo từng server: 100 server × 3 bảng mỗi 60s = 300 lệnh/phút dồn
	   vào 3 store. Giãn lên 180s cắt còn 1/3 mà người chơi gần như không nhận ra khác biệt —
	   top 50 toàn game không đổi trong 1 phút.

	3. `JITTER_SECONDS` — mấu chốt dễ bỏ sót. Mọi server khởi động cùng lúc sau một đợt update
	   sẽ gọi DataStore CÙNG MỘT GIÂY, tạo đỉnh tải nhọn rồi bị throttle hàng loạt. Cộng thêm
	   một lượng ngẫu nhiên vào mỗi lần chờ để trải đều các server ra.

	Khi bị throttle thì `BACKOFF_MULTIPLIER` giãn dần khoảng chờ (tối đa `MAX_BACKOFF_SECONDS`)
	thay vì đâm đầu gọi lại đúng nhịp cũ — càng retry dày càng bị bóp lâu.
]]
local PUBLISH_SECONDS = 120
local REFRESH_SECONDS = 180
local JITTER_SECONDS = 30
local BACKOFF_MULTIPLIER = 2
local MAX_BACKOFF_SECONDS = 900
local STUDS_TEXTURE = "rbxassetid://6372755229"
local DEFAULT_AVATAR = "rbxasset://textures/ui/GuiImagePlaceholder.png"

--[[
	Ký tự Robux của Roblox (U+E002, vùng private-use trong font hệ thống) — CÙNG ký tự mà
	ShopModal/TeleportModal đang dùng cho giá Robux. Thay cho chuỗi " R$" viết tay: biểu tượng
	đọc ra ngay ở khoảng cách xa, và ngắn hơn 2 ký tự nên đỡ chật ô số.

	── KÍCH THƯỚC HÀNG (2026-08-09, user báo chữ đè lên nhau) ──────────────────────────────
	Lỗi cũ nằm ở chỗ TRỘN gốc offset với bề rộng scale: tên đặt tại x=184 (offset) nhưng rộng
	`0.42` (scale), còn ô số bắt đầu ở `0.62` scale. Trên canvas 800px thì tên trải 184→520
	trong khi số bắt đầu ở 496 ⇒ chồng nhau 24px, tên càng dài càng lấn.
	Giờ ô SỐ neo vào MÉP PHẢI với bề rộng CỐ ĐỊNH, còn tên ăn hết phần thừa ở giữa
	(`UDim2.new(1, -(NAME_LEFT + VALUE_W + GAP), ...)`) — hai ô không bao giờ đụng nhau nữa
	dù panel rộng bao nhiêu.
	Kèm theo: mọi TextScaled đều có `UITextSizeConstraint` chặn trên, vì TextScaled trong ô
	cao 54px sẽ kéo chữ lên 54px — to quá mức cần thiết và chính là thứ làm bảng trông chật.
]]
local ROBUX_GLYPH = "\u{E002}"

--[[
	CỠ HÀNG (2026-08-10) — canvas thật của mỗi bảng là 800×1000 px (SurfaceGui FixedSize,
	đo trong Studio), tức bề rộng hàng dùng được chỉ ~750px sau padding.

	Bản trước để hàng cao 74px với chữ 24px: mỗi hàng chiếm gần 1/10 chiều cao bảng, chỉ
	thấy ~10 người trong khi bảng hiện TOP 50, và ô số 224px ăn gần 1/3 bề ngang nên tên
	dài bị cắt sớm. Thu nhỏ đồng loạt (hàng 58px, chữ ≤20px) cho ~13 hàng trong khung và
	trả ~90px bề ngang lại cho cột tên.

	Ràng buộc bất biến: NAME_LEFT + VALUE_W + COLUMN_GAP + 12 phải < 750, nếu không cột
	tên có bề rộng ÂM và chữ sẽ đè lên ô số.

	── NỚI CHỮ TO LẠI (2026-08-26, user: "chữ nhỏ quá") ────────────────────────────────────
	Bản 2026-08-10 thu nhỏ hơi tay: ≤20px trên một bảng người chơi đứng CÁCH XA vài chục stud
	để đọc thì gần như không đọc nổi tên. Nay chữ lên ≤24px, và vì `ROW_ITEM_H` (chiều cao ô
	chữ) là thứ TextScaled bám vào, nó phải nới theo — không thì cap mới vô nghĩa.
	Đổi lại: hàng cao 64px ⇒ trong khung thấy ~12 hàng thay vì ~13. Vẫn cuộn tới top 50.
	`VALUE_W` nới 178 → 196 để số 7 chữ số + hậu tố " WINS" không bị TextScaled bóp xuống
	dưới cap mới (ô số hẹp thì cap có to mấy chữ vẫn nhỏ).
]]
local ROW_HEIGHT = 64
local ROW_ITEM_H = 46 -- chiều cao ô chữ trong hàng; TextScaled bám vào số này
local ROW_ITEM_Y = (ROW_HEIGHT - ROW_ITEM_H) // 2
local RANK_W = 54
local AVATAR_SIZE = 48
local NAME_LEFT = RANK_W + AVATAR_SIZE + 18 -- 120: rank + avatar + các khe hở
local VALUE_W = 196
local COLUMN_GAP = 10

local TEXT_MAX_RANK = 24
local TEXT_MAX_NAME = 23
local TEXT_MAX_VALUE = 23

local BOARD_CONFIGS: { BoardConfig } = {
	{
		modelName = "Top_Speeds",
		title = "TOP SPEED",
		valueSuffix = " SPEED",
		storeName = "SpeedEscape_TopSpeed_v1",
		dataKey = "Speed",
		accent = Color3.fromRGB(46, 204, 113),
		darkAccent = Color3.fromRGB(0, 117, 79),
	},
	{
		modelName = "Top_Wins",
		title = "TOP WINS",
		valueSuffix = " WINS",
		storeName = "SpeedEscape_TopWins_v1",
		dataKey = "TotalWins",
		accent = Color3.fromRGB(255, 190, 34),
		darkAccent = Color3.fromRGB(180, 86, 0),
	},
	{
		modelName = "Top_Donate",
		title = "TOP DONATE",
		valuePrefix = ROBUX_GLYPH .. " ",
		valueSuffix = "",
		storeName = "SpeedEscape_TopDonate_v1",
		dataKey = "TotalDonatedRobux",
		accent = Color3.fromRGB(52, 152, 219),
		darkAccent = Color3.fromRGB(0, 82, 160),
	},
}

local stores: { [string]: OrderedDataStore } = {}
local boardRoots: { [string]: Frame } = {}
local entriesByBoard: { [string]: { RankedEntry } } = {}
local avatarCache: { [number]: string } = {}
local nameCache: { [number]: string } = {}
local lastPublishedValues: { [string]: { [number]: number } } = {}

--[[
	TRA CỨU TÊN/ẢNH — VÌ SAO PHẢI TÁCH KHỎI VÒNG REFRESH
	====================================================
	Bản cũ gọi `GetNameFromUserIdAsync` + `GetUserThumbnailAsync` NGAY TRONG
	`refreshEntries`, tuần tự, cho tới 50 người × 3 bảng. Một server vừa khởi động phải nuốt
	~300 lệnh web nối đuôi nhau trước khi vẽ được bảng đầu tiên. Hai API này bị bóp theo
	TỪNG SERVER, nên chuỗi hậu quả rất gọn: refresh kéo dài hàng phút → bị throttle → tên
	rơi hết về "Player 12345" → vòng sau lại gọi lại đúng ngần ấy. Nhân với 100+ server
	cùng khởi động sau một đợt update là tự tạo một đợt tấn công vào chính API của mình.

	Giờ tách làm hai:
	• Vòng refresh chỉ đọc OrderedDataStore rồi VẼ NGAY bằng những gì đã có trong cache.
	  Số liệu (thứ quan trọng nhất) hiện tức thì; tên chưa có thì tạm hiển thị "Player {id}".
	• Một coroutine DUY NHẤT rút hàng đợi, tra tối đa `LOOKUP_CONCURRENCY` người một lô,
	  nghỉ giữa các lô, xong thì tăng `resolveEpoch` để `renderAll` biết cần vẽ lại.

	`failUntil`: userId hỏng (đã xoá tài khoản, hoặc key rác do test ghi vào) sẽ fail VĨNH
	VIỄN. Bản cũ không nhớ thất bại của tên nên gọi lại mỗi 180s, mãi mãi, cho từng ID rác.
	Nhớ mốc thất bại và chỉ thử lại sau `LOOKUP_RETRY_SECONDS`.
]]
local LOOKUP_CONCURRENCY = 4
local LOOKUP_BATCH_PAUSE = 0.35
local LOOKUP_RETRY_SECONDS = 600

local nameFailUntil: { [number]: number } = {}
local avatarFailUntil: { [number]: number } = {}
local lookupQueue: { [number]: boolean } = {}
local lookupRunning = false

-- Tăng mỗi khi có tên/ảnh mới về. Ghép vào chữ ký của bảng để `renderAll` phân biệt được
-- "thứ hạng y hệt nhưng vừa có thêm tên" với "không có gì đổi".
local resolveEpoch = 0

local DataService

local LeaderboardService = {}

local function create(className: string, properties: { [string]: any }?, parent: Instance?): Instance
	local instance = Instance.new(className)
	if properties then
		for key, value in properties do
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function addCorner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function addStroke(parent: Instance, color: Color3, thickness: number)
	create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness,
	}, parent)
end

local function addStuds(parent: Instance, transparency: number, zIndex: number)
	create("ImageLabel", {
		BackgroundTransparency = 1,
		Image = STUDS_TEXTURE,
		ImageTransparency = transparency,
		Position = UDim2.fromScale(0, 0),
		ScaleType = Enum.ScaleType.Tile,
		Size = UDim2.fromScale(1, 1),
		TileSize = UDim2.fromOffset(30, 30),
		ZIndex = zIndex,
	}, parent)
end

-- Chặn TRÊN cho TextScaled. Không có nó thì chữ luôn phình bằng chiều cao ô.
local function addTextSizeCap(parent: Instance, maxSize: number)
	create("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8 }, parent)
end

local function formatNumber(value: number): string
	if value >= 1e12 then
		return string.format("%.2fT", value / 1e12)
	elseif value >= 1e9 then
		return string.format("%.2fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.2fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.2fK", value / 1e3)
	end
	return tostring(math.floor(value))
end

-- Người đang ở trong server này thì đã có sẵn tên, khỏi tốn một lệnh web.
local function seedFromOnlinePlayers()
	for _, player in Players:GetPlayers() do
		if player.UserId > 0 then
			nameCache[player.UserId] = player.Name
		end
	end
end

-- KHÔNG yield. Trả về cái đang có; thiếu thì xếp hàng để coroutine nền lo.
local function queueLookup(userId: number)
	if lookupQueue[userId] then
		return
	end
	local now = os.clock()
	local needName = nameCache[userId] == nil and (nameFailUntil[userId] or 0) < now
	local needAvatar = avatarCache[userId] == nil and (avatarFailUntil[userId] or 0) < now
	if needName or needAvatar then
		lookupQueue[userId] = true
	end
end

local function getCachedName(userId: number): string
	return nameCache[userId] or `Player {userId}`
end

local function getCachedAvatar(userId: number): string
	return avatarCache[userId] or DEFAULT_AVATAR
end

local function resolveOne(userId: number)
	local now = os.clock()

	if nameCache[userId] == nil and (nameFailUntil[userId] or 0) < now then
		local success, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		if success then
			nameCache[userId] = result
			resolveEpoch += 1
		else
			-- Nhớ thất bại có HẠN. Vĩnh viễn thì một lần API bị bóp sẽ đóng đinh
			-- "Player 12345" tới lúc restart; không nhớ gì thì gọi lại vô hạn cho ID rác.
			nameFailUntil[userId] = now + LOOKUP_RETRY_SECONDS
		end
	end

	if avatarCache[userId] == nil and (avatarFailUntil[userId] or 0) < now then
		local success, image = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
		if success then
			avatarCache[userId] = image
			resolveEpoch += 1
		else
			avatarFailUntil[userId] = now + LOOKUP_RETRY_SECONDS
		end
	end
end

-- Khai báo trước: `startLookupWorker` gọi lại nó sau mỗi lô để bảng cập nhật dần.
local renderAllBoards: () -> ()

local function startLookupWorker()
	if lookupRunning then
		return
	end
	lookupRunning = true

	task.spawn(function()
		while true do
			local batch: { number } = {}
			for userId in lookupQueue do
				lookupQueue[userId] = nil
				table.insert(batch, userId)
				if #batch >= LOOKUP_CONCURRENCY then
					break
				end
			end

			if #batch == 0 then
				lookupRunning = false
				return
			end

			-- Chạy song song trong LÔ, nhưng chỉ `LOOKUP_CONCURRENCY` cái một lúc: đủ nhanh
			-- để bảng đầy tên trong vài giây, đủ chậm để không tự bóp API của mình.
			local remaining = #batch
			for _, userId in batch do
				task.spawn(function()
					resolveOne(userId)
					remaining -= 1
				end)
			end
			while remaining > 0 do
				task.wait(0.1)
			end

			renderAllBoards()
			task.wait(LOOKUP_BATCH_PAUSE)
		end
	end)
end

local function getBoardRoot(config: BoardConfig): Frame?
	local folder = Workspace:FindFirstChild("LeaderBoard", true)
	local model = folder and folder:FindFirstChild(config.modelName)
	local panel = model and model:FindFirstChild("DisplayPanel")
	local surfaceGui = panel and panel:FindFirstChildWhichIsA("SurfaceGui")
	local root = surfaceGui and surfaceGui:FindFirstChild("Frame")
	if not root or not root:IsA("Frame") then
		warn(`[LeaderboardService] Missing {config.modelName}.DisplayPanel.SurfaceGui.Frame`)
		return nil
	end

	root:ClearAllChildren()
	root.BackgroundColor3 = Color3.fromRGB(9, 22, 42)
	root.BorderSizePixel = 0
	root.ZIndex = 0

	local header = create("Frame", {
		BackgroundColor3 = config.accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 104),
		ZIndex = 1,
	}, root)
	addCorner(header, 20)
	addStroke(header, config.darkAccent, 5)
	addStuds(header, 0.72, 2)

	local titleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 54),
		Text = config.title,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0,
		ZIndex = 3,
	}, header)
	addTextSizeCap(titleLabel, 48)

	local subtitleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.new(1, -24, 0, 28),
		-- Nhắc kéo: ScrollingFrame trên SurfaceGui thế giới KHÔNG nhận lăn chuột, chỉ nhận
		-- kéo-thả. Không nói ra thì người chơi tưởng bảng chỉ có mười mấy người.
		Text = `GLOBAL TOP {TOP_LIMIT}  •  DRAG TO SCROLL`,
		TextColor3 = Color3.fromRGB(255, 245, 171),
		TextScaled = true,
		TextStrokeTransparency = 0.2,
		ZIndex = 3,
	}, header)
	addTextSizeCap(subtitleLabel, 22)

	-- Danh sách CUỘN (top 50) thay cho phân trang tự lật.
	local list = create("ScrollingFrame", {
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Name = "RankList",
		Position = UDim2.fromOffset(18, 130),
		Size = UDim2.new(1, -36, 1, -148),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = config.accent,
		ZIndex = 1,
	}, root)
	create("UIListLayout", {
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, list)
	create("UIPadding", { PaddingRight = UDim.new(0, 14) }, list)

	return root :: Frame
end

local function createRankRow(parent: Instance, config: BoardConfig, entry: RankedEntry, rank: number)
	local isTopThree = rank <= 3
	local rowColor = if isTopThree then config.darkAccent:Lerp(config.accent, 0.38) else Color3.fromRGB(20, 47, 78)
	local rankColor = if rank == 1
		then Color3.fromRGB(255, 220, 64)
		elseif rank == 2 then Color3.fromRGB(230, 238, 255)
		elseif rank == 3 then Color3.fromRGB(255, 167, 89)
		else Color3.fromRGB(173, 209, 255)

	local container = create("Frame", {
		BackgroundColor3 = rowColor,
		BorderSizePixel = 0,
		LayoutOrder = rank,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		ZIndex = 2,
	}, parent)
	addCorner(container, 11)
	addStroke(container, if isTopThree then rankColor else Color3.fromRGB(45, 100, 148), 2.5)

	local rankLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(8, ROW_ITEM_Y),
		Size = UDim2.fromOffset(RANK_W, ROW_ITEM_H),
		Text = `#{rank}`,
		TextColor3 = rankColor,
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0,
		ZIndex = 3,
	}, container)
	addTextSizeCap(rankLabel, TEXT_MAX_RANK)

	local avatar = create("ImageLabel", {
		BackgroundColor3 = Color3.fromRGB(236, 245, 255),
		Image = getCachedAvatar(entry.userId),
		Position = UDim2.fromOffset(RANK_W + 12, (ROW_HEIGHT - AVATAR_SIZE) // 2),
		Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
		ZIndex = 3,
	}, container)
	addCorner(avatar, AVATAR_SIZE // 2)
	addStroke(avatar, Color3.fromRGB(255, 255, 255), 2.5)

	-- Tên: ăn hết phần thừa GIỮA avatar và ô số. Bề rộng tính bằng scale-trừ-offset nên ô số
	-- luôn còn nguyên chỗ của nó, tên dài mấy cũng chỉ tự co chữ lại chứ không tràn sang.
	local nameLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(NAME_LEFT, ROW_ITEM_Y),
		Size = UDim2.new(1, -(NAME_LEFT + VALUE_W + COLUMN_GAP + 12), 0, ROW_ITEM_H),
		Text = getCachedName(entry.userId),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextStrokeTransparency = 0.35,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, container)
	addTextSizeCap(nameLabel, TEXT_MAX_NAME)

	-- Ô số neo vào MÉP PHẢI, bề rộng cố định.
	local valueLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(1, -(VALUE_W + 12), 0, ROW_ITEM_Y),
		Size = UDim2.fromOffset(VALUE_W, ROW_ITEM_H),
		Text = (config.valuePrefix or "") .. formatNumber(entry.value) .. config.valueSuffix,
		TextColor3 = Color3.fromRGB(255, 244, 169),
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.1,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	}, container)
	addTextSizeCap(valueLabel, TEXT_MAX_VALUE)
end

-- Chữ ký của một bảng — dùng để bỏ qua lần VẼ LẠI khi thứ hạng không đổi.
-- ⚠️ Phải khai báo TRƯỚC `renderAll`: `renderAll` được gọi ngay trong `Init()`, đặt hàm này
-- xuống dưới là "attempt to call a nil value" và cả service chết ngay lúc nạp.
local function signatureOf(entries: { RankedEntry }): string
	local parts = table.create(#entries + 1)
	for index, entry in entries do
		parts[index] = `{entry.userId}:{entry.value}`
	end
	-- Epoch ở CUỐI: thứ hạng không đổi nhưng vừa có tên/ảnh mới về thì vẫn phải vẽ lại.
	parts[#entries + 1] = `e{resolveEpoch}`
	return table.concat(parts, "|")
end

-- modelName → chữ ký của lần vẽ gần nhất.
local renderedSignatures: { [string]: string } = {}

local function renderAll(config: BoardConfig)
	local root = boardRoots[config.modelName]
	if not root then
		return
	end

	local list = root:FindFirstChild("RankList")
	if not list then
		return
	end

	-- Mỗi lần vẽ là huỷ rồi dựng lại 50 hàng × ~6 instance = ~300 instance cho MỖI bảng. Top
	-- 50 toàn game thường đứng yên hàng chục phút, nên vẽ lại y hệt là đốt CPU + tạo rác GC
	-- vô ích, còn gây khựng nhẹ đều đặn trên mọi server. Chỉ vẽ khi thứ hạng THẬT SỰ đổi.
	local signature = signatureOf(entriesByBoard[config.modelName] or {})
	if renderedSignatures[config.modelName] == signature then
		return
	end
	renderedSignatures[config.modelName] = signature

	-- Xoá row cũ nhưng GIỮ UIListLayout + UIPadding.
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local entries = entriesByBoard[config.modelName] or {}
	if #entries == 0 then
		local empty = create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 84),
			Text = "NO RANKED PLAYERS YET",
			TextColor3 = Color3.fromRGB(167, 205, 255),
			TextScaled = true,
			ZIndex = 2,
		}, list)
		addTextSizeCap(empty, 30)
		return
	end

	for rank = 1, math.min(#entries, TOP_LIMIT) do
		createRankRow(list, config, entries[rank], rank)
	end
end

-- Gán vào biến đã khai báo phía trên (coroutine tra cứu gọi nó sau mỗi lô).
renderAllBoards = function()
	for _, config in BOARD_CONFIGS do
		renderAll(config)
	end
end

local function getOnlineFallback(config: BoardConfig): { RankedEntry }
	local entries = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.GetData(player)
		local value = data and data[config.dataKey]
		if typeof(value) == "number" and player.UserId > 0 and value > 0 then
			nameCache[player.UserId] = player.Name
			queueLookup(player.UserId)
			table.insert(entries, {
				userId = player.UserId,
				value = value,
			})
		end
	end
	table.sort(entries, function(a, b)
		return a.value > b.value
	end)
	return entries
end

-- Trả về true nếu gọi DataStore thành công (để vòng lặp biết có phải giãn backoff không).
local function refreshEntries(config: BoardConfig): boolean
	local store = stores[config.modelName]
	local success, pages = pcall(store.GetSortedAsync, store, false, TOP_LIMIT)
	if not success then
		entriesByBoard[config.modelName] = getOnlineFallback(config)
		return false
	end

	local entries = {}
	for _, orderedEntry in pages:GetCurrentPage() do
		local userId = tonumber(orderedEntry.key)
		-- Lọc RÁC ở đầu đọc, không chỉ đầu ghi: kho hiện tại đã có sẵn key `-1`/`-2` (người
		-- chơi test của Studio) và cả một dãy userId bịa từ một lần seed test cũ. Sửa chỗ
		-- ghi không làm sạch được thứ đã nằm trong kho.
		if userId and userId > 0 and orderedEntry.value > 0 then
			queueLookup(userId)
			table.insert(entries, {
				userId = userId,
				value = orderedEntry.value,
			})
		end
	end
	entriesByBoard[config.modelName] = entries
	startLookupWorker()
	return true
end

local function publishPlayer(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	-- ⚠️ Người chơi test của Studio mang UserId ÂM (-1, -2, …). Bản cũ publish thẳng, nên
	-- kho Live đã có `-1`/`-2` đứng đầu bảng với 1.000.000 Wins. Không tài khoản Roblox
	-- thật nào có UserId ≤ 0, nên chặn ở đây là chặn đúng và chặn hết.
	if player.UserId <= 0 then
		return
	end

	for _, config in BOARD_CONFIGS do
		local value = data[config.dataKey]
		-- Bỏ qua mốc 0: bảng Donate mà ghi mọi người chơi đều thành một rừng key giá trị 0,
		-- vừa tốn ghi vừa không bao giờ lọt top.
		if typeof(value) == "number" and value > 0 then
			local safeValue = math.clamp(math.floor(value), 1, MAX_ORDERED_VALUE)
			local published = lastPublishedValues[config.modelName]
			if published[player.UserId] ~= safeValue then
				published[player.UserId] = safeValue
				task.spawn(function()
					local success, err = pcall(
						stores[config.modelName].SetAsync,
						stores[config.modelName],
						tostring(player.UserId),
						safeValue
					)
					if not success then
						-- Lần ghi lỗi phải được thử lại, kể cả khi điểm không đổi.
						if published[player.UserId] == safeValue then
							published[player.UserId] = nil
						end
						if not RunService:IsStudio() then
							warn(`[LeaderboardService] Failed to publish {config.modelName}: {err}`)
						end
					end
				end)
			end
		end
	end
end

function LeaderboardService.Init()
	DataService = ServiceLocator.Get("DataService")

	for _, config in BOARD_CONFIGS do
		stores[config.modelName] = DataStoreService:GetOrderedDataStore(Env.StoreName(config.storeName))
		lastPublishedValues[config.modelName] = {}
		local root = getBoardRoot(config)
		if root then
			boardRoots[config.modelName] = root
			entriesByBoard[config.modelName] = {}
			renderAll(config)
		end
	end
end

function LeaderboardService.Start()
	-- Vòng GHI: đẩy điểm người chơi lên OrderedDataStore.
	task.spawn(function()
		task.wait(2 + math.random() * JITTER_SECONDS)
		while true do
			for _, player in Players:GetPlayers() do
				publishPlayer(player)
			end
			task.wait(PUBLISH_SECONDS + math.random() * JITTER_SECONDS)
		end
	end)

	-- Vòng ĐỌC + VẼ: tách khỏi vòng ghi vì đây mới là lệnh đắt và bị bóp theo toàn game.
	task.spawn(function()
		local backoff = 0
		-- Đọc ngay một lần lúc khởi động (lệch ngẫu nhiên) để bảng có số liền, không phải
		-- chờ trọn một chu kỳ mới hiện.
		task.wait(3 + math.random() * JITTER_SECONDS)
		while true do
			local allOk = true
			for _, config in BOARD_CONFIGS do
				if not refreshEntries(config) then
					allOk = false
				end
				renderAll(config)
			end

			if allOk then
				backoff = 0
			else
				-- Lần đầu hỏng thì lùi đúng một chu kỳ, các lần sau nhân đôi dần.
				backoff = math.min(
					if backoff == 0 then REFRESH_SECONDS else backoff * BACKOFF_MULTIPLIER,
					MAX_BACKOFF_SECONDS
				)
				warn(
					`[LeaderboardService] DataStore lỗi/bị bóp — chờ thêm {math.floor(backoff)}s trước khi thử lại.`
				)
			end

			task.wait(REFRESH_SECONDS + backoff + math.random() * JITTER_SECONDS)
		end
	end)

	-- Người trong server này là nguồn tên MIỄN PHÍ: nhặt sẵn để coroutine tra cứu khỏi phải
	-- gọi web cho chính những người đang đứng cạnh bảng.
	seedFromOnlinePlayers()
	Players.PlayerAdded:Connect(function(player)
		if player.UserId > 0 then
			nameCache[player.UserId] = player.Name
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		publishPlayer(player)
		for _, published in lastPublishedValues do
			published[player.UserId] = nil
		end
	end)
end

--[[
	Dọn key hỏng khỏi OrderedDataStore của MÔI TRƯỜNG ĐANG CHẠY.

	Lọc lúc đọc chỉ giấu rác đi chứ không xoá được nó: key rác vẫn chiếm suất trong 50 bản
	ghi mà `GetSortedAsync` trả về, nên nếu có 10 key rác thì bảng thật chỉ còn 40 người.
	Hàm này xoá hẳn.

	Không tự chạy — gọi tay từ command bar khi cần:
		require(...LeaderboardService).PurgeInvalidKeys()
	Trả về số key đã xoá trên mỗi bảng.
]]
function LeaderboardService.PurgeInvalidKeys(extraKeys: { number }?): { [string]: number }
	local removed: { [string]: number } = {}

	for _, config in BOARD_CONFIGS do
		local store = stores[config.modelName]
		if not store then
			continue
		end

		local count = 0
		local ok, pages = pcall(store.GetSortedAsync, store, false, 100)
		if ok then
			for _, orderedEntry in pages:GetCurrentPage() do
				local userId = tonumber(orderedEntry.key)
				local invalid = userId == nil or userId <= 0 or orderedEntry.value <= 0
				if not invalid and extraKeys then
					for _, key in extraKeys do
						if key == userId then
							invalid = true
							break
						end
					end
				end
				if invalid then
					local removeOk = pcall(store.RemoveAsync, store, orderedEntry.key)
					if removeOk then
						count += 1
					end
					task.wait(0.1)
				end
			end
		end
		removed[config.modelName] = count
	end

	renderedSignatures = {}
	return removed
end

function LeaderboardService.RecordDonation(player: Player, robuxAmount: number): boolean
	local data = DataService.GetData(player)
	if not data or robuxAmount <= 0 or robuxAmount ~= robuxAmount or math.abs(robuxAmount) == math.huge then
		return false
	end

	data.TotalDonatedRobux += math.floor(robuxAmount)
	publishPlayer(player)
	return true
end

return LeaderboardService
