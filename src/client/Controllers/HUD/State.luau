--!strict
-- Trạng thái dùng chung cho toàn HUD và các Modal (Fusion Values + Tweens).
-- Mọi module HUD đều require State để truy cập/ghi cùng một bộ state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Tokens = require(script.Parent.Tokens)
local AudioMixController = require(script.Parent.Parent.Effects.AudioMixController)

local Tween = Fusion.Tween
local Value = Fusion.Value

export type Snapshot = {
	isLoaded: boolean,
	speed: number,
	totalWins: number,
	currentRunWins: number,
	streak: number,
	personalBestRunWins: number,
	highestCompletedStage: number,
	level: number,
	xp: number,
	requiredXP: number,
	rebirths: number,
	maxWalkSpeed: number,
	customSpeedLimit: number,
	gainMultiplier: number,
	treadmillMultiplier: number,
	speedPassMultiplier: number,
	vipMultiplier: number,
	premiumMultiplier: number,
	trailMultiplier: number,
	auraMultiplier: number,
	cosmeticMultiplier: number,
	rebirthMultiplier: number,
	playtimeMultiplier: number,
	friendsMultiplier: number,
	serverMultiplier: number,
	liveOpsMultiplier: number,
	friendsInServer: number,
	isOnTreadmill: boolean,
	canRebirth: boolean,
	requiredRebirthLevel: number,
	ownsAutoRebirth: boolean,
	autoRebirthEnabled: boolean,
	activeTreadmillId: string,
	equippedTrail: string,
	equippedAura: string,
	unlockedTrails: { [string]: boolean },
	unlockedAuras: { [string]: boolean },
}

export type TeleportDestinationConfig = Constants.TeleportDestinationConfig

export type ShopPurchaseKind = "gamepass" | "product"

export type ShopItemConfig = {
	id: string,
	title: string,
	subtitle: string,
	valueText: string,
	priceRobux: number,
	purchaseKind: ShopPurchaseKind,
	purchaseId: number,
	accentColor: Color3,
	icon: string,
	sortOrder: number,
}

export type ShopCatalog = { [string]: { ShopItemConfig } }

local DEFAULT_SNAPSHOT: Snapshot = {
	isLoaded = false,
	speed = 0,
	totalWins = 0,
	currentRunWins = 0,
	streak = 0,
	personalBestRunWins = 0,
	highestCompletedStage = 0,
	level = 1,
	xp = 0,
	requiredXP = Constants.GetRequiredXP(1),
	rebirths = 0,
	maxWalkSpeed = Constants.GetMaxWalkSpeed(1),
	customSpeedLimit = Constants.GetMaxWalkSpeed(1),
	gainMultiplier = 1,
	treadmillMultiplier = 1,
	speedPassMultiplier = 1,
	vipMultiplier = 1,
	premiumMultiplier = 1,
	trailMultiplier = 1,
	auraMultiplier = 1,
	cosmeticMultiplier = 1,
	rebirthMultiplier = 1,
	playtimeMultiplier = 1,
	friendsMultiplier = 1,
	serverMultiplier = 1,
	liveOpsMultiplier = 1,
	friendsInServer = 0,
	isOnTreadmill = false,
	canRebirth = false,
	requiredRebirthLevel = Constants.GetRequiredLevelForRebirth(0),
	ownsAutoRebirth = false,
	autoRebirthEnabled = true,
	activeTreadmillId = "treadmill_1",
	equippedTrail = "none",
	equippedAura = "none",
	unlockedTrails = { none = true },
	unlockedAuras = { none = true },
}

local State = {}

State.DEFAULT_SNAPSHOT = DEFAULT_SNAPSHOT

-- Snapshot + viewport
State.snapshot = Value(DEFAULT_SNAPSHOT)
State.viewportScale = Value(1)
State.viewportSize = Value(Vector2.new(1920, 1080))

