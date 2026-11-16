chainchomp = class:new()

function chainchomp:init(x, y)
	--PHYSICS STUFF
	self.x = x-14/16
	self.y = y-12/16
	self.cox = x
	self.coy = y
	self.speedy = 0
	self.speedx = -chainchompspeed
	self.width = 12/16
	self.height = 12/16
	self.static = false
	self.active = true
	self.category = 4
	
	self.mask = {	true, 
					false, false, false, false, true,
					false, true, false, true, false,
					false, false, true, false, false,
					true, true, false, false, false,
					false, true, true, false, false,
					true, false, true, true, true,
					false, true}
	
	self.autodelete = true
	self.freezable = false
	self.frozen = false
	
	--IMAGE STUFF
	self.drawable = true
	self.graphic = chainchompimg
	self.quad = chainchompquad[spriteset][1]
	self.offsetX = 6
	self.offsetY = 3
	self.quadcenterX = 8
	self.quadcenterY = 8
	
	self.rotation = 0 --for portals
	
	self.direction = "left"
	self.animationtimer = 0
	self.falling = false
	self.freezetimer = 0
	
	self.dead = false
	
	self.shot = false
	
	self.cfloor = self.coy
	
	self.range = 3
	self.attack = false
	self.attacktimer = 0
	self.targetplayer = false
	self.targetangle = false
	self.targetx = false
	self.targety = false
	self.chargespeedx = false
	self.chargespeedy = false
	self.returnn = false
	
	self.randomattackadd = math.random(0, 200)/100
	
	self.free = false
	self.freecount = 0 --times the chain has stopped it lunging
	self.blocked = false --the chain stopped this lunge (counted once per lunge)
	self.freelinks = false --links of the broken chain that trail behind it once it's free
	self.freebounce = 5

	self.trackable = false
	self.nospawnanimation = true
end

--the rotation that points the chain chomp's mouth at angle (the sprite faces left, and is flipped when facing right)
function chainchomp:aimrotation(angle)
	if self.animationdirection ~= "left" then
		angle = angle - math.pi
	end
	return (angle + math.pi)%(math.pi*2) - math.pi
end

