# PROJECT STATE — Cập nhật sau mỗi session

> **Cập nhật lần cuối:** 2026-07-26  
> **Model làm việc:** Claude Fable 5 (claude-fable-5)

---

## Trạng thái tổng quan

| Hệ thống | Trạng thái | Ghi chú |
|----------|-----------|---------|
| UI Modal headers (Shop-style) | ✅ Hoàn thành | RebirthModal, CosmeticModal, TeleportModal, CodeModal |
| CodeModal | ✅ Hoàn thành | Green theme, promo code input, REDEEM button |
| TreadmillService | ✅ Hoàn thành | Touch detection, ownership check, debounce 0.15s |
| VSCode ↔ Studio sync | ✅ Đã sync | 13 files được ghi từ Studio → VSCode |
| LeftMenu | ✅ Hoàn thành | Wins pill (icon+số), thêm nút Codes (5 buttons total) |
| BottomHud | ✅ Hoàn thành | Speed text căn giữa (plain text, không pill) |
| GamePackets | ✅ Hoàn thành | Thêm `requestRedeemCode` + `toast` packet |
| Rojo sync setup | ✅ Hoạt động | VSCode → Studio (một chiều) |

---

## Files đã thay đổi (so với commit ban đầu)

### Client UI
- `src/client/Controllers/HUD/Theme.luau` — Thêm `Code` asset ID
- `src/client/Controllers/HUD/State.luau` — Thêm code modal state, treadmill animation tracking
- `src/client/Controllers/HUD/HUDController.luau` — Thêm CodeModal, treadmill animation RenderStepped loop
- `src/client/Controllers/HUD/Modals/Manager.luau` — Thêm OpenCode/CloseCode/ToggleCode
- `src/client/Controllers/HUD/Hud/LeftMenu.luau` — Wins display dạng pill, thêm Codes button
- `src/client/Controllers/HUD/Hud/BottomHud.luau` — Speed text căn giữa với AnchorPoint
- `src/client/Controllers/HUD/Hud/RightPanel.luau` — Layout Custom Speed cải thiện
- `src/client/Controllers/HUD/Modals/RebirthModal.luau` — Shop-style header
- `src/client/Controllers/HUD/Modals/CosmeticModal.luau` — Shop-style header, tabs y=100, scroll y=100 size 816×502
- `src/client/Controllers/HUD/Modals/TeleportModal.luau` — Shop-style header, bỏ "PAY TO TELEPORT" frame, scroll y=100 size 816×502

### Client mới tạo
- `src/client/Controllers/HUD/Modals/CodeModal.luau` — **MỚI** — Green theme, 740×380, header 740×90

### Shared
- `src/shared/Network/GamePackets.luau` — Thêm `requestRedeemCode`, `toast`

### Server mới tạo
- `src/server/Services/Gameplay/TreadmillService.luau` — **MỚI** — Full touch detection system

---

## Việc cần làm tiếp theo

### Ưu tiên cao
- [ ] Implement server-side code redemption (`requestRedeemCode` handler trong server)
- [ ] Implement `ProgressionService.SetTreadmillState()` nếu chưa có
- [ ] Test TreadmillService trong Studio (Touched/TouchEnded hoạt động đúng không)
- [ ] Verify Rojo sync đang chạy đúng (không conflict)

### Ưu tiên trung bình
- [ ] Toast system: client nhận `toast` packet và hiển thị
- [ ] Treadmill animation: verify RunAnim play/stop đúng
- [ ] Shop modal: wiring gamepass purchase IDs thực

### Backlog
- [ ] World 2 (Max Level 220)
- [ ] Zone-specific services (Zone7Gravity) — DONE: Zone2Laser, Zone4Boss, Zone5Slide, Zone8Sweeper, Zone9Tsunami
- [ ] Leaderboard UI

---

## Quyết định kỹ thuật đã chốt

| Quyết định | Lý do |
|-----------|-------|
| Rojo sync một chiều (VSCode → Studio) | Studio edit bị mất khi Rojo sync, phải edit VSCode |
| ByteNet thay RemoteEvent | Binary, type-safe, hiệu suất tốt hơn |
| Fusion 0.2.0 reactive | Không dùng direct property set, mọi thứ qua Value/Computed |
| ServiceLocator.Get() trong Init() | Tránh circular dependency |
| Touch counting per-part | Nhiều part trong Run model có thể touch cùng lúc |

---

## Session log

### 2026-07-29 (Session 27) — TopbarPlus 3.4.0, Performance/Night mode, thanh XP đúng tỉ lệ
**Model:** Claude Opus 5 · Playtest PASS: 61 controller, console 0 lỗi mới; ẩn UI giữ nguyên chat;
Performance/Night mode bật-tắt khôi phục ĐÚNG mọi giá trị gốc; thanh XP fill = 0px khi xp = 0.
- **TopbarPlus `1foreverhd/topbarplus@3.4.0`** (wally, bản mới nhất trên registry) thay bản tự dựng.
  `TopBarController` giờ chỉ còn `Icon.new():setImage():setCaption():bindEvent(...)` +
  `settingsIcon:setDropdown({...})` — TopbarPlus tự canh vị trí, caption hover, overflow.
  - ⚠️ **`wally install` GIẾT phiên Rojo**: nó xoá & tạo lại cả `Packages/`, rojo server chết,
    Studio mất Fusion/ByteNet khỏi DataModel (HUD không nạp). Phải `rojo serve` lại + bấm
    **Connect** trong plugin. Sau `wally install` LUÔN kiểm tra `ReplicatedStorage.Packages`.
  - ⚠️ TopbarPlus dựng **4** ScreenGui: `TopbarStandard/Centered` + 2 bản `…Clipped` (vẽ dropdown
    tràn ngoài widget). Whitelist "không được ẩn" phải khớp theo TIỀN TỐ `Topbar`.
  - `:select()` cho mục dropdown phải gọi SAU `setDropdown`, không gọi lúc icon còn mồ côi.
- **Ẩn giao diện CHỪA CHAT**: bỏ `SetCoreGuiEnabled(All,false)`, thay bằng danh sách
  PlayerList/Backpack/Health/EmotesMenu. Verify: `Chat=true` khi đang ẩn.
- **`Effects/ClientSettingsController.luau` MỚI** — Performance Mode + Night Mode, client-only,
  lưu & trả về đúng giá trị gốc:
  - Performance: tắt cosmetic người khác · tắt 5 PostEffect · `GlobalShadows=false` ·
    nước `WaterWaveSize/Speed/Reflectance = 0` · `EnvironmentDiffuse/SpecularScale = 0` ·
    tắt ScreenGui `KeyboardLabels` (tới 800 SurfaceGui) · `CastShadow=false` mọi part nhân vật.
  - ⚠️ **`Terrain.Decoration` KHÔNG còn tồn tại** — gán vào là lỗi "not a valid member" và HUỶ
    nửa sau của hàm (lần đầu chỉ tắt được PostEffect, shadow/nước không đổi mà không báo gì rõ).
  - ⚠️ **`UserGameSettings.SavedQualityLevel` ghi KHÔNG ăn** (đo lại vẫn QualityLevel10) — đã bỏ.
  - ⚠️ `table.clear(savedPerformance)` phải nằm CUỐI hàm; đặt giữa chừng là các khối sau đọc ra
    nil và không khôi phục được.
  - Night: `ClockTime 0`, Brightness 1, Ambient/OutdoorAmbient/ColorShift_Top/FogColor tối +
    `Atmosphere.Color/Decay` (không tối Atmosphere thì trời vẫn trắng đục).
- **Thanh XP**: bỏ `math.max(progress, 0.035)` — cái SÀN GIẢ khiến Level 120 (72K/2.45B = 0,003%)
  vẫn hiện đầy 3,5%. Thêm nhãn phần trăm THẬT ở giữa thanh, số chữ số thập phân co theo độ lớn
  (≥10% → "31%", ≥0.01% → "0.42%", nhỏ hơn → "0.0030%").
  ⚠️ Chưa quan sát được ca xp ≠ 0 vì tài khoản Studio đang kịch trần `STUDIO_SPEED_CAP` nên
  không farm thêm XP được — user nên liếc lại thanh này khi chơi thật.

### 2026-07-29 (Session 26) — Weld aura, gỡ nút Feedback, biển Group Chest, topbar Ẩn UI + Cài đặt
**Model:** Claude Opus 5 · Playtest PASS: 60 controller nạp (thêm TopBarController), console 0 lỗi mới;
ẩn UI tắt 5 ScreenGui + CoreGui và tự bật lại đúng; 2 toggle cài đặt đổi trạng thái thật.
- **"3 chấm xanh nối liền" trên ngực khi trang bị Standard Aura** = GIZMO của `WeldConstraint`
  (Studio vẽ mỗi constraint thành 2 chấm + đoạn nối khi bật "Constraint Details"; 2 weld dùng
  chung điểm torso ⇒ 3 chấm). Đổi sang **`Weld` cũ** (JointInstance — Studio KHÔNG vẽ),
  `C0 = offset`, `C1 = identity` cho part đứng y hệt chỗ cũ. Verify: 0 WeldConstraint / 2 Weld.
  ⚠️ Không tái hiện được trên máy này (visualization đang tắt) — user cần xác nhận lại.
- **Gỡ nút Feedback khỏi HUD** (`Hud/RightPanel.luau`, cả require thừa). Hòm thư trong lobby +
  biển "Feedback" + `FeedbackPromptController` GIỮ NGUYÊN, chỉ bỏ nút.
- **Biển Group Chest**: bản cũ tin `RegularChest.CFrame.LookVector` (-X) nên biển đứng ở cạnh bên,
  không ai thấy. Mặt rương thật quay về **-Z** (verify bằng screen_capture 4 hướng). Mới:
  `position (68, 33, 87.5)`, `facing (0,0,-1)`.
- **`HUD/TopBarController.luau` MỚI** — 2 nút tròn đen kiểu topbar Roblox (icon
  6031075929 mắt-gạch / 6031280882 bánh răng, cả hai verify IsLoaded):
  - **ScreenGui RIÊNG `TopBarExtras`** (không nằm trong CoreLoopHUD) vì nút ẩn UI phải sống sót
    sau khi chính nó tắt mọi ScreenGui khác.
  - Vị trí bám **`GuiService.TopbarInset.Min.X`** (đo được 208 = bề rộng unibar) thay vì hardcode.
  - Ẩn UI = tắt mọi `LayerCollector` trong PlayerGui (nhớ cái nào ĐANG bật để không bật nhầm khi
    hiện lại) + `SetCoreGuiEnabled(All,false)`; ScreenGui dựng SAU khi ẩn cũng bị tắt qua ChildAdded.
  - Bảng Cài đặt: **Nhạc nền** (`BgmController.SetEnabled` — dừng hẳn, `playNextTrack` tự chặn vì
    `Ended` vẫn bắn sau khi tắt) và **Hiệu ứng người chơi khác**
    (`CosmeticVisualController.SetOthersEnabled` — dựng lại ngay cho mọi player khác).
  - ⚠️ `AbsolutePosition` của GUI trong ScreenGui `IgnoreGuiInset=true` bị TRỪ inset (báo Y âm) —
    đừng tưởng nút nằm ngoài màn hình.
- ⚠️ **CẦN LÀM:** (1) User xác nhận 3 chấm xanh đã hết; nếu còn thì thử tắt **Model ▸ Constraints**
  trong Studio để loại trừ gizmo. (2) SAVE PLACE (từ session trước: CosmeticTemplates + bệ trail).

### 2026-07-29 (Session 25) — StandardAuras rig + Premium Trail đủ VFX + gate theo tốc độ + bệ 3D
**Model:** Claude Opus 5 · Playtest PASS: 6 aura đều 13 PE + 8 Beam + 1 Light, 0 beam trỏ ra ngoài
character; 3 trail premium đủ emitter, đứng yên bật 0 / chạy bật đủ; console 0 lỗi mới (59 controller).
- **Kho template MỚI `ReplicatedStorage.CosmeticTemplates`** (place data, KHÔNG do Rojo quản):
  `AuraBasic.Torso` (copy từ model `StandardAuras` user dựng) + `PremiumTrails.<id>` (3 part).
  Đặt ở RS nên không bị StreamingEnabled dỡ như `Workspace.Lobby.TrailBase`; Workspace còn là fallback.
- **Aura standard**: trước đây `workspace.AuraBasic` KHÔNG còn tồn tại ⇒ mọi aura standard rơi xuống
  fallback 1 ParticleEmitter trơn. Nay dựng nguyên rig. ⚠️ Phải **clone CẢ Torso rồi reparent con**:
  8 Beam trong Attachment `B` trỏ `Attachment1` sang `T` cùng cấp — clone riêng `B` là beam kéo dải
  sáng về tận template. Recolor giữ chiều sâu: `primary:Lerp(secondary, luminance màu gốc)`.
- **Màu đúng tên**: 2 kênh phụ phải ≤ 20/255 (rig chồng ~5 lớp additive, kênh chính bão hoà trước nên
  kênh phụ dồn lại làm lõi ngả trắng). Blue (23,74,203)→(7,40,170) v.v. ⚠️ Đã thử hạ `LightEmission`
  1.0→0.5 để bớt cháy sáng: HỎNG — texture nền đen hiện thành tấm chữ nhật tối quanh người.
- **Premium Trail giữ ĐỦ ParticleEmitter** (trước bị `Destroy()` hết): Mystic 5 trail + 13 PE,
  Golden Ray 2 + 2, Crimson 5 + 15. Ribbon vẫn theo cách dựng attachment DỌC như cũ.
- **Gate ẩn khi đứng yên** (`trailGate`, Heartbeat 10 Hz, hysteresis hiện ≥14 / ẩn <7 studs/s, bỏ
  thành phần Y): tránh chùm hạt trail đè lên aura khi đứng. Chỉ áp cho trail premium.
- **Bệ 3D Lobby** (`TrailShowcase`): part nâng y=15.2, orbit RADIUS 3.8 + bob 1.2 (vệt vẽ xoắn ốc),
  `CFrame.lookAt(pos, pos+tangent) * CFrame.Angles(0,0,rad(90))` → ribbon DỌC đúng như lúc đeo,
  `FaceCamera=true`. ProximityPrompt Mystic/Golden dời từ part bay sang đĩa bệ tĩnh (part bay xa 3.8 +
  cao 4.7 làm prompt dist 9 chập chờn).
