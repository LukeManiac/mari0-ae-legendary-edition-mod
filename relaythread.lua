require "love.system"
require "love.timer"

local socket = require "socket"

local channelin = love.thread.getChannel("relayin")
local channelout = love.thread.getChannel("relayout")

local ROOM_CODE_PATTERN = "^[A-Z2-9]{8}$"
local INSTANCE_ID_PATTERN = "^[A-Za-z0-9_%-]{1,80}$"
local MAX_PACKET_SIZE = 60000
local MAX_ROOMS = 1000
local ROOM_IDLE_TIMEOUT = 600
local PEER_IDLE_TIMEOUT = 45
local INSTANCE_TIMEOUT = 12
local MANAGED_EMPTY_TIMEOUT = 2
local MANAGED_STARTUP_TIMEOUT = 20

local function now()
	return socket.gettime()
end

local job = channelin:demand()
local port = tonumber(job.port) or 27021
local managed = true  -- local launches always use managed mode

local rooms = {}          -- code -> room table
local address_rooms = {}  -- "ip:port" -> code
local instances = {}      -- instance_id -> {addr_key, last_seen}
local ever_registered_instance = false
local empty_since = nil
local started_at = now()

local function addr_key(ip, p)
	return ip .. ":" .. tostring(p)
end

local function send_msg(udp, message, ip, p)
	udp:sendto(message, ip, p)
end

local function send_error(udp, code, ip, p)
	send_msg(udp, "RELAY~ERROR~" .. code, ip, p)
end

local function handle_instance(udp, instance_id, command, ip, p)
	if not instance_id:match(INSTANCE_ID_PATTERN) then
		return
	end
	local key = addr_key(ip, p)
	if command == "HEARTBEAT" then
		instances[instance_id] = {key, now()}
		ever_registered_instance = true
		empty_since = nil
		send_msg(udp, "RELAY~PONG", ip, p)
	elseif command == "STOP" then
		local inst = instances[instance_id]
		if inst and inst[1] == key then
			instances[instance_id] = nil
		end
	end
end

local function create_room(udp, code, ip, p)
	local key = addr_key(ip, p)
	local existing = rooms[code]
	if existing then
		if existing.host_key == key then
			local t = now()
			existing.last_activity = t
			existing.host_last_activity = t
			send_msg(udp, "RELAY~CREATED~" .. code, ip, p)
		else
			send_error(udp, "room_exists", ip, p)
		end
		return
	end
	if address_rooms[key] then
		send_error(udp, "endpoint_in_use", ip, p)
		return
	end
	local room_count = 0
	for _ in pairs(rooms) do
		room_count = room_count + 1
	end
	if room_count >= MAX_ROOMS then
		send_error(udp, "server_full", ip, p)
		return
	end

	local t = now()
	rooms[code] = {
		host_ip = ip,
		host_port = p,
		host_key = key,
		guest_ip = nil,
		guest_port = nil,
		guest_key = nil,
		last_activity = t,
		host_last_activity = t,
		guest_last_activity = nil,
	}
	address_rooms[key] = code
	send_msg(udp, "RELAY~CREATED~" .. code, ip, p)
end

local function join_room(udp, code, ip, p)
	local room = rooms[code]
	if not room then
		send_error(udp, "room_not_found", ip, p)
		return
	end
	local key = addr_key(ip, p)
	if room.guest_key == key then
		local t = now()
		room.last_activity = t
		room.guest_last_activity = t
		send_msg(udp, "RELAY~JOINED~" .. code, ip, p)
		return
	end
	if room.guest_key then
		send_error(udp, "room_full", ip, p)
		return
	end
	if key == room.host_key or address_rooms[key] then
		send_error(udp, "endpoint_in_use", ip, p)
		return
	end

	room.guest_ip = ip
	room.guest_port = p
	room.guest_key = key
	local t = now()
	room.last_activity = t
	room.guest_last_activity = t
	address_rooms[key] = code
	send_msg(udp, "RELAY~JOINED~" .. code, ip, p)
	send_msg(udp, "RELAY~PEER_JOINED~" .. code, room.host_ip, room.host_port)
end

local function keepalive(udp, code, ip, p)
	local room = rooms[code]
	local key = addr_key(ip, p)
	if not room or address_rooms[key] ~= code then
		send_error(udp, "room_not_found", ip, p)
		return
	end
	local t = now()
	room.last_activity = t
	if key == room.host_key then
		room.host_last_activity = t
	elseif key == room.guest_key then
		room.guest_last_activity = t
	end
end

local function detach(udp, code, ip, p)
	local room = rooms[code]
	local key = addr_key(ip, p)
	if room and room.guest_key == key then
		room.guest_ip = nil
		room.guest_port = nil
		room.guest_key = nil
		room.guest_last_activity = nil
		room.last_activity = now()
		address_rooms[key] = nil
		send_msg(udp, "RELAY~PEER_LEFT~" .. code, room.host_ip, room.host_port)
	end
end

