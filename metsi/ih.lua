local ffi = require "ffi"
local abs, exp, log, max, min = math.abs, math.exp, math.log, math.max, math.min
local mm = require "metsi.math"
local choose, d2gu, g2du, expm1, sgn1 = mm.choose, mm.d2gu, mm.g2du, mm.expm1, mm.sgn1
local coding = require "metsi.coding"
local pine, spruce, silver_birch, downy_birch, aspen, gray_alder, black_alder, xconiferous, xdeciduous
	= coding.spe.pine, coding.spe.spruce, coding.spe.silver_birch, coding.spe.downy_birch, coding.spe.aspen, coding.spe.gray_alder, coding.spe.black_alder, coding.spe.xconiferous, coding.spe.xdeciduous
local OMaT, OMT, VT, CT, ClT, ROCK, MTN
	= coding.mty.OMaT, coding.mty.OMT, coding.mty.VT, coding.mty.CT, coding.mty.ClT, coding.mty.ROCK, coding.mty.MTN
local scrub, waste = coding.mal.scrub, coding.mal.waste
local forest = coding.mal.forest
local natural = coding.snt.natural
local rhtkg1, rhtkg2, mtkg1, mtkg2, ptkg1, ptkg2, vatkg1, vatkg2, jatk
	= coding.tkg.RHTKG1, coding.tkg.RHTKG2, coding.tkg.MTKG1, coding.tkg.MTKG2,
	  coding.tkg.PTKG1, coding.tkg.PTKG2, coding.tkg.VATKG1, coding.tkg.VATKG2, coding.tkg.JATK
local peat = require "metsi.peat"
local peatc, ojic = peat.peatc, peat.ojic
local regen = require "metsi.regen"
local agekri, hvalta = regen.agekri, regen.hvalta

---- turvemaan mallit   peats/suoIH5.F90 ----------------------------------------

local function xhdom100h(hdom100, hdom100_over, hdom100_retention, hdom100_grow, storie, h)
	if hdom100 > 0 then return hdom100 end
	if storie == coding.storie.over and hdom100_over > 0 then return hdom100_over end
	if storie == coding.storie.retention and hdom100_retention > 0 then return hdom100_retention end
	if hdom100_grow > 0 then return hdom100_grow end
	return h
end

local function ih5adj(ih5, G, dd, mal, oji, tkg)
	ih5 = ih5 * peatc(mal, dd)
	ih5 = ih5 * ojic(G, dd, mal, oji, tkg)
	if ih5 < 0 then return 0.05 end
	return ih5
end

local function ih5_suo_manty(
	d, gL,
	G, Gkoivu, hdom100, dd, mal, tkg, dnm, ojik)
    if G <= 0.000001 or hdom100 <= 0.000001 then
        return 0.05
	end
    if mal > forest then
        tkg = vatkg1
	end
	local dnmts800 = min(dnm, 20-dnm, dd-800) >= 0
	local untr = 0.841
		+ 0.830 * log(d)
		+ 0.015 * gL
		- 0.001 * gL^2
		- 0.091 * hdom100
		- 0.760 * d/hdom100
		+ 0.196 * Gkoivu/G
		- 1.965 * expm1(-(dd/1000)^4)
		+ 0.257 * choose(dnmts800 and tkg == mtkg2)
		+ 0.257 * choose(dnmts800 and (tkg == ptkg1 or tkg == ptkg2))
		+ 0.195 * choose(dnmts800 and (tkg == vatkg1 or tkg == vatkg2 or tkg == jatk))
		- 0.093 * choose(ojik == 1)
		- 0.064 * choose(tkg == mtkg2 or tkg == ptkg1, log(d))
		- 0.083 * choose(tkg == ptkg2, log(d))
		- 0.033 * choose(tkg == vatkg1 or tkg == vatkg2 or tkg == jatk, hdom100)
    return exp(untr)*1.251/10
end

local function ih5a_suo_manty(
	d, h, storie, gL, snt,
	G, Gkoivu, hdom100, hdom100_over, hdom100_retention, hdom100_grow, dd, mal, oji, ojik, tkg, dnm, jh)
	--print("ih5a_suo_manty")
	hdom100 = xhdom100h(hdom100, hdom100_over, hdom100_retention, hdom100_grow, storie, h)
	local ih5 = ih5_suo_manty(d, gL, G, Gkoivu, hdom100, dd, mal, tkg, dnm, ojik)
	ih5 = ih5adj(ih5, G, dd, mal, oji, tkg)
	if snt > natural then
		ih5 = ih5 * (1 + jh)
	end
	return ih5
