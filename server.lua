local remotes = game.ReplicatedStorage:WaitForChild("weaponRemotes")
local weapons = game.ReplicatedStorage:WaitForChild("weapons") -- table for keeping track of weapons
local Players = game:GetService("Players")
local RepS = game:GetService("ReplicatedStorage")
local RunS = game:GetService("RunService")
local Debris = game:GetService("Debris")
local fireHandler = require(RepS.modules.fireHandler)

local defaultWeapons = {
	[1] = "m4a4";
	[2] = "DBS"
}
local players = {}

local bullets = {}

local parameters = RaycastParams.new()
parameters.FilterType = Enum.RaycastFilterType.Blacklist
parameters.FilterDescendantsInstances = {}

local magazineCount = 5

remotes:WaitForChild("new").OnServerInvoke = function(player)
	if not player.Character then return end

	-- we create a new table for the player
	players[player.UserId] = {}
	local weaponTable = players[player.UserId]
	
	-- some stuff for later
	weaponTable.magData = {}
	weaponTable.weapons = {}
	weaponTable.loadedAnimations = {}
	weaponTable.aiming = false

	-- add each available weapon
	local transferTable
	for index, weaponName in pairs(defaultWeapons) do 

		-- clone gun
		local weapon = weapons[weaponName]:Clone()
		local weaponSettings = require(weapon.settings)

		-- index gun
		weaponTable.weapons[weaponName] = { weapon = weapon; settings = weaponSettings; shotCount = 0}

		-- save gun magazines
		weaponTable.magData[index] = { current = weaponSettings.firing.magCapacity; spare = weaponSettings.firing.magCapacity * magazineCount  }

		--  holster
		weapon.Parent = player.Character
		weapon.receiver.backweld.Part0 = player.Character.Torso
		weapon.receiver.backweld.C1 = weapon.offsets.back.Value

		-- put gun into raycast ignore list
		transferTable = parameters.FilterDescendantsInstances
		table.insert(transferTable, weapon)
		parameters.FilterDescendantsInstances = {table.unpack(transferTable)}
	end
	remotes.rcparams:FireAllClients(transferTable)
	
	-- we give the client the gun list
	return defaultWeapons, weaponTable.magData
end

