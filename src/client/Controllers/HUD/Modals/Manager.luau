--!strict
--[[
	Quản lý đóng/mở modal: mở một cái là đóng hết những cái còn lại, kèm blur + FOV nền.

	Danh sách modal KHÔNG nằm trong file này — nó ở `Modals/Registry.luau`. `hideAll`, việc dò
	"còn modal nào đang mở", và cả ba hàm Open/Close/Toggle của từng modal đều SINH RA từ bảng
	đó. Trước đợt gom 2026-08-16, mỗi modal phải sửa tay 5 chỗ rời nhau (một nhánh `if` trong
	hideAll, một dòng trong bảng MODAL_VISIBLE_KEYS, rồi Open + Close + Toggle chép nguyên si) —
	tổng cộng ~230 dòng gần như giống hệt nhau, và sót một chỗ là modal mới không tự đóng khi mở
	modal khác hoặc để blur nền kẹt lại vĩnh viễn.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local State = require(script.Parent.Parent.State)
local Tokens = require(script.Parent.Parent.Tokens)
local Registry = require(script.Parent.Registry)

local Manager = {}

--[[
	══ FOV + BLUR KHI MỞ MODAL ("Fov_FRM" của UI Animation Pack - by JakeDev) ═══════════════

	Mở modal thì camera nới FOV +10 và nền sau mờ đi; đóng thì trả về nguyên trạng. Tác dụng
	thật của nó không phải "cho đẹp": nền 3D của game này rất rộn (cát sáng, trail neon, hạt
	VFX), modal đặt lên trên đó bị chìm. Làm mờ nền là tách hẳn lớp UI ra khỏi lớp thế giới —
	mắt biết ngay đang đọc cái gì.

	Khác bản trong pack ở hai chỗ, và cả hai đều cần thiết:
	  1. Pack gắn script vào TỪNG nút mở frame. Ở đây có 11 modal dùng chung `hideAll`, nên
	     đặt một chỗ duy nhất — thêm modal mới là tự có, không phải nhớ chép script.
	  2. Pack đọc `cam.FieldOfView` một lần lúc khởi động làm mốc. Game này có `SpeedVFXController`
	     ĐANG ĐỔI FOV theo tốc độ chạy, nên mốc đó sai ngay khi người chơi tăng tốc. Vì vậy chỉ
	     cộng thêm một LƯỢNG BÙ vào FOV hiện tại qua attribute, để hai hệ không giẫm chân nhau.

	⚠️ Blur đặt `Enabled = false` khi về 0: BlurEffect size 0 vẫn tốn một lượt post-process
	mỗi frame, mà máy yếu là đối tượng chính của cả đợt tối ưu mobile này.
]]
local FOV_BOOST = 10
local BLUR_SIZE = 18
local MODAL_FX_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local blurEffect: BlurEffect? = nil
local fovConnection: RBXScriptConnection? = nil
local modalFxActive = false

local function getBlur(): BlurEffect
	if blurEffect and blurEffect.Parent then
		return blurEffect
	end
	local blur = Instance.new("BlurEffect")
	blur.Name = "SpeedEscapeModalBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting
	blurEffect = blur
	return blur
end

local function setModalFx(active: boolean)
	if modalFxActive == active then
		return
	end
	modalFxActive = active
	-- Tín hiệu cho những thứ NGOÀI hệ modal phải nhường chỗ (xem `State.anyModalOpen`).
	State.anyModalOpen:set(active)

	local blur = getBlur()
	if active then
		blur.Enabled = true
	end
	local blurTween = TweenService:Create(blur, MODAL_FX_TWEEN, { Size = if active then BLUR_SIZE else 0 })
	blurTween:Play()
	if not active then
		blurTween.Completed:Once(function()
			if not modalFxActive then
				blur.Enabled = false
			end
		end)
	end

	--[[
		FOV: cộng bù vào giá trị camera ĐANG có mỗi frame thay vì tween thẳng `FieldOfView`.
		Tween thẳng sẽ đánh nhau với `SpeedVFXController` (nó cũng ghi FOV theo tốc độ) và kết
		quả là FOV giật loạn suốt lúc modal mở.
	]]
	if fovConnection then
		fovConnection:Disconnect()
		fovConnection = nil
	end
	local startedAt = os.clock()
	local from = tonumber(Workspace:GetAttribute("ModalFovBoost")) or 0
	local to = if active then FOV_BOOST else 0
	fovConnection = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - startedAt) / MODAL_FX_TWEEN.Time, 0, 1)
		Workspace:SetAttribute("ModalFovBoost", from + (to - from) * alpha)
		if alpha >= 1 and fovConnection then
			fovConnection:Disconnect()
			fovConnection = nil
		end
	end)
