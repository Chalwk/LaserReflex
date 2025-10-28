local love_rand = love.math.random

local Colors = {}
Colors.__index = Colors

function Colors.new()
    local instance = setmetatable({}, Colors)

    instance.colors = {
        white = { 1, 1, 1 },
        black = { 0, 0, 0 },
        red = { 1, 0, 0 },
        green = { 0, 1, 0 },
        blue = { 0, 0, 1 }
    }

    return instance
end

return Colors