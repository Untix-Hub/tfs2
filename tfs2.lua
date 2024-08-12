local runService = game:GetService("RunService")
local textChatService = game:GetService("TextChatService")
local uis = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local cameraPath = workspace.CurrentCamera
local player = game:GetService("Players").LocalPlayer
local mouse = player:GetMouse()

local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Untix-Hub/uisrc/main/src.lua"))()
local Notif = library:InitNotifications()

local priority = {}
local espTable = {}
local announceTable = {}
local blacklist = {}

local aimbot = false
local delay = 0.025
local assassin = false

local esp = false
local announce = false

local fb = false
local wraith = false

local reload

local tween, target, held

local specials = {
	["Boss"] = {Color = Color3.fromRGB(255,255,255), Announce = false},
	["Wraith"] = {Color = Color3.fromRGB(255, 255, 255), Announce = false},
	["Berserker"] = {Color = Color3.fromRGB(255, 110, 110), Announce = true},
	["Hunter"] = {Color = Color3.fromRGB(255, 0, 0), Announce = true},
	["Destroyer"] = {Color = Color3.fromRGB(255, 115, 0), Announce = false},
	["Lurker"] = {Color = Color3.fromRGB(0, 200, 5), Announce = true},
	["DrenchWraith"] = {Color = Color3.fromRGB(0, 166, 255), Announce = false},
	["Sponger"] = {Color = Color3.fromRGB(0, 51, 255), Announce = true},
	["MinerZombie"] = {Color = Color3.fromRGB(255, 187, 0), Announce = false},
	["Annihilator"] = {Color = Color3.fromRGB(156, 156, 156), Announce = true},
	["FrostWraith"] = {Color = Color3.fromRGB(125, 220, 255), Announce = false},
    ["SwampGiant"] = {Color = Color3.fromRGB(81, 255, 0), Announce = false}
}

local function isPriorityZombie(zombieName)
	return table.find(priority, zombieName) ~= nil
end

local function IsFirstPerson()
    if player.Character or player.Character.Parent ~= nil then
	    return (player.Character.Head.CFrame.p - cameraPath.CFrame.p).Magnitude < 2
    end
end

local function isVisible(part, ...)
	local parts = cameraPath:GetPartsObscuringTarget({part}, {cameraPath, player.Character, ...})
	for _, p in ipairs(parts) do
		if p.Transparency < 0.9 then -- Check if the part is not almost fully transparent
			return false
		end
	end
	return true
end	

