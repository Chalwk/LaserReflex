-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local math_floor = math.floor
local math_sin = math.sin
local math_min = math.min
local math_max = math.max

local ipairs = ipairs
local table_insert = table.insert
local table_remove = table.remove

local setLineWidth = love.graphics.setLineWidth
local rectangle = love.graphics.rectangle
local circle = love.graphics.circle
local polygon = love.graphics.polygon
local line = love.graphics.line

local Grid = {}
Grid.__index = Grid

local DIRS = { 0, 1, 2, 3 }

function Grid.new(soundManager, colors)
    local instance = setmetatable({}, Grid)

    instance.grid = {}
    instance.beams = {}
    instance.targetsHit = {}
    instance.lasers = {}

    instance.gw, instance.gh = 9, 9
    instance.tileSize = 48
    instance.gridOffsetX, instance.gridOffsetY = 40, 40

    instance.sounds = soundManager
    instance.colors = colors

    instance.previouslyHit = {}

    -- Multiple beam tracking
    instance.activeBeamPaths = {}
    instance.beamProgress = {}  -- Progress for each beam
    instance.previouslyHit = {} -- Track hit state for each target

    -- For gradual beam propagation
    instance.beamProgress = 0
    instance.beamSpeed = 5.5 -- tiles per second
    instance.activeBeamPath = {}
    instance.targetX, instance.targetY = nil, nil

    -- Directions: 0=up, 1=right, 2=down, 3=left
    instance.dirVecsX = { 0, 1, 0, -1 }
    instance.dirVecsY = { -1, 0, 1, 0 }

    -- Road tile connection patterns (for each rotation 0-3)
    instance.roadTileTypes = {
        straight = {
            { up = true,  right = false, down = true,  left = false }, -- rotation 0: vertical
            { up = false, right = true,  down = false, left = true },  -- rotation 1: horizontal
            { up = true,  right = false, down = true,  left = false }, -- rotation 2: vertical (same as 0)
            { up = false, right = true,  down = false, left = true }   -- rotation 3: horizontal (same as 1)
        },
        curve = {
            { up = true,  right = true,  down = false, left = false }, -- rotation 0: up-right
            { up = false, right = true,  down = true,  left = false }, -- rotation 1: right-down
            { up = false, right = false, down = true,  left = true },  -- rotation 2: down-left
            { up = true,  right = false, down = false, left = true }   -- rotation 3: left-up
        },
        t_junction = {
            { up = true,  right = true,  down = true,  left = false }, -- rotation 0: missing left
            { up = true,  right = true,  down = false, left = true },  -- rotation 1: missing down
            { up = false, right = true,  down = true,  left = true },  -- rotation 2: missing up
            { up = true,  right = false, down = true,  left = true }   -- rotation 3: missing right
        },
        cross = {
            { up = true, right = true, down = true, left = true }, -- rotation 0-3: all directions
            { up = true, right = true, down = true, left = true },
            { up = true, right = true, down = true, left = true },
            { up = true, right = true, down = true, left = true }
        },
        dead_end = {
            { up = true,  right = false, down = false, left = false },
            { up = false, right = true,  down = false, left = false },
            { up = false, right = false, down = true,  left = false },
            { up = false, right = false, down = false, left = true }
        },
        laser = { -- Laser acts as a dead_end that emits light
            { up = true,  right = false, down = false, left = false },
            { up = false, right = true,  down = false, left = false },
            { up = false, right = false, down = true,  left = false },
            { up = false, right = false, down = false, left = true }
        },
        target = { -- Target receives light from any direction
            { up = true, right = true, down = true, left = true },
            { up = true, right = true, down = true, left = true },
            { up = true, right = true, down = true, left = true },
            { up = true, right = true, down = true, left = true }
        }
    }

    return instance
end

local function inBounds(self, x, y)
    return x >= 1 and x <= self.gw and y >= 1 and y <= self.gh
end

local function tileAt(self, x, y)
    if not inBounds(self, x, y) then return nil end
    return self.grid[y][x]
