-- states/sos.lua: SOS intermission – UFO and alien bounce around, engine may fail.
-- Mirrors C++ SosState.
-- World coords: 448×256, Y=0 at bottom (bottom-up).

local Bitmap = require("bitmap")
local Audio  = require("audio")

local Sos = {}
Sos.__index = Sos

-- ─── constants ────────────────────────────────────────────────────────────────
local WORLD_MARGIN       = 60
local SPAWN_HEIGHT       = 60
local TOP_MARGIN         = 40
local SOS_TEXT_MARGIN    = 10
local SOS_TRAIL_SPACE    = 8
local MOVE_SPEED         = 75
local MOVE_ANGLE         = 0.9899310886   -- 55 degrees in radians
local ENGINE_FAIL_PERIOD = 3.0
local ENGINE_FAIL_CHANCE = 720           -- 1-in-N chance per update
local ALIEN_FRAME_PERIOD = 0.1

local MAX_SOS_TEXTS = 4

-- Alien class data (mirrors C++ GameState::_alienClasses, indices 1-5)
local alienClasses = {
  {w=8,  h=8, bmp={"squid0",   "squid1"},   color={1,1,1}},  -- SQUID=1
  {w=11, h=8, bmp={"crab0",    "crab1"},    color={0,1,1}},  -- CRAB=2
  {w=12, h=8, bmp={"octopus0", "octopus1"}, color={1,0,1}},  -- OCTOPUS=3
  {w=8,  h=8, bmp={"cuttle0",  "cuttle1"},  color={1,1,0}},  -- CUTTLE=4
  {w=19, h=8, bmp={"cuttletwin","cuttletwin"}, color={1,1,0}},-- CUTTLETWIN=5
}

-- UFO class data (only SAUCER=1 is used in SOS)
local ufoClasses = {
  {w=16, h=7, bmp="saucer",      color={1,0,1}},  -- SAUCER=1
  {w=15, h=7, bmp="schrodinger", color={0,1,1}},  -- SCHRODINGER=2
}

-- ─── constructor ──────────────────────────────────────────────────────────────
function Sos.new(si)
  local s = setmetatable({}, Sos)
  s.si        = si
  s.gameState = nil   -- set by main.lua after all states created

  -- Pre-load bitmaps
  s.bitmaps = {}
  local names = {
    "squid0","squid1","crab0","crab1","octopus0","octopus1",
    "cuttle0","cuttle1","cuttletwin","saucer","schrodinger","sostrail",
  }
  for _, n in ipairs(names) do s.bitmaps[n] = Bitmap.load(n) end

  s.exitHeight      = WORLD_H - TOP_MARGIN
  s.worldLeftMargin = WORLD_MARGIN
  s.worldRightMargin= WORLD_W - WORLD_MARGIN

  -- Compute SOS text x position (right-aligned)
  local sosW = si.font:stringWidth("SOS  !!")
  s.sosTextX = WORLD_W - sosW - SOS_TEXT_MARGIN

  s.uids = {}
  return s
end

-- ─── enter ────────────────────────────────────────────────────────────────────
function Sos:enter()
  local si = self.si

  -- Use the last alien class alive from the game state
  local alienClass = (self.gameState and self.gameState.lastClassAlive) or 3
  local ac = alienClasses[alienClass]
  local uc = ufoClasses[1]  -- always saucer

  -- Spawn UFO at a random horizontal position
  local ufoX = love.math.random(self.worldLeftMargin, self.worldRightMargin - uc.w)

  self.ufo = {
    classId = 1,
    x       = ufoX,
    y       = SPAWN_HEIGHT,
    w       = uc.w,
  }

  self.alien = {
    classId    = alienClass,
    x          = ufoX + (uc.w - ac.w) / 2,
    y          = SPAWN_HEIGHT + uc.h,
    frame      = 1,
    frameClock = 0,
    failX      = 0,
    failY      = 0,
  }

  -- Movement velocity: angle from vertical (sin=horiz, cos=vert component)
  local vx = MOVE_SPEED * math.sin(MOVE_ANGLE)
  local vy = MOVE_SPEED * math.cos(MOVE_ANGLE)
  self.velX = vx
  self.velY = vy

  self.isEngineFailing  = false
  self.hasEngineFailed  = false
  self.engineFailClock  = 0
  self.isWooing         = false
  self.woowooHandle     = nil
  self.nextSosText      = 0
  self.uids             = {}

  -- Start SOS sound
  self.woowooHandle = Audio.play("sos", true)
  self.isWooing     = true

  si:showHud()
end

