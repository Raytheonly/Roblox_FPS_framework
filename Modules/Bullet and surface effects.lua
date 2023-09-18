local fireHandler = {}

local RunS = game:GetService("RunService")
local RepS = game:GetService("ReplicatedStorage")
local eP = RepS:WaitForChild("environmentParticles")
local Debris = game:GetService("Debris")
local HttpS = game:GetService("HttpService")
local remotes = RepS:WaitForChild("weaponRemotes")
local cR = RepS.weaponRemotes.clientResult
local player = game:GetService("Players").LocalPlayer
local parameters = RaycastParams.new()
parameters.FilterType = Enum.RaycastFilterType.Blacklist

remotes:WaitForChild("bindableEvent").Event:Connect(function(transferTable)
	table.insert(transferTable, game.Workspace.CurrentCamera)
	table.insert(transferTable, game.Workspace.bullets)
	table.insert(transferTable, player)
	parameters.FilterDescendantsInstances = {table.unpack(transferTable)}
end)

function fireHandler:rayVisualizer(prevpos, direction, newpos)
	local ray = Instance.new("Part")
	ray.Parent = game.Workspace.bullets
	ray.Anchored = true
	ray.Size = Vector3.new(1,1,direction.Magnitude)
	ray.CFrame = CFrame.new(prevpos + direction/2, newpos)
end

local stainparams = RaycastParams.new()
stainparams.FilterType = Enum.RaycastFilterType.Blacklist
stainparams.FilterDescendantsInstances = {game.Workspace.bullets, game.Players}

function sparkEmitter(bulletHole, direction)
	local iterations = math.random(1, 7)
	for i = iterations, 0, -1 do
		local spark = eP.spark:Clone()
		spark.Parent = bulletHole
		spark.Position = bulletHole.Position
		spark.Trail.MaxLength = math.random(1, 3)
		spark.AssemblyLinearVelocity = direction * math.random(50,150) + Vector3.new(math.random(-40,40),math.random(-40,40),math.random(-40,40))
		
		raycastevent = RunS.Heartbeat:Connect(function()
			if not spark then raycastevent:Disconnect() return end
			local result = game.Workspace:Raycast(spark.Position, spark.AssemblyLinearVelocity.Unit * 2, stainparams)
			if result then
				raycastevent:Disconnect()
				local stain = eP.Stain:Clone()
				stain.Parent = game.Workspace.bullets
				stain.CFrame = CFrame.new(result.Position, result.Position + result.Normal)
				local lifespan = 1 + math.random()
				Debris:AddItem(stain, lifespan)
				stain.Size = stain.Size * math.random(6,9)/10
				for i = 1, 10, 1 do
					stain.Size = stain.Size - Vector3.new(math.random(5, 20)/100, math.random(5, 20)/100, 0)
					wait()
				end
			end
		end)
		
		local lifespan = math.random(5, 20)/100
		Debris:AddItem(spark, lifespan)
		local chance = math.random(1, 3)
		if chance ~= 1 then continue end
		local co = coroutine.wrap(function()
			wait()
			spark.AssemblyLinearVelocity = spark.AssemblyLinearVelocity + Vector3.new(0,math.random(-30,-10),0)
		end)
		co()
	end
end

function fireHandler:hitEffect(pos, surfacenormal, material, bulletnormal)
	local bulletHole = eP.bulletHole:Clone()
	bulletHole.Parent = game.Workspace.bullets
	bulletHole.CFrame = CFrame.new(pos, pos + surfacenormal)
	Debris:AddItem(bulletHole, 10)
	
	local co1 = coroutine.wrap(function()
		if material == Enum.Material.Grass or material == Enum.Material.Sand or material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then return end
		local chance = math.random(1, 5)
		if chance == 1 then return end
		local reflectednormal = bulletnormal - (2 * bulletnormal:Dot(surfacenormal) * surfacenormal)
		sparkEmitter(bulletHole, reflectednormal)
	end)
	co1()
	local co2 = coroutine.wrap(function()
		if material == Enum.Material.Grass then bulletHole.Smoke.Color = ColorSequence.new(Color3.fromRGB(112,84,62)) end 
		if material == Enum.Material.Sand then bulletHole.Smoke.Color = ColorSequence.new(Color3.fromRGB(255, 232, 190)) bulletHole.Smoke.LightEmission = 0.8 end
		if material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then bulletHole.Smoke.Color = ColorSequence.new(Color3.fromRGB(202, 164, 114)) bulletHole.Smoke.LightEmission = 0.75 end 
		bulletHole.Smoke.Enabled = true
		wait(0.2)
		bulletHole.Smoke.Enabled = false
	end)
	co2()
	
	if material == Enum.Material.Concrete then
		bulletHole.concrete1:Play()
		bulletHole.Concrete.Enabled = true
		wait()
		bulletHole.Concrete.Enabled = false
		
	elseif material == Enum.Material.Metal then
		local rng = math.random(1,3)
		local name = "metal"..rng
		bulletHole[name]:Play()
		
	elseif material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
		bulletHole.wood1:Play()
		
	elseif material == Enum.Material.Grass or material == Enum.Material.Sand or material == Enum.Material.Plastic then
		bulletHole.concrete1:Play()
		bulletHole.Dirt.Enabled = true
		wait(0.1)
		bulletHole.Dirt.Enabled = false
	end
end


function fireHandler:fire(origin, direction, properties)
	
	print(parameters.FilterDescendantsInstances)
	
	local connection
	local pause = false
	local initialdirection = direction.LookVector
	
	local velocity = properties.firing.velocity * initialdirection
	local acceleration = Vector3.new(0,RepS.bulletGravity.Value,0)
	local position = origin
	local distance
	
	local bullet = RepS.bullet:Clone()
	--bullet.Trail.Transparency = NumberSequence.new(1)
	bullet.Parent = game.Workspace.bullets
	bullet.Position = origin
	
	local id = HttpS:GenerateGUID(false)
	local camCF = game.Workspace.CurrentCamera.CFrame
	
	remotes.fire:FireServer(origin, direction, id, camCF)
	
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
		if distance >= properties.firing.range then 
			pause = true
		end

		if pause or rayCastResult then 
			bullet:Destroy()
			connection:Disconnect()
			if not rayCastResult then return end
			if rayCastResult.Instance then
				if not rayCastResult.Instance.Parent:FindFirstChild("Humanoid") and rayCastResult.Instance.Name ~= "Handle" and rayCastResult.Instance.Parent.Name ~= "m4a4" then
					fireHandler:hitEffect(rayCastResult.Position, rayCastResult.Normal, rayCastResult.Material, direction.Unit)
				end
				
				local sendTable = {rayCastResult.Instance, rayCastResult.Position, rayCastResult.Normal, rayCastResult.Material}
				remotes.ping:FireServer(origin, direction, id, initialdirection, sendTable)
				
				--print("client hit", rayCastResult.Instance, "at", rayCastResult.Position)
				--cR:FireServer(id, rayCastResult.Instance)
			end
		end
		--fireHandler:rayVisualizer(prevpos, direction, newpos)
	end)
end

return fireHandler

