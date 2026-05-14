-- states/game.lua: main Space Invaders gameplay
-- World coords: 448 wide x 256 tall, Y=0 at bottom (bottom-up like original OpenGL code).

local Bitmap                   = require("bitmap")
local Collision                = require("collision")
local Audio                    = require("audio")
local Touch                    = require("touch")

local Game                     = {}
Game.__index                   = Game

-- ─── constants ────────────────────────────────────────────────────────────────
local WORLD_W                  = 448
local WORLD_H                  = 256

local GRID_W                   = 11
local GRID_H                   = 5
local GRID_SIZE                = GRID_W * GRID_H

local ALIEN_SHIFT_DX           = 2
local ALIEN_DROP_DY            = 14
local ALIEN_SPAWN_DROP_DY      = 7
local ALIEN_TOP_ROW_Y          = 186
local ALIEN_INVASION_Y         = 32
local ALIEN_X_SEP              = 14
local ALIEN_Y_SEP              = 14
local MIN_SPAWN_DROPS          = 6

local WORLD_MARGIN             = 5
local UFO_SPAWN_Y              = 210
local UFO_SPEED                = 40
local SCHRODINGER_PHASE_PERIOD = 0.4

local MAX_BOMBS                = 20
local BOMB_FRAMES              = 4
local BOMB_BOOM_W              = 8
local BOMB_BOOM_H              = 8
local BOMB_BOOM_DUR            = 0.4

local CANNON_SPEED             = 50
local LASER_SPEED              = 300

local BUNKER_SPAWN_X           = 64
local BUNKER_SPAWN_Y           = 48
local BUNKER_SPAWN_GAP         = 90
local BUNKER_COUNT             = 4
local BUNKER_DELETE_THR        = 20

local HITBAR_Y                 = 16
local HITBAR_H                 = 1

local MSG_HEIGHT_Y             = 140
local MSG_PERIOD               = 4.0
local BEAT_FREQ_SCALE          = 0.8

local TILL_UFO_MIN             = 1200
local TILL_UFO_MAX             = 1800
local SCHRODINGER_CHANCE       = 3 -- 1-in-N chance

-- Cycle data: beats per tick, cycleEnd sentinel
local CYCLE_END                = -1
local SPAWN_CYCLE              = 5
local cycles                   = {
    { 1,  CYCLE_END, 0,         0 },
    { 1,  1,         2,         CYCLE_END },
    { 1,  2,         CYCLE_END, 0 },
    { 2,  CYCLE_END, 0,         0 },
    { 2,  3,         CYCLE_END, 0 },
    { 5,  CYCLE_END, 0,         0 },
    { 7,  CYCLE_END, 0,         0 },
    { 10, CYCLE_END, 0,         0 },
    { 14, CYCLE_END, 0,         0 },
    { 19, CYCLE_END, 0,         0 },
    { 25, CYCLE_END, 0,         0 },
    { 34, CYCLE_END, 0,         0 },
    { 46, CYCLE_END, 0,         0 },
}
local cycleTransitions         = { 49, 42, 35, 28, 21, 14, 10, 7, 5, 4, 3, 2, 0 }

local bombIntervals            = { 80, 80, 100, 120, 140, 180, 240, 300, 400, 500, 650, 800, 1100 }

-- Alien class IDs (1-indexed)
local SQUID                    = 1; local CRAB = 2; local OCTOPUS = 3; local CUTTLE = 4; local CUTTLETWIN = 5

local alienClasses             = {
    -- {w, h, score, colorIdx, frame0Key, frame1Key}
    { w = 8,  h = 8, score = 30, color = { 1, 1, 1 }, bmp = { "squid0", "squid1" } },
    { w = 11, h = 8, score = 20, color = { 0, 1, 1 }, bmp = { "crab0", "crab1" } },
    { w = 12, h = 8, score = 10, color = { 1, 0, 1 }, bmp = { "octopus0", "octopus1" } },
    { w = 8,  h = 8, score = 30, color = { 1, 1, 0 }, bmp = { "cuttle0", "cuttle1" } },
    { w = 19, h = 8, score = 60, color = { 1, 1, 0 }, bmp = { "cuttletwin", "cuttletwin" } },
}

local ufoClasses               = {
    -- saucer
    {
        scores = { 50, 100, 150 },
        special = 300,
        w = 16,
        h = 7,
        color = { 1, 0, 1 },
        phaser = false,
        phasePeriod = 0,
        shipBmp = "saucer",
        boomBmp = "ufoboom"
    },
    -- schrodinger
    {
        scores = { 300, 350, 400 },
        special = 1000,
        w = 15,
        h = 7,
        color = { 0, 1, 1 },
        phaser = true,
        phasePeriod = SCHRODINGER_PHASE_PERIOD,
        shipBmp = "schrodinger",
        boomBmp = "ufoboom"
    },
}
local SAUCER                   = 1; local SCHRODINGER = 2

local bombClasses              = {
    -- cross
    {
        w = 3,
        h = 6,
        speed = -80,
        colorIdx = 1,
        frameInterval = 20,
        laserSurvive = 0,
        bmp = { "cross0", "cross1", "cross2", "cross3" }
    },
    -- zigzag
    {
        w = 3,
        h = 7,
        speed = -120,
        colorIdx = 4,
        frameInterval = 20,
        laserSurvive = 10,
        bmp = { "zigzag0", "zigzag1", "zigzag2", "zigzag3" }
    },
    -- zagzig
    {
        w = 3,
        h = 7,
        speed = -100,
        colorIdx = 5,
        frameInterval = 20,
        laserSurvive = 4,
        bmp = { "zagzig0", "zagzig1", "zagzig2", "zagzig3" }
    },
}
local CROSS                    = 1; local ZIGZAG = 2; local ZAGZIG = 3

