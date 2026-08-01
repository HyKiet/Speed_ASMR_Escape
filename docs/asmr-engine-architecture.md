# ASMR Floor Engine — Kiến trúc hệ thống sàn ASMR siêu tối ưu (Zero Lag / 60 FPS)

> Bản thiết kế v1 — 2026-07-18. Áp dụng cho 8 loại sàn: Clicky Keyboard, PopIt, BubbleWrap,
> Melody Run, Clay, Jelly, Soap, AquaRun (+ KineticSand đã có ở Lobby), phủ lên 15 Zone Obby.
> Mục tiêu: 60 FPS cố định trên mobile/máy yếu, phòng 25+ người, **giữ nguyên 100% cảm giác ASMR**.

---

## 0. Hiện trạng đo được (khảo sát Studio 2026-07-18)

| Model trong `ASMR_Test` | Parts | Sounds | Emitters | Script hiện tại |
|---|---|---|---|---|
| KeyBoard | 726 | **720** ⚠️ | **720** ⚠️ | KeyboardASMRClient (v5, 323 dòng — đã có pool 32 + grid) |
| PopItFloor | 69 | 0 | 0 | PopItClient (127 dòng — `Instance.new` Sound + Debris ⚠️, quét tuyến tính ⚠️) |
| BubbleWrapFloor | 82 | 0 | 0 | BubbleWrapClient (210 dòng) |
| JellyFloor | 11 | 0 | 0 | JellyClient (152 dòng) |
| MelodyRunFloor | 65 | 0 | 0 | MelodyRunClient (183 dòng) |
| KineticSandFloor | 146 | 0 | 0 | KineticSandClient (191 dòng) |
| ClayFloor | 38 | 0 | 0 | ClayClient (144 dòng) |
| AquaRunFloor | 6 | 0 | 0 | AquaRunClient (166 dòng) |
| SoapFloor | 7 | 0 | 0 | SoapCutClient (204 dòng) |

- **9 vòng lặp Heartbeat chạy song song**, mỗi script tự chép hàm `__fxOK` + ngân sách qua `_G` (anti-pattern).
- 15 Zone: 48 platform Ground, tổng diện tích mặt ≈ **375.000 studs²** → tile 3×3 ≈ **~40.000 tile** khi phủ full.
- KeyBoard còn sót 720 Sound + 720 ParticleEmitter per-phím từ bản cũ (v5 dùng pool nhưng chưa dọn instance thừa).

### Vấn đề phải giải quyết
1. Nhân 9 script × 15 zone = ~135 Heartbeat loop nếu clone nguyên trạng → sụt FPS chắc chắn.
2. 720 Sound/Emitter nhân bản theo zone = hàng vạn instance → tràn RAM mobile.
3. PopIt/… tạo-hủy Sound liên tục → GC spike (micro-stutter).
4. Mỗi script tự quét vị trí player theo cách riêng → trùng lặp tính toán mỗi frame.

---

## 1. Kiến trúc tổng thể — 1 Controller, N Adapter, 0 Server

```
src/client/Controllers/ASMR/
├── ASMRController.luau      ← DUY NHẤT 1 Heartbeat cho toàn bộ ASMR trên map
├── Engine/
│   ├── TileRegistry.luau    ← Đăng ký/hủy tile theo CollectionService tag + Streaming
│   ├── SpatialGrid.luau     ← Hash lưới 2D cell 3×3, tra cứu O(1)
│   ├── SoundPool.luau       ← Pool 32 Sound toàn cục + preload + warm-decode
│   ├── ParticlePool.luau    ← Pool 12 ParticleEmitter di động
│   ├── SpringSolver.luau    ← Tích phân lò xo chung (press/release k,d theo config)
│   └── FxBudget.luau        ← Ngân sách sound/hiệu ứng + culling theo camera
└── Floors/                  ← "Behavior Adapter" — config + hook riêng từng loại sàn
    ├── Keyboard.luau   ├── PopIt.luau      ├── BubbleWrap.luau
    ├── MelodyRun.luau  ├── Clay.luau       ├── Jelly.luau
    ├── Soap.luau       ├── AquaRun.luau    └── KineticSand.luau
```

