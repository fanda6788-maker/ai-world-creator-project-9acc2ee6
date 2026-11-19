---@id ba2898e8-7d67-4a2b-b8b0-679e0d49659c
---@referenceName pub_bar.lua
-- 吧台前的点酒交互：靠近出现按钮，点击后由 Host 结算并提示
---@displayName 吧台点酒
---@start
---@var DrinkText:string="点一杯麦芽威士忌"
---@name 按钮文案
---@desc 玩家站在吧台前时显示的交互按钮文字
---@end

local TextType = typeof(CS.UnityEngine.UI.Text)
local RuntimeScope = require("official.core.runtime_scope")
local Logger = require("official.core.logger")
local logger = Logger.create("pub-bar")
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
        label.text = DrinkText
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
    if host == nil or type(host.RequestDrink) ~= "function" then
        logger:warnOnce("host-missing", "酒馆协调脚本不可用", scopeReason)
        return
    end
    host.RequestDrink()
end

function OnDisable()
    hideButton()
end

function OnDestroy()
    hideButton()
end
