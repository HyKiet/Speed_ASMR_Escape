# Roblox Engine API — Game Services
> Source: Official Roblox Creator Docs

---

## MarketplaceService
Inherits: Instance | Tags: Service, NotCreatable
> Handles in-experience purchases (game passes, developer products, assets).

### Methods
- GetProductInfo(assetId: int64, infoType: InfoType?) → table [Yields] — Get asset info
- PlayerOwnsAsset(player: Player, assetId: int64) → boolean [Yields]
- UserOwnsGamePassAsync(userId: int64, gamePassId: int64) → boolean [Yields]
- PromptGamePassPurchase(player: Player, gamePassId: int64) → ()
- PromptProductPurchase(player: Player, productId: int64, equipIfPurchased: boolean = true, currencyType: CurrencyType = Default) → ()
- PromptPurchase(player: Player, assetId: int64, equipIfPurchased: boolean = true, currencyType: CurrencyType = Default) → ()
- PromptPremiumPurchase(player: Player) → ()
- PromptSubscriptionPurchase(player: Player, subscriptionId: string) → ()
- IsPlayerSubscribed(player: Player, subscriptionId: string) → boolean [Yields]
- GetDeveloperProductsAsync() → Pages [Yields]
- GetSubscriptionProductInfoAsync(subscriptionId: string) → table [Yields]

### Callbacks
- ProcessReceipt: (receiptInfo: table) → Enum.ProductPurchaseDecision — **MUST** set this for dev products!

### Events
- PromptGamePassPurchaseFinished(player: Player, gamePassId: int64, wasPurchased: boolean)
- PromptProductPurchaseFinished(userId: int64, productId: int64, wasPurchased: boolean)
- PromptPurchaseFinished(player: Player, assetId: int64, isPurchased: boolean)
- PromptPremiumPurchaseFinished()
- PromptSubscriptionPurchaseFinished(player: Player, subscriptionId: string, wasPurchased: boolean)

> 💡 ProcessReceipt pattern:
> ```lua
> MarketplaceService.ProcessReceipt = function(receiptInfo)
>     -- receiptInfo.PlayerId, .ProductId, .PurchaseId, .CurrencySpent
>     -- Process purchase... save data...
>     return Enum.ProductPurchaseDecision.PurchaseGranted
> end
> ```

---

## BadgeService
Inherits: Instance | Tags: Service, NotCreatable
> Manage badges.

### Methods
- AwardBadge(userId: int64, badgeId: int64) → boolean [Yields]
- UserHasBadgeAsync(userId: int64, badgeId: int64) → boolean [Yields]
- GetBadgeInfoAsync(badgeId: int64) → table [Yields] — {Name, Description, IconImageId, IsEnabled}

---

## TeleportService
Inherits: Instance | Tags: Service, NotCreatable
> Teleport players between places/servers.

### Methods
- TeleportAsync(placeId: int64, players: {Player}, teleportOptions: TeleportOptions?) → TeleportAsyncResult [Yields]
- GetPlayerPlaceInstanceAsync(userId: int64) → (boolean, int64, int64, string) [Yields]
- GetArrivingTeleportGui() → ScreenGui — Custom loading screen
- SetTeleportGui(gui: GuiObject) → () — Set custom loading screen
- GetLocalPlayerTeleportData() → Variant — Data sent with teleport

### TeleportOptions (Instance)
- ServerInstanceId: string — Join specific server
- ReservedServerAccessCode: string — Join reserved server
- ShouldTeleportToVIPServer: boolean [Deprecated]
- Methods: SetTeleportData(teleportData: Variant) → ()
- Methods: GetTeleportData() → Variant

---

## SocialService
Inherits: Instance | Tags: Service, NotCreatable
> Social features (invite, voice chat, etc.)

### Methods
- PromptGameInvite(player: Player, experienceInviteOptions: ExperienceInviteOptions?) → ()
- CanSendGameInviteAsync(player: Player, recipientId: int64?) → boolean [Yields]
- PromptPhoneBook(player: Player, tag: string) → ()
- ShowSelfView(selfViewPosition: SelfViewPosition?) → ()
- HideSelfView() → ()

### Events
- GameInvitePromptClosed(player: Player, recipientIds: {int64})
- PhoneBookPromptClosed(player: Player)

---

## PathfindingService
Inherits: Instance | Tags: Service, NotCreatable
> A* pathfinding for NPC navigation.

### Methods
- CreatePath(agentParameters: table?) → Path

> agentParameters: { AgentRadius: float, AgentHeight: float, AgentCanJump: boolean, AgentCanClimb: boolean, WaypointSpacing: float, Costs: {[string]: float} }

### Path
Inherits: Instance | Tags: NotCreatable
- Status: PathStatus [ReadOnly] — Success, NoPath, ClosestNoPath, ClosestOutOfRange
- Methods: ComputeAsync(start: Vector3, finish: Vector3) → () [Yields]
- Methods: GetWaypoints() → {PathWaypoint}
- Events: Blocked(blockedWaypointIdx: int)

### PathWaypoint (DataType)
- Position: Vector3
- Action: PathWaypointAction — Walk, Jump, Custom
- Label: string

### PathfindingModifier
Inherits: Instance
> Parent to BasePart to modify pathfinding cost.
- Label: string — Custom label for Costs table
- PassThrough: boolean — Can path through this part

### PathfindingLink
Inherits: Instance
> Creates a custom pathfinding connection between two parts.
- Attachment0: Attachment
- Attachment1: Attachment
- IsBidirectional: boolean
- Label: string

---

## TextService
Inherits: Instance | Tags: Service, NotCreatable
> Text filtering and measurement.

