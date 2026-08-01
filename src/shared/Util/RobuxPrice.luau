--!strict
--[[
	RobuxPrice.luau — giá Robux LIVE theo vùng (regional pricing).

	Roblox tính giá Robux khác nhau theo vùng của người mua. Nếu hardcode số vào
	billboard/UI thì người chơi thấy một giá nhưng bị tính một giá khác trong prompt.
	Creator docs yêu cầu đọc giá lúc runtime qua `GetProductInfoAsync` — và phải gọi
	TỪ CLIENT thì `PriceInRobux` mới là giá theo vùng của chính người đang xem.

	Glyph Robux là ký tự riêng của font Roblox tại U+E002 ("").
]]

local MarketplaceService = game:GetService("MarketplaceService")

local RobuxPrice = {}

RobuxPrice.GLYPH = utf8.char(0xE002)

local cache: { [number]: number } = {}
local inFlight: { [number]: boolean } = {}

-- Giá Robux theo vùng của người chơi cục bộ. nil = pass chưa cấu hình (id 0) hoặc gọi lỗi.
function RobuxPrice.GetAsync(gamepassId: number): number?
	if gamepassId <= 0 then
		return nil
	end
	if cache[gamepassId] then
		return cache[gamepassId]
	end

	-- Nhiều billboard có thể hỏi cùng một pass — chỉ bắn 1 request, số còn lại chờ.
	if inFlight[gamepassId] then
		while inFlight[gamepassId] do
			task.wait(0.05)
		end
		return cache[gamepassId]
	end

	inFlight[gamepassId] = true
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(gamepassId, Enum.InfoType.GamePass)
	end)
	inFlight[gamepassId] = nil

	if not ok then
		warn(`[RobuxPrice] Không lấy được giá gamepass {gamepassId}: {tostring(info)}`)
		return nil
	end

	local price = (info :: any).PriceInRobux
	if typeof(price) ~= "number" then
		return nil
	end

	cache[gamepassId] = price
	return price
end

-- " 1299" — glyph trước, số sau.
function RobuxPrice.Format(price: number?): string
	if price == nil then
		return "SOON"
	end
	return `{RobuxPrice.GLYPH} {price}`
end


-- " 1299" — glyph trước. Dùng cho nút mua trong modal.
function RobuxPrice.FormatPrefixed(price: number?): string
	if price == nil then
		return "SOON"
	end
	return `{RobuxPrice.GLYPH} {price}`
end

return RobuxPrice
