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

local ZoomSettingsScreen = Class(Screen, function(self, current_bind, current_is_mouse, on_apply_fn)
    Screen._ctor(self, "ZoomSettingsScreen")
    
    self.current_bind = current_bind
    self.current_is_mouse = current_is_mouse
    self.on_apply_fn = on_apply_fn
    self.is_listening = false
    self.isoverlay = true

    self.black = self:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetVRegPoint(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetHRegPoint(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetVAnchor(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetHAnchor(GLOBAL.ANCHOR_MIDDLE)
    self.black:SetScaleMode(GLOBAL.SCALEMODE_FILLSCREEN)
    self.black:SetTint(0, 0, 0, 0.3)

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

    self.measure_text = self.root:AddChild(Text(GLOBAL.UIFONT, 28))
    self.measure_text:Hide()

    self.config_schema = {
        { id = "keybind", label = "Reset zoom:", type = "BIND" },
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
    local SETTINGS = {
        ROW_SPACING = 50,
        TEXT_SIZE = 28,
        TITLE_SIZE = 35,
        LABEL_GAP = 15,
        PADDING = 60,
        BTN_WIDTH = 200,
    }
    
    local max_lw = 0
    for _, item in ipairs(self.config_schema) do
        self.measure_text:SetString(item.label)
        local w, _ = self.measure_text:GetRegionSize()
        max_lw = math.max(max_lw, w)
    end

    local panel_w = max_lw + SETTINGS.BTN_WIDTH + SETTINGS.PADDING
    local panel_h = (#self.config_schema * SETTINGS.ROW_SPACING) + 160

    self.bg = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetSize(panel_w, panel_h)
    self.bg:SetTint(0, 0, 0, 0.6) 

    self.title = self.root:AddChild(Text(GLOBAL.UIFONT, SETTINGS.TITLE_SIZE, "Zoom+ Settings"))
    self.title:SetPosition(0, (panel_h * 0.5) - 45)
    self.title:SetColour(0.9, 0.8, 0.6, 1)

    local start_y = (panel_h * 0.5) - 110
    local left_x = -(panel_w * 0.5) + (SETTINGS.PADDING * 0.5)

    for i, item in ipairs(self.config_schema) do
        local row = self.root:AddChild(Widget("row_" .. item.id))
        row:SetPosition(left_x, start_y - ((i - 1) * SETTINGS.ROW_SPACING))

        local label = row:AddChild(Text(GLOBAL.UIFONT, SETTINGS.TEXT_SIZE, item.label))
        label:SetHAlign(GLOBAL.ANCHOR_LEFT)
        local lw, _ = label:GetRegionSize()
        label:SetPosition(lw * 0.5, 0)
        label:SetColour(0.8, 0.8, 0.8, 1)

        local btn = row:AddChild(TextButton())
        btn:SetFont(GLOBAL.UIFONT)
        btn:SetTextSize(SETTINGS.TEXT_SIZE)
        btn:SetTextColour(1, 1, 1, 1)
        btn:SetTextFocusColour(0.4, 0.7, 1, 1)
        
        btn.text:SetHAlign(GLOBAL.ANCHOR_LEFT)
        btn.text:SetRegionSize(SETTINGS.BTN_WIDTH, 40)
        btn:SetPosition(lw + SETTINGS.LABEL_GAP + (SETTINGS.BTN_WIDTH * 0.5), -2)

        if item.type == "BIND" then
            self.bind_btn = btn
            btn:SetOnClick(function() self:StartListening() end)
        end
    end

    self.apply_btn = self.root:AddChild(TextButton())
    self.apply_btn:SetFont(GLOBAL.UIFONT)
    self.apply_btn:SetTextSize(26)
    self.apply_btn:SetText("Back & Save")
    self.apply_btn:SetTextColour(1, 1, 1, 1)
    self.apply_btn:SetTextFocusColour(0.4, 0.7, 1, 1) 
    
    self.apply_btn:SetPosition((panel_w * 0.5) - 75, -(panel_h * 0.5) + 45)
    self.apply_btn:SetOnClick(function() self:Close() end)

    self:UpdateButtonText()
end

function ZoomSettingsScreen:UpdateButtonText()
    if not self.bind_btn then return end
    if self.is_listening then
        self.bind_btn:SetText("< Press Key >")
        self.bind_btn:SetTextColour(1, 0.4, 0.4, 1) 
    else
        local name = KEY_NAMES[self.current_bind] or tostring(self.current_bind)
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
        self.current_bind = key
        self.current_is_mouse = false
        self.is_listening = false
        self:UpdateButtonText()
        return true
    end
    return false
end

function ZoomSettingsScreen:OnMouseButton(button, down, x, y)
    if self.is_listening and down then
        if button == GLOBAL.MOUSEBUTTON_LEFT then return true end 
        self.current_bind = button
        self.current_is_mouse = true
        self.is_listening = false
        self:UpdateButtonText()
        return true
    end
    return ZoomSettingsScreen._base.OnMouseButton(self, button, down, x, y)
end

function ZoomSettingsScreen:Close()
    if self.on_apply_fn then
        self.on_apply_fn(self.current_bind, self.current_is_mouse)
    end
    GLOBAL.TheFrontEnd:PopScreen(self)
end

return ZoomSettingsScreen