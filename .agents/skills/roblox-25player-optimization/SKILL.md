---
name: roblox-25player-optimization
description: Guidelines, patterns, and best practices for optimizing Roblox server performance, networking, memory, and code execution for 25+ concurrent players in Luau.
---

# Roblox Server Optimization Skill (25 Players Concurrent)

This skill provides actionable design principles, architecture patterns, and optimization rules for maintaining high server FPS (60 Hz), low network bandwidth, and efficient memory usage under heavy 25-player concurrent loads on Roblox Luau engine.

---

## 1. Network Bandwidth & Serialization (ByteNet)

### Rules:
- **Binary Serialization:** Never use bare `RemoteEvent` or `UnreliableRemoteEvent` for high-frequency data. Use **ByteNet** struct definitions for compact binary payloads.
- **Throttling & Rate-limiting:** Limit state updates to 10-20 Hz instead of 60 Hz (Heartbeat). For fast-changing stats like Speed or XP, batch updates and send periodic sync packets.
- **Delta Sync:** Only send data when values actually change beyond a set threshold.
- **Selective & Spatial Broadcasting:** Use `sendTo` for targeted updates rather than broadcasting to all 25 players when only 1 player or surrounding players need the data.

---

## 2. Server CPU Execution & Loop Architecture

### Rules:
- **Centralized Batch Loops:** Never create per-player or per-object `task.spawn` / `while true do` loops. Maintain a single manager loop per service iterating over registered player data arrays.
- **Frame Staggering:** If 25 players require periodic calculations (e.g., obby zone checks, passive treadmill gains), process a subset of players each frame:
  ```lua
  -- Example: Stagger processing 25 players across frames
  local playerIndex = 1
  RunService.Heartbeat:Connect(function()
      if #activePlayers == 0 then return end
      local player = activePlayers[playerIndex]
      if player then
          ProcessPlayerCheck(player)
      end
      playerIndex = (playerIndex % #activePlayers) + 1
  end)
  ```
- **Spatial Queries over Touch Spam:** Disable `CanTouch` on ambient/decorative parts. Use `workspace:GetPartBoundsInBox` or spatial grids at controlled intervals (e.g., 0.1s - 0.2s) instead of high-frequency `Touched` signals for multi-player triggers.

---

## 3. VFX, Audio & Physics Optimization

### Rules:
- **Client-Side Rendering (Server State, Client Visuals):** The server MUST NEVER instantiate ParticleEmitters, Auras, or Tweens for cosmetics. The server updates logical state (e.g., `EquippedTrail = "NeonRider"`), and clients render local visuals for visible players.
- **Distance & Zone Culling for Cosmetics:** For 25 players, 25 high-density aura particle emitters running concurrently will tank client FPS. Clients should cull or disable visual effects for characters farther than X studs or in different obby zones.
- **Character Collisions:** Set player characters to a custom Collision Group with self-collision DISABLED (`PlayerVsPlayerCollision = false`).

---

## 4. State & ProfileStore Memory Management

### Rules:
- **In-Memory Mutating, Auto-Save Persistence:** Never invoke `ProfileStore:Save()` or DataStore calls directly on gameplay actions (e.g., earning 1 XP or win). Mutate cached session tables, relying on ProfileStore's built-in auto-save intervals and `PlayerRemoving` events.
- **Clean Disconnections with Janitor:** Ensure all signal connections, dynamic parts, and temporary instances tied to a player are stored in a `Janitor` cleanup stack and cleaned upon `PlayerRemoving`.

---

## 5. 25-Player Performance Checklist

- [ ] ByteNet used for all high-frequency network packets.
- [ ] No `Touched` listeners on dynamic decorative items; `CanTouch = false`, `CanQuery = false` set on non-interactive parts.
- [ ] Player-to-Player character collisions disabled.
- [ ] Server does NOT handle visual particle emitters, cosmetic mesh creation, or UI tweens.
- [ ] ProfileStore handles state in memory with zero manual intermediate DataStore saves.
- [ ] `Janitor` destroys all event connections and per-player instances on exit.
