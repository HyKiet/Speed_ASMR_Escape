--!strict
--[[
	ClientSettingsController.luau — Hai chế độ hiển thị bật/tắt từ nút Cài đặt trên topbar.

	  • Performance Mode — dồn hết những thứ ngốn GPU nhất của game này xuống mức tối thiểu.
	  • Night Mode      — chuyển cảnh sang ban đêm.

	MỌI thay đổi đều CLIENT-ONLY (Lighting/Terrain đổi trên client không replicate) và đều
	lưu lại giá trị cũ để trả về nguyên trạng khi tắt — không bao giờ ghi đè vĩnh viễn thiết
	lập của `LightingService`.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CosmeticVisualController = require(script.Parent.CosmeticVisualController)

local ClientSettingsController = {}

local performanceOn = false
local nightOn = false

-- ── Kho giá trị gốc ──────────────────────────────────────────────────────────
-- Ghi lại LẦN ĐẦU bật; các lần sau dùng lại bản gốc đó. Không snapshot lại khi đang bật,
-- nếu không bật Performance rồi bật Night sẽ "đóng băng" trạng thái đã bị sửa thành gốc.
local savedPerformance: { [string]: any } = {}
local savedNight: { [string]: any } = {}
local savedEffects: { [PostEffect]: boolean } = {}

local function terrain(): Terrain?
	local t = Workspace:FindFirstChildOfClass("Terrain")
	return t
end

-- ── Performance Mode ─────────────────────────────────────────────────────────

local function applyPerformance(on: boolean)
	-- 1. Hiệu ứng cosmetic của NGƯỜI KHÁC (trail premium toả tới 15 emitter/người —
	--    nguồn ngốn fill-rate lớn nhất khi đông người).
	CosmeticVisualController.SetOthersEnabled(not on)

	-- 2. Post-processing: Bloom/SunRays/DepthOfField/Blur đều là full-screen pass.
	if on then
		table.clear(savedEffects)
		for _, child in Lighting:GetDescendants() do
			if child:IsA("PostEffect") then
				savedEffects[child] = child.Enabled
				child.Enabled = false
			end
		end
	else
		for effect, wasEnabled in savedEffects do
			if effect.Parent then
				effect.Enabled = wasEnabled
			end
		end
		table.clear(savedEffects)
	end

	-- 3. Bóng đổ động + chất lượng nước (sóng nước tính mỗi frame trên toàn mặt biển lobby).
	-- ⚠️ `Terrain.Decoration` KHÔNG còn tồn tại trên engine hiện tại (gán vào là lỗi
	-- "not a valid member" và huỷ luôn phần còn lại của hàm — đã dính 2026-07-29).
	-- Chỉ đụng 3 thuộc tính nước chắc chắn có.
	if on then
		if savedPerformance.globalShadows == nil then
			savedPerformance.globalShadows = Lighting.GlobalShadows
			local t = terrain()
			if t then
				savedPerformance.waterWaveSize = t.WaterWaveSize
				savedPerformance.waterWaveSpeed = t.WaterWaveSpeed
				savedPerformance.waterReflectance = t.WaterReflectance
			end
		end
		Lighting.GlobalShadows = false
		local t = terrain()
		if t then
			t.WaterWaveSize = 0
			t.WaterWaveSpeed = 0
			t.WaterReflectance = 0
		end
	elseif savedPerformance.globalShadows ~= nil then
		Lighting.GlobalShadows = savedPerformance.globalShadows
		local t = terrain()
		if t and savedPerformance.waterWaveSize ~= nil then
			t.WaterWaveSize = savedPerformance.waterWaveSize
			t.WaterWaveSpeed = savedPerformance.waterWaveSpeed
			t.WaterReflectance = savedPerformance.waterReflectance
		end
	end

	-- 4. Ánh sáng môi trường (IBL) — tính lại mỗi frame cho từng bề mặt.
	--    ⚠️ ĐÃ THỬ và BỎ: `UserGameSettings.SavedQualityLevel`. Roblox chặn game script ghi
	--    thuộc tính này (đo lại sau khi ghi vẫn là QualityLevel10) — đừng phí công thêm lần nữa.
	if on then
		if savedPerformance.envDiffuse == nil then
			savedPerformance.envDiffuse = Lighting.EnvironmentDiffuseScale
			savedPerformance.envSpecular = Lighting.EnvironmentSpecularScale
		end
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
	elseif savedPerformance.envDiffuse ~= nil then
		Lighting.EnvironmentDiffuseScale = savedPerformance.envDiffuse
		Lighting.EnvironmentSpecularScale = savedPerformance.envSpecular
	end

	-- ⚠️ Chỉ xoá kho SAU KHI mọi khối đã đọc xong. Bản đầu `table.clear` ngay trong khối
	-- nước ⇒ khối ánh sáng phía dưới đọc ra nil và không bao giờ khôi phục được.
	if not on then
		table.clear(savedPerformance)
	end

	-- 5. Nhãn chữ trên bàn phím ASMR — tới 800 SurfaceGui bám theo chân người chơi, thuần
	--    trang trí. Đây là thứ nặng nhất còn lại trên client sau cosmetic.
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local keyboardLabels = playerGui and playerGui:FindFirstChild("KeyboardLabels")
	if keyboardLabels and keyboardLabels:IsA("LayerCollector") then
		keyboardLabels.Enabled = not on
	end

	-- 6. Bóng của chính nhân vật quanh mình (mỗi part một shadow map).
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					part.CastShadow = not on
				end
			end
		end
	end
end

function ClientSettingsController.SetPerformanceMode(enabled: boolean)
	if performanceOn == enabled then
		return
	end
	performanceOn = enabled
	applyPerformance(enabled)
end

function ClientSettingsController.IsPerformanceMode(): boolean
	return performanceOn
end

-- ── Night Mode ───────────────────────────────────────────────────────────────

--[[
	Mục tiêu: **ZONE SÁNG TRƯNG, BẦU TRỜI TỐI** — nhìn rõ mọi mép sàn obby, màu part vẫn rực,
	nhưng ngẩng lên là trời đêm xanh navy đầy sao.

	Cách tách được hai thứ đó (đây là chỗ bản trước làm sai):
	  • `Ambient` / `OutdoorAmbient` chỉ chiếu sáng VẬT THỂ, KHÔNG chạm vào skybox. Đây là cặp
	    nút vặn để "bật đèn" cho cả zone — cứ kéo cao thoải mái, trời không sáng theo.
	  • `ExposureCompensation` và `ColorCorrection.Brightness` thì kéo sáng TOÀN KHUNG HÌNH,
	    kể cả skybox. Bản trước để Exposure = +0.28 nên trời bị xám bợt mà zone vẫn chưa đủ
	    sáng. Giờ ép về 0 và dồn toàn bộ độ sáng sang Ambient.
	  • ⚠️ `ClockTime` PHẢI nằm trong khung BAN NGÀY (đang để 16), KHÔNG phải 0. Engine tự nhân
	    tối SKYBOX theo giờ: mặt trời vừa chạm chân trời (ClockTime 18) là skybox đã bị dìm về
	    gần ĐEN TUYỀN, xuống 0 thì đen hẳn — dù texture, Atmosphere, Exposure có chỉnh kiểu gì
	    cũng không kéo lại được (đã thử hết: Exposure 0.6, bỏ sạch Atmosphere, trời vẫn đen).
	    Vì texture SkyboxUp/Bk/... VỐN ĐÃ là ảnh trời đêm, ta không cần engine dìm thêm lần
	    nữa — cứ để giờ ban ngày cho skybox hiện đủ màu, còn "chất đêm" đến từ texture +
	    Ambient ám lam + ColorCorrection.
	  • Đi kèm bắt buộc: `CelestialBodiesShown = false`. Giờ ban ngày nghĩa là MẶT TRỜI đang
	    trên trời — không tắt đĩa sáng đi thì có một mặt trời chình ình giữa bầu trời đêm.
	    Tắt nó rồi thì nguồn sáng vẫn còn (ánh sáng không phụ thuộc thuộc tính này), chỉ là
	    không ai thấy cái đĩa.
	  • Bloom mạnh + threshold thấp: ban đêm mới là lúc trail/aura/neon toả đẹp nhất — đây
	    chính là phần "xịn" mà người chơi bật Night Mode để xem.

	⚠️ KHÔNG đụng `SpeedBlur` (BlurEffect có sẵn trong Lighting). Nó đang Size = 0 và chưa có
	   code nào điều khiển, nhưng đó là chỗ dành cho hiệu ứng tốc độ sau này. Blur của Night
	   Mode đi qua `DepthOfFieldEffect` (mờ theo khoảng cách) chứ KHÔNG phải BlurEffect —
	   xem `NIGHT_DEPTH_OF_FIELD`.
]]
local NIGHT_LIGHTING = {
	-- 16 = mặt trời cao ~30° trên chân trời: skybox hiện đủ màu, bóng đổ chéo đẹp. Xem lời
	-- giải thích dài ở đầu khối — ĐỪNG hạ về 0/20/22, trời sẽ đen tuyền.
	ClockTime = 16,
	Brightness = 2.2,
	-- Cặp "công tắc đèn" của cả zone. Cao gần bằng ban ngày nhưng ám xanh lam để mắt vẫn
	-- đọc ra là ban đêm — trời KHÔNG sáng theo hai giá trị này.
	Ambient = Color3.fromRGB(148, 158, 190),
	OutdoorAmbient = Color3.fromRGB(172, 184, 214),
	ColorShift_Top = Color3.fromRGB(176, 200, 245),
	ColorShift_Bottom = Color3.fromRGB(96, 112, 158),
	FogColor = Color3.fromRGB(18, 26, 54),
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	-- ⚠️ PHẢI là 0. Đây là thứ duy nhất kéo sáng được skybox — nhích lên là mất bầu trời đêm.
	ExposureCompensation = 0,
	ShadowSoftness = 0.6,
}

-- Sương đêm mỏng: đủ để núi xa thành bóng đổ có chiều sâu, KHÔNG đủ để phủ mờ zone. Density
-- cao (bản trước 0.34 + Haze 1.15) làm cả cảnh xám bợt như sương mù, mất hết màu part.
local NIGHT_ATMOSPHERE = {
	Density = 0.15,
	Offset = 0.1,
	Color = Color3.fromRGB(70, 90, 140),
	Decay = Color3.fromRGB(30, 45, 90),
	Glare = 0,
	Haze = 0.4,
}

local NIGHT_BLOOM = {
	Intensity = 1.3,
	Size = 30,
	Threshold = 1.05,
}

-- `Brightness` PHẢI là 0 (cùng lý do với ExposureCompensation: nó kéo sáng cả skybox).
-- Saturation kéo cao để part giữ được màu rực như ban ngày dù đang đêm.
local NIGHT_COLOR_CORRECTION = {
	Saturation = 0.28,
	Contrast = 0.12,
	Brightness = 0,
	TintColor = Color3.fromRGB(214, 226, 255),
}

-- Tia sáng giờ phát ra từ mặt trăng, phải rất mảnh — để nguyên mức ban ngày trông như
-- mặt trời chưa lặn.
local NIGHT_SUN_RAYS = {
	Intensity = 0.06,
	Spread = 0.9,
}

--[[
	Skybox đêm — chép nguyên từ Sky 'NIGHT' mà project đã dựng sẵn trong Lighting (Sky đó đã
	bị xoá sau khi lấy số, vì Lighting chỉ dùng ĐƯỢC MỘT Sky: để 2 Sky cạnh nhau thì cái thứ
	hai không bao giờ hiện, đó là lý do skybox đêm trước giờ "không ăn").

	⚠️⚠️ PHẢI giữ nguyên format `http://www.roblox.com/Asset/?ID=` — ĐỪNG "hiện đại hoá" thành
	`rbxassetid://`. Sáu ID này là asset **Decal** đời 2009; URL kiểu cũ tự phân giải Decal ra
	ảnh bên trong, còn `rbxassetid://` thì KHÔNG: texture hỏng và bầu trời render ĐEN TUYỀN.
	Không có lấy một dòng lỗi nào trong Output — triệu chứng duy nhất là trời đen thui. Đã
	dính đúng bẫy này ngày 2026-07-30.

	Trời đen còn kéo theo hệ quả thứ hai ít ai ngờ: `EnvironmentDiffuseScale` lấy ánh sáng môi
	trường TỪ CHÍNH SKYBOX, nên skybox hỏng = mất luôn nguồn sáng đó, cả zone tối đi dù
	`Ambient`/`OutdoorAmbient` đã kéo rất cao. Sửa texture là sáng lại theo.

	`CelestialBodiesShown = false` là BẮT BUỘC vì `ClockTime` để ở khung ban ngày (xem khối
	trên) — bật lên là có mặt trời giữa trời đêm. `StarCount` vẫn cho sao thủ tục lấp lánh.
]]
local NIGHT_SKY = {
	SkyboxBk = "http://www.roblox.com/Asset/?ID=12064107",
	SkyboxDn = "http://www.roblox.com/Asset/?ID=12064152",
	SkyboxFt = "http://www.roblox.com/Asset/?ID=12064121",
	SkyboxLf = "http://www.roblox.com/Asset/?ID=12063984",
	SkyboxRt = "http://www.roblox.com/Asset/?ID=12064115",
	SkyboxUp = "http://www.roblox.com/Asset/?ID=12064131",
	StarCount = 3000,
	CelestialBodiesShown = false,
}

--[[
	Blur đêm — dùng ĐÚNG loại blur mà ban ngày đang dùng: `DepthOfFieldEffect`, chỉ mờ VẬT Ở XA
	còn cảnh gần vẫn sắc nét.

	Bản trước dựng một `BlurEffect` tên NightBlur: cái đó làm mờ TOÀN BỘ khung hình đều nhau,
	nên ban đêm nhìn nhoè hẳn so với ban ngày — sai chất. Đã gỡ hoàn toàn.

	Giữ nguyên `NearIntensity = 0` (không mờ vật ở gần) và chỉ nhích `FarIntensity` lên một
	chút so với ban ngày (0.3 → 0.45) để đêm có chiều sâu dày hơn tí, còn cảm giác thì y hệt.
]]
local NIGHT_DEPTH_OF_FIELD = {
	FarIntensity = 0.45,
	FocusDistance = 100,
	InFocusRadius = 70,
	NearIntensity = 0,
}

-- Ghi preset lên instance và cất giá trị cũ vào `savedNight[key]`. Instance không tồn tại
-- (map chưa có Sky/SunRays) thì bỏ qua im lặng — không phải lỗi.
local function applyNightPreset(key: string, instance: Instance?, preset: { [string]: any })
	if not instance then
		return
	end
	local previous: { [string]: any } = {}
	for property in preset do
		previous[property] = (instance :: any)[property]
	end
	for property, value in preset do
		(instance :: any)[property] = value
	end
	savedNight[key] = { instance = instance, values = previous }
end

local function restoreNightPresets()
	for _, entry in savedNight do
		local instance = entry.instance
		-- Instance có thể đã bị gỡ khỏi Lighting trong lúc Night Mode đang bật.
		if instance and instance.Parent then
			for property, value in entry.values do
				(instance :: any)[property] = value
			end
		end
	end
	table.clear(savedNight)
end

function ClientSettingsController.SetNightMode(enabled: boolean)
	if nightOn == enabled then
		return
	end
	nightOn = enabled

	if enabled then
		applyNightPreset("lighting", Lighting, NIGHT_LIGHTING)
		-- Atmosphere phủ lên trên mọi thứ; không tối nó theo thì trời vẫn trắng đục.
		applyNightPreset("atmosphere", Lighting:FindFirstChildOfClass("Atmosphere"), NIGHT_ATMOSPHERE)
		applyNightPreset("bloom", Lighting:FindFirstChildOfClass("BloomEffect"), NIGHT_BLOOM)
		applyNightPreset(
			"colorCorrection",
			Lighting:FindFirstChildOfClass("ColorCorrectionEffect"),
			NIGHT_COLOR_CORRECTION
		)
		applyNightPreset("sunRays", Lighting:FindFirstChildOfClass("SunRaysEffect"), NIGHT_SUN_RAYS)
		-- Áp cho MỌI Sky, không phải `FindFirstChildOfClass`. Lighting chỉ RENDER được một Sky,
		-- nhưng khi có nhiều hơn một thì cái được render và cái `FindFirstChildOfClass` trả về
		-- có thể là hai cái khác nhau (Edit trả Stylized, runtime trả NIGHT — đã dính đúng bẫy
		-- này). Quét hết thì đúng dù project lỡ để sót Sky thứ hai.
		local skyIndex = 0
		for _, child in Lighting:GetChildren() do
			if child:IsA("Sky") then
				skyIndex += 1
				applyNightPreset(`sky{skyIndex}`, child, NIGHT_SKY)
			end
		end

		-- Dùng lại CHÍNH DepthOfFieldEffect của ban ngày (chỉ đổi thông số rồi trả về), không
		-- dựng effect mới: thêm effect thứ hai là chồng hai lớp mờ lên nhau.
		applyNightPreset("depthOfField", Lighting:FindFirstChildOfClass("DepthOfFieldEffect"), NIGHT_DEPTH_OF_FIELD)
	else
		restoreNightPresets()
	end
end

function ClientSettingsController.IsNightMode(): boolean
	return nightOn
end

function ClientSettingsController.Start()
	-- Nhân vật mới spawn (mình lẫn người khác) phải tuân theo Performance Mode đang bật.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			if not performanceOn then
				return
			end
			task.wait(0.5)
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					part.CastShadow = false
				end
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return ClientSettingsController
