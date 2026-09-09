--!strict
--[[
	CosmeticVisualController.luau — Render Trail/Aura CLIENT-SIDE cho MỌI player.

	Server không còn tạo instance hiệu ứng nào; nó chỉ đồng bộ 2 attribute trên Player:
	  • EquippedTrail — id trail đang trang bị ("none" = không)
	  • EquippedAura  — id aura đang trang bị ("none" = không)
	Mỗi client lắng nghe attribute + CharacterAdded của tất cả player trong server và
	tự dựng Trail/ParticleEmitter cục bộ → giảm replication + cho phép client tùy chỉnh
	(vd. tắt hiệu ứng người khác khi cần tối ưu máy yếu).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CosmeticVisualController = {}

local TRAIL_OBJECT = "SpeedEscapeEquippedTrail"
local TRAIL_ATTACH_A = "SpeedEscapeTrailAttachmentA"
local TRAIL_ATTACH_B = "SpeedEscapeTrailAttachmentB"
-- Hạt/khói/tia lửa đi kèm trail premium (2026-07-29). Trước đây bị `Destroy()` nên trail
-- premium trên người chơi chỉ còn dải ribbon trơn, mất hết phần VFX làm nên giá trị của nó.
local TRAIL_FX_OBJECT = "SpeedEscapeTrailFX"
local AURA_OBJECT = "SpeedEscapeEquippedAura"

-- Kho template KHÔNG bị StreamingEnabled dỡ (ReplicatedStorage.CosmeticTemplates):
--   • AuraBasic.Torso        — rig aura standard (8 Beam + 13 ParticleEmitter + Full body aura)
--   • PremiumTrails.<id>     — part gốc của 3 trail premium, đủ Trail lẫn ParticleEmitter
-- Bản trong Workspace (Lobby.TrailBase / model user đặt tay) chỉ là fallback.
local function getTemplateFolder(): Instance?
	return ReplicatedStorage:FindFirstChild("CosmeticTemplates")
end

local function getTemplate(category: string, name: string): Instance?
	local folder = getTemplateFolder()
	local group = folder and folder:FindFirstChild(category)
	return group and group:FindFirstChild(name) or nil
end

-- Template nằm THẲNG dưới CosmeticTemplates (không thuộc nhóm nào) — vd rig `Aura_FrozenBloom`.
local function getRootTemplate(name: string): Instance?
	local folder = getTemplateFolder()
	return folder and folder:FindFirstChild(name) or nil
end

type TrailVisual = {
	color: ColorSequence,
	lifetime: number,
	texture: string,
	textureLength: number,
	widthScale: number,
	lightEmission: number,
}

--[[
	⚠️ `lightEmission` PHẢI THẤP — ĐỌC TRƯỚC KHI TĂNG (hạ toàn bộ 2026-08-11).

	Bản cũ để 0.75–1.0 và người chơi báo "đẹp nhưng sáng quá, không rõ màu". Đây KHÔNG phải
	chuyện độ sáng màn hình, mà là cách Roblox trộn màu:

	  LightEmission đẩy `Trail` từ trộn alpha sang trộn CỘNG. Ở 1.0 thì mỗi lớp ribbon cộng
	  thẳng giá trị màu vào cái đằng sau nó. Mà vệt trail thì TỰ CHỒNG LÊN CHÍNH NÓ liên tục:
	  mỗi lần người chơi quay người, bẻ lái, nhảy — hai ba đoạn vệt nằm đè lên nhau. Ba lớp
	  (0.9, 0.7, 0.5) của cùng một màu là mọi kênh vượt 1.0 và bão hoà thành TRẮNG. Người
	  chơi chỉ còn thấy màu ở rìa vệt, đúng như ảnh họ gửi.

	  Ở tốc độ của game này (100–250 WS) vệt còn dài và gấp khúc hơn nữa, nên nó trắng gần
	  như thường trực chứ không chỉ lúc quay gấp.

	Mức đang dùng: 0.28–0.35 cho trail thường (đủ để vẫn "phát sáng" trên nền tối mà màu
	không bay), 0.45–0.55 cho nhóm cao cấp dùng texture sparkles — nhóm này texture đã là
	đốm trắng nên cần thêm chút cộng sáng, nhưng vẫn phải dưới 0.6.

	Muốn một trail NỔI hơn thì tăng `widthScale` hoặc làm màu đậm hơn, ĐỪNG tăng cái này.
]]
local TRAIL_VISUALS: { [string]: TrailVisual } = {
	trail_green = {
		color = ColorSequence.new(Color3.fromRGB(79, 255, 111), Color3.fromRGB(13, 171, 65)),
		lifetime = 0.5,
		texture = "",
		textureLength = 1,
		widthScale = 1,
		lightEmission = 0.28,
	},
	trail_blue = {
		color = ColorSequence.new(Color3.fromRGB(89, 207, 255), Color3.fromRGB(43, 91, 255)),
		lifetime = 0.55,
		texture = "",
		textureLength = 1,
		widthScale = 1,
		lightEmission = 0.28,
	},
	trail_purple = {
		color = ColorSequence.new(Color3.fromRGB(207, 112, 255), Color3.fromRGB(98, 45, 255)),
		lifetime = 0.6,
		texture = "",
		textureLength = 1,
		widthScale = 1,
		lightEmission = 0.3,
	},
	trail_red = {
		color = ColorSequence.new(Color3.fromRGB(255, 95, 76), Color3.fromRGB(210, 24, 40)),
		lifetime = 0.6,
		texture = "",
		textureLength = 1,
		widthScale = 1,
		lightEmission = 0.3,
	},
	--[[
		Rookie Rocket (Starter Pack) — PHỐI MÀU "ROCKET SUNSET" (2026-08-11).

		Bản đầu là lửa cream→cam→đỏ thuần. Vấn đề: đặt cạnh `trail_red` và `aura_fire` thì
		không ai phân biệt được — món ĐỘC QUYỀN của gói 99 R$ lại trông y như trail rẻ nhất
		shop, mất sạch giá trị khoe.

		Bản này giữ ĐẦU vệt là lửa thật (cream nóng → hổ phách) nhưng ĐUÔI chuyển sang đúng
		hai màu của thẻ Starter Pack (coral → raspberry) rồi tắt vào tím. Ba cái lợi:
		  • Nhìn vệt là nhận ra cái thẻ mình vừa mua — trail và banner bán hàng cùng một bảng màu.
		  • Warm-head + pink/violet-tail KHÔNG trùng trail nào: nebula và galaxy đều đi từ
		    lạnh (teal/blue) sang tím, không có đoạn lửa ở đầu.
		  • Tím ở cuối làm nền cho phần cam sáng nhất bật lên — vệt đọc được cả trên trời sáng
		    của Lobby lẫn nền tối trong zone.

		Tên màu (dùng chung cho icon — xem docs khi vẽ):
		  Ivory Flash 255,246,214 · Sunburst Amber 255,178,52 · Coral Flame 255,122,64
		  · Raspberry Pop 226,40,96 · Violet Dusk 124,60,235
	]]
	trail_rookie = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 246, 214)), -- Ivory Flash
			ColorSequenceKeypoint.new(0.22, Color3.fromRGB(255, 178, 52)), -- Sunburst Amber
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 122, 64)), -- Coral Flame
			ColorSequenceKeypoint.new(0.72, Color3.fromRGB(226, 40, 96)), -- Raspberry Pop
			ColorSequenceKeypoint.new(1, Color3.fromRGB(124, 60, 235)), -- Violet Dusk
		}),
		-- Dài hơn bản cũ (0.72 → 0.85) vì phối 5 chặng: vệt ngắn thì bốn màu sau dồn vào vài
		-- studs cuối và nhoè thành một mảng nâu.
		lifetime = 0.85,
		texture = "",
		textureLength = 1,
		widthScale = 1.25,
		-- Cao hơn trail thường một nhịp: đây là lửa tên lửa, cần chút cộng sáng ở lõi. Nhưng
		-- vẫn phải thấp, nếu không đúng cái phối 5 màu ở trên là thứ đầu tiên bay mất.
		lightEmission = 0.35,
	},
	--[[
		VIP GOLD — ⚠️ ĐÂY CHỈ LÀ BẢN DỰ PHÒNG (2026-08-12).

		Hình dạng THẬT của trail VIP là bộ 5 ribbon trong
		`ReplicatedStorage.CosmeticTemplates.PremiumTrails.trail_vip` — cùng bộ hoạ tiết mà
		Mystic Violet và Crimson Fury đang dùng, chỉ khác bảng màu (đó đúng là cách dòng trail
		cao cấp phân biệt nhau). `applyTrail` tìm template đó TRƯỚC; bảng dưới đây chỉ chạy khi
		kho template chưa có.

		Vì sao bỏ hẳn hướng "một ribbon + texture sparkles": texture đốm với `textureLength`
		nhỏ lặp lại dọc vệt, mà vệt thì co giãn theo tốc độ chạy ⇒ các đốm tách rời nhau và
		vệt nhìn ĐỨT QUÃNG (user báo 2026-08-12). Ribbon liền không có bệnh đó. Bản dự phòng
		dưới đây vì thế cũng để `texture = ""`.

		Phối màu "VÀNG RÒNG NUNG CHẢY":

		Đây là trail của món đắt nhất shop nên nó phải đọc ra là KIM LOẠI QUÝ, không phải
		"một vệt lửa nữa". Ba quyết định làm nên chất đó:

		  • ĐẦU vệt là ivory ngả xanh cực nhạt (255,252,236) chứ không phải trắng thuần. Vàng
		    thật luôn có một điểm loé lạnh ở chỗ phản chiếu mạnh nhất; trắng thuần cho ra
		    cảm giác "đèn pin", ivory ấm cho ra cảm giác "bề mặt bóng".
		  • THÂN đi champagne → vàng ròng → hổ phách, các chặng SÁT NHAU (0.16/0.34/0.55).
		    Vàng là một dải hẹp: kéo giãn ra thì nó tãi thành vàng chanh nhạt và mất chất kim
		    loại ngay.
		  • ĐUÔI tắt vào đồng nung rồi bronze sẫm (74,32,8) — KHÔNG tắt vào đen. Bronze giữ
		    hơi ấm ở cuối vệt nên toàn dải vẫn đọc ra một khối kim loại liền mạch, còn đen thì
		    cắt vệt làm hai khúc.

		KHÔNG trùng món nào đang có: `trail_rookie` cũng khởi đầu bằng lửa nhưng rẽ sang
		coral → raspberry → violet ở nửa sau; VIP ở lại trọn vẹn trong trục vàng–cam–đồng.

		`lightEmission` 0.34 — vàng bão hoà sẵn kênh R+G, chỉ còn B để chịu cộng chồng, nên
		đẩy cao là lõi vệt trắng ra và đúng cái dải vàng hẹp ở trên bay mất trước tiên.
	]]
	trail_vip = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 252, 236)), -- Ivory Gleam
			ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 233, 156)), -- Champagne
			ColorSequenceKeypoint.new(0.34, Color3.fromRGB(255, 199, 48)), -- Royal Gold
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 150, 26)), -- Amber Blaze
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(212, 82, 14)), -- Copper Ember
			ColorSequenceKeypoint.new(1, Color3.fromRGB(74, 32, 8)), -- Deep Bronze
		}),
		lifetime = 0.95,
		texture = "",
		textureLength = 1,
		widthScale = 1.8,
		lightEmission = 0.34,
	},
	trail_rainbow = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 52, 52)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 176, 43)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 245, 65)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(58, 235, 82)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(65, 163, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(188, 81, 255)),
		}),
		lifetime = 0.72,
		texture = "",
		textureLength = 1,
		widthScale = 1.15,
		-- Thấp nhất nhóm: cầu vồng là trail DUY NHẤT mà giá trị nằm ở chỗ phân biệt được
		-- từng dải màu. Cộng sáng cao là sáu dải nhoè vào nhau thành một vệt trắng hồng.
		lightEmission = 0.26,
	},
	-- Galaxy: lõi trắng rực → xanh thiên hà → tím → magenta → rìa space tối; kèm bụi sao (applyTrail).
	trail_galaxy = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.12, Color3.fromRGB(150, 190, 255)),
			ColorSequenceKeypoint.new(0.34, Color3.fromRGB(88, 66, 255)),
			ColorSequenceKeypoint.new(0.58, Color3.fromRGB(190, 44, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(255, 64, 200)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 10, 66)),
		}),
		lifetime = 0.8,
		texture = "",
		textureLength = 1,
		widthScale = 1.2,
		lightEmission = 0.34,
	},
	--[[
		STREAK AURORA (thưởng điểm danh Ngày 7) — vẽ lại theo CỰC QUANG THẬT, 2026-08-14.

		Bản trước là ba màu: trắng → xanh ngọc → lục → tím. Nó "xanh lá đẹp" nhưng không ai
		nhìn ra cực quang, và tệ hơn: đoạn lục (64,220,130) đặt cạnh `trail_green` (79,255,111)
		gần như trùng nhau, nên phần thưởng của chuỗi 7 ngày trông giống trail rẻ nhất shop —
		đúng cái bẫy mà Rookie Rocket đã phải thoát ra.

		Bản này đi theo QUANG PHỔ THẬT của cực quang, và đó cũng là thứ làm nó không đụng hàng:
		  • 557.7nm — lục ánh ngọc, dải sáng nhất và là màu ai cũng nhớ khi nghe "aurora".
		  • 630nm — đỏ thẫm ngả hồng ở rìa trên, chỉ hiện ở bão từ mạnh; đây là màu KHÔNG trail
		    nào khác trong game có ở vị trí đuôi vệt.
		  • Giữa hai đầu là lam-tím (427.8nm, nitơ ion hoá) nối chúng lại.
		Đọc từ đầu vệt ra đuôi: lõi trắng lạnh → lục ngọc → ngọc lam → lam đêm → tím → hồng
		đỏ. Sáu chặng nghe như nhiều, nhưng vệt ở tốc độ 100–250 WS dài tới mức mỗi chặng vẫn
		chiếm cả mét — đứng yên mới thấy chúng chen nhau.

		Vì sao KHÔNG đụng hàng: crystal là xanh dương đơn sắc, nebula đi ngọc→tím→hồng nhưng
		KHÔNG có đoạn lục, galaxy tối dần về đuôi. Aurora là trail duy nhất mang cả lục LẪN
		hồng, và là trail duy nhất SÁNG DẦN chứ không tối dần ở đuôi.

		── VỆT LIỀN, KHÔNG TEXTURE (sửa 2026-08-14, user: "trail không được đứt quãng") ──────
		Bản trước dùng `sparkles_main.dds` với `textureLength` 0.4 như nhóm crystal/nebula. Texture
		đó là một đốm sáng có viền trong suốt, lát lại mỗi 0.4 stud theo chiều dài vệt — nên vệt
		không phải một dải liền mà là một CHUỖI ĐỐM RỜI, và khe hở giữa các đốm nhìn rõ thành sọc
		đứt quãng.

		Giờ đi theo ĐÚNG cấu trúc của nhóm trail base (`trail_green`/`blue`/`purple`/`rainbow`/
		`galaxy`): `texture = ""`, `textureLength = 1` — một dải ribbon đặc, liền mạch, và
		`ColorSequence` là thứ DUY NHẤT phân biệt nó với các trail khác. Đúng như vậy thì dải màu
		cực quang mới đọc được thành một dải chuyển sắc thay vì bị texture băm nhỏ.

		`lightEmission` hạ 0.45 → 0.32: mức 0.45–0.55 là dành riêng cho nhóm dùng texture sparkle
		(texture vốn là đốm trắng nên cần bù sáng). Ribbon đặc mà để 0.45 là màu bắt đầu bay —
		xem cảnh báo dài ở đầu bảng. `widthScale` 1.6 (dày hơn nhóm base 1.0–1.2 để xứng với phần
		thưởng 7 ngày, nhưng dưới nhóm sparkle 2.15–2.65 vì ribbon đặc trông dày hơn cùng con số).
	]]
	trail_streak_aurora = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(232, 255, 246)), -- lõi trắng lạnh
			ColorSequenceKeypoint.new(0.16, Color3.fromRGB(138, 255, 176)), -- lục ngọc 557.7nm
			ColorSequenceKeypoint.new(0.36, Color3.fromRGB(52, 236, 214)), -- ngọc lam
			ColorSequenceKeypoint.new(0.56, Color3.fromRGB(58, 158, 255)), -- lam đêm
			ColorSequenceKeypoint.new(0.78, Color3.fromRGB(146, 104, 255)), -- tím 427.8nm
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 96, 186)), -- hồng đỏ 630nm
		}),
		lifetime = 0.95,
		texture = "",
		textureLength = 1,
		widthScale = 1.6,
		lightEmission = 0.32,
	},
	trail_crystal = {
		color = ColorSequence.new(Color3.fromRGB(137, 245, 255), Color3.fromRGB(58, 148, 255)),
		lifetime = 1.1,
		texture = "rbxasset://textures/particles/sparkles_main.dds",
		textureLength = 0.45,
		widthScale = 2.15,
		-- Xanh băng vốn đã rất nhạt: đây là trail dễ bay màu nhất, để thấp nhất nhóm sparkle.
		lightEmission = 0.45,
	},
	trail_nebula = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(73, 255, 210)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(106, 86, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 77, 224)),
		}),
		lifetime = 1.25,
		texture = "rbxasset://textures/particles/sparkles_main.dds",
		textureLength = 0.38,
		widthScale = 2.35,
		lightEmission = 0.5,
	},
	trail_singularity = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(101, 255, 212)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(22, 22, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 212, 75)),
		}),
		lifetime = 1.45,
		texture = "rbxasset://textures/particles/sparkles_main.dds",
		textureLength = 0.32,
		widthScale = 2.65,
		-- Cao nhất toàn bộ: trail đắt nhất game, và dải màu của nó có đoạn ĐEN (22,22,40) làm
		-- nền nên phần sáng không có gì để cộng chồng lên — nó chịu được mức này mà không bay.
		lightEmission = 0.55,
	},
}

