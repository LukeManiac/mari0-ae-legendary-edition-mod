music = {
	toload = {
	"overworld",
	"underground",
	"castle",
	"underwater",
	"starmusic",
	"princessmusic",
	},
	loaded = {},
	list = {},
	list_fast = {},
	pitch = 1,
	pitchmul = {}, --a song's own pitch on top of music.pitch (a made-up fast version, see music:fakefast)
}

local musicpath = "sounds/%s.ogg"

local intromusic = false --{intro name, started music}

--"sounds/x.ogg" -> "sounds/x-intro.ogg" (.mp3 too), built-in names without an extension get the suffix at the end ("starmusic" -> "starmusic-intro")
function music:variant(name, suffix)
	local ext = name:sub(-4, -1):lower()
	if ext == ".ogg" or ext == ".mp3" then
		return name:sub(1, -5) .. suffix .. name:sub(-4, -1)
	end
	return name .. suffix
end

--the intro of the fast version: "x-fastintro.ogg" or "x-introfast.ogg" (loaded as "x-fastintro.ogg" either way), nil if there's none
function music:fastintrofile(musicfile)
	for _, suffix in ipairs({"-fastintro", "-introfast"}) do
		local file = self:variant(musicfile, suffix)
		if love.filesystem.getInfo(file) then
			return file
		end
	end
	return nil
end

function music:init()
	intromusic = false --music that is currently in it's intro phase
end

function music:load(musicfile) -- can take a single file string or an array of file strings
	if type(musicfile) == "table" then
		for i, v in ipairs(musicfile) do
			self:preload(musicpath:format(v), v)
			--load fast music
			if love.filesystem.getInfo(musicpath:format(v .. "-fast")) then
				self:preload(musicpath:format(v .. "-fast"), v .. "-fast")
			end
		end
	else --custom music
		self:preload(musicfile)
		--load fast music
		if love.filesystem.getInfo(musicfile:sub(1, -5) .. "-fast" .. musicfile:sub(-4, -1)) then
			self:preload(musicfile:sub(1, -5) .. "-fast" .. musicfile:sub(-4, -1))
		end
		--load intro music
		if love.filesystem.getInfo(musicfile:sub(1, -5) .. "-intro" .. musicfile:sub(-4, -1)) then
			self:preloadintro(musicfile:sub(1, -5) .. "-intro" .. musicfile:sub(-4, -1))
		end
		--load the fast music's intro
		local fastintro = self:fastintrofile(musicfile)
		if fastintro then
			self:preloadintro(fastintro, self:variant(musicfile, "-fastintro"))
		end
	end
end

function music:preload(musicfile, name)
	if name or self.loaded[musicfile] == nil then
		local source = love.audio.newSource(musicfile, "stream")
		source:setLooping(true)
		source:setPitch(self.pitch)
		self.loaded[name or musicfile] = source
	end
end

function music:preloadintro(musicfile, name)
	if name or self.loaded[musicfile] == nil then
		local source = love.audio.newSource(musicfile, "stream")
		source:setPitch(self.pitch)
		self.loaded[name or musicfile] = source
	end
end

--"x-fast.ogg" -> "x.ogg" (.mp3 too, "starmusic-fast" -> "starmusic"), nil if it isn't a fast version
function music:normalname(name)
	local ext = name:sub(-4, -1):lower()
	if (ext == ".ogg" or ext == ".mp3") and name:sub(-9, -5) == "-fast" then
		return name:sub(1, -10) .. name:sub(-4, -1)
	elseif name:sub(-5, -1) == "-fast" then
		return name:sub(1, -6)
	end
	return nil
end

--the intro that plays before a song: "x-intro", or "x-fastintro" before the fast version "x-fast"
function music:introname(name)
	local normal = self:normalname(name)
	if normal then
		return self:variant(normal, "-fastintro")
	end
	return self:variant(name, "-intro")
end

