--!strict
--[[
	LightingService.luau — Lighting phong cách Roblox Simulator hiện đại rực rỡ.

	Tiêu chí:
	  - Nắng chiều ấm (ClockTime ~14.3, góc 2h chiều) → bóng đổ chéo mượt.
	  - Bóng khuất KHÔNG đen xì: ambient xám-xanh pastel sáng, nhìn rõ chi tiết.
	  - Màu bão hòa rực rỡ: ColorCorrection saturation cao đúng chất Simulator.
	  - Neon/Trail/Aura tỏa quầng sáng: Bloom threshold cao (chỉ vật phát sáng mới glow).
	  - Chiều sâu bầu trời: Atmosphere sương xanh pastel + SunRays tia nắng xé không trung.
	  - GIỮ NGUYÊN Sky hiện có (decal skybox không bị đụng tới).

	Lưu ý: Lighting.Technology KHÔNG set được từ script lúc runtime — muốn neon glow
	đẹp nhất hãy chỉnh tay trong Studio: Lighting.Technology = Future (ShadowMap cũng ổn).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Lighting = game:GetService("Lighting")

local LightingService = {}

-- Tìm effect sẵn có theo class (bất kể tên) để chỉnh, chưa có thì tạo — idempotent,
-- chạy lại không nhân đôi effect.
local function ensureEffect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		existing.Name = name
		return existing
	end
	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

function LightingService.Start()
	-- ===== Mặt trời chiều 2h + màu nắng ấm =====
	Lighting.ClockTime = 14.3
	Lighting.GeographicLatitude = 30 -- lệch trục để bóng đổ CHÉO thay vì thẳng đứng
	Lighting.Brightness = 2.7
	Lighting.ColorShift_Top = Color3.fromRGB(255, 226, 175) -- nắng vàng ấm phủ mặt hướng nắng
	Lighting.ColorShift_Bottom = Color3.fromRGB(255, 195, 140)
	-- Exposure kéo xuống nhẹ: mức cũ 0.12 cộng dồn với Brightness 2.7 làm bệt màu các mặt
	-- hướng nắng (pastel của map bị rửa trắng — xem ghi chú Modern Retro).
	Lighting.ExposureCompensation = 0.08

	-- ===== Bóng đổ tươi sáng (xám xanh pastel, không đen xì) =====
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.24
	Lighting.Ambient = Color3.fromRGB(98, 108, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 146, 176)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	-- Sương/fog cổ điển nhường chỗ cho Atmosphere (đẩy xa để không chồng hiệu ứng).
	Lighting.FogStart = 0
	Lighting.FogEnd = 100000

	-- ===== Chiều sâu bầu trời: sương mờ dịu xanh pastel (KHÔNG đụng Sky/decal) =====
	local atmosphere = ensureEffect("Atmosphere", "SimAtmosphere") :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 224, 255)
	atmosphere.Decay = Color3.fromRGB(110, 154, 212)
	atmosphere.Glare = 0.18
	atmosphere.Haze = 1.7

	-- ===== Glow neon: threshold cao → CHỈ Neon/Trail/Aura bừng quầng sáng =====
	local bloom = ensureEffect("BloomEffect", "SimBloom") :: BloomEffect
	bloom.Enabled = true
	bloom.Intensity = 0.95
	bloom.Size = 26
	bloom.Threshold = 1.75

	-- ===== Màu bão hòa rực rỡ chất Simulator =====
	local colorCorrection = ensureEffect("ColorCorrectionEffect", "SimColorGrade") :: ColorCorrectionEffect
	colorCorrection.Enabled = true
	colorCorrection.Saturation = 0.24
	colorCorrection.Contrast = 0.1
	colorCorrection.Brightness = 0.015
	colorCorrection.TintColor = Color3.fromRGB(255, 250, 242) -- ám ấm rất nhẹ toàn khung hình

	-- ===== Tia nắng xé không trung (nhìn lên các Stage trên cao) =====
	local sunRays = ensureEffect("SunRaysEffect", "SimSunRays") :: SunRaysEffect
	sunRays.Enabled = true
	sunRays.Intensity = 0.19
	sunRays.Spread = 0.7

	Log.Boot("[LightingService] Simulator lighting đã áp dụng (sky decal giữ nguyên).")
end

return LightingService