end

local function getTileCenter(self, x, y)
    return self.gridOffsetX + (x - 1) * self.tileSize + self.tileSize / 2,
        self.gridOffsetY + (y - 1) * self.tileSize + self.tileSize / 2
end

local function explore(self, x, y, incomingDir, visited, path, targetColor)
    if not inBounds(self, x, y) then return false end

    local inDirKey = (incomingDir == nil) and 4 or incomingDir
    local key = y * (self.gw * 5) + x * 5 + inDirKey
    if visited[key] then return false end
    visited[key] = true

    local tile = tileAt(self, x, y)
    if not tile or tile.type == "empty" then return false end

    if tile.type == "laser" then
        table_insert(path, { x = x, y = y, incomingDir = incomingDir, color = tile.laserColor })
        local laserDir = tile.rotation
        local dirVecsX, dirVecsY = self.dirVecsX, self.dirVecsY
        local newX = x + dirVecsX[laserDir + 1]
        local newY = y + dirVecsY[laserDir + 1]
        local nextIncomingDir = (laserDir + 2) % 4

        if explore(self, newX, newY, nextIncomingDir, visited, path, targetColor) then
            return true
        end

        table_remove(path)
        return false
    end

    -- For regular tiles, get connections for current rotation
    local connections = self.roadTileTypes[tile.type][tile.rotation + 1]

    -- Check if we can enter this tile from incoming direction
    local canEnter = false
    if incomingDir == 0 then canEnter = connections.up end
    if incomingDir == 1 then canEnter = connections.right end
    if incomingDir == 2 then canEnter = connections.down end
    if incomingDir == 3 then canEnter = connections.left end

    if not canEnter then return false end

    -- Add this position to path
    local pathSegment = { x = x, y = y, incomingDir = incomingDir }
    if tile.type == "target" then pathSegment.color = tile.targetColor end
    table_insert(path, pathSegment)

    -- Check if we reached a target of the correct color
    if tile.type == "target" and tile.targetColor == targetColor then
        self.activeBeamPaths[targetColor] = {}
        for _, seg in ipairs(path) do
            table_insert(self.activeBeamPaths[targetColor], seg)
        end
        self.targetsHit[x .. "," .. y] = true
        return true
    end

    -- Explore connected directions (excluding the incoming direction)
    local dirVecsX, dirVecsY = self.dirVecsX, self.dirVecsY
    for _, dir in ipairs(DIRS) do
        if dir ~= incomingDir then
            local canExit = false
            if dir == 0 then canExit = connections.up end
            if dir == 1 then canExit = connections.right end
            if dir == 2 then canExit = connections.down end
            if dir == 3 then canExit = connections.left end

            if canExit then
                local newX = x + dirVecsX[dir + 1]
                local newY = y + dirVecsY[dir + 1]
                local nextIncomingDir = (dir + 2) % 4

                if explore(self, newX, newY, nextIncomingDir, visited, path, targetColor) then
                    return true
                end
            end
        end
    end

    -- Backtrack if no path found from this tile
    table_remove(path)
    return false
end

local function computeBeamPaths(self)
    self.activeBeamPaths = {}
    self.targetsHit = {}
    self.beamProgress = {}
    self.previouslyHit = {}

    for i, laser in ipairs(self.lasers) do
        local visited = {}
        local path = {}
        local found = explore(self, laser.x, laser.y, nil, visited, path, laser.color)

        if found then
            self.beamProgress[laser.color] = 0
            self.previouslyHit[laser.color] = false
        else
            self.activeBeamPaths[laser.color] = {}
        end
    end
end