- ⚠️ **CẦN LÀM:** (1) **SAVE PLACE** — `ReplicatedStorage.CosmeticTemplates` + VFX bệ + 3 script
  `TrailShowcase` + prompt đã dời đều là place data. (2) 3 part tham chiếu user để trong Workspace
  (`Mystic Violet Trail`/`Golden Ray Trail`/`Crimson Fury Trail`, orbit radius 15 quanh lobby) vẫn còn
  — xoá được nếu không muốn thấy. (3) Nhìn mắt thật 6 tông aura trong lobby, báo nếu tông nào lệch tên.

### 2026-07-27 (Session 24) — Zone 15: WalkSurface 47 bàn phím + kí tự phím (LabelYaw)
**Model:** Claude Opus 5 · Playtest PASS: đứng đúng `KB15_001.WalkSurface` Y221.00, 450–648 nhãn
adorned, chữ đọc xuôi cả đoạn +X lẫn +Z, 42 phím lún khi chạy 120 WS, console 0 lỗi mới.
- **Bối cảnh:** user tự sắp xếp/xoay/nghiêng lại các model trong `Zone15.ASMR` (47 model, 4822 phím,
  có model trùng tên KB15_023 ×4; yaw ±90/80, pitch ±30, roll 12/20). Phím `CanCollide=false` nên
  thiếu mặt đi bộ, và `KeyboardLabelController` KHÔNG chạy được vì bàn không có `WalkSurface`.
- **WalkSurface (`tools/zone15_walksurface.luau`, execute_luau Edit):** dựng 46 part (bàn transition
  giữ nguyên part có sẵn). Quy ước theo đúng `KB_Transition14To15`: **walkTop = keyTop − 0.97**.
  Bounds tính trong KHUNG CỦA PHÍM (`keys[1].CFrame.Rotation`) — dùng AABB thế giới thì bàn nghiêng
  30° thừa hàng chục stud ra ngoài mép. 45 part collide; 2 bàn 1-phím trên `Ground.Gate.Chain` để
  KHÔNG collide. Idempotent qua attribute `AutoWalk`.
- ⚠️ **Mặt đi cao hơn deck 1 stud ⇒ hụt `Touched` của Stage15Start** (mặt trên vốn flush deck 220).
  Sửa đúng cách = **dời cả part lên cho mặt trên flush 221.0**; thử kéo Size.Y lên 224 là sai —
  part này Transparency 0 + CanCollide nên hoá bức tường chặn cửa vào zone. Stage15Finish (chỉ là
  mốc đo, không gắn Touched) dời tương tự lên 200.57.
- **Verify không có "sàn ma":** raycast 49 điểm/WalkSurface, LOẠI mọi part động (Mechanics +
  Ground tên Gate/Open/Split/Shift) → 0 điểm treo ⇒ không bàn nào bắc cầu qua bẫy ShiftBridge/SplitFloor.
- **`KeyboardLabelController` v6 → v6.1:** (1) lọc phím theo **lớp MeshPart** thay vì tên chứa "Key"
  — phím Zone 15 tên `"K"` nên bản cũ im lặng không dán chữ nào; (2) **pool GUI**: bàn rời tập gần
  nhất thì SurfaceGui về kho (`Adornee=nil`) thay vì Destroy (chạy dọc hành lang = swap bàn liên tục,
  tạo/huỷ 168 GUI mỗi lần là nguồn khựng); `dropAll` vứt kho vì GUI dưới root cũ đã lìa cây;
  (3) attribute **`LabelYaw`** trên model bàn xoay TextLabel — SurfaceGui Face=Top lấy đỉnh chữ theo
  −Z của CHÍNH PHÍM, user xoay model nên mỗi đoạn chữ quay một kiểu. Quy ước: **đỉnh chữ theo chiều
  chạy**, `LabelYaw = deg(atan2((run × keyLook).Y, keyLook·run))` bội 90; đã set đủ 47 bàn.
- Đo: 450 nhãn (3 bàn) → 648 nhãn (max, trần MAX_LABELS 800), pool tái dùng 300 GUI khi đổi bàn.
- ⚠️ **CẦN LÀM:** (1) **SAVE PLACE** (47 WalkSurface + 47 attr LabelYaw + 2 gate dời — Rojo không
  quản Workspace). (2) Chạy tay cảm nhận bậc 1 stud ở mép bàn phím. (3) Lỗi sound asset
  `3969849183` không có quyền là pre-existing, chưa xử.

### 2026-07-26 (Session 22) — Biển 15 stage chữ to/viền đậm + Zone7 sập theo người + Zone11 ép chậm gate 182
**Model:** Claude Opus 5 · Playtest PASS: biển Z5 3 dòng hiện rõ, Z7 up=30 khi đứng yên/9 trạng thái khi chạy,
Z11 gate 181.9 WS + khói đã hết + hazard vàng→đỏ cam. Console sạch.
- **Biển 15 zone (`Stage{N}SignPart`)**: mỗi SurfaceGui **tách 1 label 2 dòng → 2 label riêng**
  (`Title` 58% cao / `Sub` 30%) — chữ "Stage N" giờ to gấp ~2.4× vì không còn bị chiều cao chia đôi
  + chiều rộng dòng "(Recommend...)" ghì xuống. Bỏ khoảng trắng thừa đầu text (có biển 7 space).
  Viền: thêm `UIStroke` **Title 14 / Sub-Hint 10**, màu (10,26,12). Màu Sub (150,255,190), Hint (255,205,20).
  **Zone 5 có 3 label**: thêm `Hint` = "HOLD  W + C  TO SLIDE" (46/24/23%).
  Kèm **sửa tên part bị trùng**: trước đó 15 biển chỉ có 4 tên khác nhau (Stage1SignPart ×3,
  Stage2SignPart ×9) do clone không đổi tên → nay đúng `Stage{N}SignPart`.
  ⚠️ **BẪY**: set `TextWrapped = false` **TẮT LUÔN `TextScaled`** (Roblox yêu cầu wrap để scale) →
  62 label ban đầu giữ nguyên TextSize 8, TextBounds 35×8 (chữ li ti). Phải set
  `TextWrapped = true` rồi mới `TextScaled = true`. Data nói "TextScaled=true" ở Edit nhưng vào
  Play đọc lại là false — luôn verify TextBounds trong PLAY, không tin thuộc tính lúc set.
- **Zone 7 — cầu jelly chỉ sập KHI CÓ NGƯỜI CHẠY** (`Zone7JellyBridgeScript` v2, ref
  `tools/zone7_collapse_inline.luau` — file này trước đó vẫn là bản CrumblingBlocks lỗi thời):
  sóng vô hạn → vòng NGỦ poll 0.15s, chỉ chạy khi có player trong hộp bao cầu (suy từ chính
  segment) VÀ tốc độ ngang ≥ 6 studs/s. Đợt sóng luôn chạy TRỌN rồi mới dừng (cắt giữa chừng
  sẽ để segment kẹt "fall" = mất sàn vĩnh viễn). Rời cầu → `resetAll()` mọi segment về "up".
  Verify: đứng yên 2.5s = up=30 · chạy = 9 trạng thái sóng · rời cầu = up=30.
- **Zone 11 — máy ép chậm/mở nhanh + gate 182 WS**: `CYCLE 4.4→4.10`, `T_STAMP 0.22→1.70`
  (ép TỪ TỪ), `T_HOLD 0.30→0.35`, `T_RETRACT 0.55→1.15` (mở từ từ nhưng nhanh hơn ép),
  easing `p³`/`(1−p)²` → **smoothstep `p²(3−2p)`** cả 2 chiều.
  **Gate tính từ hình học** (khe chết gapHalf ≤ 8 ⇔ alpha ≥ 0.862 ⇔ p 0.767 ép / 0.234 mở):
  cửa sổ an toàn 3.085s / track 562 studs = **181.9 WS**; WS 170 cần 3.306s ⇒ thiếu 0.22s
  (~38 studs) **luôn bị kẹp** — đúng yêu cầu. Đo runtime khớp: 3.090s / 181.9 WS.
  ⚠️ `closeAlphaAt` phải khớp TUYỆT ĐỐI giữa server (phán xử) và `Zone11StamperController`
  (render) — đã sửa cả hai; lệch là chết oan/hụt.
  **Xóa khói**: bỏ hẳn emitter `CyberDust` + `DUST_TEXTURE` (giữ `CyberSpark`).
  **Đổi màu HazardFace**: LED_IDLE cyan(70,190,255) → **vàng hazard (255,196,0)**,
  LED_ALERT đỏ hồng(255,26,42) → **đỏ cam (255,64,0)**; part tĩnh trong Studio cũng đặt vàng.
- **Vòng 2 (cùng ngày) — 3 chỉnh theo feedback:**
  - **Z11 bỏ nhấp nháy HazardFace**: controller KHÔNG ghi `.Color` nữa (user tự chỉnh màu trong
    Studio, hiện 255,85,88). Xóa `LED_IDLE`; `LED_ALERT` chỉ còn dùng cho laser + tia lửa.
    Verify: 16 mẫu/4.5s = **1 màu duy nhất**, crusher vẫn chạy đúng nhịp.
  - **BIỂN — CHỮ VẪN NHỎ, tìm ra nguyên nhân THẬT**: Roblox **giới hạn CỨNG `TextSize` ≤ 100**
    (kể cả `UITextSizeConstraint.MaxTextSize` set 1000 cũng bị clamp về 100). Với
    `PixelsPerStud = 50`, chữ 100px = **2.0 studs** trên biển cao 19.4 = chỉ 10%. Tách label +
    stroke ở vòng 1 KHÔNG giúp được gì về kích thước. Cỡ chữ trong thế giới = `TextSize ÷
    PixelsPerStud` ⇒ cách DUY NHẤT là **hạ PixelsPerStud 50 → 14**: Title 100px = **7.1 studs
    (37% biển, ×3.5)**, Sub 4.6–5.8 studs, Hint Z5 3.8 studs. Verify ảnh: chữ to rõ rệt.
  - **Z5 EnergyWall + Highlight**: 2 tường (z 1595 / 1748) gắn `Highlight` fill đỏ (255,40,60)
    **0.8** (nhìn xuyên được, không che đường) + viền vàng (255,246,130) **0** +
    `DepthMode = AlwaysOnTop` (thấy tường qua mọi vật cản) → player nhận ra chỗ phải slide từ xa.
- ⚠️ **CẦN LÀM:** (1) **SAVE PLACE** (biển 15 zone + PixelsPerStud + 2 inline script + Highlight
  Z5 + Zone14 8 khối session trước). (2) User chạy tay Zone 11 xem nhịp ép mới có "đọc" được
  không (1.7s ép là chậm rõ rệt so với 0.22s cũ). (3) Nếu chữ biển thấy hơi mềm nét, nâng
  `PixelsPerStud` lên 18–20 (chữ nhỏ lại tương ứng: 5.6–5.0 studs) — đây là đánh đổi trực tiếp
  giữa ĐỘ TO và ĐỘ NÉT, không có cách nào có cả hai vì trần TextSize 100.

### 2026-07-26 (Session 21) — Clay v3 lò xo + Tsunami fix rách hình + Zone14 SlimeSquish 1 khối + WallGuard
**Model:** Claude Fable 5 · Playtest PASS: clay nảy vượt đà 2.387>2.2, tsunami 14 part bám cụm 22.5,
SlimeSquish 4 skin ~3680 vertex + chân lún, 3 cú tông tường @250 maxVy 0.9 (không văng), kính Z13 vẫn xuyên.
- **Clay squish v3 (feedback "0.75 lún quá sâu, muốn phê/nghiện hơn"):** MAX_SQUISH 0.48, BULGE 0.16,
  PRESS 20, RADIUS 9.5 (ô kề lún nhẹ theo = sóng); thả chân = **lò xo cosine tắt dần**
  `disp = depth·exp(-3t)·cos(12t)` → ô bật VƯỢT kích thước nghỉ ~45% độ lún rồi rung tắt (đo 1.80→2.387);
  **lit color** sáng dần theo mức lún (lerp 32% về trắng ấm); ngưỡng ghi WRITE_EPS 0.006 (chống re-batch).
  ⚠️ Bài học: jiggle CỘNG THÊM vào đường hồi phục exp không bao giờ thắng nổi để vượt đà —
  muốn overshoot phải để damped-cosine LÁI toàn bộ pha thả.
- **Tsunami rách hình trên client (user báo, server view lành):** thủ phạm = `model:PivotTo` mỗi frame
  + StreamingEnabled: part stream về LẺ TẺ tại vị trí home của server giữa lúc model client đã trôi
  → offset part↔pivot sai vĩnh viễn. Fix Zone9TsunamiController v5: nhớ **offset từng part so với
  homeCF (từ attribute)** lúc part xuất hiện (DescendantAdded + poll 0.5s), mỗi frame set
  `part.CFrame = waveCF × rel`. Đây là pattern chuẩn cho MỌI model client-side di chuyển dưới streaming.
- **Zone 14 → SlimeSquish 1 KHỐI DUY NHẤT (user đổi ý từ jelly obby):** 19 model Jelly14 backup
  `ServerStorage.Zone14_Backup_JellyObby`. Model mới `Zone14.ASMR.SlimeRun14`: WalkSurface 624×1×68
  top 221.5 + Blocks.SlimeBody 624×6×68 đục RGB(38,148,34). Adapter MỚI
  `Floors/SlimeSquish.luau` (EditableMesh, thay SlimeSwamp đã xóa hôm qua): 4 skin plane CELL 3.5
  (~3680 vertex) SmoothPlastic opaque RGB(70,214,52) tại walkTop+0.75 (chân lún tới cổ chân),
  hố lún DENT_R 9.5/DEPTH 2.6 press 14/recover 3.2, sóng tĩnh 0.6, mép rũ EDGE_DROP 1.35 tính theo
  bounds toàn đầm, per-vertex normal central-diff vùng đổi. Skin client-side tại
  `workspace.SlimeSquishSkins` (attr Owner để dọn khi re-attach). Teleport S14 → "Slime Squish".
  ⚠️ Pitch lưới = span/nx (KHÔNG dùng CELL tròn — lệch nửa ô là vertex nhảy khi lún lần đầu).
