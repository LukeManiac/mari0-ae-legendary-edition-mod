local languagemenuopen = false
local resetwarningopen = false
local resetwarningcursor = 2
local resetwarningstage = 1 --1 = first warning, 2 = second "are you really sure?" warning
local resettexthovertime = 0 --seconds the "reset" option of the warning popup has been hovered, drives its shake (decays when not hovered)
local RESET_SHAKE_MAX_TIME = 4 --hover time at which the shake reaches its 4 pixel cap
local RESET_SHAKE_DECAY = 1.5 --how many times slower than it builds up the shake fades out
local menu_updatemouseselection

local previousmappackfolder
local controlsbuttonpadding = 4
local keybindpage = 1
local keybindpageanimation
local keybindpageduration = 0.25
local optionspageanimation --{from, to, start, curve} while the options menu slides between tabs
local optionspageduration = 0.25

--vertical scrolling in the mappack menu: every time the target row changes, the list glides
--from wherever it is to the new target on an ease-out-quad curve
local MAPPACK_SCROLL_DURATION = 0.25
local mappackscrollanims = {} --[list] = {from, to, start, last}
function mappackscroll_ease(list, current, target)
	local anim = mappackscrollanims[list]
	--a new target, or something else snapped the list (opening the menu, searching): start from where it is now
	if not anim or anim.to ~= target or anim.last ~= current then
		if current == target then
			mappackscrollanims[list] = nil
			return target
		end
		anim = {from = current, to = target, start = love.timer.getTime()}
		mappackscrollanims[list] = anim
	end
	local t = (love.timer.getTime() - anim.start) / MAPPACK_SCROLL_DURATION
	if t >= 1 then
		mappackscrollanims[list] = nil
		return target
	end
	anim.last = anim.from + (anim.to - anim.from)*ease_out_quad(t)
	return anim.last
end
local OPTIONS_BOX_X, OPTIONS_BOX_Y, OPTIONS_BOX_W, OPTIONS_BOX_H = 21, 16, 218, 200 --the options menu's dark box, which the tabs slide inside
local OPTIONS_TABPREFIXES = {"ctrl_", "skin_", "opt_", "cheat_"} --the start of the names of each tab's widgets
--misc. tab: the joystick deadzone row sits above scale, packed in above shader1 (which stays at 63)
local OPTIONS_MISC_DEADZONE_Y, OPTIONS_MISC_SCALE_Y, OPTIONS_MISC_LETTERBOX_Y = 32, 42, 53
local keypromptpage = 1
local menupopupduration = 0.25
local menupopupanimations = {
	newgamewarning = {from = 0, to = 0},
	selectworld = {from = 0, to = 0},
	resetwarning = {from = 0, to = 0},
	controls = {from = 0, to = 0},
	keyprompt = {from = 0, to = 0}
}

function menupopupscale(name, now)
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

	progress = ease_in_out_quad(progress)
	return lerp(anim.from, anim.to, progress)
end

controlsopen = false
keyprompt = false

--true while the pause menu's controls popup is open or still animating closed
function controlspopupvisible()
	return controlsopen or menupopupscale("controls", love.timer.getTime()) > 0
end

--true while the keyprompt popup is open or still animating
function keypromptvisible()
	return keyprompt or menupopupscale("keyprompt", love.timer.getTime()) > 0
end

--true only when the keyprompt animation has fully opened
function keypromptfullyopen()
	return keyprompt and menupopupscale("keyprompt", love.timer.getTime()) >= 1
end

function setmenupopupvisible(name, visible)
	local currentlyvisible
	if name == "newgamewarning" then
		currentlyvisible = newgamewarning
	elseif name == "resetwarning" then
		currentlyvisible = resetwarningopen
	elseif name == "controls" then
		currentlyvisible = controlsopen
	elseif name == "keyprompt" then
		currentlyvisible = keyprompt
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
	anim.opening = visible

	if name == "newgamewarning" then
		newgamewarning = visible
	elseif name == "resetwarning" then
		resetwarningopen = visible
	elseif name == "controls" then
		controlsopen = visible
		if visible then
			if not guielements["ctrl_player"] then
				optionscontrols_create()
			end
			optionscontrols_sync()
			skinningplayer = 1
			optionsselection = 2
		end
	elseif name == "keyprompt" then
		keyprompt = visible
	else
		selectworldopen = visible
	end
end

--Misc. options tab (optionstab == 3) widgets
local optionsmiscgui = {"opt_deadzone", "opt_scale", "opt_letterbox", "opt_shader1", "opt_shader2", "opt_volume", "opt_language", "opt_nitpicks", "opt_resetmaps", "opt_resetall", "opt_vsync", "opt_mappackfolder"}
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
    if gamestate == "options" and options_tabshown(4) and gamefinished then
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

local function getmouseownerforpage(page)
	page = page or keybindpage
	if page == 1 then
		return mouseowner or 0
	elseif page == 2 then
		return mouseowner2 or 0
	elseif page == 3 then
		return mouseowner3 or 0
	elseif page == 4 then
		return mouseowner4 or 0
	end
	return 0
end

local function setmouseownerforpage(page, player)
	page = page or keybindpage
	if page == 1 then
		mouseowner = player
	elseif page == 2 then
		mouseowner2 = player
	elseif page == 3 then
		mouseowner3 = player
	elseif page == 4 then
		mouseowner4 = player
	end
end

local function optionscontrols_lastselection()
	local visiblecontrols = getmouseownerforpage(keybindpage) == skinningplayer and 9 or #optionscontrols_controlnames
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

function optionscontrols_create()
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

	local currentbindlabel = TEXT["current bind:"]
	local bindlabelwidth = utf8.len(currentbindlabel) * 8
	local binddropdownwidth = 13 + 8
	local bindgroupx = 130 - (bindlabelwidth + 4 + binddropdownwidth) / 2
	guielements["ctrl_bindpage"] = guielement:new("dropdown", bindgroupx + bindlabelwidth + 4, 64, 1, function(i)
		optionscontrols_change_page(i - keybindpage)
		guielements["ctrl_bindpage"].var = i
	end, keybindpage, "1", "2", "3", "4")

	--Uses The Mouse checkbox (per keybind page: mouseowner, mouseowner2, ...)
	guielements["ctrl_mouse"] = guielement:new("checkbox", right - 9, 52, function(v)
		if v then
			setmouseownerforpage(keybindpage, skinningplayer)
		else
			setmouseownerforpage(keybindpage, 0)
		end
		guielements["ctrl_mouse"].var = v
		saveconfig()
	end, getmouseownerforpage(keybindpage) == skinningplayer)

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

	--these are also drawn inside the pause menu's controls popup, where the mouse has to be translated (see optionscontrols_transformmouse)
	guielements["ctrl_player"].controlspopup = true
	guielements["ctrl_mouse"].controlspopup = true
	guielements["ctrl_bindpage"].controlspopup = true
end

function optionscontrols_remove()
	for i = 1, #optionscontrolsgui do
		guielements[optionscontrolsgui[i]] = nil
	end
end

function optionscontrols_sync()
	if not guielements["ctrl_player"] then
		return
	end

	guielements["ctrl_player"].var = skinningplayer
	guielements["ctrl_bindpage"].var = keybindpage
	guielements["ctrl_mouse"].var = (getmouseownerforpage(keybindpage) == skinningplayer)

	local showextra = (getmouseownerforpage(keybindpage) ~= skinningplayer)

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
	local showextra = (getmouseownerforpage(page or keybindpage) ~= skinningplayer)

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
		start = love.timer.getTime()
	}
	keybindpage = page
	if guielements["ctrl_mouse"] then
		guielements["ctrl_mouse"].var = (getmouseownerforpage(keybindpage) == skinningplayer)
	end
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

	progress = ease_out_quad(progress)
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

	local showextra = (getmouseownerforpage(page) ~= skinningplayer)
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

local function optionscontrols_resettooltip()
	local ctrlheld = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
	if ctrlheld then
		if keybindpage == 1 then
			if skinningplayer == 1 then
				return "press ctrl+f6 to", "reset keybinds"
			end
			return "press ctrl+f6 to reset", "keybinds to player " .. (skinningplayer - 1)
		end
		return "press ctrl+f6 to", "clear keybinds"
	end
	if skinningplayer >= 2 then
		return "press f6 on a keybind", "to copy from player " .. (skinningplayer - 1)
	end
	return "press f6 on a keybind", "to reset it to default"
end

local function optionscontrols_resetbindings()
	local controlset = getcontrolset(keybindpage)
	if not controlset then
		return false
	end
	if not controlset[skinningplayer] then
		controlset[skinningplayer] = {}
	end

	if keybindpage == 1 then
		if skinningplayer == 1 then
			controlset[1]["left"] = {"a"}
			controlset[1]["right"] = {"d"}
			controlset[1]["up"] = {"w"}
			controlset[1]["down"] = {"s"}
			controlset[1]["run"] = {"lshift"}
			controlset[1]["jump"] = {" "}
			controlset[1]["reload"] = {"r"}
			controlset[1]["use"] = {"e"}
			controlset[1]["pause"] = {"escape"}
			controlset[1]["aimx"] = {""}
			controlset[1]["aimy"] = {""}
			controlset[1]["portal1"] = {""}
			controlset[1]["portal2"] = {""}
		else
			local source = controlset[skinningplayer - 1]
			if source then
				for _, name in ipairs(controlstable) do
					controlset[skinningplayer][name] = deepcopy(source[name] or {})
				end
			end
		end
	else
		for _, name in ipairs(controlstable) do
			controlset[skinningplayer][name] = {}
		end
	end

	optionscontrols_sync()
	saveconfig()
	return true
end

local function optionscontrols_defaultbinding(player, name, page)
	page = page or keybindpage
	-- players 2+ copy the same binding from the previous player on this page
	if player >= 2 then
		local controlset = getcontrolset(page)
		local source = controlset and controlset[player - 1] and controlset[player - 1][name]
		return deepcopy(source or {})
	end
	-- player 1 on page 1: keyboard defaults; other pages: unbound
	if page ~= 1 then
		return {}
	end
	local defaults = {
		left = {"a"},
		right = {"d"},
		up = {"w"},
		down = {"s"},
		run = {"lshift"},
		jump = {" "},
		reload = {"r"},
		use = {"e"},
		pause = {"escape"},
		aimx = {""},
		aimy = {""},
		portal1 = {""},
		portal2 = {""},
	}
	return deepcopy(defaults[name] or {})
end

local function optionscontrols_reset_selected_binding()
	local controlindex = optionsselection - 4
	if controlindex < 1 or controlindex > #optionscontrols_controlnames then
		return false
	end
	local name = optionscontrols_controlnames[controlindex]
	local controlset = getcontrolset(keybindpage)
	if not controlset then
		return false
	end
	if not controlset[skinningplayer] then
		controlset[skinningplayer] = {}
	end
	controlset[skinningplayer][name] = optionscontrols_defaultbinding(skinningplayer, name, keybindpage)
	optionscontrols_sync()
	saveconfig()
	return true
end

--where the pause menu's controls popup is on screen, and how far its widgets are shifted from where the options menu draws them
local function controlspopup_geometry()
	local winwidth, winheight = getproperwindowsize()
	local popupw = 240 * scale
	local popuph = 226 * scale
	local popupx = (winwidth - popupw) / 2
	local popupy = (winheight - popuph) / 2
	return popupx, popupy, popupw, popuph, popupx - 20*scale, popupy - 2*scale
end

function optionscontrols_transformmouse(x, y)
	if gamestate == "game" then
		--pause menu popup: the widgets are drawn shifted, so move the mouse the same way (and ignore it while the popup is animating)
		if not controlsopen or keybindpageanimation or menupopupscale("controls", love.timer.getTime()) ~= 1 then
			return -math.huge, -math.huge
		end
		local _, _, _, _, offsetx, offsety = controlspopup_geometry()
		return x - offsetx, y - offsety
	end
	if gamestate ~= "options" or optionstab ~= 1 then
		return x, y
	end
	if keybindpageanimation then
		return -math.huge, -math.huge
	end

	return x, y
end

function optionscontrols_update()
	if (gamestate == "options" and options_tabshown(1)) or controlsopen then
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

--left/right key: change the volume (or another slider with a commit function) by delta and animate the handle
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
	local commit = slider.commit or volumeslider_commit --the deadzone slider steps the same way
	commit(slider)

	if from ~= target then
		slider.value = from --show the handle where it was, then slide it
		slider.valueanim = {from = from, to = target, start = love.timer.getTime()}
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
	slider.value = lerp(anim.from, anim.to, ease_out_quad(t))
	if t >= 1 then
		slider.value = anim.to
		slider.valueanim = nil
	end
end

--joystick deadzone slider (options > misc.): 0 to 1, shown in percent, saved as joydeadzone
local DEADZONE_LOW = 0.1 --below this, a stick that rests a little off its centre can start pressing things by itself
local deadzonelownotice --the notice warning about it, while it's on screen

