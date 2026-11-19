---@id f636479a-490f-485c-b823-9563911cbe1e
---@sourceScriptId 85bdcf3b-28f4-4faa-b62b-7d0a17c718d3
---@referenceName door_door-interaction.lua
-- 正门进出交互：门口触发区按玩家所在侧显示“进门/出门”，开门后自动闭合
---@displayName 正门进出交互
---@start
---@var OpenAngle:number=-80
---@name 开门角度
---@desc 正门绕枢轴局部 +Y 的旋转角度（度），负值向门厅内摆开
---@var AutoCloseSeconds:number=6
---@name 自动关闭延时
---@desc 玩家离开门口区域后，正门保持打开的秒数
---@group 正门
---@end

local UnityEngine = CS.UnityEngine
local Time = CS.UnityEngine.Time
local Logger = require("official.core.logger")
local RuntimeScope = require("official.core.runtime_scope")

local logger = Logger.create("front-door")
local runtimeScope, runtimeScopeReason = RuntimeScope.from(self)

local DOOR_NODE_PATH = "FrontDoorPivot"
-- 门扇所在模型局部 z 平面；局部 z 大于该值时玩家仍在街上
local DOOR_PLANE_Z = -3.06
local SWING_SPEED = 110

local doorTransform = nil
local localActor = nil
local interactorButton = nil
local isActorInRange = false
local currentAngle = 0
local targetAngle = 0
local closeAtTime = nil
local lastOutsideSide = nil

local function isActorOutside(actor)
  if actor == nil or self.transform == nil then
    return true
  end
  local localPoint = self.transform:InverseTransformPoint(actor.position)
  return localPoint.z > DOOR_PLANE_Z
end

local function setButtonText(text)
  if interactorButton == nil then
    return
  end
  local label = interactorButton:GetComponentInChildren(typeof(CS.UnityEngine.UI.Text))
  if label ~= nil then
    label.text = text
  end
end

-- 按钮在聚焦时创建，之后玩家可能跨过门槛而不重新聚焦；
-- 仅在所在侧变化时刷新文案，避免每帧写 UI。
local function refreshButtonSide()
  if interactorButton == nil or localActor == nil then
    return
  end
  local outside = isActorOutside(localActor)
  if outside == lastOutsideSide then
    return
  end
  lastOutsideSide = outside
  setButtonText(outside and "进门" or "出门")
end

function Start()
  if runtimeScope == nil then
    logger:warnOnce("door-no-scope", "正门交互缺少运行作用域", runtimeScopeReason)
    return
  end
  doorTransform = runtimeScope:GetTransformByPath(DOOR_NODE_PATH)
  if doorTransform == nil then
    logger:warnOnce("door-node-missing", "未找到正门枢轴节点", DOOR_NODE_PATH)
  end
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then
    return
  end
  localActor = actor
  isActorInRange = true
  closeAtTime = nil
  self:EnableInteraction()
  refreshButtonSide()
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then
    return
  end
  isActorInRange = false
  localActor = nil
  -- 计时从玩家离开门口区域开始，而不是从点击开门开始。
  if targetAngle ~= 0 then
    closeAtTime = Time.time + AutoCloseSeconds
  end
  self:DisableInteraction()
end

function OnFocus(handType)
  interactorButton = self:AddInteractorButton()
  lastOutsideSide = nil
  refreshButtonSide()
end

function OnLostFocus(handType)
  if interactorButton == nil then
    return
  end
  self:RemoveInteractorButton(interactorButton)
  interactorButton = nil
  lastOutsideSide = nil
end

function OnInteractorButtonClick(index)
  if index ~= 1 or doorTransform == nil then
    return
  end
  targetAngle = OpenAngle
  -- 人在门口区域内时保持打开；离开后再开始自动关闭倒计时。
  closeAtTime = nil
end

function Update()
  if doorTransform == nil then
    return
  end
  refreshButtonSide()

  if isActorInRange then
    closeAtTime = nil
  elseif targetAngle ~= 0 and closeAtTime == nil then
    closeAtTime = Time.time + AutoCloseSeconds
  elseif closeAtTime ~= nil and Time.time >= closeAtTime then
    targetAngle = 0
    closeAtTime = nil
  end

  local step = SWING_SPEED * Time.deltaTime
  if currentAngle < targetAngle then
    currentAngle = math.min(targetAngle, currentAngle + step)
  elseif currentAngle > targetAngle then
    currentAngle = math.max(targetAngle, currentAngle - step)
  else
    return
  end
  doorTransform.localEulerAngles = UnityEngine.Vector3(0, currentAngle, 0)
end
