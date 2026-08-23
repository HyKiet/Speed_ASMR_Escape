# GAME DESIGN DOCUMENT: +1 SPEED ESCAPE

> **Tên trò chơi:** +1 Speed Escape  
> **Thể loại:** Speed Simulator × Obby Hybrid  
> **Phiên bản GDD:** 2.1 (Đồng bộ chuẩn cơ chế WinCollectionPad & Roblox Studio)  
> **Max Level World 1:** 120 | **Max Level World 2:** 220  
> **Định vị sản phẩm:** Trải nghiệm tốc độ bùng nổ, kết hợp giữa cảm giác flex chỉ số ảo (hàng tỷ Speed) và kỹ năng vượt rào cản Obby thực tế. Khóa chặt vòng lặp cày cuốc, giữ chân người chơi lâu dài thông qua cơ chế Lựa chọn Chiến lược (Risk vs. Reward) tại mỗi Điểm dừng chân (Rest Stop Platform).

---

## 1. TỔNG QUAN & TRIẾT LÝ THIẾT KẾ

### 3 Trụ Cột Cốt Lõi:
1. **Cảm Giác Tốc Độ Bùng Nổ (Virtual Ego Index):**
   - Chỉ số **Speed** hiển thị trên UI/Leaderstats có thể nhân lên hàng tỷ/hàng triệu. Đây là thước đo thành tựu và vị thế (Ego) của người chơi. Whale có thể flex chỉ số bằng hệ số nhân khủng từ Treadmill và Gamepass.
2. **Khống Chế Tốc Độ Thực Tế (WalkSpeed Cap):**
   - Tốc độ di chuyển thực tế của nhân vật trong Obby (**WalkSpeed**) bị giới hạn cứng theo Level theo công thức:  
     $$\text{WalkSpeed} = \min\left(250, 12 + (L-1) \times 2\right)$$
   - Điều này đảm bảo tính thử thách của các chướng ngại vật (Obby), cấm tuyệt đối việc dùng tiền mua đứt game trong vài phút mà vẫn đòi hỏi kỹ năng di chuyển.
3. **Mô Hình Lựa Chọn Tại Điểm Dừng Chân (Rest Stop Mechanics):**
   - Vạch đích không tự động trao Wins. Khi vượt qua mỗi Stage, người chơi đứng trước lựa chọn chiến lược: **Chạy tiếp** sang Stage sau để săn lượng Wins lớn hơn hẳn, HOẶC dậm lên **WinCollectionPad** để chốt hạ nhận Wins và quay về Lobby nâng cấp.

---

## 2. VÒNG LẶP CỐT LÕI (CORE LOOP)

```
 [1. FARM] ──► [2. RUN STAGE] ──► [3. REST STOP DECISION]
   │                 │                        │
   ├─ Treadmill      └─ Vượt Obby             ├──► A. NHẬN WINS (WinCollectionPad) ──► Teleport về Lobby ──► [4. UPGRADE]
   └─ Multi Pad                               ├──► B. NHẬN X2 WINS (DoubleWinPad)  ──► Trả Robux ──► Lobby ──► [4. UPGRADE]
                                              └──► C. CHẠY TIẾP (Cổng Stage Kế)   ──► Sang Stage N+1 (Wins nhiều hơn!)
                                                                                      │
                                                                                      └──► [5. REBIRTH] (Khi đủ Level)
```

1. **FARM (Cày chỉ số):** Đứng trên **Multiplier Pad** hoặc **Treadmill** tại Lobby/Checkpoint để tích lũy Speed và XP.
2. **RUN STAGE (Thách thức Obby):** Dùng WalkSpeed thực tế di chuyển qua các chướng ngại vật của Stage.
3. **REST STOP DECISION (Điểm dừng chân & Lựa chọn):**
   - **Chạy tiếp:** Bước thẳng qua cổng Stage kế tiếp ($N+1$) để chinh phục mức thưởng Wins cao hơn gấp nhiều lần.
   - **Nhận Wins Thường (`WinCollectionPad`):** Dậm lên pad vàng để thu hoạch Wins của Stage hiện tại ➔ Hệ thống tự động dịch chuyển về Lobby.
   - **Nhận X2 Wins (`DoubleWinCollectionPad`):** Trả 49 R$ để nhân đôi Wins ➔ Tự động dịch chuyển về Lobby.
4. **UPGRADE (Nâng cấp tài sản tại Lobby):** Dùng Wins thu hoạch được để mua Trail/Aura mới hoặc mở khóa Multiplier Pad cao hơn.
5. **REBIRTH (Trùng sinh):** Khi đạt Level tối thiểu, thực hiện Trùng sinh để reset Speed & Level về 0 nhưng nhận lại hệ số nhân vĩnh viễn $\text{RebirthMultiplier} = 1 + (R \times 0.5)$.

---

## 3. HỆ THỐNG TOÁN & CÔNG THỨC SỨC MẠNH

### A. Công Thức WalkSpeed Thực Tế
$$\text{WalkSpeed} = \min\left(250, 12 + (\text{Level} - 1) \times 2\right)$$
- **Tốc độ khởi đầu (Level 1):** $12\text{ studs/s}$
- **Tốc độ tối đa World 1 (Level 120):** $250\text{ studs/s}$ (Cập nhật từ `Tuning.luau` & `Formulas.luau`).

### B. Cơ Chế Nhân Hệ Số (4 Xô Độc Lập)
Tốc độ nhận Speed & XP mỗi tick ($0.35\text{s}$) tính theo công thức:
$$\text{Gain Per Tick} = \text{BaseStep} \times \text{Bucket}_{\text{Premium}} \times \text{Bucket}_{\text{Cosmetic}} \times \text{Bucket}_{\text{Rebirth}} \times \text{Bucket}_{\text{LiveOps}}$$

