# Roblox Engine API — Scripting & Communication
> Source: Official Roblox Creator Docs

---

## Script Types

### Script
Inherits: BaseScript > LuaSourceContainer > Instance
> Runs Luau on the server. Must be in ServerScriptService, Workspace, or similar server containers.
- Source: string [PluginSecurity] — Script code
- RunContext: RunContext — Legacy, Server, Client (NEW: allows Script to run on client!)
- Enabled: boolean — Whether script runs

### LocalScript
Inherits: BaseScript > LuaSourceContainer > Instance
> Runs Luau on the client only. Must be in StarterPlayerScripts, StarterCharacterScripts, StarterGui, or PlayerGui.
- Source: string [PluginSecurity]
- Enabled: boolean

### ModuleScript
Inherits: LuaSourceContainer > Instance
> Returns a single value (usually a table). Cached after first require().
- Source: string [PluginSecurity]
> Usage: `local MyModule = require(path.to.ModuleScript)`
> ⚠️ Module code runs ONCE, subsequent require() returns cached result.

---

## Remote Communication (Client ↔ Server)

### RemoteEvent
Inherits: BaseRemoteEvent > Instance
> One-way communication between client and server.

#### Server-side:
- FireClient(player: Player, ...args) → () — Send to specific client
- FireAllClients(...args) → () — Send to ALL clients
- OnServerEvent: RBXScriptSignal(player: Player, ...args) — Listen from any client

#### Client-side:
- FireServer(...args) → () — Send to server
- OnClientEvent: RBXScriptSignal(...args) — Listen from server

### UnreliableRemoteEvent
Inherits: BaseRemoteEvent > Instance
> Like RemoteEvent but packets may be dropped. Use for frequent updates (position, effects).
> Same API as RemoteEvent. Better performance, no guaranteed delivery.

### RemoteFunction
Inherits: Instance
> Two-way communication with return value. ⚠️ YIELDS until response!

#### Server-side:
- InvokeClient(player: Player, ...args) → ...returns [Yields] — ⚠️ DANGEROUS: client can hang server
- OnServerInvoke: (player: Player, ...args) → ...returns — Callback, MUST return value

#### Client-side:
- InvokeServer(...args) → ...returns [Yields] — Call server and wait for response
- OnClientInvoke: (...args) → ...returns — Callback

> ⚠️ Best Practice: NEVER use InvokeClient. Use RemoteEvent for server→client, RemoteFunction only for client→server.

---

## Local Communication

### BindableEvent
Inherits: Instance
> Same-context event (server↔server or client↔client).
- Fire(...args) → ()
- Event: RBXScriptSignal(...args)

### BindableFunction
Inherits: Instance
> Same-context function call with return.
- Invoke(...args) → ...returns
- OnInvoke: (...args) → ...returns — Callback

---

## DataStoreService
Inherits: Instance | Tags: Service, NotCreatable
> Persistent data storage (server only).

### Methods
- GetDataStore(name: string, scope: string?, options: DataStoreOptions?) → DataStore
- GetOrderedDataStore(name: string, scope: string?) → OrderedDataStore
- GetGlobalDataStore() → GlobalDataStore
- ListDataStoresAsync(prefix: string?, pageSize: int?, cursor: string?) → DataStoreListingPages [Yields]

---

## GlobalDataStore
Inherits: Instance | Tags: NotCreatable
> Base interface for key-value data stores.

### Methods
- GetAsync(key: string, options: DataStoreGetOptions?) → (Variant, DataStoreKeyInfo) [Yields]
- SetAsync(key: string, value: Variant, userIds: {int64}?, options: DataStoreSetOptions?) → string [Yields]
- UpdateAsync(key: string, transformFunction: (currentValue: Variant, keyInfo: DataStoreKeyInfo) → (Variant, {int64}?, {}?)) → (Variant, DataStoreKeyInfo) [Yields]
- RemoveAsync(key: string) → (Variant, DataStoreKeyInfo) [Yields]
- IncrementAsync(key: string, delta: int?, userIds: {int64}?, options: DataStoreIncrementOptions?) → Variant [Yields]

