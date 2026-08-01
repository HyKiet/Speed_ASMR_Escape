# SpeedEscape — AI Collaboration Guide

> Đọc file này trước khi làm bất cứ điều gì. Áp dụng cho mọi AI model (Claude, ChatGPT, Gemini, v.v.)

---

## Tổng quan dự án

**Tên game:** +1 Speed Escape  
**Engine:** Roblox Studio  
**Ngôn ngữ:** Luau (TypeScript-flavored strict mode `--!strict`)  
**Thể loại:** Speed Simulator + Obby Hybrid

**Core loop:** Farm XP/Speed trên Treadmill → Chạy Obby → Vượt Gate → Nhận Wins → Mua cosmetics/upgrades → Rebirth → Lặp lại

---

## Kiến trúc hệ thống

### Cây thư mục chính
```
src/
├── client/
│   └── Controllers/
│       ├── HUD/                    ← Toàn bộ UI
│       │   ├── HUDController.luau  ← Orchestrator chính
│       │   ├── State.luau          ← Tất cả Fusion Values/Tweens
│       │   ├── Theme.luau          ← Asset IDs + UI factory helpers
│       │   ├── Toast.luau          ← Thông báo popup
│       │   ├── Hud/
│       │   │   ├── LeftMenu.luau   ← Wins badge + 5 menu buttons
│       │   │   ├── BottomHud.luau  ← Speed text + XP bar
│       │   │   └── RightPanel.luau ← Custom Speed input + 2x promo
│       │   └── Modals/
│       │       ├── Manager.luau    ← Open/Close/Toggle tất cả modal
│       │       ├── ShopModal.luau  ← Mua gamepass/products
│       │       ├── RebirthModal.luau
│       │       ├── CosmeticModal.luau ← Trails + Auras
│       │       ├── TeleportModal.luau
│       │       ├── CodeModal.luau  ← Nhập promo code
│       │       └── ReviveModal.luau
│       ├── CoreLoop/
│       └── Zones/
├── server/
│   └── Services/
│       ├── Core/
│       │   ├── DataService.luau        ← ProfileStore wrapper
│       │   └── LeaderboardService.luau
│       └── Gameplay/
│           ├── ProgressionService.luau ← Speed/XP/Level/Rebirth
│           ├── TreadmillService.luau   ← Touch detection treadmill
│           ├── TeleportService.luau
│           ├── RaceService.luau
│           └── StageCheckpointService.luau
└── shared/
    ├── Constants.luau         ← GetRequiredXP, GetMaxWalkSpeed, GetRebirthMultiplier...
    ├── Network/
    │   └── GamePackets.luau   ← ByteNet namespace "speedEscape"
    ├── Config/
    │   ├── Economy/Trails.luau, Auras.luau, Treadmills.luau...
    │   └── Stages.luau
    └── Util/
        ├── ServiceLocator.luau ← Dependency injection pattern
        └── Format.luau
```

### Packages
| Package | Version | Dùng cho |
|---------|---------|----------|
| Fusion | 0.2.0 | Reactive UI (Value, Computed, Tween, New, Children) |
| ByteNet | 0.6.0 | Binary networking (defineNamespace, definePacket) |
| Janitor | latest | Cleanup connections |
| ProfileStore | 1.0.3 | Data persistence |

---

## Patterns & Rules bắt buộc

### UI Pattern (Fusion 0.2.0)
```lua
-- Mọi state đều sống trong State.luau
State.myValue = Value(false)
State.myAnimation = Tween(State.myAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad))

-- Modal pattern chuẩn: Visible + GroupTransparency + slide 18px
New("CanvasGroup")({
    Visible = State.myModalMounted,
    GroupTransparency = Computed(function() return 1 - State.myModalAnimation:get() end),
    Position = Computed(function() return UDim2.fromOffset(960, 492 - (18 * State.myModalAnimation:get())) end),
})
```

