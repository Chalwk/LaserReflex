-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local setColor = love.graphics.setColor

local Colors = {}
Colors.__index = Colors

function Colors.new()
    local instance = setmetatable({}, Colors)

    instance.colors = {
        white = { 1, 1, 1 },
        black = { 0, 0, 0 },
        red = { 1, 0, 0 },
        green = { 0, 1, 0 },
        blue = { 0, 0, 1 },
        moonlit_charcoal = { 0.1, 0.1, 0.12 },
        neutral_grey = { 0.22, 0.22, 0.24 },
        neon_green = { 0 / 255, 255 / 255, 68 / 255 },
        lime_green = { 0.6, 1.0, 0.2 },
        charcoal_gray = { 0.2, 0.2, 0.22 },
        neon_green_glow = { 0 / 255, 255 / 255, 100 / 255 },
        red_glow = { 1, 0, 0 },
        white_highlight = { 1, 1, 1 },
        black_outline = { 0, 0, 0 },
        dark_grey = { 0.15, 0.15, 0.17 },
        soft_steel = { 0.4, 0.4, 0.45 },
        pastel_yellow = { 1.0, 0.95, 0.4 },
        golden_yellow = { 1.0, 0.85, 0.2 },
        golden_wheat = { 1.0, 0.95, 0.4 },
        silver = { 0.9, 0.9, 0.9 },
        medium_grey = { 0.5, 0.5, 0.5 },
        light_blue = { 0.4, 0.8, 1.0 },
        medium_blue = { 0.2, 0.5, 0.8 }
    }

    return instance
end

function Colors:getColor(name)
    return self.colors[name]
end

function Colors:setColor(name, alpha)
    local col = self.colors[name]
    alpha = alpha or 1
    if col then
        local r, g, b = col[1], col[2], col[3]
        setColor(r, g, b, alpha)
    else
        error("Color '" .. name .. "' not found")
    end
end

return Colors
