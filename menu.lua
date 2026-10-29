local languagemenuopen = false
local menu_updatemouseselection

local previousmappackfolder
local controlsbuttonpadding = 4
local keybindpage = 1
local keybindpageanimation
local keybindpageduration = 0.25
local keypromptpage = 1
local menupopupduration = 0.25
local menupopupanimations = {
	newgamewarning = {from = 0, to = 0},
	selectworld = {from = 0, to = 0}
}

local function menupopupscale(name, now)
	local anim = menupopupanimations[name]
	if not anim.start then
		return anim.to
	end

	local progress = (now - anim.start) / menupopupduration
	if progress >= 1 then
		anim.from = anim.to
		anim.start = nil
		return anim.to
	end

	progress = motion_curve(progress, anim.curve, anim.opening, not anim.opening, true, true)
	return lerp(anim.from, anim.to, progress)
end

local function setmenupopupvisible(name, visible)
	local currentlyvisible
	if name == "newgamewarning" then
		currentlyvisible = newgamewarning
	else
		currentlyvisible = selectworldopen
	end

	if currentlyvisible == visible then
		return
	end

	local now = love.timer.getTime()
	local anim = menupopupanimations[name]
	anim.from = menupopupscale(name, now)
	anim.to = bool2int(visible)
	anim.start = now
	anim.curve = random_motion_curve()
	anim.opening = visible

	if name == "newgamewarning" then
		newgamewarning = visible
	else
		selectworldopen = visible
	end
end

--Misc. options tab (optionstab == 3) widgets
local optionsmiscgui = {"opt_scale", "opt_letterbox", "opt_shader1", "opt_shader2", "opt_volume", "opt_language", "opt_nitpicks", "opt_resetmaps", "opt_resetall", "opt_vsync", "opt_mappackfolder"}
local optionsmiscselection = {}

for i, option in ipairs(optionsmiscgui) do
    optionsmiscselection[i + 1] = option
end

local optionscheatsgui = {
    "cheat_mode",
    "cheat_knockback",
    "cheat_bullettime",
    "cheat_bigmario",
    "cheat_goombaattack",
    "cheat_sonicrainboom",
    "cheat_playercollisions",
    "cheat_infinitetime",
    "cheat_infinitelives",
    "cheat_darkmode"
}
local optionscheatsselection = {}

for i, option in ipairs(optionscheatsgui) do
    optionscheatsselection[i + 1] = option
end

local function optionscheats_create()
    local right = 235
    local enabled = gamefinished

    guielements["cheat_mode"] = guielement:new("dropdown", right - 13 - 10 * 8, 59, 10, function(i)
        local widget = guielements["cheat_mode"]
        playertypei = i
        playertype = widget.entries[i]

        if playertype == "minecraft" then
            portalknockback = false
            bullettime = false
            bigmario = false
            sonicrainboom = false
        elseif playertype == "gelcannon" then
            sonicrainboom = false
        elseif playertype == "classic" then
            portalknockback = false
            sonicrainboom = false
        end

        widget.var = i
    end, playertypei, "portal", "minecraft", "gelcannon", "cappy", "classic")

    guielements["cheat_mode"].active = enabled

    local function make_checkbox(name, y, getter, setter)
        guielements[name] = guielement:new("checkbox", right - 9, y, function(v)
            setter(v)
            guielements[name].var = v
        end, getter())

        guielements[name].active = enabled
    end

    make_checkbox("cheat_knockback", 74, function()
        return portalknockback
    end, function(v)
        portalknockback = v
        if v and playertype == "minecraft" then
            playertypei = 1
            playertype = "portal"
            guielements["cheat_mode"].var = playertypei
        end
    end)

    make_checkbox("cheat_bullettime", 88, function()
        return bullettime
    end, function(v)
        bullettime = v
        if v and playertype == "minecraft" then
            playertypei = 1
            playertype = "portal"
            guielements["cheat_mode"].var = playertypei
        end
    end)

    make_checkbox("cheat_bigmario", 102, function()
        return bigmario
    end, function(v)
        bigmario = v
        if v and playertype == "minecraft" then
            playertypei = 1
            playertype = "portal"
            guielements["cheat_mode"].var = playertypei
        end
    end)

    make_checkbox("cheat_goombaattack", 116, function()
        return goombaattack
    end, function(v)
        goombaattack = v
    end)

    make_checkbox("cheat_sonicrainboom", 130, function()
        return sonicrainboom
    end, function(v)
        sonicrainboom = v
        if v then
            playertypei = 1
            playertype = "portal"
            guielements["cheat_mode"].var = playertypei
        end
    end)

    make_checkbox("cheat_playercollisions", 144, function()
        return playercollisions
    end, function(v)
        playercollisions = v
    end)

    make_checkbox("cheat_infinitetime", 158, function()
        return infinitetime
    end, function(v)
        infinitetime = v
    end)

    make_checkbox("cheat_infinitelives", 172, function()
        return infinitelives
    end, function(v)
        infinitelives = v
    end)

    make_checkbox("cheat_darkmode", 186, function()
        return darkmode
    end, function(v)
        darkmode = v
    end)
end

local function optionscheats_remove()
    for i = 1, #optionscheatsgui do
        guielements[optionscheatsgui[i]] = nil
    end
end

local function optionscheats_sync()
    if not guielements["cheat_mode"] then
        return
    end

    guielements["cheat_mode"].var = playertypei
    guielements["cheat_knockback"].var = portalknockback
    guielements["cheat_bullettime"].var = bullettime
    guielements["cheat_bigmario"].var = bigmario
    guielements["cheat_goombaattack"].var = goombaattack
    guielements["cheat_sonicrainboom"].var = sonicrainboom
    guielements["cheat_playercollisions"].var = playercollisions
    guielements["cheat_infinitetime"].var = infinitetime
    guielements["cheat_infinitelives"].var = infinitelives
    guielements["cheat_darkmode"].var = darkmode

    for selection, name in pairs(optionscheatsselection) do
        if guielements[name] then
            guielements[name].forcehover = (optionsselection == selection)
        end
    end
end

local function optionscheats_activate(selection)
    local v = guielements[optionscheatsselection[selection]]
    if not v or not v.active then
        return
    end

    if v.type == "checkbox" then
        v.func(not v.var)
    elseif v.type == "dropdown" and not v.extended then
        v:open(true)
    end
end

local function optionscheats_draw()
    local ontop = {}

    for i = 1, #optionscheatsgui do
        local v = guielements[optionscheatsgui[i]]
        if v then
            if v.extended or (v.listvalue and v.listvalue > 0) then
                table.insert(ontop, v)
            else
                v:draw()
            end
        end
    end

    for i = 1, #ontop do
        ontop[i]:draw()
    end
end

local function optionscheats_update()
    if gamestate == "options" and optionstab == 4 and gamefinished then
        if not guielements["cheat_mode"] then
            optionscheats_create()
        end
        optionscheats_sync()
    else
        optionscheats_remove()
    end
end

--Controls options tab (optionstab == 1) widgets
local optionscontrolsgui = {
	"ctrl_player", "ctrl_mouse", "ctrl_bindpage",
	"ctrl_left", "ctrl_right", "ctrl_up", "ctrl_down",
	"ctrl_run", "ctrl_jump", "ctrl_reload", "ctrl_use",
	"ctrl_pause", "ctrl_aimx", "ctrl_aimy", "ctrl_portal1", "ctrl_portal2"
}
local optionscontrolsselection = {}

for i, option in ipairs(optionscontrolsgui) do
	optionscontrolsselection[i + 1] = option
end

local optionscontrols_controlnames = {
	"left", "right", "up", "down",
	"run", "jump", "reload", "use",
	"pause", "aimx", "aimy", "portal1", "portal2"
}

local function optionscontrols_lastselection()
	local visiblecontrols = mouseowner == skinningplayer and 9 or #optionscontrols_controlnames
	return 4 + visiblecontrols
end

local optionscontrols_change_page

local function optionscontrols_getkeystring(player, name, page)
	local controlset = getcontrolset(page or keybindpage)
	local binding = controlset and controlset[player] and controlset[player][name]
	local s = ""
	if binding and binding[1] and binding[1] ~= "" then
		for j = 1, #binding do
			s = s .. tostring(binding[j])
		end
	else
		return "unbound"
	end
	if s == " " then
		s = "space"
	end
	return s
end

local function optionscontrols_create()
	local right = 235

	--Edit Player dropdown
	guielements["ctrl_player"] = guielement:new("dropdown", right - (13 + 1 * 8), 40, 1, function(i)
		skinningplayer = i
		if characters.data[mariocharacter[skinningplayer]] then
			characteri = characters.data[mariocharacter[skinningplayer]].i
		end
		if players > #controls then
			loadconfig()
		end
		guielements["ctrl_player"].var = i
		saveconfig()
	end, skinningplayer, "1", "2", "3", "4")

	local currentbindlabel = TEXT["current bind:"] or "current bind:"
	local bindlabelwidth = utf8.len(currentbindlabel) * 8
	local binddropdownwidth = 13 + 8
	local bindgroupx = 130 - (bindlabelwidth + 4 + binddropdownwidth) / 2
	guielements["ctrl_bindpage"] = guielement:new("dropdown", bindgroupx + bindlabelwidth + 4, 64, 1, function(i)
		optionscontrols_change_page(i - keybindpage)
		guielements["ctrl_bindpage"].var = i
	end, keybindpage, "1", "2", "3", "4")

	--Uses The Mouse checkbox
	guielements["ctrl_mouse"] = guielement:new("checkbox", right - 9, 52, function(v)
		if v then
			mouseowner = skinningplayer
		else
			mouseowner = 0
		end
		guielements["ctrl_mouse"].var = v
		saveconfig()
	end, mouseowner == skinningplayer)

	--Control scheme buttons (all 13, visibility handled in sync)
	for i, name in ipairs(optionscontrols_controlnames) do
		local y = 80 + (i - 1) * 10
		local controlselection = i + 4
		local s = optionscontrols_getkeystring(skinningplayer, name, keybindpage)
		local w = math.min((utf8.len(s) + 1) * (controlsbuttonpadding * 2), 112)
		local x = right - (3 + w)   -- right-aligned (space defaults to 0)
		local controlsbutton = guielement:new("button", x, y, s, function()
			optionsselection = controlselection
			keypromptstart()
		end, nil, nil, 1, w)
		controlsbutton.xpadding = controlsbuttonpadding
		controlsbutton.controlbindpage = true
		guielements["ctrl_" .. name] = controlsbutton
	end
end

local function optionscontrols_remove()
	for i = 1, #optionscontrolsgui do
		guielements[optionscontrolsgui[i]] = nil
	end
end

local function optionscontrols_sync()
	if not guielements["ctrl_player"] then
		return
	end

	guielements["ctrl_player"].var = skinningplayer
	guielements["ctrl_bindpage"].var = keybindpage
	guielements["ctrl_mouse"].var = (mouseowner == skinningplayer)

	local showextra = (mouseowner ~= skinningplayer)

	for i, name in ipairs(optionscontrols_controlnames) do
		local el = guielements["ctrl_" .. name]
		if el then
			local s = optionscontrols_getkeystring(skinningplayer, name)
			el.text = s
			el.width = math.min((utf8.len(s) + 1) * (controlsbuttonpadding * 2), 112)
			el.x = 235 - (3 + el.width)   -- keep right edge fixed when text length changes

			-- The first 9 controls stay visible; aim and portal controls require non-mouse ownership.
			local pageanimating = keybindpageanimation ~= nil
			if i <= 9 then
				el.active = not keyprompt and not pageanimating
				el.nohover = keyprompt or pageanimating
			else
				el.active = showextra and not keyprompt and not pageanimating
				el.nohover = keyprompt or pageanimating or not showextra
			end
		end
	end

	for selection, name in pairs(optionscontrolsselection) do
		if guielements[name] then
			guielements[name].forcehover = (optionsselection == selection)
		end
	end
end

function optionscontrols_activate(selection)
	local v = guielements[optionscontrolsselection[selection]]
	if not v or not v.active then
		return
	end

	if v.type == "button" then
		v.func(unpack(v.arguments or {}))
	elseif v.type == "checkbox" then
		v.func(not v.var)
	elseif v.type == "dropdown" then
		if not v.extended then
			v:open(true)
		end
	end
end

local function optionscontrols_draw(page, bindingsonly, staticonly)
	local ontop = {}
	local showextra = (mouseowner ~= skinningplayer)

	for i = 1, #optionscontrolsgui do
		local v = guielements[optionscontrolsgui[i]]
		if v and (not bindingsonly or i > 3) and (not staticonly or i <= 3) then
			local originaltext, originalwidth, originalx
			if i > 3 then
				originaltext, originalwidth, originalx = v.text, v.width, v.x
				v.text = optionscontrols_getkeystring(skinningplayer, optionscontrols_controlnames[i - 3], page)
				v.width = math.min((utf8.len(v.text) + 1) * (controlsbuttonpadding * 2), 112)
				v.x = 235 - (3 + v.width)
			end
			-- skip the extra control buttons when they should be hidden
			local isextra = (i >= 13) -- aimx onwards
			if isextra and not showextra then
				-- do not draw
			elseif v.extended or (v.listvalue and v.listvalue > 0) then
				table.insert(ontop, v)
			else
				v:draw()
			end
			if originaltext then
				v.text, v.width, v.x = originaltext, originalwidth, originalx
			end
		end
	end
	for i = 1, #ontop do
		ontop[i]:draw()
	end
end

optionscontrols_change_page = function(delta)
	local page = math.max(1, math.min(4, keybindpage + delta))
	if page == keybindpage then
		return false
	end

	keybindpageanimation = {
		from = keybindpage,
		to = page,
		direction = delta,
		start = love.timer.getTime(),
		curve = random_motion_curve()
	}
	keybindpage = page
	for _, name in ipairs(optionscontrols_controlnames) do
		local el = guielements["ctrl_" .. name]
		if el then
			el.active = false
			el.nohover = true
		end
	end
	return true
end

local function optionscontrols_pageviews()
	if not keybindpageanimation then
		return {{page = keybindpage, offset = 0}}
	end

	local animation = keybindpageanimation
	local progress = (love.timer.getTime() - animation.start) / keybindpageduration
	if progress >= 1 then
		keybindpageanimation = nil
		return {{page = keybindpage, offset = 0}}
	end

	progress = motion_curve(progress, animation.curve, true, false, true, true)
	local distance = 240 * math.abs(animation.to - animation.from)
	local direction = animation.to > animation.from and 1 or -1
	return {
		{page = animation.from, offset = -direction * progress * distance},
		{page = animation.to, offset = direction * (1 - progress) * distance}
	}
end

local function optionscontrols_draw_page(page, offset)
	love.graphics.push()
	love.graphics.translate(offset*scale, 0)

	local showextra = (mouseowner ~= skinningplayer)
	for i, name in ipairs(optionscontrols_controlnames) do
		if i <= 9 or showextra then
			if optionsselection == 4+i then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			properprintF(TEXT[name] or name, 30*scale, (80+(i-1)*10)*scale)
		end
	end
	optionscontrols_draw(page, true)
	love.graphics.pop()
end

function optionscontrols_transformmouse(x, y)
	if gamestate ~= "options" or optionstab ~= 1 then
		return x, y
	end
	if keybindpageanimation then
		return -math.huge, -math.huge
	end

	return x, y
end

function optionscontrols_update()
	if gamestate == "options" and optionstab == 1 then
		if not guielements["ctrl_player"] then
			optionscontrols_create()
		end
		optionscontrols_sync()
	elseif guielements["ctrl_player"] then
		optionscontrols_remove()
	end
end

--volume slider, shared by the options menu (here) and the pause menu (game.lua)
--called when the slider is released or a left/right key changed it
function volumeslider_commit(slider)
	slider.value = math.min(math.max(slider.value, 0), 1) --clamp
	volume = slider.value
	love.audio.setVolume(volume)

	local changed = (volume ~= slider.savedvalue)

	soundenabled = volume > 0

	if changed then
		slider.savedvalue = volume
		if soundenabled then
			playsound(beepsound)
		end
		saveconfig()
	end
end

--left/right key: change the volume by delta (0.1 or -0.1) and animate the handle
--right/d (positive delta) uses easeout, left/a (negative delta) uses easein, with a random curve each press
function volumeslider_step(slider, delta)
	if not slider then
		return
	end

	local from = slider.value --where the handle is right now
	local base = from
	if slider.valueanim then
		base = slider.valueanim.to --keep stepping from the target when keys are pressed quickly
	end
	local target = math.min(math.max(round(base + delta, 3), 0), 1)

	slider.valueanim = nil
	slider.value = target
	volumeslider_commit(slider)

	if from ~= target then
		slider.value = from --show the handle where it was, then slide it
		slider.valueanim = {from = from, to = target, start = love.timer.getTime(), curve = random_motion_curve()}
	end
end

--moves the handle along the key animation, call every frame with slider.back
--back: true if the last key moved the value back (left/a), anything else counts as forward (right/d)
function volumeslider_animate(slider)
	local anim = slider.valueanim
	if not anim then
		return
	end

	if slider.dragging then
		slider.valueanim = nil --grabbing the handle cancels the animation
		return
	end

	local t = (love.timer.getTime() - anim.start) / 0.25
	slider.value = lerp(anim.from, anim.to, motion_curve(t, anim.curve, true, true, true, true))
	if t >= 1 then
		slider.value = anim.to
		slider.valueanim = nil
	end
end

