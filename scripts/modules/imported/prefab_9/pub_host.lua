---@id 3d0aca89-b664-455b-a207-b6487ed265af
---@sourceScriptId d6e8c1f9-59f9-4975-bcde-f0e5338bccec
---@referenceName pub_host.lua
-- 酒馆共享入口：点酒时把威士忌杯递给玩家，并把牌桌请求转发给界面
---@displayName 酒馆交互协调

local UnityEngine = CS.UnityEngine
local Time = CS.UnityEngine.Time
local AnimatorType = typeof(CS.UnityEngine.Animator)
local RuntimeScope = require("official.core.runtime_scope")
local Logger = require("official.core.logger")
local logger = Logger.create("pub-host")
local runtimeScope, scopeReason = RuntimeScope.from(self)

local uiScriptId = "ui_pub_card_game.lua"
local uiNodeName = "ui-pub-card-game"
local glassPath = "威士忌酒杯"
local cardNodePath = "PubBuilding/CardTrigger"
local glassHome = UnityEngine.Vector3(-1.2, 1.113, 12.55)
local ready = false
local drinks = 0
local pendingGlass = nil
local pendingActor = nil
local pendingTimer = 0

-- 界面的资源根有独立的 RuntimeScope，宿主按节点路径取回界面脚本
local function getUi()
    if runtimeScope == nil then
        return nil
    end
    local ui = runtimeScope:GetScript(uiScriptId)
    if ui ~= nil then
        return ui
    end
    local uiObject = runtimeScope:GetGameObjectByPath(uiNodeName)
    if uiObject ~= nil then
        local ok, component = pcall(function()
            return uiObject:GetDouyinScript(uiScriptId)
        end)
        if ok and component ~= nil and component.script ~= nil then
            return component.script
        end
    end
    logger:warnOnce("ui-missing", "牌桌界面脚本不可用", tostring(scopeReason))
    return nil
end

local function getGlass()
    if runtimeScope == nil then
        return nil
    end
    return runtimeScope:GetGameObjectByPath(glassPath)
end

local function getCardScript()
    if runtimeScope == nil then
        return nil
    end
    local cardObject = runtimeScope:GetGameObjectByPath(cardNodePath)
    if cardObject == nil then
        return nil
    end
    local ok, component = pcall(function()
        return cardObject:GetDouyinScript("pub_cards.lua")
    end)
    if ok and component ~= nil then
        return component.script
    end
    return nil
end

local function buildGripMatrix(glass)
    if glass == nil then
        return UnityEngine.Matrix4x4.identity
    end
    local anchor = glass.transform:Find("GripAnchor")
    if anchor == nil then
        return UnityEngine.Matrix4x4.identity
    end
    local glassMatrix = UnityEngine.Matrix4x4.TRS(
        glass.transform.position,
        glass.transform.rotation,
        UnityEngine.Vector3.one
    )
    local gripMatrix = UnityEngine.Matrix4x4.TRS(
        anchor.position,
        anchor.rotation,
        UnityEngine.Vector3.one
    )
    return glassMatrix.inverse * gripMatrix
end

-- 把吧台上的酒杯交给本地玩家右手；手上已有杯子时不重复发放
local function serveGlass(actor)
    if actor == nil then
        return false
    end
    local glass = getGlass()
    if glass == nil then
        logger:warnOnce("glass-missing", "威士忌酒杯实例缺失", glassPath)
        return false
    end
    if actor:IsPickup() then
        return false
    end
    glass.transform.position = glassHome
    glass.transform.rotation = UnityEngine.Quaternion.identity
    glass.transform.localScale = UnityEngine.Vector3.one
    local matrix = buildGripMatrix(glass)
    actor:Pickup(glass, CS.HandType.Right, matrix)
    pendingGlass = glass
    pendingActor = actor
    pendingTimer = 0.25
    return true
end

function Start()
    ready = true
end

function IsReady()
    return ready
end

-- 玩家在吧台点酒：累计杯数、把酒杯递到手上，并更新界面提示与醉意反馈。
function RequestDrink(actor)
    drinks = drinks + 1
    local held = actor ~= nil and actor:IsPickup()
    local served = serveGlass(actor)
    local ui = getUi()
    if ui ~= nil then
        if type(ui.ShowToast) == "function" then
            if held then
                ui.ShowToast("你手上已经端着一杯威士忌了")
            elseif served then
                ui.ShowToast("酒保先生欠身致意，递来一杯麦芽威士忌（第 " .. drinks .. " 杯）")
            else
                ui.ShowToast("酒保为你斟上一杯麦芽威士忌（第 " .. drinks .. " 杯）")
            end
        end
        if type(ui.AddDrunk) == "function" then
            ui.AddDrunk(1)
        end
    end
    return drinks
end

-- 打开牌桌小游戏界面。
function OpenCardGame()
    local ui = getUi()
    if ui == nil or type(ui.OpenGame) ~= "function" then
        logger:warnOnce("card-ui", "牌桌界面不可用")
        return false
    end
    ui.OpenGame()
    return true
end

-- 关闭界面，并让仍坐在牌桌前的玩家站起来
function CloseCardGame()
    local ui = getUi()
    if ui ~= nil and type(ui.CloseGame) == "function" then
        ui.CloseGame()
    end
    local card = getCardScript()
    if card ~= nil and type(card.StandUpIfSeated) == "function" then
        card.StandUpIfSeated()
    end
end

-- 若平台的拾取回执没有挂手，补一次挂到右手的兜底，确保酒杯真的在仔仔手上
function Update()
    if pendingTimer <= 0 then
        return
    end
    pendingTimer = pendingTimer - Time.deltaTime
    if pendingTimer > 0 then
        return
    end
    local glass = pendingGlass
    local actor = pendingActor
    pendingGlass = nil
    pendingActor = nil
    if glass == nil or actor == nil then
        return
    end
    local animator = actor.gameObject:GetComponentInChildren(AnimatorType)
    if animator == nil then
        return
    end
    local bone = animator:GetBoneTransform(UnityEngine.HumanBodyBones.RightHand)
    if bone == nil or glass.transform.parent == bone then
        return
    end
    glass.transform:SetParent(bone)
    local palmPosition, palmRotation = actor:CalculatePalmTransform(false)
    glass.transform.position = palmPosition
    glass.transform.rotation = palmRotation
end
