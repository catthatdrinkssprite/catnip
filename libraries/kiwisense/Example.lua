local Library = loadstring(game:HttpGet("https://github.com/catthatdrinkssprite/moonshine/raw/main/libraries/kiwisense/Library.lua"))()

--
-- Example
do
    local Window = Library:Window({
        Name = "kiwisense",
        Version = "v2.1",
        Logo = "135215559087473",
        FadeSpeed = 0.25,
        --Size = UDim2.new(0, 659, 0, 511)
    })

    local ESPPreview = Library:ESPPreview({
        MainFrame = Window.Items["MainFrame"] -- keep this
    })

    local ChatSystem = Library:ChatSystem({
        MainFrame = Window.Items["MainFrame"] -- keep this
    })

    local Watermark = Library:Watermark("This is a watermark", "135215559087473")
    Watermark:SetVisibility(false)
    local KeybindList = Library:KeybindsList()
    KeybindList:SetVisibility(false)

    local Name = "spongebob"
    local Status = false
    local Avatar = "rbxassetid://78993485446406"
    local Count = 0
    ChatSystem:OnMessageSendPressed(function()
        Count += 1
        if Count == 1 then
            Avatar = "rbxassetid://78993485446406"
            Name = "spongebob"
            Status = true
        elseif Count == 2 then
            Avatar = "rbxassetid://136061992085389"
            Name = "patrick"
            Status = false
        elseif Count == 3 then
            Avatar = "rbxassetid://92657697206261"
            Count = 0
            Name = "squidward"
            Status = false
        end
        ChatSystem:SendMessage(Avatar, Name, ChatSystem:GetTypedMessage(), Status)
    end)

    do
        local Pages = {
            ["Combat"] = Window:Page({
                Name = "pvp", 
                Icon = "111178525804834",
                SubPages = true,
            }),
            
            ["Visuals"] = Window:Page({
                Name = "visuals", 
                Icon = "115907015044719", 
                Columns = 2
            }),

            ["Misc"] = Window:Page({
                Name = "misc", 
                Icon = "136623465713368", 
                Columns = 2
            }),

            ["Movement"] = Window:Page({
                Name = "movement", 
                Icon = "109463522861706", 
                Columns = 2
            }),

            ["Settings"] = Window:Page({
                Name = "settings", 
                Icon = "137300573942266", 
                Columns = 2,
                SubPages = true
            })
        }

        do -- Misc
            local Playerlist = Pages["Misc"]:Playerlist({
                Callback = function(...)
                    local Args = {...}
                    table.foreach(Args, print)
                end
            })
        end

        do -- Combat
            local Subpages = {
                ["Aimbot"] = Pages["Combat"]:SubPage({
                    Name = "aimbot", 
                    Icon = "111386589037485", 
                    Columns = 2
                }),
                ["Ragebot"] = Pages["Combat"]:SubPage({
                    Name = "ragebot", 
                    Icon = "126028986879491", 
                    Columns = 2
                }),
            }

            do
                local GeneralSection = Subpages["Ragebot"]:Section({Name = "general", Icon = "103174889897193", Side = 1})
                local GeneralSection2 = Subpages["Aimbot"]:Section({Name = "general2", Icon = "103174889897193", Side = 1})

                do
                    local Toggle = GeneralSection:Toggle({
                        Name = "enabled",
                        Flag = "enabled",
                        Default = false,
                        Callback = function(Value)
                            print(Value)
                        end
                    })
                


                    GeneralSection:Label("Exotic Dealer", "Left"):Colorpicker({
                        Name = "Colorpicker",
                        Flag = "Colorpicker23",
                        Default = Library.Theme.Accent,
                        Alpha = 0,
                        Callback = function(Color, Alpha)
                            print(Color, Alpha)
                        end
                    })

                    local Button = GeneralSection:Button({
                        Name = "Button", 
                        Callback = function()
                            print("Pressed")
                        end
                    })

                    local Slider = GeneralSection:Slider({
                        Name = "Slider", 
                        Flag = "Slider", 
                        Min = 0, 
                        Default = 0, 
                        Max = 100, 
                        Suffix = "%", 
                        Decimals = 1, 
                        Callback = function(Value)
                            print(Value)
                        end
                    })

                    GeneralSection:Label("WhoreoeroeroeroeoreoreoreoreoroeroeoreoreoreoroeoroereWhoreoeroeroeroeoreoreoreoreoroeroeoreoreoreoroeoroere", "Left")

                    local Dropdown = GeneralSection:Dropdown({
                        Name = "Dropdown",
                        Flag = "Dropdown",
                        Items = { },
                        Default = "One",
                        MaxSize = 155,
                        Multi = false,
                        Callback = function(Value)
                            print(Value)
                        end
                    })

                    Dropdown:AddOption("Black")
                    Dropdown:AddOption("Black")
                    Dropdown:AddOption("Black")


                    local MultiDropdown = GeneralSection:Dropdown({
                        Name = "Multi Dropdown",
                        Flag = "MultiDropdown",
                        Items = {"One", "Two", "Three"},
                        Default = {"One", "Two"},
                        MaxSize = 85,
                        Multi = true,
                        Callback = function(Value)
                            print(Value)
                        end
                    })

                    local Label = GeneralSection:Label("Keybind", "Left")
                    Label:Keybind({
                        Name = "Keybind",
                        Flag = "Keybind",
                        Default = Enum.KeyCode.L,
                        Mode = "toggle",
                        Callback = function(Value)
                            print(Value)
                        end
                    })

                    local Toggle2 = GeneralSection:Toggle({
                        Name = "enabled2",
                        Flag = "enabled2",
                        Default = false,
                        Callback = function(Value)
                            print(Value)
                        end
                    }):Keybind({
                        Name = "Keybind2",
                        Flag = "Keybind2",
                        Default = Enum.KeyCode.RightAlt,
                        Mode = "toggle",
                        Callback = function(Value)
                            print(Value)
                        end
                    })

                    local Textbox = GeneralSection:Textbox({
                        Name = "Textbox",
                        Flag = "Textbox",
                        Placeholder = "Placeholder",
                        Default = "Text",
                        Callback = function(Value)
                            print(Value)
                        end
                    })
                end
            end
        end

        do -- Visuals
            local PlayersSection = Pages["Visuals"]:Section({Name = "Players", Side = 1, Icon = "135799335731002"})

            ESPPreview:SetVisibility(false)

            ESPPreview:Set("BoxHolder", "BackgroundTransparency", 1)
            ESPPreview:Set("BoxHolder", "Visible", false)
            ESPPreview:Set("Corners", "Visible", false)
            ESPPreview:Set("WeaponText", "Visible", false)
            ESPPreview:Set("Distance", "Visible", false)
            ESPPreview:Set("Name", "Visible", false)
            ESPPreview:Set("HealthBar", "Visible", false)
            ESPPreview:Set("HealthBarText", "Visible", false)
            ESPPreview:Set("HealthBarText", "Position", UDim2.new(0, -5, 0, 0))

            PlayersSection:Toggle({
                Name = "Enabled",
                Flag = "Visuals/ESP/MasterSwitch",
                Default = false,
                Callback = function(Value)
                    Options["Enabled"] = Value
                    MiscOptions["Enabled"] = Value

                    ESPPreview:SetVisibility(Value)
                end
            })

            local BoxesToggle = PlayersSection:Toggle({
                Name = "Boxes",
                Flag = "Visuals/ESP/Boxes",
                Default = false,
                Callback = function(Value)
                    Options["Boxes"] = Value
                    MiscOptions["Boxes"] = Value

                    ESPPreview:Set("BoxHolder", "Visible", Value)

                    if Options["BoxType"] == "Corner" then
                        if Options["Boxes"] then
                            ESPPreview:Set("BoxHolder", "Visible", false)
                            ESPPreview:Set("Corners", "Visible", true)
                        else
                            ESPPreview:Set("BoxHolder", "Visible", false)
                            ESPPreview:Set("Corners", "Visible", Value)
                        end
                    else
                        if Options["Boxes"] then
                            ESPPreview:Set("BoxHolder", "Visible", true)
                            ESPPreview:Set("Corners", "Visible", false)
                        else
                            ESPPreview:Set("BoxHolder", "Visible", Value)
                            ESPPreview:Set("Corners", "Visible", false)
                        end
                    end
                end
            })

            BoxesToggle:Colorpicker({
                Name = "Gradient 1",
                Flag = "Visuals/ESP/Boxes/Gradient 1",
                Default = Options["Box Gradient 1"].Color,
                Alpha = 0,
                Callback = function(Value)
                    Options["Box Gradient 1"] = {Color = Value, Transparency = Alpha}
                    MiscOptions["Box Gradient 1"] = {Color = Value, Transparency = Alpha}
                    ESPPreview:Set("BoxGradient", "Color", ColorSequence.new{ColorSequenceKeypoint.new(0, Value), ColorSequenceKeypoint.new(1, Options["Box Gradient 2"]["Color"])})
                    
                    if Options["BoxType"] == "Corner" then
                        for _, descendant in ESPPreview.Items.Corners.Instance:GetDescendants() do
                            if descendant:IsA("UIGradient") then
                                descendant.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Value), ColorSequenceKeypoint.new(1, Options["Box Gradient 2"]["Color"])}
                            end
                        end
                    end
                end
            })

            BoxesToggle:Colorpicker({
                Name = "Gradient 2",
                Flag = "Visuals/ESP/Boxes/Gradient 2",
                Default = Options["Box Gradient 2"].Color,
                Alpha = 0,
                Callback = function(Value, Alpha)
                    Options["Box Gradient 2"] = {Color = Value, Transparency = Alpha}
                    MiscOptions["Box Gradient 2"] = {Color = Value, Transparency = Alpha}
                    ESPPreview:Set("BoxGradient", "Color", ColorSequence.new{ColorSequenceKeypoint.new(0, Options["Box Gradient 1"]["Color"]), ColorSequenceKeypoint.new(1, Value)})
                
                    if Options["BoxType"] == "Corner" then
                        for _, descendant in ESPPreview.Items.Corners.Instance:GetDescendants() do
                            if descendant:IsA("UIGradient") then
                                descendant.Color =  ColorSequence.new{ColorSequenceKeypoint.new(0, Options["Box Gradient 1"]["Color"]), ColorSequenceKeypoint.new(1, Value)}
                            end
                        end
                    end
                end
            })

            PlayersSection:Dropdown({
                Name = "Type",
                Flag = "Visuals/ESP/BoxType",
                Items = {"Normal", "Corner"},
                Default = "Normal",
                MaxSize = 100,
                Callback = function(Value)
                    Options["BoxType"] = Value
                    MiscOptions["BoxType"] = Value

                    if not Options["Boxes"] then return end
                    
                    if Value == "Corner" then
                        ESPPreview:Set("BoxHolder", "Visible", false)
                        ESPPreview:Set("Corners", "Visible", true)
                    else
                        ESPPreview:Set("BoxHolder", "Visible", true)
                        ESPPreview:Set("Corners", "Visible", false)
                    end
                end
            })
            
            PlayersSection:Slider({
                Name = "Rotation",
                Flag = "Visuals/ESP/BoxGradientRotation",
                Default = 90,
                Suffix = "°",
                Min = -180,
                Max = 180,
                Decimals = 1,
                Callback = function(Value)
                    Options["Box Gradient Rotation"] = Value
                    MiscOptions["Box Gradient Rotation"] = Value

                    ESPPreview:Set("BoxGradient", "Rotation", Value)
                end
            })

            local BoxesFilledToggle = PlayersSection:Toggle({
                Name = "Filled",
                Flag = "Visuals/ESP/BoxesFilled",
                Default = false,
                Callback = function(Value)
                    Options["Box Fill"] = Value
                    MiscOptions["Box Fill"] = Value

                    ESPPreview:Set("BoxHolder", "BackgroundTransparency", Value and 0 or 1)
                end
            })

            BoxesFilledToggle:Colorpicker({
                Name = "Gradient 1",
                Flag = "Visuals/ESP/Boxes/FilledGradient 1",
                Default = Options["Box Fill 1"].Color,
                Alpha = 0.9,
                Callback = function(Value, Alpha)
                    Options["Box Fill 1"] = {Color = Value, Transparency = Alpha}
                    MiscOptions["Box Fill 1"] = {Color = Value, Transparency = Alpha}

                    local Path = ESPPreview.Items.CornersGradient.Instance
                    Path.Transparency = NumberSequence.new{
                        NumberSequenceKeypoint.new(0, 1 - Alpha), 
                        Path.Transparency.Keypoints[2]
                    }

                    Path.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, Value), 
                        Path.Color.Keypoints[2]
                    }

                    local Path = ESPPreview.Items.BoxHolderGradient.Instance
                    Path.Transparency = NumberSequence.new{
                        Path.Transparency.Keypoints[1],
                            NumberSequenceKeypoint.new(1, 1 - Alpha)
                        }

                    Path.Color = ColorSequence.new{
                        Path.Color.Keypoints[1],
                            ColorSequenceKeypoint.new(1, Value)
                        }
                end
            })

            BoxesFilledToggle:Colorpicker({
                Name = "Gradient 2",
                Flag = "Visuals/ESP/Boxes/FilledGradient 2",
                Default = Options["Box Fill 2"].Color,
                Alpha = 0.9,
                Callback = function(Value, Alpha)
                    Options["Box Fill 2"] = {Color = Value, Transparency = Alpha}
                    MiscOptions["Box Fill 2"] = {Color = Value, Transparency = Alpha}

                    local Path = ESPPreview.Items.CornersGradient.Instance
                    Path.Transparency = NumberSequence.new{
                        Path.Transparency.Keypoints[1],
                        NumberSequenceKeypoint.new(1, Alpha)
                    };

                    Path.Color = ColorSequence.new{
                        Path.Color.Keypoints[1],
                        ColorSequenceKeypoint.new(1, Value)
                    };

                    local Path = ESPPreview.Items.BoxHolderGradient.Instance
                    Path.Transparency = NumberSequence.new{
                        NumberSequenceKeypoint.new(0, Alpha), 
                        Path.Transparency.Keypoints[2]
                    }

                    Path.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, Value), 
                        Path.Color.Keypoints[2]
                    }
                end
            })

            PlayersSection:Slider({
                Name = "Rotation",
                Flag = "Visuals/ESP/BoxFillGradientRotation",
                Default = 90,
                Suffix = "°",
                Min = -180,
                Max = 180,
                Decimals = 1,
                Callback = function(Value)
                    Options["Box Fill Rotation"] = Value
                    MiscOptions["Box Fill Rotation"] = Value

                    ESPPreview:Set("BoxHolderGradient", "Rotation", Value)
                    ESPPreview:Set("CornersGradient", "Rotation", Value)
                end
            })

            local HealthBarToggle = PlayersSection:Toggle({
                Name = "Healthbar",
                Flag = "Visuals/ESP/Healthbar",
                Default = false,
                Callback = function(Value)
                    Options["Healthbar"] = Value
                    MiscOptions["Healthbar"] = Value

                    ESPPreview:Set("HealthBar", "Visible", Value)
                end
            })

            PlayersSection:Dropdown({
                Name = "Healthbar side",
                Flag = "Visuals/ESP/HealthbarSide",
                MaxSize = 145,
                Default = "Left",
                Items = {"Left", "Bottom", "Top", "Right"},
                Callback = function(Value)
                    Value = Value or "Left"
                    Options["Healthbar_Position"] = Value
                    MiscOptions["Healthbar_Position"] = Value

                    ESPPreview:Set("HealthBar", "Parent", ESPPreview.Items[Value].Instance or ESPPreview.Items.Left.Instance)

                    if Options["Healthbar_Position"] == "Right" then
                        ESPPreview:Set("HealthBarText", "Visible", Options["Healthbar_Number"])
                        ESPPreview:Set("HealthBarText", "AnchorPoint", Vector2.new(0, 0))
                        ESPPreview:Set("HealthBarText", "Position", UDim2.new(1, 5, 0, 0))
                    else
                        ESPPreview:Set("HealthBarText", "Visible", Options["Healthbar_Number"])
                        ESPPreview:Set("HealthBarText", "AnchorPoint", Vector2.new(1, 0))
                        ESPPreview:Set("HealthBarText", "Position", UDim2.new(0, -5, 0, 0))
                    end

                    if Options["Healthbar_Position"] == "Top" or Options["Healthbar_Position"] == "Bottom" then
                        ESPPreview:Set("HealthBarText", "Visible", false)
                    end

                    for _,newparent in {ESPPreview.Items.Left, ESPPreview.Items.Top, ESPPreview.Items.Right, ESPPreview.Items.Bottom} do 
                        if newparent.Instance == ESPPreview.Items.HealthBar.Instance.Parent then 
                            local isVertical =  _ % 2 == 1
                            ESPPreview.Items.HealthBar.Instance.Size = isVertical and UDim2.new(0, Options["Healthbar_Thickness"], 1, 0) or UDim2.new(1, 0, 0, Options["Healthbar_Thickness"])
                            ESPPreview.Items.Bar.Instance.Position = isVertical and UDim2.new(0, 1, 0, 1) or UDim2.new(0, 1, 0, 1)
                            ESPPreview.Items.Bar.Instance.Size = isVertical and UDim2.new(0, Options["Healthbar_Thickness"], 1, -2) or UDim2.new(1, -2, 0, Options["Healthbar_Thickness"])
                            ESPPreview.Items.BarGradient.Instance.Rotation = isVertical and -90 or 180
                             
                            return
                        end
                    end
                end
            })

            HealthBarToggle:Colorpicker({
                Name = "Low",
                Default = Options["Healthbar_Low"].Color,
                Flag = "Visuals/ESP/HealthbarLow",
                Alpha = 0,
                Callback = function(Value, Alpha)
                    Options["Healthbar_Low"] = {Color = Value, Transparency = Alpha}
                    MiscOptions["Healthbar_Low"] = {Color = Value, Transparency = Alpha}

                    ESPPreview:Set("BarGradient", "Color", ColorSequence.new{ColorSequenceKeypoint.new(0, Value), ColorSequenceKeypoint.new(0.5, Options["Healthbar_Medium"].Color), ColorSequenceKeypoint.new(1, Options["Healthbar_High"].Color)})
                end
            })

            HealthBarToggle:Colorpicker({
                Name = "Medium",
                Default = Options["Healthbar_Medium"].Color,
                Flag = "Visuals/ESP/HealthbarMedium",
                Alpha = 0,
                Callback = function(Value, Alpha)
                    Options["Healthbar_Medium"] = {Color = Value, Transparency = Alpha}
                    MiscOptions["Healthbar_Medium"] = {Color = Value, Transparency = Alpha}
                    ESPPreview:Set("BarGradient", "Color", ColorSequence.new{ColorSequenceKeypoint.new(0, Options["Healthbar_Low"].Color), ColorSequenceKeypoint.new(0.5, Value), ColorSequenceKeypoint.new(1, Options["Healthbar_High"].Color)})
                end
            })

            HealthBarToggle:Colorpicker({
                Name = "High",
                Default = Options["Healthbar_High"].Color,
                Flag = "Visuals/ESP/HealthbarHigh",
                Alpha = 0,
                Callback = function(Value, Alpha)
                    Options["Healthbar_High"] = {Color = Value, Transparency = Alpha}
                    MiscOptions["Healthbar_High"] = {Color = Value, Transparency = Alpha}
                    ESPPreview:Set("BarGradient", "Color", ColorSequence.new{ColorSequenceKeypoint.new(0, Options["Healthbar_Low"].Color), ColorSequenceKeypoint.new(0.5, Options["Healthbar_Medium"].Color), ColorSequenceKeypoint.new(1, Value)})
                end
            })

            PlayersSection:Toggle({
                Name = "Healthbar Tween",
                Flag = "Visuals/ESP/HealthbarTween",
                Default = false,
                Callback = function(Value)
                    Options["Healthbar_Tween"] = Value
                    MiscOptions["Healthbar_Tween"] = Value
                end
            })

            PlayersSection:Dropdown({
                Name = "Tweening style",
                Flag = "Visuals/ESP/HealthbarTweenStyle",
                Default = "Linear",
                Items = {"Linear", "Sine", "Quad", "Cubic", "Quart", "Quint", "Exponential", "Circular", "Back", "Elastic", "Bounce"},
                MaxSize = 150,
                Callback = function(Value)
                    Options["Healthbar_EasingStyle"] = Value
                    MiscOptions["Healthbar_EasingStyle"] = Value
                end
            })

            PlayersSection:Dropdown({
                Name = "Tweening direction",
                Flag = "Visuals/ESP/HealthbarTweenDirection",
                MaxSize = 55,
                Default = "Out",
                Items = {"In", "Out", "InOut"},
                Callback = function(Value)
                    Options["Healthbar_EasingDirection"] = Value
                    MiscOptions["Healthbar_EasingDirection"] = Value
                end
            })

            PlayersSection:Slider({
                Name = "Tweening speed",
                Default = 1,
                Max = 10,
                Minimum = 0,
                Decimals = 0.01,
                Suffix = "s",
                Flag = "Visuals/ESP/HealthbarTweenSpeed",
                Callback = function(Value)
                    Options["Healthbar_Easing_Speed"] = Value
                    MiscOptions["Healthbar_Easing_Speed"] = Value
                end
            })

            PlayersSection:Toggle({
                Name = "Healthbar Number",
                Flag = "Visuals/ESP/HealthbarNumber",
                Default = false,
                Callback = function(Value)
                    Options["Healthbar_Number"] = Value
                    MiscOptions["Healthbar_Number"] = Value

                    ESPPreview:Set("HealthBarText", "Visible", Value)
                end
            })

            PlayersSection:Slider({
                Name = "Healthbar Text Size",
                Flag = "Visuals/ESP/HealthbarTextSize",
                Max = 14,
                Min = 1,
                Default = 11,
                Suffix = "px",
                Decimals = 1,
                Callback = function(Value)
                    Options["Healthbar_Text_Size"] = Value
                    MiscOptions["Healthbar_Text_Size"] = Value

                    ESPPreview:Set("HealthBarText", "TextSize", Value)
                end
            })

            PlayersSection:Slider({
                Name = "Healthbar Thickness",
                Flag = "Visuals/ESP/HealthbarThickness",
                Max = 10,
                Min = 1,
                Default = 3,
                Suffix = "px",
                Decimals = 1,
                Callback = function(Value)
                    Options["Healthbar_Thickness"] = Value
                    MiscOptions["Healthbar_Thickness"] = Value

                    ESPPreview:Set("HealthBar", "Size", UDim2.new(0, Value, 1, 0))

                    for _,newparent in {ESPPreview.Items.Left, ESPPreview.Items.Top, ESPPreview.Items.Right, ESPPreview.Items.Bottom} do 
                        if newparent.Instance == ESPPreview.Items.HealthBar.Instance.Parent then 
                            local isVertical =  _ % 2 == 1
                            ESPPreview.Items.HealthBar.Instance.Size = isVertical and UDim2.new(0, Options["Healthbar_Thickness"], 1, 0) or UDim2.new(1, 0, 0, Options["Healthbar_Thickness"])
                            ESPPreview.Items.Bar.Instance.Position = isVertical and UDim2.new(0, 1, 0, 1) or UDim2.new(0, 1, 0, 1)
                            ESPPreview.Items.Bar.Instance.Size = isVertical and UDim2.new(0, Options["Healthbar_Thickness"], 1, -2) or UDim2.new(1, -2, 0, Options["Healthbar_Thickness"])
                            ESPPreview.Items.BarGradient.Instance.Rotation = isVertical and -90 or 180
                             
                            return
                        end
                    end
                end
            })

            PlayersSection:Dropdown({
                Name = "Healthbar Text Font",
                Items = {"ProggyClean", "Tahoma", "Verdana", "SmallestPixel", "ProggyTiny", "Minecraftia", "Tahoma Bold"},
                MaxSize = 200,
                Flag = "Visuals/ESP/HealthbarTextFont",
                Default = "Verdana",
                Multi = false,
                Callback = function(Value)
                    if not Value then Value = "ProggyClean" end

                    Options["Healthbar_Font"] = Value
                    MiscOptions["Healthbar_Font"] = Value

                    ESPPreview:Set("HealthBarText", "FontFace", ESPFonts[Value])
                end
            })

            PlayersSection:Toggle({
                Name = "Name",
                Flag = "Visuals/ESP/NameText",
                Default = false,
                Callback = function(Value)
                    Options["Name_Text"] = Value
                    MiscOptions["Name_Text"] = Value

                    ESPPreview:Set("Name", "Visible", Value)
                end
            }):Colorpicker({
                Name = "Name Color",
                Flag = "Visuals/ESP/NameTextColor",
                Default = Color3.fromRGB(255, 255, 255),
                Alpha = 0,
                Callback = function(Value)
                    Options["Name_Text_Color"] = {Color = Value}
                    MiscOptions["Name_Text_Color"] = {Color = Value}

                    ESPPreview:Set("Name", "TextColor3", Value)
                end
            })

            PlayersSection:Dropdown({
                Name = "Name Text Font",
                Items = {"ProggyClean", "Tahoma", "Verdana", "SmallestPixel", "ProggyTiny", "Minecraftia", "Tahoma Bold"},
                MaxSize = 200,
                Flag = "Visuals/ESP/NameTextFont",
                Default = "Verdana",
                Multi = false,
                Callback = function(Value)
                    if not Value then Value = "ProggyClean" end

                    Options["Name_Text_Font"] = Value
                    MiscOptions["Name_Text_Font"] = Value

                    ESPPreview:Set("Name", "FontFace", ESPFonts[Value])
                end
            })

            PlayersSection:Slider({
                Name = "Name Text Size",
                Flag = "Visuals/ESP/NameTextSize",
                Max = 14,
                Min = 1,
                Default = 11,
                Suffix = "px",
                Decimals = 1,
                Callback = function(Value)
                    Options["Name_Text_Size"] = Value
                    MiscOptions["Name_Text_Size"] = Value

                    ESPPreview:Set("Name", "TextSize", Value)
                end
            })

            PlayersSection:Toggle({
                Name = "Distance",
                Flag = "Visuals/ESP/DistanceText",
                Default = false,
                Callback = function(Value)
                    Options["Distance_Text"] = Value
                    MiscOptions["Distance_Text"] = Value

                    ESPPreview:Set("Distance", "Visible", Value)
                end
            }):Colorpicker({
                Name = "Distance Color",
                Flag = "Visuals/ESP/DistanceTextColor",
                Default = Color3.fromRGB(255, 255, 255),
                Alpha = 0,
                Callback = function(Value)
                    Options["Distance_Text_Color"] = {Color = Value}
                    MiscOptions["Distance_Text_Color"] = {Color = Value}

                    ESPPreview:Set("Distance", "TextColor3", Value)
                end
            })

            PlayersSection:Dropdown({
                Name = "Distance Text Font",
                Items = {"ProggyClean", "Tahoma", "Verdana", "SmallestPixel", "ProggyTiny", "Minecraftia", "Tahoma Bold"},
                MaxSize = 200,
                Flag = "Visuals/ESP/DistanceTextFont",
                Default = "Verdana",
                Multi = false,
                Callback = function(Value)
                    if not Value then Value = "ProggyClean" end

                    Options["Distance_Text_Font"] = Value
                    MiscOptions["Distance_Text_Font"] = Value

                    ESPPreview:Set("Distance", "FontFace", ESPFonts[Value])
                end
            })

            PlayersSection:Slider({
                Name = "Distance Text Size",
                Flag = "Visuals/ESP/DistanceTextSize",
                Max = 14,
                Min = 1,
                Default = 11,
                Suffix = "px",
                Decimals = 1,
                Callback = function(Value)
                    Options["Distance_Text_Size"] = Value
                    MiscOptions["Distance_Text_Size"] = Value

                    ESPPreview:Set("Distance", "TextSize", Value)
                end
            })

            PlayersSection:Dropdown({
                Name = "Distance Side",
                Items = {"Top", "Bottom", "Left", "Right"},
                MaxSize = 200,
                Flag = "Visuals/ESP/DistanceTextSide",
                Default = "Bottom",
                Multi = false,
                Callback = function(Value)
                    if not Value then Value = "Left" end

                    Options["Distance_Text_Position"] = Value
                    MiscOptions["Distance_Text_Position"] = Value

                    ESPPreview:Set("Distance", "Parent", ESPPreview.Items[Value].Instance)
                end
            })
        end

        do -- Settings
            local Subpages = {
                ["Configs"] = Pages["Settings"]:SubPage({
                    Name = "configs", 
                    Icon = "96491224522405", 
                    Columns = 2
                }),

                ["Theming"] = Pages["Settings"]:SubPage({
                    Name = "theming", 
                    Icon = "103863157706913", 
                    Columns = 2
                }),

                ["Configuration"] = Pages["Settings"]:SubPage({
                    Name = "configuration", 
                    Icon = "137300573942266", 
                    Columns = 2
                })
            }

            do -- Theming
                local ThemingSection = Subpages["Theming"]:Section({Name = "theming", Icon = "103863157706913", Side = 1})
                local ThemingProfiles = Subpages["Theming"]:Section({Name = "profiles", Icon = "96491224522405", Side = 2})
                local AutoloadSection = Subpages["Theming"]:Section({Name = "autoload", Icon = "137623872962804", Side = 2})

                for Index, Value in Library.Theme do 
                    Library.ThemeColorpickers[Index] = ThemingSection:Label(Index, "Left"):Colorpicker({
                        Name = "Colorpicker",
                        Flag = "ColorpickerTheme" .. Index,
                        Default = Value,
                        Alpha = 0,
                        Callback = function(Color, Alpha)
                            Library.Theme[Index] = Color
                            Library:ChangeTheme(Index, Color)
                        end
                    })
                end

                ThemingProfiles:Dropdown({
                    Name = "preset themes",
                    Items = { "Preset", "Halloween", "Aqua", "One Tap" },
                    Default = "Preset",
                    Multi = false,
                    Callback = function(Value)
                        local ThemeData = Library.Themes[Value]

                        if not ThemeData then 
                            return
                        end

                        for Index, Value in Library.Theme do 
                            Library.Theme[Index] = ThemeData[Index]
                            Library:ChangeTheme(Index, ThemeData[Index])

                            Library.ThemeColorpickers[Index]:Set(ThemeData[Index])
                        end

                        task.wait(0.3)

                        Library:Thread(function() -- i do this because sometimes the themes dont update
                            for Index, Value in Library.Theme do 
                                Library.Theme[Index] = Library.Flags["ColorpickerTheme" .. Index].Color
                                Library:ChangeTheme(Index, Library.Flags["ColorpickerTheme" .. Index].Color)
                            end    
                        end)
                    end
                })

                local ThemeSelected 
                local ThemeName

                do
                    local ThemesDropdown = ThemingProfiles:Dropdown({
                        Name = "themes", 
                        Flag = "ThemesList", 
                        Items = { }, 
                        Multi = false,
                        Callback = function(Value)
                            ThemeSelected = Value
                        end
                    })

                    ThemingProfiles:Textbox({
                        Name = "theme name", 
                        Default = "", 
                        Flag = "ThemeName", 
                        Placeholder = "enter text", 
                        Callback = function(Value)
                            ThemeName = Value
                        end
                    })

                    ThemingProfiles:Button({
                        Name = "save",
                        Callback = function()
                            if ThemeName and ThemeName ~= "" then
                                writefile(Library.Folders.Themes .. "/" .. ThemeName .. ".json", Library:GetTheme())
                                Library:RefreshThemesList(ThemesDropdown)
                            end
                        end
                    })

                    ThemingProfiles:Button({
                        Name = "load",
                        Callback = function()
                            if ThemeSelected then
                                local Success, Result = Library:LoadTheme(readfile(Library.Folders.Themes .. "/" .. ThemeSelected))

                                if Success then 
                                    Library:Notification({
                                        Name = "Success",
                                        Description = "Succesfully loaded theme: ".. ThemeSelected,
                                        Duration = 5,
                                        Icon = "116339777575852",
                                        IconColor = Color3.fromRGB(52, 255, 164)
                                    })

                                    task.wait(0.3)

                                    Library:Thread(function() -- i do this because sometimes the themes dont update
                                        for Index, Value in Library.Theme do 
                                            Library.Theme[Index] = Library.Flags["ColorpickerTheme" .. Index].Color
                                            Library:ChangeTheme(Index, Library.Flags["ColorpickerTheme" .. Index].Color)
                                        end    
                                    end)
                                else
                                    Library:Notification({
                                        Name = "Error!",
                                        Description = "Failed to load theme, error:\n",
                                        Duration = 5,
                                        Icon = "97118059177470",
                                        IconColor = Color3.fromRGB(255, 120, 120)
                                    })
                                end
                            end
                        end
                    })

                    AutoloadSection:Button({
                        Name = "set selected theme as autoload",
                        Callback = function()
                            if ThemeSelected then 
                                writefile(Library.Folders.Directory .. "/AutoLoadTheme (do not modify this).json", readfile(Library.Folders.Themes .. "/" .. ThemeSelected))
                            end
                        end
                    })

                    AutoloadSection:Button({
                        Name = "set current theme as autoload",
                        Callback = function()
                            if ThemeSelected then 
                                writefile(Library.Folders.Directory .. "/AutoLoadTheme (do not modify this).json", Library:GetTheme())
                            end
                        end
                    })

                    AutoloadSection:Button({
                        Name = "remove autoload theme",
                        Callback = function()
                            writefile(Library.Folders.Directory .. "/AutoLoadTheme (do not modify this).json", "")
                        end
                    })

                    Library:RefreshThemesList(ThemesDropdown)
                end
            end

            do -- Configs
                local ConfigsSection = Subpages["Configs"]:Section({Name = "profiles", Icon = "96491224522405", Side = 1})
                local AutoloadSection = Subpages["Configs"]:Section({Name = "autoload", Icon = "137623872962804", Side = 2})

                local ConfigSelected 
                local ConfigName

                do
                    local ConfigsDropdown = ConfigsSection:Dropdown({
                        Name = "configs", 
                        Flag = "ConfigsList", 
                        Items = { }, 
                        Multi = false,
                        Callback = function(Value)
                            ConfigSelected = Value
                        end
                    })

                    ConfigsSection:Textbox({
                        Name = "config name", 
                        Default = "", 
                        Flag = "ConfigName", 
                        Placeholder = "enter text", 
                        Callback = function(Value)
                            ConfigName = Value
                        end
                    })

                    ConfigsSection:Button({
                        Name = "create",
                        Callback = function()
                            if ConfigName and ConfigName ~= "" then
                                writefile(Library.Folders.Configs .. "/" .. ConfigName .. ".json", Library:GetConfig())
                                Library:RefreshConfigsList(ConfigsDropdown)
                            end
                        end
                    })

                    ConfigsSection:Button({
                        Name = "delete",
                        Callback = function()
                            if ConfigSelected then
                                Library:DeleteConfig(ConfigSelected)
                                Library:RefreshConfigsList(ConfigsDropdown)
                            end
                        end
                    })

                    ConfigsSection:Button({
                        Name = "load",
                        Callback = function()
                            if ConfigSelected then
                                local Success, Result = Library:LoadConfig(readfile(Library.Folders.Configs .. "/" .. ConfigSelected))

                                if Success then 
                                    Library:Notification({
                                        Name = "Success",
                                        Description = "Succesfully loaded config: ".. ConfigSelected,
                                        Duration = 5,
                                        Icon = "116339777575852",
                                        IconColor = Color3.fromRGB(52, 255, 164)
                                    })

                                    task.wait(0.3)

                                    Library:Thread(function() -- i do this because sometimes the themes dont update
                                        for Index, Value in Library.Theme do 
                                            Library.Theme[Index] = Library.Flags["ColorpickerTheme" .. Index].Color
                                            Library:ChangeTheme(Index, Library.Flags["ColorpickerTheme" .. Index].Color)
                                        end    
                                    end)
                                else
                                    Library:Notification({
                                        Name = "Error!",
                                        Description = "Failed to load config, error:\n",
                                        Duration = 5,
                                        Icon = "97118059177470",
                                        IconColor = Color3.fromRGB(255, 120, 120)
                                    })
                                end
                            end
                        end
                    })

                    ConfigsSection:Button({
                        Name = "save",
                        Callback = function()
                            if ConfigSelected then
                                Library:SaveConfig(ConfigSelected)
                            end
                        end
                    })

                    ConfigsSection:Button({
                        Name = "refresh list",
                        Callback = function()
                            Library:RefreshConfigsList(ConfigsDropdown)
                        end
                    })

                    Library:RefreshConfigsList(ConfigsDropdown)
                end

                do
                    AutoloadSection:Button({
                        Name = "set selected config as autoload",
                        Callback = function()
                            if ConfigSelected then 
                                writefile(Library.Folders.Directory .. "/AutoLoadConfig (do not modify this).json", readfile(Library.Folders.Configs .. "/" .. ConfigSelected))
                            end
                        end
                    })

                    AutoloadSection:Button({
                        Name = "set current config as autoload",
                        Callback = function()
                            if ConfigSelected then 
                                writefile(Library.Folders.Directory .. "/AutoLoadConfig (do not modify this).json", Library:GetConfig())
                            end
                        end
                    })

                    AutoloadSection:Button({
                        Name = "remove autoload config",
                        Callback = function()
                            writefile(Library.Folders.Directory .. "/AutoLoadConfig (do not modify this).json", "")
                        end
                    })
                end
            end

            do -- Configuration
                local MenuSection = Subpages["Configuration"]:Section({Name = "menu", Icon = "93007870315593", Side = 1})
                local TweeningSection = Subpages["Configuration"]:Section({Name = "tweening", Icon = "130045183204879", Side = 2})

                do
                    MenuSection:Label("menu keybind", "Left"):Keybind({
                        Name = "MenuKeybind",
                        Flag = "MenuKeybind",
                        Mode = "toggle",
                        Default = Library.MenuKeybind,
                        Callback = function()
                            Library.MenuKeybind = Library.Flags["MenuKeybind"].Key
                        end
                    })

                    MenuSection:Toggle({
                        Name = "keybind list",
                        Flag = "keybind list",
                        Default = false,
                        Callback = function(Value)
                            KeybindList:SetVisibility(Value)
                        end
                    })

                    MenuSection:Toggle({
                        Name = "Global chat",
                        Flag = "Global chat",
                        Default = true,
                        Callback = function(Value)
                            ChatSystem:SetVisibility(Value)
                        end
                    })
                    
                    MenuSection:Toggle({
                        Name = "watermark",
                        Flag = "watermark",
                        Default = false,
                        Callback = function(Value)
                            Watermark:SetVisibility(Value)
                        end
                    })

                    MenuSection:Button({
                        Name = "unload",
                        Callback = function()
                            Library:Unload()
                        end
                    })
                end

                do
                    TweeningSection:Slider({
                        Name = "time",
                        Flag = "TweenTime",
                        Default = Library.Tween.Time,
                        Min = 0,
                        Max = 5,
                        Decimals = 0.01,
                        Callback = function(Value)
                            Library.Tween.Time = Value
                        end
                    })

                    TweeningSection:Dropdown({
                        Name = "style",
                        Flag = "TweenStyle",
                        Default = "Cubic",
                        Items = {"Linear", "Sine", "Quad", "Cubic", "Quart", "Quint", "Exponential", "Circular", "Back", "Elastic", "Bounce"},
                        MaxSize = 150,
                        Callback = function(Value)
                            Library.Tween.Style = Enum.EasingStyle[Value]
                        end
                    })

                    TweeningSection:Dropdown({
                        Name = "direction",
                        Flag = "TweenDirection",
                        MaxSize = 55,
                        Default = "Out",
                        Items = {"In", "Out", "InOut"},
                        Callback = function(Value)
                            Library.Tween.Direction = Enum.EasingDirection[Value]
                        end
                    })
                end
            end
        end
    end
end

Library:Notification({
    Name = "Loaded",
    Description = "Loaded library in: " .. string.format("%.4f", os.clock() - LoadingTick) .. " seconds",
    Duration = 5
})

Library:Init() -- put this at the end of ur script or the autoload will not work
--