local function drawGrid(self, sx, sy)
    local colors = self.colors
    local tileSize = self.tileSize

    -- Base tile
    colors:setColor("moonlit_charcoal", 1)
    rectangle("fill", sx, sy, tileSize - 1, tileSize - 1)

    -- Subtle grid pattern
    colors:setColor("neutral_grey", 0.1)
    local thirdSize = tileSize / 3
    for i = 1, 3 do
        for j = 1, 3 do
            local px = sx + (i - 1) * thirdSize
            local py = sy + (j - 1) * thirdSize
            if (i + j) % 2 == 0 then
                rectangle("fill", px, py, thirdSize - 1, thirdSize - 1)
            end
        end
    end

    colors:setColor("white", 0.2)
    rectangle("line", sx, sy, tileSize - 1, tileSize - 1)
end

local function drawRoadTile(self, tileType, rotation, cx, cy, t, gx, gy)
    local tileSize = self.tileSize
    local colors = self.colors
    local size = tileSize * 0.3
    local tile = tileAt(self, gx, gy)

    -- Base circle - different colors for special tiles
    if tileType == "laser" then
        local laserColor = tile.laserColor or "red"
        colors:setColor("laser_" .. laserColor, 0.7)
    elseif tileType == "target" then
        local targetColor = tile.targetColor or "red"
        colors:setColor("target_" .. targetColor, 0.7)
    else
        colors:setColor("road_base", 0.9)
    end
    circle("fill", cx, cy, size)

    -- Outline - different for special tiles
    if tileType == "laser" then
        local laserColor = tile.laserColor or "red"
        colors:setColor("laser_" .. laserColor .. "_glow", 1)
    elseif tileType == "target" then
        local targetColor = tile.targetColor or "red"
        colors:setColor("target_" .. targetColor .. "_glow", 1)
    else
        colors:setColor("road_outline", 1)
    end
    setLineWidth(2)
    circle("line", cx, cy, size)

    -- Draw connections based on tile type and rotation
    local connections = self.roadTileTypes[tileType][rotation + 1]

    -- Connection lines - different colors for special tiles
    if tileType == "laser" then
        local laserColor = tile.laserColor or "red"
        colors:setColor("laser_" .. laserColor .. "_glow", 0.8)
    elseif tileType == "target" then
        local targetColor = tile.targetColor or "red"
        colors:setColor("target_" .. targetColor .. "_glow", 0.8)
    else
        colors:setColor("road_connection", 0.7)
    end
    setLineWidth(6)

    if connections.up then line(cx, cy, cx, cy - size) end
    if connections.right then line(cx, cy, cx + size, cy) end
    if connections.down then line(cx, cy, cx, cy + size) end
    if connections.left then line(cx, cy, cx - size, cy) end

    -- Special center symbols for laser and target
    if tileType == "laser" then
        -- Laser emitter symbol (triangle pointing in direction)
        colors:setColor("white_highlight", 1)
        local pulse = 0.7 + 0.3 * math_sin(t * 5)
        local emitterSize = size * 0.4

        if rotation == 0 then     -- up
            polygon("fill", cx, cy - emitterSize, cx - emitterSize, cy + emitterSize, cx + emitterSize, cy + emitterSize)
        elseif rotation == 1 then -- right
            polygon("fill", cx + emitterSize, cy, cx - emitterSize, cy - emitterSize, cx - emitterSize, cy + emitterSize)
        elseif rotation == 2 then -- down
            polygon("fill", cx, cy + emitterSize, cx - emitterSize, cy - emitterSize, cx + emitterSize, cy - emitterSize)
        elseif rotation == 3 then -- left
            polygon("fill", cx - emitterSize, cy, cx + emitterSize, cy - emitterSize, cx + emitterSize, cy + emitterSize)
        end

        -- Pulsing core
        local laserColor = tile.laserColor or "red"
        colors:setColor("laser_" .. laserColor .. "_glow", pulse)
        circle("fill", cx, cy, size * 0.15)
    elseif tileType == "target" then
        -- Target symbol (bullseye)
        colors:setColor("white_highlight", 1)
        setLineWidth(2)
        circle("line", cx, cy, size * 0.6)
        circle("line", cx, cy, size * 0.3)

        -- Center dot with hit effect
        local hit = self.targetsHit[gx .. "," .. gy]
        local targetColor = tile.targetColor or "red"
        if hit then
            local glow = 0.8 + 0.2 * math_sin(t * 8)
            colors:setColor("target_" .. targetColor .. "_glow", glow)
            circle("fill", cx, cy, size * 0.2)
        else
            colors:setColor("target_" .. targetColor, 1)
            circle("fill", cx, cy, size * 0.2)
        end
    else
        -- Regular road center dot
        colors:setColor("road_center", 0.9)
        circle("fill", cx, cy, size * 0.2)
    end

    setLineWidth(1)
