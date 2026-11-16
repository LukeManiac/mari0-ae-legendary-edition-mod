icicle = class:new()

function icicle:init(x, y, t, respawn, r)
	--PHYSICS STUFF
	self.x = x-.5
	self.y = y-1
	self.cox = x
	self.coy = y
	self.speedy = 0
	self.speedx = 0
	self.width = 10/16
	self.height = 12/16
	self.static = true
	self.active = true
	self.category = 4
	self.gravity = 0
	self.falling = false
	self.killstuff = true
	self.playernear = false
	self.ignoreplatform = true
	
	self.emancipatecheck = true
	self.autodelete = true
	self.t = t or "small"
	
	--IMAGE STUFF
	self.drawable = true
	if self.t == "big" then
		self.width = 14/16
		self.height = 30/16
		self.r = r

		local v = convertr(r, {"num", "bool"})
		self.falls = v[2]
		self.fallingravity = (20/9)*v[1]
		self.maxyspeed = v[1]

		self.graphic = iciclebigimg
		if self.falls then
			self.quad = iciclebigquad[2]
		else
			self.quad = iciclebigquad[1]
		end
		self.offsetX = 7
		self.offsetY = 8
		self.quadcenterX = 8
		self.quadcenterY = 0

		self.mask = {	true, 
			false, false, false, false, true,
			false, true, false, true, false,
			false, false, true, false, false,
			true, true, false, false, false,
			false, true, true, false, false,
			true, false, true, true, true,
			false, true}
		self.trackplatform = true
	else
		self.graphic = icicleimage
		self.quad = iciclequad[spriteset][1]
		self.offsetX = 5
		self.offsetY = 1
		self.quadcenterX = 8
		self.quadcenterY = 8

		self.fallingravity = r or 10

		self.mask = {	true, 
		false, false, false, false, true,
		false, true, false, true, false,
		false, false, true, false, false,
		true, true, false, false, false,
		false, true, true, false, false,
		true, false, true, true, true,
		false, true}

		self.falls = true
	end
	self.x = self.x - self.width/2
	
	self.rotation = 0
	
	self.animationdirection = "right"
	
	self.falling = false
	self.falltimer = false
	self.shaking = false --shaking because a player is near
	self.shaketimer = 0
	self.fallwait = nil --seconds left before it falls
	self.dead = false
	self.shot = false

	self.doesrespawn = true
	self.respawn = respawn or false
	if self.respawn then
		self.drawable = false
		self.active = false
		self.respawntimer = 2
		self.autodelete = false
	end
	
	self.dontenterclearpipes = true
	self.pipespawnmax = 1
end

function icicle:update(dt)
	if self.respawn then
		self.respawntimer = self.respawntimer - dt
		if self.respawntimer < 0 and onscreen(self.x, self.y) then
			self:appear()
		else
			return false
		end
	end

	if self.falling then
		if self.falltimer then
			self.falltimer = self.falltimer - dt
			self.offsetX = 7+math.floor((self.falltimer*10)%2)
			if self.falltimer < 0 then
				playsound(iciclefallsound)
				self.speedy = 1
				self.static = false
				self.falltimer = false
				self.offsetX = 7
				self.trackable = false
			end
		end

		if self.maxyspeed then
			self.speedy = math.min(self.maxyspeed, self.speedy)
		end

		--here's the messy part; keep mario and a few items on it as it falls
		if not self.static then
			local x, y, y2 = self.cox, math.floor(self.y+17/16), math.floor(self.y+16/16)
			if (not inmap(x, y)) or (istile(x,y) and (not tilequads[map[x][y][1]].collision) and inmap(x, y2) and not tilequads[map[x][y2][1]].collision) then --stop players from falling through ground
				local checktable = {"player", "smallspring"}
				for i, v in pairs(checktable) do
					for j, w in pairs(objects[v]) do
						if not w.jumping and inrange(w.x, self.x-w.width, self.x+self.width) then
							if inrange(w.y, self.y - w.height - 0.1, self.y - w.height + 0.1) then
								local x1, y1 = math.ceil(w.x), math.ceil(self.y+1-.5)
								local x2, y2 = math.ceil(w.x+w.width), math.ceil(self.y+1-.5)
								local maxy, col = math.huge, false
								if (inmap(x1, y1) and tilequads[map[x1][y1][1]]:getproperty("collision", x1, y1) and not tilequads[map[x1][y1][1]]:getproperty("invisible", x1, y1)) then
									maxy = y1-1-w.height
								elseif (inmap(x2, y2) and tilequads[map[x2][y2][1]]:getproperty("collision", x2, y2) and not tilequads[map[x2][y2][1]]:getproperty("invisible", x2, y2)) then
									maxy = y2-1-w.height
								end
								w.y = math.min(maxy, self.y - w.height + self.speedy*dt)
								w.ice = true
							end
						end
					end
				end
			end
		end
	elseif self.fallwait then
		--stopped shaking, falls once the wait is over
		self.fallwait = self.fallwait - dt
		if self.fallwait <= 0 then
			self.fallwait = nil
			self:fall()
		end
	elseif self.falls then
		--shakes while a player below is within icicleshakedist, then stops for goombadeathtime and falls once one
		--is within iciclefalldist
		local shake, fall = false, false
		for i = 1, players do
			local v = objects["player"][i]
			if self:playerbelow(v, iciclefalldist) then
				fall = true
				break
			elseif self:playerbelow(v, icicleshakedist) then
				shake = true
			end
		end
		if fall then
			self:startfallwait()
		elseif shake then
			if not self.shaking then
				self.shaking = true
				self.shaketimer = 0
			end
			self.shaketimer = (self.shaketimer + icicleoffsetspeed*dt)%1
			self.rotation = math.sin(self.shaketimer*math.pi*2)*math.rad(icicleshakeangle)
		elseif self.shaking then
			self.shaking = false
			self.shaketimer = 0
			self.rotation = 0
		end
	end
	
	if self.dead then
		return true
	elseif self.shot then
		self.speedy = self.speedy + shotgravity*dt
		
		self.x = self.x+self.speedx*dt
		self.y = self.y+self.speedy*dt
		return false
	else
		return false
	end
