-- Pathfinder - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local table_sort = table.sort
local table_insert = table.insert
local table_remove = table.remove

local math_abs = math.abs
local math_min = math.min
local math_floor = math.floor

local love_random = love.math.random

-- Predefined constants
local LASER_COLORS = { "red", "blue", "green", "yellow" }
local TILE_TYPES = { "straight", "curve", "t_junction", "cross", "dead_end" }
local PROBABILITY_WEIGHTS = { -- tile weights
    0.3,                      -- straight (most common)
    0.25,                     -- curve
    0.2,                      -- t_junction
    0.1,                      -- cross
    0.15,                     -- dead_end
}
local DIRECTIONS = {
    { dx = 1, dy = 0 }, { dx = -1, dy = 0 },
    { dx = 0, dy = 1 }, { dx = 0, dy = -1 },
}

local CUMULATIVE_WEIGHTS = {}
do
    local total = 0
    for i, weight in ipairs(PROBABILITY_WEIGHTS) do
        total = total + weight
        CUMULATIVE_WEIGHTS[i] = total
    end
end

local DIST_COMPARE = function(a, b) return a.dist < b.dist end

local LevelGenerator = {}
LevelGenerator.__index = LevelGenerator

function LevelGenerator.new()
    local instance = setmetatable({}, LevelGenerator)
    instance.levelNumber = 1
    return instance
end

local function placeLasersAndTargets(levelData, gridSize)
    levelData.lasers = {}
    levelData.targets = {}

    local numPairs = math_min(levelData.levelNumber, 4) -- Up to 4 laser-target pairs

    -- For levels 1-4, use 1 pair; levels 5-8 use 2 pairs, etc.
    numPairs = math_min(math_floor((levelData.levelNumber + 3) / 4), 4)

    for i = 1, numPairs do
        local color = LASER_COLORS[i]
        local side1, side2

        -- Ensure lasers and targets are on different sides
        repeat
            side1 = love_random(4)
            side2 = love_random(4)
        until side1 ~= side2

        local laserX, laserY, laserDir, targetX, targetY

        -- Place laser on side1
        if side1 == 1 then                                                       -- top
            laserX, laserY, laserDir = love_random(2, gridSize - 1), 1, 2        -- down
        elseif side1 == 2 then                                                   -- right
            laserX, laserY, laserDir = gridSize, love_random(2, gridSize - 1), 3 -- left
        elseif side1 == 3 then                                                   -- bottom
            laserX, laserY, laserDir = love_random(2, gridSize - 1), gridSize, 0 -- up
        else                                                                     -- left
            laserX, laserY, laserDir = 1, love_random(2, gridSize - 1), 1        -- right
        end

        -- Place target on side2
        if side2 == 1 then     -- top
            targetX, targetY = love_random(2, gridSize - 1), 1
        elseif side2 == 2 then -- right
            targetX, targetY = gridSize, love_random(2, gridSize - 1)
        elseif side2 == 3 then -- bottom
            targetX, targetY = love_random(2, gridSize - 1), gridSize
        else                   -- left
            targetX, targetY = 1, love_random(2, gridSize - 1)
        end

        table_insert(levelData.lasers, {
            x = laserX,
            y = laserY,
            dir = laserDir,
            color = color
        })

        table_insert(levelData.targets, {
            x = targetX,
            y = targetY,
            color = color
        })
    end
end

local function getTileConnections(path, index)
    local pos = path[index]
    local connections = { up = false, right = false, down = false, left = false }

    -- Check neighbors in path
    for _, neighbor in ipairs(path) do
        if neighbor.x == pos.x and neighbor.y == pos.y - 1 then connections.up = true end
        if neighbor.x == pos.x + 1 and neighbor.y == pos.y then connections.right = true end
        if neighbor.x == pos.x and neighbor.y == pos.y + 1 then connections.down = true end
        if neighbor.x == pos.x - 1 and neighbor.y == pos.y then connections.left = true end
    end

    return connections
end

local function determineTileType(c)
    local up, right, down, left = c.up, c.right, c.down, c.left
    local count = (up and 1 or 0) + (right and 1 or 0) + (down and 1 or 0) + (left and 1 or 0)

    if count == 4 then
        return "cross"
    elseif count == 3 then
        return "t_junction"
    elseif count == 2 then
        return (up == down or left == right) and "straight" or "curve"
    elseif count == 1 then
        return "dead_end"
    else
        return "empty"
    end
end

