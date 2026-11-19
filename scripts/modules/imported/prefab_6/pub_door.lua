---@id 5e0a5c6e-8f74-4d9a-8da1-6d5787340aa8
---@referenceName pub_door.lua
-- 玩家靠近转角入口时自动推开双开门与门厅内门
---@displayName 酒馆推门

local UnityEngine = CS.UnityEngine
local Time = CS.UnityEngine.Time
local RuntimeScope = require("official.core.runtime_scope")
local Logger = require("official.core.logger")
local logger = Logger.create("pub-door")
local runtimeScope, scopeReason = RuntimeScope.from(self)

local doors = {}
local doorSpecs = {
    { path = "Entrance/DoorPivot", openDeg = -100 },
    { path = "Entrance/DoorRightPivot", openDeg = 100 },
    { path = "InteriorShell/Vestibule/InnerDoorPivot", openDeg = 100 },
}
local openSpeed = 1.8 -- 每秒完成 1.8 个开合进度
local progress = 0
local target = 0

local function applyProgress()
    for _, door in ipairs(doors) do
        door.transform.localEulerAngles = UnityEngine.Vector3(0, door.openDeg * progress, 0)
    end
end

function Start()
    if runtimeScope == nil then
        logger:warnOnce("scope", "资源根不可用", scopeReason)
        return
    end
    for _, spec in ipairs(doorSpecs) do
        local doorTransform = runtimeScope:GetTransformByPath(spec.path)
        if doorTransform ~= nil then
            doors[#doors + 1] = { transform = doorTransform, openDeg = spec.openDeg }
        else
            logger:warnOnce("door-" .. spec.path, "门轴节点缺失", spec.path)
        end
    end
    applyProgress()
end

function OnActorTriggerEnter(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    target = 1
end

function OnActorTriggerExit(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    target = 0
end

function Update()
    if progress == target then
        return
    end
    local step = Time.deltaTime * openSpeed
    if progress < target then
        progress = math.min(target, progress + step)
    else
        progress = math.max(target, progress - step)
    end
    applyProgress()
end