local function leave(udp, code, ip, p)
	local room = rooms[code]
	local key = addr_key(ip, p)
	if not room or room.host_key ~= key then
		return
	end
	if room.guest_key then
		send_msg(udp, "RELAY~CLOSED~" .. code, room.guest_ip, room.guest_port)
		address_rooms[room.guest_key] = nil
	end
	address_rooms[room.host_key] = nil
	rooms[code] = nil
end

local function forward(udp, data, ip, p)
	local key = addr_key(ip, p)
	local code = address_rooms[key]
	local room = rooms[code]
	if not room then
		return
	end
	local t = now()
	local peer_ip, peer_port
	if key == room.host_key then
		peer_ip, peer_port = room.guest_ip, room.guest_port
		room.host_last_activity = t
	elseif key == room.guest_key then
		peer_ip, peer_port = room.host_ip, room.host_port
		room.guest_last_activity = t
	else
		return
	end
	room.last_activity = t
	if peer_ip then
		udp:sendto(data, peer_ip, peer_port)
	end
end

local function handle_control(udp, data, ip, p)
	local text = data
	local parts = {}
	for part in string.gmatch(text, "[^~]+") do
		table.insert(parts, part)
	end

	if #parts == 2 and parts[1] == "RELAY" and parts[2] == "PING" then
		send_msg(udp, "RELAY~PONG", ip, p)
		return
	end
	if #parts == 4 and parts[1] == "RELAY" and parts[2] == "INSTANCE" then
		handle_instance(udp, parts[3], parts[4], ip, p)
		return
	end
	if #parts ~= 3 or parts[1] ~= "RELAY" then
		return
	end
	local command, code = parts[2], parts[3]
	if not code:match(ROOM_CODE_PATTERN) then
		send_error(udp, "invalid_code", ip, p)
		return
	end

	if command == "CREATE" then
		create_room(udp, code, ip, p)
	elseif command == "JOIN" then
		join_room(udp, code, ip, p)
	elseif command == "KEEPALIVE" then
		keepalive(udp, code, ip, p)
	elseif command == "DETACH" then
		detach(udp, code, ip, p)
	elseif command == "LEAVE" then
		leave(udp, code, ip, p)
	end
end

local function expire_rooms(udp)
	local t = now()
	local expired = {}
	for code, room in pairs(rooms) do
		if t - room.host_last_activity >= ROOM_IDLE_TIMEOUT then
			table.insert(expired, code)
		end
	end
	for _, code in ipairs(expired) do
		local room = rooms[code]
		rooms[code] = nil
		address_rooms[room.host_key] = nil
		if room.guest_key then
			address_rooms[room.guest_key] = nil
			send_msg(udp, "RELAY~CLOSED~" .. code, room.guest_ip, room.guest_port)
		end
	end
	for code, room in pairs(rooms) do
		if room.guest_key and room.guest_last_activity and t - room.guest_last_activity >= PEER_IDLE_TIMEOUT then
			local guest_ip, guest_port, guest_key = room.guest_ip, room.guest_port, room.guest_key
			room.guest_ip = nil
			room.guest_port = nil
			room.guest_key = nil
			room.guest_last_activity = nil
			room.last_activity = t
			address_rooms[guest_key] = nil
			send_msg(udp, "RELAY~CLOSED~" .. code, guest_ip, guest_port)
			send_msg(udp, "RELAY~PEER_LEFT~" .. code, room.host_ip, room.host_port)
		end
	end
end

local function should_stop()
	if not managed then
		return false
	end
	local t = now()
	local expired = {}
	for id, inst in pairs(instances) do
		if t - inst[2] >= INSTANCE_TIMEOUT then
			table.insert(expired, id)
		end
	end
	for _, id in ipairs(expired) do
		instances[id] = nil
	end

	if next(instances) then
		empty_since = nil
		return false
	end
	-- No process-alive check needed; the Lua thread lives inside a game process.
	-- Rely on INSTANCE heartbeats only.
	if not ever_registered_instance then
		return t - started_at >= MANAGED_STARTUP_TIMEOUT
	end
	if empty_since == nil then
		empty_since = t
	end
	return t - empty_since >= MANAGED_EMPTY_TIMEOUT
end

-- Bind and run
local udp = socket.udp()
if not udp then
	channelout:push({"error", "net relay start error"})
	return
end

udp:settimeout(0.05)
local ok, err = udp:setsockname("127.0.0.1", port)
if not ok then
	-- try any interface as fallback
	ok, err = udp:setsockname("*", port)
	if not ok then
		channelout:push({"error", "net relay start error"})
		udp:close()
		return
	end
end

channelout:push({"ok"})

local last_expire = now()
while true do
	local data, ip, p = udp:receivefrom()
	if data then
		if #data <= MAX_PACKET_SIZE then
			if data:sub(1, 6) == "RELAY~" then
				handle_control(udp, data, ip, p)
			else
				forward(udp, data, ip, p)
			end
		end
	end

	local t = now()
	if t - last_expire >= 1.0 then
		last_expire = t
		expire_rooms(udp)
		if should_stop() then
			break
		end
	end
end

udp:close()