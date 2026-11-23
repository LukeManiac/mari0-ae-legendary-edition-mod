--OVERLAY TASKS
--Anything that shows a loading overlay (renderoverlay) and then does a lot of work (loading a level, the editor, a
--mappack, refreshing data...) now does that work in the background, a little every frame, instead of stopping the
--whole program until it's done:
--
--* Every input callback and love.update runs inside a coroutine. When renderoverlay is called inside one, it shows the
--  overlay and hands the rest of that callback to the main loop: the coroutine is resumed once a frame, in place of the
--  game's update, until it's finished.
--* While it runs, the game is frozen (no updates, input is ignored), but the window isn't: LÖVE keeps handling the
--  window's events and drawing frames, so it can be moved, closed and doesn't stop responding.
--* The work gives the frame back (overlayyield) at points inside the long loops (map tiles, enemies, animations,
--  tiles, previews...) once it's used up its share of the frame (OVERLAYTASK_BUDGET).
--* What's drawn meanwhile is a picture of the screen taken when the overlay first showed, never the half-loaded game,
--  with the overlay's text on top. A text ending in "..." animates its dots: "", ".", "..", "...", one every 0.5 seconds.
--
--LÖVE's own threads (love.thread) can't run this work: they have their own Lua state, so they can't see or change the
--game's tables, and they can't make images or canvases. Coroutines run on the main thread, where all of that works.

--seconds of work a frame before giving the frame back: at least OVERLAYTASK_BUDGET (about 30 frames a second), and more
--when frames are slow to draw, so the work always gets about OVERLAYTASK_WORKSHARE of the time (see resume). A frame
--costs the same however much work came before it, so with a fixed budget a slow frame (a big window, software drawing,
--vsync) could take as long as the work itself, and loading took up to twice as long
OVERLAYTASK_BUDGET = 1/30
OVERLAYTASK_MAXBUDGET = 0.25 --never longer than this between frames, so the window keeps handling its events
OVERLAYTASK_WORKSHARE = 0.9 --the share of the time the work gets
OVERLAYTASK_DOTTIME = 0.5 --seconds between each step of the "..." animation

overlaytask = nil --the work running in the background: {co = coroutine}
overlayfrozen = nil --{text, start}: the overlay drawn over the frozen picture while the work runs
overlaysnapshot = nil --the frozen picture

local handlerco = nil --the callback coroutine running right now (nil outside of one)
local resumeat = 0 --when the running coroutine was last resumed
local yieldedat = nil --when the work last gave the frame back
local frametime = nil --how long a frame takes between two pieces of work (smoothed)
local budget = OVERLAYTASK_BUDGET --seconds of work before the next frame

--whether the code running now can hand the rest of its work to the main loop
function overlaytask_canyield()
	return handlerco ~= nil and coroutine.running() == handlerco
end

--whether background work is running (the game is frozen)
function overlaytask_busy()
	return overlaytask ~= nil or (overlayfrozen ~= nil and overlaytask_canyield())
end

--gives the frame back to the main loop if the background work has used up its share of it (or always, with force).
--Does nothing outside of background work, so long loops can call it whenever
function overlayyield(force)
	if not overlaytask_canyield() then
		return
	end
	if not force and not overlayfrozen then
		return --no overlay shown: the work isn't in the background, so it runs straight through like before
	end
	if force or love.timer.getTime() - resumeat >= budget then
		yieldedat = overlayfrozen and love.timer.getTime() or nil
		coroutine.yield()
		resumeat = love.timer.getTime()
	end
end

--a text ending in "..." with its dots animated: "", ".", "..", "..." (start: when the animation began). Only the dots
--that are showing are in the text, so it's centred as it is
function overlay_animatedtext(text, start)
	text = tostring(text)
	local base
	if text:sub(-3) == "..." then
		base = text:sub(1, -4)
	elseif text:sub(-3) == "…" then
		base = text:sub(1, -4) --one character, three bytes
	else
		return text
	end
	local n = math.floor((love.timer.getTime() - start)/OVERLAYTASK_DOTTIME) % 4
	return base .. string.rep(".", n)
end

--LOADING TIPS
--a tip from loadingtips (variables.lua) is shown under every loading overlay, with its middle at three quarters of the
--way down the screen. It's picked when the overlay shows and stays the same until it's gone
OVERLAYTIP_CENTERY = 0.75 --of the height of what's drawn on
OVERLAYTIP_TYPEDURATION = 1 --seconds the typewriter takes to write the whole tip (like the intro's loading text)
--a typewriter's state, like the intro's introtypewritetimer: progress is the seconds it's been typing (it stops at
--OVERLAYTIP_TYPEDURATION), last is when it was last drawn
function overlaytip_newtyping()
	return {progress = 0, last = nil}
