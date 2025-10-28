-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local HEADER_TEXT = "LaserReflex - Level: (%d) %s"
local WIN_TEXT = "All targets hit! Press N for next level."
local SIDE_TEXT = "Targets: %d / %d"
local FOOTER_TEXT = "LaserReflex - Copyright (c) 2025 Jericho Crosby (Chalwk)"

local string_format = string.format

local love_print = love.graphics.print
local love_printf = love.graphics.printf
local setFont = love.graphics.setFont

local Game = {}
Game.__index = Game

function Game.new(levelManager, grid, soundManager, colors)
    local instance = setmetatable({}, Game)

    instance.levelManager = levelManager
    instance.grid = grid
    instance.currentLevel = 1
    instance.selected = { x = nil, y = nil }
    instance.font = love.graphics.newFont(14)
    instance.sounds = soundManager
    instance.colors = colors

    return instance
end

function Game:loadLevel(levelIndex)
    self.currentLevel = levelIndex
    local levelData = self.levelManager:getLevel(levelIndex)
    self.grid:loadLevel(levelData)
    self.selected = { x = nil, y = nil }
end

function Game:onResize(w, h)
    self.grid:calculateTileSize(w, h)
end

function Game:draw()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    self.grid:draw()

    setFont(self.font)
    self.colors:setColor("white")

    local levelName = self.levelManager:getLevelName(self.currentLevel)
    love_printf(string_format(HEADER_TEXT, self.currentLevel, levelName), 8, 6, screenWidth - 16, "center")

    local hitCount, totalTargets = self.grid:getTargetProgress()

    love_print(string_format(SIDE_TEXT, hitCount, totalTargets), 8, 28)

    -- Update winning state based on current progress
    if totalTargets > 0 and hitCount == totalTargets then
        self.winningState = true
    else
        self.winningState = false
    end

    if self.winningState then
        self.colors:setColor("neon_green_glow")
        love_printf(string_format(WIN_TEXT), 0, 48, screenWidth, "center")
    end

    self.colors:setColor("white", 0.7)
    love_printf(string_format(FOOTER_TEXT), 0, screenHeight - 30, screenWidth, "center")
end

function Game:update(dt)
    self.grid:update(dt)
end

function Game:onMousePressed(x, y, button)
    local gx, gy = self.grid:screenToGrid(x, y)
    if not gx then return end

    if button == 1 then
        self.selected.x, self.selected.y = gx, gy
        self.grid:rotateMirror(gx, gy, 1)
        self.winningState = false -- Clear winning state on interaction
    elseif button == 2 then
        self.grid:rotateMirror(gx, gy, -1)
        self.winningState = false -- Clear winning state on interaction
    end
end

function Game:onKeyPressed(key)
    if key == 'r' then
        self:loadLevel(self.currentLevel)
        self.winningState = false
    elseif key == 'n' then
        local nextLevel = self.currentLevel % #self.levelManager.levels + 1
        self:loadLevel(nextLevel)
        self.winningState = false
    elseif key == 'p' then
        local prevLevel = (self.currentLevel - 2) % #self.levelManager.levels + 1
        self:loadLevel(prevLevel)
        self.winningState = false
    elseif key == 'escape' then
        love.event.quit()
    elseif key == 'q' or key == 'e' then
        if self.selected.x then
            local delta = (key == 'e') and 1 or -1
            self.grid:rotateMirror(self.selected.x, self.selected.y, delta)
            self.winningState = false -- Clear winning state on interaction
        end
    end
end

return Game
