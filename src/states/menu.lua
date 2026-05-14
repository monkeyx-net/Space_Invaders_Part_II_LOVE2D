-- states/menu.lua: menu screen with score advance table.
-- Mirrors C++ MenuState.
-- World coords: 448×256, Y=0 at bottom.

local Bitmap = require("bitmap")

local Menu = {}
Menu.__index = Menu

-- HUD positions use xOffset=112 so the content is centred in the 448-wide world
-- (original C++ positions were for a 224-wide world; 112 = (448-224)/2).
local XO = 112   -- x offset

function Menu.new(si)
  local m = setmetatable({}, Menu)
  m.si = si
  m.uids = {}
  return m
end

function Menu:enter()
  local si = self.si
  self:populateHud()
  si:showHud()
  si:hideLivesHud()
  si:showTopHud()
  si:resetGameStats()
end

function Menu:leave()
  self:depopulateHud()
  self.si:hideHud()
end

function Menu:populateHud()
  local si   = self.si
  local hud  = si.hud
  local bmps = {}
  local u    = self.uids

  -- Load bitmaps (cached by Bitmap.load)
  bmps.menu      = Bitmap.load("menu")
  bmps.controls  = Bitmap.load("controls")
  bmps.schro     = Bitmap.load("schrodinger")
  bmps.saucer    = Bitmap.load("saucer")
  bmps.squid     = Bitmap.load("squid0")
  bmps.cuttle    = Bitmap.load("cuttle0")
  bmps.crab      = Bitmap.load("crab0")
  bmps.octopus   = Bitmap.load("octopus0")

  -- Text labels
  u.menuText    = hud:addText(XO+91, 204, 0,1,1, "*MENU*")
  u.ctrlText    = hud:addText(XO+76, 162, 0,1,1, "*CONTROLS*")
  u.tableText   = hud:addText(XO+40, 108, 0,1,1, "*SCORE ADVANCE TABLE*")
  -- Phase-in text labels (flashDelay=seconds before flashing, phaseIn=true)
  u.pts500      = hud:addText(XO+82, 90, 1,0,1, "= 500 POINTS",  0, true)
  u.ptsMystery  = hud:addText(XO+82, 74, 1,0,1, "= ? MYSTERY",   1, true)
  u.pts30       = hud:addText(XO+82, 58, 1,1,0, "= 30 POINTS",   2, true)
  u.pts20       = hud:addText(XO+82, 42, 1,1,0, "= 20 POINTS",   3, true)
  u.pts10       = hud:addText(XO+82, 26, 1,0,0, "= 10 POINTS",   4, true)

  -- Bitmap labels
  u.menuBmp    = hud:addBitmap(XO+56, 182, 1,1,1, bmps.menu)
  u.ctrlBmp    = hud:addBitmap(XO+58, 134, 1,1,1, bmps.controls)
  u.schroBmp   = hud:addBitmap(XO+62,  90, 1,0,1, bmps.schro)
  u.saucerBmp  = hud:addBitmap(XO+62,  74, 1,0,1, bmps.saucer)
  u.squidBmp   = hud:addBitmap(XO+66,  58, 1,1,0, bmps.squid)
  u.cuttleBmp  = hud:addBitmap(XO+52,  58, 1,1,0, bmps.cuttle)
  u.crabBmp    = hud:addBitmap(XO+64,  42, 1,1,0, bmps.crab)
  u.octopusBmp = hud:addBitmap(XO+64,  26, 1,0,0, bmps.octopus)
end

function Menu:depopulateHud()
  local hud = self.si.hud
  for _, uid in pairs(self.uids) do
    hud:remove(uid)
  end
  self.uids = {}
end

function Menu:update(dt)
  if _keyPressed["return"] or _keyPressed["kpenter"] then
    self.si:switchState("game")

  elseif _keyPressed["s"] then
    self.si:switchState("hiscore_board")
  end
end

function Menu:draw()
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)
end

return Menu
