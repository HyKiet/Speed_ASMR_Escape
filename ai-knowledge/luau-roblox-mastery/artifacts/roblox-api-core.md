# Roblox Engine API — Core Classes
> Source: Official Roblox Creator Docs (github.com/Roblox/creator-docs)

---

## Instance
Inherits: Object | Tags: NotCreatable, NotBrowsable
> Base class for ALL objects in the DataModel tree.

### Properties
- Archivable: boolean — Can be cloned/saved
- Capabilities: SecurityCapabilities — Script capabilities for sandboxing
- Name: string — Non-unique identifier (max 100 chars)
- Parent: Instance — Hierarchical parent (set last for replication optimization!)
- Sandboxed: boolean — Enables sandboxed container
- UniqueId: UniqueId [RobloxScriptSecurity read]

### Methods
- AddTag(tag: string) → () — Apply a CollectionService tag
- ClearAllChildren() → () — Destroy all children + descendants
- Clone() → Instance — Deep copy (respects Archivable)
- Destroy() → () — Set Parent=nil, lock Parent, disconnect all, destroy children
- FindFirstAncestor(name: string) → Instance? — Search ancestors by Name
- FindFirstAncestorOfClass(className: string) → Instance? — Search ancestors by ClassName
- FindFirstAncestorWhichIsA(className: string) → Instance? — Search ancestors by IsA()
- FindFirstChild(name: string, recursive: boolean = false) → Instance? — Find child by Name
- FindFirstChildOfClass(className: string) → Instance? — Find child by exact ClassName
- FindFirstChildWhichIsA(className: string, recursive: boolean = false) → Instance? — Find child by IsA()
- FindFirstDescendant(name: string) → Instance? — Find descendant by Name
- GetActor() → Actor? — Get associated Actor
- GetAttribute(attribute: string) → Variant — Get custom attribute value
- GetAttributeChangedSignal(attribute: string) → RBXScriptSignal — Signal for specific attribute change
- GetAttributes() → Dictionary — All attributes as {name: value}
- GetChildren() → {Instance} — Array of direct children
- GetDescendants() → {Instance} — Array of ALL descendants (recursive)
- GetFullName() → string — Ancestry path string (e.g. "Workspace.Model.Part")
- GetTags() → {string} — All CollectionService tags
- HasTag(tag: string) → boolean — Check if tag exists
- IsA(className: string) → boolean — Check class inheritance (INHERITED from Object)
- IsAncestorOf(descendant: Instance) → boolean
- IsDescendantOf(ancestor: Instance) → boolean
- QueryDescendants(selector: string) → {Instance} — CSS-like selector query (NEW!)
- RemoveTag(tag: string) → ()
- SetAttribute(attribute: string, value: Variant) → ()
- WaitForChild(childName: string, timeOut: double?) → Instance [Yields] — Wait for child to exist

### Events
- AncestryChanged(child: Instance, parent: Instance) — Parent chain changed
- AttributeChanged(attribute: string) — Any attribute changed
- ChildAdded(child: Instance) — Direct child added
- ChildRemoved(child: Instance) — Direct child removed
- DescendantAdded(descendant: Instance) — Any descendant added
- DescendantRemoving(descendant: Instance) — Before descendant removed
- Destroying() — Before this instance is destroyed

---

## DataModel (game)
Inherits: ServiceProvider > Instance | Tags: NotCreatable
> The root of the Roblox instance hierarchy. Accessed via `game`.

### Properties
- CreatorId: int64 [ReadOnly] — Creator's UserId or GroupId
- CreatorType: CreatorType [ReadOnly] — User or Group
- GameId: int64 [ReadOnly] — Universe ID
- Genre: Genre [ReadOnly]
- JobId: string [ReadOnly] — Server job GUID
- PlaceId: int64 [ReadOnly] — Current place ID
- PlaceVersion: int [ReadOnly] — Published version number
- PrivateServerId: string [ReadOnly] — Private/reserved server ID
- PrivateServerOwnerId: int64 [ReadOnly]
- Workspace: Workspace [ReadOnly]

