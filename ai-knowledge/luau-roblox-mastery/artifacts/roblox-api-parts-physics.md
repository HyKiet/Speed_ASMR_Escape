# Roblox Engine API — Parts & Physics
> Source: Official Roblox Creator Docs

---

## BasePart (Abstract)
Inherits: PVInstance > Instance | Tags: NotCreatable
> Base class for all physical 3D objects.

### Key Properties
- Anchored: boolean — Immune to physics (default false)
- AssemblyAngularVelocity: Vector3 — Angular velocity of physics assembly
- AssemblyLinearVelocity: Vector3 — Linear velocity of physics assembly
- AssemblyMass: float [ReadOnly] — Total mass of assembly
- AssemblyRootPart: BasePart [ReadOnly] — Root of physics assembly
- BrickColor: BrickColor — Color via BrickColor
- CanCollide: boolean — Physical collision (default true)
- CanQuery: boolean — Spatial query detection (default true)
- CanTouch: boolean — Touched event detection (default true)
- CastShadow: boolean — Default true
- CFrame: CFrame — Position + Orientation in world space
- CollisionGroup: string — Collision group name (default "Default")
- Color: Color3 — RGB color (overrides BrickColor)
- CustomPhysicalProperties: PhysicalProperties — Override material physics
- Locked: boolean — Can't be selected in Studio (default false)
- Massless: boolean — Doesn't contribute mass when non-root
- Material: Material — Visual + physical material
- MaterialVariant: string — Custom material variant name
- Orientation: Vector3 — Euler angles (degrees)
- PivotOffset: CFrame — Pivot transform offset
- Position: Vector3 — World position (center)
- Reflectance: float — [0,1] surface reflectance
- RootPriority: int — Higher = more likely assembly root
- Rotation: Vector3 — Same as Orientation
- Shape: PartType — Ball, Block, Cylinder, Wedge (Part only)
- Size: Vector3 — Dimensions in studs
- Transparency: float — [0,1] (0=opaque, 1=invisible)

### Key Methods
- CanSetNetworkOwnership() → (boolean, string?) — Check if can set network owner
- GetConnectedParts(recursive: boolean = false) → {BasePart}
- GetJoints() → {Instance} — All connected joints
- GetMass() → float — This part's mass only
- GetNetworkOwner() → Player? — Current physics owner
- GetNetworkOwnershipAuto() → boolean — Auto network ownership?
- GetNoCollisionConstraints() → {NoCollisionConstraint}
- GetTouchingParts() → {BasePart}
- GetVelocityAtPosition(position: Vector3) → Vector3
- IsGrounded() → boolean — Part of grounded assembly?
- Resize(normalId: NormalId, deltaAmount: int) → boolean
- SetNetworkOwner(playerInstance: Player?) → () — Set physics owner (nil=server)
- SetNetworkOwnershipAuto() → () — Auto-assign network ownership

### Key Methods (inherited from PVInstance)
- GetPivot() → CFrame — Get pivot CFrame
- PivotTo(targetCFrame: CFrame) → () — Move part/model to CFrame

### Events
- Touched(otherPart: BasePart) — Physical contact began
- TouchEnded(otherPart: BasePart) — Physical contact ended

---

## Part
Inherits: BasePart
> Standard primitive part. Shape property determines visual shape.
- Shape: PartType — Block (default), Ball, Cylinder, Wedge, CornerWedge

## MeshPart
Inherits: TriangleMeshPart > BasePart
> Part with a custom 3D mesh.
- HasJointOffset: boolean [ReadOnly]
- HasSkinnedMesh: boolean [ReadOnly]
- MeshId: Content — Asset ID of the mesh
- TextureID: Content — Texture asset ID
- DoubleSided: boolean — Render both sides
- RenderFidelity: RenderFidelity — Automatic, Precise, Performance

## WedgePart
Inherits: FormFactorPart > BasePart
> Wedge-shaped primitive part.

## SpawnLocation
Inherits: Part
> Player spawn point.
- AllowTeamChangeOnTouch: boolean
- Duration: float — Forcefield duration (default 10, 0=disabled)
- Enabled: boolean — Default true
- Neutral: boolean — Any team can spawn (default true)
- TeamColor: BrickColor — Restrict to team

---

## Model
Inherits: PVInstance > Instance
> Container for grouped BaseParts.

### Properties
- LevelOfDetail: ModelLevelOfDetail — Streaming LOD
- ModelStreamingMode: ModelStreamingMode — Default, Atomic, Persistent, PersistentPerPlayer, Nonatomic
- PrimaryPart: BasePart — Reference part for Model
- Scale: float — Model scale factor (default 1.0)
- WorldPivot: CFrame — Pivot point in world space

### Methods
- GetBoundingBox() → (CFrame, Vector3) — Oriented bounding box
- GetExtentsSize() → Vector3 — Axis-aligned bounding box size
- GetScale() → float
- ScaleTo(newScaleFactor: float) → ()
- MoveTo(position: Vector3) → () — Move Model, avoiding collisions
- GetPivot() → CFrame
- PivotTo(targetCFrame: CFrame) → () — **PRIMARY way to move Models**
- AddPersistentPlayer(player: Player) → () — For PersistentPerPlayer streaming
- RemovePersistentPlayer(player: Player) → ()

