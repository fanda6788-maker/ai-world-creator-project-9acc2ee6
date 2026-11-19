---@id d006b8a8-ccae-4992-93fa-f43012152e27
---@referenceName agency-anchor-registrar.lua
-- 把外壳/内部实例里的传送锚点与安全落点登记给传送 Host
---@displayName 事务所锚点登记
---@start
---@var Role:string="exterior"
---@name 实例角色
---@desc exterior 建筑外壳；interior 内部空间
---@enum exterior=建筑外壳,interior=内部空间
---@end

local Logger = require("official.core.logger")
local RuntimeScope = require("official.core.runtime_scope")

local logger = Logger.create("agency-anchor-registrar")
local runtimeScope, runtimeScopeReason = RuntimeScope.from(self)

local registered = false

local function tryGetTransform(nodePath)
  if runtimeScope == nil then
    return nil
  end
  local transform, reason = runtimeScope:GetTransformByPath(nodePath)
  if transform == nil then
    logger:warnOnce("anchor-missing-" .. nodePath, "传送锚点节点缺失", nodePath,
      tostring(reason))
  end
  return transform
end

local function registerAnchors()
  if registered or runtimeScope == nil then
    return
  end
  local host = runtimeScope:GetRuntimeHostScript("agency-portal-host.lua")
  if host == nil or type(host.RegisterAnchors) ~= "function" then
    logger:warnOnce("host-unavailable", "传送 Host 不可用，锚点未登记")
    return
  end

  local anchors = {}
  if Role == "interior" then
    anchors.Transit = tryGetTransform("事务所内部落点")
    anchors.Floor2 = tryGetTransform("事务所二层安全落点")
    anchors.Floor3 = tryGetTransform("事务所三层安全落点")
  else
    anchors.Transit = tryGetTransform("事务所外部落点")
  end
  if anchors.Transit == nil then
    logger:warnOnce("transit-anchor-missing", "本实例缺少主传送锚点", tostring(Role))
    return
  end
  registered = host.RegisterAnchors(Role, anchors) == true
end

function Start()
  if runtimeScope == nil then
    logger:warnOnce("scope-unavailable", "锚点登记脚本无法取得资源作用域",
      tostring(runtimeScopeReason))
    return
  end
  registerAnchors()
end

function OnDestroy()
  registered = false
end
