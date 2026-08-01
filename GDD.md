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
   - *Friends Boost:* +10% mỗi bạn bè trong server (Tối đa x1.5).
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

#### 2. Premium Display Trails (Bệ 3D Lobby - Mua Robux Pass)
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
| **Frozen Bloom** | x3.5 | — | — | — | **CHỈ có trong Speed Roulette (1%)** — không bán bằng Wins lẫn Robux, không có pass |

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
| **VIP Membership** | 399 R$ | `1899686706` | Tag `[VIP]` chat, x1.5 Speed, x1.2 Wins |
| **Auto-Rebirth** | 99 R$ | `1899434608` | Tự động Trùng sinh ngay khi đủ Level (có công tắc ON/OFF trong Rebirth modal) |
| **Infinite Revives** | 249 R$ | `1930442093` | Hồi sinh tại chỗ **không giới hạn số lần** khi ngã Obby (thay cho Revive 19 R$/lần) |
| **Extra Spin** | 149 R$ | *(In Dev)* | Quay Roulette 2 lượt cùng lúc, chọn ô tốt nhất |
| **Infinite Revives** | 249 R$ | `1930442093` | Hồi sinh tại chỗ không giới hạn số lần khi ngã Obby |

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
