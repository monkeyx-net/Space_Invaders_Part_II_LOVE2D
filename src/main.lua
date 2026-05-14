-- main.lua: Love2D entry point for Space Invaders Part II
-- Virtual world: 448 x 256 (Y=0 at bottom, bottom-up like original OpenGL code).
-- Display: scaled to fill the screen each frame via love.graphics.scale().

-- ─── globals ──────────────────────────────────────────────────────────────────
WORLD_W = 448
WORLD_H = 256

-- LuaJIT compatibility: table.unpack is just unpack in Lua 5.1
table.unpack = table.unpack or unpack

-- Key-pressed table: populated by love.keypressed, cleared at end of each frame.
-- Allows states to detect a single-frame key press without polling.
_keyPressed = {}

-- ─── requires ─────────────────────────────────────────────────────────────────
local Audio    = require("audio")
local Font     = require("font")
local HUD      = require("hud")
local Bitmap   = require("bitmap")

local Game         = require("states/game")
local Splash       = require("states/splash")
local Menu         = require("states/menu")
local Sos          = require("states/sos")
local HiScoreReg   = require("states/hiscore_reg")
local HiScoreBoard = require("states/hiscore_board")

-- ─── SpaceInvaders app table ──────────────────────────────────────────────────
local si = {}

-- HiScore persistence ----------------------------------------------------------
local HISCORE_FILE    = "hiscores.txt"
local HISCORE_COUNT   = 10
local HISCORE_NAME_LEN= 4

local defaultHiScores = {
  {name="ADAM", value=120},
  {name="_IT_", value=60},
  {name="_WIN", value=240},
  {name="NOOB", value=300},
  {name="_AN_", value=340},
  {name="TIM_", value=460},
  {name="MOON", value=480},
  {name="IAN_", value=880},
  {name="BEEF", value=1180},
  {name="PEEK", value=1440},
}

