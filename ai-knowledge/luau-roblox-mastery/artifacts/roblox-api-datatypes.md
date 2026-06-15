# Roblox Engine API — Data Types & Enums
> Source: Official Roblox Creator Docs

---

## CFrame
> Position + Orientation (4x4 matrix, 3x3 rotation + Vector3 position).

### Constructors
- CFrame.new() — Identity (origin, no rotation)
- CFrame.new(x: float, y: float, z: float) — Position only
- CFrame.new(position: Vector3) — Position only
- CFrame.new(position: Vector3, lookAt: Vector3) — Position + look at point
- CFrame.new(x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22) — Full rotation matrix
- CFrame.lookAt(at: Vector3, lookAt: Vector3, up: Vector3 = Vector3.yAxis) — **PREFERRED** constructor
- CFrame.lookAlong(at: Vector3, direction: Vector3, up: Vector3 = Vector3.yAxis)
- CFrame.fromEulerAngles(rx, ry, rz, order: RotationOrder = XYZ) — Alias: Angles()
- CFrame.fromEulerAnglesXYZ(rx, ry, rz) — Same as Angles()
- CFrame.fromEulerAnglesYXZ(rx, ry, rz) — Alias: fromOrientation()
- CFrame.fromAxisAngle(axis: Vector3, angle: float) — Rotate around axis
- CFrame.fromMatrix(pos: Vector3, vX: Vector3, vY: Vector3, vZ: Vector3?)

### Properties
- Position: Vector3 [ReadOnly]
- Rotation: CFrame [ReadOnly] — Rotation-only CFrame (no translation)
- X, Y, Z: float [ReadOnly] — Position components
- LookVector: Vector3 [ReadOnly] — -Z axis (forward)
- RightVector: Vector3 [ReadOnly] — +X axis
- UpVector: Vector3 [ReadOnly] — +Y axis
- XVector, YVector, ZVector: Vector3 [ReadOnly] — Column vectors

### Methods
- Inverse() → CFrame
- Lerp(goal: CFrame, alpha: float) → CFrame — Linear interpolation
- PointToObjectSpace(v3: Vector3) → Vector3 — World → local
- PointToWorldSpace(v3: Vector3) → Vector3 — Local → world
- VectorToObjectSpace(v3: Vector3) → Vector3 — Direction world → local
- VectorToWorldSpace(v3: Vector3) → Vector3 — Direction local → world
- ToObjectSpace(cf: CFrame) → CFrame — Relative CFrame
- ToWorldSpace(cf: CFrame) → CFrame
- ToEulerAngles(order: RotationOrder?) → (float, float, float)
- ToEulerAnglesXYZ() → (float, float, float)
- ToEulerAnglesYXZ() → (float, float, float) — Alias: ToOrientation()
- ToAxisAngle() → (Vector3, float)
- GetComponents() → (x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22)

### Operators
- CFrame * CFrame → CFrame — Compose transformations
- CFrame * Vector3 → Vector3 — Transform point
- CFrame + Vector3 → CFrame — Translate
- CFrame - Vector3 → CFrame — Translate

---

## Vector3
### Constructors
- Vector3.new(x?: float, y?: float, z?: float) — Default (0,0,0)
- Vector3.one — (1,1,1)
- Vector3.zero — (0,0,0)
- Vector3.xAxis, yAxis, zAxis — Unit vectors

### Properties
- X, Y, Z: float [ReadOnly]
- Magnitude: float [ReadOnly] — Length
- Unit: Vector3 [ReadOnly] — Normalized (length=1)

### Methods
- Abs() → Vector3
- Angle(other: Vector3, axis: Vector3?) → float — Radians
- Ceil() → Vector3
- Cross(other: Vector3) → Vector3
- Dot(other: Vector3) → float
- Floor() → Vector3
- FuzzyEq(other: Vector3, epsilon: float = 1e-5) → boolean
- Lerp(goal: Vector3, alpha: float) → Vector3
- Max(others: ...Vector3) → Vector3 — Component-wise max
- Min(others: ...Vector3) → Vector3 — Component-wise min
- Sign() → Vector3

