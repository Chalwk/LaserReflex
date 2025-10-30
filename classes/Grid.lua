-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ParticleSystem = require("classes.Particles")

local math_floor, math_sin, math_min, math_max = math.floor, math.sin, math.min, math.max
local pairs, ipairs = pairs, ipairs
local table_insert = table.insert

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
            -- Up -> Right
            -- Right -> Up
            -- Down -> Left
            -- Left -> Down
            return d == 0 and 1 or d == 1 and 0 or d == 2 and 3 or d == 3 and 2 or nil
        end,

        -- Backslash (\): reflects 90 degrees
        M2 = function(d)
            -- Up -> Left
            -- Right -> Down
            -- Down -> Right
            -- Left -> Up
            return d == 0 and 3 or d == 1 and 2 or d == 2 and 1 or d == 3 and 0 or nil
        end,

        -- Blocking mirror
        M3 = function() return nil end
    }

    -- Beam Splitter: splits beam into perpendicular directions
    instance.beamSplitter = function(d)
        -- Up/Down -> Right/Left
        -- Right/Left -> Up/Down
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
    self.targetsHit = {}   -- Clear previous hits at start of computation
    local currentHits = {} -- Track hits in current frame

    for _, src in ipairs(self.lasers) do
        local sx, sy, sd = src.x, src.y, src.d
        local x, y, d = sx, sy, sd
        local visited = {}

        -- Move beam out of laser starting position
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
                    -- Store angled beam segment with both directions
                    table_insert(self.beams, {
                        x = x, y = y,
                        incoming_d = incoming_dir,
                        outgoing_d = newdir,
                        type = "mirror"
                    })
                    d = newdir
                else
                    -- Blocking mirror - just show incoming beam
                    addBeamSegment(self, x, y, d, -0.45, 0)
                    break
                end
            elseif ch == 'S' then
                -- Beam Splitter: split into two perpendicular directions
                addBeamSegment(self, x, y, d, -0.15, 0.15)

                -- Get the two split directions
                local splitDirs = self.beamSplitter(d)

                -- Process first split beam
                local d1 = splitDirs[1]
                local x1, y1 = x + self.dirVecs[d1 + 1].x, y + self.dirVecs[d1 + 1].y
                local visited1 = {}
                for k, v in pairs(visited) do visited1[k] = v end

                while inBounds(self, x1, y1) do
                    local key1 = x1 .. "," .. y1 .. "," .. d1
                    if visited1[key1] then break end
                    visited1[key1] = true

                    local ch1 = tileAt(self, x1, y1)
                    if ch1 == '.' then
                        addBeamSegment(self, x1, y1, d1, -0.45, 0.45)
                    elseif ch1 == '#' then
                        break
                    elseif ch1 == 'T' then
                        addBeamSegment(self, x1, y1, d1, -0.45, 0.0)
                        currentHits[x1 .. "," .. y1] = true
                        self.targetsHit[x1 .. "," .. y1] = true
                        break
                    elseif self.mirrorReflect[ch1] then
                        addBeamSegment(self, x1, y1, d1, -0.15, 0.15)
                        local newdir1 = self.mirrorReflect[ch1](d1)
                        if newdir1 then d1 = newdir1 else break end
                    elseif ch1 == 'S' then
                        -- Don't allow recursive splitting to prevent infinite loops
                        break
                    else
                        break
                    end

                    x1 = x1 + self.dirVecs[d1 + 1].x
                    y1 = y1 + self.dirVecs[d1 + 1].y
                end

                -- Process second split beam
                local d2 = splitDirs[2]
                local x2, y2 = x + self.dirVecs[d2 + 1].x, y + self.dirVecs[d2 + 1].y
                local visited2 = {}
                for k, v in pairs(visited) do visited2[k] = v end

                while inBounds(self, x2, y2) do
                    local key2 = x2 .. "," .. y2 .. "," .. d2
                    if visited2[key2] then break end
                    visited2[key2] = true

                    local ch2 = tileAt(self, x2, y2)
                    if ch2 == '.' then
                        addBeamSegment(self, x2, y2, d2, -0.45, 0.45)
                    elseif ch2 == '#' then
                        break
                    elseif ch2 == 'T' then
                        addBeamSegment(self, x2, y2, d2, -0.45, 0.0)
                        currentHits[x2 .. "," .. y2] = true
                        self.targetsHit[x2 .. "," .. y2] = true
                        break
                    elseif self.mirrorReflect[ch2] then
                        addBeamSegment(self, x2, y2, d2, -0.15, 0.15)
                        local newdir2 = self.mirrorReflect[ch2](d2)
                        if newdir2 then d2 = newdir2 else break end
                    elseif ch2 == 'S' then
                        -- Don't allow recursive splitting to prevent infinite loops
                        break
                    else
                        break
                    end

                    x2 = x2 + self.dirVecs[d2 + 1].x
                    y2 = y2 + self.dirVecs[d2 + 1].y
                end

                break -- Original beam stops at splitter
            elseif self.charToDir[ch] then
                addBeamSegment(self, x, y, d, -0.45, 0.45)
            else
                break
            end

            x = x + self.dirVecs[d + 1].x
            y = y + self.dirVecs[d + 1].y
        end
    end

    -- Check for newly hit targets and emit particles
    for coord, _ in pairs(currentHits) do
        if not self.previouslyHit[coord] then
            -- This target was just hit - emit particles!
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
    --self.gw, self.gh = levelData.size[1], levelData.size[2]
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
    self.colors:setColor("moonlit_charcoal", 1)
    rectangle("fill", sx, sy, self.tileSize - 1, self.tileSize - 1)
    self.colors:setColor("neutral_grey", 1)
    rectangle("line", sx, sy, self.tileSize - 1, self.tileSize - 1)
