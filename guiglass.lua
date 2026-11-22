--Liquid glass for the GUI (in the spirit of iOS 26).
--
--Every glass panel blurs whatever is already drawn behind it, but only inside its own rounded shape, so the
--blur is cut to exactly the part of the element that you can see. The edges bend the backdrop like a lens,
--with a little colour split, a specular rim lit from the top left and a soft shadow underneath.
--
--How the backdrop is read: LÖVE can't sample the canvas it's drawing to, so the first panel drawn on a canvas each frame
--copies that canvas at a third of its size and blurs it in two passes. Every panel after it reads the same copy by
--screen position, unless something it covers was drawn as glass since the copy was made, then the copy is made again.
--When nothing can be read (drawing straight to the window) the glass falls back to a tinted pane.

guiglass = {}

guiglass.enabled = true      --false: plain tinted panes, no backdrop blur
guiglass.quality = "full"    --"full": the backdrop is blurred again every frame
                             --"flat": no backdrop blur at all, tinted panes
guiglass.blur = 2            --blur radius (sigma), in game pixels (lower: clearer glass)
guiglass.downsample = nil    --the backdrop is blurred at 1/downsample size. nil: at the game's own resolution
                             --(1/scale), so it costs the same however big the window is
guiglass.refraction = 1.6    --how far the edges bend the backdrop, in game pixels
guiglass.tintstrength = 0.42 --how much of the element's fill colour is laid over the blurred backdrop
guiglass.clarity = 0.6       --scales the tint of every element except bases (the editor's background pane): lower is clearer
guiglass.shine = 1           --how strongly the curved edge catches the light (0: off)

local PRESS_STRETCH = 1.18 --scale x while held (scale y is 1/this, so the area stays the same)
local PRESS_TIME = 0.2
local SPRING_K = 600       --jelly stiffness
local SPRING_D = 5.5       --jelly damping (lower wobbles longer)
local MAGNET_PULL = 0.05   --how much of the distance to the mouse the element leans
local MAGNET_MAX = 1/32    --at most this much of the element's diagonal (a quarter of the centre-to-corner distance)
local MAGNET_SPEED = 14    --lerp speed of the lean (per second)

local blurshader, glassshader, mesh, dummy
local sentimage --the backdrop the glass shader has now
local sentshine --the shine the glass shader has now
local NOSCALE, NOCLAMP = {0, 0}, {0, 0, 0, 0}
local u = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}
local function setu(i, a, b, c, d)
	local t = u[i]
	t[1], t[2], t[3], t[4] = a, b, c, d
end
local supported = true
local state = setmetatable({}, {__mode = "k"}) --per element motion, dropped with the element

local blurcode = [[
extern vec2 dir;
extern vec4 region;
extern float sigma;
//gaussian blur along dir. Neighbouring taps are read in pairs through the linear filter, so 13 reads cover 25 taps
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc)
{
	float s2 = max(sigma*sigma, 0.0001);
	vec4 sum = Texel(tex, clamp(uv, region.xy, region.zw));
	float wsum = 1.0;
	for (int k = 0; k < 6; k++) {
		float i1 = float(2*k + 1);
		float i2 = i1 + 1.0;
		float w1 = exp(-0.5*i1*i1/s2);
		float w2 = exp(-0.5*i2*i2/s2);
		if (w1 < 0.002) {
			break; //the rest weigh nothing
		}
		float w = w1 + w2;
		float off = (i1*w1 + i2*w2)/max(w, 0.000001);
		sum += Texel(tex, clamp(uv + dir*off, region.xy, region.zw))*w;
		sum += Texel(tex, clamp(uv - dir*off, region.xy, region.zw))*w;
		wsum += 2.0*w;
	}
	return sum/wsum;
}
]]

