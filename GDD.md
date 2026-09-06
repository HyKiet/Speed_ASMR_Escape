# +1 SPEED ESCAPE — GAME DESIGN DOCUMENT

| | |
| :--- | :--- |
| **Thể loại** | Speed Simulator × Obby |
| **Nền tảng** | Roblox · canvas 1920×1080 · PC + Mobile |
| **Phiên bản GDD** | 3.0 — 2026-09-06 |
| **Quy mô World 1** | 15 stage · 8 multiplier pad · 5 treadmill · trùng sinh vô hạn |

**Tóm tắt:** người chơi cày chỉ số Speed để lên Level, Level mở WalkSpeed thật, dùng WalkSpeed
vượt 15 màn obby để kiếm Wins, tiêu Wins mua sức mạnh và trang bị, rồi trùng sinh để bắt đầu lại
với hệ số cày cao hơn.

---

## 1. VÒNG LẶP CỐT LÕI

```
  [1] CÀY SPEED ─────► [2] LÊN LEVEL ─────► [3] MỞ WALKSPEED ─────► [4] CHẠY OBBY
   treadmill / pad        Speed = XP           +2 studs/s mỗi Lv        15 stage
        ▲                                                                   │
        │                                                                   ▼
        │                                                    [5] BỆ DỪNG CHÂN — chọn 1 trong 4
        │                                                    ├─ chốt Wins → Lobby
        │                                                    ├─ x2 Wins (49 R$) → Lobby
        │                                                    ├─ Skip Stage (39 R$)
        │                                                    └─ chạy tiếp stage N+1
        │                                                                   │
        └──────── [7] TRÙNG SINH ◄──────── [6] TIÊU WINS ◄─────────────────┘
```

---

## 2. TIỀN TỆ

| | **Speed** | **Wins** |
| :--- | :--- | :--- |
| Vai trò | XP | tiền tiêu |
| Nguồn | treadmill, multiplier pad, offline, daily, quest, roulette, code | vượt stage |
| Reset khi trùng sinh | **Có** | Không |
| Chi cho | — | pad · trail · aura · emote · teleport · phí trùng sinh |

**Luật:**
1. Daily / code / roulette / offline phát Speed. Wins chỉ đến từ obby và các mốc ghi ở mục 7.
2. Mọi thứ mua bằng Wins là sở hữu vĩnh viễn; tiêu Wins không làm giảm sức mạnh.

---

## 3. TIẾN TRÌNH

### 3.1 Đường cong Level

Speed → XP tỉ lệ 1:1. XP cần để lên từ Level *L*:

| Băng | Level | Công thức |
| :--- | :---: | :--- |
| Sprint | 1 – 30 | `req(L) = 5 × 1,25^(L−1)` |
| Marathon | 31 + | `req(L) = 3.675 × 1,157^(L−30)` |

| Level | 2 | 10 | 20 | 30 | 50 | 80 | 111 | 120 |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| XP cần | 6 | 37 | 347 | 3.235 | 67.900 | 5,39M | 495,75M | 1,84B |
| Cộng dồn | 5 | 129 | 1.400 | 12.900 | 421.600 | 34,35M | 3,16B | 11,73B |
| WalkSpeed | 16 | 32 | 52 | 72 | 112 | 172 | 234 | 250 |

### 3.2 WalkSpeed

```
WalkSpeed = min(250 , 14 + (Level − 1) × 2)
```

- Level 1 = 14 studs/s. Trần 250 chạm ở Level 119.
- ⚠️ Phải khớp `StarterPlayer.CharacterWalkSpeed` trong map. Đổi số nền = đổi tầm nhảy của cả
  15 zone (tầm nhảy = WalkSpeed × 0,542 s); phải đo lại hố rộng nhất mọi stage trước khi hạ.

### 3.3 Hệ số cày

```
Speed mỗi tick (0,35 s) = PadStep × Premium × Cosmetic × Rebirth × LiveOps
```

| Xô | Cách cộng | Thành phần |
| :--- | :--- | :--- |
| Premium | cộng dồn | Treadmill *(chỉ khi đang đứng trên treadmill)* + Speed Pass (bậc cao nhất) + VIP (+0,5) |
| Cosmetic | cộng dồn | Trail + Aura đang trang bị |
| Rebirth | **nhân liên hoàn** | mục 3.4 |
| LiveOps | nhân liên hoàn | Friends × Server Boost × Event |

Cộng dồn = `1 + (a−1) + (b−1)`. Hai món x3 và x9 cho ra x11.
⚠️ Không quyền lợi gamepass nào được đưa vào xô Rebirth.

### 3.4 Trùng sinh