function si:loadHiScores()
  self.hiscores = {}
  local data = love.filesystem.getInfo(HISCORE_FILE) and love.filesystem.read(HISCORE_FILE)
  if data then
    for name, val in data:gmatch("([^\n]+)=(%d+)\n?") do
      self.hiscores[#self.hiscores+1] = {name=name, value=tonumber(val)}
    end
  end
  if #self.hiscores ~= HISCORE_COUNT then
    self.hiscores = {}
    for i, d in ipairs(defaultHiScores) do
      self.hiscores[i] = {name=d.name, value=d.value}
    end
  end
  table.sort(self.hiscores, function(a, b) return a.value < b.value end)
  self:updateHudHiScore()
end

function si:writeHiScores()
  local lines = {}
  for _, s in ipairs(self.hiscores) do
    lines[#lines+1] = s.name .. "=" .. tostring(s.value)
  end
  love.filesystem.write(HISCORE_FILE, table.concat(lines, "\n") .. "\n")
end

function si:isHiScore(val)
  return val > self.hiscores[1].value
end

function si:isDuplicateHiScore(score)
  for _, s in ipairs(self.hiscores) do
    if s.name == score.name and s.value == score.value then return true end
  end
  return false
end

function si:findScoreBoardPosition(val)
  if val < self.hiscores[1].value then return nil end
  if val > self.hiscores[HISCORE_COUNT].value then return HISCORE_COUNT end
  for i = 1, HISCORE_COUNT - 1 do
    if self.hiscores[i].value < val and val <= self.hiscores[i+1].value then
      return i
    end
  end
  return HISCORE_COUNT
end

function si:registerHiScore(score)
  local pos = self:findScoreBoardPosition(score.value)
  if not pos then return false end
  -- Shift everything below pos up by one (losing lowest)
  for i = 1, pos - 1 do
    self.hiscores[i] = self.hiscores[i+1]
  end
  self.hiscores[pos] = {name=score.name, value=score.value}
  self:updateHudHiScore()
  return true
end

function si:updateHudHiScore()
  self.hiscore = self.hiscores[HISCORE_COUNT].value
end

-- Game stats -------------------------------------------------------------------
function si:resetGameStats()
  self.lives      = 4
  self.score      = 0
  self.round      = 0
  self.credit     = 0
  self.playerName = nil
  self:updateLivesHud()
end

function si:addScore(n)
  self.score = self.score + n
  if self.score > self.hiscore then
    self.hiscore = self.score
  end
end

-- State machine ----------------------------------------------------------------
function si:switchState(name)
  if self.activeState then
    if self.activeState.leave then self.activeState:leave() end
  end
  self.activeState = self.states[name]
  if self.activeState then
    if self.activeState.enter then self.activeState:enter() end
  end
end

-- HUD management ---------------------------------------------------------------
function si:showHud()  self.hud:show() end
function si:hideHud()  self.hud:hide() end

function si:showTopHud()
  self.hud:showLabel(self.uid.scoreText)
  self.hud:showLabel(self.uid.scoreVal)
  self.hud:showLabel(self.uid.hiText)
  self.hud:showLabel(self.uid.hiVal)
  self.hud:showLabel(self.uid.roundText)
  self.hud:showLabel(self.uid.roundVal)
end

function si:hideTopHud()
  self.hud:hideLabel(self.uid.scoreText)
  self.hud:hideLabel(self.uid.scoreVal)
  self.hud:hideLabel(self.uid.hiText)
  self.hud:hideLabel(self.uid.hiVal)
  self.hud:hideLabel(self.uid.roundText)
  self.hud:hideLabel(self.uid.roundVal)
end

function si:hideLivesHud()
  self.livesHudVisible = false
  self.hud:hideLabel(self.uid.livesVal)
  for _, uid in ipairs(self.uid.livesBmps) do
    self.hud:hideLabel(uid)
  end
end

function si:showLivesHud()
  self.livesHudVisible = true
  self.hud:showLabel(self.uid.livesVal)
  self:updateLivesHud()
end

function si:updateLivesHud()
  if not self.livesHudVisible then return end
  -- Show cannon icons for lives 2, 3, 4 (not counting life 1 = current)
  for i, uid in ipairs(self.uid.livesBmps) do
    if i < self.lives then
      self.hud:showLabel(uid)
    else
      self.hud:hideLabel(uid)
    end
  end
end

function si:startScoreFlash()
  self.hud:startFlash(self.uid.scoreVal)
end

function si:stopScoreFlash()
  self.hud:stopFlash(self.uid.scoreVal)
end

-- ─── love callbacks ───────────────────────────────────────────────────────────
function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")

  Audio.load()
  si.font = Font.load("space")
  si.hud  = HUD.new(si.font)

  -- Game state variables
  si.score    = 0
  si.hiscore  = 0
  si.round    = 0
  si.credit   = 0
  si.lives    = 4
  si.playerName    = nil
  si.lastAlienClass = 3  -- OCTOPUS by default
  si.livesHudVisible = false

  -- Load hi-scores before HUD (updateHudHiScore sets si.hiscore)
  si:loadHiScores()

  -- HUD labels (positions in 448×256 bottom-up world coords).
  -- xOffset = (448 - 224) / 2 = 112, mapping original 224-wide positions to 448-wide world.
  -- Top row (y≈240 = near top in bottom-up = near top of screen)
  si.uid = {}
  si.uid.scoreText = si.hud:addText(122, 240, 1,0,1,  "SCORE")
  si.uid.scoreVal  = si.hud:addInt( 122, 230, 1,1,1,  function() return si.score end, 5)
  si.uid.hiText    = si.hud:addText(197, 240, 1,0,0,  "HI-SCORE")
  si.uid.hiVal     = si.hud:addInt( 207, 230, 0,1,0,  function() return si.hiscore end, 5)
  si.uid.roundText = si.hud:addText(282, 240, 1,1,0,  "ROUND")
  si.uid.roundVal  = si.hud:addInt( 282, 230, 1,0,1,  function() return si.round end, 5)

  -- Bottom row (y≈6 = near bottom in bottom-up = near bottom of screen)
  si.uid.creditText = si.hud:addText(242, 6, 1,0,1, "CREDIT")
  si.uid.creditVal  = si.hud:addInt( 302, 6, 0,1,1, function() return si.credit end, 1)
  si.uid.livesVal   = si.hud:addInt( 122, 6, 1,1,0, function() return si.lives  end, 1)

  -- Lives cannon icons (up to 3 extra = lives 2,3,4)
  local cannonBmp = Bitmap.load("cannon0")
  si.uid.livesBmps = {}
  for i = 0, 2 do
    si.uid.livesBmps[i+1] = si.hud:addBitmap(132 + 16*i, 6, 0,1,0, cannonBmp)
  end

  -- Everything hidden until a state shows it
  si:hideHud()
  si:hideTopHud()
  si:hideLivesHud()

  -- Build states
  si.states = {
    game          = Game.new(si),
    splash        = Splash.new(si),
    menu          = Menu.new(si),
    sos           = Sos.new(si),
    hiscore_reg   = HiScoreReg.new(si),
    hiscore_board = HiScoreBoard.new(si),
  }

  -- SOS needs a reference to game to read lastAlienClass
  si.states.sos.gameState = si.states.game

  si:switchState("splash")
end

function love.update(dt)
  si.hud:update(dt)
  if si.activeState and si.activeState.update then
    si.activeState:update(dt)
  end
  _keyPressed = {}  -- clear single-frame key events at end of frame
end

function love.draw()
  local sw, sh = love.graphics.getDimensions()
  love.graphics.push()
  love.graphics.scale(sw / WORLD_W, sh / WORLD_H)

  if si.activeState and si.activeState.draw then
    si.activeState:draw()
  end
  si.hud:draw()

  love.graphics.pop()
end

function love.keypressed(key)
  _keyPressed[key] = true
  if key == "escape" then
    love.event.quit()
  end
end
function love.gamepadpressed(joystick, button)
  -- Map gamepad buttons to virtual key names for consistency
  if button == "a" or button == "b" or button == "x" or button == "y" then
    -- Fire buttons: A, B, X, Y all trigger firing
    _keyPressed["space"] = true
  elseif button == "start" then
    -- Start button acts like Return key
    _keyPressed["return"] = true
  elseif button == "back" then
    -- Select button (back on Xbox controllers) exits
    love.event.quit()
  elseif button == "leftshoulder" or button == "lb" then
    -- L1/LB button acts like S key (high score board)
    _keyPressed["s"] = true
  elseif button == "rightshoulder" or button == "rb" then
    -- R1/RB button also acts like S key (high score board)
    _keyPressed["s"] = true
  end
end