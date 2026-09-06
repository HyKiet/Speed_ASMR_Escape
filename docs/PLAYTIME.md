# Playtime Sprint — giữ chân người chơi

**Mục tiêu:** average playtime 5,1 → **≥ 8 phút** · **Chốt 12/09/2026**
**Baseline đo 29/08/2026** · Gộp từ ba tài liệu chẩn đoán/đặc tả/bảng đo (05/09/2026)

Số cân bằng thuộc về Designer. Engineer đo và báo cáo, **không tự chỉnh** — kể cả khi thấy sai.

---

## 1. Chẩn đoán

### Vấn đề không nằm ở chỗ thu hút người chơi

$9,94 quảng cáo mua được 63.968 impression · CTR **3,79%** · 929 lượt chơi · CPP **$0,0107** —
đều ở top-decile Roblox Ads. Icon, thumbnail, tên game đang làm tốt việc của chúng.

> **Không đụng vào bất cứ thứ gì thuộc phần thu hút.** Đổi là mất baseline, mà baseline là thứ
> duy nhất cho phép đo các thay đổi khác.

### Phễu · 270 người

| Mốc | Còn lại | Mất |
|---|---:|---:|
| Spawn | 270 | — |
| 30s | 244 | −26 |
| 60s | 211 | −33 |
| 120s | 165 | −46 |
| **300s** | **77** | **−88** ← vách đá |
| 600s | 34 | −43 |

Roblox báo *"Biggest drop: Alive600s"* vì tính theo phần trăm. Sai trọng tâm: **bậc 300s mất 88
người, gấp đôi mọi bậc khác.**

| Phễu | Kết quả |
|---|---|
| `CoreLoop` | Spawn → Treadmill 70,74% → Rời 96,34% → StageClear 80,43% · **tổng 54,81%** |
| `Onboarding` | Join → FirstSpeedGain 96,69% → FirstStageClear 53,50% → **FirstRebirth 1,19%** |
| `FirstSession` | Còn sống ở phút 5: **46,67%** |

Hoàn thành trọn một vòng lặp **54,81%**, còn sống ở phút 5 **46,67%**. Hai con số trùng nhau, và
đó là toàn bộ câu chuyện:

> ### Người chơi chạy đúng MỘT vòng lặp rồi nghỉ.

Vòng lặp **không hỏng** — ai lên treadmill thì 96,34% rời được, 80,43% vượt được stage. Cái
thiếu là **lý do chạy vòng thứ hai**.

### Năm nguyên nhân

**A · Nhịp thưởng tự nhiên tắt đúng ở phút 2–5.** Đường cong XP là hàm mũ (`XP_ANCHOR_LEVEL 67`
· `XP_ANCHOR_REQUIRED 1.010.000` · growth `1,15842`), nên khoảng cách giữa hai lần level-up giãn
theo hàm mũ. **Đã đo, xác nhận** — ở tốc độ nền (treadmill x1 + pad_1, 2,86 Speed/giây):

| Level | 1 | 5 | **8** | 10 | 15 | 20 |
|---|---:|---:|---:|---:|---:|---:|
| Giây cho riêng bậc đó | 21,7 | 38,9 | **60,2** | 80,8 | 168,7 | 352,1 |

Nhịp thưởng vượt ngưỡng 60 giây tại **Level 8** và không bao giờ quay lại. Multiplier Pad có bù
(pad_3 nhanh gấp 5), nhưng pad mở theo ngưỡng Wins mà Wins chỉ đến từ vượt stage — với người mới,
pad kế tiếp luôn nằm sau vài lượt obby nữa.

**B · Tutorial hết ở phút 2.** `TutorialService` chạy Claim → Pad2 → Farm → Daily finale rồi
buông tay — đúng lúc nhịp tự nhiên bắt đầu tắt. Hai đường cong cùng chạm đáy một chỗ. Người chơi
không chán game; họ **chơi hết game**, bản dài 2 phút đã dựng.

**C · Món rẻ nhất đắt gấp 15 lần thu nhập phiên đầu.** Không phải "không thèm muốn" — là số học:

| | |
|---|---|
| Món Wins rẻ nhất | Blue Aura — **200 Wins** |
| Kiếm được sau Stage 1–3 | **14 Wins** |
| Đủ 200 Wins ở | **Stage 6** (cộng dồn 184) |

Dải giá dưới 200 Wins **hoàn toàn trống**. 17 lượt mua trên 871 người không phải thờ ơ — là
không với tới. Hệ quả: **Sinks/Sources = 2,3%**.

**D · `PlaytimeService` phục vụ tệp người chơi không tồn tại.** Bậc 20/40/60 phút, chỉ `return`
một multiplier, không ai gọi. **87,4% người chơi rời trước phút 10** — kể cả nối dây cũng không
chạm được ai.

