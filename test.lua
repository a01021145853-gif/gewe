--[[
=====================================================================
    Library.lua  ·  reusable Roblox UI library
    v1.0.0
=====================================================================
    QUICK START
        local Library = loadstring(readfile("Library.lua"))()

        local Window = Library:CreateWindow({
            Title = "My Hub",
            Subtitle = "ROBLOX SCRIPT HUB",
        })

        local Page = Window:Page("main", { Title = "Main", Icon = "games" })
        local Section = Page:Section({ Title = "Actions", Description = "Buttons and toggles" })

        Section:Button({
            Text = "Say hello",
            Description = "Shows a notification",
            Callback = function()
                Window:Notify("Hello", "This is a toast notification.", "success")
            end,
        })

    DRAG
        Click any empty part of the window (header, sidebar background,
        space between cards) and drag. Buttons, text boxes, lists, sliders
        and popups keep their normal behaviour.

    KEY
        RightShift opens/closes the window by default (configurable).

    NOTE
        The library returns a table. Only run code you trust.
=====================================================================
]]

local Library = {}
Library.Version = "1.0.0"
Library._windows = {}
Library.LastWindow = nil

--=====================================================================
-- SERVICES / THEME
--=====================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local COLORS = {
    window = Color3.fromRGB(10, 11, 15),
    sidebar = Color3.fromRGB(8, 9, 12),
    panel = Color3.fromRGB(17, 18, 23),
    card = Color3.fromRGB(20, 21, 27),
    input = Color3.fromRGB(15, 16, 21),
    text = Color3.fromRGB(244, 245, 247),
    muted = Color3.fromRGB(145, 148, 158),
    dim = Color3.fromRGB(92, 95, 106),
    white = Color3.fromRGB(245, 246, 248),
    black = Color3.fromRGB(9, 10, 13),
    accent = Color3.fromRGB(245, 246, 248),
    green = Color3.fromRGB(95, 226, 143),
    red = Color3.fromRGB(255, 107, 107),
    amber = Color3.fromRGB(255, 191, 92),
    stroke = Color3.fromRGB(255, 255, 255),
}
Library.Theme = COLORS

local FONT = Enum.Font.Gotham
local FONT_MED = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local SIDEBAR_WIDTH = 220
local WINDOW_COUNT = 0

--=====================================================================
-- HELPERS
--=====================================================================

local function create(class, props, children)
    local object = Instance.new(class)
    for key, value in next, props or {} do
        if key ~= "Parent" then
            object[key] = value
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = object
    end
    if props and props.Parent then
        object.Parent = props.Parent
    end
    return object
end

local function frame(props)
    if props.BorderSizePixel == nil then
        props.BorderSizePixel = 0
    end
    if props.BackgroundTransparency == nil then
        props.BackgroundTransparency = 0
    end
    return create("Frame", props)
end

local function label(props)
    if props.BackgroundTransparency == nil then
        props.BackgroundTransparency = 1
    end
    if props.BorderSizePixel == nil then
        props.BorderSizePixel = 0
    end
    if not props.Font then
        props.Font = FONT
    end
    if not props.TextColor3 then
        props.TextColor3 = COLORS.text
    end
    if not props.TextSize then
        props.TextSize = 14
    end
    if not props.TextXAlignment then
        props.TextXAlignment = Enum.TextXAlignment.Left
    end
    if not props.TextYAlignment then
        props.TextYAlignment = Enum.TextYAlignment.Center
    end
    return create("TextLabel", props)
end

local function button(props)
    if props.BackgroundTransparency == nil then
        props.BackgroundTransparency = 0
    end
    if props.BorderSizePixel == nil then
        props.BorderSizePixel = 0
    end
    if not props.Font then
        props.Font = FONT_MED
    end
    if not props.TextColor3 then
        props.TextColor3 = COLORS.text
    end
    if not props.TextSize then
        props.TextSize = 14
    end
    if not props.TextXAlignment then
        props.TextXAlignment = Enum.TextXAlignment.Center
    end
    if not props.TextYAlignment then
        props.TextYAlignment = Enum.TextYAlignment.Center
    end
    if props.AutoButtonColor == nil then
        props.AutoButtonColor = false
    end
    return create("TextButton", props)
end

local function corner(object, radius)
    return create("UICorner", {
        Parent = object,
        CornerRadius = UDim.new(0, radius),
    })
end

