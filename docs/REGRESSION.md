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
| QA | `[QA] Speed ASMR Escape` | `134428972694212` |
| Live | `+1 Speed ASMR Escape` | `94107323826144` |

⚠️ **Sửa 2026-08-23:** bảng cũ ghi QA là `76318425379626` — place đó KHÔNG TỒN TẠI (Open Cloud
trả `No universe exists for place ID`). Số đúng là `134428972694212`.

Hai place nằm ở **hai universe riêng**: QA `10648253073`, Live `10456737957`. Vì vậy:
- **DataStore tách sẵn ở tầng Roblox**, không phụ thuộc code. Tiền tố `QA_` trong
  `Shared/Util/Env.luau` vẫn giữ làm lớp khoá thứ hai (bảo vệ Studio).
- **Gamepass/Dev Product KHÔNG dùng chung.** Ghi chú cũ "test mua thật được" không còn đúng.
  Toàn bộ pass/product nằm ở universe **Live**; dashboard của universe QA trống trơn (0 pass,
  0 product — kiểm 2026-08-23). Bán chúng trong QA là **cross-game sale**, thứ Roblox đã tắt
  từ **2026-05-29**, không ngoại lệ kể cả cùng chủ / cùng group.

  ⚠️ Bẫy khi test: hộp mua **vẫn hiện đúng tên và giá** trong QA (`GetProductInfo` tra được
  theo ID ở bất kỳ universe nào). Đừng lấy việc "thấy hộp mua" làm bằng chứng là mua được —
  chỗ bị chặn là bước thanh toán.

  Muốn nghiệm thu luồng Robux: kiểm trên **Live**, hoặc tạo bộ pass/product **riêng** cho
  universe QA rồi cho `Config/Economy` đọc ID theo `Env.Current`.

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
- [ ] 🤖 `luau-lsp analyze` không vượt baseline trong `.github/luau-lsp-baseline.txt`
- [ ] 🤖 StyLua (không chặn) — xem có file nào mới lệch format không

Chạy tay tại máy trước khi push:

```bash
rojo build default.project.json -o build-test.rbxlx
selene --allow-warnings src
```

---

## B. Trong QA — phần máy kiểm được (🤖 chạy script trong Command Bar, ⏱ ~10 phút)

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

### C7. Playtime Sprint
- [x] 🤖 Studio fresh-player: server/client bootstrap không có `[SERVER ERROR]` / `[CLIENT ERROR]`
- [x] 🤖 Playtime card, `SessionPlaytime` và multiplier biến mất khỏi HUD/snapshot/gain
- [x] 🤖 Bánh xe Emote mở bằng `G`; mua Inf Dab trừ đúng 10 Wins và ghi Sink
- [x] 🤖 Inf Dab chạy ở priority Action, dừng khi nhân vật bắt đầu di chuyển
- [x] 🤖 Skip tutorial mở Quest 1; tracker ẩn trong lúc Daily modal/finale còn hiện
- [ ] 👤 Chạy đủ Quest 1–6 trên profile mới; mỗi thưởng chỉ phát một lần sau rejoin
- [ ] 👤 Mua và chạy cả 5 emote trên PC + mobile; xác nhận cấm trong Obby
- [ ] 👤 Rebirth thủ công/Auto-Rebirth qua đủ bảng 10 · 20 · 32 · 46 · 62 · 80 · 100
- [ ] 👤 Điền Badge ID Quest 6, publish badge và xác nhận AwardBadgeAsync thành công
- [ ] 👤 Sau publish QA, xác nhận `CoreLoopV2`, `QuestChain`, `Alive900s/1800s` có dữ liệu

### C8. Anti-cheat
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
| 2026-09-08 | Timeout của lượt Roulette trước mở khoá lượt kế tiếp | Quay tiếp trước khi timeout 8s cũ hết; lượt mới phải giữ khoá cho tới kết quả hoặc timeout riêng. |
| 2026-09-08 | Stop controller bẫy vẫn để vòng dò streaming chạy | Start hai lần, Stop hai lần, rồi Start lại: chỉ một renderer và một vòng dò; Stop phải dọn cả hai. |
| 2026-09-08 | Cầu Jelly không nối lại sau khi map stream tới muộn | Để JellyBridge vắng hơn 20s, nạp lại rồi gỡ/nạp segment; animation trở lại, listener cũ được dọn và khối được trả hình gốc. |
| 2026-09-08 | WindShake mất cờ Initialized và bỏ sót listener từng lá | Lặp Init/Cleanup; kiểm connection, Settings, octree và CFrame về trạng thái ban đầu. |
| 2026-09-08 | Màn hình tải vượt trần khi CharacterAdded hoặc preload bị treo | Mô phỏng từng bước chờ không trả về; màn hình vẫn hết chờ sau trần hiện có và huỷ worker. |
| 2026-09-08 | Widget bị giữ trong sweeper/Observer sau khi Destroy | Dựng/huỷ 100 surface và sunburst; số owner và viewport listener phải trở về mốc đầu. |
| 2026-09-08 | SpeedWind dùng thuộc tính PitchRatio không tồn tại và nuốt lỗi init | Kiểm đủ audio node/Wire, dùng AudioPitchShifter.Pitch; Master phải điều khiển cả AudioPlayer của gió và sonic boom. |

### Các rủi ro còn mở sau audit source 2026-09-08

Các mục dưới đây chưa được nghiệm thu; build và lint xanh không xác nhận được chúng.

- [ ] `ReceiptService` chưa có lịch sử `PurchaseId` bền vững: kiểm receipt lặp và xử lý đồng thời
      giữa server, kể cả donation. Thiết kế lưu dấu giao hàng phải đi cùng giao thưởng; nếu thêm
      trường profile thì bump schema và có migration trước khi triển khai.
- [ ] Roulette đã trừ vé trước khoảng chờ animation nhưng chỉ giao thưởng nếu người chơi còn
      trong server. Kiểm rời game giữa hai bước và cơ chế khôi phục thưởng khi vào lại.
- [ ] Starter Pack đánh dấu đã mua trước chuỗi cấp thưởng có thể yield: kiểm lỗi giữa chuỗi,
      tránh vừa mất quyền nhận phần còn lại vừa cấp trùng phần đã nhận.
- [ ] Zone 5/6 còn có kiểm tra chết ở client. Đối chiếu hình học map thật và luồng server trước
      khi bổ sung kiểm chứng phía server; cần kiểm cả bỏ qua sát thương lẫn chết oan ở tốc độ cao.
- [ ] Chạy phần người thật ở C1–C8 trên bản QA đã publish; các fixture Studio/Lune của audit
      không thay thế kiểm mua Robux, rejoin, hai thiết bị, mobile và tải 25 người.
