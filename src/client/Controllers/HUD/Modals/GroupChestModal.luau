--!strict
-- Modal Group Chest: hiển thị quyền lợi group, yêu cầu like + join group, và claim reward.

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local GroupChestConfig = require(ReplicatedStorage.Shared.Config.GroupChest)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New

local CHEST_ICON = "rbxassetid://76987123050422"
local FAN_TAG_ICON = "rbxassetid://139927899217214"

local GroupChestModal = {}

local PANEL_WIDTH = 760
local PANEL_HEIGHT = 548

local function makeStatusPill(text: string, doneValue: any, position: UDim2)
	local colorA = Computed(function()
		return if doneValue:get() then Color3.fromRGB(80, 218, 110) else Color3.fromRGB(255, 186, 55)
	end)
	local colorB = Computed(function()
		return colorA:get():Lerp(Color3.fromRGB(0, 0, 0), 0.32)
	end)

	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		Position = position,
		Size = UDim2.fromOffset(300, 62),
		ZIndex = 44,
		[Children] = {
			Theme.MakeCorner(14),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradientDynamic(colorA, colorB),
			Theme.MakeStandardStuds(14, 46),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(16, 6),
				Size = UDim2.fromOffset(52, 50),
				Text = Computed(function()
					return if doneValue:get() then "✓" else "!"
				end),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				MaxTextSize = 34,
				ZIndex = 47,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(76, 8),
				Size = UDim2.fromOffset(208, 46),
				Text = text,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 26,
				ZIndex = 47,
			}),
		},
	})
end

local function makeRewardCard(
	position: UDim2,
	icon: string,
	title: string,
	subtitle: string,
	colorA: Color3,
	colorB: Color3
)
	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		Position = position,
		Size = UDim2.fromOffset(214, 144),
		ZIndex = 43,
		[Children] = {
			Theme.MakeCorner(16),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(colorA, colorB),
			Theme.MakeStandardStuds(16, 45),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromOffset(76, 12),
				Size = UDim2.fromOffset(62, 62),
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(10, 74),
				Size = UDim2.fromOffset(194, 34),
				Text = title,
				TextColor3 = Color3.fromRGB(255, 245, 128),
				MaxTextSize = 27,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(10, 108),
				Size = UDim2.fromOffset(194, 24),
				Text = subtitle,
				TextColor3 = Color3.fromRGB(220, 255, 235),
				MaxTextSize = 18,
				ZIndex = 46,
			}),
		},
	})
end

--[[
	Một nút làm trọn chuỗi: mở hộp thoại vào group của Roblox → đợi người chơi bấm → hỏi lại
	server xem đã là thành viên chưa → nhận quà.

	Vế "Like Game" đã bị gỡ 2026-08-24 (lý do đầy đủ ở đầu `GroupChestService`): nó không xác
	minh được, nút cũ không mở giao diện like nào cả, và chính hàm này gọi `confirmLike()` vô
	điều kiện nên cái cổng đó chưa từng chặn ai.
]]
local function runJoinAndClaim()
	if State.groupChestHasClaimed:get() then
		Toast.Show("Group chest already claimed")
		return
	end

	task.spawn(function()
		if not State.groupChestIsGroupMember:get() then
			local ok = pcall(function()
				GroupService:PromptJoinAsync(GroupChestConfig.GROUP_ID)
			end)
			if not ok then
				Toast.Show("Open the group page from Roblox")
			end
		end

		task.wait(1.5)
		GamePackets.requestGroupChestState.send({})
		task.wait(0.6)
		GamePackets.requestGroupChestClaim.send({})
	end)
end

