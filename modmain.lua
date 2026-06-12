local _G = GLOBAL

local ConfigState = require("core/configstate")
local ConfigIO = require("wrappers/configio")
local CameraController = require("controllers/cameracontroller")
local InputController = require("controllers/inputcontroller")

local CLOUDS_ENABLED = GetModConfigData("clouds_enabled")
local SETTINGS_BIND = GetModConfigData("settings_bind")
local PERSIST_KEY = modname .. "_user_prefs"

ConfigState.UpdateSetting("zoom_sensitivity", GetModConfigData("zoom_sensitivity"))

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
    CameraController.ApplyCameraConfig()
end)

AddPrefabPostInit("focalpoint", function(inst)
    CameraController.HookFocalPoint(inst)
end)

AddGlobalClassPostConstruct("cameras/followcamera", "FollowCamera", function(inst)
    CameraController.HookCamera(inst)
end)

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