Reset Speed → 0, Level → 1, XP → 0. Giữ nguyên Wins, pad, treadmill, trail, aura, emote,
gamepass, tiến trình stage.

```
Level cần   = {10,20,32,46,62,80,100,120}[R]      nếu R ≤ 8
              120 + (R − 8) × 4                    nếu R ≥ 9
Hệ số cày   = 1 + 0,5R                             nếu R ≤ 3
              2,5 × 1,45^(R−3)                     nếu R ≥ 4
Phí Wins    = 0                                    nếu R ≤ 5
              50.000 × 2,6^(R−6)                   nếu R ≥ 6
```

| Lần | R1 | R2 | R3 | R4 | R5 | R6 | R7 | **R8** | R9 | R10 | R12 | R15 | R20 |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Level | 10 | 20 | 32 | 46 | 62 | 80 | 100 | **120** | 124 | 128 | 136 | 148 | 168 |
| Hệ số | 1,50 | 2,00 | 2,50 | 3,63 | 5,26 | 7,62 | 11,05 | **16,02** | 23,24 | 33,69 | 70,84 | 215,95 | 1.384,19 |
| Phí Wins | — | — | — | — | — | 50K | 130K | **338K** | 879K | 2,28M | 15,45M | 271,5M | 32,25B |

**R8 = điều kiện mở World 2.**

### 3.5 Nhịp mục tiêu

| Mốc | F2P | 129 R$ | 525 R$ | 2.523 R$ |
| :--- | ---: | ---: | ---: | ---: |
| Stage 5 | 9 phút | — | — | — |
| Stage 10 | 38 phút | — | — | — |
| Stage 15 | 6,1 giờ | 45 phút | 34 phút | 20 phút |
| Trùng sinh 8 (World 2) | 15,0 giờ | 1,6 giờ | 1,1 giờ | 23 phút |
| Trùng sinh 12 | 99,8 giờ | 10,1 giờ | 6,5 giờ | 1,7 giờ |
| Trùng sinh 16 | 297,6 giờ | 59,0 giờ | 45,3 giờ | 21,2 giờ |

Từ R8 trở đi mỗi bậc trùng sinh dài hơn bậc trước ~1,23×.

**Chỉ số sức khoẻ mục tiêu:** Wins tiêu / Wins kiếm ≥ 60% · thời gian trong obby ≥ 30%.
Đo được ở cấu hình hiện tại: **86%** và **36%**.

---

## 4. OBBY

### 4.1 Bệ dừng chân

Vạch Finish không trao thưởng. Wins chỉ đến từ pad tại bệ dừng chân.

| Thành phần | Chức năng | Giá |
| :--- | :--- | :--- |
| 🟨 `WinCollectionPad` | nhận Wins của stage vừa qua → teleport về Lobby | — |
| 🟥 `DoubleWinCollectionPad` | nhận x2 Wins → teleport về Lobby | 49 R$ |
| ⏭️ `SkipStagePad` | bỏ qua stage kế tiếp | 39 R$ |
| 🏃 `Treadmill_x1` | cày Speed tại chỗ | — |
| 🚪 Cổng stage kế | chạy tiếp sang stage N+1 | — |

Cooldown giữa hai lần dậm pad: 10 giây.
*(Zone 15 hiện thiếu `SkipStagePad` — đúng ý đồ — và thiếu `Treadmill_x1` — cần bổ sung.)*

### 4.2 Bảng stage

| Stage | Tên | Gợi ý Lv | Gợi ý WS | Wins |
| :---: | :--- | :---: | :---: | ---: |
| 1 | Keyboard Hop | 1 | 12 | 2 |
| 2 | Laser Grid | 8 | 26 | 5 |
| 3 | Clashing Crushers | 16 | 42 | 12 |
| 4 | Boss Chase | 24 | 58 | 30 |
| 5 | Conveyor Chaos | 32 | 74 | 75 |
| 6 | Shrinking Platform | 40 | 90 | 180 |
| 7 | Crumbling Path | 48 | 106 | 420 |
| 8 | Spinning Sweeper | 56 | 122 | 1.000 |
| 9 | Tsunami Sprint | 64 | 138 | 2.400 |
| 10 | Slime Avalanche | 72 | 154 | 5.500 |
| 11 | Highway Mayhem | 80 | 170 | 13.000 |
| 12 | Wind Tunnel | 88 | 186 | 30.000 |
| 13 | Momentum Pinball | 96 | 202 | 70.000 |
| 14 | Floor Opens Canyon | 104 | 218 | 160.000 |
| 15 | Momentum Jumps | 112 | 234 | 400.000 |

