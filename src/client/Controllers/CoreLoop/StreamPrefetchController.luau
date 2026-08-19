--!strict
--[[
	StreamPrefetchController.luau — NẠP TRƯỚC THEO HƯỚNG CHẠY.

	── VẤN ĐỀ ĐANG CHỮA (user báo 2026-08-19) ────────────────────────────────────────────
	"WalkSpeed cao chạy các zone bị lỗi / map chưa load kịp."

	Streaming của Roblox nạp content quanh VỊ TRÍ HIỆN TẠI. Ở tốc độ thấp thì thừa thời
	gian, nhưng game này cho phép tới 250 studs/giây — người chơi đi hết một bán kính 1.024
	studs trong 4 giây, và đi hết `StreamingMinRadius` mặc định (64) trong đúng 0,26 giây.
	Kết quả là chạy nhanh thì lao vào vùng chưa nạp: sàn chưa có nên rơi xuyên, bẫy chưa có
	nên không bị chặn, vật thể bật ra ngay trước mặt.

	── CÁCH CHỮA ─────────────────────────────────────────────────────────────────────────
	Đoán trước người chơi sẽ ở đâu sau `LOOKAHEAD_SECONDS` rồi bảo Roblox nạp quanh ĐIỂM ĐÓ
	thay vì đợi họ tới nơi:

	    điểm đích = vị trí + hướng_vận_tốc × tốc_độ × LOOKAHEAD_SECONDS

	Đây đúng nguyên tắc mà `ZoneLod` đã dùng cho tầm đánh thức bẫy (bán kính = WalkSpeed ×
	3,2 giây) — cùng một bài học: ở game tốc độ cao, mọi ngưỡng khoảng cách phải tính theo
	TỐC ĐỘ, không được là hằng số studs.

	── VÌ SAO KHÔNG NẠP LIÊN TỤC MỖI KHUNG HÌNH ──────────────────────────────────────────
	`RequestStreamAroundAsync` là lời gọi có YIELD và có chi phí; gọi mỗi khung hình sẽ dồn
	hàng đợi và tự làm chậm chính việc nạp. Vì vậy:
	  • Chỉ gọi khi đã đi đủ xa kể từ lần gọi trước (`MIN_MOVE_BEFORE_REFETCH`), HOẶC
	  • hết `MAX_INTERVAL` giây.
	  • Và không bao giờ có hai lời gọi chồng nhau (`inFlight`).
	Ở tốc độ đi bộ thì gần như không gọi lần nào; càng chạy nhanh nó càng làm việc nhiều —
	đúng chỗ cần.

	⚠️ Controller này KHÔNG thay được các thuộc tính Workspace (Roblox đánh dấu chúng
	NotScriptable). Nó chỉ giúp nạp SỚM hơn. Muốn người chơi không bao giờ lọt sàn thì vẫn
	phải bật `StreamingIntegrityMode = PauseOutsideLoadedArea` bằng tay trong Studio.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StreamPrefetchController = {}

-- Nhìn trước bao nhiêu giây đường chạy. 3,5s ở 250 WS = 875 studs — vượt xa khoảng cách
-- giữa hai zone liền nhau (đo được 139–624 studs), nên luôn nạp trước ít nhất một zone.
local LOOKAHEAD_SECONDS = 3.5
-- Dưới ngưỡng này coi như đứng yên: không có hướng đáng tin để đoán.
local MIN_SPEED = 24
-- Đi được chừng này kể từ lần nạp trước thì mới nạp lại.
local MIN_MOVE_BEFORE_REFETCH = 180
-- Trần thời gian giữa hai lần nạp, kể cả khi đứng yên tại chỗ nhưng vẫn đang di chuyển chậm.
local MAX_INTERVAL = 2.0
-- Trần chờ mỗi lời gọi. Ngắn thôi: đây là nạp TRƯỚC, trễ một nhịp không sao,
-- nhưng treo lâu thì lời gọi kế bị nghẽn.
local REQUEST_TIMEOUT = 2.0

local localPlayer = Players.LocalPlayer

function StreamPrefetchController.Start()
	-- Streaming tắt thì không có gì để nạp trước.
	if not Workspace.StreamingEnabled then
		print("[StreamPrefetch] StreamingEnabled = false — bỏ qua")
		return
	end

	local inFlight = false
	local lastFetchPos: Vector3? = nil
	local lastFetchAt = 0
	local accum = 0

	RunService.Heartbeat:Connect(function(dt: number)
		-- Kiểm tra thưa: 4 lần/giây là quá đủ cho một phép đoán tính bằng giây.
		accum += dt
		if accum < 0.25 then
			return
		end
		accum = 0

		if inFlight then
			return
		end

		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			return
		end

		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = flat.Magnitude
		if speed < MIN_SPEED then
			return
		end

		local pos = root.Position
		local movedEnough = lastFetchPos == nil or (pos - lastFetchPos).Magnitude >= MIN_MOVE_BEFORE_REFETCH
		local waitedEnough = os.clock() - lastFetchAt >= MAX_INTERVAL
		if not (movedEnough or waitedEnough) then
			return
		end

		-- Điểm người chơi SẼ tới, không phải điểm họ đang đứng.
		local target = pos + flat.Unit * (speed * LOOKAHEAD_SECONDS)

		inFlight = true
		lastFetchPos = pos
		lastFetchAt = os.clock()
		task.spawn(function()
			-- pcall: `RequestStreamAroundAsync` ném lỗi khi hết thời gian chờ hoặc khi toạ độ
			-- nằm ngoài thế giới. Cả hai đều không phải lỗi cần xử lý — chỉ bỏ nhịp này.
			pcall(function()
				localPlayer:RequestStreamAroundAsync(target, REQUEST_TIMEOUT)
			end)
			inFlight = false
		end)
	end)

	print(
		("[StreamPrefetch] sẵn sàng — nhìn trước %.1fs (ở 250 WS = %d studs)"):format(
			LOOKAHEAD_SECONDS,
			math.floor(250 * LOOKAHEAD_SECONDS)
		)
	)
end

return StreamPrefetchController
