--!strict
-- Các hằng số tinh chỉnh nhịp game (rate, interval, ngưỡng).
-- CORE_LOOP_VERSION bump khi đổi công thức quan trọng — DataService sẽ migrate.

local Tuning = {
	CORE_LOOP_VERSION = 2,
	BASE_SPEED_GAIN = 1,
	DEFAULT_WALK_SPEED = 6,
	BASE_MAX_WALK_SPEED = 12,
	WALK_SPEED_PER_LEVEL = 2,
	SPEED_GAIN_INTERVAL = 0.35,
	MIN_MOVEMENT_FOR_SPEED_GAIN = 1.5,
	TREADMILL_GAIN_RADIUS = 5,
	NETWORK_RATE_LIMIT_SECONDS = 0.4,
	XP_CONVERSION_RATE = 1,
}

return Tuning