end

--[[
	Truy cập state của một modal theo id (xem quy ước đặt tên ở `Modals/Registry.luau`).

	Ép `State` về `any` là CỐ Ý và chỉ gói gọn trong ba helper này: tên field được ghép từ chuỗi
	nên `--!strict` không kiểm tra được. Đổi lại, `State.luau` vẫn gán tường minh từng field để
	MỌI chỗ khác trong codebase giữ nguyên kiểm tra kiểu.
]]
local function stateOf(id: string, suffix: string): any
	return (State :: any)[id .. suffix]
end

--[[
	Còn modal nào đang mở không.

	Cần vì các hàm `Close*` KHÔNG đi qua `hideAll` — chúng chỉ tắt đúng modal của mình. Không
	hỏi lại toàn bộ thì đóng modal bằng nút X sẽ để blur + FOV kẹt lại vĩnh viễn.
]]
--[[
	Modal KHÔNG kéo theo blur + zoom nền (user chốt 2026-08-17).

	`revive` nằm trong `Registry.IDS` để dùng chung cơ chế loại trừ, nhưng nó KHÔNG phải một tấm
	panel che màn hình — nó là một nút nhỏ nổi sát mép trên, hiện lúc người chơi vừa chết và
	đang đếm ngược vài giây để quyết định. Làm mờ + zoom cả khung cảnh vào đúng lúc đó vừa che
	mất thứ người chơi cần nhìn (mình chết ở đâu, còn bao lâu), vừa là một cú giật hình không ai
	yêu cầu — trong khi mọi modal khác thì blur là đúng, vì chúng che gần hết màn hình rồi.
]]
local FX_EXEMPT_IDS: { [string]: boolean } = {
	revive = true,
}

local function anyModalVisible(): boolean
	for _, id in Registry.IDS do
		if not FX_EXEMPT_IDS[id] then
			local value = stateOf(id, "ModalVisible")
			if value and value:get() then
				return true
			end
		end
	end
	return false
end

function Manager.RefreshModalFx()
	setModalFx(anyModalVisible())
end

-- Nhịp cập nhật thanh đếm ngược Revive. 20Hz đủ mượt cho một thanh trôi và chỉ chạy
-- trong đúng 5 giây modal mở, nên không đáng kể về hiệu năng.
local REVIVE_TICK_INTERVAL = 0.05

-- Tắt/bật cả ba giá trị của một modal cùng lúc. Thứ tự giữ đúng như bản cũ.
local function setModalOpen(id: string, open: boolean)
	stateOf(id, "ModalMounted"):set(open)
	stateOf(id, "ModalVisible"):set(open)
	stateOf(id, "ModalAnimationGoal"):set(if open then 1 else 0)
end

local function hideAll(except: string?)
	--[[
		`except` khác nil nghĩa là vừa MỞ một modal; nil nghĩa là đóng sạch.

		⚠️ Phải hỏi cả `FX_EXEMPT_IDS`: đây là đường MỞ, và nó bật hiệu ứng thẳng chứ không đi qua
		`anyModalVisible`. Thiếu vế đó thì nút Revive vẫn kéo blur + zoom lên như thường, dù hàm
		kia đã loại nó ra — lỗi chỉ lộ ở đúng lúc mở, nên rất dễ tưởng là đã sửa xong.
	]]
	setModalFx(except ~= nil and not FX_EXEMPT_IDS[except])

	for _, id in Registry.IDS do
		if id ~= except then
			setModalOpen(id, false)
		end
	end
end

