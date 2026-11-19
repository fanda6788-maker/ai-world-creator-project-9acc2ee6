---@id 27c24db5-4003-4949-9c01-25e54734b61d
---@referenceName agency-fade.lua
---@displayName 事务所传送渐暗
-- 侦探事务所传送时的全屏渐暗与恢复，向 Runtime Host 注册淡入淡出视图。

local Logger = require("official.core.logger")
local RuntimeScope = require("official.core.runtime_scope")
local Animation = require("official.ui.animation")

local logTag = "agency-fade"
local logger = Logger.create(logTag)
local Anim = Animation.create(logTag)

local Time = CS.UnityEngine.Time
local CanvasGroupType = typeof(CS.UnityEngine.CanvasGroup)

local OVERLAY_PATH = "fadeOverlay"
local DEFAULT_FADE_DURATION = 0.4
local HOST_SCRIPT_NAME = "agency-portal-host.lua"

local runtimeScope = RuntimeScope.from(self)
if runtimeScope == nil then
  logger:warnOnce("scope-unavailable", "事务所渐暗遮罩未启用：无法获取当前界面作用域")
end

-- fadeOverlay 在 Start 中解析并缓存；fadeToken 用于丢弃过期的淡出回调。
local fadeOverlay = nil
local fadeActive = false
local fadeEndsAt = 0
local fadeToken = 0
local pendingHideAt = 0
local pendingHide = false

local function normalizeDuration(duration)
  local value = tonumber(duration)
  if value == nil then
    return DEFAULT_FADE_DURATION
  end
  if value < 0 then
    return 0
  end
  return value
end

-- 取得遮罩上的 CanvasGroup；缺失时补一个，保证 alpha 动画与隐藏一定可用。
local function resolveOverlay()
  if fadeOverlay ~= nil then
    return fadeOverlay
  end
  if runtimeScope == nil then
    return nil
  end
  local go = runtimeScope:GetGameObjectByPath(OVERLAY_PATH)
  if go ~= nil then
    if go:GetComponent(CanvasGroupType) == nil then
      go:AddComponent(CanvasGroupType)
    end
    fadeOverlay = go
  end
  return fadeOverlay
end

local function getOverlayGroup()
  local go = resolveOverlay()
  if go == nil then
    return nil, nil
  end
  return go, go:GetComponent(CanvasGroupType)
end

-- 遮罩不可见时同时关闭射线拦截，避免残留的 CanvasGroup 挡住界面点击。
local function applyHiddenState()
  local go, group = getOverlayGroup()
  if go == nil then
    return
  end
  if group ~= nil then
    group.alpha = 0
    group.blocksRaycasts = false
    group.interactable = false
  end
  go:SetActive(false)
end

function ResetView()
  fadeToken = fadeToken + 1
  fadeActive = false
  fadeEndsAt = 0
  pendingHide = false
  pendingHideAt = 0
  Anim.clearAll()
  if fadeOverlay == nil then
    return false
  end
  applyHiddenState()
  return true
end

function FadeToBlack(duration)
  local go, group = getOverlayGroup()
  if go == nil then
    logger:warnOnce("overlay-missing", "遮罩未找到，跳过 FadeToBlack")
    return false
  end

  local d = normalizeDuration(duration)
  fadeToken = fadeToken + 1
  fadeActive = true
  pendingHide = false
  pendingHideAt = 0
  fadeEndsAt = Time.unscaledTime + d
  if group ~= nil then
    group.alpha = 0
    group.blocksRaycasts = true
    group.interactable = true
  end
  go:SetActive(true)
  -- fadeIn 会先把 alpha 归零再淡入到不透明，遮挡期间允许拦截点击。
  Anim.fadeIn(go, d)
  return true
end

function FadeFromBlack(duration)
  local go = resolveOverlay()
  if go == nil then
    logger:warnOnce("overlay-missing", "遮罩未找到，跳过 FadeFromBlack")
    return false
  end

  local d = normalizeDuration(duration)
  if not go.activeSelf then
    -- 没有可见遮罩时不制造一次黑屏闪烁，直接回到可再次使用的状态。
    ResetView()
    return true
  end

  fadeToken = fadeToken + 1
  local token = fadeToken
  fadeActive = true
  fadeEndsAt = Time.unscaledTime + d
  pendingHide = true
  pendingHideAt = Time.unscaledTime + d + 0.15

  Anim.fadeOutThen(go, d, function()
    -- 回调再次确认状态：被重置或被新的淡入取代时不隐藏当前遮罩。
    if token ~= fadeToken or not fadeActive then
      return
    end
    fadeActive = false
    fadeEndsAt = 0
    pendingHide = false
    pendingHideAt = 0
    applyHiddenState()
  end)
  return true
end

function IsFading()
  if not fadeActive then
    return false
  end
  return Time.unscaledTime < fadeEndsAt
end

function Start()
  resolveOverlay()
  ResetView()

  local host = runtimeScope and runtimeScope:GetRuntimeHostScript(HOST_SCRIPT_NAME) or nil
  if host ~= nil and type(host.RegisterFadeView) == "function" then
    host.RegisterFadeView({
      FadeToBlack = FadeToBlack,
      FadeFromBlack = FadeFromBlack,
      ResetView = ResetView,
      IsFading = IsFading,
    })
    return
  end

  logger:warnOnce("host-unavailable", "未找到事务所传送 Host，渐暗视图仅保留本地接口")
end

function Update()
  -- 唯一的帧推进入口，使用不受 timeScale 影响的时钟。
  Anim.tick(Time.unscaledDeltaTime)

  -- 动画回调缺失或失败的兜底：到点后强制隐藏，避免永久黑屏。
  if pendingHide and Time.unscaledTime >= pendingHideAt then
    pendingHide = false
    pendingHideAt = 0
    fadeToken = fadeToken + 1
    fadeActive = false
    fadeEndsAt = 0
    applyHiddenState()
  end
end

function OnDestroy()
  Anim.clearAll()
  fadeToken = fadeToken + 1
  fadeActive = false
  fadeEndsAt = 0
  pendingHide = false
  pendingHideAt = 0
  fadeOverlay = nil
  runtimeScope = nil
end
