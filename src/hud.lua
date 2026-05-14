-- hud.lua: HUD label system (text labels, int labels, bitmap labels)
-- Mirrors the C++ HUD class.  Labels have positions in game (bottom-up) coords.

local HUD = {}
HUD.__index = HUD

local FLASH_PERIOD = 0.1   -- seconds per flash toggle
local PHASE_PERIOD = 0.1   -- seconds per character phase-in

function HUD.new(font)
  local h = setmetatable({}, HUD)
  h.font        = font
  h.labels      = {}    -- uid -> label
  h.nextUid     = 1
  h.visible     = true
  h.flashClock  = 0
  h.flashState  = true
  return h
end

-- label types
local TYPE_TEXT   = 1
local TYPE_INT    = 2
local TYPE_BITMAP = 3

-- Add a text label. Returns uid.
-- flashDelay > 0 means start flashing after that many seconds. phaseIn=true phases characters in.
function HUD:addText(x, y, r, g, b, text, flashDelay, phaseIn)
  local uid = self.nextUid; self.nextUid = self.nextUid + 1
  self.labels[uid] = {
    type       = TYPE_TEXT,
    x=x, y=y, r=r, g=g, b=b,
    text       = text,
    flashDelay = flashDelay or 0,
    flashClock = 0,
    flashing   = false,
    phaseIn    = phaseIn or false,
    phaseClock = 0,
    phaseChars = phaseIn and 0 or #text,
    hidden     = false,
  }
  return uid
end

-- Add an integer label (pointer via getter function). Returns uid.
function HUD:addInt(x, y, r, g, b, getter, digits)
  local uid = self.nextUid; self.nextUid = self.nextUid + 1
  self.labels[uid] = {
    type     = TYPE_INT,
    x=x, y=y, r=r, g=g, b=b,
    getter   = getter,
    digits   = digits or 5,
    flashing = false,
    hidden   = false,
  }
  return uid
end

-- Add a bitmap label. bmp is a Bitmap object. Returns uid.
function HUD:addBitmap(x, y, r, g, b, bmp)
  local uid = self.nextUid; self.nextUid = self.nextUid + 1
  self.labels[uid] = {
    type   = TYPE_BITMAP,
    x=x, y=y, r=r, g=g, b=b,
    bmp    = bmp,
    hidden = false,
  }
  return uid
end

function HUD:remove(uid)
  self.labels[uid] = nil
end

function HUD:show() self.visible = true  end
function HUD:hide() self.visible = false end

function HUD:showLabel(uid)
  if self.labels[uid] then self.labels[uid].hidden = false end
end

function HUD:hideLabel(uid)
  if self.labels[uid] then self.labels[uid].hidden = true end
end

function HUD:startFlash(uid)
  if self.labels[uid] then self.labels[uid].flashing = true end
end

function HUD:stopFlash(uid)
  if self.labels[uid] then self.labels[uid].flashing = false end
end

-- Update flash/phase timers
function HUD:update(dt)
  self.flashClock = self.flashClock + dt
  if self.flashClock >= FLASH_PERIOD then
    self.flashClock = self.flashClock - FLASH_PERIOD
    self.flashState = not self.flashState
  end

  for _, lbl in pairs(self.labels) do
    if lbl.type == TYPE_TEXT then
      -- Flash delay countdown
      if lbl.flashDelay > 0 then
        lbl.flashClock = lbl.flashClock + dt
        if lbl.flashClock >= lbl.flashDelay then
          lbl.flashDelay = 0
          lbl.flashing   = true
        end
      end
      -- Phase-in
      if lbl.phaseIn and lbl.phaseChars < #lbl.text then
        lbl.phaseClock = lbl.phaseClock + dt
        while lbl.phaseClock >= PHASE_PERIOD and lbl.phaseChars < #lbl.text do
          lbl.phaseClock = lbl.phaseClock - PHASE_PERIOD
          lbl.phaseChars = lbl.phaseChars + 1
        end
      end
    end
  end
end

-- Draw all visible labels
function HUD:draw()
  if not self.visible then return end
  for _, lbl in pairs(self.labels) do
    if lbl.hidden then goto continue end
    if lbl.flashing and not self.flashState then goto continue end

    if lbl.type == TYPE_TEXT then
      local text = lbl.text:sub(1, lbl.phaseChars)
      self.font:draw(text, lbl.x, lbl.y, lbl.r, lbl.g, lbl.b)

    elseif lbl.type == TYPE_INT then
      local val  = lbl.getter()
      local text = tostring(val)
      self.font:draw(text, lbl.x, lbl.y, lbl.r, lbl.g, lbl.b)

    elseif lbl.type == TYPE_BITMAP then
      love.graphics.setColor(lbl.r, lbl.g, lbl.b, 1)
      lbl.bmp:draw(lbl.x, lbl.y)
    end
    ::continue::
  end
end

return HUD