- **WallGuard (user báo vẫn văng khi tông tường @250):** cơ chế văng = engine giải xuyên thấu bằng
  xung hất trong 1 tick, người bay lên trời là hết Grounded → Grip bó tay. Fix 2 lớp trong
  ParkourBrake: (1) raycast theo hướng vận tốc (ProbeAhead 0.06s, MinSpeed 45) thấy tường đứng →
  CẮT thành phần lao vào tường TRƯỚC va chạm; (2) cửa sổ hậu va chạm 0.35s kẹp vy ≤ 26 + trần ngang
  Grip KỂ CẢ trên không. Session thêm field `wallGuardUntil`.
  ⚠️ **`MakeRaycastParams` giờ set `RespectCanCollide = true`** — không có nó, WallGuard/blockcast
  slide coi cổng thủy tinh Z13 (client CanCollide=false, CanQuery=true) + tường năng lượng Z5 là
  tường thật → cắt đà ngay trước cổng, phá cơ chế đâm-xuyên. Lưu ý kính Z13 server vẫn
  CanCollide=true (client mới tắt) → mọi test phải chạy ở Client VM.
- **Zone 14 vòng 3 (cùng ngày, user chê EM "gồ ghề"):** BỎ hướng EditableMesh — xóa
  `Floors/SlimeSquish.luau` + model SlimeRun14. Bản CHỐT: **ô squish y hệt Zone 2, mặt sàn PHẲNG**
  — `Ground.SlimeBase14` 624×6×68 top 220.5 (sàn đi bộ thật, SmoothPlastic RGB 38/148/34) +
  **584 ô SlimeTile** (clone ClayTile RoundCube 8×2.2×8, pitch 8.5, nhô 1.3, 3 tông xanh) trong
  4 model `Slime14_1..4` FloorType=**Clay**. `Clay.luau` thêm override per-model qua attribute
  **`MaxSquish`/`Bulge`** — Zone14 đặt MaxSquish 0.75 (sâu hơn Zone 2 0.48), không attr = mặc định.
  Verify: dậm tâm ô Size.Y 0.56 (kỳ vọng 0.55), top tụt 0.34 dưới sàn thành hố, rời chân nảy 2.53>2.2.
- **Zone 14 vòng 4 (user: "4 SlimeTile lớn thay vì hàng trăm"):** 584 ô → **4 tấm 153×2.2×66**
  (khe 4, nhô 1.3, Bulge hạ 0.01 kẻo tấm 153 phình +18 đè nhau). `Clay.luau` thêm **inset AABB
  per-record** `inset = max((size−8)/2, 0)` — đo khoảng cách chân tới VÙNG THÂN ô thay vì tâm
  (tấm to đo tâm = đứng giữa không lún, đúng vết SlimeJelly cũ); ô 8×8 inset=0 → Zone 2 không
  đổi cảm giác. Verify: đứng lệch tâm 38 studs lún full 0.56, rời tấm nảy 2.53.
- **Zone 14 vòng 5 (user: xóa nền, mesh user, cao 5, xếp obby):** XÓA SlimeBase14; 4 tấm =
  clone `workspace.SlimeTile` (mesh user chọn 101862116072539) **147×5×66**, obby đơn giản
  khe 12 studs, tops 221.5/224.5/222.5/221 (nhảy +3 rồi xuống dần về finish 220); mỗi model có
  **`Collider`** vô hình top = tileTop−1.2 (mặt đi bộ thật — không còn nền, rơi khe =
  KillBlockGlobal Y149); MaxSquish 0.28 (lún 1.4 ≈ mức chân — không thành hố làm chân lơ lửng).
  Verify: chân 220.30/223.30 đúng walkTop, đè 5→3.60, rời tấm nảy 5.28>5.
- **Zone 14 vòng 6 (theo ảnh mẫu — "y chang bắt buộc"):** hiệu ứng đổi từ scale-cả-tấm sang
  **VẾT LÕM CỤC BỘ quanh chân trên khối trong suốt** (đúng ảnh). `Floors/SlimeSquish.luau` v2
  (viết lại): client giấu `Tiles.SlimeTile` bằng LocalTransparencyModifier=1 rồi dựng **khối
  EditableMesh cùng size/màu** (mặt trên lưới CELL 3 PHẲNG tuyệt đối — không sóng, mép bo FILLET 1.4,
  thành + đáy khép khối, DoubleSided), lõm DENT_R 7 sâu 1.35 press 16/recover 3.5, normal
  central-diff vùng đổi, active-map → đứng ngoài sàn = 0 chi phí. 4 model FloorType=SlimeSquish
  (bỏ MaxSquish/Bulge). Look chốt: **Glass trans 0.18, RGB(32,170,36)** (thử 0.25/0.13/0.08 —
  atmosphere zone rửa màu phần xa, cần user nhìn mắt thật). Verify: 3-4 skin dựng, tile gốc giấu,
  lõm bám chân, console sạch.
  ⚠️ screen_capture trả FRAME STALE khi chụp cùng camera position nhiều lần (3 ảnh giống hệt dù đã
  đổi thuộc tính) — đổi hẳn góc camera mỗi lần chụp so sánh.
- **Zone 14 vòng 7 — SOFT BODY (yêu cầu user):** SlimeSquish nâng lên **mass-spring lattice**:
  mỗi vertex mặt trên = chất điểm `y'' = K(target−y) + C(lap kề − y) − D·y'` (K 110, D 6.5,
  C 230, semi-implicit Euler, dt kẹp 1/30 chống nổ) — dậm tạo SÓNG GỢN LAN RA, đáp mạnh bơm xung
  LAND_KICK 24×(vy/60), sóng tự đánh thức vertex kề (SPREAD_EPS 0.04), tự NGỦ khi lặng
  (SLEEP 0.012/0.06, trần MAX_ACTIVE 1400). Debug attr **`SSActive`** trên model = số vertex đang
  mô phỏng (throttle 0.3s). Đo: đứng 56 · đáp đôi peak 80 · chạy 250 để vệt sóng 122 · rời tấm
  → 0 sau ~1.2s (idle = 0 chi phí).
- **Zone 14 vòng 9 (CHỐT): 8 khối + mesh mới + lún mạnh + cổng tốc độ**
  - **8 khối** (thay 4) `Slime14_1..8`, mỗi khối 71×5×66 clone `workspace.SlimeTile` mesh MỚI của user
    (**12634586773**), khe 8, tops 221.5/223.5/222/224.5/222.5/224/222/221 (obby nhấp nhô).
  - **Lún nhanh + to** theo feedback: DENT_R 7→**8.5**, DENT_DEPTH 1.35→**2.0**, SPRING_K 110→**200**,
    LAND_KICK 24→**30**, FILLET 1.4→**2.2**. Mở 3 attribute `Fillet`/`DentRadius`/`DentDepth` để
    chỉnh trong Studio. Thêm debug attr **`SSDepth`** (độ lún sâu nhất, throttle 0.3s).
    Đo thật: đứng lún **1.52** studs · chạy **1.85** + 109 vertex sóng · đáp đúng tâm **2.74**;
    phản hồi đạt 80% độ sâu trong **0.17s**.
  - ⚠️ **Mesh user KHÔNG deform được**: `CreateEditableMeshAsync` → "no permission to load asset"
    (mesh không thuộc tài khoản chạy game). Nên client vẫn dựng khối bo mép riêng theo size/màu/
    độ trong của tile; mesh gốc chỉ có tác dụng ở Edit/server view. Muốn deform mesh riêng thì
    phải upload mesh vào chính tài khoản game.
  - ⚠️ **Fix skin trùng/thiếu**: watchdog engine re-attach trong lúc coroutine build cũ còn treo
    → tạo skin THỨ HAI (đo được Slime14_1 ×2, 1 model mất skin). Fix: cờ `destroyed` chặn build
    zombie + dọn skin cùng Owner ngay trước khi gắn. Verify sau fix: 8 model / 8 skin / 0 trùng / 0 mồ côi.
  - **`Zone14SlimeService.luau` DỰNG LẠI** (dùng hợp đồng `TerrainDrag` sẵn có trong
    ProgressionService): base ≥ `Stages.STAGE_GATES[14].minWS` (218) → drag 1 (đi thoải mái);
    thiếu chuẩn → `(base/218)³`, sàn tuyệt đối `MIN_CRAWL_SPEED` 10 studs/s. Vùng slime đọc runtime
    từ các `Collider` (kéo/thêm tấm trong Studio là tự cập nhật). Đo: WS 250 → 250 (drag nil) ·
    WS 180 → 101.3 (0.563) · WS 150 → 48.9 (0.326) · WS 60 → 10 (sàn) · rời sàn → gỡ drag ngay.
  - ⚠️ **BÀI HỌC TOOL:** KHÔNG dùng PowerShell regex (`Get-Content`/`Set-Content`) sửa file .luau —
    PS 5.1 đọc ANSI/ghi UTF-8 làm **hỏng toàn bộ tiếng Việt** (mojibake) + regex tạo self-reference.
    Đã phải viết lại cả file. Luôn dùng Edit/Write tool.
  - ⚠️ QA: anti-cheat giật player về vị trí cũ (log "teleport 545 studs → giật ngược") khiến phép đo
    đứng nhầm tấm ra kết quả giả (SSDepth 0.07). Luôn ĐỌC LẠI vị trí thật rồi tìm tấm gần nhất để đo.
- ⚠️ **CẦN LÀM:** (1) **SAVE PLACE** (Zone14 8 khối + backup jelly + laser/clay/tsunami session trước).
  (2) User chạy tay: cảm nhận nhịp nảy clay (chỉnh JIGGLE_FREQ/DECAY), độ dính WallGuard gần tường
  (hạ ProbeAhead nếu thấy "đệm vô hình"), squish slime Z14. (3) Selene pre-existing
  CosmeticVisualController:552 chưa xử.

### 2026-07-25 (Session 20) — Laser Z2 + Squish v2 + Tsunami v6 + Zone14 Jelly obby + Movement v2
**Model:** Claude Fable 5 · Playtest PASS: 3 laser Z2, tsunami attrs theo pivot user, 19 model jelly attach
(wobble ±0.5), anti-spin 69→0 rad/s trong 0.1s, console 0 lỗi mới.
- **Zone 2 laser:** `Laser2_1` bị mất (chỉ còn LaserSweeper1@440 + LaserSweeper2@708) → clone lại từ
  LaserSweeper1, đặt Platform_4 (z=574), xóa attr RPM/Dir/BaseCF để service ghi theo config (rpm 28).
  Kèm lấp **8 ô clay bị xóa nhầm** cùng laser cũ (nguyên hàng z=623.3 trên Platform_5, audit lưới
  pitch 8.5 + raycast Ground). Service log "3 laser".
- **Squish (Clay.luau):** MAX_SQUISH 0.60→**0.75** (dậm giữa ô tụt dưới mặt sàn ~0.35 = hố lún rõ),
  BULGE 0.30→**0.10** (bản cũ ô 8 studs phình 10.4 > pitch 8.5 → chồng lấn ô bên cạnh).
- **Zone 9 Tsunami v6:** user chỉnh tay vị trí model trong Edit → patch inline TsunamiScript:
  `homeX = homePivot.Position.X` + `channelZ = pivot Z` (bỏ neo mép kênh v5 — controller client đã ẩn
  sóng pha chờ nên park ngoài kênh không còn lộ). Verify runtime: WaveHomeX=-137.46 WaveY=24.46 đúng
  pivot. Bản tham chiếu `tools/zone9_tsunami_inline.luau` đã đồng bộ.
- **Zone 14 ĐẬP LÀM LẠI theo ảnh user (jelly obby xanh):** XÓA hệ SlimeSwamp — model backup
  `ServerStorage.Zone14_Backup_SlimeSwamp`, xóa file `Zone14SlimeService.luau` + `Floors/SlimeSwamp.luau`
  (Rojo sync xóa OK, engine còn 14 loại sàn). Dựng **19 model `Jelly14_S*`** (23 khối MeshPart clone
  slime mesh 101862116072539, Glass 0.2 xanh RGB 52/195/55): đường nhảy 15 đảo x2058→2648 (top 220.8–238,
  gap 11–16, stack 2 tầng + 4 tháp deco), mỗi model = Collider vô hình (top = mặt thạch −0.5) + Blocks,
  FloorType=Jelly YTol=4 tag ASMRFloor Atomic. Rơi = KillBlockGlobal Y149 sẵn có. Teleport stage_14
  mô tả → "Jelly Jump". **Patch `Jelly.luau`:** nearestBlock reach giãn theo cỡ khối
  (max(6.8, size×0.62) — bài học BubbleWrap POP_R2, khối 34 studs mà giữ 6.8 là chết wobble).
- **Movement v2 (Parkour):** (1) **TurnAssist** — xoay vector vận tốc ngang về hướng phím (giữ độ lớn)
  khi Grounded, Rate 9/s, MinSpeed 30 → cua gắt @250 không bị quán tính kéo vòng rộng; (2) **AntiFling**
  — kẹp AssemblyAngularVelocity >18 rad/s về trục Y (hết xoay tít khi va đập); (3) **phanh động**
  BrakeAccelPerSpeed=3 (gia tốc phanh = max(550, speed×3) → quãng dừng ổn định mọi WalkSpeed);
  (4) `ParkourUtil.MakeRaycastParams` loại TẤT CẢ nhân vật player khỏi blockcast → hết ngắt slide oan
  khi lướt qua người khác (va chạm player-player vốn đã tắt bởi CollisionGroupService).
  ParkourBrake.Update nhận thêm `dt`.
- ⚠️ **CẦN LÀM:** (1) **SAVE PLACE** (laser + 8 ô clay + 19 model jelly + TsunamiScript đều trong DM,
  chưa vào .rbxlx). (2) User tự chạy tay cảm nhận TurnAssist/phanh (bot không mô phỏng input thật);
  nếu lái "arcade" quá thì hạ `TurnAssist.Rate` 9→5-6 trong ParkourConfig. (3) Lỗi selene pre-existing
  CosmeticVisualController:552 (if_same_then_else) — nên xử lý sau.

