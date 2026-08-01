--!strict
-- 3 bảng xếp hạng SurfaceGui (TopSpeed / TopWins / TopDonate) trong Workspace.LeaderBoard.

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
	valueSuffix: string,
	storeName: string,
	dataKey: string,
	accent: Color3,
	darkAccent: Color3,
}

type RankedEntry = {
	userId: number,
	name: string,
	value: number,
	avatar: string,
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
		valueSuffix = " R$",
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

local function getDisplayName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end

	local success, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	-- ⚠️ CHỈ cache khi gọi THÀNH CÔNG. Cache cả lần thất bại thì một lần API bị bóp (rất dễ
	-- xảy ra khi đông server cùng gọi) sẽ đóng đinh "Player 12345" trên bảng xếp hạng cho
	-- tới khi server restart — không có đường tự sửa.
	if not success then
		return `Player {userId}`
	end
	nameCache[userId] = result
	return result
end

local function getAvatar(userId: number): string
	local cached = avatarCache[userId]
	if cached then
		return cached
	end

	local success, image = pcall(
		Players.GetUserThumbnailAsync,
		Players,
		userId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size150x150
	)
	-- Cùng lý do như getDisplayName: thất bại thì trả tạm ảnh mặc định nhưng KHÔNG cache,
	-- để vòng refresh sau còn thử lại được.
	if not success then
		return DEFAULT_AVATAR
	end
	avatarCache[userId] = image
	return image
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
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 126),
		ZIndex = 1,
	}, root)
	addCorner(header, 22)
	addStroke(header, config.darkAccent, 5)
	addStuds(header, 0.72, 2)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 70),
		Text = config.title,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0,
		ZIndex = 3,
	}, header)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(12, 82),
		Size = UDim2.new(1, -24, 0, 30),
		Text = "GLOBAL TOP 50",
		TextColor3 = Color3.fromRGB(255, 245, 171),
		TextScaled = true,
		TextStrokeTransparency = 0.2,
		ZIndex = 3,
	}, header)

	-- Danh sách CUỘN (top 50) thay cho phân trang tự lật.
	local list = create("ScrollingFrame", {
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Name = "RankList",
		Position = UDim2.fromOffset(18, 158),
		Size = UDim2.new(1, -36, 1, -176),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 12,
		ScrollBarImageColor3 = config.accent,
		ZIndex = 1,
	}, root)
	create("UIListLayout", {
		Padding = UDim.new(0, 9),
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
		elseif rank == 2
		then Color3.fromRGB(230, 238, 255)
		elseif rank == 3
		then Color3.fromRGB(255, 167, 89)
		else Color3.fromRGB(173, 209, 255)

	local container = create("Frame", {
		BackgroundColor3 = rowColor,
		BorderSizePixel = 0,
		LayoutOrder = rank,
		Size = UDim2.new(1, 0, 0, 82),
		ZIndex = 2,
	}, parent)
	addCorner(container, 14)
	addStroke(container, if isTopThree then rankColor else Color3.fromRGB(45, 100, 148), 3)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(10, 15),
		Size = UDim2.fromOffset(84, 52),
		Text = `#{rank}`,
		TextColor3 = rankColor,
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0,
		ZIndex = 3,
	}, container)

	local avatar = create("ImageLabel", {
		BackgroundColor3 = Color3.fromRGB(236, 245, 255),
		Image = entry.avatar,
		Position = UDim2.fromOffset(102, 8),
		Size = UDim2.fromOffset(66, 66),
		ZIndex = 3,
	}, container)
	addCorner(avatar, 33)
	addStroke(avatar, Color3.fromRGB(255, 255, 255), 3)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(184, 12),
		Size = UDim2.new(0.42, 0, 0, 58),
		Text = entry.name,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextStrokeTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, container)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(0.62, 0, 0, 14),
		Size = UDim2.new(0.36, -8, 0, 54),
		Text = formatNumber(entry.value) .. config.valueSuffix,
		TextColor3 = Color3.fromRGB(255, 244, 169),
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.1,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	}, container)
end

-- Chữ ký của một bảng — dùng để bỏ qua lần VẼ LẠI khi thứ hạng không đổi.
-- ⚠️ Phải khai báo TRƯỚC `renderAll`: `renderAll` được gọi ngay trong `Init()`, đặt hàm này
-- xuống dưới là "attempt to call a nil value" và cả service chết ngay lúc nạp.
local function signatureOf(entries: { RankedEntry }): string
	local parts = table.create(#entries)
	for index, entry in entries do
		parts[index] = `{entry.userId}:{entry.value}`
	end
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
		create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 100),
			Text = "NO RANKED PLAYERS YET",
			TextColor3 = Color3.fromRGB(167, 205, 255),
			TextScaled = true,
			ZIndex = 2,
		}, list)
		return
	end

	for rank = 1, math.min(#entries, TOP_LIMIT) do
		createRankRow(list, config, entries[rank], rank)
	end
end

local function getOnlineFallback(config: BoardConfig): { RankedEntry }
	local entries = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.GetData(player)
		local value = data and data[config.dataKey]
		if typeof(value) == "number" then
			table.insert(entries, {
				userId = player.UserId,
				name = player.Name,
				value = value,
				avatar = getAvatar(player.UserId),
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
		if userId then
			table.insert(entries, {
				userId = userId,
				name = getDisplayName(userId),
				value = orderedEntry.value,
				avatar = getAvatar(userId),
			})
		end
	end
	entriesByBoard[config.modelName] = entries
	return true
end

local function publishPlayer(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	for _, config in BOARD_CONFIGS do
		local value = data[config.dataKey]
		if typeof(value) == "number" then
			local safeValue = math.clamp(math.floor(value), 0, MAX_ORDERED_VALUE)
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
					if not success and not RunService:IsStudio() then
						warn(`[LeaderboardService] Failed to publish {config.modelName}: {err}`)
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
				backoff = math.min(if backoff == 0 then REFRESH_SECONDS else backoff * BACKOFF_MULTIPLIER, MAX_BACKOFF_SECONDS)
				warn(`[LeaderboardService] DataStore lỗi/bị bóp — chờ thêm {math.floor(backoff)}s trước khi thử lại.`)
			end

			task.wait(REFRESH_SECONDS + backoff + math.random() * JITTER_SECONDS)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		publishPlayer(player)
	end)
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
