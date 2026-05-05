local GLOBAL = _G
local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local TextButton = require "widgets/textbutton"
local Image = require "widgets/image"

local KEY_NAMES = {}
local function BuildKeyNames()
    for k, v in pairs(GLOBAL) do
        if type(k) == "string" and type(v) == "number" then
            if k:find("^KEY_") then
                KEY_NAMES[v] = k:sub(5)
            elseif k:find("^MOUSEBUTTON_") then
                local btn = k:sub(13)
                if btn == "RIGHT" then KEY_NAMES[v] = "Right Click"
                elseif btn == "MIDDLE" then KEY_NAMES[v] = "Middle Click"
                elseif btn == "LEFT" then KEY_NAMES[v] = "Left Click"
                else KEY_NAMES[v] = "Mouse " .. btn end
            end
        end
    end
end
BuildKeyNames()

local DragSlider = Class(Widget, function(self, min, max, value, callback)
    Widget._ctor(self, "DragSlider")
    self.min = min
    self.max = max
    self.value = value
    self.callback = callback
    self.width = 200

    self.bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetSize(self.width, 6)
    self.bg:SetTint(0.2, 0.2, 0.2, 1)

    self.left_marker = self:AddChild(Widget("left_marker"))
    self.left_marker:SetPosition(-self.width / 2, 0)

    self.right_marker = self:AddChild(Widget("right_marker"))
    self.right_marker:SetPosition(self.width / 2, 0)

    self.fill = self:AddChild(Image("images/global.xml", "square.tex"))
    self.fill:SetSize(0, 6)
    self.fill:SetTint(0.4, 0.7, 1, 1)

    self.knob = self:AddChild(Image("images/global.xml", "square.tex"))
    self.knob:SetSize(14, 28)
    self.knob:SetTint(0.9, 0.9, 0.9, 1)

    self.text = self:AddChild(Text(GLOBAL.UIFONT, 24))
    self.text:SetPosition(self.width / 2 + 50, 0)
    self.text:SetHAlign(GLOBAL.ANCHOR_LEFT)

    self.is_dragging = false
    self:UpdateVisuals()
end)

function DragSlider:UpdateVisuals()
    local pct = math.max(0, math.min(1, (self.value - self.min) / (self.max - self.min)))
    local x = -self.width / 2 + (self.width * pct)
    
    self.knob:SetPosition(x, 0)
    self.fill:SetSize(self.width * pct, 6)
    self.fill:SetPosition(-self.width / 2 + (self.width * pct) / 2, 0)
    
    if self.min < 0 then
        self.text:SetString(string.format("%.2f", self.value))
    else
        self.text:SetString(string.format("%.0f", self.value))
    end
end

function DragSlider:SetValue(val)
    self.value = math.max(self.min, math.min(self.max, val))
    self:UpdateVisuals()
end

function DragSlider:UpdateFromMouse()
    local mx = GLOBAL.TheInput:GetScreenPosition().x
    local lx = self.left_marker.inst.UITransform:GetWorldPosition()
    local rx = self.right_marker.inst.UITransform:GetWorldPosition()
    
    if lx and rx and rx ~= lx then
        local pct = (mx - lx) / (rx - lx)
        pct = math.max(0, math.min(1, pct))
        
        local new_val = self.min + (self.max - self.min) * pct
        
        if new_val ~= self.value then
            self.value = new_val
            self:UpdateVisuals()
            if self.callback then self.callback(self.value) end
        end
    end
end

function DragSlider:OnUpdate(dt)
    if self.is_dragging then
        if not GLOBAL.TheInput:IsMouseDown(GLOBAL.MOUSEBUTTON_LEFT) then
            self.is_dragging = false
            self:StopUpdating()
            return
        end
        self:UpdateFromMouse()
    end
end

function DragSlider:OnMouseButton(button, down, x, y)
    if button == GLOBAL.MOUSEBUTTON_LEFT then
        if down then
            self.is_dragging = true
            self:StartUpdating()
            self:UpdateFromMouse()
        else
            self.is_dragging = false
            self:StopUpdating()
        end
        return true
    end
    return false
end

