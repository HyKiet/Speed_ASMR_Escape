# Kế hoạch ra mắt — bản việc-cần-làm

> Cập nhật **2026-08-26**. Phân tích đầy đủ (tín hiệu thuật toán, số Ads Manager, nguồn) nằm ở
> `LAUNCH_PLAN_FULL.md`. File này chỉ liệt kê việc.

## Đổi so với bản 25/08

**Toàn bộ pre-flight đã xong và chiến dịch đầu tiên đã lên lịch.** Bước 2–4 của bản cũ (tick
thumbnail · Audience `Public` · publish) đều hoàn tất trong ngày 26/08. Chiến dịch
`01_PLAYS_thumb-test_0827_20usd` đang ở trạng thái **Scheduled**, chạy **00:00 ngày 27/08**.

**Cổng thanh toán Ad Credit đã thông.** Bản 25/08 coi đây là thứ có thể làm đứng cả bước 5–7
(Stripe từ chối thẻ, Google Play không mua được Ad Credit). Chiến dịch tạo được ⇒ nút thắt này
đã gỡ. Không cần đường vòng nào nữa.

**Đánh số lại theo đúng tên chiến dịch trong Ads Manager.** File này giờ gọi ba đợt là
GĐ 1 / 2 / 3 khớp tiền tố `01_` `02_` `03_`. `LAUNCH_PLAN_FULL.md` viết trước nên đánh số lệch
một nấc (GĐ 2 / 3a / 3b) — cùng ba đợt, chỉ khác tên. **Số credit và ngưỡng lấy theo file này**,
không lấy theo FULL: FULL viết khi ngân sách còn 75 credit, nay là 65.

**Ba lỗi đã sửa trong ngày 26/08** (chi tiết trong git log, tóm tắt ở đây vì đều ảnh hưởng tới
thứ người từ quảng cáo sẽ nhìn thấy):

- **Bảng Top Donate chưa từng chạy — không phải hỏng, mà là chưa bao giờ được nối dây.**
  `LeaderboardService.RecordDonation` không có một chỗ gọi nào trong toàn bộ `src/`. Nay móc vào
  `ReceiptService` (mọi developer product) + `GamepassService` (mọi gamepass — đường này không đi
  qua `ProcessReceipt` nên phải móc riêng). **Đã nghiệm thu trên Live**: mua X4 Speed → bảng lên
  đúng 9 (giá gross), không phải 6 (net sau chiết khấu 30%).
- **Pad 1 luôn sáng vàng** dù người chơi đã mở tới Pad 5. Hai nguyên nhân chồng nhau: lối vào khu
  pad bắt buộc giẫm qua Pad 1 nên `Touched` tự hạ người chơi về +1/step vĩnh viễn, và
  `Pad_1.PadPart` bị bake sẵn màu vàng trùng đúng màu ACTIVE trong map.
- **Chữ bảng xếp hạng to lên** (≤20px → ≤24px) — bảng để đọc từ xa vài chục stud.

Kèm theo: cắt `MultiplierPads` từ 11 xuống **8** cho khớp số pad thật trong map. Bản cũ tặng
không pad 9 (+1000/step) cho người ≥200k Wins từ một cái pad không tồn tại.

## Trạng thái tư cách publisher

Phí publish đã **Paid** (25/08). Đồng hồ `Highly engaged players` **0/250** đang chạy. Ngân sách
credit còn **65**.

`Current reach` là **Ages 16+ and trusted friends** — trần TẠM THỜI đúng thiết kế, không phải
lỗi: Content rating đã Minimal, `Group publishing reach` đã All ages, nhưng Kids & Select chỉ mở
sau khi chạm 250 highly engaged players. **Đừng đụng vào questionnaire để "sửa" con số này.**

```
2.000.000 ₫  −  1.000 R$ (≈304.000 ₫)  =  1.696.000 ₫  =  83,5 SGD
83,5 SGD ÷ 1,28 SGD/credit  ≈  65 credit  =  13 ngày chạy
```

Phí được hoàn sau 90 ngày kể từ khi game đủ tư cách Kids/Select (hoặc 90 ngày kể từ lúc trả nếu
không bao giờ đạt). Chỉ mất trắng nếu game bị gỡ vì kiểm duyệt. **Không có deadline nào ép lịch
chạy ads bên dưới** — đây là lý do được phép chừa ngày trống để chờ số liệu chắc.

