--!nocheck
-- BOT PHÁ SERVER — bắn packet rác/bất hợp lệ vào mọi listener ByteNet.
--
-- Cách chạy: Play trong Studio, rồi execute_luau nội dung file này ở datamodel
-- CLIENT. Nó mô phỏng đúng thứ một exploiter làm: client đã bị kiểm soát hoàn
-- toàn, gửi bất kỳ giá trị nào lên server.
--
-- Nguyên tắc chấm điểm: sau toàn bộ đợt tấn công, Speed/Wins/Level/Rebirths của
-- người chơi PHẢI không đổi (nhân vật đứng yên trong lobby, không đứng treadmill
-- nên không có nguồn tăng hợp lệ nào). Bất kỳ con số nào nhúc nhích = server đã
-- tin client ở đâu đó.
--
-- Mọi lệnh gửi đều bọc pcall: mục tiêu là xem SERVER có sống và có bị lừa không,
-- không phải xem client có nổ không.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)

local player = Players.LocalPlayer
local log = {}
local sendCount = 0
local sendFailed = 0

local function note(line: string)
	table.insert(log, line)
end

local function fire(packetName: string, payload: any)
	local packet = GamePackets[packetName]
	if not packet then
		note(`  ! không có packet {packetName}`)
		return
	end
	sendCount += 1
	local ok = pcall(function()
		packet.send(payload)
	end)
	if not ok then
		sendFailed += 1
	end
end

local function snapshot()
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return nil
	end
	return {
		Speed = stats.Speed.Value,
		Wins = stats.Wins.Value,
		Level = stats.Level.Value,
		Rebirths = stats.Rebirths.Value,
		WalkSpeed = (player.Character
			and player.Character:FindFirstChildOfClass("Humanoid")
			and player.Character:FindFirstChildOfClass("Humanoid").WalkSpeed) or -1,
	}
end

local before = snapshot()
if not before then
	return "CHƯA CHẠY ĐƯỢC: không thấy leaderstats — profile chưa load xong, đợi vài giây rồi chạy lại."
end

local HUGE_STRING = string.rep("A", 8000)

-- ============================================================================
-- 1. Ép WalkSpeed bằng giá trị bệnh hoạn
-- ============================================================================
note("[1] requestCustomSpeed — NaN / vô cực / âm / khổng lồ")
for _, value in { 0 / 0, math.huge, -math.huge, 1e30, -1e30, -500, 0, 999999 } do
	fire("requestCustomSpeed", { walkSpeed = value })
end
task.wait(0.6)
local afterSpeedAttack = snapshot()
note(`    WalkSpeed sau đợt tấn công = {afterSpeedAttack.WalkSpeed}`)

-- ============================================================================
-- 2. Rebirth khi chưa đủ điều kiện
-- ============================================================================
note("[2] requestRebirth ×80 ở Level thấp + bật Auto-Rebirth khi không có pass")
for _ = 1, 80 do
	fire("requestRebirth", {})
end
for _ = 1, 20 do
	fire("requestAutoRebirthToggle", { enabled = true })
end

-- ============================================================================
-- 3. Cosmetic — nhận đồ không trả tiền
-- ============================================================================
note("[3] requestCosmeticAction — id giả, chuỗi rỗng, chuỗi 8000 ký tự, món premium chưa mua")
local cosmeticAttacks = {
	{ category = "trail", itemId = "trail_galaxy" },
	{ category = "aura", itemId = "RedHeart" },
	{ category = "aura", itemId = "aura_frozen_bloom" },
	{ category = "trail", itemId = "KHONG_TON_TAI" },
	{ category = "KHONG_TON_TAI", itemId = "trail_green" },
	{ category = "", itemId = "" },
	{ category = "trail", itemId = HUGE_STRING },
	{ category = HUGE_STRING, itemId = HUGE_STRING },
}
for _, attack in cosmeticAttacks do
	for _ = 1, 10 do
		fire("requestCosmeticAction", attack)
	end
end

-- ============================================================================
-- 4. Teleport lậu
-- ============================================================================
note("[4] requestTeleport — đích giả, kiểu thanh toán giả")
local teleportAttacks = {
	{ destinationId = "stage_15", paymentKind = "free" },
	{ destinationId = "stage_15", paymentKind = "robux" },
	{ destinationId = "stage_15", paymentKind = HUGE_STRING },
	{ destinationId = "KHONG_TON_TAI", paymentKind = "wins" },
	{ destinationId = "", paymentKind = "" },
}
for _, attack in teleportAttacks do
	for _ = 1, 10 do
		fire("requestTeleport", attack)
	end
