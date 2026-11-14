--[[
	MINIGAMES
	Everything about the minigames lives here: the list of minigames, their save data,
	the "minigames" tab of the mappack menu, the intro/win/lose screens and the minigames themselves.

	The minigames run inside game.lua (gamestate "game"). game.lua calls these hooks:
		minigame_createmap()            startlevel("minigame") builds the map
		minigame_postload()             end of startlevel, after the player spawned
		minigame_update(dt)             game_update, right before the physics update
		minigame_drawtiles()            game_draw, right after the tiles (behind every object)
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
			--a word longer than a line (a long folder name) gets split over several lines
			while utf8.len(word) > maxchars do
				if line ~= "" then
					table.insert(lines, line)
					line = ""
				end
				local cut = utf8.offset(word, maxchars+1)
				table.insert(lines, word:sub(1, cut-1))
				word = word:sub(cut)
			end
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
		local removedzeros = false
		if ok and type(t) == "table" then
			for name, scores in pairs(t) do
				if type(name) == "string" and type(scores) == "table" then
					local clean = {}
					for i = 1, #scores do
						local v = tonumber(scores[i])
						if v == 0 then
							removedzeros = true --scores of 0 are never kept
						elseif v then
							table.insert(clean, v)
						end
					end
					minigamedata[name] = clean
				end
			end
		else
			print("minigame_data.json could not be read, starting fresh")
		end
		if removedzeros then
			minigame_savedata() --the file loses its 0s too
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
		for _, v in ipairs(data[name]) do
			if v ~= 0 then --scores of 0 are never saved
				table.insert(scores, tostring(math.floor(v) == v and math.floor(v) or v))
			end
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
	minigameresult = {score = score, highscore = (score > 0 and (best == nil or score > best))}
	if minigamecurrent.title then
		minigameresult.title = minigamecurrent.title(S, score)
	end
	if score == 0 then
		return --a score of 0 isn't saved
	end
	table.insert(data[name], score)
	minigame_savedata()
end

----------------
--  REGISTRY  --
----------------

--entries of a dropdown, they can come from a function (lists that depend on files)
function minigame_optionentries(opt)
	if type(opt.entries) == "function" then
		return opt.entries()
	end
	return opt.entries
end

--sliders snap to whole steps: value = min + n*step
local function slidervalue(opt, fraction)
	local step = opt.step or 1
	local v = opt.min + fraction*(opt.max-opt.min)
	v = opt.min + math.floor((v-opt.min)/step + 0.5)*step
	return math.max(opt.min, math.min(opt.max, v))
end

local function sliderfraction(opt, v)
	if opt.max == opt.min then
		return 0
	end
	return (math.max(opt.min, math.min(opt.max, v or opt.default)) - opt.min)/(opt.max-opt.min)
end

local function addminigame(def)
	def.options = def.options or {}
	minigameoptions[def.id] = minigameoptions[def.id] or {}
	for _, opt in ipairs(def.options) do
		if minigameoptions[def.id][opt.key] == nil then
			minigameoptions[def.id][opt.key] = opt.default
		end
		--the checkbox next to a slider
		if opt.checkkey and minigameoptions[def.id][opt.checkkey] == nil then
			minigameoptions[def.id][opt.checkkey] = opt.checkdefault
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
	local space = 0
	if narrow then
		space = SCROLLBAR_SPACE
	end
	layout.space = space
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
			else --dropdown or slider, the label sits above it
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

--"Castlevania VRC6 Music- Vampire Killer" in n characters: the pack name gets shortened first
function minigame_shortentry(s, n)
	if utf8.len(s) <= n then
		return s
	end
	local pack, name = s:match("^(.-)%- (.+)$")
	if pack and utf8.len(name)+2 < n then
		local room = n - utf8.len(name) - 3 --"." and "- "
		if room >= 3 then
			local short = pack:sub(1, room):gsub("%s+$", "")
			return short .. ".- " .. name
		end
	end
	if name then
		s = name
	end
	return s:sub(1, n)
end

local SLIDER_HANDLE_W = 33 --fits "1000" like the volume slider

function minigame_newslider(opt, opts, x, y, w)
	local el = guielement:new("scrollbar", x, y, w, SLIDER_HANDLE_W, 9, sliderfraction(opt, opts[opt.key]), "hor")
	el.buttonround = true
	el.scrollstepdisabled = true --the mouse wheel scrolls the panel
	el.min, el.max = opt.min, opt.max --right click to type a number
	opts[opt.key] = slidervalue(opt, el.value)
	el.displayfunction = function(self, v)
		return tostring(slidervalue(opt, v))
	end
	el.updatefunc = function(self, v)
		opts[opt.key] = slidervalue(opt, v)
	end
	el.releasefunc = function(self, v)
		--settle on the step
		opts[opt.key] = slidervalue(opt, v)
		self.value = sliderfraction(opt, opts[opt.key])
	end
	minigame_setsliderenabled(el, true)
	return el
end

function minigame_setsliderenabled(el, enabled)
	el.disabled = not enabled
	el.backgroundcolor = {0, 0, 0}
	if enabled then
		el.bordercolor = {127, 127, 127}
		el.bordercolorhigh = {255, 255, 255}
	else
		el.bordercolor = {50, 50, 50}
		el.bordercolorhigh = {90, 90, 90}
		el.dragging = false
		el.inputting = false
	end
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
			for j, e in ipairs(minigame_optionentries(opt)) do
				entries[j] = T(e):lower() --dropdowns use the old font, its capitals are symbols
				w = math.max(w, utf8.len(entries[j]))
			end
			if #entries == 0 then
				entries[1] = "-"
			end
			if (opts[opt.key] or 1) > #entries then
				opts[opt.key] = 1 --the list got shorter (files were removed)
			end
			local panelw = math.floor((DESC_W-6-layout.space-13)/8) --the most characters that fit in the panel
			local closedw = w
			if opt.wide then
				closedw = math.min(w, panelw)
			end
			el = guielement:new("dropdown", DESC_X+3, item.y + DESC_LINE*#item.labellines, closedw, function(v)
				opts[opt.key] = v
				el.var = v
			end, opts[opt.key], unpack(entries))
			if opt.wide and w > closedw then
				--long entries: shortened while closed, the list opens wide enough for the full names
				el.closedwidth = closedw
				el.fullwidth = math.min(w, math.floor((width*16-4-13)/8))
				el.basex = el.x
				el.openx = math.max(2, math.min(el.x, width*16-2-13-el.fullwidth*8))
				el.shortentries = {}
				for j, e in ipairs(entries) do
					el.shortentries[j] = minigame_shortentry(e, closedw)
				end
				el.displayentries = el.shortentries
			end
		elseif opt.type == "slider" then
			el = minigame_newslider(opt, opts, DESC_X+3, item.y + DESC_LINE*#item.labellines, DESC_W-6-layout.space)
		elseif opt.type == "sliderbox" then
			--checkbox with a slider next to it, the slider only works while the box is ticked
			local y = item.y + DESC_LINE*#item.labellines
			local slider = minigame_newslider(opt, opts, DESC_X+16, y, DESC_W-19-layout.space)
			local box
			box = guielement:new("checkbox", DESC_X+3, y, function(v)
				opts[opt.checkkey] = v
				box.var = v
				minigame_setsliderenabled(slider, v)
			end, opts[opt.checkkey] == true)
			minigame_setsliderenabled(slider, opts[opt.checkkey] == true)
			box.active = false
			box.basey = box.y
			table.insert(minigamegui, box)
			el = slider
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
		el.active = settled and el.panelvisible ~= false and not el.disabled
		if not el.active and el.extended then
			el:close()
		end
		if el.fullwidth then
			--wide dropdowns open to the left so the full names fit
			local open = el.extended or el:getlistprogress() > 0
			if open ~= el.wideopen then
				el.wideopen = open
				if open then
					el.width, el.x, el.displayentries = el.fullwidth, el.openx, nil
				else
					el.width, el.x, el.displayentries = el.closedwidth, el.basex, el.shortentries
				end
				el:updatePos()
			end
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
		--a closed dropdown whose list would go past the bottom of the screen opens upwards from where it is now
		--(it remembers that spot and goes back to it every frame, so it's worked out again after scrolling)
		if el.type == "dropdown" and not el.extended and el:getlistprogress() == 0 and not el.cutoff then
			if el.y + 10*(#el.entries+1) > height*16 then
				el.multiy = {el.y, height*16-(10*(#el.entries+1))}
			else
				el.multiy = false
			end
		end
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
	for _, el in ipairs(minigamegui) do
		if el.type == "scrollbar" and el.inputting then
			el:keypress(key)
			return true
		end
	end
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
	--one player only (just like the daily challenges), unless the minigame needs more
	if not minigameoldplayers then
		minigameoldplayers = players
	end
	players = def.players or 1
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
		highscoreprompt = false
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

--undo what a minigame changed outside of its own state (music overrides, split screen...)
function minigame_cleanup()
	local def = minigamecurrent
	if def and def.cleanup then
		def.cleanup()
	end
end

function minigame_stopsounds()
	if scoreringsound then scoreringsound:stop() end
	if windsound then windsound:stop() end
end

function minigame_returntomenu()
	minigamesoundmuted = false
	minigame_stopsounds()
	minigame_cleanup()
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

--quitting from the pause menu asks "save highscore?" while a run is going that isn't saved yet
function minigame_canrecordscore()
	if not (minigameplaying and minigamestate and minigamecurrent) then
		return false
	end
	if math.floor(minigamestate.score or 0) == 0 then
		return false --a score of 0 isn't saved, so there's nothing to ask
	end
	return not minigamestate.recorded
end

--true while a minigame stands completely still (minigame_freeze)
function minigame_hardfrozen()
	local S = minigamestate
	if not (minigameplaying and S) then
		return false
	end
	return S.frozen == true
end

--stands the minigame completely still: the music stops, no new sounds play, the controls are off and nothing moves or
--animates. Only the minigame's frozenupdate runs (its own timers, like a banner's), and the wait of minigame_finish.
--It lasts until the minigame's level is loaded again or the results screen comes
function minigame_freeze()
	local S = minigamestate
	if not S or S.frozen then
		return
	end
	S.frozen = true
	stopmusic()
	minigamesoundmuted = true
	for _, p in pairs(objects and objects["player"] or {}) do
		p.controlsenabled = false
	end
end

--ends the current run: wait (optionally freezing the game and stopping the audio), then fade to the win/lose screen
--freeze "hard": minigame_freeze for the wait
function minigame_finish(result, delay, freeze)
	local S = minigamestate
	if not S or S.finish then
		return
	end
	S.finish = {result = result, timer = delay or 0, freeze = freeze}
	if freeze == "hard" then
		minigame_freeze()
	elseif freeze then
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
	minigamesoundmuted = false

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
	highscoreprompt = false
	highscoreprompttimer = 0
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

	--minigame physics are mario maker (a minigame can switch to mari0-maker, see jumping juggle jamboree),
	--unless the minigame keeps the game's own physics (the ones game_load picked)
	if not def.keepphysics then
		currentphysics = 6
		setphysics(currentphysics)
	end

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

--the wait after minigame_finish, then the fade to the results screen
function minigame_updatefinish(S, dt)
	S.finish.timer = S.finish.timer - dt
	if S.finish.timer <= 0 and not S.finish.fading then
		minigame_recordscore()
		local reason = "minigamelose"
		if S.finish.result == "win" then
			reason = "minigamewin"
		end
		if startwarpfade(function() levelscreen_load(reason) end) ~= false then
			S.finish.fading = true
		end
	end
end

function minigame_update(dt)
	local S, def = minigamestate, minigamecurrent
	if not (S and def) then
		return false
	end
	if S.frozen then
		--nothing moves or animates (game_update stops right after this, see minigame_freeze)
		if S.finish then
			minigame_updatefinish(S, dt)
		end
		if def.frozenupdate then
			def.frozenupdate(S, dt)
		end
		return true
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
		minigame_updatefinish(S, dt)
		if S.finish.freeze then
			if def.frozenupdate then
				def.frozenupdate(S, dt) --what keeps moving while the game stands still
			end
			return true
		end
	end

	if def.update then
		return def.update(S, dt) == true
	end
	return false
end

function minigame_drawtiles()
	local S, def = minigamestate, minigamecurrent
	if S and def and def.drawtiles then
		love.graphics.setColor(255, 255, 255)
		def.drawtiles(S)
		love.graphics.setColor(255, 255, 255)
	end
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
	minigame_rawjumpkey = originaljumpkey --the real button, for minigames that need actual presses
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
	minigamesoundmuted = false --the freeze before this screen is over (see minigame_finish)
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
		local silent = minigamecurrent and minigamecurrent.resultsilent --the minigame already played its own jingle
		--or the minigame plays its own music on this screen, and says how long the screen stays up
		local ownmusic = false
		if minigamecurrent and minigamecurrent.resultmusic and minigamestate then
			stopmusic()
			love.audio.stop()
			ownmusic = minigamecurrent.resultmusic(minigamestate)
			if ownmusic then
				silent = false
			end
		end
		if not silent and not ownmusic then
			stopmusic()
			love.audio.stop()
		end
		--blacktime ends when the sound does (the fade out starts right after it)
		if reason == "minigamewin" then
			minigamescreen = "win"
			confetti_start()
		else --"minigamelose" or the player's death
			minigamescreen = "lose"
		end
		if ownmusic then
			blacktime = ownmusic + warpfadetime
		elseif silent then
			--no sound, the results stay up for resultsilent seconds (or just the fade when it's true)
			blacktime = warpfadetime
			if type(silent) == "number" then
				blacktime = silent + warpfadetime
			end
		else
			local sound = dclose2sound
			if minigamescreen == "win" or (minigameresult and minigameresult.highscore) then
				sound = dcwin2sound --a new highscore gets the victory sound even on a loss
			end
			if minigamecurrent and minigamecurrent.resultsound and minigamestate then
				sound = minigamecurrent.resultsound(minigamestate) or sound --the minigame's own fanfare
			end
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
	local def = minigamecurrent
	if minigamescreen and minigamescreen ~= "intro" and def and def.resultupdate and minigamestate then
		def.resultupdate(minigamestate, dt)
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
		end
		if def.resultheadline and minigamestate then
			centerprintline(def.resultheadline(minigamestate), cx, 84)
		elseif minigamescreen == "win" then
			centerprintline(T("you win!"), cx, 84)
		else
			centerprintline(T("game over!"), cx, 84)
		end
		centerprintline(name, cx, 104, {200, 200, 200})
		local score = minigameresult and minigameresult.score or (minigamestate and minigamestate.score) or 0
		centerprintline(T(def.scorelabel or "score") .. ": " .. formatscore(score), cx, 128)
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
do --each minigame keeps its locals in a do block (a file can only have 200 at the top level)

local BOO_ANIM_TIME = 0.1 --the whole animation (column 1, column 2)
local BOO_START_TIME = 10
local BOO_INCREMENT_INTERVAL = 0.0625
local BOO_WAIT = 0.5
local BOO_FADE_TIME = 0.5
local BOO_ROTATE_TIME = 0.25
local BOO_CROSS_TIME = 0.5
local BOO_ROUNDTYPES = {"shy", "circle", "chain", "wave", "lanes", "spiral", "flock", "shuffle", "teleport", "flee", "phase", "swing", "superrandom"}
--nitpick "orderedmovementtypes": the round types go in this order and loop, without super random
local BOO_ORDEREDTYPES = {}
for _, roundtype in ipairs(BOO_ROUNDTYPES) do
	if roundtype ~= "superrandom" then
		table.insert(BOO_ORDEREDTYPES, roundtype)
	end
end
local BOO_SPEEDUP = 0.025 --boos move this much faster every round...
local BOO_SPEEDUP_MAX = 0.5 --...up to 50% faster
local BOO_TOP = 2.5 --boos stay under the HUD (tiles)
local BOO_BONUS_STEP = 3 --found in less than n*3 seconds: add 6-n seconds
local BOO_BONUS_MAX = 5
local BOO_METER_W, BOO_METER_H = 40, 4 --bonus meter under the boo to find
local BOO_METER_Y = 37

local function boo_bonus(roundtime)
	if ImmortalComboMeter then
		return BOO_BONUS_MAX --nitpick: the meter never drains
	end
	local n = math.floor(roundtime/BOO_BONUS_STEP)+1
	return math.max(0, BOO_BONUS_MAX+1-n)
end

--how many meter segments are filled: full ones for the bonus below the current one, the current one drains over its 3 seconds
local function boo_bonusfill(roundtime)
	if ImmortalComboMeter then
		return BOO_BONUS_MAX
	end
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
	if OrderedMovementTypes then
		S.roundtypeindex = (S.roundtypeindex or 0) % #BOO_ORDEREDTYPES + 1
		roundtype = BOO_ORDEREDTYPES[S.roundtypeindex]
	else
		repeat
			roundtype = randomitem(BOO_ROUNDTYPES)
		until roundtype ~= S.roundtype
	end
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
	--some round types (circle, chain, lanes, spiral, swing...) only work out positions in update
	--so run it once with no time passing, or the boos show at their random spot for a frame first
	if move and move.groupupdate then
		move.groupupdate(S, 0)
	end
	if move and move.update then
		for _, b in ipairs(S.boos) do
			move.update(S, b, 0)
		end
	end
end

----------------------------
--  BOO FOUND ANIMATIONS  --
----------------------------
--what a boo does once it's been found (or when time runs out), one is picked at random
--start(b, a) plays the starting sound and sets things up, update(b, a, dt) sets a.done once it's finished
--drawbehind(b, a) and drawfront(b, a) are optional and draw extra bits (smoke, trails, puddles, pieces, sparkles)
--b.sx/b.sy stretch the boo, b.ox/b.oy nudge it (in tiles) and b.tint replaces its colour

--the file's main chunk can only hold 200 locals, so everything only used here lives in a do block
local BOO_FOUND_ANIMS, boo_startanimation, boo_updateanimation
do

local BOO_SPIN_TIME = 0.6
local BOO_SPIN_TURNS = 3
local BOO_ROCKET_WINDUP = 0.25
local BOO_ROCKET_ACCEL = 60
local BOO_SMOKE_INTERVAL = 0.03
local BOO_SMOKE_LIFE = 0.4
local BOO_SQUASH_TIME = 0.12
local BOO_SQUASH_HOLD = 0.4
local BOO_SQUASH_FADE = 0.25
local BOO_MELT_TIME = 1
local BOO_PUDDLE_FADE = 0.3
local BOO_FREEZE_TIME = 0.5
local BOO_SHATTER_TIME = 1.5
local BOO_ICE_COLOUR = {150, 220, 255}
local BOO_BURST_GROW = 0.2
local BOO_BURST_TIME = 0.6
local BOO_BURST_SPARKS = 8
local BOO_BURST_SPEED = 7
local BOO_DASH_WINDUP = 0.3
local BOO_DASH_SPEED = 12
local BOO_DASH_ACCEL = 50
local BOO_TRAIL_INTERVAL = 0.025
local BOO_TRAIL_LIFE = 0.2

local function boo_lerp(a, b, t)
	return a + (b-a)*t
end

local function boo_lerpcolour(c1, c2, t)
	return {boo_lerp(c1[1], c2[1], t), boo_lerp(c1[2], c2[2], t), boo_lerp(c1[3], c2[3], t)}
end

--keeps the bottom of the boo on the same spot while it's squashed or stretched
local function boo_anchorbottom(b)
	b.oy = (1 - b.scale*b.sy)*0.5
end

--counts down every particle's life and removes the dead ones
local function boo_ageparticles(list, dt)
	for i = #list, 1, -1 do
		local p = list[i]
		p.life = p.life - dt
		if p.life <= 0 then
			table.remove(list, i)
		end
	end
end

BOO_FOUND_ANIMS = {
	--grows and fades away
	fade = {
		start = function(b, a)
			playsound(mushroomappearsound)
			a.t = 0
		end,
		update = function(b, a, dt)
			a.t = a.t + dt
			local p = math.min(1, a.t/BOO_FADE_TIME)
			b.scale = 1 + p*1.5
			b.alpha = 255*(1-p)
			if b.alpha <= 0 then
				a.done = true
			end
		end,
	},

	--flips over and falls off the screen
	fall = {
		start = function(b, a)
			playsound(bowserfallsound)
			a.t = 0
			a.dir = randomsign()
			a.speedy = 0
		end,
		update = function(b, a, dt)
			a.t = a.t + dt
			b.rot = a.dir*math.pi*motion_curve(math.min(1, a.t/BOO_ROTATE_TIME), "sine", true, true, true, true)
			a.speedy = a.speedy + minigamegravity*dt
			b.y = b.y + a.speedy*dt
			--off the bottom of the screen and the fall sound has finished
			if b.y > height and not bowserfallsound:isPlaying() then
				a.done = true
			end
		end,
	},

	--vanishes in a puff of smoke
	poof = {
		start = function(b, a)
			playsound(stompbigsound)
			makepoof(b.x+0.5, b.y+1, "poof")
			a.poof = poofs[#poofs]
			b.hidden = true
		end,
		update = function(b, a, dt)
			if not (a.poof and tablefind(poofs, a.poof)) then
				a.done = true
			end
		end,
	},

	--twirls faster and faster, puffs up a little and shrinks to nothing
	spin = {
		start = function(b, a)
			playsound(raccoonswingsound)
			a.t = 0
			a.dir = randomsign()
		end,
		update = function(b, a, dt)
			a.t = a.t + dt
			local p = math.min(1, a.t/BOO_SPIN_TIME)
			b.rot = a.dir*motion_curve(p, "quad")*math.pi*2*BOO_SPIN_TURNS
			--"back" dips below 0 first, so the boo grows a bit before it shrinks
			b.scale = math.max(0, 1 - motion_curve(p, "back"))
			if p >= 1 then
				b.hidden = true
				a.done = true
			end
		end,
	},

	--crouches down, then blasts off the top of the screen with a smoke trail
	rocket = {
		start = function(b, a)
			playsound(cannonfastsound)
			a.t = 0
			a.speedy = 0
			a.smoke = {}
			a.smoketimer = 0
		end,
		update = function(b, a, dt)
			a.t = a.t + dt
			if a.t < BOO_ROCKET_WINDUP then
				local p = motion_curve(a.t/BOO_ROCKET_WINDUP, "quad", true)
				b.sx, b.sy = 1 + 0.3*p, 1 - 0.4*p
				boo_anchorbottom(b)
			else
				b.sx, b.sy = 0.8, 1.4
				b.oy = 0
				a.speedy = a.speedy - BOO_ROCKET_ACCEL*dt
				b.y = b.y + a.speedy*dt
				a.smoketimer = a.smoketimer - dt
				if a.smoketimer <= 0 and b.y > -1.5 then
					a.smoketimer = BOO_SMOKE_INTERVAL
					table.insert(a.smoke, {x = b.x+0.5+rnd(-0.15, 0.15), y = b.y+1.2, life = BOO_SMOKE_LIFE})
				end
			end
			boo_ageparticles(a.smoke, dt)
			if b.y < -2 and #a.smoke == 0 then
				a.done = true
			end
		end,
		drawbehind = function(b, a)
			for _, s in ipairs(a.smoke) do
				local life = s.life/BOO_SMOKE_LIFE
				love.graphics.setColor(200, 200, 200, 180*life)
				love.graphics.circle("fill", s.x*16*scale, s.y*16*scale, (1.5 + 3.5*(1-life))*scale)
			end
		end,
	},

	--gets flattened like a pancake, then fades
	squash = {
		start = function(b, a)
			playsound(stompsound)
			a.t = 0
		end,
		update = function(b, a, dt)
			a.t = a.t + dt
			--"back" eased out overshoots, so it squishes a bit too far and springs back
			local e = motion_curve(math.min(1, a.t/BOO_SQUASH_TIME), "back", true)
			b.sx, b.sy = boo_lerp(1, 1.8, e), boo_lerp(1, 0.15, e)
			boo_anchorbottom(b)
			local fade = a.t - BOO_SQUASH_TIME - BOO_SQUASH_HOLD
			if fade > 0 then
				b.alpha = 255*math.max(0, 1 - fade/BOO_SQUASH_FADE)
				if b.alpha <= 0 then
					a.done = true
				end
			end
		end,
	},

	--wobbles and melts down into a puddle that dries up
	melt = {
		start = function(b, a)
			playsound(meltsound)
			a.t = 0
			local _, _, colour = boo_graphic(b.variant, 1)
			a.colour = colour
			a.puddle = 0
			a.puddlealpha = 1
		end,
		update = function(b, a, dt)
			a.t = a.t + dt
			local p = math.min(1, a.t/BOO_MELT_TIME)
			local e = motion_curve(p, "quad")
			local wobble = math.sin(a.t*25)*0.08*(1-p)
			b.sx = 1 + 0.6*e + wobble
			b.sy = math.max(0.01, 1 - e)
			boo_anchorbottom(b)
			a.puddle = math.min(1, p*1.5)
			if p > 0.7 then
				b.alpha = 255*math.max(0, 1 - (p-0.7)/0.3)
			end
			if p >= 1 then
				b.hidden = true
				a.puddlealpha = math.max(0, 1 - (a.t-BOO_MELT_TIME)/BOO_PUDDLE_FADE)
				if a.puddlealpha <= 0 then
					a.done = true
				end
			end
		end,
		drawbehind = function(b, a)
			love.graphics.setColor(a.colour[1], a.colour[2], a.colour[3], 160*a.puddlealpha)
			love.graphics.ellipse("fill", (b.x+0.5)*16*scale, ((b.y+1)*16-1)*scale, 9*a.puddle*scale, 2*a.puddle*scale)
		end,
	},

	--freezes solid, shakes, then shatters into four pieces
	shatter = {
		start = function(b, a)
			playsound(freezesound)
			a.t = 0
			a.img, a.quad, a.colour = boo_graphic(b.variant, boo_frame(b))
		end,
		update = function(b, a, dt)
			a.t = a.t + dt
			if not a.pieces then
				local p = math.min(1, a.t/BOO_FREEZE_TIME)
				b.tint = boo_lerpcolour(a.colour, BOO_ICE_COLOUR, p)
				b.ox, b.oy = rnd(-1, 1)*p/16, rnd(-1, 1)*p/16
				if p >= 1 then
					playsound(iceblockbreaksound)
					b.hidden = true
					a.pieces = {}
					local qx, qy = a.quad:getViewport()
					local iw, ih = a.img:getDimensions()
					for i = 0, 1 do
						for j = 0, 1 do
							--the sprite can be mirrored, so the pieces have to be too
							local dx, dy = (i-0.5)*b.facing, j-0.5
							table.insert(a.pieces, {
								quad = love.graphics.newQuad(qx+i*8, qy+j*8, 8, 8, iw, ih),
								x = b.x+0.5+dx*0.5, y = b.y+0.5+dy*0.5,
								vx = dx*rnd(4, 7), vy = -rnd(6, 10) + dy*3,
								rot = 0, spin = rnd(-12, 12),
							})
						end
					end
				end
			else
				for _, pc in ipairs(a.pieces) do
					pc.vy = pc.vy + minigamegravity*dt
					pc.x = pc.x + pc.vx*dt
					pc.y = pc.y + pc.vy*dt
					pc.rot = pc.rot + pc.spin*dt
				end
				if a.t > BOO_FREEZE_TIME + BOO_SHATTER_TIME then
					a.done = true
				end
			end
		end,
		drawfront = function(b, a)
			if a.pieces then
				love.graphics.setColor(BOO_ICE_COLOUR)
				for _, pc in ipairs(a.pieces) do
					love.graphics.draw(a.img, pc.quad, pc.x*16*scale, pc.y*16*scale, pc.rot, b.facing*scale, scale, 4, 4)
				end
			end
		end,
	},

	--puffs up, flashes white and bursts into a ring of sparkles
	burst = {
		start = function(b, a)
			playsound(magicsound)
			a.t = 0
			local _, _, colour = boo_graphic(b.variant, 1)
			a.colour = colour
		end,
		update = function(b, a, dt)
			a.t = a.t + dt
			if not a.sparks then
				local p = math.min(1, a.t/BOO_BURST_GROW)
				b.scale = 1 + 0.6*motion_curve(p, "quad")
				b.tint = boo_lerpcolour(a.colour, {255, 255, 255}, p)
				if p >= 1 then
					b.hidden = true
					a.sparks = {}
					for i = 1, BOO_BURST_SPARKS do
						local angle = (i-1)/BOO_BURST_SPARKS*math.pi*2
						table.insert(a.sparks, {x = b.x+0.5, y = b.y+0.5, vx = math.cos(angle)*BOO_BURST_SPEED, vy = math.sin(angle)*BOO_BURST_SPEED})
					end
					a.t = 0
				end
			else
				local drag = math.exp(-4*dt)
				for _, s in ipairs(a.sparks) do
					s.x = s.x + s.vx*dt
					s.y = s.y + s.vy*dt
					s.vx, s.vy = s.vx*drag, s.vy*drag
				end
				if a.t >= BOO_BURST_TIME then
					a.done = true
				end
			end
		end,
		drawfront = function(b, a)
			if a.sparks then
				local life = math.max(0, 1 - a.t/BOO_BURST_TIME)
				local size = 1 + 3*life
				love.graphics.setLineWidth(scale)
				for i, s in ipairs(a.sparks) do
					--every other sparkle is white
					local c = a.colour
					if i % 2 == 0 then
						c = {255, 255, 255}
					end
					love.graphics.setColor(c[1], c[2], c[3], 255*life)
					love.graphics.push()
					love.graphics.translate(s.x*16*scale, s.y*16*scale)
					love.graphics.rotate(a.t*10)
					love.graphics.line(-size*scale, 0, size*scale, 0)
					love.graphics.line(0, -size*scale, 0, size*scale)
					love.graphics.pop()
				end
				love.graphics.setLineWidth(1)
			end
		end,
	},

	--leans back, then zooms off the side of the screen it's looking at, leaving afterimages
	dash = {
		start = function(b, a)
			playsound(capeflysound)
			a.t = 0
			a.dir = -b.facing --the sprite looks left when facing is 1
			a.startx = b.x
			a.speed = BOO_DASH_SPEED
			a.trail = {}
			a.trailtimer = 0
		end,
		update = function(b, a, dt)
			a.t = a.t + dt
			if a.t < BOO_DASH_WINDUP then
				local p = motion_curve(a.t/BOO_DASH_WINDUP, "quad", true)
				b.x = a.startx - a.dir*0.4*p
				b.rot = -a.dir*0.35*p
				b.sx, b.sy = 1 - 0.15*p, 1 + 0.1*p
			else
				a.speed = a.speed + BOO_DASH_ACCEL*dt
				b.x = b.x + a.dir*a.speed*dt
				b.rot = a.dir*0.25
				b.sx, b.sy = 1.3, 0.85
				a.trailtimer = a.trailtimer - dt
				if a.trailtimer <= 0 and b.x > -1 and b.x < width then
					a.trailtimer = BOO_TRAIL_INTERVAL
					table.insert(a.trail, {x = b.x, y = b.y, life = BOO_TRAIL_LIFE})
				end
			end
			boo_ageparticles(a.trail, dt)
			if (b.x < -2 or b.x > width+1) and #a.trail == 0 then
				a.done = true
			end
		end,
		drawbehind = function(b, a)
			local img, quad, colour = boo_graphic(b.variant, boo_frame(b))
			for _, tr in ipairs(a.trail) do
				love.graphics.setColor(colour[1], colour[2], colour[3], 120*tr.life/BOO_TRAIL_LIFE)
				love.graphics.draw(img, quad, (tr.x*16+8)*scale, (tr.y*16+8)*scale, b.rot, b.sx*b.facing*scale, b.sy*scale, 8, 8)
			end
		end,
	},
}

--sorted so the same random seed always picks the same animation
local BOO_FOUND_ANIM_NAMES = {}
for name in pairs(BOO_FOUND_ANIMS) do
	table.insert(BOO_FOUND_ANIM_NAMES, name)
end
table.sort(BOO_FOUND_ANIM_NAMES)

function boo_startanimation(b)
	boo_stop(b)
	local name = randomitem(BOO_FOUND_ANIM_NAMES)
	b.anim = {type = name}
	BOO_FOUND_ANIMS[name].start(b, b.anim)
end

function boo_updateanimation(b, dt)
	local a = b.anim
	if a.done then
		return
	end
	BOO_FOUND_ANIMS[a.type].update(b, a, dt)
end

end --do

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
			--nitpick "alwaysinfinitetime": take as long as you like, the timer never goes down
			if not AlwaysInfiniteTime then
				local old = S.timer
				S.timer = math.max(0, S.timer - dt)
				if math.ceil(S.timer) < math.ceil(old) then
					playsound(beepsound)
				end
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
					local bonus = boo_bonus(S.roundtime)
					S.score = S.score + math.max(1, bonus) --points from the combo meter, at least 1 even when it's empty
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
			--found animations can draw extra bits behind and in front of the boo
			local animdef = nil
			if b.anim then
				animdef = BOO_FOUND_ANIMS[b.anim.type]
			end
			if animdef and animdef.drawbehind then
				animdef.drawbehind(b, b.anim)
			end
			if not b.hidden then
				local img, quad, color = boo_graphic(b.variant, boo_frame(b))
				local bx, by = boo_position(b)
				bx, by = bx + (b.ox or 0), by + (b.oy or 0)
				local tint = b.tint or color
				love.graphics.setColor(tint[1], tint[2], tint[3], b.alpha)
				love.graphics.draw(img, quad, (bx*16+8)*scale, (by*16+8)*scale, b.rot, b.scale*(b.sx or 1)*b.facing*scale, b.scale*(b.sy or 1)*scale, 8, 8)
				if b.cross then
					--red wrong cross
					love.graphics.setColor(255, 30, 30, 255*(b.cross/BOO_CROSS_TIME))
					love.graphics.setLineWidth(2*scale)
					love.graphics.line((bx*16+2)*scale, (by*16+2)*scale, (bx*16+14)*scale, (by*16+14)*scale)
					love.graphics.line((bx*16+14)*scale, (by*16+2)*scale, (bx*16+2)*scale, (by*16+14)*scale)
					love.graphics.setLineWidth(1)
				end
			end
			if animdef and animdef.drawfront then
				animdef.drawfront(b, b.anim)
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

end --do (boo baffler bash)

------------------------------
--  SNAKE SLITHER SCRAMBLE  --
------------------------------
do --each minigame keeps its locals in a do block (a file can only have 200 at the top level)

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
	--nitpick "invinciblesnake": acts like it always has a star, without looking like it
	if (not S.ghost) and (not InvincibleSnake) and (snake_iswall(S, nx, ny) or snake_onsnake(S, nx, ny, not S.growing)) then
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
			--nitpick "probabilitypasser": no random wait, it shows up as soon as there isn't one
			if ProbabilityPasser then
				S.startimer = 0
			end
			S.startimer = S.startimer - dt
			if S.startimer <= 0 then
				S.star = snake_freecell(S)
				if not S.star then
					S.startimer = 1
				end
			end
		end

		if not S.secret then
			if ProbabilityPasser then
				S.secrettimer = 0
			end
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

end --do (snake slither scramble)

-------------------------------
--  JUMPING JUGGLE JAMBOREE  --
-------------------------------
do --each minigame keeps its locals in a do block (a file can only have 200 at the top level)

local JJJ_WIND_SPEED = 4
local JJJ_WIND_RAMP = 1 --sine in-out start and stop of the wind
local JJJ_WARNING_TIME = 3
local JJJ_BLINK = 0.5
local JJJ_BLOCK_TILE = 78
local JJJ_GROUND_TILE = 2
local JJJ_BLOCK_ROW = 9
local JJJ_GROUND_Y = 13 --top of the ground
local JJJ_ENEMIES = {"goomba", "goombrat", "paragoomba", "biggoomba", "splunkin", "drygoomba", "fighterfly", "mole", "spike"}
local JJJ_PROJECTILES = {"bulletbill", "homingbullet", "cannonball", "bigbill"} --fly in from the sides, never on the screen at the start
local JJJ_SPAWNABLE = {} --everything that can come in from the sides
for _, t in ipairs(JJJ_ENEMIES) do
	table.insert(JJJ_SPAWNABLE, t)
end
for _, t in ipairs(JJJ_PROJECTILES) do
	table.insert(JJJ_SPAWNABLE, t)
end
local JJJ_REACH_ENEMY_HEIGHT = 12/16 --the grounded enemy the jump reach is measured from (a goomba)
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
local function jjj_newenemy(S, x, t)
	local t = t or randomitem(JJJ_ENEMIES)
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
	local count = math.random(3, 10)
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

--the speed of the bounce off a stomped enemy (no low gravity)
local function jjj_stompbouncespeed(p, held)
	local grav = yacceleration
	if p.characterdata then
		grav = p.characterdata.yacceleration
	end
	local bouncespeed = math.sqrt(2*grav*bounceheight)
	if mariomakerphysics and (not portalphysics) then
		if held then
			bouncespeed = math.sqrt(2*grav*bounceheighthigh)
		else
			bouncespeed = math.sqrt(2*grav*bounceheightmaker)
		end
	end
	return bouncespeed
end

--the highest y the player's feet reach after stomping a grounded enemy (smaller y = higher up)
local function jjj_stompreachy(p)
	local risegrav = yacceleration
	if p.characterdata then
		risegrav = p.characterdata.yacceleration
	end
	if mariomakerphysics and (not portalphysics) then
		--mario:stompenemy keeps the player "jumping", so the way up uses the jumping gravity
		risegrav = yaccelerationjumping
		if p.characterdata then
			risegrav = p.characterdata.yaccelerationjumping
		end
	end
	local speed = jjj_stompbouncespeed(p, true) --jump counts as held for the whole run
	local riseheight = speed*speed/(2*risegrav)
	return JJJ_GROUND_Y - JJJ_REACH_ENEMY_HEIGHT - riseheight
end

--a bullet bill, homing bullet bill, cannon ball or big bill flying in from one side
local function jjj_spawnprojectile(S, t, side)
	local dir = "left"
	if side == "left" then
		dir = "right" --comes in from the left, flies to the right
	end

	local obj, objtable
	if t == "bulletbill" then
		obj, objtable = bulletbill:new(0, 0, dir), "bulletbill"
	elseif t == "homingbullet" then
		obj, objtable = bulletbill:new(0, 0, dir, "homing"), "bulletbill"
	elseif t == "cannonball" then
		obj, objtable = cannonball:new(0, 0, dir), "cannonball"
	elseif t == "bigbill" then
		obj, objtable = bigbill:new(0, 0, dir), "bigbill"
	end
	if not obj then
		return
	end
	--no launcher to come out of
	obj.customscissor = nil
	obj.active = true

	local lowesty = JJJ_GROUND_Y - 1 - obj.height --bottom one tile above the ground
	local highesty = 1 --homing bullets can come in at any height, they chase the player anyway
	if t ~= "homingbullet" then
		local p = objects["player"][1]
		if p then
			highesty = jjj_stompreachy(p) + 1 --top one tile below the highest stomp bounce
		end
	end
	if highesty > lowesty then
		highesty = lowesty --the bounce is too low for the range, so keep it one tile above the ground
	end
	obj.y = rnd(highesty, lowesty)

	if side == "left" then
		obj.x = -obj.width
	else
		obj.x = mapwidth
	end
	obj.startx = obj.x

	table.insert(objects[objtable], obj)
	table.insert(S.enemies, {obj = obj, side = side, projectile = true, entered = true})
end

local function jjj_spawnenemy(S)
	local side = (math.random(2) == 1) and "left" or "right"
	local t = randomitem(JJJ_SPAWNABLE)
	if tablecontains(JJJ_PROJECTILES, t) then
		jjj_spawnprojectile(S, t, side)
		return
	end
	local obj = jjj_newenemy(S, (side == "left") and 1 or mapwidth, t)
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

--is the real jump button down? (jumpkey counts as held for the whole run)
local function jjj_rawjump()
	local fn = minigame_rawjumpkey or jumpkey
	return fn(1) == true
end

--the speed of a jump with the most height a jump can get (what a full speed run-up gives)
local function jjj_fullheight(p)
	local jumpforce, jumpforceadd = p.characterdata.jumpforce, p.characterdata.jumpforceadd
	if currentphysics == 7 then --portal physics, same as mario:jump
		jumpforce, jumpforceadd = portalphysicsjumpforce, portalphysicsjumpforceadd
	end
	p.speedy = -(jumpforce + jumpforceadd)
end

--nitpick "multiplejumping": a full height jump from anywhere, with the jump sound and animation
local function jjj_fulljump(p)
	--mario:jump only works when standing, so it gets told the player is
	p.falling = false
	p.hasdoublejumped = false
	p:jump(true)
	jjj_fullheight(p)
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
		S.rawjumpheld = jjj_rawjump() --a button held from the menu isn't a new press
		jjj_spawnstartenemies(S)
	end,

	update = function(S, dt)
		local p = objects["player"][1]
		if not p then
			return
		end

		--multiple jumping: presses of the real jump button
		local jumppressed = false
		if MultipleJumping then
			local down = jjj_rawjump()
			jumppressed = down and not S.rawjumpheld
			S.rawjumpheld = down
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
				if MultipleJumping then
					--the normal jump already played its sound and animation, it only needs the full height
					jjj_fullheight(p)
					jumppressed = false --this press was the jump off the blocks
				end
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
				if MultipleJumping then
					--a point and straight back up
					S.score = S.score + 1
					jjj_fulljump(p)
				elseif not AlwaysInfiniteLives then
					p:die("killscript")
					return
				end
				--nitpick "alwaysinfinitelives": just land, as if nothing happened
			elseif MultipleJumping and jumppressed then
				jjj_fulljump(p)
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
			elseif e.projectile then
				--flies straight across (no walking, turning or wind), gone once it leaves the screen
				local gone = o.y > mapheight+1
				if not o.shot then
					if o.speedx > 0 and o.x > mapwidth+1 then
						gone = true
					elseif o.speedx < 0 and o.x+o.width < -1 then
						gone = true
					end
				elseif o.x > mapwidth+1 or o.x+o.width < -1 then
					gone = true
				end
				if gone then
					o.instantdelete = true
					table.remove(S.enemies, i)
				end
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
			S.spawntimer = rnd(0.5, 2)
			jjj_spawnenemy(S)
		end
	end,

	onstomp = function(S, player, a, b)
		if player.speedy < 0 then
			S.score = S.score + 1
			--the stomp bounce without low gravity
			player.speedy = -jjj_stompbouncespeed(player, jumpkey(player.playernumber))
		end
	end,

	drawoverlay = function(S)
		local W = S.wind
		if W.message and math.floor(W.messaget/JJJ_BLINK) % 2 == 0 then
			centerprintwrapped(W.message, width*8, 48, 46, {255, 255, 255})
		end
	end,
})

end --do (jumping juggle jamboree)

--------------------------
--  BLOCK BEAT BONANZA  --
--------------------------
do --each minigame keeps its locals in a do block (a file can only have 200 at the top level)

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
	--nitpick "alwaysinfinitelives": a revive is always on offer
	if AlwaysInfiniteLives or S.revivescore >= BEAT_REVIVE_COST then
		S.phase = "revive"
		S.revivechoice = 1 --1 = yes, 2 = no
		--opens and closes like the pause menu's prompts (see beat_updateprompt)
		S.reviveprompt = {open = true, timer = 0, curve = random_motion_curve()}
	else
		S.phase = "over"
		minigame_finish("lose", 1)
	end
end

local function beat_revive(S, accept)
	if S.reviveprompt then
		S.reviveprompt.open = false --it shrinks away over whatever comes next
		S.reviveprompt.curve = random_motion_curve()
	end
	if accept then
		--spend the points from the revive-check score, the real score stays the same
		--(free with infinite lives)
		if not AlwaysInfiniteLives then
			S.revivescore = S.revivescore - BEAT_REVIVE_COST
		end
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

--the revive prompt's text and options (drawn with the pause menu's drawprompt and drawpromptcontent)
local function beat_promptcontent()
	return {"revive? (+" .. BEAT_REVIVE_LIVES .. " lives)"}, {prompttext("yes"), prompttext("no")}
end

--the prompt's timer, like the pause menu's prompts: up while open, down while closing
local function beat_updateprompt(S, dt)
	local P = S.reviveprompt
	if not P then
		return
	end
	P.timer = math.max(0, math.min(P.timer + dt*(P.open and 1 or -1), pausemenuduration))
	if not P.open and P.timer <= 0 then
		S.reviveprompt = nil
	end
end

--answers only count once the prompt is fully open (the same as the pause menu's prompts)
local function beat_promptready(S)
	local P = S.reviveprompt
	return S.phase == "revive" and P ~= nil and P.open and P.timer >= pausemenuduration
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
		beat_updateprompt(S, dt)
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
			if beat_promptready(S) then
				local lines, options = beat_promptcontent()
				local i = promptoptionat(x*scale, y*scale, lines, options)
				if i then
					beat_revive(S, i == 1)
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
			if not beat_promptready(S) then
				return true
			end
			--up and down, like the pause menu's prompts
			if key == "up" or key == "w" or controlbindingmatcheskey(1, "up", key) then
				S.revivechoice = 1
			elseif key == "down" or key == "s" or controlbindingmatcheskey(1, "down", key) then
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
		if S.phase == "watch" or S.phase == "watchwait" then
			centerprintline("watch!", width*8, 172)
		elseif S.phase == "input" then
			centerprintline("your turn!", width*8, 172, {255, 230, 80})
		end
		--the revive prompt, drawn and animated like the pause menu's prompts
		local P = S.reviveprompt
		if P and P.timer > 0 then
			local lines, options = beat_promptcontent()
			drawprompt(P.timer, pausemenuduration, P.open, P.curve, #lines + #options)
			drawpromptcontent(lines, options, S.revivechoice)
			love.graphics.pop()
		end
	end,

	drawhud = function(S)
		drawscorehud(S)
		centerprintline("Lives: " .. math.max(0, S.lives or 0), width*8, 18)
	end,
})

end --do (block beat bonanza)

---------------------
--  RIVAL RUMBLE ROYALE  --
---------------------
--Four players (people or bots) on one arena, the last one with lives left wins.
--Built after the battle mode of Super Mario 4 Jugadores: a closed arena a bit wider than the screen (split screen
--for every person playing), a ? block above every spawn, two ? blocks in the middle and a rare one at the top.
do --each minigame keeps its locals in a do block (a file can only have 200 at the top level)

local RRR_ID = "rival_rumble_royale"
local RRR_PLAYERS = 4
local RRR_ROULETTE_TIME = 0.2 --an item shows for this long, then the next one
local RRR_COUNTDOWN = 3 --"3", "2", "1" (a second each, real time), then "go!" and the music starts
local RRR_HIT_CREDIT = 4 --dying this soon after a hit (falling in a pit for example) is a knockout for the hitter
local RRR_RESULT_TIME = 4 --the results screen (the battle clear theme already played in the arena)
local RRR_CLEAR_MAX = 15 --a battle clear theme longer than this gets cut off
local RRR_KO_FREEZE = 3 --the last knockout freezes the arena for this long before the results screen
local RRR_K = {} --(a table: the file can only have 200 locals at once)
RRR_K.FINALCOUNT = 5 --under this many seconds, the timer shows as a big number with a beep every second
RRR_K.SD_ANNOUNCE = 1.5 --time up: "time up!", then this much later "sudden death!"
RRR_K.SD_DELAY = 3 --and this long after time up, the fade to the sudden death arena
RRR_K.SD_LIVES = 1 --everyone still in the battle gets this many lives in sudden death
RRR_K.FAKEFAST_RATE = 1.25 --a song without a fast version gets one at 1.25x speed (higher too with classicspeedupfastmusic, see music:fakefast)
local RRR_DEFAULT_CLEAR = "sounds/bowserend.ogg" --the battle clear theme without a pack one (see rrr_setupmusic)
local RRR_MUSIC_NAME = "rivalrumbleroyalemusic"
local RRR_MUSIC_FOLDER = "sounds/" .. RRR_MUSIC_NAME
local RRR_SAVE_MUSIC_FOLDER = "alesans_entities/" .. RRR_MUSIC_NAME --in the save folder, so music can be added without touching the game
--where custom music is looked for (the save folder first: a song or pack there wins over one with the same name in the game)
local RRR_MUSIC_FOLDERS = {RRR_SAVE_MUSIC_FOLDER, RRR_MUSIC_FOLDER}

--? blocks: the block above a spawn, the two in the middle and the rare one
local RRR_BLOCKS = {
	S = {kind = "spawn", cooldown = 10, items = {"fireflower", "hammersuit", "boomerangflower"}, color = {255, 255, 255}},
	["?"] = {kind = "normal", cooldown = 15, items = {"leaf", "tanookisuit", "superballflower"}, color = {150, 220, 255}},
	R = {kind = "rare", cooldown = 30, items = {"blueshell", "star", "feather"}, color = {255, 220, 60}},
}
local RRR_QUESTIONBLOCK = 8 --the animated ? block tile
local RRR_ITEMQUADS = {leaf = 6, tanookisuit = 10, feather = 11, hammersuit = 14, blueshell = 16, boomerangflower = 17} --in items.png
local RRR_ITEMTABLES = {"flower", "leaf", "star", "hammersuit", "mushroom"} --where the items from the blocks end up

--arenas, 40 tiles wide and 15 high (wider screens get more floor next to the walls)
-- X wall/block, # ground, B brick, = platform, P pipe (2 wide), L lava (decoration, the pit kills)
-- S ? block above a spawn, ? ? block, R rare ? block, 1-4 spawns (the tile the player stands in)
local RRR_LAYOUTS = {
	--overworld and night overworld: two pipes and a pit in the middle
	field = {
		"X                                      X",
		"X                                      X",
		"X                                      X",
		"X                  R                   X",
		"X                                      X",
		"X       S                      S       X",
		"X              ==========              X",
		"X                                      X",
		"X       3                      4       X",
		"X S  =======  ?          ?  =======  S X",
		"X                                      X",
		"X               PP    PP               X",
		"X 1             PP    PP             2 X",
		"########################################",
		"########################################",
	},
	--underground: brick ceiling, pipes next to the ground spawns
	cave = {
		"XBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBX",
		"X                                      X",
		"X                                      X",
		"X                  R                   X",
		"X                                      X",
		"X          S                S          X",
		"X               ========               X",
		"X                                      X",
		"X          3                4          X",
		"X  S    ====== ?        ? ======    S  X", --the ? blocks stay out from under the platform (3 clear tiles over a ? block)
		"X                                      X",
		"X    PP                          PP    X",
		"X  1 PP                          PP 2  X",
		"########################################",
		"########################################",
	},
	--castle: lava pits on both sides
	castle = {
		"X                                      X",
		"X                                      X",
		"X                  R                   X",
		"X                                      X",
		"X              S        S              X",
		"X                 ====                 X", --3 clear tiles over the ? blocks under it
		"X                                      X",
		"X              3        4              X",
		"X            =====    =====            X",
		"X  S               ??               S  X",
		"X                                      X",
		"X                                      X",
		"X  1                                2  X",
		"########################################",
		"########################################",
	},
	--portal: a test chamber with a pillar splitting the floor
	lab = {
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
		"X                                      X",
		"X                                      X",
		"X                  R                   X",
		"X                                      X",
		"X         S                  S         X",
		"X              ==========              X",
		"X                                      X",
		"X         3                  4         X",
		"X  S    ===== ?          ? =====    S  X", --the ? blocks stay out from under the platform (3 clear tiles over a ? block)
		"X                  XX                  X",
		"X                  XX                  X",
		"X  1               XX               2  X",
		"########################################",
		"########################################",
	},
}

--sudden death arenas (time up with more than one player left), 25x15, without ? blocks: no power-ups
local RRR_SD_LAYOUTS = {
	field = {
		"X                       X",
		"X                       X",
		"X                       X",
		"X                       X",
		"X                       X",
		"X                       X",
		"X        =======        X",
		"X                       X",
		"X    1             2    X",
		"X  =====         =====  X",
		"X                       X",
		"X        PP   PP        X",
		"X 3      PP   PP      4 X",
		"#########################",
		"#########################",
	},
	cave = {
		"XBBBBBBBBBBBBBBBBBBBBBBBX",
		"X                       X",
		"X                       X",
		"X                       X",
		"X                       X",
		"X                       X",
		"X        =======        X",
		"X                       X",
		"X    1             2    X",
		"X  =====         =====  X",
		"X                       X",
		"X        PP   PP        X",
		"X 3      PP   PP      4 X",
		"#########################",
		"#########################",
	},
	castle = {
		"X                       X",
		"X                       X",
		"X                       X",
		"X                       X",
		"X                       X",
		"X                       X",
		"X        =======        X",
		"X                       X",
		"X    1             2    X",
		"X  =====         =====  X",
		"X                       X",
		"X                       X",
		"X 3                   4 X",
		"#########################",
		"#########################",
	},
	lab = {
		"XXXXXXXXXXXXXXXXXXXXXXXXX",
		"X                       X",
		"X                       X",
		"X                       X",
		"X                       X",
		"X                       X",
		"X        =======        X",
		"X                       X",
		"X    1             2    X",
		"X  =====         =====  X",
		"X           X           X",
		"X           X           X",
		"X 3         X         4 X",
		"#########################",
		"#########################",
	},
}

--tiles for every theme (platform: left, middle, right; pipe: top left, top right, body left, body right)
--the smb tiles are 1-132 (the last two rows of smbtiles.png are secret), the portal tiles come right after them
local RRR_GREENPIPE = {16, 17, 38, 39}
local RRR_GRAYPIPE = {14, 15, 36, 37}
local RRR_THEMES = {
	{name = "Overworld", layout = "field", spriteset = 1, background = 1, ground = 2, block = 78, brick = 7, used = 113,
		platform = {70, 71, 72}, trunk = 93, pipe = RRR_GREENPIPE, decor = "hills"},
	{name = "Underground", layout = "cave", spriteset = 2, background = 2, ground = 50, block = 111, brick = 49, used = 114,
		platform = {49, 49, 49}, pipe = RRR_GREENPIPE},
	{name = "Castle", layout = "castle", spriteset = 3, background = 2, ground = 29, block = 29, brick = 122, used = 117,
		platform = {122, 122, 122}, pipe = RRR_GRAYPIPE, lava = {107, 120}},
	{name = "Portal", layout = "lab", spriteset = 1, background = 2, ground = 140, block = 154, brick = 141, used = 113,
		platform = {141, 141, 141}, pipe = RRR_GRAYPIPE, decor = "lab"},
	{name = "Night Overworld", layout = "field", spriteset = 3, background = 2, ground = 92, block = 29, brick = 122, used = 117,
		platform = {89, 90, 91}, pipe = RRR_GRAYPIPE, decor = "clouds"},
}

--a music pack is a folder in sounds/minigames, its pack.json gives its name, its place in the list and the songs' names:
--  {"name": "Kirby VRC6 Music", "order": 1, "songs": [["boss", "Boss"], ["skybattle", "Battle Across The Sky"]]}
--(songs are [file name without .ogg, name in the list], in the order they're listed; everything is optional:
--a folder without pack.json, or a song it doesn't list, is named after its folder or file)
local RRR_PACKFILE = "pack.json"
local RRR_BUILTINMUSIC = {"overworld", "underground", "castle"}

--the star theme and the music while the battle runs are put back once it's over
local rrr_saved = nil
local rrr_saved_split = nil --the split screen nitpick, it's always on during a battle

----------------
--  HELPERS  --
----------------

--where the blinking after a hit, a power-up or a respawn starts: 2.2 instead of the game's 1.2
--(invincibletime - invincibletime2), so it lasts 1 second instead of 2
local function rrr_invinciblestart()
	return invincibletime - invincibletime2 + 1
end

local function rrr_state()
	local S = minigamestate
	if minigameplaying and gamestate == "game" and S and S.battle and minigamecurrent and minigamecurrent.id == RRR_ID then
		return S
	end
	return nil
end

local function rrr_center(p)
	return p.x + p.width/2
end

local function rrr_feet(p)
	return p.y + p.height
end

local function rrr_clamp(v, a, b)
	return math.max(a, math.min(b, v))
end

local function rrr_overlap(a, b, shrink)
	shrink = shrink or 0
	return a.x+shrink < b.x+b.width-shrink and b.x+shrink < a.x+a.width-shrink
		and a.y+shrink < b.y+b.height-shrink and b.y+shrink < a.y+a.height-shrink
end

local function rrr_solid(x, y)
	if x < 1 or x > mapwidth then
		return true
	end
	if y < 1 or y > mapheight then
		return false
	end
	local t = tilequads[map[x][y][1]]
	return t ~= nil and t.collision == true
end

local function rrr_fileexists(path)
	return love.filesystem.getInfo(path) ~= nil
end

local function rrr_prettyname(s)
	s = s:gsub("[_%-]", " ")
	return (s:gsub("(%a)([%w']*)", function(first, rest)
		return first:upper() .. rest
	end))
end

--"x-intro.ogg", "x-fast.ogg", starmusic.ogg and battleclear.ogg belong to a song or a pack, they aren't songs themselves
local function rrr_issong(file)
	if file:lower():sub(-4) ~= ".ogg" then
		return false
	end
	local base = file:sub(1, -5):lower()
	if base:match("%-intro$") or base:match("%-fast$") or base:match("%-fastintro$") or base:match("%-introfast$") or base == "starmusic" or base:match("^starmusic%-") or base == "battleclear" then
		return false
	end
	return true
end

local function rrr_alive(S, i)
	local p = objects["player"][i]
	return p and not p.dead and not S.out[i]
end

--deadly to touch: star power, or a blue shell at full speed
local function rrr_dangerous(p)
	if p.starred or p.statue then --a tanooki statue can't be hurt, so it hurts whoever touches it
		return true
	end
	if p.size == 14 then
		local top = maxrunspeed
		if p.characterdata and p.characterdata.maxrunspeed then
			top = p.characterdata.maxrunspeed
		end
		return p.blueshelled or math.abs(p.speedx) >= top - 0.05
	end
	return false
end

--can't be hurt right now (star, tanooki statue, blinking after a hit or a respawn)
local function rrr_protected(p)
	return p.starred or p.statue or p.invincible or p.dead or not p.active
end

-------------
--  MUSIC  --
-------------

--pack.json keys that pick the pack's star theme and win fanfare, and the files a pack without pack.json uses
local RRR_STARKEY, RRR_CLEARKEY = "Starman Theme", "Battle Clear"
local RRR_PACKEXTRAS = {RRR_STARKEY, RRR_CLEARKEY}
local RRR_PACKEXTRADEFAULTS = {[RRR_STARKEY] = "starmusic.ogg", [RRR_CLEARKEY] = "battleclear.ogg"}

--a pack's pack.json (nil when there isn't one or it can't be read)
local function rrr_readpack(folderpath)
	local path = folderpath .. "/" .. RRR_PACKFILE
	if not rrr_fileexists(path) then
		return nil
	end
	local text = love.filesystem.read(path)
	JSONcrashgame = false --a broken pack.json just gets ignored
	local ok, data = pcall(function() return JSON:decode(text) end)
	JSONcrashgame = true
	if not (ok and type(data) == "table") then
		print("rival rumble royale: couldn't read " .. path)
		return nil
	end
	local pack = {}
	if type(data.name) == "string" then
		pack.name = data.name
	end
	if type(data.order) == "number" then
		pack.order = data.order
	end
	--the star theme and the win fanfare of the pack, checked when the music list is made (rrr_packextra)
	pack.extras = {}
	for _, key in ipairs(RRR_PACKEXTRAS) do
		for k, v in pairs(data) do
			if type(k) == "string" and k:lower() == key:lower() then --"starman theme" works too
				pack.extras[key] = v
			end
		end
	end
	pack.songs = {}
	if type(data.songs) == "table" then
		for _, song in ipairs(data.songs) do
			if type(song) == "table" and song[1] and type(song[2]) == "string" then
				table.insert(pack.songs, {tostring(song[1]), song[2]})
			end
		end
	end
	return pack
end

--the pack's star theme or win fanfare (key is RRR_STARKEY or RRR_CLEARKEY): path and file name, or nil for the built-in one.
--1. the song pack.json names ("Starman Theme": "my star song"), 2. starmusic.ogg or battleclear.ogg in the pack, 3. the built-in one
local function rrr_packextra(folderpath, pack, key)
	local value = pack and pack.extras[key]
	if type(value) == "string" and value ~= "" then
		local file = value
		if file:lower():sub(-4) ~= ".ogg" then
			file = file .. ".ogg"
		end
		if rrr_fileexists(folderpath .. "/" .. file) then
			return folderpath .. "/" .. file, file
		end
	end
	if value ~= nil then
		print("rival rumble royale: \"" .. key .. "\" in " .. folderpath .. "/" .. RRR_PACKFILE .. " isn't a song in the pack")
	end
	local file = RRR_PACKEXTRADEFAULTS[key]
	if rrr_fileexists(folderpath .. "/" .. file) then
		return folderpath .. "/" .. file, file
	end
	return nil
end

--every song for the battle music dropdown: {label, path, pack folder, star theme path, win fanfare path}
function rrr_musiclist()
	love.filesystem.createDirectory(RRR_SAVE_MUSIC_FOLDER) --so it's there to put music in
	local list = {}
	local labels = {} --a label already in the list (the save folder's song wins)
	local function addsong(entry)
		local key = entry.label:lower()
		if not labels[key] then
			labels[key] = true
			table.insert(list, entry)
		end
	end
	local function isfolder(path)
		local info = love.filesystem.getInfo(path)
		return info and info.type == "directory"
	end

	for _, name in ipairs(RRR_BUILTINMUSIC) do
		--a song of the same name in a music folder replaces the built-in one
		local path = "sounds/" .. name .. ".ogg"
		for _, root in ipairs(RRR_MUSIC_FOLDERS) do
			if rrr_fileexists(root .. "/" .. name .. ".ogg") then
				path = root .. "/" .. name .. ".ogg"
				break
			end
		end
		addsong({label = rrr_prettyname(name), path = path})
	end

	--loose songs right in the music folders, and the pack folders in them
	local packs = {}
	for rootindex, root in ipairs(RRR_MUSIC_FOLDERS) do
		if isfolder(root) then
			local items = love.filesystem.getDirectoryItems(root)
			table.sort(items, function(a, b) return a:lower() < b:lower() end)
			for _, item in ipairs(items) do
				local path = root .. "/" .. item
				if isfolder(path) then
					table.insert(packs, {folder = item, folderpath = path, pack = rrr_readpack(path), root = rootindex})
				elseif rrr_issong(item) and not tablecontains(RRR_BUILTINMUSIC, item:sub(1, -5):lower()) then
					addsong({label = rrr_prettyname(item:sub(1, -5)), path = path})
				end
			end
		end
	end

	--the name the pack has in the list ("name" in pack.json, or the folder's name)
	for _, entry in ipairs(packs) do
		entry.packname = rrr_prettyname(entry.folder)
		if entry.pack and entry.pack.name then
			entry.packname = entry.pack.name
		end
	end
	--packs with an "order" first (lowest first), then the rest. Packs with the same order (or no order) are sorted
	--alphabetically by that name (a pack in the save folder comes before one with the same name in the game, so its songs win)
	table.sort(packs, function(a, b)
		local ao, bo = a.pack and a.pack.order, b.pack and b.pack.order
		if ao and bo and ao ~= bo then
			return ao < bo
		elseif ao and not bo then
			return true
		elseif bo and not ao then
			return false
		end
		local an, bn = a.packname:lower(), b.packname:lower()
		if an ~= bn then
			return an < bn
		end
		if a.folder:lower() ~= b.folder:lower() then
			return a.folder:lower() < b.folder:lower()
		end
		return a.root < b.root
	end)

	for _, entry in ipairs(packs) do
		local folderpath = entry.folderpath
		local packname = entry.packname
		local used = {}
		--the star theme and win fanfare aren't songs of the pack
		local star, starfile = rrr_packextra(folderpath, entry.pack, RRR_STARKEY)
		local clear, clearfile = rrr_packextra(folderpath, entry.pack, RRR_CLEARKEY)
		if starfile then
			used[starfile:lower()] = true
		end
		if clearfile then
			used[clearfile:lower()] = true
		end
		local function add(song)
			song.star, song.clear = star, clear
			addsong(song)
		end
		if entry.pack then
			for _, song in ipairs(entry.pack.songs or {}) do
				local file = tostring(song[1]) .. ".ogg"
				if song[2] and rrr_fileexists(folderpath .. "/" .. file) and not used[file:lower()] then
					used[file:lower()] = true
					add({label = packname .. "- " .. song[2], path = folderpath .. "/" .. file, pack = folderpath})
				end
			end
		end
		local files = love.filesystem.getDirectoryItems(folderpath)
		table.sort(files, function(a, b) return a:lower() < b:lower() end)
		for _, file in ipairs(files) do
			if rrr_issong(file) and not used[file:lower()] then
				add({label = packname .. "- " .. rrr_prettyname(file:sub(1, -5)), path = folderpath .. "/" .. file, pack = folderpath})
			end
		end
	end
	return list
end

local function rrr_musiclabels()
	local labels = {}
	for i, entry in ipairs(rrr_musiclist()) do
		labels[i] = entry.label
	end
	return labels
end

local function rrr_newsource(path, looping)
	local ok, source = pcall(love.audio.newSource, path, "stream")
	if not ok then
		print("rival rumble royale: couldn't load " .. tostring(path))
		return nil
	end
	source:setLooping(looping == true)
	source:setPitch(music.pitch or 1)
	return source
end

--put back the star theme a music pack replaced
local rrrx = {} --the newer helpers (a table: the file can only have 200 locals at once)
rrrx.fakefast = nil --the song a made-up fast version was made for (see rrrx.ensurefastmusic)

local function rrr_restoremusic()
	if rrrx.fakefast then
		music:unfakefast(rrrx.fakefast)
		rrrx.fakefast = nil
	end
	if rrr_saved then
		if rrr_saved.star then
			music.loaded["starmusic"]:stop()
			if music.loaded["starmusic-intro"] then
				music.loaded["starmusic-intro"]:stop()
			end
			if music.loaded["starmusic-fast"] then
				music.loaded["starmusic-fast"]:stop()
			end
		end
		if rrr_saved.star then
			music.loaded["starmusic"] = rrr_saved.star
			music.loaded["starmusic-intro"] = rrr_saved.starintro
			music.loaded["starmusic-fast"] = rrr_saved.starfast
			music.pitchmul["starmusic-fast"] = rrr_saved.starfastpitch
		end
		rrr_saved = nil
	end
end

local function rrr_setupmusic(S, entry)
	rrr_restoremusic()
	S.clearpath = RRR_DEFAULT_CLEAR
	if not (entry and rrr_fileexists(entry.path)) then
		return
	end
	custommusics = custommusics or {}
	custommusics["battle"] = entry.path
	music:load(entry.path) --also loads entry-intro.ogg
	musici = 7
	custommusic = false
	custommusici = "battle"

	--the pack's star theme replaces the built-in one (with an intro if it has one)
	if entry.star then
		local source = rrr_newsource(entry.star, true)
		if source then
			rrr_saved = {star = music.loaded["starmusic"], starintro = music.loaded["starmusic-intro"],
				starfast = music.loaded["starmusic-fast"], starfastpitch = music.pitchmul["starmusic-fast"]}
			music.loaded["starmusic"] = source
			music.loaded["starmusic-intro"] = nil
			local intro = music:variant(entry.star, "-intro")
			if rrr_fileexists(intro) then
				music.loaded["starmusic-intro"] = rrr_newsource(intro, false)
			end
			--the fast star theme (low time): the pack's own -fast version, or its star theme sped up
			local fast = music:variant(entry.star, "-fast")
			local fastsource = nil
			if rrr_fileexists(fast) then
				fastsource = rrr_newsource(fast, true)
			end
			if fastsource then
				music:stop("starmusic-fast")
				music.loaded["starmusic-fast"] = fastsource
				music.pitchmul["starmusic-fast"] = nil
			else
				music:fakefaststar(entry.star)
			end
		end
	end
	--the pack's battle clear theme, played in the arena when the battle ends
	if entry.clear then
		S.clearpath = entry.clear
	end
end

--the battle clear theme plays once, with its intro first if there is one
local function rrr_startclear(S)
	local C = {t = 0}
	local intropath = S.clearpath:sub(1, -5) .. "-intro.ogg"
	if rrr_fileexists(intropath) then
		C.intro = rrr_newsource(intropath, false)
	end
	C.main = rrr_newsource(S.clearpath, false)
	if C.intro then
		playsound(C.intro)
		C.introplaying = true
	elseif C.main then
		playsound(C.main)
	end
	S.clear = C
end

--true once the clear theme is done
local function rrr_updateclear(S, dt)
	local C = S.clear
	if not C then
		return true
	end
	C.t = C.t + dt
	if C.introplaying then
		if not C.intro:isPlaying() then
			C.introplaying = false
			if C.main then
				playsound(C.main)
			end
		end
		return false
	end
	if C.t > RRR_CLEAR_MAX or not soundenabled then
		return true
	end
	return not (C.main and C.main:isPlaying())
end

local function rrr_stopclear(S)
	local C = S and S.clear
	if C then
		if C.intro then C.intro:stop() end
		if C.main then C.main:stop() end
	end
end

-----------
--  MAP  --
-----------

--wider screens: the arena gets more floor next to the walls (columns 2 and the second to last get repeated)
local function rrr_padlayout(rows, w)
	local extra = math.max(0, w - #rows[1])
	if extra == 0 then
		return rows
	end
	local left = math.floor(extra/2)
	local right = extra - left
	local out = {}
	for i, r in ipairs(rows) do
		local l = r:sub(2, 2):gsub("[1234S?R]", " ")
		local rr = r:sub(-2, -2):gsub("[1234S?R]", " ")
		out[i] = r:sub(1, 1) .. string.rep(l, left) .. r:sub(2, -2) .. string.rep(rr, right) .. r:sub(-1, -1)
	end
	return out
end

local function rrr_settile(x, y, id)
	if map[x] and map[x][y] then
		map[x][y][1] = id
	end
end

local function rrr_char(rows, x, y)
	local r = rows[y]
	if not r or x < 1 or x > #r then
		return " "
	end
	return r:sub(x, x)
end

--hills, bushes and clouds where nothing else is
local function rrr_decorate(S, rows, theme)
	local function free(x, y)
		return map[x] and map[x][y] and map[x][y][1] == 1 and rrr_char(rows, x, y) == " "
	end
	local function place(shape, x, bottomy)
		for r = 1, #shape do
			for c = 1, #shape[r] do
				if shape[r][c] and not free(x+c-1, bottomy-(#shape-r)) then
					return false
				end
			end
		end
		for r = 1, #shape do
			for c = 1, #shape[r] do
				if shape[r][c] then
					rrr_settile(x+c-1, bottomy-(#shape-r), shape[r][c])
				end
			end
		end
		return true
	end

	if theme.decor == "hills" then
		--trunks under the low treetops
		for y = 1, mapheight do
			for x = 1, mapwidth do
				if rrr_char(rows, x, y) == "=" and rrr_char(rows, x-1, y) == "=" and rrr_char(rows, x+1, y) == "=" and y >= mapheight - 6 then
					local ty = y+1
					while ty <= mapheight and free(x, ty) do
						ty = ty + 1
					end
					if ty <= mapheight and rrr_solid(x, ty) then
						for yy = y+1, ty-1 do
							rrr_settile(x, yy, theme.trunk)
						end
					end
				end
			end
		end
		--things on the ground (the row 2 over the bottom stands on the ground)
		local shapes = {
			{{false, 3, false}, {24, 25, 26}},
			{{4, 5, 6}},
			{{4, 5, 5, 6}},
			{{false, false, 3, false, false}, {false, 24, 25, 26, false}, {24, 25, 27, 28, 26}},
		}
		local x = 2
		while x < mapwidth do
			local shape = randomitem(shapes)
			if place(shape, x, mapheight - 2) then
				x = x + #shape[#shape] + math.random(1, 3)
			else
				x = x + 1
			end
		end
	end
	if theme.decor == "hills" or theme.decor == "clouds" then
		local x = math.random(2, 5)
		while x < mapwidth-4 do
			local cloudrow = math.random(3, mapheight - 8)
			local cloudrow = math.random(3, mapheight - 8)
			local middle = math.random(1, 2)
			local top, bottom = {33}, {55}
			for i = 1, middle do
				top[#top+1] = 34
				bottom[#bottom+1] = 56
			end
			top[#top+1] = 35
			bottom[#bottom+1] = 57
			if place({top, bottom}, x, cloudrow) then
				x = x + #top + math.random(3, 7)
			else
				x = x + 2
			end
		end
	end
	if theme.decor == "lab" then
		--windows in the walls of the test chamber
		for _, x in ipairs({3, 7, mapwidth-8, mapwidth-4}) do
			place({{147, 148}}, x, 3)
		end
	end
end

--read the layout into the map, the ? blocks and the spawns
local function rrr_buildmap(S, theme, layout)
	local rows = rrr_padlayout(layout, width)
	mapwidth = #rows[1]
	originalmapwidth = mapwidth
	mapheight = #rows
	map = {}
	for x = 1, mapwidth do
		map[x] = {}
		for y = 1, mapheight do
			map[x][y] = {1}
			map[x][y]["gels"] = {}
		end
	end

	S.blocks = {}
	S.blockat = {}
	S.spawns = {}
	for y = 1, mapheight do
		for x = 1, mapwidth do
			local c = rrr_char(rows, x, y)
			if c == "#" then
				rrr_settile(x, y, theme.ground)
			elseif c == "X" then
				rrr_settile(x, y, theme.block)
			elseif c == "B" then
				rrr_settile(x, y, theme.brick)
			elseif c == "=" then
				local id = theme.platform[2]
				if rrr_char(rows, x-1, y) ~= "=" then
					id = theme.platform[1]
				elseif rrr_char(rows, x+1, y) ~= "=" then
					id = theme.platform[3]
				end
				rrr_settile(x, y, id)
			elseif c == "P" then
				--pipes are always 2 wide: count from the left end of the run
				local runstart = x
				while rrr_char(rows, runstart-1, y) == "P" do
					runstart = runstart - 1
				end
				local left = (x-runstart)%2 == 0
				local top = rrr_char(rows, x, y-1) ~= "P"
				local id
				if top and left then
					id = theme.pipe[1]
				elseif top then
					id = theme.pipe[2]
				elseif left then
					id = theme.pipe[3]
				else
					id = theme.pipe[4]
				end
				rrr_settile(x, y, id)
			elseif c == "L" then
				if theme.lava then
					if rrr_char(rows, x, y-1) == "L" then
						rrr_settile(x, y, theme.lava[2])
					else
						rrr_settile(x, y, theme.lava[1])
					end
				end
			elseif RRR_BLOCKS[c] then
				rrr_settile(x, y, RRR_QUESTIONBLOCK)
				local def = RRR_BLOCKS[c]
				local b = {x = x, y = y, def = def, cooldown = 0, roulette = math.random(#def.items), roulettet = math.random()*RRR_ROULETTE_TIME}
				table.insert(S.blocks, b)
				S.blockat[x] = S.blockat[x] or {}
				S.blockat[x][y] = b
			elseif c:match("%d") then
				S.spawns[tonumber(c)] = {x = x, y = y}
			end
		end
	end
	rrr_decorate(S, rows, theme)

	--castle: rising water at the bottom, covering ~75% of the ground area
	--y is half a tile below the top of the overall ground (the topmost # row)
	if theme.layout == "castle" then
		local groundtop = mapheight - 1 --first ground row (1-based)
		local watery = groundtop - 0.5 --half a tile below the top surface
		local waterh = 3 --covers the ground rows and a bit more
		local waterw = mapwidth - 2 --inside the walls
		local r = {nil, nil, waterw .. "|" .. waterh .. "|1|" .. (watery - (groundtop - 1)) .. "|lava|0.75|0|false|0"}
		--format: w|h|rx|ry|type|fill|fillspeed|oscillate|wait
		--rx,ry relative to the entity's cox,coy; place the entity at left wall +1, groundtop
		if not objects["risingwater"] then
			objects["risingwater"] = {}
		end
		table.insert(objects["risingwater"], risingwater:new(2, groundtop, r))
	end

	return rows
end

-------------------
--  NAVIGATION  --
-------------------
--bots walk on "segments": runs of tiles a player can stand in (air with something solid under it)

local RRR_JUMP_UP = 4 --how high a bot jumps (tiles)
local RRR_JUMP_GAP = 3 --how wide a gap a bot jumps over

local function rrr_segat(S, x, row)
	local column = S.segat[x]
	if column then
		return column[row]
	end
	return nil
end

--the segment a player stands on, nil in the air
local function rrr_playerseg(S, p)
	if p.falling or p.jumping then
		return nil
	end
	local row = math.floor(rrr_feet(p) + 0.5)
	return rrr_segat(S, math.floor(rrr_center(p))+1, row) or rrr_segat(S, math.floor(p.x+0.05)+1, row) or rrr_segat(S, math.floor(p.x+p.width-0.05)+1, row)
end

--the first surface at or under a point (x, y in tiles)
local function rrr_segbelow(S, x, y)
	local column = math.floor(x)+1
	for row = math.max(1, math.ceil(y-0.05)), mapheight do
		local seg = rrr_segat(S, column, row)
		if seg then
			return seg
		end
	end
	return nil
end

--where you land when you fall down a column
local function rrr_landing(S, column, fromrow)
	for row = fromrow, mapheight do
		if rrr_solid(column, row) then
			return nil
		end
		local seg = rrr_segat(S, column, row)
		if seg then
			return seg
		end
	end
	return nil
end

local function rrr_makeedge(S, A, B)
	local rise = A.y - B.y
	local gap, side = -1, 0
	if B.x1 > A.x2 then
		gap, side = B.x1 - A.x2 - 1, 1
	elseif B.x2 < A.x1 then
		gap, side = A.x1 - B.x2 - 1, -1
	end
	local edgex = A.x2
	if side < 0 then
		edgex = A.x1
	end

	if rise > 0 then
		if rise > RRR_JUMP_UP then
			return nil
		end
		if gap >= 0 then
			if gap > RRR_JUMP_GAP then
				return nil
			end
			return {kind = "jump", takeoffs = {{x = edgex, dir = side}}}
		end
		--B is right above A: jump from next to it, not from under it
		local takeoffs = {}
		if B.x1-1 >= A.x1 then
			table.insert(takeoffs, {x = B.x1-1, dir = 1, under = true})
		end
		if B.x2+1 <= A.x2 then
			table.insert(takeoffs, {x = B.x2+1, dir = -1, under = true})
		end
		if #takeoffs == 0 then
			return nil
		end
		return {kind = "jump", takeoffs = takeoffs}
	elseif rise == 0 then
		if gap < 0 or gap > RRR_JUMP_GAP+1 then
			return nil
		end
		return {kind = "jump", takeoffs = {{x = edgex, dir = side}}}
	end

	--B is lower: walk off the side it sticks out of, or jump over to it
	local sides = {}
	if B.x2 > A.x2 then
		table.insert(sides, 1)
	end
	if B.x1 < A.x1 then
		table.insert(sides, -1)
	end
	for _, d in ipairs(sides) do
		local column = A.x2+1
		local edge = A.x2
		if d < 0 then
			column = A.x1-1
			edge = A.x1
		end
		if not rrr_solid(column, A.y) then
			--a drop needs room to land: walking off keeps some speed
			local room = B.x2 - column
			if d < 0 then
				room = column - B.x1
			end
			if rrr_landing(S, column, A.y) == B and room >= 2 then
				return {kind = "drop", x = column, dir = d}
			end
			if gap >= 0 and gap <= RRR_JUMP_GAP and d == side then
				local near = B.x1
				if d < 0 then
					near = B.x2
				end
				if rrr_landing(S, near, A.y) == B then
					return {kind = "jump", takeoffs = {{x = edge, dir = d}}}
				end
			end
		end
	end
	return nil
end

local function rrr_buildnavigation(S)
	S.segs = {}
	S.segat = {}
	for x = 1, mapwidth do
		S.segat[x] = {}
	end
	for row = 1, mapheight-1 do
		local current = nil
		for x = 1, mapwidth do
			local standable = (not rrr_solid(x, row)) and rrr_solid(x, row+1)
			if standable then
				if current then
					current.x2 = x
				else
					current = {y = row, x1 = x, x2 = x, id = #S.segs+1}
					table.insert(S.segs, current)
				end
				S.segat[x][row] = current
			else
				current = nil
			end
		end
	end
	S.edges = {}
	for _, A in ipairs(S.segs) do
		S.edges[A] = {}
		for _, B in ipairs(S.segs) do
			if A ~= B then
				local e = rrr_makeedge(S, A, B)
				if e then
					S.edges[A][B] = e
				end
			end
		end
	end
	--the surface under every ? block, where you jump from to hit it
	for _, b in ipairs(S.blocks) do
		b.seg = rrr_segbelow(S, b.x-0.5, b.y+0.5)
	end
end

--shortest route (in jumps) between two segments, false when there is none
local function rrr_path(S, from, to)
	if from == to then
		return {from}
	end
	local prev = {[from] = from}
	local queue = {from}
	local qi = 1
	while qi <= #queue do
		local a = queue[qi]
		qi = qi + 1
		for _, b in ipairs(S.segs) do
			--one tile wide spots (on top of a ? block) are too easy to miss on the way somewhere else
			if S.edges[a][b] and not prev[b] and (b.x2 > b.x1 or b == to) then
				prev[b] = a
				if b == to then
					local path = {b}
					while path[1] ~= from do
						table.insert(path, 1, prev[path[1]])
					end
					return path
				end
				table.insert(queue, b)
			end
		end
	end
	return false
end

-------------------------
--  TERRAIN GENERATOR  --
-------------------------
--every battle gets a new arena in its theme's style, mirrored so both sides are fair. The rules stay the same as the
--fixed arenas: a ? block 3 tiles over every spawn, a ? block on each side, the rare block over the middle platform,
--and every spawn and block can be reached (checked with the bots' own routes, so they can play it too)

local RRR_GEN_W = 40
local RRR_MAPHEIGHT = 30 --every arena is 30 tiles high
local RRR_GEN_TRIES = 40 --after this many arenas that don't pass the check, the fixed one for the theme is used

--a new layout (rows of characters like RRR_LAYOUTS), nil when the dice gave something that can't work
--from the bottom up: the ground with the first two spawns, the low platforms with the other two, then platforms
--going up in turns (the middle one, one on each side, the middle one...) with the rare block over the highest one
local function rrr_generatelayout(theme)
	local W, H = RRR_GEN_W, RRR_MAPHEIGHT
	local G = H - 2 --the row a player on the ground stands in (the ground is the 2 rows under it)
	local style = theme.layout
	local grid = {}
	for y = 1, H do
		grid[y] = {}
		for x = 1, W do
			grid[y][x] = " "
		end
	end
	local function get(x, y)
		if x < 1 or x > W or y < 1 or y > H then
			return "X"
		end
		return grid[y][x]
	end
	--everything goes on the left half and gets mirrored to the right
	local function setpair(x, y, left, right)
		if x >= 1 and x <= W and y >= 1 and y <= H then
			grid[y][x] = left
			grid[y][W+1-x] = right
		end
	end
	local function set(x, y, c)
		setpair(x, y, c, c)
	end
	local function free(x1, y1, x2, y2)
		for y = y1, y2 do
			for x = x1, x2 do
				if get(x, y) ~= " " then
					return false
				end
			end
		end
		return true
	end
	--a platform in the middle, from the center out to hw tiles on each side
	local function middleplatform(row, hw)
		for x = W/2 + 1 - hw, W/2 do
			set(x, row, "=")
		end
	end

	--ground and walls (and a ceiling underground and in the test chamber)
	for x = 1, W/2 do
		set(x, G+1, "#")
		set(x, G+2, "#")
		if style == "cave" then
			set(x, 1, "B")
		elseif style == "lab" then
			set(x, 1, "X")
		end
	end
	for y = 1, G do
		set(1, y, "X")
	end

	--the bottom spawns (p3 and p4) on the ground near the walls
	local s1 = math.random(3, 5)
	setpair(s1, G, "3", "4")
	set(s1, G-3, "S")

	--lava pits in the castle, the low platform comes after them (a platform over a pit's edge would bonk
	--anyone jumping over the pit into the lava)
	local pitfrom, pitto = 0, -1
	local platformfrom, platformto, platformmax = s1 + 2, 9, 15
	if style == "castle" then
		pitfrom = s1 + math.random(3, 4)
		pitto = pitfrom + math.random(2, 3) - 1
		for x = pitfrom, pitto do
			set(x, G+1, "L")
			set(x, G+2, "L")
		end
		platformfrom, platformto, platformmax = pitto + 3, pitto + 4, 17
	end
	--near a pit's edge, where players jump from (a block there would bonk them into the lava)
	local function nearpit(x)
		return x >= pitfrom - 2 and x <= pitto + 2
	end

	--the low platform with a ? block over it
	local lowrow = G - math.random(2, 3) --3 or 4 tiles over the ground
	local x1 = math.random(platformfrom, platformto)
	local x2 = math.min(x1 + math.random(4, 7) - 1, platformmax)
	for x = x1, x2 do
		set(x, lowrow, "=")
	end
	local pc = math.floor((x1 + x2)/2)
	set(pc, lowrow-4, "?")

	--a pipe on the ground (overworld and underground), a pillar in the middle of the test chamber
	if style == "field" or style == "cave" then
		local h = math.random(1, 2)
		local spots = {}
		for x = 2, 18 do
			local clear = free(x, G+1-h, x+1, G) and math.abs(x - s1) > 1 and math.abs(x+1 - s1) > 1
			if clear and (x+1 < x1 - 1 or x > x2 + 1) then
				table.insert(spots, x)
			end
		end
		if #spots > 0 then
			local x = randomitem(spots)
			for y = G+1-h, G do
				set(x, y, "P")
				set(x+1, y, "P")
			end
		end
	elseif style == "lab" then
		for y = G+1 - math.random(2, 3), G do
			set(W/2, y, "X")
		end
	end

	--the first middle platform, 3 tiles over the low platform and close enough to jump to
	local row = lowrow - 3
	local hwmin = math.max(3, 17 - x2) --the gap from the low platform is at most 3 tiles
	local hwmax = math.min(7, 19 - pc) --and it can't be under the ? block over the low platform
	if hwmin > hwmax then
		return nil
	end
	local hw = math.random(hwmin, hwmax)
	middleplatform(row, hw)

	--a ledge on the wall now and then
	if math.random() < 0.5 then
		local lx2 = 1 + math.random(2, 4)
		if lx2 < pc - 1 and x1 - lx2 - 1 <= 3 and free(2, row-2, lx2, row) then
			for x = 2, lx2 do
				set(x, row, "=")
			end
		end
	end

	--more platforms going up: one on each side, then the middle again (3 or 4 tiles up each time, 1 to 3 tiles
	--across), as long as there's room for both and the rare block over the last one
	local topside --the highest side platforms, the top spawns (p1 and p2) go there
	while row - 8 - 3 >= 3 do
		--the side platforms, out from the middle one's end
		local siderow = row - math.random(3, 4)
		local sx2 = W/2 - hw - math.random(1, 3)
		local sx1 = math.max(2, sx2 - math.random(3, 6) + 1)
		if sx2 < sx1 + 1 then
			break
		end
		for x = sx1, sx2 do
			set(x, siderow, "=")
		end
		topside = {x1 = sx1, x2 = sx2, row = siderow}
		--the next middle platform, out to within 1 to 3 tiles of the side ones
		local nextrow = siderow - math.random(3, 4)
		local nexthw = W/2 - sx2 - math.random(1, 3)
		if nexthw < 2 then
			return nil
		end
		nexthw = math.min(nexthw, 7)
		row, hw = nextrow, nexthw
		middleplatform(row, hw)
	end
	grid[row-3][W/2] = "R"

	--the top spawns, with their ? block over them
	if not topside then
		return nil
	end
	local sc = math.floor((topside.x1 + topside.x2)/2)
	if not free(sc, topside.row-4, sc, topside.row-1) then
		return nil
	end
	setpair(sc, topside.row-1, "1", "2")
	set(sc, topside.row-4, "S")

	--a ? block on each side, hit from the ground
	local spots = {}
	for x = math.max(x2 + 2, s1 + 2), W/2 - 1 do
		if not nearpit(x) and free(x, lowrow-1, x, G) and free(x-1, lowrow, x+1, lowrow) then
			table.insert(spots, x)
		end
	end
	if #spots == 0 then
		return nil
	end
	set(randomitem(spots), lowrow, "?")

	--3 clear tiles over every ? block: with a platform any closer, a bot jumping from on top of the block
	--gets pushed into the tiles and through the wall
	for y = 1, H do
		for x = 1, W do
			if RRR_BLOCKS[grid[y][x]] then
				for d = 1, 3 do
					local c = get(x, y-d)
					if c ~= " " and not c:match("%d") then
						return nil
					end
				end
			end
		end
	end

	local rows = {}
	for y = 1, H do
		rows[y] = table.concat(grid[y])
	end
	return rows
end

--the fixed arenas are 15 high: 15 empty rows (with the walls) go on top, under the ceiling if there is one.
--their ground spawns are 1 and 2, those become 3 and 4 (p1 and p2 get the higher ones)
local RRR_SPAWNSWAP = {["1"] = "3", ["2"] = "4", ["3"] = "1", ["4"] = "2"}
local function rrr_tallfixedlayout(layout)
	local rows = {layout[1]}
	local empty = "X" .. string.rep(" ", #layout[1] - 2) .. "X"
	for i = 1, RRR_MAPHEIGHT - #layout do
		table.insert(rows, empty)
	end
	for i = 2, #layout do
		table.insert(rows, (layout[i]:gsub("[1234]", RRR_SPAWNSWAP)))
	end
	return rows
end

--can everyone get everywhere? every spawn stands on something, every ? block can be hit from below,
--and there's a route (for the bots too) from the first spawn to every spawn and every block and back
local function rrr_arenaok(S)
	local spawnsegs = {}
	for i = 1, RRR_PLAYERS do
		local spawn = S.spawns[i]
		local seg = spawn and rrr_segat(S, spawn.x, spawn.y)
		if not seg then
			return false
		end
		spawnsegs[i] = seg
	end
	local targets = {}
	for _, seg in ipairs(spawnsegs) do
		table.insert(targets, seg)
	end
	for _, b in ipairs(S.blocks) do
		if not b.seg or b.seg.y - b.y < 2 or b.seg.y - b.y > 4 then
			return false
		end
		table.insert(targets, b.seg)
	end
	for _, target in ipairs(targets) do
		if not rrr_path(S, spawnsegs[1], target) or not rrr_path(S, target, spawnsegs[1]) then
			return false
		end
	end
	--3 clear tiles over every ? block, on the map as it's built (the generator checks its layout too)
	for _, b in ipairs(S.blocks) do
		for d = 1, 3 do
			if rrr_solid(b.x, b.y - d) then
				return false
			end
		end
	end
	return true
end

--------------
--  BLOCKS  --
--------------

--the image and quad an item is drawn with (nil when the sprite isn't there)
local function rrr_itemicon(name)
	local ss = spriteset or 1
	local img, quads, index = itemsimg, itemsquad, RRR_ITEMQUADS[name]
	if name == "fireflower" then
		img, quads, index = flowerimg, flowerquad, 1
	elseif name == "superballflower" then
		img, quads, index = superballflowerimg, coinblockquads, coinframe or 1
	elseif name == "star" then
		img, quads, index = starimg, starquad, 1
	end
	if not (img and quads and quads[ss] and index) then
		return nil
	end
	return img, quads[ss][index]
end

--hit from below (or by a tail): bounce, and give out the item on show when the block is ready
local function rrr_hitblock(S, x, y, hitter)
	local b = S.blockat[x] and S.blockat[x][y]
	local breakable = inmap(x, y) and tilequads[map[x][y][1]] and tilequads[map[x][y][1]].breakable
	if not (b or breakable) then
		return false
	end
	--a new bump replaces the one that's still going on this block: an item that one was going to let out
	--(when its bump is done) comes out right away instead of getting lost
	local previous = getblockbounce(x, y)
	if previous and previous.content then
		item(previous.content, previous.x, previous.y, previous.content2)
		previous.content = false
	end
	local bounce = createblockbounce(x, y)
	bounce.timer = 0.000000001
	bounce.x = x
	bounce.y = y
	bounce.content = false
	playsound(blockhitsound)
	if b and b.cooldown <= 0 and not S.over then
		--the item comes out once the bounce is done
		bounce.content = b.def.items[b.roulette]
		bounce.content2 = 2 --as if a big player hit it, so it's never a mushroom
		playsound(mushroomappearsound)
		if not RemoveCooldowns then --removecooldowns nitpick: the block is ready again straight away
			b.cooldown = b.def.cooldown
			map[x][y][1] = S.theme.used
		end
		--a bot that got something out of a block leaves it alone for the block's cooldown (it would keep hitting the
		--same block forever with the removecooldowns nitpick) and goes for what came out instead
		local bot = type(hitter) == "table" and hitter.playernumber and S.bots[hitter.playernumber]
		if bot then
			bot.ignore[b] = S.time + b.def.cooldown
			bot.think = 0
		end
	end
	--bricks only bounce, the arena stays in one piece
	generatespritebatch()
	return true
end

local function rrr_updateblocks(S, dt)
	local changed = false
	for _, b in ipairs(S.blocks) do
		if b.cooldown > 0 then
			b.cooldown = b.cooldown - dt
			if b.cooldown <= 0 then
				b.cooldown = 0
				map[b.x][b.y][1] = RRR_QUESTIONBLOCK
				changed = true
			end
		else
			b.roulettet = b.roulettet + dt
			while b.roulettet >= RRR_ROULETTE_TIME do
				b.roulettet = b.roulettet - RRR_ROULETTE_TIME
				b.roulette = b.roulette % #b.def.items + 1
			end
		end
	end
	if changed then
		generatespritebatch()
	end
end

--how far a bumped block is up (tiles), same motion as the tile itself
local function rrr_bounceoffset(x, y)
	local bounce = getblockbounce(x, y)
	if not (bounce and bounce.timer) then
		return 0
	end
	local t = math.abs(bounce.timer)
	if t < blockbouncetime/2 then
		return t/(blockbouncetime/2)*blockbounceheight
	end
	return math.max(0, (2 - t/(blockbouncetime/2))*blockbounceheight)
end

--the roulette (or the cooldown) over every ? block
local function rrr_drawblocks(S)
	for _, b in ipairs(S.blocks) do
		--drawn on the block itself, like a roulette block (items that come out sit right above it)
		local px = (b.x-1-xscroll)*16
		local py = (b.y-1-yscroll)*16 - 8 - rrr_bounceoffset(b.x, b.y)*16
		if px > -16 and px < width*16*screenzoom2*2 then
			if b.cooldown <= 0 then
				local img, quad = rrr_itemicon(b.def.items[b.roulette])
				if img and quad then
					love.graphics.setColor(255, 255, 255)
					love.graphics.draw(img, quad, math.floor(px*scale), math.floor(py*scale), 0, scale, scale)
				end
			else
				local text = tostring(math.ceil(b.cooldown))
				local c = b.def.color
				love.graphics.setColor(c[1], c[2], c[3])
				properprintFbackground(text, math.floor((px + 8 - #text*4)*scale), math.floor((py + 4)*scale))
			end
		end
	end
	love.graphics.setColor(255, 255, 255)
end

---------------
--  COMBAT  --
---------------

local function rrr_banner(S, text, duration)
	S.banner = {text = text, t = 0, duration = duration or 2}
end

--touching a player with a star or a blue shell at full speed, a projectile or a stomp: damage, like an enemy's
--(a powered up player drops to super, super drops to small, small dies)
local function rrr_hurt(S, victim, attacker)
	if rrr_protected(victim) or S.over or S.starting then
		return false
	end
	if attacker then
		S.lasthit[victim.playernumber] = {by = attacker.playernumber, t = S.time}
	end
	victim:die("Enemy")
	return true
end

--what players throw: fireballs, superballs, hammers, boomerangs, tails, and a custom character's own enemy
--when it kills other enemies (a custom fireenemy with killsenemies)
local RRR_PROJECTILES = {"fireball", "mariohammer", "boomerang", "mariotail", "enemy"}

local function rrr_isprojectile(name, o)
	if name == "enemy" then
		return o.fireballthrower ~= nil and o.killsenemies and not o.shot and not o.dead
	end
	return true
end

local function rrr_projectileowner(o)
	return o.fireballthrower or o.mariohammerthrower or o.player
end

local RRR_STOMP_GRACE = 0.25 --after a stomp, the two players can't hurt each other by touching for this long

--a is coming down onto v's head
local function rrr_stomping(a, v, dt)
	return a.speedy > 0 and rrr_feet(a) - a.speedy*dt <= v.y + 0.3
end

--a stomped b (or b stomped a) a moment ago
local function rrr_stompgrace(S, a, b)
	local t = S.stompgrace[a .. "," .. b] or S.stompgrace[b .. "," .. a]
	return t ~= nil and S.time < t
end

local function rrr_updatecombat(S, dt)
	local list = objects["player"]
	S.stompgrace = S.stompgrace or {}
	local function touching(i, j)
		local a, v = list[i], list[j]
		return i ~= j and a and v and rrr_alive(S, i) and rrr_alive(S, j) and a.active and v.active and rrr_overlap(a, v, 1/16)
	end

	--stomps first: anyone can bounce off anyone's head, like off an enemy. The one underneath only takes
	--damage when it can be hurt (a star or the blinking after a hit just means a bounce), and the one on top
	--never gets hurt by the stomp, even landing on a star or a fast blue shell
	for i = 1, RRR_PLAYERS do
		for j = 1, RRR_PLAYERS do
			local a, v = list[i], list[j]
			if touching(i, j) and not rrr_dangerous(a) and rrr_stomping(a, v, dt) and not rrr_stompgrace(S, i, j) then
				S.stompgrace[i .. "," .. j] = S.time + RRR_STOMP_GRACE
				rrr_hurt(S, v, a)
				a:stompbounce("player", {stompbouncesound = true})
				playsound(stompsound)
			end
		end
	end

	--players with a star or a fast blue shell hurt whoever they touch
	for i = 1, RRR_PLAYERS do
		for j = 1, RRR_PLAYERS do
			local a, v = list[i], list[j]
			if touching(i, j) and not rrr_stompgrace(S, i, j) then
				local adanger, vdanger = rrr_dangerous(a), rrr_dangerous(v)
				if a.size == 14 and v.size == 14 and adanger and vdanger and not (a.starred or v.starred or a.statue or v.statue) then
					--two shells bounce off each other
					if i < j then
						a.speedx, v.speedx = -a.speedx, -v.speedx
						playsound(blockhitsound)
					end
				elseif adanger then
					rrr_hurt(S, v, a) --does nothing to someone who can't be hurt (a star, a statue, blinking)
				end
			end
		end
	end

	--fireballs, superballs, hammers, boomerangs and tails hit anyone but who threw them
	for _, name in ipairs(RRR_PROJECTILES) do
		for _, o in pairs(objects[name] or {}) do
			local owner = rrr_projectileowner(o)
			if owner and rrr_isprojectile(name, o) and o.active ~= false and not o.destroy and not o.delete and not o.destroysoon then
				for j = 1, RRR_PLAYERS do
					local v = list[j]
					if v and v ~= owner and rrr_alive(S, j) and rrr_overlap(o, v) then
						if rrr_hurt(S, v, owner) then
							if name == "fireball" and o.explode then
								o:explode()
							end
						end
					end
				end
			end
		end
	end
end

--every person's knockouts added up (bots don't count): the score, kept up to date so quitting can save it
local function rrr_humankos(S)
	local total = 0
	for i = 1, RRR_PLAYERS do
		if not S.bots[i] then
			total = total + (S.kos[i] or 0)
		end
	end
	return total
end

local function rrr_checkwinner(S)
	if S.over then
		return
	end
	local alive = {}
	for i = 1, RRR_PLAYERS do
		if not S.out[i] then
			table.insert(alive, i)
		end
	end
	if #alive <= 1 then
		S.endbattle(S, alive[1], #alive == 1) --the last one standing: a knockout win
	end
end

--every player's star ends, so the star theme stops
local function rrr_endstar(p)
	if p.starred then
		p.startimer = mariostarduration - 0.0001
		if p.dead then
			p.starred = false
			p.colors = p.basecolors
		end
	end
end

local function rrr_ondeath(S, p)
	local i = p.playernumber
	rrr_endstar(p)
	p.starred = false
	if S.over then
		return --falling in a pit after the battle doesn't change the result (or the music)
	end
	updatemusicpriority() --a star ends with the player
	local hit = S.lasthit[i]
	if hit and S.time - hit.t <= RRR_HIT_CREDIT and hit.by ~= i then
		S.kos[hit.by] = S.kos[hit.by] + 1
		S.score = rrr_humankos(S)
	end
	S.lasthit[i] = nil
	if (mariolives[i] or 0) <= 0 then
		S.out[i] = true
		table.insert(S.outorder, i)
		rrr_banner(S, "p" .. i .. " is out!", 2)
	end
	rrr_checkwinner(S)
end

--back at the spawn, small and blinking for a bit
local function rrr_respawn(S, p)
	local i = p.playernumber
	if S.out[i] or S.over then
		p.drawable = false
		if S.out[i] then
			S.viewdone[i] = true --the death animation is over: the viewport can go (rrrx.updateviews)
		end
		return
	end
	local spawn = S.spawns[i] or S.spawns[1]
	p.speedx = 0
	p.speedy = 0
	p.dead = false
	p.size = 1
	p.health = p.characterdata.health
	p:setsize(1)
	p.starred = false
	p.startimer = mariostarduration
	p.colors = p.basecolors
	p.drawable = true
	p.animationstate = "idle"
	p:setquad()
	p.animation = "invincible"
	p.invincible = true
	p.animationtimer = rrr_invinciblestart()
	p.x = spawn.x - 0.5 - p.width/2
	p.y = spawn.y - p.height
	p.jumping = false
	p.falling = true
	p.controlsenabled = not S.sdpending --(time up: everyone waits for sudden death)
	p.active = true
	makepoof(spawn.x - 0.5, spawn.y - 0.5, "makerpoof")
end

--a player who is out loses their viewport once their death animation is over, and the others move and resize into the
--new layout (splitscreen_setviewplayers). The last viewport stays, it watches someone who's still in.
function rrrx.updateviews(S)
	if not splitscreenviewplayers then
		return
	end
	local list, changed = {}, false
	for _, pn in ipairs(splitscreenviewplayers) do
		if S.out[pn] and S.viewdone[pn] then
			changed = true
		else
			table.insert(list, pn)
		end
	end
	if changed and #list > 0 then
		splitscreen_setviewplayers(list)
	end
end

--a viewport comes back (a person back in the battle with the konami code), in player order
function rrrx.addview(S, i)
	S.viewdone[i] = nil
	if not splitscreenviewplayers then
		return
	end
	local list = {}
	for _, pn in ipairs(splitscreenviewplayers) do
		if pn == i then
			return
		end
		table.insert(list, pn)
	end
	table.insert(list, i)
	table.sort(list)
	splitscreen_setviewplayers(list)
end

------------
--  BOTS  --
------------
--a bot holds buttons through the same functions the keyboard goes through (checkkey), presses call the same player functions

local RRR_SHOOTERS = {[3] = true, [4] = true, [13] = true, [15] = true} --fire, hammer, superball, boomerang
local RRR_INFINITE_FIRE_RATE = 0.4 --with infinite fireballs on, bots wait this much of their usual time between shots
local RRR_MIN_FIRE_WAIT = 0.08 --but never less than this (about as fast as someone can mash the button)
local RRR_SPINNERS = {[6] = true, [9] = true, [10] = true} --leaf, tanooki, cape

--bot difficulty
--think: how long it takes to make up its mind (seconds, up to 60% more at random)
--fire: the wait between shots (up to twice as long at random)
--dodge: the chance it jumps over a projectile coming at it
--range: how far away it starts shooting (tiles)
--flee: how close a star or a fast blue shell gets before it runs (tiles)
--dawdle: the chance it stands around for a moment when it makes up its mind
--lead: aims where the target will be this many seconds from now
--greed: how often it goes for a block instead of a fight (at random between 0.3 and 0.7 when not set)
--dodgestomps: steps out from under anyone coming down on its head
local RRR_BOTLEVELS = {
	{name = "easy", think = 0.8, fire = 1.2, dodge = 0.15, range = 7, flee = 4, dawdle = 0.3, lead = 0},
	{name = "normal", think = 0.45, fire = 0.7, dodge = 0.5, range = 10, flee = 6, dawdle = 0.1, lead = 0},
	{name = "expert", think = 0.25, fire = 0.35, dodge = 0.9, range = 12, flee = 7, dawdle = 0, lead = 0},
	{name = "super expert", think = 0.12, fire = 0.18, dodge = 1, range = 16, flee = 9, dawdle = 0, lead = 0.3},
	{name = "godmode", think = 0.05, fire = 0.1, dodge = 1, range = 40, flee = 12, dawdle = 0, lead = 0.4, greed = 0.8, dodgestomps = true},
}

local function rrr_newbot(level)
	level = RRR_BOTLEVELS[level] or RRR_BOTLEVELS[2]
	return {
		level = level,
		dawdle = 0,
		input = {},
		think = 0,
		goal = {kind = "wander"},
		firecooldown = 0.5,
		stuck = 0,
		lastx = 0,
		greed = level.greed or 0.3 + math.random()*0.4, --how often it goes for a block instead of a fight
		wandert = 0,
		ignore = {}, --items and blocks it gave up on (thing = time it can try again)
		tried = {}, --how long it has gone after each item or block, all together (switching goals doesn't reset it)
	}
end

local function rrr_steer(input, from, to, slack)
	if to < from - slack then
		input.left = true
	elseif to > from + slack then
		input.right = true
	end
end

local function rrr_facing(p)
	if p.animationdirection == "left" then
		return -1
	end
	return 1
end

local function rrr_itemobjects()
	local out = {}
	for _, name in ipairs(RRR_ITEMTABLES) do
		for _, o in pairs(objects[name] or {}) do
			if not (o.destroy or o.delete or o.instantdelete) and o.y < mapheight then
				table.insert(out, o)
			end
		end
	end
	return out
end

--the closest thing in a list (by distance), nil when the list is empty
local function rrr_nearest(p, things, getpos)
	local best, bestd = nil, math.huge
	local cx, cy = rrr_center(p), rrr_feet(p)
	for _, t in ipairs(things) do
		local x, y = getpos(t)
		if x then
			local d = math.abs(x-cx) + math.abs(y-cy)*1.5
			if d < bestd then
				best, bestd = t, d
			end
		end
	end
	return best, bestd
end

local function rrr_enemies(S, i)
	local out = {}
	for j = 1, RRR_PLAYERS do
		if j ~= i and rrr_alive(S, j) then
			table.insert(out, objects["player"][j])
		end
	end
	return out
end

local function rrr_playerpos(q)
	return rrr_center(q), rrr_feet(q)
end

local function rrr_ignored(S, bot, thing)
	local t = bot.ignore[thing]
	return t ~= nil and S.time < t
end

--set a new goal (the same goal stays as it is)
local function rrr_setgoal(S, bot, goal)
	local old = bot.goal
	local same = old.kind == goal.kind and old.obj == goal.obj and old.block == goal.block and old.target == goal.target
	if not same then
		bot.goal = goal
	end
end

--pick something to do
local function rrr_botthink(S, i, p, bot)
	local enemies = rrr_enemies(S, i)
	local cx = rrr_center(p)

	--run from deadly players (unless deadly too)
	if not p.starred then
		local danger, dist = nil, math.huge
		for _, e in ipairs(enemies) do
			if rrr_dangerous(e) and not e.statue then --a statue can't chase anyone, bots jump over it instead (rrr_botupdate)
				local d = math.abs(rrr_center(e)-cx) + math.abs(rrr_feet(e)-rrr_feet(p))
				if d < dist then
					danger, dist = e, d
				end
			end
		end
		if danger and dist < bot.level.flee then
			rrr_setgoal(S, bot, {kind = "flee", from = danger})
			return
		end
	end

	--items lying around
	if not p.starred then
		local items = {}
		for _, o in ipairs(rrr_itemobjects()) do
			if not rrr_ignored(S, bot, o) then
				table.insert(items, o)
			end
		end
		local item, dist = rrr_nearest(p, items, function(o)
			return o.x + o.width/2, o.y + o.height
		end)
		if item and (dist < 8 or p.size <= 2) then
			rrr_setgoal(S, bot, {kind = "item", obj = item})
			return
		end
	end

	--small (or greedy): get something out of a ? block
	if not p.starred and (p.size <= 2 or math.random() < bot.greed) then
		local ready = {}
		for _, b in ipairs(S.blocks) do
			if b.cooldown <= 0 and b.seg and not rrr_ignored(S, bot, b) then
				table.insert(ready, b)
			end
		end
		local b = rrr_nearest(p, ready, function(block)
			return block.x - 0.5, block.seg.y
		end)
		if b then
			rrr_setgoal(S, bot, {kind = "block", block = b})
			return
		end
	end

	--fight: the closest one that can be hurt
	local targets = {}
	for _, e in ipairs(enemies) do
		if not e.starred and (p.starred or not rrr_dangerous(e)) then
			table.insert(targets, e)
		end
	end
	local target = rrr_nearest(p, targets, rrr_playerpos)
	if target then
		rrr_setgoal(S, bot, {kind = "enemy", target = target})
		return
	end
	rrr_setgoal(S, bot, {kind = "wander"})
end

--where the goal is: the segment to get to and the x to stand at
local function rrr_goalpos(S, p, bot)
	local g = bot.goal
	if g.kind == "block" then
		if g.block.cooldown > 0 then
			bot.think = 0
		end
		return g.block.seg, g.block.x - 0.5
	elseif g.kind == "item" then
		local o = g.obj
		if o.destroy or o.delete or o.instantdelete or o.y > mapheight then
			bot.think = 0
			return nil, rrr_center(p)
		end
		local x = o.x + o.width/2
		return rrr_segbelow(S, x, o.y + o.height), x
	elseif g.kind == "enemy" then
		local e = g.target
		if e.dead or not e.active then
			bot.think = 0
			return nil, rrr_center(p)
		end
		return rrr_playerseg(S, e) or rrr_segbelow(S, rrr_center(e), rrr_feet(e)), rrr_center(e)
	elseif g.kind == "flee" then
		local seg = rrr_playerseg(S, p)
		local away = rrr_center(p) - rrr_center(g.from)
		if seg then
			--the far end of where it stands (it jumps when it gets close anyway)
			local x = seg.x1 - 0.5
			if away > 0 then
				x = seg.x2 - 0.5
			end
			return seg, x
		end
		return nil, rrr_center(p)
	end
	--wander somewhere
	if not bot.wanderseg or bot.wandert <= 0 then
		bot.wanderseg = randomitem(S.segs)
		bot.wandert = 3 + math.random()*3
	end
	return bot.wanderseg, (bot.wanderseg.x1 + bot.wanderseg.x2)/2 - 0.5
end

--fight on the same level as the target
local function rrr_botattack(S, p, bot, input, e, dt)
	local cx = rrr_center(p)
	local ex = rrr_center(e) + (e.speedx or 0)*bot.level.lead
	local dx = ex - cx
	local dy = rrr_feet(e) - rrr_feet(p)
	local dir = 1
	if dx < 0 then
		dir = -1
	end
	local function face()
		if rrr_facing(p) ~= dir then
			if dir > 0 then
				input.right = true
			else
				input.left = true
			end
			return false
		end
		return true
	end

	if p.starred then
		rrr_steer(input, cx, ex, 0.2)
		if dy < -1 and math.abs(dx) < 3 then
			input.jump = true
		end
	elseif RRR_SHOOTERS[p.size] then
		--keep some distance and shoot
		local dist = math.abs(dx)
		if dist < 2.5 then
			rrr_steer(input, cx, cx - dir*3, 0.1)
		elseif dist > 7 then
			rrr_steer(input, cx, ex, 0.5)
		end
		local inline = math.abs(dy) < 1.3 or (p.size == 4 and dy < 0 and dy > -3.5)
		--only when a shot can come out (2 on screen at most, unless infinite fireballs is on), so a press isn't wasted
		if inline and dist < bot.level.range and face() and bot.firecooldown <= 0 and p:canfire() then
			bot.fire = true
			local wait = bot.level.fire*(1 + math.random())
			if INFINITEFIREBALLS then
				wait = math.max(wait*RRR_INFINITE_FIRE_RATE, RRR_MIN_FIRE_WAIT)
			end
			bot.firecooldown = wait
		end
	elseif RRR_SPINNERS[p.size] then
		rrr_steer(input, cx, ex, 0.8)
		if math.abs(dx) < 1.8 and math.abs(dy) < 1.3 and face() and bot.firecooldown <= 0 then
			bot.fire = true
			bot.firecooldown = bot.level.fire*0.8*(1 + math.random())
		end
		if dy < -1.2 and math.abs(dx) < 2.5 then
			input.jump = true
		end
	elseif p.size == 14 then
		--blue shell: full speed into them
		rrr_steer(input, cx, ex + dir*4, 0.2)
		input.run = true
	else
		--stomp them
		rrr_steer(input, cx, ex, 0.1)
		if math.abs(dx) < 2.6 and dy > -2 and not e.falling and not e.jumping then
			input.jump = true
		end
	end
end

--projectiles coming this way: jump
local function rrr_incoming(S, p)
	local cx, cy = rrr_center(p), p.y + p.height/2
	for _, name in ipairs(RRR_PROJECTILES) do
		for _, o in pairs(objects[name] or {}) do
			local owner = rrr_projectileowner(o)
			if name ~= "mariotail" and owner and owner ~= p and rrr_isprojectile(name, o) and o.active ~= false and not o.destroy then
				local ox = o.x + o.width/2
				local toward = (o.speedx or 0) * (cx - ox) > 0
				if toward and math.abs(ox - cx) < 3.5 and math.abs((o.y + o.height/2) - cy) < 1.4 then
					return true
				end
			end
		end
	end
	return false
end

local function rrr_applyinputs(p, bot)
	local input = bot.input
	if input.jump and not bot.prevjump then
		p:button("jump")
		p:wag()
		p:jump()
	elseif not input.jump and bot.prevjump then
		p:buttonrelease("jump")
		p:stopjump()
	end
	bot.prevjump = input.jump
	if bot.fire then
		bot.fire = false
		p:button("run")
		p:fire()
	end
end

local function rrr_botupdate(S, i, p, dt)
	local bot = S.bots[i]
	local input = bot.input
	input.left, input.right, input.up, input.down = false, false, false, false
	input.run = false
	input.jump = false
	if p.dead or S.out[i] or S.over or S.starting or not p.controlsenabled then
		rrr_applyinputs(p, bot)
		return
	end
	input.run = true
	bot.firecooldown = bot.firecooldown - dt
	bot.wandert = bot.wandert - dt
	--an item or block it can't get to in 6 seconds (all tries together) gets left alone for 10
	local thing = bot.goal.obj or bot.goal.block
	if thing then
		bot.tried[thing] = (bot.tried[thing] or 0) + dt
		if bot.tried[thing] > 6 then
			bot.tried[thing] = 0
			bot.ignore[thing] = S.time + 10
			bot.think = 0
		end
	end
	bot.think = bot.think - dt
	if bot.think <= 0 then
		rrr_botthink(S, i, p, bot)
		bot.think = bot.level.think*(1 + math.random()*0.6)
		if bot.goal.kind ~= "flee" and math.random() < bot.level.dawdle then
			bot.dawdle = 0.4 + math.random()*0.6
		end
	end

	--standing around for a moment (only on the ground, and never while something dangerous is close)
	if bot.dawdle > 0 then
		bot.dawdle = bot.dawdle - dt
		if rrr_playerseg(S, p) and bot.goal.kind ~= "flee" then
			input.run = false
			bot.lastx = p.x
			rrr_applyinputs(p, bot)
			return
		end
	end

	local cx, feet = rrr_center(p), rrr_feet(p)
	local cur = rrr_playerseg(S, p)
	local goalseg, goalx = rrr_goalpos(S, p, bot)
	local g = bot.goal

	if cur then
		bot.air = nil
		bot.lastground = cur
		if bot.runup and not (S.edges[cur] and goalseg) then
			bot.runup = nil
		end
		local path = goalseg and rrr_path(S, cur, goalseg)
		bot.pending = nil
		if goalseg == nil or goalseg == cur or not path then
			--on the goal's level (or no way to get there): the goal itself, jumps here land back on this segment
			bot.pending = {seg = cur, home = true}
			if g.kind == "enemy" then
				bot.pending.chase = g.target
			end
			local seglo, seghi = cur.x1 - 1 + 0.45, cur.x2 - 0.45
			if g.kind == "enemy" and goalseg == cur then
				rrr_botattack(S, p, bot, input, g.target, dt)
			elseif g.kind == "enemy" and RRR_SHOOTERS[p.size] and math.abs(rrr_feet(g.target) - feet) < 1.5 then
				rrr_botattack(S, p, bot, input, g.target, dt) --shooting works across a gap too
			elseif g.kind == "block" and goalseg == cur then
				rrr_steer(input, cx, goalx, 0.15)
				if math.abs(cx - goalx) < 0.3 then
					input.jump = true
				end
			elseif g.kind == "flee" then
				rrr_steer(input, cx, rrr_clamp(goalx, seglo, seghi), 0.3)
				local d = math.abs(rrr_center(g.from) - cx)
				if d < 3 then
					input.jump = true
				end
			else
				rrr_steer(input, cx, rrr_clamp(goalx, seglo, seghi), 0.3)
				if g.kind == "item" and g.obj.y + g.obj.height < feet - 1 and math.abs(goalx - cx) < 1.5 then
					input.jump = true
				end
				if not path and goalseg and goalseg ~= cur and math.random() < dt then
					input.jump = true --no route found: try something
				end
			end
		else
			--follow the route
			local nextseg = path[2]
			local e = S.edges[cur][nextseg]
			if e.kind == "drop" then
				input.run = false --walk off, so it doesn't fly past where it lands
				rrr_steer(input, cx, e.x - 0.5 + e.dir*0.3, 0.05)
				bot.pending = {seg = nextseg, dir = e.dir}
			else
				local t = e.takeoffs[1]
				for k = 2, #e.takeoffs do
					if math.abs(e.takeoffs[k].x - 0.5 - cx) < math.abs(t.x - 0.5 - cx) then
						t = e.takeoffs[k]
					end
				end
				local tx = t.x - 0.5
				if not t.under then
					tx = tx + t.dir*0.25 --run up to the very edge
				end
				bot.pending = {seg = nextseg, dir = t.dir, under = t.under, gap = not t.under, down = nextseg.y > cur.y}
				--only a wide gap needs a running start, otherwise a small platform gets overshot
				local gapwidth = math.max(nextseg.x1 - cur.x2, cur.x1 - nextseg.x2) - 1
				if gapwidth < 3 then
					input.run = false
				elseif not t.under then
					--a wide gap: back up for a running start when too slow at the edge
					local edge = t.x - 0.5
					if math.abs(p.speedx) < maxrunspeed*0.8 and (tx - cx)*t.dir < 1.5 then
						bot.runup = t
					end
					if bot.runup then
						local back = rrr_clamp(edge - t.dir*4, cur.x1 - 0.5, cur.x2 - 0.5)
						if math.abs(back - cx) < 0.5 or (cx - back)*t.dir < 0 then
							bot.runup = nil
						else
							tx = back
						end
					end
				end
				local d = tx - cx
				if bot.runup then
					rrr_steer(input, cx, tx, 0.1)
				elseif (not t.under and d*t.dir <= 0.3) or math.abs(d) < 0.3 then
					input.jump = true
					if not t.under then
						rrr_steer(input, cx, cx + t.dir, 0)
					end
				else
					rrr_steer(input, cx, tx, 0.1)
				end
			end
		end
	else
		--in the air
		if not bot.air then
			bot.air = bot.pending or {}
			bot.pending = nil
		end
		local N = bot.air.seg
		if N then
			if feet < N.y - 0.05 then
				--above it: get over it (the middle of a small one), or after whoever it's jumping at
				local want = cx
				if bot.air.chase and not bot.air.chase.dead then
					want = rrr_center(bot.air.chase)
				elseif bot.air.home and goalx then
					want = goalx
				end
				local tx = rrr_clamp(want, N.x1 - 1 + 0.6, N.x2 - 0.6)
				if N.x2 - N.x1 < 3 then
					tx = (N.x1 + N.x2)/2 - 0.5
				end
				rrr_steer(input, cx, tx, 0.1)
			elseif bot.air.gap and bot.air.dir then
				rrr_steer(input, cx, cx + bot.air.dir, 0)
			end
			--keep holding jump while going up (a full jump over a gap, high enough over a platform)
			if p.speedy < 0 and ((bot.air.gap and not bot.air.down) or feet > N.y - 1.6) then
				input.jump = true
			end
		else
			if p.speedy < 0 then
				input.jump = true
			end
		end
		--missed and coming down over a pit: back to where it came from
		if p.speedy > 0 and bot.lastground and not rrr_segbelow(S, cx, feet) and (not N or feet > N.y + 0.05) then
			local G = bot.lastground
			input.left, input.right = false, false
			rrr_steer(input, cx, rrr_clamp(cx, G.x1 - 1 + 0.6, G.x2 - 0.6), 0.05)
		elseif not N then
			if g.kind == "enemy" then
				rrr_steer(input, cx, rrr_center(g.target), 0.2)
			elseif goalx then
				rrr_steer(input, cx, goalx, 0.3)
			end
		end
	end

	--dodge (it decides once per projectile if it sees it in time)
	local incoming = cur and rrr_incoming(S, p)
	if incoming and not bot.sawincoming then
		bot.willdodge = math.random() < bot.level.dodge
	end
	bot.sawincoming = incoming
	if incoming and bot.willdodge then
		input.jump = true
	end

	--a tanooki statue in the way: jump over it
	if cur and (input.left or input.right) and not p.starred then
		local dir = 1
		if input.left then
			dir = -1
		end
		for _, e in ipairs(rrr_enemies(S, i)) do
			local ahead = (rrr_center(e) - cx)*dir
			if e.statue and ahead > 0 and ahead < 2 and math.abs(rrr_feet(e) - feet) < 1 then
				input.jump = true
			end
		end
	end

	--someone coming down on its head: step out from under them
	if bot.level.dodgestomps and cur and not p.starred then
		for _, e in ipairs(rrr_enemies(S, i)) do
			local above = p.y - rrr_feet(e)
			if e.speedy > 0 and not rrr_dangerous(e) and above > 0 and above < 2.5 and math.abs(rrr_center(e) - cx) < 1.3 then
				input.left, input.right = false, false
				if rrr_center(e) > cx then
					input.left = true
				else
					input.right = true
				end
			end
		end
	end

	--blue shell: slide when running at full speed toward someone
	if p.size == 14 and g.kind == "enemy" and math.abs(p.speedx) >= maxrunspeed - 0.1 and math.abs(rrr_center(g.target) - cx) < 8 then
		input.down = true
	end

	--stuck against something: jump, and if that doesn't help, go somewhere else
	if (input.left or input.right) and cur then
		if math.abs(p.x - bot.lastx) < 0.02 then
			bot.stuck = bot.stuck + dt
			if bot.stuck > 0.4 then
				input.jump = true
			end
			if bot.stuck > 2 then
				rrr_setgoal(S, bot, {kind = "wander"})
				bot.wanderseg = nil
				bot.think = 2
				bot.stuck = 0
			end
		else
			bot.stuck = 0
		end
	end
	bot.lastx = p.x

	--a new jump needs the button to be let go first
	if input.jump and bot.prevjump and cur and not p.jumping and not p.falling then
		input.jump = false
	end

	--never walk off an edge into a pit (planned jumps over it are fine)
	if cur and not (input.jump and not bot.prevjump) then
		local column
		if input.right and cx > cur.x2 - 0.7 then
			column = cur.x2 + 1
		elseif input.left and cx < cur.x1 - 1 + 0.7 then
			column = cur.x1 - 1
		end
		if column and not rrr_solid(column, cur.y) and rrr_landing(S, column, cur.y) == nil then
			input.left, input.right = false, false
		end
	end
	rrr_applyinputs(p, bot)
end

-------------------------------
--  HOOKS INTO THE GAME CODE  --
-------------------------------

--bots press buttons instead of the keyboard or a controller
do
	local originalcheckkey = checkkey
	function checkkey(s, i, n)
		local S = rrr_state()
		if S and S.bots[i] then
			return S.bots[i].input[n] == true
		end
		return originalcheckkey(s, i, n)
	end
end

--keys bound to a bot do nothing (pause still works for everyone)
do
	local originalgetcontrolbindings = getcontrolbindings
	function getcontrolbindings(player, name)
		local S = rrr_state()
		if S and S.bots[player] and name ~= "pause" then
			return {}
		end
		return originalgetcontrolbindings(player, name)
	end
end

--sliding past the corner of a ? block of the battle (the edge of it, no hit) makes the bump sound,
--so a jump that only caught the corner doesn't go by silently
function cornerslide(x, y, p)
	local S = rrr_state()
	if S and S.blockat[x] and S.blockat[x][y] then
		playsound(blockhitsound)
	end
end

do --(each hook keeps its original to itself: the file can only have 200 locals at once)
	--a player's own thrown enemy (a custom character's fireenemy) never hurts that player, even one that hurts players
	local originalglobalcollide = mario.globalcollide
	function mario:globalcollide(a, b)
		if a == "enemy" and b and b.fireballthrower == self and rrr_state() then
			return true --passes through
		end
		return originalglobalcollide(self, a, b)
	end
end

do --(each hook keeps its original to itself: the file can only have 200 locals at once)
	local originalhitblock = hitblock
	function hitblock(x, y, t, v)
		local S = rrr_state()
		if S and rrr_hitblock(S, x, y, t) then
			return
		end
		return originalhitblock(x, y, t, v)
	end
end

do
	local originaldie = mario.die
	function mario:die(how)
		local S = rrr_state()
		if not S then
			return originaldie(self, how)
		end
		if self.dead or (S.over and how ~= "pit") then
			return
		end
		local r = originaldie(self, how)
		if self.dead then
			rrr_ondeath(S, self)
		end
		return r
	end
end

--no grow or shrink animation in a battle (they freeze the whole game): the new size is there right away,
--and the player blinks invincible for a moment, just like after getting hit
local function rrr_instantinvincible(p)
	noupdate = false
	p.animation = "invincible"
	p.invincible = true
	p.animationtimer = rrr_invinciblestart()
	p.drawable = true
	p:endsizechange() --no grow or shrink animation here: ducking comes back straight away
end

do
	local originalgrow = mario.grow
	function mario:grow(update)
		local S = rrr_state()
		if not S then
			return originalgrow(self, update)
		end
		local oldsize = self.size
		local wasanimating = self.animation and self.animation ~= "invincible"
		--a power-up (not a mushroom) while small goes straight to that power-up, whatever the physics
		--(the game only does that with mario maker physics, so it gets them for this one power-up)
		local oldphysics = mariomakerphysics
		if self.size == 1 and update and update ~= 2 then
			mariomakerphysics = true
		end
		local r = originalgrow(self, update)
		mariomakerphysics = oldphysics
		if self.animation == "grow1" or self.animation == "grow2" then
			if self.animation == "grow1" then
				self.animationstate = self.animationmisc
			end
			self:setsize(self.size)
			rrr_instantinvincible(self)
		elseif not wasanimating and (self.size ~= oldsize or update) then
			rrr_instantinvincible(self) --already powered up: the new power-up was set right away
		end
		return r
	end
end

do
	local originalshrink = mario.shrink
	function mario:shrink()
		local S = rrr_state()
		if not S then
			return originalshrink(self)
		end
		--above super (fire, leaf, suits...): back to super, whatever the physics
		--(the game only does that with mario maker physics, so it gets them for this one hit)
		local oldphysics = mariomakerphysics
		if self.size > 2 then
			mariomakerphysics = true
		end
		local r = originalshrink(self)
		mariomakerphysics = oldphysics
		if self.animation == "shrink" then
			self.animationstate = self.animationmisc
			if self.largeshrink then
				self.size = 2
				self:setsize(2)
				self.largeshrink = false
			else
				self:setsize(1)
			end
			rrr_instantinvincible(self)
		elseif self.animation == "invincible" then
			rrr_instantinvincible(self) --1 second, not the game's usual 2
		end
		return r
	end
end

do
	local originalrespawn = mario.respawn
	function mario:respawn()
		local S = rrr_state()
		if not S then
			return originalrespawn(self)
		end
		rrr_respawn(S, self)
	end
end

--nobody being alive doesn't end a battle, the minigame does (see mario:die)
function minigame_keepplaying()
	return rrr_state() ~= nil
end

--------------------
--  KONAMI CODE  --
--------------------
--a person who is out can come back once with 3 lives: up up down down left right left right run jump
--(run and jump take the places of b and a), typed with that player's own controls

local RRR_KONAMI = {"up", "up", "down", "down", "left", "right", "left", "right", "run", "jump"}
local RRR_KONAMI_LIVES = 3
local RRR_KONAMI_KEYS = {up = upkey, down = downkey, left = leftkey, right = rightkey, run = runkey, jump = jumpkey}
local RRR_KONAMI_ORDER = {"up", "down", "left", "right", "run", "jump"} --checked in this order when two go down in one frame

local function rrr_konamirevive(S, i)
	S.out[i] = false
	for k = #S.outorder, 1, -1 do
		if S.outorder[k] == i then
			table.remove(S.outorder, k)
		end
	end
	S.konami[i].used = true
	if S.suddendeath then
		mariolives[i] = RRR_K.SD_LIVES
	else
		mariolives[i] = RRR_KONAMI_LIVES
	end
	if S.watch == i then
		S.watch = nil
	end
	rrrx.addview(S, i)
	rrr_respawn(S, objects["player"][i])
	playsound(oneupsound)
	rrr_banner(S, "p" .. i .. " is back!", 2)
end

local function rrr_updatekonami(S)
	for i = 1, RRR_PLAYERS do
		local K = S.konami[i]
		if not S.bots[i] and K and objects["player"][i] then
			for _, name in ipairs(RRR_KONAMI_ORDER) do
				local down = RRR_KONAMI_KEYS[name](i) == true
				if down and not K.held[name] then
					--a press: the next one in the code, or start over (that press can be the first one again)
					if RRR_KONAMI[K.progress+1] == name then
						K.progress = K.progress + 1
					elseif RRR_KONAMI[1] == name then
						K.progress = 1
					else
						K.progress = 0
					end
					if K.progress == #RRR_KONAMI then
						K.progress = 0
						if S.out[i] and not K.used and not S.over then
							rrr_konamirevive(S, i)
						end
					end
				end
				K.held[name] = down
			end
		end
	end
end

-----------
--  HUD  --
-----------

local function rrr_drawhud(S)
	--custom player slots removed: use the built-in multiplayer lives HUD (drawmultiHUD) instead
	if S.suddendeath then
		local s = "sudden death"
		love.graphics.setColor(255, 90, 90)
		properprintFbackground(s, (width*8 - #s*4)*scale, 30*scale)
	elseif S.timeleft and not S.finalcount then --(the last seconds show as a big number instead, see rrrx.drawfinalcount)
		local t = math.max(0, math.ceil(S.timeleft))
		love.graphics.setColor(255, 255, 255)
		if t <= 30 and S.timeleft > 0 and math.floor(S.timeleft*4) % 2 == 0 then
			love.graphics.setColor(255, 90, 90)
		end
		local s = "time " .. t
		properprintFbackground(s, (width*8 - #s*4)*scale, 30*scale)
	end
	love.graphics.setColor(255, 255, 255)
end

--counts in real time (not game time), a pause or a hitch doesn't eat into it
--the timer's low time warning: below this, the battle music speeds up (if it has a fast version)
local RRR_LOWTIME = 100

--the battle music always has a fast version: song-fast.ogg next to a custom song (overworld-fast.ogg and so on for the
--built-in ones), and a song without one gets one made up, the song itself 1.25x faster and higher (music:fakefast)
function rrrx.ensurefastmusic()
	if not custommusic or music.loaded[music:variant(custommusic, "-fast")] then
		return
	end
	music:fakefast(custommusic, RRR_K.FAKEFAST_RATE, ClassicSpeedUpFastMusic) --(classic: faster and higher, not stretched)
	rrrx.fakefast = custommusic --taken away again by rrr_restoremusic
end

--the low time sound, then the fast music (rrr_updatelowtime starts it once the sound is done)
function rrrx.startlowtime(S)
	rrrx.ensurefastmusic()
	S.lowtime = {waiting = true}
	stopmusic()
	playsound(lowtimesound)
	queuelowtime = true --nothing starts the music (a star for example) until the low time sound is done
end

--with the timer below RRR_LOWTIME, and in sudden death from "go!": the low time sound, then the fast music.
--the game picks the fast music (and the fast star theme) from mariotime, which minigames don't count down themselves,
--so it follows the battle's timer from then on (sudden death has no timer, so it stays low)
local function rrr_updatelowtime(S)
	if S.over or S.starting or S.sdpending then
		return
	end
	if S.suddendeath then
		mariotime = 1
	elseif S.timeleft then
		if not S.lowtime then
			if S.timeleft < RRR_LOWTIME then
				mariotime = math.max(S.timeleft, 0.01)
				rrrx.startlowtime(S)
			end
			return
		end
		mariotime = math.max(S.timeleft, 0.01)
	end
	if S.lowtime and S.lowtime.waiting and not lowtimesound:isPlaying() then
		S.lowtime.waiting = false
		queuelowtime = false
		updatemusicpriority() --the fast music, or the fast star theme if someone has a star
	end
end

--under RRR_K.FINALCOUNT seconds the timer is a big number (rrrx.drawfinalcount), with a beep every time it changes
function rrrx.updatefinalcount(S)
	local n = nil
	if S.timeleft and S.timeleft > 0 and S.timeleft < RRR_K.FINALCOUNT and not S.over then
		n = math.ceil(S.timeleft)
	end
	if n and S.finalcount ~= n then
		playsound(countdownbeepsound)
	end
	S.finalcount = n
end

local function rrr_updatecountdown(S)
	local C = S.countdown
	if not C or C.finished then
		return
	end
	local now = love.timer.getTime()
	C.elapsed = C.elapsed + math.min(now - C.last, 0.1)
	C.last = now
	if not S.starting then
		--"go!" stays up for a second
		if C.elapsed >= RRR_COUNTDOWN + 1 then
			C.finished = true
		end
		return
	end
	if C.elapsed >= RRR_COUNTDOWN then
		S.starting = nil
		C.shown = "go!"
		playsound(countdowngosound)
		for i = 1, RRR_PLAYERS do
			local p = objects["player"][i]
			if p and not S.out[i] then
				p.controlsenabled = true
			end
		end
		if S.suddendeath then
			mariotime = 1
			--no lowtimesound on sudden death go!: just switch to the fast music
			rrrx.ensurefastmusic()
			S.lowtime = {waiting = false}
			queuelowtime = false
			updatemusicpriority()
		else
			playmusic()
			--a song without a fast version gets one made up when the time runs low: stretching it takes a moment,
			--so it starts in the background now (sudden death reuses it)
			if S.timeleft and custommusic and not ClassicSpeedUpFastMusic
				and not music.loaded[music:variant(custommusic, "-fast")] then
				music:prestretch(custommusic, RRR_K.FAKEFAST_RATE)
			end
		end
		return
	end
	local number = tostring(RRR_COUNTDOWN - math.floor(C.elapsed)) --3, then 2, then 1
	if C.shown ~= number then
		C.shown = number
		playsound(countdownbeepsound)
	end
	if music:getPlaying() then
		stopmusic() --(resuming from the pause menu starts the music)
	end
end

--the big text in the middle of the screen: the countdown, and the last seconds of the timer
function rrrx.drawbig(s, alpha)
	local size = 3
	love.graphics.setColor(255, 255, 255, alpha or 255)
	properprintFbackground(s, (width*8 - utf8.len(s)*4*size)*scale, (height*8 - 5*size - 16)*scale, nil, nil, size)
	love.graphics.setColor(255, 255, 255)
end

local function rrr_drawcountdown(S)
	local C = S.countdown
	if not (C and C.shown) or C.finished then
		return
	end
	local alpha = 255
	if C.shown == "go!" then
		alpha = 255*math.max(0, math.min(1, (RRR_COUNTDOWN + 1 - C.elapsed)/0.3))
	end
	rrrx.drawbig(C.shown, alpha)
end

--the timer's last seconds, drawn like the countdown
function rrrx.drawfinalcount(S)
	if S.finalcount and not S.over then
		rrrx.drawbig(tostring(S.finalcount))
	end
end

local function rrr_drawoverlay(S)
	rrr_drawcountdown(S)
	rrrx.drawfinalcount(S)
	local B = S.banner
	if B then
		local alpha = 255
		if B.t > B.duration - 0.3 then
			alpha = 255*math.max(0, (B.duration - B.t)/0.3)
		end
		love.graphics.setColor(255, 255, 255, alpha)
		local s = B.text
		properprintFbackground(s, (width*8 - utf8.len(s)*4)*scale, (height*8 - 24)*scale)
	end
	love.graphics.setColor(255, 255, 255)
end

--the viewport of a player who is out follows someone who isn't
local function rrr_viewtarget(i)
	local S = rrr_state()
	if not S then
		return nil
	end
	local owner = splitscreen_viewplayer(i)
	if not S.out[owner] then
		return nil
	end
	if S.watch and rrr_alive(S, S.watch) then
		return objects["player"][S.watch]
	end
	for j = 1, RRR_PLAYERS do
		if not S.out[j] and objects["player"][j] and not objects["player"][j].dead then
			S.watch = j
			return objects["player"][j]
		end
	end
	return nil
end

local function rrr_viewhud(i, view, owner)
	local S = rrr_state()
	if not (S and S.out[owner]) then
		return
	end
	local target = rrr_viewtarget(i)
	if target and target.playernumber ~= owner then
		local s = "watching p" .. target.playernumber
		love.graphics.setColor(200, 200, 200)
		properprintFbackground(s, (view.x + view.w/2 - #s*4)*scale, (view.y + view.h - 22)*scale)
		love.graphics.setColor(255, 255, 255)
	end
end

----------------
--  THE GAME  --
----------------

local function rrr_cleanup()
	rrr_restoremusic()
	if minigamestate and minigamestate.lowtime then
		queuelowtime = false
	end
	if minigamestate and minigamestate.battle then
		rrr_stopclear(minigamestate)
	end
	if rrr_saved_split then
		SPLITSCREENISBACK = rrr_saved_split.on
		rrr_saved_split = nil
	end
	splitscreenviewplayers = nil
	splitscreenviewtarget = nil
	splitscreenviewhud = nil
	splitscreen_reset()
end

local function rrr_endbattle(S, winner, knockout)
	S.over = {winner = winner, t = 0}
	S.winner = winner
	S.knockoutend = knockout
	if winner then
		rrr_banner(S, "p" .. winner .. " wins!", 99)
	else
		rrr_banner(S, "draw!", 99)
	end
	if knockout then
		--everything stands still for a moment: no music, no new sounds, no controls, nothing moves or animates,
		--then the results screen, where the battle clear theme plays (resultmusic)
		playsound(boomsound)
		earthquake = 10
		minigame_finish("win", RRR_KO_FREEZE, "hard")
	else
		for i = 1, RRR_PLAYERS do
			local p = objects["player"][i]
			if p then
				rrr_endstar(p)
			end
		end
		stopmusic()
		rrr_startclear(S)
	end
	--the record is the knockouts of every person added up (or the winner's if only bots played)
	local humans = false
	for i = 1, RRR_PLAYERS do
		if not S.bots[i] then
			humans = true
		end
	end
	if humans then
		S.score = rrr_humankos(S)
	elseif winner then
		S.score = S.kos[winner]
	else
		S.score = 0
	end
	S.result = "lose" --a draw
	if winner then
		S.result = "win"
	end
	--the results screen comes once the battle clear theme is done (update)
end

--sudden death: what carries over from the battle into the sudden death arena (createmap reads it, the level is loaded again)
rrrx.carry = nil

--the fade to the sudden death arena: a new level, with the knockouts and who's out carried over (one shared screen there)
function rrrx.startsuddendeath(S)
	startwarpfade(function()
		if minigamestate ~= S or S.over or not minigameplaying then
			return --the battle ended while the screen faded out (someone fell in a pit with their last life)
		end
		local konamiused = {}
		for i = 1, RRR_PLAYERS do
			konamiused[i] = S.konami[i].used
		end
		rrrx.carry = {kos = S.kos, out = S.out, outorder = S.outorder, konamiused = konamiused}
		startlevel("minigame")
	end, false, true)
end

--the banner's time on screen
function rrrx.updatebanner(S, dt)
	if S.banner then
		S.banner.t = S.banner.t + dt
		if S.banner.t >= S.banner.duration then
			S.banner = nil
		end
	end
end

--time up with more than one player still in (frozen, see rrr_timeup): "time up!", "sudden death!", then the fade to its arena
function rrrx.updatesdpending(S, dt)
	local P = S.sdpending
	if not P or S.over then
		return
	end
	P.t = P.t + dt
	if not P.announced and P.t >= RRR_K.SD_ANNOUNCE then
		P.announced = true
		rrr_banner(S, "sudden death!", 99)
	end
	if not P.fading and P.t >= RRR_K.SD_DELAY then
		P.fading = true
		rrrx.startsuddendeath(S)
	end
end

local function rrr_timeup(S)
	--more than one player still in: sudden death in a small arena without ? blocks, one life each
	local stillin = 0
	for i = 1, RRR_PLAYERS do
		if not S.out[i] then
			stillin = stillin + 1
		end
	end
	if stillin > 1 then
		--everything stands still until the fade to the sudden death arena (rrrx.updatesdpending)
		S.sdpending = {t = 0}
		S.finalcount = nil
		playsound(boomsound)
		earthquake = 10
		minigame_freeze()
		rrr_banner(S, "time up!", RRR_K.SD_ANNOUNCE)
		return
	end

	--most lives left wins, then most knockouts, still a tie: draw
	local best, bestlives, bestkos, tie = nil, -1, -1, false
	for i = 1, RRR_PLAYERS do
		if not S.out[i] then
			local lives = mariolives[i] or 0
			if objects["player"][i] and not objects["player"][i].dead then
				lives = lives + 0.5 --alive right now beats waiting for a respawn
			end
			if lives > bestlives or (lives == bestlives and S.kos[i] > bestkos) then
				best, bestlives, bestkos, tie = i, lives, S.kos[i], false
			elseif lives == bestlives and S.kos[i] == bestkos then
				tie = true
			end
		end
	end
	if tie then
		best = nil
	end
	rrr_banner(S, "time up!", 1.5)
	S.endbattle(S, best)
end

addminigame({
	id = RRR_ID,
	savename = "Rival Rumble Royale",
	name = "rival rumble royale",
	--the description box is 16 characters wide (with its scrollbar) and doesn't keep spaces at the start of a line,
	--so the files in the example's pack folder start with a dash, and long paths are split after a slash
	description = "last one standing wins! grab power-ups from the ? blocks and knock everyone else out.\n\ncustom music: put .ogg songs in sounds/rivalrumbleroyalemusic in the game, or in alesans_entities/rivalrumbleroyalemusic in your save folder (%appdata%/mari0 on windows). every song shows up in the battle music list.\n\nan example of what can go in one of those folders:\nmy_song.ogg\nmy pack/\n-pack.json\n-boss.ogg\n-boss-intro.ogg\n-star.ogg\n-win.ogg\n\na folder is a music pack, listed as \"my pack- boss\". a song's -intro plays once before it. pack.json is optional and sets the pack's name, its place in the list, the song names, and the songs for \"starman theme\" (the star theme) and \"battle clear\" (the win fanfare), like star and win here. a pack without pack.json uses starmusic.ogg and battleclear.ogg for those. see README.md in sounds/minigames.",
	tagline = "last mario standing!",
	usesplayer = true,
	players = RRR_PLAYERS,
	keepphysics = true, --the game's own physics, not the mario maker physics the other minigames use
	resultsilent = RRR_RESULT_TIME,
	scorelabel = "knockouts",
	drawhud = rrr_drawhud,
	options = {
		--the first players are people, the rest are bots
		{type = "dropdown", key = "humans", label = "How many players are human?", entries = {"1 (p2-4 bots)", "2 (p3-4 bots)", "3 (p4 bot)", "4 (no bots)"}, default = 1},
		{type = "dropdown", key = "botlevel", label = "Bot difficulty", entries = (function()
			local names = {}
			for i, level in ipairs(RRR_BOTLEVELS) do
				names[i] = level.name
			end
			return names
		end)(), default = 2},
		{type = "dropdown", key = "theme", label = "Battle theme", entries = (function()
			local names = {}
			for i, theme in ipairs(RRR_THEMES) do
				names[i] = theme.name
			end
			return names
		end)(), default = 1},
		{type = "dropdown", key = "music", label = "Battle music", entries = rrr_musiclabels, wide = true, default = 1},
		{type = "checkbox", key = "botsplit", label = "Bot Splitscreen", default = true},
		{type = "slider", key = "lives", label = "Starting lives", min = 5, max = 100, step = 1, default = 10},
		{type = "sliderbox", key = "timelimit", checkkey = "timer", label = "Timer", min = 100, max = 1000, step = 10, default = 300, checkdefault = false},
	},

	createmap = function(S, opts)
		rrr_cleanup() --a restart from the pause menu
		local theme = RRR_THEMES[opts.theme or 1] or RRR_THEMES[1]
		S.battle = true
		S.theme = theme
		S.endbattle = rrr_endbattle
		--sudden death: the battle's knockouts and who's out carry over (rrrx.startsuddendeath)
		local carry = rrrx.carry
		rrrx.carry = nil
		--a new arena every time (the fixed one for the theme if the generator keeps failing)
		local built = false
		if carry then
			--sudden death: a small fixed arena without ? blocks, so no power-ups
			rrr_buildmap(S, theme, RRR_SD_LAYOUTS[theme.layout] or RRR_SD_LAYOUTS.field)
			rrr_buildnavigation(S)
			S.suddendeath = true
			built = true
		end
		for try = 1, RRR_GEN_TRIES do
			if built then
				break
			end
			local layout = rrr_generatelayout(theme)
			if layout then
				rrr_buildmap(S, theme, layout)
				rrr_buildnavigation(S)
				if rrr_arenaok(S) then
					built = true
					break
				end
			end
		end
		if not built then
			rrr_buildmap(S, theme, rrr_tallfixedlayout(RRR_LAYOUTS[theme.layout]))
			rrr_buildnavigation(S)
		end

		--theme
		spriteset = theme.spriteset
		if theme.backgroundrgb then
			background = 4
			backgroundrgbon = true
			backgroundrgb = theme.backgroundrgb
			backgroundcolor[4] = theme.backgroundrgb
		else
			background = theme.background
			backgroundrgbon = false
		end
		portalgun = false

		--players and lives
		S.bots = {}
		S.kos = {}
		S.out = {}
		S.outorder = {}
		S.lasthit = {}
		S.viewdone = {} --players who are out and whose death animation is over (their viewport goes)
		S.konami = {}
		for i = 1, RRR_PLAYERS do
			S.konami[i] = {progress = 0, held = {}, used = carry ~= nil and carry.konamiused[i] == true}
		end
		local humans = {}
		local humancount = opts.humans or 1
		for i = 1, RRR_PLAYERS do
			if i > humancount then
				S.bots[i] = rrr_newbot(opts.botlevel or 2)
			else
				table.insert(humans, i)
			end
			S.kos[i] = 0
		end
		infinitelives = false
		mariolivecount = math.floor(opts.lives or 5)
		mariolives = {}
		mariosizes = {}
		for i = 1, RRR_PLAYERS do
			mariolives[i] = mariolivecount
			mariosizes[i] = 1
		end
		if opts.timer and not carry then
			S.timeleft = opts.timelimit or 300
		end
		if carry then
			--sudden death: the players still in get one life each (and start small), the rest stay out
			S.kos = carry.kos
			S.out = carry.out
			S.outorder = carry.outorder
			S.score = rrr_humankos(S)
			for i = 1, RRR_PLAYERS do
				if S.out[i] then
					mariolives[i] = 0
					S.viewdone[i] = true
				else
					mariolives[i] = RRR_K.SD_LIVES
				end
			end
		end

		--split screen for every person (all bots: one screen that follows whoever is left)
		rrr_saved_split = {on = SPLITSCREENISBACK} --(put back by rrr_cleanup)
		if carry then
			--sudden death: the whole arena fits on one screen, so everyone shares it
			SPLITSCREENISBACK = false
		else
			SPLITSCREENISBACK = true
			if #humans == 0 then
				humans = {1}
			end
			splitscreenviewplayers = humans
			if opts.botsplit ~= false then
				splitscreenviewplayers = {}
				for i = 1, RRR_PLAYERS do
					table.insert(splitscreenviewplayers, i)
				end
			end
			splitscreenviewtarget = rrr_viewtarget
			splitscreenviewhud = rrr_viewhud
		end

		--music
		local list = rrr_musiclist()
		local entry = list[opts.music or 1]
		if not (entry and rrr_fileexists(entry.path)) then
			entry = list[1] --the song is gone (files moved since the menu was open)
		end
		rrr_setupmusic(S, entry)

		local spawn = S.spawns[1]
		startx = spawn.x - 0.5
		starty = spawn.y + 1
	end,

	postload = function(S)
		for i = 1, RRR_PLAYERS do
			local p = objects["player"][i]
			local spawn = S.spawns[i] or S.spawns[1]
			if p then
				p.portalgun = false
				p.x = spawn.x - 0.5 - p.width/2
				p.y = spawn.y - p.height
				p.speedx, p.speedy = 0, 0
				p.controlsenabled = false
				--a player that never fell has no gravity of its own yet, the physics then treats the first jump as
				--walking off a ledge (the falling pose all the way up). The same value the physics would use anyway
				p.gravity = p.gravity or yacceleration
				if spawn.x > mapwidth/2 then
					p.animationdirection = "left"
				end
				if S.out[i] then
					--sudden death: out of the battle, as if their death animation just finished
					p.dead = true
					p.animation = "death"
					p.animationmisc = nil
					p.animationtimer = deathtotaltime + 1
					p.drawable = false
					p.active = false
				end
			end
		end
		--the countdown: nobody moves and no music until "go!"
		S.starting = true
		S.countdown = {elapsed = 0, last = love.timer.getTime(), shown = false}
		stopmusic()
		splitscreen_reset()
		--instasnap cameras to the players as soon as the minigame starts
		if splitscreenactive() and splitscreenviewplayers then
			for i, pn in ipairs(splitscreenviewplayers) do
				local p = objects["player"][pn]
				if p then
					local views = getsplitscreenviews and getsplitscreenviews()
					local view = views and views[i]
					if view then
						splitscreen_updatecamera(i, view, p, nil, 0, true)
					else
						--fallback: set splitcam directly
						local mul = 1
						local vw = (width*16)/math.max(1, #splitscreenviewplayers)/16
						local vh = height
						splitcamx[i] = math.max(0, math.min(mapwidth - vw, p.x + p.width/2 - vw/2))
						splitcamy[i] = math.max(0, math.min(mapheight - vh - 1, (p.y + p.height/2) - vh/2 - 0.5))
					end
				end
			end
		else
			camerasnap(nil, nil, true)
		end
	end,

	update = function(S, dt)
		rrrx.updatebanner(S, dt)

		rrr_updatecountdown(S)

		rrr_updateblocks(S, dt)
		rrr_updatekonami(S)
		rrrx.updateviews(S)

		if S.over then
			S.over.t = S.over.t + dt
			if not S.knockoutend and rrr_updateclear(S, dt) and S.over.t > 1 and not S.finish then
				minigame_finish(S.result, 0, false)
			end
		elseif not S.sdpending then --(time up for sudden death: frozen, see frozenupdate)
			--(the timer only goes down while the battle is on: not once it's over, nor during the countdown)
			if S.timeleft and not S.starting then
				S.timeleft = S.timeleft - dt
				rrrx.updatefinalcount(S)
				if S.timeleft <= 0 then
					S.timeleft = 0
					rrr_timeup(S)
				end
			end
			rrr_updatelowtime(S)
			if not S.over and not S.sdpending then
				rrr_updatecombat(S, dt)
			end
		end

		for i = 1, RRR_PLAYERS do
			local p = objects["player"][i]
			if p and S.bots[i] then
				rrr_botupdate(S, i, p, dt)
			end
			--nobody gets out of the arena sideways
			if p and not p.dead then
				if p.x < 0 then
					p.x = 0
					p.speedx = math.max(0, p.speedx)
				elseif p.x + p.width > mapwidth then
					p.x = mapwidth - p.width
					p.speedx = math.min(0, p.speedx)
				end
			end
		end
	end,

	--while it's frozen (minigame_freeze): banners, wait for sudden death, and death animations (so the last KO finishes)
	frozenupdate = function(S, dt)
		rrrx.updatebanner(S, dt)
		rrrx.updatesdpending(S, dt)
		--keep death animations moving during the freeze before victory / sudden death
		if objects and objects["player"] then
			for _, p in pairs(objects["player"]) do
				if p and (p.dead or p.animation == "death" or p.animation == "deathpit") then
					p:update(dt)
				end
			end
		end
	end,

	drawtiles = function(S)
		rrr_drawblocks(S)
	end,

	drawoverlay = rrr_drawoverlay,

	--after a knockout win the battle clear theme plays on the results screen, which stays up until it's done
	resultmusic = function(S)
		if not S.knockoutend then
			return nil --time up: the clear theme already played in the arena
		end
		rrr_startclear(S)
		local C = S.clear
		local length = 0
		if soundenabled then
			if C.intro then
				length = length + C.intro:getDuration("seconds")
			end
			if C.main then
				length = length + C.main:getDuration("seconds")
			end
		end
		return math.max(RRR_RESULT_TIME, math.min(length, RRR_CLEAR_MAX))
	end,

	resultupdate = function(S, dt)
		if S.knockoutend and S.clear and rrr_updateclear(S, dt) then
			rrr_stopclear(S) --done, or cut off at RRR_CLEAR_MAX
		end
	end,

	resultheadline = function(S)
		if S.winner then
			return "p" .. S.winner .. " wins!"
		end
		return "draw!"
	end,

	cleanup = rrr_cleanup,
})

end --do (rival rumble royale)