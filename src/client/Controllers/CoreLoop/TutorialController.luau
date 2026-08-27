--!strict
--[[
	TutorialController.luau — phần NHÌN THẤY của tutorial (logic ở TutorialService).

	── MẠCH CHẠY (bước 5/5 thêm 2026-08-27) ───────────────────────────────────────────────
	    Vào game  →  1/5  thảm mũi tên tới WinCollectionPad của Zone 1   (+1 Win)
	              →  (chốt Wins xong game tự teleport về Lobby)
	              →  2/5  tới Multiplier Pad 2, tiêu đúng 1 Win vừa kiếm  (+2 Speed/bước)
	              →  3/5  tới Treadmill x1                                (Speed tự chảy)
	              →  4/5  SPOTLIGHT nút Daily → SPOTLIGHT nút CLAIM       (+1.000 Speed, +2 Wins)
	              →  hai câu chốt (vòng lặp + mồi quay lại mai)
	              →  5/5  SPOTLIGHT nút Spin → SPOTLIGHT nút SPIN         (tiêu vé chào mừng)
	              →  Group Chest.

	Mỗi bước TO HƠN bước trước, và bước 1 tự nuôi bước 2 — đó là toàn bộ thiết kế.

	⚠️ Daily TRƯỚC ĐÂY mở ngay lúc spawn và chặn người chơi tới khi bấm CLAIM. Đã chuyển xuống
	cuối (lý do đầy đủ ở `runDailyFinale`). Đừng đưa lại lên đầu mà không đọc khối đó.

	── HAI KIỂU DẪN ĐƯỜNG ────────────────────────────────────────────────────────────────
	  1. NGOÀI MAP → THẢM MŨI TÊN: Beam nằm ngang trên mặt đất, chevron chảy về phía đích, kèm
	     mũi tên nhấp nhô phía trên mục tiêu — trẻ 9 tuổi không cần biết đọc vẫn đi theo được.
	  2. TRONG HUD → SPOTLIGHT: làm tối cả màn hình, chừa đúng cái nút cần bấm (`HUD/Spotlight`).
	     Chỉ dùng cho bước 4/4, và là chỗ DUY NHẤT tutorial chặn thao tác — vì ở đó chỉ có đúng
	     một việc đáng làm là bấm nhận quà.

	Ngoài bước 4/4, nguyên tắc vẫn là KHÔNG chặn: không hộp thoại, không khoá điều khiển; chỉ
	một dải nhắc mỏng trên đỉnh màn hình với một câu và một nút SKIP.

	── HÌNH HỌC CỦA THẢM MŨI TÊN ─────────────────────────────────────────────────────────
	Beam mặc định dựng ĐỨNG (hoặc `FaceCamera` = luôn quay về camera) — cả hai đều thành một
	dải ruy băng lơ lửng, không ra "đường đi". Muốn nó NẰM PHẲNG trên mặt đất như trong ảnh
	tham chiếu thì phải tự đặt hướng cho hai Attachment mỗi khung hình:

	    dir = hướng ngang từ người chơi tới đích
	    up  = dir × Vector3.yAxis        (nằm ngang, vuông góc dir ⇒ mặt beam nằm ngang)
	    WorldCFrame = CFrame.fromMatrix(pos, dir, up)

	⚠️ Chiều mũi tên: đã ĐO trong Studio — chevron của texture luôn chỉ về phía **Attachment0**.
	Nên Attachment0 = ĐÍCH, Attachment1 = người chơi (không phải chiều trực giác).

	── BẪY STREAMING ─────────────────────────────────────────────────────────────────────
	`Workspace.StreamingEnabled = true`, nên mục tiêu bước 1 (WinCollectionPad ở z≈316)
	THƯỜNG CHƯA TỒN TẠI lúc người chơi còn ở Lobby. Vì vậy mục tiêu được resolve LẶP LẠI mỗi
	`RESOLVE_INTERVAL` giây chứ không phải một lần lúc Start(), và mỗi bước có thêm
	`fallbackPath` — một cột mốc gần hơn (vạch xuất phát Stage 1) để chỉ tạm khi cái đích
	thật còn nằm ngoài vùng stream. Bám vào một tham chiếu lấy lúc khởi động là tutorial chết
	câm đúng ở bước 1 — bước quan trọng nhất.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local Manager = require(script.Parent.Parent.HUD.Modals.Manager)
local State = require(script.Parent.Parent.HUD.State)
local Spotlight = require(script.Parent.Parent.HUD.Spotlight)
local Toast = require(script.Parent.Parent.HUD.Toast)
local UIAnchors = require(script.Parent.Parent.HUD.UIAnchors)

local LocalPlayer = Players.LocalPlayer

local TutorialController = {}

local RESOLVE_INTERVAL = 1.0

-- Texture mũi tên lấy từ `Workspace.Arrow` (Part trang trí có sẵn trong place): chevron.
local ARROW_TEXTURE = "rbxassetid://10051771444"
-- Cạnh mũi tên tính bằng DESIGN px (bản vẽ 1920×1080). Cỡ thật = số này × `viewportScale`.
local ARROW_SIZE = 90

type StepConfig = {
	text: string,
	targetPath: { string },
	-- Cột mốc chỉ tạm khi `targetPath` chưa được stream về (xem khối BẪY STREAMING).
	fallbackPath: { string }?,
}

--[[
	Chỉ số = SỐ BƯỚC ĐÃ XONG. step=0 ⇒ đang làm bước 1.

	Thứ tự cố ý đi NGƯỢC với kiểu tutorial simulator thường thấy (farm trước, chạy sau):
	bước 1 ném thẳng người chơi vào Obby + khoảnh khắc ăn Wins, tức là phần VUI nhất và
	cũng là phần khác biệt nhất của game, trong vòng một phút đầu. Cày cuốc (Pad, Treadmill)
	để sau, khi họ đã có lý do để cày.
]]
--[[
	BƯỚC 4 — "nhận quà Daily", nằm ở CUỐI (user chốt 2026-08-17; trước đó nó ở ĐẦU phiên).

	Toàn bộ lý do đổi chỗ + cách dẫn bằng spotlight nằm ở `runDailyFinale` phía dưới.

	Bước này chỉ sống ở CLIENT — server vẫn đúng 3 bước (`TutorialService.STEP_INDEX`), và
	tuyệt đối không được thêm vào đó: thứ tự các bước ở server là khoá của dữ liệu phễu lịch
	sử, chèn một bước vào giữa là mọi số liệu trước đó đọc sai. Client chỉ tự cộng thêm MỘT
	bước hiển thị ở cuối, nên server bước 0 ⇒ người chơi thấy "1/4".
]]

--[[
	══ CÁCH VIẾT CÂU NHẮC (làm lại 2026-08-17) ══════════════════════════════════════════════

	Ba luật, rút ra từ chỗ bản cũ dở:

	  1. HỨA PHẦN THƯỞNG TRƯỚC KHI SAI VIỆC. Bản cũ ra lệnh khan ("Run Stage 1, then stomp the
	     gold pad to bank your Wins") — người chơi làm vì bị bảo làm. Bản mới nói họ ĐƯỢC GÌ
	     ("your first Win is waiting"), nên mỗi bước là một lời mời chứ không phải một mệnh lệnh.

	  2. NÓI BẰNG CON SỐ HỌ ĐANG CÓ. "You've got 1 Win — spend it" đọc xong là làm được ngay,
	     không phải tự kiểm kho rồi tính nhẩm. Bản cũ ("unlock Multiplier Pad 2 to farm faster")
	     bắt người chơi tự hiểu Pad là gì, giá bao nhiêu, và "farm" nghĩa là gì.

	  3. MỖI BƯỚC PHẢI TO HƠN BƯỚC TRƯỚC. 1 Win → gấp đôi mỗi bước chân → Speed tự chảy → 1.000
	     Speed miễn phí. Đường dốc lên đó là thứ giữ người chơi tới hết tutorial.

	⚠️ Giữ MỖI CÂU MỘT VIỆC. Dải nhắc cao 92 design px, hai dòng là hết chỗ; nhồi hai việc vào
	một câu thì trên điện thoại chữ co lại còn không đọc nổi.

	══ KHUÔN "VIỆC → THƯỞNG", MỘT DÒNG (rút gọn 2026-08-24) ═════════════════════════════════

	User: câu chữ phải ngắn gọn dễ hiểu. Ba câu cũ dài 45–66 ký tự và mỗi câu một kiểu ngữ pháp
	(mệnh lệnh / khoe số / rủ rê), nên người chơi phải ĐỌC HẾT mới biết mình cần làm gì.

	Giờ cả ba dùng chung đúng một khuôn, mũi tên là chỗ mắt nhảy tới:
	    <VIỆC PHẢI LÀM> → <THỨ NHẬN ĐƯỢC>
	Đọc lướt qua mũi tên là đủ hiểu, không cần đọc trọn câu. Ba luật trên vẫn còn nguyên: vế
	phải mũi tên CHÍNH LÀ phần thưởng (luật 1), vẫn là con số thật (luật 2), và vẫn lớn dần
	(luật 3): 1 Win → gấp đôi mỗi bước → Speed tự chảy.

	Thêm câu mới thì giữ khuôn này; đừng quay lại lối viết một câu trọn vẹn.
]]
local STEPS: { StepConfig } = {
	{
		text = "Run Stage 1, stomp the gold pad → 1 Win!",
		targetPath = { "Zones", "Zone1", "Mechanics", "WinCollectionPad" },
		fallbackPath = { "Zones", "Zone1", "Mechanics", "Stage1Start" },
	},
	{
		--[[
			Chốt Wins xong là tự teleport về Lobby, nên bước này bắt đầu ngay tại Lobby.

			"1 Win" trong câu là con số THẬT: Stage 1 trả đúng 1 Win và Pad 2 giá đúng 1 Win
			(xem `MultiplierPads`). Sửa một trong hai con số đó thì phải sửa câu này theo, nếu
			không tutorial nói dối ngay ở bước có người chơi bỏ cuộc nhiều nhất.
		]]
		text = "Spend 1 Win on Pad 2 → every step pays DOUBLE!",
		targetPath = { "Lobby", "MultiplierPads", "Pad_2", "PadPart" },
	},
	{
		-- KHÔNG viết "last step" nữa: sau bước này còn bước nhận quà Daily (4/4).
		text = "Hop on the treadmill → Speed pours in!",
		targetPath = { "Lobby", "Treadmills", "Treadmill_x1", "Hitbox" },
	},
}

--[[
	Số đo dải nhắc, tính bằng DESIGN px trên bản vẽ 1920×1080.

	`BANNER_TOP_MARGIN` / `BANNER_MODAL_MARGIN` là LỀ TÍNH TỪ MÉP TRÊN KHẢ DỤNG của màn hình (mép
	đã trừ topbar Roblox — xem `Responsive.Screen`). Trên PC cho ra y = 36 + 96 = 132 và
	36 + 8 = 44, đúng vị trí bản thiết kế đang chạy.

	Hai làn, chọn theo NỘI DUNG (có modal mở hay không), KHÔNG theo loại máy:
	  • 96 — làn thường, nằm dưới làn toast.
	  • 8  — khi có modal mở: nhích sát đỉnh để không đè thanh tiêu đề + nút X của modal.
	    (`Theme.MODAL_TUTORIAL_RESERVE` = 8 + 92 + 8 = 108 chính là chỗ dải này chiếm.)
]]
local BANNER_TOP_MARGIN = 56
local BANNER_MODAL_MARGIN = 8
-- Màu nền nút SKIP. MỘT chỗ khai duy nhất: `MouseLeave` phải trả về đúng nó (xem lý do ở đó).
local SKIP_COLOR = Color3.fromRGB(255, 176, 40)
local SKIP_HOVER_COLOR = Color3.fromRGB(255, 205, 90)

local BANNER_WIDTH = 860
local BANNER_HEIGHT = 92

local screenGui: ScreenGui?
local banner: Frame?
local bannerLabel: TextLabel?
local counterLabel: TextLabel?

local beam: Beam?
local originAttachment: Attachment?
local targetAttachment: Attachment?
local targetHolder: Part? -- part vô hình neo Attachment0 (mục tiêu có thể bị stream out)
local arrowGui: BillboardGui?

--[[
	Mũi tên là Instance thô trong Workspace nên KHÔNG tự co theo `viewportScale` như HUD — phải
	ghi lại bằng tay mỗi khi tỉ lệ đổi (đổi cỡ cửa sổ, xoay máy), và ngay lúc vừa dựng nó.
]]
local function applyArrowScale()
	if arrowGui then
		local size = math.round(ARROW_SIZE * State.viewportScale:get())
		arrowGui.Size = UDim2.fromOffset(size, size)
	end
end

local currentStep = 0
-- Bước đã vẽ gần nhất — để biết khi nào là TIẾN LÊN (đáng ăn mừng) chứ không phải vẽ lại.
local lastRenderedStep = -1
local isActive = false
local guidesVisible = false
local resolveAccumulator = 0
local arrowClock = 0
local currentTarget: BasePart? -- mục tiêu đã resolve ở lần refresh gần nhất

local function create(className: string, properties: { [string]: any }?, parent: Instance?): Instance
	local instance = Instance.new(className)
	if properties then
		for key, value in properties do
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function resolvePath(path: { string }): BasePart?
	local node: Instance? = Workspace
	for _, segment in path do
		if not node then
			return nil
		end
		node = node:FindFirstChild(segment)
	end
	if node and node:IsA("BasePart") then
		return node
	end
	return nil
end

-- ============================================================================
-- Dựng giao diện
-- ============================================================================

local function buildUI()
	if screenGui then
		return
	end

	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local gui = create("ScreenGui", {
		Name = "TutorialGui",
		-- 130 > 120 cua `SpotlightGui`: dai nhac + nut SKIP phai nam TREN lop toi, neu khong cau
		-- huong dan bi mo di dung luc can doc nhat va SKIP thi bi lop che nuot mat.
		DisplayOrder = 130,
		--[[
			`false` = ĐỂ ROBLOX TỰ ĐẨY XUỐNG DƯỚI TOPBAR.

			Đã thử tự tính (`IgnoreGuiInset = true` + cộng `GetGuiInset().Y`) và HỎNG: hàm đó trả
			về 0 trong VM của HUD lúc dựng, còn `State.guiInsetTop` cũng đứng ở 0 — đo được dải
			nhắc rơi vào y = 20 trong khi topbar cao 58, tức nằm ĐÈ lên topbar.

			Để `false` thì gốc toạ độ y = 0 CHÍNH LÀ mép dưới topbar, do engine tự lo và tự cập
			nhật khi topbar đổi cỡ. Không còn con số nào để sai.
		]]
		IgnoreGuiInset = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui) :: ScreenGui

	--[[
		Dải nhắc: neo TRÊN ĐỈNH, giữa màn hình. Không đè lên cụm nút trái/phải của HUD.

		── PHONG CÁCH (làm lại 2026-08-12 theo yêu cầu user) ──────────────────────────────
		Bản đầu là một dải xám mảnh cao 62px, chữ tối đa 22px, font Gotham thường — nhìn như
		thông báo hệ thống của Roblox chứ không phải của game này. Dải này phải nói cùng thứ
		"tiếng" với HUD, tức là bộ quy tắc trong `HUD/Theme`:
		  • thân tối (18,18,30) + VIỀN ĐEN dày 4 + bo góc 18 (mọi panel trong game đều thế),
		  • hoạ tiết STUDS mờ tile 30px phủ lên nền,
		  • badge số bước = ô VÀNG (255,205,46) có gradient + viền đen, giống mọi pill vàng,
		  • chữ GothamBlack + viền đen (UIStroke), không phải TextStrokeTransparency mờ.
		File này dựng UI bằng Instance thô (không Fusion) nên phải chép tay các helper đó —
		đổi Theme thì nhớ ngó lại đây.

		Cỡ: cao 62 → 92, chữ tối đa 22 → 34. Bề rộng đổi sang co theo màn hình
		(`Size.X.Scale`) + `UISizeConstraint`: bản cũ để offset CỨNG 560px nên trên điện thoại
		nó không co được chút nào — `MaxSize` chỉ chặn trên, không kéo xuống.
	]]
	--[[
		══ DẢI NHẮC ĐI THEO ĐÚNG LUẬT CỦA CẢ HUD (làm lại 2026-08-17) ═══════════════════════

		File này dựng Instance THÔ, không nằm trong canvas 1920×1080 của HUD nên không được
		`UIScale` co giúp. Vì thế nó tự nhân mọi con số với `k()`.

		⚠️ `k()` PHẢI là `State.viewportScale` — ĐÚNG hệ số mà cả HUD đang dùng. Bản cũ tự tính
		một hệ số riêng (`bannerK` = chiều cao ScreenGui / 1080, kẹp 0.45): hai công thức khác
		nhau nghĩa là dải nhắc co theo một nhịp còn HUD co theo nhịp khác, nên trên máy này nó
		to hơn bản vẽ, máy kia nhỏ hơn. Giờ chỉ còn MỘT tỉ lệ trong cả game.

		Mọi con số dưới đây là DESIGN px của bản vẽ 1920×1080, giống hệt mọi file HUD khác.
	]]
	local function k(value: number): number
		return math.round(value * State.viewportScale:get())
	end

	--[[
		══ ĐÃ BỎ: "MÀN HÌNH NHỎ ⇒ DẢI NHẮC XUỐNG ĐÁY" ══════════════════════════════════════

		Bản 2026-08-14 cho dải nhảy xuống đáy khi `viewportScale < 0.75`. Đó là một BỐ CỤC RIÊNG
		CHO MOBILE — đúng thứ user bác ngày 2026-08-17 ("bê nguyên UI 1920×1080 xuống"). Và nó
		hỏng thật: ảnh user chụp trên iPhone XR cho thấy dải ở đáy đè lên dòng hệ số nhân và cắt
		ngang nút CLAIM của modal Daily.

		Lý do bản cũ phải né xuống đáy là vì hồi đó bản vẽ bị CẮT trên máy nhỏ nên làn đỉnh chật.
		Giờ bản vẽ luôn nguyên vẹn, làn đỉnh trên điện thoại rộng đúng như trên PC — không còn gì
		để né. Chỉ còn HAI làn, và chúng chọn theo NỘI DUNG (có modal hay không), không theo máy.
	]]
	local frame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(18, 18, 30),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		-- Vị trí thật do `applyDock` ghi (nó cần cả chiều cao topbar), đây chỉ là giá trị ban đầu.
		Position = UDim2.new(0.5, 0, 0, k(BANNER_TOP_MARGIN)),
		Size = UDim2.fromOffset(k(BANNER_WIDTH), k(BANNER_HEIGHT)),
		Visible = false,
		ZIndex = 2,
	}, gui) :: Frame
	local frameCorner = create("UICorner", { CornerRadius = UDim.new(0, k(18)) }, frame) :: UICorner
	local frameStroke = create("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = k(4) }, frame) :: UIStroke
	-- Hoạ tiết studs: phải bo góc theo thân, không thì bốn góc vuông thò ra ngoài bo tròn.
	--[[
		⚠️ `TileSize` PHẢI theo SCALE, không được theo Offset.

		Bản cũ để `fromOffset(30, 30)`: 860 / 30 = 28,67 ô ⇒ cột cuối bị CẮT DỞ, và hàng dưới
		cũng dở (92 / 30 = 3,07). Mắt đọc mấy ô dở đó thành "nền bị lỗi" — đúng thứ user báo.
		Trên điện thoại còn tệ hơn: dải co lại còn ~36% mà ô vẫn 30 px thật, nên hoạ tiết to
		gần bằng cả chiều cao dải.

		Chia theo tỉ lệ thì `1/29` và `1/3` chia hết TUYỆT ĐỐI ở mọi cỡ màn hình. Đây đúng là
		cách `Theme.MakeStudsPattern` đã chốt cho cả HUD — xem khối lý do dài ở đó.
	]]
	local STUD_COLUMNS = math.round(BANNER_WIDTH / 30) -- 860 / 30 ≈ 29 ô ngang
	local STUD_ROWS = math.round(BANNER_HEIGHT / 30) -- 92 / 30 ≈ 3 ô dọc
	local studs = create("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://6372755229",
		--[[
			0.94 chứ không phải 0.88 (2026-08-17).

			Cả HUD chỉ đặt hoa văn studs lên panel MÀU (header vàng, thẻ xanh…), nơi nó chìm vào
			nền. Dải nhắc thì nền gần đen (18,18,30), nên cùng độ mờ ấy các mấu TRẮNG nổi bật lên
			thành một tấm ca-rô — user đọc ra là "texture nền bị lỗi", và đúng là nó phá phong cách
			chung chứ không giống bất cứ khối nào khác trong game.
		]]
		ImageTransparency = 0.94,
		ScaleType = Enum.ScaleType.Tile,
		Size = UDim2.fromScale(1, 1),
		TileSize = UDim2.fromScale(1 / STUD_COLUMNS, 1 / STUD_ROWS),
		ZIndex = 2,
	}, frame)
	create("UICorner", { CornerRadius = UDim.new(0, k(18)) }, studs)

	--[[
		Badge số bước. Nền và CHỮ phải là hai Instance rời: `UIGradient` nhuộm cả chữ của
		TextLabel/TextButton chứ không riêng nền, nên gắn gradient thẳng lên label là con số
		bị đổ màu vàng luôn — không đọc được trên nền vàng. (Cũng vì thế mà `Theme.MakeButton`
		để `Text = ""` rồi treo một label con.)
	]]
	local counterBadge = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 205, 46),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(k(14), k(20)),
		Size = UDim2.fromOffset(k(76), k(52)),
		ZIndex = 3,
	}, frame) :: Frame
	local badgeCorner = create("UICorner", { CornerRadius = UDim.new(0, k(12)) }, counterBadge) :: UICorner
	local badgeStroke =
		create("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = k(4) }, counterBadge) :: UIStroke
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 238, 77), Color3.fromRGB(255, 162, 28)),
		Rotation = 90,
	}, counterBadge)

	counterLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Size = UDim2.fromScale(1, 1),
		Text = "1/3",
		TextColor3 = Color3.fromRGB(48, 30, 0),
		TextScaled = true,
		ZIndex = 4,
	}, counterBadge) :: TextLabel
	local counterTextConstraint =
		create("UITextSizeConstraint", { MaxTextSize = k(30), MinTextSize = 1 }, counterLabel) :: UITextSizeConstraint

	bannerLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(k(102), k(14)),
		Size = UDim2.new(1, -k(222), 0, k(64)),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, frame) :: TextLabel
	local bannerTextConstraint =
		create("UITextSizeConstraint", { MaxTextSize = k(34), MinTextSize = 1 }, bannerLabel) :: UITextSizeConstraint
	local bannerStroke =
		create("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = k(3) }, bannerLabel) :: UIStroke

	local skip = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = SKIP_COLOR,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(1, -k(14), 0.5, 0),
		Size = UDim2.fromOffset(k(96), k(48)),
		Text = "",
		ZIndex = 3,
	}, frame) :: TextButton
	local skipCorner = create("UICorner", { CornerRadius = UDim.new(0, k(12)) }, skip) :: UICorner
	local skipStroke = create("UIStroke", { Color = Color3.fromRGB(18, 18, 30), Thickness = k(5) }, skip) :: UIStroke
	--[[
		SKIP đổi từ XÁM sang VÀNG-CAM (2026-08-14, user: "chỉnh màu nổi bật hơn nhưng vẫn cùng
		tone màu"). Xám (88,92,116) là màu duy nhất trong cả HUD không thuộc bảng màu game —
		nó chìm vào nền tối của chính dải nhắc. Vàng-cam 255,176,40 → 255,120,20 chính là
		gradient của badge số bước ngay bên trái, nên hai đầu dải cân nhau.
		Viền dày 5 + màu 18,18,30 = đúng chuẩn `Theme.MakeButton` của mọi nút khác trong game.
	]]
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 70), Color3.fromRGB(255, 120, 20)),
		Rotation = 90,
	}, skip)

	local skipLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Size = UDim2.fromScale(1, 1),
		Text = "SKIP",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		ZIndex = 4,
	}, skip) :: TextLabel
	local skipTextConstraint =
		create("UITextSizeConstraint", { MaxTextSize = k(24), MinTextSize = 1 }, skipLabel) :: UITextSizeConstraint
	local skipLabelStroke =
		create("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = k(3) }, skipLabel) :: UIStroke
	-- Sáng lên khi rê chuột: AutoButtonColor tắt (nó chỉ đổi BackgroundColor3, mà nền nút đã
	-- bị UIGradient phủ lên nên bấm vào trông như không có phản hồi).
	skip.MouseEnter:Connect(function()
		skip.BackgroundColor3 = SKIP_HOVER_COLOR
	end)
	skip.MouseLeave:Connect(function()
		--[[
			⚠️ PHẢI trả về ĐÚNG màu nền của nút (`SKIP_COLOR`).

			Bản cũ trả về (88, 92, 116) — màu XÁM của thời nút còn xám, trước khi nó đổi sang
			vàng-cam ngày 2026-08-14. Hệ quả: rê chuột qua MỘT lần là nút xám xịt vĩnh viễn,
			lệch hẳn khỏi bảng màu game. Đây là lỗi user báo "button skip bị lỗi".
		]]
		skip.BackgroundColor3 = SKIP_COLOR
	end)

	skip.Activated:Connect(function()
		-- Server vẫn phát thưởng cho người skip (thiết kế: không trừng phạt), nên đây chỉ
		-- là một yêu cầu — không tự ẩn UI, đợi server xác nhận qua tutorialState.
		GamePackets.requestTutorialSkip.send({})
	end)

	screenGui = gui
	--[[
		Bám theo trạng thái modal trong suốt phiên. Đặt SAU khi dựng xong `frame` vì callback
		ghi thẳng vào nó. `Observer` chứ không `Computed`: đây là hành động (dời một Instance
		thường, không phải thuộc tính Fusion), và `create()` ở file này dựng Instance thô.
	]]
	--[[
		HAI LÀN, chọn theo NỘI DUNG chứ không theo máy (xem khối "ĐÃ BỎ" ở trên):

		  • đang mở modal   → `BANNER_MODAL_Y`, sát đỉnh, để không đè tiêu đề + nút X của modal.
		  • không có modal  → `BANNER_TOP_Y`, làn thường.

		⚠️ Toạ độ phải đi qua ĐÚNG phép ánh xạ của canvas HUD:

		    y thật = canvasOffsetY + y_design × scale

		`canvasOffsetY` là khoảng cả tấm canvas bị đẩy xuống để thoát topbar (xem
		`Responsive.Solve`). Bỏ nó ra thì dải nhắc lệch khỏi HUD đúng bằng chừng đó — trên điện
		thoại là 39px thật, đủ để nó chui vào topbar trong khi HUD thì không.

		Vì vậy `ScreenGui` phải để `IgnoreGuiInset = true`: nếu để `false`, Roblox tự cộng thêm
		chiều cao topbar và phép ánh xạ trên bị cộng hai lần.
	]]
	local function applyDock()
		local margin = if State.anyModalOpen:get() then BANNER_MODAL_MARGIN else BANNER_TOP_MARGIN
		--[[
			Bám MÉP TRÊN MÀN HÌNH, giống mọi cụm HUD khác — chỉ khác là file này dựng Instance thô
			nên phải tự quy đổi thay vì gọi `Responsive.Anchor`:

			    y thật = chiều cao topbar (px thật, KHÔNG co) + lề × scale

			Topbar là vật lý nên cộng nguyên; lề là số của bản vẽ nên nhân `scale`. Trộn hai đơn vị
			này chính là lỗi kinh điển của file — bản cũ nhân cả topbar theo tỉ lệ nên dải nhắc chui
			vào topbar trên điện thoại.
		]]
		-- y = 0 đã là mép dưới topbar (`IgnoreGuiInset = false`), nên chỉ còn lề của bản vẽ.
		frame.Position = UDim2.new(0.5, 0, 0, k(margin))
		frame.Size = UDim2.fromOffset(k(BANNER_WIDTH), k(BANNER_HEIGHT))
	end

	--[[
		⚠️ RUỘT DẢI NHẮC PHẢI CO LẠI CÙNG LÚC VỚI VỎ — nếu không, banner vỡ (2026-08-18).

		`k()` chỉ được tính MỘT LẦN, ngay lúc `create()` chạy. Trước bản này chỉ có `applyDock`
		nghe `viewportScale`, mà nó lại chỉ ghi đè `frame.Position` + `frame.Size`. Mọi con của
		dải (badge, chữ, nút SKIP, mọi UICorner/UIStroke/UITextSizeConstraint) giữ nguyên con số
		đã nướng lúc dựng, VĨNH VIỄN.

		Hậu quả thật (ảnh user chụp ở chế độ Client & Server): `TutorialController` dựng banner
		trước khi `Workspace.CurrentCamera.ViewportSize` kịp có giá trị thật, nên `Responsive.Solve`
		trả về `Tokens.MIN_SCALE` = 0,12. Vỏ sau đó được `applyDock` sửa về đúng cỡ (860×92 × 0,73),
		nhưng ruột vẫn ở 12%: chữ `MaxTextSize` = 4 px, badge 9×6, nút SKIP 12×6. Nhìn ra đúng
		"một ô đen có dòng chữ li ti ở góc và một chấm cam bên phải".

		Đây KHÔNG chỉ là lỗi lúc khởi động: mọi lần đổi cỡ cửa sổ / xoay điện thoại đều làm
		`viewportScale` đổi, và trước bản này ruột dải không bao giờ theo kịp.

		Vì vậy mọi thuộc tính phụ thuộc `k()` phải nằm TRONG hàm này, và hàm này phải chạy lại
		mỗi khi tỉ lệ đổi. Thêm phần tử mới vào dải thì cũng phải khai báo cỡ ở đây.
	]]
	local function applyBannerScale()
		frameCorner.CornerRadius = UDim.new(0, k(18))
		frameStroke.Thickness = k(4)

		counterBadge.Position = UDim2.fromOffset(k(14), k(20))
		counterBadge.Size = UDim2.fromOffset(k(76), k(52))
		badgeCorner.CornerRadius = UDim.new(0, k(12))
		badgeStroke.Thickness = k(4)
		counterTextConstraint.MaxTextSize = k(30)

		bannerLabel.Position = UDim2.fromOffset(k(102), k(14))
		bannerLabel.Size = UDim2.new(1, -k(222), 0, k(64))
		bannerTextConstraint.MaxTextSize = k(34)
		bannerStroke.Thickness = k(3)

		skip.Position = UDim2.new(1, -k(14), 0.5, 0)
		skip.Size = UDim2.fromOffset(k(96), k(48))
		skipCorner.CornerRadius = UDim.new(0, k(12))
		skipStroke.Thickness = k(5)
		skipTextConstraint.MaxTextSize = k(24)
		skipLabelStroke.Thickness = k(3)
	end
	applyArrowScale()
	State.sweeper:Add(Fusion.Observer(State.viewportScale):onChange(applyArrowScale))

	-- Ruột dải nhắc: dựng xong áp ngay một lần, rồi bám `viewportScale` suốt phiên.
	applyBannerScale()
	State.sweeper:Add(Fusion.Observer(State.viewportScale):onChange(applyBannerScale))

	State.sweeper:Add(Fusion.Observer(State.anyModalOpen):onChange(applyDock))
	-- Đổi cỡ cửa sổ / xoay máy: tỉ lệ đổi ⇒ phải ghi lại vị trí và cỡ (Instance thô không tự
	-- theo Fusion như phần còn lại của HUD).
	State.sweeper:Add(Fusion.Observer(State.viewportScale):onChange(applyDock))
	--[[
		⚠️ PHẢI nghe cả `guiInsetTop`, không chỉ tỉ lệ.

		Topbar Roblox nạp SAU khi HUD dựng xong, và lúc dựng `GetGuiInset()` còn trả 0. Thiếu
		dòng này thì dải nhắc chốt vị trí theo inset = 0 và nằm ĐÈ LÊN topbar suốt phiên chơi —
		đo được y = 20 trong khi topbar cao 58. Cùng một cái bẫy đã ghi ở `State.guiInsetTop`.
	]]
	State.sweeper:Add(Fusion.Observer(State.guiInsetTop):onChange(applyDock))
	applyDock()

	banner = frame
end

-- Mũi tên nhấp nhô + thảm mũi tên. Dựng một lần, sau đó chỉ dời/ẩn hiện.
local function buildWorldGuides()
	if targetHolder then
		return
	end

	local holder = create("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Locked = true,
		Name = "TutorialTargetAnchor",
		Size = Vector3.one,
		Transparency = 1,
	}, Workspace) :: Part

	local attachment = create("Attachment", { Name = "TutorialTarget" }, holder) :: Attachment

	--[[
		DẢI MŨI TÊN. Sống trên `holder` (không phải trên nhân vật) nên respawn không giết nó
		— chỉ cần nối lại `Attachment1`.

		── ĐỔI 2026-08-17 (user): DẢI BAY NGANG THÂN, KHÔNG CÒN LÀ THẢM NẰM ĐẤT ──────────────
		`FaceCamera = true` ⇒ engine tự xoay dải về phía camera mỗi khung hình, nên nhìn từ góc
		nào cũng thấy trọn bề mặt. Bản cũ để `false` rồi tự tính hướng để dải ÚP xuống đất: nhìn
		từ sau lưng nhân vật (góc mặc định) thì nó gần như một đường kẻ mỏng, và bị cỏ/dốc che.

		Kèm theo đó `orientBeam` chỉ còn đặt VỊ TRÍ — hướng do `FaceCamera` lo, tính tay nữa là
		thừa và còn cãi nhau với engine.

		`Attachment0` vẫn là ĐÍCH vì chevron của texture chỉ về phía Attachment0 (đã đo trong
		Studio, xem đầu file), và `TextureSpeed` âm để dòng chảy đi cùng chiều mũi tên.
	]]
	local newBeam = create("Beam", {
		Attachment0 = attachment,
		-- ⚠️ Ánh sáng của map RỬA MÀU rất mạnh (bãi cát sáng + LightEmission): bản đầu để
		-- (255,72,62) ra màn hình thành mũi tên kem nhạt, chìm vào nền cát. Đỏ sẫm hơn ~20%
		-- + LightEmission thấp mới ra đúng sắc đỏ cam của ảnh tham chiếu.
		Color = ColorSequence.new(Color3.fromRGB(226, 34, 30), Color3.fromRGB(255, 96, 26)),
		Enabled = false,
		FaceCamera = true,
		-- Thẳng tuột: đường cong làm dải võng xuống đất ở quãng giữa, đúng thứ vừa bỏ đi.
		CurveSize0 = 0,
		CurveSize1 = 0,
		LightEmission = 0.1,
		LightInfluence = 0,
		Name = "TutorialBeam",
		Segments = 4,
		Texture = ARROW_TEXTURE,
		TextureLength = 8,
		TextureMode = Enum.TextureMode.Wrap,
		TextureSpeed = -1.4,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.85, 0.1),
			-- Nhạt dần ở đầu sát chân người chơi: dải cứng đầu trông như dính vào mặt.
			NumberSequenceKeypoint.new(1, 0.55),
		}),
		--[[
			Hẹp hơn bản thảm (5.5/7 → 3/3.8). Nằm dưới đất thì bề rộng đó đọc ra "lối đi"; bay
			ngang tầm mắt thì nó thành một tấm biển che mất đường chạy phía trước.
		]]
		Width0 = 3, -- ở đích
		Width1 = 3.8, -- ở phía người chơi
		ZOffset = 0.05,
	}, holder) :: Beam

	--[[
		Mũi tên: BillboardGui + `AlwaysOnTop = true`. Luôn quay về camera miễn phí (không tốn
		một phép tính CFrame nào mỗi khung hình) và XUYÊN QUA địa hình — đúng thứ cần cho một
		chỉ dẫn: mục tiêu nằm sau bức tường thì vẫn phải thấy đường mà đi.

		⚠️ Ghi cho lần sau: `screen_capture` của MCP KHÔNG chụp được lớp AlwaysOnTop. Nhìn ảnh
		chụp mà tưởng billboard hỏng là sai — kiểm bằng mắt trên màn hình Studio, hoặc bằng
		`Camera:WorldToViewportPoint` để biết nó có nằm trong khung hình không.
	]]
	--[[
		⚠️ `Size` của BillboardGui là PIXEL MÀN HÌNH, không co theo máy.

		Để cứng 90 px thì trên PC nó chiếm 8% chiều cao màn hình, còn trên điện thoại (392 px)
		là 23% — mũi tên to như cái nhà, che mất chính con đường nó đang chỉ (user 2026-08-17:
		"chưa có responsive"). Nên nó phải nhân `viewportScale` y như mọi thứ khác trong HUD;
		`applyArrowScale` ghi lại mỗi khi tỉ lệ đổi.
	]]
	local arrow = create("BillboardGui", {
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 400,
		Name = "TutorialArrow",
		Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
		StudsOffsetWorldSpace = Vector3.new(0, 7, 0),
	}, holder) :: BillboardGui

	-- Hình gốc là chevron chỉ LÊN ⇒ xoay 180° để chỉ XUỐNG mục tiêu.
	create("ImageLabel", {
		BackgroundTransparency = 1,
		Image = ARROW_TEXTURE,
		ImageColor3 = Color3.fromRGB(255, 190, 40),
		Rotation = 180,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
	}, arrow)

	targetHolder = holder
	targetAttachment = attachment
	arrowGui = arrow
	applyArrowScale()
	beam = newBeam
