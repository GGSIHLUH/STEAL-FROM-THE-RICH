local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Bersihkan UI lama jika ada
if PlayerGui:FindFirstChild("AreAcuysHub_UI") then
	PlayerGui.AresHub_UI:Destroy()
end

-- Service & Remote Objects
local placeAtEvent, itemLoadoutEvent
pcall(function() placeAtEvent = ReplicatedStorage:FindFirstChild("re_PLACE_AT") end)
pcall(function() itemLoadoutEvent = ReplicatedStorage:FindFirstChild("rf_ITEM_LOADOUT") end)

-- State Variables
local selectedZone = ""
local autoCrateEnabled = false
local autoPlaceEnabled = false
local autoOpenEnabled = false
local equipBestEnabled = false
local spawnCFrame = nil

-- Save Spawn Position
task.spawn(function()
	task.wait(1)
	pcall(function()
		local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then spawnCFrame = root.CFrame end
	end)
end)

-- Helper Functions
local function teleportTo(cframe)
	local character = LocalPlayer.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		character:PivotTo(cframe)
	end)
end

local function getCFrame(obj)
	if not obj then return nil end
	if obj:IsA("BasePart") then
		return obj.CFrame
	elseif obj:IsA("Attachment") then
		return obj.WorldCFrame
	elseif obj:IsA("Model") then
		if obj.PrimaryPart then return obj.PrimaryPart.CFrame end
		local best, size = nil, 0
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") and d.Size.Magnitude > size then
				best, size = d, d.Size.Magnitude
			end
		end
		if best then return best.CFrame end
		return obj:GetPivot()
	end
	return nil
end

local function getSafeZoneCFrame()
	local safeZoneObj = nil
	pcall(function() safeZoneObj = workspace["Steal Map"].Lobby["safe zone"] end)

	if safeZoneObj then
		local cf = getCFrame(safeZoneObj)
		if cf then return cf * CFrame.new(0, 3, 0) end
	end

	pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("SpawnLocation") then
				safeZoneObj = obj.CFrame * CFrame.new(0, 3, 0)
				break
			end
		end
	end)
	return safeZoneObj or spawnCFrame
end

local function getMyPlotFloor()
	local myUserId = LocalPlayer.UserId
	local myName = LocalPlayer.Name:lower()

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "floor" or obj:GetAttribute("IsPlotFloor") then
			local ownerId = obj:GetAttribute("OwnerUserId")
			if ownerId and tonumber(ownerId) == myUserId then return obj end

			local parentPlot = obj.Parent
			if parentPlot then
				local plotSign = parentPlot:FindFirstChild("PlotSign", true)
				if plotSign then
					local ownerNameLabel = plotSign:FindFirstChild("OwnerName", true)
					if ownerNameLabel and ownerNameLabel:IsA("TextLabel") then
						if ownerNameLabel.Text:lower():find(myName) then return obj end
					end
				end
			end
		end
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "floor" and obj:IsA("BasePart") then
			local ownerId = obj:GetAttribute("OwnerUserId")
			if ownerId and tonumber(ownerId) == myUserId then return obj end
		end
	end
	return nil
end

local function quickFirePrompt(prompt)
	if not prompt then return false end
	pcall(function()
		prompt.Enabled = true
		prompt.MaxActivationDistance = 999
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
	end)
	local ok = false
	pcall(function()
		fireproximityprompt(prompt)
		ok = true
	end)
	return ok
end

local function forceFirePrompt(prompt)
	if not prompt then return false end
	local oldEnabled = prompt.Enabled
	local oldMaxDist = prompt.MaxActivationDistance
	local oldHold = prompt.HoldDuration
	local oldRequires = prompt.RequiresLineOfSight

	pcall(function()
		prompt.Enabled = true
		prompt.MaxActivationDistance = 999
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
	end)

	pcall(function() fireproximityprompt(prompt) end)

	pcall(function()
		prompt.Enabled = oldEnabled
		prompt.MaxActivationDistance = oldMaxDist
		prompt.HoldDuration = oldHold
		prompt.RequiresLineOfSight = oldRequires
	end)
	return true
end

-- Core Logic Features
local function startEquipBest()
	task.spawn(function()
		while equipBestEnabled do
			if not itemLoadoutEvent then itemLoadoutEvent = ReplicatedStorage:FindFirstChild("rf_ITEM_LOADOUT") end
			if itemLoadoutEvent then
				pcall(function() itemLoadoutEvent:InvokeServer("placebest") end)
			end
			task.wait(2)
		end
	end)
