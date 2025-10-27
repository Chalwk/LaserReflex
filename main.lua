-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local table_insert = table.insert

local circle = love.graphics.circle
local line = love.graphics.line
local polygon = love.graphics.polygon
local rectangle = love.graphics.rectangle
local setColor = love.graphics.setColor
local setLineWidth = love.graphics.setLineWidth

-- ======================================================
-- CONFIG / LEVELS - IMPROVED FORMAT
-- ======================================================

-- New intuitive level format using tables instead of strings
local levels = {
    -- Level 1: Basic single reflection
    {
        name = "Simple Turn",
        size = { 9, 9 },
        map = {
            { x = 3, y = 3, type = "laser", dir = "right" },
            { x = 6, y = 3, type = "mirror", state = "M1" },
            { x = 6, y = 5, type = "target" }
        }
    },

    -- Level 2: Two lasers, two targets
    {
        name = "Double Approach",
        size = { 9, 9 },
        map = {
            { x = 2, y = 2, type = "laser", dir = "right" },
            { x = 5, y = 2, type = "mirror", state = "M2" },
            { x = 6, y = 5, type = "target" },
            { x = 4, y = 6, type = "target" },
            { x = 7, y = 7, type = "mirror", state = "M2" },
            { x = 8, y = 7, type = "laser", dir = "left" }
        }
    },

    -- Level 3: Introduce walls
    {
        name = "Wall Barriers",
        size = { 9, 9 },
        map = {
            { x = 2, y = 2, type = "laser", dir = "right" },
            { x = 5, y = 2, type = "mirror", state = "M2" },
            { x = 7, y = 2, type = "wall" },
            { x = 5, y = 3, type = "wall" },
            { x = 5, y = 4, type = "wall" },
            { x = 5, y = 5, type = "target" },
            { x = 5, y = 6, type = "wall" },
            { x = 5, y = 7, type = "wall" }
        }
    },

    -- Level 4: Multiple reflections
    {
        name = "Double Reflection",
        size = { 9, 9 },
        map = {
            { x = 2, y = 2, type = "laser", dir = "right" },
            { x = 5, y = 2, type = "mirror", state = "M2" },
            { x = 7, y = 2, type = "wall" },
            { x = 5, y = 3, type = "wall" },
            { x = 5, y = 4, type = "wall" },
            { x = 3, y = 5, type = "target" },
            { x = 5, y = 5, type = "wall" },
            { x = 5, y = 6, type = "wall" },
            { x = 5, y = 7, type = "wall" }
        }
    },

    -- Level 5: U-shaped path
    {
        name = "The U-Turn",
        size = { 9, 9 },
        map = {
            { x = 3, y = 3, type = "laser", dir = "right" },
            { x = 6, y = 3, type = "mirror", state = "M2" },
            { x = 4, y = 5, type = "wall" },
            { x = 7, y = 5, type = "wall" },
            { x = 5, y = 7, type = "target" }
        }
    },

    -- Level 6: Multiple targets, single laser
    {
        name = "Dual Targets",
        size = { 11, 11 },
        map = {
            { x = 4, y = 3, type = "laser", dir = "right" },
            { x = 6, y = 5, type = "mirror", state = "M2" },
            { x = 4, y = 7, type = "wall" },
            { x = 8, y = 7, type = "wall" },
            { x = 3, y = 9, type = "target" },
            { x = 8, y = 9, type = "target" }
        }
    },

    -- Level 7: Maze-like structure
    {
        name = "Mirror Maze",
        size = { 11, 11 },
        map = {
            { x = 2, y = 3, type = "laser", dir = "right" },
            { x = 6, y = 5, type = "mirror", state = "M2" },
            { x = 7, y = 9, type = "target" },
            -- Walls in alternating pattern
            { x = 2, y = 2, type = "wall" }, { x = 4, y = 2, type = "wall" }, { x = 6, y = 2, type = "wall" }, { x = 8, y = 2, type = "wall" }, { x = 10, y = 2, type = "wall" },
            { x = 2, y = 4, type = "wall" }, { x = 4, y = 4, type = "wall" }, { x = 6, y = 4, type = "wall" }, { x = 8, y = 4, type = "wall" }, { x = 10, y = 4, type = "wall" },
            { x = 2, y = 6, type = "wall" }, { x = 4, y = 6, type = "wall" }, { x = 6, y = 6, type = "wall" }, { x = 8, y = 6, type = "wall" }, { x = 10, y = 6, type = "wall" },
            { x = 2, y = 8, type = "wall" }, { x = 4, y = 8, type = "wall" }, { x = 6, y = 8, type = "wall" }, { x = 8, y = 8, type = "wall" }, { x = 10, y = 8, type = "wall" },
            { x = 2, y = 10, type = "wall" }, { x = 4, y = 10, type = "wall" }, { x = 6, y = 10, type = "wall" }, { x = 8, y = 10, type = "wall" }, { x = 10, y = 10, type = "wall" }
        }
    }
}

