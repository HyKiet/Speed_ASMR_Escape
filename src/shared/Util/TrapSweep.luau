--!strict
--[[
	TrapSweep.luau — phát hiện va chạm LIÊN TỤC (swept) cho bẫy zone.

	VẤN ĐỀ ĐANG CHỮA (user báo 2026-08-07: "walkspeed cao hoặc gắn aura/trail thì bẫy
	không giết player"). Mọi bẫy đều phán xử bằng một phép thử ĐIỂM tại vị trí HIỆN TẠI
	của người chơi, mỗi Heartbeat một lần. Đó là lấy mẫu rời rạc, và nó thủng theo đúng
	hai cách user gặp:

	  1) TỐC ĐỘ. Ở 250 WS người chơi đi 4.2 studs mỗi frame 60Hz — còn dàn laser Zone 2
	     phán xử ở 20Hz nên là 12.5 studs mỗi lần thử. Beam dày ~3 studs. Người chơi
	     nhảy CÁCH QUA cả bề dày beam giữa hai lần thử: chưa tới ở lần thử n, đã qua hẳn
	     ở lần n+1, không lần nào thấy trùng nhau. Bẫy càng mỏng càng thủng sớm
	     (cánh tay Zone 8 dày 1.5 studs).

	  2) AURA/TRAIL. Cosmetic được render CLIENT-SIDE (CosmeticVisualController) nên
	     server không hề thấy thêm part nào — đây không phải lỗi filter. Cái nó làm là
	     hạ FPS của client, mà client chính là network owner của nhân vật: FPS thấp ⇒
	     mỗi gói vị trí replicate về server nhảy một bước DÀI hơn ⇒ đúng lỗi (1) nhưng
	     nặng hơn, kể cả khi walkspeed không đổi. Cùng một cách chữa.

	ĐO ĐƯỢC trên đúng hình học laser Zone 2 (600 lượt băng qua/ô, WS 250):
	    bước server        thử điểm (cũ)   swept (mới)
	    60 fps —  4.2 studs    100.0%         100.0%
	    30 fps —  8.3 studs     45.0%         100.0%
	    20 fps — 12.5 studs     27.0%         100.0%
	    15 fps — 16.7 studs     27.0%         100.0%

	CÁCH CHỮA: thay vì hỏi "người chơi có đang ở trong bẫy không", hỏi "ĐOẠN ĐƯỜNG người
	chơi vừa đi qua có cắt bẫy không". Module giữ vị trí frame trước của từng player rồi
	rải mẫu dọc đoạn thẳng đó với bước <= độ dày mỏng nhất của bẫy.

	Tham số `alpha` (0 = đầu đoạn, 1 = cuối đoạn) trả về kèm mỗi mẫu để bẫy NỘI SUY CẢ
	CHUYỂN ĐỘNG CỦA CHÍNH NÓ tại cùng thời điểm — bắt buộc với bẫy nhanh (cánh tay Zone 8
	đầu mút đi 165 studs/s, khối lava Zone 10 rơi 350 studs/s): quét đường đi của người
	chơi mà so với bẫy đứng yên ở vị trí cuối frame thì vẫn lọt.

	CÁCH DÙNG — mỗi bẫy tạo một bộ quét RIÊNG:
	    local sweep = TrapSweep.new("Zone8")
	    local from, steps = sweep.segment(plr, pos, 1.0, armTravel)
]]

local Players = game:GetService("Players")

local TrapSweep = {}

-- Đoạn dài hơn ngần này coi như teleport/respawn, KHÔNG quét (nếu không, một cú
-- teleport ngang map sẽ quét qua mọi bẫy trên đường và giết oan).
local MAX_SEGMENT = 400
-- Trần số mẫu/đoạn: chặn chi phí khi dt giật (server hiccup) hoặc bẫy khai step quá nhỏ.
local MAX_SAMPLES = 24

type Track = { pos: Vector3, t: number }

export type Sweeper = {
	forEachStep: (Player, Vector3, number, (Vector3, number) -> boolean?) -> boolean,
	segment: (Player, Vector3, number, number) -> (Vector3, number),
	reset: (Player) -> (),
}

