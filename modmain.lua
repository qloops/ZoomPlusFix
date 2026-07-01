local _G = GLOBAL

local ConfigState = require("core/configstate")
local ConfigIO = require("wrappers/configio")
local CameraController = require("controllers/cameracontroller")
local InputController = require("controllers/inputcontroller")

local CLOUDS_ENABLED = GetModConfigData("clouds_enabled")
local CANOPY_ENABLED = GetModConfigData("canopy_enabled")
local SETTINGS_BIND = GetModConfigData("settings_bind")
-- Use modname to keep preferences scoped to this exact mod build.
-- Renaming the mod changes the storage key and effectively starts with fresh prefs.
local PERSIST_KEY = modname .. "_user_prefs"

ConfigIO.Initialize(_G)
CameraController.Initialize(ConfigState, _G)

local function OnSettingsSaved(key, value, is_mouse)
    ConfigState.UpdateSetting(key, value)
    if key == "reset_bind" then
        ConfigState.UpdateSetting("reset_is_mouse", is_mouse)
    end
    CameraController.ApplyCameraConfig()
    ConfigIO.Save(PERSIST_KEY, ConfigState)
end

InputController.Initialize(ConfigState, CameraController, _G, SETTINGS_BIND, OnSettingsSaved)

ConfigIO.Load(PERSIST_KEY, ConfigState, function()
    ConfigState.UpdateSetting("zoom_sensitivity", GetModConfigData("zoom_sensitivity"))
    CameraController.ApplyCameraConfig()
end)

AddPrefabPostInit("focalpoint", function(inst)
    CameraController.HookFocalPoint(inst)
end)

AddGlobalClassPostConstruct("cameras/followcamera", "FollowCamera", function(inst)
    CameraController.HookCamera(inst)
end)

-- Conservative disable. Override update functions and hide visual elements 
-- instead of destroying them. This ensures compatibility with the HUD and other 
-- mods that may still expect these systems or fields to exist.
if not CLOUDS_ENABLED then
    AddClassPostConstruct("screens/playerhud", function(self)
        if self.UpdateClouds then self.UpdateClouds = function() end end
        if self.cloudoverlays then
            for _, overlay in pairs(self.cloudoverlays) do
                if overlay.Hide then overlay:Hide() end
            end
        end
    end)
end

if not CANOPY_ENABLED then
    AddClassPostConstruct("widgets/leafcanopy", function(self)
        self:Hide()
        self.OnUpdate = function() end
    end)
end