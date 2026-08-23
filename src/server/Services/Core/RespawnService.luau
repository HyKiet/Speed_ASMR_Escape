--!strict
-- Khi player bị giết bởi BẤT KỲ thứ gì → hồi sinh về Lobby NHANH NHẤT có thể.
-- Roblox mặc định RespawnTime = 5s (quá lâu). Hạ xuống mức rất thấp + auto-load nhân vật.
-- Spawn về Lobby do Workspace.SpawnLocation (lobby) là SpawnLocation duy nhất.
--
-- HƯỚNG NHÌN LÚC SPAWN
-- ====================
-- `Workspace.Spawn.SpawnLocation` (NGOÀI Lobby — xem PathResolver.FindLobbySpawn) có
-- LookVector = (0,0,-1) trong khi toàn bộ zone
-- nằm về phía +Z ⇒ Roblox đặt nhân vật QUAY LƯNG vào các zone mỗi lần vào game và mỗi
-- lần chết đi sống lại. Xoay part trong Studio cũng sửa được, nhưng đó là place data
-- (Rojo không quản) nên dễ mất — chốt hướng bằng code ở đây.
--
-- Chỉ đổi YAW, giữ nguyên vị trí, và phải gửi `snapCamera`: camera là của client, server
-- xoay character thôi thì người chơi vẫn nhìn theo khung hình cũ.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local PathResolver = require(ReplicatedStorage.Shared.Util.PathResolver)
local StageFacing = require(ReplicatedStorage.Shared.Util.StageFacing)

local RespawnService = {}

-- Mốc thời gian lúc chết, để đo đúng khoảng người chơi PHẢI CHỜ (chết → nhân vật mới).
local diedAt: { [Player]: number } = {}

--[[
	══ NHỊP CHẾT → HỒI SINH (user chốt 2026-08-21) ═════════════════════════════════════════

	0.4 s quá NHANH: người chơi chưa kịp thấy nhân vật đổ xuống thì đã đứng ở Lobby, nên cú
	chết không đọc ra được là "mình vừa chết" — nó đọc ra thành "màn hình vừa nhảy một cái".
	Hoạt ảnh chết mặc định của Roblox (`Humanoid` rã khớp + ngã) cần ~1 s mới thành hình.

	1.3 s là chỗ dừng: đủ thấy trọn cú ngã, vẫn dưới ngưỡng bắt đầu thấy sốt ruột trong một
	game obby tốc độ (kinh nghiệm chung của thể loại: quá 2 s là người chơi bắt đầu bấm loạn).

	⚠️ ĐỪNG nhầm số này với chuyện "lâu lâu về Lobby rất lâu" mà user báo cùng lúc — cái đó
	là streaming, không phải hằng số này. Xem `prefetchLobbyForClient`.
]]
local RESPAWN_TIME = 1.3
local ROOT_WAIT_SECONDS = 5

--[[
	Ngưỡng cảnh báo: hồi sinh lâu hơn mức này thì ghi một dòng vào Error Report.

	Có mặt vì "lâu lâu bị" là thứ không sửa mù được — phải biết nó lâu BAO NHIÊU và xảy ra ở
	đâu. Dòng warn này biến một lời phàn nàn thành một con số đọc được trên Creator Hub.
]]
local SLOW_RESPAWN_WARN_SECONDS = 3

local function faceZones(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", ROOT_WAIT_SECONDS)
	if not root or not root:IsA("BasePart") then
		return
	end

	-- Nhân vật vừa spawn: chờ engine đặt xong CFrame ban đầu rồi mới xoay, nếu không
	-- phép xoay của mình bị chính bước đặt vị trí của engine ghi đè.
	task.wait()
	if character.Parent == nil or root.Parent ~= character then
		return
	end

	-- Hướng "phía trước" = từ chỗ đứng nhìn về cổng Zone 1 (suy từ hình học, xem StageFacing).
	local oriented = StageFacing.Orient(root.Position, 1, root.CFrame)
	root.CFrame = oriented

	local look = oriented.LookVector
	pcall(GamePackets.snapCamera.sendTo, { lookX = look.X, lookZ = look.Z }, player)
end

--[[
	══ VÌ SAO "LÂU LÂU VỀ LOBBY RẤT LÂU" ═══════════════════════════════════════════════════

	`Players.RespawnTime` chỉ quyết định khi nào SERVER dựng lại nhân vật. Thứ người chơi thật
	sự chờ là lúc CLIENT nhìn thấy và điều khiển được nó — mà với `StreamingEnabled`, client
	chỉ có địa hình quanh chỗ nó ĐANG ở.

	Chết ở Zone 15 nghĩa là Lobby cách đó hàng nghìn studs và ĐÃ BỊ ĐẨY RA KHỎI BỘ NHỚ client.
	Nhân vật spawn xong vẫn phải đợi cả vùng Lobby tải về mới đứng được — đó chính là "lâu lâu
	rất lâu", và nó phụ thuộc đường truyền + RAM máy nên lúc nhanh lúc chậm, đúng kiểu "lâu
	lâu". Trên Redmi (272 MB working set, ping 311 ms đo 2026-08-21) là ca tệ nhất.

	Cách chữa: ngay khi CHẾT, bảo client tải trước vùng Lobby. Cú tải chạy song song với 1.3 s
	hoạt ảnh chết, nên tới lúc nhân vật spawn thì địa hình đã sẵn sàng.

	⚠️ `RequestStreamAroundAsync` phải gọi TỪ CLIENT (nó là hàm của `Player` phía client). Ở
	đây server chỉ bắn gói; `CoreLoop/StreamPrefetchController` là bên gọi thật.
]]
local function prefetchLobbyForClient(player: Player)
	local spawnPart = PathResolver.FindLobbySpawn()
	if not spawnPart then
		return
	end
	local position = spawnPart.Position
	pcall(GamePackets.prefetchAround.sendTo, {
		x = position.X,
		y = position.Y,
		z = position.Z,
	}, player)
end

local function watchDeath(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(function()
		diedAt[player] = os.clock()
		prefetchLobbyForClient(player)
	end)
end

local function bindPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		local startedAt = diedAt[player]
		if startedAt then
			diedAt[player] = nil
			local elapsed = os.clock() - startedAt
			if elapsed > SLOW_RESPAWN_WARN_SECONDS then
				warn(
					`[Respawn] {player.Name}: hồi sinh mất {string.format("%.1f", elapsed)}s `
						.. `(ngưỡng {SLOW_RESPAWN_WARN_SECONDS}s) — nghi streaming Lobby chưa về kịp`
				)
			end
		end
		task.spawn(watchDeath, player, character)
		task.spawn(faceZones, player, character)
	end)
	if player.Character then
		task.spawn(watchDeath, player, player.Character)
		task.spawn(faceZones, player, player.Character)
	end
end

function RespawnService.Init()
	Players.CharacterAutoLoads = true
	Players.RespawnTime = RESPAWN_TIME
end

function RespawnService.Start()
	-- Bảo hiểm: giữ RespawnTime thấp kể cả khi có script khác đổi.
	Players.RespawnTime = RESPAWN_TIME

	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		diedAt[player] = nil
	end)
end

return RespawnService
