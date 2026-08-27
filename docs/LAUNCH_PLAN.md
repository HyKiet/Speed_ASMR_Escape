# Kế hoạch ra mắt — bản việc-cần-làm

> Cập nhật **2026-08-27, 16h sau khi GĐ 1 chạy**. Phân tích cũ nằm ở `LAUNCH_PLAN_FULL.md`
> (viết khi ngân sách còn 75 credit — **số liệu lấy theo file này**, không lấy theo FULL).

## Đổi so với bản 26/08 — đọc mục này trước

Số liệu 16h đầu **lật ngược thứ tự ưu tiên của cả kế hoạch**. Ba thay đổi lớn:

1. **Quảng cáo không phải nút thắt. Giây thứ 50–100 mới là nút thắt.** CTR 4,99% (mốc tham
   chiếu 3,63%), 817 click, phễu vào game chạy tốt. Nhưng **2/3 người mới rời đi trong vòng
   90 giây**. Đây đúng là chỉ số mà thuật toán Roblox 2026 phạt nặng nhất.
2. **GĐ 1 rút từ 4 ngày xuống 2 ngày** — câu hỏi thumbnail đã có đáp án, chạy thêm không đổi
   được gì. Tiết kiệm **10 credit**.
3. **Chèn thêm một giai đoạn không tốn credit: "Sprint giữ chân"** (29/08 – 03/09), đặt TRƯỚC
   GĐ 2. Lý do ở mục [Vì sao không vào GĐ 2 cuối tuần này](#vì-sao-không-vào-gđ-2-cuối-tuần-này).

---

## Số liệu 16h đầu — cái nào là tín hiệu

### Đang chạy tốt

| Kiểm tra | Số thật | Kết |
|---|---|---|
| Giao hàng | $3,29 / 16h, mục tiêu $5/ngày | đúng nhịp |
| Kiểm duyệt creative | cả 3 `Learning`, không cái nào Rejected | ✅ |
| CTR vs mốc 3,63% | **4,99%** | vượt mốc |
| Click → vào game | 817 click → **418 người vào** ≈ **51%** | phễu **KHÔNG hỏng** |

**Ô `Plays` trống trong Ads Manager là độ trễ báo cáo, không phải số 0.** Trang ghi rõ
*"Some metrics may be delayed by up to 48 hours"* và ô hiện biểu tượng đồng hồ. Bằng chứng
độc lập: Funnels ghi **418 Total users**, trong khi `MAU tính đến 25/08 = 3`. 415 người đó
không thể là lịch sử cũ — họ tới từ quảng cáo.

> Cảnh báo "Clicks ≥ 20 mà Plays = 0 → tắt ngay" của bản trước **đã được gỡ**. Không tắt vì
> ô Plays trống; chỉ tắt khi Funnels cho thấy `Total users` không tăng.

### Phễu Onboarding (dữ liệu 27/08, 14:00)

| Bước | Người | Hoàn thành | Rơi |
|---|---|---|---|
| 1. Join | 418 | 100% | — |
| 2. FirstSpeedGain | 401 | 95,93% | 4,07% |
| **3. FirstStageClear** | **176** | **43,89%** | **56,11%** ⚠️ |
| 4. FirstRebirth | 5 | 2,84% | 97,16% |

Bước 2 gần như hoàn hảo — móc câu treadmill hoạt động. **Toàn bộ thiệt hại nằm ở bước 3.**

### Đường cong 5 phút đầu — chỗ này mới là gốc rễ

`New user first session retention`: **33,33% còn chơi sau 5 phút.**

Hình dạng đường cong quan trọng hơn con số:

```
100% ─────────┐                      ← giữ nguyên tới ~00:50
              │
              └──────────────────    ← rơi thẳng 00:50 → 01:40
 33%                                 ← rồi PHẲNG từ 01:40 tới 07:00
```

Đọc ra hai điều:

- **Ai qua được 90 giây thì ở lại ít nhất 7 phút.** Nội dung game giữ chân được — không phải
  game dở.
- **Nhưng 2/3 chết trong 90 giây đầu.** Một cái vách, không phải một con dốc.

### Vì sao server lúc nào cũng 2–3 người rồi trống

Đây là số học, không phải bug. Định luật Little: `CCU = nhịp người vào × thời lượng phiên`.

```
418 người / 14 giờ            = 29,9 người/giờ
phiên trung bình ≈ 0,67×1,25' + 0,33×7'  ≈ 3,15 phút
CCU = 29,9 × (3,15/60)        ≈ 1,6 người đồng thời
```

**≈1,6 người đồng thời, trải trên nhiều server MaxPlayers 12.** Ra đúng cái bạn nhìn thấy.
Không có gì hỏng cả.

Hai cách nâng CCU, và giá của chúng:

| Cách | Từ → đến | CCU | Giá |
|---|---|---|---|
| Tăng nhịp người vào | 30 → 120 người/giờ | 1,6 → 6,4 | **+60 credit** (không có) |
| Tăng thời lượng phiên | 3,1 → 12 phút | 1,6 → 6,0 | **0 credit** |

Cùng một kết quả. Một bên tốn cả ngân sách còn lại, một bên tốn công sửa game.

### Số xấu nhưng CHƯA được phép đọc

- `Average playtime 0,343 min` / `Average session time 0,263 min` — đây là **trung bình
  ngày trên 28 ngày**, bị pha loãng bởi ~26 ngày bằng 0. Điểm cuối thực tế trên biểu đồ
  là ~7–9 phút; thẻ Watchlist ghi 4,8 phút. Đừng dùng con số 0,343.
- `Day 1 retention 50%` · `Day 7 = 0%` · `Stickiness 3,57%` — cỡ mẫu vài người. Nhiễu.
- `Sessions 0` · `MAU by day 0` — dữ liệu trễ tới 25/08, trước khi có ads.

Mốc so sánh của Roblox (dải benchmark top 10.000 trên chính biểu đồ của bạn):
**Average session time ~15–19 phút**, **Average playtime ~25–32 phút**.

### Một phát hiện phụ: kinh tế trong game không có chỗ thoát

`Economy` (28 ngày): **Total Sources 191.885 Wins · Total Sinks `--`**. Ví trung bình
1.419 Wins. Không có một giao dịch tiêu nào được ghi nhận.

Và tỉ lệ đúc tiền lệch nặng:

| Nguồn | Giao dịch | Wins | Wins / lần |
|---|---|---|---|
| roulette | 61 | 126.175 | **2.068** |
| starterPack | 1 | 27.500 | 27.500 |
| stage | 592 | 37.581 | **63** |
| daily | 196 | 442 | 2,3 |

Một vòng quay bằng **33 lần vượt stage**. Vòng lặp lõi bị chính cái roulette làm cho vô
nghĩa. Chưa gấp bằng vách 90 giây, nhưng phải xử trước GĐ 3.

---

## Thuật toán đề xuất của Roblox — 2026

Phần này thay thế mục "Hai điều đừng quên" của bản cũ. Nguồn ở [cuối file](#nguồn).

### Hệ thống chạy hai tầng

- **Retrieval** — lọc ra tập game người dùng có thể thích, dựa trên engagement, retention,
  monetization.
- **Ranking** — xếp hạng cá nhân hoá trong tập đó.

### Tín hiệu, theo đúng thứ tự quan trọng Roblox công bố

**Quan trọng nhất:**

1. **Play through rate** — thấy đề xuất rồi có bấm vào chơi không.
2. **First play bounce rate** — ⚠️ **đo riêng ở mốc `< 60 giây` và `61–180 giây`**.
3. **Play days per user** và **playtime per user** — đo trên ba khung **D1**, **D2–7**,
   **D8–28**.

**Quan trọng:** intentional co-play days, qualified play sessions, spend days, Robux spent
per user.

### Ba điều quyết định cho game này

**a) Vách 90 giây rơi ĐÚNG vào hai rổ bounce rate.** Cú rơi 00:50 → 01:40 nằm vắt ngang cả
mốc `<60s` lẫn `61–180s`. Nghĩa là ngay lúc này, mỗi người quảng cáo đưa vào đang nạp cho
thuật toán đúng cái tín hiệu tiêu cực mà nó cân nặng nhất. **Đây là lý do kỹ thuật để sửa
trước rồi mới tiêu tiếp credit.**

**b) Tín hiệu tính TRUNG BÌNH TRÊN MỖI NGƯỜI, không tính tổng.** Game nhỏ không bị thiệt.
418 người ở lại sâu có giá trị hơn 4.180 người bật ra sau 30 giây. Điều này biến "sửa giữ
chân" thành đòn bẩy trực tiếp lên thứ hạng, chứ không chỉ lên CCU.

