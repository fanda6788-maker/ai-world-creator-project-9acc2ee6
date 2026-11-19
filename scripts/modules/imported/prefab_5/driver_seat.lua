---@id 0c898675-7136-46bd-aae4-ea84fd038e26
---@referenceName driver_seat.lua
-- 马车驾驶座：靠近提示、坐下对齐、离座清理，并把驾驶状态交给马车根脚本
---@displayName 马车驾驶座

local RuntimeScope = require("official.core.runtime_scope")
local UnityEngine = CS.UnityEngine
local Vector3 = UnityEngine.Vector3
local Quaternion = UnityEngine.Quaternion
local DouyinCameraService = CS.DouyinCameraService

local runtimeScope, runtimeScopeReason = RuntimeScope.from(self)

-- 驾驶态相机：拉远抬高，避免车厢挡住视线；离座恢复宿主默认值。
local DRIVE_CAMERA_DISTANCE = 7.5
local DRIVE_CAMERA_PITCH = 14
local DRIVE_CAMERA_OFFSET = Vector3(0, 1.2, 0)
local DEFAULT_CAMERA_DISTANCE = 4
local DEFAULT_CAMERA_PITCH = 0
local DEFAULT_CAMERA_OFFSET = Vector3(0, 0, 0)

local function applyDriveCameraView()
  if DouyinCameraService == nil then return end
  DouyinCameraService.SetDistance(DRIVE_CAMERA_DISTANCE)
  DouyinCameraService.SetPitch(DRIVE_CAMERA_PITCH)
  DouyinCameraService.SetOffset(DRIVE_CAMERA_OFFSET)
end

local function restoreDefaultCameraView()
  if DouyinCameraService == nil then return end
  DouyinCameraService.SetDistance(DEFAULT_CAMERA_DISTANCE)
  DouyinCameraService.SetPitch(DEFAULT_CAMERA_PITCH)
  DouyinCameraService.SetOffset(DEFAULT_CAMERA_OFFSET)
end

local seatAnchor = nil
local standAnchor = nil
local interactionButton = nil
local localActorId = nil
local hasPassenger = false

-- 在座 Actor -> 座位锚点；远端 Avatar 也走同一套对齐表现。
local seatedActors = {}
local savedScale = {}
local savedPosition = {}
local savedRotation = {}
local savedColliderEnabled = {}

local function setButtonText(text)
  if interactionButton == nil then return end
  local label = interactionButton:GetComponentInChildren(typeof(CS.UnityEngine.UI.Text), true)
  if label ~= nil then
    label.text = text
  end
end

local function ensureInteractionButton()
  if interactionButton == nil then
    interactionButton = self:AddInteractorButton()
  end
  if hasPassenger then
    setButtonText("下车")
  else
    setButtonText("上车")
  end
end

local function removeInteractionButton()
  if interactionButton ~= nil then
    self:RemoveInteractorButton(interactionButton)
    interactionButton = nil
  end
end

-- 扩展点：返回当前座椅唯一的 SeatAnchor。
local function resolveSeatTrans()
  return seatAnchor
end

local function alignActorHipsToSeat(actor, target)
  target = target or resolveSeatTrans()
  if actor == nil or target == nil then return end

  local trans = actor.gameObject.transform
  trans:SetParent(target)
  trans.localPosition = Vector3.zero
  trans.localRotation = Quaternion.identity

  local original = savedScale[actor] or Vector3.one
  local parentScale = target.lossyScale
  trans.localScale = Vector3(
    original.x / parentScale.x,
    original.y / parentScale.y,
    original.z / parentScale.z
  )

  local animator = actor.gameObject:GetComponentInChildren(typeof(CS.UnityEngine.Animator))
  if animator == nil then return end

  local hips = animator:GetBoneTransform(CS.UnityEngine.HumanBodyBones.Hips)
  if hips == nil then return end

  local hipsPosition = hips.position
  local actorPosition = trans.position
  trans.position = Vector3(
    actorPosition.x - (hipsPosition.x - actorPosition.x),
    actorPosition.y - (hipsPosition.y - actorPosition.y),
    actorPosition.z - (hipsPosition.z - actorPosition.z)
  )
end

