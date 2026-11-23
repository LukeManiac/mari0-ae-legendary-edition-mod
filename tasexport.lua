--[[
	TAS EXPORT: writes the frames the TAS editor renders as an .mp4 (H.264 video in an MP4 container), in plain Lua.

	LÖVE can't encode video, and a TAS shouldn't need anything installed, so this is a small H.264 encoder of its own.
	It's lossless (apart from the usual RGB to YUV 4:2:0 conversion): every 16x16 macroblock is either
	* sent as it is (I_PCM: the raw pixels), or
	* skipped (P_Skip: copied from the frame before) when it hasn't changed.
	Games like this one have big areas that stay the same from one frame to the next, so most of the picture is skipped.
	Every TAS_EXPORT_IDR frames is a whole picture (an IDR frame), so video players can seek.

	The samples are written to <name>.mp4.part while the frames come in, then the .mp4 is put together (header, the
	samples, and the index of where every sample is) and the .part file is removed.
]]

local ffi = require "ffi"
local bit = require "bit"
local band, bor, rshift, lshift, arshift = bit.band, bit.bor, bit.rshift, bit.lshift, bit.arshift

tasexport = {}
TAS_EXPORT_IDR = 120 --a whole picture every 2 seconds
TAS_EXPORT_COPYCHUNK = 4*1048576

------------------------------------------------------------
-- bits
------------------------------------------------------------

