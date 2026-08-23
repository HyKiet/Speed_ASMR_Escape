--!strict
-- Nhận diện môi trường đang chạy (Studio / QA / Live) và tách không gian dữ liệu.
--
-- ⚠️ SỬA 2026-08-23 — bản cũ ghi "cả 2 place nằm chung MỘT universe". KHÔNG ĐÚNG NỮA.
-- QA và Live nằm ở HAI universe riêng (kiểm bằng Open Cloud 2026-08-23):
--     QA   universe 10648253073 · place 134428972694212 · "[QA] Speed ASMR Escape"
--     Live universe 10456737957 · place  94107323826144 · "+1 Speed ASMR Escape"
-- Place 76318425379626 mà tài liệu cũ gọi là QA thì KHÔNG TỒN TẠI — Open Cloud trả về
-- "No universe exists for place ID".
--
-- Hệ quả của việc tách universe:
--   • DataStore đã tách sẵn ở tầng Roblox (DataStore gắn theo universe). Tiền tố "QA_"
--     dưới đây thành lớp khoá THỨ HAI — thừa nhưng giữ lại, vì nó là thứ bảo vệ Studio
--     (Studio chạy từ file có thể mang PlaceId bất kỳ).
--   • Gamepass và Dev Product: TẤT CẢ đều được tạo ở universe LIVE (dashboard của QA trống
--     trơn — 0 pass, 0 product, kiểm 2026-08-23). Bán chúng bên trong QA chính là
--     "cross-game sale" — thứ Roblox đã TẮT từ 2026-05-29, và thông báo ghi rõ KHÔNG có
--     ngoại lệ kể cả hai experience cùng một chủ hoặc cùng group.
--     Triệu chứng dễ hiểu nhầm: hộp mua VẪN HIỆN đúng tên và giá trong QA, vì
--     `GetProductInfo` tra theo ID thì universe nào cũng tra được. Cái bị chặn là bước
--     THANH TOÁN, không phải bước hiển thị.
--     ⇒ Hệ quả cho World 2: phải là SUB-PLACE trong ĐÚNG universe Live. Tách universe riêng
--     là mất sạch khả năng bán pass/product ở đó.
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
local QA_PLACE_ID = 134428972694212

local LIVE_UNIVERSE_ID = 10456737957
local QA_UNIVERSE_ID = 10648253073

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
Env.LIVE_UNIVERSE_ID = LIVE_UNIVERSE_ID
Env.QA_UNIVERSE_ID = QA_UNIVERSE_ID

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
