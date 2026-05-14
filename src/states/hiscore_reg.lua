-- states/hiscore_reg.lua: Hi-score name entry keypad.
-- Mirrors C++ HiScoreRegState with Keypad and NameBox inner classes.
-- World coords: 448×256, Y=0 at bottom.

local Audio = require("audio")

local HiScoreReg = {}
HiScoreReg.__index = HiScoreReg

-- ─── constants ────────────────────────────────────────────────────────────────
local KEY_ROWS    = 4
local KEY_COLS    = 11
local KEY_SPACE   = 4    -- pixels between keys
local CURSOR_DROP = 2    -- pixels the cursor sits below key text
local NAME_LEN    = 4
local NULL_CHAR   = "-"
local QUOTE_CHAR  = "'"

-- Keypad layout (row 1 = top row of keys)
local keyLayout = {
  {"A","B","C","D","E","F","G","H","I","J","K"},   -- row 4 (top)
  {"L","M","N","O","P","Q","R","S","T","U","V"},   -- row 3
  {"W","X","Y","Z",".",  "_","-", "[","]","<",">"},-- row 2
  {"\\","/","(",")","+","^","RUB","","","END",""},  -- row 1 (bottom)
}
-- Map keyLayout[1] = top row (index 4 in C++ where 0=bottom).
-- In Love2D we just keep rows top-to-bottom as stored here.

-- ─── constructor ──────────────────────────────────────────────────────────────
function HiScoreReg.new(si)
  local h = setmetatable({}, HiScoreReg)
  h.si = si
  h.cursorRow = 1   -- 1=top row, KEY_ROWS=bottom row
  h.cursorCol = 1   -- 1=left
  h.nameBuffer = {NULL_CHAR, NULL_CHAR, NULL_CHAR, NULL_CHAR}

  -- Positions are computed in enter() once we have font metrics
  h.padX = 0
  h.padY = 0
  h.cellW = 0
  h.cellH = 0
  h.nameBoxX = 0
  h.nameBoxY = 0
  return h
end

-- ─── enter ────────────────────────────────────────────────────────────────────
function HiScoreReg:enter()
  local si   = self.si
  local font = si.font

  -- Compute cell size from font
  self.cellW = font.size + KEY_SPACE
  self.cellH = font.size + KEY_SPACE

  local padW = KEY_COLS * self.cellW
  local padH = KEY_ROWS * self.cellH

  -- Centre keypad in world
  self.padX = (WORLD_W - padW) / 2
  -- In bottom-up coords, position the pad in the lower half
  -- padY is the top edge of the top row (row 1) in bottom-up coords
  -- We want the pad centred vertically: use 1/4 of world height from bottom
  self.padY = WORLD_H / 2 + padH / 2   -- top of top row in bottom-up coords

  -- Name box above the pad
  local nameFinal = self:composeNameFinal()
  local nameW = font:stringWidth(nameFinal)
  self.nameBoxX = (WORLD_W - nameW) / 2
  self.nameBoxY = WORLD_H * 3 / 4 - font.size  -- upper quarter

  -- Reset cursor and name
  self.cursorRow = 1
  self.cursorCol = 1
  self:skipEmptyKeys()
  self.nameBuffer = {NULL_CHAR, NULL_CHAR, NULL_CHAR, NULL_CHAR}

  si:showHud()
end

function HiScoreReg:composeNameFinal()
  local s = "NAME " .. QUOTE_CHAR
  for _, c in ipairs(self.nameBuffer) do s = s .. c end
  s = s .. QUOTE_CHAR
  return s
end

function HiScoreReg:isNameFull()
  return self.nameBuffer[NAME_LEN] ~= NULL_CHAR
end

function HiScoreReg:isNameEmpty()
  return self.nameBuffer[1] == NULL_CHAR
end

function HiScoreReg:namePushBack(c)
  if self:isNameFull() then return false end
  for i = NAME_LEN, 1, -1 do
    if i == 1 then
      self.nameBuffer[1] = c
    elseif self.nameBuffer[i] == NULL_CHAR and self.nameBuffer[i-1] ~= NULL_CHAR then
      self.nameBuffer[i] = c
      break
    end
  end
  return true
end

