# Hệ thống âm thanh — SpeedEscape

> Cập nhật 2026-08-04. Nguồn sự thật là `src/shared/Config/Audio.luau`; file này là bản đọc-được-bằng-mắt của nó.
> Sinh lại số đo bằng `tools/audio_report.luau` (chạy qua MCP `execute_luau`).

---

## Luật nguồn — chỉ 3 nguồn được phép

| Nguồn | Tài khoản Roblox | Dùng cho | Vì sao tin được |
|---|---|---|---|
| **Pro Sound Effects** | `ProSoundEffects` (7462895450) | Toàn bộ SFX + sàn ASMR | Roblox mua bản quyền, cấp free vĩnh viễn cho mọi creator |
| **APM Music** | `APMOfficial` (7462718749) | Nhạc nền + stinger phần thưởng | Licensed chính thức, royalty-free trên Roblox |
| **Monstercat** | `Monstercat` | Nhạc nền EDM | Hợp tác chính thức từ 2020 |

**KHÔNG dùng audio của tài khoản cá nhân.** Không phải vì chất lượng — vì vòng đời. Audio người dùng lẻ chỉ public nhờ luật "≤10 giây tự động public"; người upload privatize lúc nào là game câm lúc đó, **không có log lỗi rõ ràng**, chỉ là tự nhiên hết kêu.

23 ID người dùng lẻ (16 tài khoản) đã được thay sạch ngày 2026-08-04.

---

## Cây mixer

```
Master (100%)
├── ASMR   (100%)  ← tiếng sàn: thứ người chơi tới đây để nghe
├── SFX    ( 75%)  ← zone, pháo hoa, gió
├── UI     ( 60%)  ← nút bấm, modal, phần thưởng
└── Music  ( 30%)  ← nhạc nền, còn bị ducking đè thêm
```

Thực thi ở `src/client/Controllers/Effects/AudioMixer.luau`.

### Ưu tiên ASMR hơn nhạc nền — ba tầng

1. **Volume mặc định** — ASMR gấp hơn 3 lần nhạc.
2. **Sidechain ducking** — mỗi tiếng sàn gọi `AudioMixer.Notify()`, nhạc bị nhân `MUSIC_DUCK = 0.28`. Attack 0.07s (dìm nhanh để bước chân bật ra), release 1.4s (thả chậm để không "bơm" ù tai giữa các bước). Chạy liên tục trên sàn ⇒ nhạc gần như biến mất; đứng yên ⇒ nhạc quay lại.
3. **Nhóm riêng** — kéo nhạc về 0 mà tiếng sàn không suy suyển.

### Lưu âm lượng

Roblox **không có** local storage phía client. Muốn slider còn nguyên lần sau thì phải qua server:

- `DataTemplate.AudioMaster/ASMR/SFX/UI/Music`
- packet `audioSettings` (S→C, lúc profile nạp xong) và `requestAudioSettings` (C→S, throttle 0.45s sau khi thả tay)
- `src/server/Services/Core/AudioSettingsService.luau`

---

## Bảng âm thanh (82 mẫu)

Cột **Dài** là `TimeLength` đo thật trong Studio 2026-08-04.

### Giao diện

| ID | Tên | Nguồn | Dài | Dùng ở |
|---|---|---|---|---|
| `9120410809` | Video Game Buttons 1 | PSE | 0.47s | Click mọi nút |
| `9120149740` | Tone Clusters 11 | PSE | 0.29s | Hover (pitch 1.4) |
| `9120410025` | Video Game Buttons 5 | PSE | 0.85s | Mở modal |
| `9120412048` | Video Game Buttons 20 | PSE | 0.97s | Đóng modal |
| `9120148551` | Tone Clusters 58 | PSE | 0.38s | Toast lỗi (double-thud) |
| `9120151328` | Tone Clusters 32 | PSE | 0.46s | Tick vòng quay |
| `9120150515` | Tone Clusters 23 | PSE | 0.40s | Toast thường |

### Phần thưởng — 5 mốc, 5 âm khác nhau

Trước đây **một** tiếng "Level Up" bị dán vào 8 chỗ. Giờ mỗi mốc có tiếng riêng để người chơi phân biệt được cấp độ phần thưởng.

