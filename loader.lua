local QuartzOk, Quartz = pcall(function()
    return loadstring(game:HttpGet("https://github.com/notpoiu/Quartz/releases/latest/download/Quartz.luau"))()
end)

if QuartzOk and Quartz then
    local Tester = Quartz.new({ Timeout = 5, AllowFFlagPolyfills = true })
    Tester:TestAll()
    Tester:PatchEnvironment()
end

local BASE_URL = "https://github.com/catthatdrinkssprite/moonshine/raw/main"

local Folders = {
    "moonshine",
    "moonshine/images",
    "moonshine/txts",
    "moonshine/sounds",
}

local Assets = {
    ["moonshine/images/cover.png"]           = "moonshine/images/embedcover.png",
    ["moonshine/images/embedcover.png"]           = "moonshine/images/embedcover.png",
    ["moonshine/images/moon.png"]           = "moonshine/images/moon.png",
    ["moonshine/images/paw.png"]           = "moonshine/images/paw.png",
    ["moonshine/images/W AZULA.png"]        = "moonshine/images/W%20AZULA.png",
    ["moonshine/txts/W AZULA.txt"]          = "moonshine/txts/W%20AZULA.txt",
    ["moonshine/sounds/12.mp3"]             = "moonshine/sounds/12.mp3",
    ["moonshine/sounds/agpa2.mp3"]          = "moonshine/sounds/agpa2.mp3",
    ["moonshine/sounds/basshit.mp3"]        = "moonshine/sounds/basshit.mp3",
    ["moonshine/sounds/bell.mp3"]           = "moonshine/sounds/bell.mp3",
    ["moonshine/sounds/blizzard.mp3"]       = "moonshine/sounds/blizzard.mp3",
    ["moonshine/sounds/bubble.mp3"]         = "moonshine/sounds/bubble.mp3",
    ["moonshine/sounds/chockpro.mp3"]       = "moonshine/sounds/chockpro.mp3",
    ["moonshine/sounds/cod.mp3"]            = "moonshine/sounds/cod.mp3",
    ["moonshine/sounds/copperbell.mp3"]     = "moonshine/sounds/copperbell.mp3",
    ["moonshine/sounds/crowbar.mp3"]        = "moonshine/sounds/crowbar.mp3",
    ["moonshine/sounds/headshot.mp3"]        = "moonshine/sounds/headshot.mp3",
    ["moonshine/sounds/knob.mp3"]           = "moonshine/sounds/knob.mp3",
    ["moonshine/sounds/minecraft orb.mp3"]  = "moonshine/sounds/minecraft%20orb.mp3",
    ["moonshine/sounds/neverlose.mp3"]      = "moonshine/sounds/neverlose.mp3",
    ["moonshine/sounds/rust.mp3"]           = "moonshine/sounds/rust.mp3",
    ["moonshine/sounds/skeet.mp3"]          = "moonshine/sounds/skeet.mp3",
    ["moonshine/skyboxes.json"]              = "moonshine/skyboxes.json",
}

for _, folder in Folders do
    if not isfolder(folder) then
        makefolder(folder)
    end
end

local Library = loadstring(game:HttpGet(BASE_URL .. "/libraries/scoot/Library.lua", true))()

local logoPath = "moonshine/images/moon.png"
local logoImage = isfile(logoPath) and getcustomasset(logoPath) or ""

local Popup = Library:LoadingPopup({
    Logo = logoImage,
    Status = "Initializing...",
})

local AssetKeys = {}
for k in Assets do
    table.insert(AssetKeys, k)
end
local TotalAssets = #AssetKeys
local FailedAssets = {}

for i, localPath in AssetKeys do
    if not isfile(localPath) then
        local shortName = string.match(localPath, "[^/]+$") or localPath
        Popup:SetStatus("Downloading " .. shortName)
        Popup:SetProgress(i / TotalAssets)

        local ok, data = pcall(game.HttpGet, game, BASE_URL .. "/" .. Assets[localPath], true)
        if ok then
            writefile(localPath, data)
        else
            table.insert(FailedAssets, localPath)
        end
    else
        Popup:SetProgress(i / TotalAssets)
    end
end

Popup:SetProgress(1)

if #FailedAssets > 0 then
    Library:Notification("Download Failed.", "Could not download: " .. table.concat(FailedAssets, ", "), 8)
end

Popup:SetStatus("Checking compatibility...")

local RequiredFunctions = {
    "hookmetamethod", "newcclosure", "getnamecallmethod",
    "checkcaller", "mouse1click", "Drawing",
    "isfolder", "makefolder", "isfile", "writefile", "readfile", "loadstring",
}

local MissingFunctions = {}
for _, name in RequiredFunctions do
    if typeof(getfenv()[name]) ~= "function" and typeof(getgenv()[name]) ~= "function" and typeof(getfenv()[name]) ~= "table" then
        table.insert(MissingFunctions, name)
    end
end

if #MissingFunctions > 0 then
    Popup:Dismiss()
    Library:Notification("Incompatible Executor", "Missing: " .. table.concat(MissingFunctions, ", "), 10)
    warn("[moonshine] Executor is missing critical functions even after Quartz polyfill: " .. table.concat(MissingFunctions, ", "))
    return
end

Popup:SetStatus("Loading game script...")

local success, result = pcall(function()
    return loadstring(game:HttpGet(string.format("%s/games/%s.lua", BASE_URL, game.PlaceId), true))
end)

if success and type(result) == "function" then
    Popup:SetStatus("Starting...")
    task.wait(0.3)
    Popup:Dismiss()
    result()
else
    Popup:Dismiss()
    Library:Notification("Failed to load.", "Game may not be supported, Check the github for supported games!", 5)
end
