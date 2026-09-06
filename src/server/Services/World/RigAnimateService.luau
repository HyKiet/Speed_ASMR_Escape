--!strict
--[[
	RigAnimateService — chạy animation idle cho ba rig Aura trưng bày ở Lobby.

	`Workspace.Lobby.AuraBase` có ba bệ (Dark / Flame / RedHeart), mỗi bệ chứa một `Rig` là
	Dummy R15 kèm sẵn một `Animation` tên `Aura_Idle`. Không có gì tự phát animation đó, nên
	nếu service này không chạy thì ba rig đứng chết cứng ở tư thế T-pose — đúng chỗ dễ thấy
	nhất của Lobby và là mặt tiền của ba gamepass đắt nhất shop (299 / 499 / 799 R$).

	══ VÌ SAO FILE NÀY XUẤT HIỆN Ở ĐÂY MUỘN (2026-09-06) ═══════════════════════════════════

	Bản gốc là một `Script` dán thẳng vào `ServerScriptService` TRONG STUDIO, không đi qua
	Rojo. Nó chạy đúng, nhưng vô hình với mọi thứ trong repo: không ai grep ra, không nằm
	trong sourcemap, không qua selene/stylua, và một lần dọn ServerScriptService là mất hẳn
	mà không ai biết cho tới khi vào Lobby nhìn thấy T-pose.

	Đã chuyển nguyên hành vi sang đây và xoá bản trong Studio.
	⚠️ Đừng dán script mới vào Studio nữa — Rojo sync MỘT CHIỀU (VSCode → Studio), thứ dán
	tay trong Studio sẽ bị ghi đè hoặc mất im lặng.

	══ KHÁC BẢN CŨ ĐÚNG BA CHỖ ════════════════════════════════════════════════════════════

	1. `Log.Boot`/`Log.Warn` thay cho `print` — dòng khởi động im lặng theo mặc định
	   (xem `Shared/Util/Log`), còn lỗi thì vẫn kêu.
	2. Resolve phòng thủ + warn khi trượt. Streaming đang bật; bản cũ `return` im lặng khi
	   không thấy `AuraBase`, tức triệu chứng duy nhất là T-pose không kèm log nào.
	3. Chạy trong `Start()` theo vòng đời chuẩn của repo thay vì chạy lúc file được nạp.
]]

local Workspace = game:GetService("Workspace")

local Log = require(game:GetService("ReplicatedStorage").Shared.Util.Log)

local RigAnimateService = {}

-- Tên `Animation` nằm sẵn trong mỗi Rig. Đây là dữ liệu của MAP, không phải hằng số tự do:
-- đổi tên ở đây mà không đổi trong Workspace.Lobby.AuraBase là ba rig đứng im.
local IDLE_ANIMATION_NAME = "Aura_Idle"

local function animateRig(rig: Instance)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		Log.Warn(`[RigAnimateService] {rig:GetFullName()} thiếu Humanoid — bỏ qua`)
		return false
	end

	local animation = rig:FindFirstChild(IDLE_ANIMATION_NAME)
	if not animation or not animation:IsA("Animation") then
		Log.Warn(`[RigAnimateService] {rig:GetFullName()} thiếu Animation "{IDLE_ANIMATION_NAME}"`)
		return false
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local ok, err = pcall(function()
		local track = (animator :: Animator):LoadAnimation(animation :: Animation)
		track.Looped = true
		track:Play()
	end)

	if not ok then
		Log.Warn(`[RigAnimateService] không chạy được animation trên {rig:GetFullName()}: {err}`)
		return false
	end
	return true
end

function RigAnimateService.Start()
	local lobby = Workspace:FindFirstChild("Lobby")
	local auraBase = lobby and lobby:FindFirstChild("AuraBase")
	if not auraBase then
		Log.Warn("[RigAnimateService] Không thấy Workspace.Lobby.AuraBase — ba rig Aura sẽ đứng T-pose")
		return
	end

	local started = 0
	for _, holder in auraBase:GetChildren() do
		local rig = holder:FindFirstChild("Rig")
		if rig and animateRig(rig) then
			started += 1
		end
	end

	Log.Boot(`[RigAnimateService] sẵn sàng — {started} rig Aura đang chạy idle`)
end

return RigAnimateService
