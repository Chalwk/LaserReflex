-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ParticleSystem = require("classes/Particles")

local math_max = math.max
local math_min = math.min
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

local Grid = {}
Grid.__index = Grid

function Grid.new()
    local instance = setmetatable({}, Grid)

    instance.grid = {}
    instance.beams = {}
    instance.targetsHit = {}
    instance.lasers = {}

    instance.gw, instance.gh = 9, 9
    instance.tileSize = 48
    instance.gridOffsetX, instance.gridOffsetY = 40, 40

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
    -- M3, M4: Alternative orientations (blocking or other behaviors)
    instance.mirrorReflect = {
        -- Forward slash (/): reflects 90 degrees
        M1 = function(incomingDir)
            if incomingDir == 0 then return 1 end -- Up -> Right
            if incomingDir == 1 then return 0 end -- Right -> Up
            if incomingDir == 2 then return 3 end -- Down -> Left
            if incomingDir == 3 then return 2 end -- Left -> Down
            return nil
        end,

        -- Backslash (\): reflects 90 degrees
        M2 = function(incomingDir)
            if incomingDir == 0 then return 3 end -- Up -> Left
            if incomingDir == 1 then return 2 end -- Right -> Down
            if incomingDir == 2 then return 1 end -- Down -> Right
            if incomingDir == 3 then return 0 end -- Left -> Up
            return nil
        end,

        -- Blocking mirrors (no reflection)
        M3 = function(incomingDir) return nil end,
        M4 = function(incomingDir) return nil end
    }

    instance.mirrorStates = { "M1", "M2", "M3", "M4" }

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
            return
        end
    end
end

function Grid:addBeamSegment(x, y, d, startFrac, endFrac)
    table_insert(self.beams, { x = x, y = y, d = d, startFrac = startFrac, endFrac = endFrac })
end

function Grid:computeBeams()
    self.beams = {}
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
                setColor(hit and { 0 / 255, 255 / 255, 68 / 255 } or { 255, 0, 0 })
                circle("fill", cx, cy, self.tileSize * 0.22)
                setColor(0, 0, 0, 0.6)
                circle("line", cx, cy, self.tileSize * 0.22)
            elseif self.charToDir[ch] then
                setColor(1.0, 0.9, 0.3)
                rectangle("fill", cx - 6, cy - 6, 12, 12)
                setColor(0.06, 0.06, 0.06)
                local d = self.charToDir[ch]
                if d == 0 then
                    polygon("fill", cx, cy - 10, cx - 6, cy + 4, cx + 6, cy + 4)
                elseif d == 1 then
                    polygon("fill", cx + 10, cy, cx - 4, cy - 6, cx - 4, cy + 6)
                elseif d == 2 then
                    polygon("fill", cx, cy + 10, cx - 6, cy - 4, cx + 6, cy - 4)
                elseif d == 3 then
                    polygon("fill", cx - 10, cy, cx + 4, cy - 6, cx + 4, cy + 6)
                end
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
                elseif ch == "M3" or ch == "M4" then
                    setColor(0.5, 0.5, 0.5)
                    -- Blocking mirrors - draw as X
                    line(cx - self.tileSize * 0.3, cy - self.tileSize * 0.3,
                        cx + self.tileSize * 0.3, cy + self.tileSize * 0.3)
                    line(cx - self.tileSize * 0.3, cy + self.tileSize * 0.3,
                        cx + self.tileSize * 0.3, cy - self.tileSize * 0.3)
                end
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
