# 🎧 Báo Cáo & Quản Lý Hệ Thống Âm Thanh - SpeedEscape

> **Ngày kiểm tra:** 2026-08-04  
> **Vị trí Folder Âm Thanh Trong Roblox Studio:** `game.Workspace.AllGameSounds_Review`  
> **Nguồn dữ liệu chính (Single Source of Truth):** [`src/shared/Config/Audio.luau`](file:///c:/Users/Admin/Downloads/SpeedEscape/src/shared/Config/Audio.luau)  
> **Thư mục tài nguyên local:** [`audio_system/`](file:///c:/Users/Admin/Downloads/SpeedEscape/audio_system/)  

---

## 📍 1. Vị Trí Sound Instances Trong Roblox Studio Explorer

Đã tạo sẵn thư mục **`AllGameSounds_Review`** nằm ngay trong **`Workspace`** của Roblox Studio. Bạn có thể mở Explorer trong Studio, chọn bất kỳ `Sound` instance nào và bấm **Preview / Play** để nghe thử trực tiếp:

```
Workspace
 └── AllGameSounds_Review
      ├── ASMR_Floors
      │    ├── AquaRun (7 sounds)
      │    ├── BubbleWrap (6 sounds)
      │    ├── Clay (3 sounds)
      │    ├── CrystalDrop (3 sounds)
      │    ├── GummySquish (1 sound)
      │    ├── Jelly (6 sounds)
      │    ├── Keyboard (3 lớp đang dùng + 7 mẫu thân thay thế)
      │    ├── KineticSand (6 sounds)
      │    ├── MelodyRun (3 sounds)
      │    ├── Orbeez (1 sound)
      │    ├── PopIt (1 sound)
      │    ├── Soap (4 sounds)
      │    ├── SqueakyDuck (6 sounds)
      │    └── Misc_ASMR (1 sound)
      ├── UI (9 sounds: Click, Hover, Modal, Toast, Spin...)
      ├── Reward (5 sounds: LevelUp, Rebirth, Wins, Jackpot, Stage)
      ├── Music (8 sounds BGM)
      └── Zone_SFX (4 sounds: Wind, SonicBoom, MetalImpact, Shatter)
```

---

## 🔍 2. Kết Quả Quét Trực Tiếp Qua Roblox Studio MCP

1. **Thư viện cấu hình (`Audio.luau`):** 
   - **82/82** Sound Asset IDs nạp thành công trong Studio (`IsLoaded = true`).
   - **100%** khớp nguồn chính thức: `ProSoundEffects` (SFX & ASMR), `APMOfficial` (BGM & Phần thưởng), `Monstercat` (EDM BGM).

2. **Âm thanh tĩnh trong DataModel (3 Mẫu bổ sung):**
   - `Workspace.Zones.Zone4.Mechanics.MonkeyBoss.Head.Jeff_Susto2` (`rbxassetid://5124099762`)
   - `Workspace.Zones.Zone4.Mechanics.MonkeyBoss.Head.Jeff_Laugh` (`rbxassetid://2473639958`)
   - `ServerStorage.SharkTemplate.Shark.Head.Angry` (`rbxassetid://9114344093`)

---

## 🎛️ 3. Cấu Trúc Âm Lượng & Sidechain Ducking

Hệ thống quản lý 5 nhóm mixer với nguyên tắc **"Ưu tiên ASMR hơn Nhạc nền"**:

```
Master (100%)
 ├── ASMR   (100%)  <-- Tiếng sàn bước chân ASMR (Trọng tâm trải nghiệm)
 ├── SFX    ( 75%)  <-- Hiệu ứng Zone, bẫy, pháo hoa
 ├── UI     ( 60%)  <-- Click nút, mở Modal, Toast
 └── Music  ( 30%)  <-- Nhạc nền BGM (Tự động Sidechain Ducking)
```

---

## 📊 4. Bảng Tổng Hợp Tất Cả Âm Thanh Dự Án

### 4.1. Giao diện (UI Cues - 7 mẫu)

> ⚠️ Hai dòng đầu là ID ĐANG CHẠY (đọc từ `HUD/Theme.luau` → `UI_ASSETS`). Các dòng còn
> lại là di sản từ thời `Audio.luau`, đã revert 2026-08-05 — chưa đối chiếu lại với code.

| Sound Instance Name trong Studio | Sound ID | Nguồn | Độ Dài Thật (Studio) | Công Dụng |
|---|---|---|---|---|
| `01 Click (ButtonSFX) [5852470908]` | `5852470908` | user upload | 0.21s | Click nút UI — vol 0.50, speed 1.00 |
| `02 Hover (ButtonSFX) [10066931761]` | `10066931761` | user upload | 0.20s | Rê chuột qua nút — vol 0.22, speed 1.00 |
| `Video Game Buttons 5 [9120410025]` | `9120410025` | PSE | 0.85s | Mở Modal UI |
| `Video Game Buttons 20 [9120412048]` | `9120412048` | PSE | 0.97s | Đóng Modal UI |
| `Tone Clusters 58 [9120148551]` | `9120148551` | PSE | 0.38s | Toast lỗi |
| `Tone Clusters 32 [9120151328]` | `9120151328` | PSE | 0.46s | Tick Roulette |
| `Tone Clusters 23 [9120150515]` | `9120150515` | PSE | 0.40s | Toast thông báo |

### 4.2. Phần thưởng (Reward Cues - 5 mốc)
| Sound Instance Name trong Studio | Sound ID | Nguồn | Độ Dài Thật (Studio) | Mốc Phần Thưởng |
|---|---|---|---|---|
| `Classic Console - Hit1 [1848274293]` | `1848274293` | APM | 4.59s | Level Up |
| `Classic Console - Hit2 [1848274304]` | `1848274304` | APM | 4.59s | Rebirth |
| `Classic Console - Tag2 [1848274279]` | `1848274279` | APM | 1.99s | +Wins |
| `Classic Console - Tag1 [1848274276]` | `1848274276` | APM | 3.55s | Jackpot Roulette |
| `On Our Way - Mnemonic2 [1848281172]` | `1848281172` | APM | 4.45s | Mở Pad / Stage |

### 4.3. Nhạc nền (BGM Playlist)

**Nguồn hợp lệ cho NHẠC là APMOfficial (APM Music) và Monstercat.** ProSoundEffects
**không** phát hành nhạc nền — thư viện của họ chỉ có hiệu ứng (tra Creator Store
2026-08-05: mọi kết quả nhạc đều là APMOfficial hoặc DistrokidOfficial). Dùng PSE cho
SFX/ASMR, APM cho BGM.

Playlist thật do `Effects/BgmController.luau` quyết định — **3 bài**, cập nhật 2026-08-05:

| # | Tên | Sound ID | Nguồn | Độ dài |
|---|---|---|---|---|
| 01 | Paradise Falls - Alt1 | `1837879134` | APM | 162.3s |
| 02 | Paradise Falls | `1837879082` | APM | 162.0s |
| 03 | Paradise Falls - Alt2 | `1837879143` | APM | 162.7s |

Alt1/Alt2 là hai **bản phối khác của chính bản nhạc** user chấm — sát nghĩa "tương tự"
nhất tìm được. Đã gỡ `9043887091` (Lo-fi Chill A) và `1848354536` (Relaxed Scene); cả hai
vẫn nằm trong `AllGameSounds_Review/3_Music/Bài CŨ đã gỡ` nếu muốn quay lại.

**Âm lượng `BGM_VOLUME = 0.025`** (hạ từ 0.04). Nhạc là Sound **2D** gắn vào SoundService
nên không suy giảm theo khoảng cách — luôn đúng âm lượng này — trong khi mọi tiếng ASMR là
3D và tụt dần. Con số nhìn thì bé nhưng nhạc vẫn thừa sức che tiếng sàn nếu để cao.

> 8 bài ứng viên khác nằm trong `AllGameSounds_Review/3_Music/Ứng viên thay thế` — tất cả
> đã đo `IsLoaded=true`. **Cảnh báo:** `1836807625` (Drifted) và `1838967315` (Pretty
> Night) đo ra `TimeLength=0, IsLoaded=false` — KHÔNG đưa vào playlist.

<details><summary>Bảng cũ (8 bài, từ thời <code>Audio.luau</code> đã revert — chưa đối chiếu lại)</summary>

| Sound Instance Name trong Studio | Sound ID | Nguồn | Độ Dài Thật | Thể Loại |
|---|---|---|---|---|
| `Powerful Engine [9042020196]` | `9042020196` | APM | 169.72s | Electro House |
| `Rogue - Move Me [7028548115]` | `7028548115` | MC | 230.01s | Dance / House |
| `Speed Demon (A) [1840441665]` | `1840441665` | APM | 123.22s | Speed Hype |
| `Tony Romera - I Can't [5410082805]` | `5410082805` | MC | 183.88s | Dance Vocal |
| `Rise to the Top (c) [1837768013]` | `1837768013` | APM | 129.95s | Uplifting |
| `Take Me Higher (c) [1837768107]` | `1837768107` | APM | 119.95s | Uplifting High |
| `Lo-fi Chill A [9043887091]` | `9043887091` | APM | 136.91s | Lo-fi Chill |
| `Relaxed Scene [1848354536]` | `1848354536` | APM | 97.02s | Calm Scene |

</details>

### 4.4. Thư viện Sàn Bàn Phím Cơ (ThockyKey — 3 lớp chồng nhau)

Cập nhật 2026-08-05. **Mọi ThockyKey phát y hệt nhau** — không bốc ngẫu nhiên mẫu, không
rung cao độ, không gán nốt theo vị trí phím. Mỗi cú gõ = 3 lớp cố định phát chồng lên,
tái hiện 3 sự kiện của một switch cơ thật. Nguồn: `ASMR/Floors/Keyboard.luau`.

| Lớp | Sound ID | Nguồn | Dài | Âm lượng | PlaybackSpeed | Vai trò |
|---|---|---|---|---|---|---|
| THÂN Keyboard Click | `127105730240202` | user upload | 0.277s | 1.00× | **0.92** | keycap chạm đáy — lớp chính |
| TICK lá đồng | `9113140795` | PSE Apple Keyboard 5 | 0.203s | 0.34× | **1.44** | đầu transient sắc, cùng frame với thân |
| NHẢ phím | `9116157307` | PSE Keyboard Typing 34 | 0.303s | **0.36×** | 1.78 | lò xo đẩy keycap về vị trí nghỉ |

### 4.4b. Chạy càng nhanh nghe càng đã tai (2026-08-05)

**Vấn đề đo được:** nhịp gõ tỉ lệ thuận với walkspeed — 50 WS → 26 nhịp/giây, 250 WS →
**78**. Tai người ngừng nghe ra sự kiện rời rạc ở khoảng **30 nhịp/giây**; trên mức đó các
cú gõ hoà vào nhau thành tiếng rè có cao độ. Càng nhanh càng NHIỀU tiếng không làm nó đã
tai hơn — nó biến tiếng gõ thành tiếng ồn.

**Cách chữa: đổi hướng — nhanh thì gõ ÍT hơn nhưng mỗi tiếng NẶNG hơn.**

| Thông số | Đứng yên | 250 WS | Vì sao |
|---|---|---|---|
| nhịp gõ trần | 20/giây | 30/giây | giữ dưới ngưỡng hoà thành tiếng rè |
| thân — âm lượng | 0.50 | **1.15** | chạy hết tốc phải nghe đầm (Volume tới 10 là hợp lệ) |
| thân — cao độ | 0.96 | **0.86** | càng nhanh càng trầm, càng "thocky" |
| tick — âm lượng | 0.38× | **0.18×** | hàng chục transient treble/giây chồng lên = tiếng xì chói |
| nhả — âm lượng | 0.30 | **0.14** | chạy nhanh thì cú nhả đè lên cú nhấn kế, chỉ làm đục |

Lọc nhịp dùng **token bucket** (`CLICK_RATE_SLOW/FAST` + `CLICK_BURST`), KHÔNG phải cổng
"cách lần trước ≥ X giây" — cổng thời gian bị lượng tử hoá theo khung hình (60fps chỉ ra
được 60/n nhịp/giây) nên kết quả nhảy loạn và **ngược**: 250 WS ra 15.5 nhịp/giây trong
khi 180 WS được 21.5.

`CLICK_BURST = 3` chọn bằng đo, không phải đoán (nhịp/giây, Heartbeat 4s mỗi mức):

| WS | thô | BURST=1 | BURST=2 | **BURST=3** |
|---|---|---|---|---|
| 50 | 26 | 9.8 | 18.7 | **19.8** |
| 100 | 49 | 18.9 | 23.0 | **24.1** |
| 150 | 67 | 15.4 | 25.9 | **26.2** |
| 200 | 85 | 19.3 | 27.9 | **28.1** |
| 250 | 78 | 15.1 | 22.3 | **26.4** |

Phím bị lọc **vẫn lún và vẫn nổ hạt** — chỉ tiếng bị bỏ. Cú nhả của phím bị lọc cũng im
(`rec.sounded`), nếu không ta chỉ đổi tiếng rè này lấy tiếng rè khác.

Không nút nào ở đây phá tính đồng bộ: mọi phím vẫn chung một mẫu và một công thức — cái
thay đổi là **tốc độ người chơi**, không phải phím nào được gõ.

**Số giọng (`Keyboard.voices`)** — thân 32 / tick 16 / nhả 8. Bắt buộc: mặc định 4 giọng/id
của SoundPool chỉ đủ khi sàn luân phiên nhiều mẫu. Rút về một mẫu thì giọng bị cướp lại
trước khi mẫu kêu xong ⇒ nghe như mất tiếng khi chạy nhanh.

> **Công thức:** số giọng cần = lượt-nhấn/giây × độ-dài-mẫu.
> Walkspeed cap cứng 250 (`Formulas.GetMaxWalkSpeed`) ⇒ tối đa **105 lượt nhấn/giây** (đo
> mô phỏng `touchKeysAt` trên bàn thật). Mẫu 0.277s ⇒ cần 30 giọng, để 32 cho có biên.
> **Đổi `BODY_ID` sang mẫu dài hơn thì phải tính lại `Keyboard.voices`.**

8 mẫu thân thay thế nằm trong thư mục con `Mẫu thân thay thế (KHÔNG dùng)` của
`AllGameSounds_Review/5_ASMR_Floors/Keyboard` — đổi chất tiếng thì sửa `BODY_ID`.

### 4.5. Bàn phím KeyCapper (`Workspace.KeyCapperKeys`) — dùng CHUNG hệ âm mục 4.4

`KeyCapperKeys` là 100 phím do plugin bên thứ ba **KeyCapper v0.5.17** (sebattfg) sinh ra,
lưới 10×10, phím cách nhau 3.15 studs, tâm `(50, 12.7, 118)`. Nó có hệ âm RIÊNG, độc lập
hoàn toàn với engine ASMR — mỗi phím tự mang một `Sound` gắn dưới `Hitbox`.

**Mặc định của plugin sai lệch hẳn với hệ âm của game:**

| | Mặc định plugin | Đã đổi thành | Vì sao |
|---|---|---|---|
| `SoundIds` | `""` → rơi về `Config.SOUND_ID` = `76552892647565` | `rbxassetid://127105730240202` | dùng đúng mẫu thân của game |
| `PitchJitter` | **0.5** = ±50% cao độ ngẫu nhiên mỗi lần bấm | **0** | yêu cầu "mọi phím phát y hệt nhau" |

Chỉnh tại **`ReplicatedStorage.KeyCapperGroups.Default`** (attribute) — đây là ô mà panel
của plugin ghi vào. **KHÔNG sửa `ReplicatedStorage.KeyCapper.Config`**: file đó do plugin
sở hữu và sẽ bị ghi đè khi plugin cập nhật.

Hai chi tiết trong `Detection.Keycap` khiến hai giá trị trên là đủ:
- Chỉ khai **đúng 1** id ⇒ nhánh `if #self.soundIds > 1 then ... math.random(...)` không
  chạy ⇒ hết bốc mẫu ngẫu nhiên mỗi lần bấm.
- `PlaybackSpeed = 1 + (rand*2-1) * pitchJitter` ⇒ jitter 0 thì luôn đúng 1.00.
- Cả hai được resolve **một lần** lúc `Keycap.new` ⇒ phải Play lại mới ăn.

**Lớp TICK + NHẢ**: KeyCapper chỉ phát 1 Sound/lần bấm nên hai lớp còn lại do
`Effects/KeyCapperSFXController.luau` bù vào, bám sự kiện `KeyCapper.KeyPressed`
(điểm mở rộng công khai plugin ghi trong `Config.lua`) — không đụng code plugin.
Âm lượng lấy theo tỉ lệ với `Config.SOUND_VOLUME` (0.5) nên cân bằng 3 lớp giống mục 4.4.

> ⚠️ KeyCapper **không** có sự kiện lúc nhả phím, nên lớp nhả phải hẹn giờ cố định
> (`RELEASE_DELAY = 0.085`, lấy từ sàn ASMR). Đặt 0 để tắt hẳn lớp này.