**c) Vòng "explore → expand" khởi động bằng CẬP NHẬT NỘI DUNG, không bằng quảng cáo.**
Roblox mô tả: sau một bản cập nhật, game được bơm một nhúm người mới (*explore*); nếu nhóm
đó engagement/monetization tốt thì được bơm tiếp nhóm lớn hơn (*expand*).

> Đây là cơ chế "được đề xuất tự nhiên" mà bạn hỏi. Nó **không mua được bằng credit** — nó
> được kích bằng nhịp ra bản cập nhật, và được nuôi bằng chất lượng cohort. Cửa sổ đánh giá
> đã nới từ 7 ngày lên **28 ngày**, nên đừng kỳ vọng thấy kết quả trong 2–3 ngày.

### Roblox nói thẳng nên làm gì

Bài DevForum chia hai nhánh:

- **Retention thấp** → dồn vào gameplay lõi: *"a great first session"*, *"a satisfying core
  loop"*, *"reasons to return"*.
- **Retention cao** → mới chuyển sang *"sustainable monetization"*.

Game này thuộc nhánh trên. Và: *"Games that are strong in both retention and monetization
may receive broader distribution. Games strong in only one area may see some changes to
their distribution."*

### Một điều bản cũ khẳng định mà tôi KHÔNG xác minh được