function volumeslider_new(x, y, range)
	local slider = guielement:new("scrollbar", x, y, range, 33, 9, volume, "hor")
	slider.backgroundcolor = {0, 0, 0}
	slider.buttonround = true
	slider.scrollstepdisabled = true --the mouse wheel would change the value without a release
	slider.savedvalue = volume

	--text on the handle (scales with the window like the editor's sliders)
	slider.displayfunction = function(self, v)
		if self.valueanim then
			v = self.valueanim.to --show the target volume while the handle slides
		end
		return round(v*100) .. "%"
	end

	--live volume while dragging
	slider.updatefunc = function(self, v)
		volume = v
		love.audio.setVolume(volume)
	end

	slider.releasefunc = function(self, v)
		volumeslider_commit(self)
	end

	return slider
end

local function optionsmisc_create()
	local right = 235 --right edge of the dropdowns and checkboxes

	--Scale
	guielements["opt_scale"] = guielement:new("dropdown", right-(13+9*8), 38, 9, function(i)
		changescale(i)
		guielements["opt_scale"].var = i
		saveconfig()
	end, resizable and 5 or scale, 1, 2, 3, 4, 5)
	guielements["opt_scale"].displayentries = {"*1", "*2", "*3", "*4", "resizable"}

	--Letterbox
	guielements["opt_letterbox"] = guielement:new("checkbox", right-9, 51, function(v)
		letterboxfullscreen = v
		guielements["opt_letterbox"].var = v
		saveconfig()
	end, letterboxfullscreen)

	--Shader1 and Shader2
	if shaderssupported ~= false then
		local shaderwidth = 1
		for i = 1, #shaderlist do
			shaderwidth = math.max(shaderwidth, utf8.len(shaderlist[i]))
		end

		for slot = 1, 2 do
			local name = "opt_shader" .. slot
			local start = currentshaderi1
			if slot == 2 then
				start = currentshaderi2
			end

			guielements[name] = guielement:new("dropdown", right-(13+shaderwidth*8), 63+(slot-1)*13, shaderwidth, function(i)
				if slot == 1 then
					currentshaderi1 = i
				else
					currentshaderi2 = i
				end

				if shaderlist[i] == "none" then
					shaders:set(slot, nil)
				else
					shaders:set(slot, shaderlist[i])
				end
				guielements[name].var = i
				saveconfig()
			end, start, unpack(shaderlist))
		end
	end

	--Change Language
	guielements["opt_language"] = guielement:new("button", 30, 124, TEXT["change language"], function()
		languagemenuopen = true
		languagemenu_open()
	end)

	--Generate Nitpicks File
	guielements["opt_nitpicks"] = guielement:new("button", 30, 137, "generate nitpicks file", function()
		generatenitpicksfile()
	end)

	--Reset Included Maps
	guielements["opt_resetmaps"] = guielement:new("button", 30, 150, TEXT["reset included maps"], function()
		reset_mappacks()
	end)
	guielements["opt_resetmaps"].textcolor = {255, 0, 0}

	--Reset All Settings
	guielements["opt_resetall"] = guielement:new("button", 30, 163, TEXT["reset all settings"], function()
		resetconfig()
	end)
	guielements["opt_resetall"].textcolor = {255, 0, 0}

	--Volume
	guielements["opt_volume"] = volumeslider_new(90, 109, right-90)

	--VSync
	guielements["opt_vsync"] = guielement:new("checkbox", right-9, 177, function(v)
		vsync = v
		guielements["opt_vsync"].var = v
		changescale(scale)
		saveconfig()
	end, vsync)

	--Mappack Folder
	previousmappackfolder = mappackfolder
	local start = 2
	if mappackfolder == "mappacks" then
		start = 1
	end

	guielements["opt_mappackfolder"] = guielement:new("dropdown", 30, 190, 17, function(i)
		local option = guielements["opt_mappackfolder"].entries[i]
		if option == "mappacks" then
			mappackfolder = "mappacks"
			savesfolder = "saves"
		else
			mappackfolder = "alesans_entities/mappacks"
			savesfolder = "alesans_entities/saves"
		end
		guielements["opt_mappackfolder"].var = i

		if mappackfolder ~= previousmappackfolder then
			previousmappackfolder = mappackfolder
			mappack = "smb"
			loadbackground("1-1.txt")
		end
		saveconfig()
	end, start, "mappacks", "alesans_entities")
	guielements["opt_mappackfolder"].displayentries = {"mappacks", "alesan's entities"}
end

local function optionsmisc_remove()
	for i = 1, #optionsmiscgui do
		guielements[optionsmiscgui[i]] = nil
	end
end

local nitpickkeys = {
	"dropshadow",
	"assistmode",
	"playmusicineditor",
	"disabletooltips",
	"disablemouseinmainmenu",
	"noportalgun",
	"mariomakergravity",
	"dontpauseonunfocus",
	"firebuttoncannonhelmet",
	"pipesineditor",
	"noonlinemultiplayernames",
	"letterbox",
	"customportalcolors",
	"usebuttoncappy",
	"showplayercoords",
	"alwaysnocustomenemybg",
	"showtime",
	"showbattery",
	"showfps",
	"infinitelivesmultiplayer",
	"slowbackgrounds",
	"nomusic",
	"alwaysinfinitetime",
	"alwaysinfinitelives",
	"centercamera",
	"render3d",
	"viewhitboxes",
	"viewanimationnumbers",
	"pcversion",
	"hideandroidbuttons",
	"androidversion",
	"debugGraphs",
	"console",
	"noexitconfirmation",
	"persistenteditortools",
	"persistenteditortoolslocal",
	"dpifix",
	"noeditorpreviews",
	"displayhiddenenemiesinspawner",
	"completelycenteredcamera",
	"modernmultiplayercamera",
	"splitscreenmultiplayer",
	"horizontalsplitscreenviewports",
	"hurrymode",
	"hurrymodeskipfanfare",
	"disabletransitions",
	"infinitefireballs",
	"rapidfire"
}

function generatenitpicksfile()
	local path = "alesans_entities/nitpicks.json"
	local existed = love.filesystem.getInfo(path) ~= nil
	local t = {}
	local edited = false

	if existed then
		local data = love.filesystem.read(path)
		local decoded = JSON:decode(data or "")
		if type(decoded) == "table" then
			for k, v in pairs(decoded) do
				t[tostring(k):lower()] = v
			end
		end
	else
		edited = true
	end

	for _, key in ipairs(nitpickkeys) do
		local lowerkey = key:lower()
		if t[lowerkey] == nil then
			t[lowerkey] = false
			edited = true
		end
	end

	if not existed or edited then
		local out = {}
		for _, key in ipairs(nitpickkeys) do
			out[key] = t[key:lower()]
		end
		love.filesystem.write(path, JSON:encode_pretty(out))
	end

	if not existed then
		notice.new("nitpicks file created!")
	elseif edited then
		notice.new("nitpicks file fixed!")
	else
		notice.new("nitpicks file already exists!")
	end
end

--keeps the widgets in line with the variables when something else changed them (keyboard, reset all settings, ...)
local function optionsmisc_sync()
	guielements["opt_scale"].var = resizable and 5 or scale
	guielements["opt_letterbox"].var = letterboxfullscreen
	guielements["opt_vsync"].var = vsync

	if guielements["opt_shader1"] then
		guielements["opt_shader1"].var = currentshaderi1
		guielements["opt_shader2"].var = currentshaderi2
	end

	--the slider follows the volume unless it is being dragged or is animating from a key press
	volumeslider_animate(guielements["opt_volume"])
	if not guielements["opt_volume"].dragging and not guielements["opt_volume"].valueanim and guielements["opt_volume"].value ~= volume then
		guielements["opt_volume"].value = volume
		guielements["opt_volume"].savedvalue = volume
	end

	previousmappackfolder = mappackfolder
	if mappackfolder == "mappacks" then
		guielements["opt_mappackfolder"].var = 1
	else
		guielements["opt_mappackfolder"].var = 2
	end

	--the widget the keyboard has selected looks hovered
	for selection, name in pairs(optionsmiscselection) do
		if guielements[name] then
			guielements[name].forcehover = (optionsselection == selection)
		end
	end
end

function optionsmisc_update()
	if gamestate == "options" and optionstab == 3 then
		if not guielements["opt_scale"] then
			optionsmisc_create()
		end
		optionsmisc_sync()

		--the widgets sit still (no clicks, no hover animations) while the language menu is open
		for i = 1, #optionsmiscgui do
			if guielements[optionsmiscgui[i]] then
				guielements[optionsmiscgui[i]].active = not languagemenuopen
				guielements[optionsmiscgui[i]].nohover = languagemenuopen
			end
		end
	elseif guielements["opt_scale"] then
		optionsmisc_remove()
	end
end

--pressing enter on the widget the keyboard has selected
function optionsmisc_activate(selection)
	local v = guielements[optionsmiscselection[selection]]
	if not v or not v.active then
		return
	end

	if v.type == "button" then
		v.func(unpack(v.arguments)) --force click
	elseif v.type == "checkbox" then
		v.func(not v.var) --toggle
	elseif v.type == "dropdown" then
		--once it is open, the dropdown takes the up/down/enter keys itself (see guielement:keypress in gui.lua)
		if not v.extended then
			v:open(true)
		end
	end
end

--an open dropdown list has to be drawn on top of the other widgets
local function optionsmisc_draw()
	local ontop = {}
	for i = 1, #optionsmiscgui do
		local v = guielements[optionsmiscgui[i]]
		if v then
			if v.extended or (v.listvalue and v.listvalue > 0) then
				table.insert(ontop, v)
			else
				v:draw()
			end
		end
	end

	for i = 1, #ontop do
		ontop[i]:draw()
	end
end

function menu_load()
	love.audio.stop()
	pausedaudio = nil
	music:disableintromusic()
	if dailychallengebuiltingraphics then
		loadcustomsprites()
		loadcustombackgrounds()
		loadanimatedtiles()
		dailychallengebuiltingraphics = false
	end
	if dailychallengebuiltinsounds then
		loadcustomsounds()
		dailychallengebuiltinsounds = false
	end
	if dailychallengerestoremusic then
		loadcustommusic()
		dailychallengerestoremusic = false
	end
	editormode = false
	guielements = {}
	gamestate = "menu"

	selection = 1
	oldmouse = {love.mouse.getPosition()}
	oldjoystick = {}
	mouseonselect = false
	mouseonselecthold = false
	coinanimation = 1
	coinframe = 1
	love.graphics.setBackgroundColor(92, 148, 252)
	scrollsmoothrate = 4
	optionstab = 2
	optionsselection = 1
	keybindpage = 1
	keybindpageanimation = nil
	skinningplayer = 1
	characteri = characters.data[mariocharacter[1]].i
	rgbselection = 1
	colorsetedit = 1
	mappackselection = 1
	onlinemappackselection = 1
	openmappacksbutton = guielement:new("button", 241, 190, "", function() openSaveFolder(mappackfolder) end, nil, 0, 2.5, 147, true)
	openmappacksbutton.active = false
	opendlcbutton = guielement:new("button", 241, 190, "open dlc folder", opendlcfolder, nil, 0, 2.5, 147, true)
	opendlcbutton.active = false
	mappacksearchbar = guielement:new("input", 240, 16, 15, searchmappacks, "", 100, nil, nil, 0)
	mappacksearchbar.active = false
	oldmappacksearchtable = {}
	mappacksearchi = 1
	screenzoom = 1
	screenzoom2 = 1/screenzoom

	downloadedmappacks = {}
	mappackhorscroll = 0
	mappackhorscrollsmooth = 0
	checkpointx = false
	mariocoincount = 0
	objects = nil
	updateplayerproperties("reset")
	love.graphics.setBackgroundColor(backgroundcolor[1])
	
	
	portalanimation = 1
	portalanimationtimer = 0
	portalanimationdelay = 0.08
	
	infmarioY = 0
	infmarioR = 0
	
	infmarioYspeed = 200
	infmarioRspeed = 4
	
	RGBchangespeed = 200
	huechangespeed = 0.5
	spriteset = 1
	speedtarget = 1
	currentanimation = 1
	
	portalcolors = {}
	for i = 1, players do
		portalcolors[i] = {}
	end
	
	continueavailable = false
	if love.filesystem.getInfo(savesfolder .. "/" .. mappack .. ".suspend") then
		continueavailable = true
	end
	
	mariolevel = 1
	marioworld = 1
	mariosublevel = 0
	actualsublevel = 0
	
	--load 1-1 as background
	if mappackbackground and mappackbackground[mappackselection] then
		loadbackground(mappackbackground[mappackselection] .. ".txt")
	else
		loadbackground("1-1.txt")
	end
	
	--tips
	if TEXT["menutips"] then
		currentmenutip = randomitem(TEXT["menutips"])
	else
		currentmenutip = randomitem(menutips)
	end
	menutipoffset = -1280--(-width*16)
	
	--blinking fore the daily challenge tab
	blinktimer = 0
	
	--player select
	currentcustomplayer = false
	
	skipupdate = true
end

function menu_update(dt)
	--coinanimation
	coinanimation = coinanimation + dt*6.75
	while coinanimation >= 6 do
		coinanimation = coinanimation - 5
	end	
	
	coinframe = math.max(1, math.floor(coinanimation))

	--animate animated tiles because I say so
	for i = 1, #animatedtiles do
		animatedtiles[i]:update(dt)
	end

	updatecustombackgrounds(dt)
	optionsmisc_update()
	optionscheats_update()
	optionscontrols_update()
	
	if mappackscroll then
		--smooth the scroll
		if mappackscrollsmooth > mappackscroll then
			mappackscrollsmooth = mappackscrollsmooth - (mappackscrollsmooth-mappackscroll)*dt*5-0.1*dt
			if mappackscrollsmooth < mappackscroll then
				mappackscrollsmooth = mappackscroll
			end
		elseif mappackscrollsmooth < mappackscroll then
			mappackscrollsmooth = mappackscrollsmooth - (mappackscrollsmooth-mappackscroll)*dt*5+0.1*dt
			if mappackscrollsmooth > mappackscroll then
				mappackscrollsmooth = mappackscroll
			end
		end
	end
	
	if onlinemappackscroll then
		--smooth the scroll
		if onlinemappackscrollsmooth > onlinemappackscroll then
			onlinemappackscrollsmooth = onlinemappackscrollsmooth - (onlinemappackscrollsmooth-onlinemappackscroll)*dt*5-0.1*dt
			if onlinemappackscrollsmooth < onlinemappackscroll then
				onlinemappackscrollsmooth = onlinemappackscroll
			end
		elseif onlinemappackscrollsmooth < onlinemappackscroll then
			onlinemappackscrollsmooth = onlinemappackscrollsmooth - (onlinemappackscrollsmooth-onlinemappackscroll)*dt*5+0.1*dt
			if onlinemappackscrollsmooth > onlinemappackscroll then
				onlinemappackscrollsmooth = onlinemappackscroll
			end
		end
	end
	
	if onlinemappackiconchannel2 and onlinemappackiconchannel2:peek() then
		local v = onlinemappackiconchannel2:pop()
		if v[1] == "img" then
			local image = love.graphics.newImage(v[3])
			local url = v[2]
			for i, asset in pairs(onlineassetlist) do
				if asset.icon_url == url then
					asset.icon = image
				end
			end
		end
	end
	if mappacklistthread then
		if mappacklistthread:isRunning() then
			local v = mappacklistthreadchannelout:pop()
			local error = mappacklistthread:getError()
			if v then
				if v[1] == "error" then
					mappacklistthreadchannelin:push({"stop"})
				elseif v[1] == "mappack" then
					if v[6] then
						mappackicon[mappacklistthreadn] = love.graphics.newImage(v[6])
					end
		
					--get info
					mappackname[mappacklistthreadn] = v[2]
					mappackauthor[mappacklistthreadn] = v[3]
					mappackdescription[mappacklistthreadn] = v[4]
					mappackbackground[mappacklistthreadn] = v[5]
					mappackdropshadow[mappacklistthreadn] = v[7]

					mappacklistthreadn = mappacklistthreadn + 1
					if mappacklistthreadn <= #mappacklist-1 then
						mappacklistthreadchannelin:push({mappackfolder .. "/" .. mappacklist[mappacklistthreadn]})
					else
						mappacklistthreadchannelin:push({"stop"})
					end
				end
			end
		else
			local error = mappacklistthread:getError()
			--print(error)
		end
	end
	
	if mappackhorscroll then
		if mappackhorscrollsmooth > mappackhorscroll then
			mappackhorscrollsmooth = mappackhorscrollsmooth - (mappackhorscrollsmooth-mappackhorscroll)*dt*5-0.03*dt
			if mappackhorscrollsmooth < mappackhorscroll then
				mappackhorscrollsmooth = mappackhorscroll
			end
		elseif mappackhorscrollsmooth < mappackhorscroll then
			mappackhorscrollsmooth = mappackhorscrollsmooth - (mappackhorscrollsmooth-mappackhorscroll)*dt*5+0.03*dt
			if mappackhorscrollsmooth > mappackhorscroll then
				mappackhorscrollsmooth = mappackhorscroll
			end
		end
	end
	if mappacksearchbar.active then
		mappacksearchbar:update(dt)
	end

	if gamestate == "options" and optionstab == 2 then
		portalanimationtimer = portalanimationtimer + dt
		while portalanimationtimer > portalanimationdelay do
			portalanimation = portalanimation + 1
			if portalanimation > 6 then
				portalanimation = 1
			end
			portalanimationtimer = portalanimationtimer - portalanimationdelay
		end
		
		infmarioY = infmarioY + infmarioYspeed*dt
		while infmarioY > 64 do
			infmarioY = infmarioY - 64
		end
		
		infmarioR = infmarioR + infmarioRspeed*dt
		while infmarioR > math.pi*2 do
			infmarioR = infmarioR - math.pi*2
		end
	
		if characters.data[mariocharacter[skinningplayer]].colorables and optionsselection > 5 and optionsselection < 9 then
			local colorRGB = optionsselection-5
			
			if (love.keyboard.isDown("right") or love.keyboard.isDown("d")) and mariocolors[skinningplayer][colorsetedit][colorRGB] < 255 then
				mariocolors[skinningplayer][colorsetedit][colorRGB] = mariocolors[skinningplayer][colorsetedit][colorRGB] + RGBchangespeed*dt
				if mariocolors[skinningplayer][colorsetedit][colorRGB] > 255 then
					mariocolors[skinningplayer][colorsetedit][colorRGB] = 255
				end
			elseif (love.keyboard.isDown("left") or love.keyboard.isDown("a")) and mariocolors[skinningplayer][colorsetedit][colorRGB] > 0 then
				mariocolors[skinningplayer][colorsetedit][colorRGB] = mariocolors[skinningplayer][colorsetedit][colorRGB] - RGBchangespeed*dt
				if mariocolors[skinningplayer][colorsetedit][colorRGB] < 0 then
					mariocolors[skinningplayer][colorsetedit][colorRGB] = 0
				end
			end
			
		elseif (characters.data[mariocharacter[skinningplayer]].colorables and optionsselection == 9) or (not characters.data[mariocharacter[skinningplayer]].colorables and optionsselection == 5) then
			if (love.keyboard.isDown("right") or love.keyboard.isDown("d")) and portalhues[skinningplayer][1] < 1 then
				portalhues[skinningplayer][1] = portalhues[skinningplayer][1] + huechangespeed*dt
				if portalhues[skinningplayer][1] > 1 then
					portalhues[skinningplayer][1] = 1
				end
				portalcolor[skinningplayer][1] = getrainbowcolor(portalhues[skinningplayer][1])
				
			elseif (love.keyboard.isDown("left") or love.keyboard.isDown("a")) and portalhues[skinningplayer][1] > 0 then
				portalhues[skinningplayer][1] = portalhues[skinningplayer][1] - huechangespeed*dt
				if portalhues[skinningplayer][1] < 0 then
					portalhues[skinningplayer][1] = 0
				end
				portalcolor[skinningplayer][1] = getrainbowcolor(portalhues[skinningplayer][1])
			end
			
		elseif (characters.data[mariocharacter[skinningplayer]].colorables and optionsselection == 10) or (not characters.data[mariocharacter[skinningplayer]].colorables and optionsselection == 6) then
			if (love.keyboard.isDown("right") or love.keyboard.isDown("d")) and portalhues[skinningplayer][2] < 1 then
				portalhues[skinningplayer][2] = portalhues[skinningplayer][2] + huechangespeed*dt
				if portalhues[skinningplayer][2] > 1 then
					portalhues[skinningplayer][2] = 1
				end
				portalcolor[skinningplayer][2] = getrainbowcolor(portalhues[skinningplayer][2])
				
			elseif (love.keyboard.isDown("left") or love.keyboard.isDown("a")) and portalhues[skinningplayer][2] > 0 then
				portalhues[skinningplayer][2] = portalhues[skinningplayer][2] - huechangespeed*dt
				if portalhues[skinningplayer][2] < 0 then
					portalhues[skinningplayer][2] = 0
				end
				portalcolor[skinningplayer][2] = getrainbowcolor(portalhues[skinningplayer][2])
			end
		end
	elseif gamestate == "onlinemenu" then
		onlinemenu_update(dt)
	elseif gamestate == "lobby" then
		lobby_update(dt)
	end
	
	if titleframes > 1 and gamestate == "menu" and titledelay ~= nil then
		titletimer = titletimer + dt
		while titletimer >= titledelay do
			titleframe = titleframe + 1
			if titleframe > titleframes then
				titleframe = 1
			end
			titletimer = titletimer - titledelay
		end
	end
	
	--use mouse to select
	local x, y = love.mouse.getPosition()
	if (x ~= oldmouse[1] or y ~= oldmouse[2]) and gamestate == "menu" and (not DisableMouseInMainMenu) and (not languagemenuopen) then
		menu_updatemouseselection(x,y)
	end
	oldmouse = {x, y}
	
	--joystick navigation
	if not keyprompt then
		if hasjoystickaxisbinding(1, "right") then
			if joystickaxisdown(1, "right") then
				if not oldjoystick[1] then
					menu_keypressed("right")
					oldjoystick[1] = true
				end
			else
				oldjoystick[1] = false
			end
		end
		if hasjoystickaxisbinding(1, "left") then
			if joystickaxisdown(1, "left") then
				if not oldjoystick[2] then
					menu_keypressed("left")
					oldjoystick[2] = true
				end
			else
				oldjoystick[2] = false
			end
		end
		if hasjoystickaxisbinding(1, "down") then
			if joystickaxisdown(1, "down") then
				if not oldjoystick[3] then
					menu_keypressed("down")
					oldjoystick[3] = true
				end
			else
				oldjoystick[3] = false
			end
		end
		if hasjoystickaxisbinding(1, "up") then
			if joystickaxisdown(1, "up") then
				if not oldjoystick[4] then
					menu_keypressed("up")
					oldjoystick[4] = true
				end
			else
				oldjoystick[4] = false
			end
		end
	end
	
	if not disabletips then
		menutipoffset = menutipoffset + 80*dt
		while menutipoffset > currentmenutip:len()*8 do
			menutipoffset = menutipoffset - (utf8.len(currentmenutip)*8) - (width*16)*2
			if TEXT["menutips"] then
				currentmenutip = randomitem(TEXT["menutips"])
			else
				currentmenutip = randomitem(menutips)
			end
		end
	end
	
	--blink
	blinktimer = blinktimer + dt
	while blinktimer > 1 do
		blinktimer = blinktimer - 1
	end

	if languagemenuopen then
		languagemenu_update(dt)
	end
end

function menu_draw()
	--GUI LIBRARY?! Never heard of that.
	--I'm not proud of this at all; But I'm even lazier than not proud.

	--TILES
	love.graphics.translate(0, yoffset*scale)
	local xtodraw
	if mapwidth < width+1 then
		xtodraw = mapwidth
	else
		if mapwidth > width then
			xtodraw = width+1
		else
			xtodraw = width
		end
	end
	
	local ytodraw
	if mapheight > height-1 then
		ytodraw = height+2
	else
		ytodraw = height+1
	end
		
	--custom background
	rendercustombackground(0,0)

	--BACKGROUND TILES
	if bmap_on then
		if editormode then
			love.graphics.setColor(255,255,255,100)
		else
			love.graphics.setColor(255,255,255,255)
		end
		for y = 1, ytodraw do
			for x = 1, xtodraw do
				local backgroundtile = bmapt(x, y, 1)
				if backgroundtile then
					if not tilequads[backgroundtile] then 
						print("background tile doesn't exist:",backgroundtile)
					else
						love.graphics.draw(tilequads[backgroundtile].image, tilequads[backgroundtile].quad, math.floor((x-1)*16*scale), ((y-1)*16-8)*scale, 0, scale, scale)
					end
				end
			end
		end
		love.graphics.setColor(255,255,255,255)
	end

	--Drop Shadow
	if dropshadow then
		love.graphics.setColor(dropshadowcolor)
		love.graphics.push()
		love.graphics.translate(3*scale, 3*scale)
		drawmaptiles("menudropshadow", 0, 0, xtodraw, ytodraw)
		love.graphics.pop()
	end
	
	love.graphics.setColor(255, 255, 255)
	drawmaptiles("menu", 0, 0, xtodraw, ytodraw)
	
	--[[for y = 1, ytodraw do
		for x = 1, xtodraw do
			local t = map[x][y]
			if t then --cheap fix
				local tilenumber = tonumber(t[1])
				if tilequads[tilenumber].coinblock and tilenumber < 90000 and tilequads[tilenumber].invisible == false then --coinblock
					love.graphics.draw(coinblockimage, coinblockquads[spriteset][coinframe], math.floor((x-1)*16*scale), ((y-1)*16-8)*scale, 0, scale, scale)
				elseif (tilequads[tilenumber].coin and tilenumber < 90000) or (t[2] == "187") then --coin
					love.graphics.draw(coinimage, coinquads[spriteset][coinframe], math.floor((x-1)*16*scale), ((y-1)*16-8)*scale, 0, scale, scale)
				elseif tilenumber ~= 0 and not tilequads[tilenumber].invisible then
					love.graphics.draw(tilequads[tilenumber].image, tilequads[tilenumber].quad, math.floor((x-1)*16*scale), ((y-1)*16-8)*scale, 0, scale, scale)
				end
			end
		end
	end]]
	
	for j = 1, math.min(4, players) do
		local char = mariocharacter[j]
		local v = characters.data[char]
		if (not v) or (not v["animations"]) then
			mariocharacter[j] = "mario"
			v = characters.data[char]
			if not v then
				break
			end
		end
	
		--draw player
		love.graphics.setColor(255, 255, 255, 255)
		local idlei = 3
		if not portalgun or (playertype == "classic" or playertype == "cappy") then
			idlei = 5
		end
		for k = 1, #v.colorables do
			if v["animations"] then
				love.graphics.setColor(mariocolors[j][k] or {0,0,0})
				love.graphics.draw(v["animations"][k], v["small"]["idle"][idlei], (startx*16-6+v.smalloffsetX)*scale+8*(j-1)*scale, (starty*16-12-v.smalloffsetY)*scale, 0, scale, scale, v.smallquadcenterX, v.smallquadcenterY)
			end
		end
		
		--hat
		offsets = customplayerhatoffsets(char, "hatoffsets", "idle") or hatoffsets["idle"]
		if v.hats then
			if #mariohats[j] > 1 or mariohats[j][1] ~= 1 then
				local yadd = 0
				for i = 1, #mariohats[j] do
					love.graphics.setColor(255, 255, 255)
					love.graphics.draw(hat[mariohats[j][i]].graphic, hat[mariohats[j][i]].quad[1], (startx*16-6+v.smalloffsetX)*scale+8*(j-1)*scale, (starty*16-12-v.smalloffsetY)*scale, 0, scale, scale, v.smallquadcenterX - hat[mariohats[j][i]].x + offsets[1], v.smallquadcenterY - hat[mariohats[j][i]].y + offsets[2] + yadd)
					yadd = yadd + (hat[mariohats[j][i]].height or 0)
				end
			elseif #mariohats[j] == 1 then
				love.graphics.setColor(mariocolors[j][1])
				love.graphics.draw(hat[mariohats[j][1]].graphic, hat[mariohats[j][1]].quad[1], (startx*16-6+v.smalloffsetX)*scale+8*(j-1)*scale, (starty*16-12-v.smalloffsetY)*scale, 0, scale, scale, v.smallquadcenterX - hat[mariohats[j][1]].x + offsets[1], v.smallquadcenterY - hat[mariohats[j][1]].y + offsets[2])
			end
		end
		
		if v["animations"] then
			love.graphics.setColor(255, 255, 255, 255)
			love.graphics.draw(v["animations"][0], v["small"]["idle"][idlei], (startx*16-6+v.smalloffsetX)*scale+8*(j-1)*scale, (starty*16-12-v.smalloffsetY)*scale, 0, scale, scale, v.smallquadcenterX, v.smallquadcenterY)
		end
	end
	
	---UI
	local properprintfunc = properprintF
	if hudoutline then
		properprintfunc = properprintFbackground
	end
	if hudvisible then
		drawHUD()
	end
	
	love.graphics.setColor(255, 255, 255, 255)
	
	--custom foreground
	rendercustomforeground(0,0)
	
	if gamestate == "menu" then
		local x = (40-8*((titlewidth-176)/24))--position of title logo
		love.graphics.draw(titleimage, titlequad[titleframe], x*scale, 24*scale, 0, scale, scale)
		
		love.graphics.setColor(255, 255, 255)
		properprintF("©2012-2024 maurice", (x+titlewidth-144)*scale, 112*scale)
		love.graphics.setColor(255, 255, 255, 255)
		
		if selection == 0 then
			love.graphics.draw(menuselectimg, (129-(math.ceil((utf8.len(TEXT["continue game"]))/2)*8))*scale, (137+(selection-1)*16)*scale, 0, scale, scale)
		elseif selection == 1 then
			love.graphics.draw(menuselectimg, (134-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8)-5)*scale, (137+(selection-1)*16)*scale, 0, scale, scale)
		elseif selection == 2 then
			love.graphics.draw(menuselectimg, (129-(math.ceil((utf8.len(TEXT["level editor"]))/2)*8))*scale, (137+(selection-1)*16)*scale, 0, scale, scale)
		elseif selection == 3 then
			love.graphics.draw(menuselectimg, (129-(math.ceil((utf8.len(TEXT["select mappack"]))/2)*8))*scale, (137+(selection-1)*16)*scale, 0, scale, scale)
		elseif selection == 4 then
			love.graphics.draw(menuselectimg, (129-(math.ceil((utf8.len(TEXT["options"]))/2)*8))*scale, (137+(selection-1)*16)*scale, 0, scale, scale)
		end
		
		local start = 9
		if (custombackground or customforeground) and not hudoutline then
			start = 1
		end
		
		for i = start, 9 do
			local tx, ty = -scale, scale
			love.graphics.setColor(0, 0, 0)
			if i == 2 then
				tx, ty = scale, scale
			elseif i == 3 then
				tx, ty = -scale, -scale
			elseif i == 4 then
				tx, ty = scale, -scale
			elseif i == 5 then
				tx, ty = 0, -scale
			elseif i == 6 then
				tx, ty = 0, scale
			elseif i == 7 then
				tx, ty = scale, 0
			elseif i == 8 then
				tx, ty = -scale, 0
			elseif i == 9 then
				tx, ty = 0, 0
				love.graphics.setColor(255, 255, 255)
			end
			
			love.graphics.translate(tx, ty)
			
			if continueavailable then
				if i == 9 then if mouseonselecthold and mouseonselect == 0 then love.graphics.setColor(188, 188, 188) else love.graphics.setColor(255, 255, 255) end end
				properprintfunc(TEXT["continue game"], (143-(math.ceil(utf8.len(TEXT["continue game"])/2)*8))*scale, 122*scale)
			end
			
			if i == 9 then if mouseonselecthold and mouseonselect == 1 then love.graphics.setColor(188, 188, 188) else love.graphics.setColor(255, 255, 255) end end
			properprintfunc(TEXT["player game"], (143-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8)+16)*scale, 138*scale)
			
			properprintfunc(players, (143-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8))*scale, 138*scale)
			if i == 9 then if (mouseonselecthold and mouseonselect == 2) then love.graphics.setColor(188, 188, 188) else love.graphics.setColor(255, 255, 255) end end
			properprintfunc(TEXT["level editor"], (143-(math.ceil(utf8.len(TEXT["level editor"])/2)*8))*scale, 154*scale)
			
			if i == 9 then if mouseonselecthold and mouseonselect == 3 then love.graphics.setColor(188, 188, 188) else love.graphics.setColor(255, 255, 255) end end
			properprintfunc(TEXT["select mappack"], (143-(math.ceil(utf8.len(TEXT["select mappack"])/2)*8))*scale, 170*scale)
			
			if i == 9 then if mouseonselecthold and mouseonselect == 4 then love.graphics.setColor(188, 188, 188) else love.graphics.setColor(255, 255, 255) end end
			properprintfunc(TEXT["options"], (143-(math.ceil(utf8.len(TEXT["options"])/2)*8))*scale, 186*scale)
			
			if i == 9 then love.graphics.setColor(255, 255, 255) end
			
			--if not (not disabletips and menutipoffset > -width*16) then
				brprint("mod by alesan99", 204)

				if mouseinrect(232, 210, 160, 8) then
					brprint("le- legendary edition", 212)
				else
					brprint("le mod by lukemaniac", 212)
				end
			--end
			
			love.graphics.translate(-tx, -ty)
		end
		
		if players >= 1 then
			love.graphics.draw(playerselectarrowimg, (138-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8))*scale, 138*scale, 0, scale, scale)
		end
		
		if players < 4 then
			love.graphics.draw(playerselectarrowimg, (158-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8))*scale, 138*scale, 0, -scale, scale)
		end
		
        local now = love.timer.getTime()
        local warningpopupscale = menupopupscale("newgamewarning", now)
        if newgamewarning or warningpopupscale > 0 then
            love.graphics.push()
            love.graphics.translate(130*scale, 122*scale)
            love.graphics.scale(warningpopupscale, warningpopupscale)
            love.graphics.translate(-130*scale, -122*scale)

            local warningprogress = warningpopupscale
            love.graphics.translate(0, (1 - warningprogress) * 8 * scale)

            local popupradius = math.min(220, 60) * scale * 0.2
            love.graphics.setColor(0, 0, 0)
            love.graphics.rectangle("fill", 20*scale, 92*scale, 220*scale, 60*scale, popupradius)
            love.graphics.setColor(255, 255, 255)
            local previouslinewidth = love.graphics.getLineWidth()
            love.graphics.setLineWidth(scale)
            love.graphics.rectangle("line", 20*scale, 92*scale, 220*scale, 60*scale, popupradius)
            love.graphics.setLineWidth(previouslinewidth)
            properprintF(TEXT["starting a new game will"], (130-(utf8.len(TEXT["starting a new game will"])*4))*scale, 100*scale)
            properprintF(TEXT["delete your existing save!"], (130-(utf8.len(TEXT["delete your existing save!"])*4))*scale, 110*scale)
            
            if newgamewarningcursor == 1 then
                properprintF(">", (120-((utf8.len(TEXT["new game"])+utf8.len(TEXT["go back"]))*4)-16)*scale, 130*scale)
                love.graphics.setColor(255, 255, 255, 255)
                properprintF(TEXT["new game"], (130-((utf8.len(TEXT["new game"])+utf8.len(TEXT["go back"]))*4)-16)*scale, 130*scale)
                love.graphics.setColor(100, 100, 100, 255)
                properprintF(TEXT["go back"], (130-((utf8.len(TEXT["new game"])-utf8.len(TEXT["go back"]))*4)+16)*scale, 130*scale)
            else
                properprintF(">", (120-((utf8.len(TEXT["new game"])-utf8.len(TEXT["go back"]))*4)+16)*scale, 130*scale)
                love.graphics.setColor(100, 100, 100, 255)
                properprintF(TEXT["new game"], (130-((utf8.len(TEXT["new game"])+utf8.len(TEXT["go back"]))*4)-16)*scale, 130*scale)
                love.graphics.setColor(255, 255, 255, 255)
                properprintF(TEXT["go back"], (130-((utf8.len(TEXT["new game"])-utf8.len(TEXT["go back"]))*4)+16)*scale, 130*scale)
            end

            love.graphics.pop()
        end
		
		local worldpopupscale = menupopupscale("selectworld", now)
		if selectworldopen or worldpopupscale > 0 then
			love.graphics.push()
			love.graphics.translate(130*scale, 122*scale)
			love.graphics.scale(worldpopupscale, worldpopupscale)
			love.graphics.translate(-130*scale, -122*scale)

			local popupradius = math.min(220, 60) * scale * 0.2
			love.graphics.setColor(0, 0, 0)
			love.graphics.rectangle("fill", 20*scale, 92*scale, 220*scale, 60*scale, popupradius)
			love.graphics.setColor(255, 255, 255)
			local previouslinewidth = love.graphics.getLineWidth()
			love.graphics.setLineWidth(scale)
			love.graphics.rectangle("line", 20*scale, 92*scale, 220*scale, 60*scale, popupradius)
			love.graphics.setLineWidth(previouslinewidth)
			properprintF(TEXT["select world"], (130-(utf8.len(TEXT["select world"])*4))*scale, 105*scale)
			
			local sc = selectworldcursor
			local v = math.ceil(sc/8)*8-7
			
            love.graphics.setScissor(43*scale, 93*scale, 173*scale, 58*scale)

            local now = love.timer.getTime()
            local function drawworldpage(page, pageoffset, drawcursor)
                for i = page, page+7 do
                    local color
                    if selectworldcursor == i then
                        color = 255
                    elseif previousselectworldcursor == i and previousselectworldtime then
                        local previousprogress = math.min((now - previousselectworldtime) / 0.22, 1)
                        local targetcolor
                        if reachedworlds[mappack][i] then
                            targetcolor = 200
                        elseif selectworldexists[i] then
                            targetcolor = 50
                        else
                            targetcolor = 0
                        end
                        color = lerp(255, targetcolor, previousprogress)
                    elseif reachedworlds[mappack][i] then
                        color = 200
                    elseif selectworldexists[i] then
                        color = 50
                    else
                        color = 0
                    end
                    love.graphics.setColor(color, color, color)

                    local world = i
                    if hudworldletter and i > 9 and i <= 9+#alphabet then
                        world = alphabet:sub(i-9, i-9)
                    end
                    local worldx = 55 + (i-page)*20 + pageoffset
                    properprint(world, worldx*scale, 130*scale)

                    if drawcursor and selectworldcursor == i then
                        local cursorprogress = math.min((now - selectworldcursoranimstart) / 0.22, 1)
                        cursorprogress = motion_curve(cursorprogress, selectworldcursorcurve, true, false, true, true)
                        local cursorx = 55 + (i-page)*20
                        local cursoroffset = 0
                        if previousselectworldx then
                            cursorx = lerp(previousselectworldx, cursorx, cursorprogress)
                        else
                            cursoroffset = (1 - cursorprogress) * 4
                        end
                        love.graphics.setColor(255, 255, 255)
                        properprint("v", (cursorx + pageoffset)*scale, (120 + cursoroffset)*scale)
                    end
                end
            end

            local scrollrawprogress
            if selectworldpreviouspage then
                scrollrawprogress = (now - selectworldscrollstart) / 0.28
            end

            if scrollrawprogress and scrollrawprogress < 1 then
                local scrollprogress = motion_curve(scrollrawprogress, selectworldscrollcurve, true, false, true, true)
                local direction = v > selectworldpreviouspage and -1 or 1
                drawworldpage(selectworldpreviouspage, direction * scrollprogress * 160, false)
                drawworldpage(v, -direction * (1 - scrollprogress) * 160, true)
            else
                drawworldpage(v, 0, true)
            end

            love.graphics.setScissor()
            love.graphics.setColor(255, 255, 255)
			if v ~= 1 then
				properprintF("{", 35*scale, 130*scale)
			end
			if v+7 < #mappacklevels then
				properprintF("}", 215*scale, 130*scale)
			end
			love.graphics.pop()
		end
		
		--menu tip
		if not disabletips and menutipoffset > -width*16 then
			love.graphics.setColor(0, 0, 0, 140)
			love.graphics.rectangle("fill", 0*scale, 208*scale, width*16*scale, 11*scale)
			love.graphics.setColor(255, 255, 255, 200)
			properprintF(utf8.sub(currentmenutip, 1, math.floor((menutipoffset+(width*16))/8)+1), -menutipoffset*scale, 210*scale)
		end
		
	elseif gamestate == "mappackmenu" then
		--background
		love.graphics.setColor(0, 0, 0, 100)
		love.graphics.rectangle("fill", 21*scale, 16*scale, 218*scale, 200*scale)
		love.graphics.setColor(255, 255, 255, 255)
		
		--set scissor
		love.graphics.setScissor(21*scale, 16*scale, 218*scale, 200*scale)
		
		if loadingonlinemappacks then
			love.graphics.setColor(0, 0, 0, 200)
			love.graphics.rectangle("fill", 21*scale, 16*scale, 218*scale, 200*scale)
			love.graphics.setColor(255, 255, 255, 255)
			properprint("a little patience..\ndownloading " .. currentdownload .. " of " .. downloadcount, 50*scale, 30*scale)
			drawrectangle(50, 55, 152, 10)
			love.graphics.rectangle("fill", 50*scale, 55*scale, 152*((currentfiledownload-1)/(filecount-1))*scale, 10*scale)
		else
			love.graphics.translate(-round(mappackhorscrollsmooth*scale*mappackhorscrollrange), 0)
			
			--mappacks
			if mappackhorscrollsmooth < 1 then
				--draw each butten (even if all you do, is press ONE. BUTTEN.)
				--scrollbar offset
				love.graphics.translate(0, -round(mappackscrollsmooth*60*scale))
				
				love.graphics.setScissor(21*scale, 16*scale, 218*scale, 200*scale)
				
				for i = math.max(1, math.floor(mappackscrollsmooth+1)), math.min(#mappacklist, math.floor(mappackscrollsmooth+5)) do
					--back
					love.graphics.draw(mappackback, 25*scale, (20+(i-1)*60)*scale, 0, scale, scale)
					
					--icon
					if mappackicon[i] ~= nil then
						local scale2w = scale*50 / math.max(1, mappackicon[i]:getWidth())
						local scale2h = scale*50 / math.max(1, mappackicon[i]:getHeight())
						love.graphics.draw(mappackicon[i], 29*scale, (24+(i-1)*60)*scale, 0, scale2w, scale2h)
					elseif i > mappacklistthreadn and i ~= #mappacklist then
						love.graphics.setColor(0, 0, 0)
						love.graphics.rectangle("fill", 29*scale, (24+(i-1)*60)*scale, 50*scale, 50*scale)
						love.graphics.setColor(255, 255, 255)
						love.graphics.draw(mappackloadingicon, (29+25)*scale, (24+(i-1)*60+25)*scale, (coinanimation/5)*math.pi*2, scale, scale, 25, 25)
					else
						love.graphics.draw(mappacknoicon, 29*scale, (24+(i-1)*60)*scale, 0, scale, scale)
					end
					love.graphics.draw(mappackoverlay, 29*scale, (24+(i-1)*60)*scale, 0, scale, scale)
					
					--name
					love.graphics.setColor(200, 200, 200)
					if mappackselection == i then
						love.graphics.setColor(255, 255, 255)
					end
					
					properprint(string.sub(mappackname[i] or mappacklist[i]:lower(), 1, 17), 83*scale, (26+(i-1)*60)*scale)
					
					--author
					love.graphics.setColor(100, 100, 100)
					if mappackselection == i then
						love.graphics.setColor(100, 100, 100)
					end
					
					if mappackauthor[i] then
						local by = TEXT["by"]
						if #by ~= utf8.len(by) then
							properprintF(string.sub(by .. " " .. mappackauthor[i], 1, 17), 83*scale, (35+(i-1)*60)*scale)
						else
							properprint(string.sub(by .. " " .. mappackauthor[i], 1, 17), 83*scale, (35+(i-1)*60)*scale)
						end
					end
					
					--description
					love.graphics.setColor(130, 130, 130)
					if mappackselection == i then
						love.graphics.setColor(180, 180, 180)
					end
					
					if mappackdescription[i] then
						properprint( string.sub(mappackdescription[i] or "", 1, 17), 83*scale, (47+(i-1)*60)*scale)
						
						if mappackdescription[i]:len() > 17 then
							properprint( string.sub(mappackdescription[i] or "", 18, 34), 83*scale, (56+(i-1)*60)*scale)
						end
						
						if mappackdescription[i]:len() > 34 then
							properprint( string.sub(mappackdescription[i] or "", 35, 51), 83*scale, (65+(i-1)*60)*scale)
						end
					end
					
					love.graphics.setColor(255, 255, 255)
					
					--highlight
					if i == mappackselection then
						love.graphics.draw(mappackhighlight, 25*scale, (20+(i-1)*60)*scale, 0, scale, scale)
					end
				end
			
				love.graphics.translate(0, round(mappackscrollsmooth*60*scale))
			
				local i = mappackscrollsmooth / (#mappacklist-3.233)
			
				love.graphics.draw(mappackscrollbar, 227*scale, (20+i*160)*scale, 0, scale, scale)
			
				if mappackhorscrollsmooth <= 0.01 then
					love.graphics.setScissor()
					love.graphics.setColor(0, 0, 0, 200)
					love.graphics.rectangle("fill", 241*scale, 125*scale, 150*scale, 65*scale, 10*scale)
					love.graphics.setColor(255, 255, 255, 255)
					if not savefolderfailed then
						properprintF(TEXT["mappack folder instructions"], 244*scale, 129*scale)
					else
						properprintF(TEXT["mappack folder fail"], 244*scale, 129*scale)
					end
					openmappacksbutton:draw()
					properprintF("       open\n  mappacks folder", 239*scale, 194*scale)
					if mappacksearchbar.active then
						mappacksearchbar:draw()
					end
				end
			end
			
			love.graphics.translate(round(mappackhorscrollsmooth*scale*mappackhorscrollrange), 0)
			----------
			--ONLINE--
			----------
			
			love.graphics.translate(round(mappackhorscrollrange*scale - mappackhorscrollsmooth*scale*mappackhorscrollrange), 0)
			
			if mappackhorscrollsmooth > 0 and mappackhorscrollsmooth < 2 and onlineassetlist then
				if #onlineassetlist == 0 then -- todo uhh i dont think this can be reached, it looks broken
					properprintF("something went wrong\n\n      sorry d:\n\nmaybe your internet\ndoes not work right?", 40*scale, 80*scale)
				end
				
				love.graphics.setScissor()
				if mappackhorscrollsmooth <= 1.01 then
					love.graphics.setColor(0, 0, 0, 200)
					love.graphics.rectangle("fill", 241*scale, 16*scale, 150*scale, 180*scale)
					love.graphics.setColor(255, 255, 255, 255)
					local asset = onlineassetlist[onlinemappackselection]

					local message
					if asset and asset.downloadable then
						message = TEXT["dlc dl instructions"]
					else
						message = TEXT["dlc instructions"]

						local y = (19 + 10 * (1 + #(message:split("\n"))))*scale
						if asset and asset.type == "enemy" then
							properprintF(TEXT["dlc enemy instructions"], 244*scale, y)
						elseif asset and (asset.type == "mappack" or asset.type == "character") then
							properprintF(TEXT["dlc asset instructions"], 244*scale, y)
						end
					end
					properprintF(message, 244*scale, 19*scale)

					love.graphics.setColor(255, 255, 255, 255)
					-- TODO: these aren't initialized
					if outdated then
						love.graphics.setColor(255, 0, 0, 255)
						properprintF("version outdated!\nyou have an old\nversion of mari0!\nmappacks could not\nbe downloaded.\ngo to\nstabyourself.net\nto download latest", 244*scale, 130*scale)
						love.graphics.setColor(255, 255, 255, 255)
					elseif onlinemappackerror then
						love.graphics.setColor(255, 0, 0, 255)
						properprintF("download error!\nsomething went\nwrong while\ndownloading\nyour mappack.\ntry again.\nsorry.", 244*scale, 130*scale)
						love.graphics.setColor(255, 255, 255, 255)
					end

					if asset and asset.type == "character" then
						love.graphics.setColor(255, 255, 255, 255)
						opendlcbutton.text = TEXT["characters folder"]
					else
						opendlcbutton.text = TEXT["open dlc folder"]
					end

					opendlcbutton:draw()
				end
					
				love.graphics.setScissor(21*scale, 16*scale, 218*scale, 200*scale)
				
				--scrollbar offset
				love.graphics.translate(0, -round(onlinemappackscrollsmooth*60*scale))
				for i = math.max(1, math.floor(onlinemappackscrollsmooth+1)), math.min(#onlineassetlist, math.floor(onlinemappackscrollsmooth+5)) do
					local asset = onlineassetlist[i]
					local bonuscontent = asset.type == "enemy" or asset.type == "character"

					--back
					if downloadedmappacks[i] then
						if downloadedmappacks[i] == true then
							love.graphics.setColor(0, 100, 0, 179)
						else
							love.graphics.setColor(100, 0, 0, 179)
						end
						love.graphics.rectangle("fill", 25*scale, (20+(i-1)*60)*scale, 200*scale, 58*scale)
					else
						love.graphics.draw(mappackback, 25*scale, (20+(i-1)*60)*scale, 0, scale, scale)
					end
					
					--icon
					love.graphics.setColor(255, 255, 255)
					if asset.icon then
						local scale2w = scale*50 / math.max(1, asset.icon:getWidth())
						local scale2h = scale*50 / math.max(1, asset.icon:getHeight())
						love.graphics.draw(asset.icon, 29*scale, (24+(i-1)*60)*scale, 0, scale2w, scale2h)
					else
						love.graphics.draw(mappackonlineicon, mappackonlineiconquad[1], 29*scale, (24+(i-1)*60)*scale, 0, scale, scale)
					end

					love.graphics.draw(mappackoverlay, 29*scale, (24+(i-1)*60)*scale, 0, scale, scale)
					local qi = 2
					if (not onlinedlc) then
						qi = 3
					elseif asset.type == "enemy" then
						qi = 5
					elseif asset.type == "character" then
						qi = 6
					elseif asset.type == "video" then
						qi = 7
					end
					love.graphics.setColor(0, 0, 0, 150)
					love.graphics.draw(mappackonlineicon, mappackonlineiconquad[qi], 63*scale, (26+(i-1)*60)*scale, 0, scale, scale)
					love.graphics.setColor(255, 255, 255)
					love.graphics.draw(mappackonlineicon, mappackonlineiconquad[qi], 63*scale, (25+(i-1)*60)*scale, 0, scale, scale)
					
					--name
					love.graphics.setColor(200, 200, 200)
					if onlinemappackselection == i then
						love.graphics.setColor(255, 255, 255)
					end
					
					properprint(string.sub(asset.name:lower(), 1, 17), 83*scale, (26+(i-1)*60)*scale)
					
					--author
					love.graphics.setColor(100, 100, 100)
					if onlinemappackselection == i then
						love.graphics.setColor(100, 100, 100)
					end
					
					if asset.author then
						local by = TEXT["by"]
						if #by ~= utf8.len(by) then
							properprintF(string.sub(by .. " " .. asset.author:lower(), 1, 17), 83*scale, (35+(i-1)*60)*scale)
						else
							properprint(string.sub(by .. " " .. asset.author:lower(), 1, 17), 83*scale, (35+(i-1)*60)*scale)
						end
					end
					
					--description
					love.graphics.setColor(130, 130, 130)
					if onlinemappackselection == i then
						love.graphics.setColor(180, 180, 180)
					end
					
					if asset.description then
						-- compute description lines (max 3 lines, max length 17 char per line, accept newline)
						local description = asset.description:lower()
						local lines = {}
						local line = ""
						for ci = 1, #description do
							local c = description:sub(ci,ci)
							if c == "\n" then
								table.insert(lines, line)
								if #lines >= 3 then break end
								line = ""
							elseif #line >= 17 then
								table.insert(lines, line)
								if #lines >= 3 then break end
								line = c
							else
								line = line .. c
							end
						end
						if line ~= "" then
							table.insert(lines, line)
						end

						-- display lines
						for li = 1, #lines do
							properprint(lines[li], 83*scale, (47+(li-1)*9+(i-1)*60)*scale)
						end
					end
					
					love.graphics.setColor(255, 255, 255)
					
					--highlight
					if i == onlinemappackselection then
						love.graphics.draw(mappackhighlight, 25*scale, (20+(i-1)*60)*scale, 0, scale, scale)
					end
				end
			
				love.graphics.translate(0, round(onlinemappackscrollsmooth*60*scale))
			
				local i = onlinemappackscrollsmooth / (#onlineassetlist-3.233)
			
				love.graphics.draw(mappackscrollbar, 227*scale, (20+i*160)*scale, 0, scale, scale)
			end
			
			love.graphics.translate(- round(mappackhorscrollrange*scale - mappackhorscrollsmooth*scale*mappackhorscrollrange), 0)
			
			-------------------
			--DAILY CHALLENGE--
			-------------------
			
			love.graphics.translate(round(((mappackhorscrollrange*scale)*2) - mappackhorscrollsmooth*scale*mappackhorscrollrange), 0)
			
			love.graphics.setScissor(21*scale, 16*scale, 218*scale, 200*scale)
			if mappackhorscrollsmooth > 1 and mappackhorscrollsmooth < 3 then
				love.graphics.setColor(255, 255, 255)
				properprint("daily challenge:" .. datet[1] .. "/" .. datet[2] .. "/" .. datet[3], 25*scale, 21*scale)
				properprint("no. " .. DCcompleted, 25*scale, 33*scale)
				love.graphics.setColor(30, 30, 30, 150)
				properprint("v." .. DCversion, (21+mappackhorscrollrange-5-(#("v." .. DCversion)*8))*scale, 33*scale)
				love.graphics.setColor(0, 0, 0, 150)
				love.graphics.rectangle("fill", 24*scale, 45*scale, 212*scale, 80*scale)
				love.graphics.rectangle("fill", 24*scale, 129*scale, (utf8.len(TEXT["highscores"])*8+8)*scale, 13*scale)
				love.graphics.rectangle("fill", 24*scale, 145*scale, 213*scale, 42*scale)
				love.graphics.setColor(160, 160, 160)
				for i = 1, #DCchalobjectivet do
					properprint(DCchalobjectivet[i], 106*scale, (75+((i-1)*10))*scale)
				end
				local high1, high2, high3 = DChigh[1], DChigh[2], DChigh[3]
				if tonumber(high1) then
					high1 = string.format("%.2f", tonumber(high1) or 0)
				end
				if tonumber(high2) then
					high2 = string.format("%.2f", tonumber(high2) or 0)
				end
				if tonumber(high3) then
					high3 = string.format("%.2f", tonumber(high3) or 0)
				end
				properprint("1. " .. high1 .. "\n2. " .. high2 .. "\n3. " .. high3, 30*scale, 152*scale)
				love.graphics.setColor(255, 255, 255)
				properprintF(TEXT["today's\nchallenge"], 106*scale, 48*scale)
				properprintF(TEXT["highscores"], 28*scale, 132*scale)
				if blinktimer < 0.5 then
					properprintF(TEXT["press start to play!"], (130-utf8.len(TEXT["press start to play!"])*4)*scale, 199*scale)
				end
				love.graphics.setColor(calendarcolors[tonumber(datet[1]) or 1])
				love.graphics.rectangle("fill", 26*scale, 47*scale, 76*scale, 76*scale)
				love.graphics.setColor(255, 255, 255)
				love.graphics.draw(calendarimg, 26*scale, 47*scale, 0, scale, scale)
			end
			love.graphics.setScissor()
			
			love.graphics.translate(- (round(((mappackhorscrollrange*scale)*2) - mappackhorscrollsmooth*scale*mappackhorscrollrange)), 0)
		end
		
		love.graphics.setScissor()
		
		--draw tabs
		local colors = {}
		for i = 0, 2 do
			if mappackhorscroll == i then
				colors[i] = {{255, 255, 255}, {0, 0, 0}}
			else
				colors[i] = {{0, 0, 0}, {255, 255, 255}}
			end
		end
		--local
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", 22*scale, 3*scale, 44*scale, 13*scale)
		love.graphics.setColor(colors[0][1])
		love.graphics.rectangle("fill", 23*scale, 4*scale, 42*scale, 11*scale)
		love.graphics.setColor(colors[0][2])
		properprint("local", 23*scale, 6*scale)
		--dlc
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", 70*scale, 3*scale, 29*scale, 13*scale)
		love.graphics.setColor(colors[1][1])
		love.graphics.rectangle("fill", 71*scale, 4*scale, 27*scale, 11*scale)
		love.graphics.setColor(colors[1][2])
		properprint("dlc", 72*scale, 6*scale)
		--daily challenge
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", 103*scale, 3*scale, 125*scale, 13*scale)
		love.graphics.setColor(colors[2][1])
		love.graphics.rectangle("fill", 104*scale, 4*scale, 123*scale, 11*scale)
		love.graphics.setColor(colors[2][2])
		properprint("daily challenge", 105*scale, 6*scale)
		
		if downloadingmappack then
			renderoverlay((onlinedlc and (onlineassetlist[onlinemappackselection].downloadable and "downloading asset" or "opening link") or "loading mappacks") .. "...", true, true)
		end
		
	elseif gamestate == "onlinemenu" then
		onlinemenu_draw()
	elseif gamestate == "lobby" then
		lobby_draw()
	elseif gamestate == "options" then
		love.graphics.setColor(0, 0, 0, 200)
		love.graphics.rectangle("fill", 21*scale, 16*scale, 218*scale, 200*scale)

		--Settings tab heads
		local tabX = 26
		local tabs = {"controls", "skins", "misc.", "cheat"}
		for i = 1, #tabs do
			local s = tabs[i]
			if optionstab == i then
				love.graphics.setColor(100, 100, 100, 100)
				love.graphics.rectangle("fill", (tabX-1)*scale, 20*scale, (utf8.len(s)*8+3)*scale, 11*scale)
			end
			if optionstab == i and optionsselection == 1 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			properprint(s, tabX*scale, 22*scale)
			tabX = tabX + utf8.len(s)*8+6
		end
		
		if optionstab == 1 then
			--CONTROLS
			if optionsselection == 2 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			properprintF(TEXT["edit player:"], 30*scale, 40*scale)
			
			if optionsselection == 4 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			local currentbindlabel = TEXT["current bind:"] or "current bind:"
			local bindlabelwidth = utf8.len(currentbindlabel) * 8
			local bindgroupwidth = bindlabelwidth + 4 + 21
			properprintF(currentbindlabel, (130 - bindgroupwidth/2)*scale, 66*scale)

			if optionsselection == 3 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			properprintF(TEXT["uses the mouse:"], 30*scale, 52*scale)
			
			love.graphics.setScissor(21*scale, 16*scale, 218*scale, 200*scale)
			local pageviews = optionscontrols_pageviews()
			for i = 1, #pageviews do
				optionscontrols_draw_page(pageviews[i].page, pageviews[i].offset)
			end
			love.graphics.setScissor()
			optionscontrols_draw(nil, false, true)

			local tooltipline1, tooltipline2
			if keybindpage == 1 then
				if skinningplayer == 1 then
					tooltipline1, tooltipline2 = "press ctrl+f6 to", "reset keybinds"
				else
					tooltipline1, tooltipline2 = "press ctrl+f6 to reset", "keybinds to player " .. (skinningplayer - 1)
				end
			else
				tooltipline1, tooltipline2 = "press ctrl+f6 to", "clear keybinds"
			end
			local tooltipwidth = math.max(utf8.len(tooltipline1), utf8.len(tooltipline2)) * 8
			local tooltipx = 130 - tooltipwidth / 2
			love.graphics.setColor(0, 0, 0, 200)
			love.graphics.rectangle("fill", (tooltipx - 3)*scale, 0, (tooltipwidth + 6)*scale, 18*scale)
			love.graphics.setColor(255, 255, 255, 255)
			properprintF(tooltipline1 .. "\n" .. tooltipline2, tooltipx*scale, 0)
				
			if keyprompt then
				love.graphics.setColor(0, 0, 0, 255)
				love.graphics.rectangle("fill", 30*scale, 100*scale, 200*scale, 60*scale)
				love.graphics.setColor(255, 255, 255, 255)
				drawrectangle(30, 100, 200, 60)
				local controlname = optionscontrols_controlnames[optionsselection-4]
				if controlname == "aimx" then
					properprintF(TEXT["move stick right"], 40*scale, 110*scale)
				elseif controlname == "aimy" then
					properprintF(TEXT["move stick down"], 40*scale, 110*scale)
				else
					properprintF(TEXT["press key for '"] .. TEXT[controlname] .. "'", 40*scale, 110*scale)
				end
				local escapetext = TEXT["press 'esc' to cancel"]
				if keypromptpage > 1 then
					escapetext = TEXT["press 'esc' to clear"] or "press 'esc' to clear"
				end
				properprintF(escapetext, 40*scale, 140*scale)
				
				if buttonerror then
					love.graphics.setColor(200, 0, 0)
					properprintF(TEXT["you can only set"], 40*scale, 120*scale)
					properprintF(TEXT["buttons for this"], 40*scale, 130*scale)
				elseif axiserror then
					love.graphics.setColor(200, 0, 0)
					properprintF(TEXT["you can only set"], 40*scale, 120*scale)
					properprintF(TEXT["axes for this"], 40*scale, 130*scale)
				end
			end
		elseif optionstab == 2 then
			--SKINS
			if optionsselection == 2 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			
			properprintF(TEXT["edit player:"] .. skinningplayer, (130-4-utf8.len(TEXT["edit player:"])*4)*scale, 32*scale)
			
			--PREVIEW MARIO IN BIG. WITH BIG LETTERS
			local v = characters.data[mariocharacter[skinningplayer]]
			if v.portalgununderhat then
				love.graphics.setColor(255, 255, 255, 255)
				love.graphics.draw(v["animations"][0], v["small"]["idle"][3], (34+46+v.smalloffsetX*2)*scale, (32+32-v.smalloffsetY*2)*scale, 0, scale*2, scale*2, v.smallquadcenterX, v.smallquadcenterY)
			end
			love.graphics.setColor(255, 255, 255, 255)
			for i = 1, #v.colorables do
				if mariocolors[skinningplayer][i] then
					love.graphics.setColor(unpack(mariocolors[skinningplayer][i]))
				end
				if mariocharacter[skinningplayer] then
					love.graphics.draw(v["animations"][i], v["small"]["idle"][3], (34+46+v.smalloffsetX*2)*scale, (32+32-v.smalloffsetY*2)*scale, 0, scale*2, scale*2, v.smallquadcenterX, v.smallquadcenterY)
				end
			end
			
			--character
			if optionsselection == 3 then
				love.graphics.setColor(0, 0, 0, 200)
				love.graphics.rectangle("fill", 240*scale, 41*scale, 95*scale, 41*scale)
				love.graphics.setColor(255, 255, 255)
				properprintF(TEXT["press m to\nopen your\ncharacters\nfolder"], 241*scale, 43*scale)

				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			
			properprintF("{", 64*scale, 56*scale)
			properprintF("}", 112*scale, 56*scale)
			properprint(characters.data[characters.list[characteri]].name, (118-#characters.data[characters.list[characteri]].name*4)*scale, 80*scale)
			
			--hat
			offsets = customplayerhatoffsets(mariocharacter[skinningplayer], "hatoffsets", "idle") or hatoffsets["idle"]
			if v.hats then
				if #mariohats[skinningplayer] > 1 or mariohats[skinningplayer][1] ~= 1 then
					local yadd = 0
					for i = 1, #mariohats[skinningplayer] do
						love.graphics.setColor(255, 255, 255)
						love.graphics.draw(hat[mariohats[skinningplayer][i]].graphic, hat[mariohats[skinningplayer][i]].quad[1], (80+v.smalloffsetX*2)*scale, (64-v.smalloffsetY*2)*scale, 0, scale*2, scale*2, v.smallquadcenterX - hat[mariohats[skinningplayer][i]].x + offsets[1], v.smallquadcenterY - hat[mariohats[skinningplayer][i]].y + offsets[2] + yadd)
						yadd = yadd + hat[mariohats[skinningplayer][i]].height
					end
				elseif #mariohats[skinningplayer] == 1 then
					love.graphics.setColor(mariocolors[skinningplayer][1])
					love.graphics.draw(hat[mariohats[skinningplayer][1]].graphic, hat[mariohats[skinningplayer][1]].quad[1], (80+v.smalloffsetX*2)*scale, (64-v.smalloffsetY*2)*scale, 0, scale*2, scale*2, v.smallquadcenterX - hat[mariohats[skinningplayer][1]].x + offsets[1], v.smallquadcenterY - hat[mariohats[skinningplayer][1]].y + offsets[2])
				end
			end
			
			if not v.portalgununderhat then
				love.graphics.setColor(255, 255, 255, 255)
				love.graphics.draw(v["animations"][0], v["small"]["idle"][3], (34+46+v.smalloffsetX*2)*scale, (32+32-v.smalloffsetY*2)*scale, 0, scale*2, scale*2, v.smallquadcenterX, v.smallquadcenterY)
			end
			
			--PREVIEW PORTALS WITH FALLING MARIO BECAUSE I CAN AND IT LOOKS RAD
			love.graphics.setScissor(142*scale, 42*scale, 32*scale, 32*scale)
			
			for j = 1, #v.colorables do
				if v.portalgununderhat then
					love.graphics.setColor(255, 255, 255, 255)
					love.graphics.draw(v["animations"][0], v["small"]["jump"][3][1], (152+v.smalloffsetX)*scale, (2+((j-1)*32)+infmarioY-v.smalloffsetY)*scale, infmarioR, scale, scale, v.smallquadcenterX, v.smallquadcenterY)
				end
				for i = 1, #v.colorables do
					love.graphics.setColor(mariocolors[skinningplayer][i])
					love.graphics.draw(v["animations"][i], v["small"]["jump"][3][1], (152+v.smalloffsetX)*scale, (2+((j-1)*32)+infmarioY-v.smalloffsetY)*scale, infmarioR, scale, scale, v.smallquadcenterX, v.smallquadcenterY)
				end
				if not v.portalgununderhat then
					love.graphics.setColor(255, 255, 255, 255)
					love.graphics.draw(v["animations"][0], v["small"]["jump"][3][1], (152+v.smalloffsetX)*scale, (2+((j-1)*32)+infmarioY-v.smalloffsetY)*scale, infmarioR, scale, scale, v.smallquadcenterX, v.smallquadcenterY)
				end
			end
			
			local portalframe = portalanimation
			
			love.graphics.setColor(255, 255, 255, 80 - math.abs(portalframe-3)*10)
			love.graphics.draw(portalglowimg, 174*scale, 59*scale, math.pi, scale, scale)
			love.graphics.draw(portalglowimg, 142*scale, 57*scale, 0, scale, scale)
			
			love.graphics.setColor(portalcolor[skinningplayer][1])
			love.graphics.draw(portalimg, portalquad[portalframe], 174*scale, 46*scale, math.pi, scale, scale)
			love.graphics.setColor(portalcolor[skinningplayer][2])
			love.graphics.draw(portalimg, portalquad[portalframe], 142*scale, 70*scale, 0, scale, scale)
			
			love.graphics.setScissor()
			
			--HAT
			if optionsselection == 4 then
				if mariocharacter[skinningplayer] and not characters.data[mariocharacter[skinningplayer]].hats then
					love.graphics.setColor(150, 150, 150, 255)
				else
					love.graphics.setColor(255, 255, 255, 255)
				end
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			if mariocharacter[skinningplayer] and not characters.data[mariocharacter[skinningplayer]].hats then
				properprintF(TEXT["hat: "] .. TEXT["disabled"], (120-utf8.len(TEXT["hat: "] .. TEXT["disabled"])*4)*scale, 90*scale)
			elseif mariohats[skinningplayer][1] == nil then
				properprintF(TEXT["hat: "] .. TEXT["none"], (120-utf8.len(TEXT["hat: "] .. TEXT["none"])*4)*scale, 90*scale)
			else
				properprintF(TEXT["hat: "] .. mariohats[skinningplayer][1], (120-utf8.len(TEXT["hat: "] .. mariohats[skinningplayer][1])*4)*scale, 90*scale)
			end

			if v.colorables then
				if optionsselection == 5 then
					love.graphics.setColor(255, 255, 255, 255)
				else
					love.graphics.setColor(100, 100, 100, 255)
				end
				
				--NEW SKIN CUSTOMIZATION
				local v = characters.data[mariocharacter[skinningplayer]]
				properprint("{ " .. v.colorables[colorsetedit] .. " }", 120*scale-string.len("{ " .. v.colorables[colorsetedit] .. " }")*4*scale, 105*scale)
				
				if optionsselection > 5 and optionsselection < 9 then
					love.graphics.setColor(255, 255, 255, 255)
					love.graphics.rectangle("fill", 39*scale, 114*scale + (optionsselection-6)*10*scale, 142*scale, 10*scale)
				end
			
				love.graphics.setColor(100, 0, 0)
				properprint("r", 40*scale, (116)*scale)
				love.graphics.setColor(255, 0, 0)
				properprint("r", 39*scale, (115)*scale)
				
				love.graphics.setColor(0, 100, 0)
				properprint("g", 40*scale, (126)*scale)
				love.graphics.setColor(0, 255, 0)
				properprint("g", 39*scale, (125)*scale)
				
				love.graphics.setColor(0, 0, 100)
				properprint("b", 40*scale, (136)*scale)
				love.graphics.setColor(0, 0, 255)
				properprint("b", 39*scale, (135)*scale)
				
				love.graphics.setColor(100, 0, 0)
				love.graphics.rectangle("fill", 51*scale, (116)*scale, math.floor(129*scale * (mariocolors[skinningplayer][colorsetedit][1]/255)), 7*scale)
				love.graphics.setColor(255, 0, 0)
				love.graphics.rectangle("fill", 50*scale, (115)*scale, math.floor(129*scale * (mariocolors[skinningplayer][colorsetedit][1]/255)), 7*scale)
				
				love.graphics.setColor(100, 100, 100)
				local s = math.floor(mariocolors[skinningplayer][colorsetedit][1])
				properprint(s, 200*scale-string.len(s)*4*scale, 116*scale)
				
				love.graphics.setColor(0, 100, 0)
				love.graphics.rectangle("fill", 51*scale, (126)*scale, math.floor(129*scale * (mariocolors[skinningplayer][colorsetedit][2]/255)), 7*scale)
				love.graphics.setColor(0, 255, 0)
				love.graphics.rectangle("fill", 50*scale, (125)*scale, math.floor(129*scale * (mariocolors[skinningplayer][colorsetedit][2]/255)), 7*scale)
				
				love.graphics.setColor(100, 100, 100)
				s = math.floor(mariocolors[skinningplayer][colorsetedit][2])
				properprintF(s, 200*scale-string.len(s)*4*scale, 126*scale)
				
				love.graphics.setColor(0, 0, 100)
				love.graphics.rectangle("fill", 51*scale, (136)*scale, math.floor(129*scale * (mariocolors[skinningplayer][colorsetedit][3]/255)), 7*scale)
				love.graphics.setColor(0, 0, 255)
				love.graphics.rectangle("fill", 50*scale, (135)*scale, math.floor(129*scale * (mariocolors[skinningplayer][colorsetedit][3]/255)), 7*scale)
				
				love.graphics.setColor(100, 100, 100)
				s = math.floor(mariocolors[skinningplayer][colorsetedit][3])
				properprintF(s, 200*scale-string.len(s)*4*scale, 136*scale)
			end
			
			--Portalhues
			--hue
			local alpha = 100
			
			if characters.data[mariocharacter[skinningplayer]].colorables then
				if optionsselection == 9 then
					alpha = 255
				end
			else
				if optionsselection == 5 then
					alpha = 255
				end
			end
			
			love.graphics.setColor(255, 255, 255, alpha)
			
			properprintF(TEXT["coop portal 1 color:"], 31*scale, 150*scale)
			
			love.graphics.draw(huebarimg, 32*scale, 170*scale, 0, scale, scale)
			
			--marker
			love.graphics.setColor(portalcolor[skinningplayer][1])
			love.graphics.rectangle("fill", math.floor(29 + (portalhues[skinningplayer][1])*178)*scale, 161*scale, 7*scale, 6*scale)
			love.graphics.setColor(alpha, alpha, alpha)
			love.graphics.draw(huebarmarkerimg, math.floor(28 + (portalhues[skinningplayer][1])*178)*scale, 160*scale, 0, scale, scale)
			
			alpha = 100
			if characters.data[mariocharacter[skinningplayer]].colorables then
				if optionsselection == 10 then
					alpha = 255
				end
			else
				if optionsselection == 6 then
					alpha = 255
				end
			end
			
			love.graphics.setColor(255, 255, 255, alpha)
			
			properprintF(TEXT["coop portal 2 color:"], 31*scale, 180*scale)
			
			love.graphics.draw(huebarimg, 32*scale, 200*scale, 0, scale, scale)
			
			--marker
			love.graphics.setColor(portalcolor[skinningplayer][2])
			love.graphics.rectangle("fill", math.floor(29 + (portalhues[skinningplayer][2])*178)*scale, 191*scale, 7*scale, 6*scale)
			love.graphics.setColor(alpha, alpha, alpha)
			love.graphics.draw(huebarmarkerimg, math.floor(28 + (portalhues[skinningplayer][2])*178)*scale, 190*scale, 0, scale, scale)
		elseif optionstab == 3 then
			if optionsselection == 2 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			properprintF(TEXT["scale:"], 30*scale, 40*scale)

			if optionsselection == 3 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			properprintF(TEXT["letterbox:"], 30*scale, 52*scale)
			
			if optionsselection == 4 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			
			properprintF(TEXT["shader1:"], 30*scale, 65*scale)
			if shaderssupported == false then
				properprintF(TEXT["unsupported"], (180-utf8.len("unsupported")*8)*scale, 65*scale)
			end
			
			if optionsselection == 5 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			properprintF(TEXT["shader2:"], 30*scale, 78*scale)
			if shaderssupported == false then
				properprintF(TEXT["unsupported"], (180-utf8.len("unsupported")*8)*scale, 78*scale)
			end
			
			love.graphics.setColor(100, 100, 100, 255)
			properprintF(TEXT["shaders will really\nreduce performance!"], 30*scale, 89*scale)
			
			if optionsselection == 6 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			properprintF(TEXT["volume:"], 30*scale, 110*scale)
			
			if optionsselection == 11 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			
			properprintF(TEXT["vsync:"], 30*scale, 178*scale)
			
			if optionsselection == 12 then
				love.graphics.setColor(255, 255, 255, 255)
			else
				love.graphics.setColor(100, 100, 100, 255)
			end
			
			properprintF(TEXT["mappack folder:"], 30*scale, 191*scale)
			
			--love.graphics.setColor(100, 100, 100, 255)
			--properprintF(TEXT["lock mouse with f12"], 30*scale, 195*scale)
			
			love.graphics.setColor(255, 255, 255, 255)
			properprintF("alesan99's entities", 30*scale, 211*scale)
			local version = "Version " .. VERSIONSTRING
			properprintF(version, (234-(#(version)*8))*scale, 220*scale)
			
			--widgets (scale, letterbox, shaders, language, nitpicks, resets, vsync, mappack folder)
			optionsmisc_draw()
		elseif optionstab == 4 then
			love.graphics.setColor(255, 255, 255, 255)

			if not gamefinished then
				properprintF(TEXT["unlock this by completing"], 30*scale, 40*scale)
				properprintF(TEXT["the original levels pack!"], 30*scale, 50*scale)
			else
				properprintF(TEXT["have fun with these!"], 30*scale, 45*scale)
			end

			local labels = {
				"mode:",
				"knockback:",
				"bullettime:",
				"huge mario:",
				"goomba attack:",
				"sonic rainboom:",
				"playercollision:",
				"infinite time:",
				"infinite lives:",
				"dark mode:"
			}

			for i, label in ipairs(labels) do
				if optionsselection == i + 1 then
					love.graphics.setColor(255, 255, 255, 255)
				else
					love.graphics.setColor(100, 100, 100, 255)
				end

				properprintF(TEXT[label] or label, 30*scale, (65 + (i - 1)*14)*scale)
			end

			optionscheats_draw()
		end
	end
	love.graphics.translate(0, yoffset*scale)
	
	if languagemenuopen then
		languagemenu_draw()
	end
end

function loadbackground(background)
	loadanimatedtiles()
	enemies_load()
	loadcustomsprites()
	loadcustomtext()
	loadcustomsounds()
	loadcustommusic()
	loadcustombackgrounds()
	getmappacklevels()
	titleframe = 1
	titletimer = 0

	--dropshadow
	if mappackselection and mappackdropshadow then
		local sel = mappackselection
		for i = 1, #mappacklist do if mappacklist[i] == mappack then sel = i break end end
		dropshadow = mappackdropshadow[sel]
	end
	mappackversion = nil

	--BLOCKTOGGLE STUFF
	solidblockperma = {false, false, false, false}
	collectables = {} --[marioworld-mariolevel-mariosublevel][x-y]
	collectableslist = {{},{},{},{},{},{},{},{},{},{}}
	collectablescount = {0,0,0,0,0,0,0,0,0,0}
	animationnumbers = {}
	
	if not love.filesystem.getInfo(mappackfolder .. "/" .. mappack .. "/" .. background) then
	
		map = {}
		mapwidth = width
		originalmapwidth = mapwidth
		mapheight = 15
		for x = 1, width do
			map[x] = {}
			for y = 1, 13 do
				map[x][y] = {1}
			end
		
			for y = 14, mapheight do
				map[x][y] = {2}
			end
		end
		startx = 3
		starty = 13
		custombackground = false
		backgroundi = 1
		love.graphics.setBackgroundColor(backgroundcolor[backgroundi])
		portalgun = true
		portalguni = 1
	else
		local s = love.filesystem.read( mappackfolder .. "/" .. mappack .. "/" .. background )
		local s2 = s:split(";")
		
		--remove custom sprites
		for i = smbtilecount+portaltilecount+1, #tilequads do
			tilequads[i] = nil
		end
		
		for i = smbtilecount+portaltilecount+1, #rgblist do
			rgblist[i] = nil
		end
		
		--add custom tiles
		if love.filesystem.getInfo(mappackfolder .. "/" .. mappack .. "/tiles.png") then
			loadtiles("custom")
			customtiles = true
		else
			customtiles = false
			customtilecount = 0
		end
		
		--MAP ITSELF
		local t = s2[1]:split(",")
		
		mapheight = 15
		if s2[2] and s2[2]:sub(1,7) == "height=" then
			mapheight = tonumber(s2[2]:sub(8,-1)) or 15
		elseif love.filesystem.getInfo(mappackfolder .. "/" .. mappack .. "/heights/1-1_0.txt") then
			local s11 = love.filesystem.read(mappackfolder .. "/" .. mappack .. "/heights/" .. marioworld .. "-" .. mariolevel .. "_" .. mariosublevel .. ".txt")
			mapheight = tonumber(s11)
		end
		
		if math.fmod(#t, mapheight) ~= 0 then
			--create blank map
			startx = 3
			starty = 13
			mapwidth = width
			originalmapwidth = mapwidth
			mapheight = 15
			map = {}
			bmap_on = false --enabled?
			for x = 1, width do
				map[x] = {}
				for y = 1, mapheight do
					if y > 13 then
						map[x][y] = {2}
					else
						map[x][y] = {1}
					end
				end
			end
			if s2[1]:find("¤") then
				notice.new("Incompatible mappack!\nMade for Mari0 SE Beta 9", notice.red, 8)
			elseif s2[1]:find("*") then
				notice.new("Incompatible mappack!\nMade for Mari0 SE Beta 8", notice.red, 8)
			else
				notice.new("Incompatible mappack!", notice.red, 4)
			end

			print("Incorrect number of entries: " .. #t)
			return false
		end

		mapwidth = #t/mapheight
		originalmapwidth = mapwidth
		startx = 3
		starty = 13
		
		map = {} --foreground map
		bmap_on = false
		local r --map[x][y]
		local nr --map[x][y][1]
		
		for y = 1, mapheight do
			for x = 1, mapwidth do
				if y == 1 then
					map[x] = {}
				end
				
				map[x][y] = t[(y-1)*(#t/mapheight)+x]:split("-")
				
				r = map[x][y]
				
				if #r > 1 then
					if tonumber(r[2]) and entityquads[tonumber(r[2])] and entityquads[tonumber(r[2])].t == "spawn" then
						startx = x
						starty = y
						if r[3] and r[3] == "true" then
							startx = startx - 0.5
						end
					end
				end

				nr = tonumber(r[1])
				if not nr then
					--background tile
					if not bmap_on then
						bmap_on = true
					end
					local tiles = r[1]:split("~")
					r[1] = tonumber(tiles[1])
					map[x][y]["back"] = tonumber(tiles[2])
				elseif (nr > smbtilecount+portaltilecount+customtilecount and nr <= 90000) or nr > 90000+animatedtilecount then
					--tile doesn't exist
					r[1] = 1
				end
			end
		end
		
		--get background color and portal gun
		custombackground = false
		customforeground = false
		portalgun = true
		portalguni = 1
		nofunallowed = nil
		
		for i = 2, #s2 do
			s3 = s2[i]:split("=")
			if s3[1] == "background" then
				if tonumber(s3[2]) ~= nil then
					local backgroundi = tonumber(s3[2])
					love.graphics.setBackgroundColor(backgroundcolor[backgroundi])
				else
					local s4 = s3[2]:split(",")
					local backgroundrgbon = true
					local backgroundrgb = {tonumber(s4[1]), tonumber(s4[2]), tonumber(s4[3])}
					love.graphics.setBackgroundColor(unpack(backgroundrgb))
				end
			elseif s3[1] == "spriteset" then
				spriteset = tonumber(s3[2])
			elseif s3[1] == "custombackground" or s3[1] == "portalbackground" then
				custombackground = (s3[2] or true)
			elseif s3[1] == "customforeground" then
				customforeground = (s3[2] or true)
			elseif s3[1] == "noportalgun" then
				portalgun = false
				portalguni = 2
			elseif s3[1] == "portalguni" then
				portalguni = tonumber(s3[2])
				portalgun = portalguni ~= 2
			elseif s3[1] == "nofunallowed" then
				nofunallowed = true
			elseif s3[1] == "vs" then
				local vs = tonumber(s3[2])
				mappackversion = vs
				if vs and vs > VERSION then
					if math.abs(vs-VERSION) < 0.1 then
						notice.new("This map was made for a\nnew patch of mari0 ae\ndownload the new version", nil, 4.5)
					else
						notice.new("This map was made for a\nnewer version of mari0 ae\ndownload the new version!", notice.red, 8)
					end
				end
			end
		end
		if custombackground then
			loadcustombackground(custombackground)
		end
		if customforeground then
			loadcustomforeground(customforeground)
		end
	end
end

function updatescroll()
	--check if current focus is completely on screen
	if inrange(mappackselection, 1+mappackscroll, 3+mappackscroll, true) == false then
		if mappackselection < 1+mappackscroll then --above window
			mappackscroll = mappackselection-1
		else
			mappackscroll = mappackselection-3.233
		end
	end
end

function onlineupdatescroll()
	--check if current focus is completely onscreen
	if inrange(onlinemappackselection, 1+onlinemappackscroll, 3+onlinemappackscroll, true) == false then
		if onlinemappackselection < 1+onlinemappackscroll then --above window
			onlinemappackscroll = onlinemappackselection-1
		else
			onlinemappackscroll = onlinemappackselection-3.233
		end
	end
end

function mappacks()
	opendlcbutton.active = false
	openmappacksbutton.active = false
	mappacksearchbar.active = false
	if mappackhorscroll == 0 then
		loadmappacks()
		openmappacksbutton.active = true
		mappacksearchbar.active = true
	elseif mappackhorscroll == 1 then
		if (not onlineassetlist) or onlinemappacklisterror then
			loadonlinemappacks()
		end
		mappacktype = "online"
		opendlcbutton.active = true
	elseif mappackhorscroll == 2 then
		loaddailychallenge()
	end
end

function loadmappacks()
	mappacktype = "local"
	mappacklist = love.filesystem.getDirectoryItems( mappackfolder )

	if onlinedlc then
		mountalldlc()
	end
	
	local delete = {}
	for i = 1, #mappacklist do
		if ((not onlinedlc) and (love.filesystem.getInfo("alesans_entities/onlinemappacks/" .. mappacklist[i] .. ".zip")
		or love.filesystem.getInfo(mappackfolder .. "/" .. mappacklist[i] .. "/version.txt")))
		or not love.filesystem.getInfo(mappackfolder .. "/" .. mappacklist[i] .. "/settings.txt") then
			table.insert(delete, i)
		end
	end
	
	table.sort(delete, function(a,b) return a>b end)
	
	for i, v in pairs(delete) do
		table.remove(mappacklist, v) --remove
	end
	
	mappackicon = {}
	
	--get info
	mappackname = {}
	mappackauthor = {}
	mappackdescription = {}
	mappackbackground = {}
	mappackdropshadow = {}
	
	table.insert(mappacklist, "custom_mappack")
	mappackname[#mappacklist] = TEXT["{new mappack}"]
	mappackauthor[#mappacklist] = "you"
	mappackdescription[#mappacklist] = TEXT["new mappack description"]
	mappackdropshadow[#mappacklist] = false
	
	--get the current cursorposition
	for i = 1, #mappacklist do
		if mappacklist[i] == mappack then
			mappackselection = i
		end
	end
	
	mappack = mappacklist[mappackselection]
	
	--load background
	if mappackbackground[mappackselection] then
		--loadbackground(mappackbackground[mappackselection] .. ".txt")
	else
		--loadbackground("1-1.txt")
	end
	
	if mappacklistthread then
		mappacklistthreadchannelin:clear()
		--mappacklistthreadchannelin:push({"stop"})
	end
	mappacklistthreadn = 1
	mappacklistthreadchannelin = love.thread.getChannel("mappackin")
	mappacklistthreadchannelout = love.thread.getChannel("mappackout")
	mappacklistthread = love.thread.newThread("mappacklistthread.lua")
	mappacklistthreadchannelin:push({mappackfolder .. "/" .. mappacklist[mappacklistthreadn], love.filesystem.getIdentity()})
	mappacklistthread:start()
	
	mappackscroll = 0
	updatescroll()
	mappackscrollsmooth = mappackscroll
end

function loadonlinemappacks()
	mappacktype = "online"
	if onlinedlc then
		onlinemappacklisterror = nil
		local assetdata = downloadassetdata()
		if not (assetdata and assetdata.assets) then
			onlinemappackscroll = 0
			onlineupdatescroll()
			onlinemappackscrollsmooth = onlinemappackscroll
			local asset = {
				type = "error",
				name = "error",
				author = "error",
				description = "error",
				download = {
					url = "error",
					filename = "error",
				},
			}
			onlineassetlist = {asset}
			onlinemappacklisterror = true
			return false
		end
		
		-- prepare icon thread
		onlinemappackiconchannel = love.thread.getChannel("image_input")
		onlinemappackiconchannel2 = love.thread.getChannel("image_output")
		onlinemappackiconthread = love.thread.newThread("onlineimage.lua")
		onlinemappackiconthread:start()

		-- get asset info
		onlineassetlist = {}
		local assets = assetdata.assets
		
		for i = 1, #assets do
			local raw_asset = assets[i]
			if raw_asset.game_version and hasvalue(raw_asset.game_version.derivative, "AE") then
				local asset = {
					type = raw_asset.type,
					downloadable = raw_asset.download and (raw_asset.type == "mappack" or raw_asset.type == "character"),
					name = raw_asset.name or raw_asset.long_name,
					author = raw_asset.author,
					description = raw_asset.description or raw_asset.long_description,
					background = raw_asset.background,
					download = raw_asset.download or {
						url = raw_asset.homepage,
					},
				}
				
				if raw_asset.icon then
					asset.icon_url = raw_asset.icon
					onlinemappackiconchannel:push(asset)
				end

				table.insert(onlineassetlist, asset)
			end
		end
		
		onlinemappackiconchannel:push("stop")
		onlinemappackscroll = 0
		onlineupdatescroll()
		onlinemappackscrollsmooth = onlinemappackscroll
		return true
	else
		--"download" mappacks
		downloadingmappack = true
		love.draw()
		menu_draw()
		love.graphics.present()

		--copy included zip dlcs to save folder (because of course you can't mount from source directory :/)
		local zips = love.filesystem.getDirectoryItems("alesans_entities/dlc_mappacks")
		if #zips > 0 then
			for j, w in pairs(zips) do
				if not love.filesystem.getInfo("alesans_entities/onlinemappacks/" .. w) then
					local filedata = love.filesystem.newFileData("alesans_entities/dlc_mappacks/" .. w)
					love.filesystem.write("alesans_entities/onlinemappacks/" .. w, filedata)
					if j == 1 and not love.filesystem.getInfo("alesans_entities/onlinemappacks/" .. w) then
						break
					end
				end
			end
		end

		--mount dlc zip files
		mountalldlc()

		local mappacks = love.filesystem.getDirectoryItems( mappackfolder )
		
		local delete = {}
		for i = 1, #mappacks do
			if (not (love.filesystem.getInfo("alesans_entities/onlinemappacks/" .. mappacks[i] .. ".zip") or love.filesystem.getInfo(mappackfolder .. "/" .. mappacks[i] .. "/version.txt"))) or not love.filesystem.getInfo( mappackfolder .. "/" .. mappacks[i] .. "/settings.txt") then
				table.insert(delete, i)
			end
		end
		
		table.sort(delete, function(a,b) return a>b end)
		
		for i, v in pairs(delete) do
			table.remove(mappacks, v) --remove
		end

		downloadingmappack = false
		
		--get info
		onlineassetlist = {}
		
		for i = 1, #mappacks do
			local asset = {}
			onlineassetlist[i] = asset

			if love.filesystem.getInfo( mappackfolder .. "/" .. mappacks[i] .. "/icon.png" ) then
				asset.icon = love.graphics.newImage(mappackfolder .. "/" .. mappacks[i] .. "/icon.png")
			end

			if love.filesystem.getInfo( mappackfolder .. "/" .. mappacks[i] .. "/settings.txt" ) then
				local s = love.filesystem.read( mappackfolder .. "/" .. mappacks[i] .. "/settings.txt" )
				local s1 = s:split("\n")
				for j = 1, #s1 do
					local s2 = s1[j]:split("=")
					if s2[1] == "name" or s2[1] == "author" or s2[1] == "description" or s2[1] == "background" then
						asset[s2[1]] = s2[2]
					end
				end
			else
				asset.name = mappacks[i]
			end
		end
		
		--[[get the current cursorposition
		for i = 1, #mappacks do
			if mappacks[i] == mappack then
				onlinemappackselection = i
			end
		end
		
		if #mappacks >= 1 then
			mappack = mappacks[onlinemappackselection]
		end
		
		--load background
		if onlinemappackbackground[onlinemappackselection] then
			loadbackground(onlinemappackbackground[onlinemappackselection] .. ".txt")
		else
			loadbackground("1-1.txt")
		end]]
		
		onlinemappackscroll = 0
		onlineupdatescroll()
		onlinemappackscrollsmooth = onlinemappackscroll
	end
end

function loaddailychallenge()
	mappacktype = "daily_challenge"
	return true
end

function menu_keypressed(key, unicode)
	if languagemenuopen then
		if languagemenu_keypressed(key, unicode) then
			languagemenuopen = false
		end
		return
	end
	if gamestate == "menu" then
		if newgamewarning then
			if (key == "left" or key == "a") then
				newgamewarningcursor = 1
			elseif (key == "right" or key == "d") then
				newgamewarningcursor = 2
			elseif (key == "return" or key == "enter" or key == "kpenter" or key == " ") then
				if (newgamewarningcursor == 1) then
					setmenupopupvisible("newgamewarning", false)
					selectworld()
				else
					setmenupopupvisible("newgamewarning", false)
				end
			elseif key == "escape" then
				setmenupopupvisible("newgamewarning", false)
			end
			return
		elseif selectworldopen then
			if (key == "right" or key == "d") then
				local target = selectworldcursor+1
				while target <= #mappacklevels and not reachedworlds[mappack][target] do
					target = target + 1
				end
				if target <= #mappacklevels then
					setselectworldcursor(target)
				end
			elseif (key == "left" or key == "a") then
				local target = selectworldcursor-1
				while target > 0 and not reachedworlds[mappack][target] do
					target = target - 1
				end
				if target > 0 then
					setselectworldcursor(target)
				end
			elseif (key == "return" or key == "enter" or key == "kpenter" or key == " ") then
				renderoverlay("loading game...")
				setmenupopupvisible("selectworld", false)
				game_load(selectworldcursor, true)
			elseif key == "escape" then
				setmenupopupvisible("selectworld", false)
			end
			return
		end
		if (key == "up" or key == "w") then
			if continueavailable then
				if selection > 0 then
					selection = selection - 1
				end
			else
				if selection > 1 then
					selection = selection - 1
				end
			end
		elseif (key == "down" or key == "s") then
			if selection < 4 then
				selection = selection + 1
			end
		elseif (key == "return" or key == "enter" or key == "kpenter" or key == " ") then
			if selection == 0 then
				renderoverlay("loading save data...")
				game_load(true)
			elseif selection == 1 then
				newgame()
			elseif selection == 2 then
				if nofunallowed then
					if love.keyboard.isDown("lctrl") and love.keyboard.isDown("lshift") then
						renderoverlay("loading editor...")
					else
						notice.new("Creator disabled the editor.", nil, 2)
						return false
					end
				else
					renderoverlay("loading editor...")
				end
				if not CurrentLanguage then
					languagemenuopen = true
					languagemenu_open()
					return false
				end
				editormode = true
				players = 1
				playertype = "portal"
				playertypei = 1
				disablecheats()
				loadeditormetadata()
				game_load()
			elseif selection == 3 then
				gamestate = "mappackmenu"
				mappacks()
			elseif selection == 4 then
				if not CurrentLanguage then
					languagemenuopen = true
					languagemenu_open()
					return false
				end
				gamestate = "options"
			end
		elseif key == "escape" then
			love.event.quit()
		elseif (key == "left" or key == "a") then
			if players > 1 then
				players = players - 1
			elseif players == 1 then
				onlinemenu_load()
			end
		elseif (key == "right" or key == "d") then
			players = players + 1
			if players > 4 then
				players = 4
			end
		end
	elseif gamestate == "mappackmenu" then
		if mappacksearchbar.inputting then
			if (key == "up" or key == "down") then
				mappacksearchbar.inputting = false
			else
				mappacksearchbar:keypress(key)
				return
			end
		elseif (key == "up" or key == "w") then
			if mappacktype == "local" then
				if mappackselection > 1 then
					mappackselection = mappackselection - 1
					updatescroll()
				end
			elseif mappacktype == "online" then
				if onlinemappackselection > 1 then
					onlinemappackselection = onlinemappackselection - 1
					
					onlineupdatescroll()
				end
			end
		elseif (key == "down" or key == "s") then
			if mappacktype == "local" then
				if mappackselection < #mappacklist then
					mappackselection = mappackselection + 1
					
					updatescroll()
				end
			elseif mappacktype == "online" then
				if onlinemappackselection < #onlineassetlist then
					onlinemappackselection = onlinemappackselection + 1
					
					onlineupdatescroll()
				end
			end
		elseif mappacktype == "online" and (key == "return" or key == "enter" or key == "kenter" or key == " ") then
			if onlinedlc then
				local i = onlinemappackselection
				local asset = onlineassetlist[i]
				local onlinemappackerror = false
				--download mappack
				downloadingmappack = true
				love.graphics.clear(love.graphics.getBackgroundColor())
				if resizable then
					love.graphics.scale(winwidth/(width*16*scale), winheight/(224*scale))
				end
				menu_draw()
				love.graphics.present()
				
				if asset.download then
					if not asset.downloadable then
						--link
						if love.system.openURL(asset.download.url) then
							notice.new(TEXT["Opened Download Link"], nil, 2)
						else
							love.system.setClipboardText(asset.download.url)
							notice.new(TEXT["Couldn't Open Link\nLink copied to clipboard"], notice.red, 3)
						end
					else
						onlinemappackerror = not downloadasset(asset)
						if not onlinemappackerror then
							mountasset(asset)
							if asset.type == "mappack" then
								loadmappacks()
							elseif asset.type == "character" then
								loadcustomplayers()
								resetcustomplayers()
							end
							mappackhorscroll = 0
							mappacktype = "local"
							downloadedmappacks[i] = true
							for mi = 1, #mappacklist do
								if mappacklist[mi]:lower() == asset.name:lower() then
									mappackselection = mi
									break
								end
							end
							updatescroll()
							onlineupdatescroll()
							notice.new(TEXT["DLC downloaded!"], nil, 2)
						else
							downloadedmappacks[i] = false
							notice.new(TEXT["Download failed"], notice.red, 2)
						end
					end
				else
					onlinemappackerror = true
					downloadedmappacks[i] = false
					notice.new(TEXT["DLC not found"], notice.red, 2)
				end
				downloadingmappack = false
			else
				--local dlc
				mappack = onlineassetlist[onlinemappackselection]
				--load background
				loadbackground((mappack.background or "1-1") .. ".txt")
				gamestate = "menu"
				saveconfig()
			end
		elseif mappacktype == "daily_challenge" and (key == "return" or key == "enter" or key == "kenter" or key == " ") then
			infinitetime = false
			warpfadeoutnow()
			game_load("dailychallenge")
		elseif (key == "return" or key == "enter" or key == "kpenter" or key == " ") then
			--stop loading mappacks
			if mappacklistthread and mappacklistthread:isRunning() then
				mappacklistthreadchannelin:push({"stop"})
			end

			renderoverlay("loading mappack...")
			mappack = mappacklist[mappackselection]
			--load background					
	
			if mappackbackground[mappackselection] then
				loadbackground(mappackbackground[mappackselection] .. ".txt")
			else
				loadbackground("1-1.txt")
			end

			gamestate = "menu"
			saveconfig()

			continueavailable = false
			if love.filesystem.getInfo(savesfolder .. "/" .. mappack .. ".suspend") then
				continueavailable = true
			end

			if mappack == "custom_mappack" then
				createmappack()
			end
		elseif key == "escape" then
			if mappacklistthread and mappacklistthread:isRunning() then
				mappacklistthreadchannelin:push({"stop"})
			end
			gamestate = "menu"
		elseif (key == "right" or key == "d") or (key == "left" or key == "a") then
			--change mappack selection tab
			if (key == "right" or key == "d") then
				mappackhorscroll = mappackhorscroll + 1
			else
				mappackhorscroll = mappackhorscroll - 1
			end
			if mappackhorscroll > 2 then
				mappackhorscroll = 0
			elseif mappackhorscroll < 0 then
				mappackhorscroll = 2
			end
			mappacks()
		elseif key == "m" then
			if not openSaveFolder( mappackfolder ) then
				savefolderfailed = true
			end
		end
	elseif gamestate == "onlinemenu" then
		if key == "escape" then
			guielements = {}
			gamestate = "menu"
		end
	elseif gamestate == "options" then
		--keys that skip love.keypressed (controller buttons) still belong to an open dropdown
		local dropdown = guielement.getopendropdown()
		if dropdown and dropdown:keypress(key) then
			return
		end

		-- Ctrl+F6: reset / clear / copy the current player's keybind page
		if optionstab == 1 and not keyprompt and key == "f6" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
			local controlset = getcontrolset(keybindpage)
			if not controlset then
				return
			end
			if not controlset[skinningplayer] then
				controlset[skinningplayer] = {}
			end

			if keybindpage == 1 then
				if skinningplayer == 1 then
					-- player 1 page 1 → factory keyboard defaults
					controlset[1]["left"] = {"a"}
					controlset[1]["right"] = {"d"}
					controlset[1]["up"] = {"w"}
					controlset[1]["down"] = {"s"}
					controlset[1]["run"] = {"lshift"}
					controlset[1]["jump"] = {" "}
					controlset[1]["reload"] = {"r"}
					controlset[1]["use"] = {"e"}
					controlset[1]["pause"] = {""}
					controlset[1]["aimx"] = {""}
					controlset[1]["aimy"] = {""}
					controlset[1]["portal1"] = {""}
					controlset[1]["portal2"] = {""}
				else
					-- player n page 1 → exact copy of player n-1's page 1
					local source = controlset[skinningplayer - 1]
					if source then
						for _, name in ipairs(controlstable) do
							controlset[skinningplayer][name] = deepcopy(source[name] or {})
						end
					end
				end
			else
				-- any other page → clear every binding for this player
				for _, name in ipairs(controlstable) do
					controlset[skinningplayer][name] = {}
				end
			end

			optionscontrols_sync()
			saveconfig()
			return
		end

		if optionstab == 1 and optionsselection >= 4 and not keyprompt
			and (key == "left" or key == "right" or key == "a" or key == "d") then
			if optionscontrols_change_page((key == "left" or key == "a") and -1 or 1) then
				return
			end
		end

		if optionsselection == 1 then
			if (key == "left" or key == "a") then
				if optionstab > 1 then
					optionstab = optionstab - 1
				end
			elseif (key == "right" or key == "d") then
				if optionstab < 4 then
					optionstab = optionstab + 1
				end
			end
		elseif optionsselection == 2 then
			if (key == "left" or key == "a") then
				if optionstab == 2 or optionstab == 1 then
					if skinningplayer > 1 then
						skinningplayer = skinningplayer - 1
						characteri = characters.data[mariocharacter[skinningplayer]].i
					end
				end
			elseif (key == "right" or key == "d") then
				if optionstab == 2 or optionstab == 1 then
					if skinningplayer < 4 then
						skinningplayer = skinningplayer + 1
						characteri = characters.data[mariocharacter[skinningplayer]].i
						if players > #controls then
							loadconfig()
						end
					end
				end
			end
		end
		
		if (key == "return" or key == "enter" or key == "kpenter" or key == " ") then
			if optionstab == 1 then
				optionscontrols_activate(optionsselection)
			elseif optionstab == 2 and optionsselection == 3 then
				if characteri ~= characters.data[mariocharacter[skinningplayer]].i then
					colorsetedit = 1
					setcustomplayer(characters.list[characteri], skinningplayer)
					saveconfig()
				end
			elseif optionstab == 3 then
				optionsmisc_activate(optionsselection)
			elseif optionstab == 4 and gamefinished then
				optionscheats_activate(optionsselection)
			end
		elseif (key == "down" or key == "s") then
			if optionstab == 1 then
				if optionsselection < optionscontrols_lastselection() then
					optionsselection = optionsselection + 1
				else
					optionsselection = 1
				end
			elseif optionstab == 2 then
				if characteri ~= characters.data[mariocharacter[skinningplayer]].i then
					colorsetedit = 1
					setcustomplayer(characters.list[characteri], skinningplayer)
				end

				local limit = 6
				if characters.data[mariocharacter[skinningplayer]].colorables then
					limit = 10
				end

				if optionsselection < limit then
					optionsselection = optionsselection + 1
				else
					optionsselection = 1
				end
			elseif optionstab == 3 then
				if optionsselection < 12 then
					optionsselection = optionsselection + 1
				else
					optionsselection = 1
				end
			elseif optionstab == 4 and gamefinished then
				if optionsselection < 11 then
					optionsselection = optionsselection + 1
				else
					optionsselection = 2
				end
			end
		elseif (key == "up" or key == "w") then
			if optionsselection > 1 then
				if characteri ~= characters.data[mariocharacter[skinningplayer]].i then
					colorsetedit = 1
					setcustomplayer(characters.list[characteri], skinningplayer)
				end

				optionsselection = optionsselection - 1
			else
				if optionstab == 1 then
					optionsselection = optionscontrols_lastselection()
				elseif optionstab == 2 then
					local limit = 6
					if characters.data[mariocharacter[skinningplayer]].colorables then
						limit = 10
					end
					optionsselection = limit
				elseif optionstab == 3 then
					optionsselection = 12
				elseif optionstab == 4 and gamefinished then
					optionsselection = 11
				end
			end
		elseif (key == "right" or key == "d") then
			if optionstab == 2 then
				if mariocharacter[skinningplayer] == nil then --idk
					setcustomplayer(mariocharacter[skinningplayer], skinningplayer, "initial")
				end
				if optionsselection == 3 then
					if #characters.list > 0 then
						characteri = characteri+1 or 1
						if characteri > #characters.list then
							characteri = 1
						end
					end
				elseif optionsselection == 4 and not (mariocharacter[skinningplayer] and not characters.data[mariocharacter[skinningplayer]].hats) then
					if mariohats[skinningplayer][1] == nil then
						mariohats[skinningplayer][1] = 1
					elseif mariohats[skinningplayer][1] < #hat then
						mariohats[skinningplayer][1] = mariohats[skinningplayer][1] + 1
					end
				elseif characters.data[mariocharacter[skinningplayer]].colorables and optionsselection == 5 then
					--next color set
					colorsetedit = colorsetedit + 1
					if colorsetedit > #characters.data[mariocharacter[skinningplayer]].colorables then
						colorsetedit = 1
					end
				end
			elseif optionstab == 3 then
				if optionsselection == 2 then
					if resizable then
					elseif scale < 5 then
						changescale(scale+1)
					end
					saveconfig()
				elseif optionsselection == 3 then
					letterboxfullscreen = not letterboxfullscreen
					saveconfig()
				elseif optionsselection == 4 then
					currentshaderi1 = currentshaderi1 + 1
					if currentshaderi1 > #shaderlist then
						currentshaderi1 = 1
					end
					if shaderlist[currentshaderi1] == "none" then
						shaders:set(1, nil)
					else
						shaders:set(1, shaderlist[currentshaderi1])
					end
					saveconfig()
					
				elseif optionsselection == 5 then
					currentshaderi2 = currentshaderi2 + 1
					if currentshaderi2 > #shaderlist then
						currentshaderi2 = 1
					end
					if shaderlist[currentshaderi2] == "none" then
						shaders:set(2, nil)
					else
						shaders:set(2, shaderlist[currentshaderi2])
					end
					saveconfig()
					
				elseif optionsselection == 6 then
					volumeslider_step(guielements["opt_volume"], 0.1)
				elseif optionsselection == 11 then
					vsync = not vsync
					changescale(scale)
					saveconfig()
				elseif optionsselection == 12 then
					if mappackfolder == "mappacks" then
						mappackfolder = "alesans_entities/mappacks"
						savesfolder = "alesans_entities/saves"
						mappack = "smb"
						loadbackground("1-1.txt")
					end
					saveconfig()
				end
			elseif optionstab == 4 then
				if optionsselection == 2 then
					playertypei = playertypei + 1
					if playertypei > #playertypelist then
						playertypei = 1
					end
					playertype = playertypelist[playertypei]
					if playertype == "minecraft" then
						portalknockback = false
						bullettime = false
						bigmario = false
						sonicrainboom = false
					elseif playertype == "gelcannon" then
						sonicrainboom = false
					elseif playertype == "classic" then
						portalknockback = false
						sonicrainboom = false
					end
				elseif optionsselection == 3 then
					portalknockback = not portalknockback
					if portalknockback then
						if playertype == "minecraft" then
							playertypei = 1
							playertype = "portal"
						end
					end
				elseif optionsselection == 4 then
					bullettime = not bullettime
					if bullettime then
						if playertype == "minecraft" then
							playertypei = 1
							playertype = "portal"
						end
					end
				elseif optionsselection == 5 then
					bigmario = not bigmario
					if bigmario then
						if playertype == "minecraft" then
							playertypei = 1
							playertype = "portal"
						end
					end
				elseif optionsselection == 6 then
					goombaattack = not goombaattack
				elseif optionsselection == 7 then
					sonicrainboom = not sonicrainboom
					playertype = "portal"
					playertypei = 1
				elseif optionsselection == 8 then
					playercollisions = not playercollisions
				elseif optionsselection == 9 then
					infinitetime = not infinitetime
				elseif optionsselection == 10 then
					infinitelives = not infinitelives
				elseif optionsselection == 11 then
					darkmode = not darkmode
				end
			end				
		elseif (key == "left" or key == "a") then
			if optionstab == 2 then
				if mariocharacter[skinningplayer] == nil then
					setcustomplayer(mariocharacter[skinningplayer], skinningplayer, "initial")
				end
				if optionsselection == 3 then
					if #characters.list > 0 then
						characteri = characteri-1 or 1
						if characteri < 1 then
							characteri = #characters.list
						end
					end
				elseif optionsselection == 4 and not (mariocharacter[skinningplayer] and not characters.data[mariocharacter[skinningplayer]].hats) then
					if mariohats[skinningplayer][1] == 1 then
						mariohats[skinningplayer] = {}
					elseif mariohats[skinningplayer][1] and mariohats[skinningplayer][1] > 1 then
						mariohats[skinningplayer][1] = mariohats[skinningplayer][1] - 1
					end
				elseif characters.data[mariocharacter[skinningplayer]].colorables and optionsselection == 5 then
					--previous color set
					colorsetedit = colorsetedit - 1
					if colorsetedit < 1 then
						colorsetedit = #characters.data[mariocharacter[skinningplayer]].colorables
					end
				end
			elseif optionstab == 3 then
				if optionsselection == 2 then
					if resizable then
						changescale(4)
					elseif scale > 1 then
						changescale(scale-1)
					end
					saveconfig()
				elseif optionsselection == 3 then
					letterboxfullscreen = not letterboxfullscreen
					saveconfig()
				elseif optionsselection == 4 then
					currentshaderi1 = currentshaderi1 - 1
					if currentshaderi1 < 1 then
						currentshaderi1 = #shaderlist
					end
					if shaderlist[currentshaderi1] == "none" then
						shaders:set(1, nil)
					else
						shaders:set(1, shaderlist[currentshaderi1])
					end
					saveconfig()

				elseif optionsselection == 5 then
					currentshaderi2 = currentshaderi2 - 1
					if currentshaderi2 < 1 then
						currentshaderi2 = #shaderlist
					end
					if shaderlist[currentshaderi2] == "none" then
						shaders:set(2, nil)
					else
						shaders:set(2, shaderlist[currentshaderi2])
					end
					saveconfig()
					
				elseif optionsselection == 6 then
					volumeslider_step(guielements["opt_volume"], -0.1)
				elseif optionsselection == 11 then
					vsync = not vsync
					changescale(scale)
					saveconfig()
				elseif optionsselection == 12 then
					if mappackfolder == "alesans_entities/mappacks" then
						mappackfolder = "mappacks"
						savesfolder = "saves"
						mappack = "smb"
						loadbackground("1-1.txt")
					end
					saveconfig()
				end
			elseif optionstab == 4 then
				if optionsselection == 2 then
					playertypei = playertypei - 1
					if playertypei < 1 then
						playertypei = #playertypelist
					end
					playertype = playertypelist[playertypei]
					if playertype == "minecraft" then
						portalknockback = false
						bullettime = false
						bigmario = false
						sonicrainboom = false
					elseif playertype == "gelcannon" then
						sonicrainboom = false
					end
				elseif optionsselection == 3 then
					portalknockback = not portalknockback
					if portalknockback then
						if playertype == "minecraft" then
							playertypei = 1
							playertype = "portal"
						end
					end
				elseif optionsselection == 4 then
					bullettime = not bullettime
					if bullettime then
						if playertype == "minecraft" then
							playertypei = 1
							playertype = "portal"
						end
					end
				elseif optionsselection == 5 then
					bigmario = not bigmario
					if bigmario then
						if playertype == "minecraft" then
							playertypei = 1
							playertype = "portal"
						end
					end
				elseif optionsselection == 6 then
					goombaattack = not goombaattack
				elseif optionsselection == 7 then
					sonicrainboom = not sonicrainboom
					playertype = "portal"
					playertypei = 1
				elseif optionsselection == 8 then
					playercollisions = not playercollisions
				elseif optionsselection == 9 then
					infinitetime = not infinitetime
				elseif optionsselection == 10 then
					infinitelives = not infinitelives
				elseif optionsselection == 11 then
					darkmode = not darkmode
				end
			end
		elseif key == "m" then
			if optionstab == 2 then
				if optionsselection == 3 then
					--open characters folder
					if android then
						notice.new("On android try a file manager\nand go to:\nAndroid > data > Love.to.mario >\nfiles > save > mari0_android", notice.red)
					end
					if not love.filesystem.getInfo("alesans_entities/characters") then
						love.filesystem.createDirectory("alesans_entities/characters")
					end
					openfile("alesans_entities/characters")
				end
			end
		elseif key == "escape" then
			if characteri ~= characters.data[mariocharacter[skinningplayer]].i then
				colorsetedit = 1
				setcustomplayer(characters.list[characteri], skinningplayer)
			end
			gamestate = "menu"
			saveconfig()
		end
	end
end

function menu_keyreleased(key, unicode)
	local colorables = characters.data[mariocharacter[skinningplayer]].colorables
	local changingColour = key == "left" or key == "right" or key == "a" or key == "d"
	local anyHold = love.keyboard.isDown("left") or love.keyboard.isDown("right") or love.keyboard.isDown("a") or love.keyboard.isDown("d")

	if gamestate == "options" and optionstab == 2 and changingColour and ((colorables and optionsselection > 5 and optionsselection < 9) or (colorables and optionsselection == 9) or (not colorables and optionsselection == 5) or (colorables and optionsselection == 10) or (not colorables and optionsselection == 6)) and not anyHold then
		saveconfig()
	end
end

function menu_mousepressed(x, y, button)
	if languagemenuopen then
		if languagemenu_mousepressed(x, y, button) then
			languagemenuopen = false
		end
		return
	end
	if gamestate == "menu" then
		menu_updatemouseselection(x,y)
		if mouseonselect then
			if newgamewarning then
				if newgamewarningcursor == 1 then
					selectworld()
					setmenupopupvisible("newgamewarning", false)
				elseif newgamewarningcursor == 2 then
					setmenupopupvisible("newgamewarning", false)
				end
				return
			elseif selectworldopen then
				local x, y = x/scale, y/scale
				local sc = selectworldcursor
				local v = math.ceil(sc/8)*8-7
				if x > 35 and x < 43 and y > 130 and y < 138 then
					local target = selectworldcursor-1
					while target > 0 and not reachedworlds[mappack][target] do
						target = target - 1
					end
					if target > 0 then
						setselectworldcursor(target)
					end
					return
				end
				if x > 215 and x < 223 and y > 130 and y < 138 then
					local target = selectworldcursor+1
					while target <= #mappacklevels and not reachedworlds[mappack][target] do
						target = target + 1
					end
					if target <= #mappacklevels then
						setselectworldcursor(target)
					end
					return
				end
				local i2 = 1
				for i = v, v+7 do
					local world = i
					if hudworldletter and i > 9 and i <= 9+#alphabet then
						world = alphabet:sub(i-9, i-9)
					end
					if reachedworlds[mappack][i] and x > (54+(i2-1)*20) and x < (54+(i2-1)*20)+12 and y > 128 and y < 140 then
						setmenupopupvisible("selectworld", false)
						warpfadeoutnow()
						game_load(i, true)
						break
					end
					i2 = i2 + 1
				end
			else
				--hold down menu buttons
				mouseonselecthold = true
			end
		end
		--sausage D:
		if button == "l" and (not customsprites) and x > 179*scale and y > 71*scale and x < 201*scale and y < 96*scale then
			dothesausage(1)
			dothesausage()
		end
	elseif gamestate == "mappackmenu" then
		openmappacksbutton:click(x, y, button)
		opendlcbutton:click(x, y, button)
		mappacksearchbar:click(x, y, button)
		if button == "wu" then
			menu_keypressed("up")
		elseif button == "wd" then
			menu_keypressed("down")
		elseif button == "l" then
			if y > 4*scale and y < 15*scale then --tab buttons
				local oldmappackhorscroll = mappackhorscroll
				if x > 23*scale and x < 65*scale then
					mappackhorscroll = 0
				elseif x > 71*scale and x < 98*scale then
					mappackhorscroll = 1
				elseif x > 103*scale and x < 225*scale then
					mappackhorscroll = 2
				end
				if oldmappackhorscroll ~= mappackhorscroll then
					openmappacksbutton.active = false
					opendlcbutton.active = false
					mappacks()
					return
				end
			end
			--mappack selection
			if not android then
				if mappacktype ~= "daily_challenge" then
					local i = mappackselection
					local scrollsmooth = mappackscrollsmooth
					if mappacktype == "online" then
						i = onlinemappackselection
						scrollsmooth = onlinemappackscrollsmooth
					end
					if x > 25*scale and y > (20+(i-1)*60-round(scrollsmooth*60))*scale and y > 15*scale
						and x < (mappackhighlight:getWidth()-30)*scale and y < (20+mappackhighlight:getHeight()+(i-1)*60-round(scrollsmooth*60))*scale then
						menu_keypressed("return")
					end
				else
					menu_keypressed("return")
				end
			end
			--mappack scrollbar
			local i = mappackscrollsmooth / (#mappacklist-3.233)
			if mappacktype == "online" then
				i = onlinemappackscrollsmooth / (#onlineassetlist-3.233)
			end
			if x > 227*scale and x < 235*scale and y > (20+i*160)*scale and y < (52+i*160)*scale then --scrollbar
				mappackscrollmouse = true
			end
		end
	end
end

function menu_mousereleased(x, y, button)
	if languagemenuopen then
		return
	end
	if gamestate == "menu" then
		if mouseonselect and mouseonselecthold then
			if mouseonselect == 0 then
				renderoverlay("loading save data...")
				game_load(true)
			elseif mouseonselect == 1 then
				newgame()
			elseif mouseonselect == 2 then
				if nofunallowed then
					if love.keyboard.isDown("lctrl") and love.keyboard.isDown("lshift") then
						renderoverlay("loading editor...")
					else
						notice.new("Creator disabled the editor.", nil, 2)
						return false
					end
				else
					renderoverlay("loading editor...")
				end
				editormode = true
				players = 1
				playertype = "portal"
				playertypei = 1
				disablecheats()
				loadeditormetadata()
				game_load()
				return
			elseif mouseonselect == 3 then
				gamestate = "mappackmenu"
				mappacks()
			elseif mouseonselect == 4 then
				gamestate = "options"
			end
		end
		mouseonselecthold = false
	elseif gamestate == "mappackmenu" then
		mappackscrollmouse = false
		mappacksearchbar:unclick(x, y)
	end
end

function menu_mousemoved(x, y, dx, dy)
	if DisableMouseInMainMenu then
		return false
	end
	if languagemenuopen then
		languagemenu_mousemoved(x, y, dx, dy)
		return
	end
	if gamestate == "mappackmenu" then
		--mappack selection
		if (not android) and mappacktype ~= "daily_challenge" then
			local scrollsmooth = mappackscrollsmooth
			local list = mappacklist
			if mappacktype == "online" then
				scrollsmooth = onlinemappackscrollsmooth
				list = onlineassetlist
			end
			for i = math.max(1, math.floor(scrollsmooth+1)), math.min(#list, math.floor(scrollsmooth+5)) do
				if x > 25*scale and y > (20+(i-1)*60-round(scrollsmooth*60))*scale
					and x < (mappackhighlight:getWidth()-30)*scale and y < (20+mappackhighlight:getHeight()+(i-1)*60-round(scrollsmooth*60))*scale then
					if mappacktype == "online" then
						onlinemappackselection = i
					else
						mappackselection = i
					end
				end
			end
		end
		--mappack scrollbar
		if mappackscrollmouse then
			if mappacktype == "online" then
				onlinemappackscroll = math.min(math.max(onlinemappackscroll+((dy/(159*scale)) * ((#onlineassetlist-3.233))), 0), #onlineassetlist-3.233)
				onlinemappackscrollsmooth = onlinemappackscroll
				onlinemappackselection = math.min(math.max(math.ceil(onlinemappackscroll), onlinemappackselection), math.ceil(onlinemappackscroll)+3)
			else
				mappackscroll = math.min(math.max(mappackscroll+((dy/(159*scale)) * ((#mappacklist-3.233))), 0), #mappacklist-3.233)
				mappackscrollsmooth = mappackscroll
				mappackselection = math.min(math.max(math.ceil(mappackscroll), mappackselection), math.ceil(mappackscroll)+3)
			end
		end
	end
end

function menu_joystickpressed(joystick, button)
	if controlbindingmatchesjoy(1, "right", joystick, button) then
		menu_keypressed("right")
		return
	elseif controlbindingmatchesjoy(1, "left", joystick, button) then
		menu_keypressed("left")
		return
	elseif controlbindingmatchesjoy(1, "down", joystick, button) then
		menu_keypressed("down")
		return
	elseif controlbindingmatchesjoy(1, "up", joystick, button) then
		menu_keypressed("up")
		return
	elseif controlbindingmatchesjoy(1, "jump", joystick, button) then
		menu_keypressed("return")
		return
	elseif controlbindingmatchesjoy(1, "run", joystick, button) then
		menu_keypressed("escape")
		return
	end
end

function menu_joystickreleased(joystick, button)

end

function keypromptenter(t, ...)
	arg = {...}
	if t == "key" and (arg[1] == ";" or arg[1] == "," or arg[1] == "," or arg[1] == "-") then
		return
	end
	buttonerror = false
	axiserror = false
	local buttononly = {"run", "jump", "reload", "use", "portal1", "portal2", "pause"}
	local axisonly = {"aimx", "aimy"}
	local controlset = getcontrolset(keypromptpage)
	local controlname = optionscontrols_controlnames[optionsselection-4]
	if t == "key" and arg[1] == "escape" then
		if keypromptpage > 1 then
			controlset[skinningplayer][controlname] = {}
		end
	else
		if t == "key" then
			if tablecontains(axisonly, controlname) then
				axiserror = true
			else
				controlset[skinningplayer][controlname] = {arg[1]}
			end
		elseif t == "joybutton" then
			if tablecontains(axisonly, controlname) then
				axiserror = true
			else
				controlset[skinningplayer][controlname] = {"joy", arg[1], "but", arg[2]}
			end
		elseif t == "joyhat" then
			if tablecontains(buttononly, controlname) then
				buttonerror = true
			elseif tablecontains(axisonly, controlname) then
				axiserror = true
			else
				controlset[skinningplayer][controlname] = {"joy", arg[1], "hat", arg[2], arg[3]}
			end
		elseif t == "joyaxis" then
			if tablecontains(buttononly, controlname) then
				buttonerror = true
			else
				controlset[skinningplayer][controlname] = {"joy", arg[1], "axe", arg[2], arg[3]}
			end
		end
	end
	
	if (not buttonerror and not axiserror) or arg[1] == "escape" then
		keyprompt = false
	end
end

function keypromptstart()
	keyprompt = true
	keypromptpage = keybindpage
	buttonerror = false
	axiserror = false
	
	--save number of stuff
	prompt = {}
	prompt.joystick = {}
	prompt.joysticks = love.joystick.getJoystickCount()
	
	for i = 1, prompt.joysticks do
		prompt.joystick[i] = {}
		prompt.joystick[i].hats = love.joystick.getHatCount(i)
		prompt.joystick[i].axes = love.joystick.getAxisCount(i)
		
		prompt.joystick[i].validhats = {}
		for j = 1, prompt.joystick[i].hats do
			if love.joystick.getHat(i, j) == "c" then
				table.insert(prompt.joystick[i].validhats, j)
			end
		end
		
		prompt.joystick[i].axisposition = {}
		for j = 1, prompt.joystick[i].axes do
			table.insert(prompt.joystick[i].axisposition, love.joystick.getAxis(i, j))
		end
	end
end

function reset_mappacks()
	delete_mappack("smb")
	delete_mappack("portal")
	delete_mappack("alesans_entities_mappack")

	--[[local dlclist = love.filesystem.getDirectoryItems("alesans_entities/onlinemappacks/")
	for i = 1, #dlclist do
		love.filesystem.remove("alesans_entities/onlinemappacks/" .. dlclist[i])
	end]]
	
	loadbackground("1-1.txt")
	
	playsound(oneupsound)
end

function delete_mappack(pack)
	if not love.filesystem.getInfo(mappackfolder .. "/" .. pack .. "/") then
		return false
	end
	
	local list = love.filesystem.getDirectoryItems(mappackfolder .. "/" .. pack .. "/")
	for i = 1, #list do
		love.filesystem.remove(mappackfolder .. "/" .. pack .. "/" .. list[i])
	end
	local list2 = love.filesystem.getDirectoryItems(mappackfolder .. "/" .. pack .. "/heights")
	for i = 1, #list2 do
		love.filesystem.remove(mappackfolder .. "/" .. pack .. "/heights/" .. list2[i])
	end
	
	love.filesystem.remove(mappackfolder .. "/" .. pack .. "/")
end

function createmappack()
	local i = 1
	while love.filesystem.getInfo( mappackfolder .. "/custom_mappack_" .. i .. "/") do
		i = i + 1
	end
	
	mappack = "custom_mappack_" .. i
	
	love.filesystem.createDirectory(mappackfolder .. "/" .. mappack .. "/")
	
	love.filesystem.createDirectory(mappackfolder .. "/" .. mappack .. "/custom/")
	love.filesystem.createDirectory(mappackfolder .. "/" .. mappack .. "/sounds/")
	love.filesystem.createDirectory(mappackfolder .. "/" .. mappack .. "/animated/")
	love.filesystem.createDirectory(mappackfolder .. "/" .. mappack .. "/enemies/")
	love.filesystem.createDirectory(mappackfolder .. "/" .. mappack .. "/music/")
	love.filesystem.createDirectory(mappackfolder .. "/" .. mappack .. "/backgrounds/")
	love.filesystem.createDirectory(mappackfolder .. "/" .. mappack .. "/animations/")
	
	local s = ""
	s = s .. "name=new mappack" .. "\n"
	s = s .. "author=you" .. "\n"
	s = s .. "description=the newest best  mappack?" .. "\n"
	
	love.filesystem.write(mappackfolder .. "/" .. mappack .. "/settings.txt", s)

	-- Clean old suspend file for renamed or deleted mappacks
	love.filesystem.remove(savesfolder .. "/" .. mappack .. ".suspend")
end

function resetconfig()
	defaultconfig()
	
	changescale(scale)
	--loadplayersprites()
	love.audio.setVolume(volume)
	currentshaderi1 = 1
	currentshaderi2 = 1
	shaders:set(1, nil)
	shaders:set(2, nil)
	saveconfig()
	loadbackground("1-1.txt")
end

function setselectworldcursor(target)
    if target ~= selectworldcursor then
        local now = love.timer.getTime()
        local currentpage = math.ceil(selectworldcursor/8)*8-7
        local targetpage = math.ceil(target/8)*8-7
        previousselectworldcursor = selectworldcursor
        previousselectworldtime = now

        if targetpage ~= currentpage then
            selectworldpreviouspage = currentpage
            selectworldscrollstart = now + math.random() * 0.12
            selectworldscrollcurve = random_motion_curve()
            previousselectworldx = nil
            selectworldcursorcurve = selectworldscrollcurve
        else
            previousselectworldx = 55 + (selectworldcursor-currentpage)*20
            selectworldcursorcurve = random_motion_curve()
        end

        selectworldcursor = target
        selectworldcursoranimstart = now
    end
end

function newgame()
	if love.filesystem.getInfo(savesfolder .. "/" .. mappack .. ".suspend") then
		setmenupopupvisible("newgamewarning", true)
		newgamewarningcursor = 1
		return
	end

	selectworld()
end

function selectworld()
	if not reachedworlds[mappack] then
		renderoverlay("loading game...")
		game_load(nil, true)
	end
	
	local noworlds = true
	for i = 2, #mappacklevels do
		if reachedworlds[mappack][i] then
			noworlds = false
			break
		end
	end
	
	if noworlds then
		renderoverlay("loading game...")
		game_load(nil, true)
		return
	end
	
	setmenupopupvisible("selectworld", true)
	selectworldcursor = 1
	previousselectworldcursor = nil
	previousselectworldtime = nil
	selectworldcursoranimstart = love.timer.getTime()
	selectworldcursorcurve = random_motion_curve()
	
	selectworldexists = {}
	for i = 1, #mappacklevels do
		if love.filesystem.getInfo(mappackfolder .. "/" .. mappack .. "/" .. i .. "-1.txt") then
			selectworldexists[i] = true
		end
	end
end

function opendlcfolder()
	local path
	if onlineassetlist[onlinemappackselection] and onlineassetlist[onlinemappackselection].type == "character" then
		path = "characters"
	else
		path = "onlinemappacks"
	end

	if android then
		notice.new("On android use a file manager\nand go to:\nAndroid > data > Love.to.mario")
		filebrowser_load("alesans_entities/" .. path)
		return false
	end
	if not love.filesystem.getInfo("alesans_entities/" .. path) then
		love.filesystem.createDirectory("alesans_entities/" .. path)
	end
	openfile("alesans_entities/" .. path)
end

--https://stackoverflow.com/questions/20459943/find-the-last-index-of-a-character-in-a-string/20461414
local function lastIndexOf(haystack, needle)
    local i, j
    local k = 0
    repeat
        i = j
        j, k = string.find(haystack, needle, k + 1, true)
    until j == nil

    return i
end

function menu_filedropped(file)
	if gamestate == "mappackmenu" then
		--drag and drop zip file
		local filename = string.sub(file:getFilename(), (lastIndexOf(file:getFilename(), "\\") or -5)+1, -1)
		local newfilepath = "alesans_entities/onlinemappacks/" .. filename
		if filename:sub(-4,-1) == ".zip" and not love.filesystem.getInfo(newfilepath) then --only copy if file doesn't exist
			local filedata = love.filesystem.newFileData(file)
			love.filesystem.write(newfilepath, filedata) --copy file

			local success = mountmappack(filename)
			if success then
				--reload mappack list
				mappackhorscroll = 0
				mappacks()
				local name = filename:sub(1,-5)
				for i = 1, #mappacklist do
					if mappacklist[i] == name then
						mappackselection = i
						break
					end
				end
				updatescroll()
				notice.new("Loaded " .. filename, nil, 4)
			else
				love.filesystem.remove(newfilepath)
				notice.new("Could not load " .. filename, notice.red, 4)
			end
		end
	end
end

function menu_updatemouseselection(x,y)
	if newgamewarning then
		local x, y = x/scale, y/scale
		local option1start = (130-((utf8.len(TEXT["new game"])+utf8.len(TEXT["go back"]))*4)-16) - 2
		local option1end = option1start + (utf8.len(TEXT["new game"])*8) + 2
		local option2start = (130-((utf8.len(TEXT["new game"])-utf8.len(TEXT["go back"]))*4)+16) - 2
		local option2end = option2start + (utf8.len(TEXT["go back"])*8) + 2
		if x > option1start and x < option1end and y > 128 and y < 140 then
			newgamewarningcursor = 1
		elseif x > option2start and x < option2end and y > 128 and y < 140 then
			newgamewarningcursor = 2
		end
	elseif selectworldopen then
		local x, y = x/scale, y/scale
		local sc = selectworldcursor
		local v = math.ceil(sc/8)*8-7
		
		local i2 = 1
		for i = v, v+7 do
			local world = i
			if hudworldletter and i > 9 and i <= 9+#alphabet then
				world = alphabet:sub(i-9, i-9)
			end
			if reachedworlds[mappack][i] and x > (54+(i2-1)*20) and x < (54+(i2-1)*20)+12 and y > 128 and y < 140 then
				setselectworldcursor(i)
				break
			end
			i2 = i2 + 1
		end
	else
		mouseonselect = false
		local x, y = x/scale, y/scale
		--continue game
		if continueavailable then
			if x > (143-(math.ceil(utf8.len(TEXT["continue game"])/2)*8)) and y > 122 and x < (143+(math.ceil(utf8.len(TEXT["continue game"])/2)*8)) and y < 122+8 then
				selection = 0
				mouseonselect = 0
			end
		end
		--player game
		if x > (143-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8)) and y > 138 and x < (143+(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8)) and y < 138+8 then
			selection = 1
			mouseonselect = 1
		end
		--level editor
		if x > (143-(math.ceil(utf8.len(TEXT["level editor"])/2)*8)) and y > 154 and x < (143+(math.ceil(utf8.len(TEXT["level editor"])/2)*8)) and y < 154+8 then
			selection = 2
			mouseonselect = 2
		end
		--select mappack
		if x > (143-(math.ceil(utf8.len(TEXT["select mappack"])/2)*8)) and y > 170 and x < (143+(math.ceil(utf8.len(TEXT["select mappack"])/2)*8)) and y < 170+8 then
			selection = 3
			mouseonselect = 3
		end
		--options
		if x > (143-(math.ceil(utf8.len(TEXT["options"])/2)*8)) and y > 186 and x < (143+(math.ceil(utf8.len(TEXT["options"])/2)*8)) and y < 186+8 then
			selection = 4
			mouseonselect = 4
		end
	end
end

function searchmappacks()
	local text = mappacksearchbar.value
	local mappacksearchtable = {}
	local names = mappackname
	if mappacktype == "online" then names = onlinemappackname end

	for i in pairs(names) do
		for j = 1, (#names[i] - #text)+1 do
			if string.sub(names[i], j, #text+j-1) == text then
				table.insert(mappacksearchtable, i)
				break
			end
		end
	end
	if #mappacksearchtable == 0 then
		playsound(blockhitsound)
		return
	end

	local pass = true
	for i in pairs(mappacksearchtable) do
		if mappacksearchtable[i] ~= oldmappacksearchtable[i] then
		pass = false
		end
	end

	if pass then
		mappacksearchi = mappacksearchi + 1
	else
		mappacksearchi = 0
		oldmappacksearchtable = mappacksearchtable
	end

	local topick = mappacksearchtable[(mappacksearchi % #mappacksearchtable)+1]

	if mappacktype == "local" then
		mappackselection = topick
		updatescroll()
	elseif mappacktype == "online" then
		onlinemappackselection = topick
		onlineupdatescroll()
	end
end

function brprint(text, y)
	if not (custombackground or customforeground) or hudoutline then
		love.graphics.setColor(0, 0, 0)
		properprint(text, (width*16-#(text)*8-7)*scale, (y + 1)*scale)
		love.graphics.setColor(255, 255, 255)
	end

	properprint(text, (width*16-#(text)*8-8)*scale, y*scale)
end