### Methods
- GetService(className: string) → Instance — Get or create a service
- BindToClose(callback: () → ()) → () — Run function on server shutdown
- SetPlaceId(placeId: int64) → () — For testing
- SetUniverseId(universeId: int64) → () — For testing

### Events
- GraphicsQualityChangeRequest(betterQuality: boolean) — User changed quality
- Loaded() — Game fully loaded
- ServiceAdded(service: Instance)
- ServiceRemoving(service: Instance)

---

## Workspace
Inherits: WorldRoot > Model > PVInstance > Instance | Tags: Service, NotCreatable
> Contains all 3D objects in the game world.

### Key Properties
- AllowThirdPartySales: boolean — Default false
- CurrentCamera: Camera — Active camera
- DistributedGameTime: double [ReadOnly] — Time since game start
- FallenPartsDestroyHeight: float — Y-level to destroy parts (default -500)
- Gravity: float — Gravitational acceleration (default 196.2)
- StreamingEnabled: boolean — Enable instance streaming
- StreamingMinRadius: int — Min streaming radius
- StreamingTargetRadius: int — Target streaming radius
- Terrain: Terrain [ReadOnly]
- Retries: int — Not commonly used

### Methods (inherited from WorldRoot)
- Blockcast(cframe: CFrame, size: Vector3, direction: Vector3, params: RaycastParams?) → RaycastResult?
- Raycast(origin: Vector3, direction: Vector3, params: RaycastParams?) → RaycastResult?
- Shapecast(part: BasePart, direction: Vector3, params: RaycastParams?) → RaycastResult?
- Spherecast(position: Vector3, radius: float, direction: Vector3, params: RaycastParams?) → RaycastResult?
- GetPartBoundsInBox(cframe: CFrame, size: Vector3, params: OverlapParams?) → {BasePart}
- GetPartBoundsInRadius(position: Vector3, radius: float, params: OverlapParams?) → {BasePart}
- GetPartsInPart(part: BasePart, params: OverlapParams?) → {BasePart}

---

## Players
Inherits: Instance | Tags: Service, NotCreatable
> Manages connected players.

### Properties
- CharacterAutoLoads: boolean — Auto-spawn characters (default true)
- MaxPlayers: int [ReadOnly] — Server capacity
- RespawnTime: float — Respawn delay (default 5.0)

### Methods
- GetPlayerByUserId(userId: int64) → Player? — Find connected player by UserId
- GetPlayerFromCharacter(character: Model) → Player? — Find player from character Model
- GetPlayers() → {Player} — All connected players
- CreateHumanoidModelFromUserId(userId: int64) → Model [Yields] — Generate character model
- GetHumanoidDescriptionFromUserId(userId: int64) → HumanoidDescription [Yields]
- GetNameFromUserIdAsync(userId: int64) → string [Yields]
- GetUserIdFromNameAsync(userName: string) → int64 [Yields]
- GetUserThumbnailAsync(userId: int64, thumbnailType: ThumbnailType, thumbnailSize: ThumbnailSize) → (string, boolean) [Yields]
- BanAsync(config: table) → () [Yields] — Ban player(s)
- UnbanAsync(config: table) → () [Yields] — Unban player(s)

### Events
- PlayerAdded(player: Player) — Player joined
- PlayerRemoving(player: Player) — Player leaving (before cleanup)

---

## Player
Inherits: Instance | Tags: NotCreatable
> Represents a connected player.

### Key Properties
- AccountAge: int [ReadOnly] — Days since account creation
- Character: Model — Player's character model (nil if not spawned)
- CharacterAppearanceId: int64 — Avatar appearance override
- DisplayName: string [ReadOnly] — Display name
- FollowUserId: int64 [ReadOnly] — Who player followed to join
- GameplayPaused: boolean — Streaming gameplay pause state
- HasVerifiedBadge: boolean [ReadOnly]
- LocaleId: string [ReadOnly] — Player's locale
- MembershipType: MembershipType [ReadOnly] — None, Premium
- Name: string [ReadOnly] — Username (unique identifier)
- Team: Team — Current team
- TeamColor: BrickColor — Current team color
- UserId: int64 [ReadOnly] — Unique player ID (NEVER changes)
- ReplicationFocus: BasePart — Override streaming center