Bản 26/08 viết: *"Roblox loại toàn bộ engagement, monetization và retention của người dùng
lần đầu đến từ ads."*

Tôi **không tìm thấy khẳng định này trong tài liệu Discovery hiện hành** (08/2026). Có thể
đúng, có thể đã lỗi thời. Rủi ro lệch hẳn về một phía:

- Nếu **đúng** → chạy ads vào lúc bounce 67% chỉ là lãng phí credit.
- Nếu **sai** → chạy ads vào lúc bounce 67% đang **chủ động phá** tín hiệu xếp hạng.

Cả hai nhánh đều dẫn tới cùng một quyết định: **sửa vách 90 giây trước, tiêu credit sau.**

---

## Vì sao không vào GĐ 2 cuối tuần này

Bạn hỏi: cắt GĐ 1 xuống 2 ngày rồi vào GĐ 2 ngay thứ 7–CN này?

**Cắt GĐ 1: đồng ý. Vào GĐ 2 cuối tuần này: không.**

**Cắt GĐ 1 — câu hỏi thumbnail đã có đáp án rồi.** Khoảng tin cậy 95% của ba ảnh chồng lên
nhau gần hết, và cả ba đều trên mốc tham chiếu:

| Ảnh | Impressions | Clicks | CTR | Khoảng tin cậy 95% |
|---|---|---|---|---|
| #1 | 12.960 | 645 | 4,98% | 4,60 – 5,35% |
| #2 | 2.041 | 99 | 4,85% | 3,92 – 5,78% |
| #3 | 1.367 | 73 | 5,34% | 4,15 – 6,53% |

Thêm hai ngày nữa cũng không tách được ba khoảng này, vì bộ tối ưu đã dồn **79% impression
vào ảnh #1** và sẽ tiếp tục bỏ đói #2/#3. Kết luận đúng: **cả ba đều đạt, CTR không phải nút
thắt** → lấy ảnh #1 (nhiều dữ liệu nhất, đang được ưu tiên). Cắt cuối ngày 2 tiết kiệm
**~10 credit**.

**Không vào GĐ 2 ngay, vì GĐ 2 mua "highly engaged players".** Theo định nghĩa là người
**ở lại**. Bơm 15 credit vào một cái phễu đang mất 2/3 người trong 90 giây = mua đúng món
đó với giá gấp ba. Sửa xong rồi mua thì mỗi credit mang về nhiều hơn hẳn.

**Và không có deadline nào ép.** Phí publish hoàn sau 90 ngày kể từ khi đủ tư cách, hoặc
90 ngày kể từ lúc trả nếu không bao giờ đạt (chỉ mất trắng nếu game bị gỡ vì kiểm duyệt).
Chờ một tuần không mất gì.

**Cuối tuần vẫn là thời điểm đúng — chỉ là cuối tuần SAU.** Traffic Roblox đỉnh vào thứ 6–CN,
nên GĐ 2 nên rơi vào **05–07/09**. Trùng luôn với lịch cũ.

