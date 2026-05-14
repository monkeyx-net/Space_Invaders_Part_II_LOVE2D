-- states/splash.lua: animated "SPACE INVADERS" + "PART II" intro screen.
-- Mirrors C++ SplashState / Sign<W,H> template.
-- World coords: 448×256, Y=0 at bottom.

local Bitmap = require("bitmap")

local Splash = {}
Splash.__index = Splash

-- ─── Sign block data ──────────────────────────────────────────────────────────
-- Each cell: 1 = block still visible, 0 = block removed (after being decremented)
-- The animation decrements cells one at a time until all reach 0.

local SPACE_W, SPACE_H = 48, 16
local spaceBlocks = {
  {1,2,2,2,2,1,1,1,1,1,2,2,2,2,2,2,2,1,1,1,1,1,2,2,2,2,2,1,1,1,1,1,1,2,2,2,2,1,1,1,1,2,2,2,2,2,2,2},
  {2,2,2,2,2,2,2,1,1,1,2,2,2,2,2,2,2,2,1,1,1,1,2,2,2,2,2,1,1,1,1,1,2,2,2,2,2,2,1,1,1,2,2,2,2,2,2,2},
  {2,2,2,2,2,2,2,2,1,1,2,2,2,2,2,2,2,2,2,1,1,2,2,2,2,2,2,2,1,1,1,2,2,2,2,2,2,2,2,1,1,2,2,2,2,2,2,2},
  {2,2,2,2,2,2,2,2,1,1,2,2,2,2,2,2,2,2,2,1,1,2,2,2,2,2,2,2,1,1,1,2,2,2,2,2,2,2,2,1,1,2,2,2,2,2,2,2},
  {2,2,1,1,1,2,2,2,1,1,2,2,2,1,1,1,2,2,2,1,2,2,2,2,2,2,2,2,2,1,1,2,2,2,1,1,2,2,2,1,2,2,2,1,1,1,1,1},
  {2,2,2,1,1,2,2,2,1,1,2,2,2,1,1,1,2,2,2,1,2,2,2,2,2,2,2,2,2,1,1,2,2,2,1,1,2,2,2,1,2,2,2,1,1,1,1,1},
  {1,2,2,2,1,1,1,1,1,1,2,2,2,1,1,1,2,2,2,1,2,2,2,1,2,1,2,2,2,1,1,2,2,2,1,1,1,1,1,1,2,2,2,1,1,1,1,1},
  {1,2,2,2,2,2,1,1,1,1,2,2,2,2,2,2,2,2,2,1,2,2,2,1,2,1,2,2,2,1,1,2,2,2,1,1,1,1,1,1,2,2,2,2,2,1,1,1},
  {1,1,2,2,2,2,2,2,1,1,1,2,2,2,2,2,2,2,1,1,2,2,2,2,2,2,2,2,2,1,2,2,2,1,1,1,1,1,1,2,2,2,2,2,2,1,1,1},
  {1,1,1,1,2,2,2,2,2,1,1,2,2,2,2,2,2,1,1,1,1,1,2,2,2,2,2,1,1,1,2,2,2,1,1,1,1,1,1,2,2,2,2,2,2,1,1,1},
  {1,1,1,1,1,1,2,2,2,1,1,2,2,2,1,1,1,1,1,1,1,2,2,2,1,2,2,2,1,1,2,2,2,1,1,1,1,1,1,2,2,1,1,1,1,1,1,1},
  {1,1,1,2,2,1,1,2,2,1,1,2,2,2,1,1,1,1,1,1,1,2,2,2,1,2,2,2,1,1,2,2,2,1,2,2,2,1,1,2,2,1,1,1,1,1,1,1},
  {1,1,1,2,2,1,1,2,2,1,1,2,2,2,1,1,1,1,1,1,2,2,2,1,1,1,2,2,2,1,2,2,2,1,2,2,2,1,2,2,2,1,1,1,1,1,1,1},
  {1,1,1,2,2,2,2,2,2,1,1,2,2,2,1,1,1,1,1,1,2,2,2,1,1,1,2,2,2,1,2,2,2,2,2,2,2,1,2,2,2,2,2,2,1,1,1,1},
  {1,1,1,1,2,2,2,2,1,1,1,2,2,2,1,1,1,1,1,1,1,2,2,2,1,2,2,2,1,1,1,2,2,2,2,2,1,1,2,2,2,2,2,2,1,1,1,1},
  {1,1,1,1,1,2,2,1,1,1,1,2,2,2,1,1,1,1,1,1,1,2,2,2,1,2,2,2,1,1,1,1,2,2,2,1,1,1,2,2,2,2,2,2,1,1,1,1},
}

