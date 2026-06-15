# 📋 TASK LIST — +1 Speed Escape (GDDv2)

---

## 📊 TRẠNG THÁI DỰ ÁN HIỆN TẠI

### ✅ CƠ CHẾ ĐÃ CÓ (Đã code xong)

| Cơ chế | File/Location | Mô tả |
|:---|:---|:---|
| **Server Bootstrapper** | `src/server/init.server.luau` | Auto-load tất cả ModuleScript Services |
| **Client Bootstrapper** | `src/client/init.client.luau` | Auto-load tất cả client Controllers |
| **ProgressionService** | `src/server/Services/ProgressionService.luau` | XP, Level, Speed gain, Rebirth, Trail/Aura/Treadmill equip, Gamepass multiplier |
| **DataService** | `src/server/Services/DataService.luau` | DataStore save/load player data |
| **RaceService** | `src/server/Services/RaceService.luau` | Obby race logic, ragdoll death, respawn, launch/landing system, void detect |
| **BossChaseService** | `src/server/Services/BossChaseService.luau` | Stage 4 Boss Gorillo AI chase logic |
| **TeleportService** | `src/server/Services/TeleportService.luau` | Teleport destinations (Lobby, Stage 1-5, Training) |
| **LeaderboardService** | `src/server/Services/LeaderboardService.luau` | In-game leaderboard display |
| **CoreLoopHUDController** | `src/client/Controllers/CoreLoopHUDController.luau` | Full HUD: Speed display, Level, Wins, Shop UI, Rebirth UI, Custom Speed slider |
| **Zone5ClientHelper** | `src/client/Controllers/Zone5ClientHelper.luau` | Client-side effects cho Stage 5 (conveyor visual) |
| **Constants** | `src/shared/Constants.luau` | Tất cả balancing data: Treadmills, Trails, Auras, MultiplierPads, XP curve, Rebirth formula, Streak bonuses |
| **GamePackets** | `src/shared/Network/GamePackets.luau` | Network packet definitions |

### ✅ MAP/STAGE ĐÃ CÓ (Trong Workspace)

| Stage | Zone Name | Trạng thái | Nội dung |
|:---:|:---|:---:|:---|
| Lobby | SpawnLocation + MultiplierPads + Treadmill_x1-x100 + LeaderBoard | ✅ | Fully functional |
| Stage 1 | Zone1 | ✅ | Keyboard Hop obby |
| Stage 2 | Zone2 | ✅ | Laser Grid |
| Stage 3 | Zone3 | ✅ | Clashing Crushers |
| Stage 4 | Zone4 | ✅ | Boss Corridor (Gorillo) |
| Stage 5 | Zone5 | ✅ | Conveyor Chaos + falling shapes |
| Stage 6 | Zone6 | ⚠️ | Folder tồn tại nhưng chưa xác nhận nội dung |

### ❌ CHƯA CÓ

| Cơ chế/Stage | Mô tả |
|:---|:---|
| Stage 7 (Zone7) | Gravity Flip — Chưa tạo |
| Stage 8 (Zone8) | Speed or Die — Chưa tạo |
| Stage 9 (Zone9) | Mirror Maze — Chưa tạo |
| Stage 10 (Zone10) | The Final Sprint + Victory Cup — Chưa tạo |
| Speed Roulette | Vòng xoay may rủi giữa các Stage — Chưa code |
| Server Boost | Mua buff cho cả server — Chưa code |
| Daily Rewards | Phần thưởng đăng nhập hàng ngày — Chưa code |
| Rewarded Ads | Xem quảng cáo nhận buff — Chưa code |
| STAGE_WINS update | Constants chỉ có [1]-[5], cần mở rộng đến [10] |
| Teleport Destinations update | Cần thêm Stage 6-10 vào TELEPORT_DESTINATIONS |

---

## 🎯 TASK LIST

### PHASE 1: HOÀN THIỆN MAP STAGE 6-10

---

#### `[ ]` Task 1.0: Kiểm tra Zone6 hiện tại
> Kiểm tra nội dung Zone6 đã có trong Workspace để xác nhận cần tạo mới hay chỉ cần điều chỉnh.

