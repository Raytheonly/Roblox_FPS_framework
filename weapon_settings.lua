
local root = script.Parent

local data = {
	animations = {
	
		viewmodel = {
			idle = root.animations.idle;
			fire = root.animations.fire;
			reload = root.animations.reload;
			sprint = root.animations.sprint;
		};
	
		player = {
			unarmedRun = root.serverAnimations.unarmedRun;
			armedRun = root.serverAnimations.armedRun;
			crouch = root.serverAnimations.crouch;
			hold = root.serverAnimations.hold;
			walk = root.serverAnimations.walk;
			aim = root.serverAnimations.aim;
			shoot = root.serverAnimations.shoot;
			aimshoot = root.serverAnimations.aimshoot;
			reload = root.serverAnimations.reload;
		};
	
	};
	
	firing = {
		class = "AR";
		damage = 20;
		headshot = 34;
		rpm = 700;
		magCapacity = 30;
		velocity = 1500;
		range = 5000;
	}
	
}

return data