end

-- Forward-slash mirror (/)
local function drawForwardSlash(self, cx, cy)
    local r = self.tileSize * 0.42
    self.colors:setColor("mirror_base", 1)
    circle("line", cx, cy, r)

    -- Reflective arc faces top-right, and bottom-left
    self.colors:setColor("mirror_glow", 0.9)
    setLineWidth(3)
    local startAngle, endAngle = math.rad(-45), math.rad(135)
    love.graphics.arc("line", cx, cy, r, startAngle, endAngle)
    setLineWidth(1)
end

-- Backslash mirror (\)
local function drawBackSlash(self, cx, cy)
    local r = self.tileSize * 0.42
    self.colors:setColor("mirror_base", 1)
    circle("line", cx, cy, r)

    -- Reflective arc faces top-left, and bottom-right
    self.colors:setColor("mirror_glow", 0.9)
    setLineWidth(3)
    local startAngle, endAngle = math.rad(45), math.rad(225)
    love.graphics.arc("line", cx, cy, r, startAngle, endAngle)
    setLineWidth(1)
end

-- Blocking mirror (M3)
local function drawX(self, cx, cy)
    local r = self.tileSize * 0.42
    self.colors:setColor("mirror_disabled_outer", 1)
    circle("line", cx, cy, r)

    self.colors:setColor("mirror_disabled_fill", 0.6)
    circle("fill", cx, cy, r * 0.6)

    self.colors:setColor("mirror_disabled_highlight", 0.8)
    setLineWidth(2)
    circle("line", cx, cy, r * 0.6)
    setLineWidth(1)
end

-- Beam Splitter (S)
local function drawSplitter(self, cx, cy)
    local r = self.tileSize * 0.42
    local t = love.timer.getTime()
    local pulse = 0.75 + 0.25 * math.sin(t * 5)

    -- Outer ring glow
    self.colors:setColor("splitter_glow", 0.4 * pulse)
    circle("fill", cx, cy, r * 1.1)

    -- Main circle ring
    self.colors:setColor("splitter_base", 1)
    circle("line", cx, cy, r)

    -- Cross pattern inside
    setLineWidth(3)
    self.colors:setColor("splitter_cross", 1)
    line(cx - r * 0.5, cy, cx + r * 0.5, cy)
    line(cx, cy - r * 0.5, cx, cy + r * 0.5)
    setLineWidth(1)

    -- Center pulse
    self.colors:setColor("splitter_core", 1)
    circle("fill", cx, cy, r * 0.25 * pulse)
end

local function drawBeam(self, cx, cy, ox_start, oy_start, ox_end, oy_end)
    self.colors:setColor("lime_green", 0.95)
    setLineWidth(2)
    line(cx + ox_start, cy + oy_start, cx + ox_end, cy + oy_end)
    setLineWidth(1)
end