end

-- Attachment gốc bám nhân vật; phải dựng LẠI mỗi lần respawn (nó chết theo nhân vật cũ).
local function ensureOrigin(): Attachment?
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	if originAttachment and originAttachment.Parent == root then
		return originAttachment
	end

	if originAttachment then
		originAttachment:Destroy()
	end

	local attachment = create("Attachment", { Name = "TutorialOrigin" }, root) :: Attachment
	originAttachment = attachment
	if beam then
		beam.Attachment1 = attachment
	end

	return attachment
end

-- ============================================================================
-- Cập nhật theo bước
-- ============================================================================

local function setGuidesVisible(visible: boolean)
	guidesVisible = visible
	if beam then
		beam.Enabled = visible
	end
	if arrowGui then
		arrowGui.Enabled = visible
	end
end

--[[
	Đặt VỊ TRÍ hai đầu dải. Gọi mỗi khung hình vì người chơi di chuyển liên tục.

	⚠️ KHÔNG đặt hướng ở đây nữa. `FaceCamera = true` giao việc xoay cho engine (xem khối lý do
	chỗ dựng Beam); tự đặt `WorldCFrame` thêm một lần nữa chỉ tổ giành việc với nó, và đó chính
	là thứ đã ghim dải xuống mặt đất.

	Cả hai đầu đặt ở TẦM NGỰC (`BEAM_HEIGHT`), không phải dưới chân: dải chạy ngang tầm mắt thì
	nhìn từ sau lưng nhân vật vẫn thấy rõ, và không bị dốc/bậc thang cắt ngang.
]]
local BEAM_HEIGHT = 1.2