- **Vị trí code:** Rojo-managed (`StarterPlayerScripts.Client.Controllers.ASMR`) — đúng workflow
  CLAUDE.md (edit VSCode → Rojo sync). **Xóa toàn bộ 9 script inline** trong model.
- **Server & network: 0%.** Không ByteNet, không RemoteEvent. Mọi hiệu ứng chỉ tính cho
  `Players.LocalPlayer` (Local Player Isolation) — chi phí client KHÔNG phụ thuộc số người trong server.

### 1.1 Adapter interface (data-driven, không copy-paste logic)

```lua
export type TileRecord = {
	part: BasePart,          -- tile thật (clone từ ASMR_Test)
	floorType: string,       -- "Keyboard" | "PopIt" | ...
	rest: CFrame,            -- CFrame gốc
	x: number, z: number, topY: number,
	depth: number, vel: number,      -- trạng thái SpringSolver
	pulseUntil: number, down: boolean,
	custom: { [string]: any }?,      -- state riêng của adapter (glow, popped, noteIndex...)
}

export type FloorAdapter = {
	name: string,
	config: {
		pressDepth: number,          -- độ lún
		pressK: number, pressD: number,
		releaseK: number, releaseD: number,
		soundIds: { number },        -- GIỮ NGUYÊN ID hiện có của từng sàn
		volume: NumberRange, pitch: NumberRange,
		reach: number,               -- bán kính ăn tile quanh chân
	},
	onRegister: ((rec: TileRecord) -> ())?,   -- đọc metadata tile (nốt nhạc, theme glow...)
	onStep: ((rec: TileRecord, ctx: StepContext) -> ())?, -- khi chân MỚI chạm tile (phát sound/particle)
	onUpdate: ((rec: TileRecord, dt: number, now: number) -> boolean)?, -- animate riêng; return false = tile ngủ lại
	onAmbient: ((dt: number, now: number, footPos: Vector3) -> ())?,    -- hiệu ứng vùng (RGB glow, gợn sóng Aqua)
}
```

Logic chung (swept detection, grid lookup, spring, budget) sống trong Engine —
adapter **chỉ khai báo config + hook đặc thù**. 9 script cũ co lại thành ~30–80 dòng config/adapter.

---

## 2. Data model trong Workspace

### 2.1 Chuẩn hóa tile (Zero Physics Overhead)
Mọi BasePart tile ASMR (script builder áp khi rải):

| Thuộc tính | Giá trị | Lý do |
|---|---|---|
| `Anchored` | `true` | Không simulation |
| `CanCollide` | `false` | Nhân vật đứng trên WalkSurface, không phải tile |
| `CanTouch` | `false` | Không sự kiện Touched — phát hiện bằng toán học |
| `CanQuery` | `false` | Raycast/OverlapParams bỏ qua hàng vạn tile |
| `CastShadow` | `false` | Giảm draw cost đổ bóng |
| Vị trí | nổi **+0.02** trên mặt platform | tránh z-fighting (quy ước sẵn có) |

**WalkSurface:** nhân vật chạy trên chính `Ground.Platform_*` của Zone (đã CanCollide) — không cần
part tàng hình thêm, trừ sàn có bề mặt lồi (Keyboard/Jelly) thì kèm 1 WalkSurface phẳng
trong suốt `CanCollide=true` per cluster như mẫu `KeyBoard.WalkInfra` hiện có.

### 2.2 Đánh dấu & metadata — CollectionService, không script con
- Tag `ASMRTile` trên từng tile + Attribute `FloorType = "PopIt" | ...`.
- Metadata riêng qua Attribute: `Note` (MelodyRun), `GlowTheme` (Keyboard), `Row` (Soap)...
- Cluster mỗi zone: `Workspace.Zones.ZoneN.ASMR` (Model, **`ModelStreamingMode = Atomic`**).