local ZoomSettingsScreen = Class(Screen, function(self, app_config, on_change_fn)
    Screen._ctor(self, "ZoomSettingsScreen")
    
    self.app_config = app_config
    self.on_change_fn = on_change_fn
    self.is_listening = false
    self.isoverlay = true
    self.sliders = {}

    self.black = self:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetVRegPoint(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetHRegPoint(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetVAnchor(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetHAnchor(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetScaleMode(GLOBAL.SCALEMODE_FILLSCREEN)
    self.black:SetTint(0, 0, 0, 0.25)

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

    self.root = self:AddChild(Widget("ROOT"))
    self.root:SetVAnchor(GLOBAL.ANCHOR_MIDDLE)
    self.root:SetHAnchor(GLOBAL.ANCHOR_MIDDLE)
    self.root:SetScaleMode(GLOBAL.SCALEMODE_PROPORTIONAL)

    self.config_schema = {
        { id = "reset_bind", label = "Reset zoom key", type = "BIND", default_bind = GLOBAL.MOUSEBUTTON_MIDDLE, default_is_mouse = true },
        { id = "max_dist", label = "Max Distance", type = "SLIDER", min = 0, max = 180, default = 180 },
        { id = "min_dist", label = "Min Distance", type = "SLIDER", min = 0, max = 180, default = 3 },
        { id = "min_pitch", label = "Min Pitch", type = "SLIDER", min = 0, max = 90, default = 30 },
        { id = "min_pitch_cave", label = "Min Pitch Cave", type = "SLIDER", min = 0, max = 90, default = 25 },
        { id = "max_pitch", label = "Max Pitch", type = "SLIDER", min = 0, max = 90, default = 85 },
        { id = "default_fov", label = "Default FOV", type = "SLIDER", min = 0, max = 220, default = 35 },
        { id = "max_fov", label = "Max FOV", type = "SLIDER", min = 0, max = 220, default = 70 },
        { id = "pitch_speed", label = "Pitch Speed", type = "SLIDER", min = -1.5, max = 0.49, default = 0.07 },
    }

    self:InitLayout()
end)

function ZoomSettingsScreen:OnControl(control, down)
    if ZoomSettingsScreen._base.OnControl(self, control, down) then return true end
    if not down and control == GLOBAL.CONTROL_CANCEL then
        if self.is_listening then
            self.is_listening = false
            self:UpdateButtonText()
        else
            self:Close()
        end
        return true
    end
    return false
end

function ZoomSettingsScreen:InitLayout()
    local ROW_SPACING = 45
    local PADDING = 80
    local BTN_WIDTH = 250
    local panel_w = 550
    local panel_h = (#self.config_schema * ROW_SPACING) + 140

    self.bg = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetSize(panel_w, panel_h)
    self.bg:SetTint(0, 0, 0, 0.5) 

    self.title = self.root:AddChild(Text(GLOBAL.UIFONT, 35, "Zoom+ Settings"))
    self.title:SetPosition(0, (panel_h * 0.5) - 40)
    self.title:SetColour(0.9, 0.8, 0.6, 1)

    local start_y = (panel_h * 0.5) - 100
    local left_x = -(panel_w * 0.5) + PADDING

    for i, item in ipairs(self.config_schema) do
        local row = self.root:AddChild(Widget("row_" .. item.id))
        row:SetPosition(left_x, start_y - ((i - 1) * ROW_SPACING))

        local label = row:AddChild(Text(GLOBAL.UIFONT, 26, item.label))
        label:SetHAlign(GLOBAL.ANCHOR_LEFT)
        local lw, _ = label:GetRegionSize()
        label:SetPosition(lw * 0.5, 0)
        label:SetColour(0.8, 0.8, 0.8, 1)

        if item.type == "BIND" then
            local btn = row:AddChild(TextButton())
            btn:SetFont(GLOBAL.UIFONT)
            btn:SetTextSize(26)
            btn:SetTextColour(1, 1, 1, 1)
            btn:SetTextFocusColour(0.4, 0.7, 1, 1)
            btn.text:SetHAlign(GLOBAL.ANCHOR_LEFT)
            btn.text:SetRegionSize(BTN_WIDTH, 40)
            btn:SetPosition(250, -2)
            btn:SetOnClick(function() self:StartListening() end)
            self.bind_btn = btn
            self:UpdateButtonText()

        elseif item.type == "SLIDER" then
            local slider = row:AddChild(DragSlider(item.min, item.max, self.app_config[item.id] or item.default, function(val)
                self.on_change_fn(item.id, val, false)
            end))
            slider:SetPosition(250, -2)
            self.sliders[item.id] = slider
        end
    end

    self.reset_btn = self.root:AddChild(TextButton())
    self.reset_btn:SetFont(GLOBAL.UIFONT)
    self.reset_btn:SetTextSize(26)
    self.reset_btn:SetText("Reset Defaults")
    self.reset_btn:SetTextColour(1, 1, 1, 1)
    self.reset_btn:SetTextFocusColour(0.4, 0.7, 1, 1) 
    self.reset_btn:SetPosition(-110, -(panel_h * 0.5) + 45)
    self.reset_btn:SetOnClick(function() self:ResetToDefaults() end)

    self.apply_btn = self.root:AddChild(TextButton())
    self.apply_btn:SetFont(GLOBAL.UIFONT)
    self.apply_btn:SetTextSize(26)
    self.apply_btn:SetText("Back & Save")
    self.apply_btn:SetTextColour(1, 1, 1, 1)
    self.apply_btn:SetTextFocusColour(0.4, 0.7, 1, 1) 
    self.apply_btn:SetPosition(110, -(panel_h * 0.5) + 45)
    self.apply_btn:SetOnClick(function() self:Close() end)
end

function ZoomSettingsScreen:ResetToDefaults()
    for _, item in ipairs(self.config_schema) do
        if item.type == "BIND" then
            self.app_config[item.id] = item.default_bind
            self.app_config.reset_is_mouse = item.default_is_mouse
            self.on_change_fn(item.id, item.default_bind, item.default_is_mouse)
            self:UpdateButtonText()
        elseif item.type == "SLIDER" then
            self.app_config[item.id] = item.default
            self.on_change_fn(item.id, item.default, false)
            if self.sliders[item.id] then
                self.sliders[item.id]:SetValue(item.default)
            end
        end
    end
end

function ZoomSettingsScreen:UpdateButtonText()
    if not self.bind_btn then return end
    if self.is_listening then
        self.bind_btn:SetText("< Press Key >")
        self.bind_btn:SetTextColour(1, 0.4, 0.4, 1) 
    else
        local name = KEY_NAMES[self.app_config.reset_bind] or tostring(self.app_config.reset_bind)
        self.bind_btn:SetText("[ " .. name .. " ]")
        self.bind_btn:SetTextColour(1, 1, 1, 1)
    end
end

function ZoomSettingsScreen:StartListening()
    self.is_listening = true
    self:UpdateButtonText()
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

function ZoomSettingsScreen:Close()
    GLOBAL.TheFrontEnd:PopScreen(self)
end

return ZoomSettingsScreen