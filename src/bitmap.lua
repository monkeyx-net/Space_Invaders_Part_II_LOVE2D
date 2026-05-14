-- bitmap.lua: load and draw .bitmap assets (text files of 0/1 rows, top-to-bottom)
-- In Love2D Y=0 is at top.  Game logic uses bottom-up Y like the original OpenGL code.
-- drawBitmap() converts: loveY = WORLD_H - posY - bitmapH

local Bitmap = {}
Bitmap.__index = Bitmap

local cache = {}   -- name -> Bitmap object

-- Parse a .bitmap text file and create an image (white pixels = on, transparent = off)
function Bitmap.load(name)
  if cache[name] then return cache[name] end

  local path = "assets/bitmaps/" .. name .. ".bitmap"
  local data, err = love.filesystem.read(path)
  if not data then
    -- Fallback: tiny error block
    local imgdata = love.image.newImageData(4, 4)
    for y = 0, 3 do for x = 0, 3 do imgdata:setPixel(x, y, 1, 0, 0, 1) end end
    local b = setmetatable({}, Bitmap)
    b.imgdata = imgdata
    b.image   = love.graphics.newImage(imgdata)
    b.w       = 4
    b.h       = 4
    cache[name] = b
    return b
  end

  local rows = {}
  for line in (data .. "\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("%s", "")
    if #line > 0 then rows[#rows+1] = line end
  end

  -- Strip trailing '0's per row (keep at least one char)
  for i, row in ipairs(rows) do
    local j = #row
    while j > 1 and row:sub(j,j) == "0" do j = j - 1 end
    rows[i] = row:sub(1, j)
  end

  local h = #rows
  local w = 0
  for _, row in ipairs(rows) do w = math.max(w, #row) end
  if w == 0 or h == 0 then w = 4; h = 4 end

  local imgdata = love.image.newImageData(w, h)
  -- File rows are top-to-bottom; Love2D ImageData y=0 is top -> correct order, no reversal
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

  local b = setmetatable({}, Bitmap)
  b.imgdata = imgdata
  b.image   = love.graphics.newImage(imgdata)
  b.w       = w
  b.h       = h
  cache[name] = b
  return b
end

-- Make a solid white block bitmap of given pixel size (not file-backed)
function Bitmap.makeBlock(w, h)
  local imgdata = love.image.newImageData(w, h)
  for y = 0, h-1 do
    for x = 0, w-1 do imgdata:setPixel(x, y, 1, 1, 1, 1) end
  end
  local b = setmetatable({}, Bitmap)
  b.imgdata = imgdata
  b.image   = love.graphics.newImage(imgdata)
  b.w       = w
  b.h       = h
  return b
end

-- Clone a bitmap's pixel data so it can be modified independently (for bunkers / hitbar)
function Bitmap.clone(src)
  local imgdata = src.imgdata:clone()
  local b = setmetatable({}, Bitmap)
  b.imgdata = imgdata
  b.image   = love.graphics.newImage(imgdata)
  b.w       = src.w
  b.h       = src.h
  return b
end

-- Regenerate the GPU image after modifying imgdata
function Bitmap:refresh()
  self.image = love.graphics.newImage(self.imgdata)
end

-- Set/clear a pixel (row/col in imgdata coordinates: row 0 = top)
function Bitmap:setPixel(row, col, val)
  if col < 0 or col >= self.w or row < 0 or row >= self.h then return end
  if val then
    self.imgdata:setPixel(col, row, 1, 1, 1, 1)
  else
    self.imgdata:setPixel(col, row, 0, 0, 0, 0)
  end
end

function Bitmap:getPixel(row, col)
  if col < 0 or col >= self.w or row < 0 or row >= self.h then return false end
  local r,g,b,a = self.imgdata:getPixel(col, row)
  return a > 0.5
end

-- Clear a rect of pixels
function Bitmap:clearRect(rowMin, colMin, rowMax, colMax)
  for row = rowMin, rowMax do
    for col = colMin, colMax do
      if col >= 0 and col < self.w and row >= 0 and row < self.h then
        self.imgdata:setPixel(col, row, 0, 0, 0, 0)
      end
    end
  end
end

-- Count set pixels (for bunker delete threshold)
function Bitmap:countPixels()
  local count = 0
  for row = 0, self.h-1 do
    for col = 0, self.w-1 do
      local _,_,_,a = self.imgdata:getPixel(col, row)
      if a > 0.5 then count = count + 1 end
    end
  end
  return count
end

-- Draw the bitmap using the current love.graphics colour.
-- posX, posY are in game (bottom-up) world coords.
-- WORLD_H must be set as a global (448x256 world, WORLD_H=256).
function Bitmap:draw(posX, posY)
  -- Convert bottom-up Y to Love2D top-down Y
  local loveY = WORLD_H - posY - self.h
  love.graphics.draw(self.image, math.floor(posX + 0.5), math.floor(loveY + 0.5))
end

return Bitmap
