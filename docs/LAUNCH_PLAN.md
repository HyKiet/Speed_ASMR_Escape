# Kế hoạch ra mắt — +1 Speed ASMR Escape

> Chốt 2026-08-13 · **Cập nhật 2026-08-24** (số liệu Ads Manager thật + phí publish được miễn).
> Bản trình bày: https://claude.ai/code/artifact/bcb5d0d1-c173-46e7-bbbd-aa5d46edca7f
>
> Vốn: **2.000.000 ₫** · Cửa sổ: **60 ngày**

---

## 0. Đổi gì trong bản 2026-08-24

| Đổi | Vì sao |
|---|---|
| Ngân sách **65 → ~75 Ad Credit** | Creator Hub báo *Refundable publishing fee: **Exempt** — No payment required with active subscription*. Khoản 1.000 R$ (~304.000 ₫) không còn phải trả ⇒ dồn hết vào credit |
| Thêm mục 7: **Plays hay Engagement** | Trả lời dứt điểm bằng số thật, kèm chỗ bài devlog đọc sai |
| GĐ 3 đổi từ "hai đợt cố định" sang **thăm dò rồi ngoại suy** | Chi phí mỗi highly engaged player là ẩn số. Đặt cược 40 credit vào một con số chưa ai đo là sai quy trình |
| GĐ 0 cập nhật theo tình trạng code thật | AntiCheat đã bật rồi; hai mục kia thì **chưa** làm — xem mục 9 |
| Mục 3 nói rõ hơn | Traffic quảng cáo bị loại khỏi tín hiệu, **nhưng** người do ads mang về mà hôm sau tự quay lại qua Home thì có tính |

---

## 1. Ba thay đổi của Roblox đang chi phối kế hoạch này

| Mốc | Thay đổi |
|---|---|
| 06/2026 | Recommended For You mở từ 7 ngày lên **28 ngày**, chia theo Ngày 1 · Ngày 2–7 · Ngày 8–28. Chỉ số qPTR bị tách đôi thành **PTR** và **first-play bounce rate** (tín hiệu âm). |
| 06/08/2026 | Roblox thử nghiệm bản Home recommendations mới, dự kiến áp dụng **cuối tháng 8 / đầu tháng 9/2026**. Lần đầu **kiếm tiền được đặt ngang hàng với giữ chân**. |
| Đang áp dụng | **Roblox Kids & Select** — phân phối cho người dùng dưới 16 tuổi phải qua xét duyệt. Với speed simulator, đây là phần lớn thị trường. |

Thêm một điểm của bản 06/2026 mà kế hoạch cũ chưa ghi: **mọi tín hiệu đều tính TRUNG BÌNH TRÊN MỖI NGƯỜI, không phải tổng.** Game nhỏ mà người chơi gắn bó không bị thiệt so với game to. Đây là tin tốt cho một game solo: bạn không cần đông, bạn cần *sâu*.

## 2. Bảng tín hiệu chính thức

**Quan trọng nhất**
- Play-through rate — icon/thumbnail, thấy rồi có bấm không
- First-play bounce rate — tín hiệu **âm**, vào rồi thoát ngay
- Play days / user — đo ở cả ba mốc D1 · D2–7 · D8–28
- Playtime / user — **trần 60 phút/ngày**, cày quá không tính thêm

**Quan trọng**
- Intentional co-play days — rủ bạn cùng chơi (game hiện gần như không có)
- Qualified play sessions
- Spend days / user — số **ngày** có chi tiêu, nhiều lần nhỏ thắng một lần lớn
- Robux spent / user

## 3. Điều quan trọng nhất

> Tất cả tín hiệu trên **chỉ đo người tới tự nhiên qua Home recommendations**.
> Người vào từ quảng cáo, tìm kiếm, mạng xã hội đều **bị loại khỏi phép tính**.

Nên tiền quảng cáo **không mua được thứ hạng đề xuất**. Nó mua được ba thứ:

1. **Dữ liệu creative** — thumbnail nào có tỉ lệ bấm cao, để áp cho traffic tự nhiên
2. **Tư cách Kids & Select** — ngưỡng 500 người chơi gắn bó
3. **Hạt giống gián tiếp** — người do ads mang về, nếu hôm sau **tự quay lại qua Home**, thì lần quay lại ĐÓ là organic và có tính

