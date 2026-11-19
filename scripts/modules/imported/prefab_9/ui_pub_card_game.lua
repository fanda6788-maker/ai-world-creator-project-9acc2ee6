---@id 6bde846a-d64b-4619-bfb4-f8864fb66e57
---@sourceScriptId 7fc8300d-4af5-47f6-b179-0d30dd1bb047
---@referenceName ui_pub_card_game.lua
-- 酒馆牌桌的二十一点小游戏界面：发牌、要牌、停牌、再来一局、离开，以及点酒提示与酒意反馈
---@displayName 酒馆牌桌界面

local UnityEngine = CS.UnityEngine
local Color = CS.UnityEngine.Color
local Time = CS.UnityEngine.Time
local ButtonType = typeof(CS.UnityEngine.UI.Button)
local TextType = typeof(CS.UnityEngine.UI.Text)
local RuntimeScope = require("official.core.runtime_scope")
local Logger = require("official.core.logger")
local logger = Logger.create("pub-card-ui")
local runtimeScope, scopeReason = RuntimeScope.from(self)

local hostScriptId = "pub_host.lua"
local host = nil
if runtimeScope ~= nil then
    host, _ = runtimeScope:GetRuntimeHostScript(hostScriptId)
end

local panelPath = "cardGamePanel"
local statusPath = "cardGamePanel/gameStatus"
local uiComponents = {}
local listeners = {}

local function getComponent(nodePath, componentType)
    if runtimeScope == nil then
        return nil
    end
    local cached = uiComponents[nodePath]
    if cached ~= nil and cached[componentType] ~= nil then
        return cached[componentType]
    end
    local gameObject = runtimeScope:GetGameObjectByPath(nodePath)
    local component = gameObject ~= nil and gameObject:GetComponent(componentType) or nil
    if component == nil then
        logger:warnOnce("missing-" .. nodePath, "界面控件缺失", nodePath, tostring(scopeReason))
    else
        uiComponents[nodePath] = cached or {}
        uiComponents[nodePath][componentType] = component
    end
    return component
end

local function setText(nodePath, value)
    local text = getComponent(nodePath, TextType)
    if text ~= nil then
        text.text = tostring(value)
    end
end

local function setActive(nodePath, active)
    if runtimeScope == nil then
        return
    end
    local gameObject = runtimeScope:GetGameObjectByPath(nodePath)
    if gameObject ~= nil then
        gameObject:SetActive(active)
    end
end