---

#### `[ ]` Task 1.1: Tạo Stage 6 — "Shrinking Platform" (Zone6)

**🤖 AI PROMPT — TẠO MAP STAGE 6:**
```
Tạo Stage 6 "Shrinking Platform" trong Roblox Studio cho game "+1 Speed Escape".

=== PHONG CÁCH ART ===
- Tất cả Part dùng Material = Enum.Material.Studs
- Pattern Checkerboard: xen kẽ 2 tone màu trên sàn/bệ
- Màu bệ: Vàng cam cảnh báo — Color3.fromRGB(218, 165, 32) xen kẽ Color3.fromRGB(204, 130, 0)
- Tường rào 2 bên: Trắng Color3.fromRGB(255, 255, 255), Material = Studs
- Hố bên dưới: Nước xanh Cyan Color3.fromRGB(0, 207, 255) hoặc khoảng trống

=== CẤU TRÚC FOLDER ===
Tạo Folder "Zone6" trong Workspace với cấu trúc:
- Zone6/
  - Ground/ (các Part sàn, bệ nhảy)
    - Transition5To6 (Part nối từ Zone5)
    - ShrinkPlatform_1 đến ShrinkPlatform_12 (12 bệ co rút)
  - Mechanics/ (script trigger, kill zones)
  - Boundaries/ (tường rào 2 bên)
  - Transition6To7 (Part nối đến Zone7)

=== THÔNG SỐ KỸ THUẬT ===
- 12 bệ xếp ZIGZAG (lệch trái/phải xen kẽ)
- Mỗi bệ: Size = Vector3.new(20, 2, 20)
- Khoảng cách giữa bệ: 14 studs
- Chiều cao bệ so với hố: 40 studs
- Tổng chiều dài Stage: ~300 studs

=== CƠ CHẾ ===
Khi player chạm bệ → sau 0.3s → bệ bắt đầu co rút (TweenService, 2.5 giây từ size gốc về Vector3.zero)
→ Sau khi co rút xong, bệ Destroy() → respawn lại sau 5 giây

=== KẾT NỐI ===
- Đầu vào: nối tiếp từ Zone5 (kiểm tra tọa độ Z cuối của Zone5)
- Đầu ra: Transition6To7 Part nối sang Zone7
```

---

#### `[ ]` Task 1.2: Tạo Stage 7 — "Gravity Flip" (Zone7)

**🤖 AI PROMPT — TẠO MAP STAGE 7:**
```
Tạo Stage 7 "Gravity Flip" trong Roblox Studio cho game "+1 Speed Escape".

=== PHONG CÁCH ART ===
- Material = Enum.Material.Studs trên mọi Part
- Checkerboard tím đậm Color3.fromRGB(90, 40, 140) / tím nhạt Color3.fromRGB(150, 80, 200)
- Vùng Gravity Zone: Part Neon tím phát sáng Transparency = 0.5
- Trần nhà: cùng pattern checkerboard nhưng đảo màu (nhạt/đậm)

=== CẤU TRÚC FOLDER ===
- Zone7/
  - Ground/ (sàn dưới)
    - Transition6To7
    - FloorSegment_1 đến FloorSegment_6
  - Ceiling/ (trần trên — player chạy ở đây khi lật)
    - CeilingSegment_1 đến CeilingSegment_6
  - GravityZones/ (các vùng trigger lật trọng lực)
    - FlipZone_1 đến FlipZone_6 (Part Neon tím, CanCollide = false)
  - Boundaries/ (tường rào + trần)
  - Mechanics/
  - Transition7To8

=== THÔNG SỐ KỸ THUẬT ===
- Chiều cao trần: 40 studs (sàn Y=0, trần Y=40)
- 6 đoạn xen kẽ: Sàn → Lật lên trần → Lật xuống sàn → ...
- Mỗi đoạn: dài 50 studs, có khe nhảy 16 studs
- GravityZone: Part mỏng (Y=0.5) đặt giữa mỗi đoạn chuyển tiếp
- Tổng chiều dài Stage: ~350 studs

=== CƠ CHẾ ===
- Khi player Touched FlipZone → Server đặt workspace.Gravity = -196.2 (lật ngược)
  → Player bay lên trần → chạy trên CeilingSegment
- FlipZone tiếp theo → workspace.Gravity = 196.2 (bình thường)
- Client: Camera xoay 180° smooth bằng TweenService khi flip

=== KẾT NỐI ===
- Đầu vào: nối tiếp từ Zone6.Transition6To7
- Đầu ra: Transition7To8
```