-- ======================================================
-- GAME STATE
-- ======================================================

local currentLevel = 1
local grid = {}
local gw, gh = 9, 9
local tileSize = 48
local gridOffsetX, gridOffsetY = 40, 40

local beams = {}
local targetsHit = {}
local lasers = {}
local selected = { x = nil, y = nil }
local font

-- directions: 0=up, 1=right, 2=down, 3=left
local dirVecs = {
    { x = 0,  y = -1 },
    { x = 1,  y = 0 },
    { x = 0,  y = 1 },
    { x = -1, y = 0 },
}
local charToDir = { ['^'] = 0, ['>'] = 1, ['v'] = 2, ['<'] = 3 }
local dirToChar = { ['up'] = '^', ['right'] = '>', ['down'] = 'v', ['left'] = '<' }

-- ======================================================
-- MIRROR REFLECTION RULES
-- ======================================================

-- Reflection logic for each mirror state:
-- Keys = incoming direction; Values = new outgoing direction
-- 0=up, 1=right, 2=down, 3=left
local mirrorReflect = {
    -- M1 reflects 90° clockwise (up→right, right→down, down→left, left→up)
    M1 = { [0] = 1, [1] = 2, [2] = 3, [3] = 0 },

    -- M2 blocks (no reflection)
    M2 = {},

    -- M3 blocks (no reflection)
    M3 = {},

    -- M4 reflects 90° counterclockwise (up→left, left→down, down→right, right→up)
    M4 = { [0] = 3, [3] = 2, [2] = 1, [1] = 0 },
}

local mirrorStates = { "M1", "M2", "M3", "M4" }

-- ======================================================
-- HELPERS
-- ======================================================

local function inBounds(x, y)
    return x >= 1 and x <= gw and y >= 1 and y <= gh
end

local function tileAt(x, y)
    if not inBounds(x, y) then return nil end
    return grid[y][x]
end

local function setTile(x, y, ch)
    if inBounds(x, y) then grid[y][x] = ch end
end

local computeBeams

-- ======================================================
-- LEVEL LOADING - IMPROVED
-- ======================================================

local function loadLevel(idx)
    idx = idx or currentLevel
    local lev = levels[idx]
    assert(lev, "level not found")
    gw, gh = lev.size[1], lev.size[2]
    grid, lasers, beams, targetsHit = {}, {}, {}, {}
    selected = { x = nil, y = nil }

    -- Initialize empty grid
    for y = 1, gh do
        grid[y] = {}
        for x = 1, gw do
            grid[y][x] = '.'
        end
    end

    -- Place objects from the map definition
    for _, obj in ipairs(lev.map) do
        if obj.type == "laser" then
            local char = dirToChar[obj.dir]
            setTile(obj.x, obj.y, char)
            table_insert(lasers, { x = obj.x, y = obj.y, d = charToDir[char] })
        elseif obj.type == "mirror" then
            setTile(obj.x, obj.y, obj.state)
        elseif obj.type == "target" then
            setTile(obj.x, obj.y, 'T')
        elseif obj.type == "wall" then
            setTile(obj.x, obj.y, '#')
        end
    end

    local winw, winh = love.graphics.getDimensions()
    local maxTileW = math_floor((winw - 160) / gw)
    local maxTileH = math_floor((winh - 160) / gh)
    tileSize = math_max(24, math_min(64, math_min(maxTileW, maxTileH)))
    gridOffsetX = math_floor((winw - gw * tileSize) / 2)
    gridOffsetY = math_floor((winh - gh * tileSize) / 2)

    computeBeams()
