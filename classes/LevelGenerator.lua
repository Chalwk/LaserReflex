-- Pathfinder - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local table_sort = table.sort
local table_insert = table.insert
local table_remove = table.remove

local math_max = math.max
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
    0.21,                      -- t_junction
    0.1,                      -- cross
    0.10,                     -- dead_end (previous 0.15)
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

local DIST_COMPARE = function(a, b) return a.f < b.f end

local LevelGenerator = {}
LevelGenerator.__index = LevelGenerator

function LevelGenerator.new()
    local instance = setmetatable({}, LevelGenerator)
    instance.levelNumber = 1
    return instance
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = love_random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function placeLasersAndTargets(levelData, gridSize)
    levelData.lasers = {}
    levelData.targets = {}

    local numPairs = math_min(levelData.levelNumber, 4) -- Up to 4 laser-target pairs

    -- For levels 1-4, use 1 pair; levels 5-8 use 2 pairs, etc.
    numPairs = math_min(math_floor((levelData.levelNumber + 3) / 4), 4)

    -- Ensure at least 1 pair
    numPairs = math_max(1, numPairs)

    local usedPositions = {}
    local availableSides = { 1, 2, 3, 4 }

    for i = 1, numPairs do
        local color = LASER_COLORS[i]
        local sidesCopy = {}
        for _, side in ipairs(availableSides) do table_insert(sidesCopy, side) end

        -- Not enough sides left, reuse sides but ensure different positions
        if #sidesCopy < 2 then sidesCopy = { 1, 2, 3, 4 } end

        -- Shuffle sides to ensure randomness
        sidesCopy = shuffle(sidesCopy)

        local side1, side2 = sidesCopy[1], sidesCopy[2]

        -- Remove used sides to avoid conflicts in next iterations
        for idx, side in ipairs(availableSides) do
            if side == side1 or side == side2 then
                table_remove(availableSides, idx)
                break
            end
        end

        local laserX, laserY, laserDir, targetX, targetY

        -- Place laser on side1 with position validation
        local laserPlaced = false
        local attempts = 0
        while not laserPlaced and attempts < 20 do
            attempts = attempts + 1
            if side1 == 1 then     -- top
                laserX, laserY = love_random(2, gridSize - 1), 1
                laserDir = 2       -- down
            elseif side1 == 2 then -- right
                laserX, laserY = gridSize, love_random(2, gridSize - 1)
                laserDir = 3       -- left
            elseif side1 == 3 then -- bottom
                laserX, laserY = love_random(2, gridSize - 1), gridSize
                laserDir = 0       -- up
            else                   -- left
                laserX, laserY = 1, love_random(2, gridSize - 1)
                laserDir = 1       -- right
            end

            local laserKey = laserX .. "," .. laserY
            if not usedPositions[laserKey] then
                usedPositions[laserKey] = true
                laserPlaced = true
            end
        end

        -- Place target on side2 with position validation
        local targetPlaced = false
        attempts = 0
        while not targetPlaced and attempts < 20 do
            attempts = attempts + 1
            if side2 == 1 then     -- top
                targetX, targetY = love_random(2, gridSize - 1), 1
            elseif side2 == 2 then -- right
                targetX, targetY = gridSize, love_random(2, gridSize - 1)
            elseif side2 == 3 then -- bottom
                targetX, targetY = love_random(2, gridSize - 1), gridSize
            else                   -- left
                targetX, targetY = 1, love_random(2, gridSize - 1)
            end

            local targetKey = targetX .. "," .. targetY
            if not usedPositions[targetKey] then
                usedPositions[targetKey] = true
                targetPlaced = true
            end
        end

        if laserPlaced and targetPlaced then
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
        else
            -- If we can't place this pair, stop trying more pairs
            break
        end
    end
end

local function getTileConnections(path, index)
    local pos = path[index]
    local CONNECTIONS = { up = false, right = false, down = false, left = false }

    -- Check neighbors in path
    for _, neighbor in ipairs(path) do
        if neighbor.x == pos.x and neighbor.y == pos.y - 1 then CONNECTIONS.up = true end
        if neighbor.x == pos.x + 1 and neighbor.y == pos.y then CONNECTIONS.right = true end
        if neighbor.x == pos.x and neighbor.y == pos.y + 1 then CONNECTIONS.down = true end
        if neighbor.x == pos.x - 1 and neighbor.y == pos.y then CONNECTIONS.left = true end
    end

    return CONNECTIONS
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

-- Heuristic function (Manhattan distance)
local function heuristic(x1, y1, x2, y2)
    return math_abs(x1 - x2) + math_abs(y1 - y2)
end