function chainchomp:update(dt)
	if self.frozen then
		return
	end
	
	--waiting to attack or charging: turn smoothly to face the player (or where it's charging)
	local aimangle
	if not self.shot and not self.free then
		if self.attack and not self.returnn then
			aimangle = self.targetangle
		elseif (not self.attack) and self.targetplayer and self.attacktimer > chainchompattackwait+self.randomattackadd then
			local p = self.targetplayer
			aimangle = math.atan2((p.y+p.height/2)-(self.y+self.height/2), (p.x+p.width/2)-(self.x+self.width/2))
		end
	end
	
	if aimangle then
		local target = self:aimrotation(aimangle)
		local diff = (target - self.rotation + math.pi)%(math.pi*2) - math.pi
		self.rotation = self.rotation + diff*math.min(1, chainchomprotatespeed*dt)
	else
		--rotate back to 0 (portals)
		self.rotation = math.fmod(self.rotation, math.pi*2)
		if self.rotation > 0 then
			self.rotation = self.rotation - portalrotationalignmentspeed*dt
			if self.rotation < 0 then
				self.rotation = 0
			end
		elseif self.rotation < 0 then
			self.rotation = self.rotation + portalrotationalignmentspeed*dt
			if self.rotation > 0 then
				self.rotation = 0
			end
		end
	end
	
	if self.shot then
		self.speedy = self.speedy + shotgravity*dt
		
		self.x = self.x+self.speedx*dt
		self.y = self.y+self.speedy*dt
		
		return false
	else
		if self.attack then
			--charge at player, chomping twice as fast
			self.animationtimer = self.animationtimer + dt
			while self.animationtimer > goombaanimationspeed/2.5 do
				if self.quad == chainchompquad[spriteset][1] then
					self.quad = chainchompquad[spriteset][2]
				else
					self.quad = chainchompquad[spriteset][1]
				end
				self.animationtimer = self.animationtimer - goombaanimationspeed/2.5
			end
			
			self.mask[2] = true
			self.speedx = self.chargespeedx
			self.speedy = self.chargespeedy
			self.gravity = 0
			local freeze = false
			local returned = false
			if self.chargespeedx > 0 then
				if self.x > self.targetx then
					if self.returnn then
						returned = true
					else
						freeze = true
					end
				end
			else
				if self.x < self.targetx then
					if self.returnn then
						returned = true
					else
						freeze = true
					end
				end
			end
			if self.chargespeedy > 0 then
				if self.y > self.targety then
					if self.returnn then
						returned = true
					else
						freeze = true
					end
				end
			else
				if self.y < self.targety then
					if self.returnn then
						returned = true
					else
						freeze = true
					end
				end
			end
			if freeze and not self.returnn then
				self.x = self.targetx
				self.y = self.targety
				self.static = true
				if not self.blocked then
					--the chain stopped it: one more try at breaking free
					self.blocked = true
					self.freecount = self.freecount + 1
					if self.freecount >= chainchompfreecount then
						self:breakfree()
						return false
					end
				end
			end
			
			self.attack = self.attack - dt
			if self.attack < 0 and not self.returnn then
				self.static = false
				self.returnn = true
				self.targetx = self.cox-.5-self.width/2
				self.targety = self.coy-self.height
				local rx, ry = (self.targetx + -self.x), (self.targety + -self.y)
				local d = math.sqrt(rx*rx+ry*ry)
				self.chargespeedx, self.chargespeedy = (rx)/d*(chainchompattackspeed/2), (ry)/d*(chainchompattackspeed/2)
			end
			
			if self.returnn and returned then
				self.randomattackadd = math.random(0, 200)/100
				self.x = self.targetx
				self.y = self.targety
				self.attack = false
				self.returnn = false
				self.gravity = nil
				self.attacktimer = 0
				self.targetplayer = false
				self.targetangle = false
				self.targetx = false
				self.targety = false
				self.static = false
				self.mask[2] = false
				self.chargespeedx = false
				self.chargespeedy = false
				if self.animationdirection == "left" then
					self.speedx = -chainchompspeed
				else
					self.speedx = chainchompspeed
				end
				self.speedy = 0
				if self.y > self.coy then
					self.y = self.coy-self.height
				end
			end
		elseif self.free then --break free
			if self.speedx > 0 then
				self.speedx = chainchompfreespeed
			else
				self.speedx = -chainchompfreespeed
			end
			self.animationtimer = self.animationtimer + dt
			while self.animationtimer > goombaanimationspeed/1.5 do
				if self.quad == chainchompquad[spriteset][1] then
					self.quad = chainchompquad[spriteset][2]
				else
					self.quad = chainchompquad[spriteset][1]
				end
				self.animationtimer = self.animationtimer - goombaanimationspeed/1.5
			end
			self:updatefreelinks(dt)
		else
			--slow down
			if self.speedx > 0 then
				if self.speedx > chainchompspeed then
					self.speedx = self.speedx - friction*dt*2
					if self.speedx < chainchompspeed then
						self.speedx = chainchompspeed
					end
				elseif self.speedx < chainchompspeed then
					self.speedx = self.speedx + friction*dt*2
					if self.speedx > chainchompspeed then
						self.speedx = chainchompspeed
					end
				end
			elseif self.speedx < 0 then
				if self.speedx < -chainchompspeed then
					self.speedx = self.speedx + friction*dt*2
					if self.speedx > -chainchompspeed then
						self.speedx = -chainchompspeed
					end
				elseif self.speedx > -chainchompspeed then
					self.speedx = self.speedx - friction*dt*2
					if self.speedx < -chainchompspeed then
						self.speedx = -chainchompspeed
					end
				end
			end
			
			--animation (keeps going while it waits to attack)
			self.animationtimer = self.animationtimer + dt
			while self.animationtimer > goombaanimationspeed do
				if self.quad == chainchompquad[spriteset][1] then
					self.quad = chainchompquad[spriteset][2]
				else
					self.quad = chainchompquad[spriteset][1]
				end
				self.animationtimer = self.animationtimer - goombaanimationspeed
			end
			
			--stay within range
			local x1, y1, x2, y2 = self.x+self.width/2, self.y+self.height/2, self.cox-.5, self.coy-.5
			local dist = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
			local angle = math.atan2(y2 - y1, x2 - x1)
			if (dist > chainchompfreedist or self.freecount >= chainchompfreecount) and not (self.attacktimer > chainchompattackwait+self.randomattackadd) then
				self:breakfree()
				return false
			end
			
			if dist > self.range and self.x > self.cox-.5 and self.speedx > 0 then
				self.speedx = -self.speedx
			elseif -dist < -self.range and self.x < self.cox-.5 and self.speedx < 0 then
				self.speedx = -self.speedx
			end
			
			--also don't fall off edges
			local x = math.floor(self.x + self.width/2+1)
			local y = math.floor(self.cfloor)
			if inmap(x, y) and tilequads[map[x][y][1]].collision == false and ((inmap(x+.5, y) and tilequads[map[math.ceil(x+.5)][y][1]].collision) or (inmap(x-.5, y) and tilequads[map[math.floor(x-.5)][y][1]].collision)) then
				if self.speedx < 0 then
					self.animationdirection = "left"
					self.x = x-self.width/2
				else
					self.animationdirection = "right"
					self.x = x-1-self.width/2
				end
				self.speedx = -self.speedx
			end
			
			--charge at player
			self.attacktimer = self.attacktimer + dt
			if self.attacktimer > chainchompattackstart+self.randomattackadd then
				self.gravity = 0
				self.attack = chainchompattacktime
				local x2, y2 = self.targetplayer.x+self.targetplayer.width/2, self.targetplayer.y+self.targetplayer.height/2
				self.targetangle = math.atan2(y2 - y1, x2 - x1)
				self.targetx = self.cox-.5+(math.cos(self.targetangle)*self.range)-self.width/2
				self.targety = self.coy-.5+(math.sin(self.targetangle)*self.range)-self.height/2
				local rx, ry = (self.targetx + -self.x), (self.targety + -self.y)
				local d = math.sqrt(rx*rx+ry*ry)
				self.chargespeedx, self.chargespeedy = (rx)/d*(chainchompattackspeed), (ry)/d*(chainchompattackspeed)
				self.blocked = false
			elseif self.attacktimer > chainchompattackwait+self.randomattackadd then
				if self.targetplayer then
					if self.targetplayer.x+self.targetplayer.width/2 < self.x+self.width/2 then
						self.animationdirection = "right"
					else
						self.animationdirection = "left"
					end
					self.speedx = 0
				else
					local closestplayer = false
					local closestdist = math.huge
					for i = 1, players do
						local p = objects["player"][i]
						local x2, y2 = p.x+p.width/2, p.y+p.height/2
						local dist = math.sqrt((x2 - x1)^2 + (y2 - y2)^2)
						if dist < chainchompattackrange and dist < closestdist then
							closestdist = dist
							closestplayer = i
						end
					end
					if closestplayer then
						self.targetplayer = objects["player"][closestplayer]
						if self.targetplayer.x+self.targetplayer.width/2 < self.x+self.width/2 then
							self.animationdirection = "right"
						else
							self.animationdirection = "left"
						end
						self.speedx = 0
					else
						self.attacktimer = 0
					end
				end
			end
			
			if self.speedx > 0 then
				self.animationdirection = "left"
			elseif self.speedx < 0 then
				self.animationdirection = "right"
			end
		end
		return false
	end
end

function chainchomp:draw()
	if self.free and not self.shot then
		--the broken chain trailing behind it
		if self.freelinks then
			love.graphics.setColor(255, 255, 255)
			local s = self.supersized or 1
			for i = #self.freelinks, 1, -1 do
				local l = self.freelinks[i]
				love.graphics.draw(chainchompimg, chainchompquad[spriteset][3],
					math.floor((l.x-s*.25-xscroll)*16*scale), math.floor((l.y-s*.25-yscroll-.5)*16*scale),
					0, s*scale, s*scale)
			end
		end
	end
	if not self.shot and not self.free then
		--draw the chain
		love.graphics.setColor(255, 255, 255)
		for i = 1, 4 do
			i = i - .5
			local drop = (2/16)*(2-math.abs(i-2))
			if self.attack and not self.returnn then
				drop = drop*((self.x/self.targetx)-1)
			end
			love.graphics.draw(chainchompimg, chainchompquad[spriteset][3],
				math.floor( (((((self.x+self.width/2-(self.supersized or 1)*.25)-(self.cox-(self.supersized or 1)*12/16))*(i/4)+self.cox-(self.supersized or 1)*12/16)-xscroll)*16)*scale ), 
				math.floor( (((((self.y+self.height/2-(self.supersized or 1)*.25)-(self.coy-(self.supersized or 1)*12/16))*(i/4)+self.coy-(self.supersized or 1)*12/16+drop)-yscroll-.5)*16)*scale ),
				0, (self.supersized or 1)*scale, (self.supersized or 1)*scale)
		end
	end
end

function chainchomp:shotted(dir)
	playsound(shotsound)
	self.shot = true
	self.speedy = -shotjumpforce
	self.direction = dir or "right"
	self.active = false
	self.gravity = shotgravity
	if self.direction == "left" then
		self.speedx = -shotspeedx
	else
		self.speedx = shotspeedx
	end
end

function chainchomp:freeze()
	self.frozen = true
end

function chainchomp:leftcollide(a, b)
	if self:globalcollide(a, b) then
		return false
	end
	
	if self.free then
		return false
	end
	
	if not self.attack then
		self.speedx = chainchompspeed
	end
	
	return false
end

function chainchomp:rightcollide(a, b)
	if self:globalcollide(a, b) then
		return false
	end
	
	if self.free then
		return false
	end
	
	if not self.attack then
		self.speedx = -chainchompspeed
	end
	
	return false
end

function chainchomp:ceilcollide(a, b)
	if self:globalcollide(a, b) then
		return false
	end
	
	if self.free then
		return false
	end
end

function chainchomp:globalcollide(a, b)
	if a == "fireball" or a == "player" then
		return true
	end
	
	if a == "tile" and b.cox == self.cox and b.coy == self.coy then
		return true
	end
end

function chainchomp:floorcollide(a, b)
	if self:globalcollide(a, b) then
		return false
	end
	
	if not self.attack and self.attacktimer < chainchompattackwait+self.randomattackadd then
		if self.free then
			if self.freebounce <= 0 then
				self.mask = {false}
				return false
			end
			if lowgravity then
				self.speedy = -10
			else
				self.speedy = -20
			end
			self.freebounce = self.freebounce - 1
		else
			if lowgravity then
				self.speedy = -5
			else
				self.speedy = -10
			end
			if a == "tile" then
				self.cfloor = b.coy
			end
		end
	end
end

function chainchomp:passivecollide(a, b)
	self:leftcollide(a, b)
	return false
end

function chainchomp:emancipate(a)
	self:shotted()
end

function chainchomp:laser()
	self:shotted()
end

function chainchomp:dospawnanimation(a)
	self.free = true
end

--the stake gives way: runs off with its chain trailing behind it, like in Super Mario Maker 2
function chainchomp:breakfree()
	--keeps going the way it lunged
	local dir = self.speedx
	if self.attack and self.chargespeedx then
		dir = self.chargespeedx
	end
	self.free = true
	self.attack = false
	self.returnn = false
	self.static = false
	self.gravity = nil
	self.mask[2] = false
	self.attacktimer = 0
	self.targetplayer = false
	self.targetangle = false
	self.targetx = false
	self.targety = false
	self.chargespeedx = false
	self.chargespeedy = false
	self.speedy = 0
	if dir and dir > 0 then
		self.speedx = chainchompfreespeed
		self.animationdirection = "left"
	else
		self.speedx = -chainchompfreespeed
		self.animationdirection = "right"
	end

	--the links start where the chain was drawn, from the chomp back to the stake
	local s = self.supersized or 1
	local cx, cy = self.x+self.width/2, self.y+self.height/2
	local sx, sy = self.cox-s*12/16+s*.25, self.coy-s*12/16+s*.25
	self.freelinks = {}
	for i = 1, 4 do
		local t = 1-(i-.5)/4
		table.insert(self.freelinks, {x = sx+(cx-sx)*t, y = sy+(cy-sy)*t, speedy = 0})
	end
end

--each link falls, rests on solid tiles, and is dragged along by the one in front of it (the first one by the chomp)
function chainchomp:updatefreelinks(dt)
	local cx, cy = self.x+self.width/2, self.y+self.height/2
	if not self.freelinks then
		self.freelinks = {}
		for i = 1, 4 do
			table.insert(self.freelinks, {x = cx, y = cy, speedy = 0})
		end
	end
	local linkdist = chainchompfreelinkdist*(self.supersized or 1)
	local px, py = cx, cy
	for i, l in ipairs(self.freelinks) do
		l.speedy = math.min(maxyspeed, l.speedy + yacceleration*dt)
		l.y = l.y + l.speedy*dt

		--drag along behind the link in front
		local dx, dy = l.x-px, l.y-py
		local d = math.sqrt(dx*dx+dy*dy)
		if d > linkdist then
			l.x = px + dx/d*linkdist
			l.y = py + dy/d*linkdist
			if l.y < py and l.speedy > 0 then
				l.speedy = 0
			end
		end

		--rest on solid tiles (only while the chomp hasn't fallen through the ground)
		if self.mask[1] ~= false then
			local tx, ty = math.floor(l.x)+1, math.floor(l.y+.25)+1
			if inmap(tx, ty) and tilequads[map[tx][ty][1]]:getproperty("collision", tx, ty) then
				l.y = ty-1-.25
				l.speedy = 0
			end
		end
		px, py = l.x, l.y
	end
end
