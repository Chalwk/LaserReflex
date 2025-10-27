-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local string_rep = string.rep
local table_insert = table.insert

local circle = love.graphics.circle
local line = love.graphics.line
local polygon = love.graphics.polygon
local rectangle = love.graphics.rectangle
local setColor = love.graphics.setColor
local setLineWidth = love.graphics.setLineWidth

-- ======================================================
-- CONFIG / LEVELS
-- ======================================================

-- Token legend (for level map strings):
-- '.' = empty
-- '^', '>', 'v', '<' = laser source and initial direction
-- '/', '\' = mirror (slash and backslash)
-- 'T' = target
-- '#' = wall (blocks beam)
--
-- Mirrors rotate between slash and backslash.
-- Left-click rotates clockwise (/ -> \ -> /), right-click rotates counter-clockwise.

local levels = {
    -- Level 1: Basic single reflection
    {
        name = "Simple Turn",
        size = { 9, 9 },
        map = {
            ".........",
            ".........",
            "..>...\\..",
            ".........",
            ".....T...",
            ".........",
            ".........",
            ".........",
            ".........",
        }
    },

    -- Level 2: Two lasers, two targets
    {
        name = "Double Approach",
        size = { 9, 9 },
        map = {
            ".........",
            ".>..\\....",
            ".........",
            ".........",
            ".....T...",
            "....T....",
            ".....\\.<.",
            ".........",
            ".........",
        }
    },

    -- Level 3: Introduce walls
    {
        name = "Wall Barriers",
        size = { 9, 9 },
        map = {
            ".........",
            ".>..\\#...",
            ".....#...",
            ".....#...",
            "..../.T..",
            ".....#...",
            ".....#...",
            ".........",
            ".........",
        }
    },

    -- Level 4: Multiple reflections
    {
        name = "Double Reflection",
        size = { 9, 9 },
        map = {
            ".........",
            ".>..\\#...",
            ".....#...",
            ".....#...",
            "..T..#...",
            "..../#...",
            ".....#...",
            ".........",
            ".........",
        }
    },

    -- Level 5: U-shaped path
    {
        name = "The U-Turn",
        size = { 9, 9 },
        map = {
            ".........",
            ".........",
            "..>..\\...",
            ".........",
            "..#..#...",
            ".........",
            "../..T...",
            ".........",
            ".........",
        }
    },

    -- Level 6: Multiple targets, single laser
    {
        name = "Dual Targets",
        size = { 11, 11 },
        map = {
            "...........",
            "...........",
            "...>.......",
            "...........",
            ".....\\.....",
            "...........",
            "..#....#...",
            "...........",
            "..T....T...",
            "...........",
            "...........",
        }
    },

    -- Level 7: Maze-like structure
    {
        name = "Mirror Maze",
        size = { 11, 11 },
        map = {
            "...........",
            ".#.#.#.#.#.",
            ".>.........",
            ".#.#.#.#.#.",
            "....\\......",
            ".#.#.#.#.#.",
            "...........",
            ".#.#.#.#.#.",
            ".....T.....",
            ".#.#.#.#.#.",
            "...........",
        }
    },

    -- Level 8: Complex path with obstacles
    {
        name = "Obstacle Course",
        size = { 13, 13 },
        map = {
            ".............",
            ".>............",
            ".............",
            "..#...#...#..",
            "....\\........",
            "..#.......#..",
            "......\\......",
            "..#.......#..",
            "..../........",
            "..#...#...#..",
            ".............",
            ".........T...",
            ".............",
        }
    },

    -- Level 9: Multiple lasers, complex interactions
    {
        name = "Laser Grid",
        size = { 13, 13 },
        map = {
            "v............",
            ".............",
            "......#......",
            "......\\......",
            "......#......",
            ">...../.....<",
            "......#......",
            "......\\......",
            "......#......",
            ".............",
            "......T......",
            ".............",
            "^............",
        }
    },

    -- Level 10: Master challenge
    {
        name = "Master Puzzle",
        size = { 15, 15 },
        map = {
            "...............",
            ".>.........#...",
            ".............#.",
            "..#.....#......",
            "...\\.........#",
            ".............#.",
            "..#....\\.......",
            "......#......#.",
            "..#...../....#.",
            "..............#",
            "..#....T.....#.",
            ".............#.",
            "...#..........",
            "..............",
            "...............",
        }
    },

    -- Level 11: Advanced reflection patterns
    {
        name = "Reflection Master",
        size = { 15, 15 },
        map = {
            "...............",
            "...........T...",
            "..#...#.#......",
            "......\\........",
            ".#.#.#.#.#.#.#.",
            "..............>",
            "....../........",
            ".#.#.#.#.#.#.#.",
            "......\\........",
            ".#.#.#.#.#.#.#.",
            "....../........",
            ".#.#.#.#.#.#.#.",
            "..............",
            "..............",
            "...............",
        }
    },

    -- Level 12: Final challenge
    {
        name = "Ultimate Test",
        size = { 17, 17 },
        map = {
            ".................",
            ".>..............#",
            ".................",
            ".#.#.#.#.#.#.#.#.",
            ".................",
            ".#.#.#.#.#.#.#.#.",
            "........\\........",
            ".#.#.#.#.#.#.#.#.",
            "......../........",
            ".#.#.#.#.#.#.#.#.",
            "........\\........",
            ".#.#.#.#.#.#.#.#.",
            ".................",
            ".#.#.#.#.#.#.#.#.",
            "........T........",
            ".................",
            ".................",
        }
    }
}

