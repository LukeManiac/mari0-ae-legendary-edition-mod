guielement = class:new()

--GUI animations
--every animation lasts 0.25 seconds and uses a random curve from motion_curve (main.lua),
--picked at the moment the animation starts. Animations are time based (love.timer) so they
--keep working even if an element is only drawn and never updated.
local GUI_ANIM_TIME = 0.25

local function gui_anim_start(from, to, curve_in, curve_out)
	--default to ease-out (curve_in=true, curve_out=false)
	return {from = from, to = to, start = love.timer.getTime(), curve = random_motion_curve(), curve_in = curve_in ~= false, curve_out = curve_out or false}
end

--returns the current value of the animation, and whether it has finished
local function gui_anim_value(anim, clamp_output)
	local t = (love.timer.getTime() - anim.start) / GUI_ANIM_TIME
	local p = motion_curve(t, anim.curve, anim.curve_in, anim.curve_out, true, clamp_output)
	return lerp(anim.from, anim.to, p), t >= 1
end

local android_key_repeat = false --bugfix: keep track of last pressed key to prevent glitchy keyboards from inputing letter twice
typingintextinput = false --dirty fix, not neccessarily accurate but good enough to prevent unintended scrolling in editor

function guielement:init(...)
	local arg = {...}
	self.active = true
	self.priority = false
	self.type = arg[1]
	self.x = arg[2]
	self.y = arg[3]
	if self.type == "checkbox" then --checkbox(x, y, func, start, text)
		self.func = arg[4]
		if arg[5] or arg[5] == false then
			self.var = arg[5]
		else
			self.var = true
		end
		self.text = arg[6]
	elseif self.type == "dropdown" then --dropdown(x, y, width (in chars), func, start, {entries})
		self.width = arg[4]
		self.func = arg[5]
		self.var = arg[6] or 1
		self.entries = {}
		for i = 7, #arg do
			table.insert(self.entries, arg[i])
		end
		--self.dropup = ((self.x+(10*#self.entries))(height*16))--the opposite direction so you can see all the options
		self.extended = false
		self.listvalue = 0
		self.listtarget = 0
		self.timer = 0--[DROID]

		self:updatePos()
	elseif self.type == "rightclick" then --rightclick(x, y, width (in chars), func, start, {entries})
		self.width = arg[4]
		self.func = arg[5]
		self.var = arg[6] or nil
		self.entries = {}
		for i = 7, #arg do
			table.insert(self.entries, arg[i])
		end
		self.priority = true
		
		if self.y+10*#self.entries > height*16 then
			self.direction = "up"
		else
			self.direction = "down"
		end
		self:updatePos()
	elseif self.type == "button" then --button(x, y, text, func, space, arguments (in a table), height (in lines), width, center text)
		self.text = arg[4]
		self.func = arg[5]
		self.space = arg[6] or 0
		self.xpadding = 0
		self.ypadding = 0
		if type(arg[7]) ~= "table" then
			self.arguments = {}
		else
			self.arguments = arg[7]
		end
		self.height = arg[8] or 1
		self.width = arg[9] or utf8.len(self.text)*8
		if arg[10] and tonumber(arg[10]) then
			self.autorepeat = arg[10] or false
			self.repeatwait = 0.3
			self.repeatdelay = arg[10] or 0.05
		else
			self.centertext = arg[10]
		end
		
		self.bordercolorhigh = {255, 255, 255}
		self.bordercolor = {127, 127, 127}
		
		self.fillcolor = {0, 0, 0}
		self.textcolor = {255, 255, 255}
	elseif self.type == "scrollbar" then --scrollbar(x, y, yrange, width, height, start, dir)
		self.range = arg[4]
		self.width = arg[5]
		self.height = arg[6]
		self.value = arg[7] or 0
		self.dir = arg[8] or "ver"
		
		if self.dir == "ver" then
			self.yrange = self.range - self.height
		else
			self.xrange = self.range - self.width
		end	
		
		self.backgroundcolor = {127, 127, 127}
		self.bordercolorhigh = {255, 255, 255}
		self.bordercolor = {127, 127, 127}
		
		self.fillcolor = {0, 0, 0}

		self.displayfunction = false

		self.timer = 0
		self.cursoralpha = 1
		self.inputting = false
		self.textvalue = false
	elseif self.type == "input" then --input(x, y, width, enterfunc, start, maxlength, rightclick, height, extra, spacing)
		self.width = arg[4]
		self.func = arg[5]
		self.value = arg[6] or ""
		self.maxlength = arg[7] or 0
		self.height = arg[8] or 1
		self.extra = arg[9] or "none"
		self.spacing = arg[10] or 1
		self.highlighting = false
		self.highlight = false
		
		self.timer = 0
		self.offsettimer = 0
		self.cursoralpha = 1
		self.cursorcurve = random_motion_curve()
		self.inputting = false
		self.lastinputting = false
		self.cursorpos = string.len(self.value)+1
		self.offset = 0
		self.textoffset = 0
		
		self.bordercolorhigh = {255, 255, 255}
		self.bordercolor = {127, 127, 127}
		
		self.fillcolor = {0, 0, 0}
		self.textcolor = {255, 255, 255}

		if android then
			self.didtypecheck = false
			self.didtypetextinput = false
			self.didtype = false
		end
		
		self:updatePos()
		--[[while string.len(self.value)-self.textoffset > self.width-1 and self.width ~= 1 and self.width ~= self.maxlength do
			self.textoffset = self.textoffset + 1
		end]]
	elseif self.type == "text" then --text(x, y, text, color)
		self.text = arg[4]
		self.color = arg[5]
	end
end

local doubleinput = false
local doubleinputcheck = false
function guielement:update(dt)
	if self.active then
		if self.type == "scrollbar" then
			self.timer = self.timer + dt
			local phase = (self.timer % (blinktime * 2)) / blinktime
			if phase < 1 then
				self.cursoralpha = 1
			else
				self.cursoralpha = 1 - (phase - 1)
			end
			if self.dragging then
				if self.dir == "ver" then
					local y = (love.mouse.getY()-self.draggingy) - self.y*scale
					local actualyrange = self.yrange*scale
					
					self.value = math.min(math.max(y / actualyrange, 0), 1) --clamp
				else
					local x = (love.mouse.getX()-self.draggingx) - self.x*scale
					local actualxrange = self.xrange*scale
					
					self.value = math.min(math.max(x / actualxrange, 0), 1) --clamp
				end
				if self.updatefunc then
					self:updatefunc(self.value)
				end
			end
		elseif self.type == "input" then
			self.timer = self.timer + dt
			self.offsettimer = math.max(self.offsettimer-dt, 0)
			if self.inputting ~= self.lastinputting then
				self.cursorcurve = random_motion_curve()
				self.lastinputting = self.inputting
				--only reset when the active state actually changes
				self.timer = 0
				--start faded out (alpha 0) when becoming active
				if self.inputting then
					self.cursoralpha = 0
				end
			end
			--full oscillation over 1 second (0 → 1 → 0), shaped by the random curve
			local t = self.timer % 1
			if t < 0.5 then
				self.cursoralpha = motion_curve(t * 2, self.cursorcurve, false, true, true, true)
			else
				self.cursoralpha = 1 - motion_curve((t - 0.5) * 2, self.cursorcurve, false, true, true, true)
			end
			self.shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
			self.ctrl = love.keyboard.isDown("rctrl") or love.keyboard.isDown("lctrl") or ((love.keyboard.isDown("rgui") or love.keyboard.isDown("lgui")) and love.system.getOS() == "OS X")

			if self.highlighting then
				local mx, my = love.mouse.getX()/scale, love.mouse.getY()/scale
				self.cursorpos = math.max(math.min(round(((math.min(math.max(mx,self.x),self.x+self.width*8)-self.x)+6)/8) + self.textoffset + math.max((math.min(math.ceil(((my-self.y)-1)/10),self.height)-1)*self.width,0), string.len(self.value)+1),1)
				if self.height == 1 and mx > self.x + 4 + self.width*8 and self.offsettimer == 0 then
					self.textoffset = math.min(self.textoffset + 1, string.len(self.value) - self.width + 1)
					self.offsettimer = 0.1
				elseif self.height == 1 and mx < self.x and self.offsettimer == 0 then
					self.textoffset = math.max(self.textoffset - 1, 0)
					self.offsettimer = 0.1
				end
			--drag number without typing
			elseif self.numdraggingstart then
				local dx = (love.mouse.getX()-self.oldmousex)/scale
				if math.abs(dx) > 2 then
					--start dragging number
					self.numdragging = true
					self.numdraggingstart = false
					self.inputting = false
					typingintextinput = false
				end
				--self.oldmousex, self.oldmousey = love.mouse.getPosition()
			end
			if self.numdragging then
				local dx = (love.mouse.getX()-self.oldmousex)/scale
				local add = math.ceil(dx*2)
				if dx < 0 then
					add = math.floor(dx*2)
				end
				self.value = math.max(self.numdrag[1], math.min(self.numdrag[2], tonumber(self.value) + add))
				self:func()
				self.oldmousex, self.oldmousey = love.mouse.getPosition()
			end
			
			--[[DROID]]
			if android then
				android_key_repeat = false

				if self.didtypecheck and (not self.didtype) then
					--force a text input if for some reason the android keyboard did not do anything
					self:keypress(self.didtypecheck,"forcetextinput")
				end

				doubleinputcheck = false
				self.didtypecheck = false
				self.didtype = false
				self.didtypetextinput = false
			end
		elseif self.type == "button" then
			if self.autorepeat then
				if self.holding then
					if self.repeatwaittimer <= 0 then
						self.repeatdelaytimer = self.repeatdelaytimer - dt
						while self.repeatdelaytimer <= 0 do
							if self.func then
								self.func(unpack(self.arguments))
							end
							self.repeatdelaytimer = self.repeatdelaytimer + self.repeatdelay
						end
					else
						self.repeatwaittimer = self.repeatwaittimer - dt
					end
				else
					self.repeatwaittimer = self.repeatwait
					self.repeatdelaytimer = self.repeatdelay
				end
			end
		elseif self.type == "dropdown" then
			self:getlistprogress() --keeps the open/close animation (and priority) up to date
			if self.keycursor and self.keymouse then
				local mx, my = love.mouse.getPosition()
				if mx ~= self.keymouse[1] or my ~= self.keymouse[2] then
					self.keycursor = nil --the mouse moved, so hovering takes over again
				end
			end
			if self.scrollbar then
				self.scrollbar:update(dt)
				self.scroll = self.scrollbar.value*(((#self.entries+1)*10)-(height*16)+1)
			end
			if self.multiy then
				if not self.dropup then
					--glide up/down together with the list opening/closing
					local p = self:getlistprogress()
					self.y = lerp(self.multiy[1], self.multiy[2], p)
				else
					self.y = self.multiy[1]
				end
			end
		end
	end
end

function guielement:draw(a, offx, offy)
	love.graphics.setColor(255, 255, 255)
	if self.type == "checkbox" then
		local quad = 1
		if self.var == true then
			quad = 2
		end
		local high = 1
		local hovering = self:hovered()
		if hovering then high = 2 end

		--hover pop (1 → 1.12) + existing toggle scale
		if hovering ~= self.lasthover then
			self.lasthover = hovering
			self.hoveranim = gui_anim_start(self.hoverscale or 1, hovering and 1.12 or 1)
		end
		local hoverscale = self.hoverscale or 1
		if self.hoveranim then
			local v, done = gui_anim_value(self.hoveranim, true)
			hoverscale = v
			self.hoverscale = v
			if done then self.hoveranim = nil end
		end

		if self.lastvar == nil then
			self.lastvar = self.var
		elseif self.lastvar ~= self.var then
			self.lastvar = self.var
			self.scaleanim = gui_anim_start(0.6, 1)
		end
		local s = hoverscale
		if self.scaleanim then
			local v, done = gui_anim_value(self.scaleanim)
			if done then
				self.scaleanim = nil
			else
				s = hoverscale * math.max(v, 0)
			end
		end
		
		local border = high == 2 and 255 or 127
		local cx, cy = (self.x + 4.5) * scale, (self.y + 4.5) * scale
		love.graphics.push()
		love.graphics.translate(cx, cy)
		love.graphics.scale(s, s)
		love.graphics.translate(-4.5 * scale, -4.5 * scale)

		-- border (same corner ratio as the buttons: 0.15, inner fill 0.7 of that)
		local cbr = 9 * scale * 0.15
		love.graphics.setColor(border, border, border)
		love.graphics.rectangle("fill", 0, 0, 9 * scale, 9 * scale, cbr)
		-- fill
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", 1 * scale, 1 * scale, 7 * scale, 7 * scale, cbr * 0.7)

		-- tickmark when checked
		if self.var then
			love.graphics.setColor(255, 255, 255)
			love.graphics.setLineWidth(scale)
			love.graphics.setLineStyle("smooth")
			-- short leg
			love.graphics.line(2.2 * scale, 4.5 * scale, 4 * scale, 6.5 * scale)
			-- long leg
			love.graphics.line(4 * scale, 6.5 * scale, 7 * scale, 2.5 * scale)
			-- rounded caps on both ends and the elbow
			local tr = scale / 2
			love.graphics.circle("fill", 2.2 * scale, 4.5 * scale, tr, 12)
			love.graphics.circle("fill", 4 * scale, 6.5 * scale, tr, 12)
			love.graphics.circle("fill", 7 * scale, 2.5 * scale, tr, 12)
		end

		love.graphics.pop()
		love.graphics.setLineWidth(1)
		
		if self.text then
			love.graphics.setColor(255, 255, 255) -- was inheriting the black fill colour when unchecked
			properprintF(self.text, (self.x+10)*scale, (self.y+1)*scale)
		end
	elseif self.type == "dropdown" then
		local high = self:inhighlight(love.mouse.getPosition())
		if self.extended and self.keycursor then
			high = self.keycursor --highlight the option picked with the keyboard
		end
		if not high and self.forcehover and not self.nohover then
			high = 0 --looks hovered without a highlighted option
		end
		
		local bordertarget = bool2int(high)
		if self.bordertarget == nil then
			self.bordertarget = bordertarget
			self.bordermix = bordertarget
		elseif bordertarget ~= self.bordertarget then
			self.bordertarget = bordertarget
			self.borderanim = gui_anim_start(self.bordermix, bordertarget)
		end
		if self.borderanim then
			local v, done = gui_anim_value(self.borderanim, true)
			self.bordermix = v
			if done then self.borderanim = nil end
		end
		local bordergrey = lerp(127, 255, self.bordermix)
		
		--p: how far the list is open (0-1), animated. The list stays drawn while it is closing
		local p = self:getlistprogress()
		local ext = self.extended or p > 0
		local listheight = 10*#self.entries
		local listr = math.min((3+self.width*8)*scale, 11*scale) * 0.2 --same corner radius as the header
		
		if ext and not self.cutoff then
			love.graphics.setColor(127, 127, 127)
			local y = self.y
			if self.dropup then
				y = (self.y-(10*#self.entries))
			end
			local fullheight = 10*(#self.entries+1)+1
			local shadowheight = fullheight - (1-p)*listheight
			local shadowy = y+2
			if self.dropup then
				shadowy = y+2 + (fullheight - shadowheight)
			end
			love.graphics.rectangle("fill", (self.x+2)*scale, shadowy*scale, (13+self.width*8)*scale, shadowheight*scale, listr)
		end
	
		love.graphics.setColor(bordergrey, bordergrey, bordergrey)
		
		local dw = (3+self.width*8)*scale
		local dh = 11*scale
		local dr = math.min(dw, dh) * 0.2
		--outer border for the whole control
		love.graphics.rectangle("fill", self.x*scale, self.y*scale, dw, dh, dr)

		--text area fill (left side)
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", (self.x+1)*scale, (self.y+1)*scale, (1+self.width*8)*scale, 9*scale, dr*0.7)

		--arrow button strip on the right (same border colour as the outer frame)
		love.graphics.setColor(bordergrey, bordergrey, bordergrey)
		local abx = (self.x + 2 + self.width*8)*scale
		local aby = self.y*scale
		local abw = 11*scale
		local abh = 11*scale
		local abr = math.min(abw, abh) * 0.2
		love.graphics.rectangle("fill", abx, aby, abw, abh, abr)
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", abx+scale, aby+scale, abw-2*scale, abh-2*scale, abr*0.7)

		--↓ from the font, centred in the arrow button
		love.graphics.setColor(bordergrey, bordergrey, bordergrey)
		local arrowchar = self.dropup and "↑" or "↓"
		properprintF(arrowchar, (self.x + 3 + self.width*8)*scale, (self.y + 2)*scale)
		
		local s = self.entries[self.var]
		if self.extended then
			love.graphics.setColor(127, 127, 127)
		elseif self.coloredtext then
			if s == "black" then
				love.graphics.setColor(80, 80, 80)
			else
				love.graphics.setColor(textcolors[s])
			end
		else
			love.graphics.setColor(255, 255, 255)
		end

		if self.displayentries then s = self.displayentries[self.var];
			if s and s:sub(1, 6) == "_ENEMY" then
				s = " " .. s:sub(7, -1)
				love.graphics.draw(customenemyiconimg, (self.x+1)*scale, (self.y+2)*scale, 0, scale, scale)
			end
		end
		if type(s) == "string" then s = s:sub(1, self.width) end
		properprint(s, (self.x+1)*scale, (self.y+2)*scale)
	
		if ext then
			love.graphics.setColor(127, 127, 127)
			if high then
				love.graphics.setColor(255, 255, 255)
			end
			
			--scroll the list in/out: clip it to the part that is revealed and slide it along
			--(only while it is animating, a fully open list is drawn normally)
			local animating = p < 1
			local oldx, oldy, oldw, oldh
			if animating then
				local clipx, clipy, clipw, cliph, slide
				clipw = (14+self.width*8)*scale
				if self.cutoff then
					--the list covers the whole screen, so grow it outward from the header
					--instead of from the top of the screen
					local fullh = height*16
					local top = self.y*(1-p)
					local bottom = (self.y+11) + (fullh-(self.y+11))*p
					clipx, clipy, cliph = self.x*scale, top*scale, (bottom-top)*scale
					slide = 0
				elseif self.dropup then
					clipx, clipy, cliph = self.x*scale, (self.y-listheight*p)*scale, listheight*p*scale
					slide = (1-p)*listheight*scale
				else
					clipx, clipy, cliph = self.x*scale, (self.y+11)*scale, listheight*p*scale
					slide = -(1-p)*listheight*scale
				end
				oldx, oldy, oldw, oldh = love.graphics.getScissor()
				love.graphics.intersectScissor(math.floor(clipx), math.floor(clipy), math.ceil(clipw), math.max(0, math.ceil(cliph)))
				love.graphics.push()
				love.graphics.translate(0, slide)
			end
			
			if self.cutoff then --have a scrollbar
				love.graphics.rectangle("fill", self.x*scale, -self.scroll*scale, (13+self.width*8)*scale, (10*(#self.entries+1)+1)*scale, listr)
				
				love.graphics.setColor(127, 127, 127)
				if high then
					love.graphics.setColor(255, 255, 255)
				end
				local ax = (self.x+2+self.width*8+4)*scale
				local ay = (-self.scroll+5.5)*scale
				local s = scale
				love.graphics.polygon("fill", ax-3*s, ay-2*s, ax+3*s, ay-2*s, ax, ay+3*s)
				love.graphics.setColor(0, 0, 0)
				love.graphics.rectangle("fill", (self.x+1)*scale, (-self.scroll+1)*scale, (1+self.width*8)*scale, 9*scale)
				love.graphics.setColor(255, 255, 255)
				if ext then
					love.graphics.setColor(127, 127, 127)
				end
				local s = self.entries[self.var]
				if self.displayentries then s = self.displayentries[self.var];
					if s and s:sub(1, 6) == "_ENEMY" then s = " " .. s:sub(7, -1); love.graphics.draw(customenemyiconimg, (self.x+1)*scale, (-self.scroll+2)*scale, 0, scale, scale) end end
				if type(s) == "string" then s = s:sub(1, self.width) end
				properprint(s, (self.x+1)*scale, (-self.scroll+2)*scale)
				
				love.graphics.setColor(127, 127, 127)
				if high then
					love.graphics.setColor(255, 255, 255)
				end
				
				for i = 1, #self.entries do
					local y = ((2+10*i)-self.scroll)
					if y+10*scale > 0 and y < height*16 then
						if high ~= i then
							love.graphics.setColor(0, 0, 0)
							love.graphics.rectangle("fill", (self.x+1)*scale, ((1+i*10)-self.scroll)*scale, (11+self.width*8)*scale, 9*scale, listr*0.7)
							love.graphics.setColor(255, 255, 255)
									
							local s = self.entries[i]
							if self.displayentries then s = self.displayentries[i];
								if s:sub(1, 6) == "_ENEMY" then s = " " .. s:sub(7, -1); love.graphics.draw(customenemyiconimg, (self.x+1)*scale, ((2+10*i)-self.scroll)*scale, 0, scale, scale) end end
							if type(s) == "string" then s = s:sub(1, self.width+1) end
							properprint(s, (self.x+1)*scale, y*scale)
						else
							love.graphics.setColor(0, 0, 0)
							local s = self.entries[i]
							if self.displayentries then s = self.displayentries[i];
								if s:sub(1, 6) == "_ENEMY" then s = " " .. s:sub(7, -1); love.graphics.draw(customenemyiconimg, (self.x+1)*scale, ((2+10*i)-self.scroll)*scale, 0, scale, scale) end end
							if type(s) == "string" then s = s:sub(1, self.width+1) end
							properprint(s, (self.x+1)*scale, y*scale)
						end
					end
				end
				
				self.scrollbar:draw()
			elseif self.dropup then
				love.graphics.rectangle("fill", self.x*scale, (self.y-(10*#self.entries))*scale, (13+self.width*8)*scale, (10*#self.entries)*scale, listr)
				
				for i = 1, #self.entries do
					if high ~= i then
						love.graphics.setColor(0, 0, 0)
						love.graphics.rectangle("fill", (self.x+1)*scale, ((self.y+2+i*10)-(11+(10*#self.entries)))*scale, (11+self.width*8)*scale, 9*scale, listr*0.7)
						love.graphics.setColor(255, 255, 255)
						local s = self.entries[i]
						if self.displayentries then s = self.displayentries[i] end
						if type(s) == "string" then s = s:sub(1, self.width+1) end
						properprint(s, (self.x+1)*scale, ((self.y+3+10*i)-(11+(10*#self.entries)))*scale)
					else
						love.graphics.setColor(0, 0, 0)
						local s = self.entries[i]
						if self.displayentries then s = self.displayentries[i] end
						if type(s) == "string" then s = s:sub(1, self.width+1) end
						properprint(s, (self.x+1)*scale, ((self.y+3+10*i)-(11+(10*#self.entries)))*scale)
					end
				end
			else
				love.graphics.rectangle("fill", self.x*scale, (self.y+11)*scale, (13+self.width*8)*scale, (10*#self.entries)*scale, listr)
				
				for i = 1, #self.entries do
					if high ~= i then
						love.graphics.setColor(0, 0, 0)
						love.graphics.rectangle("fill", (self.x+1)*scale, (self.y+1+i*10)*scale, (11+self.width*8)*scale, 9*scale, listr*0.7)
						love.graphics.setColor(255, 255, 255)
						local s = self.entries[i]
						if self.coloredtext then
							if s == "black" then
								love.graphics.setColor(80,80,80)
							else
								love.graphics.setColor(textcolors[s])
							end
						end
						if self.displayentries then s = self.displayentries[i] end
						if type(s) == "string" then s = s:sub(1, self.width+1) end
						properprint(s, (self.x+1)*scale, (self.y+2+10*i)*scale)
					else
						love.graphics.setColor(0, 0, 0)
						local s = self.entries[i]
						if self.displayentries then s = self.displayentries[i] end
						if type(s) == "string" then s = s:sub(1, self.width+1) end
						properprint(s, (self.x+1)*scale, (self.y+2+10*i)*scale)
					end
				end
			end
			
			if animating then
				love.graphics.pop()
				if oldx then
					love.graphics.setScissor(oldx, oldy, oldw, oldh)
				else
					love.graphics.setScissor()
				end
			end
		end
	elseif self.type == "rightclick" then
		local high = self:inhighlight(love.mouse.getPosition())
	
		love.graphics.setColor(255, 255, 255)
		
		love.graphics.rectangle("fill", self.x*scale, self.y*scale, (3+self.width*8)*scale, 11*scale)
		
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", (self.x+1)*scale, (self.y+1)*scale, (1+self.width*8)*scale, 9*scale)
		
		love.graphics.setColor(180, 180, 180)
			
		properprint(self.entries[1], (self.x+1)*scale, (self.y+2)*scale)
	
		love.graphics.setColor(127, 127, 127)
		if high then
			love.graphics.setColor(255, 255, 255)
		end
		
		if self.direction == "down" then
			love.graphics.rectangle("fill", self.x*scale, (self.y+11)*scale, (3+self.width*8)*scale, (10*(#self.entries-1))*scale)
		else
			love.graphics.rectangle("fill", self.x*scale, (self.y+10-(#self.entries)*10)*scale, (3+self.width*8)*scale, (10*(#self.entries-1))*scale)
		end
		
		for i = 2, #self.entries do
			if high ~= i then
				if ((not self.trustWhatStartWasSetAs) and self.var == self.entries[i]) or (self.trustWhatStartWasSetAs and i == self.var) then
					love.graphics.setColor(0, 127, 0)
				else
					love.graphics.setColor(0, 0, 0)
				end
				if self.direction == "down" then
					love.graphics.rectangle("fill", (self.x+1)*scale, (self.y+lerp(1, i, 10))*scale, (1+self.width*8)*scale, 9*scale)
					love.graphics.setColor(255, 255, 255)
					properprint(self.entries[i], (self.x+1)*scale, (self.y+2+10*(i-1))*scale)
				else
					love.graphics.rectangle("fill", (self.x+1)*scale, (self.y+1-(i-1)*10)*scale, (1+self.width*8)*scale, 9*scale)
					love.graphics.setColor(255, 255, 255)
					properprint(self.entries[i], (self.x+1)*scale, (self.y+2-10*(i-1))*scale)
				end
			else
				if self.var == self.entries[i] then
					love.graphics.setColor(0, 127, 0)
				else
					love.graphics.setColor(0, 0, 0)
				end
				
				if self.direction == "down" then
					properprint(self.entries[i], (self.x+1)*scale, (self.y+2+10*(i-1))*scale)
				else
					properprint(self.entries[i], (self.x+1)*scale, (self.y+2-10*(i-1))*scale)
				end
			end
		end
	elseif self.type == "button" then
		local high = self:hovered()
		
		--smooth hover scale (1 → 1.04) and press zoom
		if high ~= self.lasthigh then
			self.lasthigh = high
			self.hoveranim = gui_anim_start(self.hoverscale or 1, high and 1.04 or 1)
		end
		local hoverscale = self.hoverscale or 1
		if self.hoveranim then
			local v, done = gui_anim_value(self.hoveranim, true)
			hoverscale = v
			self.hoverscale = v
			if done then self.hoveranim = nil end
		end

		local zoom = hoverscale
		if self.pressanim then
			local p, done = gui_anim_value(self.pressanim)
			if done then
				self.pressanim = nil
			else
				zoom = hoverscale * (1 - 0.15*math.sin(math.pi*p))
			end
		end
		if zoom ~= 1 then
			local cx = (self.x + (3+self.width+self.space*2)/2)*scale
			local cy = (self.y + (1+self.height*10+self.space*2)/2)*scale
			love.graphics.push()
			love.graphics.translate(cx, cy)
			love.graphics.scale(zoom, zoom)
			love.graphics.translate(-cx, -cy)
		end

		--lerp border colour toward highlight
		local t = (hoverscale - 1) / 0.04
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
		love.graphics.setColor(
			lerp(self.bordercolor[1], self.bordercolorhigh[1], t),
			lerp(self.bordercolor[2], self.bordercolorhigh[2], t),
			lerp(self.bordercolor[3], self.bordercolorhigh[3], t)
		)
		
		local bw = (3+self.width+self.space*2)*scale
		local bh = (1+self.height*10+self.space*2)*scale
		local br = math.min(bw, bh) * 0.15
		love.graphics.rectangle("fill", self.x*scale, self.y*scale, bw, bh, br)
		
		love.graphics.setColor(self.fillcolor)
		love.graphics.rectangle("fill", (self.x+1)*scale, (self.y+1)*scale, (1+self.width+self.space*2)*scale, (-1+self.height*10+self.space*2)*scale, br * 0.7)

		if self.image then
			if self.imagecolor then
				love.graphics.setColor(self.imagecolor)
			else
				love.graphics.setColor(255,255,255)
			end
			love.graphics.draw(self.image, (self.x+self.imageoffsetx)*scale, (self.y+self.imageoffsety)*scale, 0, scale, scale)
		end
		
		--optional text shake (shakerange returns the range in pixels), only the text moves
		local shakerange = self.shakerange and self.shakerange() or 0
		if shakerange > 0 then
			love.graphics.push()
			love.graphics.translate((math.random()*2-1)*shakerange*scale, (math.random()*2-1)*shakerange*scale)
		end

		love.graphics.setColor(self.textcolor)
		if type(self.text) == "table" then
			love.graphics.draw(self.text[1], self.text[2], (self.x+2+self.xpadding+self.space)*scale, (self.y+2+self.ypadding+self.space)*scale, 0, scale, scale)
		else
			if self.centertext then
				if self.image then
					properprintFbackground(self.text, math.floor((self.x+(self.width/2)-(utf8.len(self.text)*4))*scale), math.floor((self.y+((self.height*10)/2)-3)*scale))
				else
					if utf8.len(self.text) ~= string.len(self.text) then
						properprintF(self.text, math.floor((self.x+(self.width/2)-(utf8.len(self.text)*4))*scale), math.floor((self.y+((self.height*10)/2)-3)*scale))
					else
						properprint(self.text, math.floor((self.x+(self.width/2)-(utf8.len(self.text)*4))*scale), math.floor((self.y+((self.height*10)/2)-3)*scale))
					end
				end
			else
				properprintF(self.text, (self.x+1+self.xpadding+self.space)*scale, (self.y+2+self.ypadding+self.space)*scale)
			end
		end

		if shakerange > 0 then
			love.graphics.pop()
		end
		
		if zoom ~= 1 then
			love.graphics.pop()
		end
		
	elseif self.type == "scrollbar" then
		if self.dir == "ver" then
			local high = self:inhighlight(love.mouse.getPosition())
			
			local tw, th = self.width*scale, (self.yrange+self.height)*scale
			local tr = 0
			if self.buttonround then tr = math.min(tw, th) * 0.15 end
			love.graphics.setColor(self.backgroundcolor)
			love.graphics.rectangle("fill", self.x*scale, self.y*scale, tw, th, tr)
		
			love.graphics.setColor(self.bordercolor)
			if self.dragging or high or self.inputting then
				love.graphics.setColor(self.bordercolorhigh)
			end
			
			local sw, sh = self.width*scale, self.height*scale
			local sr = math.min(sw, sh) * (self.buttonround and 0.15 or 0.25) -- buttons use 0.15

			--press zoom (push on mouse down, retract on release), pivoting on the handle's centre
			local pz = self.presszoom or 1
			if self.presszoomanim then
				local v, done = gui_anim_value(self.presszoomanim)
				pz = math.max(v, 0)
				self.presszoom = pz
				if done then
					self.presszoomanim = nil
					self.presszoom = self.presszoomed and 0.85 or 1
					pz = self.presszoom
				end
			end
			if pz ~= 1 then
				local hcx = (self.x+self.width/2)*scale
				local hcy = (self.y+self.yrange*self.value+self.height/2)*scale
				love.graphics.push()
				love.graphics.translate(hcx, hcy)
				love.graphics.scale(pz, pz)
				love.graphics.translate(-hcx, -hcy)
			end

			love.graphics.rectangle("fill", self.x*scale, (self.y+self.yrange*self.value)*scale, sw, sh, sr)

			love.graphics.setColor(self.fillcolor)
			love.graphics.rectangle("fill", (self.x+1)*scale, (self.y+1+self.yrange*self.value)*scale, (self.width-2)*scale, (self.height-2)*scale, sr * 0.7)

			if pz ~= 1 then
				love.graphics.pop()
			end
		else
			local high = self:inhighlight(love.mouse.getPosition())
			
			local tw, th = (self.xrange+self.width)*scale, self.height*scale
			local tr = 0
			if self.buttonround then tr = math.min(tw, th) * 0.15 end -- same ratio as buttons
			love.graphics.setColor(self.backgroundcolor)
			love.graphics.rectangle("fill", self.x*scale, self.y*scale, tw, th, tr)
		
			love.graphics.setColor(self.bordercolor)
			if self.dragging or high or self.inputting then
				love.graphics.setColor(self.bordercolorhigh)
			end
			
			local sw, sh = self.width*scale, self.height*scale
			local sr = math.min(sw, sh) * (self.buttonround and 0.15 or 0.25) -- buttons use 0.15

			--press zoom (push on mouse down, retract on release), pivoting on the handle's centre
			local pz = self.presszoom or 1
			if self.presszoomanim then
				local v, done = gui_anim_value(self.presszoomanim)
				pz = math.max(v, 0)
				self.presszoom = pz
				if done then
					self.presszoomanim = nil
					self.presszoom = self.presszoomed and 0.85 or 1
					pz = self.presszoom
				end
			end
			if pz ~= 1 then
				local hcx = (self.x+self.xrange*self.value+self.width/2)*scale
				local hcy = (self.y+self.height/2)*scale
				love.graphics.push()
				love.graphics.translate(hcx, hcy)
				love.graphics.scale(pz, pz)
				love.graphics.translate(-hcx, -hcy)
			end

			love.graphics.rectangle("fill", (self.x+self.xrange*self.value)*scale, self.y*scale, sw, sh, sr)
			
			love.graphics.setColor(self.fillcolor)
			love.graphics.rectangle("fill", (self.x+1+self.xrange*self.value)*scale, (self.y+1)*scale, (self.width-2)*scale, (self.height-2)*scale, sr * 0.7)

			if self.displayfunction then
				love.graphics.setColor(self.bordercolorhigh)
				local s = self:displayfunction(self.value)
				if self.inputting then
					s = self.textvalue
				end
				properprint(s, (self.x+self.xrange*self.value)*scale, (self.y+math.ceil((self.height-8)/2))*scale)

				--cursor
				if self.inputting and self.cursoralpha and self.cursoralpha > 0 then
					love.graphics.setColor(255, 255, 255, self.cursoralpha * 255)
					love.graphics.rectangle("fill", (self.x+self.xrange*self.value+string.len(self.textvalue)*8)*scale, (self.y+math.ceil((self.height-8)/2)-1)*scale, 2*scale, 9*scale)
				end
			end

			if pz ~= 1 then
				love.graphics.pop()
			end
		end
	elseif self.type == "input" then
		if self.width >= self.maxlength or self.height > 1 then
			self.textoffset = 0
		end
		local high = self:inhighlight(love.mouse.getPosition())
	
		local bordertarget = bool2int(self.inputting or high)
		if self.bordertarget == nil then
			self.bordertarget = bordertarget
			self.bordermix = bordertarget
		elseif bordertarget ~= self.bordertarget then
			self.bordertarget = bordertarget
			self.borderanim = gui_anim_start(self.bordermix, bordertarget)
		end
		if self.borderanim then
			local v, done = gui_anim_value(self.borderanim, true)
			self.bordermix = v
			if done then self.borderanim = nil end
		end

		if (not self.justdisplay) or self.inputting or high or self.bordermix > 0 then
			local bc, bh, bm = self.bordercolor, self.bordercolorhigh, self.bordermix
			love.graphics.setColor(
				lerp(bc[1], bh[1], bm),
				lerp(bc[2], bh[2], bm),
				lerp(bc[3], bh[3], bm),
				lerp(bc[4] or 255, bh[4] or 255, bm)
			)

			local iw = (3+self.width*8+2*self.spacing)*scale
			local ih = (1+self.height*10+2*self.spacing)*scale
			local ir = math.min(iw, ih) * 0.15
			love.graphics.rectangle("fill", self.x*scale, self.y*scale, iw, ih, ir)

			love.graphics.setColor(self.fillcolor)
			love.graphics.rectangle("fill", (self.x+1)*scale, (self.y+1)*scale, (1+self.width*8+2*self.spacing)*scale, (-1+self.height*10+2*self.spacing)*scale, ir * 0.7)
		end
		love.graphics.setColor(self.textcolor)
		
		if self.height == 1 then
			if self.highlight then
				local highlight1,highlight2 = math.min(self.highlight,self.cursorpos),math.max(self.highlight,self.cursorpos)

				love.graphics.setColor((self.textcolor[1]-self.fillcolor[1])/2,(self.textcolor[2]-self.fillcolor[2])/2,(self.textcolor[3]-self.fillcolor[3])/2)
				local x3, x4 = math.max(1, highlight1 - self.textoffset), math.min(self.width+1, highlight2 - self.textoffset)
				love.graphics.rectangle("fill", (self.x+2+self.spacing+(x3-1)*8)*scale, (self.y+1+self.spacing)*scale, (x4-x3)*8*scale, 9*scale)
			end
			local s = tostring(self.value)
			love.graphics.setColor(self.textcolor)
			if self.allowanycharacters then
				properprintfast(string.sub(s,self.textoffset+1, self.textoffset+self.width), (self.x+1+self.spacing)*scale, (self.y+2+self.spacing)*scale)
			else
				properprint(string.sub(s,self.textoffset+1, self.textoffset+self.width), (self.x+1+self.spacing)*scale, (self.y+2+self.spacing)*scale)
			end
		else
			--format string for tall text boxes
			local oldstring = self.value--string.sub(self.value, self.textoffset+1, self.textoffset+self.width)  --old offsets
			local newstring = {}
			for i = 1, string.len(oldstring), self.width do
				if math.ceil(i/self.width) > self.height then
					break
				end
				table.insert(newstring, string.sub(oldstring, i, i+self.width-1))
			end

			local x3, x4
			local highlight1,highlight2
			if self.highlight then
				highlight1,highlight2 = math.min(self.highlight,self.cursorpos),math.max(self.highlight,self.cursorpos)
			end
			for i = 1, #newstring do
				if self.highlight then
					love.graphics.setColor((self.textcolor[1]-self.fillcolor[1])/2,(self.textcolor[2]-self.fillcolor[2])/2,(self.textcolor[3]-self.fillcolor[3])/2)
					x3, x4 = math.max(math.ceil(highlight1-1)+1-self.width*(i-1),1), math.min(math.ceil(highlight2-1)+1-self.width*(i-1),self.width+1)
					if highlight2 >= (i-1)* self.width+1 and highlight1 <= i * self.width then
						love.graphics.rectangle("fill", (self.x+2+self.spacing+(x3-1)*8)*scale, (self.y+1+self.spacing+(i-1)*10)*scale, (x4-x3)*8*scale, 9*scale)
					end
				end
				love.graphics.setColor(self.textcolor)
				properprint(newstring[i], (self.x+2)*scale, (self.y+2+self.spacing+(i-1)*10)*scale)
			end
		end
		
		--cursor
		if self.inputting then
			local varwidth = self.width
			if self.height == 1 then varwidth = 999999 end
			local x = math.ceil((self.cursorpos-1-self.textoffset) % varwidth)+1
			local y = math.min(math.ceil(self.cursorpos/self.width), self.height)
			
			if (self.cursorpos == self.maxlength+1) and (self.height > 1 or self.width >= self.maxlength) then
				x = self.width+1
			end
			
			--glide to the new position (0.25 s)
			x, y = self:smoothcursor(x, y)
			
			if self.cursoralpha and self.cursoralpha > 0 then
				love.graphics.setColor(self.textcolor[1], self.textcolor[2], self.textcolor[3], self.cursoralpha * 255)
				love.graphics.rectangle("fill", (self.x+1+self.spacing+(x-1)*8)*scale, (self.y+1+self.spacing+(y-1)*10)*scale, 2*scale, 9*scale)
				love.graphics.setColor(self.textcolor)
			end
		else
			--next time the input is focused, the cursor starts at its position without gliding
			self.cursortx = nil
			self.cursoranim = nil
		end
	elseif self.type == "text" then
		love.graphics.setColor(self.color)
		properprint(self.text, self.x*scale, self.y*scale)
	end
	love.graphics.setColor(255, 255, 255)
end

function guielement:click(x, y, button)
	if self.active then
		if self.type == "checkbox" then
			if self:inhighlight(x, y) and button ~= "wd" and button ~= "wu" then
				self.func(not self.var)
			end
		elseif self.type == "dropdown" then
			if self.extended == false then
				if self:inhighlight(x, y) and button ~= "wd" and button ~= "wu" then
					self:open()
				end
			else
				if self.scrollbar then
					self.scrollbar:click(x, y, button)
					if x > (self.x+(13+self.width*8))*scale and x < (self.x+(13+self.width*8)+8)*scale then
						return true
					end
				end
				
				if button ~= "wu" and button ~= "wd" then
					local high = self:inhighlight(x, y)
					self.extended = false
					if self.scrollbar then
						self.scrollbar.active = false
					end
					
					if high then
						if high ~= 0 then
							self.func(high)
						end
						return true
					end
				end
			end
		elseif self.type == "rightclick" then
			local high = self:inhighlight(x, y)
			
			if high then
				if high ~= 0 then
					self.func(high)
				end
				return true
			end
		elseif self.type == "button" then
			if button ~= "wd" and button ~= "wu" and button ~= "r" then
				if self:inhighlight(x, y) then
					self.holding = true
					self.pressanim = gui_anim_start(0, 1)
					if self.func then
						self.func(unpack(self.arguments))
						return true
					end
				end
			end
		elseif self.type == "scrollbar" then
			if button ~= "wd" and button ~= "wu" then
				if self.dir == "ver" then
					if self:inhighlight(x, y) then
						self.dragging = true
						self.draggingy = y-(self.y+self.yrange*self.value)*scale
						if self.buttonround then
							self.presszoomed = true
							self.presszoomanim = gui_anim_start(self.presszoom or 1, 0.85)
						end
					end
				else
					if self:inhighlight(x, y) then
						if button == "r" and (self.rightclickvalue or (self.displayfunction and self.min and self.max)) and not android then
							self.inputting = true
							typingintextinput = true
							self.textvalue = self:displayfunction(self.value)
							self.cursorblink = true
							self.timer = 0
						elseif not self.inputting then
							self.dragging = true
							self.draggingx = x-(self.x+self.xrange*self.value)*scale
							if self.buttonround then
								self.presszoomed = true
								self.presszoomanim = gui_anim_start(self.presszoom or 1, 0.85)
							end
						end
					else
						self.inputting = false
						typingintextinput = false
					end
				end
			end
			if not self.scrollstepdisabled then
				if button == "wd" then
					self.value = math.min(1, self.value+(self.scrollstep or 0.2))
				elseif button == "wu" then
					self.value = math.max(0, self.value-(self.scrollstep or 0.2))
				end
			end
		elseif self.type == "input" then
			if button ~= "wd" and button ~= "wu" then
				if self:inhighlight(x, y) then
					if ((not android) or self.inputting) then
						--click where you want the cursor
						local mx, my = love.mouse.getX()/scale, love.mouse.getY()/scale
						self.cursorpos = math.max(math.min(round(((mx-self.x)+6.5)/8) + self.textoffset + math.max((math.min(math.ceil(((my-self.y)-1)/10),self.height)-1)*self.width,0), string.len(self.value)+1),1)
						if not self.numdrag then
							self.highlighting = true
							self.highlight = self.cursorpos
						end
					else
						self.cursorpos = string.len(self.value)+1
					end
					self.inputting = true
					typingintextinput = true
					if self.width >= self.maxlength or self.height > 1 then
						self.textoffset = 0
					end
					if self.numdrag and (not android) and tonumber(self.value) then
						self.numdraggingstart = true
						self.oldmousex, self.oldmousey = love.mouse.getPosition()
						if not android then
							love.mouse.setCursor(mousecursor_sizewe)
						end
					end
					if self.inputtingfunc then
						self:inputtingfunc()
					end
					if android then
						love.keyboard.setTextInput(true, self.x*scale, self.y*scale, (3+self.width*8+2)*scale, (1+self.height*10+2)*scale) --[DROID]
					end
					love.keyboard.setKeyRepeat(true)
				else
					if self.inputting then
						love.keyboard.setKeyRepeat(false)
					end
					if self.uninputtingfunc then
						self:uninputtingfunc()
					end
					self.inputting = false
					typingintextinput = false
					self.highlight = false
				end
			end
		end
	end
end

function guielement:keypress(key,textinput)
	if self.active then
		if self.type == "dropdown" then
			--an open dropdown takes the up/down/enter keys: up and down move the highlighted option, enter sets it
			if self.extended and not textinput then
				if key == "up" or key == "w" or key == "down" or key == "s" then
					local i = self:getdropdowncursor()
					if key == "up" or key == "w" then
						i = i - 1
						if i < 1 then
							i = #self.entries
						end
					else
						i = i + 1
						if i > #self.entries then
							i = 1
						end
					end
					self.keycursor = i
					self.keymouse = {love.mouse.getPosition()}
					self:scrolltocursor()
					return true
				elseif key == "return" or key == "enter" or key == "kpenter" then
					local i = self:getdropdowncursor()
					self:close()
					self.func(i)
					return true
				end
			end
		elseif self.type == "scrollbar" then
			--Type in number into scrollbar
			if self.inputting and not self.highlighting then
				if key == "escape" then
					self.inputting = false
					typingintextinput = false
					love.keyboard.setKeyRepeat(false)
				elseif (key == "return" or key == "enter" or key == "kpenter") then
					local newvalue = tonumber(self.textvalue)
					if newvalue then
						if self.rcrange or (self.min and self.max) then
							local min, max = self.min or self.rcrange[1], self.max or self.rcrange[2]
							newvalue = math.min(max, math.max(min, newvalue))
							self.value = (newvalue-min)/(max-min)
						end
						if self.updatefunc then
							self:updatefunc(self.value)
						end
					end
					self.inputting = false
					typingintextinput = false
					love.keyboard.setKeyRepeat(false)
				elseif key == "backspace" then
					self.textvalue = string.sub(self.textvalue, 1, -2)
				else
					if string.len(self.textvalue) < math.floor(self.width/8) then
						if tonumber(key) or key == "-" or key == "." then
							self.textvalue = self.textvalue .. key
							self.cursorblink = true
							self.timer = 0
						end
					end
				end
			end
		elseif self.type == "input" then
			if self.inputting then
				--[[DROID
				if android then
					if android_key_repeat == key then
						return
					end
					android_key_repeat = key
				end]]

				if (key == ":" or key == ";") and not self.allowanycharacters then
					return
				elseif key == "," and (not self.bypassspecialcharacters) then
					key = "A"
				elseif key == "-" and (not self.bypassspecialcharacters) then
					key = "B"
				end
				if key == "escape" and not android then
					self.inputting = false
					typingintextinput = false
					self.highlight = false
					love.keyboard.setKeyRepeat(false)
				elseif (key == "return" or key == "enter" or key == "kpenter") or (android and key == "escape") then
					if self.func then
						if self.extra == "music" then
							changemusic(musici)
							self.inputting = false
							typingintextinput = false
							love.keyboard.setKeyRepeat(false)
							if android then
								love.keyboard.setTextInput(false)--[DROID]
							end
						elseif self.extra == "rightclick" then
							self.func(self.value)
							self.inputting = false
							typingintextinput = false
							love.keyboard.setKeyRepeat(false)
							if android then
								love.keyboard.setTextInput(false)--[DROID]
							end
						else
							self:func()
						end
					else
						self.inputting = false
						typingintextinput = false
						love.keyboard.setKeyRepeat(false)
						if android then
							love.keyboard.setTextInput(false)--[DROID]
						end
					end
				elseif key == "left" then
					if not self.shift then
						if self.highlight then
							self.cursorpos = math.min(self.cursorpos,self.highlight)+1
							self.highlight = false
						end
					else
						self.highlight = self.highlight or self.cursorpos
					end
					self.cursorpos = math.max(1, self.cursorpos - 1)
					--while self.cursorpos-1 < self.textoffset do
						self.textoffset = math.max(math.min(self.cursorpos-1, self.textoffset), 0)
					--end
				elseif key == "right" then
					if not self.shift then
						if self.highlight then
							self.cursorpos = math.max(self.cursorpos,self.highlight)-1
							self.highlight = false
						end
					else
						self.highlight = self.highlight or self.cursorpos
					end

					self.cursorpos = math.min(string.len(self.value) + 1, self.cursorpos + 1)
					--while self.cursorpos-1 >= self.textoffset+self.width do
						self.textoffset = math.min(math.max(self.textoffset, self.cursorpos-self.width), self.maxlength - self.width)
					--end
				elseif key == "up" and self.height > 1 then
					if not self.shift then
						self.highlight = false
					else
						self.highlight = self.highlight or self.cursorpos
					end

					self.cursorpos = math.max(1, self.cursorpos - self.width)
				elseif key == "down" and self.height > 1 then
					if not self.shift then
						self.highlight = false
					else
						self.highlight = self.highlight or self.cursorpos
					end

					self.cursorpos = math.min(string.len(self.value) + 1, self.cursorpos + self.width)
				elseif key == "backspace" or (key == "x" and self.ctrl and self.highlight) then
					if self.highlight then
						local highlight = {math.min(self.highlight,self.cursorpos),math.max(self.highlight,self.cursorpos)}
						if key == "x" and self.ctrl then
							-- cut text selection
							textclipboard = string.sub(self.value,highlight[1],highlight[2]-1)
						end
						self.value = string.sub(self.value,1,highlight[1]-1)..string.sub(self.value,highlight[2])
						self.cursorpos = highlight[1]
						self.highlight = false
						self.textoffset = math.max(math.min(self.textoffset, self.cursorpos-1), 0)
					elseif self.cursorpos > 1 then
						self.value = string.sub(self.value,1,self.cursorpos-2)..string.sub(self.value,self.cursorpos)
						if self.cursorpos > 1 then
							self.cursorpos = self.cursorpos - 1
						end
						self.textoffset = math.max(self.textoffset - 1, 0)
					end

					self.timer = 0
					self.cursoralpha = 1
				elseif key == "a" and self.ctrl then
					self.highlight = 1
					self.cursorpos = string.len(self.value) + 1
				elseif key == "c" and self.ctrl then
					--copy text selection
					if self.highlight then
						local highlight1, highlight2 = math.min(self.highlight,self.cursorpos),math.max(self.highlight,self.cursorpos)
						textclipboard = string.sub(self.value,highlight1,highlight2-1)
					end
				else
					if android then
						if not (textinput and textinput == "forcetextinput") then
							local justchanged = false
							if not doubleinput then
								if doubleinputcheck and key and doubleinputcheck:lower() == key:lower() then
									doubleinput = true
									justchanged = true
								end
								doubleinputcheck = key
							end
							if textinput or (not self.didtypecheck) then
								self.didtypecheck = key
								if textinput then
									self.didtypetextinput = true
								end
							end
							if doubleinput and ((not textinput) or justchanged) then
								return false
							end
							self.didtype = true
						end
					end
					if string.len(self.value) < self.maxlength or self.maxlength == 0 then
						local found = false
						local targetkey = key
						
						if self.shift and not android then
							if key == "1" then
								targetkey = "!"
							elseif key == "2" then
								targetkey = "@"
							elseif key == "3" then
								targetkey = "#"
							elseif key == "4" then
								targetkey = "^"
							elseif key == "5" then
								targetkey = "%"
							elseif key == "7" then
								targetkey = "&"
							elseif key == "8" then
								targetkey = "*"
							elseif key == "9" then
								targetkey = "("
							elseif key == "0" then
								targetkey = ")"
							elseif key == "/" then
								targetkey = "?"
							elseif key == "]" then
								targetkey = "}"
							elseif key == "[" then
								targetkey = "{"
							elseif key == "-" then
								targetkey = "_"
							elseif key == "=" then
								targetkey = "+"
							elseif key == "B" and not self.bypassspecialcharacters then
								targetkey = "_"
							elseif key == ";" then
								targetkey = ":"
							end
						end
						
						found = (targetkey == " ")
						if not found then
							for char, quad in pairs(fontquads) do
								if targetkey == char then
									found = true
									break
								end
							end
						end
						
						if found then
							if key == "v" and self.ctrl then
								local highlightlength = 0
								if self.highlight then
									highlightlength = math.abs(self.highlight - self.cursorpos)
								end
								if textclipboard then
									if (#textclipboard or 0) + string.len(self.value) - highlightlength <= self.maxlength then
										targetkey = textclipboard
									else
										notice.new("no room to paste!")
										targetkey = ""
									end
								else
									notice.new("clipboard is empty!")
									targetkey = ""
								end
							end
							if self.highlight and targetkey ~= "" then
								local highlight1,highlight2 = math.min(self.highlight,self.cursorpos),math.max(self.highlight,self.cursorpos)
								self.value = string.sub(self.value,1,highlight1-1)..targetkey..string.sub(self.value,highlight2)
								self.cursorpos = highlight1
								self.highlight = false
							elseif targetkey ~= "" then
								self.value = string.sub(self.value,1,self.cursorpos-1)..targetkey..string.sub(self.value,self.cursorpos)
							end

							if self.cursorpos <= self.maxlength then
								self.cursorpos = self.cursorpos + #targetkey
							end
							--while self.cursorpos > self.textoffset+self.width do
								self.textoffset = math.max(self.cursorpos-self.width, self.textoffset)
							--end
							self.cursorblink = true
							self.timer = 0
						end
					elseif key == "v" and self.ctrl and textclipboard and #textclipboard > 0 then
						notice.new("no room to paste!")
					end
				end
				
				return true
			end
		end
	end
end

function guielement:unclick(x, y)
	if self.active then
		if self.type == "input" then
			if self.highlighting then
				self.highlighting = false
				if self.highlight == self.cursorpos then
					self.highlight = false
				end
			elseif self.numdrag then
				self.numdraggingstart = false
				self.numdragging = false
				if not android then
					love.mouse.setCursor()
				end
			end
		elseif self.type == "scrollbar" then
			local wasdragging = self.dragging
			self.dragging = false
			if self.presszoomed then
				self.presszoomed = false
				self.presszoomanim = gui_anim_start(self.presszoom or 1, 1)
			end
			if wasdragging and self.releasefunc then
				self:releasefunc(self.value)
			end
		elseif self.type == "dropdown" then
			if self.scrollbar then
				self.scrollbar:unclick(x, y)
			end
		elseif self.type == "button" then
			self.holding = false
		end
	end
end

--true when the mouse is over the element, or when it is made to look hovered (forcehover, e.g. selected with the keyboard)
function guielement:hovered()
	if editormode and not editor_gui_interaction_enabled(self) then
		return false
	end
	if self:inhighlight(love.mouse.getPosition()) then
		return true
	end
	return self.forcehover and not self.nohover
end

--dropdown: open the list. keyboard = true highlights the current option so up/down/enter can be used right away
function guielement:open(keyboard)
	if self.type ~= "dropdown" then
		return
	end
	if self.multiy then
		--could be mid-animation, start from the real position
		self.y = self.multiy[1]
	end
	self:updatePos()
	self.extended = true
	self.priority = true
	if self.scrollbar then
		self.scrollbar.active = true
	end

	if keyboard then
		self.keycursor = self.var
		self.keymouse = {love.mouse.getPosition()}
		self:scrolltocursor()
	else
		self.keycursor = nil
	end
end

--dropdown: close the list without picking anything
function guielement:close()
	if self.type ~= "dropdown" then
		return
	end
	self.extended = false
	self.keycursor = nil
	if self.scrollbar then
		self.scrollbar.active = false
	end
end

--dropdown: the option up/down/enter works on (keyboard highlight, else the hovered option, else the current one)
function guielement:getdropdowncursor()
	if self.keycursor then
		return self.keycursor
	end
	local high = self:inhighlight(love.mouse.getPosition())
	if high and high > 0 then
		return high
	end
	return self.var
end

--dropdown: scroll a long (cut off) list so the keyboard's option is on screen
function guielement:scrolltocursor()
	if self.cutoff and self.scrollbar and self.keycursor then
		local range = ((#self.entries+1)*10)-(height*16)+1
		local top = 10*self.keycursor
		local bottom = top + 11
		local scroll = self.scroll or 0
		if top < scroll then
			scroll = top
		elseif bottom > scroll + height*16 then
			scroll = bottom - height*16
		end
		self.scrollbar.value = math.max(0, math.min(1, scroll/range))
		self.scroll = self.scrollbar.value*range
	end
end

--returns the dropdown that is currently open (or false), so other code can tell when keys belong to it
function guielement.getopendropdown()
	for i, v in pairs(guielements) do
		if v.type == "dropdown" and v.active and v.extended then
			return v
		end
	end
	return false
end

--dropdown: how far the list is open, from 0 (closed) to 1 (open).
--Whenever self.extended changes, a new 0.25 second animation with a random curve starts.
function guielement:getlistprogress()
	local target = bool2int(self.extended)
	if target ~= self.listtarget then
		--opening (0→1): ease-out; closing (1→0): ease-in
		self.listanim = gui_anim_start(self.listvalue, target, target == 1, false)
		self.listtarget = target
	end
	if self.listanim then
		local v, done = gui_anim_value(self.listanim)
		if done then
			self.listanim = nil
			self.listvalue = self.listtarget
			if self.listtarget == 0 then
				self.priority = false
			end
		else
			self.listvalue = math.max(0, math.min(1, v))
		end
	end
	return self.listvalue
end

--input: moves the displayed cursor towards the given position (in characters/lines).
--0.0625 s animation. Curve is randomised only when inputting is toggled.
--Entering a character (moving forward) uses ease-in; removing uses ease-out.
local CURSOR_ANIM_TIME = 0.0625

function guielement:smoothcursor(x, y)
	if self.cursortx == nil then
		--just focused, no gliding
		self.cursortx, self.cursorty = x, y
		self.cursordx, self.cursordy = x, y
		self.cursoranim = nil
	elseif x ~= self.cursortx or y ~= self.cursorty then
		self.cursorfromx, self.cursorfromy = self.cursordx, self.cursordy
		local moving_forward = (x + y * 1000) > (self.cursortx + self.cursorty * 1000)
		--reuse the curve picked when inputting toggled; only the easing direction changes
		self.cursoranim = {
			from = 0, to = 1,
			start = love.timer.getTime(),
			curve = self.cursorcurve or random_motion_curve(),
			curve_in = not moving_forward,
			curve_out = false
		}
		self.cursortx, self.cursorty = x, y
	end
	
	if self.cursoranim then
		local t = (love.timer.getTime() - self.cursoranim.start) / CURSOR_ANIM_TIME
		local p = motion_curve(t, self.cursoranim.curve, self.cursoranim.curve_in, self.cursoranim.curve_out, true, true)
		if t >= 1 then
			self.cursoranim = nil
			self.cursordx, self.cursordy = self.cursortx, self.cursorty
		else
			self.cursordx = lerp(self.cursorfromx, self.cursortx, p)
			self.cursordy = lerp(self.cursorfromy, self.cursorty, p)
		end
	end
	return self.cursordx, self.cursordy
end

function guielement:inhighlight(x, y)
	if editormode and not editor_gui_interaction_enabled(self) then
		return false
	end
	if self.controlbindpage and optionscontrols_transformmouse then
		x, y = optionscontrols_transformmouse(x, y)
	end
	if self.nohover then --e.g. the level properties panel while it is still sliding, or a menu on top of it
		return false
	end
	if self.type == "checkbox" then
		local xadd = 0
		if self.text then
			xadd = utf8.len(self.text)*8+1
		end
		if x >= self.x*scale and x < (self.x+9+xadd)*scale and y >= self.y*scale and y < (self.y+9)*scale then
			return true
		end
	elseif self.type == "dropdown" then
		if self.extended == false then
			if x >= self.x*scale and x < (self.x+13+self.width*8)*scale and y >= self.y*scale and y < (self.y+11)*scale then
				return true
			end
		else
			if self.cutoff then
				if x >= self.x*scale and x < (self.x+13+self.width*8)*scale and y >= -self.scroll*scale and y < ((10*#self.entries+11)-self.scroll)*scale then
					--get which entry
					return math.max(0, math.min(#self.entries, math.floor((y+self.scroll*scale) / (10*scale))))
				end
			elseif self.dropup then
				--(11+))
				if x >= self.x*scale and x < (self.x+13+self.width*8)*scale and y >= (self.y-(10*#self.entries))*scale and y < (self.y+11)*scale then
					--get which entry
					local i = math.max(0, math.floor((y-(self.y-10-(10*#self.entries))*scale) / (10*scale)))
					if i > #self.entries then
						i = 0
					end
					return i
				end
			else
				if x >= self.x*scale and x < (self.x+13+self.width*8)*scale and y >= self.y*scale and y < (self.y+10*#self.entries+11)*scale then
					--get which entry
					return math.max(0, math.floor((y-(self.y+1)*scale) / (10*scale)))
				end
			end
		end
	elseif self.type == "rightclick" then
		if self.direction == "down" then
			if x > self.x*scale and x < (self.x+3+self.width*8)*scale and y >= self.y*scale and y < (self.y+10*#self.entries+1)*scale then
				--get which entry
				return math.max(0, math.floor((y-(self.y+1)*scale) / (10*scale))+1)
			end
		else
			if x > self.x*scale and x < (self.x+3+self.width*8)*scale and y >= (self.y-10*(#self.entries-1))*scale and y < (self.y+11)*scale then
				--get which entry
				return math.max(0, math.floor((self.y*scale-y) / (10*scale))+2)
			end
		end
	elseif self.type == "button" then
		if self.clickswithinyrange and (y < self.clickswithinyrange[1]*scale or y > self.clickswithinyrange[2]*scale) then
			--ignore clicks outside y range
			return false
		end
		if x >= self.x*scale and x < (self.x+3+self.width+self.space*2)*scale and y >= self.y*scale and y < (self.y+1+self.height*10+self.space*2)*scale then
			return true
		end
	elseif self.type == "scrollbar" then
		if self.dir == "ver" then
			if x >= self.x*scale and x < (self.x+self.width)*scale and y >= (self.y+self.yrange*self.value)*scale and y < (self.height+self.y+self.yrange*self.value)*scale then
				return true
			end
		else
			if x >= (self.x+self.xrange*self.value)*scale and x < (self.x+self.width+self.xrange*self.value)*scale and y >= self.y*scale and y < (self.height+self.y)*scale then
				return true
			end
		end
	elseif self.type == "input" then
		if x >= self.x*scale and x < (self.x+3+self.width*8+2*self.spacing)*scale and y >= self.y*scale and y < (self.y+1+self.height*10+2*self.spacing)*scale then
			return true
		end
	end
	
	return false
end

function guielement:updatePos()
	if self.type == "dropdown" then
		if 10*(#self.entries+1) > height*16 then
			local yrange = (((#self.entries+1)*10)-(height*16)+1)
			self.cutoff = true
			self.scroll = 0
			self.scrollbar = guielement:new("scrollbar", self.x+(self.width*8+13), 0, height*16, 8, 40, 0, "ver")
			self.scrollbar.active = false
			self.scrollbar.yrange = self.scrollbar.yrange + self.scrollbar.height
			self.scrollbar.height = math.max(30, math.min(1, (height*16)/(yrange+(height*16)))*(height*16))
			self.scrollbar.yrange = self.scrollbar.yrange - self.scrollbar.height
			self.scrollbar.scrollstep = math.max(0.0001, 73/yrange)
		end
		if not self.cutoff and self.y+10*(#self.entries+1) > height*16 then
			self.multiy = {self.y, height*16-(10*(#self.entries+1))}
		else
			self.multiy = false
		end
	elseif self.type == "rightclick" then
		if self.direction == "up" and self.y-#self.entries*10-10 < 0 then
			self.y = #self.entries*10-10
		elseif self.direction == "down" and self.y+#self.entries*10 > height*16 then
			self.y = math.max(0, height*16-(#self.entries*10))
		end
		
		if self.x+self.width*8 > width*16 then
			self.x = (width*16)-self.width*8
		end
	elseif self.type == "input" then
		self.textoffset = 0
		while string.len(self.value)-self.textoffset > self.width-1 and self.width ~= 1 and self.width ~= self.maxlength do
			self.textoffset = self.textoffset + 1
		end
	end
end
