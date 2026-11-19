---@id 53900039-5d70-404f-b872-17d6bbec2620
---@sourceScriptId 93d20ac9-a2f7-4ad0-b799-c34a14cca50c
---@referenceName pub_cards.lua
-- 牌桌：靠近显示坐下按钮，确认入座后开始二十一点，离座时收尾
---@displayName 牌桌打牌
---@start
---@var PlayText:string="坐下打一局牌"
---@name 坐下按钮文案
---@desc 玩家靠近牌桌、尚未入座时显示的按钮文字
---@var LeaveText:string="站起来"
---@name 离座按钮文案
---@desc 已经坐在牌桌前时显示的按钮文字
---@end

local UnityEngine = CS.UnityEngine
local Vector3 = UnityEngine.Vector3
local Time = CS.UnityEngine.Time
local TextType = typeof(CS.UnityEngine.UI.Text)
local ColliderType = typeof(CS.UnityEngine.Collider)
local AnimatorType = typeof(CS.UnityEngine.Animator)
local RuntimeScope = require("official.core.runtime_scope")
local Logger = require("official.core.logger")
local logger = Logger.create("pub-cards")
local runtimeScope, scopeReason = RuntimeScope.from(self)

local hostScriptId = "pub_host.lua"
local host = nil
if runtimeScope ~= nil then
    host, _ = runtimeScope:GetRuntimeHostScript(hostScriptId)
end

local interactionButton = nil
local localActor = nil
local localActorId = nil
local hasPassenger = false
local manualSeated = false
local seatRequestTimer = 0
local seatAnchor = nil
local standAnchor = nil

local seatedActors = {}
local savedScale = {}
local savedPosition = {}
local savedRotation = {}
local savedColliderEnabled = {}

local function getHost()
    if host == nil and runtimeScope ~= nil then
        host, _ = runtimeScope:GetRuntimeHostScript(hostScriptId)
    end
    return host
end

local function getLocalActor()
    if localActor ~= nil and localActor.isLocal then
        return localActor
    end
    if localActorId ~= nil then
        local ok, actor = pcall(function()
            return DouyinActorService.GetActorById(localActorId)
        end)
        if ok and actor ~= nil then
            localActor = actor
            return actor
        end
    end
    return localActor
end

local function setButtonText(text)
    if interactionButton == nil then
        return
    end
    local label = interactionButton:GetComponentInChildren(TextType, true)
    if label ~= nil then
        label.gameObject:SetActive(true)
        label.text = text
    end
end

local function updateButtonText()
    if hasPassenger or manualSeated then
        setButtonText(LeaveText)
    else
        setButtonText(PlayText)
    end
end

local function showButton()
    if interactionButton == nil then
        interactionButton = self:AddInteractorButton()
    end
    if interactionButton ~= nil then
        updateButtonText()
    end
end

local function hideButton()
    if interactionButton ~= nil then
        self:RemoveInteractorButton(interactionButton)
        interactionButton = nil
    end
end

local function resolveAnchors()
    seatAnchor = self.transform:Find("SeatAnchor")
    standAnchor = self.transform:Find("StandUpAnchor")
    if seatAnchor == nil then
        logger:warnOnce("seat-anchor", "牌桌座位锚点缺失")
    end
end

local function alignActorToSeat(actor, target)
    if actor == nil or target == nil then
        return
    end
    local trans = actor.gameObject.transform
    if savedScale[actor] == nil then
        savedScale[actor] = trans.localScale
    end
    trans:SetParent(target)
    trans.localPosition = Vector3.zero
    trans.localRotation = UnityEngine.Quaternion.identity

    local parentScale = target.lossyScale
    local original = savedScale[actor] or Vector3.one
    trans.localScale = Vector3(
        original.x / parentScale.x,
        original.y / parentScale.y,
        original.z / parentScale.z
    )

    local animator = actor.gameObject:GetComponentInChildren(AnimatorType)
    if animator == nil then
        return
    end
    local hips = animator:GetBoneTransform(UnityEngine.HumanBodyBones.Hips)
    if hips == nil then
        return
    end
    local hipsPosition = hips.position
    local actorPosition = trans.position
    trans.position = Vector3(
        actorPosition.x - (hipsPosition.x - actorPosition.x),
        actorPosition.y - (hipsPosition.y - actorPosition.y),
        actorPosition.z - (hipsPosition.z - actorPosition.z)
    )
