-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local LevelManager = {}
LevelManager.__index = LevelManager

function LevelManager.new()
    local instance = setmetatable({}, LevelManager)

    instance.levels = {
        -- Level 1: Basic single reflection
        {
            name = "Simple Turn",
            size = { 9, 9 },
            map = {
                { x = 3, y = 3, type = "laser",  dir = "right" },
                { x = 6, y = 3, type = "mirror", state = "M2" },
                { x = 6, y = 5, type = "target" }
            }
        },

        -- Level 2: Two lasers, two targets
        {
            name = "Double Approach",
            size = { 9, 9 },
            map = {
                { x = 2, y = 2, type = "laser",  dir = "right" },
                { x = 5, y = 2, type = "mirror", state = "M2" },
                { x = 7, y = 3, type = "target" },
                { x = 5, y = 7, type = "target" },
                { x = 7, y = 7, type = "mirror", state = "M2" },
                { x = 8, y = 7, type = "laser",  dir = "left" }
            }
        },

        -- Level 3: Introduce walls
        {
            name = "Wall Barriers",
            size = { 9, 9 },
            map = {
                { x = 2, y = 2, type = "laser",  dir = "right" },
                { x = 6, y = 2, type = "mirror", state = "M2" },
                { x = 6, y = 5, type = "mirror", state = "M2" },
                { x = 7, y = 2, type = "wall" },
                { x = 5, y = 3, type = "wall" },
                { x = 5, y = 4, type = "wall" },
                { x = 2, y = 5, type = "target" },
                { x = 5, y = 6, type = "wall" },
                { x = 5, y = 7, type = "wall" }
            }
        },

        -- Level 4: Multiple reflections
        {
            name = "Double Reflection",
            size = { 9, 9 },
            map = {
                { x = 2, y = 2, type = "laser",  dir = "right" },
                { x = 5, y = 2, type = "mirror", state = "M2" },
                { x = 3, y = 5, type = "target" },
                { x = 7, y = 2, type = "wall" },
                { x = 5, y = 3, type = "wall" },
                { x = 5, y = 4, type = "wall" },
                { x = 5, y = 5, type = "wall" },
                { x = 5, y = 6, type = "wall" },
                { x = 5, y = 7, type = "wall" }
            }
        },

        -- Level 5: U-shaped path
        {
            name = "The U-Turn",
            size = { 9, 9 },
            map = {
                { x = 3, y = 3, type = "laser",  dir = "right" },
                { x = 6, y = 3, type = "mirror", state = "M2" },
                { x = 5, y = 7, type = "target" },
                { x = 4, y = 5, type = "wall" },
                { x = 7, y = 5, type = "wall" }
            }
        },

        -- Level 6: Multiple targets, single laser
        {
            name = "Dual Targets",
            size = { 11, 11 },
            map = {
                { x = 4, y = 3, type = "laser",  dir = "right" },
                { x = 6, y = 5, type = "mirror", state = "M2" },
                { x = 3, y = 9, type = "target" },
                { x = 8, y = 9, type = "target" },
                { x = 4, y = 7, type = "wall" },
                { x = 8, y = 7, type = "wall" }
            }
        },

        -- Level 7: Maze-like structure
        {
            name = "Mirror Maze",
            size = { 11, 11 },
            map = {
                { x = 2, y = 3, type = "laser",  dir = "right" },
                { x = 6, y = 5, type = "mirror", state = "M2" },
                { x = 7, y = 9, type = "target" },
                { x = 2, y = 2, type = "wall" }, { x = 4, y = 2, type = "wall" }, { x = 6, y = 2, type = "wall" },
                { x = 8, y = 2, type = "wall" }, { x = 10, y = 2, type = "wall" }, { x = 2, y = 4, type = "wall" },
                { x = 4, y = 4, type = "wall" }, { x = 6, y = 4, type = "wall" }, { x = 8, y = 4, type = "wall" },
                { x = 10, y = 4, type = "wall" }, { x = 2, y = 6, type = "wall" }, { x = 4, y = 6, type = "wall" },
                { x = 6,  y = 6, type = "wall" }, { x = 8, y = 6, type = "wall" }, { x = 10, y = 6, type = "wall" },
                { x = 2, y = 8, type = "wall" }, { x = 4, y = 8, type = "wall" }, { x = 6, y = 8, type = "wall" },
                { x = 8, y = 8, type = "wall" }, { x = 10, y = 8, type = "wall" }, { x = 2, y = 10, type = "wall" },
                { x = 4,  y = 10, type = "wall" }, { x = 6, y = 10, type = "wall" }, { x = 8, y = 10, type = "wall" },
                { x = 10, y = 10, type = "wall" }
            }
        }
    }

    return instance
end

function LevelManager:getLevel(levelIndex)
    return self.levels[levelIndex]
end

function LevelManager:getLevelName(levelIndex)
    local level = self.levels[levelIndex]
    return level and level.name or tostring(levelIndex)
end

return LevelManager