type AuraVisual = {
	color: ColorSequence,
	texture: string,
	rate: number,
	size: NumberSequence,
	speed: NumberRange,
	lifetime: NumberRange,
	lightEmission: number,
}

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local AURA_VISUALS: { [string]: AuraVisual } = {
	aura_sparkle = {
		color = ColorSequence.new(Color3.fromRGB(255, 250, 180), Color3.fromRGB(255, 214, 64)),
		texture = SPARKLE_TEXTURE,
		rate = 14,
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.1) }),
		speed = NumberRange.new(1.5, 3),
		lifetime = NumberRange.new(0.7, 1.2),
		lightEmission = 0.9,
	},
	aura_fire = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 120)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 132, 32)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 32, 18)),
		}),
		texture = "rbxasset://textures/particles/fire_main.dds",
		rate = 22,
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0.2) }),
		speed = NumberRange.new(2.5, 4.5),
		lifetime = NumberRange.new(0.55, 0.9),
		lightEmission = 1,
	},
	aura_lightning = {
		color = ColorSequence.new(Color3.fromRGB(170, 220, 255), Color3.fromRGB(64, 130, 255)),
		texture = SPARKLE_TEXTURE,
		rate = 30,
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.08) }),
		speed = NumberRange.new(4, 8),
		lifetime = NumberRange.new(0.35, 0.6),
		lightEmission = 1,
	},
	aura_void = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 60, 255)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 12, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 4, 26)),
		}),
		texture = "rbxasset://textures/particles/smoke_main.dds",
		rate = 18,
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.4) }),
		speed = NumberRange.new(1, 2.2),
		lifetime = NumberRange.new(0.9, 1.5),
		lightEmission = 0.65,
	},
	-- Độc quyền Roulette: cyberpunk glitch — chớp magenta/cyan tốc độ cao.
	aura_glitch = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 180)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 255, 240)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 60, 255)),
		}),
		texture = SPARKLE_TEXTURE,
		rate = 42,
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.05), NumberSequenceKeypoint.new(1, 0.05) }),
		speed = NumberRange.new(5, 9),
		lifetime = NumberRange.new(0.25, 0.5),
		lightEmission = 1,
	},
	aura_cosmic = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(120, 200, 255)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(186, 100, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 214, 120)),
		}),
		texture = SPARKLE_TEXTURE,
		rate = 34,
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.25), NumberSequenceKeypoint.new(1, 0.12) }),
		speed = NumberRange.new(2.5, 5),
		lifetime = NumberRange.new(0.8, 1.4),
		lightEmission = 1,
	},
}

