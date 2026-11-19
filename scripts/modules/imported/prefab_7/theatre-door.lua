---@id 7b516a5d-cb8c-4d37-982b-d99ac5553a33
---@referenceName theatre-door.lua
-- 剧院大门：玩家走近门廊时双门叶向内缓缓开启，离开后回到常开角度
---@displayName 剧院大门开合
---@start
---@var OpenAngle:number=100
---@name 开门角度
---@desc 玩家靠近时门叶绕铰链向内旋转的角度（度）
---@var RestAngle:number=78
---@name 常开角度
---@desc 无人时门叶保持的开启角度（度），保持门厅暖光外透并留出通行宽度
---@var SwingSpeed:number=150
---@name 开合速度
---@desc 门叶每秒旋转的角度
---@var CloseDelay:number=1.5
---@name 关门延迟
---@desc 玩家离开门口后等待多久回到常开角度（秒）
---@end

local Quaternion = CS.UnityEngine.Quaternion
local Time = CS.UnityEngine.Time
local RuntimeScope = require("official.core.runtime_scope")

local runtimeScope = RuntimeScope.from(self)

local LEFT_PATH = "Facade/Entrance/Pivot_Door_L"
local RIGHT_PATH = "Facade/Entrance/Pivot_Door_R"

local leftPivot = nil
local rightPivot = nil
local leftBase = nil
local rightBase = nil
local openAngle = 100
local restAngle = 78
local currentAngle = 78
local targetAngle = 78
local closeTimer = 0
local insideCount = 0

-- 门叶节点在资源内部，按当前实例根路径查找；就绪后缓存初始局部旋转。
local function resolvePivots()
  if runtimeScope == nil then
    return false
  end
  if leftPivot == nil then
    leftPivot = runtimeScope:GetTransformByPath(LEFT_PATH)
  end
  if rightPivot == nil then
    rightPivot = runtimeScope:GetTransformByPath(RIGHT_PATH)
  end
  if leftPivot == nil or rightPivot == nil then
    return false
  end
  if leftBase == nil then
    leftBase = leftPivot.localRotation
    rightBase = rightPivot.localRotation
  end
  return true
end

local function applyAngle(angle)
  if leftPivot == nil or rightPivot == nil then
    return
  end
  -- 左叶铰链在 +X、叶片朝 -X，绕 Y 负角向室内（-Z）摆开；右叶相反。
  leftPivot.localRotation = leftBase * Quaternion.Euler(0, -angle, 0)
  rightPivot.localRotation = rightBase * Quaternion.Euler(0, angle, 0)
end

function Start()
  if OpenAngle ~= nil then
    openAngle = OpenAngle
  end
  if RestAngle ~= nil then
    restAngle = RestAngle
  end
  currentAngle = restAngle
  targetAngle = restAngle
  if resolvePivots() then
    applyAngle(restAngle)
  end
end

function OnActorTriggerEnter(actor)
  insideCount = insideCount + 1
  closeTimer = 0
  targetAngle = openAngle
end

function OnActorTriggerExit(actor)
  insideCount = insideCount - 1
  if insideCount < 0 then
    insideCount = 0
  end
  if insideCount == 0 then
    closeTimer = CloseDelay or 1.5
  end
end

function Update()
  if leftPivot == nil or rightPivot == nil then
    if not resolvePivots() then
      return
    end
  end

  if closeTimer > 0 then
    closeTimer = closeTimer - Time.deltaTime
    if closeTimer <= 0 then
      closeTimer = 0
      targetAngle = restAngle
    end
  end

  if math.abs(currentAngle - targetAngle) > 0.05 then
    local speed = SwingSpeed
    if speed == nil then
      speed = 150
    end
    local step = speed * Time.deltaTime
    if step <= 0 then
      step = 150 * Time.deltaTime
    end
    if currentAngle < targetAngle then
      currentAngle = math.min(currentAngle + step, targetAngle)
    else
      currentAngle = math.max(currentAngle - step, targetAngle)
    end
    applyAngle(currentAngle)
  end
end
