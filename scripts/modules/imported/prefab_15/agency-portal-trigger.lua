---@id 0b409171-0fb9-443f-9c02-a50f1d7fe8e4
---@referenceName agency-portal-trigger.lua
-- 侦探事务所入口/出口触发区：显示交互提示并把传送请求交给 Host
---@displayName 事务所传送触发区
---@start
---@var Direction:string="enter"
---@name 传送方向
---@desc enter 从室外进入事务所；leave 从室内离开事务所
---@enum enter=进入事务所,leave=离开事务所
---@var PromptText:string="进入侦探事务所"
---@name 交互提示
---@desc 玩家靠近后显示在交互按钮上的文字
---@end

local Logger = require("official.core.logger")
local RuntimeScope = require("official.core.runtime_scope")

local logger = Logger.create("agency-portal-trigger")
local runtimeScope, runtimeScopeReason = RuntimeScope.from(self)
local host = nil
if runtimeScope ~= nil then
  host = runtimeScope:GetRuntimeHostScript("agency-portal-host.lua")
end

local interactionButton = nil
local localActorId = nil

local function setButtonText(button, text)
  if button == nil then
    return
  end
  local label = button:GetComponentInChildren(typeof(CS.UnityEngine.UI.Text), true)
  if label ~= nil then
    label.text = text
  end
end

local function getHost()
  if host ~= nil then
    return host
  end
  if runtimeScope == nil then
    return nil
  end
  host = runtimeScope:GetRuntimeHostScript("agency-portal-host.lua")
  return host
end

function Start()
  if runtimeScope == nil then
    logger:warnOnce("scope-unavailable", "触发区无法取得资源作用域",
      tostring(runtimeScopeReason))
  end
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then
    return
  end
  localActorId = actor.actorID
  self:EnableInteraction()
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then
    return
  end
  self:DisableInteraction()
  localActorId = nil
end

function OnFocus(handType)
  interactionButton = self:AddInteractorButton()
  setButtonText(interactionButton, PromptText)
end

function OnLostFocus(handType)
  if interactionButton ~= nil then
    self:RemoveInteractorButton(interactionButton)
  end
  interactionButton = nil
end

function OnInteractorButtonClick(index)
  if index ~= 1 then
    return
  end
  if localActorId == nil then
    return
  end
  local actor = DouyinActorService.GetActorById(math.floor(localActorId))
  if actor == nil or not actor.isLocal then
    return
  end
  local portalHost = getHost()
  if portalHost == nil or type(portalHost.RequestTransit) ~= "function" then
    logger:warnOnce("host-unavailable", "传送 Host 不可用，取消本次交互")
    return
  end
  if portalHost.RequestTransit(Direction, actor.actorID) then
    -- 受理后立刻关闭当前交互通道，避免重复点击；玩家离开范围后按钮清理。
    self:DisableInteraction()
  end
end

function OnDestroy()
  if interactionButton ~= nil then
    self:RemoveInteractorButton(interactionButton)
  end
  interactionButton = nil
  localActorId = nil
  host = nil
end