-- Tuỳ chọn "Hiệu ứng người chơi khác" trong bảng Cài đặt (TopBarController): máy yếu tắt đi
-- là bỏ hẳn việc dựng Trail/Aura cho MỌI người trừ bản thân.
local othersEnabled = true

local function shouldRender(player: Player): boolean
	return othersEnabled or player == Players.LocalPlayer
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- ── Trail ────────────────────────────────────────────────────────────────

-- Trail premium sau khi đã đổi sang trục dọc: giữ nguyên mẫu (parent = nil) để dựng lại
-- bất cứ lúc nào, kể cả khi Workspace.TrailBase đã bị streaming dỡ.
type PremiumRibbon = { proto: Trail, y0: number, y1: number }
type PremiumTrailSpec = {
	ribbons: { PremiumRibbon },
	-- ParticleEmitter con trực tiếp của part gốc + Attachment mang emitter (clone NGUYÊN
	-- cây để giữ mọi tham chiếu nội bộ), gắn thẳng lên HumanoidRootPart.
	fx: { Instance },
}
local premiumTrailCache: { [string]: PremiumTrailSpec } = {}

-- ẨN TRAIL PREMIUM KHI ĐỨNG YÊN (2026-07-29, yêu cầu user).
-- Trail premium toả hạt rất dày; người chơi đứng im thì chùm hạt đó CHỒNG LÊN aura đang
-- đeo, nhìn rối và bẩn. Vì vậy chỉ bật khi thật sự đang chạy. Dùng NGƯỠNG KÉP (hysteresis)
-- để không nhấp nháy ở quanh mốc; chỉ áp cho trail premium (loại có VFX hạt), trail
-- standard là dải màu trơn nên giữ nguyên hành vi cũ.
type TrailGate = { root: BasePart, items: { Instance }, visible: boolean }
local trailGate: { [Player]: TrailGate } = {}

local GATE_SHOW_SPEED = 14 -- studs/s: bắt đầu hiện
local GATE_HIDE_SPEED = 7 -- studs/s: ẩn hẳn
local GATE_INTERVAL = 0.1 -- giây giữa 2 lần kiểm tra (10 Hz là quá đủ cho bật/tắt)

local function setGateVisible(entry: TrailGate, visible: boolean)
	entry.visible = visible
	for _, item in entry.items do
		if item:IsA("Trail") or item:IsA("ParticleEmitter") then
			item.Enabled = visible
		end
	end
end