end

local function ih5_suo_kuusi(
	d, gLku,
	hdom100, dd, mal, tkg, dr, dnm)
	if hdom100 == 0 then
		return
	end
	if mal > forest then
		tkg = vatkg1
	end
	local untr = 1.232
		- 0.0022 * d^1.5
		+ 0.936 * log(d)
		- 0.034 * gLku
		+ 0.118 * log(gLku+0.0001)
		- 0.669 * d/hdom100
		+ 4.617 * log(dd/1000)
		- 0.102 * hdom100 * dd/1000
		- 0.175 * choose(min(dr, 5-dr, 1050-dd) >= 0)
		+ 0.316 * choose(min(dnm, 10-dnm, 1050-dd) >= 0)
		+ 0.064 * choose(tkg == rhtkg1 or tkg == rhtkg2, hdom100)
		+ 0.056 * choose(tkg == mtkg1 or tkg == mtkg2 or tkg == ptkg1 or tkg == ptkg2, hdom100)
    local c = 1.271 - 0.0055*d
    return c*exp(untr)/10
end

local function ih5a_suo_kuusi(
	d, h, storie, gLku, snt,
	G, hdom100, hdom100_over, hdom100_retention, hdom100_grow, dd, mal, oji, tkg, dr, dnm, jh)
	--print("ih5a_suo_kuusi")
	hdom100 = xhdom100h(hdom100, hdom100_over, hdom100_retention, hdom100_grow, storie, h)
	local ih5 = ih5_suo_kuusi(d, gLku, hdom100, dd, mal, tkg, dr, dnm)
	if ih5 <= 0 then
		return 0.0001
	end
	ih5 = ih5adj(ih5, G, dd, mal, oji, tkg)
	if snt > natural then
		ih5 = ih5 * (1 + jh)
	end
	return ih5
end

local function ih5_suo_koivu(
	d, gLlehti,
	dg, G, Gmanty, F, hdom100, dd, Z, mal, tkg, dr, dnm, xt_thin, xt_fert)
	if mal > forest then
		tkg = vatkg1
	end
	local Grel = 0
	if G > 0 then
		Grel = Gmanty/G
	end
	local untr = -14.659
		+ 0.679 * log(d)
		- 0.006 * gLlehti^1.3
		- 0.079 * hdom100
		- 0.753 * d/hdom100
		- 0.0002 * F/d
		+ 0.142 * log(F)
		+ 2.294 * log(dd)
		+ 0.002 * Z
		+ 0.226 * choose(min(dr, 5-dr) >= 0 and (tkg == rhtkg1 or tkg == rhtkg2))
		+ 0.145 * choose(min(dnm, 10-dnm) >= 0 and (tkg == ptkg1 or tkg == ptkg2))
		+ 0.082 * choose(min(xt_thin-5, 10-xt_thin) >= 0)
		- 0.421 * choose(tkg == rhtkg1 or tkg == rhtkg2, Grel)
		+ 0.009 * choose(tkg == rhtkg1 or tkg == rhtkg2, dg)
		+ 0.007 * choose(tkg == mtkg1 or tkg == mtkg2, dg)
		+ 0.130 * choose(min(xt_fert, 15-xt_fert) >= 0 and (tkg == ptkg1 or tkg == ptkg2))
    return (exp(untr)*1.187-2)/10
end

local function ih5a_suo_koivu(
	d, h, storie, gLlehti,
	dg, G, Gmanty, F, hdom100, hdom100_over, hdom100_retention, hdom100_grow, dd, Z, mal, oji, tkg, dr, dnm, xt_thin, xt_fert)
	hdom100 = xhdom100h(hdom100, hdom100_over, hdom100_retention, hdom100_grow, storie, h)
	--print("ih5a_suo_koivu")
	local ih5 = ih5_suo_koivu(d, gLlehti, dg, G, Gmanty, F, hdom100, dd, Z, mal, tkg, dr, dnm, xt_thin, xt_fert)
	if ih5 <= 0 then
		return 0.0001
	end
	ih5 = ih5adj(ih5, G, dd, mal, oji, tkg)
	return ih5
end

---- kangasmaan mallit   heath/Fihperus.F90 ----------------------------------------

