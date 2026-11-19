---@id 519aaf73-d01c-4431-b028-51187a26d4de
---@sourceScriptId ba2898e8-7d67-4a2b-b8b0-679e0d49659c
---@referenceName pub_bar.lua
-- 酒保交互：靠近吧台前的酒保时出现点酒按钮，点击后由 Host 结算并让酒保欠身示意
---@displayName 酒保点酒
---@start
---@var DrinkText:string="向酒保要一杯威士忌"
---@name 按钮文案
---@desc 玩家走近吧台、面对酒保时显示的按钮文字
---@end

local UnityEngine = CS.UnityEngine
local Time = CS.UnityEngine.Time
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
local localActor = nil
local hostTransform = nil
local baseRotation = nil
local bowTimer = 0
local bowDuration = 0.7
local bowAngle = 8

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

local function requestDrink()
    if host == nil and runtimeScope ~= nil then
        host, _ = runtimeScope:GetRuntimeHostScript(hostScriptId)
    end
    if host == nil or type(host.RequestDrink) ~= "function" then
        logger:warnOnce("host-missing", "酒馆协调脚本不可用", tostring(scopeReason))
        return
    end
    host.RequestDrink(localActor)
    bowTimer = bowDuration
end

local function updateBow()
    if hostTransform == nil or baseRotation == nil then
        return
    end
    if bowTimer > 0 then
        bowTimer = bowTimer - Time.deltaTime
        local t = 1 - math.max(0, bowTimer) / bowDuration
        local bend = math.sin(t * math.pi) * bowAngle
        hostTransform.localRotation = baseRotation * UnityEngine.Quaternion.Euler(bend, 0, 0)
    elseif bowTimer > -0.2 then
        bowTimer = -1
        hostTransform.localRotation = baseRotation
    end
end

function Start()
    if runtimeScope == nil then
        logger:warnOnce("scope", "资源作用域不可用", tostring(scopeReason))
        return
    end
    hostTransform = self.transform
    baseRotation = hostTransform.localRotation
end

function OnActorTriggerEnter(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    localActor = actor
    self:EnableInteraction()
end

function OnActorTriggerExit(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    localActor = nil
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
    requestDrink()
end

function Update()
    updateBow()
end

function OnDisable()
    hideButton()
    localActor = nil
end

function OnDestroy()
    hideButton()
    localActor = nil
end
