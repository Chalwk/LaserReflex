-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Grid = require("classes/Grid")
local GameManager = require("classes/Game")
local LevelManager = require("classes.Levels")

local gameManager, grid, levelManager

function love.load()
    levelManager = LevelManager.new()
    grid = Grid.new()
    gameManager = GameManager.new(levelManager, grid)

    local w, h = love.graphics.getDimensions()
    gameManager:onResize(w, h)

    gameManager:loadLevel(1)
end

function love.resize(w, h)
    gameManager:onResize(w, h)
end

function love.draw()
    gameManager:draw()
end

function love.update(dt)
    gameManager:update(dt)
end

function love.mousepressed(x, y, button)
    gameManager:onMousePressed(x, y, button)
end

function love.keypressed(key)
    gameManager:onKeyPressed(key)
end
