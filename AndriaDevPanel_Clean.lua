local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local DEVELOPER_USER_IDS = {
    [123456789] = true,
}
if not DEVELOPER_USER_IDS[LP.UserId] then
    return
end

local oldGui = PG:FindFirstChild("AndriaDevPanel")
if oldGui then
    oldGui:Destroy()
end

local S = {
    AimAssistOverlay = true,
    FOV = true,
    Crosshair = true,

    ESP = false,
    TeamCheck = true,
    Tracers = true,
    Names = true,
    Distance = true,

    FullBright = false,
    LowGraphics = false,

    CombatSprint = false,
    SlideMechanics = false,
    DashMechanics = false,
    DodgeMechanics = false,
    QuickStep = false,
    DoubleJump = false,
    MultiJump = false,
    WallJump = false,
    WallRun = false,
    LedgeGrab = false,
    CombatRoll = false,
    Fly = false,
    HoverMode = false,
    NoClip = false,
    BunnyHop = false,
    AirStrafing = false,
    StrafeAssistance = false,
    MovementSmoothing = false,
    JumpTimingAssistance = false,
    LandingRecovery = false,
    KnockbackResistance = false,
    MovementPrediction = false,
    StrafingOptimization = false,
    AnimationCancelMechanics = false,
}

local WALK_SPEED = 16
local SPRINT_SPEED = 21
local JUMP_POWER = 50
local FLY_SPEED = 45
local FOV_RADIUS = 100
local AIM_SMOOTHNESS = 50
local CAMERA_FOV = 70

local character, humanoid, root
local flyVelocity, flyGyro
local shiftHeld = false
local airJumpsUsed = 0
local lastBunnyJump = 0
local lastHorizontalSpeed = 0
local burstIgnoreUntil = 0
local originalHipHeight = nil
local noclipOriginal = {}
local lowGraphicsOriginal = {}
local terrainDecorationOriginal = nil
local noclipDescendantConnection = nil
local lastViewportSize = nil
local espObjects = {}
local playerConnections = {}
local connections = {}
local characterConnections = {}
local oldLighting = nil
local currentPage = nil
local pages = {}
local refreshAllESP
local setFly
local setNoClip
local setFullBright
local setLowGraphics
local applyBurst, tryLedgeVault
local fovCircle, crosshair, predictionLabel, espCounter
local flyControls, flyUpHeld, flyDownHeld = nil, false, false

local gui = Instance.new("ScreenGui")
gui.Name = "AndriaDevPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PG

local scale, appRoot

local function make(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props or {}) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local function round(obj, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, obj)
end

local function outline(obj, color, thickness)
    make("UIStroke", {
        Color = color or Color3.fromRGB(45, 220, 125),
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, obj)
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

appRoot = make("Frame", {
    Name = "ScaledAppRoot",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = false,
}, gui)
scale = make("UIScale", { Name = "ResponsiveScale", Scale = 1 }, appRoot)

local function updateResponsiveScale()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local fitX = (viewport.X - 20) / 590
    local fitY = (viewport.Y - 24) / 430
    scale.Scale = math.clamp(math.min(1, fitX, fitY), 0.35, 1)
end

local main = make("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(590, 430),
    Position = UDim2.new(0.5, -295, 0.5, -215),
    BackgroundColor3 = Color3.fromRGB(18, 21, 27),
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, appRoot)
round(main, 12)
outline(main, Color3.fromRGB(45, 220, 125), 2)

local top = make("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 45),
    BackgroundColor3 = Color3.fromRGB(27, 33, 41),
    BorderSizePixel = 0,
}, main)
round(top, 10)

make("TextLabel", {
    Name = "Title",
    Size = UDim2.new(1, -150, 1, 0),
    Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1,
    Text = "ANDRIA  /  DEV PANEL",
    TextColor3 = Color3.fromRGB(235, 255, 243),
    Font = Enum.Font.GothamBold,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
}, top)

local minimize = make("TextButton", {
    Name = "Minimize",
    Size = UDim2.fromOffset(35, 30),
    Position = UDim2.new(1, -82, 0, 7),
    Text = "—",
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(54, 62, 73),
    BorderSizePixel = 0,
    AutoButtonColor = true,
}, top)
round(minimize, 7)

local close = make("TextButton", {
    Name = "Hide",
    Size = UDim2.fromOffset(35, 30),
    Position = UDim2.new(1, -41, 0, 7),
    Text = "X",
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(155, 54, 65),
    BorderSizePixel = 0,
    AutoButtonColor = true,
}, top)
round(close, 7)

local reopen = make("TextButton", {
    Name = "ReopenButton",
    Size = UDim2.fromOffset(52, 52),
    Position = UDim2.new(0, 18, 0.5, -26),
    Text = "DEV",
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(20, 28, 29),
    BorderSizePixel = 0,
    Visible = false,
    AutoButtonColor = true,
}, appRoot)
round(reopen, 26)
outline(reopen, Color3.fromRGB(45, 220, 125), 2)

flyControls = make("Frame", {
    Name = "TouchFlyControls",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -14, 1, -18),
    Size = UDim2.fromOffset(194, 54),
    BackgroundColor3 = Color3.fromRGB(18, 21, 27),
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 20,
}, appRoot)
round(flyControls, 9)
outline(flyControls, Color3.fromRGB(45, 220, 125), 1)

local flyUpButton = make("TextButton", {
    Name = "FlyRise",
    Position = UDim2.fromOffset(5, 5),
    Size = UDim2.fromOffset(90, 44),
    Text = "HOLD  UP",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(30, 115, 75),
    BorderSizePixel = 0,
    ZIndex = 21,
}, flyControls)
round(flyUpButton, 7)

local flyDownButton = make("TextButton", {
    Name = "FlyDescend",
    Position = UDim2.fromOffset(99, 5),
    Size = UDim2.fromOffset(90, 44),
    Text = "HOLD  DOWN",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(50, 60, 70),
    BorderSizePixel = 0,
    ZIndex = 21,
}, flyControls)
round(flyDownButton, 7)

local function bindFlyHold(button, setter)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            setter(true)
        end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            setter(false)
        end
    end)
