-- Constants

local ITERATIONS	= 8

-- Module

local SPRING	= {}

-- Functions 

function SPRING.create(self, mass, force, damping, speed)

	local spring	= {
		Target		= Vector3.new();
		Position	= Vector3.new();
		Velocity	= Vector3.new();
		
		Mass		= mass or 5;
		Force		= force or 50;
		Damping		= damping or 10;
		Speed		= speed  or 4;
	}
	
	function spring.shove(self, force)
		local x, y, z	= force.X, force.Y, force.Z
		if x ~= x or x == math.huge or x == -math.huge then
			x = 0
		end
		if y ~= y or y == math.huge or y == -math.huge then
			y = 0
		end
		if z ~= z or z == math.huge or z == -math.huge then
			z = 0
		end
		self.Velocity	= self.Velocity + Vector3.new(x, y, z)
	end
	
	function spring.update(self, dt)
		if dt >= 0.02 then dt = 0.02 end
		ITERATIONS = math.floor(ITERATIONS / (0.016/dt) + 0.5)
		--print(ITERATIONS)
		local scaledDeltaTime = dt * self.Speed / ITERATIONS
		
		for i = 1, ITERATIONS do
			local iterationForce = self.Target - self.Position
			local acceleration	= (iterationForce * self.Force) / self.Mass
			
			acceleration = acceleration - self.Velocity * self.Damping
			self.Velocity = self.Velocity + acceleration * scaledDeltaTime
			self.Position = self.Position + self.Velocity * scaledDeltaTime
		end
		
		ITERATIONS = 8
		return self.Position
	end
	
	return spring
end

return SPRING
