local ffi = require "ffi"
local exp = math.exp
local mm = require "metsi.math"
local choose = mm.choose
local coding = require "metsi.coding"
local pine, spruce, silver_birch, downy_birch, aspen, gray_alder, black_alder, xconiferous, xdeciduous
	= coding.spe.pine, coding.spe.spruce, coding.spe.silver_birch, coding.spe.downy_birch, coding.spe.aspen, coding.spe.gray_alder, coding.spe.black_alder, coding.spe.xconiferous, coding.spe.xdeciduous
local OMaT, OMT, VT, CT, ClT, ROCK, MTN
	= coding.mty.OMaT, coding.mty.OMT, coding.mty.VT, coding.mty.CT, coding.mty.ClT, coding.mty.ROCK, coding.mty.MTN
local STONY, WET, MOSS = coding.verlt.stony, coding.verlt.wet, coding.verlt.moss
local dkan = require "metsi.dkan"

local PP = ffi.new("double[9]", { 2.067, 1.593, 2.218, 1.855, 2.218, 1.855, 1.855, 2.067, 1.855 })
local P = ffi.new("double[68]", {
	-- pine & other conifers
	0.0007666,-0.17,-0.4268,-0.003178,-0.003178, 0.03012,
	0.07614,-0.7614, 0.05279, 0.01913, 0.08891, 0.10120, 0.1459,
	-0.3249,-0.03374,-0.35, 0.01252,
	-- spruce
	0.0032920,-0.16,-0.1645,-0.020720, 0.002699, 0.01562,
	0.05627,-0.9653, 0.04533, 0.03494, 0.06530,-0.03203,-0.05316,
	-0.4245,-0.06554, 0.00,0.03391,
	-- silver birch and aspen
	0.00068284, 0.00, 0.0000, 0.000000, 0.000000, 0.00000,
	0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,
	-- other deciduous
	0.001914, 0.00, 0.0000, 0.000000, 0.000000, 0.00000,
	0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.
})

local PBASE = {
	[pine]         = 0*17,
	[spruce]       = 1*17,
	[silver_birch] = 2*17,
	[downy_birch]  = 3*17,
	[aspen]        = 2*17,
	[gray_alder]   = 3*17,
	[black_alder]  = 3*17,
	[xconiferous]  = 0*17,
	[xdeciduous]   = 3*17
}

-- heath/ccf.FOR  GetCcf
local function ccf(d, f, spe, mty, verlt, lake, sea, Z, dd)
	local p0 = PBASE[spe]
	local y =
		  P[p0+3]  * choose(mty == OMaT)
		+ P[p0+4]  * choose(mty == OMT)
		+ P[p0+5]  * choose(mty == VT)
		+ P[p0+6]  * choose(mty == CT)
		+ P[p0+7]  * choose(mty >= ClT)
		+ P[p0+8]  * choose(verlt == STONY)
		+ P[p0+9]  * choose(verlt == WET)
		+ P[p0+10] * choose(verlt == MOSS)
		+ P[p0+11] * lake
		+ P[p0+12] * sea
		+ P[p0+13]/1000 * Z
		+ P[p0+14]/1000000 * dd * Z
		+ choose(mty >= ClT, (P[p0+15] + dd/1000)^P[p0+16])
    local c0_1 = (P[p0]/1000) * (P[p0+1] + dd/1000)^P[p0+2] * exp(y)
    local draj = dkan.dk(8)
	local xnn
	local pp = -PP[spe-1]
    if dkan.dk(d) < draj then
        local xn0 = draj^pp / c0_1
        local xd0 = pp*draj^(pp-1) / c0_1
        xnn = (xn0-xd0*draj)+dkan.dk(d)*xd0
	else
        xnn = dkan.dk(d)^pp / c0_1
	end
	if xnn > 0 then
		local kal = mty == ROCK and 0.6 or 1.0
		local lak = mty == MTN  and 0.5 or 1.0
        return kal * lak * f / xnn
	else
        return 0
	end
end

--------------------------------------------------------------------------------

return {
	ccf = ccf
}