### 2.3 Streaming compatibility
`TileRegistry` lắng nghe `CollectionService:GetInstanceAddedSignal("ASMRTile")` /
`GetInstanceRemovedSignal` → tile tự vào/ra `SpatialGrid` khi StreamingEnabled nạp/xả zone.
Không `WaitForChild` chuỗi dài, không giả định zone nào đang tồn tại trong memory.

---

## 3. Frame pipeline (1 Heartbeat duy nhất)

```
Heartbeat(dt):
 1. GATE      : LocalPlayer còn sống? Nằm trong bounding region tile nào? (early-out ~0 cost khi ở ngoài)
 2. SWEEP     : lấy footPos; nếu di chuyển > 1.4 studs từ frame trước → lấy mẫu dọc đường đi
                (SAMPLE_STEP=1.4, MAX_SAMPLES=40 — giữ nguyên từ Keyboard v5, không hụt phím khi speed 250+)
 3. LOOKUP    : với mỗi điểm mẫu → SpatialGrid tra 9 cell quanh chân, O(1), lọc theo reach + Y-tolerance
 4. DISPATCH  : tile MỚI chạm → adapter.onStep(rec) — phát sound (SoundPool), particle (ParticlePool),
                đánh thức tile vào activeSet
 5. ANIMATE   : SpringSolver tích phân mọi tile trong activeSet (mọi loại sàn chung 1 vòng);
                adapter.onUpdate cho hành vi riêng (glow decay, re-inflate PopIt, sóng Aqua);
                tile về trạng thái nghỉ → rời activeSet (map về đúng 0 cost khi không ai giẫm)
 6. AMBIENT   : adapter.onAmbient (RGB glow radius 8, gợn nước) — chỉ chạy cho sàn trong ActiveRadius
 7. BUDGET    : FxBudget chốt số sound/frame và tổng sound/0.1s (mục 5)
```

Điểm mấu chốt: **activeSet rỗng ⇒ vòng Heartbeat gần như miễn phí.** Tất cả 40.000 tile
"đóng băng" mặc định; chỉ tile bị giẫm trong ~0.5s gần nhất mới được tích phân.

---

## 4. Pool tài nguyên toàn cục (thay cho per-tile instance)

### 4.1 SoundPool — 32 Sound cố định
- Khởi tạo 32 Sound lúc load, `PreloadAsync` toàn bộ ID của **cả 9 sàn** + **warm-decode**
  (phát 1 lần Volume=0) — fix trễ nhịp lần phát đầu (bài học v5 đã verify).
- Phát = round-robin: re-parent Sound vào tile, set `SoundId/Volume/PlaybackSpeed`, `Play()`.
  Không `Instance.new`, không `Debris` → **0 GC churn** (sửa dứt điểm anti-pattern của PopIt/BubbleWrap cũ).
- RollOff giữ nguyên: InverseTapered, min 18 / max 70–80.

### 4.2 ParticlePool — 12 emitter di động
- 12 Part tàng hình anchored, mỗi part 1 ParticleEmitter (Stars/Splash/Dust… đổi texture theo sàn).
- Khi cần: dịch part đến tile → `Emit(n)`. **Xóa toàn bộ 720 emitter per-phím** hiện có.

### 4.3 Dọn rác model gốc
Migration phải xóa khỏi `ASMR_Test` (và mọi bản clone): 720 Sound + 720 Emitter trong KeyBoard,
9 script inline. Ước tính giảm **>90% instance count** phần ASMR.

---

## 5. Ngân sách hiệu năng (hard budgets — FxBudget.luau)

| Ngân sách | Giá trị | Ghi chú |
|---|---|---|
| Sound mỗi frame | 8 | burst chia volume (giữ cơ chế v5) |
| Sound mỗi 0.1s toàn map | 20 | chuyển từ `_G` → module state |
| ActiveRadius hiệu ứng | 60–80 studs quanh **camera** | ngoài bán kính: tile sleep tuyệt đối |
| Nhãn chữ / SurfaceGui | `MaxDistance = 50–60` | BillboardGui/SurfaceGui LOD |
| Tile animate đồng thời | cap 160 | vượt cap → tile cũ nhất snap về rest |
| Spring step | `math.min(dt, 1/30)` | ổn định tích phân khi frame drop |
| Ambient glow scan | ≤ (2r/3+1)² cell ≈ 49 cell/frame | radius 8 ⇒ không đổi so v5 |