### Operators
- Vector3 + Vector3, - Vector3, * (float|Vector3), / (float|Vector3)

---

## Vector2
- Same pattern as Vector3 but 2D (X, Y)
- Vector2.new(x?: float, y?: float), Vector2.one, Vector2.zero, Vector2.xAxis, Vector2.yAxis
- Methods: same as Vector3 (Abs, Angle, Cross, Dot, Lerp, etc.)

---

## UDim / UDim2

### UDim
- UDim.new(Scale: float, Offset: int) — Scale (0-1 fraction) + Offset (pixels)
- Properties: Scale, Offset

### UDim2
> 2D Size/Position for GUI.
- UDim2.new(xScale: float, xOffset: int, yScale: float, yOffset: int)
- UDim2.fromScale(xScale: float, yScale: float) — Offset=0
- UDim2.fromOffset(xOffset: int, yOffset: int) — Scale=0
- Properties: X: UDim, Y: UDim, Width: UDim, Height: UDim
- Methods: Lerp(goal: UDim2, alpha: float) → UDim2

---

## Color3
### Constructors
- Color3.new(r?: float, g?: float, b?: float) — [0,1] components
- Color3.fromRGB(r: int, g: int, b: int) — [0,255] components (**MOST COMMON**)
- Color3.fromHSV(h: float, s: float, v: float) — [0,1] components
- Color3.fromHex(hex: string) — e.g. "#FF6A00"

### Properties
- R, G, B: float [ReadOnly] — [0,1]

### Methods
- Lerp(goal: Color3, alpha: float) → Color3
- ToHSV() → (float, float, float)
- ToHex() → string

---

## BrickColor
> Legacy color system (725 named colors). Use Color3 for new work.
- BrickColor.new(name: string) — e.g. "Bright red"
- BrickColor.new(number: int) — By color number
- BrickColor.new(r: float, g: float, b: float) — Rounds to nearest BrickColor
- BrickColor.Random() → BrickColor
- Properties: Name, Number, r, g, b, Color (Color3)

---

## ColorSequence
> Color gradient for particles, UIGradient, etc.
- ColorSequence.new(c: Color3) — Single color
- ColorSequence.new(c0: Color3, c1: Color3) — Two-point gradient
- ColorSequence.new(keypoints: {ColorSequenceKeypoint})
- ColorSequenceKeypoint.new(time: float, color: Color3) — time ∈ [0,1]

## NumberSequence
> Number gradient (e.g. particle size/transparency over lifetime).
- NumberSequence.new(val: float) — Constant
- NumberSequence.new(val0: float, val1: float) — Two-point
- NumberSequence.new(keypoints: {NumberSequenceKeypoint})
- NumberSequenceKeypoint.new(time: float, value: float, envelope: float = 0)

## NumberRange
- NumberRange.new(value: float) — Min=Max=value
- NumberRange.new(min: float, max: float)
- Properties: Min, Max

---

## Ray
> Origin + Direction. Used in raycasting.
- Ray.new(origin: Vector3, direction: Vector3)
- Properties: Origin: Vector3, Direction: Vector3, Unit: Ray
- Methods: ClosestPoint(point: Vector3) → Vector3, Distance(point: Vector3) → float

> ⚠️ For raycasting, use `Workspace:Raycast()` instead of Ray objects directly.

## RaycastParams
> Configure raycast behavior.
- RaycastParams.new()
- FilterDescendantsInstances: {Instance} — Whitelist/blacklist
- FilterType: RaycastFilterType — Include, Exclude (default Exclude)
- IgnoreWater: boolean
- CollisionGroup: string
- RespectCanCollide: boolean
- BruteForceAllSlow: boolean

## RaycastResult (Returned by Workspace:Raycast)
- Distance: float, Instance: BasePart, Material: Material
- Normal: Vector3 — Surface normal at hit point
- Position: Vector3 — Hit point

