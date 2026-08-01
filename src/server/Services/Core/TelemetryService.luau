--!strict
-- Đo đạc bằng số liệu, thay cho việc ngồi đoán vì sao người chơi rời game.
--
-- Ba thứ được ghi:
--   1. Onboarding funnel — người chơi MỚI đi được tới đâu trong 4 bước đầu.
--      Đây là chỉ số quan trọng nhất của một game simulator: chỗ nào tụt mạnh
--      giữa 2 bước chính là chỗ cần sửa trước tiên.
--   2. Economy — mọi lần Wins vào/ra, kèm lý do. Dùng để biết nguồn Wins nào
--      đang lạm phát và sink nào không ai dùng.
--   3. Lỗi runtime — gom theo script, in định kỳ, không spam từng dòng.
--
-- Tất cả đều bọc pcall và không bao giờ yield trên đường chạy nóng: telemetry
-- hỏng thì im lặng chịu mất số liệu, tuyệt đối không được kéo gameplay chết theo.
--
-- Số liệu xem ở Creator Dashboard → Analytics (funnel hiện sau ~24h có dữ liệu).

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local Env = require(ReplicatedStorage.Shared.Util.Env)

-- 4 bước đầu của người chơi mới. Đổi thứ tự = làm gãy dữ liệu lịch sử, chỉ
-- được THÊM bước vào cuối.
local ONBOARDING_STEPS = {
	Join = { index = 1, name = "Join" },
	FirstSpeed = { index = 2, name = "FirstSpeedGain" },
	FirstStage = { index = 3, name = "FirstStageClear" },
	FirstRebirth = { index = 4, name = "FirstRebirth" },
}

local ERROR_REPORT_INTERVAL = 300

local TelemetryService = {}

-- Bước onboarding đã ghi của từng player trong phiên này (chống ghi trùng).
local loggedSteps: { [Player]: { [string]: boolean } } = {}
local errorCounts: { [string]: number } = {}
local errorTotal = 0

-- ============================================================================
-- API công khai
-- ============================================================================

-- stepKey lấy từ ONBOARDING_STEPS. Gọi bao nhiêu lần cũng được — chỉ lần đầu
-- trong phiên là thật sự gửi đi.
function TelemetryService.Onboarding(player: Player, stepKey: string)
	local step = ONBOARDING_STEPS[stepKey]
	if not step then
		warn(`[Telemetry] Bước onboarding không tồn tại: {stepKey}`)
		return
	end

	local logged = loggedSteps[player]
	if not logged then
		return
	end
	if logged[stepKey] then
		return
	end
	logged[stepKey] = true

	-- Không tự lọc "người chơi mới": funnel onboarding phía Roblox chỉ tính
	-- người vào experience lần đầu, gửi thừa cũng không làm bẩn số liệu.
	task.spawn(function()
		local ok, err = pcall(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step.index, step.name)
		end)
		if not ok and Env.IsStudio() then
			warn(`[Telemetry] Onboarding {stepKey} lỗi: {err}`)
		end
	end)
end

-- flow: "Source" khi Wins chảy VÀO tay người chơi, "Sink" khi chảy ra.
function TelemetryService.Economy(
	player: Player,
	flow: "Source" | "Sink",
	amount: number,
	endingBalance: number,
	reason: string
)
	if amount <= 0 then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			AnalyticsService:LogEconomyEvent(
				player,
				if flow == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
				"Wins",
				amount,
				endingBalance,
				reason
			)
		end)
		if not ok and Env.IsStudio() then
			warn(`[Telemetry] Economy {reason} lỗi: {err}`)
		end
	end)
end

function TelemetryService.Custom(player: Player, eventName: string, value: number?)
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogCustomEvent(player, eventName, value or 1)
		end)
	end)
end

-- ============================================================================

function TelemetryService.Start()
	local function trackPlayer(player: Player)
		loggedSteps[player] = {}
		TelemetryService.Onboarding(player, "Join")
	end

	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
	Players.PlayerAdded:Connect(trackPlayer)
	Players.PlayerRemoving:Connect(function(player)
		loggedSteps[player] = nil
	end)

	-- Gom lỗi runtime theo script thay vì để chúng trôi trong Output. Roblox có
	-- trang Errors riêng, nhưng bản gom này cho biết NGAY trong log server là
	-- script nào đang hỏng liên tục.
	ScriptContext.Error:Connect(function(message: string, _stack: string, script: LuaSourceContainer?)
		local key = if script then script:GetFullName() else "unknown"
		errorCounts[key] = (errorCounts[key] or 0) + 1
		errorTotal += 1

		-- Lần đầu mỗi script thì in ngay, các lần sau chỉ đếm.
		if errorCounts[key] == 1 then
			warn(`[Telemetry] Lỗi đầu tiên ở {key}: {message}`)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(ERROR_REPORT_INTERVAL)
			if errorTotal > 0 then
				local lines = {}
				for key, count in errorCounts do
					table.insert(lines, `  {count}× {key}`)
				end
				table.sort(lines)
				warn(`[Telemetry] {errorTotal} lỗi trong {ERROR_REPORT_INTERVAL}s qua ({Env.Current}):\n{table.concat(lines, "\n")}`)
				errorCounts = {}
				errorTotal = 0
			end
		end
	end)

	print(`[Telemetry] Đang chạy ở môi trường {Env.Current}.`)
end

return TelemetryService
