-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ParticleSystem = require("classes.Particles")

local math_floor, math_sin, math_min, math_max, math_cos, math_rad = math.floor, math.sin, math.min, math.max, math.cos,
    math.rad
local pairs, ipairs = pairs, ipairs
local table_insert = table.insert

local setLineWidth = love.graphics.setLineWidth
local rectangle = love.graphics.rectangle
local circle = love.graphics.circle
local polygon = love.graphics.polygon
local line = love.graphics.line
local arc = love.graphics.arc

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

    instance.particleSystem = ParticleSystem.new()
    instance.previouslyHit = {}

    -- Directions: 0=up, 1=right, 2=down, 3=left
    instance.dirVecs = {
        { x = 0,  y = -1 },
        { x = 1,  y = 0 },
        { x = 0,  y = 1 },
        { x = -1, y = 0 },
    }

    instance.charToDir = { ['^'] = 0, ['>'] = 1, ['v'] = 2, ['<'] = 3 }
    instance.dirToChar = { ['up'] = '^', ['right'] = '>', ['down'] = 'v', ['left'] = '<' }

    -- M1: Forward slash (/)
    -- M2: Backslash (\)
    -- M3: Blocking
    instance.mirrorReflect = {
        -- Forward slash (/): reflects 90 degrees
        M1 = function(d)
            return d == 0 and 1 or d == 1 and 0 or d == 2 and 3 or d == 3 and 2 or nil
        end,

        -- Backslash (\): reflects 90 degrees
        M2 = function(d)
            return d == 0 and 3 or d == 1 and 2 or d == 2 and 1 or d == 3 and 0 or nil
        end,

        -- Blocking mirror
        M3 = function() return nil end
    }

    -- Beam Splitter: splits beam into perpendicular directions
    instance.beamSplitter = function(d)
        return d == 0 or d == 2 and { 1, 3 } or { 0, 2 }
    end

    instance.mirrorStates = { "M1", "M2", "M3" }

    return instance
end

local function inBounds(self, x, y)
    return x >= 1 and x <= self.gw and y >= 1 and y <= self.gh
end

local function tileAt(self, x, y)
    if not inBounds(self, x, y) then return nil end
    return self.grid[y][x]
end

local function setTile(self, x, y, ch)
    if inBounds(self, x, y) then self.grid[y][x] = ch end
end

local function addBeamSegment(self, x, y, d, startFrac, endFrac)
    table_insert(self.beams, { x = x, y = y, d = d, startFrac = startFrac, endFrac = endFrac })
end

