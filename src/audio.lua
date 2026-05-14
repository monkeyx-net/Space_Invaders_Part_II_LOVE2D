-- audio.lua: load and play sound effects

local Audio = {}
Audio.__index = Audio

local sounds = {}

local soundFiles = {
  explosion      = "assets/sounds/explosion.wav",
  shoot          = "assets/sounds/shoot.wav",
  invaderkilled  = "assets/sounds/invaderkilled.wav",
  invadermorphed = "assets/sounds/invadermorphed.wav",
  ufo_highpitch  = "assets/sounds/ufo_highpitch.wav",
  ufo_lowpitch   = "assets/sounds/ufo_lowpitch.wav",
  fastinvader1   = "assets/sounds/fastinvader1.wav",
  fastinvader2   = "assets/sounds/fastinvader2.wav",
  fastinvader3   = "assets/sounds/fastinvader3.wav",
  fastinvader4   = "assets/sounds/fastinvader4.wav",
  scorebeep      = "assets/sounds/scorebeep.wav",
  topscore       = "assets/sounds/topscore.wav",
  sos            = "assets/sounds/sos.wav",
}

function Audio.load()
  for name, path in pairs(soundFiles) do
    local ok, src = pcall(love.audio.newSource, path, "static")
    if ok then
      sounds[name] = src
    end
  end
end

-- Play a sound by name. Returns a handle (the source) that can be stopped.
-- loops: optional boolean for looping
function Audio.play(name, loops)
  local src = sounds[name]
  if not src then return nil end
  -- Clone so the same sound can overlap itself
  local clone = src:clone()
  clone:setLooping(loops or false)
  clone:play()
  return clone
end

function Audio.stop(handle)
  if handle then handle:stop() end
end

return Audio
