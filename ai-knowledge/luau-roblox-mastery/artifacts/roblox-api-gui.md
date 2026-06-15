# Roblox Engine API — GUI System
> Source: Official Roblox Creator Docs

---

## GuiObject (Abstract)
Inherits: GuiBase2d > GuiBase > Instance | Tags: NotCreatable, NotBrowsable
> Base class for all 2D GUI elements.

### Key Properties
- Active: boolean — Sinks input (prevents click-through)
- AnchorPoint: Vector2 — Relative anchor (0,0)=TopLeft, (0.5,0.5)=Center, (1,1)=BottomRight
- AutomaticSize: AutomaticSize — None, X, Y, XY
- BackgroundColor3: Color3
- BackgroundTransparency: float — 0=opaque, 1=transparent
- BorderColor3: Color3
- BorderMode: BorderMode — Outline, Middle, Inset
- BorderSizePixel: int — Border thickness (0=none)
- ClipsDescendants: boolean — Clip children to bounds
- Interactable: boolean — Respond to input
- LayoutOrder: int — For UIListLayout/UIGridLayout sorting
- Position: UDim2 — {Scale + Offset, Scale + Offset}
- Rotation: float — Degrees
- Size: UDim2 — {ScaleX + Offset, ScaleY + Offset}
- SizeConstraint: SizeConstraint — RelativeXX, RelativeXY, RelativeYY
- Visible: boolean
- ZIndex: int — Render order (higher=front)

### Key Properties (inherited from GuiBase2d)
- AbsolutePosition: Vector2 [ReadOnly] — Final screen position
- AbsoluteRotation: float [ReadOnly]
- AbsoluteSize: Vector2 [ReadOnly] — Final screen size

### Methods
- TweenPosition(endPosition: UDim2, easingDirection: EasingDirection, easingStyle: EasingStyle, time: float, override: boolean, callback: ((status: TweenStatus) → ())?) → boolean
- TweenSize(endSize: UDim2, ...) → boolean
- TweenSizeAndPosition(endSize: UDim2, endPosition: UDim2, ...) → boolean

### Events
- InputBegan(input: InputObject)
- InputChanged(input: InputObject)
- InputEnded(input: InputObject)
- MouseEnter(x: int, y: int)
- MouseLeave(x: int, y: int)
- MouseMoved(x: int, y: int)
- SelectionGained()
- SelectionLost()
- TouchLongPress(touchPositions: {Vector2}, state: UserInputState)
- TouchPan(touchPositions: {Vector2}, totalTranslation: Vector2, velocity: Vector2, state: UserInputState)
- TouchPinch(touchPositions: {Vector2}, scale: float, velocity: float, state: UserInputState)
- TouchRotate(touchPositions: {Vector2}, rotation: float, velocity: float, state: UserInputState)
- TouchSwipe(swipeDirection: SwipeDirection, numberOfTouches: int)
- TouchTap(touchPositions: {Vector2})

---

## Frame
Inherits: GuiObject
> Basic container. No unique properties. Use for grouping/layout.

## TextLabel
Inherits: GuiObject
> Displays non-interactive text.
- Font: Font — Legacy (use FontFace)
- FontFace: Font — Modern font specification
- FontSize: FontSize [Deprecated]
- LineHeight: float — Line spacing multiplier
- MaxVisibleGraphemes: int — For typewriter effect (-1=all)
- RichText: boolean — Enable rich text markup
- Text: string — Displayed text
- TextColor3: Color3
- TextScaled: boolean — Auto-fit text to bounds
- TextSize: float — Font size in pixels
- TextStrokeColor3: Color3 — Text outline color
- TextStrokeTransparency: float — Outline transparency (1=none)
- TextTruncate: TextTruncate — None, AtEnd
- TextWrapped: boolean — Word wrap
- TextXAlignment: TextXAlignment — Left, Center, Right
- TextYAlignment: TextYAlignment — Top, Center, Bottom
- ContentText: string [ReadOnly] — Text after filtering
- TextBounds: Vector2 [ReadOnly] — Size of rendered text
- TextFits: boolean [ReadOnly] — Text fits within bounds