local function computeBeams(self)
    self.beams = {}
    self.targetsHit = {}   -- Clear previous hits
    local currentHits = {} -- Track hits this frame

    for _, src in ipairs(self.lasers) do
        local sx, sy, sd = src.x, src.y, src.d
        local x, y, d = sx, sy, sd
        local visited = {}

        -- Move one tile outward from the laser
        x = x + self.dirVecs[d + 1].x
        y = y + self.dirVecs[d + 1].y

        while inBounds(self, x, y) do
            local key = x .. "," .. y .. "," .. d
            if visited[key] then break end
            visited[key] = true

            local ch = tileAt(self, x, y)

            if ch == '.' then
                addBeamSegment(self, x, y, d, -0.45, 0.45)
            elseif ch == '#' then
                break
            elseif ch == 'T' then
                addBeamSegment(self, x, y, d, -0.45, 0.0)
                currentHits[x .. "," .. y] = true
                self.targetsHit[x .. "," .. y] = true
                break
            elseif self.mirrorReflect[ch] then
                local incoming_dir = d
                local newdir = self.mirrorReflect[ch](d)

                if newdir then
                    -- Draw 90 degree turn inside the mirror tile
                    table_insert(self.beams, {
                        x = x,
                        y = y,
                        incoming_d = incoming_dir,
                        outgoing_d = newdir,
                        type = "mirror"
                    })
                    d = newdir
                else
                    -- Blocking mirror (M3)
                    addBeamSegment(self, x, y, d, -0.45, 0)
                    break
                end
            elseif ch == 'S' then
                -- Beam Splitter logic
                addBeamSegment(self, x, y, d, -0.15, 0.15)
                local splitDirs = self.beamSplitter(d)

                for _, nd in ipairs(splitDirs) do
                    local nx, ny = x + self.dirVecs[nd + 1].x, y + self.dirVecs[nd + 1].y
                    local visitedBranch = {}
                    for k, v in pairs(visited) do visitedBranch[k] = v end

                    while inBounds(self, nx, ny) do
                        local keyB = nx .. "," .. ny .. "," .. nd
                        if visitedBranch[keyB] then break end
                        visitedBranch[keyB] = true

                        local chB = tileAt(self, nx, ny)
                        if chB == '.' then
                            addBeamSegment(self, nx, ny, nd, -0.45, 0.45)
                        elseif chB == '#' then
                            break
                        elseif chB == 'T' then
                            addBeamSegment(self, nx, ny, nd, -0.45, 0.0)
                            currentHits[nx .. "," .. ny] = true
                            self.targetsHit[nx .. "," .. ny] = true
                            break
                        elseif self.mirrorReflect[chB] then
                            local incoming_d = nd
                            local newdirB = self.mirrorReflect[chB](nd)
                            if newdirB then
                                table_insert(self.beams, {
                                    x = nx,
                                    y = ny,
                                    incoming_d = incoming_d,
                                    outgoing_d = newdirB,
                                    type = "mirror"
                                })
                                nd = newdirB
                            else
                                addBeamSegment(self, nx, ny, nd, -0.45, 0)
                                break
                            end
                        elseif chB == 'S' then
                            break
                        else
                            break
                        end

                        nx = nx + self.dirVecs[nd + 1].x
                        ny = ny + self.dirVecs[nd + 1].y
                    end
                end

                break
            elseif self.charToDir[ch] then
                addBeamSegment(self, x, y, d, -0.45, 0.45)
            else
                break
            end

            x = x + self.dirVecs[d + 1].x
            y = y + self.dirVecs[d + 1].y
        end
    end

    -- Handle newly hit targets (particles, sounds)
    for coord, _ in pairs(currentHits) do
        if not self.previouslyHit[coord] then
            local x, y = coord:match("(%d+),(%d+)")
            x, y = tonumber(x), tonumber(y)
            local screenX = self.gridOffsetX + (x - 1) * self.tileSize + self.tileSize / 2
            local screenY = self.gridOffsetY + (y - 1) * self.tileSize + self.tileSize / 2
            self.particleSystem:emit(screenX, screenY, 15)
            self.sounds:play("connect")
        end
    end

    self.previouslyHit = currentHits
end

function Grid:loadLevel(levelData)
    self.gw, self.gh = 10, 10 -- temp hard-coded grid size
    self.grid, self.lasers, self.beams, self.targetsHit = {}, {}, {}, {}
    self.previouslyHit = {}

    -- Initialize empty grid
    for y = 1, self.gh do
        self.grid[y] = {}
        for x = 1, self.gw do
            self.grid[y][x] = '.'
        end
    end

    -- Place objects from the map definition
    for _, obj in ipairs(levelData.map) do
        if obj.type == "laser" then
            local char = self.dirToChar[obj.dir]
            setTile(self, obj.x, obj.y, char)
            table_insert(self.lasers, { x = obj.x, y = obj.y, d = self.charToDir[char] })
        elseif obj.type == "mirror" then
            setTile(self, obj.x, obj.y, obj.state)
        elseif obj.type == "target" then
            setTile(self, obj.x, obj.y, 'T')
        elseif obj.type == "wall" then
            setTile(self, obj.x, obj.y, '#')
        elseif obj.type == "splitter" then
            setTile(self, obj.x, obj.y, 'S')
        end
    end

    computeBeams(self)
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

