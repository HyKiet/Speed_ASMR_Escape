# Roblox Engine API — Effects, Lighting & Media
> Source: Official Roblox Creator Docs

---

## Lighting
Inherits: Instance | Tags: Service, NotCreatable
> Controls global lighting, time of day, and post-processing effects.

### Properties
- Ambient: Color3 — Ambient light from environment
- Brightness: float — Intensity of light (0-10, default 2)
- ClockTime: float — 24h format (0-24, e.g. 14.5 = 2:30 PM)
- ColorShiftBottom: Color3 — Color shift for surfaces facing down
- ColorShiftTop: Color3 — Color shift for surfaces facing up
- EnvironmentDiffuseScale: float — [0,1] diffuse environment map
- EnvironmentSpecularScale: float — [0,1] specular environment map
- ExposureCompensation: float — EV adjustment (-5 to 5)
- FogColor: Color3
- FogEnd: float — Fog end distance
- FogStart: float — Fog start distance
- GeographicLatitude: float — Sun/moon angle
- GlobalShadows: boolean — Enable dynamic shadows
- OutdoorAmbient: Color3 — Ambient from sky (when GlobalShadows=true)
- ShadowSoftness: float — [0,1]
- Technology: Technology — Compatibility, Voxel, ShadowMap, Future
- TimeOfDay: string — "HH:MM:SS" format (alternative to ClockTime)

### Methods
- GetMinutesAfterMidnight() → float
- SetMinutesAfterMidnight(minutes: float) → ()
- GetMoonDirection() → Vector3
- GetMoonPhase() → float
- GetSunDirection() → Vector3

### Events
- LightingChanged() — Any lighting property changed

---

## Atmosphere
Inherits: Instance
> Parent to Lighting. Realistic atmospheric rendering.
- Color: Color3 — Atmosphere color
- Decay: Color3 — Color at furthest visible distance
- Density: float — [0,1] atmosphere thickness
- Glare: float — [0,10] glare intensity
- Haze: float — [0,10] haze amount
- Offset: float — [0,1] atmosphere height offset

## Sky
Inherits: Instance
> Parent to Lighting. Skybox textures or celestial bodies.
- CelestialBodiesShown: boolean — Show sun/moon
- MoonAngularSize: float
- MoonTextureId: Content
- SkyboxBk: Content, SkyboxDn, SkyboxFt, SkyboxLf, SkyboxRt, SkyboxUp — 6-sided skybox
- StarCount: int — Default 3000
- SunAngularSize: float — Default 21
- SunTextureId: Content

## Clouds
Inherits: Instance
> Parent to Terrain. Volumetric cloud layer.
- Color: Color3
- Cover: float — [0,1] cloud coverage
- Density: float — [0,1]
- Enabled: boolean

---

## Lights

### PointLight
Inherits: Light > Instance
> Emits light in all directions from parent part.
- Brightness: float (default 1)
- Color: Color3
- Enabled: boolean
- Range: float — Max illumination distance (default 8)
- Shadows: boolean — Cast shadows

### SpotLight
Inherits: Light > Instance
> Directional cone of light.
- Angle: float — Cone angle [0,180] (default 90)
- Face: NormalId — Direction (default Front)
- Range: float (default 16)
- Shadows: boolean

### SurfaceLight
Inherits: Light > Instance
> Emits light from a face of parent part.
- Angle: float (default 90)
- Face: NormalId (default Front)
- Range: float (default 16)

---

## Post-Processing Effects
> Parent to Lighting or Camera.

### BloomEffect
- Intensity: float — [0,1] bloom intensity
- Size: float — [0,56] bloom spread
- Threshold: float — [0,4] brightness threshold

### BlurEffect
- Size: float — [0,56] blur amount

### ColorCorrectionEffect
- Brightness: float — [-1,1]
- Contrast: float — [-1,1]
- Saturation: float — [-1,1]
- TintColor: Color3 — Color tint overlay

### DepthOfFieldEffect
- FarIntensity: float — [0,1]
- FocusDistance: float — Focus point distance
- InFocusRadius: float — Range in focus
- NearIntensity: float — [0,1]

### SunRaysEffect
- Intensity: float — [0,1]
- Spread: float — [0,1]

### ColorGradingEffect
- LookUpTable: Content — Color LUT texture

---

## Particle Effects

### ParticleEmitter
Inherits: Instance
> Emits particles from parent BasePart or Attachment.

#### Key Properties
- Color: ColorSequence
- Drag: float — Air resistance
- EmissionDirection: NormalId
- Enabled: boolean
- FlipbookFramerate: NumberRange — Sprite sheet animation speed
- FlipbookLayout: ParticleFlipbookLayout — None, Grid2x2, Grid4x4, Grid8x8
- Lifetime: NumberRange — Particle lifespan (seconds)
- LightEmission: float — [0,1] additive blending
- LightInfluence: float — [0,1] affected by lighting
- Orientation: ParticleOrientation — FacingCamera, FacingCameraWorldUp, VelocityParallel, VelocityPerpendicular
- Rate: float — Particles per second
- RotSpeed: NumberRange — Rotation speed
- Rotation: NumberRange — Initial rotation
- Shape: ParticleEmitterShape — Box, Sphere, Cylinder, Disc
- ShapePartial: float — [0,1] emit from volume
- Size: NumberSequence — Size over lifetime
- Speed: NumberRange — Initial speed
- SpreadAngle: Vector2 — Spread range (degrees)
- Squash: NumberSequence — Axis squash over lifetime
- Texture: Content — Particle image
- TimeScale: float — Playback speed
- Transparency: NumberSequence — Transparency over lifetime
- VelocityInheritance: float — Inherit parent velocity
- ZOffset: float — Render depth offset

