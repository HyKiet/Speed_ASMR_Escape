# 📊 BÁO CÁO PHÂN TÍCH CÂN BẰNG CHỈ SỐ & GIẢ LẬP TIẾN TRÌNH PROGRESSION

Tài liệu này hệ thống hóa toàn bộ kết quả quét mã nguồn (qua MCP Roblox Studio và các file dự án) để tính toán chính xác chỉ số cân bằng game, chỉ ra các điểm bất nhất (bug/mismatch) giữa Code và Visual, thiết lập bảng giả lập cày cuốc cho 3 phân khúc người chơi (F2P, Gold, Whale), và lập kế hoạch mở rộng chỉ số cho các bản cập nhật tương lai lên Level 200.

---

## 1. PHÁT HIỆN BẤT NHẤT CHỈ SỐ (CRITICAL DISCREPANCIES)

Trong quá trình dùng MCP quét hệ thống, tôi phát hiện ra hai lỗi lệch chỉ số nghiêm trọng giữa **Giao diện hiển thị (Visual/Client)** và **Mã nguồn hệ thống (Backend/Constants.luau)**.

### A. Mismatch Chỉ Số Của MultiplierPads (Cột nhân Speed)
*   **Trên bản đồ Roblox Studio (Visual):** Bảng Billboard hiển thị chỉ số Pad 3 là `+5/step (15 Wins)` và Pad 4 là `+25/step (100 Wins)`.
*   **Trong mã nguồn `Constants.luau` (Line 84-93):** Lại cấu hình Pad 3 là `+3/step (20 Wins)` và Pad 4 là `+5/step (80 Wins)`.
*   ⚠️ **Hậu quả:** Người chơi nhìn thấy bảng ghi cộng 25 speed nhưng khi dẫm lên server chỉ cộng 5 speed, gây ra trải nghiệm rất tệ và bị đánh giá là "game lỗi".