1. **Xô Nạp (Additive Premium):** Mua bằng Robux.  
   $$\text{Bucket}_{\text{Premium}} = 1 + (\text{Treadmill} - 1) + (\text{SpeedPass}_{\text{Max}} - 1) + (\text{VIP} - 1)$$
   - *Treadmill:* Wood (x1), Purple (x3), Blue (x9), Gold (x25), Red Admin (x100).
   - *Speed Pass:* Double Speed (x2), Quad Speed (x4), Octa Speed (x8). (Ưu tiên kích hoạt gói cao nhất).
   - *VIP Membership:* +0.5 (tương đương hệ số x1.5).

2. **Xô Đồ Trang Bị (Additive Cosmetics):** Cày bằng Wins.  
   $$\text{Bucket}_{\text{Cosmetic}} = 1 + (\text{Trail} - 1) + (\text{Aura} - 1)$$

3. **Xô Tiến Trình (Multiplicative Rebirth):** Cày Level.  
   $$\text{Bucket}_{\text{Rebirth}} = 1 + (\text{Rebirths} \times 0.5)$$

4. **Xô Vận Hành (Live-Ops Boosts):** Buff tạm thời nhân liên hoàn.  
   $$\text{Bucket}_{\text{LiveOps}} = \text{PlaytimeBoost} \times \text{FriendsBoost} \times \text{ServerBoost}$$
   - *Playtime Boost:* Tăng dần theo thời gian online (Tối đa x4 ở phút 60).
   - *Friends Boost:* bảng DỒN VỀ ĐẦU (tính lại 2026-08-21) — 1 bạn = **x1.15 Speed + x1.10 Wins**,
     2 = x1.25/x1.15, 3 = x1.35/x1.20, 4 = x1.45/x1.23, 5 = **x1.5 / x1.25** (trần).
     Trần giữ nguyên như bản +10%/bạn cũ; chỉ đổi hình dạng đường cong. Lý do: rủ được 5 bạn
     vào CÙNG một server gần như không xảy ra, nên bản tuyến tính dồn hết giá trị vào một mốc
     không ai chạm tới, còn người bạn ĐẦU TIÊN — người duy nhất thật sự rủ được — chỉ đáng
     x1.1. Xem khối lý do trong `FriendService`.
     ⚠️ Trước 2026-08-21 phần **Wins hoàn toàn không được cài đặt**: HUD hứa x1.25 Wins mà
     `AwardWins` chưa bao giờ đọc tới `FriendService`. Nay đã nối, phạm vi hẹp `stage`/`stage_x2`
     như VIP / x2 Wins / Server Boost.
   - *Server Boost:* Mua bằng Robux toàn máy chủ (x2 Speed / x2 Wins).

---

## 4. CƠ CHẾ ĐIỂM DỪNG CHÂN (REST STOP PLATFORM) & BẢNG THƯỞNG STAGE

 World 1 gồm **15 Stage Obby**. Sau khi vượt qua chướng ngại vật của mỗi Stage, người chơi sẽ tiến vào **Điểm Dừng Chân (Rest Stop Platform / Checkpoint Island)**.

### A. Quy Tắc Hoạt Động Tại Bệ Dừng Chân
> **LƯU Ý QUAN TRỌNG:** Vạch Finish của Stage **KHÔNG tự động trao thưởng Wins**. Thưởng Wins chỉ được trao duy nhất khi người chơi bước lên một trong các Pad chuyên dụng tại Bệ dừng chân (`StageCheckpointService.luau`).

Tại Bệ dừng chân, người chơi có **4 lựa chọn chiến lược**:
1. 🚪 **Cổng Stage Kế (Chạy Tiếp):** Bước qua cổng sang Stage $N+1$. Người chơi chưa nhận Wins lúc này nhưng được quyền chinh phục các màn tiếp theo với mức thưởng Wins cao hơn hẳn.
2. 🟨 **`WinCollectionPad` (Nhận Wins & Về Lobby):** Dậm chân lên Pad vàng ➔ Nhận đủ Wins của Stage vừa vượt ➔ Hệ thống lập tức dịch chuyển (Teleport) về Lobby để mua trang bị.
3. 🟥 **`DoubleWinCollectionPad` (Nhận X2 Wins & Về Lobby):** Mua gói X2 Wins (49 R$) ➔ Nhận gấp đôi lượng Wins ➔ Teleport về Lobby.
4. 🏃 **`Treadmill` / `SkipStagePad` (Tập Luyện / Bỏ Qua):** Đứng trên Treadmill tại bệ dừng chân để cày thêm Speed tại chỗ, hoặc dậm lên `SkipStagePad` (39 R$) để bỏ qua màn tiếp theo.

---

### B. Bảng Chỉ Số Stage, Gợi Ý & Thưởng Wins (World 1)

| Stage | Tên Chướng Ngại Vật | Gợi Ý Level (`minLv`) | Gợi Ý WalkSpeed (`minWS`) | Thưởng Wins Chi Tiết (`STAGE_WINS`) |
| :---: | :--- | :---: | :---: | :---: |
| **1** | Keyboard Hop | 1 | 12 | **1 Win** |
| **2** | Laser Grid | 8 | 26 | **3 Wins** |
| **3** | Clashing Crushers | 16 | 42 | **10 Wins** |
| **4** | Boss Chase | 24 | 58 | **20 Wins** |
| **5** | Conveyor Chaos | 32 | 74 | **50 Wins** |
| **6** | Shrinking Platform | 40 | 90 | **100 Wins** |
| **7** | Crumbling Path | 48 | 106 | **150 Wins** |
| **8** | Spinning Sweeper | 56 | 122 | **300 Wins** |
| **9** | Tsunami Sprint | 64 | 138 | **500 Wins** |
| **10** | Slime Avalanche | 72 | 154 | **1,000 Wins** |
| **11** | Highway Mayhem | 80 | 170 | **2,500 Wins** |
| **12** | Wind Tunnel | 88 | 186 | **10,000 Wins** |
| **13** | Momentum Pinball | 96 | 202 | **25,000 Wins** |
| **14** | Floor Opens Canyon | 104 | 218 | **50,000 Wins** |
| **15** | Momentum Jumps | 112 | 234 | **150,000 Wins** |

