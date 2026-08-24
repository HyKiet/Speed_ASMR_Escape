--!strict
--[[
	CameraFaceController.luau — snap camera ra sau lưng player sau khi server teleport/hồi sinh.

	Server xoay CFrame của character được, nhưng CAMERA thuộc về client — sau teleport
	camera vẫn giữ góc quay cũ nên người chơi nhìn ngược hướng chạy dù nhân vật đã quay
	đúng. Server gửi packet `snapCamera {lookX, lookZ}` ngay sau mỗi teleport/hồi sinh.

	══ ⚠️ HAI LẦN SỬA HỤT — ĐỌC TRƯỚC KHI ĐỔI GÌ (2026-08-24) ══════════════════════════════

	User báo: chết xong về Lobby thì nhìn vào dãy Treadmill thay vì đường chạy. **Chỉ trên
	điện thoại. PC không bao giờ dính.**

	**Lần 1** — nghĩ là chờ chưa đủ: bản gốc chờ 2 nhịp Heartbeat rồi gọi `snapTo` một lần,
	và `snapTo` thoát êm khi chưa có `HumanoidRootPart`. Đã thêm vòng chờ tới khi có root và
	snap lần hai sau 0,25 s. **Vẫn hỏng trên điện thoại.**

	**Lần 2 — nguyên nhân thật:** ghi thẳng `Camera.CFrame` KHÔNG ĂN trên mobile. Module
	camera của Roblox (`TouchCamera`) chạy ở `RenderPriority.Camera` mỗi khung hình và **tự
	dựng lại `Camera.CFrame` từ trạng thái yaw/pitch NỘI BỘ của nó**. Ghi từ ngoài vào bị nó
	đè lại ngay khung hình kế tiếp. Trên PC thì `ClassicCamera` lấy lại hướng từ chính CFrame
	hiện tại nên phép ghi dính — đó là toàn bộ lý do PC không tái hiện được lỗi.

	⇒ Không thể ép bằng cách ghi mạnh tay hơn hay chờ lâu hơn. Phải làm cho module **tính lại
	trạng thái nội bộ**. Cách duy nhất từ ngoài: chuyển `CameraType` sang `Scriptable`, ghi
	CFrame, rồi trả về `Custom`. Lúc quay lại `Custom`, module kích hoạt lại controller và suy
	yaw/pitch từ CFrame đang có — tức là từ hướng mình vừa đặt.

	══ VÌ SAO PHẢI TỰ KIỂM TRA LẠI ═════════════════════════════════════════════════════════

	Tôi không có điện thoại để đo. Nên thay vì tin là xong, controller **tự đo kết quả**: sau
	khi snap thì lấy mẫu hướng camera trong `VERIFY_SECONDS`; lệch quá `MATCH_DOT` thì làm
	lại, tối đa `MAX_ATTEMPTS` lần. Hỏng hẳn thì `warn` — biến máy người chơi thành thiết bị
	đo, lần test sau chỉ cần soi log là biết cơ chế có ăn không.

	Dừng đo NGAY khi thấy khớp một lần: kéo dài cửa sổ là giành tay lái với người chơi đang
	tự xoay camera, khó chịu hơn hẳn so với việc phải tự quay một lần.

	══ LIÊN QUAN: NÚT KHOÁ CAMERA TRÊN MOBILE ══════════════════════════════════════════════

	`TopBarController` có nút **chỉ hiện trên mobile** bật `applyCameraLockStep`, chạy mỗi
	RenderStep và ép **NHÂN VẬT quay theo CAMERA** (`root.CFrame = lookAt(...)` theo
	`camera.CFrame.LookVector`, kèm `AutoRotate = false`).

	Nghĩa là khi nút đó bật, quan hệ bị ĐẢO: sửa hướng nhân vật là vô nghĩa vì khung hình sau
	nó bị kéo về theo camera. Camera mới là thứ duy nhất đáng sửa — đúng thứ file này làm.
	Sửa được camera thì khoá camera tự kéo nhân vật theo, ra đúng kết quả mong muốn.

	⚠️ ĐỪNG "sửa" bằng cách ép lại `root.CFrame` ở đây. Nó sẽ đánh nhau với khoá camera mỗi
	khung hình và người chơi thấy nhân vật giật qua giật lại.
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

-- Tối đa chờ nhân vật mới replicate về. Rộng rãi cho cả mạng 3G; quá đó thì lần hồi sinh
-- này coi như lỡ, đừng snap muộn hơn nữa.
local RESOLVE_TIMEOUT = 5
-- Sau khi snap, đo trong bao lâu để biết module camera có kéo ngược lại không.
local VERIFY_SECONDS = 0.6
-- dot(hướng camera phẳng, hướng yêu cầu) trên mức này = coi như đã đúng.
local MATCH_DOT = 0.9
local MAX_ATTEMPTS = 3

-- Mỗi gói tin mới huỷ gói đang chờ: chỉ hướng MỚI NHẤT được quyền quay camera.
local token = 0

local function flatLook(camera: Camera): Vector3?
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.001 then
		return nil
	end
	return flat.Unit
end

--[[
	Đặt camera ra sau lưng, nhìn xuôi theo `direction`.

	`Scriptable` → ghi → `Custom` là phần KHÔNG ĐƯỢC BỎ: xem khối "Lần 2" ở đầu file. Ghi
	thẳng khi đang `Custom` thì trên mobile bị module đè lại ngay khung hình sau.
]]
--   true  = đã snap
--   false = chưa snap được (chưa có nhân vật/camera) → cứ thử lại
--   nil   = KHÔNG PHẢI VIỆC CỦA MÌNH, hệ khác đang giữ camera → bỏ hẳn, đừng thử lại
local function snapTo(direction: Vector3): boolean?
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

	--[[
		Chỉ động vào camera khi nó đang ở `Custom` — tức là đang do module mặc định lái.

		Hiện KHÔNG file nào khác trong `src/` đụng tới `CameraType` (đã grep), nên nhánh này
		chưa bao giờ chạy. Nó có mặt cho tương lai: nếu sau này có cutscene hay chế độ ngắm
		đặt `Scriptable`, một gói `snapCamera` rơi vào giữa lúc đó mà ép về `Custom` là cướp
		quyền của hệ kia giữa chừng. Nhường là đúng — lúc đó người chơi cũng không cần snap.
	]]
	if camera.CameraType ~= Enum.CameraType.Custom then
		return nil
	end

	local focus = (root :: BasePart).Position + Vector3.new(0, FOCUS_HEIGHT, 0)
	local eye = focus - (direction * CAMERA_DISTANCE) + Vector3.new(0, CAMERA_HEIGHT, 0)
	local goal = CFrame.lookAt(eye, focus)

	--[[
		⚠️ PHẢI TRẢ `CameraType` VỀ TRONG MỌI ĐƯỜNG THOÁT. Kẹt ở `Scriptable` nghĩa là camera
		đứng hình vĩnh viễn — hỏng nặng hơn nhiều so với chính lỗi đang sửa. Vì vậy bọc
		`pcall` và khôi phục ở ngoài, kể cả khi thân hàm ném lỗi giữa chừng.
	]]
	local ok = pcall(function()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = goal
		-- Một khung hình để phép ghi kịp có hiệu lực trước khi module nhận lại quyền.
		RunService.RenderStepped:Wait()
		camera.CFrame = goal
	end)
	-- Luôn trả về `Custom` — vào tới đây nghĩa là lúc bắt đầu nó đang `Custom`.
	camera.CameraType = Enum.CameraType.Custom

	return ok
end

function CameraFaceController.Start()
	GamePackets.snapCamera.listen(function(data)
		local raw = Vector3.new(data.lookX, 0, data.lookZ)
		if raw.Magnitude < 0.01 then
			return
		end
		local direction = raw.Unit

		token += 1
		local mine = token

		task.spawn(function()
			-- 1) Chờ tới khi thật sự có nhân vật mới. Gói tin đi một chiều nên nó tới trước
			--    bản sao nhân vật là chuyện bình thường ở ping thật.
			local deadline = os.clock() + RESOLVE_TIMEOUT
			while os.clock() < deadline do
				if token ~= mine then
					return
				end
				local result = snapTo(direction)
				if result == nil then
					return -- hệ khác đang giữ camera, nhường
				elseif result then
					break
				end
				RunService.Heartbeat:Wait()
			end

			-- 2) Đo xem module camera có kéo ngược lại không, làm lại nếu có.
			for attempt = 1, MAX_ATTEMPTS do
				local until_ = os.clock() + VERIFY_SECONDS
				local matched = false
				while os.clock() < until_ do
					RunService.Heartbeat:Wait()
					if token ~= mine then
						return
					end
					local camera = Workspace.CurrentCamera
					local actual = camera and flatLook(camera)
					if actual and actual:Dot(direction) >= MATCH_DOT then
						matched = true
						break
					end
				end

				if matched then
					if attempt > 1 then
						warn(
							`[CameraFace] phải snap {attempt} lần mới ăn — module camera đang kéo ngược. `
								.. `Nếu thấy dòng này thường xuyên trên một loại máy, ghi lại loại máy đó.`
						)
					end
					return
				end

				if attempt < MAX_ATTEMPTS then
					snapTo(direction)
				end
			end

			warn(
				`[CameraFace] KHÔNG snap được camera sau {MAX_ATTEMPTS} lần. `
					.. `Người chơi sẽ nhìn sai hướng sau khi hồi sinh — cần đổi cơ chế, xem đầu file.`
			)
		end)
	end)
end

return CameraFaceController