local BOMBHIT_BOTTOM           = 1; local BOMBHIT_MIDAIR = 2

local formations               = {
    { -- formation 0: bottom-to-top rows
        { OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS },
        { OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS },
        { CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB },
        { CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB },
        { SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID },
    },
    { -- formation 1
        { SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID,   SQUID },
        { CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB },
        { CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB,    CRAB },
        { OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS },
        { OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS, OCTOPUS },
    },
}

local colorPalette             = {
    { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 }, { 1, 0, 1 }, { 0, 1, 1 }, { 1, 1, 0 }, { 1, 1, 1 }
}

-- ─── helpers ──────────────────────────────────────────────────────────────────
local function wrap(v, lo, hi)
    local range = hi - lo + 1
    return lo + (v - lo) % range
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function randInt(lo, hi)
    return love.math.random(lo, hi)
end

-- ─── constructor ──────────────────────────────────────────────────────────────
function Game.new(si)
    local g = setmetatable({}, Game)
    g.si = si -- SpaceInvaders app table

    -- Pre-load all bitmaps
    g.bitmaps = {}
    local bmpNames = {
        "cannon0", "squid0", "squid1", "crab0", "crab1", "octopus0", "octopus1",
        "cuttle0", "cuttle1", "cuttletwin", "saucer", "schrodinger", "ufoboom",
        "cross0", "cross1", "cross2", "cross3", "zigzag0", "zigzag1", "zigzag2", "zigzag3",
        "zagzig0", "zagzig1", "zagzig2", "zagzig3", "laser0",
        "cannonboom0", "cannonboom1", "cannonboom2",
        "hitbar", "alienboom", "bombboombottom", "bombboommidair",
        "bunker", "partii", "controls", "menu", "sostrail",
    }
    for _, name in ipairs(bmpNames) do
        g.bitmaps[name] = Bitmap.load(name)
    end

    g.worldLeftBorderX  = WORLD_MARGIN
    g.worldRightBorderX = WORLD_W - WORLD_MARGIN
    g.worldTopBorderY   = WORLD_H - 30

    g.spawnX            = (WORLD_W - GRID_W * ALIEN_X_SEP) / 2
    g.spawnY            = (ALIEN_TOP_ROW_Y + MIN_SPAWN_DROPS * ALIEN_SPAWN_DROP_DY)
        - (GRID_H - 1) * ALIEN_DROP_DY

    -- Allocate object pools
    g.grid              = {} -- [row][col] alien
    g.columnPops        = {}
    g.rowPops           = {}
    g.bombs             = {}
    g.bombBooms         = {}
    g.activeBombs       = {} -- active list: only live bombs
    g.activeBombBooms   = {} -- active list: only live bomb booms
    g.bombCount         = 0
    g.boomCount         = 0
    g.bunkers           = {}
    for r = 1, GRID_H do
        g.grid[r] = {}
        for c = 1, GRID_W do
            g.grid[r][c] = {}
        end
    end
    for i = 1, MAX_BOMBS do
        g.bombs[i]     = { alive = false }
        g.bombBooms[i] = { alive = false }
    end

    g.hitbarBmp    = nil

    g.isGameOver   = false
    g.isVictory    = false
    g.isRoundIntro = false

    return g
end

-- ─── enter ────────────────────────────────────────────────────────────────────
function Game:enter()
    self:startNextLevel()
end

function Game:startNextLevel()
    local si         = self.si
    local round      = si.round
    local levelIndex = math.min(round, 10)

    -- Beat system
    self.activeCycle = SPAWN_CYCLE
    self.activeBeat  = 1
    self.beatPaused  = true
    self.beatClock   = 0
    self.beatPeriod  = 1
    self.nextBeat    = 1
    self:updateBeatFreq()

    self.nextMoverRow             = 1
    self.nextMoverCol             = 1
    self.alienMoveDir             = 1
    self.dropsDone                = 0
    self.isAliensBooming          = false
    self.isAliensMorphing         = false
    self.isAliensDropping         = true
    self.isAliensSpawning         = true
    self.isAliensFrozen           = false
    self.isAliensAboveInvasionRow = false
    self.alienBoomer              = nil
    self.alienBoomClock           = 0
    self.alienMorpher             = nil
    self.alienMorphClock          = 0
    self.lastClassAlive           = SQUID

    -- Reset alien grid
    for r = 1, GRID_H do
        for c = 1, GRID_W do
            local a   = self.grid[r][c]
            a.classId = formations[1][r][c]
            a.x       = self.spawnX + (c - 1) * ALIEN_X_SEP
            a.y       = self.spawnY + (r - 1) * ALIEN_Y_SEP
            a.row     = r; a.col = c
            a.frame   = 1; a.alive = true
        end
    end
    for c = 1, GRID_W do self.columnPops[c] = GRID_H end
    for r = 1, GRID_H do self.rowPops[r] = GRID_W end
    self.alienPop     = GRID_SIZE

    -- UFO
    self.ufo          = { alive = false, classId = SAUCER, x = 0, y = UFO_SPAWN_Y, phase = true, phaseClock = 0 }
    self.tillUfo      = randInt(TILL_UFO_MIN, TILL_UFO_MAX)
    self.ufoCounter   = 0
    self.ufoDir       = 1
    self.canUfosSpawn = true
    self.isUfoBooming = false
    self.isUfoScoring = false
    self.ufoBoomClock = 0
    self.ufoSfxHandle = nil
    self.ufoLastScore = 0

    -- Bombs
    for i = 1, MAX_BOMBS do
        self.bombs[i].alive = false
        self.bombBooms[i].alive = false
    end
    self.bombCount       = 0
    self.boomCount       = 0
    self.activeBombs     = {}
    self.activeBombBooms = {}
    self.bombClock       = bombIntervals[self.activeCycle] or 80

    -- Laser & cannon
    self.laser           = { alive = false, x = 0, y = 0, w = 1, h = 6, speed = LASER_SPEED }
    self.shotCounter     = 0

    self.cannon          = {
        alive = false,
        booming = false,
        x = self.worldLeftBorderX,
        y = ALIEN_INVASION_Y,
        w = 13,
        h = 8,
        speed = CANNON_SPEED,
        boomClock = 0,
        boomDur = 1.0,
        boomFrameClock = 0,
        boomFrameDur = 0.2,
        boomFrame = 1,
    }

    -- Fresh hitbar
    local srcHitbar      = self.bitmaps["hitbar"]
    self.hitbarBmp       = Bitmap.clone(srcHitbar)
    self.hitbarY         = HITBAR_Y

    -- Fresh bunkers
    self.bunkers         = {}
    local bx             = BUNKER_SPAWN_X
    for i = 1, BUNKER_COUNT do
        local src = self.bitmaps["bunker"]
        self.bunkers[i] = {
            bmp = Bitmap.clone(src),
            x = bx,
            y = BUNKER_SPAWN_Y,
            alive = true,
        }
        bx = bx + BUNKER_SPAWN_GAP
    end

    self.isGameOver     = false
    self.isVictory      = false
    self.msgClock       = 0
    self.hudMsg         = nil
    self.hudMsgColor    = { 1, 1, 1 }
    self.ufoScoringText = nil

    self.si:showHud()
    self.si:hideTopHud()
    self.si:showLivesHud()
    self:startRoundIntro()
