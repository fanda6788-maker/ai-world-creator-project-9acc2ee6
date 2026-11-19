---@id 8d4fd43a-aecd-4e7a-9f28-d5c717cff0b4
---@referenceName vehicle_drive.lua
-- 驾驶维多利亚四轮马车：输入采样、刚体推进、车轮滚动与双马步态
---@displayName 马车驾驶
---@start
---@var topSpeed:number=6
---@name 最高速度
---@desc 马车前进时的最高水平速度，单位米/秒
---@group 驾驶
---@var reverseSpeed:number=2.5
---@name 倒车速度
---@desc 后退时的最高速度
---@group 驾驶
---@var acceleration:number=3.5
---@name 加速能力
---@desc 按住前进时达到目标速度的快慢
---@group 驾驶
---@var braking:number=7
---@name 刹车力度
---@desc 行驶中输入反方向时降低速度的快慢
---@group 驾驶
---@var turnSpeed:number=50
---@name 转向灵敏度
---@desc 左右输入控制马车转向的快慢
---@group 转向
---@var grip:number=0.92
---@name 抓地力
---@desc 数值越高越贴合车头方向，数值越低越容易侧滑
---@group 转向
---@end

local RuntimeScope = require("official.core.runtime_scope")
local UnityEngine = CS.UnityEngine
local Vector3 = UnityEngine.Vector3
local Quaternion = UnityEngine.Quaternion
local Mathf = UnityEngine.Mathf
local Time = UnityEngine.Time
local Vector2 = UnityEngine.Vector2
local RigidbodyType = typeof(CS.UnityEngine.Rigidbody)

local runtimeScope, runtimeScopeReason = RuntimeScope.from(self)

local NetService = CS.DouyinNetService
if NetService == nil then
  NetService = DouyinNetService
end

local DEAD_ZONE = 0.1
local MAX_ANGULAR_VELOCITY = 3.5
local COASTING_DRAG = 3.0
local MIN_STEER_SCALE = 0.45
local CONTROL_REQUEST_DELAY = 0.12

-- 车轮与马蹄都是实体网格碰撞体，模型自带的 0.6 摩擦会在每个物理步把脚本写入的
-- 推进速度完全抵消，导致马车无法起步。驾驶手感由加速度与横向抓地力计算决定，
-- 所以车体碰撞体改用低摩擦材质，让刚体按脚本速度行驶。
local SLIDE_FRICTION = 0.1

local rb = nil
local hasDriver = false
local localDriverActorId = nil
local controlRequestPending = false
local controlRequestTimer = 0

local moveVec = Vector2.zero
local onMoveInputStart = nil
local onMoveInputPerform = nil
local onMoveInputCancel = nil

local frontWheelLeft = nil
local frontWheelRight = nil
local rearWheelLeft = nil
local rearWheelRight = nil
local wheelSpin = 0
local legs = {}
local gaitPhase = 0

-- Trot gaits: diagonal pairs share a phase, the right horse runs slightly ahead.
local LEG_DEFINITIONS = {
  { base = "HorseTeam/HorseLeft/LegFrontLeft", phase = 0 },
  { base = "HorseTeam/HorseLeft/LegFrontRight", phase = math.pi },
  { base = "HorseTeam/HorseLeft/LegRearLeft", phase = math.pi },
  { base = "HorseTeam/HorseLeft/LegRearRight", phase = 0 },
  { base = "HorseTeam/HorseRight/LegFrontLeft", phase = 0.3 },
  { base = "HorseTeam/HorseRight/LegFrontRight", phase = math.pi + 0.3 },
  { base = "HorseTeam/HorseRight/LegRearLeft", phase = math.pi + 0.3 },
  { base = "HorseTeam/HorseRight/LegRearRight", phase = 0.3 },
}

local function isNetworkSettled()
  if NetService == nil then return true end
  return NetService.isNetworkSettled
end

local function getHorizontalSpeed()
  if rb == nil then return 0 end
  local velocity = rb.velocity
  local horizontal = Vector3(velocity.x, 0, velocity.z)
  return horizontal.magnitude