local function drawAngledBeam(self, cx, cy, incoming_d, outgoing_d)
    self.colors:setColor("lime_green", 0.95)
    setLineWidth(2)

    local incoming_dir = self.dirVecs[incoming_d + 1]
    local outgoing_dir = self.dirVecs[outgoing_d + 1]

    local offset = self.tileSize * 0.45

    local start_x = cx - incoming_dir.x * offset
    local start_y = cy - incoming_dir.y * offset

    local end_x = cx + outgoing_dir.x * offset
    local end_y = cy + outgoing_dir.y * offset

    line(start_x, start_y, cx, cy)
    line(cx, cy, end_x, end_y)

    setLineWidth(1)
end

local function drawWall(self, sx, sy)
    self.colors:setColor("charcoal_gray", 1)
    rectangle("fill", sx + 4, sy + 4, self.tileSize - 8, self.tileSize - 8)
end

local function drawTarget(self, cx, cy, x, y)
    local hit = self.targetsHit[x .. "," .. y]

    -- Center and size
    local r = self.tileSize * 0.22

    -- Glow pulse (animated with time)
    local t = love.timer.getTime()
    local pulse = 0.8 + 0.2 * math_sin(t * 6)
    local glowRadius = r * (1.3 + 0.1 * math_sin(t * 3))

    -- Outer glow
    self.colors:setColor(hit and "neon_green_glow" or "red_glow", 0.4)
    circle("fill", cx, cy, glowRadius * pulse)

    -- Main target body
    self.colors:setColor(hit and "neon_green" or "red", 1)
    circle("fill", cx, cy, r)

    -- Inner ring highlight
    self.colors:setColor("white_highlight", 0.2)
    setLineWidth(2)
    circle("line", cx, cy, r * 0.65)
    circle("line", cx, cy, r * 0.4)

    -- Black outline
    self.colors:setColor("black_outline", 0.6)
    setLineWidth(1.5)
    circle("line", cx, cy, r)
end

local function drawLaser(self, ch, cx, cy)
    local d = self.charToDir[ch]

    -- Base body (metallic turret)
    self.colors:setColor("dark_grey", 1)
    circle("fill", cx, cy, self.tileSize * 0.25)
    self.colors:setColor("soft_steel", 1)
    circle("line", cx, cy, self.tileSize * 0.25)

    -- Inner glowing core
    self.colors:setColor("pastel_yellow", 0.9)
    circle("fill", cx, cy, self.tileSize * 0.12)

    -- Directional nozzle
    self.colors:setColor("golden_yellow", 1)
    local nozzleLength = self.tileSize * 0.22
    local nozzleWidth = self.tileSize * 0.09
    if d == 0 then
        polygon("fill", cx, cy - nozzleLength, cx - nozzleWidth, cy, cx + nozzleWidth, cy)
    elseif d == 1 then
        polygon("fill", cx + nozzleLength, cy, cx, cy - nozzleWidth, cx, cy + nozzleWidth)
    elseif d == 2 then
        polygon("fill", cx, cy + nozzleLength, cx - nozzleWidth, cy, cx + nozzleWidth, cy)
    elseif d == 3 then
        polygon("fill", cx - nozzleLength, cy, cx, cy - nozzleWidth, cx, cy + nozzleWidth)
    end

    -- Glow ring
    self.colors:setColor("golden_wheat", 0.3)
    setLineWidth(3)
    circle("line", cx, cy, self.tileSize * 0.28)
    setLineWidth(1)
end

function Grid:draw()
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
            drawAngledBeam(self, cx, cy, b.incoming_d, b.outgoing_d)
        else
            local d = b.d
            local dir = self.dirVecs[d + 1]
            local ox_start = dir.x * self.tileSize * b.startFrac
            local oy_start = dir.y * self.tileSize * b.startFrac
            local ox_end = dir.x * self.tileSize * b.endFrac
            local oy_end = dir.y * self.tileSize * b.endFrac
            drawBeam(self, cx, cy, ox_start, oy_start, ox_end, oy_end)
        end
    end

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
                drawTarget(self, cx, cy, x, y)
            elseif self.charToDir[ch] then
                drawLaser(self, ch, cx, cy)
            elseif self.mirrorReflect[ch] then
                setLineWidth(3)
                if ch == "M1" then
                    drawForwardSlash(self, cx, cy)
                elseif ch == "M2" then
                    drawBackSlash(self, cx, cy)
                elseif ch == "M3" then
                    drawX(self, cx, cy)
                end
                setLineWidth(1)
            elseif ch == 'S' then
                drawSplitter(self, cx, cy)
            end
        end
    end

    self.particleSystem:draw()
end

function Grid:update(dt)
    self.particleSystem:update(dt)
end

return Grid
