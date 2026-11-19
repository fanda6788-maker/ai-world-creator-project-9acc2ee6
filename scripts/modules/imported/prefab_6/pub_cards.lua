---@id 93d20ac9-a2f7-4ad0-b799-c34a14cca50c
---@referenceName pub_cards.lua
-- 牌桌旁的打牌交互：靠近出现按钮，点击后打开二十一点界面
---@displayName 牌桌打牌
---@start
---@var PlayText:string="坐下打一局牌"
---@name 按钮文案
---@desc 玩家靠近牌桌时显示的交互按钮文字
---@end

local TextType = typeof(CS.UnityEngine.UI.Text)
local RuntimeScope = require("official.core.runtime_scope")
local Logger = require("official.core.logger")
local logger = Logger.create("pub-cards")
local runtimeScope, scopeReason = RuntimeScope.from(self)

local hostScriptId = "pub_host.lua"
local host = nil
if runtimeScope ~= nil then
    host, _ = runtimeScope:GetRuntimeHostScript(hostScriptId)
end

local interactionButton = nil

local function showButton()
    if interactionButton == nil then
        interactionButton = self:AddInteractorButton()
    end
    if interactionButton == nil then
        return
    end
    local label = interactionButton:GetComponentInChildren(TextType, true)
    if label ~= nil then
        label.gameObject:SetActive(true)
        label.text = PlayText
    end
end

local function hideButton()
    if interactionButton ~= nil then
        self:RemoveInteractorButton(interactionButton)
        interactionButton = nil
    end
end

function OnActorTriggerEnter(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    self:EnableInteraction()
end

function OnActorTriggerExit(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    self:DisableInteraction()
    hideButton()
end

function OnFocus(handType)
    showButton()
end

function OnLostFocus(handType)
    hideButton()
end

function OnInteractorButtonClick(index)
    if index ~= 1 then
        return
    end
    if host == nil or type(host.OpenCardGame) ~= "function" then
        logger:warnOnce("host-missing", "酒馆协调脚本不可用", scopeReason)
        return
    end
    host.OpenCardGame()
end

function OnDisable()
    hideButton()
end

function OnDestroy()
    hideButton()
end
