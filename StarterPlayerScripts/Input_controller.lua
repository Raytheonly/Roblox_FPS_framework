-- input controller

-- Import the client_actions_states module
local weaponHandler = require(game.ReplicatedStorage.modules.fps)

local UIS = game:GetService("UserInputService")
local RunS = game:GetService("RunService")
local RepS = game:GetService("ReplicatedStorage")
local SoundS = game:GetService("SoundService")
local remotes = RepS:WaitForChild("weaponRemotes")

local curWeapon = nil

local player = game:GetService("Players").LocalPlayer
local cursor = player:WaitForChild("PlayerGui"):WaitForChild("Cursor"):WaitForChild("Dot")

local weps, ammoData = game.ReplicatedStorage.weaponRemotes.new:InvokeServer()
local weapon = weaponHandler.new(weps)

weapon.ammoData = ammoData

-- clearing viewmodels we could have kept in the camera because of script errors and stuff
local viewmodels = workspace.Camera:GetChildren()
for i,v in pairs(viewmodels) do
	if v.Name == "viewmodel" then
		v:Destroy()
	end
end

local mouse = player:GetMouse()
local function update(dt)
	--local position = mouse.Hit.p
	weapon:update(dt)
end

----Equip


local currentWeapon = nil
local wantedWeapon = nil
local cooldown = false

UIS.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.One then
			wantedWeapon = weps[1]
		elseif input.KeyCode == Enum.KeyCode.Two then
			wantedWeapon = weps[2]
		elseif input.KeyCode == Enum.KeyCode.Three then
			wantedWeapon = weps[3]
		end

		if wantedWeapon then
			if currentWeapon == nil then
				weapon:equip(wantedWeapon)
				currentWeapon = wantedWeapon
				wantedWeapon = nil
			elseif currentWeapon ~= wantedWeapon and not cooldown then
				cooldown = true
				weapon:remove()
				weapon:equip(wantedWeapon)
				currentWeapon = wantedWeapon
				wantedWeapon = nil
				cooldown = false
			elseif currentWeapon == wantedWeapon and not cooldown then
				cooldown = true
				weapon:remove()
				currentWeapon = nil
				wantedWeapon = nil
				cooldown = false
			end
		end
	end
end)

UIS.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.LeftShift then
			weapon:sprint(true)
		end
		if input.KeyCode == Enum.KeyCode.LeftControl then
			weapon:crouch()
		end
		if input.KeyCode == Enum.KeyCode.R then
			weapon:reload()
		end
	end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		weapon:fire(true)
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		weapon:aim(true)
		if currentWeapon == nil then return end
		for i = 0.1, 1, 0.1 do
			cursor.ImageTransparency = i
			wait()
		end
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.LeftShift then
			weapon:sprint(false)
		end
	end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		weapon:fire(false)
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		weapon:aim(false)
		if currentWeapon == nil then return end
		for i = 0.9, 0, -0.1 do
			cursor.ImageTransparency = i
			wait()
		end
	end
end)


local hitsound = RepS.hitsounds.hit
local headshotsound = RepS.hitsounds.headshot
remotes.hitsound.OnClientEvent:Connect(function(headshot)
	if headshot then 
		SoundS:PlayLocalSound(headshotsound)
	else
		SoundS:PlayLocalSound(hitsound)
	end
end)

function getping()
	local ST = tick()
	local ping
	remotes.getping:InvokeServer()

	ping = math.floor((tick() - ST) * 1000 + 0.5) / 1000
	return ping
end

local co = coroutine.create(function()
	while true do
		local ping = getping()
		remotes.receiveping:FireServer(ping)
		wait(0.4)
	end
end)

coroutine.resume(co)

remotes:WaitForChild("rcparams").OnClientEvent:Connect(function(transferTable)
	remotes.bindableEvent:Fire(transferTable)
end)

-- marking the gun as unequippable
player.Character:WaitForChild("Humanoid").Died:Connect(function() weapon:remove() weapon.disabled = true end)
game:GetService("RunService").RenderStepped:Connect(update)
