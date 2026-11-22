--ACCESSIBILITY
--The settings of the options menu's accessibility tab and the pause menu's accessibility page, what each one does,
--and the categorised layout both menus share:
--
--	Category:
--	    <label>        <widget>
--
--Loaded at the top of main.lua (before the config is read), so everything here only defines things: it doesn't use
--the window, the language or other modules until they are called.

local lg = love.graphics

------------------------------------------------------------
-- settings
------------------------------------------------------------

--every setting: its widget, its label (a TEXT key) and its range or entries (what's saved, and the TEXT keys shown for them)
local ITEMS = {
	reducemotion = {kind = "checkbox", label = "reduce motion"},
	shakeintensity = {kind = "slider", label = "screen shake", min = 25, max = 100, step = 5},
	shakedirection = {kind = "dropdown", label = "shake direction", entries = {"vertical", "horizontal", "both"},
		display = {"shake vertical", "shake horizontal", "shake both"}},
	camerasmoothing = {kind = "checkbox", label = "smooth camera"},
	reducetransparency = {kind = "checkbox", label = "reduce transparency"},
	increasecontrast = {kind = "checkbox", label = "increase contrast"},
	colourfilter = {kind = "dropdown", label = "colour filter", entries = {"none", "protanopia", "deuteranopia", "tritanopia"},
		display = {"filter none", "protanopia", "deuteranopia", "tritanopia"}},
	hudoutline = {kind = "checkbox", label = "hud outline"},
	cursorsize = {kind = "dropdown", label = "text cursor", entries = {"normal", "large", "extra large"},
		display = {"cursor normal", "cursor large", "cursor extra large"}},
	gamespeed = {kind = "slider", label = "game speed", min = 25, max = 100, step = 5},
	halfopaqueblink = {kind = "checkbox", label = "half-opaque blink"},
	clicknotices = {kind = "checkbox", label = "click to dismiss"},
}

--the categories, in order (label is a TEXT key)
local CATEGORIES = {
	{label = "motion:", items = {"reducemotion", "shakeintensity", "shakedirection", "camerasmoothing"}},
	{label = "display:", items = {"reducetransparency", "increasecontrast", "colourfilter", "hudoutline", "cursorsize"}},
	{label = "gameplay:", items = {"gamespeed", "halfopaqueblink"}},
	{label = "notices:", items = {"clicknotices"}},
}

local DEFAULTS = {
	reducemotion = false,
	shakeintensity = 100, --percent, 25 to 100 in steps of 5
	shakedirection = "both",
	camerasmoothing = nil, --nil until the nitpicks are read: it starts as the camerasmoothing nitpick
	reducetransparency = false,
	increasecontrast = false,
	colourfilter = "none",
	hudoutline = false,
	cursorsize = "normal",
	gamespeed = 100, --percent, 25 to 100 in steps of 5
	halfopaqueblink = false,
	clicknotices = false,
}

accessibility = {}

local nitpicksread = false

--puts every setting back to its default (defaultconfig and reset all settings)
function accessibility_defaults()
	for key, value in pairs(DEFAULTS) do
		accessibility[key] = value
	end
	accessibility.camerasmoothing = nil
	accessibility_resolve()
end

--settings that start from something else once it's known
function accessibility_resolve()
	if accessibility.camerasmoothing == nil and nitpicksread then
		if CameraSmoothingNitpick then
			accessibility.camerasmoothing = true
		else
			accessibility.camerasmoothing = false
		end
	end
	if accessibility.camerasmoothing ~= nil then
		CameraSmoothing = accessibility.camerasmoothing
	end
end

--after loadnitpicks: smooth camera starts as the camerasmoothing nitpick, unless options.txt already has it
function accessibility_afternitpicks()
	CameraSmoothingNitpick = CameraSmoothing
	nitpicksread = true
	accessibility_resolve()
end

local function snap(item, value)
	value = tonumber(value) or item.max
	value = math.floor((value - item.min)/item.step + 0.5)*item.step + item.min
	return math.max(item.min, math.min(item.max, value))
end

local function validentry(item, value)
	for _, entry in ipairs(item.entries) do
		if entry == value then
			return true
		end
	end
	return false
end

--options.txt: every setting as a11y_<name>:<value>;
function accessibility_saveconfig()
	local s = ""
	for key, item in pairs(ITEMS) do
		local value = accessibility[key]
		if value ~= nil then
			s = s .. "a11y_" .. key .. ":" .. tostring(value) .. ";"
		end
	end
	return s
end

--one a11y_ entry of options.txt; returns true when it was one
function accessibility_loadconfigvalue(name, value)
	if type(name) ~= "string" or name:sub(1, 5) ~= "a11y_" then
		return false
	end
	local key = name:sub(6)
	local item = ITEMS[key]
	if not item or value == nil then
		return true
	end
	if item.kind == "checkbox" then
		accessibility[key] = (value == "true")
	elseif item.kind == "slider" then
		accessibility[key] = snap(item, value)
	elseif item.kind == "dropdown" and validentry(item, value) then
		accessibility[key] = value
	end
	accessibility_resolve()
	return true
end

--changes a setting and does what it takes for it to show straight away. nosave: don't save yet (a slider being dragged)
function accessibility_set(key, value, nosave)
	local item = ITEMS[key]
	if not item then
		return
	end
	if item.kind == "slider" then
		value = snap(item, value)
	elseif item.kind == "checkbox" then
		if value then
			value = true
		else
			value = false
		end
	elseif item.kind == "dropdown" and not validentry(item, value) then
		return
	end
	accessibility[key] = value
	if key == "camerasmoothing" then
		CameraSmoothing = value
	end
	if not nosave and saveconfig then
		saveconfig()
	end
end

accessibility_defaults()

------------------------------------------------------------
-- what the settings do
------------------------------------------------------------

--reduce motion: animations that scale things fade them instead
function accessibility_reducemotion()
	return accessibility.reducemotion
end

--screen shake: the offset scaled by the intensity, along the chosen direction only
function accessibility_shake(x, y)
	local f = (accessibility.shakeintensity or 100)/100
	x, y = x*f, y*f
	if accessibility.shakedirection == "vertical" then
		x = 0
	elseif accessibility.shakedirection == "horizontal" then
		y = 0
	end
	return x, y
end

--game speed: what gameplay's dt is multiplied by
function accessibility_gamespeed()
	return (accessibility.gamespeed or 100)/100
end

--the width of a text input's cursor, in game pixels
function accessibility_cursorwidth()
	if accessibility.cursorsize == "large" then
		return 3
	elseif accessibility.cursorsize == "extra large" then
		return 4
	end
	return 2
end

--whether a player blinking after a hit is drawn half opaque instead of blinking
function accessibility_halfblink()
	return accessibility.halfopaqueblink
end

--whether the HUD (and score notes) are outlined: the mappack's hudoutline, or the setting
function hudoutlined()
	if hudoutline or accessibility.hudoutline then
		return true
	end
	return false
end

--draws something (fn draws it with the current colour) with a black outline a game pixel wide around it
local OUTLINE = {{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}}
function drawoutlined(fn)
	local r, g, b, a = lg.getColor()
	lg.setColor(0, 0, 0, a)
	for _, o in ipairs(OUTLINE) do
		lg.push()
		lg.translate(o[1]*scale, o[2]*scale)
		fn()
		lg.pop()
	end
	lg.setColor(r, g, b, a)
	fn()
end

--increase contrast: grey text (unselected options, hints...) is drawn brighter. Returns what to put back afterwards
function accessibility_contrasttext()
	if not accessibility.increasecontrast then
		return nil
	end
	local r, g, b, a = lg.getColor()
	if math.abs(r-g) < 4 and math.abs(g-b) < 4 and r >= 40 and r < 200 then
		local v = r + (255-r)*0.55
		lg.setColor(v, v, v, a)
		return {r, g, b, a}
	end
	return nil
end

function accessibility_restoretext(saved)
	if saved then
		lg.setColor(saved[1], saved[2], saved[3], saved[4])
	end
end

------------------------------------------------------------
-- reduce motion: scaling becomes fading
------------------------------------------------------------
--Everything drawn can be faded with graphicsalphamult: setColor multiplies the alpha by it and getColor divides it
--back out, so code that saves and restores a colour still works. It belongs to the love.graphics.push it was set in,
--and goes back to what it was at the matching pop.

graphicsalphamult = 1

local basesetcolor, basegetcolor = lg.setColor, lg.getColor
function lg.setColor(r, g, b, a)
	if type(r) == "table" then
		r, g, b, a = r[1], r[2], r[3], r[4]
	end
	if graphicsalphamult ~= 1 then
		a = (a or 255)*graphicsalphamult
	end
	return basesetcolor(r, g, b, a)
end

function lg.getColor()
	local r, g, b, a = basegetcolor()
	if graphicsalphamult ~= 1 then
		a = a/graphicsalphamult
	end
	return r, g, b, a
end

local basepush, basepop = lg.push, lg.pop
local alphastack, kindstack = {}, {}
function lg.push(kind)
	local n = #alphastack + 1
	alphastack[n] = graphicsalphamult
	kindstack[n] = kind or "transform"
	return basepush(kind)
end

function lg.pop()
	local n = #alphastack
	local outer = alphastack[n] or 1
	local kind = kindstack[n]
	alphastack[n], kindstack[n] = nil, nil
	local inner = graphicsalphamult
	local result = basepop()
	if inner ~= outer then
		if kind ~= "all" then
			--the colour isn't put back by a plain pop: move it from the faded level to the outer one
			local r, g, b, a = basegetcolor()
			basesetcolor(r, g, b, a/inner*outer)
		end
		graphicsalphamult = outer
	end
	return result
end

--fades everything drawn until the next pop by f (0-1)
local function fadeuntilpop(f)
	f = math.max(0.001, math.min(1, f))
	if f >= 1 then
		return
	end
	local r, g, b, a = lg.getColor()
	graphicsalphamult = graphicsalphamult*f
	lg.setColor(r, g, b, a)
end

--love.graphics.scale for an animation (a popup scaling in, a jelly...): with reduce motion, the scale is shown as a fade
--instead, the smaller side deciding how faded. Call it after a push, like scale
function motion_scale(sx, sy)
	sy = sy or sx
	if accessibility.reducemotion then
		fadeuntilpop(math.min(sx, sy))
		return
	end
	lg.scale(sx, sy)
end

--a zoom an animation draws something at (the editor panels zooming in): 1 with reduce motion (they fade already)
function motion_zoom(zoom)
	if accessibility.reducemotion then
		return 1
	end
	return zoom
end

------------------------------------------------------------
-- colour filter
------------------------------------------------------------
--The frame is drawn into a canvas the size of the window, then put on the window through a daltonisation shader:
--it works out what someone with that colour vision deficiency would see, and moves the colours they'd lose into ones
--they can tell apart. Everything that draws "to the screen" (setCanvas with nothing) draws to that canvas instead.

local FILTERMODES = {protanopia = 1, deuteranopia = 2, tritanopia = 3}
local filtercode = [[
extern float mode; //1 protanopia, 2 deuteranopia, 3 tritanopia
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
	vec4 c = Texel(tex, tc);
	vec3 rgb = c.rgb;
	float L = 17.8824*rgb.r + 43.5161*rgb.g + 4.11935*rgb.b;
	float M = 3.45565*rgb.r + 27.1554*rgb.g + 3.86714*rgb.b;
	float S = 0.0299566*rgb.r + 0.184309*rgb.g + 1.46709*rgb.b;
	float l = L;
	float m = M;
	float s = S;
	if (mode < 1.5) {
		l = 2.02344*M - 2.52581*S;
	} else if (mode < 2.5) {
		m = 0.494207*L + 1.24827*S;
	} else {
		s = -0.395913*L + 0.801109*M;
	}
	vec3 sim = vec3(
		0.0809444479*l - 0.130504409*m + 0.116721066*s,
		-0.0102485335*l + 0.0540193266*m - 0.113614708*s,
		-0.000365296938*l - 0.00412161469*m + 0.693511405*s);
	vec3 err = rgb - sim;
	vec3 shift;
	if (mode < 2.5) {
		shift = vec3(0.0, 0.7*err.r + err.g, 0.7*err.r + err.b);
	} else {
		shift = vec3(err.r + 0.7*err.b, err.g + 0.7*err.b, 0.0);
	}
	return vec4(clamp(rgb + shift, 0.0, 1.0), c.a)*color;
}
]]
local filtershader, filterfailed
local filtercanvas
accessibilityfilteractive = false

