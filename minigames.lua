--[[
	MINIGAMES
	Everything about the minigames lives here: the list of minigames, their save data,
	the "minigames" tab of the mappack menu, the intro/win/lose screens and the minigames themselves.

	The minigames run inside game.lua (gamestate "game"). game.lua calls these hooks:
		minigame_createmap()            startlevel("minigame") builds the map
		minigame_postload()             end of startlevel, after the player spawned
		minigame_update(dt)             game_update, right before the physics update
		minigame_drawworld()            game_draw, before the foreground tiles
		minigame_drawoverlay()          game_draw, on top of everything (includes the HUD)
		minigame_drawHUD()              drawHUD (the minigame levelscreens use it too)
		minigame_mousepressed(x, y, b)  game_mousepressed
		minigame_keypressed(key)        game_keypressed

	Minigames are one player only, play the daily challenge music and always use the
	built-in assets (overrideassets/overridegraphics/overridesounds are ignored).
]]

minigameplaying = false --a minigame (or one of its levelscreens) is running
minigamecurrent = false --definition of the minigame being played
minigamestate = false --state of the current run
minigamescreen = false --"intro", "win" or "lose" while on the minigame levelscreen
minigameresult = false --{score = n, highscore = bool} after a run ended
minigameselection = 1
minigamescroll = 0
minigamescrollsmooth = 0
minigameoptions = {} --[minigame id][option key] = value (game modes picked in the menu)
minigamelist = {}
minigameoldplayers = nil --player count to restore when going back to the menu
minigamegravity = 30
victoryscore = 100 --losing an endless minigame with a score above this shows the victory screen

local MINIGAME_DATA_FILE = "alesans_entities/minigame_data.json"
local MINIGAME_GRAPHICS_FOLDER = "graphics/minigames/"

--menu layout
local OPTION_X, OPTION_Y = 25, 20 --same spot and size as a mappack option (200x58)
local OPTION_W, OPTION_H = 200, 58
local OPTION_SPACING = 60
local GRAPHIC_W, GRAPHIC_H = OPTION_W-8, OPTION_H-8 --192x50
local DESC_X, DESC_Y, DESC_W = 241, 16, 150 --where the search bar is on the local tab
local DESC_LINE = 10 --the value added to the text y on a new line
local DESC_CHARS = math.floor((DESC_W-6)/8)
local SCROLLBAR_SPACE = 10 --room the description and highscores scrollbars take on the right
local GUI_PADDING = 2 --between the bottom of the text and the top of a game mode GUI element
local CHECKBOX_LABEL_X = DESC_X+16
local CHECKBOX_LABEL_CHARS = math.floor((DESC_X+DESC_W-3-CHECKBOX_LABEL_X)/8)

local minigamedata = nil
local minigameimages = {}
local minigamegui = {}
local minigameguiid = nil

---------------
--  HELPERS  --
---------------

local function T(key)
	return (TEXT and TEXT[key]) or key
end

local function rnd(a, b) --randomisers don't have to output whole numbers
	return a + math.random()*(b-a)
end

local function randomsign()
	return (math.random(2) == 1) and -1 or 1
end

local function textwidth(s)
	return utf8.len(tostring(s))*8
end

local function tablefind(t, v)
	for i = 1, #t do
		if t[i] == v then
			return i
		end
	end
	return false
end

local function shadowprint(s, x, y, color)
	--x and y are in game pixels
	love.graphics.setColor(color or {255, 255, 255})
	properprintFbackground(s, x*scale, y*scale)
end

local function centerprintline(s, cx, y, color)
	shadowprint(s, cx - textwidth(s)/2, y, color)
end

