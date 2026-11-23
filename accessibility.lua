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
	reduceflashing = {kind = "checkbox", label = "reduce flashing"},
	playerindicator = {kind = "checkbox", label = "player indicator"},
	aimline = {kind = "checkbox", label = "aim line"},
	lowtimewarning = {kind = "checkbox", label = "low time warning"},
	jumpbuffer = {kind = "checkbox", label = "jump buffer"},
	coyotetime = {kind = "checkbox", label = "coyote time"},
	pitrescue = {kind = "checkbox", label = "pit rescue"},
	respawnwheredied = {kind = "checkbox", label = "respawn where you died"},
	generousstomps = {kind = "checkbox", label = "generous stomps"},
	infinitelives = {kind = "checkbox", label = "infinite lives"},
	infinitetime = {kind = "checkbox", label = "infinite time"},
	skipdeaths = {kind = "number", label = "skip course after", suffix = "deaths", min = 5, max = 100, step = 1},
	skipnever = {kind = "checkbox", label = "never skip automatically"},
	togglerun = {kind = "checkbox", label = "toggle run"},
	holdtoswim = {kind = "checkbox", label = "hold to swim"},
	holdtofire = {kind = "checkbox", label = "hold to fire"},
	rapidhold = {kind = "checkbox", label = "rapid hold execution"},
}

--settings that can't be changed while another one makes them do nothing: greyed out, and they don't take clicks or keys
local DISABLEDWHEN = {
	skipdeaths = function() return accessibility.skipnever end, --only the automatic skip uses the number
	rapidhold = function() return not accessibility.holdtofire end, --only hold to fire repeats
}

local function isdisabled(key)
	local test = DISABLEDWHEN[key]
	if test and test() then
		return true
	end
	return false
end

--the categories, in order (label is a TEXT key)
local CATEGORIES = {
	{label = "motion:", items = {"reducemotion", "shakeintensity", "shakedirection", "camerasmoothing"}},
	{label = "display:", items = {"reducetransparency", "increasecontrast", "colourfilter", "hudoutline", "cursorsize",
		"reduceflashing", "playerindicator", "aimline", "lowtimewarning"}},
	{label = "gameplay:", items = {"gamespeed", "halfopaqueblink"}},
	{label = "assists:", items = {"jumpbuffer", "coyotetime", "pitrescue", "respawnwheredied", "generousstomps",
		"infinitelives", "infinitetime", "skipdeaths", "skipnever"}},
	{label = "controls:", items = {"togglerun", "holdtoswim", "holdtofire", "rapidhold"}},
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
	reduceflashing = false,
	playerindicator = false,
	aimline = false,
	lowtimewarning = false,
	jumpbuffer = false,
	coyotetime = false,
	pitrescue = false,
	respawnwheredied = false,
	generousstomps = false,
	infinitelives = nil, --nil until the nitpicks are read: it starts as the alwaysinfinitelives nitpick
	infinitetime = nil, --nil until the nitpicks are read: it starts as the alwaysinfinitetime nitpick
	skipdeaths = 10, --skip course after this many deaths (5 to 100)
	skipnever = true, --true: the pause menu offers to skip; false: the course is skipped by itself
	togglerun = false,
	holdtoswim = false,
	holdtofire = false,
	rapidhold = false, --with hold to fire: a throw every frame instead of every HOLD_REPEAT
}

accessibility = {}

local nitpicksread = false

--puts every setting back to its default (defaultconfig and reset all settings)
function accessibility_defaults()
	for key, value in pairs(DEFAULTS) do
		accessibility[key] = value
	end
	accessibility.camerasmoothing = nil
	accessibility.infinitelives = nil
	accessibility.infinitetime = nil
	accessibility_resolve()
end

--the settings that start as a nitpick, and the global the game reads them from:
--smooth camera (camerasmoothing), infinite lives (alwaysinfinitelives) and infinite time (alwaysinfinitetime)
local FROMNITPICKS = {
	camerasmoothing = "CameraSmoothing",
	infinitelives = "AlwaysInfiniteLives",
	infinitetime = "AlwaysInfiniteTime",
}
local nitpickvalues = {}