Điểm 3 là chỗ kế hoạch cũ nói quá tay ("ngân sách này không mua được, ở bất kỳ cách tiêu nào"). Nói cho đúng: **lượt vào đầu tiên không tính, lượt quay lại thì tính.** Nhưng nó chỉ có giá trị nếu game giữ được người — tức là nó khuếch đại chất lượng game chứ không thay thế được. Game rò rỉ người thì ads chỉ đổ tiền qua lỗ thủng nhanh hơn.

## 4. Cửa Kids & Select

| Yêu cầu | Chi tiết | Chi phí |
|---|---|---|
| Tài khoản | Age-checked, xác minh danh tính, tình trạng tốt | 0 |
| Bảo mật | Bật 2FA | 0 |
| Cam kết tài chính | Phí một lần mỗi game **hoặc** Premium/Plus 2 tháng liên tiếp | **0 — đã Exempt** ✅ |
| Giai đoạn thử | Game chỉ mở cho người age-checked **16+** trong lúc xét | — |
| Xét an toàn | Roblox soi báo cáo kiểm duyệt và gameplay | — |
| **Ngưỡng vượt cửa** | **500 lượt chơi duy nhất** từ highly engaged age-checked users, trong **60 ngày** | Xem GĐ 3 |

**"Highly engaged player"** = đạt đồng thời yêu cầu về tuổi tài khoản, thời gian chơi trong game bạn, và **có mua thứ gì đó ở bất kỳ đâu trên Roblox trong 60 ngày qua**. Họ **không cần mua gì trong game bạn**.

⚠️ **Ngưỡng 500 đếm CẢ người tới tự nhiên, không chỉ người từ ads.** Đây là chỗ kế hoạch cũ ngầm hiểu sai thành "phải mua đủ 500 bằng credit". Không phải — ads chỉ là một trong hai nguồn, và với ngân sách này thì **nguồn phụ**. Xem phép tính ở GĐ 3.

**Tình trạng hiện tại (Creator Hub, cập nhật 18/08/2026):** `Highly engaged players — **Eligible** — 0`. Đã đủ tư cách tích luỹ, đồng hồ đang ở 0.

Vì phí đã được miễn, **rớt ngưỡng giờ không mất gì ngoài credit đã tiêu** — không còn khoản 1.000 R$ nào bị treo 90 ngày. Cửa này rẻ hơn hẳn so với lúc lập kế hoạch.

## 5. Nạp tiền

**Đừng mua Robux để đổi sang Ad Credit.** Tỉ giá 263 R$ = 1 Ad Credit bằng đúng tỉ giá DevEx — nó dành cho Robux *kiếm được*. Mua Robux bằng tiền thật rồi đổi là trả ~2,7 lần.

| Đường mua 1 Ad Credit | Thành tiền |
|---|---|
| **Mua Ad Credit trực tiếp bằng thẻ** | **≈ 1,28 SGD** |
| Gói Robux 5.250 rồi đổi | ≈ 3,46 SGD |
| Gói Robux 1.000 rồi đổi | ≈ 3,94 SGD |

Phí publish đã Exempt nên **không còn khoản Robux nào cần mua**. Toàn bộ vốn thành credit:

```
2.000.000 ₫ ÷ 20.300 ₫/SGD = 98,5 SGD
98,5 SGD ÷ 1,28 SGD/credit ≈ 77 credit
```

Lấy tròn **75 credit**, chừa phần chênh tỉ giá. Kiểm giá thật ở màn hình "Purchase Ad Credit" trước khi bấm.

## 6. Ràng buộc Ads Manager

- **Sàn 5 Ad Credit / ngày**, Lifetime budget bắt buộc ≥ 5 × số ngày
- **Thời lượng tối thiểu 2 ngày** → chiến dịch rẻ nhất = 10 credit / 2 ngày
- **Không thể rải mỏng.** 75 credit = đúng **15 ngày chạy**, phải chia thành đợt tập trung
- Chiến dịch có **24 giờ Learning**, cần **3–5 ngày** mới ra dữ liệu có nghĩa
  → ⚠️ **Không đợt nào được ngắn hơn 3 ngày**, nếu không bạn chỉ trả tiền cho giai đoạn Learning
- Tối đa **10 thumbnail**, tỉ lệ **16:9**, chia đều lượt hiển thị
- Nhắm được: All / New / Recent / Lapsed players + vị trí, tuổi, giới, thể loại, thiết bị

## 7. Plays hay Engagement — trả lời dứt điểm

### 7.1. Số thật từ Ads Manager (một dev khác, 08/2026)

