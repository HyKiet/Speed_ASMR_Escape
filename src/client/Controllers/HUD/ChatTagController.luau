--!strict
-- TextChatService tag: [VIP] vàng cho chủ VIP gamepass (ưu tiên cao nhất, ĐÈ [Fan]);
-- [Fan] xanh cho thành viên group. Attribute IsVIP do GamepassService set (cả khi mua giữa session).

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local VIP_TAG = '<font color="#FFD700">[VIP]</font>'
local FAN_TAG = '<font color="#00FF00">[Fan]</font>'

local ChatTagController = {}

local function getPlayerFromMessage(message: TextChatMessage): Player?
	local source = message.TextSource
	if not source then
		return nil
	end

	return Players:GetPlayerByUserId(source.UserId)
end

function ChatTagController.Start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local player = getPlayerFromMessage(message)
		if not player then
			return nil
		end

		local tag: string? = nil
		if player:GetAttribute("IsVIP") == true then
			tag = VIP_TAG
		elseif player:GetAttribute("IsGroupMember") == true then
			tag = FAN_TAG
		end
		if not tag then
			return nil
		end

		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = `{tag} {message.PrefixText}`
		return properties
	end
end

return ChatTagController