## TextButton
Inherits: GuiButton > GuiObject
> Clickable text element. All TextLabel properties + GuiButton properties.
- AutoButtonColor: boolean — Auto darken on hover/press
- Modal: boolean — Capture gamepad input
- Selected: boolean
- Style: ButtonStyle [Deprecated]
- Events: Activated(inputObject: InputObject, clickCount: int)
- Events: MouseButton1Click(), MouseButton1Down(x: int, y: int), MouseButton1Up(x: int, y: int)
- Events: MouseButton2Click(), MouseButton2Down(x: int, y: int), MouseButton2Up(x: int, y: int)

## TextBox
Inherits: GuiObject
> Editable text input. All TextLabel properties +
- ClearTextOnFocus: boolean — Default true
- MultiLine: boolean
- PlaceholderColor3: Color3
- PlaceholderText: string
- ShowNativeInput: boolean — Native keyboard on mobile
- TextEditable: boolean
- CursorPosition: int — Cursor offset (-1=end)
- SelectionStart: int — Selection start (-1=none)
- Events: FocusLost(enterPressed: boolean, inputThatCausedFocusLoss: InputObject)
- Events: Focused()
- Methods: CaptureFocus() → (), ReleaseFocus(submitted: boolean = false) → ()

## ImageLabel
Inherits: GuiObject
> Displays an image.
- Image: Content — Asset ID or URL
- ImageColor3: Color3 — Image tint
- ImageRectOffset: Vector2 — Sprite sheet offset
- ImageRectSize: Vector2 — Sprite sheet cell size
- ImageTransparency: float
- ResampleMode: ResamplerMode — Default, Pixelated
- ScaleType: ScaleType — Stretch, Slice, Tile, Fit, Crop
- SliceCenter: Rect — 9-slice center (when ScaleType=Slice)
- SliceScale: float — 9-slice border scale
- TileSize: UDim2 — Tile dimensions (when ScaleType=Tile)
- IsLoaded: boolean [ReadOnly]

## ImageButton
Inherits: GuiButton > GuiObject
> Clickable image. All ImageLabel properties + GuiButton events.

---

## Container GUIs

### ScreenGui
Inherits: LayerCollector > GuiBase2d > Instance
> Container for 2D UI on player's screen.
- DisplayOrder: int — Layer order (higher=front)
- Enabled: boolean — Show/hide
- IgnoreGuiInset: boolean — Ignore top bar inset
- ResetOnSpawn: boolean — Re-clone from StarterGui on respawn
- ZIndexBehavior: ZIndexBehavior — Global (all descendants), Sibling (local)
- ClipToDeviceSafeArea: boolean
- SafeAreaCompatibility: SafeAreaCompatibility — None, FullscreenExtension
- ScreenInsets: ScreenInsets — None, TopbarSafeInsets, DeviceSafeInsets, CoreUISafeInsets

### BillboardGui
Inherits: LayerCollector
> 3D-attached GUI that always faces camera.
- Adornee: Instance — Target part/attachment
- AlwaysOnTop: boolean
- MaxDistance: float — Visibility distance
- Size: UDim2 — Size in 3D space
- StudsOffset: Vector3 — Offset from adornee
- StudsOffsetWorldSpace: Vector3 — World space offset
- ExtentsOffset: Vector3 — Offset in adornee's extents
- LightInfluence: float [0,1] — Affected by lighting

### SurfaceGui
Inherits: LayerCollector
> GUI attached to a surface of a BasePart.
- Adornee: BasePart
- Face: NormalId — Which face (Front, Back, Left, Right, Top, Bottom)
- PixelsPerStud: float
- SizingMode: SurfaceGuiSizingMode — FixedSize, PixelsPerStud
- CanvasSize: Vector2 — Virtual canvas size

### ViewportFrame
Inherits: GuiObject
> Renders 3D objects within a 2D GUI element.
- CurrentCamera: Camera — Camera for viewport
- ImageColor3: Color3 — Tint
- ImageTransparency: float
- LightColor: Color3
- LightDirection: Vector3
- Ambient: Color3

### ScrollingFrame
Inherits: GuiObject
> Scrollable container.
- AutomaticCanvasSize: AutomaticSize — X, Y, XY
- BottomImage: Content — Scrollbar bottom texture
- CanvasPosition: Vector2 — Scroll position
- CanvasSize: UDim2 — Total scrollable area
- ElasticBehavior: ElasticBehavior — WhenScrollable, Always, Never
- MidImage: Content
- ScrollBarImageColor3: Color3
- ScrollBarImageTransparency: float
- ScrollBarThickness: int
- ScrollingDirection: ScrollingDirection — X, Y, XY
- ScrollingEnabled: boolean
- TopImage: Content
- VerticalScrollBarInset: ScrollBarInset