--[[
	── LOD HIỆU ỨNG THEO TẦM NHÌN (2026-08-23, user báo "trang bị cosmetic bị tụt fps nhẹ") ──

	RÀNG BUỘC USER ĐẶT RA: **không được giảm VFX hay đồ hoạ của cosmetic**. Vậy nên khối này
	KHÔNG đụng tới bất kỳ tham số tạo hình nào — màu, texture, size, lifetime, số lớp ribbon,
	số emitter đều giữ nguyên tuyệt đối. Thứ duy nhất bị cắt là hiệu ứng mà **không ai đang
	nhìn thấy**.

	── VÌ SAO CẮT Ở ĐÂY MỚI ĐÚNG CHỖ ──
	Vòng Heartbeat của file này đã chạy 10 Hz trên một bảng nhỏ ⇒ chi phí Lua gần như bằng 0.
	Nên "tụt fps nhẹ khi trang bị cosmetic" KHÔNG phải chi phí script mà là **chi phí GPU**:
	  • aura standard = 8 Beam + 13 ParticleEmitter mỗi người;
	  • trail premium = 5 ribbon trong suốt, dài 150 studs (`TARGET_TRAIL_LENGTH`);
	  • tất cả đều là mặt TRONG SUỐT ⇒ overdraw, thứ đắt nhất trên máy yếu;
	  • và nhân lên theo SỐ NGƯỜI trong server, ai cũng vẽ đủ dù đứng sau lưng camera.

	── BA BẬC ──
	  bậc 0 (đầy đủ): trong tầm nhìn và gần hơn LOD_NEAR_STUDS  → y hệt trước đây
	  bậc 1 (thưa):   trong tầm nhìn, LOD_NEAR..LOD_FAR         → Rate × LOD_MID_RATE_SCALE
	  bậc 2 (tắt):    xa hơn LOD_FAR, HOẶC nằm sau lưng camera  → Rate = 0, Beam tắt

	Ở bậc 1 hạt thưa đi, nhưng ở khoảng cách đó cả chùm hạt chiếm vài chục pixel — mắt không
	phân biệt được mật độ. Ở bậc 2 thì theo định nghĩa không ai nhìn thấy.

	── HAI NGUYÊN TẮC AN TOÀN (đừng phá khi sửa) ──
	1. **Người chơi CỦA MÁY NÀY không bao giờ bị hạ bậc.** Cosmetic của chính mình là thứ họ
	   bỏ tiền ra mua và nhìn suốt phiên chơi — hạ nó là đúng thứ user cấm.
	2. **Chỉ ghi `Rate` của ParticleEmitter và `Enabled` của Beam.** Cổng ẩn-khi-đứng-yên ở
	   trên (`setGateVisible`) ghi `Enabled` của Trail và ParticleEmitter. Hai hệ chạm vào hai
	   thuộc tính KHÁC NHAU nên không bao giờ giẫm chân nhau. Nếu sau này định cho LOD ghi
	   `Enabled` của emitter, phải gộp hai hệ lại làm một chứ đừng ghi song song — chúng sẽ
	   bật/tắt lẫn nhau mỗi 0,1 giây.

	Dùng `Rate = 0` thay vì `Enabled = false`: hạt đang sống bay nốt vòng đời rồi mới hết,
	nên lúc hạ bậc không thấy chớp tắt đột ngột.
]]
local LOD_NEAR_STUDS = 140
local LOD_FAR_STUDS = 340
local LOD_MID_RATE_SCALE = 0.35
-- Tích vô hướng giữa hướng camera và hướng tới người chơi. Nhỏ hơn mức này = nằm rõ ràng
-- sau lưng. Để -0.35 chứ không phải 0 vì FOV rộng và camera vai lệch: cắt sát 0 là hiệu ứng
-- chớp mất ở rìa màn hình khi xoay người.
local LOD_BEHIND_DOT = -0.35

type LodEntry = {
	root: BasePart,
	emitters: { ParticleEmitter },
	beams: { Beam },
	baseRate: { [ParticleEmitter]: number },
	tier: number,
}
local lodEntries: { [Player]: LodEntry } = {}

-- Duyệt character MỘT LẦN lúc vừa gắn cosmetic (hiếm) thay vì mỗi tick.
local function buildLodEntry(player: Player): LodEntry?
	local root = getRoot(player)
	local character = player.Character
	if not root or not character then
		return nil
	end

	local entry: LodEntry = {
		root = root,
		emitters = {},
		beams = {},
		baseRate = {},
		tier = 0,
	}

	for _, descendant in character:GetDescendants() do
		local name = descendant.Name
		if name ~= TRAIL_OBJECT and name ~= TRAIL_FX_OBJECT and name ~= AURA_OBJECT then
			continue
		end
		if descendant:IsA("ParticleEmitter") then
			table.insert(entry.emitters, descendant)
			entry.baseRate[descendant] = descendant.Rate
		elseif descendant:IsA("Beam") then
			table.insert(entry.beams, descendant)
		end
	end

	-- Emitter nằm SÂU bên trong rig aura (Attachment/Model con) mang tên riêng của template
	-- chứ không phải AURA_OBJECT — vòng trên bỏ sót chúng. Quét thêm một lượt từ những nút
	-- đã mang đúng tên: mọi thứ bên dưới chúng đều là hiệu ứng cosmetic.
	for _, descendant in character:GetDescendants() do
		if descendant.Name ~= AURA_OBJECT and descendant.Name ~= TRAIL_FX_OBJECT then
			continue
		end
		for _, sub in descendant:GetDescendants() do
			if sub:IsA("ParticleEmitter") and entry.baseRate[sub] == nil then
				table.insert(entry.emitters, sub)
				entry.baseRate[sub] = sub.Rate
			elseif sub:IsA("Beam") then
				table.insert(entry.beams, sub)
			end
		end
	end

	lodEntries[player] = entry
	return entry
end

local function applyLodTier(entry: LodEntry, tier: number)
	if entry.tier == tier then
		return
	end
	entry.tier = tier

	local scale = if tier >= 2 then 0 elseif tier == 1 then LOD_MID_RATE_SCALE else 1
	for _, emitter in entry.emitters do
		if emitter.Parent then
			emitter.Rate = (entry.baseRate[emitter] or 0) * scale
		end
	end

	local beamsOn = tier < 2
	for _, beam in entry.beams do
		if beam.Parent then
			beam.Enabled = beamsOn
		end
	end
end

local function invalidateLod(player: Player)
	local entry = lodEntries[player]
	if entry then
		-- Đổi trail vẫn giữ aura cũ: trả Rate gốc trước khi chụp lại, tránh lấy Rate đã cull làm gốc.
		applyLodTier(entry, 0)
	end
	lodEntries[player] = nil
end

