-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

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

    -- Directions: 0=up, 1=right, 2=down, 3=left
    instance.dirVecs = {
        { x = 0,  y = -1 },
        { x = 1,  y = 0 },
        { x = 0,  y = 1 },
        { x = -1, y = 0 },
    }

    instance.charToDir = { ['^'] = 0, ['>'] = 1, ['v'] = 2, ['<'] = 3 }
    instance.dirToChar = { ['up'] = '^', ['right'] = '>', ['down'] = 'v', ['left'] = '<' }

    -- Mirror reflection rules
    instance.mirrorReflect = {
        M1 = { [0] = 1, [1] = 2, [2] = 3, [3] = 0 },
        M2 = {},
        M3 = {},
        M4 = { [0] = 3, [3] = 2, [2] = 1, [1] = 0 },
    }

    instance.mirrorStates = { "M1", "M2", "M3", "M4" }

    return instance
end

function Grid:loadLevel(levelData)
    self.gw, self.gh = levelData.size[1], levelData.size[2]
    self.grid, self.lasers, self.beams, self.targetsHit = {}, {}, {}, {}

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
            table.insert(self.lasers, { x = obj.x, y = obj.y, d = self.charToDir[char] })
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
    local maxTileW = math.floor((winw - 160) / self.gw)
    local maxTileH = math.floor((winh - 160) / self.gh)
    self.tileSize = math.max(24, math.min(64, math.min(maxTileW, maxTileH)))
    self.gridOffsetX = math.floor((winw - self.gw * self.tileSize) / 2)
    self.gridOffsetY = math.floor((winh - self.gh * self.tileSize) / 2)
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
    local gx = math.floor((sx - self.gridOffsetX) / self.tileSize) + 1
    local gy = math.floor((sy - self.gridOffsetY) / self.tileSize) + 1
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

function Grid:addBeamSegment(x, y, d, length)
    table.insert(self.beams, { x = x, y = y, d = d, length = length })
end

function Grid:computeBeams()
    self.beams = {}
    self.targetsHit = {}

    for _, src in ipairs(self.lasers) do
        local sx, sy, sd = src.x, src.y, src.d
        local x, y, d = sx, sy, sd
        local visited = {}
        x = x + self.dirVecs[d + 1].x
        y = y + self.dirVecs[d + 1].y

        while self:inBounds(x, y) do
            local key = x .. "," .. y .. "," .. d
            if visited[key] then break end
            visited[key] = true

            local ch = self:tileAt(x, y)
            if ch == '.' then
                self:addBeamSegment(x, y, d, 0.45)
            elseif ch == '#' then
                break
            elseif ch == 'T' then
                self:addBeamSegment(x, y, d, 0.45)
                self.targetsHit[x .. "," .. y] = true
                break
            elseif self.mirrorReflect[ch] then
                self:addBeamSegment(x, y, d, 0.15)
                local refl = self.mirrorReflect[ch]
                local newdir = refl[d]
                if newdir then
                    d = newdir
                else
                    break -- blocked mirror (M2/M3)
                end
            elseif self.charToDir[ch] then
                self:addBeamSegment(x, y, d, 0.45)
            else
                break
            end
            x = x + self.dirVecs[d + 1].x
            y = y + self.dirVecs[d + 1].y
        end
    end
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
            love.graphics.setColor(0.1, 0.1, 0.12)
            love.graphics.rectangle("fill", sx, sy, self.tileSize - 1, self.tileSize - 1)
            love.graphics.setColor(0.22, 0.22, 0.24)
            love.graphics.rectangle("line", sx, sy, self.tileSize - 1, self.tileSize - 1)
        end
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
                love.graphics.setColor(0.2, 0.2, 0.22)
                love.graphics.rectangle("fill", sx + 4, sy + 4, self.tileSize - 8, self.tileSize - 8)
            elseif ch == 'T' then
                local hit = self.targetsHit[x .. "," .. y]
                love.graphics.setColor(hit and { 0.65, 0.95, 0.55 } or { 0.4, 0.95, 0.4 })
                love.graphics.circle("fill", cx, cy, self.tileSize * 0.22)
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.circle("line", cx, cy, self.tileSize * 0.22)
            elseif self.charToDir[ch] then
                love.graphics.setColor(1.0, 0.9, 0.3)
                love.graphics.rectangle("fill", cx - 6, cy - 6, 12, 12)
                love.graphics.setColor(0.06, 0.06, 0.06)
                local d = self.charToDir[ch]
                if d == 0 then
                    love.graphics.polygon("fill", cx, cy - 10, cx - 6, cy + 4, cx + 6, cy + 4)
                elseif d == 1 then
                    love.graphics.polygon("fill", cx + 10, cy, cx - 4, cy - 6, cx - 4, cy + 6)
                elseif d == 2 then
                    love.graphics.polygon("fill", cx, cy + 10, cx - 6, cy - 4, cx + 6, cy - 4)
                elseif d == 3 then
                    love.graphics.polygon("fill", cx - 10, cy, cx + 4, cy - 6, cx + 4, cy + 6)
                end
            elseif self.mirrorReflect[ch] then
                love.graphics.setLineWidth(3)
                if ch == "M1" then
                    love.graphics.setColor(0.9, 0.9, 0.9)
                elseif ch == "M2" or ch == "M3" then
                    love.graphics.setColor(0.5, 0.5, 0.5)
                elseif ch == "M4" then
                    love.graphics.setColor(1, 1, 1)
                end
                local angle = ({ M1 = 45, M2 = 0, M3 = 0, M4 = -45 })[ch]
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(math.rad(angle))
                love.graphics.line(-self.tileSize / 2 + 4, 0, self.tileSize / 2 - 4, 0)
                love.graphics.pop()
                love.graphics.setLineWidth(1)
            end
        end
    end

    -- Draw beams
    for _, b in ipairs(self.beams) do
        local sx = self.gridOffsetX + (b.x - 1) * self.tileSize
        local sy = self.gridOffsetY + (b.y - 1) * self.tileSize
        local cx = sx + self.tileSize / 2
        local cy = sy + self.tileSize / 2
        local d = b.d
        local ox = self.dirVecs[d + 1].x * self.tileSize * b.length
        local oy = self.dirVecs[d + 1].y * self.tileSize * b.length
        love.graphics.setColor(0.6, 1.0, 0.2, 0.95)
        love.graphics.setLineWidth(4)
        love.graphics.line(cx - ox, cy - oy, cx + ox, cy + oy)
        love.graphics.setLineWidth(1)
    end
end

return Grid