local function orientBeam()
	local target = currentTarget
	local origin = originAttachment
	if not target or not origin or not targetAttachment then
		return
	end

	local root = origin.Parent
	if not root or not root:IsA("BasePart") then
		return
	end

	--[[
		`HumanoidRootPart` vốn đã nằm giữa thân, nên đầu phía người chơi chỉ cần nhích thêm một
		chút cho khỏi trùng đúng tâm ngực (dải xuyên qua chính nhân vật trông rất khó chịu).

		Đầu phía ĐÍCH nâng lên cùng độ cao so với MẶT TRÊN của đích: dải giữ độ cao đều suốt
		quãng đường thay vì chúi xuống đất ở cuối. Mũi tên nhấp nhô (`arrowGui`) mới là thứ chỉ
		chính xác điểm cần tới.
	]]
	origin.WorldPosition = root.Position + Vector3.new(0, BEAM_HEIGHT, 0)
	targetAttachment.WorldPosition = target.Position + Vector3.new(0, target.Size.Y * 0.5 + BEAM_HEIGHT + 1.4, 0)
end

local function refreshTarget()
	local config = STEPS[currentStep + 1]
	if not config or not isActive then
		currentTarget = nil
		setGuidesVisible(false)
		return
	end

	-- Đích thật trước; chưa stream về thì chỉ tạm tới cột mốc gần hơn.
	local target = resolvePath(config.targetPath)
	if not target and config.fallbackPath then
		target = resolvePath(config.fallbackPath)
	end

	if not target or not targetHolder then
		-- Cả đích lẫn cột mốc đều đang bị stream out — tắt chỉ dẫn thay vì trỏ vào hư không.
		currentTarget = nil
		setGuidesVisible(false)
		return
	end

	currentTarget = target
	targetHolder.Position = target.Position

	local hasOrigin = ensureOrigin() ~= nil
	setGuidesVisible(hasOrigin)
	if hasOrigin then
		orientBeam()
	end