local function stepCosmeticLod()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local camCF = camera.CFrame
	local camPos = camCF.Position
	local look = camCF.LookVector
	local localPlayer = Players.LocalPlayer

	for _, player in Players:GetPlayers() do
		if player == localPlayer then
			continue -- nguyên tắc 1: không bao giờ hạ bậc cosmetic của chính mình
		end

		local entry = lodEntries[player]
		if entry and (entry.root.Parent == nil or player.Character ~= entry.root.Parent) then
			entry = nil
			lodEntries[player] = nil
		end
		if not entry then
			entry = buildLodEntry(player)
		end
		if not entry or (#entry.emitters == 0 and #entry.beams == 0) then
			continue
		end

		local offset = entry.root.Position - camPos
		local distance = offset.Magnitude
		local behind = distance > 1 and look:Dot(offset.Unit) < LOD_BEHIND_DOT
		local tier
		if distance > LOD_FAR_STUDS or behind then
			tier = 2
		elseif distance > LOD_NEAR_STUDS then
			tier = 1
		else
			tier = 0
		end
		applyLodTier(entry, tier)
	end
end

local MAX_TRAIL_SPAN = 4.6 -- ribbon cao hơn thân nhân vật thì thu lại (Golden Ray 6.37)

-- ĐỘ DÀI VỆT KHÔNG ĐỔI THEO TỐC ĐỘ (2026-07-28) — cách sửa "hoa văn bị lặp".
--
-- Lịch sử hai lần hỏng, cả hai đều do một nguyên nhân: chiều dài vệt = tốc độ × Lifetime,
-- mà Lifetime cố định 1.0s nên ở 250 studs/s vệt dài 250 studs.
--   • Stretch + Lifetime 1.0 ⇒ MỘT ảnh bị kéo trải 250 studs ⇒ nhoè thành vệt mờ.
--   • Wrap + TextureLength ~8.7 ⇒ ảnh lát lại HƠN 20 LẦN ⇒ thấy rõ hoa văn lặp (user báo).
-- Đổi TextureLength không cứu được: mọi giá trị cố định đều sai ở một dải tốc độ nào đó.
--
-- Sửa tận gốc: giữ `Stretch` (đúng như template được thiết kế — MỘT hoạ tiết trọn vẹn,
-- không bao giờ lặp) và điều khiển `Lifetime` sao cho vệt luôn dài ~TARGET_TRAIL_LENGTH
-- studs bất kể chạy nhanh hay chậm: `lifetime = TARGET / speed`.
--
-- Bám theo `Humanoid.WalkSpeed` chứ KHÔNG đo vận tốc mỗi frame: WalkSpeed là chỉ số của
-- game, hiếm khi đổi, nên chỉ cần cập nhật khi nó đổi ⇒ 0 chi phí mỗi frame cho cả 25 người.
-- 26 studs (vòng đầu) diệt được hoa văn lặp nhưng đuôi NGẮN HƠN HẲN trail standard —
-- standard để Lifetime cố định 0.5–0.8s nên ở 250 studs/s đuôi dài 125–200 studs, còn
-- premium chỉ 26. Nâng lên 150 để hai loại nhìn ngang nhau; vẫn giữ `Stretch` nên dù đuôi
-- dài bao nhiêu cũng CHỈ MỘT hoạ tiết, không bao giờ lặp lại.
local TARGET_TRAIL_LENGTH = 150
local MIN_TRAIL_LIFETIME = 0.5
local MAX_TRAIL_LIFETIME = 1.4

local function lifetimeForSpeed(speed: number): number
	return math.clamp(TARGET_TRAIL_LENGTH / math.max(speed, 1), MIN_TRAIL_LIFETIME, MAX_TRAIL_LIFETIME)
end

-- Đồng bộ Lifetime của ribbon CÓ TEXTURE theo WalkSpeed hiện tại.
-- Chỉ đụng trail có texture (= trail premium): trail standard phần lớn là dải màu trơn,
-- không có hoạ tiết nên không thể "lặp hình", và Lifetime của chúng là thiết kế sẵn có.
local function syncTrailLifetime(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local lifetime = lifetimeForSpeed(if humanoid then humanoid.WalkSpeed else 16)
	for _, descendant in character:GetDescendants() do
		if descendant.Name == TRAIL_OBJECT and descendant:IsA("Trail") and descendant.Texture ~= "" then
			descendant.Lifetime = lifetime
		end
	end
end

local function clearTrail(player: Player)
	local character = player.Character
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if
			descendant.Name == TRAIL_OBJECT
			or descendant.Name == TRAIL_ATTACH_A
			or descendant.Name == TRAIL_ATTACH_B
			or descendant.Name == TRAIL_FX_OBJECT
		then
			descendant:Destroy()
		end
	end
	trailGate[player] = nil
end

-- Tìm part gốc của trail premium: ưu tiên kho ReplicatedStorage (không bao giờ bị dỡ),
-- fallback về bệ trưng bày trong Lobby.TrailBase khi kho chưa có.
local function findPremiumTrailSource(trailId: string): BasePart?
	local template = getTemplate("PremiumTrails", trailId)
	if template and template:IsA("BasePart") then
		return template
	end

	local trailBase = workspace:FindFirstChild("TrailBase", true)
	local trailFolder = trailBase and trailBase:FindFirstChild(trailId)
	local baseModel = trailFolder and trailFolder:FindFirstChild("Base")
	if not baseModel then
		return nil
	end
	-- Base chứa NHIỀU part trùng tên "Part" (part trơn + part hiệu ứng) —
	-- FindFirstChild("Part") từng vớ part RỖNG → trail tàng hình sau khi mua.
	-- Chọn part có nhiều hiệu ứng (Trail/ParticleEmitter) nhất.
	local best: BasePart? = nil
	local bestCount = 0
	for _, child in baseModel:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "Billboard" then
			local count = 0
			for _, desc in child:GetDescendants() do
				if desc:IsA("Trail") or desc:IsA("ParticleEmitter") then
					count += 1
				end
			end
			if count > bestCount then
				bestCount = count
				best = child
			end
		end
	end
	return best
end

-- Dựng bản mẫu (parent = nil) từ part gốc: ribbon đổi sang trục dọc + gom VFX hạt.
local function buildPremiumTrailSpec(sourcePart: BasePart): PremiumTrailSpec?
	-- ⚠️ KHÔNG clone cả part rồi weld vào root. Part trưng bày nằm NGANG trên bệ, nên cặp
	-- Attachment của Trail trải theo trục X (±1.5 … ±3.2) và FaceCamera=false. Weld nguyên
	-- trạng vào nhân vật ⇒ dải trail nằm NGANG: nhìn từ trên xuống mới thấy, nhìn ngang thì
	-- mỏng như tờ giấy nên biến mất. Ở đây ta lấy RIÊNG các Trail rồi gắn lại lên cặp
	-- attachment DỌC, giữ nguyên texture/màu/width (phần làm nên vẻ premium).
	local templateTrails: { Trail } = {}
	local maxSpan = 0
	for _, desc in sourcePart:GetDescendants() do
		if desc:IsA("Trail") and desc.Attachment0 and desc.Attachment1 then
			table.insert(templateTrails, desc :: Trail)
			local span = math.abs(desc.Attachment0.Position.X - desc.Attachment1.Position.X)
			maxSpan = math.max(maxSpan, span)
		end
	end
	if #templateTrails == 0 then
		return nil
	end

	-- GIỮ NGUYÊN bề rộng gốc (Mystic 3.15 · Crimson 3.49 · Golden Ray 6.37+3.99) — ép hết về
	-- một cỡ là làm Golden Ray hụt gần nửa bề dày. Chỉ thu nhỏ khi ribbon cao quá thân nhân
	-- vật (MAX_SPAN), và thu theo TỈ LỆ để 2 ribbon lệch nhau của Golden Ray giữ đúng thiết kế.
	local scale = if maxSpan > MAX_TRAIL_SPAN then MAX_TRAIL_SPAN / maxSpan else 1
	local ribbons: { PremiumRibbon } = {}
	for _, src in templateTrails do
		local proto = src:Clone()
		proto.Name = TRAIL_OBJECT
		proto.FaceCamera = true -- nhìn từ MỌI góc đều thấy dải trail
		proto.Enabled = true
		-- Giữ Stretch của template: MỘT hoạ tiết trọn vẹn trải hết vệt, không lặp.
		-- Chiều dài vệt được giữ ổn định bằng Lifetime (xem TARGET_TRAIL_LENGTH).
		proto.TextureMode = Enum.TextureMode.Stretch
		-- template trưng bày để MinLength lớn thì trail chỉ hiện khi chạy rất nhanh
		proto.MinLength = math.min(proto.MinLength, 0.08)
		for _, sub in proto:GetDescendants() do
			if sub:IsA("LuaSourceContainer") or sub:IsA("ParticleEmitter") then
				sub:Destroy()
			end
		end
		table.insert(ribbons, {
			proto = proto,
			y0 = src.Attachment0.Position.X * scale,
			y1 = src.Attachment1.Position.X * scale,
		})
	end

	-- VFX HẠT — phần trước đây bị vứt đi. Hai kiểu bố trí trong asset gốc:
	--   • ParticleEmitter là con TRỰC TIẾP của part (Mystic: Fire/Smoke/Specs) → phát theo
	--     thể tích part, gắn thẳng lên HumanoidRootPart cho kết quả tương đương.
	--   • ParticleEmitter nằm trong Attachment (Crimson: BALL, Golden Ray: Spec1) → clone
	--     NGUYÊN Attachment để giữ cả cây con lẫn vị trí tương đối.
	local fx: { Instance } = {}
	local function collect(container: Instance)
		for _, child in container:GetChildren() do
			if child:IsA("ParticleEmitter") then
				local clone = child:Clone()
				clone.Name = TRAIL_FX_OBJECT
				clone.Enabled = true
				table.insert(fx, clone)
			elseif child:IsA("Attachment") then
				local hasEmitter = false
				for _, desc in child:GetDescendants() do
					if desc:IsA("ParticleEmitter") then
						hasEmitter = true
						break
					end
				end
				if hasEmitter then
					local clone = child:Clone()
					clone.Name = TRAIL_FX_OBJECT
					for _, desc in clone:GetDescendants() do
						if desc:IsA("ParticleEmitter") then
							desc.Enabled = true
						elseif desc:IsA("LuaSourceContainer") then
							desc:Destroy()
						end
					end
					table.insert(fx, clone)
				end
			end
		end
	end
	collect(sourcePart)

	return { ribbons = ribbons, fx = fx }
end

local function applyTrail(player: Player)
	local root = getRoot(player)
	if not root then
		return
	end

	local trailId = player:GetAttribute("EquippedTrail")
	clearTrail(player)
	if typeof(trailId) ~= "string" or trailId == "none" or not shouldRender(player) then
		return
	end

	-- Bản dựng sẵn (nếu đã từng thấy template): TrailBase nằm ở LOBBY nên StreamingEnabled
	-- dỡ nó ngay khi người chơi vào stage. Không cache thì respawn tại checkpoint xa lobby
	-- là mất sạch trail premium cho tới lúc quay về.
	local spec = premiumTrailCache[trailId]
	if not spec then
		local source = findPremiumTrailSource(trailId)
		if source then
			spec = buildPremiumTrailSpec(source)
			premiumTrailCache[trailId] = spec
		end
	end

	if spec then
		local gateItems: { Instance } = {}

		for i, ribbon in spec.ribbons do
			-- ribbon xếp lớp: lệch nhẹ theo Z để không z-fight khi cùng texture
			local z = 0.18 - 0.03 * (i - 1)

			local a = Instance.new("Attachment")
			a.Name = TRAIL_ATTACH_A
			a.Position = Vector3.new(0, ribbon.y0, z)
			a.Parent = root

			local b = Instance.new("Attachment")
			b.Name = TRAIL_ATTACH_B
			b.Position = Vector3.new(0, ribbon.y1, z)
			b.Parent = root

			local trail = ribbon.proto:Clone()
			trail.Attachment0 = a
			trail.Attachment1 = b
			trail.Parent = root
			table.insert(gateItems, trail)
		end

		for _, proto in spec.fx do
			local clone = proto:Clone()
			clone.Parent = root
			if clone:IsA("ParticleEmitter") then
				table.insert(gateItems, clone)
			else
				for _, desc in clone:GetDescendants() do
					if desc:IsA("ParticleEmitter") then
						table.insert(gateItems, desc)
					end
				end
			end
		end

		syncTrailLifetime(player)

		-- Bắt đầu ở trạng thái ẨN: người chơi vừa spawn/vừa mua thường đang đứng yên.
		local entry: TrailGate = { root = root, items = gateItems, visible = true }
		trailGate[player] = entry
		setGateVisible(entry, false)
		return
	end

	local visual = TRAIL_VISUALS[trailId]
	if not visual then
		return
	end

	local attachA = Instance.new("Attachment")
	attachA.Name = TRAIL_ATTACH_A
	attachA.Position = Vector3.new(0, 1.6, 0.18)
	attachA.Parent = root

	local attachB = Instance.new("Attachment")
	attachB.Name = TRAIL_ATTACH_B
	attachB.Position = Vector3.new(0, -1.7, 0.18)
	attachB.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = TRAIL_OBJECT
	trail.Attachment0 = attachA
	trail.Attachment1 = attachB
	trail.Color = visual.color
	trail.FaceCamera = true
	trail.Lifetime = visual.lifetime
	trail.LightEmission = visual.lightEmission
	trail.LightInfluence = 0
	trail.MinLength = 0.08
	trail.Texture = visual.texture
	trail.TextureLength = visual.textureLength
	trail.TextureMode = Enum.TextureMode.Wrap
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.72, 0.22),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, visual.widthScale),
		NumberSequenceKeypoint.new(0.65, visual.widthScale * 0.72),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = root