function HiScoreReg:namePopBack()
  if self:isNameEmpty() then return false end
  if self:isNameFull() then
    self.nameBuffer[NAME_LEN] = NULL_CHAR
    return true
  end
  for i = NAME_LEN, 1, -1 do
    if i == 1 then
      self.nameBuffer[1] = NULL_CHAR
    elseif self.nameBuffer[i] == NULL_CHAR and self.nameBuffer[i-1] ~= NULL_CHAR then
      self.nameBuffer[i-1] = NULL_CHAR
      break
    end
  end
  return true
end

function HiScoreReg:getActiveKey()
  return keyLayout[self.cursorRow][self.cursorCol]
end

function HiScoreReg:skipEmptyKeys()
  -- If cursor lands on an empty slot, advance right
  while self:getActiveKey() == "" do
    self.cursorCol = self.cursorCol + 1
    if self.cursorCol > KEY_COLS then self.cursorCol = 1 end
  end
end

local function wrap1(v, lo, hi)
  local range = hi - lo + 1
  return lo + (v - lo) % range
end

function HiScoreReg:moveCursor(dc, dr)
  repeat
    if dc ~= 0 then
      self.cursorCol = wrap1(self.cursorCol + dc, 1, KEY_COLS)
    end
    if dr ~= 0 then
      self.cursorRow = wrap1(self.cursorRow + dr, 1, KEY_ROWS)
    end
  until self:getActiveKey() ~= ""
end

-- ─── update ───────────────────────────────────────────────────────────────────
function HiScoreReg:update(dt)
  local dc, dr = 0, 0
  if _keyPressed["left"]  then dc = dc - 1 end
  if _keyPressed["right"] then dc = dc + 1 end
  if _keyPressed["up"]    then dr = dr - 1 end  -- up key = move up = lower row index
  if _keyPressed["down"]  then dr = dr + 1 end

  -- Check gamepad dpad input (first connected joystick)
  local joysticks = love.joystick.getJoysticks()
  if joysticks and #joysticks > 0 then
    local js = joysticks[1]
    if js:isGamepadDown("dpleft") then dc = dc - 1 end
    if js:isGamepadDown("dpright") then dc = dc + 1 end
    if js:isGamepadDown("dpup") then dr = dr - 1 end
    if js:isGamepadDown("dpdown") then dr = dr + 1 end
  end

  if dc ~= 0 or dr ~= 0 then
    self:moveCursor(dc, dr)
  end

  if _keyPressed["space"] then
    local key = self:getActiveKey()
    if key == "RUB" then
      if not self:namePopBack() then
        Audio.play("fastinvader1")
      end
    elseif key == "END" then
      if not self:isNameFull() then
        Audio.play("fastinvader1")
      else
        local name = table.concat(self.nameBuffer)
        self.si.playerName = name
        self.si:switchState("hiscore_board")
      end
    else
      if not self:namePushBack(key:sub(1,1)) then
        Audio.play("fastinvader1")
      end
    end
  end
end

-- ─── draw ─────────────────────────────────────────────────────────────────────
function HiScoreReg:draw()
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)

  local font = self.si.font

  -- Draw keypad
  for row = 1, KEY_ROWS do
    for col = 1, KEY_COLS do
      local key = keyLayout[row][col]
      if key ~= "" then
        local kx = self.padX + (col-1) * self.cellW
        -- Row 1 at padY (top in bottom-up coords), row 2 below, etc.
        local ky = self.padY - (row-1) * self.cellH

        local r, g, b = 0, 1, 1  -- cyan
        if key == "RUB" or key == "END" then r,g,b = 1,0,1 end  -- magenta

        font:draw(key, kx, ky, r, g, b)
      end
    end
  end

  -- Draw cursor under active key
  local ck = self:getActiveKey()
  local cx = self.padX + (self.cursorCol-1) * self.cellW
  local cy = self.padY - (self.cursorRow-1) * self.cellH - CURSOR_DROP
  -- Offset cursor for RUB/END keys (put it after first character)
  if ck == "RUB" or ck == "END" then
    cx = cx + font.size + font.glyphSpace
  end
  font:draw("_", cx, cy, 0, 1, 0)

  -- Draw name box
  local nameFinal = self:composeNameFinal()
  font:draw(nameFinal, self.nameBoxX, self.nameBoxY, 1, 0, 0)
end

return HiScoreReg