end
bindFlyHold(flyUpButton, function(value) flyUpHeld = value end)
bindFlyHold(flyDownButton, function(value) flyDownHeld = value end)

local function hidePanel()
    main.Visible = false
    reopen.Visible = true
end

local function showPanel()
    main.Visible = true
    reopen.Visible = false
end

minimize.Activated:Connect(hidePanel)
close.Activated:Connect(hidePanel)
reopen.Activated:Connect(showPanel)

do
    local dragging = false
    local dragStart
    local startPosition
    local dragInput

    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
            dragInput = input
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    dragInput = nil
                end
            end)
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
            )
        end
    end)
end

local sidebar = make("ScrollingFrame", {
    Name = "Sidebar",
    Position = UDim2.fromOffset(10, 55),
    Size = UDim2.fromOffset(155, 365),
    BackgroundColor3 = Color3.fromRGB(24, 28, 35),
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, main)
round(sidebar, 8)
make("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, sidebar)
make("UIPadding", {
    PaddingTop = UDim.new(0, 7),
    PaddingLeft = UDim.new(0, 7),
    PaddingRight = UDim.new(0, 7),
    PaddingBottom = UDim.new(0, 7),
}, sidebar)

local content = make("ScrollingFrame", {
    Name = "Content",
    Position = UDim2.fromOffset(175, 55),
    Size = UDim2.fromOffset(405, 365),
    BackgroundColor3 = Color3.fromRGB(24, 28, 35),
    BorderSizePixel = 0,
    ScrollBarThickness = 5,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, main)
round(content, 8)
local pageLayout = make("UIListLayout", {
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, content)
local contentPadding = make("UIPadding", {
    PaddingTop = UDim.new(0, 10),
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10),
    PaddingBottom = UDim.new(0, 10),
}, content)

local function clearPage()
    for _, child in ipairs(content:GetChildren()) do
        if child ~= pageLayout and child ~= contentPadding then
            child:Destroy()
        end
    end
    content.CanvasPosition = Vector2.zero
end

local function showPage(name)
    local page = pages[name]
    if not page then return end
    currentPage = name
    clearPage()

    for _, child in ipairs(sidebar:GetChildren()) do
        if child:IsA("TextButton") then
            child.BackgroundColor3 = child.Name == "Page_" .. name
                and Color3.fromRGB(30, 112, 76)
                or Color3.fromRGB(37, 43, 52)
        end
    end

    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = string.upper(page.name),
        TextColor3 = Color3.fromRGB(70, 235, 145),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, content)

    for _, item in ipairs(page.items) do
        item()
    end
end

local function createPage(name)
    local page = { name = name, items = {} }
    pages[name] = page

    local button = make("TextButton", {
        Name = "Page_" .. name,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(37, 43, 52),
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = Color3.fromRGB(230, 235, 242),
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        AutoButtonColor = true,
    }, sidebar)
    round(button, 7)
    button.Activated:Connect(function()
        showPage(name)
    end)
    return page
end

local function addLabel(page, text, height)
    table.insert(page.items, function()
        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, height or 36),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Color3.fromRGB(178, 190, 203),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
        }, content)
    end)
end

local function addButton(page, label, callback)
    table.insert(page.items, function()
        local button = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 35),
            BackgroundColor3 = Color3.fromRGB(42, 48, 58),
            BorderSizePixel = 0,
            Text = label,
            TextColor3 = Color3.fromRGB(240, 245, 250),
            Font = Enum.Font.GothamSemibold,
            TextSize = 12,
            AutoButtonColor = true,
        }, content)
        round(button, 7)
        button.Activated:Connect(callback)
    end)
end

local function addToggle(page, key, label, callback)
    table.insert(page.items, function()
        local button
        local function refresh()
            local enabled = S[key] == true
            button.Text = label .. "   [" .. (enabled and "ON" or "OFF") .. "]"
            button.BackgroundColor3 = enabled
                and Color3.fromRGB(27, 111, 72)
                or Color3.fromRGB(42, 48, 58)
        end

        button = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 35),
            BackgroundColor3 = Color3.fromRGB(42, 48, 58),
            BorderSizePixel = 0,
            TextColor3 = Color3.fromRGB(240, 245, 250),
            Font = Enum.Font.GothamSemibold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = true,
        }, content)
        round(button, 7)

        button.Activated:Connect(function()
            S[key] = not S[key]
            refresh()
            if callback then callback(S[key]) end
        end)
        refresh()
    end)
end