---

#### `[ ]` Task 1.3: Tạo Stage 8 — "Speed or Die" (Zone8)

**🤖 AI PROMPT — TẠO MAP STAGE 8:**
```
Tạo Stage 8 "Speed or Die" trong Roblox Studio cho game "+1 Speed Escape".

=== PHONG CÁCH ART ===
- Material = Enum.Material.Studs
- Checkerboard đỏ đậm Color3.fromRGB(139, 26, 26) / đỏ nhạt Color3.fromRGB(200, 60, 60)
- Chướng ngại vật: Neon cam Color3.fromRGB(255, 140, 0)

=== CẤU TRÚC FOLDER ===
- Zone8/
  - Ground/ (đường chạy thẳng gồm nhiều Part liền kề)
    - Transition7To8
    - CollapsingPlatform_1 đến CollapsingPlatform_40 (mỗi cái 10x2x12 studs)
  - Obstacles/ (rào cản thấp trên đường)
    - Hurdle_1 đến Hurdle_6 (Part cao 3 studs, phải nhảy qua)
  - Boundaries/ (tường rào 2 bên)
  - Mechanics/
  - Transition8To9

=== THÔNG SỐ KỸ THUẬT ===
- Đường chạy thẳng: 400 studs (40 Part x 10 studs mỗi cái)
- 6 rào cản thấp (Hurdle) phân bố đều mỗi ~60 studs
- Không có khe hở nhảy — chỉ cần chạy thẳng và nhảy qua rào
- Tốc độ sụp đổ: 150 studs/s (Server loop mỗi 0.067s xóa 1 Part)

=== CƠ CHẾ ===
- Khi player bước lên Part đầu tiên → Server bắt đầu loop sụp đổ từ Part cuối
- Mỗi Part: TweenService giảm Position.Y -30 + Transparency → 1 trong 0.15s → Destroy
- Player phải chạy nhanh hơn 150 studs/s (WalkSpeed ≥ 152)
- Nếu đứng trên Part bị sụp → rơi xuống void → Ragdoll → Respawn

=== KẾT NỐI ===
- Đầu vào: nối tiếp từ Zone7.Transition7To8
- Đầu ra: Transition8To9
```

---

#### `[ ]` Task 1.4: Tạo Stage 9 — "Mirror Maze" (Zone9)

**🤖 AI PROMPT — TẠO MAP STAGE 9:**
```
Tạo Stage 9 "Mirror Maze" trong Roblox Studio cho game "+1 Speed Escape".

=== PHONG CÁCH ART ===
- Sàn: Material = Enum.Material.Studs, checkerboard xanh dương đậm Color3.fromRGB(30, 60, 120) / xanh dương nhạt Color3.fromRGB(60, 120, 200)
- Tường mê cung: Material = Glass, Transparency = 0.92, CanCollide = true, Neon viền mỏng ở chân tường để player nhìn thấy mờ mờ
- Rào ngoài: Material = Studs, trắng/xanh nhạt

=== CẤU TRÚC FOLDER ===
- Zone9/
  - Ground/ (sàn mê cung)
    - Transition8To9
    - MazeFloor (Part lớn 100x2x100)
  - MazeWalls/ (Model chứa tất cả tường mê cung — sẽ xoay cả Model)
    - Wall_1 đến Wall_N (các Part tường Glass)
  - Boundaries/ (rào ngoài 4 bên)
  - Mechanics/ (timer, rotation script trigger)
  - ExitZone (Part nối ra Transition9To10)
  - Transition9To10

=== THÔNG SỐ KỸ THUẬT ===
- Mê cung: 100 x 100 studs, tường cao 15 studs
- Tường: Thickness 2 studs, Transparency = 0.92
- Có đúng 1 đường đi duy nhất từ Entrance → Exit
- Khe thoát cuối: rộng 8 studs (cần chạy nhanh WalkSpeed ≥ 168)
- Timer: 60 giây, hiển thị countdown trên HUD
- Mỗi 15 giây: MazeWalls Model PivotTo() xoay 90° quanh tâm

=== CƠ CHẾ ===
- Server: Mỗi 15s → MazeWalls:PivotTo(CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0))
- Client: Hiển thị WARNING "⚠️ MAZE ROTATING IN 3... 2... 1..." trước khi xoay
- Hết 60s → Player bị teleport về đầu Stage 9
- Player chạm ExitZone → Clear stage

=== KẾT NỐI ===
- Đầu vào: nối tiếp từ Zone8.Transition8To9
- Đầu ra: Transition9To10
```