**Cắt GĐ 1 còn hạ thấp chính cái cổng quyết định** — xem [mục 5](#5-cổng-quyết-định).

---

## Trạng thái tư cách publisher

Phí publish đã **Paid** (25/08). Đồng hồ `Highly engaged players` **0/250** đang chạy.

`Current reach` là **Ages 16+ and trusted friends** — trần TẠM THỜI đúng thiết kế, không phải
lỗi: Content rating đã Minimal, `Group publishing reach` đã All ages, nhưng Kids & Select chỉ
mở sau khi chạm 250 highly engaged players. **Đừng đụng vào questionnaire để "sửa" con số này.**

```
2.000.000 ₫  −  1.000 R$ (≈304.000 ₫)  =  1.696.000 ₫  =  83,5 SGD
83,5 SGD ÷ 1,28 SGD/credit  ≈  65 credit
```

---

## Đã xong

- [x] AntiCheat bật + nghiệm thu Zone 15
- [x] Vé quay chào mừng
- [x] Xác minh danh tính + 2FA
- [x] Content Maturity: **Minimal**, Descriptors **None**
- [x] Thumbnail: 3 ảnh Experience Detail Page + 3 ảnh Home Page
- [x] Nạp 1.000 R$ → **Refundable publishing fee: Paid** (25/08)
- [x] **Mua thật trên Live đã chạy** — X2 Speed 25/08, X4 Speed 26/08
- [x] Audience `Limited` → **`Public`**
- [x] Gỡ nút thắt thanh toán Ad Credit
- [x] Nối dây bảng Top Donate + nghiệm thu bằng giao dịch thật
- [x] GĐ 1 chạy, phễu xác nhận hoạt động (418 người vào)
- [~] Video giới thiệu — under review, không chặn gì

---

## Việc còn lại, theo đúng thứ tự

### 1. GĐ 1 — cắt xuống 2 ngày · ~10 credit · ĐANG CHẠY

**Tắt vào 00:00 ngày 29/08** (hết ngày 2). Trước khi tắt, lưu lại: Spent · Impressions ·
CTR · Clicks của từng creative, và `Total users` ở Funnels.

Chốt **ảnh #1** làm thumbnail cho GĐ 2 và GĐ 3.

Trong lúc còn chạy, mỗi ngày một lần: **Funnels → đặt khoảng ngày = HÔM NAY**, đọc
`Total users`. Đó là ô duy nhất không bị trễ 48h. Chỉ tắt sớm nếu ô đó đứng yên.

### 2. ⭐ Sprint giữ chân — 29/08 → 03/09 · 0 credit

**Đây là việc quan trọng nhất trong toàn bộ kế hoạch.** Mục tiêu duy nhất:

> Kéo `New user first session retention @ 5 phút` từ **33%** lên **≥ 50%**.

Ba thứ đáng nghi, xếp theo mức độ chắc chắn:

**a) `DEFAULT_WALK_SPEED = 6` — nghi phạm số một.**
`src/shared/Config/Tuning.luau:8`. Mặc định của Roblox là **16**. Người mới sinh ra chậm hơn
**2,7 lần** mọi game họ từng chơi, và trần Level 1 (`BASE_MAX_WALK_SPEED = 12`) vẫn dưới 16.
Ấn tượng đầu tiên trong 10 giây đầu là lội bùn. Khớp hoàn hảo với vách 50–100 giây.

*Chưa kiểm chứng — đây là giả thuyết, phải đo.* Cách đo: nâng tốc độ xuất phát, publish,
so `New user first session retention` của cohort trước/sau.

**b) Khoảng trống giữa "có speed" và "vượt stage 1".**
95,9% đạt FirstSpeedGain nhưng chỉ 43,9% clear stage 1. `STAGE_GATES[1]` chỉ là
`minWS = 12` và **không chặn ai** (`Stages.luau`) — nên không phải bị khoá, mà là **bỏ cuộc
giữa chừng**. Cần bấm giờ: từ lúc spawn tới lúc clear stage 1 mất bao lâu? Nếu > 90 giây thì
đó chính là vách.

**c) 60 giây đầu không có mục tiêu nào rõ ràng.** Roblox gọi thẳng là *"a great first
session"*. Kiểm bằng chính mắt: tạo tài khoản mới, vào game, bấm giờ — trong 30 giây đầu có
biết phải làm gì không?

