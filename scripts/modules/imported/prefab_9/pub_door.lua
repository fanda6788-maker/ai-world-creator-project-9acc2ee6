---@id 356ade08-35cf-4251-a564-bc35d09120ad
---@sourceScriptId 5e0a5c6e-8f74-4d9a-8da1-6d5787340aa8
---@referenceName pub_door.lua
-- 酒馆入口：门外靠近显示「进门」，门内靠近显示「离开」，点击后传送并带动门扇
---@displayName 酒馆进门交互
---@start
---@var InsideText:string="进门"
---@name 门外按钮文案
---@desc 玩家站在门外靠近大门时显示的按钮文字
---@var OutsideText:string="离开"
---@name 门内按钮文案
---@desc 玩家已进入酒馆、靠近大门内侧时显示的按钮文字
---@end

local UnityEngine = CS.UnityEngine
local Vector3 = UnityEngine.Vector3
local Time = CS.UnityEngine.Time
local TextType = typeof(CS.UnityEngine.UI.Text)
local RuntimeScope = require("official.core.runtime_scope")
local Logger = require("official.core.logger")
local logger = Logger.create("pub-door")
local runtimeScope, scopeReason = RuntimeScope.from(self)

local doorSpecs = {
    { path = "Entrance/DoorPivot", openDeg = -100 },
    { path = "Entrance/DoorRightPivot", openDeg = 100 },
    { path = "InteriorShell/Vestibule/InnerDoorPivot", openDeg = 100 },
}
local doors = {}

-- 由真实门轴与内门位置推导门洞中心、朝内/朝外方向，避免依赖模型的局部镜像坐标
local doorMid = nil
local inward = nil
local outward = nil
local innerDoor = nil
local faceInward = nil

local openSpeed = 3.2
local progress = 0
local target = 0
local closeTimer = 0
local localActor = nil
local interactionButton = nil
local lastInside = nil

local function applyProgress()
    for i = 1, #doors do
        local door = doors[i]
        if door ~= nil and door.transform ~= nil then
            door.transform.localEulerAngles = UnityEngine.Vector3(0, door.openDeg * progress, 0)
        end
    end
end

local function setupAnchors()
    local left = runtimeScope:GetTransformByPath("Entrance/DoorPivot")
    local right = runtimeScope:GetTransformByPath("Entrance/DoorRightPivot")
    innerDoor = runtimeScope:GetTransformByPath("InteriorShell/Vestibule/InnerDoorPivot")
    if left == nil or right == nil or innerDoor == nil then
        logger:warnOnce("anchors", "门轴或门厅内门节点缺失")
        return false
    end
    local lp = left.position
    local rp = right.position
    doorMid = Vector3((lp.x + rp.x) * 0.5, lp.y, (lp.z + rp.z) * 0.5)
    local lineX = rp.x - lp.x
    local lineZ = rp.z - lp.z
    local lineLength = math.sqrt(lineX * lineX + lineZ * lineZ)
    if lineLength < 0.001 then
        logger:warnOnce("anchors-length", "门轴间距过小，无法确定门洞方向")
        return false
    end
    -- 门轴连线垂直于门洞法线；用法线中朝向门厅内门的一侧作为“室内”
    local nx = -lineZ / lineLength
    local nz = lineX / lineLength
    local ip = innerDoor.position
    local cx = ip.x - doorMid.x
    local cz = ip.z - doorMid.z
    if nx * cx + nz * cz < 0 then
        nx = -nx
        nz = -nz
    end
    inward = Vector3(nx, 0, nz)
    outward = Vector3(-nx, 0, -nz)
    faceInward = UnityEngine.Quaternion.LookRotation(inward, Vector3.up)
    return true
end

local function isInsideBuilding(actor)
    if doorMid == nil or inward == nil or actor == nil then
        return false
    end
    local p = actor.position
    local dx = p.x - doorMid.x
    local dz = p.z - doorMid.z
    return (dx * inward.x + dz * inward.z) > 0
end

local function setButtonLabel(text)
    if interactionButton == nil then
        return
    end
    local label = interactionButton:GetComponentInChildren(TextType, true)
    if label ~= nil then
        label.gameObject:SetActive(true)
        label.text = text
    end
end

local function refreshLabel(force)
    if localActor == nil then
        return
    end
    local inside = isInsideBuilding(localActor)
    if force or inside ~= lastInside then
        lastInside = inside
        setButtonLabel(inside and OutsideText or InsideText)
    end
end

local function showButton()
    if interactionButton == nil then
        interactionButton = self:AddInteractorButton()
    end
    if interactionButton ~= nil then
        refreshLabel(true)
    end
end

local function hideButton()
    if interactionButton ~= nil then
        self:RemoveInteractorButton(interactionButton)
        interactionButton = nil
    end
    lastInside = nil
end

local function teleportActor(actor, destination, rotation)
    if destination == nil or rotation == nil then
        return false
    end
    actor:Teleport(destination, rotation)
    return true
end

function Start()
    if runtimeScope == nil then
        logger:warnOnce("scope", "资源作用域不可用", tostring(scopeReason))
        return
    end
    for i = 1, #doorSpecs do
        local spec = doorSpecs[i]
        local transform = runtimeScope:GetTransformByPath(spec.path)
        if transform ~= nil then
            doors[#doors + 1] = { transform = transform, openDeg = spec.openDeg }
        else
            logger:warnOnce("door-" .. spec.path, "门轴节点缺失", spec.path)
        end
    end
    setupAnchors()
    applyProgress()
end

function OnActorTriggerEnter(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    localActor = actor
    closeTimer = 0
    target = 1
    self:EnableInteraction()
    refreshLabel(true)
end

function OnActorTriggerExit(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    localActor = nil
    closeTimer = 1.2
    self:DisableInteraction()
    hideButton()
end

function OnFocus(handType)
    showButton()
end

function OnLostFocus(handType)
    hideButton()
end

function OnInteractorButtonClick(index)
    if index ~= 1 or localActor == nil or doorMid == nil then
        return
    end
    if isInsideBuilding(localActor) then
        local destination = Vector3(
            doorMid.x + outward.x * 1.8,
            doorMid.y + 0.12,
            doorMid.z + outward.z * 1.8
        )
        teleportActor(localActor, destination, faceInward)
    else
        local ip = innerDoor.position
        local destination = Vector3(
            ip.x + inward.x * 0.55,
            doorMid.y + 0.12,
            ip.z + inward.z * 0.55
        )
        teleportActor(localActor, destination, faceInward)
    end
    target = 1
    closeTimer = 1.2
    refreshLabel(true)
end

function Update()
    if localActor ~= nil then
        refreshLabel(false)
    end
    if closeTimer > 0 then
        closeTimer = closeTimer - Time.deltaTime
        if closeTimer <= 0 and localActor == nil then
            target = 0
        end
    end
    if progress ~= target then
        local step = Time.deltaTime * openSpeed
        if progress < target then
            progress = math.min(target, progress + step)
        else
            progress = math.max(target, progress - step)
        end
        applyProgress()
    end
end

function OnDisable()
    hideButton()
    localActor = nil
end

function OnDestroy()
    hideButton()
    localActor = nil
end
