--!strict
-- Server nhận mã qua ByteNet, đối chiếu Codes rồi khoá lượt nhận trong dữ liệu DataService.
-- ProgressionService cấp Speed, RouletteService cấp vé; mã quà không cấp Wins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codes = require(ReplicatedStorage.Shared.Config.Economy.Codes)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local NetRateLimit = require(ReplicatedStorage.Shared.Util.NetRateLimit)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local DataService: any = nil
local ProgressionService: any = nil

local CodeService = {}

function CodeService.RedeemCode(player: Player, rawCode: string)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	local cleanCode = string.gsub(rawCode, "%s+", ""):upper()
	if #cleanCode == 0 then
		GamePackets.toast.sendTo({
			kind = "code",
			message = "Please enter a valid code!",
			amount = 0,
		}, player)
		return
	end

	local reward = Codes[cleanCode]
	if not reward then
		GamePackets.toast.sendTo({
			kind = "code",
			message = "Invalid or expired code!",
			amount = 0,
		}, player)
		return
	end

	-- Chống nhập lặp lại mã đã dùng
	data.RedeemedCodes = data.RedeemedCodes or {}
	if data.RedeemedCodes[cleanCode] then
		GamePackets.toast.sendTo({
			kind = "code",
			message = "You have already claimed this code!",
			amount = 0,
		}, player)
		return
	end

	-- Đánh dấu đã nhận
	data.RedeemedCodes[cleanCode] = true

	-- Trao phần thưởng.
	-- ⚠️ KHÔNG có nhánh Wins, và đó là CHỦ Ý (2026-08-23) — xem khối lý do đầu
	-- `Config/Economy/Codes.luau`. Mã quà phát Wins là mở cửa sau cho phép siết bảng daily
	-- xuống 1.177 Wins/tuần ở GDD 8.A1. Muốn thêm lại thì đọc chỗ đó trước.
	if reward.speed and reward.speed > 0 then
		ProgressionService.GrantSpeed(player, reward.speed)
	end

	if reward.spin and reward.spin > 0 then
		local rouletteService = ServiceLocator.Find("RouletteService")
		if rouletteService then
			rouletteService.GrantTickets(player, reward.spin, true)
		end
	end

	-- Thông báo thành công
	GamePackets.toast.sendTo({
		kind = "code",
		message = `Code Redeemed: {reward.description}!`,
		amount = 0,
	}, player)

	print(
		`[CodeService] Player {player.Name} ({player.UserId}) successfully redeemed code "{cleanCode}" ({reward.description})`
	)
end

function CodeService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
end

function CodeService.Start()
	GamePackets.requestRedeemCode.listen(function(packet, player)
		if not player or NetRateLimit.ShouldDrop(player, "redeemCode") then
			return
		end
		CodeService.RedeemCode(player, packet.code)
	end)
end

return CodeService