end

-- ── Aura ─────────────────────────────────────────────────────────────────

-- ── Standard Auras (dựng từ template AuraBasic + recolor) ────────────────────
-- Template = rig `StandardAuras` user dựng trong Studio, đã copy vào
-- ReplicatedStorage.CosmeticTemplates.AuraBasic (8 Beam + 13 ParticleEmitter + PointLight +
-- model "Full body aura"). MỌI aura standard dùng CHUNG bộ VFX này, chỉ khác tông màu.
type AuraColorConfig = {
	primary: Color3,
	secondary: Color3,
	light: Color3,
}

-- Tông màu phải ĐÚNG TÊN aura trong `Config/Economy/Auras.luau` — người chơi mua "Red Aura"
-- thì không được thấy vệt cam, mua "Blue Aura" không được thấy tím.
-- ⚠️ HAI KÊNH MÀU PHỤ PHẢI GẦN 0.
-- Rig chồng ~5 lớp additive quanh thân: mỗi kênh cộng dồn rồi bão hoà ở 1.0. Nếu Red Aura
-- để (191,23,21) thì kênh R bão hoà TRƯỚC, còn G/B cộng 5 lớp × 0.09 ≈ 0.45 ⇒ lõi ngả trắng
-- hồng, chỉ rìa mới đỏ (đúng cái ảnh user gửi). Chọn tông gần như bão hoà một kênh
-- (G/B ≤ 20) thì dù chồng bao nhiêu lớp, lõi vẫn giữ đúng sắc.
local STANDARD_AURA_COLORS: { [string]: AuraColorConfig } = {
	aura_sparkle = { -- Blue Aura
		primary = Color3.fromRGB(0, 8, 120),
		secondary = Color3.fromRGB(15, 85, 255),
		light = Color3.fromRGB(0, 110, 255),
	},
	aura_fire = { -- Red Aura — đỏ thuần, KHÔNG ngả cam (cam là Flame Aura premium)
		primary = Color3.fromRGB(120, 0, 0),
		secondary = Color3.fromRGB(255, 20, 8),
		light = Color3.fromRGB(255, 45, 35),
	},
	aura_lightning = { -- Cyan Aura
		primary = Color3.fromRGB(0, 80, 100),
		secondary = Color3.fromRGB(0, 215, 255),
		light = Color3.fromRGB(60, 220, 255),
	},
	aura_void = { -- Purple Aura
		primary = Color3.fromRGB(45, 0, 110),
		secondary = Color3.fromRGB(135, 15, 255),
		light = Color3.fromRGB(180, 60, 255),
	},
	aura_cosmic = { -- Pink Aura
		primary = Color3.fromRGB(130, 0, 62),
		secondary = Color3.fromRGB(255, 15, 145),
		light = Color3.fromRGB(255, 20, 180),
	},
	aura_frozen_bloom = { -- Frozen Bloom (băng giá)
		primary = Color3.fromRGB(0, 95, 115),
		secondary = Color3.fromRGB(60, 245, 240),
		light = Color3.fromRGB(100, 255, 230),
	},
}

--[[
	Aura có RIG VFX RIÊNG → tên model trong `ReplicatedStorage.CosmeticTemplates`.

	Những aura này KHÔNG đi qua template chung `AuraBasic.Torso` và KHÔNG được nhuộm màu:
	toàn bộ hiệu ứng nằm sẵn trong rig. `STANDARD_AURA_COLORS` cố tình không có mục cho
	chúng — có mục là mở đường cho cái bẫy fallback mô tả ở nhánh dùng bảng này.

	Thêm aura rig mới thì thêm ĐÚNG một dòng ở đây; đừng chép lại cả nhánh.
]]
local RIG_AURAS: { [string]: string } = {
	aura_frozen_bloom = "Aura_FrozenBloom",
	aura_glitch = "Aura_FrozenBloom",
	-- VIP Gold Aura (độc quyền VIP Membership): lửa vàng–cam, rig 15 part khớp tên bộ phận R15.
	aura_vip = "Aura_Vip",
}

