-- This is game.replicatedstorage.fps 

local handler = {}
local fpsMT = {__index = handler}	

local replicatedStorage = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local spring = require(replicatedStorage.modules.spring)
local fireHandler = require(replicatedStorage.modules.fireHandler)
local runEvent = replicatedStorage:WaitForChild("weaponRemotes").run
local reloadEvent = replicatedStorage:WaitForChild("weaponRemotes").reload
local player = game:GetService("Players").LocalPlayer

local function getBobbing(addition,speed,modifier)
	return math.sin(tick()*addition*speed)*modifier
end

local function lerpNumber(a, b, t)
	return a + (b - a) * t
end

local RunService = game:GetService("RunService")
local function Wait(seconds) 
	local Heartbeat = RunService.Heartbeat
	local StartTime = os.clock()
	repeat Heartbeat:Wait() until os.clock() - StartTime >= seconds or os.clock() - StartTime + 0.008 >= seconds
end

function handler.new(weapons)
	local self = {}
	
	self.loadedAnimations = {}
	
	self.lerpValues = {}
	self.lerpValues.aim = Instance.new("NumberValue")
	self.lerpValues.equip = Instance.new("NumberValue") self.lerpValues.equip.Value = 1
	
	self.springs = {}
	self.springs.walkCycle = spring.create();
	self.springs.sway = spring.create()
	self.springs.fire = spring.create()
	
	self.shotCount = {}
	self.canFire = true
	self.tocrouch = false
	return setmetatable(self,fpsMT)
end

