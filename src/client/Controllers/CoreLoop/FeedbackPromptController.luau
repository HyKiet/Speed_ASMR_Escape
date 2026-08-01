--!strict
--[[
	FeedbackPromptController.luau — Feedback bằng API GỐC của Roblox.

	Thay cho hệ thống feedback tự code trước đây (FeedbackModal + FeedbackService +
	packet `requestSubmitFeedback` + DataStore "GameFeedbackLogs_v1"). Cái cũ ghi lời
	nhắn vào DataStore riêng — không ai đọc, và KHÔNG bao giờ hiện lên Creator Dashboard.

	Bản mới gọi `SocialService:PromptFeedbackSubmissionAsync()`: Roblox tự dựng hộp thoại
	"Share Your Feedback", tự lọc chữ, tự chống spam (1 lần/ngày/experience), và feedback
	chảy thẳng vào Creator Dashboard → Audience → Feedback.

	LƯU Ý KHI TEST (Roblox ghi rõ trong docs): API này KHÔNG chạy trong Studio playtest.
	Muốn thấy hộp thoại thật phải publish rồi vào bằng app Roblox. Trong Studio, controller
	sẽ hiện toast báo thay vì im lặng.

	Người chơi ineligible (chủ game, chưa đủ tuổi, vừa gửi hôm nay) sẽ được chính hộp
	thoại của Roblox báo — không cần client tự kiểm.

	Hai lối vào: nút Feedback trên HUD (RightPanel) và ProximityPrompt trên hòm thư
	`Workspace.Feedback.Mailbox`.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local Workspace = game:GetService("Workspace")

local Toast = require(script.Parent.Parent.HUD.Toast)

local localPlayer = Players.LocalPlayer

local PROMPT_NAME = "MailboxPrompt"

-- `PromptFeedbackSubmissionAsync` yield tới khi người chơi đóng hộp thoại (hoặc timeout).
-- Cờ này chặn việc bấm nút liên tục làm xếp chồng nhiều coroutine chờ cùng lúc.
local promptOpen = false

local FeedbackPromptController = {}

function FeedbackPromptController.Prompt()
	if promptOpen then
		return
	end
	promptOpen = true

	task.spawn(function()
		if RunService:IsStudio() then
			Toast.Show("Feedback chỉ mở được trong game thật (không chạy ở Studio)")
			promptOpen = false
			return
		end

		local ok, err = pcall(function()
			SocialService:PromptFeedbackSubmissionAsync()
		end)
		if not ok then
			warn(`[FeedbackPromptController] Không mở được hộp thoại feedback: {tostring(err)}`)
			Toast.Show("Could not open feedback right now")
		end

		promptOpen = false
	end)
end

local function attachPrompt(mailbox: BasePart)
	local prompt = mailbox:FindFirstChild(PROMPT_NAME)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		local newPrompt = Instance.new("ProximityPrompt")
		newPrompt.Name = PROMPT_NAME
		newPrompt.ObjectText = "Feedback Mailbox"
		newPrompt.ActionText = "Send Feedback"
		newPrompt.KeyboardKeyCode = Enum.KeyCode.E
		newPrompt.HoldDuration = 0
		newPrompt.MaxActivationDistance = 10
		newPrompt.RequiresLineOfSight = false
		newPrompt.Parent = mailbox
		prompt = newPrompt
	end

	if prompt:GetAttribute("BoundToFeedback") then
		return
	end
	prompt:SetAttribute("BoundToFeedback", true)
	prompt.Triggered:Connect(function(player: Player)
		if player == localPlayer then
			FeedbackPromptController.Prompt()
		end
	end)
end

local function scanMailbox()
	local mailbox = Workspace:FindFirstChild("Mailbox", true)
	if mailbox and mailbox:IsA("BasePart") then
		attachPrompt(mailbox)
	end
end

function FeedbackPromptController.Start()
	scanMailbox()

	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "Mailbox" and descendant:IsA("BasePart") then
			attachPrompt(descendant)
		elseif descendant.Name == PROMPT_NAME and descendant:IsA("ProximityPrompt") then
			local parent = descendant.Parent
			if parent and parent.Name == "Mailbox" and parent:IsA("BasePart") then
				attachPrompt(parent)
			end
		end
	end)
end

return FeedbackPromptController
