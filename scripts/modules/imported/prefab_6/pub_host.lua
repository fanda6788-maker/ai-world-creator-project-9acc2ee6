---@id d6e8c1f9-59f9-4975-bcde-f0e5338bccec
---@referenceName pub_host.lua
-- 酒馆共享入口：点酒与牌桌请求转发给牌桌界面脚本
---@displayName 酒馆交互协调

local RuntimeScope = require("official.core.runtime_scope")
local Logger = require("official.core.logger")
local logger = Logger.create("pub-host")
local runtimeScope, scopeReason = RuntimeScope.from(self)

local uiScriptId = "ui_pub_card_game.lua"
local ready = false
local drinks = 0

local function getUi()
    if runtimeScope == nil then
        return nil
    end
    local ui = runtimeScope:GetScript(uiScriptId)
    if ui == nil then
        logger:warnOnce("ui-missing", "牌桌界面脚本不可用", scopeReason)
    end
    return ui
end

function Start()
    ready = true
end

function IsReady()
    return ready
end

-- 玩家在吧台点酒：累计杯数，并让界面提示与醉意反馈更新。
function RequestDrink()
    drinks = drinks + 1
    local ui = getUi()
    if ui ~= nil then
        if type(ui.ShowToast) == "function" then
            ui.ShowToast("酒保递来一杯麦芽威士忌（第 " .. drinks .. " 杯）")
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

function CloseCardGame()
    local ui = getUi()
    if ui ~= nil and type(ui.CloseGame) == "function" then
        ui.CloseGame()
    end
end