- **Bonus Đặc Biệt Stage 15:** Lần đầu clear Stage 15 thưởng thêm **+50,000 Wins**.
- **Cooldown Thưởng:** $10\text{s}$ giữa các lần thu hoạch pad để chống spam.

---

## 5. KINH TẾ & TRANG BỊ

### A. Multiplier Pads (Bệ cày tốc độ ở Lobby)

| ID Pad | Tốc Độ Cơ Bản (Step) | Yêu Cầu Mở Khóa (Wins) |
| :--- | :---: | :---: |
| `pad_1` | +1 | 0 |
| `pad_2` | +2 | 3 |
| `pad_3` | +5 | 15 |
| `pad_4` | +25 | 100 |
| `pad_5` | +50 | 500 |
| `pad_6` | +100 | 2,500 |
| `pad_7` | +250 | 15,000 |
| `pad_8` | +500 | 50,000 |


### B. Treadmills (Máy chạy bộ VIP)

| Tên Treadmills | Multiplier | Giá Robux | Gamepass ID |
| :--- | :---: | :---: | :---: |
| **Wood Treadmill** | x1.0 | FREE | 0 |
| **Purple Treadmill** | x3.0 | 99 R$ | `1899470645` |
| **Blue Treadmill** | x9.0 | 249 R$ | `1898588703` |
| **Gold Treadmill** | x25.0 | 699 R$ | `1898528586` |
| **Red Admin Treadmill** | x100.0 | 1,299 R$ | `1900262663` |

### C. Trails (Vệt đuôi)

#### 1. Standard Trails (Mua bằng Wins HOẶC Robux)
| Tên Trail | Multiplier | Giá Wins | Giá Robux | Gamepass ID |
| :--- | :---: | :---: | :---: | :---: |
| **Green Trail** | x1.5 | 500 | 19 R$ | `1928360029` |
| **Blue Trail** | x2.0 | 1,500 | 39 R$ | `1928000089` |
| **Purple Trail** | x3.0 | 5,000 | 79 R$ | `1927832085` |
| **Red Trail** | x4.0 | 25,000 | 129 R$ | `1928300077` |
| **Rainbow Trail** | x5.0 | 100,000 | 199 R$ | `1928324050` |
| **Galaxy Trail** | x10.0 | 500,000 | 299 R$ | `1928756071` |

#### 2. Trail Độc Quyền (KHÔNG bán — chỉ rơi từ chuỗi điểm danh)
| Tên Trail | Multiplier | Nguồn duy nhất | Cờ chặn mua |
| :--- | :---: | :--- | :--- |
| **Streak Aurora** | x5.0 | Phần thưởng **Ngày 7** chuỗi điểm danh hardcore | `dailyOnly = true` |

> **Vì sao x5.0 (nâng từ x2.5):** mức 2.5 đặt nó giữa Blue (x2.0) và Purple (x3.0 – chỉ 5,000 Wins). Tới ngày thứ 7 thì gần như ai cũng đã mua nổi Purple ⇒ phần thưởng của bảy ngày kiên trì hoá ra **yếu hơn thứ họ đang đeo**. Phần thưởng dưới mức kỳ vọng còn hại hơn không có phần thưởng.
> x5.0 = ngang **Rainbow Trail (100,000 Wins / 199 R$)** — đọc ra là "món 199 R$", xứng với 7 ngày đăng nhập liên tục. Trần vẫn nguyên: Galaxy x10 và ba trail Robux-only x15/x22/x30 không bị đụng.
> **Đánh đổi:** mất một phần doanh thu Rainbow. Chấp nhận — nhóm đi trọn 7 ngày là nhóm gắn bó nhất, giữ họ đáng hơn vài lần bán lẻ, và họ vẫn còn Galaxy + premium để tiêu tiền.
> Server chặn mua bằng cờ `dailyOnly` kiểm **tường minh** (giống `spinOnly` của Frozen Bloom), không dựa vào `priceWins = 0`.

#### 3. Premium Display Trails (Bệ 3D Lobby - Mua Robux Pass)
| Tên Trail | Multiplier | Giá Robux | Gamepass ID |
| :--- | :---: | :---: | :---: |
| **Mystic Violet Trail** | x15.0 | 399 R$ | `1911802508` |
| **Golden Ray Trail** | x22.0 | 599 R$ | `1912472263` |
| **Crimson Fury Trail** | x30.0 | 899 R$ | `1911958542` |

### D. Auras (Hào quang)

#### 1. Standard Auras (Mua bằng Wins HOẶC Robux)
| Tên Aura | Multiplier | Giá Wins | Giá Robux | Gamepass ID | Ghi chú |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Blue Aura** | x1.2 | 200 | 19 R$ | `1930543869` | Standard |
| **Red Aura** | x1.8 | 2,000 | 39 R$ | `1928120079` | Standard |
| **Cyan Aura** | x2.5 | 8,000 | 69 R$ | `1927712117` | Standard |
| **Purple Aura** | x4.5 | 40,000 | 119 R$ | `1928156055` | Standard |
| **Pink Aura** | x8.0 | 200,000 | 199 R$ | `1930698462` | Standard |
| **Frozen Bloom** | **x10.0** | — | — | — | **CHỈ có trong Speed Roulette (1%)** — không bán bằng Wins lẫn Robux, không có pass |

