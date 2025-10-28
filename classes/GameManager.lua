-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Game = {}
Game.__index = Game

function Game.new(levelManager, grid)
    local instance = setmetatable({}, Game)

    instance.levelManager = levelManager
    instance.grid = grid
    instance.currentLevel = 1
    instance.selected = { x = nil, y = nil }
    instance.font = love.graphics.newFont(14)

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

    love.graphics.clear(0.06, 0.06, 0.06)

    self.grid:draw()

    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1)

    local levelName = self.levelManager:getLevelName(self.currentLevel)
    love.graphics.printf("LaserReflex - Level: (" .. self.currentLevel .. ") " .. levelName,
        8, 6, screenWidth - 16, "center")

    local hitCount, totalTargets = self.grid:getTargetProgress()
    love.graphics.print(string.format("Targets: %d / %d", hitCount, totalTargets), 8, 28)

    if totalTargets > 0 and hitCount == totalTargets then
        love.graphics.setColor(0.8, 1, 0.6)
        love.graphics.printf("All targets hit! Press N for next level.", 0, 48, screenWidth, "center")
    end

    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(
        "LaserReflex - Copyright (c) 2025 Jericho Crosby (Chalwk)",
        0,
        screenHeight - 30,
        screenWidth,
        "center")
end

function Game:onMousePressed(x, y, button)
    local gx, gy = self.grid:screenToGrid(x, y)
    if not gx then return end

    if button == 1 then
        self.selected.x, self.selected.y = gx, gy
        self.grid:rotateMirror(gx, gy, 1)
    elseif button == 2 then
        self.grid:rotateMirror(gx, gy, -1)
    end
end

function Game:onKeyPressed(key)
    if key == 'r' then
        self:loadLevel(self.currentLevel)
    elseif key == 'n' then
        local nextLevel = self.currentLevel % #self.levelManager.levels + 1
        self:loadLevel(nextLevel)
    elseif key == 'p' then
        local prevLevel = (self.currentLevel - 2) % #self.levelManager.levels + 1
        self:loadLevel(prevLevel)
    elseif key == 'escape' then
        love.event.quit()
    elseif key == 'q' or key == 'e' then
        if self.selected.x then
            local delta = (key == 'e') and 1 or -1
            self.grid:rotateMirror(self.selected.x, self.selected.y, delta)
        end
    end
end

return Game