function Grid:rotateMirror(x, y, delta)
    local ch = tileAt(self, x, y)
    if not ch then return end

    for i, state in ipairs(self.mirrorStates) do
        if ch == state then
            local newIndex = ((i - 1 + (delta or 1)) % #self.mirrorStates) + 1
            setTile(self, x, y, self.mirrorStates[newIndex])
            computeBeams(self)
            self.sounds:play("rotate")
            return
        end
    end
end

function Grid:getTargetProgress()
    local totalTargets, hitCount = 0, 0
    for y = 1, self.gh do
        for x = 1, self.gw do
            if tileAt(self, x, y) == 'T' then totalTargets = totalTargets + 1 end
        end
    end
    for _ in pairs(self.targetsHit) do hitCount = hitCount + 1 end
    return hitCount, totalTargets
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

-- Enhanced forward-slash mirror with filled back side
local function drawForwardSlash(self, cx, cy, r, t)
    -- Glass base with subtle animation
    self.colors:setColor("mirror_glass", 0.8 + 0.1 * math_sin(t * 2))
    circle("line", cx, cy, r)

    -- Reflective surface with glow
    self.colors:setColor("mirror_glow", 0.9)
    setLineWidth(3)
    local startAngle, endAngle = math_rad(-45), math_rad(135)
    arc("line", cx, cy, r, startAngle, endAngle)

    setLineWidth(1)
end

-- Enhanced backslash mirror with filled back side
local function drawBackSlash(self, cx, cy, r, t)
    -- Glass base
    self.colors:setColor("mirror_glass", 0.8 + 0.1 * math_sin(t * 2))
    circle("line", cx, cy, r)

    -- Reflective surface
    self.colors:setColor("mirror_glow", 0.9)
    setLineWidth(3)
    local startAngle, endAngle = math_rad(45), math_rad(225)
    arc("line", cx, cy, r, startAngle, endAngle)

    setLineWidth(1)
end

local function drawX(self, cx, cy, t)
    local r = self.tileSize * 0.42
    local pulse = 0.8 + 0.2 * math_sin(t * 3)

    -- Outer ring with pulse
    self.colors:setColor("mirror_disabled_outer", pulse)
    setLineWidth(3)
    circle("line", cx, cy, r)

    -- Inner fill
    self.colors:setColor("mirror_disabled_fill", 0.7)
    circle("fill", cx, cy, r * 0.7)

    -- Animated X
    self.colors:setColor("mirror_disabled_highlight", 1)
    setLineWidth(4)
    local crossSize = r * 0.5
    line(cx - crossSize, cy - crossSize, cx + crossSize, cy + crossSize)
    line(cx + crossSize, cy - crossSize, cx - crossSize, cy + crossSize)

    setLineWidth(1)
end

local function drawSplitter(self, cx, cy, t)
    local r = self.tileSize * 0.42
    local pulse = 0.7 + 0.3 * math_sin(t * 4)
    local rotation = t * 2

    -- Outer glow ring
    self.colors:setColor("splitter_glow", 0.6 * pulse)
    circle("fill", cx, cy, r * 1.2)

    -- Main rotating ring
    self.colors:setColor("splitter_base", 1)
    setLineWidth(3)
    circle("line", cx, cy, r)

    -- Animated cross pattern
    setLineWidth(4)
    self.colors:setColor("splitter_cross", pulse)
    local crossR = r * 0.6
    line(cx - crossR * math_cos(rotation), cy - crossR * math_sin(rotation),
        cx + crossR * math_cos(rotation), cy + crossR * math_sin(rotation))
    line(cx + crossR * math_sin(rotation), cy - crossR * math_cos(rotation),
        cx - crossR * math_sin(rotation), cy + crossR * math_cos(rotation))

    -- Pulsing core
    self.colors:setColor("splitter_core", 1)
    circle("fill", cx, cy, r * 0.2 * pulse)

    setLineWidth(1)
end

local function drawBeam(self, cx, cy, ox_start, oy_start, ox_end, oy_end, t)
    local pulse = 0.8 + 0.2 * math_sin(t * 8)

    -- Glow effect
    self.colors:setColor("lime_green", 0.3 * pulse)
    setLineWidth(6)
    line(cx + ox_start, cy + oy_start, cx + ox_end, cy + oy_end)

    -- Core beam
    self.colors:setColor("lime_green", 0.95 * pulse)
    setLineWidth(3)
    line(cx + ox_start, cy + oy_start, cx + ox_end, cy + oy_end)

    -- Bright center line
    self.colors:setColor("white_highlight", 1)
    setLineWidth(1)
    line(cx + ox_start, cy + oy_start, cx + ox_end, cy + oy_end)

    setLineWidth(1)
end

local function drawAngledBeam(self, cx, cy, incoming_d, outgoing_d, t)
    local pulse = 0.8 + 0.2 * math_sin(t * 8)

    local incoming_dir = self.dirVecs[incoming_d + 1]
    local outgoing_dir = self.dirVecs[outgoing_d + 1]
    local offset = self.tileSize * 0.45

    local start_x = cx - incoming_dir.x * offset
    local start_y = cy - incoming_dir.y * offset
    local end_x = cx + outgoing_dir.x * offset
    local end_y = cy + outgoing_dir.y * offset

    -- Glow effect
    self.colors:setColor("lime_green", 0.3 * pulse)
    setLineWidth(6)
    line(start_x, start_y, cx, cy)
    line(cx, cy, end_x, end_y)

    -- Core beam
    self.colors:setColor("lime_green", 0.95 * pulse)
    setLineWidth(3)
    line(start_x, start_y, cx, cy)
    line(cx, cy, end_x, end_y)

    -- Bright center line
    self.colors:setColor("white_highlight", 1)
    setLineWidth(1)
    line(start_x, start_y, cx, cy)
    line(cx, cy, end_x, end_y)

    setLineWidth(1)
end

local function drawWall(self, sx, sy)
    local size = self.tileSize - 8
    local inset = 3

    -- Main wall body
    self.colors:setColor("charcoal_gray", 1)
    rectangle("fill", sx + inset, sy + inset, size, size)

    -- 3D bevel effect
    self.colors:setColor("wall_highlight", 0.8)
    line(sx + inset, sy + inset, sx + inset + size, sy + inset) -- top
    line(sx + inset, sy + inset, sx + inset, sy + inset + size) -- left

    self.colors:setColor("wall_shadow", 0.8)
    line(sx + inset + size, sy + inset, sx + inset + size, sy + inset + size) -- right
    line(sx + inset, sy + inset + size, sx + inset + size, sy + inset + size) -- bottom

    -- Inner texture
    self.colors:setColor("wall_texture", 0.3)
    for i = 1, 2 do
        for j = 1, 2 do
            local px = sx + inset + i * (size / 3)
            local py = sy + inset + j * (size / 3)
            rectangle("fill", px, py, 2, 2)
        end
    end
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

local function drawLaser(self, ch, cx, cy, t)
    local d = self.charToDir[ch]
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

    if d == 0 then
        polygon("fill", cx, cy - nozzleLength, cx - nozzleWidth, cy, cx + nozzleWidth, cy)
        -- Nozzle glow
        self.colors:setColor("golden_wheat", 0.6)
        polygon("line", cx, cy - nozzleLength, cx - nozzleWidth, cy, cx + nozzleWidth, cy)
    elseif d == 1 then
        polygon("fill", cx + nozzleLength, cy, cx, cy - nozzleWidth, cx, cy + nozzleWidth)
        self.colors:setColor("golden_wheat", 0.6)
        polygon("line", cx + nozzleLength, cy, cx, cy - nozzleWidth, cx, cy + nozzleWidth)
    elseif d == 2 then
        polygon("fill", cx, cy + nozzleLength, cx - nozzleWidth, cy, cx + nozzleWidth, cy)
        self.colors:setColor("golden_wheat", 0.6)
        polygon("line", cx, cy + nozzleLength, cx - nozzleWidth, cy, cx + nozzleWidth, cy)
    elseif d == 3 then
        polygon("fill", cx - nozzleLength, cy, cx, cy - nozzleWidth, cx, cy + nozzleWidth)
        self.colors:setColor("golden_wheat", 0.6)
        polygon("line", cx - nozzleLength, cy, cx, cy - nozzleWidth, cx, cy + nozzleWidth)
    end

    setLineWidth(1)
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

    -- Draw beams
    for _, b in ipairs(self.beams) do
        local sx = self.gridOffsetX + (b.x - 1) * self.tileSize
        local sy = self.gridOffsetY + (b.y - 1) * self.tileSize
        local cx = sx + self.tileSize / 2
        local cy = sy + self.tileSize / 2

        if b.type == "mirror" then
            drawAngledBeam(self, cx, cy, b.incoming_d, b.outgoing_d, t)
        else
            local d = b.d
            local dir = self.dirVecs[d + 1]
            local ox_start = dir.x * self.tileSize * b.startFrac
            local oy_start = dir.y * self.tileSize * b.startFrac
            local ox_end = dir.x * self.tileSize * b.endFrac
            local oy_end = dir.y * self.tileSize * b.endFrac
            drawBeam(self, cx, cy, ox_start, oy_start, ox_end, oy_end, t)
        end
    end

    local r = self.tileSize * 0.42

    -- Draw tiles
    for y = 1, self.gh do
        for x = 1, self.gw do
            local ch = tileAt(self, x, y)
            local sx = self.gridOffsetX + (x - 1) * self.tileSize
            local sy = self.gridOffsetY + (y - 1) * self.tileSize
            local cx = sx + self.tileSize / 2
            local cy = sy + self.tileSize / 2

            if ch == '#' then
                drawWall(self, sx, sy)
            elseif ch == 'T' then
                drawTarget(self, cx, cy, x, y, t)
            elseif self.charToDir[ch] then
                drawLaser(self, ch, cx, cy, t)
            elseif self.mirrorReflect[ch] then
                if ch == "M1" then
                    drawForwardSlash(self, cx, cy, r, t)
                elseif ch == "M2" then
                    drawBackSlash(self, cx, cy, r, t)
                elseif ch == "M3" then
                    drawX(self, cx, cy, t)
                end
            elseif ch == 'S' then
                drawSplitter(self, cx, cy, t)
            end
        end
    end

    self.particleSystem:draw()
end

function Grid:update(dt)
    self.particleSystem:update(dt)
end

return Grid