local function buildContent(): { any }
	local claimHovered = State.groupChestClaimHovered

	local canClaim = Computed(function()
		return State.groupChestIsGroupMember:get() and not State.groupChestHasClaimed:get()
	end)

	return {
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(34, 108),
			Size = UDim2.fromOffset(692, 34),
			Text = "One tap opens the group join prompt, then claims your reward.",
			TextColor3 = Color3.fromRGB(255, 226, 226),
			MaxTextSize = 24,
			ZIndex = 42,
		}),

		makeRewardCard(
			UDim2.fromOffset(36, 158),
			CHEST_ICON,
			"+5,000 Speed",
			"one-time starter gift",
			Color3.fromRGB(255, 118, 68),
			Color3.fromRGB(190, 36, 24)
		),
		-- Wins TRAO NGAY ở dòng to (thứ quyết định người chơi có bấm Join hay không), buff
		-- vĩnh viễn xuống dòng phụ. Số lấy thẳng từ config để chữ trên thẻ không bao giờ
		-- hứa sai — xem khối cân bằng trong `Config/GroupChest.luau`.
		makeRewardCard(
			UDim2.fromOffset(273, 158),
			Theme.UI_ASSETS.Trophy,
			`+{GroupChestConfig.INSTANT_WINS_REWARD} Wins now`,
			`+{math.floor((GroupChestConfig.WINS_MULTIPLIER - 1) * 100 + 0.5)}% Wins forever`,
			Color3.fromRGB(255, 72, 88),
			Color3.fromRGB(150, 18, 42)
		),
		makeRewardCard(
			UDim2.fromOffset(510, 158),
			FAN_TAG_ICON,
			"[Fan] Tag",
			"green chat prefix",
			Color3.fromRGB(255, 93, 128),
			Color3.fromRGB(138, 22, 74)
		),

		-- Chỉ còn MỘT điều kiện nên pill phải nằm giữa: nút CLAIM bên dưới neo ở x = 380,
		-- pill rộng 300 ⇒ x = 380 − 150 = 230. Để nguyên 64 là lệch hẳn sang trái.
		makeStatusPill("Join Group", State.groupChestIsGroupMember, UDim2.fromOffset(230, 322)),

		-- Nút CLAIM: `MakeSurface` + `Zoom` (viền và chữ phóng cùng nhịp, nở đều 4 góc).
		Theme.MakeSurface({
			ClassName = "TextButton",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(380, 404),
			Size = UDim2.fromOffset(560, 76),
			ZIndex = 45,
			Radius = 16,
			Border = 4,
			Color = Computed(function()
				if State.groupChestHasClaimed:get() then
					return Color3.fromRGB(80, 132, 86)
				end
				return if claimHovered:get() then Color3.fromRGB(255, 118, 92) else Color3.fromRGB(235, 62, 54)
			end),
			ColorB = Computed(function()
				if State.groupChestHasClaimed:get() then
					return Color3.fromRGB(34, 82, 42)
				end
				return Color3.fromRGB(150, 18, 28)
			end),
			Zoom = { Hovered = claimHovered, Scale = 1.06 },
			Activated = runJoinAndClaim,
			MouseEnter = function()
				claimHovered:set(true)
			end,
			MouseLeave = function()
				claimHovered:set(false)
			end,
			Content = function(zoom)
				return {
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							if State.groupChestHasClaimed:get() then
								return "CLAIMED"
							end
							return if canClaim:get() then "CLAIM GROUP CHEST" else "JOIN + CLAIM"
						end),
						Zoom = zoom,
						MaxTextSize = 32,
						ZIndex = 48,
					}),
				}
			end,
		}),
	}
end

function GroupChestModal.Build()
	return ModalShell.Build({
		Id = "groupChest",
		Width = PANEL_WIDTH,
		Height = PANEL_HEIGHT,
		PanelColor = Color3.fromRGB(54, 16, 18),
		PanelTransparency = 0.18,
		HeaderColor = Color3.fromRGB(255, 91, 84),
		HeaderColorB = Color3.fromRGB(171, 18, 34),
		Icon = CHEST_ICON,
		Title = "Group Chest",
		OnClose = Manager.CloseGroupChest,
		Content = buildContent(),
	})
end

return GroupChestModal