> **Vì sao Frozen Bloom là x10.0** (nâng từ x3.5 ngày 2026-08-09): nó phải nằm đúng khe giữa
> hai tầng — **trên** mọi aura mua được bằng Wins (mạnh nhất là Pink x8.0) để cảm giác trúng
> 1% xứng đáng và là aura mạnh nhất mà người chơi F2P sở hữu được, nhưng **dưới** tầng premium
> bán bằng Robux (Dark x12) để không phá giá gamepass. Mức cũ x3.5 còn thua Purple x4.5 vốn
> mua thẳng bằng 40.000 Wins.

#### 2. Premium Display Auras (Bệ 3D Lobby - Mua Robux Pass)
| Tên Aura | Multiplier | Giá Robux | Gamepass ID |
| :--- | :---: | :---: | :---: |
| **Dark Aura** | x12.0 | 299 R$ | `1912234503` |
| **Flame Aura** | x18.0 | 499 R$ | `1909292663` |
| **Red Heart Aura** | x25.0 | 799 R$ | `1912096528` |

---

## 6. HỆ THỐNG TRÙNG SINH (REBIRTH SYSTEM)

- **Điều kiện Level tối thiểu:** $\text{Required Level} = 50 + (\text{Rebirths} \times 10)$
- **Hệ số nhân thưởng:** $\text{RebirthMultiplier} = 1 + (\text{Rebirths} \times 0.5)$
- **Quy tắc Reset:** Reset Speed về $0$, Level về $1$, XP về $0$.
- **Bảo lưu tài sản:** Giữ nguyên trọn vẹn Wins, Unlocked Pads, Unlocked Treadmills, Trails, Auras, và Gamepass.

---

## 7. CHIẾN LƯỢC MONETIZATION (GAMEPASS & DEV PRODUCTS)

### A. Hệ Thống Gamepass (Sở hữu vĩnh viễn)

| Tên Gamepass | Giá Robux | ID Creator Dashboard | Tính Năng / Quyền Lợi |
| :--- | :---: | :---: | :--- |
| **Double Speed (x2)** | 3 R$ | `1900262644` | Nhân đôi tốc độ cày Speed cơ bản |
| **Quad Speed (x4)** | 9 R$ | `1900160603` | Nhân 4 tốc độ cày Speed |
| **Octa Speed (x8)** | 27 R$ | `1898810606` | Nhân 8 tốc độ cày Speed |
| **Double Wins (x2)** | 399 R$ | `1940593812` | Nhân đôi Wins mỗi lần vượt Stage. Lý do giá & phạm vi: mục 7.A2 |
| **VIP Membership** | 399 R$ | `1899686706` | x1.5 Speed · x1.25 Wins/stage · VIP Gold Trail x6 + Aura x6 · vé quay 8 phút (trần 5) · teleport miễn phí · tag `[VIP]`. Chi tiết & lý do cân bằng: mục 7.A1 |
| **Auto-Rebirth** | 99 R$ | `1899434608` | Tự động Trùng sinh ngay khi đủ Level (có công tắc ON/OFF trong Rebirth modal) |
| **Infinite Revives** | 249 R$ | `1930442093` | Hồi sinh tại chỗ **không giới hạn số lần** khi ngã Obby (thay cho Revive 19 R$/lần) |
| **Extra Spin** | 149 R$ | *(In Dev)* | Quay Roulette 2 lượt cùng lúc, chọn ô tốt nhất |
| **Infinite Revives** | 249 R$ | `1930442093` | Hồi sinh tại chỗ không giới hạn số lần khi ngã Obby |

### A2. Double Wins (x2) — 399 R$ (2026-08-21, **ĐÃ TẠO & BẬT** — pass `1940593812`)

> Trạng thái: **đang bán**. Pass `1940593812` (managed pricing bật), nút cầu vồng bảy sắc ở
> cột phải HUD, server nhân đúng phạm vi `stage`/`stage_x2`.
>
> Cơ chế tắt an toàn vẫn còn: đặt `Config/Economy/Gamepass.DoubleWins = 0` thì nút TỰ ẨN và
> server không nhân gì — dùng khi cần gỡ pass khỏi bán mà không phải đụng vào code.

#### Vì sao 399 R$

Món này cạnh tranh trực tiếp với **`DoubleWinCollectionPad` (49 R$ / lượt)**, nên giá phải trả
lời được câu "mua bao nhiêu lần thì nên mua đứt":

| Giá pass | Hoà vốn sau | Hệ quả |
| :--- | :---: | :--- |
| 249 R$ | 5 lượt | Gần như xoá sổ doanh thu pad, và làm VIP 399 R$ (chỉ x1.25 Wins) trông hớ |
| **399 R$** | **~8 lượt** | Người chơi thường vẫn dùng pad; người cày nhiều mới mua đứt. Pad giữ được doanh thu |
| 699 R$ | ~14 lượt | An toàn cho pad nhưng ít người mua — món whale |

399 cũng **bằng đúng VIP Membership**, mà VIP chỉ cho x1.25 Wins trong một gói 7 quyền lợi ⇒
hai món không dẫm chân nhau: ai chỉ cần Wins thì mua pass này, ai cần cosmetic + tiện nghi thì
mua VIP. Đây là lần đầu shop có một món bán THUẦN bằng Wins.

#### Phạm vi — y hệt VIP, và vì y hệt lý do

Chỉ nhân ở `reason == "stage"` / `"stage_x2"` (`ProgressionService.AwardWins`). Đây là pass
MẠNH NHẤT trong nhóm nhân Wins (x2, không phải x1.25) nên phạm vi càng phải chặt:

- Nhân cả `product` ⇒ Ultra Wins Pack 1.299 R$ tự nhân đôi cho người có pass — **tự phá giá
  món đắt nhất shop bằng một món rẻ hơn ba lần**.
- Nhân `daily` / `roulette` / `code` ⇒ phá lại phép siết bảng điểm danh xuống 1.177 Wins/tuần
  (mục 8.A1).