local function addSlider(page, label, minVal, maxVal, initial, callback, step)
    step = step or 1
    table.insert(page.items, function()
        local value = math.clamp(initial, minVal, maxVal)
        local holder = make("Frame", {
            Size = UDim2.new(1, 0, 0, 74),
            BackgroundTransparency = 1,
        }, content)

        make("TextLabel", {
            Size = UDim2.new(1, -90, 0, 25),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = Color3.fromRGB(235, 240, 245),
            Font = Enum.Font.GothamSemibold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, holder)

        local number = make("TextBox", {
            Size = UDim2.fromOffset(70, 25),
            Position = UDim2.new(1, -70, 0, 0),
            BackgroundColor3 = Color3.fromRGB(35, 45, 53),
            TextColor3 = Color3.fromRGB(70, 235, 145),
            Text = tostring(value),
            ClearTextOnFocus = false,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            BorderSizePixel = 0,
            TextEditable = true,
            Active = true,
        }, holder)
        round(number, 5)

        local minus = make("TextButton", {
            Size = UDim2.fromOffset(32, 27),
            Position = UDim2.fromOffset(0, 36),
            Text = "−",
            TextSize = 18,
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.new(1, 1, 1),
            BackgroundColor3 = Color3.fromRGB(50, 60, 70),
            BorderSizePixel = 0,
        }, holder)
        round(minus, 5)

        local plus = make("TextButton", {
            Size = UDim2.fromOffset(32, 27),
            Position = UDim2.new(1, -32, 0, 36),
            Text = "+",
            TextSize = 18,
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.new(1, 1, 1),
            BackgroundColor3 = Color3.fromRGB(30, 115, 75),
            BorderSizePixel = 0,
        }, holder)
        round(plus, 5)

        local bar = make("Frame", {
            Position = UDim2.fromOffset(40, 45),
            Size = UDim2.new(1, -80, 0, 8),
            BackgroundColor3 = Color3.fromRGB(55, 63, 74),
            BorderSizePixel = 0,
        }, holder)
        round(bar, 4)

        local fill = make("Frame", {
            Size = UDim2.new((value - minVal) / (maxVal - minVal), 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(45, 220, 125),
            BorderSizePixel = 0,
        }, bar)
        round(fill, 4)

        local function setValue(rawValue)
            local numeric = tonumber(rawValue)
            if not numeric then
                number.Text = tostring(value)
                return
            end
            value = math.clamp(math.floor(numeric + 0.5), minVal, maxVal)
            number.Text = tostring(value)
            fill.Size = UDim2.new((value - minVal) / (maxVal - minVal), 0, 1, 0)
            callback(value)
        end

        minus.Activated:Connect(function()
            setValue(value - step)
        end)
        plus.Activated:Connect(function()
            setValue(value + step)
        end)
        number.FocusLost:Connect(function()
            setValue(number.Text)
        end)

        local dragging = false
        local dragConnections = {}

        local function updateFromX(x)
            local width = math.max(bar.AbsoluteSize.X, 1)
            local alpha = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
            setValue(minVal + alpha * (maxVal - minVal))
        end

        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateFromX(input.Position.X)
            end
        end)

        table.insert(dragConnections, UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromX(input.Position.X)
            end
        end))
        table.insert(dragConnections, UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))
        holder.Destroying:Connect(function()
            dragging = false
            for _, conn in ipairs(dragConnections) do
                conn:Disconnect()
            end
        end)
    end)
end

local function addResetButton(page)
    addButton(page, "RESET MOVEMENT VALUES", function()
        WALK_SPEED = 16
        SPRINT_SPEED = 21
        JUMP_POWER = 50
        FLY_SPEED = 45
        FOV_RADIUS = 100
        AIM_SMOOTHNESS = 50
        CAMERA_FOV = 70
        if humanoid then
            humanoid.WalkSpeed = WALK_SPEED
            humanoid.UseJumpPower = true
            humanoid.JumpPower = JUMP_POWER
        end
        if fovCircle then
            fovCircle.Size = UDim2.fromOffset(FOV_RADIUS * 2, FOV_RADIUS * 2)
        end
        if Workspace.CurrentCamera then
            Workspace.CurrentCamera.FieldOfView = CAMERA_FOV
        end
        LP:SetAttribute("AimAssistSmoothness", AIM_SMOOTHNESS)
        if currentPage then
            showPage(currentPage)
        end
    end)
end

fovCircle = make("Frame", {
    Name = "FOVCircle",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.42),
    Size = UDim2.fromOffset(FOV_RADIUS * 2, FOV_RADIUS * 2),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = true,
    ZIndex = 10,
}, gui)
round(fovCircle, 500)
outline(fovCircle, Color3.fromRGB(45, 220, 125), 2)

crosshair = make("Frame", {
    Name = "Crosshair",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(4, 4),
    BackgroundColor3 = Color3.fromRGB(45, 220, 125),
    BorderSizePixel = 0,
    Visible = true,
    ZIndex = 11,
}, gui)
round(crosshair, 4)

local tracerGui = make("Frame", {
    Name = "ESPTracers",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 5,
}, gui)

espCounter = make("TextLabel", {
    Name = "ESPCount",
    Position = UDim2.new(0.5, -100, 0, 8),
    Size = UDim2.fromOffset(200, 25),
    BackgroundTransparency = 1,
    Text = "Player ESP: OFF",
    TextColor3 = Color3.fromRGB(45, 220, 125),
    TextStrokeTransparency = 0,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    Visible = true,
    ZIndex = 12,
}, gui)

predictionLabel = make("TextLabel", {
    Name = "MovementPrediction",
    Position = UDim2.new(0, 10, 1, -38),
    Size = UDim2.fromOffset(280, 25),
    BackgroundColor3 = Color3.fromRGB(18, 21, 27),
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Text = "Movement prediction: OFF",
    TextColor3 = Color3.fromRGB(130, 255, 180),
    Font = Enum.Font.GothamSemibold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Visible = false,
    ZIndex = 12,
}, gui)
round(predictionLabel, 6)

local function isEnemy(player)
    if player == LP then return false end
    if S.TeamCheck and LP.Team and player.Team then
        return LP.Team ~= player.Team
    end
    return true
end

local function clearESP(player)
    local data = espObjects[player]
    if not data then return end
    for _, object in pairs(data) do
        if typeof(object) == "Instance" then
            object:Destroy()
        end
    end
    espObjects[player] = nil
end

local function buildESP(player)
    clearESP(player)
    if not S.ESP or not isEnemy(player) then return end
    local char = player.Character
    if not char or not char.Parent then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return end

    local highlight = make("Highlight", {
        Name = "PlayerHighlight",
        Adornee = char,
        FillColor = Color3.fromRGB(35, 220, 115),
        OutlineColor = Color3.fromRGB(35, 255, 145),
        FillTransparency = 0.78,
        OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.Occluded,
    }, gui)

    local billboard = make("BillboardGui", {
        Name = "PlayerLabel",
        Adornee = hrp,
        Size = UDim2.fromOffset(220, 28),
        StudsOffset = Vector3.new(0, 3, 0),
        AlwaysOnTop = false,
        Enabled = S.Names or S.Distance,
    }, gui)

    local label = make("TextLabel", {
        Name = "Label",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(100, 255, 155),
        TextStrokeTransparency = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Text = player.Name,
    }, billboard)

    local tracer = make("Frame", {
        Name = "Tracer",
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(45, 220, 125),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(2, 0),
        Visible = false,
        ZIndex = 5,
    }, tracerGui)

    espObjects[player] = {
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
        Tracer = tracer,
    }
end

refreshAllESP = function()
    for player in pairs(espObjects) do
        clearESP(player)
    end
    if S.ESP then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LP then
                buildESP(player)
            end
        end
    end
