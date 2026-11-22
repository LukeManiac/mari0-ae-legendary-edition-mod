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

OVERLAYTASK_BUDGET = 0.012 --seconds of work a frame before giving the frame back
OVERLAYTASK_DOTTIME = 0.5 --seconds between each step of the "..." animation

overlaytask = nil --the work running in the background: {co = coroutine}
overlayfrozen = nil --{text, start}: the overlay drawn over the frozen picture while the work runs
overlaysnapshot = nil --the frozen picture

local handlerco = nil --the callback coroutine running right now (nil outside of one)
local resumeat = 0 --when the running coroutine was last resumed

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
	if force or love.timer.getTime() - resumeat >= OVERLAYTASK_BUDGET then
		coroutine.yield()
		resumeat = love.timer.getTime()
	end
end

--a text ending in "..." with its dots animated: "", ".", "..", "..." (start: when the animation began). The missing dots
--are spaces, so the text doesn't move as they come in
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
	return base .. string.rep(".", n) .. string.rep(" ", 3-n)
end

--the overlay drawn from love.draw