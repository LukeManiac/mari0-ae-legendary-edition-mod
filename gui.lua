require "guiglass"

guielement = class:new()

--GUI animations
--every animation lasts 0.25 seconds. Animations are time based (love.timer) so they
--keep working even if an element is only drawn and never updated.
local GUI_ANIM_TIME = 0.25
local opened_dropdown = false

local function gui_anim_start(from, to)
	return {from = from, to = to, start = love.timer.getTime()}
end

--returns the current value of the animation, and whether it has finished
local function gui_anim_value(anim)
	local t = (love.timer.getTime() - anim.start) / GUI_ANIM_TIME
	local p = ease_in_out_quad(t)
	return lerp(anim.from, anim.to, p), t >= 1
end

--dropdown layout (all in game pixels). A plain dropdown has 10 pixel rows in one column, but a graphical one
--(see guielement:setentrydrawing) can have taller rows, a grid of columns and draw its entries itself.
--The header is a row tall plus 1 pixel, and the list below it is rows*rowheight tall
local function dropdown_rowheight(self)
	return self.rowheight or 10
end

local function dropdown_headerheight(self)
	return dropdown_rowheight(self)+1
end

local function dropdown_columns(self)
	return self.columns or 1
end

local function dropdown_listheight(self)
	return math.ceil(#self.entries/dropdown_columns(self))*dropdown_rowheight(self)
end

--how far a list taller than the screen scrolls
local function dropdown_scrollrange(self)
	return dropdown_headerheight(self)+dropdown_listheight(self)-(height*16)
end

--column and row (both from 1) of an entry
local function dropdown_cell(self, i)
	local columns = dropdown_columns(self)
	return (i-1)%columns+1, math.floor((i-1)/columns)+1
end

--left edge and width of a column: the columns share the list's inside, with a 1 pixel gap between them
local function dropdown_columnspan(self, column)
	local inside = 11+self.width*8
	local columns = dropdown_columns(self)
	local left = math.floor((column-1)*inside/columns)
	local right = math.floor(column*inside/columns)
	if column < columns then
		right = right-1
	end
	return self.x+1+left, right-left
end

--the entry under a point of the list (game pixels, y from the top of the first row), 0 for a gap past the last entry
local function dropdown_entryat(self, x, y)
	local columns = dropdown_columns(self)
	local row = math.floor(y/dropdown_rowheight(self))+1
	local column = math.floor((x-self.x-1)*columns/(11+self.width*8))+1
	column = math.max(1, math.min(columns, column))
	local i = (row-1)*columns+column
	if row < 1 or i > #self.entries then
		return 0
	end
	return i
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
			--typing cursor: the same animation as text inputs
			self.timer = self.timer + dt
			if self.inputting ~= self.lastinputting then
				self.lastinputting = self.inputting
				self.timer = 0
				if self.inputting then
					self.cursoralpha = 0
				end
			end
			--full oscillation over 1 second (0 → 1 → 0)
			local t = self.timer % 1
			if t < 0.5 then
				self.cursoralpha = ease_in_out_quad(t * 2)
			else
				self.cursoralpha = 1 - ease_in_out_quad((t - 0.5) * 2)
			end
			--a wheel slide: dragging, or anything else setting the value, takes over from it
			if self.wheelanim then
				if self.dragging or self.value ~= self.wheelvalue then
					self.wheelanim = nil
				else
					local pos, done = gui_wheelanimposition(self.wheelanim, love.timer.getTime())
					if done then
						self.wheelanim = nil
					end
					self.value = math.max(0, math.min(1, pos))
					self.wheelvalue = self.value
				end
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
				self.lastinputting = self.inputting
				--only reset when the active state actually changes
				self.timer = 0
				--start faded out (alpha 0) when becoming active
				if self.inputting then
					self.cursoralpha = 0
				end
			end
			--full oscillation over 1 second (0 → 1 → 0)
			local t = self.timer % 1
			if t < 0.5 then
				self.cursoralpha = ease_in_out_quad(t * 2)
			else
				self.cursoralpha = 1 - ease_in_out_quad((t - 0.5) * 2)
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
			self:getlistprogress()
			if opened_dropdown == self and not self.extended then
				opened_dropdown = false
			end
			if self.keycursor and self.keymouse then
				local mx, my = love.mouse.getPosition()
				if mx ~= self.keymouse[1] or my ~= self.keymouse[2] then
					self.keycursor = nil --the mouse moved, so hovering takes over again
				end
			end
			if self.scrollbar then
				self.scrollbar:update(dt)
				local range = dropdown_scrollrange(self)
				if self.wheelanim then
					if self.scrollbar.dragging then
						self.wheelanim = nil --dragging the scrollbar takes over
					else
						local pos, done = gui_wheelanimposition(self.wheelanim, love.timer.getTime())
						if done then
							self.wheelanim = nil
						end
						self.scrollbar.value = math.max(0, math.min(1, pos/range))
					end
				end
				self.scroll = self.scrollbar.value*range
			end
			if self.multiy then
				if not self.dropup then
					local p = self:getlistprogress()
					self.y = self.multiy[1] + (self.multiy[2]-self.multiy[1])*p
				else
					self.y = self.multiy[1]
				end
			end
		end
	end
end

--areaw (game pixels): the width of the area the entry sits in; the entry is drawn in the middle of it
local function drawdropdownentry(entry, x, y, maxchars, areaw)
	local customenemy = type(entry) == "string" and entry:sub(1, 6) == "_ENEMY"
	if customenemy then
		entry = " " .. entry:sub(7) --the space is where the icon goes
	end
	local utf = false
	if type(entry) == "string" then
		local length = utf8.len(entry)
		if length and length ~= string.len(entry) then
			--accents, cyrillic...: cut by character and print with the utf-8 printer
			utf = true
			local stop = utf8.offset(entry, maxchars + 1)
			if stop then
				entry = entry:sub(1, stop - 1)
			end
		else
			entry = entry:sub(1, maxchars)
		end
	end

	--in the middle of its area (an entry too long for it starts at the left, like before)
	if areaw then
		local chars = utf8.len(tostring(entry)) or string.len(tostring(entry))
		x = x + math.max(0, math.floor((areaw - chars*8)/2))
	end

	if customenemy then
		local r, g, b, a = love.graphics.getColor()
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.draw(customenemyiconimg, x*scale, y*scale, 0, scale, scale)
		love.graphics.setColor(r, g, b, a)
	end
	if utf then
		properprintF(entry, x*scale, y*scale)
	else
		properprint(entry, x*scale, y*scale)
	end
end

--a dropdown can colour its entries: dropdown.entrycolors = {[entry number] = {r, g, b}, ...}
--(set it straight on the element or with dropdown:setentrycolors), entries without a colour use the usual one
local function getdropdownentrycolor(self, i)
	return self.entrycolors and i and self.entrycolors[i]
end

local function setdropdownentrycolor(self, entry, i)
	local color = getdropdownentrycolor(self, i)
	if color then
		love.graphics.setColor(color)
	elseif self.coloredtext then
		if entry == "black" then
			love.graphics.setColor(80, 80, 80)
		else
			love.graphics.setColor(textcolors[entry])
		end
	else
		love.graphics.setColor(255, 255, 255)
	end
end

--a graphical dropdown draws entry i in the box x, y, w, h (game pixels) itself
--highlighted: the box is the bright list colour behind it (hovered or picked with the keyboard)
--header: it is the closed dropdown's current entry (dimmed while the list is open)
local function drawgraphicalentry(self, i, x, y, w, h, highlighted, header)
	if not self.entries[i] then
		return
	end
	local r, g, b, a = love.graphics.getColor()
	self.drawentryfunc(self, i, x, y, w, h, highlighted, header)
	love.graphics.setColor(r, g, b, a)
end

--seconds since this element's last frame (each element keeps its own clock, so it works however often it's drawn)
local function framedt(st, key)
	local now = love.timer.getTime()
	local last = st[key] or now
	st[key] = now
	return math.min(math.max(now - last, 0), 1/20)
end

--a 0-1 value that eases towards on (1) or off (0), like the old border fades
local function hovermix(self, key, on)
	local target = bool2int(on)
	local anim = self[key .. "anim"]
	if self[key .. "target"] == nil then
		self[key .. "target"] = target
		self[key] = target
	elseif target ~= self[key .. "target"] then
		self[key .. "target"] = target
		anim = gui_anim_start(self[key], target)
		self[key .. "anim"] = anim
	end
	if anim then
		local v, done = gui_anim_value(anim)
		self[key] = v
		if done then
			self[key .. "anim"] = nil
		end
	end
	return self[key]
end

local function lerpcolor(c1, c2, t)
	return {lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t)}
end

--a highlight pill that glides from option to option and fades in and out (target: {x, y, w, h} or nil)
local function glidepill(st, key, target, dt)
	local pill = st[key]
	if not pill then
		pill = {a = 0}
		st[key] = pill
	end
	local f = 1 - math.exp(-dt*24)
	if target then
		if pill.a < 0.05 or not pill.x then
			pill.x, pill.y, pill.w, pill.h = target[1], target[2], target[3], target[4]
		else
			pill.x = lerp(pill.x, target[1], f)
			pill.y = lerp(pill.y, target[2], f)
			pill.w = lerp(pill.w, target[3], f)
			pill.h = lerp(pill.h, target[4], f)
		end
		pill.a = lerp(pill.a, 1, f)
	else
		pill.a = lerp(pill.a, 0, f)
	end
	return pill
