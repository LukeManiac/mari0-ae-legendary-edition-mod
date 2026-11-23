--[[
	TAS EDITOR (title screen > utils > tas editor)

	A tool-assisted speedrun editor modelled on FCEUX's TAS Editor. It takes over the whole window: the game on the
	left, the piano roll (one row a frame, one column a key or mouse input) on the right.

	* Greenzone: every frame the editor has run with the current input. Its savestates (see tascore.lua) are kept every
	  TAS_KEYFRAME frames, and thinned out further behind the playback cursor, the same way FCEUX cleans its greenzone.
	  Going to any frame loads the nearest savestate before it and runs the game forward to it, so the editor can
	  always go back.
	* Changing a frame's input throws away the greenzone after it. If the playback cursor was past it, the game is run
	  again from the last good savestate back to where the cursor was.
	* Frame f's input is used going from frame f to frame f+1. The game view shows the state at the playback cursor.

	Projects are saved as alesans_entities/tasprojects/<mappack name>.tasproject (JSON) and exported as
	alesans_entities/tasrecordings/<mappack name>_<date>.mp4 (see tasexport.lua).
]]

require "tascore"
require "tasexport"

local C = tascore

TAS_KEYFRAME = 20 --a savestate every this many frames
TAS_SEEKBUDGET = 0.014 --seconds of seeking a frame
TAS_EXPORTBUDGET = 0.03 --seconds of exporting a frame
TAS_PROJECTFOLDER = "alesans_entities/tasprojects"
TAS_RECORDINGFOLDER = "alesans_entities/tasrecordings"
TAS_FONT = "graphics/fonts/DejaVuSans.ttf" --has the letters of every language the game has (Cyrillic, Turkish, Esperanto...)

local ROWH = 16
local HEADERH = 34
local TOOLBARH = 30

--FCEUX's piano roll colours (taseditor/piano_roll.h, turned from 0xBBGGRR into RGB)
local COL = {
	normalframe = {255, 255, 255}, normal1 = {237, 237, 237}, normal2 = {226, 226, 226},
	greenframe = {221, 255, 221}, green1 = {196, 247, 200}, green2 = {173, 231, 173},
	palegreenframe = {228, 255, 228}, palegreen1 = {210, 249, 211}, palegreen2 = {186, 235, 186},
	curframe = {207, 237, 252}, cur1 = {181, 231, 247}, cur2 = {165, 219, 229},
	desync = {255, 200, 200},
	selected = {51, 153, 255},
}

local E = {} --the editor (a local, so savestates never see it)
tas_editor = E
local font, smallfont, boldfont

local function realtime()
	return C.orig["timer.getTime"] and C.orig["timer.getTime"]() or love.timer.getTime()
end

local function setcolor(c, a)
	love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 255)
end

--the editor's text comes from the language files (languages/*.json), like the rest of the game
local function T(key)
	if TEXT and TEXT[key] and TEXT[key] ~= "" then
		return TEXT[key]
	end
	return key
end
local function TF(key, ...)
	return string.format(T(key), ...)
end

--cuts a text to n characters (not bytes, so it never splits a letter in two)
local function utf8cut(s, n)
	local cut = utf8.offset(s, n + 1)
	if cut then
		return s:sub(1, cut - 1)
	end
	return s
end

local function status(text, bad)
	E.status = {text = text, bad = bad, time = realtime()}
end

------------------------------------------------------------
-- small helpers
------------------------------------------------------------

local function copyinput(i)
	if not i then
		return {k = {}}
	end
	local c = {k = {}, x = i.x, y = i.y, w = i.w}
	for k in pairs(i.k or {}) do
		c.k[k] = true
	end
	if i.b then
		c.b = {}
		for b, v in pairs(i.b) do
			c.b[b] = v
		end
	end
	return c
end

local function deepcopy(t, seen)
	if type(t) ~= "table" then
		return t
	end
	seen = seen or {}
	if seen[t] then
		return seen[t]
	end
	local c = {}
	seen[t] = c
	for k, v in pairs(t) do
		c[deepcopy(k, seen)] = deepcopy(v, seen)
	end
	return c
end

local function safefilename(s)
	s = tostring(s or "mappack"):gsub("[\\/:%*%?\"<>|%c]", "_")
	s = s:gsub("^%s+", ""):gsub("[%s%.]+$", "")
	if s == "" then
		s = "mappack"
	end
	return s
end

--the mappack's name as its settings.txt has it (name=...), or its folder's name
local function mappackdisplayname(folder, pack)
	local path = (folder or mappackfolder) .. "/" .. tostring(pack or mappack) .. "/settings.txt"
	local data = love.filesystem.getInfo(path) and love.filesystem.read(path)
	if data then
		for line in data:gmatch("[^\r\n]+") do
			local name = line:match("^name=(.*)$")
			if name and name ~= "" then
				return name
			end
		end
	end
	return tostring(pack or mappack)
end