end

local function setupPlayer(player)
    if player == LP then return end
    if playerConnections[player] then
        for _, conn in ipairs(playerConnections[player]) do
            conn:Disconnect()
        end
    end
    playerConnections[player] = {}
    table.insert(playerConnections[player], player.CharacterAdded:Connect(function()
        task.wait(0.25)
        buildESP(player)
    end))
    table.insert(playerConnections[player], player:GetPropertyChangedSignal("Team"):Connect(function()
        buildESP(player)
    end))
    if player.Character then
        task.defer(buildESP, player)
    end
end

local aimPage = createPage("Aim Assist")
addLabel(aimPage, "Aim Assist settings and visual controls. This page does not lock onto players.", 42)
addToggle(aimPage, "AimAssistOverlay", "Aim Assist Overlay", function(on)
    if fovCircle then fovCircle.Visible = on and S.FOV end
    if crosshair then crosshair.Visible = on and S.Crosshair end
end)
addToggle(aimPage, "FOV", "FOV Circle", function(on)
    if fovCircle then fovCircle.Visible = S.AimAssistOverlay and on end
end)
addToggle(aimPage, "Crosshair", "Crosshair", function(on)
    if crosshair then crosshair.Visible = S.AimAssistOverlay and on end
end)
addSlider(aimPage, "Aim Assist Smoothness", 10, 100, AIM_SMOOTHNESS, function(value)
    AIM_SMOOTHNESS = value
    LP:SetAttribute("AimAssistSmoothness", value)
end)
addSlider(aimPage, "FOV Radius", 10, 500, FOV_RADIUS, function(value)
    FOV_RADIUS = value
    if fovCircle then
        fovCircle.Size = UDim2.fromOffset(value * 2, value * 2)
    end
end)
addSlider(aimPage, "Camera FOV", 50, 120, CAMERA_FOV, function(value)
    CAMERA_FOV = value
    local camera = Workspace.CurrentCamera
    if camera then camera.FieldOfView = value end
end)

local characterPage = createPage("Character")
addLabel(characterPage, "Character settings change your character in this experience.", 36)
addSlider(characterPage, "Walk Speed", 10, 500, WALK_SPEED, function(value)
    WALK_SPEED = value
    if humanoid and not S.MovementSmoothing then
        humanoid.WalkSpeed = (S.CombatSprint and shiftHeld) and SPRINT_SPEED or WALK_SPEED
    end
end)
addSlider(characterPage, "Sprint Speed", 10, 500, SPRINT_SPEED, function(value)
    SPRINT_SPEED = value
    if humanoid and not S.MovementSmoothing and S.CombatSprint and shiftHeld then
        humanoid.WalkSpeed = SPRINT_SPEED
    end
end)
addSlider(characterPage, "Jump Power", 10, 500, JUMP_POWER, function(value)
    JUMP_POWER = value
    if humanoid then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = value
    end
end)
addToggle(characterPage, "CombatSprint", "Sprint (Left Shift)")
addToggle(characterPage, "SlideMechanics", "Slide (C)")
addToggle(characterPage, "DashMechanics", "Dash (Q)")
addToggle(characterPage, "DodgeMechanics", "Dodge (E)")
addToggle(characterPage, "QuickStep", "Quick-Step (X)")
addToggle(characterPage, "CombatRoll", "Combat Roll (V)")
addToggle(characterPage, "DoubleJump", "Double Jump")
addToggle(characterPage, "MultiJump", "Multi-Jump (up to 5 air jumps)")
addToggle(characterPage, "WallJump", "Wall Jump")
addToggle(characterPage, "WallRun", "Wall Run (hold Space + A/D)")
addToggle(characterPage, "LedgeGrab", "Ledge Grab / Vault (G)")
addToggle(characterPage, "NoClip", "Noclip", function(on)
    if setNoClip then setNoClip(on) end
end)

local flyPage = createPage("Fly Settings")
addToggle(flyPage, "Fly", "Fly", function(on)
    if setFly then setFly(on) end
end)
addSlider(flyPage, "Fly Speed", 10, 500, FLY_SPEED, function(value)
    FLY_SPEED = value
end)
addToggle(flyPage, "HoverMode", "Hover Mode")
addLabel(flyPage, "Controls: WASD move, Space rise, Left Ctrl descend.", 36)
addLabel(flyPage, "Fly and Noclip are developer tools for this experience.", 32)

local bunnyPage = createPage("Bunny Hop")
addToggle(bunnyPage, "BunnyHop", "Bunny Hop (hold Space)")
addToggle(bunnyPage, "AirStrafing", "Air Strafing")
addToggle(bunnyPage, "StrafeAssistance", "Strafe Assistance")
addToggle(bunnyPage, "MovementSmoothing", "Movement Smoothing")
addToggle(bunnyPage, "JumpTimingAssistance", "Jump Timing Assistance")
addToggle(bunnyPage, "LandingRecovery", "Landing Recovery")
addToggle(bunnyPage, "StrafingOptimization", "Strafing Optimization")
addToggle(bunnyPage, "KnockbackResistance", "Knockback Resistance")
addToggle(bunnyPage, "MovementPrediction", "Movement Prediction Display", function(on)
    if predictionLabel then
        predictionLabel.Visible = on
        predictionLabel.Text = on and "Movement prediction: waiting..." or "Movement prediction: OFF"
    end
end)
addToggle(bunnyPage, "AnimationCancelMechanics", "Animation Cancel on Burst")
addLabel(bunnyPage, "Bunny Hop jumps when Space is held as you land.", 34)

local espPage = createPage("Player ESP")
addLabel(espPage, "Player ESP view of actual player characters; dummies are not scanned.", 42)
addToggle(espPage, "ESP", "Player ESP", function(on)
    if refreshAllESP then refreshAllESP() end
    if espCounter then espCounter.Text = on and "Player ESP: ON" or "Player ESP: OFF" end
end)
addToggle(espPage, "TeamCheck", "Hide Teammates", function()
    if refreshAllESP then refreshAllESP() end
end)
addToggle(espPage, "Names", "Show Player Names", function()
    if refreshAllESP then refreshAllESP() end
end)
addToggle(espPage, "Distance", "Show Distance", function()
    if refreshAllESP then refreshAllESP() end
end)
addToggle(espPage, "Tracers", "Show Tracers")