### 2026-07-15 (Session 16) — ASMR zones v4: FIX LAG (65k instance) + xoay chữ đúng hướng chạy
**Model:** Claude Fable 5 · Verify data PASS (đo instance + orientation; FPS phải test tay — MCP throttle).
**Feedback user sau v3:** (1) chữ keycap NGƯỢC hướng — muốn đọc xuôi theo hướng chạy; (2) game
SIÊU LAG từ khi lát sàn (MicroProfiler: FPS 25.8, 31k ParticleEmitter + 30k Sound + 30k SurfaceGui
render vô hạn khoảng cách, 312k instance).
- **HƯỚNG CHỮ (builder v4, ref `tools/zone_asmr_build_v4.luau`):** keycap SurfaceGui Face=Top;
  quy tắc Roblox: part identity → đỉnh chữ quay về Front (−Z). Template boardwalk orient (0,−90,0)
  = đỉnh chữ +X (đọc xuôi khi chạy +X) — corroborate quy tắc. Fix zone: dọc +Z → yaw 180°
  (đỉnh chữ +Z); hành lang ngang (heuristic z∈2980–3080 & x>50) → yaw −90° (đỉnh chữ +X).
  Verify: Z1 key orient (0,180,0), Z13/Z11 (0,−90,0).
- **FIX LAG (giữ nguyên chức năng):**
  - Xóa `Sound` con mọi key zone (22.414) — v5 phát âm qua pool nên Sound con là đồ thừa từ đầu.
  - Xóa `Stars` con (22.414) → **KeyboardASMRClient v5.1**: sparkle POOL 12 emitter dùng chung,
    playKey dời emitter tới phím rồi Emit(2); phím lobby còn Stars riêng thì dùng như cũ.
  - GIỮ chữ (SurfaceGui/TextLabel 22.414) nhưng **MaxDistance=60** → đo runtime chỉ 279/12.423
    SurfaceGui trong tầm render (2,2%) thay vì render TẤT CẢ như trước.
  - Zone 11 Persistent: phím TRẦN ClearAllChildren (bỏ 20.700 instance thường trực trên MỌI client).
  - Tổng: **giảm ~65.5k instance** + render SurfaceGui giảm ~98%. Đây là nguồn lag chính
    (Render 22.9ms 61% trong profiler user).
- Đã rebuild 15 zone bằng v4 (counts giữ nguyên: Z1 1104, Z4 9801, Z11 6900, Z13 3818...).
  222 script + lobby v5.1: 0 lỗi syntax. Sound=0, Emitter=0 trong ASMRFloors.
- ⚠️ **CẦN LÀM:** (1) SAVE PLACE. (2) User tự đo FPS máy thật (MCP đo không tin được — viewport
  không render khi background). (3) Nếu VẪN lag: bước tiếp = giảm mật độ key Z4 arena (9801) hoặc
  bỏ chữ Z4, và/hoặc hạ StreamingEnabled radius.

### 2026-07-15 (Session 15) — ASMR zones v3: phím có chữ+âm+hiệu ứng, xóa base thừa, Zone9 1 aqua
**Model:** Claude Opus 4.8 · Playtest PASS: phím có SurfaceGui(chữ)+Sound+Stars, popit patch pop 5 bubble.
**Feedback user sau v2:** (1) phím keyboard thiếu chữ/âm/hiệu ứng (v2 lỡ `ClearAllChildren`);
(2) xóa UnderBase/Rim/Base thừa; (3) Zone 9 chỉ 1 AquaRunFloor resize vừa zone.
- **ASMRZoneBuilder v3 (ref `tools/zone_asmr_build_v3.luau`):**
  - **Keyboard GIỮ children key** (SurfaceGui chữ cái + Sound + Stars) — bỏ ClearAllChildren. Âm thanh
    vẫn qua pool v5 (verify pool phát). Sparkle (Stars) + chữ (SurfaceGui) hiện lại đúng ASMR_Test.
  - **Xóa part base visible** non-keyboard: clay `UnderBase`, popit `Base`+4`Rim`, bubblewrap `Base`,
    melody `Base`, jelly `Tray`, soap `Tray`+`Collider`. GIỮ `Collider` ẩn (clay/jelly — script dùng).
    → **PATCH script** popit/bubblewrap/melody (dùng `Base`) + soap (dùng `Tray`): inject `__asmrBox`
    tự tính bounds từ tile folder. Verify: baseTop tính ra 9.22 = khớp Base gốc 9.2, footY 7.80,
    detect FIRE (diff 1.42<2.6); playtest đi qua popit → 5 bubble pop = script chạy đúng.
  - **Zone 9: 1 AquaRunFloor** resize Basin 561×84 + WaterSurface 560×83 phủ WaterFloor, bỏ 4 Edge
    (thay 28 clone). AquaRunClient auto-adapt từ basin/surface.
  - Giữ từ v2: clone tile THẬT không resize, đáy tile = floorTop+0.02 (nổi trên mặt), mọi part
    non-collide/touch → player đi sàn zone gốc, chức năng nguyên vẹn. 222 script, 0 lỗi syntax.
- **Counts:** Z1 1104, Z2 24clay, Z3 24bw, Z4 9801, Z5 36popit, Z6 6melody, Z7 60jelly, Z8 2401,
  Z9 1aqua, Z11 6900, Z12 12soap, Z13 3818, Z14 8clay, Z15 32melody, strips ~400/zone.
- ⚠️ **Bài học tool:** screen_capture hay trả frame TỐI/mờ sau nhiều thao tác (lỗi render tool, không
  phải game) — verify bằng data + physical test (đếm bubble pop) thay vì tin screenshot.
- ⚠️ **CẦN LÀM:** SAVE PLACE; Z4(9801 key)+Z11(6900 key) nặng (giữ full children càng nặng) — offer trim.

### 2026-07-15 (Session 14) — LÀM LẠI ASMR zones: CLONE model thật (không sinh mới), nổi trên mặt
**Model:** Claude Opus 4.8 · Playtest PASS: tile nổi trên floor (không chìm), đúng theme, laser/glow/teleport OK.
**Bối cảnh:** bản Session 13 bị user CHÊ 2 lỗi: (1) tile là "tạo mới" (Instance.new + RESIZE) chứ
không phải copy floor thật từ ASMR_Test; (2) tile CHÌM NGHỈM dưới mặt đất (ảnh user gửi).
- **ĐẬP ĐI LÀM LẠI (`ServerStorage.ASMRZoneBuilder` v2, ref `tools/zone_asmr_build_v2.luau`):**
  builder idempotent, xóa `Zone{N}.ASMRFloors` cũ + gỡ 2100 ASMRKey đã nhét trong Section Zone11.
- **Non-keyboard (clay/bubblewrap/popit/melody/jelly/aqua/soap): CLONE NGUYÊN MODEL** từ ASMR_Test
  (giữ y hệt Tiles/Bubbles/Bars + base + script), lát grid theo ĐÚNG footprint gốc (đo runtime:
  clay 35.7², bubblewrap 35.1², popit 32.9², melody 35.8², jelly 36², aqua 42², soap 36.6×34),
  clip tile thừa ngoài mép part, mỗi clone 1 script (early-out rẻ khi player không đứng trên →
  perf OK vì StreamingEnabled chỉ chạy script của zone hiện tại).
- **Keyboard (zone 1,4,8,13 + strips): 1 section + clone KEY THẬT** (đúng 3×1.37×3, ClearAllChildren
  cho nhẹ, giữ keycap mesh) lát CELL=3, 1 script v5 (GLOW_THEME = theme của zone → MỌI zone keyboard
  đều có RGB glow theo chân). Zone 11: key thả vào Section model (sập+hồi sinh cùng cầu, Persistent).
- **CĂN Y (fix chìm):** đáy tile = mặt trên zone floor + 0.02 → tile NỔI HẲN trên mặt. Verify số:
  Z1 key bottom 8.02 > floorTop 8.00; Z13 (Y220) key 220.02; Z6 melody trên shrink core (top 1.0)
  = 1.02; Z15 melody bám từng đảo I1..I6 (220.8→248.6). KHÔNG còn chìm.
- **GIỮ CHỨC NĂNG ZONE:** mọi part clone CanCollide=CanTouch=CanQuery=false → player VẪN đi trên
  sàn zone gốc → Stage/pad/laser/sweeper/checkpoint chạy y nguyên (playtest: laser Zone 3 vẫn quét,
  teleport packet + đứng sàn OK, glow hồng dưới chân = keyboard detect player). Base (Tray/Collider)
  chìm dưới floor, bị khối floor che. Jelly patch tolerance 3→5.5 (player đứng sàn thấp hơn collider).
- **Theme map (đúng list user):** Z1 Plain·Z2 Clay/Squish·Z3 BubbleWrap·Z4 Dark rainbow·Z5 PopIt·
  Z6 Melody(trên 6 shrink core)·Z7 Jelly(trên crumbling blocks)·Z8 Dark grey·Z9 Aqua·Z11 Light
  Rainbow·Z12 Soap·Z13 Red With White·Z14 Clay(Start+End floor)·Z15 Melody(từng đảo). Z10 bỏ (thang).
  Mọi Transition/Stage strip = keyboard Plain glow. Tổng 249 script, 0 lỗi syntax.
- **Counts:** Z1 1104key, Z2 24clay-clone, Z3 24bw, Z4 **9801key** (arena 300×300 — nặng, offer trim),
  Z5 36popit, Z6 6melody, Z7 60jelly, Z8 2401key, Z9 28aqua, Z11 **6900key**(cầu sập), Z12 12soap,
  Z13 3818key, Z14 8clay, Z15 32melody. Strips ~400key/zone.
- ⚠️ **CẦN LÀM:** (1) **SAVE PLACE** (toàn bộ clone + ASMRZoneBuilder + 2100 key gỡ khỏi Zone11 chưa
  vào .rbxlx). (2) Zone 4 (9801) & Zone 11 (6900) nặng — nếu lag báo để trim. (3) Zone 6/7 tile không
  di chuyển theo cơ chế động (melody đứng yên khi platform co, jelly đứng yên khi block sập) — cơ chế
  vẫn chạy, chỉ hơi lệch visual; báo nếu muốn bỏ.

### 2026-07-15 (Session 13) — ASMR zones toàn map + Keyboard v5 + pháo hoa tại màn hình 3D + Pass ID
**Model:** Claude Fable 5 · Playtest PASS trong Studio: console sạch, glow/pháo hoa/BGM/Z11 collapse verify.

- **Task 4 — Pass ID cosmetic (Rojo):** điền 6 ID thật vào `Config/Economy/Gamepass.luau`:
  Dark Aura 1912234503 (299), Flame Aura 1909292663 (499), Red Heart Aura 1912096528 (799),
  Mystic Violet 1911802508 (399), Golden Ray 1912472263 (599), Crimson Fury 1911958542 (899).
  Auras/Trails.luau đọc qua `Gamepass.*` nên tự chảy xuống billboard + CosmeticModal + GamepassService.
- **Task 3 — BGM (Rojo `Effects/BgmController.luau`):** track 1840618037 VÀ 1843415711 đều không
  phải Sound ("Asset type does not match") → thay bằng 1837879082 (162s) + 1848354536 (97s), giữ
  9043887091 (137s) — cả 3 verify IsLoaded=true. Thêm WATCHDOG: track không load trong 6s → tự nhảy
  bài (Ended không bao giờ bắn với asset hỏng → hết cảnh BGM chết lặng vĩnh viễn). Verify: playlist
  xoay đủ 3 bài trong playtest.
- **Task 1 — ASMR trễ nhịp (9 script inline Workspace):** NGUYÊN NHÂN GỐC: (a) KeyboardASMRClient v4
  có hàm preload KHÔNG BAO GIỜ được gọi (`local __dummy = (function() ... end)` thiếu `()`);
  (b) PreloadAsync chỉ tải bytes — lần Play đầu của MỖI variant vẫn decode ngay lúc đạp → các bước
  đầu trễ 100-300ms. FIX toàn bộ floor script: preload + **WARM** (phát Volume=0 một lần lúc load),
  `RollOffMinDistance=18` (âm bước chân của mình luôn full volume), nhịp trigger dày hơn
  (sand 2.4/0.12→2.0/0.09, clay 2.6→2.2, bubblewrap 3.2→2.6, jelly 3→2.6, aqua 2.4→2.0, soap 2.2→2.0).
  Bỏ hardcode Y: Melody topY, Soap surfY, sand-test surfY giờ suy từ part (cần cho bản clone zone).
- **Task 5 — KeyboardASMR v5 (viết lại, ref `tools/asmr_keyboard_inline.luau`):** SOUND POOL 32
  Sound tái sử dụng (không Instance.new+Debris mỗi lần đạp); bộ 6 click bàn phím cơ MỚI
  ProSoundEffects CU Clicks (9116158528/8927/8128/8896, 9116157307, 9116158538 — 0.24-0.33s,
  verify IsLoaded) + pitch ngẫu nhiên; **RGB GLOW theme "Plain"**: đi đến đâu phím sáng đến đó —
  vầng cầu vồng bán kính 8 quanh chân, phím bị đạp chớp glow=1, tắt mềm exp. Áp cho cả 6 bàn phím
  boardwalk (sound) + mọi section Plain trong zones (glow).
- **Task 2 — Pháo hoa ServerBoost về màn hình 3D (Rojo `HUD/BoostCelebration.luau`):** rocket giờ
  phóng từ CHÂN màn hình 3D tại Transition1To2 (dùng `getInfoScreenCFrame()`, offset theo
  RightVector/LookVector màn hình), nổ bung QUANH màn hình (apex +58..108). Tia BỰ hơn: burst size
  4.6/Emit 110/Speed 26-40, core ball 30, glitter 2.2/70, rocket 1.6×5.5, light range 90. Âm ĐÃ hơn:
  volume 1.35 + tầng BOOM bass (PlaybackSpeed 0.4-0.52) chồng lên, RollOffMin 45/Max 700. Gate
  particle đổi sang <700 studs quanh MÀN HÌNH. Verify: watcher client đo 8 rocket đồng thời,
  10 burst, panel spawn (-4, 74.4, 324) đúng vị trí.
