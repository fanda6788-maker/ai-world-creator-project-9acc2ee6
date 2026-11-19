---@id 7d852a75-c257-4e5e-857b-99d30bc80ca1
---@sourceScriptId d2ef46f7-3088-4ba5-9090-672eff5a52a9
---@referenceName reception_runtime-host.lua
-- 接待协调：把房东太太的接待请求转给对话框界面，统一维护接待台词
---@displayName 接待协调
---@start
---@var SpeakerName:string="哈德森太太"
---@name 房管姓名
---@desc 对话框姓名牌显示的称呼
---@var DialogueLines:List<string>={"哦，是来看房的吧？快进来，外头凉。这栋楼里住过记者、医生，还有一位总把琴拉跑调的小姐。","我是哈德森太太，这里的房客都归我照看。早饭七点，晚饭六点，茶随时都有——只要你别把炭火弄灭。","楼上右手边那间刚收拾干净，床单是新换的，窗子正对着街。要住的话跟我说一声，钥匙就挂在这块板子上。","规矩也不多：夜里十一点前回来，别在楼梯上跑；有信我替你收着。你要是愿意，今晚就能住下。"}
---@name 接待台词
---@desc 点击交谈后按顺序逐句显示的台词
---@group 接待
---@end

local Logger = require("official.core.logger")
local RuntimeScope = require("official.core.runtime_scope")

local logger = Logger.create("reception-host")
local runtimeScope, runtimeScopeReason = RuntimeScope.from(self)

local UI_NODE_NAME = "ui-dialogue"
local UI_SCRIPT_ID = "ui_dialogue-ui.lua"
local uiScript = nil
local hasRoomKey = false

local KEY_DIALOGUE_LINES = {
  "楼上右手边的客房已经收拾妥当。这里是十二号房钥匙，请收好。",
  "上楼后沿走廊走到尽头，门牌下有黄铜锁孔。靠近房门即可使用钥匙。",
  "我已经把房间里的火炉和床铺检查过了，今晚可以安心住下。",
  "若要出门，钥匙不必交回；回来时仍能直接开门。",
}

local LOCKED_DOOR_LINES = {
  "门锁着。先到一楼接待台向哈德森太太领取十二号房钥匙。",
}

local UNLOCKED_DOOR_LINES = {
  "黄铜钥匙顺利转动，十二号客房已经解锁。",
}

-- 对话框是独立的 Runtime UI 资源，不在 Host 作用域成员内，
-- 需先按节点路径找到 UI 实例根，再取绑定在该实例上的脚本表。
local function resolveUi()
  if uiScript ~= nil then
    return uiScript
  end
  if runtimeScope == nil then
    logger:warnOnce("host-no-scope", "接待协调缺少运行作用域", runtimeScopeReason)
    return nil
  end
  local uiObject, uiReason = runtimeScope:GetGameObjectByPath(UI_NODE_NAME)
  if uiObject == nil then
    logger:warnOnce("host-no-ui-node", "未找到对话框界面节点", UI_NODE_NAME, "reason=" .. tostring(uiReason))
    return nil
  end
  local ok, component = pcall(function()
    return uiObject:GetDouyinScript(UI_SCRIPT_ID)
  end)
  if not ok or component == nil or component.script == nil then
    logger:warnOnce("host-no-ui", "未找到对话框脚本", UI_SCRIPT_ID)
    return nil
  end
  local candidate = component.script
  if type(candidate.ShowDialogue) ~= "function" then
    logger:warnOnce("host-ui-api", "对话框脚本缺少 ShowDialogue", UI_SCRIPT_ID)
    return nil
  end
  uiScript = candidate
  return uiScript
end

-- List<string> 参数在运行时是 C# List（userdata），不是 Lua 表；
-- 统一转成 1 起始的 Lua 数组，供界面脚本按 #lines 与 lines[i] 使用。
local function normalizeLines(value)
  if value == nil then
    return nil
  end
  if type(value) == "table" then
    local out = {}
    for index = 1, #value do
      local line = value[index]
      if line == nil then
        return nil
      end
      out[index] = tostring(line)
    end
    if #out == 0 then
      return nil
    end
    return out
  end
  local countOk, count = pcall(function()
    return value.Count
  end)
  if not countOk or type(count) ~= "number" or count <= 0 then
    return nil
  end
  local out = {}
  for index = 0, count - 1 do
    local itemOk, line = pcall(function()
      return value[index]
    end)
    if not itemOk or line == nil then
      return nil
    end
    out[#out + 1] = tostring(line)
  end
  return out
end

function ShowReceptionDialogue()
  local ui = resolveUi()
  if ui == nil or type(ui.ShowDialogue) ~= "function" then
    return false
  end
  local content = nil
  if not hasRoomKey then
    hasRoomKey = true
    content = KEY_DIALOGUE_LINES
  else
    content = normalizeLines(DialogueLines)
  end
  if content == nil then
    logger:warnOnce("host-no-lines", "接待台词不可用", "DialogueLines 未配置或是空列表")
    return false
  end
  return ui.ShowDialogue(SpeakerName, content)
end

function HasRoomKey()
  return hasRoomKey
end

function ShowRoomDoorMessage(unlocked)
  local ui = resolveUi()
  if ui == nil or type(ui.ShowDialogue) ~= "function" then
    return false
  end
  if unlocked then
    return ui.ShowDialogue("十二号客房", UNLOCKED_DOOR_LINES)
  end
  return ui.ShowDialogue("十二号客房", LOCKED_DOOR_LINES)
end

function CloseReceptionDialogue()
  local ui = resolveUi()
  if ui == nil or type(ui.CloseDialogue) ~= "function" then
    return false
  end
  ui.CloseDialogue()
  return true
end