-- ======================================================
-- GAME STATE + METATABLES
-- ======================================================

local tileproto = {}
tileproto.__index = tileproto

local currentLevel = 1
local grid = {}
local gw, gh = 9, 9
local tileSize = 48
local gridOffsetX, gridOffsetY = 40, 40

local beams = {}
local beamHits = {}
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

-- mirror reflection: mirrorReflect[mirrorType][incomingDir] = outgoingDir
local mirrorReflect = {
    -- '/' mirror
    ['/'] = {
        [0] = 1, -- up -> right
        [1] = 0, -- right -> up
        [2] = 3, -- down -> left
        [3] = 2, -- left -> down
    },
    -- '\' mirror
    ['\\'] = {
        [0] = 3, -- up -> left
        [1] = 2, -- right -> down
        [2] = 1, -- down -> right
        [3] = 0, -- left -> up
    }
}

-- ======================================================
-- LOCAL HELPERS / ORGANISATION
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

-- forward declaration (loadLevel uses computeBeams)
local computeBeams

local function loadLevel(idx)
    idx = idx or currentLevel
    local lev = levels[idx]
    assert(lev, "level not found")
    gw, gh = lev.size[1], lev.size[2]
    grid = {}
    lasers = {}
    beams = {}
    targetsHit = {}
    selected = { x = nil, y = nil }

    for y = 1, gh do
        local rowStr = lev.map[y] or string_rep('.', gw)
        grid[y] = {}
        for x = 1, gw do
            local ch = rowStr:sub(x, x) or '.'
            grid[y][x] = ch
            if charToDir[ch] then
                table_insert(lasers, { x = x, y = y, d = charToDir[ch] })
            end
        end
    end

    -- compute tileSize and offset to nicely fit window
    local winw, winh = love.graphics.getDimensions()
    local maxTileW = math_floor((winw - 160) / gw)
    local maxTileH = math_floor((winh - 160) / gh)
    tileSize = math_max(24, math_min(64, math_min(maxTileW, maxTileH)))
    gridOffsetX = math_floor((winw - gw * tileSize) / 2)
    gridOffsetY = math_floor((winh - gh * tileSize) / 2)

    -- compute beams initially
    computeBeams()
end

local function screenToGrid(sx, sy)
    local gx = math_floor((sx - gridOffsetX) / tileSize) + 1
    local gy = math_floor((sy - gridOffsetY) / tileSize) + 1
    if inBounds(gx, gy) then return gx, gy end

    return nil, nil
end

