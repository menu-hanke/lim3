local coding = require "metsi.coding"
local vdata = require "metsi.vdata"
local pine, spruce, xconiferous = coding.spe.pine, coding.spe.spruce, coding.spe.xconiferous
local xd, xh, vtotm, vtukm, vlatm, vtotk, vtukk, vlatk, vtotko, vtukko, vlatko = vdata.xd, vdata.xh,
	vdata.vtotm, vdata.vtukm, vdata.vlatm, vdata.vtotk, vdata.vtukk, vdata.vlatk, vdata.vtotko,
	vdata.vtukko, vdata.vlatko
local max, min = math.max, math.min

local vmin = 0.0004
local vmax = 0.00101788
local hmin = 0.00001

local function biint(ya, d, h)
    local j = math.floor(max(d-2, 0))
    local k = math.floor(max(h-2, 0))
    local y1 = ya[38*j     + k]
    local y2 = ya[38*(j+1) + k]
    local y3 = ya[38*(j+1) + k+1]
    local y4 = ya[38*j     + k+1]
    local t = (d - xd[j])/(xd[j+1] - xd[j])
    local u = (h - xh[k])/(xh[k+1] - xh[k])
    return (1-t)*(1-u)*y1 + t*(1-u)*y2 + t*u*y3 + (1-t)*u*y4
end

local function vol(spe, d, h)
	local tot, tuk, lat
	if spe == pine or spe == xconiferous then
		tot, tuk, lat = vtotm, vtukm, vlatm
	elseif spe == spruce then
		tot, tuk, lat = vtotk, vtukk, vlatk
	else
		tot, tuk, lat = vtotko, vtukko, vlatko
	end
	local id = min(d, 59)
	local ih = min(h, 38)
	local ytuk = biint(tuk, id, ih)
	local ytot, ylat
	if h < hmin then
		ytot, ylat = 0, 0
	else
		ytot = biint(tot, id, ih)
		if ytot < vmin then
			ytot = max(min(h*math.pi*((1.2*d/200)^2)/3, vmax), vmin)
			ylat = ytot
		else
			ylat = biint(lat, id, ih)
		end
	end
    return ytot, ytuk, ytot - ytuk - ylat, ylat
end

return {
	vol = vol
}
