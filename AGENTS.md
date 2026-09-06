---
name: speedescape
description: Luật kỹ thuật duy nhất của +1 Speed Escape. Mọi AI (Claude, Codex, Gemini…) PHẢI đọc hết file này trước khi đọc hay viết bất kỳ dòng code nào của game.
---

# +1 Speed Escape — Luật kỹ thuật

> **File này là nguồn chân lý duy nhất về cách viết code trong repo.**
> Không có file hướng dẫn thứ hai. Nếu bạn thấy một file khác mâu thuẫn với file này, file này thắng — và hãy báo để xoá file kia.

---

## Luật 0 — Kim chỉ nam là tài liệu chính thức

Trước khi trả lời bất kỳ câu hỏi nào về **API, hành vi engine, hay giới hạn của Roblox**, tra
**https://github.com/Roblox/creator-docs** trước, rồi mới trả lời.

| Cần gì | Tra ở đâu |
|---|---|
| Bản Markdown gốc | `content/en-us/**` trong repo creator-docs |
| Trang web tương ứng | `content/en-us/<đường-dẫn>.md` → `create.roblox.com/docs/<đường-dẫn>` |
| Chữ ký API của một class/enum | `content/en-us/reference/engine/classes/<Tên>.yaml` |

### 0.1 — Tra bằng cách nào

Đọc **file trong repo**, đừng mở trang web rồi đoán. Hai lệnh, không cần token:

```
# Chưa biết tài liệu tên gì → liệt kê thư mục
https://api.github.com/repos/Roblox/creator-docs/contents/content/en-us/<thư-mục>

# Đã biết cần gì → đọc thẳng file thô
https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/<đường-dẫn>
```

Với **API cụ thể**, tin `reference/engine/classes/<Tên>.yaml` hơn mọi thứ khác — nó là chữ ký
sinh ra từ engine, không phải văn xuôi người viết.

> **Nếu môi trường của bạn không có mạng** (Codex chạy sandbox thường tắt mặc định): **nói ra**.
> Đừng im lặng trả lời bằng trí nhớ. "Tôi không truy cập được creator-docs, dưới đây là theo trí
> nhớ, cần kiểm lại" là câu trả lời chấp nhận được. Trả lời như thể đã tra thì không.

### 0.2 — Ba quy tắc khi tra

1. Trích thì **dẫn đường dẫn file** trong creator-docs. Không dẫn được = bạn đang nhớ chứ không
   phải đang biết → nói rõ "cái này tôi nhớ, chưa kiểm". Link `create.roblox.com/...` **không
   tính** — đó là trang web, không phải file bạn đã đọc.
2. Trí nhớ về API Roblox **hết hạn nhanh**. Deprecated liên tục (`Humanoid.Jump`,
   `PhysicsService:SetPartCollisionGroup`, `Terrain.Decoration`…). Trước khi dùng một API bạn
   không gõ trong tháng này, kiểm lại.
3. Tài liệu chính thức nói về **Roblox chuẩn**. Repo này nói về **game này**. Xung đột thì
   repo thắng — nhưng phải giải thích tại sao ta lệch chuẩn, đừng lặng lẽ lệch.

### 0.3 — ⭐ BẮT BUỘC: làm xong thì liệt kê đã tra những gì

**Mỗi lần code xong một chức năng, hoặc sửa xong một lỗi, phần cuối báo cáo phải có khối này:**

```
## Đã tra creator-docs
| Đường dẫn file | Tra để làm gì | Rút ra được gì |
|---|---|---|
| content/en-us/reference/engine/classes/AnimationTrack.yaml | xác nhận Priority làm gì | Priority chỉ chọn pose nào HIỆN; track thua vẫn chạy ngầm ⇒ phải :Stop() chứ không hạ ưu tiên |
| content/en-us/ui/on-screen-containers.md | chọn container cho banner | ScreenGui.IgnoreGuiInset đổi gốc toạ độ — ảnh hưởng lề trên |
```

