---@id f26cb13c-1269-4039-ad8f-2ecb9d544bbc
---@referenceName reception_housekeeper-dialogue.lua
-- 房东太太接待交互：靠近接待台出现“交谈”按钮，点击后由接待协调打开对话框
---@displayName 房东太太接待
---@start
---@var TalkButtonText:string="交谈"
---@name 交互按钮文字
---@desc 靠近房东太太时显示的按钮文案
---@group 接待
---@end

local Logger = require("official.core.logger")
local RuntimeScope = require("official.core.runtime_scope")

local logger = Logger.create("housekeeper")
local runtimeScope, runtimeScopeReason = RuntimeScope.from(self)

local HOST_SCRIPT_ID = "reception_runtime-host.lua"
local host = nil
local interactorButton = nil

function Start()
  if runtimeScope == nil then
    logger:warnOnce("keeper-no-scope", "接待交互缺少运行作用域", runtimeScopeReason)
    return
  end
  host = runtimeScope:GetRuntimeHostScript(HOST_SCRIPT_ID)
  if host == nil then
    logger:warnOnce("keeper-no-host", "未找到接待协调脚本", HOST_SCRIPT_ID)
  end
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then
    return
  end
  self:EnableInteraction()
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then
    return
  end
  self:DisableInteraction()
end

function OnFocus(handType)
  interactorButton = self:AddInteractorButton()
  if interactorButton == nil then
    return
  end
  local label = interactorButton:GetComponentInChildren(typeof(CS.UnityEngine.UI.Text))
  if label ~= nil then
    label.text = TalkButtonText
  end
end

function OnLostFocus(handType)
  if interactorButton == nil then
    return
  end
  self:RemoveInteractorButton(interactorButton)
  interactorButton = nil
end

function OnInteractorButtonClick(index)
  if index ~= 1 then
    return
  end
  if host == nil then
    return
  end
  if type(host.ShowReceptionDialogue) ~= "function" then
    logger:warnOnce("keeper-no-api", "接待协调脚本缺少 ShowReceptionDialogue")
    return
  end
  host.ShowReceptionDialogue()
end
