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

### Khởi động

**1. Mở Roblox Studio** và load file `.rbxl` trong thư mục gốc

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