end

--[[
	Dải nhắc dùng chung cho CẢ HAI loại bước:
	  • bước THẾ GIỚI — có thảm mũi tên chỉ tới một mục tiêu ngoài map;
	  • bước GIAO DIỆN — có spotlight khoét một ô sáng trên chính HUD.
	Cả hai chỉ khác nhau ở chỗ "chỉ vào đâu", còn câu chữ + số bước + nút SKIP thì dùng chung một
	dải. Một màn hình chỉ được có ĐÚNG MỘT câu hướng dẫn tại một thời điểm.
]]
local function setBanner(text: string, counter: string)
	buildUI()
	if banner then
		banner.Visible = true
	end
	-- Modal phải biết làn đỉnh đang bị chiếm (xem `State.tutorialBannerVisible`).
	State.tutorialBannerVisible:set(true)
	if bannerLabel then
		bannerLabel.Text = text
	end
	if counterLabel then
		counterLabel.Text = counter
	end
end

local function hideBanner()
	if banner then
		banner.Visible = false
	end
	State.tutorialBannerVisible:set(false)
end

--[[
	Tổng số bước NGƯỜI CHƠI nhìn thấy = 3 bước thế giới + Daily + Vòng quay.

	Server vẫn chỉ biết 3 bước (`TutorialService.STEP_INDEX`); hai bước cuối sống hoàn toàn ở
	client vì chúng chỉ là "mở đúng modal và chỉ vào đúng nút", không có sự kiện gameplay nào
	để server chốt. Phễu Onboarding trên Creator Hub vì vậy vẫn là 4 bước như cũ — ĐỪNG sửa
	`STEP_INDEX` cho "khớp", làm thế là gãy toàn bộ dữ liệu phễu lịch sử.

	DAILY_STEP để hai bước cuối tự đánh số đúng khi ai đó thêm/bớt bước, thay vì chép tay 4 và 5.
]]
local DAILY_STEP = #STEPS + 1
local TOTAL_STEPS = #STEPS + 2