**Không tra gì thì vẫn phải ghi, và ghi lý do:**

```
## Đã tra creator-docs
Không tra — thay đổi thuần trong code sẵn có (đổi hằng số cân bằng), không đụng API engine nào.
```

Ba lý do luật này tồn tại, theo thứ tự quan trọng:

1. **Câu trả lời bịa nghe y hệt câu trả lời tra thật.** Không CI nào bắt được, không lỗi nào
   hiện ra. Bảng này là chỗ duy nhất phân biệt được hai thứ đó — vì đường dẫn sai thì mở ra là
   404 ngay.
2. **Nó cho người review biết chỗ nào KHÔNG được kiểm**, tức chỗ nào rủi ro nhất trong PR.
3. **Nó là ghi chép cho lần sau.** Dòng "rút ra được gì" chính là thứ đáng chuyển thành comment
   cạnh đoạn code tương ứng (xem §5 luật 12).

⛔ **Không có khối này = công việc chưa xong.** Người review có quyền trả lại mà không cần đọc code.

---

## 1. Game này là gì (30 giây)

Speed Simulator × Obby, canvas 1920×1080.

**Core loop:** farm XP/Speed trên Treadmill → chạy Obby qua 15 zone → vượt Gate → nhận Wins →
mua cosmetic/upgrade → Rebirth → lặp.

**Hai place, hai universe RIÊNG** (đọc `src/shared/Util/Env.luau` trước khi đụng tới data hoặc
mua bán — file đó ghi đủ ID và các bẫy đã dính):

| | PlaceId | UniverseId |
|---|---|---|
| QA | `134428972694212` | `10648253073` |
| Live | `94107323826144` | `10456737957` |

**Repo chứa code, KHÔNG chứa thế giới.** 15 zone / Lobby / treadmill / sàn ASMR / terrain sống
trên Roblox Cloud, người đồng bộ bằng tay. `SpeedEscape.rbxl` chỉ là ảnh chụp. Hệ quả: **không
bao giờ suy ra map từ code.** Muốn biết map có gì thì hỏi Studio (`execute_luau`,
`search_game_tree`), đừng đoán.

---

## 2. Bản đồ code

```
src/
├── client/init.client.luau      ← quét đệ quy Controllers/, require → Init() → Start()
│   └── Controllers/
│       ├── HUD/                 ← toàn bộ UI (Fusion)
│       │   ├── Tokens.luau      ← ⭐ MỌI hằng số dùng chung của UI (font, màu, Z, khoảng cách)
│       │   ├── Theme.luau       ← factory dựng Instance + xuất lại token dưới tên cũ
│       │   ├── State.luau       ← ⭐ MỌI Fusion Value/Tween
│       │   ├── Components/      ← vỏ dùng chung (ModalShell)
│       │   ├── Hud/             ← thành phần luôn hiện
│       │   └── Modals/          ← Registry.luau là danh sách modal thật
│       ├── CoreLoop/ Effects/ Movement/ Zones/ ASMR/ Emotes/ Debug/
├── server/init.server.luau      ← quét đệ quy Services/, cùng vòng đời Init/Start
│   └── Services/{Core,Gameplay,World,Zones}/
└── shared/
    ├── Network/GamePackets.luau ← ⭐ HỢP ĐỒNG DUY NHẤT qua ranh giới client–server
    ├── Config/                  ← số liệu cân bằng, kinh tế, zone
    ├── Constants.luau  Config/Formulas.luau  Config/Tuning.luau
    └── Util/                    ← ServiceLocator, Log, LagComp, Env, TrapSweep…
```

**Cả hai bootstrapper tự quét thư mục.** Thả một `.luau` mới vào `Controllers/` hay `Services/`
là nó tự chạy — không có danh sách đăng ký nào để sửa, và cũng không có file nào "chết vì không
ai require". Ngược lại: **thêm file = thêm tải cho mọi phiên chơi.**

