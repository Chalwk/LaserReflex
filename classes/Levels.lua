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
        },
        {
            -- Level 5
            name = "Corner Bounce",
            map = {
                { x = 2, y = 2, type = "laser",  dir = "right" },
                { x = 6, y = 2, type = "wall" },
                { x = 6, y = 3, type = "wall" },
                { x = 6, y = 4, type = "wall" },
                { x = 7, y = 4, type = "mirror", state = "M1" },
                { x = 9, y = 5, type = "target" }
            }
        },
        {
            -- Level 6
            name = "Wall Maze",
            map = {
                { x = 2, y = 2, type = "laser",  dir = "right" },
                { x = 5, y = 2, type = "wall" },
                { x = 5, y = 3, type = "wall" },
                { x = 5, y = 4, type = "wall" },
                { x = 5, y = 6, type = "wall" },
                { x = 5, y = 7, type = "wall" },
                { x = 5, y = 8, type = "wall" },
                { x = 8, y = 2, type = "mirror", state = "M2" },
                { x = 9, y = 5, type = "target" }
            }
        },
        {
            -- Level 7
            name = "Split Decision",
            map = {
                { x = 2, y = 2, type = "laser",   dir = "right" },
                { x = 5, y = 2, type = "splitter" },
                { x = 5, y = 3, type = "wall" },
                { x = 5, y = 4, type = "wall" },
                { x = 5, y = 5, type = "wall" },
                { x = 8, y = 2, type = "target" },
                { x = 8, y = 6, type = "target" }
            }
        },
        {
            -- Level 8
            name = "Reflection Corridor",
            map = {
                { x = 2, y = 2, type = "laser",  dir = "right" },
                { x = 6, y = 2, type = "wall" },
                { x = 6, y = 3, type = "wall" },
                { x = 6, y = 4, type = "wall" },
                { x = 6, y = 6, type = "wall" },
                { x = 6, y = 7, type = "wall" },
                { x = 6, y = 8, type = "wall" },
                { x = 8, y = 4, type = "mirror", state = "M2" },
                { x = 9, y = 5, type = "target" }
            }
        },
        {
            -- Level 9
            name = "The Crossfire",
            map = {
                { x = 2,  y = 2,  type = "laser",   dir = "right" },
                { x = 10, y = 10, type = "laser",   dir = "left" },
                { x = 5,  y = 2,  type = "splitter" },
                { x = 5,  y = 3,  type = "wall" },
                { x = 5,  y = 4,  type = "wall" },
                { x = 5,  y = 5,  type = "wall" },
                { x = 5,  y = 8,  type = "wall" },
                { x = 5,  y = 9,  type = "wall" },
                { x = 8,  y = 2,  type = "target" },
                { x = 8,  y = 6,  type = "target" }
            }
        },
        {
            -- Level 10
            name = "Corner Walls",
            map = {
                { x = 2, y = 2, type = "laser",  dir = "right" },
                { x = 8, y = 2, type = "target" },
                { x = 5, y = 2, type = "mirror", state = "M3" },
                { x = 5, y = 5, type = "mirror", state = "M3" },
                { x = 8, y = 5, type = "mirror", state = "M3" },
                { x = 3, y = 4, type = "mirror", state = "M3" },
                { x = 6, y = 1, type = "wall" },
                { x = 6, y = 2, type = "wall" },
                { x = 6, y = 3, type = "wall" }
            }
        },
        {
            -- Level 11
            name = "Maze Split",
            map = {
                { x = 2, y = 3, type = "laser",   dir = "right" },
                { x = 6, y = 3, type = "splitter" },
                { x = 9, y = 3, type = "target" },
                { x = 9, y = 6, type = "target" },
                { x = 5, y = 3, type = "mirror",  state = "M3" },
                { x = 5, y = 6, type = "mirror",  state = "M3" },
                { x = 8, y = 6, type = "mirror",  state = "M3" },
                { x = 4, y = 4, type = "mirror",  state = "M3" },
                { x = 7, y = 2, type = "wall" },
                { x = 7, y = 3, type = "wall" },
                { x = 7, y = 4, type = "wall" }
            }
        },
        {
            -- Level 12
            name = "Red Herring Alley",
            map = {
                { x = 1,  y = 5, type = "laser",  dir = "right" },
                { x = 10, y = 5, type = "target" },
                { x = 3,  y = 5, type = "mirror", state = "M3" },
                { x = 4,  y = 3, type = "mirror", state = "M3" },
                { x = 6,  y = 5, type = "mirror", state = "M3" },
                { x = 8,  y = 5, type = "mirror", state = "M3" },
                { x = 3,  y = 4, type = "wall" },
                { x = 3,  y = 6, type = "wall" },
                { x = 5,  y = 4, type = "wall" },
                { x = 5,  y = 6, type = "wall" },
                { x = 7,  y = 4, type = "wall" },
                { x = 7,  y = 6, type = "wall" }
            }
        },
        {
            -- Level 13
            name = "Blocked Corridor",
            map = {
                { x = 5, y = 1, type = "laser",  dir = "down" },
                { x = 5, y = 9, type = "target" },
                { x = 5, y = 3, type = "mirror", state = "M3" },
                { x = 3, y = 4, type = "mirror", state = "M3" },
                { x = 7, y = 6, type = "mirror", state = "M3" },
                { x = 4, y = 4, type = "wall" },
                { x = 6, y = 4, type = "wall" },
                { x = 4, y = 6, type = "wall" },
                { x = 6, y = 6, type = "wall" }
            }
        },
        {
            -- Level 14
            name = "Mirror Maze Finale",
            map = {
                { x = 2, y = 8, type = "laser",  dir = "right" },
                { x = 9, y = 8, type = "target" },
                { x = 9, y = 2, type = "target" },
                { x = 4, y = 8, type = "mirror", state = "M3" },
                { x = 4, y = 7, type = "mirror", state = "M3" },
                { x = 6, y = 6, type = "mirror", state = "M3" },
                { x = 8, y = 4, type = "mirror", state = "M3" },
                { x = 4, y = 7, type = "wall" },
                { x = 4, y = 8, type = "wall" },
                { x = 4, y = 9, type = "wall" },
                { x = 6, y = 6, type = "wall" },
                { x = 6, y = 7, type = "wall" },
                { x = 6, y = 8, type = "wall" }
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