> ⚠️ UpdateAsync is the SAFEST method — prevents race conditions.
> ⚠️ Rate limits: 60 + numPlayers × 10 requests per minute.

---

## OrderedDataStore
Inherits: GlobalDataStore
> Like DataStore but values must be integers. Can sort/paginate.
- GetSortedAsync(ascending: boolean, pageSize: int, minValue: int?, maxValue: int?) → DataStorePages [Yields]

---

## MemoryStoreService
Inherits: Instance | Tags: Service, NotCreatable
> In-memory data store for temporary data (leaderboards, matchmaking). Data expires.

### Methods
- GetHashMap(name: string) → MemoryStoreHashMap
- GetQueue(name: string, invisibilityTimeout: int?) → MemoryStoreQueue
- GetSortedMap(name: string) → MemoryStoreSortedMap

### MemoryStoreHashMap
- GetAsync(key: string) → Variant [Yields]
- SetAsync(key: string, value: Variant, expiration: int) → boolean [Yields]
- UpdateAsync(key: string, transformFunction, expiration: int) → Variant [Yields]
- RemoveAsync(key: string) → () [Yields]

### MemoryStoreSortedMap
- GetAsync(key: string) → (Variant, string) [Yields]
- SetAsync(key: string, value: Variant, expiration: int, sortKey: Variant?) → boolean [Yields]
- GetRangeAsync(direction: SortDirection, count: int, exclusiveLowerBound: Variant?, exclusiveUpperBound: Variant?) → {{key: string, value: Variant, sortKey: Variant}} [Yields]
- UpdateAsync(key: string, transformFunction, expiration: int) → Variant [Yields]
- RemoveAsync(key: string) → () [Yields]

### MemoryStoreQueue
- AddAsync(value: Variant, expiration: int, priority: float?) → () [Yields]
- ReadAsync(count: int, allOrNothing: boolean?, waitTimeout: float?) → ({any}, string) [Yields]
- RemoveAsync(id: string) → () [Yields]

---

## HttpService
Inherits: Instance | Tags: Service, NotCreatable
> HTTP requests + JSON utility. ⚠️ Must enable in Game Settings > Security.

### Methods
- GetAsync(url: string, nocache: boolean?, headers: table?) → string [Yields]
- PostAsync(url: string, data: string, contentType: HttpContentType?, compress: boolean?, headers: table?) → string [Yields]
- RequestAsync(requestOptions: table) → table [Yields] — Full control: {Url, Method, Headers, Body}
- JSONEncode(input: Variant) → string — Table → JSON string
- JSONDecode(input: string) → Variant — JSON string → Table
- GenerateGUID(wrapInCurlyBraces: boolean = true) → string
- UrlEncode(input: string) → string

---

## MessagingService
Inherits: Instance | Tags: Service, NotCreatable
> Cross-server messaging (between game servers).

### Methods
- PublishAsync(topic: string, message: Variant) → () [Yields]
- SubscribeAsync(topic: string, callback: (message: {Data: Variant, Sent: int64}) → ()) → RBXScriptConnection [Yields]

> ⚠️ Message size limit: 1KB. 150 + 60*numPlayers messages/minute.

---

## CollectionService
Inherits: Instance | Tags: Service, NotCreatable
> Tag-based instance management system.

### Methods
- AddTag(instance: Instance, tag: string) → ()
- RemoveTag(instance: Instance, tag: string) → ()
- HasTag(instance: Instance, tag: string) → boolean
- GetTagged(tag: string) → {Instance} — All instances with tag
- GetTags(instance: Instance) → {string}
- GetInstanceAddedSignal(tag: string) → RBXScriptSignal(instance: Instance)
- GetInstanceRemovedSignal(tag: string) → RBXScriptSignal(instance: Instance)

> 💡 Pattern: Use for component systems — tag objects, then manage them with signals.

---

