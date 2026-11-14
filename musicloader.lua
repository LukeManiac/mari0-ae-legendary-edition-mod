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
	FAKEFAST_RATE = 1.25, --how much faster a made-up fast version is (see music:fakefast)
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
--a song sped up without changing its pitch: decoded and time-stretched (WSOLA) in a thread, since LÖVE can only change
--the playback rate, which moves the pitch with it. The result is kept, so a song is only stretched once.
local STRETCH_THREAD = [[
local path, rate, channelname = ...
require("love.filesystem")
require("love.sound")
local ffi = require("ffi")
local ok, err = pcall(function()
	local sd = love.sound.newSoundData(path)
	local C, N, sr = sd:getChannelCount(), sd:getSampleCount(), sd:getSampleRate()
	if sd:getBitDepth() ~= 16 then --(decoded songs are 16-bit, this is just in case)
		local copy = love.sound.newSoundData(N, sr, 16, C)
		for i = 0, N-1 do
			for c = 1, C do
				copy:setSample(i, c, sd:getSample(i, c))
			end
		end
		sd = copy
	end
	local inp = ffi.cast("int16_t*", sd:getFFIPointer())
	local outN = math.floor(N/rate)
	local acc = ffi.new("float[?]", outN*C)
	local W, Hs = 2048, 1024 --window and output hop (a Hann window at 50% overlap adds up to 1)
	local DELTA, STEP, CSTEP = 256, 4, 16 --how far to look for the best fit, and how finely
	local win = ffi.new("float[?]", W)
	for j = 0, W-1 do
		win[j] = 0.5 - 0.5*math.cos(2*math.pi*j/W)
	end
	local prev, k = 0, 0
	while k*Hs < outN do
		local os = k*Hs
		local ideal = math.floor(os*rate)
		local best = ideal
		if k > 0 then
			--the input that lines up best with how the last piece would have carried on
			local natural = prev + Hs
			local bestcorr = -math.huge
			for d = -DELTA, DELTA, STEP do
				local s = ideal + d
				if s >= 0 and s + W <= N and natural + W <= N then
					local corr = 0
					for j = 0, W-1, CSTEP do
						corr = corr + inp[(s+j)*C]*inp[(natural+j)*C]
					end
					if corr > bestcorr then
						bestcorr = corr
						best = s
					end
				end
			end
		end
		for j = 0, W-1 do
			local o, ii = os + j, best + j
			if o >= outN or ii >= N then
				break
			end
			local w = win[j]
			if k == 0 and j < Hs then
				w = 1 --the very start doesn't fade in
			end
			for c = 0, C-1 do
				acc[o*C+c] = acc[o*C+c] + inp[ii*C+c]*w
			end
		end
		prev = best
		k = k + 1
	end
	local out = love.sound.newSoundData(outN, sr, 16, C)
	local op = ffi.cast("int16_t*", out:getFFIPointer())
	for i = 0, outN*C-1 do
		local v = acc[i]
		if v > 32767 then
			v = 32767
		elseif v < -32768 then
			v = -32768
		end
		op[i] = v
	end
	love.thread.getChannel(channelname):push(out)
end)
if not ok then
	love.thread.getChannel(channelname):push("error: " .. tostring(err))
end
]]

music.stretched = {} --[song .. "|" .. rate] = time-stretched SoundData
music.stretchjobs = {} --[song .. "|" .. rate] = {thread, channel name} while it's being made

--starts stretching a song in the background (music:fakefast picks it up, or waits for it)
function music:prestretch(name, rate)
	local key = name .. "|" .. rate
	if self.stretched[key] or self.stretchjobs[key] or not FFIAVAILABLE or not love.filesystem.getInfo(name) then
		return
	end
	local channelname = "musicstretch|" .. key
	love.thread.getChannel(channelname):clear()
	local thread = love.thread.newThread(STRETCH_THREAD)
	thread:start(name, rate, channelname)
	self.stretchjobs[key] = {thread = thread, channel = channelname}
end

--the stretched song, waiting for it if it's still being made (nil if it can't be made)
function music:getstretched(name, rate)
	local key = name .. "|" .. rate
	if self.stretched[key] then
		return self.stretched[key]
	end
	self:prestretch(name, rate)
	local job = self.stretchjobs[key]
	if not job then
		return nil
	end
	local result = love.thread.getChannel(job.channel):demand(30)
	self.stretchjobs[key] = nil
	if type(result) ~= "userdata" then
		print("couldn't speed up " .. name .. ": " .. tostring(result or job.thread:getError()))
		return nil
	end
	self.stretched[key] = result
	return result
end

--returns the fast version's name; music:unfakefast takes it away again
--classic: just play the song faster, which raises its pitch too (the classicspeedupfastmusic nitpick).
--Otherwise it's time-stretched to keep its pitch (falling back to the classic way if that can't be done)
--file: the song it's made from, when that isn't name itself ("starmusic" made from a mappack's starmusic.ogg)
function music:fakefast(name, rate, classic, file)
	local fastname = self:variant(name, "-fast")
	file = file or name
	if self.loaded[fastname] or not love.filesystem.getInfo(file) then
		return fastname --a real one (or nothing to make one from)
	end
	rate = rate or self.FAKEFAST_RATE
	local stretched = nil
	if not classic then
		stretched = self:getstretched(file, rate)
	end
	local source
	if stretched then
		source = love.audio.newSource(stretched)
		self.pitchmul[fastname] = 1 --already faster, at the same pitch
	else
		source = love.audio.newSource(file, "stream")
		self.pitchmul[fastname] = rate
	end
	source:setLooping(true)
	source:setPitch(self.pitch*self.pitchmul[fastname])
	self.loaded[fastname] = source

	--also make a fakefast intro so the sped-up song still plays its intro first
	local introfile = self:variant(file, "-intro")
	if love.filesystem.getInfo(introfile) then
		local fastintro = self:variant(name, "-fastintro")
		if not self.loaded[fastintro] then
			local introstretched = nil
			if not classic then
				introstretched = self:getstretched(introfile, rate)
			end
			local introsource
			if introstretched then
				introsource = love.audio.newSource(introstretched)
				self.pitchmul[fastintro] = 1
			else
				introsource = love.audio.newSource(introfile, "stream")
				self.pitchmul[fastintro] = rate
			end
			--intros do not loop
			introsource:setPitch(self.pitch*self.pitchmul[fastintro])
			self.loaded[fastintro] = introsource
		end
	end

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
	local fastintro = self:variant(name, "-fastintro")
	if self.pitchmul[fastintro] then
		if self.loaded[fastintro] then
			self.loaded[fastintro]:stop()
		end
		self.loaded[fastintro] = nil
		self.pitchmul[fastintro] = nil
	end
end

--a star theme without a fast version: starmusic-fast becomes the star theme (file) sped up, in place of whatever it was
function music:fakefaststar(file)
	self:stop("starmusic-fast")
	self.loaded["starmusic-fast"] = nil
	self.pitchmul["starmusic-fast"] = nil
	self:fakefast("starmusic", self.FAKEFAST_RATE, ClassicSpeedUpFastMusic, file)
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
