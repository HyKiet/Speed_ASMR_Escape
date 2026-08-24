--!strict
--[[
	AutoPerformanceController — ĐO khung hình, ĐỀ NGHỊ bật Performance Mode khi máy tụt FPS.

	══ VÌ SAO CÓ FILE NÀY ═══════════════════════════════════════════════════════════════════

	User hỏi thẳng: "có cách nào để FPS luôn cao nhất không". Câu trả lời trung thực là không
	có một công tắc nào làm được điều đó — nhưng có thể làm cho game TỰ ĐIỀU CHỈNH thay vì bắt
	người chơi đi tìm nút Cài đặt.

	`Performance Mode` (`ClientSettingsController`) vốn đã tồn tại, nhưng nó là OPT-IN: nằm sau
	nút Cài đặt trên topbar. Thực tế gần như không ai vào đó — người chơi thấy game giật thì họ
	thoát, không đi tìm cài đặt. Cái mất mát đó là im lặng và không đo được.

	Ngoài ra Roblox CÓ tự chỉnh chất lượng (`AverageQualityLevel`), nhưng nó chỉ biết những thứ
	của ENGINE. Nó không biết game này có: cosmetic của người chơi khác, tới 800 SurfaceGui nhãn
	phím, bóng đổ trên từng part nhân vật. Đó đúng là những thứ `Performance Mode` tắt.

	══ CÁCH ĐO — TRUNG VỊ, KHÔNG PHẢI TRUNG BÌNH ═══════════════════════════════════════════

	Trung bình bị kéo lệch bởi đúng mấy khung hình dài mà ta đang muốn phát hiện, và cũng bị
	một cú khựng đơn lẻ (nạp streaming, mở modal) đánh lừa. Trung vị trả lời đúng câu hỏi cần
	hỏi: "khung hình BÌNH THƯỜNG của máy này dài bao nhiêu".

	Số đo thật để hiệu chỉnh hai ngưỡng (2026-08-21, cùng một máy PC):
	    trong Studio  : trung vị 16,3–16,8 ms  → 60 fps chắc tay, GIẬT 0/60
	    game đã publish: trung vị 17,0–22,1 ms → 45–58 fps, khựng thấy rõ
	Nên 20 ms (50 fps) là ranh giới phân biệt được hai trạng thái đó, và 17,2 ms (58 fps) là
	mức "đang chạy đủ mượt" — đặt sát 16,67 quá thì không bao giờ leo lại được.

	══ ĐỀ NGHỊ, KHÔNG TỰ BẬT (user chốt 2026-08-22) ════════════════════════════════════════

	⚠️ BẢN TỰ BẬT ĐÃ BỊ BÁC — ĐỪNG DỰNG LẠI. User: "AutoPerformance không được tự bật."
	Bản đầu tự gọi `SetPerformanceMode(true)` khi thấy máy tụt. Nó "đúng kỹ thuật" nhưng sai
	về quyền: người chơi đang nhìn màn hình thì hình ảnh tự đổi mà họ không ra lệnh — không
	phân biệt được với game hỏng, và không biết vì sao vừa xấu đi.

	Giờ nó chỉ ĐO và ĐỀ NGHỊ **đúng một lần mỗi phiên** bằng một toast. Người chơi bấm nút
	Cài đặt để bật, hoặc lờ đi. Giá trị của phép đo vẫn còn nguyên (người chơi biết game đang
	tụt và biết có cách chữa), chỉ bỏ đúng phần giành quyền.

	Muốn quay lại tự bật: đổi `SUGGEST_ONLY = false` — nhưng đọc đoạn trên trước.

	══ BA NGUYÊN TẮC PHẢI GIỮ ══════════════════════════════════════════════════════════════

	1. KHÔNG BAO GIỜ ĐÈ QUYẾT ĐỊNH CỦA NGƯỜI CHƠI. Ai đã tự bật/tắt Performance Mode trong
	   Cài đặt thì controller này im lặng vĩnh viễn trong phiên đó.
	2. ĐỀ NGHỊ ĐÚNG MỘT LẦN. Toast nhắc lại mỗi lần tụt FPS còn phiền hơn cả chuyện tụt FPS.
	3. BỎ QUA GIAI ĐOẠN NẠP. 12 giây đầu phiên là lúc streaming + preload đang chạy, khung
	   hình dài là bình thường. Đo lúc đó là chắc chắn nhắc nhầm cho mọi người.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ClientSettingsController = require(script.Parent.ClientSettingsController)
local Toast = require(script.Parent.Parent.HUD.Toast)

local AutoPerformanceController = {}

-- Chỉ ĐỀ NGHỊ, không tự bật. Xem khối "ĐỀ NGHỊ, KHÔNG TỰ BẬT" ở đầu file trước khi đổi.
local SUGGEST_ONLY = true

--[[
	══ GRAPHICS MODE = AUTOMATIC — ĐỌC ĐƯỢC, GHI THÌ KHÔNG ═════════════════════════════════

	User tự tìm ra và test nhiều lần (2026-08-22): **Graphics Mode = Automatic thì lia màn
	hình rất mượt; chuyển sang Manual + kéo max thì giật.** Rồi hỏi: game tự đặt Automatic
	lúc người chơi vào được không.

	Không được. Cùng bức tường quyền như thanh Graphics Quality — đo lại đúng ca này:

	    UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
	      → "The current thread cannot set 'render quality level' (lacking capability
	         RobloxScript)"

	NHƯNG **ĐỌC thì được** (đo: trả về `QualityLevel10` đúng như cài đặt máy user). Và
	`Enum.SavedQualitySetting.Automatic` = 0 chính là mục "Automatic" trong menu Roblox.

	⇒ Làm được đúng một nửa: KHÔNG đặt hộ được, nhưng BIẾT được người chơi đang ở Manual và
	  nhắc đúng câu cần nhắc. Nên toast tách làm hai nhánh — đang Manual thì khuyên đổi sang
	  Automatic (thứ user đo được là ăn nhất), đã Automatic rồi mới khuyên Performance Mode.

	⚠️ Chỉ nhắc KHI ĐÃ ĐO ĐƯỢC máy tụt. Nhắc mọi người đang để Manual là sai: ai cố ý để
	  Manual ở mức THẤP thì họ đang chạy nhanh, nhắc họ là phiền vô cớ.
]]
local function isAutomaticGraphics(): boolean
	local ok, value = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	-- Đọc lỗi ⇒ coi như đang Automatic, để không nhắc bừa.
	return (not ok) or value == Enum.SavedQualitySetting.Automatic
end

local WINDOW_SECONDS = 2
-- Trung vị vượt ngưỡng này = máy đang không theo kịp (20 ms ≈ 50 fps).
local BAD_FRAME_SECONDS = 1 / 50
-- Trung vị dưới ngưỡng này = máy đang thoải mái (17,2 ms ≈ 58 fps).
local GOOD_FRAME_SECONDS = 1 / 58
local WINDOWS_BEFORE_DOWNGRADE = 3
local WINDOWS_BEFORE_UPGRADE = 10
local WARMUP_SECONDS = 12

-- Đúng/sai: controller này có phải là bên đã bật Performance Mode không. Chỉ được TỰ TẮT thứ
-- do chính mình bật — nếu không, người chơi bật tay xong đứng yên một lúc là bị tắt mất.
local autoEnabled = false
-- Người chơi đã tự đụng vào công tắc chưa. Một chiều: đã bật lên thì không bao giờ về false.
local playerOverrode = false

--[[
	`SettingsModal` gọi hàm này ngay trước khi tự gọi `SetPerformanceMode`.

	Đặt ở đây chứ không bắt `ClientSettingsController` tự phát hiện: hàm `SetPerformanceMode`
	không phân biệt được ai gọi mình, và thêm tham số "ai gọi" vào nó thì mọi caller đều phải
	biết chuyện tự-động — một khái niệm không liên quan gì tới nó.
]]
function AutoPerformanceController.NotePlayerOverride()
	playerOverrode = true
	autoEnabled = false
end

function AutoPerformanceController.Init() end

function AutoPerformanceController.Start()
	local samples: { number } = {}
	local windowStart = os.clock()
	local startedAt = os.clock()
	local badWindows = 0
	local goodWindows = 0

	RunService.RenderStepped:Connect(function(dt: number)
		table.insert(samples, dt)

		local now = os.clock()
		if now - windowStart < WINDOW_SECONDS then
			return
		end
		windowStart = now

		local batch = samples
		samples = {}

		if playerOverrode or now - startedAt < WARMUP_SECONDS or #batch < 10 then
			return
		end

		table.sort(batch)
		local median = batch[math.floor(#batch * 0.5)]

		if median > BAD_FRAME_SECONDS then
			badWindows += 1
			goodWindows = 0
		elseif median < GOOD_FRAME_SECONDS then
			goodWindows += 1
			badWindows = 0
		else
			-- Vùng xám giữa hai ngưỡng: không tính về phía nào cả. Đây chính là chỗ hysteresis
			-- sống — thiếu nó thì máy nào chạy quanh 54 fps sẽ bật/tắt liên tục.
			badWindows = 0
			goodWindows = 0
		end

		if not autoEnabled and badWindows >= WINDOWS_BEFORE_DOWNGRADE then
			badWindows = 0
			if not ClientSettingsController.IsPerformanceMode() then
				if SUGGEST_ONLY then
					-- Một lần duy nhất mỗi phiên: dùng chính `playerOverrode` làm cờ câm, vì từ
					-- giây phút đã nhắc thì quả bóng nằm bên người chơi — hệt như khi họ tự bấm.
					playerOverrode = true
					local automatic = isAutomaticGraphics()
					-- Toàn bộ chữ hiện ra cho người chơi đều là TIẾNG ANH (chốt 2026-08-24) và
					-- theo khuôn VIỆC → KẾT QUẢ, một dòng, đọc lướt là hiểu.
					Toast.Show(
						if automatic
							then "Low FPS? Settings → Performance Mode"
							else "Low FPS? Roblox ⚙ → Graphics Mode → Automatic",
						"error"
					)
					print(
						string.format(
							"[AutoPerformance] khung hình trung vị %.1fms (<%d fps) — ĐỀ NGHỊ %s",
							median * 1000,
							math.floor(1 / BAD_FRAME_SECONDS),
							if automatic then "bật Performance Mode" else "chuyển Graphics Mode sang Automatic"
						)
					)
				else
					autoEnabled = true
					ClientSettingsController.SetPerformanceMode(true)
					print(
						string.format(
							"[AutoPerformance] khung hình trung vị %.1fms (<%d fps) — TỰ BẬT Performance Mode",
							median * 1000,
							math.floor(1 / BAD_FRAME_SECONDS)
						)
					)
				end
			end
		elseif autoEnabled and goodWindows >= WINDOWS_BEFORE_UPGRADE then
			goodWindows = 0
			autoEnabled = false
			ClientSettingsController.SetPerformanceMode(false)
			print(
				string.format(
					"[AutoPerformance] khung hình trung vị %.1fms — máy đã thoải mái, TẮT Performance Mode",
					median * 1000
				)
			)
		end
	end)

	Log.Boot(
		if SUGGEST_ONLY
			then "[AutoPerformance] đang theo dõi khung hình — ĐỀ NGHỊ (không tự bật) nếu tụt dưới 50 fps"
			else "[AutoPerformance] đang theo dõi khung hình — tự hạ hiệu ứng nếu tụt dưới 50 fps"
	)
end

-- Giữ tham chiếu cho các controller khác cần biết trạng thái (HUD hiển thị chẳng hạn).
function AutoPerformanceController.IsAuto(): boolean
	return autoEnabled
end

AutoPerformanceController.LocalPlayer = Players.LocalPlayer

return AutoPerformanceController
