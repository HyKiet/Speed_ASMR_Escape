--!strict
--[[
	AssetWarmController — tải trước mesh/texture nặng nhất của map, NGẦM, sau khi vào game.

	Lý do đầy đủ nằm ở `Shared/Config/PreloadManifest`. Tóm tắt: client thật bắt đầu với bộ nhớ
	trống, nên mỗi mesh/texture lần đầu lọt vào khung nhìn phải tải → giải mã → đẩy lên GPU, và
	bước cuối làm nghẽn luồng render vài ms. Đó là cái "khựng khi lia màn hình" mà Studio không
	bao giờ tái hiện (phiên Edit đã làm nóng sẵn toàn bộ map).

	══ BA QUYẾT ĐỊNH THIẾT KẾ, VÀ VÌ SAO ══════════════════════════════════════════════════════

	1. CHẠY SAU MÀN HÌNH CHỜ, KHÔNG PHẢI TRONG NÓ.
	   `LoadingScreen.client.luau` đã preload ảnh UI và nó CHẶN — mỗi asset thêm vào đó là màn
	   hình chờ dài thêm. Kéo dài màn hình chờ để đổi lấy vài ms mượt hơn là một cú đánh đổi
	   tồi: người chơi bỏ đi ở màn hình chờ, không bỏ đi vì một cú khựng.

	2. CHIA LÔ NHỎ + NGHỈ GIỮA CÁC LÔ.
	   `PreloadAsync` YIELD cho tới khi cả lô xong. Ném cả 20 asset vào một lời gọi là tự tạo
	   ra đúng cái cục nghẽn đang muốn tránh, chỉ dời nó sang chỗ khác. 3 cái một lô, nghỉ
	   0,4 s — tổng ~3 giây, trải mỏng, không khung hình nào cảm nhận được.

	3. `pcall` TỪNG LÔ.
	   `PreloadAsync` NÉM LỖI khi một asset hỏng/bị gỡ/không có quyền. Không bọc thì một ID
	   chết làm hỏng toàn bộ phần còn lại của danh sách — và im lặng, vì nó nằm trong task.spawn.

	⚠️ `PreloadAsync` chỉ tải BYTES. Lần vẽ đầu tiên của mesh vẫn phải đẩy lên GPU. Nó cắt được
	phần mạng + giải mã (phần lớn thời gian), không cắt được toàn bộ. Đây là bài học đã ghi ở
	`SoundPool` và `MovementAnimator` cho âm thanh/hoạt ảnh — mesh cũng vậy.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PreloadManifest = require(ReplicatedStorage.Shared.Config.PreloadManifest)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local AssetWarmController = {}

--[[
	`START_DELAY = 0` (đổi từ 3 ngày 2026-08-24).

	User báo: "vào game lag lúc đầu, chơi một chút thì mượt hơn." Đọc log thì thấy đúng ba
	giây trống đó là thủ phạm:
	    [LoadingScreen] xong sau 5.7s      ← người chơi bắt đầu chạy từ đây
	    [AssetWarm] … trong 3.1s            ← nhưng mới CHỜ 3s rồi mới bắt đầu tải
	Nghĩa là việc làm nóng rơi trúng giây thứ 3–6 của phiên — đúng lúc người chơi đang lia
	camera lần đầu và mọi mesh đều chưa lên GPU.

	Bỏ hẳn thời gian chờ thì việc tải bắt đầu NGAY khi controller Start, tức là vẫn còn đang
	ở sau màn hình chờ (`LoadingScreen` mất ~5,7 s, mà vòng nạp controller xong trước đó).
	Phần lớn công việc rơi vào lúc người chơi còn đang nhìn thanh tiến trình.

	⚠️ VẪN GIỮ chia lô + nghỉ giữa lô. Bỏ `START_DELAY` chỉ dời điểm BẮT ĐẦU sớm lên; nếu bỏ
	luôn `BATCH_GAP` thì lại tạo ra đúng cục nghẽn mà cả file này sinh ra để tránh — lúc đó
	nó nghẽn ngay giữa màn hình chờ, và thanh tiến trình đứng hình.

	Muốn triệt để hơn nữa thì phải kéo hẳn việc này VÀO TRONG `LoadingScreen` (màn chờ dài
	thêm ~3 s). Đó là đánh đổi với tỉ lệ bỏ game ở màn chờ — xem khối "BA QUYẾT ĐỊNH" ở trên,
	quyết định đó chưa đổi.
]]
local START_DELAY = 0
local BATCH_SIZE = 3
local BATCH_GAP = 0.4

function AssetWarmController.Init() end

function AssetWarmController.Start()
	task.spawn(function()
		task.wait(START_DELAY)

		local list = PreloadManifest.Hot
		local startedAt = os.clock()
		local failedBatches = 0

		for index = 1, #list, BATCH_SIZE do
			local batch: { string } = {}
			for offset = index, math.min(index + BATCH_SIZE - 1, #list) do
				table.insert(batch, list[offset])
			end

			local ok = pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)
			if not ok then
				failedBatches += 1
			end

			task.wait(BATCH_GAP)
		end

		Log.Boot(
			string.format(
				"[AssetWarm] đã làm nóng %d asset nặng nhất của map trong %.1fs (%d lô lỗi)",
				#list,
				os.clock() - startedAt,
				failedBatches
			)
		)
		GamePackets.earlySessionState.send({
			assetsLoaded = true,
			controlsTouched = false,
		})
	end)
end

return AssetWarmController
