-- LaserReflex - Love2D
-- Tile-based puzzle: rotate mirrors to direct lasers into targets.
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ipairs = ipairs
local table_insert = table.insert
local table_remove = table.remove
local math_random = math.random

local setColor = love.graphics.setColor
local circle = love.graphics.circle

local Particle = {}
Particle.__index = Particle

function Particle.new()
    local instance = setmetatable({}, Particle)
    instance.particles = {}
    return instance
end

function Particle:emit(x, y, count)
    for _ = 1, count do
        table_insert(self.particles, {
            x = x,
            y = y,
            dx = (math_random() - 0.5) * 300,
            dy = (math_random() - 0.5) * 300,
            life = 0.8 + math_random() * 1,
            maxLife = 0.8 + math_random() * 1,
            size = 3 + math_random() * 4,
            color = {
                math_random(),
                math_random(),
                math_random()
            }
        })
    end
end

function Particle:update(dt)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.life = p.life - dt
        p.x = p.x + p.dx * dt
        p.y = p.y + p.dy * dt
        p.dy = p.dy + 40 * dt -- gravity

        if p.life <= 0 then
            table_remove(self.particles, i)
        end
    end
end

function Particle:draw()
    setColor(1, 1, 1)
    for _, p in ipairs(self.particles) do
        local alpha = p.life / p.maxLife
        setColor(p.color[1], p.color[2], p.color[3], alpha)
        circle("fill", p.x, p.y, p.size * alpha)
    end
end

return Particle
