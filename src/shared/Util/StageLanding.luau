--!strict
--[[
	StageLanding.luau — điểm ĐÁP chuẩn khi vào một stage bằng teleport / hồi sinh / Skip Stage.

	QUY TẮC DUY NHẤT: luôn đáp xuống CHÍNH GIỮA part `Transition{N-1}To{N}` — cái bệ phẳng
	nối hai zone — chứ không phải xuống vạch `Stage{N}Start`.

	Vì sao không dùng vạch Start:
	  • Vạch Start là một part MỎNG nằm chìm dưới mặt đi (xem ghi chú "mạch chạy tại vạch
	    Stage"): đáp ngay trên nó dễ rơi lệch mép hoặc kẹt trong hình học của cổng.
	  • Đáp ĐÚNG trên vạch có thể ăn `Touched` ngay lúc chưa kịp đứng vững, hoặc ngược lại
	    bỏ lỡ `Touched` vì nhân vật xuất hiện phía trong vạch.
	  • Bệ Transition thì rộng (48–72 studs), phẳng, và nằm NGAY TRƯỚC vạch Start ⇒ đáp giữa
	    bệ rồi chạy tới là ăn `Touched` một cách tự nhiên, giống hệt người chơi chạy bộ tới.

	Stage 1 KHÔNG có `Transition0To1` (vào từ Lobby) → trả nil, caller tự fallback.

	Các part Transition nằm rải rác: 1To2..7To8 ở `Zone{from}`, còn 8To9..14To15 lại ở
	`Zone{from+1}` → phải tìm ĐỆ QUY theo tên thay vì đoán đường dẫn.
]]

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StageFacing = require(ReplicatedStorage.Shared.Util.StageFacing)

local StageLanding = {}

-- Khoảng nhấc HumanoidRootPart lên trên mặt bệ (nhân vật cao ~5 studs tính từ root).
local ROOT_HEIGHT = 4

function StageLanding.FindTransition(fromStage: number): BasePart?
	local zonesFolder = Workspace:FindFirstChild("Zones")
	if not zonesFolder then
		return nil
	end
	local transition = zonesFolder:FindFirstChild(`Transition{fromStage}To{fromStage + 1}`, true)
	return if transition and transition:IsA("BasePart") then transition :: BasePart else nil
end

-- Tâm mặt trên của bệ Transition dẫn VÀO `stage`, mặt quay theo chiều chạy của stage đó.
function StageLanding.GetEntryCFrame(stage: number): CFrame?
	if stage <= 1 then
		return nil
	end

	local transition = StageLanding.FindTransition(stage - 1)
	if not transition then
		return nil
	end

	local position = transition.Position + Vector3.new(0, (transition.Size.Y * 0.5) + ROOT_HEIGHT, 0)
	return StageFacing.Orient(position, stage, transition.CFrame)
end

return StageLanding