--[[
	Chiều cao topbar Roblox (px thật). PHẢI là một `Value` chứ không được gọi thẳng
	`GuiService:GetGuiInset()` trong Computed — đó không phải dependency của Fusion, nên
	Computed nào đọc nó sẽ chốt giá trị ở lần chạy ĐẦU TIÊN và không bao giờ tính lại.

	Bẫy đã dính (2026-08-14): lúc HUD dựng xong thì topbar chưa nạp, inset = 0. Mọi modal
	tính vị trí ngay lúc đó rồi giữ nguyên mãi — trên điện thoại (topbar 58px) modal nằm chui
	dưới topbar suốt phiên chơi, dù công thức tránh topbar đã viết đúng.

	`Theme.UpdateViewportScale` cập nhật giá trị này; HUDController lắng nghe cả
	`GuiService:GetPropertyChangedSignal("TopbarInset")`.
]]
State.guiInsetTop = Value(0)

--[[
	Bề rộng vùng KHÔNG DÙNG ĐƯỢC ở mép PHẢI màn hình (px thật) — tai thỏ / Dynamic Island /
	viền bo của điện thoại khi xoay ngang.

	`GetGuiInset()` chỉ trả về inset DỌC nên nó mù hoàn toàn với chuyện này: cụm nào bám mép
	phải sẽ chui thẳng vào dưới tai thỏ trên iPhone nằm ngang, mà trên PC lại không tái hiện
	được (luôn = 0) nên rất dễ tưởng là "đã sát góc rồi".

	Nguồn: `GuiService.TopbarInset` — một `Rect` mô tả DẢI TOPBAR DÙNG ĐƯỢC. Đo trên PC:
	`208, 0, 1304, 58` với viewport 1304 ⇒ `Max.X` chạm đúng mép phải (thừa 0). Trên máy có
	tai thỏ, `Max.X` lùi vào trong đúng bằng phần bị che.

	⚠️ CHỈ dùng cho mép PHẢI (`Screen().SafeRight`). `Min.X` = 208 là chỗ Roblox để nút menu
	của CHÍNH NÓ, không phải vùng bị che — lấy nó làm lề trái sẽ đẩy cụm trái vào giữa màn hình.
]]
State.safeInsetRight = Value(0)

--[[
	Popup lên cấp đang hiện hay không.

	Dùng để TÁCH LÀN với banner chúc mừng (mua hàng / rebirth / boost). Hai thứ này là hai hệ
	thống rời nhau nên trước đây cùng vẽ vào giữa màn hình và đè chồng chữ lên nhau khi cùng
	nổ một lúc — mua treadmill xong lên mấy cấp liền là "LEVEL UP! LEVEL 62" nằm đè lên
	"RED ADMIN TREADMILL", không đọc được cái nào (user 2026-08-14).

	Cách các game Roblox lớn làm: mỗi loại thông báo có một LÀN riêng trên màn hình và không
	bao giờ tranh chỗ. Ở đây: level-up giữ làn TRÊN, banner tụt xuống làn DƯỚI khi cả hai cùng
	sống. Không xếp hàng chờ nhau — combo lên cấp bắn liên tục, bắt banner đợi là nó hiện ra
	sau khi người chơi đã quên mình vừa mua gì.
]]
State.levelUpActive = Value(false)

-- Toast + LevelUp
State.toastText = Value("")
State.levelUpText = Value("")

-- Custom speed input
State.customSpeedDraft = Value(tostring(Constants.GetMaxWalkSpeed(1)))
State.isEditingCustomSpeed = false

-- Playtime Boost
State.sessionPlaytime = Value(0)