### Shop-style Header Pattern (tất cả modal đều dùng)
```lua
New("Frame")({
    BackgroundColor3 = Color3.fromRGB(255, 205, 46),
    Size = UDim2.fromOffset(920, 90),  -- 740x90 cho modal nhỏ hơn
    ZIndex = 45,
    [Children] = {
        Theme.MakeCorner(18),
        Theme.MakeStroke(Color3.fromRGB(18, 18, 30), 4),
        Theme.MakeGradient(Color3.fromRGB(255, 238, 77), Color3.fromRGB(255, 162, 28), 0),
        Theme.MakeStudsPattern(0.86, 47),
        New("ImageLabel")({ Image = icon, Position = UDim2.fromOffset(20, 11), Size = UDim2.fromOffset(68, 68) }),
        Theme.MakeOutlineLabel({ Position = UDim2.fromOffset(100, 8), Size = UDim2.fromOffset(716, 74),
            Text = "Title", TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 54 }),
        New("TextButton")({ Position = UDim2.fromOffset(840, 12), Size = UDim2.fromOffset(66, 66), Text = "X",
            [Children] = { Theme.MakeCorner(10), Theme.MakeStroke(Color3.fromRGB(48, 8, 13), 4) }
        }),
    },
})
```

### Service Pattern
```lua
-- Init(): lấy dependencies
function MyService.Init()
    DataService = ServiceLocator.Get("DataService")
    ProgressionService = ServiceLocator.Get("ProgressionService")
end
-- Start(): bind events, bắt đầu logic
function MyService.Start()
    Players.PlayerAdded:Connect(...)
end
```

### Network Pattern (ByteNet)
```lua
-- GamePackets.luau — định nghĩa packet
myPacket = ByteNet.definePacket({ value = ByteNet.struct({ field = ByteNet.string }) })

-- Client gửi
GamePackets.myPacket.send({ field = "value" })

-- Server nhận
GamePackets.myPacket.listen(function(data, player) end)

-- Server gửi cho 1 player
GamePackets.myPacket.sendTo({ field = "value" }, player)
```

---

## Quy trình làm việc BẮT BUỘC

### ✅ ĐÚNG
1. Edit file `.luau` trong VSCode
2. Save → Rojo 7.7.0 tự động sync vào Roblox Studio
3. Test trong Studio

### ❌ SAI (không bao giờ làm)
- Dùng MCP `multi_edit` để edit trực tiếp trong Studio
- Edit trong Studio rồi mới về VSCode
- Lý do: Rojo chỉ sync **một chiều** (VSCode → Studio), edit trong Studio sẽ bị ghi đè mất

### Khi cần đọc code trong Studio
- Dùng `mcp__Roblox_Studio__script_read` để đọc
- Sau đó dùng `Write` tool để ghi về file `.luau` tương ứng

### Path mapping (Studio → VSCode)
| Roblox Studio path | VSCode file path |
|---|---|
| `StarterPlayer.StarterPlayerScripts.Client.Controllers.HUD.*` | `src/client/Controllers/HUD/*.luau` |
| `ServerScriptService.Server.Services.*` | `src/server/Services/*.luau` |
| `ReplicatedStorage.Shared.*` | `src/shared/*.luau` |

---

## Design canvas
- Kích thước thiết kế: **1920×1080**
- Scale tự động qua `UIScale` + `State.viewportScale`
- Modals căn giữa tại **(960, 492)**

---

## MCP Tools (Roblox Studio)
Tất cả tools đã được cấp quyền trong `.claude/settings.local.json`:
- `script_read` — đọc script từ Studio
- `multi_edit` — chỉ dùng để đọc/verify, KHÔNG edit
- `execute_luau` — chạy Luau code trong Studio
- `get_console_output` — xem output console
- `screen_capture` — chụp màn hình Studio
- `start_stop_play` — bắt đầu/dừng playtest

---

## Thông tin quan trọng khác
- **Design canvas:** 1920×1080, scale qua UIScale
- **DataStore:** ProfileStore 1.0.3 (không dùng DataStore trực tiếp)
- **Anti-cheat:** Mọi logic gameplay phải validate server-side
- **RemoteEvent:** Dùng ByteNet thay vì RemoteEvent thô