### Methods
- FilterStringAsync(stringToFilter: string, fromUserId: int64, textContext: TextFilterContext = PrivateChat) → TextFilterResult [Yields]
- GetTextSize(string: string, fontSize: int, font: Font, frameSize: Vector2) → Vector2
- GetTextBoundsAsync(params: GetTextBoundsParams) → Vector2 [Yields]

> ⚠️ ALL user-generated text MUST be filtered through FilterStringAsync.

---

## TextChatService
Inherits: Instance | Tags: Service, NotCreatable
> Modern chat system (replacement for legacy Chat service).

### Properties
- ChatVersion: ChatVersion — LegacyChatService, TextChatService
- CreateDefaultTextChannels: boolean
- CreateDefaultCommands: boolean

### Methods
- DisplayBubble(partOrCharacter: Instance, message: string) → () — Show NPC chat bubble

### Events
- MessageReceived(textChatMessage: TextChatMessage)
- SendingMessage(textChatMessage: TextChatMessage) — Before sending (client)

### TextChannel
Inherits: Instance
- Methods: DisplaySystemMessage(systemMessage: string, metadata: string?) → TextChatMessage
- Methods: SendAsync(message: string, metadata: string?) → TextChatMessage [Yields]
- Events: MessageReceived(textChatMessage: TextChatMessage)
- Callbacks: ShouldDeliverCallback: (textChatMessage: TextChatMessage, textSource: TextSource) → boolean

---

## Animation System

### Animation
Inherits: Instance
> References an animation asset.
- AnimationId: Content — rbxassetid://

### Animator
Inherits: Instance
> Plays animations. Found inside Humanoid.
- Methods: LoadAnimation(animation: Animation) → AnimationTrack [Yields]
- Methods: GetPlayingAnimationTracks() → {AnimationTrack}
- Events: AnimationPlayed(animationTrack: AnimationTrack)

### AnimationTrack
Inherits: Instance | Tags: NotCreatable
> Controls animation playback state.

#### Properties
- Animation: Animation [ReadOnly]
- IsPlaying: boolean [ReadOnly]
- Length: double [ReadOnly] — Duration in seconds
- Looped: boolean
- Priority: AnimationPriority — Idle, Movement, Action, Action2, Action3, Action4, Core
- Speed: float [ReadOnly]
- TimePosition: double — Current time
- WeightCurrent: float [ReadOnly]
- WeightTarget: float [ReadOnly]

#### Methods
- Play(fadeTime: float = 0.1, weight: float = 1, speed: float = 1) → ()
- Stop(fadeTime: float = 0.1) → ()
- AdjustSpeed(speed: float) → ()
- AdjustWeight(weight: float, fadeTime: float = 0.1) → ()
- GetMarkerReachedSignal(name: string) → RBXScriptSignal(paramValue: string)
- GetTimeOfKeyframe(keyframeName: string) → double

#### Events
- Stopped() — Animation stopped
- KeyframeReached(keyframeName: string)
- DidLoop()

---

## AssetService
Inherits: Instance | Tags: Service, NotCreatable
> Manage assets programmatically.

### Methods
- CreateEditableImage(editableImageOptions: table?) → EditableImage
- CreateEditableMesh(editableMeshOptions: table?) → EditableMesh
- CreateEditableMeshAsync(content: Content, editableMeshOptions: table?) → EditableMesh [Yields]
- CreateMeshPartAsync(meshContent: Content, options: table?) → MeshPart [Yields]
- GetBundleDetailsAsync(bundleId: int64) → table [Yields]
- CreatePlaceAsync(placeName: string, templatePlaceID: int64, description: string?) → int64 [Yields]
- SavePlaceAsync() → () [Yields]

---

## InsertService
Inherits: Instance | Tags: Service, NotCreatable
> Insert free models/assets from the catalog.

### Methods
- LoadAsset(assetId: int64) → Instance [Yields] — Returns a Model containing the asset
- LoadAssetVersion(assetVersionId: int64) → Instance [Yields]
- GetFreeModels(searchText: string, pageNum: int) → {table} [Yields, Deprecated]
- GetFreeDecals(searchText: string, pageNum: int) → {table} [Yields, Deprecated]

---

## PolicyService
Inherits: Instance | Tags: Service, NotCreatable
> Get player policy info (age restrictions, region limits).

### Methods
- GetPolicyInfoForPlayerAsync(player: Player) → table [Yields]

> Returns: { ArePaidRandomItemsRestricted: boolean, AllowedExternalLinkReferences: {string}, IsPaidItemTradingAllowed: boolean, IsSubjectToChinaPolicies: boolean, ... }

---

## LocalizationService
Inherits: Instance | Tags: Service, NotCreatable
> In-game text localization.

### Methods
- GetTranslatorForPlayer(player: Player) → Translator
- GetTranslatorForPlayerAsync(player: Player) → Translator [Yields]
- GetTranslatorForLocaleAsync(locale: string) → Translator [Yields]

### Translator
- Methods: Translate(context: Instance, text: string) → string
- Methods: FormatByKey(key: string, args: table?) → string

---

## GroupService
Inherits: Instance | Tags: Service, NotCreatable
### Methods
- GetGroupInfoAsync(groupId: int64) → table [Yields]
- GetGroupsAsync(userId: int64) → {{...}} [Yields]

## Player:GetRankInGroup / IsInGroup (on Player object)
- GetRankInGroup(groupId: int64) → int [Yields] — 0-255 rank
- IsInGroup(groupId: int64) → boolean [Yields]
- GetRoleInGroup(groupId: int64) → string [Yields]
