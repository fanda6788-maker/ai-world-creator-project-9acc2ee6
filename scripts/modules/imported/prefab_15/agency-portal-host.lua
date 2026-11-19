---@id a9855eb8-bb12-4f97-88b8-a2488de91bd2
---@referenceName agency-portal-host.lua
-- 侦探事务所进入/离开传送协调：渐暗、音效、移动锁定与锚点传送
---@displayName 事务所传送管理
---@start
---@var DoorOpenSound:UnityEngine.AudioClip=nil
---@name 开门音效
---@refFrom asset
---@assetCategory Music
---@dataType Audio
---@var DoorOpenVolume:number=0.9
---@name 开门音量
---@desc 0–1，0 表示静音
---@var DoorOpenMaxDistance:number=14
---@name 开门最大作用范围
---@desc 距声源的可听半径，单位米；小于等于 0 时不播放
---@var DoorCloseSound:UnityEngine.AudioClip=nil
---@name 关门音效
---@refFrom asset
---@assetCategory Music
---@dataType Audio
---@var DoorCloseVolume:number=0.9
---@name 关门音量
---@desc 0–1，0 表示静音
---@var DoorCloseMaxDistance:number=14
---@name 关门最大作用范围
---@desc 距声源的可听半径，单位米；小于等于 0 时不播放
---@end

local Logger = require("official.core.logger")
local RuntimeScope = require("official.core.runtime_scope")

local logger = Logger.create("agency-portal-host")
local runtimeScope, runtimeScopeReason = RuntimeScope.from(self)

-- 传送节奏与冷却，属于实现固定值，不放在面板。
local FADE_OUT_DURATION = 0.3
local HOLD_DURATION = 0.12
local FADE_IN_DURATION = 0.32
local COOLDOWN_SECONDS = 1.0

local exteriorAnchor = nil
local interiorAnchor = nil
local safeAnchors = { Floor2 = nil, Floor3 = nil }
local fadeView = nil

-- idle / fadeOut / hold / fadeIn
local state = "idle"
local timer = 0
local pendingDirection = nil
local pendingActorId = nil
local lockedActor = nil
local cooldownUntil = 0

local exteriorAudio = nil
local interiorAudio = nil

local function clamp01(value)
  if type(value) ~= "number" then
    return 0
  end
  if value < 0 then
    return 0
  end
  if value > 1 then
    return 1
  end
  return value
end

local function getAnchorTransform(direction)
  if direction == "enter" then
    return interiorAnchor
  elseif direction == "leave" then
    return exteriorAnchor
  end
  return nil
end

-- 为门侧节点按需创建专用 AudioSource，使声源随外壳/内部实例一起移动。
local function getAnchorAudio(anchorTransform, isOpenSound)
  if anchorTransform == nil then
    return nil
  end
  local cached = isOpenSound and exteriorAudio or interiorAudio
  if cached ~= nil then
    return cached
  end
  local go = anchorTransform.gameObject
  if go == nil then
    return nil
  end
  local source = go:GetComponent(typeof(CS.UnityEngine.AudioSource))
  if source == nil then
    source = go:AddComponent(typeof(CS.UnityEngine.AudioSource))
  end
  if source == nil then
    return nil
  end
  source.playOnAwake = false
  source.loop = false
  source.spatialBlend = 1
  source.rolloffMode = CS.UnityEngine.AudioRolloffMode.Linear
  if isOpenSound then
    exteriorAudio = source
  else
    interiorAudio = source
  end
  return source
end

-- 播放木门声音：进入时用外壳正门音源，离开时用内部入口音源。
local function playDoorSound(direction)
  local openSound = direction == "enter"
  local clip = openSound and DoorOpenSound or DoorCloseSound
  local volume = openSound and DoorOpenVolume or DoorCloseVolume
  local maxDistance = openSound and DoorOpenMaxDistance or DoorCloseMaxDistance
  if clip == nil or type(volume) ~= "number" or type(maxDistance) ~= "number" then
    return
  end
  if volume <= 0 or maxDistance <= 0 then
    return
  end
  local soundAnchor = openSound and exteriorAnchor or interiorAnchor
  local source = getAnchorAudio(soundAnchor, openSound)
  if source == nil then
    return
  end
  source:Stop()
  source.volume = clamp01(volume)
  source.minDistance = math.min(1, maxDistance * 0.1)
  source.maxDistance = maxDistance
  pcall(function()
    source:PlayOneShot(clip)
  end)
end

local function releaseLock()
  if lockedActor ~= nil then
    local actor = lockedActor
    lockedActor = nil
    pcall(function()
      actor:Immobilize(false)
    end)
  end
end

local function resetFadeView()
  if fadeView ~= nil and type(fadeView.ResetView) == "function" then
    pcall(function()
      fadeView.ResetView()
    end)
  end
end

local function clearPending()
  pendingDirection = nil
  pendingActorId = nil
  timer = 0
  state = "idle"
end

-- 取消传送：恢复玩家控制与画面，不把玩家送到世界原点。
local function cancelTransit()
  releaseLock()
  resetFadeView()
  clearPending()
end

local function finishTransit()
  releaseLock()
  clearPending()
  cooldownUntil = CS.UnityEngine.Time.time + COOLDOWN_SECONDS
end

