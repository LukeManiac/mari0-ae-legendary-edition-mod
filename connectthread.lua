local id, host, port, is_local = ...

require "love.timer"
local socket = require "socket"

local channelin = love.thread.getChannel("connin" .. id)
local channelout = love.thread.getChannel("connout" .. id)

local timeout = 30 --seconds
local start = socket.gettime()

local ip = socket.dns.toip(host)
if not ip then
	channelout:push({"timeout"})
	return
end

local udp = socket.udp()
udp:settimeout(0)
udp:setpeername(ip, port)

local nextping = 0
local spawnasked = false

while true do
	if channelin:pop() == "stop" then
		udp:close()
		return
	end

	local now = socket.gettime() - start
	if now >= timeout then
		udp:close()
		channelout:push({"timeout"})
		return
	end

	if now >= nextping then
		nextping = now + 0.5
		udp:send("RELAY~PING")
	end

	local data = udp:receive()
	if data == "RELAY~PONG" then
		udp:close()
		channelout:push({"ok", socket.gettime() - start})
		return
	end

	--a local relay that doesn't answer needs starting
	if is_local and not spawnasked and now >= 0.5 then
		spawnasked = true
		channelout:push({"spawn"})
	end

	love.timer.sleep(0.02)
end