remotes:WaitForChild("equip").OnServerInvoke = function(player, wepName)
	if players[player.UserId].currentWeapon and not players[player.UserId].unequipping then return print("1") end
	if not players[player.UserId].weapons[wepName] then return print("2") end
	if not player.Character then return end 
	local weaponTable = players[player.UserId]
	
	--game.Workspace[player.Name].Animate.Disabled = true
	
	-- we mark the current gun
	weaponTable.currentWeapon = weaponTable.weapons[wepName] 
	player.gun.Value = weaponTable.currentWeapon.weapon

	--  unholster
	weaponTable.currentWeapon.Parent = player.Character
	weaponTable.currentWeapon.weapon.receiver.backweld.Part0 = nil

	-- equip gun
	weaponTable.currentWeapon.weapon.receiver.weaponHold.Part0 = player.Character["Right Arm"]
	
	weaponTable.loadedAnimations.currentAnim = nil
	--weaponTable.loadedAnimations.currentArmsAnim = nil
	--weaponTable.loadedAnimations.currentLegsAnim = nil
	
	if weaponTable.legsState ~= "crouching" then
		weaponTable.legsState = "walking"
	end
	weaponTable.armsState = "holding"
	weaponTable.loadedAnimations.aim = player.Character.Humanoid:LoadAnimation(weaponTable.currentWeapon.settings.animations.player.aim)
	weaponTable.loadedAnimations.hold = player.Character.Humanoid:LoadAnimation(weaponTable.currentWeapon.settings.animations.player.hold)
	weaponTable.loadedAnimations.walk = player.Character.Humanoid:LoadAnimation(weaponTable.currentWeapon.settings.animations.player.walk)
	weaponTable.loadedAnimations.unarmedRun = player.Character.Humanoid:LoadAnimation(weaponTable.currentWeapon.settings.animations.player.unarmedRun)
	weaponTable.loadedAnimations.armedRun = player.Character.Humanoid:LoadAnimation(weaponTable.currentWeapon.settings.animations.player.armedRun)
	weaponTable.loadedAnimations.crouch = player.Character.Humanoid:LoadAnimation(weaponTable.currentWeapon.settings.animations.player.crouch)
	weaponTable.loadedAnimations.shoot = player.Character.Humanoid:LoadAnimation(weaponTable.currentWeapon.settings.animations.player.shoot)
	weaponTable.loadedAnimations.aimshoot = player.Character.Humanoid:LoadAnimation(weaponTable.currentWeapon.settings.animations.player.aimshoot)
	weaponTable.loadedAnimations.reload = player.Character.Humanoid:LoadAnimation(weaponTable.currentWeapon.settings.animations.player.reload)
	----weaponTable.loadedAnimations.idlewalk:Play()
	----weaponTable.loadedAnimations.idlewalk:AdjustSpeed(0)
	
	weaponTable.loadedAnimations.hold:Play()
	weaponTable.loadedAnimations.walk:Play()
	weaponTable.loadedAnimations.walk:AdjustSpeed(0)

	local rundetect = coroutine.wrap(function()
		while players[player.UserId].currentWeapon do
			if weaponTable.legsState == "walking" then
				if not weaponTable.loadedAnimations.walk.IsPlaying then
					print("walking")
					weaponTable.loadedAnimations.walk:Play()
				end
				
				if player.Character.Humanoid.MoveDirection.Magnitude > 0 then
					weaponTable.loadedAnimations.walk:AdjustSpeed(1)
				elseif player.Character.Humanoid.MoveDirection.Magnitude == 0 then
					weaponTable.loadedAnimations.walk:AdjustSpeed(0)
				end
				player.Character.Humanoid.WalkSpeed = 16
				
			elseif weaponTable.legsState == "crouching" then
				if not weaponTable.loadedAnimations.crouch.IsPlaying then
					weaponTable.loadedAnimations.crouch:Play()
				end
				
				if player.Character.Humanoid.MoveDirection.Magnitude > 0 then
					weaponTable.loadedAnimations.crouch:AdjustSpeed(1)
				elseif player.Character.Humanoid.MoveDirection.Magnitude == 0 then
					weaponTable.loadedAnimations.crouch:AdjustSpeed(0)
				end
				player.Character.Humanoid.WalkSpeed = 8
				
			elseif weaponTable.legsState == "sprinting" then
				if player.Character.Humanoid.MoveDirection.Magnitude == 0 then
					weaponTable.legsState = "walking"
					weaponTable.loadedAnimations.currentAnim:Stop()
				end
			end
		
			
			if weaponTable.armsState == "holding" then
				if not weaponTable.loadedAnimations.hold.IsPlaying then
					weaponTable.loadedAnimations.hold:Play()
				end
				
			elseif weaponTable.armsState == "aiming" then
				if weaponTable.loadedAnimations.currentAnim ~= nil then
					weaponTable.loadedAnimations.currentAnim:Stop()
					weaponTable.legsState = "walking"
				end
				
				if not weaponTable.loadedAnimations.aim.IsPlaying then
					weaponTable.loadedAnimations.aim:Play()
				end
				
			elseif players[player.UserId].armsState == "reloading" then
				if not weaponTable.loadedAnimations.reload.IsPlaying then
					weaponTable.loadedAnimations.reload:Play()
					event = weaponTable.loadedAnimations.reload.Stopped:Connect(function()
						event:Disconnect()
						if weaponTable.reloadCancelled then weaponTable.reloadCancelled = false return end
						weaponTable.currentWeapon.shotCount = 0
						weaponTable.armsState = "holding"
					end)
				end
			end
			wait()
		end
	end)
	
	rundetect()
	-- yes client u can equip gun
	return true 
end

remotes:WaitForChild("unequip").OnServerInvoke = function(player)
	if not players[player.UserId].currentWeapon then return end
	if not player.Character then return end 
	local weaponTable = players[player.UserId]
	
	--game.Workspace[player.Name].Animate.Disabled = false
	for i, v in pairs(weaponTable.loadedAnimations) do
		if v.IsPlaying then
			if v ~= weaponTable.loadedAnimations.crouch then
				v:Stop()
			end
		end
	end
	if weaponTable.legsState ~= "crouching" then
		player.Character.Humanoid.WalkSpeed = 16
	end
	
	-----------------------------------------------------------------------weaponTable.loadedAnimations = {}

	-- holster
	weaponTable.currentWeapon.Parent = player.Character
	weaponTable.currentWeapon.weapon.receiver.backweld.Part0 = player.Character.Torso

	weaponTable.currentWeapon.weapon.receiver.weaponHold.Part0 = nil

	-- we mark the inexistence of the current gun
	weaponTable.unequipping = true
	wait(0.6)
	weaponTable.currentWeapon = nil
	weaponTable.unequipping = false
	player.gun.Value = nil

	-- 
	return true 