## UserInputService
Inherits: Instance | Tags: Service, NotCreatable
> Client-only input detection.

### Key Properties
- GamepadEnabled: boolean [ReadOnly]
- KeyboardEnabled: boolean [ReadOnly]
- MouseEnabled: boolean [ReadOnly]
- TouchEnabled: boolean [ReadOnly]
- GyroscopeEnabled: boolean [ReadOnly]
- AccelerometerEnabled: boolean [ReadOnly]
- MouseBehavior: MouseBehavior — Default, LockCenter, LockCurrentPosition
- MouseDeltaSensitivity: float
- MouseIconEnabled: boolean

### Key Methods
- GetMouseLocation() → Vector2 — Mouse position (accounts for GUI inset)
- IsKeyDown(keyCode: KeyCode) → boolean
- IsMouseButtonPressed(mouseButton: UserInputType) → boolean
- IsGamepadButtonDown(gamepadNum: UserInputType, gamepadKeyCode: KeyCode) → boolean
- GetKeysPressed() → {InputObject}
- GetMouseButtonsPressed() → {InputObject}

### Key Events
- InputBegan(input: InputObject, gameProcessedEvent: boolean)
- InputChanged(input: InputObject, gameProcessedEvent: boolean)
- InputEnded(input: InputObject, gameProcessedEvent: boolean)
- JumpRequest() — Player wants to jump
- MouseWheelForward(input: InputObject)
- MouseWheelBackward(input: InputObject)
- TouchStarted(touch: InputObject, gameProcessedEvent: boolean)
- TouchMoved(touch: InputObject, gameProcessedEvent: boolean)
- TouchEnded(touch: InputObject, gameProcessedEvent: boolean)

> 💡 Check `gameProcessedEvent` to avoid handling input already consumed by UI.

---

## ContextActionService
Inherits: Instance | Tags: Service, NotCreatable
> Bind actions to input. Better for game-specific keybinds (can stack/override).

### Methods
- BindAction(actionName: string, functionToBind: (actionName: string, state: UserInputState, inputObject: InputObject) → Enum.ContextActionResult?, createTouchButton: boolean, ...inputTypes: (KeyCode | UserInputType)) → ()
- UnbindAction(actionName: string) → ()
- BindActionAtPriority(actionName, func, createTouchButton, priority: int, ...inputTypes) → ()
- GetButton(actionName: string) → ImageButton? — Get created touch button
- SetDescription(actionName: string, description: string) → ()
- SetImage(actionName: string, image: string) → ()
- SetPosition(actionName: string, position: UDim2) → ()
- SetTitle(actionName: string, title: string) → ()
- GetBoundActionInfo(actionName: string) → table
- GetAllBoundActionInfo() → table

---

## TweenService
Inherits: Instance | Tags: Service, NotCreatable
> Animate property changes smoothly.

### Methods
- Create(instance: Instance, tweenInfo: TweenInfo, propertyTable: table) → Tween
- GetValue(alpha: float, easingStyle: EasingStyle, easingDirection: EasingDirection) → float

### TweenInfo (DataType, not Instance)
> Constructor: TweenInfo.new(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)
- time: float = 1 — Duration in seconds
- easingStyle: EasingStyle = Quad — Linear, Sine, Back, Bounce, Elastic, Exponential, Circular, Cubic, Quad, Quart, Quint
- easingDirection: EasingDirection = Out — In, Out, InOut
- repeatCount: int = 0 — -1 for infinite
- reverses: boolean = false
- delayTime: float = 0

### Tween
Inherits: TweenBase > Instance
- Methods: Play(), Pause(), Cancel()
- Events: Completed(playbackState: PlaybackState)
- Properties: PlaybackState: PlaybackState [ReadOnly], TweenInfo: TweenInfo [ReadOnly]

> 💡 Tweenable types: number, boolean, CFrame, Rect, Color3, UDim, UDim2, Vector2, Vector2int16, Vector3, EnumItem, NumberSequence, ColorSequence
