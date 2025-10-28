-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ParticleSystem = require("classes.Particles")

local math_max = math.max
local math_min = math.min
local math_sin = math.sin
local math_floor = math.floor
local table_insert = table.insert
local pairs = pairs
local ipairs = ipairs

local setLineWidth = love.graphics.setLineWidth
local setColor = love.graphics.setColor
local rectangle = love.graphics.rectangle
local circle = love.graphics.circle
local polygon = love.graphics.polygon
local line = love.graphics.line

-- Target state colors (on / off)
local COLOR_ON = { 0 / 255, 255 / 255, 68 / 255 }
local COLOR_OFF = { 1, 0, 0 }

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
        M1 = function(direction)
            if direction == 0 then return 1 end -- Up -> Right
            if direction == 1 then return 0 end -- Right -> Up
            if direction == 2 then return 3 end -- Down -> Left
            if direction == 3 then return 2 end -- Left -> Down
            return nil
        end,

        -- Backslash (\): reflects 90 degrees
        M2 = function(direction)
            if direction == 0 then return 3 end -- Up -> Left
            if direction == 1 then return 2 end -- Right -> Down
            if direction == 2 then return 1 end -- Down -> Right
            if direction == 3 then return 0 end -- Left -> Up
            return nil
        end,

        M3 = function() return nil end
    }

    -- Beam Splitter: splits beam into perpendicular directions
    instance.beamSplitter = function(direction)
        if direction == 0 or direction == 2 then
            return { 1, 3 } -- Up/Down -> Right/Left
        else
            return { 0, 2 } -- Right/Left -> Up/Down
        end
    end

    instance.mirrorStates = { "M1", "M2", "M3" }

    return instance
end

function Grid:loadLevel(levelData)
    self.gw, self.gh = levelData.size[1], levelData.size[2]
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
            self:setTile(obj.x, obj.y, char)
            table_insert(self.lasers, { x = obj.x, y = obj.y, d = self.charToDir[char] })
        elseif obj.type == "mirror" then
            self:setTile(obj.x, obj.y, obj.state)
        elseif obj.type == "target" then
            self:setTile(obj.x, obj.y, 'T')
        elseif obj.type == "wall" then
            self:setTile(obj.x, obj.y, '#')
        elseif obj.type == "splitter" then
            self:setTile(obj.x, obj.y, 'S')
        end
    end

    self:computeBeams()
end

function Grid:calculateTileSize(winw, winh)
    local maxTileW = math_floor((winw - 160) / self.gw)
    local maxTileH = math_floor((winh - 160) / self.gh)
    self.tileSize = math_max(24, math_min(64, math_min(maxTileW, maxTileH)))
    self.gridOffsetX = math_floor((winw - self.gw * self.tileSize) / 2)
    self.gridOffsetY = math_floor((winh - self.gh * self.tileSize) / 2)
end

function Grid:inBounds(x, y)
    return x >= 1 and x <= self.gw and y >= 1 and y <= self.gh
end

function Grid:tileAt(x, y)
    if not self:inBounds(x, y) then return nil end
    return self.grid[y][x]
end

function Grid:setTile(x, y, ch)
    if self:inBounds(x, y) then self.grid[y][x] = ch end
end

function Grid:screenToGrid(sx, sy)
    local gx = math_floor((sx - self.gridOffsetX) / self.tileSize) + 1
    local gy = math_floor((sy - self.gridOffsetY) / self.tileSize) + 1
    if self:inBounds(gx, gy) then return gx, gy end
end