-- Improved A* pathfinding algorithm
local function aStarPathfinding(startX, startY, targetX, targetY, gridSize, complexity)
    -- Priority queue implementation
    local openSet = {}
    local closedSet = {}
    local cameFrom = {}

    -- Initialize start node
    local startNode = {
        x = startX,
        y = startY,
        g = 0, -- Cost from start
        h = heuristic(startX, startY, targetX, targetY),
        f = heuristic(startX, startY, targetX, targetY)
    }
    startNode.f = startNode.g + startNode.h

    table_insert(openSet, startNode)

    while #openSet > 0 do
        -- Get node with lowest f cost
        table_sort(openSet, DIST_COMPARE)
        local current = openSet[1]
        table_remove(openSet, 1)

        -- Check if we reached the target
        if current.x == targetX and current.y == targetY then
            -- Reconstruct path
            local path = {}
            local node = current
            while node do
                table_insert(path, 1, { x = node.x, y = node.y })
                node = cameFrom[node.x .. "," .. node.y]
            end
            return path
        end

        -- Add current to closed set
        closedSet[current.x .. "," .. current.y] = true

        -- Explore neighbors
        for _, dir in ipairs(DIRECTIONS) do
            local neighborX = current.x + dir.dx
            local neighborY = current.y + dir.dy

            -- Check bounds
            if neighborX >= 1 and neighborX <= gridSize and neighborY >= 1 and neighborY <= gridSize then
                local neighborKey = neighborX .. "," .. neighborY

                -- Skip if in closed set
                if not closedSet[neighborKey] then
                    local tentative_g = current.g + 1

                    -- Check if we found a better path to this neighbor
                    local inOpenSet = false
                    local neighborNode

                    for i, node in ipairs(openSet) do
                        if node.x == neighborX and node.y == neighborY then
                            inOpenSet = true
                            neighborNode = node
                            break
                        end
                    end

                    if not inOpenSet or tentative_g < neighborNode.g then
                        if not inOpenSet then
                            neighborNode = {
                                x = neighborX,
                                y = neighborY,
                                g = tentative_g,
                                h = heuristic(neighborX, neighborY, targetX, targetY)
                            }
                            neighborNode.f = neighborNode.g + neighborNode.h
                            table_insert(openSet, neighborNode)
                        else
                            neighborNode.g = tentative_g
                            neighborNode.f = neighborNode.g + neighborNode.h
                        end

                        cameFrom[neighborKey] = current
                    end
                end
            end
        end

        -- Add some randomness based on complexity to explore alternative paths
        if #openSet > 1 and love_random() < complexity * 0.3 then
            -- Occasionally shuffle the open set to explore different paths
            for i = #openSet, 2, -1 do
                local j = love_random(1, i)
                openSet[i], openSet[j] = openSet[j], openSet[i]
            end
        end
    end

    -- No path found
    return nil
end

local function fillRemainingTiles(levelData)
    local gridSize = levelData.gridSize
    local tiles = levelData.tiles
    local totalWeight = CUMULATIVE_WEIGHTS[#CUMULATIVE_WEIGHTS]

    for y = 1, gridSize do
        -- Ensure the row exists
        if not tiles[y] then tiles[y] = {} end
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

local function generateNonConflictingPaths(levelData)
    local gridSize = levelData.gridSize
    local tiles = levelData.tiles or {}

    -- Initialize tiles if not exists
    for y = 1, gridSize do
        if not tiles[y] then tiles[y] = {} end
        for x = 1, gridSize do
            if not tiles[y][x] then
                tiles[y][x] = { type = "empty", rotation = 0 }
            end
        end
    end

    -- Generate paths for each laser-target pair
    for i, laser in ipairs(levelData.lasers) do
        local target = levelData.targets[i]
        if target then
            local path = aStarPathfinding(laser.x, laser.y, target.x, target.y, gridSize, levelData.complexity)

            if path then
                -- Place path tiles, avoiding conflicts with existing paths
                for j, pos in ipairs(path) do
                    if not tiles[pos.y] then tiles[pos.y] = {} end

                    -- Only place tile if it's not already part of another path (except start/end)
                    if j == 1 or j == #path or not tiles[pos.y][pos.x] or tiles[pos.y][pos.x].type == "empty" then
                        local connections = getTileConnections(path, j)
                        tiles[pos.y][pos.x] = {
                            type = determineTileType(connections),
                            rotation = 0,
                            connections = connections
                        }
                    end
                end
            end
        end
    end

    levelData.tiles = tiles
end

local function validateLevelSolvability(levelData)
    local totalTargets = #levelData.targets
    local reachableTargets = 0

    -- Simple check: ensure each target has at least one possible path from its corresponding laser
    for i, laser in ipairs(levelData.lasers) do
        local target = levelData.targets[i]
        if target then
            local path = aStarPathfinding(laser.x, laser.y, target.x, target.y, levelData.gridSize, 0.1)
            if path then
                reachableTargets = reachableTargets + 1
            else
                print("No path found for " .. laser.color .. " laser to target")
            end
        end
    end

    local valid = reachableTargets == totalTargets
    if not valid then
        print("Level validation failed: " .. reachableTargets .. "/" .. totalTargets .. " targets reachable")
    end

    return valid
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

    -- Place multiple lasers and targets (with the fixed function)
    placeLasersAndTargets(levelData, gridSize)

    -- Generate non-conflicting paths for all laser-target pairs
    generateNonConflictingPaths(levelData)

    -- Validate level solvability and regenerate if needed
    local maxAttempts = 10
    local attempts = 0
    while attempts < maxAttempts and not validateLevelSolvability(levelData) do
        attempts = attempts + 1
        -- Regenerate paths
        levelData.tiles = {} -- Clear existing tiles
        generateNonConflictingPaths(levelData)
    end

    if attempts >= maxAttempts then
        print("Warning: Level " .. levelIndex .. " may not be fully solvable after " .. maxAttempts .. " attempts")
    end

    -- Fill remaining tiles with random road pieces
    fillRemainingTiles(levelData)

    -- Randomize tile rotations to create the puzzle
    randomizeRotations(levelData)

    return levelData
end

return LevelGenerator