local INVADERS_W, INVADERS_H = 48, 8
local invadersBlocks = {
  {1,2,2,1,2,2,1,1,2,2,1,2,2,1,1,2,2,1,1,2,2,2,1,1,2,2,2,2,1,1,2,2,2,2,2,1,2,2,2,2,1,1,1,2,2,2,1,1},
  {1,2,2,1,2,2,1,1,2,2,1,2,2,1,1,2,2,1,1,2,2,2,1,1,2,2,1,2,2,1,2,2,1,1,1,1,2,2,1,2,2,1,2,2,1,2,2,1},
  {1,2,2,1,2,2,2,1,2,2,1,2,2,1,1,2,2,1,2,2,1,2,2,1,2,2,1,2,2,1,2,2,1,1,1,1,2,2,1,2,2,1,2,2,1,1,1,1},
  {1,2,2,1,2,2,2,2,2,2,1,2,2,1,1,2,2,1,2,2,1,2,2,1,2,2,1,2,2,1,2,2,1,1,1,1,2,2,1,2,2,1,2,2,1,1,1,1},
  {1,2,2,1,2,2,2,2,2,2,1,1,2,2,2,2,1,1,2,2,2,2,2,1,2,2,1,2,2,1,2,2,2,2,2,1,2,2,2,2,1,1,1,2,2,2,1,1},
  {1,2,2,1,2,2,1,2,2,2,1,1,2,2,2,2,1,1,2,2,1,2,2,1,2,2,1,2,2,1,2,2,1,1,1,1,2,2,1,2,2,1,1,1,1,2,2,1},
  {1,2,2,1,2,2,1,1,2,2,1,1,1,2,2,1,1,1,2,2,1,2,2,1,2,2,1,2,2,1,2,2,1,1,1,1,2,2,1,2,2,1,2,2,1,2,2,1},
  {1,2,2,1,2,2,1,1,2,2,1,1,1,2,2,1,1,1,2,2,1,2,2,1,2,2,2,2,1,1,2,2,2,2,2,1,2,2,1,2,2,1,1,2,2,2,1,1},
}

-- ─── helpers ──────────────────────────────────────────────────────────────────
-- Deep-copy a 2D table of numbers
local function copyBlocks(src)
  local dst = {}
  for r, row in ipairs(src) do
    dst[r] = {}
    for c, v in ipairs(row) do dst[r][c] = v end
  end
  return dst
end

-- ─── Sign object ──────────────────────────────────────────────────────────────
local Sign = {}
Sign.__index = Sign

function Sign.new(blocks, w, h, posX, posY, topColor, bottomColor, blockLag, blockSize, blockSpace)
  local s = setmetatable({}, Sign)
  s.blocks     = blocks
  s.w          = w
  s.h          = h
  s.posX       = posX
  s.posY       = posY       -- bottom-up Y of row 0 (topmost row drawn)
  s.topColor   = topColor
  s.bottomColor= bottomColor
  s.blockLag   = blockLag  -- seconds per block reveal
  s.blockSize  = blockSize
  s.blockGap   = blockSize + blockSpace
  s.row        = 1
  s.col        = 1
  s.clock      = 0
  s.isDone     = false
  return s
end

function Sign:reset()
  -- Can only reset after isDone; increments all cells back to original values
  if not self.isDone then return end
  for r = 1, self.h do
    for c = 1, self.w do
      self.blocks[r][c] = self.blocks[r][c] + 1
    end
  end
  self.row    = 1
  self.col    = 1
  self.clock  = 0
  self.isDone = false
end

function Sign:updateBlocks(dt)
  if self.isDone then return end
  self.clock = self.clock + dt
  while self.clock > self.blockLag and not self.isDone do
    self.blocks[self.row][self.col] = self.blocks[self.row][self.col] - 1
    self.col = self.col + 1
    if self.col > self.w then
      self.col = 1
      self.row = self.row + 1
      if self.row > self.h then
        self.isDone = true
      end
    end
    self.clock = self.clock - self.blockLag
  end
end

