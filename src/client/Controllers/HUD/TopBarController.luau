--!nonstrict
--[[
	TopBarController.luau — Nút ẨN GIAO DIỆN + CÀI ĐẶT trên topbar, dựng bằng **TopbarPlus
	v3.4.0** (`Packages/TopbarPlus`, wally `1foreverhd/topbarplus@3.4.0`).

	Dùng TopbarPlus thay vì tự dựng ScreenGui: nó tự lo canh vị trí cạnh cụm nút gốc của
	Roblox trên MỌI thiết bị (desktop / mobile / tay cầm), tự làm caption khi hover, tự thu
	vào overflow khi hết chỗ — những thứ bản tự dựng phải hardcode `GuiService.TopbarInset`.

	⚠️ TopbarPlus dựng ScreenGui riêng trong PlayerGui (`Topbar*`). Chức năng "ẩn giao diện"
	PHẢI chừa chúng ra, nếu không bấm ẩn xong là mất luôn nút để bấm lại.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Icon = require(ReplicatedStorage.Packages.TopbarPlus)
local BgmController = require(script.Parent.Parent.Effects.BgmController)
local ClientSettingsController = require(script.Parent.Parent.Effects.ClientSettingsController)

local localPlayer = Players.LocalPlayer

local TopBarController = {}

-- Icon trong bộ material chính chủ Roblox (đã verify IsLoaded=true trong Studio).
local ICON_HIDE = "rbxassetid://6031075929" -- mắt gạch chéo
local ICON_SETTINGS = "rbxassetid://6031280882" -- bánh răng

-- ScreenGui của TopbarPlus — không bao giờ được tắt. Đo trong Studio: nó dựng tới BỐN cái
-- (`TopbarStandard`, `TopbarCentered` + hai bản `…Clipped` để vẽ dropdown tràn ra ngoài
-- widget), nên khớp theo TIỀN TỐ chứ đừng liệt kê tay — thiếu bản Clipped là bấm ẩn xong
-- dropdown Cài đặt mất tiêu.
local function isTopbarPlusGui(gui: Instance): boolean
	return gui.Name:sub(1, 6) == "Topbar"
end

-- CoreGui bị tắt khi ẩn giao diện. **Chat KHÔNG có trong danh sách** (yêu cầu 2026-07-29:
-- người chơi vẫn phải chat được khi đang quay video / chụp ảnh).
local CORE_GUI_TO_HIDE = {
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Health,
	Enum.CoreGuiType.EmotesMenu,
}

local isHidden = false
-- Nhớ ScreenGui nào ĐANG bật lúc ẩn, để lúc hiện lại không bật nhầm modal vốn đã đóng.
local suppressed: { [LayerCollector]: boolean } = {}

local function applyHidden(hide: boolean)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	for _, gui in playerGui:GetChildren() do
		if gui:IsA("LayerCollector") and not isTopbarPlusGui(gui) then
			if hide then
				if gui.Enabled then
					suppressed[gui] = true
					gui.Enabled = false
				end
			elseif suppressed[gui] then
				gui.Enabled = true
			end
		end
	end
	if not hide then
		table.clear(suppressed)
	end

	for _, coreGuiType in CORE_GUI_TO_HIDE do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(coreGuiType, not hide)
		end)
	end
end

local function setHidden(hide: boolean)
	if isHidden == hide then
		return
	end
	isHidden = hide
	applyHidden(hide)
end

-- ── Mục trong dropdown Cài đặt ───────────────────────────────────────────────

-- Nhãn tự nói trạng thái: dropdown TopbarPlus chỉ tô sáng mục đang chọn, ở kích thước đó
-- người chơi khó thấy — ghi thẳng BẬT/TẮT là đọc được ngay.
local function makeToggleItem(label: string, startsOn: boolean, onChanged: (boolean) -> ())
	local item = Icon.new()
		:setLabel(`{label}  •  {if startsOn then "BẬT" else "TẮT"}`)
		:autoDeselect(false)

	local function sync(on: boolean)
		item:setLabel(`{label}  •  {if on then "BẬT" else "TẮT"}`)
		onChanged(on)
	end

	item:bindEvent("selected", function()
		sync(true)
	end)
	item:bindEvent("deselected", function()
		sync(false)
	end)

	return item
end

function TopBarController.Init()
	localPlayer:WaitForChild("PlayerGui")

	-- 1. Nút ẩn giao diện. `oneClick(false)` (mặc định) ⇒ bấm lần nữa là bỏ chọn, đúng kiểu
	--    công tắc; trạng thái "đang chọn" cũng chính là dấu hiệu giao diện đang bị ẩn.
	Icon.new()
		:setName("HideUiIcon")
		:setImage(ICON_HIDE)
		:setCaption("Ẩn giao diện")
		:bindEvent("selected", function()
			setHidden(true)
		end)
		:bindEvent("deselected", function()
			setHidden(false)
		end)

	-- 2. Nút cài đặt + dropdown 3 công tắc.
	local settingsIcon = Icon.new():setName("SettingsIcon"):setImage(ICON_SETTINGS):setCaption("Cài đặt")

	local performanceItem = makeToggleItem("Performance Mode", false, function(on)
		ClientSettingsController.SetPerformanceMode(on)
	end)
	local nightItem = makeToggleItem("Night Mode", false, function(on)
		ClientSettingsController.SetNightMode(on)
	end)
	local musicItem = makeToggleItem("Nhạc nền", true, function(on)
		BgmController.SetEnabled(on)
	end)

	settingsIcon:setDropdown({ performanceItem, nightItem, musicItem })

	-- Chọn SAU khi đã vào dropdown: `:select()` lúc icon còn mồ côi khiến TopbarPlus tính
	-- trạng thái mở/đóng của dropdown theo một icon chưa có cha.
	musicItem:select()
end

function TopBarController.Start()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	-- ScreenGui dựng SAU khi đã ẩn (modal mở lần đầu, ReviveModal…) cũng phải tắt theo,
	-- nếu không bấm ẩn xong mở modal là giao diện lòi ra lại.
	playerGui.ChildAdded:Connect(function(child)
		if not isHidden or not child:IsA("LayerCollector") or isTopbarPlusGui(child) then
			return
		end
		task.defer(function()
			if isHidden and child.Parent and child.Enabled then
				suppressed[child] = true
				child.Enabled = false
			end
		end)
	end)
end

return TopBarController