---

## 6. Bảo tồn 100% trải nghiệm ASMR — ma trận tính năng

| Sàn | Hiệu ứng giữ nguyên | Cơ chế trong kiến trúc mới |
|---|---|---|
| Keyboard | Lún lò xo sâu 0.9; 6 click cơ ProSoundEffects (ID 9116158528…) + pitch random; RGB glow r=8 theme Plain; Stars khi dậm | SpringSolver (k=1400/42, 330/13); SoundPool; onAmbient glow (giữ nguyên công thức hue/decay v5); ParticlePool thay 720 Stars |
| PopIt | Hạt lún + đổi màu tối, pop lách tách (4 ID), tự phồng lại 2.2–4.4s + tiếng trầm | onStep pop; onUpdate re-inflate bằng SpringSolver thay TweenService (mượt hơn, không cấp phát Tween) |
| BubbleWrap | Bóng bẹp xuống + nổ xốp giòn | như PopIt, config riêng depth/sound |
| MelodyRun | Phím piano lún + nốt nhạc theo tile | Attribute `Note` per tile; onStep phát đúng pitch qua PlaybackSpeed |
| Clay | Nhún dẻo squish + âm nặn đất | spring mềm (k thấp, d cao), sound clay |
| Jelly | Nén xuống bật lại bồng bềnh | spring nảy (d thấp → overshoot), scale mesh theo depth |
| Soap | Thanh xà phòng chìm + tiếng cắt sần sật | spring + sound cắt; giữ bố cục Bars |
| AquaRun | Gợn sóng nhấp nhô + bắn nước | onAmbient sóng sin quanh chân (chỉ tile trong ActiveRadius); ParticlePool splash |
| KineticSand (Lobby) | giữ nguyên hành vi hiện tại | port thành adapter thứ 9, Lobby dùng chung engine |

Mọi hằng số cảm giác (depth, k/d, PULSE, reach, pitch range, sound ID) **bê nguyên xi từ script cũ
sang config adapter** — trải nghiệm không đổi, chỉ đổi chỗ chạy.

---

## 7. Thứ tự thực thi

### Phase 1 — ASMR_Test (proof + đo đạc)
1. Viết Engine + 9 adapter trong `src/client/Controllers/ASMR/` (Rojo sync).
2. Script dọn dẹp (execute_luau, Edit mode): xóa 9 script inline, xóa 720 Sound + 720 Emitter,
   áp 5 flag chuẩn hóa + tag `ASMRTile` + `FloorType` cho toàn bộ tile trong `ASMR_Test`.
3. Playtest (rbx-qa): so sánh trước/sau — frame time (Stats.HeartbeatTimeMs), instance count,
   memory (`Stats:GetTotalMemoryUsageMb`), đủ 9 hiệu ứng sound/visual. Tiêu chí: 60 FPS, 0 warning console.

### Phase 2 — Rải 15 Zone
1. Builder script (Edit mode): với mỗi `ZoneN.Ground.Platform_*` → clone **model THẬT** từ
   `ASMR_Test` theo phân công sàn/zone, tile nổi +0.02, đóng gói `ZoneN.ASMR` (Atomic),
   áp flags + tags tự động. Không resize mẫu (quy ước hiện hành).
2. Kiểm tra StreamingEnabled: chạy xuyên 15 zone, xác nhận tile vào/ra registry sạch, memory ổn định.
3. Test 25+ player (multi-client Studio) — xác nhận chi phí không đổi theo số người.

### Điều kiện dừng/rollback
Mỗi phase commit riêng; `ASMR_Test` giữ nguyên hình học (chỉ gỡ script/instance thừa) nên
rollback = revert commit + re-sync Rojo.
