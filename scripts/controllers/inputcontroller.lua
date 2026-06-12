local InputController = {}

local cached_config = nil
local cached_defaults = nil
local CamController = nil
local GameEnv = nil
local active_settings_bind = nil
local on_settings_saved_cb = nil

function InputController.Initialize(
    config_state, 
    camera_controller, 
    game_env, 
    settings_bind, 
    on_saved_callback
)
    cached_config = config_state.Settings
    cached_defaults = config_state.DefaultSettings
    CamController = camera_controller
    GameEnv = game_env
    on_settings_saved_cb = on_saved_callback

    local SETTINGS_MENU_BINDS = {
        ctrl_z = { key = GameEnv.KEY_Z,   mods = { GameEnv.KEY_CTRL,  GameEnv.KEY_LCTRL,  GameEnv.KEY_RCTRL } },
        shift_z = { key = GameEnv.KEY_Z,   mods = { GameEnv.KEY_SHIFT, GameEnv.KEY_LSHIFT, GameEnv.KEY_RSHIFT } },
        alt_z = { key = GameEnv.KEY_Z,   mods = { GameEnv.KEY_ALT,   GameEnv.KEY_LALT,   GameEnv.KEY_RALT } },
        f10 = { key = GameEnv.KEY_F10, mods = {} },
    }

    active_settings_bind = SETTINGS_MENU_BINDS[settings_bind] or SETTINGS_MENU_BINDS["ctrl_z"]

    InputController.RegisterHandlers()
end

local function IsHUDActive()
    if not GameEnv.ThePlayer then return false end
    local screen = GameEnv.TheFrontEnd and GameEnv.TheFrontEnd:GetActiveScreen()
    return screen and screen.name == "HUD"
end

local function HasValidModifier()
    if #active_settings_bind.mods == 0 then return true end
    
    for _, mod_key in ipairs(active_settings_bind.mods) do
        if GameEnv.TheInput:IsKeyDown(mod_key) then return true end
    end
    
    return false
end

local function OpenSettingsMenu()
    if not IsHUDActive() then return end
    
    local ZoomSettingsScreen = require("screens/zoomsettingsscreen")
    
    GameEnv.TheFrontEnd:PushScreen(ZoomSettingsScreen(
        cached_config, 
        cached_defaults, 
        on_settings_saved_cb
    ))
end

function InputController.RegisterHandlers()
    GameEnv.TheInput:AddKeyDownHandler(active_settings_bind.key, function()
        if HasValidModifier() and IsHUDActive() then
            OpenSettingsMenu()
        end
    end)

    GameEnv.TheInput:AddKeyHandler(function(key, down)
        if not down or cached_config.reset_is_mouse then return end
        if key == cached_config.reset_bind and IsHUDActive() then
            CamController.ResetCamera()
        end
    end)

    GameEnv.TheInput:AddMouseButtonHandler(function(button, down)
        if not down or not cached_config.reset_is_mouse then return end
        if button == cached_config.reset_bind and IsHUDActive() then
            CamController.ResetCamera()
        end
    end)
end

return InputController