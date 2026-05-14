-- touch.lua: on-screen virtual controls for web/mobile
-- Detection strategy:
--   Native Android/iOS : love.touchpressed fires → _isMobile true, use touch events
--   Mobile web         : love.touchpressed fires first, then love.mousepressed
--                        → _touchSeen set on first touch, then mouse events drive buttons
--   Desktop web/native : only mouse fires, love.touchpressed never called → hidden

local Touch = {}

local _held    = {}  -- key -> bool: finger currently on button
local _pressed = {}  -- key -> bool: tapped this frame, cleared by flush()
local _map     = {}  -- id -> button id
local _font    = nil -- lazy-loaded

local _os        = love.system.getOS()
local _isWeb     = (_os == "Web")
local _isMobile  = (_os == "Android" or _os == "iOS")
local _touchSeen = false  -- true once any touch event fires (mobile web detection)
local _state     = ""

local function visible()
  return _isMobile or _touchSeen
end

function Touch.setState(name)
  _state = name or ""
end

-- Button layout: LEFT RIGHT FIRE grouped and centered at bottom
local BSZ = 72   -- button size
local SSZ = 54   -- small button size (up/down)
local GAP = 10   -- gap between buttons
local M   = 24   -- bottom margin

local GRP = BSZ * 3 + GAP * 2  -- total width of main group

local BTNS = {
  {
    id   = "left",
    text = "<",
    keys = { "left" },
    held = true,
    sz   = BSZ,
    pos  = function(sw, sh) return sw/2 - GRP/2,                   sh - BSZ - M end,
  },
  {
    id   = "right",
    text = ">",
    keys = { "right" },
    held = true,
    sz   = BSZ,
    pos  = function(sw, sh) return sw/2 - GRP/2 + BSZ + GAP,       sh - BSZ - M end,
  },
  {
    id   = "fire",
    text = "FIRE",
    keys = { "space", "return" },
    held = false,
    sz   = BSZ,
    pos  = function(sw, sh) return sw/2 - GRP/2 + BSZ*2 + GAP*2,   sh - BSZ - M end,
  },
  {
    id    = "up",
    text  = "^",
    keys  = { "up" },
    held  = false,
    sz    = SSZ,
    state = "hiscore_reg",
    pos   = function(sw, sh) return sw/2 - SSZ - GAP/2, sh - BSZ - M - SSZ - GAP end,
  },
  {
    id    = "down",
    text  = "v",
    keys  = { "down" },
    held  = false,
    sz    = SSZ,
    state = "hiscore_reg",
    pos   = function(sw, sh) return sw/2 + GAP/2,       sh - BSZ - M - SSZ - GAP end,
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
      local sz = btn.sz
      if x >= bx and x <= bx + sz and y >= by and y <= by + sz then
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
  if not btn or not btn.held then return end
  for _, k in ipairs(btn.keys) do _held[k] = false end
end

local function processPress(id, x, y)
  local bid = findBtn(x, y)
  if bid then _map[id] = bid; pressBtn(bid) end
end

local function processMoved(id, x, y)
  local prev = _map[id]
  local cur  = findBtn(x, y)
  if prev ~= cur then
    if prev then releaseBtn(prev) end
    if cur  then pressBtn(cur); _map[id] = cur
    else         _map[id] = nil end
  end
end

local function processRelease(id)
  local bid = _map[id]
  if bid then releaseBtn(bid); _map[id] = nil end
end

-- Native touch events (Android/iOS; also fires on mobile web alongside mouse)
function Touch.touchpressed(id, x, y)
  _touchSeen = true
  if not _isWeb then processPress(id, x, y) end
end

function Touch.touchmoved(id, x, y)
  if not _isWeb then processMoved(id, x, y) end
end

function Touch.touchreleased(id, x, y)
  if not _isWeb then processRelease(id) end
end

-- Mouse events: used on web (love.js routes touch through mouse) and native mobile
function Touch.mousepressed(x, y, btn)
  if btn ~= 1 then return end
  if _isMobile or (_isWeb and _touchSeen) then processPress("mouse", x, y) end
end

function Touch.mousemoved(x, y)
  if _isMobile or (_isWeb and _touchSeen) then processMoved("mouse", x, y) end
end

function Touch.mousereleased(x, y, btn)
  if btn ~= 1 then return end
  if _isMobile or (_isWeb and _touchSeen) then processRelease("mouse") end
end

function Touch.flush()
  local p = _pressed
  _pressed = {}
  return p
end

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
      local sz     = btn.sz
      local active = btn.held and _held[btn.keys[1]]

      love.graphics.setColor(active and 1 or 0.15, active and 1 or 0.15, active and 1 or 0.15, 0.55)
      love.graphics.rectangle("fill", bx, by, sz, sz, 10, 10)

      love.graphics.setColor(0.9, 0.9, 0.9, 0.75)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", bx, by, sz, sz, 10, 10)

      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.printf(btn.text, bx, by + sz/2 - 10, sz, "center")
    end
  end

  love.graphics.pop()
end

return Touch