---

#### `[ ]` Task 1.5: Tạo Stage 10 — "The Final Sprint" + Victory Cup (Zone10)

**🤖 AI PROMPT — TẠO MAP STAGE 10:**
```
Tạo Stage 10 "The Final Sprint" trong Roblox Studio cho game "+1 Speed Escape".

=== PHONG CÁCH ART ===
- Material = Enum.Material.Studs trên mọi Part
- Mỗi đoạn 60 studs dùng MÀU KHÁC NHAU theo Stage gốc:
  - Đoạn 1 (Keyboard): Checkerboard xanh lá
  - Đoạn 2 (Laser): Checkerboard đỏ
  - Đoạn 3 (Crusher): Checkerboard xám
  - Đoạn 4 (Conveyor): Checkerboard xanh dương
  - Đoạn 5 (Shrink): Checkerboard vàng
  - Đoạn 6 (Gravity): Checkerboard tím
  - Đoạn 7 (Speed or Die): Checkerboard đỏ đậm
  - Đoạn 8 (Maze mini): Checkerboard xanh dương đậm
  - Đoạn 9 (Boss): Checkerboard cam
  - Đoạn 10 (Victory): Checkerboard vàng GOLD rực rỡ
- Victory Cup cuối: Part khổng lồ hình cúp vàng Neon phát sáng

=== CẤU TRÚC FOLDER ===
- Zone10/
  - Ground/ (sàn 10 đoạn liên tiếp)
    - Transition9To10
    - Segment_1 đến Segment_10 (mỗi cái 60 studs)
  - Mechanics/ (bẫy thu nhỏ từ mỗi Stage)
    - MiniKeyboard/ (3-4 phím nhảy, khe 24 studs)
    - MiniLaser/ (3 laser xoay)
    - MiniCrusher/ (2 cặp dập nhanh)
    - MiniConveyor/ (1 chốt chặn ngược -120 studs/s)
    - MiniShrink/ (3 bệ co rút 1.5s)
    - MiniGravity/ (4 flip zones)
    - MiniCollapse/ (đường sụp 180 studs/s, 60 studs)
    - MiniMaze/ (maze nhỏ 40x40, xoay mỗi 10s)
    - MiniBoss/ (Boss WalkSpeed 190, đuổi 60 studs)
  - VictoryCup/ (Model cúp vàng khổng lồ ở cuối)
  - Boundaries/
  - Transition10ToFinish (teleport về Lobby)

=== THÔNG SỐ KỸ THUẬT ===
- Tổng chiều dài: 600 studs (10 đoạn x 60 studs)
- KHÔNG có checkpoint — chết = quay lại đầu Zone10
- Victory Cup: Part hình cúp, Size khoảng 15x25x15 studs, Material = Neon, Color = Gold

=== KẾT NỐI ===
- Đầu vào: nối tiếp từ Zone9.Transition9To10
- Đầu ra: Touch VictoryCup → Nhận 1000 Wins → Teleport về Lobby
```

---

### PHASE 2: HỆ THỐNG GAME MỚI