| | Plays | Engagement | Engagement đắt hơn |
|---|---|---|---|
| Spent | 4,05 USD | 79,09 USD | |
| Impressions | 34.372 | 194.513 | |
| CTR | 3,63% | 2,16% | thấp hơn 40% |
| Clicks | 1.248 | 4.192 | |
| **CPM** (tự tính) | **0,118 USD** | **0,407 USD** | **3,45×** |
| **Cost/click** (tự tính) | **0,0032 USD** | **0,0189 USD** | **5,8×** |

### 7.2. Ba chỗ bài devlog đó đọc sai — đừng chép theo

1. **Cột đó là `Clicks`, không phải `Plays`.** Bài viết ghi "4K plays for $80" và "1.2K plays for $4" — nhưng ảnh chụp ghi rõ **Clicks**. Roblox tách hai chỉ số này vì click rồi thoát ở trang game là chuyện thường. Kết luận rút từ nhầm lẫn đó không dùng được.

2. **Cả hai chiến dịch đều đang ở trạng thái `Learning`.** Ảnh chụp ghi thế ở cả hai dòng. Theo chính tài liệu Ads Manager, số trong giai đoạn Learning chưa phải hiệu năng thật — so hai chiến dịch chưa tối ưu xong là so tiếng ồn.

3. **Chênh lệch CCU (20–40 vs 1–5) phần lớn là do thời lượng, không do loại chiến dịch.** 4 USD ở sàn 5 credit/ngày là chưa hết một ngày; 79 USD trải ra khoảng 16 ngày. Cùng lượng người mà rải dài gấp 16 lần thì CCU tất nhiên thấp hơn. Đây không phải thuộc tính của Engagement.

### 7.3. Vậy cái nào tốt hơn?

**Câu hỏi sai.** Tài liệu Roblox nói thẳng: Engagement tiếp cận **age-checked highly engaged players mà session của họ được tính vào ngưỡng Kids & Select**; Plays tiếp cận **người có khả năng mở game cao nhất, dùng khi muốn phân phối rộng hoặc muốn traffic ban đầu cho hệ đề xuất học**. Roblox còn khuyên: nếu mục tiêu là ngưỡng Kids & Select thì **dùng ngân sách RIÊNG cho Engagement, đừng rút từ ngân sách Plays**.

Và TLDR của chính bài devlog đó cũng nói y hệt: *"want 500 engaged? Do engagement. Want more CCU from ads for the algo? Do plays."* — tức là **bài viết đồng ý với kế hoạch cũ**, không phản bác.

> **Engagement là con đường DUY NHẤT tới ngưỡng 500.** Plays không đóng góp một người nào vào đó.
> Nên "Plays rẻ hơn nên chọn Plays" giống như nói "xe máy rẻ hơn máy bay nên bay bằng xe máy".

### 7.4. Nhưng số CPM đó lại đổi một thứ — THỨ TỰ

Engagement đắt hơn **3,45× mỗi lượt hiển thị**. Nghĩa là chạy Engagement với một thumbnail chưa được kiểm chứng là **lãng phí đắt gấp 3,45 lần** so với chạy Plays với cùng thumbnail đó.

⇒ **Bắt buộc chốt thumbnail bằng Plays trước, rồi mới đổ Engagement.** Đây chính là thứ tự GĐ 2 → GĐ 3 vốn có, và giờ nó có số để chống lưng chứ không còn là linh cảm.

### 7.5. Một rủi ro đã từng xảy ra — kiểm sớm

06/2026 có đợt Engagement campaign hiện **0 plays dù đã tốn hàng trăm click** (một dev ghi nhận 588 click / 0 play). Roblox đánh dấu Fixed sau 2 ngày. Đã sửa, nhưng vì nó từng hỏng đúng ở chỗ click→play, **sau 24h đầu của GĐ 3 phải mở Ads Manager đối chiếu Clicks với Plays.** Lệch bất thường thì tắt ngay, đừng đợi hết đợt.

## 8. Kế hoạch bốn giai đoạn

### GĐ 0 — Bịt lỗ thủng (0 credit, 1–2 ngày)

Không tiêu đồng credit nào trước khi xong.