**Cổng ra của sprint:** publish xong, chờ **2 ngày** để cohort mới đủ chín, rồi đọc lại
`New user first session retention`. Chưa chạm 50% thì **hoãn GĐ 2 tiếp** — credit không mất
đi đâu cả.

### 3. Nhịp cập nhật — bắt đầu từ tuần này, vĩnh viễn

Vòng *explore → expand* kích bằng **cập nhật nội dung**. Mỗi bản update là một lần xin
Roblox bơm thử một nhóm người mới. Nhịp đều đặn hằng tuần đáng giá hơn nhiều so với một bản
lớn mỗi tháng — và nó là thứ giữ bar 25 highly engaged sau này.

Ghi vào `LIVEOPS.md`. Publish bằng **Restart Servers** trên Creator Dashboard
(Configure → Server Management), bật *"restart only outdated servers"* + delay 5–10 phút.

### 4. GĐ 2 — Engagement thăm dò · 15 credit / 3 ngày · **05–07/09**

Goal **Engagement** — loại chiến dịch **DUY NHẤT** đóng góp vào ngưỡng 250. Plays không
đóng góp một người nào, nên đừng nhìn số Plays của GĐ 1 mà mừng hay lo về mốc 250.

Dùng thumbnail #1. Rơi vào cuối tuần (đỉnh traffic Roblox) là cố ý.

**Chỉ chạy nếu cổng ra của sprint đã qua.**

### 5. Cổng quyết định — đọc H vào **09–10/09**, KHÔNG phải 07/09

> ⚠️ **Sửa lỗi của bản cũ.** Ô `Highly engaged players` ghi *"Last updated 8/25/2026"* trong
> khi hôm đó là 27/08 — **trễ 2 ngày**. Đọc H ngay khi GĐ 2 kết thúc sẽ lấy phải số của 2
> ngày trước ⇒ H bị hụt ⇒ rơi nhầm xuống hàng dưới ⇒ **dừng oan, bỏ phí 30 credit**.

Gọi **H** = số `Highly engaged players` tăng thêm nhờ GĐ 2.

Vì GĐ 1 chỉ tiêu 10 thay vì 20, còn **55 credit** thay vì 45. Cần `3750 / H` credit để đủ 250:

| H sau 3 ngày | Nghĩa là | Quyết |
|---|---|---|
| **≥ 69** | ads đủ sức tới 250 | chạy tiếp GĐ 3 |
| **34 – 68** | ads lo ~một nửa | chạy tiếp, nửa còn lại trông vào tự nhiên + TikTok |
| **< 34** | ads không mua nổi ngưỡng | **dừng**, giữ 30 credit, dồn sang mục 7 |

Hàng giữa **không phải thất bại**: ngưỡng 250 đếm cả người tới tự nhiên.

*(Bản cũ đặt ngưỡng ≥84 / 42–83 / <42 khi chỉ còn 45 credit. Cắt GĐ 1 hạ cả ba mốc xuống.)*

### 6. GĐ 3 — Engagement đẩy · 25 credit / 5 ngày · **10–15/09** · chỉ khi cổng cho qua

Chiến dịch **không tự dừng** khi đạt ngưỡng — theo dõi Audience Reach và **tắt tay** khi
chạm 250. Chừa 5 credit dự phòng để kéo dài đợt đang thắng.

Trước GĐ 3, xử lý chỗ rò kinh tế: **roulette đúc 2.068 Wins/lần so với 63 Wins/stage**, và
**Total Sinks đang là `--`** (hoặc không có ai tiêu, hoặc chưa gắn đo). Kiểm cái nào trước
đã — nếu chưa gắn đo thì `spend days` và `Robux spent per user` của thuật toán cũng đang
trống.

### 7. Giữ bar 25 highly engaged players — vĩnh viễn

Vượt 250 không phải là xong; tụt dưới 25 là **mất tư cách**. Nhịp update ở mục 3 chính là
thứ giữ con số này, không phải credit.

---

## Lịch ngày