--emulation prevention: 00 00 followed by 00, 01, 02 or 03 gets a 03 in between
local function escape(s)
	if not s:find("\0\0", 1, true) then
		return s
	end
	local out = {}
	local zeros = 0
	for i = 1, #s do
		local b = s:byte(i)
		if zeros >= 2 and b <= 3 then
			out[#out+1] = 3
			zeros = 0
		end
		out[#out+1] = b
		if b == 0 then
			zeros = zeros + 1
		else
			zeros = 0
		end
	end
	local parts = {}
	for i = 1, #out, 4096 do
		parts[#parts+1] = string.char(unpack(out, i, math.min(#out, i + 4095)))
	end
	return table.concat(parts)
end
tasexport.escape = escape

local BW = {}
BW.__index = BW

local function newbits()
	return setmetatable({parts = {}, bytes = {}, cur = 0, n = 0}, BW)
end

function BW:put(v, n)
	for i = n - 1, 0, -1 do
		self.cur = self.cur*2 + band(rshift(v, i), 1)
		self.n = self.n + 1
		if self.n == 8 then
			self.bytes[#self.bytes+1] = self.cur
			self.cur, self.n = 0, 0
		end
	end
end

function BW:ue(v)
	v = v + 1
	local len = 0
	local t = v
	while t > 1 do
		t = math.floor(t/2)
		len = len + 1
	end
	if len > 0 then
		self:put(0, len)
	end
	self:put(v, len + 1)
end

function BW:se(v)
	if v <= 0 then
		self:ue(-2*v)
	else
		self:ue(2*v - 1)
	end
end

function BW:align()
	if self.n > 0 then
		self:put(0, 8 - self.n)
	end
end

function BW:flush()
	if #self.bytes > 0 then
		local parts = {}
		for i = 1, #self.bytes, 4096 do
			parts[#parts+1] = string.char(unpack(self.bytes, i, math.min(#self.bytes, i + 4095)))
		end
		--raw samples never have a zero byte (they're 16 to 240), so each run of header bytes can be escaped on its own
		self.parts[#self.parts+1] = escape(table.concat(parts))
		self.bytes = {}
	end
end

--raw bytes (only when byte aligned)
function BW:raw(s)
	self:flush()
	self.parts[#self.parts+1] = s
end

function BW:trailing()
	self:put(1, 1)
	self:align()
	self:flush()
end

function BW:result()
	return table.concat(self.parts)
end

------------------------------------------------------------
-- bytes for the container
------------------------------------------------------------

local function u8(n)
	return string.char(band(n, 255))
end
local function u16(n)
	return string.char(band(rshift(n, 8), 255), band(n, 255))
end
local function u24(n)
	return string.char(band(rshift(n, 16), 255), band(rshift(n, 8), 255), band(n, 255))
end
local function u32(n)
	n = n % 4294967296
	return string.char(math.floor(n/16777216) % 256, math.floor(n/65536) % 256, math.floor(n/256) % 256, n % 256)
end
local function u64(n)
	return u32(math.floor(n/4294967296)) .. u32(n % 4294967296)
end
local function box(kind, payload)
	return u32(8 + #payload) .. kind .. payload
end
local function fullbox(kind, version, flags, payload)
	return box(kind, u8(version) .. u24(flags) .. payload)
end
tasexport.u32 = u32

------------------------------------------------------------
-- H.264 parameter sets
------------------------------------------------------------

--the lowest level whose frame size and macroblock rate fit
local function pickevel(mbs, fps)
	local levels = {{30, 1620, 40500}, {31, 3600, 108000}, {32, 5120, 216000}, {40, 8192, 245760}, {42, 8704, 522240},
		{50, 22080, 589824}, {51, 36864, 983040}, {52, 36864, 2073600}}
	for _, l in ipairs(levels) do
		if mbs <= l[2] and mbs*fps <= l[3] then
			return l[1]
		end
	end
	return 52
end

local function makesps(wmbs, hmbs, level)
	local b = newbits()
	b:put(66, 8) --baseline
	b:put(0xC0, 8) --constraint_set0 and constraint_set1 (constrained baseline)
	b:put(level, 8)
	b:ue(0) --seq_parameter_set_id
	b:ue(0) --log2_max_frame_num_minus4: frame_num is 4 bits
	b:ue(2) --pic_order_cnt_type 2: pictures come out in the order they go in
	b:ue(1) --max_num_ref_frames
	b:put(0, 1) --gaps_in_frame_num_value_allowed_flag
	b:ue(wmbs - 1)
	b:ue(hmbs - 1)
	b:put(1, 1) --frame_mbs_only_flag
	b:put(1, 1) --direct_8x8_inference_flag
	b:put(0, 1) --frame_cropping_flag
	b:put(0, 1) --vui_parameters_present_flag
	b:trailing()
	return string.char(0x67) .. b:result()
end

local function makepps()
	local b = newbits()
	b:ue(0) --pic_parameter_set_id
	b:ue(0) --seq_parameter_set_id
	b:put(0, 1) --entropy_coding_mode_flag: CAVLC
	b:put(0, 1) --bottom_field_pic_order_in_frame_present_flag
	b:ue(0) --num_slice_groups_minus1
	b:ue(0) --num_ref_idx_l0_default_active_minus1
	b:ue(0) --num_ref_idx_l1_default_active_minus1
	b:put(0, 1) --weighted_pred_flag
	b:put(0, 2) --weighted_bipred_idc
	b:se(0) --pic_init_qp_minus26
	b:se(0) --pic_init_qs_minus26
	b:se(0) --chroma_qp_index_offset
	b:put(1, 1) --deblocking_filter_control_present_flag (so slices can turn it off)
	b:put(0, 1) --constrained_intra_pred_flag
	b:put(0, 1) --redundant_pic_cnt_present_flag
	b:trailing()
	return string.char(0x68) .. b:result()
end

------------------------------------------------------------
-- encoder
------------------------------------------------------------

local Enc = {}
Enc.__index = Enc

--path: where the .mp4 goes (in the save folder). w and h: multiples of 16
function tasexport.new(path, w, h, fps)
	if w % 16 ~= 0 or h % 16 ~= 0 then
		return nil, "the size has to be a multiple of 16"
	end
	local part = path .. ".part"
	local file, err = love.filesystem.newFile(part, "w")
	if not file then
		return nil, err
	end
	local self = setmetatable({}, Enc)
	self.path, self.part, self.file = path, part, file
	self.w, self.h, self.fps = w, h, fps or 60
	self.wmbs, self.hmbs = w/16, h/16
	self.mbs = self.wmbs*self.hmbs
	self.level = pickevel(self.mbs, self.fps)
	self.sps = makesps(self.wmbs, self.hmbs, self.level)
	self.pps = makepps()
	self.Y = ffi.new("uint8_t[?]", w*h)
	self.U = ffi.new("uint8_t[?]", (w/2)*(h/2))
	self.V = ffi.new("uint8_t[?]", (w/2)*(h/2))
	self.mb = ffi.new("uint8_t[384]")
	self.prev = {}
	self.sizes = {}
	self.sync = {}
	self.count = 0
	self.idrs = 0
	self.framenum = 0
	self.datasize = 0
	return self
end

--RGB to YUV 4:2:0 (BT.601, video range: Y 16-235, U and V 16-240, so no sample is ever 0)
function Enc:convert(imagedata)
	local w, h = self.w, self.h
	local p = ffi.cast("const uint8_t*", imagedata:getPointer())
	local Y, U, V = self.Y, self.U, self.V
	local hw = w/2
	for y = 0, h - 1, 2 do
		local r0 = p + y*w*4
		local r1 = r0 + w*4
		local y0 = y*w
		local y1 = y0 + w
		local co = (y/2)*hw
		for x = 0, w - 1, 2 do
			local i = x*4
			local ra, ga, ba = r0[i], r0[i+1], r0[i+2]
			local rb, gb, bb = r0[i+4], r0[i+5], r0[i+6]
			local rc, gc, bc = r1[i], r1[i+1], r1[i+2]
			local rd, gd, bd = r1[i+4], r1[i+5], r1[i+6]
			Y[y0+x] = rshift(66*ra + 129*ga + 25*ba + 128, 8) + 16
			Y[y0+x+1] = rshift(66*rb + 129*gb + 25*bb + 128, 8) + 16
			Y[y1+x] = rshift(66*rc + 129*gc + 25*bc + 128, 8) + 16
			Y[y1+x+1] = rshift(66*rd + 129*gd + 25*bd + 128, 8) + 16
			local r = rshift(ra + rb + rc + rd + 2, 2)
			local g = rshift(ga + gb + gc + gd + 2, 2)
			local b = rshift(ba + bb + bc + bd + 2, 2)
			U[co + x/2] = arshift(-38*r - 74*g + 112*b + 128, 8) + 128
			V[co + x/2] = arshift(112*r - 94*g - 18*b + 128, 8) + 128
		end
	end
end

--the raw bytes of macroblock (mx, my): 256 luma, 64 Cb, 64 Cr
function Enc:macroblock(mx, my)
	local w, hw = self.w, self.w/2
	local mb, Y, U, V = self.mb, self.Y, self.U, self.V
	for j = 0, 15 do
		ffi.copy(mb + j*16, Y + (my*16 + j)*w + mx*16, 16)
	end
	for j = 0, 7 do
		ffi.copy(mb + 256 + j*8, U + (my*8 + j)*hw + mx*8, 8)
		ffi.copy(mb + 320 + j*8, V + (my*8 + j)*hw + mx*8, 8)
	end
	return ffi.string(mb, 384)
end

function Enc:frame(imagedata)
	self:convert(imagedata)
	local idr = (self.count % TAS_EXPORT_IDR == 0)
	if idr then
		self.framenum = 0
	end
	local b = newbits()
	--slice header
	b:ue(0) --first_mb_in_slice
	b:ue(idr and 7 or 5) --slice_type: I or P (every slice of the picture the same)
	b:ue(0) --pic_parameter_set_id
	b:put(self.framenum, 4) --frame_num
	if idr then
		b:ue(self.idrs % 2) --idr_pic_id
	else
		b:put(0, 1) --num_ref_idx_active_override_flag
		b:put(0, 1) --ref_pic_list_modification_flag_l0
	end
	if idr then
		b:put(0, 1) --no_output_of_prior_pics_flag
		b:put(0, 1) --long_term_reference_flag
	else
		b:put(0, 1) --adaptive_ref_pic_marking_mode_flag
	end
	b:se(0) --slice_qp_delta
	b:ue(1) --disable_deblocking_filter_idc: off, so skipped blocks are exact copies
	--slice data
	local prev = self.prev
	local run = 0
	local i = 0
	for my = 0, self.hmbs - 1 do
		for mx = 0, self.wmbs - 1 do
			i = i + 1
			local data = self:macroblock(mx, my)
			if idr then
				b:ue(25) --mb_type I_PCM (in an I slice)
				b:align()
				b:raw(data)
			elseif prev[i] == data then
				run = run + 1
			else
				b:ue(run) --mb_skip_run
				run = 0
				b:ue(30) --mb_type I_PCM (in a P slice: 5 + 25)
				b:align()
				b:raw(data)
			end
			prev[i] = data
		end
	end
	if run > 0 then
		b:ue(run)
	end
	b:trailing()
	local nal = string.char(idr and 0x65 or 0x41) .. b:result()
	local sample = u32(#nal) .. nal
	local ok, err = self.file:write(sample)
	if not ok then
		error(err or "couldn't write the video")
	end
	self.count = self.count + 1
	self.sizes[self.count] = #sample
	self.datasize = self.datasize + #sample
	if idr then
		self.sync[#self.sync+1] = self.count
		self.idrs = self.idrs + 1
	end
	self.framenum = (self.framenum + 1) % 16
end

function Enc:moov()
	local n = self.count
	local w, h = self.w, self.h
	local matrix = u32(0x00010000) .. u32(0) .. u32(0) .. u32(0) .. u32(0x00010000) .. u32(0) .. u32(0) .. u32(0) .. u32(0x40000000)
	local duration = math.floor(n*1000/self.fps + 0.5)
	local mvhd = fullbox("mvhd", 0, 0, u32(0) .. u32(0) .. u32(1000) .. u32(duration) .. u32(0x00010000) .. u16(0x0100)
		.. u16(0) .. u32(0) .. u32(0) .. matrix .. string.rep("\0", 24) .. u32(2))
	local tkhd = fullbox("tkhd", 0, 3, u32(0) .. u32(0) .. u32(1) .. u32(0) .. u32(duration) .. u32(0) .. u32(0)
		.. u16(0) .. u16(0) .. u16(0) .. u16(0) .. matrix .. u32(w*65536) .. u32(h*65536))
	local mdhd = fullbox("mdhd", 0, 0, u32(0) .. u32(0) .. u32(self.fps) .. u32(n) .. u16(0x55C4) .. u16(0))
	local hdlr = fullbox("hdlr", 0, 0, u32(0) .. "vide" .. u32(0) .. u32(0) .. u32(0) .. "VideoHandler\0")
	local vmhd = fullbox("vmhd", 0, 1, u16(0) .. u16(0) .. u16(0) .. u16(0))
	local dinf = box("dinf", fullbox("dref", 0, 0, u32(1) .. fullbox("url ", 0, 1, "")))
	local avcc = box("avcC", u8(1) .. u8(66) .. u8(0xC0) .. u8(self.level) .. u8(0xFF) .. u8(0xE1)
		.. u16(#self.sps) .. self.sps .. u8(1) .. u16(#self.pps) .. self.pps)
	local name = "mari0 tas"
	local compressor = u8(#name) .. name .. string.rep("\0", 31 - #name)
	local avc1 = box("avc1", string.rep("\0", 6) .. u16(1) .. u16(0) .. u16(0) .. u32(0) .. u32(0) .. u32(0)
		.. u16(w) .. u16(h) .. u32(0x00480000) .. u32(0x00480000) .. u32(0) .. u16(1) .. compressor .. u16(0x0018)
		.. u16(0xFFFF) .. avcc)
	local stsd = fullbox("stsd", 0, 0, u32(1) .. avc1)
	local stts = fullbox("stts", 0, 0, u32(1) .. u32(n) .. u32(1))
	local syncs = {}
	for i, s in ipairs(self.sync) do
		syncs[i] = u32(s)
	end
	local stss = fullbox("stss", 0, 0, u32(#self.sync) .. table.concat(syncs))
	local stsc = fullbox("stsc", 0, 0, u32(1) .. u32(1) .. u32(n) .. u32(1))
	local sizes = {}
	for i = 1, n do
		sizes[i] = u32(self.sizes[i])
	end
	local stsz = fullbox("stsz", 0, 0, u32(0) .. u32(n) .. table.concat(sizes))
	local stco = fullbox("stco", 0, 0, u32(1) .. u32(self.dataoffset))
	local stbl = box("stbl", stsd .. stts .. stss .. stsc .. stsz .. stco)
	local minf = box("minf", vmhd .. dinf .. stbl)
	local mdia = box("mdia", mdhd .. hdlr .. minf)
	local trak = box("trak", tkhd .. mdia)
	return box("moov", mvhd .. trak)
end

--puts the .mp4 together a piece at a time (budget: seconds). Returns true once it's done
function Enc:finishstep(budget)
	local start = love.timer.getTime()
	if not self.out then
		self.file:close()
		local ftyp = box("ftyp", "isom" .. u32(0x200) .. "isom" .. "iso2" .. "avc1" .. "mp41")
		local out, err = love.filesystem.newFile(self.path, "w")
		if not out then
			error(err or "couldn't write " .. self.path)
		end
		self.out = out
		self.dataoffset = #ftyp + 16
		out:write(ftyp)
		out:write(u32(1) .. "mdat" .. u64(16 + self.datasize)) --a 64-bit size: the video can be over 4 GB
		self.input = love.filesystem.newFile(self.part, "r")
		self.copied = 0
	end
	while self.copied < self.datasize do
		local data, size = self.input:read(math.min(TAS_EXPORT_COPYCHUNK, self.datasize - self.copied))
		if not data or size == 0 then
			error("couldn't read the video back")
		end
		self.out:write(data)
		self.copied = self.copied + size
		if love.timer.getTime() - start > budget then
			return false
		end
	end
	self.input:close()
	self.out:write(self:moov())
	self.out:close()
	love.filesystem.remove(self.part)
	self.bytes = (love.filesystem.getInfo(self.path) or {}).size
	self.done = true
	return true
end

function Enc:finishprogress()
	if not self.datasize or self.datasize == 0 then
		return 1
	end
	return (self.copied or 0)/self.datasize
end

function Enc:abort()
	pcall(function() self.file:close() end)
	if self.input then
		pcall(function() self.input:close() end)
	end
	if self.out then
		pcall(function() self.out:close() end)
	end
	love.filesystem.remove(self.part)
	if not self.done then
		love.filesystem.remove(self.path)
	end
end