local function stroke(object, color, transparency, thickness)
    return create("UIStroke", {
        Parent = object,
        Color = color or COLORS.stroke,
        Transparency = transparency or 0.92,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function gradient(object, colorA, colorB, rotation)
    return create("UIGradient", {
        Parent = object,
        Color = ColorSequence.new(colorA, colorB),
        Rotation = rotation or 90,
    })
end

local function pad(object, left, top, right, bottom)
    return create("UIPadding", {
        Parent = object,
        PaddingLeft = UDim.new(0, left),
        PaddingTop = UDim.new(0, top),
        PaddingRight = UDim.new(0, right),
        PaddingBottom = UDim.new(0, bottom),
    })
end

local function layout(object, gap)
    return create("UIListLayout", {
        Parent = object,
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0),
    })
end

local function tween(object, duration, props, style, direction)
    local info = TweenInfo.new(
        duration or 0.16,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out
    )
    local animation = TweenService:Create(object, info, props)
    animation:Play()
    return animation
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function disconnectAll(connections)
    for _, connection in ipairs(connections or {}) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
end

local function measureText(content, textSize, width)
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(
            tostring(content),
            textSize,
            FONT,
            Vector2.new(math.max(80, width), 10000)
        )
    end)
    if ok and bounds then
        return math.ceil(bounds.Y)
    end
    local roughLines = math.ceil(#tostring(content) / math.max(10, width / (textSize * 0.55)))
    return roughLines * (textSize + 4)
end

local function formatNumber(value)
    if value == math.floor(value) then
        return tostring(math.floor(value))
    end
    local formatted = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
    return formatted
end

local function keyName(key)
    if key == nil then
        return "Not set"
    end
    if key.Name then
        return key.Name
    end
    local name = tostring(key)
    return (name:gsub("^Enum%.KeyCode%.", ""))
end

local function getGuiParent()
    if gethui then
        local ok, hidden = pcall(gethui)
        if ok and hidden then
            return hidden
        end
    end
    return player:WaitForChild("PlayerGui")
end

local function tintIcon(holder, color)
    for _, child in ipairs(holder:GetDescendants()) do
        if child:IsA("Frame") then
            child.BackgroundColor3 = color
        elseif child:IsA("TextLabel") then
            child.TextColor3 = color
        end
    end
end

local function makeIcon(parent, kind, size, color)
    local holder = frame({
        Parent = parent,
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
    })
    local key = tostring(kind or ""):lower()

    if key == "games" or key == "grid" or key == "home" then
        local cell = math.floor((size - 3) / 2)
        for row = 0, 1 do
            for column = 0, 1 do
                local square = frame({
                    Parent = holder,
                    Position = UDim2.fromOffset(column * (cell + 3), row * (cell + 3)),
                    Size = UDim2.fromOffset(cell, cell),
                    BackgroundColor3 = color,
                })
                corner(square, 2)
            end
        end
    elseif key == "settings" or key == "sliders" then
        for index = 0, 2 do
            local y = index * math.max(4, size * 0.28)
            frame({
                Parent = holder,
                Position = UDim2.fromOffset(0, y),
                Size = UDim2.fromOffset(size, 1),
                BackgroundColor3 = color,
            })
            local knobPosition = size * 0.2
            if index == 1 then
                knobPosition = size * 0.55
            elseif index == 2 then
                knobPosition = size * 0.35
            end
            local knob = frame({
                Parent = holder,
                Position = UDim2.fromOffset(knobPosition, y - 2),
                Size = UDim2.fromOffset(4, 4),
                BackgroundColor3 = color,
            })
            corner(knob, 2)
        end
    elseif key == "info" or key == "about" then
        local circle = frame({
            Parent = holder,
            Size = UDim2.fromOffset(size, size),
            BackgroundColor3 = color,
        })
        corner(circle, size / 2)
        label({
            Parent = circle,
            Size = UDim2.fromScale(1, 1),
            Text = "i",
            Font = FONT_BOLD,
            TextSize = math.max(9, math.floor(size * 0.62)),
            TextColor3 = COLORS.black,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    else
        local fallback = tostring(kind or "?"):sub(1, 1):upper()
        label({
            Parent = holder,
            Size = UDim2.fromScale(1, 1),
            Text = fallback,
            Font = FONT_BOLD,
            TextSize = math.max(10, math.floor(size * 0.8)),
            TextColor3 = color,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end

    return {
        Holder = holder,
        SetColor = function(_, nextColor)
            tintIcon(holder, nextColor)
        end,
    }
end

--=====================================================================
-- PAGE / SECTION OBJECTS
--=====================================================================

local PageMethods = {}
local SectionMethods = {}
local WindowMethods = {}

local function newPage(window, key, config)
    local page = {
        Window = window,
        Key = key,
        Config = config,
        _order = 0,
    }
    return setmetatable(page, { __index = PageMethods })
end

local function newSection(page, config)
    local section = {
        Page = page,
        Window = page.Window,
        Config = config,
        _order = 0,
    }
    return setmetatable(section, { __index = SectionMethods })
end

local function addRowButton(section, height)
    section._order += 1
    local row = button({
        Parent = section.Body,
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = COLORS.panel,
        BackgroundTransparency = 1,
        Text = "",
        LayoutOrder = section._order,
    })
    corner(row, 10)
    return row
end

local function addRowFrame(section, height)
    section._order += 1
    return frame({
        Parent = section.Body,
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        LayoutOrder = section._order,
    })
end

local function addTitleBlock(parent, titleText, description, topOffset, height)
    local hasDescription = description ~= nil and description ~= ""
    local title = label({
        Parent = parent,
        Position = UDim2.fromOffset(12, topOffset or 0),
        Size = UDim2.new(1, -70, 0, hasDescription and 19 or height),
        Text = titleText,
        Font = FONT_MED,
        TextSize = 15,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local subtitle = nil
    if hasDescription then
        subtitle = label({
            Parent = parent,
            Position = UDim2.fromOffset(12, (topOffset or 0) + 20),
            Size = UDim2.new(1, -70, 0, 16),
            Text = description,
            TextSize = 12,
            TextColor3 = COLORS.muted,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
    end
    return title, subtitle
end

--=====================================================================
-- PAGE API
--=====================================================================

function PageMethods:Section(config)
    config = config or {}
    local section = newSection(self, config)

    local heightEstimate = 36
    if config.Title and config.Description then
        heightEstimate = 48
    end

    local card = frame({
        Parent = self.Content,
        Size = UDim2.new(1, 0, 0, heightEstimate),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = COLORS.card,
        BorderSizePixel = 0,
    })
    corner(card, 12)
    stroke(card, COLORS.stroke, 0.92, 1)
    pad(card, 16, 14, 16, 14)
    layout(card, 8)

    local hasHeader = (config.Title ~= nil and config.Title ~= "") or (config.Description ~= nil and config.Description ~= "")
    if hasHeader then
        local header = frame({
            Parent = card,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        })
        layout(header, 2)
        if config.Title ~= nil and config.Title ~= "" then
            label({
                Parent = header,
                Size = UDim2.new(1, 0, 0, 18),
                Text = tostring(config.Title),
                Font = FONT_BOLD,
                TextSize = 14,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
        end
        if config.Description ~= nil and config.Description ~= "" then
            label({
                Parent = header,
                Size = UDim2.new(1, 0, 0, 16),
                Text = tostring(config.Description),
                TextSize = 12,
                TextColor3 = COLORS.muted,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
        end
    end

    local body = frame({
        Parent = card,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    layout(body, 8)

    section.Card = card
    section.Body = body
    table.insert(self._sections, section)
    return section
end

function PageMethods:_getDefaultSection()
    if not self._defaultSection then
        self._defaultSection = self:Section({})
    end
    return self._defaultSection
end

function PageMethods:Label(config)
    return self:_getDefaultSection():Label(config)
end

function PageMethods:Paragraph(config)
    return self:_getDefaultSection():Paragraph(config)
end

function PageMethods:Button(config)
    return self:_getDefaultSection():Button(config)
end

function PageMethods:Toggle(config)
    return self:_getDefaultSection():Toggle(config)
end

function PageMethods:Input(config)
    return self:_getDefaultSection():Input(config)
end

function PageMethods:Slider(config)
    return self:_getDefaultSection():Slider(config)
end

function PageMethods:Dropdown(config)
    return self:_getDefaultSection():Dropdown(config)
end

function PageMethods:Keybind(config)
    return self:_getDefaultSection():Keybind(config)
end

function PageMethods:Divider()
    return self:_getDefaultSection():Divider()
end

--=====================================================================
-- SECTION: LABEL / PARAGRAPH / DIVIDER
--=====================================================================

function SectionMethods:Label(config)
    if type(config) == "string" then
        config = { Text = config }
    end
    config = config or {}

    local holder = addRowFrame(self, 30)
    label({
        Parent = holder,
        Size = UDim2.new(1, config.Value and -120 or 0, 0, 30),
        Text = tostring(config.Text or "Label"),
        TextSize = 14,
        TextColor3 = COLORS.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local valueLabel = nil
    if config.Value ~= nil then
        valueLabel = label({
            Parent = holder,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(110, 30),
            Text = tostring(config.Value),
            TextSize = 13,
            TextColor3 = COLORS.muted,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
    end

    local api = { Instance = holder }
    function api:SetText(value)
        holder:FindFirstChildOfClass("TextLabel").Text = tostring(value)
    end
    function api:SetValue(value)
        if valueLabel then
            valueLabel.Text = tostring(value)
        end
    end
    function api:Destroy()
        holder:Destroy()
    end
    return api
end

function SectionMethods:Paragraph(config)
    if type(config) == "string" then
        config = { Text = config }
    end
    config = config or {}
    local content = tostring(config.Text or "")
    local width = self.Window._contentWidth
    local textSize = 13
    local height = math.max(22, measureText(content, textSize, width) + 4)
    local holder = addRowFrame(self, height)
    label({
        Parent = holder,
        Size = UDim2.fromScale(1, 1),
        Text = content,
        TextSize = textSize,
        TextColor3 = config.Color or COLORS.muted,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    return {
        Instance = holder,
        SetText = function(_, value)
            holder:FindFirstChildOfClass("TextLabel").Text = tostring(value)
        end,
        Destroy = function()
            holder:Destroy()
        end,
    }
end

function SectionMethods:Divider()
    local holder = addRowFrame(self, 9)
    frame({
        Parent = holder,
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = COLORS.stroke,
        BackgroundTransparency = 0.9,
    })
    return {
        Instance = holder,
        Destroy = function()
            holder:Destroy()
        end,
    }
end

--=====================================================================
-- SECTION: BUTTON
--=====================================================================

function SectionMethods:Button(config)
    if type(config) == "string" then
        config = { Text = config }
    end
    config = config or {}
    local hasDescription = config.Description ~= nil and config.Description ~= ""
    local height = hasDescription and 58 or 46
    local row = addRowButton(self, height)
    local title, subtitle = addTitleBlock(row, tostring(config.Text or "Button"), config.Description, hasDescription and 9 or 0, height)
    local arrow = label({
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        Text = "›",
        Font = FONT_BOLD,
        TextSize = 17,
        TextColor3 = COLORS.dim,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local enabled = config.Enabled ~= false
    local function refresh()
        title.TextColor3 = enabled and COLORS.text or COLORS.dim
        if subtitle then
            subtitle.TextColor3 = enabled and COLORS.muted or COLORS.dim
        end
        arrow.TextColor3 = enabled and COLORS.dim or COLORS.dim
        row.Active = enabled
    end
    refresh()

    row.MouseEnter:Connect(function()
        if not enabled then
            return
        end
        tween(row, 0.12, { BackgroundTransparency = 0.55 })
        tween(arrow, 0.12, {
            Position = UDim2.new(1, -12, 0.5, 0),
            TextColor3 = COLORS.text,
        })
    end)
    row.MouseLeave:Connect(function()
        tween(row, 0.12, { BackgroundTransparency = 1 })
        tween(arrow, 0.12, {
            Position = UDim2.new(1, -14, 0.5, 0),
            TextColor3 = enabled and COLORS.dim or COLORS.dim,
        })
    end)
    row.MouseButton1Click:Connect(function()
        if enabled and config.Callback then
            config.Callback()
        end
    end)

    local api = { Instance = row }
    function api:SetText(value)
        title.Text = tostring(value)
    end
    function api:SetDescription(value)
        if subtitle then
            subtitle.Text = tostring(value)
        end
    end
    function api:SetEnabled(value)
        enabled = value ~= false
        refresh()
    end
    function api:Destroy()
        row:Destroy()
    end
    return api
end

--=====================================================================
-- SECTION: TOGGLE
--=====================================================================

function SectionMethods:Toggle(config)
    if type(config) == "string" then
        config = { Text = config }
    end
    config = config or {}
    local hasDescription = config.Description ~= nil and config.Description ~= ""
    local height = hasDescription and 58 or 46
    local row = addRowButton(self, height)
    local title, subtitle = addTitleBlock(row, tostring(config.Text or "Toggle"), config.Description, hasDescription and 9 or 0, height)

    local track = frame({
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(42, 22),
        BackgroundColor3 = COLORS.panel,
    })
    corner(track, 11)
    stroke(track, COLORS.stroke, 0.9, 1)
    local knob = frame({
        Parent = track,
        Position = UDim2.fromOffset(3, 3),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = COLORS.muted,
    })
    corner(knob, 8)

    local value = config.Default == true
    if config.Flag and self.Window.Flags[config.Flag] ~= nil then
        value = self.Window.Flags[config.Flag] == true
    end
    if config.Flag then
        self.Window.Flags[config.Flag] = value
    end
    local listeners = {}

    local function render(animate)
        local targetColor = value and self.Window.Accent or COLORS.panel
        local targetKnobColor = value and COLORS.black or COLORS.muted
        local targetPosition = value and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
        if animate then
            tween(track, 0.16, { BackgroundColor3 = targetColor })
            tween(knob, 0.16, { Position = targetPosition, BackgroundColor3 = targetKnobColor })
        else
            track.BackgroundColor3 = targetColor
            knob.Position = targetPosition
            knob.BackgroundColor3 = targetKnobColor
        end
    end
    render(false)

    local function commit(nextValue, fireCallback)
        value = nextValue == true
        if config.Flag then
            self.Window.Flags[config.Flag] = value
        end
        render(true)
        if not fireCallback then
            return
        end
        if config.Callback then
            config.Callback(value)
        end
        for _, listener in ipairs(listeners) do
            listener(value)
        end
    end

    row.MouseEnter:Connect(function()
        tween(row, 0.12, { BackgroundTransparency = 0.55 })
    end)
    row.MouseLeave:Connect(function()
        tween(row, 0.12, { BackgroundTransparency = 1 })
    end)
    row.MouseButton1Click:Connect(function()
        commit(not value, true)
    end)

    local api = { Instance = row }
    function api:Set(nextValue, fireCallback)
        commit(nextValue == true, fireCallback == true)
    end
    function api:Get()
        return value
    end
    function api:OnChanged(callback)
        table.insert(listeners, callback)
    end
    function api:Destroy()
        row:Destroy()
    end
    return api
end

--=====================================================================
-- SECTION: INPUT
--=====================================================================

function SectionMethods:Input(config)
    if type(config) == "string" then
        config = { Text = config }
    end
    config = config or {}
    local hasDescription = config.Description ~= nil and config.Description ~= ""
    local height = hasDescription and 66 or 54
    local row = addRowFrame(self, height)
    local windowObject = self.Window
    local title, subtitle = addTitleBlock(row, tostring(config.Text or "Input"), config.Description, hasDescription and 8 or 0, height)

    local boxWidth = math.min(230, math.floor(self.Window._contentWidth * 0.42))
    local box = create("TextBox", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(boxWidth, 32),
        BackgroundColor3 = COLORS.input,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = config.Placeholder or "Enter text...",
        PlaceholderColor3 = COLORS.dim,
        TextColor3 = COLORS.text,
        TextSize = 13,
        Font = FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ClearTextOnFocus = false,
    })
    corner(box, 8)
    local boxStroke = stroke(box, COLORS.stroke, 0.9, 1)
    pad(box, 10, 0, 10, 0)

    if config.Flag and self.Window.Flags[config.Flag] ~= nil then
        box.Text = tostring(self.Window.Flags[config.Flag])
    elseif config.Default ~= nil then
        box.Text = tostring(config.Default)
    end
    if config.Flag then
        self.Window.Flags[config.Flag] = box.Text
    end
    local listeners = {}

    local function commit(enterPressed, fireCallback)
        if config.Flag then
            self.Window.Flags[config.Flag] = box.Text
        end
        if not fireCallback then
            return
        end
        if config.Callback then
            config.Callback(box.Text, enterPressed == true)
        end
        for _, listener in ipairs(listeners) do
            listener(box.Text, enterPressed == true)
        end
    end

    box.Focused:Connect(function()
        tween(boxStroke, 0.14, { Transparency = 0.4, Color = self.Window.Accent })
    end)
    box.FocusLost:Connect(function(enterPressed)
        tween(boxStroke, 0.14, { Transparency = 0.9, Color = COLORS.stroke })
        commit(enterPressed, true)
    end)

    local api = { Instance = row, Box = box }
    function api:Set(value, fireCallback)
        box.Text = tostring(value)
        commit(false, fireCallback == true)
    end
    function api:Get()
        return box.Text
    end
    function api:OnChanged(callback)
        table.insert(listeners, callback)
    end
    function api:Destroy()
        row:Destroy()
    end
    return api
end

--=====================================================================
-- SECTION: SLIDER
--=====================================================================

function SectionMethods:Slider(config)
    if type(config) == "string" then
        config = { Text = config }
    end
    config = config or {}
    local minimum = tonumber(config.Min) or 0
    local maximum = tonumber(config.Max) or 100
    if maximum <= minimum then
        maximum = minimum + 1
    end
    local step = tonumber(config.Step) or 1
    if step <= 0 then
        step = 1
    end

    local row = addRowFrame(self, 62)
    label({
        Parent = row,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -100, 0, 20),
        Text = tostring(config.Text or "Slider"),
        TextSize = 14,
        TextColor3 = COLORS.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local valueLabel = label({
        Parent = row,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(90, 20),
        Text = "",
        TextSize = 13,
        TextColor3 = COLORS.muted,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local track = frame({
        Parent = row,
        Position = UDim2.fromOffset(0, 38),
        Size = UDim2.new(1, -2, 0, 6),
        BackgroundColor3 = COLORS.panel,
    })
    corner(track, 3)
    local fill = frame({
        Parent = track,
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = self.Window.Accent,
    })
    corner(fill, 3)
    local knob = frame({
        Parent = track,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = self.Window.Accent,
    })
    corner(knob, 6)
    stroke(knob, COLORS.stroke, 0.75, 1)

    local hitArea = button({
        Parent = row,
        Position = UDim2.fromOffset(0, 26),
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "",
    })

    local value = tonumber(config.Default) or minimum
    value = clamp(value, minimum, maximum)
    local dragging = false
    local connections = {}
    local listeners = {}

    local function displayValue(nextValue)
        if config.Format then
            return tostring(config.Format(nextValue))
        end
        return formatNumber(nextValue)
    end

    local function snap(raw)
        local steps = math.floor((raw - minimum) / step + 0.5)
        return clamp(minimum + steps * step, minimum, maximum)
    end

    local function render(fireCallback)
        local percent = 0
        if maximum > minimum then
            percent = clamp((value - minimum) / (maximum - minimum), 0, 1)
        end
        fill.Size = UDim2.new(percent, 0, 1, 0)
        knob.Position = UDim2.new(percent, 0, 0.5, 0)
        valueLabel.Text = displayValue(value)
        if config.Flag then
            self.Window.Flags[config.Flag] = value
        end
        if fireCallback and config.Callback then
            config.Callback(value)
        end
        if fireCallback then
            for _, listener in ipairs(listeners) do
                listener(value)
            end
        end
    end

    local function setFromX(x)
        local origin = track.AbsolutePosition.X
        local width = math.max(1, track.AbsoluteSize.X)
        local percent = clamp((x - origin) / width, 0, 1)
        local raw = minimum + percent * (maximum - minimum)
        value = snap(raw)
        render(true)
    end

    if config.Flag and self.Window.Flags[config.Flag] ~= nil then
        value = clamp(tonumber(self.Window.Flags[config.Flag]) or value, minimum, maximum)
    end
    render(false)

    hitArea.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        dragging = true
        setFromX(input.Position.X)
    end)
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        setFromX(input.Position.X)
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = false
        end
    end))
    for _, connection in ipairs(connections) do
        table.insert(self.Window._connections, connection)
    end

    local api = { Instance = row }
    function api:Set(nextValue, fireCallback)
        value = snap(tonumber(nextValue) or minimum)
        render(fireCallback == true)
    end
    function api:Get()
        return value
    end
    function api:OnChanged(callback)
        table.insert(listeners, callback)
    end
    function api:Destroy()
        disconnectAll(connections)
        row:Destroy()
    end
    return api
end

--=====================================================================
-- SECTION: DROPDOWN
--=====================================================================

function SectionMethods:Dropdown(config)
    if type(config) == "string" then
        config = { Text = config }
    end
    config = config or {}
    local options = config.Options or {}
    local normalized = {}
    for _, option in ipairs(options) do
        if type(option) == "table" then
            table.insert(normalized, {
                Text = tostring(option.Text or option.Value or ""),
                Value = option.Value ~= nil and option.Value or option.Text,
            })
        else
            table.insert(normalized, { Text = tostring(option), Value = option })
        end
    end
    if #normalized == 0 then
        table.insert(normalized, { Text = "No options", Value = nil })
    end

    local row = addRowFrame(self, 54)
    label({
        Parent = row,
        Size = UDim2.new(1, -250, 0, 54),
        Text = tostring(config.Text or "Dropdown"),
        TextSize = 14,
        TextColor3 = COLORS.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local selected = button({
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(math.min(230, math.floor(self.Window._contentWidth * 0.42)), 32),
        BackgroundColor3 = COLORS.input,
        Text = "",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 13,
    })
    corner(selected, 8)
    stroke(selected, COLORS.stroke, 0.9, 1)
    pad(selected, 10, 0, 26, 0)
    local selectedLabel = label({
        Parent = selected,
        Size = UDim2.new(1, -8, 1, 0),
        Text = "",
        TextSize = 13,
        TextColor3 = COLORS.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local chevron = label({
        Parent = selected,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        Text = "v",
        TextSize = 11,
        TextColor3 = COLORS.muted,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local currentValue = config.Default
    if config.Flag and self.Window.Flags[config.Flag] ~= nil then
        currentValue = self.Window.Flags[config.Flag]
    end
    if currentValue == nil then
        currentValue = normalized[1].Value
    end
    local valueExists = false
    for _, option in ipairs(normalized) do
        if option.Value == currentValue then
            valueExists = true
            break
        end
    end
    if not valueExists then
        currentValue = normalized[1].Value
    end

    local listeners = {}

    local menu = nil
    local function closeMenu()
        if not menu then
            return
        end
        local closing = menu
        menu = nil
        if self.Window._menu == closing then
            self.Window._menu = nil
        end
        if closing.Overlay then
            closing.Overlay:Destroy()
        end
        if closing.Popup then
            closing.Popup:Destroy()
        end
    end

    local function render()
        local display = ""
        for _, option in ipairs(normalized) do
            if option.Value == currentValue then
                display = option.Text
                break
            end
        end
        selectedLabel.Text = display
        if config.Flag then
            self.Window.Flags[config.Flag] = currentValue
        end
    end
    render()

    local function commit(nextValue, fireCallback)
        currentValue = nextValue
        render()
        if not fireCallback then
            return
        end
        if config.Callback then
            config.Callback(currentValue)
        end
        for _, listener in ipairs(listeners) do
            listener(currentValue)
        end
    end

    local function openMenu()
        if menu then
            closeMenu()
            return
        end
        if self.Window._menu then
            self.Window:_closeMenus()
        end
        local windowObject = self.Window
        local windowFrame = windowObject.Window
        local currentScale = windowObject._scale or 1

        local overlay = button({
            Parent = windowFrame,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 80,
        })
        local popup = frame({
            Parent = windowFrame,
            BackgroundColor3 = COLORS.card,
            ZIndex = 81,
        })
        corner(popup, 10)
        stroke(popup, COLORS.stroke, 0.9, 1)

        local anchorX = (selected.AbsolutePosition.X - windowFrame.AbsolutePosition.X) / currentScale
        local anchorY = (selected.AbsolutePosition.Y - windowFrame.AbsolutePosition.Y) / currentScale
        local anchorWidth = selected.AbsoluteSize.X / currentScale
        local anchorHeight = selected.AbsoluteSize.Y / currentScale
        local popupWidth = math.max(180, anchorWidth)
        local optionHeight = 32
        local popupHeight = math.min(#normalized * (optionHeight + 2) + 8, 220)
        local popupX = clamp(anchorX, 10, math.max(10, windowObject._design.X - popupWidth - 10))
        local popupY = anchorY + anchorHeight + 6
        if popupY + popupHeight > windowObject._design.Y - 10 then
            popupY = math.max(10, anchorY - popupHeight - 6)
        end
        popup.Position = UDim2.fromOffset(popupX, popupY)
        popup.Size = UDim2.fromOffset(popupWidth, popupHeight)

        local scroller = create("ScrollingFrame", {
            Parent = popup,
            Position = UDim2.fromOffset(4, 4),
            Size = UDim2.new(1, -8, 1, -8),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.fromOffset(0, #normalized * (optionHeight + 2)),
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = COLORS.dim,
            ScrollBarImageTransparency = 0.35,
        })
        layout(scroller, 2)

        local function optionRow(option)
            local optionButton = button({
                Parent = scroller,
                Size = UDim2.new(1, -2, 0, optionHeight),
                BackgroundTransparency = 1,
                Text = "",
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            corner(optionButton, 7)
            local optionLabel = label({
                Parent = optionButton,
                Position = UDim2.fromOffset(9, 0),
                Size = UDim2.new(1, -30, 1, 0),
                Text = option.Text,
                TextSize = 13,
                TextColor3 = option.Value == currentValue and COLORS.text or COLORS.muted,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            if option.Value == currentValue then
                local dot = frame({
                    Parent = optionButton,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.fromOffset(6, 6),
                    BackgroundColor3 = windowObject.Accent,
                })
                corner(dot, 3)
            end
            optionButton.MouseEnter:Connect(function()
                tween(optionButton, 0.1, { BackgroundTransparency = 0.6 })
                optionLabel.TextColor3 = COLORS.text
            end)
            optionButton.MouseLeave:Connect(function()
                tween(optionButton, 0.1, { BackgroundTransparency = 1 })
                optionLabel.TextColor3 = option.Value == currentValue and COLORS.text or COLORS.muted
            end)
            optionButton.MouseButton1Click:Connect(function()
                closeMenu()
                commit(option.Value, true)
            end)
        end

        for _, option in ipairs(normalized) do
            optionRow(option)
        end

        overlay.MouseButton1Click:Connect(function()
            closeMenu()
        end)
        menu = { Overlay = overlay, Popup = popup, Close = closeMenu }
        windowObject._menu = menu
    end

    selected.MouseEnter:Connect(function()
        tween(selected, 0.12, { BackgroundColor3 = COLORS.card })
    end)
    selected.MouseLeave:Connect(function()
        tween(selected, 0.12, { BackgroundColor3 = COLORS.input })
    end)
    selected.MouseButton1Click:Connect(openMenu)

    local api = { Instance = row }
    function api:Set(nextValue, fireCallback)
        commit(nextValue, fireCallback == true)
    end
    function api:Get()
        return currentValue
    end
    function api:OnChanged(callback)
        table.insert(listeners, callback)
    end
    function api:Destroy()
        closeMenu()
        row:Destroy()
    end
    return api
end

--=====================================================================
-- SECTION: KEYBIND
--=====================================================================

function SectionMethods:Keybind(config)
    if type(config) == "string" then
        config = { Text = config }
    end
    config = config or {}
    local row = addRowFrame(self, 50)
    label({
        Parent = row,
        Size = UDim2.new(1, -180, 1, 0),
        Text = tostring(config.Text or "Keybind"),
        TextSize = 14,
        TextColor3 = COLORS.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local keyButton = button({
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(140, 30),
        BackgroundColor3 = COLORS.input,
        Text = "",
        TextSize = 12,
    })
    corner(keyButton, 8)
    local keyStroke = stroke(keyButton, COLORS.stroke, 0.9, 1)

    local value = config.Default
    if config.Flag and self.Window.Flags[config.Flag] ~= nil then
        value = self.Window.Flags[config.Flag]
    end
    local listening = false
    local connections = {}
    local listeners = {}

    local function render()
        keyButton.Text = listening and "Press a key..." or keyName(value)
        if config.Flag then
            self.Window.Flags[config.Flag] = value
        end
    end
    render()

    local function stopListening()
        if not listening then
            return
        end
        listening = false
        self.Window._capturing = false
        keyButton.Text = keyName(value)
        tween(keyStroke, 0.14, { Transparency = 0.9, Color = COLORS.stroke })
        if self.Window._captureCancel == stopListening then
            self.Window._captureCancel = nil
        end
    end

    local function startListening()
        if listening then
            stopListening()
            return
        end
        if self.Window._captureCancel then
            self.Window._captureCancel()
        end
        listening = true
        self.Window._capturing = true
        self.Window._captureCancel = stopListening
        keyButton.Text = "Press a key..."
        tween(keyStroke, 0.14, { Transparency = 0.4, Color = self.Window.Accent })
    end

    table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not listening or gameProcessed then
            return
        end
        local key = input.KeyCode
        if key == nil then
            return
        end
        if key == Enum.KeyCode.Escape then
            stopListening()
            return
        end
        if key == Enum.KeyCode.Unknown then
            return
        end
        value = key
        listening = false
        self.Window._capturing = false
        self.Window._captureCancel = nil
        keyButton.Text = keyName(value)
        tween(keyStroke, 0.14, { Transparency = 0.9, Color = COLORS.stroke })
        if config.Flag then
            self.Window.Flags[config.Flag] = value
        end
        if config.Callback then
            config.Callback(value)
        end
        for _, listener in ipairs(listeners) do
            listener(value)
        end
    end))
    for _, connection in ipairs(connections) do
        table.insert(self.Window._connections, connection)
    end

    keyButton.MouseEnter:Connect(function()
        tween(keyButton, 0.12, { BackgroundColor3 = COLORS.card })
    end)
    keyButton.MouseLeave:Connect(function()
        tween(keyButton, 0.12, { BackgroundColor3 = COLORS.input })
    end)
    keyButton.MouseButton1Click:Connect(startListening)

    local api = { Instance = row, Button = keyButton }
    function api:Set(nextKey, fireCallback)
        value = nextKey
        render()
        if fireCallback then
            if config.Callback then
                config.Callback(value)
            end
            for _, listener in ipairs(listeners) do
                listener(value)
            end
        end
    end
    function api:Get()
        return value
    end
    function api:OnChanged(callback)
        table.insert(listeners, callback)
    end
    function api:Destroy()
        stopListening()
        disconnectAll(connections)
        row:Destroy()
    end
    return api
end

--=====================================================================
-- WINDOW: CREATE
--=====================================================================

local function computeScale(windowObject)
    local viewport = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
    local fit = math.min(
        (viewport.X - 48) / windowObject._design.X,
        (viewport.Y - 48) / windowObject._design.Y
    )
    return clamp(fit, 0.28, 1.3) * windowObject._scaleSetting
end

function Library:CreateWindow(config)
    config = config or {}

    if getgenv then
        local ok, environment = pcall(getgenv)
        if ok and type(environment) == "table" and environment.__LibraryUI then
            pcall(function()
                environment.__LibraryUI:Destroy()
            end)
            environment.__LibraryUI = nil
        end
    end

    local previousWindows = self._windows
    self._windows = {}
    for _, oldWindow in ipairs(previousWindows) do
        if oldWindow and not oldWindow._destroyed then
            oldWindow:Destroy()
        end
    end
    self.LastWindow = nil

    WINDOW_COUNT += 1
    local selfWindow = setmetatable({}, { __index = WindowMethods })
    selfWindow.Config = config
    selfWindow.Theme = COLORS
    selfWindow.Accent = config.Accent or COLORS.accent
    selfWindow.Flags = {}
    selfWindow._pages = {}
    selfWindow._pageOrder = {}
    selfWindow._navs = {}
    selfWindow._sections = {}
    selfWindow._connections = {}
    selfWindow._toasts = {}
    selfWindow._toastOrder = 0
    selfWindow._destroyed = false
    selfWindow._open = config.StartOpen ~= false
    selfWindow._capturing = false
    selfWindow._captureCancel = nil
    selfWindow._menu = nil
    selfWindow._dragging = false
    selfWindow._dragStart = nil
    selfWindow._dragOrigin = nil
    selfWindow._design = config.Size or Vector2.new(1000, 650)
    selfWindow._scaleSetting = tonumber(config.Scale) or 0.85
    selfWindow._toggleKey = config.ToggleKey == nil and Enum.KeyCode.RightShift or config.ToggleKey
    selfWindow.CloseOnEscape = config.CloseOnEscape == true
    selfWindow._contentWidth = selfWindow._design.X - SIDEBAR_WIDTH - 84
    selfWindow._scale = computeScale(selfWindow)

    local dark = config.DimTransparency ~= nil and tonumber(config.DimTransparency) or 0.45

    local guiParent = getGuiParent()
    local guiName = config.Name or "LibraryUI"
    local existing = guiParent:FindFirstChild(guiName)
    if existing then
        existing:Destroy()
    end

    local gui = create("ScreenGui", {
        Name = guiName,
        Parent = guiParent,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999,
    })
    selfWindow.Gui = gui

    local dim = frame({
        Parent = gui,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = selfWindow._open and dark or 1,
        Visible = selfWindow._open,
        ZIndex = 0,
    })
    selfWindow.Dim = dim

    local windowFrame = frame({
        Parent = gui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(selfWindow._design.X, selfWindow._design.Y),
        BackgroundColor3 = COLORS.window,
        ClipsDescendants = true,
        Visible = selfWindow._open,
        ZIndex = 2,
    })
    corner(windowFrame, 18)
    stroke(windowFrame, COLORS.stroke, 0.9, 1)
    gradient(windowFrame, Color3.fromRGB(13, 14, 19), Color3.fromRGB(8, 9, 12), 90)
    selfWindow.Window = windowFrame

    local windowScale = create("UIScale", {
        Parent = windowFrame,
        Scale = selfWindow._scale,
    })
    selfWindow.WindowScale = windowScale

    local sidebar = frame({
        Parent = windowFrame,
        Size = UDim2.fromOffset(SIDEBAR_WIDTH, selfWindow._design.Y),
        BackgroundColor3 = COLORS.sidebar,
        ClipsDescendants = true,
        ZIndex = 3,
    })
    corner(sidebar, 18)
    frame({
        Parent = sidebar,
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.fromOffset(SIDEBAR_WIDTH - 18, selfWindow._design.Y),
        BackgroundColor3 = COLORS.sidebar,
        ZIndex = 1,
    })
    frame({
        Parent = sidebar,
        Position = UDim2.new(1, -1, 0, 18),
        Size = UDim2.new(0, 1, 1, -36),
        BackgroundColor3 = COLORS.stroke,
        BackgroundTransparency = 0.94,
    })

    local logo = frame({
        Parent = sidebar,
        Position = UDim2.fromOffset(22, 20),
        Size = UDim2.fromOffset(36, 36),
        BackgroundColor3 = COLORS.white,
        ZIndex = 2,
    })
    corner(logo, 11)
    gradient(logo, Color3.fromRGB(255, 255, 255), Color3.fromRGB(203, 206, 214), 90)
    label({
        Parent = logo,
        Size = UDim2.fromScale(1, 1),
        Text = "L",
        Font = FONT_BOLD,
        TextSize = 20,
        TextColor3 = COLORS.black,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 3,
    })
    label({
        Parent = sidebar,
        Position = UDim2.fromOffset(68, 16),
        Size = UDim2.new(1, -86, 0, 21),
        Text = tostring(config.Title or "Library"),
        Font = FONT_BOLD,
        TextSize = 16,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })
    label({
        Parent = sidebar,
        Position = UDim2.fromOffset(68, 37),
        Size = UDim2.new(1, -86, 0, 13),
        Text = string.upper(tostring(config.Subtitle or "ROBLOX UI LIBRARY")),
        Font = FONT_MED,
        TextSize = 8,
        TextColor3 = COLORS.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })
    frame({
        Parent = sidebar,
        Position = UDim2.fromOffset(22, 74),
        Size = UDim2.fromOffset(SIDEBAR_WIDTH - 44, 1),
        BackgroundColor3 = COLORS.stroke,
        BackgroundTransparency = 0.94,
        ZIndex = 2,
    })

    local footerY = selfWindow._design.Y - 86
    frame({
        Parent = sidebar,
        Position = UDim2.fromOffset(22, footerY),
        Size = UDim2.fromOffset(SIDEBAR_WIDTH - 44, 1),
        BackgroundColor3 = COLORS.stroke,
        BackgroundTransparency = 0.94,
        ZIndex = 2,
    })
    local statusDot = frame({
        Parent = sidebar,
        Position = UDim2.fromOffset(22, footerY + 22),
        Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = selfWindow.Accent,
        ZIndex = 2,
    })
    corner(statusDot, 3)
    label({
        Parent = sidebar,
        Position = UDim2.fromOffset(36, footerY + 16),
        Size = UDim2.new(1, -58, 0, 16),
        Text = "STATUS",
        Font = FONT_MED,
        TextSize = 9,
        TextColor3 = COLORS.dim,
        ZIndex = 2,
    })
    selfWindow._statusLabel = label({
        Parent = sidebar,
        Position = UDim2.fromOffset(22, footerY + 34),
        Size = UDim2.new(1, -44, 0, 16),
        Text = tostring(config.Status or "Ready"),
        TextSize = 11,
        TextColor3 = COLORS.muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })
    label({
        Parent = sidebar,
        Position = UDim2.fromOffset(22, footerY + 54),
        Size = UDim2.new(1, -44, 0, 14),
        Text = tostring(config.Footer or ("Library v" .. Library.Version)),
        TextSize = 9,
        TextColor3 = COLORS.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    })

    local header = frame({
        Parent = windowFrame,
        Position = UDim2.fromOffset(SIDEBAR_WIDTH, 0),
        Size = UDim2.new(1, -SIDEBAR_WIDTH, 0, 72),
        BackgroundTransparency = 1,
        ZIndex = 4,
    })
    selfWindow._pageTitle = label({
        Parent = header,
        Position = UDim2.fromOffset(26, 14),
        Size = UDim2.new(1, -96, 0, 25),
        Text = tostring(config.Title or "Library"),
        Font = FONT_BOLD,
        TextSize = 20,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    selfWindow._pageSubtitle = label({
        Parent = header,
        Position = UDim2.fromOffset(26, 42),
        Size = UDim2.new(1, -96, 0, 15),
        Text = "SELECT A PAGE",
        Font = FONT_MED,
        TextSize = 10,
        TextColor3 = COLORS.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    frame({
        Parent = header,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = COLORS.stroke,
        BackgroundTransparency = 0.94,
    })

    local closeButton = button({
        Parent = header,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -20, 0, 21),
        Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1,
        Text = "×",
        Font = FONT_MED,
        TextSize = 20,
        TextColor3 = COLORS.muted,
        ZIndex = 5,
    })
    corner(closeButton, 8)
    closeButton.MouseEnter:Connect(function()
        tween(closeButton, 0.12, { BackgroundTransparency = 0.86, TextColor3 = COLORS.text })
    end)
    closeButton.MouseLeave:Connect(function()
        tween(closeButton, 0.12, { BackgroundTransparency = 1, TextColor3 = COLORS.muted })
    end)
    closeButton.MouseButton1Click:Connect(function()
        selfWindow:Close()
    end)

    local content = frame({
        Parent = windowFrame,
        Position = UDim2.fromOffset(SIDEBAR_WIDTH, 72),
        Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -72),
        BackgroundTransparency = 1,
        ZIndex = 4,
    })
    selfWindow._content = content
    selfWindow._navParent = sidebar

    local launcher = nil
    if config.ShowLauncher ~= false then
        launcher = button({
            Parent = gui,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -22, 1, -22),
            Size = UDim2.fromOffset(52, 52),
            BackgroundColor3 = COLORS.white,
            Text = tostring(config.LauncherText or "L"),
            Font = FONT_BOLD,
            TextSize = 21,
            TextColor3 = COLORS.black,
            Visible = not selfWindow._open,
            ZIndex = 100,
        })
        corner(launcher, 15)
        stroke(launcher, COLORS.stroke, 0.55, 1)
        gradient(launcher, Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 222, 228), 90)
        local launcherScale = create("UIScale", { Parent = launcher, Scale = 1 })
        launcher.MouseEnter:Connect(function()
            tween(launcherScale, 0.14, { Scale = 1.07 })
        end)
        launcher.MouseLeave:Connect(function()
            tween(launcherScale, 0.14, { Scale = 1 })
        end)
        launcher.MouseButton1Click:Connect(function()
            selfWindow:Open()
        end)
    end
    selfWindow.Launcher = launcher

    local toastLayer = frame({
        Parent = gui,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -22, 0, 22),
        Size = UDim2.fromOffset(310, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 200,
    })
    layout(toastLayer, 8)
    local toastScale = create("UIScale", { Parent = toastLayer, Scale = 1 })
    selfWindow._toastLayer = toastLayer
    selfWindow._toastScale = toastScale
    local viewport = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
    toastScale.Scale = clamp(viewport.Y / 1080, 0.8, 1.5)

    -- open animation
    if selfWindow._open then
        windowScale.Scale = selfWindow._scale * 0.96
        tween(windowScale, 0.24, { Scale = selfWindow._scale })
        dim.BackgroundTransparency = 1
        tween(dim, 0.22, { BackgroundTransparency = dark })
    end

    --=================================================================
    -- DRAGGING (empty space only)
    --=================================================================

    local function isOnVisibleBranch(object)
        local node = object
        while node and node ~= gui do
            if node:IsA("GuiObject") and node.Visible == false then
                return false
            end
            node = node.Parent
        end
        return true
    end

    local function pointerOverControl(position)
        for _, object in ipairs(windowFrame:GetDescendants()) do
            if (object:IsA("GuiButton") or object:IsA("TextBox") or object:IsA("ScrollingFrame"))
                and isOnVisibleBranch(object)
            then
                local origin = object.AbsolutePosition
                local size = object.AbsoluteSize
                if position.X >= origin.X
                    and position.X <= origin.X + size.X
                    and position.Y >= origin.Y
                    and position.Y <= origin.Y + size.Y
                then
                    return true
                end
            end
        end
        return false
    end

    local function pointerInsideWindow(position)
        local origin = windowFrame.AbsolutePosition
        local size = windowFrame.AbsoluteSize
        return position.X >= origin.X
            and position.X <= origin.X + size.X
            and position.Y >= origin.Y
            and position.Y <= origin.Y + size.Y
    end

    function selfWindow:_stopDrag()
        self._dragging = false
        self._dragStart = nil
        self._dragOrigin = nil
    end

    table.insert(selfWindow._connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or selfWindow._destroyed or not selfWindow._open then
            return
        end
        if not windowFrame.Visible or selfWindow._capturing or selfWindow._menu then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        if not pointerInsideWindow(input.Position) then
            return
        end
        if pointerOverControl(input.Position) then
            return
        end
        selfWindow._dragging = true
        selfWindow._dragStart = input.Position
        selfWindow._dragOrigin = windowFrame.Position
    end))

    table.insert(selfWindow._connections, UserInputService.InputChanged:Connect(function(input)
        if not selfWindow._dragging or not selfWindow._dragStart or not selfWindow._dragOrigin then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        local delta = input.Position - selfWindow._dragStart
        local viewportNow = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
        local halfWidth = selfWindow._design.X * selfWindow._scale / 2
        local halfHeight = selfWindow._design.Y * selfWindow._scale / 2
        local limitX = math.max(0, viewportNow.X / 2 + halfWidth - 130)
        local limitY = math.max(0, viewportNow.Y / 2 + halfHeight - 100)
        local nextX = clamp(selfWindow._dragOrigin.X.Offset + delta.X, -limitX, limitX)
        local nextY = clamp(selfWindow._dragOrigin.Y.Offset + delta.Y, -limitY, limitY)
        windowFrame.Position = UDim2.new(0.5, nextX, 0.5, nextY)
    end))

    table.insert(selfWindow._connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            selfWindow:_stopDrag()
        end
    end))

    --=================================================================
    -- KEY TOGGLE / VIEWPORT
    --=================================================================

    table.insert(selfWindow._connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or selfWindow._destroyed or selfWindow._capturing then
            return
        end
        if selfWindow._toggleKey and input.KeyCode == selfWindow._toggleKey then
            selfWindow:Toggle()
            return
        end
        if input.KeyCode == Enum.KeyCode.Escape then
            if selfWindow._menu then
                selfWindow:_closeMenus()
            end
            if selfWindow.CloseOnEscape then
                selfWindow:Close()
            end
        end
    end))

    if camera then
        table.insert(selfWindow._connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if selfWindow._destroyed then
                return
            end
            selfWindow._scale = computeScale(selfWindow)
            if selfWindow._open then
                windowScale.Scale = selfWindow._scale
            end
            local viewportNow = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
            toastScale.Scale = clamp(viewportNow.Y / 1080, 0.8, 1.5)
            selfWindow:_closeMenus()
        end))
    end

    table.insert(self._windows, selfWindow)
    self.LastWindow = selfWindow
    if getgenv then
        local ok, environment = pcall(getgenv)
        if ok and type(environment) == "table" then
            environment.__LibraryUI = selfWindow
        end
    end
    return selfWindow
end

--=====================================================================
-- WINDOW: PAGES
--=====================================================================

function WindowMethods:Page(key, config)
    key = tostring(key or "page")
    config = config or {}
    if self._pages[key] then
        return self._pages[key]
    end

    local page = newPage(self, key, config)
    page._sections = {}

    local scroller = create("ScrollingFrame", {
        Parent = self._content,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = COLORS.dim,
        ScrollBarImageTransparency = 0.35,
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 4,
    })
    local inner = frame({
        Parent = scroller,
        Position = UDim2.fromOffset(26, 18),
        Size = UDim2.new(1, -52, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 4,
    })
    layout(inner, 14)
    pad(inner, 0, 0, 0, 18)
    page.Frame = scroller
    page.Content = inner

    self._pages[key] = page
    table.insert(self._pageOrder, page)

    local itemIndex = #self._pageOrder
    local navButton = button({
        Parent = self._navParent,
        Position = UDim2.fromOffset(14, 94 + (itemIndex - 1) * 48),
        Size = UDim2.new(1, -28, 0, 42),
        BackgroundColor3 = COLORS.panel,
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 2,
    })
    corner(navButton, 10)
    local activeBar = frame({
        Parent = navButton,
        Position = UDim2.fromOffset(0, 12),
        Size = UDim2.fromOffset(2, 18),
        BackgroundColor3 = self.Accent,
        Visible = false,
        ZIndex = 3,
    })
    corner(activeBar, 2)
    local icon = makeIcon(navButton, config.Icon or "grid", 16, COLORS.dim)
    icon.Holder.Position = UDim2.fromOffset(14, 13)
    icon.Holder.ZIndex = 3
    local navLabel = label({
        Parent = navButton,
        Position = UDim2.fromOffset(40, 0),
        Size = UDim2.new(1, -50, 1, 0),
        Text = tostring(config.Title or key),
        Font = FONT_MED,
        TextSize = 15,
        TextColor3 = COLORS.muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    })

    local navData = {
        Button = navButton,
        Bar = activeBar,
        Icon = icon,
        Label = navLabel,
        Active = false,
    }
    self._navs[key] = navData

    navButton.MouseEnter:Connect(function()
        if not navData.Active then
            tween(navButton, 0.14, { BackgroundTransparency = 0.6 })
            navLabel.TextColor3 = COLORS.text
        end
    end)
    navButton.MouseLeave:Connect(function()
        if not navData.Active then
            tween(navButton, 0.14, { BackgroundTransparency = 1 })
            navLabel.TextColor3 = COLORS.muted
        end
    end)
    navButton.MouseButton1Click:Connect(function()
        self:SelectPage(key)
    end)

    if not self._currentPage then
        self:SelectPage(key)
    end
    return page
end

function WindowMethods:SelectPage(key)
    local page = self._pages[tostring(key)]
    if not page then
        return nil
    end
    self._currentPage = page
    for otherKey, otherPage in pairs(self._pages) do
        otherPage.Frame.Visible = otherKey == tostring(key)
    end
    for navKey, navData in pairs(self._navs) do
        local active = navKey == tostring(key)
        navData.Active = active
        navData.Bar.Visible = active
        navData.Label.TextColor3 = active and COLORS.text or COLORS.muted
        navData.Icon:SetColor(active and self.Accent or COLORS.dim)
        navData.Button.BackgroundTransparency = active and 0.55 or 1
    end
    self._pageTitle.Text = tostring(page.Config.Title or key)
    self._pageSubtitle.Text = tostring(page.Config.Description or ("PAGE / " .. string.upper(tostring(key))))
    page.Frame.CanvasPosition = Vector2.new(0, 0)
    if self._menu then
        self:_closeMenus()
    end
    return page
end

function WindowMethods:GetPage(key)
    return self._pages[tostring(key)]
end

--=====================================================================
-- WINDOW: NOTIFICATIONS
--=====================================================================

function WindowMethods:Notify(title, content, kind, duration)
    local windowObject = self
    if type(title) == "table" then
        local config = title
        title = config.Title or config.title
        content = config.Text or config.Content or config.text
        kind = config.Type or config.type or kind
        duration = config.Duration or config.duration or duration
    end
    title = tostring(title or "Notification")
    kind = tostring(kind or "info"):lower()
    duration = tonumber(duration) or 4

    local color = self.Accent
    if kind == "success" then
        color = COLORS.green
    elseif kind == "warn" or kind == "warning" then
        color = COLORS.amber
    elseif kind == "error" then
        color = COLORS.red
    end

    self._toastOrder += 1
    local card = create("CanvasGroup", {
        Parent = self._toastLayer,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = COLORS.card,
        BackgroundTransparency = 0.02,
        GroupTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = self._toastOrder,
    })
    corner(card, 10)
    stroke(card, COLORS.stroke, 0.9, 1)
    pad(card, 14, 12, 14, 12)
    layout(card, 4)

    local header = frame({
        Parent = card,
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
    })
    frame({
        Parent = header,
        Position = UDim2.fromOffset(0, 6),
        Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = color,
    })
    label({
        Parent = header,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -30, 0, 18),
        Text = title,
        Font = FONT_MED,
        TextSize = 14,
        TextColor3 = COLORS.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local closeToast = button({
        Parent = header,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 2, 0, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1,
        Text = "×",
        TextSize = 14,
        TextColor3 = COLORS.dim,
    })
    closeToast.MouseEnter:Connect(function()
        closeToast.TextColor3 = COLORS.text
    end)
    closeToast.MouseLeave:Connect(function()
        closeToast.TextColor3 = COLORS.dim
    end)

    local bodyHeight = 0
    if content ~= nil and tostring(content) ~= "" then
        local bodyText = tostring(content)
        bodyHeight = math.max(16, measureText(bodyText, 12, 268) + 2)
        label({
            Parent = card,
            Size = UDim2.new(1, 0, 0, bodyHeight),
            Text = bodyText,
            TextSize = 12,
            TextColor3 = COLORS.muted,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
    end

    local toast = { Instance = card, _dismissed = false }
    function toast:Dismiss()
        if self._dismissed then
            return
        end
        self._dismissed = true
        tween(card, 0.16, { GroupTransparency = 1 })
        task.delay(0.2, function()
            if card and card.Parent then
                card:Destroy()
            end
            for index, item in ipairs(windowObject._toasts) do
                if item == toast then
                    table.remove(windowObject._toasts, index)
                    break
                end
            end
        end)
    end
    closeToast.MouseButton1Click:Connect(function()
        toast:Dismiss()
    end)

    table.insert(self._toasts, toast)
    tween(card, 0.2, { GroupTransparency = 0 })

    while #self._toasts > (tonumber(self.Config.MaxNotifications) or 5) do
        local oldest = table.remove(self._toasts, 1)
        if oldest and not oldest._dismissed then
            oldest:Dismiss()
        end
    end

    if duration > 0 then
        task.delay(duration, function()
            if not toast._dismissed then
                toast:Dismiss()
            end
        end)
    end
    return toast
end

function WindowMethods:ClearNotifications()
    local current = {}
    for _, toast in ipairs(self._toasts) do
        table.insert(current, toast)
    end
    for _, toast in ipairs(current) do
        toast:Dismiss()
    end
end

function Library:Notify(...)
    if self.LastWindow then
        return self.LastWindow:Notify(...)
    end
    return nil
end

--=====================================================================
-- WINDOW: STATE / OPEN / CLOSE / DESTROY
--=====================================================================

function WindowMethods:SetStatus(content)
    if self._statusLabel then
        self._statusLabel.Text = tostring(content or "")
    end
end

function WindowMethods:SetScale(scale)
    scale = tonumber(scale)
    if not scale or scale <= 0 then
        return
    end
    self._scaleSetting = scale
    self._scale = computeScale(self)
    if self._open then
        self.WindowScale.Scale = self._scale
    end
    self:_closeMenus()
end

function WindowMethods:_closeMenus()
    if self._menu then
        local menu = self._menu
        self._menu = nil
        if menu.Close then
            menu.Close()
        end
    end
end

function WindowMethods:_cancelCapture()
    if self._captureCancel then
        local cancel = self._captureCancel
        self._captureCancel = nil
        cancel()
    end
    self._capturing = false
end

function WindowMethods:Open()
    if self._destroyed or self._open then
        return
    end
    self._open = true
    if self.Launcher then
        self.Launcher.Visible = false
    end
    self.Window.Visible = true
    self.WindowScale.Scale = self._scale * 0.96
    tween(self.WindowScale, 0.24, { Scale = self._scale })
    self.Dim.Visible = true
    self.Dim.BackgroundTransparency = 1
    local dark = self.Config.DimTransparency ~= nil and tonumber(self.Config.DimTransparency) or 0.45
    tween(self.Dim, 0.22, { BackgroundTransparency = dark })
end

function WindowMethods:Close()
    if self._destroyed or not self._open then
        return
    end
    self._open = false
    self:_stopDrag()
    self:_closeMenus()
    self:_cancelCapture()
    tween(self.WindowScale, 0.18, { Scale = self._scale * 0.96 })
    tween(self.Dim, 0.18, { BackgroundTransparency = 1 })
    task.delay(0.18, function()
        if self._open or self._destroyed then
            return
        end
        self.Window.Visible = false
        self.Dim.Visible = false
        if self.Launcher then
            self.Launcher.Visible = true
        end
    end)
end

function WindowMethods:Toggle()
    if self._open then
        self:Close()
    else
        self:Open()
    end
end

function WindowMethods:IsOpen()
    return self._open == true
end

function WindowMethods:GetFlag(flag)
    return self.Flags[flag]
end

function WindowMethods:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    self:_stopDrag()
    self:_closeMenus()
    self:_cancelCapture()
    disconnectAll(self._connections)
    self._connections = {}
    if self.Gui then
        self.Gui:Destroy()
    end
    for index, windowItem in ipairs(Library._windows) do
        if windowItem == self then
            table.remove(Library._windows, index)
            break
        end
    end
    if Library.LastWindow == self then
        Library.LastWindow = nil
    end
    if getgenv then
        local ok, environment = pcall(getgenv)
        if ok and type(environment) == "table" and environment.__LibraryUI == self then
            environment.__LibraryUI = nil
        end
    end
end

--=====================================================================
-- PUBLIC HELPERS
--=====================================================================

function Library:SetTheme(patch)
    if type(patch) ~= "table" then
        return
    end
    for key, value in pairs(patch) do
        if COLORS[key] ~= nil then
            COLORS[key] = value
        end
    end
end

function Library:GetWindow()
    return self.LastWindow
end

return Library