end

local recenttips = {} --the last two tips shown, newest first
function overlaytip_pick()
	if not loadingtips or #loadingtips == 0 then
		return nil
	end
	--not the previous tip or the one before it (as long as there are enough tips to choose from)
	local choices = {}
	for i = 1, #loadingtips do
		if i ~= recenttips[1] and i ~= recenttips[2] then
			table.insert(choices, i)
		end
	end
	if #choices == 0 then
		for i = 1, #loadingtips do
			if i ~= recenttips[1] then
				table.insert(choices, i)
			end
		end
	end
	if #choices == 0 then
		choices = {1}
	end
	local i = choices[math.random(#choices)]
	recenttips = {i, recenttips[1]}
	local tip = loadingtips[i]
	if TEXT and TEXT[tip] then
		tip = TEXT[tip] --a language file can translate a tip by using it as a key
	end
	return "tip: " .. tip
end

--draws a tip in the middle of the screen's width, word-wrapped to fit, its middle at OVERLAYTIP_CENTERY of the height
--(call it with the transform at its origin). It's typed out exactly like the intro's loading text (intro_draw): typing
--(overlaytip_newtyping) is its timer, the whole tip is written after OVERLAYTIP_TYPEDURATION seconds, and the characters
--shown are the whole ones the timer has reached
--the tip's lines, worked out once for each tip and screen width and kept: {lines, lengths, charcount}
local tiplayout = {key = nil}
local function overlaytip_layout(tip, ww)
	local key = tostring(tip) .. "|" .. ww .. "|" .. scale
	if tiplayout.key == key then
		return tiplayout
	end
	local maxchars = math.max(8, math.floor(ww/(8*scale)) - 4) --two characters of room on each side
	local lines, line = {}, ""
	for word in tostring(tip):gmatch("%S+") do
		if line == "" then
			line = word
		elseif utf8.len(line) + 1 + utf8.len(word) <= maxchars then
			line = line .. " " .. word
		else
			table.insert(lines, line)
			line = word
		end
	end
	if line ~= "" then
		table.insert(lines, line)
	end
	local lengths, charcount = {}, 0
	for i, l in ipairs(lines) do
		lengths[i] = utf8.len(l)
		charcount = charcount + lengths[i]
	end
	tiplayout = {key = key, lines = lines, lengths = lengths, charcount = charcount}
	return tiplayout
end

function overlaytip_draw(tip, typing)
	if not tip then
		return
	end
	local ww, wh = getproperwindowsize()
	--the wrapping is worked out once for the whole tip, so words never jump to the next line as they're typed
	local layout = overlaytip_layout(tip, ww)
	local lines, lengths = layout.lines, layout.lengths

	--the intro's typewriter: the timer goes up by the time since the last frame and stops at the duration, and the
	--characters shown are math.floor(charcount * timer/duration), counted across the lines in order
	local visiblechars = layout.charcount
	if typing then
		local now = love.timer.getTime()
		if typing.last then
			typing.progress = math.min(typing.progress + (now - typing.last), OVERLAYTIP_TYPEDURATION)
		end
		typing.last = now
		visiblechars = math.floor(layout.charcount * math.min(typing.progress / OVERLAYTIP_TYPEDURATION, 1))
	end

	--the block's place stays put; each line is centred on what's written of it, like the intro's text
	local lineheight = 10*scale
	local totalheight = (#lines-1)*lineheight + 8*scale
	local y = wh*OVERLAYTIP_CENTERY - totalheight/2
	love.graphics.setColor(200, 200, 200, 255)
	for i, l in ipairs(lines) do
		if visiblechars <= 0 then
			break
		end
		local len = lengths[i]
		local visibletext, length
		if visiblechars >= len then
			--fully printed: drawn as it is, without working anything out
			visibletext, length = l, len
		else
			--only the line being typed is cut
			local byteend = utf8.offset(l, visiblechars + 1)
			visibletext = l:sub(1, (byteend or (#l + 1)) - 1)
			length = visiblechars
		end
		visiblechars = visiblechars - len

		local x = ww/2 - length/2*8*scale
		local ly = y + (i-1)*lineheight
		if hudoutlined() then
			properprintFbackground(visibletext, x, ly)
		else
			properprintF(visibletext, x, ly)
		end
	end
	love.graphics.setColor(255, 255, 255, 255)
end

--the overlay drawn from love.draw (donotpresentgraphics): its dots start over whenever the text changes, or when it
--hasn't been drawn for a moment
local drawnoverlay = {text = nil, start = 0, last = 0}
function overlay_drawnanimatedtext(text)
	local now = love.timer.getTime()
	if drawnoverlay.text ~= text or now - drawnoverlay.last > 0.25 then
		drawnoverlay.text = text
		drawnoverlay.start = now
	end
	drawnoverlay.last = now
	return overlay_animatedtext(text, drawnoverlay.start)
end

--takes the picture that's shown while the work runs: the frame as it is now, dimmed like the overlay, without its text
function overlaytask_snapshot(donotupdate)
	overlaysnapshot = nil
	overlaytext = "" --dims the screen, no text
	love.draw(donotupdate)
	overlaytext = nil
	if (resizable or android) and canvas then
		--love.draw drew the frame into the game's canvas first: keep a copy of it
		local w, h = canvas:getDimensions()
		local copy = love.graphics.newCanvas(w, h)
		copy:setFilter("nearest", "nearest")
		love.graphics.push("all")
		love.graphics.setCanvas(copy)
		love.graphics.origin()
		love.graphics.setScissor()
		love.graphics.setShader()
		love.graphics.setBlendMode("replace", "premultiplied")
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(canvas, 0, 0)
		love.graphics.pop()
		overlaysnapshot = copy
		love.graphics.present()
	else
		--drawn straight onto the window: take a screenshot of it when it's shown
		love.graphics.captureScreenshot(function(imagedata)
			overlaysnapshot = love.graphics.newImage(imagedata)
		end)
		love.graphics.present()
	end
end

--drawn by lovedraw in place of the game while the work runs. Returns true if it drew
function overlaytask_draw()
	if not overlayfrozen then
		return false
	end
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setScissor()
	love.graphics.setShader()
	if overlaysnapshot then
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(overlaysnapshot, 0, 0)
	else
		love.graphics.setColor(0, 0, 0, 255)
		local ww, wh = getproperwindowsize()
		love.graphics.rectangle("fill", 0, 0, ww, wh)
	end
	love.graphics.setColor(255, 255, 255, 255)
	centerprintscreen(overlay_animatedtext(overlayfrozen.text, overlayfrozen.start))
	love.graphics.pop()
	return true
end

--vsync is turned off while the work runs: with it on, every frame waits for the monitor, and a frame whose work runs
--past a refresh waits for a whole extra one, so the work only got about half of the time
local savedvsync = nil

local function vsyncoff()
	if savedvsync == nil and love.window and love.window.getVSync then
		savedvsync = love.window.getVSync()
		if savedvsync ~= 0 then
			love.window.setVSync(0)
		end
	end
end

local function vsyncrestore()
	if savedvsync ~= nil then
		if savedvsync ~= 0 then
			love.window.setVSync(savedvsync)
		end
		savedvsync = nil
	end
end

local function finish()
	yieldedat, frametime, budget = nil, nil, OVERLAYTASK_BUDGET
	overlaytask = nil
	overlayfrozen = nil
	overlaysnapshot = nil
	vsyncrestore()
end

local function check(co, ok, err)
	if not ok then
		finish()
		error(debug.traceback(co, tostring(err)), 0)
	end
	if coroutine.status(co) == "dead" then
		finish()
		return false
	end
	return true
end

--runs one more piece of the background work (the main loop calls this in place of love.update)
local function resume()
	local co = overlaytask.co
	if overlayfrozen then
		vsyncoff() --the fade before it still waits for the monitor, so it stays smooth
	end
	--how long the frame in between took, and from that how much work to do before the next one
	local now = love.timer.getTime()
	if yieldedat then
		local gap = now - yieldedat
		frametime = frametime and (frametime*0.7 + gap*0.3) or gap
		budget = math.max(OVERLAYTASK_BUDGET, math.min(OVERLAYTASK_MAXBUDGET, frametime*OVERLAYTASK_WORKSHARE/(1 - OVERLAYTASK_WORKSHARE)))
		yieldedat = nil
	end
	handlerco = co
	resumeat = now
	local ok, err = coroutine.resume(co)
	handlerco = nil
	check(co, ok, err)
end

--KEYS PRESSED WHILE LOADING
--keys pressed while the work runs aren't lost: each press is added to the end of overlaykeyqueue. Once the work is
--done, the nth key of the queue is pressed on the nth frame after the end (the 1st on the 1st frame, the 2nd on the
--2nd...), so a key pressed 5 times is pressed 5 times. A pressed key is let go of on the frame after its press, unless
--it's still held down for real. Until then, love.keyboard.isDown says it's down.
--If a pressed key starts more work, the rest wait for it and count their frames again from its end, and keys pressed
--during it go on the end
overlaykeyqueue = {} --{key, scancode} for every key pressed while the work ran, oldest first
local virtualdown = {} --keys pressed by the playback and not let go of yet: key = scancode
local releasing = nil --the key pressed on the last frame, let go of on this one: {key, scancode}

local function normalkey(k)
	if k == " " then
		return "space"
	end
	return k
end

local function overlaykeys_queue(key, scancode, isrepeat)
	if isrepeat then
		return --a held key's repeats aren't new presses
	end
	table.insert(overlaykeyqueue, {key = key, scancode = scancode})
end

--runs once a frame while the game isn't frozen: lets go of the last frame's key, then presses the next one
function overlaykeys_play()
	if releasing then
		local entry = releasing
		releasing = nil
		local key = normalkey(entry.key)
		if virtualdown[key] and not (entry.scancode and love.keyboard.isScancodeDown(entry.scancode)) then
			virtualdown[key] = nil
			love.keyreleased(entry.key, entry.scancode)
			if overlaytask then
				return --letting go of it started more work
			end
		end
		virtualdown[key] = nil
	end
	local entry = table.remove(overlaykeyqueue, 1)
	if not entry then
		return
	end
	virtualdown[normalkey(entry.key)] = entry.scancode or true
	releasing = entry
	love.keypressed(entry.key, entry.scancode, false)
end

--Alt+F4 closes the game straight away, loading or not, and is never queued
local function isaltf4(key)
	return key == "f4" and (love.keyboard.isScancodeDown("lalt") or love.keyboard.isScancodeDown("ralt"))
end

--callbacks that keep working while the game is frozen: the window's own events
local PASSTHROUGH = {quit = true, resize = true, visible = true}

local function wrap(name)
	local f = love[name]
	if type(f) ~= "function" then
		return
	end
	love[name] = function(...)
		if PASSTHROUGH[name] then
			return f(...) --never in the background: quit has to finish before the window closes
		end
		if tasstepping then
			return f(...) --the TAS is running the game a frame at a time: everything runs straight through
		end
		if name == "keypressed" and isaltf4(...) then
			love.event.quit()
			return
		end
		if overlaytask then
			if name == "update" then
				resume()
			elseif name == "keypressed" then
				overlaykeys_queue(...)
			end
			return --frozen: other input is ignored
		end
		if name == "keyreleased" and not handlerco then
			virtualdown[normalkey((...))] = nil --let go of for real
		end
		if name == "update" and not handlerco then
			overlaykeys_play()
			if overlaytask then
				return --a played-back key started more work
			end
		end
		if handlerco then
			return f(...) --called from inside another callback (android buttons, the mouse wheel...): part of that one
		end
		local co = coroutine.create(f)
		handlerco = co
		resumeat = love.timer.getTime()
		local results = {coroutine.resume(co, ...)}
		handlerco = nil
		if check(co, results[1], results[2]) then
			--renderoverlay handed the rest of this callback to the main loop
			overlaytask = {co = co}
			return
		end
		return unpack(results, 2)
	end
end

local CALLBACKS = {
	"update", "keypressed", "keyreleased", "textinput", "mousepressed", "mousereleased", "mousemoved", "wheelmoved",
	"filedropped", "directorydropped", "focus", "joystickpressed", "joystickreleased", "joystickaxis", "joystickhat",
	"gamepadpressed", "gamepadreleased", "gamepadaxis", "joystickadded", "joystickremoved",
	"touchpressed", "touchreleased", "touchmoved", "resize", "visible", "quit",
}

--wraps love's callbacks (once love.load has set them all up)
function overlaytask_install()
	if overlaytask_installed then
		return
	end
	overlaytask_installed = true
	for _, name in ipairs(CALLBACKS) do
		wrap(name)
	end
	--a key held by the playback counts as down
	local isdown = love.keyboard.isDown
	love.keyboard.isDown = function(...)
		if isdown(...) then
			return true
		end
		for i = 1, select("#", ...) do
			if virtualdown[normalkey((select(i, ...)))] then
				return true
			end
		end
		return false
	end
end