function Sign:draw()
  for row = 1, self.h do
    for col = 1, self.w do
      if self.blocks[row][col] == 0 then goto next end
      local bx = self.posX + (col - 1) * self.blockGap
      -- row 1 is topmost; in bottom-up Y, row 1 = posY, row h = posY-(h-1)*blockGap
      local by = self.posY - (row - 1) * self.blockGap
      -- Convert bottom-up to Love2D: loveY = WORLD_H - by - blockSize
      local loveY = WORLD_H - by - self.blockSize
      local color = (row <= self.h / 2) and self.topColor or self.bottomColor
      love.graphics.setColor(color[1], color[2], color[3], 1)
      love.graphics.rectangle("fill",
        math.floor(bx + 0.5),
        math.floor(loveY + 0.5),
        self.blockSize, self.blockSize)
      ::next::
    end
  end
end

-- ─── Splash state ─────────────────────────────────────────────────────────────
function Splash.new(si)
  local s = setmetatable({}, Splash)
  s.si = si
  return s
end

function Splash:enter()
  local si = self.si
  si:hideHud()

  self.masterClock = 0
  self.nextNode    = 1

  -- Sequence nodes: {time, event}
  self.sequence = {
    {1.0,  "show_space"},
    {2.0,  "trigger_space"},
    {4.5,  "show_invaders"},
    {5.5,  "trigger_invaders"},
    {7.3,  "show_partii"},
    {8.3,  "show_hud"},
    {11.0, "end"},
  }

  local blockSize  = 3
  local blockSpace = 1
  -- Centered: signWidth = 48 * (3+1) = 192; (448-192)/2 = 128
  local signX      = (WORLD_W - 48 * (blockSize + blockSpace)) / 2

  self.spaceSign = Sign.new(
    copyBlocks(spaceBlocks),
    SPACE_W, SPACE_H,
    signX, 192,        -- posX, posY (bottom-up: row1 at y=192)
    {0,1,0}, {0,1,1},  -- topColor=green, bottomColor=cyan
    0.002, blockSize, blockSpace
  )

  self.invadersSign = Sign.new(
    copyBlocks(invadersBlocks),
    INVADERS_W, INVADERS_H,
    signX, 112,          -- posX, posY
    {1,0,1}, {1,1,0},   -- topColor=magenta, bottomColor=yellow
    0.002, blockSize, blockSpace
  )

  self.spaceVisible      = false
  self.spaceTriggered    = false
  self.invadersVisible   = false
  self.invadersTriggered = false
  self.partiiVisible     = false
  self.partiiX           = (WORLD_W - 57) / 2   -- 57 = approx width of PARTII bitmap
  self.partiiY           = 48

  self.partiiBmp = Bitmap.load("partii")
  -- Recalculate centered X once we know bitmap width
  if self.partiiBmp then
    self.partiiX = (WORLD_W - self.partiiBmp.w) / 2
  end

  self.authorUid = nil
end

function Splash:doEvents()
  if self.nextNode > #self.sequence then return end
  local node = self.sequence[self.nextNode]
  if self.masterClock < node[1] then return end

  local event = node[2]
  if event == "show_space" then
    self.spaceVisible = true

  elseif event == "trigger_space" then
    self.spaceTriggered = true

  elseif event == "show_invaders" then
    self.invadersVisible = true

  elseif event == "trigger_invaders" then
    self.invadersTriggered = true

  elseif event == "show_partii" then
    self.partiiVisible = true

  elseif event == "show_hud" then
    local si = self.si
    self.authorUid = si.hud:addText(
      (WORLD_W - si.font:stringWidth("*REMAKE BY IANMURFINXYZ*")) / 2, 24,
      0,1,1, "*REMAKE BY IANMURFINXYZ*")
    si:showHud()
    si:hideLivesHud()

  elseif event == "end" then
    local si = self.si
    if self.authorUid then
      si.hud:remove(self.authorUid)
      self.authorUid = nil
    end
    si:switchState("menu")
  end

  self.nextNode = self.nextNode + 1
end

function Splash:update(dt)
  self.masterClock = self.masterClock + dt
  self:doEvents()
  if self.spaceTriggered    then self.spaceSign:updateBlocks(dt)    end
  if self.invadersTriggered then self.invadersSign:updateBlocks(dt) end
end

function Splash:draw()
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)

  if self.spaceVisible    then self.spaceSign:draw()    end
  if self.invadersVisible then self.invadersSign:draw() end

  if self.partiiVisible and self.partiiBmp then
    love.graphics.setColor(1, 0, 0, 1)
    self.partiiBmp:draw(self.partiiX, self.partiiY)
  end
end

return Splash
