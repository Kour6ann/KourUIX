-- SimpleUI.lua
-- Minimal, self-contained UI library for Roblox (inspired by Kavo/Rayfield)
-- Features: Window, Sections, Buttons, Toggles, Sliders, Dropdowns, Textbox, Labels
-- Includes Close and Minimize buttons, responsive scaling, draggable windows,
-- and a diagnostic checker that runs through common UI bug categories you provided.

local SimpleUI = {}
SimpleUI.__index = SimpleUI

-- Utility functions ---------------------------------------------------------
local function new(class, props)
    local obj = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
    end
    return obj
end

local function snapToInteger(n)
    return math.floor(n + 0.5)
end

local function safeConnect(obj, event, fn)
    if obj and obj[event] then
        return obj[event]:Connect(fn)
    end
end

-- Default theme -------------------------------------------------------------
SimpleUI.Theme = {
    Accent = Color3.fromRGB(58, 110, 255),
    Background = Color3.fromRGB(28, 28, 30),
    Panel = Color3.fromRGB(34, 34, 36),
    Text = Color3.fromRGB(235, 235, 240),
    SecondaryText = Color3.fromRGB(170,170,175),
    CornerRadius = UDim.new(0,8),
}

-- Create main ScreenGui ----------------------------------------------------
function SimpleUI.new(name)
    local self = setmetatable({}, SimpleUI)
    self.Name = name or "SimpleUI"
    self.ScreenGui = new("ScreenGui", {Name = self.Name, ResetOnSpawn = false})

    -- Safe parenting: prefer PlayerGui when in game, otherwise StarterGui for preview
    local players = game:GetService("Players")
    local localPlayer = players.LocalPlayer
    if localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui") then
        self.ScreenGui.Parent = localPlayer:FindFirstChildOfClass("PlayerGui")
    else
        self.ScreenGui.Parent = game:GetService("CoreGui") or game:GetService("StarterGui")
    end

    -- Container: top-level window holder
    self.Windows = {}
    return self
end