## Đã xong

- [x] AntiCheat bật + nghiệm thu Zone 15
- [x] Vé quay chào mừng
- [x] Xác minh danh tính + 2FA
- [x] Content Maturity: **Minimal**, Descriptors **None**
- [x] Thumbnail: 3 ảnh ở Experience Detail Page + 3 ảnh ở Home Page
- [x] Nạp 1.000 R$ → **Refundable publishing fee: Paid** (25/08)
- [x] **Mua thật trên Live đã chạy** — X2 Speed 25/08, X4 Speed 26/08, quà vào tay
- [x] Tick Active đúng MỘT thumbnail ở tab Home Page
- [x] Audience `Limited` → **`Public`**
- [x] Publish bản mới
- [x] Gỡ được nút thắt thanh toán Ad Credit
- [x] Tạo chiến dịch GĐ 1, lịch 00:00 ngày 27/08
- [x] Nối dây bảng Top Donate + nghiệm thu bằng giao dịch thật
- [~] Video giới thiệu — đang under review, không chặn gì

## Việc còn lại, theo đúng thứ tự

### 0. Xác nhận bản đang Live đã gồm fix 26/08

⚠️ **Đây là mục duy nhất tôi không tự kiểm được từ máy, và nó có một phần dễ trượt.**

Ba fix code (Top Donate · pad · chữ bảng) đi theo Rojo nên chỉ cần publish là có. Nhưng fix màu
`Pad_1.PadPart` được sửa **trực tiếp trong Studio bằng MCP**, không nằm trong git — nó chỉ lên
Live nếu bạn đã **Save file trong Studio rồi mới publish**. Publish mà chưa save thì hai fix pad
sẽ lệch nhau: logic không còn hạ cấp nữa, nhưng Pad 1 vẫn vàng.

Cách kiểm nhanh trên Live: đứng cạnh khu pad, nhìn Pad 1 — phải là **xám-xanh** như 7 pad kia,
không phải vàng. Nếu còn vàng thì Save + publish lại.

Nếu đã xong: tick mục này và bỏ qua.

### 1. GĐ 1 — Plays, chốt thumbnail · 20 credit / 4 ngày · ĐANG CHẠY

Goal **Plays**, Audience **All players**, 3 ảnh 16:9. Bắt đầu 00:00 27/08, kết thúc 00:00 31/08.

- **Không tắt sớm.** 24h đầu là Learning. Số của ngày 1–2 không dùng để kết luận gì.
- **29/08** — chỉ liếc **Clicks vs Plays**. Từng có bug click cao / 0 play; lệch bất thường thì
  tắt ngay. Ngoài ô đó ra, ngày 29 không đọc gì khác.
- Mốc so sánh: CTR tham chiếu **3,63%**. Dưới ~2% là lỗi thumbnail, không phải lỗi ngân sách.

Bốn ô đã phải sửa khỏi mặc định của form — ghi lại để đối chiếu nếu về sau tạo chiến dịch mới:

| Ô | Mặc định form | Phải là | Vì sao |
|---|---|---|---|
| Daily budget | 16 | **5** | 16×4 = 64 credit, gần trọn ngân sách cho một đợt test |
| Duration | Run continuously | **4 ngày** (end date) | chạy liên tục = không có điểm dừng |
| Auto-Reload Ad Credit | ✅ bật | **tắt** | ô DUY NHẤT tiêu tiền thật thay vì credit |
| Image assets | 0/25 | **3 ảnh** | không có creative thì không có gì để so |

### 2. Chốt thumbnail thắng — 02/09, không phải 31/08

Ads Manager ghi rõ **"Some metrics may be delayed by up to 48 hours."** Plan đọc số ở ngày 3–4;
ngày 4 kết thúc 31/08 nên số của nó chỉ chắc chắn đầy đủ vào 01–02/09.

Nối GĐ 2 thẳng vào 31/08 nghĩa là chốt bằng dữ liệu ngày 3 — **đúng một ngày sạch** sau Learning,
một phần còn đang trễ. Mà lựa chọn này gánh **40/65 credit** còn lại: cả GĐ 2 lẫn GĐ 3 đều dùng
thumbnail thắng. Hai ngày trống không tốn credit nào và không có deadline nào ép (xem mục phí
hoàn 90 ngày ở trên) — đổi 2 ngày lấy một quyết định dựa trên số chắc là giá rẻ.