### Methods
- ClearCharacterAppearance() → () — Remove clothes/accessories
- DistanceFromCharacter(point: Vector3) → float — Distance from character to point
- GetMouse() → Mouse — [Client only, deprecated for UserInputService]
- GetNetworkPing() → double — Network latency in seconds
- HasAppearanceLoaded() → boolean
- Kick(message: string?) → () — Disconnect player
- LoadCharacter() → () — (Re)spawn character
- LoadCharacterAsync() → () [Yields]
- LoadCharacterWithHumanoidDescription(humanoidDescription: HumanoidDescription) → ()
- RequestStreamAroundAsync(position: Vector3, timeOut: double?) → () [Yields]

### Events
- CharacterAdded(character: Model) — Character spawned
- CharacterAppearanceLoaded(character: Model) — Avatar fully loaded
- CharacterRemoving(character: Model) — Character about to be removed

---

## Humanoid
Inherits: Instance | Tags: (none)
> Gives a Model character functionality (walking, health, death).

### Key Properties
- AutoJumpEnabled: boolean — Auto jump on mobile
- AutoRotate: boolean — Auto face movement direction
- BreakJointsOnDeath: boolean — Break joints when dead (default true)
- CameraOffset: Vector3 — Camera subject offset
- DisplayName: string — Overhead display name
- EvaluateStateMachine: boolean — Enable/disable internal physics
- FloorMaterial: Material [ReadOnly] — Current standing material
- Health: float — Current health [0, MaxHealth]
- HealthDisplayDistance: float — Health bar visibility distance
- HealthDisplayType: HumanoidHealthDisplayType — AlwaysOn/AlwaysOff/DisplayWhenDamaged
- HipHeight: float — Distance above ground for RootPart
- Jump: boolean — Trigger jump
- JumpHeight: float — Jump height in studs (when UseJumpPower=false)
- JumpPower: float — Jump force (when UseJumpPower=true, default 50)
- MaxHealth: float — Maximum health (default 100)
- MaxSlopeAngle: float — Max walkable slope (0-89, default 89)
- MoveDirection: Vector3 [ReadOnly] — Current movement direction (unit vector)
- NameDisplayDistance: float — Name visibility distance
- NameOcclusion: NameOcclusion — Name visibility through walls
- RigType: HumanoidRigType — R6 or R15
- RootPart: BasePart [ReadOnly] — HumanoidRootPart reference
- SeatPart: Seat [ReadOnly] — Currently sitting on
- Sit: boolean — Whether sitting
- UseJumpPower: boolean — Use JumpPower vs JumpHeight
- WalkSpeed: float — Movement speed (default 16)
- WalkToPart: BasePart — Walk target part
- WalkToPoint: Vector3 — Walk target position

### Methods
- AddAccessory(accessory: Accessory) → ()
- ChangeState(state: HumanoidStateType?) → ()
- EquipTool(tool: Tool) → ()
- GetAccessories() → {Accessory}
- GetAppliedDescription() → HumanoidDescription
- GetState() → HumanoidStateType
- GetStateEnabled(state: HumanoidStateType) → boolean
- Move(moveDirection: Vector3, relativeToCamera: boolean = false) → ()
- MoveTo(location: Vector3, part: BasePart?) → ()
- SetStateEnabled(state: HumanoidStateType, enabled: boolean) → ()
- TakeDamage(amount: float) → () — Subtracts from Health (respects ForceField)
- UnequipTools() → ()
- ApplyDescription(humanoidDescription: HumanoidDescription) → () [Yields]