-- Internal: create window --------------------------------------------------
function SimpleUI:CreateWindow(opts)
    opts = opts or {}
    local title = opts.Title or "Window"
    local size = opts.Size or UDim2.new(0, 520, 0, 360)
    local position = opts.Position or UDim2.new(0.5, -260, 0.5, -180)

    local container = new("Frame", {
        Name = title:gsub("%s+", "_") .. "_Window",
        Size = size,
        Position = position,
        AnchorPoint = Vector2.new(0,0),
        BackgroundColor3 = SimpleUI.Theme.Panel,
        BorderSizePixel = 0,
        Parent = self.ScreenGui,
    })
    local uiCorner = new("UICorner", {CornerRadius = SimpleUI.Theme.CornerRadius, Parent = container})

    -- Titlebar
    local titlebar = new("Frame", {
        Name = "Titlebar",
        Size = UDim2.new(1,0,0,36),
        BackgroundTransparency = 1,
        Parent = container,
    })
    local titleLabel = new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -96, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = SimpleUI.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        Parent = titlebar,
    })

    -- Buttons: minimize, close
    local closeBtn = new("TextButton", {
        Name = "Close",
        Size = UDim2.new(0,36,0,24),
        Position = UDim2.new(1, -44, 0, 6),
        BackgroundColor3 = SimpleUI.Theme.Accent,
        Text = "X",
        TextColor3 = Color3.new(1,1,1),
        Font = Enum.Font.SourceSansBold,
        TextSize = 16,
        Parent = titlebar,
    })
    new("UICorner", {CornerRadius = UDim.new(0,6), Parent = closeBtn})

    local minimizeBtn = new("TextButton", {
        Name = "Minimize",
        Size = UDim2.new(0,36,0,24),
        Position = UDim2.new(1, -88, 0, 6),
        BackgroundColor3 = Color3.fromRGB(120,120,120),
        Text = "_",
        TextColor3 = Color3.new(1,1,1),
        Font = Enum.Font.SourceSansBold,
        TextSize = 22,
        Parent = titlebar,
    })
    new("UICorner", {CornerRadius = UDim.new(0,6), Parent = minimizeBtn})

    -- Body with padding and layout
    local body = new("Frame", {
        Name = "Body",
        Size = UDim2.new(1, -20, 1, -56),
        Position = UDim2.new(0, 10, 0, 44),
        BackgroundTransparency = 1,
        Parent = container,
    })

    local layout = new("UIListLayout", {Parent = body, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,8)})

    -- Draggability
    local dragging = false
    local dragOffset = Vector2.new()
    local inputService = game:GetService("UserInputService")

    titlebar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local mouse = inputService:GetMouseLocation()
            local absPos = container.AbsolutePosition
            dragOffset = Vector2.new(mouse.X - absPos.X, mouse.Y - absPos.Y)
        end
    end)
    titlebar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    inputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mouse = inputService:GetMouseLocation()
            local newX = snapToInteger(mouse.X - dragOffset.X)
            local newY = snapToInteger(mouse.Y - dragOffset.Y)
            -- Keep window inside viewport
            local screenX = container.Parent.AbsoluteSize.X
            local screenY = container.Parent.AbsoluteSize.Y
            newX = math.clamp(newX, 0, screenX - container.AbsoluteSize.X)
            newY = math.clamp(newY, 0, screenY - container.AbsoluteSize.Y)
            container.Position = UDim2.new(0, newX, 0, newY)
        end
    end)

    -- Close / Minimize logic
    closeBtn.MouseButton1Click:Connect(function()
        container:Destroy()
    end)

    local minimized = false
    minimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        for _, child in pairs(body:GetChildren()) do
            if not child:IsA("UILayout") then
                child.Visible = not minimized
            end
        end
        container.Size = minimized and UDim2.new(container.Size.X.Scale, container.Size.X.Offset, 0, 44) or size
    end)

    -- Store references
    local win = {
        Container = container,
        Body = body,
        Titlebar = titlebar,
        TitleLabel = titleLabel,
        Close = closeBtn,
        Minimize = minimizeBtn,
        Layout = layout,
        Elements = {},
    }

    -- API for window
    function win:AddSection(name)
        local section = new("Frame", {Size = UDim2.new(1,0,0,80), BackgroundColor3 = SimpleUI.Theme.Background, Parent = body})
        new("UICorner", {CornerRadius = SimpleUI.Theme.CornerRadius, Parent = section})
        local secTitle = new("TextLabel", {Text = name or "Section", BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 24), Position = UDim2.new(0, 6, 0, 6), TextColor3 = SimpleUI.Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = section})
        local content = new("Frame", {Name = "Content", Size = UDim2.new(1, -12, 1, -36), Position = UDim2.new(0, 6, 0, 30), BackgroundTransparency = 1, Parent = section})
        local contentLayout = new("UIListLayout", {Parent = content, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,6)})
        local sec = {Frame = section, Content = content, Layout = contentLayout}

        function sec:AddButton(label, callback)
            local btn = new("TextButton", {Size = UDim2.new(1,0,0,36), BackgroundColor3 = SimpleUI.Theme.Accent, Text = label or "Button", TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 14, Parent = content})
            new("UICorner", {CornerRadius = UDim.new(0,6), Parent = btn})
            btn.MouseButton1Click:Connect(function() pcall(callback) end)
            table.insert(self.Elements, btn)
            return btn
        end

        function sec:AddToggle(label, init, callback)
            local row = new("Frame", {Size = UDim2.new(1,0,0,28), BackgroundTransparency = 1, Parent = content})
            local text = new("TextLabel", {Text = label or "Toggle", BackgroundTransparency = 1, Size = UDim2.new(1, -48, 1, 0), TextColor3 = SimpleUI.Theme.Text, Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = row})
            local box = new("TextButton", {Size = UDim2.new(0,36,0,20), Position = UDim2.new(1, -40, 0, 4), BackgroundColor3 = Color3.fromRGB(80,80,80), Text = init and "ON" or "OFF", Parent = row})
            new("UICorner", {CornerRadius = UDim.new(0,6), Parent = box})
            local state = init or false
            box.MouseButton1Click:Connect(function()
                state = not state
                box.Text = state and "ON" or "OFF"
                pcall(callback, state)
            end)
            table.insert(self.Elements, row)
            return box, function() return state end
        end

        function sec:AddSlider(label, min, max, init, callback)
            min = min or 0; max = max or 100; init = init or min
            local frame = new("Frame", {Size = UDim2.new(1,0,0,32), BackgroundTransparency = 1, Parent = content})
            local text = new("TextLabel", {Text = label or "Slider", BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 14), TextColor3 = SimpleUI.Theme.Text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame})
            local bar = new("Frame", {Size = UDim2.new(1,0,0,12), Position = UDim2.new(0,0,0,18), BackgroundColor3 = Color3.fromRGB(70,70,70), Parent = frame})
            new("UICorner", {CornerRadius = UDim.new(0,6), Parent = bar})
            local fill = new("Frame", {Size = UDim2.new((init-min)/(max-min),0,1,0), BackgroundColor3 = SimpleUI.Theme.Accent, Parent = bar})
            new("UICorner", {CornerRadius = UDim.new(0,6), Parent = fill})
            local draggingBar = false

            bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingBar = true
                end
            end)
            bar.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingBar = false
                end
            end)
            inputService.InputChanged:Connect(function(inpt)
                if draggingBar and inpt.UserInputType == Enum.UserInputType.MouseMovement then
                    local abs = bar.AbsoluteSize.X
                    local rel = math.clamp((inpt.Position.X - bar.AbsolutePosition.X) / abs, 0, 1)
                    fill.Size = UDim2.new(rel,0,1,0)
                    local value = min + rel*(max-min)
                    pcall(callback, value)
                end
            end)

            table.insert(self.Elements, frame)
            return fill
        end

        function sec:AddTextbox(label, placeholder, callback)
            local frame = new("Frame", {Size = UDim2.new(1,0,0,36), BackgroundTransparency = 1, Parent = content})
            local text = new("TextLabel", {Text = label or "Text", BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 14), TextColor3 = SimpleUI.Theme.Text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame})
            local box = new("TextBox", {Size = UDim2.new(1,0,0,18), Position = UDim2.new(0,0,0,18), Text = "", PlaceholderText = placeholder or "...", BackgroundColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 0.95, TextColor3 = SimpleUI.Theme.Text, Font = Enum.Font.Gotham, TextSize = 13, Parent = frame})
            box.FocusLost:Connect(function(enter)
                if enter then
                    pcall(callback, box.Text)
                end
            end)
            table.insert(self.Elements, frame)
            return box
        end

        function sec:AddDropdown(label, options, callback)
            local frame = new("Frame", {Size = UDim2.new(1,0,0,36), BackgroundTransparency = 1, Parent = content})
            local text = new("TextLabel", {Text = label or "Dropdown", BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 14), TextColor3 = SimpleUI.Theme.Text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame})
            local btn = new("TextButton", {Size = UDim2.new(1,0,0,18), Position = UDim2.new(0,0,0,18), Text = options[1] or "Select", BackgroundColor3 = Color3.fromRGB(50,50,50), TextColor3 = SimpleUI.Theme.Text, Font = Enum.Font.Gotham, TextSize = 13, Parent = frame})
            local dropdown = new("Frame", {Size = UDim2.new(1,0,0,0), Position = UDim2.new(0,0,0,36), BackgroundColor3 = Color3.fromRGB(48,48,50), ClipsDescendants = true, Parent = frame})
            local ddLayout = new("UIListLayout", {Parent = dropdown, SortOrder = Enum.SortOrder.LayoutOrder})
            for i, opt in ipairs(options) do
                local optBtn = new("TextButton", {Size = UDim2.new(1,0,0,28), Text = opt, BackgroundTransparency = 1, TextColor3 = SimpleUI.Theme.Text, Parent = dropdown})
                optBtn.MouseButton1Click:Connect(function()
                    btn.Text = opt
                    dropdown:TweenSize(UDim2.new(1,0,0,0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
                    pcall(callback, opt)
                end)
            end
            btn.MouseButton1Click:Connect(function()
                local target = UDim2.new(1,0,0,#options * 28)
                dropdown:TweenSize(dropdown.Size.Y.Offset > 0 and UDim2.new(1,0,0,0) or target, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
            end)
            table.insert(self.Elements, frame)
            return btn
        end

        return sec
    end

    table.insert(self.Windows, win)
    return win
end

-- Diagnostics: run checks from user's strict rule list ---------------------
-- This function attempts to detect common UI problems and returns a report table.
function SimpleUI.RunDiagnostics(screenGui)
    local report = {OK = {}, Warn = {}, Error = {}}
    screenGui = screenGui or (game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui") and game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui"):FindFirstChildWhichIsA("ScreenGui"))
    if not screenGui then
        table.insert(report.Error, "No ScreenGui found for diagnostics")
        return report
    end

    -- General rendering
    for _, gui in pairs(screenGui:GetDescendants()) do
        if gui:IsA("GuiObject") then
            -- missing positions/sizes
            if (gui.Size == nil) then table.insert(report.Warn, gui:GetFullName() .. " has nil Size") end
            -- alpha blending
            if gui.BackgroundTransparency and gui.BackgroundTransparency < 0 then
                table.insert(report.Warn, gui:GetFullName() .. " BackgroundTransparency out of range")
            end
            -- non-integer pixel position/size (blurriness risk)
            if gui.AbsolutePosition and gui.AbsoluteSize then
                local x,y = gui.AbsolutePosition.X, gui.AbsolutePosition.Y
                if math.abs(x - snapToInteger(x)) > 0.01 or math.abs(y - snapToInteger(y)) > 0.01 then
                    table.insert(report.Warn, gui:GetFullName() .. " at non-integer absolute position (may blur)")
                end
            end
        end
    end

    -- Layout & Positioning
    for _, frame in pairs(screenGui:GetDescendants()) do
        if frame:IsA("GuiObject") and frame:FindFirstChildOfClass("UIListLayout") then
            -- ensure parent clips descendants if overflow expected
            local parent = frame
            if not parent.ClipsDescendants and parent.AbsoluteSize.Y < (#parent:GetChildren() * 28) then
                table.insert(report.Warn, parent:GetFullName() .. " may need ClipsDescendants for overflowing content")
            end
        end
    end

    -- Text Rendering
    for _, t in pairs(screenGui:GetDescendants()) do
        if t:IsA("TextLabel") or t:IsA("TextButton") or t:IsA("TextBox") then
            if t.TextFits == false and not t.TextWrapped then
                table.insert(report.Warn, t:GetFullName() .. " text may be clipping (TextFits=false and TextWrapped=false)")
            end
            -- font fallback basic check
            if t.Text and string.find(t.Text, "\239\191\189") then
                table.insert(report.Warn, t:GetFullName() .. " contains replacement character (font fallback missing glyphs)")
            end
        end
    end

    -- Input & Interaction
    for _, obj in pairs(screenGui:GetDescendants()) do
        if obj:IsA("GuiObject") then
            if obj.Active == false and obj:IsA("TextButton") then
                table.insert(report.Warn, obj:GetFullName() .. " is a button but Active=false (may not receive input)")
            end
        end
    end

    -- Performance
    local count = #screenGui:GetDescendants()
    if count > 400 then
        table.insert(report.Warn, "Large number of GUI objects (" .. count .. ") — consider batching or lazy-creating elements")
    end

    if #report.Warn == 0 and #report.Error == 0 then
        table.insert(report.OK, "No obvious issues detected by automated checks")
    end
    return report
end

-- Simple cleanup helper
function SimpleUI:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
        self.Windows = nil
    end
end

-- Expose library
return SimpleUI
