-- collision.lua: AABB + pixel-perfect collision detection
-- Positions are in game (bottom-up) world coords.
-- Bitmaps have y=0 at top internally (imgdata), so we must flip when indexing pixels.

local Collision = {}

-- Test collision between two bitmap objects at their game positions.
-- Returns: isCollision, aPixels, bPixels, aOverlap, bOverlap
-- aPixels/bPixels are lists of {col, row} in each bitmap's local (imgdata) coordinates.
-- If pixelLists==false, stops after finding first colliding pixel pair.
function Collision.test(ax, ay, aBmp, bx, by, bBmp, pixelLists)
  -- AABB in game coords (bottom-up Y, y=bottom edge of sprite)
  -- round inputs to integer pixel positions so that collisions agree
-- with rendering (which snaps to whole pixels).  leaving floats around
-- can make hits occur a pixel early/late as the cannon moves;
-- rounding ensures the bounding boxes are computed on the same grid as
-- the bitmaps.
  ax = math.floor(ax + 0.5); ay = math.floor(ay + 0.5)
  bx = math.floor(bx + 0.5); by = math.floor(by + 0.5)

  local axmin, aymin = ax,          ay
  local axmax, aymax = ax + aBmp.w, ay + aBmp.h
  local bxmin, bymin = bx,          by
  local bxmax, bymax = bx + bBmp.w, by + bBmp.h

  -- AABB intersection (exclusive on edges).  note that pixel coordinates
  -- are integer and stamping on a boundary should count as contact;
  -- we keep the original <= tests because the rounding above already
  -- prevents off-by-one when a sprite is exactly adjacent.
  if axmax <= bxmin or bxmax <= axmin or aymax <= bymin or bymax <= aymin then
    return false, nil, nil, nil, nil
  end

  -- Overlap in game coords (float results converted to ints when used):
  local oxmin = math.max(axmin, bxmin)
  local oxmax = math.min(axmax, bxmax)
  local oymin = math.max(aymin, bymin)
  local oymax = math.min(aymax, bymax)

  -- Overlaps in each bitmap's local imgdata coords.
  -- Game Y is bottom-up, imgdata Y is top-down (row 0 = top of bitmap).
  -- game_y -> imgdata_row = (bitmapH - 1) - (game_y - sprite_bottom_y)
  -- But we work with ranges: the overlap bottom in game = oymin, top in game = oymax.
  -- For bitmap A: row in imgdata = (aBmp.h - 1) - (game_y - aymin)
  --   overlap game_y range: [oymin, oymax)
  --   imgdata rows: [(aBmp.h-1)-(oymax-1-aymin), (aBmp.h-1)-(oymin-aymin)]
  --               = [aBmp.h-1-oymax+1+aymin, aBmp.h-1-oymin+aymin]
  --               = [aBmp.h+aymin-oymax, aBmp.h-1+aymin-oymin]
  -- Let's just iterate directly:

  local aPixels, bPixels = {}, {}
  local isCollision = false

  -- convert overlap extents to integer counts (floor) so loops run the
  -- expected number of iterations even when positions were rounded above.
  local overlapW = math.floor(oxmax - oxmin)
  local overlapH = math.floor(oymax - oymin)

  for drow = 0, overlapH - 1 do
    -- game Y of this row's bottom: oymin + drow
    local gameY = oymin + drow

    -- compute bitmap rows, rounding to integers as the formula may produce
    -- floats when aymin or oymin were fractional before rounding above.
    local aRow = math.floor((aBmp.h - 1) - (gameY - aymin) + 0.5)
    local bRow = math.floor((bBmp.h - 1) - (gameY - bymin) + 0.5)

    for dcol = 0, overlapW - 1 do
      local gameX = oxmin + dcol
      local aCol  = math.floor(gameX - axmin + 0.5)
      local bCol  = math.floor(gameX - bxmin + 0.5)

      local aSet = aBmp:getPixel(aRow, aCol)
      local bSet = bBmp:getPixel(bRow, bCol)

      if aSet and bSet then
        isCollision = true
        if pixelLists then
          aPixels[#aPixels+1] = {col = aCol, row = aRow}
          bPixels[#bPixels+1] = {col = bCol, row = bRow}
        else
          -- Return overlap info for bunker damage
          return true, {{col=aCol,row=aRow}}, {{col=bCol,row=bRow}},
                 {xmin=oxmin-axmin, ymin=oymin-aymin, xmax=oxmax-axmin, ymax=oymax-aymin},
                 {xmin=oxmin-bxmin, ymin=oymin-bymin, xmax=oxmax-bxmin, ymax=oymax-bymin}
        end
      end
    end
  end

  if not isCollision then
    return false, nil, nil, nil, nil
  end

  return true, aPixels, bPixels,
         {xmin=oxmin-axmin, ymin=oymin-aymin, xmax=oxmax-axmin, ymax=oymax-aymin},
         {xmin=oxmin-bxmin, ymin=oymin-bymin, xmax=oxmax-bxmin, ymax=oymax-bymin}
end

return Collision