- [x] ~~Bật lại AntiCheat~~ — **đã xong**, `AntiCheatConfig.ENABLED = true`
- [ ] ⚠️ **Nghiệm thu AntiCheat ở Zone 15** — `STAGE_EXTRA_ALLOWANCE` có `[12] [13] [14]` nhưng **không có `[15]`**, mà Zone 15 có SplitFloor + ShiftBridge tự dịch chuyển. Chạy tốc độ cao qua Zone 15 rồi soi log `[AntiCheat]`; thấy dòng nào thì thêm `[15] = <studs/s của sàn> + 60`. Test tay không bắt được lỗi này — triệu chứng là **giật ngược oan**, không phải hỏng
- [ ] **Sửa công thức rebirth** — vẫn đang là `50 + r*10`. `docs/ECONOMY_REVIEW.md` đề xuất `50 + r*3`. Bức tường rơi đúng rebirth 4–5 = **tuần thứ hai** = đúng mốc Ngày 8–28 mà thuật toán đo nặng nhất
- [ ] **Tặng 1 vé quay chào mừng** — vẫn chưa có. Hiện chỉ Studio hook mới phát vé; người mới thật vào game có **0 vé** và phải chờ
- [ ] **Save place** → publish QA → Live
- [ ] **Mua thật 1 món rẻ nhất trên Live** (Spin 1 vé, 19 R$) và xác nhận quà vào tay. Gamepass/product chỉ tồn tại ở universe Live nên **đường thanh toán chưa từng được test** — xem `docs/LIVEOPS.md` mục 4

### GĐ 1 — Mở tư cách publisher (0 credit, 0 R$, 1 ngày)

- [ ] Xác minh danh tính + 2FA
- [x] ~~Trả phí một lần~~ — **Exempt**, đang có subscription
- [ ] Điền Content Maturity trung thực
- [ ] ⚠️ **Rà lại content descriptors.** Creator Hub đang khai `Blood (Heavy/Unrealistic)` và `Violence (Repeated/Mild)` cho một game obby tốc độ. Reach hiện vẫn *All ages* nên chưa bị chặn, nhưng descriptor khai dư vẫn có thể bị bộ lọc của phụ huynh cắt bớt. Khai đúng thứ game thật sự có
- [ ] Rà metadata: tên/icon/mô tả **khớp gameplay thật**, không dẫn bằng "FREE ROBUX", hình và tiêu đề của riêng mình

### GĐ 2 — Chốt thumbnail bằng Plays (20 credit, 4 ngày × 5/ngày)

Mục tiêu **không phải người chơi** mà là tỉ lệ bấm. Hai lý do, cả hai đều đã có số:
- PTR là tín hiệu hạng nhất của hệ đề xuất
- Engagement đắt hơn 3,45×/hiển thị ⇒ phải biết thumbnail nào thắng TRƯỚC khi đổ tiền vào đó

- Goal **Plays**, Lifetime 20 credit / 4 ngày
- Tải **3 thumbnail 16:9**: sàn ASMR đang lún dưới chân · con số tốc độ khổng lồ · nhân vật bị sóng thần rượt
- **Không tắt sớm** — 24h đầu là Learning, đọc số ở ngày 3–4
- Mốc tham chiếu: CTR của Plays trong bảng 7.1 là **3,63%**. Dưới ~2% thì vấn đề ở thumbnail chứ không ở ngân sách

### GĐ 3 — Engagement: THĂM DÒ rồi mới quyết (15 + 35 credit)

Kế hoạch cũ đặt cược 40 credit vào một con số chưa ai đo: **credit tốn cho mỗi highly engaged player**. Không tài liệu nào công bố nó. Nên chia đôi:

**GĐ 3a — Thăm dò (15 credit / 3 ngày)**

- Goal **Engagement**, thumbnail thắng từ GĐ 2
- Sau 24h: đối chiếu Clicks vs Plays (mục 7.5)
- Hết 3 ngày: đọc `Highly engaged players` trên Creator Hub, gọi số tăng thêm là **H**

**Cổng quyết định — tính bằng chính số của bạn**

```
credit cho mỗi HEP        = 15 / H
credit cần cho 500 người  = 500 × 15 / H  =  7500 / H
```

| H đo được sau 3 ngày | Ngoại suy để đủ 500 | Quyết |
|---|---|---|
| ≥ 190 | ≤ 40 credit | **Chạy tiếp GĐ 3b**, thừa sức |
| 100 – 190 | 40 – 75 credit | Chạy tiếp, nhưng **500 phải trông cậy thêm vào traffic tự nhiên** |
| < 100 | > 75 credit | **Dừng.** Ngân sách không mua nổi ngưỡng — dồn phần còn lại sang mục 10 |

