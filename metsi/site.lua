-- site variables.
local coding = require "metsi.coding"
local lower, upper = coding.storie.lower, coding.storie.upper
local PINE, SPRUCE, SILVER_BIRCH, DOWNY_BIRCH, ASPEN =
	coding.spe.pine, coding.spe.spruce, coding.spe.silver_birch, coding.spe.downy_birch, coding.spe.aspen
local OMT, MT, VT, CT = coding.mty.OMT, coding.mty.MT, coding.mty.VT, coding.mty.CT
local MINERAL, PEAT_SPRUCE, PEAT_PINE = coding.alr.mineralsoil, coding.alr.peat_spruce, coding.alr.peat_pine
local RHTKG1, MTKG1, MTKG2, PTKG1, PTKG2, VATKG1, JATK =
	coding.tkg.RHTKG1, coding.tkg.MTKG1, coding.tkg.MTKG2, coding.tkg.PTKG1, coding.tkg.PTKG2, coding.tkg.VATKG1, coding.tkg.JATK
local mm = require "metsi.math"

local function kx100storie(which, grow, spedom, prt, spe, storie, snt, xs, fs, js)
	local lim = 100
	local s, num = 0, 0
	for j=0, #js-1 do
		local i = js[j]
		if snt[i] == prt and storie[i] == which and (which ~= grow or spe[i] == spedom) then
			local f, x = fs[i], xs[i]
			if num+f >= lim then
				s = s + (lim-num)*x
				return s/lim
			end
			s, num = s+f*x, num+f
		end
	end
	for j=0, #js-1 do
		local i = js[j]
		if snt[i] ~= prt and storie[i] == which and (which ~= grow or spe[i] == spedom) then
			local f,x = fs[i], xs[i]
			if num+f >= lim then
				s = s + (lim-num)*x
				return s/lim
			end
			s, num = s+f*x, num+f
		end
	end
	if num > 0 then
		return s/num
	else
		return 0
	end
end

local function x100storie(which)
	which = mm.label(which)
	return function(...) return kx100storie(which, ...) end
end

local function kdgstorie(which, grow, spedom, spe, storie, fs, ds)
	local s3, s2 = 0, 0
	for i=0, #fs-1 do
		if storie[i] == which and (which ~= grow or spe[i] == spedom) then
			local f = fs[i]
			local d = ds[i]
			s2 = s2 + f*d^2
			s3 = s3 + f*d^3
		end
	end
	if s2 > 0 then
		return s3/s2
	else
		return 0
	end
end

local function dgstorie(which)
	which = mm.label(which)
	return function(...) return kdgstorie(which, ...) end
end

local function h100_grow(h100_lower, h100_upper, g_grow, grow)
	if g_grow > 0 then
		local h100 = grow == coding.storie.lower and h100_lower or h100_upper
		if h100 > 0 then
			return 0
		end
	end
	-- TODO: growing stratum
	return 0
end

local function dgdom(grow, spedom, ss, spe, ds, fs)
	local sg, so = 0, 0
	local wg, wo = 0, 0
	local other = 3 - grow -- flip 1 <-> 2
	for i=0, #ds-1 do
		local x = fs[i]*ds[i]^3
		local w = fs[i]*ds[i]^2
		if ss[i] == grow and spe[i] == spedom then
			sg, wg = sg+x, wg+w
		elseif ss[i] == other then
			so, wo = so+x, wo+w
		end
	end
	if wg > 0 then
		return sg/wg
	elseif wo > 0 then
		return so/wo
	else
		return 0
	end
end

local function spedom(spe, g)
	local speg = {}
	local gmax, spemax = 0, 0
	for i=0, #spe-1 do
		local s = spe[i]
		local gs = (speg[s] or 0) + g[i]
		speg[s] = gs
		if gs >= gmax then
			gmax, spemax = gs, s
		end
	end
	return spemax
end

local function hdomg(h, g, f, order)
	local rem, HG, G = 100, 0, 0
	for i=0, #order-1 do
		local j = order[i]
		if f[j] >= rem then
			HG = HG + h[j]*rem*g[j]
			G = G + rem*g[j]
			break
		else
			rem = rem - f[j]
			HG = HG + h[j]*f[j]*g[j]
			G = G + f[j]*g[j]
		end
	end
	if G > 0 then
		return HG/G
	else
		return 0
	end
end

local function hdoma(h, f, order)
	local rem, hw, w = 100, 0, 0
	for i=0, #order-1 do
		local j = order[i]
		if f[j] >= rem then
			hw = hw + h[j]*rem
			w = w + rem
			break
		else
			rem = rem - f[j]
			hw = hw + h[j]*f[j]
			w = w + f[j]
		end
	end
	if w > 0 then
		return hw/w
	else
		return 0
	end
end

local function promote(flo, fup, h100lo, h100up)
	return fup == 0 or h100up - h100lo <= 5 or flo <= 250
end

local function contains(xs, x)
	for i=0, #xs-1 do
		if xs[i] == x then
			return true
		end
	end
	return false
end

local function growst(spedom, storie, spe)
	local haveupper = contains(storie, upper)
	local havelower = contains(storie, lower)
	local small = false -- TODO: small trees
	if (havelower or small) and haveupper then
		for i=0, #storie-1 do
			if storie[i] == upper and spe[i] == spedom then
				return upper
			end
		end
		return lower
	else
		return upper
	end
end

local function grel_pine(Gpine, G, spedom)
	if G > 0 then
		return Gpine / G
	elseif spedom <= SPRUCE then
		return 0.8
	else
		return 0.2
	end
end

local function grel_birch(Gbirch, G, spedom)
	if G > 0 then
		return Gbirch / G
	elseif spedom <= SPRUCE then
		return 0.2
	else
		return 0.8
	end
end

local function pdr(ojik, dd, V)
	if ojik == 1 then return false end
	local vlim = dd >= 1000 and 125 or 150
	return V < vlim
end

local function tkg(mty, alr, spedom)
	if mty <= OMT and alr > MINERAL then
		return RHTKG1
	end
	if mty == MT and alr > MINERAL and (spedom == 0 or spedom == PINE or spedom == DOWNY_BIRCH) then
		return MTKG2
	end
	if mty == MT and alr > MINERAL and (spedom == SPRUCE or spedom == SILVER_BIRCH or spedom == ASPEN) then
		return MTKG1
	end
	if mty == VT and alr == PEAT_PINE and (spedom == 0 or spedom == PINE or spedom == DOWNY_BIRCH) then
		return PTKG2
	end
	if mty == VT and alr > MINERAL and (spedom == SPRUCE or spedom == SILVER_BIRCH) then
		return PTKG1
	end
	if mty == VT and alr == PEAT_SPRUCE then
		return PTKG1
	end
	if mty == CT and alr > MINERAL then
		return VATKG1
	end
	if mty > CT and alr > MINERAL then
		return JATK
	end
	return 0
end

return {
	x100storie = x100storie,
	dgstorie   = dgstorie,
	h100_grow  = h100_grow,
	dgdom      = dgdom,
	spedom     = spedom,
	hdomg      = hdomg,
	hdoma      = hdoma,
	hdom       = hdoma,
	promote    = promote,
	growst     = growst,
	grel_pine  = grel_pine,
	grel_birch = grel_birch,
	pdr        = pdr,
	tkg        = tkg
}
