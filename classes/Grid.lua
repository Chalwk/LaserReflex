-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local math_floor = math.floor
local math_sin = math.sin
local math_min = math.min
local math_max = math.max

local next = next
local ipairs = ipairs
local tostring = tostring
local table_insert = table.insert
local table_remove = table.remove

local string_format = string.format

local setLineWidth = love.graphics.setLineWidth
local rectangle = love.graphics.rectangle
local circle = love.graphics.circle
local polygon = love.graphics.polygon
local line = love.graphics.line

local Grid = {}
Grid.__index = Grid

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

    -- Directions: 0=up, 1=right, 2=down, 3=left
    instance.dirVecs = {
        { x = 0,  y = -1 },
        { x = 1,  y = 0 },
        { x = 0,  y = 1 },
        { x = -1, y = 0 },
    }

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

    -- For gradual beam propagation
    instance.beamProgress = 0
    instance.beamSpeed = 5.5 -- tiles per second
    instance.activeBeamPath = {}
    instance.targetX, instance.targetY = nil, nil

    return instance
end

local function inBounds(self, x, y)
    return x >= 1 and x <= self.gw and y >= 1 and y <= self.gh
end

local function tileAt(self, x, y)
    if not inBounds(self, x, y) then return nil end
    return self.grid[y][x]
end

