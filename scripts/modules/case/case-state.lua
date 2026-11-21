-- 案件进度由本地玩家的交互修改，场景节点流式加载时仍可共享。
local Case = { required = 4, total = 6, count = 0 }
local collected = {}
local viewedLetter = false
local enteredHut = false
local viewedCanvas = false
local message = nil
local messageUntil = 0

function Case.notify(text, now)
  message = text
  messageUntil = now + 7
end

function Case.readLetter()
  viewedLetter = true
end

function Case.hasReadLetter()
  return viewedLetter
end

function Case.hasEvidence(id)
  return collected[id] == true
end

function Case.collect(id)
  if not viewedLetter or collected[id] or id < 1 or id > Case.total then
    return false
  end
  collected[id] = true
  Case.count = Case.count + 1
  return true
end

function Case.canEnterHut()
  return Case.count >= Case.required
end

function Case.enterHut()
  if not Case.canEnterHut() or enteredHut then
    return false
  end
  enteredHut = true
  return true
end

function Case.hasEnteredHut()
  return enteredHut
end

function Case.lookAtCanvas()
  if not enteredHut or viewedCanvas then
    return false
  end
  viewedCanvas = true
  return true
end

function Case.progress()
  return string.format("证据 %d/%d", Case.count, Case.total)
end

function Case.hint(now)
  if now < messageUntil then
    return message
  end
  if viewedCanvas then
    return nil
  end
  if enteredHut then
    return "任务 · 靠近并查看帆布"
  end
  if Case.canEnterHut() then
    return Case.progress() .. " · 到宅邸门厅前往破屋"
  end
  if viewedLetter then
    return Case.progress() .. " · 到船长宅邸搜查（至少 4 件）"
  end
  return "任务 · 到侦探事务所主桌查看勒索书"
end

return Case
