--!strict
--[[
	FrameStatsLogger — ĐO THẬT hiện tượng "khựng khựng khi lia màn hình", trên MÁY THẬT.

	══ VÌ SAO PHẢI CÓ FILE NÀY ══════════════════════════════════════════════════════════════

	Câu hỏi "vì sao PC khựng mà iPhone thì không" không trả lời được bằng cách đọc code, và
	cũng không đo được trong Studio: Studio mất focus là bóp FPS xuống ~20 nên mọi con số FPS
	đo qua MCP đều vô nghĩa.

	⚠️ BÀI HỌC BẢN v1 (2026-08-21) — ĐỪNG LẶP LẠI:
	Bản đầu đọc `Stats.FrameRateManager` (RenderAverage / AverageGPU / RenderThreadAverage /
	Indices / Batches). Trong Studio nó trả số đẹp, nhưng **trên client THẬT mọi ô đều trả 0**
	— cả log của user in ra `render 0.00 gpu 0.00 renderThread 0.00 tri 0.00M batch 0`. Đó là
	telemetry chỉ sống trong Studio. Nguồn đúng cho client thật là **`Stats.PerformanceStats`**
	— đúng bộ số mà dải Performance Stats trên màn hình đang hiện (Mem / CPU ms / GPU ms /
	Ping), và bộ đó chạy ở mọi nơi.

	Quy tắc chung rút ra: mọi số lấy từ `Stats` phải được KIỂM TRÊN CLIENT THẬT trước khi tin.

	── ĐỌC KẾT QUẢ ──────────────────────────────────────────────────────────────────────────
	    cpu cao, gpu thấp        → nghẽn CPU: số part, script, streaming ⇒ lỗi MAP/CODE
	    gpu cao, cpu thấp        → nghẽn GPU: shadow, post-process, độ phân giải
	    cả hai thấp mà fps thấp  → nghẽn ở chỗ khác (đồng bộ dọc, tải asset, GC)
	    `giật` lớn               → ĐÂY MỚI LÀ THỨ MẮT THẤY. Số khung hình dài hơn GẤP ĐÔI khung
	                               trung vị. 60 fps đều tay thì `giật` = 0; còn 55 fps mà mỗi
	                               giây có 5 khung 35 ms thì mắt đọc ra là "khựng khựng" —
	                               ĐÚNG cái user tả. FPS trung bình một mình KHÔNG thấy được.

	── CÁCH DÙNG ────────────────────────────────────────────────────────────────────────────
	  1. Vào game (QA hay Live, PC hay điện thoại đều được).
	  2. Bấm  Ctrl + Shift + F  để bật (bấm lại để tắt).
	  3. Mở Developer Console: PC bấm F9, mobile gõ `/console` trong chat.
	  4. LIA CAMERA qua lại ~10 giây, rồi ĐỨNG YÊN ~10 giây. Chụp log gửi lại.

	Hai đoạn đó mới là phép đo: chênh lệch giữa chúng chỉ khác đúng một thứ — bao nhiêu hình
	học mới lọt vào khung nhìn.

	⚠️ Gắn vào phím CHỨ không phải attribute: attribute chỉ đặt được trong Studio, mà chỗ cần
	đo là máy thật của người chơi. Log chỉ đi vào Developer Console nên không làm phiền ai.
]]

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local FrameStatsLogger = {}

local SAMPLE_SECONDS = 1
-- Khung hình dài hơn `JUDDER_FACTOR` × khung TRUNG VỊ thì tính là một cú giật.
local JUDDER_FACTOR = 2

-- Đọc một ô của `Stats.PerformanceStats`. Trả 0 nếu thiếu — tên các ô này không phải API
-- công khai, và mất một ô không được làm chết cả logger.
local function perf(node: Instance?, name: string): number
	local child = node and node:FindFirstChild(name)
	if not child then
		return 0
	end
	local ok, value = pcall(function()
		return (child :: any):GetValue()
	end)
	return if ok and typeof(value) == "number" then value else 0
end

local running = false
local connection: RBXScriptConnection? = nil

local function stop()
	running = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
	print("[FrameStats] TẮT")
end

local function start()
	running = true
	local ps = Stats:FindFirstChild("PerformanceStats")
	local lastPrint = os.clock()
	local samples: { number } = {}

	print("[FrameStats] BẬT — lia camera ~10s rồi đứng yên ~10s. Ctrl+Shift+F để tắt.")
	--[[
		⚠️ `cpu`/`gpu`/`ping` in ra 0.0 là BÌNH THƯỜNG nếu chưa bật dải Performance Stats.

		Đo 2026-08-21: `Stats.PerformanceStats.*` chỉ được engine cập nhật khi dải thống kê
		trên màn hình đang HIỆN. Tắt dải đi thì mấy ô đó đứng ở 0 — không phải máy không tải
		gì. Bật ở: nút Roblox (góc trái) → Settings → Performance Stats → On.

		`mem` thì luôn đúng vì nó lấy từ `Stats:GetTotalMemoryUsageMb()`, không qua bảng đó.
	]]
	if perf(ps, "CPU") <= 0 then
		warn(
			"[FrameStats] cpu/gpu đang đọc 0 — bật Roblox menu → Settings → Performance Stats = On rồi bật lại"
		)
	end

	connection = RunService.RenderStepped:Connect(function(dt: number)
		table.insert(samples, dt)

		local now = os.clock()
		if now - lastPrint < SAMPLE_SECONDS then
			return
		end
		local elapsed = now - lastPrint
		lastPrint = now

		--[[
			TRUNG VỊ, không phải TRUNG BÌNH.

			Trung bình bị chính mấy khung hình dài kéo lên, nên nó che mất đúng thứ cần tìm.
			Trung vị cho biết "khung hình BÌNH THƯỜNG dài bao nhiêu", rồi đếm xem bao nhiêu
			khung dài gấp đôi mức đó — đó mới là con số tương ứng với cảm giác khựng.
		]]
		local sorted = table.clone(samples)
		table.sort(sorted)
		local count = #sorted
		local median = sorted[math.max(1, math.floor(count * 0.5))]
		local p99 = sorted[math.max(1, math.floor(count * 0.99))]
		local worst = sorted[count]
		local judder = 0
		for _, value in sorted do
			if value > median * JUDDER_FACTOR then
				judder += 1
			end
		end

		print(
			string.format(
				"[FrameStats] fps %5.1f | khung thường %5.1fms  p99 %5.1fms  xấu nhất %6.1fms | GIẬT %d/%d | cpu %5.1fms gpu %5.1fms | mem %.0fMB ping %.0fms",
				count / elapsed,
				median * 1000,
				p99 * 1000,
				worst * 1000,
				judder,
				count,
				perf(ps, "CPU"),
				perf(ps, "GPU"),
				Stats:GetTotalMemoryUsageMb(),
				perf(ps, "Ping")
			)
		)

		table.clear(samples)
	end)
end

function FrameStatsLogger.Init() end

function FrameStatsLogger.Start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or input.KeyCode ~= Enum.KeyCode.F then
			return
		end
		if
			not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		then
			return
		end
		if running then
			stop()
		else
			start()
		end
	end)

	-- Chỉ nhắc trong Studio: ngoài Studio thì dòng này là rác trong console của người chơi.
	if RunService:IsStudio() then
		print("[FrameStats] sẵn sàng — Ctrl+Shift+F để bật/tắt, xem log ở Developer Console (F9)")
	end
end

return FrameStatsLogger