- **Task 6 — ASMR Floor phủ 15 zone (~16.000 part, 36 section):** builder
  `ServerStorage.ASMRZoneBuilder` (ref `tools/zone_asmr_build.luau`), idempotent
  (`require(...)({1..15})` xóa `Zone{N}.ASMRFloors` cũ rồi regen).
  **Nguyên tắc:** tile chỉ là VISUAL (CanCollide/CanTouch/CanQuery=false), nhô ≤0.5 stud, player
  vẫn đi trên sàn gốc → mọi Touched (Stage/Transition/pad/laser/sweeper/blockcast slide) nguyên
  vẹn + mọi đường đi phẳng đúng cao độ cũ. Section = Model **Atomic** (stream-in là script thấy đủ
  tile — né bài học StreamingEnabled S11); script clone từ bản lobby đã nâng cấp + patch nhỏ
  (`__waitStable` chờ replicate, CELL/KEY_REACH theo zone).
  Map: Z1 Plain(612) · Z2 Clay/Squish(1035) · Z3 BubbleWrap(1152) · Z4 Dark rainbow(2401, cell 6)
  · Z5 PopIt(1666, trên SlideFloor) · Z8 Dark grey(1369) · Z9 AquaRun(surface trên WaterFloor)
  · Z11 **Light Rainbow(2100, cell 5) đặt TRONG Section model → phím SẬP + HỒI SINH cùng cầu**
  (Section set Persistent; script gom key qua path Sections + guard tên ASMRKey)
  · Z12 Soap(27 bar) · Z13 Red With White(1650) · Z14 Clay trên StartFloor+EndFloor(255)
  · Z15 Melody 9 section/từng đảo vì cao độ khác nhau (1329). MỌI Transition/StageStart/StageFinish
  15 zone = Plain keys có glow (~2.900). Zone 6 (shrink platform Touched), Zone 7 (crumbling
  unanchor+physics), Zone 14 flaps (xoay bản lề), Zone 10 (leo thang) — sàn ĐỘNG không thể phủ
  tile tĩnh → chỉ strips.
- ⚠️ **CẦN LÀM:** (1) **SAVE PLACE** — 16K part + KeyboardASMRClient v5 + 9 script inline patch +
  ASMRZoneBuilder chưa vào .rbxlx (Rojo không quản Workspace). (2) Nghe thực tế bộ click mới +
  volume pháo hoa bằng tai (bot không nghe được). (3) Zone11 nhịp sóng sập hiện dày (pre-existing,
  wave 5.22s chồng nhau — section chỉ "nổi" ~0.7s/chu kỳ) — cân nhắc chỉnh WAVE_INTERVAL nếu khó chơi.

### 2026-07-13 (Session 12) — Bỏ auto-award Finish + bỏ gate chặn + Meteor Server Boost + Lighting Simulator
**Model:** Claude Fable 5 · MCP Studio KHÔNG kết nối được trong session (proxy không expose tool) —
mọi thay đổi thuần code qua Rojo, **CHƯA playtest verify trong Studio**.

- **Task 1 — Vạch Finish KHÔNG tự trao Wins (StageCheckpointService):** xóa `onStageFinishTouched`
  + bỏ hook Touched trên mọi Stage{N}Finish + xóa bảng `zonesWithWinPad`/`finishCooldowns`.
  Nhận Wins/x2/Skip CHỈ qua 3 pad cuối zone (setupSpecialPads GIỮ NGUYÊN, kể cả anti-cheat
  isFinishSequenceValid). Part Finish vẫn giữ làm mốc tính minStageTime.
  ⚠️ **HỆ QUẢ:** hiện chỉ Zone 1 & 2 có pad trong Workspace — zone 3–15 vượt xong KHÔNG có
  cách nhận Wins (chỉ được ghi nhận vượt màn im lặng khi chạm Start zone kế). **Phải đặt bộ
  3 pad (WinCollectionPad/DoubleWinCollectionPad/SkipStagePad) vào Mechanics của CẢ 15 zone.**
- **Task 2 — Gỡ hẳn cơ chế gate chặn minLv/minWS:** xóa dead code `getStageGateFailure` +
  `rejectStageGate` + `gateCooldowns` (teleport gate đã gỡ từ Session 3 — trong src không còn
  chỗ nào chặn). `Stages.STAGE_GATES` GIỮ LẠI thuần dữ liệu GỢI Ý cho biển "Recommend: Lv X".
- **Task 3 — Meteor Server Boost: ĐÃ XÓA HOÀN TOÀN (user quyết định sau 2 vòng thử).**
  Lịch sử: v1 đá procedural rơi 1.2s → v2 clone model `Meteorite` rơi 3.6s + crater +
  SurfaceGui không background tại vị trí cố định (1, 8.5, -105) → user bỏ ý tưởng thiên
  thạch. Đã gỡ: `MeteorBoostController.luau` (xóa file), packet `meteorState`, toàn bộ
  code meteor trong ServerBoostService (lastMeteor/sendMeteorState). Không còn reference.
- **Task 3 THAY THẾ — Boost Glory (tôn vinh người mua hoành tráng, kích thích mua):**
  packet `boostCelebration` thêm field `userId` (float64) để client tìm character người mua.
  `Effects/BoostGloryController.luau` MỚI (client-side, listener THỨ HAI trên
  boostCelebration — ByteNet 0.6 hỗ trợ nhiều listener, đã verify source): sân khấu 3D
  ~8s quanh NGƯỜI MUA, bám theo realtime khi chạy (heartbeat follow): (1) cột sáng neon
  cao 380 studs từ trời rọi xuống, thở + xoay, màu theo kind (speed cyan/wins gold/mega
  magenta); (2) 2 vòng hào quang neon dưới chân xoay ngược chiều; (3) billboard vương miện
  "👑 {tên}" + "⚡ {boost} ⚡" AlwaysOnTop MaxDistance 400; (4) 12 quả pháo hoa vút lên
  quanh người trong 5s đầu, nổ bung chùm sparkle 6 màu (Acceleration -24 rơi cong như
  pháo hoa thật) + flash + pop sound pitch ngẫu nhiên; (5) suối hạt sao vàng bay lên.
  Kết màn fade 0.7s tự dọn; mua chồng → hủy màn cũ chạy màn mới (token). Buyer rời
  server/chết → hiệu ứng đứng tại vị trí cuối. UI 2D (BoostCelebration) nâng cấp:
  `goldenFlash` chớp vàng toàn màn hình 0.5s + `fireCannons` 48 mảnh confetti bắn CHÉO
  từ 2 góc dưới lên rồi rơi lả tả (kiểu lễ trao giải), giữ nguyên banner + confetti rơi
  + chat neon. Test: `TestBoost = "speed"` trên Player.
- **Task 4 — LightingService.luau MỚI (Core):** nắng chiều 2h (ClockTime 14.3, latitude 30,
  ColorShift vàng ấm), bóng xám-xanh pastel sáng (OutdoorAmbient 136/150/178, ShadowSoftness
  0.24), ColorCorrection saturation +0.2, Bloom threshold 1.75 (chỉ Neon glow), Atmosphere
  xanh pastel (density 0.3) + SunRays. KHÔNG đụng Sky → decal bầu trời giữ nguyên; effect
  tạo idempotent (nhận effect sẵn có theo class). ⚠️ `Lighting.Technology` không set được
  runtime — muốn glow max thì chỉnh tay Studio → Future.
- Dọn import không dùng (CollectionService/TweenService trong StageCheckpointService).
  Selene: 0 errors trên toàn src.
- ⚠️ **CẦN LÀM:** (1) đặt 3 pad cho zone 3–15 (xem hệ quả Task 1); (2) playtest verify
  4 thay đổi khi Studio mở lại (meteor qua TestBoost, lighting nhìn thực tế, pad flow);
  (3) cân nhắc chỉnh Lighting.Technology = Future trong Studio.

### 2026-07-13 (Session 11) — Regional pricing + hướng teleport + pad hệ thống + biển 15 zone
**Model:** Claude Opus 4.8 · Test PASS trong Studio playtest: console sạch, giá billboard đúng
Dashboard, 15/15 stage quay mặt đúng hướng, hết warn "Missing Stage14/15Finish".

- **Regional pricing (`Shared/Util/RobuxPrice.luau` MỚI + `CoreLoop/PriceTagController.luau` MỚI):**
  billboard Treadmill/AuraBase/TrailBase KHÔNG còn hardcode số Robux. Giá đọc runtime từ
  `MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.GamePass).PriceInRobux` **gọi phía
  client** → đúng giá theo vùng của từng người xem, luôn khớp con số trong prompt thanh toán.
  Glyph Robux = `utf8.char(0xE002)` (""). Giá cũ trên biển SAI hoàn toàn (29/99/249/499)
  so với Dashboard (99/249/699/1299) — giờ tự đồng bộ. Treadmill free → "FREE";
  pass chưa tạo (id=0) → "SOON".
- **⚠️ BÀI HỌC LỚN — `Workspace.StreamingEnabled = true`:** quét `Workspace:GetDescendants()`
  MỘT LẦN lúc client Start là VÔ DỤNG — Lobby chưa replicate xong nên tìm thấy 0 billboard
  (fail IM LẶNG, không lỗi console). Model còn stream out/in nhiều lần trong phiên, mỗi lần
  vào lại là instance MỚI mang text hardcode cũ. → PriceTagController phải bám
  `Workspace.DescendantAdded` và sơn lại giá mỗi lần billboard xuất hiện.
- **Hướng teleport/hồi sinh (`Shared/Util/StageFacing.luau` MỚI):** KHÔNG xoay 180° cứng được.
  Zone 1–9 chạy dọc **+Z**, zone 9–15 chạy dọc **+X**; riêng Transition10To11 / 13To14 / 14To15
  còn lệch 90° so với hàng xóm → xoay 180° cho ra hướng NGANG hành lang. Giờ suy hướng từ
  HÌNH HỌC: nhìn từ điểm đáp về Stage{N}Start, nếu đáp ngay tại Start (hồi sinh) thì nhìn
  Start → Stage{N}Finish. Áp cho cả TeleportService, revive, và Skip pad. Lobby/Training giữ
  hành vi cũ. Đo được: 15/15 stage đúng hướng.
- **Hệ thống 3 pad (StageCheckpointService):** pad nằm TRÊN part Transition cuối mỗi zone
  (sau vạch Finish). `WinCollectionPad` → nhận Wins, về Lobby. `DoubleWinCollectionPad` → Robux,
  x2 Wins, về Lobby. `SkipStagePad` → Robux, **bỏ qua stage KẾ TIẾP (N+1)**, đáp GIỮA part
  `Transition{N+1}To{N+2}` (trước đây chỉ dịch tới Stage{N+1}Start = trả tiền gần như không
  được gì). Pad quét cho CẢ 15 zone (trước hardcode 1 & 2); zone nào có WinCollectionPad thì
  Finish không tự trao thưởng nữa (trước hardcode `stage >= 3`). Thêm chống gian lận:
  DoubleWin pad giờ cũng phải qua `isFinishSequenceValid` (trước bỏ trống → mở prompt lấy x2
  Wins mà không cần vượt màn); Skip pad phải `ActiveStage == stage`.
  Hiện chỉ Zone 1 & 2 có pad trong Workspace.
- **Bỏ thông báo "Stage N completed! (Bypassed wins)"** — vẫn ghi nhận vượt màn, chỉ im lặng.
- **Aura Robux-only (task 5):** 3 aura RedHeart/Flame/Dark → `robuxOnly = true`. Server
  (ProgressionService) TỪ CHỐI bán bằng Wins kể cả khi client gửi packet giả — đường mở khoá
  DUY NHẤT là gamepass qua GamepassService. UI: ẩn hẳn nút Wins, nút Robux chiếm trọn ô.
  3 trail premium vẫn mua được bằng Wins HOẶC Robux (user chưa yêu cầu đổi).
- **Sở hữu cosmetic bằng gamepass (task 6):** `GamepassService` sync ownership lúc profile load
  + `PromptGamePassPurchaseFinished` → mở khoá + TRANG BỊ ngay + celebration.
  `ProgressionService.UnlockCosmetic()` MỚI.
- **Biển Stage 15 zone (task 4):** clone y hệt `Stage1SignPart` (part vô hình 35×19.44×0.5 +
  Beam cyan 72 rộng + 2 SurfaceGui Front/Back, FredokaOne, xanh lá) cho zone 2→15, chỉ đổi
  icon + chữ `{icon} Stage N\n(Recommend: Lv X)`. Trước đó zone 7 (35×35×1), zone 9 (biển đặc
  2×12×22) sai cấu trúc, zone 10–15 KHÔNG CÓ biển. Biển đặt tại Stage{N}Start, quay mặt NGƯỢC
  hướng đi (nhìn thẳng vào người chạy tới) — zone 10–15 tự xoay 90° theo hành lang +X.
- **FIX bug đặt tên Workspace:** `Zone14.Mechanics.Stage13Finish` → `Stage14Finish`;
  `Zone15.ExitBridge.Stage13Finish` → `Stage15Finish`. Trước đó console warn "Missing
  Stage14Finish/Stage15Finish" mỗi lần chạy và **Stage 14/15 KHÔNG trao Wins**.
  Zone10 có 2 part cùng tên `Stage10Finish` → giữ nguyên, service giờ hook MỌI part trùng tên
  (trước chỉ lấy part đầu → nửa vạch đích kia là vạch chết).
**Phần 2 (cùng ngày) — camera facing + spawn + fix lỗi console (test PASS):**
- **Camera quay theo hướng teleport:** packet `snapCamera {lookX, lookZ}` (GamePackets) +
  `CoreLoop/CameraFaceController.luau` MỚI — camera là CỦA CLIENT, server xoay character
  chưa đủ. Server gửi packet sau MỌI teleport (TeleportService.teleportPlayer +
  StageCheckpointService.placePlayer = revive/skip/lobby); client chờ 2 Heartbeat
  (đợi CFrame mới replicate) rồi snap camera ra sau lưng nhìn xuôi. Đo được: spawn/S11/lobby
  camera đều đúng hướng.
- **SpawnLocation bị NGƯỢC từ đầu:** look = −Z trong khi Zone 1 ở +Z (dot = −1) → respawn
  luôn quay lưng vào map. Đã xoay part 180° trong Edit mode (respawn tự nhiên + camera lúc
  spawn tự đúng theo). Teleport về lobby giờ dùng `StageFacing.Orient(pos, 1, ...)` — quay
  về cổng Zone 1, độc lập với orientation của part.
- **Giá fallback thay "SOON":** billboard + nút Robux trong CosmeticModal hiện GIÁ CONFIG
  (299/499/799, 399/599/899) khi gamepassId = 0; điền ID thật là tự chuyển sang giá live
  theo vùng. Text TĨNH của billboard treadmill trong .rbxlx cũng đã sửa (29/99/249/499 cũ →
  99 /249 /699 /1299  + FREE, cả bản trong Zone1/Zone2).
- **FIX lỗi console:** (1) `Zone15ObbyScript` treo vĩnh viễn tại `WaitForChild("Rings")`
  (folder bị xóa từ obby v5) → geyser/hiệu ứng KHÔNG chạy; tạo folder `Rings` rỗng →
  script chạy lại ("Obby v2 — 0 rings + lava geysers"). (2) BGM asset 1837879003 không phải
  Sound → gỡ khỏi PLAYLIST trong BgmController.