| ID | Tên | Nguồn | Dài | Mốc |
|---|---|---|---|---|
| `1848274293` | Classic Console – Hit1 | APM | 4.59s | Level up (pitch leo theo combo) |
| `1848274304` | Classic Console – Hit2 | APM | 4.59s | Rebirth (pitch 0.92 → nặng đô) |
| `1848274279` | Classic Console – Tag2 | APM | 1.99s | +Wins |
| `1848274276` | Classic Console – Tag1 | APM | 3.55s | Jackpot roulette |
| `1848281172` | On Our Way – Mnemonic2 | APM | 4.45s | Mở khoá pad / qua stage |

### Nhạc nền (playlist 8 bài, xáo ngẫu nhiên mỗi phiên)

Xen kẽ cao trào ↔ dịu có chủ đích: sáu bài hype liên tiếp làm người chơi mệt tai rồi tắt nhạc hẳn.

| ID | Tên | Nguồn | Dài | Vibe |
|---|---|---|---|---|
| `9042020196` | Powerful Engine | APM | 2:50 | Electro house, sport |
| `7028548115` | Rogue – Move Me | Monstercat | 3:50 | Dance / house |
| `9043887091` | Lo-fi Chill A | APM | 2:17 | Hạ nhiệt |
| `1840441665` | Speed Demon (A) | APM | 2:03 | Hype |
| `5410082805` | Tony Romera – I Can't | Monstercat | 3:04 | Dance vocal |
| `1848354536` | Relaxed Scene | APM | 1:37 | Hạ nhiệt |
| `1837768013` | Rise to the Top (c) | APM | 2:10 | Uplifting |
| `1837768107` | Take Me Higher (c) | APM | 2:00 | Uplifting |

### Sàn ASMR

| Sàn | Số mẫu | Chất liệu |
|---|---|---|
| Keyboard (Zone 15) | 8 | Apple Keyboard 10/13/15/24/28/44/72/85 — 0.35–0.71s |
| SqueakyDuck | 8 | 5 Squeeze Toy + Doll Squeak + 2 pop |
| AquaRun | 7 | 4 Puddle Impact + Small Splash + Bubble Bloop + Wood Bowl Blip |
| BubbleWrap | 6 | 3 pop + 2 Mouth Pop + Paper Bag Crinkle |
| CrystalDrop | 6 | 2 Ceramic Bowl Ping + Wood Bowl + Bloop + Drip Plop + Mouth Pop |
| Jelly | 6 | 4 Wobble Board + Toad Tongue 11 + Mouth Pop |
| Orbeez | 6 | Bloop + Drip + Mouth Pop + Suction + Tentacle Slime + Wood Bowl |
| PopIt | 6 | 3 pop + 3 Mouth Pop |
| KineticSand (+Live) | 6 | 4 Snow Impact + Sand Silt + Dirt Impacts |
| Soap | 4 | Wood Whittle + Wax Seal + Ice Cream Scoop + Mouth Pop |
| SlimeSquish / SlimeJelly / GummySquish | 4 | Tentacle Slime 4 + Toad Tongue 9 + Gooshy Grab + Food Valley 11 |
| Clay | 3 | Gooshy Grab + Tentacle Slime 1 + Toad Tongue 9 |
| MelodyRun | 3 | Tone Clusters 4/10/21 — pitch-shift ngũ cung |

**Vì sao MelodyRun dùng Tone Clusters chứ không phải piano:** chúng là tiếng thuần tone ngắn, gần như không có transient gõ và không có đuôi ngân. Mẫu piano thật khi bị `PlaybackSpeed` kéo lên 2 quãng tám sẽ nghe rõ chất "băng chạy nhanh" (cả tiếng búa lẫn hộp cộng hưởng đều dịch theo); tone thuần thì dịch bao nhiêu cũng vẫn là một nốt sạch.

### Zone / gameplay

| ID | Tên | Nguồn | Dài | Dùng ở |
|---|---|---|---|---|
| `9113286969` | Barstow Wind Howl 2 | PSE | 37.02s | Zone 12, Zone 14, SpeedWind (loop) |
| `9120769331` | Wind Whoosh Sonic Boom | PSE | 5.83s | Sonic boom ≥200 studs/s |
| `9116684884` | Metal Impacts 5 | PSE | 2.01s | Zone 11 stamper (pitch 0.55) |
| `9114592102` | Glass Breaks 11 | PSE | 2.00s | Zone 13 kính vỡ (3D + 2D) |

---

## Nghe & đánh giá từng file

### Trong game — **Sound Lab**

