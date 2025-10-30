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
        black = { 0, 0, 0 },
        black_outline = { 0, 0, 0 },
        blue = { 0, 0, 1 },
        charcoal_gray = { 0.2, 0.2, 0.22 },
        dark_grey = { 0.15, 0.15, 0.17 },
        golden_wheat = { 1.0, 0.95, 0.4 },
        golden_yellow = { 1.0, 0.85, 0.2 },
        green = { 0, 1, 0 },
        light_blue = { 0.4, 0.8, 1.0 },
        lime_green = { 0.6, 1.0, 0.2 },
        medium_blue = { 0.2, 0.5, 0.8 },
        medium_grey = { 0.5, 0.5, 0.5 },
        mirror_base = { 0.6, 0.65, 0.7 },
        mirror_back = { 100, 100, 110 },
        mirror_disabled_fill = { 0.1, 0.1, 0.12 },
        mirror_disabled_highlight = { 0.6, 0.6, 0.65 },
        mirror_disabled_outer = { 0.35, 0.35, 0.4 },
        mirror_glow = { 0.5, 1.0, 0.9 },
        mirror_glass = { 0.7, 0.8, 0.9, 0.8 },
        moonlit_charcoal = { 0.1, 0.1, 0.12 },
        neutral_grey = { 0.22, 0.22, 0.24 },
        neon_green = { 0 / 255, 255 / 255, 68 / 255 },
        neon_green_glow = { 0 / 255, 255 / 255, 100 / 255 },
        pastel_yellow = { 1.0, 0.95, 0.4 },
        red = { 1, 0, 0 },
        red_glow = { 1, 0.3, 0.3 },
        silver = { 0.9, 0.9, 0.9 },
        soft_steel = { 0.4, 0.4, 0.45 },
        splitter_base = { 0.6, 0.9, 1.0 },
        splitter_core = { 0.8, 1.0, 0.9 },
        splitter_cross = { 1.0, 1.0, 1.0 },
        splitter_glow = { 0.4, 0.9, 1.0 },
        wall_highlight = { 0.4, 0.4, 0.45 },
        wall_shadow = { 0.1, 0.1, 0.12 },
        wall_texture = { 0.05, 0.05, 0.07 },
        white = { 1, 1, 1 },
        white_highlight = { 1, 1, 1 },
        grid_highlight = { 0.3, 0.3, 0.32, 0.1 },
        laser_core_glow = { 1.0, 1.0, 0.7, 0.8 },
        beam_outer_glow = { 0.4, 1.0, 0.3, 0.4 },
        target_inner_ring = { 1.0, 1.0, 1.0, 0.6 },
    }

    return instance
end

function Colors:getColor(name)
    return self.colors[name]
end

function Colors:setColor(name, alpha)
    local col = self.colors[name]
    if col then
        local r, g, b, a = col[1], col[2], col[3], alpha or (col[4] or 1)
        setColor(r, g, b, a)
    else
        error("Color '" .. name .. "' not found")
    end
end

return Colors