function music:play(name, isfast, nointro)
	local isintro = false
	if name and soundenabled then
		--find fast
		intromusic = false
		if isfast and self.loaded[self:variant(name, "-fast")] then
			name = self:variant(name, "-fast")
		end
		local filename = name --what plays after the intro
		if (not nointro) and self.loaded[self:introname(name)] then
			name = self:introname(name)
			isintro = true
		end
		if self.loaded[name] then
			--self.loaded[name]:setPitch(0.61538)
			playsound(self.loaded[name])
			if isintro then
				intromusic = {name, filename}
			end
		elseif self.loaded[musicpath:format(name)] then
			playsound(self.loaded[musicpath:format(name)])
		end
	end
end

function music:playIndex(index, isfast)
	local name = self.list[index]
	--find fast default music
	if isfast then
		name = name .. "-fast"
	end
	self:play(name)
end

function music:stop(name, isfast)
	if name then
		--find fast
		if isfast and self.loaded[self:variant(name, "-fast")] then
			name = self:variant(name, "-fast")
		end
		--an intro (normal or fast) that's still playing stops too
		if intromusic and name == intromusic[2] then
			if self.loaded[intromusic[1]] then
				love.audio.stop(self.loaded[intromusic[1]])
			end
			self:disableintromusic()
		end
		if self.loaded[name] then
			love.audio.stop(self.loaded[name])
		elseif self.loaded[musicpath:format(name)] then
			love.audio.stop(self.loaded[musicpath:format(name)])
		end
	end
end

function music:stopIndex(index, isfast)
	local name = self.list[index]
	--find fast default music
	if isfast then
		name = name .. "-fast"
	end
	self:stop(name)
	intromusic = false
end

function music:stopall()
	for name, source in pairs(self.loaded) do
		if source ~= false then
			source:stop()
		end
	end
	intromusic = false
end

function music:getPlaying()
	for name, source in pairs(self.loaded) do
		if isActive(source) then
			return name, source
		end
	end
	return false
end

function music:update()
	for name, source in pairs(self.loaded) do
		if source ~= false then
			source:setPitch(self.pitch*(self.pitchmul[name] or 1))
		end
	end
	if intromusic then
		if self.loaded[intromusic[1]] and not isActive(self.loaded[intromusic[1]]) then
			music:play(intromusic[2], nil, true)
			intromusic = false
		end
	end
end

--a song without a fast version gets one: the song itself, played faster and higher (rate 1.25: 1.25x speed,
--and 3.86 semitones up, the closest to 4 a single rate can get while keeping the speed)
--returns the fast version's name; music:unfakefast takes it away again
function music:fakefast(name, rate)
	local fastname = self:variant(name, "-fast")
	if self.loaded[fastname] or not love.filesystem.getInfo(name) then
		return fastname --a real one (or nothing to make one from)
	end
	local source = love.audio.newSource(name, "stream")
	source:setLooping(true)
	self.pitchmul[fastname] = rate or 1.25
	source:setPitch(self.pitch*self.pitchmul[fastname])
	self.loaded[fastname] = source
	return fastname
end

function music:unfakefast(name)
	local fastname = self:variant(name, "-fast")
	if self.pitchmul[fastname] then
		if self.loaded[fastname] then
			self.loaded[fastname]:stop()
		end
		self.loaded[fastname] = nil
		self.pitchmul[fastname] = nil
	end
end

function music:playingmusic()
	for name, source in pairs(self.loaded) do
		if source and isActive(source) then
			return true
		end
	end
	return false
end

function music:disableintromusic()
	intromusic = false
end

local loveaudiostop = love.audio.stop
function love.audio.stop(...)
	if select("#", ...) == 0 or (intromusic and music.loaded[intromusic[1]] == (...)) then
		intromusic = false
	end
	return loveaudiostop(...)
end

music:load(music.toload)

-- the original/default music needs to be put in the correct lists
for i,v in ipairs(music.toload) do
	if not v:match("princessmusic") then
		table.insert(music.list, v)
	end
end

music:init()
