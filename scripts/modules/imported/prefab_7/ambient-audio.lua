---@id 36833d03-113f-4690-aa1b-4c10388cc072
---@referenceName ambient-audio.lua
-- 播放雾夜街道或剧院门厅的循环环境声
---@displayName 环境音播放
---@start
---@var AmbientSound:UnityEngine.AudioClip=nil
---@name 音效
---@refFrom asset
---@assetCategory Music
---@dataType Audio
---@var AmbientVolume:number=0.35
---@name 音量
---@desc 0–1，0 表示静音
---@var AmbientMaxDistance:number=24
---@name 最大作用范围
---@desc 距声源的可听半径，单位米；小于等于 0 时不播放
---@end

local AudioRolloffMode = CS.UnityEngine.AudioRolloffMode
local Object = CS.UnityEngine.Object

local audioSource = nil
local currentClip = nil

local function clamp01(value)
  if value == nil then
    return 0
  end
  if value < 0 then
    return 0
  end
  if value > 1 then
    return 1
  end
  return value
end

-- 按当前参数同步播放器：引用、音量与作用范围变化都在这里生效。
local function applySettings()
  if audioSource == nil then
    return false
  end

  local clip = AmbientSound
  local volume = clamp01(AmbientVolume)
  local distance = AmbientMaxDistance or 0
  if clip == nil or volume <= 0 or distance <= 0 then
    if audioSource.isPlaying then
      audioSource:Stop()
    end
    currentClip = nil
    return false
  end

  if currentClip ~= clip then
    audioSource:Stop()
    audioSource.clip = clip
    currentClip = clip
  end

  audioSource.volume = volume
  audioSource.minDistance = math.min(1, distance * 0.1)
  audioSource.maxDistance = distance

  if not audioSource.isPlaying then
    audioSource:Play()
  end
  return true
end

function Start()
  audioSource = self.gameObject:AddComponent(typeof(CS.UnityEngine.AudioSource))
  audioSource.playOnAwake = false
  audioSource.loop = true
  audioSource.spatialBlend = 1
  audioSource.rolloffMode = AudioRolloffMode.Linear
  applySettings()
end

function Update()
  if audioSource == nil then
    return
  end
  -- 播放期间持续应用当前参数，面板调整无需重新进入场景。
  applySettings()
end

function OnDisable()
  if audioSource ~= nil then
    audioSource:Stop()
    currentClip = nil
  end
end

function OnDestroy()
  if audioSource ~= nil then
    audioSource:Stop()
    Object.Destroy(audioSource)
    audioSource = nil
    currentClip = nil
  end
end