function Grid:rotateMirror(x, y, delta)
    local ch = self:tileAt(x, y)
    if not ch then return end

    for i, state in ipairs(self.mirrorStates) do
        if ch == state then
            local newIndex = ((i - 1 + (delta or 1)) % #self.mirrorStates) + 1
            self:setTile(x, y, self.mirrorStates[newIndex])
            self:computeBeams()
            self.sounds:play("rotate")
            return
        end
    end
end

function Grid:addBeamSegment(x, y, d, startFrac, endFrac)
    table_insert(self.beams, { x = x, y = y, d = d, startFrac = startFrac, endFrac = endFrac })
end

function Grid:computeBeams()
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

        while self:inBounds(x, y) do
            local key = x .. "," .. y .. "," .. d
            if visited[key] then break end
            visited[key] = true

            local ch = self:tileAt(x, y)
            if ch == '.' then
                self:addBeamSegment(x, y, d, -0.45, 0.45)
            elseif ch == '#' then
                break
            elseif ch == 'T' then
                self:addBeamSegment(x, y, d, -0.45, 0.0)
                currentHits[x .. "," .. y] = true
                self.targetsHit[x .. "," .. y] = true
                break
            elseif self.mirrorReflect[ch] then
                self:addBeamSegment(x, y, d, -0.15, 0.15)
                local newdir = self.mirrorReflect[ch](d)
                if newdir then
                    d = newdir
                else
                    break
                end
            elseif ch == 'S' then
                -- Beam Splitter: split into two perpendicular directions
                self:addBeamSegment(x, y, d, -0.15, 0.15)

                -- Get the two split directions
                local splitDirs = self.beamSplitter(d)

                -- Process first split beam
                local d1 = splitDirs[1]
                local x1, y1 = x + self.dirVecs[d1 + 1].x, y + self.dirVecs[d1 + 1].y
                local visited1 = {}
                for k, v in pairs(visited) do visited1[k] = v end

                while self:inBounds(x1, y1) do
                    local key1 = x1 .. "," .. y1 .. "," .. d1
                    if visited1[key1] then break end
                    visited1[key1] = true

                    local ch1 = self:tileAt(x1, y1)
                    if ch1 == '.' then
                        self:addBeamSegment(x1, y1, d1, -0.45, 0.45)
                    elseif ch1 == '#' then
                        break
                    elseif ch1 == 'T' then
                        self:addBeamSegment(x1, y1, d1, -0.45, 0.0)
                        currentHits[x1 .. "," .. y1] = true
                        self.targetsHit[x1 .. "," .. y1] = true
                        break
                    elseif self.mirrorReflect[ch1] then
                        self:addBeamSegment(x1, y1, d1, -0.15, 0.15)
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

                while self:inBounds(x2, y2) do
                    local key2 = x2 .. "," .. y2 .. "," .. d2
                    if visited2[key2] then break end
                    visited2[key2] = true

                    local ch2 = self:tileAt(x2, y2)
                    if ch2 == '.' then
                        self:addBeamSegment(x2, y2, d2, -0.45, 0.45)
                    elseif ch2 == '#' then
                        break
                    elseif ch2 == 'T' then
                        self:addBeamSegment(x2, y2, d2, -0.45, 0.0)
                        currentHits[x2 .. "," .. y2] = true
                        self.targetsHit[x2 .. "," .. y2] = true
                        break
                    elseif self.mirrorReflect[ch2] then
                        self:addBeamSegment(x2, y2, d2, -0.15, 0.15)
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
                self:addBeamSegment(x, y, d, -0.45, 0.45)
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
        end
    end

    self.previouslyHit = currentHits
end

function Grid:getTargetProgress()
    local totalTargets, hitCount = 0, 0
    for y = 1, self.gh do
        for x = 1, self.gw do
            if self:tileAt(x, y) == 'T' then totalTargets = totalTargets + 1 end
        end
    end
    for _ in pairs(self.targetsHit) do hitCount = hitCount + 1 end
    return hitCount, totalTargets
end

function Grid:draw()
    -- Draw grid background
    for y = 1, self.gh do
        for x = 1, self.gw do
            local sx = self.gridOffsetX + (x - 1) * self.tileSize
            local sy = self.gridOffsetY + (y - 1) * self.tileSize
            setColor(0.1, 0.1, 0.12)
            rectangle("fill", sx, sy, self.tileSize - 1, self.tileSize - 1)
            setColor(0.22, 0.22, 0.24)
            rectangle("line", sx, sy, self.tileSize - 1, self.tileSize - 1)
        end
    end

    -- Draw beams first
    for _, b in ipairs(self.beams) do
        local sx = self.gridOffsetX + (b.x - 1) * self.tileSize
        local sy = self.gridOffsetY + (b.y - 1) * self.tileSize
        local cx = sx + self.tileSize / 2
        local cy = sy + self.tileSize / 2
        local d = b.d
        local dir = self.dirVecs[d + 1]
        local ox_start = dir.x * self.tileSize * b.startFrac
        local oy_start = dir.y * self.tileSize * b.startFrac
        local ox_end = dir.x * self.tileSize * b.endFrac
        local oy_end = dir.y * self.tileSize * b.endFrac

        setColor(0.6, 1.0, 0.2, 0.95)
        setLineWidth(2)
        line(cx + ox_start, cy + oy_start, cx + ox_end, cy + oy_end)
        setLineWidth(1)
    end

    -- Draw tiles
    for y = 1, self.gh do
        for x = 1, self.gw do
            local ch = self:tileAt(x, y)
            local sx = self.gridOffsetX + (x - 1) * self.tileSize
            local sy = self.gridOffsetY + (y - 1) * self.tileSize
            local cx = sx + self.tileSize / 2
            local cy = sy + self.tileSize / 2

            if ch == '#' then
                setColor(0.2, 0.2, 0.22)
                rectangle("fill", sx + 4, sy + 4, self.tileSize - 8, self.tileSize - 8)
            elseif ch == 'T' then
                local hit = self.targetsHit[x .. "," .. y]

                -- Colors
                local glowColor = hit and { 0 / 255, 255 / 255, 100 / 255, 0.4 } or { 1, 0, 0, 0.3 }

                -- Center and size
                local r = self.tileSize * 0.22

                -- Glow pulse (animated with time)
                local t = love.timer.getTime()
                local pulse = 0.8 + 0.2 * math_sin(t * 6)
                local glowRadius = r * (1.3 + 0.1 * math_sin(t * 3))

                -- Outer glow
                setColor(glowColor)
                circle("fill", cx, cy, glowRadius * pulse)

                -- Main target body
                setColor(hit and COLOR_ON or COLOR_OFF)
                circle("fill", cx, cy, r)

                -- Inner ring highlight
                setColor(1, 1, 1, 0.2)
                setLineWidth(2)
                circle("line", cx, cy, r * 0.65)
                circle("line", cx, cy, r * 0.4)

                -- Black outline
                setColor(0, 0, 0, 0.6)
                setLineWidth(1.5)
                circle("line", cx, cy, r)
            elseif self.charToDir[ch] then
                local d = self.charToDir[ch]

                -- Base body (metallic turret)
                setColor(0.15, 0.15, 0.17)
                circle("fill", cx, cy, self.tileSize * 0.25)
                setColor(0.4, 0.4, 0.45)
                circle("line", cx, cy, self.tileSize * 0.25)

                -- Inner glowing core
                setColor(1.0, 0.95, 0.4, 0.9)
                circle("fill", cx, cy, self.tileSize * 0.12)

                -- Directional nozzle
                setColor(1.0, 0.85, 0.2)
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
                setColor(1.0, 0.95, 0.4, 0.3)
                setLineWidth(3)
                circle("line", cx, cy, self.tileSize * 0.28)
                setLineWidth(1)
            elseif self.mirrorReflect[ch] then
                setLineWidth(3)
                if ch == "M1" then
                    setColor(0.9, 0.9, 0.9)
                    -- Forward slash (/)
                    line(cx - self.tileSize * 0.3, cy + self.tileSize * 0.3,
                        cx + self.tileSize * 0.3, cy - self.tileSize * 0.3)
                elseif ch == "M2" then
                    setColor(0.9, 0.9, 0.9)
                    -- Backslash (\)
                    line(cx - self.tileSize * 0.3, cy - self.tileSize * 0.3,
                        cx + self.tileSize * 0.3, cy + self.tileSize * 0.3)
                elseif ch == "M3" then
                    setColor(0.5, 0.5, 0.5)
                    -- Blocking mirrors - draw as X
                    line(cx - self.tileSize * 0.3, cy - self.tileSize * 0.3,
                        cx + self.tileSize * 0.3, cy + self.tileSize * 0.3)
                    line(cx - self.tileSize * 0.3, cy + self.tileSize * 0.3,
                        cx + self.tileSize * 0.3, cy - self.tileSize * 0.3)
                end
                setLineWidth(1)
            elseif ch == 'S' then
                -- Beam Splitter: draw as a diamond shape with cross pattern
                setColor(0.4, 0.8, 1.0, 0.9) -- Light blue color

                -- Draw diamond shape
                local r = self.tileSize * 0.25
                polygon("fill",
                    cx, cy - r,
                    cx + r, cy,
                    cx, cy + r,
                    cx - r, cy
                )

                -- Draw cross pattern inside
                setColor(1, 1, 1, 0.8)
                setLineWidth(2)
                line(cx - r * 0.7, cy, cx + r * 0.7, cy) -- Horizontal line
                line(cx, cy - r * 0.7, cx, cy + r * 0.7) -- Vertical line
                setLineWidth(1)

                -- Outline
                setColor(0.2, 0.5, 0.8)
                setLineWidth(1.5)
                polygon("line",
                    cx, cy - r,
                    cx + r, cy,
                    cx, cy + r,
                    cx - r, cy
                )
                setLineWidth(1)
            end
        end
    end

    self.particleSystem:draw()
end

function Grid:update(dt)
    self.particleSystem:update(dt)
end

return Grid