local PLKORCR = {1, 1, 1, 1, 0.99, 0.98, 0.97, 0.96, 0.95}
local function fihucr(spe, cr, crkor, mty, dd, hdomj)
	local pf1,  pf2,  pf3,  pf4,  pf5,  pf6,  pf7,  pf8,  pf9,  pf10
	local pf11, pf12, pf13, pf14, pf15, pf16, pf17, pf18, pf19
	local pf21,                                           pf29
	local             pf33,                               pf39, pf40
	if spe == pine or spe == xconiferous then
		pf1  = 1.166
		pf2  = 1.9
		pf3  = 1.9
		pf4  = 0.
		pf5  = -1.7
		pf6  = -8.4
		pf7  = -8.4
		pf8  = 70.2
		pf9  = -26.5
		pf10 = -17.3
		pf11 = 2.695
		pf12 = -.238
		pf13 = -.238
		pf14 = 0.
		pf15 = .031
		pf16 = .469
		pf17 = .469
		pf18 = -0.071
		pf19 = 0.
		pf21 = .521
		pf29 = 4.20
		pf39 = .223
		pf40 = .174
	elseif spe == spruce then
		pf1  = 1.255
		pf2  = 0.
		pf3  = 0.
		pf4  = 0.
		pf5  = -6.4
		pf6  = -6.4
		pf7  = -6.4
		pf8  = 45.3
		pf9  = -11.6
		pf10 = -8.4
		pf11 = -5.922
		pf12 = .313
		pf13 = .313
		pf14 = 0.
		pf15 = .551
		pf16 = .551
		pf17 = .551
		pf18 = 5.157
		pf19 = -2.440
		pf21 = .966
		pf29 = 119 -- XXX: virheellinen kerroin motissa? pitäisikö olla 1.19?
		pf33 = .329
		pf39 = .169
		pf40 = .344
	elseif spe == silver_birch or spe == aspen then
		pf1  = 1.446
		pf2  = 0.
		pf3  = 0.
		pf4  = 0.
		pf5  = 0.
		pf6  = 0.
		pf7  = 0.
		pf8  = 21.1
		pf9  = 0.
		pf10 = 0.1
		pf11 = -3.109
		pf12 = .024
		pf13 = .136
		pf14 = 0.
		pf15 = 0.
		pf16 = 0.
		pf17 = 0.
		pf18 = .083
		pf19 = 0.
		pf21 = .354
		pf29 = 2.47
		pf33 = 0.
		pf39 = .142
		pf40 = .410
	else
		pf1  = 1.675
		pf2  = 0.
		pf3  = 0.
		pf4  = 0.
		pf5  = 0.
		pf6  = 0.
		pf7  = 0.
		pf8  = 19.9
		pf9  = 0.
		pf10 = -1.5
		pf11 = -3.524
		pf12 = .024
		pf13 = .136
		pf14 = 0.
		pf15 = 0.
		pf16 = 0.
		pf17 = 0.
		pf18 = .083
		pf19 = 0.
		pf21 = .354
		pf29 = 2.47
		pf33 = 0.
		pf39 = .142
		pf40 = .410
	end
	local A = pf1 * (
        pf10 + (
            pf8
            + pf2 * choose(mty == OMaT)
            + pf3 * choose(mty == OMT)
            + pf4 * choose(mty == MT)
            + pf5 * choose(mty == VT)
            + pf6 * choose(mty == CT)
            + pf7 * choose(mty >= ClT)
        ) * dd/1000
        + pf9 * (dd/1000)^2
	)
    local B = (
        pf11
        + pf12 * choose(mty == OMaT)
        + pf13 * choose(mty == OMT)
        + pf14 * choose(mty == MT)
        + pf15 * choose(mty == VT)
        + pf16 * choose(mty == CT)
        + pf17 * choose(mty >= ClT) * dd/1000
        + pf18 * dd/1000
        + pf19 * (dd/1000)^2
    )
    local dihmax = 5/A
	local xm0 = .00889
		+ 1.55243  * dihmax
		- 1.02468  * dihmax^2
		+ 11.75567 * dihmax^3
    local xm = xm0*(1+pf29*(1-cr))
	if abx(xm-1) < 0.01 then
		xm = 1 + sgn1(x-1) * 0.01
	end
    local xk = (2*xm+2)/(1-xm^2)
    local xn = A^(1-xm)*xk
    local bh = max(xn*hdomj^xm-xk*hdomj, 0.0001)
    local loghi1 = B + log(bh) + pf33 + pf21*log(cr) + (pf39+pf40)/2
    local loghi2 = B + log(bh) + pf33 + pf21*log(cr-crkor) + (pf39+pf40)/2
    local kor = 1 -- aina 1 bugin takia
    return exp(kor*(loghi1-loghi2))
end

local function ih5_antikali(ih, ig, d, h)
	local d2 = g2du(d2gu(d)+ig*100^2)
    local dimrel = (h+ih)/d2
    if dimrel > 2 then
        ih = max(2*d2 - h, 0.05)
	end
    return ih