local visualsPage = createPage("Visuals")
addToggle(visualsPage, "FullBright", "Full Bright", function(on)
    if setFullBright then setFullBright(on) end
end)
addToggle(visualsPage, "LowGraphics", "Low Graphics", function(on)
    if setLowGraphics then setLowGraphics(on) end
end)
addLabel(visualsPage, "Low Graphics disables local particle and beam effects for testing.", 38)

local movementPage = createPage("Movement")
addLabel(movementPage, "Movement keybinds", 25)
addLabel(movementPage, "Sprint: Left Shift   |   Slide: C   |   Dash: Q", 32)
addLabel(movementPage, "Dodge: E   |   Quick-Step: X   |   Roll: V", 32)
addLabel(movementPage, "Ledge Vault: G   |   Fly vertical: Space / Left Ctrl", 34)
addLabel(movementPage, "Mobile: tap an action below after enabling its toggle on Character.", 36)
addButton(movementPage, "USE SLIDE", function()
    if S.SlideMechanics and root and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
        applyBurst("Slide", root.CFrame.LookVector, math.clamp(WALK_SPEED * 1.8, 22, 90), 0, 0.55)
    end
end)
addButton(movementPage, "USE DASH", function()
    if S.DashMechanics then applyBurst("Dash", root and root.CFrame.LookVector, math.clamp(WALK_SPEED * 2.4, 30, 150), 2, 0.4) end
end)
addButton(movementPage, "USE DODGE", function()
    if S.DodgeMechanics then applyBurst("Dodge", root and root.CFrame.RightVector, math.clamp(WALK_SPEED * 1.8, 24, 100), 3, 0.35) end
end)
addButton(movementPage, "USE QUICK-STEP", function()
    if S.QuickStep then applyBurst("QuickStep", root and root.CFrame.LookVector, math.clamp(WALK_SPEED * 1.6, 22, 100), 1, 0.3) end
end)
addButton(movementPage, "USE COMBAT ROLL", function()
    if S.CombatRoll then applyBurst("CombatRoll", root and root.CFrame.LookVector, math.clamp(WALK_SPEED * 1.5, 20, 90), 1, 0.65) end
end)
addButton(movementPage, "TRY LEDGE VAULT", function()
    if S.LedgeGrab then tryLedgeVault() end
end)
addButton(movementPage, "RESET CHARACTER MOVEMENT", function()
    if humanoid then
        humanoid.WalkSpeed = WALK_SPEED
        humanoid.UseJumpPower = true
        humanoid.JumpPower = JUMP_POWER
    end
end)

local settingsPage = createPage("Settings")
addLabel(settingsPage, "ANDRIA DEV PANEL — Developer Edition", 30)
addLabel(settingsPage, "Right Shift shows or hides the panel. Close/minimize hides it; DEV reopens it.", 42)
addLabel(settingsPage, "High speed and jump values can make physics unstable. Use them carefully in your test place.", 48)
addResetButton(settingsPage)
addButton(settingsPage, "REBUILD PLAYER ESP", function()
    if refreshAllESP then refreshAllESP() end
end)

setFullBright = function(enabled)
    S.FullBright = enabled
    if enabled then
        if not oldLighting then
            oldLighting = {
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                ExposureCompensation = Lighting.ExposureCompensation,
            }
        end
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(190, 190, 190)
        Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
        Lighting.ExposureCompensation = 0.25
    else
        if oldLighting then
            for key, value in pairs(oldLighting) do
                pcall(function() Lighting[key] = value end)
            end
            oldLighting = nil
        end
    end
end

local function isVisualEffect(instance)
    return instance:IsA("ParticleEmitter")
        or instance:IsA("Trail")
        or instance:IsA("Beam")
        or instance:IsA("Smoke")
        or instance:IsA("Fire")
        or instance:IsA("Sparkles")
end

local function setEffectEnabled(instance, enabled)
    if not isVisualEffect(instance) then return end
    if enabled then
        if lowGraphicsOriginal[instance] == nil then
            lowGraphicsOriginal[instance] = instance.Enabled
        end
        instance.Enabled = false
    else
        local original = lowGraphicsOriginal[instance]
        if original ~= nil and instance.Parent then
            pcall(function() instance.Enabled = original end)
        end
        lowGraphicsOriginal[instance] = nil
    end
end

setLowGraphics = function(enabled)
    S.LowGraphics = enabled
    if enabled then
        if terrainDecorationOriginal == nil then
            pcall(function() terrainDecorationOriginal = Workspace.Terrain.Decoration end)
        end
        for _, instance in ipairs(Workspace:GetDescendants()) do
            setEffectEnabled(instance, true)
        end
        pcall(function() Workspace.Terrain.Decoration = false end)
    else
        for instance, original in pairs(lowGraphicsOriginal) do
            if instance and instance.Parent then
                pcall(function() instance.Enabled = original end)
            end
            lowGraphicsOriginal[instance] = nil
        end
        if terrainDecorationOriginal ~= nil then
            pcall(function() Workspace.Terrain.Decoration = terrainDecorationOriginal end)
            terrainDecorationOriginal = nil
        end
    end
end

setNoClip = function(enabled)
    S.NoClip = enabled
    if noclipDescendantConnection then
        noclipDescendantConnection:Disconnect()
        noclipDescendantConnection = nil
    end

    if enabled then
        local function disableCollision(instance)
            if instance:IsA("BasePart") then
                if noclipOriginal[instance] == nil then
                    noclipOriginal[instance] = instance.CanCollide
                end
                instance.CanCollide = false
            end
        end
        if character then
            for _, instance in ipairs(character:GetDescendants()) do
                disableCollision(instance)
            end
            noclipDescendantConnection = character.DescendantAdded:Connect(disableCollision)
        end
    else
        for instance, oldValue in pairs(noclipOriginal) do
            if instance and instance.Parent then
                pcall(function() instance.CanCollide = oldValue end)
            end
            noclipOriginal[instance] = nil
        end
    end