### 3. GĐ 2 — Engagement thăm dò · 15 credit / 3 ngày · bắt đầu 02–03/09

Goal **Engagement** — đây là loại chiến dịch **DUY NHẤT** đóng góp vào ngưỡng 250. Plays không
đóng góp một người nào, nên đừng nhìn số Plays của GĐ 1 mà mừng hay lo về mốc 250.

Dùng thumbnail thắng từ GĐ 1. Sau 24h: lại đối chiếu **Clicks vs Plays**.

Hết 3 ngày: đọc `Highly engaged players` ở Audience Reach, gọi **số tăng thêm** là **H**.

### 4. Cổng quyết định

Còn 45 credit cho Engagement, cần `3750 / H` credit để đủ 250:

| H sau 3 ngày | Nghĩa là | Quyết |
|---|---|---|
| **≥ 84** | ads đủ sức tới 250 | chạy tiếp GĐ 3 |
| **42 – 83** | ads lo ~một nửa | chạy tiếp, nửa còn lại trông vào traffic tự nhiên + TikTok |
| **< 42** | ads không mua nổi ngưỡng | **dừng**, giữ 30 credit, dồn sang mục 6 |

Hàng giữa **không phải thất bại**: ngưỡng 250 đếm cả người tới tự nhiên, ads không cần gánh hết.

### 5. GĐ 3 — Engagement đẩy · 25 credit / 5 ngày · chỉ khi cổng cho qua

Chiến dịch **không tự dừng** khi đạt ngưỡng — theo dõi Audience Reach và **tắt tay** khi chạm
250. Chừa 5 credit dự phòng để kéo dài đợt đang thắng.

### 6. Giữ bar 25 highly engaged players — vĩnh viễn

Vượt 250 không phải là xong; tụt dưới 25 là **mất tư cách**. Nhịp update hằng tuần trong
`LIVEOPS.md` chính là thứ giữ con số này, không phải credit.

## Lịch ngày

| Ngày | Việc | Ghi chú |
|---|---|---|
| 27/08 00:00 | GĐ 1 chạy | Learning 24h — không đọc, không tắt |
| 28/08 | GĐ 1 ngày 2 | vẫn Learning |
| 29/08 | GĐ 1 ngày 3 | chỉ kiểm Clicks vs Plays |
| 30/08 | GĐ 1 ngày 4 (cuối) | |
| 31/08 00:00 | GĐ 1 kết thúc | |
| 01/09 | Đọc số lần 1 | **chưa chốt** — số ngày cuối chưa settle |
| 02/09 | Chốt thumbnail thắng → tạo GĐ 2 | |
| 02–03/09 00:00 | **GĐ 2 chạy** | 15 credit / 3 ngày |
| 05–06/09 | GĐ 2 kết thúc → đọc **H** | |
| 06–07/09 | Cổng quyết định | |
| 07–08/09 | GĐ 3 (nếu qua cổng) | 25 credit / 5 ngày |
| 12–13/09 | GĐ 3 kết thúc | tắt tay nếu chạm 250 sớm hơn |

## Phân bổ

| Đợt | Credit | Ngày |
|---|---|---|
| GĐ 1 — Plays, chốt thumbnail | 20 | 4 |
| GĐ 2 — Engagement thăm dò | 15 | 3 |
| GĐ 3 — Engagement đẩy (có điều kiện) | 25 | 5 |
| Dự phòng | 5 | 1 |
| **Tổng** | **65** | **13** |

Ràng buộc Ads Manager: sàn 5 credit/ngày, tối thiểu 2 ngày/chiến dịch, 24h Learning —
**không đợt nào được ngắn hơn 3 ngày**.

## Hai điều đừng quên

**Tiền quảng cáo không mua được thứ hạng đề xuất.** Roblox loại toàn bộ engagement,
monetization và retention của *người dùng lần đầu đến từ ads*. Credit mua được đúng hai thứ:
dữ liệu creative, và tư cách Kids & Select.

**Đòn bẩy thật nằm ngoài 65 credit.** 17 loại sàn ASMR là khác biệt cấu trúc so với hàng nghìn
speed simulator, và là chất liệu lan tự nhiên mạnh nhất trên TikTok/Shorts. Thuật toán 2026 tính
tín hiệu **trung bình trên mỗi người** — game nhỏ mà người chơi ở lại sâu không hề bị thiệt.
