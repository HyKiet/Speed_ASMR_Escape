# Roblox Engine Reference Index

Last Updated: 2026-04-24
Primary: https://create.roblox.com/docs/en-us/reference/engine
Mirror: https://robloxapi.github.io/ref/index.html

## Coverage Snapshot (from official and mirror catalogs)
- Classes: 653+ official listing, 800+ mirror listing (includes internal/extended visibility).
- Data types: 45+ official listing.
- Enums: 500+ official listing.
- Globals/Libraries: available under engine reference sections.

## Core Domains For BrainrotRNG
1. Networking and replication
   - RemoteEvent, RemoteFunction, UnreliableRemoteEvent
   - ReplicatedStorage, ReplicatedFirst, ServerScriptService
2. Player and character
   - Players, Player, Humanoid, Animator, AnimationTrack
3. Physics and hit detection
   - Workspace, WorldRoot queries, constraints, raycasts/casts
4. UI and interaction
   - ScreenGui, GuiObject, constraints/layout classes, input services
5. VFX/Audio
   - ParticleEmitter, Beam, Trail, Lighting effects, SoundService
6. Data and persistence
   - DataStoreService, MemoryStoreService, MessagingService

## Deprecated-To-Modern Migration Notes
- Replace BodyMover family with modern constraints/forces where applicable.
- Prefer explicit world query APIs for hit detection over touch-only logic.
- Validate all client-sent state changes on server.

## How To Use This Index
- Start with official class page for signatures.
- Use mirror update log to detect recent add/remove/change.
- Record confirmed migration notes in playbooks and quality gates.