end

--dropdown lists pop in and out with a jelly. These say how long each part takes
local DROPDOWN_CLOSE_DELAY = 0.06 --the panel waits this long for its options to start shrinking
local DROPDOWN_CLOSE_TIME = 0.2   --each option (and the panel) shrinks in this long

local function dropdown_rows(self)
	return math.max(1, math.ceil(#self.entries/dropdown_columns(self)))
end

local function drop_stagger(rows)
	return math.min(0.022, 0.16/rows)
end

local function drop_closetime(rows)
	return DROPDOWN_CLOSE_DELAY + DROPDOWN_CLOSE_TIME + drop_stagger(rows)*(rows-1)
end

--keeps track of when a dropdown-like panel opened and closed (on owner), and says whether any of it is still on screen
local function drop_timeline(owner, open, rows)
	local st = guiglass.state(owner)
	local now = love.timer.getTime()
	if st.wasext == nil then
		st.wasext = open
		if open then
			st.openat = now
		end
	elseif st.wasext ~= open then
		st.wasext = open
		if open then
			st.openat = now
			st.closeat = nil
		else
			st.closeat = now
		end
	end
	if open then
		return true
	end
	if st.closeat and now - st.closeat < drop_closetime(rows) then
		return true
	end
	st.closeat = nil
	return false
end

--the panel's jelly: scale x, scale y (it grows out of the header's edge) and opacity
local function drop_panelscale(owner, open)
	local st = guiglass.state(owner)
	local now = love.timer.getTime()
	local sy, alpha
	if open then
		local ot = now - (st.openat or now)
		sy = guiglass.jellyin(ot*1.15)
		alpha = math.min(1, ot*12)
	else
		local ct = now - (st.closeat or now)
		sy = guiglass.jellyout((ct - DROPDOWN_CLOSE_DELAY)/DROPDOWN_CLOSE_TIME)
		alpha = math.max(0, math.min(1, sy*3))
	end
	return guiglass.jellywidth(sy, 0.25), sy, alpha
end

--a row's own jelly. distance: how many rows it is from the header (it pops after the ones nearer the header,
--and closing, the ones furthest from the header go first)
local function drop_rowscale(owner, open, distance, rows)
	local st = guiglass.state(owner)
	local now = love.timer.getTime()
	local stagger = drop_stagger(rows)
	if open then
		local ot = now - (st.openat or now) - 0.03 - stagger*distance
		local sy = guiglass.jellyin(ot*1.1)
		return guiglass.jellywidth(sy), sy, math.max(0, math.min(1, ot*12))
	end
	local ct = now - (st.closeat or now) - stagger*(rows - 1 - distance)
	local sy = guiglass.jellyout(ct/DROPDOWN_CLOSE_TIME)
	return guiglass.jellywidth(sy), sy, math.max(0, math.min(1, sy*3))
end

local function dropdown_timeline(self)
	if drop_timeline(self, self.extended, dropdown_rows(self)) then
		return true
	end
	return (self.listvalue or 0) > 0
end