--[[
	══ NHỊP HOÀN THÀNH: CHỚP XANH "✓ Nice!" GIỮA HAI BƯỚC ═══════════════════════════════════

	Bản cũ đổi thẳng chữ sang việc tiếp theo. Người chơi vừa làm xong một việc mà màn hình lập
	tức giao việc mới — không có một khoảnh khắc nào nói "bạn vừa làm được đấy". Đó là kiểu
	tutorial đọc như danh sách công việc, và là lý do người ta bấm SKIP.

	0,9 giây chớp xanh là đủ để não ghi nhận một lần THẮNG, rồi mới nhận việc mới. Bốn bước là
	bốn lần thắng liên tiếp — chính cái nhịp đó giữ người chơi tới hết.

	⚠️ Chỉ chớp khi bước THẬT SỰ tiến (`step > lastRenderedStep`). Không có chốt này thì mọi gói
	`tutorialState` lặp lại (server đẩy lại lúc respawn) đều nháy một cái, thành đèn nhấp nháy vô
	nghĩa giữa lúc người chơi đang chạy.
]]
local BANNER_COLOR = Color3.fromRGB(18, 18, 30)
local BANNER_DONE_COLOR = Color3.fromRGB(28, 122, 52)
local flashToken = 0

local function flashStepDone(onFinished: () -> ())
	buildUI()
	flashToken += 1
	local token = flashToken

	setBanner("✓ Nice!", "")
	if banner then
		banner.BackgroundColor3 = BANNER_DONE_COLOR
	end

	task.delay(0.9, function()
		-- Bước khác đã chen vào trong lúc chờ ⇒ bỏ qua, để nó vẽ tiếp chứ đừng ghi đè.
		if token ~= flashToken then
			return
		end
		if banner then
			banner.BackgroundColor3 = BANNER_COLOR
		end
		onFinished()
	end)
