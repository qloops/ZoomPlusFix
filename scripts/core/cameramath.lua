local CameraMath = {}

local math_max = math.max
local math_min = math.min

function CameraMath.CalculateCameraValues(
    distance, mindist, dist_range, 
    pitch_power, mindistpitch, pitch_range, 
    default_fov, fov_range, 
    is_wx, current_fov
)
    local percent_d = math_max(0, math_min(1, (distance - mindist) / dist_range))
    local curved_percent_d = percent_d ^ pitch_power
    
    local new_pitch = mindistpitch + pitch_range * curved_percent_d
    local new_fov = current_fov

    if not is_wx then
        new_fov = default_fov + (fov_range or 0) * percent_d
    end

    return new_pitch, new_fov
end

return CameraMath