- ⚠️ Còn tồn tại (không phải lỗi mình tạo): script lạ "Complete Smooth Aura System + DataStore
  + VIP" (VIP ID placeholder 1234567) trong ServerScriptService — hệ aura/DataStore RIÊNG từ
  free model, chạy song song với hệ cosmetic thật. Nên xem xét XÓA để tránh xung đột.
  Fusion warning destructorNeededComputed (4×) là pre-existing.
- ⚠️ **CẦN LÀM:** (1) **Save place** (biển 15 zone + rename part + SpawnLocation xoay +
  folder Rings + text billboard tĩnh chưa vào .rbxlx).
  (2) Tạo 6 gamepass trên Dashboard (Dark 299 / Flame 499 / RedHeart 799 / Mystic Violet 399 /
  Golden Ray 599 / Crimson Fury 899) rồi điền ID vào `Config/Economy/Gamepass.luau` —
  hiện billboard hiện "SOON" và nút mua báo "Coming soon!".

### 2026-07-12 (Session 10) — Tái cấu trúc Workspace + LobbyHills/Cliffs Modern Retro + Lava mọi zone
**Model:** Claude Fable 5 · Đã test PASS: console sạch, lava kill dummy 0.29s, GlobalKillFloor touched OK.
- **Tái cấu trúc Workspace (chức năng giữ nguyên):** top-level giờ chỉ còn `Zones` (Zone1–15),
  `Lobby` (Baseplate, Spawn, LobbyHills, Treadmills, MultiplierPads, BasePads, LeaderBoard,
  GroupChest, TrailBase, AuraBase, `Displays/` 4 kệ trưng bày aura/trail, `ASMR/` ASMR_Test+KeyBoard,
  `Misc/`), `GlobalKillZone`. Arrow tháp Zone10 → `Zones.Zone10.Decor`. VirtualVogue pack →
  `ReplicatedStorage.AssetPacks`. "Water Blocks" rỗng đã xóa.
- **Update references đồng bộ:** Teleport.luau (targetPath → Workspace.Zones.*, SpawnLocation →
  Lobby.Spawn, Treadmill_x1 → Lobby.Treadmills), StageCheckpointService (template path + zonesFolder),
  LeaderboardService/MultiplierPadService/GroupChestService/CosmeticVisualController/
  Zone12WindTunnelController → `FindFirstChild(name, true)` đệ quy (chống gãy khi re-org sau này),
  MultiplierPadVisualController bootstrap poll đệ quy, Zone13SpringFlingController chờ Zones.
  7 inline script trong Workspace (Zone2/4/5/11×2/12/13) đổi sang `script.Parent` — zone giờ
  tự chứa, move đâu cũng chạy. RigAnimateService (ServerScriptService, ngoài Rojo) patch recursive.
- **LobbyHills v7 Modern Retro (268 parts):** vòng đồi 2 lớp ĐAN KHÍT overlap 38% + 4 tháp góc
  (hết hở góc), palette pastel sunset 8 màu SmoothPlastic (user sẽ tự gắn texture), sọc band cream,
  2 mặt trời retro layered (ĐB + TN), 8 cụm mây, cột sọc 2 bên 4 cửa, 7 palm low-poly (creator
  store 18363394399, đã vet sạch script). GIỮ nguyên 7 tường vô hình + 4 cửa mở cũ.
  Cấu trúc mới: `LobbyHills/InvisibleWalls|Hills|Decor`.
- **ThemeCliffs Modern Retro 13 zone (~1900 parts thay 1052):** vách xếp 3 tầng thu dần
  (terraced) + dome cap 55% + band cream 30% + accent stripe dọc mỗi 3 segment (Neon cho zone
  tech/volcano/night/cyber). Mỗi zone giữ hue theme riêng (Z1 mint, Z2 teal, Z3 sand, Z4 forest,
  Z5 ice, Z6 desert, Z7 volcanic, Z8 slate, Z9 tropic, Z11 night indigo+neon hồng, Z12 sky,
  Z13 cyber ice+magenta, Z15 volcano). SideWall vô hình GIỮ nguyên. Zone14 canyon cam giữ nguyên
  (user duyệt từ 9e). Đã boost saturation 8 zone màu nhạt vì lighting rửa màu.
- **Lava KillFloor TỪNG zone:** 12 lava mới (Z1,2,4–13) — plane Neon cam dày 14 studs
  (chống tunnel) + crust đỏ sậm + ember particle, đặt dưới đáy ground 10 studs (zone thấp)
  / Y190 (Z11–13 trên cao) / Y-26 (Z10). Zone3 KillFloor cũ restyle lava (giữ logic),
  Zone14/15 lava sẵn giữ nguyên. Kill: `Workspace.Zones.ZoneLavaKillScript` (1 script chung,
  hook mọi part tên `LavaKillFloor` + DescendantAdded; ref `tools/zone_lava_inline.luau`).
- **FIX bug sẵn có:** `GlobalKillZone.KillFloor` plane Y-280 bị THIẾU từ trước (infinite yield
  mỗi lần chạy) → tạo lại 4400×3800 dày 12. RigAnimateService hết lỗi "Không tìm thấy AuraBase".
- **Split cliff trái/phải + giãn (theo feedback):** mỗi `ThemeCliffs` (13 zone corridor +
  Zone14 "Cliffs") tách thành `CliffLeft` + `CliffRight` (theo hướng đi tiến: Z-corridor
  right=+X, X-corridor right=+Z), đẩy vách nhìn thấy ra ngoài **28 studs** để nhìn thoáng
  (lava cam giờ lộ ở khe → đẹp). SideWall vô hình GIỮ nguyên vị trí (gameplay width không đổi).
  Idempotent qua attribute `CliffSpreadApplied`. Zone4 (arena boss vòng núi Mount*) & Zone10
  (tháp) không split — không phải corridor 2 bên.
- ⚠️ **CẦN LÀM: Save place** (toàn bộ geometry + inline script edits chưa vào .rbxlx).

### 2026-07-11 (Session 9f) — Obby v5 theo feedback: 6 đảo to so le, bỏ ramp, geyser mạnh hơn, LobbyHills ôm Baseplate
**Model:** Claude Fable 5 · Đã test: geyser giết player đứng yên sau 2s, ramp đã xóa, finish/gate mới đúng kích thước.
- **Zone 15 Obby v5:** 6 đảo trụ **34×34** (to hơn, chống trượt mép) SO LE đơn chuỗi
  (X 3294→3664 cách 74, Z xen kẽ 3004/3054 → khoảng nhảy chéo 89.4 = quãng bay WS 234
  lên +6), top 226→256. **BỎ VictoryRamp** — finale: lao khỏi đảo cuối bay xuyên vạch đích
  trên không. `Stage15Finish` nâng thành màn neon Y 220–270 (size 14×50×72);
  `World2Gate` nâng Y 218–290 làm tường hậu (bay lố → bật xuống cầu, có GlobalKillFloor đỡ).
- **Geyser mạnh hơn:** interval 0.5–0.9s (cũ 0.7–1.2), cột 10×130 (cũ 7×122), vẫn 30%
  nhắm player + chỉ bắn đầy đủ khi có người trong vùng.
- **LobbyHills v6 (chốt) — ôm SÁT mép Baseplate, liền khít:** 4 dãy đồi ngay mép plate
  (X -116/122, Z -137/108), đồi TO (26-36 rộng, cao 15-23) và NHỎ (12-18 rộng, cao 6-11)
  ĐAN XEN liền khít + lớp đồi sau cao hơn (20-32) lệch ra ngoài 21 studs lấp silhouette.
  KHÔNG có cổng (user bỏ candy gate của v4). Decor: kẹo mút, chỏm kem, hoa neon, 6 mây
  pastel. **4 cửa mở** (không trang trí): Zone 1 (bắc X -50..48), Trail Pack (nam X 0..60),
  aura panel (đông Z -25..10), boardwalk ASMR (đông Z >58). 7 tường vô hình khớp cửa.
  119 parts. (Lịch sử: v3 vành to bao Trail Pack — chê xa plate; v4 có candy gates — bỏ;
  v5 hở khe — fix liền khít ở v6.)

### 2026-07-11 (Session 9e) — Obby v4 + Geyser + Cliffs toàn map + Global KillFloor
**Model:** Claude Fable 5 · **Component tests PASS; full chain verify bằng toán vật lý (bot không mô phỏng được jump client).**
- **Zone 15 Obby v4 (thêm 4+ obby):** P0 RunUp → **8 đảo trụ** dâng từ lava (2 làn Z
  2997/3061 × 4 cột X 3325/3415/3505/3595, top 226→244, +6/bậc) → VictoryRamp 17.7°
  xuống ExitBridge. **Toán nhảy:** WS 234 nhảy lên +6 bay đúng 89.4 studs = khoảng cột 90
  → nhảy từ giữa-tới-mép đảo đều đáp; WS <200 hụt → lava. Chọn làn để né geyser.
- **Geyser dung nham (cơ chế mới):** mỗi 0.7–1.2s bắn 1 tia từ KillFloor lava (Y143):
  telegraph 0.55s cột mờ vàng + bọt sủi → phụt cột neon cao 122 (xuyên tầm bay) 0.5s,
  chạm chết, 30% NHẮM player trong vùng. Test: giết player đứng yên sau 11s.
- **Cliffs + SideWall TOÀN MAP theo theme riêng (1052 parts):** Z1 đồng cỏ (cây pastel),
  Z2 tech lab (neon strip), Z3 mỏ đá, Z4 rừng boss, Z5 băng (pha lê), Z6 sa mạc (xương rồng),
  Z7 núi lửa (vệt ember), Z8 công nghiệp (vàng hazard), Z9 biển nhiệt đới (cây cọ),
  Z11 thành phố đêm (cao ốc + cửa sổ sáng), Z12 bầu trời (mây), Z13 băng cyber (pha lê cyan),
  Z15 sườn núi lửa (không sidewall — vực là gameplay). Mỗi zone kèm SideWall vô hình cao 70.
  Builder trong `Boundaries.ThemeCliffs` mỗi zone (xóa/regen dễ). Zone14 giữ canyon cũ, Zone10 tháp bỏ qua.
- **Lobby "Candy Park" (99 parts):** đồi pastel + chỏm tròn quanh viền X[-120..758] Z[-95..140],
  chừa cửa Zone1 (X -60..60), 5 tường vô hình `Workspace.LobbyHills`.
- **Global KillFloor:** `Workspace.GlobalKillZone` — plane 4400×3800 tại Y **-280** (dưới cả
  tháp Zone10 Y-239) + `GlobalKillScript` inline. Test: rơi hư không chết sau 1.5s.
- Lưu ý test: bot KHÔNG thể mô phỏng cú nhảy client chuẩn (server Jump/velocity đều bị
  client override; constraint-jump sai số vy làm lệch quãng bay) — full chain obby cần
  user tự chạy tay trong Studio để cảm nhận nhịp.

### 2026-07-11 (Session 9d) — Zone 15 v5: MOMENTUM JUMP OBBY
**Model:** Claude Fable 5 · **Đã test PASS full flow (A: 234 vượt 3 gap +220K wins; B: 150 rơi lava).**
User yêu cầu xóa Mega Launchpad, thay bằng obby đơn giản: nhảy dựa vào WalkSpeed.
- **Layout (giữ nguyên mọi part user đặt):** P0_RunUp X 3187–3265 (rộng 72, chevron neon)
  → gap 85 → P1_Island 3350–3420 (rộng 44) → gap 95 → P2_Island 3515–3580 → gap 102 →
  đáp ExitBridge 3682 → Stage15Finish 3700. Nhảy từ mép ở WS 234 bay ~119 studs; gap cuối
  102 cần gần đúng chuẩn 234. Biển lava KillFloor Y=140 giữ từ launchpad (ember + light).
- **Hiệu ứng:** viền neon cyan/magenta quanh mép platform "thở" theo sóng chạy dọc X;
  vạch NHẢY vàng ở mép đông + vạch ĐÁP xanh (sparkle emitter) ở mép tây mỗi platform;
  3 vòng neon bay lơ lửng giữa gap (xoay quanh trục bay + bob + pulse) — bay XUYÊN vòng
  → flash trắng + nổ 36 particle (juice thưởng đường bay đẹp); biển "MOMENTUM JUMPS /
  MAX SPEED + JUMP AT YELLOW LINE".
- **BÀI HỌC MỚI (đã ghi memory):** (3) `humanoid.Jump = true` từ server VÔ DỤNG với
  character client-owned (giống AssemblyLinearVelocity) — bot test phải mô phỏng nhảy bằng
  LinearVelocity constraint 2 pha. (4) **Part mỏng 4 studs bị TUNNEL Touched ở 234 studs/s**
  (đi chậm ăn, chạy nhanh trượt) → vạch finish Stage14/15 dày lên 14 studs. (5) Bot MoveTo
  không có input client → Active Braking client ghìm tốc dao động 210–243, đừng tin số đo
  tốc độ của bot; người thật giữ W không bị.
- Xóa: Runway/RampWedge/RampTop/LaunchPad/LandingPad/Zone15LaunchScript;
  `tools/zone15_launchpad_inline.luau` → `tools/zone15_obby_inline.luau`.
  Teleport S15 mô tả → "Momentum Jumps".

### 2026-07-11 (Session 9c) — Zone 15 v4: THE MEGA LAUNCHPAD (Cú Bay Finale)
**Model:** Claude Fable 5 · **Đã test PASS full flow trong Studio playtest.**
User yêu cầu XÓA mê cung + Stalker, thay bằng đường chạy + dốc phóng tối giản.
- **Layout:** Runway X 3187–3320 (chevron neon tăng tốc + lan can trim cyan/magenta) →
  RampWedge 3320–3356 (cao 20) → RampTop + LaunchPad neon (Y đỉnh 240) → vực lava
  KillFloor Y=140 (neon + ember + light) → LandingPad X 3635–3685 (tâm 3660, vòng neon
  xanh) → Stage15Finish X 3700 → ExitBridge → cổng World 2. Biển "MEGA LAUNCHPAD /
  SPEED 234+ TO FLY" ở đầu runway.
