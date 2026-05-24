--[[
I'm no Lua or modding expert, so I've likely missed some best practices here. 
This code needs a thorough review by experienced developers (or by myself 
later, once I learn the ropes better).
--]]

local GLOBAL = _G
local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Text = require("widgets/text")
local TextButton = require("widgets/textbutton")
local ImageButton = require("widgets/imagebutton")
local Image = require("widgets/image")

local math_floor = math.floor
local string_format = string.format
local string_sub = string.sub
local type = type
local tostring = tostring
local pcall = pcall

local TheFrontEnd = GLOBAL.TheFrontEnd
local TheSim = GLOBAL.TheSim
local TheInput = GLOBAL.TheInput
local Class = GLOBAL.Class

local LAYOUT = {
    PANEL_WIDTH = 550,
    PANEL_BASE_HEIGHT = 160,
    ROW_SPACING = 45,
    TITLE_OFFSET_Y = 40,
    START_Y_OFFSET = 95,
    LEFT_X_PADDING = 60,
    CONTROL_X = 330,
    BTN_BOTTOM_OFFSET = 45,
    STEPPER_OFFSET = 90,
    BTN_HEIGHT = 35,
    ARROW_SCALE = 0.4,
    TEXT_SIZE_SMALL = 22,
    TEXT_SIZE_MED = 24,
    TEXT_SIZE_LARGE = 32,
    
    HOLD_DELAY = 0.4,
    REPEAT_RATE = 0.02,

    PHASE_1_TIME = 0.5,
    PHASE_1_MULT = 2,
    PHASE_2_TIME = 2.0,
    PHASE_2_MULT = 8,
    PHASE_3_TIME = 4.0,
    PHASE_3_MULT = 16,

    CENTER_MULT = 0.5,
    MATH_ROUND_HALF = 0.5,

    BG_R = 0.05, BG_G = 0.05, BG_B = 0.05, BG_A = 0.85,
    OV_R = 0, OV_G = 0, OV_B = 0, OV_A = 0.4,
    TXT_R = 0.9, TXT_G = 0.9, TXT_B = 0.9, TXT_A = 1,
    FOC_R = 0.4, FOC_G = 0.7, FOC_B = 1, FOC_A = 1,
    TIT_R = 0.8, TIT_G = 0.7, TIT_B = 0.5, TIT_A = 1,
    ERR_R = 1, ERR_G = 0.4, ERR_B = 0.4, ERR_A = 1,
}

local KEY_NAMES_CACHE = {}

for k, v in pairs(GLOBAL) do
    if type(k) == "string" and type(v) == "number" then
        if string_sub(k, 1, 4) == "KEY_" then
            KEY_NAMES_CACHE[v] = string_sub(k, 5)
        elseif string_sub(k, 1, 12) == "MOUSEBUTTON_" then
            local btn = string_sub(k, 13)
            if btn == "RIGHT" then
                KEY_NAMES_CACHE[v] = "Right Click"
            elseif btn == "MIDDLE" then
                KEY_NAMES_CACHE[v] = "Middle Click"
            elseif btn == "LEFT" then
                KEY_NAMES_CACHE[v] = "Left Click"
            else
                KEY_NAMES_CACHE[v] = "Mouse " .. btn
            end
        end
    end
end

local function GetKeyName(val)
    return KEY_NAMES_CACHE[val] or tostring(val)
end

local NumericStepper = Class(Widget, function(self, value, step, decimals, callback)
    Widget._ctor(self, "NumericStepper")
    
    self.value = value
    self.step = step
    self.decimals = decimals
    self.callback = callback
    
    self.fmt_string = "%." .. decimals .. "f"
    self.multiplier = 10 ^ decimals
    self.last_str = ""
    self.hold_dir = 0
    self.hold_time = 0
    self.repeat_time = 0

    self.inst:ListenForEvent("onremove", function()
        if self.debounce_task then
            self.debounce_task:Cancel()
            self.debounce_task = nil
        end
        self:StopHold()
    end)

    self.left_btn = self:AddChild(ImageButton("images/ui.xml", "arrow_left.tex", "arrow_left_over.tex", "arrow_left_disabled.tex", "arrow_left_down.tex"))
    self.left_btn:SetPosition(-LAYOUT.STEPPER_OFFSET, 0)
    self.left_btn:SetScale(LAYOUT.ARROW_SCALE)

    self.right_btn = self:AddChild(ImageButton("images/ui.xml", "arrow_right.tex", "arrow_right_over.tex", "arrow_right_disabled.tex", "arrow_right_down.tex"))
    self.right_btn:SetPosition(LAYOUT.STEPPER_OFFSET, 0)
    self.right_btn:SetScale(LAYOUT.ARROW_SCALE)

    self.text = self:AddChild(Text(GLOBAL.UIFONT, LAYOUT.TEXT_SIZE_MED))
    
    self:UpdateText()
end)