function handler:equip(wepName)

	-- if the weapon is disabled, or equipped, remove it instead.
	if self.disabled then return end
	--if self.equipped then self:remove() end
	
	-- get weapon from storage
	local weapon = replicatedStorage.weapons:FindFirstChild(wepName)
	if not weapon then return end -- if the weapon exists, clone it, else, stop
	weapon = weapon:Clone()

	--Make a viewmodel
	self.viewmodel = replicatedStorage.viewmodel:Clone()
	for i,v in pairs(weapon:GetChildren()) do
		v.Parent = self.viewmodel
		if v:IsA("BasePart") then
			v.CanCollide = false
			v.CastShadow = false
		end
	end		

	self.camera = workspace.CurrentCamera
	self.character = player.Character

	-- Throw the viewmodel under the map. It will go back to the camera the next render frame once we get to moving it.
	self.viewmodel.rootPart.CFrame = CFrame.new(0,-100,0)
	-- We're making the gun bound to the viewmodel's rootpart, and making the arms move along with the viewmodel using hierarchy.
	self.viewmodel.rootPart.weapon.Part1 = self.viewmodel.weaponRootPart
	self.viewmodel.left.leftHand.Part0 = self.viewmodel.weaponRootPart
	self.viewmodel.right.rightHand.Part0 = self.viewmodel.weaponRootPart
	self.viewmodel.Parent = game.Workspace.CurrentCamera

	--load weapon_settings
	self.settings = require(self.viewmodel.settings)
	--load animation from settings
	self.loadedAnimations.fire = self.viewmodel.AnimationController:LoadAnimation(self.settings.animations.viewmodel.fire)
	self.loadedAnimations.idle = self.viewmodel.AnimationController:LoadAnimation(self.settings.animations.viewmodel.idle)
	self.loadedAnimations.sprint = self.viewmodel.AnimationController:LoadAnimation(self.settings.animations.viewmodel.sprint)
	self.loadedAnimations.reload = self.viewmodel.AnimationController:LoadAnimation(self.settings.animations.viewmodel.reload)
	self.loadedAnimations.idle:Play(0) --no lerp time from default pos to prevent stupid looking arms for no longer than 0 frames	
	
	local tweeningInformation = TweenInfo.new(0.6, Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
	local properties = { Value = 0 }
	TS:Create(self.lerpValues.equip,tweeningInformation,properties):Play()	
	
	--separate thread
	local co = coroutine.wrap(function()
		local pass = game.ReplicatedStorage.weaponRemotes.equip:InvokeServer(wepName)
		if not pass then print("god") self:remove() end
	end)
	co()
	
	if not self.shotCount[wepName] then
		self.shotCount[wepName] = 0
	end
	self.curWeapon = wepName
	self.equipped = true
end

function handler:sprint(run)
	if self.disabled then return end
	if not self.equipped then return end
	
	if self.reloading then
		self.reloadCancelled = true
		self.loadedAnimations.reload:Stop()
		for i, v in pairs(self.viewmodel.receiver:GetChildren()) do
			if v.Name == "clonedreloadsound" then
				v:Destroy()
				return
			end
		end
		self.reloading = false
	end
	if self.tocrouch then
		self.tocrouch = false
		player.Character.Humanoid.CameraOffset = Vector3.new(0,0,0)
	end
	local armed = self.equipped
	if self.aiming and run then
		local tweeningInformation = TweenInfo.new(0.5, Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
		local properties = { Value = 0 }
		TS:Create(self.lerpValues.aim,tweeningInformation,properties):Play()	
	end
	
	runEvent:FireServer(run, armed)
	if run then 
		self.sprinting = true
		self.loadedAnimations.sprint:Play()
	else
		self.sprinting = false
		self.loadedAnimations.sprint:Stop()
	end
end
function handler:crouch()
	if self.disabled then return end
	if not self.equipped then return end
	
	replicatedStorage:WaitForChild("weaponRemotes").crouch:FireServer()
	if self.tocrouch == false then
		self.tocrouch = true
		player.Character.Humanoid.CameraOffset = Vector3.new(0,-0.7,0)
	else
		self.tocrouch = false
		player.Character.Humanoid.CameraOffset = Vector3.new(0,0,0)
	end
end
function handler:reload()
	if self.disabled then return end
	if not self.equipped then return end
	
	if self.reloading then return end
	if self.sprinting then return end
	if self.shotCount[self.curWeapon] == 0 then return end
	
	self.reloading = true
	reloadEvent:FireServer()
	if self.aiming then
		local tweeningInformation = TweenInfo.new(0.5, Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
		local properties = { Value = 0 }
		TS:Create(self.lerpValues.aim,tweeningInformation,properties):Play()	
	end
	
	self.loadedAnimations.reload:Play()
	
	event = self.loadedAnimations.reload.Stopped:Connect(function()
		event:Disconnect()
		self.reloading = false
		if self.reloadCancelled then self.reloadCancelled = false return end
		self.shotCount[self.curWeapon] = 0
	end)
	
	
	wait(0.1)
	local sound = self.viewmodel.receiver:WaitForChild("reload"):Clone()
	sound.Name = "clonedreloadsound"
	sound.Parent = self.viewmodel.receiver
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 1.6)
end

function handler:remove()
	self.disabled = true
	print("unequip function was ran")
	if self.reloading then
		self.reloadCancelled = true
		self.loadedAnimations.reload:Stop()
		for i, v in pairs(self.viewmodel.receiver:GetChildren()) do
			if v.Name == "clonedreloadsound" then
				v:Destroy()
				return
			end
		end
		self.reloading = false
	end
	--[[if self.tocrouch then
		self.tocrouch = false
		player.Character.Humanoid.CameraOffset = Vector3.new(0,0,0)
	end]]--
	
	local tweeningInformation = TweenInfo.new(0.6, Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
	local properties = { Value = 1 }
	TS:Create(self.lerpValues.equip,tweeningInformation,properties):Play()	
	
	local co = coroutine.wrap(function()
		game.ReplicatedStorage.weaponRemotes.unequip:InvokeServer()
	end)
	co()
	
	wait(0.6) --wait until the tween finishes so the gun lowers itself smoothly
	if self.viewmodel then
		self.viewmodel:Destroy()
		self.viewmodel = nil
	end
	self.disabled = false
	self.equipped = false
	self.curWeapon = nil
end

function handler:aim(toaim)
  
	if self.reloading then print("bruh") return end
	if self.disabled then return end
	if not self.equipped then return end
	self.aiming = toaim
	replicatedStorage.weaponRemotes.aim:FireServer(toaim)

	if toaim then
		if self.loadedAnimations.sprint.IsPlaying then
			self.sprinting = false
			self.loadedAnimations.sprint:Stop()
		end
	  
		local tweeningInformation = TweenInfo.new(1, Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
		local properties = { Value = 1 }
		TS:Create(self.lerpValues.aim,tweeningInformation,properties):Play()			
	else
		local tweeningInformation = TweenInfo.new(0.5, Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
		local properties = { Value = 0 }
		TS:Create(self.lerpValues.aim,tweeningInformation,properties):Play()			
	end
end

function handler:fire(tofire)
	-- wall of requirements
	if self.reloading then return end
	if self.disabled then return end
	if not self.equipped then return end
	if self.firing and tofire then return end 
	if not self.canFire and tofire then return end

	-- this makes the loop stop running when set to false
	self.firing = tofire
	if not tofire then return end

	-- while lmb held down do
	local function fire()

		-- It's better to replicate the change to other clients and play it there with the same code as here instead of using SoundService.RespectFilteringEnabled = false
		local sound = self.viewmodel.receiver:WaitForChild("pewpew"):Clone()
		sound.Parent = self.viewmodel.receiver
		sound:Play()

		game:GetService("Debris"):AddItem(sound,3)
		self.loadedAnimations.fire:Play()

		coroutine.wrap(function()		
			-- flash flashes inside the barrel, and smoke smokes for a short time

			for i,v in pairs(self.viewmodel.receiver.barrel:GetChildren()) do
				if v.Name == "flash" then
					v.Enabled = true
				elseif v.Name == "smoke" then
					v:Emit(1)
				elseif v.Name == "lightFlash" then
					v.Enabled = true
				end
			end	

			wait()

			for i,v in pairs(self.viewmodel.receiver.barrel:GetChildren()) do
				if v.Name == "flash" then
					v.Enabled = false
				elseif v.Name == "lightFlash" then
					v.Enabled = false
					
				end
			end		

		end)()		
		
		local recoilOffset = Vector3.new(3/100,math.random(-1,1)/100,math.random(-7,7)/100)
		if self.tocrouch then
			recoilOffset = recoilOffset/2
		end
		if self.aiming then
			recoilOffset = recoilOffset/1.4
		end
		
		self.springs.fire:shove(recoilOffset)
		local co = coroutine.wrap(function()
			Wait(0.15)
			self.springs.fire:shove(-recoilOffset)
		end)
		co()

		local origin = self.viewmodel.receiver.barrel.WorldPosition
		local direction = self.viewmodel.receiver.barrel.WorldCFrame

		fireHandler:fire(origin, direction, self.settings)
		self.shotCount[self.curWeapon] = self.shotCount[self.curWeapon] + 1
		if self.settings.firing.rpm ~= "NA" then
			Wait(60/self.settings.firing.rpm)
		end
	end

	repeat
		self.canFire = false
		if self.sprinting then self.canFire = true return end
		if self.reloading then self.canFire = true return end
		if self.shotCount[self.curWeapon] >= self.settings.firing.magCapacity then self.canFire = true return end
		fire()
		self.canFire = true
		if self.settings.firing.rpm == "NA" then return end
	until not self.firing or self.disabled
end

function handler:update(deltaTime)
	if self.viewmodel then
		
		-- get velocity for walkCycle
		local velocity = self.character.HumanoidRootPart.Velocity
		if self.character.Humanoid.MoveDirection.Magnitude == 0 then
			if self.loadedAnimations.sprint.IsPlaying then
				self.loadedAnimations.sprint:Stop()
				self.sprinting = false
			end
		end
		
		-- self.viewmodel.offsets.idle.Value = CFrame.new(0.7,-1.2,-0.9) * CFrame.Angles(0.005,-math.pi / 2 - 0.005,0)
		-- here, aim overwrites idle.
		local idleOffset = self.viewmodel.offsets.idle.Value
		local aimOffset = idleOffset:lerp(self.viewmodel.offsets.aim.Value,self.lerpValues.aim.Value)
		local equipOffset = aimOffset:lerp(self.viewmodel.offsets.equip.Value,self.lerpValues.equip.Value)
		
		local finalOffset = equipOffset
		-- transforms player mouse displacement into Vector3, then adds it to self.springs.sway's velocity and changes it
		local mouseDelta = game:GetService("UserInputService"):GetMouseDelta()
		if self.aiming then mouseDelta = mouseDelta * 0.1 end
		self.springs.sway:shove(Vector3.new(mouseDelta.x / 200,mouseDelta.y / 200)) --not sure if this needs deltaTime filtering

		-- speed can be dependent on a value changed when you're running, or standing still, or aiming, etc.
		-- this makes the bobble faster.
		local speed = 1
		if self.sprinting then speed = 0 end
		-- modifier can be dependent on a value changed when you're aiming, or standing still, etc.
		local modifier = 0.1
		if self.aiming then modifier = modifier * 0.3 end
		if self.tocrouch then modifier = modifier * 0.5 speed = speed * 0.7 end
		
		local movementSway = Vector3.new(getBobbing(10,speed,modifier),getBobbing(5,speed,modifier),getBobbing(5,speed,modifier))
		self.springs.walkCycle:shove((movementSway / 25) * deltaTime * 60 * velocity.Magnitude)
		
		local sway = self.springs.sway:update(deltaTime)
		local walkCycle = self.springs.walkCycle:update(deltaTime)
		local recoil = self.springs.fire:update(deltaTime)

		self.viewmodel.rootPart.CFrame = self.camera.CFrame:ToWorldSpace(finalOffset)
		----self.viewmodel.receiver.Fireorigin.CFrame = CFrame.lookAt(self.viewmodel.receiver.Fireorigin.Position, position) * CFrame.Angles(0, math.pi, 0)
		----local offset = self.camera.CFrame:ToObjectSpace(self.viewmodel.rootPart.CFrame)
		----print(offset)
		self.viewmodel.rootPart.CFrame = self.viewmodel.rootPart.CFrame:ToWorldSpace(CFrame.new(walkCycle.x / 2,walkCycle.y / 2,0))

		-- Rotate our rootpart based on sway
		self.viewmodel.rootPart.CFrame = self.viewmodel.rootPart.CFrame * CFrame.Angles(0,-sway.x,sway.y)
		self.viewmodel.rootPart.CFrame = self.viewmodel.rootPart.CFrame * CFrame.Angles(0,walkCycle.y,walkCycle.x)
  
		self.camera.CFrame = self.camera.CFrame * CFrame.Angles(recoil.x,recoil.y,recoil.z)
	end
end

return handler
