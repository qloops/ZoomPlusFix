local CameraMath = require("core/cameramath")

local CameraController = {}

local math_max = math.max

local cached_config = nil
local cached_constants = nil
local GameEnv = nil

local function IsCave()
    return GameEnv.TheWorld ~= nil and GameEnv.TheWorld:HasTag("cave")
end

function CameraController.Initialize(config_state, game_env)
    cached_config = config_state.Settings
    cached_constants = config_state.CONSTANTS
    GameEnv = game_env
end

-- Fixes extreme zoom on WX-78's drone when FOV is overridden.
function CameraController.HookFocalPoint(inst)
    local focal_comp = inst.components.focalpoint
    if not focal_comp then return end

    local original_StartFocus = focal_comp.StartFocusSource
    focal_comp.StartFocusSource = function(self, source, id, ...)
        if GameEnv.TheCamera then GameEnv.TheCamera.focus_locked = true end
        return original_StartFocus(self, source, id, ...)
    end

    local original_StopFocus = focal_comp.StopFocusSource
    focal_comp.StopFocusSource = function(self, source, id, ...)
        local result = original_StopFocus(self, source, id, ...)
        if GameEnv.TheCamera then
            local has_active_focus = self.focussources ~= nil and next(self.focussources) ~= nil
            GameEnv.TheCamera.focus_locked = has_active_focus
        end
        return result
    end
end

function CameraController.ApplyCameraConfig()
    if not GameEnv.TheCamera then return end

    local cam = GameEnv.TheCamera

    cam.maxdist = cached_config.max_dist
    cam.mindist = cached_config.min_dist
    cam.mindistpitch = IsCave() and cached_config.min_pitch_cave or cached_config.min_pitch
    cam.maxdistpitch = cached_config.max_pitch

    cam.dist_range = cam.maxdist - cam.mindist
    cam.pitch_range = cam.maxdistpitch - cam.mindistpitch
    cam.default_fov = cached_config.default_fov
    cam.fov_range = cached_config.max_fov - cached_config.default_fov
    cam.pitch_power = math_max(
        cached_constants.MIN_PITCH_POWER, 
        cached_constants.BASE_PITCH_POWER - cached_config.pitch_speed
    )

    if GameEnv.PLAYER_CAMERA_MAX_DIST ~= nil then 
        GameEnv.PLAYER_CAMERA_MAX_DIST = cached_config.max_dist 
    end
    if GameEnv.PLAYER_CAMERA_MAX_DIST_CAVES ~= nil then 
        GameEnv.PLAYER_CAMERA_MAX_DIST_CAVES = cached_config.max_dist 
    end
end

function CameraController.ResetCamera()
    if not GameEnv.TheCamera then return end

    local is_cave = IsCave()

    GameEnv.TheCamera.distancetarget = is_cave 
    and cached_config.reset_dist_cave 
    or cached_config.reset_dist_surface
end

function CameraController.HookCamera(inst)
    inst.SetDefaultOriginal = inst.SetDefault
    inst.SetDefault = function(self, ...)
        self:SetDefaultOriginal(...)
        self.focus_locked = false
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
            local allow_custom_fov = not self.focus_locked

            self.pitch, self.fov = CameraMath.CalculateCameraValues(
                self.distance, self.mindist, self.dist_range,
                self.pitch_power, self.mindistpitch, self.pitch_range,
                self.default_fov, self.fov_range,
                allow_custom_fov, self.fov
            )
        end
        self:ApplyOriginal()
    end
end

return CameraController