local function getfiltershader()
	if not filtershader and not filterfailed then
		local ok, shader = pcall(lg.newShader, filtercode)
		if ok then
			filtershader = shader
		else
			filterfailed = true
			print("colour filter shader failed: " .. tostring(shader))
		end
	end
	return filtershader
end

local basesetcanvas = lg.setCanvas
function lg.setCanvas(...)
	if accessibilityfilteractive and filtercanvas then
		local n = select("#", ...)
		if n == 0 or (...) == nil then
			return basesetcanvas({filtercanvas, stencil = true})
		end
	end
	return basesetcanvas(...)
end

--wraps love.draw (love.load runs it last)
function accessibility_install()
	if accessibility_installed then
		return
	end
	accessibility_installed = true
	local draw = love.draw
	love.draw = function(...)
		local mode = FILTERMODES[accessibility.colourfilter]
		if not mode or android or accessibilityfilteractive or lg.getCanvas() then
			return draw(...)
		end
		local shader = getfiltershader()
		if not shader then
			return draw(...)
		end
		local w, h = lg.getDimensions()
		if not filtercanvas or filtercanvas:getWidth() ~= w or filtercanvas:getHeight() ~= h then
			filtercanvas = lg.newCanvas(w, h)
			filtercanvas:setFilter("nearest", "nearest")
		end
		basesetcanvas({filtercanvas, stencil = true})
		lg.clear(0, 0, 0, 255)
		accessibilityfilteractive = true
		local ok, err = pcall(draw, ...)
		accessibilityfilteractive = false
		basesetcanvas()
		lg.push("all")
		lg.origin()
		lg.setScissor()
		lg.setShader(shader)
		shader:send("mode", mode)
		lg.setBlendMode("replace", "premultiplied")
		lg.setColor(255, 255, 255, 255)
		lg.draw(filtercanvas, 0, 0)
		lg.pop()
		if not ok then
			error(err, 0)
		end
	end
