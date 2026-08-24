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
local Log = require(ReplicatedStorage.Shared.Util.Log)

local AssetWarmController = {}

-- Chờ cho màn hình chờ + vòng nạp controller xong hẳn rồi mới bắt đầu.
local START_DELAY = 3
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
	end)
end

return AssetWarmController
