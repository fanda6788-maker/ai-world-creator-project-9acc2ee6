---@id 2d3b4dc3-ba20-4ed0-adbd-8075efe99648
---@referenceName chuansong.lua
---@displayName 建筑入口传送
---@start
---@var ChuanSongMuBiao:Vector3=(0,0,0)
---@name 传送目标
---@desc 玩家进入触发区后到达的世界坐标
---@var MuBiaoChaoxiang:number=0
---@name 目标朝向
---@desc 玩家传送后的水平朝向角度
---@end

local UnityEngine = CS.UnityEngine

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then
    return
  end

  local mubiaoXuanzhuan = UnityEngine.Quaternion.Euler(0, MuBiaoChaoxiang, 0)
  actor:Teleport(ChuanSongMuBiao, mubiaoXuanzhuan)
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then
    return
  end
end
