local _G = GLOBAL

local ConfigState = require("core/configstate")
local ConfigIO = require("wrappers/configio")
local CameraController = require("controllers/cameracontroller")

local CLOUDS_ENABLED = GetModConfigData("clouds_enabled")
local PERSIST_KEY = modname .. "_user_prefs"

ConfigState.UpdateSetting("zoom_sensitivity", GetModConfigData("zoom_sensitivity"))

ConfigIO.Initialize(_G)
CameraController.Initialize(ConfigState, _G)

ConfigIO.Load(PERSIST_KEY, ConfigState, function()
    CameraController.ApplyCameraConfig()
end)

local function IsHUDActive()
    if not _G.ThePlayer then return false end
    local screen = _G.TheFrontEnd and _G.TheFrontEnd:GetActiveScreen()
    return screen and screen.name == "HUD"
end

local function OpenSettingsMenu()
    if not IsHUDActive() then return end
    
    local ZoomSettingsScreen = require("screens/zoomsettingsscreen")
    
    _G.TheFrontEnd:PushScreen(ZoomSettingsScreen(
        ConfigState.Settings, 
        ConfigState.DefaultSettings,
        function(key, value, is_mouse)
            ConfigState.UpdateSetting(key, value)
            if key == "reset_bind" then
                ConfigState.UpdateSetting("reset_is_mouse", is_mouse)
            end
            
            CameraController.ApplyCameraConfig()
            ConfigIO.Save(PERSIST_KEY, ConfigState)
        end
    ))
end

AddPrefabPostInit("focalpoint", function(inst)
    CameraController.HookFocalPoint(inst)
end)

AddGlobalClassPostConstruct("cameras/followcamera", "FollowCamera", function(inst)
    CameraController.HookCamera(inst)
end)

_G.TheInput:AddKeyDownHandler(_G.KEY_Z, function()
    local ctrl_down = _G.TheInput:IsKeyDown(_G.KEY_CTRL) or
                      _G.TheInput:IsKeyDown(_G.KEY_LCTRL) or
                      _G.TheInput:IsKeyDown(_G.KEY_RCTRL)

    if ctrl_down and IsHUDActive() then
        OpenSettingsMenu()
    end
end)

_G.TheInput:AddKeyHandler(function(key, down)
    if not down or ConfigState.Settings.reset_is_mouse then return end
    if key == ConfigState.Settings.reset_bind and IsHUDActive() then
        CameraController.ResetCamera()
    end
end)

_G.TheInput:AddMouseButtonHandler(function(button, down)
    if not down or not ConfigState.Settings.reset_is_mouse then return end
    if button == ConfigState.Settings.reset_bind and IsHUDActive() then
        CameraController.ResetCamera()
    end
end)

if not CLOUDS_ENABLED then
    AddClassPostConstruct("screens/playerhud", function(self)
        if self.UpdateClouds then
            self.UpdateClouds = function() end
        end
        if self.cloudoverlays then
            for _, overlay in pairs(self.cloudoverlays) do
                if overlay.Hide then
                    overlay:Hide()
                end
            end
        end
    end)
end