end

--[[remotes:WaitForChild("clientResult").OnServerEvent:Connect(function(player, id, clientResult)
	bullets[id].clientResult = clientResult
end)--]]

local function directionCheck(camD, shotD)
	local x = math.abs(camD.X - shotD.X)
	if x > 0.2 then return false end
	local y = math.abs(camD.Y - shotD.Y)
	if y > 0.2 then return false end
	local z = math.abs(camD.Z - shotD.Z)
	if z > 0.2 then return false end
	--print(x,y,z)
	return true
end

remotes:WaitForChild("fire").OnServerEvent:Connect(function(player, origin, direction, id, camCF)
	if players[player.UserId].legsState == "sprinting" then return end
	if players[player.UserId].armsState == "reloading" then return end
	print(players[player.UserId].currentWeapon)
	if players[player.UserId].currentWeapon.shotCount >= players[player.UserId].currentWeapon.settings.firing.magCapacity then
		players[player.UserId].armsState = "reloading"
		return
	end
	
	local cameraDirection = camCF.LookVector
	local shotDirection = direction.LookVector
	--print(cameraDirection, shotDirection)
	local pass = directionCheck(cameraDirection, shotDirection)
	if not pass then print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")return end
	
	------------------------------------------------------checks completed------------------------------------------------
	
	remotes.fire:FireAllClients(player, origin, direction, players[player.UserId].currentWeapon.settings)
	
	if players[player.UserId].armsState == "aiming" then
		players[player.UserId].loadedAnimations.aimshoot:Play()
	else
		players[player.UserId].loadedAnimations.shoot:Play()
	end
	
	players[player.UserId].currentWeapon.shotCount = players[player.UserId].currentWeapon.shotCount + 1
	bullets[id] = {serverResult = "tbd"; clientResult = "placeholder"}

	wait(7)
	bullets[id] = nil
	print("id deleted")
end)


remotes:WaitForChild("run").OnServerEvent:Connect(function(player, run, armed)
	if run then	
		if armed then
			players[player.UserId].loadedAnimations.armedRun:Play()
			player.Character.Humanoid.WalkSpeed = 27
			players[player.UserId].loadedAnimations.currentAnim = players[player.UserId].loadedAnimations.armedRun
		else
			players[player.UserId].loadedAnimations.unarmedRun:Play()
			player.Character.Humanoid.WalkSpeed = 27
			players[player.UserId].loadedAnimations.currentAnim = players[player.UserId].loadedAnimations.unarmedRun
		end
		
		if players[player.UserId].loadedAnimations.reload.IsPlaying then
			players[player.UserId].reloadCancelled = true
			players[player.UserId].loadedAnimations.reload:Stop()
			players[player.UserId].armsState = "holding"
		end
		if players[player.UserId].loadedAnimations.crouch.IsPlaying then
			players[player.UserId].loadedAnimations.crouch:Stop()
		end
		if players[player.UserId].loadedAnimations.aim.IsPlaying then
			players[player.UserId].loadedAnimations.aim:Stop()
			players[player.UserId].armsState = "holding"
		end
		players[player.UserId].legsState = "sprinting"
	else
		if players[player.UserId].loadedAnimations.currentAnim ~= nil then
			players[player.UserId].loadedAnimations.currentAnim:Stop()
		end
		players[player.UserId].loadedAnimations.currentAnim = nil
		player.Character.Humanoid.WalkSpeed = 16
		players[player.UserId].legsState = "walking"
	end
end)	

remotes:WaitForChild("aim").OnServerEvent:Connect(function(player, toaim)

	if not players[player.UserId].currentWeapon then return end
	if not player.Character then return end 
	
	if toaim then
		players[player.UserId].armsState = "aiming"
	else
		players[player.UserId].loadedAnimations.aim:Stop()
		players[player.UserId].armsState = "holding"
	end
end)

remotes:WaitForChild("crouch").OnServerEvent:Connect(function(player)
	if players[player.UserId].legsState ~= "crouching" then
		players[player.UserId].legsState = "crouching"
	else
		players[player.UserId].loadedAnimations.crouch:Stop()
		players[player.UserId].legsState = "walking"
	end
end)	

remotes:WaitForChild("reload").OnServerEvent:Connect(function(player)
	if players[player.UserId].legsState == "sprinting" then return end
	if players[player.UserId].armsState == "reloading" then return end
	if players[player.UserId].currentWeapon.shotCount == 0 then return end
	
	players[player.UserId].armsState = "reloading"
end)




local data = {}
local pingData = {}
local playersTable = {}