end

local function startAutoOpen()
	task.spawn(function()
		while autoOpenEnabled do
			pcall(function()
				local floorObj = getMyPlotFloor()
				if floorObj then
					local foundAny = false
					for _, child in ipairs(floorObj:GetChildren()) do
						if child.Name == "AppraisingCrate" or child.Name:find("Crate") then
							for _, desc in ipairs(child:GetDescendants()) do
								if desc:IsA("ProximityPrompt") then
									foundAny = true
									forceFirePrompt(desc)
									task.wait(0.15)
									if not autoOpenEnabled then break end
								end
							end
						end
						if not autoOpenEnabled then break end
					end
					if not foundAny then task.wait(1.5) end
				else
					task.wait(2)
				end
			end)
			task.wait(0.3)
		end
	end)
end

local function getCrateTools()
	local tools = {}
	local function scan(container)
		if not container then return end
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") and item.Name:lower():find("crate") then
				table.insert(tools, item)
			end
		end
	end
	scan(LocalPlayer:FindFirstChild("Backpack"))
	scan(LocalPlayer.Character)
	return tools
end

local function startAutoPlace()
	task.spawn(function()
		while autoPlaceEnabled do
			pcall(function()
				if not placeAtEvent then placeAtEvent = ReplicatedStorage:FindFirstChild("re_PLACE_AT") end
				local floorObj = getMyPlotFloor()
				local crateTools = getCrateTools()

				if floorObj and #crateTools > 0 and placeAtEvent then
					local floorCF = getCFrame(floorObj)
					if floorCF then
						local selectedTool = crateTools[math.random(1, #crateTools)]
						local character = LocalPlayer.Character
						local humanoid = character and character:FindFirstChildOfClass("Humanoid")

						if humanoid and selectedTool.Parent ~= character then
							humanoid:EquipTool(selectedTool)
							task.wait(0.2)
						end

						local offsetX = math.random(-8, 8)
						local offsetZ = math.random(-8, 8)
						local placePos = floorCF.Position + Vector3.new(offsetX, 1.5, offsetZ)

						placeAtEvent:FireServer(placePos, 0)
						task.wait(0.5)
					end
				else
					task.wait(2)
				end
			end)
			task.wait(0.5)
		end
	end)
end

local function getZoneFromName(name)
	local parts = string.split(name, "_")
	if #parts >= 2 and parts[1] == "Crate" then return parts[2] end
	return nil
end

local zoneList = {}
local zoneSet = {}

local function refreshZones()
	zoneList = {}
	zoneSet = {}
	pcall(function()
		local crates = workspace:FindFirstChild("Crates")
		if not crates then return end
		for _, child in ipairs(crates:GetChildren()) do
			local zone = getZoneFromName(child.Name)
			if zone and not zoneSet[zone] then
				zoneSet[zone] = true
				table.insert(zoneList, zone)
			end
		end
		table.sort(zoneList)
	end)

	if #zoneList == 0 then
		zoneList = {
			"Angel", "Archeologist", "Astronaut", "Celebrity",
			"DemonKing", "GoldTycoon", "Grandpa", "MafiaBoss",
			"MuseumOwner", "PirateCaptain"
		}
	end

	if selectedZone == "" or not zoneSet[selectedZone] then
		selectedZone = zoneList[1]
	end
end

refreshZones()

local function getZoneCrates(zoneName)
	local list = {}
	pcall(function()
		local crates = workspace:FindFirstChild("Crates")
		if not crates then return end
		for _, child in ipairs(crates:GetChildren()) do
			if getZoneFromName(child.Name) == zoneName then
				table.insert(list, child)
			end
		end
	end)
	return list
end

local function startAutoCrate()
	task.spawn(function()
		while autoCrateEnabled do
			pcall(function()
				local crates = getZoneCrates(selectedZone)
				if #crates > 0 then
					local crate = crates[math.random(1, #crates)]
					local cf = getCFrame(crate)

					if cf then
						teleportTo(cf * CFrame.new(0, 2, 0))
						task.wait(0.15)

						local promptFound = nil
						for _, desc in ipairs(crate:GetDescendants()) do
							if desc:IsA("ProximityPrompt") then
								promptFound = desc
								break
							end
						end

						if not promptFound then
							local originPos = cf.Position
							for _, p in ipairs(workspace:GetDescendants()) do
								if p:IsA("ProximityPrompt") and p.Parent then
									local parentPos = getCFrame(p.Parent)
									if parentPos and (parentPos.Position - originPos).Magnitude <= 15 then
										promptFound = p
										break
									end
								end
							end
						end

						if promptFound then quickFirePrompt(promptFound) end

						local retCF = getSafeZoneCFrame()
						if retCF then teleportTo(retCF) end
					end
				else
					task.wait(1.5)
				end
			end)
			task.wait(0.2)
		end
	end)
end

-- ==================== Pembuatan Ares Hub UI ====================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AresHub_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 100
ScreenGui.Parent = PlayerGui

local FloatingIcon = Instance.new("ImageButton", ScreenGui)
FloatingIcon.Name = "AresFloatingIcon"
FloatingIcon.Size = UDim2.new(0, 50, 0, 50)
FloatingIcon.Position = UDim2.new(0.02, 0, 0.25, 0)
FloatingIcon.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
FloatingIcon.Image = "rbxassetid://94158239411156"
FloatingIcon.Active = true
FloatingIcon.Draggable = true

Instance.new("UICorner", FloatingIcon).CornerRadius = UDim.new(0, 10)
local IconStroke = Instance.new("UIStroke", FloatingIcon)
IconStroke.Thickness = 1.5
IconStroke.Color = Color3.fromRGB(60, 60, 60)

local MainFrame = Instance.new("ImageLabel", ScreenGui)
MainFrame.Name = "AresMainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 320)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -160)
MainFrame.Image = "rbxassetid://107592201437230"
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 1
MainStroke.Color = Color3.fromRGB(45, 45, 50)

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 35)
TopBar.BackgroundTransparency = 1

local HubTitle = Instance.new("TextLabel", TopBar)
HubTitle.Size = UDim2.new(0, 250, 1, 0)
HubTitle.Position = UDim2.new(0, 15, 0, 0)
HubTitle.BackgroundTransparency = 1
HubTitle.Text = "Ares Hub - Steal From The Rich"
HubTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
HubTitle.Font = Enum.Font.GothamBold
HubTitle.TextSize = 13
HubTitle.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 2)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
CloseBtn.Font = Enum.Font.GothamMedium
CloseBtn.TextSize = 14

CloseBtn.MouseButton1Click:Connect(function()
	MainFrame.Visible = false
end)

FloatingIcon.MouseButton1Click:Connect(function()
	MainFrame.Visible = not MainFrame.Visible
end)

local ContentFrame = Instance.new("Frame", MainFrame)
ContentFrame.Size = UDim2.new(1, -20, 1, -45)
ContentFrame.Position = UDim2.new(0, 10, 0, 38)
ContentFrame.BackgroundTransparency = 1

local LeftColumn = Instance.new("ScrollingFrame", ContentFrame)
LeftColumn.Size = UDim2.new(0.5, -5, 1, 0)
LeftColumn.Position = UDim2.new(0, 0, 0, 0)
LeftColumn.BackgroundTransparency = 1
LeftColumn.ScrollBarThickness = 2
LeftColumn.BorderSizePixel = 0

local RightColumn = Instance.new("ScrollingFrame", ContentFrame)
RightColumn.Size = UDim2.new(0.5, -5, 1, 0)
RightColumn.Position = UDim2.new(0.5, 5, 0, 0)
RightColumn.BackgroundTransparency = 1
RightColumn.ScrollBarThickness = 2
RightColumn.BorderSizePixel = 0

local LeftList = Instance.new("UIListLayout", LeftColumn)
LeftList.Padding = UDim.new(0, 6)

local RightList = Instance.new("UIListLayout", RightColumn)
RightList.Padding = UDim.new(0, 6)

local Library = {}

function Library:AddToggle(parent, text, default, callback)
	local ToggleFrame = Instance.new("Frame", parent)
	ToggleFrame.Size = UDim2.new(1, -6, 0, 26)
	ToggleFrame.BackgroundTransparency = 1

	local Label = Instance.new("TextLabel", ToggleFrame)
	Label.Size = UDim2.new(0.7, 0, 1, 0)
	Label.BackgroundTransparency = 1
	Label.Text = text
	Label.TextColor3 = Color3.fromRGB(200, 200, 200)
	Label.Font = Enum.Font.Gotham
	Label.TextSize = 10
	Label.TextXAlignment = Enum.TextXAlignment.Left

	local Switch = Instance.new("TextButton", ToggleFrame)
	Switch.Size = UDim2.new(0, 32, 0, 16)
	Switch.Position = UDim2.new(1, -35, 0.5, -8)
	Switch.BackgroundColor3 = default and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(50, 50, 55)
	Switch.Text = ""

	Instance.new("UICorner", Switch).CornerRadius = UDim.new(1, 0)

	local Circle = Instance.new("Frame", Switch)
	Circle.Size = UDim2.new(0, 12, 0, 12)
	Circle.Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
	Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Instance.new("UICorner", Circle).CornerRadius = UDim.new(1, 0)

	local state = default
	Switch.MouseButton1Click:Connect(function()
		state = not state
		if state then
			Switch.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
			Circle.Position = UDim2.new(1, -14, 0.5, -6)
		else
			Switch.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
			Circle.Position = UDim2.new(0, 2, 0.5, -6)
		end
		callback(state)
	end)
end

function Library:AddDropdown(parent, text, options, callback)
	local DropFrame = Instance.new("Frame", parent)
	DropFrame.Size = UDim2.new(1, -6, 0, 26)
	DropFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
	DropFrame.ClipsDescendants = true
	Instance.new("UICorner", DropFrame).CornerRadius = UDim.new(0, 5)

	local ToggleBtn = Instance.new("TextButton", DropFrame)
	ToggleBtn.Size = UDim2.new(1, 0, 0, 26)
	ToggleBtn.BackgroundTransparency = 1
	ToggleBtn.Text = "  " .. text .. ": " .. (options[1] or "")
	ToggleBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	ToggleBtn.Font = Enum.Font.Gotham
	ToggleBtn.TextSize = 10
	ToggleBtn.TextXAlignment = Enum.TextXAlignment.Left

	local ListHolder = Instance.new("Frame", DropFrame)
	ListHolder.Size = UDim2.new(1, 0, 0, #options * 20)
	ListHolder.Position = UDim2.new(0, 0, 0, 26)
	ListHolder.BackgroundTransparency = 1
	Instance.new("UIListLayout", ListHolder)

	local isOpen = false
	ToggleBtn.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		DropFrame.Size = UDim2.new(1, -6, 0, isOpen and (26 + #options * 20) or 26)
	end)

	for _, opt in ipairs(options) do
		local Item = Instance.new("TextButton", ListHolder)
		Item.Size = UDim2.new(1, 0, 0, 20)
		Item.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
		Item.Text = opt
		Item.TextColor3 = Color3.fromRGB(160, 160, 160)
		Item.Font = Enum.Font.Gotham
		Item.TextSize = 9

		Item.MouseButton1Click:Connect(function()
			ToggleBtn.Text = "  " .. text .. ": " .. opt
			isOpen = false
			DropFrame.Size = UDim2.new(1, -6, 0, 26)
			callback(opt)
		end)
	end
end

-- Menambahkan Elemen Baru Fitur Steal From The Rich ke UI
Library:AddDropdown(LeftColumn, "Select Zone", zoneList, function(v)
	selectedZone = v
end)

Library:AddToggle(LeftColumn, "Auto Crate", false, function(v)
	autoCrateEnabled = v
	if v then startAutoCrate() end
end)

Library:AddToggle(LeftColumn, "Auto Place", false, function(v)
	autoPlaceEnabled = v
	if v then startAutoPlace() end
end)

Library:AddToggle(RightColumn, "Auto Open", false, function(v)
	autoOpenEnabled = v
	if v then startAutoOpen() end
end)

Library:AddToggle(RightColumn, "Equip Best", false, function(v)
	equipBestEnabled = v
	if v then startEquipBest() end
end)


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Bersihkan UI lama jika ada
if PlayerGui:FindFirstChild("AresHub_UI") then
	PlayerGui.AresHub_UI:Destroy()
end

-- Service & Remote Objects
local placeAtEvent, itemLoadoutEvent
pcall(function() placeAtEvent = ReplicatedStorage:FindFirstChild("re_PLACE_AT") end)
pcall(function() itemLoadoutEvent = ReplicatedStorage:FindFirstChild("rf_ITEM_LOADOUT") end)

-- State Variables
local selectedZone = ""
local autoCrateEnabled = false
local autoPlaceEnabled = false
local autoOpenEnabled = false
local equipBestEnabled = false
local tpModeEnabled = false -- Toggle Mode TP / Tween
local spawnCFrame = nil

-- Save Spawn Position
task.spawn(function()
	task.wait(1)
	pcall(function()
		local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then spawnCFrame = root.CFrame end
	end)
end)

-- Custom Movement Logic (Tween 780 + TP Height Custom)
local function ForceTweenTo(targetCFrame, speed)
	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)

	local dist = (root.Position - targetCFrame.Position).Magnitude
	local info = TweenInfo.new(dist / (speed or 780), Enum.EasingStyle.Linear)
	local tween = TweenService:Create(root, info, {CFrame = targetCFrame})
	tween:Play()
	tween.Completed:Wait()
end

local function moveCharacter(targetCFrame)
	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if tpModeEnabled then
		-- Mode TP: Naik 15 Studs -> TP ke atas Target/Home -> Turun
		local currentCF = root.CFrame
		local upCF = currentCF * CFrame.new(0, 15, 0)
		local targetUpCF = targetCFrame * CFrame.new(0, 15, 0)

		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			
			-- 1. Naik 15 studs
			char:PivotTo(upCF)
			task.wait(0.05)

			-- 2. TP ke posisi atas area tujuan
			char:PivotTo(targetUpCF)
			task.wait(0.05)

			-- 3. Turun ke lantai tujuan
			char:PivotTo(targetCFrame)
		end)
	else
		-- Mode Tween Speed 780
		ForceTweenTo(targetCFrame, 780)
	end

	-- Jeda/Delay 1 Detik setelah pergerakan
	task.wait(1)
end

local function getCFrame(obj)
	if not obj then return nil end
	if obj:IsA("BasePart") then
		return obj.CFrame
	elseif obj:IsA("Attachment") then
		return obj.WorldCFrame
	elseif obj:IsA("Model") then
		if obj.PrimaryPart then return obj.PrimaryPart.CFrame end
		local best, size = nil, 0
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") and d.Size.Magnitude > size then
				best, size = d, d.Size.Magnitude
			end
		end
		if best then return best.CFrame end
		return obj:GetPivot()
	end
	return nil
end

local function getSafeZoneCFrame()
	local safeZoneObj = nil
	pcall(function() safeZoneObj = workspace["Steal Map"].Lobby["safe zone"] end)

	if safeZoneObj then
		local cf = getCFrame(safeZoneObj)
		if cf then return cf * CFrame.new(0, 3, 0) end
	end

	pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("SpawnLocation") then
				safeZoneObj = obj.CFrame * CFrame.new(0, 3, 0)
				break
			end
		end
	end)
	return safeZoneObj or spawnCFrame
end

local function getMyPlotFloor()
	local myUserId = LocalPlayer.UserId
	local myName = LocalPlayer.Name:lower()

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "floor" or obj:GetAttribute("IsPlotFloor") then
			local ownerId = obj:GetAttribute("OwnerUserId")
			if ownerId and tonumber(ownerId) == myUserId then return obj end

			local parentPlot = obj.Parent
			if parentPlot then
				local plotSign = parentPlot:FindFirstChild("PlotSign", true)
				if plotSign then
					local ownerNameLabel = plotSign:FindFirstChild("OwnerName", true)
					if ownerNameLabel and ownerNameLabel:IsA("TextLabel") then
						if ownerNameLabel.Text:lower():find(myName) then return obj end
					end
				end
			end
		end
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "floor" and obj:IsA("BasePart") then
			local ownerId = obj:GetAttribute("OwnerUserId")
			if ownerId and tonumber(ownerId) == myUserId then return obj end
		end
	end
	return nil
end

local function quickFirePrompt(prompt)
	if not prompt then return false end
	pcall(function()
		prompt.Enabled = true
		prompt.MaxActivationDistance = 999
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
	end)
	local ok = false
	pcall(function()
		fireproximityprompt(prompt)
		ok = true
	end)
	return ok
end

local function forceFirePrompt(prompt)
	if not prompt then return false end
	local oldEnabled = prompt.Enabled
	local oldMaxDist = prompt.MaxActivationDistance
	local oldHold = prompt.HoldDuration
	local oldRequires = prompt.RequiresLineOfSight

	pcall(function()
		prompt.Enabled = true
		prompt.MaxActivationDistance = 999
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
	end)

	pcall(function() fireproximityprompt(prompt) end)

	pcall(function()
		prompt.Enabled = oldEnabled
		prompt.MaxActivationDistance = oldMaxDist
		prompt.HoldDuration = oldHold
		prompt.RequiresLineOfSight = oldRequires
	end)
	return true
end

-- Core Logic Features
local function startEquipBest()
	task.spawn(function()
		while equipBestEnabled do
			if not itemLoadoutEvent then itemLoadoutEvent = ReplicatedStorage:FindFirstChild("rf_ITEM_LOADOUT") end
			if itemLoadoutEvent then
				pcall(function() itemLoadoutEvent:InvokeServer("placebest") end)
			end
			task.wait(2)
		end
	end)
end

local function startAutoOpen()
	task.spawn(function()
		while autoOpenEnabled do
			pcall(function()
				local floorObj = getMyPlotFloor()
				if floorObj then
					local foundAny = false
					for _, child in ipairs(floorObj:GetChildren()) do
						if child.Name == "AppraisingCrate" or child.Name:find("Crate") then
							for _, desc in ipairs(child:GetDescendants()) do
								if desc:IsA("ProximityPrompt") then
									foundAny = true
									forceFirePrompt(desc)
									task.wait(0.15)
									if not autoOpenEnabled then break end
								end
							end
						end
						if not autoOpenEnabled then break end
					end
					if not foundAny then task.wait(1.5) end
				else
					task.wait(2)
				end
			end)
			task.wait(0.3)
		end
	end)
end

local function getCrateTools()
	local tools = {}
	local function scan(container)
		if not container then return end
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") and item.Name:lower():find("crate") then
				table.insert(tools, item)
			end
		end
	end
	scan(LocalPlayer:FindFirstChild("Backpack"))
	scan(LocalPlayer.Character)
	return tools
end

local function startAutoPlace()
	task.spawn(function()
		while autoPlaceEnabled do
			pcall(function()
				if not placeAtEvent then placeAtEvent = ReplicatedStorage:FindFirstChild("re_PLACE_AT") end
				local floorObj = getMyPlotFloor()
				local crateTools = getCrateTools()

				if floorObj and #crateTools > 0 and placeAtEvent then
					local floorCF = getCFrame(floorObj)
					if floorCF then
						local selectedTool = crateTools[math.random(1, #crateTools)]
						local character = LocalPlayer.Character
						local humanoid = character and character:FindFirstChildOfClass("Humanoid")

						if humanoid and selectedTool.Parent ~= character then
							humanoid:EquipTool(selectedTool)
							task.wait(0.2)
						end

						local offsetX = math.random(-8, 8)
						local offsetZ = math.random(-8, 8)
						local placePos = floorCF.Position + Vector3.new(offsetX, 1.5, offsetZ)

						placeAtEvent:FireServer(placePos, 0)
						task.wait(0.5)
					end
				else
					task.wait(2)
				end
			end)
			task.wait(0.5)
		end
	end)
end

local function getZoneFromName(name)
	local parts = string.split(name, "_")
	if #parts >= 2 and parts[1] == "Crate" then return parts[2] end
	return nil
end

local zoneList = {}
local zoneSet = {}

local function refreshZones()
	zoneList = {}
	zoneSet = {}
	pcall(function()
		local crates = workspace:FindFirstChild("Crates")
		if not crates then return end
		for _, child in ipairs(crates:GetChildren()) do
			local zone = getZoneFromName(child.Name)
			if zone and not zoneSet[zone] then
				zoneSet[zone] = true
				table.insert(zoneList, zone)
			end
		end
		table.sort(zoneList)
	end)

	if #zoneList == 0 then
		zoneList = {
			"Angel", "Archeologist", "Astronaut", "Celebrity",
			"DemonKing", "GoldTycoon", "Grandpa", "MafiaBoss",
			"MuseumOwner", "PirateCaptain"
		}
	end

	if selectedZone == "" or not zoneSet[selectedZone] then
		selectedZone = zoneList[1]
	end
end

refreshZones()

local function getZoneCrates(zoneName)
	local list = {}
	pcall(function()
		local crates = workspace:FindFirstChild("Crates")
		if not crates then return end
		for _, child in ipairs(crates:GetChildren()) do
			if getZoneFromName(child.Name) == zoneName then
				table.insert(list, child)
			end
		end
	end)
	return list
end

local function startAutoCrate()
	task.spawn(function()
		while autoCrateEnabled do
			pcall(function()
				local crates = getZoneCrates(selectedZone)
				if #crates > 0 then
					local crate = crates[math.random(1, #crates)]
					local cf = getCFrame(crate)

					if cf then
						-- Pergerakan ke Crate menggunakan Method Tween / TP
						moveCharacter(cf * CFrame.new(0, 2, 0))

						local promptFound = nil
						for _, desc in ipairs(crate:GetDescendants()) do
							if desc:IsA("ProximityPrompt") then
								promptFound = desc
								break
							end
						end

						if not promptFound then
							local originPos = cf.Position
							for _, p in ipairs(workspace:GetDescendants()) do
								if p:IsA("ProximityPrompt") and p.Parent then
									local parentPos = getCFrame(p.Parent)
									if parentPos and (parentPos.Position - originPos).Magnitude <= 15 then
										promptFound = p
										break
									end
								end
							end
						end

						if promptFound then quickFirePrompt(promptFound) end

						-- Kembali ke Safe Zone / Home
						local retCF = getSafeZoneCFrame()
						if retCF then moveCharacter(retCF) end
					end
				else
					task.wait(1.5)
				end
			end)
			task.wait(0.2)
		end
	end)
end

-- ==================== Pembuatan Ares Hub UI ====================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AresHub_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 100
ScreenGui.Parent = PlayerGui

local FloatingIcon = Instance.new("ImageButton", ScreenGui)
FloatingIcon.Name = "AresFloatingIcon"
FloatingIcon.Size = UDim2.new(0, 50, 0, 50)
FloatingIcon.Position = UDim2.new(0.02, 0, 0.25, 0)
FloatingIcon.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
FloatingIcon.Image = "rbxassetid://94158239411156"
FloatingIcon.Active = true
FloatingIcon.Draggable = true

Instance.new("UICorner", FloatingIcon).CornerRadius = UDim.new(0, 10)
local IconStroke = Instance.new("UIStroke", FloatingIcon)
IconStroke.Thickness = 1.5
IconStroke.Color = Color3.fromRGB(60, 60, 60)

local MainFrame = Instance.new("ImageLabel", ScreenGui)
MainFrame.Name = "AresMainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 320)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -160)
MainFrame.Image = "rbxassetid://107592201437230"
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 1
MainStroke.Color = Color3.fromRGB(45, 45, 50)

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 35)
TopBar.BackgroundTransparency = 1

local HubTitle = Instance.new("TextLabel", TopBar)
HubTitle.Size = UDim2.new(0, 250, 1, 0)
HubTitle.Position = UDim2.new(0, 15, 0, 0)
HubTitle.BackgroundTransparency = 1
HubTitle.Text = "Ares Hub - Steal From The Rich V2"
HubTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
HubTitle.Font = Enum.Font.GothamBold
HubTitle.TextSize = 13
HubTitle.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 2)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
CloseBtn.Font = Enum.Font.GothamMedium
CloseBtn.TextSize = 14

CloseBtn.MouseButton1Click:Connect(function()
	MainFrame.Visible = false
end)

FloatingIcon.MouseButton1Click:Connect(function()
	MainFrame.Visible = not MainFrame.Visible
end)

local ContentFrame = Instance.new("Frame", MainFrame)
ContentFrame.Size = UDim2.new(1, -20, 1, -45)
ContentFrame.Position = UDim2.new(0, 10, 0, 38)
ContentFrame.BackgroundTransparency = 1

local LeftColumn = Instance.new("ScrollingFrame", ContentFrame)
LeftColumn.Size = UDim2.new(0.5, -5, 1, 0)
LeftColumn.Position = UDim2.new(0, 0, 0, 0)
LeftColumn.BackgroundTransparency = 1
LeftColumn.ScrollBarThickness = 2
LeftColumn.BorderSizePixel = 0

local RightColumn = Instance.new("ScrollingFrame", ContentFrame)
RightColumn.Size = UDim2.new(0.5, -5, 1, 0)
RightColumn.Position = UDim2.new(0.5, 5, 0, 0)
RightColumn.BackgroundTransparency = 1
RightColumn.ScrollBarThickness = 2
RightColumn.BorderSizePixel = 0

local LeftList = Instance.new("UIListLayout", LeftColumn)
LeftList.Padding = UDim.new(0, 6)

local RightList = Instance.new("UIListLayout", RightColumn)
RightList.Padding = UDim.new(0, 6)

local Library = {}

function Library:AddToggle(parent, text, default, callback)
	local ToggleFrame = Instance.new("Frame", parent)
	ToggleFrame.Size = UDim2.new(1, -6, 0, 26)
	ToggleFrame.BackgroundTransparency = 1

	local Label = Instance.new("TextLabel", ToggleFrame)
	Label.Size = UDim2.new(0.7, 0, 1, 0)
	Label.BackgroundTransparency = 1
	Label.Text = text
	Label.TextColor3 = Color3.fromRGB(200, 200, 200)
	Label.Font = Enum.Font.Gotham
	Label.TextSize = 10
	Label.TextXAlignment = Enum.TextXAlignment.Left

	local Switch = Instance.new("TextButton", ToggleFrame)
	Switch.Size = UDim2.new(0, 32, 0, 16)
	Switch.Position = UDim2.new(1, -35, 0.5, -8)
	Switch.BackgroundColor3 = default and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(50, 50, 55)
	Switch.Text = ""

	Instance.new("UICorner", Switch).CornerRadius = UDim.new(1, 0)

	local Circle = Instance.new("Frame", Switch)
	Circle.Size = UDim2.new(0, 12, 0, 12)
	Circle.Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
	Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Instance.new("UICorner", Circle).CornerRadius = UDim.new(1, 0)

	local state = default
	Switch.MouseButton1Click:Connect(function()
		state = not state
		if state then
			Switch.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
			Circle.Position = UDim2.new(1, -14, 0.5, -6)
		else
			Switch.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
			Circle.Position = UDim2.new(0, 2, 0.5, -6)
		end
		callback(state)
	end)
end

function Library:AddDropdown(parent, text, options, callback)
	local DropFrame = Instance.new("Frame", parent)
	DropFrame.Size = UDim2.new(1, -6, 0, 26)
	DropFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
	DropFrame.ClipsDescendants = true
	Instance.new("UICorner", DropFrame).CornerRadius = UDim.new(0, 5)

	local ToggleBtn = Instance.new("TextButton", DropFrame)
	ToggleBtn.Size = UDim2.new(1, 0, 0, 26)
	ToggleBtn.BackgroundTransparency = 1
	ToggleBtn.Text = "  " .. text .. ": " .. (options[1] or "")
	ToggleBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	ToggleBtn.Font = Enum.Font.Gotham
	ToggleBtn.TextSize = 10
	ToggleBtn.TextXAlignment = Enum.TextXAlignment.Left

	local ListHolder = Instance.new("Frame", DropFrame)
	ListHolder.Size = UDim2.new(1, 0, 0, #options * 20)
	ListHolder.Position = UDim2.new(0, 0, 0, 26)
	ListHolder.BackgroundTransparency = 1
	Instance.new("UIListLayout", ListHolder)

	local isOpen = false
	ToggleBtn.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		DropFrame.Size = UDim2.new(1, -6, 0, isOpen and (26 + #options * 20) or 26)
	end)

	for _, opt in ipairs(options) do
		local Item = Instance.new("TextButton", ListHolder)
		Item.Size = UDim2.new(1, 0, 0, 20)
		Item.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
		Item.Text = opt
		Item.TextColor3 = Color3.fromRGB(160, 160, 160)
		Item.Font = Enum.Font.Gotham
		Item.TextSize = 9

		Item.MouseButton1Click:Connect(function()
			ToggleBtn.Text = "  " .. text .. ": " .. opt
			isOpen = false
			DropFrame.Size = UDim2.new(1, -6, 0, 26)
			callback(opt)
		end)
	end
end

-- Elemen UI Steal From The Rich
Library:AddDropdown(LeftColumn, "Select Zone", zoneList, function(v)
	selectedZone = v
end)

Library:AddToggle(LeftColumn, "Auto Crate", false, function(v)
	autoCrateEnabled = v
	if v then startAutoCrate() end
end)

Library:AddToggle(LeftColumn, "Use Teleport Mode", false, function(v)
	tpModeEnabled = v
end)

Library:AddToggle(RightColumn, "Auto Place", false, function(v)
	autoPlaceEnabled = v
	if v then startAutoPlace() end
end)

Library:AddToggle(RightColumn, "Auto Open", false, function(v)
	autoOpenEnabled = v
	if v then startAutoOpen() end
end)

Library:AddToggle(RightColumn, "Equip Best", false, function(v)
	equipBestEnabled = v
	if v then startEquipBest() end
end)
