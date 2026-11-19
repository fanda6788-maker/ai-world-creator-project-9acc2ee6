---@id 1e781da1-0b87-4837-81bd-3dd1534a52cc
---@referenceName entrance-door.lua
-- 正门双扇木门的开合交互：靠近后显示按钮，点击开合两扇门（每端自行维护开合表现）
---@displayName 大门开合
---@start
---@var OpenAngle:number=100
---@name 开门角度
---@desc 门扇绕铰链旋转的角度，单位为度
---@end

local UnityEngine = CS.UnityEngine
local Logger = require("official.core.logger")
local RuntimeScope = require("official.core.runtime_scope")

local logger = Logger.create("entrance-door")
local runtimeScope, runtimeScopeReason = RuntimeScope.from(self)

local BUTTON_OPEN = "开门"
local BUTTON_CLOSE = "关门"

-- 铰链、门扇状态与本地按钮上下文；只服务当前客户端的表现。
local hingeLeft = nil
local hingeRight = nil
local isOpen = false
local interactionButton = nil
local localActorId = nil
local isReady = false

local function applyDoorState(open)
  if hingeLeft == nil or hingeRight == nil then
    return
  end
  local angle = open and OpenAngle or 0
  hingeLeft.localEulerAngles = UnityEngine.Vector3(0, angle, 0)
  hingeRight.localEulerAngles = UnityEngine.Vector3(0, -angle, 0)
  isOpen = open
end

local function refreshButtonText()
  if interactionButton == nil then
    return
  end
  local label = interactionButton:GetComponentInChildren(typeof(CS.UnityEngine.UI.Text), true)
  if label ~= nil then
    if isOpen then
      label.text = BUTTON_CLOSE
    else
      label.text = BUTTON_OPEN
    end
  end
end

function Start()
  if runtimeScope == nil then
    logger:warnOnce("scope-missing", "interaction disabled", runtimeScopeReason)
    return
  end
  hingeLeft = runtimeScope:GetTransformByPath("EntranceDoors/DoorHingeLeftPivot")
  hingeRight = runtimeScope:GetTransformByPath("EntranceDoors/DoorHingeRightPivot")
  if hingeLeft == nil or hingeRight == nil then
    logger:warnOnce("hinge-missing", "door leaves not found, interaction disabled")
    return
  end
  applyDoorState(false)
  isReady = true
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
  if not isReady then
    return
  end
  interactionButton = self:AddInteractorButton()
  refreshButtonText()
end

function OnLostFocus(handType)
  if interactionButton ~= nil then
    self:RemoveInteractorButton(interactionButton)
  end
  interactionButton = nil
end

function OnInteractorButtonClick(index)
  if index ~= 1 or not isReady or localActorId == nil then
    return
  end
  applyDoorState(not isOpen)
  refreshButtonText()
end