local function explore(self, x, y, incomingDir, visited, path)
    if not inBounds(self, x, y) then return false end

    local key = x .. "," .. y .. "," .. incomingDir
    if visited[key] then
        return false
    end
    visited[key] = true

    local tile = tileAt(self, x, y)
    if not tile or tile.type == "empty" then return false end

    -- Get tile connections for current rotation
    local connections = self.roadTileTypes[tile.type][tile.rotation + 1]

    -- Check if we can enter this tile from incoming direction
    -- The incoming direction should match the connection on that side
    local canEnter = false
    if incomingDir == 0 then canEnter = connections.up end    -- Coming from top, need up connection
    if incomingDir == 1 then canEnter = connections.right end -- Coming from right, need right connection
    if incomingDir == 2 then canEnter = connections.down end  -- Coming from bottom, need down connection
    if incomingDir == 3 then canEnter = connections.left end  -- Coming from left, need left connection

    if not canEnter then return false end

    -- Add this position to path
    local pathSegment = { x = x, y = y, incomingDir = incomingDir }
    table_insert(path, pathSegment)

    -- Check if we reached the target
    if x == self.targetX and y == self.targetY then
        -- Found the target!
        self.activeBeamPath = {}
        for i, seg in ipairs(path) do
            table_insert(self.activeBeamPath, seg)
        end
        self.targetsHit[x .. "," .. y] = true
        print(string_format("Found path to target! Path length: %d", #self.activeBeamPath))
        return true
    end

    -- Explore connected directions (excluding the incoming direction)
    local dirs = { 0, 1, 2, 3 }
    for _, dir in ipairs(dirs) do
        if dir ~= incomingDir then -- Don't go back the way we came
            local canExit = false
            if dir == 0 then canExit = connections.up end
            if dir == 1 then canExit = connections.right end
            if dir == 2 then canExit = connections.down end
            if dir == 3 then canExit = connections.left end

            if canExit then
                local newX = x + self.dirVecs[dir + 1].x
                local newY = y + self.dirVecs[dir + 1].y

                -- Calculate the incoming direction for the next tile
                -- This is the opposite of the direction we're exiting
                local nextIncomingDir = (dir + 2) % 4

                if explore(self, newX, newY, nextIncomingDir, visited, path) then
                    return true
                end
            end
        end
    end

    -- Backtrack if no path found from this tile
    table_remove(path)
    return false
end

local function computeBeamPath(self)
    self.activeBeamPath = {}
    self.targetsHit = {}
    self.beamProgress = 0

    if #self.lasers == 0 then return end

    local laser = self.lasers[1]
    local visited = {}
    local path = {}

    -- Start from the tile in front of the laser
    local startX = laser.x + self.dirVecs[laser.d + 1].x
    local startY = laser.y + self.dirVecs[laser.d + 1].y

    -- Debug: print starting position
    print(string_format("Laser at (%d,%d) facing %d", laser.x, laser.y, laser.d))
    print(string_format("Starting beam at (%d,%d)", startX, startY))
    print(string_format("Target at (%d,%d)", self.targetX, self.targetY))

    -- Calculate initial incoming direction based on laser direction
    -- The beam enters the first tile from the opposite side of the laser direction
    local initialIncomingDir = (laser.d + 2) % 4

    -- Start exploration
    local found = explore(self, startX, startY, initialIncomingDir, visited, path)

    if not found then
        print("No path found to target")
        self.activeBeamPath = {}
    else
        print(string_format("Beam path computed with %d segments", #self.activeBeamPath))

        -- Debug: print path
        for i, seg in ipairs(self.activeBeamPath) do
            print(string_format("  %d: (%d,%d) incomingDir: %d", i, seg.x, seg.y, seg.incomingDir))
        end
    end
end

local function drawGrid(self, sx, sy)
    -- Base tile
    self.colors:setColor("moonlit_charcoal", 1)
    rectangle("fill", sx, sy, self.tileSize - 1, self.tileSize - 1)

    -- Subtle grid pattern
    self.colors:setColor("neutral_grey", 0.1)
    for i = 1, 3 do
        for j = 1, 3 do
            local px = sx + (i - 1) * (self.tileSize / 3)
            local py = sy + (j - 1) * (self.tileSize / 3)
            if (i + j) % 2 == 0 then
                rectangle("fill", px, py, self.tileSize / 3 - 1, self.tileSize / 3 - 1)
            end
        end
    end

    self.colors:setColor("white", 0.2)
    rectangle("line", sx, sy, self.tileSize - 1, self.tileSize - 1)
end

local function drawRoadTile(self, tileType, rotation, cx, cy, t)
    local size = self.tileSize * 0.3

    -- Base circle - different colors for special tiles
    if tileType == "laser" then
        self.colors:setColor("golden_wheat", 0.7)
    elseif tileType == "target" then
        self.colors:setColor("crimson_red", 0.7)
    else
        self.colors:setColor("road_base", 0.9)
    end
    circle("fill", cx, cy, size)

    -- Outline - different for special tiles
    if tileType == "laser" then
        self.colors:setColor("golden_yellow", 1)
    elseif tileType == "target" then
        self.colors:setColor("dark_red", 1)
    else
        self.colors:setColor("road_outline", 1)
    end
    setLineWidth(2)
    circle("line", cx, cy, size)

    -- Draw connections based on tile type and rotation
    local connections = self.roadTileTypes[tileType][rotation + 1]

    -- Connection lines - different colors for special tiles
    if tileType == "laser" then
        self.colors:setColor("golden_yellow", 0.8)
    elseif tileType == "target" then
        self.colors:setColor("crimson_red", 0.8)
    else
        self.colors:setColor("road_connection", 0.7)
    end
    setLineWidth(6)

    if connections.up then
        line(cx, cy, cx, cy - size)
    end
    if connections.right then
        line(cx, cy, cx + size, cy)
    end
    if connections.down then
        line(cx, cy, cx, cy + size)
    end
    if connections.left then
        line(cx, cy, cx - size, cy)
    end

    -- Special center symbols for laser and target
    if tileType == "laser" then
        -- Laser emitter symbol (triangle pointing in direction)
        self.colors:setColor("white_highlight", 1)
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
        self.colors:setColor("pastel_yellow", pulse)
        circle("fill", cx, cy, size * 0.15)
    elseif tileType == "target" then
        -- Target symbol (bullseye)
        self.colors:setColor("white_highlight", 1)
        setLineWidth(2)
        circle("line", cx, cy, size * 0.6)
        circle("line", cx, cy, size * 0.3)

        -- Center dot with hit effect
        local hit = self.targetsHit[cx .. "," .. cy] -- Simple check, you might want to use grid coordinates
        if hit then
            local glow = 0.8 + 0.2 * math_sin(t * 8)
            self.colors:setColor("neon_green", glow)
            circle("fill", cx, cy, size * 0.2)
        else
            self.colors:setColor("crimson_red", 1)
            circle("fill", cx, cy, size * 0.2)
        end
    else
        -- Regular road center dot
        self.colors:setColor("road_center", 0.9)
        circle("fill", cx, cy, size * 0.2)
    end

    setLineWidth(1)
end

local function drawLaser(self, direction, cx, cy, t)
    local pulse = 0.7 + 0.3 * math_sin(t * 5)
    local baseRadius = self.tileSize * 0.25

    -- Outer glow
    self.colors:setColor("golden_wheat", 0.4 * pulse)
    circle("fill", cx, cy, baseRadius * 1.4)

    -- Metallic base
    self.colors:setColor("dark_grey", 1)
    circle("fill", cx, cy, baseRadius)

    -- Metallic rings
    self.colors:setColor("soft_steel", 0.9)
    setLineWidth(2)
    circle("line", cx, cy, baseRadius)
    circle("line", cx, cy, baseRadius * 0.7)

    -- Pulsing core
    self.colors:setColor("pastel_yellow", pulse)
    circle("fill", cx, cy, baseRadius * 0.35 * pulse)

    -- Directional nozzle with glow
    self.colors:setColor("golden_yellow", 1)
    local nozzleLength = self.tileSize * 0.25
    local nozzleWidth = self.tileSize * 0.1

    if direction == 0 then -- up
        polygon("fill", cx, cy - nozzleLength, cx - nozzleWidth, cy, cx + nozzleWidth, cy)
        self.colors:setColor("golden_wheat", 1)
        polygon("line", cx, cy - nozzleLength, cx - nozzleWidth, cy, cx + nozzleWidth, cy)
    elseif direction == 1 then -- right
        polygon("fill", cx + nozzleLength, cy, cx, cy - nozzleWidth, cx, cy + nozzleWidth)
        self.colors:setColor("golden_wheat", 1)
        polygon("line", cx + nozzleLength, cy, cx, cy - nozzleWidth, cx, cy + nozzleWidth)
    elseif direction == 2 then -- down
        polygon("fill", cx, cy + nozzleLength, cx - nozzleWidth, cy, cx + nozzleWidth, cy)
        self.colors:setColor("golden_wheat", 1)
        polygon("line", cx, cy + nozzleLength, cx - nozzleWidth, cy, cx + nozzleWidth, cy)
    elseif direction == 3 then -- left
        polygon("fill", cx - nozzleLength, cy, cx, cy - nozzleWidth, cx, cy + nozzleWidth)
        self.colors:setColor("golden_wheat", 1)
        polygon("line", cx - nozzleLength, cy, cx, cy - nozzleWidth, cx, cy + nozzleWidth)
    end

    setLineWidth(1)
end

local function drawTarget(self, cx, cy, x, y, t)
    local hit = self.targetsHit[x .. "," .. y]
    local pulse = 0.8 + 0.2 * math_sin(t * 6)
    local r = self.tileSize * 0.22

    if hit then
        -- Hit effect
        local glowRadius = r * (1.5 + 0.3 * math_sin(t * 8))
        self.colors:setColor("neon_green_glow", 0.6 * pulse)
        circle("fill", cx, cy, glowRadius)

        -- Pulsing rings
        self.colors:setColor("neon_green", 0.4)
        setLineWidth(2)
        circle("line", cx, cy, r * 1.8 * pulse)
        circle("line", cx, cy, r * 1.4 * (1 - pulse * 0.5))
    end

    -- Main target body
    self.colors:setColor(hit and "neon_green" or "red", 1)
    circle("fill", cx, cy, r)

    -- Inner rings
    self.colors:setColor("white_highlight", 0.8)
    setLineWidth(2)
    circle("line", cx, cy, r * 0.7)
    circle("line", cx, cy, r * 0.4)

    -- Outer outline
    self.colors:setColor("black_outline", 0.8)
    setLineWidth(2.5)
    circle("line", cx, cy, r)

    setLineWidth(1)
end

local function drawGradualBeam(self, t)
    if #self.activeBeamPath == 0 then return end

    local pulse = 0.7 + 0.3 * math_sin(t * 8)
    local progress = math_min(self.beamProgress, #self.activeBeamPath)

    -- Draw the beam segments up to the current progress
    for i = 1, math_floor(progress) do
        local segment = self.activeBeamPath[i]
        local sx = self.gridOffsetX + (segment.x - 1) * self.tileSize + self.tileSize / 2
        local sy = self.gridOffsetY + (segment.y - 1) * self.tileSize + self.tileSize / 2

        -- Draw beam segment (glowing dot at each tile)
        self.colors:setColor("lime_green", 0.9 * pulse)
        setLineWidth(8)
        circle("fill", sx, sy, self.tileSize * 0.12)

        -- Draw connection to previous segment (if exists)
        if i > 1 then
            local prev = self.activeBeamPath[i - 1]
            local psx = self.gridOffsetX + (prev.x - 1) * self.tileSize + self.tileSize / 2
            local psy = self.gridOffsetY + (prev.y - 1) * self.tileSize + self.tileSize / 2

            -- Connection line with glow
            self.colors:setColor("lime_green", 0.4 * pulse)
            setLineWidth(12)
            line(psx, psy, sx, sy)

            self.colors:setColor("lime_green", 0.9 * pulse)
            setLineWidth(6)
            line(psx, psy, sx, sy)
        end
    end

    -- Draw partial progress to next segment
    local partial = progress - math_floor(progress)
    if partial > 0 and math_floor(progress) < #self.activeBeamPath then
        local currentIndex = math_floor(progress)
        local nextIndex = currentIndex + 1

        if currentIndex >= 1 and nextIndex <= #self.activeBeamPath then
            local currentSeg = self.activeBeamPath[currentIndex]
            local nextSeg = self.activeBeamPath[nextIndex]

            local csx = self.gridOffsetX + (currentSeg.x - 1) * self.tileSize + self.tileSize / 2
            local csy = self.gridOffsetY + (currentSeg.y - 1) * self.tileSize + self.tileSize / 2
            local nsx = self.gridOffsetX + (nextSeg.x - 1) * self.tileSize + self.tileSize / 2
            local nsy = self.gridOffsetY + (nextSeg.y - 1) * self.tileSize + self.tileSize / 2

            -- Interpolated position
            local isx = csx + (nsx - csx) * partial
            local isy = csy + (nsy - csy) * partial

            -- Draw partial connection
            self.colors:setColor("lime_green", 0.4 * pulse)
            setLineWidth(12)
            line(csx, csy, isx, isy)

            self.colors:setColor("lime_green", 0.9 * pulse)
            setLineWidth(6)
            line(csx, csy, isx, isy)

            -- Draw partial endpoint
            self.colors:setColor("lime_green", 0.9 * pulse)
            circle("fill", isx, isy, self.tileSize * 0.12)
        end
    end

    setLineWidth(1)
end

function Grid:getTile(x, y) return tileAt(self, x, y) end

function Grid:loadLevel(levelData)
    self.gw, self.gh = levelData.gridSize, levelData.gridSize
    self.grid, self.lasers, self.beams, self.targetsHit = {}, {}, {}, {}
    self.previouslyHit = {}
    self.beamProgress = 0
    self.activeBeamPath = {}
    self.targetX, self.targetY = nil, nil

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

    -- Place laser and target as proper road tiles
    if levelData.laser then
        local lx, ly, ld = levelData.laser.x, levelData.laser.y, levelData.laser.dir
        self.grid[ly][lx] = { type = "laser", rotation = ld }
        self.lasers = { { x = lx, y = ly, d = ld } }
    end

    if levelData.target then
        local tx, ty = levelData.target.x, levelData.target.y
        -- Target rotation should face toward the grid (opposite of laser direction)
        local targetDir = (levelData.laser.dir + 2) % 4
        self.grid[ty][tx] = { type = "target", rotation = targetDir }
        self.targetX, self.targetY = tx, ty
    end

    local w, h = love.graphics.getDimensions()
    self:calculateTileSize(w, h)

    computeBeamPath(self)
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
    computeBeamPath(self)
    self.sounds:play("rotate")
end

function Grid:getTargetProgress()
    local totalTargets = (self.targetX and self.targetY) and 1 or 0
    local hitCount = totalTargets > 0 and next(self.targetsHit) and 1 or 0
    return hitCount, totalTargets
end

function Grid:update(dt)
    -- Update beam progression
    if #self.activeBeamPath > 0 then
        self.beamProgress = self.beamProgress + self.beamSpeed * dt
        if self.beamProgress > #self.activeBeamPath then
            self.beamProgress = #self.activeBeamPath

            -- Emit particles when beam first reaches target
            if self.targetsHit[tostring(self.targetX) .. "," .. tostring(self.targetY)] and not self.previouslyHit then
                local screenX = self.gridOffsetX + (self.targetX - 1) * self.tileSize + self.tileSize / 2
                local screenY = self.gridOffsetY + (self.targetY - 1) * self.tileSize + self.tileSize / 2
                self.sounds:play("connect")
                self.previouslyHit = true
            end
        end
    else
        self.previouslyHit = false
    end
end

function Grid:draw()
    local t = love.timer.getTime()

    -- Draw grid background
    for y = 1, self.gh do
        for x = 1, self.gw do
            local sx = self.gridOffsetX + (x - 1) * self.tileSize
            local sy = self.gridOffsetY + (y - 1) * self.tileSize
            drawGrid(self, sx, sy)
        end
    end

    -- Draw road tiles
    for y = 1, self.gh do
        for x = 1, self.gw do
            local tile = tileAt(self, x, y)
            if tile and tile.type ~= "empty" then
                local sx = self.gridOffsetX + (x - 1) * self.tileSize
                local sy = self.gridOffsetY + (y - 1) * self.tileSize
                local cx = sx + self.tileSize / 2
                local cy = sy + self.tileSize / 2

                drawRoadTile(self, tile.type, tile.rotation, cx, cy, t)
            end
        end
    end

    -- Draw gradual beam
    drawGradualBeam(self, t)
end

return Grid