#### Cộng dồn: có, thành x4

`stage_x2` KHÔNG bị loại trừ, nên **có pass + dậm `DoubleWinCollectionPad` = x4 Wins**. Đây là
ý đồ, không phải sơ suất: nếu chặn, pad 49 R$ trở thành nút chết với đúng nhóm khách đã chi
nhiều nhất. Cộng dồn tiếp với group chest (+10%), VIP (x1.25), Server Boost và event — cùng
cách mọi hệ số Wins khác đang cộng dồn.

### A1. VIP Membership — Thiết kế lại (2026-08-12, **ĐÃ TRIỂN KHAI**)

> Trạng thái: đã code đủ 7 quyền lợi. Mục này ghi lại **vì sao từng con số là con số đó** —
> đọc trước khi chỉnh bất cứ giá trị nào ở đây.

#### Hai vấn đề của bản cũ (đã sửa)

**1. Thẻ shop từng quảng cáo thứ không tồn tại.** `HUD/Theme.luau` →
`SHOP_CATALOG.utility.vip_membership` ghi *"x1.5 Speed + x1.2 Wins"* và *"[VIP] tag + VIP
Trail + VIP Aura"*, trong khi code chỉ có x1.5 Speed + tag chat: không có hệ số Wins, và cả
`Trails.luau` lẫn `Auras.luau` đều không có mục VIP nào. Người bỏ 399 R$ không nhận được thứ
họ đọc trên thẻ. Giờ cả năm quyền lợi đều có thật và thẻ shop mang chú thích chỉ tới đúng
nơi sinh ra từng con số.

**2. Món đắt nhất shop từng là món yếu nhất tính trên mỗi Robux.** Cả VIP lẫn Speed Pass đều đổ
vào cùng **xô Premium cộng dồn**, nên so được trực tiếp:

| Món | Giá | Cộng vào xô Premium | Robux / mỗi +1 |
| :--- | :---: | :---: | :---: |
| Double Speed x2 | 3 R$ | +1 | 3 |
| Octa Speed x8 | 27 R$ | +7 | **3.9** |
| Purple Treadmill x3 | 99 R$ | +2 | 49.5 |
| **VIP Membership** | **399 R$** | **+0.5** | **798** |

Người chơi biết tính sẽ không bao giờ mua VIP để lấy tốc độ. Vậy VIP **không được** bán bằng
hệ số tốc độ — nó phải bán bằng thứ Speed Pass không có: **cosmetic độc quyền + dòng chảy
tài nguyên đều đặn + tiện nghi**. Đó là định nghĩa của "membership", khác hẳn "pass".

#### Gói VIP mới — giữ giá 399 R$

| # | Quyền lợi | Số | Nơi thực thi |
| :---: | :--- | :--- | :--- |
| 1 | Speed farm | **x1.5** (+0.5 xô Premium) | `ProgressionService.computeVipMultiplier` |
| 2 | Wins khi vượt Stage | **x1.25** | `ProgressionService.AwardWins` (`VIP_WINS_MULTIPLIER`) |
| 3 | **VIP Gold Trail** (độc quyền, không bán) | **x6.0** | `Trails.luau` → `trail_vip` |
| 4 | **VIP Gold Aura** (độc quyền, không bán) | **x6.0** | `Auras.luau` → `aura_vip`, rig `Aura_Vip` |
| 5 | Vé quay miễn phí | hồi **15 → 8 phút**, trần tích **3 → 5 vé** | `Config/Roulette.VIP_TICKET_*` |
| 6 | Teleport | **miễn phí tới nơi ĐÃ TỪNG ĐẾN** (stage ≤ cao nhất +1) | `TeleportService.tryPayWins` |
| 7 | Tag `[VIP]` vàng trong chat | — | `ChatTagController` (attribute `IsVIP`) |

Đường trao hai món cosmetic: `GamepassService.grantVipCosmetics` — chạy cả lúc mua trong
session lẫn lúc profile load (người mua trên web / mua trước khi có hai món này).

#### Vì sao từng con số — và vì sao nó KHÔNG phá kinh tế

**Mục 2 — x1.25 Wins, chỉ ở `reason == "stage"` / `"stage_x2"`.** Đúng phạm vi mà Group Chest
(+10%), Server Boost và event đang dùng. Cộng dồn với group ⇒ **x1.375**, không phải x1.5.
Phạm vi hẹp này là điều kiện sống còn: nếu nhân cả `product`, gói Ultra Wins Pack 1.299 R$
tự nhiên thành 1.250.000 Wins cho người có VIP — tự phá giá chính món đắt thứ hai của shop.
Cũng không nhân `daily` / `roulette` / `code`, vì bảng daily đã bị siết xuống 1.177 Wins/tuần
có chủ đích (mục 8.A1) — nhân lên là phá lại chính phép siết đó.

**Mục 3 & 4 — vì sao đúng x6.0.** Hai món này rơi vào **xô Cosmetic cộng dồn**, nên người mua
VIP tay trắng vẫn có ngay $1 + 5 + 5 = \mathbf{x11}$. Mức 6.0 được chọn để nằm lọt đúng khe
giữa hai tầng đang bán:

| Tầng | Trail | Aura |
| :--- | :--- | :--- |
| Cày bằng Wins (F2P) | Rainbow x5.0 (100k Wins / 199 R$) | Pink x8.0 (200k Wins / 199 R$) |
| **VIP x6.0** | **trên** Rainbow, **dưới** Galaxy | **dưới** Pink — Pink vẫn đáng mua |
| Robux tầng cao | Galaxy x10 (299 R$), Mystic x15 (399), Golden x22 (599), Crimson x30 (899) | Dark x12 (299), Flame x18 (499), Red Heart x25 (799) |

