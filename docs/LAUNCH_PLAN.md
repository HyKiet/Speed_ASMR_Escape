# Kế hoạch ra mắt — +1 Speed ASMR Escape

> Chốt 2026-08-13. Bản trình bày: https://claude.ai/code/artifact/bcb5d0d1-c173-46e7-bbbd-aa5d46edca7f
>
> Vốn: **2.000.000 ₫** (gồm cả phí publish) · Cửa sổ: **60 ngày**

---

## 1. Ba thay đổi của Roblox đang chi phối kế hoạch này

| Mốc | Thay đổi |
|---|---|
| 06/2026 | Recommended For You mở từ 7 ngày lên **28 ngày**, chia theo Ngày 1 · Ngày 2–7 · Ngày 8–28. Chỉ số qPTR bị tách đôi thành **PTR** và **first-play bounce rate** (tín hiệu âm). |
| 06/08/2026 | Roblox thử nghiệm bản Home recommendations mới, dự kiến áp dụng **cuối tháng 8 / đầu tháng 9/2026**. Lần đầu **kiếm tiền được đặt ngang hàng với giữ chân**: mạnh cả hai mặt thì phân phối rộng hơn, chỉ mạnh một mặt có thể bị đổi mức phân phối. |
| Đang áp dụng | **Roblox Kids & Select** — phân phối cho người dùng dưới 16 tuổi phải qua xét duyệt. Với speed simulator, đây là phần lớn thị trường. |

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

Nên tiền quảng cáo **không mua được thứ hạng đề xuất**. Nó chỉ mua được hai thứ:

1. **Dữ liệu creative** — thumbnail nào có tỉ lệ bấm cao, để áp cho traffic tự nhiên
2. **Tư cách Kids & Select** — ngưỡng 500 người chơi gắn bó

## 4. Cửa Kids & Select

| Yêu cầu | Chi tiết | Chi phí |
|---|---|---|
| Tài khoản | Age-checked, xác minh danh tính, tình trạng tốt | 0 |
| Bảo mật | Bật 2FA | 0 |
| Cam kết tài chính | Phí một lần mỗi game (**hoàn lại**) **hoặc** Premium/Plus 2 tháng liên tiếp | ~1.000 R$ (cần xác minh lại trên Dashboard) |
| Giai đoạn thử | Game chỉ mở cho người age-checked **16+** trong lúc xét | — |
| Xét an toàn | Roblox soi báo cáo kiểm duyệt và gameplay | — |
| **Ngưỡng vượt cửa** | **500 lượt chơi duy nhất** từ highly engaged age-checked users, trong **60 ngày** | Xem GĐ 3 |

**"Highly engaged player"** = đạt đồng thời yêu cầu về tuổi tài khoản, thời gian chơi trong game bạn, và **có mua thứ gì đó ở bất kỳ đâu trên Roblox trong 60 ngày qua**. Họ **không cần mua gì trong game bạn**.

Không đạt trong 60 ngày → phí được hoàn sau 90 ngày kể từ ngày trả.

Đây là lý do Ads Manager ghi: *"Engagement should only be used to reach eligibility requirements for Roblox kids or select."*

## 5. Nạp tiền

**Đừng mua Robux để đổi sang Ad Credit.** Tỉ giá 263 R$ = 1 Ad Credit bằng đúng tỉ giá DevEx — nó dành cho Robux *kiếm được*. Mua Robux bằng tiền thật rồi đổi là trả ~2,7 lần.

| Đường mua 1 Ad Credit | Thành tiền |
|---|---|
| **Mua Ad Credit trực tiếp bằng thẻ** | **≈ 1,28 SGD** |
| Gói Robux 5.250 (rẻ nhất/R$) rồi đổi | ≈ 3,46 SGD |
| Gói Robux 1.000 rồi đổi | ≈ 3,94 SGD |

**Chia làm hai khoản mua tách biệt:**

| Mua gì | Dùng vào | Giá | VNĐ |
|---|---|---|---|
| Gói Robux **1.000 R$** | Phí Kids & Select (hoàn lại) | 14,98 SGD | ≈ 304.000 |
| **65 Ad Credit** mua thẳng | Chiến dịch GĐ 2 và 3 | ≈ 83 SGD | ≈ 1.685.000 |
| | | **≈ 98 SGD** | **≈ 1.989.000** |

Quy đổi ~20.300 ₫/SGD, 1 Ad Credit = $1. Kiểm giá thật ở màn hình "Purchase Ad Credit" rồi co giãn **số credit**, đừng co khoản Robux.

## 6. Ràng buộc Ads Manager

- **Sàn 5 Ad Credit / ngày**, Lifetime budget bắt buộc ≥ 5 × số ngày
- **Thời lượng tối thiểu 2 ngày** → chiến dịch rẻ nhất = 10 credit / 2 ngày
- **Không thể rải mỏng.** 65 credit = đúng **13 ngày chạy**, phải chia thành đợt tập trung
- Chiến dịch có **24 giờ Learning**, cần **3–5 ngày** mới ra dữ liệu có nghĩa
- Tối đa **10 thumbnail**, tỉ lệ **16:9**, chia đều lượt hiển thị
- Nhắm được: All / New / Recent / Lapsed players + vị trí, tuổi, giới, thể loại, thiết bị