end

local function stopFlyObjects()
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
    flyUpHeld = false
    flyDownHeld = false
    if flyControls then flyControls.Visible = false end
    if humanoid then
        humanoid.AutoRotate = true
        if humanoid.Health > 0 then
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end)
        end
    end
end

setFly = function(enabled)
    S.Fly = enabled
    if flyControls then
        flyControls.Visible = enabled and UserInputService.TouchEnabled
    end
    if not enabled then
        stopFlyObjects()
        return
    end
    if not root or not humanoid then return end
    stopFlyObjects()

    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.Name = "AndriaFlyVelocity"
    flyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flyVelocity.P = 1e5
    flyVelocity.Velocity = Vector3.zero
    flyVelocity.Parent = root

    flyGyro = Instance.new("BodyGyro")
    flyGyro.Name = "AndriaFlyGyro"
    flyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    flyGyro.P = 1e5
    flyGyro.CFrame = root.CFrame
    flyGyro.Parent = root

    humanoid.AutoRotate = false
end

local function currentRayParams()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character, gui }
    params.IgnoreWater = true
    return params
end

local function cancelPlayingAnimations()
    if not S.AnimationCancelMechanics or not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        pcall(function() track:Stop(0.08) end)
    end
end

local actionCooldowns = {}
local function canUseAction(name, cooldown)
    local now = os.clock()
    if actionCooldowns[name] and now - actionCooldowns[name] < cooldown then
        return false
    end
    actionCooldowns[name] = now
    return true
end

local function horizontalUnit(vector)
    local flat = Vector3.new(vector.X, 0, vector.Z)
    if flat.Magnitude < 0.001 then return Vector3.zero end
    return flat.Unit
end

applyBurst = function(name, direction, speed, lift, cooldown)
    if not root or not humanoid or humanoid.Health <= 0 then return end
    if not canUseAction(name, cooldown or 0.25) then return end
    local dir = direction and horizontalUnit(direction) or horizontalUnit(root.CFrame.LookVector)
    if dir.Magnitude < 0.001 then dir = horizontalUnit(root.CFrame.LookVector) end
    local current = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(
        dir.X * speed,
        math.max(current.Y, lift or 0),
        dir.Z * speed
    )
    burstIgnoreUntil = os.clock() + 0.35
    cancelPlayingAnimations()
end

local function raycast(origin, direction)
    return Workspace:Raycast(origin, direction, currentRayParams())
end

local function tryWallJump()
    if not S.WallJump or not root then return false end
    local origin = root.Position
    local params = currentRayParams()
    local directions = {
        root.CFrame.LookVector * 3,
        root.CFrame.RightVector * 3,
        -root.CFrame.RightVector * 3,
    }
    for _, direction in ipairs(directions) do
        local result = Workspace:Raycast(origin, direction, params)
        if result and math.abs(result.Normal.Y) < 0.45 then
            local away = Vector3.new(result.Normal.X, 0, result.Normal.Z)
            if away.Magnitude > 0.001 then
                local current = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = away.Unit * 42 + Vector3.new(current.X * 0.2, 54, current.Z * 0.2)
                airJumpsUsed = 0
                burstIgnoreUntil = os.clock() + 0.25
                return true
            end
        end
    end
    return false
end

local function tryAirJump()
    if not humanoid or not root or humanoid.Health <= 0 or S.Fly then return end
    if humanoid.FloorMaterial ~= Enum.Material.Air then
        airJumpsUsed = 0
        return
    end
    if tryWallJump() then return end

    local maxAirJumps = S.MultiJump and 5 or 1
    if not S.DoubleJump and not S.MultiJump then return end
    if airJumpsUsed >= maxAirJumps then return end

    airJumpsUsed += 1
    local current = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(current.X, math.max(current.Y, JUMP_POWER), current.Z)
end

tryLedgeVault = function()
    if not S.LedgeGrab or not root or not humanoid or humanoid.Health <= 0 then return end
    if not canUseAction("LedgeVault", 0.5) then return end

    local forward = horizontalUnit(root.CFrame.LookVector)
    if forward.Magnitude < 0.01 then return end
    local params = currentRayParams()
    local wallOrigin = root.Position + Vector3.new(0, 1.5, 0)
    local wallHit = Workspace:Raycast(wallOrigin, forward * 3, params)
    local upperOrigin = root.Position + Vector3.new(0, 4, 0)
    local upperHit = Workspace:Raycast(upperOrigin, forward * 3, params)

    if wallHit and not upperHit then
        local downOrigin = root.Position + forward * 3 + Vector3.new(0, 6, 0)
        local groundHit = Workspace:Raycast(downOrigin, Vector3.new(0, -8, 0), params)
        if groundHit then
            local rise = groundHit.Position.Y - root.Position.Y
            if rise > 0.2 and rise < 5 then
                local current = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = forward * math.clamp(WALK_SPEED, 18, 70)
                    + Vector3.new(0, 35, 0)
                burstIgnoreUntil = os.clock() + 0.35
                cancelPlayingAnimations()
            end
        end
    end
end

local function startCharacterConnections()
    for _, conn in ipairs(characterConnections) do
        conn:Disconnect()
    end
    table.clear(characterConnections)
    if not humanoid then return end

    table.insert(characterConnections, humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
            airJumpsUsed = 0
        end
        if newState == Enum.HumanoidStateType.Landed and S.LandingRecovery and humanoid and humanoid.Health > 0 then
            local target = (S.CombatSprint and shiftHeld) and SPRINT_SPEED or WALK_SPEED
            humanoid.WalkSpeed = math.clamp(target + 3, 10, 500)
            task.delay(0.22, function()
                if humanoid and humanoid.Parent then
                    humanoid.WalkSpeed = (S.CombatSprint and shiftHeld) and SPRINT_SPEED or WALK_SPEED
                end
            end)
        end
    end))
end