--[[
	Sinh bộ Open/Close/Toggle cho một modal.

	`onOpen` chạy SAU `hideAll` và TRƯỚC khi modal hiện ra — đúng khe mà bản cũ nhét việc riêng
	vào (Roulette xin state từ server, Cosmetic chọn tab).

	`Close` cố ý KHÔNG gọi `hideAll`: nó chỉ tắt modal của mình rồi hỏi lại `RefreshModalFx` xem
	còn cái nào mở không. Gọi `hideAll` ở đây sẽ tắt nhầm modal khác nếu sau này có hai modal
	cùng sống.
]]
local function defineModal(id: string, onOpen: (() -> ())?)
	local function open()
		hideAll(id)
		if onOpen then
			onOpen()
		end
		setModalOpen(id, true)
	end

	local function close()
		stateOf(id, "ModalVisible"):set(false)
		stateOf(id, "ModalAnimationGoal"):set(0)
		Manager.RefreshModalFx()
		-- Giữ modal trên màn hình tới hết hoạt ảnh đóng. Kiểm lại `Visible` trước khi gỡ: người
		-- chơi bấm mở lại trong 0.22s đó thì KHÔNG được gỡ, nếu không modal vừa mở lại biến mất.
		task.delay(Tokens.MODAL_CLOSE_DELAY, function()
			if not stateOf(id, "ModalVisible"):get() then
				stateOf(id, "ModalMounted"):set(false)
			end
		end)
	end

	local function toggle()
		if stateOf(id, "ModalVisible"):get() then
			close()
		else
			open()
		end
	end

	return open, close, toggle
end

-- Feedback KHÔNG còn là modal của game: xem `CoreLoop/FeedbackPromptController`
-- (hộp thoại gốc của Roblox, đổ về Creator Dashboard).

--[[
	══ BA HÀM CỦA TỪNG MODAL, SINH TỪ `Registry` ════════════════════════════════════════════

	Gán TƯỜNG MINH `Manager.OpenShop = …` thay vì nhét động vào bảng: `--!strict` chỉ nhận ra
	field khi nó được gán thẳng, mà ~20 file khác đang gọi `Manager.OpenShop()` — gán động là
	tất cả thành "unknown field".

	Modal nào cần làm thêm việc lúc mở thì truyền `onOpen`; ngoài ra không có ngoại lệ nào.
]]
Manager.OpenRebirth, Manager.CloseRebirth, Manager.ToggleRebirth = defineModal("rebirth")
Manager.OpenTeleport, Manager.CloseTeleport, Manager.ToggleTeleport = defineModal("teleport")
Manager.OpenShop, Manager.CloseShop, Manager.ToggleShop = defineModal("shop")
Manager.OpenCode, Manager.CloseCode, Manager.ToggleCode = defineModal("code")
Manager.OpenDaily, Manager.CloseDaily, Manager.ToggleDaily = defineModal("daily")
Manager.OpenGroupChest, Manager.CloseGroupChest, Manager.ToggleGroupChest = defineModal("groupChest")
Manager.OpenStarterPack, Manager.CloseStarterPack, Manager.ToggleStarterPack = defineModal("starterPack")
Manager.OpenSettings, Manager.CloseSettings, Manager.ToggleSettings = defineModal("settings")
Manager.OpenQuest, Manager.CloseQuest, Manager.ToggleQuest = defineModal("quest")
Manager.OpenEmote, Manager.CloseEmote, Manager.ToggleEmote = defineModal("emote")
Manager.OpenOffline, Manager.CloseOffline, Manager.ToggleOffline = defineModal("offline")

-- Roulette xin state mới từ server ngay lúc mở: số vé và đồng hồ quay miễn phí thay đổi cả khi
-- modal đang đóng, nên đọc cache cũ là hiện sai số vé trong khung hình đầu tiên.
Manager.OpenRoulette, Manager.CloseRoulette, Manager.ToggleRoulette = defineModal("roulette", function()
	GamePackets.requestRouletteState.send({})
end)

--[[
	Cosmetic là modal DUY NHẤT mở kèm tham số (mở thẳng vào tab Trails hay Auras), nên nó bọc
	thêm một lớp quanh hàm sinh sẵn.

	Đặt `cosmeticCategory` TRƯỚC `open()` được vì `hideAll` không đụng tới giá trị này — kết quả
	giống hệt bản cũ (bản cũ đặt sau `hideAll`, trước khi bật `Mounted`).
]]
local openCosmetic, closeCosmetic = defineModal("cosmetic")
Manager.CloseCosmetic = closeCosmetic

function Manager.OpenCosmetic(category: string)
	State.cosmeticCategory:set(category)
	openCosmetic()
end

function Manager.ToggleCosmetic(category: string)
	if State.cosmeticModalVisible:get() then
		Manager.CloseCosmetic()
	else
		Manager.OpenCosmetic(category)
	end
end