Hai kiểm tra bắt buộc đều đạt: (a) người bỏ 399 R$ phải nhận được thứ **mạnh hơn** món 199 R$
— trail x6 > Rainbow x5 ✅; (b) **không** được chạm tới tầng 299 R$ trở lên — x6 < Galaxy x10
và < Dark x12 ✅. Riêng aura cố ý để **thấp hơn** Pink x8: nếu không, aura bán bằng Wins
mạnh nhất của F2P trở thành vô nghĩa với mọi người mua VIP.

Về mặt tài nguyên: cosmetic **không sinh ra Wins hay Speed** ngoài hệ số của chính nó, nên
đây là quyền lợi có giá trị cảm nhận cao nhất mà tốn của nền kinh tế ít nhất — đúng vai trò
mà Rookie Rocket đang gánh cho Starter Pack.

**Mục 5 — vé quay.** 15 → 8 phút là **~x1.9 tốc độ farm vé**, trần 3 → 5 để người AFK dài
không bị phí. Vẫn phải **online** mới hồi, và cơ cấu ô không đổi — Frozen Bloom vẫn 1%, trung
bình ~100 lượt. Nghĩa là VIP rút ngắn thời gian chờ chứ không mua được jackpot. Gói vé Robux
(19/79/149 R$) vẫn còn nguyên lý do tồn tại: ai muốn quay **ngay bây giờ** vẫn phải trả.

**Mục 6 — teleport miễn phí, nhưng CHỈ TỚI CHỖ ĐÃ TỪNG ĐẾN.**

> ⚠️ **Lỗi đã sửa trong ngày (2026-08-12).** Bản đầu cho VIP miễn phí MỌI điểm đến. Nhưng trong
> game này **giá Wins chính là cổng khoá duy nhất** — `TeleportService` ghi rõ ở dòng đầu:
> *"Player được TỰ DO teleport: không còn chặn theo Level/WalkSpeed"*. Bỏ giá cho VIP là bỏ
> luôn cổng: mua pass xong nhảy thẳng Stage 15 mà chưa chạy màn nào. **Toàn bộ nội dung obby —
> thứ mà cả game được dựng quanh nó — bị bỏ qua trong một cú bấm.** Người chơi phát hiện ngay
> khi trang bị thử.

Luật đúng: miễn phí trong phạm vi người chơi **đã tự đi tới**, ngoài phạm vi đó trả giá như mọi
người. Mốc là `HighestCompletedStage + 1`, không phải `+0`: về đích stage N là người chơi đứng
ngay đầu stage N+1, chỗ đó họ đã đến rồi nên bắt trả tiền để quay lại là vô lý; còn N+2 trở đi
thì chưa từng đặt chân — đó là ranh giới.

Bài học chung, đáng nhớ hơn cả con số: **trước khi cho một quyền lợi "miễn phí X", phải hỏi X
đang gánh vai trò gì trong hệ thống.** Ở đây giá Wins trông như một sink kinh tế, nhưng thực ra
nó là cổng tiến trình — miễn phí nó không phải là giảm giá, mà là gỡ khoá.

Sink Wins vẫn còn nguyên với nhóm VIP ở đúng chỗ đáng kể nhất: teleport vượt tuyến (stage chưa
tới) vẫn phải trả đủ, kể cả 100.000 Wins của Stage 15.

**Cố ý KHÔNG đụng xô Rebirth.** Đó là xô duy nhất **nhân liên hoàn** ($1 + \text{Rebirths}
\times 0.5$). Mọi quyền lợi VIP ở trên đều nằm trong các xô **cộng dồn**, nên tác động của
chúng bị chặn trên; nhét VIP vào xô Rebirth là mở cửa cho lạm phát cuối game.

#### Thẻ shop đọc ra thế nào

```
VIP MEMBERSHIP                             399 R$
x1.5 Speed · x1.25 Wins · FREE Teleport
Gold Trail x6 + Gold Aura x6 · 2x spins · [VIP]
```

Cộng riêng phần cosmetic đã ngang hai món 199 R$, chưa tính x1.25 Wins vĩnh viễn — thẻ tự
biện minh được cái giá 399 mà không cần bịa con số "giá gốc" nào.

#### Bộ mặt của hai món cosmetic VIP

**VIP Gold Trail** — dùng **bộ 5 ribbon của dòng trail cao cấp**, tức đúng cấu trúc mà Mystic
Violet và Crimson Fury đang dùng (2 lớp hoạ tiết sáng chồng trên 3 lớp nền); hai món đó vốn
chỉ khác nhau ở bảng màu, nên một bản vàng là cách nhập gia đúng ngôn ngữ của dòng này. Template:
`ReplicatedStorage.CosmeticTemplates.PremiumTrails.trail_vip`, đi qua đường dựng premium sẵn có.

> **Vì sao bỏ hướng "một ribbon + texture sparkles" (2026-08-12):** texture đốm lặp dọc vệt,
> mà chiều dài vệt lại co giãn theo tốc độ chạy ⇒ các đốm tách rời và vệt nhìn **đứt quãng**.
> Ribbon liền không có bệnh đó. Bảng `TRAIL_VISUALS.trail_vip` giờ chỉ còn là bản dự phòng khi
> thiếu template, và cũng đã bỏ texture.

Màu: thân vàng ròng (ánh kim → vàng → hổ phách) trên nền **đồng sẫm** — giữ đúng tỉ lệ
"nền tối hơn thân" của Mystic, vì chính cái chênh đó tạo chiều sâu. Hai lớp khói của Mystic bị
gỡ: khói tím đọc ra là bí ẩn, còn khói trên nền vàng chỉ thành vệt xám bẩn.