--warns that the deadzone is low. The text is the same in every language (like the other notices here), and changing
--the deadzone again while the warning is up keeps that one on screen instead of stacking another
local function deadzoneslider_warnlow()
	for _, v in ipairs(notice.notices) do
		if v == deadzonelownotice then
			v.life = math.max(v.life, v.duration - notice.fadetime)
			return
		end
	end
	notice.new("joystick deadzone below 10%!\nsticks may drift and\npress things by themselves", notice.red, 4)
	deadzonelownotice = notice.notices[#notice.notices]
end

function deadzoneslider_commit(slider)
	slider.value = math.min(math.max(slider.value, 0), 1)
	joystickdeadzone = round(slider.value, 2)
	if joystickdeadzone ~= slider.savedvalue then
		slider.savedvalue = joystickdeadzone
		saveconfig()
		if joystickdeadzone < DEADZONE_LOW then
			deadzoneslider_warnlow()
		end
	end
end

function deadzoneslider_new(x, y, range)
	local slider = guielement:new("scrollbar", x, y, range, 33, 9, joystickdeadzone, "hor")
	slider.backgroundcolor = {0, 0, 0}
	slider.buttonround = true
	slider.scrollstepdisabled = true --the mouse wheel would change the value without a release
	slider.savedvalue = joystickdeadzone
	slider.commit = deadzoneslider_commit
	slider.displayfunction = function(self, v)
		if self.valueanim then
			v = self.valueanim.to --show where it's going while the handle slides
		end
		return round(v*100) .. "%"
	end
	slider.updatefunc = function(self, v)
		joystickdeadzone = round(math.min(math.max(v, 0), 1), 2)
	end
	slider.releasefunc = function(self, v)
		deadzoneslider_commit(self)
	end
	return slider
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

--"reset all settings" warning, animated like the other menu popups (see menupopupanimations)
local function resetwarning_open()
	resetwarningcursor = 2 --"go back" is selected first
	resetwarningstage = 1
	resettexthovertime = 0
	setmenupopupvisible("resetwarning", true)

	--the widgets behind the popup stop right away, optionsmisc_update keeps them that way
	for i = 1, #optionsmiscgui do
		local v = guielements[optionsmiscgui[i]]
		if v then
			v.active = false
			v.nohover = true
		end
	end
end

local function resetwarning_confirm(reset)
	if reset and resetwarningstage < 3 then
		--warning confirmed, ask again before actually resetting (3 warnings in total)
		resetwarningstage = resetwarningstage + 1
		resetwarningcursor = 2 --"go back" is selected first
		resettexthovertime = 0 --each warning starts calm
		if resetwarningstage == 3 then
			playsound(lowtimesound) --the final warning pops up
		end
		return
	end

	if reset then
		resetconfig()
		playsound(gameoversound)
	else
		playsound(oneupsound)
		lowtimesound:stop()
	end

	--closing after the reset, so the loading time does not eat the fade out
	setmenupopupvisible("resetwarning", false)
end

--x position and width of the two options, shared by drawing and mouse selection
local function resetwarning_layout()
	local resetlength = utf8.len(TEXT["reset"])
	local backlength = utf8.len(TEXT["go back"])
	local gap = 32
	local resetx = 130 - ((resetlength + backlength)*8 + gap)/2
	local backx = resetx + resetlength*8 + gap
	return resetx, resetlength*8, backx, backlength*8
end

local function resetwarning_updatemouse(x, y)
	x, y = x/scale, y/scale
	local resetx, resetwidth, backx, backwidth = resetwarning_layout()
	if y > 128 and y < 140 then
		if x > resetx - 2 and x < resetx + resetwidth + 2 then
			resetwarningcursor = 1
			return true
		elseif x > backx - 2 and x < backx + backwidth + 2 then
			resetwarningcursor = 2
			return true
		end
	end
	return false
end

local function resetwarning_mousepressed(x, y, button)
	ignoregui = true --the widgets behind the popup must not get this click

	if button == "l" and resetwarning_updatemouse(x, y) then
		resetwarning_confirm(resetwarningcursor == 1)
	end
end

local function resetwarning_keypressed(key)
	if (key == "left" or key == "a") then
		resetwarningcursor = 1
	elseif (key == "right" or key == "d") then
		resetwarningcursor = 2
	elseif (key == "return" or key == "enter" or key == "kpenter" or key == " ") then
		resetwarning_confirm(resetwarningcursor == 1)
	elseif key == "escape" then
		playsound(oneupsound)
		lowtimesound:stop()
		setmenupopupvisible("resetwarning", false)
	end
end

local function resetwarning_draw()
	if gamestate ~= "options" then
		return
	end

	local popupscale = menupopupscale("resetwarning", love.timer.getTime())
	if not resetwarningopen and popupscale <= 0 then
		return
	end

	--the dimmed foreground fades in and out with the popup
	love.graphics.setColor(0, 0, 0, 150*popupscale)
	love.graphics.rectangle("fill", 0, 0, width*16*scale, height*16*scale)

	love.graphics.push()
	love.graphics.translate(130*scale, 122*scale)
	love.graphics.scale(popupscale, popupscale)
	love.graphics.translate(-130*scale, -122*scale)
	love.graphics.translate(0, (1 - popupscale) * 8 * scale)

	local alpha = 255*popupscale
	local popupradius = 60 * scale * 0.2
	guiglass.box(20*scale, 92*scale, 220*scale, 60*scale, popupradius, alpha/255)
	love.graphics.setColor(255, 255, 255, alpha)
	local line1 = TEXT["all settings and controls"]
	local line2 = TEXT["will be reset to default!"]
	if resetwarningstage == 2 then
		line1 = TEXT["are you really sure?"]
		line2 = TEXT["this cannot be undone!"]
	elseif resetwarningstage == 3 then
		line1 = TEXT["last chance!"]
		line2 = TEXT["really reset everything?"]
	end
	properprintF(line1, (130-(utf8.len(line1)*4))*scale, 100*scale)
	properprintF(line2, (130-(utf8.len(line2)*4))*scale, 110*scale)

	local resetx, resetwidth, backx, backwidth = resetwarning_layout()
	local shakerange = math.min(resettexthovertime, 4) --capped at 4 pixels
	local shakex = (math.random()*2-1)*shakerange
	local shakey = (math.random()*2-1)*shakerange
	if resetwarningcursor == 1 then
		love.graphics.setColor(255, 255, 255, alpha)
		properprintF(">", (resetx-10)*scale, 130*scale)

		local r, g, b = 255, 80, 80
		if resetwarningstage == 2 then
			r, g, b = 255, 40, 40
		elseif resetwarningstage == 3 then
			r, g, b = 255, 0, 0
		end

		love.graphics.setColor(r, g, b, alpha)
	else
		love.graphics.setColor(255, 255, 255, alpha)
		properprintF(">", (backx-10)*scale, 130*scale)
		love.graphics.setColor(100, 100, 100, alpha)
	end

	properprintF(TEXT["reset"], (resetx+shakex)*scale, (130+shakey)*scale)

	if resetwarningcursor == 1 then
		love.graphics.setColor(100, 100, 100, alpha)
	else
		love.graphics.setColor(255, 255, 255, alpha)
	end

	properprintF(TEXT["go back"], backx*scale, 130*scale)

	love.graphics.pop()
	love.graphics.setColor(255, 255, 255, 255)
end

local function optionsmisc_create()
	local right = 235 --right edge of the dropdowns and checkboxes

	--Joystick deadzone, after its label
	local deadzonex = 30 + utf8.len(TEXT["joy deadzone:"])*8 + 4
	guielements["opt_deadzone"] = deadzoneslider_new(deadzonex, OPTIONS_MISC_DEADZONE_Y, right-deadzonex)

	--Scale
	guielements["opt_scale"] = guielement:new("dropdown", right-(13+9*8), OPTIONS_MISC_SCALE_Y, 9, function(i)
		changescale(i)
		guielements["opt_scale"].var = i
		saveconfig()
	end, resizable and 5 or scale, 1, 2, 3, 4, 5)
	guielements["opt_scale"].displayentries = {"*1", "*2", "*3", "*4", "resizable"}

	--Letterbox
	guielements["opt_letterbox"] = guielement:new("checkbox", right-9, OPTIONS_MISC_LETTERBOX_Y, function(v)
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
	guielements["opt_language"] = guielement:new("button", 30, 120, TEXT["change language"], function()
		languagemenuopen = true
		languagemenu_open()
	end)

	--Generate Nitpicks File
	guielements["opt_nitpicks"] = guielement:new("button", 30, 134, TEXT["generate nitpicks file"], function()
		generatenitpicksfile()
	end)

	--Reset Included Maps
	guielements["opt_resetmaps"] = guielement:new("button", 30, 147, TEXT["reset included maps"], function()
		reset_mappacks()
	end)
	guielements["opt_resetmaps"].textcolor = {255, 0, 0}

	--Reset All Settings
	guielements["opt_resetall"] = guielement:new("button", 30, 160, TEXT["reset all settings"], function()
		resetwarning_open()
	end)
	guielements["opt_resetall"].textcolor = {255, 0, 0}

	--Volume
	guielements["opt_volume"] = volumeslider_new(90, 109, right-90)

	--VSync
	guielements["opt_vsync"] = guielement:new("checkbox", right-9, 172, function(v)
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

	guielements["opt_mappackfolder"] = guielement:new("dropdown", 30, 191, 17, function(i)
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
	"smwwaterphysics",
	"nologdumping",
	"skipintro",
	"consistentvinespeed",
	"orderedmovementtypes",
	"invinciblesnake",
	"multiplejumping",
	"probabilitypasser",
	"immortalcombometer",
	"removecooldowns",
	"classicspeedupfastmusic",
	"modernsizechangeanimation",
	"noairspeedcap",
	"inertiaphysics",
	"dontfreezeonsizechange",
	"camerasmoothing",
	"backwardsmoothing",
	"automaticenemyreload"
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
		--JSON:encode_pretty sorts object keys alphabetically, so write the file in nitpickkeys order instead
		local lines = {}
		for _, key in ipairs(nitpickkeys) do
			table.insert(lines, "    " .. JSON:encode_pretty(key) .. ": " .. JSON:encode_pretty(t[key:lower()]))
		end
		love.filesystem.write(path, "{\n" .. table.concat(lines, ",\n") .. "\n}")
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

	local deadzone = guielements["opt_deadzone"]
	volumeslider_animate(deadzone)
	if not deadzone.dragging and not deadzone.valueanim and not deadzone.inputting and deadzone.value ~= joystickdeadzone then
		deadzone.value = joystickdeadzone
		deadzone.savedvalue = joystickdeadzone
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
	if gamestate == "options" and options_tabshown(3) then
		if not guielements["opt_scale"] then
			optionsmisc_create()
		end
		optionsmisc_sync()

		--the widgets sit still (no clicks, no hover animations) while the language menu is open
		for i = 1, #optionsmiscgui do
			if guielements[optionsmiscgui[i]] then
				guielements[optionsmiscgui[i]].active = not (languagemenuopen or resetwarningopen)
				guielements[optionsmiscgui[i]].nohover = languagemenuopen or resetwarningopen
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

------------------------------------------------------------------------
--Skins options tab (optionstab == 2) widgets
------------------------------------------------------------------------
--keyboard rows: 2 player, 3 character, 4 hat, 5 colourable, 6-8 red, green and blue, 9-10 coop portal colours
--(a character without colourables has its portal colours at 5 and 6)
local optionsskinsgui = {"skin_player", "skin_character", "skin_hat", "skin_colorable", "skin_red", "skin_green", "skin_blue", "skin_portal1", "skin_portal2"}

--layout, in game pixels
local SKINS_RIGHT = 235 --right edge of the widgets, like the other tabs
local SKINS_DROPDOWN_X = 118 --the character, hat and colourable dropdowns
local SKINS_DROPDOWN_WIDTH = 13 --characters wide, so they end at SKINS_RIGHT
local SKINS_PREVIEW_X, SKINS_PREVIEW_FEET = 50, 92 --middle and feet of the big character preview (drawn twice the size)
local SKINS_PORTAL_X, SKINS_PORTAL_Y = 78, 56 --top left of the 32x32 portal preview
local SKINS_CHARACTER_Y = 56
local SKINS_CHARACTER_ROW = 32 --a character's skin (20 pixels, with room for a hat) and its name under it
local SKINS_HAT_Y = 92
local SKINS_HAT_ROW = 18 --fits the tallest hat (17 pixels)
local SKINS_HAT_COLUMNS = 6
local SKINS_COLORABLE_Y = 115
local SKINS_RGB_Y = 130 --red, green and blue rows are 10 pixels apart
local SKINS_PORTAL1_Y = 164 --label, with the slider 10 pixels under it
local SKINS_PORTAL2_Y = 187
local SKINS_SLIDER_RIGHT = 205
local SKINS_SWATCH_X = 210 --the full colour previews, right of the sliders
local SKINS_SWATCH_W = SKINS_RIGHT-SKINS_SWATCH_X
local SKINS_SLIDER_H = 9

--what the colour and portal sliders were last showing, so a switch to something else can be seen
local skins_colorcontext, skins_portalcontext

local function skins_character()
	return characters.data[mariocharacter[skinningplayer]]
end

function skins_hascolorables()
	local v = skins_character()
	return v and type(v.colorables) == "table" and #v.colorables > 0
end

--the colour (r, g, b, 0-255) the sliders edit
local function skins_editcolor()
	local colors = mariocolors[skinningplayer]
	return colors and colors[colorsetedit]
end

--what a character looks like for the player being edited: the colours and hats it has now if it is theirs,
--else the ones picking it would give it (setcustomplayer)
local function skins_previewlook(name)
	local pn = skinningplayer
	local v = characters.data[name]
	if name == mariocharacter[pn] then
		return mariocolors[pn] or {}, mariohats[pn] or {}
	end
	local colors, hats = mariocolors[pn] or {}, mariohats[pn] or {}
	local defaults = v.defaultcolors and v.defaultcolors[pn]
	if defaults and type(v.colorables) == "table" and #defaults >= #v.colorables then
		colors = defaults
		if v.defaulthat then
			hats = {}
			if v.defaulthat ~= 0 then
				hats = {v.defaulthat}
			end
		end
	end
	return colors, hats
end

--the part of a character's standing frame that has pixels in it: {left, top, right, bottom} in the frame
--(right and bottom are past the last pixel). Custom characters pad their frames however they like,
--so this is what lines them up. Worked out once from the image files.
local function skins_spritebounds(name)
	local v = characters.data[name]
	local qx, qy, qw, qh = v.small.idle[3]:getViewport()
	local bounds = {0, 0, qw, qh}
	local folder = "alesans_entities/characters/" .. name .. "/"
	local files = {}
	if love.filesystem.getInfo(folder .. "animations.png") then
		files = {"animations.png"}
	else
		local colorables = type(v.colorables) == "table" and #v.colorables or 0
		for j = 0, colorables do
			if love.filesystem.getInfo(folder .. "animations" .. j .. ".png") then
				table.insert(files, "animations" .. j .. ".png")
			end
		end
	end
	local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
	for _, file in ipairs(files) do
		local ok, data = pcall(love.image.newImageData, folder .. file)
		if ok and data then
			local w, h = data:getDimensions()
			for y = math.max(0, qy), math.min(h, qy+qh)-1 do
				for x = math.max(0, qx), math.min(w, qx+qw)-1 do
					local _, _, _, a = data:getPixel(x, y)
					if a > 0 then
						left, right = math.min(left, x-qx), math.max(right, x-qx+1)
						top, bottom = math.min(top, y-qy), math.max(bottom, y-qy+1)
					end
				end
			end
		end
	end
	if left <= right then
		bounds = {left, top, right, bottom}
	end
	return bounds
end

--makes sure a character's graphics and bounds are loaded (optionsskins_preload loads them all when the menu loads,
--this catches characters added after that, like a downloaded one)
local function skins_characterready(name)
	local v = characters.data[name]
	if not v then
		return false
	end
	if not (v.animations and v.quads and v.skinsbounds) then
		loadcustomplayergraphics(name)
		v.skinsbounds = skins_spritebounds(name)
	end
	return true
end

--loads every character's skin, so the skins menu never has to stop and load one
function optionsskins_preload()
	for _, name in ipairs(characters.list) do
		skins_characterready(name)
	end
end

--the character's middle across its standing frame, where the game centres it: the game draws the frame
--smalloffsetX right of the player and smallquadcenterX back, and the player is 12 pixels wide
local function skins_framecenterx(name)
	local v = characters.data[name]
	return 6 - v.smalloffsetX + v.smallquadcenterX
end

--top left of the standing frame (game pixels) that puts the character's middle in the middle of a box x, w wide
--and the bottom of its sprite on feety (rounded inside the box, so it stays put in a list that scrolls by fractions of a pixel)
local function skins_placecharacter(name, x, w, feety, s)
	local b = characters.data[name].skinsbounds
	return x + math.floor(w/2 - skins_framecenterx(name)*s), feety - b[4]*s
end

--draws a character standing still with the top left of its frame at x, y (s is its size),
--the colourable parts get colors, and hats are stacked on its head if withhats
local function skins_drawcharacter(name, colors, hats, x, y, s, withhats)
	local v = characters.data[name]
	if not (v and v.small and v.animations) then
		return
	end
	local quad = v.small.idle[3]
	local ax, ay = (x+v.smallquadcenterX*s)*scale, (y+v.smallquadcenterY*s)*scale
	local colorables = type(v.colorables) == "table" and v.colorables or {}

	if v.portalgununderhat then
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.draw(v.animations[0], quad, ax, ay, 0, scale*s, scale*s, v.smallquadcenterX, v.smallquadcenterY)
	end
	for i = 1, #colorables do
		love.graphics.setColor(colors[i] or {255, 255, 255})
		if v.animations[i] then
			love.graphics.draw(v.animations[i], quad, ax, ay, 0, scale*s, scale*s, v.smallquadcenterX, v.smallquadcenterY)
		end
	end

	if withhats and v.hats then
		local offsets = customplayerhatoffsets(name, "hatoffsets", "idle") or hatoffsets["idle"]
		if #hats > 1 or hats[1] ~= 1 then
			local yadd = 0
			for i = 1, #hats do
				local t = hat[hats[i]]
				if t then
					love.graphics.setColor(255, 255, 255)
					love.graphics.draw(t.graphic, t.quad[1], ax, ay, 0, scale*s, scale*s, v.smallquadcenterX - t.x + offsets[1], v.smallquadcenterY - t.y + offsets[2] + yadd)
					yadd = yadd + t.height
				end
			end
		elseif #hats == 1 then
			--the standard hat takes the first colourable's colour
			local t = hat[1]
			love.graphics.setColor(colors[1] or {255, 255, 255})
			love.graphics.draw(t.graphic, t.quad[1], ax, ay, 0, scale*s, scale*s, v.smallquadcenterX - t.x + offsets[1], v.smallquadcenterY - t.y + offsets[2])
		end
	end

	if not v.portalgununderhat then
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.draw(v.animations[0], quad, ax, ay, 0, scale*s, scale*s, v.smallquadcenterX, v.smallquadcenterY)
	end
end

--text colour of a dropdown entry: black on the bright highlight, grey for the header while its list is open
local function skins_entrytextcolor(self, highlighted, header)
	if highlighted then
		love.graphics.setColor(0, 0, 0)
	elseif header and self.extended then
		love.graphics.setColor(127, 127, 127)
	else
		love.graphics.setColor(255, 255, 255)
	end
end

--runs f with drawing cut to a box (game pixels, wherever the current transform puts it)
local function skins_clip(x, y, w, h, f)
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

--prints s centred in a box of width w; text too long for it slides to its end and back so all of it can be read
local SKINS_SCROLL_SPEED = 24 --game pixels a second
local SKINS_SCROLL_PAUSE = 1 --seconds it waits at each end
local function skins_printscrolling(s, x, y, w)
	local textwidth = utf8.len(s)*8
	if textwidth <= w then
		properprintF(s, (x+math.floor((w-textwidth)/2))*scale, y*scale)
		return
	end
	local overflow = textwidth-w
	local slide = overflow/SKINS_SCROLL_SPEED
	local t = love.timer.getTime() % (2*(slide+SKINS_SCROLL_PAUSE))
	local offset
	if t < SKINS_SCROLL_PAUSE then
		offset = 0
	elseif t < SKINS_SCROLL_PAUSE+slide then
		offset = (t-SKINS_SCROLL_PAUSE)*SKINS_SCROLL_SPEED
	elseif t < 2*SKINS_SCROLL_PAUSE+slide then
		offset = overflow
	else
		offset = overflow-(t-2*SKINS_SCROLL_PAUSE-slide)*SKINS_SCROLL_SPEED
	end
	skins_clip(x, y-1, w, 10, function()
		properprintF(s, math.floor((x-offset)*scale), y*scale)
	end)
end

--prints s centred in a box, cut to fit
local function skins_printcentered(s, x, y, w)
	local maxchars = math.floor(w/8)
	if utf8.len(s) > maxchars then
		s = s:sub(1, (utf8.offset(s, maxchars+1) or #s+1)-1)
	end
	properprintF(s, (x+math.floor((w-utf8.len(s)*8)/2))*scale, y*scale)
end

--character dropdown entry: its skin, with its name under it
local function skins_drawcharacterentry(self, i, x, y, w, h, highlighted, header)
	local name = characters.list[i]
	local v = characters.data[name]
	if not v then
		return
	end
	--the sprite stands just above the name, in the middle; a tall sprite or hat is cut at the box
	local feety = y+h-9
	if skins_characterready(name) then
		local colors, hats = skins_previewlook(name)
		local px, py = skins_placecharacter(name, x, w, feety, 1)
		skins_clip(x, y, w, feety-y, function()
			skins_drawcharacter(name, colors, hats, px, py, 1, true)
		end)
	end

	skins_entrytextcolor(self, highlighted, header)
	skins_printscrolling(v.name or name, x+1, y+h-8, w-2)
end

--hat dropdown: the hat ids in list order, 0 being no hat
local function skins_hatlist()
	local ids = {}
	for id in pairs(hat) do
		if type(id) == "number" then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	table.insert(ids, 1, 0)
	return ids
end

--hat dropdown entry: only the hat's graphic
local function skins_drawhatentry(self, i, x, y, w, h, highlighted, header)
	local v = skins_character()
	if header and not (v and v.hats) then
		love.graphics.setColor(127, 127, 127)
		skins_printcentered(TEXT["disabled"], x, y+math.floor((h-8)/2), w)
		return
	end
	local id = self.entries[i]
	local t = hat[id]
	if not t then
		--no hat: a crossed out circle
		skins_entrytextcolor(self, highlighted, header)
		local cx, cy = (x+w/2)*scale, (y+h/2)*scale
		love.graphics.setLineWidth(scale)
		love.graphics.circle("line", cx, cy, 4*scale, 16)
		love.graphics.line(cx-2.8*scale, cy+2.8*scale, cx+2.8*scale, cy-2.8*scale)
		love.graphics.setLineWidth(1)
		return
	end
	local _, _, qw, qh = t.quad[1]:getViewport()
	if id == 1 then
		--the standard hat takes the first colourable's colour, as it does on the player
		local colors = mariocolors[skinningplayer]
		love.graphics.setColor(colors and colors[1] or {255, 255, 255})
	else
		love.graphics.setColor(255, 255, 255)
	end
	love.graphics.draw(t.graphic, t.quad[1], (x+math.floor((w-qw)/2))*scale, (y+math.floor((h-qh)/2))*scale, 0, scale, scale)
end

--a small colour square with a frame, so black on black still shows
local function skins_drawswatch(x, y, w, h, color)
	local r = math.min(w, h)*scale*0.15
	love.graphics.setColor(127, 127, 127)
	love.graphics.rectangle("fill", x*scale, y*scale, w*scale, h*scale, r)
	love.graphics.setColor(color[1], color[2], color[3])
	love.graphics.rectangle("fill", (x+1)*scale, (y+1)*scale, (w-2)*scale, (h-2)*scale, r*0.7)
end

--the colour the red, green and blue sliders show right now. While they glide over to another player's, character's or
--colourable's colour, that's the colour in between, so everything showing the colour glides along with them
local SKINS_RGBSLIDERS = {"skin_red", "skin_green", "skin_blue"}
local function skins_shownrgb()
	local color = skins_editcolor()
	if not color then
		return nil
	end
	local shown = {}
	for channel, name in ipairs(SKINS_RGBSLIDERS) do
		local slider = guielements[name]
		if slider then
			shown[channel] = slider.value*255
		else
			shown[channel] = color[channel] or 0 --before the sliders exist
		end
	end
	return shown
end

--the colour a coop portal slider shows right now, gliding along with its handle
local function skins_shownportalcolor(portal)
	local slider = guielements["skin_portal" .. portal]
	if slider then
		return getrainbowcolor(slider.value)
	end
	return portalcolor[skinningplayer][portal]
end

--colourable dropdown entry: its colour and its name. The header's colour is the one being edited, so it glides with the sliders
local function skins_drawcolorableentry(self, i, x, y, w, h, highlighted, header)
	local colors = mariocolors[skinningplayer]
	local color = {255, 255, 255}
	if header and i == colorsetedit and skins_shownrgb() then
		color = skins_shownrgb()
	elseif colors and colors[i] then
		color = colors[i]
	end
	skins_drawswatch(x+1, y+1, 7, 7, color)
	skins_entrytextcolor(self, highlighted, header)
	local s = tostring(self.entries[i])
	local maxchars = math.floor((w-11)/8)
	if utf8.len(s) > maxchars then
		s = s:sub(1, (utf8.offset(s, maxchars+1) or #s+1)-1)
	end
	properprintF(s, (x+10)*scale, (y+1)*scale)
end

--a slider's track painted by stepcolor(t) along it (t from 0 to 1), inside the usual dark frame
local function skins_drawgradienttrack(x, y, w, h, r, stepcolor)
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", x, y, w, h, r)
	local steps = math.max(1, math.floor(w/scale)-2)
	for i = 0, steps-1 do
		love.graphics.setColor(stepcolor(i/math.max(1, steps-1)))
		love.graphics.rectangle("fill", x+(1+i)*scale, y+scale, scale, h-2*scale)
	end
end

local function skins_newslider(x, y, range, handlewidth, value)
	local slider = guielement:new("scrollbar", x, y, range, handlewidth, SKINS_SLIDER_H, value, "hor")
	slider.backgroundcolor = {0, 0, 0}
	slider.buttonround = true
	slider.scrollstepdisabled = true --the mouse wheel would change the colour without saving it
	slider.trackclick = true
	return slider
end

--slider for one channel (1 red, 2 green, 3 blue) of the colourable being edited
local function skins_rgbslider(channel, y)
	local color = skins_editcolor() or {0, 0, 0}
	local slider = skins_newslider(40, y, SKINS_SLIDER_RIGHT-40, 27, (color[channel] or 0)/255)
	slider.centerdisplay = true
	slider.displayfunction = function(self, v)
		if self.valueanim then
			v = self.valueanim.to --show where it's going while it glides
		end
		return round(v*255)
	end
	slider.updatefunc = function(self, v)
		local color = skins_editcolor()
		if color then
			color[channel] = round(v*255)
		end
	end
	slider.releasefunc = function(self, v)
		saveconfig()
	end
	--the track shows what the colour would be along it, with the other two channels as their sliders show them (gliding too)
	slider.drawtrack = function(self, x, y, w, h, r)
		local color = skins_shownrgb() or {0, 0, 0}
		skins_drawgradienttrack(x, y, w, h, r, function(t)
			local c = {color[1], color[2], color[3]}
			c[channel] = t*255
			return c
		end)
	end
	return slider
end

--slider for the hue of one of the coop portals
local function skins_portalslider(portal, y)
	local slider = skins_newslider(30, y, SKINS_SLIDER_RIGHT-30, 9, portalhues[skinningplayer][portal])
	slider.typeable = false
	slider.updatefunc = function(self, v)
		portalhues[skinningplayer][portal] = v
		portalcolor[skinningplayer][portal] = getrainbowcolor(v)
	end
	slider.releasefunc = function(self, v)
		saveconfig()
	end
	slider.drawtrack = function(self, x, y, w, h, r)
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", x, y, w, h, r)
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(huebarimg, x+scale, y+scale, 0, (w-2*scale)/huebarimg:getWidth(), (h-2*scale)/huebarimg:getHeight())
	end
	return slider
end

--picking a character in the dropdown, or with left and right
function optionsskins_setcharacter(i)
	if not characters.list[i] then
		return
	end
	if characters.list[i] ~= mariocharacter[skinningplayer] then
		colorsetedit = 1
		setcustomplayer(characters.list[i], skinningplayer)
		saveconfig()
	end
	characteri = characters.data[mariocharacter[skinningplayer]].i
end

local function optionsskins_create()
	--Edit Player dropdown, the same as the controls tab's
	guielements["skin_player"] = guielement:new("dropdown", SKINS_RIGHT - (13 + 1 * 8), 40, 1, function(i)
		skinningplayer = i
		if characters.data[mariocharacter[skinningplayer]] then
			characteri = characters.data[mariocharacter[skinningplayer]].i
		end
		if players > #controls then
			loadconfig()
		end
		guielements["skin_player"].var = i
		saveconfig()
	end, skinningplayer, "1", "2", "3", "4")

	--Character: skin and name
	guielements["skin_character"] = guielement:new("dropdown", SKINS_DROPDOWN_X, SKINS_CHARACTER_Y, SKINS_DROPDOWN_WIDTH, function(i)
		optionsskins_setcharacter(i)
	end, characteri, unpack(characters.list))
	guielements["skin_character"]:setentrydrawing(skins_drawcharacterentry, SKINS_CHARACTER_ROW)

	--Hat: only the graphics, in a grid
	guielements["skin_hat"] = guielement:new("dropdown", SKINS_DROPDOWN_X, SKINS_HAT_Y, SKINS_DROPDOWN_WIDTH, function(i)
		local id = guielements["skin_hat"].entries[i]
		if id == 0 then
			mariohats[skinningplayer] = {}
		else
			mariohats[skinningplayer][1] = id
		end
		saveconfig()
	end, 1, unpack(skins_hatlist()))
	guielements["skin_hat"]:setentrydrawing(skins_drawhatentry, SKINS_HAT_ROW, SKINS_HAT_COLUMNS)
	guielements["skin_hat"].hatcount = hatcount

	--Colourable
	guielements["skin_colorable"] = guielement:new("dropdown", SKINS_DROPDOWN_X, SKINS_COLORABLE_Y, SKINS_DROPDOWN_WIDTH, function(i)
		colorsetedit = i
	end, 1, "")
	guielements["skin_colorable"]:setentrydrawing(skins_drawcolorableentry)

	--Red, green and blue
	guielements["skin_red"] = skins_rgbslider(1, SKINS_RGB_Y)
	guielements["skin_green"] = skins_rgbslider(2, SKINS_RGB_Y+10)
	guielements["skin_blue"] = skins_rgbslider(3, SKINS_RGB_Y+20)

	--Coop portal colours
	guielements["skin_portal1"] = skins_portalslider(1, SKINS_PORTAL1_Y+10)
	guielements["skin_portal2"] = skins_portalslider(2, SKINS_PORTAL2_Y+10)
end

local function optionsskins_remove()
	skins_colorcontext, skins_portalcontext = nil, nil --nothing to glide from when they're made again
	for i = 1, #optionsskinsgui do
		local v = guielements[optionsskinsgui[i]]
		if v and v.type == "dropdown" then
			v:close()
		end
		guielements[optionsskinsgui[i]] = nil
	end
end

--the keyboard row of each widget, which depends on the character having colourables
local function optionsskins_selections()
	if skins_hascolorables() then
		return {[2] = "skin_player", [3] = "skin_character", [4] = "skin_hat", [5] = "skin_colorable",
			[6] = "skin_red", [7] = "skin_green", [8] = "skin_blue", [9] = "skin_portal1", [10] = "skin_portal2"}
	end
	return {[2] = "skin_player", [3] = "skin_character", [4] = "skin_hat", [5] = "skin_portal1", [6] = "skin_portal2"}
end

--a list changed (characters or hats loaded, another character's colourables): keep the dropdown's entries in line
local function skins_sameentries(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

--moves a slider to target: gliding there on a motion curve (0.25 seconds) if glide, else straight away.
--A glide stops when the value is taken over (dragged, typed, or changed by a held key)
local SKINS_GLIDE_TIME = 0.25
local function skins_followvalue(slider, target, glide)
	if slider.dragging or slider.inputting then
		slider.valueanim = nil
		return
	end
	if glide and math.abs(slider.value-target) > 1e-9 then
		slider.valueanim = {from = slider.value, to = target, start = love.timer.getTime()}
	end
	local anim = slider.valueanim
	if anim and anim.to == target then
		local t = (love.timer.getTime()-anim.start)/SKINS_GLIDE_TIME
		if t < 1 then
			slider.value = lerp(anim.from, anim.to, ease_out_quad(t))
			return
		end
	end
	slider.valueanim = nil
	slider.value = target
end

--keeps the widgets in line with the variables when something else changed them (keyboard, another player, ...)
local function optionsskins_sync()
	local pn = skinningplayer
	local v = skins_character()
	local hascolorables = skins_hascolorables()
	if hascolorables then
		colorsetedit = math.max(1, math.min(colorsetedit, #v.colorables))
	end

	guielements["skin_player"].var = pn

	local character = guielements["skin_character"]
	if not skins_sameentries(character.entries, characters.list) then
		character:close()
		character:setentries({unpack(characters.list)})
	end
	character.var = v.i

	local hats = guielements["skin_hat"]
	if hats.hatcount ~= hatcount then
		hats:close()
		hats:setentries(skins_hatlist())
		hats.hatcount = hatcount
	end
	hats.var = 1
	for i, id in ipairs(hats.entries) do
		if id == mariohats[pn][1] then
			hats.var = i
			break
		end
	end
	--a character without hats can't wear one
	if not v.hats and hats.extended then
		hats:close()
	end
	hats.active = v.hats and true or false
	hats.nohover = not hats.active

	local colorable = guielements["skin_colorable"]
	if hascolorables then
		if not skins_sameentries(colorable.entries, v.colorables) then
			colorable:close()
			colorable:setentries({unpack(v.colorables)})
		end
		colorable.var = colorsetedit
	elseif colorable.extended then
		colorable:close()
	end
	colorable.active = hascolorables

	--sliders follow the colours unless they're being dragged; they glide over when another player, character or colourable
	--is picked (the colour sliders) or another player (the portal sliders, the only thing their colours belong to)
	local colorcontext = pn .. ":" .. tostring(mariocharacter[pn]) .. ":" .. colorsetedit
	local glidecolors = skins_colorcontext ~= nil and colorcontext ~= skins_colorcontext
	local glideportals = skins_portalcontext ~= nil and pn ~= skins_portalcontext
	skins_colorcontext, skins_portalcontext = colorcontext, pn

	local color = skins_editcolor()
	for channel, name in ipairs({"skin_red", "skin_green", "skin_blue"}) do
		local slider = guielements[name]
		slider.active = hascolorables and color ~= nil
		if slider.active then
			skins_followvalue(slider, math.min(math.max((color[channel] or 0)/255, 0), 1), glidecolors)
		end
	end
	for portal = 1, 2 do
		local slider = guielements["skin_portal" .. portal]
		skins_followvalue(slider, portalhues[pn][portal], glideportals)
		slider.fillcolor = skins_shownportalcolor(portal) --the handle is the portal's colour, gliding with it
	end

	--the widget the keyboard has selected looks hovered
	local selections = optionsskins_selections()
	for i = 1, #optionsskinsgui do
		guielements[optionsskinsgui[i]].forcehover = false
	end
	for selection, name in pairs(selections) do
		guielements[name].forcehover = (optionsselection == selection)
	end
end

function optionsskins_update()
	if gamestate == "options" and options_tabshown(2) then
		if not guielements["skin_player"] then
			optionsskins_create()
		end
		optionsskins_sync()
	elseif guielements["skin_player"] then
		optionsskins_remove()
	end
end

--pressing enter on the row the keyboard has selected opens its dropdown
function optionsskins_activate(selection)
	local v = guielements[optionsskins_selections()[selection]]
	if v and v.active and v.type == "dropdown" and not v.extended then
		v:open(true)
	end
end

--labels, previews and widgets of the skins tab
local function optionsskins_draw()
	local pn = skinningplayer
	local v = skins_character()
	local hascolorables = skins_hascolorables()
	local selections = optionsskins_selections()
	local function rowcolor(name)
		local selected = false
		for selection, n in pairs(selections) do
			if n == name and optionsselection == selection then
				selected = true
			end
		end
		if selected then
			love.graphics.setColor(255, 255, 255, 255)
		else
			love.graphics.setColor(100, 100, 100, 255)
		end
		return selected
	end

	--edit player
	rowcolor("skin_player")
	properprintF(TEXT["edit player:"], 30*scale, 40*scale)

	--PREVIEW MARIO IN BIG. WITH BIG LETTERS
	if skins_characterready(mariocharacter[pn]) then
		local px, py = skins_placecharacter(mariocharacter[pn], SKINS_PREVIEW_X-30, 60, SKINS_PREVIEW_FEET, 2)
		skins_drawcharacter(mariocharacter[pn], mariocolors[pn], mariohats[pn], px, py, 2, true)
	end

	--PREVIEW PORTALS WITH FALLING MARIO BECAUSE I CAN AND IT LOOKS RAD
	local dx, dy = SKINS_PORTAL_X-142, SKINS_PORTAL_Y-42 --this preview was made for 142, 42
	--cut inside whatever clip is already set (the tab slide's), and moved along with the tab
	skins_clip(SKINS_PORTAL_X, SKINS_PORTAL_Y, 32, 32, function()
		local colorables = type(v.colorables) == "table" and v.colorables or {}
		for j = 1, #colorables do
			local fx, fy = (152+dx+v.smalloffsetX)*scale, (2+dy+((j-1)*32)+infmarioY-v.smalloffsetY)*scale
			if v.portalgununderhat then
				love.graphics.setColor(255, 255, 255, 255)
				love.graphics.draw(v["animations"][0], v["small"]["jump"][3][1], fx, fy, infmarioR, scale, scale, v.smallquadcenterX, v.smallquadcenterY)
			end
			for i = 1, #colorables do
				love.graphics.setColor(mariocolors[pn][i] or {255, 255, 255})
				love.graphics.draw(v["animations"][i], v["small"]["jump"][3][1], fx, fy, infmarioR, scale, scale, v.smallquadcenterX, v.smallquadcenterY)
			end
			if not v.portalgununderhat then
				love.graphics.setColor(255, 255, 255, 255)
				love.graphics.draw(v["animations"][0], v["small"]["jump"][3][1], fx, fy, infmarioR, scale, scale, v.smallquadcenterX, v.smallquadcenterY)
			end
		end
		local portalframe = portalanimation
		love.graphics.setColor(255, 255, 255, 80 - math.abs(portalframe-3)*10)
		love.graphics.draw(portalglowimg, (174+dx)*scale, (59+dy)*scale, math.pi, scale, scale)
		love.graphics.draw(portalglowimg, (142+dx)*scale, (57+dy)*scale, 0, scale, scale)
		love.graphics.setColor(portalcolor[pn][1])
		love.graphics.draw(portalimg, portalquad[portalframe], (174+dx)*scale, (46+dy)*scale, math.pi, scale, scale)
		love.graphics.setColor(portalcolor[pn][2])
		love.graphics.draw(portalimg, portalquad[portalframe], (142+dx)*scale, (70+dy)*scale, 0, scale, scale)
	end)

	--character
	if rowcolor("skin_character") then
		love.graphics.setColor(0, 0, 0, 200)
		love.graphics.rectangle("fill", 240*scale, 41*scale, 95*scale, 41*scale)
		love.graphics.setColor(255, 255, 255)
		properprintF(TEXT["press m to\nopen your\ncharacters\nfolder"], 241*scale, 43*scale)
	end

	--hat
	if rowcolor("skin_hat") and not v.hats then
		love.graphics.setColor(150, 150, 150, 255)
	end
	local hatlabel = TEXT["hat: "]:gsub("%s+$", "")
	properprintF(hatlabel, 30*scale, (SKINS_HAT_Y+math.floor((SKINS_HAT_ROW-7)/2))*scale)

	if hascolorables then
		--colourable
		rowcolor("skin_colorable")
		properprintF(TEXT["colour:"], 30*scale, (SKINS_COLORABLE_Y+2)*scale)

		--r, g and b, bright on the selected row
		local letters = {{"r", {255, 0, 0}}, {"g", {0, 255, 0}}, {"b", {0, 0, 255}}}
		local names = {"skin_red", "skin_green", "skin_blue"}
		for i, t in ipairs(letters) do
			local y = SKINS_RGB_Y+(i-1)*10+1
			local selected = guielements[names[i]] and guielements[names[i]].forcehover
			local c = t[2]
			local k = selected and 1 or 0.6
			love.graphics.setColor(c[1]*0.4*k, c[2]*0.4*k, c[3]*0.4*k)
			properprint(t[1], 31*scale, (y+1)*scale)
			love.graphics.setColor(c[1]*k, c[2]*k, c[3]*k)
			properprint(t[1], 30*scale, y*scale)
		end

		--the colour itself, right of its sliders
		local color = skins_shownrgb()
		if color then
			skins_drawswatch(SKINS_SWATCH_X, SKINS_RGB_Y, SKINS_SWATCH_W, 20+SKINS_SLIDER_H, color)
		end
	end

	--coop portal colours, with each colour aside its slider
	rowcolor("skin_portal1")
	properprintF(TEXT["coop portal 1 color:"], 30*scale, SKINS_PORTAL1_Y*scale)
	skins_drawswatch(SKINS_SWATCH_X, SKINS_PORTAL1_Y+10, SKINS_SWATCH_W, SKINS_SLIDER_H, skins_shownportalcolor(1))
	rowcolor("skin_portal2")
	properprintF(TEXT["coop portal 2 color:"], 30*scale, SKINS_PORTAL2_Y*scale)
	skins_drawswatch(SKINS_SWATCH_X, SKINS_PORTAL2_Y+10, SKINS_SWATCH_W, SKINS_SLIDER_H, skins_shownportalcolor(2))

	--widgets, an open dropdown list on top of the rest
	local ontop = {}
	for i = 1, #optionsskinsgui do
		local w = guielements[optionsskinsgui[i]]
		if w and (w.type ~= "scrollbar" or options_widgetactive(w)) then
			if optionsskinsgui[i] == "skin_colorable" and not hascolorables then
				--no colourables, nothing to pick
			elseif w.extended or (w.listvalue and w.listvalue > 0) then
				table.insert(ontop, w)
			else
				w:draw()
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
	utilsmenuopen = false

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
	optionspageanimation = nil
	keybindpage = 1
	keybindpageanimation = nil
	resetwarningopen = false
	menupopupanimations.resetwarning = {from = 0, to = 0}
	skinningplayer = 1
	characteri = characters.data[mariocharacter[1]].i
	optionsskins_preload() --every character's skin, ready for the skins menu
	rgbselection = 1
	colorsetedit = 1
	mappackselection = 1
	onlinemappackselection = 1
	openmappacksbutton = guielement:new("button", 241, 190, "open folder", function() openSaveFolder(mappackfolder) end, nil, 0, 2.5, 147, true)
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
	--"reset" text shake: the longer it is hovered in the warning popup, the harder it shakes
	if gamestate == "options" and resetwarningopen and resetwarningcursor == 1 then
		resettexthovertime = math.min(resettexthovertime + dt, RESET_SHAKE_MAX_TIME)
	else
		--moving the cursor away slowly calms the shake down instead of stopping it at once
		resettexthovertime = math.max(resettexthovertime - dt/RESET_SHAKE_DECAY, 0)
	end

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
	options_updatepageanimation()
	optionscontrols_update()
	optionsmisc_update()
	optionscheats_update()
	if utilsmenuopen then
		utilsmenu_update(dt)
	end
	
	if mappackscroll then
		--smooth the scroll
		mappackscrollsmooth = mappackscroll_ease("local", mappackscrollsmooth, mappackscroll)
	end

	if onlinemappackscroll then
		--smooth the scroll
		onlinemappackscrollsmooth = mappackscroll_ease("online", onlinemappackscrollsmooth, onlinemappackscroll)
	end

	if gamestate == "mappackmenu" then
		mappackgui_update(dt)
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
		mappackpage_update() --switching pages slides them (see mappackmenu_drawslide)
	end
	if mappacksearchbar.active then
		mappacksearchbar:update(dt)
	end
	if gamestate == "mappackmenu" and mappacktype == "minigames" then
		minigame_menu_update(dt)
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
	
		if skins_hascolorables() and optionsselection > 5 and optionsselection < 9 and skins_editcolor() then
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
			
		elseif (skins_hascolorables() and optionsselection == 9) or (not skins_hascolorables() and optionsselection == 5) then
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
			
		elseif (skins_hascolorables() and optionsselection == 10) or (not skins_hascolorables() and optionsselection == 6) then
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
	optionsskins_update() --after the held keys above changed the colours, so the sliders show this frame's
	options_freezepages()
	
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
	if (x ~= oldmouse[1] or y ~= oldmouse[2]) and gamestate == "menu" and (not utilsmenuopen) and (not DisableMouseInMainMenu) and (not languagemenuopen) then
		menu_updatemouseselection(x,y)
	end
	if (x ~= oldmouse[1] or y ~= oldmouse[2]) and resetwarningopen and gamestate == "options" and (not DisableMouseInMainMenu) and (not languagemenuopen) then
		resetwarning_updatemouse(x, y)
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

	languagemenu_update(dt, languagemenuopen)
end

--whether a tab's widgets should exist: the open tab, and the tab sliding out while the menu switches tabs
function options_tabshown(tab)
	return optionstab == tab or (optionspageanimation ~= nil and optionspageanimation.from == tab)
end

--switches to another tab, sliding the old one out and the new one in
function options_switchtab(tab)
	if tab == optionstab or tab < 1 or tab > 4 then
		return
	end
	optionspageanimation = {
		from = optionstab,
		to = tab,
		start = love.timer.getTime()
	}
	optionstab = tab
end

--how far along the tab slide is (0 to 1, after the motion curve), or nil when the menu isn't sliding
local function options_pageprogress()
	local animation = optionspageanimation
	if not animation then
		return nil
	end
	local t = (love.timer.getTime() - animation.start) / optionspageduration
	if t >= 1 then
		return nil
	end
	return ease_out_quad(t)
end

--gives the frozen widgets back what they had before the slide; their tab's sync puts anything else right this frame
local function options_unfreezepages()
	for _, el in pairs(guielements) do
		if el.optionspagesaved then
			el.active = el.optionspagesaved.active
			el.nohover = el.optionspagesaved.nohover
			el.optionspagesaved = nil
		end
	end
end

--whether a widget is active, going by what it was before the tab slide froze it
function options_widgetactive(el)
	if el.optionspagesaved then
		return el.optionspagesaved.active
	end
	return el.active
end

--ends the tab slide once it's over, before the tabs' updates remove the widgets of the tab that slid out
function options_updatepageanimation()
	if optionspageanimation and (gamestate ~= "options" or not options_pageprogress()) then
		optionspageanimation = nil
		options_unfreezepages()
	end
end

--while the tabs slide, neither tab's widgets can be clicked, typed into or hovered, since they aren't where the mouse thinks they are
function options_freezepages()
	local animation = optionspageanimation
	if gamestate ~= "options" or not animation then
		return
	end
	local fromprefix, toprefix = OPTIONS_TABPREFIXES[animation.from], OPTIONS_TABPREFIXES[animation.to]
	for name, el in pairs(guielements) do
		if type(name) == "string" and (name:sub(1, #fromprefix) == fromprefix or name:sub(1, #toprefix) == toprefix) then
			if not el.optionspagesaved then
				el.optionspagesaved = {active = el.active, nohover = el.nohover}
			end
			el.active = false
			el.nohover = true
			el.forcehover = false
		end
	end
end

--the f6 note of the controls tab, right of the options box with its middle halfway down the screen, like the dlc tips in the mappack menu.
--It's outside the box, so it fades with the tab slide instead of sliding
local function optionscontrols_drawresetnote()
	local shown = 0
	local progress = options_pageprogress()
	if progress then
		if optionspageanimation.to == 1 then
			shown = progress
		elseif optionspageanimation.from == 1 then
			shown = 1 - progress
		end
	elseif optionstab == 1 then
		shown = 1
	end
	if shown <= 0 then
		return
	end

	local boxx = OPTIONS_BOX_X + OPTIONS_BOX_W + 2 --241, where the dlc tips start
	local boxw = width*16 - boxx - 9
	optionscontrols_drawnotebox(boxx*scale, boxw*scale, height*16/2*scale, shown)
end

--the f6 note in a glass box (screen pixels): left edge x, width w, its middle at centery, shown fades it (0-1).
--The text is rewrapped to the box's width, since the lines are longer than it
function optionscontrols_drawnotebox(x, w, centery, shown)
	local line1, line2 = optionscontrols_resettooltip()
	local lines, line = {}, ""
	local maxchars = math.max(1, math.floor((w/scale - 6)/8))
	for word in (line1 .. " " .. line2):gmatch("%S+") do
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

	local h = (#lines*10 + 4)*scale
	local y = centery - h/2
	guiglass.box(x, y, w, h, 4*scale, shown, {rimstrength = 0.55})
	love.graphics.setColor(255, 255, 255, 255*shown)
	for i = 1, #lines do
		properprintF(lines[i], x + 3*scale, y + (3 + (i-1)*10)*scale)
	end
end

--labels and widgets of the open tab (optionstab)
local function options_drawtab()
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
		local currentbindlabel = TEXT["current bind:"]
		local bindlabelwidth = utf8.len(currentbindlabel) * 8
		local bindgroupwidth = bindlabelwidth + 4 + 21
		properprintF(currentbindlabel, (130 - bindgroupwidth/2)*scale, 66*scale)

		if optionsselection == 3 then
			love.graphics.setColor(255, 255, 255, 255)
		else
			love.graphics.setColor(100, 100, 100, 255)
		end
		properprintF(TEXT["uses the mouse:"], 30*scale, 52*scale)
		
		skins_clip(OPTIONS_BOX_X, OPTIONS_BOX_Y, OPTIONS_BOX_W, OPTIONS_BOX_H, function()
			local pageviews = optionscontrols_pageviews()
			for i = 1, #pageviews do
				optionscontrols_draw_page(pageviews[i].page, pageviews[i].offset)
			end
		end)
		optionscontrols_draw(nil, false, true)

			
		local now = love.timer.getTime()
		local keypromptscale = menupopupscale("keyprompt", now)
		if keyprompt or keypromptscale > 0 then
			love.graphics.push()
			love.graphics.translate(130*scale, 130*scale)
			love.graphics.scale(keypromptscale, keypromptscale)
			love.graphics.translate(-130*scale, -130*scale)

			local progress = keypromptscale
			love.graphics.translate(0, (1 - progress) * 8 * scale)

			local popupradius = math.min(200, 60) * scale * 0.2
			guiglass.box(30*scale, 100*scale, 200*scale, 60*scale, popupradius, 1)
			love.graphics.setColor(255, 255, 255)
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
				escapetext = TEXT["press 'esc' to clear"]
			end
			properprintF(escapetext, 40*scale, 140*scale)
			
			if axiserror then
				love.graphics.setColor(200, 0, 0)
				properprintF(TEXT["you can only set"], 40*scale, 120*scale)
				properprintF(TEXT["axes for this"], 40*scale, 130*scale)
			end
			love.graphics.pop()
		end
	elseif optionstab == 2 then
		--SKINS: player, character and hat dropdowns, colour sliders and previews
		optionsskins_draw()
	elseif optionstab == 3 then
		if optionsselection == 2 then
			love.graphics.setColor(255, 255, 255, 255)
		else
			love.graphics.setColor(100, 100, 100, 255)
		end
		properprintF(TEXT["joy deadzone:"], 30*scale, (OPTIONS_MISC_DEADZONE_Y+1)*scale)

		if optionsselection == 3 then
			love.graphics.setColor(255, 255, 255, 255)
		else
			love.graphics.setColor(100, 100, 100, 255)
		end
		properprintF(TEXT["scale:"], 30*scale, (OPTIONS_MISC_SCALE_Y+2)*scale)

		if optionsselection == 4 then
			love.graphics.setColor(255, 255, 255, 255)
		else
			love.graphics.setColor(100, 100, 100, 255)
		end
		properprintF(TEXT["letterbox:"], 30*scale, (OPTIONS_MISC_LETTERBOX_Y+1)*scale)
		
		if optionsselection == 5 then
			love.graphics.setColor(255, 255, 255, 255)
		else
			love.graphics.setColor(100, 100, 100, 255)
		end
		
		properprintF(TEXT["shader1:"], 30*scale, 65*scale)
		if shaderssupported == false then
			properprintF(TEXT["unsupported"], (180-utf8.len("unsupported")*8)*scale, 65*scale)
		end
		
		if optionsselection == 6 then
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
		
		if optionsselection == 7 then
			love.graphics.setColor(255, 255, 255, 255)
		else
			love.graphics.setColor(100, 100, 100, 255)
		end
		properprintF(TEXT["volume:"], 30*scale, 110*scale)
		
		if optionsselection == 12 then
			love.graphics.setColor(255, 255, 255, 255)
		else
			love.graphics.setColor(100, 100, 100, 255)
		end
		
		properprintF(TEXT["vsync:"], 30*scale, 172*scale)
		
		if optionsselection == 13 then
			love.graphics.setColor(255, 255, 255, 255)
		else
			love.graphics.setColor(100, 100, 100, 255)
		end
		
		properprintF(TEXT["mappack folder:"], 30*scale, 182*scale)
		
		--love.graphics.setColor(100, 100, 100, 255)
		--properprintF(TEXT["lock mouse with f12"], 30*scale, 195*scale)
		
		love.graphics.setColor(255, 255, 255, 255)
		properprintF("mari0 le " .. VERSIONSTRING, 30*scale, 205*scale)
		
		--widgets (scale, letterbox, shaders, language, nitpicks, resets, vsync, mappack folder)
		optionsmisc_draw()
	elseif optionstab == 4 then
		love.graphics.setColor(255, 255, 255, 255)

		if gamefinished then
			properprintF(TEXT["have fun with these!"], 30*scale, 45*scale)
		else
			properprintF(TEXT["unlock this by completing"], 30*scale, 40*scale)
			properprintF(TEXT["the original levels pack!"], 30*scale, 50*scale)
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

--the open tab, or while switching tabs, the old tab sliding out and the new one sliding in, cut to the options box
local function options_drawpages()
	local progress = options_pageprogress()
	if not progress then
		options_drawtab()
		return
	end

	local animation = optionspageanimation
	local direction = animation.to > animation.from and 1 or -1
	local distance = OPTIONS_BOX_W
	local tab, selection = optionstab, optionsselection
	skins_clip(OPTIONS_BOX_X, OPTIONS_BOX_Y, OPTIONS_BOX_W, OPTIONS_BOX_H, function()
		--the old tab is drawn as it was left: tabs only switch while the tab row is selected
		optionstab, optionsselection = animation.from, 1
		love.graphics.push()
		love.graphics.translate(-direction * progress * distance * scale, 0)
		options_drawtab()
		love.graphics.pop()
		optionstab, optionsselection = tab, selection

		love.graphics.push()
		love.graphics.translate(direction * (1 - progress) * distance * scale, 0)
		options_drawtab()
		love.graphics.pop()
	end)
end

--the mappack menu's pages (local, dlc, daily challenge, minigames). Each page used to be drawn wherever
--mappackhorscrollsmooth put it; now mappackhorscrollsmooth is always a whole page, and switching pages slides
--the old page out and the new one in (easing in and out, like the options menu's tabs), cut to the page area
local MAPPACKPAGE_TIME = 0.25
--each page has two areas, and each one slides inside its own box: the list's box, and the panel right of it
local MAPPACKPAGE_Y, MAPPACKPAGE_H = 16, 200
local MAPPACKPAGE_LISTX, MAPPACKPAGE_LISTW, MAPPACKPAGE_PANELX = 21, 218, 241
local mappackpageanim --{from, to, direction, start} while sliding
local mappackpageshown --the page drawn last frame
local mappackpagecanvases = {}
local mappackpagequad --one area of a page's canvas

--{x, w} of each area, in game pixels
local function mappackpage_areas()
	return {
		{MAPPACKPAGE_LISTX, MAPPACKPAGE_LISTW},
		{MAPPACKPAGE_PANELX, width*16 - MAPPACKPAGE_PANELX - 9},
	}
end

--switches the slide on when mappackhorscroll changed (by a key, a click on a tab, or anything else).
--direction: 1 if the new page comes in from the right, -1 from the left, nil to work it out from the page numbers
function mappackpage_update()
	if gamestate ~= "mappackmenu" then
		mappackpageshown = nil --opening the menu shows its page straight away
		mappackpageanim = nil
		mappackpagedirection = nil
		mappackhorscrollsmooth = mappackhorscroll
		return
	end
	if mappackpageshown ~= nil and mappackhorscroll ~= mappackpageshown then
		local direction = mappackpagedirection
		if not direction then
			direction = 1
			if mappackhorscroll < mappackpageshown then
				direction = -1
			end
		end
		--the clock starts on the slide's first drawn frame: opening a page can stop the game for a moment first
		--(the dlc page downloads its list), and the slide shouldn't be over before it's seen
		mappackpageanim = {from = mappackpageshown, to = mappackhorscroll, direction = direction}
	end
	mappackpagedirection = nil
	mappackpageshown = mappackhorscroll
	mappackhorscrollsmooth = mappackhorscroll
	if mappackpageanim and mappackpageanim.start and love.timer.getTime() - mappackpageanim.start >= MAPPACKPAGE_TIME then
		mappackpageanim = nil
	end
end

------------------------------------------------------------
-- mappack lists (local and online)
-- every mappack is a button gui element (a mappack frame) and each list has a real scrollbar.
-- the mouse and the arrow keys share one selection, and only the selected frame looks hovered.
------------------------------------------------------------
local MAPPACKFRAME_X, MAPPACKFRAME_TOP, MAPPACKFRAME_SPACING = 25, 20, 60
local MAPPACKFRAME_WIDTH, MAPPACKFRAME_HEIGHT = 200, 58
local MAPPACKLIST_VISIBLE = 3.233 --how many frames fit in the box
local MAPPACKFRAME_CLIP = {16, 216} --the box the list shows in (game pixels, top and bottom)
local mappackgui = {}

--how many entries, the selected one, the scroll target and where the list is drawn right now
local function mappackgui_vars(kind)
	if kind == "online" then
		return onlineassetlist and #onlineassetlist or 0, onlinemappackselection or 1, onlinemappackscroll or 0, onlinemappackscrollsmooth or 0
	elseif kind == "minigames" then
		return minigamelist and #minigamelist or 0, minigameselection or 1, minigamescroll or 0, minigamescrollsmooth or 0
	end
	return mappacklist and #mappacklist or 0, mappackselection or 1, mappackscroll or 0, mappackscrollsmooth or 0
end

local function mappackgui_scrollrange(kind)
	local n = mappackgui_vars(kind)
	return math.max(0, n-MAPPACKLIST_VISIBLE)
end

--the list the current page shows, nil on the pages that aren't lists
function mappackgui_kind()
	if mappacktype == "local" or mappacktype == "online" or mappacktype == "minigames" then
		return mappacktype
	end
end

local function mappackgui_select(kind, i)
	if kind == "online" then
		onlinemappackselection = i
	elseif kind == "minigames" then
		if i ~= minigameselection then
			minigameselection = i
			minigame_updatescroll()
			minigame_buildgui()
			minigamepanelscroll = minigame_newpanelscroll()
			minigamescrollbars = {}
		end
	else
		mappackselection = i
	end
end

--click (or tap) on a frame: select it and open it, just like enter
local function mappackgui_press(kind, i)
	if mappackgui_kind() ~= kind then
		return
	end
	mappackgui_select(kind, i)
	menu_keypressed("return")
end

local function mappackframe_drawlocal(self, x, y)
	local i = self.index
	local selected = self.forcehover

	--icon, with round corners that follow the frame's (no border image)
	guiglass.beginround((x+4)*scale, (y+4)*scale, 50*scale, 50*scale, guiglass.insetradius(self, 4)*scale)
	love.graphics.setColor(255, 255, 255)
	if mappackicon and mappackicon[i] ~= nil then
		local scale2w = scale*50 / math.max(1, mappackicon[i]:getWidth())
		local scale2h = scale*50 / math.max(1, mappackicon[i]:getHeight())
		love.graphics.draw(mappackicon[i], (x+4)*scale, (y+4)*scale, 0, scale2w, scale2h)
	elseif i > (mappacklistthreadn or 0) and i ~= #mappacklist then
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", (x+4)*scale, (y+4)*scale, 50*scale, 50*scale)
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(mappackloadingicon, (x+4+25)*scale, (y+4+25)*scale, (coinanimation/5)*math.pi*2, scale, scale, 25, 25)
	else
		love.graphics.draw(mappacknoicon, (x+4)*scale, (y+4)*scale, 0, scale, scale)
	end
	guiglass.endround()

	--name
	if selected then
		love.graphics.setColor(255, 255, 255)
	else
		love.graphics.setColor(200, 200, 200)
	end
	properprint(string.sub(mappackname[i] or mappacklist[i]:lower(), 1, 17), (x+58)*scale, (y+6)*scale)

	--author
	love.graphics.setColor(100, 100, 100)
	if mappackauthor[i] then
		local by = TEXT["by"]
		if #by ~= utf8.len(by) then
			properprintF(string.sub(by .. " " .. mappackauthor[i], 1, 17), (x+58)*scale, (y+15)*scale)
		else
			properprint(string.sub(by .. " " .. mappackauthor[i], 1, 17), (x+58)*scale, (y+15)*scale)
		end
	end

	--description
	if selected then
		love.graphics.setColor(180, 180, 180)
	else
		love.graphics.setColor(130, 130, 130)
	end
	local description = mappackdescription[i]
	if description then
		properprint(string.sub(description, 1, 17), (x+58)*scale, (y+27)*scale)
		if description:len() > 17 then
			properprint(string.sub(description, 18, 34), (x+58)*scale, (y+36)*scale)
		end
		if description:len() > 34 then
			properprint(string.sub(description, 35, 51), (x+58)*scale, (y+45)*scale)
		end
	end
	love.graphics.setColor(255, 255, 255)
end

local function mappackframe_drawonline(self, x, y)
	local i = self.index
	local selected = self.forcehover
	local asset = onlineassetlist[i]

	--icon, with round corners that follow the frame's (no border image)
	guiglass.beginround((x+4)*scale, (y+4)*scale, 50*scale, 50*scale, guiglass.insetradius(self, 4)*scale)
	love.graphics.setColor(255, 255, 255)
	if asset.icon then
		local scale2w = scale*50 / math.max(1, asset.icon:getWidth())
		local scale2h = scale*50 / math.max(1, asset.icon:getHeight())
		love.graphics.draw(asset.icon, (x+4)*scale, (y+4)*scale, 0, scale2w, scale2h)
	else
		love.graphics.draw(mappackonlineicon, mappackonlineiconquad[1], (x+4)*scale, (y+4)*scale, 0, scale, scale)
	end
	guiglass.endround()

	--what kind of dlc it is
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
	love.graphics.draw(mappackonlineicon, mappackonlineiconquad[qi], (x+38)*scale, (y+6)*scale, 0, scale, scale)
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(mappackonlineicon, mappackonlineiconquad[qi], (x+38)*scale, (y+5)*scale, 0, scale, scale)

	--name
	if selected then
		love.graphics.setColor(255, 255, 255)
	else
		love.graphics.setColor(200, 200, 200)
	end
	properprint(string.sub(asset.name:lower(), 1, 17), (x+58)*scale, (y+6)*scale)

	--author
	love.graphics.setColor(100, 100, 100)
	if asset.author then
		local by = TEXT["by"]
		if #by ~= utf8.len(by) then
			properprintF(string.sub(by .. " " .. asset.author:lower(), 1, 17), (x+58)*scale, (y+15)*scale)
		else
			properprint(string.sub(by .. " " .. asset.author:lower(), 1, 17), (x+58)*scale, (y+15)*scale)
		end
	end

	--description (at most 3 lines of 17 characters, newlines start a new line)
	if selected then
		love.graphics.setColor(180, 180, 180)
	else
		love.graphics.setColor(130, 130, 130)
	end
	if asset.description then
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
		if line ~= "" and #lines < 3 then
			table.insert(lines, line)
		end
		for li = 1, #lines do
			properprint(lines[li], (x+58)*scale, (y+27+(li-1)*9)*scale)
		end
	end
	love.graphics.setColor(255, 255, 255)
end

local function mappackgui_get(kind)
	if not mappackgui[kind] then
		mappackgui[kind] = {frames = {}}
	end
	return mappackgui[kind]
end

local function mappackgui_frame(kind, i)
	local gui = mappackgui_get(kind)
	local frame = gui.frames[i]
	if not frame then
		--button(x, y, text, func, space, arguments, height (in lines), width): the box is (3+width) x (1+height*10)
		frame = guielement:new("button", MAPPACKFRAME_X, MAPPACKFRAME_TOP, "", function() mappackgui_press(kind, i) end,
			0, nil, (MAPPACKFRAME_HEIGHT-1)/10, MAPPACKFRAME_WIDTH-3)
		frame.index = i
		frame.forcehoveronly = true
		frame.clickswithinyrange = MAPPACKFRAME_CLIP
		if kind == "online" then
			frame.drawcontent = mappackframe_drawonline
		elseif kind == "minigames" then
			frame.drawcontent = minigame_frame_draw
		else
			frame.drawcontent = mappackframe_drawlocal
		end
		gui.frames[i] = frame
	end
	return frame
end

--dragging the scrollbar moves the list straight there, and keeps the selection on screen
local function mappackgui_drag(kind, value)
	local n, sel = mappackgui_vars(kind)
	local range = mappackgui_scrollrange(kind)
	local scroll = value*range
	if kind == "online" then
		onlinemappackscroll = scroll
		onlinemappackscrollsmooth = scroll
	elseif kind == "minigames" then
		minigamescroll = scroll
		minigamescrollsmooth = scroll
	else
		mappackscroll = scroll
		mappackscrollsmooth = scroll
	end
	sel = math.min(math.max(math.ceil(scroll), sel), math.ceil(scroll)+3)
	mappackgui_select(kind, math.max(1, math.min(n, sel)))
end

function mappackgui_scrollbar(kind)
	local gui = mappackgui_get(kind)
	if not gui.scrollbar then
		--scrollbar(x, y, range, width, height, start, dir)
		local scrollbar = guielement:new("scrollbar", 227, MAPPACKFRAME_TOP, 192, 8, 32, 0, "ver")
		scrollbar.scrollstepdisabled = true --the wheel moves the selection instead
		scrollbar.updatefunc = function(self, value)
			if mappackgui_scrollrange(kind) <= 0 then
				self.value = 0
			end
			mappackgui_drag(kind, self.value)
		end
		gui.scrollbar = scrollbar
	end
	return gui.scrollbar
end

--puts the frames on screen where the list is scrolled to, and works out which one is selected.
--returns the first and last frame that can be seen
function mappackgui_layout(kind)
	local n, sel, scroll, smooth = mappackgui_vars(kind)
	local offset = round(smooth*MAPPACKFRAME_SPACING*scale)/scale --whole screen pixels, so the text stays sharp
	local first, last = math.max(1, math.floor(smooth+1)), math.min(n, math.floor(smooth+5))
	for i = first, last do
		local frame = mappackgui_frame(kind, i)
		frame.y = MAPPACKFRAME_TOP+(i-1)*MAPPACKFRAME_SPACING-offset
		frame.forcehover = (i == sel)
		if kind == "online" then
			if downloadedmappacks[i] == true then
				frame.fillcolor = {0, 70, 0}
			elseif downloadedmappacks[i] == false then
				frame.fillcolor = {70, 0, 0}
			else
				frame.fillcolor = {0, 0, 0}
			end
		end
	end
	return first, last
end

function mappackgui_update(dt)
	for _, kind in ipairs({"local", "online", "minigames"}) do
		local gui = mappackgui[kind]
		if gui and gui.scrollbar then
			local scrollbar = gui.scrollbar
			scrollbar.active = (mappackgui_kind() == kind)
			scrollbar:update(dt)
			if not scrollbar.dragging then
				--follow the list as it eases to where it's going
				local range = mappackgui_scrollrange(kind)
				local _, _, _, smooth = mappackgui_vars(kind)
				if range > 0 then
					scrollbar.value = math.max(0, math.min(1, smooth/range))
				else
					scrollbar.value = 0
				end
			end
		end
	end
end

function mappackgui_draw(kind)
	local first, last = mappackgui_layout(kind)
	for i = first, last do
		mappackgui_frame(kind, i):draw()
	end
	mappackgui_scrollbar(kind):draw()
end

function mappackgui_mousepressed(x, y, button)
	local kind = mappackgui_kind()
	if not kind then
		return false
	end
	if mappackgui_scrollbar(kind):click(x, y, button) or mappackgui_scrollbar(kind).dragging then
		return true
	end
	if android then
		return false
	end
	local first, last = mappackgui_layout(kind)
	for i = first, last do
		if mappackgui_frame(kind, i):click(x, y, button) then
			return true
		end
	end
	return false
end

function mappackgui_mousereleased(x, y)
	for _, gui in pairs(mappackgui) do
		if gui.scrollbar then
			gui.scrollbar:unclick(x, y)
		end
		for _, frame in pairs(gui.frames) do
			frame:unclick(x, y)
		end
	end
end

--the frame under the mouse becomes the selected one
function mappackgui_mousemoved(x, y)
	local kind = mappackgui_kind()
	if not kind or android or mappackgui_scrollbar(kind).dragging then
		return
	end
	local first, last = mappackgui_layout(kind)
	for i = first, last do
		if mappackgui_frame(kind, i):inhighlight(x, y) then
			mappackgui_select(kind, i)
		end
	end
end

--every page, drawn where it sits when it's open (only the page mappackhorscrollsmooth is on gets drawn)
local function mappackmenu_drawpages()
	love.graphics.translate(-round(mappackhorscrollsmooth*scale*mappackhorscrollrange), 0)
	
	--mappacks
	if mappackhorscrollsmooth < 1 then
		love.graphics.setScissor(21*scale, 16*scale, 218*scale, 200*scale)
		
		--every mappack is a mappack frame (a button), with a real scrollbar next to them
		mappackgui_draw("local")
	
		if mappackhorscrollsmooth <= 0.01 then
			love.graphics.setScissor()
			guiglass.box(241*scale, 125*scale, 150*scale, 75*scale, 4*scale, 1, {rimstrength = 0.55})
			love.graphics.setColor(255, 255, 255, 255)
			if savefolderfailed then
				properprintF(TEXT["mappack folder fail"], 244*scale, 129*scale)
			else
				properprintF(TEXT["mappack folder instructions"], 244*scale, 129*scale)
			end
			openmappacksbutton:draw()
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
			guiglass.box(241*scale, 16*scale, 150*scale, 180*scale, 4*scale, 1, {rimstrength = 0.55})
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
		
		--every dlc is a mappack frame (a button), with a real scrollbar next to them
		mappackgui_draw("online")
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
	
	-------------
	--MINIGAMES--
	-------------
	
	love.graphics.translate(round(((mappackhorscrollrange*scale)*3) - mappackhorscrollsmooth*scale*mappackhorscrollrange), 0)
	
	if mappackhorscrollsmooth > 2 then
		minigame_menu_draw()
	end
	love.graphics.setScissor()
	
	love.graphics.translate(- (round(((mappackhorscrollrange*scale)*3) - mappackhorscrollsmooth*scale*mappackhorscrollrange)), 0)
end

--one page drawn on its own canvas, the size of what's being drawn to, exactly as it looks when it's open.
--A canvas keeps the page's own clipping (its list, its panels) out of the way of the slide
local function mappackmenu_pagecanvas(slot, page)
	local target = love.graphics.getCanvas()
	local cw, ch = love.graphics.getDimensions()
	if target then
		cw, ch = target:getDimensions()
	end
	local c = mappackpagecanvases[slot]
	if not c or c:getWidth() ~= cw or c:getHeight() ~= ch then
		c = love.graphics.newCanvas(cw, ch)
		mappackpagecanvases[slot] = c
	end
	local smooth = mappackhorscrollsmooth
	local ox, oy, ow, oh = love.graphics.getScissor()
	love.graphics.setCanvas({c, stencil = true})
	love.graphics.setScissor() --clear only clears inside the clip, and the whole canvas has to be emptied
	love.graphics.clear(0, 0, 0, 0)
	--the same clip the pages start with on screen (the list's box), set just before they're drawn
	if ox then
		love.graphics.setScissor(ox, oy, ow, oh)
	else
		love.graphics.setScissor()
	end
	mappackhorscrollsmooth = page
	love.graphics.push("all")
	mappackmenu_drawpages()
	love.graphics.pop()
	mappackhorscrollsmooth = smooth
	if target then
		love.graphics.setCanvas({target, stencil = true})
	else
		love.graphics.setCanvas()
	end
	if ox then
		love.graphics.setScissor(ox, oy, ow, oh)
	else
		love.graphics.setScissor()
	end
	return c
end

function mappackmenu_drawslide()
	local anim = mappackpageanim
	local t = 1
	if anim then
		if not anim.start then
			anim.start = love.timer.getTime()
		end
		t = (love.timer.getTime() - anim.start)/MAPPACKPAGE_TIME
	end
	if not anim or t >= 1 then
		mappackmenu_drawpages()
		return
	end

	local p = ease_out_quad(t)
	local oldcanvas = mappackmenu_pagecanvas(1, anim.from)
	local newcanvas = mappackmenu_pagecanvas(2, anim.to)

	--each area is cut to its own box (wherever the current transform puts it), and slides by its own width
	local boxes = {}
	for i, area in ipairs(mappackpage_areas()) do
		local sx1, sy1 = love.graphics.transformPoint(area[1]*scale, MAPPACKPAGE_Y*scale)
		local sx2, sy2 = love.graphics.transformPoint((area[1]+area[2])*scale, (MAPPACKPAGE_Y+MAPPACKPAGE_H)*scale)
		boxes[i] = {math.floor(sx1), math.floor(sy1), math.max(0, math.ceil(sx2-sx1)), math.max(0, math.ceil(sy2-sy1)), area[2]}
	end
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.setBlendMode("alpha", "premultiplied") --the canvases already hold blended colours
	local cw, ch = oldcanvas:getDimensions()
	mappackpagequad = mappackpagequad or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
	for _, box in ipairs(boxes) do
		local bx, by, bw, bh, distance = box[1], box[2], box[3], box[4], box[5]
		love.graphics.setScissor(bx, by, bw, bh)
		--only this area of each page, so the list and the panel never slide into each other's box
		mappackpagequad:setViewport(bx, by, bw, bh, cw, ch)
		love.graphics.draw(oldcanvas, mappackpagequad, bx - anim.direction*p*distance*scale, by)
		love.graphics.draw(newcanvas, mappackpagequad, bx + anim.direction*(1-p)*distance*scale, by)
	end
	love.graphics.pop()
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
					if tilequads[backgroundtile] then 
						love.graphics.draw(tilequads[backgroundtile].image, tilequads[backgroundtile].quad, math.floor((x-1)*16*scale), ((y-1)*16-8)*scale, 0, scale, scale)
					else
						print("background tile doesn't exist:",backgroundtile)
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
	
	if utilsmenuopen then
		utilsmenu_draw()
	elseif gamestate == "menu" then
		local x = (40-8*((titlewidth-176)/24))--position of title logo
		love.graphics.draw(titleimage, titlequad[titleframe], x*scale, 24*scale, 0, scale, scale)
		
		love.graphics.setColor(255, 255, 255)
		properprintF("©2012-2024 maurice", (x+titlewidth-144)*scale, 112*scale)
		love.graphics.setColor(255, 255, 255, 255)
		
		if selection == 0 then
			love.graphics.draw(menuselectimg, (129-(math.ceil((utf8.len(TEXT["continue game"]))/2)*8))*scale, (titlemenuy(selection)-1)*scale, 0, scale, scale)
		elseif selection == 1 then
			love.graphics.draw(menuselectimg, (134-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8)-5)*scale, (titlemenuy(selection)-1)*scale, 0, scale, scale)
		elseif selection == 2 then
			love.graphics.draw(menuselectimg, (129-(math.ceil((utf8.len(TEXT["level editor"]))/2)*8))*scale, (titlemenuy(selection)-1)*scale, 0, scale, scale)
		elseif selection == 3 then
			love.graphics.draw(menuselectimg, (129-(math.ceil((utf8.len(TEXT["select mappack"]))/2)*8))*scale, (titlemenuy(selection)-1)*scale, 0, scale, scale)
		elseif selection == 4 then
			love.graphics.draw(menuselectimg, (129-(math.ceil((utf8.len(TEXT["options"]))/2)*8))*scale, (titlemenuy(selection)-1)*scale, 0, scale, scale)
		elseif selection == 5 then
			love.graphics.draw(menuselectimg, (129-(math.ceil((utf8.len(TEXT["utils"]))/2)*8))*scale, (titlemenuy(selection)-1)*scale, 0, scale, scale)
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
				properprintfunc(TEXT["continue game"], (143-(math.ceil(utf8.len(TEXT["continue game"])/2)*8))*scale, titlemenuy(0)*scale)
			end
			
			if i == 9 then if mouseonselecthold and mouseonselect == 1 then love.graphics.setColor(188, 188, 188) else love.graphics.setColor(255, 255, 255) end end
			properprintfunc(TEXT["player game"], (143-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8)+16)*scale, titlemenuy(1)*scale)
			
			properprintfunc(players, (143-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8))*scale, titlemenuy(1)*scale)
			if i == 9 then if (mouseonselecthold and mouseonselect == 2) then love.graphics.setColor(188, 188, 188) else love.graphics.setColor(255, 255, 255) end end
			properprintfunc(TEXT["level editor"], (143-(math.ceil(utf8.len(TEXT["level editor"])/2)*8))*scale, titlemenuy(2)*scale)
			
			if i == 9 then if mouseonselecthold and mouseonselect == 3 then love.graphics.setColor(188, 188, 188) else love.graphics.setColor(255, 255, 255) end end
			properprintfunc(TEXT["select mappack"], (143-(math.ceil(utf8.len(TEXT["select mappack"])/2)*8))*scale, titlemenuy(3)*scale)
			
			if i == 9 then if mouseonselecthold and mouseonselect == 4 then love.graphics.setColor(188, 188, 188) else love.graphics.setColor(255, 255, 255) end end
			properprintfunc(TEXT["options"], (143-(math.ceil(utf8.len(TEXT["options"])/2)*8))*scale, titlemenuy(4)*scale)
			
			if i == 9 then if mouseonselecthold and mouseonselect == 5 then love.graphics.setColor(188, 188, 188) else love.graphics.setColor(255, 255, 255) end end
			properprintfunc(TEXT["utils"], (143-(math.ceil(utf8.len(TEXT["utils"])/2)*8))*scale, titlemenuy(5)*scale)
			
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
			love.graphics.draw(playerselectarrowimg, (138-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8))*scale, titlemenuy(1)*scale, 0, scale, scale)
		end
		
		if players < 4 then
			love.graphics.draw(playerselectarrowimg, (158-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8))*scale, titlemenuy(1)*scale, 0, -scale, scale)
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
            guiglass.box(20*scale, 92*scale, 220*scale, 60*scale, popupradius, 1)
            love.graphics.setColor(255, 255, 255)
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
			guiglass.box(20*scale, 92*scale, 220*scale, 60*scale, popupradius, 1)
			love.graphics.setColor(255, 255, 255)
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
                        cursorprogress = ease_out_quad(cursorprogress)
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
                local scrollprogress = ease_out_quad(scrollrawprogress)
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
			--the open page, or while switching pages, the old one sliding out and the new one sliding in
			mappackmenu_drawslide()
		end
		
		love.graphics.setScissor()
		
		--draw tabs
		local colors = {}
		for i = 0, 3 do
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
		--minigames
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("fill", 232*scale, 3*scale, 77*scale, 13*scale)
		love.graphics.setColor(colors[3][1])
		love.graphics.rectangle("fill", 233*scale, 4*scale, 75*scale, 11*scale)
		love.graphics.setColor(colors[3][2])
		properprint("minigames", 234*scale, 6*scale)
		
		--an open minigame settings dropdown goes over the tabs
		if mappacktype == "minigames" then
			minigame_menu_drawdropdown()
		end
		
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
		
		--the open tab, or the two tabs sliding past each other
		options_drawpages()
		optionscontrols_drawresetnote()
	end
	resetwarning_draw()
	love.graphics.translate(0, yoffset*scale)
	
	if languagemenu_visible() then
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
	
	if love.filesystem.getInfo(mappackfolder .. "/" .. mappack .. "/" .. background) then
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
	else
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
	--reset button hover animation progress so the selected frame animates in cleanly
	for _, kind in ipairs({"local", "online", "minigames"}) do
		local gui = mappackgui[kind]
		if gui and gui.frames then
			for _, frame in pairs(gui.frames) do
				frame.hoveranim = nil
				frame.hoverscale = 1
				frame.lasthigh = false
				frame.pressanim = nil
			end
		end
	end
	for _, btn in ipairs({openmappacksbutton, opendlcbutton}) do
		if btn then
			btn.hoveranim = nil
			btn.hoverscale = 1
			btn.lasthigh = false
			btn.pressanim = nil
		end
	end

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
	elseif mappackhorscroll == 3 then
		loadminigames()
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
	if resetwarningopen then
		resetwarning_keypressed(key)
		return
	end
	if utilsmenuopen then
		utilsmenu_keypressed(key)
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
			if selection < 5 then
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
				optionsmenu_resettab()
				gamestate = "options"
			elseif selection == 5 then
				utilsmenu_open()
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
		if mappacktype == "minigames" and minigame_menu_keypressed(key) then
			return
		end
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
				love.draw()
				love.graphics.present()
				
				if asset.download then
					if asset.downloadable then
						onlinemappackerror = not downloadasset(asset)
						if onlinemappackerror then
							downloadedmappacks[i] = false
							notice.new(TEXT["Download failed"], notice.red, 2)
						else
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
						end
					else
						--link
						if love.system.openURL(asset.download.url) then
							notice.new(TEXT["Opened Download Link"], nil, 2)
						else
							love.system.setClipboardText(asset.download.url)
							notice.new(TEXT["Couldn't Open Link\nLink copied to clipboard"], notice.red, 3)
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
				mappackpagedirection = 1
			else
				mappackhorscroll = mappackhorscroll - 1
				mappackpagedirection = -1
			end
			if mappackhorscroll > 3 then
				mappackhorscroll = 0
			elseif mappackhorscroll < 0 then
				mappackhorscroll = 3
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
		if dropdown and key == "escape" then
			--escape closes the open list instead of leaving the options
			dropdown:close()
			return
		end
		if dropdown and optionstab == 2 then
			--the other keys would change what's under the open list
			return
		end

		-- F6: selected keybind to default; Ctrl+F6: full page reset / clear / copy
		if optionstab == 1 and not keyprompt and key == "f6" then
			if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
				optionscontrols_resetbindings()
			elseif optionsselection >= 5 then
				if optionscontrols_reset_selected_binding() then
					notice.new("keybind reset to default", nil, 2)
				end
			else
				notice.new("select a keybind first\nthen press f6 to reset it", nil, 3)
			end
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
					options_switchtab(optionstab - 1)
				end
			elseif (key == "right" or key == "d") then
				if optionstab < 4 then
					options_switchtab(optionstab + 1)
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
			elseif optionstab == 2 then
				optionsskins_activate(optionsselection)
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
				if skins_hascolorables() then
					limit = 10
				end

				if optionsselection < limit then
					optionsselection = optionsselection + 1
				else
					optionsselection = 1
				end
			elseif optionstab == 3 then
				if optionsselection < 13 then
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
					if skins_hascolorables() then
						limit = 10
					end
					optionsselection = limit
				elseif optionstab == 3 then
					optionsselection = 13
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
						optionsskins_setcharacter(characteri)
					end
				elseif optionsselection == 4 and not (mariocharacter[skinningplayer] and not characters.data[mariocharacter[skinningplayer]].hats) then
					if mariohats[skinningplayer][1] == nil then
						mariohats[skinningplayer][1] = 1
					elseif mariohats[skinningplayer][1] < #hat then
						mariohats[skinningplayer][1] = mariohats[skinningplayer][1] + 1
					end
					saveconfig()
				elseif skins_hascolorables() and optionsselection == 5 then
					--next color set
					colorsetedit = colorsetedit + 1
					if colorsetedit > #characters.data[mariocharacter[skinningplayer]].colorables then
						colorsetedit = 1
					end
				end
			elseif optionstab == 3 then
				if optionsselection == 2 then
					volumeslider_step(guielements["opt_deadzone"], 0.05)
				elseif optionsselection == 3 then
					if resizable then
					elseif scale < 5 then
						changescale(scale+1)
					end
					saveconfig()
				elseif optionsselection == 4 then
					letterboxfullscreen = not letterboxfullscreen
					saveconfig()
				elseif optionsselection == 5 then
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
					
				elseif optionsselection == 6 then
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
					
				elseif optionsselection == 7 then
					volumeslider_step(guielements["opt_volume"], 0.1)
				elseif optionsselection == 12 then
					vsync = not vsync
					changescale(scale)
					saveconfig()
				elseif optionsselection == 13 then
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
						optionsskins_setcharacter(characteri)
					end
				elseif optionsselection == 4 and not (mariocharacter[skinningplayer] and not characters.data[mariocharacter[skinningplayer]].hats) then
					if mariohats[skinningplayer][1] == 1 then
						mariohats[skinningplayer] = {}
					elseif mariohats[skinningplayer][1] and mariohats[skinningplayer][1] > 1 then
						mariohats[skinningplayer][1] = mariohats[skinningplayer][1] - 1
					end
					saveconfig()
				elseif skins_hascolorables() and optionsselection == 5 then
					--previous color set
					colorsetedit = colorsetedit - 1
					if colorsetedit < 1 then
						colorsetedit = #characters.data[mariocharacter[skinningplayer]].colorables
					end
				end
			elseif optionstab == 3 then
				if optionsselection == 2 then
					volumeslider_step(guielements["opt_deadzone"], -0.05)
				elseif optionsselection == 3 then
					if resizable then
						changescale(4)
					elseif scale > 1 then
						changescale(scale-1)
					end
					saveconfig()
				elseif optionsselection == 4 then
					letterboxfullscreen = not letterboxfullscreen
					saveconfig()
				elseif optionsselection == 5 then
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

				elseif optionsselection == 6 then
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
					
				elseif optionsselection == 7 then
					volumeslider_step(guielements["opt_volume"], -0.1)
				elseif optionsselection == 12 then
					vsync = not vsync
					changescale(scale)
					saveconfig()
				elseif optionsselection == 13 then
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
			optionsmenu_resettab()
			gamestate = "menu"
			saveconfig()
		end
	end
end

function menu_keyreleased(key, unicode)
	local colorables = skins_hascolorables()
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
	if resetwarningopen then
		resetwarning_mousepressed(x, y, button)
		return
	end
	if gamestate == "utils" then
		utilsmenu_mousepressed(x, y, button)
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
		if mappacktype == "minigames" and (button == "wu" or button == "wd") and minigame_menu_wheel(x, y, button) then
			return
		end
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
				elseif x > 233*scale and x < 308*scale then
					mappackhorscroll = 3
				end
				if oldmappackhorscroll ~= mappackhorscroll then
					openmappacksbutton.active = false
					opendlcbutton.active = false
					mappacks()
					return
				end
			end
			if mappacktype == "minigames" then
				if minigame_menu_mousepressed(x, y, button) then
					return
				end
			end
			--mappack frames and the scrollbar
			if mappacktype == "daily_challenge" then
				if not android then
					menu_keypressed("return")
				end
			else
				mappackgui_mousepressed(x, y, button)
			end
		end
	end
end

function menu_mousereleased(x, y, button)
	if languagemenuopen then
		return
	end
	if gamestate == "utils" then
		utilsmenu_mousereleased(x, y, button)
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
				optionsmenu_resettab()
				gamestate = "options"
			elseif mouseonselect == 5 then
				utilsmenu_open()
			end
		end
		mouseonselecthold = false
	elseif gamestate == "mappackmenu" then
		mappackgui_mousereleased(x, y)
		mappacksearchbar:unclick(x, y)
		if mappacktype == "minigames" then
			minigame_menu_mousereleased(x, y, button)
		end
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
	if gamestate == "utils" then
		utilsmenu_mousemoved(x, y)
		return
	end
	if gamestate == "mappackmenu" then
		if mappacktype == "minigames" then
			minigame_menu_mousemoved(x, y)
		end
		--the frame under the mouse is the selected one (the scrollbar drags itself in mappackgui_update)
		mappackgui_mousemoved(x, y)
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
	axiserror = false
	--any joystick input (button, hat or axis) can go on any control. Only the keyboard can't aim, since a key has no axis
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
			controlset[skinningplayer][controlname] = {"joy", arg[1], "but", arg[2]}
		elseif t == "joyhat" then
			controlset[skinningplayer][controlname] = {"joy", arg[1], "hat", arg[2], arg[3]}
		elseif t == "joyaxis" then
			controlset[skinningplayer][controlname] = {"joy", arg[1], "axe", arg[2], arg[3]}
		end
	end
	
	if not axiserror or arg[1] == "escape" then
		setmenupopupvisible("keyprompt", false)
	end
end

function keypromptstart()
	keypromptpage = keybindpage
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

	setmenupopupvisible("keyprompt", true)
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
            previousselectworldx = nil
        else
            previousselectworldx = 55 + (selectworldcursor-currentpage)*20
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

--the options menu always opens and closes on its first tab (the same one menu_load starts on)
function optionsmenu_resettab()
	optionstab = 2
	optionsselection = 1 --a row from another tab could be past the end of this one
	optionspageanimation = nil
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
	--no slide or page scroll left over from the last time it was open, the cursor just drops in
	previousselectworldx = nil
	selectworldpreviouspage = nil
	selectworldscrollstart = nil
	
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
	if gamestate == "utils" then
		utilsmenu_filedropped(file)
		return
	end
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
			if x > (143-(math.ceil(utf8.len(TEXT["continue game"])/2)*8)) and y > titlemenuy(0) and x < (143+(math.ceil(utf8.len(TEXT["continue game"])/2)*8)) and y < titlemenuy(0)+8 then
				selection = 0
				mouseonselect = 0
			end
		end
		--player game
		if x > (143-(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8)) and y > titlemenuy(1) and x < (143+(math.ceil((utf8.len(TEXT["player game"])+2)/2)*8)) and y < titlemenuy(1)+8 then
			selection = 1
			mouseonselect = 1
		end
		--level editor
		if x > (143-(math.ceil(utf8.len(TEXT["level editor"])/2)*8)) and y > titlemenuy(2) and x < (143+(math.ceil(utf8.len(TEXT["level editor"])/2)*8)) and y < titlemenuy(2)+8 then
			selection = 2
			mouseonselect = 2
		end
		--select mappack
		if x > (143-(math.ceil(utf8.len(TEXT["select mappack"])/2)*8)) and y > titlemenuy(3) and x < (143+(math.ceil(utf8.len(TEXT["select mappack"])/2)*8)) and y < titlemenuy(3)+8 then
			selection = 3
			mouseonselect = 3
		end
		--options
		if x > (143-(math.ceil(utf8.len(TEXT["options"])/2)*8)) and y > titlemenuy(4) and x < (143+(math.ceil(utf8.len(TEXT["options"])/2)*8)) and y < titlemenuy(4)+8 then
			selection = 4
			mouseonselect = 4
		end
		--utils
		if x > (143-(math.ceil(utf8.len(TEXT["utils"])/2)*8)) and y > titlemenuy(5) and x < (143+(math.ceil(utf8.len(TEXT["utils"])/2)*8)) and y < titlemenuy(5)+8 then
			selection = 5
			mouseonselect = 5
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

require("utilsmenu")

--title screen menu layout: "1 player game" stays at TITLEMENU_TOP and every item is TITLEMENU_SPACING below the last,
--so the last item (utils) ends where options used to (0 = continue game, 1 = player game ... 5 = utils)
TITLEMENU_TOP = 138
TITLEMENU_SPACING = 12
function titlemenuy(i)
	return TITLEMENU_TOP + (i-1)*TITLEMENU_SPACING
end

function brprint(text, y)
	properprintFbackground(text, (width*16-#(text)*8-8)*scale, y*scale)
end

function drawcontrolsoverlay()
	local now = love.timer.getTime()
	local controlspopupscale = menupopupscale("controls", now)
	if not (controlsopen or controlspopupscale > 0) then
		return
	end

	local winwidth, winheight = getproperwindowsize()
	-- Animated alpha for the foreground (dim behind the overlay)
	local dimalpha = controlspopupscale * 180
	love.graphics.setColor(0, 0, 0, dimalpha)
	love.graphics.rectangle("fill", 0, 0, winwidth, winheight)

	love.graphics.push()
	local cx, cy = winwidth / 2, winheight / 2
	love.graphics.translate(cx, cy)
	love.graphics.scale(controlspopupscale, controlspopupscale)
	love.graphics.translate(-cx, -cy)

	local popupx, popupy, popupw, popuph, offsetx, offsety = controlspopup_geometry()
	local popupradius = get_corner_radius(popupw, popuph) / 2

	guiglass.box(popupx, popupy, popupw, popuph, popupradius, 1)
	love.graphics.setColor(255, 255, 255)

	-- Title, and the f6 note right of the popup with its middle halfway down the screen (like in the options menu)
	properprintF("controls:", (winwidth/2 - 36*scale), popupy + 3*scale)
	local notex = popupx + popupw + 2*scale
	optionscontrols_drawnotebox(notex, winwidth - notex - 9*scale, winheight/2, 1)
	love.graphics.setColor(255, 255, 255, 255)

	-- Draw the controls content (repositioned, the widgets are laid out like in the options menu)
	love.graphics.push()
	love.graphics.translate(offsetx, offsety)

	-- the key bindings (clipped, they slide sideways when the page changes)
	love.graphics.setScissor(popupx + 4*scale, popupy + 38*scale, popupw - 8*scale, popuph - 46*scale)
	local pageviews = optionscontrols_pageviews()
	for i = 1, #pageviews do
		optionscontrols_draw_page(pageviews[i].page, pageviews[i].offset)
	end
	love.graphics.setScissor()

	-- labels of the widgets at the top (the options menu draws these itself)
	if optionsselection == 2 then
		love.graphics.setColor(255, 255, 255, 255)
	else
		love.graphics.setColor(100, 100, 100, 255)
	end
	properprintF(TEXT["edit player:"], 30*scale, 40*scale)

	if optionsselection == 3 then
		love.graphics.setColor(255, 255, 255, 255)
	else
		love.graphics.setColor(100, 100, 100, 255)
	end
	properprintF(TEXT["uses the mouse:"], 30*scale, 52*scale)

	if optionsselection == 4 then
		love.graphics.setColor(255, 255, 255, 255)
	else
		love.graphics.setColor(100, 100, 100, 255)
	end
	local currentbindlabel = TEXT["current bind:"]
	local bindgroupwidth = utf8.len(currentbindlabel) * 8 + 4 + 21
	properprintF(currentbindlabel, (130 - bindgroupwidth/2)*scale, 66*scale)

	-- player, mouse and bind page widgets (drawn last so an open dropdown is on top)
	optionscontrols_draw(nil, false, true)

	-- waiting for a key / button to bind
	local now = love.timer.getTime()
	local keypromptscale = menupopupscale("keyprompt", now)
	if keyprompt or keypromptscale > 0 then
		love.graphics.push()
		love.graphics.translate(130*scale, 130*scale)
		love.graphics.scale(keypromptscale, keypromptscale)
		love.graphics.translate(-130*scale, -130*scale)

		local progress = keypromptscale
		love.graphics.translate(0, (1 - progress) * 8 * scale)

		local popupradius = math.min(200, 60) * scale * 0.2
		guiglass.box(30*scale, 100*scale, 200*scale, 60*scale, popupradius, 1)
		love.graphics.setColor(255, 255, 255)
		local controlname = optionscontrols_controlnames[optionsselection-4]
		if controlname == "aimx" then
			properprintF(TEXT["move stick right"], 40*scale, 110*scale)
		elseif controlname == "aimy" then
			properprintF(TEXT["move stick down"], 40*scale, 110*scale)
		elseif controlname then
			properprintF(TEXT["press key for '"] .. TEXT[controlname] .. "'", 40*scale, 110*scale)
		end
		local escapetext = TEXT["press 'esc' to cancel"]
		if keypromptpage > 1 then
			escapetext = TEXT["press 'esc' to clear"]
		end
		properprintF(escapetext, 40*scale, 140*scale)

		if axiserror then
			love.graphics.setColor(200, 0, 0)
			properprintF(TEXT["you can only set"], 40*scale, 120*scale)
			properprintF(TEXT["axes for this"], 40*scale, 130*scale)
		end
		love.graphics.pop()
	end
	love.graphics.pop()

	-- how to leave
	if not keypromptvisible() then
		local hint = "esc: back"
		love.graphics.setColor(100, 100, 100, 255)
		properprintF(hint, popupx + (popupw - utf8.len(hint)*8*scale)/2, popupy + popuph - 12*scale)
	end

	love.graphics.pop()
end

--called every frame from game_update: keeps the widgets of the pause menu's controls popup in sync (selection highlight, which ones can be used)
--and removes them again once the popup has closed so they stop reacting to the mouse and keys
function controlspopup_update()
	if controlsopen then
		if not pausemenuopen then
			setmenupopupvisible("controls", false)
			return
		end
		if not guielements["ctrl_player"] then
			optionscontrols_create()
		end
		optionscontrols_sync()
	elseif guielements["ctrl_player"] and menupopupscale("controls", love.timer.getTime()) == 0 then
		optionscontrols_remove()
	end
end

--keyboard / controller input for the pause menu's controls popup (controller buttons and sticks arrive as up, down, left, right, return and escape)
function controlspopup_keypressed(key)
	if keyprompt then
		return --the next key or button gets bound, see love.keypressed
	end

	local dropdown = guielement.getopendropdown()
	if key == "escape" then
		if dropdown then
			dropdown:close()
		else
			setmenupopupvisible("controls", false)
		end
		return
	end

	if menupopupscale("controls", love.timer.getTime()) < 1 then
		return --still opening
	end

	if dropdown then
		--keys that skip love.keypressed (controller buttons) still belong to an open dropdown
		dropdown:keypress(key)
		return
	end

	if key == "f6" then
		if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
			optionscontrols_resetbindings()
		elseif optionsselection >= 5 then
			if optionscontrols_reset_selected_binding() then
				notice.new("keybind reset to default", nil, 2)
			end
		else
			notice.new("select a keybind first\nthen press f6 to reset it", nil, 3)
		end
		return
	end

	--left / right on the bind page row or a binding flips the page
	if optionsselection >= 4 and (key == "left" or key == "right" or key == "a" or key == "d") then
		if optionscontrols_change_page((key == "left" or key == "a") and -1 or 1) then
			return
		end
	end

	if optionsselection == 2 then
		--left / right on the player row changes the player
		if key == "left" or key == "a" then
			if skinningplayer > 1 then
				skinningplayer = skinningplayer - 1
			end
		elseif key == "right" or key == "d" then
			if skinningplayer < 4 then
				skinningplayer = skinningplayer + 1
			end
		end
		if characters.data[mariocharacter[skinningplayer]] then
			characteri = characters.data[mariocharacter[skinningplayer]].i
		end
	end

	if key == "return" or key == "enter" or key == "kpenter" or key == " " then
		optionscontrols_activate(optionsselection)
	elseif key == "down" or key == "s" then
		if optionsselection < optionscontrols_lastselection() then
			optionsselection = optionsselection + 1
		else
			optionsselection = 2
		end
	elseif key == "up" or key == "w" then
		if optionsselection > 2 then
			optionsselection = optionsselection - 1
		else
			optionsselection = optionscontrols_lastselection()
		end
	end
end

--a click outside of the pause menu's controls popup closes it
function controlspopup_mousepressed(x, y, button)
	if not controlsopen or keyprompt or button ~= "l" or guielement.getopendropdown() then
		return
	end
	if menupopupscale("controls", love.timer.getTime()) < 1 then
		return
	end

	local popupx, popupy, popupw, popuph = controlspopup_geometry()
	if x < popupx or x >= popupx + popupw or y < popupy or y >= popupy + popuph then
		setmenupopupvisible("controls", false)
	end
end