**E · Không có gì cho người chơi cũ.** Bốn nguyên nhân trên đều nói về 10 phút đầu, nhưng đã có
người ở Level 31 / 874 Wins. Hai lỗ hổng cấu trúc:

- **Dải catalog hẹp hơn dải thu nhập 60 lần** — thu nhập trải 1 → 150.000 Wins (150.000×),
  catalog chỉ 200 → 500.000 (2.500×). Đây mới là nguyên nhân *cấu trúc* của Sinks/Sources 2,3%;
  nguyên nhân C chỉ là nửa dưới của cùng vấn đề.
- **Bức tường R8** — yêu cầu Level tăng +10 mỗi rebirth ⇒ chi phí XP `×4,35`, phần thưởng chỉ đi
  từ `1+0,5R` lên `1+0,5(R+1)`. **Chi phí hàm mũ, thưởng tuyến tính** — đường cong tự nó tiến tới
  một bức tường, và Max Level World 1 = 120 đặt bức tường đó đúng tại R8.
  **Quyết định 30/08: biến bức tường thành cửa — R8 là điều kiện mở World 2** (GDD §6, §9).

---

## 2. Nguyên tắc

> ### Luật 60 giây
> Trong **10 phút đầu**, người chơi không được đi quá 60 giây mà không có một **sự kiện phần
> thưởng nhìn thấy được**: level up, mở khoá, quest tick, vé quay, mốc.

Nguyên nhân A cho thấy game **từng** tuân luật này một cách tự nhiên, tới khoảng Level 8. Việc
của sprint là bắc một nhịp nhân tạo qua đúng chỗ nhịp tự nhiên tắt đi.

### Bốn ràng buộc bất di bất dịch

1. **Speed là xương sống, Wins bị siết.** GDD §8.A1/§8.C đã cố ý cắt Wins điểm danh 14.300 →
   1.177/tuần và gỡ toàn bộ Wins khỏi promo code — Wins cho phép nhảy cóc qua đoạn chơi mà đầu
   game được dựng ra để dạy. **Mọi phần thưởng mới mặc định là Speed + vé quay.**
2. **Không đụng cấu trúc bốn xô hệ số** (GDD §3.B). Xô Tiến trình (Rebirth) là xô **duy nhất
   nhân liên hoàn**.
3. **Chỉ nới, không nerf.**
4. **Không sửa phễu cũ.** Chỉ thêm bậc vào cuối, hoặc đăng ký phễu mới chạy song song.

---

## 3. Trạng thái thi hành

| | Việc | Chữa | Trạng thái |
|---|---|:---:|---|
| T0 | Bảng đo cân bằng | — | ✅ đo xong, kết quả ở §4 |
| T1 | **Quest Chain** 6 mắt xích tiếp quản khi tutorial buông tay | A · B | ✅ `QuestService` · `Quests.luau` · `QuestTracker` |
| T2 | **Emote bán bằng Wins**, thang 10 → 3.000.000 | C · E | ✅ `EmoteService` · `Economy/Emotes.luau` |
| T3 | **Tái nhịp rebirth** R1 từ Level 50 → 10 | FirstRebirth | ✅ `EARLY_REBIRTH_LEVELS = {10,20,32,46,62,80,100}` |
| T4 | **Gỡ `PlaytimeService`** | D | ✅ đã xoá |
| T5 | Banner "cái tiếp theo" sau Stage 1 | vách 120s | ⬜ **chưa làm** |
| T6 | Sửa dụng cụ đo | — | ✅ `CoreLoopV2` · `QuestChain` · mốc 900/1800s · đo 30s đầu |
| T7 | **Daily Quest** 3/ngày cho người chơi cũ | E | ✅ mở rộng `QuestService`, không dựng service thứ hai |
| T8 | Nút HUD Quest + Emotes | — | ✅ *lệch đặc tả:* Daily và Emotes chuyển lên hàng icon cạnh Spin, menu trái giữ 3 hàng thay vì lưới 2×4 |

`CORE_LOOP_VERSION = 4` — mọi thay đổi schema đã bump và có migration.

### T5 — việc duy nhất còn lại

Vượt Stage 1 → teleport về Lobby → **im lặng**. Thêm banner ngắn (dùng lại `Toast.luau` hoặc
pattern banner của `WinsFlight`) hiện ngay: Stage 2 thưởng bao nhiêu Wins, cần bao nhiêu
WalkSpeed, còn thiếu bao nhiêu. Rẻ, không đụng dữ liệu, rơi đúng giây ~90 — ngay trước bậc mất
46 người.

---

## 4. Bảng đo T0

Đo trên config tại thời điểm 30/08/2026. Script sinh bảng đã gỡ khỏi repo; muốn đo lại thì
đọc thẳng `Config/Formulas.luau` và `Config/Stages.luau`.

**Thời gian đạt mốc Level** (treadmill x1, pad mở dần theo Wins kiếm từ stage):

