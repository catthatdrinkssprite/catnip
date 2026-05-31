local Library = loadstring(game:HttpGet("https://github.com/catthatdrinkssprite/catnip/raw/main/library/Library.lua"))()

local Window = Library:Window({
    Logo = "rbxassetid://77218680285262",
    FadeTime = 0.3,
})

local Watermark = Library:Watermark("This is a watermark")
local KeybindList = Library:KeybindList()

do 
    local CombatPage = Window:Page({Name = "Combat", SubPages = true})
    local PlayerPage = Window:Page({Name = "Player", Columns = 2})
    local VisualsPage = Window:Page({Name = "Visuals", Columns = 2})
    local PlayersPage = Window:Page({Name = "Players", Columns = 2})
    local SettingsPage = Library:CreateSettingsPage(Window, Watermark, KeybindList) 
    local Playerlist = PlayersPage:Playerlist({
        Callback = function(...)
            local Args = { ... }
            table.foreach(Args, print)
        end
    })
    
    do -- Combat page
        local WeaponSubPage = CombatPage:SubPage({Name = "Weapon", Columns = 2})
        local AimbotSubPage = CombatPage:SubPage({Name = "Aimbot", Columns = 2}) 

        do -- Weapon subpage
            local RangedWeaponSection = WeaponSubPage:Section({Name = "Ranged Weapons", Side = 1}) do -- Ranged weapon section
                RangedWeaponSection:Toggle({
                    Name = "Enabled",
                    Flag = "RangedWeaponEnabled",
                    Default = false,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Toggle:SetVisibility(<bool>) -> nil
                --Toggle:Set(<bool>) -> nil
                --Toggle:Get(<void>) -> Toggle.Value

                RangedWeaponSection:Toggle({
                    Name = "Instant hit",
                    Flag = "RangedWeaponInstantHit",
                    Default = false,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Toggle:SetVisibility(<bool>) -> nil
                --Toggle:Set(<bool>) -> nil
                --Toggle:Get(<void>) -> Toggle.Value

                RangedWeaponSection:Toggle({
                    Name = "Rapid fire",
                    Flag = "RangedWeaponRapidFire",
                    Default = false,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Toggle:SetVisibility(<bool>) -> nil
                --Toggle:Set(<bool>) -> nil
                --Toggle:Get(<void>) -> Toggle.Value

                RangedWeaponSection:Toggle({
                    Name = "Full auto",
                    Flag = "RangedWeaponFullAuto",
                    Default = false,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Toggle:SetVisibility(<bool>) -> nil
                --Toggle:Set(<bool>) -> nil
                --Toggle:Get(<void>) -> Toggle.Value

                RangedWeaponSection:Slider({
                    Name = "Reload time",
                    Flag = "RangedWeaponReloadTime",
                    Min = 0,
                    Suffix = "s",
                    Max = 5,
                    Default = 0,
                    Decimals = 0.01,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Slider:SetVisibility(<bool>) -> nil
                --Slider:Set(<number>) -> nil
                --Slider:Get(<void>) -> Slider.Value

                RangedWeaponSection:Dropdown({
                    Name = "Mode",
                    Items = {"Burst", "Auto", "Single"},
                    Flag = "RangedWeaponMode",
                    Default = "Burst",
                    Multi = false,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Dropdown:SetVisibility(<bool>) -> nil
                --Dropdown:Set(<string>) -> nil
                --Dropdown:Get(<void>) -> Dropdown.Value
                --Dropdown:Add(<string>) -> OptionData
                --Dropdown:Remove(<string>) -> nil
                --Dropdown:Refresh(<table>, <boolean>) -> nil   

                local Button = RangedWeaponSection:Button()
                Button:Add("Apply", function()
                    print("Pressed")
                end)
                Button:Add("Reset", function()
                    print("Pressed 2")
                end)

                --Button:Add(<string>, <function>)
            end
        end

        do -- Aimbot subpage
            local SilentAimSection = AimbotSubPage:Section({Name = "Silent Aim", Side = 1}) do -- Silent aim section
                SilentAimSection:Toggle({
                    Name = "Enabled",
                    ToolTip = {
                        Name = "Silent aim",
                        Description = "Redirects bullets to the closest target from the mouse"
                    },
                    Flag = "SilentAimEnabled",
                    Default = false,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Toggle:SetVisibility(<bool>) -> nil
                --Toggle:Set(<bool>) -> nil
                --Toggle:Get(<void>) -> Toggle.Value

                local Toggle = SilentAimSection:Toggle({
                    Name = "FoV Circle",
                    Flag = "SilentAimFoVEnabled",
                    Default = false,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Toggle:SetVisibility(<bool>) -> nil
                --Toggle:Set(<bool>) -> nil
                --Toggle:Get(<void>) -> Toggle.Value

                Toggle:Colorpicker({
                    Name = "FoV",
                    Flag = "SilentAimFoV",
                    Default = Library.Theme.Accent,
                    Alpha = 0,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Colorpicker:SetVisibility(<bool>) -> nil
                --Colorpicker:Set(<Color3>) -> nil
                --Colorpicker:Get(<void>) -> Color3
                --Colorpicker:SlidePalette(<InputObject>) -> nil
                --Colorpicker:SlideHue(<InputObject>) -> nil
                --Colorpicker:SlideAlpha(<InputObject>) -> nil
                --Colorpicker:Update(<boolean>, <boolean>) -> nil
                --Colorpicker:Set(<Color3>, <number>) -> nil

                Toggle:Colorpicker({
                    Name = "FoV",
                    Flag = "SilentAimFoVOutline",
                    Default = Color3.fromRGB(0, 0, 0),
                    Alpha = 0,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Colorpicker:SetVisibility(<bool>) -> nil
                --Colorpicker:Set(<Color3>) -> nil
                --Colorpicker:Get(<void>) -> Color3
                --Colorpicker:SlidePalette(<InputObject>) -> nil
                --Colorpicker:SlideHue(<InputObject>) -> nil
                --Colorpicker:SlideAlpha(<InputObject>) -> nil
                --Colorpicker:Update(<boolean>, <boolean>) -> nil
                --Colorpicker:Set(<Color3>, <number>) -> nil

                SilentAimSection:Dropdown({
                    Name = "Bone",
                    Flag = "SilentAimBone",
                    Default = "Head",
                    Multi = false,
                    Items = {"Head", "Penis", "Ass", "Thigh", "Tits"},
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Dropdown:SetVisibility(<bool>) -> nil
                --Dropdown:Set(<string>) -> nil
                --Dropdown:Get(<void>) -> Dropdown.Value
                --Dropdown:Add(<string>) -> OptionData
                --Dropdown:Remove(<string>) -> nil
                --Dropdown:Refresh(<table>, <boolean>) -> nil   

                SilentAimSection:Toggle({
                    Name = "Manipulation",
                    Flag = "SilentAimManipulation",
                    Default = false,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Toggle:SetVisibility(<bool>) -> nil
                --Toggle:Set(<bool>) -> nil
                --Toggle:Get(<void>) -> Toggle.Value

                SilentAimSection:Slider({
                    Name = "Radius",
                    Flag = "FoVRadius",
                    Min = 1,
                    Suffix = "px",
                    Max = 500,
                    Default = 75,
                    Decimals = 1,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Slider:SetVisibility(<bool>) -> nil
                --Slider:Set(<number>) -> nil
                --Slider:Get(<void>) -> Slider.Value

                SilentAimSection:Toggle({
                    Name = "Wall Check",
                    Flag = "SilentAimFoVWallCheck",
                    Default = false,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Toggle:SetVisibility(<bool>) -> nil
                --Toggle:Set(<bool>) -> nil
                --Toggle:Get(<void>) -> Toggle.Value

                SilentAimSection:Toggle({
                    Name = "Team Check",
                    Flag = "SilentAimFoVTeamCheck",
                    Default = false,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Toggle:SetVisibility(<bool>) -> nil
                --Toggle:Set(<bool>) -> nil
                --Toggle:Get(<void>) -> Toggle.Value

                SilentAimSection:Toggle({
                    Name = "Death Check",
                    Flag = "SilentAimFoVDeathCheck",
                    Default = false,
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Toggle:SetVisibility(<bool>) -> nil
                --Toggle:Set(<bool>) -> nil
                --Toggle:Get(<void>) -> Toggle.Value
            end

            local AimbotSection = AimbotSubPage:Section({Name = "Camera", Side = 2}) do -- Aimbot section
                AimbotSection:Toggle({
                    Name = "Enabled",
                    Flag = "AimbotEnabled",
                    Default = false,
                    Callback = function(Value)
                        print(Value)
                    end
                }):Keybind({
                    Flag = "AimbotKeybind",
                    Default = Enum.KeyCode.E,
                    Mode = "Toggle",
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Toggle:SetVisibility(<bool>) -> nil
                --Toggle:Set(<bool>) -> nil
                --Toggle:Get(<void>) -> Toggle.Value

                --Keybind:Get(<void>) -> Keybind.Key, Keybind.Mode, Keybind.Toggled
                --Keybind:Set(<EnumItem>/<table>/<string>) -> nil
                --Keybind:SetMode(<string>) -> nil
                --Keybind:Press(<void>) -> nil

                AimbotSection:Searchbox({
                    Name = "Searchbox",
                    Flag = "Searchbox",
                    Items = {"Option 1", "Option 2", "Option 3", "Option 4", "Option 5", "Option 6", "Option 7", "Option 8", "Option 9", "Option 10", "Option 11"},
                    Multi = false,
                    Default = "Option 1",
                    Callback = function(Value)
                        print(Value)
                    end
                })

                --Searchbox:SetVisibility(<bool>) -> nil
                --Searchbox:Set(<string>) -> nil
                --Searchbox:Get(<void>) -> Searchbox.Value
                --Searchbox:Add(<string>) -> OptionData
                --Searchbox:Remove(<string>) -> nil
                --Searchbox:Refresh(<table>, <boolean>) -> nil   
            end
        end
    end
end

Library:Notification("Loaded!", "Menu took "..string.format("%.4f", os.clock() - LoadTick).." seconds to load", 5)