---

## Camera
Inherits: Instance
> Controls the viewport. One per client.

### Key Properties
- CameraSubject: Instance — Usually Humanoid or BasePart
- CameraType: CameraType — Custom, Scriptable, Watch, Track, Follow, etc.
- CFrame: CFrame — Camera position + look direction
- FieldOfView: float — Degrees (default 70)
- FieldOfViewMode: FieldOfViewMode — Vertical (default), Diagonal, MaxAxis
- Focus: CFrame — Point camera should render detail around
- MaxAxisFieldOfView: float
- NearPlaneZ: float [ReadOnly] — Near clip
- ViewportSize: Vector2 [ReadOnly] — Screen size in pixels
- DiagonalFieldOfView: float

### Key Methods
- ScreenPointToRay(x: float, y: float, depth: float = 0) → Ray — Screen coords → world Ray (accounts for GUI inset)
- ViewportPointToRay(x: float, y: float, depth: float = 0) → Ray — Viewport coords → world Ray
- WorldToScreenPoint(worldPoint: Vector3) → (Vector3, boolean) — World → screen coords + onScreen flag
- WorldToViewportPoint(worldPoint: Vector3) → (Vector3, boolean)

---

## Attachment
Inherits: Instance
> A point + orientation on a BasePart. Used by Constraints.

### Properties
- CFrame: CFrame — Position + orientation relative to parent
- Axis: Vector3 [ReadOnly] — X-axis direction
- SecondaryAxis: Vector3 [ReadOnly] — Y-axis direction
- Position: Vector3 — Relative to parent (convenience)
- Orientation: Vector3 — Euler angles (convenience)
- Visible: boolean — Debug visualization
- WorldCFrame: CFrame [ReadOnly]
- WorldPosition: Vector3 [ReadOnly]

---

## Constraints (Common)

### WeldConstraint
> Rigidly connects two parts. No Attachments needed.
- Enabled: boolean, Part0: BasePart, Part1: BasePart, Active: boolean [ReadOnly]

### RigidConstraint
> Like WeldConstraint but uses Attachments.
- Attachment0: Attachment, Attachment1: Attachment

### HingeConstraint
> Rotates around an axis (door, wheel).
- ActuatorType: ActuatorType (None, Motor, Servo)
- AngularVelocity: float, MotorMaxTorque: float, ServoMaxTorque: float, TargetAngle: float
- LimitsEnabled: boolean, LowerAngle: float, UpperAngle: float

### SpringConstraint
> Spring force between two attachments.
- Damping: float, FreeLength: float, Stiffness: float, MaxForce: float

### RopeConstraint
> Maximum distance between two attachments (like a rope).
- Length: float, Restitution: float, Thickness: float, Visible: boolean

### AlignPosition
> Applies force to align a part to a target position.
- Mode: AlignType (OneAttachment, TwoAttachment)
- Position: Vector3 — Target (OneAttachment mode)
- MaxForce: float, MaxVelocity: float, Responsiveness: float, RigidityEnabled: boolean

### AlignOrientation
> Applies torque to align orientation.
- Mode: AlignType, CFrame: CFrame, MaxTorque: float, Responsiveness: float

### LinearVelocity
> Applies force to achieve a target velocity.
- LineDirection: Vector3, LineVelocity: float, MaxForce: float, VelocityConstraintMode: VelocityConstraintMode

### AngularVelocity
> Applies torque to achieve target angular velocity.
- AngularVelocity: Vector3, MaxTorque: float

---

## JointInstance (Abstract)
Inherits: Instance | Tags: NotCreatable
- C0: CFrame, C1: CFrame — Joint transforms
- Enabled: boolean
- Part0: BasePart, Part1: BasePart

### Motor6D
Inherits: Motor > JointInstance
> Animated joint connecting character parts.
- CurrentAngle: float, DesiredAngle: float, MaxVelocity: float
- Transform: CFrame — Set by Animator during animation playback

### Weld
Inherits: JointInstance
> Legacy rigid connection (use WeldConstraint instead for new work).

---

## NoCollisionConstraint
> Disables collision between two parts.
- Part0: BasePart, Part1: BasePart, Enabled: boolean

---

## Terrain
Inherits: BasePart | Tags: NotCreatable
> Voxel-based terrain system.

### Methods
- FillBall(center: Vector3, radius: float, material: Material) → ()
- FillBlock(cframe: CFrame, size: Vector3, material: Material) → ()
- FillCylinder(cframe: CFrame, height: float, radius: float, material: Material) → ()
- FillWedge(cframe: CFrame, size: Vector3, material: Material) → ()
- FillRegion(region: Region3, resolution: float, material: Material) → ()
- ReadVoxels(region: Region3, resolution: float) → ({{{Material}}}, {{{float}}}) [CustomLuaState]
- WriteVoxels(region: Region3, resolution: float, materials: {{{Material}}}, occupancy: {{{float}}}) → ()
- ReplaceMaterial(region: Region3, resolution: float, sourceMaterial: Material, targetMaterial: Material) → ()
- GetMaterialColor(material: Material) → Color3
- SetMaterialColor(material: Material, value: Color3) → ()
- Clear() → ()