**Đừng chép số vào tài liệu.** Cần danh sách modal thì đọc `Modals/Registry.luau`; cần danh sách
sàn ASMR thì đọc thư mục `ASMR/Floors/`. Tài liệu chép lại sẽ sai trong hai tuần.

---

## 3. Stack — dùng đúng thứ này, không dùng thứ khác

| Việc | Dùng | KHÔNG dùng |
|---|---|---|
| Networking | **ByteNet 0.6.0** | `RemoteEvent` / `RemoteFunction` thô |
| Lưu dữ liệu | **ProfileStore 1.0.3** | `DataStoreService` trực tiếp |
| UI | **Fusion 0.2.0** | dựng Instance bằng tay ngoài `Theme` |
| Dọn kết nối | **Janitor** (`aspecky/sweeper@2.2.0`) | tự quản `:Disconnect()` rải rác |
| Topbar | **TopbarPlus 3.4.0** | |
| Vùng không gian | **ZonePlus 3.2.0** | |
| DI | `Shared/Util/ServiceLocator` | require chéo service ↔ service |

Toolchain: Rojo 7.7.0 · StyLua 0.20.0 · Selene 0.27.1 · Wally 0.3.1 (`aftman.toml`).
Mọi file mở đầu bằng `--!strict`.

---

## 4. Bốn khuôn mẫu — code mới phải khớp một trong bốn

### 4.1 Service (server) và Controller (client) — cùng vòng đời

```lua
--!strict
local MyService = {}

local OtherService  -- điền trong Init, KHÔNG require ở đầu file

function MyService.Init()          -- pha 1: chỉ lấy dependency, không chạy logic
	OtherService = ServiceLocator.Get("OtherService")
end

function MyService.Start()         -- pha 2: nối event, bắt đầu vòng lặp
	Players.PlayerAdded:Connect(onPlayerAdded)
end

return MyService
```

`Init()` của mọi service chạy xong **trước** `Start()` đầu tiên. Đó là lý do lấy dependency
phải nằm ở `Init` — đặt ở đầu file sẽ tạo vòng require.

### 4.2 Network — mọi thứ qua ranh giới đều khai ở `GamePackets.luau`

```lua
-- shared/Network/GamePackets.luau
myPacket = ByteNet.definePacket({ value = ByteNet.struct({ field = ByteNet.string }) })

GamePackets.myPacket.send({ field = "x" })              -- client → server
GamePackets.myPacket.listen(function(data, player) end) -- server nhận (player LUÔN là tham số 2)
GamePackets.myPacket.sendTo({ field = "x" }, player)    -- server → đúng 1 người
```

**Quy ước tên — giữ đúng, nó là thứ giúp đọc code không cần mở file:**

| Tiền tố/hậu tố | Nghĩa | Ai gửi |
|---|---|---|
| `request*` | client **xin phép**, server phán xử | client |
| `*State`, `*Snapshot` | server **thông báo sự thật** | server |

### 4.3 UI (Fusion) — state ở `State.luau`, số ở `Tokens.luau`

```lua
State.myValue = Value(false)
State.myAnim  = Tween(State.myAnimGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad))
```

- Modal mới → dựng bằng `Components/ModalShell`, đăng ký ở `Modals/Registry.luau`, mở/đóng qua
  `Modals/Manager.luau`. Đừng dựng vỏ riêng.
- **Cấm gõ số thẳng** (màu, font, bán kính, ZIndex, khoảng cách). Đọc `Tokens.X`. Số chỉ dùng ở
  đúng một màn hình thì để ngay trong file đó — đừng nhét vào `Tokens`.
- Nền UI dùng `Theme.MakeSurface`. **Cấm `UIStroke` làm viền nền** (lệch 32%).
- Modal căn giữa `(960, 492)`, scale qua `UIScale` + `State.viewportScale`.

### 4.4 Dữ liệu — server sở hữu, client chỉ được xem

Ghi vào bảng phiên trong bộ nhớ; ProfileStore tự lưu theo chu kỳ và lúc `PlayerRemoving`.
**Không gọi `:Save()` thủ công sau mỗi hành động gameplay.**

