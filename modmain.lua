local GLOBAL = GLOBAL
local TheInput = GLOBAL.TheInput

local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt

local CLOUDS_ENABLED = GetModConfigData("clouds_enabled")
local ZOOM_SENSITIVITY = GetModConfigData("zoom_sensitivity")

local MAX_DIST = 180        -- ~190 is Max! Vanilla: 50 surface, 35 caves
                            -- Higher values may cause the camera to exceed the scene's render limits.
local MIN_DIST = 3          -- Vanilla: 15 Any

local RESET_DIST = 30
local RESET_DIST_CAVE = 25

local MIN_PITCH = 30        -- Vanilla
local MIN_PITCH_CAVE = 25   -- Vanilla
local MAX_PITCH = 85        -- 90 is Max! Vanilla: 60 surface, 40 caves

local DEFAULT_FOV = 35      -- Vanilla
local MAX_FOV = 70          -- Might be worth tweaking this further

local PITCH_SPEED = 0.07    -- >0 faster, <0 slower, 0 default. Range: -1.5 to 0.49
local PITCH_POWER = math_max(0.01, 0.5 - PITCH_SPEED)

if GLOBAL.PLAYER_CAMERA_MAX_DIST ~= nil then GLOBAL.PLAYER_CAMERA_MAX_DIST = MAX_DIST end
if GLOBAL.PLAYER_CAMERA_MAX_DIST_CAVES ~= nil then GLOBAL.PLAYER_CAMERA_MAX_DIST_CAVES = MAX_DIST end

local PERSIST_KEY = modname .. "_user_prefs"

local ControlsConfig = {
    reset_bind = GLOBAL.MOUSEBUTTON_MIDDLE,
    reset_is_mouse = true,
}

local function IsHUDActive()
    if not GLOBAL.ThePlayer then return false end
    local screen = GLOBAL.TheFrontEnd and GLOBAL.TheFrontEnd:GetActiveScreen()
    return screen and screen.name == "HUD"
end

local function SaveControlsConfig()
    local str = GLOBAL.json.encode(ControlsConfig)
    GLOBAL.TheSim:SetPersistentString(PERSIST_KEY, str, false)
end

GLOBAL.TheSim:GetPersistentString(PERSIST_KEY, function(load_success, str)
    if load_success and str then
        local success, data = GLOBAL.pcall(GLOBAL.json.decode, str)
        if success and GLOBAL.type(data) == "table" then
            for k, v in pairs(data) do
                ControlsConfig[k] = v
            end
        end
    end
end)

local function OpenSettingsMenu()
    if IsHUDActive() then
        local ZoomSettingsScreen = require("screens/zoomsettingsscreen")
        GLOBAL.TheFrontEnd:PushScreen(ZoomSettingsScreen(
            ControlsConfig.reset_bind, 
            ControlsConfig.reset_is_mouse, 
            function(new_bind, is_mouse)
                ControlsConfig.reset_bind = new_bind
                ControlsConfig.reset_is_mouse = is_mouse
                SaveControlsConfig()
            end
        ))
    end
end

local function ResetCamera()
    if IsHUDActive() then
        if GLOBAL.TheCamera then
            local is_cave = GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld:HasTag("cave")
            GLOBAL.TheCamera.distancetarget = is_cave and RESET_DIST_CAVE or RESET_DIST
        end
    end
end

GLOBAL.TheInput:AddKeyDownHandler(GLOBAL.KEY_X, function()
    local ctrl_down = GLOBAL.TheInput:IsKeyDown(GLOBAL.KEY_CTRL) or 
                      GLOBAL.TheInput:IsKeyDown(GLOBAL.KEY_LCTRL) or 
                      GLOBAL.TheInput:IsKeyDown(GLOBAL.KEY_RCTRL)
    
    if ctrl_down and IsHUDActive() then
        OpenSettingsMenu()
    end
end)

GLOBAL.TheInput:AddKeyHandler(function(key, down)
    if not down or ControlsConfig.reset_is_mouse then return end
    if key == ControlsConfig.reset_bind then ResetCamera() end
end)

GLOBAL.TheInput:AddMouseButtonHandler(function(button, down)
    if not down or not ControlsConfig.reset_is_mouse then return end
    if button == ControlsConfig.reset_bind then ResetCamera() end
end)

local function IsWX()
    -- WX-78 Zaptrocuter HARDFix..
    if GLOBAL.ThePlayer and GLOBAL.ThePlayer.prefab == "wx78" then return true end
    return false
end

local function UpdateZoom(inst)
    inst.SetDefaultOriginal = inst.SetDefault
    inst.SetDefault = function(self, ...)
        self:SetDefaultOriginal(...)

        self.is_wx = IsWX()
        local _is_cave = GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld:HasTag("cave")

        self.maxdist = MAX_DIST
        self.mindist = MIN_DIST
        self.mindistpitch = _is_cave and MIN_PITCH_CAVE or MIN_PITCH
        self.maxdistpitch = MAX_PITCH

        self.dist_range = self.maxdist - self.mindist
        self.pitch_range = self.maxdistpitch - self.mindistpitch
        self.fov_range = MAX_FOV - DEFAULT_FOV
    end

    inst.ZoomInOriginal = inst.ZoomIn
    inst.ZoomIn = function(self, step)
        self:ZoomInOriginal(step or ZOOM_SENSITIVITY)
    end

    inst.ZoomOutOriginal = inst.ZoomOut
    inst.ZoomOut = function(self, step)
        self:ZoomOutOriginal(step or ZOOM_SENSITIVITY)
    end

    inst.UpdateOriginal = inst.Update
    inst.Update = function(self, dt, dontupdatepos)
        self.should_push_down = false 
        self:UpdateOriginal(dt, dontupdatepos)
    end

    inst.ApplyOriginal = inst.Apply
    inst.Apply = function(self)
        if (self.dist_range and self.dist_range > 0) then
            local percent_d = math_max(0, math_min(1, (self.distance - self.mindist) / self.dist_range))
            local curved_percent_d = percent_d ^ PITCH_POWER
            
            self.pitch = self.mindistpitch + self.pitch_range * curved_percent_d
            
            if not self.is_wx then
                self.fov = DEFAULT_FOV + (self.fov_range or 0) * percent_d
            end
        end

        self:ApplyOriginal()
    end
end

AddGlobalClassPostConstruct("cameras/followcamera", "FollowCamera", UpdateZoom)

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