local function bindButton(nodePath, handler)
    local button = getComponent(nodePath, ButtonType)
    if button == nil then
        return
    end
    button.onClick:AddListener(handler)
    listeners[#listeners + 1] = { button = button, handler = handler }
end

local function setActionButtonsEnabled(enabled)
    local hit = getComponent("cardGamePanel/hitButton", ButtonType)
    local stand = getComponent("cardGamePanel/standButton", ButtonType)
    if hit ~= nil then hit.interactable = enabled end
    if stand ~= nil then stand.interactable = enabled end
end

-- ---------------------------------------------------------------- card game

local SUITS = { "♠", "♥", "♦", "♣" }
local RANKS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
local deck = {}
local playerCards = {}
local dealerCards = {}
local roundOver = true
local dealerHidden = true
local isOpen = false
local toastTimer = 0
local drunkLevel = 0
local drunkTimer = 0
local pulse = 0

local function buildDeck()
    deck = {}
    for _, suit in ipairs(SUITS) do
        for _, rank in ipairs(RANKS) do
            deck[#deck + 1] = { rank = rank, suit = suit }
        end
    end
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end

local function drawCard()
    if #deck == 0 then
        buildDeck()
    end
    return table.remove(deck)
end

local function cardValue(card)
    if card.rank == "A" then
        return 11
    end
    if card.rank == "J" or card.rank == "Q" or card.rank == "K" then
        return 10
    end
    return tonumber(card.rank)
end

local function scoreOf(cards)
    local total = 0
    local aces = 0
    for _, card in ipairs(cards) do
        total = total + cardValue(card)
        if card.rank == "A" then
            aces = aces + 1
        end
    end
    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end
    return total
end

local function renderCards()
    for i = 1, 4 do
        local visible = i <= #dealerCards and (not dealerHidden or i == 1)
        setActive("cardGamePanel/dealerCard" .. i, visible)
        if visible and dealerCards[i] ~= nil then
            setText("cardGamePanel/dealerCard" .. i .. "/dealerCard" .. i .. "Value",
                dealerCards[i].rank .. dealerCards[i].suit)
        end
    end
    for i = 1, 5 do
        local visible = i <= #playerCards
        setActive("cardGamePanel/playerCard" .. i, visible)
        if visible and playerCards[i] ~= nil then
            setText("cardGamePanel/playerCard" .. i .. "/playerCard" .. i .. "Value",
                playerCards[i].rank .. playerCards[i].suit)
        end
    end

    if dealerHidden then
        local shown = #dealerCards > 0 and scoreOf({ dealerCards[1] }) or 0
        setText("cardGamePanel/dealerTotal", "庄家点数：" .. shown .. " + ?")
    else
        setText("cardGamePanel/dealerTotal", "庄家点数：" .. scoreOf(dealerCards))
    end
    setText("cardGamePanel/playerTotal", "你的点数：" .. scoreOf(playerCards))
end

local function finishRound(message)
    roundOver = true
    dealerHidden = false
    renderCards()
    setText(statusPath, message)
    setActionButtonsEnabled(false)
end

local function startRound()
    buildDeck()
    playerCards = { drawCard(), drawCard() }
    dealerCards = { drawCard(), drawCard() }
    roundOver = false
    dealerHidden = true
    setActionButtonsEnabled(true)
    setText(statusPath, "点击「要牌」继续拿牌，或「停牌」比点数。")
    renderCards()
end

local function hit()
    if roundOver then
        return
    end
    if #playerCards >= 5 then
        setText(statusPath, "手中已有五张牌，请停牌比点数。")
        return
    end
    playerCards[#playerCards + 1] = drawCard()
    renderCards()
    if scoreOf(playerCards) > 21 then
        finishRound("你爆牌了，庄家赢。点「再来一局」重开。")
    else
        setText(statusPath, "你要了一张牌。")
    end
end

local function stand()
    if roundOver then
        return
    end
    dealerHidden = false
    while scoreOf(dealerCards) < 17 and #dealerCards < 6 do
        dealerCards[#dealerCards + 1] = drawCard()
    end
    renderCards()
    local playerScore = scoreOf(playerCards)
    local dealerScore = scoreOf(dealerCards)
    if dealerScore > 21 then
        finishRound("庄家爆牌，你赢了这一局。")
    elseif dealerScore > playerScore then
        finishRound("庄家 " .. dealerScore .. " 点，你 " .. playerScore .. " 点，庄家赢。")
    elseif dealerScore < playerScore then
        finishRound("你 " .. playerScore .. " 点，庄家 " .. dealerScore .. " 点，你赢了这一局。")
    else
        finishRound("双方都是 " .. playerScore .. " 点，平局。")
    end
end

-- ---------------------------------------------------------------- public

function OpenGame()
    if isOpen then
        return
    end
    isOpen = true
    setActive(panelPath, true)
    startRound()
end

function CloseGame()
    if not isOpen then
        return
    end
    isOpen = false
    setActive(panelPath, false)
end

function ShowToast(message)
    setText("toastRoot/toastLabel", message)
    setActive("toastRoot", true)
    toastTimer = 3.2
end

function AddDrunk(amount)
    drunkLevel = math.min(4, drunkLevel + (amount or 1))
    drunkTimer = 10
    setActive("drunkRoot", true)
end

local function updateDrunkLabel()
    local names = { "微醺", "上头", "脚步发飘", "天旋地转" }
    local index = math.max(1, math.min(4, drunkLevel))
    setText("drunkRoot/drunkLabel", "酒意：" .. names[index])
    local label = getComponent("drunkRoot/drunkLabel", TextType)
    if label ~= nil then
        label.color = Color(0.95, 0.66 + 0.12 * math.sin(pulse), 0.36, 1)
    end
end

function Start()
    if runtimeScope == nil then
        logger:warnOnce("scope", "界面作用域不可用", tostring(scopeReason))
        return
    end

    bindButton("cardGamePanel/hitButton", function()
        hit()
    end)
    bindButton("cardGamePanel/standButton", function()
        stand()
    end)
    bindButton("cardGamePanel/againButton", function()
        if isOpen then
            startRound()
        end
    end)
    bindButton("cardGamePanel/leaveButton", function()
        if host == nil and runtimeScope ~= nil then
            host, _ = runtimeScope:GetRuntimeHostScript(hostScriptId)
        end
        if host ~= nil and type(host.CloseCardGame) == "function" then
            host.CloseCardGame()
        else
            CloseGame()
        end
    end)

    setActive(panelPath, false)
    setActive("toastRoot", false)
    setActive("drunkRoot", false)
    updateDrunkLabel()
end

function Update()
    local deltaTime = Time.deltaTime

    if toastTimer > 0 then
        toastTimer = toastTimer - deltaTime
        if toastTimer <= 0 then
            setActive("toastRoot", false)
        end
    end

    if drunkLevel > 0 then
        pulse = pulse + deltaTime * 3
        drunkTimer = drunkTimer - deltaTime
        if drunkTimer <= 0 then
            drunkLevel = math.max(0, drunkLevel - 1)
            drunkTimer = 7
            if drunkLevel == 0 then
                setActive("drunkRoot", false)
            end
        end
        updateDrunkLabel()
    end
end

function OnDestroy()
    for _, item in ipairs(listeners) do
        if item.button ~= nil and item.handler ~= nil then
            item.button.onClick:RemoveListener(item.handler)
        end
    end
    listeners = {}
    uiComponents = {}
end