--puts a setting that comes from a nitpick where the game reads it
local function applynitpicksetting(key)
	local value = accessibility[key]
	if value == nil then
		return
	end
	_G[FROMNITPICKS[key]] = value
	if key == "infinitelives" then
		infinitelives = value --(the cheat tab's switch, for this session)
	elseif key == "infinitetime" then
		infinitetime = value
	end
end

--settings that start from something else once it's known
function accessibility_resolve()
	for key in pairs(FROMNITPICKS) do
		if accessibility[key] == nil and nitpicksread then
			if nitpickvalues[key] then
				accessibility[key] = true
			else
				accessibility[key] = false
			end
		end
		applynitpicksetting(key)
	end
end

--after loadnitpicks: these settings start as their nitpicks, unless options.txt already has them
function accessibility_afternitpicks()
	for key, global in pairs(FROMNITPICKS) do
		nitpickvalues[key] = _G[global]
	end
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
	elseif item.kind == "slider" or item.kind == "number" then
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
	if item.kind == "slider" or item.kind == "number" then
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
	if FROMNITPICKS[key] then
		applynitpicksetting(key)
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
-- assists and controls
------------------------------------------------------------

local JUMPBUFFER_TIME = 0.15 --a jump pressed this long before landing still happens
local COYOTE_TIME = 0.1 --how long after walking off a ledge a jump still works
local HOLD_REPEAT = 0.3 --hold to swim and hold to fire: seconds between strokes and throws

--coyote time: whether the player walked off a ledge (not jumped) a moment ago, so a jump still counts as from the ground
function accessibility_coyote(p)
	if not accessibility.coyotetime then
		return false
	end
	if not p.falling or p.jumping or p.a11yleftbyjump or not p.a11yairtime then
		return false
	end
	if p.gravitydir ~= "down" or p.water or p.vine or p.fence then
		return false
	end
	return p.a11yairtime <= COYOTE_TIME
end

--jump buffer: a jump pressed in the air that didn't do anything is remembered for a moment
function accessibility_bufferjump(p)
	if accessibility.jumpbuffer and p.gravitydir == "down" and not p.water then
		p.a11yjumpbuffer = love.timer.getTime()
	end
end

--the player just landed: a remembered jump happens next frame (see accessibility_playerupdate)
function accessibility_landed(p)
	if p.a11yjumpbuffer then
		if accessibility.jumpbuffer and love.timer.getTime() - p.a11yjumpbuffer <= JUMPBUFFER_TIME then
			p.a11ypendingjump = true
		end
		p.a11yjumpbuffer = nil
	end
end

--the last solid ground a player stood on (pit rescue and respawn where you died): where their feet were, in which course
function accessibility_safeground(p)
	if p.gravitydir ~= "down" or p.dead then
		return
	end
	local safe = p.a11ysafe
	if not safe then
		safe = {}
		p.a11ysafe = safe
	end
	safe.x = p.x + p.width/2
	safe.y = p.y + p.height
	safe.course = tostring(marioworld) .. "-" .. tostring(mariolevel)
	safe.sub = mariosublevel
end

--whether a safe ground is in the course and area that's loaded
local function safehere(safe)
	return safe and safe.course == tostring(marioworld) .. "-" .. tostring(mariolevel) and safe.sub == mariosublevel
end

--whether a projectile power-up's throw can repeat (hold to fire): not a tail whip, pick up, Cappy or Yoshi
local THROWSIZES = {[3] = true, [4] = true, [7] = true, [13] = true, [15] = true}
local function canautofire(p)
	if p.yoshi or p.shoe or p.pickup or p.pickupready or p.fence or p.vine or p.statue or p.ducking then
		return false
	end
	if p.cappy and not UseButtonCappy then
		return false
	end
	return THROWSIZES[p.size] or p.fireenemy or p.characterdata.fireenemy
end

--every frame for every player (mario:update)
function accessibility_playerupdate(p, dt)
	if p.dead or not p.controlsenabled then
		p.a11ypendingjump = false
		return
	end
	local n = p.playernumber

	--on the ground, or how long in the air (coyote time)
	if p.falling == false and not p.jumping then
		p.a11yairtime = 0
		p.a11yleftbyjump = false
	else
		p.a11yairtime = (p.a11yairtime or 0) + dt
		if p.jumping then
			p.a11yleftbyjump = true
		end
	end

	--jump buffer: the jump pressed just before landing
	if p.a11ypendingjump then
		p.a11ypendingjump = false
		if accessibility.jumpbuffer and p.falling == false and not p.jumping then
			p:jump()
			if not jumpkey(n) then
				p:stopjump() --let go already: a short hop
			end
		end
	end

	--hold to swim: another stroke every so often while jump is held
	if accessibility.holdtoswim and p.water and not p.frog and jumpkey(n) then
		p.a11yswimtimer = (p.a11yswimtimer or 0) + dt
		if p.a11yswimtimer >= HOLD_REPEAT then
			p.a11yswimtimer = 0
			p:jump()
		end
	else
		p.a11yswimtimer = 0
	end

	--hold to fire: another throw every so often while run is held (the run button itself, even with toggle run)
	if accessibility.holdtofire and controls[n] and checkkey(controls[n]["run"], n, "run") and canautofire(p) then
		p.a11yfiretimer = (p.a11yfiretimer or 0) + dt
		local interval = HOLD_REPEAT
		if accessibility.rapidhold then
			interval = 0 --rapid hold execution: every frame (still within the limit on how many can be out at once)
		end
		if p.a11yfiretimer >= interval then
			p.a11yfiretimer = 0
			if p.fireenemy or p.characterdata.fireenemy then
				p:button("run") --custom power-ups fire from the run button
			end
			p:fire()
		end
	else
		p.a11yfiretimer = 0
	end
end

--toggle run: whether run counts as held for a player
function accessibility_runlatched(i)
	local p = objects and objects["player"] and objects["player"][i]
	if p and p.a11yrunlatched then
		return true
	end
	return false
end

--toggle run: a press of run turns it on or off
function accessibility_runpressed(i)
	if not accessibility.togglerun or gamestate ~= "game" then
		return
	end
	local p = objects and objects["player"] and objects["player"][i]
	if p then
		p.a11yrunlatched = not p.a11yrunlatched
	end
end

--pit rescue: a player falling out of the level goes back to the last solid ground they stood on, and it counts as a
--hit (a small player just blinks). Returns true when it caught them
function accessibility_pitrescue(p)
	if not accessibility.pitrescue or editormode or minigameplaying or autoscrolling or levelfinished or p.dead then
		return false
	end
	if bigmario or p.gravitydir ~= "down" or not safehere(p.a11ysafe) then
		return false
	end
	local safe = p.a11ysafe
	p.x = safe.x - p.width/2
	p.y = safe.y - p.height
	p.speedx, p.speedy = 0, 0
	p.a11yairtime = 0
	p.a11yjumpbuffer = nil

	if p.invincible or p.starred then
		--already can't be hurt: just put back
	elseif p.characterdata.health and p.health and p.health > 1 then
		p:die("Enemy (pit rescue)")
	elseif p.size > 1 and not p.characterdata.health then
		p:die("Enemy (pit rescue)") --drops a size, or loses a shoe, helmet or Yoshi, like any hit
	else
		playsound(shrinksound)
		p.invincible = true
		p.animationtimer = invincibletime - invincibletime2
		p.animation = "invincible"
	end
	if players == 1 then
		camerasnap(nil, nil, true)
	end
	return true
end

--respawn where you died: where the next try starts after everyone died, or nil
accessibilityrespawn = nil

--a player died for real: remember where they last stood
function accessibility_playerdied(p)
	if accessibility.respawnwheredied and not editormode and not minigameplaying and not dcplaying and safehere(p.a11ysafe) then
		local safe = p.a11ysafe
		accessibilityrespawn = {x = safe.x, y = safe.y, course = safe.course, sub = safe.sub}
	end
end

--the area to load after everyone died, when respawning where they died (nil: as usual)
function accessibility_respawnsublevel()
	if accessibility.respawnwheredied and accessibilityrespawn then
		return accessibilityrespawn.sub
	end
	return nil
end

--startlevel: where to put the players instead of the start or a checkpoint (and forgets it), or nil
function accessibility_takerespawn()
	local point = accessibilityrespawn
	accessibilityrespawn = nil
	if point and accessibility.respawnwheredied and safehere(point) then
		return point
	end
	return nil
end

--generous stomps: a side hit counts as landing on the enemy when the player is coming down with their feet above its middle
function accessibility_generousstomp(p, a, b)
	if not accessibility.generousstomps or a == "tile" or type(b) ~= "table" then
		return false
	end
	if p.gravitydir ~= "down" or p.speedy <= 0 or p.water then
		return false
	end
	if not (b.stompable or type(b.stomp) == "function") then
		return false
	end
	if not (b.y and b.height) then
		return false
	end
	return p.y + p.height <= b.y + b.height/2
end

--skip course: deaths on the course being played
local coursedeaths = {key = nil, count = 0}

local function coursekey()
	return tostring(mappack) .. ":" .. tostring(marioworld) .. "-" .. tostring(mariolevel)
end

--everyone died on this course
function accessibility_countdeath()
	if coursedeaths.key ~= coursekey() then
		coursedeaths.key = coursekey()
		coursedeaths.count = 0
	end
	coursedeaths.count = coursedeaths.count + 1
end

--whether everyone has died on this course at least as many times as skip course after ... deaths says
local function deathsreached()
	return coursedeaths.key == coursekey() and coursedeaths.count >= accessibility.skipdeaths
end

--whether the pause menu offers to skip this course: always while never skip automatically is ticked, otherwise
--once there have been enough deaths (when the automatic skip didn't happen, on the last life say)
function accessibility_canskip()
	if editormode or testlevel or minigameplaying or dcplaying or SERVER or CLIENT then
		return false
	end
	return accessibility.skipnever or deathsreached()
end

local function skiptonext()
	coursedeaths.key, coursedeaths.count = nil, 0
	accessibilityrespawn = nil
	mariosublevel = 0
	prevsublevel = false
	nextlevel()
end

--skips to the next course, from the pause menu
function accessibility_skipcourse()
	if gamestate ~= "game" or not accessibility_canskip() then
		return
	end
	pausemenuopen = false
	pausedaudio = nil
	skiptonext()
end

--everyone died (after accessibility_countdeath): with never skip automatically unticked, the course is skipped by itself
--once there have been enough deaths, unless that was the last life. Returns true when it skipped
function accessibility_autoskip()
	if accessibility.skipnever or not accessibility_canskip() or not deathsreached() then
		return false
	end
	local livesleft = infinitelives or mariolivecount == false
	for i = 1, players do
		if mariolives[i] and mariolives[i] > 0 then
			livesleft = true
		end
	end
	if not livesleft then
		return false --game over, as usual
	end
	notice.new("skipped the course after " .. coursedeaths.count .. " deaths", nil, 4)
	skiptonext()
	return true
end

------------------------------------------------------------
-- display
------------------------------------------------------------

--reduce flashing: a Starman doesn't flash the player's colours
function accessibility_reduceflashing()
	return accessibility.reduceflashing
end

--low time warning: the colour of the timer (nil: the HUD's own)
function accessibility_timecolour()
	if not accessibility.lowtimewarning or gamestate ~= "game" or editormode or infinitetime or notime then
		return nil
	end
	if not mariotime or mariotime <= 0 or mariotime >= 100 then
		return nil
	end
	local pulse = (math.sin(love.timer.getTime()*8) + 1)/2
	return {255, lerp(40, 140, pulse), lerp(40, 140, pulse)}
end

--player indicator: "P<n>" with an arrow under it above every player (game pixels on screen, in the level's draw)
function accessibility_drawplayerindicators(xscroll, yscroll)
	if not accessibility.playerindicator or not objects or not objects["player"] then
		return
	end
	for i = 1, players do
		local p = objects["player"][i]
		if p and not p.dead then
			local colour = {255, 255, 255}
			if mariocolors[i] and mariocolors[i][1] then
				colour = mariocolors[i][1]
			end
			local cx = (p.x + p.width/2 - xscroll)*16
			local top = (p.y - yscroll)*16 - 12
			local lines = {"p" .. i, "↓"}
			for l, line in ipairs(lines) do
				local y = top - 2 - (#lines - l + 1)*8
				properprintFbackground(line, math.floor((cx - utf8.len(line)*4)*scale), math.floor(y*scale), true, colour)
			end
		end
	end
	lg.setColor(255, 255, 255, 255)
end

--aim line: a solid line from the portal gun to where the portal would open, in the portal's colour
--(red with a cross where it can't open)
function accessibility_drawaimline(player, sourcex, sourcey, x, y, possible, xscroll, yscroll)
	local x1, y1 = (sourcex - xscroll)*16*scale, (sourcey - .5 - yscroll)*16*scale
	local x2, y2 = (x - xscroll)*16*scale, (y - .5 - yscroll)*16*scale
	local colour = {255, 60, 60}
	if possible then
		colour = {0, 255, 0}
		local pc = portalcolor and portalcolor[player.playernumber]
		if pc and pc[1] then
			colour = pc[1]
		end
	end
	local oldwidth = lg.getLineWidth()
	local oldstyle = lg.getLineStyle()
	lg.setLineStyle("rough")
	lg.setColor(0, 0, 0, 255)
	lg.setLineWidth(3*scale)
	lg.line(x1, y1, x2, y2)
	lg.setColor(colour[1], colour[2], colour[3], 255)
	lg.setLineWidth(scale)
	lg.line(x1, y1, x2, y2)
	if not possible then
		local c = 3*scale
		lg.setColor(0, 0, 0, 255)
		lg.setLineWidth(3*scale)
		lg.line(x2-c, y2-c, x2+c, y2+c)
		lg.line(x2-c, y2+c, x2+c, y2-c)
		lg.setColor(255, 60, 60, 255)
		lg.setLineWidth(scale)
		lg.line(x2-c, y2-c, x2+c, y2+c)
		lg.line(x2-c, y2+c, x2+c, y2-c)
	end
	lg.setLineWidth(oldwidth)
	lg.setLineStyle(oldstyle)
	lg.setColor(255, 255, 255, 255)
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
local SCROLLBAR_W = 6 --the page's scrollbar, at the right edge of its viewport
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

local NUMBER_CHARS = 3 --a number input is 3 characters wide (5 to 100)

local function widgetsize(item)
	if item.kind == "checkbox" then
		return 9, 9
	elseif item.kind == "number" then
		return 3 + NUMBER_CHARS*8 + 2, 13
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
					if item.kind == "number" then
						--"<label>" on its own line(s), then "[number] <suffix>" under it
						row.lines = wraptext(label, math.floor((col.w - INDENT)/8))
						row.wx, row.ww, row.wh = col.x + INDENT, ww, wh
						row.labely, row.wy = y + 1, y + #row.lines*10
						row.suffix = T(item.suffix)
						row.suffixx = row.wx + ww + 4
						row.suffixy = row.wy + 3
						row.h = #row.lines*10 + wh + 2
					elseif textw(label) <= avail then
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
	elseif item.kind == "number" then
		--a number input like the editor's colour inputs: type a number (Enter sets it), or drag it left and right
		el = guielement:new("input", row.wx, row.wy, NUMBER_CHARS, function(self)
			local n = tonumber(self.value)
			if n then
				accessibility_set(key, n, self.numdragging) --(dragging: saved when it's let go, see updatepage)
			elseif not self.numdragging then
				notice.new("that has to be a number!", notice.red, 3)
			end
			self.value = tostring(accessibility[key])
			if not self.numdragging then
				self.inputting = false
			end
		end, tostring(accessibility[key]), NUMBER_CHARS + 1) --(one more than shows, so a selected 3 digit number can be typed over)
		el.numdrag = {item.min, item.max}
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

local function scrollbarname(page)
	return page.prefix .. "scrollbar"
end

local function removewidgets(page)
	guielements[scrollbarname(page)] = nil
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

	--the scrollbar: a gui scrollbar at the right edge of the viewport, only when it doesn't all fit.
	--Dragging it scrolls the page, and otherwise it follows the page (the wheel and the keyboard scroll it)
	local barname = scrollbarname(page)
	local bar = guielements[barname]
	if maxscroll > 0 then
		local handle = math.max(10, math.floor(vp.h*vp.h/layout.height))
		local x = vp.x + vp.w - SCROLLBAR_W
		local sig = x .. "," .. vp.y .. "," .. vp.h .. "," .. handle
		if not (bar and bar.sig == sig) then
			bar = guielement:new("scrollbar", x, vp.y, vp.h, SCROLLBAR_W, handle, page.scroll/maxscroll, "ver")
			bar.sig = sig
			bar.scrollstepdisabled = true --the mouse wheel is handled by the page (see wheelpage)
			guielements[barname] = bar
		end
		bar.active = active
		bar.nohover = not active
		if not active then
			bar.dragging = false
		end
		if bar.dragging then
			page.scrolltarget = bar.value*maxscroll
			page.scroll = page.scrolltarget
		end
	elseif bar then
		guielements[barname] = nil
		bar = nil
	end

	page.scrolltarget = math.max(0, math.min(maxscroll, page.scrolltarget))
	page.scroll = lerp(page.scroll, page.scrolltarget, math.min(1, (dt or 0)*14))
	if math.abs(page.scroll - page.scrolltarget) < 0.05 then
		page.scroll = page.scrolltarget
	end
	if bar and not bar.dragging then
		bar.value = page.scroll/maxscroll
	end

	for key, row in pairs(layout.items) do
		local item = row.item
		local name = pagename(page, key)
		local el = guielements[name] or createwidget(page, key, row)
		el.x = row.wx
		if item.kind == "dropdown" and el.multiy and (el.extended or el:getlistprogress() > 0) then
			--an open list that didn't fit under its header opened upwards: it stays where it opened
		else
			el.y = vp.y + row.wy - page.scroll
		end
		--a dropdown puts itself back where it was made every frame (multiy, for lists that open upwards when they don't
		--fit under the header), so that has to follow the scrolled spot, like the minigame settings' dropdowns
		if item.kind == "dropdown" and not el.extended and el:getlistprogress() == 0 and not el.cutoff then
			local listbottom = el.y + 10*(#el.entries + 1)
			if listbottom > height*16 then
				el.multiy = {el.y, height*16 - 10*(#el.entries + 1)}
			else
				el.multiy = false
			end
		end
		--only usable while all of it is in view
		local inview = row.wy - page.scroll >= -0.5 and row.wy + row.wh - page.scroll <= vp.h + 0.5
		local disabled = isdisabled(key)
		el.active = active and inview and not disabled
		el.nohover = not el.active
		el.forcehover = el.active and selected == key
		if item.kind == "checkbox" then
			el.var = accessibility[key]
		elseif item.kind == "number" then
			if el.numdragging then
				el.a11ydragged = true
			elseif el.a11ydragged then
				el.a11ydragged = nil
				accessibility_set(key, tonumber(el.value) or accessibility[key]) --let go after dragging: save it
			end
			if not (el.inputting or el.numdragging) then
				el.value = tostring(accessibility[key])
			end
			if not el.active and el.inputting then
				el.inputting = false
				typingintextinput = false
			end
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
		if isdisabled(key) then
			--greyed out: darker, and only a little lighter when the keyboard is on it
			if selected == key then
				lg.setColor(150, 150, 150, 120)
			else
				lg.setColor(100, 100, 100, 110)
			end
		elseif selected == key then
			lg.setColor(255, 255, 255, 255)
		else
			lg.setColor(100, 100, 100, 255)
		end
		for i, line in ipairs(row.lines) do
			properprintF(line, row.labelx*scale, (top + row.labely + (i-1)*10)*scale)
		end
		if row.suffix then
			properprintF(row.suffix, row.suffixx*scale, (top + row.suffixy)*scale)
		end
	end
	--widgets: open lists are drawn later, on top of everything (guielement.drawopendropdowns)
	for key in pairs(layout.items) do
		local el = guielements[pagename(page, key)]
		if el then
			if isdisabled(key) then
				lg.push()
				fadeuntilpop(0.4) --greyed out
				el:draw()
				lg.pop()
			else
				el:draw()
			end
		end
	end

	--the scrollbar, when it doesn't all fit
	local bar = guielements[scrollbarname(page)]
	if bar then
		bar:draw()
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
	if not item or isdisabled(key) then
		return
	end
	if item.kind == "checkbox" then
		accessibility_set(key, not accessibility[key])
	elseif item.kind == "dropdown" then
		local el = guielements[pagename(page, key)]
		if el and el.active and not el.extended then
			el:open(true)
		end
	elseif item.kind == "number" then
		--start typing, with the whole number selected so typing replaces it
		local el = guielements[pagename(page, key)]
		if el and el.active then
			el.inputting = true
			typingintextinput = true
			el.highlight = 1
			el.cursorpos = string.len(tostring(el.value)) + 1
			el.textoffset = 0
		end
	end
end

--Left and Right on a setting: a step of a slider, the next or previous entry of a dropdown, a checkbox flips
local function adjust(key, dir)
	local item = ITEMS[key]
	if not item or isdisabled(key) then
		return
	end
	if item.kind == "checkbox" then
		accessibility_set(key, not accessibility[key])
	elseif item.kind == "slider" or item.kind == "number" then
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
	catcolumns = {1, 1, 1, 1, 1, 1},
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
	columns = {{x = 58, w = 138}, {x = 204, w = 134}}, --(the scrollbar goes right of the second)
	catcolumns = {1, 2, 1, 1, 2, 2}, --motion, gameplay and assists on the left; display, controls and notices on the right
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
		pausemenubuttoncol = 1
	end
end

--the buttons at the bottom of the pause box: "accessibility" (or "back" on the accessibility page), and "skip course"
--next to it on the pause menu once it's on offer (see accessibility_canskip)
pausemenubuttoncol = 1 --the button the keyboard is on, on the pause menu's button row: 1 accessibility, 2 skip course

local function makebutton(name, label, func)
	local el = guielements[name]
	if not el or el.label ~= label then
		el = guielement:new("button", 0, 0, label, func, 2)
		el.label = label
		guielements[name] = el
	end
	return el
end

local function buttonwidth(el)
	return 3 + el.width + el.space*2
end

--whether the pause menu shows "skip course"
function pausemenu_skipshown()
	return pausemenupage == 1 and accessibility_canskip()
end

local function pausebuttons()
	local label = T("accessibility")
	if pausemenupage == 2 then
		label = T("back")
	end
	local main = makebutton("pause_a11ybutton", label, function()
		if pausemenupage == 2 then
			pausemenu_setpage(1)
		else
			pausemenu_setpage(2)
		end
	end)
	local skip
	if pausemenu_skipshown() then
		skip = makebutton("pause_skipbutton", T("skip course"), accessibility_skipcourse)
	else
		guielements["pause_skipbutton"] = nil
		pausemenubuttoncol = 1
	end
	--side by side in the middle, their bottom edges 4 pixels above the pause box's
	local gap = 6
	local total = buttonwidth(main)
	if skip then
		total = total + gap + buttonwidth(skip)
	end
	local x = math.floor(width*8 - total/2)
	main.x, main.y = x, 177
	if skip then
		skip.x, skip.y = x + buttonwidth(main) + gap, 177
	end
	return main, skip
end

--the keyboard on the pause menu's button row: Left and Right move between the buttons
function pausemenu_buttonmove(dir)
	if pausemenu_skipshown() then
		pausemenubuttoncol = math.max(1, math.min(2, pausemenubuttoncol + dir))
	end
end

--Enter on the pause menu's button row
function pausemenu_buttonactivate()
	if pausemenubuttoncol == 2 and pausemenu_skipshown() then
		accessibility_skipcourse()
	else
		pausemenu_setpage(2)
	end
end

--every frame the pause menu is on screen. active: the pause menu takes input (fully open, no prompt or popup)
function accessibility_pauseupdate(active, dt)
	local idle2 = pausemenu_pageidle(2)
	local key = pauseselectedkey()
	updatepage(pausepage, active and idle2, key, dt)
	local main, skip = pausebuttons()
	local onrow = pausemenupage == 1 and pausemenu_a11yrow and pausemenuselected == pausemenu_a11yrow()
	main.active = active and not pausemenupageanim
	main.nohover = not main.active
	if pausemenupage == 2 then
		main.forcehover = main.active and pausea11yselected > pagecount(pausepage)
	else
		main.forcehover = main.active and onrow and pausemenubuttoncol == 1
	end
	if skip then
		skip.active = active and not pausemenupageanim
		skip.nohover = not skip.active
		skip.forcehover = skip.active and onrow and pausemenubuttoncol == 2
	end
end

function accessibility_pauseremove()
	if pausepage.layout then
		removewidgets(pausepage)
	end
	guielements["pause_a11ybutton"] = nil
	guielements["pause_skipbutton"] = nil
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
	for _, name in ipairs({"pause_a11ybutton", "pause_skipbutton"}) do
		local el = guielements[name]
		if el then
			el:draw()
		end
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