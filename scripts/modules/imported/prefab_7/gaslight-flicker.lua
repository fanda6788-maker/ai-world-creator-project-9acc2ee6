---@id edc1c5ca-1114-49ec-a22f-38244cfe1aca
---@referenceName gaslight-flicker.lua
-- 煤气灯在稳定亮度上做轻微明暗闪烁
---@displayName 煤气灯闪烁
---@start
---@var FlickerAmount:number=0.14
---@name 闪烁幅度
---@desc 灯光强度上下浮动的比例，0 表示稳定
---@var FlickerSpeed:number=1.7
---@name 闪烁速度
---@desc 明暗变化的快慢，数值越大抖动越密
---@end

local LightType = typeof(CS.UnityEngine.Light)
local Mathf = CS.UnityEngine.Mathf
local Time = CS.UnityEngine.Time

local light = nil
local baseIntensity = 1
local seed = 0
-- 灯光初始化可能晚于脚本，先用一小段时间读取稳定亮度作为基准。
local settleTime = 0.8

-- 灯光组件可能在灯罩节点或它的子节点上，找到后缓存基准亮度。
local function resolveLight()
  if light ~= nil then
    return true
  end
  local gameObject = self.gameObject
  if gameObject == nil then
    return false
  end

  local found = gameObject:GetComponent(LightType)
  if found == nil then
    found = gameObject:GetComponentInChildren(LightType)
  end
  if found == nil then
    local parent = self.transform ~= nil and self.transform.parent or nil
    if parent ~= nil then
      found = parent.gameObject:GetComponent(LightType)
    end
  end
  if found == nil then
    return false
  end

  light = found
  if settleTime < 0.3 then
    settleTime = 0.3
  end
  baseIntensity = found.intensity
  local position = self.transform.position
  seed = math.abs(position.x * 0.37 + position.z * 0.61) % 5.0
  return true
end

function Start()
  resolveLight()
end

function Update()
  if light == nil then
    if not resolveLight() then
      return
    end
  end

  if settleTime > 0 then
    settleTime = settleTime - Time.deltaTime
    baseIntensity = light.intensity
    return
  end

  local speed = FlickerSpeed or 1.7
  if speed <= 0 then
    speed = 1.7
  end
  local amount = FlickerAmount or 0.14
  if amount < 0 then
    amount = 0
  end
  if amount > 1 then
    amount = 1
  end

  local t = Time.time * speed
  local slow = Mathf.PerlinNoise(seed + 0.5, t)
  local fast = Mathf.PerlinNoise(seed + 7.3, t * 2.4)
  local wander = (slow - 0.5) * 0.7 + (fast - 0.5) * 0.3

  -- 偶发的轻微下沉，模拟煤气压力波动，而不是规律频闪。
  local gate = Mathf.PerlinNoise(seed + 21.7, t * 0.22)
  local dip = 1.0
  if gate > 0.62 then
    dip = 1.0 - (gate - 0.62) / 0.38 * 0.5
  end

  local factor = (1.0 + wander * 2.0 * amount) * dip
  if factor < 0.2 then
    factor = 0.2
  end
  light.intensity = baseIntensity * factor
end

function OnDisable()
  if light ~= nil then
    light.intensity = baseIntensity
  end
end