- **Speed check tại LaunchPad:** WalkSpeed (server-side) >= 234 → bay vòng cung apex Y~291,
  đáp ~X 3682, chạy tới finish (+220K wins đo được = (150K+50K first-clear)×1.1 group).
  < 234 → hích nhẹ (70,30,0) + popup "TOO SLOW! x/234" → rơi lava X~3400.
- **2 BÀI HỌC KỸ THUẬT QUAN TRỌNG:**
  (1) **Server set AssemblyLinearVelocity trên character VÔ DỤNG** — client sở hữu physics,
  ghi đè ngay lập tức (đã chứng minh: vy=100 bị nuốt, bay phẳng). PHẢI dùng LinearVelocity
  CONSTRAINT (replicate → client tự mô phỏng): pha 1 (0.22s) đủ trục (245,90,0) vọt lên,
  pha 2 (1.3s) giữ riêng trục X=172 thả Y cho trọng lực. + ChangeState(Freefall).
  (2) **Part chìm TRONG sàn (đỉnh phẳng mặt sàn) KHÔNG fire Touched** khi chạy ngang qua —
  Stage14Finish/Stage15Finish phải NÂNG thành finish line nổi Y 220–238 (neon trong suốt).
- Xóa: Maze folder, GlitchStalker, Zone15MazeScript, EntrancePortal;
  `tools/zone15_maze_inline.luau` → thay bằng `tools/zone15_launchpad_inline.luau`.
  Teleport S15 mô tả "Mega Launchpad". WedgePart lưu ý: orientation Y+90 (không phải -90)
  để dốc lên về +X.

### 2026-07-10 (Session 9b) — Zone 14 & 15 v3: polish theo feedback + tôn trọng chỉnh tay của user
**Model:** Claude Fable 5 · **Đã test PASS trong Studio playtest.**
Feedback user sau v2: (1) Zone14 lằn đỏ nhấp nháy xấu, (2) mê cung quá nhỏ/dễ, (3) enforce
218/234 WS, (4) GIỮ NGUYÊN các part Transition/Start/Finish user đã chỉnh tay, (5) Stalker
thông minh hơn nhưng công bằng.
- **Tôn trọng chỉnh tay (user chốt "sửa tên giữ vị trí"):** part user đặt ở X 3160 (tên nhầm
  Stage14Start) → RENAME thành `Stage14Finish` rồi dời nhẹ về X 3150 (tránh race cùng frame
  với Stage15Start @3160 làm mất Wins); tạo `Stage14Start` MỚI X 2481 (kiêm lấp khe hở sàn);
  rename `Zone15.Ground.Transition13To14` (user đặt nhầm tên) → `Transition14To15` (fix teleport
  Stage 15); `Stage15Start` bật CanCollide (nó là miếng sàn duy nhất X 3158–3162); EndFloor
  kéo dài 3064–3108 vá khe.
- **Zone 14 fix "lằn đỏ":** nguyên nhân = khe hở 0.4 stud giữa các flap lộ lava + z-fight với
  StartFloor → flap nới 26.6→26.96, hạ top 220→219.95; cảnh báo đổi từ nhấp nháy nhị phân
  sang PULSE mượt (sine lerp base→cam, mạnh dần khi sắp mở). Script v2 đọc hinge Y từ part.
- **Zone 15 mê cung TO GẤP ĐÔI + khó hơn:** 15×12 ô (Z 2831–3227, sâu 396) thay 15×6;
  seed 51, CHỈ 3 lối phụ (v1 có 10); 202 tường + 67 đèn neon; lối giải đo được ~963 studs
  (gấp 2 đường thẳng). X giữ 3187–3682 khớp StartStrip/ExitBridge user đã dời.
- **Glitch Stalker AI v2 (state machine):** patrol (60, lượn ô ngẫu nhiên) → **alert 0.8s**
  (khóa mục tiêu, mắt cam, đèn nháy dồn — đứng yên) → **hunt 225 studs/s** (> 218, < 234 minWS
  gate → enforce tốc độ chuẩn mới thoát; nhắm VỊ TRÍ DỰ ĐOÁN pos+vel×0.35s, repath 0.25s) →
  **overheat 1.6s** sau mỗi 5.5s săn hoặc sau khi giết (co giật xám, đèn chập chờn — cửa sổ
  thoát thân). Test: giết player WS 60 sau 5.4s; path solve ~963 studs OK; console sạch.
- Zone 14 enforce 218 sẵn có: sóng mở sàn = đúng 218 studs/s.

### 2026-07-10 (Session 9) — Zone 14 & 15 v2: Floor Opens Canyon + Glitch Maze
**Model:** Claude Fable 5
**Bối cảnh:** bản v1 (Shutter Gauntlet + Glitch Storm chase) bị user chê khó chơi/không vừa ý
→ ĐẬP BỎ, làm lại theo ảnh tham chiếu user gửi. **Đã test PASS trong Studio playtest.**
- **Zone 14 "Floor Opens Canyon" (X 2479–3100):** theme canyon voxel cam (135 part vách
  2 tầng + 17 cây) như ảnh mẫu. Sàn = 20 đoạn trapdoor 2 cánh (40 flap, bản lề mép ngoài,
  xoay 100° xuống); mỗi chu kỳ 5.8s một "sóng mở" chạy dọc +X đúng **218 studs/s = minWS
  gate**: sàn mở NGAY SAU LƯNG người chạy đủ tốc — chậm hơn là cánh mở dưới chân → rơi
  xuống **biển lava** (neon + ember particle + PointLight, kill 0.5s). Cánh nhấp đỏ 0.35s
  trước khi mở. Đèn **GO/WAIT** ở vạch xuất phát (xanh = an toàn chạy, đỏ 1.6s đầu sóng).
  Biển gỗ "⚠ CAUTION Floor Opens" + "Recommended Level: 104" + billboard "Stage 14".
  Script inline `Zone14FloorScript` (ref `tools/zone14_floor_inline.luau`).
- **Zone 15 "Glitch Maze" (X 3125–3720):** mê cung cyber 15×6 ô (33 studs/ô, sinh bằng
  recursive backtracker seed 15 + 10 lỗ đục thêm cho nhiều lối), ~105 tường Metal tối +
  dải neon magenta/cyan xen kẽ trên đỉnh. **NPC "Glitch Stalker"** (cầu glass đen + vòng
  neon xoay đổi màu + mắt đỏ nhìn theo hướng bay + particle trail + PointLight thở + hum
  sound): PathfindingService đuổi player gần nhất trong mê cung @145 studs/s, repath 0.35s,
  chạm bán kính 7 = chết; không có mồi → về home tuần tra. Cổng vào neon "GLITCH MAZE — IT
  HUNTS YOU" + billboard "Stage 15"; sau mê cung là cầu + arch vàng + Stage15Finish (X 3700)
  + cổng World 2. Script inline `Zone15MazeScript` (ref `tools/zone15_maze_inline.luau`).
  Test: Stalker săn xuyên mê cung giết sau 7.5s (minDist 0.8), tự về home sau khi player chết.
- **Sync Wins theo GDD (user chốt):** `Stages.luau` STAGE_WINS = bảng GDD §3.B
  (S14 50K, S15 150K, sửa cả 3–8/11–13). `Teleport.luau` mô tả "Floor Opens Canyon"/"Glitch
  Maze" (giá vẫn 0 = test mode). AntiCheat KHÔNG cần allowance mới (đã thêm [15]=120 cho
  boost rail v1 rồi gỡ khi bỏ thiết kế đó).
- **Kỹ thuật đáng nhớ:** (1) teleport thô qua execute_luau bị AntiCheat giật về — lách bằng
  `player:LoadCharacter()` + set CFrame trong TELEPORT_GRACE 1.5s; poll `player.Character`
  thay vì `CharacterAdded:Wait()` (event có thể đã bắn → treo). (2) Player teleport đến
  đứng yên KHÔNG fire Touched (physics ngủ) — test hazard sàn bằng Humanoid:MoveTo.
  (3) PathfindingService trả NoPath transient ~10s đầu sau khi start play (navmesh đang
  build cho geometry mới) — retry là hết, script repath 0.35s tự phục hồi.
  (4) SurfaceGui mặc định LightInfluence=1 → chữ đen thui trong bóng; set LightInfluence=0.
- ⚠️ **CẦN LÀM:** Save place (geometry + inline scripts chưa vào .rbxlx). Lỗi console có sẵn
  không liên quan: sound `1837879003` sai asset type.


### 2026-07-06 (Session 8) — Fix treadmill chập chờn + Studio pass testing + rebirth celebration
**Model:** Claude Fable 5
**Làm được (đã test PASS trong Studio playtest):**
- **FIX treadmill "lúc chạy lúc không" (root cause):** client chỉ gửi packet khi ĐỔI trạng thái,
  nhưng server rate-limit 0.1s drop packet lặng lẽ + vòng revalidate 1s tắt farm → hai bên lệch
  trạng thái VĨNH VIỄN. Fix: `TreadmillClientController` gửi keepalive "on" mỗi 0.6s khi đang đứng
  trên treadmill → server tự đồng bộ lại trong ≤0.6s. Test: đi bộ lên Treadmill_x1, farm +22/8s
  liên tục không đứt.
- **Treadmill multiplier CHỈ khi đứng trên máy:** `getTreadmillMultiplier` bỏ hẳn buff vĩnh viễn
  theo EquippedTreadmill — `isOnTreadmill == false` → x1. Rời máy là mất buff.
- **Studio test = passes CHƯA sở hữu:** `GamepassService.OwnsPass(player, passId)` là nguồn sự thật
  duy nhất — Studio luôn trả false TRỪ pass mua trong session (sessionOwned). ProgressionService
  compute multiplier dùng OwnsPass. Studio còn RESET UnlockedTreadmills về wood mỗi lần join để
  test luồng mua sạch. Test: Premium x1.0 (Pass x1 + VIP x1 + Treadmill x1), promo "2x Speed" hiện lại.
- **VIP tag:** GamepassService set attribute `IsVIP` (load + sau khi mua). `ChatTagController`:
  [VIP] vàng ƯU TIÊN đè [Fan] xanh (group member).
- **Speed Pass UI:** BỎ section khỏi Shop — chỉ còn promo banner RightPanel (vị trí cũ, động theo
  tier chưa own, 3 màu). Shop giờ mở đầu bằng SERVER BOOSTS.
- **Rebirth celebration:** `celebrateRebirth` trong ProgressionService (cả requestRebirth lẫn
  ForceRebirth/Skip Rebirth) → packet purchaseCelebration (thêm field `subtitle`) → banner
  "⭐ REBIRTH #N!" + confetti + sound. Dùng chung hạ tầng BoostCelebration.TriggerPurchase(name, subtitle).
- **Wheel button:** thêm 2 label giống Playtime Boost — "Spin" + đếm ngược vé free ("FULL" khi đầy 3 vé).

### 2026-07-06 (Session 7) — Speed Pass system + Treadmill purchase fix + Shop Boosts + UI reposition
**Model:** Claude Fable 5
**Làm được (đã test PASS trong Studio playtest):**
- **GamepassService (MỚI — Gameplay):** trung tâm xử lý gamepass in-game.
  (1) Speed pass x2/x4/x8 + VIP: `PromptGamePassPurchaseFinished` → `ProgressionService.RefreshGamepassCache`
  (MỚI — xoá cache session để multiplier áp dụng NGAY không cần rejoin) + packet `purchaseCelebration`
  (MỚI) → banner + confetti + sound cho riêng buyer (`BoostCelebration.TriggerPurchase`).
  (2) Treadmill passes: sync ownership lúc profile load → cấp `UnlockedTreadmills` + tự trang bị
  treadmill multiplier cao nhất (FIX lỗi "own pass nhưng treadmill vẫn khoá" — test: owner Red Admin
  pass vào game thấy ngay Treadmill x100, Total x107.5). Mua trong game → unlock + equip + celebration.
  (3) API `PromptTreadmillPurchase` — TreadmillService gọi khi chạm treadmill khoá (throttle 3s) →
  hiện prompt thanh toán ngay tại chỗ.
- **Treadmills.luau:** thêm field `gamepassId` + tên/giá khớp dashboard (Purple x3/Blue x9/Gold x25/Red Admin x100).
- **Shop:** thêm 2 section MỚI đầu danh sách — "SPEED GAMEPASS (x2·x4·x8)" 3 card 3 màu riêng
  (cam-vàng/tím/đỏ, `Theme.SPEED_PASS_TIERS`) và "SERVER BOOSTS" 3 dev products (teal/gold/magenta).
- **RightPanel promo:** nút "2x Speed ONLY 3" giờ ĐỘNG — hiện pass rẻ nhất CHƯA own (x2→x4→x8),
  màu gradient đổi theo tier, click prompt mua thật, own hết cả 3 → tự ẩn. Refresh sau khi mua.
- **Roulette button:** bỏ khỏi LeftMenu (về 6 nút), thành ICON-ONLY (icon wheel mới
  `rbxassetid://115585087379442`) đặt NGAY TRÊN Playtime Boost góc phải + badge đỏ số vé.
- **BoostHud:** chuyển từ top-center xuống GÓC DƯỚI PHẢI, xếp dọc (AnchorPoint 1,1, bám visible bounds).
- **Galaxy Trail redesign:** lõi trắng rực → xanh thiên hà → tím → magenta → rìa space tối,
  width 2.6, lifetime 1.6 + emitter bụi sao lấp lánh (parent vào attachA, tự dọn theo clearTrail).
- **Slide animation:** đổi `rbxassetid://80662638776599` (lỗi permission) → `115997630662112` — hết lỗi console.

**⚠️ Lưu ý:** giá speed pass trong Shop/promo hardcode theo dashboard hiện tại (3/9/27 R$ — giá test).
Khi đổi giá thật (GDD: 15/39/89) phải sửa `Theme.SPEED_PASS_TIERS` + catalog `speed`.

### 2026-07-06 (Session 6) — Server Boosts + Speed Roulette + cập nhật ID monetization
**Model:** Claude Fable 5
**Làm được (đã test PASS trong Studio playtest):**
- **Cập nhật toàn bộ ID thật từ Creator Dashboard:** `Economy/Gamepass.luau` (9 passes),
  `Economy/Products.luau` (MỚI — wins packs, server boosts, skip rebirth, spin packs),
  `Stages.luau` (Revive 3608405576 @19R$, Skip Stage 3608405926, Double Wins 3608406804,
  Skip Rebirth 3608406966), Theme.SHOP_CATALOG (purchaseId + giá đúng dashboard; đổi tên
  treadmill theo dashboard: Purple x3 / Blue x9 / Gold x25 / Red Admin x100). File `ID` đã sửa
  Auto-Rebirth 1899434608 (trước ghi nhầm trùng VIP), thêm Server x2 Wins 3608407843 + Skip Rebirth.
