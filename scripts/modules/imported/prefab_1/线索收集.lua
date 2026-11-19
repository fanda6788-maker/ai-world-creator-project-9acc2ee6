---@id 6221d9ff-efe7-4a67-8a87-5941ba20c9a3
---@referenceName 线索收集.lua
-- 玩家进入线索热点后，将提示切换为已收集状态。
---@displayName 线索自动收集
---@start
---@end

local yishouji = false
local daitiaocha = nil
local shoujijieguo = nil

function Start()
  local genjiedian = self.transform
  if genjiedian == nil then return end

  local daijiedian = genjiedian:Find("待调查")
  local yijiedian = genjiedian:Find("已收集")
  if daijiedian ~= nil then
    daitiaocha = daijiedian.gameObject
  end
  if yijiedian ~= nil then
    shoujijieguo = yijiedian.gameObject
  end
end

local function shoujixiansuo(wanjia)
  if yishouji then return end
  if wanjia ~= nil and wanjia.isLocal ~= nil and not wanjia.isLocal then return end

  yishouji = true
  if daitiaocha ~= nil then
    daitiaocha:SetActive(false)
  end
  if shoujijieguo ~= nil then
    shoujijieguo:SetActive(true)
  end
end

function OnActorTriggerEnter(wanjia)
  shoujixiansuo(wanjia)
end

function OnPlayerTriggerEnter(wanjia)
  shoujixiansuo(wanjia)
end
