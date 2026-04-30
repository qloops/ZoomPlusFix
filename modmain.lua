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

local RESET_BIND = GLOBAL.MOUSEBUTTON_MIDDLE

if GLOBAL.PLAYER_CAMERA_MAX_DIST ~= nil then GLOBAL.PLAYER_CAMERA_MAX_DIST = MAX_DIST end
if GLOBAL.PLAYER_CAMERA_MAX_DIST_CAVES ~= nil then GLOBAL.PLAYER_CAMERA_MAX_DIST_CAVES = MAX_DIST end

local function IsWX()
    -- WX-78 Zaptrocuter Fix..
    if GLOBAL.ThePlayer and GLOBAL.ThePlayer.prefab == "wx78" then return true end
    return false
end

local function ResetCamera()
    if GLOBAL.TheCamera and GLOBAL.TheFrontEnd:GetActiveScreen() and GLOBAL.TheFrontEnd:GetActiveScreen().name == "HUD" then
        local is_cave = GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld:HasTag("cave")
        GLOBAL.TheCamera.distancetarget = is_cave and RESET_DIST_CAVE or RESET_DIST
    end
end

if RESET_BIND then
    TheInput:AddMouseButtonHandler(function(button, down)
        if button == RESET_BIND and down then
            ResetCamera()
        end
    end)
end

local function updateZoom(inst)
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

AddGlobalClassPostConstruct("cameras/followcamera", "FollowCamera", updateZoom)

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