end

local function renderStep(step: number, active: boolean)
	currentStep = step
	isActive = active

	buildUI()
	buildWorldGuides()

	local config = STEPS[step + 1]
	if not active or not config then
		hideBanner()
		setGuidesVisible(false)
		return
	end

	--[[
		Bước thế giới bắt đầu từ 1: Daily giờ nằm ở CUỐI chứ không phải đầu (xem khối lý do ở
		`runDailyFinale`), nên bước 0 của server chính là bước 1 người chơi thấy.

		Bước vừa TIẾN LÊN thì ăn mừng trước rồi mới giao việc mới (xem `flashStepDone`). Lần đầu
		vào game (`step` = 0) thì không có gì để mừng, vẽ thẳng.
	]]
	local function show()
		setBanner(config.text, `{step + 1}/{TOTAL_STEPS}`)
		refreshTarget()
	end

	if step > lastRenderedStep and step > 0 then
		lastRenderedStep = step
		setGuidesVisible(false) -- giấu thảm mũi tên cũ trong lúc chớp, tránh chỉ vào đích đã xong
		flashStepDone(show)
		return
	end
	lastRenderedStep = step
	show()
end

local function applyState(step: number, active: boolean)
	renderStep(step, active)
end

--[[
	══ BƯỚC CUỐI: NHẬN QUÀ DAILY, DẪN BẰNG SPOTLIGHT (user chốt 2026-08-17) ═════════════════

	── VÌ SAO DAILY Ở CUỐI CHỨ KHÔNG PHẢI ĐẦU ────────────────────────────────────────────────
	Bản trước mở Daily ngay lúc spawn và bắt người chơi bấm CLAIM trước khi được chạy. Đổi vì:

	  1. Phần thưởng phải CÓ NGHĨA thì mới có tác dụng. Ngày 1 cho "+1.00K Speed" — với người
	     vừa vào game, chưa từng thấy Speed là gì, đó là một con số vô nghĩa. Cũng món quà ấy,
	     đưa SAU khi họ tự cày được ~15 Speed ở Stage 1, thì đọc thành "gấp sáu mươi lần cái
	     mình vừa làm cả phút".
	  2. Mười giây đầu phải là GAME chứ không phải một cái modal che mất thế giới. Dấu hiệu của
	     việc xếp sai: phải đẻ ra hẳn một làn riêng cho dải nhắc để nó không đè lên modal, và
	     `Theme.ModalPosition` phải có nhánh né dải nhắc — hai thứ đó tranh chỗ vì bị đặt cùng lúc.
	  3. Kết bằng quà + câu "mai vào nhận tiếp" là cái móc quay lại, và nó ăn nhất ở CUỐI, khi
	     người chơi đã hiểu Speed dùng để làm gì.

	── RỦI RO ĐÃ CHẶN ────────────────────────────────────────────────────────────────────────
	Người bấm SKIP sẽ không đi tới đây và mất luôn ngày đầu của chuỗi streak. Vì vậy nhánh
	`skipped` VẪN mở Daily (chỉ không có spotlight, vì họ vừa nói rõ là không muốn được dắt tay).
	Chấm đỏ trên nút Daily cũng bật từ giây đầu, nên ai muốn nhận sớm vẫn tự tìm thấy.
]]
local function waitUntil(predicate: () -> boolean, timeout: number): boolean
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.15)
	end
	return false
