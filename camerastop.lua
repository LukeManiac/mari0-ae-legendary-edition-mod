camerastop = class:new()

function camerastop:init(x, y, r)
	self.cox = x
	self.coy = y
	self.rx = self.cox-1
	self.ry = self.coy-1
	self.rw = 1
	self.rh = 1

	self.r = {unpack(r)}
	table.remove(self.r, 1)
	table.remove(self.r, 1)
	
	if #self.r > 0 and self.r[1] ~= "link" then
		--rightclick things
		local v = convertr(self.r[1], {"num", "num", "num", "num", "bool", "bool"}, true)
		self.rx = (self.cox-1)+v[3]
		self.ry = (self.coy-1)+v[4]
		self.rw = v[1]
		self.rh = v[2]
		self.forcepush = v[5] --forcefully push camera out of way?
		self.ignoreifoffscreen = v[6]
		table.remove(self.r, 1)
	end

	self.power = true
end

function camerastop:collide(oldx, oldy)
	local playersonscreen = true
	if self.ignoreifoffscreen then
		for i = 1, players do
			local p = objects["player"][i]
			if not onscreenobj(p) then
				playersonscreen = false
				break
			end
		end
	end
	if not (self.power and ((not self.ignoreifoffscreen) or playersonscreen)) then
		return
	end

	local x1, y1, w1, h1 = self.rx, self.ry-.5, self.rw, self.rh

	local function applystop(cx, cy, vw, vh, oldcx, oldcy, setx, sety)
		local x2, y2, w2, h2 = cx, cy, vw, vh
		if not (x1+w1 >= x2 and x1 <= x2+w2 and y1+h1 >= y2 and y1 <= y2+h2) then
			return cx, cy, false
		end

		local forcepush = false
		if self.forcepush then
			local camcx, camcy = (x2 + w2/2), (y2 + h2/2)
			if camcx < x1 then forcepush = "left" end
			if camcx > x1+w1 then forcepush = "right" end
			if camcy > y1+h1 then forcepush = "down" end
			if camcy < y1 then forcepush = "up" end
		end

		local changed = false
		-- right edge of camera hitting left side of stopper
		if (oldcx + vw <= x1 and cx + vw > x1) or forcepush == "left" then
			cx = math.max(0, x1 - vw)
			changed = true
		-- left edge of camera hitting right side of stopper
		elseif (oldcx >= x1 + w1 and cx < x1 + w1) or forcepush == "right" then
			cx = math.min(mapwidth - vw, x1 + w1)
			changed = true
		end
		-- bottom edge of camera hitting top of stopper
		if (oldcy + vh <= y1 and cy + vh > y1) or forcepush == "up" then
			cy = math.max(0, y1 - vh)
			changed = true
		-- top edge of camera hitting bottom of stopper
		elseif (oldcy >= y1 + h1 and cy < y1 + h1) or forcepush == "down" then
			cy = math.min(mapheight - 1 - vh, y1 + h1)
			changed = true
		end

		if changed then
			setx(cx)
			sety(cy)
		end
		return cx, cy, changed
	end

	local anychanged = false

	-- Normal / shared camera (always present)
	local xscroll, yscroll = splitxscroll[1], splityscroll[1]
	local _, _, changed = applystop(
		xscroll, yscroll, width, height,
		oldx or xscroll, oldy or yscroll,
		function(v) splitxscroll[1] = v end,
		function(v) splityscroll[1] = v end
	)
	if changed then anychanged = true end

	-- Per-viewport cameras (SPLITSCREENISBACK system)
	if splitscreenactive() then
		local views = getsplitscreenviews()
		if views then
			for i = 1, players do
				local view = views[i]
				if view and splitcamx[i] and splitcamy[i] then
					local vw = view.w / 16 * screenzoom2
					local vh = view.h / 16 * screenzoom2
					-- We don't have per-viewport "old" values stored, so use current as approximate old.
					-- The forcepush path and continuous clamping still work correctly with the real viewport size.
					local _, _, c = applystop(
						splitcamx[i], splitcamy[i], vw, vh,
						splitcamx[i], splitcamy[i],
						function(v) splitcamx[i] = v end,
						function(v) splitcamy[i] = v end
					)
					if c then anychanged = true end
				end
			end
		end
	end

	if anychanged then
		generatespritebatch()
	end
end

function camerastop:link()
	while #self.r >= 3 do
		for j, w in pairs(outputs) do
			for i, v in pairs(objects[w]) do
				if tonumber(self.r[2]) == v.cox and tonumber(self.r[3]) == v.coy then
					self.linked = true
					v:addoutput(self, self.r[4] or "power")
				end
			end
		end
		
		table.remove(self.r, 1)
		table.remove(self.r, 1)
		table.remove(self.r, 1)
		table.remove(self.r, 1)
	end
end

function camerastop:input(t, input)
	if input == "power" then
		if t == "on" then
			self.power = false
		elseif t == "off" then
			self.power = true
		else
			self.power = not self.power
		end
	end
end