local function generatePath(levelData)
    -- Cache levelData properties
    local gridSize = levelData.gridSize
    local complexity = levelData.complexity
    local targetX, targetY = levelData.target.x, levelData.target.y
    local tiles = levelData.tiles

    -- Start with laser position
    local currentX, currentY = levelData.laser.x, levelData.laser.y
    local path = { { x = currentX, y = currentY } }
    local visited = {}
    visited[currentY * gridSize + currentX] = true

    -- A* pathfinding to target
    while currentX ~= targetX or currentY ~= targetY do
        -- Get possible moves
        local moves = {}

        for _, dir in ipairs(DIRECTIONS) do
            local newX, newY = currentX + dir.dx, currentY + dir.dy
            if newX >= 1 and newX <= gridSize and newY >= 1 and newY <= gridSize then
                local key = newY * gridSize + newX
                if not visited[key] then
                    local distToTarget = math_abs(newX - targetX) + math_abs(newY - targetY)
                    table_insert(moves, { x = newX, y = newY, dist = distToTarget })
                end
            end
        end

        if #moves == 0 then
            -- Backtrack if stuck
            if #path > 1 then
                table_remove(path)
                currentX, currentY = path[#path].x, path[#path].y
            else
                break
            end
        else
            -- Choose next move (prefer moves toward target, but add some randomness)
            table_sort(moves, DIST_COMPARE)

            local chosenIndex = 1
            if #moves > 1 and love_random() < complexity then
                chosenIndex = love_random(1, math_min(3, #moves))
            end

            currentX, currentY = moves[chosenIndex].x, moves[chosenIndex].y
            table_insert(path, { x = currentX, y = currentY })
            visited[currentY * gridSize + currentX] = true
        end
    end

    -- Place path tiles
    for i, pos in ipairs(path) do
        local connections = getTileConnections(path, i)
        if not tiles[pos.y] then tiles[pos.y] = {} end
        tiles[pos.y][pos.x] = {
            type = determineTileType(connections),
            rotation = 0, -- Will be randomized later
            connections = connections
        }
    end
end

local function fillRemainingTiles(levelData)
    local gridSize = levelData.gridSize
    local tiles = levelData.tiles
    local totalWeight = CUMULATIVE_WEIGHTS[#CUMULATIVE_WEIGHTS]

    for y = 1, gridSize do
        -- Ensure the row exists
        if not tiles[y] then
            tiles[y] = {}
        end
        for x = 1, gridSize do
            -- Check if tile exists and is empty, or if tile doesn't exist
            if not tiles[y][x] or tiles[y][x].type == "empty" then
                -- Weighted random selection using precomputed cumulative weights
                local r = love_random() * totalWeight
                for i = 1, #TILE_TYPES do
                    if r <= CUMULATIVE_WEIGHTS[i] then
                        tiles[y][x] = {
                            type = TILE_TYPES[i],
                            rotation = love_random(0, 3)
                        }
                        break
                    end
                end
            end
        end
    end
end

local function randomizeRotations(levelData)
    local gridSize = levelData.gridSize
    local tiles = levelData.tiles

    for y = 1, gridSize do
        if tiles[y] then
            for x = 1, gridSize do
                if tiles[y][x] and tiles[y][x].type ~= "empty" then
                    tiles[y][x].rotation = love_random(0, 3)
                end
            end
        end
    end
end

function LevelGenerator:generateLevel(levelIndex)
    self.levelNumber = levelIndex or self.levelNumber + 1

    -- Grid size increases with level difficulty
    local baseSize = 7
    local sizeIncrease = math_floor((levelIndex - 1) / 3)
    local gridSize = math_min(baseSize + sizeIncrease, 12)

    local levelData = {
        gridSize = gridSize,
        lasers = {},
        targets = {},
        tiles = {},
        levelNumber = levelIndex,
        complexity = math_min(0.3 + (levelIndex - 1) * 0.1, 0.8)
    }

    -- Place multiple lasers and targets
    placeLasersAndTargets(levelData, gridSize)

    -- Generate paths for each laser-target pair
    for i, laser in ipairs(levelData.lasers) do
        local target = levelData.targets[i]
        if target then
            -- Temporarily set single laser/target for path generation
            levelData.laser = laser
            levelData.target = target
            generatePath(levelData)
            levelData.laser = nil
            levelData.target = nil
        end
    end

    -- Fill remaining tiles with random road pieces
    fillRemainingTiles(levelData)

    -- Randomize tile rotations to create the puzzle
    randomizeRotations(levelData)

    return levelData
end

return LevelGenerator