end

local function runDailyFinale(): boolean
	-- Chưa có gói `dailyState`, hoặc hôm nay đã nhận rồi: không có gì để dắt.
	if not waitUntil(function()
		return State.dailyCanClaim:get()
	end, 8) then
		return false
	end

	--[[
		Chặng 1 — chiếu vào NÚT DAILY trong menu trái.

		Spotlight nuốt mọi cú chạm ngoài ô sáng, nên người chơi chỉ có đúng một đường đi: bấm
		vào cái nút đang sáng. Không thể bấm nhầm sang Shop/Rebirth rồi lạc mất mạch.
	]]
	local dailyButton = UIAnchors.Await("dailyButton", 5)
	if not dailyButton or not dailyButton:IsA("GuiObject") then
		-- Không tìm thấy nút thì tuyệt đối KHÔNG bật lớp tối: sẽ thành màn hình đen với một lỗ
		-- chỉ vào hư không. Thà mở thẳng modal còn hơn.
		Manager.OpenDaily()
		return false
	end

	setBanner("Your reward is waiting — tap Daily!", `{DAILY_STEP}/{TOTAL_STEPS}`)
	Spotlight.Show(dailyButton :: GuiObject)

	local opened = waitUntil(function()
		return State.dailyModalVisible:get()
	end, 90)
	if not opened then
		-- Người chơi bỏ mặc: dọn sạch, không để lớp tối treo vĩnh viễn trên màn hình.
		Spotlight.Hide()
		hideBanner()
		return false
	end

	--[[
		Chặng 2 — chiếu vào NÚT CLAIM bên trong modal.

		Nút này chỉ tồn tại sau khi modal dựng xong nên phải `Await`, không được `Get` ngay —
		đó cũng là lý do `UIAnchors` có hàm chờ.
	]]
	local claimButton = UIAnchors.Await("dailyClaimButton", 5)
	if claimButton and claimButton:IsA("GuiObject") then
		setBanner("CLAIM now: +1,000 Speed and +2 Wins!", `{DAILY_STEP}/{TOTAL_STEPS}`)
		-- Mũi tên vàng trong modal (dựng sẵn trong `DailyModal`) chỉ xuống nút CLAIM.
		State.tutorialClaimHint:set(true)
		Spotlight.Show(claimButton :: GuiObject)
	end

	-- Xong khi ĐÃ NHẬN, hoặc khi người chơi tự đóng modal (không ép).
	local claimed = waitUntil(function()
		return not State.dailyCanClaim:get() or not State.dailyModalVisible:get()
	end, 120) and not State.dailyCanClaim:get()

	Spotlight.Hide()
	State.tutorialClaimHint:set(false)
	hideBanner()

	return claimed
end

--[[
	Hai câu chốt của CẢ tutorial. Chạy SAU bước quay, không phải ngay sau khi nhận quà Daily.

	⚠️ 2026-08-27 (user: "từ bước 4/5 sang 5/5 chậm quá, thấy claim xong là phải dẫn liền").
	Trước đó hai câu này nằm ngay sau `claimed` và cộng thêm 1,8 + 2,6 giây vào ĐƯỜNG GĂNG
	giữa lúc bấm CLAIM và lúc spotlight nút Spin sáng lên — tổng cộng ~5,4 giây người chơi
	ngồi nhìn màn hình không có gì xảy ra, đúng chỗ dễ rời game nhất.

	Chuyển xuống đây vừa xoá độ trễ đó, vừa hợp mạch hơn: đây là lời chốt của TOÀN BỘ tutorial
	chứ không riêng gì bước Daily.
]]
local function runClosingToasts()
	--[[
		Câu CHỐT LẠI VÒNG LẶP. Người chơi vừa đi qua đủ bốn mảnh (chạy → Wins → nâng cấp →
		Speed) nhưng chưa chắc đã ghép chúng lại trong đầu; một câu gói cả vòng là thứ họ mang
		theo suốt phiên sau.
	]]
	Toast.Show("That's the loop: farm Speed → run further → bank more Wins.", "info")
	task.wait(2.6)
	--[[
		HAI CÁI MÓC trong một câu: một mục tiêu cho NGAY BÂY GIỜ (Stage 2 trả 3 Wins — gấp ba
		Stage 1) và một lý do quay lại NGÀY MAI (quà Ngày 2 to hơn).

		⚠️ Tutorial kết thúc là lúc người chơi dễ rời game nhất: hết việc được giao, không ai
		nói tiếp theo làm gì. Câu này lấp đúng khoảng trống đó.
	]]
	Toast.Show("Next stop: Stage 2 pays 3 Wins. Come back tomorrow — Day 2 gift is bigger.", "info")
end

--[[
	══ BƯỚC 5/5: TIÊU VÉ QUAY CHÀO MỪNG (user chốt 2026-08-27) ══════════════════════════════

	── VÌ SAO CHÈN VÀO GIỮA DAILY VÀ GROUP CHEST ─────────────────────────────────────────────
	`RouletteService` phát MỘT vé miễn phí cho mọi tài khoản mới (cờ `WelcomeSpinGranted`),
	nhưng trước bản này không có gì dẫn người chơi tới chỗ tiêu nó. Cái vé nằm im trong túi,
	và phần lớn người chơi rời game mà chưa từng thấy vòng quay lần nào — tức là một trong
	những khoảnh khắc đã-dựng-sẵn và đáng nhớ nhất của game bị bỏ phí hoàn toàn.

	Đặt SAU Daily vì cùng một lý do đã đưa Daily xuống cuối: phần thưởng chỉ có nghĩa khi
	người chơi đã hiểu Speed/Wins dùng để làm gì. Đặt TRƯỚC Group Chest vì Group Chest là lời
	MỜI RA NGOÀI game (vào nhóm Roblox) — mọi thứ diễn ra bên trong game phải xong trước đã.

	── VÌ SAO KHÔNG ÉP QUAY ──────────────────────────────────────────────────────────────────
	Mọi vòng chờ đều thoát êm khi người chơi đóng modal. Vé vẫn nằm nguyên trong túi và chấm
	đỏ trên nút Spin vẫn sáng, nên ai không muốn quay bây giờ không mất gì cả. Ép ở bước cuối
	là cách nhanh nhất để biến một món quà thành một thủ tục.
]]
local function runSpinFinale()
	--[[
		ĐÓNG MODAL DAILY TRƯỚC.

		`runDailyFinale` cố ý không đóng (người chơi có quyền ngồi xem tiếp bảng 7 ngày). Nhưng
		nếu để nguyên thì bước này bật lớp tối ĐÈ LÊN một modal đang mở — nhìn thấy trong ảnh
		nghiệm thu 2026-08-27: bảng Daily nằm mờ mờ giữa màn hình trong khi lỗ sáng lại ở góc
		trên bên phải. Hai tiêu điểm cùng lúc, người chơi không biết nhìn đâu.
	]]
	Manager.CloseDaily()
	task.wait(0.2)

	--[[
		Xin state trước khi dẫn: số vé thay đổi cả khi người chơi đang offline (đồng hồ vé free
		vẫn chạy), nên giá trị trong `State` lúc này có thể là số cũ từ lúc join.
	]]
	GamePackets.requestRouletteState.send({})
	if not waitUntil(function()
		return State.rouletteTickets:get() > 0
	end, 5) then
		-- Không có vé thì không có gì để dắt. Im lặng bỏ qua, không hiện banner hụt.
		return
	end

	-- Chặng 1 — chiếu vào nút SPIN ở hàng trên bên phải.
	local spinButton = UIAnchors.Await("spinButton", 5)
	if not spinButton or not spinButton:IsA("GuiObject") then
		-- Cùng lý do với `runDailyFinale`: không tìm thấy nút thì TUYỆT ĐỐI không bật lớp tối,
		-- vì đó sẽ là màn hình đen với một cái lỗ chỉ vào hư không. Mở thẳng modal còn hơn.
		Manager.OpenRoulette()
		return
	end

	setBanner("You have a free spin → claim your prize!", `{TOTAL_STEPS}/{TOTAL_STEPS}`)
	Spotlight.Show(spinButton :: GuiObject)

	if not waitUntil(function()
		return State.rouletteModalVisible:get()
	end, 90) then
		Spotlight.Hide()
		hideBanner()
		return
	end

	-- Chặng 2 — chiếu vào nút SPIN bên trong modal (chỉ tồn tại sau khi modal dựng xong).
	local wheelButton = UIAnchors.Await("rouletteSpinButton", 5)
	if wheelButton and wheelButton:IsA("GuiObject") then
		setBanner("Tap SPIN → see what you win!", `{TOTAL_STEPS}/{TOTAL_STEPS}`)
		Spotlight.Show(wheelButton :: GuiObject)
	end

	--[[
		Xong khi bánh xe BẮT ĐẦU quay, hoặc khi người chơi tự đóng modal.

		Mốc là `rouletteSpinning` chứ không phải "vé giảm đi": bánh xe quay mất 4,2 giây và
		lớp tối phải tắt NGAY lúc bấm, nếu không nó che mất đúng cái khoảnh khắc mà cả bước
		này tồn tại để tạo ra.
	]]
	waitUntil(function()
		return State.rouletteSpinning:get() or not State.rouletteModalVisible:get()
	end, 120)

	Spotlight.Hide()
	hideBanner()