### CanvasGroup
Inherits: GuiObject
> Groups children and applies transparency/color as a single unit.
- GroupColor3: Color3
- GroupTransparency: float

---

## UI Layout & Constraints

### UIListLayout
Inherits: UIGridStyleLayout > UILayout > UIBase > Instance
> Arranges siblings in a list.
- FillDirection: FillDirection — Horizontal, Vertical
- HorizontalAlignment: HorizontalAlignment — Left, Center, Right
- VerticalAlignment: VerticalAlignment — Top, Center, Bottom
- HorizontalFlex: UIFlexAlignment — None, Fill, SpaceAround, SpaceBetween, SpaceEvenly
- VerticalFlex: UIFlexAlignment
- ItemLineAlignment: ItemLineAlignment
- Padding: UDim — Space between children
- SortOrder: SortOrder — Name, LayoutOrder, Custom
- Wraps: boolean — Wrap to next line
- Events: AbsoluteContentSize (Vector2, ReadOnly)

### UIGridLayout
Inherits: UIGridStyleLayout
> Arranges siblings in a grid.
- CellPadding: UDim2
- CellSize: UDim2
- FillDirectionMaxCells: int
- StartCorner: StartCorner — TopLeft, TopRight, BottomLeft, BottomRight

### UIPageLayout
Inherits: UIGridStyleLayout
> Page-based navigation.
- Animated: boolean, Circular: boolean, EasingDirection, EasingStyle, TweenTime

### UITableLayout
Inherits: UIGridStyleLayout
> Table layout with rows/columns.

### UIPadding
> Adds padding to parent GuiObject.
- PaddingBottom: UDim, PaddingLeft: UDim, PaddingRight: UDim, PaddingTop: UDim

### UICorner
> Rounds corners of parent.
- CornerRadius: UDim — (default 0,8)

### UIStroke
> Border/outline on parent.
- ApplyStrokeMode: ApplyStrokeMode — Contextual, Border
- Color: Color3
- Enabled: boolean
- LineJoinMode: LineJoinMode — Round, Bevel, Miter
- Thickness: float
- Transparency: float

### UIScale
> Scales parent and descendants.
- Scale: float

### UIGradient
> Applies color/transparency gradient.
- Color: ColorSequence
- Enabled: boolean
- Offset: Vector2
- Rotation: float
- Transparency: NumberSequence

### UIAspectRatioConstraint
> Enforces aspect ratio.
- AspectRatio: float (default 1.0)
- AspectType: AspectType — FitWithinMaxSize, ScaleWithParentSize
- DominantAxis: DominantAxis — Width, Height

### UISizeConstraint
> Min/Max size limits.
- MaxSize: Vector2
- MinSize: Vector2

### UITextSizeConstraint
> Min/Max text size.
- MaxTextSize: int
- MinTextSize: int

### UIFlexItem
> Controls flex behavior of parent within UIListLayout.
- FlexMode: UIFlexMode — None, Grow, Shrink, Fill, Custom
- GrowRatio: float
- ShrinkRatio: float
- ItemLineAlignment: ItemLineAlignment

---

## ProximityPrompt
Inherits: Instance
> Interactive prompt when player is near a part.

### Properties
- ActionText: string — Button text ("Interact")
- Enabled: boolean
- Exclusivity: ProximityPromptExclusivity — OnePerButton, OneGlobally, AlwaysShow
- GamepadKeyCode: KeyCode
- HoldDuration: float — How long to hold (0=instant)
- KeyboardKeyCode: KeyCode — Default E
- MaxActivationDistance: float — Default 10
- ObjectText: string — Description text
- RequiresLineOfSight: boolean
- Style: ProximityPromptStyle — Default, Custom

### Events
- Triggered(playerWhoTriggered: Player) — ACTION completed!
- TriggerEnded(playerWhoTriggered: Player)
- PromptButtonHoldBegan(playerWhoTriggered: Player)
- PromptButtonHoldEnded(playerWhoTriggered: Player)
- PromptShown(inputType: ProximityPromptInputType)
- PromptHidden()
