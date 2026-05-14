# Space Invaders Part II (LOVE2D)

A faithful LOVE2D reimplementation of the classic arcade game **Space Invaders Part II** by Taito (1980). This is a remake of the OpenGL/C++ version originally by [ianmurfinxyz](https://github.com/ianmurfinxyz), ported to Lua/LÖVE.

## Overview

The game renders in a virtual world of **448×256** pixels (bottom-up Y-coordinate convention matching the original). The display is scaled to fill the window each frame using `love.graphics.scale()`.

### Gameplay Features

- 5 rows × 11 columns of alien invaders in various formations per round
- 4 destructible bunkers for cover
- UFO / Schrödinger saucer that flies across the top
- Multiple bomb types (cross, zigzag, zagzig) dropped by aliens
- Laser cannon with pixel-perfect collision
- Alien morphing mechanic (Crab → Cuttletwin → Cuttle)
- SOS intermission between rounds (UFO tows an alien, engine may fail)
- Hi-score persistence across sessions

## Controls

| Key                  | Action            |
|----------------------|-------------------|
| ← / → (Arrow keys)   | Move cannon       |
| Space                | Fire laser        |
| Escape               | Quit              |
| S                    | Hi-score board    |
| Enter / KpEnter      | Confirm / Start   |

**Gamepad support** (Xbox-style controller):
- D-Pad left/right: Move cannon
- A, B, X, Y: Fire
- Start: Confirm
- Back: Quit
- LB / RB: Hi-score board

## Project Structure

```
Space_Invaders_Part_II_LOVE2D/
├── README.md
├── LICENSE
└── src/
    ├── main.lua              -- Entry point, globals, state machine, hi-score persistence
    ├── conf.lua              -- LÖVE configuration
    ├── audio.lua             -- Sound effect loading and playback
    ├── bitmap.lua            -- .bitmap text-file parser and renderer
    ├── collision.lua         -- AABB + pixel-perfect collision detection
    ├── font.lua              -- Custom pixel font loader and renderer
    ├── hud.lua               -- HUD label system (text, int, bitmap labels with flash/phase)
    └── states/
        ├── game.lua          -- Main gameplay state (the big one)
        ├── splash.lua        -- Animated title screen with Sign block animation
        ├── menu.lua          -- Menu with score advance table
        ├── sos.lua           -- SOS intermission state
        ├── hiscore_board.lua -- Animated hi-score leaderboard with bubble-up swaps
        └── hiscore_reg.lua   -- Name entry keypad for hi-score registration
```

## Code Review & Performance Improvement Suggestions

Below is a detailed review of the code with actionable performance improvements, ordered by potential impact.

---

### 1. 🔴 High: `Bitmap:refresh()` creates a new GPU texture every call

**File:** `src/bitmap.lua` — function `Bitmap:refresh()`

`love.graphics.newImage(self.imgdata)` creates a brand-new OpenGL texture and uploads it to the GPU. This is called every frame a bunker is damaged (in `doCollisionsBombsHitbar`, `damageBunker`, `doCollisionsBunkersAliens`).

```lua
function Bitmap:refresh()
  self.image = love.graphics.newImage(self.imgdata)  -- expensive!
end
```

**Suggestion:** Replace with `love.graphics.replacePixels` (LÖVE 11.0+), which updates the existing texture in-place without re-allocating GPU memory:

```lua
function Bitmap:refresh()
  self.image:replacePixels(self.imgdata)
end
```

---

### 2. 🔴 High: Object pools iterated unconditionally

**File:** `src/states/game.lua`

Multiple collision and update functions loop over all 20 pool slots every frame:

```lua
for i = 1, MAX_BOMBS do     -- iterates 20 slots even if bombCount == 0
  local bomb = self.bombs[i]
  if not bomb.alive then goto continue end
  ...
end
```

**Suggestion:** Maintain an explicit active list (`self.activeBombs = {}`) and push/pop as bombs are spawned/destroyed. Only iterate active bombs. This turns 20-iteration loops into O(active) loops (typically 1–5).

---

### 3. 🟠 Medium: `love.joystick.getJoysticks()` called every frame

**Files:** `src/states/game.lua` (`doCannonMoving`), `src/states/hiscore_reg.lua` (`update`)

```lua
local joysticks = love.joystick.getJoysticks()
```

`getJoysticks()` returns a new table each call.

**Suggestion:** Cache the joystick reference once and only refresh when joysticks are connected/disconnected (via `love.joystickadded` / `love.joystickremoved` callbacks).

---

### 4. 🟠 Medium: `table.unpack` in every draw call

**Files:** `src/states/game.lua` (draw), `src/states/sos.lua` (draw)

```lua
love.graphics.setColor(table.unpack(ac.color))  -- vararg expansion every frame
```

For 55 aliens being drawn, this is 55 vararg expansions per frame.

**Suggestion:** Pass color components directly:

```lua
local c = ac.color
love.graphics.setColor(c[1], c[2], c[3], 1)
```

---

### 5. 🟠 Medium: String concatenation in draw hot path

**File:** `src/states/game.lua` — `Game:draw()`

```lua
local bmp = self.bitmaps["cannonboom" .. (self.cannon.boomFrame - 1)]
```

Creates a new string every draw frame while cannon is booming.

**Suggestion:** Pre-compute a lookup table:

```lua
self.boomBmpNames = {"cannonboom0", "cannonboom1", "cannonboom2"}
-- In draw:
local bmp = self.bitmaps[self.boomBmpNames[self.cannon.boomFrame]]
```

---

### 6. 🟠 Medium: Full grid scan each frame for min Y

**File:** `src/states/game.lua` — `doInvasionTest()`

```lua
local minY = math.huge
for r = 1, GRID_H do
  for c = 1, GRID_W do
    local a = self.grid[r][c]
    if a.alive then minY = math.min(minY, a.y) end
  end
end
```

Scans all 55 grid cells every update frame.

**Suggestion:** Track `self.lowestAlienY` incrementally in `doAlienMoving`. This turns a 55-iteration scan into O(1).

---

### 7. 🟡 Low: `Bitmap:countPixels()` iterates every pixel

**File:** `src/bitmap.lua` — `Bitmap:countPixels()`

```lua
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
```

**Suggestion:** Maintain a running `pixelCount` property on the bitmap. Decrement it in `setPixel` and `clearRect` when turning pixels off.

---

### 8. 🟡 Low: `HUD:update()` iterates all labels with `pairs()`

**File:** `src/hud.lua` — `HUD:update()`

```lua
for _, lbl in pairs(self.labels) do
```

Acceptable at current scale (~10–20 labels), but worth noting if the HUD grows.

---

### 9. 🟡 Low: `love.graphics.setColor` thrashing in draw

**File:** `src/states/game.lua` — `Game:draw()`

Draw calls `setColor` dozens of times per frame (once per alien, bomb, boom, etc.).

**Suggestion:** Group draws by color. Sort aliens by color before drawing to minimize state changes.

---

### 10. 🟡 Low: Redundant floor rounding in `Bitmap:draw()`

**File:** `src/bitmap.lua` — `Bitmap:draw()`

```lua
love.graphics.draw(self.image, math.floor(posX + 0.5), math.floor(loveY + 0.5))
```

LÖVE with `nearest` filtering already rounds to nearest pixel.

**Suggestion:** Remove manual rounding and let LÖVE handle pixel snapping.

```lua
function Bitmap:draw(posX, posY)
  local loveY = WORLD_H - posY - self.h
  love.graphics.draw(self.image, posX, loveY)
end
```

---

### Summary Table

| # | Area | Severity | Issue | Suggested Fix |
|---|------|----------|-------|---------------|
| 1 | `bitmap.lua` | 🔴 High | `refresh()` creates new GPU texture per call | Use `replacePixels` instead |
| 2 | `game.lua` | 🔴 High | Object pool iterates max slots | Track active list separately |
| 3 | `game.lua`, `hiscore_reg.lua` | 🟠 Medium | `getJoysticks()` allocates table every frame | Cache joystick reference once |
| 4 | `game.lua`, `sos.lua` | 🟠 Medium | `table.unpack` in draw hot path | Pass color components directly |
| 5 | `game.lua` | 🟠 Medium | String concat in draw boom path | Pre-compute key lookup table |
| 6 | `game.lua` | 🟠 Medium | Full grid scan each frame for min Y | Track incrementally |
| 7 | `bitmap.lua` | 🟡 Low | Full pixel scan for count | Maintain running counter |
| 8 | `hud.lua` | 🟡 Low | `pairs()` iteration over labels | Acceptable at current scale |
| 9 | `game.lua` | 🟡 Low | `setColor` thrashing | Group draws by color |
| 10 | `bitmap.lua` | 🟡 Low | Redundant floor rounding | Let LÖVE handle pixel snapping |

## How to Run

```sh
cd Space_Invaders_Part_II_LOVE2D
love src/
```

Requires LÖVE 11.x or later.