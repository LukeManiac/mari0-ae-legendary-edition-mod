--[[
	UTILS (title screen > utils)

	character formatter: splits a character's animation sheets into colour layers,
	                     written to alesans_entities/characters/<name>_formatted
	font renderer:       renders text with the current mappack's font (and its outline) to a png
	mappack creator:     makes a new mappack filled with blank courses and subzones

	Everything here lives in its own gamestate ("utils") and keeps its gui elements to itself,
	so nothing leaks into the global guielements table.
]]

local CHARFOLDER = "alesans_entities/characters"
local PROJECTFOLDER = "alesans_entities/mappackprojects"

--mappack creator process warnings: nothing is blocked, the creator only warns when a mappack
--would need at least this many course files (change these to taste)
MAPPACKCREATOR_FILEWARNING = 1000 --"this will take some time"
MAPPACKCREATOR_FILEWARNING_BIG = 10000 --"this will take a lot of time"
MAPPACKCREATOR_FILEWARNING_HUGE = 100000 --"this will take tons of time"
MAPPACKCREATOR_FILEWARNING_GOODGOD = 1000000 --"this will take MILLION TONS of time"
local RENDERFOLDER = "renders"

local PX, PY, PH = 21, 16, 200 --panel position and height (width follows the screen)

local function panelright()
	return width*16 - PX
end

local function panelwidth()
	return panelright() - PX
end

local page = "hub" --"hub", "charformat", "fontrender" or "mappack"
local hubselection = 1
local HUBITEMS = {
	{text = "character formatter", page = "charformat", info = "split a character's sheets into colour layers"},
	{text = "font renderer", page = "fontrender", info = "render text to a png with this mappack's font"},
	{text = "mappack creator", page = "mappack", info = "make a new mappack full of blank courses"},
	{text = "back", info = "back to the title screen"},
}

local elements = {} --{el = guielement, tab = mappack tab or nil}
local named = {}
local labels = {} --{x, y, text, tab}
local job --background work (coroutine), see startjob
local confirmuntil = {} --two-click buttons: name -> time the "click again" state runs out

local mptab = "general"
local MPTABS = {"general", "worlds", "hud", "text", "course", "create"}
local mpslide = {time = 0.25} --the mappack creator's tab slide: anim is {from, to, start, curve} while it slides (one table for the 200 locals limit)

local utils_back --forward declarations
local inner_utilsmenu_openpage
local mp_build

------------------------------------------------------------
-- helpers
------------------------------------------------------------

local function clamp(v, minimum, maximum)
	return math.max(minimum, math.min(maximum, v))
end

