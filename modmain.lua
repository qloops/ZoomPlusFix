local GLOBAL = GLOBAL
local TheInput = GLOBAL.TheInput

local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt

local CLOUDS_ENABLED = GetModConfigData("clouds_enabled")
local ZOOM_SENSITIVITY = GetModConfigData("zoom_sensitivity")

local PERSIST_KEY = modname .. "_user_prefs"

local AppConfig = {
    reset_bind = GLOBAL.MOUSEBUTTON_MIDDLE,
    reset_is_mouse = true,
    max_dist = 180,         -- ~190 is Max! Vanilla: 50 surface, 35 caves
                            -- Higher values may cause the camera to exceed the scene's render limits.
    min_dist = 3,           
    min_pitch = 30,         -- Vanilla
    min_pitch_cave = 25,    -- Vanilla
    max_pitch = 85,         -- 90 is Max! Vanilla: 60 surface, 40 caves
    default_fov = 35,       -- Vanilla
    max_fov = 70,           -- Might be worth tweaking this further
    pitch_speed = 0.07,     -- >0 faster, <0 slower, 0 default. Range: -1.5 to 0.49
}

local RESET_DIST = 30
local RESET_DIST_CAVE = 25

local function IsHUDActive()
    if not GLOBAL.ThePlayer then return false end
    local screen = GLOBAL.TheFrontEnd and GLOBAL.TheFrontEnd:GetActiveScreen()
    return screen and screen.name == "HUD"
end

local function SaveAppConfig()
    local str = GLOBAL.json.encode(AppConfig)
    GLOBAL.TheSim:SetPersistentString(PERSIST_KEY, str, false)
end

local function ApplyCameraConfig()
    if not GLOBAL.TheCamera then return end
    local cam = GLOBAL.TheCamera
    local is_cave = GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld:HasTag("cave")

    cam.maxdist = AppConfig.max_dist
    cam.mindist = AppConfig.min_dist
    cam.mindistpitch = is_cave and AppConfig.min_pitch_cave or AppConfig.min_pitch
    cam.maxdistpitch = AppConfig.max_pitch

    cam.dist_range = cam.maxdist - cam.mindist
    cam.pitch_range = cam.maxdistpitch - cam.mindistpitch
    cam.default_fov = AppConfig.default_fov
    cam.fov_range = AppConfig.max_fov - 35
    cam.pitch_power = math_max(0.01, 0.5 - AppConfig.pitch_speed)

    if GLOBAL.PLAYER_CAMERA_MAX_DIST ~= nil then 
        GLOBAL.PLAYER_CAMERA_MAX_DIST = AppConfig.max_dist 
    end
    if GLOBAL.PLAYER_CAMERA_MAX_DIST_CAVES ~= nil then 
        GLOBAL.PLAYER_CAMERA_MAX_DIST_CAVES = AppConfig.max_dist 
    end
end

GLOBAL.TheSim:GetPersistentString(PERSIST_KEY, function(load_success, str)
    if load_success and str then
        local success, data = GLOBAL.pcall(GLOBAL.json.decode, str)
        if success and GLOBAL.type(data) == "table" then
            for k, v in pairs(data) do
                if AppConfig[k] ~= nil then
                    AppConfig[k] = v
                end
            end
        end
    end
end)

local function OpenSettingsMenu()
    if IsHUDActive() then
        local ZoomSettingsScreen = require("screens/zoomsettingsscreen")
        GLOBAL.TheFrontEnd:PushScreen(ZoomSettingsScreen(
            AppConfig,
            function(key, value, is_mouse)
                if key == "reset_bind" then
                    AppConfig.reset_bind = value
                    AppConfig.reset_is_mouse = is_mouse
                else
                    AppConfig[key] = value
                end
                ApplyCameraConfig()
                SaveAppConfig()
            end
        ))
    end
end

local function ResetCamera()
    if IsHUDActive() and GLOBAL.TheCamera then
        local is_cave = GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld:HasTag("cave")
        GLOBAL.TheCamera.distancetarget = is_cave and RESET_DIST_CAVE or RESET_DIST
    end
end

GLOBAL.TheInput:AddKeyDownHandler(GLOBAL.KEY_Z, function()
    local ctrl_down = GLOBAL.TheInput:IsKeyDown(GLOBAL.KEY_CTRL) or 
                      GLOBAL.TheInput:IsKeyDown(GLOBAL.KEY_LCTRL) or 
                      GLOBAL.TheInput:IsKeyDown(GLOBAL.KEY_RCTRL)
    
    if ctrl_down and IsHUDActive() then
        OpenSettingsMenu()
    end
end)

GLOBAL.TheInput:AddKeyHandler(function(key, down)
    if not down or AppConfig.reset_is_mouse then return end
    if key == AppConfig.reset_bind then ResetCamera() end
end)

GLOBAL.TheInput:AddMouseButtonHandler(function(button, down)
    if not down or not AppConfig.reset_is_mouse then return end
    if button == AppConfig.reset_bind then ResetCamera() end
end)

local function IsWX()
    -- WX-78 Zaptrocuter HARDFix..
    return GLOBAL.ThePlayer and GLOBAL.ThePlayer.prefab == "wx78" or false
end

local function UpdateZoom(inst)
    inst.SetDefaultOriginal = inst.SetDefault
    inst.SetDefault = function(self, ...)
        self:SetDefaultOriginal(...)
        self.is_wx = IsWX()
        ApplyCameraConfig()
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
            local curved_percent_d = percent_d ^ self.pitch_power
            
            self.pitch = self.mindistpitch + self.pitch_range * curved_percent_d
            
            if not self.is_wx then
                self.fov = self.default_fov + (self.fov_range or 0) * percent_d
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