end

-- ============================================================================
-- 5. Hồi sinh miễn phí
-- ============================================================================
note("[5] requestRevive — method giả (không hề chết)")
for _, method in { "free", "robux", "ad", "", HUGE_STRING, "gamepass" } do
	for _ = 1, 10 do
		fire("requestRevive", { method = method })
	end
end

-- ============================================================================
-- 6. Đập kính Zone 13 từ xa
-- ============================================================================
note("[6] requestGlassSmash — tên tấm giả, spam từ lobby")
for _, wallName in { "Glass1", "Glass_KHONG_TON_TAI", "", HUGE_STRING } do
	for _ = 1, 20 do
		fire("requestGlassSmash", { wallName = wallName })
	end
end

-- ============================================================================
-- 7. Code — nhập lại, nhập rác
-- ============================================================================
note("[7] requestRedeemCode — code rác + spam")
for _, code in { "FREESPEED", "freespeed", "", HUGE_STRING, "'; DROP TABLE --" } do
	for _ = 1, 15 do
		fire("requestRedeemCode", { code = code })
	end
end

-- ============================================================================
-- 8. Rương nhóm / Daily / Roulette — nhận thưởng nhiều lần
-- ============================================================================
note("[8] Group chest / Daily / Roulette — spam nhận thưởng")
for _ = 1, 60 do
	fire("requestGroupChestLikeConfirm", {})
	fire("requestGroupChestClaim", {})
	fire("requestDailyClaim", {})
	fire("requestSpin", {})
end

-- ============================================================================
-- 9. Treadmill ma — báo "tôi đang đứng treadmill" khi đứng giữa lobby
-- ============================================================================
note("[9] treadmillContact isOn=true ×200 khi đang ở lobby (cách treadmill rất xa)")
for _ = 1, 200 do
	fire("treadmillContact", { isOn = true })
end

-- ============================================================================
-- 10. Lụt gói tin — kiểm tra rate limit
-- ============================================================================
note("[10] Lụt 3000 gói requestSnapshot + requestRouletteState")
for _ = 1, 3000 do
	fire("requestSnapshot", {})
	fire("requestRouletteState", {})
end

-- Cho server 4 giây để xử lý hết hàng đợi rồi mới chấm điểm.
task.wait(4)

-- ============================================================================
-- CHẤM ĐIỂM
-- ============================================================================
local after = snapshot()
local verdicts = {}

local function judge(label: string, ok: boolean, detail: string)
	table.insert(verdicts, `{if ok then "PASS" else "*** FAIL ***"}  {label} — {detail}`)
end

judge(
	"Speed không bị bơm",
	after.Speed == before.Speed,
	`{before.Speed} → {after.Speed}`
)
judge("Wins không bị bơm", after.Wins == before.Wins, `{before.Wins} → {after.Wins}`)
judge("Level không bị bơm", after.Level == before.Level, `{before.Level} → {after.Level}`)
judge(
	"Rebirths không tăng khi chưa đủ level",
	after.Rebirths == before.Rebirths,
	`{before.Rebirths} → {after.Rebirths}`
)
judge(
	"WalkSpeed vẫn là số hợp lệ",
	after.WalkSpeed == after.WalkSpeed and after.WalkSpeed > 0 and after.WalkSpeed <= 250,
	`= {after.WalkSpeed}`
)
judge("Nhân vật còn sống (server không kill oan)", player.Character ~= nil, "")

local equippedTrail = player:GetAttribute("EquippedTrail")
local equippedAura = player:GetAttribute("EquippedAura")
judge(
	"Không tự trang bị được trail chưa mua",
	equippedTrail ~= "trail_galaxy",
	`EquippedTrail = {tostring(equippedTrail)}`
)
judge(
	"Không tự trang bị được aura chưa mua",
	equippedAura ~= "RedHeart" and equippedAura ~= "aura_frozen_bloom",
	`EquippedAura = {tostring(equippedAura)}`
)

local failures = 0
for _, verdict in verdicts do
	if verdict:find("FAIL") then
		failures += 1
	end
end

return table.concat(log, "\n")
	.. `\n\n─── ĐÃ BẮN {sendCount} GÓI ({sendFailed} gói client tự từ chối) ───\n`
	.. table.concat(verdicts, "\n")
	.. `\n\n═══ {#verdicts - failures}/{#verdicts} ĐẠT, {failures} HỎNG ═══`