function NumericStepper:OnControl(control, down)
    if control == GLOBAL.CONTROL_ACCEPT then
        if self.left_btn.focus then
            if down then self:StartHold(-1) else self:StopHold() end
            return true
        elseif self.right_btn.focus then
            if down then self:StartHold(1) else self:StopHold() end
            return true
        end
    end
    return false
end

function NumericStepper:StartHold(dir)
    self.hold_dir = dir
    self.hold_time = 0
    self.repeat_time = LAYOUT.HOLD_DELAY
    self:DeltaValue(self.step * self.hold_dir)
    self:StartUpdating()
end

function NumericStepper:StopHold()
    self.hold_dir = 0
    self:StopUpdating()
end

function NumericStepper:OnUpdate(dt)
    if self.hold_dir ~= 0 then
        if not self.inst:IsValid() or not TheInput:IsMouseDown(GLOBAL.MOUSEBUTTON_LEFT) then
            self:StopHold()
            return
        end

        self.hold_time = self.hold_time + dt
        if self.hold_time > LAYOUT.HOLD_DELAY then
            self.repeat_time = self.repeat_time - dt
            if self.repeat_time <= 0 then
                self.repeat_time = LAYOUT.REPEAT_RATE
                
                local current_mult = 1
                local active_hold = self.hold_time - LAYOUT.HOLD_DELAY

                if active_hold > LAYOUT.PHASE_3_TIME then
                    current_mult = LAYOUT.PHASE_3_MULT
                elseif active_hold > LAYOUT.PHASE_2_TIME then
                    current_mult = LAYOUT.PHASE_2_MULT
                elseif active_hold > LAYOUT.PHASE_1_TIME then
                    current_mult = LAYOUT.PHASE_1_MULT
                end
                
                self:DeltaValue(self.step * self.hold_dir * current_mult)
            end
        end
    end
end

function NumericStepper:DeltaValue(delta)
    local raw_val = self.value + delta
    local new_val = math_floor(raw_val * self.multiplier + LAYOUT.MATH_ROUND_HALF) / self.multiplier
    
    if self.value ~= new_val then
        self.value = new_val
        self:UpdateText()
        
        if self.debounce_task then
            self.debounce_task:Cancel()
        end
        
        self.debounce_task = self.inst:DoTaskInTime(0.15, function()
            self.debounce_task = nil
            if self.callback then
                pcall(self.callback, self.value)
            end
        end)
    end
end

function NumericStepper:SetValue(val)
    self.value = val
    self:UpdateText()
end

function NumericStepper:UpdateText()
    local str = string_format(self.fmt_string, self.value)
    if self.last_str ~= str then
        self.last_str = str
        self.text:SetString(str)
    end
end

