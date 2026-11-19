---@id 42b1c309-4fcd-4796-ba01-b78a22779dcf
---@sourceScriptId adb3f68a-c9a4-4cfc-a5a1-55f8ed027241
---@referenceName entrance-door.lua
-- 事务所入口：玩家靠近正门后出现“进入事务所”，点击后传送到门内安全落点。
---@displayName 事务所入口交互
---@start
---@var EnterText:string="进入事务所"
---@name 入口按钮文字
---@desc 玩家靠近事务所正门时显示的交互文字
---@var InsideOffset:number=3
---@name 门内落点距离
---@desc 从入口交互区沿建筑内部方向移动的米数
---@end

local UnityEngine = CS.UnityEngine

local currentActor = nil
local interactionButton = nil

local function clearButton()
  if interactionButton ~= nil then
    self:RemoveInteractorButton(interactionButton)
    interactionButton = nil
  end
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then
    return
  end
  currentActor = actor
  self:EnableInteraction()
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then
    return
  end
  if currentActor == actor then
    currentActor = nil
  end
  self:DisableInteraction()
  clearButton()
end

function OnFocus(handType)
  clearButton()
  interactionButton = self:AddInteractorButton()
  if interactionButton == nil then
    return
  end
  local label = interactionButton:GetComponentInChildren(typeof(UnityEngine.UI.Text), true)
  if label ~= nil then
    label.text = EnterText
  end
end

function OnLostFocus(handType)
  clearButton()
end

function OnInteractorButtonClick(index)
  if index ~= 1 or currentActor == nil or not currentActor.isLocal then
    return
  end
  local insideTarget = self.transform:TransformPoint(UnityEngine.Vector3(0, 0, -InsideOffset))
  currentActor:Teleport(insideTarget)
  self:DisableInteraction()
  clearButton()
end

function OnDisable()
  currentActor = nil
  clearButton()
end