Topbar → bánh răng → tab **SOUND LAB**.

- 82 mẫu, mỗi dòng: nhãn nguồn (PSE/APM/MC) · tên · sàn đang dùng · độ dài · **ID copy được** · nút nghe.
- Lọc: TẤT CẢ / SÀN ASMR / GIAO DIỆN / PHẦN THƯỞNG / NHẠC / ZONE.
- Mẫu ASMR phát qua **đúng nhóm mixer ASMR** (kể cả ducking) — nghe giống hệt lúc chạy trên sàn thật.
- Mọi mẫu phát ở volume 0.8 cố định: mục đích là **so sánh chất tiếng**, nên phải cùng một mức.

Code: `src/client/Controllers/HUD/Modals/SettingsModal.luau`.

### Trong VS Code

1. Mở `src/shared/Config/Audio.luau` — mọi ID + nguồn + độ dài + tag ở một chỗ.
2. Muốn đổi mẫu cho một sàn: sửa `Audio.FLOORS.<TênSàn>`. Không cần đụng file sàn.
3. Muốn đổi âm phần thưởng/UI: sửa `Audio.REWARD` / `Audio.UI`.
4. Chạy `tools/audio_report.luau` qua MCP để đối chiếu lại **nguồn thật và độ dài thật** với bảng khai báo.

---

## Quy trình thêm một âm mới

1. Tìm trên Creator Store, lọc `creatorName` = ProSoundEffects / APMOfficial / Monstercat.
   Mẹo: PSE đánh ID theo cụm series liền nhau — tìm được một mẫu là quét dải quanh nó ra cả bộ.
2. **Verify trước khi dùng** (bẫy đã dính 5 lần trong repo này):
   ```lua
   local info = game:GetService("MarketplaceService"):GetProductInfo(id)
   -- info.AssetTypeId phải == 3, info.Creator.Name phải thuộc 3 nguồn trên
   ```
   ID sai loại asset (ảnh, mesh, script) **không log gì** cho tới khi `:Play()` thật.
3. Thêm một dòng `E(id, "tên", "PSE"|"APM"|"MC", dur, "tags")` vào `Audio.LIBRARY`.
4. Gán vào `Audio.FLOORS` / `Audio.UI` / `Audio.REWARD` / `Audio.ZONE`.
5. Chạy `tools/audio_report.luau` — cột "Khớp?" phải sạch.

---

## Bẫy đã gặp trong repo này

| Bẫy | Triệu chứng | Cách tránh |
|---|---|---|
| ID trỏ nhầm loại asset (ảnh/mesh/script) | Câm hoàn toàn, **không log gì** cho tới khi `Play()` thật | Kiểm `AssetTypeId == 3` trước khi gán |
| Gán lại `SoundId` ngay trước `Play()` | Tiếng ra trễ vài trăm ms (ở 250 studs/s là trễ vài chục studs) | Pool giọng có `SoundId` cố định — xem `ASMR/Engine/SoundPool` và `AudioMixer` |
| Hai bản sao cùng mẫu lệch vài ms | Không thành hai tiếng gõ mà cộng pha thành tiếng méo như lọc lược | Cổng chặn theo **frame** trong `SoundPool.gateOK` |
| Tưởng `SoundGroup` có thuộc tính `.SoundGroup` | `SoundGroup is not a valid member of SoundGroup` — và vì code chạy lúc require nên **kéo sập 20 controller** (console báo "Đã nạp 64" thay vì 84) | SoundGroup lồng nhau bằng **`Parent`**. Chỉ `Sound` mới có `Sound.SoundGroup` |
| Dựng SoundGroup trong `Init()` | Nhạc nền thỉnh thoảng nằm ngoài mixer, lỗi ngẫu nhiên theo lần khởi động | `init.client.luau` duyệt bảng băm nên thứ tự `Init()` không xác định — dựng **lúc require**, nhưng phải bọc `pcall` vì lỗi lúc require sập dây chuyền |
| Audio API mới (`AudioPlayer`) | Không đi qua `SoundGroup`, slider không chạm tới | Nhân tay `AudioMixer.GetVolume()` — xem `SpeedWindAudioController` |
| `PreloadAsync` không cứu độ trễ lần đầu | Vẫn trễ ở lần `Play()` đầu tiên của mỗi Sound | Phải chạy câm một lượt để decode (xem `SoundPool.init`) |