-- ĐỔI MÀU GIỮ CHIỀU SÂU (2026-07-29).
-- Rig gốc (StandardAuras) là aura XANH DƯƠNG, và bên trong nó các lớp có độ sáng khác nhau
-- (beam nền tối 0,38,85 · lõi sáng 0,123,255 · beam nhấn 0,255,111). Nếu ép TẤT CẢ về một
-- ColorSequence primary→secondary thì aura mất hết lớp, trông như một khối màu bẹt.
-- Cách làm ở đây: lấy ĐỘ SÁNG của màu gốc làm hệ số nội suy primary→secondary — lớp nào
-- gốc tối vẫn tối, lớp nào gốc sáng vẫn sáng, chỉ TÔNG MÀU đổi theo đúng tên aura.
-- ⚠️ TUYỆT ĐỐI KHÔNG hạ `LightEmission` của rig này (đã thử 0.5, hỏng).
-- Cả 21 lớp (8 Beam + 13 emitter) dùng texture nền ĐEN và trông đúng nhờ blend cộng
-- (LightEmission = 1) triệt tiêu nền. Hạ xuống 0.5 là nền đen hiện thành các tấm chữ nhật
-- tối lởm chởm quanh người chơi. Muốn màu đọc ra đúng tên thì phải chỉnh Ở PHÍA MÀU:
-- xem chú thích của STANDARD_AURA_COLORS.
local function tintColor(source: Color3, config: AuraColorConfig): Color3
	local luminance = 0.299 * source.R + 0.587 * source.G + 0.114 * source.B
	return config.primary:Lerp(config.secondary, math.clamp(luminance, 0, 1))
end

local function tintSequence(source: ColorSequence, config: AuraColorConfig): ColorSequence
	local keypoints: { ColorSequenceKeypoint } = {}
	for _, keypoint in source.Keypoints do
		table.insert(keypoints, ColorSequenceKeypoint.new(keypoint.Time, tintColor(keypoint.Value, config)))
	end
	return ColorSequence.new(keypoints)
end

-- Torso mang VFX của rig aura standard. Ưu tiên kho ReplicatedStorage; fallback về Workspace
-- (tên "AuraBasic" cũ, hoặc model "StandardAuras" user dựng tay — chấp nhận cả tên có
-- khoảng trắng thừa vì model trong place đang tên `"StandardAuras "`).
local function getStandardAuraTemplate(): BasePart?
	local template = getTemplate("AuraBasic", "Torso")
	if template and template:IsA("BasePart") then
		return template
	end

	for _, child in workspace:GetChildren() do
		local name = child.Name:lower():gsub("%s", "")
		if name == "aurabasic" or name == "standardauras" then
			local torso = child:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				return torso
			end
		end
	end
	return nil
end

local function clearAura(player: Player)
	local character = player.Character
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if descendant.Name == AURA_OBJECT then
			descendant:Destroy()
		end
	end
end