end

--whether player v is below the icicle, within dist tiles of it sideways (and no more than a screen further down)
function icicle:playerbelow(v, dist)
	return inrange(v.x+v.width/2, self.x+self.width/2-dist, self.x+self.width/2+dist) and v.y > self.y and math.abs(v.y-(self.y+self.height)) < height
end

function icicle:shotted(dir) --fireball, star, turtle
	if self.respawn then
		return
	end
	self:explode()
end

--stops shaking and falls after goombadeathtime seconds
function icicle:startfallwait()
	if self.falling or self.fallwait or not self.falls then
		return false
	end
	self.shaking = false
	self.shaketimer = 0
	self.rotation = 0
	self.fallwait = goombadeathtime
end

function icicle:fall()
	if self.falling or not self.falls then
		return false
	end
	self.gravity = self.fallingravity
	self.falling = true
	self.fallwait = nil
	if self.shaking then
		self.shaking = false
		self.rotation = 0
	end
	if self.t == "big" then
		--it already waited (see startfallwait), so it drops straight away
		playsound(iciclefallsound)
		self.speedy = 1
		self.trackable = false
	end
	self.static = false
end

function icicle:appear()
	self.drawable = true
	self.active = true
	self.respawn = false
	self.autodelete = true
	self.trackspeed = nil

	makepoof(self.x+self.width/2, self.y+.5, "makerpoof")
	makepoof(self.x+self.width/2, self.y+1.5, "makerpoof")
end

function icicle:leftcollide(a, b)
	if self:globalcollide(a, b) then
		return false
	end
	return false
end

function icicle:rightcollide(a, b)
	if self:globalcollide(a, b) then
		return false
	end
	
	return false
end

function icicle:ceilcollide(a, b)
	if self:globalcollide(a, b) then
		return false
	end

	if self.t == "big" and a == "player" then
		self:startfallwait()
	end
end

function icicle:globalcollide(a, b)
	if a == "player" and (b.invincible and not b.starred) then
		return true
	end
	if a == "fireball" then
		self:explode()
		return true
	end
	
	if self.falling then
		if fireballkill[a] and not b.resistsenemykill then
			b:shotted("left")
			if self.t == "big" and (not (b.hp)) then
				return true
			end
		end
	end
end

function icicle:floorcollide(a, b)
	if self:globalcollide(a, b) then
		return false
	end

	if a == "tile" then
		hitblock(b.cox, b.coy, {size=2})
	end

	self:explode()
end

function icicle:passivecollide(a, b)
	return false
end

function icicle:explode()
	if self.dead then
		return false --idk
	end
	if self.t == "big" then
		self.dead = true
		self.active = false
		self.drawable = false
		
		table.insert(blockdebristable, blockdebris:new(self.x+.5, self.y+2, 2, -14, iciclebigimg, randomitem(icicledebrisquad), "noframes"))
		table.insert(blockdebristable, blockdebris:new(self.x+.5, self.y+2, -2, -14, iciclebigimg, randomitem(icicledebrisquad), "noframes"))
		table.insert(blockdebristable, blockdebris:new(self.x+.5, self.y+2, 2, -7, iciclebigimg, randomitem(icicledebrisquad), "noframes"))
		table.insert(blockdebristable, blockdebris:new(self.x+.5, self.y+2, -2, -7, iciclebigimg, randomitem(icicledebrisquad), "noframes"))
		playsound(iciclesound)

		--respawn
		if self.doesrespawn then
			local obj = icicle:new(self.cox, self.coy, "big", true, self.r)
			if self.trackicicle then
				obj.trackable = true
				obj.trackspeed = 0
				local succ = trackobject(self.cox, self.coy, obj, "icicle")
			end
			table.insert(objects["icicle"], obj)
		end
	else
		self.dead = true
		self.active = false
		self.quad = iciclequad[spriteset][2]
		playsound(iciclesound)
	end
end

function icicle:autodeleted()
	if self.respawn then
		return
	end
	--respawn
	if self.t == "big" then
		if self.doesrespawn then
			local obj = icicle:new(self.cox, self.coy, "big", true, self.r)
			if self.trackicicle then
				obj.trackable = true
				obj.trackspeed = 0
				local succ = trackobject(self.cox, self.coy, obj, "icicle")
			end
			table.insert(objects["icicle"], obj)
		end
	end
end

function icicle:emancipate(a)
	table.insert(emancipateanimations, emancipateanimation:new(self.x, self.y, self.width, self.height, self.graphic, self.quad, self.speedx, self.speedy, self.rotation, self.offsetX, self.offsetY, self.quadcenterX, self.quadcenterY))
	self.dead = true
	self.active = false
end

function icicle:dotrack(track)
	if track then
		--self.respawn = false
		self.trackicicle = true
	end
end

function icicle:dospawnanimation(a)
	self.doesrespawn = false
end