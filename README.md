# +1 Speed Escape

Speed Simulator + Obby Hybrid game trên Roblox.

---

## Cho AI Model: Đọc ngay các file này theo thứ tự

```
1. CLAUDE.md         ← Kiến trúc, patterns, rules bắt buộc
2. PROJECT_STATE.md  ← Trạng thái hiện tại + việc cần làm
3. GDD_v2.md         ← Game design document đầy đủ
```

**Câu hỏi nhanh:**
- *Tôi đang làm gì?* → Xem `PROJECT_STATE.md` phần "Việc cần làm"
- *Code viết kiểu gì?* → Xem `CLAUDE.md` phần "Patterns & Rules"
- *Workflow ra sao?* → Edit VSCode → Rojo sync tự động → Studio

---

## Setup môi trường

### Yêu cầu
- Roblox Studio (bản mới nhất)
- VSCode với extension **Rojo**
- Rojo CLI 7.7.0+
- Node.js (cho tooling)

### ⚠️ Nguồn chân lý của THẾ GIỚI GAME (đọc trước tiên)

Repo này chứa **code**, không chứa **thế giới**. Hai thứ đó sống ở hai nơi khác nhau:

| Thứ | Nguồn chân lý | Ai đồng bộ |
|---|---|---|
| Script (`src/`) | **Git** | Rojo, một chiều VSCode → Studio |
| Thế giới: 15 zone, Lobby, treadmill, sàn ASMR, terrain, lighting | **Place trên Roblox Cloud** | Con người, thủ công |

Snapshot thế giới nằm ở **`SpeedEscape.rbxl`** (68.228 instance, ~1.3 MB — chụp 2026-08-18).
File `.rbxlx` cũ chỉ là vỏ 153 instance, **không phải** thế giới; mở nó ra là thấy đủ script
và một bản đồ trống rỗng.

**Vì vậy, trước khi làm bất cứ việc gì đụng tới map:**

1. Mở place từ Roblox (Home → My Games), **không** mở file `.rbxlx` trong repo.
2. Hai PlaceId hợp lệ — **luôn kiểm tra bạn đang ở đâu** trước khi sửa:
   - QA `76318425379626` — nơi thử nghiệm.
   - Live `94107323826144` — **người chơi thật đang ở đây**.
   Kiểm nhanh trong Command Bar: `print(game.PlaceId)`.
3. Sửa map xong thì **Publish** (File → Publish to Roblox) — đó mới là lưu thật.

**Sao lưu thế giới ra git (nên làm mỗi khi map đổi đáng kể):**

```
Studio → File → Download a Copy → lưu vào thư mục repo, đè SpeedEscape.rbxl (kiểu .rbxl)
git add -f SpeedEscape.rbxl && git commit -m "Snapshot world <ngày>"
```

> Place mở từ cloud thì menu **không có** "Save to File As…" — Studio thay bằng
> **"Download a Copy"**. Chọn kiểu **`.rbxl`** (binary), đừng chọn `.rbxlx`: XML sẽ phình lên
> hàng trăm MB và đụng trần 100 MB/file của GitHub, còn binary chỉ ~1.3 MB.
>
> Kiểm nhanh file vừa tải có đúng là thế giới không (không cần mở Studio) — header khai sẵn
> số instance ở offset 20:
> ```bash
> od -An -tu4 -j20 -N4 SpeedEscape.rbxl    # ~68.000 = đúng; vài trăm = mới chỉ có code
> ```

Không có bước này thì thế giới chỉ tồn tại trên máy bạn và trên Roblox Cloud — mất tài khoản
hoặc lỡ tay ghi đè là chỉ còn khôi phục được qua Version History trên Creator Dashboard.
CI có cổng `Place snapshot` cảnh báo khi file trong repo vẫn còn là vỏ rỗng.

---

### Khởi động

**1. Mở Roblox Studio** → **Open from Roblox** → chọn **`[QA] SpeedEscape`**

> Mở từ cloud, KHÔNG mở `SpeedEscape.rbxl` trong repo — file đó là *bản sao lưu*, sửa vào nó
> thì không ai thấy. Xác nhận đúng place trước khi làm gì: `print(game.PlaceId)` →
> `76318425379626` (QA). Ra `94107323826144` là bạn đang ở **Live**.

**2. Start Rojo sync** trong VSCode terminal:
```bash
rojo serve
```

**3. Kết nối trong Studio** → Plugins → Rojo → Connect

**4. Rojo sẽ sync VSCode → Studio tự động** khi save file

> ⚠️ Rojo chỉ sync **một chiều**: VSCode → Studio  
> Không bao giờ edit trực tiếp trong Studio Explorer

---

## Cấu trúc thư mục

```
SpeedEscape/
├── src/
│   ├── client/        ← LocalScript, UI Controllers
│   ├── server/        ← Script, Services
│   └── shared/        ← ModuleScript, Constants, Config
├── Packages/          ← Wally packages (Fusion, ByteNet, Janitor)
├── ServerPackages/    ← Wally server packages (ProfileStore)
├── default.project.json  ← Rojo config
├── wally.toml         ← Package dependencies
├── CLAUDE.md          ← AI collaboration guide
├── PROJECT_STATE.md   ← Current state tracker
└── GDD_v2.md          ← Game design document
```

---

## Packages chính

| Package | Path | Dùng cho |
|---------|------|----------|
| Fusion 0.2.0 | `ReplicatedStorage.Packages.Fusion` | Reactive UI |
| ByteNet 0.6.0 | `ReplicatedStorage.Packages.ByteNet` | Networking |
| Janitor | `ReplicatedStorage.Packages.Janitor` | Cleanup |
| ProfileStore | `ServerScriptService...` | Data persistence |

---

## MCP (dành cho Claude Code)

MCP Roblox Studio đã được cấu hình với full permissions tại `.claude/settings.local.json`.

Tools hữu ích:
```
mcp__Roblox_Studio__script_read     ← Đọc script từ Studio
mcp__Roblox_Studio__execute_luau    ← Chạy code trong Studio
mcp__Roblox_Studio__get_console_output ← Xem log
mcp__Roblox_Studio__screen_capture  ← Chụp màn hình Studio
```

---

## Game Design tóm tắt

- **Core loop:** Farm Treadmill → Chạy Obby → Vượt Gate → Wins → Cosmetics → Rebirth
- **World 1:** 15 stages, Max Level 120
- **World 2:** Max Level 220 (planned)
- **Multipliers:** Premium (gamepass) × Gear (cosmetic) × Progress (rebirth)
- **Max whale advantage:** ~215× so với F2P

Xem `GDD_v2.md` để biết chi tiết đầy đủ.
