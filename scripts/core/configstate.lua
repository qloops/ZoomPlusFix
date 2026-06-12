local ConfigState = {}

ConfigState.CONSTANTS = {
    RESET_DIST_SURFACE = 30,
    RESET_DIST_CAVE = 25,

    BASE_PITCH_POWER = 0.5,
    MIN_PITCH_POWER = 0.01,
}

ConfigState.DefaultSettings = {
    reset_bind = rawget(_G, "MOUSEBUTTON_MIDDLE") or 3,
    reset_is_mouse = true,
    max_dist = 180,
    min_dist = 3,
    min_pitch = 30,
    min_pitch_cave = 25,
    max_pitch = 85,
    default_fov = 35,
    max_fov = 70,
    pitch_speed = 0.00,
    zoom_sensitivity = 4,
}

ConfigState.Settings = {}
for k, v in pairs(ConfigState.DefaultSettings) do
    ConfigState.Settings[k] = v
end

function ConfigState.UpdateSetting(key, value)
    local current_val = ConfigState.Settings[key]
    if current_val ~= nil and type(value) == type(current_val) then
        ConfigState.Settings[key] = value
    end
end

return ConfigState