## OverlapParams
> Configure spatial queries (GetPartBoundsInBox, etc.)
- OverlapParams.new()
- FilterDescendantsInstances: {Instance}
- FilterType: RaycastFilterType
- CollisionGroup: string
- MaxParts: int
- RespectCanCollide: boolean
- BruteForceAllSlow: boolean

---

## Region3
- Region3.new(min: Vector3, max: Vector3)
- Properties: CFrame, Size
- Methods: ExpandToGrid(resolution: float) → Region3

## Rect
- Rect.new(min: Vector2, max: Vector2) or Rect.new(minX, minY, maxX, maxY)
- Properties: Min, Max, Width, Height

---

## TweenInfo
- TweenInfo.new(time: float?, easingStyle: EasingStyle?, easingDirection: EasingDirection?, repeatCount: int?, reverses: boolean?, delayTime: float?)
- Defaults: 1, Quad, Out, 0, false, 0

## PathWaypoint
- PathWaypoint.new(position: Vector3, action: PathWaypointAction)
- Properties: Position, Action, Label

---

## Key Enums Reference

### EasingStyle
Linear, Sine, Back, Quad, Quart, Quint, Bounce, Elastic, Exponential, Circular, Cubic

### EasingDirection
In, Out, InOut

### Material (Partial — Most Used)
Plastic, SmoothPlastic, Neon, Glass, Wood, WoodPlanks, Marble, Granite, Brick, Cobblestone, Concrete, Sandstone, Rock, Basalt, Slate, Metal, CorrodedMetal, DiamondPlate, Foil, Grass, LeafyGrass, Sand, Mud, Ground, Snow, Ice, Glacier, Asphalt, Pavement, Fabric, Leather, Rubber, CeramicTiles, Cardboard, Carpet, Salt, Limestone, Plaster, Air, Water, ForceField, CrackedLava, Pebble

### KeyCode (Most Used)
W, A, S, D, Q, E, R, F, G, T, Space, LeftShift, RightShift, LeftControl, RightControl, Tab, Return, Escape, Backspace, Delete, Up, Down, Left, Right, Zero–Nine, F1–F12, LeftAlt, RightAlt

### UserInputType
MouseButton1, MouseButton2, MouseButton3, MouseWheel, MouseMovement, Touch, Keyboard, Focus, Accelerometer, Gyro, Gamepad1–Gamepad8, TextInput, InputMethod, None

### HumanoidStateType
Running, Jumping, Freefall, FallingDown, Landed, Swimming, Climbing, Seated, Dead, Physics, GettingUp, StrafingNoPhysics, Ragdoll, PlatformStanding, None

### RenderPriority (for BindToRenderStep)
First = 0, Input = 100, Camera = 200, Character = 300, Last = 2000

### SortOrder
Name, LayoutOrder, Custom

### FillDirection
Horizontal, Vertical

### AutomaticSize
None, X, Y, XY

### Font (Legacy — use FontFace)
Legacy, Arial, ArialBold, SourceSans, SourceSansBold, SourceSansLight, SourceSansItalic, SourceSansSemibold, Gotham, GothamMedium, GothamBold, GothamBlack, Ubuntu, Bangers, FredokaOne, BuilderSans, BuilderSansMedium, BuilderSansBold, BuilderSansExtraBold

### CoreGuiType
PlayerList, Health, Backpack, Chat, All, EmotesMenu, SelfView, Captures

### AnimationPriority (Highest wins)
Core = 1000, Idle = 0, Movement = 1, Action = 2, Action2 = 3, Action3 = 4, Action4 = 5

### ProductPurchaseDecision
PurchaseGranted, NotProcessedYet

### RigType
R6, R15

### ScreenInsets
None, TopbarSafeInsets, DeviceSafeInsets, CoreUISafeInsets

### ModelStreamingMode
Default, Atomic, Persistent, PersistentPerPlayer, Nonatomic
