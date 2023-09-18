local RepS = game:GetService("ReplicatedStorage")
local RunS = game:GetService("RunService")
local fireHandler = require(RepS:WaitForChild("modules").fireHandler)
local remotes = RepS:WaitForChild("weaponRemotes")
local players = game:GetService("Players")

local parameters = RaycastParams.new()
parameters.FilterType = Enum.RaycastFilterType.Blacklist
parameters.FilterDescendantsInstances = {game.Workspace.bullets}

remotes:WaitForChild("fire").OnClientEvent:Connect(function(player, origin, direction, params)
	
	if player ~= players.LocalPlayer then
		local gun = player.gun.Value
		
		
		local sound = gun.receiver:WaitForChild("pewpew"):Clone()
		sound.Parent = gun.receiver
		sound:Play()

		game:GetService("Debris"):AddItem(sound,3)
		
		coroutine.wrap(function()		
          
			for i,v in pairs(gun.receiver.barrel:GetChildren()) do
				if v.Name == "flash" then
					v.Transparency = NumberSequence.new(v.transparency.Value)
				elseif v.Name == "smoke" then
					v:Emit(1)
				elseif v.Name == "lightFlash" then
					v.Enabled = true
				end
			end	

			wait()

			for i,v in pairs(gun.receiver.barrel:GetChildren()) do
				if v.Name == "flash" then
					v.Transparency = NumberSequence.new(1)
				elseif v.Name == "lightFlash" then
					v.Enabled = false
				end
			end		

		end)()	
		
		local connection
		local pause = false

		local velocity = params.firing.velocity * direction.LookVector
		local acceleration = Vector3.new(0,RepS.bulletGravity.Value,0)
		local position = origin
		local distance

		local bullet = RepS.bullet:Clone()
		bullet.Parent = game.Workspace.bullets
		bullet.Position = origin

		local prevpos = origin
		local newpos = origin

		connection = RunS.Heartbeat:Connect(function(deltaTime)

			prevpos = newpos
			velocity = velocity + (acceleration * deltaTime)
			position = position + (velocity * deltaTime)
			bullet.CFrame = CFrame.new(position)
			newpos = position
			direction = newpos - prevpos
			local rayCastResult = game.Workspace:Raycast(prevpos, direction, parameters)

			distance = (origin - position).Magnitude
			if distance >= params.firing.range then 
				pause = true
			end

			if pause or rayCastResult then 
				bullet:Destroy()
				connection:Disconnect()
			end
			--rayVisualizer(prevpos, direction, newpos)
		end)
	end
end)


local stainparams = RaycastParams.new()
stainparams.FilterType = Enum.RaycastFilterType.Blacklist
stainparams.FilterDescendantsInstances = {game.Workspace.bullets, game.Players}

remotes:WaitForChild("hit").OnClientEvent:Connect(function(player, pos, surfacenormal, material, bulletnormal)
	if player == players.LocalPlayer then return end
	print("replicated bullethole")
	fireHandler:hitEffect(pos, surfacenormal, material, bulletnormal)
end)
