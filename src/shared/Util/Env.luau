--!strict
-- Nhận diện môi trường đang chạy (Studio / QA / Live) và tách không gian dữ liệu.
--
-- Cả 2 place nằm chung MỘT universe nên chúng dùng chung DataStore, gamepass và
-- product. Dùng chung ID mua bán là điều ta muốn (test được luồng Robux thật),
-- nhưng dùng chung DataStore thì QA sẽ đè lên dữ liệu người chơi thật. Vì vậy
-- mọi tên store phải đi qua Env.StoreName().
--
-- Quy tắc an toàn: chỉ đúng LIVE_PLACE_ID mới được coi là Live. Bất kỳ place nào
-- khác — kể cả place mới tạo sau này — đều rơi về QA. Đoán sai theo hướng này
-- chỉ làm bẩn dữ liệu QA; đoán sai theo hướng ngược lại thì mất dữ liệu thật.
--
-- ⚠️ KHI RA WORLD 2 (hoặc bất kỳ place Live thứ hai nào): phải đổi chỗ này thành
-- một DANH SÁCH place Live. Nếu quên, World 2 sẽ bị xếp vào QA và người chơi
-- teleport sang đó thấy tài khoản trắng — đúng, dữ liệu thật vẫn còn nguyên
-- trong bể Live, nhưng người chơi sẽ tưởng là mất sạch.

local RunService = game:GetService("RunService")

local LIVE_PLACE_ID = 94107323826144
local QA_PLACE_ID = 76318425379626

export type Environment = "Studio" | "QA" | "Live"

local current: Environment
if RunService:IsStudio() then
	current = "Studio"
elseif game.PlaceId == LIVE_PLACE_ID then
	current = "Live"
else
	current = "QA"
end

local Env = {}

Env.LIVE_PLACE_ID = LIVE_PLACE_ID
Env.QA_PLACE_ID = QA_PLACE_ID
Env.UNIVERSE_ID = 10456737957

Env.Current = current

function Env.IsLive(): boolean
	return current == "Live"
end

function Env.IsQA(): boolean
	return current == "QA"
end

function Env.IsStudio(): boolean
	return current == "Studio"
end

-- Live giữ nguyên tên store cũ để không mất dữ liệu đang có.
-- Studio và QA cùng chia sẻ tiền tố "QA_": Studio bật API Services sẽ ghi vào
-- đúng bể của QA, không bao giờ chạm vào Live.
function Env.StoreName(baseName: string): string
	if current == "Live" then
		return baseName
	end
	return `QA_{baseName}`
end

return Env