end

local function runCompletionSequence(_wins: number, _spins: number, skipped: boolean)
	task.spawn(function()
		--[[
			Tutorial KHÔNG phát thưởng (quà của người mới nằm ở Daily Ngày 1). `wins`/`spins`
			trong gói tin luôn là 0 — giữ trong packet để không phải đổi schema nếu sau này
			muốn bật thưởng lại.
		]]
		if skipped then
			-- Đã nói "để tôi yên" thì không dắt nữa; nhưng vẫn mở Daily một lần để họ không mất
			-- trắng ngày đầu của chuỗi streak.
			Spotlight.Hide()
			hideBanner()
			task.wait(0.8)
			if State.dailyCanClaim:get() then
				Manager.OpenDaily()
			end
			return
		end

		-- KHÔNG chúc mừng ở đây nữa: bước 4/4 (nhận quà Daily) mới là cái kết, và hai câu chốt
		-- nằm ở cuối `runDailyFinale`. Chúc mừng sớm là báo "xong rồi" trong khi còn một bước.
		task.wait(1.0)

		-- Bước 4/5: nhận quà Daily, có spotlight dẫn đường.
		local claimed = runDailyFinale()

		--[[
			SANG BƯỚC 5 NGAY KHI THẤY ĐÃ NHẬN (user chốt 2026-08-27).

			1,1 giây chứ không phải 0: thẻ thưởng Daily bay mất khoảng chừng đó, và cắt ngang
			nó là người chơi không kịp thấy mình vừa được gì — vừa hỏng khoảnh khắc, vừa hỏng
			luôn lý do đã đưa Daily xuống cuối tutorial.

			Ai KHÔNG nhận (đóng modal, hoặc hết giờ chờ) thì không có thẻ nào đang bay, đi thẳng.
		]]
		if claimed then
			task.wait(1.1)
		end

		-- Bước 5/5: tiêu vé quay chào mừng. Xem khối lý do ở `runSpinFinale`.
		runSpinFinale()

		--[[
			Chờ lâu hơn ở đây (0.6 → 2.4s, hoặc 9s nếu bánh xe đang quay).

			Bánh xe quay 4,2 giây, nhưng ĐUÔI của nó mới là chỗ dài: trúng Speed thì sau đó còn
			toast phần thưởng + chuỗi "LEVEL UP!" nổ liên tiếp. Đo 2026-08-27: một cú +25K Speed
			trên tài khoản mới bắn ra COMBO x8 và tấm "LEVEL UP!" đè CHỒNG LÊN modal Group Chest
			vừa mở — hai lớp chữ to nằm đúng giữa màn hình, không đọc được cái nào.

			9 giây = 4,2 quay + ~1,5 toast + ~3 cho chuỗi level-up dài nhất.
		]]
		task.wait(if State.rouletteSpinning:get() then 9.0 else 2.4)

		-- Hai câu chốt của cả tutorial (trước đây nằm kẹt giữa bước 4 và 5 — xem khối lý do
		-- ở `runClosingToasts`).
		runClosingToasts()
		task.wait(2.6)

		-- Lời mời cuối cùng, và cũng là buff vĩnh viễn +10% Wins nếu họ vào group.
		Manager.OpenGroupChest()
	end)
end

-- ============================================================================

function TutorialController.Start()
	GamePackets.tutorialState.listen(function(payload)
		applyState(payload.step, payload.active)
	end)

	GamePackets.tutorialComplete.listen(function(payload)
		runCompletionSequence(payload.wins, payload.spins, payload.skipped)
	end)

	--[[
		[Studio-only test hook] CHẠY THẲNG MÀN CUỐI (spotlight → Daily → CLAIM).

		Đặt `StudioTutorialFinale` = 1 lên Player (hoặc = 2 để thử nhánh bấm SKIP) là chạy đúng
		đoạn mà người chơi thật sẽ thấy sau khi xong bước 3.

		Attribute chứ không phải gọi hàm, và cũng KHÔNG bắn gói tin: `execute_luau` chạy ở một VM
		riêng, nên nó vừa không với tới hàm local ở đây, vừa không gửi được ByteNet sang VM này
		(đã thử: gói `tutorialComplete` bắn từ command bar không bao giờ tới nơi). Attribute nằm
		trên Instance nên mọi VM đều ghi/đọc được — cùng lý do với `StudioTestSpin` bên
		`RouletteService`.

		Nghiệm thu bằng tay thì tốn ~2 phút chạy hết Stage 1 cho MỖI lần sửa một dòng chữ.
	]]
	if RunService:IsStudio() then
		LocalPlayer:GetAttributeChangedSignal("StudioTutorialFinale"):Connect(function()
			local mode = tonumber(LocalPlayer:GetAttribute("StudioTutorialFinale"))
			if not mode then
				return
			end
			LocalPlayer:SetAttribute("StudioTutorialFinale", nil)
			runCompletionSequence(0, 0, mode == 2)
		end)

		--[[
			[Studio-only test hook] NHẢY THẲNG TỚI MỘT BƯỚC.

			`StudioTutorialStep` = 0..2 (chỉ số bước của server) ⇒ vẽ đúng bước đó, kể cả nhịp
			chớp "✓ Nice!" khi nhảy tiến. Không có hook này thì muốn đọc lại câu nhắc của bước 3
			phải chạy hết Stage 1 + mở pad + lên treadmill cho MỖI lần sửa một chữ.
		]]
		LocalPlayer:GetAttributeChangedSignal("StudioTutorialStep"):Connect(function()
			local step = tonumber(LocalPlayer:GetAttribute("StudioTutorialStep"))
			if not step then
				return
			end
			LocalPlayer:SetAttribute("StudioTutorialStep", nil)
			applyState(math.clamp(math.floor(step), 0, #STEPS - 1), true)
		end)
	end

	LocalPlayer.CharacterAdded:Connect(function()
		-- Attachment gốc chết theo nhân vật cũ; dựng lại rồi chỉ lại mục tiêu.
		task.wait(0.5)
		if isActive then
			refreshTarget()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not isActive then
			return
		end

		-- Mũi tên nhấp nhô: chuyển động là thứ mắt bắt được từ xa, chữ thì không.
		arrowClock += dt
		if arrowGui then
			arrowGui.StudsOffsetWorldSpace = Vector3.new(0, 7 + math.sin(arrowClock * 3.2) * 0.9, 0)
		end

		if guidesVisible then
			orientBeam()
		end

		resolveAccumulator += dt
		if resolveAccumulator >= RESOLVE_INTERVAL then
			resolveAccumulator = 0
			refreshTarget()
		end
	end)
end

return TutorialController