game.Players.PlayerAdded:Connect(function(player)
	
	table.insert(playersTable, player)

	local values = {
		{ name = "gun"; value = nil; type = "ObjectValue" };
	}

	for _, v in pairs(values) do
		local value = Instance.new(v.type)
		value.Name = v.name
		value.Value = v.value
		value.Parent = player
	end
	
	local playerCosmetics = {}
	pingData[player.UserId] = {}
	
	player.CharacterAdded:Connect(function()
		local character = player.Character or player.CharacterAdded:Wait()
		wait(1)
		local playerParts = player.Character:GetChildren()
		local transferTable 
		for i, v in pairs(playerParts) do
			if not v:FindFirstChild("Handle") then continue end
			table.insert(playerCosmetics, v)
			
			transferTable = parameters.FilterDescendantsInstances
			table.insert(transferTable, v)
			parameters.FilterDescendantsInstances = {table.unpack(transferTable)}
		end
		remotes.rcparams:FireAllClients(transferTable)
		
		for i, v in pairs(parameters.FilterDescendantsInstances) do 
			print(v)
		end
	end)
	
	player.CharacterRemoving:Connect(function()
		local transferTable
		if playerCosmetics then
			for i, v in pairs(playerCosmetics) do
				local index = table.find(parameters.FilterDescendantsInstances, v)
				transferTable = parameters.FilterDescendantsInstances
				table.remove(transferTable, index)
				parameters.FilterDescendantsInstances = {table.unpack(transferTable)}
			end
			playerCosmetics = {}
		end
		for i, v in pairs(defaultWeapons) do
			local index = table.find(parameters.FilterDescendantsInstances, v)
			transferTable = parameters.FilterDescendantsInstances
			table.remove(transferTable, index)
			parameters.FilterDescendantsInstances = {table.unpack(transferTable)}
		end
		remotes.rcparams:FireAllClients(transferTable)
	end)
end)

game.Players.PlayerRemoving:Connect(function(player)
	local index = table.find(playersTable, player)
	table.remove(playersTable, index)
end)

function Posinterp(ST, target)
	local userid = game.Players[target.Name].UserId
	local indexTable = {}
	table.insert(indexTable, ST)
	for i, v in pairs(data) do
		table.insert(indexTable, i)
	end
	table.sort(indexTable)
	local prevTime = indexTable[table.find(indexTable, ST) - 1]
	local postTime = indexTable[table.find(indexTable, ST) + 1]
	local prevCF = data[prevTime][userid]
	local postCF = data[postTime][userid]
	local Timediff = postTime - prevTime
	local interpPercentage = (ST-prevTime) /Timediff
	
	local part1 = game.Workspace.Wpos:Clone()
	part1.BrickColor = BrickColor.new("Bright green")
	local part2 = game.Workspace.Wpos:Clone()
	part2.BrickColor = BrickColor.new("Bright red")
	part1.Parent = workspace 
	part2.Parent = workspace
	part1.Position = prevCF.Position
	part2.Position = postCF.Position
	
	return prevCF:Lerp(postCF, interpPercentage)
end
function ClosestPt2Ray (p, a, normal)
	local ap = p - a
	local d = ap:Dot(normal)
	
	return a + d * normal
end

--[[local pt = ClosestPt2Ray(Vector3.new(15,5,3), Vector3.new(10,1,0), Vector3.new(0.70710678118,0,-0.70710678118))
local part = game.Workspace.Wpos:Clone()
part.Parent = game.Workspace
part.Position = Vector3.new(15,5,3)
local part1 = game.Workspace.Wpos:Clone()
part1.Parent = game.Workspace
part1.Position = pt
local part2 = game.Workspace.Wpos:Clone()
part2.Parent = game.Workspace
part2.Position = Vector3.new(10,1,0)
print(pt)--]]


remotes:WaitForChild("getping").OnServerInvoke = (function(player)
	return true
end)

local function damage(hit, hum, player)
	if hit.Name == "Head" then
		hum:TakeDamage(players[player.UserId].currentWeapon.settings.firing.headshot)
		remotes.hitsound:FireClient(player, true)
		player.PlayerGui.Cursor.HeadHitmarker.ImageTransparency = 0
		for i = 0.1, 1, 0.1 do
			player.PlayerGui.Cursor.HeadHitmarker.ImageTransparency = i
			wait()
		end
	else
		hum:TakeDamage(players[player.UserId].currentWeapon.settings.firing.damage)
		remotes.hitsound:FireClient(player, false)
		player.PlayerGui.Cursor.Hitmarker.ImageTransparency = 0
		for i = 0.1, 1, 0.1 do
			player.PlayerGui.Cursor.Hitmarker.ImageTransparency = i
			wait()
		end
	end
