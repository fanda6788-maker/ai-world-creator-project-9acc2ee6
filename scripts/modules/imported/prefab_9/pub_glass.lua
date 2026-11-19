---@id 376d831f-1aa7-4716-926d-1f93bf7aa04e
---@referenceName pub_glass.lua
-- 威士忌酒杯：被酒保递到玩家右手，放下时回到吧台原位
---@displayName 威士忌酒杯

local UnityEngine = CS.UnityEngine
local AnimatorType = typeof(CS.UnityEngine.Animator)

local currentActor = nil
local homeParent = nil
local homePosition = nil
local homeRotation = nil
local homeScale = nil

function Start()
    homeParent = self.transform.parent
    homePosition = self.transform.position
    homeRotation = self.transform.rotation
    homeScale = self.transform.localScale
end

-- 平台确认拾取后，把手杯挂到右手骨并对齐掌心；本端与远端都执行挂手
function OnPickup(actor, handType, pickUpPoint)
    if actor == nil then
        return
    end
    currentActor = actor

    local animator = actor.gameObject:GetComponentInChildren(AnimatorType)
    if animator ~= nil then
        local bone = animator:GetBoneTransform(UnityEngine.HumanBodyBones.RightHand)
        if bone ~= nil then
            self.transform:SetParent(bone)
        end
    end

    local pickupMatrix = CS.UnityEngine.Matrix4x4.identity
    if pickUpPoint ~= nil then
        pickupMatrix = pickUpPoint.inverse
    end
    local palmPosition, palmRotation = actor:CalculatePalmTransform(false)
    local palmMatrix = CS.UnityEngine.Matrix4x4.TRS(
        palmPosition,
        palmRotation,
        CS.UnityEngine.Vector3.one
    )
    local finalMatrix = palmMatrix * pickupMatrix
    self.transform.position = finalMatrix:GetPosition()
    self.transform.rotation = finalMatrix.rotation
end

-- 放下后回到吧台原位，下一杯可以直接再次递给玩家
function OnDrop(actor)
    if actor == nil or actor ~= currentActor then
        return
    end
    self.transform:SetParent(homeParent)
    self.transform.position = homePosition
    self.transform.rotation = homeRotation
    if homeScale ~= nil then
        self.transform.localScale = homeScale
    end
    currentActor = nil
end
