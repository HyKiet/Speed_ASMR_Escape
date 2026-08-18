--!strict
-- Rate-limit gói tin theo cặp (player, key).
--
-- MỖI LOẠI PACKET NÊN CÓ KEY RIÊNG. Đây là điều kiện sống còn: nếu hai luồng hợp
-- lệ khác nhau dùng chung một key, chúng sẽ tự chặn lẫn nhau (ví dụ modal Group
-- Chest gửi likeConfirm rồi state rồi claim trong cùng một thao tác). Tách key ra
-- thì chỉ có việc SPAM CÙNG một packet mới bị bỏ, còn các luồng khác nhau không
-- bao giờ va nhau.
--
-- Gói bị bỏ phải VÔ HÌNH với người chơi: caller chỉ `return`, KHÔNG gửi toast lỗi
-- (một gói trùng bị nuốt không phải là sự kiện đáng báo cho người chơi thật).
--
-- Bảng lưu dùng weak-key nên entry của một Player tự được thu gom khi họ rời game
-- — không cần dọn tay ở PlayerRemoving, không rò bộ nhớ theo phiên.
--
-- ProgressionService KHÔNG dùng module này: nó đã tự giữ requestTimes bên trong
-- session của mình từ trước. Module này phục vụ các service còn lại (Code, Daily,
-- Roulette, GroupChest) để chúng theo cùng một khuôn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local NetRateLimit = {}

local times: { [Player]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

-- Trả về true nếu gói này đến QUÁ SỚM so với gói cùng key trước đó — caller nên bỏ.
-- minInterval mặc định = Constants.NETWORK_RATE_LIMIT_SECONDS (0.4s).
function NetRateLimit.ShouldDrop(player: Player, key: string, minInterval: number?): boolean
	local interval = minInterval or Constants.NETWORK_RATE_LIMIT_SECONDS
	local now = os.clock()

	local perPlayer = times[player]
	if not perPlayer then
		perPlayer = {}
		times[player] = perPlayer
	end

	local last = perPlayer[key] or 0
	if now - last < interval then
		return true
	end

	perPlayer[key] = now
	return false
end

return NetRateLimit