-- ─── update helpers ───────────────────────────────────────────────────────────
function Sos:doMoving(dt)
  if self.isEngineFailing then return end

  if self.hasEngineFailed then
    -- Alien drifts upward on its own after engine fails
    self.alien.y = self.alien.y + 0.6 * MOVE_SPEED * dt
  else
    self.ufo.x   = self.ufo.x   + self.velX * dt
    self.ufo.y   = self.ufo.y   + self.velY * dt
    self.alien.x = self.alien.x + self.velX * dt
    self.alien.y = self.alien.y + self.velY * dt
  end
end

function Sos:doAlienAnimating(dt)
  if not self.hasEngineFailed then return end
  self.alien.frameClock = self.alien.frameClock + dt
  if self.alien.frameClock >= ALIEN_FRAME_PERIOD then
    self.alien.frameClock = 0
    self.alien.frame = (self.alien.frame == 1) and 2 or 1
  end
end

function Sos:doEngineFailing(dt)
  if not self.isEngineFailing then return end
  self.engineFailClock = self.engineFailClock + dt
  if self.engineFailClock >= ENGINE_FAIL_PERIOD then
    self.alien.failX     = self.alien.x
    self.alien.failY     = self.alien.y
    self.alien.frameClock= 0
    self.isEngineFailing = false
    self.hasEngineFailed = true
  end
end

function Sos:doEngineCheck()
  if self.hasEngineFailed then return end
  if self.isEngineFailing  then return end

  if love.math.random(0, ENGINE_FAIL_CHANCE) == 0 then
    self.isEngineFailing = true
    self.engineFailClock = 0

    -- Show "ENGINE TROUBLE" text above UFO
    local si = self.si
    local troubleText = "ENGINE TROUBLE"
    local tw = si.font:stringWidth(troubleText)
    local tx = self.ufo.x - math.abs(self.ufo.w - tw) / 2
    local ty = self.ufo.y + ufoClasses[1].h + si.font.lineSpace
    self.uids.trouble = si.hud:addText(tx, ty, 1,0,1, troubleText)

    Audio.stop(self.woowooHandle)
    self.isWooing = false
  end
end

function Sos:doWallColliding()
  if self.isEngineFailing or self.hasEngineFailed then return end

  local hitWall = false
  if self.ufo.x < self.worldLeftMargin and self.velX < 0 then
    self.velX = -self.velX
    hitWall   = true
  elseif (self.ufo.x + self.ufo.w) > self.worldRightMargin and self.velX > 0 then
    self.velX = -self.velX
    hitWall   = true
  end

  if hitWall and self.nextSosText < MAX_SOS_TEXTS then
    local si = self.si
    local ty = self.ufo.y + si.font.size / 2
    local uid = si.hud:addText(self.sosTextX, ty, 1,0,1, "SOS  !!")
    self.nextSosText = self.nextSosText + 1
    self.uids["sos"..self.nextSosText] = uid
  end
end

function Sos:doEndTest()
  if self.alien.y <= self.exitHeight then return end

  -- Clean up sound and HUD labels
  if self.isWooing then Audio.stop(self.woowooHandle) end
  if self.uids.trouble then self.si.hud:remove(self.uids.trouble) end
  for i = 1, self.nextSosText do
    local uid = self.uids["sos"..i]
    if uid then self.si.hud:remove(uid) end
  end
  self.uids = {}

  self.si:switchState("game")
end

function Sos:update(dt)
  self:doEngineCheck()
  self:doAlienAnimating(dt)
  self:doMoving(dt)
  self:doEngineFailing(dt)
  self:doWallColliding()
  self:doEndTest()
end

-- ─── draw ─────────────────────────────────────────────────────────────────────
function Sos:draw()
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)

  local ac = alienClasses[self.alien.classId]
  local uc = ufoClasses[self.ufo.classId]

  -- Draw trail if engine has failed
  if self.hasEngineFailed then
    local trailBmp = self.bitmaps["sostrail"]
    local ty = self.alien.failY
    while ty < self.alien.y do
      love.graphics.setColor(table.unpack(ac.color))
      trailBmp:draw(self.alien.x, ty)
      ty = ty + SOS_TRAIL_SPACE
    end
  end

  -- Draw alien
  local aBmpName = ac.bmp[self.alien.frame]
  love.graphics.setColor(table.unpack(ac.color))
  self.bitmaps[aBmpName]:draw(self.alien.x, self.alien.y)

  -- Draw UFO (only when not failed)
  if not self.hasEngineFailed then
    love.graphics.setColor(table.unpack(uc.color))
    self.bitmaps[uc.bmp]:draw(self.ufo.x, self.ufo.y)
  end
end

return Sos