end

-- ─── beat system ──────────────────────────────────────────────────────────────
function Game:updateBeatFreq()
    local cycle = cycles[self.activeCycle]
    local ticksPerCycle, beatsPerCycle = 0, 0
    for _, v in ipairs(cycle) do
        if v ~= CYCLE_END then
            ticksPerCycle = ticksPerCycle + 1
            beatsPerCycle = beatsPerCycle + v
        else
            break
        end
    end
    local freq = (60 / ((GRID_SIZE / beatsPerCycle) * ticksPerCycle)) * BEAT_FREQ_SCALE
    self.beatPeriod = 1 / freq
end

function Game:updateActiveCycle()
    self.activeCycle = 1
    while self.alienPop < cycleTransitions[self.activeCycle] do
        self.activeCycle = self.activeCycle + 1
        self:updateBeatFreq()
    end
end

function Game:updateActiveCycleBeat()
    self.activeBeat = self.activeBeat + 1
    local cycle = cycles[self.activeCycle]
    if self.activeBeat > #cycle or cycle[self.activeBeat] == CYCLE_END then
        self.activeBeat = 1
    end
end

function Game:doBeats(dt)
    if self.beatPaused then return end
    self.beatClock = self.beatClock + dt
    if self.beatClock >= self.beatPeriod then
        self.beatClock = self.beatClock - self.beatPeriod
        local beatKeys = { "fastinvader1", "fastinvader2", "fastinvader3", "fastinvader4" }
        Audio.play(beatKeys[self.nextBeat])
        self.nextBeat = wrap(self.nextBeat + 1, 1, 4)
    end
end

-- ─── spawning ─────────────────────────────────────────────────────────────────
function Game:endSpawning()
    self.isAliensSpawning = false
    self.isAliensDropping = false
    self:spawnCannon(false)
    self.activeCycle = 1
    self:updateBeatFreq()
    self.beatPaused = false
    self.si:showTopHud()
end

function Game:spawnCannon(takeLife)
    if takeLife then
        self.si.lives = self.si.lives - 1
        self.si:updateLivesHud()
        if self.si.lives <= 0 then
            self:startGameOver()
            return
        end
    end
    self.cannon.x       = self.worldLeftBorderX
    self.cannon.y       = ALIEN_INVASION_Y
    self.cannon.alive   = true
    self.cannon.booming = false
    self.isAliensFrozen = false
    self.beatPaused     = false
end

function Game:spawnUfo(classId)
    self.ufo.classId    = classId
    self.ufo.alive      = true
    self.ufo.phase      = true
    self.ufo.phaseClock = 0
    self.ufoDir         = (randInt(0, 1) == 0) and 1 or -1
    self.ufo.x          = (self.ufoDir == 1) and 0 or WORLD_W
    self.ufo.y          = UFO_SPAWN_Y
    self.ufoCounter     = self.ufoCounter + 1
    self.ufoSfxHandle   = Audio.play("ufo_highpitch", true)
end

function Game:spawnBomb(x, y, classId)
    if self.bombCount >= MAX_BOMBS then return end
    local b                          = self.bombs[self.bombCount + 1]
    b.classId                        = classId
    b.x                              = x; b.y = y
    b.frame                          = 1
    b.alive                          = true
    b.frameClock                     = bombClasses[classId].frameInterval
    self.bombCount                   = self.bombCount + 1
    self.activeBombs[self.bombCount] = b
end

function Game:spawnBoom(x, y, hit, colorIdx)
    local boom                           = self.bombBooms[self.boomCount + 1]
    boom.x                               = x; boom.y = y
    boom.hit                             = hit
    boom.colorIdx                        = colorIdx
    boom.clock                           = BOMB_BOOM_DUR
    boom.alive                           = true
    self.boomCount                       = self.boomCount + 1
    self.activeBombBooms[self.boomCount] = boom
end

-- ─── booming ──────────────────────────────────────────────────────────────────
function Game:boomCannon()
    self.cannon.alive          = false
    self.cannon.booming        = true
    self.cannon.boomClock      = 1.0
    self.cannon.boomFrameClock = self.cannon.boomFrameDur
    self.cannon.boomFrame      = 1
    self.isAliensFrozen        = true
    self.beatPaused            = true
    Audio.play("explosion")
end

