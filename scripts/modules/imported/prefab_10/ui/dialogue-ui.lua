---@id 75ca1a11-8187-41f5-9c6f-bc4714e646b3
---@sourceScriptId 5f1f8808-6f12-4e93-8d08-d7cecbd6d775
---@referenceName ui_dialogue-ui.lua
-- 接待对话框：默认隐藏，按台词逐句显示并在最后一句后关闭
---@displayName 接待对话框

local ButtonType = typeof(CS.UnityEngine.UI.Button)
local TextType = typeof(CS.UnityEngine.UI.Text)
local Logger = require("official.core.logger")
local RuntimeScope = require("official.core.runtime_scope")

local logger = Logger.create("dialogue-ui")
local runtimeScope, runtimeScopeReason = RuntimeScope.from(self)

local PANEL_PATH = "dialogueRoot"
local NAME_PATH = "dialogueRoot/nameLabel"
local TEXT_PATH = "dialogueRoot/textLabel"
local BUTTON_PATH = "dialogueRoot/nextButton"
local BUTTON_LABEL_PATH = "dialogueRoot/nextButton/nextButtonLabel"

local panelObject = nil
local nameComponent = nil
local textComponent = nil
local nextButton = nil
local buttonLabel = nil
local buttonHandler = nil
local lines = nil
local lineIndex = 0
local isOpen = false

local function getComponent(path, componentType, label)
  if runtimeScope == nil then
    return nil
  end
  local node, reason = runtimeScope:GetGameObjectByPath(path)
  if node == nil then
    logger:warnOnce("ui-missing-" .. label, "对话框控件缺失", path, "reason=" .. tostring(reason))
    return nil
  end
  return node:GetComponent(componentType)
end

local function updateButtonLabel()
  if buttonLabel == nil or lines == nil then
    return
  end
  if lineIndex >= #lines then
    buttonLabel.text = "结束"
  else
    buttonLabel.text = "继续"
  end
end

function ShowDialogue(speaker, content)
  if type(content) ~= "table" or #content == 0 then
    return false
  end
  if panelObject == nil or textComponent == nil then
    return false
  end
  lines = content
  lineIndex = 1
  if nameComponent ~= nil then
    nameComponent.text = tostring(speaker or "")
  end
  textComponent.text = tostring(lines[1])
  updateButtonLabel()
  if not isOpen then
    panelObject:SetActive(true)
  end
  isOpen = true
  return true
end

function AdvanceDialogue()
  if not isOpen or lines == nil then
    return false
  end
  lineIndex = lineIndex + 1
  if lineIndex > #lines then
    CloseDialogue()
    return true
  end
  if textComponent ~= nil then
    textComponent.text = tostring(lines[lineIndex])
  end
  updateButtonLabel()
  return true
end

function CloseDialogue()
  if not isOpen then
    return true
  end
  isOpen = false
  lineIndex = 0
  lines = nil
  if panelObject ~= nil then
    panelObject:SetActive(false)
  end
  return true
end

function IsDialogueOpen()
  return isOpen
end

function Start()
  if runtimeScope == nil then
    logger:warnOnce("dialogue-no-scope", "对话框缺少运行作用域", runtimeScopeReason)
    return
  end
  panelObject = runtimeScope:GetGameObjectByPath(PANEL_PATH)
  nameComponent = getComponent(NAME_PATH, TextType, "name")
  textComponent = getComponent(TEXT_PATH, TextType, "text")
  buttonLabel = getComponent(BUTTON_LABEL_PATH, TextType, "button-label")
  nextButton = getComponent(BUTTON_PATH, ButtonType, "next-button")
  if panelObject == nil then
    logger:warnOnce("dialogue-no-panel", "对话框面板缺失", PANEL_PATH)
    return
  end
  panelObject:SetActive(false)
  isOpen = false
  if nextButton ~= nil then
    buttonHandler = function()
      AdvanceDialogue()
    end
    nextButton.onClick:AddListener(buttonHandler)
  end
end

function OnDestroy()
  if nextButton ~= nil and buttonHandler ~= nil then
    nextButton.onClick:RemoveListener(buttonHandler)
  end
  nextButton = nil
  buttonHandler = nil
end
