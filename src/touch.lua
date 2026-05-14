-- touch.lua: on-screen virtual controls for web/mobile
-- Layout: D-pad (left), Fire button (right)
-- Detection: native Android/iOS uses touch events; mobile web detected via
-- love.touchpressed firing first, then mouse events drive the buttons.

local Touch = {}

local _held    = {}
local _pressed = {}
local _map     = {}
local _font    = nil

local _os        = love.system.getOS()
local _isWeb     = (_os == "Web")
local _isMobile  = (_os == "Android" or _os == "iOS")
local _touchSeen = false
local _state     = ""

local function visible() return _isMobile or _touchSeen end

function Touch.setState(name) _state = name or "" end

-- Layout constants
local DSZ = 60   -- d-pad button size
local FSZ = 90   -- fire button size
local GAP = 6    -- gap between d-pad buttons
local M   = 24   -- screen margin

-- D-pad centre in screen coords (computed at draw time from sw, sh)
-- cx = M + DSZ + GAP + DSZ/2
-- cy = sh - M - DSZ - GAP - DSZ/2

local function dpadCentre(sh)
  local cx = M + DSZ + GAP + DSZ/2
  local cy = sh - M - DSZ - GAP - DSZ/2
  return cx, cy
end

-- Button definitions: pos returns top-left (x, y), sz is width/height
local BTNS = {
  {
    id   = "up",
    text = "^",
    keys = { "up" },
    held = false,
    sz   = DSZ,
    pos  = function(sw, sh)
      local cx, cy = dpadCentre(sh)
      return cx - DSZ/2, cy - DSZ/2 - DSZ - GAP
    end,
  },
  {
    id   = "down",
    text = "v",
    keys = { "down" },
    held = false,
    sz   = DSZ,
    pos  = function(sw, sh)
      local cx, cy = dpadCentre(sh)
      return cx - DSZ/2, cy - DSZ/2 + DSZ + GAP
    end,
  },
  {
    id   = "left",
    text = "<",
    keys = { "left" },
    held = true,
    sz   = DSZ,
    pos  = function(sw, sh)
      local cx, cy = dpadCentre(sh)
      return cx - DSZ/2 - DSZ - GAP, cy - DSZ/2
    end,
  },
  {
    id   = "right",
    text = ">",
    keys = { "right" },
    held = true,
    sz   = DSZ,
    pos  = function(sw, sh)
      local cx, cy = dpadCentre(sh)
      return cx - DSZ/2 + DSZ + GAP, cy - DSZ/2
    end,
  },
  {
    id   = "fire",
    text = "FIRE",
    keys = { "space", "return" },
    held = false,
    sz   = FSZ,
    pos  = function(sw, sh)
      return sw - M - FSZ, sh - M - FSZ
    end,
  },
}

local function findBtn(x, y)
  local sw, sh = love.graphics.getDimensions()
  for _, btn in ipairs(BTNS) do
    local bx, by = btn.pos(sw, sh)
    local sz = btn.sz
    if x >= bx and x <= bx + sz and y >= by and y <= by + sz then
      return btn.id
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
  local p = _pressed; _pressed = {}; return p
end

function Touch.isDown(key) return _held[key] == true end

function Touch.draw()
  if not visible() then return end
  local sw, sh = love.graphics.getDimensions()
  if not _font then _font = love.graphics.newFont(20) end

  love.graphics.push()
  love.graphics.origin()
  love.graphics.setFont(_font)

  -- Draw d-pad centre decoration
  local cx, cy = dpadCentre(sh)
  love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
  love.graphics.rectangle("fill", cx - DSZ/2, cy - DSZ/2, DSZ, DSZ, 6, 6)

  -- Draw buttons
  for _, btn in ipairs(BTNS) do
    local bx, by = btn.pos(sw, sh)
    local sz     = btn.sz
    local active = btn.held and _held[btn.keys[1]]
    local isFire = btn.id == "fire"

    love.graphics.setColor(active and 1 or 0.15, active and 1 or 0.15, active and 1 or 0.15, 0.55)
    if isFire then
      love.graphics.circle("fill", bx + sz/2, by + sz/2, sz/2)
    else
      love.graphics.rectangle("fill", bx, by, sz, sz, 8, 8)
    end

    love.graphics.setColor(0.9, 0.9, 0.9, 0.75)
    love.graphics.setLineWidth(2)
    if isFire then
      love.graphics.circle("line", bx + sz/2, by + sz/2, sz/2)
    else
      love.graphics.rectangle("line", bx, by, sz, sz, 8, 8)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(btn.text, bx, by + sz/2 - 10, sz, "center")
  end

  love.graphics.pop()
end

return Touch
