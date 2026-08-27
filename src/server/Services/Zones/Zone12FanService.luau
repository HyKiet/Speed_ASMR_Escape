--!strict
--[[
	Zone12FanService.luau — Server cho cánh quạt Cyber Fan Stage 12.

	THAY THẾ script inline `Workspace.Zones.Zone12.Mechanics.Zone12WindTunnelScript`
	(2026-08-27). Hai lý do, độc lập nhau:

	── 1. HẾT QUAY Ở SERVER ────────────────────────────────────────────────────────────────
	Bản inline chạy `blades:PivotTo(...)` mỗi Heartbeat, 360°/s, VĨNH VIỄN — không cổng ngủ,
	không LOD, chạy cả khi cả server đang ở lobby. Part neo do script dời thì client KHÔNG nội
	suy: nó nhảy thẳng tới giá trị mới mỗi khi gói replicate tới. Nhịp gói thấp hơn nhịp frame
	⇒ quạt quay theo nhịp MẠNG chứ không theo nhịp hình, và stage đông người thì nhịp đó còn
	thưa hơn. Ở ping 350–400ms (đo 2026-08-27) đây là bẫy giật rõ nhất game.

	Giờ theo kiến trúc chung (Zone 2/3/8/9/11/15): server công bố THAM SỐ đúng một lần,
	`Zone12WindTunnelController` phía client dựng góc từ đồng hồ tất định. 0 byte replicate.

	── 2. VÀO RỒI THÌ VÀO GIT ──────────────────────────────────────────────────────────────
	Script inline nằm trong .rbxl nên KHÔNG được Rojo sync và KHÔNG có lịch sử git; muốn sửa
	phải mở Studio. Là ModuleScript dưới `src/server/Services` thì `init.server.luau` tự quét
	và nạp — không phải đăng ký ở đâu cả.

	Đổi lại: service không có `script.Parent` để bám, phải tự tìm zone trong Workspace và
	CHỊU ĐƯỢC việc map chưa nạp xong (vòng resolve có retry ở dưới).

	Hợp đồng với client — attribute trên Workspace.Zones.Zone12:
	    FanPivotCF : CFrame  — pivot gốc của model Blades
	    FanSpinRPS : number  — số vòng mỗi giây (1.0 = 360°/s, giữ nguyên tốc độ bản inline)
	    FanReady   : boolean — bật SAU CÙNG, client chỉ dựng khi thấy cờ này
	Và trên TỪNG part cánh: HomeCF (CFrame bất biến — client dời part nên part.CFrame hết là gốc).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone12FanService = {}

local SPIN_RPS = 1.0 -- 360°/s, y hệt bản inline
local RESOLVE_RETRY = 1

local function resolve(): number?
	local zones = Workspace:FindFirstChild("Zones")
	local zone12 = zones and zones:FindFirstChild("Zone12")
	local ground = zone12 and zone12:FindFirstChild("Ground")
	local fan = ground and ground:FindFirstChild("CyberFan")
	local blades = fan and fan:FindFirstChild("Blades")
	if not zone12 or not blades or not blades:IsA("Model") then
		return nil
	end

	zone12:SetAttribute("FanPivotCF", blades:GetPivot())
	zone12:SetAttribute("FanSpinRPS", SPIN_RPS)

	local n = 0
	for _, part in blades:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			-- Cánh quạt thuần trang trí (đã CanCollide=false sẵn trong map). Tắt cả CanTouch
			-- để client dời tự do mà không sinh Touched theo vị trí HOME của server.
			part.CanCollide = false
			part.CanTouch = false
			part:SetAttribute("HomeCF", part.CFrame)
			n += 1
		end
	end
	if n == 0 then
		return nil
	end

	-- Bật SAU CÙNG: client thấy cờ là chắc chắn mọi HomeCF đã có.
	zone12:SetAttribute("FanReady", true)
	return n
end

function Zone12FanService.Init() end

function Zone12FanService.Start()
	task.spawn(function()
		local n = resolve()
		while not n do
			task.wait(RESOLVE_RETRY)
			n = resolve()
		end
		Log.Boot(`[Zone12FanService] {n} cánh — client tự quay (0 replication)`)
	end)
end

return Zone12FanService
