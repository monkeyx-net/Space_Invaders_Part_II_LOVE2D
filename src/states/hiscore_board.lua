-- states/hiscore_board.lua: animated hi-score leaderboard.
-- Mirrors C++ HiScoreBoardState.
-- New score bubbles up via swap animation, then exits to menu.
-- World coords: 448×256, Y=0 at bottom.

local Audio = require("audio")

local HiScoreBoard = {}
HiScoreBoard.__index = HiScoreBoard

-- ─── constants ────────────────────────────────────────────────────────────────
local ROW_SEP             = 2      -- extra pixels between rows
local COL_SEP             = 8      -- pixels between name and score columns
local BOARD_TITLE_SEP     = 20     -- pixels between board and title text
local SCORE_DIGIT_ESTIMATE= 4      -- typical digit count (for column width)
local ENTER_DELAY         = 1.0    -- seconds before swap starts
local TOP_SCORE_EXIT_DELAY= 7.0    -- extended exit delay if player got top score
local NORMAL_EXIT_DELAY   = 1.0
local SWAP_DELAY          = 0.5    -- seconds between each score swap step
local TITLE_STRING        = "*HI-SCORER LEADERBOARD*"
local PLACEHOLDER_NAME    = "YOU_"

-- ─── constructor ──────────────────────────────────────────────────────────────
function HiScoreBoard.new(si)
  local h = setmetatable({}, HiScoreBoard)
  h.si        = si
  h.titleUid  = nil
  return h
end

-- ─── enter ────────────────────────────────────────────────────────────────────
function HiScoreBoard:enter()
  local si   = self.si
  local font = si.font

  -- Build the newScore record
  local newScore = {
    name  = si.playerName or PLACEHOLDER_NAME,
    value = si.score,
    isNew = true,
  }
  -- Pad name to NAME_LEN
  while #newScore.name < 4 do newScore.name = newScore.name .. "_" end

  -- Board: newScore at index 1, then all 10 hi-scores in ascending order
  self.scoreBoard = {newScore}
  for _, s in ipairs(si.hiscores) do
    self.scoreBoard[#self.scoreBoard+1] = {name=s.name, value=s.value, isNew=false}
  end

  -- Compute layout
  local glyphW = font.size + font.glyphSpace
  local nameW  = glyphW * 4          -- 4-char names
  local scoreW = glyphW * SCORE_DIGIT_ESTIMATE
  local boardW = nameW + COL_SEP + scoreW
  local rowH   = font.lineSpace + ROW_SEP
  local boardH = (#self.scoreBoard) * rowH

  -- Centre horizontally; place in upper third vertically
  self.nameX   = (WORLD_W - boardW) / 2
  self.scoreX  = self.nameX + nameW + COL_SEP
  -- Top of first row in bottom-up coords
  self.topY    = WORLD_H / 3 + boardH / 2

  -- Title text above the board
  local titleW = font:stringWidth(TITLE_STRING)
  local titleX = (WORLD_W - titleW) / 2
  local titleY = self.topY + BOARD_TITLE_SEP

  self.titleUid = si.hud:addText(titleX, titleY, 0,1,1, TITLE_STRING)
  si:showHud()

  -- Event state machine
  self.eventNum    = 0
  self.eventClock  = 0
  self.exitDelay   = NORMAL_EXIT_DELAY
  self.rowH        = rowH
end

function HiScoreBoard:leave()
  if self.titleUid then
    self.si.hud:remove(self.titleUid)
    self.titleUid = nil
  end
end

-- ─── score swap ───────────────────────────────────────────────────────────────
-- Bubble the newScore entry up one position (toward the end of the
-- ascending list) if it belongs higher.  The drawing code displays the
-- list reversed so this movement will appear as a bubble-up animation on
-- screen.
-- Returns true if the new score is now in its final position (no more swaps needed).
function HiScoreBoard:doScoreSwap()
  for i = 1, #self.scoreBoard do
    if self.scoreBoard[i].isNew then
      if i == #self.scoreBoard then return true end  -- already at top
      if self.scoreBoard[i].value <= self.scoreBoard[i+1].value then return true end
      -- Swap up
      self.scoreBoard[i], self.scoreBoard[i+1] = self.scoreBoard[i+1], self.scoreBoard[i]
      Audio.play("scorebeep")
      return false
    end
  end
  return true   -- shouldn't reach here
end

function HiScoreBoard:newScoreIsTop()
  return self.scoreBoard[#self.scoreBoard].isNew
end

-- ─── update ───────────────────────────────────────────────────────────────────
function HiScoreBoard:update(dt)
  self.eventClock = self.eventClock + dt
  local boardSize = #self.scoreBoard

  if self.eventNum == 0 then
    -- Waiting for initial delay before swap starts
    if self.eventClock >= ENTER_DELAY then
      self.eventClock = 0
      self.eventNum   = 1
    end

  elseif self.eventNum > boardSize then
    -- All swaps done; wait then exit
    if self.eventClock >= self.exitDelay then
      local si = self.si
      -- Register the hi-score if it qualifies
      if si:isHiScore(si.score) then
        local name = si.playerName or PLACEHOLDER_NAME
        while #name < 4 do name = name .. "_" end
        local rec = {name=name, value=si.score}
        if not si:isDuplicateHiScore(rec) then
          si:registerHiScore(rec)
          si:writeHiScores()
        end
      end
      si:switchState("menu")
    end

  else
    -- Perform swap steps
    if self.eventClock >= SWAP_DELAY then
      self.eventClock = 0
      local done = self:doScoreSwap()
      if done then
        -- Skip to end
        self.eventNum = boardSize + 1
        if self:newScoreIsTop() then
          Audio.play("topscore")
          self.exitDelay = TOP_SCORE_EXIT_DELAY
        else
          self.exitDelay = NORMAL_EXIT_DELAY
        end
      else
        self.eventNum = self.eventNum + 1
      end
    end
  end
end

-- ─── draw ─────────────────────────────────────────────────────────────────────
function HiScoreBoard:draw()
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)

  local font = self.si.font

  -- Display rows in reverse order so the highest-value entry (last in
  -- ascending `scoreBoard`) appears at the top of the screen.  Internal
  -- logic (swapping, newScoreIsTop, etc.) still works with the original
  -- ascending ordering.
  for displayRow = 1, #self.scoreBoard do
    local idx = #self.scoreBoard - (displayRow - 1)
    local score = self.scoreBoard[idx]

    -- Row `displayRow`: row 1 at topY, each subsequent row lower (toward
    -- bottom of screen) by rowH.
    local ry = self.topY - (displayRow - 1) * self.rowH

    local r, g, b
    if score.isNew then
      r, g, b = 0, 1, 0       -- green for new score
    else
      r, g, b = 1, 0, 1       -- magenta for existing scores
    end

    -- Draw name (padded to 4 chars)
    local name = score.name
    while #name < 4 do name = name .. " " end
    name = name:sub(1, 4)

    font:draw(name,             self.nameX,  ry, r, g, b)
    font:draw(tostring(score.value), self.scoreX, ry, r, g, b)
  end
end

return HiScoreBoard
