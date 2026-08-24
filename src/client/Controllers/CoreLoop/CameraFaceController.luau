--!strict
--[[
	CameraFaceController.luau — snap camera ra sau lưng player sau khi server teleport/hồi sinh.

	Server xoay CFrame của character được, nhưng CAMERA thuộc về client — sau teleport
	camera vẫn giữ góc quay cũ nên người chơi nhìn ngược hướng chạy dù nhân vật đã quay
	đúng. Server gửi packet `snapCamera {lookX, lookZ}` ngay sau mỗi teleport/hồi sinh;
	controller này đặt camera ra SAU lưng, nhìn xuôi theo hướng đó.

	══ ⚠️ BẢN CŨ THUA CUỘC ĐUA TRÊN MÁY THẬT (sửa 2026-08-24) ══════════════════════════════

	Bản cũ chỉ chờ đúng 2 nhịp Heartbeat rồi gọi `snapTo` MỘT LẦN, và `snapTo` thoát êm khi
	chưa có `HumanoidRootPart`. Trên PC trong Studio thì không bao giờ hỏng — replication gần
	như tức thì nên nhân vật mới luôn có mặt sau 2 nhịp. Đo 2026-08-24 trong Studio: camera
	đi từ (0, −1) sang (−0.06, +1.00), đúng hướng, mọi lần.

	Nhưng user quay video trên **iPhone, ping 50–90 ms**, và ở đó camera vẫn nhìn về phía
	Treadmills sau khi hồi sinh. Nhân vật thì quay đúng — đã đo trên server: `dot` giữa hướng
	thật và hướng mong đợi = **1.00**. Nhân vật do server xoay nên đúng ở mọi máy; camera do
	client xoay nên chỉ đúng khi client kịp.

	Chuỗi thua cuộc đua:
	    server `CharacterAdded` → chờ 1 frame → gửi `snapCamera`
	    client nhận packet   → chờ 2 Heartbeat → `player.Character` VẪN LÀ NHÂN VẬT CŨ (hoặc nil)
	    `snapTo` thoát êm, không snap gì cả → camera giữ nguyên góc cũ VĨNH VIỄN
	Gói tin đi một chiều nên nó tới trước bản sao của nhân vật mới là chuyện bình thường ở
	ping thật. Studio không bao giờ tái hiện được vì ở đó không có độ trễ để mà thua.

	Hai thay đổi, cố ý giữ cả hai:

	  1. **CHỜ CHO TỚI KHI CÓ NHÂN VẬT MỚI, đừng thoát êm.** Ôm lấy hướng vừa nhận rồi thử lại
	     cho tới `RESOLVE_TIMEOUT`. Hết hạn thì thôi — thà không snap còn hơn snap vào một
	     nhân vật khác ở một lần hồi sinh sau.

	  2. **SNAP HAI LẦN.** Lần đầu ngay khi có root, lần hai sau `REAPPLY_DELAY`. Lý do: hệ
	     camera của Roblox tự đặt lại CFrame khi nó gắn vào nhân vật mới, và bước đó có thể
	     chạy SAU lần snap đầu — nhất là trên mobile, nơi camera do người chơi kéo tay nên
	     module camera giữ lại yaw cũ. Lần snap thứ hai đè lên bước đó.

	⚠️ Cửa sổ ghi đè phải NGẮN (`REAPPLY_DELAY` 0,25 s). Dài hơn là giành tay lái với người
	chơi đang tự xoay camera — khó chịu hơn nhiều so với việc phải tự quay một lần.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)

local CameraFaceController = {}

-- Khớp offset camera mặc định của Roblox (zoom ~12.5, hơi cao hơn đầu).
local CAMERA_DISTANCE = 12
local CAMERA_HEIGHT = 5
local FOCUS_HEIGHT = 2

-- Tối đa chờ nhân vật mới replicate về. 5 s là rộng rãi cho cả mạng 3G; quá đó thì lần hồi
-- sinh này coi như lỡ, đừng snap muộn hơn nữa.
local RESOLVE_TIMEOUT = 5
-- Khoảng cách giữa hai lần snap. Xem cảnh báo ở đầu file trước khi nới.
local REAPPLY_DELAY = 0.25

-- Mỗi gói tin mới huỷ gói đang chờ: chỉ hướng MỚI NHẤT được quyền quay camera.
local token = 0

local function snapTo(direction: Vector3): boolean
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end

	local focus = root.Position + Vector3.new(0, FOCUS_HEIGHT, 0)
	local eye = focus - (direction * CAMERA_DISTANCE) + Vector3.new(0, CAMERA_HEIGHT, 0)
	-- CameraType Custom: set CFrame một lần là engine nhận góc quay mới rồi tự follow tiếp.
	camera.CFrame = CFrame.lookAt(eye, focus)
	return true
end

function CameraFaceController.Start()
	GamePackets.snapCamera.listen(function(data)
		local direction = Vector3.new(data.lookX, 0, data.lookZ)
		if direction.Magnitude < 0.01 then
			return
		end
		direction = direction.Unit

		token += 1
		local mine = token

		task.spawn(function()
			-- Chờ tới khi thật sự snap được, thay vì thử một lần rồi bỏ cuộc.
			local deadline = os.clock() + RESOLVE_TIMEOUT
			while os.clock() < deadline do
				RunService.Heartbeat:Wait()
				if token ~= mine then
					return -- đã có lệnh quay mới hơn
				end
				if snapTo(direction) then
					break
				end
			end

			-- Lần hai: đè lên bước hệ camera Roblox tự đặt lại khi gắn vào nhân vật mới.
			task.wait(REAPPLY_DELAY)
			if token == mine then
				snapTo(direction)
			end
		end)
	end)
end

return CameraFaceController
