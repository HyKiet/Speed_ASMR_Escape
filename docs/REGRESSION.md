# Regression Checklist — chạy TRƯỚC MỖI LẦN publish lên Live

> Nguyên tắc: chạy **toàn bộ** checklist, kể cả phần release này không đụng tới.
> Bug thật hay nằm ở chỗ không ai nghĩ là mình đã động vào.

**Ký hiệu**

| | Nghĩa |
|---|---|
| 🤖 | Máy tự kiểm — CI hoặc script chạy, không cần người ngồi |
| 👤 | Bắt buộc người thật bấm — không giả lập được |
| ⏱ | Ước lượng thời gian |

**Ba môi trường**

| | Place | PlaceId |
|---|---|---|
| Dev | Studio trên máy | — |
| QA | `[QA] SpeedEscape` | `76318425379626` |
| Live | `+1 Speed ASMR Escape` | `94107323826144` |

Cùng UniverseId `10456737957` ⇒ **dùng chung gamepass/product** (test mua thật được) nhưng
**tách DataStore** qua `Shared/Util/Env.luau` (QA và Studio ghi vào bể `QA_*`).

---

## Quy trình release

```
1. Code trong VSCode        →  Rojo sync  →  test nhanh trong Studio
2. Push lên GitHub          →  CI xanh (mục A dưới đây)   ← không xanh thì DỪNG
3. Publish lên place QA     →  chạy mục B + C trong QA     ⏱ ~35 phút
4. Publish lên place Live   →  chạy mục D (smoke test)     ⏱ ~5 phút
```

⚠️ Bước 3 → 4: publish sang Live phải là **đúng file .rbxlx đã test ở QA**, không sửa
thêm dòng nào ở giữa. Sửa gì thêm thì quay lại bước 2.

---

## A. Máy tự chạy — CI (🤖, ⏱ 0 phút của bạn)

Đẩy code lên GitHub là `.github/workflows/ci.yml` tự chạy. Tất cả phải xanh:

- [ ] 🤖 `rojo build` thành công — place dựng được từ source
- [ ] 🤖 `selene` không có error (warning được phép)
- [ ] 🤖 `luau-lsp analyze` không vượt baseline trong `tests/luau-lsp-baseline.txt`
- [ ] 🤖 `lune run tests/run.luau` — 52 test logic thuần đều đạt
- [ ] 🤖 StyLua (không chặn) — xem có file nào mới lệch format không

Chạy tay tại máy trước khi push:

```bash
rojo build default.project.json -o build-test.rbxlx
selene --allow-warnings src
lune run tests/run.luau
```

---

## B. Trong QA — phần máy kiểm được (🤖 qua MCP, ⏱ ~10 phút)

- [ ] 🤖 Console sạch khi khởi động: có `--- [SERVER READY] ---` và khối `[CLIENT LOADING]`
      báo **đủ 59 controller**. Thiếu số = có controller chết câm.
- [ ] 🤖 `[Telemetry] Đang chạy ở môi trường QA.` — sai môi trường ở đây nghĩa là
      `Env.luau` đọc nhầm PlaceId, DataStore sẽ ghi nhầm bể.
- [ ] 🤖 Mỗi sàn ASMR in đúng dòng `[ASMR <tên>] sẵn sàng — …`. Sàn nào không in
      dòng nào là sàn đó hỏng init và sẽ câm vĩnh viễn.
- [ ] 🤖 Không có warn `[SERVER ERROR]` / `[CLIENT ERROR]` nào trong 60s đầu
- [ ] 🤖 Mở lần lượt 7 modal (Shop, Rebirth, Cosmetic, Teleport, Code, Revive, Roulette):
      hiện đúng, đóng được, không kẹt overlay
- [ ] 🤖 FPS ≥ 30 và memory không tăng đều sau 5 phút đứng yên ở lobby
- [ ] 🤖 Số liệu khớp công thức: `Speed` sau 10 tick treadmill = `10 × step × multiplier`

---

## C. Trong QA — phần bắt buộc người thật (👤, ⏱ ~25 phút)

### C1. Core loop
- [ ] 👤 Đứng lên treadmill → Speed tăng đều, HUD nhảy số, thanh XP chạy
- [ ] 👤 Lên level → nhận Wins thưởng, WalkSpeed tăng theo
- [ ] 👤 Chạy hết Stage 1 → chạm vạch Finish → nhận đúng số Wins trong `Stages.STAGE_WINS`
- [ ] 👤 Chết ở giữa obby → respawn đúng checkpoint gần nhất, không mất tiến trình
- [ ] 👤 Vạch Start/Finish vẫn ăn `Touched` (lý do đây là mục 👤: teleport bằng
      server không sinh Touched đáng tin — phải chạy chân qua)