local function setActorColliderEnabled(actor, enabled)
  if actor == nil or actor.gameObject == nil then return end
  local collider = actor.gameObject:GetComponent(typeof(CS.UnityEngine.Collider))
  if collider == nil then return end

  if not enabled then
    savedColliderEnabled[actor] = collider.enabled
    collider.enabled = false
  else
    local previous = savedColliderEnabled[actor]
    collider.enabled = previous == nil or previous
    savedColliderEnabled[actor] = nil
  end
end

local function placeActorAtStandPoint(actor)
  if actor == nil then return end

  local trans = actor.gameObject.transform
  trans:SetParent(nil)

  if savedScale[actor] ~= nil then
    trans.localScale = savedScale[actor]
    savedScale[actor] = nil
  end

  if standAnchor ~= nil then
    actor.position = standAnchor.position
    actor.rotation = standAnchor.rotation
  elseif savedPosition[actor] ~= nil then
    actor.position = savedPosition[actor]
    actor.rotation = savedRotation[actor]
  else
    local right = self.transform.right
    actor.position = Vector3(
      self.transform.position.x + right.x * 1.4,
      self.transform.position.y,
      self.transform.position.z + right.z * 1.4
    )
    actor.rotation = self.transform.rotation
  end

  savedPosition[actor] = nil
  savedRotation[actor] = nil
end

-- 扩展点：把本地驾驶状态交给马车根脚本，由它负责物理推进。
local function setVehicleDriver(seated, actor)
  if runtimeScope == nil then return end
  local drive = runtimeScope:GetScript("vehicle_drive.lua")
  if drive == nil then return end
  if type(drive.SetDriverSeated) ~= "function" then return end
  local actorId = nil
  if actor ~= nil then
    actorId = actor.actorID
  end
  drive.SetDriverSeated(seated, actorId)
end

function Start()
  if runtimeScope == nil then return end
  seatAnchor = runtimeScope:GetTransformByPath("DriverSeat/SeatAnchor")
  standAnchor = runtimeScope:GetTransformByPath("StandUpAnchor")
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then return end
  localActorId = actor.actorID
  self:EnableInteraction()
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then return end

  -- 在座时保留 Actor ID 和交互通道，避免移动的马车离开原 Trigger 后无法下车。
  if not hasPassenger then
    self:DisableInteraction()
    localActorId = nil
  end
end

function OnFocus(handType)
  ensureInteractionButton()
end

function OnLostFocus(handType)
  -- 在座时保留下车按钮，马车驶离原焦点后仍能站起。
  if hasPassenger then return end
  removeInteractionButton()
end

function OnInteractorButtonClick(index)
  if index ~= 1 then return end
  if localActorId == nil then return end

  local actor = DouyinActorService.GetActorById(localActorId)
  if actor == nil then return end

  if hasPassenger then
    actor:StandUp(self.gameObject)
  else
    if actor:IsFlying() then return end
    if resolveSeatTrans() == nil then return end
    actor:SitDown(self.gameObject)
  end
end

function OnSeatEntered(actor, handType)
  if actor == nil then return end

  local target = resolveSeatTrans()
  if target == nil then return end

  local trans = actor.gameObject.transform
  savedPosition[actor] = trans.position
  savedRotation[actor] = trans.rotation
  savedScale[actor] = trans.localScale

  alignActorHipsToSeat(actor, target)
  seatedActors[actor] = target
  setActorColliderEnabled(actor, false)

  if actor.isLocal then
    hasPassenger = true
    -- 先交接驾驶状态，避免按钮或相机调用出错时马车一直停在锁定状态。
    setVehicleDriver(true, actor)
    self:EnableInteraction()
    ensureInteractionButton()
    applyDriveCameraView()
  end
end

function OnSeatExited(actor)
  if actor == nil then return end

  seatedActors[actor] = nil
  placeActorAtStandPoint(actor)
  setActorColliderEnabled(actor, true)

  if actor.isLocal then
    hasPassenger = false
    -- 先收回驾驶状态，保证离座后马车立即停止响应摇杆。
    setVehicleDriver(false, nil)
    setButtonText("上车")
    restoreDefaultCameraView()
  end
end

-- 坐姿动画会持续改变 Hips 相对根节点的位置，必须在动画更新后重对齐。
function LateUpdate()
  for actor, target in pairs(seatedActors) do
    alignActorHipsToSeat(actor, target)
  end
end

function OnDestroy()
  interactionButton = nil
  restoreDefaultCameraView()
end