end

local PF = ffi.new("double[160]", {
	-- pine & other conifers
	6.07, 0.33, 0.33, 4.11,10.16,10.16, 0.00, 0.00, 0.00, 0.00,
	21.7, 0.00, 0.00,-6.38,-17.2,-19.0, 00.0, 0.00, 0.00, 0.00,
	-3.08,-0.86, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
	2.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.31, .384,
	-- spruce
	3.45, 0.00, 0.00, 8.99, 8.99, 8.99, 0.00, 0.00, 0.00, 0.00,
	28.1, 6.51, 6.51,-10.5,-16.0,-20.0, 00.0, 0.00, 0.00, 0.00,
	-3.45,-1.50, 0.70, 0.00, 0.07, 0.00, 0.00, 0.00, 0.00, 0.00,
	2.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.37, .556,
	-- silver birch & aspen
	0.0, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
	32.0, 1.35, 1.35, -8.0,-12.0,-15.0, 0.00, 0.00, 0.00, 0.00,
	-3.04,-1.48, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
	2.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, .662,
	-- other
	0.0, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
	33.9, 3.33, 3.33, -3.0,-8.0,-13.0, 0.00, 0.00, 0.00, 0.00,
	-3.81,-0.86, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
	2.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, .637
})

local PFBASE = {
	[pine]         = 0*40,
	[spruce]       = 1*40,
	[silver_birch] = 2*40,
	[downy_birch]  = 3*40,
	[aspen]        = 2*40,
	[gray_alder]   = 3*40,
	[black_alder]  = 3*40,
	[xconiferous]  = 0*40,
	[xdeciduous]   = 3*40
}

local function ih5_fihu(
	spe, d, h, rdfL, rdfLma, rdfLku, cr, crkor, ig5,
	mty, mal, dd, hdomj, jd)
	-- speed hack loop to control scope of traces. see comment in ig5_figu for more info.
	for _=1, 10 do end
	local pf0 = PFBASE[spe]
	if mal == scrub then
		mty = ROCK
	elseif mal == waste then
		mty = MTN
	end
	local A = (1+jd) * (
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
        ) * dd/1000
	)
    local dihmax = PF[pf0+30]/A
	local xm = -.00889
		+ 1.55243  * dihmax
		- 1.02468  * dihmax^2
		+ 11.75567 * dihmax^3
	if abs(xm-1) < 0.01 then
		xm = 1 + sgn1(xm-1) * 0.01
	end
    local xk = (2*xm+2)/(1-xm^2)
    local xn = A^(1-xm)*xk
    local bh = max(xn*h^xm - xk*h, 0.001)
    rdfL = max(rdfL, 0.1)
    local BB = (
          PF[pf0+20]
        + PF[pf0+21] * rdfL
        + PF[pf0+22] * rdfLma
        + PF[pf0+23] * rdfLku
        + PF[pf0+23] * (rdfL - rdfLma - rdfLku)
    )
    local ih = exp(log(bh)+BB)
    if abs(crkor) > 0.005 then
        local ihc = fihucr(spe, cr, crkor, mty, dd, hdomj)
        ih = min(ih, ih*ihc)
	end
    if spe < 8 then
        if h > 2 then
            ih = ih5_antikali(ih, ig5, d, h)
		end
		if mal == scrub then
			ih = ih*600/dd
		end
		if mal == waste then
			ih = ih*0.25
		end
	end
	--print("ih5_fihu", spe, ih)
    return ih
end

---- pienet puut   regenerate/hincu3.FOR ----------------------------------------

local function hincu(
	spe, age, h, snt,
	mty, dd, G, step)
	step = step or 5
	local t = agekri(spe, mty, snt, dd, 0, 0, h)
	local hi = hvalta(spe, t+step, mty, snt, dd, 0) - hvalta(spe, max(t, 1), mty, snt, dd, 0)
	if hi <= 0 then
		hi = h/age*step
	end
	if G > 10 then
		hi = hi / (1 + 0.005*(G-10)^2)
	end
	return hi
end

--------------------------------------------------------------------------------

return {
	ih5_suo_manty  = ih5_suo_manty,
	ih5a_suo_manty = ih5a_suo_manty,
	ih5_suo_kuusi  = ih5_suo_kuusi,
	ih5a_suo_kuusi = ih5a_suo_kuusi,
	ih5_suo_koivu  = ih5_suo_koivu,
	ih5a_suo_koivu = ih5a_suo_koivu,
	ih5_fihu       = ih5_fihu,
	hincu          = hincu
}