function Manager.CloseRevive(reason: string?)
	State.reviveModalVisible:set(false)
	State.reviveModalAnimationGoal:set(0)
	State.reviveCountdownToken += 1
	State.reviveCountdownFraction:set(0)
	if reason == "declined" then
		GamePackets.requestRevive.send({
			method = "decline",
		})
	end
	--[[
		LỖI ĐÃ SỬA 2026-08-16: hàm này là hàm `Close*` DUY NHẤT quên gọi `RefreshModalFx`.
		`OpenRevive` đi qua `hideAll("revive")` nên có bật blur + FOV, nhưng lúc đóng thì không
		ai tắt — blur kẹt lại cho tới khi người chơi tình cờ mở rồi đóng một modal khác. Mà đây
		đúng là lúc KHÔNG được mờ màn hình: người chơi vừa chết và đang phải nhìn để chạy tiếp.
	]]
	Manager.RefreshModalFx()
	task.delay(Tokens.MODAL_CLOSE_DELAY, function()
		if not State.reviveModalVisible:get() then
			State.reviveModalMounted:set(false)
		end
	end)
end

function Manager.OpenRevive(
	stage: number,
	durationSeconds: number,
	robuxProductId: number,
	robuxPrice: number,
	adRewardProductId: number,
	freeRevive: boolean?
)
	hideAll("revive")

	State.reviveStage:set(stage)
	State.reviveCountdown:set(durationSeconds)
	State.reviveRobuxProductId:set(robuxProductId)
	State.reviveRobuxPrice:set(robuxPrice)
	State.reviveAdRewardProductId:set(adRewardProductId)
	State.reviveFree:set(freeRevive == true)
	State.reviveModalMounted:set(true)
	State.reviveModalVisible:set(true)
	State.reviveModalAnimationGoal:set(1)

	State.reviveCountdownToken += 1
	local token = State.reviveCountdownToken
	task.spawn(function()
		-- Bám mốc thời gian tuyệt đối chứ không cộng dồn task.wait: lag một khung hình
		-- không được phép kéo dài cửa sổ hồi sinh so với hạn server đang tính.
		local total = math.max(1, durationSeconds)
		local deadline = os.clock() + total
		State.reviveCountdown:set(total)
		State.reviveCountdownFraction:set(1)

		while token == State.reviveCountdownToken and State.reviveModalVisible:get() do
			local remaining = deadline - os.clock()
			if remaining <= 0 then
				break
			end
			State.reviveCountdown:set(math.ceil(remaining))
			State.reviveCountdownFraction:set(math.clamp(remaining / total, 0, 1))
			task.wait(REVIVE_TICK_INTERVAL)
		end

		if token == State.reviveCountdownToken and State.reviveModalVisible:get() then
			State.reviveCountdown:set(0)
			State.reviveCountdownFraction:set(0)
			Manager.CloseRevive()
		end
	end)
end

--[[
	[Studio-only test hook] MỞ / ĐÓNG MỘT MODAL BẤT KỲ TỪ NGOÀI.

	    LocalPlayer:SetAttribute("StudioOpenModal", "quest")   -- mở modal id "quest"
	    LocalPlayer:SetAttribute("StudioOpenModal", "")        -- đóng hết

	Cùng kiểu với `StudioOfflineNotice` / `StudioTutorialFinale` / `StudioTestCelebration`, và
	có mặt vì đúng lý do đó: công cụ MCP `execute_luau` chạy trong MỘT VM RIÊNG, không với được
	bảng module `Manager` mà HUD đang giữ, nên không có cách nào gọi thẳng `Manager.OpenQuest()`
	từ ngoài. Attribute là sợi dây duy nhất đi qua được ranh giới đó.

	`id` lấy từ `Modals/Registry.IDS`, nên hook này tự phủ mọi modal mới mà không phải sửa gì.
	⚠️ "revive" cần tham số nên hook bỏ qua nó — mở bằng `Manager.OpenRevive` như bình thường.
]]
if RunService:IsStudio() then
	local localPlayer = Players.LocalPlayer
	localPlayer:GetAttributeChangedSignal("StudioOpenModal"):Connect(function()
		local id = localPlayer:GetAttribute("StudioOpenModal")
		if typeof(id) ~= "string" then
			return
		end
		localPlayer:SetAttribute("StudioOpenModal", nil)

		if id == "" then
			hideAll()
			Manager.RefreshModalFx()
			return
		end
		if id == "revive" or not table.find(Registry.IDS, id) then
			warn(`[Manager] StudioOpenModal: không mở được "{id}"`)
			return
		end
		hideAll(id)
		setModalOpen(id, true)
	end)
end

return Manager