local glasscode = [[
extern Image backdrop;
//u[0]: uv per target pixel in the blurred copy (xy), element size in local pixels (zw)
//u[1]: uv rectangle the blurred copy covers
//u[2]: tint rgb, strength      u[3]: rim rgb, strength
//u[4]: margin (the mesh reaches this far around the element, for the shadow), radius, aa (local pixels per target
//      pixel, for smooth edges), refraction (target pixels)
//u[5]: bezel (how far in from the edge the lens bends), shadow, opacity without a backdrop, has a backdrop (0/1)
extern vec4 u[6];
extern float shine;

float sdbox(vec2 p, vec2 b, float r)
{
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
	vec2 size = u[0].zw;
	float margin = u[4].x;
	float aa = u[4].z;
	vec2 hb = size*0.5;
	vec2 p = tc*(size + 2.0*margin) - margin - hb;
	float r = min(u[4].y, min(hb.x, hb.y));
	vec2 q = abs(p) - hb + r;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	float inside = clamp(0.5 - d/aa, 0.0, 1.0);

	//outside the shape there's only the soft shadow
	if (inside <= 0.0) {
		float ds = sdbox(p - vec2(0.0, margin*0.3), hb, r);
		return vec4(0.0, 0.0, 0.0, u[5].y*exp(-max(ds, 0.0)/max(margin*0.4, 0.001)))*color;
	}

	float depth = max(-d, 0.0);
	float bezel = u[5].x;
	vec4 tint = u[2];
	float sheen = 0.07*(1.0 - clamp((p.y + hb.y)/max(size.y, 1.0), 0.0, 1.0));

	//the middle, past the bent edge: just the blurred backdrop, tinted (most of a big panel's pixels)
	if (depth > bezel) {
		vec4 sg = vec4(0.0);
		if (u[5].w > 0.0) {
			sg = Texel(backdrop, clamp(sc*u[0].xy, u[1].xy, u[1].zw));
		}
		float bda = sg.a*u[5].w;
		vec3 bd = sg.rgb/max(sg.a, 0.002);
		float lum = dot(bd, vec3(0.299, 0.587, 0.114));
		bd = clamp(mix(vec3(lum), bd, 1.35), 0.0, 1.0);
		vec3 col = mix(tint.rgb, mix(bd, tint.rgb, tint.a), bda) + vec3(sheen);
		float a = mix(u[5].z, 1.0, bda);
		return vec4(clamp(col, 0.0, 1.0), a*inside)*color;
	}

	//near the edge: the lens, the colour split and the rim
	//(only on the antialiased rim: everywhere else inside is 1, so it would be multiplied away)
	float sh = 0.0;
	if (inside < 1.0) {
		float ds = sdbox(p - vec2(0.0, margin*0.3), hb, r);
		sh = u[5].y*exp(-max(ds, 0.0)/max(margin*0.4, 0.001))*(1.0 - inside);
	}

	//the edge's direction, straight from the shape
	vec2 sp = sign(p);
	vec2 n;
	if (q.x > 0.0 && q.y > 0.0) {
		n = normalize(q)*sp;
	} else if (q.x > q.y) {
		n = vec2(sp.x, 0.0);
	} else {
		n = vec2(0.0, sp.y);
	}

	float lens = 1.0 - smoothstep(0.0, bezel, depth);
	lens = lens*lens;

	//blurred backdrop, bent at the edges (with a little colour split there)
	vec2 off = -n*lens*u[4].w;
	vec4 sg = vec4(0.0);
	if (u[5].w > 0.0) {
		sg = Texel(backdrop, clamp((sc + off)*u[0].xy, u[1].xy, u[1].zw));
	}
	vec3 bd = sg.rgb;
	//the split moves the red and blue reads under half a pixel of the blurred copy, so it only shows where the lens
	//is strong (the outer half of the bezel)
	if (lens > 0.25 && u[5].w > 0.0) {
		bd.r = Texel(backdrop, clamp((sc + off*1.25)*u[0].xy, u[1].xy, u[1].zw)).r;
		bd.b = Texel(backdrop, clamp((sc + off*0.75)*u[0].xy, u[1].xy, u[1].zw)).b;
	}
	float bda = sg.a*u[5].w;
	bd = bd/max(sg.a, 0.002);
	float lum = dot(bd, vec3(0.299, 0.587, 0.114));
	bd = clamp(mix(vec3(lum), bd, 1.35), 0.0, 1.0);

	vec3 col = mix(tint.rgb, mix(bd, tint.rgb, tint.a), bda);
	float a = mix(u[5].z, 1.0, bda);

	//sheen from the top, glow along the inside of the edge
	col += vec3(sheen);
	col += vec3(0.08)*lens;

	//specular rim, lit from the top left, a softer bounce on the bottom right
	vec4 rim = u[3];
	vec2 light = vec2(-0.5432, -0.8396);
	float ld = dot(n, light);
	float lp = max(ld, 0.0);
	float ln = max(-ld, 0.0);
	float spec = 0.35 + 0.65*lp*sqrt(lp) + 0.45*ln*ln;
	float band = 1.0 - smoothstep(0.0, aa*1.6, depth);
	col = mix(col, rim.rgb, clamp(band*rim.a*spec, 0.0, 1.0));
	col += rim.rgb*(1.0 - smoothstep(0.0, bezel*0.7, depth))*0.10*rim.a*spec;
	a = max(a, band*rim.a*spec);

	//3D shine: the bezel is a rounded edge (a quarter circle from the flat top down to the rim), lit from the top left.
	//Its normal leans out by x across the bezel, so the curve facing the light catches a soft highlight, the side facing
	//away darkens a little, and the steepest part reflects a little more (fresnel). The flat middle's lighting is taken
	//off, so everything past the bezel stays as it is.
	if (shine > 0.0) {
		float x = clamp(1.0 - depth/max(bezel, 0.0001), 0.0, 1.0);
		vec3 N = vec3(n*x, sqrt(max(1.0 - x*x, 0.0)));
		const vec3 L = vec3(-0.4342, -0.6513, 0.6224); //normalize(-0.4, -0.6, 0.5734): top left, towards the viewer
		const vec3 H = vec3(-0.2410, -0.3615, 0.9007); //normalize(L + view)
		float nh = max(dot(N, H), 0.0);
		float s = nh*nh; s *= s; s *= s; s *= s; s *= s; //nh^32: a soft but tight highlight
		float flat_s = 0.0352;                          //H.z^32, what the flat top gets
		float highlight = max(s - flat_s, 0.0);
		float shade = dot(N, L) - L.z;                  //>0 facing the light, <0 facing away
		float fres = x*x*x;
		//smart: less over a bright backdrop (it would blow out), more while hovered (the rim is brighter then)
		float bright = dot(col, vec3(0.299, 0.587, 0.114));
		float amount = shine*(1.0 - 0.55*bright)*(0.6 + 0.6*rim.a);
		col += vec3(1.0)*highlight*0.55*amount;
		col *= 1.0 + clamp(shade, -1.0, 0.4)*0.14*shine;
		col += mix(vec3(1.0), rim.rgb, 0.5)*fres*0.06*amount;
		a = max(a, highlight*0.55*amount);
	}

	float ga = a*inside;
	float outa = ga + sh*(1.0 - ga);
	return vec4(clamp(col, 0.0, 1.0)*ga/max(outa, 0.0001), outa)*color;
}
]]

