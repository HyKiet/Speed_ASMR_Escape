--!strict
-- Giải mã chuỗi path dạng "Workspace.Zone3.Mechanics.Stage3Start" thành Instance.

local PathResolver = {}

function PathResolver.Resolve(path: string): Instance?
	local current: Instance = game
	for segment in string.gmatch(path, "[^%.]+") do
		local nextInstance = current:FindFirstChild(segment)
		if not nextInstance then
			return nil
		end
		current = nextInstance
	end

	return current
end

--[[
	Thử lần lượt nhiều đường dẫn, trả về cái đầu tiên có thật (kèm chính đường dẫn đó).

	VÌ SAO CẦN (bug 2026-08-07): `Workspace.Lobby.Spawn.SpawnLocation` viết cứng ở 2 chỗ,
	nhưng trong map SpawnLocation thật nằm ở `Workspace.Spawn.SpawnLocation` — ngoài Lobby.
	`Resolve` trả nil, cả hai chỗ gọi đều `return` lặng lẽ ⇒ ăn Wins xong KHÔNG về Lobby và
	nút Lobby trong TeleportModal cũng câm, không một dòng log. Map có thể còn được sắp lại
	nữa, nên chỗ nào phụ thuộc vị trí trong map thì khai vài phương án và LOG khi trượt hết.
]]
function PathResolver.ResolveFirst(paths: { string }): (Instance?, string?)
	for _, path in paths do
		local found = PathResolver.Resolve(path)
		if found then
			return found, path
		end
	end
	return nil, nil
end

--[[
	Điểm spawn ở sảnh. Đây là thứ hay bị dời nhất trong map nên tra theo thứ tự:
	đường dẫn đã biết → bất kỳ SpawnLocation nào trong Workspace.
	Trả nil kèm cảnh báo ở chỗ gọi thì hơn là im lặng không teleport.
]]
function PathResolver.FindLobbySpawn(): BasePart?
	local found = PathResolver.ResolveFirst({
		"Workspace.Spawn.SpawnLocation",
		"Workspace.Lobby.Spawn.SpawnLocation",
		"Workspace.Lobby.Spawn",
	})
	if found and found:IsA("BasePart") then
		return found
	end

	-- Chốt chặn cuối: quét ra SpawnLocation bất kỳ. Thà đưa người chơi về sai chỗ một chút
	-- còn hơn để họ dính lại giữa map sau khi đã ăn Wins.
	local workspaceService = game:GetService("Workspace")
	for _, d in workspaceService:GetDescendants() do
		if d:IsA("SpawnLocation") then
			return d
		end
	end
	return nil
end

return PathResolver
