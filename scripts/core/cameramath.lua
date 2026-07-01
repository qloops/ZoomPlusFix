local CameraMath = {}

local math_max = math.max
local math_min = math.min

-- Skipping extra checks (division by zero, incompatible parameters)
-- to boost performance; missing checks won't cause crashes.
function CameraMath.CalculateCameraValues(
    distance, mindist, dist_range, 
    pitch_power, mindistpitch, pitch_range, 
    default_fov, fov_range, 
    allow_custom_fov, current_fov
)
    local percent_d = math_max(0, math_min(1, (distance - mindist) / dist_range))
    local curved_percent_d = percent_d ^ pitch_power
    
    local new_pitch = mindistpitch + pitch_range * curved_percent_d
    local new_fov = allow_custom_fov 
        and (default_fov + fov_range * percent_d) 
        or current_fov

    return new_pitch, new_fov
end

return CameraMath