---

#### `[ ]` Task 2.1: Cập nhật Constants.luau — Mở rộng STAGE_WINS và TELEPORT_DESTINATIONS

**🤖 AI PROMPT — CẬP NHẬT CONSTANTS:**
```
Mở rộng file src/shared/Constants.luau:

1. Cập nhật STAGE_WINS thêm Stage 6-10:
   [6] = 60, [7] = 120, [8] = 250, [9] = 500, [10] = 1000

2. Thêm TELEPORT_DESTINATIONS cho Stage 6-10:
   stage_6: targetPath = "Workspace.Zone6.Ground.Transition5To6", priceWins = 80, sortOrder = 7
   stage_7: targetPath = "Workspace.Zone7.Ground.Transition6To7", priceWins = 150, sortOrder = 8
   stage_8: targetPath = "Workspace.Zone8.Ground.Transition7To8", priceWins = 300, sortOrder = 9
   stage_9: targetPath = "Workspace.Zone9.Ground.Transition8To9", priceWins = 600, sortOrder = 10
   stage_10: targetPath = "Workspace.Zone10.Ground.Transition9To10", priceWins = 1000, sortOrder = 11

3. Thêm SERVER_BOOST config:
   Constants.SERVER_BOOST = {
     SPEED_2X = { id = "server_speed_2x", productId = 0, multiplier = 2, duration = 600, priceRobux = 49 },
     WINS_2X = { id = "server_wins_2x", productId = 0, multiplier = 2, duration = 600, priceRobux = 49 },
     MEGA = { id = "server_mega", productId = 0, speedMult = 2, winsMult = 2, duration = 600, priceRobux = 99 },
   }

4. Thêm SPEED_ROULETTE config:
   Constants.SPEED_ROULETTE = {
     { weight = 35, type = "BUFF_SPEED", label = "🟢 +20% Speed", speedMult = 1.2, winsMult = 1 },
     { weight = 20, type = "X2_WINS", label = "🟡 x2 Wins", speedMult = 1, winsMult = 2 },
     { weight = 15, type = "SHIELD", label = "🔵 Shield", shieldCount = 1 },
     { weight = 10, type = "MEGA_BUFF", label = "🟣 MEGA", speedMult = 1.5, winsMult = 3 },
     { weight = 10, type = "DEBUFF_SPEED", label = "🔴 -15% Speed", speedMult = 0.85, winsMult = 1 },
     { weight = 5, type = "SCRAMBLE", label = "⚫ Scramble!", duration = 5 },
     { weight = 5, type = "JACKPOT", label = "💎 JACKPOT!", speedMult = 1, winsMult = 10 },
   }

5. Thêm DAILY_REWARDS config:
   Constants.DAILY_REWARDS = {
     [1] = { wins = 100 },
     [2] = { wins = 200 },
     [3] = { wins = 500, bonusRouletteToken = 1 },
     [4] = { wins = 1000 },
     [5] = { wins = 2000 },
     [6] = { wins = 5000 },
     [7] = { wins = 10000, bonusTrail = "trail_weekly_exclusive" },
   }
```

---

#### `[ ]` Task 2.2: Tạo SpeedRouletteService (Server)

