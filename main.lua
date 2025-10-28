-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local GameManager = require("classes/GameManager")
local Grid = require("classes/Grid")
local LevelManager = require("classes/LevelManager")

local gameManager, grid, levelManager

function love.load()
    levelManager = LevelManager.new()
    grid = Grid.new()
    gameManager = GameManager.new(levelManager, grid)

    -- Get initial window size and trigger resize calculation
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

function love.mousepressed(x, y, button)
    gameManager:onMousePressed(x, y, button)
end

function love.keypressed(key)
    gameManager:onKeyPressed(key)
end