Đổi schema đã lưu ⇒ **bắt buộc** bump version + viết đường migration cho người chơi cũ, và nói
rõ trong PR. Người đang chơi không được mất gì.

---

## 5. Luật cứng — vi phạm là hỏng thật, không phải "chưa đẹp"

**Ranh giới tin cậy**

1. **Server là sự thật duy nhất.** Không tin gói nào từ client tự nhận đã tiến bộ / đã thắng /
   đáng được thưởng. Client được phép *phát hiện*, server phải *đo lại*.
   Mẫu chuẩn để đọc: `TreadmillClientController` → `TreadmillService` (server tự tìm hitbox gần
   nhất và tự đo khoảng cách; sai thì bỏ qua, không phạt).
2. **Validate + rate-limit mọi gói vào** (`Shared/Util/NetRateLimit`). Giả định client thù địch.
3. Đổi tiền/inventory phải **trừ trước, cấp sau**, và phát event kinh tế cho analytics.

**Quy trình sửa file**

4. Sửa `.luau` **trong VSCode**, save → Rojo tự sync. Rojo chạy **MỘT CHIỀU** (VSCode → Studio):
   sửa trong Studio sẽ bị ghi đè mất. MCP `multi_edit` chỉ để **đọc/verify**, không để sửa.
5. **Không sửa `.luau` bằng PowerShell `Get-Content`/`Set-Content`** — PS 5.1 đọc ANSI ghi UTF-8,
   mojibake toàn bộ comment tiếng Việt. Chỉ dùng Edit/Write.

**Streaming & vòng đời**

6. Streaming đang bật. **Không giả định instance tồn tại.** Resolve phòng thủ
   (`Shared/Util/PathResolver`) và **warn to** khi trượt — `nil` im lặng là cách bug sống sót
   hàng tuần.
7. Dọn mọi connection, task, instance bạn tạo. Phiên dài mới lộ rò rỉ; playtest Studio thì không.

**Cân bằng & số liệu**

8. **Bạn là engineer, không phải designer.** Không tự nghĩ ra hay lặng lẽ chỉnh một con số cân
   bằng (giá, tỉ lệ rơi, phần thưởng, đường cong tiến trình). Thấy sai thì **đo, in bảng ra, rồi
   hỏi**.
9. **Hằng số đã tinh chỉnh thường đi theo cặp khoá nhau** (tốc độ chạy ↔ hình học level; phần
   thưởng ↔ chi phí nó phải bù). Đổi một cái thì **gọi tên cái kia và kiểm nó**. Phá cặp cho ra
   ngõ cụt im lặng chứ không phải crash.
10. Cân bằng chỉ được **nới, không được siết**. Người chơi không bao giờ được thấy thứ họ đã có
    bị lấy đi.
11. **Không đổi thứ tự hay ý nghĩa bước funnel analytics đang có** — làm thế là huỷ dữ liệu lịch
    sử. Chỉ được thêm bước vào cuối, hoặc dựng funnel song song.

**Comment**

12. Comment trong repo này ghi **VÌ SAO** một hằng số mang giá trị đó và **cái gì vỡ nếu đổi**.
    Chúng mã hoá những con bug đã tốn nhiều ngày. **Giữ và mở rộng chúng**, đừng dọn cho gọn.
    Viết comment tiếng Việt; định danh, type và log tag giữ tiếng Anh.

---

## 6. Hiệu năng — ngân sách là 25 người cùng lúc

**Mạng**
- Gói tần suất cao phải là ByteNet nhị phân. Trạng thái đổi liên tục (Speed, XP) → gửi 10–20 Hz,
  không phải mỗi Heartbeat.
- Chỉ gửi khi giá trị **thật sự đổi** quá ngưỡng. Gửi cho **đúng người cần** (`sendTo`), đừng
  broadcast cho cả 25.