**VIP Gold Aura** — rig `Aura_Vip` dựng từ model **Aura_SusanooArms**, đã gỡ hết phần "hai cánh
tay" (10 Beam trên HumanoidRootPart + 2 cụm lửa ở gốc tay) và nhuộm sang palette uy quyền:
**vàng ròng trên nền tím hoàng gia gần đen**. Lớp tối được giữ lại có chủ đích — vàng cần nền
tương phản mới ra vẻ uy quyền — nhưng thưa và mờ bớt, vì dày quá thì đọc ra là bồ hóng bám người.
Đỉnh sáng cố ý **không** phải ivory gần trắng: 5-6 lớp chồng lên nhau là bão hoà cả ba kênh, lõi
cháy trắng và nuốt luôn nhân vật. Nguyên tắc rút ra: một aura mà nhìn không ra người chơi thì
không phải aura, đó là màn khói.

Model gốc `Workspace.Aura_SusanooArms` **giữ nguyên** (còn cả hai tay) — nó là asset nguồn, bản
VIP là bản sao đã cắt.

#### Đường hồi quy khi cần chỉnh

| Muốn đổi | Sửa ở đâu | Cẩn thận |
| :--- | :--- | :--- |
| Hệ số Wins | `ProgressionService.VIP_WINS_MULTIPLIER` | giữ nguyên bộ lọc `reason` — nới ra là phá giá Wins Packs |
| Hệ số 2 cosmetic | `Trails.luau` / `Auras.luau` | phải ở giữa tầng Wins và tầng premium Robux; xem hai bảng trên |
| Nhịp vé quay | `Config/Roulette.VIP_TICKET_*` | dưới 8 phút là VIP tự cày ra Frozen Bloom, giết ba gói vé Robux |
| Teleport | `TeleportService.tryPayWins` | client `TeleportModal` cũng phải biết, nếu không UI chặn trước khi packet đi |
| Hình/màu trail | `CosmeticTemplates.PremiumTrails.trail_vip` | sửa ở TEMPLATE, không phải `TRAIL_VISUALS` (bảng đó chỉ là dự phòng). Đừng quay lại texture đốm — vệt sẽ đứt quãng |
| VFX aura | `CosmeticTemplates.Aura_Vip` | part phải NEO; rig này KHÔNG được fallback về aura standard (`RIG_AURAS`) |

### B. Developer Products (Tiêu hao & Tiện ích)

| Gói Sản Phẩm | Giá Robux | Product ID | Mô Tả Tính Năng |
| :--- | :---: | :---: | :--- |
| **Revive (Hồi sinh)** | 19 R$ | `3608405576` | Hồi sinh tại vị trí chết khi đi Obby |
| **Skip Stage** | 39 R$ | `3608405926` | Bỏ qua Stage hiện tại, sang màn kế tiếp |
| **Double Wins (`DoubleWinCollectionPad`)** | 49 R$ | `3608406804` | Nhận x2 Wins khi dậm pad ở bệ dừng chân & về Lobby |
| **Skip Rebirth** | 149 R$ | `3608406966` | Trùng sinh ngay lập tức không cần đủ Level |
| **Small Wins Pack** | 99 R$ | `3608400621` | Cộng +1,000 Wins ngay |
| **Medium Wins Pack** | 299 R$ | `3608400807` | Cộng +10,000 Wins ngay |
| **Large Wins Pack** | 699 R$ | `3608401003` | Cộng +100,000 Wins ngay |
| **Ultra Wins Pack** | 1,299 R$ | `3608401110` | Cộng +1,000,000 Wins ngay |
| **Server x2 Speed (10m)** | 99 R$ | `3608407713` | Buff x2 Speed cho toàn bộ server |
| **Server x2 Wins (10m)** | 99 R$ | `3608407843` | Buff x2 Wins cho toàn bộ server |
| **MEGA Server Boost (10m)**| 149 R$ | `3608407916` | Buff x2 Speed & x2 Wins toàn server |
| **1 Roulette Spin Ticket** | 19 R$ | `3610356888` | Mua 1 lượt quay Vòng quay may mắn |
| **5 Roulette Spin Tickets**| 79 R$ | `3610357071` | Mua 5 lượt quay Vòng quay may mắn |
| **10 Roulette Spin Tickets**| 149 R$ | `3610357149` | Mua 10 lượt quay Vòng quay may mắn |

---

## 8. RETENTION, SOCIAL & LIVE-OPS

### A0. Trải Nghiệm 3 Phút Đầu (FTUE) — Daily trước, Tutorial sau

Thứ tự cố ý: **món quà đầu tiên phải tới trước công việc đầu tiên.**

```
Vào game ──► [DAILY REWARDS mở ngay]  ──► CLAIM: +1,000 Speed & +2 Wins
                                              │
                                              ▼
                    [TUTORIAL 3 BƯỚC — tia sáng + mũi tên chỉ đường, có nút SKIP]
                                              │
   Bước 1 ─ Chạy Stage 1 → dậm pad vàng chốt Wins    (+1 Win của Stage 1)
   Bước 2 ─ (tự teleport về Lobby) → mở khoá Multiplier Pad 2
   Bước 3 ─ Bước lên Treadmill x1                    ──► HOÀN THÀNH
                                              │
                          KHÔNG thưởng gì ──► [GROUP CHEST mở]
```

**Tutorial KHÔNG phát phần thưởng.** Toàn bộ quà của người chơi mới nằm ở Daily Ngày 1, phát **trước** khi tutorial bắt đầu. Nhờ vậy `TutorialService` không đụng gì vào kinh tế, và cũng không cần bù Wins để mở Pad 2 (xem ràng buộc ngay dưới).

**Vì sao đảo ngược thứ tự so với tutorial simulator thường thấy (farm trước, chạy sau):**
Bước 1 ném thẳng người chơi vào Obby + khoảnh khắc ăn Wins — phần vui nhất và **khác biệt nhất** của game (sàn ASMR, quyết định tham lam) — trong vòng một phút đầu. Cày cuốc để sau, khi họ đã có lý do để cày.