⚠️ Con số này **không cần ads gánh hết**: ngưỡng 500 đếm cả người tới tự nhiên. Nên hàng H thứ hai không phải thất bại — nó nghĩa là ads lo một nửa, TikTok và giữ chân lo nửa còn lại.

**GĐ 3b — Đẩy (35 credit / 7 ngày)**

- Chỉ chạy nếu cổng trên cho qua
- **Engagement không tự dừng khi đạt ngưỡng** — theo dõi và tắt tay
- Vì phí đã Exempt, dừng giữa chừng **không mất gì ngoài credit đã tiêu**

### Phân bổ

| Đợt | Mục tiêu | Credit | Ngày | /ngày |
|---|---|---|---|---|
| GĐ 2 — Plays | Chốt thumbnail thắng | 20 | 4 | 5 |
| GĐ 3a — Engagement thăm dò | **Đo credit/HEP** | 15 | 3 | 5 |
| GĐ 3b — Engagement đẩy | Vượt ngưỡng (có điều kiện) | 35 | 7 | 5 |
| Dự phòng | Kéo dài đợt thắng | 5 | 1 | 5 |
| **Tổng** | | **75** | **15** | |

## 9. Tỉ lệ thành công

| Mục tiêu | Cũ | **Mới** | Vì sao đổi |
|---|---|---|---|
| Vượt cửa Kids & Select trong 60 ngày | 45–60% | **50–65%** | Thêm 10 credit, phí Exempt (rớt không mất gì), và GĐ 3 giờ có cổng đo thay vì đặt cược |
| Đủ 30.000 R$ rút DevEx lần đầu trong 6 tháng | 30–40% | **30–40%** | Không đổi — vẫn phụ thuộc cửa trên |
| Quảng cáo tự tạo tăng trưởng tự nhiên bền vững | < 5% | **< 10%** | Nhích lên vì điểm 3 mục 3 (người quay lại có tính), nhưng vẫn rất thấp |

⚠️ **Các con số này giả định GĐ 0 đã xong.** Hiện GĐ 0 còn **5 mục chưa tick**, trong đó hai mục là lỗ thủng giữ chân thật (rebirth wall rơi đúng tuần 2, người mới có 0 vé quay). Bỏ qua thì tụt dưới 20% — và đó là cách chắc chắn nhất để đốt 75 credit vô ích.

## 10. Đòn bẩy thật sự không nằm trong 75 credit

2 triệu mua được 15 ngày quảng cáo và một tấm vé qua cửa. Thứ đưa game lên vài trăm CCU thì miễn phí: **17 loại sàn ASMR** là nội dung satisfying dạng thuần, thể loại lan tự nhiên mạnh nhất trên TikTok/Shorts, và là khác biệt *cấu trúc* so với hàng nghìn speed simulator khác.

Điều này càng đúng hơn sau bản 06/2026: tín hiệu tính **trung bình trên mỗi người**, không phải tổng. Một game nhỏ mà người chơi ở lại sâu **không hề bị thiệt** so với game to. Đó là sân chơi mà một người làm game có thể thắng — và quảng cáo trả tiền không mua được nó.

Nếu cổng GĐ 3a cho kết quả xấu (H < 100), **đừng cố đấm nốt 35 credit**. Giữ lại, và đọc `docs/LIVEOPS.md` — nhịp update hằng tuần cộng với video ngắn tạo ra đúng loại traffic mà thuật toán đếm, còn credit thì không.

## Nguồn

- [Boost Your Discovery by Building Games People Want to Play](https://devforum.roblox.com/t/boost-your-discovery-by-building-games-people-want-to-play/4779042) — DevForum, 06/8/2026
- [Optimizing Discovery](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox) — Newsroom, 06/2026
- [Discovery](https://create.roblox.com/docs/discovery) — Creator Hub (danh sách tín hiệu)
- [Roblox Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select) — Creator Hub
- [Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager) — Creator Hub (định nghĩa Plays vs Engagement)
- [Roblox Kids and Select Global Launch: Updates to Eligibility, Ads Manager, Expedited Review](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717/1) — DevForum
- [New Engagement Campaigns Suspiciously Have 0 Plays](https://devforum.roblox.com/t/new-engagement-campaigns-for-ads-manager-suspiciously-have-0-plays/4686589) — DevForum, 06/2026 (đã Fixed)
- [Developer Exchange](https://create.roblox.com/docs/production/monetization/developer-exchange) — Creator Hub
- Ảnh chụp Ads Manager + Creator Hub của user, 2026-08-24 (bảng 7.1 và mục 4)