local function applyAura(player: Player)
	local root = getRoot(player)
	if not root then
		return
	end

	local auraId = player:GetAttribute("EquippedAura")
	clearAura(player)
	if typeof(auraId) ~= "string" or auraId == "none" or not shouldRender(player) then
		return
	end

	--[[
		0. Aura có rig VFX RIÊNG (`RIG_AURAS`: Frozen Bloom, VIP Gold) — KHÔNG đi qua template chung.

		⚠️ LỖI ĐÃ SỬA 2026-08-08 (user báo "Frozen Bloom bị sao aura"): rig này trước nằm ở
		`Workspace.Aura_FrozenBloom` — sai chỗ theo đúng hai cách cùng lúc:
		  • 16 part đều KHÔNG neo và chỉ có 2 joint ⇒ vào game là rig rã ra rơi tự do, kéo
		    theo mọi ParticleEmitter gắn trên nó.
		  • `ModelStreamingMode = Default` + StreamingEnabled, mà nó đứng cách Spawn 125
		    studs ⇒ client ở xa không nhìn thấy model, `FindFirstChild` trả nil.
		Cả hai đường đều dẫn tới việc rơi xuống nhánh 2 phía dưới, tức aura standard nhuộm
		tông cyan của `STANDARD_AURA_COLORS.aura_frozen_bloom` — đúng cái quầng trắng-xanh
		khổng lồ trùm kín nhân vật trong ảnh user gửi, chẳng liên quan gì tới hoa băng.

		Giờ rig nằm trong `ReplicatedStorage.CosmeticTemplates` (đã neo part): luôn có mặt
		trên mọi client, không bị streaming dỡ, không bị physics đụng tới.

		Và khi aura ĐÃ nằm trong `RIG_AURAS` thì `return` LUÔN dù tìm thấy rig hay không —
		thà không có aura còn hơn hiện nhầm sang aura của món khác. Luật này áp cho MỌI rig
		trong bảng, không riêng Frozen Bloom.
	]]
	local rigName = RIG_AURAS[auraId]
	if rigName then
		local rigModel = getRootTemplate(rigName) or workspace:FindFirstChild(rigName, true)
		if rigModel and rigModel:IsA("Model") then
			local character = player.Character
			if character then
				for _, partInModel in rigModel:GetChildren() do
					if partInModel:IsA("BasePart") then
						local targetPart = character:FindFirstChild(partInModel.Name)
							or (if string.find(partInModel.Name, "Torso")
								then (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
								else nil)
							or character:FindFirstChild("HumanoidRootPart")

						if targetPart and targetPart:IsA("BasePart") then
							for _, child in partInModel:GetChildren() do
								if
									child:IsA("ParticleEmitter")
									or child:IsA("PointLight")
									or child:IsA("Highlight")
									or child:IsA("Attachment")
									or child:IsA("Beam")
									or child:IsA("Trail")
								then
									local clone = child:Clone()
									clone.Name = AURA_OBJECT
									if clone:IsA("ParticleEmitter") then
										clone.Enabled = true
									end
									clone.Parent = targetPart
								end
							end
						end
					end
				end
			end
		else
			warn(`[CosmeticVisual] Không tìm thấy rig {rigName} (ReplicatedStorage.CosmeticTemplates)`)
		end
		return
	end

	-- 1. Ưu tiên: Premium Auras có folder riêng trong Workspace.AuraBase (Dark, Flame, RedHeart)
	local auraBase = workspace:FindFirstChild("AuraBase", true)
	local auraFolder = auraBase and auraBase:FindFirstChild(auraId)

	if auraFolder and auraFolder:IsA("Folder") then
		local rigTemplate = auraFolder:FindFirstChild("Rig")
		if rigTemplate and rigTemplate:IsA("Model") then
			local character = player.Character
			if character then
				local function getAncestorBodyPart(inst: Instance): BasePart?
					local curr: Instance? = inst.Parent
					while curr and curr ~= rigTemplate do
						if curr:IsA("BasePart") and curr.Parent == rigTemplate then
							return curr :: BasePart
						end
						curr = curr.Parent
					end
					return nil
				end

				for _, child in rigTemplate:GetDescendants() do
					if
						child:IsA("ParticleEmitter")
						or child:IsA("PointLight")
						or child:IsA("Highlight")
						or child:IsA("Attachment")
						or child:IsA("Beam")
						or child:IsA("Trail")
					then
						local bodyPart = getAncestorBodyPart(child)
							or (if child.Parent and child.Parent:IsA("BasePart") then child.Parent :: BasePart else nil)
						if bodyPart then
							local targetPart = character:FindFirstChild(bodyPart.Name)
								or character:FindFirstChild("HumanoidRootPart")
							if targetPart and targetPart:IsA("BasePart") then
								local clone = child:Clone()
								clone.Name = AURA_OBJECT
								if clone:IsA("ParticleEmitter") then
									clone.Enabled = true
								end
								clone.Parent = targetPart
							end
						end
					end
				end
			end
			return
		end
	end

	-- 2. Standard Auras: dựng NGUYÊN rig VFX từ template + đổi tông màu theo tên aura.
	local colorConfig = STANDARD_AURA_COLORS[auraId]
	local templateTorso = getStandardAuraTemplate()
	if templateTorso and colorConfig then
		local character = player.Character
		local torso = character
			and (
				character:FindFirstChild("Torso")
				or character:FindFirstChild("UpperTorso")
				or character:FindFirstChild("HumanoidRootPart")
			)
		if torso and torso:IsA("BasePart") then
			-- ⚠️ CLONE CẢ TORSO rồi mới tách con ra — KHÔNG clone từng con một.
			-- 8 Beam nằm trong Attachment "B" nhưng `Attachment1` của chúng trỏ sang Attachment
			-- "T" (anh em cùng cấp). Clone riêng "B" thì Roblox không rewire được tham chiếu
			-- ngoài subtree ⇒ beam vẫn dính vào template, kéo một dải sáng từ người chơi về
			-- tận chỗ để template. Clone cả Torso thì B và T nằm chung một lần clone nên
			-- tham chiếu được nối lại đúng; sau đó REPARENT (không clone lại) nên vẫn giữ nguyên.
			local holder = templateTorso:Clone()
			local holderCF = holder.CFrame

			-- Ghi lại offset so với torso template TRƯỚC khi dời (dời xong CFrame sẽ đổi).
			local offsets: { [BasePart]: CFrame } = {}
			for _, desc in holder:GetDescendants() do
				if desc:IsA("BasePart") then
					offsets[desc] = holderCF:ToObjectSpace(desc.CFrame)
				elseif desc:IsA("ParticleEmitter") then
					desc.Color = tintSequence(desc.Color, colorConfig)
					desc.Enabled = true
				elseif desc:IsA("Beam") then
					desc.Color = tintSequence(desc.Color, colorConfig)
				elseif desc:IsA("PointLight") or desc:IsA("SurfaceLight") or desc:IsA("SpotLight") then
					desc.Color = colorConfig.light
				end
			end

			for _, child in holder:GetChildren() do
				if child:IsA("Attachment") or child:IsA("Model") or child:IsA("BasePart") then
					child.Name = AURA_OBJECT
					child.Parent = torso
				end
			end
			holder:Destroy()

			-- Part vật lý bên trong "Full body aura": đặt đúng chỗ rồi hàn vào torso.
			-- ⚠️ DÙNG `Weld` CŨ, KHÔNG DÙNG `WeldConstraint` (2026-07-29, user báo "3 chấm
			-- xanh nối liền" hiện trên ngực khi trang bị aura). `WeldConstraint` là Constraint
			-- nên Studio VẼ GIZMO cho nó khi bật "Constraint Details": mỗi weld là 2 chấm +
			-- 1 đoạn nối, 2 weld chung điểm torso ⇒ đúng 3 chấm nối liền. `Weld` là
			-- JointInstance nên không bao giờ bị vẽ. Hai loại giữ part y hệt nhau:
			-- part.CFrame = Part0.CFrame * C0 * C1⁻¹ = torso.CFrame * offset.
			for part, offset in offsets do
				if part.Parent then
					part.Anchored = false
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.CastShadow = false
					part.Massless = true
					part.Transparency = 1
					part.CFrame = torso.CFrame * offset

					local weld = Instance.new("Weld")
					weld.Name = AURA_OBJECT
					weld.Part0 = torso
					weld.Part1 = part
					weld.C0 = offset
					weld.C1 = CFrame.identity
					weld.Parent = part
				end
			end
			return
		end
	end

	local visual = AURA_VISUALS[auraId]
	if not visual then
		return
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = AURA_OBJECT
	emitter.Color = visual.color
	emitter.Texture = visual.texture
	emitter.Rate = visual.rate
	emitter.Size = visual.size
	emitter.Speed = visual.speed
	emitter.Lifetime = visual.lifetime
	emitter.LightEmission = visual.lightEmission
	emitter.LightInfluence = 0
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = root
end

-- ── Wiring ───────────────────────────────────────────────────────────────

local function setupCharacter(player: Player, character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not root or not humanoid then
			return
		end

		-- 1. Chờ character hoàn toàn nằm trong workspace
		while character.Parent ~= workspace and character.Parent ~= nil do
			task.wait(0.05)
		end
		if not character:IsDescendantOf(workspace) then
			return
		end

		-- 2. Đợi Roblox Server hoàn tất việc teleport nhân vật đến điểm Spawn/Checkpoint
		task.wait(0.15)

		-- 3. Tiến hành gắn Trail & Aura
		if player.Parent == Players and player.Character == character and humanoid.Health > 0 then
			applyTrail(player)
			applyAura(player)
			invalidateLod(player)
		end

		-- 4. Double check kiểm tra phụ sau 0.5s để chống mất Trail/Aura khi vừa hồi sinh
		task.wait(0.5)
		if player.Parent == Players and player.Character == character and humanoid.Health > 0 then
			local currentRoot = getRoot(player)
			if currentRoot then
				local hasTrail = currentRoot:FindFirstChild(TRAIL_ATTACH_A) ~= nil
					or currentRoot:FindFirstChild(TRAIL_OBJECT) ~= nil
				local trailId = player:GetAttribute("EquippedTrail")
				if typeof(trailId) == "string" and trailId ~= "none" and not hasTrail then
					applyTrail(player)
				end

				local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or currentRoot
				local hasAura = currentRoot:FindFirstChild(AURA_OBJECT) ~= nil
					or (torso and torso:FindFirstChild(AURA_OBJECT) ~= nil)
				local auraId = player:GetAttribute("EquippedAura")
				if typeof(auraId) == "string" and auraId ~= "none" and not hasAura then
					applyAura(player)
				end
				invalidateLod(player)
			end
		end
	end)
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal("EquippedTrail"):Connect(function()
		applyTrail(player)
		invalidateLod(player)
	end)
	player:GetAttributeChangedSignal("EquippedAura"):Connect(function()
		applyAura(player)
		invalidateLod(player)
	end)

	-- Vệt phải giữ chiều dài cố định khi WalkSpeed đổi (lên level / rebirth / Custom Speed).
	-- Bám sự kiện thay vì đo mỗi frame: WalkSpeed hiếm khi đổi ⇒ 0 chi phí thường trực.
	local function bindWalkSpeed(character: Model)
		task.spawn(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
			if player.Parent == Players and player.Character == character and humanoid and humanoid:IsA("Humanoid") then
				humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
					syncTrailLifetime(player)
				end)
				syncTrailLifetime(player)
			end
		end)
	end

	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
		bindWalkSpeed(character)
	end)

	if player.Character then
		setupCharacter(player, player.Character)
		bindWalkSpeed(player.Character)
	end
end

-- Gọi từ bảng Cài đặt. Dựng lại NGAY cho mọi người chơi khác thay vì chờ respawn.
function CosmeticVisualController.SetOthersEnabled(enabled: boolean)
	if othersEnabled == enabled then
		return
	end
	othersEnabled = enabled
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer then
			applyTrail(player)
			applyAura(player)
			invalidateLod(player)
		end
	end
end

function CosmeticVisualController.IsOthersEnabled(): boolean
	return othersEnabled
end

function CosmeticVisualController.Start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	Players.PlayerRemoving:Connect(function(player)
		trailGate[player] = nil
		lodEntries[player] = nil
	end)

	-- Cổng ẩn/hiện trail premium theo tốc độ. Chỉ chạy 10 Hz và chỉ duyệt những người ĐANG
	-- đeo trail premium (bảng `trailGate`) nên gần như miễn phí kể cả server 25 người.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < GATE_INTERVAL then
			return
		end
		accumulator = 0

		for player, entry in trailGate do
			if not entry.root.Parent or player.Character ~= entry.root.Parent then
				trailGate[player] = nil
				continue
			end

			local velocity = entry.root.AssemblyLinearVelocity
			-- Bỏ thành phần Y: rơi tự do không phải "đang chạy", và người đứng trên bệ đỡ
			-- chuyển động vẫn nên coi là đứng yên.
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

			if entry.visible and speed < GATE_HIDE_SPEED then
				setGateVisible(entry, false)
			elseif not entry.visible and speed >= GATE_SHOW_SPEED then
				setGateVisible(entry, true)
			end
		end

		-- Cùng nhịp 10 Hz: hạ bậc hiệu ứng của người chơi ở xa / ngoài tầm nhìn.
		stepCosmeticLod()
	end)
end

return CosmeticVisualController
