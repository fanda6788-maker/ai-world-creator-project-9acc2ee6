---@id 9efa4c64-a8dc-4b81-a612-77f6bd004802
---@referenceName case-interaction.lua
---@displayName 勒索案交互
---@start
---@var Role:string="letter"
---@name 交互类型
---@enum letter=勒索书,houseEnter=进入船长宅邸,houseExit=离开船长宅邸,evidence=搜集证据,hutTravel=前往破屋,hutArrival=进入破屋,canvas=帆布,hutExit=返回船长家
---@var Title:string=""
---@name 证据名称
---@var Detail:string=""
---@name 证据内容
---@var EvidenceId:number=0
---@name 证据序号
---@var Target:Vector3=(0,0,0)
---@name 传送落点
---@end

local Case = require("modules.case.case-state")
local Time = CS.UnityEngine.Time
local TextType = typeof(CS.UnityEngine.UI.Text)

local actorId = nil
local button = nil
local label = nil

local function notify(text)
  Case.notify(text, Time.time)
end

local function prompt()
  if Role == "letter" then
    return Case.hasReadLetter() and "重看勒索书" or "查看勒索书"
  elseif Role == "evidence" then
    return (Case.hasEvidence(EvidenceId) and "复查" or "搜集") .. Title
  elseif Role == "hutTravel" then
    return Case.canEnterHut() and "前往破屋" or ("破屋未解锁 · " .. Case.progress())
  elseif Role == "canvas" then
    return "查看帆布"
  elseif Role == "houseEnter" then
    return "进入船长宅邸"
  elseif Role == "houseExit" then
    return "离开船长宅邸"
  elseif Role == "hutExit" then
    return "返回船长宅邸"
  end
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then return end
  if Role == "hutArrival" then
    if Case.enterHut() then
      notify("已进入破屋 · 靠近帆布查看")
    end
    return
  end
  if Role == "canvas" and not Case.hasEnteredHut() then return end
  actorId = actor.actorID
  self:EnableInteraction()
end

function OnLostFocus()
  if button ~= nil then
    self:RemoveInteractorButton(button)
  end
  button = nil
  label = nil
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal or actor.actorID ~= actorId then return end
  actorId = nil
  self:DisableInteraction()
  OnLostFocus()
end

function OnFocus()
  if actorId == nil or button ~= nil then return end
  button = self:AddInteractorButton()
  if button ~= nil then
    label = button:GetComponentInChildren(TextType, true)
    if label ~= nil then label.text = prompt() end
  end
end

function OnInteractorButtonClick(index)
  if index ~= 1 or actorId == nil then return end
  local actor = DouyinActorService.GetActorById(actorId)
  if actor == nil or not actor.isLocal then return end

  if Role == "letter" then
    Case.readLetter()
    notify("勒索书 · 交出航海记录，否则秘密就会公开。\n前往船长宅邸搜索证据。")
  elseif Role == "evidence" then
    if not Case.hasReadLetter() then
      notify("先到侦探事务所查看勒索书。")
      return
    end
    local added = Case.collect(EvidenceId)
    if added and Case.count == Case.required then
      notify(Title .. "：" .. Detail .. "\n证据 4/6 · 回门厅前往破屋。")
    else
      notify(Title .. "：" .. Detail .. "\n" .. Case.progress())
    end
  elseif Role == "hutTravel" then
    if Case.canEnterHut() then
      actor:Teleport(Target)
    else
      notify(Case.progress() .. " · 搜集至少 4 件证据后解锁破屋。")
    end
  elseif Role == "canvas" then
    if not Case.hasEnteredHut() then return end
    Case.lookAtCanvas()
    notify("帆布下藏着被割掉的航海记录。\n这正是勒索者索要的东西。")
  else
    actor:Teleport(Target)
  end

  if label ~= nil then label.text = prompt() end
end
