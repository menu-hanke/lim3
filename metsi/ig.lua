local ffi = require "ffi"
local abs, exp, max, min, log = math.abs, math.exp, math.max, math.min, math.log
local mm = require "metsi.math"
local choose, d2gu, sgn1 = mm.choose, mm.d2gu, mm.sgn1
local coding = require "metsi.coding"
local pine, spruce, silver_birch, downy_birch, aspen, gray_alder, black_alder, xconiferous, xdeciduous
	= coding.spe.pine, coding.spe.spruce, coding.spe.silver_birch, coding.spe.downy_birch, coding.spe.aspen, coding.spe.gray_alder, coding.spe.black_alder, coding.spe.xconiferous, coding.spe.xdeciduous
local OMaT, OMT, VT, CT, ClT, ROCK, MTN
	= coding.mty.OMaT, coding.mty.OMT, coding.mty.VT, coding.mty.CT, coding.mty.ClT, coding.mty.ROCK, coding.mty.MTN
local scrub, waste = coding.mal.scrub, coding.mal.waste
local planted = coding.snt.planted
local dkan = require "metsi.dkan"

---- kasvu latvussuhteen kanssa  heath/Figcrperus.FOR ----------------------------------------

local function idcr(
	cr, dk, snt,
	A, B, kor, pf21, pf22, pf23, pf29, pf33, pf39, pf40)
    local didmax = (2+1.25*10)/A
    local xm0 = (
        -.00889
        + 1.55243  * didmax
        - 1.02468  * didmax^2
        + 11.75567 * didmax^3
    )
    local xm = xm0*(1+pf29)*(1-cr)
	if abs(xm-1) < 0.01 then
		xm = 1 + 0.01*sgn1(xm-1)
	end
    local xk = (2*xm+2)/(1-xm^2)
    local xn = A^(1-xm)*xk
    local bd = xn*dk^xm-xk*dk
    local bd = max(bd, 0.0001)
    local dki = (
        log(bd) + B
        + pf33 * choose(snt == planted)
        + pf21 * log(cr)
        + pf22 * log(cr) * dk
        + pf23 * log(cr)^2
        + (pf39+pf40)/2
    )
    return exp(dki*kor)/1.25
end

local PLKORCR = {1, 1, 1, 1, 0.99, 0.98, 0.97, 0.96, 0.95}
local function figucr(
	spe, d, dk, cr, crkor, snt,
	mty, dd)
	local pf1,  pf2,  pf3,  pf4,  pf5,  pf6,  pf7,  pf8,  pf9
	local pf11, pf12, pf13, pf14, pf15, pf16, pf17, pf18, pf19
	local pf21, pf22, pf23,                               pf29
	local             pf33,                               pf39, pf40
	if spe == pine or spe == xconiferous then
		pf1  = 1.500
		pf2  = -0.80
		pf3  = -0.80
		pf4  = 9.20
		pf5  = -1.79
		pf6  = -10.26
		pf7  = -10.26
		pf8  = 26.80
		pf9  = 0.
		pf11 = -3.715
		pf12 = .013
		pf13 = .013
		pf14 = 0.
		pf15 = .085
		pf16 = .588
		pf17 = .588
		pf18 = .432
		pf19 = 0.
		pf21 = 0.445
		pf22 = 0.
		pf23 = 0.
		pf29 = 4.3
		pf33 = .429
		pf39 = .133
		pf40 = .165
	elseif spe == spruce then
		pf1  = 1.500
		pf2  = 0.
		pf3  = 0.
		pf4  = 26.03
		pf5  = -9.52
		pf6  = -9.52
		pf7  = -9.52
		pf8  = 10.11
		pf9  = 0.
		pf11 = -4.530
		pf12 = .133
		pf13 = .159
		pf14 = 0.
		pf15 = .471
		pf16 = .471
		pf17 = .471
		pf18 = .831
		pf19 = 0.
		pf21 = 1.816
		pf22 = 0.
		pf23 = 0.
		pf29 = 0.0
		pf33 = .401
		pf39 = .087
		pf40 = .235
	elseif spe == silver_birch or spe == aspen then
		pf1  = 1.500
		pf2  = 0.
		pf3  = 0.
		pf4  = 21.10
		pf5  = 0.
		pf6  = 0.
		pf7  = 0.
		pf8  = 12.70
		pf9  = 0.
		pf11 = -3.086
		pf12 = .044
		pf13 = -.105
		pf14 = 0.
		pf15 = 0.
		pf16 = 0.
		pf17 = 0.
		pf18 = -0.317
		pf19 = 0.
		pf21 = 0.528
		pf22 = 0.
		pf23 = 0.
		pf29 = 4.4
		pf33 = 0.
		pf39 = .150
		pf40 = .336
	else
		pf1  = 1.500
		pf2  = 0.
		pf3  = 0.
		pf4  = 20.80
		pf5  = 0.
		pf6  = 0.
		pf7  = 0.
		pf8  = 6.40
		pf9  = 0.
		pf11 = -1.468
		pf12 = .044
		pf13 = -.105
		pf14 = 0.
		pf15 = 0.
		pf16 = 0.
		pf17 = 0.
		pf18 = -1.710
		pf19 = 0.
		pf21 = 0.528
		pf22 = 0.
		pf23 = 0.
		pf29 = 4.4
		pf33 = 0.
		pf39 = .150
		pf40 = .336
	end
	local kor = PLKORCR[spe]
	local A = pf1 * (
		pf8 + (
			pf4
			+ pf2 * choose(mty == OMaT)
			+ pf3 * choose(mty == OMT)
			+ pf5 * choose(mty == VT)
			+ pf6 * choose(mty == CT)
			+ pf7 * choose(mty == ClT)
		) * dd/1000
		+ pf9 * (dd/1000)^2
	)
	local B = pf11
		+ pf12 * choose(mty == OMaT)
		+ pf13 * choose(mty == OMT)
		+ pf14 * choose(mty == MT)
		+ pf15 * choose(mty == VT)
		+ pf16 * choose(mty == CT)
		+ pf17 * choose(mty == ClT)
		+ pf18 * dd/1000
		+ pf19 * (dd/1000)^2
	local id1 = idcr(cr, dk, snt, A, B, kor, pf21, pf22, pf23, pf29, pf33, pf39, pf40)
	local id2 = idcr(cr+crkor, dk, snt, A, B, kor, pf21, pf22, pf23, pf29, pf33, pf39, pf40)
	return (d2gu(d+id1)-d2gu(d))/(d2gu(d+id2)-d2gu(d))