local function setCharacter(char)
    stopFlyObjects()
    if noclipDescendantConnection then
        noclipDescendantConnection:Disconnect()
        noclipDescendantConnection = nil
    end
    for part, oldCanCollide in pairs(noclipOriginal) do
        if part and part.Parent then
            pcall(function() part.CanCollide = oldCanCollide end)
        end
        noclipOriginal[part] = nil
    end
    character = char
    humanoid = char and char:WaitForChild("Humanoid", 5)
    root = char and char:WaitForChild("HumanoidRootPart", 5)
    airJumpsUsed = 0
    originalHipHeight = humanoid and humanoid.HipHeight or nil

    if humanoid then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = JUMP_POWER
        humanoid.WalkSpeed = (S.CombatSprint and shiftHeld) and SPRINT_SPEED or WALK_SPEED
    end

    if S.NoClip then setNoClip(true) end
    if S.Fly then setFly(true) end
    startCharacterConnections()
end

if LP.Character then
    task.spawn(setCharacter, LP.Character)
end
connect(LP.CharacterAdded, setCharacter)

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end
connect(Players.PlayerAdded, setupPlayer)
connect(Players.PlayerRemoving, function(player)
    clearESP(player)
    if playerConnections[player] then
        for _, conn in ipairs(playerConnections[player]) do conn:Disconnect() end
        playerConnections[player] = nil
    end
end)

connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    local key = input.KeyCode

    if key == Enum.KeyCode.RightShift then
        if main.Visible then hidePanel() else showPanel() end
        return
    end

    if key == Enum.KeyCode.LeftShift then
        shiftHeld = true
        if humanoid and S.CombatSprint and not S.MovementSmoothing then
            humanoid.WalkSpeed = SPRINT_SPEED
        end
    elseif key == Enum.KeyCode.C and S.SlideMechanics then
        if root and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
            applyBurst("Slide", root.CFrame.LookVector, math.clamp(WALK_SPEED * 1.8, 22, 90), 0, 0.55)
            if humanoid and originalHipHeight then
                humanoid.HipHeight = math.max(0, originalHipHeight - 0.5)
                task.delay(0.45, function()
                    if humanoid and humanoid.Parent and originalHipHeight then
                        humanoid.HipHeight = originalHipHeight
                    end
                end)
            end
        end
    elseif key == Enum.KeyCode.Q and S.DashMechanics then
        applyBurst("Dash", root and root.CFrame.LookVector, math.clamp(WALK_SPEED * 2.4, 30, 150), 2, 0.4)
    elseif key == Enum.KeyCode.E and S.DodgeMechanics then
        local side = UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 1
        applyBurst("Dodge", root and root.CFrame.RightVector * side, math.clamp(WALK_SPEED * 1.8, 24, 100), 3, 0.35)
    elseif key == Enum.KeyCode.X and S.QuickStep then
        applyBurst("QuickStep", root and root.CFrame.LookVector, math.clamp(WALK_SPEED * 1.6, 22, 100), 1, 0.3)
    elseif key == Enum.KeyCode.V and S.CombatRoll then
        applyBurst("CombatRoll", root and root.CFrame.LookVector, math.clamp(WALK_SPEED * 1.5, 20, 90), 1, 0.65)
    elseif key == Enum.KeyCode.G and S.LedgeGrab then
        tryLedgeVault()
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        shiftHeld = false
        if humanoid and S.CombatSprint and not S.MovementSmoothing then
            humanoid.WalkSpeed = WALK_SPEED
        end
    end
end)

local lastJumpRequest = 0
connect(UserInputService.JumpRequest, function()
    if S.Fly then return end
    if os.clock() - lastJumpRequest < 0.12 then return end
    lastJumpRequest = os.clock()
    if humanoid and humanoid.FloorMaterial == Enum.Material.Air then
        tryAirJump()
    end
end)

connect(Workspace.DescendantAdded, function(instance)
    if S.LowGraphics and isVisualEffect(instance) then
        task.defer(function()
            if instance.Parent and S.LowGraphics then
                setEffectEnabled(instance, true)
            end
        end)
    end
end)