| Ngày | Việc | Ghi chú |
|---|---|---|
| 27/08 | GĐ 1 ngày 1 | ✅ phễu xác nhận chạy, 418 người vào |
| 28/08 | GĐ 1 ngày 2 | ghi lại số từng creative |
| **29/08 00:00** | **Tắt GĐ 1**, chốt ảnh #1 | tiết kiệm ~10 credit |
| 29/08 – 02/09 | ⭐ **Sprint giữ chân** | 0 credit — việc quan trọng nhất |
| 02/09 | Publish bản sửa | + Restart Servers |
| 03–04/09 | Chờ cohort chín | **không đọc số sớm** |
| 04/09 | Đọc `first session retention` | cổng ra: **≥ 50%** |
| **05–07/09** | **GĐ 2 chạy** — nếu qua cổng | 15 credit / 3 ngày, trúng cuối tuần |
| **09–10/09** | Đọc **H** | +2 ngày bù độ trễ ô Audience Reach |
| 10/09 | Cổng quyết định | |
| 10–15/09 | GĐ 3 (nếu qua cổng) | 25 credit / 5 ngày |

## Phân bổ

| Đợt | Credit | Ngày |
|---|---|---|
| GĐ 1 — Plays, chốt thumbnail (đã cắt) | 10 | 2 |
| **Sprint giữ chân** | **0** | **5** |
| GĐ 2 — Engagement thăm dò | 15 | 3 |
| GĐ 3 — Engagement đẩy (có điều kiện) | 25 | 5 |
| Dự phòng | 5 | 1 |
| **Tổng** | **55 / 65** | |

Ràng buộc Ads Manager: sàn 5 credit/ngày, tối thiểu 2 ngày/chiến dịch, 24h Learning —
**không đợt nào được ngắn hơn 2 ngày**.

Bốn ô phải sửa khỏi mặc định của form, ghi lại để dùng khi tạo GĐ 2:

| Ô | Mặc định form | Phải là | Vì sao |
|---|---|---|---|
| Daily budget | 16 | **5** | 16×n ngốn gần trọn ngân sách |
| Duration | Run continuously | **end date** | chạy liên tục = không có điểm dừng |
| Auto-Reload Ad Credit | ✅ bật | **tắt** | ô DUY NHẤT tiêu tiền thật thay vì credit |
| Image assets | 0/25 | **ảnh #1** | GĐ 2/3 không A/B nữa |

---

## Ba câu chốt

**Tiền quảng cáo không mua được thứ hạng đề xuất.** Vòng *explore → expand* kích bằng cập
nhật nội dung và được nuôi bằng chất lượng cohort. Credit mua được đúng hai thứ: dữ liệu
creative, và tư cách Kids & Select.

**Tín hiệu tính trung bình trên mỗi người.** Game nhỏ mà người chơi ở lại sâu không hề bị
thiệt. Đây là lý do 90 giây đầu đáng giá hơn cả 55 credit còn lại.

**Đòn bẩy thật nằm ngoài credit.** 17 loại sàn ASMR là khác biệt cấu trúc so với hàng nghìn
speed simulator, và là chất liệu lan tự nhiên mạnh nhất trên TikTok/Shorts.

---

## Nguồn

Tất cả truy cập 27/08/2026.

- [Boost your discovery by building games people want to play — DevForum](https://devforum.roblox.com/t/boost-your-discovery-by-building-games-people-want-to-play/4779042)
  — bốn yếu tố ảnh hưởng impression; hai nhánh retention thấp/cao; câu *"Games that are
  strong in both retention and monetization may receive broader distribution."*
- [Discovery — Roblox Creator Documentation](https://create.roblox.com/docs/discovery)
  — hai tầng Retrieval/Ranking; **danh sách tín hiệu theo thứ tự quan trọng**; định nghĩa
  qualified play; cơ chế explore → expand. Nguồn quan trọng nhất trong danh sách này.
- [Optimizing Discovery: How Great Games Reach Millions of Players on Roblox — Roblox Newsroom, 06/2026](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)
  — nới cửa sổ 7 → 28 ngày; tách `qualified play-through rate` thành play-through behavior /
  session quality / spend; ba khung D1, D2–7, D8–28.
- [First play bounce rate question — DevForum, 07/2026](https://devforum.roblox.com/t/first-play-bounce-rate-question/4743249)
  — quan hệ giữa tụt impression và tăng bounce rate.
- [Analytics Dashboard — Roblox Creator Documentation](https://create.roblox.com/docs/production/analytics/analytics-dashboard)
  — cách đọc dải benchmark (phân vị 50–90 của game cùng tệp người chơi).
