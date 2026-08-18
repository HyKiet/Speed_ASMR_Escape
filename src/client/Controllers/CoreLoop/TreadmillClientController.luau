--!strict
--[[
	TreadmillClientController.luau — Client tự phát hiện đứng trên treadmill hitbox.

	Thay cho cơ chế server quét vật lý mỗi 0.03s: client kiểm tra AABB cục bộ
	(root có nằm trong hitbox không — thuần toán học) mỗi 0.12s, và CHỈ gửi packet
	ByteNet `treadmillContact` khi trạng thái on/off hoặc hitbox đang đứng THAY ĐỔI.
	Server nhận packet sẽ tự validate lại khoảng cách (không tin client).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)

local TreadmillClientController = {}

local TREADMILL_MODEL_NAMES: { [string]: boolean } = {
	Treadmill_x1 = true,
	Treadmill_x3 = true,
	Treadmill_x9 = true,
	Treadmill_x25 = true,
	Treadmill_x100 = true,
}

local CHECK_INTERVAL = 0.12
-- Keepalive: gửi lại "on" định kỳ khi đang đứng trên treadmill. Nếu server lỡ drop packet
-- (rate-limit) hoặc revalidate tắt nhầm, keepalive tự đồng bộ lại trong ≤0.6s —
-- fix lỗi treadmill "lúc chạy lúc không" do hai bên lệch trạng thái vĩnh viễn.
local KEEPALIVE_INTERVAL = 0.6
-- Margin nhỏ hơn server (6.0) để client không báo "on" ở rìa mà server từ chối.
local HORIZONTAL_MARGIN = 1.0
local VERTICAL_MARGIN = 8.0

local localPlayer = Players.LocalPlayer

local models: { Model } = {}
local registeredModels: { [Instance]: boolean } = {}
local currentHitbox: BasePart? = nil
local lastSentAt = 0

-- LƯU Ý StreamingEnabled: vỏ Model replicate NGAY khi client vào game, nhưng part Hitbox
-- chỉ đến khi zone lọt vào bán kính stream. Bản cũ dùng WaitForChild("Hitbox", 10): với
-- Zone 2..14 (cách Lobby hàng nghìn studs) 10s trôi qua trước khi zone stream vào, hitbox
-- trả về nil và KHÔNG BAO GIỜ được thử lại → treadmill mọi zone trừ Zone 1 chết câm.
-- → giữ danh sách MODEL, phân giải Hitbox theo nhu cầu ở mỗi lần quét (rẻ: ≤20 model),
-- nên stream vào/ra bao nhiêu lần cũng tự hồi.
local function registerModel(model: Instance)
	if not model:IsA("Model") then
		return
	end
	if not TREADMILL_MODEL_NAMES[model.Name] then
		return
	end
	if registeredModels[model] then
		return
	end
	registeredModels[model] = true
	table.insert(models, model)
end

local function isWithinHitbox(rootPos: Vector3, hitbox: BasePart): boolean
	local localPos = hitbox.CFrame:PointToObjectSpace(rootPos)
	local halfSize = hitbox.Size * 0.5
	return math.abs(localPos.X) <= halfSize.X + HORIZONTAL_MARGIN
		and math.abs(localPos.Z) <= halfSize.Z + HORIZONTAL_MARGIN
		and math.abs(localPos.Y) <= halfSize.Y + VERTICAL_MARGIN
end

local function findHitboxUnder(rootPos: Vector3): BasePart?
	for index = #models, 1, -1 do
		local model = models[index]
		if not model.Parent then
			-- Model bị stream ra hẳn: bỏ khỏi danh sách, DescendantAdded sẽ đăng ký lại.
			registeredModels[model] = nil
			table.remove(models, index)
			continue
		end
		local hitbox = model:FindFirstChild("Hitbox")
		if hitbox and hitbox:IsA("BasePart") and isWithinHitbox(rootPos, hitbox) then
			return hitbox
		end
	end
	return nil
end

local function update()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	local found: BasePart? = nil
	if root and humanoid and humanoid.Health > 0 then
		found = findHitboxUnder(root.Position)
	end

	local now = os.clock()
	if found ~= currentHitbox then
		-- Đổi trạng thái/hitbox → báo ngay.
		currentHitbox = found
		lastSentAt = now
		GamePackets.treadmillContact.send({ isOn = found ~= nil })
	elseif found ~= nil and now - lastSentAt >= KEEPALIVE_INTERVAL then
		-- Đang đứng yên trên treadmill → keepalive để server không bao giờ kẹt "off".
		lastSentAt = now
		GamePackets.treadmillContact.send({ isOn = true })
	end
end

function TreadmillClientController.Start()
	for _, desc in ipairs(Workspace:GetDescendants()) do
		registerModel(desc)
	end
	-- Map/zone stream vào sau khi client load (nếu có) vẫn được đăng ký.
	Workspace.DescendantAdded:Connect(registerModel)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < CHECK_INTERVAL then
			return
		end
		accumulator = 0
		update()
	end)
end

return TreadmillClientController