--score units: 1.23K, 45.6M, 789B, 1T... up to the biggest number Lua can hold (about 179UCe, 1.8*10^308)
--K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, then U/D/T/Qa/Qi/Sx/Sp/Oc/No + Dc, Vg, Tg, Qag, Qig, Sxg, Spg, Ocg, Nog, then Ce
local SCORE_UNITS = {"K", "M", "B", "T"}
do
	local ones = {"", "U", "D", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No"}
	local tens = {"", "Dc", "Vg", "Tg", "Qag", "Qig", "Sxg", "Spg", "Ocg", "Nog"}
	for n = 4, 9 do --quadrillion to nonillion
		SCORE_UNITS[n+1] = ones[n+1]
	end
	for n = 10, 99 do --decillion to novemnonagintillion
		SCORE_UNITS[n+1] = ones[n%10+1] .. tens[math.floor(n/10)+1]
	end
	SCORE_UNITS[101] = "Ce" --centillion, 10^303
	SCORE_UNITS[102] = "UCe" --10^306
end

function minigame_formatscore(n)
	n = tonumber(n) or 0
	if n ~= n then
		return "0"
	end
	local sign = (n < 0) and "-" or ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	if n == math.huge then
		return sign .. "INF"
	end
	local unit = 0
	while n >= 1000 - 1e-6 and unit < #SCORE_UNITS do --a hair under 1000 counts (dividing big numbers isn't exact)
		n = n/1000
		unit = unit + 1
	end
	n = n*(1 + 1e-12) --dividing can land just under a whole number
	--3 significant digits, cut off instead of rounded so 999.9K never shows as 1000K
	local text
	if n >= 100 then
		text = tostring(math.floor(n))
	elseif n >= 10 then
		text = string.format("%.1f", math.floor(n*10)/10)
	else
		text = string.format("%.2f", math.floor(n*100)/100)
	end
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return sign .. text .. SCORE_UNITS[unit]
end
local formatscore = minigame_formatscore

--"Score: " .. score, centered on the screen
local function drawscorehud(S)
	centerprintline("Score: " .. formatscore(S.score or 0), width*8, 8)
end

--wrap the text by splitting spaces, "\n" starts a new line
function minigame_wraptext(s, maxchars)
	local lines = {}
	for paragraph in (tostring(s) .. "\n"):gmatch("(.-)\n") do
		local line = ""
		for word in paragraph:gmatch("[^ ]+") do
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
	if #lines == 0 then
		lines[1] = ""
	end
	return lines
end
local wraptext = minigame_wraptext

local function centerprintwrapped(s, cx, y, maxchars, color)
	local lines = wraptext(s, maxchars or 46)
	for i = 1, #lines do
		centerprintline(lines[i], cx, y+(i-1)*DESC_LINE, color)
	end
end

--images from graphics/minigames, never overridden by mappacks
function minigame_image(file)
	if minigameimages[file] == nil then
		minigameimages[file] = false
		local path = MINIGAME_GRAPHICS_FOLDER .. file
		if love.filesystem.getInfo(path) then
			local ok, img = pcall(love.graphics.newImage, path)
			if ok then
				minigameimages[file] = img
			end
		end
	end
	return minigameimages[file] or nil
end

function minigame_getgraphic(def)
	return minigame_image(def.id .. ".png")
end

local function minigame_popup(text, x, y, color)
	--small rising number (x, y in game pixels)
	local S = minigamestate
	if S then
		table.insert(S.popups, {text = tostring(text), x = x, y = y, t = 0, color = color})
	end
end

local function drawtilegraphic(id, x, y, sx, sy)
	local t = tilequads[id]
	if t and t.image and t.quad then
		love.graphics.draw(t.image, t.quad, x*scale, y*scale, 0, (sx or 1)*scale, (sy or sx or 1)*scale)
	end
end

------------------
--  SAVE  DATA  --
------------------

function minigame_getdata()
	if minigamedata then
		return minigamedata
	end
	minigamedata = {}
	if love.filesystem.getInfo(MINIGAME_DATA_FILE) then
		local ok, t = pcall(function()
			return JSON:decode(love.filesystem.read(MINIGAME_DATA_FILE))
		end)
		if ok and type(t) == "table" then
			for name, scores in pairs(t) do
				if type(name) == "string" and type(scores) == "table" then
					local clean = {}
					for i = 1, #scores do
						if tonumber(scores[i]) then
							table.insert(clean, tonumber(scores[i]))
						end
					end
					minigamedata[name] = clean
				end
			end
		else
			print("minigame_data.json could not be read, starting fresh")
		end
	end
	return minigamedata
end

local function jsonstring(s)
	s = tostring(s):gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
	return "\"" .. s .. "\""
end

function minigame_savedata()
	--{"minigame name": [all scores (starting with oldest)], ...}
	local data = minigame_getdata()
	local order = {}
	local used = {}
	for i = 1, #minigamelist do
		local name = minigamelist[i].savename
		data[name] = data[name] or {}
		table.insert(order, name)
		used[name] = true
	end
	local extra = {}
	for name in pairs(data) do
		if not used[name] then
			table.insert(extra, name) --keep scores of minigames that aren't in this version
		end
	end
	table.sort(extra)
	for i = 1, #extra do
		table.insert(order, extra[i])
	end

	local out = {"{"}
	for i, name in ipairs(order) do
		local scores = {}
		for j, v in ipairs(data[name]) do
			scores[j] = tostring(math.floor(v) == v and math.floor(v) or v)
		end
		table.insert(out, "\t" .. jsonstring(name) .. ": [" .. table.concat(scores, ", ") .. "]" .. (i < #order and "," or ""))
	end
	table.insert(out, "}")
	love.filesystem.createDirectory("alesans_entities")
	local ok, err = love.filesystem.write(MINIGAME_DATA_FILE, table.concat(out, "\n"))
	if not ok then
		print("Failed to save minigame data: " .. tostring(err))
	end
end

function minigame_gethighscores(def, count)
	local scores = {}
	for i, v in ipairs(minigame_getdata()[def.savename] or {}) do
		scores[i] = v
	end
	table.sort(scores, function(a, b) return a > b end)
	if not count then
		return scores --all of them, best first
	end
	local out = {}
	for i = 1, math.min(count, #scores) do
		out[i] = scores[i]
	end
	return out
end

function minigame_recordscore()
	local S = minigamestate
	if not (S and minigamecurrent) or S.recorded then
		return
	end
	S.recorded = true
	local data = minigame_getdata()
	local name = minigamecurrent.savename
	data[name] = data[name] or {}
	local best
	for _, v in ipairs(data[name]) do
		if (not best) or v > best then
			best = v
		end
	end
	local score = math.floor(S.score or 0)
	table.insert(data[name], score)
	minigameresult = {score = score, highscore = (score > 0 and (best == nil or score > best))}
	if minigamecurrent.title then
		minigameresult.title = minigamecurrent.title(S, score)
	end
	minigame_savedata()
end

----------------
--  REGISTRY  --
----------------

local function addminigame(def)
	def.options = def.options or {}
	minigameoptions[def.id] = minigameoptions[def.id] or {}
	for _, opt in ipairs(def.options) do
		if minigameoptions[def.id][opt.key] == nil then
			minigameoptions[def.id][opt.key] = opt.default
		end
	end
	table.insert(minigamelist, def)
	return def
end

------------
--  MENU  --
------------

function loadminigames()
	mappacktype = "minigames"
	--the search bar isn't visible or usable on this tab
	if mappacksearchbar then
		mappacksearchbar.active = false
		mappacksearchbar.inputting = false
	end
	if openmappacksbutton then openmappacksbutton.active = false end
	if opendlcbutton then opendlcbutton.active = false end
	minigame_getdata()
	minigameselection = math.max(1, math.min(minigameselection, #minigamelist))
	minigame_updatescroll()
	minigamescrollsmooth = minigamescroll
	minigame_buildgui(true)
	return true
end

function minigame_updatescroll()
	if minigameselection < 1+minigamescroll then
		minigamescroll = minigameselection-1
	elseif minigameselection > 3+minigamescroll then
		minigamescroll = minigameselection-3.233
	end
	minigamescroll = math.max(0, minigamescroll)
end

--a long description (with its settings) gets a scrollbar
local function descmaxheight()
	return math.floor((height or 14)*16/2/DESC_LINE)*DESC_LINE
end

--lays out the description and the game mode settings as one block (content y, not scrolled)
local function layoutcontent(def, layout, narrow)
	local space = narrow and SCROLLBAR_SPACE or 0
	layout.lines = wraptext(def.description, math.floor((DESC_W-6-space)/8))
	layout.items = {}
	local y = DESC_Y + DESC_LINE*#layout.lines
	if #def.options > 0 then
		y = y + GUI_PADDING
		for _, opt in ipairs(def.options) do
			local item = {opt = opt, y = y}
			if opt.type == "checkbox" then
				item.labellines = wraptext(opt.label, CHECKBOX_LABEL_CHARS - math.ceil(space/8))
				item.height = math.max(9, DESC_LINE*#item.labellines-1)
			else --dropdown, the label sits above it
				item.labellines = wraptext(opt.label, math.floor((DESC_W-6-space)/8))
				item.height = DESC_LINE*#item.labellines + 11
			end
			table.insert(layout.items, item)
			y = y + item.height + GUI_PADDING
		end
	end
	layout.contenth = y - DESC_Y
end

local function panellayout(def)
	local layout = {}
	--the description and the settings together never take more than half of the game height
	local maxh = descmaxheight()
	layoutcontent(def, layout, false)
	if layout.contenth > maxh then
		--narrower, so nothing runs under the scrollbar
		layoutcontent(def, layout, true)
	end
	layout.viewh = math.min(layout.contenth, maxh)
	layout.maxscroll = layout.contenth - layout.viewh --in pixels
	layout.bottom = DESC_Y + layout.viewh
	return layout
end

function minigame_buildgui(force)
	local def = minigamelist[minigameselection]
	if not def then
		minigamegui = {}
		minigameguiid = nil
		return
	end
	if minigameguiid == def.id and not force then
		return
	end
	minigameguiid = def.id
	minigamegui = {}
	local layout = panellayout(def)
	local opts = minigameoptions[def.id]
	for _, item in ipairs(layout.items) do
		local opt = item.opt
		local el
		if opt.type == "checkbox" then
			el = guielement:new("checkbox", DESC_X+3, item.y, function(v)
				opts[opt.key] = v
				el.var = v
			end, opts[opt.key])
		elseif opt.type == "dropdown" then
			local entries = {}
			local w = 1
			for j, e in ipairs(opt.entries) do
				entries[j] = T(e)
				w = math.max(w, utf8.len(entries[j]))
			end
			el = guielement:new("dropdown", DESC_X+3, item.y + DESC_LINE*#item.labellines, w, function(v)
				opts[opt.key] = v
				el.var = v
			end, opts[opt.key], unpack(entries))
		end
		if el then
			el.active = false
			el.basey = el.y --where it sits before the panel is scrolled
			table.insert(minigamegui, el)
		end
	end
end

local function menusettled()
	return gamestate == "mappackmenu" and mappacktype == "minigames" and mappackhorscrollsmooth and math.abs(mappackhorscrollsmooth-3) < 0.01
end

function minigame_menu_update(dt)
	if minigamescrollsmooth > minigamescroll then
		minigamescrollsmooth = minigamescrollsmooth - (minigamescrollsmooth-minigamescroll)*dt*5-0.1*dt
		if minigamescrollsmooth < minigamescroll then
			minigamescrollsmooth = minigamescroll
		end
	elseif minigamescrollsmooth < minigamescroll then
		minigamescrollsmooth = minigamescrollsmooth - (minigamescrollsmooth-minigamescroll)*dt*5+0.1*dt
		if minigamescrollsmooth > minigamescroll then
			minigamescrollsmooth = minigamescroll
		end
	end
	for _, st in pairs(minigamepanelscroll) do
		if st.smooth ~= st.pos then
			st.smooth = st.smooth + (st.pos-st.smooth)*math.min(1, dt*15)
			if math.abs(st.smooth-st.pos) < 0.01 then
				st.smooth = st.pos
			end
		end
	end
	local settled = menusettled()
	minigame_updatescrollbars(dt, settled)
	for _, el in ipairs(minigamegui) do
		el.active = settled and el.panelvisible ~= false
		if not el.active and el.extended then
			el:close()
		end
		el:update(dt)
	end
end

--scroll position (in lines) of the description and the highscores, smooth follows pos
minigamepanelscroll = {desc = {pos = 0, smooth = 0}, score = {pos = 0, smooth = 0}}
local SCOREBOX_BOTTOM = 216 --bottom of the mappack menu area

--the highscores box fills the space left under the description
local function scorebox(def, layout)
	layout = layout or panellayout(def)
	local box = {y = layout.bottom + 4}
	box.listy = box.y + 2 + DESC_LINE
	box.scores = minigame_gethighscores(def)
	box.visible = math.max(1, math.floor((SCOREBOX_BOTTOM - 1 - box.listy)/DESC_LINE))
	box.listh = box.visible*DESC_LINE
	box.h = box.listy + box.listh + 1 - box.y
	box.maxscroll = math.max(0, #box.scores - box.visible)
	return box
end

--the two scrollable areas of the panel (game pixels), each gets a gui scrollbar when it doesn't fit
local SCROLLBAR_W = 8
local function panelareas(def, layout, box)
	layout = layout or panellayout(def)
	box = box or scorebox(def, layout)
	return {
		--description and settings: scrolled in pixels, one line per wheel notch
		{key = "desc", top = DESC_Y, bottom = layout.bottom, tracky = DESC_Y+1, trackh = layout.viewh-2,
			visible = layout.viewh, total = layout.contenth, max = layout.maxscroll, step = DESC_LINE},
		--highscores: scrolled in lines
		{key = "score", top = box.y, bottom = box.y+box.h, tracky = box.listy+1, trackh = box.listh-2,
			visible = box.visible, total = #box.scores, max = box.maxscroll, step = 1},
	}
end

minigamescrollbars = {} --gui scrollbars by area key

--make (or remake when the area changed) the gui scrollbar of an area, nil when everything fits
local function syncscrollbar(area)
	if area.max <= 0 then
		minigamescrollbars[area.key] = nil
		return nil
	end
	local el = minigamescrollbars[area.key]
	local x = DESC_X+DESC_W-SCROLLBAR_W-1
	local handle = math.max(10, math.floor(area.trackh*area.visible/area.total))
	local sig = x .. "," .. area.tracky .. "," .. area.trackh .. "," .. handle
	if not (el and el.sig == sig) then
		local value = el and el.value or minigamepanelscroll[area.key].smooth/area.max
		el = guielement:new("scrollbar", x, area.tracky, area.trackh, SCROLLBAR_W, handle, value, "ver")
		el.sig = sig
		el.scrollstepdisabled = true --the mouse wheel is handled by the area (one line per notch)
		el.releasefunc = function()
			--settle on a whole line
			local st = minigamepanelscroll[area.key]
			st.pos = math.max(0, math.min(area.max, round(st.pos/area.step)*area.step))
		end
		minigamescrollbars[area.key] = el
	end
	return el
end

--keep the scrollbars and the scroll positions in step (called from minigame_menu_update)
function minigame_updatescrollbars(dt, settled)
	local def = minigamelist[minigameselection]
	if settled and def then
		for _, area in ipairs(panelareas(def)) do
			local el = syncscrollbar(area)
			if el then
				el.active = true
				el:update(dt)
				local st = minigamepanelscroll[area.key]
				if el.dragging then
					st.pos = el.value*area.max
					st.smooth = st.pos
				else
					el.value = st.smooth/area.max
				end
			end
		end
	else
		for _, el in pairs(minigamescrollbars) do
			el.active = false
			el.dragging = false
		end
	end
	minigame_placegui()
end

--move the settings with the scrolled panel
function minigame_placegui()
	local def = minigamelist[minigameselection]
	if not def then
		return
	end
	local layout = panellayout(def)
	local offset = minigamepanelscroll.desc.smooth
	for _, el in ipairs(minigamegui) do
		el.y = (el.basey or el.y) - offset
		--hidden above or below the panel: can't be clicked
		local h = (el.type == "dropdown") and 11 or 9
		el.panelvisible = el.y + h > DESC_Y and el.y < layout.bottom
	end
end

local function scrollbardragging()
	for _, el in pairs(minigamescrollbars) do
		if el.dragging then
			return true
		end
	end
	return false
end

local function drawpanel()
	local def = minigamelist[minigameselection]
	if not def then
		return
	end
	local layout = panellayout(def)

	--description and game modes, scrolled together inside a box of at most half the game height
	love.graphics.setColor(0, 0, 0, 200)
	love.graphics.rectangle("fill", DESC_X*scale, DESC_Y*scale, DESC_W*scale, (layout.bottom-DESC_Y)*scale)
	local sx, sy, sw, sh = love.graphics.getScissor()
	love.graphics.setScissor(DESC_X*scale, DESC_Y*scale, DESC_W*scale, layout.viewh*scale)
	local offset = minigamepanelscroll.desc.smooth
	love.graphics.setColor(255, 255, 255)
	for i, line in ipairs(layout.lines) do
		local y = DESC_Y+1+(i-1)*DESC_LINE-offset
		if y > DESC_Y-DESC_LINE and y < layout.bottom then
			properprintF(line, (DESC_X+3)*scale, round(y*scale))
		end
	end
	love.graphics.setColor(200, 200, 200)
	for _, item in ipairs(layout.items) do
		local x = (item.opt.type == "checkbox") and CHECKBOX_LABEL_X or DESC_X+3
		for j, line in ipairs(item.labellines) do
			properprintF(line, x*scale, round((item.y+1+(j-1)*DESC_LINE-offset)*scale))
		end
	end
	--gui elements (an open dropdown is drawn later, on top of everything)
	local ontop
	for _, el in ipairs(minigamegui) do
		if el.extended or (el.listvalue and el.listvalue > 0) then
			ontop = el
		else
			el:draw()
		end
	end
	if sx then
		love.graphics.setScissor(sx, sy, sw, sh)
	else
		love.graphics.setScissor()
	end
	if minigamescrollbars.desc then
		minigamescrollbars.desc:draw()
	end
	local box = scorebox(def, layout)

	--highscores: every score, best first, scrollable with the mouse wheel
	love.graphics.setColor(0, 0, 0, 200)
	love.graphics.rectangle("fill", DESC_X*scale, box.y*scale, DESC_W*scale, box.h*scale)
	love.graphics.setColor(255, 255, 255)
	properprintF(T("highscores"), (DESC_X+3)*scale, (box.y+2)*scale)
	local sx, sy, sw, sh = love.graphics.getScissor()
	love.graphics.setScissor(DESC_X*scale, box.listy*scale, DESC_W*scale, box.listh*scale)
	love.graphics.setColor(160, 160, 160)
	if #box.scores == 0 then
		properprintF("1. -", (DESC_X+3)*scale, box.listy*scale)
	else
		local scroll = minigamepanelscroll.score.smooth
		local first = math.max(1, math.floor(scroll)+1)
		local last = math.min(#box.scores, first+box.visible)
		for i = first, last do
			local y = box.listy + (i-1-scroll)*DESC_LINE
			properprintF(i .. ". " .. formatscore(box.scores[i]), (DESC_X+3)*scale, round(y*scale))
		end
	end
	if sx then
		love.graphics.setScissor(sx, sy, sw, sh)
	else
		love.graphics.setScissor()
	end
	--scrollbar when there are more scores than fit
	if minigamescrollbars.score then
		minigamescrollbars.score:draw()
	end

	if ontop then
		ontop:draw()
	end
	love.graphics.setColor(255, 255, 255)
end

--title and short description in the center of the minigame graphic (lowercase letters)
local OVERLAY_CHARS = math.floor((GRAPHIC_W-8)/8)
local function drawgraphicoverlay(def, x, y, selected)
	local lines = {T(def.name):lower()}
	if def.tagline then
		for _, line in ipairs(wraptext(T(def.tagline):lower(), OVERLAY_CHARS)) do
			table.insert(lines, line)
		end
	end
	local w = 0
	for _, line in ipairs(lines) do
		w = math.max(w, textwidth(line))
	end
	w = math.min(GRAPHIC_W, w+8)
	local h = DESC_LINE*#lines+2
	local top = y + math.floor((GRAPHIC_H-h)/2)
	local left = x + math.floor((GRAPHIC_W-w)/2)
	love.graphics.setColor(0, 0, 0, 175)
	love.graphics.rectangle("fill", left*scale, top*scale, w*scale, h*scale, 2*scale)
	for i, line in ipairs(lines) do
		local color
		if i == 1 then
			color = selected and {255, 255, 255} or {215, 215, 215}
		else
			color = selected and {255, 230, 120} or {185, 185, 185}
		end
		love.graphics.setColor(255, 255, 255)
		properprintFbackground(line, (x + math.floor((GRAPHIC_W-textwidth(line))/2))*scale, (top+2+(i-1)*DESC_LINE)*scale, true, color)
	end
	love.graphics.setColor(255, 255, 255)
end

function minigame_menu_draw()
	love.graphics.setScissor(21*scale, 16*scale, 218*scale, 200*scale)
	love.graphics.translate(0, -round(minigamescrollsmooth*OPTION_SPACING*scale))
	for i = math.max(1, math.floor(minigamescrollsmooth+1)), math.min(#minigamelist, math.floor(minigamescrollsmooth+5)) do
		local def = minigamelist[i]
		local y = OPTION_Y+(i-1)*OPTION_SPACING
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(mappackback, OPTION_X*scale, y*scale, 0, scale, scale)

		local img = minigame_getgraphic(def)
		if img then
			love.graphics.draw(img, (OPTION_X+4)*scale, (y+4)*scale, 0, scale*GRAPHIC_W/math.max(1, img:getWidth()), scale*GRAPHIC_H/math.max(1, img:getHeight()))
		else
			--placeholder until graphics/minigames/<id>.png exists
			love.graphics.setColor(0, 0, 0, 160)
			love.graphics.rectangle("fill", (OPTION_X+4)*scale, (y+4)*scale, GRAPHIC_W*scale, GRAPHIC_H*scale)
		end
		drawgraphicoverlay(def, OPTION_X+4, y+4, i == minigameselection)

		if i == minigameselection then
			love.graphics.setColor(255, 255, 255)
			love.graphics.draw(mappackhighlight, OPTION_X*scale, y*scale, 0, scale, scale)
		end
	end
	love.graphics.translate(0, round(minigamescrollsmooth*OPTION_SPACING*scale))

	if #minigamelist > 3 then
		love.graphics.setColor(255, 255, 255)
		local i = minigamescrollsmooth / (#minigamelist-3.233)
		love.graphics.draw(mappackscrollbar, 227*scale, (20+i*160)*scale, 0, scale, scale)
	end

	love.graphics.setScissor()
	if menusettled() then
		drawpanel()
	end
	love.graphics.setColor(255, 255, 255)
end

local function changeselection(i)
	i = math.max(1, math.min(#minigamelist, i))
	if i ~= minigameselection then
		minigameselection = i
		minigame_updatescroll()
		minigame_buildgui()
		minigamepanelscroll = {desc = {pos = 0, smooth = 0}, score = {pos = 0, smooth = 0}}
		minigamescrollbars = {}
	end
end

local function openminigamedropdown()
	for _, el in ipairs(minigamegui) do
		if el.type == "dropdown" and el.extended then
			return el
		end
	end
end

--mouse wheel over the description or the highscores scrolls it (x, y in scaled pixels)
function minigame_menu_wheel(x, y, button)
	local def = minigamelist[minigameselection]
	if not (def and menusettled()) or openminigamedropdown() or scrollbardragging() then
		return false
	end
	--wheel events can arrive with converted coordinates, so read the cursor directly
	x, y = love.mouse.getPosition()
	if x < DESC_X*scale or x > (DESC_X+DESC_W)*scale then
		return false
	end
	for _, area in ipairs(panelareas(def)) do
		if y >= area.top*scale and y <= area.bottom*scale then
			local st = minigamepanelscroll[area.key]
			local step = area.step
			if button == "wu" then
				st.pos = math.max(0, (math.ceil(st.pos/step)-1)*step)
			elseif button == "wd" then
				st.pos = math.min(area.max, (math.floor(st.pos/step)+1)*step)
			end
			return true --the wheel belongs to the area while the cursor is on it
		end
	end
	return false
end

function minigame_menu_keypressed(key)
	local dd = openminigamedropdown()
	if dd then
		if key == "escape" then
			dd:close()
		else
			dd:keypress(key)
		end
		return true
	end
	if key == "up" or key == "w" then
		changeselection(minigameselection-1)
		return true
	elseif key == "down" or key == "s" then
		changeselection(minigameselection+1)
		return true
	elseif key == "return" or key == "enter" or key == "kpenter" or key == "kenter" or key == " " then
		minigame_start(minigameselection)
		return true
	end
	return false
end

local function optionat(x, y)
	--which minigame option is under the cursor (x, y in scaled pixels)
	for i = math.max(1, math.floor(minigamescrollsmooth+1)), math.min(#minigamelist, math.floor(minigamescrollsmooth+5)) do
		local top = OPTION_Y+(i-1)*OPTION_SPACING-round(minigamescrollsmooth*OPTION_SPACING)
		if x > OPTION_X*scale and x < (OPTION_X+OPTION_W)*scale and y > top*scale and y < (top+OPTION_H)*scale
			and y > 16*scale and y < 216*scale then
			return i
		end
	end
	return false
end

function minigame_menu_mousepressed(x, y, button)
	if menusettled() then
		local dd = openminigamedropdown()
		if dd then
			dd:click(x, y, button)
			return true
		end
		local def = minigamelist[minigameselection]
		local inpanel = def and y >= DESC_Y*scale and y < panellayout(def).bottom*scale --settings scrolled out of view can't be clicked
		for _, el in ipairs(minigamegui) do
			if inpanel and el.active and el:inhighlight(x, y) then
				el:click(x, y, button)
				return true
			end
		end
		--description and highscores scrollbars
		if button == "l" then
			for _, el in pairs(minigamescrollbars) do
				if el.active and el:inhighlight(x, y) then
					el:click(x, y, button)
					return true
				end
			end
		end
	end
	if button == "l" and not android then
		local i = optionat(x, y)
		if i and i == minigameselection then
			minigame_start(i)
			return true
		elseif i then
			changeselection(i)
			return true
		end
	end
	return false
end

function minigame_menu_mousereleased(x, y, button)
	for _, el in pairs(minigamescrollbars) do
		el:unclick(x, y)
	end
	for _, el in ipairs(minigamegui) do
		el:unclick(x, y)
	end
end

function minigame_menu_mousemoved(x, y)
	if scrollbardragging() then
		return --the gui scrollbar follows the mouse by itself
	end
	if android or openminigamedropdown() then
		return
	end
	local i = optionat(x, y)
	if i then
		changeselection(i)
	end
end

----------------------
--  START AND STOP  --
----------------------

function minigame_start(i)
	local def = minigamelist[i]
	if not def then
		return false
	end
	if mappacklistthread and mappacklistthread:isRunning() then
		mappacklistthreadchannelin:push({"stop"})
	end
	for _, el in ipairs(minigamegui) do
		if el.extended then
			el:close()
		end
	end
	minigamecurrent = def
	minigamestate = false
	minigameresult = false
	minigamescreen = false
	--one player only, just like the daily challenges
	if not minigameoldplayers then
		minigameoldplayers = players
	end
	players = 1
	infinitetime = false
	warpfadeoutnow()
	game_load("minigame")
	return true
end

--fade to black, then go back to the minigame menu (used by the pause menu)
function minigame_exit()
	if warpfade then
		return false
	end
	return startwarpfade(function()
		pausemenuopen = false
		menuprompt = false
		pausedaudio = nil
		stopmusic()
		love.audio.stop()
		minigame_returntomenu()
	end, false, true)
end

--fade to black, then restart the current minigame (used by the pause menu)
function minigame_restart()
	if warpfade then
		return false
	end
	return startwarpfade(function()
		pausemenuopen = false
		pausedaudio = nil
		stopmusic()
		love.audio.stop()
		levelscreen_load("minigame")
	end, false, true)
end

function minigame_stopsounds()
	if scoreringsound then scoreringsound:stop() end
	if windsound then windsound:stop() end
end

function minigame_returntomenu()
	minigame_stopsounds()
	minigameplaying = false
	minigamescreen = false
	lowgravity = false
	if minigameoldplayers then
		players = minigameoldplayers
		minigameoldplayers = nil
	end
	menu_load()
	gamestate = "mappackmenu"
	mappackhorscroll = 3
	mappackhorscrollsmooth = 3
	loadminigames()
end

--ends the current run: wait (optionally freezing the game and stopping the audio), then fade to the win/lose screen
function minigame_finish(result, delay, freeze)
	local S = minigamestate
	if not S or S.finish then
		return
	end
	S.finish = {result = result, timer = delay or 0, freeze = freeze}
	if freeze then
		stopmusic()
		love.audio.stop()
	end
end

--------------------
--  GAME  HOOKS  --
--------------------

local function hideplayers()
	for _, p in pairs(objects["player"]) do
		p.active = false
		p.drawable = false
		p.controlsenabled = false
		p.speedx = 0
		p.speedy = 0
	end
end

function minigame_createmap()
	local def = minigamecurrent

	--always the built-in daily challenge music
	custommusics = custommusics or {}
	if love.filesystem.getInfo("sounds/dailychallenge.ogg") then
		custommusics["dc"] = "sounds/dailychallenge.ogg"
	else
		custommusics["dc"] = "sounds/overworld-fast.ogg"
	end
	music:load(custommusics["dc"])
	musici = 7
	custommusic = false
	custommusici = "dc"

	pausemenuopentimer = 0
	menuprompttimer = 0
	desktopprompttimer = 0
	suspendprompttimer = 0
	mariotimelimit = 400
	background = 1
	backgroundrgbon = false
	spriteset = 1
	mariocoincount = 0
	marioscore = 0
	underwater = false
	realtime = false
	portalgun = false
	mariosizes = mariosizes or {}
	for i = 1, players do
		mariosizes[i] = 1
	end

	mapwidth = width
	originalmapwidth = mapwidth
	mapheight = 15
	map = {}
	for x = 1, mapwidth do
		map[x] = {}
		for y = 1, mapheight do
			map[x][y] = {1}
			map[x][y]["gels"] = {}
		end
	end
	startx = math.floor(mapwidth/2)+0.5
	starty = 13

	--minigame physics are always mario maker (a minigame can switch to mari0-maker, see jumping juggle jamboree)
	currentphysics = 6
	setphysics(currentphysics)

	minigamestate = {score = 0, time = 0, popups = {}, options = minigameoptions[def.id] or {}}
	if def.createmap then
		def.createmap(minigamestate, minigamestate.options)
	end

	--collision
	for x = 1, mapwidth do
		for y = 1, mapheight do
			if tilequads[map[x][y][1]] and tilequads[map[x][y][1]].collision == true then
				objects["tile"][tilemap(x, y)] = tile:new(x-1, y-1, 1, 1, true)
			end
		end
	end
end

function minigame_postload()
	local def = minigamecurrent
	if not (def and minigamestate) then
		return
	end
	if not def.usesplayer then
		hideplayers()
	end
	if def.postload then
		def.postload(minigamestate)
	end
end

function minigame_update(dt)
	local S, def = minigamestate, minigamecurrent
	if not (S and def) then
		return false
	end
	if not def.usesplayer then
		hideplayers()
	end
	S.time = S.time + dt

	for i = #S.popups, 1, -1 do
		local p = S.popups[i]
		p.t = p.t + dt
		if p.t > 0.8 then
			table.remove(S.popups, i)
		end
	end

	if S.finish then
		S.finish.timer = S.finish.timer - dt
		if S.finish.timer <= 0 and not S.finish.fading then
			minigame_recordscore()
			local reason = (S.finish.result == "win") and "minigamewin" or "minigamelose"
			if startwarpfade(function() levelscreen_load(reason) end) ~= false then
				S.finish.fading = true
			end
		end
		if S.finish.freeze then
			return true
		end
	end

	if def.update then
		return def.update(S, dt) == true
	end
	return false
end

function minigame_drawworld()
	local S, def = minigamestate, minigamecurrent
	if S and def and def.drawworld then
		love.graphics.setColor(255, 255, 255)
		def.drawworld(S)
		love.graphics.setColor(255, 255, 255)
	end
end

function minigame_drawHUD()
	local S, def = minigamestate, minigamecurrent
	if not (S and def) then
		return
	end
	if def.drawhud then
		--custom HUD
		def.drawhud(S)
		love.graphics.setColor(255, 255, 255)
		return
	end
	--by default there is a score element, minigames can add more
	local items = {{label = "score", value = formatscore(S.score or 0)}}
	if def.hud then
		def.hud(S, items)
	end
	local printfunc = hudoutline and properprintFbackground or properprintF
	for i, item in ipairs(items) do
		local col = item.column or (i-0.5)
		love.graphics.setColor(hudtextcolor or {255, 255, 255})
		local x = uispace*col - 24*scale
		printfunc(item.label, x, 8*scale)
		printfunc(tostring(item.value), x, 16*scale)
	end
	love.graphics.setColor(255, 255, 255)
end

function minigame_drawoverlay()
	local S, def = minigamestate, minigamecurrent
	if not (S and def) then
		return
	end
	love.graphics.setColor(255, 255, 255)
	if def.drawoverlay then
		def.drawoverlay(S)
	end
	for _, p in ipairs(S.popups) do
		local a = 1 - p.t/0.8
		local c = p.color or {255, 255, 255}
		love.graphics.setColor(c[1], c[2], c[3], 255*a)
		properprintFbackground(p.text, (p.x - textwidth(p.text)/2)*scale, (p.y - p.t*20)*scale)
	end
	if hudvisible then
		minigame_drawHUD()
	end
	love.graphics.setColor(255, 255, 255)
end

function minigame_mousepressed(x, y, button)
	local S, def = minigamestate, minigamecurrent
	if S and def and def.mousepressed and not S.finish then
		def.mousepressed(S, x/scale, y/scale, button)
	end
end

--a minigame can lock every control except jump (Jumping Juggle Jamboree, until the player jumps off the blocks)
function minigame_controlslocked(i)
	local S, def = minigamestate, minigamecurrent
	if not (minigameplaying and gamestate == "game" and S and def and def.lockcontrols) or S.finish or (i and i ~= 1) then
		return false
	end
	local p = objects and objects["player"] and objects["player"][1]
	if not p or p.dead or p.jumping then
		return false
	end
	return def.lockcontrols(S) == true
end

--controller buttons other than jump do nothing while the controls are locked
function minigame_joystickblocked(joystick, button)
	return minigame_controlslocked(1) and not controlbindingmatchesjoy(1, "jump", joystick, button)
end

function minigame_keypressed(key)
	local S, def = minigamestate, minigamecurrent
	if minigame_controlslocked(1) and not controlbindingmatcheskey(1, "jump", key) then
		return true --swallow the key (turning, ducking, running, using...)
	end
	if S and def and def.keypressed and not S.finish then
		return def.keypressed(S, key) == true
	end
	return false
end

--count stomps and bounce like there was no low gravity (Jumping Juggle Jamboree)
if mario and mario.stompenemy then
	local stompenemy = mario.stompenemy
	function mario:stompenemy(a, b)
		local r = stompenemy(self, a, b)
		if minigameplaying and minigamecurrent and minigamecurrent.onstomp and minigamestate then
			minigamecurrent.onstomp(minigamestate, self, a, b)
		end
		return r
	end
end

--held buttons (Jumping Juggle Jamboree)
--jump: from the moment the player jumps off the ground, jump counts as held until the run ends
function minigame_jumpheld(i)
	local S, def = minigamestate, minigamecurrent
	if not (minigameplaying and gamestate == "game" and S and def and def.holdjump) or S.finish or i ~= 1 then
		return false
	end
	local p = objects and objects["player"] and objects["player"][1]
	if not p or p.dead then
		return false
	end
	return S.jumped or p.jumping
end

if jumpkey then
	local originaljumpkey = jumpkey
	function jumpkey(i)
		if minigame_jumpheld(i) then
			return true
		end
		return originaljumpkey(i)
	end
end

--held directions and buttons read every frame are released while the controls are locked
for _, name in ipairs({"leftkey", "rightkey", "upkey", "downkey", "runkey", "usekey", "reloadkey"}) do
	local original = _G[name]
	if original then
		_G[name] = function(i, ...)
			if minigame_controlslocked(i) then
				return false
			end
			return original(i, ...)
		end
	end
end

--------------------
--  LEVELSCREENS  --
--------------------

local confetti = {}
local confettispawntimer = 0
local confetticolors = {{255, 64, 64}, {255, 170, 40}, {255, 240, 60}, {80, 220, 90}, {60, 170, 255}, {170, 90, 255}, {255, 110, 200}}

local function newconfetti(y)
	return {
		x = math.random()*width*16, y = y or -8,
		speedx = rnd(-25, 25), speedy = rnd(35, 80),
		rot = math.random()*math.pi*2, rotspeed = rnd(-6, 6),
		flip = math.random()*math.pi*2, flipspeed = rnd(4, 10),
		sway = math.random()*math.pi*2, swayspeed = rnd(1.5, 3.5),
		w = rnd(3, 6), h = rnd(2, 4),
		color = randomitem(confetticolors),
	}
end

local function confetti_start()
	confetti = {}
	confettispawntimer = 0
	for i = 1, 90 do
		table.insert(confetti, newconfetti(-math.random()*height*16))
	end
end

local function confetti_update(dt)
	for i = #confetti, 1, -1 do
		local c = confetti[i]
		c.sway = c.sway + c.swayspeed*dt
		c.x = c.x + (c.speedx + math.sin(c.sway)*20)*dt
		c.y = c.y + c.speedy*dt
		c.rot = c.rot + c.rotspeed*dt
		c.flip = c.flip + c.flipspeed*dt
		if c.y > height*16+10 then
			table.remove(confetti, i)
		end
	end
	confettispawntimer = confettispawntimer + dt
	while confettispawntimer > 1/45 do
		confettispawntimer = confettispawntimer - 1/45
		table.insert(confetti, newconfetti())
	end
end

local function confetti_draw()
	for _, c in ipairs(confetti) do
		local flip = math.cos(c.flip)
		local shade = 0.55 + 0.45*math.abs(flip)
		love.graphics.setColor(c.color[1]*shade, c.color[2]*shade, c.color[3]*shade)
		love.graphics.push()
		love.graphics.translate(c.x*scale, c.y*scale)
		love.graphics.rotate(c.rot)
		love.graphics.scale(flip, 1)
		love.graphics.rectangle("fill", -c.w/2*scale, -c.h/2*scale, c.w*scale, c.h*scale)
		love.graphics.pop()
	end
	love.graphics.setColor(255, 255, 255)
end

function minigame_levelscreen_load(reason)
	minigame_stopsounds()
	music:disableintromusic()
	levelscreenimagecheck = false
	dcfinish = false
	gamestate = "minigamelevelscreen"

	if reason == "minigame" then
		minigamescreen = "intro"
		minigamestate = false --a fresh run starts after the intro
		minigameresult = false
		blacktime = 1.5
	else
		--endless minigames have no real win, so a big enough score turns the loss into a victory
		if (reason == "minigamelose" or reason == "death") and minigamecurrent
			and (minigamecurrent.endless or minigamecurrent.scorevictory)
			and minigamestate and (minigamestate.score or 0) > victoryscore then
			reason = "minigamewin"
		end
		minigame_recordscore()
		stopmusic()
		love.audio.stop()
		--blacktime ends when the sound does (the fade out starts right after it)
		if reason == "minigamewin" then
			minigamescreen = "win"
			blacktime = dcwin2sound:getDuration("seconds") + warpfadetime
			playsound(dcwin2sound)
			confetti_start()
		else --"minigamelose" or the player's death
			minigamescreen = "lose"
			--a new highscore gets the victory sound even on a loss
			local sound = (minigameresult and minigameresult.highscore) and dcwin2sound or dclose2sound
			blacktime = sound:getDuration("seconds") + warpfadetime
			playsound(sound)
		end
	end

	coinframe = 1
	love.graphics.setBackgroundColor(0, 0, 0)
	levelscreentimer = 0
	if not maptransitionsdisabled() then
		warpfadein = {t = 0}
	end
	if warpfade and warpfade.hold then
		warpfade = nil
	end
end

function minigame_levelscreen_update(dt)
	if minigamescreen == "win" then
		confetti_update(dt)
	end
end

function minigame_levelscreen_draw()
	local def = minigamecurrent
	if not def then
		return
	end
	local cx = width*8
	local name = T(def.name)
	if minigamescreen == "intro" then
		centerprintline(name, cx, 100)
		centerprintline(T("get ready!"), cx, 124, {200, 200, 200})
	else
		if minigamescreen == "win" then
			confetti_draw()
			centerprintline(T("you win!"), cx, 84)
		else
			centerprintline(T("game over!"), cx, 84)
		end
		centerprintline(name, cx, 104, {200, 200, 200})
		local score = minigameresult and minigameresult.score or (minigamestate and minigamestate.score) or 0
		centerprintline("score: " .. formatscore(score), cx, 128)
		local y = 144
		if minigameresult and minigameresult.title then
			centerprintline(T("title: ") .. T(minigameresult.title), cx, y, {140, 230, 255})
			y = y + 16
		end
		if minigameresult and minigameresult.highscore and math.floor(levelscreentimer/0.25) % 2 == 0 then
			centerprintline(T("new highscore!"), cx, y, {255, 220, 60})
		end
	end
	love.graphics.setColor(255, 255, 255)
end

------------------------
--  BOO BAFFLER BASH  --
------------------------

local BOO_ANIM_TIME = 0.1 --the whole animation (column 1, column 2)
local BOO_START_TIME = 10
local BOO_INCREMENT_INTERVAL = 0.0625
local BOO_WAIT = 0.5
local BOO_FADE_TIME = 0.5
local BOO_ROTATE_TIME = 0.25
local BOO_CROSS_TIME = 0.5
local BOO_ROUNDTYPES = {"shy", "circle", "chain", "wave", "lanes", "spiral", "flock", "shuffle", "teleport", "flee", "phase", "swing", "superrandom"}
local BOO_SPEEDUP = 0.025 --boos move this much faster every round...
local BOO_SPEEDUP_MAX = 0.5 --...up to 50% faster
local BOO_TOP = 2.5 --boos stay under the HUD (tiles)
local BOO_BONUS_STEP = 3 --found in less than n*3 seconds: add 6-n seconds
local BOO_BONUS_MAX = 5
local BOO_METER_W, BOO_METER_H = 40, 4 --bonus meter under the boo to find
local BOO_METER_Y = 37

local function boo_bonus(roundtime)
	local n = math.floor(roundtime/BOO_BONUS_STEP)+1
	return math.max(0, BOO_BONUS_MAX+1-n)
end

--how many meter segments are filled: full ones for the bonus below the current one, the current one drains over its 3 seconds
local function boo_bonusfill(roundtime)
	local bonus = boo_bonus(roundtime)
	if bonus <= 0 then
		return 0
	end
	local intostep = (roundtime % BOO_BONUS_STEP)/BOO_BONUS_STEP
	return (bonus-1) + (1-intostep)
end

--bonus colour: red when the meter is empty, yellow at half, green when full
local function boo_bonuscolour(roundtime)
	local percent = math.max(0, math.min(1, boo_bonusfill(roundtime)/BOO_BONUS_MAX))
	if percent <= 0 then
		return {255, 0, 0}
	elseif percent < 0.5 then
		return hsv_lerp({255, 0, 0}, {255, 255, 0}, percent/0.5)
	elseif percent < 1 then
		return hsv_lerp({255, 255, 0}, {0, 255, 0}, (percent-0.5)/0.5)
	end
	return {0, 255, 0}
end
local boofallbackcolors = {{255, 255, 255}, {255, 160, 160}, {140, 200, 255}} --tints when minigame_boo.png is missing
local booquads = nil

local function boo_graphic(variant, frame)
	local img = minigame_image("minigame_boo.png") --2 columns (animation) and 3 rows (boos), 16x16 each
	if img then
		if not booquads then
			booquads = {}
			for row = 1, 3 do
				booquads[row] = {}
				for col = 1, 2 do
					booquads[row][col] = love.graphics.newQuad((col-1)*16, (row-1)*16, 16, 16, img:getWidth(), img:getHeight())
				end
			end
		end
		return img, booquads[variant][frame], boofallbackcolors[1]
	end
	return booimage, booquad[spriteset or 1][frame], boofallbackcolors[variant]
end

local function boo_frame(b)
	return math.min(2, math.floor(b.frametimer/BOO_ANIM_TIME)+1)
end

local function boo_position(b)
	return b.x, b.y
end

local function boo_stop(b)
	if not b.stopped then
		b.x, b.y = boo_position(b)
		b.stopped = true
		b.alpha = 255 --shy and phasing boos are see-through
	end
end

--------------------------
--  BOO MOVEMENT TYPES  --
--------------------------
--positions are the top left of the boo in tiles, S.movetime is the round's time (already sped up)

local function boo_area()
	return 0, BOO_TOP, width-1, height-1 --smallest and largest top left position
end

local function boo_clamp(b)
	local x0, y0, x1, y1 = boo_area()
	b.x = math.max(x0, math.min(x1, b.x))
	b.y = math.max(y0, math.min(y1, b.y))
end

local function boo_mouse()
	local x, y = love.mouse.getPosition()
	return x/scale/16, y/scale/16
end

local function boo_shufflelist(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

--n spread out positions (a jittered grid), so the boos start readable
local function boo_spots(n)
	local x0, y0, x1, y1 = boo_area()
	local w, h = x1-x0, y1-y0
	local cols = math.max(1, math.ceil(math.sqrt(n*w/h)))
	local rows = math.max(1, math.ceil(n/cols))
	local spots = {}
	for r = 0, rows-1 do
		for c = 0, cols-1 do
			table.insert(spots, {x = x0 + (c + rnd(0.15, 0.85))*w/cols, y = y0 + (r + rnd(0.15, 0.85))*h/rows})
		end
	end
	return boo_shufflelist(spots)
end

local function boo_placespread(boos)
	local spots = boo_spots(#boos)
	for i, b in ipairs(boos) do
		b.x, b.y = spots[i].x, spots[i].y
	end
end

--a random direction that slowly turns (used by flee and phase)
local function boo_wander(b, dt, speed)
	b.heading = b.heading + b.turn*dt
	if math.random() < dt*0.5 then
		b.turn = rnd(-1.5, 1.5)
	end
	local x0, y0, x1, y1 = boo_area()
	local vx, vy = math.cos(b.heading)*speed, math.sin(b.heading)*speed
	--turn back at the edges
	if (b.x <= x0 and vx < 0) or (b.x >= x1 and vx > 0) then
		b.heading = math.pi - b.heading
	end
	if (b.y <= y0 and vy < 0) or (b.y >= y1 and vy > 0) then
		b.heading = -b.heading
	end
	return math.cos(b.heading)*speed, math.sin(b.heading)*speed
end

local function boo_wanderinit(b)
	b.heading = rnd(0, math.pi*2)
	b.turn = rnd(-1.5, 1.5)
end

--a closed lissajous curve over the play area, walked by arc length
local function boo_newcurve()
	local x0, y0, x1, y1 = boo_area()
	local p = randomitem({{1, 2}, {2, 1}, {2, 3}, {3, 2}, {1, 3}, {3, 4}})
	local ax, ay = (x1-x0)/2*rnd(0.75, 1), (y1-y0)/2*rnd(0.75, 1)
	local cx, cy = (x0+x1)/2, (y0+y1)/2
	local phi = rnd(0, math.pi*2)
	local c = {pts = {}, len = {0}}
	local samples = 720
	for i = 0, samples do
		local t = math.pi*2*i/samples
		c.pts[i+1] = {cx + ax*math.sin(p[1]*t + phi), cy + ay*math.sin(p[2]*t)}
		if i > 0 then
			local a, b = c.pts[i], c.pts[i+1]
			c.len[i+1] = c.len[i] + math.sqrt((b[1]-a[1])^2 + (b[2]-a[2])^2)
		end
	end
	c.total = c.len[#c.len]
	return c
end

local function boo_curvepoint(c, s)
	s = s % c.total
	local lo, hi = 1, #c.len
	while hi - lo > 1 do
		local mid = math.floor((lo+hi)/2)
		if c.len[mid] <= s then
			lo = mid
		else
			hi = mid
		end
	end
	local seg = c.len[hi] - c.len[lo]
	local f = (seg > 0) and (s - c.len[lo])/seg or 0
	local a, b = c.pts[lo], c.pts[hi]
	return a[1] + (b[1]-a[1])*f, a[2] + (b[2]-a[2])*f
end

local BOO_SHY_RADIUS = 3.5 --boos this close to the cursor hide
local BOO_FLEE_RADIUS = 4

--super random: every boo has its own movement and swaps to a new one every 3-5 seconds
local BOO_RANDOM_INTERVAL = {3, 5} --seconds (not sped up by the round)

--keep a moving boo inside the play area by bouncing it off the edges
local function boo_bounceinside(b)
	local x0, y0, x1, y1 = boo_area()
	if (b.x <= x0 and b.vx < 0) or (b.x >= x1 and b.vx > 0) then
		b.vx = -b.vx
	end
	if (b.y <= y0 and b.vy < 0) or (b.y >= y1 and b.vy > 0) then
		b.vy = -b.vy
	end
	boo_clamp(b)
end

local BOO_RANDOM_MOVES = {
	--floats in a straight line, bouncing off the edges
	drift = {
		start = function(S, b)
			local a, speed = rnd(0, math.pi*2), rnd(1, 3)
			b.vx, b.vy = math.cos(a)*speed, math.sin(a)*speed
		end,
		update = function(S, b, dt)
			b.x, b.y = b.x + b.vx*dt, b.y + b.vy*dt
			boo_bounceinside(b)
		end,
	},
	--strolls around, slowly changing direction
	wander = {
		start = function(S, b)
			boo_wanderinit(b)
		end,
		update = function(S, b, dt)
			local vx, vy = boo_wander(b, dt, 1.5)
			b.x, b.y = b.x + vx*dt, b.y + vy*dt
			boo_clamp(b)
		end,
	},
	--moves in a zigzag
	zigzag = {
		start = function(S, b)
			local a, speed = rnd(0, math.pi*2), rnd(1.5, 2.5)
			b.vx, b.vy = math.cos(a)*speed, math.sin(a)*speed
			b.zigfreq, b.zigamp = rnd(4, 7), rnd(2, 4)
		end,
		update = function(S, b, dt)
			local speed = math.sqrt(b.vx*b.vx + b.vy*b.vy)
			local side = math.cos(b.zigfreq*b.rt)*b.zigamp
			b.x = b.x + (b.vx - b.vy/speed*side)*dt
			b.y = b.y + (b.vy + b.vx/speed*side)*dt
			boo_bounceinside(b)
		end,
	},
	--circles around a spot next to it
	orbit = {
		start = function(S, b)
			local x0, y0, x1, y1 = boo_area()
			local r, a = rnd(1, 2.5), rnd(0, math.pi*2)
			local cx = math.max(x0+r, math.min(x1-r, b.x - math.cos(a)*r))
			local cy = math.max(y0+r, math.min(y1-r, b.y - math.sin(a)*r))
			b.orbit = {x = cx, y = cy, r = math.sqrt((b.x-cx)^2 + (b.y-cy)^2), a = math.atan2(b.y-cy, b.x-cx), speed = randomsign()*rnd(1.5, 3)}
		end,
		update = function(S, b, dt)
			local o = b.orbit
			o.a = o.a + o.speed*dt
			b.x, b.y = o.x + math.cos(o.a)*o.r, o.y + math.sin(o.a)*o.r
			boo_clamp(b)
		end,
	},
	--stays in place, bobbing up and down
	bob = {
		start = function(S, b)
			b.basey, b.bobamp, b.bobfreq = b.y, rnd(0.3, 0.8), rnd(3, 6)
		end,
		update = function(S, b, dt)
			b.y = b.basey + math.sin(b.bobfreq*b.rt)*b.bobamp
			boo_clamp(b)
		end,
	},
	--waits, then shoots off in a random direction
	dash = {
		start = function(S, b)
			b.dashwait, b.dashleft, b.vx, b.vy = rnd(0.3, 0.8), 0, 0, 0
		end,
		update = function(S, b, dt)
			if b.dashleft > 0 then
				b.dashleft = b.dashleft - dt
				b.x, b.y = b.x + b.vx*dt, b.y + b.vy*dt
				boo_bounceinside(b)
			else
				b.dashwait = b.dashwait - dt
				if b.dashwait <= 0 then
					local a = rnd(0, math.pi*2)
					b.vx, b.vy = math.cos(a)*8, math.sin(a)*8
					b.dashleft, b.dashwait = 0.25, rnd(0.4, 0.9)
				end
			end
		end,
	},
	--vanishes in a poof and pops up somewhere else, then hovers
	teleport = {
		start = function(S, b)
			makepoof(b.x+0.5, b.y+1, "poof")
			local x0, y0, x1, y1 = boo_area()
			b.x, b.y = rnd(x0, x1), rnd(y0+0.2, y1-0.2)
			b.basey = b.y
		end,
		update = function(S, b, dt)
			b.y = b.basey + 0.15*math.sin(3*b.rt)
		end,
	},
	--runs away from the cursor
	flee = {
		start = function(S, b)
			boo_wanderinit(b)
		end,
		update = function(S, b, dt)
			local vx, vy = boo_wander(b, dt, 0.8)
			local mx, my = boo_mouse()
			local dx, dy = (b.x+0.5) - mx, (b.y+0.5) - my
			local d = math.sqrt(dx*dx + dy*dy)
			if d < BOO_FLEE_RADIUS and d > 0 then
				local push = (1 - d/BOO_FLEE_RADIUS)*6
				vx, vy = vx + dx/d*push, vy + dy/d*push
			end
			b.x, b.y = b.x + vx*dt, b.y + vy*dt
			boo_clamp(b)
		end,
	},
	--sneaks towards the cursor and stops next to it
	chase = {
		start = function(S, b)
			b.chasespeed = rnd(1, 2)
		end,
		update = function(S, b, dt)
			local mx, my = boo_mouse()
			local dx, dy = mx - (b.x+0.5), my - (b.y+0.5)
			local d = math.sqrt(dx*dx + dy*dy)
			if d > 1.5 then
				b.x, b.y = b.x + dx/d*b.chasespeed*dt, b.y + dy/d*b.chasespeed*dt
				boo_clamp(b)
			end
		end,
	},
	--stops completely
	freeze = {
		start = function(S, b) end,
		update = function(S, b, dt) end,
	},
	--fades in and out while wandering slowly
	fade = {
		start = function(S, b)
			boo_wanderinit(b)
			b.fadespeed = rnd(1.5, 3)
		end,
		update = function(S, b, dt)
			local vx, vy = boo_wander(b, dt, 0.7)
			b.x, b.y = b.x + vx*dt, b.y + vy*dt
			boo_clamp(b)
			b.alpha = 25 + 230*(0.5 + 0.5*math.cos(b.fadespeed*b.rt))
		end,
	},
	--shakes on the spot
	jitter = {
		start = function(S, b)
			b.basex, b.basey = b.x, b.y
			b.shakex, b.shakey = rnd(0, math.pi*2), rnd(0, math.pi*2)
		end,
		update = function(S, b, dt)
			b.x = b.basex + 0.15*math.sin(23*b.rt + b.shakex)
			b.y = b.basey + 0.15*math.sin(17*b.rt + b.shakey)
		end,
	},
}
local BOO_RANDOM_NAMES = {}
for name in pairs(BOO_RANDOM_MOVES) do
	table.insert(BOO_RANDOM_NAMES, name)
end
table.sort(BOO_RANDOM_NAMES) --same order every time, so the seed decides

local function boo_randommove(S, b)
	local name
	repeat
		name = randomitem(BOO_RANDOM_NAMES)
	until name ~= b.randommove
	b.randommove = name
	b.rt = 0
	b.alpha = 255
	b.randomleft = rnd(BOO_RANDOM_INTERVAL[1], BOO_RANDOM_INTERVAL[2])
	BOO_RANDOM_MOVES[name].start(S, b)
end

local BOO_MOVES = {
	--1. shy: boos near the cursor stop and turn see-through, the others creep towards it
	shy = {
		init = function(S, boos)
			boo_placespread(boos)
			for _, b in ipairs(boos) do
				b.creep = rnd(0.7, 1.3)
			end
		end,
		update = function(S, b, dt)
			local mx, my = boo_mouse()
			local dx, dy = mx - (b.x+0.5), my - (b.y+0.5)
			local d = math.sqrt(dx*dx + dy*dy)
			if d < BOO_SHY_RADIUS then
				b.alpha = math.max(110, b.alpha - 600*dt)
				b.frametimer = 0 --frozen while hiding
			else
				b.alpha = math.min(255, b.alpha + 600*dt)
				b.x = b.x + dx/d*b.creep*dt
				b.y = b.y + dy/d*b.creep*dt
				boo_clamp(b)
			end
			--always face the cursor
			b.facing = (dx > 0) and -1 or 1
		end,
	},

	--2. circle: rings of boos around a few centres, some spinning each way
	circle = {
		init = function(S, boos)
			local x0, y0, x1, y1 = boo_area()
			local rings, capacity = {}, 0
			while capacity < #boos do
				local last = rings[#rings]
				local ring
				if last and math.random() < 0.4 and last.r + 1.4 <= math.min(last.cx-x0-0.5, x1+0.5-last.cx, last.cy-y0-0.5, y1+0.5-last.cy) then
					--around the same centre
					ring = {cx = last.cx, cy = last.cy, r = last.r + 1.4}
				else
					local r = math.min(rnd(1.5, 4), (x1-x0)/2, (y1-y0)/2)
					ring = {cx = rnd(x0+0.5+r, x1+0.5-r), cy = rnd(y0+0.5+r, y1+0.5-r), r = r}
				end
				ring.speed = randomsign()*rnd(0.5, 1.1)
				ring.angle = rnd(0, math.pi*2)
				ring.cap = math.max(3, math.floor(math.pi*2*ring.r/1.2))
				ring.boos = {}
				table.insert(rings, ring)
				capacity = capacity + ring.cap
			end
			local ri = 1
			for _, b in ipairs(boos) do
				while #rings[ri].boos >= rings[ri].cap do
					ri = ri + 1
				end
				table.insert(rings[ri].boos, b)
				b.ring = rings[ri]
			end
			for _, ring in ipairs(rings) do
				for k, b in ipairs(ring.boos) do
					b.ringoffset = math.pi*2*(k-1)/#ring.boos
				end
			end
		end,
		update = function(S, b, dt)
			local ring = b.ring
			local a = ring.angle + ring.speed*S.movetime + b.ringoffset
			b.x = ring.cx + ring.r*math.cos(a) - 0.5
			b.y = ring.cy + ring.r*math.sin(a) - 0.5
		end,
	},

	--3. chain: boos follow a leader in a snaking line
	chain = {
		init = function(S, boos)
			local chains = (#boos <= 12) and 1 or math.random(2, 3)
			local lists = {}
			for i = 1, chains do
				lists[i] = {curve = boo_newcurve(), speed = rnd(2, 3), start = 0}
			end
			for i, b in ipairs(boos) do
				local list = lists[(i-1) % chains + 1]
				b.chain = list
				list.count = (list.count or 0) + 1
				b.chainindex = list.count
			end
			for _, list in ipairs(lists) do
				list.spacing = math.min(1.15, list.curve.total/math.max(1, list.count))
				list.start = rnd(0, list.curve.total)
			end
		end,
		update = function(S, b, dt)
			local list = b.chain
			b.x, b.y = boo_curvepoint(list.curve, list.start + list.speed*S.movetime - b.chainindex*list.spacing)
		end,
	},

	--4. wave: drift sideways while bobbing on a sine wave
	wave = {
		init = function(S, boos)
			local x0, y0, x1, y1 = boo_area()
			for _, b in ipairs(boos) do
				b.vx = randomsign()*rnd(0.8, 2)
				b.amp = rnd(0.4, 1.5)
				b.freq = rnd(1.5, 3.5)
				b.phase = rnd(0, math.pi*2)
				b.basey = math.max(y0+b.amp, math.min(y1-b.amp, b.y))
			end
		end,
		update = function(S, b, dt)
			b.x = b.x + b.vx*dt
			if b.x+1 <= 0 and b.vx < 0 then
				b.x = width
			elseif b.x >= width and b.vx > 0 then
				b.x = -1
			end
			b.y = b.basey + b.amp*math.sin(b.phase + b.freq*S.movetime)
		end,
	},

	--5. lanes: rows sliding in alternating directions, wrapping around
	lanes = {
		init = function(S, boos)
			local x0, y0, x1, y1 = boo_area()
			local count = math.max(2, math.floor((y1-y0)/1.3)+1)
			local lanes = {}
			local dir = randomsign()
			for i = 1, count do
				lanes[i] = {y = y0 + (y1-y0)*(i-1)/(count-1), dir = dir, speed = rnd(1.5, 2.5), boos = {}}
				dir = -dir
			end
			for i, b in ipairs(boo_shufflelist({unpack(boos)})) do
				table.insert(lanes[(i-1) % count + 1].boos, b)
			end
			for _, lane in ipairs(lanes) do
				local n = #lane.boos
				lane.loop = math.max(width+2, n*rnd(1.6, 2.4))
				for k, b in ipairs(lane.boos) do
					b.lane = lane
					b.laneoffset = (k-1)*lane.loop/math.max(1, n) + rnd(0, 0.3)
				end
			end
		end,
		update = function(S, b, dt)
			local lane = b.lane
			b.x = (b.laneoffset + lane.dir*lane.speed*S.movetime) % lane.loop - 1
			b.y = lane.y
		end,
	},

	--6. spiral: arms of boos that spiral out from the centre and back in
	spiral = {
		init = function(S, boos)
			local x0, y0, x1, y1 = boo_area()
			S.spiral = {
				cx = (x0+x1)/2, cy = (y0+y1)/2, rx = (x1-x0)/2, ry = (y1-y0)/2,
				arms = math.random(2, 3), spin = randomsign()*rnd(0.4, 0.8),
				twist = randomsign()*rnd(2, 4), rate = rnd(0.12, 0.2),
			}
			for i, b in ipairs(boos) do
				b.arm = (i-1) % S.spiral.arms
				b.spiraloffset = (i-1)/#boos
			end
		end,
		update = function(S, b, dt)
			local sp = S.spiral
			local p = 0.5 - 0.5*math.cos(math.pi*2*(sp.rate*S.movetime + b.spiraloffset))
			local r = 0.08 + 0.92*p
			local a = b.arm*math.pi*2/sp.arms + sp.spin*S.movetime + sp.twist*r
			b.x = sp.cx + sp.rx*r*math.cos(a)
			b.y = sp.cy + sp.ry*r*math.sin(a)
		end,
	},

	--7. flock: boos swarm like a school of fish
	flock = {
		init = function(S, boos)
			for _, b in ipairs(boos) do
				local a = rnd(0, math.pi*2)
				b.vx, b.vy = math.cos(a)*2, math.sin(a)*2
			end
		end,
		update = function(S, b, dt)
			local ax, ay, cx, cy, sx, sy, n = 0, 0, 0, 0, 0, 0, 0
			for _, o in ipairs(S.boos) do
				if o ~= b and not o.stopped and not o.anim then
					local dx, dy = o.x - b.x, o.y - b.y
					local d = math.sqrt(dx*dx + dy*dy)
					if d < 3.5 then
						n = n + 1
						ax, ay = ax + o.vx, ay + o.vy
						cx, cy = cx + dx, cy + dy
						if d < 1.2 and d > 0 then
							sx, sy = sx - dx/(d*d), sy - dy/(d*d)
						end
					end
				end
			end
			if n > 0 then
				b.vx = b.vx + ((ax/n - b.vx)*1.5 + cx/n*0.8 + sx*3)*dt
				b.vy = b.vy + ((ay/n - b.vy)*1.5 + cy/n*0.8 + sy*3)*dt
			end
			--steer away from the edges
			local x0, y0, x1, y1 = boo_area()
			if b.x < x0+1.5 then b.vx = b.vx + 8*dt end
			if b.x > x1-1.5 then b.vx = b.vx - 8*dt end
			if b.y < y0+1.5 then b.vy = b.vy + 8*dt end
			if b.y > y1-1.5 then b.vy = b.vy - 8*dt end
			--keep a swimming speed
			local speed = math.sqrt(b.vx*b.vx + b.vy*b.vy)
			local target = math.max(1.8, math.min(3.2, speed))
			if speed > 0 then
				b.vx, b.vy = b.vx/speed*target, b.vy/speed*target
			end
			b.x = b.x + b.vx*dt
			b.y = b.y + b.vy*dt
			boo_clamp(b)
		end,
	},

	--8. shuffle: still for a moment, then every boo dashes to another boo's spot
	shuffle = {
		init = function(S, boos)
			boo_placespread(boos)
			S.shuffle = {stage = "hold", t = rnd(1.2, 2)}
		end,
		groupupdate = function(S, dt)
			local q = S.shuffle
			local active = {}
			for _, b in ipairs(S.boos) do
				if not b.stopped and not b.anim then
					table.insert(active, b)
				end
			end
			q.t = q.t - dt
			if q.stage == "hold" then
				if q.t <= 0 and #active > 1 then
					--each boo takes the spot of the next one in a shuffled order
					boo_shufflelist(active)
					for i, b in ipairs(active) do
						local to = active[i % #active + 1]
						b.from = {b.x, b.y}
						b.to = {to.x, to.y}
					end
					q.stage = "dash"
					q.duration = 0.7
					q.t = q.duration
				end
			elseif q.stage == "dash" then
				local p = 1 - math.max(0, q.t)/q.duration
				p = 0.5 - 0.5*math.cos(p*math.pi) --ease in and out
				for _, b in ipairs(active) do
					if b.from then
						b.x = b.from[1] + (b.to[1]-b.from[1])*p
						b.y = b.from[2] + (b.to[2]-b.from[2])*p
					end
				end
				if q.t <= 0 then
					for _, b in ipairs(active) do
						b.from, b.to = nil, nil
					end
					q.stage = "hold"
					q.t = rnd(1, 1.8)
				end
			end
		end,
	},

	--9. teleport: boos blink to a new spot with a poof, one at a time
	teleport = {
		init = function(S, boos)
			boo_placespread(boos)
			for _, b in ipairs(boos) do
				b.teleport = rnd(0.5, 3.5)
				b.basey = b.y
				b.bob = rnd(0, math.pi*2)
			end
		end,
		update = function(S, b, dt)
			b.teleport = b.teleport - dt
			if b.teleport <= 0 then
				makepoof(b.x+0.5, b.y+1, "poof")
				local x0, y0, x1, y1 = boo_area()
				b.x, b.basey = rnd(x0, x1), rnd(y0+0.15, y1-0.15)
				b.teleport = rnd(2, 4)
			end
			b.y = b.basey + 0.15*math.sin(b.bob + 3*S.movetime)
		end,
	},

	--10. flee: boos wander around and drift away from the cursor
	flee = {
		init = function(S, boos)
			for _, b in ipairs(boos) do
				boo_wanderinit(b)
			end
		end,
		update = function(S, b, dt)
			local vx, vy = boo_wander(b, dt, 0.9)
			local mx, my = boo_mouse()
			local dx, dy = (b.x+0.5) - mx, (b.y+0.5) - my
			local d = math.sqrt(dx*dx + dy*dy)
			if d < BOO_FLEE_RADIUS and d > 0 then
				local push = (1 - d/BOO_FLEE_RADIUS)*6
				vx, vy = vx + dx/d*push, vy + dy/d*push
			end
			b.x = b.x + vx*dt
			b.y = b.y + vy*dt
			boo_clamp(b) --so they can be cornered
		end,
	},

	--11. phase: boos wander slowly while fading in and out like ghosts
	phase = {
		init = function(S, boos)
			for _, b in ipairs(boos) do
				boo_wanderinit(b)
				b.fadespeed = rnd(0.8, 1.6)
				b.fadephase = rnd(0, math.pi*2)
			end
		end,
		update = function(S, b, dt)
			local vx, vy = boo_wander(b, dt, 0.7)
			b.x = b.x + vx*dt
			b.y = b.y + vy*dt
			boo_clamp(b)
			b.alpha = 25 + 230*(0.5 + 0.5*math.sin(b.fadephase + b.fadespeed*S.movetime))
		end,
	},

	--12. swing: boos hang on invisible strings and swing like a pendulum wave
	swing = {
		init = function(S, boos)
			local x0, y0, x1, y1 = boo_area()
			local count = math.max(4, math.min(10, math.ceil(#boos/3)))
			local pivoty = y0 - 0.5
			local reach = y1 + 0.5 - pivoty
			S.pendulums = {}
			for i = 1, count do
				local px = width*(0.2 + 0.6*(i-0.5)/count)
				S.pendulums[i] = {x = px, y = pivoty, boos = {}, omega = math.pi*2*(8+i)/30}
			end
			for i, b in ipairs(boos) do
				table.insert(S.pendulums[(i-1) % count + 1].boos, b)
			end
			for _, pd in ipairs(S.pendulums) do
				local m = #pd.boos
				local length = rnd(math.min(reach, 1.5 + 1.3*(m-1) + 1), reach)
				pd.length = length
				local margin = math.min(pd.x - 0.5, width - 0.5 - pd.x)
				pd.amp = math.min(0.75, math.asin(math.min(1, margin/length)))
				pd.phase = rnd(-0.3, 0.3)
				for k, b in ipairs(pd.boos) do
					b.pendulum = pd
					b.reach = length - (k-1)*1.3
				end
			end
		end,
		update = function(S, b, dt)
			local pd = b.pendulum
			local a = pd.amp*math.sin(pd.omega*S.movetime + pd.phase)
			b.x = pd.x + b.reach*math.sin(a) - 0.5
			b.y = pd.y + b.reach*math.cos(a) - 0.5
		end,
	},

	--13. super random: each boo moves its own random way and switches every 3-5 seconds
	superrandom = {
		init = function(S, boos)
			boo_placespread(boos)
			for _, b in ipairs(boos) do
				boo_randommove(S, b)
			end
		end,
		update = function(S, b, dt)
			b.rt = b.rt + dt
			b.randomleft = b.randomleft - dt/(S.speedmul or 1) --real seconds
			if b.randomleft <= 0 then
				boo_randommove(S, b)
			end
			BOO_RANDOM_MOVES[b.randommove].update(S, b, dt)
		end,
	},
}

local function boo_newround(S)
	S.phase = "play"
	S.roundtime = 0
	S.bonustime = nil
	S.seq = nil
	S.target = math.random(3)
	local roundtype
	repeat
		roundtype = randomitem(BOO_ROUNDTYPES)
	until roundtype ~= S.roundtype
	S.roundtype = roundtype
	S.speedmul = 1 + math.min(BOO_SPEEDUP_MAX, (S.round-1)*BOO_SPEEDUP)
	S.movetime = 0
	S.boos = {}

	local others = {}
	for v = 1, 3 do
		if v ~= S.target then
			table.insert(others, v)
		end
	end
	local count = math.random(math.min(4+S.round, 24), math.min(8+S.round*2, 40))
	local targetindex = math.random(count)
	for i = 1, count do
		local b = {
			istarget = (i == targetindex),
			variant = (i == targetindex) and S.target or randomitem(others),
			x = rnd(0, width-1), y = rnd(BOO_TOP, height-1),
			mode = S.roundtype,
			frametimer = math.random()*BOO_ANIM_TIME*2,
			scale = 1, alpha = 255, rot = 0,
			facing = randomsign(),
		}
		table.insert(S.boos, b)
	end
	local move = BOO_MOVES[S.roundtype]
	if move and move.init then
		move.init(S, S.boos)
	end
end

local function boo_startanimation(b)
	boo_stop(b)
	local t = math.random(3)
	if t == 1 then
		playsound(mushroomappearsound)
		b.anim = {type = "fade", t = 0}
	elseif t == 2 then
		playsound(bowserfallsound)
		b.anim = {type = "fall", t = 0, dir = randomsign(), speedy = 0}
	else
		playsound(stompbigsound)
		makepoof(b.x+0.5, b.y+1, "poof")
		b.anim = {type = "poof", poof = poofs[#poofs]}
		b.hidden = true
	end
end

local function boo_updateanimation(b, dt)
	local a = b.anim
	if a.done then
		return
	end
	if a.type == "fade" then
		a.t = a.t + dt
		local p = math.min(1, a.t/BOO_FADE_TIME)
		b.scale = 1 + p*1.5
		b.alpha = 255*(1-p)
		if b.alpha <= 0 then
			a.done = true
		end
	elseif a.type == "fall" then
		a.t = a.t + dt
		b.rot = a.dir*math.pi*motion_curve(math.min(1, a.t/BOO_ROTATE_TIME), "sine", true, true, true, true)
		a.speedy = a.speedy + minigamegravity*dt
		b.y = b.y + a.speedy*dt
		--off the bottom of the screen and the fall sound has finished
		if b.y > height and not bowserfallsound:isPlaying() then
			a.done = true
		end
	elseif a.type == "poof" then
		if not (a.poof and tablefind(poofs, a.poof)) then
			a.done = true
		end
	end
end

local function boo_updateboos(S, dt)
	local mdt = dt*(S.speedmul or 1) --movement gets faster every round
	S.movetime = (S.movetime or 0) + mdt
	local move = BOO_MOVES[S.roundtype]
	if move and move.groupupdate then
		move.groupupdate(S, mdt)
	end
	for _, b in ipairs(S.boos) do
		b.frametimer = (b.frametimer + dt) % (BOO_ANIM_TIME*2)
		if b.cross then
			b.cross = b.cross - dt
			if b.cross <= 0 then
				b.cross = nil
			end
		end
		if b.anim then
			boo_updateanimation(b, dt)
		elseif not b.stopped then
			local m = BOO_MOVES[b.mode]
			local oldx = b.x
			if m and m.update then
				m.update(S, b, mdt)
			end
			--look where it's going
			if b.x > oldx + 0.001 then
				b.facing = -1
			elseif b.x < oldx - 0.001 then
				b.facing = 1
			end
		end
	end
end

addminigame({
	id = "boo_baffler_bash",
	savename = "Boo Baffler Bash",
	endless = true, --no win condition, see victoryscore
	name = "boo baffler bash",
	description = "find the boo shown at the top of the screen and click it before the timer runs out! the faster you find it, the more time you win back. the boos get a little faster every round, and every round they move in a new way:\n\nshy: boos close to your mouse get shy. they stop and turn see-through. boos far away sneak towards your mouse.\ncircle: boos fly around in circles, like a merry-go-round. some circles spin one way and some spin the other way.\nchain: boos follow each other in a long line, like a train, and wiggle all over the screen.\nwave: boos float sideways and bob up and down, like boats on the sea. when they leave one side, they come back on the other side.\nlanes: boos slide in rows, like cars on a road. each row goes the opposite way to the row next to it.\nspiral: boos spin around the middle of the screen. they move out to the edges, then back to the middle.\nflock: boos fly together in groups, like a school of fish. the groups join up and split apart.\nshuffle: boos stay still for a moment. then they all zoom and swap places! keep your eyes on yours!\nteleport: boos vanish in a puff of smoke and pop up somewhere else.\nflee: boos run away from your mouse. trap one against a wall to catch it!\nphase: boos fade away until they are almost invisible, then come back, like real ghosts.\nswing: boos hang on strings and swing back and forth, like a swing at the park.\nsuper random: every boo does its own crazy thing, like zooming, spinning, shaking or hiding, and switches to something new every few seconds!",
	tagline = "find the boo before time runs out!", --short description on the menu graphic
	usesplayer = false,

	createmap = function(S)
		backgroundrgbon = true
		backgroundrgb = {28, 20, 44}
		S.round = 1
		S.timer = BOO_START_TIME
		boo_newround(S)
	end,

	update = function(S, dt)
		boo_updateboos(S, dt)
		if S.phase == "play" then
			S.roundtime = S.roundtime + dt
			local old = S.timer
			S.timer = math.max(0, S.timer - dt)
			if math.ceil(S.timer) < math.ceil(old) then
				playsound(beepsound)
			end
			if S.timer <= 0 then
				S.phase = "timeout"
				for _, b in ipairs(S.boos) do
					boo_startanimation(b)
				end
			end
		elseif S.phase == "caught" then
			--the timer doesn't tick down here
			local q = S.seq
			if q.stage == "wait1" then
				q.t = q.t - dt
				if q.t <= 0 then
					if q.left > 0 then
						q.stage = "increment"
						q.t = 0
						playsound(scoreringsound)
					else
						q.stage = "wait2"
						q.t = BOO_WAIT
					end
				end
			elseif q.stage == "increment" then
				q.t = q.t + dt
				while q.t >= BOO_INCREMENT_INTERVAL and q.left > 0 do
					q.t = q.t - BOO_INCREMENT_INTERVAL
					S.timer = S.timer + 1
					q.left = q.left - 1
				end
				if q.left <= 0 then
					scoreringsound:stop()
					q.stage = "wait2"
					q.t = BOO_WAIT
				end
			elseif q.stage == "wait2" then
				q.t = q.t - dt
				if q.t <= 0 then
					q.stage = "animation"
					boo_startanimation(q.boo)
				end
			elseif q.stage == "animation" then
				if q.boo.anim and q.boo.anim.done then
					S.round = S.round + 1
					boo_newround(S)
				end
			end
		elseif S.phase == "timeout" then
			local done = true
			for _, b in ipairs(S.boos) do
				if not (b.anim and b.anim.done) then
					done = false
					break
				end
			end
			if done then
				S.phase = "over"
				minigame_finish("lose")
			end
		end
	end,

	mousepressed = function(S, x, y, button)
		if button ~= "l" or S.phase ~= "play" then
			return
		end
		local mx, my = x/16, y/16
		for i = #S.boos, 1, -1 do --topmost first
			local b = S.boos[i]
			local bx, by = boo_position(b)
			if mx >= bx and mx < bx+1 and my >= by and my < by+1 then
				if b.istarget then
					playsound(coinsound)
					boo_stop(b)
					S.score = S.score + 1
					local bonus = boo_bonus(S.roundtime)
					S.phase = "caught"
					S.seq = {stage = "wait1", t = BOO_WAIT, left = bonus, boo = b}
					S.bonustime = S.roundtime --the bonus meter stops where it was
					--every other boo disappears in a poof
					for _, other in ipairs(S.boos) do
						if other ~= b and not other.hidden then
							local ox, oy = boo_position(other)
							makepoof(ox+0.5, oy+1, "poof")
						end
					end
					S.boos = {b}
					if bonus > 0 then
						minigame_popup("+" .. bonus, (b.x+0.5)*16, b.y*16-4, boo_bonuscolour(S.roundtime))
					end
				else
					playsound(blockhitsound)
					b.cross = BOO_CROSS_TIME
				end
				return
			end
		end
	end,

	drawworld = function(S)
		if S.roundtype == "swing" and S.phase == "play" and S.pendulums then
			--faint strings
			love.graphics.setColor(255, 255, 255, 35)
			love.graphics.setLineWidth(scale)
			for _, pd in ipairs(S.pendulums) do
				local a = pd.amp*math.sin(pd.omega*S.movetime + pd.phase)
				love.graphics.line(pd.x*16*scale, pd.y*16*scale, (pd.x + pd.length*math.sin(a))*16*scale, (pd.y + pd.length*math.cos(a))*16*scale)
			end
			love.graphics.setLineWidth(1)
		end
		for _, b in ipairs(S.boos) do
			if not b.hidden then
				local img, quad, color = boo_graphic(b.variant, boo_frame(b))
				local bx, by = boo_position(b)
				love.graphics.setColor(color[1], color[2], color[3], b.alpha)
				love.graphics.draw(img, quad, (bx*16+8)*scale, (by*16+8)*scale, b.rot, b.scale*b.facing*scale, b.scale*scale, 8, 8)
				if b.cross then
					--red wrong cross
					love.graphics.setColor(255, 30, 30, 255*(b.cross/BOO_CROSS_TIME))
					love.graphics.setLineWidth(2*scale)
					love.graphics.line((bx*16+2)*scale, (by*16+2)*scale, (bx*16+14)*scale, (by*16+14)*scale)
					love.graphics.line((bx*16+14)*scale, (by*16+2)*scale, (bx*16+2)*scale, (by*16+14)*scale)
					love.graphics.setLineWidth(1)
				end
			end
		end
	end,

	drawoverlay = function(S)
		local cx = width*8

		--bonus meter (one segment per second of bonus, the current one drains) with the bonus display on its right
		--the meter and the display are one group, centered on the screen
		local roundtime = S.bonustime or S.roundtime or 0
		if S.phase == "timeout" or S.phase == "over" then
			roundtime = BOO_BONUS_STEP*BOO_BONUS_MAX
		end
		local bonus = boo_bonus(roundtime)
		local text = "+" .. bonus
		local gap = 4
		local groupw = BOO_METER_W + gap + textwidth(text)
		local mx = math.floor(cx - groupw/2)
		local segw = BOO_METER_W/BOO_BONUS_MAX
		love.graphics.setColor(255, 255, 255)
		love.graphics.rectangle("fill", (mx-1)*scale, (BOO_METER_Y-1)*scale, (BOO_METER_W+2)*scale, (BOO_METER_H+2)*scale)
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", mx*scale, BOO_METER_Y*scale, BOO_METER_W*scale, BOO_METER_H*scale)
		local fill = boo_bonusfill(roundtime)
		local bonuscolour = boo_bonuscolour(roundtime)
		love.graphics.setColor(bonuscolour)
		love.graphics.rectangle("fill", mx*scale, BOO_METER_Y*scale, fill*segw*scale, BOO_METER_H*scale)
		love.graphics.setColor(0, 0, 0)
		for i = 1, BOO_BONUS_MAX-1 do
			love.graphics.rectangle("fill", (mx+i*segw)*scale, BOO_METER_Y*scale, scale, BOO_METER_H*scale)
		end
		shadowprint(text, mx + BOO_METER_W + gap, BOO_METER_Y + BOO_METER_H/2 - 4, bonuscolour)

		if S.phase == "timeout" or S.phase == "over" then
			centerprintline(T("time up!"), cx, 100)
		end
	end,

	drawhud = function(S)
		--one rectangle centered on the screen: score and round on the left, the boo to find in the middle, the time on the right
		local cx = width*8
		local scoretext = "Score: " .. formatscore(S.score)
		local roundtext = "Round " .. S.round
		local timetext = tostring(math.ceil(S.timer))
		local clockw, clockgap = 10, 2
		local side = math.max(textwidth(scoretext), textwidth(roundtext), clockw + clockgap + textwidth(timetext))
		local pad, gap = 5, 6
		local boxw = 30
		local w = boxw + 2*(gap + side + pad)
		local x = cx - w/2
		local top, h = 3, 30
		--the rectangle is half transparent (the border is a line so it doesn't show through the fill)
		love.graphics.setColor(0, 0, 0, 128)
		love.graphics.rectangle("fill", (x+1)*scale, (top+1)*scale, (w-2)*scale, (h-2)*scale, 3*scale)
		local linewidth = love.graphics.getLineWidth()
		love.graphics.setLineWidth(scale)
		love.graphics.setColor(255, 255, 255, 128)
		love.graphics.rectangle("line", (x+0.5)*scale, (top+0.5)*scale, (w-1)*scale, (h-1)*scale, 3.5*scale)
		love.graphics.setLineWidth(linewidth)
		local img, quad, color = boo_graphic(S.target, math.floor((S.time % (BOO_ANIM_TIME*2))/BOO_ANIM_TIME)+1)
		love.graphics.setColor(color)
		love.graphics.draw(img, quad, cx*scale, (top+h/2)*scale, 0, scale, scale, 8, 8)
		--left: score and round (right-aligned against the boo)
		local lx = cx - boxw/2 - gap
		shadowprint(scoretext, lx - textwidth(scoretext), top+5)
		shadowprint(roundtext, lx - textwidth(roundtext), top+17)
		--right: clock and time
		local rx = cx + boxw/2 + gap
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(hudclockimg, hudclockquad[hudoutline], rx*scale, (top+h/2-5)*scale, 0, scale, scale)
		shadowprint(timetext, rx + clockw + clockgap, top+h/2-4)
	end,
})

------------------------------
--  SNAKE SLITHER SCRAMBLE  --
------------------------------

local SNAKE_SPEED = 7 --tiles per second
local SNAKE_SLOW_SPEED = snakeblockspeed --slow mode: a normal speed snake block (green graphic)
local SNAKE_WALL_TILE = 78
local SNAKE_SECRET_POINTS = {2, 3, 5, 10}
local SNAKE_STAR_MIN, SNAKE_STAR_MAX = 15, 25 --seconds before a star appears (the ? block takes 5 to 10)
local SNAKE_STAR_COLORS = {{255, 255, 255}, {255, 170, 120}, {150, 255, 150}, {255, 255, 120}}
local SNAKE_DIRS = {up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0}}
local SNAKE_OPPOSITE = {up = "down", down = "up", left = "right", right = "left"}

local function snake_wrap(S, x, y)
	--with a star the snake can pass through the walls too, so it always wraps around the screen
	return x % S.cols, y % S.rows
end

local function snake_iswall(S, x, y)
	return S.walls and (x <= 0 or y <= 0 or x >= S.cols-1 or y >= S.rows-1)
end

local function snake_onsnake(S, x, y, ignoretail)
	local last = #S.segs
	if ignoretail then
		last = last - 1
	end
	for i = 1, last do
		if S.segs[i][1] == x and S.segs[i][2] == y then
			return true
		end
	end
	return false
end

local function snake_freecell(S)
	local free = {}
	for x = 0, S.cols-1 do
		for y = 0, S.rows-1 do
			if not snake_iswall(S, x, y) and not snake_onsnake(S, x, y)
				and not (S.mushroom and S.mushroom[1] == x and S.mushroom[2] == y)
				and not (S.secret and S.secret[1] == x and S.secret[2] == y)
				and not (S.star and S.star[1] == x and S.star[2] == y) then
				table.insert(free, {x, y})
			end
		end
	end
	if #free == 0 then
		return nil
	end
	return free[math.random(#free)]
end

--how many of the empty (non-wall) tiles the snake covers; with a star it can overlap itself and sit in walls
local function snake_coverage(S)
	local seen, count = {}, 0
	for _, seg in ipairs(S.segs) do
		local key = seg[1] .. "|" .. seg[2]
		if not seen[key] and not snake_iswall(S, seg[1], seg[2]) then
			seen[key] = true
			count = count + 1
		end
	end
	return count
end

local function snake_starstart(S)
	S.starleft = mariostarduration
	S.ghost = true --no loss until the head is on a blank tile after the star wears off
	playsound(mushroomeatsound)
	if not NoMusic then
		stopmusic()
		music:play("starmusic")
	end
end

local function snake_starend(S)
	S.starleft = 0
	music:stop("starmusic")
	playmusic()
end

local function snake_arrive(S)
	--the head is on a tile: move the body, eat, turn and check what's ahead
	local hx, hy = snake_wrap(S, round(S.px), round(S.py))
	S.px, S.py = hx, hy
	table.insert(S.segs, 1, {hx, hy})
	if not S.growing then
		table.remove(S.segs)
	end
	S.growing = false

	if S.mushroom and S.mushroom[1] == hx and S.mushroom[2] == hy then
		S.score = S.score + 1
		S.growing = true
		S.mushroom = nil
		playsound(coinsound)
		minigame_popup("+1", hx*16+8, hy*16)
	end
	if S.secret and S.secret[1] == hx and S.secret[2] == hy then
		local points = randomitem(SNAKE_SECRET_POINTS)
		S.score = S.score + points
		S.growing = true
		S.secret = nil
		S.secrettimer = rnd(5, 10)
		playsound(mushroomeatsound)
		minigame_popup("+" .. points, hx*16+8, hy*16, {255, 230, 80})
	end

	if S.star and S.star[1] == hx and S.star[2] == hy then
		S.star = nil
		S.startimer = rnd(SNAKE_STAR_MIN, SNAKE_STAR_MAX)
		snake_starstart(S)
	end

	--the star wore off: losing only becomes possible again once the head is on a blank tile
	if S.ghost and S.starleft <= 0 then
		local blank = not snake_iswall(S, hx, hy)
		for i = 2, #S.segs do
			if S.segs[i][1] == hx and S.segs[i][2] == hy then
				blank = false
				break
			end
		end
		if blank then
			S.ghost = false
		end
	end

	--covered the entire grid
	if snake_coverage(S) >= S.totalcells then
		S.won = true
		S.speedx, S.speedy = 0, 0
		minigame_finish("win", 3, true)
		return false
	end

	if not S.mushroom then
		S.mushroom = snake_freecell(S)
	end

	--take the next turn from the queue
	if #S.queue > 0 then
		local nextdir = table.remove(S.queue, 1)
		if nextdir ~= SNAKE_OPPOSITE[S.dir] then
			S.dir = nextdir
		end
	end
	local d = SNAKE_DIRS[S.dir]
	S.speedx, S.speedy = d[1]*S.speed, d[2]*S.speed

	local nx, ny = snake_wrap(S, hx+d[1], hy+d[2])
	if (not S.ghost) and (snake_iswall(S, nx, ny) or snake_onsnake(S, nx, ny, not S.growing)) then
		--hit something: bump into it like a hit block, then the game stops
		S.dead = true
		S.speedx, S.speedy = 0, 0
		S.bump = {t = 0}
		playsound(blockhitsound)
		return false
	end
	return true
end

local function snake_drawblock(S, img, quad, x, y)
	local xs, ys = {x}, {y}
	--blocks sliding off one edge also show on the other (walls can be passed with a star)
	if x > S.cols-1 then xs[2] = x-S.cols elseif x < 0 then xs[2] = x+S.cols end
	if y > S.rows-1 then ys[2] = y-S.rows elseif y < 0 then ys[2] = y+S.rows end
	for _, dx in ipairs(xs) do
		for _, dy in ipairs(ys) do
			love.graphics.draw(img, quad, math.floor(dx*16*scale), math.floor(dy*16*scale), 0, scale, scale)
		end
	end
end

--titles from 100 points up to the number of empty tiles (the highest possible score), evenly spread
local SNAKE_TITLE_MIN = victoryscore
local SNAKE_TITLES = {"snake title 1", "snake title 2", "snake title 3", "snake title 4", "snake title 5"}

local function snake_title(S, score)
	local maxscore = math.max(SNAKE_TITLE_MIN, S.emptytiles or SNAKE_TITLE_MIN)
	if score < SNAKE_TITLE_MIN then
		return nil
	end
	if score >= maxscore then
		return SNAKE_TITLES[#SNAKE_TITLES]
	end
	local p = (score - SNAKE_TITLE_MIN)/(maxscore - SNAKE_TITLE_MIN)
	return SNAKE_TITLES[math.min(#SNAKE_TITLES-1, math.floor(p*(#SNAKE_TITLES-1))+1)]
end

local SNAKE_KEYS = {up = function() return upkey(1) end, down = function() return downkey(1) end,
	left = function() return leftkey(1) end, right = function() return rightkey(1) end}

addminigame({
	id = "snake_slither_scramble",
	savename = "Snake Slither Scramble",
	scorevictory = true, --has its own win, but a loss above victoryscore is a victory too
	name = "snake slither scramble",
	description = "steer the snake block with your movement keys and gobble up mushrooms to grow longer. hidden ? blocks are worth 2 to 10 points. don't bite yourself, and fill the whole screen to win!",
	tagline = "gobble mushrooms and fill the screen!",
	usesplayer = false,
	options = {
		{type = "checkbox", key = "walls", label = "wall mode", default = false},
		{type = "checkbox", key = "fast", label = "fast mode", default = true},
	},
	title = snake_title,

	drawhud = function(S)
		drawscorehud(S)
		if S.starleft and S.starleft > 0 then
			centerprintline("Remaining Invincibility Time: " .. math.ceil(S.starleft), width*8, 18, {255, 230, 80})
		end
	end,

	createmap = function(S, opts)
		backgroundrgbon = true
		backgroundrgb = {16, 40, 32}
		S.walls = opts.walls
		S.cols, S.rows = width, height
		if S.walls then
			S.totalcells = (S.cols-2)*(S.rows-2)
		else
			S.totalcells = S.cols*S.rows
		end
		local hx, hy = math.floor(S.cols/2), math.floor(S.rows/2)
		S.segs = {{hx, hy}, {hx-1, hy}, {hx-2, hy}}
		S.emptytiles = S.totalcells - #S.segs --the highest possible score
		S.dir = "right"
		S.px, S.py = hx, hy
		S.speed = opts.fast and SNAKE_SPEED or SNAKE_SLOW_SPEED
		S.speedx, S.speedy = S.speed, 0
		S.growing = false
		S.quadi = (S.speed > snakeblockspeed) and 3 or 1 --snake block graphic logic (green when slow, blue when fast)
		S.keyheld = {}
		S.queue = {}
		S.mushroom = snake_freecell(S)
		S.secret = nil
		S.secrettimer = rnd(5, 10)
		S.star = nil
		S.startimer = rnd(SNAKE_STAR_MIN, SNAKE_STAR_MAX)
		S.starleft = 0
		S.ghost = false
	end,

	postload = function(S)
		for name, fn in pairs(SNAKE_KEYS) do
			S.keyheld[name] = fn()
		end
	end,

	update = function(S, dt)
		if S.bump and not S.bump.done then
			S.bump.t = S.bump.t + dt
			if S.bump.t >= blockbouncetime then
				--back where it was before the hit: stop the audio and the game for 1 second
				S.bump.done = true
				S.bump.t = blockbouncetime
				minigame_finish("lose", 1, true)
			end
			return
		end
		if S.dead or S.won then
			return
		end
		--player 1's up, down, left and right; the turn happens once the head is on a tile
		--presses are queued (up to 2), and a press that is the same as or opposite to the turn before it is ignored
		for name, fn in pairs(SNAKE_KEYS) do
			local down = fn()
			if down and not S.keyheld[name] then
				local last = S.queue[#S.queue] or S.dir
				if name ~= last and name ~= SNAKE_OPPOSITE[last] and #S.queue < 2 then
					table.insert(S.queue, name)
				end
			end
			S.keyheld[name] = down
		end

		--star: invincibility for mariostarduration seconds
		if S.starleft > 0 then
			S.starleft = S.starleft - dt
			if S.starleft <= 0 then
				snake_starend(S)
			end
		elseif not S.star then
			S.startimer = S.startimer - dt
			if S.startimer <= 0 then
				S.star = snake_freecell(S)
				if not S.star then
					S.startimer = 1
				end
			end
		end

		if not S.secret then
			S.secrettimer = S.secrettimer - dt
			if S.secrettimer <= 0 then
				S.secret = snake_freecell(S)
				if not S.secret then
					S.secrettimer = 1
				end
			end
		end

		local step = dt
		local guard = 0
		while step > 0 and guard < 8 do
			guard = guard + 1
			local ox, oy = S.px, S.py
			local nx, ny = ox + S.speedx*step, oy + S.speedy*step
			local cross
			if S.speedx > 0 and math.floor(nx) > math.floor(ox) then
				cross = math.floor(nx)
			elseif S.speedx < 0 and math.ceil(nx) < math.ceil(ox) then
				cross = math.ceil(nx)
			elseif S.speedy > 0 and math.floor(ny) > math.floor(oy) then
				cross = math.floor(ny)
			elseif S.speedy < 0 and math.ceil(ny) < math.ceil(oy) then
				cross = math.ceil(ny)
			end
			if cross then
				if S.speedx ~= 0 then
					step = step - math.abs(cross-ox)/S.speed
					S.px = cross
				else
					step = step - math.abs(cross-oy)/S.speed
					S.py = cross
				end
				if not snake_arrive(S) then
					break
				end
			else
				S.px, S.py = nx, ny
				step = 0
			end
		end
	end,

	drawworld = function(S)
		love.graphics.setColor(255, 255, 255)
		if S.walls then
			for x = 0, S.cols-1 do
				for y = 0, S.rows-1 do
					if snake_iswall(S, x, y) then
						drawtilegraphic(SNAKE_WALL_TILE, x*16, y*16)
					end
				end
			end
		end
		if S.mushroom then
			love.graphics.draw(itemsimg, itemsquad[spriteset][1], S.mushroom[1]*16*scale, S.mushroom[2]*16*scale, 0, scale, scale)
		end
		if S.secret then
			love.graphics.draw(coinblockimage, coinblockquads[spriteset][coinframe or 1], S.secret[1]*16*scale, S.secret[2]*16*scale, 0, scale, scale)
		end
		if S.star then
			love.graphics.draw(starimg, starquad[spriteset][math.floor(S.time*10)%4+1], S.star[1]*16*scale, S.star[2]*16*scale, 0, scale, scale)
		end
		--starred snake flashes like a starred player (slower in the last second)
		if S.starleft > 0 then
			local rate = (S.starleft < mariostarrunout) and mariostarblinkrateslow or mariostarblinkrate
			love.graphics.setColor(SNAKE_STAR_COLORS[math.floor(S.time/rate)%#SNAKE_STAR_COLORS+1])
		end

		--snake block style: the body sits on tiles, the front and back blocks slide
		local img, quad = snakeblockimg, starquad[spriteset][S.quadi]
		local segs = S.segs
		local head = segs[1]
		local progress = math.abs(S.px-head[1]) + math.abs(S.py-head[2])
		if progress > 1 then
			progress = 0
		end
		local fixed = #segs-1
		if S.growing or #segs < 2 then
			fixed = #segs
		end
		for i = 1, fixed do
			snake_drawblock(S, img, quad, segs[i][1], segs[i][2])
		end
		if (not S.growing) and #segs >= 2 then
			local tail, prev = segs[#segs], segs[#segs-1]
			local dx, dy = prev[1]-tail[1], prev[2]-tail[2]
			if dx > 1 then dx = dx-S.cols elseif dx < -1 then dx = dx+S.cols end
			if dy > 1 then dy = dy-S.rows elseif dy < -1 then dy = dy+S.rows end
			snake_drawblock(S, img, quad, tail[1]+dx*progress, tail[2]+dy*progress)
		end
		local d = SNAKE_DIRS[S.dir]
		local headprogress = progress
		if S.bump then
			--same motion as a bumped block: out to blockbounceheight at half the time, then back
			local t = S.bump.t
			if t < blockbouncetime/2 then
				headprogress = t/(blockbouncetime/2)*blockbounceheight
			else
				headprogress = (2 - t/(blockbouncetime/2))*blockbounceheight
			end
		end
		snake_drawblock(S, img, quad, head[1]+d[1]*headprogress, head[2]+d[2]*headprogress)
		love.graphics.setColor(255, 255, 255)
	end,
})

-------------------------------
--  JUMPING JUGGLE JAMBOREE  --
-------------------------------

local JJJ_WIND_SPEED = 4
local JJJ_WIND_RAMP = 1 --sine in-out start and stop of the wind
local JJJ_WARNING_TIME = 3
local JJJ_BLINK = 0.5
local JJJ_BLOCK_TILE = 78
local JJJ_GROUND_TILE = 2
local JJJ_BLOCK_ROW = 9
local JJJ_GROUND_Y = 13 --top of the ground
local JJJ_ENEMIES = {"goomba", "goombrat", "paragoomba", "biggoomba", "splunkin", "drygoomba", "fighterfly", "mole", "spike"}
local JJJ_WINDMODES = {"none", "occasional", "continuous"}

--decoration generator: the same shapes the SMB levels use (rows listed top to bottom, false = empty)
local JJJ_DECOR = {
	smallhill = {{false, 3, false}, {24, 25, 26}},
	bighill = {{false, false, 3, false, false}, {false, 24, 25, 26, false}, {24, 25, 27, 28, 26}},
	smalltree = {{87}, {88}},
	tree = {{44}, {66}, {88}},
}

local function jjj_place(shape, x, bottomy)
	--x is the left column, bottomy the row the shape stands on
	for r = 1, #shape do
		local y = bottomy - (#shape - r)
		for c = 1, #shape[r] do
			local id = shape[r][c]
			if id and map[x+c-1] and map[x+c-1][y] then
				map[x+c-1][y][1] = id
			end
		end
	end
end

local function jjj_generatedecor(groundrow)
	--things on the ground, left to right with gaps in between
	local x = math.random(1, 2)
	while x <= mapwidth do
		local kind = randomitem({"smallhill", "bighill", "bush", "fence", "smalltree", "tree"})
		local w
		if kind == "bush" then
			local middle = math.random(1, 3)
			w = middle + 2
			if x + w - 1 <= mapwidth then
				local row = {4}
				for i = 1, middle do row[#row+1] = 5 end
				row[#row+1] = 6
				jjj_place({row}, x, groundrow)
			end
		elseif kind == "fence" then
			w = math.random(1, 4)
			if x + w - 1 <= mapwidth then
				local row = {}
				for i = 1, w do row[i] = 86 end
				jjj_place({row}, x, groundrow)
			end
		else
			w = #JJJ_DECOR[kind][#JJJ_DECOR[kind]]
			if x + w - 1 <= mapwidth then
				jjj_place(JJJ_DECOR[kind], x, groundrow)
			end
		end
		x = x + w + math.random(1, 3)
	end

	--clouds in the sky
	local cx = math.random(1, 4)
	while cx <= mapwidth do
		local middle = math.random(1, 3)
		local w = middle + 2
		if cx + w - 1 <= mapwidth then
			local top, bottom = {33}, {55}
			for i = 1, middle do
				top[#top+1] = 34
				bottom[#bottom+1] = 56
			end
			top[#top+1] = 35
			bottom[#bottom+1] = 57
			jjj_place({top, bottom}, cx, math.random(4, 7))
		end
		cx = cx + w + math.random(2, 6)
	end
end

local function jjj_dirname(dir)
	return (dir > 0) and T("wind right") or T("wind left")
end

local function jjj_windramp(W, target)
	W.from = W.current
	W.to = target
	W.rampt = 0
end

local function jjj_windmessage(W, text)
	W.message = text
	W.messaget = 0
end

local function jjj_windinit(W)
	W.current = 0
	W.dir = randomsign()
	if W.mode == "occasional" then
		W.stage = "wait"
		W.timer = rnd(10, 15) - JJJ_WARNING_TIME
	elseif W.mode == "continuous" then
		jjj_windramp(W, W.dir*JJJ_WIND_SPEED)
		W.stage = "wait"
		W.timer = rnd(10, 15) - JJJ_WARNING_TIME
	end
end

local function jjj_windupdate(W, dt)
	if W.rampt then
		W.rampt = W.rampt + dt
		local p = math.min(1, W.rampt/JJJ_WIND_RAMP)
		W.current = lerp(W.from, W.to, motion_curve(p, "sine", true, true, true, true))
		if p >= 1 then
			W.current = W.to
			W.rampt = nil
		end
	end
	if W.message then
		W.messaget = W.messaget + dt
		if W.messaget >= JJJ_WARNING_TIME then
			W.message = nil
		end
	end

	if W.mode == "occasional" then
		if W.stage == "wait" then
			W.timer = W.timer - dt
			if W.timer <= 0 then
				W.duration = rnd(10, 15)
				jjj_windmessage(W, string.format(T("the wind will blow %s for %s seconds!"), jjj_dirname(W.dir), string.format("%.1f", W.duration)))
				W.stage = "warnstart"
				W.timer = JJJ_WARNING_TIME
			end
		elseif W.stage == "warnstart" then
			W.timer = W.timer - dt
			if W.timer <= 0 then
				jjj_windramp(W, W.dir*JJJ_WIND_SPEED)
				W.stage = "blowing"
				W.timer = W.duration
				W.warnedstop = false
			end
		elseif W.stage == "blowing" then
			W.timer = W.timer - dt
			if W.timer <= JJJ_WARNING_TIME and not W.warnedstop then
				W.warnedstop = true
				jjj_windmessage(W, T("the wind is about to stop!"))
			end
			if W.timer <= 0 then
				jjj_windramp(W, 0)
				W.dir = -W.dir --reverse instead of randomising
				W.stage = "wait"
				W.timer = rnd(10, 15) - JJJ_WARNING_TIME
			end
		end
	elseif W.mode == "continuous" then
		if W.stage == "wait" then
			W.timer = W.timer - dt
			if W.timer <= 0 then
				W.nextdir = -W.dir
				jjj_windmessage(W, string.format(T("the wind is about to blow %s!"), jjj_dirname(W.nextdir)))
				W.stage = "warn"
				W.timer = JJJ_WARNING_TIME
			end
		elseif W.stage == "warn" then
			W.timer = W.timer - dt
			if W.timer <= 0 then
				W.dir = W.nextdir
				jjj_windramp(W, W.dir*JJJ_WIND_SPEED)
				W.stage = "wait"
				W.timer = rnd(10, 15) - JJJ_WARNING_TIME
			end
		end
	end
end

local function jjj_windpush(o, dist)
	if (not o) or o.static or o.active == false or o.shot then
		return
	end
	if not checkintile(o.x+dist, o.y, o.width, o.height, tileentitieswind, o, "ignorehorplatforms") then
		o.x = o.x + dist
	end
end

--turn an enemy around (speed and sprite)
local function jjj_turn(o)
	o.speedx = -o.speedx
	if o.animationdirection == "left" then
		o.animationdirection = "right"
	elseif o.animationdirection == "right" then
		o.animationdirection = "left"
	end
end

--a random enemy from the list, standing on the ground in column x
local function jjj_newenemy(S, x)
	local t = randomitem(JJJ_ENEMIES)
	local r
	if t == "mole" then
		r = {1, nil, "false"} --walking monty mole, not one hiding in the ground
	end
	local obj = spawnenemy(t, x, JJJ_GROUND_Y, r)
	if obj and t == "spike" and not S.spikeballs then
		obj.spittimer = math.huge
	end
	return obj
end

--enemies already on the screen when the map loads
local function jjj_spawnstartenemies(S)
	local columns = {}
	for x = 1, mapwidth do
		columns[x] = x
	end
	for i = #columns, 2, -1 do
		local j = math.random(i)
		columns[i], columns[j] = columns[j], columns[i]
	end
	local count = math.random(3, 5)
	local used = {}
	for _, x in ipairs(columns) do
		if count <= 0 then
			break
		end
		if not used[x-1] and not used[x] and not used[x+1] then
			local obj = jjj_newenemy(S, x)
			if obj then
				used[x] = true
				count = count - 1
				if math.random(2) == 1 then
					jjj_turn(obj)
				end
				table.insert(S.enemies, {obj = obj, side = (obj.speedx > 0) and "left" or "right", spawny = obj.y, entered = true})
			end
		end
	end
end

local function jjj_spawnenemy(S)
	local side = (math.random(2) == 1) and "left" or "right"
	local obj = jjj_newenemy(S, (side == "left") and 1 or mapwidth)
	if not obj then
		return
	end
	if side == "left" then
		obj.x = -obj.width --rightx = 0
	else
		obj.x = mapwidth --x = game width
	end
	--no gravity until it is on the screen (there is no ground outside of it)
	local e = {obj = obj, side = side, spawny = obj.y, pending = true, entered = false, oldignoregravity = obj.ignoregravity}
	obj.ignoregravity = true
	table.insert(S.enemies, e)
end

addminigame({
	id = "jumping_juggle_jamboree",
	savename = "Jumping Juggle Jamboree",
	name = "jumping juggle jamboree",
	description = "you only get one jump! leap off the blocks and keep bouncing on the enemies that walk in from the sides. touching the ground ends the game, so watch out for the wind!",
	tagline = "one jump, endless bouncing!",
	usesplayer = true,
	holdjump = true,
	lockcontrols = function(S) return not S.jumped end, --stuck on the blocks: nothing but jump works
	drawhud = drawscorehud,
	options = {
		{type = "checkbox", key = "spikeballs", label = "can spike spawn spikeballs?", default = false},
		{type = "checkbox", key = "fastfall", label = "fast falling", default = false},
		{type = "dropdown", key = "windmode", label = "wind mode:", entries = JJJ_WINDMODES, default = 1},
	},

	createmap = function(S, opts)
		for x = 1, mapwidth do
			for y = JJJ_GROUND_Y+1, mapheight do
				map[x][y][1] = JJJ_GROUND_TILE
			end
		end
		jjj_generatedecor(JJJ_GROUND_Y) --decor stands on the row above the ground
		local cx = math.ceil(mapwidth/2)
		S.blocks = {cx-1, cx, cx+1}
		for _, x in ipairs(S.blocks) do
			map[x][JJJ_BLOCK_ROW][1] = JJJ_BLOCK_TILE
		end
		startx = cx-0.5
		starty = JJJ_BLOCK_ROW-1
		portalgun = false
		if opts.fastfall then
			--fast falling: mari0-maker physics instead of mario maker
			currentphysics = 5
			setphysics(currentphysics)
		end
		S.spikeballs = (opts.spikeballs ~= false)
		S.enemies = {}
		S.spawntimer = 0.5
		S.wind = {mode = JJJ_WINDMODES[opts.windmode or 1] or "none"}
		jjj_windinit(S.wind)
	end,

	postload = function(S)
		--enemies come in from outside the screen
		objects["screenboundary"] = {}
		local p = objects["player"][1]
		if p then
			p.portalgun = false
			p.minigamenowalkcap = true --always able to reach maxrunspeed
			S.pinx = p.x
		end
		jjj_spawnstartenemies(S)
	end,

	update = function(S, dt)
		local p = objects["player"][1]
		if not p then
			return
		end

		if not S.jumped then
			if p.jumping or p.speedy < -0.5 then
				--remove the blocks once the player jumps off
				S.jumped = true
				for _, x in ipairs(S.blocks) do
					map[x][JJJ_BLOCK_ROW][1] = 1
					objects["tile"][tilemap(x, JJJ_BLOCK_ROW)] = nil
					makepoof(x-0.5, JJJ_BLOCK_ROW-0.5, "makerpoof")
				end
				generatespritebatch()
			else
				--static on the blocks until it jumps
				p.x = S.pinx or p.x
				p.speedx = 0
			end
		end

		--run is held too, but only for the movement (mario:movement), so custom character run animations aren't triggered
		p.minigameforcerun = S.jumped and not p.dead and not S.finish

		if S.jumped and not p.dead then
			if p.x < 0 then
				p.x = 0
				p.speedx = math.max(0, p.speedx)
			elseif p.x+p.width > mapwidth then
				p.x = mapwidth-p.width
				p.speedx = math.min(0, p.speedx)
			end
			--landed on the ground
			if not p.falling and not p.jumping and p.y+p.height >= JJJ_GROUND_Y-1/16 then
				p:die("killscript")
				return
			end
		end

		--wind (game.lua pushes the player and makes the leaves, the enemies are pushed here)
		jjj_windupdate(S.wind, dt)
		windentityspeed = S.wind.current
		windstarted = math.abs(S.wind.current) > 0.05
		local dist = S.wind.current*dt

		for i = #S.enemies, 1, -1 do
			local e = S.enemies[i]
			local o = e.obj
			if o.delete or o.instantdelete then
				table.remove(S.enemies, i)
			else
				if e.pending then
					--first update after initialisation
					e.pending = false
					if (e.side == "left" and o.speedx < 0) or (e.side == "right" and o.speedx > 0) then
						--turns the sprite around with it, so it doesn't face backwards until its own next update
						jjj_turn(o)
					end
				end
				if not e.entered then
					local inward = (e.side == "left") and 1 or -1
					local stationary = math.abs(o.speedx or 0) < 0.1
					if not o.shot then
						--hovering a pixel above the ground so the push in doesn't snag on the ground tiles
						o.y = e.spawny - (stationary and 1/16 or 0)
						o.speedy = 0
						if stationary then
							--enemies that aren't walking at the moment (like hopping fighter flies) get pushed in
							o.x = o.x + inward*2*dt
						elseif o.speedx*inward < 0 then
							--some enemies turn around at ledges, and there is no ground outside the screen
							o.speedx = -o.speedx
						end
					end
					local margin = stationary and 1.5 or 0
					if (e.side == "left" and o.x >= margin) or (e.side == "right" and o.x+o.width <= mapwidth-margin) then
						e.entered = true
						o.ignoregravity = e.oldignoregravity
					end
				else
					jjj_windpush(o, dist)
					--the map edges act like tiles just offscreen: walk into one and turn around
					if not o.shot then
						if o.x < 0 then
							o.x = 0
							if o.speedx < 0 then
								jjj_turn(o)
							end
						elseif o.x + o.width > mapwidth then
							o.x = mapwidth - o.width
							if o.speedx > 0 then
								jjj_turn(o)
							end
						end
					end
					if o.y > mapheight+1 or (o.shot and (o.x > mapwidth+1 or o.x+o.width < -1)) then
						o.instantdelete = true
						table.remove(S.enemies, i)
					end
				end
			end
		end
		if dist ~= 0 then
			for _, o in pairs(objects["spikeball"]) do
				jjj_windpush(o, dist)
			end
		end

		--spawned after the enemy loop, so the direction check waits for the enemy's first update
		S.spawntimer = S.spawntimer - dt
		if S.spawntimer <= 0 then
			S.spawntimer = rnd(3, 5)
			jjj_spawnenemy(S)
		end
	end,

	onstomp = function(S, player, a, b)
		if player.speedy < 0 then
			S.score = S.score + 1
			--the stomp bounce without low gravity
			local grav = (player.characterdata and player.characterdata.yacceleration) or yacceleration
			local bouncespeed = math.sqrt(2*grav*bounceheight)
			if mariomakerphysics and (not portalphysics) then
				if jumpkey(player.playernumber) then
					bouncespeed = math.sqrt(2*grav*bounceheighthigh)
				else
					bouncespeed = math.sqrt(2*grav*bounceheightmaker)
				end
			end
			player.speedy = -bouncespeed
		end
	end,

	drawoverlay = function(S)
		local W = S.wind
		if W.message and math.floor(W.messaget/JJJ_BLINK) % 2 == 0 then
			centerprintwrapped(W.message, width*8, 48, 46, {255, 255, 255})
		end
	end,
})

--------------------------
--  BLOCK BEAT BONANZA  --
--------------------------

local BEAT_PITCHES = {0.8, 1, 1.25, 1.5}
local BEAT_COLORS = {{230, 60, 60}, {70, 200, 80}, {60, 130, 240}, {240, 200, 40}}
local BEAT_KEYS = {"left", "up", "down", "right"}
local beattones = nil

local function beat_blocks()
	local blocks = {}
	for i = 1, 4 do
		table.insert(blocks, {cx = width*8 + (i-2.5)*64, cy = 112})
	end
	return blocks
end

local function beat_light(S, i, duration)
	S.lit[i] = duration
	if not beattones then
		beattones = {}
		for j = 1, 4 do
			beattones[j] = beepsound:clone()
			beattones[j]:setPitch(BEAT_PITCHES[j])
		end
	end
	playsound(beattones[i])
end

local BEAT_START_LIVES = 5
local BEAT_IDLE_TIME = 10 --seconds without a press before the pattern is shown again
local BEAT_REVIVE_LIVES = 3
local BEAT_REVIVE_COST = 10 --every this many points earns one revive
local BEAT_WRONG_TIME = 0.6

--show the pattern again, the player starts from its first block
local function beat_replay(S, delay)
	S.phase = "watchwait"
	S.t = delay or 0.6
	S.inputi = 1
	S.idle = 0
end

--out of lives: offer a revive if the revive-check score has at least one revive's worth of points
local function beat_gameover(S)
	if S.revivescore >= BEAT_REVIVE_COST then
		S.phase = "revive"
		S.revivechoice = 1 --1 = yes, 2 = no
	else
		S.phase = "over"
		minigame_finish("lose", 1)
	end
end

local function beat_revive(S, accept)
	if accept then
		--spend the points from the revive-check score, the real score stays the same
		S.revivescore = S.revivescore - BEAT_REVIVE_COST
		S.lives = S.lives + BEAT_REVIVE_LIVES
		--the music starts over
		stopmusic()
		playmusic()
		playsound(oneupsound)
		beat_replay(S, 1)
	else
		S.phase = "over"
		minigame_finish("lose", 1)
	end
end

local function beat_press(S, i)
	if S.phase ~= "input" then
		return
	end
	S.idle = 0
	beat_light(S, i, 0.25)
	if S.sequence[S.inputi] == i then
		S.inputi = S.inputi + 1
		if S.inputi > #S.sequence then
			S.score = #S.sequence
			S.revivescore = S.revivescore + 1
			minigame_popup("+1", width*8, 76)
			S.phase = "success"
			S.t = 0.8
		end
	else
		S.wrong = i
		S.wrongt = BEAT_WRONG_TIME
		playsound(blockhitsound)
		S.lives = S.lives - 1
		if S.lives <= 0 then
			beat_gameover(S)
		else
			beat_replay(S, 1)
		end
	end
end

--revive prompt layout (game pixels)
local function beat_promptboxes()
	local cx, y = width*8, 160
	return {
		{x = cx-44, y = y+14, w = 36, h = 13, accept = true, text = "yes"},
		{x = cx+8, y = y+14, w = 36, h = 13, accept = false, text = "no"},
	}, cx, y
end

addminigame({
	id = "block_beat_bonanza",
	savename = "Block Beat Bonanza",
	endless = true, --no win condition, see victoryscore
	name = "block beat bonanza",
	description = "watch the coloured ? blocks light up in a sequence, then hit them in the same order with the mouse or your movement keys. every round adds one more beat. you have 5 lives, and playing well can earn you a revive!",
	tagline = "watch the blocks, repeat the beat!", --short description on the menu graphic
	usesplayer = false,

	createmap = function(S)
		backgroundrgbon = true
		backgroundrgb = {20, 24, 48}
		S.blocks = beat_blocks()
		S.lit = {0, 0, 0, 0}
		S.sequence = {math.random(4)}
		S.lives = BEAT_START_LIVES
		S.revivescore = 0
		S.idle = 0
		S.phase = "watchwait"
		S.t = 1
	end,

	update = function(S, dt)
		for i = 1, 4 do
			S.lit[i] = math.max(0, S.lit[i]-dt)
		end
		if S.wrongt then
			S.wrongt = S.wrongt - dt
			if S.wrongt <= 0 then
				S.wrongt = nil
				S.wrong = nil
			end
		end
		if S.phase == "watchwait" then
			S.t = S.t - dt
			if S.t <= 0 then
				S.phase = "watch"
				S.showi = 0
				S.t = 0
			end
		elseif S.phase == "watch" then
			local interval = math.max(0.28, 0.6 - #S.sequence*0.02)
			S.t = S.t - dt
			if S.t <= 0 then
				S.showi = S.showi + 1
				if S.showi > #S.sequence then
					S.phase = "input"
					S.inputi = 1
					S.idle = 0
				else
					beat_light(S, S.sequence[S.showi], interval*0.65)
					S.t = interval
				end
			end
		elseif S.phase == "input" then
			--idle for too long: show the pattern again
			S.idle = S.idle + dt
			if S.idle >= BEAT_IDLE_TIME then
				beat_replay(S, 0.3)
			end
		elseif S.phase == "success" then
			S.t = S.t - dt
			if S.t <= 0 then
				table.insert(S.sequence, math.random(4))
				S.phase = "watchwait"
				S.t = 0.4
			end
		end
	end,

	mousepressed = function(S, x, y, button)
		if button ~= "l" then
			return
		end
		if S.phase == "revive" then
			for i, b in ipairs(beat_promptboxes()) do
				if x >= b.x and x <= b.x+b.w and y >= b.y and y <= b.y+b.h then
					beat_revive(S, b.accept)
					return
				end
			end
			return
		end
		for i, b in ipairs(S.blocks) do
			if x >= b.cx-22 and x <= b.cx+22 and y >= b.cy-22 and y <= b.cy+22 then
				beat_press(S, i)
				return
			end
		end
	end,

	keypressed = function(S, key)
		if S.phase == "revive" then
			if key == "left" or key == "a" or controlbindingmatcheskey(1, "left", key) then
				S.revivechoice = 1
			elseif key == "right" or key == "d" or controlbindingmatcheskey(1, "right", key) then
				S.revivechoice = 2
			elseif key == "return" or key == "enter" or key == "kpenter" or key == " " or controlbindingmatcheskey(1, "jump", key) then
				beat_revive(S, S.revivechoice == 1)
			end
			return true
		end
		for i, name in ipairs(BEAT_KEYS) do
			if controlbindingmatcheskey(1, name, key) then
				beat_press(S, i)
				return true
			end
		end
		return false
	end,

	drawworld = function(S)
		for i, b in ipairs(S.blocks) do
			local lit = S.lit[i] > 0
			local c = BEAT_COLORS[i]
			local a = lit and 255 or 70
			if S.wrong == i then
				a = (math.floor(S.time*8)%2 == 0) and 255 or 40
			end
			love.graphics.setColor(c[1], c[2], c[3], a)
			love.graphics.rectangle("fill", (b.cx-22)*scale, (b.cy-22)*scale, 44*scale, 44*scale, 5*scale)
			love.graphics.setColor(255, 255, 255)
			local bump = lit and -4 or 0
			love.graphics.draw(coinblockimage, coinblockquads[spriteset][lit and 1 or (coinframe or 1)], (b.cx-16)*scale, (b.cy-16+bump)*scale, 0, 2*scale, 2*scale)
			love.graphics.setColor(200, 200, 200)
			properprintF(BEAT_KEYS[i], (b.cx-textwidth(BEAT_KEYS[i])/2)*scale, (b.cy+28)*scale)
		end
	end,

	drawoverlay = function(S)
		if S.phase == "revive" then
			local boxes, cx, y = beat_promptboxes()
			love.graphics.setColor(0, 0, 0, 210)
			love.graphics.rectangle("fill", (cx-90)*scale, (y-6)*scale, 180*scale, 40*scale, 4*scale)
			centerprintline("revive? (+" .. BEAT_REVIVE_LIVES .. " lives)", cx, y)
			for i, b in ipairs(boxes) do
				local selected = (S.revivechoice == i)
				love.graphics.setColor(selected and {255, 230, 80} or {120, 120, 120})
				love.graphics.rectangle("line", b.x*scale, b.y*scale, b.w*scale, b.h*scale, 2*scale)
				centerprintline(b.text, b.x + b.w/2, b.y + 3, selected and {255, 230, 80} or {200, 200, 200})
			end
		elseif S.phase == "watch" or S.phase == "watchwait" then
			centerprintline("watch!", width*8, 172)
		elseif S.phase == "input" then
			centerprintline("your turn!", width*8, 172, {255, 230, 80})
		end
	end,

	drawhud = function(S)
		drawscorehud(S)
		centerprintline("Lives: " .. math.max(0, S.lives or 0), width*8, 18)
	end,
})