end

remotes:WaitForChild("ping").OnServerEvent:Connect(function(player, origin, direction, id, initialdirection, tab)
	local hum = tab[1].Parent:FindFirstChild("Humanoid")
	if not hum and tab[1].Name ~= "Handle" and tab[1].Parent.Name ~= "m4a4" then
		remotes.hit:FireAllClients(player, tab[2], tab[3], tab[4], direction.Unit)
	end
	
	if not hum then return end
	if hum.Health == 0 then return end
	local target = tab[1].Parent

	local endTime = math.floor(tick() * 1000 + 0.5) /1000
	data[endTime] = {}
	for i, player in pairs(playersTable) do
		data[endTime][player.UserId] = player.Character.HumanoidRootPart.CFrame
	end
	
	local sum = 0
	for i, v in pairs(pingData[player.UserId]) do
		sum = sum + v
	end
	local averageping = sum/#pingData[player.UserId]
	print(averageping)
	
	local ST = endTime - averageping/2

	local serverCF = Posinterp(ST, target)
	local part3 = game.Workspace.Wpos:Clone()
	part3.BrickColor = BrickColor.new("Cool yellow")
	part3.Parent = workspace
	part3.Position = serverCF.Position
	local clientCF = Posinterp(ST - averageping/2, target)
	local shadow = game.Workspace.R6:Clone()
	shadow.Humanoid:Destroy()
	for i ,v in pairs(shadow:GetChildren()) do
		v.Transparency = 0.5
		v.CanCollide = false
	end
	shadow.Parent = game.Workspace
	shadow:PivotTo(clientCF)
	
	local rayCastResult
	if averageping >= 0.020 then
		print("Shoot")
		print(parameters.FilterDescendantsInstances)
		rayCastResult = game.Workspace:Raycast(origin, initialdirection * 5000, parameters)
		
		if not rayCastResult then 
			for i, v in pairs(shadow:GetChildren()) do
				local closestPoint = ClosestPt2Ray(v.Position, origin, initialdirection)
				local part4 = game.Workspace.Wpos:Clone()
				part4.Size = Vector3.new(0.5,0.5,0.5)
				part4.Parent = game.Workspace
				part4.Position = closestPoint
				if (closestPoint - v.Position).Magnitude <= 2 then 
					damage(v, hum, player)
					return 
				end
			end
		end
		if rayCastResult.Instance.Parent == shadow or  rayCastResult.Instance.Parent == target then
			damage(rayCastResult.Instance, hum, player)
		end
	else
		print("shoot2")
		rayCastResult = game.Workspace:Raycast(origin, initialdirection * 5000, parameters)
		if not rayCastResult then 
			for i, v in pairs(target:GetChildren()) do
				print(v)
				if v.ClassName ~= "Part" or v.Name == "Handle" then continue end
				local closestPoint = ClosestPt2Ray(v.Position, origin, initialdirection)
				local part4 = game.Workspace.Wpos:Clone()
				part4.Parent = game.Workspace
				part4.Position = closestPoint
				if (closestPoint - v.Position).Magnitude <= 2 then 
					damage(v, hum, player)
					return 
				end
			end
		end
		print(rayCastResult.Instance)
		if rayCastResult.Instance.Parent == target then
			damage(rayCastResult.Instance, hum, player)
		end
	end
end)


function updatePositionData()
	wait(3)
	local count = 0
	local timeStep
	local oldestTimeStep
	local indexTable = {}
	while true do
		timeStep = math.floor(tick() * 1000 + 0.5) /1000
		data[timeStep] = {}
		for i, player in pairs(playersTable) do
			data[timeStep][player.UserId] = player.Character.HumanoidRootPart.CFrame
		end
		wait(0.1)
		for i, v in pairs(data) do
			table.insert(indexTable, i)
			count = count + 1
		end
		oldestTimeStep = math.min(unpack(indexTable))
		if count > 10 then
			data[oldestTimeStep] = nil
		end
		indexTable = {}
		count = 0
	end
end



remotes:WaitForChild("receiveping").OnServerEvent:Connect(function(player, ping)
	table.insert(pingData[player.UserId], ping)
	if #pingData[player.UserId] > 15 then
		table.remove(pingData[player.UserId], 1)
	end
end)


local uD = coroutine.create(updatePositionData)

updatePositionData()