--[[
	══ BỘ 4 GIÁ TRỊ CỦA MỘT MODAL — KHAI BẰNG MỘT DÒNG ══════════════════════════════════════

	Trả về theo đúng thứ tự: `Visible`, `Mounted`, `AnimationGoal`, `Animation`.

	  • `Visible`  — người chơi đang mở nó không. Dùng cho Toggle và cho việc quyết định còn
	                 modal nào đang mở (blur + FOV).
	  • `Mounted`  — có nằm trên màn hình không. Tắt SAU `Visible` đúng `MODAL_CLOSE_DELAY` để
	                 hoạt ảnh đóng chạy hết; tắt cùng lúc là modal biến mất phụt một cái.
	  • `Animation`— 0..1, mọi modal dùng CHUNG nhịp `Tokens.MODAL_TWEEN`.

	Trước đây 11 modal mỗi cái chép 5 dòng y hệt, trong đó có nguyên một `TweenInfo` gõ lại 11
	lần — muốn modal mở nhanh hơn phải sửa đúng 11 chỗ và sót một chỗ là modal đó lệch nhịp.
	Danh sách id chính thức nằm ở `Modals/Registry.luau`.

	⚠️ Vẫn gán TƯỜNG MINH từng tên thay vì chạy vòng lặp trên Registry: `--!strict` chỉ nhận ra
	field của bảng khi nó được gán thẳng. Gán động qua `(State :: any)[k]` thì mọi chỗ đọc
	`State.shopModalMounted` sẽ thành "unknown field" và CI type-baseline nổ hàng loạt.
]]
local function declareModal(): (any, any, any, any)
	local goal = Value(0)
	return Value(false), Value(false), goal, Tween(goal, Tokens.MODAL_TWEEN)
end

--[[
	Có ĐANG mở modal nào không — tín hiệu dùng chung cho những thứ nằm NGOÀI hệ modal nhưng phải
	nhường chỗ cho nó. `Manager.setModalFx` là nơi duy nhất ghi giá trị này (nó vốn đã được gọi
	đúng vào lúc trạng thái đó đổi, cùng chỗ bật/tắt blur + FOV).

	Người dùng đầu tiên: dải nhắc tutorial. Trên PC nó neo ở y = 96, mà mép trên của modal rơi
	vào khoảng y = 86 và thanh tiêu đề chiếm 98..182 — tức là nó che tiêu đề của MỌI modal
	(thấy rõ trong loạt ảnh user gửi 2026-08-16). Trước đây chỉ màn hình nhỏ mới đẩy dải xuống
	đáy; giờ mở modal là đẩy xuống, bất kể cỡ màn hình.
]]
State.anyModalOpen = Value(false)

--[[
	Dải nhắc tutorial đang chiếm LÀN ĐỈNH màn hình.

	`Theme.ModalPosition` đọc cờ này để BỎ phần "nhích modal lên" (`RAISE_OFFSET` = 48) trong
	lúc dải hiện. Đo ở 1919×1080 với dải nằm ở y 8..95: có nhích thì mép trên của ba modal cao
	nhất rơi vào 70 (Store) / 75 (Cosmetics) / 75 (Teleport) — dải đè lên 19–24px, tức là ăn mất
	đúng dòng chữ tiêu đề. Bỏ nhích thì cả ba tụt xuống 118/123/123, thoát hẳn.

	Nhích lên vốn chỉ là một cú căn chỉnh cho đẹp, còn đọc được tiêu đề modal thì không phải —
	nên khi hai thứ tranh chỗ, cái nhích phải nhường.
]]
State.tutorialBannerVisible = Value(false)

-- Rebirth modal
State.rebirthModalVisible, State.rebirthModalMounted, State.rebirthModalAnimationGoal, State.rebirthModalAnimation =
	declareModal()
State.rebirthCloseHovered = Value(false)
State.rebirthConfirmHovered = Value(false)
State.rebirthSkipHovered = Value(false)
State.rebirthAutoHovered = Value(false)

-- Cosmetic modal
State.cosmeticModalVisible, State.cosmeticModalMounted, State.cosmeticModalAnimationGoal, State.cosmeticModalAnimation =
	declareModal()
State.cosmeticCategory = Value("trail")
State.cosmeticCloseHovered = Value(false)