local function rotateMirror(x, y, delta)
    local ch = tileAt(x, y)
    if not ch then return end
    if ch == '/' then
        if delta and delta < 0 then
            setTile(x, y, '\\') -- CCW: '/' -> '\'
        else
            setTile(x, y, '\\') -- CW also '/'
        end
        computeBeams()
    elseif ch == '\\' then
        if delta and delta < 0 then
            setTile(x, y, '/')
        else
            setTile(x, y, '/')
        end
        computeBeams()
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

        -- Start from the laser source and move in its direction
        x = x + dirVecs[d + 1].x
        y = y + dirVecs[d + 1].y

        while inBounds(x, y) do
            local key = x .. "," .. y .. "," .. d
            if visited[key] then break end
            visited[key] = true

            local ch = tileAt(x, y)

            if ch == '.' then
                -- Empty cell - full beam
                addBeamSegment(x, y, d, 0.45)
            elseif ch == '#' then
                -- Wall - stop at edge of previous cell
                -- Don't add beam for wall cell, break immediately
                break
            elseif ch == 'T' then
                -- Target - full beam
                addBeamSegment(x, y, d, 0.45)
                targetsHit[x .. "," .. y] = true
                break
            elseif ch == '/' or ch == '\\' then
                -- Mirror - very short beam just touching the mirror
                addBeamSegment(x, y, d, 0.15)

                -- Calculate reflection
                local refl = mirrorReflect[ch]
                local newdir = refl[d]
                if newdir then
                    d = newdir
                else
                    break
                end
            elseif charToDir[ch] then
                -- Pass through other lasers
                addBeamSegment(x, y, d, 0.45)
            else
                break
            end

            -- Move to next cell
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
                if hit then
                    setColor(0.65, 0.95, 0.55)
                else
                    setColor(0.4, 0.95, 0.4)
                end
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
            elseif ch == '/' or ch == '\\' then
                setLineWidth(3)
                setColor(0.9, 0.9, 0.9)
                if ch == '/' then
                    line(sx + 4, sy + tileSize - 4, sx + tileSize - 4, sy + 4)
                else -- '\'
                    line(sx + 4, sy + 4, sx + tileSize - 4, sy + tileSize - 4)
                end
                setLineWidth(1)
            end

            if selected.x == x and selected.y == y then
                setColor(0.9, 0.9, 1, 0.25)
                rectangle("fill", sx, sy, tileSize - 1, tileSize - 1)
            end
        end
    end

    -- Draw beams with proper lengths
    for _, b in ipairs(beams) do
        local sx = gridOffsetX + (b.x - 1) * tileSize
        local sy = gridOffsetY + (b.y - 1) * tileSize
        local cx = sx + tileSize / 2
        local cy = sy + tileSize / 2
        local d = b.d

        local ox = dirVecs[d + 1].x * tileSize * b.length
        local oy = dirVecs[d + 1].y * tileSize * b.length

        setColor(0.6, 1.0, 0.2, 0.95)
        setLineWidth(4) -- Reduced from 6 for better visual appeal
        line(cx - ox, cy - oy, cx + ox, cy + oy)
        setLineWidth(1)
    end

    setColor(1, 1, 1)
    love.graphics.printf(
        "LaserReflex - Level: (" ..
        currentLevel .. ") " .. (levels[currentLevel] and levels[currentLevel].name or tostring(currentLevel)), 8, 6,
        love.graphics.getWidth() - 16, "center")
    setColor(1, 1, 1)
    love.graphics.print(
        "Left-click mirror to rotate CW (/ -> \\), Right-click CCW. R reset. N/P next/prev level. Q/E rotate selected.",
        8,
        love.graphics.getHeight() - 28)

    local totalTargets = 0
    for y = 1, gh do
        for x = 1, gw do
            if tileAt(x, y) == 'T' then totalTargets = totalTargets + 1 end
        end
    end
    local hitCount = 0
    for k, v in pairs(targetsHit) do hitCount = hitCount + 1 end
    setColor(1, 1, 1)
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