end

-- 车体所有实体碰撞体改用统一的低摩擦材质，避免接地摩擦抵消驾驶速度。
local function applyDriveFriction()
  local colliders = self.gameObject:GetComponentsInChildren(typeof(CS.UnityEngine.Collider), true)
  if colliders == nil or colliders.Length == 0 then return end

  local material = CS.UnityEngine.PhysicMaterial("CarriageGroundFriction")
  material.dynamicFriction = SLIDE_FRICTION
  material.staticFriction = SLIDE_FRICTION
  material.bounciness = 0
  material.frictionCombine = CS.UnityEngine.PhysicMaterialCombine.Minimum
  material.bounceCombine = CS.UnityEngine.PhysicMaterialCombine.Minimum

  for index = 0, colliders.Length - 1 do
    local collider = colliders[index]
    if not collider.isTrigger then
      collider.sharedMaterial = material
    end
  end
end

local function cacheVehicleNodes()
  if runtimeScope == nil then return end

  frontWheelLeft = runtimeScope:GetTransformByPath("WheelSet/WheelFrontLeftPivot")
  frontWheelRight = runtimeScope:GetTransformByPath("WheelSet/WheelFrontRightPivot")
  rearWheelLeft = runtimeScope:GetTransformByPath("WheelSet/WheelRearLeftPivot")
  rearWheelRight = runtimeScope:GetTransformByPath("WheelSet/WheelRearRightPivot")

  for index = 1, #LEG_DEFINITIONS do
    local definition = LEG_DEFINITIONS[index]
    local legName = string.match(definition.base, "([^/]+)$") or definition.base
    local upper = runtimeScope:GetTransformByPath(definition.base .. "UpperPivot")
    -- 下节枢轴挂在上节枢轴下，路径必须经由上节节点。
    local lower = runtimeScope:GetTransformByPath(
      definition.base .. "UpperPivot/" .. legName .. "LowerPivot"
    )
    if upper ~= nil and lower ~= nil then
      legs[#legs + 1] = { upper = upper, lower = lower, phase = definition.phase }
    end
  end
end

local function resolveDriveInput()
  local throttle = 0
  local steer = 0
  if math.abs(moveVec.y) > DEAD_ZONE then throttle = moveVec.y end
  if math.abs(moveVec.x) > DEAD_ZONE then steer = moveVec.x end
  return throttle, steer
end

local function registerInput()
  onMoveInputStart = function()
    moveVec = Vector2.zero
  end
  onMoveInputPerform = function(vec)
    moveVec = vec
  end
  onMoveInputCancel = function()
    moveVec = Vector2.zero
  end

  CS.DouyinInputService.onMoveInputStart:AddListener(onMoveInputStart)
  CS.DouyinInputService.onMoveInputPerform:AddListener(onMoveInputPerform)
  CS.DouyinInputService.onMoveInputCancel:AddListener(onMoveInputCancel)
end

local function unregisterInput()
  if onMoveInputStart ~= nil then
    CS.DouyinInputService.onMoveInputStart:RemoveListener(onMoveInputStart)
    onMoveInputStart = nil
  end
  if onMoveInputPerform ~= nil then
    CS.DouyinInputService.onMoveInputPerform:RemoveListener(onMoveInputPerform)
    onMoveInputPerform = nil
  end
  if onMoveInputCancel ~= nil then
    CS.DouyinInputService.onMoveInputCancel:RemoveListener(onMoveInputCancel)
    onMoveInputCancel = nil
  end
end

local function releaseControl()
  controlRequestPending = false
  controlRequestTimer = 0
  if self:HasControllership() then
    self:ReleaseControllership()
  end
end

local function stopVehicle()
  if rb == nil then return end
  if not rb.isKinematic then
    local velocity = rb.velocity
    rb.velocity = Vector3(0, velocity.y, 0)
    rb.angularVelocity = Vector3.zero
  end
  rb.isKinematic = true
end

local function updateControlRequest()
  if not hasDriver then return end
  if controlRequestPending then return end
  if not isNetworkSettled() then return end

  if self:HasControllership() then
    if rb ~= nil and rb.isKinematic then
      rb.isKinematic = false
    end
    return
  end

  if controlRequestTimer > 0 then
    controlRequestTimer = controlRequestTimer - Time.deltaTime
    return
  end

  controlRequestPending = true
  self:RequestControllership(function(success)
    controlRequestPending = false
    if self:IsNull() then return end
    if success and hasDriver and rb ~= nil then
      rb.isKinematic = false
    end
  end)
end

local function updateWheels(dt)
  if frontWheelLeft == nil then return end
  local signedSpeed = 0
  if rb ~= nil then
    signedSpeed = Vector3.Dot(rb.velocity, self.transform.forward)
  end
  if math.abs(signedSpeed) < 0.02 then return end

  -- 绕 X 轴正向旋转会让轮顶向 +Z 侧倒，因此前进（+Z）使用负向角增量。
  wheelSpin = wheelSpin - signedSpeed * dt
  local frontAngle = math.deg(wheelSpin / 0.5)
  local rearAngle = math.deg(wheelSpin / 0.62)

  frontWheelLeft.localEulerAngles = Vector3(frontAngle, 0, 0)
  if frontWheelRight ~= nil then
    frontWheelRight.localEulerAngles = Vector3(frontAngle, 0, 0)
  end
  if rearWheelLeft ~= nil then
    rearWheelLeft.localEulerAngles = Vector3(rearAngle, 0, 0)
  end
  if rearWheelRight ~= nil then
    rearWheelRight.localEulerAngles = Vector3(rearAngle, 0, 0)
  end
end

local function updateGait(dt)
  if #legs == 0 then return end

  local speed = getHorizontalSpeed()
  if hasDriver and speed > 0.2 then
    gaitPhase = gaitPhase + (1.0 + speed * 0.5) * dt
  end

  local scale = 0
  if hasDriver then
    scale = Mathf.Clamp01(speed / 2.2)
  end

  for index = 1, #legs do
    local leg = legs[index]
    local angle = gaitPhase + leg.phase
    local swing = math.sin(angle) * 0.36 * scale
    local bend = math.max(0, math.cos(angle)) * 0.55 * scale
    leg.upper.localEulerAngles = Vector3(math.deg(swing), 0, 0)
    leg.lower.localEulerAngles = Vector3(-math.deg(bend), 0, 0)
  end
end

-- 扩展点：由驾驶座脚本在本地玩家落座、离座时调用。
function SetDriverSeated(seated, actorId)
  if seated then
    hasDriver = true
    localDriverActorId = actorId
    moveVec = Vector2.zero
    controlRequestPending = false
    controlRequestTimer = CONTROL_REQUEST_DELAY
  else
    hasDriver = false
    localDriverActorId = nil
    moveVec = Vector2.zero
    stopVehicle()
    releaseControl()
  end
end

function Start()
  rb = self.gameObject:GetComponent(RigidbodyType)
  if rb ~= nil then
    rb.isKinematic = true
    rb.maxAngularVelocity = MAX_ANGULAR_VELOCITY
  end

  cacheVehicleNodes()
  applyDriveFriction()
  registerInput()
end

function Update()
  updateControlRequest()
  updateWheels(Time.deltaTime)
  updateGait(Time.deltaTime)
end

function FixedUpdate()
  if rb == nil then return end
  if rb.isKinematic then return end
  if not hasDriver or localDriverActorId == nil then return end
  if not self:HasOwnership() or not self:HasControllership() then return end

  local dt = Time.fixedDeltaTime
  local throttle, steer = resolveDriveInput()

  local forward = self.transform.forward
  local horizontalForward = Vector3(forward.x, 0, forward.z)
  if horizontalForward.sqrMagnitude <= 0.0001 then return end
  horizontalForward:Normalize()

  local velocity = rb.velocity
  local horizontalVelocity = Vector3(velocity.x, 0, velocity.z)
  local horizontalSpeed = horizontalVelocity.magnitude
  local speedRatio = 0
  if topSpeed > 0.0001 then
    speedRatio = Mathf.Clamp01(horizontalSpeed / topSpeed)
  end

  local localVelocity = self.transform:InverseTransformDirection(velocity)
  local forwardSpeed = localVelocity.z
  local movingForward = forwardSpeed >= -0.05
  local acceleratingForward = throttle >= 0
  local maxSpeed = reverseSpeed
  if movingForward then
    maxSpeed = topSpeed
  end
  if horizontalSpeed < 0.2 and acceleratingForward then
    maxSpeed = topSpeed
  end

  local steerScale = Mathf.Lerp(1.0, MIN_STEER_SCALE, speedRatio * speedRatio)
  local turningPower = steer * turnSpeed * dt * steerScale
  if math.abs(steer) > DEAD_ZONE and (horizontalSpeed > 0.2 or math.abs(throttle) > DEAD_ZONE) then
    local steerDirection = 1
    if forwardSpeed < -0.05 then
      steerDirection = -1
    end
    local turn = Quaternion.Euler(0, turningPower * steerDirection, 0)
    rb:MoveRotation(self.transform.rotation * turn)
  end

  local brakingNow = (movingForward and throttle < -0.01)
    or ((not movingForward) and throttle > 0.01)
  local accelPower = acceleration
  if brakingNow then
    accelPower = braking
  end

  local rampT = 0
  if maxSpeed > 0.0001 then
    rampT = Mathf.Clamp01(horizontalSpeed / maxSpeed)
  end
  local ramp = Mathf.Lerp(3.0, 1.0, rampT * rampT)

  if not (horizontalSpeed >= maxSpeed and not brakingNow) then
    horizontalVelocity = horizontalVelocity + horizontalForward * (throttle * accelPower * ramp * dt)
  end
  if horizontalVelocity.magnitude > maxSpeed then
    horizontalVelocity = Vector3.ClampMagnitude(horizontalVelocity, maxSpeed)
  end

  if math.abs(throttle) < 0.01 then
    horizontalVelocity = Vector3.MoveTowards(horizontalVelocity, Vector3.zero, COASTING_DRAG * dt)
  end

  local right = self.transform.right
  local lateralSpeed = Vector3.Dot(horizontalVelocity, right)
  local lateralFriction = 4.0 + grip * 8.0
  local correction = lateralSpeed * Mathf.Clamp01(lateralFriction * dt)
  horizontalVelocity = Vector3(
    horizontalVelocity.x - right.x * correction,
    0,
    horizontalVelocity.z - right.z * correction
  )
  if horizontalVelocity.magnitude > maxSpeed then
    horizontalVelocity = Vector3.ClampMagnitude(horizontalVelocity, maxSpeed)
  end

  rb.velocity = Vector3(horizontalVelocity.x, velocity.y, horizontalVelocity.z)

  local localAngular = self.transform:InverseTransformDirection(rb.angularVelocity)
  local yawT = Mathf.Clamp01(2.4 * dt * (0.6 + speedRatio * 0.8))
  if math.abs(steer) > DEAD_ZONE then
    yawT = yawT * 0.35
  end
  local pitchRollT = Mathf.Clamp01(7.5 * dt)
  local corrected = Vector3(
    Mathf.Lerp(localAngular.x, 0, pitchRollT),
    Mathf.Lerp(localAngular.y, 0, yawT),
    Mathf.Lerp(localAngular.z, 0, pitchRollT)
  )
  local correctedWorld = self.transform:TransformDirection(corrected)
  if correctedWorld.magnitude > MAX_ANGULAR_VELOCITY then
    correctedWorld = Vector3.ClampMagnitude(correctedWorld, MAX_ANGULAR_VELOCITY)
  end
  rb.angularVelocity = correctedWorld
end

function OnDestroy()
  unregisterInput()
  hasDriver = false
  localDriverActorId = nil
  releaseControl()
end
