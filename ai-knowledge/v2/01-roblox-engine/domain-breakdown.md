# Roblox Engine Domain Breakdown

Last Updated: 2026-04-24

## 1. Runtime Foundation
- DataModel, Workspace, RunService, Debris
- Service access and lifecycle patterns

## 2. Networking
- RemoteEvent, RemoteFunction, UnreliableRemoteEvent
- Replication-aware architecture and payload contracts

## 3. Characters And Animation
- Players, Humanoid, Animator, AnimationTrack
- Marker-driven timing and state transitions

## 4. Physics And World Queries
- WorldRoot query methods, raycasts/casts, overlap patterns
- Constraints and modern movement force APIs

## 5. UI And Input
- ScreenGui and GuiObject family
- Input services and action mapping
- Layout constraints for multi-device behavior

## 6. Effects, Lighting, Audio
- Lighting pipeline and post effects
- Particle/Beam/Trail visual systems
- SoundService and Sound graph considerations

## 7. Persistence And Cross-Server
- DataStoreService
- MemoryStoreService
- MessagingService

## 8. Performance And Diagnostics
- Stats and profiling-related tooling
- Safe throttling and budget-aware design

## BrainrotRNG Priority Order
1. Networking security and server authority
2. Combat movement and world query correctness
3. Ability VFX timing and responsiveness
4. Data integrity for progression/economy
5. UI responsiveness across devices