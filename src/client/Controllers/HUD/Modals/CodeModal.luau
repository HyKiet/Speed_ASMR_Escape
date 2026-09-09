--!strict
-- Dựng ô nhập mã trên client bằng ModalShell; gửi mã qua ByteNet để server kiểm tra và cấp quà.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)

local Children = Fusion.Children
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange

local CodeModal = {}

local PANEL_WIDTH = 740
local PANEL_HEIGHT = 380

local function submitCode()
	local code = State.codeInput:get():gsub("%s+", ""):upper()
	if #code == 0 then
		Toast.Show("Enter a code first!")
		return
	end
	GamePackets.requestRedeemCode.send({ code = code })
	State.codeInput:set("")
	Manager.CloseCode()
end

local function buildContent(): { any }
	return {
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(40, 106),
			Size = UDim2.fromOffset(660, 34),
			Text = "Enter a promo code below to claim your reward!",
			TextColor3 = Color3.fromRGB(210, 255, 228),
			MaxTextSize = 24,
			ZIndex = 43,
		}),

		-- Ô nhập mã. Dùng `MakeSurface` (2026-08-16) thay vì tự dựng "khung đen + ruột": chỉ khối
		-- đi qua `MakeSurface` mới được kẹp SÀN độ dày viền theo px thật, nên trên cửa sổ nhỏ
		-- viền không mỏng đi tới mức biến mất.
		Theme.MakeSurface({
			Position = UDim2.fromOffset(40, 148),
			Size = UDim2.fromOffset(480, 72),
			ZIndex = 42,
			Radius = 14,
			Border = Tokens.BORDER,
			Studs = false,
			Color = Color3.fromRGB(16, 72, 36),
			ColorB = Color3.fromRGB(4, 32, 14),
			Content = {
				New("TextBox")({
					BackgroundTransparency = 1,
					ClearTextOnFocus = false,
					Font = Theme.FONT,
					PlaceholderColor3 = Color3.fromRGB(80, 140, 100),
					PlaceholderText = "TYPE CODE HERE...",
					Position = UDim2.fromOffset(12, 4),
					Size = UDim2.fromOffset(456, 64),
					Text = State.codeInput,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0,
					ZIndex = 44,
					[OnChange("Text")] = function(text: string)
						if not State.isEnteringCode then
							return
						end
						State.codeInput:set(text)
					end,
					[OnEvent("Focused")] = function()
						State.isEnteringCode = true
					end,
					[OnEvent("FocusLost")] = function(enterPressed: boolean)
						State.isEnteringCode = false
						if enterPressed then
							submitCode()
						end
					end,
					[Children] = {
						Theme.MakeTextSizeConstraint(36, 14),
					},
				}),
			},
		}),

		--[[
			Nút REDEEM.

			── ĐÃ SỬA 2026-08-16 (user: "nút redeem chưa đồng bộ hiệu ứng với các button khác") ──
			Nút này là chỗ CUỐI CÙNG còn dùng hiệu ứng tự chế: một `New("UIScale")` gắn thẳng vào
			nút với `TweenInfo` riêng (0.12s Quad, phóng 1.05) thay vì đi qua `Theme.HoverZoom`.
			Vì vậy nó lọt qua cả đợt chuyển đổi trước — `grep Theme.HoverZoom` không thấy nó.

			Hệ quả: nhịp phóng lệch với mọi nút khác (0.12s Quad vs 0.18s Back), viền đen đứng im,
			chữ không phóng, và nó nở về phải + xuống dưới thay vì đều 4 góc. Giờ đi chung đường
			`MakeSurface` + `Zoom` như tất cả.
		]]
		Theme.MakeSurface({
			ClassName = "TextButton",
			Position = UDim2.fromOffset(534, 148),
			Size = UDim2.fromOffset(166, 72),
			ZIndex = 42,
			Radius = 14,
			Border = Tokens.BORDER,
			Color = Color3.fromRGB(88, 230, 140),
			ColorB = Color3.fromRGB(30, 150, 72),
			Zoom = { Hovered = State.codeRedeemHovered, Scale = 1.08 },
			Activated = submitCode,
			MouseEnter = function()
				State.codeRedeemHovered:set(true)
			end,
			MouseLeave = function()
				State.codeRedeemHovered:set(false)
			end,
			Content = function(zoom)
				return {
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = "REDEEM",
						Zoom = zoom,
						MaxTextSize = 26,
						ZIndex = 44,
					}),
				}
			end,
		}),

		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(40, 234),
			Size = UDim2.fromOffset(660, 40),
			Text = "Follow our social media for new codes!",
			TextColor3 = Color3.fromRGB(180, 240, 210),
			MaxTextSize = 22,
			ZIndex = 43,
		}),

		New("Frame")({
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.7,
			Position = UDim2.fromOffset(40, 284),
			Size = UDim2.fromOffset(660, 3),
			ZIndex = 42,
			[Children] = {
				Theme.MakeCorner(2),
			},
		}),

		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(40, 296),
			Size = UDim2.fromOffset(660, 72),
			Text = "Join Discord & like on Roblox to stay updated!",
			TextColor3 = Color3.fromRGB(150, 220, 180),
			MaxTextSize = 20,
			ZIndex = 43,
		}),
	}
end

function CodeModal.Build()
	return ModalShell.Build({
		Id = "code",
		Width = PANEL_WIDTH,
		Height = PANEL_HEIGHT,
		PanelColor = Color3.fromRGB(22, 110, 58),
		HeaderColor = Color3.fromRGB(96, 226, 142),
		HeaderColorB = Color3.fromRGB(28, 162, 84),
		Icon = Theme.UI_ASSETS.Code,
		Title = "Redeem Code",
		OnClose = Manager.CloseCode,
		Content = buildContent(),
	})
end

return CodeModal
