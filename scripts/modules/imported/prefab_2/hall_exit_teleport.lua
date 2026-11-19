---@id f3aaf3a9-46f4-4fd5-84b8-ae113ab1b809
---@referenceName hall_exit_teleport.lua
-- 门厅内交互：本地玩家点击按钮后传送到门外台阶前锚点
---@displayName 离开警察局
---@start
---@end

local RuntimeScope = require("official.core.runtime_scope")
local runtimeScope = RuntimeScope.from(self)

-- 传送目标锚点：模型实例内的门外出口点
local exitTransform = nil

function Start()
  if runtimeScope == nil then return end
  exitTransform = runtimeScope:GetTransformByPath("ExteriorExitPoint")
end

local localActorId = nil
local interactorButton = nil

local function getLocalActor()
  if localActorId == nil then return nil end
  local actor = DouyinActorService.GetActorById(localActorId)
  if actor == nil or not actor.isLocal then return nil end
  return actor
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then return end
  localActorId = actor.actorID
  self:EnableInteraction()
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then return end
  self:DisableInteraction()
  localActorId = nil
end

function OnFocus(handType)
  interactorButton = self:AddInteractorButton()
  if interactorButton == nil then return end
  local label = interactorButton:GetComponentInChildren(typeof(CS.UnityEngine.UI.Text), true)
  if label ~= nil then
    label.text = "离开警察局"
  end
end

function OnLostFocus(handType)
  if interactorButton ~= nil then
    self:RemoveInteractorButton(interactorButton)
  end
  interactorButton = nil
end

function OnInteractorButtonClick(index)
  if index ~= 1 then return end
  local actor = getLocalActor()
  if actor == nil or exitTransform == nil then return end
  actor:Teleport(exitTransform.position, exitTransform.rotation)
end