Cột Gợi ý là biển báo, **không chặn người chơi**. Không có bonus lần đầu, không có thưởng chuỗi.

### 4.3 Teleport

| Đích | S2 | S3 | S4 | S5 | S6 | S7 | S8 | S9 | S10 | S11 | S12 | S13 | S14 | S15 |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Wins | 3 | 8 | 20 | 50 | 120 | 300 | 700 | 1.700 | 4.000 | 9.000 | 21.000 | 48.000 | 110.000 | 260.000 |

- Lobby miễn phí. Chỉ bán bằng Wins.
- VIP miễn phí tới `HighestCompletedStage + 1`, ngoài phạm vi đó trả đủ.
- ⚠️ Ràng buộc cứng: `Wins(N−1) < giá(N) < Wins(N)`. Đổi bảng 4.2 là phải tính lại bảng này.

---

## 5. KINH TẾ

### 5.1 Multiplier Pad

Mua một lần bằng Wins, sở hữu vĩnh viễn.

| Pad | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Speed / bước | +1 | +3 | +8 | +25 | +50 | +100 | +250 | +500 |
| Giá Wins | 0 | 1 | 12 | 40 | 120 | 600 | 3.500 | 18.000 |

- ⚠️ Bảng dừng ở 8 vì map chỉ dựng 8 pad. Thêm pad = dựng trong map trước.
- ⚠️ `pad_2` (1 Wins) ≤ `Stage 1` (2 Wins) — bước 2 tutorial phải tự nuôi được.

### 5.2 Trail

| Trail | Hệ số | Wins | Robux | Nguồn |
| :--- | :---: | ---: | ---: | :--- |
| Green | x1,5 | 500 | 19 R$ | shop |
| Blue | x2,0 | 1.500 | 39 R$ | shop |
| Purple | x3,0 | 5.000 | 79 R$ | shop |
| Red | x4,0 | 25.000 | 129 R$ | shop |
| Rainbow | x5,0 | 100.000 | 199 R$ | shop |
| Galaxy | x10,0 | 500.000 | 299 R$ | shop |
| Rookie Rocket | x2,5 | — | — | Starter Pack |
| Streak Aurora | x5,0 | — | — | Điểm danh Ngày 7 |
| VIP Gold | x6,0 | — | — | VIP Membership |
| Mystic Violet | x15,0 | — | 399 R$ | bệ 3D Lobby |
| Golden Ray | x22,0 | — | 599 R$ | bệ 3D Lobby |
| Crimson Fury | x30,0 | — | 899 R$ | bệ 3D Lobby |

### 5.3 Aura

| Aura | Hệ số | Wins | Robux | Nguồn |
| :--- | :---: | ---: | ---: | :--- |
| Blue | x1,2 | 200 | 19 R$ | shop |
| Red | x1,8 | 2.000 | 39 R$ | shop |
| Cyan | x2,5 | 8.000 | 69 R$ | shop |
| Purple | x4,5 | 40.000 | 119 R$ | shop |
| Pink | x8,0 | 200.000 | 199 R$ | shop |
| VIP Gold | x6,0 | — | — | VIP Membership |
| Frozen Bloom | x10,0 | — | — | Roulette 1% |
| Dark | x12,0 | — | 299 R$ | bệ 3D Lobby |
| Flame | x18,0 | — | 499 R$ | bệ 3D Lobby |
| Red Heart | x25,0 | — | 799 R$ | bệ 3D Lobby |

### 5.4 Emote

Không mang hệ số. Bánh xe radial phím `G` / nút HUD.

| # | Emote | Giá Wins |
| ---: | :--- | ---: |
| 1 | Inf Dab | 10 |
| 2 | Peter Parker | 250 |
| 3 | Kazotsky Kick | 1.500 |
| 4 | Electro Shuffle | 7.500 |
| 5 | Electro Swing | 30.000 |

Bậc giá để dành cho emote bổ sung: 100.000 · 400.000 · 1.200.000 · 3.000.000.

**Luật sử dụng:**
- Dùng được trong Lobby và trên treadmill. Cấm trong obby.
- Huỷ khi di chuyển / nhảy / trúng bẫy.
- Bật emote ⇒ dừng animation treadmill. Tắt emote ⇒ khôi phục. Sáu lối thoát phải khôi phục:
  kết thúc tự nhiên · bấm huỷ · di chuyển · rời treadmill · chết · respawn.
- Tên hiển thị là tên tự đặt; `assetId` giữ ở tầng config để thay được mà không mất quyền sở hữu.

### 5.5 Treadmill