- **ServerBoostService (MỚI — Gameplay):** server boost x2 Speed/Wins/MEGA 10 phút, mua chồng
  cộng dồn thời gian; personal boost (từ Roulette) nhân tiếp ×2 (max ×4). Hook vào
  `ProgressionService.getMultiplierBreakdown` (serverMult) + `AwardWins` (chỉ reason stage/stage_x2).
  ProcessReceipt đăng ký trong ReceiptService. Test: chip đếm ngược hiện, Total x8.5→x17, stack 0:48→1:18.
- **RouletteService (MỚI — Gameplay):** vé `SpinTickets` (persist DataTemplate); free 15 phút/vé
  (cap 3, đầy thì dừng đếm), Daily ngày 7 +1 vé (DailyService gọi GrantTickets), spin packs
  1/19R$ · 5/79R$ · 10/149R$ (⚠️ CHƯA tạo product trên Dashboard — ID=0). 8 ô theo GDD
  (`Shared/Config/Roulette.luau`, xếp tăng dần giá trị); Extra Spin gamepass (⚠️ chưa tạo, ID=0)
  → quay 2 lần lấy slot index cao hơn. Ô 8 = Glitch Aura (thêm vào Auras.luau ×3.5 + visual
  glitch magenta/cyan trong CosmeticVisualController); đã sở hữu → đền 50K Wins.
- **ProductService (MỚI — Core):** ProcessReceipt cho 4 Wins Packs + Skip Rebirth
  (ProgressionService.ForceRebirth MỚI — rebirth không cần đủ level).
- **Client:** RouletteModal (bánh xe 8 ô quay Quint 4.2s dừng đúng ô server roll, tickets,
  timer vé free, 3 nút mua, nút Spin trong LeftMenu — menu giờ 7 nút cao 700), BoostHud
  (2 chip đếm ngược top-center, gộp server×personal), BoostCelebration (banner pop 4.5s +
  ~46 confetti rơi + sound + chat neon `[BOOST] Cảm ơn {tên}...` qua DisplaySystemMessage).
  Packets mới: boostState, boostCelebration, rouletteState, requestRouletteState, requestSpin, spinResult.
- **Fix quan trọng:** ByteNet race lúc player join trước khi channel tạo →
  ServerBoostService đợi DataService.IsLoaded mới gửi state đầu + pcall sendTo.

**Studio-only test hooks (không chạy production):**
- RouletteService: tự tặng 3 vé khi profile load (attribute `StudioSpinGranted`).
- ServerBoostService: set attribute `TestBoost` = "speed"/"wins"/"mega" trên Player → boost 60s.

**⚠️ CẦN LÀM để hoàn thiện monetization:**
- Tạo trên Dashboard: gamepass **Extra Spin (149 R$)** + 3 dev products **Spin Packs (19/79/149 R$)**
  → điền ID vào `Economy/Gamepass.luau` (ExtraSpin) và `Economy/Products.luau` (SPIN_PACKS).
- Treadmill gamepass: shop đã prompt đúng pass ID nhưng CHƯA có logic server cấp
  UnlockedTreadmills khi mua/own pass.
- Small Wins Pack không thấy trong ảnh dashboard (dùng ID 3608400621 từ file `ID`) — xác nhận giá 99R$.

### 2026-07-06 (Session 5) — Chuẩn bị release: Anti-Cheat + Tối ưu server 25 player
**Model:** Claude Fable 5
**Làm được (tất cả đã test PASS trong Studio):**
- **AntiCheatService (MỚI — `Core/AntiCheatService.luau` + config `shared/Config/AntiCheat.luau`):**
  theo dõi tọa độ X-Z mỗi 0.4s. Teleport >allowed×dt+50 studs → giật ngược NGAY; speed
  >WalkSpeed×1.75 (sàn 65, nới thêm theo stage 12/13 vì gió/lò xo hợp lệ) → strike, 3 strikes/8s
  → giật ngược; 3 lần giật ngược/30s → KILL respawn. Whitelist: `AntiCheatService.NoteTeleport(player)`
  được gọi ở MỌI teleport server (TeleportService, lobby/revive/skip trong StageCheckpointService,
  CharacterAdded). Test: tele-hack 500 studs bị giật về, speed-hack 500 studs/s bị kill sau ~4s.
- **Xác thực trình tự Stage (StageCheckpointService):** Finish/WinPad chỉ ăn khi ActiveStage==stage
  VÀ đã ở trong stage ≥ minStageTime (= dist(Start,Finish)/450 studs/s, sàn 1.5s; stamp qua
  GetAttributeChangedSignal("ActiveStage") nên cover cả teleport). WinPad thêm check khoảng cách 40 studs.
- **TreadmillService viết lại:** bỏ polling GetPartsInPart 0.03s ở server. Client
  (`CoreLoop/TreadmillClientController.luau` MỚI) tự check AABB mỗi 0.12s, gửi packet
  `treadmillContact {isOn}` (MỚI trong GamePackets) CHỈ khi đổi trạng thái; server validate khoảng
  cách tới hitbox (margin 6/10 studs) + revalidate 1s/lần chỉ trên người đang farm. **Lưu ý:**
  client scan hitbox phải WaitForChild (replication race — đã fix, model đến trước child Hitbox).
- **CollisionGroupService (MỚI — Core):** nhóm "Players" tự va chạm = false, gán mọi part nhân vật
  (kể cả DescendantAdded). Test: Players×Players collidable = false.
- **Trail/Aura client-side:** server bỏ hẳn tạo instance (xóa TRAIL_VISUALS khỏi ProgressionService);
  chỉ sync attribute `EquippedTrail`/`EquippedAura` trên Player (trong tick + khi equip).
  `Effects/CosmeticVisualController.luau` (MỚI) render Trail + Aura (5 aura visual MỚI: sparkle/fire/
  lightning/void/cosmic) cho MỌI player theo attribute. Test end-to-end mua+equip qua packet: PASS.
- **Active Braking (`Parkour/ParkourBrake.luau` MỚI, config `ParkourConfig.Braking`):** thả phím →
  LinearVelocity (X-Z, lực = mass×420) ghìm về 0, dưới 3 studs/s triệt tiêu hẳn; chỉ khi Grounded
  + không input → không phá fling/wind hợp lệ. Test: 200 studs/s → 0 tức thì.
- **Slide chống văng 4 lớp (ParkourSlide viết lại):** (1) lực constraint HỮU HẠN mass×900 thay vì
  inf — hết ủi xuyên khối vật lý; (2) Blockcast cỡ thân người (3.4×2.6×0.6) thay raycast tâm;
  (3) kẹp velocity Y ≤ 12 + diệt angular velocity mỗi frame; (4) phát hiện nghẽn (vận tốc thực
  < 45% lệnh sau 0.18s → dừng cứng, hardStop còn kẹp Y ≤ 0).
- **Fix animation trễ 1-2s lúc vào game:** ParkourAnimator giờ warm CẢ animation trong script
  Animate (run/walk/jump/idle...) chứ không chỉ anim parkour — PreloadAsync + LoadAnimation
  Play weight 0; chạy nền không chặn buildSession.

**Cần biết cho session sau:**
- ⚠️ Lỗi console có sẵn: asset animation `125733527624272` (Aura_Idle của RigAnimateService —
  script inline Workspace) KHÔNG có quyền — cần "Click to share access" hoặc thay asset trước release.
- Ngưỡng anti-cheat chỉnh ở `src/shared/Config/AntiCheat.luau` (thêm zone đẩy/văng mới → thêm
  `STAGE_EXTRA_ALLOWANCE[stage]`).
- Trong Studio, `execute_luau` chạy VM riêng → ServiceLocator registry luôn rỗng khi require lại;
  test bằng HÀNH VI (attribute/leaderstats/vị trí), đừng tin registry check.

### 2026-06-29 (Session 4)
**Model:** Claude Opus 4.8
**Làm được:**
- **BasePads tuần tự:** thêm `DataTemplate.HighestPadIndex` (persist). `MultiplierPadService` bắt buộc mua đúng thứ tự (không cắt ngang): index<=highest → đổi active free; ==highest+1 → cần đủ Wins (ngưỡng, không trừ) → mở khóa; >highest+1 → chặn "Unlock Pad N first!". Server set attribute `HighestPadIndex`. Client `MultiplierPadVisualController` tô màu theo TIẾN ĐỘ: active=VÀNG, đã đạt=XANH LÁ, chưa đạt=XÁM. **FIX:** refreshAll giờ live-scan folder mỗi tick (trackedPads cũ bị rỗng nên không tô được). Test OK (ảnh xác nhận: pad1,2 xanh, pad3 vàng, pad4+ xám; skip pad3 khi highest=1 bị chặn).
- **Respawn nhanh về lobby:** `Core/RespawnService.luau` set `Players.RespawnTime = 0.4` (mặc định 5s). Chết bởi bất kỳ thứ gì → spawn lobby nhanh.
- **Fix khựng animation:** `ParkourAnimator` preload toàn bộ animation game 1 lần lúc client load (ContentProvider:PreloadAsync) → hết khựng nhẹ lần đầu.
- **Treadmill animation:** `HUDController.playTreadmillAnimation` ép phát anim chạy NHANH SprintF (Action priority) khi đứng treadmill, không dùng RunAnim mặc định chậm. Test: SprintF đang phát khi đứng Run pad.

### 2026-06-28 (Session 3)
**Model:** Claude Opus 4.8
**Làm được:**
- **Teleport:** gỡ bỏ hoàn toàn cơ chế chặn theo Level/WalkSpeed (StageGate) — player tự do teleport mọi stage (`TeleportService.luau`).
- **Zone 8 Sweeper:** tăng tốc quay 45→90°/s (calibrate tip ≈ 110 ≈ gate minWS 108), chạm là chết ngay (check mỗi frame + Touched backup), bỏ logic isQualified/Level survive cũ.
- **Zone 9 — Tsunami Sprint (MỚI):** map BƠI nằm NGANG (trục X) nối tiếp Zone 8. Geometry dựng bằng `tools/build_zone9.luau` (Workspace.Zone9 + ServerStorage.TsunamiTemplate). Runtime `Zone9TsunamiService.luau`: sóng tự spawn mỗi 6s, đuổi từ sau lưng @118 studs/s (< gate minWS 124), chạm = chết. Đã test trong Studio: spawn/move/kill OK, Started=true, không lỗi.

- **Inline trap scripts (theo yêu cầu):** chuyển cơ chế bẫy Zone 8 & Zone 9 RA KHỎI `server/Services/Zones/` vào Script đặt TRỰC TIẾP trong Workspace: `Workspace.Zone8.Mechanics.SweeperScript` và `Workspace.Zone9.Mechanics.Tsunami.TsunamiScript`. Đã XOÁ `Zone8SweeperService.luau` + `Zone9TsunamiService.luau`. Bản tham khảo: `tools/zone8_sweeper_inline.luau`, `tools/zone9_tsunami_inline.luau`. Tsunami CHẠY LIÊN TỤC theo vòng lặp (không cần player): quét từ vị trí đặt (home X≈-94) tới Stage9Finish, chạm player vẫn chạy tiếp, tới Finish thì BIẾN MẤT hoàn toàn, nghỉ 1.2s rồi quay về home lặp lại. Tốc độ tự tính theo gate: V = minWS(124)*(finishX-homeX)/(finishX-startX) ≈ 148 studs/s. Player vượt Finish được miễn nhiễm. Test: continuous loop + vanish + kill OK (~150 studs/s đo được).
- **Zone 7 (đường sập) làm lại:** `Workspace.Zone7.Zone7Controller` — bỏ cơ chế chạm-mới-sập; giờ khối TỰ ĐỘNG sập theo đợt sóng dọc +Z rồi tự mọc lại, lặp vô hạn, đẹp mắt (flash màu + rung → rơi mờ dần → fade-in). Ripple = 92 studs/s (gate Stage7). Test: 30/30 khối tự sập+mọc lại, không cần chạm.

- **Tất cả bẫy zone giờ INLINE trong Workspace:** Zone2/4/5 chuyển từ service sang `Workspace.Zone2.Zone2LaserScript`, `Workspace.Zone4.Zone4BossScript`, `Workspace.Zone5.Zone5SlideScript` (đọc Source ModuleScript rồi đổi `return XService` thành `XService.Init()+Start()`). `server/Services/Zones/` giờ TRỐNG. Test: Zone4 boss kill OK, không double-run.
- **Level Up UI cực đỉnh:** `src/client/Controllers/HUD/LevelUp.luau` — popup text+icon, nền trong suốt, COMBO LIÊN HOÀN (combo càng cao → màu nóng dần→cầu vồng, sunburst pulse, hạt nổ, pitch âm thanh tăng → cú hích Dopamine). Sound creator-store `89481514209130` (EasyPlay Level Up). Wired trong HUDController. Test: combo x6 hiển thị đẹp.

> ⚠️ **CẦN LÀM:** Mở Studio → **Save** place để geometry Zone9 + các inline Script Workspace (Zone2/4/5/7/8/9 — không được Rojo sync) ghi vào `SpeedEscape.rbxlx`. (LevelUp.luau là client script nên Rojo đã sync.) (Workspace parts không được Rojo sync, dễ mất nếu không save).

### 2026-06-19 (Session 2)
**Model:** Claude Haiku 4.5 → Claude Sonnet 4.6  
**Làm được:**
- Redesign header 4 modal sang Shop-style (yellow gradient)
- Tạo CodeModal (promo code redemption)
- Tạo TreadmillService (full touch system)
- Sync 13 files từ Studio về VSCode
- Cài skill `roblox-game` vào Claude Code
- Cấp quyền toàn bộ MCP tools
- Tạo CLAUDE.md + PROJECT_STATE.md + README.md

**Model tiếp theo cần biết:**
- Workflow: **chỉ edit VSCode**, Rojo sync tự động
- MCP đã cấp quyền đầy đủ trong `.claude/settings.local.json`
- `requestRedeemCode` packet đã có nhưng chưa có server handler

### 2026-06-18 (Session 1)
**Model:** Claude Haiku 4.5  
**Làm được:**
- Setup cơ bản project structure
- Khởi tạo dự án (commit đầu tiên)
