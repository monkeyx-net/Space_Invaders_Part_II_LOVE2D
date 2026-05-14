-- touch.lua: on-screen virtual controls for web/mobile
-- Buttons are rendered in screen space (outside game world transform).
-- Held buttons (left/right) feed Touch.isDown() for continuous cannon movement.
-- Tap buttons (fire) inject into _keyPressed via Touch.flush() each frame.

local Touch = {}

local _held    = {}  -- key -> bool: finger currently on button
local _pressed = {}  -- key -> bool: tapped this frame, cleared by flush()
local _map     = {}  -- touch/mouse id -> button id
local _font    = nil -- created lazily on first draw

-- Show controls on native mobile, or on web once a real touch is detected
local _os        = love.system.getOS()
local _isMobile  = (_os == "Android" or _os == "iOS")
local _touchSeen = false  -- set true on first touch event on web
local _state     = ""     -- current game state name

local function visible()
  return _isMobile or _touchSeen
end

function Touch.setState(name)
  _state = name or ""
end

local M   = 20  -- screen margin (px)
local BSZ = 80  -- button size (px)

-- pos(sw, sh) returns top-left x, y in screen coords
local BTNS = {
  {
    id   = "left",
    text = "<",
    keys = { "left" },
    held = true,
    pos  = function(sw, sh) return M, sh - BSZ - M end,
  },
  {
    id   = "right",
    text = ">",
    keys = { "right" },
    held = true,
    pos  = function(sw, sh) return sw - BSZ - M, sh - BSZ - M end,
  },
  {
    id   = "fire",
    text = "FIRE",
    keys = { "space", "return" },
    held = false,
    pos  = function(sw, sh) return sw / 2 - BSZ / 2, sh - BSZ - M end,
  },
  {
    id    = "up",
    text  = "^",
    keys  = { "up" },
    held  = false,
    state = "hiscore_reg",
    pos   = function(sw, sh) return M * 3 + BSZ, sh - BSZ * 2 - M * 2 end,
  },
  {
    id    = "down",
    text  = "v",
    keys  = { "down" },
    held  = false,
    state = "hiscore_reg",
    pos   = function(sw, sh) return M * 3 + BSZ, sh - BSZ - M end,
  },
}

local function btnActive(btn)
  return not btn.state or btn.state == _state
end

local function findBtn(x, y)
  local sw, sh = love.graphics.getDimensions()
  for _, btn in ipairs(BTNS) do
    if btnActive(btn) then
      local bx, by = btn.pos(sw, sh)
      if x >= bx and x <= bx + BSZ and y >= by and y <= by + BSZ then
        return btn.id
      end
    end
  end
end

local function getBtnById(id)
  for _, btn in ipairs(BTNS) do
    if btn.id == id then return btn end
  end
end

local function pressBtn(id)
  local btn = getBtnById(id)
  if not btn then return end
  for _, k in ipairs(btn.keys) do
    _pressed[k] = true
    if btn.held then _held[k] = true end
  end
end

local function releaseBtn(id)
  local btn = getBtnById(id)
  if not btn then return end
  if btn.held then
    for _, k in ipairs(btn.keys) do _held[k] = false end
  end
end

function Touch.touchpressed(id, x, y)
  _touchSeen = true
  local bid = findBtn(x, y)
  if bid then _map[id] = bid; pressBtn(bid) end
end

function Touch.touchmoved(id, x, y)
  local prev = _map[id]
  local cur  = findBtn(x, y)
  if prev ~= cur then
    if prev then releaseBtn(prev) end
    if cur  then pressBtn(cur); _map[id] = cur
    else         _map[id] = nil end
  end
end

function Touch.touchreleased(id, x, y)
  local bid = _map[id]
  if bid then releaseBtn(bid); _map[id] = nil end
end

-- Mouse forwarding: only active on mobile OS (on mobile, LOVE fires both
-- touch and mouse events; on desktop we ignore mouse to avoid conflicts)
function Touch.mousepressed(x, y, btn)
  if _isMobile and btn == 1 then Touch.touchpressed("mouse", x, y) end
end

function Touch.mousemoved(x, y)
  if _isMobile then Touch.touchmoved("mouse", x, y) end
end

function Touch.mousereleased(x, y, btn)
  if _isMobile and btn == 1 then Touch.touchreleased("mouse", x, y) end
end

-- Returns this-frame taps and resets them. Call once per update before state:update().
function Touch.flush()
  local p = _pressed
  _pressed = {}
  return p
end

-- Continuous held state for cannon movement polling.
function Touch.isDown(key)
  return _held[key] == true
end

function Touch.draw()
  if not visible() then return end
  local sw, sh = love.graphics.getDimensions()
  if not _font then _font = love.graphics.newFont(20) end

  love.graphics.push()
  love.graphics.origin()
  love.graphics.setFont(_font)

  for _, btn in ipairs(BTNS) do
    if btnActive(btn) then
      local bx, by = btn.pos(sw, sh)
      local active = btn.held and _held[btn.keys[1]]

      love.graphics.setColor(active and 1 or 0.15, active and 1 or 0.15, active and 1 or 0.15, 0.55)
      love.graphics.rectangle("fill", bx, by, BSZ, BSZ, 10, 10)

      love.graphics.setColor(0.9, 0.9, 0.9, 0.75)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", bx, by, BSZ, BSZ, 10, 10)

      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.printf(btn.text, bx, by + BSZ / 2 - 10, BSZ, "center")
    end
  end

  love.graphics.pop()
end

return Touch
