--!strict
-- Server: đếm bạn bè đang trong phiên để ProgressionService tính bonus và gửi HUD.
-- Gộp các lượt vào/ra thành một lần tra; kết quả của danh sách cũ không ghi đè danh sách mới.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local FriendService = {}

local friendsInServer: { [Player]: number } = {}
local members: { [Player]: boolean } = {}
local refreshPending = false
local refreshing = false
local ProgressionService: any

local function updateFriendsCount()
	local players: { Player } = {}
	local counts: { [Player]: number } = {}
	for p in members do
		table.insert(players, p)
		counts[p] = 0
	end

	local pairsToCheck = {}
	for i = 1, #players do
		for j = i + 1, #players do
			table.insert(pairsToCheck, { p1 = players[i], p2 = players[j] })
		end
	end

	for _, pair in pairsToCheck do
		if not members[pair.p1] or not members[pair.p2] then
			continue
		end
		local ok, isFriends = pcall(function()
			return pair.p1:IsFriendsWithAsync(pair.p2.UserId)
		end)
		if ok and isFriends then
			if counts[pair.p1] then
				counts[pair.p1] += 1
			end
			if counts[pair.p2] then
				counts[pair.p2] += 1
			end
		end
	end

	-- API có thể yield; một người vào/ra trong lúc tra làm toàn bộ snapshot này cũ đi.
	if refreshPending then
		return
	end
	for p, count in counts do
		if not members[p] then
			continue
		end
		if friendsInServer[p] ~= count then
			friendsInServer[p] = count
			if ProgressionService then
				ProgressionService.SendSnapshot(p)
			end
		end
	end
end

local function requestRefresh()
	refreshPending = true
	if refreshing then
		return
	end
	refreshing = true
	task.defer(function()
		repeat
			refreshPending = false
			local ok, err = pcall(function()
				updateFriendsCount()
				return true
			end)
			if not ok then
				warn("[FriendService] Không cập nhật được danh sách bạn bè:", err)
			end
		until not refreshPending
		refreshing = false
	end)
end

function FriendService.GetFriendsInServer(player: Player): number
	return friendsInServer[player] or 0
end

--[[
	══ THƯỞNG RỦ BẠN — TÍNH LẠI 2026-08-21 (user: "sao cho xứng đáng với player") ═══════════

	HAI LỖI ĐÃ SỬA CÙNG LÚC, và cái thứ hai mới là cái nặng:

	  1. Bảng chú thích in ra `Speed Boost: x1.100000023841858`. Số tính đúng, chỉ là hiển thị:
	     1.1 không biểu diễn chính xác bằng float32 (kiểu ByteNet dùng để gửi). Chữa ở
	     `Format.Multiplier`, không phải ở đây.
	  2. **Bảng hứa "x1.25 Wins" mà server KHÔNG HỀ nhân Wins.** `AwardWins` chưa bao giờ đọc
	     tới `FriendService`. Người chơi rủ được bạn vào rồi vẫn nhận đúng số Wins như cũ —
	     một lời hứa suông ngay trên HUD. Giờ đã nối vào (xem `AwardWins`).

	── VÌ SAO ĐỔI TỪ "TUYẾN TÍNH +10%" SANG BẢNG DỒN VỀ ĐẦU ────────────────────────────────

	TRẦN GIỮ NGUYÊN như GDD mục 3 (x1.5 Speed · x1.25 Wins) — trần là con số đã được cân với
	cả nền kinh tế, tôi không tự nâng. Cái đổi là HÌNH DẠNG đường cong.

	Lý do: rủ được 5 người bạn vào CÙNG MỘT server là chuyện gần như không xảy ra. Thực tế đại
	đa số người chơi dừng ở 0 hoặc 1. Mà đường tuyến tính +10%/bạn lại trả cho người bạn ĐẦU
	TIÊN — người duy nhất họ thật sự rủ được — đúng x1.1, tức là gần như không cảm thấy gì.
	Toàn bộ giá trị của tính năng bị dồn vào một cái mốc không ai chạm tới.

	Dồn về đầu: bạn đầu tiên nhảy thẳng lên x1.15 Speed + x1.10 Wins (gấp rưỡi phần thưởng cũ,
	và Wins thì từ 0 lên có), rồi thoải dần về đúng trần cũ ở bạn thứ 5. Không ai bị mất gì —
	mọi mốc đều ≥ bảng cũ — nhưng phần thưởng rơi vào chỗ người chơi VỚI TỚI ĐƯỢC.

	Đây cũng là đòn bẩy rẻ nhất của game: nó không tốn Robux của ai, chỉ đổi lấy CCU và tỉ lệ
	quay lại. Trả hậu ở mốc 1–2 bạn là đúng chỗ nên đầu tư.

	⚠️ Hệ số này nằm trong rổ LiveOps (nhân với Playtime × ServerBoost — xem GDD mục 3), nên
	nâng TRẦN là nhân lên toàn bộ rổ. Muốn hào phóng hơn thì sửa hình dạng bảng, ĐỪNG nâng
	phần tử cuối.
]]
-- Chỉ số = số bạn trong server (1..5). Bạn thứ 6 trở đi không thêm gì.
local SPEED_BONUS = { 0.15, 0.25, 0.35, 0.45, 0.50 } -- x1.15 → x1.50 (trần GDD)
local WINS_BONUS = { 0.10, 0.15, 0.20, 0.23, 0.25 } -- x1.10 → x1.25 (trần GDD)

local function bonusFor(table_: { number }, player: Player): number
	local count = math.min(#table_, FriendService.GetFriendsInServer(player))
	if count <= 0 then
		return 1
	end
	return 1 + table_[count]
end

-- Hệ số nhân vào TỐC ĐỘ farm. Luôn ≥ 1.
function FriendService.GetFriendsMultiplier(player: Player): number
	return bonusFor(SPEED_BONUS, player)
end

--[[
	Hệ số nhân vào WINS khi vượt ải. Luôn ≥ 1.

	⚠️ `AwardWins` chỉ được gọi nó với `reason == "stage"` / `"stage_x2"` — CÙNG phạm vi hẹp
	với VIP / x2 Wins / Server Boost / event, và vì cùng lý do: nhân cả `product` là gói Ultra
	Wins Pack tự phá giá, nhân `daily`/`roulette` là phá phép siết bảng điểm danh (GDD 8.A1).
]]
function FriendService.GetFriendsWinsMultiplier(player: Player): number
	return bonusFor(WINS_BONUS, player)
end

function FriendService.Init()
	ProgressionService = ServiceLocator.Get("ProgressionService")
end

function FriendService.Start()
	Players.PlayerAdded:Connect(function(player)
		members[player] = true
		friendsInServer[player] = 0
		requestRefresh()
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- PlayerRemoving chạy trước khi Parent đổi; loại khỏi tập phiên ngay tại đây.
		members[player] = nil
		friendsInServer[player] = nil
		requestRefresh()
	end)
	for _, player in Players:GetPlayers() do
		members[player] = true
		friendsInServer[player] = 0
	end
	requestRefresh()
end

return FriendService