-- MỖI BẪY MỘT BẢNG DẤU VẾT RIÊNG. Bắt buộc, không phải cho gọn: mọi bẫy đều gọi
-- `reset(player)` cho những người ĐANG Ở NGOÀI vùng của nó, mỗi frame. Dùng chung một bảng
-- thì Zone 2 xoá sạch dấu vết mà Zone 8/9/10 vừa ghi (và ngược lại) — đoạn quét luôn rỗng và
-- swept âm thầm thoái hoá về đúng phép thử điểm mà nó đang chữa.
local allTracks: { [string]: { [Player]: Track } } = {}

Players.PlayerRemoving:Connect(function(player)
	for _, tracks in allTracks do
		tracks[player] = nil
	end
end)

--[[
	Tạo một bộ quét ĐỘC LẬP cho một bẫy. `name` chỉ để phân biệt bảng dấu vết (và debug).
	Các hàm trả về gọi bằng DẤU CHẤM (closure, không phải method).
]]
function TrapSweep.new(name: string): Sweeper
	local tracks: { [Player]: Track } = {}
	allTracks[name] = tracks

	--[[
		Quét đoạn đường player vừa đi trong frame này.

		`step` = bước rải mẫu (studs) — đặt bằng NỬA bề dày mỏng nhất của bẫy để không bao
		giờ nhảy qua. `fn(pos, alpha)` gọi cho từng mẫu, trả `true` để dừng sớm (đã trúng).
		Trả về `true` nếu `fn` báo trúng ở bất kỳ mẫu nào.

		Mẫu ĐẦU TIÊN luôn là vị trí hiện tại (alpha = 1) — frame đầu sau khi spawn hoặc sau
		teleport chưa có điểm trước thì vẫn hành xử đúng y như bản kiểm tra điểm cũ.
	]]
	local function forEachStep(
		player: Player,
		pos: Vector3,
		step: number,
		fn: (Vector3, number) -> boolean?
	): boolean
		local prev = tracks[player]
		tracks[player] = { pos = pos, t = os.clock() }

		if fn(pos, 1) then
			return true
		end
		if not prev then
			return false
		end

		local delta = pos - prev.pos
		local dist = delta.Magnitude
		if dist <= step or dist > MAX_SEGMENT then
			return false
		end

		local n = math.min(math.floor(dist / math.max(step, 0.1)), MAX_SAMPLES)
		-- đi NGƯỢC từ gần hiện tại về quá khứ: trúng ở đâu cũng đúng, nhưng thứ tự này cho
		-- điểm chết gần vị trí người chơi nhìn thấy nhất khi dừng sớm.
		for i = n - 1, 0, -1 do
			local alpha = i / n
			if fn(prev.pos + delta * alpha, alpha) then
				return true
			end
		end
		return false
	end

	--[[
		Biến thể "tự quản số mẫu" cho bẫy mà BẢN THÂN NÓ cũng đi nhanh (cánh tay Zone 8 đầu
		mút 165 studs/s, khối lava Zone 10 rơi 350 studs/s). Ở đó, số mẫu không được suy từ
		riêng quãng đường người chơi: người đứng YÊN mà bẫy quét qua vẫn phải bắt được.

		`trapTravel` = quãng đường chính bẫy đi trong frame này (studs) tại vị trí người chơi.
		Số mẫu lấy theo cái LỚN HƠN giữa hai chuyển động.

		Trả về prevPos, n (số khoảng). Bẫy tự lặp alpha = i/n để nội suy cả hai phía.
	]]
	local function segment(player: Player, pos: Vector3, step: number, trapTravel: number): (Vector3, number)
		local prev = tracks[player]
		tracks[player] = { pos = pos, t = os.clock() }

		local from = if prev then prev.pos else pos
		local dist = (pos - from).Magnitude
		if dist > MAX_SEGMENT then
			from, dist = pos, 0 -- teleport/respawn: không nối đoạn
		end

		local travel = math.max(dist, trapTravel)
		local n = math.clamp(math.ceil(travel / math.max(step, 0.1)), 1, MAX_SAMPLES)
		return from, n
	end

	-- Xoá dấu vết: gọi khi player chết/teleport/ra khỏi vùng, để đoạn kế tiếp không nối từ
	-- vị trí cũ.
	local function reset(player: Player)
		tracks[player] = nil
	end

	return { forEachStep = forEachStep, segment = segment, reset = reset }
end

return TrapSweep
