--!strict
--[[
	AvatarScaleService — CHUẨN HOÁ CỠ AVATAR (2026-08-21).

	══ VÌ SAO CÓ FILE NÀY ═══════════════════════════════════════════════════════════════════

	Bug user báo: "player có avatar to hơn thì khi slide không vượt qua được Zone 5".

	Đây không phải một lỗi lẻ của Zone 5 — nó là triệu chứng của một giả định sai nằm rải
	khắp game: **mọi phép đo hình học trong map đều ngầm cho rằng người chơi cao đúng 5 studs**
	(R15 chuẩn, `HipHeight = 2.0`). Khe chui, hành lang, tầm nhảy, mọi thứ đều dựng theo đó.
	Roblox thì cho phép avatar cao từ ~4.5 tới ~6.5 studs — chênh gần 45%.

	Hệ quả cụ thể đã đo được ở Zone 5 (xem thêm `Zone5SlideController`):
	    HipHeight lúc slide = HipHeight đứng × 0.5   (`MovementConfig.Slide.HipHeightFactor`)
	    Ngưỡng nhận biết "đang slide" = 1.6
	  ⇒ avatar nào có HipHeight đứng ≥ 3.2 thì slide xong VẪN bị tính là đứng thẳng → chết,
	    không cách nào qua cổng. Người chơi avatar chuẩn (2.0 → 1.0) không bao giờ gặp.

	Cái ngưỡng đó đã được sửa riêng ở `Zone5SlideController` (giờ đọc cờ tường minh chứ không
	suy từ HipHeight). Nhưng sửa một chỗ chỉ vá một triệu chứng: mọi khe chui vật lý trong map
	vẫn hẹp cố định, và avatar 6.5 studs vẫn kẹt ở đó. Chuẩn hoá cỡ avatar là cách DUY NHẤT
	làm cho hình học của map đúng cho tất cả mọi người.

	══ CÁCH LÀM, VÀ VÌ SAO KHÔNG DÙNG `ApplyDescription` ════════════════════════════════════

	Ghi thẳng vào các `NumberValue` cỡ trong `Humanoid` (`BodyHeightScale`, …). Engine áp dụng
	ngay lập tức và không tốn một web request nào.

	`humanoid:ApplyDescription()` thì ngược lại: nó tải LẠI toàn bộ trang phục/phụ kiện của
	người chơi từ web mỗi lần gọi — hàng chục asset, ngay lúc spawn, đúng lúc client đang bận
	nhất. Trên máy yếu (Redmi A2+ đang nghẽn CPU) đó là một cú đơ thấy được, chỉ để đổi bốn
	con số.

	══ ĐÁNH ĐỔI, NÓI THẲNG ═════════════════════════════════════════════════════════════════

	`BodyTypeScale = 0` + `BodyProportionScale = 0` đưa mọi người về dáng CLASSIC (khối vuông).
	Người chơi mua bundle Rthro sẽ thấy dáng người mình đổi. Đây là đánh đổi CÓ CHỦ Ý và là
	cách đại đa số game obby/parkour Roblox làm: công bằng về hình học quan trọng hơn dáng
	người, vì một cổng chui không qua được là hỏng hẳn phần chơi, còn dáng người thì không.

	Trang phục, mặt, tóc, màu da, phụ kiện GIỮ NGUYÊN 100% — file này chỉ đụng vào cỡ.

	Muốn nới lỏng: hạ `ENFORCE` xuống `false` (tắt hẳn), hoặc chỉnh `TARGET` cho từng số.

	══ CÁCH KHÔNG CẦN CODE (nếu muốn thay thế file này) ═════════════════════════════════════

	Studio → Game Settings → Avatar → Avatar Type `R15`, và đặt Scale min = max = 1.0 cho cả
	Height/Width/Head, Body Type = 0. Roblox áp trước khi nhân vật spawn nên không có nháy
	hình và không tốn runtime. Nhược điểm: nó là cài đặt trên Dashboard, KHÔNG nằm trong git —
	sang universe khác (World 2, place test) là mất, và không ai review được nó trong PR. Vì
	vậy file này vẫn giữ vai trò chốt chặn cuối cùng; hai cách đặt cùng lúc không xung đột.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Players = game:GetService("Players")

local AvatarScaleService = {}

-- Bật/tắt toàn bộ. `false` = trả avatar về đúng như người chơi cấu hình.
local ENFORCE = true

--[[
	Cỡ chuẩn. Đây chính là bộ số của một avatar R15 mặc định — `HipHeight` ra đúng 2.0, tức là
	con số mà mọi hình học trong map đã được dựng theo.

	⚠️ Đổi bất kỳ số nào ở đây là đổi HÌNH HỌC của cả game. `HipHeightFactor` của slide, ngưỡng
	của các cổng chui, chiều cao trần hành lang — tất cả suy ra từ đây.
]]
local TARGET: { [string]: number } = {
	BodyHeightScale = 1,
	BodyWidthScale = 1,
	BodyDepthScale = 1,
	HeadScale = 1,
	BodyTypeScale = 0,
	BodyProportionScale = 0,
}

local function pin(humanoid: Humanoid, name: string, want: number)
	local value = humanoid:FindFirstChild(name)
	if not value or not value:IsA("NumberValue") then
		-- R6 hoặc rig tự dựng: không có mấy NumberValue này. Không phải lỗi.
		return
	end
	if value.Value ~= want then
		value.Value = want
	end
	--[[
		Ghim luôn, không chỉ ghi một lần.

		Roblox nạp trang phục theo nhiều đợt và có đợt ghi đè lại cỡ SAU khi `CharacterAdded`
		đã chạy — ghi đúng một lần là thua cuộc đua đó một cách im lặng, mà lại chỉ thua với
		một số avatar nên rất khó tái hiện. `Changed` chỉ nổ khi có ai đó thật sự ghi số khác,
		nên đây không phải vòng lặp mỗi frame.
	]]
	value.Changed:Connect(function(newValue)
		if ENFORCE and newValue ~= want then
			value.Value = want
		end
	end)
end

local function normalize(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	end
	if not humanoid then
		warn("[AvatarScaleService] không tìm thấy Humanoid — bỏ qua chuẩn hoá cỡ avatar")
		return
	end

	for name, want in TARGET do
		pin(humanoid, name, want)
	end
end

function AvatarScaleService.Init() end

function AvatarScaleService.Start()
	if not ENFORCE then
		Log.Boot("[AvatarScaleService] ĐANG TẮT — avatar giữ nguyên cỡ người chơi tự chỉnh")
		return
	end

	local function hook(player: Player)
		player.CharacterAdded:Connect(normalize)
		if player.Character then
			normalize(player.Character)
		end
	end

	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerAdded:Connect(hook)

	Log.Boot("[AvatarScaleService] chuẩn hoá cỡ avatar về R15 mặc định (HipHeight 2.0)")
end

return AvatarScaleService
