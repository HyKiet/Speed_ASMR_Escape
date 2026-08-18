--!strict
--[=[

WindShake- High performance wind effect for leaves and foliage
by: boatbomber, CloneTrooper1019

Docs: https://devforum.roblox.com/t/wind-shake-high-performance-wind-effect-for-leaves-and-foliage/1039806/1

--]=]

-- ⚠️ Đã GỠ khối "Demo dynamic settings" của place demo gốc (2026-07-30): nó dựng một
-- ScreenGui debug (nhãn "Leaf Count" + 3 TextBox chỉnh gió) và một `spawn(while wait(0.1))`
-- chạy vĩnh viễn trên MỌI client. ScreenGui đó chưa bao giờ được gán `.Parent` nên người
-- chơi không thấy gì — nhưng vòng lặp thì vẫn quay 10 lần/giây suốt phiên chỉ để ghi chữ
-- vào một nhãn mồ côi. Muốn chỉnh gió thì sửa 3 hằng số dưới đây rồi save.

local WIND_DIRECTION = Vector3.new(1, 0, 0.3)
local WIND_SPEED = 20
local WIND_POWER = 0.5

local WindLines = require(script.WindLines)
local WindShake = require(script.WindShake)

WindLines:Init({
	Direction = WIND_DIRECTION,
	Speed = WIND_SPEED,
	Lifetime = 2,
	SpawnRate = 15,
})

WindShake:SetDefaultSettings({
	WindSpeed = WIND_SPEED,
	WindDirection = WIND_DIRECTION,
	WindPower = WIND_POWER,
})
WindShake:Init()