local function send(shader, name, ...)
	if shader:hasUniform(name) then
		shader:send(name, ...)
	end
end

function guiglass.load()
	local ok, err = pcall(function()
		blurshader = love.graphics.newShader(blurcode)
		glassshader = love.graphics.newShader(glasscode)
	end)
	if not ok then
		print("liquid glass: shaders unavailable, falling back to plain panels (" .. tostring(err) .. ")")
		supported = false
		return
	end
	mesh = love.graphics.newMesh({{0, 0, 0, 0}, {1, 0, 1, 0}, {1, 1, 1, 1}, {0, 1, 0, 1}}, "fan", "static")
	local data = love.image.newImageData(1, 1)
	data:setPixel(0, 0, 0, 0, 0, 0)
	dummy = love.graphics.newImage(data)
end

--Blurred copies of the canvases glass is drawn on. Each canvas is blurred at the frame's first panel on it, before
--any glass is on it, and every panel after that reads the same copy. It's never blurred again in the middle of a
--frame, so a blur never has glass in it (the editor's big background pane, say). Only clearing the canvas makes the
--next panel blur it again. Nothing is kept from one frame to the next.
local backdrops = setmetatable({}, {__mode = "k"}) --canvas → {a, b, w, h, frame}
local frame = 0 --every love.graphics.present() starts a new frame

local framebackdrop = false

local pushed = {} --the elements being drawn between guiglass.push and guiglass.pop, innermost last
--each element's shape on screen (see guiglass.hit)
local shapes = setmetatable({}, {__mode = "k"}) --element → {frame, ox, oy, ux, uy, vx, vy, w, h, r}

local function recordshape(x, y, w, h, r)
	local el = pushed[#pushed]
	if not el then
		return
	end
	local sh = shapes[el]
	if sh and sh.frame == frame then
		return --only the first panel: the element's own body, not what's drawn inside it
	end
	sh = sh or {}
	shapes[el] = sh
	local ox, oy = love.graphics.transformPoint(x, y)
	local ax, ay = love.graphics.transformPoint(x+w, y)
	local bx, by = love.graphics.transformPoint(x, y+h)
	sh.frame = frame
	sh.ox, sh.oy = ox, oy
	sh.ux, sh.uy = ax-ox, ay-oy --the panel's x axis on screen, w long
	sh.vx, sh.vy = bx-ox, by-oy --and its y axis, h long
	sh.w, sh.h, sh.r = w, h, math.min(r or 0, w/2, h/2)
end
guiglass.recordshape = recordshape
local lastbackdropframe = -math.huge --the last frame glass wanted a blurred backdrop

guiglass.debug = false --true: shows the glass state in the top left corner
local dbg = {with = 0, without = 0, nosrc = 0, src = "-"}
local dbgshown = {}

local present = love.graphics.present
function love.graphics.present(...)
	if guiglass.debug then
		dbgshown.text = string.format("glass: %s  backdrop %d  none %d  nosrc %d  src %s  wantscanvas %s",
			guiglass.mode(), dbg.with, dbg.without, dbg.nosrc, dbg.src, tostring(guiglass.wantscanvas()))
		love.graphics.push("all")
		love.graphics.setCanvas()
		love.graphics.origin()
		love.graphics.setScissor()
		love.graphics.setShader()
		love.graphics.setColor(0, 0, 0, 200)
		love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 14)
		love.graphics.setColor(255, 255, 0, 255)
		love.graphics.print(dbgshown.text, 2, 0)
		love.graphics.pop()
	end
	dbg.with, dbg.without, dbg.nosrc, dbg.src = 0, 0, 0, "-"
	frame = frame + 1
	if framebackdrop then
		lastbackdropframe = frame
	end
	framebackdrop = false
	return present(...)
end

--whether love.draw should draw the frame on a canvas first, so glass can read it back: only while glass wants a
--blurred backdrop (it's checked before the frame, so it goes by the last frames: a GUI showing up is plain for its
--first frame), never in flat
function guiglass.wantscanvas()
	return guiglass.mode() ~= "flat" and frame - lastbackdropframe < 30
end

--the quality in use now
function guiglass.mode()
	if not guiglass.enabled then
		return "flat"
	end
	return guiglass.quality
end

--Glass drawn on a canvas that started out transparent (a page drawn on its own canvas for a slide, the editor menu
--while it zooms in...) has nothing behind it on that canvas: what it goes over is on the canvas that was being drawn
--to before. So the canvas that was set before each canvas is remembered, and so is whether it was cleared to
--transparent, and such glass reads its backdrop from there.
local parentcanvas = setmetatable({}, {__mode = "k"}) --canvas → the canvas that was set before it
local transparent = setmetatable({}, {__mode = "k"})  --canvas → true when it was last cleared to transparent
local ownscratch = setmetatable({}, {__mode = "k"})   --the blurred copies themselves

local function firstcanvas(a)
	if type(a) == "table" then
		a = a[1]
		if type(a) == "table" then
			a = a[1]
		end
	end
	if type(a) == "userdata" then
		return a
	end
	return nil
end

local setcanvas = love.graphics.setCanvas
function love.graphics.setCanvas(...)
	local before = love.graphics.getCanvas()
	local after = firstcanvas((...))
	if after and after ~= before and not ownscratch[after] then
		parentcanvas[after] = before
	end
	return setcanvas(...)
end

local clear = love.graphics.clear
function love.graphics.clear(...)
	local canvas = love.graphics.getCanvas()
	if canvas then
		if backdrops[canvas] then
			backdrops[canvas].frame = -1
		end
		local n = select("#", ...)
		local a = select(4, ...)
		transparent[canvas] = (n == 0) or (type(a) == "number" and a == 0)
	end
	return clear(...)
end

--the canvas a panel drawn on canvas should read its backdrop from
local function backdropsource(canvas)
	local depth = 0
	while canvas and transparent[canvas] and parentcanvas[canvas] and depth < 8 do
		local parent = parentcanvas[canvas]
		--only one the same size, so a spot on one is the same spot on the other
		if parent:getWidth() ~= canvas:getWidth() or parent:getHeight() ~= canvas:getHeight() then
			break
		end
		canvas = parent
		depth = depth + 1
	end
	return canvas
end

--the blurred copy of src for a panel drawn on it, or nil
local function getbackdrop(src)
	local sw, sh = src:getDimensions()
	local ds = guiglass.downsample or scale
	local rw, rh = math.ceil(sw/ds), math.ceil(sh/ds)
	local bd = backdrops[src]
	if bd and bd.ds == ds and bd.w == rw and bd.h == rh and bd.frame == frame then
		--already blurred this frame, before any glass went on it
		return bd
	end
	if not bd or bd.w ~= rw or bd.h ~= rh then
		local ok, a = pcall(love.graphics.newCanvas, rw, rh)
		local ok2, b = pcall(love.graphics.newCanvas, rw, rh)
		if not (ok and ok2) then
			return nil
		end
		a:setFilter("linear", "linear")
		b:setFilter("linear", "linear")
		ownscratch[a], ownscratch[b] = true, true
		bd = {a = a, b = b, w = rw, h = rh}
		backdrops[src] = bd
	end

	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setScissor()
	love.graphics.setShader()
	love.graphics.setBlendMode("replace", "premultiplied")
	love.graphics.setColor(255, 255, 255, 255)

	--copy the canvas, shrunk
	love.graphics.setCanvas(bd.a)
	love.graphics.draw(src, 0, 0, 0, rw/sw, rh/sh)

	--blur it across, then down
	bd.region = {0.5/rw, 0.5/rh, 1-0.5/rw, 1-0.5/rh}
	send(blurshader, "region", bd.region)
	send(blurshader, "sigma", guiglass.blur*scale/ds)
	send(blurshader, "dir", {1/rw, 0})
	love.graphics.setCanvas(bd.b)
	love.graphics.setShader(blurshader)
	love.graphics.draw(bd.a, 0, 0)
	send(blurshader, "dir", {0, 1/rh})
	love.graphics.setCanvas(bd.a)
	love.graphics.draw(bd.b, 0, 0)
	love.graphics.pop()

	bd.frame = frame
	bd.ds = ds
	bd.scale = {1/sw, 1/sh} --uv per target pixel
	return bd
end

local function tocolor(c, fallback)
	c = c or fallback
	return (c[1] or 0)/255, (c[2] or 0)/255, (c[3] or 0)/255
end

--Draws a glass panel in the current coordinates (like love.graphics.rectangle("fill", x, y, w, h, r)).
--o (all optional):
--	tint = {r, g, b}       fill colour laid over the backdrop (0-255), black by default
--	tintstrength = 0-1     how much of it (guiglass.tintstrength by default)
--	rim = {r, g, b}        edge highlight colour, white by default
--	rimstrength = 0-1      edge highlight strength (0.55 by default)
--	alpha = 0-1            fades the whole panel
--	shadow = 0-1 or false  shadow opacity (0.28 by default)
--	nobackdrop = true      just a tinted pane: cheaper, for things inside another panel (highlights, pills)
--	glassalpha = 0-1       opacity of the pane where there is no backdrop to read
--	solid = true           the tint is shown as it is, not made clearer by guiglass.clarity (colour swatches)
--	base = true            other glass sits on it (a slider's track). Kept for the callers; every panel reads the
--	                       blur from before any glass now, so it changes nothing
function guiglass.panel(x, y, w, h, r, o)
	if supported and not glassshader then
		guiglass.load()
	end
	o = o or {}
	local alpha = o.alpha or 1
	if w <= 0 or h <= 0 or alpha <= 0 then
		return
	end
	local tr, tg, tb = tocolor(o.tint, {0, 0, 0})
	local rr, rg, rb = tocolor(o.rim, {255, 255, 255})

	--accessibility: reduce transparency takes the blur away from behind panels and makes them solid, and increase
	--contrast makes panels darker and their rims and highlights stronger (like iOS). Pills (nobackdrop: highlights,
	--dividers) keep their own see-through look, but get stronger with increase contrast
	local nobackdrop = o.nobackdrop
	local glassalpha = o.glassalpha or 0.82
	local tintstrength = o.tintstrength or guiglass.tintstrength
	local rimstrength = o.rimstrength or 0.55
	local pill = o.nobackdrop
	if accessibility and accessibility.reducetransparency and not pill then
		nobackdrop = true
		glassalpha = math.max(glassalpha, 0.94)
	end
	if accessibility and accessibility.increasecontrast then
		rimstrength = math.min(1, rimstrength*1.5 + 0.3)
		rr, rg, rb = rr + (1-rr)*0.4, rg + (1-rg)*0.4, rb + (1-rb)*0.4
		if pill then
			glassalpha = math.min(1, glassalpha*1.6)
		elseif not o.solid then
			tintstrength = math.max(tintstrength, 0.75)
			glassalpha = math.max(glassalpha, 0.92)
		end
	end

	if not supported then
		local cr, cg, cb, ca = love.graphics.getColor()
		love.graphics.setColor(rr*255, rg*255, rb*255, 255*alpha*rimstrength)
		love.graphics.rectangle("fill", x, y, w, h, r)
		love.graphics.setColor(tr*255, tg*255, tb*255, 255*alpha*glassalpha)
		love.graphics.rectangle("fill", x+scale, y+scale, w-2*scale, h-2*scale, r*0.7)
		love.graphics.setColor(cr, cg, cb, ca)
		return
	end

	local shadowamount = o.shadow
	if shadowamount == nil then
		shadowamount = 0.28
	elseif shadowamount == false then
		shadowamount = 0
	end
	local margin = 0
	if shadowamount > 0 then
		margin = math.max(2, scale*2.5)
	end

	--where the panel lands on the render target
	local x0, y0 = love.graphics.transformPoint(x-margin, y-margin)
	local x1, y1 = love.graphics.transformPoint(x+w+margin, y-margin)
	local x2, y2 = love.graphics.transformPoint(x+w+margin, y+h+margin)
	local x3, y3 = love.graphics.transformPoint(x-margin, y+h+margin)
	local minx, maxx = math.min(x0, x1, x2, x3), math.max(x0, x1, x2, x3)
	local miny, maxy = math.min(y0, y1, y2, y3), math.max(y0, y1, y2, y3)

	--skip it entirely when the scissor hides it
	local scx, scy, scw, sch = love.graphics.getScissor()
	if scx and (maxx <= scx or minx >= scx+scw or maxy <= scy or miny >= scy+sch) then
		return
	end

	local ox, oy = love.graphics.transformPoint(0, 0)
	local ux, uy = love.graphics.transformPoint(1, 0)
	local vx, vy = love.graphics.transformPoint(0, 1)
	local unit = math.min(math.sqrt((ux-ox)^2+(uy-oy)^2), math.sqrt((vx-ox)^2+(vy-oy)^2))
	local aa = 1/math.max(unit, 0.001)

	local hasbackdrop = 0
	local backdrop
	local uvscale, uvclamp = NOSCALE, NOCLAMP
	local src = backdropsource(love.graphics.getCanvas())
	if pushed[1] then
		recordshape(x, y, w, h, r)
	end
	local wants = guiglass.mode() ~= "flat" and not nobackdrop
	if wants then
		framebackdrop = true
	end
	if wants and src and src.getDimensions then
		backdrop = getbackdrop(src)
		if backdrop then
			hasbackdrop = 1
			uvscale = backdrop.scale
			uvclamp = backdrop.region
		end
	end
	if guiglass.debug and wants then
		if backdrop then
			dbg.with = dbg.with + 1
			dbg.src = src:getWidth() .. "x" .. src:getHeight() .. (transparent[src] and " transparent" or "")
		elseif not src then
			dbg.nosrc = dbg.nosrc + 1
		else
			dbg.without = dbg.without + 1
		end
	end

	--every setting goes in one send (u in the shader), with its tables reused
	local tint = tintstrength
	if not (o.base or o.solid) then
		tint = tint*guiglass.clarity
	end
	setu(1, uvscale[1], uvscale[2], w, h)
	setu(2, uvclamp[1], uvclamp[2], uvclamp[3], uvclamp[4])
	setu(3, tr, tg, tb, tint)
	setu(4, rr, rg, rb, rimstrength)
	setu(5, margin, r or 0, aa, guiglass.refraction*scale)
	--the bent edge: about a third of a small panel, but never more than 6 game pixels (a big panel bends at its edge,
	--and its middle is cheap to draw)
	local bezel = math.min(math.max(3*scale, math.min(w, h)*0.35), math.min(w, h)*0.5, 6*scale)
	setu(6, bezel, shadowamount, glassalpha, hasbackdrop)
	local shader = glassshader
	local image = dummy
	if backdrop then
		image = backdrop.a
	end
	if image ~= sentimage then
		shader:send("backdrop", image)
		sentimage = image
	end
	if guiglass.shine ~= sentshine then
		shader:send("shine", guiglass.shine)
		sentshine = guiglass.shine
	end
	shader:send("u", u[1], u[2], u[3], u[4], u[5], u[6])

	local prevshader = love.graphics.getShader()
	local cr, cg, cb, ca = love.graphics.getColor()
	local bm, am = love.graphics.getBlendMode()
	love.graphics.setBlendMode("alpha")
	love.graphics.setShader(shader)
	love.graphics.setColor(255, 255, 255, 255*alpha)
	love.graphics.draw(mesh, x-margin, y-margin, 0, w+2*margin, h+2*margin)
	love.graphics.setShader(prevshader)
	love.graphics.setBlendMode(bm, am)
	love.graphics.setColor(cr, cg, cb, ca)
end

--a cheap pane for things that sit on top of another panel (a hovered option, a divider...)
function guiglass.pill(x, y, w, h, r, color, rimstrength, alpha)
	guiglass.panel(x, y, w, h, r, {
		nobackdrop = true,
		shadow = false,
		tint = color,
		glassalpha = (color[4] or 255)/255,
		rimstrength = rimstrength or 0.3,
		alpha = alpha,
	})
end

------------------------------------------------------------
-- motion
------------------------------------------------------------

local function ease_out_cubic(t)
	t = math.max(0, math.min(1, t))
	return 1 - (1-t)^3
end

local function getstate(el)
	local st = state[el]
	if not st then
		st = {ox = 0, oy = 0, s = 1, v = 0, hs = 1, phase = "idle", last = love.timer.getTime()}
		state[el] = st
	end
	return st
end
guiglass.state = getstate

--the element was clicked: squash it wide and hold it there
function guiglass.press(el)
	local st = getstate(el)
	st.phase = "press"
	st.t0 = love.timer.getTime()
	st.from = st.s
	el.glassreleased = false
end

--the mouse button came up: the next frame starts the jelly
function guiglass.release(el)
	el.glassreleased = true
end

--Works out an element's motion for this frame. cx, cy is its centre and w, h its size (local pixels),
--hovering whether the mouse is really over it (for the lean and hover growth; a press holds until the button comes up
--wherever the mouse is). o.nomagnet stops the lean, o.hoverscale grows it while hovered.
--Returns the lean (ox, oy) and the scale (sx, sy).
function guiglass.motion(el, cx, cy, w, h, hovering, o)
	local st = getstate(el)
	local now = love.timer.getTime()
	local dt = math.min(math.max(now - st.last, 0), 1/20)
	st.last = now

	--magnet: lean towards the mouse, lerped
	local tx, ty = 0, 0
	if hovering and not (o and o.nomagnet) then
		local mx, my
		if el.mousepos then
			mx, my = el:mousepos()
		else
			mx, my = love.mouse.getPosition()
		end
		tx, ty = (mx-cx)*MAGNET_PULL, (my-cy)*MAGNET_PULL
		local maxdistance = math.sqrt(w*w + h*h)*MAGNET_MAX
		local distance = math.sqrt(tx*tx + ty*ty)
		if distance > maxdistance then
			tx, ty = tx*maxdistance/distance, ty*maxdistance/distance
		end
	end
	local f = 1 - math.exp(-dt*MAGNET_SPEED)
	st.ox = lerp(st.ox, tx, f)
	st.oy = lerp(st.oy, ty, f)
	local hovertarget = 1
	if hovering and o and o.hoverscale then
		hovertarget = o.hoverscale
	end
	st.hs = lerp(st.hs, hovertarget, f)

	--press: ease out into the wide squash, and hold it until the mouse button comes up, wherever the mouse is
	--(the button being up at all also counts, in case the release went somewhere else)
	if st.phase == "press" then
		local held = love.mouse.isDown(1) or love.mouse.isDown(2) or love.mouse.isDown(3)
		if el.glassreleased or not held then
			st.phase = "jelly"
			st.v = 0
		else
			st.s = lerp(st.from, PRESS_STRETCH, ease_out_cubic((now - st.t0)/PRESS_TIME))
		end
	end

	--jelly: a bouncy spring back to the normal shape
	if st.phase == "jelly" then
		local steps = 4
		local h2 = dt/steps
		for _ = 1, steps do
			local acc = -SPRING_K*(st.s-1) - SPRING_D*st.v
			st.v = st.v + acc*h2
			st.s = st.s + st.v*h2
		end
		if math.abs(st.s-1) < 0.0005 and math.abs(st.v) < 0.01 then
			st.s, st.v, st.phase = 1, 0, "idle"
		end
	end

	--reduce motion (accessibility): the element stays where it is, at its size
	if accessibility and accessibility.reducemotion then
		return 0, 0, 1, 1
	end

	local s = math.max(st.s, 0.2)
	return st.ox, st.oy, s*st.hs, st.hs/s
end

--motion as a transform: everything drawn until guiglass.pop() leans, squashes and wobbles with the element
function guiglass.push(el, cx, cy, w, h, hovering, o)
	local ox, oy, sx, sy = guiglass.motion(el, cx, cy, w, h, hovering, o)
	love.graphics.push()
	love.graphics.translate(cx+ox, cy+oy)
	love.graphics.scale(sx, sy)
	love.graphics.translate(-cx, -cy)
	table.insert(pushed, el)
end

function guiglass.pop()
	table.remove(pushed)
	love.graphics.pop()
end

------------------------------------------------------------
-- hover by the element's real shape
------------------------------------------------------------

--The first glass panel an element draws between guiglass.push and guiglass.pop is its shape on screen: where it sits
--after leaning, growing on hover and squashing, with its round corners. guiglass.hit tests the mouse against that, so
--an element counts as hovered exactly while the mouse is on what you see (and stays hovered while it grows towards
--the mouse), instead of on a fixed rectangle.

--whether (mx, my) (render target pixels, like love.mouse.getPosition) is on el's shape as it was last drawn.
--nil when el hasn't been drawn with glass lately (the caller falls back to its own rectangle then)
function guiglass.hit(el, mx, my)
	local sh = shapes[el]
	if not sh or frame - sh.frame > 2 then
		return nil
	end
	--back into the panel's own coordinates
	local det = sh.ux*sh.vy - sh.uy*sh.vx
	if math.abs(det) < 1e-9 then
		return false
	end
	local dx, dy = mx - sh.ox, my - sh.oy
	local s = (dx*sh.vy - dy*sh.vx)/det
	local t = (sh.ux*dy - sh.uy*dx)/det
	local lx, ly = s*sh.w, t*sh.h
	--the rounded box: inside when the distance to its edge is at most 0
	local hw, hh, r = sh.w/2, sh.h/2, sh.r
	local qx = math.abs(lx - hw) - hw + r
	local qy = math.abs(ly - hh) - hh + r
	local outside = math.sqrt(math.max(qx, 0)^2 + math.max(qy, 0)^2) + math.min(math.max(qx, qy), 0) - r
	return outside <= 0
end

------------------------------------------------------------
-- curves for popping things in and out
------------------------------------------------------------

--0 → 1 with a wobble (t in seconds), settles in about two thirds of a second
function guiglass.jellyin(t)
	if t <= 0 then
		return 0
	end
	--reduce motion (accessibility): no bounce. Callers draw this with motion_scale, which fades instead of scaling
	if accessibility and accessibility.reducemotion then
		return 1 - math.exp(-t*12)
	end
	return 1 - math.exp(-t*8)*math.cos(t*17)
end

--1 → 0, swelling first (u from 0 to 1)
function guiglass.jellyout(u)
	u = math.max(0, math.min(1, u))
	--reduce motion (accessibility): no swell, just away
	if accessibility and accessibility.reducemotion then
		return 1 - u
	end
	return 1 - (3.4*u*u*u - 2.4*u*u)
end

--the width that goes with a jelly height, so it bulges sideways as it squashes
function guiglass.jellywidth(sy, amount)
	return math.max(0.8, math.min(1.45, 1 - (amount or 0.6)*(sy-1)))
end

--A popup box: glass with a bright rim, where the game used to draw a black box with a white outline (prompts, the
--pause menu, notices...). Same arguments as love.graphics.rectangle("fill", x, y, w, h, r), alpha fades it (0-1).
--o (optional): rim, rimstrength, tintstrength like guiglass.panel
function guiglass.box(x, y, w, h, r, alpha, o)
	o = o or {}
	guiglass.panel(x, y, w, h, r, {
		rim = o.rim or {255, 255, 255},
		rimstrength = o.rimstrength or 0.85,
		tintstrength = o.tintstrength or 0.55,
		alpha = alpha or 1,
		shadow = 0.35,
	})
end

------------------------------------------------------------
-- rounded clipping for pictures (mappack icons, minigame graphics)
------------------------------------------------------------

local roundcode = [[
extern vec4 rect;    //the rounded box on the target: left, top, right, bottom (target pixels)
extern float radius; //target pixels
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
	vec4 c = Texel(tex, tc)*color;
	vec2 hb = (rect.zw - rect.xy)*0.5;
	float r = min(radius, min(hb.x, hb.y));
	vec2 q = abs(sc - (rect.xy + rect.zw)*0.5) - hb + r;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	c.a *= clamp(0.5 - d, 0.0, 1.0);
	return c;
}
]]
local roundshader
local roundsupported = true
local roundstack = {}
local roundrect = {0, 0, 0, 0}

--Everything drawn until guiglass.endround() is cut to a box with round corners: x, y, w, h and r in the current
--coordinates (like love.graphics.rectangle). Works with the transform (the frames' press and jelly), no stencil needed.
function guiglass.beginround(x, y, w, h, r)
	if roundsupported and not roundshader then
		local ok, shader = pcall(love.graphics.newShader, roundcode)
		if ok then
			roundshader = shader
		else
			roundsupported = false
		end
	end
	table.insert(roundstack, love.graphics.getShader() or false)
	if not roundshader then
		return
	end
	local x0, y0 = love.graphics.transformPoint(x, y)
	local x1, y1 = love.graphics.transformPoint(x+w, y+h)
	local ox, oy = love.graphics.transformPoint(0, 0)
	local ux, uy = love.graphics.transformPoint(1, 0)
	local vx, vy = love.graphics.transformPoint(0, 1)
	local unit = (math.sqrt((ux-ox)^2+(uy-oy)^2) + math.sqrt((vx-ox)^2+(vy-oy)^2))/2
	roundrect[1], roundrect[2] = math.min(x0, x1), math.min(y0, y1)
	roundrect[3], roundrect[4] = math.max(x0, x1), math.max(y0, y1)
	roundshader:send("rect", roundrect)
	roundshader:send("radius", r*unit)
	love.graphics.setShader(roundshader)
end

function guiglass.endround()
	local previous = table.remove(roundstack)
	if previous then
		love.graphics.setShader(previous)
	else
		love.graphics.setShader()
	end
end

--the corner radius (game pixels) for a picture inset by inset game pixels in a glass button, so its corners
--run alongside the button's (the button's radius is 0.3 of its shorter side)
function guiglass.insetradius(button, inset)
	local bw = 3 + button.width + button.space*2
	local bh = 1 + button.height*10 + button.space*2
	return math.max(1, math.min(bw, bh)*0.3 - inset)
end