| Mốc | Level 10 | Level 20 | Level 32 |
|---|---:|---:|---:|
| Phút | **5,63** | 16,20 | 53,31 |

**Wins cộng dồn theo stage:**

| Stage | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---:|---:|---:|---:|---:|---:|
| Cộng dồn | 1 | 4 | **14** | 34 | 84 | **184** |

Hai bảng này khoá ba quyết định:

- Level 10 = 5,63 phút → nằm trong cổng 4–12 phút ⇒ **ngưỡng rebirth R1 = Level 10 hợp lệ**.
- Stage 3 = 14 Wins ⇒ **emote 10 Wins mua được trong phiên đầu**, rơi vào phút thứ 4.
- Stage 6 = 184 Wins ⇒ **emote 250 Wins nằm ngoài tầm với**, buộc phải cày thêm. Đó là chủ ý.

> **10 Wins không phải một cái giá — nó là học phí.** Nó dạy đúng một bài (*Wins mua được đồ*),
> trả đúng một lần, và không cần là sink. Bảng giá đầu tiên (10/25/50/100/300) đã bị bác: nó
> tối ưu cho lần mua đầu nên cả catalog chết trong 10 phút, và **làm Sinks/Sources tệ hơn** vì
> bơm thêm hàng vào dải giá đã bão hoà. Emote là hạng mục duy nhất định giá cao tuỳ ý được —
> vì nó **không mang hệ số**, là sink thuần tuý.

---

## 5. Cặp hằng số khoá nhau

Đụng một cái **phải kiểm cái kia**. Phá cặp cho ra ngõ cụt im lặng, không phải crash.

| Cặp | Vì sao |
|---|---|
| `STAGE_WINS[1]` ↔ `pad_2.requiredWins` ↔ vị trí Daily trong luồng | Bước 1 tutorial phải tự nuôi bước 2. Lệch = ngõ cụt "Need N Wins" |
| Giá emote khởi đầu (10) ↔ `STAGE_WINS[1..4]` | Món 10 Wins phải mua được sau Stage 3 |
| `Tuning.DEFAULT_WALK_SPEED` ↔ `StarterPlayer.CharacterWalkSpeed` (trong map) | Hai nguồn sự thật. Lệch = "hồi sinh xong đơ một nhịp" |
| `Tuning.BASE_MAX_WALK_SPEED` ↔ bề rộng hố của cả 15 zone | Tầm nhảy = WalkSpeed × 0,542s. Luật: hố ≤ tầm nhảy − 2 studs |
| `EARLY_REBIRTH_LEVELS[7]` ↔ `50 + (R−1)×10` | Bảng phải hội tụ đúng tại R8, nếu không gãy trần lạm phát cuối game |
| `EARLY_REBIRTH_LEVELS` ↔ nhịp tới World 2 | R8 mở World 2. Đổi bảng này là đổi thời điểm toàn bộ người chơi chạm nội dung cuối |

---

## 6. Đo lường & cổng nghiệm thu

Traffic tự nhiên **không tồn tại** — Home Recommendation 0, Charts 0, Search 1, Featured 0;
827/871 người đến từ Sponsored Ads. **Đo phải mua bằng tiền.**

| Ngân sách $90 còn lại | | |
|---|---:|---|
| 3 vòng đo × $5 | $15 | sau mỗi lần ship, đọc lại phễu |
| Dự trữ mở rộng | $75 | chỉ mở khi playtime ≥ 8 phút |

$5 ≈ 460 lượt chơi ở CPP $0,0107 — dư so với baseline 270 người. Không cần A/B, baseline đã đo.

> **Mỗi vòng đo giữ Y HỆT** campaign type, creative và daily budget như lần đầu. Đổi bất kỳ thứ
> nào là chất lượng traffic đổi theo và phép so mất giá trị.
>
> **Độ trễ:** Ads Manager gần thời gian thực · Dashboard ~1 ngày · **Funnels ~2 ngày**.
> **Ship xong đợi 3 ngày mới đọc phễu.** Đọc sớm hơn là tự lừa mình.

| Chỉ số | Baseline 29/08 | Cổng |
|---|---:|---:|
| Average playtime | 5,1 phút | **≥ 8 phút** |
| `Alive300s` | 46,67% | **≥ 65%** |
| `FirstRebirth` | 1,19% | **≥ 20%** |
| Sinks / Sources | 2,3% | **≥ 25%** |

**Qua ≥ 2/4 cổng ⇒ mở $75 mở rộng. Không qua cổng nào tính đến 12/09 ⇒ dừng, xem xét pivot.**

Tích phân đường cong sống sót hiện tại cho 5,2 phút — khớp con số 5,1 phút trên Watchlist, nên
mô hình đáng tin. Nếu `Alive300s` đi 28,5% → 45% và `Alive600s` 12,6% → 28% thì
**playtime ≈ 7,8 phút**: riêng việc lấp hố 2–5 phút đã gần chạm cổng. Không cần phép màu.