| Treadmill | Wood | Purple | Blue | Gold | Red Admin |
| :--- | :---: | :---: | :---: | :---: | :---: |
| Hệ số | x1 | x3 | x9 | x25 | x100 |
| Giá | — | 99 R$ | 249 R$ | 699 R$ | 1.299 R$ |

Hệ số chỉ áp dụng khi đang đứng trên treadmill.

---

## 6. MONETIZATION

### 6.1 Gamepass

| Gamepass | Giá | Quyền lợi |
| :--- | ---: | :--- |
| Double Speed | 3 R$ | +1 xô Premium |
| Quad Speed | 9 R$ | +3 xô Premium |
| Octa Speed | 27 R$ | +7 xô Premium |
| Auto-Rebirth | 99 R$ | tự trùng sinh khi đủ điều kiện, có công tắc ON/OFF |
| Infinite Revives | 249 R$ | hồi sinh tại chỗ không giới hạn |
| Double Wins | 399 R$ | x2 Wins mỗi lần vượt stage |
| VIP Membership | 399 R$ | mục 6.2 |
| Treadmill ×4 | 99 – 1.299 R$ | mục 5.5 |
| Trail & Aura ×11 | 19 – 899 R$ | mục 5.2 / 5.3 |

**Phạm vi hệ số Wins** (VIP · Double Wins · Friends · Server Boost · Event): chỉ áp ở
`reason == "stage"` / `"stage_x2"`. Không áp cho `product` / `daily` / `roulette` / `code`.
Double Wins Pass + `DoubleWinCollectionPad` cộng dồn thành **x4**.

### 6.2 VIP Membership — 399 R$

| # | Quyền lợi | Số |
| :---: | :--- | :--- |
| 1 | Speed farm | x1,5 (+0,5 xô Premium) |
| 2 | Wins khi vượt stage | x1,25 |
| 3 | VIP Gold Trail | x6,0 |
| 4 | VIP Gold Aura | x6,0 |
| 5 | Vé quay | hồi 8 phút · tích tối đa 5 |
| 6 | Teleport | miễn phí tới `HighestCompletedStage + 1` |
| 7 | Tag `[VIP]` vàng trong chat | — |

### 6.3 Developer Products

| Sản phẩm | Giá | Nội dung |
| :--- | ---: | :--- |
| Revive | 19 R$ | hồi sinh tại vị trí chết |
| Skip Stage | 39 R$ | bỏ qua stage hiện tại |
| x2 Wins tại pad | 49 R$ | nhân đôi Wins lần chốt này |
| Skip Rebirth | 149 R$ | trùng sinh ngay — bỏ qua cả điều kiện Level và phí Wins |
| Small Wins Pack | 99 R$ | +5.000 Wins |
| Medium Wins Pack | 299 R$ | +40.000 Wins |
| Large Wins Pack | 699 R$ | +300.000 Wins |
| Ultra Wins Pack | 1.299 R$ | +2.500.000 Wins |
| Server x2 Speed (10m) | 99 R$ | toàn server |
| Server x2 Wins (10m) | 99 R$ | toàn server |
| MEGA Server Boost (10m) | 149 R$ | x2 Speed & x2 Wins toàn server |
| Vé quay 1 / 5 / 10 | 19 / 79 / 149 R$ | vé Roulette |
| Double Offline | 6 R$ | nhân đôi phần thưởng offline |
| Starter Pack | 99 R$ | mục 6.4 |

### 6.4 Starter Pack "Rookie Rocket" — 99 R$

Cửa sổ **48 giờ** từ lần đầu vào game, chạy cả khi offline. Hết hạn là biến mất vĩnh viễn.
Giá niêm yết 999 R$ (−90%).

| Nội dung | |
| :--- | ---: |
| Wins | 50.000 |
| Speed Multiplier vĩnh viễn | x2 (cộng lên bậc pass đang có) |
| Vé quay | 5 |
| x2 Wins Boost | 30 phút |
| Rookie Rocket Trail x2,5 | không bán ở đâu khác |

Bán bằng Developer Product. ⚠️ `LEGACY_PASS_ID` phải giữ để phát bù cho người mua đời gamepass.

---

## 7. GIỮ CHÂN

### 7.1 FTUE — ba phút đầu

```
Vào game ──► TUTORIAL 3 BƯỚC (beam + mũi tên, có SKIP, không chặn điều khiển)
              1. Chạy Stage 1 → dậm pad vàng chốt Wins        (+2 Wins)
              2. Mua Multiplier Pad 2                          (−1 Wins)
              3. Bước lên Treadmill x1
                            ▼
              DAILY NGÀY 1   →  +2.000 Speed · +5 Wins
                            ▼
              GROUP CHEST    →  +5.000 Speed · +25 Wins · x1,1 Wins vĩnh viễn
                            ▼
              QUEST CHAIN (7.2)
```