function visualizeESP(zombie)
	if not esp then
		return
	end
	
	if not table.find(espTable, zombie.Name) then
		return
	end
	
	local special = specials[zombie.Name]
	if not special or not special.Color then
		return
	end

	local humanoid = zombie:WaitForChild("Zombie")
	local humanoidRootPart = zombie:WaitForChild("HumanoidRootPart")

	local text = Drawing.new("Text")
	text.Visible = false
	text.Center = true
	text.Outline = true 
	text.Font = 2
	text.Color = Color3.fromRGB(255,255,255)
	text.Size = 13

	local highlight = Instance.new("Highlight", zombie)
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = 0.75
	highlight.FillColor = special.Color

	local connection1, connection2, connection3

	local function disconnect()
		text.Visible = false
		text:Remove()
		if zombie:FindFirstChild("Highlight") then
			zombie:FindFirstChild("Highlight"):Destroy()
		end
		if connection1 then
			connection1:Disconnect()
			connection1 = nil
		end
		if connection2 then
			connection2:Disconnect()
			connection2 = nil
		end
		if connection3 then
			connection3:Disconnect()
			connection3 = nil
		end
	end

	connection2 = zombie.AncestryChanged:Connect(function(_, parent)
		if not parent then
			disconnect()
		end
	end)

	connection3 = humanoid.HealthChanged:Connect(function(v)
		local nhumanoid = zombie:WaitForChild("Zombie") or zombie:FindFirstChild("Zombie")
		if nhumanoid and (v <= 0) or (nhumanoid:GetState() == Enum.HumanoidStateType.Dead) then
			disconnect()
		end
	end)

	if announce and table.find(announceTable, zombie.Name) then
		textChatService.TextChannels.RBXSystem:DisplaySystemMessage(
			string.format('<font color="#%s">A %s has spawned!</font>', special.Color:ToHex(), zombie.Name)
		)
	end

	connection1 = runService.RenderStepped:Connect(function()
		if not esp then disconnect() end
		if not table.find(espTable, zombie.Name) then return end
		
		if humanoidRootPart then
			if table.find(blacklist, zombie.Name) then
				text.Visible = false
				return
			end

			local hrpPos, onScreen = cameraPath:WorldToViewportPoint(humanoidRootPart.Position)
			if onScreen then
				text.Color = special.Color
				text.Position = Vector2.new(hrpPos.X, hrpPos.Y - 50)
				text.Text = string.format('%s\n%d/%d', zombie.Name, math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
				text.Visible = true
			else
				text.Visible = false
			end
		end
	end)
end

local function getLowestHealthNearMouse()
    local lowestHealthZombie = nil
    local lowestHealth = math.huge
    local closestDistanceToMouse = math.huge
    local zombiePath = workspace.Zombies
    local mousePosition = mouse.Hit.Position

    for _, zombie in pairs(zombiePath:GetChildren()) do
        if zombie:FindFirstChild("Zombie") and zombie.Zombie.Health > 0 then
            local head = zombie:FindFirstChild("Head")

            if head and isVisible(zombie.Head.Position, zombie.Head.Parent) then
                local _, onScreen = cameraPath:WorldToViewportPoint(head.Position)
                local distanceToMouse = (mousePosition - head.Position).Magnitude
                local zombieHealth = zombie.Zombie.Health

                -- Prioritize the zombie with the lowest health near the mouse cursor
                if zombieHealth < lowestHealth and distanceToMouse < closestDistanceToMouse and not zombie:FindFirstChildWhichIsA("ForceField") and onScreen then
                    lowestHealth = zombieHealth
                    closestDistanceToMouse = distanceToMouse
                    lowestHealthZombie = zombie
                end
            end
        end
    end

    return lowestHealthZombie
end

local function getNearestZombie()
    local zombiePath = workspace.Zombies
    local closestPriorityDistance = math.huge
    local closestOtherDistance = math.huge
    local mousePosition = mouse.Hit.Position
    local priorityTarget, otherTarget

    -- If Assassin is off cooldown, prioritize the lowest health zombie near the mouse
    if player.PlayerValues.PerkValues.AssassinCD.Value == 0 and assassin then
        target = getLowestHealthNearMouse()
        return
    end

    -- Default targeting logic
    for _, zombie in pairs(zombiePath:GetChildren()) do
        if zombie:FindFirstChild("Zombie") and zombie.Zombie.Health > 0 then
            local head = zombie:FindFirstChild("Head")
            
            if head then
                -- Calculate the distance from the mouse position to the zombie's head
                local screenPosition, onScreen = cameraPath:WorldToViewportPoint(head.Position)
                local distanceToMouse = (mousePosition - head.Position).Magnitude

                -- Check if the zombie is a priority target
                if isPriorityZombie(zombie.Name) then
                    if distanceToMouse < closestPriorityDistance then
                        if onScreen and isVisible(head.Position, head.Parent) and not zombie:FindFirstChildWhichIsA("ForceField") then
                            closestPriorityDistance = distanceToMouse
                            priorityTarget = zombie
                        end
                    end
                else
                    -- Handle non-priority zombies
                    if distanceToMouse < closestOtherDistance then
                        if onScreen and isVisible(head.Position, head.Parent) and not zombie:FindFirstChildWhichIsA("ForceField") then
                            closestOtherDistance = distanceToMouse
                            otherTarget = zombie
                        end
                    end
                end
            end
        end
    end

    -- Prioritize target selection
    if priorityTarget then
        target = priorityTarget
    else
        target = otherTarget
    end
end

local function visibleWraith(zombie)
    if not wraith then
        return
    end

    local humanoid = zombie:FindFirstChild("Zombie")
    local humanoidRootPart = zombie:FindFirstChild("HumanoidRootPart")

    if humanoid and humanoidRootPart then
        for i,v in pairs(zombie:GetChildren()) do
            local success = pcall(function()
                local _ = v.Transparency
            end)

            if success then
                v.Transparency = 0
            end
        end
    end
end

local function Load()
    task.spawn(function()
        workspace.Zombies.ChildAdded:Connect(function(zombie)
            visualizeESP(zombie)
            visibleWraith(zombie)
        end)
        game:GetService("RunService").Heartbeat:Connect(function()
            if not fb then return end
        
            game.Lighting.Brightness = 5
            game.Lighting.Ambient = Color3.fromRGB(255,255,255)
            game.Lighting.FogStart = 0
            game.Lighting.FogEnd = math.huge
        end)
    end)

	task.spawn(function()
		runService.RenderStepped:Connect(function()
            if not player:HasAppearanceLoaded() then return end

			if not aimbot or not IsFirstPerson() then return end

			local head = target and target:FindFirstChild("Head")
			local zombie = target and target:FindFirstChild("Zombie")
			local zombieHealth = zombie and zombie.Health

			if not target or not head or not zombie or type(zombieHealth) ~= "number" or zombieHealth <= 0 or not held then
				getNearestZombie()
			end

			if target and head and zombie and type(zombieHealth) == "number" and zombieHealth > 0 and held then
				tween = tweenService:Create(cameraPath, TweenInfo.new(delay, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(cameraPath.CFrame.Position, head.Position)})
				tween:Play()
			end
		end)
	end)

	task.spawn(function()
		uis.InputBegan:Connect(function(input, isProcessed)
			if isProcessed then return end
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				held = true
			end
		end)
	end)

	task.spawn(function()
		uis.InputEnded:Connect(function(input, isProcessed)
			if isProcessed then return end
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				held = false
			end
		end)
	end)
end

task.spawn(function()
	library.title = "The Final Stand 2"

	Notif:Notify("Loading the hub...", 8, "information")
	library:Introduction()

	task.wait(1)

	local Window = library:Init()
	local AimTab = Window:NewTab("Aimbot")
	local ESPTab = Window:NewTab("ESP")
    local MiscTab = Window:NewTab("Misc")
	local SettingsTab = Window:NewTab("Settings")
	local CreditTab = Window:NewTab("Credits")

	AimTab:NewToggle("Aimbot", false, function(v)
		aimbot = v
	end)

	AimTab:NewToggle("Assassin", false, function(v)
		assassin = v
	end)

	AimTab:NewSlider("Delay", "ms", false, " / ", {min = 0, max = 100, default = 25}, function(v)
		delay = v / 1000
	end)

	AimTab:NewSeperator()
	AimTab:NewLabel("Prioritize Zombies")
	for i,v in pairs(specials) do
		AimTab:NewToggle(i, false, function(_)
			if _ then
				table.insert(priority, i)
			elseif table.find(priority, i) then
				table.remove(priority, table.find(priority, i))
			end
		end)
	end

	AimTab:NewSeperator()
	AimTab:NewLabel("Blacklist Zombies")
	for i,v in pairs(specials) do
		AimTab:NewToggle(i, false, function(_)
			if _ then
				table.insert(blacklist, i)
			elseif table.find(blacklist, i) then
				table.remove(blacklist, table.find(blacklist, i))
			end
		end)
	end

	ESPTab:NewToggle("ESP", false, function(v)
		esp = v
	end):AddKeybind(Enum.KeyCode.B)

	ESPTab:NewToggle("Announce Zombies", false, function(v)
		announce = v
	end):AddKeybind(Enum.KeyCode.B)

	ESPTab:NewSeperator()
	ESPTab:NewLabel("Zombies")
	for i,v in pairs(specials) do
		ESPTab:NewToggle(i, true, function(_)
			if _ then
				table.insert(espTable, i)
			elseif table.find(espTable, i) then
				table.remove(espTable, table.find(espTable, i))
			end
		end)
	end

	ESPTab:NewSeperator()
	ESPTab:NewLabel("Announce Zombie")
	for i,v in pairs(specials) do
		ESPTab:NewToggle(i, v.Announce, function(_)
			if _ then
				table.insert(announceTable, i)
			elseif table.find(announceTable, i) then
				table.remove(announceTable, table.find(announceTable, i))
			end
		end)
	end

    MiscTab:NewToggle("Fullbright", false, function(v)
        fb = v
    end)

    MiscTab:NewToggle("Visible Wraiths", false, function(v)
        wraith = v
    end)

    MiscTab:NewSeperator()
    MiscTab:NewLabel("Equip weapon you wish to make fullauto/semi.")
    MiscTab:NewButton("FullAuto Gun", function()
        local success, error = pcall(function()
            for i,v in pairs(player.Character:GetChildren()) do
                if v:IsA("Tool") then
                    v.CurrentValues.FireType.Value = "FullAuto"
                end
            end
        end)

        if success then
            return
        else
            Notif:Notify(error, 5, "error")
        end
    end)

    MiscTab:NewButton("Semi Gun", function()
        local success, error = pcall(function()
            for i,v in pairs(player.Character:GetChildren()) do
                if v:IsA("Tool") then
                    v.CurrentValues.FireType.Value = "Single"
                end
            end
        end)

        if success then
            return
        else
            Notif:Notify(error, 5, "error")
        end
    end)

	SettingsTab:NewKeybind("Toggle UI", nil, function(v)
		Window:UpdateKeybind(Enum.KeyCode[v])
	end)

	CreditTab:NewLabel("Credits")
	CreditTab:NewLabel("Scripter: Nekoexus (nekoexus / 738794703079866418)\nUI Library: idk i found this off google")	
end)

Load()