**🤖 AI PROMPT — SPEED ROULETTE SERVER:**
```
Tạo file src/server/Services/SpeedRouletteService.luau cho game "+1 Speed Escape".

=== KIẾN TRÚC ===
- ModuleScript trả về table { Init, Start }
- Sử dụng Constants.SPEED_ROULETTE cho cấu hình
- Tích hợp với ProgressionService (đã có) để áp dụng buff

=== LOGIC ===
1. Khi player vượt Stage N (nhận từ RaceService thông qua RemoteEvent "StageCleared"):
   - Server tính kết quả random dựa trên weight table
   - Lưu buff vào playerActiveBuffs[player] = { type, speedMult, winsMult, shieldCount, stageApplied }
   - Fire RemoteEvent "RouletteResult" về client với kết quả
   
2. Khi player bắt đầu Stage tiếp theo:
   - Áp dụng buff từ playerActiveBuffs
   - Nếu BUFF_SPEED/MEGA_BUFF: tạm thời nhân WalkSpeed
   - Nếu X2_WINS/JACKPOT: nhân Wins khi clear stage
   - Nếu SHIELD: cho phép 1 lần chết không reset (cần hook vào RaceService ragdoll)
   - Nếu SCRAMBLE: fire RemoteEvent "Scramble" về client (client đảo input)
   - Nếu DEBUFF_SPEED: tạm giảm WalkSpeed

3. Buff HẾT HẠN sau khi player hoàn thành hoặc chết ở Stage đó

4. Gamepass "Extra Spin": 
   - Kiểm tra player có gamepass → cho phép quay lại 1 lần
   - Giữ kết quả tốt hơn giữa 2 lần quay

=== SECURITY ===
- Tất cả logic random chạy trên Server
- Client chỉ nhận kết quả để hiển thị UI
- Sanity check: player phải thực sự ở vùng chuyển tiếp giữa 2 Stage
```

---

#### `[ ]` Task 2.3: Tạo SpeedRouletteUI (Client)

**🤖 AI PROMPT — SPEED ROULETTE CLIENT UI:**
```
Thêm Speed Roulette UI vào src/client/Controllers/CoreLoopHUDController.luau (hoặc tạo controller mới SpeedRouletteController.luau).

=== UI DESIGN ===
- Vòng xoay xuất hiện GIỮA MÀN HÌNH khi nhận RemoteEvent "RouletteResult"
- Vòng xoay hình tròn với 7 ô màu (mỗi ô = 1 kết quả)
- Animation: xoay nhanh → chậm dần → dừng ở kết quả (TweenService, ~3 giây)
- Khi dừng: hiệu ứng phát sáng + âm thanh "DING!" + text lớn hiện kết quả
- Nếu JACKPOT: hiệu ứng confetti + camera shake + âm thanh đặc biệt
- Sau 2 giây → UI biến mất, player tiếp tục chạy

=== SCRAMBLE HANDLER ===
- Khi nhận "Scramble": đảo ngược UserInputService MoveDirection (trái↔phải) trong 5 giây
- Hiển thị icon "⚫ CONTROLS REVERSED!" ở góc màn hình

=== KẾT NỐI ===
- Listen RemoteEvent "RouletteResult" từ server
- Hiển thị buff icon nhỏ ở góc HUD trong suốt Stage đang active
```

---

#### `[ ]` Task 2.4: Tạo ServerBoostService (Server)

**🤖 AI PROMPT — SERVER BOOST:**
```
Tạo file src/server/Services/ServerBoostService.luau

=== LOGIC ===
1. Khi player mua Developer Product (Server Boost):
   - MarketplaceService.ProcessReceipt → xác nhận thanh toán
   - Lưu activeBoosts = { type, buyerName, multiplier, endTime }
   - Broadcast thông báo cho toàn server: "[TênNgườiMua] đã kích hoạt SERVER x2 SPEED! (10 phút)"
   - Fire RemoteEvent "ServerBoostActivated" → tất cả clients

2. Mỗi frame (RunService.Heartbeat hoặc loop 1s):
   - Kiểm tra boost còn hạn không (tick() < endTime)
   - Nếu hết hạn → xóa boost + broadcast "Server Boost đã hết!"

3. Tích hợp với ProgressionService:
   - ProgressionService đọc ServerBoostService.GetActiveSpeedMultiplier() khi tính Speed gain
   - ProgressionService đọc ServerBoostService.GetActiveWinsMultiplier() khi tính Wins

4. Quy tắc:
   - Cooldown 2 phút giữa 2 lần mua cùng loại boost
   - Buff cùng loại KHÔNG stack, chỉ gia hạn thời gian thêm 10 phút
   - Buff khác loại (Speed + Wins) CÓ THỂ hoạt động đồng thời

=== CLIENT UI ===
- Banner phát sáng ở góc trên màn hình: "⚡ SERVER x2 SPEED — 09:45 còn lại"
- Đếm ngược realtime
- Nút "Mua Server Boost" trong Shop UI (thêm tab mới hoặc section mới)
```