connect(RunService.Heartbeat, function(dt)
    if not gui.Parent then return end

    if fovCircle then
        fovCircle.Visible = S.AimAssistOverlay and S.FOV
        fovCircle.Size = UDim2.fromOffset(FOV_RADIUS * 2, FOV_RADIUS * 2)
    end
    if crosshair then
        crosshair.Visible = S.AimAssistOverlay and S.Crosshair
    end
    if predictionLabel then
        predictionLabel.Visible = S.MovementPrediction
    end

    if humanoid and humanoid.Parent and humanoid.Health > 0 then
        local targetSpeed = (S.CombatSprint and shiftHeld) and SPRINT_SPEED or WALK_SPEED
        if S.MovementSmoothing then
            humanoid.WalkSpeed = humanoid.WalkSpeed + (targetSpeed - humanoid.WalkSpeed) * math.clamp(dt * 12, 0, 1)
        elseif not S.Fly then
            if math.abs(humanoid.WalkSpeed - targetSpeed) > 0.1 then
                humanoid.WalkSpeed = targetSpeed
            end
        end

        if S.Fly and root and flyVelocity and flyGyro then
            local camera = Workspace.CurrentCamera
            if camera then
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                if S.HoverMode then
                    local flatForward = Vector3.new(forward.X, 0, forward.Z)
                    local flatRight = Vector3.new(right.X, 0, right.Z)
                    if flatForward.Magnitude > 0.01 then forward = flatForward.Unit end
                    if flatRight.Magnitude > 0.01 then right = flatRight.Unit end
                end

                local direction = Vector3.zero
                local hasKeyboardDirection = false
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += forward; hasKeyboardDirection = true end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= forward; hasKeyboardDirection = true end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += right; hasKeyboardDirection = true end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= right; hasKeyboardDirection = true end
                if not hasKeyboardDirection then
                    direction = humanoid.MoveDirection
                    if S.HoverMode then direction = Vector3.new(direction.X, 0, direction.Z) end
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) or flyUpHeld then direction += Vector3.yAxis end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or flyDownHeld then direction -= Vector3.yAxis end
                if direction.Magnitude > 1 then direction = direction.Unit end
                flyVelocity.Velocity = direction * FLY_SPEED
                local look = Vector3.new(forward.X, 0, forward.Z)
                if look.Magnitude > 0.01 then
                    flyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + look.Unit)
                end
                if S.HoverMode and direction.Magnitude < 0.01 then
                    flyVelocity.Velocity = Vector3.zero
                end
            end
        end

        if S.BunnyHop or S.JumpTimingAssistance then
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)
                and humanoid.FloorMaterial ~= Enum.Material.Air
                and os.clock() - lastBunnyJump > 0.12 then
                lastBunnyJump = os.clock()
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end

        if root and humanoid.FloorMaterial == Enum.Material.Air then
            local moveDirection = humanoid.MoveDirection
            if moveDirection.Magnitude > 0.05 and (S.AirStrafing or S.StrafeAssistance or S.StrafingOptimization) then
                local velocity = root.AssemblyLinearVelocity
                local flat = Vector3.new(velocity.X, 0, velocity.Z)
                local accel = 0
                if S.AirStrafing then accel += 18 end
                if S.StrafeAssistance then accel += 10 end
                if S.StrafingOptimization then accel += 8 end
                flat += Vector3.new(moveDirection.X, 0, moveDirection.Z) * accel * dt
                local cap = math.max(WALK_SPEED, SPRINT_SPEED)
                if flat.Magnitude > cap then flat = flat.Unit * cap end
                root.AssemblyLinearVelocity = Vector3.new(flat.X, velocity.Y, flat.Z)
            end
        end

        if S.WallRun and root and humanoid.FloorMaterial == Enum.Material.Air
            and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            local sideVector = nil
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                sideVector = -root.CFrame.RightVector
            elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
                sideVector = root.CFrame.RightVector
            end
            if sideVector then
                local hit = raycast(root.Position, sideVector * 2.8)
                if hit and math.abs(hit.Normal.Y) < 0.45 then
                    local tangent = Vector3.yAxis:Cross(hit.Normal)
                    if tangent.Magnitude > 0.01 then
                        tangent = tangent.Unit
                        if tangent:Dot(humanoid.MoveDirection) < 0 then tangent = -tangent end
                        local oldVelocity = root.AssemblyLinearVelocity
                        local horizontalSpeed = math.clamp(math.max(WALK_SPEED, Vector3.new(oldVelocity.X, 0, oldVelocity.Z).Magnitude), 10, 100)
                        root.AssemblyLinearVelocity = Vector3.new(tangent.X * horizontalSpeed, math.max(oldVelocity.Y, 2), tangent.Z * horizontalSpeed)
                    end
                end
            end
        end

        if S.KnockbackResistance and root and os.clock() > burstIgnoreUntil then
            local velocity = root.AssemblyLinearVelocity
            local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
            local currentSpeed = horizontal.Magnitude
            local limit = math.clamp(math.max(WALK_SPEED, SPRINT_SPEED) * 1.3, 20, 500)
            if currentSpeed > limit and currentSpeed > lastHorizontalSpeed + 28 then
                local reduced = horizontal.Unit * limit
                root.AssemblyLinearVelocity = Vector3.new(reduced.X, velocity.Y, reduced.Z)
                currentSpeed = limit
            end
            lastHorizontalSpeed = currentSpeed
        elseif root then
            local velocity = root.AssemblyLinearVelocity
            lastHorizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        end

        if S.MovementPrediction and predictionLabel and root then
            local future = root.Position + root.AssemblyLinearVelocity * 0.2
            predictionLabel.Text = string.format(
                "Predicted +0.2s: %.1f, %.1f, %.1f",
                future.X, future.Y, future.Z
            )
        end
    end

    local camera = Workspace.CurrentCamera
    if camera then
        local viewport = camera.ViewportSize
        local from = Vector2.new(viewport.X * 0.5, viewport.Y - 12)
        local count = 0
        for player, data in pairs(espObjects) do
            local char = player.Character
            local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
            local targetHumanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not S.ESP or not isEnemy(player) or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
                data.Tracer.Visible = false
                if data.Billboard then data.Billboard.Enabled = false end
            else
                count += 1
                data.Billboard.Enabled = S.Names or S.Distance
                local distance = root and math.floor((root.Position - targetRoot.Position).Magnitude + 0.5) or 0
                local parts = {}
                if S.Names then table.insert(parts, player.Name) end
                if S.Distance then table.insert(parts, tostring(distance) .. " studs") end
                data.Label.Text = table.concat(parts, " | ")

                local screenPos, visible = camera:WorldToViewportPoint(targetRoot.Position)
                if S.Tracers and visible and screenPos.Z > 0 then
                    local to = Vector2.new(screenPos.X, screenPos.Y)
                    local delta = to - from
                    data.Tracer.Position = UDim2.fromOffset(from.X, from.Y)
                    data.Tracer.Size = UDim2.fromOffset(2, delta.Magnitude)
                    data.Tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X)) - 90
                    data.Tracer.Visible = true
                else
                    data.Tracer.Visible = false
                end
            end
        end
        if espCounter then
            espCounter.Text = S.ESP and ("Player ESP: " .. tostring(count)) or "Player ESP: OFF"
        end
        if lastViewportSize ~= viewport then
            lastViewportSize = viewport
            updateResponsiveScale()
        end
    end
end)

LP:SetAttribute("AimAssistSmoothness", AIM_SMOOTHNESS)
if Workspace.CurrentCamera then
    Workspace.CurrentCamera.FieldOfView = CAMERA_FOV
end
fovCircle.Visible = S.AimAssistOverlay and S.FOV
crosshair.Visible = S.AimAssistOverlay and S.Crosshair
showPage("Aim Assist")
updateResponsiveScale()

gui.Destroying:Connect(function()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    for _, conn in ipairs(characterConnections) do
        pcall(function() conn:Disconnect() end)
    end
    for _, perPlayer in pairs(playerConnections) do
        for _, conn in ipairs(perPlayer) do
            pcall(function() conn:Disconnect() end)
        end
    end
    stopFlyObjects()
    setNoClip(false)
    setFullBright(false)
    setLowGraphics(false)
    for player in pairs(espObjects) do clearESP(player) end
end)