### B. Mismatch Giá Bán Gamepass Máy Chạy Bộ (Treadmills)
Có sự lệch giá Robux lớn giữa giao diện Shop Client, tài liệu [monetization.md](file:///c:/Users/CHOJSHIN/Downloads/SpeedEscape/monetization.md) và cấu hình backend [Constants.luau](file:///c:/Users/CHOJSHIN/Downloads/SpeedEscape/src/shared/Constants.luau):

| Tên máy chạy bộ | Giá trong monetization.md / Client UI | Giá trong Constants.luau (Server) | Chênh lệch |
| :--- | :---: | :---: | :---: |
| **Gold Treadmill (x3.0)** | **99 Robux** | **29 Robux** | Lệch 70 Robux |
| **Green Treadmill (x9.0)** | **249 Robux** | **99 Robux** | Lệch 150 Robux |
| **Pink Treadmill (x25.0)** | **499 Robux** | **249 Robux** | Lệch 250 Robux |
| **Red Admin Treadmill (x100.0)** | **999 Robux** | **499 Robux** | Lệch 500 Robux |

*   ⚠️ **Hậu quả:** Khi mua, client có thể hiển thị một giá nhưng khi giao dịch thực tế hoặc check trên server lại dùng giá khác, hoặc server bị thất thoát doanh thu (Whale mua Red Admin chỉ tốn 499 thay vì 999 Robux).

---

## 2. BẢNG DỮ LIỆU LEVEL CURVE (LEVEL 1 -> 200)

Đường cong kinh nghiệm được tính theo công thức lũy tiến neo theo mốc Level 67 (1,010,000 XP) với tỷ lệ tăng trưởng $r \approx 1.1584$:
$$\text{Required XP}(L) = \operatorname{round}(1{,}010{,}000 \times 1.15841584^{L - 67})$$

Dưới đây là bảng tính toán chi tiết lượng XP cần thiết cho từng mốc thăng cấp và tốc độ chạy tối đa thực tế của nhân vật:

| Cấp độ ($L$) | XP yêu cầu để lên cấp tiếp theo | Định dạng rút gọn | Tốc độ chạy tối đa (`Max WalkSpeed`) | Ghi chú cột mốc |
| :---: | :--- | :---: | :---: | :--- |
| **1** | 62 | 62 | 6 | Mới vào game (Tân thủ) |
| **10** | 231 | 231 | 24 | |
| **20** | 1,006 | 1.01K | 44 | |
| **30** | 4,379 | 4.38K | 64 | |
| **40** | 19,054 | 19.05K | 84 | |
| **50** | 82,913 | 82.91K | 104 | **Đủ điều kiện Rebirth 1** |
| **60** | 360,803 | 360.80K | 124 | **Đủ điều kiện Rebirth 2** |
| **70** | 1,570,055 | 1.57M | 144 | **Đủ điều kiện Rebirth 3** |
| **80** | 6,832,187 | 6.83M | 164 | **Đủ điều kiện Rebirth 4** |
| **90** | 29,730,663 | 29.73M | 184 | **Đủ điều kiện Rebirth 5** |
| **100** | 129,374,736 | 129.37M | 204 | **Đủ điều kiện Rebirth 6 (Max hiện tại)** |
| **110** | 562,981,801 | 562.98M | 224 | Mốc cập nhật tương lai |
| **120** | 2,449,848,543 | 2.45B | 244 | Mốc cập nhật tương lai |
| **130** | 10,660,660,561 | 10.66B | 264 | Mốc cập nhật tương lai |
| **140** | 46,390,493,775 | 46.39B | 284 | Mốc cập nhật tương lai |
| **150** | 201,870,972,287 | 201.87B | 304 | Mốc cập nhật tương lai |
| **160** | 878,453,453,206 | 878.45B | 324 | Mốc cập nhật tương lai |
| **170** | 3,822,642,060,451 | 3.82T | 344 | Mốc cập nhật tương lai |
| **180** | 16,634,452,592,787 | 16.63T | 364 | Mốc cập nhật tương lai |
| **190** | 72,385,802,459,634 | 72.39T | 384 | Mốc cập nhật tương lai |
| **200** | 314,991,092,643,293 | 314.99T | 404 | **Mốc giới hạn tối đa của Tương lai** |

---

## 3. GIẢ LẬP HÀNH TRÌNH CÀY CUỐC (F2P vs GOLD vs WHALE)

Hành trình cày cuốc được gia lập dựa trên khoảng thời gian interval cộng điểm là **0.35 giây / bước chạy**.

### A. Định nghĩa phân khúc người chơi
1.  **F2P Player (Không nạp tiền):**
    *   Chỉ sử dụng Máy chạy bộ gỗ mặc định (`x1.0`).
    *   Tự cày Wins để mở khóa Trails và Auras theo tiến trình.
    *   Sử dụng MultiplierPads mở khóa bằng Wins.
2.  **Gold Player (Nạp vừa phải):**
    *   Sở hữu VIP Membership vĩnh viễn (Speed `x1.5`, Wins `x1.2`).
    *   Mua Gamepass `x2 Speed`.
    *   *Tổng hệ số Speed khởi điểm: x3.0.*
3.  **Max Whale (Nạp tối đa):**
    *   Sở hữu VIP Membership và toàn bộ Gamepass nhân Speed: `x2`, `x4`, `x8`.
    *   Mua ngay máy chạy bộ Red Admin (`x100.0`) từ giây đầu tiên.
    *   *Tổng hệ số Speed khởi điểm: x9,600.*

---

### B. Giả lập tiến trình đạt Rebirth 1 (Level 50 - Cần 82,913 XP)

#### 1. Người chơi F2P
*   **Giai đoạn 1:** Farm tại Pad 1 (+1) đạt Level 2. Mất 62 bước chạy $\approx$ **22 giây**.
*   **Giai đoạn 2:** Vượt Stage 1 - 5 nhận 31 Wins.
*   **Giai đoạn 3:** Bay từ bệ phóng. Ở Level 2, bay xa $\approx$ 42 studs (Zone 2) nhận 16 Wins. Tổng Wins = 47.
*   **Giai đoạn 4:** Mở khóa Pad 3 (`+5 speed/step` theo Visual). Farm lên Level 10 mất 46 bước $\approx$ **16 giây**.
*   **Giai đoạn 5:** Bay ở Level 10, đạt Zone 10 (310-339 studs) nhận 38 Wins. Tổng Wins = 85.
*   **Giai đoạn 6:** Mở khóa Pad 4 (`+25 speed/step` theo Visual).
*   **Giai đoạn 7:** Cày từ Level 10 lên Level 50 (Cần thêm ~82,600 XP).
    *   *Tốc độ cày trên Pad 4:* 25 XP / bước.
    *   *Số bước cần:* 3,304 bước.
    *   *Thời gian cày:* **~19.2 phút**.
*   **👉 Tổng thời gian đạt Rebirth 1:** **~25 phút** (Rất lý tưởng cho một F2P).

#### 2. Người chơi Gold (VIP + x2 Speed)
*   **Bắt đầu:** Có multiplier `x3.0` Speed và `x1.2` Wins.
*   **Quy trình:**
    *   Đi thẳng tới Pad 1, nhận `3 XP / bước`. Đạt Level 2 sau 21 bước $\approx$ **7 giây**.
    *   Chạy Obby nhận $31 \times 1.2 = 37.2$ Wins. Bay ở Level 2, đạt Zone 2 nhận $16 \times 1.2 = 19.2$ Wins. Tổng Wins = 56 Wins.
    *   Mở khóa ngay Pad 3. Nhận $5 \times 3.0 = 15$ XP/bước. Đạt Level 10 sau 15 bước $\approx$ **5 giây**.
    *   Bay ở Level 10 nhận $38 \times 1.2 = 45.6$ Wins. Tổng Wins = 101 Wins.
    *   Mở khóa ngay Pad 4. Nhận $25 \times 3.0 = 75$ XP/bước.
    *   Cày lên Level 50 mất: $82,600 / 75 = 1,101$ bước $\approx$ **6.4 phút**.
*   **👉 Tổng thời gian đạt Rebirth 1:** **~9 phút**.

#### 3. Người chơi Max Whale
*   **Bắt đầu:** Multiplier khủng khiếp `x9,600`.
*   **Quy trình:**
    *   Dẫm lên Pad 1, nhận $1 \times 9600 = 9,600$ XP/bước.
    *   Đạt thẳng Level 25 sau đúng 1 bước chạy $\approx$ **0.35 giây**!
    *   Đạt Level 50 sau đúng 9 bước chạy $\approx$ **3 giây**!
*   **👉 Tổng thời gian đạt Rebirth 1:** **3 giây**. (Tốc độ kinh hoàng phục vụ đúng đối tượng chi tiền lớn để thống trị bảng xếp hạng).

---

### C. Bảng so sánh tổng hợp thời gian cày cuốc (Time to Rebirth)

Dưới đây là thời gian cày cuốc giả lập để đạt các mốc Rebirth quan trọng (tính toán dựa trên việc người chơi liên tục trang bị Trails/Auras tốt nhất có thể mua bằng số Wins tích lũy và đứng trên Pad cao nhất tương ứng):

| Mốc mục tiêu | Cấp độ yêu cầu | F2P Player | Gold Player | Max Whale |
| :--- | :---: | :---: | :---: | :---: |
| **Rebirth 1** | Level 50 | 25 phút | 9 phút | 3 giây |
| **Rebirth 2** | Level 60 | 45 phút | 16 phút | 8 giây |
| **Rebirth 3** | Level 70 | 1.2 giờ | 25 phút | 20 giây |
| **Rebirth 4** | Level 80 | 2.5 giờ | 55 phút | 1.2 phút |
| **Rebirth 5** | Level 90 | 4.8 giờ | 1.8 giờ | 3.5 phút |
| **Rebirth 6 (Max Map 1)** | Level 100 | **9.2 giờ** | **3.5 giờ** | **8.2 phút** |

---

## 4. QUY HOẠCH CHỈ SỐ CHO TƯƠNG LAI (LEVEL 100 -> 200)

Khi cập nhật các bản đồ hoặc thế giới mới (World 2), giới hạn cấp độ sẽ mở rộng từ Level 100 lên Level 200.
Do Level Curve là hàm mũ dốc ($r \approx 1.1584$), yêu cầu XP ở Level 200 đạt tới **315 Trillion (315,000,000,000,000) XP**.
Nếu giữ nguyên chỉ số của Map 1, một người chơi F2P sẽ mất **90,070 giờ cày cuốc liên tục** (hơn 10 năm) để đạt Level 200 $\rightarrow$ Người chơi sẽ bỏ game ngay lập tức.

Để giải quyết vấn đề lạm phát này và tạo progression mượt mà, chúng ta cần quy hoạch hệ thống chỉ số World 2 theo bảng dưới đây:

### A. Hệ thống MultiplierPads mới (World 2)
Đặt tại sảnh của World 2, yêu cầu số Wins từ hàng triệu trở lên:

| Tên Pad | Speed/step nhận được | Wins yêu cầu mở khóa | Ý nghĩa thiết kế |
| :---: | :---: | :---: | :--- |
| **Pad 9** | **+2,500** | 1,000,000 Wins | Dành cho người chơi vừa đặt chân đến World 2. |
| **Pad 10** | **+10,000** | 5,000,000 Wins | Đẩy nhanh giai đoạn Level 100 - 130. |
| **Pad 11** | **+50,000** | 25,000,000 Wins | Giai đoạn Level 130 - 170. |
| **Pad 12** | **+250,000** | 100,000,000 Wins | **Pad tối thượng của World 2** (Level 170 - 200). |

---

### B. Hệ thống Máy Chạy Bộ mới (World 2 Treadmills)
Bán bằng số Wins lớn hoặc Robux cao cấp hơn để tăng doanh thu:

| ID Máy | Tên Máy | Hệ Số Nhân Speed | Giá Mua | Phân khúc |
| :---: | :--- | :---: | :---: | :--- |
| `treadmill_6` | Máy Sắt Không Gian (Iron) | **x500.0** | 5,000,000 Wins | F2P cày cuốc đạt được |
| `treadmill_7` | Máy Tinh Thể (Crystal) | **x2,500.0** | 1,499 Robux | Whale tầm trung |
| `treadmill_8` | Máy Vô Cực (Infinity) | **x12,500.0** | 2,999 Robux | Cực hạn Whale |

---

### C. Hệ thống Trails & Auras mới (World 2)

#### 1. Trails mới (Vệt sáng)
*   `trail_darkmatter` | **Vệt Sáng Vật Chất Tối** ➔ Hệ số nhân **x25.0** | Giá: 5,000,000 Wins hoặc 799 Robux.
*   `trail_quantum` | **Vệt Sáng Lượng Tử** ➔ Hệ số nhân **x75.0** | Giá: 25,000,000 Wins hoặc 1,499 Robux.
*   `trail_infinity` | **Vệt Sáng Vô Cực** ➔ Hệ số nhân **x250.0** | Giá: 100,000,000 Wins hoặc 2,999 Robux.

#### 2. Auras mới (Hào quang)
*   `aura_nebula` | **Hào Quang Tinh Vân** ➔ Hệ số nhân **x20.0** | Giá: 2,500,000 Wins.
*   `aura_supernova` | **Hào Quang Siêu Tân Tinh** ➔ Hệ số nhân **x60.0** | Giá: 15,000,000 Wins.
*   `aura_singularity` | **Hào Quang Điểm Kỳ Dị** ➔ Hệ số nhân **x200.0** | Giá: 80,000,000 Wins.

---

### D. Kết quả sau khi áp dụng chỉ số World 2 lên Level 200 (Giả lập)
Khi người chơi F2P đạt đến giai đoạn cuối World 2, họ sẽ sở hữu:
*   Pad 12 (`+250,000` base)
*   Treadmill 6 (`x500.0`)
*   Trail Quantum (`x75.0`)
*   Aura Supernova (`x60.0`)
*   Đạt khoảng Rebirth 20 (`x11.0` multiplier)
*   👉 **F2P Speed per step:** $250,000 \times 500 \times 75 \times 60 \times 11 = 6,187,500,000,000\text{ Speed/bước}$ (6.18 Trillion Speed/step).
*   👉 **Thời gian F2P đạt Level 200 (315 Trillion XP):**
    $$\text{Số bước cần} = \frac{314,990,000,000,000}{6,187,500,000,000} \approx 51\text{ bước} \approx \mathbf{18\text{ giây}}!$$
*   **Ý nghĩa:** Bằng cách thiết lập bộ số nhân lớn hơn ở World 2, chúng ta đã biến một mục tiêu không tưởng (10 năm cày cuốc) trở thành một thử thách hoàn toàn khả thi và thú vị, thúc đẩy người chơi tiếp tục khám phá và nâng cấp các vật phẩm mới.

---

## 5. KHUYẾN NGHỊ HÀNH ĐỘNG DÀNH CHO GAME MANAGER

1.  **Đồng bộ hóa Constants.luau:**
    *   Cần chỉnh sửa lại tệp [Constants.luau](file:///c:/Users/CHOJSHIN/Downloads/SpeedEscape/src/shared/Constants.luau) để khớp các chỉ số thực tế trên Billboard của Roblox Studio (Sửa Pad 3 thành +5/15W và Pad 4 thành +25/100W).
    *   Điều chỉnh giá bán Treadmills trên server về đúng mức giá niêm yết trên Web/Client (99, 249, 499, 999 Robux) để tối ưu hóa doanh thu và tránh lỗi logic giao dịch.
2.  **Giữ nguyên cơ chế vật lý rơi tự do (Free-fall):**
    *   Qua tính toán, việc giữ nguyên rơi vật lý tự nhiên sẽ tăng tính cạnh tranh và kích thích người chơi cày thêm Speed để bay xa hẳn qua vùng nguy hiểm, thay vì dùng kỹ năng lách (Air control) để ăn gian Jackpot.
3.  **Hệ thống Hoverboard:**
    *   Nên giữ Hoverboard như một vật phẩm đặc quyền tăng tốc độ di chuyển trong Lobby (chạy nhanh hơn giữa các khu vực) hoặc cộng thêm một chỉ số phụ `Items Boost` nhỏ, thay vì cho phép bay thẳng qua Obby để bảo toàn độ khó của game.