---

#### `[ ]` Task 2.5: Tạo DailyRewardService (Server)

**🤖 AI PROMPT — DAILY REWARDS:**
```
Tạo file src/server/Services/DailyRewardService.luau

=== DATA ===
Thêm vào Constants.DATA_TEMPLATE:
  DailyRewardDay = 0,           -- Ngày hiện tại trong chuỗi (0 = chưa nhận)
  LastDailyRewardDate = "",      -- Format "YYYY-MM-DD"

=== LOGIC ===
1. Khi player join:
   - Đọc LastDailyRewardDate từ DataStore
   - So sánh với os.date("!*t") (UTC date)
   - Nếu KHÁC NGÀY:
     a. Nếu đúng ngày hôm sau → DailyRewardDay += 1 (tiếp chuỗi)
     b. Nếu bỏ lỡ > 1 ngày → DailyRewardDay = 1 (reset chuỗi)
     c. Nếu DailyRewardDay > 7 → DailyRewardDay = 1 (reset sau 7 ngày)
   - Fire RemoteEvent "DailyRewardAvailable" → client (kèm ngày + phần thưởng)

2. Khi player nhấn "Nhận" trên UI:
   - Server verify, cộng Wins theo Constants.DAILY_REWARDS[day]
   - Lưu LastDailyRewardDate = today
   - Fire "DailyRewardClaimed" → client (hiệu ứng)

=== CLIENT UI ===
- Popup hiện ngay khi join game nếu có reward chưa nhận
- Grid 7 ô, ô hiện tại phát sáng, ô đã nhận có check ✅
- Nút "NHẬN" lớn + hiệu ứng particle khi nhận
```

---

#### `[ ]` Task 2.6: Cập nhật RaceService — Hook Speed Roulette + Server Boost

**🤖 AI PROMPT — UPDATE RACESERVICE:**
```
Cập nhật src/server/Services/RaceService.luau:

1. Khi player vượt Stage (onFinishTouched hoặc tương đương):
   - Fire event/signal cho SpeedRouletteService biết player đã clear Stage N
   - Áp dụng Wins multiplier từ SpeedRouletteService (nếu có buff x2/x10 Wins)
   - Áp dụng Wins multiplier từ ServerBoostService (nếu có Server x2 Wins)

2. Khi player chết (ragdoll):
   - Check SpeedRouletteService: nếu player có Shield buff → KHÔNG chết, chỉ mất Shield
   - Fire "ShieldUsed" → client (hiệu ứng shield vỡ)

3. Stage progression:
   - Hỗ trợ Stage 6-10 trong logic respawn và teleport
   - Đảm bảo player respawn đúng đầu Stage khi chết
```

---

### PHASE 3: POLISH & EXTRAS

---

#### `[ ]` Task 3.1: Cập nhật HUD cho Stage 6-10
> Thêm indicator Stage 6-10 vào CoreLoopHUDController, hiển thị tên Stage + icon

#### `[ ]` Task 3.2: Thêm Stage-specific Client Effects
> Tạo Zone7ClientHelper (camera flip), Zone8ClientHelper (collapse VFX), Zone9ClientHelper (maze timer HUD)

#### `[ ]` Task 3.3: Âm thanh & Nhạc nền
> Thêm SFX cho mỗi Stage, Roulette spin sound, Server Boost jingle, Victory Cup fanfare

#### `[ ]` Task 3.4: Testing & Balancing
> Test từng Stage, điều chỉnh gatekeeping thực tế, đảm bảo F2P progression hợp lý

---

## 📝 GHI CHÚ

- **Ưu tiên:** Phase 1 (Map) → Phase 2 (Systems) → Phase 3 (Polish)
- **Art Style bắt buộc:** MỌI Part phải dùng Material = Studs + pattern Checkerboard
- **Mỗi Zone cần test kết nối** với Zone trước và sau (tọa độ Z khớp nhau)
- **Server-first:** Tất cả logic game chạy trên Server, client chỉ render UI/VFX