end

local function setActorColliderEnabled(actor, enabled)
    if actor == nil or actor.gameObject == nil then
        return
    end
    local collider = actor.gameObject:GetComponent(ColliderType)
    if collider == nil then
        return
    end
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
    if actor == nil then
        return
    end
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
    end
    savedPosition[actor] = nil
    savedRotation[actor] = nil
end

local function openCardGame()
    local h = getHost()
    if h == nil or type(h.OpenCardGame) ~= "function" then
        logger:warnOnce("host-missing", "酒馆协调脚本不可用", tostring(scopeReason))
        return
    end
    h.OpenCardGame()
end

local function closeCardGame()
    local h = getHost()
    if h ~= nil and type(h.CloseCardGame) == "function" then
        h.CloseCardGame()
    end
end

function Start()
    resolveAnchors()
end

-- 平台确认入座后，对齐到牌桌座位并开始牌局；远端 Actor 也执行对齐
function OnSeatEntered(actor, handType)
    if actor == nil or seatAnchor == nil then
        return
    end
    local trans = actor.gameObject.transform
    savedPosition[actor] = trans.position
    savedRotation[actor] = trans.rotation
    if savedScale[actor] == nil then
        savedScale[actor] = trans.localScale
    end
    alignActorToSeat(actor, seatAnchor)
    seatedActors[actor] = seatAnchor
    setActorColliderEnabled(actor, false)

    if actor.isLocal then
        hasPassenger = true
        manualSeated = false
        seatRequestTimer = 0
        self:EnableInteraction()
        updateButtonText()
        openCardGame()
    end
end

function OnSeatExited(actor)
    if actor == nil then
        return
    end
    seatedActors[actor] = nil
    placeActorAtStandPoint(actor)
    setActorColliderEnabled(actor, true)
    if actor.isLocal then
        hasPassenger = false
        seatRequestTimer = 0
        updateButtonText()
    end
end

function StandUpIfSeated()
    local actor = getLocalActor()
    if actor ~= nil and hasPassenger then
        actor:StandUp(self.gameObject)
    end
    manualSeated = false
    seatRequestTimer = 0
    updateButtonText()
end

function OnActorTriggerEnter(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    localActor = actor
    localActorId = actor.actorID
    self:EnableInteraction()
end

function OnActorTriggerExit(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    if not hasPassenger then
        localActor = nil
        localActorId = nil
        manualSeated = false
        seatRequestTimer = 0
        self:DisableInteraction()
        hideButton()
    end
end

function OnFocus(handType)
    showButton()
end

function OnLostFocus(handType)
    hideButton()
end

function OnInteractorButtonClick(index)
    if index ~= 1 then
        return
    end
    local actor = getLocalActor()
    if actor == nil then
        return
    end

    if hasPassenger then
        actor:StandUp(self.gameObject)
        closeCardGame()
        updateButtonText()
        return
    end
    if manualSeated then
        manualSeated = false
        seatRequestTimer = 0
        closeCardGame()
        updateButtonText()
        return
    end

    if seatAnchor == nil then
        logger:warnOnce("seat-anchor", "牌桌座位锚点缺失")
        return
    end
    if actor:IsSitting() then
        return
    end
    seatRequestTimer = 0.9
    actor:SitDown(self.gameObject)
end

function Update()
    if seatRequestTimer > 0 then
        seatRequestTimer = seatRequestTimer - Time.deltaTime
        if seatRequestTimer <= 0 and not hasPassenger then
            -- 座椅系统未接管时仍允许开始牌局，避免交互卡死
            manualSeated = true
            updateButtonText()
            openCardGame()
        end
    end
end

function LateUpdate()
    for actor, target in pairs(seatedActors) do
        alignActorToSeat(actor, target)
    end
end

function OnDisable()
    hideButton()
end

function OnDestroy()
    hideButton()
    seatedActors = {}
end
