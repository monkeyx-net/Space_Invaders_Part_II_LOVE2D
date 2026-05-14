-- font.lua: load and draw custom pixel font from assets/fonts/<name>/
-- .font file: lineSpace, wordSpace, glyphSpace, size (key=value pairs)
-- .glyph file: asciiCode, offsetX, offsetY, advance, width, height
-- Glyph bitmaps are stored as .bitmap files alongside the .glyph files.

local Bitmap = require("bitmap")

local Font = {}
Font.__index = Font

local cache = {}   -- name -> Font object

local function parseKeyValue(data)
  local t = {}
  for line in (data.."\n"):gmatch("([^\n]*)\n") do
    local k, v = line:match("^%s*(%w+)%s*=%s*(%S+)")
    if k then t[k] = tonumber(v) or v end
  end
  return t
end

function Font.load(name)
  if cache[name] then return cache[name] end

  local basepath = "assets/fonts/" .. name .. "/"
  local fontpath  = basepath .. name .. ".font"

  local fontdata, _ = love.filesystem.read(fontpath)
  local meta = fontdata and parseKeyValue(fontdata) or {}
  local lineSpace  = meta.lineSpace  or 12
  local wordSpace  = meta.wordSpace  or 5
  local glyphSpace = meta.glyphSpace or 2
  local size       = meta.size       or 8

  -- glyphFilenames mirrors the C++ pixiretro.h array (94 entries, ASCII 33..126)
  local glyphFilenames = {
    "emark","dquote","hash","dollar","percent","ampersand","squote","lrbracket","rrbracket",
    "asterix","plus","comma","minus","dot","fslash",
    "0","1","2","3","4","5","6","7","8","9",
    "colon","scolon","lcroc","equals","rcroc","qmark","at",
    "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
    "lsbracket","bslash","rsbracket","carrot","underscore","backtick",
    "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
    "lcbracket","pipe","rcbracket","tilde"
  }

  local glyphs = {}   -- indexed 33..126
  for i, fname in ipairs(glyphFilenames) do
    local ascii = 32 + i
    local glyphpath = basepath .. fname .. ".glyph"
    local gdata, _ = love.filesystem.read(glyphpath)
    local gm = gdata and parseKeyValue(gdata) or {}

    local bmp = _loadGlyphBitmap(basepath, fname)

    glyphs[ascii] = {
      asciiCode = ascii,
      offsetX   = (gm.offsetX or 0),
      offsetY   = (gm.offsetY or 0),
      advance   = (gm.advance or size),
      w         = (gm.width  or size),
      h         = (gm.height or size),
      bitmap    = bmp,
    }
  end

  local f = setmetatable({}, Font)
  f.lineSpace  = lineSpace
  f.wordSpace  = wordSpace
  f.glyphSpace = glyphSpace
  f.size       = size
  f.glyphs     = glyphs
  cache[name] = f
  return f
end

-- Load a glyph bitmap from the font's own directory (not assets/bitmaps/)
function _loadGlyphBitmap(basepath, fname)
  local path = basepath .. fname .. ".bitmap"
  local data, _ = love.filesystem.read(path)
  if not data then
    -- fallback: small error block
    local imgdata = love.image.newImageData(4, 4)
    for y=0,3 do for x=0,3 do imgdata:setPixel(x,y,1,0,0,1) end end
    local b = {}
    b.imgdata = imgdata
    b.image   = love.graphics.newImage(imgdata)
    b.w = 4; b.h = 4
    setmetatable(b, require("bitmap"))
    return b
  end

  local rows = {}
  for line in (data.."\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("%s","")
    if #line > 0 then rows[#rows+1] = line end
  end

  -- Strip trailing zeros
  for i, row in ipairs(rows) do
    local j = #row
    while j > 1 and row:sub(j,j) == "0" do j = j-1 end
    rows[i] = row:sub(1,j)
  end

  local h = #rows
  local w = 0
  for _, row in ipairs(rows) do w = math.max(w, #row) end
  if w == 0 or h == 0 then w = 4; h = 4 end

  local imgdata = love.image.newImageData(w, h)
  for iy, row in ipairs(rows) do
    for ix = 1, w do
      local ch = row:sub(ix, ix)
      if ch == "1" then
        imgdata:setPixel(ix-1, iy-1, 1, 1, 1, 1)
      else
        imgdata:setPixel(ix-1, iy-1, 0, 0, 0, 0)
      end
    end
  end

  local Bitmap = require("bitmap")
  local b = setmetatable({}, Bitmap)
  b.imgdata = imgdata
  b.image   = love.graphics.newImage(imgdata)
  b.w = w; b.h = h
  return b
end

-- Calculate the pixel width of a string
function Font:stringWidth(text)
  local w = 0
  for i = 1, #text do
    local ch = text:sub(i,i)
    if ch == " " then
      w = w + self.wordSpace
    else
      local ascii = ch:byte()
      local g = self.glyphs[ascii]
      if g then
        w = w + g.advance + self.glyphSpace
      end
    end
  end
  return w
end

-- Draw text at game (bottom-up) position (posX, posY).
-- posY is the baseline (bottom of glyphs with offsetY=0).
function Font:draw(text, posX, posY, r, g, b)
  love.graphics.setColor(r, g, b, 1)
  local curX = posX
  for i = 1, #text do
    local ch = text:sub(i,i)
    if ch == " " then
      curX = curX + self.wordSpace
    else
      local ascii = ch:byte()
      local glyph = self.glyphs[ascii]
      if glyph and glyph.bitmap then
        local bx = curX + glyph.offsetX
        local by = posY + glyph.offsetY
        glyph.bitmap:draw(bx, by)
        curX = curX + glyph.advance + self.glyphSpace
      end
    end
  end
end

return Font