-- Teleport modal
State.teleportModalVisible, State.teleportModalMounted, State.teleportModalAnimationGoal, State.teleportModalAnimation =
	declareModal()
State.teleportCloseHovered = Value(false)

-- Revive modal
State.reviveModalVisible, State.reviveModalMounted, State.reviveModalAnimationGoal, State.reviveModalAnimation =
	declareModal()
State.reviveStage = Value(0)
-- Số giây còn lại (đã làm tròn lên) để hiện chữ "5s", "4s"…
State.reviveCountdown = Value(0)
-- Cùng bộ đếm nhưng ở dạng 0..1 cho thanh thời gian trôi mượt. Tách riêng vì
-- reviveCountdown chỉ nhảy theo bước 1 giây — bám vào nó thì thanh giật 5 nấc.
State.reviveCountdownFraction = Value(1)
State.reviveRobuxProductId = Value(0)
State.reviveRobuxPrice = Value(0)
State.reviveAdRewardProductId = Value(0)
-- Gamepass Infinite Revives: hồi sinh miễn phí, không giới hạn số lần.
State.reviveFree = Value(false)
State.reviveAdAvailable = Value(false)
State.reviveCloseHovered = Value(false)
State.reviveRobuxHovered = Value(false)
State.reviveAdHovered = Value(false)
State.reviveCountdownToken = 0

-- Shop modal
State.shopModalVisible, State.shopModalMounted, State.shopModalAnimationGoal, State.shopModalAnimation = declareModal()
State.shopCloseHovered = Value(false)

-- Daily login modal
State.dailyModalVisible, State.dailyModalMounted, State.dailyModalAnimationGoal, State.dailyModalAnimation =
	declareModal()
State.dailyCloseHovered = Value(false)
State.dailyClaimHovered = Value(false)
State.dailyStreakDay = Value(0)
State.dailyCanClaim = Value(false)
State.dailyNextDay = Value(1)

-- Group Chest modal
State.groupChestModalVisible, State.groupChestModalMounted, State.groupChestModalAnimationGoal, State.groupChestModalAnimation =
	declareModal()
State.groupChestCloseHovered = Value(false)
State.groupChestJoinHovered = Value(false)
State.groupChestClaimHovered = Value(false)
State.groupChestIsGroupMember = Value(false)
State.groupChestHasClaimed = Value(false)

-- Code modal
State.codeModalVisible, State.codeModalMounted, State.codeModalAnimationGoal, State.codeModalAnimation = declareModal()
State.codeCloseHovered = Value(false)
State.codeRedeemHovered = Value(false)
State.codeInput = Value("")
State.isEnteringCode = false

-- Roulette modal
State.rouletteModalVisible, State.rouletteModalMounted, State.rouletteModalAnimationGoal, State.rouletteModalAnimation =
	declareModal()
State.rouletteCloseHovered = Value(false)
State.rouletteSpinHovered = Value(false)
State.rouletteTickets = Value(0)
State.rouletteNextFreeSeconds = Value(-1) -- -1 = đầy cap (không đếm)
State.rouletteNextFreeReceivedAt = Value(0) -- os.clock() lúc nhận state (đếm ngược cục bộ)
State.rouletteSpinning = Value(false)
State.rouletteResultText = Value("")

-- Server/Personal Boosts (deadline theo os.clock; client tự đếm ngược)
State.boostServerSpeedUntil = Value(0)
State.boostServerWinsUntil = Value(0)
State.boostPersonalSpeedUntil = Value(0)
State.boostPersonalWinsUntil = Value(0)
State.boostClockNow = Value(0) -- cập nhật ~4 lần/giây trong HUDController

--[[
	Starter Pack "Rookie Rocket".
	`starterPackDeadline` là mốc theo `os.clock()` cục bộ = lúc nhận gói tin + secondsLeft;
	thẻ đếm ngược bằng `boostClockNow` (đã có sẵn nhịp 4 lần/giây) nên không cần vòng lặp
	thứ hai chỉ để nhích một con số.
]]
State.starterPackDeadline = Value(0)
State.starterPackBought = Value(false)
State.starterPackConfigured = Value(false)