end

------------------------------------------------------------
-- the categorised layout
------------------------------------------------------------

local INDENT = 8 --labels sit this far in from their category
local SLIDER_W = 80 --a slider next to its label
local HEADER_COLOR = {140, 200, 255}

local function T(key)
	if TEXT and TEXT[key] then
		return TEXT[key]
	end
	return key
end

local function textw(s)
	return (utf8.len(s) or #s)*8
end

local function wraptext(text, maxchars)
	maxchars = math.max(1, maxchars)
	local lines, line = {}, ""
	for word in tostring(text):gmatch("%S+") do
		if line == "" then
			line = word
		elseif utf8.len(line) + 1 + utf8.len(word) <= maxchars then
			line = line .. " " .. word
		else
			table.insert(lines, line)
			line = word
		end
	end
	if line ~= "" or #lines == 0 then
		table.insert(lines, line)
	end
	return lines
end

local function entrytexts(item)
	local t = {}
	for i, entry in ipairs(item.entries) do
		local key = entry
		if item.display then
			key = item.display[i]
		end
		t[i] = T(key)
	end
	return t
end

local function dropdownchars(item)
	local chars = 1
	for _, s in ipairs(entrytexts(item)) do
		chars = math.max(chars, utf8.len(s) or #s)
	end
	return chars
end

local function widgetsize(item)
	if item.kind == "checkbox" then
		return 9, 9
	elseif item.kind == "slider" then
		return SLIDER_W, 9
	end
	return 13 + dropdownchars(item)*8, 11
end

--Lays the categories out in columns: columns is a list of {x, w} (game pixels), catcolumns says which column each
--category goes in. Positions are relative to the top of the content. Returns the rows, the items in keyboard order
--and the content's height
local function buildlayout(columns, catcolumns)
	local layout = {headers = {}, items = {}, order = {}, height = 0}
	for c, col in ipairs(columns) do
		local y = 0
		local first = true
		for ci, cat in ipairs(CATEGORIES) do
			if catcolumns[ci] == c then
				if not first then
					y = y + 3
				end
				first = false
				table.insert(layout.headers, {text = T(cat.label), x = col.x, y = y})
				local headery = y
				y = y + 10
				for ii, key in ipairs(cat.items) do
					local item = ITEMS[key]
					local label = T(item.label)
					local ww, wh = widgetsize(item)
					local avail = col.w - INDENT - 8 - ww --(a gap of 8 between a label and its widget)
					local row = {key = key, item = item, top = y}
					if ii == 1 then
						row.top = headery --scrolling to the first item shows its category too
					end
					if textw(label) <= avail then
						--label and widget on one line
						row.lines = {label}
						row.wx, row.ww, row.wh = col.x + col.w - ww, ww, wh
						if item.kind == "dropdown" then
							row.labely, row.wy, row.h = y + 2, y, 12
						else
							row.labely, row.wy, row.h = y + 1, y, 10
						end
					elseif item.kind == "checkbox" then
						--a checkbox stays on the line: the label wraps beside it
						row.lines = wraptext(label, math.floor(avail/8))
						row.wx, row.ww, row.wh = col.x + col.w - ww, ww, wh
						row.labely, row.wy, row.h = y + 1, y, math.max(10, #row.lines*10)
					else
						--the widget goes under its label, as wide as the column for a slider
						row.lines = wraptext(label, math.floor((col.w - INDENT)/8))
						if item.kind == "slider" then
							ww = col.w - INDENT
						end
						row.wx, row.ww, row.wh = col.x + INDENT, ww, wh
						row.labely, row.wy, row.h = y + 1, y + #row.lines*10, #row.lines*10 + wh + 2
					end
					row.labelx = col.x + INDENT
					y = y + row.h
					row.bottom = y
					layout.items[key] = row
				end
			end
		end
		layout.height = math.max(layout.height, y)
	end
	--keyboard order: column by column, top to bottom
	for c = 1, #columns do
		for ci, cat in ipairs(CATEGORIES) do
			if catcolumns[ci] == c then
				for _, key in ipairs(cat.items) do
					table.insert(layout.order, key)
				end
			end
		end
	end
	return layout
end

------------------------------------------------------------
-- a page of settings: its widgets, scrolling, drawing and keys
------------------------------------------------------------
--A page is {prefix, columns, catcolumns, viewport = {x, y, w, h}}: the widgets are guielements named prefix..setting.

local function pagename(page, key)
	return page.prefix .. key
end

local function slidervalue(item, value)
	return (value - item.min)/(item.max - item.min)
end

local function createwidget(page, key, row)
	local item = row.item
	local name = pagename(page, key)
	local el
	if item.kind == "checkbox" then
		el = guielement:new("checkbox", row.wx, row.wy, function(v)
			accessibility_set(key, v)
		end, accessibility[key])
	elseif item.kind == "dropdown" then
		local start = 1
		for i, entry in ipairs(item.entries) do
			if entry == accessibility[key] then
				start = i
			end
		end
		el = guielement:new("dropdown", row.wx, row.wy, dropdownchars(item), function(i)
			accessibility_set(key, item.entries[i])
			if guielements[name] then
				guielements[name].var = i
			end
		end, start, unpack(item.entries))
		el.displayentries = entrytexts(item)
	else
		el = guielement:new("scrollbar", row.wx, row.wy, row.ww, 33, 9, slidervalue(item, accessibility[key]), "hor")
		el.backgroundcolor = {0, 0, 0}
		el.buttonround = true
		el.scrollstepdisabled = true
		el.trackclick = true
		el.centerdisplay = true
		el.min, el.max = item.min, item.max
		el.displayfunction = function(self, v)
			return snap(item, item.min + v*(item.max - item.min)) .. "%"
		end
		el.updatefunc = function(self, v)
			accessibility_set(key, item.min + v*(item.max - item.min), true)
		end
		el.releasefunc = function(self, v)
			accessibility_set(key, item.min + v*(item.max - item.min))
			self.value = slidervalue(item, accessibility[key]) --onto the step it stands for
		end
	end
	guielements[name] = el
	return el
end

local function removewidgets(page)
	for key in pairs(ITEMS) do
		local name = pagename(page, key)
		local el = guielements[name]
		if el then
			if el.extended then
				el:close()
			end
			guielements[name] = nil
		end
	end
	page.layout = nil
end

--keeps a page's widgets in place (and in step with the settings) each frame.
--active: whether they can be used at all. selected: the setting the keyboard is on
local function updatepage(page, active, selected, dt)
	if not page.layout or page.language ~= CurrentLanguage then
		removewidgets(page)
		page.layout = buildlayout(page.columns, page.catcolumns)
		page.language = CurrentLanguage
		page.scroll = page.scroll or 0
		page.scrolltarget = page.scrolltarget or 0
	end
	local layout = page.layout
	local vp = page.viewport
	local maxscroll = math.max(0, layout.height - vp.h)

	--the keyboard's row stays in view
	if selected and layout.items[selected] and page.followselection then
		local row = layout.items[selected]
		if row.top < page.scrolltarget then
			page.scrolltarget = row.top
		elseif row.bottom > page.scrolltarget + vp.h then
			page.scrolltarget = row.bottom - vp.h
		end
	end
	page.followselection = false
	page.scrolltarget = math.max(0, math.min(maxscroll, page.scrolltarget))
	page.scroll = lerp(page.scroll, page.scrolltarget, math.min(1, (dt or 0)*14))
	if math.abs(page.scroll - page.scrolltarget) < 0.05 then
		page.scroll = page.scrolltarget
	end

	for key, row in pairs(layout.items) do
		local item = row.item
		local name = pagename(page, key)
		local el = guielements[name] or createwidget(page, key, row)
		el.x = row.wx
		el.y = vp.y + row.wy - page.scroll
		--only usable while all of it is in view
		local inview = row.wy - page.scroll >= -0.5 and row.wy + row.wh - page.scroll <= vp.h + 0.5
		el.active = active and inview
		el.nohover = not el.active
		el.forcehover = active and selected == key
		if item.kind == "checkbox" then
			el.var = accessibility[key]
		elseif item.kind == "dropdown" then
			if not el.extended then
				for i, entry in ipairs(item.entries) do
					if entry == accessibility[key] then
						el.var = i
					end
				end
			end
		elseif not (el.dragging or el.inputting) then
			el.value = slidervalue(item, accessibility[key])
		end
		if item.kind == "dropdown" and el.extended and not el.active then
			el:close()
		end
	end
end

--draws a page: offx, offy move it (a slide), selected is the setting the keyboard is on
local function drawpage(page, selected, offx, offy)
	local layout = page.layout
	if not layout then
		return
	end
	offx, offy = offx or 0, offy or 0
	local vp = page.viewport

	lg.push()
	lg.translate(offx*scale, offy*scale)
	--cut to the viewport, wherever the transform (the pause menu's scale-in, a slide) puts it
	local x0, y0 = lg.transformPoint(vp.x*scale, vp.y*scale)
	local x1, y1 = lg.transformPoint((vp.x+vp.w)*scale, (vp.y+vp.h)*scale)
	local sx, sy, sw, sh = lg.getScissor()
	lg.intersectScissor(math.min(x0, x1), math.min(y0, y1), math.max(1, math.abs(x1-x0)), math.max(1, math.abs(y1-y0)))

	local top = vp.y - page.scroll
	lg.setColor(HEADER_COLOR)
	for _, header in ipairs(layout.headers) do
		properprintF(header.text, header.x*scale, (top + header.y + 1)*scale)
	end
	for key, row in pairs(layout.items) do
		if selected == key then
			lg.setColor(255, 255, 255, 255)
		else
			lg.setColor(100, 100, 100, 255)
		end
		for i, line in ipairs(row.lines) do
			properprintF(line, row.labelx*scale, (top + row.labely + (i-1)*10)*scale)
		end
	end
	--widgets: open lists are drawn later, on top of everything (guielement.drawopendropdowns)
	for key in pairs(layout.items) do
		local el = guielements[pagename(page, key)]
		if el then
			el:draw()
		end
	end

	--a scrollbar shows when it doesn't all fit
	local maxscroll = layout.height - vp.h
	if maxscroll > 0 then
		local barh = math.max(10, vp.h*vp.h/layout.height)
		local bary = vp.y + (vp.h - barh)*(page.scroll/maxscroll)
		guiglass.pill((vp.x + vp.w - 3)*scale, bary*scale, 2*scale, barh*scale, scale, {255, 255, 255, 110}, 0.3, 1)
	end

	if sx then
		lg.setScissor(sx, sy, sw, sh)
	else
		lg.setScissor()
	end
	lg.pop()
	lg.setColor(255, 255, 255, 255)
end

local function pagecount(page)
	if not page.layout then
		return 0
	end
	return #page.layout.order
end

local function pagekey(page, index)
	return page.layout and page.layout.order[index]
end

--Enter on a setting: ticks a checkbox, opens a dropdown
local function activate(page, key)
	local item = ITEMS[key]
	if not item then
		return
	end
	if item.kind == "checkbox" then
		accessibility_set(key, not accessibility[key])
	elseif item.kind == "dropdown" then
		local el = guielements[pagename(page, key)]
		if el and el.active and not el.extended then
			el:open(true)
		end
	end
end

--Left and Right on a setting: a step of a slider, the next or previous entry of a dropdown, a checkbox flips
local function adjust(key, dir)
	local item = ITEMS[key]
	if not item then
		return
	end
	if item.kind == "checkbox" then
		accessibility_set(key, not accessibility[key])
	elseif item.kind == "slider" then
		accessibility_set(key, accessibility[key] + dir*item.step)
	else
		local index = 1
		for i, entry in ipairs(item.entries) do
			if entry == accessibility[key] then
				index = i
			end
		end
		index = index + dir
		if index > #item.entries then
			index = 1
		elseif index < 1 then
			index = #item.entries
		end
		accessibility_set(key, item.entries[index])
	end
end

local function openpagedropdown(page)
	for key in pairs(ITEMS) do
		local el = guielements[pagename(page, key)]
		if el and el.type == "dropdown" and el.extended then
			return el
		end
	end
end

--the mouse wheel over a page scrolls it (when it doesn't all fit)
local function wheelpage(page, x, y, button)
	if not page.layout or (button ~= "wu" and button ~= "wd") then
		return false
	end
	local vp = page.viewport
	if x < vp.x*scale or x > (vp.x+vp.w)*scale or y < vp.y*scale or y > (vp.y+vp.h)*scale then
		return false
	end
	if page.layout.height <= vp.h then
		return false
	end
	local step = -20
	if button == "wd" then
		step = 20
	end
	page.scrolltarget = page.scrolltarget + step
	return true
end

------------------------------------------------------------
-- options menu: the accessibility tab
------------------------------------------------------------

ACCESSIBILITY_OPTIONSTAB = 5

local optionspage = {
	prefix = "a11y_",
	columns = {{x = 30, w = 199}}, --(the scrollbar goes right of it)
	catcolumns = {1, 1, 1, 1},
	viewport = {x = 23, y = 33, w = 214, h = 181},
}

local function optionskey(selection)
	return pagekey(optionspage, (selection or 0) - 1)
end

function accessibility_optionsupdate(dt)
	if gamestate == "options" and options_tabshown(ACCESSIBILITY_OPTIONSTAB) then
		local blocked = options_popupopen and options_popupopen()
		local selected
		if optionstab == ACCESSIBILITY_OPTIONSTAB then
			selected = optionskey(optionsselection)
		end
		updatepage(optionspage, not blocked, selected, dt)
	elseif optionspage.layout then
		removewidgets(optionspage)
		optionspage.scroll, optionspage.scrolltarget = 0, 0
	end
end

function accessibility_optionsdraw()
	drawpage(optionspage, optionskey(optionsselection))
end

--the last optionsselection of the tab (1 is the tab row)
function accessibility_optionslastselection()
	return math.max(1, pagecount(optionspage) + 1)
end

function accessibility_optionsfollow()
	optionspage.followselection = true
end

function accessibility_optionsactivate(selection)
	activate(optionspage, optionskey(selection))
end

function accessibility_optionsadjust(selection, dir)
	adjust(optionskey(selection), dir)
end

------------------------------------------------------------
-- pause menu: the accessibility page, below the pause menu
------------------------------------------------------------

PAUSEMENU_PAGETIME = 0.25
pausemenupage = 1
pausemenupageanim = nil --{from, to, start} while the pages slide
pausea11yselected = 1 --the setting the keyboard is on (its index), or count+1 for the back button

local pausepage = {
	prefix = "pa11y_",
	columns = {{x = 58, w = 138}, {x = 204, w = 138}},
	catcolumns = {1, 2, 1, 2},
	viewport = {x = 52, y = 32, w = 296, h = 143},
}

--1 on the accessibility page, 0 on the pause menu
local function pagevalue()
	if pausemenupage == 2 then
		return 1
	end
	return 0
end

--the setting the keyboard is on, on the accessibility page (nil on its back button)
local function pauseselectedkey()
	if not pausepage.layout then
		return nil
	end
	return pausepage.layout.order[pausea11yselected]
end

--how far the pages have slid (0: the pause menu, 1: the accessibility page)
function pausemenu_pageprogress()
	local anim = pausemenupageanim
	if not anim then
		return pagevalue()
	end
	local t = (love.timer.getTime() - anim.start)/PAUSEMENU_PAGETIME
	if t >= 1 then
		pausemenupageanim = nil
		return pagevalue()
	end
	local p = ease_in_out_quad(t)
	if anim.to == 2 then
		return p
	end
	return 1 - p
end

--whether page (1 or 2) is up and not sliding
function pausemenu_pageidle(page)
	pausemenu_pageprogress()
	return pausemenupage == page and not pausemenupageanim
end

--slides to a page: 2 is the accessibility page, 1 the pause menu
function pausemenu_setpage(page, instant)
	if page == pausemenupage then
		return
	end
	local dropdown = openpagedropdown(pausepage)
	if dropdown then
		dropdown:close()
	end
	if instant then
		pausemenupageanim = nil
	else
		pausemenupageanim = {from = pausemenupage, to = page, start = love.timer.getTime()}
	end
	pausemenupage = page
	if page == 2 then
		pausea11yselected = 1
		pausepage.followselection = true
	else
		if pausemenu_a11yrow then
			pausemenuselected = pausemenu_a11yrow()
		end
	end
end

--the button at the bottom of the pause box: "accessibility" on the pause menu, "back" on the accessibility page
local function pausebutton()
	local label = T("accessibility")
	if pausemenupage == 2 then
		label = T("back")
	end
	local el = guielements["pause_a11ybutton"]
	if not el or el.label ~= label then
		el = guielement:new("button", 0, 0, label, function()
			if pausemenupage == 2 then
				pausemenu_setpage(1)
			else
				pausemenu_setpage(2)
			end
		end, 2)
		el.label = label
		guielements["pause_a11ybutton"] = el
	end
	local w = 3 + el.width + el.space*2
	el.x = math.floor(width*8 - w/2)
	el.y = 177 --its bottom edge is 4 pixels above the pause box's
	return el
end

--every frame the pause menu is on screen. active: the pause menu takes input (fully open, no prompt or popup)
function accessibility_pauseupdate(active, dt)
	local idle2 = pausemenu_pageidle(2)
	local key = pauseselectedkey()
	updatepage(pausepage, active and idle2, key, dt)
	local button = pausebutton()
	button.active = active and not pausemenupageanim
	button.nohover = not button.active
	if pausemenupage == 2 then
		button.forcehover = button.active and pausea11yselected > pagecount(pausepage)
	else
		button.forcehover = button.active and pausemenu_a11yrow and pausemenuselected == pausemenu_a11yrow()
	end
end

function accessibility_pauseremove()
	if pausepage.layout then
		removewidgets(pausepage)
	end
	guielements["pause_a11ybutton"] = nil
	pausepage.scroll, pausepage.scrolltarget = 0, 0
end

--the accessibility page, offy game pixels down (it slides up from below)
function accessibility_pausedraw(offy)
	local key = pauseselectedkey()
	if not pausemenu_pageidle(2) then
		key = nil
	end
	drawpage(pausepage, key, 0, offy)
end

function accessibility_pausedrawbutton()
	local el = guielements["pause_a11ybutton"]
	if el then
		el:draw()
	end
end

--keys while the accessibility page is up (or sliding). Returns true when it took the key
function accessibility_pausekeypressed(key)
	if pausemenupageanim then
		return true --nothing happens while the pages slide
	end
	if pausemenupage ~= 2 then
		return false
	end
	local dropdown = openpagedropdown(pausepage)
	if dropdown then
		if key == "escape" or isPauseKey(key) then
			dropdown:close()
		end
		return true --the open list has the other keys (see guielement:keypress)
	end

	local count = pagecount(pausepage)
	local selectedkey = pauseselectedkey()
	if key == "down" or key == "s" then
		if pausea11yselected <= count then
			pausea11yselected = pausea11yselected + 1
			pausepage.followselection = true
		end
	elseif key == "up" or key == "w" then
		if pausea11yselected > 1 then
			pausea11yselected = pausea11yselected - 1
			pausepage.followselection = true
		else
			pausemenu_setpage(1) --the pause menu is above
		end
	elseif key == "right" or key == "d" then
		adjust(selectedkey, 1)
	elseif key == "left" or key == "a" then
		adjust(selectedkey, -1)
	elseif key == "return" or key == "enter" or key == "kpenter" or key == " " then
		if pausea11yselected > count then
			pausemenu_setpage(1)
		else
			activate(pausepage, selectedkey)
		end
	elseif key == "escape" or isPauseKey(key) then
		pausemenu_setpage(1)
	end
	return true
end

------------------------------------------------------------
-- mouse
------------------------------------------------------------

--the mouse wheel over a page of settings that doesn't fit scrolls it. Returns true when it took the click
function accessibility_mousepressed(x, y, button)
	if guielement.getopendropdown and guielement.getopendropdown() then
		return false --an open list scrolls itself
	end
	if gamestate == "options" and optionstab == ACCESSIBILITY_OPTIONSTAB and optionspage.layout then
		return wheelpage(optionspage, x, y, button)
	end
	if gamestate == "game" and pausemenuopen and pausemenupage == 2 and pausepage.layout then
		return wheelpage(pausepage, x, y, button)
	end
	return false
end