local function keylabel(key)
	local short = {space = "spc", ["return"] = "ent", escape = "esc", lshift = "lsh", rshift = "rsh", lctrl = "lct",
		rctrl = "rct", lalt = "lal", ralt = "ral", backspace = "bks", left = "lft", right = "rgt", down = "dwn",
		tab = "tab", up = "up"}
	return short[key] or (#key > 4 and key:sub(1, 4) or key)
end

------------------------------------------------------------
-- JSON (written here for speed: a project can hold tens of thousands of frames)
------------------------------------------------------------

local encodevalue
local function encodestring(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		local map = {['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t'}
		return map[c] or string.format("\\u%04x", c:byte())
	end) .. '"'
end
encodevalue = function(v, out)
	local t = type(v)
	if t == "table" then
		local n = #v
		local isarray = n > 0 or next(v) == nil
		if isarray then
			for k in pairs(v) do
				if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
					isarray = false
					break
				end
			end
		end
		if isarray then
			out[#out+1] = "["
			for i = 1, n do
				if i > 1 then
					out[#out+1] = ","
				end
				encodevalue(v[i], out)
			end
			out[#out+1] = "]"
		else
			out[#out+1] = "{"
			local first = true
			local keys = {}
			for k in pairs(v) do
				keys[#keys+1] = tostring(k)
			end
			table.sort(keys)
			for _, k in ipairs(keys) do
				local val = v[k]
				if val == nil then
					val = v[tonumber(k)]
				end
				if not first then
					out[#out+1] = ","
				end
				first = false
				out[#out+1] = encodestring(k)
				out[#out+1] = ":"
				encodevalue(val, out)
			end
			out[#out+1] = "}"
		end
	elseif t == "string" then
		out[#out+1] = encodestring(v)
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			out[#out+1] = "0"
		elseif v % 1 == 0 and math.abs(v) < 2^53 then
			out[#out+1] = string.format("%d", v)
		else
			out[#out+1] = string.format("%.17g", v)
		end
	elseif t == "boolean" then
		out[#out+1] = v and "true" or "false"
	else
		out[#out+1] = "null"
	end
end
local function encodejson(v)
	local out = {}
	encodevalue(v, out)
	return table.concat(out)
end

------------------------------------------------------------
-- project
------------------------------------------------------------

local function projectpath(name)
	return TAS_PROJECTFOLDER .. "/" .. safefilename(name) .. ".tasproject"
end

--the game's settings a project keeps: players, skins, controls and accessibility
local function capturesettings()
	local s = {players = players}
	s.characters, s.colors, s.hats, s.portalhues = {}, {}, {}, {}
	for i = 1, 4 do
		s.characters[i] = mariocharacter and mariocharacter[i]
		s.colors[i] = mariocolors and deepcopy(mariocolors[i])
		s.hats[i] = mariohats and deepcopy(mariohats[i])
		s.portalhues[i] = portalhues and deepcopy(portalhues[i])
	end
	s.controls = {}
	for page = 1, 4 do
		local name = page == 1 and "controls" or "controls" .. page
		s.controls[page] = deepcopy(_G[name])
	end
	s.accessibility = deepcopy(accessibility)
	return s
end

local function applysettings(s)
	if not s then
		return
	end
	players = s.players or players
	for i = 1, 4 do
		if mariocharacter and s.characters and s.characters[i] then
			mariocharacter[i] = s.characters[i]
		end
		if mariocolors and s.colors and s.colors[i] then
			mariocolors[i] = deepcopy(s.colors[i])
		end
		if mariohats and s.hats and s.hats[i] then
			mariohats[i] = deepcopy(s.hats[i])
		end
		if portalhues and s.portalhues and s.portalhues[i] then
			portalhues[i] = deepcopy(s.portalhues[i])
		end
	end
	if s.controls then
		for page = 1, 4 do
			local name = page == 1 and "controls" or "controls" .. page
			if s.controls[page] then
				_G[name] = deepcopy(s.controls[page])
			end
		end
	end
	if s.accessibility and accessibility then
		for k, v in pairs(s.accessibility) do
			accessibility[k] = deepcopy(v)
		end
	end
	if setcustomplayer and mariocharacter then
		for i = 1, players or 1 do
			if mariocharacter[i] then
				pcall(setcustomplayer, mariocharacter[i], i, true)
			end
		end
	end
end

--the keys the players' controls use, in order: {key, label}
local function controlkeys()
	local list, seen = {}, {}
	local order = {"left", "right", "up", "down", "run", "jump", "reload", "use", "portal1", "portal2", "pause"}
	for page = 1, 4 do
		local set = _G[page == 1 and "controls" or "controls" .. page]
		if type(set) == "table" then
			for p = 1, math.max(1, players or 1) do
				local c = set[p]
				if type(c) == "table" then
					for _, action in ipairs(order) do
						local entry = c[action]
						if type(entry) == "table" and type(entry[1]) == "string" and entry[1] ~= "" and entry[1] ~= "joy" then
							local key = C.normalkey(entry[1])
							if not seen[key] then
								seen[key] = true
								list[#list+1] = {key = key, action = action, player = p}
							end
						end
					end
				end
			end
		end
	end
	for _, key in ipairs({"return", "escape"}) do
		if not seen[key] then
			seen[key] = true
			list[#list+1] = {key = key, action = key == "return" and "menu" or "back", player = 1}
		end
	end
	return list
end

local function newproject()
	local name = mappackdisplayname()
	local p = {
		version = 1,
		name = name,
		mappack = mappack,
		mappackfolder = mappackfolder,
		seed = math.floor((C.orig["os.time"] or os.time)() % 2147483647),
		epoch = (C.orig["os.time"] or os.time)(),
		created = (C.orig["os.date"] or os.date)("%Y-%m-%d %H:%M:%S"),
		settings = capturesettings(),
		columns = {},
		frames = {},
		states = {},
		rng = {},
		exportscale = 2,
	}
	for _, c in ipairs(controlkeys()) do
		p.columns[#p.columns+1] = {kind = "key", key = c.key, action = c.action, player = c.player}
	end
	return p
end

--the columns of the piano roll: the project's key columns, then the mouse
local MOUSECOLUMNS = {
	{kind = "button", b = 1, label = "lmb", width = 30},
	{kind = "button", b = 2, label = "rmb", width = 30},
	{kind = "button", b = 3, label = "mmb", width = 30},
	{kind = "mx", label = "x", width = 38},
	{kind = "my", label = "y", width = 38},
	{kind = "wheel", label = "whl", width = 30},
}

local function rebuildcolumns()
	local cols = {}
	local seen = {}
	for _, c in ipairs(E.project.columns) do
		--columns saved with a plain label ("jump", "p2 jump") get their action and player back, so they're translated
		if c.kind == "key" and not c.action and c.label and c.label ~= "" then
			local player, action = c.label:match("^p(%d) (.+)$")
			c.action, c.player = action or c.label, tonumber(player) or 1
		end
		if c.kind == "key" and not seen[c.key] then
			seen[c.key] = true
			cols[#cols+1] = {kind = "key", key = c.key, action = c.action, player = c.player, label = c.label or "", width = 34}
		end
	end
	--every key a frame uses has a column
	for _, f in ipairs(E.project.frames) do
		for key in pairs(f.k or {}) do
			if not seen[key] then
				seen[key] = true
				E.project.columns[#E.project.columns+1] = {kind = "key", key = key, label = ""}
				cols[#cols+1] = {kind = "key", key = key, label = "", width = 34}
			end
		end
	end
	for _, c in ipairs(MOUSECOLUMNS) do
		cols[#cols+1] = c
	end
	cols[#cols+1] = {kind = "add", label = "+", width = 22}
	E.columns = cols
end

local function framesfromjson(list)
	local frames = {}
	for i, f in ipairs(list or {}) do
		local fr = {k = {}}
		for _, key in ipairs(f.k or {}) do
			fr.k[key] = true
		end
		fr.x, fr.y = tonumber(f.x), tonumber(f.y)
		if f.b and #f.b > 0 then
			fr.b = {}
			for _, b in ipairs(f.b) do
				fr.b[b] = true
			end
		end
		if tonumber(f.w) and tonumber(f.w) ~= 0 then
			fr.w = tonumber(f.w)
		end
		frames[i] = fr
	end
	return frames
end

local function framestojson(frames)
	local list = {}
	for i, f in ipairs(frames) do
		local o = {}
		local keys = {}
		for k in pairs(f.k or {}) do
			keys[#keys+1] = k
		end
		table.sort(keys)
		if #keys > 0 then
			o.k = keys
		end
		o.x, o.y = f.x, f.y
		if f.b then
			local bs = {}
			for b in pairs(f.b) do
				bs[#bs+1] = b
			end
			table.sort(bs)
			if #bs > 0 then
				o.b = bs
			end
		end
		if f.w and f.w ~= 0 then
			o.w = f.w
		end
		list[i] = o
	end
	return list
end

------------------------------------------------------------
-- greenzone and playback
------------------------------------------------------------

local function inputat(f)
	return E.project.frames[f+1] or {k = {}}
end

--throws away everything known after frame `after` (its input changed)
local function invalidate(after)
	if after < 0 then
		after = 0
	end
	for f in pairs(E.greenzone) do
		if f > after and f ~= 0 then
			E.greenzone[f] = nil
		end
	end
	for f in pairs(E.summaries) do
		if f > after then
			E.summaries[f] = nil
		end
	end
	for f in pairs(E.rngouts) do
		if f >= after then
			E.rngouts[f] = nil
		end
	end
	if E.desync and E.desync > after then
		E.desync = nil
	end
	if E.gzsize > after + 1 then
		E.gzsize = after + 1
		E.rerecords = E.rerecords + 1
	end
	--the game state now is past the change: it has to be made again, then go back to where it was
	if C.frame > after then
		E.lastposition = math.max(E.lastposition or 0, C.frame)
		E.statevalid = false
	end
	E.dirty = true
end

--the newest savestate at or before frame f
local function keyframebefore(f)
	local best = 0
	for k in pairs(E.greenzone) do
		if k <= f and k > best and k < E.gzsize then
			best = k
		end
	end
	return best
end

local function loadframe(k)
	C.load(E.greenzone[k])
	E.lastsnap = E.greenzone[k]
	E.statevalid = true
	E.needsdraw = true
end

--thins out savestates far behind the playback cursor (like FCEUX's greenzone cleaning)
local function cleangreenzone()
	local cur = C.frame
	for k in pairs(E.greenzone) do
		if k ~= 0 then
			local behind = cur - k
			local keep = true
			if behind > 18000 then
				keep = k % 1800 == 0
			elseif behind > 3600 then
				keep = k % 300 == 0
			elseif behind > 600 then
				keep = k % 60 == 0
			end
			if not keep then
				E.greenzone[k] = nil
			end
		end
	end
	E.nextclean = realtime() + 2
end

--runs one frame from the playback cursor with its input. Returns false if the game broke
local function stepframe(record)
	local f = C.frame
	if record then
		E.recordframe(f)
	end
	local input = inputat(f)
	local x, y = C.mouseat(E.project.frames, f+1)
	local ok, err = C.step(input, x, y)
	if not ok then
		E.playing = false
		E.pauseframe = nil
		E.exportfailed = err
		status(TF("the game broke at frame %d: %s", f, tostring(err):match("[^\n]*")), true)
		print(err)
		--go back to a state that works
		C.frame = f
		loadframe(keyframebefore(f))
		E.target = nil
		return false
	end
	local now = C.frame
	E.rngouts[f] = C.rngout
	local s = C.summary()
	local expected = E.summaries[now] or (E.expected and E.expected[now])
	if expected and not C.samesummary(s, expected) and not E.desync then
		E.desync = now
		status(TF("desync: frame %d plays differently than before", now), true)
	end
	E.summaries[now] = s
	if E.statevalid and E.gzsize <= now then
		E.gzsize = now + 1
	end
	if now % TAS_KEYFRAME == 0 and not E.greenzone[now] then
		E.greenzone[now] = C.save(E.lastsnap)
		E.lastsnap = E.greenzone[now]
	end
	E.needsdraw = true
	return true
end

--sends the playback cursor to frame f (seeking forward from the nearest savestate if it has to)
local function jump(f, keepplaying)
	f = math.max(0, math.floor(f))
	--the nearest savestate before f, unless the game is already between it and f
	local k = keyframebefore(f)
	if not E.statevalid or f < C.frame or k > C.frame then
		loadframe(k)
	end
	if f > C.frame then
		E.target = f
	else
		E.target = nil
	end
	if not keepplaying then
		E.playing = false
	end
	E.needsdraw = true
	E.followcursor = true
end
E.jump = jump

local function seeking()
	return E.target ~= nil
end

--runs the game towards the seek target for a share of this frame
local function updateseek()
	if not E.target then
		return
	end
	C.setmuted(true)
	local start = realtime()
	while E.target and C.frame < E.target do
		if not stepframe(false) then
			return
		end
		if realtime() - start > TAS_SEEKBUDGET then
			break
		end
	end
	if E.target and C.frame >= E.target then
		E.target = nil
		E.followcursor = true
	end
	if not E.target then
		C.setmuted(false)
	end
end

------------------------------------------------------------
-- editing input (every change goes through apply, so it can be undone)
------------------------------------------------------------

--replaces count frames from frame first with the list of new frames. Returns a history step
local function replace(first, count, new)
	local frames = E.project.frames
	--frames past the end of the movie exist as empty frames when they're edited
	while #frames < first do
		frames[#frames+1] = {k = {}}
	end
	local old = {}
	for i = 1, count do
		old[i] = frames[first+i] and copyinput(frames[first+i]) or {k = {}}
	end
	if count == #new then
		for i = 1, count do
			frames[first+i] = copyinput(new[i])
		end
	else
		for i = 1, count do
			table.remove(frames, first+1)
		end
		for i = #new, 1, -1 do
			table.insert(frames, first+1, copyinput(new[i]))
		end
	end
	return {first = first, count = #new, old = old, new = new, oldcount = count}
end

local function sortframes(list)
	table.sort(list)
	return list
end

--a history entry: {name, steps = {replace steps in the order they were done}}
local function pushhistory(name, steps, merge)
	if #steps == 0 then
		return
	end
	local h = E.history
	for i = #h.list, h.pos + 1, -1 do
		h.list[i] = nil
	end
	local top = h.list[h.pos]
	if merge and top and top.merge == merge then
		for _, s in ipairs(steps) do
			top.steps[#top.steps+1] = s
		end
	else
		h.list[#h.list+1] = {name = name, steps = steps, merge = merge}
		if #h.list > 500 then
			table.remove(h.list, 1)
		end
		h.pos = #h.list
	end
	local first = math.huge
	for _, s in ipairs(steps) do
		first = math.min(first, s.first)
	end
	invalidate(first)
	rebuildcolumns()
end

local function undo()
	local h = E.history
	local entry = h.list[h.pos]
	if not entry then
		status(T("nothing to undo"))
		return
	end
	local first = math.huge
	for i = #entry.steps, 1, -1 do
		local s = entry.steps[i]
		replace(s.first, s.count, s.old)
		first = math.min(first, s.first)
	end
	h.pos = h.pos - 1
	invalidate(first)
	rebuildcolumns()
	status(TF("undid: %s", T(entry.name)))
end

local function redo()
	local h = E.history
	local entry = h.list[h.pos + 1]
	if not entry then
		status(T("nothing to redo"))
		return
	end
	local first = math.huge
	for _, s in ipairs(entry.steps) do
		replace(s.first, s.oldcount, s.new)
		first = math.min(first, s.first)
	end
	h.pos = h.pos + 1
	invalidate(first)
	rebuildcolumns()
	status(TF("redid: %s", T(entry.name)))
end

--changes one input of the given frames: fn(copy of the frame's input) changes it
local function editframes(name, list, fn, merge)
	local steps = {}
	for _, f in ipairs(list) do
		local new = copyinput(inputat(f))
		fn(new, f)
		steps[#steps+1] = replace(f, 1, {new})
	end
	pushhistory(name, steps, merge)
end

local function selectedlist()
	local list = {}
	for f in pairs(E.selection) do
		list[#list+1] = f
	end
	return sortframes(list)
end

local function selectonly(f)
	E.selection = {[f] = true}
	E.anchor = f
end

local function selectrange(a, b)
	E.selection = {}
	for f = math.min(a, b), math.max(a, b) do
		E.selection[f] = true
	end
end

local function cellvalue(col, f)
	local input = inputat(f)
	if col.kind == "key" then
		return input.k and input.k[col.key] or false
	elseif col.kind == "button" then
		return input.b and input.b[col.b] or false
	end
end

local function setcell(input, col, value)
	if col.kind == "key" then
		input.k = input.k or {}
		input.k[col.key] = value or nil
	elseif col.kind == "button" then
		input.b = input.b or {}
		input.b[col.b] = value or nil
		if not next(input.b) then
			input.b = nil
		end
	end
end

--the frames the playback cursor or selection means: the selection, or the playback frame
local function targetframes()
	local list = selectedlist()
	if #list == 0 then
		list = {C.frame}
	end
	return list
end

local function clearselected()
	local list = selectedlist()
	if #list == 0 then
		return
	end
	editframes("clear frames", list, function(input)
		input.k = {}
		input.b, input.x, input.y, input.w = nil, nil, nil, nil
	end)
end

local function deleteselected()
	local list = selectedlist()
	if #list == 0 then
		return
	end
	local steps = {}
	for i = #list, 1, -1 do
		if list[i] < #E.project.frames then
			steps[#steps+1] = replace(list[i], 1, {})
		end
	end
	pushhistory("delete frames", steps)
	selectonly(list[1])
end

local function insertblank()
	local list = selectedlist()
	local at = list[1] or C.frame
	local new = {}
	for i = 1, math.max(1, #list) do
		new[i] = {k = {}}
	end
	pushhistory("insert frames", {replace(at, 0, new)})
	selectrange(at, at + #new - 1)
end

local function cloneselected()
	local list = selectedlist()
	if #list == 0 then
		return
	end
	--each run of selected frames is copied right after itself, from the bottom up
	local runs = {}
	for _, f in ipairs(list) do
		local r = runs[#runs]
		if r and f == r[2] + 1 then
			r[2] = f
		else
			runs[#runs+1] = {f, f}
		end
	end
	local steps = {}
	for i = #runs, 1, -1 do
		local a, b = runs[i][1], runs[i][2]
		local new = {}
		for f = a, b do
			new[#new+1] = copyinput(inputat(f))
		end
		steps[#steps+1] = replace(b + 1, 0, new)
	end
	pushhistory("clone frames", steps)
end

local function copyselected()
	local list = selectedlist()
	if #list == 0 then
		return false
	end
	E.clipboard = {}
	for _, f in ipairs(list) do
		E.clipboard[#E.clipboard+1] = copyinput(inputat(f))
	end
	status(TF("copied frames: %d", #list))
	return true
end

local function paste(insert)
	if not E.clipboard or #E.clipboard == 0 then
		status(T("nothing to paste"))
		return
	end
	local at = selectedlist()[1] or C.frame
	if insert then
		pushhistory("paste insert", {replace(at, 0, E.clipboard)})
	else
		pushhistory("paste", {replace(at, math.min(#E.clipboard, math.max(0, #E.project.frames - at)), E.clipboard)})
	end
	selectrange(at, at + #E.clipboard - 1)
end

--recording: the real keyboard and mouse become this frame's input
function E.recordframe(f)
	local input = {k = {}}
	for key in pairs(E.realheld) do
		input.k[key] = true
	end
	if E.mouseingame then
		input.x, input.y = E.mouseingame[1], E.mouseingame[2]
		for b in pairs(E.realbuttons) do
			input.b = input.b or {}
			input.b[b] = true
		end
	end
	if E.realwheel ~= 0 then
		input.w = E.realwheel
		E.realwheel = 0
	end
	local old = inputat(f)
	local same = true
	for k in pairs(input.k) do
		if not old.k[k] then same = false end
	end
	for k in pairs(old.k or {}) do
		if not input.k[k] then same = false end
	end
	if input.x ~= nil and (input.x ~= old.x or input.y ~= old.y) then same = false end
	if (input.b and next(input.b)) or (old.b and next(old.b)) or input.w then same = false end
	if f >= #E.project.frames then same = false end
	if not same then
		--recorded frames are one undo step for each time recording is turned on
		local s = replace(f, f < #E.project.frames and 1 or 0, {input})
		if s.oldcount == 0 then
			s.oldcount = 0
		end
		local h = E.history
		for i = #h.list, h.pos + 1, -1 do
			h.list[i] = nil
		end
		local top = h.list[h.pos]
		if top and top.merge == E.recordsession then
			top.steps[#top.steps+1] = s
		else
			h.list[#h.list+1] = {name = "record", steps = {s}, merge = E.recordsession}
			h.pos = #h.list
		end
		--only what comes after this frame is out of date (the game is about to run this frame with it)
		for g in pairs(E.greenzone) do
			if g > f then E.greenzone[g] = nil end
		end
		for g in pairs(E.summaries) do
			if g > f then E.summaries[g] = nil end
		end
		if E.gzsize > f + 1 then
			E.gzsize = f + 1
		end
		E.dirty = true
		rebuildcolumns()
	end
end

------------------------------------------------------------
-- opening, saving and closing
------------------------------------------------------------

--starts the project's game from frame 0
local function startproject(project, path)
	C.load(E.home)
	E.project = project
	E.path = path
	E.greenzone, E.summaries, E.rngouts = {}, {}, {}
	E.expected = nil
	E.gzsize = 1
	E.rerecords = project.rerecords or 0
	E.history = {list = {}, pos = 0}
	E.selection, E.anchor = {}, nil
	E.scroll, E.target, E.playing, E.recording = 0, nil, false, false
	E.desync, E.lastposition, E.dirty = nil, nil, false
	project.frames = project.frames or {}
	project.columns = project.columns or {}

	--the game as it starts: the project's mappack, settings, random numbers and clock
	if project.mappack then
		mappack = project.mappack
		if mappacklist then
			for i, name in ipairs(mappacklist) do
				if name == mappack then
					mappackselection = i
				end
			end
		end
	end
	C.gen = love.math.newRandomGenerator(project.seed or 1)
	C.epoch = project.epoch or 0
	C.frame = 0
	C.lastinput = {k = {}, x = 0, y = 0, b = {}}
	C.messages = {}
	local ok, err = C.run(function()
		applysettings(project.settings)
		menu_load()
	end)
	if not ok then
		status(TF("couldn't start the game: %s", tostring(err):match("[^\n]*")), true)
		print(err)
	end
	E.greenzone[0] = C.save()
	E.lastsnap = E.greenzone[0]
	E.summaries[0] = C.summary()
	E.statevalid = true
	--what the saved project says each frame looks like: frames that play differently are a desync
	if project.states and #project.states > 0 then
		E.expected = {}
		for i, s in ipairs(project.states) do
			E.expected[i-1] = s
		end
	end
	for i, out in ipairs(project.rng or {}) do
		E.rngouts[i-1] = out
	end
	rebuildcolumns()
	E.needsdraw = true
	E.nextclean = realtime() + 2
end

local function saveproject()
	local p = E.project
	--the frame states and random numbers of every frame the greenzone has (frames 0 to gzsize-1)
	local states, rng = {}, {}
	for f = 0, E.gzsize - 1 do
		states[f+1] = E.summaries[f] or (E.expected and E.expected[f]) or {}
		rng[f+1] = E.rngouts[f] or {}
	end
	local data = {
		version = p.version or 1, name = p.name, mappack = p.mappack, mappackfolder = p.mappackfolder,
		seed = p.seed, epoch = p.epoch, created = p.created, saved = (C.orig["os.date"] or os.date)("%Y-%m-%d %H:%M:%S"),
		settings = p.settings, columns = p.columns, frames = framestojson(p.frames), states = states, rng = rng,
		exportscale = p.exportscale, rerecords = E.rerecords, playback = C.frame,
	}
	love.filesystem.createDirectory(TAS_PROJECTFOLDER)
	local path = projectpath(p.name)
	local ok, err = love.filesystem.write(path, encodejson(data))
	if ok then
		E.path = path
		E.dirty = false
		status(TF("saved %s", path))
	else
		status(TF("couldn't save: %s", tostring(err)), true)
	end
end

local function readproject(path)
	local data = love.filesystem.read(path)
	if not data then
		return nil, TF("couldn't read %s", path)
	end
	local ok, p = pcall(function() return JSON:decode(data) end)
	if not ok or type(p) ~= "table" then
		return nil, T("that isn't a tas project")
	end
	p.frames = framesfromjson(p.frames)
	p.columns = p.columns or {}
	p.name = p.name or path:match("([^/]+)%.tasproject$")
	return p
end

local function openproject(path)
	local p, err = readproject(path)
	if not p then
		status(err, true)
		return
	end
	if p.mappack and mappackfolder and not love.filesystem.getInfo((p.mappackfolder or mappackfolder) .. "/" .. p.mappack) then
		status(TF("the mappack \"%s\" isn't here: the game might not play the same", tostring(p.mappack)), true)
	end
	startproject(p, path)
	local back = tonumber(p.playback)
	if back and back > 0 then
		jump(back)
	end
	status(TF("opened %s", path))
end

local function listprojects()
	local list = {}
	for _, item in ipairs(love.filesystem.getDirectoryItems(TAS_PROJECTFOLDER)) do
		if item:match("%.tasproject$") then
			list[#list+1] = item
		end
	end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

------------------------------------------------------------
-- export
------------------------------------------------------------

local function exportpath()
	love.filesystem.createDirectory(TAS_RECORDINGFOLDER)
	local base = TAS_RECORDINGFOLDER .. "/" .. safefilename(E.project.name) .. "_" .. (C.orig["os.date"] or os.date)("%Y%m%d")
	local path = base .. ".mp4"
	local n = 2
	while love.filesystem.getInfo(path) do
		path = base .. "_" .. n .. ".mp4"
		n = n + 1
	end
	return path
end

local function startexport()
	if E.export then
		return
	end
	local total = math.max(1, #E.project.frames)
	local e = E.project.exportscale or 2
	local w, h = width*16*e, height*16*e
	local path = exportpath()
	local enc, err = tasexport.new(path, w, h, C.FPS)
	if not enc then
		status(TF("couldn't export: %s", tostring(err)), true)
		return
	end
	E.export = {enc = enc, path = path, total = total, done = 0, back = C.frame, scale = e, w = w, h = h, phase = "frames"}
	E.export.canvas = love.graphics.newCanvas(w, h)
	E.playing, E.target = false, nil
	loadframe(0)
	C.setmuted(true)
	status(TF("exporting to %s", path))
end

local function endexport(cancelled)
	local x = E.export
	E.export = nil
	C.setmuted(false)
	if cancelled then
		x.enc:abort()
		status(T("export cancelled"))
	end
	--back to where the playback cursor was
	E.statevalid = false
	jump(x.back)
end

local function updateexport()
	local x = E.export
	local start = realtime()
	if x.phase == "frames" then
		while x.done < x.total and realtime() - start < TAS_EXPORTBUDGET do
			if not stepframe(false) then
				x.enc:abort()
				E.export = nil
				C.setmuted(false)
				status(TF("export stopped: the game broke at frame %d", C.frame), true)
				return
			end
			E.gamecanvas = C.drawgame(E.gamecanvas)
			love.graphics.push("all")
			love.graphics.setCanvas(x.canvas)
			love.graphics.clear(0, 0, 0, 255)
			love.graphics.origin()
			love.graphics.setColor(255, 255, 255, 255)
			love.graphics.setBlendMode("replace", "premultiplied")
			E.gamecanvas:setFilter("nearest", "nearest")
			love.graphics.draw(E.gamecanvas, 0, 0, 0, x.w/E.gamecanvas:getWidth(), x.h/E.gamecanvas:getHeight())
			love.graphics.pop()
			local ok, err = pcall(x.enc.frame, x.enc, x.canvas:newImageData())
			if not ok then
				x.enc:abort()
				E.export = nil
				C.setmuted(false)
				status(TF("export failed: %s", tostring(err)), true)
				return
			end
			x.done = x.done + 1
		end
		if x.done >= x.total then
			x.phase = "finish"
		end
	elseif x.phase == "finish" then
		local ok, done = pcall(x.enc.finishstep, x.enc, TAS_EXPORTBUDGET)
		if not ok then
			x.enc:abort()
			E.export = nil
			C.setmuted(false)
			status(TF("export failed: %s", tostring(done)), true)
			return
		end
		if done then
			endexport(false)
			status(TF("exported %s (%.1f mb)", x.path, (x.enc.bytes or 0)/1048576))
		end
	end
end

------------------------------------------------------------
-- layout
------------------------------------------------------------

local function layout()
	local W, H = love.graphics.getDimensions()
	local L = {W = W, H = H}
	L.leftw = math.floor(math.max(320, W*0.5))
	local gw, gh = width*16, height*16
	local availw, availh = L.leftw - 16, H - TOOLBARH - 8 - 150
	local s = math.min(availw/gw, availh/gh)
	if s >= 1 then
		s = math.floor(s*2)/2
	end
	L.gs = s
	L.gx, L.gy = 8 + math.floor((availw - gw*s)/2), TOOLBARH + 8
	L.gw, L.gh = gw*s, gh*s
	L.infoy = L.gy + L.gh + 8
	L.rollx = L.leftw
	L.rolly = TOOLBARH
	L.rollw = W - L.leftw
	L.rollh = H - TOOLBARH
	L.rows = math.max(1, math.floor((L.rollh - HEADERH)/ROWH))
	--columns: arrows, frame number, then the input columns (narrowed if they don't fit)
	L.iconw, L.framew = 18, 58
	local total = 0
	for _, c in ipairs(E.columns) do
		total = total + c.width
	end
	local room = L.rollw - L.iconw - L.framew - 14
	L.colscale = math.min(1, room/math.max(total, 1))
	local x = L.rollx + L.iconw + L.framew
	L.colx = {}
	for i, c in ipairs(E.columns) do
		L.colx[i] = {x, math.max(12, math.floor(c.width*L.colscale))}
		x = x + L.colx[i][2]
	end
	L.rollend = x
	E.L = L
	return L
end

local TOOLBAR = {
	{id = "new", text = "new"}, {id = "open", text = "open"}, {id = "save", text = "save"},
	{id = "export", text = "export mp4"}, {id = "scale", text = "size"},
	{gap = true},
	{id = "start", text = "|<"}, {id = "back", text = "<"}, {id = "play", text = "play"}, {id = "forward", text = ">"},
	{id = "end", text = ">|"}, {id = "record", text = "rec"},
	{gap = true},
	{id = "close", text = "close"},
}

local function toolbarrects()
	local rects = {}
	local x = 6
	for _, b in ipairs(TOOLBAR) do
		if b.gap then
			x = x + 12
		else
			local text = b.text:match("^[|<>]+$") and b.text or T(b.text)
			if b.id == "play" then
				text = T((E.playing or seeking()) and "pause" or "play")
			elseif b.id == "scale" then
				text = TF("size %dx", E.project.exportscale or 2)
			end
			local w = font:getWidth(text) + 16
			rects[#rects+1] = {id = b.id, text = text, x = x, y = 4, w = w, h = TOOLBARH - 8}
			x = x + w + 4
		end
	end
	return rects
end

E.toolbarrects = function() return toolbarrects() end

local function rowat(y)
	local L = E.L
	if y < L.rolly + HEADERH then
		return nil
	end
	return E.scroll + math.floor((y - L.rolly - HEADERH)/ROWH)
end

local function columnat(x)
	local L = E.L
	if x < L.rollx + L.iconw then
		return "icons"
	elseif x < L.rollx + L.iconw + L.framew then
		return "frame"
	end
	for i, c in ipairs(L.colx) do
		if x >= c[1] and x < c[1] + c[2] then
			return i
		end
	end
	return nil
end

local function rowcount()
	return math.max(#E.project.frames, C.frame + 1, (E.target or 0) + 1) + 1
end

local function followcursor()
	local L = E.L
	if not L then
		return
	end
	local f = C.frame
	if f < E.scroll or f >= E.scroll + L.rows then
		E.scroll = math.max(0, f - math.floor(L.rows/2))
	end
end

local function clampscroll()
	local L = E.L
	E.scroll = math.max(0, math.min(E.scroll, rowcount() - math.floor(L.rows/2)))
end

------------------------------------------------------------
-- drawing
------------------------------------------------------------

local function drawbutton(r, active, hot)
	if active then
		love.graphics.setColor(70, 110, 170)
	elseif hot then
		love.graphics.setColor(80, 80, 90)
	else
		love.graphics.setColor(55, 55, 62)
	end
	love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
	love.graphics.setColor(230, 230, 230)
	love.graphics.print(r.text, r.x + 8, r.y + math.floor((r.h - font:getHeight())/2))
end

local function drawgameview(L)
	if E.needsdraw or not E.gamecanvas then
		local canvas, ok, err = C.drawgame(E.gamecanvas)
		E.gamecanvas = canvas
		E.needsdraw = false
		if not ok then
			E.drawerror = err
		else
			E.drawerror = nil
		end
	end
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", L.gx - 2, L.gy - 2, L.gw + 4, L.gh + 4)
	love.graphics.setColor(255, 255, 255)
	E.gamecanvas:setFilter("nearest", "nearest")
	love.graphics.draw(E.gamecanvas, L.gx, L.gy, 0, L.gw/E.gamecanvas:getWidth(), L.gh/E.gamecanvas:getHeight())
	--where the game sees the mouse this frame
	local mx, my = C.mouseat(E.project.frames, C.frame + 1)
	local cx, cy = L.gx + mx*L.gs, L.gy + my*L.gs
	love.graphics.setColor(255, 60, 60, 220)
	love.graphics.setLineWidth(1)
	love.graphics.line(cx - 6, cy, cx - 2, cy)
	love.graphics.line(cx + 2, cy, cx + 6, cy)
	love.graphics.line(cx, cy - 6, cx, cy - 2)
	love.graphics.line(cx, cy + 2, cx, cy + 6)
	if E.drawerror then
		love.graphics.setColor(255, 80, 80)
		love.graphics.printf(T("the game couldn't be drawn:") .. "\n" .. tostring(E.drawerror):match("[^\n]*"), L.gx + 8, L.gy + 8, L.gw - 16)
	end
	if E.recording then
		love.graphics.setColor(220, 30, 30)
		love.graphics.circle("fill", L.gx + L.gw - 14, L.gy + 14, 6)
	end
end

local function drawinfo(L)
	local x, y = 10, L.infoy
	local lh = font:getHeight() + 2
	love.graphics.setColor(235, 235, 235)
	local state = E.export and T("exporting") or (seeking() and TF("seeking to %d", E.target)) or T(E.playing and "playing" or "paused")
	local w = L.leftw - 20
	local function line(text)
		love.graphics.printf(text, x, y, w)
		local _, lines = font:getWrap(text, w)
		y = y + lh*math.max(1, #lines)
	end
	line(table.concat({TF("frame %d / %d", C.frame, #E.project.frames), state, TF("greenzone 0-%d", E.gzsize - 1), TF("rerecords %d", E.rerecords)}, "   "))
	local s = E.summaries[C.frame]
	local text = TF("state: %s", tostring(gamestate))
	if s and s.p and s.p[1] then
		local p = s.p[1]
		local n = function(v) return string.format("%.4f", v or 0) end
		text = text .. "   " .. tostring(s.w or "?") .. "-" .. tostring(s.l or "?") .. "   " .. TF("p1 x %s  y %s   speed %s, %s", n(p.x), n(p.y), n(p.sx), n(p.sy))
	end
	line(text)
	local out = E.rngouts[C.frame - 1]
	local numbers
	if out and #out > 0 then
		local parts = {}
		for i = 1, math.min(#out, 8) do
			local v = out[i]
			parts[i] = (v % 1 == 0) and tostring(v) or string.format("%.4f", v)
		end
		numbers = #out .. " (" .. table.concat(parts, ", ") .. (#out > 8 and ", ..." or "") .. ")"
	else
		numbers = T("none")
	end
	line(TF("random numbers last frame: %s", numbers))
	local name = E.project.name .. (E.dirty and " *" or "")
	love.graphics.setColor(170, 170, 180)
	line(TF("project: %s   mappack: %s", name, tostring(E.project.mappack)))
	if E.export then
		local x2 = E.export
		local p = x2.phase == "finish" and (x2.enc.finishprogress and x2.enc:finishprogress() or 1) or x2.done/x2.total
		local bw = L.leftw - 20
		love.graphics.setColor(40, 40, 45)
		love.graphics.rectangle("fill", x, y + 2, bw, 16, 3, 3)
		love.graphics.setColor(80, 170, 90)
		love.graphics.rectangle("fill", x, y + 2, bw*p, 16, 3, 3)
		love.graphics.setColor(255, 255, 255)
		local text = x2.phase == "finish" and TF("finishing the mp4... %d%%", math.floor(p*100))
			or TF("exporting frame %d / %d (%d%%)   esc: cancel", x2.done, x2.total, math.floor(p*100))
		love.graphics.print(text, x + 6, y + 3)
		y = y + 22
	end
	if E.status then
		if E.status.bad then
			love.graphics.setColor(255, 110, 110)
		else
			love.graphics.setColor(140, 220, 140)
		end
		love.graphics.printf(E.status.text, x, y, L.leftw - 20)
		y = y + lh*2
	end
	love.graphics.setColor(130, 130, 140)
	local help = T("\\ next frame   backspace previous frame   space play/pause   enter go to the selected frame") .. "\n"
		.. T("click: select   shift: select up to   ctrl: add/remove   click the game: set the mouse there") .. "\n"
		.. T("ins insert   ctrl+ins clone   del clear   ctrl+del delete   ctrl+c/x/v   ctrl+z/y   ctrl+r record")
	love.graphics.setFont(smallfont)
	local _, helplines = smallfont:getWrap(help, L.leftw - 20)
	love.graphics.printf(help, x, math.max(y, L.H - smallfont:getHeight()*#helplines - 8), L.leftw - 20)
	love.graphics.setFont(font)
end

local function drawroll(L)
	local x0, y0 = L.rollx, L.rolly
	love.graphics.setScissor(x0, y0, L.rollw, L.rollh)
	love.graphics.setColor(250, 250, 250)
	love.graphics.rectangle("fill", x0, y0, L.rollw, L.rollh)

	--header
	love.graphics.setColor(232, 232, 236)
	love.graphics.rectangle("fill", x0, y0, L.rollw, HEADERH)
	love.graphics.setColor(40, 40, 40)
	love.graphics.setFont(smallfont)
	love.graphics.print(T("frame#"), x0 + L.iconw + 4, y0 + 10)
	local sel = selectedlist()
	for i, c in ipairs(E.columns) do
		local cx, cw = L.colx[i][1], L.colx[i][2]
		if E.headerflash and E.headerflash.col == i and realtime() < E.headerflash.until_ then
			love.graphics.setColor(255, 230, 150)
			love.graphics.rectangle("fill", cx, y0, cw, HEADERH)
		end
		love.graphics.setColor(200, 200, 205)
		love.graphics.line(cx + 0.5, y0, cx + 0.5, y0 + L.rollh)
		love.graphics.setColor(30, 30, 30)
		local top = c.kind == "key" and keylabel(c.key) or (c.kind == "button" or c.kind == "wheel") and utf8cut(T(c.label), 4) or c.label
		love.graphics.printf(top, cx, y0 + 4, cw, "center")
		local under
		if c.kind == "key" and c.action then
			under = (c.player or 1) > 1 and TF("p%d %s", c.player, T(c.action)) or T(c.action)
		elseif c.kind == "key" then
			under = c.label --projects from before columns kept their action
		elseif c.kind ~= "add" then
			under = T("mouse")
		end
		if under and under ~= "" then
			love.graphics.setColor(110, 110, 120)
			love.graphics.printf(utf8cut(under, 6), cx, y0 + 18, cw, "center")
		end
	end
	love.graphics.setColor(180, 180, 185)
	love.graphics.line(x0, y0 + HEADERH - 0.5, x0 + L.rollw, y0 + HEADERH - 0.5)

	--rows
	local total = rowcount()
	for r = 0, L.rows - 1 do
		local f = E.scroll + r
		if f >= total then
			break
		end
		local y = y0 + HEADERH + r*ROWH
		local isplay = (f == C.frame)
		local ingreen = f < E.gzsize
		local frameband, c1, c2
		if isplay then
			frameband, c1, c2 = COL.curframe, COL.cur1, COL.cur2
		elseif ingreen and E.greenzone[f] then
			frameband, c1, c2 = COL.greenframe, COL.green1, COL.green2
		elseif ingreen then
			frameband, c1, c2 = COL.palegreenframe, COL.palegreen1, COL.palegreen2
		else
			frameband, c1, c2 = COL.normalframe, COL.normal1, COL.normal2
		end
		if f == E.desync then
			frameband = COL.desync
		end
		setcolor(frameband)
		love.graphics.rectangle("fill", x0, y, L.iconw + L.framew, ROWH)
		for i, c in ipairs(E.columns) do
			setcolor((i % 2 == 1) and c1 or c2)
			love.graphics.rectangle("fill", L.colx[i][1], y, L.colx[i][2], ROWH)
		end
		if f >= #E.project.frames then
			--past the end of the movie
			love.graphics.setColor(255, 255, 255, 120)
			love.graphics.rectangle("fill", x0 + L.iconw, y, L.rollend - x0 - L.iconw, ROWH)
		end
		if E.selection[f] then
			setcolor(COL.selected, 80)
			love.graphics.rectangle("fill", x0 + L.iconw, y, L.rollend - x0 - L.iconw, ROWH)
		end
		--arrows: blue for the playback cursor, green for where it's seeking to
		if isplay then
			love.graphics.setColor(40, 90, 220)
			love.graphics.polygon("fill", x0 + 4, y + 3, x0 + 14, y + ROWH/2, x0 + 4, y + ROWH - 3)
		elseif E.target and f == E.target then
			love.graphics.setColor(40, 170, 60)
			love.graphics.polygon("fill", x0 + 4, y + 3, x0 + 14, y + ROWH/2, x0 + 4, y + ROWH - 3)
		elseif E.lastposition and f == E.lastposition and not E.target then
			love.graphics.setColor(40, 170, 60, 120)
			love.graphics.polygon("line", x0 + 4, y + 3, x0 + 14, y + ROWH/2, x0 + 4, y + ROWH - 3)
		end
		love.graphics.setColor(20, 20, 20)
		love.graphics.print(tostring(f), x0 + L.iconw + 4, y + 2)
		--cells
		local input = E.project.frames[f+1]
		for i, c in ipairs(E.columns) do
			local cx, cw = L.colx[i][1], L.colx[i][2]
			if c.kind == "key" or c.kind == "button" then
				if input and cellvalue(c, f) then
					love.graphics.setColor(25, 25, 25)
					love.graphics.printf(c.kind == "key" and keylabel(c.key) or utf8cut(T(c.label), 4), cx, y + 2, cw, "center")
				end
			elseif c.kind == "mx" or c.kind == "my" then
				local v = input and (c.kind == "mx" and input.x or input.y)
				if v then
					love.graphics.setColor(25, 25, 25)
					love.graphics.printf(string.format("%g", v), cx, y + 2, cw, "center")
				end
			elseif c.kind == "wheel" then
				if input and input.w and input.w ~= 0 then
					love.graphics.setColor(25, 25, 25)
					love.graphics.printf(string.format("%+d", input.w), cx, y + 2, cw, "center")
				end
			end
		end
	end
	love.graphics.setFont(font)
	love.graphics.setScissor()
end

local function drawdialog(L)
	local d = E.dialog
	if not d then
		return
	end
	love.graphics.setColor(0, 0, 0, 160)
	love.graphics.rectangle("fill", 0, 0, L.W, L.H)
	local w, h = math.min(520, L.W - 40), 120
	if d.kind == "open" then
		h = math.min(L.H - 80, 60 + math.max(1, #d.list)*20)
	end
	local x, y = math.floor((L.W - w)/2), math.floor((L.H - h)/2)
	d.rect = {x, y, w, h}
	love.graphics.setColor(45, 45, 52)
	love.graphics.rectangle("fill", x, y, w, h, 6, 6)
	love.graphics.setColor(235, 235, 235)
	if d.kind == "open" then
		love.graphics.print(TF("open a tas project (%s)", TAS_PROJECTFOLDER), x + 12, y + 10)
		if #d.list == 0 then
			love.graphics.setColor(170, 170, 170)
			love.graphics.print(T("there aren't any projects yet"), x + 12, y + 36)
		end
		for i, name in ipairs(d.list) do
			local ry = y + 34 + (i-1)*20
			if ry + 20 > y + h - 8 then
				break
			end
			if i == d.sel then
				love.graphics.setColor(70, 110, 170)
				love.graphics.rectangle("fill", x + 8, ry, w - 16, 20, 3, 3)
			end
			love.graphics.setColor(235, 235, 235)
			love.graphics.print(name:gsub("%.tasproject$", ""), x + 14, ry + 3)
		end
	elseif d.kind == "key" then
		love.graphics.printf(T("press the key to add a column for\n(esc: cancel)"), x + 12, y + 30, w - 24, "center")
	elseif d.kind == "number" then
		love.graphics.printf(d.title, x + 12, y + 14, w - 24, "center")
		love.graphics.setColor(25, 25, 30)
		love.graphics.rectangle("fill", x + 60, y + 44, w - 120, 26, 3, 3)
		love.graphics.setColor(255, 255, 255)
		local caret = (math.floor(realtime()*2) % 2 == 0) and "|" or ""
		love.graphics.printf(d.text .. caret, x + 60, y + 49, w - 120, "center")
		love.graphics.setColor(170, 170, 170)
		love.graphics.printf(T("enter: set   empty: same as the frame before   esc: cancel"), x + 12, y + 84, w - 24, "center")
	elseif d.kind == "confirm" then
		love.graphics.printf(d.text .. "\n\n" .. T("enter: yes   esc: no"), x + 12, y + 24, w - 24, "center")
	end
end

function E.draw()
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setScissor()
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.setBlendMode("alpha")
	love.graphics.setFont(font)
	local L = layout()
	love.graphics.clear(30, 30, 35, 255)
	--toolbar
	love.graphics.setColor(38, 38, 44)
	love.graphics.rectangle("fill", 0, 0, L.W, TOOLBARH)
	local mx, my = love.mouse.getPosition()
	for _, r in ipairs(toolbarrects()) do
		local active = (r.id == "record" and E.recording) or (r.id == "play" and (E.playing or seeking()))
		local hot = mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h
		if r.id == "record" and E.recording then
			love.graphics.setColor(190, 40, 40)
			love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
			love.graphics.setColor(255, 255, 255)
			love.graphics.print(r.text, r.x + 8, r.y + math.floor((r.h - font:getHeight())/2))
		else
			drawbutton(r, active, hot)
		end
	end
	love.graphics.setColor(150, 150, 160)
	love.graphics.print(T("tas editor"), L.W - font:getWidth(T("tas editor")) - 10, 8)

	drawgameview(L)
	drawinfo(L)
	drawroll(L)
	drawdialog(L)
	love.graphics.pop()
end

------------------------------------------------------------
-- update
------------------------------------------------------------

function E.update(dt)
	if E.pendingclose then
		E.pendingclose = false
		tas_close()
		return
	end
	if E.export then
		updateexport()
		return
	end
	--the game state is out of date (input before it changed): make it again and go back to where it was
	if not E.statevalid then
		local back = E.lastposition or C.frame
		E.lastposition = nil
		jump(back, E.playing)
	end
	if seeking() then
		updateseek()
		if E.followcursor then
			followcursor()
		end
	elseif E.playing then
		C.setmuted(false)
		E.accum = math.min((E.accum or 0) + dt, C.DT*4)
		while E.accum >= C.DT do
			E.accum = E.accum - C.DT
			if not stepframe(E.recording) then
				break
			end
		end
		followcursor()
	end
	if E.nextclean and realtime() > E.nextclean then
		cleangreenzone()
	end
	for _, m in ipairs(C.messages) do
		status(TF("%s (frame %d)", T(m), C.frame), true)
	end
	C.messages = {}
	if E.held then
		--holding \ or backspace keeps stepping after a moment, like FCEUX's frame advance
		local h = E.held
		if realtime() - h.start > 0.25 and not seeking() then
			h.acc = (h.acc or 0) + dt
			while h.acc > 1/30 do
				h.acc = h.acc - 1/30
				if h.key == "\\" then
					if E.recording then
						stepframe(true)
					else
						jump(C.frame + 1)
					end
				else
					jump(C.frame - 1)
				end
			end
		end
	end
	if E.dragplayback then
		local row = rowat(love.mouse.getY())
		if row and row ~= C.frame and not seeking() then
			jump(math.max(0, row))
		end
	end
end

------------------------------------------------------------
-- input
------------------------------------------------------------

local function ctrldown()
	local isdown = C.orig["keyboard.isDown"] or love.keyboard.isDown
	return isdown("lctrl") or isdown("rctrl") or isdown("lgui") or isdown("rgui")
end
local function shiftdown()
	local isdown = C.orig["keyboard.isDown"] or love.keyboard.isDown
	return isdown("lshift") or isdown("rshift")
end

local function togglepause()
	if seeking() then
		E.target = nil
		E.playing = false
		C.setmuted(false)
	else
		E.playing = not E.playing
		E.accum = 0
		if E.playing and E.recording then
			E.recordsession = {}
		end
	end
end

local function setrecording(on)
	E.recording = on
	E.recordsession = {}
	status(T(on and "recording: the keyboard and the mouse over the game go into the frames" or "stopped recording"))
end

local function confirmdirty(text, fn)
	if E.dirty then
		E.dialog = {kind = "confirm", text = text, fn = fn}
	else
		fn()
	end
end

local function toolbarclick(id)
	if id == "new" then
		confirmdirty(T("start a new project? the changes to this one that aren't saved are lost"), function()
			startproject(newproject(), nil)
			status(T("new project"))
		end)
	elseif id == "open" then
		confirmdirty(T("open another project? the changes to this one that aren't saved are lost"), function()
			E.dialog = {kind = "open", list = listprojects(), sel = 1}
		end)
	elseif id == "save" then
		saveproject()
	elseif id == "export" then
		startexport()
	elseif id == "scale" then
		E.project.exportscale = ((E.project.exportscale or 2) % 4) + 1
		E.dirty = true
		local e = E.project.exportscale
		status(TF("the mp4 will be %dx%d", width*16*e, height*16*e))
	elseif id == "start" then
		jump(0)
	elseif id == "back" then
		jump(C.frame - 1)
	elseif id == "play" then
		togglepause()
	elseif id == "forward" then
		jump(C.frame + 1)
	elseif id == "end" then
		jump(math.max(0, #E.project.frames))
	elseif id == "record" then
		setrecording(not E.recording)
	elseif id == "close" then
		confirmdirty(T("close the tas editor? the changes that aren't saved are lost"), function()
			E.pendingclose = true
		end)
	end
end

local function opennumber(col, list)
	local first = inputat(list[1])
	local v = col.kind == "mx" and first.x or col.kind == "my" and first.y or first.w
	E.dialog = {kind = "number", col = col, list = list, text = v and tostring(v) or "",
		title = TF("%s for frames: %d", T(col.kind == "wheel" and "mouse wheel" or ("mouse " .. col.label)), #list)}
end

local function dialogkey(key)
	local d = E.dialog
	if d.kind == "open" then
		if key == "escape" then
			E.dialog = nil
		elseif key == "up" then
			d.sel = math.max(1, d.sel - 1)
		elseif key == "down" then
			d.sel = math.min(#d.list, d.sel + 1)
		elseif key == "return" and d.list[d.sel] then
			E.dialog = nil
			openproject(TAS_PROJECTFOLDER .. "/" .. d.list[d.sel])
		end
	elseif d.kind == "key" then
		E.dialog = nil
		if key ~= "escape" then
			key = C.normalkey(key)
			for _, c in ipairs(E.project.columns) do
				if c.key == key then
					status(TF("there's already a column for %s", key))
					return
				end
			end
			E.project.columns[#E.project.columns+1] = {kind = "key", key = key, label = ""}
			E.dirty = true
			rebuildcolumns()
			status(TF("added a column for %s", key))
		end
	elseif d.kind == "number" then
		if key == "escape" then
			E.dialog = nil
		elseif key == "backspace" then
			d.text = d.text:sub(1, -2)
		elseif key == "return" or key == "kpenter" then
			E.dialog = nil
			local v = tonumber(d.text)
			if d.text ~= "" and not v then
				status(T("that isn't a number"), true)
				return
			end
			local col = d.col
			if col.kind == "mx" then
				v = v and math.max(0, math.min(width*16 - 1, v))
			elseif col.kind == "my" then
				v = v and math.max(0, math.min(height*16 - 1, v))
			elseif v then
				v = math.floor(v)
			end
			editframes("set mouse", d.list, function(input)
				if col.kind == "mx" then
					input.x = v
				elseif col.kind == "my" then
					input.y = v
				else
					input.w = (v and v ~= 0) and v or nil
				end
			end)
		end
	elseif d.kind == "confirm" then
		if key == "return" or key == "y" then
			E.dialog = nil
			d.fn()
		elseif key == "escape" or key == "n" then
			E.dialog = nil
		end
	end
end

local RECORDIGNORE = {["\\"] = true, backspace = true, pause = true}

function E.keypressed(key, scancode, isrepeat)
	if E.dialog then
		dialogkey(key)
		return
	end
	if E.export then
		if key == "escape" then
			endexport(true)
		end
		return
	end
	local ctrl, shift = ctrldown(), shiftdown()
	--what's held down for real (for recording)
	if not ctrl and not RECORDIGNORE[key] and not isrepeat then
		E.realheld[C.normalkey(key)] = true
	end
	if key == "\\" then
		if not isrepeat then
			E.held = {key = key, start = realtime()}
			E.playing = false
			if E.recording then
				if seeking() then
					return
				end
				E.recordsession = E.recordsession or {}
				stepframe(true)
				followcursor()
			else
				jump(C.frame + 1)
			end
		end
		return
	elseif key == "backspace" then
		if not isrepeat then
			E.held = {key = key, start = realtime()}
			E.playing = false
			jump(C.frame - 1)
		end
		return
	elseif key == "pause" then
		togglepause()
		return
	end
	if ctrl then
		if key == "z" then undo()
		elseif key == "y" then redo()
		elseif key == "c" then copyselected()
		elseif key == "x" then
			if copyselected() then clearselected() end
		elseif key == "v" then paste(shift)
		elseif key == "a" then
			E.selection = {}
			for f = 0, math.max(0, #E.project.frames - 1) do
				E.selection[f] = true
			end
			E.anchor = 0
		elseif key == "s" then saveproject()
		elseif key == "o" then toolbarclick("open")
		elseif key == "n" then toolbarclick("new")
		elseif key == "e" then startexport()
		elseif key == "r" then setrecording(not E.recording)
		elseif key == "insert" then cloneselected()
		elseif key == "delete" then deleteselected()
		elseif key == "home" then jump(0)
		elseif key == "end" then jump(#E.project.frames)
		end
		return
	end
	if E.recording and E.playing then
		return --the keys are going into the frames
	end
	local L = E.L or layout()
	local list = selectedlist()
	local cur = E.anchor or list[1] or C.frame
	if key == "space" then
		togglepause()
	elseif key == "return" or key == "kpenter" then
		if list[1] then
			jump(E.anchor or list[1])
		end
	elseif key == "escape" then
		E.selection, E.anchor = {}, nil
	elseif key == "insert" then
		insertblank()
	elseif key == "delete" then
		clearselected()
	elseif key == "up" or key == "down" or key == "pageup" or key == "pagedown" or key == "home" or key == "end" then
		local step = (key == "up" and -1) or (key == "down" and 1) or (key == "pageup" and -L.rows) or (key == "pagedown" and L.rows) or 0
		local target = cur + step
		if key == "home" then target = 0 end
		if key == "end" then target = math.max(0, #E.project.frames - 1) end
		target = math.max(0, math.min(rowcount() - 1, target))
		if shift then
			E.selanchor = E.selanchor or cur
			selectrange(E.selanchor, target)
			E.anchor = target
		else
			E.selanchor = nil
			selectonly(target)
		end
		if target < E.scroll then
			E.scroll = target
		elseif target >= E.scroll + L.rows then
			E.scroll = target - L.rows + 1
		end
	end
end

function E.keyreleased(key)
	E.realheld[C.normalkey(key)] = nil
	if E.held and E.held.key == key then
		E.held = nil
	end
end

local function ingame(x, y)
	local L = E.L
	if not L then
		return nil
	end
	if x >= L.gx and x < L.gx + L.gw and y >= L.gy and y < L.gy + L.gh then
		return math.floor((x - L.gx)/L.gs), math.floor((y - L.gy)/L.gs)
	end
	return nil
end

function E.mousepressed(x, y, button)
	local L = E.L or layout()
	E.lastclick = E.lastclick or {t = 0}
	--a double click: the same place on the same rows (the piano roll didn't scroll in between) within 0.35 seconds
	local double = (realtime() - E.lastclick.t < 0.35) and math.abs(E.lastclick.x - x) < 4 and math.abs(E.lastclick.y - y) < 4
		and E.lastclick.scroll == E.scroll
	E.lastclick = {t = realtime(), x = x, y = y, scroll = E.scroll}
	if E.dialog then
		local d = E.dialog
		if d.kind == "open" and d.rect and button == 1 then
			local rx, ry, rw = d.rect[1], d.rect[2], d.rect[3]
			local i = math.floor((y - ry - 34)/20) + 1
			if x >= rx and x < rx + rw and d.list[i] and y >= ry + 34 then
				if d.sel == i and double then
					E.dialog = nil
					openproject(TAS_PROJECTFOLDER .. "/" .. d.list[i])
				else
					d.sel = i
				end
			elseif not (x >= rx and x < rx + rw and y >= ry and y < ry + d.rect[4]) then
				E.dialog = nil
			end
		end
		return
	end
	if E.export then
		return
	end
	--toolbar
	if y < TOOLBARH then
		for _, r in ipairs(toolbarrects()) do
			if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then
				toolbarclick(r.id)
				return
			end
		end
		return
	end
	--the game: recording takes the mouse from here, otherwise a click puts the mouse of the selected frames there
	local gx, gy = ingame(x, y)
	if gx then
		if E.recording then
			E.realbuttons[button] = true
			return
		end
		if button == 1 then
			editframes("set mouse", targetframes(), function(input)
				input.x, input.y = gx, gy
			end)
			status(TF("the mouse is at %d, %d on frames: %d", gx, gy, #targetframes()))
		end
		return
	end
	if button == 3 then
		togglepause() --middle click, like FCEUX
		return
	end
	--piano roll
	if x < L.rollx then
		return
	end
	local row = rowat(y)
	local colid = columnat(x)
	if not row then
		--header: column set (like FCEUX: every selected frame gets it, or loses it if they all have it)
		if type(colid) == "number" then
			local col = E.columns[colid]
			if col.kind == "add" then
				E.dialog = {kind = "key"}
			elseif button == 2 and col.kind == "key" then
				local used = false
				for _, f in ipairs(E.project.frames) do
					if f.k and f.k[col.key] then
						used = true
						break
					end
				end
				if used then
					status(TF("frames still use %s: clear that column first (select all, then click its name)", col.key), true)
				else
					for i, c in ipairs(E.project.columns) do
						if c.key == col.key then
							table.remove(E.project.columns, i)
							break
						end
					end
					E.dirty = true
					rebuildcolumns()
					status(TF("removed the column for %s", col.key))
				end
			elseif col.kind == "key" or col.kind == "button" then
				local list = selectedlist()
				if #list > 0 then
					local all = true
					for _, f in ipairs(list) do
						if not cellvalue(col, f) then
							all = false
							break
						end
					end
					editframes(all and "column clear" or "column set", list, function(input)
						setcell(input, col, not all)
					end)
					E.headerflash = {col = colid, until_ = realtime() + 0.3}
				end
			elseif col.kind == "mx" or col.kind == "my" or col.kind == "wheel" then
				local list = selectedlist()
				if #list > 0 then
					opennumber(col, list)
				end
			end
		end
		return
	end
	if button ~= 1 and button ~= 2 then
		return
	end
	local ctrl, shift = ctrldown(), shiftdown()
	if colid == "icons" then
		jump(row)
		E.dragplayback = true
	elseif colid == "frame" then
		if double and not shift and not ctrl then
			jump(row)
		elseif shift and E.anchor then
			selectrange(E.anchor, row)
			E.dragselect = {from = E.anchor}
		elseif ctrl then
			if E.selection[row] then
				E.selection[row] = nil
				E.dragselect = {unset = true}
			else
				E.selection[row] = true
				E.dragselect = {set = true}
			end
			E.anchor = row
		else
			selectonly(row)
			E.dragselect = {from = row}
		end
	elseif type(colid) == "number" then
		local col = E.columns[colid]
		if col.kind == "key" or col.kind == "button" then
			local value = not cellvalue(col, row)
			local list
			if shift and E.anchor then
				list = {}
				for f = math.min(E.anchor, row), math.max(E.anchor, row) do
					list[#list+1] = f
				end
				selectrange(E.anchor, row)
			elseif ctrl then
				E.selection[row] = true
				list = {row}
			else
				selectonly(row)
				list = {row}
			end
			E.paint = {col = col, value = value, done = {}, merge = {}}
			for _, f in ipairs(list) do
				E.paint.done[f] = true
			end
			editframes(value and "set input" or "clear input", list, function(input)
				setcell(input, col, value)
			end, E.paint.merge)
		elseif col.kind == "mx" or col.kind == "my" or col.kind == "wheel" then
			if not E.selection[row] then
				selectonly(row)
			end
			opennumber(col, selectedlist())
		elseif col.kind == "add" then
			E.dialog = {kind = "key"}
		end
	end
end

function E.mousereleased(x, y, button)
	E.realbuttons[button] = nil
	E.paint = nil
	E.dragselect = nil
	E.dragplayback = nil
end

function E.mousemoved(x, y)
	local gx, gy = ingame(x, y)
	E.mouseingame = gx and {gx, gy} or E.mouseingame
	if not E.L then
		return
	end
	local row = rowat(y)
	if row and E.paint then
		--painting down (or up) a column
		local p = E.paint
		if not p.done[row] then
			p.done[row] = true
			editframes("paint input", {row}, function(input)
				setcell(input, p.col, p.value)
			end, p.merge)
		end
	elseif row and E.dragselect then
		local d = E.dragselect
		if d.from then
			selectrange(d.from, row)
			E.anchor = d.from
		elseif d.set then
			E.selection[row] = true
		elseif d.unset then
			E.selection[row] = nil
		end
	end
end

function E.wheelmoved(x, y)
	if E.dialog or E.export then
		return
	end
	local mx, my = love.mouse.getPosition()
	if E.recording and ingame(mx, my) then
		E.realwheel = (E.realwheel or 0) + y
		return
	end
	if shiftdown() then
		jump(C.frame - y)
	else
		E.scroll = E.scroll - y*3
		clampscroll()
	end
end

function E.textinput(t)
	local d = E.dialog
	if d and d.kind == "number" and t:match("^[%d%.%-]$") and #d.text < 8 then
		d.text = d.text .. t
	end
end

function E.filedropped(file)
	local name = file:getFilename()
	if name:match("%.tasproject$") then
		local ok = file:open("r")
		local data = ok and file:read()
		file:close()
		if data then
			love.filesystem.createDirectory(TAS_PROJECTFOLDER)
			local path = TAS_PROJECTFOLDER .. "/" .. name:match("([^/\\]+)$")
			love.filesystem.write(path, data)
			confirmdirty(TF("open %s? the changes to this one that aren't saved are lost", name:match("([^/\\]+)$")), function()
				openproject(path)
			end)
		end
	end
end

------------------------------------------------------------
-- opening and closing the editor
------------------------------------------------------------

--opens the editor (from the utils menu). It starts on the next frame, outside of any callback
function tas_open()
	if tasactive or tasstepping then
		if notice then
			notice.new(T("the tas editor can't be opened inside a tas project!"), notice.red, 3)
		end
		return false
	end
	E.pendingopen = true
	return true
end

local function reallyopen()
	E.pendingopen = false
	if not font then
		if love.filesystem.getInfo(TAS_FONT) then
			font = love.graphics.newFont(TAS_FONT, 12)
			smallfont = love.graphics.newFont(TAS_FONT, 11)
		else
			font = love.graphics.newFont(12)
			smallfont = love.graphics.newFont(11)
		end
	end
	--everything as it is now, put back when the editor closes
	E.home = C.save()
	E.pausedsources = love.audio.pause()
	E.realheld, E.realbuttons, E.realwheel = {}, {}, 0
	local W, H = love.graphics.getDimensions()
	if (W < 1100 or H < 620) and love.window.updateMode then
		E.oldsize = {W, H}
		local dw, dh = love.window.getDesktopDimensions()
		love.window.updateMode(math.min(1280, dw or 1280), math.min(720, (dh or 760) - 40))
	end
	tasactive = true
	--this mappack's project, or a new one
	local path = projectpath(mappackdisplayname())
	if love.filesystem.getInfo(path) then
		openproject(path)
	else
		startproject(newproject(), nil)
		status(TF("new project for %s (ctrl+s saves it as %s)", E.project.name, path))
	end
end

function tas_close()
	if E.export then
		endexport(true)
	end
	C.setmuted(false)
	C.load(E.home)
	if E.pausedsources then
		love.audio.play(E.pausedsources)
	end
	if E.oldsize and love.window.updateMode then
		love.window.updateMode(E.oldsize[1], E.oldsize[2])
	end
	E.oldsize = nil
	E.home, E.greenzone, E.summaries, E.rngouts, E.project, E.history = nil, nil, nil, nil, nil, nil
	E.gamecanvas = nil
	tasactive = false
	collectgarbage()
end

------------------------------------------------------------
-- hooks: while the editor is open, it gets every callback
------------------------------------------------------------

function tas_install()
	if tasinstalled then
		return
	end
	tasinstalled = true
	C.install()
	C.captureinner()
	local handlers = {
		update = function(dt)
			if E.pendingopen then
				reallyopen()
				return
			end
			E.update(dt)
		end,
		draw = function() E.draw() end,
		keypressed = function(...) E.keypressed(...) end,
		keyreleased = function(...) E.keyreleased(...) end,
		mousepressed = function(...) E.mousepressed(...) end,
		mousereleased = function(...) E.mousereleased(...) end,
		mousemoved = function(...) E.mousemoved(...) end,
		wheelmoved = function(...) E.wheelmoved(...) end,
		textinput = function(...) E.textinput(...) end,
		filedropped = function(...) E.filedropped(...) end,
	}
	local names = {"update", "draw", "keypressed", "keyreleased", "textinput", "mousepressed", "mousereleased",
		"mousemoved", "wheelmoved", "focus", "joystickpressed", "joystickreleased", "joystickaxis", "joystickhat",
		"gamepadpressed", "gamepadreleased", "gamepadaxis", "filedropped", "directorydropped", "resize", "visible",
		"touchpressed", "touchreleased", "touchmoved"}
	--closing the window with changes that aren't saved: they go into "<name> (autosave).tasproject"
	local quit = love.quit
	love.quit = function(...)
		if tasactive and E.project and E.dirty then
			pcall(function()
				local name = E.project.name
				E.project.name = name .. " (autosave)"
				saveproject()
				E.project.name = name
			end)
		end
		if quit then
			return quit(...)
		end
	end
	for _, name in ipairs(names) do
		local f = love[name]
		local h = handlers[name]
		love[name] = function(...)
			if tasactive or (name == "update" and E.pendingopen) then
				if h then
					local ok, err = xpcall(h, debug.traceback, ...)
					if not ok then
						print(err)
						status(TF("tas editor error: %s", tostring(err):match("[^\n]*")), true)
					end
				end
				return
			end
			if f then
				return f(...)
			end
		end
	end
end