--Draws a panel that opens and closes like a dropdown list, for things that aren't a dropdown but open like one
--(the editor's level properties, say). It pops out of its top edge with a jelly and so does each row, one after
--another. owner keeps the animation, open says whether it's open, x, y, w, h is the panel (game pixels) and rows are
--{y = top, h = height, draw = function} in game pixels, nearest the header first.
--o: highlight (0-1) brightens the rim. Returns whether any of it is on screen.
function guielement.drawdroppanel(owner, open, x, y, w, h, rows, o)
	o = o or {}
	if not drop_timeline(owner, open, #rows) then
		return false
	end
	local psx, psy, palpha = drop_panelscale(owner, open)
	if psy <= 0.01 or palpha <= 0 then
		return true
	end
	local pcx = (x + w/2)*scale
	love.graphics.push()
	love.graphics.translate(pcx, y*scale)
	love.graphics.scale(psx, psy)
	love.graphics.translate(-pcx, -y*scale)

	local grey = lerp(127, 255, o.highlight or 0)
	guiglass.panel(x*scale, y*scale, w*scale, h*scale, math.min(11*scale*0.32, h*scale/2), {rim = {grey, grey, grey}, rimstrength = 0.6, alpha = palpha, tintstrength = 0.5})

	for i, row in ipairs(rows) do
		local rsx, rsy, ralpha = drop_rowscale(owner, open, i-1, #rows)
		if rsy > 0.01 and ralpha > 0 then
			local rcx, rcy = pcx, (row.y + row.h/2)*scale
			love.graphics.push()
			love.graphics.translate(rcx, rcy)
			love.graphics.scale(rsx, rsy)
			love.graphics.translate(-rcx, -rcy)
			row.draw()
			love.graphics.pop()
		end
	end
	love.graphics.pop()
	love.graphics.setColor(255, 255, 255)
	return true
end

local drawingopendropdowns = false

--an open dropdown is drawn later, on top of everything (guielement.drawopendropdowns), so it isn't drawn twice
local function dropdown_deferred(self)
	if drawingopendropdowns or not self.active or not guielements then
		return false
	end
	if not dropdown_timeline(self) then
		return false
	end
	for _, v in pairs(guielements) do
		if v == self then
			return true
		end
	end
	return false
end

function guielement:draw(a, offx, offy)
	love.graphics.setColor(255, 255, 255)
	if self.type == "checkbox" then
		local hovering = self:hovered()
		local mx, my = love.mouse.getPosition()
		local over = self:inhighlight(mx, my)
		local mix = hovermix(self, "hovermix", hovering)

		--the tick pops when it changes
		if self.lastvar == nil then
			self.lastvar = self.var
		elseif self.lastvar ~= self.var then
			self.lastvar = self.var
			self.scaleanim = gui_anim_start(0.6, 1)
		end
		local ticks = 1
		if self.scaleanim then
			local v, done = gui_anim_value(self.scaleanim)
			if done then
				self.scaleanim = nil
			else
				ticks = math.max(v, 0)
			end
		end

		local size = 9*scale
		local cx, cy = (self.x + 4.5)*scale, (self.y + 4.5)*scale
		guiglass.push(self, cx, cy, size, size, over, {hoverscale = 1.12})

		local rim = lerpcolor({127, 127, 127}, {255, 255, 255}, mix)
		local tint = {0, 0, 0}
		if self.var then
			tint = {40, 40, 40}
		end
		guiglass.panel(self.x*scale, self.y*scale, size, size, size*0.3, {tint = tint, rim = rim, rimstrength = lerp(0.45, 0.95, mix)})

		--tickmark when checked
		if self.var then
			love.graphics.push()
			love.graphics.translate(cx, cy)
			love.graphics.scale(ticks, ticks)
			love.graphics.translate(-4.5*scale, -4.5*scale)
			love.graphics.setColor(255, 255, 255)
			love.graphics.setLineWidth(scale)
			love.graphics.setLineStyle("smooth")
			love.graphics.line(2.2*scale, 4.5*scale, 4*scale, 6.5*scale)
			love.graphics.line(4*scale, 6.5*scale, 7*scale, 2.5*scale)
			local tr = scale/2
			love.graphics.circle("fill", 2.2*scale, 4.5*scale, tr, 12)
			love.graphics.circle("fill", 4*scale, 6.5*scale, tr, 12)
			love.graphics.circle("fill", 7*scale, 2.5*scale, tr, 12)
			love.graphics.pop()
			love.graphics.setLineWidth(1)
		end

		guiglass.pop()

		if self.text then
			love.graphics.setColor(255, 255, 255)
			properprintF(self.text, (self.x+10)*scale, (self.y+1)*scale)
		end
	elseif self.type == "dropdown" then
		if dropdown_deferred(self) then
			love.graphics.setColor(255, 255, 255)
			return
		end
		local listvisible = dropdown_timeline(self)
		local st = guiglass.state(self)
		local now = love.timer.getTime()
		local dt = framedt(st, "listlast")

		local high = self:inhighlight(love.mouse.getPosition())
		local rawhigh = high
		if self.extended and self.keycursor then
			high = self.keycursor --highlight the option picked with the keyboard
		end
		if not high and self.forcehover and not self.nohover then
			high = 0 --looks hovered without a highlighted option
		end

		local mix = hovermix(self, "bordermix", high)
		local bordergrey = lerp(127, 255, mix)

		local p = self:getlistprogress()
		local rowh = dropdown_rowheight(self)
		local headh = dropdown_headerheight(self)
		local listheight = dropdown_listheight(self)
		local listtop = self.y+headh
		local fullw = 13+self.width*8

		--the header: one glass capsule with the arrow at its right end
		local hw, hh = fullw*scale, headh*scale
		local hr = hh*0.32
		local headerover = rawhigh == true or rawhigh == 0
		local hcx, hcy = self.x*scale + hw/2, self.y*scale + hh/2
		guiglass.push(self, hcx, hcy, hw, hh, headerover, {nomagnet = self.extended})
		guiglass.panel(self.x*scale, self.y*scale, hw, hh, hr, {rim = {bordergrey, bordergrey, bordergrey}, rimstrength = lerp(0.45, 0.95, mix)})

		--a thin divider before the arrow
		love.graphics.setColor(255, 255, 255, 45 + 50*mix)
		love.graphics.rectangle("fill", (self.x + 2 + self.width*8)*scale, (self.y + 2)*scale, math.max(1, scale*0.5), (headh-4)*scale)

		--the arrow turns over as the list opens
		love.graphics.setColor(bordergrey, bordergrey, bordergrey)
		local arrowchar = "↓"
		if self.dropup then
			arrowchar = "↑"
		end
		local ax = (self.x + 3 + self.width*8)*scale
		local ay = (self.y + 2 + math.floor((headh-11)/2))*scale
		love.graphics.push()
		love.graphics.translate(ax + 4*scale, ay + 4*scale)
		love.graphics.rotate(math.pi*p)
		properprintF(arrowchar, -4*scale, -4*scale)
		love.graphics.pop()

		--the option shown in the header
		local function drawheader(var)
			local s = self.entries[var]
			if self.drawentryfunc then
				drawgraphicalentry(self, var, self.x+1, self.y+1, 1+self.width*8, headh-2, false, true)
			else
				if self.extended then
					love.graphics.setColor(127, 127, 127)
				elseif getdropdownentrycolor(self, var) then
					love.graphics.setColor(getdropdownentrycolor(self, var))
				elseif self.coloredtext then
					if s == "black" then
						love.graphics.setColor(80, 80, 80)
					else
						love.graphics.setColor(textcolors[s])
					end
				else
					love.graphics.setColor(255, 255, 255)
				end

				if self.displayentries then s = self.displayentries[var] end
				drawdropdownentry(s, self.x+1, self.y+2, self.width, self.width*8) --in the middle of the part left of the divider
			end
		end

		--a new option picked without the mouse (keys, a controller, or something else changing it) slides in sideways and
		--pushes the old one out, easing out: from the right when it's further down the list, from the left when it's further up
		if self.headervar == nil or self.headerentries ~= self.entries or not self.entries[self.headervar] then
			self.headeranim = nil --first draw, or the list itself changed
		elseif self.var ~= self.headervar then
			if self.mousepicked and now - self.mousepicked < 0.5 then
				self.headeranim = nil
			else
				local n = #self.entries
				local direction = 1
				if self.var < self.headervar then
					direction = -1
				end
				--going past either end wraps around, so it keeps going the way it was going
				if n > 2 and self.headervar == n and self.var == 1 then
					direction = 1
				elseif n > 2 and self.headervar == 1 and self.var == n then
					direction = -1
				end
				self.headeranim = {from = self.headervar, direction = direction, start = now}
			end
		end
		self.headervar, self.headerentries = self.var, self.entries
		self.mousepicked = nil

		local anim = self.headeranim
		local t = 1
		if anim then
			t = (now - anim.start)/GUI_ANIM_TIME
		end
		if anim and t < 1 and self.entries[anim.from] then
			local ep = ease_out_quad(t)
			local w = 1+self.width*8
			--cut to the header's text area, wherever the current transform puts it
			local sx1, sy1 = love.graphics.transformPoint((self.x+1)*scale, (self.y+1)*scale)
			local sx2, sy2 = love.graphics.transformPoint((self.x+1+w)*scale, (self.y+headh-1)*scale)
			local ox, oy, ow, oh = love.graphics.getScissor()
			love.graphics.intersectScissor(math.floor(math.min(sx1, sx2)), math.floor(math.min(sy1, sy2)), math.max(0, math.ceil(math.abs(sx2-sx1))), math.max(0, math.ceil(math.abs(sy2-sy1))))
			love.graphics.push()
			love.graphics.translate(-anim.direction*ep*w*scale, 0)
			drawheader(anim.from)
			love.graphics.pop()
			love.graphics.push()
			love.graphics.translate(anim.direction*(1-ep)*w*scale, 0)
			drawheader(self.var)
			love.graphics.pop()
			if ox then
				love.graphics.setScissor(ox, oy, ow, oh)
			else
				love.graphics.setScissor()
			end
		else
			self.headeranim = nil
			drawheader(self.var)
		end
		guiglass.pop()

		if listvisible then
			--where the list panel sits, and the edge it grows out of
			local panely, panelh, pivoty
			if self.cutoff then
				panely, panelh = -self.scroll, headh+listheight
				pivoty = self.y + headh/2
			elseif self.dropup then
				panely, panelh = self.y-listheight, listheight
				pivoty = self.y
			else
				panely, panelh = listtop, listheight
				pivoty = listtop
			end
			local firstrowtop --top of the first row of options
			if self.cutoff then
				firstrowtop = headh - self.scroll
			else
				firstrowtop = panely
			end
			local rows = dropdown_rows(self)
			local panelsx, panelsy, panelalpha = drop_panelscale(self, self.extended)

			--how far an option is from the header, in rows
			local function rowdistance(row)
				if self.dropup then
					return rows - row
				end
				return row - 1
			end

			local function optionscale(row)
				return drop_rowscale(self, self.extended, rowdistance(row), rows)
			end

			if panelsy > 0.01 and panelalpha > 0 then
				local pcx = (self.x + fullw/2)*scale
				love.graphics.push()
				love.graphics.translate(pcx, pivoty*scale)
				love.graphics.scale(panelsx, panelsy)
				love.graphics.translate(-pcx, -pivoty*scale)

				local pr = math.min(headh*scale*0.32, panelh*scale/2)
				guiglass.panel(self.x*scale, panely*scale, fullw*scale, panelh*scale, pr, {rim = {bordergrey, bordergrey, bordergrey}, rimstrength = 0.6, alpha = panelalpha, tintstrength = 0.5})

				--a long list repeats the header at its top
				if self.cutoff then
					love.graphics.setColor(bordergrey, bordergrey, bordergrey, 255*panelalpha)
					local cax = (self.x+2+self.width*8+4)*scale
					local cay = (-self.scroll+headh/2)*scale
					love.graphics.polygon("fill", cax-3*scale, cay+2*scale, cax+3*scale, cay+2*scale, cax, cay-3*scale)
					if self.drawentryfunc then
						drawgraphicalentry(self, self.var, self.x+1, -self.scroll+1, 1+self.width*8, headh-2, false, true)
					else
						love.graphics.setColor(127, 127, 127, 255*panelalpha)
						local selected = self.entries[self.var]
						if self.displayentries then selected = self.displayentries[self.var] end
						drawdropdownentry(selected, self.x+1, -self.scroll+2, self.width, self.width*8)
					end
					love.graphics.setColor(255, 255, 255, 40*panelalpha)
					love.graphics.rectangle("fill", (self.x+3)*scale, (headh-self.scroll-1)*scale, (fullw-6)*scale, math.max(1, scale*0.5))
				end

				--the hovered option's pill glides between options
				local target
				if type(high) == "number" and high > 0 and self.entries[high] then
					local column, row = dropdown_cell(self, high)
					local cx, cw = dropdown_columnspan(self, column)
					target = {cx*scale, (firstrowtop+(row-1)*rowh)*scale, cw*scale, (rowh-1)*scale}
				end
				local pill = glidepill(st, "pill", target, dt)
				if pill.a > 0.01 and pill.x then
					guiglass.pill(pill.x, pill.y, pill.w, pill.h, math.min(pill.h*0.4, pr), {255, 255, 255, 70}, 0.45, pill.a*panelalpha)
				end

				for i = 1, #self.entries do
					local column, row = dropdown_cell(self, i)
					local boxtop = firstrowtop+(row-1)*rowh
					if boxtop+rowh > 0 and boxtop < height*16 then
						local cx, cw = dropdown_columnspan(self, column)
						local osx, osy, oalpha = optionscale(row)
						if osy > 0.01 and oalpha > 0 then
							local ocx, ocy = (cx + cw/2)*scale, (boxtop + (rowh-1)/2)*scale
							love.graphics.push()
							love.graphics.translate(ocx, ocy)
							love.graphics.scale(osx, osy)
							love.graphics.translate(-ocx, -ocy)
							local highlighted = (high == i)
							if self.drawentryfunc then
								drawgraphicalentry(self, i, cx, boxtop, cw, rowh-1, highlighted, false)
							else
								local s = self.entries[i]
								setdropdownentrycolor(self, s, i)
								local r, g, b = love.graphics.getColor()
								love.graphics.setColor(r, g, b, 255*oalpha*panelalpha)
								if self.displayentries then s = self.displayentries[i] end
								drawdropdownentry(s, cx, boxtop+1, self.width+1, cw)
							end
							love.graphics.pop()
						end
					end
				end

				if self.cutoff and self.scrollbar then
					self.scrollbar:draw()
				end
				love.graphics.pop()
			end
		end
	elseif self.type == "rightclick" then
		local high = self:inhighlight(love.mouse.getPosition())
		local st = guiglass.state(self)
		local now = love.timer.getTime()
		local dt = framedt(st, "listlast")
		if not st.born then
			st.born = now
		end
		local t = now - st.born
		local n = #self.entries
		local w = 3+self.width*8

		local top, bottom, pivoty
		if self.direction == "down" then
			top, bottom = self.y, self.y+11+10*(n-1)
			pivoty = self.y
		else
			top, bottom = self.y+10-n*10, self.y+11
			pivoty = bottom
		end

		--pops out of the corner it was opened at, with a jelly
		local sy = guiglass.jellyin(t*1.2)
		local sx = guiglass.jellyin(t*1.2 - 0.03)
		local alpha = math.max(0, math.min(1, t*12))
		if st.closing then
			--closing (see closeanimated): swells a little, then shrinks back into the same corner, the width a moment after
			--the height, the way it came out
			local u = (now - st.closing)/RIGHTCLICK_CLOSETIME
			local closesy = guiglass.jellyout(u)
			local closesx = guiglass.jellyout(u - 0.15)
			sy = math.min(sy, closesy)
			sx = math.min(sx, closesx)
			alpha = alpha*math.max(0, math.min(1, (1-u)*3))
			high = nil --nothing is hovered on the way out
		end
		if sx > 0.01 and sy > 0.01 then
			love.graphics.push()
			love.graphics.translate(self.x*scale, pivoty*scale)
			love.graphics.scale(sx, sy)
			love.graphics.translate(-self.x*scale, -pivoty*scale)

			local r = 11*scale*0.32
			guiglass.panel(self.x*scale, top*scale, w*scale, (bottom-top)*scale, r, {rim = {255, 255, 255}, rimstrength = 0.6, alpha = alpha, tintstrength = 0.5})

			--title
			--a centred menu (centerentries) draws its title and options in the middle of their rows
			local function entryx(text)
				if self.centerentries then
					local len = utf8.len(tostring(text)) or string.len(tostring(text))
					return self.x + (w - len*8)/2
				end
				return self.x+1
			end

			love.graphics.setColor(180, 180, 180, 255*alpha)
			properprint(self.entries[1], entryx(self.entries[1])*scale, (self.y+2)*scale)
			love.graphics.setColor(255, 255, 255, 40*alpha)
			if self.direction == "down" then
				love.graphics.rectangle("fill", (self.x+2)*scale, (self.y+10.5)*scale, (w-4)*scale, math.max(1, scale*0.5))
			else
				love.graphics.rectangle("fill", (self.x+2)*scale, self.y*scale, (w-4)*scale, math.max(1, scale*0.5))
			end

			local function rowtop(i)
				if self.direction == "down" then
					return self.y+1+10*(i-1)
				end
				return self.y+1-10*(i-1)
			end

			--the picked one is green, the hovered one has a pill that glides
			for i = 2, n do
				if ((not self.trustWhatStartWasSetAs) and self.var == self.entries[i]) or (self.trustWhatStartWasSetAs and i == self.var) then
					guiglass.pill((self.x+1)*scale, rowtop(i)*scale, (w-2)*scale, 9*scale, 3*scale, {0, 170, 0, 110}, 0.3, alpha)
				end
			end
			local target
			if type(high) == "number" and high > 1 then
				target = {(self.x+1)*scale, rowtop(high)*scale, (w-2)*scale, 9*scale}
			end
			local pill = glidepill(st, "pill", target, dt)
			if pill.a > 0.01 and pill.x then
				guiglass.pill(pill.x, pill.y, pill.w, pill.h, 3*scale, {255, 255, 255, 70}, 0.45, pill.a*alpha)
			end

			love.graphics.setColor(255, 255, 255, 255*alpha)
			for i = 2, n do
				properprint(self.entries[i], entryx(self.entries[i])*scale, (rowtop(i)+1)*scale)
			end
			love.graphics.pop()
		end
	elseif self.type == "button" then
		local alpha = a or 255
		local high = self:hovered()
		local over = self:inhighlight(love.mouse.getPosition())
		local mix = hovermix(self, "hovermix", high)

		local bw = (3+self.width+self.space*2)*scale
		local bh = (1+self.height*10+self.space*2)*scale
		local br = math.min(bw, bh)*0.3
		local cx, cy = self.x*scale + bw/2, self.y*scale + bh/2
		guiglass.push(self, cx, cy, bw, bh, over, {hoverscale = 1.03})

		guiglass.panel(self.x*scale, self.y*scale, bw, bh, br, {
			tint = self.fillcolor,
			tintstrength = self.tintstrength, --nil: the usual glass
			solid = self.solidtint,           --true: the fill colour shows as it is (colour swatches)
			rim = lerpcolor(self.bordercolor, self.bordercolorhigh, mix),
			rimstrength = lerp(0.45, 0.95, mix),
			alpha = alpha/255,
		})

		--a button that opens something like a dropdown (droparrow returns how far it's open, 0-1) ends with a divider
		--and an arrow that turns over as it opens, like a dropdown's header
		if self.droparrow then
			local right = self.x + 3 + self.width + self.space*2
			local grey = lerp(127, 255, mix)
			love.graphics.setColor(255, 255, 255, (45 + 50*mix)*alpha/255)
			love.graphics.rectangle("fill", (right-11)*scale, (self.y+2)*scale, math.max(1, scale*0.5), bh-4*scale)
			love.graphics.setColor(grey, grey, grey, alpha)
			love.graphics.push()
			love.graphics.translate((right-5.5)*scale, cy)
			love.graphics.rotate(math.pi*self.droparrow())
			properprintF("↓", -4*scale, -4*scale)
			love.graphics.pop()
		end

		--a button can draw its own content inside the box (a mappack frame, say): drawcontent(self, x, y, alpha) in game pixels
		if self.drawcontent then
			self:drawcontent(self.x, self.y, alpha)
		end

		if self.image then
			if self.imagecolor then
				love.graphics.setColor(self.imagecolor[1], self.imagecolor[2], self.imagecolor[3], alpha)
			else
				love.graphics.setColor(255,255,255,alpha)
			end
			love.graphics.draw(self.image, (self.x+self.imageoffsetx)*scale, (self.y+self.imageoffsety)*scale, 0, scale, scale)
		end

		love.graphics.setColor(self.textcolor[1], self.textcolor[2], self.textcolor[3], alpha)
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

		guiglass.pop()
	elseif self.type == "scrollbar" then
		local high = self:inhighlight(love.mouse.getPosition())
		local handleround = 0.5
		if self.buttonround then
			handleround = 0.3
		end

		if self.dir == "ver" then
			local tw, th = self.width*scale, (self.yrange+self.height)*scale
			guiglass.panel(self.x*scale, self.y*scale, tw, th, math.min(tw, th)*0.5, {tint = self.backgroundcolor, tintstrength = 0.25, rimstrength = 0.25, shadow = false, base = true})

			self:setsliderbordercolor(self.dragging or high or self.inputting or (self.forcehover and not self.nohover))
			local rimr, rimg, rimb = love.graphics.getColor()
			local mix = self.bordermix or 0

			local sw, sh = self.width*scale, self.height*scale
			local hx, hy = self.x*scale, (self.y+self.yrange*self.value)*scale
			guiglass.push(self, hx + sw/2, hy + sh/2, sw, sh, high, {nomagnet = self.dragging})
			guiglass.panel(hx, hy, sw, sh, math.min(sw, sh)*handleround, {tint = self.fillcolor, rim = {rimr, rimg, rimb}, rimstrength = lerp(0.5, 0.95, mix)})
			guiglass.pop()
		else
			local tw, th = (self.xrange+self.width)*scale, self.height*scale
			local tr = self:sliderradius() --the track is rounded like its handle
			if self.drawtrack then
				--a slider can paint its own track (a colour gradient, say): drawtrack(self, x, y, w, h, radius) in screen pixels
				self:drawtrack(self.x*scale, self.y*scale, tw, th, tr)
			else
				guiglass.panel(self.x*scale, self.y*scale, tw, th, math.min(tw, th)*handleround, {tint = self.backgroundcolor, tintstrength = 0.25, rimstrength = 0.25, shadow = false, base = true})
			end

			self:setsliderbordercolor(self.dragging or high or self.inputting or (self.forcehover and not self.nohover))
			local rimr, rimg, rimb = love.graphics.getColor()
			local mix = self.bordermix or 0

			local sw, sh = self.width*scale, self.height*scale
			local hx, hy = (self.x+self.xrange*self.value)*scale, self.y*scale
			guiglass.push(self, hx + sw/2, hy + sh/2, sw, sh, high, {nomagnet = self.dragging})
			guiglass.panel(hx, hy, sw, sh, math.min(sw, sh)*handleround, {tint = self.fillcolor, rim = {rimr, rimg, rimb}, rimstrength = lerp(0.5, 0.95, mix)})

			if self.displayfunction or self.inputting then
				love.graphics.setColor(self.bordercolorhigh)
				local s
				if self.inputting then
					s = self.textvalue
				else
					s = self:displayfunction(self.value)
				end
				local textx = self.x+self.xrange*self.value
				local column --where the typing cursor is, in characters (it glides, so it can be between two)
				if self.inputting then
					column = self:smoothcursor(string.len(self.textvalue), 1)
				end
				if self.centerdisplay then
					--the value sits in the middle of the handle. While typing it stays in the middle too,
					--gliding with the cursor (which is always at the end) instead of jumping half a character per key
					if self.inputting then
						textx = textx + (self.width - column*8)/2
					else
						textx = textx + math.floor((self.width-utf8.len(tostring(s))*8)/2)
					end
				end
				properprint(s, textx*scale, (self.y+math.ceil((self.height-8)/2))*scale)

				--cursor: fades and glides like a text input's
				if self.inputting then
					if self.cursoralpha and self.cursoralpha > 0 then
						love.graphics.setColor(255, 255, 255, self.cursoralpha * 255)
						love.graphics.rectangle("fill", (textx+column*8)*scale, (self.y+math.ceil((self.height-8)/2)-1)*scale, 2*scale, 9*scale)
					end
				end
			end
			if not self.inputting then
				--next time typing starts, the cursor starts where it is without gliding
				self.cursortx = nil
				self.cursoranim = nil
			end

			guiglass.pop()
		end
	elseif self.type == "input" then
		if self.width >= self.maxlength or self.height > 1 then
			self.textoffset = 0
		end
		local high = self:inhighlight(love.mouse.getPosition())
		local mix = hovermix(self, "bordermix", self.inputting or high)

		local iw = (3+self.width*8+2*self.spacing)*scale
		local ih = (1+self.height*10+2*self.spacing)*scale
		guiglass.push(self, self.x*scale + iw/2, self.y*scale + ih/2, iw, ih, high, {nomagnet = self.highlighting or self.numdragging})

		if (not self.justdisplay) or self.inputting or high or mix > 0 then
			local panelalpha = 1
			if self.justdisplay then
				panelalpha = mix
			end
			local bc, bh = self.bordercolor, self.bordercolorhigh
			guiglass.panel(self.x*scale, self.y*scale, iw, ih, math.min(iw, ih)*0.3, {
				tint = self.fillcolor,
				rim = lerpcolor(bc, bh, mix),
				rimstrength = lerp(0.45, 0.95, mix)*lerp(bc[4] or 255, bh[4] or 255, mix)/255,
				alpha = panelalpha,
			})
		end
		love.graphics.setColor(self.textcolor)

		if self.height == 1 then
			if self.highlight then
				local highlight1,highlight2 = math.min(self.highlight,self.cursorpos),math.max(self.highlight,self.cursorpos)

				love.graphics.setColor((self.textcolor[1]-self.fillcolor[1])/2,(self.textcolor[2]-self.fillcolor[2])/2,(self.textcolor[3]-self.fillcolor[3])/2)
				local x3, x4 = math.max(1, highlight1 - self.textoffset), math.min(self.width+1, highlight2 - self.textoffset)
				love.graphics.rectangle("fill", (self.x+2+self.spacing+(x3-1)*8)*scale, (self.y+1+self.spacing)*scale, (x4-x3)*8*scale, 9*scale, scale)
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
			local oldstring = self.value
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
						love.graphics.rectangle("fill", (self.x+2+self.spacing+(x3-1)*8)*scale, (self.y+1+self.spacing+(i-1)*10)*scale, (x4-x3)*8*scale, 9*scale, scale)
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
				love.graphics.rectangle("fill", (self.x+1+self.spacing+(x-1)*8)*scale, (self.y+1+self.spacing+(y-1)*10)*scale, 2*scale, 9*scale, scale)
				love.graphics.setColor(self.textcolor)
			end
		else
			--next time the input is focused, the cursor starts at its position without gliding
			self.cursortx = nil
			self.cursoranim = nil
		end

		guiglass.pop()
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
				if (button == "wu" or button == "wd") and self.scrollbar then
					--the wheel scrolls a long list by as much as the wheel actually turned
					self:wheelscroll(button)
					return true
				end
				if self.scrollbar then
					self.scrollbar:click(x, y, button)
					if x > (self.x+(13+self.width*8))*scale and x < (self.x+(13+self.width*8)+8)*scale then
						return true
					end
				end
				
				if button ~= "wu" and button ~= "wd" then
					local high = self:inhighlight(x, y)
					self:close()
					
					if high then
						if high ~= 0 then
							self.mousepicked = love.timer.getTime() --picked with the mouse: the header doesn't slide (see the header slide in draw)
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
					if button == "r" then
						--right click anywhere on a slider to type its value (enter sets it, escape cancels)
						if self:isslider() and self:insidertrack(x, y) and not android then
							self:starttyping()
							return true
						elseif self.inputting then
							self:stoptyping()
						end
					else
						if self.inputting then
							self:stoptyping()
						end
						local ontrack = false
						if self.trackclick and button == "l" and not self:inhighlight(x, y) and self:insidertrack(x, y) then
							--clicking the track jumps the handle under the mouse and grabs it
							self.value = math.min(math.max((x/scale-self.x-self.width/2)/self.xrange, 0), 1)
							if self.updatefunc then
								self:updatefunc(self.value)
							end
							ontrack = true
						end
						if ontrack or self:inhighlight(x, y) then
							self.dragging = true
							self.draggingx = x-(self.x+self.xrange*self.value)*scale
							if self.buttonround then
								self.presszoomed = true
								self.presszoomanim = gui_anim_start(self.presszoom or 1, 0.85)
							end
						end
					end
				end
			end
			if not self.scrollstepdisabled and (button == "wd" or button == "wu") then
				self:wheelscrollbar(button) --slides there, like a dropdown's list
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

------------------------------------------------------------
-- text input editing keys
------------------------------------------------------------
--Ctrl+Left/Right, Ctrl+Backspace/Delete, Delete, Home/End and Ctrl+Home/End for inputs.
--Holding Shift with a movement key selects, the same as Shift+Left and Shift+Right.

--what kind of character this is for word jumps: spaces, word characters, or anything else
local function input_charclass(c)
	if c == "" or c:match("%s") then
		return 0
	elseif c:match("[%w_]") then
		return 1
	end
	return 2
end

--the position a word jump to the left lands on: skips spaces, then the word (or run of symbols) before them
local function input_wordleft(value, pos)
	local p = pos
	while p > 1 and input_charclass(value:sub(p-1, p-1)) == 0 do
		p = p - 1
	end
	if p > 1 then
		local class = input_charclass(value:sub(p-1, p-1))
		while p > 1 and input_charclass(value:sub(p-1, p-1)) == class do
			p = p - 1
		end
	end
	return p
end

--the position a word jump to the right lands on: skips the word (or run of symbols), then the spaces after it
local function input_wordright(value, pos)
	local len = string.len(value)
	local p = pos
	if p <= len then
		local class = input_charclass(value:sub(p, p))
		if class ~= 0 then
			while p <= len and input_charclass(value:sub(p, p)) == class do
				p = p + 1
			end
		end
	end
	while p <= len and input_charclass(value:sub(p, p)) == 0 do
		p = p + 1
	end
	return p
end

--keeps a one-line input scrolled so the cursor can be seen, and never past the end of the text
local function input_keepcursorvisible(self)
	if self.height > 1 then
		return
	end
	local len = string.len(self.value)
	self.textoffset = math.max(math.min(self.cursorpos-1, self.textoffset), 0)
	self.textoffset = math.max(self.textoffset, self.cursorpos-self.width)
	self.textoffset = math.max(0, math.min(self.textoffset, len+1-self.width))
	if self.maxlength > 0 then
		self.textoffset = math.max(0, math.min(self.textoffset, self.maxlength-self.width))
	end
end

--moves the cursor to pos; with Shift held, the selection grows from where it was
local function input_movecursor(self, pos)
	if self.shift then
		self.highlight = self.highlight or self.cursorpos
	else
		self.highlight = false
	end
	self.cursorpos = math.max(1, math.min(string.len(self.value)+1, pos))
	if self.highlight == self.cursorpos then
		self.highlight = false
	end
	input_keepcursorvisible(self)
	self.timer = 0
	self.cursoralpha = 1
end

--removes the characters from a up to (not including) b
local function input_deleterange(self, a, b)
	if b <= a then
		return
	end
	self.value = string.sub(self.value, 1, a-1) .. string.sub(self.value, b)
	self.cursorpos = a
	self.highlight = false
	input_keepcursorvisible(self)
	self.timer = 0
	self.cursoralpha = 1
end

--removes the selected text, if there is any; returns true when it did
local function input_deleteselection(self)
	if self.highlight and self.highlight ~= self.cursorpos then
		input_deleterange(self, math.min(self.highlight, self.cursorpos), math.max(self.highlight, self.cursorpos))
		return true
	end
	self.highlight = false
	return false
end

--handles the editing keys; returns true when the key was one of them
local function input_editkey(self, key)
	local len = string.len(self.value)
	if key == "left" and self.ctrl then
		input_movecursor(self, input_wordleft(self.value, self.cursorpos))
	elseif key == "right" and self.ctrl then
		input_movecursor(self, input_wordright(self.value, self.cursorpos))
	elseif key == "home" then
		if self.ctrl or self.height == 1 then
			input_movecursor(self, 1)
		else
			--a tall input: the start of the row the cursor is on
			local row = math.floor((self.cursorpos-1)/self.width)
			input_movecursor(self, row*self.width+1)
		end
	elseif key == "end" then
		if self.ctrl or self.height == 1 then
			input_movecursor(self, len+1)
		else
			--a tall input: the end of the row the cursor is on (the next row starts one further)
			local row = math.min(math.floor((self.cursorpos-1)/self.width), math.max(0, math.floor(len/self.width)))
			local rowend = (row+1)*self.width
			if len+1 <= rowend then
				rowend = len+1
			end
			input_movecursor(self, rowend)
		end
	elseif key == "backspace" and self.ctrl then
		if not input_deleteselection(self) then
			input_deleterange(self, input_wordleft(self.value, self.cursorpos), self.cursorpos)
		end
	elseif key == "delete" then
		if not input_deleteselection(self) then
			if self.ctrl then
				input_deleterange(self, self.cursorpos, input_wordright(self.value, self.cursorpos))
			else
				input_deleterange(self, self.cursorpos, self.cursorpos+1)
			end
		end
	else
		return false
	end
	return true
end

function guielement:keypress(key,textinput)
	if self.active then
		if self.type == "dropdown" then
			--an open dropdown takes the up/down/enter keys: up and down move the highlighted option, enter sets it
			if self.extended and not textinput then
				local columns = dropdown_columns(self)
				if columns > 1 and (key == "up" or key == "w" or key == "down" or key == "s" or key == "left" or key == "a" or key == "right" or key == "d") then
					--a grid: left and right go along a row, up and down along a column (both wrap around)
					local n = #self.entries
					local i = math.max(1, math.min(n, self:getdropdowncursor()))
					if key == "left" or key == "a" then
						i = i - 1
						if i < 1 then
							i = n
						end
					elseif key == "right" or key == "d" then
						i = i + 1
						if i > n then
							i = 1
						end
					else
						local column = dropdown_cell(self, i)
						local lastrow = math.floor((n-column)/columns)+1 --the column's last row
						local _, row = dropdown_cell(self, i)
						if key == "up" or key == "w" then
							row = row - 1
							if row < 1 then
								row = lastrow
							end
						else
							row = row + 1
							if row > lastrow then
								row = 1
							end
						end
						i = (row-1)*columns+column
					end
					self.keycursor = i
					self.keymouse = {love.mouse.getPosition()}
					self:scrolltocursor()
					return true
				elseif key == "up" or key == "w" or key == "down" or key == "s" then
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
					self:stoptyping()
				elseif (key == "return" or key == "enter" or key == "kpenter") then
					local newvalue = tonumber(self.textvalue)
					if newvalue then
						self.value = self:valuefornumber(newvalue)
						if self.updatefunc then
							self:updatefunc(self.value)
						end
						if self.releasefunc then
							self:releasefunc(self.value)
						end
					end
					self:stoptyping()
				elseif key == "backspace" then
					self.textvalue = string.sub(self.textvalue, 1, -2)
					self.timer = 0
				else
					if string.len(self.textvalue) < math.max(6, math.floor(self.width/8)) then
						if tonumber(key) or key == "-" or key == "." then
							self.textvalue = self.textvalue .. key
							self.cursorblink = true
							self.timer = 0
						end
					end
				end
				return true --the keys belong to the slider while typing
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
							if not self.inputting then
								typingintextinput = false
								love.keyboard.setKeyRepeat(false)
								if android then
									love.keyboard.setTextInput(false)--[DROID]
								end
							end
						end
					else
						self.inputting = false
						typingintextinput = false
						love.keyboard.setKeyRepeat(false)
						if android then
							love.keyboard.setTextInput(false)--[DROID]
						end
					end
				elseif input_editkey(self, key) then
					--Ctrl+Left/Right, Ctrl+Backspace/Delete, Delete, Home/End, Ctrl+Home/End (see input_editkey)
				elseif key == "left" then
					if self.shift then
						self.highlight = self.highlight or self.cursorpos
					else
						if self.highlight then
							self.cursorpos = math.min(self.cursorpos,self.highlight)+1
							self.highlight = false
						end
					end
					self.cursorpos = math.max(1, self.cursorpos - 1)
					--while self.cursorpos-1 < self.textoffset do
						self.textoffset = math.max(math.min(self.cursorpos-1, self.textoffset), 0)
					--end
				elseif key == "right" then
					if self.shift then
						self.highlight = self.highlight or self.cursorpos
					else
						if self.highlight then
							self.cursorpos = math.max(self.cursorpos,self.highlight)-1
							self.highlight = false
						end
					end

					self.cursorpos = math.min(string.len(self.value) + 1, self.cursorpos + 1)
					--while self.cursorpos-1 >= self.textoffset+self.width do
						self.textoffset = math.min(math.max(self.textoffset, self.cursorpos-self.width), self.maxlength - self.width)
					--end
				elseif key == "up" and self.height > 1 then
					if self.shift then
						self.highlight = self.highlight or self.cursorpos
					else
						self.highlight = false
					end

					self.cursorpos = math.max(1, self.cursorpos - self.width)
				elseif key == "down" and self.height > 1 then
					if self.shift then
						self.highlight = self.highlight or self.cursorpos
					else
						self.highlight = false
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
--how long a right-click menu takes to shrink away when closed with closeanimated (like a dropdown's options)
RIGHTCLICK_CLOSETIME = 0.2

--closes a right-click menu with an animation: it stops taking clicks straight away, but keeps being drawn
--(draw it while isclosing() is true) until it has shrunk back into the corner it opened from
function guielement:closeanimated()
	self.active = false
	local st = guiglass.state(self)
	if st.born and not st.closing then
		st.closing = love.timer.getTime()
	end
end

--true while a right-click menu closed with closeanimated is still shrinking away
function guielement:isclosing()
	local st = guiglass.state(self)
	if not st.closing then
		return false
	end
	if love.timer.getTime() - st.closing >= RIGHTCLICK_CLOSETIME then
		st.closing = nil
		st.born = nil
		return false
	end
	return true
end

--starts a right-click menu's opening animation over (its jelly pop and the hover pill), so a menu
--that is kept and opened again, like the Course Maker's maps tab menu, animates every time it opens
function guielement:resetanimation()
	local st = guiglass.state(self)
	st.born = nil
	st.listlast = nil
	st.pill = nil
	st.closing = nil
end

function guielement:hovered()
	local dropdown_open = opened_dropdown and opened_dropdown.active and opened_dropdown.extended
	local hover_only = editormode and dropdown_open and opened_dropdown ~= self and editor_gui_hover_enabled(self)
	if editormode and not self.alwaysinteractable and
		(not editor_gui_interaction_enabled(self) or (dropdown_open and opened_dropdown ~= self)) and not hover_only then
		return false
	end
	if self.forcehoveronly then
		--only looks hovered when it's the selected one (a list where the mouse and the arrow keys share one selection)
		return self.forcehover and not self.nohover
	end
	local x, y = love.mouse.getPosition()
	if self:inhighlight(x, y, hover_only) then
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
		self.y = self.multiy[1]
	end
	if opened_dropdown and opened_dropdown ~= self then
		opened_dropdown:close()
	end
	self:updatePos()
	self.extended = true
	opened_dropdown = self
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

--dropdown: colours for its entries ({[entry number] = {r, g, b}, ...}, nil for none)
function guielement:setentrycolors(colors)
	self.entrycolors = colors
end

--dropdown: make it graphical. Its entries are drawn by drawfunc(self, i, x, y, w, h, highlighted, header)
--into the box x, y, w, h (game pixels) instead of printed, its rows are rowheight pixels tall (10 by default)
--and its list is laid out in a grid of columns (1 by default). The header is a row tall plus a pixel.
function guielement:setentrydrawing(drawfunc, rowheight, columns)
	if self.type ~= "dropdown" then
		return
	end
	self.drawentryfunc = drawfunc
	self.rowheight = rowheight
	self.columns = columns
	--work the layout out again for the new size
	if self.multiy then
		self.y = self.multiy[1]
	end
	self.cutoff = false
	self.scrollbar = nil
	self:updatePos()
end

--dropdown: change its entries (and the current one), working the layout out again
function guielement:setentries(entries, var)
	if self.type ~= "dropdown" then
		return
	end
	self.entries = entries
	self.var = var or math.min(self.var, #entries)
	if self.multiy then
		self.y = self.multiy[1]
	end
	self.cutoff = false
	self.scrollbar = nil
	self:updatePos()
end

--dropdown: scroll a long (cut off) list with the mouse wheel, the way a web browser does (Chromium's wheel scrolling):
--every notch moves the target DROPDOWN_WHEEL_PIXELS screen pixels (times how far the wheel turned, mousewheelamount,
--so a fine scrolling wheel or a touchpad moves it a little), and the list slides there on an ease-in-out curve,
--cubic-bezier(0.42, 0, 0.58, 1), that takes sqrt(distance in screen pixels)/60 seconds, at most 0.2.
--a notch that comes in while the list is still sliding moves the target further and the slide carries on
--from the speed it has, instead of starting again from a standstill
DROPDOWN_WHEEL_PIXELS = 100 --screen pixels per notch, what browsers on windows scroll by
local WHEEL_DURATION_DIVISOR = 60
local WHEEL_DURATION_MAX = 12 --sqrt(distance) is capped at this before dividing, so a slide is 0.2 s at most

--y of a cubic-bezier(x1, y1, x2, y2) timing curve at x (0-1)
local function cubicbezier(x1, y1, x2, y2, x)
	local function bez(a, b, t)
		return 3*a*t*(1-t)^2 + 3*b*t^2*(1-t) + t^3
	end
	--find the curve's t for this x: newton first, bisection if it doesn't settle
	local t = x
	for _ = 1, 8 do
		local err = bez(x1, x2, t) - x
		if math.abs(err) < 1e-6 then
			return bez(y1, y2, t)
		end
		local slope = 3*x1*(1-t)^2 + 6*(x2-x1)*t*(1-t) + 3*(1-x2)*t^2
		if math.abs(slope) < 1e-6 then
			break
		end
		t = t - err/slope
	end
	local lo, hi = 0, 1
	t = x
	for _ = 1, 30 do
		local v = bez(x1, x2, t)
		if math.abs(v-x) < 1e-6 then
			break
		end
		if v < x then
			lo = t
		else
			hi = t
		end
		t = (lo+hi)/2
	end
	return bez(y1, y2, t)
end

--where a wheel slide is at time now (game pixels), and whether it has finished
function gui_wheelanimposition(anim, now)
	local t = (now - anim.start)/anim.duration
	if t >= 1 then
		return anim.to, true
	end
	t = math.max(0, t)
	return anim.from + (anim.to-anim.from)*cubicbezier(0.42, anim.y1, 0.58, 1, t), false
end

--how long a slide over this many game pixels takes
local function wheelduration(distance)
	return math.min(math.sqrt(math.abs(distance)*scale), WHEEL_DURATION_MAX)/WHEEL_DURATION_DIVISOR
end

function guielement:wheelscroll(button)
	if not (self.cutoff and self.scrollbar) then
		return
	end
	local range = dropdown_scrollrange(self)
	if range <= 0 then
		return
	end
	local pixels = (mousewheelamount or 1)*DROPDOWN_WHEEL_PIXELS/scale --screen pixels to game pixels
	if button == "wu" then
		pixels = -pixels
	end
	local now = love.timer.getTime()
	local anim = self.wheelanim
	local current = self.scroll or 0
	local velocity = 0 --game pixels per second
	if anim then
		local a = gui_wheelanimposition(anim, now - 0.001)
		local b = gui_wheelanimposition(anim, now)
		current = b
		velocity = (b-a)/0.001
	end
	local target = math.max(0, math.min(range, ((anim and anim.to) or current) + pixels))
	local delta = target - current
	if math.abs(delta) < 0.01 then
		return --already at the end
	end
	local duration = wheelduration(delta)
	--the curve's first control point is tilted so the slide starts at the speed it already had
	local slope = velocity*duration/delta
	slope = math.max(-1000, math.min(1000, slope))
	self.wheelanim = {from = current, to = target, start = now, duration = duration, y1 = 0.42*slope}
	self.keycursor = nil --the hovered option takes over again
end

--scrollbar: the mouse wheel slides it the same way a dropdown's list slides (see wheelscroll above). A scrollbar with
--a scrollstep moves through 73/scrollstep game pixels (that's how the editor sets it up for its lists), so a notch
--moves DROPDOWN_WHEEL_PIXELS screen pixels of that, like a dropdown. One without a scrollstep moves 0.2 a notch.
function guielement:wheelscrollbar(button)
	local step = self.scrollstep or 0.2
	if step <= 0 then
		return --a slider that the wheel doesn't move
	end
	local content = 73/step --game pixels the whole bar scrolls through
	local amount = mousewheelamount or 1
	local dv
	if self.scrollstep then
		dv = amount*DROPDOWN_WHEEL_PIXELS/scale/content
	else
		dv = amount*step
	end
	if button == "wu" then
		dv = -dv
	end
	local now = love.timer.getTime()
	local anim = self.wheelanim
	if anim and self.value ~= self.wheelvalue then
		anim = nil --something else moved it since
	end
	local current = self.value
	local velocity = 0 --value per second
	if anim then
		local a = gui_wheelanimposition(anim, now - 0.001)
		local b = gui_wheelanimposition(anim, now)
		current = b
		velocity = (b-a)/0.001
	end
	local target = math.max(0, math.min(1, ((anim and anim.to) or current) + dv))
	local delta = target - current
	if math.abs(delta) < 1e-6 then
		return --already at the end
	end
	local duration = wheelduration(delta*content)
	local slope = velocity*duration/delta
	slope = math.max(-1000, math.min(1000, slope))
	self.wheelanim = {from = current, to = target, start = now, duration = duration, y1 = 0.42*slope}
	self.wheelvalue = self.value
end

--dropdown: close the list without picking anything
function guielement:close()
	if self.type ~= "dropdown" then
		return
	end
	self.extended = false
	if opened_dropdown == self then
		opened_dropdown = false
	end
	self.keycursor = nil
	self.wheelanim = nil
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
		local range = dropdown_scrollrange(self)
		local _, row = dropdown_cell(self, self.keycursor)
		local top = dropdown_headerheight(self)-1 + (row-1)*dropdown_rowheight(self)
		local bottom = top + dropdown_rowheight(self) + 1
		local scroll = self.scroll or 0
		if top < scroll then
			scroll = top
		elseif bottom > scroll + height*16 then
			scroll = bottom - height*16
		end
		self.scrollbar.value = math.max(0, math.min(1, scroll/range))
		self.scroll = self.scrollbar.value*range
		self.wheelanim = nil --the keyboard jumps straight there
	end
end

--returns the dropdown that is currently open (or false), so other code can tell when keys belong to it
function guielement.getopendropdown()
	if opened_dropdown and opened_dropdown.active and opened_dropdown.extended then
		return opened_dropdown
	end
	return false
end

-- draw every open / still-animating dropdown on top of the rest of the game
-- (called from lovedraw after notice.draw, before FPS / battery / time overlays)
function guielement.drawopendropdowns()
	drawingopendropdowns = true
	for _, v in pairs(guielements) do
		if v.type == "dropdown" and v.active and dropdown_timeline(v) then
			v:draw()
		end
	end
	drawingopendropdowns = false
end

function guielement:getlistprogress()
	local target = bool2int(self.extended)
	if target ~= self.listtarget then
		self.listanim = gui_anim_start(self.listvalue, target)
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
		self.cursoranim = {
			from = 0, to = 1,
			start = love.timer.getTime()
		}
		self.cursortx, self.cursorty = x, y
	end
	
	if self.cursoranim then
		local t = (love.timer.getTime() - self.cursoranim.start) / CURSOR_ANIM_TIME
		local p = ease_in_out_quad(t)
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

function guielement:inhighlight(x, y, allow_dropdown_hover)
	local dropdown_open = opened_dropdown and opened_dropdown.active and opened_dropdown.extended
	local hover_only = editormode and allow_dropdown_hover and dropdown_open and opened_dropdown ~= self and editor_gui_hover_enabled(self)
	if editormode and not self.alwaysinteractable and
		(not editor_gui_interaction_enabled(self) or (dropdown_open and opened_dropdown ~= self)) and not hover_only then
		return false
	end
	--the element's real shape as it was drawn (leaning, grown on hover, squashed, round corners), or nil to use the
	--rectangle below (not drawn with glass lately, or the mouse is moved into another space first)
	local shapehit
	if (self.controlbindpage or (self.controlspopup and gamestate == "game")) and optionscontrols_transformmouse then
		x, y = optionscontrols_transformmouse(x, y)
	elseif guiglass then
		shapehit = guiglass.hit(self, x, y)
	end
	if self.nohover then --e.g. the level properties panel while it is still sliding, or a menu on top of it
		return false
	end
	if self.type == "checkbox" then
		local xadd = 0
		if self.text then
			xadd = utf8.len(self.text)*8+1
		end
		if shapehit then
			return true --on the box
		end
		--the label (and the box, when there's no shape to go by)
		local left = self.x
		if shapehit == false then
			left = self.x+9
		end
		if x >= left*scale and x < (self.x+9+xadd)*scale and y >= self.y*scale and y < (self.y+9)*scale then
			return true
		end
	elseif self.type == "dropdown" then
		local headh = dropdown_headerheight(self)
		local listheight = dropdown_listheight(self)
		local inside = x >= self.x*scale and x < (self.x+13+self.width*8)*scale
		if self.extended == false then
			if shapehit ~= nil then
				return shapehit
			end
			if inside and y >= self.y*scale and y < (self.y+headh)*scale then
				return true
			end
		else
			--the header is 0, the list gives the entry under the mouse
			if self.cutoff then
				local top = -self.scroll
				if inside and y >= top*scale and y < (top+headh+listheight)*scale then
					local gy = y/scale-top
					if gy < headh then
						return 0
					end
					return dropdown_entryat(self, x/scale, gy-headh)
				end
			elseif self.dropup then
				local top = self.y-listheight
				if inside and y >= top*scale and y < (self.y+headh)*scale then
					if y >= self.y*scale then
						return 0
					end
					return dropdown_entryat(self, x/scale, y/scale-top)
				end
			else
				if inside and y >= self.y*scale and y < (self.y+headh+listheight)*scale then
					if y < (self.y+headh)*scale then
						return 0
					end
					return dropdown_entryat(self, x/scale, y/scale-(self.y+headh))
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
		if shapehit ~= nil then
			return shapehit
		end
		if x >= self.x*scale and x < (self.x+3+self.width+self.space*2)*scale and y >= self.y*scale and y < (self.y+1+self.height*10+self.space*2)*scale then
			return true
		end
	elseif self.type == "scrollbar" then
		if shapehit ~= nil then
			return shapehit --the handle
		end
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
		if shapehit ~= nil then
			return shapehit
		end
		if x >= self.x*scale and x < (self.x+3+self.width*8+2*self.spacing)*scale and y >= self.y*scale and y < (self.y+1+self.height*10+2*self.spacing)*scale then
			return true
		end
	end
	
	return false
end

------------------------------------------------------------
-- sliders (horizontal scrollbars)
------------------------------------------------------------

--sets the colour of a scrollbar's handle border: it fades between bordercolor and bordercolorhigh
--on a motion curve (like a dropdown's border) as the handle is hovered, dragged, typed into or selected
function guielement:setsliderbordercolor(highlighted)
	local target = bool2int(highlighted)
	if self.bordertarget == nil then
		self.bordertarget = target
		self.bordermix = target
	elseif target ~= self.bordertarget then
		self.bordertarget = target
		self.borderanim = gui_anim_start(self.bordermix, target)
	end
	if self.borderanim then
		local v, done = gui_anim_value(self.borderanim)
		self.bordermix = v
		if done then
			self.borderanim = nil
		end
	end
	local low, high, mix = self.bordercolor, self.bordercolorhigh, self.bordermix
	love.graphics.setColor(
		lerp(low[1], high[1], mix),
		lerp(low[2], high[2], mix),
		lerp(low[3], high[3], mix),
		lerp(low[4] or 255, high[4] or 255, mix)
	)
end

--corner radius of a scrollbar's handle; the track uses the same one
function guielement:sliderradius()
	local roundness = 0.25
	if self.buttonround then
		roundness = 0.15 --buttons use 0.15
	end
	return math.min(self.width, self.height)*scale*roundness
end

--a slider is a horizontal scrollbar that stands for a number; plain scrollbars (like the animation list's) only scroll
function guielement:isslider()
	if self.type ~= "scrollbar" or self.dir == "ver" or self.typeable == false then
		return false
	end
	if self.typeable then
		return true
	end
	if self.displayfunction or self.valuefunction or self.typefunc or self.rcrange or self.rightclickvalue then
		return true
	end
	return self.min ~= nil and self.max ~= nil
end

--like inhighlight, but anywhere on a horizontal slider's track instead of only on its handle
function guielement:insidertrack(x, y)
	local dropdown_open = opened_dropdown and opened_dropdown.active and opened_dropdown.extended
	if editormode and not self.alwaysinteractable and
		(not editor_gui_interaction_enabled(self) or (dropdown_open and opened_dropdown ~= self)) then
		return false
	end
	if (self.controlbindpage or (self.controlspopup and gamestate == "game")) and optionscontrols_transformmouse then
		x, y = optionscontrols_transformmouse(x, y)
	end
	if self.nohover then
		return false
	end
	return x >= self.x*scale and x < (self.x+self.xrange+self.width)*scale and y >= self.y*scale and y < (self.y+self.height)*scale
end

function guielement:starttyping()
	self.dragging = false
	self.inputting = true
	self.textvalue = self:currentnumbertext() --starts with the slider's value, the cursor at the end
	self.cursorblink = true
	self.timer = 0
	typingintextinput = true
	love.keyboard.setKeyRepeat(true)
end

function guielement:stoptyping()
	self.inputting = false
	typingintextinput = false
	love.keyboard.setKeyRepeat(false)
end

--the number a slider stands for at a position (0-1), or nil if it can't tell
function guielement:numberat(v)
	if self.valuefunction then
		return tonumber(self:valuefunction(v))
	elseif self.displayfunction then
		local s = tostring(self:displayfunction(v) or "")
		return tonumber(s) or tonumber(s:match("%-?%d+%.?%d*"))
	end
	return nil
end

--the slider's value as text to type over: what it shows, else its range, else a percentage
function guielement:currentnumbertext()
	local n = self:numberat(self.value)
	if n == nil then
		local min, max = self.min, self.max
		if not (min and max) and self.rcrange then
			min, max = self.rcrange[1], self.rcrange[2]
		end
		if min and max then
			n = min + self.value*(max-min)
		else
			n = self.value*100
		end
	end
	n = round(n, 2)
	if n == math.floor(n) then
		return string.format("%d", n)
	end
	return tostring(n)
end

--turns a typed number into a slider position (0-1)
--	typefunc(self, number):     the slider says how itself
--	min/max or rcrange:         a straight range
--	valuefunction/displayfunction: the closest position showing that number (works for curved scales too)
--	nothing:                    a percentage
function guielement:valuefornumber(n)
	if self.typefunc then
		return math.min(math.max(self:typefunc(n), 0), 1)
	end
	local min, max = self.min, self.max
	if not (min and max) and self.rcrange then
		min, max = self.rcrange[1], self.rcrange[2]
	end
	if min and max and max ~= min then
		n = math.min(math.max(n, math.min(min, max)), math.max(min, max))
		return (n-min)/(max-min)
	end
	if self:numberat(0) ~= nil then
		--find the positions that show the closest number, and take the middle of them
		local first, last, bestdistance = self.value, self.value, math.huge
		local steps = 2000
		for i = 0, steps do
			local v = i/steps
			local shown = self:numberat(v)
			if shown then
				local distance = math.abs(shown - n)
				if distance < bestdistance - 1e-9 then
					first, last, bestdistance = v, v, distance
				elseif math.abs(distance - bestdistance) <= 1e-9 and last == (i-1)/steps then
					last = v
				end
			end
		end
		return (first + last)/2
	end
	return math.min(math.max(n/100, 0), 1)
end

function guielement:updatePos()
	if self.type == "dropdown" then
		local fullheight = dropdown_headerheight(self)-1+dropdown_listheight(self) --10*(#self.entries+1) for a plain dropdown
		if fullheight > height*16 then
			local yrange = dropdown_scrollrange(self)
			self.cutoff = true
			self.scroll = 0
			self.wheelanim = nil
			self.scrollbar = guielement:new("scrollbar", self.x+(self.width*8+13), 0, height*16, 8, 40, 0, "ver")
			self.scrollbar.active = false
			self.scrollbar.yrange = self.scrollbar.yrange + self.scrollbar.height
			self.scrollbar.height = math.max(30, math.min(1, (height*16)/(yrange+(height*16)))*(height*16))
			self.scrollbar.yrange = self.scrollbar.yrange - self.scrollbar.height
			self.scrollbar.scrollstep = math.max(0.0001, 73/yrange)
		end
		if not self.cutoff and self.y+fullheight > height*16 then
			self.multiy = {self.y, height*16-fullheight}
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
--the mouse in the element's own coordinates (the controls page draws its elements moved, see inhighlight)
function guielement:mousepos()
	local x, y = love.mouse.getPosition()
	if (self.controlbindpage or (self.controlspopup and gamestate == "game")) and optionscontrols_transformmouse then
		x, y = optionscontrols_transformmouse(x, y)
	end
	return x, y
end

------------------------------------------------------------
-- liquid glass press and release (see guiglass.lua)
------------------------------------------------------------

--a click on an element squashes it wide until the mouse button comes up (wherever the mouse is), then it wobbles back
local guielement_click = guielement.click
function guielement:click(x, y, button)
	local pressed = false
	local wasdragging = self.dragging
	if self.active and button ~= "wu" and button ~= "wd" then
		local hit = self:inhighlight(x, y)
		if self.type == "dropdown" then
			--the header only: picking an option closes the list, which has its own jelly
			if hit == true or hit == 0 then
				pressed = true
			end
		elseif self.type ~= "rightclick" and self.type ~= "text" and hit then
			pressed = true
		end
	end
	local result = guielement_click(self, x, y, button)
	if self.type == "scrollbar" and self.dragging and not wasdragging then
		pressed = true --grabbed by clicking its track
	end
	if pressed then
		guiglass.press(self)
	end
	return result
end

local guielement_unclick = guielement.unclick
function guielement:unclick(x, y, ...)
	guiglass.release(self)
	return guielement_unclick(self, x, y, ...)
end