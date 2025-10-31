-- LaserReflex - Love2D
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

local TILE_TYPES = { "straight", "curve", "t_junction", "cross", "dead_end" }
local WEIGHTS = { 0.3, 0.25, 0.2, 0.1, 0.15 } -- Probability weights

-- Precomputed cumulative weights
local CUMULATIVE_WEIGHTS = {}
do
    local total = 0
    for i, weight in ipairs(WEIGHTS) do
        total = total + weight
        CUMULATIVE_WEIGHTS[i] = total
    end
end

-- Predefined constants
local DIRECTIONS = {
    {dx = 1, dy = 0}, {dx = -1, dy = 0},
    {dx = 0, dy = 1}, {dx = 0, dy = -1}
}

local DIST_COMPARE = function(a, b) return a.dist < b.dist end

local LevelGenerator = {}
LevelGenerator.__index = LevelGenerator

function LevelGenerator.new()
    local instance = setmetatable({}, LevelGenerator)
    instance.levelNumber = 1
    return instance
end

local function placeLaserAndTarget(levelData, gridSize)
    local side = love_random(4) -- 1: top, 2: right, 3: bottom, 4: left
    local laserX, laserY, laserDir, targetX, targetY

    if side == 1 then                                                        -- top
        laserX, laserY, laserDir = love_random(2, gridSize - 1), 1, 2        -- down
        targetX, targetY = love_random(2, gridSize - 1), gridSize
    elseif side == 2 then                                                    -- right
        laserX, laserY, laserDir = gridSize, love_random(2, gridSize - 1), 3 -- left
        targetX, targetY = 1, love_random(2, gridSize - 1)
    elseif side == 3 then                                                    -- bottom
        laserX, laserY, laserDir = love_random(2, gridSize - 1), gridSize, 0 -- up
        targetX, targetY = love_random(2, gridSize - 1), 1
    else                                                                     -- left
        laserX, laserY, laserDir = 1, love_random(2, gridSize - 1), 1        -- right
        targetX, targetY = gridSize, love_random(2, gridSize - 1)
    end

    levelData.laser = { x = laserX, y = laserY, dir = laserDir }
    levelData.target = { x = targetX, y = targetY }
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

local function determineTileType(connections)
    local count = 0
    if connections.up then count = count + 1 end
    if connections.right then count = count + 1 end
    if connections.down then count = count + 1 end
    if connections.left then count = count + 1 end

    if count == 2 then
        if (connections.up and connections.down) or (connections.left and connections.right) then
            return "straight"
        else
            return "curve"
        end
    elseif count == 3 then
        return "t_junction"
    elseif count == 4 then
        return "cross"
    else
        return "dead_end"
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

    -- Place path tiles - FIXED: Ensure the tile exists before accessing it
    for i, pos in ipairs(path) do
        local connections = getTileConnections(path, i)
        -- Initialize the row if it doesn't exist
        if not tiles[pos.y] then
            tiles[pos.y] = {}
        end
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
        laser = {},
        target = {},
        tiles = {},
        complexity = math_min(0.3 + (levelIndex - 1) * 0.1, 0.8) -- Controls path complexity
    }

    -- Place laser and target at random positions (ensuring they're not too close)
    placeLaserAndTarget(levelData, gridSize)

    -- Generate a solvable path
    generatePath(levelData)

    -- Fill remaining tiles with random road pieces
    fillRemainingTiles(levelData)

    -- Randomize tile rotations to create the puzzle
    randomizeRotations(levelData)

    return levelData
end

return LevelGenerator