end

local function screenToGrid(sx, sy)
    local gx = math_floor((sx - gridOffsetX) / tileSize) + 1
    local gy = math_floor((sy - gridOffsetY) / tileSize) + 1
    if inBounds(gx, gy) then return gx, gy end
end

local function rotateMirror(x, y, delta)
    local ch = tileAt(x, y)
    if not ch then return end
    for i, state in ipairs(mirrorStates) do
        if ch == state then
            local newIndex = ((i - 1 + (delta or 1)) % #mirrorStates) + 1
            setTile(x, y, mirrorStates[newIndex])
            computeBeams()
            return
        end
    end
end

local function resetLevel() loadLevel(currentLevel) end

-- ======================================================
-- LASER / BEAM COMPUTATION
-- ======================================================

local function addBeamSegment(x, y, d, length)
    table_insert(beams, { x = x, y = y, d = d, length = length })
end

function computeBeams()
    beams = {}
    targetsHit = {}

    for _, src in ipairs(lasers) do
        local sx, sy, sd = src.x, src.y, src.d
        local x, y, d = sx, sy, sd
        local visited = {}
        x = x + dirVecs[d + 1].x
        y = y + dirVecs[d + 1].y

        while inBounds(x, y) do
            local key = x .. "," .. y .. "," .. d
            if visited[key] then break end
            visited[key] = true

            local ch = tileAt(x, y)
            if ch == '.' then
                addBeamSegment(x, y, d, 0.45)
            elseif ch == '#' then
                break
            elseif ch == 'T' then
                addBeamSegment(x, y, d, 0.45)
                targetsHit[x .. "," .. y] = true
                break
            elseif mirrorReflect[ch] then
                addBeamSegment(x, y, d, 0.15)
                local refl = mirrorReflect[ch]
                local newdir = refl[d]
                if newdir then
                    d = newdir
                else
                    break -- blocked mirror (M2/M3)
                end
            elseif charToDir[ch] then
                addBeamSegment(x, y, d, 0.45)
            else
                break
            end
            x = x + dirVecs[d + 1].x
            y = y + dirVecs[d + 1].y
        end
    end
end

-- ======================================================
-- LOVE CALLBACKS
-- ======================================================

function love.load()
    font = love.graphics.newFont(14)
    love.graphics.setFont(font)
    loadLevel(currentLevel)
end

function love.resize(w, h)
    if levels[currentLevel] then
        local lev = levels[currentLevel]
        local maxTileW = math_floor((w - 160) / lev.size[1])
        local maxTileH = math_floor((h - 160) / lev.size[2])
        tileSize = math_max(24, math_min(64, math_min(maxTileW, maxTileH)))
        gridOffsetX = math_floor((w - lev.size[1] * tileSize) / 2)
        gridOffsetY = math_floor((h - lev.size[2] * tileSize) / 2)
    end
end

function love.draw()
    love.graphics.clear(0.06, 0.06, 0.06)

    for y = 1, gh do
        for x = 1, gw do
            local sx = gridOffsetX + (x - 1) * tileSize
            local sy = gridOffsetY + (y - 1) * tileSize
            setColor(0.1, 0.1, 0.12)
            rectangle("fill", sx, sy, tileSize - 1, tileSize - 1)
            setColor(0.22, 0.22, 0.24)
            rectangle("line", sx, sy, tileSize - 1, tileSize - 1)
        end
    end

    for y = 1, gh do
        for x = 1, gw do
            local ch = tileAt(x, y)
            local sx = gridOffsetX + (x - 1) * tileSize
            local sy = gridOffsetY + (y - 1) * tileSize
            local cx = sx + tileSize / 2
            local cy = sy + tileSize / 2

            if ch == '#' then
                setColor(0.2, 0.2, 0.22)
                rectangle("fill", sx + 4, sy + 4, tileSize - 8, tileSize - 8)
            elseif ch == 'T' then
                local hit = targetsHit[x .. "," .. y]
                setColor(hit and { 0.65, 0.95, 0.55 } or { 0.4, 0.95, 0.4 })
                circle("fill", cx, cy, tileSize * 0.22)
                setColor(0, 0, 0, 0.6)
                circle("line", cx, cy, tileSize * 0.22)
            elseif charToDir[ch] then
                setColor(1.0, 0.9, 0.3)
                rectangle("fill", cx - 6, cy - 6, 12, 12)
                setColor(0.06, 0.06, 0.06)
                local d = charToDir[ch]
                if d == 0 then
                    polygon("fill", cx, cy - 10, cx - 6, cy + 4, cx + 6, cy + 4)
                elseif d == 1 then
                    polygon("fill", cx + 10, cy, cx - 4, cy - 6, cx - 4, cy + 6)
                elseif d == 2 then
                    polygon("fill", cx, cy + 10, cx - 6, cy - 4, cx + 6, cy - 4)
                elseif d == 3 then
                    polygon("fill", cx - 10, cy, cx + 4, cy - 6, cx + 4, cy + 6)
                end
            elseif mirrorReflect[ch] then
                setLineWidth(3)
                if ch == "M1" then
                    setColor(0.9, 0.9, 0.9)
                elseif ch == "M2" or ch == "M3" then
                    setColor(0.5, 0.5, 0.5)
                elseif ch == "M4" then
                    setColor(1, 1, 1)
                end
                local angle = ({ M1 = 45, M2 = 0, M3 = 0, M4 = -45 })[ch]
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(math.rad(angle))
                line(-tileSize / 2 + 4, 0, tileSize / 2 - 4, 0)
                love.graphics.pop()
                setLineWidth(1)
            end

            if selected.x == x and selected.y == y then
                setColor(0.9, 0.9, 1, 0.25)
                rectangle("fill", sx, sy, tileSize - 1, tileSize - 1)
            end
        end
    end

    for _, b in ipairs(beams) do
        local sx = gridOffsetX + (b.x - 1) * tileSize
        local sy = gridOffsetY + (b.y - 1) * tileSize
        local cx = sx + tileSize / 2
        local cy = sy + tileSize / 2
        local d = b.d
        local ox = dirVecs[d + 1].x * tileSize * b.length
        local oy = dirVecs[d + 1].y * tileSize * b.length
        setColor(0.6, 1.0, 0.2, 0.95)
        setLineWidth(4)
        line(cx - ox, cy - oy, cx + ox, cy + oy)
        setLineWidth(1)
    end

    setColor(1, 1, 1)
    love.graphics.printf("LaserReflex - Level: (" .. currentLevel .. ") " ..
        (levels[currentLevel] and levels[currentLevel].name or tostring(currentLevel)),
        8, 6, love.graphics.getWidth() - 16, "center")

    local totalTargets, hitCount = 0, 0
    for y = 1, gh do
        for x = 1, gw do
            if tileAt(x, y) == 'T' then totalTargets = totalTargets + 1 end
        end
    end
    for _ in pairs(targetsHit) do hitCount = hitCount + 1 end

    love.graphics.print(string.format("Targets: %d / %d", hitCount, totalTargets), 8, 28)
    if totalTargets > 0 and hitCount == totalTargets then
        setColor(0.8, 1, 0.6)
        love.graphics.printf("All targets hit! Press N for next level.", 0, 48, love.graphics.getWidth(), "center")
    end
end

function love.mousepressed(x, y, button)
    local gx, gy = screenToGrid(x, y)
    if not gx then return end
    if button == 1 then
        selected.x, selected.y = gx, gy
        rotateMirror(gx, gy, 1)
    elseif button == 2 then
        rotateMirror(gx, gy, -1)
    end
end

function love.keypressed(key)
    if key == 'r' then
        resetLevel()
    elseif key == 'n' then
        currentLevel = currentLevel % #levels + 1
        loadLevel(currentLevel)
    elseif key == 'p' then
        currentLevel = (currentLevel - 2) % #levels + 1
        loadLevel(currentLevel)
    elseif key == 'escape' then
        love.event.quit()
    elseif key == 'q' or key == 'e' then
        if selected.x then
            local delta = (key == 'e') and 1 or -1
            rotateMirror(selected.x, selected.y, delta)
        end
    end
end
