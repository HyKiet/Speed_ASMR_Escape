--!strict
-- Tiện ích nhân vật dùng chung. Trước đây các Service tự viết lại — gom về 1 nơi.

local Players = game:GetService("Players")

local CharacterUtil = {}

function CharacterUtil.GetCharacterParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil, nil
	end

	return humanoid, root
end

-- Trả về HumanoidRootPart khi nhân vật còn sống (Health > 0). Nil nếu không hợp lệ.
function CharacterUtil.GetAliveRoot(player: Player): BasePart?
	local humanoid, root = CharacterUtil.GetCharacterParts(player)
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end
	return root
end

-- Lấy Player tương ứng từ Instance bị Touched. Trả về (player, humanoid) hoặc nil.
function CharacterUtil.GetPlayerFromHit(hit: BasePart): (Player?, Humanoid?)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return nil, nil
	end

	return player, humanoid
end

-- Tìm Model nhân vật từ một part bị Touched. Không yêu cầu còn sống.
function CharacterUtil.GetCharacterFromHit(hit: BasePart): Model?
	local candidate = hit:FindFirstAncestorOfClass("Model")
	if candidate and candidate:FindFirstChildOfClass("Humanoid") then
		return candidate
	end
	return nil
end

return CharacterUtil