## 7. Kế hoạch bốn giai đoạn

### GĐ 0 — Bịt lỗ thủng (0 credit, 1–2 ngày)

Không tiêu đồng credit nào trước khi xong.

- [ ] **Bật lại AntiCheat** — `AntiCheatConfig.ENABLED` đang `false`, console cảnh báo mỗi lần chạy
- [ ] **Sửa công thức rebirth** — xem `docs/ECONOMY_REVIEW.md`. Bức tường rơi đúng tuần thứ hai = mốc Ngày 8–28
- [ ] **Tặng 1 vé quay chào mừng** — hiện người mới có 0 vé, chờ 15 phút
- [ ] **Save place** → publish QA → Live

### GĐ 1 — Mở tư cách publisher (0 credit, ~1.000 R$ hoàn lại, 1 ngày)

- [ ] Xác minh danh tính + 2FA + trả phí một lần (chọn phí thay vì Premium 2 tháng: nhanh hơn, hoàn lại được)
- [ ] Điền Content Maturity trung thực
- [ ] Rà metadata: tên/icon/mô tả **khớp gameplay thật**, không dẫn bằng "FREE ROBUX", hình và tiêu đề của riêng mình

### GĐ 2 — Test thumbnail bằng Plays (20 credit, 4 ngày × 5/ngày)

Mục tiêu **không phải người chơi** mà là tỉ lệ bấm — PTR là tín hiệu hạng nhất.

- Goal **Plays**, Lifetime 20 credit / 4 ngày
- Tải **3 thumbnail 16:9**: sàn ASMR đang lún dưới chân · con số tốc độ khổng lồ · nhân vật bị sóng thần rượt
- **Không tắt sớm** — 24h đầu là Learning

### GĐ 3 — Engagement vượt ngưỡng 500 (40 credit, 2 đợt × 4 ngày)

- Goal **Engagement (Beta)**, thumbnail thắng từ GĐ 2
- CPP cao hơn Plays (tập khán giả nhỏ hơn) — chấp nhận, đây là nguồn duy nhất tính vào ngưỡng 500
- **Hai đợt 20 credit / 4 ngày, cách nhau 2–3 tuần**
- Sau đợt 1: đếm highly engaged player trong Creator Analytics. **Dưới ~120 thì sửa game trước khi chạy đợt 2**
- ⚠️ **Engagement không tự dừng khi đạt ngưỡng** — phải theo dõi và tắt tay

### Phân bổ

| Đợt | Mục tiêu | Credit | Ngày | /ngày |
|---|---|---|---|---|
| GĐ 2 — Plays | Tìm thumbnail thắng | 20 | 4 | 5 |
| GĐ 3 — Engagement đợt 1 | Nửa đầu ngưỡng + số đo | 20 | 4 | 5 |
| GĐ 3 — Engagement đợt 2 | Vượt nốt ngưỡng | 20 | 4 | 5 |
| Dự phòng | Kéo dài đợt 2 thêm 1 ngày | 5 | 1 | 5 |
| **Tổng** | | **65** | **13** | |

## 8. Tỉ lệ thành công

| Mục tiêu | Ước tính | Vì sao |
|---|---|---|
| **Vượt cửa Kids & Select trong 60 ngày** | **45–60%** | Ngưỡng có số cụ thể, có công cụ nhắm đúng, 40 credit dồn hai đợt là đủ tầm. Rủi ro: CPP cao hơn dự kiến, khâu xét an toàn |
| Đủ 30.000 R$ rút DevEx lần đầu trong 6 tháng | 30–40% | Phụ thuộc gần như hoàn toàn vào việc qua được cửa trên |
| Quảng cáo tự tạo tăng trưởng tự nhiên bền vững | **< 5%** | Traffic quảng cáo bị loại khỏi tín hiệu đề xuất — ngân sách này không mua được, ở bất kỳ cách tiêu nào |

Con số 45–60% **giả định GĐ 0 đã xong**. Bỏ qua thì tụt dưới 20%.

## 9. Đòn bẩy thật sự không nằm trong 65 credit

2 triệu mua được 13 ngày quảng cáo và một tấm vé qua cửa. Thứ đưa game lên vài trăm CCU thì miễn phí: **14 loại sàn ASMR** là nội dung satisfying dạng thuần, thể loại lan tự nhiên mạnh nhất trên TikTok/Shorts, và là khác biệt *cấu trúc* so với hàng nghìn speed simulator khác. Quảng cáo trả tiền không khai thác được lợi thế đó; video ngắn thì có — và đó là kênh duy nhất tạo ra **traffic tự nhiên**, loại duy nhất thuật toán đếm.

## Nguồn

- [Boost Your Discovery by Building Games People Want to Play](https://devforum.roblox.com/t/boost-your-discovery-by-building-games-people-want-to-play/4779042) — DevForum, 06/8/2026
- [Optimizing Discovery](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox) — Newsroom, 06/2026
- [Discovery](https://create.roblox.com/docs/discovery) — Creator Hub (danh sách tín hiệu)
- [Roblox Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select) — Creator Hub
- [Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager) — Creator Hub
- [Developer Exchange](https://create.roblox.com/docs/production/monetization/developer-exchange) — Creator Hub