- Tutorial không phát thưởng. Mọi bước gắn vào sự kiện gameplay server tự biết.
- Người bấm SKIP đánh dấu `TutorialSkipped`, tách khỏi phễu onboarding.
- Kết thúc FTUE người chơi ở ~7.000 Speed ≈ Level 27 ≈ WalkSpeed 66.

### 7.2 Quest Chain

Chạy một lần, phút 2–10. Xong thì Daily Quests chiếm chỗ trên HUD vĩnh viễn.

| # | Mục tiêu | Thưởng |
| :---: | :--- | :--- |
| 1 | Vượt Stage 2 | +1.500 Speed |
| 2 | Đạt Level 10 | +3.000 Speed |
| 3 | **Trùng sinh lần đầu** | +20.000 Speed · 🎟️1 |
| 4 | Mua Multiplier Pad 4 | +60.000 Speed |
| 5 | Vượt Stage 5 | +150.000 Speed |
| 6 | **Trùng sinh lần hai** | +250.000 Speed · 🎟️2 · badge |

- Tổng chuỗi: **484.500 Speed · 3 vé quay**.
- ⚠️ Không mắt xích nào được vượt phần thưởng Speed lớn nhất của một ngày điểm danh (400.000).
- ⚠️ Số vé của chuỗi khoá với bảng chốt chặn Roulette ở 7.5 — chuỗi + mã + online phải giữ
  tổng vé của **giờ đầu ở mức 12**.

### 7.3 Daily Quests

3 quest mỗi ngày, reset 00:00 UTC. Rút 1 quest Obby + 1 quest Farm/Kinh tế + 1 quest tự do.

| Loại | Ví dụ |
| :--- | :--- |
| Obby | vượt 3 stage · vượt stage cao nhất của bạn |
| Farm | cày X Speed · lên 2 Level |
| Kinh tế | mua 1 cosmetic |
| Tiến trình | trùng sinh 1 lần |
| Vận may | quay Roulette 3 lần |
| Xã hội | dùng emote 5 lần · chơi cùng 1 người bạn |

**Phần thưởng mỗi quest — server tính riêng cho từng người chơi tại thời điểm nhận.**

Mục tiêu quest thì cố định ("vượt 3 stage"), nhưng **con số thưởng thì không**. Lúc người chơi
bấm nhận, server đọc hai chỉ số của chính họ rồi tính ra thưởng:

| Server đọc | Dùng để tính |
| :--- | :--- |
| Đang ở lần trùng sinh thứ mấy → còn phải leo bao nhiêu XP nữa | phần **Speed** |
| Stage cao nhất đã qua · phí Wins của lần trùng sinh kế tiếp | phần **Wins** |

```
Speed = max( 2.000 , 2% × tổng XP còn phải leo tới lần trùng sinh kế tiếp )
Wins  = max( Wins(stage cao nhất đã qua) × 0,5 , 2% × phí Wins trùng sinh kế tiếp )
```

Nghĩa là mỗi quest luôn đẩy người chơi tiến **đúng 2% quãng đường tới mốc kế tiếp của họ** —
người mới và người chơi 300 giờ nhận hai con số khác nhau hàng tỉ lần nhưng **cảm giác tiến bộ
là như nhau**:

| Người chơi | R0 / Stage 3 | R4 / Stage 8 | R6 / Stage 12 | R8 / Stage 15 | R15 / Stage 15 |
| :--- | ---: | ---: | ---: | ---: | ---: |
| Speed | 2.000 | 49.600 | 12,70M | 420,46M | 24,95B |
| Wins | 6 | 500 | 15.000 | 200.000 | 5,43M |

3 quest/ngày = **6% một bậc trùng sinh**, ở mọi cấp, mãi mãi.

> **UI hiển thị con số đã tính**, không hiển thị công thức. Người chơi chỉ thấy
> *"Vượt 3 stage → +200.000 Wins · +420M Speed"*.

⚠️ Mọi phần thưởng lặp lại trong game định nghĩa bằng **% mục tiêu hiện tại**, không bằng số
tuyệt đối. Ngoại lệ duy nhất: Speed Roulette (7.5) — nhãn trên bánh xe phải đọc được trước khi
bấm nên nó dùng số cố định.

### 7.4 Điểm danh 7 ngày

Lỡ một ngày → reset về Ngày 1. Nhận đủ Ngày 7 → **hôm sau quay lại Ngày 1 và chạy lại chuỗi**,
lặp vô hạn.

