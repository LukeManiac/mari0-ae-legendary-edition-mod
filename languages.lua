--Languages use .lua files inside the languages folder
--English is default, any missing strings in the language file will fallback to English
function set_language(lang)
	local s = love.filesystem.read("languages/english.json")
	TEXT = JSON:decode(s)
	s = nil

	if lang ~= "english" then
		if love.filesystem.getInfo("languages/" .. lang .. ".json") then
			local s = love.filesystem.read("languages/" .. lang .. ".json")
			local t = JSON:decode(s)
			for j, w in pairs(t) do
				TEXT[j] = w
			end
		else
			CurrentLanguage = "english"
		end
	end
end
set_language("english")

local Languages, LanguageCount
local LanguageList --the languages in a fixed order: {name = file name, display = shown name}
local sel = 1
local languagemenu_select

--opening and closing animate like the pause menu prompts (drawprompt in game.lua)
local languagemenushown = false --open as far as the animation knows, set by languagemenu_open/languagemenu_update
local languagemenutimer = 0
local languagemenuduration = pausemenuduration

local function languagemenu_lines()
	return {TEXT["language"] or "language"}
end

local function languagemenu_options()
	local options = {}
	for i, t in ipairs(LanguageList) do
		options[i] = t.display
	end
	return options
end

function languagemenu_open()
	--Load list of languages
	if not Languages then
		Languages = {}
		LanguageCount = 0
		local files = love.filesystem.getDirectoryItems("languages")
		for num, filename in pairs(files) do
			if string.sub(filename, -5, -1) == ".json" and string.sub(filename, 1, -6) ~= "names" then
				Languages[string.sub(filename, 1, -6)] = {name=string.sub(filename, 1, -6)}
				LanguageCount = LanguageCount + 1
			end
		end
		--Load Names
		local s = love.filesystem.read("languages/names.json")
		local t = JSON:decode(s)
		for j, w in pairs(t) do
			if Languages[j] then
				Languages[j].name = w
			end
		end
		LanguageList = {}
		for name, t in pairs(Languages) do
			table.insert(LanguageList, {name = name, display = t.name})
		end
		table.sort(LanguageList, function(a, b) return a.display:lower() < b.display:lower() end)
	end

	if not CurrentLanguage then
		CurrentLanguage = "english"
	end
	--Find Current Selection
	sel = 1
	for i, t in ipairs(LanguageList) do
		if t.name == CurrentLanguage then
			sel = i
			break
		end
	end
	languagemenushown = true
end
--open: whether the menu is open right now (it keeps drawing while it shrinks away after closing)
function languagemenu_update(dt, open)
	languagemenushown = (open == true)
	local direction = 1
	if not languagemenushown then
		direction = -1
	end
	languagemenutimer = math.max(0, math.min(languagemenutimer + dt*direction, languagemenuduration))
end
function languagemenu_visible()
	return languagemenushown or languagemenutimer > 0
end
function languagemenu_draw()
	if not LanguageList or not languagemenu_visible() then
		return
	end
	local lines, options = languagemenu_lines(), languagemenu_options()
	drawprompt(languagemenutimer, languagemenuduration, languagemenushown, #lines + #options)
	drawpromptcontent(lines, options, sel)
	love.graphics.pop()
end
function languagemenu_keypressed(key)
	local moved
	sel, moved = promptnavigate(key, sel, LanguageCount)
	if moved then
		return
	end
	if (key == "return" or key == "enter" or key == "kpenter" or key == " ") then
		return languagemenu_select()
	elseif key == "escape" then
		return true
	end
end
function languagemenu_mousepressed(mx, my, button)
	local i = promptoptionat(mx, my, languagemenu_lines(), languagemenu_options())
	if i then
		sel = i
		return languagemenu_select()
	end
end
function languagemenu_mousemoved(mx, my, dx, dy)
	local i = promptoptionat(mx, my, languagemenu_lines(), languagemenu_options())
	if i then
		sel = i
	end
end
function languagemenu_select()
	local t = LanguageList[sel]
	if t then
		CurrentLanguage = t.name
		set_language(CurrentLanguage)
		saveconfig()
		return true
	end
	return false
end