### C2. Rebirth
- [ ] 👤 Rebirth thủ công ở Lv50 → Speed/Level về 0, Rebirths +1, multiplier áp NGAY
- [ ] 👤 Auto-Rebirth (nếu sở hữu pass) → tự trùng sinh đúng lúc đủ level, không kẹt vòng lặp
- [ ] 👤 Skip Rebirth (dev product) → trùng sinh không cần đủ level

### C3. Tiền thật — **không thể giả lập**
- [ ] 👤 Mua 1 gamepass bằng Robux thật → multiplier áp dụng **ngay**, không cần rejoin
- [ ] 👤 Mua 1 dev product (Wins Pack) → `ProcessReceipt` trả `PurchaseGranted`, Wins vào tài khoản
- [ ] 👤 Huỷ giữa chừng hộp thoại mua → không mất Robux, không cộng nhầm
- [ ] 👤 Giá hiển thị trên UI khớp giá thật trên Creator Dashboard

### C4. Lưu dữ liệu — **cần thoát hẳn rồi vào lại**
- [ ] 👤 Farm một ít Speed → rời game → vào lại: số liệu còn nguyên
- [ ] 👤 Mua cosmetic → rời game → vào lại: vẫn sở hữu và vẫn đang trang bị
- [ ] 👤 Vào bằng 2 thiết bị cùng lúc → ProfileStore session lock chặn, không mất data

### C5. Nhiều người
- [ ] 👤 2 người cùng chạm 1 checkpoint → cả hai đều được tính
- [ ] 👤 Leaderboard 3 bảng (Speed / Wins / Donate) hiện tên + avatar đúng
- [ ] 👤 Server Boost / Group Chest kích hoạt → mọi người trong server đều thấy

### C6. Cosmetic & phụ trợ
- [ ] 👤 Trang bị trail → nhìn thấy trail khi chạy; đổi sang trail khác → đổi đúng
- [ ] 👤 Trang bị aura → hạt bay quanh người, tắt đi thì biến mất sạch
- [ ] 👤 Nhập promo code hợp lệ → nhận thưởng; nhập lại lần 2 → bị từ chối
- [ ] 👤 Roulette: quay 1 vòng → trúng đúng ô mà kim chỉ, phần thưởng vào tài khoản
- [ ] 👤 Teleport tới từng zone → tới đúng nơi, không rơi khỏi map
- [ ] 👤 Topbar: Ẩn UI / Cài đặt / Performance mode / Night mode đều đổi đúng

### C7. Anti-cheat
- [ ] 👤 Chạy bình thường qua zone 12/13/14 (gió, lò xo, quạt) → **không** bị giật ngược oan
- [ ] 👤 Wall run + slide ở tốc độ cao → không bị phạt oan

---

## D. Sau khi lên Live — smoke test (👤, ⏱ ~5 phút)

Chạy ngay sau khi publish, trước khi đi ngủ:

- [ ] 👤 Vào Live bằng tài khoản chính → nhân vật spawn, HUD hiện đủ
- [ ] 👤 Data cũ của mình còn nguyên (đây là phép thử quan trọng nhất: nếu `Env.luau`
      sai thì mất sạch dữ liệu Live, và sẽ thấy ngay ở bước này)
- [ ] 👤 Farm 10 giây trên treadmill → Speed tăng
- [ ] 👤 Leaderboard hiện dữ liệu **thật** (không phải bảng trống của QA)
- [ ] 👤 Mở Shop → giá Robux hiển thị đúng
- [ ] 👤 Creator Dashboard → Analytics: không có đỉnh lỗi mới sau 30 phút

Nếu bất kỳ mục nào hỏng → **rollback ngay** bằng Version History của place Live
(Creator Dashboard → Places → Version History → Restore), rồi mới ngồi tìm nguyên nhân.

---

## Ghi chú cho lần sau

Mỗi khi tìm ra một bug lọt lưới, thêm một dòng vào đây mô tả **cách phát hiện nó**.
Checklist chỉ có giá trị khi nó dài ra theo từng bug đã từng xảy ra.

| Ngày | Bug lọt lưới | Mục đã thêm |
|---|---|---|
| | | |
