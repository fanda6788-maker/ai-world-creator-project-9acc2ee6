---@id adb3f68a-c9a4-4cfc-a5a1-55f8ed027241
---@referenceName entrance-door.lua
-- 侦探事务所大门：靠近台阶出现交互按钮，点击后门扇绕合页轴向内开/关（各端本地表现）
---@displayName 事务所大门
---@start
---@var OpenAngle:number=85
---@name 门开启角度
---@desc 门向内打开的最大角度（度）
---@var DoorSpeed:number=150
---@name 开关门速度
---@desc 门每秒转动的角度
---@var EnterText:string="推门进入"
---@name 开门按钮文字
---@var ExitText:string="关上门"
---@name 关门按钮文字
---@end

local UnityEngine = CS.UnityEngine
local Time = CS.UnityEngine.Time
local RuntimeScope = require("official.core.runtime_scope")

-- 当前模型实例作用域，用于查找合页节点
local runtimeScope = RuntimeScope.from(self)

-- 合页节点路径（相对模型实例根）
local DOOR_PATH = "Exterior/Entrance/DoorPivot"

local doorPivot = nil
local button = nil
local isOpen = false
local currentAngle = 0
local targetAngle = 0

local function refreshButtonText()
  if button == nil then
    return
  end
  local label = button:GetComponentInChildren(typeof(CS.UnityEngine.UI.Text), true)
  if label ~= nil then
    label.text = isOpen and ExitText or EnterText
  end
end

local function removeButton()
  if button ~= nil then
    self:RemoveInteractorButton(button)
    button = nil
  end
end

function Start()
  if runtimeScope == nil then
    return
  end
  local pivot = runtimeScope:GetTransformByPath(DOOR_PATH)
  if pivot ~= nil then
    doorPivot = pivot
    currentAngle = 0
    targetAngle = 0
    doorPivot.localEulerAngles = UnityEngine.Vector3(0, 0, 0)
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
end

function OnFocus(handType)
  button = self:AddInteractorButton()
  refreshButtonText()
end

function OnLostFocus(handType)
  removeButton()
end

function OnInteractorButtonClick(index)
  if index ~= 1 then
    return
  end
  isOpen = not isOpen
  -- 引擎导入后模型 X 轴镜像，合页在 -X 一侧：负角为向室内开
  targetAngle = isOpen and -OpenAngle or 0
  refreshButtonText()
end

function Update()
  if doorPivot == nil then
    return
  end
  if math.abs(targetAngle - currentAngle) < 0.05 then
    currentAngle = targetAngle
  else
    local step = DoorSpeed * Time.deltaTime
    if currentAngle < targetAngle then
      currentAngle = math.min(targetAngle, currentAngle + step)
    else
      currentAngle = math.max(targetAngle, currentAngle - step)
    end
  end
  doorPivot.localEulerAngles = UnityEngine.Vector3(0, currentAngle, 0)
end

function OnDisable()
  removeButton()
end
