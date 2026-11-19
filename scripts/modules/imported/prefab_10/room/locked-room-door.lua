---@id 0a0b0700-c308-4753-9880-10155d9aadca
---@referenceName room_locked-room-door.lua
-- 十二号客房门：必须先向房东太太领取钥匙，随后可开门并自动闭合
---@displayName 十二号客房门
---@start
---@var OpenAngle:number=-92
---@name 开门角度
---@desc 门扇绕本地纵轴转动的角度
---@var AutoCloseSeconds:number=6
---@name 自动闭合延时
---@desc 玩家离开门口后，门保持打开的秒数
---@group 客房
---@end

local UnityEngine = CS.UnityEngine
local Time = CS.UnityEngine.Time
local Logger = require("official.core.logger")
local RuntimeScope = require("official.core.runtime_scope")

local logger = Logger.create("guest-room-door")
local runtimeScope, runtimeScopeReason = RuntimeScope.from(self)
local HOST_SCRIPT_ID = "reception_runtime-host.lua"
local SWING_SPEED = 110

local host = nil
local doorTransform = nil
local baseEuler = nil
local interactorButton = nil
local isActorInRange = false
local currentAngle = 0
local targetAngle = 0
local closeAtTime = nil
local hasShownUnlockMessage = false

local function hasKey()
  return host ~= nil and type(host.HasRoomKey) == "function" and host.HasRoomKey()
end

local function setButtonText()
  if interactorButton == nil then
    return
  end
  local label = interactorButton:GetComponentInChildren(typeof(CS.UnityEngine.UI.Text))
  if label ~= nil then
    label.text = hasKey() and "用钥匙开门" or "需要客房钥匙"
  end
end

function Start()
  doorTransform = self.transform
  if doorTransform ~= nil then
    baseEuler = doorTransform.localEulerAngles
  end
  if runtimeScope == nil then
    logger:warnOnce("room-door-no-scope", "客房门缺少运行作用域", runtimeScopeReason)
    return
  end
  host = runtimeScope:GetRuntimeHostScript(HOST_SCRIPT_ID)
  if host == nil then
    logger:warnOnce("room-door-no-host", "未找到寄宿公寓接待协调脚本", HOST_SCRIPT_ID)
  end
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then
    return
  end
  isActorInRange = true
  closeAtTime = nil
  self:EnableInteraction()
  setButtonText()
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then
    return
  end
  isActorInRange = false
  if targetAngle ~= 0 then
    closeAtTime = Time.time + AutoCloseSeconds
  end
  self:DisableInteraction()
end

function OnFocus(handType)
  interactorButton = self:AddInteractorButton()
  setButtonText()
end

function OnLostFocus(handType)
  if interactorButton ~= nil then
    self:RemoveInteractorButton(interactorButton)
    interactorButton = nil
  end
end

function OnInteractorButtonClick(index)
  if index ~= 1 then
    return
  end
  if not hasKey() then
    if host ~= nil and type(host.ShowRoomDoorMessage) == "function" then
      host.ShowRoomDoorMessage(false)
    end
    return
  end
  targetAngle = OpenAngle
  closeAtTime = nil
  setButtonText()
  if not hasShownUnlockMessage and host ~= nil and type(host.ShowRoomDoorMessage) == "function" then
    hasShownUnlockMessage = true
    host.ShowRoomDoorMessage(true)
  end
end

function Update()
  if doorTransform == nil or baseEuler == nil then
    return
  end
  setButtonText()
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
  doorTransform.localEulerAngles = UnityEngine.Vector3(baseEuler.x, baseEuler.y + currentAngle, baseEuler.z)
end