### Events
- Died() — Health reached 0
- HealthChanged(health: float) — Health value changed
- Jumping(isActive: boolean) — Jump state changed
- MoveToFinished(reached: boolean) — MoveTo completed or timed out (8s default)
- Running(speed: float) — Running speed changed
- Seated(active: boolean, currentSeatPart: Seat)
- StateChanged(old: HumanoidStateType, new: HumanoidStateType)
- Touched(touchingPart: BasePart, humanoidPart: BasePart)

---

## RunService
Inherits: Instance | Tags: Service, NotCreatable
> Manages frame-by-frame game loop timing.

### Properties
(none commonly used)

### Methods
- BindToRenderStep(name: string, priority: int, callback: (dt: float) → ()) → () — [Client only]
- UnbindFromRenderStep(name: string) → ()
- IsClient() → boolean
- IsServer() → boolean
- IsStudio() → boolean
- IsRunning() → boolean
- IsEdit() → boolean

### Events
- Heartbeat(deltaTime: float) — After physics simulation (EVERY frame)
- PreAnimation(deltaTimeSim: float) — Before animation update
- PreRender(deltaTimeRender: float) — Before render [Client only] (replacement for RenderStepped)
- PreSimulation(deltaTimeSim: float) — Before physics step (replacement for Stepped)
- PostSimulation(deltaTimeSim: float) — After physics step
- RenderStepped(deltaTime: float) — [Client only, deprecated → use PreRender]
- Stepped(time: double, deltaTime: float) — [deprecated → use PreSimulation]

---

## Container Services (Simple)

### ReplicatedStorage
Inherits: Instance | Tags: Service, NotCreatable
> Shared container visible to both server and client. Use for ModuleScripts, RemoteEvents, shared assets.

### ServerScriptService
Inherits: Instance | Tags: Service, NotCreatable
> Server-only Script container. NOT visible to clients.

### ServerStorage
Inherits: Instance | Tags: Service, NotCreatable
> Server-only storage. NOT visible to clients.

### ReplicatedFirst
Inherits: Instance | Tags: Service, NotCreatable
> Content replicated to client FIRST (before anything else). Use for loading screens.
- Methods: RemoveDefaultLoadingScreen() → ()
- Events: RemoveDefaultLoadingGuiSignal()

### StarterGui
Inherits: BasePlayerGui > Instance | Tags: Service, NotCreatable
> Template for PlayerGui. Contents copied to each player on spawn.
- Methods: SetCoreGuiEnabled(coreGuiType: CoreGuiType, enabled: boolean) → ()
- Methods: GetCoreGuiEnabled(coreGuiType: CoreGuiType) → boolean
- Properties: ResetPlayerGuiOnSpawn: boolean (default true)
- Properties: ScreenOrientation: ScreenOrientation

### StarterPack
Inherits: Instance | Tags: Service, NotCreatable
> Template for Backpack. Tools placed here are given to every player on spawn.

### StarterPlayer
Inherits: Instance | Tags: Service, NotCreatable
> Default character properties. Contains StarterPlayerScripts and StarterCharacterScripts.
- Key Properties: CameraMode, CameraMinZoomDistance, CameraMaxZoomDistance
- Key Properties: CharacterJumpHeight, CharacterJumpPower, CharacterMaxSlopeAngle, CharacterWalkSpeed
- Key Properties: AutoJumpEnabled, DevCameraOcclusionMode, DevComputerMovementMode, DevTouchMovementMode
- Key Properties: HealthDisplayDistance, NameDisplayDistance, LoadCharacterLayeredClothing

### Folder
Inherits: Instance
> Organizational container. No unique functionality — purely for hierarchy organization.

### Debris
Inherits: Instance | Tags: Service, NotCreatable
> Schedules automatic instance destruction after a delay.
- Methods: AddItem(item: Instance, lifetime: double = 10) → ()

### Teams
Inherits: Instance | Tags: Service, NotCreatable
> Container for Team objects.
- Methods: GetTeams() → {Team}

### Team
Inherits: Instance
- Properties: AutoAssignable: boolean, TeamColor: BrickColor
- Methods: GetPlayers() → {Player}
- Events: PlayerAdded(player: Player), PlayerRemoved(player: Player)
