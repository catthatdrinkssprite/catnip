--Prison Life
local Library = loadstring(game:HttpGet("https://github.com/catthatdrinkssprite/catnip/raw/main/libraries/scoot/Library.lua"))()

local Window = Library:Window({
    Logo = getcustomasset("catnip/images/paw.png"),
    FadeTime = 0.3,
})

Library.MenuKeybind = tostring(Enum.KeyCode.Delete)

local Watermark = Library:Watermark("loading...")
local KeybindList = Library:KeybindList()

do
    local CombatPage = Window:Page({Name = "Combat", SubPages = true})
    local MovementPage = Window:Page({Name = "Movement", Columns = 2})
    local VisualsPage = Window:Page({Name = "Visuals", SubPages = true})
    local WorldPage = Window:Page({Name = "World", SubPages = true})
    local MiscPage = Window:Page({Name = "Misc", Columns = 2})
    local BlatantPage = Window:Page({Name = "Blatant", Columns = 2})
    local PlayersPage = Window:Page({Name = "Players", Columns = 2})
    local SettingsPage = Library:CreateSettingsPage(Window, Watermark, KeybindList)

    local RagebotForcedTarget = nil
    local RagebotMuzzleOrigin = nil

    local RunService = game:GetService("RunService")
    local RenderCache = {}
    local NotificationShown = {}
    local CleanupCallbacks = {}
    local TrackedDrawings = {}
    local TrackedConnections = {}

    local function RegisterCleanup(fn)
        table.insert(CleanupCallbacks, fn)
    end

    local function TrackDrawing(obj)
        table.insert(TrackedDrawings, obj)
        return obj
    end

    local function TrackConnection(conn)
        table.insert(TrackedConnections, conn)
        return conn
    end

    local FriendsCache = {}
    do
        local LP = game:GetService("Players").LocalPlayer
        for _, p in pairs(game:GetService("Players"):GetPlayers()) do
            if p ~= LP then
                task.spawn(function()
                    local ok, result = pcall(LP.IsFriendsWith, LP, p.UserId)
                    if ok then FriendsCache[p.Name] = result end
                end)
            end
        end
        TrackConnection(game:GetService("Players").PlayerAdded:Connect(function(p)
            task.spawn(function()
                local ok, result = pcall(LP.IsFriendsWith, LP, p.UserId)
                if ok then FriendsCache[p.Name] = result end
            end)
        end))
        TrackConnection(game:GetService("Players").PlayerRemoving:Connect(function(p)
            FriendsCache[p.Name] = nil
        end))
    end

    local function NewRender(Callback)
        local Connection = {
            Function = Callback,
        }
        local Index = #RenderCache + 1
        RenderCache[Index] = Connection
        Connection.Disconnect = function(self)
            if RenderCache[Index] then RenderCache[Index] = nil end
        end
        return Connection
    end

    local MasterRenderConnection = RunService.RenderStepped:Connect(function(Delta)
        for _, Connection in RenderCache do
            Connection.Function(Delta)
        end
    end)
    RegisterCleanup(function()
        MasterRenderConnection:Disconnect()
    end)

    local PingWarningEnabled = false
    local KillfeedNotificationsEnabled = false
    local PingThreshold = 0.3
    local LastPingWarning = 0
    local PingCooldown = 30
    local AutoBlacklistSet = {}
    local ItemESPState = {
        Enabled = false,
        Items = {},
        Color = Library.Theme.Accent,
        Chams = false,
        ChamsColor = Library.Theme.Accent,
        ChamsFillTransparency = 0.5,
    }
    local ItemESPDrawings = {}
    local ItemESPHighlights = {}
    local ItemESPChamsFolder = Instance.new("Folder")
    ItemESPChamsFolder.Name = "catnipItemChams"
    ItemESPChamsFolder.Parent = game:GetService("CoreGui")

    local function ResolvePickupPart(obj)
        if obj:IsA("BasePart") then
            return obj
        elseif obj:IsA("Model") then
            return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        end
        return nil
    end

    do
        local LastFPS = 0
        local FrameCount = 0
        local LastFPSUpdate = os.clock()

        NewRender(function(Delta)
            FrameCount = FrameCount + 1
            local now = os.clock()
            if now - LastFPSUpdate >= 0.5 then
                LastFPS = math.floor(FrameCount / (now - LastFPSUpdate))
                FrameCount = 0
                LastFPSUpdate = now
            end

            local ping = game.Players.LocalPlayer:GetNetworkPing()
            local pingMs = math.floor(ping * 1000)
            Watermark:SetText(string.format("catnip | Prison Life | %d FPS | %dms | gg/DPBtncwaEm", LastFPS, pingMs))

            if PingWarningEnabled and ping >= PingThreshold and (now - LastPingWarning) >= PingCooldown then
                LastPingWarning = now
                Library:Notification("High Ping", string.format("Your ping is %dms — gameplay may be unplayable.", pingMs), 5)
            end
        end)
    end

    do
        local GunModsSubPage = CombatPage:SubPage({Name = "Gun Mods", Columns = 2})

        do
            local LP = game:GetService("Players").LocalPlayer
            local OriginalValues = {}
            local GunModConnections = {}

            local function GetToolKey(tool)
                return tostring(tool) .. "_" .. tool:GetDebugId()
            end

            local function GetAllTools()
                local tools = {}
                for _, tool in pairs(LP.Backpack:GetChildren()) do
                    if tool:IsA("Tool") then table.insert(tools, tool) end
                end
                local char = LP.Character
                if char then
                    for _, tool in pairs(char:GetChildren()) do
                        if tool:IsA("Tool") then table.insert(tools, tool) end
                    end
                end
                return tools
            end

            local function SaveOriginal(tool, attr)
                local key = GetToolKey(tool)
                if not OriginalValues[key] then OriginalValues[key] = {} end
                if OriginalValues[key][attr] == nil then
                    OriginalValues[key][attr] = tool:GetAttribute(attr)
                end
            end

            local function RestoreOriginal(tool, attr)
                local key = GetToolKey(tool)
                if OriginalValues[key] and OriginalValues[key][attr] ~= nil then
                    tool:SetAttribute(attr, OriginalValues[key][attr])
                    OriginalValues[key][attr] = nil
                    if not next(OriginalValues[key]) then OriginalValues[key] = nil end
                end
            end

            local function ApplyMod(tool, attr, value, flagGet)
                if not tool:IsA("Tool") then return end
                if tool:GetAttribute(attr) == nil then return end
                if flagGet() ~= true then return end
                SaveOriginal(tool, attr)
                tool:SetAttribute(attr, value)
            end

            local function RevertMod(attr)
                for _, tool in pairs(GetAllTools()) do
                    RestoreOriginal(tool, attr)
                end
            end

            local GunModFlags = {
                NoFireRate = false,
                NoSpread = false,
                ForceAutoFire = false,
            }

            local function ApplyAllMods(tool)
                ApplyMod(tool, "FireRate", 0, function() return GunModFlags.NoFireRate end)
                ApplyMod(tool, "SpreadRadius", 0, function() return GunModFlags.NoSpread end)
                ApplyMod(tool, "AutoFire", true, function() return GunModFlags.ForceAutoFire end)
            end

            local function ConnectContainer(container)
                local conn = container.ChildAdded:Connect(function(tool)
                    if tool:IsA("Tool") then
                        task.defer(ApplyAllMods, tool)
                    end
                end)
                table.insert(GunModConnections, conn)
            end

            ConnectContainer(LP.Backpack)
            if LP.Character then ConnectContainer(LP.Character) end
            local charConn = LP.CharacterAdded:Connect(function(char)
                ConnectContainer(char)
                task.defer(function()
                    for _, tool in pairs(GetAllTools()) do
                        ApplyAllMods(tool)
                    end
                end)
            end)
            table.insert(GunModConnections, charConn)

            local NoFireRate = GunModsSubPage:Section({Name = "No Fire Rate", Side = 1}) do
                NoFireRate:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "No Fire Rate",
                        Description = "Sets weapon fire delay to zero — cap FPS to 60 or bullets arrive instantly"
                    },
                    Flag = "NoFireRateEnabled",
                    Default = false,
                    Callback = function(state)
                        GunModFlags.NoFireRate = state
                        if state then
                            if not NotificationShown["NoFireRate"] then
                                NotificationShown["NoFireRate"] = true
                                Library:Notification("Warning.", "It is recommended to use 60 FPS or below unless you want your bullets to come instantly.", 5)
                            end
                            for _, tool in pairs(GetAllTools()) do
                                ApplyMod(tool, "FireRate", 0, function() return true end)
                            end
                        else
                            RevertMod("FireRate")
                        end
                    end
                })
            end

            local NoSpread = GunModsSubPage:Section({Name = "No Spread", Side = 2}) do
                NoSpread:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "No Spread",
                        Description = "Removes bullet spread for perfect accuracy on every shot"
                    },
                    Flag = "NoSpreadEnabled",
                    Default = false,
                    Callback = function(state)
                        GunModFlags.NoSpread = state
                        if state then
                            for _, tool in pairs(GetAllTools()) do
                                ApplyMod(tool, "SpreadRadius", 0, function() return true end)
                            end
                        else
                            RevertMod("SpreadRadius")
                        end
                    end
                })
            end

            RegisterCleanup(function()
                for _, conn in pairs(GunModConnections) do conn:Disconnect() end
                for _, attr in pairs({"FireRate", "SpreadRadius", "AutoFire"}) do RevertMod(attr) end
            end)

            local ForceAutoFire = GunModsSubPage:Section({Name = "Force Auto Fire", Side = 1}) do
                ForceAutoFire:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "Force Auto Fire",
                        Description = "Makes all weapons fully automatic — hold click to spray"
                    },
                    Flag = "ForceAutoFireEnabled",
                    Default = false,
                    Callback = function(state)
                        GunModFlags.ForceAutoFire = state
                        if state then
                            for _, tool in pairs(GetAllTools()) do
                                ApplyMod(tool, "AutoFire", true, function() return true end)
                            end
                        else
                            RevertMod("AutoFire")
                        end
                    end
                })
            end
        end
    end

    do
        local AimbotSubPage = CombatPage:SubPage({Name = "Aimbot", Columns = 2})

        do
            local SilentAimSection = AimbotSubPage:Section({Name = "Silent Aim", Side = 1}) do
                local SilentAimState = {
                    Enabled = false,
                    Triggerbot = false,
                    ArrestSafety = false,
                    FoVCircle = false,
                    FoVCircleColor = Library.Theme.Accent,
                    Tracer = false,
                    TracerColor = Library.Theme.Accent,
                    Radius = 130,
                    Bone = "Head",
                    WallCheck = false,
                    MuzzleLOS = false,
                    ForceFieldCheck = true,
                    Teams = {},
                    InmateTypes = {},
                    DeathCheck = true,
                    FriendCheck = false,
                    Whitelist = {},
                    Blacklist = {},
                }

                local Camera = workspace.CurrentCamera
                local Players = game:GetService("Players")
                local LocalPlayer = Players.LocalPlayer
                local UserInputService = game:GetService("UserInputService")

                local GetPlayers = Players.GetPlayers
                local WorldToViewportPoint = Camera.WorldToViewportPoint
                local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
                local FindFirstChild = game.FindFirstChild
                local GetMouseLocation = UserInputService.GetMouseLocation

                local R6_BONES = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart"}
                local R6_BONE_ITEMS = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart", "Random", "Nearest Visible"}

                local function ResolveBone(rawBone, character, localCharacter)
                    if rawBone == "Random" then
                        return R6_BONES[math.random(1, #R6_BONES)]
                    end
                    if rawBone == "Nearest Visible" then
                        for _, name in ipairs(R6_BONES) do
                            local part = character:FindFirstChild(name)
                            if part then
                                if #GetPartsObscuringTarget(Camera, {part.Position}, {localCharacter, character}) == 0 then
                                    return name
                                end
                            end
                        end
                        return "HumanoidRootPart"
                    end
                    return rawBone
                end

                SilentAimSection:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "Silent Aim",
                        Description = "Redirects bullet raycasts toward the closest valid target without moving your camera"
                    },
                    Flag = "SilentAimEnabled",
                    Default = SilentAimState.Enabled,
                    Callback = function(v) SilentAimState.Enabled = v end
                })

                SilentAimSection:Toggle({
                    Name = "Triggerbot",
                    ToolTip = {
                        Name = "Triggerbot",
                        Description = "Automatically fires when a valid target is within the FoV circle"
                    },
                    Flag = "SilentAimTriggerbot",
                    Default = SilentAimState.Triggerbot,
                    Callback = function(v) SilentAimState.Triggerbot = v end
                })

                SilentAimSection:Toggle({
                    Name = "Arrest Safety",
                    ToolTip = {
                        Name = "Arrest Safety",
                        Description = "Ignores arrestable inmates unless you are holding the Taser — killing them without cause is punishable"
                    },
                    Flag = "SilentAimArrestSafety",
                    Default = SilentAimState.ArrestSafety,
                    Callback = function(v) SilentAimState.ArrestSafety = v end
                })

                SilentAimSection:Toggle({
                    Name = "FoV Circle",
                    ToolTip = {
                        Name = "FoV Circle",
                        Description = "Shows a circle around your cursor representing the targeting radius"
                    },
                    Flag = "SilentAimFoVEnabled",
                    Default = SilentAimState.FoVCircle,
                    Callback = function(v) SilentAimState.FoVCircle = v end
                }):Colorpicker({
                    Name = "Color",
                    Flag = "SilentAimFoVColor",
                    Default = SilentAimState.FoVCircleColor,
                    Alpha = 0,
                    Callback = function(v) SilentAimState.FoVCircleColor = v end
                })

                SilentAimSection:Toggle({
                    Name = "Tracer",
                    ToolTip = {
                        Name = "Tracer",
                        Description = "Draws a line from your cursor to the current target"
                    },
                    Flag = "SilentAimTracerEnabled",
                    Default = SilentAimState.Tracer,
                    Callback = function(v) SilentAimState.Tracer = v end
                }):Colorpicker({
                    Name = "Color",
                    Flag = "SilentAimTracerColor",
                    Default = SilentAimState.TracerColor,
                    Alpha = 0,
                    Callback = function(v) SilentAimState.TracerColor = v end
                })

                SilentAimSection:Slider({
                    Name = "Radius",
                    Flag = "SilentAimRadius",
                    Min = 1,
                    Suffix = "px",
                    Max = 500,
                    Default = SilentAimState.Radius,
                    Decimals = 1,
                    Callback = function(v) SilentAimState.Radius = v end
                })

                SilentAimSection:Dropdown({
                    Name = "Bone",
                    Flag = "SilentAimBone",
                    Default = SilentAimState.Bone,
                    Multi = false,
                    Items = R6_BONE_ITEMS,
                    Callback = function(v) SilentAimState.Bone = v end
                })

                SilentAimSection:Toggle({
                    Name = "Wall Check",
                    ToolTip = {
                        Name = "Wall Check",
                        Description = "Skips targets obscured by walls from the camera's perspective"
                    },
                    Flag = "SilentAimWallCheck",
                    Default = SilentAimState.WallCheck,
                    Callback = function(v) SilentAimState.WallCheck = v end
                })

                SilentAimSection:Toggle({
                    Name = "Muzzle LOS",
                    ToolTip = {
                        Name = "Muzzle LOS",
                        Description = "Raycasts from the gun's muzzle to the target — skips targets that would waste bullets on walls"
                    },
                    Flag = "SilentAimMuzzleLOS",
                    Default = SilentAimState.MuzzleLOS,
                    Callback = function(v) SilentAimState.MuzzleLOS = v end
                })

                SilentAimSection:Toggle({
                    Name = "ForceField Check",
                    ToolTip = {
                        Name = "ForceField Check",
                        Description = "Skips targets with an active spawn ForceField"
                    },
                    Flag = "SilentAimForceFieldCheck",
                    Default = SilentAimState.ForceFieldCheck,
                    Callback = function(v) SilentAimState.ForceFieldCheck = v end
                })

                SilentAimSection:Dropdown({
                    Name = "Teams",
                    Flag = "SilentAimTeams",
                    Multi = true,
                    Items = {"Guards", "Inmates", "Criminals"},
                    Callback = function(v)
                        local set = {}
                        for _, name in pairs(v) do set[name] = true end
                        SilentAimState.Teams = set
                    end
                })

                SilentAimSection:Dropdown({
                    Name = "Inmate Types",
                    Flag = "SilentAimInmateTypes",
                    Multi = true,
                    Items = {"Regular", "Aggressive", "Arrestable"},
                    Callback = function(v)
                        local set = {}
                        for _, name in pairs(v) do set[name] = true end
                        SilentAimState.InmateTypes = set
                    end
                })

                SilentAimSection:Toggle({
                    Name = "Death Check",
                    ToolTip = {
                        Name = "Death Check",
                        Description = "Skips dead players so you don't waste shots on corpses"
                    },
                    Flag = "SilentAimDeathCheck",
                    Default = SilentAimState.DeathCheck,
                    Callback = function(v) SilentAimState.DeathCheck = v end
                })

                SilentAimSection:Toggle({
                    Name = "Friend Check",
                    ToolTip = {
                        Name = "Friend Check",
                        Description = "Won't target players on your Roblox friends list"
                    },
                    Flag = "SilentAimFriendCheck",
                    Default = SilentAimState.FriendCheck,
                    Callback = function(v) SilentAimState.FriendCheck = v end
                }) do
                    local saPlayerNames = {}
                    for _, p in pairs(game:GetService("Players"):GetPlayers()) do
                        if p ~= game.Players.LocalPlayer then
                            table.insert(saPlayerNames, p.Name)
                        end
                    end

                    local SAWhitelistDropdown = SilentAimSection:Dropdown({
                        Name = "Whitelist",
                        Flag = "SilentAimWhitelist",
                        Multi = true,
                        Items = saPlayerNames,
                        Callback = function(v)
                            local set = {}
                            for _, name in pairs(v) do set[name] = true end
                            SilentAimState.Whitelist = set
                        end
                    })

                    local SABlacklistDropdown = SilentAimSection:Dropdown({
                        Name = "Blacklist",
                        ToolTip = { Name = "Blacklist", Description = "Always target these players regardless of team, inmate status, or arrest safety filters" },
                        Flag = "SilentAimBlacklist",
                        Multi = true,
                        Items = saPlayerNames,
                        Callback = function(v)
                            local set = {}
                            for _, name in pairs(v) do set[name] = true end
                            SilentAimState.Blacklist = set
                        end
                    })

                    TrackConnection(game:GetService("Players").PlayerAdded:Connect(function(p)
                        SAWhitelistDropdown:Add(p.Name)
                        SABlacklistDropdown:Add(p.Name)
                    end))
                    TrackConnection(game:GetService("Players").PlayerRemoving:Connect(function(p)
                        SAWhitelistDropdown:Remove(p.Name)
                        SABlacklistDropdown:Remove(p.Name)
                    end))
                end do
                    local FoVCircle = TrackDrawing(Drawing.new("Circle"))
                    FoVCircle.Thickness = 1
                    FoVCircle.NumSides = 100
                    FoVCircle.Filled = false
                    FoVCircle.Visible = false
                    FoVCircle.ZIndex = 999
                    FoVCircle.Transparency = 1

                    local Tracer = TrackDrawing(Drawing.new("Line"))
                    Tracer.Thickness = 1
                    Tracer.Visible = false
                    Tracer.ZIndex = 999
                    Tracer.Transparency = 1

                    local ExpectedArguments = {
                        FindPartOnRayWithIgnoreList = {
                            ArgCountRequired = 3,
                            Args = {"Instance", "Ray", "table", "boolean", "boolean"}
                        },
                        FindPartOnRayWithWhitelist = {
                            ArgCountRequired = 3,
                            Args = {"Instance", "Ray", "table", "boolean"}
                        },
                        FindPartOnRay = {
                            ArgCountRequired = 2,
                            Args = {"Instance", "Ray", "Instance", "boolean", "boolean"}
                        },
                        Raycast = {
                            ArgCountRequired = 3,
                            Args = {"Instance", "Vector3", "Vector3", "RaycastParams"}
                        }
                    }

                    local function ValidateArguments(Args, RayMethod)
                        local Matches = 0
                        if #Args < RayMethod.ArgCountRequired then
                            return false
                        end
                        for Pos, Argument in next, Args do
                            if typeof(Argument) == RayMethod.Args[Pos] then
                                Matches = Matches + 1
                            end
                        end
                        return Matches >= RayMethod.ArgCountRequired
                    end

                    local function getDirection(Origin, Position)
                        return (Position - Origin).Unit * 1000
                    end

                    local function getMousePosition()
                        return GetMouseLocation(UserInputService)
                    end

                    local function GetInmateStatus(Character)
                        local humanoid = FindFirstChild(Character, "Humanoid")
                        if not humanoid then return "Regular" end
                        local displayName = humanoid.DisplayName
                        if string.sub(displayName, 1, 4) == "\xF0\x9F\x94\x97" then
                            return "Arrestable"
                        elseif string.sub(displayName, 1, 4) == "\xF0\x9F\x92\xA2" then
                            return "Aggressive"
                        end
                        return "Regular"
                    end

                    local function IsPlayerVisible(Player, BoneName)
                        local PlayerCharacter = Player.Character
                        local LocalPlayerCharacter = LocalPlayer.Character
                        if not (PlayerCharacter and LocalPlayerCharacter) then return false end

                        local TargetPart = FindFirstChild(PlayerCharacter, BoneName) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
                        if not TargetPart then return false end

                        return #GetPartsObscuringTarget(Camera, {TargetPart.Position}, {LocalPlayerCharacter, PlayerCharacter}) == 0
                    end

                    local SilentAimFrameCounter = 0
                    local CachedClosestResult = nil
                    local CachedClosestFrame = -1

                    local function getClosestPlayer()
                        if CachedClosestFrame == SilentAimFrameCounter then
                            return CachedClosestResult
                        end

                        local Closest = nil
                        local ClosestDist = nil
                        local MousePos = getMousePosition()
                        local RawBone = SilentAimState.Bone

                        local checkArrestSafety = SilentAimState.ArrestSafety
                        local checkMuzzleLOS = SilentAimState.MuzzleLOS
                        local LocalCharacter = LocalPlayer.Character
                        local holdingTaser = false
                        local muzzleOrigin = nil

                        if LocalCharacter then
                            local tool = LocalCharacter:FindFirstChildOfClass("Tool")
                            if tool then
                                if checkArrestSafety then
                                    holdingTaser = tool.Name == "Taser"
                                end
                                if checkMuzzleLOS then
                                    local muzzle = tool:FindFirstChild("Muzzle") or tool:FindFirstChild("Handle")
                                    if muzzle then muzzleOrigin = muzzle.Position end
                                end
                            end
                        end

                        local losParams
                        if muzzleOrigin then
                            losParams = RaycastParams.new()
                            losParams.FilterType = Enum.RaycastFilterType.Exclude
                        end

                        local myTeam = LocalPlayer.Team and LocalPlayer.Team.Name or ""

                        for _, Player in next, GetPlayers(Players) do
                            if Player == LocalPlayer then continue end

                            local isBlacklisted = SilentAimState.Blacklist[Player.Name] or AutoBlacklistSet[Player.Name]
                            local TeamName = Player.Team and Player.Team.Name or ""

                            if isBlacklisted then
                                if TeamName == myTeam and TeamName ~= "Inmates" then continue end
                            end

                            local Character = Player.Character
                            if not Character then continue end

                            if isBlacklisted then
                                if TeamName == "Inmates" and GetInmateStatus(Character) == "Regular" then continue end
                            end

                            if not isBlacklisted then
                                if SilentAimState.Whitelist[Player.Name] then continue end
                                if SilentAimState.FriendCheck and FriendsCache[Player.Name] then continue end
                                if next(SilentAimState.Teams) and not SilentAimState.Teams[TeamName] then continue end

                                if TeamName == "Inmates" then
                                    local needStatus = next(SilentAimState.InmateTypes) or (checkArrestSafety and not holdingTaser)
                                    if needStatus then
                                        local Status = GetInmateStatus(Character)
                                        if next(SilentAimState.InmateTypes) and not SilentAimState.InmateTypes[Status] then continue end
                                        if checkArrestSafety and not holdingTaser and Status == "Arrestable" then continue end
                                    end
                                end
                            end

                            local Humanoid = FindFirstChild(Character, "Humanoid")
                            if SilentAimState.DeathCheck and (not Humanoid or Humanoid.Health <= 0) then continue end
                            if SilentAimState.ForceFieldCheck and FindFirstChild(Character, "ForceField") then continue end

                            local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
                            if not HumanoidRootPart then continue end

                            local resolvedBone = ResolveBone(RawBone, Character, LocalCharacter)
                            local targetPart = FindFirstChild(Character, resolvedBone) or HumanoidRootPart

                            if SilentAimState.WallCheck and not IsPlayerVisible(Player, resolvedBone) then continue end

                            if muzzleOrigin then
                                losParams.FilterDescendantsInstances = {LocalCharacter, Character}
                                if workspace:Raycast(muzzleOrigin, targetPart.Position - muzzleOrigin, losParams) then continue end
                            end

                            local ScreenPos, OnScreen = WorldToViewportPoint(Camera, targetPart.Position)
                            if not OnScreen then continue end

                            local Distance = (MousePos - Vector2.new(ScreenPos.X, ScreenPos.Y)).Magnitude

                            if Distance > (ClosestDist or SilentAimState.Radius) then
                                local bestBonePart = nil
                                local bestBoneDist = ClosestDist or SilentAimState.Radius
                                for _, boneName in ipairs(R6_BONES) do
                                    local bp = FindFirstChild(Character, boneName)
                                    if not bp then continue end
                                    local bsp, bos = WorldToViewportPoint(Camera, bp.Position)
                                    if not bos then continue end
                                    local bd = (MousePos - Vector2.new(bsp.X, bsp.Y)).Magnitude
                                    if bd < bestBoneDist then
                                        if muzzleOrigin then
                                            losParams.FilterDescendantsInstances = {LocalCharacter, Character}
                                            if workspace:Raycast(muzzleOrigin, bp.Position - muzzleOrigin, losParams) then continue end
                                        end
                                        bestBoneDist = bd
                                        bestBonePart = bp
                                    end
                                end
                                if bestBonePart then
                                    Closest = bestBonePart
                                    ClosestDist = bestBoneDist
                                end
                            else
                                Closest = targetPart
                                ClosestDist = Distance
                            end
                        end

                        CachedClosestResult = Closest
                        CachedClosestFrame = SilentAimFrameCounter
                        return Closest
                    end

                    NewRender(function()
                        Camera = workspace.CurrentCamera
                        SilentAimFrameCounter = SilentAimFrameCounter + 1

                        if SilentAimState.Enabled and SilentAimState.FoVCircle then
                            FoVCircle.Position = getMousePosition()
                            FoVCircle.Radius = SilentAimState.Radius
                            FoVCircle.Color = SilentAimState.FoVCircleColor
                            FoVCircle.Visible = true
                        else
                            FoVCircle.Visible = false
                        end

                        local ClosestTarget = SilentAimState.Enabled and getClosestPlayer() or nil

                        if SilentAimState.Enabled and SilentAimState.Tracer then
                            if ClosestTarget then
                                local ScreenPos, OnScreen = WorldToViewportPoint(Camera, ClosestTarget.Position)
                                if OnScreen then
                                    Tracer.From = getMousePosition()
                                    Tracer.To = Vector2.new(ScreenPos.X, ScreenPos.Y)
                                    Tracer.Color = SilentAimState.TracerColor
                                    Tracer.Visible = true
                                else
                                    Tracer.Visible = false
                                end
                            else
                                Tracer.Visible = false
                            end
                        else
                            Tracer.Visible = false
                        end

                        if SilentAimState.Triggerbot and ClosestTarget then
                            local character = LocalPlayer.Character
                            if character then
                                local tool = character:FindFirstChildOfClass("Tool")
                                if tool then
                                    local handle = tool:FindFirstChild("Handle")
                                    if handle and handle:FindFirstChild("ShootSound") then
                                        mouse1click()
                                    end
                                end
                            end
                        end
                    end)


                    local CallerBlacklist = {}
                    do
                        local cam = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerScripts")
                        if cam then
                            local pm = cam:FindFirstChild("PlayerModule")
                            if pm then
                                local cm = pm:FindFirstChild("CameraModule")
                                if cm then
                                    CallerBlacklist[cm] = true
                                    for _, desc in pairs(cm:GetDescendants()) do
                                        if desc:IsA("ModuleScript") then
                                            CallerBlacklist[desc] = true
                                        end
                                    end
                                end
                            end
                        end
                    end

                    local oldNamecall
                    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
                        local Method = getnamecallmethod()

                        if Method ~= "FindPartOnRayWithIgnoreList" and Method ~= "FindPartOnRayWithWhitelist"
                            and Method ~= "FindPartOnRay" and Method ~= "findPartOnRay" and Method ~= "Raycast" then
                            return oldNamecall(...)
                        end

                        local Arguments = {...}
                        local self = Arguments[1]

                        if self ~= workspace then return oldNamecall(...) end
                        if checkcaller() then return oldNamecall(...) end

                        local callerOk, callerScript = pcall(getcallingscript)
                        if callerOk and callerScript and CallerBlacklist[callerScript] then
                            return oldNamecall(...)
                        end

                        if not (SilentAimState.Enabled or RagebotForcedTarget) then
                            return oldNamecall(...)
                        end

                        local rbTarget = RagebotForcedTarget
                        local rbOrigin = RagebotMuzzleOrigin

                        if Method == "FindPartOnRayWithIgnoreList" then
                            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                                local HitPart = rbTarget or getClosestPlayer()
                                if HitPart then
                                    local Origin = rbOrigin or Arguments[2].Origin
                                    Arguments[2] = Ray.new(Origin, getDirection(Origin, HitPart.Position))
                                    return oldNamecall(unpack(Arguments))
                                end
                            end
                        elseif Method == "FindPartOnRayWithWhitelist" then
                            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithWhitelist) then
                                local HitPart = rbTarget or getClosestPlayer()
                                if HitPart then
                                    local Origin = rbOrigin or Arguments[2].Origin
                                    Arguments[2] = Ray.new(Origin, getDirection(Origin, HitPart.Position))
                                    return oldNamecall(unpack(Arguments))
                                end
                            end
                        elseif Method == "FindPartOnRay" or Method == "findPartOnRay" then
                            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRay) then
                                local HitPart = rbTarget or getClosestPlayer()
                                if HitPart then
                                    local Origin = rbOrigin or Arguments[2].Origin
                                    Arguments[2] = Ray.new(Origin, getDirection(Origin, HitPart.Position))
                                    return oldNamecall(unpack(Arguments))
                                end
                            end
                        elseif Method == "Raycast" then
                            if ValidateArguments(Arguments, ExpectedArguments.Raycast) then
                                local HitPart = rbTarget or getClosestPlayer()
                                if HitPart then
                                    local Origin = rbOrigin or Arguments[2]
                                    Arguments[2] = Origin
                                    Arguments[3] = getDirection(Origin, HitPart.Position)
                                    return oldNamecall(unpack(Arguments))
                                end
                            end
                        end

                        return oldNamecall(...)
                    end))

                    RegisterCleanup(function()
                        hookmetamethod(game, "__namecall", oldNamecall)
                    end)
                end
            end
        end
    end

    do
        local HitSoundsSubPage = CombatPage:SubPage({Name = "Hit Sounds", Columns = 2})

        do
            local SoundFiles = {
                ["12.mp3"] = getcustomasset("catnip/sounds/12.mp3"),
                ["agpa2.mp3"] = getcustomasset("catnip/sounds/agpa2.mp3"),
                ["basshit.mp3"] = getcustomasset("catnip/sounds/basshit.mp3"),
                ["bell.mp3"] = getcustomasset("catnip/sounds/bell.mp3"),
                ["blizzard.mp3"] = getcustomasset("catnip/sounds/blizzard.mp3"),
                ["bubble.mp3"] = getcustomasset("catnip/sounds/bubble.mp3"),
                ["chockpro.mp3"] = getcustomasset("catnip/sounds/chockpro.mp3"),
                ["cod.mp3"] = getcustomasset("catnip/sounds/cod.mp3"),
                ["copperbell.mp3"] = getcustomasset("catnip/sounds/copperbell.mp3"),
                ["crowbar.mp3"] = getcustomasset("catnip/sounds/crowbar.mp3"),
                ["headshot.mp3"] = getcustomasset("catnip/sounds/headshot.mp3"),
                ["knob.mp3"] = getcustomasset("catnip/sounds/knob.mp3"),
                ["minecraft orb.mp3"] = getcustomasset("catnip/sounds/minecraft orb.mp3"),
                ["neverlose.mp3"] = getcustomasset("catnip/sounds/neverlose.mp3"),
                ["rust.mp3"] = getcustomasset("catnip/sounds/rust.mp3"),
                ["skeet.mp3"] = getcustomasset("catnip/sounds/skeet.mp3"),
            }

            local Players = game:GetService("Players")
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local LocalPlayer = Players.LocalPlayer
            local HealthConnections = {}
            local LastFireTime = 0
            local HIT_WINDOW = 0.35

            local HitSoundState = {
                Enabled = false,
                Volume = 1,
                Sound = "rust.mp3",
                MuteGunSound = false,
            }

            local KillSoundState = {
                Enabled = false,
                Volume = 1,
                Sound = "minecraft orb.mp3",
            }
            local ConfirmedKillCount = 0

            local function PlaySound(soundFile, volume)
                local id = SoundFiles[soundFile]
                if not id then return end
                local sound = Instance.new("Sound")
                sound.SoundId = id
                sound.Volume = volume
                sound.PlayOnRemove = true
                sound.Parent = workspace
                sound:Destroy()
            end

            local function PlayHitSound()
                PlaySound(HitSoundState.Sound, HitSoundState.Volume)
            end

            local function PlayKillSound()
                PlaySound(KillSoundState.Sound, KillSoundState.Volume)
            end

            local function IsLocalKillfeedEntry(entryText)
                if type(entryText) ~= "string" or entryText == "" then
                    return false
                end
                local killPos = string.find(entryText, " killed ", 1, true)
                if not killPos then
                    return false
                end
                local killerText = string.sub(entryText, 1, killPos - 1)
                local token = "(@" .. LocalPlayer.Name .. ")"
                return string.find(string.lower(killerText), string.lower(token), 1, true) ~= nil
            end

            local function MuteShootSound(tool)
                local handle = tool:FindFirstChild("Handle")
                if not handle then return end
                local shootSound = handle:FindFirstChild("ShootSound")
                if not shootSound or not shootSound:IsA("Sound") then return end
                if HitSoundState.MuteGunSound then
                    shootSound.Volume = 0
                end
            end

            local function HookTool(tool)
                if not tool:IsA("Tool") then return end
                tool.Activated:Connect(function()
                    LastFireTime = tick()
                    MuteShootSound(tool)
                end)
            end

            local function HookCharacter(character)
                for _, child in pairs(character:GetChildren()) do
                    HookTool(child)
                end
                TrackConnection(character.ChildAdded:Connect(HookTool))
            end

            if LocalPlayer.Character then HookCharacter(LocalPlayer.Character) end
            TrackConnection(LocalPlayer.CharacterAdded:Connect(HookCharacter))
            TrackConnection(LocalPlayer.Backpack.ChildAdded:Connect(HookTool))
            for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                HookTool(tool)
            end

            local function TrackPlayer(player)
                if player == LocalPlayer then return end

                local function ConnectHealth(character)
                    local humanoid = character:WaitForChild("Humanoid", 5)
                    if not humanoid then return end
                    local lastHealth = humanoid.Health

                    if HealthConnections[player] then
                        HealthConnections[player]:Disconnect()
                    end

                    HealthConnections[player] = humanoid.HealthChanged:Connect(function(newHealth)
                        if (tick() - LastFireTime) <= HIT_WINDOW and newHealth < lastHealth then
                            if HitSoundState.Enabled then
                                PlayHitSound()
                            end
                        end
                        lastHealth = newHealth
                    end)
                end

                if player.Character then
                    task.spawn(ConnectHealth, player.Character)
                end
                TrackConnection(player.CharacterAdded:Connect(function(char)
                    task.spawn(ConnectHealth, char)
                end))
            end

            for _, player in pairs(Players:GetPlayers()) do
                TrackPlayer(player)
            end
            TrackConnection(Players.PlayerAdded:Connect(TrackPlayer))
            TrackConnection(Players.PlayerRemoving:Connect(function(player)
                if HealthConnections[player] then
                    HealthConnections[player]:Disconnect()
                    HealthConnections[player] = nil
                end
            end))

            local KillfeedFolder = ReplicatedStorage:FindFirstChild("Killfeed")
            if KillfeedFolder then
                TrackConnection(KillfeedFolder.ChildAdded:Connect(function(entry)
                    if not entry:IsA("IntValue") then
                        return
                    end
                    local entryText = entry.Name
                    if KillfeedNotificationsEnabled then
                        Library:Notification("Killfeed", entryText, 3)
                    end
                    if KillSoundState.Enabled and IsLocalKillfeedEntry(entryText) then
                        ConfirmedKillCount = ConfirmedKillCount + 1
                        PlayKillSound()
                    end
                end))
            end

            RegisterCleanup(function()
                for player, conn in pairs(HealthConnections) do
                    conn:Disconnect()
                end
                local function RestoreAllSounds(container)
                    for _, tool in pairs(container:GetChildren()) do
                        if tool:IsA("Tool") then
                            local handle = tool:FindFirstChild("Handle")
                            if handle then
                                local s = handle:FindFirstChild("ShootSound")
                                if s and s:IsA("Sound") then s.Volume = 0.5 end
                            end
                        end
                    end
                end
                RestoreAllSounds(LocalPlayer.Backpack)
                if LocalPlayer.Character then RestoreAllSounds(LocalPlayer.Character) end
            end)

            local HitSoundsSection = HitSoundsSubPage:Section({Name = "Hit Sounds", Side = 1}) do
                HitSoundsSection:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "Hit Sounds",
                        Description = "Plays a custom sound when your bullets damage a player"
                    },
                    Flag = "HitSoundsEnabled",
                    Default = false,
                    Callback = function(v) HitSoundState.Enabled = v end
                })

                HitSoundsSection:Toggle({
                    Name = "Mute Gun Sound",
                    ToolTip = {
                        Name = "Mute Gun Sound",
                        Description = "Silences the weapon's shoot sound effect"
                    },
                    Flag = "HitSoundsMuteGun",
                    Default = false,
                    Callback = function(v)
                        HitSoundState.MuteGunSound = v
                        local char = LocalPlayer.Character
                        if not v then
                            local function RestoreVolume(container)
                                for _, tool in pairs(container:GetChildren()) do
                                    if tool:IsA("Tool") then
                                        local handle = tool:FindFirstChild("Handle")
                                        if handle then
                                            local s = handle:FindFirstChild("ShootSound")
                                            if s and s:IsA("Sound") then s.Volume = 0.5 end
                                        end
                                    end
                                end
                            end
                            RestoreVolume(LocalPlayer.Backpack)
                            if char then RestoreVolume(char) end
                        end
                    end
                })

                HitSoundsSection:Slider({
                    Name = "Volume",
                    Flag = "HitSoundsVolume",
                    Min = 0,
                    Max = 3,
                    Default = 1,
                    Decimals = 1,
                    Callback = function(v) HitSoundState.Volume = v end
                })

                HitSoundsSection:Dropdown({
                    Name = "Sound",
                    Flag = "HitSoundsSound",
                    Default = "rust.mp3",
                    Multi = false,
                    Items = {"12.mp3", "agpa2.mp3", "basshit.mp3", "bell.mp3", "blizzard.mp3", "bubble.mp3", "chockpro.mp3", "cod.mp3", "copperbell.mp3", "crowbar.mp3", "headshot.mp3", "knob.mp3", "minecraft orb.mp3", "neverlose.mp3", "rust.mp3", "skeet.mp3"},
                    Callback = function(v) HitSoundState.Sound = v end
                })

                HitSoundsSection:Button():Add("Preview", function()
                    PlayHitSound()
                end)
            end

            local KillSoundsSection = HitSoundsSubPage:Section({Name = "Kill Sounds", Side = 2}) do
                KillSoundsSection:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "Kill Sounds",
                        Description = "Plays a custom sound when you eliminate a player"
                    },
                    Flag = "KillSoundsEnabled",
                    Default = false,
                    Callback = function(v) KillSoundState.Enabled = v end
                })

                KillSoundsSection:Slider({
                    Name = "Volume",
                    Flag = "KillSoundsVolume",
                    Min = 0,
                    Max = 3,
                    Default = 1,
                    Decimals = 1,
                    Callback = function(v) KillSoundState.Volume = v end
                })

                KillSoundsSection:Dropdown({
                    Name = "Sound",
                    Flag = "KillSoundsSound",
                    Default = "minecraft orb.mp3",
                    Multi = false,
                    Items = {"12.mp3", "agpa2.mp3", "basshit.mp3", "bell.mp3", "blizzard.mp3", "bubble.mp3", "chockpro.mp3", "cod.mp3", "copperbell.mp3", "crowbar.mp3", "headshot.mp3", "knob.mp3", "minecraft orb.mp3", "neverlose.mp3", "rust.mp3", "skeet.mp3"},
                    Callback = function(v) KillSoundState.Sound = v end
                })

                KillSoundsSection:Button():Add("Preview", function()
                    PlayKillSound()
                end)
            end
        end
    end

    do
        do
            local NoclipSection = MovementPage:Section({Name = "Noclip", Side = 1}) do
                local NoclipEnabled = NoclipSection:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "Noclip",
                        Description = "Walk through walls, floors, and all solid objects"
                    },
                    Flag = "NoclipEnabled",
                    Default = false
                }) do
                    local Players = game:GetService("Players")
                    local LocalPlayer = Players.LocalPlayer
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")

                    local scriptsFolder = ReplicatedStorage:FindFirstChild("Scripts")
                    if scriptsFolder then
                        local CharacterCollision = scriptsFolder:FindFirstChild("CharacterCollision")
                        if CharacterCollision then
                            CharacterCollision:Destroy()
                        end
                    end

                    local function SetupNoclip(Character)
                        local Head = Character:WaitForChild("Head")
                        task.spawn(function()
                            for _, Connection in getconnections(Head:GetPropertyChangedSignal("CanCollide")) do
                                Connection:Disable()
                            end
                        end)
                    end

                    TrackConnection(LocalPlayer.CharacterAdded:Connect(SetupNoclip))
                    if LocalPlayer.Character then
                        SetupNoclip(LocalPlayer.Character)
                    end

                    TrackConnection(game.RunService.Stepped:Connect(function()
                        if NoclipEnabled:Get() == true then
                            local character = LocalPlayer.Character
                            if not character then return end
                            for _, part in pairs(character:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = false
                                end
                            end
                        end
                    end))
                end
            end

            local InfJumpSection = MovementPage:Section({Name = "Infinite Jump", Side = 2}) do
                local InfJumpEnabled = InfJumpSection:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "Infinite Jump",
                        Description = "Jump in mid-air without needing to touch the ground"
                    },
                    Flag = "InfJumpEnabled",
                    Default = false
                }) do
                    local LocalPlayer = game:GetService("Players").LocalPlayer
                    local UserInputService = game:GetService("UserInputService")
                    local infJumpConn = nil
                    local debounce = false

                    local function EnableInfJump()
                        if infJumpConn then return end
                        infJumpConn = UserInputService.JumpRequest:Connect(function()
                            if not debounce then
                                debounce = true
                                local character = LocalPlayer.Character
                                if character then
                                    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
                                    if humanoid then
                                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                end
                                task.wait()
                                debounce = false
                            end
                        end)
                    end

                    local function DisableInfJump()
                        if infJumpConn then
                            infJumpConn:Disconnect()
                            infJumpConn = nil
                        end
                        debounce = false
                    end

                    NewRender(function()
                        if InfJumpEnabled:Get() == true then
                            EnableInfJump()
                        else
                            DisableInfJump()
                        end
                    end)
                end
            end
        end
    end
    
    do
        local ESPSubPage = VisualsPage:SubPage({Name = "ESP", Columns = 2})

        do
            local ESPFilterState = {
                Teams = {},
                InmateTypes = {},
                Whitelist = {},
                Blacklist = {},
                FriendCheck = false,
                WhitelistMode = "Hide ESP"
            }

            local function GetInmateStatusESP(Character)
                local humanoid = Character:FindFirstChildOfClass("Humanoid")
                if not humanoid then return "Regular" end
                local displayName = humanoid.DisplayName
                if string.sub(displayName, 1, 4) == "\xF0\x9F\x94\x97" then
                    return "Arrestable"
                elseif string.sub(displayName, 1, 4) == "\xF0\x9F\x92\xA2" then
                    return "Aggressive"
                end
                return "Regular"
            end

            local function IsWhitelisted(Player)
                if ESPFilterState.Whitelist[Player.Name] then return true end
                if ESPFilterState.FriendCheck and FriendsCache[Player.Name] then return true end
                return false
            end

            local function IsBlacklisted(Player)
                return ESPFilterState.Blacklist[Player.Name] == true or AutoBlacklistSet[Player.Name] == true
            end

            local function ShouldShowPlayer(Player)
                if IsBlacklisted(Player) then
                    local myTeam = game.Players.LocalPlayer.Team
                    local myTeamName = myTeam and myTeam.Name or ""
                    local theirTeamName = Player.Team and Player.Team.Name or ""
                    if theirTeamName == myTeamName and theirTeamName ~= "Inmates" then
                        -- same non-inmate team, can't damage -- fall through to normal filters
                    elseif theirTeamName == "Inmates" then
                        local Character = Player.Character
                        if Character and GetInmateStatusESP(Character) == "Regular" then
                            -- innocent inmate, can't damage -- fall through to normal filters
                        else
                            return true
                        end
                    else
                        return true
                    end
                end
                if IsWhitelisted(Player) then
                    if ESPFilterState.WhitelistMode == "Hide ESP" then
                        return false
                    end
                end
                local TeamName = Player.Team and Player.Team.Name or ""
                if next(ESPFilterState.Teams) and not ESPFilterState.Teams[TeamName] then
                    return false
                end
                if TeamName == "Inmates" and next(ESPFilterState.InmateTypes) then
                    local Character = Player.Character
                    if Character then
                        local Status = GetInmateStatusESP(Character)
                        if not ESPFilterState.InmateTypes[Status] then
                            return false
                        end
                    end
                end
                return true
            end

            local ESPState

            local function GetDisplayName(Character)
                local humanoid = Character:FindFirstChildOfClass("Humanoid")
                if not humanoid then return Character.Name end
                local prefix = ""
                if Character:FindFirstChild("ForceField") then
                    prefix = "[FF] "
                end

                if ESPState.InmateStatus then
                    local dn = humanoid.DisplayName
                    if string.sub(dn, 1, 4) == "\xF0\x9F\x94\x97" then
                        prefix = prefix .. "[W] "
                    elseif string.sub(dn, 1, 4) == "\xF0\x9F\x92\xA2" then
                        prefix = prefix .. "[A] "
                    end
                end

                local player = game.Players:GetPlayerFromCharacter(Character)
                local username = Character.Name
                local realDisplayName = player and player.DisplayName or username

                local fmt = ESPState.NameFormat
                if fmt == "Display Name" then
                    return prefix .. realDisplayName
                elseif fmt == "Display Name (@Username)" then
                    if realDisplayName == username then
                        return prefix .. username
                    end
                    return prefix .. realDisplayName .. " (@" .. username .. ")"
                end
                return prefix .. username
            end

            local ESPFilters = ESPSubPage:Section({Name = "Filters", Side = 1}) do
                ESPFilters:Dropdown({
                    Name = "Teams",
                    Flag = "ESPFilterTeams",
                    Multi = true,
                    Items = {"Guards", "Inmates", "Criminals"},
                    Callback = function(v)
                        local set = {}
                        for _, name in pairs(v) do set[name] = true end
                        ESPFilterState.Teams = set
                    end
                })

                ESPFilters:Dropdown({
                    Name = "Inmate Types",
                    Flag = "ESPFilterInmateTypes",
                    Multi = true,
                    Items = {"Regular", "Aggressive", "Arrestable"},
                    Callback = function(v)
                        local set = {}
                        for _, name in pairs(v) do set[name] = true end
                        ESPFilterState.InmateTypes = set
                    end
                })

                ESPFilters:Toggle({
                    Name = "Friend Check",
                    ToolTip = {
                        Name = "Friend Check",
                        Description = "Applies whitelist behavior to players on your Roblox friends list"
                    },
                    Flag = "ESPFriendCheck",
                    Default = false,
                    Callback = function(v) ESPFilterState.FriendCheck = v end
                })

                local playerNames = {}
                for _, p in pairs(game:GetService("Players"):GetPlayers()) do
                    if p ~= game.Players.LocalPlayer then
                        table.insert(playerNames, p.Name)
                    end
                end

                local WhitelistDropdown = ESPFilters:Dropdown({
                    Name = "Whitelist",
                    Flag = "ESPWhitelist",
                    Multi = true,
                    Items = playerNames,
                    Callback = function(v)
                        local set = {}
                        for _, name in pairs(v) do set[name] = true end
                        ESPFilterState.Whitelist = set
                    end
                })

                local ESPBlacklistDropdown = ESPFilters:Dropdown({
                    Name = "Blacklist",
                    ToolTip = { Name = "Blacklist", Description = "Always show these players on ESP with criminal color, regardless of team or filter settings" },
                    Flag = "ESPBlacklist",
                    Multi = true,
                    Items = playerNames,
                    Callback = function(v)
                        local set = {}
                        for _, name in pairs(v) do set[name] = true end
                        ESPFilterState.Blacklist = set
                    end
                })

                TrackConnection(game:GetService("Players").PlayerAdded:Connect(function(p)
                    WhitelistDropdown:Add(p.Name)
                    ESPBlacklistDropdown:Add(p.Name)
                end))
                TrackConnection(game:GetService("Players").PlayerRemoving:Connect(function(p)
                    WhitelistDropdown:Remove(p.Name)
                    ESPBlacklistDropdown:Remove(p.Name)
                end))

                ESPFilters:Dropdown({
                    Name = "Whitelist Mode",
                    Flag = "ESPWhitelistMode",
                    Multi = false,
                    Default = "Hide ESP",
                    Items = {"Hide ESP", "Show Green"},
                    Callback = function(v) ESPFilterState.WhitelistMode = v end
                })
            end

            ESPState = {
                Enabled = false,
                ShowSelf = false,
                TeamColor = true,
                Color = Library.Theme.Accent,
                Outline = true,
                Name = false,
                InmateStatus = true,
                NameFormat = "Username",
                Box = false,
                Skeleton = false,
                Chams = false,
                ChamsColor = Library.Theme.Accent,
                ChamsFillTransparency = 0.75,
                ChamsOutlineTransparency = 0,
                HealthBar = false,
                HealthBarSide = "Left",
            }

            local ActiveHighlights = {}
            local ChamsFolder = Instance.new("Folder")
            ChamsFolder.Name = "catnipChams"
            ChamsFolder.Parent = game:GetService("CoreGui")

            local ESPSection = ESPSubPage:Section({Name = "ESP", Side = 2}) do
                ESPSection:Toggle({
                    Name = "Enabled",
                    ToolTip = { Name = "ESP", Description = "Master toggle for all ESP components (name, box, skeleton, chams, health bar)" },
                    Flag = "ESPEnabled",
                    Default = false,
                    Callback = function(v) ESPState.Enabled = v end
                })

                ESPSection:Toggle({
                    Name = "Name",
                    ToolTip = { Name = "Name ESP", Description = "Shows player names floating above their heads through walls" },
                    Flag = "ESPName",
                    Default = false,
                    Callback = function(v) ESPState.Name = v end
                })

                ESPSection:Toggle({
                    Name = "Inmate Status",
                    ToolTip = { Name = "Inmate Status", Description = "Prefixes names with [W] for wanted or [A] for aggressive inmates" },
                    Flag = "ESPInmateStatus",
                    Default = true,
                    Callback = function(v) ESPState.InmateStatus = v end
                })

                ESPSection:Dropdown({
                    Name = "Name Format",
                    ToolTip = { Name = "Name Format", Description = "Choose how player names appear on ESP" },
                    Flag = "ESPNameFormat",
                    Multi = false,
                    Default = "Username",
                    Items = {"Username", "Display Name", "Display Name (@Username)"},
                    Callback = function(v) ESPState.NameFormat = v end
                })

                ESPSection:Toggle({
                    Name = "Box",
                    ToolTip = { Name = "Box ESP", Description = "Draws 2D bounding boxes around players visible through walls" },
                    Flag = "ESPBox",
                    Default = false,
                    Callback = function(v) ESPState.Box = v end
                })

                ESPSection:Toggle({
                    Name = "Skeleton",
                    ToolTip = { Name = "Skeleton ESP", Description = "Draws simplified skeleton lines connecting head, torso, hands and feet" },
                    Flag = "ESPSkeleton",
                    Default = false,
                    Callback = function(v) ESPState.Skeleton = v end
                })

                ESPSection:Toggle({
                    Name = "Chams",
                    ToolTip = { Name = "Chams", Description = "Highlights player models with a colored overlay visible through walls" },
                    Flag = "ESPChams",
                    Default = false,
                    Callback = function(v) ESPState.Chams = v end
                }):Colorpicker({
                    Name = "Chams Color",
                    Flag = "ESPChamsColor",
                    Default = Library.Theme.Accent,
                    Alpha = 0,
                    Callback = function(v) ESPState.ChamsColor = v end
                })

                ESPSection:Slider({
                    Name = "Chams Fill Transparency",
                    Flag = "ESPChamsFillTransparency",
                    Default = 0.75,
                    Min = 0,
                    Max = 1,
                    Decimals = 0.01,
                    Callback = function(v) ESPState.ChamsFillTransparency = v end
                })

                ESPSection:Toggle({
                    Name = "Health Bar",
                    ToolTip = { Name = "Health Bar", Description = "Draws a vertical health bar next to the bounding box, green at full HP fading to red" },
                    Flag = "ESPHealthBar",
                    Default = false,
                    Callback = function(v) ESPState.HealthBar = v end
                })

                ESPSection:Dropdown({
                    Name = "Health Bar Side",
                    Flag = "ESPHealthBarSide",
                    Default = "Left",
                    Multi = false,
                    Items = {"Left", "Right"},
                    Callback = function(v) ESPState.HealthBarSide = v end
                })

                ESPSection:Toggle({
                    Name = "Team Color",
                    Flag = "ESPTeamColor",
                    Default = true,
                    Callback = function(v) ESPState.TeamColor = v end
                }):Colorpicker({
                    Name = "Color",
                    Flag = "ESPColor",
                    Default = Library.Theme.Accent,
                    Alpha = 0,
                    Callback = function(v) ESPState.Color = v end
                })

                ESPSection:Toggle({
                    Name = "Show Self",
                    Flag = "ESPShowSelf",
                    Default = false,
                    Callback = function(v) ESPState.ShowSelf = v end
                })

                ESPSection:Toggle({
                    Name = "Outline",
                    ToolTip = { Name = "Outline", Description = "Adds a dark outline to name text and box drawings for readability" },
                    Flag = "ESPOutline",
                    Default = true,
                    Callback = function(v) ESPState.Outline = v end
                }) do
                    local SKELETON_LINKS = {
                        {"Torso", "Head"},
                        {"Torso", "Left Arm"},
                        {"Torso", "Right Arm"},
                        {"Torso", "Left Leg"},
                        {"Torso", "Right Leg"},
                    }

                    local function HideAll(drawings, highlight)
                        drawings.Text.Visible = false
                        drawings.Box.Visible = false
                        drawings.BoxOutline.Visible = false
                        for i = 1, 5 do drawings.Skeleton[i].Visible = false end
                        drawings.HealthBG.Visible = false
                        drawings.HealthFill.Visible = false
                        if highlight then highlight.Enabled = false end
                    end

                    local function Apply(Character)
                        local Player = game.Players:GetPlayerFromCharacter(Character)
                        if not Player then return end

                        local Text = TrackDrawing(Drawing.new("Text"))
                        Text.Visible = false
                        Text.ZIndex = 5
                        Text.Size = 12
                        Text.Center = true
                        Text.OutlineColor = Color3.fromRGB(0, 0, 0)

                        local Box = TrackDrawing(Drawing.new("Square"))
                        Box.Visible = false
                        Box.ZIndex = 2
                        Box.Filled = false
                        Box.Thickness = 1

                        local BoxOutline = TrackDrawing(Drawing.new("Square"))
                        BoxOutline.Visible = false
                        BoxOutline.Thickness = 3
                        BoxOutline.ZIndex = 1
                        BoxOutline.Color = Color3.fromRGB(0, 0, 0)
                        BoxOutline.Filled = false

                        local SkeletonLines = {}
                        for i = 1, 5 do
                            local line = TrackDrawing(Drawing.new("Line"))
                            line.Visible = false
                            line.Thickness = 1
                            line.ZIndex = 3
                            SkeletonLines[i] = line
                        end

                        local HealthBG = TrackDrawing(Drawing.new("Line"))
                        HealthBG.Visible = false
                        HealthBG.Thickness = 4
                        HealthBG.ZIndex = 1
                        HealthBG.Color = Color3.fromRGB(0, 0, 0)

                        local HealthFill = TrackDrawing(Drawing.new("Line"))
                        HealthFill.Visible = false
                        HealthFill.Thickness = 2
                        HealthFill.ZIndex = 2

                        local Highlight = Instance.new("Highlight")
                        Highlight.Name = Player.Name
                        Highlight.Adornee = Character
                        Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        Highlight.Enabled = false
                        Highlight.Parent = ChamsFolder
                        ActiveHighlights[Character] = Highlight

                        local drawings = {
                            Text = Text,
                            Box = Box,
                            BoxOutline = BoxOutline,
                            Skeleton = SkeletonLines,
                            HealthBG = HealthBG,
                            HealthFill = HealthFill,
                        }

                        local Render = NewRender(function()
                            if not ESPState.Enabled then
                                HideAll(drawings, Highlight)
                                return
                            end

                            local isSelf = Character == game.Players.LocalPlayer.Character
                            if isSelf and not ESPState.ShowSelf then
                                HideAll(drawings, Highlight)
                                return
                            end

                            if not ShouldShowPlayer(Player) then
                                HideAll(drawings, Highlight)
                                return
                            end

                            local hrp = Character:FindFirstChild("HumanoidRootPart")
                            if not hrp then HideAll(drawings, Highlight) return end
                            local hum = Character:FindFirstChildOfClass("Humanoid")
                            if not hum or hum.Health <= 0 then HideAll(drawings, Highlight) return end

                            local pos, onscreen = workspace.CurrentCamera:WorldToViewportPoint(hrp.Position)
                            if not onscreen then
                                HideAll(drawings, Highlight)
                                return
                            end

                            local espColor
                            if IsBlacklisted(Player) then
                                espColor = Color3.fromRGB(90, 90, 90)
                            elseif IsWhitelisted(Player) then
                                espColor = Color3.fromRGB(0, 255, 0)
                            elseif ESPState.TeamColor then
                                espColor = Player.TeamColor.Color
                            else
                                espColor = ESPState.Color
                            end

                            local scale = 1 / (pos.Z * math.tan(math.rad(workspace.CurrentCamera.FieldOfView * 0.5)) * 2) * 1000
                            local width, height = math.floor(4.5 * scale), math.floor(6 * scale)
                            local x, y = math.floor(pos.X), math.floor(pos.Y)
                            local xPos, yPos = math.floor(x - width * 0.5), math.floor((y - height * 0.5) + (0.5 * scale))

                            if ESPState.Name then
                                Text.Position = Vector2.new(pos.X, yPos - 14)
                                Text.Text = GetDisplayName(Character)
                                Text.Color = espColor
                                Text.Outline = ESPState.Outline
                                Text.Visible = true
                            else
                                Text.Visible = false
                            end

                            if ESPState.Box then
                                Box.Size = Vector2.new(width, height)
                                Box.Position = Vector2.new(xPos, yPos)
                                Box.Color = espColor
                                Box.Visible = true
                                BoxOutline.Size = Vector2.new(width, height)
                                BoxOutline.Position = Vector2.new(xPos, yPos)
                                BoxOutline.Visible = ESPState.Outline
                            else
                                Box.Visible = false
                                BoxOutline.Visible = false
                            end

                            if ESPState.Skeleton then
                                for i, link in ipairs(SKELETON_LINKS) do
                                    local partA = Character:FindFirstChild(link[1])
                                    local partB = Character:FindFirstChild(link[2])
                                    if partA and partB then
                                        local aPos, aOn = workspace.CurrentCamera:WorldToViewportPoint(partA.Position)
                                        local bPos, bOn = workspace.CurrentCamera:WorldToViewportPoint(partB.Position)
                                        if aOn and bOn then
                                            SkeletonLines[i].From = Vector2.new(aPos.X, aPos.Y)
                                            SkeletonLines[i].To = Vector2.new(bPos.X, bPos.Y)
                                            SkeletonLines[i].Color = espColor
                                            SkeletonLines[i].Visible = true
                                        else
                                            SkeletonLines[i].Visible = false
                                        end
                                    else
                                        SkeletonLines[i].Visible = false
                                    end
                                end
                            else
                                for i = 1, 5 do SkeletonLines[i].Visible = false end
                            end

                            if ESPState.Chams then
                                Highlight.FillColor = ESPState.ChamsColor
                                Highlight.OutlineColor = espColor
                                Highlight.FillTransparency = ESPState.ChamsFillTransparency
                                Highlight.OutlineTransparency = ESPState.ChamsOutlineTransparency
                                Highlight.Enabled = true
                            else
                                Highlight.Enabled = false
                            end

                            if ESPState.HealthBar then
                                local hpRatio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                                local barX
                                if ESPState.HealthBarSide == "Left" then
                                    barX = xPos - 5
                                else
                                    barX = xPos + width + 5
                                end
                                local barTop = yPos
                                local barBot = yPos + height
                                local fillBot = barBot
                                local fillTop = barBot - math.floor(height * hpRatio)

                                HealthBG.From = Vector2.new(barX, barTop)
                                HealthBG.To = Vector2.new(barX, barBot)
                                HealthBG.Visible = true

                                HealthFill.From = Vector2.new(barX, fillTop)
                                HealthFill.To = Vector2.new(barX, fillBot)
                                HealthFill.Color = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), hpRatio)
                                HealthFill.Visible = true
                            else
                                HealthBG.Visible = false
                                HealthFill.Visible = false
                            end
                        end)

                        Character.AncestryChanged:Connect(function(_, parent)
                            if not parent then
                                Render:Disconnect()
                                Text:Destroy()
                                Box:Destroy()
                                BoxOutline:Destroy()
                                for i = 1, 5 do SkeletonLines[i]:Destroy() end
                                HealthBG:Destroy()
                                HealthFill:Destroy()
                                if Highlight then
                                    ActiveHighlights[Character] = nil
                                    Highlight:Destroy()
                                    Highlight = nil
                                end
                            end
                        end)
                    end

                    for _, v in pairs(game:GetService("Players"):GetPlayers()) do
                        if v.Character then Apply(v.Character) end
                        TrackConnection(v.CharacterAdded:Connect(function(char)
                            Apply(char)
                        end))
                    end

                    TrackConnection(game:GetService("Players").PlayerAdded:Connect(function(v)
                        TrackConnection(v.CharacterAdded:Connect(function(char)
                            Apply(char)
                        end))
                    end))
                end
            end

            local ItemESPSection = ESPSubPage:Section({Name = "Item ESP", Side = 2}) do
                ItemESPSection:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "Item ESP",
                        Description = "Draws floating labels on world items, with distance scaling matching player ESP"
                    },
                    Flag = "ItemESPEnabled",
                    Default = false,
                    Callback = function(v) ItemESPState.Enabled = v end
                }):Colorpicker({
                    Name = "Color",
                    Flag = "ItemESPColor",
                    Default = Library.Theme.Accent,
                    Alpha = 0,
                    Callback = function(v) ItemESPState.Color = v end
                })

                ItemESPSection:Dropdown({
                    Name = "Items",
                    ToolTip = { Name = "Items", Description = "Select which world items to show with Item ESP" },
                    Flag = "ItemESPItems",
                    Multi = true,
                    Items = {"M9", "Hammer", "Crude Knife", "Key card"},
                    Callback = function(v)
                        local set = {}
                        for _, name in pairs(v) do set[name] = true end
                        ItemESPState.Items = set
                    end
                })

                ItemESPSection:Toggle({
                    Name = "Chams",
                    ToolTip = { Name = "Item Chams", Description = "Highlights items with a colored overlay visible through walls" },
                    Flag = "ItemESPChams",
                    Default = false,
                    Callback = function(v) ItemESPState.Chams = v end
                }):Colorpicker({
                    Name = "Chams Color",
                    Flag = "ItemESPChamsColor",
                    Default = Library.Theme.Accent,
                    Alpha = 0,
                    Callback = function(v) ItemESPState.ChamsColor = v end
                })

                ItemESPSection:Slider({
                    Name = "Chams Fill Transparency",
                    Flag = "ItemESPChamsFillTransparency",
                    Default = 0.5,
                    Min = 0,
                    Max = 1,
                    Decimals = 0.01,
                    Callback = function(v) ItemESPState.ChamsFillTransparency = v end
                }) do
                    NewRender(function()
                        local character = game.Players.LocalPlayer.Character
                        local hrp = character and character:FindFirstChild("HumanoidRootPart")

                        if not ItemESPState.Enabled or not hrp or not next(ItemESPState.Items) then
                            for _, data in pairs(ItemESPDrawings) do
                                data.Text.Visible = false
                            end
                            for obj, hl in pairs(ItemESPHighlights) do
                                hl.Enabled = false
                            end
                            return
                        end

                        local camera = workspace.CurrentCamera
                        local myPos = hrp.Position
                        local visibleNow = {}

                        for _, obj in pairs(workspace:GetChildren()) do
                            if not ItemESPState.Items[obj.Name] then continue end
                            local part = ResolvePickupPart(obj)
                            if not part then continue end

                            local distance = (myPos - part.Position).Magnitude

                            local screenPos, onScreen = camera:WorldToViewportPoint(part.Position + Vector3.new(0, 1.2, 0))
                            if not onScreen then continue end

                            local scale = 1 / (screenPos.Z * math.tan(math.rad(camera.FieldOfView * 0.5)) * 2) * 1000
                            local textSize = math.clamp(math.floor(12 * (scale / 3.5)), 8, 18)

                            local data = ItemESPDrawings[obj]
                            if not data then
                                local text = TrackDrawing(Drawing.new("Text"))
                                text.Center = true
                                text.ZIndex = 5
                                text.OutlineColor = Color3.fromRGB(0, 0, 0)
                                data = { Text = text }
                                ItemESPDrawings[obj] = data
                            end

                            data.Text.Size = textSize
                            data.Text.Outline = ESPState.Outline
                            data.Text.Text = string.format("%s [%d]", obj.Name, math.floor(distance))
                            data.Text.Color = ItemESPState.Color
                            data.Text.Position = Vector2.new(screenPos.X, screenPos.Y)
                            data.Text.Visible = true
                            visibleNow[obj] = true

                            if ItemESPState.Chams then
                                local hl = ItemESPHighlights[obj]
                                if not hl then
                                    hl = Instance.new("Highlight")
                                    hl.Name = obj.Name
                                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                    hl.Parent = ItemESPChamsFolder
                                    ItemESPHighlights[obj] = hl
                                end
                                hl.Adornee = obj
                                hl.FillColor = ItemESPState.ChamsColor
                                hl.OutlineColor = ItemESPState.ChamsColor
                                hl.FillTransparency = ItemESPState.ChamsFillTransparency
                                hl.OutlineTransparency = 0
                                hl.Enabled = true
                            else
                                local hl = ItemESPHighlights[obj]
                                if hl then hl.Enabled = false end
                            end
                        end

                        for obj, data in pairs(ItemESPDrawings) do
                            if not visibleNow[obj] then
                                data.Text.Visible = false
                                local hl = ItemESPHighlights[obj]
                                if hl then hl.Enabled = false end
                            end
                        end
                    end)

                    RegisterCleanup(function()
                        for _, data in pairs(ItemESPDrawings) do
                            pcall(data.Text.Remove, data.Text)
                        end
                        ItemESPDrawings = {}
                        for _, hl in pairs(ItemESPHighlights) do
                            pcall(hl.Destroy, hl)
                        end
                        ItemESPHighlights = {}
                        pcall(ItemESPChamsFolder.Destroy, ItemESPChamsFolder)
                    end)
                end
            end

            RegisterCleanup(function()
                for char, hl in pairs(ActiveHighlights) do
                    pcall(hl.Destroy, hl)
                end
                ActiveHighlights = {}
                pcall(ChamsFolder.Destroy, ChamsFolder)
            end)
        end
    end

    do
        local CharSubPage = VisualsPage:SubPage({Name = "Character", Columns = 2})

        local FFState = {
            Enabled = false,
            ApplyTo = "Character",
            TeamColor = true,
            Color = Color3.fromRGB(0, 170, 255),
            SelfOnly = true,
        }

        local OriginalMaterials = {}
        local ActivePlayers = {}

        local function ApplyForceField(character, color)
            if not character then return end
            local key = character
            if not OriginalMaterials[key] then OriginalMaterials[key] = {} end

            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    local isWeapon = part:FindFirstAncestorOfClass("Tool") ~= nil
                    local isBody = not isWeapon

                    local shouldApply = false
                    if FFState.ApplyTo == "Character" then shouldApply = isBody
                    elseif FFState.ApplyTo == "Weapon" then shouldApply = isWeapon
                    elseif FFState.ApplyTo == "Both" then shouldApply = true end

                    if shouldApply then
                        if not OriginalMaterials[key][part] then
                            OriginalMaterials[key][part] = {Material = part.Material, Color = part.Color}
                        end
                        part.Material = Enum.Material.ForceField
                        part.Color = color
                    else
                        local orig = OriginalMaterials[key] and OriginalMaterials[key][part]
                        if orig then
                            part.Material = orig.Material
                            part.Color = orig.Color
                            OriginalMaterials[key][part] = nil
                        end
                    end
                end
            end
        end

        local function RevertCharacter(character)
            local key = character
            local saved = OriginalMaterials[key]
            if not saved then return end
            for part, orig in pairs(saved) do
                if part and part.Parent then
                    pcall(function()
                        part.Material = orig.Material
                        part.Color = orig.Color
                    end)
                end
            end
            OriginalMaterials[key] = nil
        end

        local function RevertAll()
            for char, _ in pairs(OriginalMaterials) do
                RevertCharacter(char)
            end
            OriginalMaterials = {}
        end

        local FFSection = CharSubPage:Section({Name = "ForceField Material", Side = 1}) do
            FFSection:Toggle({
                Name = "Enabled",
                ToolTip = { Name = "ForceField Material", Description = "Replaces your character/weapon materials with the ForceField shader" },
                Flag = "FFMatEnabled",
                Default = false,
                Callback = function(v)
                    FFState.Enabled = v
                    if not v then RevertAll() end
                end
            })

            FFSection:Dropdown({
                Name = "Apply To",
                Flag = "FFMatApplyTo",
                Default = "Character",
                Multi = false,
                Items = {"Character", "Weapon", "Both"},
                Callback = function(v)
                    RevertAll()
                    FFState.ApplyTo = v
                end
            })

            FFSection:Toggle({
                Name = "Team Color",
                Flag = "FFMatTeamColor",
                Default = true,
                Callback = function(v) FFState.TeamColor = v end
            }):Colorpicker({
                Name = "Color",
                Flag = "FFMatColor",
                Default = FFState.Color,
                Alpha = 0,
                Callback = function(v) FFState.Color = v end
            })

            FFSection:Toggle({
                Name = "Self Only",
                ToolTip = { Name = "Self Only", Description = "Only apply to your own character. Disable to apply to all players." },
                Flag = "FFMatSelfOnly",
                Default = true,
                Callback = function(v)
                    FFState.SelfOnly = v
                    if v then RevertAll() end
                end
            })
        end

        NewRender(function()
            if not FFState.Enabled then return end

            local Players = game:GetService("Players")
            local lp = Players.LocalPlayer

            if FFState.SelfOnly then
                local char = lp.Character
                if char then
                    local color = FFState.TeamColor and lp.TeamColor.Color or FFState.Color
                    ApplyForceField(char, color)
                end
            else
                for _, player in pairs(Players:GetPlayers()) do
                    local char = player.Character
                    if char then
                        local color = FFState.TeamColor and player.TeamColor.Color or FFState.Color
                        ApplyForceField(char, color)
                    end
                end
            end
        end)

        RegisterCleanup(function()
            RevertAll()
        end)
    end

    do
        local ObjectsSubPage = WorldPage:SubPage({Name = "Objects", Columns = 2})

        local DoorStorage = game:GetService("Lighting")
        local StorageName = "catnipDoorStorage"

        local RemoveDoors = ObjectsSubPage:Section({Name = "Remove Doors", Side = 1}) do
            RemoveDoors:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Remove Doors",
                    Description = "Removes all doors from the map — purely visual, server still has them"
                },
                Flag = "RemoveDoorsEnabled",
                Default = false,
                Callback = function(enabled)
                    if enabled then
                        local Doors = workspace:FindFirstChild("Doors")
                        if not Doors then return end
                        local folder = Instance.new("Folder")
                        folder.Name = StorageName
                        folder.Parent = DoorStorage
                        Doors.Parent = folder
                    else
                        local folder = DoorStorage:FindFirstChild(StorageName)
                        if not folder then return end
                        local Doors = folder:FindFirstChild("Doors")
                        if Doors then Doors.Parent = workspace end
                        folder:Destroy()
                    end
                end
            })
        end

        RegisterCleanup(function()
            local folder = DoorStorage:FindFirstChild(StorageName)
            if folder then
                local Doors = folder:FindFirstChild("Doors")
                if Doors then Doors.Parent = workspace end
                folder:Destroy()
            end
        end)

        local BypassDoors = ObjectsSubPage:Section({Name = "Bypass Doors", Side = 1}) do
            local DummyFolder = nil

            BypassDoors:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Bypass Doors",
                    Description = "Replaces doors with passthrough parts — walk through any door as a guard"
                },
                Flag = "BypassDoorsEnabled",
                Default = false,
                Callback = function(enabled)
                    if enabled then
                        local Doors = workspace:FindFirstChild("Doors")
                        if not Doors then return end

                        DummyFolder = Instance.new("Folder")
                        DummyFolder.Name = "BypassDoorDummies"
                        DummyFolder.Parent = workspace

                        for _, child in pairs(Doors:GetChildren()) do
                            local cf, size
                            if child:IsA("Model") then
                                cf, size = child:GetBoundingBox()
                            elseif child:IsA("BasePart") then
                                cf = child.CFrame
                                size = child.Size
                            else
                                continue
                            end

                            local dummy = Instance.new("Part")
                            dummy.Name = child.Name
                            dummy.Size = size
                            dummy.CFrame = cf
                            dummy.Anchored = true
                            dummy.CanCollide = false
                            dummy.CanTouch = false
                            dummy.Transparency = 0.75
                            dummy.Material = Enum.Material.ForceField
                            dummy.Color = Color3.fromRGB(120, 180, 255)
                            dummy.Parent = DummyFolder
                        end

                        local folder = Instance.new("Folder")
                        folder.Name = StorageName
                        folder.Parent = DoorStorage
                        Doors.Parent = folder
                    else
                        local folder = DoorStorage:FindFirstChild(StorageName)
                        if folder then
                            local Doors = folder:FindFirstChild("Doors")
                            if Doors then Doors.Parent = workspace end
                            folder:Destroy()
                        end

                        if DummyFolder then
                            DummyFolder:Destroy()
                            DummyFolder = nil
                        end
                    end
                end
            })

            RegisterCleanup(function()
                if DummyFolder then
                    DummyFolder:Destroy()
                end
            end)
        end
    end

    do
        local LightingSubPage = WorldPage:SubPage({Name = "Lighting", Columns = 2})
        local Lighting = game:GetService("Lighting")

        local OriginalLighting = {
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
            FogColor = Lighting.FogColor,
            ColorShift_Top = Lighting.ColorShift_Top,
            ColorShift_Bottom = Lighting.ColorShift_Bottom,
        }

        local OriginalSky = nil
        local ManagedSky = nil

        do
            local sky = Lighting:FindFirstChildOfClass("Sky")
            if sky then
                OriginalSky = {
                    SkyboxBk = sky.SkyboxBk,
                    SkyboxDn = sky.SkyboxDn,
                    SkyboxFt = sky.SkyboxFt,
                    SkyboxLf = sky.SkyboxLf,
                    SkyboxRt = sky.SkyboxRt,
                    SkyboxUp = sky.SkyboxUp,
                    StarCount = sky.StarCount,
                    CelestialBodiesShown = sky.CelestialBodiesShown,
                }
            end
        end

        local SkyboxList = {}
        local SkyboxNames = {"Default"}
        do
            local ok, raw = pcall(function()
                if isfile("catnip/skyboxes.json") then
                    return readfile("catnip/skyboxes.json")
                end
                return nil
            end)
            if ok and raw then
                local decoded = game:GetService("HttpService"):JSONDecode(raw)
                if type(decoded) == "table" then
                    for _, entry in decoded do
                        if entry.Name and entry.Name ~= "None" then
                            table.insert(SkyboxList, entry)
                            table.insert(SkyboxNames, entry.Name)
                        end
                    end
                end
            end
        end

        local LightState = {
            AmbientOverride = false,
            OutdoorAmbientOverride = false,
            BrightnessOverride = false,
            ClockTimeOverride = false,
            FogOverride = false,
            ColorShiftOverride = false,
            RemoveFog = false,
            SkyboxChoice = "Default",
            Fullbright = false,

            AmbientColor = OriginalLighting.Ambient,
            OutdoorAmbientColor = OriginalLighting.OutdoorAmbient,
            BrightnessValue = OriginalLighting.Brightness,
            ClockTimeValue = OriginalLighting.ClockTime,
            FogColor = OriginalLighting.FogColor,
            FogStart = OriginalLighting.FogStart,
            FogEnd = math.min(OriginalLighting.FogEnd, 5000),
            ColorShiftTop = OriginalLighting.ColorShift_Top,
            ColorShiftBottom = OriginalLighting.ColorShift_Bottom,
        }

        local AmbientSection = LightingSubPage:Section({Name = "Ambient & Brightness", Side = 1}) do
            AmbientSection:Toggle({
                Name = "Override Ambient",
                ToolTip = { Name = "Override Ambient", Description = "Override the indoor ambient lighting color" },
                Flag = "LightAmbientOverride",
                Default = false,
                Callback = function(v) LightState.AmbientOverride = v end
            }):Colorpicker({
                Name = "Ambient Color",
                Flag = "LightAmbientColor",
                Default = OriginalLighting.Ambient,
                Alpha = 0,
                Callback = function(v) LightState.AmbientColor = v end
            })

            AmbientSection:Toggle({
                Name = "Override Outdoor Ambient",
                ToolTip = { Name = "Override Outdoor Ambient", Description = "Override the outdoor ambient lighting color" },
                Flag = "LightOutdoorAmbientOverride",
                Default = false,
                Callback = function(v) LightState.OutdoorAmbientOverride = v end
            }):Colorpicker({
                Name = "Outdoor Ambient Color",
                Flag = "LightOutdoorAmbientColor",
                Default = OriginalLighting.OutdoorAmbient,
                Alpha = 0,
                Callback = function(v) LightState.OutdoorAmbientColor = v end
            })

            AmbientSection:Toggle({
                Name = "Override Brightness",
                ToolTip = { Name = "Override Brightness", Description = "Override the scene brightness value" },
                Flag = "LightBrightnessOverride",
                Default = false,
                Callback = function(v) LightState.BrightnessOverride = v end
            })

            AmbientSection:Slider({
                Name = "Brightness",
                Flag = "LightBrightnessValue",
                Default = OriginalLighting.Brightness,
                Min = 0,
                Max = 10,
                Decimals = 0.1,
                Callback = function(v) LightState.BrightnessValue = v end
            })

            AmbientSection:Toggle({
                Name = "Fullbright",
                ToolTip = { Name = "Fullbright", Description = "Maxes out ambient and brightness so everything is fully lit with no shadows" },
                Flag = "LightFullbright",
                Default = false,
                Callback = function(v) LightState.Fullbright = v end
            })
        end

        local TimeSection = LightingSubPage:Section({Name = "Time of Day", Side = 1}) do
            TimeSection:Toggle({
                Name = "Override Clock Time",
                ToolTip = { Name = "Override Clock Time", Description = "Freeze the in-game time to a custom value" },
                Flag = "LightClockTimeOverride",
                Default = false,
                Callback = function(v) LightState.ClockTimeOverride = v end
            })

            TimeSection:Slider({
                Name = "Clock Time",
                Flag = "LightClockTimeValue",
                Default = OriginalLighting.ClockTime,
                Min = 0,
                Max = 24,
                Decimals = 0.1,
                Suffix = "h",
                Callback = function(v) LightState.ClockTimeValue = v end
            })
        end

        local FogSection = LightingSubPage:Section({Name = "Fog", Side = 2}) do
            FogSection:Toggle({
                Name = "Override Fog",
                ToolTip = { Name = "Override Fog", Description = "Override fog distance and color" },
                Flag = "LightFogOverride",
                Default = false,
                Callback = function(v) LightState.FogOverride = v end
            }):Colorpicker({
                Name = "Fog Color",
                Flag = "LightFogColor",
                Default = OriginalLighting.FogColor,
                Alpha = 0,
                Callback = function(v) LightState.FogColor = v end
            })

            FogSection:Slider({
                Name = "Fog Start",
                Flag = "LightFogStartValue",
                Default = OriginalLighting.FogStart,
                Min = 0,
                Max = 5000,
                Decimals = 1,
                Callback = function(v) LightState.FogStart = v end
            })

            FogSection:Slider({
                Name = "Fog End",
                Flag = "LightFogEndValue",
                Default = math.min(OriginalLighting.FogEnd, 5000),
                Min = 0,
                Max = 5000,
                Decimals = 1,
                Callback = function(v) LightState.FogEnd = v end
            })

            FogSection:Toggle({
                Name = "Remove Fog",
                ToolTip = { Name = "Remove Fog", Description = "Push fog distance to infinity, effectively removing it" },
                Flag = "LightRemoveFog",
                Default = false,
                Callback = function(v) LightState.RemoveFog = v end
            })
        end

        local function applySkybox(data)
            local sky = Lighting:FindFirstChildOfClass("Sky")
            if not sky then
                if not ManagedSky then
                    ManagedSky = Instance.new("Sky")
                    ManagedSky.Name = "catnipSky"
                    ManagedSky.Parent = Lighting
                end
                sky = ManagedSky
            end
            sky.SkyboxBk = data.SkyboxBk
            sky.SkyboxDn = data.SkyboxDn
            sky.SkyboxFt = data.SkyboxFt
            sky.SkyboxLf = data.SkyboxLf
            sky.SkyboxRt = data.SkyboxRt
            sky.SkyboxUp = data.SkyboxUp
        end

        local function restoreSkybox()
            if ManagedSky then
                ManagedSky:Destroy()
                ManagedSky = nil
            end
            local sky = Lighting:FindFirstChildOfClass("Sky")
            if sky and OriginalSky then
                sky.SkyboxBk = OriginalSky.SkyboxBk
                sky.SkyboxDn = OriginalSky.SkyboxDn
                sky.SkyboxFt = OriginalSky.SkyboxFt
                sky.SkyboxLf = OriginalSky.SkyboxLf
                sky.SkyboxRt = OriginalSky.SkyboxRt
                sky.SkyboxUp = OriginalSky.SkyboxUp
            end
        end

        local CustomSkyIds = { Bk = "", Dn = "", Ft = "", Lf = "", Rt = "", Up = "" }

        local function applyCustomSky()
            local hasAny = false
            for _, v in CustomSkyIds do
                if v ~= "" then hasAny = true break end
            end
            if not hasAny then return end
            applySkybox({
                SkyboxBk = CustomSkyIds.Bk,
                SkyboxDn = CustomSkyIds.Dn,
                SkyboxFt = CustomSkyIds.Ft,
                SkyboxLf = CustomSkyIds.Lf,
                SkyboxRt = CustomSkyIds.Rt,
                SkyboxUp = CustomSkyIds.Up,
            })
        end

        local function normalizeAssetId(input)
            input = tostring(input):match("^%s*(.-)%s*$")
            if input == "" then return "" end
            if input:match("^rbxasset") then return input end
            local id = input:match("%d+")
            if id then return "rbxassetid://" .. id end
            return input
        end

        table.insert(SkyboxNames, "Custom")

        local SkySection = LightingSubPage:Section({Name = "Sky & Color Shift", Side = 2}) do
            SkySection:Dropdown({
                Name = "Skybox",
                ToolTip = { Name = "Custom Skybox", Description = "Pick a preset, or select 'Custom' and enter your own asset IDs below" },
                Flag = "LightSkyboxChoice",
                Default = "Default",
                Items = SkyboxNames,
                Callback = function(v)
                    LightState.SkyboxChoice = v
                    if v == "Default" then
                        restoreSkybox()
                        return
                    end
                    if v == "Custom" then
                        applyCustomSky()
                        return
                    end
                    for _, entry in SkyboxList do
                        if entry.Name == v then applySkybox(entry) return end
                    end
                end
            })

            SkySection:Textbox({
                Name = "All Faces ID",
                ToolTip = { Name = "All Faces", Description = "Paste a single asset ID to apply to all 6 skybox faces at once. Press Enter to apply." },
                Flag = "CustomSkyAllFaces",
                Placeholder = "rbxassetid://...",
                Finished = true,
                Callback = function(v)
                    local id = normalizeAssetId(v)
                    if id == "" then return end
                    for k in CustomSkyIds do CustomSkyIds[k] = id end
                    if LightState.SkyboxChoice == "Custom" then applyCustomSky() end
                end
            })

            SkySection:Textbox({
                Name = "Front",
                Flag = "CustomSkyFt",
                Placeholder = "rbxassetid://...",
                Finished = true,
                Callback = function(v)
                    CustomSkyIds.Ft = normalizeAssetId(v)
                    if LightState.SkyboxChoice == "Custom" then applyCustomSky() end
                end
            })

            SkySection:Textbox({
                Name = "Back",
                Flag = "CustomSkyBk",
                Placeholder = "rbxassetid://...",
                Finished = true,
                Callback = function(v)
                    CustomSkyIds.Bk = normalizeAssetId(v)
                    if LightState.SkyboxChoice == "Custom" then applyCustomSky() end
                end
            })

            SkySection:Textbox({
                Name = "Left",
                Flag = "CustomSkyLf",
                Placeholder = "rbxassetid://...",
                Finished = true,
                Callback = function(v)
                    CustomSkyIds.Lf = normalizeAssetId(v)
                    if LightState.SkyboxChoice == "Custom" then applyCustomSky() end
                end
            })

            SkySection:Textbox({
                Name = "Right",
                Flag = "CustomSkyRt",
                Placeholder = "rbxassetid://...",
                Finished = true,
                Callback = function(v)
                    CustomSkyIds.Rt = normalizeAssetId(v)
                    if LightState.SkyboxChoice == "Custom" then applyCustomSky() end
                end
            })

            SkySection:Textbox({
                Name = "Up",
                Flag = "CustomSkyUp",
                Placeholder = "rbxassetid://...",
                Finished = true,
                Callback = function(v)
                    CustomSkyIds.Up = normalizeAssetId(v)
                    if LightState.SkyboxChoice == "Custom" then applyCustomSky() end
                end
            })

            SkySection:Textbox({
                Name = "Down",
                Flag = "CustomSkyDn",
                Placeholder = "rbxassetid://...",
                Finished = true,
                Callback = function(v)
                    CustomSkyIds.Dn = normalizeAssetId(v)
                    if LightState.SkyboxChoice == "Custom" then applyCustomSky() end
                end
            })

            SkySection:Toggle({
                Name = "Override Color Shift",
                ToolTip = { Name = "Override Color Shift", Description = "Override the top and bottom color shift tinting" },
                Flag = "LightColorShiftOverride",
                Default = false,
                Callback = function(v) LightState.ColorShiftOverride = v end
            }):Colorpicker({
                Name = "Top",
                Flag = "LightColorShiftTop",
                Default = OriginalLighting.ColorShift_Top,
                Alpha = 0,
                Callback = function(v) LightState.ColorShiftTop = v end
            })

            SkySection:Toggle({
                Name = "Color Shift Bottom",
                Flag = "LightColorShiftBottomToggle",
                Default = false,
                Callback = function() end
            }):Colorpicker({
                Name = "Bottom",
                Flag = "LightColorShiftBottom",
                Default = OriginalLighting.ColorShift_Bottom,
                Alpha = 0,
                Callback = function(v) LightState.ColorShiftBottom = v end
            })
        end

        NewRender(function()
            if LightState.Fullbright then
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
                Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                Lighting.Brightness = 2
                Lighting.FogEnd = 1e9
                Lighting.FogStart = 1e9
                Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
                Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
                return
            end

            if LightState.AmbientOverride then
                Lighting.Ambient = LightState.AmbientColor
            end
            if LightState.OutdoorAmbientOverride then
                Lighting.OutdoorAmbient = LightState.OutdoorAmbientColor
            end
            if LightState.BrightnessOverride then
                Lighting.Brightness = LightState.BrightnessValue
            end
            if LightState.ClockTimeOverride then
                Lighting.ClockTime = LightState.ClockTimeValue
            end

            if LightState.RemoveFog then
                Lighting.FogEnd = 1e9
                Lighting.FogStart = 1e9
            elseif LightState.FogOverride then
                Lighting.FogStart = LightState.FogStart
                Lighting.FogEnd = LightState.FogEnd
                Lighting.FogColor = LightState.FogColor
            end

            if LightState.ColorShiftOverride then
                Lighting.ColorShift_Top = LightState.ColorShiftTop
                Lighting.ColorShift_Bottom = LightState.ColorShiftBottom
            end
        end)

        RegisterCleanup(function()
            Lighting.Ambient = OriginalLighting.Ambient
            Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
            Lighting.Brightness = OriginalLighting.Brightness
            Lighting.ClockTime = OriginalLighting.ClockTime
            Lighting.FogEnd = OriginalLighting.FogEnd
            Lighting.FogStart = OriginalLighting.FogStart
            Lighting.FogColor = OriginalLighting.FogColor
            Lighting.ColorShift_Top = OriginalLighting.ColorShift_Top
            Lighting.ColorShift_Bottom = OriginalLighting.ColorShift_Bottom
            restoreSkybox()
        end)
    end

    do
        local PingWarning = MiscPage:Section({Name = "Ping Warning", Side = 2}) do
            PingWarning:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Ping Warning",
                    Description = "Notifies you when your ping exceeds 300ms"
                },
                Flag = "PingWarningEnabled",
                Default = false,
                Callback = function(v) PingWarningEnabled = v end
            })
        end
    end

    do
        local KillfeedNotifications = MiscPage:Section({Name = "Killfeed Notifications", Side = 2}) do
            KillfeedNotifications:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Killfeed Notifications",
                    Description = "Shows a notification for every new killfeed entry"
                },
                Flag = "KillfeedNotificationsEnabled",
                Default = false,
                Callback = function(v) KillfeedNotificationsEnabled = v end
            })
        end
    end

    do
        local AutoBLSection = MiscPage:Section({Name = "Auto Blacklist", Side = 2}) do
            local AutoBLState = { Enabled = false }

            local function ExtractKillerUsername(entryText)
                local killPos = string.find(entryText, " killed ", 1, true)
                if not killPos then return nil end
                local killerText = string.sub(entryText, 1, killPos - 1)
                local username = string.match(killerText, "@([%w_]+)%)")
                return username
            end

            local function ExtractVictimUsername(entryText)
                local killPos = string.find(entryText, " killed ", 1, true)
                if not killPos then return nil end
                local afterKill = string.sub(entryText, killPos + 8)
                local username = string.match(afterKill, "@([%w_]+)%)")
                return username
            end

            AutoBLSection:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Auto Blacklist",
                    Description = "When you die as a criminal, automatically blacklists the inmate who killed you. Uses killfeed for accuracy."
                },
                Flag = "AutoBlacklistEnabled",
                Default = false,
                Callback = function(v) AutoBLState.Enabled = v end
            })

            local KillfeedFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Killfeed")
            if KillfeedFolder then
                TrackConnection(KillfeedFolder.ChildAdded:Connect(function(entry)
                    if not entry:IsA("IntValue") then return end
                    if not AutoBLState.Enabled then return end

                    local lp = game.Players.LocalPlayer
                    local myTeam = lp.Team and lp.Team.Name or ""
                    if myTeam ~= "Criminals" then return end

                    local entryText = entry.Name
                    local victimName = ExtractVictimUsername(entryText)
                    if victimName ~= lp.Name then return end

                    local killerName = ExtractKillerUsername(entryText)
                    if not killerName or killerName == lp.Name then return end

                    local killer = game.Players:FindFirstChild(killerName)
                    if not killer then return end
                    local killerTeam = killer.Team and killer.Team.Name or ""
                    if killerTeam ~= "Inmates" then return end

                    if not AutoBlacklistSet[killerName] then
                        AutoBlacklistSet[killerName] = true
                        Library:Notification({
                            Title = "Auto Blacklist",
                            Description = killerName .. " auto-blacklisted (killed you)",
                            Duration = 3,
                        })
                    end
                end))
            end

            RegisterCleanup(function()
                AutoBlacklistSet = {}
            end)
        end
    end

    do
        local MonoAudio = MiscPage:Section({Name = "Center Gun Audio", Side = 1}) do
            local MonoState = { Enabled = false }
            local ReparentedSounds = {}

            local function IsFirstPerson()
                local cam = workspace.CurrentCamera
                local char = game.Players.LocalPlayer.Character
                if not cam or not char then return false end
                local head = char:FindFirstChild("Head")
                if not head then return false end
                return (cam.CFrame.Position - head.Position).Magnitude < 1.5
            end

            MonoAudio:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Center Gun Audio",
                    Description = "Moves gun sounds to your head so they play centered instead of from the right ear in first person"
                },
                Flag = "CenterGunAudioEnabled",
                Default = false,
                Callback = function(v) MonoState.Enabled = v end
            })

            NewRender(function()
                local char = game.Players.LocalPlayer.Character
                if not char then return end
                local head = char:FindFirstChild("Head")
                if not head then return end

                local tool = char:FindFirstChildOfClass("Tool")
                local shouldPatch = MonoState.Enabled and IsFirstPerson() and tool ~= nil

                if shouldPatch then
                    for _, desc in pairs(tool:GetDescendants()) do
                        if not desc:IsA("Sound") then continue end
                        if not ReparentedSounds[desc] then
                            ReparentedSounds[desc] = desc.Parent
                        end
                        if desc.Parent ~= head then
                            desc.Parent = head
                        end
                    end
                else
                    for snd, origParent in pairs(ReparentedSounds) do
                        if snd and snd.Parent and origParent and origParent.Parent then
                            snd.Parent = origParent
                        end
                    end
                    ReparentedSounds = {}
                end
            end)

            RegisterCleanup(function()
                for snd, origParent in pairs(ReparentedSounds) do
                    if snd and snd.Parent and origParent and origParent.Parent then
                        pcall(function() snd.Parent = origParent end)
                    end
                end
                ReparentedSounds = {}
            end)
        end
    end

    do
        local RemoveJumpCooldown = MiscPage:Section({Name = "Remove Jump Cooldown", Side = 1}) do
            local Enabled = RemoveJumpCooldown:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Remove Jump Cooldown",
                    Description = "Disables the forced delay between consecutive jumps"
                },
                Flag = "RemoveJumpCooldownEnabled",
                Default = false
            }) do
                NewRender(function()
                    local character = game.Players.LocalPlayer.Character
                    if not character then return end
                    local antiJump = character:FindFirstChild("AntiJump")
                    if not antiJump then return end
                    antiJump.Disabled = Enabled:Get()
                end)
            end
        end
    end

    do
        local AntiInvisible = MiscPage:Section({Name = "Anti Invisible", Side = 2}) do
            local Enabled = AntiInvisible:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Anti Invisible",
                    Description = "Detects the invisibility glitch and highlights offending players in red"
                },
                Flag = "AntiInvisibleEnabled",
                Default = false
            }) do
                local FlaggedPlayers = {}

                local function ApplyHighlight(character)
                    if character:FindFirstChild("AntiInvisHighlight") then return end
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "AntiInvisHighlight"
                    highlight.FillColor = Color3.fromRGB(255, 0, 0)
                    highlight.FillTransparency = 0.5
                    highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
                    highlight.OutlineTransparency = 0
                    highlight.Parent = character
                end

                local function RemoveHighlight(character)
                    local highlight = character:FindFirstChild("AntiInvisHighlight")
                    if highlight then highlight:Destroy() end
                end

                local function CleanupPlayer(player)
                    FlaggedPlayers[player] = nil
                    if player.Character then
                        RemoveHighlight(player.Character)
                    end
                end

                NewRender(function()
                    if Enabled:Get() == true then
                        for _, player in pairs(game:GetService("Players"):GetPlayers()) do
                            if player == game.Players.LocalPlayer then continue end
                            local character = player.Character
                            if not character then continue end
                            local humanoid = character:FindFirstChildOfClass("Humanoid")
                            if not humanoid then continue end

                            local animator = humanoid:FindFirstChildOfClass("Animator")
                            if animator then
                                for _, track in pairs(animator:GetPlayingAnimationTracks()) do
                                    if track.Animation and track.Animation.AnimationId == "rbxassetid://215384594" then
                                        track:Stop(0)
                                        FlaggedPlayers[player] = true
                                    end
                                end
                            end

                            if FlaggedPlayers[player] then
                                ApplyHighlight(character)
                            end
                        end
                    else
                        for player, _ in pairs(FlaggedPlayers) do
                            CleanupPlayer(player)
                        end
                    end
                end)

                RegisterCleanup(function()
                    for player, _ in pairs(FlaggedPlayers) do
                        CleanupPlayer(player)
                    end
                end)
            end
        end
    end

    do
        local AlwaysBackpack = MiscPage:Section({Name = "Always Backpack", Side = 1}) do
            local Enabled = AlwaysBackpack:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Always Backpack",
                    Description = "Prevents the game from hiding your inventory toolbar"
                },
                Flag = "AlwaysBackpackEnabled",
                Default = false
            }) do
                local LP = game:GetService("Players").LocalPlayer
                LP:GetAttributeChangedSignal("BackpackEnabled"):Connect(function()
                    if Enabled:Get() == true and LP:GetAttribute("BackpackEnabled") == false then
                        LP:SetAttribute("BackpackEnabled", true)
                    end
                end)
            end
        end
    end

    do
        local AntiTase = MiscPage:Section({Name = "Anti Tase", Side = 2}) do
            local ATState = {
                Enabled = false,
                Method = "Old Method",
            }

            AntiTase:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Anti Tase",
                    Description = "Prevents or cancels the taser stun effect and re-equips your weapon"
                },
                Flag = "AntiTaseEnabled",
                Default = false,
                Callback = function(v) ATState.Enabled = v end
            })

            AntiTase:Dropdown({
                Name = "Method",
                ToolTip = {
                    Name = "Method",
                    Description = "New Method continuously blocks the tase event. Old Method cancels the animation after it starts but has a 5s weapon cooldown."
                },
                Flag = "AntiTaseMethod",
                Default = "Old Method",
                Multi = false,
                Items = {"New Method", "Old Method"},
                Callback = function(v) ATState.Method = v end
            }) do
                local PlayerTased = game:GetService("ReplicatedStorage"):WaitForChild("GunRemotes"):WaitForChild("PlayerTased")

                local PreTaseSpeed = 16
                local PreTaseJumpHeight = 5.5
                local LastEquippedTool = nil
                local WasTazedLastFrame = false
                local TaseCooldownEnd = 0
                local CooldownNotifShown = false
                local CapturedSpeedOnTase = 16

                local NewMethodActive = false

                local function DisableTaseConnections()
                    for _, conn in pairs(getconnections(PlayerTased.OnClientEvent)) do
                        conn:Disable()
                    end
                end

                local function EnableTaseConnections()
                    for _, conn in pairs(getconnections(PlayerTased.OnClientEvent)) do
                        conn:Enable()
                    end
                end

                NewRender(function()
                    local character = game.Players.LocalPlayer.Character
                    if not character then return end
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if not humanoid then return end

                    local currentTool = character:FindFirstChildOfClass("Tool")
                    if currentTool then
                        LastEquippedTool = currentTool
                    end

                    if not ATState.Enabled then
                        if NewMethodActive then
                            EnableTaseConnections()
                            NewMethodActive = false
                        end
                        WasTazedLastFrame = false
                        return
                    end

                    if ATState.Method == "New Method" then
                        DisableTaseConnections()
                        NewMethodActive = true
                        WasTazedLastFrame = false
                        return
                    end

                    if NewMethodActive then
                        EnableTaseConnections()
                        NewMethodActive = false
                    end

                    if humanoid.WalkSpeed > 0 and tick() > TaseCooldownEnd then
                        PreTaseSpeed = humanoid.WalkSpeed
                    end
                    if humanoid.JumpHeight > 0 then
                        PreTaseJumpHeight = humanoid.JumpHeight
                    end

                    local animator = humanoid:FindFirstChildOfClass("Animator")
                    if not animator then return end

                    local tazed = false
                    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
                        local animId = track.Animation and track.Animation.AnimationId or ""
                        if animId == "rbxassetid://279227693" or animId == "rbxassetid://279229192" then
                            track:Stop(0)
                            tazed = true
                        end
                    end

                    if tazed then
                        humanoid.WalkSpeed = PreTaseSpeed
                        humanoid.JumpHeight = PreTaseJumpHeight

                        if not WasTazedLastFrame then
                            CapturedSpeedOnTase = PreTaseSpeed
                            TaseCooldownEnd = tick() + 5
                            CooldownNotifShown = false

                            if LastEquippedTool then
                                local tool = LastEquippedTool
                                if tool.Parent == game.Players.LocalPlayer.Backpack then
                                    humanoid:EquipTool(tool)
                                end
                            end
                        end
                        WasTazedLastFrame = true
                    else
                        WasTazedLastFrame = false
                    end

                    local now = tick()
                    if TaseCooldownEnd > 0 and now < TaseCooldownEnd then
                        if not CooldownNotifShown then
                            CooldownNotifShown = true
                            Library:Notification("Anti Tase", "Weapon cooldown active (5s)", 5)
                        end

                        if humanoid.WalkSpeed == 16 and CapturedSpeedOnTase ~= 16 then
                            humanoid.WalkSpeed = CapturedSpeedOnTase
                        end
                    end

                    if TaseCooldownEnd > 0 and now >= TaseCooldownEnd then
                        if humanoid.WalkSpeed == 16 and CapturedSpeedOnTase ~= 16 then
                            humanoid.WalkSpeed = CapturedSpeedOnTase
                        end
                        TaseCooldownEnd = 0
                    end
                end)

                RegisterCleanup(function()
                    EnableTaseConnections()
                    NewMethodActive = false
                end)
            end
        end
    end

    do
        local PickupAura = MiscPage:Section({Name = "Pickup Aura", Side = 2}) do
            local PAState = {
                Enabled = false,
                Items = {},
                Radius = 10,
                Cooldown = 0.5,
            }

            local PALastTick = 0
            local GiverRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("GiverPressed")

            PickupAura:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Pickup Aura",
                    Description = "Automatically picks up selected items within range using the GiverPressed remote"
                },
                Flag = "PickupAuraEnabled",
                Default = false,
                Callback = function(v) PAState.Enabled = v end
            })

            PickupAura:Dropdown({
                Name = "Items",
                Flag = "PickupAuraItems",
                Multi = true,
                Items = {"M9", "Hammer", "Crude Knife", "Key card"},
                Callback = function(v)
                    local set = {}
                    for _, name in pairs(v) do set[name] = true end
                    PAState.Items = set
                end
            })

            PickupAura:Slider({
                Name = "Radius",
                Flag = "PickupAuraRadius",
                Min = 5,
                Max = 30,
                Default = 10,
                Suffix = " studs",
                Decimals = 1,
                Callback = function(v) PAState.Radius = v end
            })

            NewRender(function()
                if not PAState.Enabled then return end
                if not next(PAState.Items) then return end

                local now = tick()
                if (now - PALastTick) < PAState.Cooldown then return end

                local character = game.Players.LocalPlayer.Character
                if not character then return end
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local myPos = hrp.Position
                local radius = PAState.Radius

                for _, obj in pairs(workspace:GetChildren()) do
                    if not PAState.Items[obj.Name] then continue end
                    local part = ResolvePickupPart(obj)

                    if part and (myPos - part.Position).Magnitude <= radius then
                        PALastTick = now
                        pcall(GiverRemote.FireServer, GiverRemote, obj)
                        return
                    end
                end
            end)
        end
    end

    do
        local ArrestAura = MiscPage:Section({Name = "Arrest Aura", Side = 1}) do
            local Players = game:GetService("Players")
            local LocalPlayer = Players.LocalPlayer
            local ArrestRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ArrestPlayer")

            local AAState = {
                Enabled = false,
                FriendCheck = false,
                ShowRadius = false,
                ShowTarget = false,
                Radius = 10,
                Whitelist = {},
            }

            local function GetInmateStatusAA(character)
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if not humanoid then return "Regular" end
                local dn = humanoid.DisplayName
                if string.sub(dn, 1, 4) == "\xF0\x9F\x94\x97" then
                    return "Arrestable"
                elseif string.sub(dn, 1, 4) == "\xF0\x9F\x92\xA2" then
                    return "Aggressive"
                end
                return "Regular"
            end

            local function IsArrestable(player)
                local teamName = player.Team and player.Team.Name or ""
                if teamName == "Criminals" then return true end
                if teamName == "Inmates" then
                    local char = player.Character
                    if char then
                        local status = GetInmateStatusAA(char)
                        if status == "Arrestable" or status == "Aggressive" then
                            return true
                        end
                    end
                end
                return false
            end

            local CIRCLE_SEGMENTS = 40
            local RadiusLines = {}
            for i = 1, CIRCLE_SEGMENTS do
                local line = TrackDrawing(Drawing.new("Line"))
                line.Thickness = 1
                line.Visible = false
                line.ZIndex = 998
                line.Transparency = 0.6
                line.Color = Color3.fromRGB(255, 50, 50)
                RadiusLines[i] = line
            end

            local TargetLine = TrackDrawing(Drawing.new("Line"))
            TargetLine.Thickness = 1.5
            TargetLine.Visible = false
            TargetLine.ZIndex = 998
            TargetLine.Color = Color3.fromRGB(255, 50, 50)

            ArrestAura:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Arrest Aura",
                    Description = "Automatically arrests the closest criminal or wanted inmate within radius"
                },
                Flag = "ArrestAuraEnabled",
                Default = false,
                Callback = function(v)
                    AAState.Enabled = v
                    if not v then
                        for _, line in RadiusLines do line.Visible = false end
                        TargetLine.Visible = false
                    end
                end
            })

            ArrestAura:Slider({
                Name = "Radius",
                Flag = "ArrestAuraRadius",
                Min = 5,
                Max = 30,
                Default = 10,
                Suffix = " studs",
                Decimals = 1,
                Callback = function(v) AAState.Radius = v end
            })

            ArrestAura:Toggle({
                Name = "Show Radius",
                Flag = "ArrestAuraShowRadius",
                Default = false,
                Callback = function(v)
                    AAState.ShowRadius = v
                    if not v then
                        for _, line in RadiusLines do line.Visible = false end
                    end
                end
            })

            ArrestAura:Toggle({
                Name = "Show Target",
                Flag = "ArrestAuraShowTarget",
                Default = false,
                Callback = function(v)
                    AAState.ShowTarget = v
                    if not v then TargetLine.Visible = false end
                end
            })

            ArrestAura:Toggle({
                Name = "Friend Check",
                ToolTip = {
                    Name = "Friend Check",
                    Description = "Won't arrest players on your Roblox friends list"
                },
                Flag = "ArrestAuraFriendCheck",
                Default = false,
                Callback = function(v) AAState.FriendCheck = v end
            })

            local aaPlayerNames = {}
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    table.insert(aaPlayerNames, p.Name)
                end
            end

            local AAWhitelistDropdown = ArrestAura:Dropdown({
                Name = "Whitelist",
                Flag = "ArrestAuraWhitelist",
                Multi = true,
                Items = aaPlayerNames,
                Callback = function(v)
                    local set = {}
                    for _, name in pairs(v) do set[name] = true end
                    AAState.Whitelist = set
                end
            })

            TrackConnection(Players.PlayerAdded:Connect(function(p) AAWhitelistDropdown:Add(p.Name) end))
            TrackConnection(Players.PlayerRemoving:Connect(function(p) AAWhitelistDropdown:Remove(p.Name) end))

            NewRender(function()
                if not AAState.Enabled then
                    for _, line in RadiusLines do line.Visible = false end
                    TargetLine.Visible = false
                    return
                end

                local character = LocalPlayer.Character
                if not character then return end
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if not rootPart then return end

                local Camera = workspace.CurrentCamera
                local feetY = rootPart.Position.Y - 3
                local center = Vector3.new(rootPart.Position.X, feetY, rootPart.Position.Z)

                if AAState.ShowRadius then
                    local angleStep = (2 * math.pi) / CIRCLE_SEGMENTS
                    local prevScreen = nil
                    local prevOnScreen = false

                    for i = 1, CIRCLE_SEGMENTS do
                        local angle = angleStep * i
                        local worldPoint = center + Vector3.new(math.cos(angle) * AAState.Radius, 0, math.sin(angle) * AAState.Radius)
                        local screenPos, onScreen = Camera:WorldToViewportPoint(worldPoint)
                        local curScreen = Vector2.new(screenPos.X, screenPos.Y)

                        if i > 1 then
                            if onScreen and prevOnScreen then
                                RadiusLines[i - 1].From = prevScreen
                                RadiusLines[i - 1].To = curScreen
                                RadiusLines[i - 1].Visible = true
                            else
                                RadiusLines[i - 1].Visible = false
                            end
                        end

                        if i == CIRCLE_SEGMENTS then
                            local firstWorld = center + Vector3.new(math.cos(angleStep) * AAState.Radius, 0, math.sin(angleStep) * AAState.Radius)
                            local firstPos, firstOn = Camera:WorldToViewportPoint(firstWorld)
                            if onScreen and firstOn then
                                RadiusLines[CIRCLE_SEGMENTS].From = curScreen
                                RadiusLines[CIRCLE_SEGMENTS].To = Vector2.new(firstPos.X, firstPos.Y)
                                RadiusLines[CIRCLE_SEGMENTS].Visible = true
                            else
                                RadiusLines[CIRCLE_SEGMENTS].Visible = false
                            end
                        end

                        prevScreen = curScreen
                        prevOnScreen = onScreen
                    end
                else
                    for _, line in RadiusLines do line.Visible = false end
                end

                local closestPlayer = nil
                local closestDist = AAState.Radius

                for _, player in pairs(Players:GetPlayers()) do
                    if player == LocalPlayer then continue end
                    if AAState.Whitelist[player.Name] then continue end
                    if AAState.FriendCheck and FriendsCache[player.Name] then continue end
                    if not IsArrestable(player) then continue end
                    local targetChar = player.Character
                    if not targetChar then continue end
                    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                    if not targetRoot then continue end
                    local dist = (rootPart.Position - targetRoot.Position).Magnitude
                    if dist <= closestDist then
                        closestDist = dist
                        closestPlayer = player
                    end
                end

                if closestPlayer then
                    local targetRoot = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if targetRoot then
                        pcall(function()
                            ArrestRemote:InvokeServer(closestPlayer, 1)
                        end)

                        if AAState.ShowTarget then
                            local targetFeetY = targetRoot.Position.Y - 3
                            local fromWorld = Vector3.new(rootPart.Position.X, feetY, rootPart.Position.Z)
                            local toWorld = Vector3.new(targetRoot.Position.X, targetFeetY, targetRoot.Position.Z)
                            local fromPos, fromOn = Camera:WorldToViewportPoint(fromWorld)
                            local toPos, toOn = Camera:WorldToViewportPoint(toWorld)
                            if fromOn and toOn then
                                TargetLine.From = Vector2.new(fromPos.X, fromPos.Y)
                                TargetLine.To = Vector2.new(toPos.X, toPos.Y)
                                TargetLine.Visible = true
                            else
                                TargetLine.Visible = false
                            end
                        else
                            TargetLine.Visible = false
                        end
                    end
                else
                    TargetLine.Visible = false
                end
            end)
        end
    end

    do
        local FistAura = MiscPage:Section({Name = "Fist Aura", Side = 2}) do
            local Players = game:GetService("Players")
            local LocalPlayer = Players.LocalPlayer
            local MeleeRemote = game:GetService("ReplicatedStorage"):WaitForChild("meleeEvent")

            local FAState = {
                Enabled = false,
                FriendCheck = false,
                ShowRadius = false,
                ShowTarget = false,
                Radius = 10,
                Teams = {},
                InmateTypes = {},
                Whitelist = {},
            }

            local function GetInmateStatusFA(character)
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if not humanoid then return "Regular" end
                local dn = humanoid.DisplayName
                if string.sub(dn, 1, 4) == "\xF0\x9F\x94\x97" then
                    return "Arrestable"
                elseif string.sub(dn, 1, 4) == "\xF0\x9F\x92\xA2" then
                    return "Aggressive"
                end
                return "Regular"
            end

            local function ShouldTarget(player)
                local teamName = player.Team and player.Team.Name or ""
                if next(FAState.Teams) and not FAState.Teams[teamName] then return false end
                if teamName == "Inmates" and next(FAState.InmateTypes) then
                    local char = player.Character
                    if char then
                        local status = GetInmateStatusFA(char)
                        if not FAState.InmateTypes[status] then return false end
                    end
                end
                return true
            end

            local FA_CIRCLE_SEGMENTS = 40
            local FARadiusLines = {}
            for i = 1, FA_CIRCLE_SEGMENTS do
                local line = TrackDrawing(Drawing.new("Line"))
                line.Thickness = 1
                line.Visible = false
                line.ZIndex = 997
                line.Transparency = 0.6
                line.Color = Color3.fromRGB(50, 150, 255)
                FARadiusLines[i] = line
            end

            local FATargetLine = TrackDrawing(Drawing.new("Line"))
            FATargetLine.Thickness = 1.5
            FATargetLine.Visible = false
            FATargetLine.ZIndex = 997
            FATargetLine.Color = Color3.fromRGB(50, 150, 255)

            FistAura:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Fist Aura",
                    Description = "Automatically punches the closest valid player within radius"
                },
                Flag = "FistAuraEnabled",
                Default = false,
                Callback = function(v)
                    FAState.Enabled = v
                    if not v then
                        for _, line in FARadiusLines do line.Visible = false end
                        FATargetLine.Visible = false
                    end
                end
            })

            FistAura:Slider({
                Name = "Radius",
                Flag = "FistAuraRadius",
                Min = 5,
                Max = 30,
                Default = 10,
                Suffix = " studs",
                Decimals = 1,
                Callback = function(v) FAState.Radius = v end
            })

            FistAura:Toggle({
                Name = "Show Radius",
                Flag = "FistAuraShowRadius",
                Default = false,
                Callback = function(v)
                    FAState.ShowRadius = v
                    if not v then
                        for _, line in FARadiusLines do line.Visible = false end
                    end
                end
            })

            FistAura:Toggle({
                Name = "Show Target",
                Flag = "FistAuraShowTarget",
                Default = false,
                Callback = function(v)
                    FAState.ShowTarget = v
                    if not v then FATargetLine.Visible = false end
                end
            })

            FistAura:Dropdown({
                Name = "Teams",
                Flag = "FistAuraTeams",
                Multi = true,
                Items = {"Guards", "Inmates", "Criminals"},
                Callback = function(v)
                    local set = {}
                    for _, name in pairs(v) do set[name] = true end
                    FAState.Teams = set
                end
            })

            FistAura:Dropdown({
                Name = "Inmate Types",
                Flag = "FistAuraInmateTypes",
                Multi = true,
                Items = {"Regular", "Aggressive", "Arrestable"},
                Callback = function(v)
                    local set = {}
                    for _, name in pairs(v) do set[name] = true end
                    FAState.InmateTypes = set
                end
            })

            FistAura:Toggle({
                Name = "Friend Check",
                ToolTip = {
                    Name = "Friend Check",
                    Description = "Won't punch players on your Roblox friends list"
                },
                Flag = "FistAuraFriendCheck",
                Default = false,
                Callback = function(v) FAState.FriendCheck = v end
            })

            local faPlayerNames = {}
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    table.insert(faPlayerNames, p.Name)
                end
            end

            local FAWhitelistDropdown = FistAura:Dropdown({
                Name = "Whitelist",
                Flag = "FistAuraWhitelist",
                Multi = true,
                Items = faPlayerNames,
                Callback = function(v)
                    local set = {}
                    for _, name in pairs(v) do set[name] = true end
                    FAState.Whitelist = set
                end
            })

            TrackConnection(Players.PlayerAdded:Connect(function(p) FAWhitelistDropdown:Add(p.Name) end))
            TrackConnection(Players.PlayerRemoving:Connect(function(p) FAWhitelistDropdown:Remove(p.Name) end))

            NewRender(function()
                if not FAState.Enabled then
                    for _, line in FARadiusLines do line.Visible = false end
                    FATargetLine.Visible = false
                    return
                end

                local character = LocalPlayer.Character
                if not character then return end
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if not rootPart then return end

                local Camera = workspace.CurrentCamera
                local feetY = rootPart.Position.Y - 3
                local center = Vector3.new(rootPart.Position.X, feetY, rootPart.Position.Z)

                if FAState.ShowRadius then
                    local angleStep = (2 * math.pi) / FA_CIRCLE_SEGMENTS
                    local prevScreen = nil
                    local prevOnScreen = false

                    for i = 1, FA_CIRCLE_SEGMENTS do
                        local angle = angleStep * i
                        local worldPoint = center + Vector3.new(math.cos(angle) * FAState.Radius, 0, math.sin(angle) * FAState.Radius)
                        local screenPos, onScreen = Camera:WorldToViewportPoint(worldPoint)
                        local curScreen = Vector2.new(screenPos.X, screenPos.Y)

                        if i > 1 then
                            if onScreen and prevOnScreen then
                                FARadiusLines[i - 1].From = prevScreen
                                FARadiusLines[i - 1].To = curScreen
                                FARadiusLines[i - 1].Visible = true
                            else
                                FARadiusLines[i - 1].Visible = false
                            end
                        end

                        if i == FA_CIRCLE_SEGMENTS then
                            local firstWorld = center + Vector3.new(math.cos(angleStep) * FAState.Radius, 0, math.sin(angleStep) * FAState.Radius)
                            local firstPos, firstOn = Camera:WorldToViewportPoint(firstWorld)
                            if onScreen and firstOn then
                                FARadiusLines[FA_CIRCLE_SEGMENTS].From = curScreen
                                FARadiusLines[FA_CIRCLE_SEGMENTS].To = Vector2.new(firstPos.X, firstPos.Y)
                                FARadiusLines[FA_CIRCLE_SEGMENTS].Visible = true
                            else
                                FARadiusLines[FA_CIRCLE_SEGMENTS].Visible = false
                            end
                        end

                        prevScreen = curScreen
                        prevOnScreen = onScreen
                    end
                else
                    for _, line in FARadiusLines do line.Visible = false end
                end

                local closestPlayer = nil
                local closestDist = FAState.Radius

                for _, player in pairs(Players:GetPlayers()) do
                    if player == LocalPlayer then continue end
                    if FAState.Whitelist[player.Name] then continue end
                    if FAState.FriendCheck and FriendsCache[player.Name] then continue end
                    if not ShouldTarget(player) then continue end
                    local targetChar = player.Character
                    if not targetChar then continue end
                    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                    if not targetRoot then continue end
                    local dist = (rootPart.Position - targetRoot.Position).Magnitude
                    if dist <= closestDist then
                        closestDist = dist
                        closestPlayer = player
                    end
                end

                if closestPlayer then
                    local targetRoot = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if targetRoot then
                        pcall(function()
                            MeleeRemote:FireServer(closestPlayer, 1, 1)
                        end)

                        if FAState.ShowTarget then
                            local targetFeetY = targetRoot.Position.Y - 3
                            local fromWorld = Vector3.new(rootPart.Position.X, feetY, rootPart.Position.Z)
                            local toWorld = Vector3.new(targetRoot.Position.X, targetFeetY, targetRoot.Position.Z)
                            local fromPos, fromOn = Camera:WorldToViewportPoint(fromWorld)
                            local toPos, toOn = Camera:WorldToViewportPoint(toWorld)
                            if fromOn and toOn then
                                FATargetLine.From = Vector2.new(fromPos.X, fromPos.Y)
                                FATargetLine.To = Vector2.new(toPos.X, toPos.Y)
                                FATargetLine.Visible = true
                            else
                                FATargetLine.Visible = false
                            end
                        else
                            FATargetLine.Visible = false
                        end
                    end
                else
                    FATargetLine.Visible = false
                end
            end)
        end
    end

    do
        local AntiRiotShield = MiscPage:Section({Name = "Anti Riot Shield", Side = 1}) do
            local Enabled = AntiRiotShield:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Anti Riot Shield",
                    Description = "Removes RiotShieldPart from all players' characters"
                },
                Flag = "AntiRiotShieldEnabled",
                Default = false
            }) do
                NewRender(function()
                    if Enabled:Get() ~= true then return end
                    for _, player in pairs(game:GetService("Players"):GetPlayers()) do
                        local character = player.Character
                        if not character then continue end
                        local shield = character:FindFirstChild("RiotShieldPart")
                        if shield then
                            shield:Destroy()
                        end
                    end
                end)
            end
        end
    end

    do
        local RagebotSection = BlatantPage:Section({Name = "Ragebot (BETA)", Side = 1})
        local RagebotConfigSection = BlatantPage:Section({Name = "Ragebot Config", Side = 2})

        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer

        local RBState = {
            Enabled = false,
            AutoSwitch = true,
            AutoReload = true,
            TargetBone = "HumanoidRootPart",
            Teams = {},
            InmateTypes = {},
            DeathCheck = true,
            ForceFieldCheck = true,
            FriendCheck = false,
            Whitelist = {},
            Blacklist = {},
        }

        local RBLastFireTick = 0
        local RBSwitchCooldown = 0
        local RBPhase = "fight"
        local RBReloadQueue = {}
        local RBReloadIndex = 0
        local RBLastReloadTick = 0

        local VIM = cloneref(game:GetService("VirtualInputManager"))

        local function RBGetAmmoLabel()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if not pg then return nil end
            local home = pg:FindFirstChild("Home")
            if not home then return nil end
            local hud = home:FindFirstChild("hud")
            if not hud then return nil end
            local brf = hud:FindFirstChild("BottomRightFrame")
            if not brf then return nil end
            local gf = brf:FindFirstChild("GunFrame")
            if not gf then return nil end
            return gf:FindFirstChild("BulletsLabel")
        end

        local function RBReadAmmo()
            local label = RBGetAmmoLabel()
            if not label then return nil, nil end
            local text = label.Text
            local current, total = text:match("^(%d+)/(%d+)")
            return tonumber(current), tonumber(total)
        end

        local function RBSendReloadKey()
            VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
            task.delay(0.05, function()
                VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
            end)
        end

        local function RBIsGun(tool)
            if not tool:IsA("Tool") then return false end
            local handle = tool:FindFirstChild("Handle")
            if not handle then return false end
            return handle:FindFirstChild("ShootSound") ~= nil
        end

        local function RBGetAllGuns()
            local guns = {}
            for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                if RBIsGun(tool) then table.insert(guns, tool) end
            end
            local char = LocalPlayer.Character
            if char then
                for _, tool in pairs(char:GetChildren()) do
                    if RBIsGun(tool) then table.insert(guns, tool) end
                end
            end
            return guns
        end

        local function RBGetEquippedGun()
            local char = LocalPlayer.Character
            if not char then return nil end
            for _, tool in pairs(char:GetChildren()) do
                if RBIsGun(tool) then return tool end
            end
            return nil
        end

        local function RBGetMuzzlePosition(tool)
            local muzzle = tool:FindFirstChild("Muzzle")
            if muzzle and muzzle:IsA("BasePart") then return muzzle.Position end
            local handle = tool:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then return handle.Position end
            return nil
        end

        local RB_R6_BONES = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart"}
        local RB_R6_BONE_ITEMS = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart", "Random", "Nearest Visible"}

        local function RBHasClearLOS(origin, targetPos, ignoreList)
            local direction = targetPos - origin
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = ignoreList
            local result = workspace:Raycast(origin, direction, params)
            return result == nil
        end

        local function RBResolveBone(rawBone, character, localChar)
            if rawBone == "Random" then
                return RB_R6_BONES[math.random(1, #RB_R6_BONES)]
            end
            if rawBone == "Nearest Visible" then
                local cam = workspace.CurrentCamera
                for _, name in ipairs(RB_R6_BONES) do
                    local part = character:FindFirstChild(name)
                    if part then
                        if #cam:GetPartsObscuringTarget({part.Position}, {localChar, character}) == 0 then
                            return name
                        end
                    end
                end
                return "HumanoidRootPart"
            end
            return rawBone
        end

        local function RBGetInmateStatus(character)
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return "Regular" end
            local dn = humanoid.DisplayName
            if string.sub(dn, 1, 4) == "\xF0\x9F\x94\x97" then return "Arrestable"
            elseif string.sub(dn, 1, 4) == "\xF0\x9F\x92\xA2" then return "Aggressive" end
            return "Regular"
        end

        local function RBFindBestTarget(muzzlePos, gun)
            local localChar = LocalPlayer.Character
            if not localChar then return nil end

            local range = gun:GetAttribute("Range") or 1000
            local bestTarget = nil
            local bestDist = math.huge

            local rbMyTeam = LocalPlayer.Team and LocalPlayer.Team.Name or ""

            for _, player in pairs(Players:GetPlayers()) do
                if player == LocalPlayer then continue end

                local rbBlacklisted = RBState.Blacklist[player.Name] or AutoBlacklistSet[player.Name]
                local teamName = player.Team and player.Team.Name or ""

                if rbBlacklisted then
                    if teamName == rbMyTeam and teamName ~= "Inmates" then continue end
                end

                local character = player.Character
                if not character then continue end

                if rbBlacklisted then
                    if teamName == "Inmates" and RBGetInmateStatus(character) == "Regular" then continue end
                end

                if not rbBlacklisted then
                    if RBState.Whitelist[player.Name] then continue end
                    if RBState.FriendCheck and FriendsCache[player.Name] then continue end
                    if next(RBState.Teams) and not RBState.Teams[teamName] then continue end

                    if teamName == "Inmates" and next(RBState.InmateTypes) then
                        local status = RBGetInmateStatus(character)
                        if not RBState.InmateTypes[status] then continue end
                    end
                end

                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if RBState.DeathCheck and (not humanoid or humanoid.Health <= 0) then continue end
                if RBState.ForceFieldCheck and character:FindFirstChild("ForceField") then continue end

                local bone = RBResolveBone(RBState.TargetBone, character, localChar)
                local targetPart = character:FindFirstChild(bone) or character:FindFirstChild("HumanoidRootPart")
                if not targetPart then continue end

                local dist = (muzzlePos - targetPart.Position).Magnitude
                if dist > range then continue end

                local clear = RBHasClearLOS(muzzlePos, targetPart.Position, {localChar, character})
                if clear and dist < bestDist then
                    bestDist = dist
                    bestTarget = targetPart
                end
            end

            return bestTarget
        end

        RagebotSection:Toggle({
            Name = "Enabled",
            ToolTip = {
                Name = "Ragebot",
                Description = "Fully automated combat — acquires targets, aims, and fires with no input needed"
            },
            Flag = "RagebotEnabled",
            Default = false,
            Callback = function(v)
                RBState.Enabled = v
                if not v then
                    RagebotForcedTarget = nil
                end
            end
        })

        RagebotSection:Toggle({
            Name = "Auto Switch",
            ToolTip = {
                Name = "Auto Switch",
                Description = "Automatically switches to another gun when the current one is empty"
            },
            Flag = "RagebotAutoSwitch",
            Default = true,
            Callback = function(v) RBState.AutoSwitch = v end
        })

        RagebotSection:Toggle({
            Name = "Auto Reload",
            ToolTip = {
                Name = "Auto Reload",
                Description = "Automatically reloads the current gun when the magazine is empty"
            },
            Flag = "RagebotAutoReload",
            Default = true,
            Callback = function(v) RBState.AutoReload = v end
        })

        RagebotSection:Dropdown({
            Name = "Target Bone",
            Flag = "RagebotTargetBone",
            Default = "HumanoidRootPart",
            Multi = false,
            Items = RB_R6_BONE_ITEMS,
            Callback = function(v) RBState.TargetBone = v end
        })

        RagebotConfigSection:Dropdown({
            Name = "Teams",
            Flag = "RagebotTeams",
            Multi = true,
            Items = {"Guards", "Inmates", "Criminals"},
            Callback = function(v)
                local set = {}
                for _, name in pairs(v) do set[name] = true end
                RBState.Teams = set
            end
        })

        RagebotConfigSection:Dropdown({
            Name = "Inmate Types",
            Flag = "RagebotInmateTypes",
            Multi = true,
            Items = {"Regular", "Aggressive", "Arrestable"},
            Callback = function(v)
                local set = {}
                for _, name in pairs(v) do set[name] = true end
                RBState.InmateTypes = set
            end
        })

        RagebotConfigSection:Toggle({
            Name = "Death Check",
            ToolTip = {
                Name = "Death Check",
                Description = "Skips dead players so the ragebot doesn't waste ammo on corpses"
            },
            Flag = "RagebotDeathCheck",
            Default = true,
            Callback = function(v) RBState.DeathCheck = v end
        })

        RagebotConfigSection:Toggle({
            Name = "ForceField Check",
            ToolTip = {
                Name = "ForceField Check",
                Description = "Skips targets with an active spawn ForceField"
            },
            Flag = "RagebotForceFieldCheck",
            Default = true,
            Callback = function(v) RBState.ForceFieldCheck = v end
        })

        RagebotConfigSection:Toggle({
            Name = "Friend Check",
            ToolTip = {
                Name = "Friend Check",
                Description = "Won't target players on your Roblox friends list"
            },
            Flag = "RagebotFriendCheck",
            Default = false,
            Callback = function(v) RBState.FriendCheck = v end
        })

        local rbPlayerNames = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(rbPlayerNames, p.Name)
            end
        end

        local RBWhitelistDropdown = RagebotConfigSection:Dropdown({
            Name = "Whitelist",
            Flag = "RagebotWhitelist",
            Multi = true,
            Items = rbPlayerNames,
            Callback = function(v)
                local set = {}
                for _, name in pairs(v) do set[name] = true end
                RBState.Whitelist = set
            end
        })

        local RBBlacklistDropdown = RagebotConfigSection:Dropdown({
            Name = "Blacklist",
            ToolTip = { Name = "Blacklist", Description = "Always target these players regardless of team, inmate status, or other filters" },
            Flag = "RagebotBlacklist",
            Multi = true,
            Items = rbPlayerNames,
            Callback = function(v)
                local set = {}
                for _, name in pairs(v) do set[name] = true end
                RBState.Blacklist = set
            end
        })

        TrackConnection(Players.PlayerAdded:Connect(function(p)
            RBWhitelistDropdown:Add(p.Name)
            RBBlacklistDropdown:Add(p.Name)
        end))
        TrackConnection(Players.PlayerRemoving:Connect(function(p)
            RBWhitelistDropdown:Remove(p.Name)
            RBBlacklistDropdown:Remove(p.Name)
        end))

        NewRender(function()
            if not RBState.Enabled then
                RagebotForcedTarget = nil
                RagebotMuzzleOrigin = nil
                RBPhase = "fight"
                return
            end

            local character = LocalPlayer.Character
            if not character then
                RagebotForcedTarget = nil
                RagebotMuzzleOrigin = nil
                return
            end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                RagebotForcedTarget = nil
                RagebotMuzzleOrigin = nil
                return
            end

            local now = tick()
            local currentAmmo, totalAmmo = RBReadAmmo()

            if RBPhase == "reload" then
                RagebotForcedTarget = nil
                RagebotMuzzleOrigin = nil

                if RBReloadIndex > #RBReloadQueue then
                    RBPhase = "fight"
                    RBReloadQueue = {}
                    RBReloadIndex = 0
                    return
                end

                local gun = RBReloadQueue[RBReloadIndex]
                if not gun or not gun.Parent then
                    RBReloadIndex = RBReloadIndex + 1
                    return
                end

                local equipped = RBGetEquippedGun()
                if equipped ~= gun then
                    if (now - RBSwitchCooldown) > 0.3 then
                        humanoid:EquipTool(gun)
                        RBSwitchCooldown = now
                    end
                    return
                end

                if currentAmmo and currentAmmo > 0 then
                    RBReloadIndex = RBReloadIndex + 1
                    return
                end

                if (now - RBLastReloadTick) > 2 then
                    RBSendReloadKey()
                    RBLastReloadTick = now
                    return
                end

                return
            end

            local equippedGun = RBGetEquippedGun()
            local magEmpty = not currentAmmo or currentAmmo == 0

            if not equippedGun or magEmpty then
                if equippedGun and magEmpty and RBState.AutoSwitch then
                    local allGuns = RBGetAllGuns()
                    for _, gun in pairs(allGuns) do
                        if gun ~= equippedGun and gun.Parent == LocalPlayer.Backpack then
                            if (now - RBSwitchCooldown) > 0.3 then
                                humanoid:EquipTool(gun)
                                RBSwitchCooldown = now
                            end
                            RagebotForcedTarget = nil
                            RagebotMuzzleOrigin = nil
                            return
                        end
                    end
                end

                if RBState.AutoReload and magEmpty then
                    RBReloadQueue = RBGetAllGuns()
                    if #RBReloadQueue > 0 then
                        RBPhase = "reload"
                        RBReloadIndex = 1
                        RBLastReloadTick = 0
                    end
                end

                RagebotForcedTarget = nil
                RagebotMuzzleOrigin = nil
                return
            end

            if (now - RBLastFireTick) < 0.08 then return end

            local muzzlePos = RBGetMuzzlePosition(equippedGun)
            if not muzzlePos then return end

            local target = RBFindBestTarget(muzzlePos, equippedGun)
            if target then
                RagebotForcedTarget = target
                RagebotMuzzleOrigin = muzzlePos
                RBLastFireTick = now
                mouse1click()
            else
                RagebotForcedTarget = nil
                RagebotMuzzleOrigin = nil
            end
        end)
    end

    do
        local PlayersState = {
            SelectedPlayer = "",
            TeleportCooldown = false
        }

        local PlayersSection = PlayersPage:Section({Name = "Players", Side = 1}) do
            local SelectedPlayer = PlayersSection:Dropdown({
                Name = "Selected Player",
                Flag = "PlayersSelectedPlayer",
                Multi = false,
                Callback = function(callback) PlayersState.SelectedPlayer = callback end
            }) do
                for _, player in pairs(game.Players:GetPlayers()) do
                    if player.Name ~= game.Players.LocalPlayer.Name then
                        SelectedPlayer:Add(player.Name)
                    end
                end

                TrackConnection(game.Players.PlayerAdded:Connect(function(player)
                    SelectedPlayer:Add(player.Name)
                end))

                TrackConnection(game.Players.PlayerRemoving:Connect(function(player)
                    SelectedPlayer:Remove(player.Name)
                end))
            end
        end

        local ActionsSection = PlayersPage:Section({Name = "Actions", Side = 2}) do
            ActionsSection:Button():Add("Teleport", function()
                if PlayersState.TeleportCooldown == false then
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = game.Players[PlayersState.SelectedPlayer].Character.HumanoidRootPart.CFrame
                    Library:Notification("Teleport", "You are able to teleport again in 15 seconds, the wait is due to the anticheat flagging if you teleport too often.", 15)
                    PlayersState.TeleportCooldown = true
                    task.delay(15, function() PlayersState.TeleportCooldown = false end)
                end
            end)
        end
    end

    local OriginalUnload = Library.Unload
    Library.Unload = function(self)
        for _, conn in ipairs(TrackedConnections) do
            pcall(function() conn:Disconnect() end)
        end
        TrackedConnections = {}
        for i = #CleanupCallbacks, 1, -1 do
            pcall(CleanupCallbacks[i])
        end
        for _, drawing in ipairs(TrackedDrawings) do
            pcall(drawing.Remove, drawing)
        end
        CleanupCallbacks = {}
        TrackedDrawings = {}
        OriginalUnload(self)
    end
end