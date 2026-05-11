local CameraMath = require("core/cameramath")

local CameraController = {}

local cached_config = nil
local cached_constants = nil
local GameEnv = nil

function CameraController.Initialize(config_state, game_env)
    cached_config = config_state.Settings
    cached_constants = config_state.CONSTANTS
    GameEnv = game_env
end

function CameraController.ApplyCameraConfig()
    if not GameEnv.TheCamera then return end

    local cam = GameEnv.TheCamera
    local is_cave = GameEnv.TheWorld ~= nil and GameEnv.TheWorld:HasTag("cave")

    cam.maxdist = cached_config.max_dist
    cam.mindist = cached_config.min_dist
    cam.mindistpitch = is_cave and cached_config.min_pitch_cave or cached_config.min_pitch
    cam.maxdistpitch = cached_config.max_pitch

    cam.dist_range = cam.maxdist - cam.mindist
    cam.pitch_range = cam.maxdistpitch - cam.mindistpitch
    cam.default_fov = cached_config.default_fov
    cam.fov_range = cached_config.max_fov - cached_config.default_fov
    cam.pitch_power = math.max(cached_constants.MIN_PITCH_POWER, cached_constants.BASE_PITCH_POWER - cached_config.pitch_speed)

    if GameEnv.PLAYER_CAMERA_MAX_DIST ~= nil then 
        GameEnv.PLAYER_CAMERA_MAX_DIST = cached_config.max_dist 
    end
    
    if GameEnv.PLAYER_CAMERA_MAX_DIST_CAVES ~= nil then 
        GameEnv.PLAYER_CAMERA_MAX_DIST_CAVES = cached_config.max_dist 
    end
end

function CameraController.ResetCamera()
    if not GameEnv.TheCamera then return end

    local is_cave = GameEnv.TheWorld ~= nil and GameEnv.TheWorld:HasTag("cave")
    GameEnv.TheCamera.distancetarget = is_cave and cached_constants.RESET_DIST_CAVE or cached_constants.RESET_DIST_SURFACE
end

local function IsWX()
    return GameEnv.ThePlayer and GameEnv.ThePlayer.prefab == "wx78" or false
end

function CameraController.HookCamera(inst)
    inst.SetDefaultOriginal = inst.SetDefault
    inst.SetDefault = function(self, ...)
        self:SetDefaultOriginal(...)
        self.is_wx = IsWX()
        CameraController.ApplyCameraConfig()
    end

    inst.ZoomInOriginal = inst.ZoomIn
    inst.ZoomIn = function(self, step)
        self:ZoomInOriginal(step or cached_config.zoom_sensitivity)
    end

    inst.ZoomOutOriginal = inst.ZoomOut
    inst.ZoomOut = function(self, step)
        self:ZoomOutOriginal(step or cached_config.zoom_sensitivity)
    end

    inst.UpdateOriginal = inst.Update
    inst.Update = function(self, dt, dontupdatepos)
        self.should_push_down = false
        self:UpdateOriginal(dt, dontupdatepos)
    end

    inst.ApplyOriginal = inst.Apply
    inst.Apply = function(self)
        if self.dist_range and self.dist_range > 0 then
            self.pitch, self.fov = CameraMath.CalculateCameraValues(
                self.distance, self.mindist, self.dist_range, 
                self.pitch_power, self.mindistpitch, self.pitch_range, 
                self.default_fov, self.fov_range, 
                self.is_wx, self.fov
            )
        end
        self:ApplyOriginal()
    end
end

return CameraController