--[[
	Modal chi tiết của gói (tách 2026-08-12). Trên HUD giờ chỉ còn một ICON nhỏ (giá giảm +
	đồng hồ); toàn bộ danh sách phần thưởng và nút mua chuyển vào modal này — góc phải trên
	đã có Spin + Playtime Boost, một tấm thẻ 300×268 nằm thường trực ở đó che mất cả khoảng
	nhìn của người chơi.
]]
--[[
	Bước 1 của tutorial ("bấm CLAIM nhận quà Ngày 1") đang chạy. `TutorialController` bật cờ
	này lúc mở cửa Daily và tắt khi cửa đóng; `DailyModal` dùng nó để hiện mũi tên chỉ vào nút
	CLAIM. Cờ nằm ở State (không phải trong TutorialController) vì mũi tên phải sống TRONG
	modal — nó cần đi theo modal khi UIScale co lại, và cần biến mất cùng modal.
]]
State.tutorialClaimHint = Value(false)

State.starterPackModalVisible, State.starterPackModalMounted, State.starterPackModalAnimationGoal, State.starterPackModalAnimation =
	declareModal()
State.starterPackCloseHovered = Value(false)
State.starterPackBuyHovered = Value(false)

-- Event thời vụ (RemoteConfigService đẩy xuống qua packet eventState).
-- eventName = "" ⇒ không có event ⇒ HUD ẩn dòng Event.
State.eventName = Value("")
State.eventSpeedMultiplier = Value(1)
State.eventWinsMultiplier = Value(1)

-- ── Modal Cài đặt (Settings) ─────────────────────────────────────────────────
State.settingsModalVisible, State.settingsModalMounted, State.settingsModalAnimationGoal, State.settingsModalAnimation =
	declareModal()
State.settingsCloseHovered = Value(false)
-- Tab đang mở: "display" | "audio" (tab ÂM THANH dựng lại 2026-08-07 trên nền
-- `AudioMixController` — bản mixer cũ gỡ ngày 2026-08-05 là bản bắt mọi controller gọi qua
-- helper chung, khác hẳn; xem đầu file AudioMixController).
State.settingsTab = Value("display")

State.musicEnabled = Value(true)
State.performanceMode = Value(false)
State.nightMode = Value(false)

-- ── Bàn trộn âm thanh (0..1, khớp AudioMixController.SetVolume) ──────────────
State.volMaster = Value(1)
-- Nhạc KHÔNG mặc định 100%: xem `AudioMixController.DEFAULT_MUSIC` — mức cân với tiếng sàn
-- ASMR nằm ở đó, và phải require chứ không chép số, nếu không slider hiển thị một đằng còn
-- SoundGroup kêu một nẻo.
State.volMusic = Value(AudioMixController.DEFAULT_MUSIC)
State.volAsmr = Value(1)
-- ĐÃ GỠ 2026-08-09: `volSfx` (slider "UI & Effects") và `muteOnBlur`. Kênh `sfx` trong
-- AudioMixController vẫn còn và đứng yên ở 1 — chỉ thanh trượt bị bỏ.
-- `musicEnabled` giờ là giá trị SUY RA từ slider Music (>0 = bật), xem SettingsModal.

-- Sound Lab: bộ lọc + mục đang phát (để tô sáng dòng).
State.labFilter = Value("all")
State.labSearch = Value("")
State.labPlayingId = Value(0)

-- Janitor cho HUD
State.sweeper = Janitor.new()

State.lastSpeed = 0

function State.GetSnapshot(): Snapshot
	return State.snapshot:get()
end

function State.SyncCustomSpeedDraft(speed: number)
	State.customSpeedDraft:set(tostring(math.floor(speed)))
end

return State
