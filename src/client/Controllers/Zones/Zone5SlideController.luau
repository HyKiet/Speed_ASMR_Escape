--!strict
--[[
	Zone5SlideController — cổng "BẮT BUỘC SLIDE" Zone 5 phía CLIENT.

	Vì sao client: trạng thái slide do MovementSlide dựng nằm ở phía CLIENT và KHÔNG replicate
	lên server (đã kiểm chứng: server luôn đọc HipHeight 2.0). Nên server không thể biết player
	có slide hay không → phải phát hiện ngay tại client (nơi biết chính xác trạng thái của mình).

	Cơ chế: player đứng THẲNG (không slide) trong bóng đổ X-Z của bất kỳ EnergyWall nào
	→ tự chết. Slide đi xuyên qua → sống. Đứng dậy giữa chừng (chưa ra khỏi tường) mà chưa
	slide hết → chết ngay. Khe thở giữa 2 tường (đứng dậy an toàn) nằm ngoài mọi footprint
	nên không bị phạt.

	══ ⚠️ BUG AVATAR TO — ĐÃ SỬA 2026-08-21, ĐỪNG LÀM LẠI ═══════════════════════════════════

	Bản trước nhận biết "đang slide" bằng `humanoid.HipHeight < 1.6`. Đó là một ngưỡng TUYỆT
	ĐỐI áp lên một đại lượng TỈ LỆ THEO AVATAR:

	    HipHeight lúc slide = HipHeight đứng × 0.5   (`MovementConfig.Slide.HipHeightFactor`)
	    R15 chuẩn : 2.0 × 0.5 = 1.0  < 1.6  ✓ qua được
	    Rthro cao : 3.4 × 0.5 = 1.7  > 1.6  ✗ CHẾT dù đang slide đúng cách

	Đúng bug user báo: "avatar to hơn thì slide không vượt qua được Zone 5". Người test bằng
	avatar chuẩn KHÔNG BAO GIỜ gặp, nên nó sống sót qua mọi lượt QA.

	Giờ đọc CỜ TƯỜNG MINH `MovementSlide.SLIDING_ATTRIBUTE` — không còn con số nào phụ thuộc
	cỡ người. Song song, `Server/Services/Core/AvatarScaleService` chuẩn hoá cỡ avatar về R15
	mặc định để mọi khe chui VẬT LÝ trong map cũng đúng cho tất cả; hai thứ này bổ sung cho
	nhau, không thay thế nhau (tắt cái này thì cái kia vẫn phải đúng).

	Self-kill (client sở hữu nhân vật) → khớp cảm giác 100%, 0 packet. 25 player vẫn nhẹ
	(mỗi client chỉ kiểm tra bản thân với ≤ vài tường).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MovementSlide = require(script.Parent.Parent.Movement.MovementSlide)

local Zone5SlideController = {}

local player = Players.LocalPlayer

function Zone5SlideController.Init() end

function Zone5SlideController.Start()
	task.spawn(function()
		local zones = workspace:WaitForChild("Zones", 20)
		local zone5 = zones and zones:WaitForChild("Zone5", 20)
		local mech = zone5 and zone5:WaitForChild("Mechanics", 20)
		local gates = mech and mech:WaitForChild("SlideGates", 20)
		if not gates then
			return
		end

		-- gom các EnergyWall (tường tĩnh — gom 1 lần, cập nhật khi thêm/bớt)
		local walls = {}
		local function refresh()
			table.clear(walls)
			for _, c in gates:GetChildren() do
				if c.Name == "EnergyWall" and c:IsA("BasePart") then
					table.insert(walls, c)
				end
			end
		end
		refresh()
		gates.ChildAdded:Connect(refresh)
		gates.ChildRemoved:Connect(refresh)

		local dead = false

		RunService.Heartbeat:Connect(function()
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not (hum and root) or hum.Health <= 0 then
				dead = false
				return
			end
			if dead then
				return
			end
			-- đang slide? (cờ tường minh do MovementSlide đặt — KHÔNG suy từ HipHeight)
			if hum:GetAttribute(MovementSlide.SLIDING_ATTRIBUTE) == true then
				return
			end
			local pos = root.Position
			for _, wall in walls do
				local size = wall.Size
				local lp = wall.CFrame:PointToObjectSpace(pos)
				local inFootprint = math.abs(lp.X) <= size.X / 2 + 0.5 and math.abs(lp.Z) <= size.Z / 2 + 0.5
				local wallBottom = wall.Position.Y - size.Y / 2
				local wallTop = wall.Position.Y + size.Y / 2
				local inHeight = pos.Y >= wallBottom - 14 and pos.Y <= wallTop + 2
				if inFootprint and inHeight then
					dead = true
					hum.Health = 0
					break
				end
			end
		end)
		Log.Boot("[Zone5SlideController] cổng bắt buộc slide (client) sẵn sàng")
	end)
end

return Zone5SlideController