end

local function drawGradualBeams(self, t)
    local colors = self.colors
    local tileSize = self.tileSize

    for beamColor, activeBeamPath in pairs(self.activeBeamPaths) do
        if #activeBeamPath == 0 then goto continue end

        local pulse = 0.7 + 0.3 * math_sin(t * 8)
        local progress = math_min(self.beamProgress[beamColor] or 0, #activeBeamPath)

        -- Draw the beam segments up to the current progress
        for i = 2, math_floor(progress) do
            local segment = activeBeamPath[i]
            local sx, sy = getTileCenter(self, segment.x, segment.y)

            -- Draw beam segment (glowing dot at each tile)
            colors:setColor("beam_" .. beamColor, 0.9 * pulse)
            setLineWidth(8)
            circle("fill", sx, sy, tileSize * 0.12)

            -- Draw connection to previous segment (if exists)
            local prev = activeBeamPath[i - 1]
            local psx, psy = getTileCenter(self, prev.x, prev.y)

            -- Connection line with glow
            colors:setColor("beam_" .. beamColor, 0.4 * pulse)
            setLineWidth(3)
            line(psx, psy, sx, sy)

            colors:setColor("beam_" .. beamColor, 0.9 * pulse)
            setLineWidth(3)
            line(psx, psy, sx, sy)
        end

        -- Draw partial progress to next segment
        local partial = progress - math_floor(progress)
        if partial > 0 and math_floor(progress) < #activeBeamPath then
            local currentIndex = math_floor(progress)
            local nextIndex = currentIndex + 1

            if currentIndex >= 1 and nextIndex <= #activeBeamPath then
                local currentSeg = activeBeamPath[currentIndex]
                local nextSeg = activeBeamPath[nextIndex]

                local csx, csy = getTileCenter(self, currentSeg.x, currentSeg.y)
                local nsx, nsy = getTileCenter(self, nextSeg.x, nextSeg.y)

                -- Interpolated position
                local isx = csx + (nsx - csx) * partial
                local isy = csy + (nsy - csy) * partial

                -- Draw partial connection
                colors:setColor("beam_" .. beamColor, 0.4 * pulse)
                setLineWidth(12)
                line(csx, csy, isx, isy)

                colors:setColor("beam_" .. beamColor, 0.9 * pulse)
                setLineWidth(6)
                line(csx, csy, isx, isy)

                -- Draw partial endpoint
                colors:setColor("beam_" .. beamColor, 0.9 * pulse)
                circle("fill", isx, isy, tileSize * 0.12)
            end
        end

        ::continue::
    end

    setLineWidth(1)
end

function Grid:getTile(x, y) return tileAt(self, x, y) end

function Grid:loadLevel(levelData)
    self.gw, self.gh = levelData.gridSize, levelData.gridSize
    self.grid, self.lasers, self.beams, self.targetsHit = {}, {}, {}, {}
    self.previouslyHit = {}
    self.beamProgress = {}
    self.activeBeamPaths = {}
    self.targets = levelData.targets or {}

    -- Initialize grid with road tiles
    for y = 1, self.gh do
        self.grid[y] = {}
        for x = 1, self.gw do
            if levelData.tiles[y] and levelData.tiles[y][x] then
                self.grid[y][x] = levelData.tiles[y][x]
            else
                self.grid[y][x] = { type = "empty", rotation = 0 }
            end
        end
    end

    -- Place multiple lasers as proper road tiles
    if levelData.lasers then
        for _, laser in ipairs(levelData.lasers) do
            local lx, ly, ld, color = laser.x, laser.y, laser.dir, laser.color
            self.grid[ly][lx] = {
                type = "laser",
                rotation = ld,
                laserColor = color
            }
            table_insert(self.lasers, { x = lx, y = ly, d = ld, color = color })
        end
    end

    -- Place multiple targets as proper road tiles
    if levelData.targets then
        for _, target in ipairs(levelData.targets) do
            local tx, ty, color = target.x, target.y, target.color
            self.grid[ty][tx] = {
                type = "target",
                rotation = 0, -- Targets can receive from any direction
                targetColor = color
            }
        end
    end

    local w, h = love.graphics.getDimensions()
    self:calculateTileSize(w, h)

    computeBeamPaths(self)
end

function Grid:calculateTileSize(winw, winh)
    local maxTileW = math_floor((winw - 160) / self.gw)
    local maxTileH = math_floor((winh - 160) / self.gh)
    self.tileSize = math_max(24, math_min(64, math_min(maxTileW, maxTileH)))
    self.gridOffsetX = math_floor((winw - self.gw * self.tileSize) / 2)
    self.gridOffsetY = math_floor((winh - self.gh * self.tileSize) / 2)
end

function Grid:screenToGrid(sx, sy)
    local gx = math_floor((sx - self.gridOffsetX) / self.tileSize) + 1
    local gy = math_floor((sy - self.gridOffsetY) / self.tileSize) + 1
    if inBounds(self, gx, gy) then return gx, gy end
end

function Grid:rotateTile(x, y, delta)
    local tile = tileAt(self, x, y)
    if not tile or tile.type == "empty" then return end

    tile.rotation = (tile.rotation + (delta or 1)) % 4
    computeBeamPaths(self)
    self.sounds:play("rotate")
end

function Grid:getTargetProgress()
    local totalTargets = #self.targets
    local hitCount = 0

    for _, hit in pairs(self.targetsHit) do
        if hit then hitCount = hitCount + 1 end
    end

    return hitCount, totalTargets
end

function Grid:update(dt)
    -- Update beam progression for each active beam
    for beamColor, path in pairs(self.activeBeamPaths) do
        local pathLength = #path
        if pathLength > 0 then
            self.beamProgress[beamColor] = (self.beamProgress[beamColor] or 0) + self.beamSpeed * dt
            if self.beamProgress[beamColor] > pathLength then
                self.beamProgress[beamColor] = pathLength

                -- Check if target was just hit
                local lastSegment = path[#path]
                local targetKey = lastSegment.x .. "," .. lastSegment.y
                if self.targetsHit[targetKey] and not (self.previouslyHit[beamColor]) then
                    self.sounds:play("connect")
                    self.previouslyHit[beamColor] = true
                end
            end
        else
            self.previouslyHit[beamColor] = false
        end
    end
end

function Grid:draw()
    local t = love.timer.getTime()
    local gridOffsetX, gridOffsetY = self.gridOffsetX, self.gridOffsetY
    local tileSize = self.tileSize
    local gw, gh = self.gw, self.gh

    -- Draw grid background
    for y = 1, gh do
        for x = 1, gw do
            local sx = gridOffsetX + (x - 1) * tileSize
            local sy = gridOffsetY + (y - 1) * tileSize
            drawGrid(self, sx, sy)
        end
    end

    -- Draw road tiles
    for y = 1, gh do
        for x = 1, gw do
            local tile = tileAt(self, x, y)
            if tile and tile.type ~= "empty" then
                local sx = gridOffsetX + (x - 1) * tileSize
                local sy = gridOffsetY + (y - 1) * tileSize
                local cx = sx + tileSize / 2
                local cy = sy + tileSize / 2

                drawRoadTile(self, tile.type, tile.rotation, cx, cy, t, x, y)
            end
        end
    end

    -- Draw gradual beams for all active lasers
    drawGradualBeams(self, t)
end

return Grid
