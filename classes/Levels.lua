-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local LevelManager = {}
LevelManager.__index = LevelManager

function LevelManager.new()
    local instance = setmetatable({}, LevelManager)

    instance.levels = {
        {
            -- Level 1
            name = "Simple Turn",
            map = {
                { x = 3, y = 3, type = "laser",  dir = "right" },
                { x = 6, y = 3, type = "mirror", state = "M3" },
                { x = 6, y = 5, type = "target" }
            }
        },
        {
            -- Level 2
            name = "Double Approach",
            map = {
                { x = 2, y = 2, type = "laser",  dir = "right" },
                { x = 5, y = 2, type = "mirror", state = "M3" },
                { x = 5, y = 7, type = "target" },
                { x = 6, y = 3, type = "target" },
                { x = 6, y = 7, type = "mirror", state = "M3" },
                { x = 9, y = 7, type = "laser",  dir = "left" }
            }
        },
        {
            -- Level 3
            name = "Wall Barriers",
            map = {
                { x = 2, y = 2, type = "laser",  dir = "right" },
                { x = 6, y = 2, type = "mirror", state = "M3" },
                { x = 6, y = 5, type = "mirror", state = "M3" },
                { x = 7, y = 2, type = "wall" },
                { x = 5, y = 3, type = "wall" },
                { x = 5, y = 4, type = "wall" },
                { x = 2, y = 5, type = "target" },
                { x = 5, y = 6, type = "wall" },
                { x = 5, y = 7, type = "wall" }
            }
        },
        {
            -- Level 4
            name = "Split Reflection",
            map = {
                { x = 2, y = 2, type = "laser",   dir = "right" },
                { x = 9, y = 2, type = "mirror",  state = "M3" },
                { x = 5, y = 3, type = "mirror",  state = "M3" },
                { x = 9, y = 6, type = "mirror",  state = "M3" },
                { x = 5, y = 9, type = "mirror",  state = "M3" },
                { x = 7, y = 3, type = "target" },
                { x = 7, y = 9, type = "target" },
                { x = 5, y = 6, type = "splitter" }
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