end

---- yleinen kasvufunktio   heath/Figuperus.FOR ----------------------------------------

local PF = ffi.new("double[200]", {
	-- pine/other coniferous
	 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,   0.00, 0.00, 0.00, 0.00,
	 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,    0.00, 0.00, 0.00, 0.00,
	-3.95, 0.02, 0.02,-0.09,-0.34,-0.4,    0.00, 0.00, 0.00,  0.95,
	-1.83, 0.00, 0.00, 0.00,-0.20, 0.00,  0.00,  0.00,-0.92, 0.00,
	 65.2, 0.00,   2.00, 0.00, 16.3, 0.00, 0.00, 0.00, 0.21, .276,
	-- spruce
	 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,   0.00, 0.00, 0.00, 0.00,
	 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,    0.00, 0.00, 0.00, 0.00,
	-5.47, 0.30, 0.22,-0.12,-0.7,-0.8,    0.00, 0.00, 0.00,  1.61,
	-1.51, 0.46, 0.00, 0.60,-1.76, 1.08,  0.00,  1.20,-0.50, 0.00,
	 99.2, 0.00,   2.00, 0.00, 8.22, 0.00, 0.00, 0.00, 0.41, .288,
	-- silver birch & aspen
	 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,   0.00, 0.00, 0.00, 0.00,
	 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,    0.00, 0.00, 0.00, 0.00,
	-4.64, 0.17, 0.17, -0.2,-0.7,-0.8,    0.00, 0.00, 0.00,  1.30,
	-0.50, 0.00, 0.00, 0.00,-2.25, 0.00,  0.00,  0.00,-1.81, 0.00,
	 56.7, 0.00,   1.00, 0.00, 16.2, 0.00, 0.00, 0.00, 0.00, .583,
	-- other
	 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,   0.00, 0.00, 0.00, 0.00,
	 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,    0.00, 0.00, 0.00, 0.00,
	-4.63, 0.17, 0.17, -0.15,-0.4,-0.5,    0.00, 0.00, 0.00,  0.61,
	-0.21, 0.00, 0.00, 0.00,-2.25, 0.00,  0.00,  0.00,-1.32, 0.00,
	 66.7, 0.00,   1.00, 0.00,  8.7, 0.00, 0.00, 0.00, 0.00, .630
})

local PFBASE = {
	[pine]         = 0*50,
	[spruce]       = 1*50,
	[silver_birch] = 2*50,
	[downy_birch]  = 3*50,
	[aspen]        = 2*50,
	[gray_alder]   = 3*50,
	[black_alder]  = 3*50,
	[xconiferous]  = 0*50,
	[xdeciduous]   = 3*50
}

