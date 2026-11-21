---@id 1afd41a5-ae91-44c9-a386-2174e57dff54
---@referenceName case-hud.lua
---@displayName 勒索案任务提示

local Case = require("modules.case.case-state")
local RuntimeScope = require("official.core.runtime_scope")
local Time = CS.UnityEngine.Time
local TextType = typeof(CS.UnityEngine.UI.Text)
local scope = RuntimeScope.from(self)
local panel = nil
local label = nil
local previous = nil

function Start()
  if scope == nil then return end
  -- 复用项目的提示控件，隐藏这份界面实例里的纸牌和酒意面板。
  for _, path in ipairs({ "cardGamePanel", "drunkRoot" }) do
    local node = scope:GetGameObjectByPath(path)
    if node ~= nil then node:SetActive(false) end
  end
  panel = scope:GetGameObjectByPath("toastRoot")
  local textNode = scope:GetGameObjectByPath("toastRoot/toastLabel")
  if panel == nil or textNode == nil then return end
  label = textNode:GetComponent(TextType)
  if label ~= nil then
    label.resizeTextForBestFit = true
    label.resizeTextMinSize = 14
  end
  panel:SetActive(false)
end

function Update()
  if label == nil then return end
  local text = Case.hint(Time.time)
  if text == previous then return end
  previous = text
  if text ~= nil then label.text = text end
  panel:SetActive(text ~= nil)
end