function Game:boomBomb(bomb, makeBoom, bx, by, hit)
    bomb.alive     = false
    self.bombCount = self.bombCount - 1
    -- Swap-remove from active list: move last active to this slot
    for i = 1, #self.activeBombs do
        if self.activeBombs[i] == bomb then
            self.activeBombs[i] = self.activeBombs[#self.activeBombs]
            self.activeBombs[#self.activeBombs] = nil
            break
        end
    end
    if makeBoom then
        local bc = bombClasses[bomb.classId]
        self:spawnBoom(bx or bomb.x, by or bomb.y, hit or BOMBHIT_MIDAIR, bc.colorIdx)
    end
end

function Game:boomUfo()
    self.ufo.alive    = false
    self.isUfoBooming = true
    self.ufoBoomClock = 0
    local uc          = ufoClasses[self.ufo.classId]
    local cnt         = self.ufoCounter
    local shot        = self.shotCounter
    if (cnt == 1 and shot == 23) or (cnt > 1 and (shot - 23) % 15 == 0) then
        self.ufoLastScore = uc.special
    else
        self.ufoLastScore = uc.scores[randInt(1, 3)]
    end
    self.si:addScore(self.ufoLastScore)
    Audio.stop(self.ufoSfxHandle)
    Audio.play("ufo_lowpitch")
end

function Game:boomAlien(alien)
    self.si:addScore(alienClasses[alien.classId].score)
    alien.alive                = false
    self.alienBoomer           = alien
    self.alienBoomClock        = 0.1
    self.isAliensFrozen        = true
    self.isAliensBooming       = true
    self.columnPops[alien.col] = self.columnPops[alien.col] - 1
    self.rowPops[alien.row]    = self.rowPops[alien.row] - 1
    self.alienPop              = self.alienPop - 1
    if self.alienPop <= 0 then self.lastClassAlive = alien.classId end
    if self.alienPop <= 8 then self.canUfosSpawn = false end
    self:updateActiveCycle()
    Audio.play("invaderkilled")
end

function Game:boomLaser(makeBoom, hit)
    self.laser.alive = false
    if makeBoom then
        local bx = self.laser.x - (BOMB_BOOM_W - self.laser.w) / 2
        self:spawnBoom(bx, self.laser.y, hit or BOMBHIT_MIDAIR, 6)
    end
end

function Game:boomAllBombs()
    -- Iterate a copy of active list since boomBomb mutates it
    local bombs = {}
    for _, b in ipairs(self.activeBombs) do bombs[#bombs + 1] = b end
    for _, b in ipairs(bombs) do
        if b.alive then self:boomBomb(b, false) end
    end
end

function Game:morphAlien(alien)
    self.si:addScore(alienClasses[alien.classId].score)
    alien.classId         = CUTTLETWIN
    self.alienMorpher     = alien
    self.alienMorphClock  = 0.2
    self.isAliensFrozen   = true
    self.isAliensMorphing = true
    -- Kill the neighbour to the right
    local neighbour       = self.grid[alien.row][alien.col + 1]
    if neighbour.alive then
        neighbour.alive                = false
        self.columnPops[neighbour.col] = self.columnPops[neighbour.col] - 1
        self.rowPops[neighbour.row]    = self.rowPops[neighbour.row] - 1
        self.alienPop                  = self.alienPop - 1
    end
    Audio.play("invadermorphed")
end

-- ─── update helpers ───────────────────────────────────────────────────────────
function Game:doRoundIntro(dt)
    if not self.isRoundIntro then return end
    self.msgClock = self.msgClock + dt
    if self.msgClock >= MSG_PERIOD then
        self.isRoundIntro = false
        self.hudMsg = nil
    end
end

function Game:startRoundIntro()
    self.hudMsg       = "ROUND " .. tostring(self.si.round)
    self.hudMsgColor  = { 1, 0, 0 }
    self.msgClock     = 0
    self.isRoundIntro = true
end

function Game:startGameOver()
    self.cannon.alive   = false
    self.isAliensFrozen = true
    self.beatPaused     = true
    if self.ufo.alive then Audio.stop(self.ufoSfxHandle) end
    self.si:startScoreFlash()
    self.hudMsg      = "GAME OVER!"
    self.hudMsgColor = { 1, 0, 0 }
    self.msgClock    = 0
    self.isGameOver  = true
end

function Game:doGameOver(dt)
    if not self.isGameOver then return end
    self.msgClock = self.msgClock + dt
    if self.msgClock >= MSG_PERIOD then
        self.si:stopScoreFlash()
        self.hudMsg = nil
        if self.si:isHiScore(self.si.score) then
            self.si:switchState("hiscore_reg")
        else
            self.si:switchState("hiscore_board")
        end
    end
end

function Game:startVictory()
    self.beatPaused = true
    if self.ufo.alive then Audio.stop(self.ufoSfxHandle) end
    self:boomAllBombs()
    self.si:startScoreFlash()
    self.hudMsg      = "VICTORY!"
    self.hudMsgColor = { 0, 1, 0 }
    self.msgClock    = 0
    self.isVictory   = true
end

function Game:doVictory(dt)
    if not self.isVictory then return end
    self.msgClock = self.msgClock + dt
    if self.msgClock >= MSG_PERIOD then
        self.si.round = self.si.round + 1
        self.si:stopScoreFlash()
        self.hudMsg = nil
        self.si:switchState("sos")
    end
end

function Game:doVictoryTest()
    if not self.isVictory and self.alienPop == 0 then
        self.beatPaused = true
        if not self.ufo.alive then self:startVictory() end
    end
end

function Game:doInvasionTest()
    if self.isGameOver or self.alienPop == 0 or self.isAliensFrozen
        or self.isAliensSpawning or self.isAliensDropping then
        return
    end

    local minY = math.huge
    for r = 1, GRID_H do
        for c = 1, GRID_W do
            local a = self.grid[r][c]
            if a.alive then minY = math.min(minY, a.y) end
        end
    end
    if minY == ALIEN_INVASION_Y then
        self:startGameOver()
    elseif minY == ALIEN_INVASION_Y + ALIEN_DROP_DY then
        self.isAliensAboveInvasionRow = true
    end
end

function Game:doCannonMoving(dt)
    if not self.cannon.alive then return end
    if self.isVictory then return end

    -- Check keyboard input
    local lKey = love.keyboard.isDown("left")
    local rKey = love.keyboard.isDown("right")

    -- Check gamepad dpad input (first connected joystick)
    local joysticks = love.joystick.getJoysticks()
    if joysticks and #joysticks > 0 then
        local js = joysticks[1]
        if js:isGamepadDown("dpleft") then lKey = true end
        if js:isGamepadDown("dpright") then rKey = true end
    end

    if Touch.isDown("left")  then lKey = true end
    if Touch.isDown("right") then rKey = true end

    local dir     = (lKey and not rKey) and -1 or ((rKey and not lKey) and 1 or 0)
    self.cannon.x = clamp(self.cannon.x + CANNON_SPEED * dir * dt,
        self.worldLeftBorderX,
        self.worldRightBorderX - self.cannon.w)
end

function Game:doCannonBooming(dt)
    if not self.cannon.booming then return end
    self.cannon.boomClock = self.cannon.boomClock - dt
    if self.cannon.boomClock <= 0 then
        self.cannon.booming = false
        self:spawnCannon(true)
        return
    end
    self.cannon.boomFrameClock = self.cannon.boomFrameClock - dt
    if self.cannon.boomFrameClock <= 0 then
        self.cannon.boomFrame = wrap(self.cannon.boomFrame + 1, 1, 3)
        self.cannon.boomFrameClock = self.cannon.boomFrameDur
    end
end

function Game:doCannonFiring()
    if not self.cannon.alive then return end
    if self.laser.alive then return end
    if self.isVictory then return end
    if _keyPressed["space"] then
        self.laser.x = self.cannon.x + self.cannon.w / 2
        self.laser.y = self.cannon.y + self.cannon.h
        self.laser.alive = true
        self.shotCounter = self.shotCounter + 1
        Audio.play("shoot")
    end
end

function Game:doAlienMoving(beats)
    if self.isRoundIntro or self.isAliensFrozen or self.alienPop == 0 then return end
    for _ = 1, beats do
        local alien = self.grid[self.nextMoverRow][self.nextMoverCol]
        if self.isAliensDropping then
            local dy = self.isAliensSpawning and ALIEN_SPAWN_DROP_DY or ALIEN_DROP_DY
            alien.y = alien.y - dy
        else
            alien.x = alien.x + ALIEN_SHIFT_DX * self.alienMoveDir
        end
        alien.frame = (alien.frame == 1) and 2 or 1

        -- Advance next mover
        local looped = false
        self.nextMoverCol = self.nextMoverCol + 1
        if self.nextMoverCol > GRID_W then
            self.nextMoverCol = 1
            self.nextMoverRow = self.nextMoverRow + 1
            if self.nextMoverRow > GRID_H then
                self.nextMoverRow = 1
                looped = true
            end
        end

        if looped then
            if self.isAliensDropping then
                self.dropsDone = self.dropsDone + 1
                if self.isAliensSpawning then
                    Audio.play("fastinvader4")
                    if self.dropsDone >= MIN_SPAWN_DROPS then self:endSpawning() end
                else
                    self.isAliensDropping = false
                    self.alienMoveDir = -self.alienMoveDir
                end
            elseif self:doCollisionsAliensBorders() then
                self.isAliensDropping = true
            end
        end
    end
end

function Game:doBombMoving(beats, dt)
    for _, b in ipairs(self.activeBombs) do
        local bc = bombClasses[b.classId]
        b.y = b.y + bc.speed * dt
        b.frameClock = b.frameClock - beats
        if b.frameClock <= 0 then
            b.frame = wrap(b.frame + 1, 1, BOMB_FRAMES)
            b.frameClock = bc.frameInterval
        end
    end
end

function Game:doLaserMoving(dt)
    if self.laser.alive then
        self.laser.y = self.laser.y + LASER_SPEED * dt
    end
end

function Game:doUfoMoving(dt)
    if self.ufo.alive then
        self.ufo.x = self.ufo.x + UFO_SPEED * self.ufoDir * dt
    end
end

function Game:doUfoPhasing(dt)
    if not self.ufo.alive then return end
    local uc = ufoClasses[self.ufo.classId]
    if not uc.phaser then return end
    self.ufo.phaseClock = self.ufo.phaseClock + dt
    if self.ufo.phaseClock >= uc.phasePeriod then
        self.ufo.phase      = not self.ufo.phase
        self.ufo.phaseClock = 0
    end
end

function Game:doUfoSpawning()
    if self.ufo.alive or self.isAliensSpawning or self.isAliensDropping then return end
    if self.isGameOver or self.isVictory or self.isRoundIntro then return end
    if self.alienPop <= 8 or not self.canUfosSpawn then return end
    self.tillUfo = self.tillUfo - 1
    if self.tillUfo <= 0 then
        local classId = (randInt(0, SCHRODINGER_CHANCE) == 0) and SCHRODINGER or SAUCER
        self:spawnUfo(classId)
        self.tillUfo = randInt(TILL_UFO_MIN, TILL_UFO_MAX)
    end
end

function Game:doAlienBombing(beats)
    if self.isAliensFrozen or self.isAliensSpawning or self.alienPop == 0 then return end
    self.bombClock = self.bombClock - beats
    if self.bombClock > 0 then return end
    -- Pick a populated column
    local populated = {}
    for c = 1, GRID_W do
        if self.columnPops[c] > 0 then populated[#populated + 1] = c end
    end
    if #populated == 0 then return end
    local col = populated[randInt(1, #populated)]
    -- Find the bottom-most alive alien in that column
    local alien = nil
    for r = 1, GRID_H do
        if self.grid[r][col].alive then
            alien = self.grid[r][col]; break
        end
    end
    if not alien then return end
    local classId = randInt(CROSS, ZAGZIG)
    local bc      = bombClasses[classId]
    local ac      = alienClasses[alien.classId]
    self:spawnBomb(alien.x + ac.w / 2, alien.y - bc.h, classId)
    self.bombClock = bombIntervals[self.activeCycle] or 80
end

function Game:doAlienBooming(dt)
    if not self.isAliensBooming then return end
    self.alienBoomClock = self.alienBoomClock - dt
    if self.alienBoomClock <= 0 then
        self.alienBoomer     = nil
        self.isAliensFrozen  = false
        self.isAliensBooming = false
    end
end

function Game:doAlienMorphing(dt)
    if not self.isAliensMorphing then return end
    if self.alienPop == 0 then return end
    self.alienMorphClock = self.alienMorphClock - dt
    if self.alienMorphClock > 0 then return end
    local m                        = self.alienMorpher
    m.classId                      = CUTTLE
    local neighbour                = self.grid[m.row][m.col + 1]
    neighbour.classId              = CUTTLE
    neighbour.alive                = true
    self.columnPops[neighbour.col] = self.columnPops[neighbour.col] + 1
    self.rowPops[neighbour.row]    = self.rowPops[neighbour.row] + 1
    self.alienPop                  = self.alienPop + 1
    self.isAliensMorphing          = false
    self.isAliensFrozen            = false
    self.alienMorpher              = nil
end

function Game:doUfoBoomScoring(dt)
    if not (self.isUfoBooming or self.isUfoScoring) then return end
    self.ufoBoomClock = self.ufoBoomClock + dt
    if self.ufoBoomClock >= 0.5 then
        if self.isUfoBooming then
            self.isUfoBooming   = false
            self.isUfoScoring   = true
            self.ufoScoringText = tostring(self.ufoLastScore)
            self.ufoScoringX    = self.ufo.x
            self.ufoScoringY    = self.ufo.y
        else
            self.isUfoScoring   = false
            self.ufoScoringText = nil
        end
        self.ufoBoomClock = 0
    end
end

function Game:doBombBoomBooming(dt)
    for i = #self.activeBombBooms, 1, -1 do
        local boom = self.activeBombBooms[i]
        boom.clock = boom.clock - dt
        if boom.clock <= 0 then
            boom.alive = false
            -- Swap-remove
            self.activeBombBooms[i] = self.activeBombBooms[#self.activeBombBooms]
            self.activeBombBooms[#self.activeBombBooms] = nil
            self.boomCount = self.boomCount - 1
        end
    end
end

-- ─── collision detection ──────────────────────────────────────────────────────
function Game:doCollisionsAliensBorders()
    if self.isAliensSpawning or self.isAliensFrozen or self.alienPop == 0 then return false end
    if self.alienMoveDir == -1 then
        for c = 1, GRID_W do
            for r = 1, GRID_H do
                local a = self.grid[r][c]
                if a.alive and a.x <= self.worldLeftBorderX then return true end
            end
        end
    else
        for c = GRID_W, 1, -1 do
            for r = 1, GRID_H do
                local a = self.grid[r][c]
                if a.alive and a.x + ALIEN_X_SEP >= self.worldRightBorderX then return true end
            end
        end
    end
    return false
end

function Game:doCollisionsUfoBorders()
    if not self.ufo.alive then return end
    if (self.ufoDir == -1 and self.ufo.x < 0) or
        (self.ufoDir == 1 and self.ufo.x > WORLD_W) then
        self.ufo.alive = false
        Audio.stop(self.ufoSfxHandle)
    end
end

function Game:doCollisionsBombsHitbar()
    for _, bomb in ipairs(self.activeBombs) do
        if bomb.y <= self.hitbarY then
            local bc     = bombClasses[bomb.classId]
            local bithit = math.floor(bomb.x - (BOMB_BOOM_W - bc.w) / 2)
            local hbW    = self.hitbarBmp.w

            -- Damage the hitbar pixels
            for px = 0, BOMB_BOOM_W - 1 do
                local col = bithit + px
                if col >= 0 and col < hbW then
                    -- Checkerboard pattern
                    local val = (math.floor(col) % 2 == 0)
                    for row = 0, self.hitbarBmp.h - 1 do
                        self.hitbarBmp:setPixel(row, col, val)
                    end
                end
            end
            self.hitbarBmp:refresh()

            local boomX = bithit
            local boomY = self.hitbarY + self.hitbarBmp.h
            self:boomBomb(bomb, true, boomX, boomY, BOMBHIT_BOTTOM)
        end
    end
end

function Game:doCollisionsBombsCannon()
    if not self.cannon.alive or self.cannon.booming then return end
    if self.bombCount == 0 or self.isAliensAboveInvasionRow then return end
    local cBmp = self.bitmaps["cannon0"]
    for _, bomb in ipairs(self.activeBombs) do
        local bc   = bombClasses[bomb.classId]
        local bBmp = self.bitmaps[bc.bmp[bomb.frame]]
        local hit  = Collision.test(self.cannon.x, self.cannon.y, cBmp,
            bomb.x, bomb.y, bBmp, false)
        if hit then
            self:boomCannon()
            self:boomBomb(bomb)
        end
    end
end

function Game:doCollisionsBombsLaser()
    if not self.laser.alive or self.bombCount == 0 then return end
    local lBmp = self.bitmaps["laser0"]
    for _, bomb in ipairs(self.activeBombs) do
        local bc   = bombClasses[bomb.classId]
        local bBmp = self.bitmaps[bc.bmp[bomb.frame]]
        local hit  = Collision.test(self.laser.x, self.laser.y, lBmp,
            bomb.x, bomb.y, bBmp, false)
        if hit then
            self:boomLaser(true)
            self:spawnBoom(bomb.x, bomb.y, BOMBHIT_MIDAIR, bc.colorIdx)
            if randInt(0, bc.laserSurvive) ~= 0 then
                self:boomBomb(bomb, false)
            end
            return
        end
    end
end

function Game:doCollisionsLaserAliens()
    if not self.laser.alive or self.isAliensSpawning or self.isAliensFrozen
        or self.alienPop == 0 then
        return
    end
    local lBmp = self.bitmaps["laser0"]
    for r = 1, GRID_H do
        for c = 1, GRID_W do
            local alien = self.grid[r][c]
            if alien.alive then
                local ac   = alienClasses[alien.classId]
                local aBmp = self.bitmaps[ac.bmp[alien.frame]]
                local hit  = Collision.test(self.laser.x, self.laser.y, lBmp,
                    alien.x, alien.y, aBmp, false)
                if hit then
                    if alien.classId == CUTTLETWIN then
                        self.alienMorpher     = nil
                        self.isAliensMorphing = false
                    end
                    -- Cuttle morph mechanic (col < GRID_W means there's a neighbour)
                    if alien.classId == CRAB and alien.col < GRID_W then
                        self:morphAlien(alien)
                    else
                        self:boomAlien(alien)
                    end
                    self:boomLaser(false)
                    return
                end
            end
        end
    end
end

function Game:doCollisionsLaserUfo()
    if not self.laser.alive or not self.ufo.alive or not self.ufo.phase then return end
    local uc   = ufoClasses[self.ufo.classId]
    local uBmp = self.bitmaps[uc.shipBmp]
    local lBmp = self.bitmaps["laser0"]
    local hit  = Collision.test(self.laser.x, self.laser.y, lBmp,
        self.ufo.x, self.ufo.y, uBmp, false)
    if hit then
        self:boomLaser(false)
        self:boomUfo()
    end
end

function Game:doCollisionsLaserSky()
    if not self.laser.alive then return end
    if self.laser.y + self.laser.h < self.worldTopBorderY then return end
    local bx = self.laser.x - (BOMB_BOOM_W - self.laser.w) / 2
    self:boomLaser(true, BOMBHIT_MIDAIR)
end

function Game:doCollisionsBunkersBombs()
    if self.bombCount == 0 or #self.bunkers == 0 then return end
    for _, bomb in ipairs(self.activeBombs) do
        if bomb.y >= BUNKER_SPAWN_Y and bomb.y <= BUNKER_SPAWN_Y + 16 then
            local bc   = bombClasses[bomb.classId]
            local bBmp = self.bitmaps[bc.bmp[bomb.frame]]
            for bi = #self.bunkers, 1, -1 do
                local bunker = self.bunkers[bi]
                if bunker.alive then
                    local hit, aPixels, bPixels = Collision.test(bomb.x, bomb.y, bBmp,
                        bunker.x, bunker.y, bunker.bmp, true)
                    if hit then
                        self:boomBomb(bomb)
                        -- Damage bunker at collision pixels
                        self:damageBunker(bunker, bPixels)
                        if bunker.bmp:countPixels() <= BUNKER_DELETE_THR then
                            table.remove(self.bunkers, bi)
                        end
                        break
                    end
                end
            end
        end
    end
end

function Game:doCollisionsBunkersLaser()
    if not self.laser.alive or #self.bunkers == 0 then return end
    local lBmp = self.bitmaps["laser0"]
    for bi = #self.bunkers, 1, -1 do
        local bunker = self.bunkers[bi]
        if bunker.alive then
            local hit, aPixels, bPixels = Collision.test(self.laser.x, self.laser.y, lBmp,
                bunker.x, bunker.y, bunker.bmp, true)
            if hit then
                self:boomLaser(false)
                self:damageBunker(bunker, bPixels)
                if bunker.bmp:countPixels() <= BUNKER_DELETE_THR then
                    table.remove(self.bunkers, bi)
                end
                return
            end
        end
    end
end

function Game:doCollisionsBunkersAliens()
    if self.isAliensSpawning or self.isAliensFrozen or #self.bunkers == 0
        or self.alienPop == 0 then
        return
    end
    -- Find bottom row
    local bottomRow = 0
    for r = 1, GRID_H do
        if self.rowPops[r] > 0 then
            bottomRow = r; break
        end
    end
    if bottomRow == 0 then return end
    if self.grid[bottomRow][1].y > BUNKER_SPAWN_Y + 16 then return end

    for c = 1, GRID_W do
        local alien = self.grid[bottomRow][c]
        if alien.alive then
            local ac   = alienClasses[alien.classId]
            local aBmp = self.bitmaps[ac.bmp[alien.frame]]
            for bi = #self.bunkers, 1, -1 do
                local bunker = self.bunkers[bi]
                if bunker.alive then
                    local hit, aPixels, bPixels, aOv, bOv = Collision.test(
                        alien.x, alien.y, aBmp, bunker.x, bunker.y, bunker.bmp, false)
                    if hit then
                        -- Erase the overlapping rectangle from the bunker
                        if bOv then
                            bunker.bmp:clearRect(bOv.ymin, bOv.xmin, bOv.ymax - 1, bOv.xmax - 1)
                            bunker.bmp:refresh()
                        end
                        if bunker.bmp:countPixels() <= BUNKER_DELETE_THR then
                            table.remove(self.bunkers, bi)
                        end
                        return
                    end
                end
            end
        end
    end
end

-- Erase bPixels from a bunker's bitmap and refresh
function Game:damageBunker(bunker, pixels)
    if not pixels then return end
    local boomBmp = self.bitmaps["bombboommidair"]
    -- Use the midair boom bitmap as an eraser mask (damage shape)
    -- For simplicity, just erase the colliding pixels directly
    for _, px in ipairs(pixels) do
        bunker.bmp:setPixel(px.row, px.col, false)
    end
    bunker.bmp:refresh()
end

-- ─── update ───────────────────────────────────────────────────────────────────
function Game:update(dt)
    local beats = cycles[self.activeCycle][self.activeBeat]
    if beats == CYCLE_END or beats == 0 then beats = 0 end

    self:doRoundIntro(dt)
    self:doAlienMorphing(dt)
    self:doBombMoving(beats, dt)
    self:doLaserMoving(dt)
    self:doAlienMoving(beats)
    self:doAlienBombing(beats)
    self:doCannonMoving(dt)
    self:doUfoMoving(dt)
    self:doUfoPhasing(dt)
    self:doUfoSpawning()
    self:doCannonBooming(dt)
    self:doAlienBooming(dt)
    self:doBombBoomBooming(dt)
    self:doUfoBoomScoring(dt)
    self:doCannonFiring()
    self:doCollisionsUfoBorders()
    self:doCollisionsBombsHitbar()
    self:doCollisionsBombsCannon()
    self:doCollisionsBombsLaser()
    self:doCollisionsLaserAliens()
    self:doCollisionsBunkersBombs()
    self:doCollisionsBunkersLaser()
    self:doCollisionsBunkersAliens()
    self:doCollisionsLaserUfo()
    self:doCollisionsLaserSky()
    self:doVictoryTest()
    self:doVictory(dt)
    self:doInvasionTest()
    self:doGameOver(dt)
    self:updateActiveCycleBeat()
    self:doBeats(dt)
end

-- ─── draw ─────────────────────────────────────────────────────────────────────
function Game:draw()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)

    if not self.isRoundIntro then
        -- Aliens
        for r = 1, GRID_H do
            for c = 1, GRID_W do
                local alien = self.grid[r][c]
                if alien.alive then
                    local ac  = alienClasses[alien.classId]
                    local bmp = self.bitmaps[ac.bmp[alien.frame]]
                    love.graphics.setColor(table.unpack(ac.color))
                    bmp:draw(alien.x, alien.y)
                end
            end
        end

        -- Alien boom
        if self.isAliensBooming and self.alienBoomer then
            local ab = self.alienBoomer
            local ac = alienClasses[ab.classId]
            local bmp = self.bitmaps["alienboom"]
            love.graphics.setColor(table.unpack(ac.color))
            bmp:draw(ab.x, ab.y)
        end
    end

    -- UFO
    if self.ufo.alive and self.ufo.phase then
        local uc  = ufoClasses[self.ufo.classId]
        local bmp = self.bitmaps[uc.shipBmp]
        love.graphics.setColor(table.unpack(uc.color))
        bmp:draw(self.ufo.x, self.ufo.y)
    elseif self.isUfoBooming then
        local uc  = ufoClasses[self.ufo.classId]
        local bmp = self.bitmaps[uc.boomBmp]
        love.graphics.setColor(table.unpack(uc.color))
        bmp:draw(self.ufo.x, self.ufo.y)
    end

    -- UFO score text
    if self.isUfoScoring and self.ufoScoringText then
        love.graphics.setColor(1, 0, 1, 1)
        self.si.font:draw(self.ufoScoringText, self.ufoScoringX, self.ufoScoringY,
            1, 0, 1)
    end

    -- Cannon
    if self.cannon.booming then
        local bmp = self.bitmaps["cannonboom" .. (self.cannon.boomFrame - 1)]
        love.graphics.setColor(1, 0, 0, 1)
        bmp:draw(self.cannon.x, self.cannon.y)
    elseif self.cannon.alive then
        love.graphics.setColor(1, 0, 0, 1)
        self.bitmaps["cannon0"]:draw(self.cannon.x, self.cannon.y)
    end

    -- Bombs
    for _, bomb in ipairs(self.activeBombs) do
        local bc  = bombClasses[bomb.classId]
        local bmp = self.bitmaps[bc.bmp[bomb.frame]]
        love.graphics.setColor(table.unpack(colorPalette[bc.colorIdx]))
        bmp:draw(bomb.x, bomb.y)
    end

    -- Bomb booms
    for _, boom in ipairs(self.activeBombBooms) do
        local key = (boom.hit == BOMBHIT_BOTTOM) and "bombboombottom" or "bombboommidair"
        local bmp = self.bitmaps[key]
        love.graphics.setColor(table.unpack(colorPalette[boom.colorIdx] or { 1, 1, 1 }))
        bmp:draw(boom.x, boom.y)
    end

    -- Laser
    if self.laser.alive then
        love.graphics.setColor(1, 1, 1, 1)
        self.bitmaps["laser0"]:draw(self.laser.x, self.laser.y)
    end

    -- Bunkers
    love.graphics.setColor(0, 1, 0, 1)
    for _, bunker in ipairs(self.bunkers) do
        bunker.bmp:draw(bunker.x, bunker.y)
    end

    -- Hitbar
    love.graphics.setColor(0, 1, 0, 1)
    self.hitbarBmp:draw(0, self.hitbarY)

    -- HUD message
    if self.hudMsg then
        local mw = self.si.font:stringWidth(self.hudMsg)
        local mx = (WORLD_W - mw) / 2
        love.graphics.setColor(table.unpack(self.hudMsgColor))
        self.si.font:draw(self.hudMsg, mx, MSG_HEIGHT_Y,
            self.hudMsgColor[1], self.hudMsgColor[2], self.hudMsgColor[3])
    end
end

return Game