| Ngày | Vòng 1 (7 ngày đầu tiên) | Vòng 2 trở đi |
| :---: | :--- | :--- |
| 1 | +2.000 Speed · +5 Wins | *giống vòng 1* |
| 2 | +10.000 Speed · x2 Speed Boost (15 phút) | *giống vòng 1* |
| 3 | +150 Wins · 🎟️1 | *giống vòng 1* |
| 4 | +60.000 Speed · x2 Wins Boost (15 phút) | *giống vòng 1* |
| 5 | +1.200 Wins · 🎟️2 | *giống vòng 1* |
| 6 | +400.000 Speed · MEGA Server Boost (15 phút) | *giống vòng 1* |
| **7** | 🌈 **Streak Aurora Trail x5,0** · +12.000 Wins · 🎟️3 | **Gói bù** (dưới) · 🎟️3 |

**Chỉ Ngày 7 đổi.** Sáu ngày đầu giống hệt nhau ở mọi vòng. Ngày 7 vòng 1 trao Streak Aurora
Trail — món chỉ có một cái; từ vòng 2 người chơi đã sở hữu nó rồi nên **thay bằng gói bù tính
theo tiến trình hiện tại của họ**:

| Ngày 7 vòng 2+ | Công thức | Ví dụ (người chơi R8) |
| :--- | :--- | ---: |
| Wins | 20% phí Wins trùng sinh kế tiếp, tối thiểu 12.000 | 175.760 |
| Speed | 15% quãng đường trùng sinh kế tiếp | 3,15B |
| Vé quay | 🎟️3 (cố định) | 🎟️3 |

Nhờ vậy vòng 5, vòng 20 vẫn đáng đi trọn — thay vì phát lại một cái trail đã có trong túi.

Chỉ số `LifetimeStreak` đếm tổng ngày liên tục qua mọi vòng, hiển thị cạnh chuỗi 7 ngày, không
trao thưởng.

### 7.5 Speed Roulette

Phần thưởng là **số cố định, ghi thẳng trên ô** — người chơi đọc được trước khi bấm.

| # | Ô | Tỉ lệ |
| :---: | :--- | :---: |
| 1 | **+50 Wins** | 25% |
| 2 | **+15.000 Speed** | 22% |
| 3 | **+400 Wins** | 16% |
| 4 | x2 Speed Boost 15 phút | 15% |
| 5 | x2 Wins Boost 15 phút | 12% |
| 6 | **+4.000 Wins** | 6% |
| 7 | **+400.000 Speed** | 3% |
| 8 | 🌸 **Frozen Bloom Aura** — đền +10.000 Wins nếu đã sở hữu | 1% |

**EV mỗi lượt: 416 Wins · 15.300 Speed.**

#### Nguồn vé

| Nguồn | Số vé |
| :--- | :--- |
| Online | 1 vé / 15 phút, tích tối đa **3** (VIP: 8 phút / 5 vé) |
| Quest Chain | 3 vé — một lần, xem 7.2 |
| Mã `RELEASE` + `ASMR` | 5 vé — một lần |
| Điểm danh D3 + D5 + D7 | 6 vé / tuần |
| Starter Pack | 5 vé |
| Gói Robux | 1 / 5 / 10 vé |

Trần tuyệt đối 99 vé.

#### Bốn chốt chặn cân bằng

| Chốt | Ngưỡng | Hiện tại |
| :--- | :--- | :--- |
| Roulette chiếm bao nhiêu **Wins** giờ đầu | ≤ 20% | **17%** (12 vé × 416 so với 24,9K thu từ stage) |
| Roulette chiếm bao nhiêu **Speed** giờ đầu | ≤ 30% | **28%** (12 vé × 15,3K so với 484,5K của Quest Chain) |
| Ô thường nhất so với `pad_2+3+4` (53 Wins) | phải **thấp hơn** | **50 Wins** ✅ — không tự mua nổi ba pad đầu |
| Tổng weight | = 100 | ✅ |

| 1 lượt quay bằng mấy lượt clear stage | S3 | S5 | S8 | S10 | S12 | S15 |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| | 31,5 | 5,0 | 0,38 | 0,07 | 0,01 | 0,00 |

Ô Speed soi vào đường cong XP: **+15.000 → Level 30** (WS 72) · **+400.000 → Level 49** (WS 110).
Jackpot Wins **4.000 < 4.273** = tổng giá `pad_2`…`pad_7`, nên một cú may mắn vẫn không mua đứt
cả thang pad.