local function idk(
	spe, dk, rdfL, rdfLma, rdfLku, rdfLlehti,
	mty, dd, rdf, rdfma, rdfku, rdflehti, rdfmet, jd)
	local pf0 = PFBASE[spe]
	local A = PF[pf0+40] + PF[pf0+41] * (
		  PF[pf0+0]
		+ PF[pf0+1] * choose(mty == OMaT)
		+ PF[pf0+2] * choose(mty == OMT)
		+ PF[pf0+3] * choose(mty == VT)
		+ PF[pf0+4] * choose(mty == CT)
		+ PF[pf0+5] * choose(mty >= ClT)
		+ (
			  PF[pf0+10]
			+ PF[pf0+11] * choose(mty == OMaT)
			+ PF[pf0+12] * choose(mty == OMT)
			+ PF[pf0+13] * choose(mty == VT)
			+ PF[pf0+14] * choose(mty == CT)
			+ PF[pf0+15] * (
				choose(mty >= ClT)
				+ 0.1  * choose(mty == ROCK)
				+ 0.15 * choose(mty == MTN)
			)
		) * (dd/1000)
	)
	A = A * (1+jd)
	local B =
	      PF[pf0+20]
		+ PF[pf0+21]* choose(mty == OMaT)
		+ PF[pf0+22]* choose(mty == OMT)
		+ PF[pf0+23]* choose(mty == VT)
		+ PF[pf0+24]* choose(mty == CT)
		+ PF[pf0+25]* (
			choose(mty >= ClT)
			+ 0.1  * choose(mty == ROCK)
			+ 0.15 * choose(mty == MTN)
		)
		+ PF[pf0+29] * (dd/1000)
    local didmax = dkan.dk(PF[pf0+42])/A
	local xm0 = -.00889
		+ 1.55243  * didmax
		- 1.02468  * didmax^2
		+ 11.75567 * didmax^3
    local xm = xm0 * (1 + PF[pf0+43]*rdf + PF[pf0+44]*rdfL)
	if abs(xm-1) < 0.01 then
		xm = 1 + sgn1(xm-1) * 0.01
	end
    local xk = (2*xm+2)/(1-xm^2)
    local xn = A^(1-xm)*xk
    local bd = xn*dk^xm - xk*dk
    local bd = max(bd, 0.001)
    local dki = (
        log(bd) + B
        + PF[pf0+30] * log(1 + rdf)
        + PF[pf0+38] * log(1 + (rdf-rdfmet))
        + PF[pf0+31] * log(1 + rdfma)
        + PF[pf0+32] * log(1 + rdfku)
        + PF[pf0+33] * log(1 + rdflehti)
        + PF[pf0+34] * log(1 + rdfL)
        + PF[pf0+35] * log(1 + rdfLma)
        + PF[pf0+36] * log(1 + rdfLku)
        + PF[pf0+37] * log(1 + rdfLlehti)
    )
    return max(exp(dki)/1.25, 0.001)
end

-- skaalaamaton
local function ig5_figu_raw(
	spe, d, h, rdfL, rdfLma, rdfLku, rdfLlehti, cr, crkor, snt,
	mty, mal, dd, rdf, rdfma, rdfku, rdflehti, jd)
	local dk
	if h <= 3 then
		dk = dkan.dkjs_small(h)
	else
		dk = dkan.dk(d)
	end
	if mal == scrub then
		mty = ROCK
	elseif mal == waste then
		mty = MTN
	end
	-- XXX: rdfmet = rdf
	local id = idk(spe,dk,rdfL,rdfLma,rdfLku,rdfLlehti,mty,dd,rdf,rdfma,rdfku,rdflehti,rdf,jd)
	-- tactically placed speedup loop to control trace scope.
	-- this is a quick-and-dirty workaround for preventing trace aborts caused by "register
	-- coalescing too complex".
	-- this loop decreases total runtime by ~30% on uusimaa data!
	for _=1, 10 do end
	local ig = d2gu(d+id) - d2gu(d)
	if abs(crkor) > 0.005 then
		ig = min(ig, ig*figucr(spe,d,dk,cr,crkor,snt,mty,dd))
	end
	ig = max(ig, 0.0001)
	if spe < 8 then
		if mal == scrub then
			ig = ig * 600/dd
		elseif  mal == waste then
			ig = ig * 300/dd
		end
	end
	--print("ig5_figu", spe, ig)
	return ig
end

local function ig5_figu(...)
	return ig5_figu_raw(...)/10000
end

--------------------------------------------------------------------------------

return {
	ig5_figu     = ig5_figu,
	ig5_figu_raw = ig5_figu_raw
}