local ui = {mp = {}} --layout helpers (one table, the file is near lua's 200 locals limit)

--text in the current language: languages/<language>.json, falling back to english.json, then to the key itself
--(the keys are the english text, like the rest of the game)
local function T(key)
	if TEXT and TEXT[key] then
		return TEXT[key]
	end
	return key
end

--T with string.format, for text with %s in it
local function TF(key, ...)
	return string.format(T(key), ...)
end

--T on one line (some translations wrap with \n, which checkboxes can't do)
function ui.line(key)
	return (T(key):gsub("\n", " "))
end

--the first n characters of s, without cutting a utf-8 character in half like string.sub would
function ui.cut(s, n)
	local stop = utf8.offset(s, n + 1)
	if stop then
		return s:sub(1, stop - 1)
	end
	return s
end

--how wide a piece of text is in pixels
function ui.textw(s)
	return utf8.len(s)*8
end

--where a column of fields starts: after the longest label, but never left of minimum
function ui.columnx(minimum, ...)
	local longest = 0
	for _, s in ipairs({...}) do
		for line in (s .. "\n"):gmatch("(.-)\n") do
			longest = math.max(longest, utf8.len(line))
		end
	end
	return math.max(minimum, 26 + longest*8 + 6)
end

--how many extra lines a piece of text has (some translations wrap with \n)
function ui.extralines(s)
	local _, count = s:gsub("\n", "")
	return count
end

local function wraptext(s, maxchars)
	local lines = {}
	for paragraph in (s .. "\n"):gmatch("(.-)\n") do
		local line = ""
		for word in paragraph:gmatch("%S+") do
			if line == "" then
				line = word
			elseif utf8.len(line) + 1 + utf8.len(word) <= maxchars then
				line = line .. " " .. word
			else
				table.insert(lines, line)
				line = word
			end
		end
		table.insert(lines, line)
	end
	return lines
end

local function centredprint(s, cx, y)
	for i, line in ipairs(wraptext(s, 999)) do
		properprintF(line, (cx - utf8.len(line)*4)*scale, (y + (i-1)*10)*scale)
	end
end

local function numbertostring(n)
	if n == math.floor(n) then
		return string.format("%d", n)
	end
	return tostring(n)
end

local function tobool(value, default)
	if value == nil then
		return default
	end
	if type(value) == "boolean" then
		return value
	end
	local s = tostring(value):lower()
	return s == "true" or s == "t" or s == "yes" or s == "1"
end

local function readjson(path)
	local s = love.filesystem.read(path)
	if not s then
		return nil, TF("can't read %s", path)
	end
	local oldcrash = JSONcrashgame
	JSONcrashgame = false
	local ok, result = pcall(function() return JSON:decode(s) end)
	JSONcrashgame = oldcrash
	if not ok or type(result) ~= "table" then
		return nil, T("that json file has an error in it")
	end
	return result
end

local function copyfolder(src, dst)
	love.filesystem.createDirectory(dst)
	for _, file in ipairs(love.filesystem.getDirectoryItems(src)) do
		local from, to = src .. "/" .. file, dst .. "/" .. file
		local info = love.filesystem.getInfo(from)
		if info and info.type == "directory" then
			copyfolder(from, to)
		elseif info then
			local data = love.filesystem.read(from)
			if data then
				love.filesystem.write(to, data)
			end
		end
	end
end

--deletes a folder from the save directory, yields now and then so it can run as a job
local removedcount = 0
local function removerecursive(path)
	local info = love.filesystem.getInfo(path)
	if info and info.type == "directory" then
		for _, file in ipairs(love.filesystem.getDirectoryItems(path)) do
			removerecursive(path .. "/" .. file)
		end
	end
	love.filesystem.remove(path)
	removedcount = removedcount + 1
	--only inside a utils job: the game's own callbacks run in coroutines too now (overlaytask.lua), and those mustn't stop here
	if removedcount % 200 == 0 and coroutine.running() and not overlaytask_canyield() then
		coroutine.yield()
	end
end

local function insavedirectory(path)
	local ok, real = pcall(love.filesystem.getRealDirectory, path)
	return ok and real ~= nil and real == love.filesystem.getSaveDirectory()
end

local function drawpanel()
	love.graphics.setColor(0, 0, 0, 200)
	love.graphics.rectangle("fill", PX*scale, PY*scale, panelwidth()*scale, PH*scale)
end

--runs f with drawing cut to a box (game pixels, wherever the current transform puts it), inside any clip already set
function ui.clipto(x, y, w, h, f)
	local sx1, sy1 = love.graphics.transformPoint(x*scale, y*scale)
	local sx2, sy2 = love.graphics.transformPoint((x+w)*scale, (y+h)*scale)
	local ox, oy, ow, oh = love.graphics.getScissor()
	love.graphics.intersectScissor(math.floor(sx1), math.floor(sy1), math.max(0, math.ceil(sx2-sx1)), math.max(0, math.ceil(sy2-sy1)))
	f()
	if ox then
		love.graphics.setScissor(ox, oy, ow, oh)
	else
		love.graphics.setScissor()
	end
end

--how far along the mappack creator's tab slide is (0 to 1, after the motion curve), or nil when it isn't sliding
function mpslide.progress()
	if not mpslide.anim or page ~= "mappack" then
		return nil
	end
	local t = (love.timer.getTime() - mpslide.anim.start)/mpslide.time
	if t >= 1 then
		return nil
	end
	return ease_in_out_quad(t)
end

local function drawtitle(s)
	love.graphics.setColor(255, 255, 255)
	properprintF(s, (PX+5)*scale, (PY+6)*scale)
	love.graphics.setColor(60, 60, 60)
	love.graphics.rectangle("fill", (PX+5)*scale, (PY+15)*scale, (panelwidth()-10)*scale, scale)
end

local function drawprogress(x, y, w, p, color)
	love.graphics.setColor(127, 127, 127)
	love.graphics.rectangle("fill", x*scale, y*scale, w*scale, 8*scale)
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", (x+1)*scale, (y+1)*scale, (w-2)*scale, 6*scale)
	love.graphics.setColor(color)
	love.graphics.rectangle("fill", (x+1)*scale, (y+1)*scale, math.floor((w-2)*clamp(p, 0, 1))*scale, 6*scale)
end

local function drawswatch(x, y, w, h, color)
	love.graphics.setColor(255, 255, 255)
	love.graphics.rectangle("fill", x*scale, y*scale, w*scale, h*scale)
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", (x+1)*scale, (y+1)*scale, (w-2)*scale, (h-2)*scale)
	love.graphics.setColor(color)
	love.graphics.rectangle("fill", (x+2)*scale, (y+2)*scale, (w-4)*scale, (h-4)*scale)
end

------------------------------------------------------------
-- gui elements owned by the utils pages
------------------------------------------------------------

local steppers
local function clearelements()
	steppers = {}
	elements = {}
	named = {}
	labels = {}
	confirmuntil = {}
	typingintextinput = false
	love.keyboard.setKeyRepeat(false)
end

local function add(name, el, tab)
	table.insert(elements, {el = el, tab = tab})
	named[name] = el
	return el
end

local function label(x, y, text, tab, color)
	table.insert(labels, {x = x, y = y, text = text, tab = tab, color = color})
end

local function onpage(entry)
	return entry.tab == nil or entry.tab == mptab
end

local function closeinput(self)
	self.inputting = false
	self.highlight = false
	typingintextinput = false
	love.keyboard.setKeyRepeat(false)
end

local function newinput(x, y, w, value, maxlength, h)
	local el = guielement:new("input", x, y, w, closeinput, tostring(value or ""), maxlength, h or 1)
	el.bypassspecialcharacters = true --keep "," and "-" as they are
	return el
end

local function newbutton(x, y, text, func, w)
	return guielement:new("button", x, y, text, func, 0, nil, 1, w)
end

--a button that has to be clicked twice within 3 seconds
local function confirmbutton(name, x, y, text, func)
	local w = math.max(utf8.len(text), utf8.len(T("sure? click again")))*8
	local el
	el = newbutton(x, y, text, function()
		if confirmuntil[name] and love.timer.getTime() < confirmuntil[name] then
			confirmuntil[name] = nil
			el.text = text
			func()
		else
			confirmuntil[name] = love.timer.getTime() + 3
			el.text = T("sure? click again")
		end
	end, w)
	el.textcolor = {255, 80, 80}
	el.utilsconfirmtext = text
	return add(name, el)
end

--buttons one after another from x (each {name, text, func}); returns where the row ends
function ui.buttonrow(x, y, ...)
	for _, b in ipairs({...}) do
		local el = add(b[1], newbutton(x, y, b[2], b[3]))
		x = x + 3 + el.width + 6
	end
	return x
end

--the back button in the bottom right corner of every page
function ui.addback()
	local text = T("back")
	add("back", newbutton(panelright() - 5 - (3 + utf8.len(text)*8), 199, text, function() utils_back() end))
end

local function updateelements(dt)
	local now = love.timer.getTime()
	for name, untiltime in pairs(confirmuntil) do
		if now >= untiltime then
			confirmuntil[name] = nil
			if named[name] then
				named[name].text = named[name].utilsconfirmtext
			end
		end
	end

	if mpslide.anim and not mpslide.progress() then
		mpslide.anim = nil
	end
	local sliding = mpslide.anim ~= nil --tabs' elements aren't where the mouse thinks they are while they slide
	for _, v in ipairs(elements) do
		local el = v.el
		local visible = onpage(v) and not el.utilshidden
		el.active = visible and not el.utilsdisabled and not (sliding and v.tab)
		el.nohover = el.utilsdisabled or (sliding and v.tab ~= nil)
		if not visible and el.type == "input" and el.inputting then
			closeinput(el)
		end
		if el.active then
			el:update(dt)
		end
	end
end

--tab: nil draws everything on the page, false only what's on every tab, or a mappack tab's name only that tab's
function ui.intab(entry, tab)
	if tab == nil then
		return onpage(entry)
	elseif tab == false then
		return entry.tab == nil
	end
	return entry.tab == tab
end

local function drawelements(tab)
	local ontop = {}
	for _, v in ipairs(elements) do
		local el = v.el
		if ui.intab(v, tab) and not el.utilshidden then
			if el.type == "dropdown" and (el.extended or (el.listvalue and el.listvalue > 0)) then
				table.insert(ontop, el)
			elseif el.type == "button" and el.utilsdisabled then
				el:draw(90)
			else
				el:draw()
			end
		end
	end
	for _, el in ipairs(ontop) do
		el:draw()
	end
end

local function drawlabels(tab)
	for _, v in ipairs(labels) do
		if ui.intab(v, tab) then
			love.graphics.setColor(v.color or {255, 255, 255})
			properprintF(v.text, v.x*scale, v.y*scale)
		end
	end
end

local function opendropdown()
	for _, v in ipairs(elements) do
		local el = v.el
		if el.active and el.type == "dropdown" and el.extended then
			return el
		end
	end
	return nil
end

------------------------------------------------------------
-- sliders: drag the handle, click the track to jump, right click to type a value
------------------------------------------------------------

local function sliderround(s, n)
	n = s.min + math.floor((n - s.min)/s.utilsstep + 0.5)*s.utilsstep
	n = clamp(n, s.min, s.max)
	if s.utilsstep >= 1 then
		return math.floor(n + 0.5)
	end
	return math.floor(n*10 + 0.5)/10
end

--the slider's value in its own units (snapped to its step)
local function slidervalue(s)
	return sliderround(s, s.min + s.value*(s.max - s.min))
end

local function setslidervalue(s, n)
	s.value = clamp((n - s.min)/(s.max - s.min), 0, 1)
end

local function newslider(x, y, trackwidth, minimum, maximum, step, value)
	local s = guielement:new("scrollbar", x, y, trackwidth, 33, 9, 0, "hor")
	s.buttonround = true
	s.scrollstepdisabled = true --the wheel would change it while scrolling past
	s.min, s.max = minimum, maximum
	s.utilsstep = step
	s.utilsslider = true
	s.displayfunction = function(self)
		return numbertostring(slidervalue(self))
	end
	setslidervalue(s, tonumber(value) or minimum)
	return s
end

local function slidertrackhit(s, x, y)
	x, y = x/scale, y/scale
	return x >= s.x and x < s.x + s.xrange + s.width and y >= s.y and y < s.y + s.height
end

--right click typing comes from gui.lua; clicking the track (not the handle) jumps the handle there
local function sliderclick(s, x, y, button)
	if button == "l" and slidertrackhit(s, x, y) and not s:inhighlight(x, y) then
		s.value = clamp((x/scale - s.x - s.width/2)/s.xrange, 0, 1)
	end
	s:click(x, y, button)
end

------------------------------------------------------------
-- steppers, like the editor's time limit: [<][value][>]
-- hold an arrow to keep counting, click the number to type one
------------------------------------------------------------

steppers = {}

local function stepperget(st)
	local n = tonumber(st.get())
	if not n then
		return st.minimum
	end
	return clamp(math.floor(n), st.minimum, st.maximum)
end

local function newstepper(name, x, y, digits, minimum, maximum, step, get, set, tab)
	local st = {x = x, digits = digits, minimum = minimum, maximum = maximum, get = get, set = set}

	local function nudge(direction)
		st.set(clamp(stepperget(st) + direction*step, minimum, maximum))
	end
	local function arrow(text, direction)
		local b = guielement:new("button", x, y, text, function() nudge(direction) end, 0)
		b.autorepeat = true
		b.repeatwait = 0.3
		b.repeatdelay = 0.08
		return b
	end

	st.dec = add(name .. "_dec", arrow("{", -1), tab)
	st.input = add(name .. "_input", guielement:new("input", x + 12, y, 1, function(self)
		local n = tonumber(self.value)
		if n then
			st.set(clamp(math.floor(n), minimum, maximum))
		else
			notice.new(T("that has to be a number!"), notice.red, 3)
		end
		closeinput(self)
	end, tostring(stepperget(st)), digits, nil, nil, 0), tab)
	st.input.justdisplay = true
	st.input.utilsnumeric = "int"
	st.inc = add(name .. "_inc", arrow("}", 1), tab)
	table.insert(steppers, st)
	return st
end

--keeps the number and the right arrow where the editor would put them
local function updatesteppers()
	for _, st in ipairs(steppers) do
		local width
		if st.input.inputting then
			if not st.wasinputting then
				--select the whole number, so typing replaces it
				st.input.highlighting = false
				st.input.highlight = 1
				st.input.cursorpos = string.len(tostring(st.input.value)) + 1
			end
			width = st.digits
		else
			local value = tostring(stepperget(st))
			st.input.value = value
			st.input.textoffset = 0
			width = string.len(value)
		end
		st.input.width = width
		st.inc.x = st.x + 16 + width*8
		st.dec.utilsdisabled = st.input.inputting
		st.inc.utilsdisabled = st.input.inputting
		st.wasinputting = st.input.inputting
	end
end

local function clickelements(x, y, button)
	--an open dropdown gets the click and nothing behind it does
	local dropdown = opendropdown()
	if dropdown then
		dropdown:click(x, y, button)
		return true
	end

	--inputs and sliders first: they never stop the click, and every input has to see it to lose focus
	for _, v in ipairs(elements) do
		local el = v.el
		if el.active and (el.type == "input" or el.type == "scrollbar") then
			if el.utilsslider then
				sliderclick(el, x, y, button)
			else
				el:click(x, y, button)
			end
		end
	end
	for _, v in ipairs(elements) do
		local el = v.el
		if el.active and el.type ~= "input" and el.type ~= "scrollbar" then
			if el:click(x, y, button) then
				return true
			end
		end
	end
	return false
end

local function keyelements(key)
	local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
	for _, v in ipairs(elements) do
		local el = v.el
		if el.active then
			local k = key
			if el.type == "input" and el.inputting and string.len(key) == 1 and not el.ctrl then
				if el.utilsnumeric then
					local allowed = key:match("%d") ~= nil or (el.utilsnumeric == "float" and key == ".")
					if shift or not allowed then
						return true
					end
				elseif el.utilscaps and shift and key:match("%l") then
					k = key:upper()
				end
			end
			if el:keypress(k) then
				return true
			end
		end
	end
	return false
end

local function anyinputting()
	for _, v in ipairs(elements) do
		local el = v.el
		if el.active and el.inputting then
			return true
		end
	end
	return false
end

------------------------------------------------------------
-- background jobs
------------------------------------------------------------

--fn runs as a coroutine and yields whenever it wants to give the frame back
local function startjob(fn, onerror)
	job = {co = coroutine.create(fn), onerror = onerror}
end

local function runjob()
	local stop = love.timer.getTime() + 0.012
	while job and love.timer.getTime() < stop do
		local current = job
		local ok, err = coroutine.resume(current.co)
		if not ok then
			job = nil
			print("utils job failed: " .. tostring(err))
			if current.onerror then
				current.onerror(tostring(err))
			end
		elseif coroutine.status(current.co) == "dead" then
			job = nil
		end
	end
end

------------------------------------------------------------
-- hub
------------------------------------------------------------

local function hub_itemrect(i)
	local item = HUBITEMS[i]
	local y = 56 + (i-1)*22
	if i == #HUBITEMS then
		y = y + 10
	end
	local text = T(item.text)
	local x = 130 - utf8.len(text)*4
	return x, y, utf8.len(text)*8
end

local function hub_draw()
	love.graphics.setColor(0, 0, 0, 200)
	love.graphics.rectangle("fill", 21*scale, 16*scale, 218*scale, 200*scale)

	love.graphics.setColor(255, 255, 255)
	centredprint(T("utils"), 130, 26)
	love.graphics.setColor(60, 60, 60)
	love.graphics.rectangle("fill", 30*scale, 37*scale, 200*scale, scale)

	for i, item in ipairs(HUBITEMS) do
		local x, y = hub_itemrect(i)
		if hubselection == i then
			love.graphics.setColor(255, 255, 255)
			love.graphics.draw(menuselectimg, (x-14)*scale, (y-1)*scale, 0, scale, scale)
		else
			love.graphics.setColor(100, 100, 100)
		end
		properprintF(T(item.text), x*scale, y*scale)
	end

	love.graphics.setColor(60, 60, 60)
	love.graphics.rectangle("fill", 30*scale, 162*scale, 200*scale, scale)
	love.graphics.setColor(170, 170, 170)
	centredprint(table.concat(wraptext(T(HUBITEMS[hubselection].info), 25), "\n"), 130, 172)
end

local function hub_activate()
	local item = HUBITEMS[hubselection]
	if item.page then
		inner_utilsmenu_openpage(item.page)
	else
		utilsmenu_close()
	end
end

local function hub_mouseitem(x, y)
	x, y = x/scale, y/scale
	for i = 1, #HUBITEMS do
		local ix, iy, iw = hub_itemrect(i)
		if x >= ix - 16 and x < ix + iw + 2 and y >= iy - 3 and y < iy + 11 then
			return i
		end
	end
	return nil
end

------------------------------------------------------------
-- character formatter
------------------------------------------------------------

local cf = {list = {}, sel = 1, colors = nil, sheets = {}, status = "", statuscolor = {255, 255, 255}}

local function cf_scan()
	local previous = cf.list[cf.sel]
	cf.list = {}
	for _, v in ipairs(love.filesystem.getDirectoryItems(CHARFOLDER)) do
		if love.filesystem.getInfo(CHARFOLDER .. "/" .. v .. "/config.json") then
			table.insert(cf.list, v)
		end
	end
	table.sort(cf.list, function(a, b) return a:lower() < b:lower() end)
	cf.sel = 1
	for i, v in ipairs(cf.list) do
		if v == previous then
			cf.sel = i
		end
	end
end

--the sheets the formatter splits: "<something>animations.png", not already a numbered layer
local function cf_findsheets(folder)
	local sheets = {}
	for _, file in ipairs(love.filesystem.getDirectoryItems(folder)) do
		local lower = file:lower()
		if lower:sub(-4) == ".png" and love.filesystem.getInfo(folder .. "/" .. file, "file") then
			local base = lower:sub(1, -5)
			if base:match("animations$") then
				table.insert(sheets, file)
			end
		end
	end
	table.sort(sheets, function(a, b) return a:lower() < b:lower() end)
	return sheets
end

local function cf_readcolors(folder)
	local config, err = readjson(folder .. "/config.json")
	if not config then
		return nil, err
	end
	local colors = config.colors
	if type(colors) ~= "table" or #colors == 0 then
		return nil, T("config.json has no colors list")
	end
	local list = {}
	for i, c in ipairs(colors) do
		if type(c) ~= "table" or not (tonumber(c[1]) and tonumber(c[2]) and tonumber(c[3])) then
			return nil, TF("colour %s in config.json isn't r, g, b", i)
		end
		list[i] = {tonumber(c[1]), tonumber(c[2]), tonumber(c[3])}
	end
	return list
end

local function cf_load()
	cf.colors, cf.error, cf.sheets = nil, nil, {}
	local name = cf.list[cf.sel]
	if not name then
		return
	end
	local folder = CHARFOLDER .. "/" .. name
	cf.colors, cf.error = cf_readcolors(folder)
	cf.sheets = cf_findsheets(folder)
end

local function colourkey(r, g, b)
	return math.floor(r + 0.5)*65536 + math.floor(g + 0.5)*256 + math.floor(b + 0.5)
end

local function cf_job(name)
	local src = CHARFOLDER .. "/" .. name
	local dst = CHARFOLDER .. "/" .. name .. "_formatted"

	local colors, err = cf_readcolors(src)
	if not colors then
		error(err, 0)
	end
	local lookup = {}
	for i, c in ipairs(colors) do
		local key = colourkey(c[1], c[2], c[3])
		if not lookup[key] then
			lookup[key] = i
		end
	end

	cf.status, cf.statuscolor = T("copying files..."), {255, 255, 255}
	copyfolder(src, dst)
	coroutine.yield()

	local sheets = cf_findsheets(src)
	cf.progress = {done = 0, total = #sheets, row = 0}
	local written = 0

	for _, file in ipairs(sheets) do
		cf.status = TF("splitting %s", file:lower())
		local img = love.image.newImageData(src .. "/" .. file)
		local w, h = img:getDimensions()
		local layers = {}
		for i = 1, #colors do
			layers[i] = love.image.newImageData(w, h)
		end
		local excluded = love.image.newImageData(w, h)

		--main.lua wraps ImageData so pixels are 0-255 here, like the rest of the game
		for y = 0, h-1 do
			for x = 0, w-1 do
				local r, g, b, a = img:getPixel(x, y)
				if a > 0 then
					local index = nil
					if a >= 255 then
						index = lookup[colourkey(r, g, b)]
					end
					if index then
						layers[index]:setPixel(x, y, 255, 255, 255, 255)
					else
						excluded:setPixel(x, y, r, g, b, a)
					end
				end
			end
			if y % 16 == 15 then
				cf.progress.row = (y+1)/h
				coroutine.yield()
			end
		end

		--layers the character already had (made by hand) are kept as they are
		local base = file:sub(1, -5)
		local function writelayer(imagedata, suffix)
			local outname = base .. suffix .. ".png"
			if not love.filesystem.getInfo(src .. "/" .. outname) then
				imagedata:encode("png", dst .. "/" .. outname)
				written = written + 1
			end
		end
		writelayer(excluded, "0")
		for i = 1, #layers do
			writelayer(layers[i], tostring(i))
		end

		cf.progress.done = cf.progress.done + 1
		cf.progress.row = 0
		coroutine.yield()
	end

	cf.progress = nil
	cf.status = TF("done! wrote %s layers to %s", written, name:lower() .. "_formatted")
	cf.statuscolor = {100, 255, 100}
	notice.new(TF("formatted %s (restart to play as it)", name), nil, 4)
	cf_scan()
	cf_load()
	if named["cf_char"] then
		named["cf_char"].var = cf.sel
	end
end

local function cf_start()
	local name = cf.list[cf.sel]
	if not name or job then
		return
	end
	startjob(function() cf_job(name) end, function(err)
		cf.progress = nil
		cf.status = TF("failed: %s", err)
		cf.statuscolor = {255, 80, 80}
	end)
end

local function cf_build()
	clearelements()
	cf_scan()
	ui.cfx = ui.columnx(114, T("character:"), T("colours:"))

	if #cf.list > 0 then
		local w = 8
		local display = {}
		for i, v in ipairs(cf.list) do
			w = math.max(w, math.min(20, utf8.len(v)))
			display[i] = v:lower()
		end
		w = math.min(w, math.floor((panelright() - 5 - ui.cfx - 13)/8))
		local drop
		drop = add("cf_char", guielement:new("dropdown", ui.cfx, 35, w, function(i)
			drop.var = i
			cf.sel = i
			cf.status = ""
			cf_load()
		end, cf.sel, unpack(cf.list)))
		drop.displayentries = display
	end

	ui.buttonrow(26, 199,
		{"cf_format", T("format"), cf_start},
		{"cf_open", T("open folder"), function() openSaveFolder(CHARFOLDER) end})
	ui.addback()

	cf_load()
end

local function cf_update()
	if named["cf_format"] then
		named["cf_format"].utilsdisabled = (job ~= nil) or cf.colors == nil or #cf.sheets == 0
	end
	if named["cf_char"] then
		named["cf_char"].utilsdisabled = (job ~= nil)
	end
end

local function cf_draw()
	drawpanel()
	drawtitle(T("character formatter"))

	love.graphics.setColor(255, 255, 255)
	properprintF(T("character:"), 26*scale, 37*scale)

	if #cf.list == 0 then
		love.graphics.setColor(255, 80, 80)
		properprintF(T("no characters found in") .. "\n" .. CHARFOLDER, ui.cfx*scale, 37*scale)
	else
		love.graphics.setColor(255, 255, 255)
		properprintF(T("colours:"), 26*scale, 55*scale)
		if cf.colors then
			for i, c in ipairs(cf.colors) do
				drawswatch(ui.cfx + (i-1)*13, 53, 11, 11, c)
			end
		elseif cf.error then
			love.graphics.setColor(255, 80, 80)
			properprintF(cf.error, ui.cfx*scale, 55*scale)
		end

		love.graphics.setColor(255, 255, 255)
		properprintF(TF("sheets to split: %s", #cf.sheets), 26*scale, 72*scale)
		love.graphics.setColor(150, 150, 150)
		for i, file in ipairs(cf.sheets) do
			if i > 14 then
				properprintF(TF("+%s more", #cf.sheets - 14), 200*scale, (84 + 6*10)*scale)
				break
			end
			local col = math.floor((i-1)/7)
			local row = (i-1) % 7
			properprintF(file:lower():sub(1, 21), (26 + col*174)*scale, (84 + row*10)*scale)
		end

		love.graphics.setColor(255, 255, 255)
		properprintF(T("output:"), 26*scale, 158*scale)
		love.graphics.setColor(150, 150, 150)
		local outx = ui.columnx(90, T("output:"))
		local output = (cf.list[cf.sel] or ""):lower() .. "_formatted"
		properprintF(ui.cut(output, math.floor((panelright() - 5 - outx)/8)), outx*scale, 158*scale)
	end

	if cf.progress then
		local p = 0
		if cf.progress.total > 0 then
			p = (cf.progress.done + cf.progress.row)/cf.progress.total
		end
		drawprogress(26, 172, panelwidth()-10, p, {60, 100, 255})
	end
	love.graphics.setColor(cf.statuscolor)
	properprintF(ui.cut(cf.status, 44), 26*scale, 184*scale)

	drawelements()
end

------------------------------------------------------------
-- font renderer
------------------------------------------------------------

local FR_ALIGN = {"left", "center", "right"}
local fr = {caps = true, outline = false, align = 2, color = {255, 255, 255}}
local CLIPBOARD_CHANNEL = "utilsmenu_clipboard"

--the glyph the game would draw for a character (all caps uses the same table as properprintF)
local function fr_glyph(c)
	if fr.caps then
		c = fontindexCAP[c] or c
	end
	if fontquads[c] then
		return c
	end
	return nil
end

------------------------------------------------------------
-- font renderer: multi-line text area (typing comes from love.textinput, so capitals and symbols just work)
------------------------------------------------------------

local TA_X, TA_Y, TA_ROWS = 26, 33, 6
local TA_MAXCHARS = 2000
local ta = {chars = {}, cursor = 0, focus = false, scroll = 0, hscroll = 0, blinkstart = 0}

local function ta_width()
	return panelwidth() - 10
end

local function ta_height()
	return TA_ROWS*10 + 4
end

local function ta_visiblecolumns()
	return math.floor((ta_width() - 6)/8)
end

local function ta_text()
	return table.concat(ta.chars)
end

--every line as {start = index of its first character, len = characters in it}
local function ta_lines()
	local lines = {{start = 1, len = 0}}
	for i, c in ipairs(ta.chars) do
		if c == "\n" then
			lines[#lines+1] = {start = i + 1, len = 0}
		else
			lines[#lines].len = lines[#lines].len + 1
		end
	end
	return lines
end

--line number and column (0 = before the first character) of the cursor
local function ta_cursorpos()
	local lines = ta_lines()
	for li, line in ipairs(lines) do
		if ta.cursor >= line.start - 1 and ta.cursor <= line.start - 1 + line.len then
			return li, ta.cursor - (line.start - 1), lines
		end
	end
	return #lines, lines[#lines].len, lines
end

--scroll so the cursor can be seen
local function ta_follow()
	local li, col = ta_cursorpos()
	if li - 1 < ta.scroll then
		ta.scroll = li - 1
	elseif li > ta.scroll + TA_ROWS then
		ta.scroll = li - TA_ROWS
	end
	local columns = ta_visiblecolumns()
	if col < ta.hscroll then
		ta.hscroll = col
	elseif col > ta.hscroll + columns - 1 then
		ta.hscroll = col - columns + 1
	end
	ta.blinkstart = love.timer.getTime()
end

local function ta_insert(s)
	for _, c in utf8.chars(s) do
		if c == "\t" then
			c = " "
		end
		if c ~= "\r" and #ta.chars < TA_MAXCHARS then
			table.insert(ta.chars, ta.cursor + 1, c)
			ta.cursor = ta.cursor + 1
		end
	end
	ta_follow()
end

local function ta_setfocus(focus)
	ta.focus = focus
	love.keyboard.setKeyRepeat(focus)
	typingintextinput = focus
	if focus then
		ta.blinkstart = love.timer.getTime()
	end
end

local function ta_keypressed(key)
	local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")
	local li, col, lines = ta_cursorpos()
	if key == "escape" then
		ta_setfocus(false)
	elseif key == "backspace" then
		if ta.cursor > 0 then
			table.remove(ta.chars, ta.cursor)
			ta.cursor = ta.cursor - 1
		end
	elseif key == "delete" then
		if ta.cursor < #ta.chars then
			table.remove(ta.chars, ta.cursor + 1)
		end
	elseif key == "left" then
		ta.cursor = math.max(0, ta.cursor - 1)
	elseif key == "right" then
		ta.cursor = math.min(#ta.chars, ta.cursor + 1)
	elseif key == "up" or key == "down" then
		local target = li - 1
		if key == "down" then
			target = li + 1
		end
		if lines[target] then
			ta.cursor = lines[target].start - 1 + math.min(col, lines[target].len)
		end
	elseif key == "home" then
		ta.cursor = lines[li].start - 1
	elseif key == "end" then
		ta.cursor = lines[li].start - 1 + lines[li].len
	elseif key == "return" or key == "enter" or key == "kpenter" then
		ta_insert("\n")
	elseif key == "v" and ctrl then
		local paste = love.system.getClipboardText()
		if paste then
			ta_insert(paste)
		end
	elseif key == "c" and ctrl then
		love.system.setClipboardText(ta_text())
		notice.new(T("copied the text"), nil, 2)
	elseif key == "x" and ctrl then
		love.system.setClipboardText(ta_text())
		ta.chars, ta.cursor = {}, 0
	end
	ta_follow()
end

local function ta_inside(x, y)
	x, y = x/scale, y/scale
	return x >= TA_X and x < TA_X + ta_width() and y >= TA_Y and y < TA_Y + ta_height()
end

--returns true when the click belonged to the text area
local function ta_mousepressed(x, y, button)
	if not ta_inside(x, y) then
		if button == "l" and ta.focus then
			ta_setfocus(false)
		end
		return false
	end
	local lines = ta_lines()
	if button == "wu" then
		ta.scroll = math.max(0, ta.scroll - 1)
	elseif button == "wd" then
		ta.scroll = math.max(0, math.min(#lines - TA_ROWS, ta.scroll + 1))
	elseif button == "l" then
		ta_setfocus(true)
		local gx, gy = x/scale, y/scale
		local li = clamp(ta.scroll + math.floor((gy - TA_Y - 2)/10) + 1, 1, #lines)
		local col = clamp(ta.hscroll + math.floor((gx - TA_X - 3)/8 + 0.5), 0, lines[li].len)
		ta.cursor = lines[li].start - 1 + col
		ta_follow()
	end
	return true
end

local function ta_draw()
	local x, y, w, h = TA_X, TA_Y, ta_width(), ta_height()
	local hover = ta_inside(love.mouse.getPosition())
	local border = 127
	if ta.focus or hover then
		border = 255
	end
	local r = math.min(w, h)*scale*0.08
	love.graphics.setColor(border, border, border)
	love.graphics.rectangle("fill", x*scale, y*scale, w*scale, h*scale, r)
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", (x+1)*scale, (y+1)*scale, (w-2)*scale, (h-2)*scale, r*0.7)

	if #ta.chars == 0 and not ta.focus then
		love.graphics.setColor(110, 110, 110)
		local placeholder = wraptext(T("click here and type. enter makes a new line."), math.floor((w-6)/8))
		properprintF(table.concat(placeholder, "\n"), (x+3)*scale, (y+3)*scale)
		return
	end

	love.graphics.setScissor((x+1)*scale, (y+1)*scale, (w-2)*scale, (h-2)*scale)
	local lines = ta_lines()
	local columns = ta_visiblecolumns()
	for row = 1, TA_ROWS do
		local line = lines[ta.scroll + row]
		if line then
			for k = 1, math.min(columns + 1, line.len - ta.hscroll) do
				local c = ta.chars[line.start - 1 + ta.hscroll + k]
				local cx, cy = (x + 3 + (k-1)*8)*scale, (y + 3 + (row-1)*10)*scale
				if fontquads[c] then
					love.graphics.setColor(255, 255, 255)
					love.graphics.draw(fontimage, fontquads[c], cx, cy, 0, scale, scale)
				elseif c ~= " " then
					--the font has no glyph for this, so it won't show up in the render either
					love.graphics.setColor(255, 80, 80)
					love.graphics.draw(fontimage, fontquads["?"], cx, cy, 0, scale, scale)
				end
			end
		end
	end

	if ta.focus and (love.timer.getTime() - ta.blinkstart) % 1 < 0.5 then
		local li, col = ta_cursorpos()
		local row = li - ta.scroll
		if row >= 1 and row <= TA_ROWS then
			love.graphics.setColor(255, 255, 255)
			love.graphics.rectangle("fill", (x + 2 + (col - ta.hscroll)*8)*scale, (y + 2 + (row-1)*10)*scale, scale, 9*scale)
		end
	end
	love.graphics.setScissor()

	--line count, so you know there's more when it's scrolled
	if #lines > TA_ROWS then
		love.graphics.setColor(110, 110, 110)
		local s = (ta.scroll + 1) .. "-" .. math.min(#lines, ta.scroll + TA_ROWS) .. "/" .. #lines
		properprintF(s, (x + w - 3 - utf8.len(s)*8)*scale, (y + h - 10)*scale)
	end
end

--the lines that get rendered (empty lines at the end are dropped)
local function fr_gettext()
	local lines = {}
	for line in (ta_text() .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end
	while #lines > 0 and lines[#lines] == "" do
		table.remove(lines)
	end
	return lines
end

--renders the text with the mappack's font (fontimage) and outline (fontbackimage) like properprintFbackground does
local function fr_render()
	local lines = fr_gettext()
	local longest = 0
	for _, line in ipairs(lines) do
		longest = math.max(longest, utf8.len(line))
	end
	if longest == 0 then
		return nil
	end

	local pad = 0
	if fr.outline then
		pad = 1
	end
	local w, h = longest*8 + pad*2, #lines*10
	local canvas = love.graphics.newCanvas(w, h)
	canvas:setFilter("nearest", "nearest")

	--each line's left edge in pixels
	local offsets = {}
	for i, line in ipairs(lines) do
		local free = (longest - utf8.len(line))*8
		if fr.align == 1 then
			offsets[i] = pad
		elseif fr.align == 2 then
			offsets[i] = pad + math.floor(free/2)
		else
			offsets[i] = pad + free
		end
	end

	love.graphics.push("all")
	local ok, err = pcall(function()
	love.graphics.setCanvas(canvas)
	love.graphics.origin()
	love.graphics.setScissor()
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setBlendMode("alpha")

	--outline first, so it never covers the letters next to it
	if fr.outline then
		love.graphics.setColor(255, 255, 255)
		for li, line in ipairs(lines) do
			for i, c in utf8.chars(line) do
				local g = fr_glyph(c)
				if g and fontquadsback[g] then
					love.graphics.draw(fontbackimage, fontquadsback[g], offsets[li] + (i-1)*8 - 1, (li-1)*10)
				end
			end
		end
	end

	love.graphics.setColor(fr.color[1], fr.color[2], fr.color[3])
	for li, line in ipairs(lines) do
		for i, c in utf8.chars(line) do
			local g = fr_glyph(c)
			if g then
				love.graphics.draw(fontimage, fontquads[g], offsets[li] + (i-1)*8, (li-1)*10 + 1)
			end
		end
	end
	end)
	love.graphics.setCanvas()
	love.graphics.pop()
	if not ok then
		error(err, 0)
	end

	return canvas
end

local function fr_renderkey()
	local lines = fr_gettext()
	return table.concat(lines, "\n") .. "|" .. tostring(fr.caps) .. tostring(fr.outline) .. fr.align
		.. "|" .. fr.color[1] .. "," .. fr.color[2] .. "," .. fr.color[3] .. "|" .. tostring(fontimage) .. tostring(fontbackimage)
end

local function fr_save(path)
	if not fr.canvas then
		notice.new(T("there's no text to render!"), notice.red, 3)
		return false
	end
	love.filesystem.createDirectory(RENDERFOLDER)
	local data = fr.canvas:newImageData()
	data:encode("png", path)
	return true
end

local function utf16le(s)
	local out = {}
	for _, cp in utf8.codes(s) do
		if cp >= 0x10000 then
			cp = cp - 0x10000
			local hi, lo = 0xD800 + math.floor(cp/0x400), 0xDC00 + cp % 0x400
			out[#out+1] = string.char(hi % 256, math.floor(hi/256), lo % 256, math.floor(lo/256))
		else
			out[#out+1] = string.char(cp % 256, math.floor(cp/256))
		end
	end
	return table.concat(out)
end

--a shell command that puts the png on the clipboard (keeps transparency where the os allows it)
local function fr_clipboardcommand(realpath)
	local system = love.system.getOS()
	if system == "Windows" then
		realpath = realpath:gsub("/", "\\")
		local script = table.concat({
			"Add-Type -AssemblyName System.Windows.Forms",
			"Add-Type -AssemblyName System.Drawing",
			"$bytes = [System.IO.File]::ReadAllBytes('" .. realpath:gsub("'", "''") .. "')",
			"$data = New-Object System.Windows.Forms.DataObject",
			"$data.SetData('PNG', (New-Object System.IO.MemoryStream(,$bytes)))",
			"$data.SetImage([System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(,$bytes))))",
			"[System.Windows.Forms.Clipboard]::SetDataObject($data, $true)",
		}, "\n")
		local encoded = love.data.encode("string", "base64", utf16le(script))
		return "powershell -NoProfile -NonInteractive -STA -WindowStyle Hidden -EncodedCommand " .. encoded
	elseif system == "OS X" then
		return "osascript -e 'set the clipboard to (read (POSIX file \"" .. realpath .. "\") as «class PNGf»)'"
	elseif system == "Linux" then
		return "xclip -selection clipboard -t image/png -i \"" .. realpath .. "\""
	end
	return nil
end

local CLIPBOARD_THREAD = [[
require("love.thread")
local command, channel = ...
local result = os.execute(command)
love.thread.getChannel(channel):push(result == 0 or result == true)
]]

local function fr_copy()
	local path = RENDERFOLDER .. "/clipboard.png"
	if not fr_save(path) then
		return
	end
	local command = fr_clipboardcommand(love.filesystem.getSaveDirectory() .. "/" .. path)
	if not command then
		notice.new(TF("can't copy images on this system,\nsaved to %s instead", path), notice.red, 4)
		return
	end
	love.thread.newThread(CLIPBOARD_THREAD):start(command, CLIPBOARD_CHANNEL)
	notice.new(T("copying..."), nil, 1)
end

local function fr_slider(c, y)
	local slider = newslider(36, y, 280, 0, 255, 1, fr.color[c])
	slider.backgroundcolor = {0, 0, 0}
	--the track shows what the colour would be along it, with the other two channels as they are, like the skins tab's sliders
	--(it fills the box it's given: the slider draws the glass around it, see drawtrack in gui.lua)
	slider.drawtrack = function(self, x, y, w, h, r, alpha)
		local steps = math.max(1, math.ceil(w/scale))
		local color = {fr.color[1], fr.color[2], fr.color[3], alpha or 255}
		for i = 0, steps-1 do
			color[c] = i/math.max(1, steps-1)*255
			love.graphics.setColor(color)
			love.graphics.rectangle("fill", x+i*scale, y, math.min(scale, w-i*scale), h)
		end
	end
	return slider
end

local function fr_build()
	clearelements()
	if fr.colorfrommappack == nil then
		--start with the mappack's own hud settings
		fr.outline = hudoutline or false
		fr.color = {hudtextcolor[1], hudtextcolor[2], hudtextcolor[3]}
		fr.colorfrommappack = mappack
	end

	--each control starts after the one before it, so longer translations push the row along
	local capstext, outlinetext, aligntext = ui.line("all caps"), ui.line("outline"), T("align:")
	local outlinex = math.max(110, 26 + 9 + ui.textw(capstext) + 11)
	local alignx = math.max(202, outlinex + 9 + ui.textw(outlinetext) + 11)
	local aligndropx = math.max(252, alignx + ui.textw(aligntext) + 2)
	local aligndisplay, alignwidth = {}, 6
	for i, v in ipairs(FR_ALIGN) do
		aligndisplay[i] = T(v)
		alignwidth = math.max(alignwidth, utf8.len(aligndisplay[i]))
	end

	local caps, outline, align
	caps = add("fr_caps", guielement:new("checkbox", 26, 101, function(v)
		caps.var = v
		fr.caps = v
	end, fr.caps, capstext))
	outline = add("fr_outline", guielement:new("checkbox", outlinex, 101, function(v)
		outline.var = v
		fr.outline = v
	end, fr.outline, outlinetext))
	label(alignx, 102, aligntext)
	align = add("fr_align", guielement:new("dropdown", aligndropx, 100, alignwidth, function(i)
		align.var = i
		fr.align = i
	end, fr.align, unpack(FR_ALIGN)))
	align.displayentries = aligndisplay

	for c = 1, 3 do
		add("fr_slider" .. c, fr_slider(c, 115 + (c-1)*12))
	end

	local buttons = {
		{"fr_save", T("save png"), function()
			local path = RENDERFOLDER .. "/text " .. os.date("%Y-%m-%d %H-%M-%S") .. ".png"
			if fr_save(path) then
				notice.new(TF("saved to %s", path), nil, 4)
			end
		end},
		{"fr_copy", T("copy image"), fr_copy},
		{"fr_mappackcolour", T("hud colour"), function()
			fr.color = {hudtextcolor[1], hudtextcolor[2], hudtextcolor[3]}
			fr.outline = hudoutline or false
			named["fr_outline"].var = fr.outline
			for c = 1, 3 do
				setslidervalue(named["fr_slider" .. c], fr.color[c])
			end
		end},
	}
	--if the buttons would run into the back button, they go one row up and the preview gets shorter
	local rowend = 26
	for _, b in ipairs(buttons) do
		rowend = rowend + 3 + ui.textw(b[2]) + 6
	end
	local backx = panelright() - 5 - (3 + ui.textw(T("back")))
	fr.compact = rowend - 6 > backx - 4
	ui.buttonrow(26, fr.compact and 187 or 199, unpack(buttons))
	ui.addback()

	fr.renderkey = nil
end

local function fr_update()
	for c = 1, 3 do
		local slider = named["fr_slider" .. c]
		if slider then
			fr.color[c] = slidervalue(slider)
		end
	end

	local key = fr_renderkey()
	if key ~= fr.renderkey then
		fr.renderkey = key
		fr.canvas = fr_render()
	end
end

local function fr_draw()
	drawpanel()
	drawtitle(T("font renderer"))
	local fontname = TF("font: %s", tostring(mappack))
	love.graphics.setColor(150, 150, 150)
	properprintF(ui.cut(fontname, 26), (panelright() - 5 - math.min(26, utf8.len(fontname))*8)*scale, (PY+6)*scale)

	--rgb letters next to the sliders, drawn like the skin options do
	local letters = {"r", "g", "b"}
	local dark = {{100, 0, 0}, {0, 100, 0}, {0, 0, 100}}
	local bright = {{255, 0, 0}, {0, 255, 0}, {0, 0, 255}}
	for c = 1, 3 do
		local y = 116 + (c-1)*12
		love.graphics.setColor(dark[c])
		properprint(letters[c], 27*scale, (y+1)*scale)
		love.graphics.setColor(bright[c])
		properprint(letters[c], 26*scale, y*scale)
	end

	--colour preview, right of the sliders
	drawswatch(324, 114, 34, 34, fr.color)

	--rendered preview, on the game's sky so the black outline shows up
	local bx, by, bw, bh = 26, 152, panelwidth()-10, 43
	if fr.compact then
		bh = 31
	end
	love.graphics.setColor(127, 127, 127)
	love.graphics.rectangle("fill", bx*scale, by*scale, bw*scale, bh*scale)
	love.graphics.setColor(92, 148, 252)
	love.graphics.rectangle("fill", (bx+1)*scale, (by+1)*scale, (bw-2)*scale, (bh-2)*scale)
	if fr.canvas then
		local cw, ch = fr.canvas:getDimensions()
		local s = math.min(2, (bw-6)/cw, (bh-6)/ch)
		if s >= 1 then
			s = math.floor(s)
		end
		local x = bx + (bw - cw*s)/2
		local y = by + (bh - ch*s)/2
		love.graphics.setColor(255, 255, 255)
		love.graphics.setBlendMode("alpha", "premultiplied")
		love.graphics.draw(fr.canvas, math.floor(x*scale), math.floor(y*scale), 0, s*scale, s*scale)
		love.graphics.setBlendMode("alpha")
		love.graphics.setColor(40, 70, 140)
		local size = cw .. "*" .. ch
		properprintF(size, (bx + bw - 3 - utf8.len(size)*8)*scale, (by + bh - 10)*scale)
	else
		love.graphics.setColor(40, 70, 140)
		centredprint(T("the render shows up here"), bx + bw/2, by + bh/2 - 4)
	end

	ta_draw()
	drawlabels()
	drawelements()
end

------------------------------------------------------------
-- mappack creator
------------------------------------------------------------

--option names match the python mappack creator, so project files work in both
local PHYSICS = {"Mari0", "SMB", "Mari0-SMB2J", "SMB2J", "Mari0-Maker", "Mario Maker", "Portal"}
local CAMERA = {"Default", "Centered", "Forward Only"}
local PORTALGUN = {"Normal", "None", "1 Only", "2 Only", "Gel"}
local COLOURS = {"Black", "Blue", "Brown", "Gray", "Green", "Lime", "Maroon", "Orange", "Pink", "Purple", "Red", "Sky", "White", "Yellow"}
local WHITE = 13
local PROJECTFORMATS = {"mpckproj", "json", "cfg"}
local SUBFOLDERS = {"animated", "animations", "backgrounds", "custom", "enemies", "music", "sounds"}

local function lowered(list)
	local out = {}
	for i, v in ipairs(list) do
		out[i] = v:lower()
	end
	return out
end

local function optionindex(list, value, default)
	if type(value) == "number" then
		if list[value] then
			return value
		end
		return default
	end
	if value == nil then
		return default
	end
	value = tostring(value):lower()
	for i, v in ipairs(list) do
		if v:lower() == value then
			return i
		end
	end
	return default
end

local function colourvalue(i)
	return textcolors[COLOURS[i]:lower()] or {255, 255, 255}
end

local function mp_defaults()
	local d = {
		name = "new mappack", display_name = "", author = "you", description = "the newest best  mappack",
		lives = "3", physics = 1, camera = 1,
		drop_shadow = false, real_time = false, continue_music = false, no_hurry = false, no_coinlimit = false,
		world_count = "8", courses_per_world = "4", subzones_per_course = "5", no_subzones = false,
		player_name = "", use_character_name = true, hud_colour = WHITE,
		letters_world = false, visible_hud = true, outlined_hud = false, simple_hud = false,
		ending1 = "congratulations!", ending2 = "you have finished this mappack!", ending_colour = WHITE,
		toad1 = "thank you mario!", toad2 = "but our princess is in", toad3 = "another castle!",
		peach1 = "thank you mario!", peach2 = "your quest is over.", peach3 = "we present you a new quest.",
		peach4 = "push button b", peach5 = "to play as steve",
		allow_cheats = true, hidden = {},
		time_limit = "400", portalgun = 1, bgx = "0", bgy = "0", fgx = "0", fgy = "0",
		prevent_delete = true, projectformat = 1, projectsel = 1,
	}
	for i = 1, 10 do
		d.hidden[i] = false
	end
	return d
end

local mp --current values (input fields keep their text, dropdowns their index)
local mpicon --ImageData or nil
local mpiconimage
local mpbinds = {}
local mpsliders = {}
local mpexisting = {} --lowercase name -> folder name
local mpexistingtime = 0
local mpsession = {} --lowercase names created since the game started
local mpprojects = {}
local mpcreating = false
local mpprogress --{done, total}
local mpstatus, mpstatuscolor = "", {255, 255, 255}
local mpcheck = {valid = true, requirements = {}, notices = {}}

local function mpnumber(key, default, minimum, maximum, float)
	local n = tonumber(mp[key])
	if not n then
		return default
	end
	if not float then
		n = math.floor(n)
	end
	return clamp(n, minimum, maximum)
end

local function mp_seticon(imagedata)
	mpicon = imagedata
	mpiconimage = nil
	if imagedata then
		mpiconimage = love.graphics.newImage(imagedata)
		mpiconimage:setFilter("nearest", "nearest")
	end
end

--every value in its final form, used by creating and saving
local function mp_values()
	local v = {}
	for _, key in ipairs({"name", "display_name", "author", "description", "player_name", "ending1", "ending2", "toad1", "toad2", "toad3", "peach1", "peach2", "peach3", "peach4", "peach5"}) do
		v[key] = tostring(mp[key])
	end
	for _, key in ipairs({"drop_shadow", "real_time", "continue_music", "no_hurry", "no_coinlimit", "no_subzones", "use_character_name", "letters_world", "visible_hud", "outlined_hud", "simple_hud", "allow_cheats", "prevent_delete"}) do
		v[key] = mp[key]
	end
	if v.simple_hud then
		v.use_character_name = true
	end
	v.lives = mpnumber("lives", 3, 0, 9999)
	v.world_count = mpnumber("world_count", 8, 1, 999)
	v.courses_per_world = mpnumber("courses_per_world", 4, 1, 99)
	v.subzones_per_course = mpnumber("subzones_per_course", 5, 1, 13)
	v.time_limit = mpnumber("time_limit", 400, 0, 9999)
	v.bgx = mpnumber("bgx", 0, 0, 9, true)
	v.bgy = mpnumber("bgy", 0, 0, 9, true)
	v.fgx = mpnumber("fgx", 0, 0, 9, true)
	v.fgy = mpnumber("fgy", 0, 0, 9, true)
	v.physics, v.camera, v.portalgun = mp.physics, mp.camera, mp.portalgun
	v.hud_colour, v.ending_colour = mp.hud_colour, mp.ending_colour
	v.hidden = {}
	for i = 1, 10 do
		v.hidden[i] = mp.hidden[i] == true
	end
	return v
end

local function mp_filecount(v)
	local subzones = v.subzones_per_course
	if v.no_subzones then
		subzones = 0
	end
	return v.world_count * v.courses_per_world * (subzones + 1)
end

local function mp_refreshexisting()
	mpexisting = {}
	for _, v in ipairs(love.filesystem.getDirectoryItems(mappackfolder)) do
		if love.filesystem.getInfo(mappackfolder .. "/" .. v, "directory") then
			mpexisting[v:lower()] = v
		end
	end
	mpexistingtime = love.timer.getTime()
end

local function mp_refreshprojects()
	mpprojects = {}
	for _, file in ipairs(love.filesystem.getDirectoryItems(PROJECTFOLDER)) do
		local ext = (file:match("%.([^%.]+)$") or ""):lower()
		if ext == "mpckproj" or ext == "json" or ext == "cfg" then
			table.insert(mpprojects, file)
		end
	end
	table.sort(mpprojects, function(a, b) return a:lower() < b:lower() end)
end

--nil: not made by the creator (or not in the save folder), "session"/"marker": can be deleted, "locked": prevent deletion was on
local function mp_deletestate(name)
	local folder = mpexisting[name:lower()]
	if not folder then
		return nil
	end
	local path = mappackfolder .. "/" .. folder
	if not insavedirectory(path) then
		return nil
	end
	if mpsession[name:lower()] then
		return "session"
	end
	local marker = love.filesystem.read(path .. "/made_by_mappack_creator")
	if marker == nil then
		return nil
	end
	if marker:find("cannot delete") then
		return "locked"
	end
	return "marker"
end

local function mp_validate()
	local v = mp_values()
	local valid = true
	local requirements, notices = {}, {}
	local name = v.name

	if name:match("^%s*$") then
		valid = false
		table.insert(requirements, T("value for name is empty!"))
	end
	if name:find('[/\\:%*%?"<>|]') then
		valid = false
		table.insert(requirements, T("name can't have / \\ : * ? \" < > or | in it!"))
	end
	if utf8.len(v.display_name) > 17 then
		valid = false
		table.insert(requirements, T("value for display name is above 17 characters!"))
	end
	if utf8.len(v.author) > 13 then
		valid = false
		table.insert(requirements, T("value for author is above 13 characters!"))
	end
	if utf8.len(v.description) > 51 then
		valid = false
		table.insert(requirements, T("value for description is above 51 characters!"))
	end
	if v.display_name == "" and utf8.len(name) > 17 then
		valid = false
		table.insert(requirements, T("display name is empty, so it uses the name, which is above 17 characters!"))
	end

	local filecount = mp_filecount(v)
	if filecount >= MAPPACKCREATOR_FILEWARNING then
		local sentence = "this will create %s files. this will take some time."
		if filecount >= MAPPACKCREATOR_FILEWARNING_GOODGOD then
			sentence = "this will create %s files. this will take a ridiculously long time."
		elseif filecount >= MAPPACKCREATOR_FILEWARNING_HUGE then
			sentence = "this will create %s files. this will take a very long time."
		elseif filecount >= MAPPACKCREATOR_FILEWARNING_BIG then
			sentence = "this will create %s files. this will take a lot of time."
		end
		table.insert(requirements, TF(sentence, filecount))
	end

	if mpexisting[name:lower()] and not mpcreating then
		valid = false
		local state = mp_deletestate(name)
		if state == "session" or state == "marker" then
			table.insert(notices, TF("you can safely delete '%s'.", name))
		else
			table.insert(requirements, T("value for name already exists in the mappack folder!"))
			if state == "locked" then
				table.insert(requirements, TF("'%s' was made with prevent deletion on, so the creator can't delete it.", name))
			end
		end
	end

	mpcheck = {valid = valid, requirements = requirements, notices = notices, filecount = filecount, values = v}
end

------------------------------------------------------------
-- mappack creator: writing the mappack
------------------------------------------------------------

local function colourstring(i)
	local c = colourvalue(i)
	return c[1] .. ", " .. c[2] .. ", " .. c[3]
end

local function mp_settingstxt(v)
	local display = v.display_name
	if display == "" then
		display = v.name
	end
	local lines = {
		"name=" .. display:lower(),
		"author=" .. v.author:lower(),
		"description=" .. v.description:lower(),
		"lives=" .. v.lives,
	}
	if v.physics ~= 1 then
		table.insert(lines, "physics=" .. v.physics)
	end
	if v.camera ~= 1 then
		table.insert(lines, "camera=" .. v.camera)
	end
	if v.drop_shadow then
		table.insert(lines, "dropshadow=t")
	end
	if v.real_time then
		table.insert(lines, "realtime=t")
	end
	if v.continue_music then
		table.insert(lines, "continuesublevelmusic=t")
	end
	if v.no_hurry then
		table.insert(lines, "nolowtime=t")
	end
	if v.no_coinlimit then
		table.insert(lines, "nocoinlimit=t")
	end
	return table.concat(lines, "\n")
end

local function mp_texttxt(v)
	local hidden = {}
	for i = 1, 10 do
		hidden[i] = tostring(v.hidden[i])
	end
	local lines = {
		"endingtextcolor=" .. colourstring(v.ending_colour),
		"endingcolorname=" .. COLOURS[v.ending_colour]:lower(),
		"endingtext=" .. v.ending1:lower() .. "," .. v.ending2:lower(),
	}
	if not v.use_character_name then
		table.insert(lines, "playername=" .. v.player_name)
	end
	table.insert(lines, "hudtextcolor=" .. colourstring(v.hud_colour))
	table.insert(lines, "hudcolorname=" .. COLOURS[v.hud_colour]:lower())
	table.insert(lines, "hudvisible=" .. tostring(v.visible_hud))
	table.insert(lines, "hudworldletter=" .. tostring(v.letters_world))
	table.insert(lines, "hudoutline=" .. tostring(v.outlined_hud))
	table.insert(lines, "hudsimple=" .. tostring(v.simple_hud))
	table.insert(lines, "toadtext=" .. v.toad1:lower() .. "," .. v.toad2:lower() .. "," .. v.toad3:lower())
	table.insert(lines, "peachtext=" .. table.concat({v.peach1:lower(), v.peach2:lower(), v.peach3:lower(), v.peach4:lower(), v.peach5:lower()}, ","))
	table.insert(lines, "steve=" .. tostring(v.allow_cheats))
	table.insert(lines, "hudhidecollectables=" .. table.concat(hidden, ","))
	return table.concat(lines, "\n")
end

--a blank 25x15 course: sky with two rows of ground
local function mp_coursedata(v)
	local tiles = {}
	for i = 1, 325 do
		tiles[i] = "1"
	end
	for i = 326, 375 do
		tiles[i] = "2"
	end
	local portalgun = "portalguni=" .. v.portalgun
	if v.portalgun == 2 then --"none"
		portalgun = "noportalgun"
	end
	return table.concat({
		table.concat(tiles, ","),
		"height=15", "background=1", "spriteset=1", "music=1",
		portalgun,
		"timelimit=" .. v.time_limit,
		"scrollfactor=" .. numbertostring(v.bgx),
		"scrollfactory=" .. numbertostring(v.bgy),
		"scrollfactor2=" .. numbertostring(v.fgx),
		"scrollfactor2y=" .. numbertostring(v.fgy),
	}, ";")
end

local function mp_createjob(v)
	local name = v.name
	local path = mappackfolder .. "/" .. name
	mpcreating = true
	mpstatus, mpstatuscolor = T("creating files..."), {255, 255, 255}

	if not love.filesystem.createDirectory(path) then
		error(T("couldn't make the mappack folder"), 0)
	end
	love.filesystem.write(path .. "/settings.txt", mp_settingstxt(v))
	love.filesystem.write(path .. "/text.txt", mp_texttxt(v))
	if mpicon then
		mpicon:encode("png", path .. "/icon.png")
	end
	for _, folder in ipairs(SUBFOLDERS) do
		love.filesystem.createDirectory(path .. "/" .. folder)
	end

	local marker = ""
	if v.prevent_delete then
		marker = "cannot delete"
	end
	love.filesystem.write(path .. "/made_by_mappack_creator", marker)
	mpsession[name:lower()] = true

	local data = mp_coursedata(v)
	local subzones = v.subzones_per_course
	if v.no_subzones then
		subzones = 0
	end
	mpprogress = {done = 0, total = mp_filecount(v)}

	local function writefile(filename)
		if not love.filesystem.write(path .. "/" .. filename, data) then
			error(TF("couldn't write %s", filename), 0)
		end
		mpprogress.done = mpprogress.done + 1
		if mpprogress.done % 100 == 0 then
			coroutine.yield()
		end
	end

	for world = 1, v.world_count do
		for course = 1, v.courses_per_world do
			writefile(world .. "-" .. course .. ".txt")
			for subzone = 1, subzones do
				writefile(world .. "-" .. course .. "_" .. subzone .. ".txt")
			end
		end
	end

	mpcreating = false
	mpstatus, mpstatuscolor = T("finished!"), {100, 255, 100}
	mp_refreshexisting()
	notice.new(T("mappack created successfully!"), nil, 4)
end

local function mp_create()
	mp_refreshexisting()
	mp_validate()
	if job or not mpcheck.valid then
		return
	end
	local v = mpcheck.values
	startjob(function() mp_createjob(v) end, function(err)
		mpcreating = false
		mpstatus, mpstatuscolor = T("generation failed..."), {255, 80, 80}
		notice.new(err, notice.red, 5)
		local path = mappackfolder .. "/" .. v.name
		if insavedirectory(path) then
			startjob(function() removerecursive(path) mp_refreshexisting() end)
		end
	end)
end

local function mp_delete()
	local name = tostring(mp.name)
	local state = mp_deletestate(name)
	if job or not (state == "session" or state == "marker") then
		return
	end
	local path = mappackfolder .. "/" .. mpexisting[name:lower()]
	mpstatus, mpstatuscolor = T("deleting..."), {255, 255, 255}
	startjob(function()
		removerecursive(path)
		mpsession[name:lower()] = nil
		mp_refreshexisting()
		mpprogress = nil
		mpstatus, mpstatuscolor = TF("deleted %s", name), {255, 255, 255}
	end, function(err)
		mpstatus, mpstatuscolor = T("couldn't delete it"), {255, 80, 80}
		mp_refreshexisting()
	end)
end

------------------------------------------------------------
-- mappack creator: project files (.mpckproj, .json, .cfg)
------------------------------------------------------------

local function mp_icondata()
	if not mpicon then
		return nil
	end
	return love.data.encode("string", "base64", mpicon:encode("png"):getString())
end

local function mp_loadicondata(data)
	if type(data) ~= "string" or data == "" or data == "None" or data == "nil" or data == "null" then
		mp_seticon(nil)
		return
	end
	local ok, imagedata = pcall(function()
		local bytes = love.data.decode("string", "base64", data)
		return love.image.newImageData(love.filesystem.newFileData(bytes, "icon.png"))
	end)
	if ok then
		mp_seticon(imagedata)
	else
		mp_seticon(nil)
	end
end

local function mp_projectjson(v, icon)
	return JSON:encode_pretty({
		general = {
			name = v.name, display_name = v.display_name, author = v.author, description = v.description,
			icon = icon, lives = v.lives, physics = PHYSICS[v.physics], camera = CAMERA[v.camera],
			drop_shadow = v.drop_shadow, real_time = v.real_time, continue_music = v.continue_music,
			no_hurry = v.no_hurry, no_coinlimit = v.no_coinlimit,
			world_count = v.world_count, courses_per_world = v.courses_per_world,
			subzones_per_course = v.subzones_per_course, no_subzones = v.no_subzones,
		},
		text = {
			player_name = v.player_name, use_character_name = v.use_character_name,
			hud_colour = COLOURS[v.hud_colour], letters_world = v.letters_world, visible_hud = v.visible_hud,
			outlined_hud = v.outlined_hud, simple_hud = v.simple_hud,
			ending1 = v.ending1, ending2 = v.ending2, ending_colour = COLOURS[v.ending_colour],
			toad = {v.toad1, v.toad2, v.toad3},
			peach = {v.peach1, v.peach2, v.peach3, v.peach4, v.peach5},
			allow_cheats = v.allow_cheats, hidden_collectables = v.hidden,
		},
		course_defaults = {
			time_limit = v.time_limit, portalgun = PORTALGUN[v.portalgun],
			background_scroll = {x = v.bgx, y = v.bgy},
			foreground_scroll = {x = v.fgx, y = v.fgy},
		},
	})
end

local function mp_projectcfg(v, icon)
	local hidden = {}
	for i = 1, 10 do
		hidden[i] = tostring(v.hidden[i])
	end
	local lines = {
		"# Mari0 Mappack Creator Project",
		"[General]",
		"name=" .. v.name, "display_name=" .. v.display_name, "author=" .. v.author,
		"description=" .. v.description, "icon=" .. (icon or ""), "lives=" .. v.lives,
		"physics=" .. v.physics, "camera=" .. v.camera,
		"",
		"[Flags]",
		"drop_shadow=" .. tostring(v.drop_shadow), "real_time=" .. tostring(v.real_time),
		"continue_music=" .. tostring(v.continue_music), "no_hurry=" .. tostring(v.no_hurry),
		"no_coinlimit=" .. tostring(v.no_coinlimit),
		"",
		"[Worlds]",
		"world_count=" .. v.world_count, "courses_per_world=" .. v.courses_per_world,
		"subzones_per_course=" .. v.subzones_per_course, "no_subzones=" .. tostring(v.no_subzones),
		"",
		"[Text]",
		"player_name=" .. v.player_name, "use_character_name=" .. tostring(v.use_character_name),
		"hud_colour=" .. COLOURS[v.hud_colour], "letters_world=" .. tostring(v.letters_world),
		"visible_hud=" .. tostring(v.visible_hud), "outlined_hud=" .. tostring(v.outlined_hud),
		"simple_hud=" .. tostring(v.simple_hud),
		"ending1=" .. v.ending1, "ending2=" .. v.ending2, "ending_colour=" .. COLOURS[v.ending_colour],
		"toad1=" .. v.toad1, "toad2=" .. v.toad2, "toad3=" .. v.toad3,
		"peach1=" .. v.peach1, "peach2=" .. v.peach2, "peach3=" .. v.peach3, "peach4=" .. v.peach4, "peach5=" .. v.peach5,
		"allow_cheats=" .. tostring(v.allow_cheats), "hidden_collectables=" .. table.concat(hidden, ","),
		"",
		"[Course]",
		"time_limit=" .. v.time_limit, "portalgun=" .. PORTALGUN[v.portalgun],
		"background_x=" .. numbertostring(v.bgx), "background_y=" .. numbertostring(v.bgy),
		"foreground_x=" .. numbertostring(v.fgx), "foreground_y=" .. numbertostring(v.fgy),
		"",
	}
	return table.concat(lines, "\n")
end

local function mp_projectmpck(v, icon)
	local hidden = {}
	for i = 1, 10 do
		hidden[i] = tostring(v.hidden[i])
	end
	local function q(s)
		return '"' .. s .. '"'
	end
	local lines = {
		"MARIO_MAPPACK_PROJECT",
		"GENERAL {",
		"    NAME " .. q(v.name),
		"    DISPLAY_NAME " .. q(v.display_name),
		"    AUTHOR " .. q(v.author),
		"    DESCRIPTION " .. q(v.description),
		"    ICON " .. q(icon or "None"),
		"    LIVES " .. v.lives,
		"    PHYSICS " .. q(PHYSICS[v.physics]),
		"    CAMERA " .. q(CAMERA[v.camera]),
		"}",
		"",
		"OPTIONS {",
		"    DROP_SHADOW " .. tostring(v.drop_shadow),
		"    REAL_TIME " .. tostring(v.real_time),
		"    CONTINUE_MUSIC " .. tostring(v.continue_music),
		"    NO_HURRY " .. tostring(v.no_hurry),
		"    NO_COINLIMIT " .. tostring(v.no_coinlimit),
		"}",
		"",
		"LAYOUT {",
		"    WORLDS " .. v.world_count,
		"    COURSES_PER_WORLD " .. v.courses_per_world,
		"    SUBZONES_PER_COURSE " .. v.subzones_per_course,
		"    NO_SUBZONES " .. tostring(v.no_subzones),
		"}",
		"",
		"TEXT {",
		"    PLAYER_NAME " .. q(v.player_name),
		"    USE_CHARACTER_NAME " .. tostring(v.use_character_name),
		"",
		"    HUD_COLOUR " .. q(COLOURS[v.hud_colour]),
		"    ENDING_COLOUR " .. q(COLOURS[v.ending_colour]),
		"    LETTERS_WORLD " .. tostring(v.letters_world),
		"    VISIBLE_HUD " .. tostring(v.visible_hud),
		"    OUTLINED_HUD " .. tostring(v.outlined_hud),
		"    SIMPLE_HUD " .. tostring(v.simple_hud),
		"",
		"    ENDING_TEXT {",
		"        " .. q(v.ending1),
		"        " .. q(v.ending2),
		"    }",
		"",
		"    TOAD_TEXT {",
		"        " .. q(v.toad1),
		"        " .. q(v.toad2),
		"        " .. q(v.toad3),
		"    }",
		"",
		"    PEACH_TEXT {",
		"        " .. q(v.peach1),
		"        " .. q(v.peach2),
		"        " .. q(v.peach3),
		"        " .. q(v.peach4),
		"        " .. q(v.peach5),
		"    }",
		"",
		"    ALLOW_CHEATS " .. tostring(v.allow_cheats),
		"",
		"    HIDDEN_COLLECTABLES {" .. table.concat(hidden, ", ") .. "}",
		"}",
		"",
		"COURSE_DEFAULTS {",
		"    TIME_LIMIT " .. v.time_limit,
		"    PORTALGUN " .. q(PORTALGUN[v.portalgun]),
		"",
		"    BACKGROUND_SCROLL {",
		"        X " .. numbertostring(v.bgx),
		"        Y " .. numbertostring(v.bgy),
		"    }",
		"",
		"    FOREGROUND_SCROLL {",
		"        X " .. numbertostring(v.fgx),
		"        Y " .. numbertostring(v.fgy),
		"    }",
		"}",
		"",
	}
	return table.concat(lines, "\n")
end

--project data -> a table with the creator's keys (missing values stay nil)
local function mp_parsejson(data)
	local oldcrash = JSONcrashgame
	JSONcrashgame = false
	local ok, project = pcall(function() return JSON:decode(data) end)
	JSONcrashgame = oldcrash
	if not ok or type(project) ~= "table" then
		error(T("that .json project has an error in it"), 0)
	end
	local g = project.general or {}
	local t = project.text or {}
	local c = project.course_defaults or {}
	local p = {
		name = g.name, display_name = g.display_name, author = g.author, description = g.description,
		icon = g.icon, lives = g.lives,
		physics = optionindex(PHYSICS, g.physics), camera = optionindex(CAMERA, g.camera),
		drop_shadow = g.drop_shadow, real_time = g.real_time, continue_music = g.continue_music,
		no_hurry = g.no_hurry, no_coinlimit = g.no_coinlimit,
		world_count = g.world_count, courses_per_world = g.courses_per_world,
		subzones_per_course = g.subzones_per_course, no_subzones = g.no_subzones,
		player_name = t.player_name, use_character_name = t.use_character_name,
		hud_colour = optionindex(COLOURS, t.hud_colour), letters_world = t.letters_world,
		visible_hud = t.visible_hud, outlined_hud = t.outlined_hud, simple_hud = t.simple_hud,
		ending1 = t.ending1, ending2 = t.ending2, ending_colour = optionindex(COLOURS, t.ending_colour),
		allow_cheats = t.allow_cheats,
		time_limit = c.time_limit, portalgun = optionindex(PORTALGUN, c.portalgun),
	}
	if type(t.toad) == "table" and #t.toad >= 3 then
		p.toad1, p.toad2, p.toad3 = t.toad[1], t.toad[2], t.toad[3]
	end
	if type(t.peach) == "table" and #t.peach >= 5 then
		p.peach1, p.peach2, p.peach3, p.peach4, p.peach5 = t.peach[1], t.peach[2], t.peach[3], t.peach[4], t.peach[5]
	end
	if type(t.hidden_collectables) == "table" then
		p.hidden = t.hidden_collectables
	end
	if type(c.background_scroll) == "table" then
		p.bgx, p.bgy = c.background_scroll.x, c.background_scroll.y
	end
	if type(c.foreground_scroll) == "table" then
		p.fgx, p.fgy = c.foreground_scroll.x, c.foreground_scroll.y
	end
	return p
end

local function mp_parsecfg(data)
	local sections, current = {}, nil
	for line in (data .. "\n"):gmatch("(.-)\r?\n") do
		line = line:match("^%s*(.-)%s*$")
		if line ~= "" and line:sub(1, 1) ~= "#" then
			local section = line:match("^%[(.*)%]$")
			if section then
				current = section
				sections[current] = {}
			elseif current and line:find("=") then
				local key, value = line:match("^([^=]*)=(.*)$")
				sections[current][key] = value
			end
		end
	end
	local g, f, w, t, c = sections.General or {}, sections.Flags or {}, sections.Worlds or {}, sections.Text or {}, sections.Course or {}
	local p = {
		name = g.name, display_name = g.display_name, author = g.author, description = g.description,
		icon = g.icon, lives = g.lives,
		physics = optionindex(PHYSICS, tonumber(g.physics)), camera = optionindex(CAMERA, tonumber(g.camera)),
		drop_shadow = tobool(f.drop_shadow), real_time = tobool(f.real_time), continue_music = tobool(f.continue_music),
		no_hurry = tobool(f.no_hurry), no_coinlimit = tobool(f.no_coinlimit),
		world_count = w.world_count, courses_per_world = w.courses_per_world,
		subzones_per_course = w.subzones_per_course, no_subzones = tobool(w.no_subzones),
		player_name = t.player_name, use_character_name = tobool(t.use_character_name),
		hud_colour = optionindex(COLOURS, t.hud_colour), letters_world = tobool(t.letters_world),
		visible_hud = tobool(t.visible_hud), outlined_hud = tobool(t.outlined_hud), simple_hud = tobool(t.simple_hud),
		ending1 = t.ending1, ending2 = t.ending2, ending_colour = optionindex(COLOURS, t.ending_colour),
		toad1 = t.toad1, toad2 = t.toad2, toad3 = t.toad3,
		peach1 = t.peach1, peach2 = t.peach2, peach3 = t.peach3, peach4 = t.peach4, peach5 = t.peach5,
		allow_cheats = tobool(t.allow_cheats),
		time_limit = c.time_limit, portalgun = optionindex(PORTALGUN, c.portalgun),
		bgx = c.background_x, bgy = c.background_y, fgx = c.foreground_x, fgy = c.foreground_y,
	}
	if t.hidden_collectables then
		p.hidden = {}
		for value in (t.hidden_collectables .. ","):gmatch("(.-),") do
			table.insert(p.hidden, tobool(value:match("^%s*(.-)%s*$")))
		end
	end
	return p
end

local function mp_parsempck(data)
	local function value(pattern)
		return data:match(pattern)
	end
	local function quoted(key)
		return value("%f[%w_]" .. key .. ' "(.-)"')
	end
	local function word(key)
		return value("%f[%w_]" .. key .. " ([%w%.]+)")
	end
	local function block(key)
		local inner = value(key .. "%s*{(.-)}")
		local lines = {}
		if inner then
			for line in inner:gmatch("[^\r\n]+") do
				line = line:match("^%s*(.-)%s*$")
				if line ~= "" then
					table.insert(lines, (line:gsub('^"', ""):gsub('"$', "")))
				end
			end
		end
		return lines
	end

	local p = {
		name = quoted("NAME"), display_name = quoted("DISPLAY_NAME"), author = quoted("AUTHOR"),
		description = quoted("DESCRIPTION"), icon = quoted("ICON"), lives = word("LIVES"),
		physics = optionindex(PHYSICS, quoted("PHYSICS")), camera = optionindex(CAMERA, quoted("CAMERA")),
		drop_shadow = tobool(word("DROP_SHADOW")), real_time = tobool(word("REAL_TIME")),
		continue_music = tobool(word("CONTINUE_MUSIC")), no_hurry = tobool(word("NO_HURRY")),
		no_coinlimit = tobool(word("NO_COINLIMIT") or word("NO_COIN_LIMIT")),
		world_count = word("WORLDS"), courses_per_world = word("COURSES_PER_WORLD"),
		subzones_per_course = word("SUBZONES_PER_COURSE"), no_subzones = tobool(word("NO_SUBZONES")),
		player_name = quoted("PLAYER_NAME"), use_character_name = tobool(word("USE_CHARACTER_NAME")),
		hud_colour = optionindex(COLOURS, quoted("HUD_COLOUR")), ending_colour = optionindex(COLOURS, quoted("ENDING_COLOUR")),
		letters_world = tobool(word("LETTERS_WORLD")), visible_hud = tobool(word("VISIBLE_HUD")),
		outlined_hud = tobool(word("OUTLINED_HUD")), simple_hud = tobool(word("SIMPLE_HUD")),
		allow_cheats = tobool(word("ALLOW_CHEATS")),
		time_limit = word("TIME_LIMIT"), portalgun = optionindex(PORTALGUN, quoted("PORTALGUN")),
	}
	local ending = block("ENDING_TEXT")
	if #ending >= 2 then
		p.ending1, p.ending2 = ending[1], ending[2]
	end
	local toad = block("TOAD_TEXT")
	if #toad >= 3 then
		p.toad1, p.toad2, p.toad3 = toad[1], toad[2], toad[3]
	end
	local peach = block("PEACH_TEXT")
	if #peach >= 5 then
		p.peach1, p.peach2, p.peach3, p.peach4, p.peach5 = peach[1], peach[2], peach[3], peach[4], peach[5]
	end
	local hidden = value("HIDDEN_COLLECTABLES%s*{(.-)}")
	if hidden then
		p.hidden = {}
		for v in (hidden .. ","):gmatch("(.-),") do
			table.insert(p.hidden, tobool(v:match("^%s*(.-)%s*$")))
		end
	end
	p.bgx, p.bgy = value("BACKGROUND_SCROLL%s*{%s*X ([%d%.]+)%s*Y ([%d%.]+)")
	p.fgx, p.fgy = value("FOREGROUND_SCROLL%s*{%s*X ([%d%.]+)%s*Y ([%d%.]+)")
	return p
end

local NUMBERKEYS = {lives = true, world_count = true, courses_per_world = true, subzones_per_course = true, time_limit = true, bgx = true, bgy = true, fgx = true, fgy = true}

local function mp_apply(p)
	local keep = {prevent_delete = mp.prevent_delete, projectformat = mp.projectformat, projectsel = mp.projectsel}
	mp = mp_defaults()
	for key, value in pairs(keep) do
		mp[key] = value
	end
	for key, value in pairs(p) do
		if key == "icon" then
			--handled below
		elseif key == "hidden" then
			for i = 1, 10 do
				mp.hidden[i] = tobool(value[i], false)
			end
		elseif NUMBERKEYS[key] then
			local n = tonumber(value)
			if n then
				mp[key] = numbertostring(n)
			end
		elseif type(mp[key]) == "string" and value ~= nil then
			mp[key] = tostring(value):lower() --capitals don't show up right in the game's text boxes
		elseif mp[key] ~= nil and value ~= nil then
			mp[key] = value
		end
	end
	mp_loadicondata(p.icon)
end

local function mp_loadproject(data, ext)
	local ok, result = pcall(function()
		if ext == "json" then
			return mp_parsejson(data)
		elseif ext == "cfg" then
			return mp_parsecfg(data)
		elseif ext == "mpckproj" then
			return mp_parsempck(data)
		end
		error(T("this project format is not supported."), 0)
	end)
	if not ok then
		notice.new(tostring(result), notice.red, 4)
		return
	end
	mp_apply(result)
	mp_build()
	notice.new(T("mappack project loaded successfully!"), nil, 3)
end

local function mp_saveproject()
	local v = mp_values()
	local ext = PROJECTFORMATS[mp.projectformat]
	local filename = v.name:gsub('[/\\:%*%?"<>|]', "_")
	if filename:match("^%s*$") then
		filename = "new mappack"
	end
	local icon = mp_icondata()
	local data
	if ext == "json" then
		data = mp_projectjson(v, icon)
	elseif ext == "cfg" then
		data = mp_projectcfg(v, icon)
	else
		data = mp_projectmpck(v, icon)
	end
	love.filesystem.createDirectory(PROJECTFOLDER)
	local path = PROJECTFOLDER .. "/" .. filename .. "." .. ext
	if love.filesystem.write(path, data) then
		notice.new(TF("saved project to %s", path), nil, 4)
	else
		notice.new(T("couldn't save the project"), notice.red, 4)
	end
	mp_refreshprojects()
	mp_build()
end

local function mp_reset()
	mp_apply({})
	mp_seticon(nil)
	mp_build()
	notice.new(T("everything is back to default."), nil, 3)
end

------------------------------------------------------------
-- mappack creator: gui
------------------------------------------------------------

local function mpslider(key, x, y, trackwidth, minimum, maximum, step, tab)
	local slider = newslider(x, y, trackwidth, minimum, maximum, step, mp[key])
	slider.backgroundcolor = {40, 40, 40}
	slider.utilskey = key
	table.insert(mpsliders, slider)
	return add("mp_" .. key, slider, tab)
end

local function mpstepper(key, x, y, digits, minimum, maximum, step, tab)
	return newstepper("mp_" .. key, x, y, digits, minimum, maximum, step,
		function() return mp[key] end,
		function(n) mp[key] = tostring(n) end, tab)
end

local function mpinput(key, x, y, w, maxlength, tab, numeric, h)
	local el = newinput(x, y, w, mp[key], maxlength, h)
	el.utilsnumeric = numeric
	table.insert(mpbinds, {el = el, key = key})
	return add("mp_" .. key, el, tab)
end

local function mpcheckbox(key, x, y, text, tab)
	local el
	el = guielement:new("checkbox", x, y, function(v)
		el.var = v
		mp[key] = v
	end, mp[key], ui.line(text))
	return add("mp_" .. key, el, tab)
end

--w is the smallest width; it grows to fit the longest (translated) option, but never past the panel
--translate: show the options in the current language (the values stay english, project files need them)
local function mpdropdown(key, x, y, w, options, tab, coloured, translate)
	local display = lowered(options)
	if translate then
		for i, v in ipairs(display) do
			display[i] = T(v)
		end
	end
	for _, v in ipairs(display) do
		w = math.max(w, utf8.len(v))
	end
	w = math.min(w, math.floor((panelright() - 5 - x - 13)/8))

	local el
	el = guielement:new("dropdown", x, y, w, function(i)
		el.var = i
		mp[key] = i
	end, mp[key], unpack(lowered(options)))
	el.displayentries = display
	if coloured then
		--coloured by number, since gui.lua would look the translated name up in textcolors
		el.entrycolors = {}
		for i = 1, #options do
			if options[i] == "Black" then
				el.entrycolors[i] = {80, 80, 80}
			else
				el.entrycolors[i] = textcolors[options[i]:lower()] or {255, 255, 255}
			end
		end
	end
	return add("mp_" .. key, el, tab)
end

mp_build = function()
	if not mp then
		mp = mp_defaults()
	end
	clearelements()
	mpbinds = {}
	mpsliders = {}
	mp_refreshexisting()
	mp_refreshprojects()

	--every tab puts its fields after its longest label, so translations don't run into them
	local col
	local hint = {150, 150, 150}

	--general
	local t = "general"
	col = ui.columnx(132, T("name:"), T("display name:"), T("author:"), T("description:"), T("lives:"), T("physics:"), T("camera:"))
	local frame = ui.iconframe
	frame.x = clamp(col + 5 + 17*8 + 8, 300, panelright() - 5 - frame.size)
	local inputw = math.min(17, math.floor((frame.x - 8 - col - 5)/8))
	label(26, 37, T("name:"), t)
	mpinput("name", col, 35, inputw, 64, t)
	label(26, 51, T("display name:"), t)
	mpinput("display_name", col, 49, inputw, 17, t)
	label(26, 65, T("author:"), t)
	mpinput("author", col, 63, math.min(13, inputw), 13, t)
	label(26, 79, T("description:"), t)
	mpinput("description", col, 77, inputw, 51, t, nil, 3)
	label(26, 117, T("lives:"), t)
	mpstepper("lives", col, 116, 4, 0, 9999, 1, t)
	ui.mp.livesx = col + 68
	label(26, 133, T("physics:"), t)
	mpdropdown("physics", col, 131, 12, PHYSICS, t)
	label(26, 147, T("camera:"), t)
	mpdropdown("camera", col, 145, 13, CAMERA, t, false, true)
	--"icon" sits left of the clear button; if the translation doesn't fit there it goes inside the empty frame
	local cleartext = T("clear")
	local clearx = panelright() - 2 - (3 + ui.textw(cleartext))
	ui.mp.iconlabel = frame.x + ui.textw(T("icon")) + 2 <= clearx
	if ui.mp.iconlabel then
		label(frame.x, 37, T("icon"), t)
	end
	add("mp_iconclear", newbutton(clearx, 34, cleartext, function() mp_seticon(nil) end), t)
	for i, line in ipairs(wraptext(T("drop a .png onto the window to use it as the icon, or a project file to load it"), 43)) do
		label(26, 172 + (i-1)*10, line, t, hint)
	end

	--worlds
	t = "worlds"
	mpcheckbox("drop_shadow", 26, 36, "drop shadow", t)
	ui.mp.performancex = math.max(150, 26 + 9 + ui.textw(ui.line("drop shadow")) + 12)
	mpcheckbox("real_time", 26, 50, "real time", t)
	mpcheckbox("continue_music", 26, 64, "continue subzone music", t)
	mpcheckbox("no_hurry", 26, 78, "no hurry music", t)
	mpcheckbox("no_coinlimit", 26, 92, "no coin limit", t)
	col = ui.columnx(190, T("world count:"), T("courses per world:"), T("subzones per course:"))
	ui.mp.worldsx = col
	label(26, 113, T("world count:"), t)
	mpslider("world_count", col, 112, panelright() - 9 - col, 1, 999, 1, t)
	label(26, 127, T("courses per world:"), t)
	mpslider("courses_per_world", col, 126, panelright() - 9 - col, 1, 99, 1, t)
	label(26, 141, T("subzones per course:"), t)
	mpslider("subzones_per_course", col, 140, panelright() - 9 - col, 1, 13, 1, t)
	mpcheckbox("no_subzones", 26, 155, "do not create subzones", t)
	label(26, 186, T("right click a slider to type a value."), t, hint)

	--hud
	t = "hud"
	col = ui.columnx(124, T("player name:"), T("hud colour:"))
	ui.mp.hudx = col
	label(26, 37, T("player name:"), t)
	mpinput("player_name", col, 35, 12, 12, t)
	mpcheckbox("use_character_name", 26, 51, "use character name for player name", t)
	label(26, 67, T("hud colour:"), t)
	mpdropdown("hud_colour", col, 65, 6, COLOURS, t, true, true)
	mpcheckbox("letters_world", 26, 81, "use letters for worlds above 9", t)
	mpcheckbox("visible_hud", 26, 95, "visible hud", t)
	mpcheckbox("outlined_hud", 26, 109, "outlined hud", t)
	mpcheckbox("simple_hud", 26, 123, "simple hud", t)
	mpcheckbox("allow_cheats", 26, 137, "allow cheats", t)
	label(26, 157, T("hide hud collectables:"), t)
	for i = 1, 10 do
		local el
		el = guielement:new("checkbox", 26 + (i-1)*34, 169, function(v)
			el.var = v
			mp.hidden[i] = v
		end, mp.hidden[i], tostring(i))
		add("mp_hidden" .. i, el, t)
	end

	--text
	t = "text"
	col = ui.columnx(98, T("ending 1:"), T("ending 2:"), T("colour:"), TF("toad %s:", 3), TF("peach %s:", 5))
	inputw = math.min(32, math.floor((panelright() - 5 - col - 5)/8))
	label(26, 36, T("ending 1:"), t)
	mpinput("ending1", col, 34, inputw, 32, t)
	label(26, 49, T("ending 2:"), t)
	mpinput("ending2", col, 47, inputw, 32, t)
	label(26, 63, T("colour:"), t)
	mpdropdown("ending_colour", col, 61, 6, COLOURS, t, true, true)
	for i = 1, 3 do
		label(26, 80 + (i-1)*13, TF("toad %s:", i), t)
		mpinput("toad" .. i, col, 78 + (i-1)*13, inputw, 32, t)
	end
	for i = 1, 5 do
		label(26, 122 + (i-1)*13, TF("peach %s:", i), t)
		mpinput("peach" .. i, col, 120 + (i-1)*13, inputw, 32, t)
	end

	--course
	t = "course"
	col = ui.columnx(190, T("time limit:"), T("portal gun:"), T("background scroll x:"), T("background scroll y:"), T("foreground scroll x:"), T("foreground scroll y:"))
	ui.mp.timex = col + 64
	label(26, 37, T("time limit:"), t)
	mpstepper("time_limit", col, 36, 4, 0, 9999, 10, t)
	label(26, 53, T("portal gun:"), t)
	mpdropdown("portalgun", col, 51, 6, PORTALGUN, t, false, true)
	label(26, 69, T("background scroll x:"), t)
	mpslider("bgx", col, 68, panelright() - 9 - col, 0, 9, 0.1, t)
	label(26, 83, T("background scroll y:"), t)
	mpslider("bgy", col, 82, panelright() - 9 - col, 0, 9, 0.1, t)
	label(26, 97, T("foreground scroll x:"), t)
	mpslider("fgx", col, 96, panelright() - 9 - col, 0, 9, 0.1, t)
	label(26, 111, T("foreground scroll y:"), t)
	mpslider("fgy", col, 110, panelright() - 9 - col, 0, 9, 0.1, t)
	label(26, 131, T("these are used by every new course."), t, hint)
	label(26, 141, T("right click a slider to type a value."), t, hint)

	--create
	t = "create"
	mpcheckbox("prevent_delete", 26, 35, "prevent deletion from the mappack creator", t)
	local createtext = T("create mappack")
	add("mp_create", newbutton(26, 128, createtext, mp_create), t)
	local delete = confirmbutton("mp_delete", math.max(160, 26 + 3 + ui.textw(createtext) + 19), 128, T("delete mappack"), mp_delete)
	elements[#elements].tab = t
	delete.textcolor = {255, 80, 80}

	--the save/load buttons share a width, and the dropdowns line up after the wider one
	local savetext, loadtext = T("save project"), T("load project")
	local projectw = math.max(ui.textw(savetext), ui.textw(loadtext))
	col = math.max(130, 26 + 3 + projectw + 5)
	ui.mp.projectsx = col
	add("mp_save", newbutton(26, 145, savetext, mp_saveproject, projectw), t)
	local format
	format = add("mp_format", guielement:new("dropdown", col, 145, 9, function(i)
		format.var = i
		mp.projectformat = i
	end, mp.projectformat, unpack(PROJECTFORMATS)), t)
	format.displayentries = {".mpckproj", ".json", ".cfg"}

	add("mp_load", newbutton(26, 162, loadtext, function()
		local file = mpprojects[mp.projectsel]
		if not file then
			return
		end
		local data = love.filesystem.read(PROJECTFOLDER .. "/" .. file)
		if data then
			mp_loadproject(data, (file:match("%.([^%.]+)$") or ""):lower())
		end
	end, projectw), t)
	if #mpprojects > 0 then
		mp.projectsel = clamp(mp.projectsel, 1, #mpprojects)
		local projects
		projects = add("mp_projects", guielement:new("dropdown", col, 162, math.min(22, math.floor((panelright() - 5 - col - 13)/8)), function(i)
			projects.var = i
			mp.projectsel = i
		end, mp.projectsel, unpack(mpprojects)), t)
		projects.displayentries = lowered(mpprojects)
	end

	local reset = confirmbutton("mp_reset", 26, 179, T("reset properties"), mp_reset)
	elements[#elements].tab = t
	ui.mp.statusx = math.max(168, 26 + 3 + reset.width + 3)

	ui.addback()
end

local function mp_update()
	--text fields and sliders -> values
	for _, bind in ipairs(mpbinds) do
		mp[bind.key] = tostring(bind.el.value)
	end
	for _, slider in ipairs(mpsliders) do
		mp[slider.utilskey] = numbertostring(slidervalue(slider))
	end
	updatesteppers()

	--simple hud always uses the character's name
	local usename = named["mp_use_character_name"]
	if mp.simple_hud then
		mp.use_character_name = true
		usename.var = true
	end
	usename.utilsdisabled = mp.simple_hud
	named["mp_player_name"].utilshidden = mp.use_character_name
	named["mp_subzones_per_course"].utilshidden = mp.no_subzones
	named["mp_iconclear"].utilsdisabled = (mpicon == nil)

	if love.timer.getTime() - mpexistingtime > 2 then
		mp_refreshexisting()
	end
	mp_validate()

	named["mp_create"].utilsdisabled = (job ~= nil) or not mpcheck.valid
	local state = mp_deletestate(tostring(mp.name))
	named["mp_delete"].utilsdisabled = (job ~= nil) or mpcreating or not (state == "session" or state == "marker")
	named["mp_save"].utilsdisabled = (job ~= nil)
	named["mp_load"].utilsdisabled = (job ~= nil) or #mpprojects == 0
	named["mp_reset"].utilsdisabled = (job ~= nil)
end

local function mp_tabrects()
	local rects = {}
	local x = 26
	for i, name in ipairs(MPTABS) do
		local w = utf8.len(T(name))*8
		rects[i] = {x = x, w = w}
		x = x + w + 6
	end
	return rects
end

--colour of the "files to create" count: each warning has a colour, and counts in between
--blend between the two nearest ones with hsv_lerp (on a log scale, since the warnings go up by 10x)
local function filecountcolour(count)
	local stops = {
		{MAPPACKCREATOR_FILEWARNING/10, {150, 150, 150}},
		{MAPPACKCREATOR_FILEWARNING, {252, 152, 56}},
		{MAPPACKCREATOR_FILEWARNING_BIG, {252, 80, 80}},
		{MAPPACKCREATOR_FILEWARNING_HUGE, {255, 0, 0}},
		{MAPPACKCREATOR_FILEWARNING_GOODGOD, {127, 0, 0}},
	}
	local function logof(n)
		return math.log(math.max(n, 1))
	end

	if count <= stops[1][1] then
		local c = stops[1][2]
		return c[1], c[2], c[3]
	end
	for i = 2, #stops do
		local from, to = stops[i-1], stops[i]
		if count < to[1] then
			local t = 1
			if logof(to[1]) > logof(from[1]) then
				t = (logof(count) - logof(from[1]))/(logof(to[1]) - logof(from[1]))
			end
			t = clamp(t, 0, 1)
			local c = hsv_lerp(from[2], to[2], t) --through hue, like the fps counter
			return c[1], c[2], c[3]
		end
	end
	local c = stops[#stops][2]
	return c[1], c[2], c[3]
end

function mpslide.index(name)
	for i, n in ipairs(MPTABS) do
		if n == name then
			return i
		end
	end
	return 1
end

--switches to another tab, sliding the old one out and the new one in
function mpslide.settab(name)
	if name == mptab then
		return
	end
	mpslide.anim = {from = mptab, to = name, start = love.timer.getTime()}
	mptab = name
end

local function mp_draw()
	drawpanel()

	--tab heads, like the options menu
	local rects = mp_tabrects()
	for i, name in ipairs(MPTABS) do
		local r = rects[i]
		if mptab == name then
			love.graphics.setColor(100, 100, 100, 100)
			love.graphics.rectangle("fill", (r.x-1)*scale, 20*scale, (r.w+3)*scale, 11*scale)
			love.graphics.setColor(255, 255, 255)
		else
			love.graphics.setColor(100, 100, 100)
		end
		if name == "create" and not mpcheck.valid and mptab ~= name then
			love.graphics.setColor(170, 60, 60)
		end
		properprintF(T(name), r.x*scale, 22*scale)
	end
	love.graphics.setColor(60, 60, 60)
	love.graphics.rectangle("fill", (PX+5)*scale, 32*scale, (panelwidth()-10)*scale, scale)

	--the open tab, or while switching tabs, the old tab sliding out and the new one sliding in, cut to the panel
	local progress = mpslide.progress()
	if progress then
		local anim = mpslide.anim
		local direction = mpslide.index(anim.to) > mpslide.index(anim.from) and 1 or -1
		local distance = panelwidth()
		ui.clipto(PX, PY, panelwidth(), PH, function()
			love.graphics.push()
			love.graphics.translate(-direction*progress*distance*scale, 0)
			mpslide.drawtab(anim.from)
			love.graphics.pop()
			love.graphics.push()
			love.graphics.translate(direction*(1 - progress)*distance*scale, 0)
			mpslide.drawtab(anim.to)
			love.graphics.pop()
		end)
	else
		mpslide.drawtab(mptab)
	end

	--what's on every tab (the back button) stays put
	drawlabels(false)
	drawelements(false)
end

--labels, elements and extras of one mappack creator tab
function mpslide.drawtab(tab)
	local v = mpcheck.values or mp_values()

	if tab == "general" then
		--icon preview
		local f = ui.iconframe
		local cx, cy = f.x + f.size/2, f.y + f.size/2
		drawswatch(f.x, f.y, f.size, f.size, {0, 0, 0})
		if mpiconimage then
			local iw, ih = mpiconimage:getDimensions()
			local s = math.min((f.size-4)/iw, (f.size-4)/ih)
			love.graphics.setColor(255, 255, 255)
			love.graphics.draw(mpiconimage, (cx - iw*s/2)*scale, (cy - ih*s/2)*scale, 0, s*scale, s*scale)
		elseif ui.mp.iconlabel then
			love.graphics.setColor(110, 110, 110)
			centredprint(T("blank"), cx, cy - 4)
		else
			--"icon" didn't fit above the frame, so the empty frame says it
			love.graphics.setColor(150, 150, 150)
			centredprint(T("icon"), cx, cy - 9)
			love.graphics.setColor(110, 110, 110)
			centredprint(T("blank"), cx, cy + 1)
		end
		if v.lives == 0 then
			love.graphics.setColor(100, 255, 100)
			properprintF(T("infinite lives!"), ui.mp.livesx*scale, 117*scale)
		end
	elseif tab == "worlds" then
		if mp.drop_shadow then
			love.graphics.setColor(255, 80, 80)
			properprintF(T("will reduce performance!"), ui.mp.performancex*scale, 37*scale)
		end
		if mp.no_subzones then
			love.graphics.setColor(150, 150, 150)
			properprintF(T("none"), ui.mp.worldsx*scale, 141*scale)
		end
		--fades from grey through orange and reds as the count passes each warning
		love.graphics.setColor(filecountcolour(mpcheck.filecount))
		properprintF(TF("files to create: %s", mpcheck.filecount), 26*scale, 172*scale)
	elseif tab == "hud" then
		if mp.use_character_name then
			love.graphics.setColor(150, 150, 150)
			properprintF(T("the character's name"), ui.mp.hudx*scale, 37*scale)
		end
	elseif tab == "course" then
		if v.time_limit == 0 then
			love.graphics.setColor(100, 255, 100)
			properprintF(T("infinite time!"), ui.mp.timex*scale, 37*scale)
		end
	elseif tab == "create" then
		local y = 50
		local maxlines = 7
		for _, message in ipairs(mpcheck.requirements) do
			for _, line in ipairs(wraptext(message, 43)) do
				if maxlines > 0 then
					love.graphics.setColor(255, 80, 80)
					properprintF(line, 26*scale, y*scale)
					y = y + 10
					maxlines = maxlines - 1
				end
			end
		end
		for _, message in ipairs(mpcheck.notices) do
			for _, line in ipairs(wraptext(message, 43)) do
				if maxlines > 0 then
					love.graphics.setColor(100, 255, 100)
					properprintF(line, 26*scale, y*scale)
					y = y + 10
					maxlines = maxlines - 1
				end
			end
		end
		if #mpcheck.requirements == 0 and #mpcheck.notices == 0 then
			love.graphics.setColor(150, 150, 150)
			properprintF(TF("ready to create '%s'", v.name), 26*scale, 50*scale)
			properprintF(TF("in %s", mappackfolder), 26*scale, 60*scale)
		end

		if #mpprojects == 0 then
			love.graphics.setColor(150, 150, 150)
			properprintF(T("no projects saved yet"), ui.mp.projectsx*scale, 164*scale)
		end

		if mpprogress then
			local p = 0
			if mpprogress.total > 0 then
				p = mpprogress.done/mpprogress.total
			end
			local color = {60, 100, 255}
			if not mpcreating then
				color = {60, 200, 60}
			end
			if mpstatuscolor[1] == 255 and mpstatuscolor[2] == 80 then
				color = {255, 60, 60}
			end
			drawprogress(26, 201, 200, p, color)
			love.graphics.setColor(150, 150, 150)
			local count = mpprogress.done .. "/" .. mpprogress.total
			properprintF(count, 232*scale, 201*scale)
		end
		love.graphics.setColor(mpstatuscolor)
		properprintF(ui.cut(mpstatus, math.floor((panelright() - ui.mp.statusx)/8)), ui.mp.statusx*scale, 181*scale)
	end

	drawlabels(tab)
	drawelements(tab)
end

local function mp_filedropped(file)
	local filename = file:getFilename()
	local ext = (filename:match("%.([^%.\\/]+)$") or ""):lower()
	if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "bmp" or ext == "tga" then
		local ok, imagedata = pcall(function()
			return love.image.newImageData(love.filesystem.newFileData(file))
		end)
		if ok then
			mp_seticon(imagedata)
			notice.new(T("icon set!"), nil, 2)
		else
			notice.new(T("couldn't read that image"), notice.red, 3)
		end
	elseif ext == "mpckproj" or ext == "json" or ext == "cfg" then
		local ok, data = pcall(function()
			return love.filesystem.newFileData(file):getString()
		end)
		if ok then
			mp_loadproject(data, ext)
		else
			notice.new(T("couldn't read that file"), notice.red, 3)
		end
	end
end

local function mp_switchtab(delta)
	mpslide.settab(MPTABS[(mpslide.index(mptab) - 1 + delta) % #MPTABS + 1])
end

------------------------------------------------------------
-- public functions (called from menu.lua)
------------------------------------------------------------

--the utils menu lives inside the "menu" gamestate, so main.lua doesn't need to know about it
utilsmenuopen = false

function utilsmenu_open()
	utilsmenuopen = true
	page = "hub"
	clearelements()
end

function utilsmenu_close()
	clearelements()
	page = "hub"
	utilsmenuopen = false
	selection = 5
end

inner_utilsmenu_openpage = function(name)
	page = name
	if name == "charformat" then
		cf_build()
	elseif name == "fontrender" then
		fr_build()
	elseif name == "mappack" then
		mp_build()
	end
end

utils_back = function()
	if job then
		notice.new(T("wait until it's finished!"), notice.red, 2)
		return
	end
	if page == "fontrender" then
		ta_setfocus(false)
	end
	clearelements()
	page = "hub"
end

local function inner_utilsmenu_update(dt)
	runjob()

	local result = love.thread.getChannel(CLIPBOARD_CHANNEL):pop()
	if result == true then
		notice.new(T("copied the image to the clipboard!"), nil, 3)
	elseif result == false then
		notice.new(TF("couldn't copy the image,\nit's saved in %s instead", RENDERFOLDER), notice.red, 4)
	end

	if page == "charformat" then
		cf_update()
	elseif page == "fontrender" then
		fr_update()
	elseif page == "mappack" then
		mp_update()
	end
	updateelements(dt)
end

local function inner_utilsmenu_draw()
	if page == "hub" then
		hub_draw()
	elseif page == "charformat" then
		cf_draw()
	elseif page == "fontrender" then
		fr_draw()
	elseif page == "mappack" then
		mp_draw()
	end
	love.graphics.setColor(255, 255, 255)
end

local function inner_utilsmenu_keypressed(key)
	if page == "hub" then
		if key == "up" or key == "w" then
			hubselection = math.max(1, hubselection - 1)
		elseif key == "down" or key == "s" then
			hubselection = math.min(#HUBITEMS, hubselection + 1)
		elseif key == "return" or key == "enter" or key == "kpenter" or key == " " then
			hub_activate()
		elseif key == "escape" then
			utilsmenu_close()
		end
		return
	end

	if page == "fontrender" and ta.focus then
		ta_keypressed(key)
		return
	end

	if keyelements(key) then
		return
	end

	local dropdown = opendropdown()
	if dropdown then
		if key == "escape" then
			dropdown:close()
		end
		return
	end

	if key == "escape" then
		utils_back()
	elseif page == "mappack" and not anyinputting() then
		if key == "left" or key == "a" then
			mp_switchtab(-1)
		elseif key == "right" or key == "d" then
			mp_switchtab(1)
		end
	end
end

--the icon frame on the general tab (mp_build can move it right to make room for long labels)
ui.iconframe = {x = 300, y = 47, size = 66}

function ui.insideiconframe(x, y)
	local f = ui.iconframe
	x, y = x/scale, y/scale
	return x >= f.x and x < f.x + f.size and y >= f.y and y < f.y + f.size
end

local function inner_utilsmenu_mousepressed(x, y, button)
	if page == "hub" then
		if button == "l" then
			local i = hub_mouseitem(x, y)
			if i then
				hubselection = i
				hub_activate()
			end
		end
		return
	end

	if page == "fontrender" and not opendropdown() and ta_mousepressed(x, y, button) then
		return
	end

	if clickelements(x, y, button) then
		return
	end

	if page == "mappack" and button == "r" and mptab == "general" and not opendropdown() and ui.insideiconframe(x, y) then
		mp_seticon(nil) --right click clears the icon
		return
	end

	if page == "mappack" and button == "l" then
		local gx, gy = x/scale, y/scale
		if gy >= 20 and gy < 31 then
			for i, r in ipairs(mp_tabrects()) do
				if gx >= r.x - 1 and gx < r.x + r.w + 2 then
					mpslide.settab(MPTABS[i])
				end
			end
		end
	end
end

local function inner_utilsmenu_mousereleased(x, y, button)
	for _, v in ipairs(elements) do
		v.el:unclick(x, y, button)
	end
end

local function inner_utilsmenu_mousemoved(x, y)
	if page == "hub" then
		local i = hub_mouseitem(x, y)
		if i then
			hubselection = i
		end
	end
end

local function inner_utilsmenu_textinput(text)
	if page == "fontrender" and ta.focus then
		ta_insert(text)
	end
end

local function inner_utilsmenu_filedropped(file)
	if page == "mappack" then
		mp_filedropped(file)
	end
end

------------------------------------------------------------
-- error guard: if anything in here breaks, show it instead of leaving a broken screen
------------------------------------------------------------

local utilserror

local function reporterror(err)
	utilserror = tostring(err)
	print("UTILS ERROR: " .. utilserror)
	pcall(function()
		love.filesystem.createDirectory("alesans_entities/crashes")
		love.filesystem.write("alesans_entities/crashes/utils_error.txt", utilserror)
	end)
	job = nil
	clearelements()
end

local function guarded(fn)
	return function(...)
		if utilserror then
			return
		end
		local ok, err = xpcall(fn, debug.traceback, ...)
		if not ok then
			reporterror(err)
		end
	end
end

local function drawerror()
	drawpanel()
	drawtitle(T("utils hit an error"))
	love.graphics.setColor(255, 80, 80)
	local y = 36
	local message = utilserror:gsub("\t", " ")
	for _, line in ipairs(wraptext(message:lower(), 44)) do
		if y > 180 then
			break
		end
		properprint(line, 26*scale, y*scale)
		y = y + 10
	end
	love.graphics.setColor(255, 255, 255)
	properprintF(T("press escape to go back"), 26*scale, 196*scale)
	properprintF(TF("saved in %s", "alesans_entities/crashes"), 26*scale, 206*scale)
end

utilsmenu_openpage = guarded(inner_utilsmenu_openpage)
utilsmenu_update = guarded(inner_utilsmenu_update)
utilsmenu_mousepressed = guarded(inner_utilsmenu_mousepressed)
utilsmenu_mousereleased = guarded(inner_utilsmenu_mousereleased)
utilsmenu_mousemoved = guarded(inner_utilsmenu_mousemoved)
utilsmenu_filedropped = guarded(inner_utilsmenu_filedropped)
utilsmenu_textinput = guarded(inner_utilsmenu_textinput)

local guardedkeypressed = guarded(inner_utilsmenu_keypressed)
function utilsmenu_keypressed(key)
	if utilserror then
		if key == "escape" or key == "return" then
			utilserror = nil
			utilsmenu_close()
		end
		return
	end
	guardedkeypressed(key)
end

function utilsmenu_draw()
	if utilserror then
		drawerror()
		return
	end
	love.graphics.push("all")
	local ok, err = xpcall(inner_utilsmenu_draw, debug.traceback)
	love.graphics.pop()
	if not ok then
		reporterror(err)
		drawerror()
	end
end

------------------------------------------------------------
-- input: while the utils menu is open it takes love's input callbacks first,
-- so nothing else in the game can swallow the clicks and keys meant for it
------------------------------------------------------------

if not utilsmenu_hooked then
	utilsmenu_hooked = true

	local oldmousepressed = love.mousepressed
	love.mousepressed = function(x, y, button, ...)
		if utilsmenuopen and not android then
			local mx, my = love.mouse.getPosition()
			utilsmenu_mousepressed(mx, my, nummousebutton(button))
			return
		end
		return oldmousepressed(x, y, button, ...)
	end

	local oldmousereleased = love.mousereleased
	love.mousereleased = function(x, y, button, ...)
		if utilsmenuopen and not android then
			local mx, my = love.mouse.getPosition()
			utilsmenu_mousereleased(mx, my, nummousebutton(button))
			return
		end
		return oldmousereleased(x, y, button, ...)
	end

	local oldmousemoved = love.mousemoved
	love.mousemoved = function(...)
		if utilsmenuopen and not android then
			utilsmenu_mousemoved(love.mouse.getPosition())
			return
		end
		if oldmousemoved then
			return oldmousemoved(...)
		end
	end

	local oldkeypressed = love.keypressed
	love.keypressed = function(key, ...)
		if utilsmenuopen and not android then
			local k = key
			if k == "space" then
				k = " "
			end
			--function keys and alt+enter (fullscreen) still go to the game
			local passthrough = k:match("^f%d+$") or ((k == "return") and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")))
			if not passthrough then
				utilsmenu_keypressed(k)
				return
			end
		end
		return oldkeypressed(key, ...)
	end

	local oldtextinput = love.textinput
	love.textinput = function(text, ...)
		if utilsmenuopen and not android then
			utilsmenu_textinput(text)
			return
		end
		if oldtextinput then
			return oldtextinput(text, ...)
		end
	end

	local oldfiledropped = love.filedropped
	love.filedropped = function(file, ...)
		if utilsmenuopen then
			utilsmenu_filedropped(file)
			return
		end
		if oldfiledropped then
			return oldfiledropped(file, ...)
		end
	end
end