Đây là hệ thống của **~15 giờ đầu**. Về sau số cố định mất dần ý nghĩa, và giá trị còn lại của
bánh xe nằm ở hai ô boost (tự co giãn theo thu nhập hiện tại) cùng jackpot Frozen Bloom — aura
x10 vĩnh viễn, đáng giá như nhau ở mọi cấp. Ba gói vé Robux bán chính món đó.

⚠️ Đổi giá `pad_4` hoặc bảng Wins ở 4.2 là phải kiểm lại bảng chốt chặn trên.

### 7.6 Xã hội

| Hệ thống | Nội dung |
| :--- | :--- |
| **Group Chest** (`GROUP_ID 675923086`) | +5.000 Speed · +25 Wins ngay · x1,1 Wins vĩnh viễn |
| **Friends Boost** | 1 bạn x1,15 Speed / x1,10 Wins · 2 x1,25/x1,15 · 3 x1,35/x1,20 · 4 x1,45/x1,23 · 5 x1,5/x1,25 (trần) |
| **Chat tag** | `[VIP]` · `[Fan]` · `[Member]` |

**Mã quà tặng** — phát Speed + vé quay, không phát Wins:

| Mã | Phần thưởng |
| :--- | :--- |
| `RELEASE` | +500.000 Speed · 🎟️3 |
| `ASMR` | +200.000 Speed · 🎟️2 |

⚠️ Mỗi mã nhận một lần/tài khoản. Phát đợt mới thì thêm mã mới, không sửa mã cũ.

### 7.7 Treadmill offline

| Tham số | Giá trị |
| :--- | :--- |
| Tỉ lệ so với online | 25% |
| Trần tích luỹ | 4 giờ |
| Thời gian tối thiểu | 3 phút |
| Speed tối thiểu để phát | 500 |
| Ngưỡng hiện nút "Double It" | phần thưởng ≥ 2% quãng đường trùng sinh kế tiếp |

- **Tính:** treadmill · Speed Pass · VIP · trail · aura · rebirth.
- **Không tính:** Friends · Server Boost · Event.
- Chỉ phát Speed, không phát Wins.
- ⚠️ Tỉ lệ 25% chỉ được đi xuống, không bao giờ đi lên.

---

## 8. WORLD 2 (LEVEL 121 – 220)

| | |
| :--- | :--- |
| Điều kiện mở | Trùng sinh lần 8 |
| Chủ đề | Neon Cyber City — cyberpunk, glitch lighting, laser di động |
| Nội dung | Stage 16–30 · multiplier pad cấp triệu |
| Trần WalkSpeed | 250 (không đổi) |

Người chơi giữ nguyên toàn bộ chỉ số và vật phẩm; chỉ WalkSpeed reset về mốc đầu và leo lại trên
một trục tiến trình riêng.

**Việc kỹ thuật phải xong trước:**
1. Thêm trục tiến trình theo world trong `DataTemplate` (WalkSpeed hiện không được lưu, được
   tính lại từ Level mỗi lần cần).
2. `Config/Formulas.GetMaxWalkSpeed` — số 250 đang gõ thẳng, hàm cần biết đang ở world nào.
3. `Services/Core/DataService` — `CustomSpeedLimit` kẹp theo `GetMaxWalkSpeed(Level)` lúc nạp
   profile, sang World 2 sẽ kẹp theo trần sai.
4. `Shared/Util/Env` — place World 2 phải khai là Live.

`Config/AntiCheat.luau` không phải đụng. **Còn để ngỏ:** quan hệ giữa trục XP/Level và trục
WalkSpeed mới.

---

## 9. TRẠNG THÁI TRIỂN KHAI

Bản 3.0 **đã áp vào code** (2026-09-06, `CORE_LOOP_VERSION` 4 → 5). §9.1 và §9.2 giữ lại làm
nhật ký delta. Còn mở: §9.2 mục 9.

### 9.1 Đổi giá trị — ✅ xong

