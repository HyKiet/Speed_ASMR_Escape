--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)

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
local ROWS_PER_PAGE = 8
local REFRESH_SECONDS = 60
local PAGE_SECONDS = 7
local MAX_ORDERED_VALUE = 9e15
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
	local name = if success then result else `Player {userId}`
	nameCache[userId] = name
	return name
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
	local avatar = if success then image else DEFAULT_AVATAR
	avatarCache[userId] = avatar
	return avatar
end

local function getBoardRoot(config: BoardConfig): Frame?
	local folder = Workspace:FindFirstChild("LeaderBoard")
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

	create("Frame", {
		BackgroundTransparency = 1,
		Name = "RankList",
		Position = UDim2.fromOffset(18, 160),
		Size = UDim2.new(1, -36, 0, 746),
		ZIndex = 1,
	}, root)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Name = "PageLabel",
		Position = UDim2.new(0, 18, 1, -72),
		Size = UDim2.new(1, -36, 0, 52),
		Text = "PAGE 1 / 1",
		TextColor3 = Color3.fromRGB(167, 205, 255),
		TextScaled = true,
		TextStrokeTransparency = 0.35,
		ZIndex = 2,
	}, root)

	return root :: Frame
end

local function createRankRow(parent: Instance, config: BoardConfig, entry: RankedEntry, rank: number, row: number)
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
		Position = UDim2.fromOffset(0, (row - 1) * 91),
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

local function renderPage(config: BoardConfig, page: number)
	local root = boardRoots[config.modelName]
	if not root then
		return
	end

	local list = root:FindFirstChild("RankList") :: Frame?
	local pageLabel = root:FindFirstChild("PageLabel") :: TextLabel?
	if not list or not pageLabel then
		return
	end

	list:ClearAllChildren()
	local entries = entriesByBoard[config.modelName] or {}
	local pageCount = math.max(1, math.ceil(#entries / ROWS_PER_PAGE))
	local currentPage = ((page - 1) % pageCount) + 1
	pageLabel.Text = `PAGE {currentPage} / {pageCount}`

	if #entries == 0 then
		create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(24, 190),
			Size = UDim2.new(1, -48, 0, 100),
			Text = "NO RANKED PLAYERS YET",
			TextColor3 = Color3.fromRGB(167, 205, 255),
			TextScaled = true,
			ZIndex = 2,
		}, list)
		return
	end

	local firstIndex = ((currentPage - 1) * ROWS_PER_PAGE) + 1
	for row = 1, ROWS_PER_PAGE do
		local index = firstIndex + row - 1
		local entry = entries[index]
		if entry then
			createRankRow(list, config, entry, index, row)
		end
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

local function refreshEntries(config: BoardConfig)
	local store = stores[config.modelName]
	local success, pages = pcall(store.GetSortedAsync, store, false, TOP_LIMIT)
	if not success then
		entriesByBoard[config.modelName] = getOnlineFallback(config)
		return
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
	for _, config in BOARD_CONFIGS do
		stores[config.modelName] = DataStoreService:GetOrderedDataStore(config.storeName)
		lastPublishedValues[config.modelName] = {}
		local root = getBoardRoot(config)
		if root then
			boardRoots[config.modelName] = root
			entriesByBoard[config.modelName] = {}
			renderPage(config, 1)
		end
	end
end

function LeaderboardService.Start()
	task.spawn(function()
		task.wait(2)
		local page = 1
		local nextRefresh = 0
		while true do
			if os.clock() >= nextRefresh then
				for _, player in Players:GetPlayers() do
					publishPlayer(player)
				end
				for _, config in BOARD_CONFIGS do
					refreshEntries(config)
				end
				nextRefresh = os.clock() + REFRESH_SECONDS
			end

			for _, config in BOARD_CONFIGS do
				renderPage(config, page)
			end
			page += 1
			task.wait(PAGE_SECONDS)
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