**Ràng buộc số học đã chốt — ba con số khoá chặt nhau:**

```
Daily Ngày 1 = 2 Wins   +   Stage 1 = 1 Win   =   3 Wins   =   ĐÚNG mốc mở Pad 2
```

Mở pad là so **ngưỡng** `TotalWins` (không trừ tiền) nên 3 Wins vừa khít. ⚠️ Đổi `requiredWins` của pad_2, thưởng Wins Ngày 1, hoặc `STAGE_WINS[1]` thì **phải kiểm lại phép cộng này** — lệch xuống là bước 2 thành ngõ cụt "Need 3 Wins" và người chơi mới kẹt không có đường ra.

**Nguyên tắc triển khai:**
- Tutorial **không chặn điều khiển**, không hộp thoại chữ, không làm tối màn hình. Chỉ Beam cong + mũi tên nhấp nhô + một dòng nhắc.
- Mọi bước gắn vào **sự kiện gameplay server đã tự biết** (chốt Wins / mở pad / lên treadmill) ⇒ không có packet "tôi xong rồi" nào để giả mạo.
- Người bấm **SKIP** được đánh dấu riêng (`TutorialSkipped`) để số liệu phễu không trộn với người đi hết. Không ai mất gì khi skip vì tutorial vốn không thưởng.
- 3 bước khớp phễu `TelemetryService.Onboarding` ⇒ đọc tỉ lệ rơi thẳng trên Creator Hub.

### A1. Điểm Danh 7 Ngày (Daily Rewards — Hardcore Streak)

Lỡ **một** ngày → chuỗi reset về Ngày 1. Luật khắc nghiệt này chỉ có sức nặng vì cuối chuỗi là món **không mua được**.

| Ngày | Phần thưởng |
| :---: | :--- |
| **1** | +1,000 Speed · **+2 Wins** |
| **2** | +5,000 Speed · x2 Speed Boost (10 phút) |
| **3** | +25 Wins · 🎟️ 1 Spin |
| **4** | +25,000 Speed · x2 Wins Boost (10 phút) |
| **5** | +150 Wins · 🎟️ 2 Spins |
| **6** | +150,000 Speed · MEGA Server Boost (10 phút) |
| **7** | 🌈 **STREAK AURORA TRAIL (độc quyền)** · +1,000 Wins · 🎟️ 3 Spins |

**Triết lý cân bằng (sửa 2026-08-10):** bản cũ phát **14,300 Wins/tuần**, riêng Ngày 1 đã 300 Wins — bấm một cái là nhảy thẳng qua pad_2/3/4 (3/15/100 Wins), bỏ qua trọn đoạn chơi mà phần đầu game được thiết kế để dạy. Bảng mới đảo trục:

- **Speed là xương sống** (ngày 2/4/6: 5K → 25K → 150K). Speed cộng thẳng vào XP ⇒ thành Level ⇒ thành WalkSpeed — thứ **cảm nhận được ngay dưới chân** và **không dùng để mua vượt cấp** bất cứ gì.
- **Wins bị siết còn 1,177/tuần** (từ 14,300): đủ để thấy tiến lên, không đủ để nhảy cóc.
- **Ngày 7 là món độc quyền**, không phải một đống số.

> Hạn chế đã biết: bảng thưởng đang **cố định**, nên với người chơi cuối game (Stage 14 = 50,000 Wins/lượt) phần Wins gần như vô nghĩa. Hướng nâng cấp: cho thưởng **thang theo Rebirth/Level**. Chưa làm.

### A. Vòng Quay May Mắn (Speed Roulette)
- **Tự động tặng lượt quay:** Mỗi **15 phút online** liên tục nhận 1 lượt quay miễn phí (Tối đa tích trữ 3 vé).
- **Cơ cấu phần thưởng (8 Ô):**
  1. `+500 Wins` (Common - 25%)
  2. `+5,000 Speed` (Common - 25%)
  3. `+2,500 Wins` (Uncommon - 15%)
  4. `x2 Speed Boost (10 Phút)` (Uncommon - 15%)
  5. `x2 Wins Boost (10 Phút)` (Rare - 10%)
  6. `+15,000 Wins` (Epic - 6%)
  7. `+100,000 Speed` (Epic - 3%)
  8. **Frozen Bloom Aura** (Legendary - 1%) *(Đền bù 50,000 Wins nếu đã sở hữu)*

### B. Group Join Rewards & Social Features
- Tag Chat `[Fan]` / `[Member]`.
- Thưởng vĩnh viễn: **+10% Wins** mỗi khi hoàn thành Stage.
- Thưởng khởi nghiệp: **+5,000 Speed** khi nhận Group Chest.

### C. Mã Quà Tặng (Promo Codes)

| Mã Code | Phần Thưởng Kích Hoạt |
| :--- | :--- |
| **`RELEASE`** | +1,000 Wins & 🎟️ 1 Spin Ticket |
| **`SPEED`** | +5,000 Speed Boost |
| **`FREEWINS`** | +2,500 Wins |
| **`LUCKY`** | +10,000 Speed & 🎟️ 2 Spin Tickets |

---

## 9. ROADMAP WORLD 2 & ĐỊNH HƯỚNG MỞ RỘNG (LEVEL 121 - 220)

- **Điều kiện mở khóa World 2:** Hoàn thành Stage 15 (World 1).
- **Chủ đề thiết kế (Theme):** Neon Cyber City (Cyberpunk, Glitch Lighting, Moving Lasers).
- **Đường cong lạm phát XP:** Hàm mũ `1.082^(Level - 120)` từ Level 120 trở lên.
- **Hệ thống Kinh tế Mới:** Thêm 15 Stage mới (Stage 16 - 30), Multiplier Pads cấp số nhân hàng triệu, Mở rộng giới hạn WalkSpeed tối đa lên **444 studs/s** (Stage 30).