**CPU server**
- **Không** tạo `while true do` / `task.spawn` cho từng người chơi hay từng vật thể. Một service
  = một vòng lặp quản lý, duyệt mảng đã đăng ký.
- 25 người cần tính định kỳ → **chia đều qua các frame**, mỗi frame xử lý một phần.
- Thay `Touched` tần suất cao bằng `GetPartBoundsInBox` / lưới không gian ở nhịp có kiểm soát
  (0.1–0.2 s). Part trang trí: `CanTouch = false`, `CanQuery = false`.
- Bẫy ở tốc độ cao: thử điểm rời rạc là **bắn hụt** → dùng `Shared/Util/TrapSweep` (swept), mỗi
  bẫy một bảng dấu vết riêng.

**Client**
- **Server không bao giờ dựng ParticleEmitter / aura / trail / tween cosmetic.** Server giữ
  trạng thái (`EquippedTrail = "NeonRider"`), client tự vẽ (`CosmeticVisualController`).
- Cull hiệu ứng của người chơi ở xa. 25 aura mật độ cao cùng lúc là chết FPS client.
- Va chạm người–người: TẮT (`CollisionGroupService`).

**Đo đạc**
- **Đo trước khi sửa.** Nghi ngờ một con số thì viết script in đường cong thật ra, dán bảng vào
  PR. Không bao giờ chỉnh theo ước lượng — kể cả ước lượng của chính bạn.
- **Studio nói dối về hiệu năng**: mất focus là tụt còn ~15 FPS, `execute_luau` chạy VM riêng
  (ByteNet không qua được), và Studio không tái tạo được độ trễ mạng. Kết quả chỉ đúng trong
  Studio thì **phải nói rõ là chỉ đúng trong Studio**.

---

## 7. Trước khi nói "xong"

1. **Khối "Đã tra creator-docs" (§0.3)** — thiếu là chưa xong, không có ngoại lệ.
2. `selene --allow-warnings src` — error là chặn cứng.
3. `rojo build default.project.json -o /tmp/ci.rbxl` — không build được thì không publish được.
4. `stylua --check src` với file bạn đụng tới.
5. Không thêm lỗi type mới so với `.github/luau-lsp-baseline.txt`.
6. Publish **QA trước**, chạy `docs/REGRESSION.md`, rồi mới Live. **Không bao giờ publish thẳng
   Live.**
7. Roblox **không cập nhật server đang chạy** — bản mới chỉ áp cho server sinh ra sau đó. Kiểm
   bằng `game.PlaceVersion` in ở log `[SERVER READY]`, đừng tin trang publish.

**Báo cáo trung thực:** nói rõ cái gì bạn đã *kiểm chứng* và cái gì bạn chỉ *giả định*. Test
trượt hay bước bị bỏ qua thì nói thẳng kèm output. Không thêm dependency, không đổi tên hệ thống,
không tái cấu trúc thư mục nếu chưa hỏi.

---

## 8. Tài liệu tra cứu trong repo

Repo cố ý giữ **rất ít** tài liệu. Bốn file, không hơn:

| Cần gì | File |
|---|---|
| Thiết kế game, số cân bằng đã chốt | `GDD.md` |
| Setup, nguồn chân lý của map, PlaceId | `README.md` |
| Việc đang làm và vì sao (sprint giữ chân) | `docs/PLAYTIME.md` |
| Checklist bắt buộc trước publish | `docs/REGRESSION.md` |

**Đừng thêm file thứ năm.** Nếu điều bạn định viết là *vì sao một con số mang giá trị đó*, chỗ
của nó là comment ngay cạnh con số ấy — nơi người sửa nó sẽ đọc.

Số liệu **không** nằm trong tài liệu: mã quà tặng ở `Config/Economy/Codes.luau`, gamepass ở
`Config/Economy/Gamepass.luau`, product ở `Config/Economy/Products.luau`, ID môi trường ở
`Util/Env.luau`. Tài liệu nào chép lại các số đó là đang nói dối bạn — tin code.