-- 读取锚点当前世界位置与朝向后传送，锚点移动后仍然有效。
local function performTeleport()
  local target = getAnchorTransform(pendingDirection)
  if target == nil or lockedActor == nil then
    return false
  end
  local pos = target.position
  local rot = target.rotation
  if pos == nil or rot == nil then
    return false
  end
  lockedActor:Teleport(
    CS.UnityEngine.Vector3(pos.x, pos.y, pos.z),
    CS.UnityEngine.Quaternion(rot.x, rot.y, rot.z, rot.w))
  return true
end

-- Runtime UI 在 Start 中注册视图接口，Host 不直接持有 UI 控件。
function RegisterFadeView(view)
  if type(view) ~= "table" then
    return false
  end
  fadeView = view
  return true
end

-- 外部模型实例登记“外部落点”，内部模型实例登记“内部落点/二三层安全落点”。
function RegisterAnchors(role, anchors)
  if type(anchors) ~= "table" then
    return false
  end
  if role == "exterior" then
    if anchors.Transit ~= nil then
      exteriorAnchor = anchors.Transit
    end
    return true
  end
  if role == "interior" then
    if anchors.Transit ~= nil then
      interiorAnchor = anchors.Transit
    end
    if anchors.Floor2 ~= nil then
      safeAnchors.Floor2 = anchors.Floor2
    end
    if anchors.Floor3 ~= nil then
      safeAnchors.Floor3 = anchors.Floor3
    end
    return true
  end
  return false
end

function IsReady()
  return runtimeScope ~= nil
end

-- 玩家在触发区确认交互后调用。返回 true 表示已受理并进入传送流程。
function RequestTransit(direction, actorId)
  if runtimeScope == nil then
    return false
  end
  if direction ~= "enter" and direction ~= "leave" then
    return false
  end
  if state ~= "idle" then
    return false
  end
  if CS.UnityEngine.Time.time < cooldownUntil then
    return false
  end
  local target = getAnchorTransform(direction)
  if target == nil then
    logger:warnOnce("anchor-missing-" .. direction,
      "传送锚点缺失，取消本次传送", tostring(direction))
    return false
  end
  local id = tonumber(actorId)
  if id == nil then
    return false
  end
  local actor = DouyinActorService.GetActorById(math.floor(id))
  if actor == nil or not actor.isLocal then
    return false
  end

  pendingDirection = direction
  pendingActorId = id
  lockedActor = actor
  actor:Immobilize(true)
  playDoorSound(direction)

  timer = 0
  local fadeStarted = false
  if fadeView ~= nil and type(fadeView.FadeToBlack) == "function" then
    local ok = pcall(function()
      fadeView.FadeToBlack(FADE_OUT_DURATION)
    end)
    fadeStarted = ok == true
  end
  if fadeStarted then
    state = "fadeOut"
  else
    -- 渐暗界面不可用时仍然完成传送，只是没有画面过渡。
    if performTeleport() then
      finishTransit()
    else
      cancelTransit()
      return false
    end
  end
  return true
end

-- 异常恢复入口：把本地玩家送到二层/三层走廊安全落点。
function RecoverToSafePoint(floor, actorId)
  local target = floor == 2 and safeAnchors.Floor2 or nil
  if target == nil and floor == 3 then
    target = safeAnchors.Floor3
  end
  if target == nil then
    return false
  end
  local id = tonumber(actorId)
  if id == nil then
    return false
  end
  local actor = DouyinActorService.GetActorById(math.floor(id))
  if actor == nil or not actor.isLocal then
    return false
  end
  local pos = target.position
  local rot = target.rotation
  actor:Teleport(
    CS.UnityEngine.Vector3(pos.x, pos.y, pos.z),
    CS.UnityEngine.Quaternion(rot.x, rot.y, rot.z, rot.w))
  return true
end

function Start()
  if runtimeScope == nil then
    logger:warnOnce("scope-unavailable", "传送协调脚本无法取得资源作用域",
      tostring(runtimeScopeReason))
    return
  end
  releaseLock()
  resetFadeView()
  clearPending()
  cooldownUntil = 0
end

function Update()
  if state == "idle" then
    return
  end
  timer = timer + CS.UnityEngine.Time.deltaTime

  if state == "fadeOut" then
    if timer >= FADE_OUT_DURATION then
      if not performTeleport() then
        cancelTransit()
        return
      end
      timer = 0
      state = "hold"
    end
    return
  end

  if state == "hold" then
    if timer >= HOLD_DURATION then
      timer = 0
      local fadeStarted = false
      if fadeView ~= nil and type(fadeView.FadeFromBlack) == "function" then
        local ok = pcall(function()
          fadeView.FadeFromBlack(FADE_IN_DURATION)
        end)
        fadeStarted = ok == true
      end
      if fadeStarted then
        state = "fadeIn"
      else
        finishTransit()
      end
    end
    return
  end

  if state == "fadeIn" then
    if timer >= FADE_IN_DURATION then
      finishTransit()
    end
  end
end

function OnDestroy()
  releaseLock()
  resetFadeView()
  pendingDirection = nil
  pendingActorId = nil
  fadeView = nil
  exteriorAnchor = nil
  interiorAnchor = nil
  safeAnchors = { Floor2 = nil, Floor3 = nil }
  exteriorAudio = nil
  interiorAudio = nil
end