| File | Hằng số | Mới |
| :--- | :--- | :--- |
| `Config/Formulas` | `GetRequiredXP` | 2 băng — 3.1 |
| `Config/Formulas` | `GetRebirthMultiplier` | `2,5 × 1,45^(R−3)` từ R4 |
| `Config/Formulas` | `GetRequiredLevelForRebirth` | `120 + (R−8)×4` từ R9 |
| `Config/Formulas` | *(mới)* `GetRebirthWinsCost` | `50.000 × 2,6^(R−6)` |
| `Config/Stages` | `STAGE_WINS` | 4.2 |
| `Config/Stages` | `STAGE_15_FIRST_CLEAR_BONUS` | **gỡ** |
| `Config/Teleport` | `priceWins` ×14 | 4.3 |
| `Config/Economy/MultiplierPads` | `speedPerStep` | 1/**3**/**8**/25/50/100/250/500 |
| `Config/Economy/MultiplierPads` | `requiredWins` → giá mua | 0/1/12/40/120/600/3.500/18.000 |
| `Config/Economy/StreakBonuses` | cả file | **gỡ** |
| `Config/Economy/Products` | `WINS_PACKS` | 5K/40K/300K/2,5M |
| `Config/Economy/Products` | `OFFLINE_DOUBLE_MIN_SPEED` | ngưỡng tương đối — 7.7 |
| `Config/Economy/StarterPack` | `WINS` | 50.000 |
| `Config/Economy/Codes` | `RELEASE` / `ASMR` | 500K / 200K Speed |
| `Config/GroupChest` | `INSTANT_WINS_REWARD` | 25 |
| `Config/OfflineEarnings` | `MAX_SECONDS` | 4 giờ |
| `Config/Quests` | `Chain` | 7.2 |
| `DailyService` | `DAILY_REWARDS` | 7.4 |

`Config/Economy/Emotes` không đổi.

### 9.2 Đổi hành vi

| # | Thay đổi | Chỗ sửa | Trạng thái |
| :---: | :--- | :--- | :--- |
| 1 | Pad: ngưỡng số dư ví → mua vĩnh viễn | `MultiplierPadService`, `DataTemplate` | ✅ — migration grandfather theo ngưỡng cũ |
| 2 | Phí Wins khi trùng sinh (R ≥ 6) | `ProgressionService`, `RebirthModal` | ✅ — Auto-Rebirth bỏ qua lượt khi thiếu Wins |
| 3 | Skip Rebirth bỏ qua cả Level lẫn phí Wins | `ProductService` | ✅ |
| 4 | Migration đường cong XP: Level tính lại từ Speed tích luỹ | `DataService.normalizeData` | ✅ — kẹp lại `CustomSpeedLimit` sau khi tính |
| 5 | Daily Quest: thưởng theo % quãng đường | `QuestService` | ✅ |
| 6 | Điểm danh vòng 2+ · `LifetimeStreak` | `DailyService`, `DataTemplate` | ✅ |
| 7 | Thêm `Treadmill_x1` vào Zone 15 | map | ✅ — `Zone15.Mechanics.Treadmill_x1` tại (6635, 204.8, 3450) trên bệ hoàn thành |
| 8 | Roulette: cập nhật 8 ô theo bảng 7.5 | `Config/Roulette.SLOTS` | ✅ |
| 9 | Hệ số Treadmill chỉ chạy khi đứng trên treadmill; người nạp ở trong obby 96–97% thời gian | `ProgressionService.getTreadmillMultiplier` | ⏳ **Chưa quyết định thiết kế** |

### 9.3 Kiểm tra trước khi publish

| # | Bất biến | Kết quả đo 2026-09-06 |
| :---: | :--- | :--- |
| 1 | Không tài khoản nào tụt Level, tụt pad, mất cosmetic sau migration | ✅ — mô phỏng 13 mốc Speed/Wins, Level mới ≥ Level cũ ở mọi mốc |
| 2 | `Stage 1 Wins ≥ pad_2 giá` | ✅ — 2 ≥ 1 |
| 3 | `Wins(N−1) < teleport(N) < Wins(N)` cho cả 14 điểm đến | ✅ — 14/14 |
| 4 | Tổng weight Roulette = 100 | ✅ |
| 5 | Emote bậc 1 (10 Wins) < thu nhập cộng dồn sau Stage 3 (19 Wins) | ✅ |
| 6 | `Tuning.BASE_MAX_WALK_SPEED` = `StarterPlayer.CharacterWalkSpeed` = 14 | ✅ |
| 7 | Không còn tham chiếu `StreakBonuses` / `STAGE_15_FIRST_CLEAR_BONUS` | ✅ — 0 kết quả trong `src/` |
| 8 | Chạy `docs/REGRESSION.md` trên QA trước, không publish thẳng Live | ⏳ chưa chạy |

---

## 10. NGUỒN CHÂN LÝ

| Cần gì | Ở đâu |
| :--- | :--- |
| Đường cong, bảng giá, phần thưởng, nhịp | tài liệu này |
| ID gamepass / product / asset | `src/shared/Config/Economy/*` |
| ID môi trường (PlaceId, UniverseId) | `src/shared/Util/Env.luau` |
| 15 zone, Lobby, pad, treadmill, terrain | Roblox Cloud — repo không chứa map |

Mâu thuẫn giữa ba nơi thì đo lại trong Studio.
