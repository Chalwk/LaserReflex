-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Grid = require("classes.Grid")
local Game = require("classes.Game")
local Colors = require("classes.Colors")
local LevelManager = require("classes.Levels")
local SoundManager = require("classes.SoundManager")

local game, grid, levelManager

function love.load()
    local soundManager = SoundManager.new()
    levelManager = LevelManager.new()

    local colors = Colors.new()

    grid = Grid.new(soundManager, colors)
    game = Game.new(levelManager, grid, soundManager, colors)

    local w, h = love.graphics.getDimensions()
    game:onResize(w, h)

    game:loadLevel(1)
end

function love.resize(w, h)
    game:onResize(w, h)
end

function love.draw()
    game:draw()
end

function love.update(dt)
    game:update(dt)
end

function love.mousepressed(x, y, button)
    game:onMousePressed(x, y, button)
end

function love.keypressed(key)
    game:onKeyPressed(key)
end