#### Methods
- Clear() → () — Remove all existing particles
- Emit(particleCount: int = 16) → () — Burst emit

### Beam
Inherits: Instance
> Renders a beam between two Attachments.
- Attachment0: Attachment — Start
- Attachment1: Attachment — End
- Color: ColorSequence
- CurveSize0: float, CurveSize1: float — Bezier curve control
- Enabled: boolean
- FaceCamera: boolean
- LightEmission: float
- LightInfluence: float
- Segments: int — Curve resolution (default 10)
- Texture: Content
- TextureLength: float
- TextureMode: TextureMode — Static, Stretch, Wrap
- TextureSpeed: float
- Transparency: NumberSequence
- Width0: float, Width1: float
- ZOffset: float

### Trail
Inherits: Instance
> Renders a trail behind moving Attachments.
- Attachment0: Attachment, Attachment1: Attachment
- Color: ColorSequence
- Enabled: boolean
- FaceCamera: boolean
- Lifetime: float — How long trail segments last
- LightEmission: float
- LightInfluence: float
- MaxWidth: float
- MinLength: float
- Texture: Content
- TextureLength: float
- TextureMode: TextureMode
- Transparency: NumberSequence
- WidthScale: NumberSequence
- Methods: Clear() → ()

---

## Legacy Effects

### Fire — Inherits: Instance. Parent to BasePart.
- Color: Color3, SecondaryColor: Color3, Size: float, Heat: float, Enabled: boolean

### Smoke — Inherits: Instance. Parent to BasePart.
- Color: Color3, Opacity: float, RiseVelocity: float, Size: float, Enabled: boolean

### Sparkles — Inherits: Instance. Parent to BasePart.
- SparkleColor: Color3, Enabled: boolean

### Explosion — Inherits: Instance. Parent to Workspace.
- BlastPressure: float, BlastRadius: float, Position: Vector3, Visible: boolean
- DestroyJointRadiusPercent: float, ExplosionType: ExplosionType (NoCraters, Craters)
- Events: Hit(part: BasePart, distance: float)

### Highlight
Inherits: Instance
> Outline/overlay effect on a Model or BasePart.
- Adornee: Instance — Target (nil = parent)
- DepthMode: HighlightDepthMode — AlwaysOnTop, Occluded
- Enabled: boolean
- FillColor: Color3 — Interior color
- FillTransparency: float
- OutlineColor: Color3 — Edge outline color
- OutlineTransparency: float

### ForceField
Inherits: Instance
> Visual shield + prevents TakeDamage.
- Visible: boolean

---

## Sound System

### Sound
Inherits: Instance
> Audio playback. Parent to part for 3D positional audio, or SoundService for 2D.

#### Properties
- IsLoaded: boolean [ReadOnly]
- IsPlaying: boolean [ReadOnly]
- Looped: boolean
- PlaybackSpeed: float — 1=normal, 2=double speed
- Playing: boolean
- RollOffMaxDistance: float — 3D falloff max (default 10000)
- RollOffMinDistance: float — 3D falloff start (default 10)
- RollOffMode: RollOffMode — Inverse, InverseTapered, Linear, LinearSquare
- SoundId: Content — Audio asset ID
- TimeLength: double [ReadOnly] — Duration in seconds
- TimePosition: double — Current playback position
- Volume: float — [0,10] (default 0.5)

#### Methods
- Play() → (), Pause() → (), Resume() → (), Stop() → ()

#### Events
- Played(soundId: string)
- Paused(soundId: string)
- Resumed(soundId: string)
- Stopped(soundId: string)
- Ended() — Playback finished
- Loaded() — Audio asset loaded
- DidLoop(soundId: string, numOfTimesLooped: int)

### SoundGroup
Inherits: Instance
> Groups sounds for volume control.
- Volume: float — Master volume for group

### SoundService
Inherits: Instance | Tags: Service, NotCreatable
> Global sound settings.
- AmbientReverb: ReverbType
- DistanceFactor: float
- DopplerScale: float
- RespectFilteringEnabled: boolean
- RolloffScale: float
- VolumetricAudio: VolumetricAudio
- Methods: PlayLocalSound(sound: Sound) → () — 2D sound client-only

---

## Surface Appearance & Materials

### Decal
Inherits: FaceInstance > Instance
> Image applied to one face of a BasePart.
- Color3: Color3 — Tint
- Face: NormalId — Which face
- Texture: Content — Image asset
- Transparency: float
- ZIndex: int

### Texture
Inherits: Decal
> Tiling texture on a face.
- OffsetStudsU: float, OffsetStudsV: float
- StudsPerTileU: float, StudsPerTileV: float

### SurfaceAppearance
Inherits: Instance
> PBR material for MeshParts.
- AlphaMode: AlphaMode — Overlay, Transparency
- ColorMap: Content — Albedo/diffuse texture
- MetalnessMap: Content
- NormalMap: Content
- RoughnessMap: Content
- TexturePack: Content — All-in-one texture pack

### MaterialVariant
Inherits: Instance
> Custom material variant overriding a BaseMaterial.
- BaseMaterial: Material — Which material to override
- MaterialPattern: MaterialPattern — Regular, Organic
- ColorMap: Content, MetalnessMap, NormalMap, RoughnessMap
- StudsPerTile: float

### MaterialService
Inherits: Instance | Tags: Service, NotCreatable
> Manages custom material variants. MaterialVariants are parented here.