local ZoomSettingsScreen = Class(Screen, function(self, app_config, default_config, on_change_fn)
    Screen._ctor(self, "ZoomSettingsScreen")

    self.app_config = app_config
    self.default_config = default_config
    self.on_change_fn = on_change_fn
    self.is_listening = false
    self.isoverlay = true
    self.controls = {}

    self.config_schema = {
        { id = "reset_bind", label = "Reset Zoom Key", type = "BIND" },
        { id = "max_dist", label = "Max Distance", type = "STEPPER", step = 1, decimals = 0 },
        { id = "min_dist", label = "Min Distance", type = "STEPPER", step = 1, decimals = 0 },
        { id = "max_pitch", label = "Max Pitch", type = "STEPPER", step = 1, decimals = 0 },
        { id = "min_pitch", label = "Min Pitch", type = "STEPPER", step = 1, decimals = 0 },
        { id = "min_pitch_cave", label = "Min Pitch Cave", type = "STEPPER", step = 1, decimals = 0 },
        { id = "default_fov", label = "Default FOV", type = "STEPPER", step = 1, decimals = 0 },
        { id = "max_fov", label = "Max FOV", type = "STEPPER", step = 1, decimals = 0 },
        { id = "pitch_speed", label = "Pitch Speed", type = "STEPPER", step = 0.01, decimals = 2 },
    }

    self.panel_h = (#self.config_schema * LAYOUT.ROW_SPACING) + LAYOUT.PANEL_BASE_HEIGHT

    self:BuildOverlay()
    self:BuildBackground()
    self:BuildRows()
    self:BuildBottomButtons()
end)

function ZoomSettingsScreen:OnBecomeActive()
    ZoomSettingsScreen._base.OnBecomeActive(self)
    self.root:SetFocus()
end

function ZoomSettingsScreen:BuildOverlay()
    self.black = self:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetVRegPoint(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetHRegPoint(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetVAnchor(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetHAnchor(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetScaleMode(GLOBAL.SCALEMODE_FILLSCREEN)
    self.black:SetTint(LAYOUT.OV_R, LAYOUT.OV_G, LAYOUT.OV_B, LAYOUT.OV_A)
    
    self.black.OnMouseButton = function(_, button, down)
        if not down and button == GLOBAL.MOUSEBUTTON_LEFT then
            if self.is_listening then
                self.is_listening = false
                self:UpdateButtonText()
            else
                self:Close()
            end
            return true
        end
    end
end

function ZoomSettingsScreen:BuildBackground()
    self.root = self:AddChild(Widget("ROOT"))
    self.root:SetVAnchor(GLOBAL.ANCHOR_MIDDLE)
    self.root:SetHAnchor(GLOBAL.ANCHOR_MIDDLE)
    self.root:SetScaleMode(GLOBAL.SCALEMODE_PROPORTIONAL)

    local _, h = TheSim:GetScreenSize()
    local target_h = self.panel_h + 100
    if h > 0 and target_h > h then
        self.root:SetScale(h / target_h)
    end

    self.bg = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetSize(LAYOUT.PANEL_WIDTH, self.panel_h)
    self.bg:SetTint(LAYOUT.BG_R, LAYOUT.BG_G, LAYOUT.BG_B, LAYOUT.BG_A)

    self.title = self.root:AddChild(Text(GLOBAL.UIFONT, LAYOUT.TEXT_SIZE_LARGE, "Zoom+ Settings"))
    self.title:SetPosition(0, self.panel_h * LAYOUT.CENTER_MULT - LAYOUT.TITLE_OFFSET_Y)
    self.title:SetColour(LAYOUT.TIT_R, LAYOUT.TIT_G, LAYOUT.TIT_B, LAYOUT.TIT_A)
end

function ZoomSettingsScreen:BuildRows()
    local start_y = self.panel_h * LAYOUT.CENTER_MULT - LAYOUT.START_Y_OFFSET
    local left_x = -LAYOUT.PANEL_WIDTH * LAYOUT.CENTER_MULT + LAYOUT.LEFT_X_PADDING

    for i, item in ipairs(self.config_schema) do
        local row = self.root:AddChild(Widget("row_" .. item.id))
        row:SetPosition(left_x, start_y - ((i - 1) * LAYOUT.ROW_SPACING))

        local label = row:AddChild(Text(GLOBAL.UIFONT, LAYOUT.TEXT_SIZE_MED, item.label))
        label:SetHAlign(GLOBAL.ANCHOR_LEFT)
        local lw, _ = label:GetRegionSize()
        label:SetPosition(lw * LAYOUT.CENTER_MULT, 0)
        label:SetColour(LAYOUT.TXT_R, LAYOUT.TXT_G, LAYOUT.TXT_B, LAYOUT.TXT_A)

        if item.type == "BIND" then
            self:BuildBindControl(row, item)
        elseif item.type == "STEPPER" then
            self:BuildStepperControl(row, item)
        end
    end
end

function ZoomSettingsScreen:BuildBindControl(parent, item)
    self.bind_btn = parent:AddChild(TextButton())
    self.bind_btn:SetFont(GLOBAL.UIFONT)
    self.bind_btn:SetTextSize(LAYOUT.TEXT_SIZE_MED)
    self.bind_btn:SetTextColour(LAYOUT.TXT_R, LAYOUT.TXT_G, LAYOUT.TXT_B, LAYOUT.TXT_A)
    self.bind_btn:SetTextFocusColour(LAYOUT.FOC_R, LAYOUT.FOC_G, LAYOUT.FOC_B, LAYOUT.FOC_A)
    self.bind_btn.text:SetHAlign(GLOBAL.ANCHOR_LEFT)
    self.bind_btn.text:SetRegionSize(LAYOUT.STEPPER_OFFSET * 2, LAYOUT.BTN_HEIGHT)
    self.bind_btn:SetPosition(LAYOUT.CONTROL_X, 0)
    self.bind_btn:SetOnClick(function()
        self.is_listening = true
        self:UpdateButtonText()
    end)
    
    self:UpdateButtonText()
end

function ZoomSettingsScreen:BuildStepperControl(parent, item)
    local initial_value = self.app_config[item.id] or self.default_config[item.id]
    local stepper = parent:AddChild(NumericStepper(initial_value, item.step, item.decimals, function(val)
        self.on_change_fn(item.id, val, false)
    end))
    stepper:SetPosition(LAYOUT.CONTROL_X, 0)
    self.controls[item.id] = stepper
end

function ZoomSettingsScreen:BuildBottomButtons()
    local y_pos = -self.panel_h * LAYOUT.CENTER_MULT + LAYOUT.BTN_BOTTOM_OFFSET
    local x_offset = (LAYOUT.PANEL_WIDTH * LAYOUT.CENTER_MULT) * LAYOUT.CENTER_MULT

    self.reset_btn = self.root:AddChild(TextButton())
    self.reset_btn:SetFont(GLOBAL.UIFONT)
    self.reset_btn:SetTextSize(LAYOUT.TEXT_SIZE_MED)
    self.reset_btn:SetText("Reset Defaults")
    self.reset_btn:SetTextColour(LAYOUT.TXT_R, LAYOUT.TXT_G, LAYOUT.TXT_B, LAYOUT.TXT_A)
    self.reset_btn:SetTextFocusColour(LAYOUT.FOC_R, LAYOUT.FOC_G, LAYOUT.FOC_B, LAYOUT.FOC_A)
    self.reset_btn:SetPosition(-x_offset, y_pos)
    self.reset_btn:SetOnClick(function() self:ResetToDefaults() end)

    self.apply_btn = self.root:AddChild(TextButton())
    self.apply_btn:SetFont(GLOBAL.UIFONT)
    self.apply_btn:SetTextSize(LAYOUT.TEXT_SIZE_MED)
    self.apply_btn:SetText("Back & Save")
    self.apply_btn:SetTextColour(LAYOUT.TXT_R, LAYOUT.TXT_G, LAYOUT.TXT_B, LAYOUT.TXT_A)
    self.apply_btn:SetTextFocusColour(LAYOUT.FOC_R, LAYOUT.FOC_G, LAYOUT.FOC_B, LAYOUT.FOC_A)
    self.apply_btn:SetPosition(x_offset, y_pos)
    self.apply_btn:SetOnClick(function() self:Close() end)
end

function ZoomSettingsScreen:ResetToDefaults()
    for _, item in ipairs(self.config_schema) do
        local def_val = self.default_config[item.id]
        
        if item.type == "BIND" then
            self.app_config[item.id] = def_val
            self.app_config.reset_is_mouse = self.default_config.reset_is_mouse
            self.on_change_fn(item.id, def_val, self.default_config.reset_is_mouse)
            self:UpdateButtonText()
        elseif item.type == "STEPPER" then
            self.app_config[item.id] = def_val
            self.on_change_fn(item.id, def_val, false)
            if self.controls[item.id] then
                self.controls[item.id]:SetValue(def_val)
            end
        end
    end
end

function ZoomSettingsScreen:UpdateButtonText()
    if not self.bind_btn then return end
    
    if self.is_listening then
        self.bind_btn:SetText("< Press Key >")
        self.bind_btn:SetTextColour(LAYOUT.ERR_R, LAYOUT.ERR_G, LAYOUT.ERR_B, LAYOUT.ERR_A)
    else
        self.bind_btn:SetText("> " .. GetKeyName(self.app_config.reset_bind) .. " <")
        self.bind_btn:SetTextColour(LAYOUT.TXT_R, LAYOUT.TXT_G, LAYOUT.TXT_B, LAYOUT.TXT_A)
    end
end

function ZoomSettingsScreen:OnRawKey(key, down)
    if self.is_listening and down then
        if key == GLOBAL.KEY_ESCAPE then return false end
        self.on_change_fn("reset_bind", key, false)
        self.is_listening = false
        self:UpdateButtonText()
        return true
    end
    return false
end

function ZoomSettingsScreen:OnMouseButton(button, down, x, y)
    if self.is_listening and down then
        if button == GLOBAL.MOUSEBUTTON_LEFT then return true end
        self.on_change_fn("reset_bind", button, true)
        self.is_listening = false
        self:UpdateButtonText()
        return true
    end
    return ZoomSettingsScreen._base.OnMouseButton(self, button, down, x, y)
end

function ZoomSettingsScreen:OnControl(control, down)
    ZoomSettingsScreen._base.OnControl(self, control, down)
    if not down and control == GLOBAL.CONTROL_CANCEL then
        if self.is_listening then
            self.is_listening = false
            self:UpdateButtonText()
        else
            self:Close()
        end
    end
    return true
end

function ZoomSettingsScreen:Close()
    TheFrontEnd:PopScreen(self)
end

return ZoomSettingsScreen