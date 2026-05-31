--Prison Life
local Library = loadstring(game:HttpGet("https://github.com/catthatdrinkssprite/catnip/raw/main/library/Library.lua"))()

local Window = Library:Window({
    Logo = getcustomasset("catnip/images/paw.png"),
    FadeTime = 0.3,
})

Library.MenuKeybind = tostring(Enum.KeyCode.Delete)

local Watermark = Library:Watermark("loading...")
local KeybindList = Library:KeybindList()

do
    local CombatPage = Window:Page({Name = "Combat", Columns = 2})
    local MovementPage = Window:Page({Name = "Movement", Columns = 2})
    local VisualsPage = Window:Page({Name = "Visuals", Columns = 2})
    local WorldPage = Window:Page({Name = "World", Columns = 2})
    local MiscPage = Window:Page({Name = "Misc", Columns = 2})
    local RagebotPage = Window:Page({Name = "Ragebot", Columns = 2})
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
    local ScriptAlive = true

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

    local MasterRenderConnection
    local function StopAllRenderers()
        if MasterRenderConnection and MasterRenderConnection.Connected then
            MasterRenderConnection:Disconnect()
        end
        for _, connection in RenderCache do
            if connection and connection.Disconnect then
                pcall(connection.Disconnect, connection)
            end
        end
        table.clear(RenderCache)
    end

    MasterRenderConnection = RunService.RenderStepped:Connect(function(Delta)
        if not ScriptAlive then return end
        for _, Connection in RenderCache do
            if Connection and Connection.Function then
                Connection.Function(Delta)
            end
        end
    end)
    RegisterCleanup(StopAllRenderers)

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

    -- Prison Life shared core (Vape parity)
    local PL = {
        Shoot = nil,
        rawShoot = nil,
        Bullet = nil,
        Reload = nil,
        GunTracers = nil,
    }
    local PLTargeting = {}
    local aimTimer, shootTimer, aimVec = os.clock(), os.clock(), Vector3.zero

    local PlayersService = game:GetService("Players")
    local LocalPlayer = PlayersService.LocalPlayer
    local UserInputService = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local CollectionService = game:GetService("CollectionService")
    local TweenService = game:GetService("TweenService")
    local Teams = game:GetService("Teams")
    local PLCamera = workspace.CurrentCamera

    local WallbangRayGuard = false
    local function GuardedRaycast(origin, direction, params)
        WallbangRayGuard = true
        local ok, result = pcall(workspace.Raycast, workspace, origin, direction, params)
        WallbangRayGuard = false
        return ok and result or nil
    end

    local function GuardedGetPartBoundsInBox(cframe, size, params)
        WallbangRayGuard = true
        local ok, result = pcall(workspace.GetPartBoundsInBox, workspace, cframe, size, params)
        WallbangRayGuard = false
        return ok and result or {}
    end

    PL.OriginScanner = {}
    do
        local rayParams = RaycastParams.new()
        rayParams.CollisionGroup = "ClientBullet"
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local rayParams2 = OverlapParams.new()
        rayParams2.CollisionGroup = "ClientBullet"
        rayParams2.FilterType = Enum.RaycastFilterType.Exclude
        PL.OriginScanner.Ray = rayParams
        PL.OriginScanner.Overlap = rayParams2

        local scanOffsets = {
            Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), Vector3.new(0.7, -0.5, -0.5),
            Vector3.new(-0.1, -0.8, -0.8), Vector3.new(-0.8, -0.5, -0.5), Vector3.new(-1, 0, 0),
            Vector3.new(-0.8, 0.4, 0.4), Vector3.new(0, 0.7, 0.7), Vector3.new(0.7, 0.5, 0.5),
            Vector3.new(1, 0, 0), Vector3.new(0.7, 0, -0.8), Vector3.new(-0.1, 0, -1),
            Vector3.new(-0.8, 0, -0.8), Vector3.new(-1, 0, 0), Vector3.new(-0.8, 0, 0.7),
            Vector3.new(0, 0, 1), Vector3.new(0.7, 0, 0.7), Vector3.new(1, 0, 0),
            Vector3.new(0.7, 0.4, -0.5), Vector3.new(-0.1, 0.7, -0.8), Vector3.new(-0.8, 0.4, -0.5),
            Vector3.new(-1, -0.1, 0), Vector3.new(-0.8, -0.5, 0.4), Vector3.new(0, -0.8, 0.7),
            Vector3.new(0.7, -0.6, 0.5), Vector3.new(0, -1, 0),
        }
        local wallbangIgnoreList = {}

        local function RefreshWallbangIgnoreList()
            table.clear(wallbangIgnoreList)
            local localCharacter = LocalPlayer.Character
            if localCharacter then table.insert(wallbangIgnoreList, localCharacter) end
            for _, player in ipairs(PlayersService:GetPlayers()) do
                if player.Character then table.insert(wallbangIgnoreList, player.Character) end
            end
            rayParams.FilterDescendantsInstances = wallbangIgnoreList
            rayParams2.FilterDescendantsInstances = wallbangIgnoreList
        end

        function PL.OriginScanner:UpdateIgnore()
            rayParams.FilterDescendantsInstances = wallbangIgnoreList
            rayParams2.FilterDescendantsInstances = wallbangIgnoreList
        end

        RefreshWallbangIgnoreList()
        TrackConnection(PlayersService.PlayerAdded:Connect(function(player)
            RefreshWallbangIgnoreList()
            TrackConnection(player.CharacterAdded:Connect(RefreshWallbangIgnoreList))
        end))
        TrackConnection(PlayersService.PlayerRemoving:Connect(RefreshWallbangIgnoreList))
        TrackConnection(LocalPlayer.CharacterAdded:Connect(RefreshWallbangIgnoreList))

        function PL.OriginScanner:Scan(origin, target, ...)
            local scanPositions = {}
            for _, v in {...} do
                if (origin - v).Magnitude < 7.5 then table.insert(scanPositions, v) end
            end
            for i = 5, 7 do
                for _, v in scanOffsets do
                    table.insert(scanPositions, origin + v * i)
                end
            end
            for _, pos in scanPositions do
                local ray = GuardedRaycast(target, (pos - target), rayParams)
                if not ray and #GuardedGetPartBoundsInBox(CFrame.new(pos), Vector3.one * 0.1, rayParams2) <= 0 then
                    return pos
                end
            end
        end
    end

    function PL.resolveShoot()
        local home = LocalPlayer.PlayerGui:FindFirstChild("Home")
        local actionArea = home and home:FindFirstChild("hud") and home.hud:FindFirstChild("ActionArea")
        if not actionArea then return false end
        for _, connection in getconnections(actionArea.InputBegan) do
            local shootFn = connection.Function and debug.getupvalue(connection.Function, 2)
            if shootFn then
                PL.Shoot = shootFn
                PL.rawShoot = shootFn
                PL.Reload = debug.getupvalue(shootFn, 2)
                PL.Bullet = debug.getupvalue(shootFn, 16)
                return PL.Bullet ~= nil
            end
        end
        return false
    end

    function PL.getGunData()
        local fn = PL.rawShoot
        if not fn then return nil end
        local ok, data = pcall(debug.getupvalue, fn, 10)
        if ok and type(data) == "table" and data.Range ~= nil then return data end
        for i = 1, 40 do
            ok, data = pcall(debug.getupvalue, fn, i)
            if ok and type(data) == "table" and data.Range ~= nil and data.FireRate ~= nil then
                return data
            end
        end
        return nil
    end

    function PL.getEquippedTool()
        local character = LocalPlayer.Character
        return character and character:FindFirstChildWhichIsA("Tool")
    end

    function PL.getMousePosition()
        if UserInputService.TouchEnabled then
            return PLCamera.ViewportSize / 2
        end
        return UserInputService:GetMouseLocation()
    end

    function PL.GetInmateStatus(character)
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return "Regular" end
        local displayName = humanoid.DisplayName
        if string.sub(displayName, 1, 4) == "\xF0\x9F\x94\x97" then return "Arrestable"
        elseif string.sub(displayName, 1, 4) == "\xF0\x9F\x92\xA2" then return "Aggressive" end
        return "Regular"
    end

    function PL.passesCombatFilters(player, character, filters)
        local isBlacklisted = filters.Blacklist and (filters.Blacklist[player.Name] or (filters.AutoBlacklist and filters.AutoBlacklist[player.Name]))
        local teamName = player.Team and player.Team.Name or ""
        local myTeam = LocalPlayer.Team and LocalPlayer.Team.Name or ""

        if isBlacklisted and teamName == myTeam and teamName ~= "Inmates" then return false end
        if isBlacklisted and teamName == "Inmates" and PL.GetInmateStatus(character) == "Regular" then return false end

        if not isBlacklisted then
            if filters.Whitelist and filters.Whitelist[player.Name] then return false end
            if filters.FriendCheck and FriendsCache[player.Name] then return false end
            if filters.Teams and next(filters.Teams) and not filters.Teams[teamName] then return false end
            if teamName == "Inmates" then
                local holdingTaser = filters.HoldingTaser
                local needStatus = (filters.InmateTypes and next(filters.InmateTypes)) or (filters.ArrestSafety and not holdingTaser)
                if needStatus then
                    local status = PL.GetInmateStatus(character)
                    if filters.InmateTypes and next(filters.InmateTypes) and not filters.InmateTypes[status] then return false end
                    if filters.ArrestSafety and not holdingTaser and status == "Arrestable" then return false end
                end
            end
        end

        local humanoid = character:FindFirstChild("Humanoid")
        if filters.DeathCheck and (not humanoid or humanoid.Health <= 0) then return false end
        if filters.ForceFieldCheck and character:FindFirstChild("ForceField") then return false end
        return true
    end

    function PL.wallcheck(shootOrigin, targetPos, wallbangRootPos)
        PL.OriginScanner:UpdateIgnore()
        local ray = GuardedRaycast(targetPos, shootOrigin - targetPos, PL.OriginScanner.Ray)
        if ray then
            return not wallbangRootPos or not PL.OriginScanner:Scan(wallbangRootPos, targetPos, ray.Position + ray.Normal * 0.05)
        end
        return false
    end

    function PLTargeting.getClosestPart(settings)
        local origin = settings.Origin or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position)
        if not origin then return nil end

        local localCharacter = LocalPlayer.Character
        if not localCharacter then return nil end
        local root = localCharacter:FindFirstChild("HumanoidRootPart")
        if not root then return nil end

        if settings.RollChance and settings.HitChance and settings.HitChance < 100 and settings.AimRandom then
            if settings.AimRandom:NextInteger(1, 100) > settings.HitChance then
                return nil
            end
        end

        local boneName = "HumanoidRootPart"
        if settings.Bone then
            boneName = settings.Bone
        elseif settings.HeadshotChance and settings.HeadshotChance >= 100 then
            boneName = "Head"
        elseif settings.HeadshotChance and settings.AimRandom then
            boneName = settings.AimRandom:NextInteger(1, 100) <= settings.HeadshotChance and "Head" or "HumanoidRootPart"
        end

        local aimRange = settings.Range or 150
        if settings.Mode == "Position" and settings.RangeLimit then
            aimRange = math.min(aimRange, settings.RangeLimit)
        end

        local wallbangRoot = settings.Wallbang and root.Position or nil
        local sortingTable = {}
        local mousePos = PL.getMousePosition()
        local filters = settings.Filters or {}

        for _, player in PlayersService:GetPlayers() do
            if player == LocalPlayer then continue end
            local character = player.Character
            if not character then continue end
            if not PL.passesCombatFilters(player, character, filters) then continue end

            if player.Team == Teams.Inmates then
                if not (character:GetAttribute("Trespassing") or character:GetAttribute("Hostile")) then continue end
                if settings.AttackCheck and LocalPlayer.Team == Teams.Guards and not character:GetAttribute("Hostile") then continue end
            end

            local targetPart = character:FindFirstChild(boneName) or character:FindFirstChild("HumanoidRootPart")
            if not targetPart then continue end

            local magnitude
            if settings.Mode == "Mouse" then
                local screenPos, onScreen = PLCamera:WorldToViewportPoint(targetPart.Position)
                if not onScreen then continue end
                magnitude = (mousePos - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
            else
                magnitude = (targetPart.Position - origin).Magnitude
            end

            if magnitude > aimRange then continue end
            if PL.wallcheck(origin, targetPart.Position, wallbangRoot) then continue end

            table.insert(sortingTable, {Part = targetPart, Magnitude = magnitude, Player = player})
        end

        table.sort(sortingTable, function(a, b) return a.Magnitude < b.Magnitude end)
        return sortingTable[1] and sortingTable[1].Part or nil, sortingTable[1] and sortingTable[1].Player or nil
    end

    function PLTargeting.allPositions(settings)
        local origin = settings.Origin or (LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart and LocalPlayer.Character.HumanoidRootPart.Position)
        if not origin then return {} end
        local results = {}
        local wallbangRoot = settings.Wallbang and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or nil
        local filters = settings.Filters or {}

        for _, player in PlayersService:GetPlayers() do
            if player == LocalPlayer then continue end
            local character = player.Character
            if not character then continue end
            if not PL.passesCombatFilters(player, character, filters) then continue end
            if player.Team == Teams.Inmates and settings.AttackCheck and LocalPlayer.Team == Teams.Guards and not character:GetAttribute("Hostile") then continue end

            local targetPart = character:FindFirstChild(settings.Bone or "HumanoidRootPart") or character:FindFirstChild("HumanoidRootPart")
            if not targetPart then continue end
            local magnitude = (targetPart.Position - origin).Magnitude
            if magnitude > (settings.Range or 12) then continue end
            if settings.Wallcheck ~= false and PL.wallcheck(origin, targetPart.Position, wallbangRoot) then continue end
            table.insert(results, {Part = targetPart, Player = player, Magnitude = magnitude})
        end
        table.sort(results, function(a, b) return a.Magnitude < b.Magnitude end)
        if settings.Limit then
            while #results > settings.Limit do table.remove(results) end
        end
        return results
    end

    function PL.applyWallbang(origin, targetPos)
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then return origin end
        PL.OriginScanner:UpdateIgnore()
        local ray = GuardedRaycast(targetPos, origin - targetPos, PL.OriginScanner.Ray)
        if ray then
            local newOrigin = PL.OriginScanner:Scan(root.Position, targetPos, ray.Position + ray.Normal * 0.05)
            if newOrigin then return newOrigin end
        end
        return origin
    end

    PL.TracerHook = {Hooks = {}}
    local oldGunTracer = nil
    function PL.TracerHook:Add(key, fn, priority)
        table.insert(self.Hooks, {key, fn, priority or 0})
        table.sort(self.Hooks, function(a, b) return a[3] < b[3] end)
        if not oldGunTracer and PL.GunTracers then
            oldGunTracer = hookfunction(PL.GunTracers.createBullet, function(...)
                if debug.info(3, "s") ~= "ReplicatedStorage.Scripts.Replication.ClientReplicator" then
                    for _, v in self.Hooks do
                        if v[2](...) then return end
                    end
                end
                return oldGunTracer(...)
            end)
        end
    end
    function PL.TracerHook:Remove(key)
        for i, v in self.Hooks do
            if v[1] == key then table.remove(self.Hooks, i) break end
        end
        if oldGunTracer and not next(self.Hooks) then
            hookfunction(PL.GunTracers.createBullet, oldGunTracer)
            oldGunTracer = nil
        end
    end

    local bulletHandlers = {}
    local oldBullet = nil
    local bulletHookActive = false

    function PL.addBulletHandler(name, handler, priority)
        table.insert(bulletHandlers, {name, handler, priority or 0})
        table.sort(bulletHandlers, function(a, b) return a[3] < b[3] end)
        PL.ensureBulletHook()
    end

    function PL.removeBulletHandler(name)
        for i, v in bulletHandlers do
            if v[1] == name then table.remove(bulletHandlers, i) break end
        end
        if not next(bulletHandlers) then PL.removeBulletHook() end
    end

    function PL.ensureBulletHook()
        if bulletHookActive or not PL.Bullet then return end
        oldBullet = hookfunction(PL.Bullet, newcclosure(function(...)
            local args = table.pack(...)
            for _, h in bulletHandlers do
                local result = h[2](args)
                if result == false then return oldBullet(unpack(args, 1, args.n)) end
            end
            return oldBullet(unpack(args, 1, args.n))
        end))
        bulletHookActive = true
    end

    function PL.removeBulletHook()
        if oldBullet and PL.Bullet then
            if restorefunction then restorefunction(PL.Bullet) else hookfunction(PL.Bullet, oldBullet) end
            oldBullet = nil
            bulletHookActive = false
        end
    end

    local shootHandlers = {}
    local oldShootHook = nil
    local shootHookActive = false

    function PL.addShootHandler(name, handler)
        shootHandlers[name] = handler
        PL.ensureShootHook()
    end

    function PL.removeShootHandler(name)
        shootHandlers[name] = nil
        if not next(shootHandlers) then PL.removeShootHook() end
    end

    function PL.ensureShootHook()
        if shootHookActive or not PL.Shoot then return end
        oldShootHook = hookfunction(PL.Shoot, newcclosure(function(...)
            local args = table.pack(oldShootHook(...))
            for _, handler in shootHandlers do
                handler(args)
            end
            return unpack(args, 1, args.n)
        end))
        shootHookActive = true
    end

    function PL.removeShootHook()
        if oldShootHook and PL.Shoot then
            if restorefunction then restorefunction(PL.Shoot) else hookfunction(PL.Shoot, oldShootHook) end
            oldShootHook = nil
            shootHookActive = false
        end
    end

    task.spawn(function()
        while not PL.resolveShoot() do task.wait(0.5) end
        pcall(function()
            PL.GunTracers = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GunTracers"))
        end)
    end)

    RegisterCleanup(function()
        local bulletNames, shootNames = {}, {}
        for _, h in bulletHandlers do
            table.insert(bulletNames, h[1])
        end
        for _, name in bulletNames do
            PL.removeBulletHandler(name)
        end
        for name in shootHandlers do
            table.insert(shootNames, name)
        end
        for _, name in shootNames do
            PL.removeShootHandler(name)
        end
        PL.removeBulletHook()
        PL.removeShootHook()
        if PL.TracerHook and PL.TracerHook.Hooks then
            local tracerKeys = {}
            for _, h in PL.TracerHook.Hooks do
                table.insert(tracerKeys, h[1])
            end
            for _, key in tracerKeys do
                PL.TracerHook:Remove(key)
            end
        end
        if oldGunTracer and PL.GunTracers then
            pcall(function() hookfunction(PL.GunTracers.createBullet, oldGunTracer) end)
            oldGunTracer = nil
        end
    end)

    do
        local GunModState = {Enabled = false, NoSpread = false, FullAuto = false, FireRatePct = 100}
        local gunModOldData, gunModOldRef = {}, nil
        local gunModThread = nil

        local function restoreGunData()
            if gunModOldRef then
                for i, v in gunModOldData do gunModOldRef[i] = v end
                table.clear(gunModOldData)
                gunModOldRef = nil
            end
        end

        local function startGunModLoop()
            if gunModThread then return end
            gunModThread = task.spawn(function()
                while GunModState.Enabled do
                    local data = PL.getGunData()
                    if data then
                        if gunModOldRef ~= data then
                            gunModOldData = table.clone(data)
                            gunModOldRef = data
                        end
                        data.SpreadRadius = GunModState.NoSpread and 0 or gunModOldData.SpreadRadius
                        data.FireRate = (gunModOldData.FireRate or 0) * (GunModState.FireRatePct / 100)
                        data.AutoFire = GunModState.FullAuto or gunModOldData.AutoFire
                    end
                    task.wait(0.016)
                end
                restoreGunData()
                gunModThread = nil
            end)
        end

        local GunModSection = CombatPage:Section({Name = "Gun Modifications", Side = 2})
        GunModSection:Toggle({
            Name = "Enabled",
            Flag = "GunModificationsEnabled",
            Default = false,
            Callback = function(v)
                GunModState.Enabled = v
                if v then
                    if not PL.rawShoot then PL.resolveShoot() end
                    startGunModLoop()
                else
                    restoreGunData()
                end
            end
        })
        GunModSection:Slider({
            Name = "FireRate Multiplier",
            Flag = "GunModFireRate",
            Min = 1, Max = 100, Default = 100, Suffix = "%",
            Callback = function(v) GunModState.FireRatePct = v end
        })
        GunModSection:Toggle({Name = "No Spread", Flag = "GunModNoSpread", Default = false, Callback = function(v) GunModState.NoSpread = v end})
        GunModSection:Toggle({Name = "Full Automatic", Flag = "GunModFullAuto", Default = false, Callback = function(v) GunModState.FullAuto = v end})

        RegisterCleanup(function()
            GunModState.Enabled = false
            restoreGunData()
        end)
    end

    do
        do
            local SilentAimSection = CombatPage:Section({Name = "Silent Aim", Side = 1}) do
                local SilentAimState = {
                    Enabled = false,
                    Style = "Legit",
                    Triggerbot = false,
                    ArrestSafety = false,
                    FoVCircle = false,
                    FoVCircleFilled = false,
                    FoVCircleTransparency = 0.5,
                    FoVCircleColor = Library.Theme.Accent,
                    Tracer = false,
                    TracerColor = Library.Theme.Accent,
                    Mode = "Mouse",
                    Range = 150,
                    HitChance = 85,
                    HeadshotChance = 65,
                    Wallbang = false,
                    ForceFieldCheck = true,
                    Teams = {},
                    InmateTypes = {},
                    DeathCheck = true,
                    FriendCheck = false,
                    Whitelist = {},
                    Blacklist = {},
                }
                local aimRandom = Random.new()

                local function getSAFilters()
                    local holdingTaser = false
                    local char = LocalPlayer.Character
                    if char and SilentAimState.ArrestSafety then
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool then holdingTaser = tool.Name == "Taser" end
                    end
                    return {
                        Teams = SilentAimState.Teams,
                        InmateTypes = SilentAimState.InmateTypes,
                        Whitelist = SilentAimState.Whitelist,
                        Blacklist = SilentAimState.Blacklist,
                        AutoBlacklist = AutoBlacklistSet,
                        FriendCheck = SilentAimState.FriendCheck,
                        DeathCheck = SilentAimState.DeathCheck,
                        ForceFieldCheck = SilentAimState.ForceFieldCheck,
                        ArrestSafety = SilentAimState.ArrestSafety,
                        HoldingTaser = holdingTaser,
                    }
                end

                local function saGetTarget(origin, rangeLimit, attackCheck, rollChance)
                    local blatant = SilentAimState.Style == "Blatant"
                    return PLTargeting.getClosestPart({
                        Origin = origin,
                        Mode = SilentAimState.Mode,
                        Range = SilentAimState.Range,
                        RangeLimit = rangeLimit,
                        HitChance = blatant and 100 or SilentAimState.HitChance,
                        HeadshotChance = blatant and 100 or SilentAimState.HeadshotChance,
                        Bone = blatant and "Head" or nil,
                        Wallbang = SilentAimState.Wallbang,
                        AttackCheck = attackCheck,
                        RollChance = rollChance and not blatant,
                        AimRandom = aimRandom,
                        Filters = getSAFilters(),
                    })
                end

                SilentAimSection:Dropdown({
                    Name = "Style",
                    Flag = "SilentAimStyle",
                    Default = "Legit",
                    Multi = false,
                    Items = {"Legit", "Blatant"},
                    Callback = function(v) SilentAimState.Style = v end
                })

                SilentAimSection:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "Silent Aim",
                        Description = "Legit: hit/headshot chance rolls can miss (Vape). Blatant: always redirects to head."
                    },
                    Flag = "SilentAimEnabled",
                    Default = SilentAimState.Enabled,
                    Callback = function(v)
                        SilentAimState.Enabled = v
                        if not v then
                            PL.removeBulletHandler("SilentAim")
                            return
                        end
                        PL.addBulletHandler("SilentAim", function(args)
                            if not (SilentAimState.Enabled or RagebotForcedTarget) then return end
                            local origin = args[1]
                            local gunData = PL.getGunData()
                            local rangeLimit = gunData and gunData.Range or 1000
                            local attackCheck = not gunData or gunData.Behavior ~= "Taser"
                            local hitPart = RagebotForcedTarget or saGetTarget(origin, rangeLimit, attackCheck, true)
                            if not hitPart then return false end
                            args[2] = hitPart.Position
                            aimVec = args[2]
                            aimTimer = os.clock() + 0.3
                            shootTimer = os.clock() + 0.3
                            if SilentAimState.Wallbang then
                                local newOrigin = PL.applyWallbang(origin, args[2])
                                for i, v in debug.getstack(3) do
                                    if v == origin then debug.setstack(3, i, newOrigin) end
                                end
                                args[1] = newOrigin
                            end
                        end, 1)
                    end
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
                        Description = "Shows targeting radius on screen (Mouse mode only)"
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

                SilentAimSection:Slider({
                    Name = "Circle Transparency",
                    Flag = "SilentAimFoVTransparency",
                    Min = 0, Max = 1, Default = 0.5, Decimals = 0.01,
                    Callback = function(v) SilentAimState.FoVCircleTransparency = v end
                })

                SilentAimSection:Toggle({
                    Name = "Circle Filled",
                    Flag = "SilentAimFoVFilled",
                    Default = false,
                    Callback = function(v) SilentAimState.FoVCircleFilled = v end
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

                SilentAimSection:Dropdown({
                    Name = "Mode",
                    Flag = "SilentAimMode",
                    Default = SilentAimState.Mode,
                    Multi = false,
                    Items = {"Mouse", "Position"},
                    Callback = function(v) SilentAimState.Mode = v end
                })

                SilentAimSection:Slider({
                    Name = "Range",
                    Flag = "SilentAimRange",
                    Min = 1,
                    Max = 1000,
                    Default = SilentAimState.Range,
                    Decimals = 1,
                    Callback = function(v) SilentAimState.Range = v end
                })

                SilentAimSection:Slider({
                    Name = "Hit Chance",
                    Flag = "SilentAimHitChance",
                    Min = 0,
                    Max = 100,
                    Default = SilentAimState.HitChance,
                    Suffix = "%",
                    ToolTip = {
                        Name = "Hit Chance",
                        Description = "Legit only. Chance silent aim redirects the bullet. Below 100% some shots fire normally and can miss."
                    },
                    Callback = function(v) SilentAimState.HitChance = v end
                })

                SilentAimSection:Slider({
                    Name = "Headshot Chance",
                    Flag = "SilentAimHeadshotChance",
                    Min = 0,
                    Max = 100,
                    Default = SilentAimState.HeadshotChance,
                    Suffix = "%",
                    ToolTip = {
                        Name = "Headshot Chance",
                        Description = "Legit only. Chance to aim at Head instead of torso when a shot is redirected."
                    },
                    Callback = function(v) SilentAimState.HeadshotChance = v end
                })

                SilentAimSection:Toggle({
                    Name = "Wallbang",
                    ToolTip = {
                        Name = "Wallbang",
                        Description = "Shoot through walls when a ClientBullet path exists from your character to the target"
                    },
                    Flag = "SilentAimWallbang",
                    Default = SilentAimState.Wallbang,
                    Callback = function(v) SilentAimState.Wallbang = v end
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

                    local previewTarget = nil

                    NewRender(function()
                        PLCamera = workspace.CurrentCamera
                        local showCircle = SilentAimState.Enabled and SilentAimState.FoVCircle and SilentAimState.Mode == "Mouse"
                        if showCircle then
                            FoVCircle.Position = PL.getMousePosition()
                            FoVCircle.Radius = SilentAimState.Range
                            FoVCircle.Color = SilentAimState.FoVCircleColor
                            FoVCircle.Filled = SilentAimState.FoVCircleFilled
                            FoVCircle.Thickness = 1
                            FoVCircle.Transparency = 1 - SilentAimState.FoVCircleTransparency
                            FoVCircle.Visible = true
                        else
                            FoVCircle.Visible = false
                        end

                        previewTarget = nil
                        if SilentAimState.Enabled or RagebotForcedTarget then
                            local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                            local previewOrigin = RagebotMuzzleOrigin or (head and head.Position) or Vector3.zero
                            local previewRoll = SilentAimState.Style == "Legit" and not RagebotForcedTarget
                            previewTarget = RagebotForcedTarget or saGetTarget(previewOrigin, 1000, true, previewRoll)
                        end

                        if SilentAimState.Enabled and SilentAimState.Tracer and previewTarget then
                            local screenPos, onScreen = PLCamera:WorldToViewportPoint(previewTarget.Position)
                            if onScreen then
                                Tracer.From = PL.getMousePosition()
                                Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                                Tracer.Color = SilentAimState.TracerColor
                                Tracer.Visible = true
                            else
                                Tracer.Visible = false
                            end
                        else
                            Tracer.Visible = false
                        end

                        if SilentAimState.Triggerbot and previewTarget then
                            local character = LocalPlayer.Character
                            if character then
                                local tool = character:FindFirstChildOfClass("Tool")
                                if tool and tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("ShootSound") then
                                    mouse1click()
                                end
                            end
                        end
                    end)

                    RegisterCleanup(function()
                        PL.removeBulletHandler("SilentAim")
                    end)
                end
            end
        end
    end

    do

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
                        local killPos = string.find(entryText, " killed ", 1, true)
                        if killPos then
                            local victim = string.match(string.sub(entryText, killPos + 8), "@([%w_]+)%)")
                            if victim == LocalPlayer.Name then
                                local killer = string.match(string.sub(entryText, 1, killPos - 1), "@([%w_]+)%)")
                                if killer and killer ~= LocalPlayer.Name then
                                    Library:Notification("Kill Notifications", killer .. " killed you!", 5)
                                end
                            end
                        end
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

            local HitSoundsSection = CombatPage:Section({Name = "Hit Sounds", Side = 2}) do
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
                    Decimals = 0.1,
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

            local KillSoundsSection = CombatPage:Section({Name = "Kill Sounds", Side = 2}) do
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
                    Decimals = 0.1,
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
            local AutoDetonateSection = CombatPage:Section({Name = "Auto Detonate", Side = 2})
            local ADEnabled = false
            local localC4 = nil
            local detonateTicks = 0
            local detonateRay = RaycastParams.new()
            detonateRay.CollisionGroup = "ClientBullet"
            detonateRay.FilterType = Enum.RaycastFilterType.Exclude

            AutoDetonateSection:Toggle({
                Name = "Enabled",
                Flag = "AutoDetonateEnabled",
                Default = false,
                Callback = function(v) ADEnabled = v end
            })

            local function trackC4(obj)
                if obj:GetAttribute("UserId") == LocalPlayer.UserId then localC4 = obj end
            end
            TrackConnection(CollectionService:GetInstanceAddedSignal("C4"):Connect(function(obj)
                if ADEnabled then trackC4(obj) end
            end))
            for _, obj in CollectionService:GetTagged("C4") do trackC4(obj) end

            task.spawn(function()
                while ScriptAlive do
                    if ADEnabled and localC4 and localC4.Parent then
                        local backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
                        local tool = backpack and backpack:FindFirstChild("C4 Explosive")
                        if tool then
                            local ent = PLTargeting.getClosestPart({
                                Mode = "Position",
                                Origin = localC4.Position,
                                Range = 25,
                                Bone = "HumanoidRootPart",
                                AttackCheck = true,
                                Filters = {Teams = {Criminals = true, Inmates = true}},
                            })
                            if ent then
                                local char = ent.Parent
                                local player = PlayersService:GetPlayerFromCharacter(char)
                                detonateRay.FilterDescendantsInstances = {char, LocalPlayer.Character, localC4}
                                local ray = workspace:Raycast(localC4.Position, ent.Position - localC4.Position, detonateRay)
                                if not ray then
                                    detonateTicks += 1
                                    if detonateTicks > 3 then
                                        local equipped = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
                                        if equipped then equipped.Parent = backpack end
                                        tool.Parent = LocalPlayer.Character
                                        pcall(function()
                                            ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("C4"):WaitForChild("ActivateC4"):InvokeServer()
                                        end)
                                        tool.Parent = backpack
                                        if equipped then equipped.Parent = LocalPlayer.Character end
                                        detonateTicks = 0
                                    end
                                    task.wait(0.05)
                                    continue
                                end
                            end
                        end
                    end
                    detonateTicks = 0
                    task.wait(0.05)
                end
            end)
        end

        do
            local AutoHealSection = CombatPage:Section({Name = "Auto Heal", Side = 2})
            local AHEnabled = false
            local healItems = {Breakfast = true, Lunch = true, Dinner = true}

            AutoHealSection:Toggle({
                Name = "Enabled",
                Flag = "AutoHealEnabled",
                Default = false,
                Callback = function(v) AHEnabled = v end
            })

            task.spawn(function()
                while ScriptAlive do
                    if AHEnabled and LocalPlayer.Character then
                        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        local backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
                        if humanoid and humanoid.Health <= 85 and backpack then
                            local healTool
                            for _, t in backpack:GetChildren() do
                                if healItems[t.Name] then healTool = t break end
                            end
                            if healTool and (os.clock() - (healTool:GetAttribute("Client_LastConsumedAt") or 0)) >= 3 then
                                local equipped = LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
                                if equipped then equipped.Parent = backpack end
                                healTool.Parent = LocalPlayer.Character
                                healTool:SetAttribute("Quantity", (healTool:GetAttribute("Quantity") or 1) - 1)
                                healTool:SetAttribute("Client_LastConsumedAt", os.clock())
                                pcall(function() ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EatFood"):FireServer() end)
                                healTool.Parent = backpack
                                if equipped then equipped.Parent = LocalPlayer.Character end
                            end
                        end
                    end
                    task.wait(0.05)
                end
            end)
        end

        do
            local AutoReloadSection = CombatPage:Section({Name = "Auto Reload", Side = 2})
            local AREnabled, ARHotSwap = false, false
            local weaponPriority = {["M4A1"] = 1, ["AK-47"] = 1, MP5 = 1, FAL = 1, ["Remington 870"] = 2, M9 = 3, Revolver = 4}

            local function getSwapWeapon()
                local backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
                if not backpack then return nil end
                local items = {}
                for _, tool in backpack:GetChildren() do
                    if tool:GetAttribute("FireRate") and (tool:GetAttribute("Local_ReloadSession") or 0) <= 0
                        and tool.Name ~= "Taser" and tool.Name ~= "Sniper" then
                        table.insert(items, tool)
                    end
                end
                table.sort(items, function(a, b)
                    return (weaponPriority[a.Name] or 100) < (weaponPriority[b.Name] or 100)
                end)
                return items[1]
            end

            local function shootReloadHandler()
                if not AREnabled or not PL.rawShoot then return end
                local tool = PL.getEquippedTool()
                if tool and (tool:GetAttribute("Local_CurrentAmmo") or 1) <= 0 then
                    if PL.Reload then task.spawn(PL.Reload) end
                    if ARHotSwap then
                        local wep = getSwapWeapon()
                        if wep then
                            tool.Parent = LocalPlayer.Backpack
                            wep.Parent = LocalPlayer.Character
                        end
                    end
                end
            end

            AutoReloadSection:Toggle({
                Name = "Enabled",
                Flag = "AutoReloadEnabled",
                Default = false,
                Callback = function(v)
                    AREnabled = v
                    if v then PL.addShootHandler("AutoReload", shootReloadHandler)
                    else PL.removeShootHandler("AutoReload") end
                end
            })
            AutoReloadSection:Toggle({
                Name = "Hot Swap",
                Flag = "AutoReloadHotSwap",
                Default = false,
                Callback = function(v) ARHotSwap = v end
            })
            RegisterCleanup(function() PL.removeShootHandler("AutoReload") end)
        end

        do
            local VehicleWallbangSection = CombatPage:Section({Name = "Vehicle Wallbang", Side = 2})
            local vehicleWallbangModified = {}

            local function ModifyVehiclePart(part)
                if part:IsA("BasePart") then
                    if not vehicleWallbangModified[part] then
                        vehicleWallbangModified[part] = part.CanQuery
                    end
                    part.CanQuery = false
                end
            end

            local carContainer = workspace:FindFirstChild("CarContainer")
            if carContainer then
                local VehicleWallbangEnabled

                local function SetVehicleWallbang(enabled)
                    if enabled then
                        task.defer(function()
                            if VehicleWallbangEnabled:Get() ~= true then return end
                            for _, part in carContainer:GetDescendants() do
                                ModifyVehiclePart(part)
                            end
                        end)
                    else
                        for part, original in pairs(vehicleWallbangModified) do
                            if part.Parent then
                                part.CanQuery = original
                            end
                        end
                        table.clear(vehicleWallbangModified)
                    end
                end

                VehicleWallbangEnabled = VehicleWallbangSection:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "Vehicle Wallbang",
                        Description = "Disables CanQuery on vehicle parts so bullets can pass through cars"
                    },
                    Flag = "VehicleWallbangEnabled",
                    Default = false,
                    Callback = SetVehicleWallbang,
                })

                TrackConnection(carContainer.DescendantAdded:Connect(function(part)
                    if VehicleWallbangEnabled:Get() == true then
                        ModifyVehiclePart(part)
                    end
                end))

                RegisterCleanup(function()
                    SetVehicleWallbang(false)
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
        local VFState = {Enabled = false, Mode = "CFrame", Speed = 60}
        local vfUp, vfDown = 0, 0
        local vfWheels = {}
        local vfPart
        local VehicleFlySection = MovementPage:Section({Name = "Vehicle Fly", Side = 1})
        local carContainer = workspace:WaitForChild("CarContainer", 30)

        VehicleFlySection:Toggle({
            Name = "Enabled",
            Flag = "VehicleFlyEnabled",
            Default = false,
            Callback = function(v)
                VFState.Enabled = v
                vfUp, vfDown = 0, 0
            end
        })
        VehicleFlySection:Dropdown({
            Name = "Mode", Flag = "VehicleFlyMode", Default = "CFrame", Multi = false,
            Items = {"CFrame", "Part"}, Callback = function(v) VFState.Mode = v end
        })
        VehicleFlySection:Slider({
            Name = "Speed", Flag = "VehicleFlySpeed", Min = 1, Max = 100, Default = 60,
            Callback = function(v) VFState.Speed = v end
        })

        TrackConnection(UserInputService.InputBegan:Connect(function(input)
            if not VFState.Enabled or UserInputService:GetFocusedTextBox() then return end
            if input.KeyCode == Enum.KeyCode.E then vfUp = 1
            elseif input.KeyCode == Enum.KeyCode.Q then vfDown = -1 end
        end))
        TrackConnection(UserInputService.InputEnded:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.E and vfUp == 1 then vfUp = 0
            elseif input.KeyCode == Enum.KeyCode.Q and vfDown == -1 then vfDown = 0 end
        end))

        NewRender(function(dt)
            if not VFState.Enabled or not LocalPlayer.Character then
                for _, w in vfWheels do pcall(function() w.Enabled = true end) end
                table.clear(vfWheels)
                if vfPart then vfPart.Parent = nil end
                return
            end
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            local seat = hum and hum.SeatPart
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not (seat and root and carContainer and seat:IsDescendantOf(carContainer)) then
                if vfPart then vfPart.Parent = nil end
                return
            end
            if VFState.Mode == "Part" then
                if not vfPart then
                    vfPart = Instance.new("Part")
                    vfPart.Size = Vector3.new(50, 1, 50)
                    vfPart.Anchored, vfPart.CanQuery, vfPart.Transparency = true, false, 1
                end
                vfPart.CFrame = CFrame.new(seat.Position - Vector3.new(0, 2.2 - (vfUp + vfDown), 0))
                vfPart.Parent = workspace
            elseif seat:IsA("VehicleSeat") then
                local wheels = seat.Parent and seat.Parent.Parent and seat.Parent.Parent:FindFirstChild("Wheels")
                if wheels and #vfWheels == 0 then
                    for _, w in wheels:GetDescendants() do
                        if w.ClassName == "Rotate" or w:IsA("HingeConstraint") then
                            w.Enabled = false
                            table.insert(vfWheels, w)
                        end
                    end
                end
                root.AssemblyLinearVelocity = Vector3.new(0, 2.25, 0)
                root.CFrame = CFrame.lookAlong(root.Position, PLCamera.CFrame.LookVector)
                    + (hum.MoveDirection + Vector3.new(0, vfUp + vfDown, 0)) * VFState.Speed * dt
            end
        end)
        RegisterCleanup(function()
            for _, w in vfWheels do pcall(function() w.Enabled = true end) end
            if vfPart then vfPart:Destroy() end
        end)
    end

    do
        local VSState = {Enabled = false, Speed = 140}
        local vsSeats, vsOldSeat = {}, nil
        local VehicleSpeedSection = MovementPage:Section({Name = "Vehicle Speed", Side = 2})
        VehicleSpeedSection:Toggle({
            Name = "Enabled", Flag = "VehicleSpeedEnabled", Default = false,
            Callback = function(v) VSState.Enabled = v if not v then table.clear(vsSeats) vsOldSeat = nil end end
        })
        VehicleSpeedSection:Slider({
            Name = "Speed", Flag = "VehicleSpeedValue", Min = 80, Max = 200, Default = 140,
            Callback = function(v) VSState.Speed = v end
        })
        local carContainerVS = workspace:FindFirstChild("CarContainer")
        task.spawn(function()
            while ScriptAlive do
                if VSState.Enabled and carContainerVS and LocalPlayer.Character then
                    local seat = LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and LocalPlayer.Character.Humanoid.SeatPart
                    if seat and seat:IsDescendantOf(carContainerVS) then
                        if seat ~= vsOldSeat then
                            vsSeats = {}
                            local model = seat.Parent and seat.Parent.Parent
                            if model then
                                for _, v in model:GetDescendants() do
                                    if v:IsA("VehicleSeat") then table.insert(vsSeats, v) end
                                end
                            end
                            vsOldSeat = seat
                        end
                        for _, v in vsSeats do v.MaxSpeed = VSState.Speed v.Torque = 4 end
                    end
                end
                task.wait()
            end
        end)
    end
    
    do
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

            local ESPFilters = VisualsPage:Section({Name = "Filters", Side = 1}) do
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

            local ESPSection = VisualsPage:Section({Name = "ESP", Side = 2}) do
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

            local ItemESPSection = VisualsPage:Section({Name = "Item ESP", Side = 2}) do
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

        do
            local C4ESPSection = VisualsPage:Section({Name = "C4 ESP", Side = 2})
            local c4Refs, c4Folder = {}, Instance.new("Folder")
            c4Folder.Name = "catnipC4ESP"
            c4Folder.Parent = game:GetService("CoreGui")
            local c4Fill = Color3.fromRGB(255, 80, 0)
            local c4Outline = Color3.new(1, 1, 1)
            local c4FillT, c4OutlineT = 0.5, 0

            local function addC4(obj)
                if c4Refs[obj] then return end
                local h = Instance.new("Highlight")
                h.Adornee = obj
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.FillColor, h.OutlineColor = c4Fill, c4Outline
                h.FillTransparency, h.OutlineTransparency = c4FillT, c4OutlineT
                h.Parent = c4Folder
                c4Refs[obj] = h
            end
            local function remC4(obj)
                if c4Refs[obj] then c4Refs[obj]:Destroy() c4Refs[obj] = nil end
            end

            local C4Enabled = false
            C4ESPSection:Toggle({Name = "Enabled", Flag = "C4ESPEnabled", Default = false, Callback = function(v)
                C4Enabled = v
                if v then
                    for _, obj in CollectionService:GetTagged("C4") do addC4(obj) end
                else
                    for obj in pairs(c4Refs) do remC4(obj) end
                end
            end})
            C4ESPSection:Toggle({Name = "Fill Color", Flag = "C4ESPFill", Default = true}):Colorpicker({
                Name = "Fill", Flag = "C4ESPFillColor", Default = c4Fill, Callback = function(v)
                    c4Fill = v
                    for _, h in pairs(c4Refs) do h.FillColor = v end
                end
            })
            C4ESPSection:Slider({Name = "Fill Transparency", Flag = "C4ESPFillT", Min = 0, Max = 1, Default = 0.5, Decimals = 0.01,
                Callback = function(v) c4FillT = v for _, h in pairs(c4Refs) do h.FillTransparency = v end end})
            C4ESPSection:Slider({Name = "Outline Transparency", Flag = "C4ESPOutlineT", Min = 0, Max = 1, Default = 0, Decimals = 0.01,
                Callback = function(v) c4OutlineT = v for _, h in pairs(c4Refs) do h.OutlineTransparency = v end end})

            TrackConnection(CollectionService:GetInstanceAddedSignal("C4"):Connect(function(obj) if C4Enabled then addC4(obj) end end))
            TrackConnection(CollectionService:GetInstanceRemovedSignal("C4"):Connect(remC4))
            RegisterCleanup(function()
                for obj in pairs(c4Refs) do remC4(obj) end
                c4Folder:Destroy()
            end)
        end
    end

    do
        local BTState = {Enabled = false, Fade = true, Drawing = false, Lifetime = 0.2, Thickness = 2, Material = "Neon", Color = Color3.fromRGB(255, 200, 50), Opacity = 0.5}
            local btDrawings = {}
            local btMaterials = {}
            for _, mat in Enum.Material:GetEnumItems() do
                table.insert(btMaterials, mat.Name)
            end
            local btSection = VisualsPage:Section({Name = "Bullet Tracers", Side = 1})

            btSection:Toggle({Name = "Enabled", Flag = "BulletTracersEnabled", Default = false, Callback = function(v)
                BTState.Enabled = v
                if v then
                    PL.TracerHook:Add("BulletTracers", function(origin, dir)
                        if not BTState.Enabled then return end
                        local velocity = CFrame.lookAt(origin, dir).LookVector * 1000
                        if BTState.Drawing then
                            local obj = TrackDrawing(Drawing.new("Line"))
                            obj.Thickness = BTState.Thickness
                            obj.Color = BTState.Color
                            obj.Transparency = 1 - BTState.Opacity
                            btDrawings[obj] = {origin, origin + velocity, os.clock()}
                            task.delay(BTState.Lifetime, function()
                                btDrawings[obj] = nil
                                pcall(obj.Remove, obj)
                            end)
                        else
                            local obj = Instance.new("Part")
                            local thick = math.max(0.05, BTState.Thickness * 0.05)
                            obj.Size = Vector3.new(thick, thick, velocity.Magnitude)
                            obj.CFrame = CFrame.lookAt(origin + velocity / 2, origin + velocity)
                            obj.CanCollide, obj.CanQuery, obj.Anchored = false, false, true
                            obj.Material = Enum.Material[BTState.Material] or Enum.Material.Neon
                            obj.Color = BTState.Color
                            obj.Transparency = 1 - BTState.Opacity
                            obj.Parent = workspace
                            if BTState.Fade then
                                TweenService:Create(obj, TweenInfo.new(BTState.Lifetime), {Transparency = 1}):Play()
                            end
                            task.delay(BTState.Lifetime, obj.Destroy, obj)
                        end
                        return true
                    end, 1)
                else
                    PL.TracerHook:Remove("BulletTracers")
                end
            end})
            btSection:Dropdown({Name = "Material", Flag = "BulletTracersMaterial", Default = "Neon", Multi = false,
                Items = btMaterials, Callback = function(v) BTState.Material = v end})
            btSection:Slider({Name = "Thickness", Flag = "BulletTracersThickness", Min = 1, Max = 8, Default = 2, Decimals = 1, Callback = function(v) BTState.Thickness = v end})
            btSection:Slider({Name = "Opacity", Flag = "BulletTracersOpacity", Min = 0, Max = 1, Default = 0.5, Decimals = 0.01, Callback = function(v) BTState.Opacity = v end})
            btSection:Toggle({Name = "Fade", Flag = "BulletTracersFade", Default = true, Callback = function(v) BTState.Fade = v end})
            btSection:Toggle({Name = "Drawing", Flag = "BulletTracersDrawing", Default = false, Callback = function(v) BTState.Drawing = v end})
            btSection:Slider({Name = "Lifetime", Flag = "BulletTracersLifetime", Min = 0.05, Max = 0.5, Default = 0.2, Decimals = 0.01, Suffix = "s", Callback = function(v) BTState.Lifetime = v end})
            btSection:Toggle({Name = "Tracer Color", Flag = "BulletTracersUseColor", Default = true}):Colorpicker({
                Name = "Color", Flag = "BulletTracersColor", Default = BTState.Color, Callback = function(v) BTState.Color = v end
            })

            NewRender(function()
                for obj, data in btDrawings do
                    local from, vis = PLCamera:WorldToViewportPoint(data[1])
                    local to, vis2 = PLCamera:WorldToViewportPoint(data[2])
                    if vis and vis2 then
                        obj.Visible = true
                        obj.From = Vector2.new(from.X, from.Y)
                        obj.To = Vector2.new(to.X, to.Y)
                        if BTState.Fade then
                            local t = math.clamp((os.clock() - data[3]) / BTState.Lifetime, 0, 1)
                            obj.Transparency = (1 - BTState.Opacity) + BTState.Opacity * t
                        else
                            obj.Transparency = 1 - BTState.Opacity
                        end
                    else
                        obj.Visible = false
                    end
                end
            end)
    end

    do
        local vmTool, vmHandle, vmOldTool
        local vmAimLook = Vector3.new(0, 0, -1)
        local VMEnabled, VMSway, VMForceField = false, true, false
        local VMColor = Color3.fromRGB(0, 200, 255)
        local vmSection = VisualsPage:Section({Name = "Viewmodel", Side = 2})

        local function styleVmParts()
            if not vmTool then return end
            for _, v in vmTool:GetDescendants() do
                if v:IsA("BasePart") then
                    if VMForceField then
                        v.Material = Enum.Material.ForceField
                        v.Color = VMColor
                    end
                end
            end
        end

        local function restoreVmTool()
            if vmOldTool then
                for _, v in vmOldTool:GetDescendants() do
                    if v:IsA("BasePart") or v:IsA("Texture") or v:IsA("Decal") then
                        v.LocalTransparencyModifier = 0
                    end
                end
                vmOldTool = nil
            end
            if vmTool then
                vmTool:Destroy()
                vmTool, vmHandle = nil, nil
            end
        end

        local function onVmTool(tool)
            if not VMEnabled or not tool or not tool:IsA("Tool") then return end
            restoreVmTool()
            vmOldTool = tool
            vmTool = tool:Clone()
            vmHandle = vmTool:FindFirstChild("Handle")
            if not vmHandle then
                restoreVmTool()
                return
            end
            for _, v in vmTool:GetDescendants() do
                if v:IsA("Script") or v:IsA("LocalScript") then
                    v:Destroy()
                end
            end
            styleVmParts()
            vmTool.Parent = workspace.CurrentCamera
            for _, v in vmOldTool:GetDescendants() do
                if v:IsA("BasePart") or v:IsA("Texture") or v:IsA("Decal") then
                    v.LocalTransparencyModifier = 1
                end
            end
            vmAimLook = workspace.CurrentCamera.CFrame.LookVector
        end

        local function refreshVmTool()
            if not VMEnabled or not vmOldTool or not vmOldTool.Parent then return end
            onVmTool(vmOldTool)
        end

        vmSection:Toggle({
            Name = "Enabled",
            Flag = "ViewmodelEnabled",
            Default = false,
            Callback = function(v)
                VMEnabled = v
                if not v then
                    restoreVmTool()
                else
                    local char = LocalPlayer.Character
                    local t = char and char:FindFirstChildWhichIsA("Tool")
                    if t then onVmTool(t) end
                end
            end
        })
        vmSection:Toggle({Name = "Sway", Flag = "ViewmodelSway", Default = true, Callback = function(v) VMSway = v end})
        vmSection:Toggle({
            Name = "ForceField",
            Flag = "ViewmodelForceField",
            Default = false,
            Callback = function(v)
                VMForceField = v
                refreshVmTool()
            end
        })
        vmSection:Toggle({Name = "Tint", Flag = "ViewmodelUseColor", Default = true}):Colorpicker({
            Name = "Color",
            Flag = "ViewmodelColor",
            Default = VMColor,
            Callback = function(v)
                VMColor = v
                styleVmParts()
            end
        })

        TrackConnection(LocalPlayer.CharacterAdded:Connect(function(char)
            restoreVmTool()
            TrackConnection(char.ChildAdded:Connect(function(c)
                if c:IsA("Tool") then onVmTool(c) end
            end))
            TrackConnection(char.ChildRemoved:Connect(function(c)
                if c == vmOldTool then restoreVmTool() end
            end))
            local t = char:FindFirstChildWhichIsA("Tool")
            if t then onVmTool(t) end
        end))

        NewRender(function(dt)
            if not VMEnabled or not vmHandle then return end
            local cam = workspace.CurrentCamera
            PLCamera = cam

            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local vmMove = root and root.AssemblyLinearVelocity * 0.005 or Vector3.zero
            if vmMove.Magnitude > 0.1 and VMSway then
                vmMove = vmMove + (cam.CFrame * CFrame.new(math.sin(os.clock() * 10) * 0.06, 0, 0)).Position - cam.CFrame.Position
            end

            local cf = (cam.CFrame * CFrame.new(2, -1.5, -3)) + vmMove
            local targetLook = cam.CFrame.LookVector
            if aimTimer > os.clock() then
                targetLook = CFrame.lookAt(cf.Position, aimVec).LookVector
            end
            vmAimLook = vmAimLook:Lerp(targetLook, math.min(1, 15 * dt)).Unit

            local recoil = math.max(shootTimer - os.clock(), 0)
            vmHandle.CFrame = CFrame.lookAlong(cf.Position, vmAimLook) * CFrame.new(0, 0, recoil)
            vmHandle.AssemblyLinearVelocity = Vector3.zero
        end)

        RegisterCleanup(restoreVmTool)
    end

    do

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

        local FFSection = VisualsPage:Section({Name = "ForceField Material", Side = 1}) do
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

        local DoorStorage = game:GetService("Lighting")
        local StorageName = "catnipDoorStorage"

        local RemoveDoors = WorldPage:Section({Name = "Remove Doors", Side = 1}) do
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

        local BypassDoors = WorldPage:Section({Name = "Bypass Doors", Side = 1}) do
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

        local AmbientSection = WorldPage:Section({Name = "Ambient & Brightness", Side = 1}) do
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

        local TimeSection = WorldPage:Section({Name = "Time of Day", Side = 1}) do
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

        local FogSection = WorldPage:Section({Name = "Fog", Side = 2}) do
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

        local SkySection = WorldPage:Section({Name = "Sky & Color Shift", Side = 2}) do
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
                    Description = "Shows notifications for killfeed entries (including when you are killed)"
                },
                Flag = "KillfeedNotificationsEnabled",
                Default = false,
                Callback = function(v) KillfeedNotificationsEnabled = v end
            })
        end
    end

    do
        local AutoBLSection = CombatPage:Section({Name = "Auto Blacklist", Side = 2}) do
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
        local MonoAudio = CombatPage:Section({Name = "Center Gun Audio", Side = 2}) do
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
        local RemoveJumpCooldown = MovementPage:Section({Name = "Remove Jump Cooldown", Side = 2}) do
            local NJCEnabled = false
            local jumpConnDisabled = nil
            local function onCharacterAdded(character)
                local humanoid = character:WaitForChild("Humanoid", 10)
                if not humanoid or not NJCEnabled then return end
                local conns = getconnections(humanoid:GetPropertyChangedSignal("Jump"))
                if conns[1] then
                    jumpConnDisabled = conns[1]
                    jumpConnDisabled:Disable()
                end
            end
            RemoveJumpCooldown:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Remove Jump Cooldown",
                    Description = "Disables the humanoid jump cooldown connection"
                },
                Flag = "RemoveJumpCooldownEnabled",
                Default = false,
                Callback = function(v)
                    NJCEnabled = v
                    if v then
                        if LocalPlayer.Character then task.spawn(onCharacterAdded, LocalPlayer.Character) end
                    elseif jumpConnDisabled then
                        pcall(function() jumpConnDisabled:Enable() end)
                        jumpConnDisabled = nil
                    end
                end
            })
            TrackConnection(LocalPlayer.CharacterAdded:Connect(function(char)
                if NJCEnabled then onCharacterAdded(char) end
            end))
            RegisterCleanup(function()
                if jumpConnDisabled then pcall(function() jumpConnDisabled:Enable() end) end
            end)
        end
    end

    do
        local AntiInvisible = CombatPage:Section({Name = "Anti Invisible", Side = 2}) do
            local AIEnabled = false
            local invisAnimId = "215384594"
            local tracked = {}

            local function hookAnimator(animator)
                if tracked[animator] then return end
                tracked[animator] = TrackConnection(animator.AnimationPlayed:Connect(function(anim)
                    if not AIEnabled then return end
                    if anim.Animation and anim.Animation.AnimationId:find(invisAnimId) then
                        anim:AdjustWeight(0)
                    end
                end))
                for _, track in animator:GetPlayingAnimationTracks() do
                    if track.Animation and track.Animation.AnimationId:find(invisAnimId) then
                        track:AdjustWeight(0)
                    end
                end
            end

            local function onCharacter(character)
                local humanoid = character:WaitForChild("Humanoid", 8)
                if humanoid then
                    local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
                    if animator then hookAnimator(animator) end
                end
            end

            AntiInvisible:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Anti Invisible",
                    Description = "Zeroes weight on the invisibility animation (Vape AdjustWeight)"
                },
                Flag = "AntiInvisibleEnabled",
                Default = false,
                Callback = function(v)
                    AIEnabled = v
                    if v then
                        for _, player in PlayersService:GetPlayers() do
                            if player ~= LocalPlayer and player.Character then onCharacter(player.Character) end
                        end
                    end
                end
            })
            TrackConnection(PlayersService.PlayerAdded:Connect(function(player)
                TrackConnection(player.CharacterAdded:Connect(function(char)
                    if AIEnabled then onCharacter(char) end
                end))
            end))
            for _, player in PlayersService:GetPlayers() do
                if player ~= LocalPlayer then
                    TrackConnection(player.CharacterAdded:Connect(function(char)
                        if AIEnabled then onCharacter(char) end
                    end))
                end
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
        local AntiTase = CombatPage:Section({Name = "Anti Tase", Side = 2}) do
            local ATEnabled = false
            local taseOldFn, taseConn = nil, nil
            local PlayerTased = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("PlayerTased")

            local function hookTaseHandler()
                if taseOldFn then return end
                taseConn = getconnections(PlayerTased.OnClientEvent)[1]
                if not (taseConn and taseConn.Function) then return end
                taseOldFn = hookfunction(taseConn.Function, function()
                    local char = LocalPlayer.Character
                    LocalPlayer:SetAttribute("BackpackEnabled", false)
                    if char then
                        local humanoid = char:FindFirstChildOfClass("Humanoid")
                        if humanoid then humanoid:UnequipTools() end
                    end
                    task.wait(3.5)
                    if LocalPlayer.Character == char then
                        LocalPlayer:SetAttribute("BackpackEnabled", true)
                    end
                end)
            end

            local function unhookTaseHandler()
                if taseOldFn and taseConn and taseConn.Function then
                    hookfunction(taseConn.Function, taseOldFn)
                    taseOldFn = nil
                end
            end

            AntiTase:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Anti Tase",
                    Description = "Hooks PlayerTased: brief backpack lock then restore (Vape)"
                },
                Flag = "AntiTaseEnabled",
                Default = false,
                Callback = function(v)
                    ATEnabled = v
                    if v then hookTaseHandler() else unhookTaseHandler() end
                end
            })
            TrackConnection(LocalPlayer.CharacterAdded:Connect(function()
                if ATEnabled then
                    unhookTaseHandler()
                    task.defer(hookTaseHandler)
                end
            end))
            RegisterCleanup(unhookTaseHandler)
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
            local pickupItems = {}
            local GiverRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GiverPressed")

            local function addPickup(obj)
                if obj:IsA("Model") and obj.Name ~= "TouchGiver" and obj.Name ~= "Model" and obj:GetAttribute("ToolName") then
                    table.insert(pickupItems, obj)
                end
            end

            PickupAura:Toggle({
                Name = "Enabled",
                ToolTip = {
                    Name = "Pickup Aura",
                    Description = "Auto-pickup ToolName models in range (GiverPressed); select items, radius, and cooldown"
                },
                Flag = "PickupAuraEnabled",
                Default = false,
                Callback = function(v)
                    PAState.Enabled = v
                    if v then
                        for _, obj in workspace:GetChildren() do task.spawn(addPickup, obj) end
                    else
                        table.clear(pickupItems)
                    end
                end
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

            PickupAura:Slider({
                Name = "Cooldown",
                Flag = "PickupAuraCooldown",
                Min = 0.1,
                Max = 1,
                Default = 0.5,
                Suffix = "s",
                Decimals = 0.1,
                Callback = function(v) PAState.Cooldown = v end
            })

            TrackConnection(workspace.ChildAdded:Connect(function(obj)
                if PAState.Enabled then addPickup(obj) end
            end))
            TrackConnection(workspace.ChildRemoved:Connect(function(obj)
                local idx = table.find(pickupItems, obj)
                if idx then table.remove(pickupItems, idx) end
            end))

            task.spawn(function()
                while ScriptAlive do
                    if PAState.Enabled and next(PAState.Items) and LocalPlayer.Character then
                        local now = tick()
                        if (now - PALastTick) >= PAState.Cooldown then
                            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            local backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
                            if root and backpack then
                                local pos = root.Position
                                for _, model in pickupItems do
                                    local toolName = model:GetAttribute("ToolName")
                                    if toolName and PAState.Items[toolName] and model.PrimaryPart then
                                        if (model.PrimaryPart.Position - pos).Magnitude <= PAState.Radius then
                                            if not backpack:FindFirstChild(toolName) then
                                                PALastTick = now
                                                pcall(GiverRemote.FireServer, GiverRemote, model)
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.1)
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
                HandCheck = false,
                CooldownBar = false,
                ShowRadius = false,
                ShowTarget = false,
                Radius = 8,
                Whitelist = {},
            }
            local arrestCooldown = 0
            local cdHolder, cdFrame, cdLabel

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
                Min = 1,
                Max = 8,
                Default = 8,
                Suffix = " studs",
                Decimals = 1,
                Callback = function(v) AAState.Radius = v end
            })

            ArrestAura:Toggle({
                Name = "Hand Check",
                ToolTip = {Name = "Hand Check", Description = "Only arrest when Handcuffs equipped"},
                Flag = "ArrestAuraHandCheck",
                Default = false,
                Callback = function(v) AAState.HandCheck = v end
            })

            ArrestAura:Toggle({
                Name = "Cooldown Bar",
                Flag = "ArrestAuraCooldownBar",
                Default = false,
                Callback = function(v)
                    AAState.CooldownBar = v
                    if v and not cdHolder then
                        cdHolder = Instance.new("Frame")
                        cdHolder.BorderSizePixel = 0
                        cdHolder.BackgroundTransparency = 0.7
                        cdHolder.AnchorPoint = Vector2.new(0.5, 0)
                        cdHolder.BackgroundColor3 = Color3.new(1, 1, 1)
                        cdHolder.Size = UDim2.new(0.1, 0, 0, 5)
                        cdHolder.Position = UDim2.fromScale(0.5, 0.55)
                        cdHolder.Parent = game:GetService("CoreGui")
                        cdFrame = Instance.new("Frame")
                        cdFrame.BorderSizePixel = 0
                        cdFrame.BackgroundTransparency = 0.3
                        cdFrame.BackgroundColor3 = Color3.new(1, 1, 1)
                        cdFrame.Size = UDim2.new(1, -2, 1, -2)
                        cdFrame.Position = UDim2.fromOffset(1, 1)
                        cdFrame.Parent = cdHolder
                        cdLabel = Instance.new("TextLabel")
                        cdLabel.Size = UDim2.new(1, 0, 0, 14)
                        cdLabel.Position = UDim2.fromOffset(0, 10)
                        cdLabel.BackgroundTransparency = 1
                        cdLabel.TextColor3 = Color3.new(1, 1, 1)
                        cdLabel.TextScaled = true
                        cdLabel.TextStrokeTransparency = 0
                        cdLabel.Font = Enum.Font.Arial
                        cdLabel.Parent = cdHolder
                        RegisterCleanup(function()
                            if cdHolder then cdHolder:Destroy() cdHolder = nil end
                        end)
                    elseif not v and cdHolder then
                        cdHolder:Destroy()
                        cdHolder, cdFrame, cdLabel = nil, nil, nil
                    end
                end
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

                if cdHolder and AAState.CooldownBar then
                    cdHolder.Visible = arrestCooldown > os.clock()
                    if cdHolder.Visible and cdFrame and cdLabel then
                        local diff = arrestCooldown - os.clock()
                        cdFrame.Size = UDim2.new(math.clamp(diff / 7, 0, 1), -2, 1, -2)
                        cdLabel.Text = string.format("%.1fs", diff)
                    end
                end

                local canArrest = arrestCooldown < os.clock()
                if AAState.HandCheck then
                    local tool = character:FindFirstChildWhichIsA("Tool")
                    canArrest = canArrest and tool and tool.Name == "Handcuffs"
                end

                if closestPlayer and canArrest then
                    local targetRoot = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local tChar = closestPlayer.Character
                    if targetRoot and tChar and not tChar:GetAttribute("Arrested") then
                        if closestPlayer.Team == Teams.Inmates and tChar:GetAttribute("Hostile") and not tChar:GetAttribute("Tased") then
                            closestPlayer = nil
                        end
                    end
                else
                    closestPlayer = nil
                end

                if closestPlayer then
                    local targetRoot = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if targetRoot then
                        local success, didArrest = pcall(function()
                            return ArrestRemote:InvokeServer(closestPlayer, 1)
                        end)
                        if success and didArrest then
                            arrestCooldown = os.clock() + 7
                            Library:Notification("Auto Arrest", "Arrested " .. closestPlayer.Name, 3)
                        end

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
        local FistAura = CombatPage:Section({Name = "Fist Aura", Side = 2}) do
            local Players = game:GetService("Players")
            local LocalPlayer = Players.LocalPlayer
            local MeleeRemote = game:GetService("ReplicatedStorage"):WaitForChild("meleeEvent")

            local FAState = {
                Enabled = false,
                FriendCheck = false,
                ShowRadius = false,
                ShowTarget = false,
                Radius = 12,
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
                Min = 1,
                Max = 12,
                Default = 12,
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

                local entities = PLTargeting.allPositions({
                    Origin = rootPart.Position,
                    Range = FAState.Radius,
                    Bone = "HumanoidRootPart",
                    AttackCheck = true,
                    Wallcheck = false,
                    Filters = {
                        Teams = FAState.Teams,
                        InmateTypes = FAState.InmateTypes,
                        FriendCheck = FAState.FriendCheck,
                        Whitelist = FAState.Whitelist,
                    },
                })
                local closestPlayer = entities[1] and entities[1].Player or nil

                if closestPlayer then
                    local targetRoot = closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart")
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
                    Description = "Sets RiotShieldPart CanQuery false so bullets pass through"
                },
                Flag = "AntiRiotShieldEnabled",
                Default = false
            }) do
                local shieldModified = {}
                NewRender(function()
                    if Enabled:Get() ~= true then
                        for shield, orig in pairs(shieldModified) do
                            if shield.Parent then shield.CanQuery = orig end
                        end
                        table.clear(shieldModified)
                        return
                    end
                    for _, player in pairs(PlayersService:GetPlayers()) do
                        local character = player.Character
                        if not character then continue end
                        local shield = character:FindFirstChild("RiotShieldPart")
                        if shield and shield:IsA("BasePart") then
                            if not shieldModified[shield] then shieldModified[shield] = shield.CanQuery end
                            shield.CanQuery = false
                        end
                    end
                end)
                RegisterCleanup(function()
                    for shield, orig in pairs(shieldModified) do
                        if shield.Parent then shield.CanQuery = orig end
                    end
                end)
            end
        end
    end

    do
        local AntiKillPlaneSection = WorldPage:Section({Name = "Anti Kill Plane", Side = 2})
        local killPlaneParts = {}
        AntiKillPlaneSection:Toggle({
            Name = "Enabled",
            Flag = "AntiKillPlaneEnabled",
            Default = false,
            Callback = function(v)
                if v then
                    for x = -2048, 2048, 2048 do
                        for z = -2048, 2048, 2048 do
                            local part = Instance.new("Part")
                            part.CanQuery = false
                            part.CanCollide = true
                            part.Anchored = true
                            part.Transparency = 1
                            part.Size = Vector3.new(2048, 10, 2048)
                            part.Position = Vector3.new(x, 170, z)
                            part.Parent = workspace
                            table.insert(killPlaneParts, part)
                        end
                    end
                else
                    for _, part in killPlaneParts do pcall(part.Destroy, part) end
                    table.clear(killPlaneParts)
                end
            end
        })
        RegisterCleanup(function()
            for _, part in killPlaneParts do pcall(part.Destroy, part) end
            table.clear(killPlaneParts)
        end)
    end

    do
        local AutoResetSection = MiscPage:Section({Name = "Auto Reset", Side = 2})
        local criminalsTeam = Teams:FindFirstChild("Criminals")
        local autoResetConn
        AutoResetSection:Toggle({
            Name = "Enabled",
            Flag = "AutoResetEnabled",
            Default = false,
            Callback = function(v)
                if autoResetConn then autoResetConn:Disconnect() autoResetConn = nil end
                if v then
                    autoResetConn = LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
                        if criminalsTeam and LocalPlayer.Team == criminalsTeam and LocalPlayer.Character then
                            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            if hum then hum:ChangeState(Enum.HumanoidStateType.Dead) end
                        end
                    end)
                    TrackConnection(autoResetConn)
                end
            end
        })
    end

    do
        local RagebotSection = RagebotPage:Section({Name = "Ragebot", Side = 1})
        local RagebotConfigSection = RagebotPage:Section({Name = "Ragebot Config", Side = 2})

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
        if not ScriptAlive then
            return OriginalUnload(self)
        end
        ScriptAlive = false

        RagebotForcedTarget = nil
        RagebotMuzzleOrigin = nil
        PingWarningEnabled = false
        KillfeedNotificationsEnabled = false
        ItemESPState.Enabled = false

        StopAllRenderers()

        for i = #CleanupCallbacks, 1, -1 do
            pcall(CleanupCallbacks[i])
        end
        table.clear(CleanupCallbacks)

        for _, conn in TrackedConnections do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(TrackedConnections)

        for _, drawing in TrackedDrawings do
            pcall(function()
                if drawing.Remove then
                    drawing:Remove()
                elseif drawing.Destroy then
                    drawing:Destroy()
                end
            end)
        end
        table.clear(TrackedDrawings)

        pcall(function()
            if ItemESPChamsFolder and ItemESPChamsFolder.Parent then
                ItemESPChamsFolder:Destroy()
            end
        end)

        pcall(function()
            local lp = game:GetService("Players").LocalPlayer
            local char = lp and lp.Character
            if not char then return end
            for _, v in char:GetDescendants() do
                if v:IsA("BasePart") or v:IsA("Texture") or v:IsA("Decal") then
                    v.LocalTransparencyModifier = 0
                end
            end
            local cam = workspace.CurrentCamera
            if cam then
                for _, child in cam:GetChildren() do
                    if child:IsA("Tool") then
                        child:Destroy()
                    end
                end
            end
        end)

        OriginalUnload(self)
    end
end
