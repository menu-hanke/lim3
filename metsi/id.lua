local exp, log, max, min = math.exp, math.log, math.max, math.min
local mm = require "metsi.math"
local choose, g2du, expm1 = mm.choose, mm.g2du, mm.expm1
local coding = require "metsi.coding"
local over, retention = coding.storie.over, coding.storie.retention
local forest = coding.mal.forest
local rhtkg1, rhtkg2, mtkg1, mtkg2, ptkg1, ptkg2, vatkg1, vatkg2, jatk
	= coding.tkg.RHTKG1, coding.tkg.RHTKG2, coding.tkg.MTKG1, coding.tkg.MTKG2,
	  coding.tkg.PTKG1, coding.tkg.PTKG2, coding.tkg.VATKG1, coding.tkg.VATKG2, coding.tkg.JATK
local PsK, PKgK, PsR, KgR, PKR
	= coding.sty.PsK, coding.sty.PKgK, coding.sty.PsR, coding.sty.KgR, coding.sty.PKR
local peat = require "metsi.peat"
local peatc, ojic = peat.peatc, peat.ojic
local ig = require "metsi.ig"
local ig5_figu = ig.ig5_figu

local function xhdom100d(hdom100, hdom100_over, hdom100_retention, storie, h)
	if hdom100 > 0 then return hdom100 end
	if storie == over and hdom100_over > 0 then return hdom100_over end
	if storie == retention and hdom100_retention > 0 then return hdom100_retention end
	return h
end

local function id5_suo_manty(
	d, h, storie, gL,
	hdom100, hdom100_over, hdom100_retention, G, dd, mal, oji, tkg, sty, rimp, pdr, dr, dnm, xt_thin)
	hdom100 = xhdom100d(hdom100, hdom100_over, hdom100_retention, storie, h)
	if mal > forest then
		tkg = vatkg1
	end
	local untr = 3.035
		+ 0.987 * log(d)
		- 0.001 * d^1.5
		- 0.271 * log(G)
		- 0.011 * gL
		- 0.0003 * gL^2
		- 0.680 * log(hdom100)
		- 0.658 * d/hdom100
		- 0.949 * expm1(-(dd/1000)^4)
		+ 0.271 * choose(min(dr, 5-dr, dd-1000) >= 0)
		+ 0.106 * choose(min(dr-5, 15-dr) >= 0)
		- 0.075 * choose(min(dr-20, 1000-dr) >= 0)
		+ 0.052 * choose(min(dnm, 5-dnm) >= 0)
		- 0.297 * choose(pdr)
		+ 0.090 * choose(pdr, log(G))
		+ 0.044 * choose(min(xt_thin-5, 10-xt_thin) >= 0)
		- 0.076 * choose(tkg == rhtkg1 or tkg == rhtkg2 or tkg == mtkg1, log(d))
		- 0.112 * choose(tkg == mtkg2 or tkg == ptkg1 or tkg == ptkg2, log(d))
		- 0.024 * choose(tkg == ptkg1 and (
				sty == PsK or sty == PKgK or sty == PsR or sty == KgR or sty == PKR
			), log(d))
		- 0.056 * choose(tkg == vatkg1 or tkg == vatkg2 or tkg == jatk, hdom100)
		- 0.442 * choose(rimp)
	--print(string.format("d=%g gL=%g G=%g hdom100=%g dd=%g mal=%d oji=%d tkg=%d sty=%d rimp=%s pdr=%s dr=%d dnm=%d xt_thin=%d -> untr=%g", d, gL, G, hdom100, dd, mal, oji, tkg, sty, rimp, pdr, dr, dnm, xt_thin, untr))
	local c = peatc(mal, dd) * ojic(G, dd, mal, oji, tkg)
    local id = c * (exp(untr + (0.055+0.026+0.186)/2) - 2) / 10
	if id <= 0 then
        id = 0.0001
	end
	return id
end

local function id5_suo_kuusi(
	d, h, storie, gLku,
	hdom100, hdom100_over, hdom100_retention, G, dd, Z, mal, oji, tkg, dr, dnm, xt_thin)
	hdom100 = xhdom100d(hdom100, hdom100_over, hdom100_retention, storie, h)
	if mal > forest then
		tkg = vatkg1
	end
	local untr = 2.250
		+ 0.046 * d
		- 0.001 * d^2
		- 0.132 * log(G)
		- 0.022 * gLku
		- 0.115 * (d/hdom100)^2
		- 1.228 * expm1(-(dd/1000)^4)
		+ 0.001 * Z
		- 0.075 * choose(min(dr-25, 1000-dr) >= 0)
		+ 0.092 * choose(min(dnm, 5-dnm, 1050-dd) >= 0)
		- 0.085 * choose(min(xt_thin, 900-xt_thin) >= 0)
		- 0.009 * choose(tkg == mtkg1 or tkg == mtkg2, hdom100)
		- 0.011 * choose(tkg == ptkg1 or tkg == ptkg2, hdom100)
		- 0.049 * choose(tkg == vatkg1 or tkg == vatkg2 or tkg == jatk, hdom100)
	--print(string.format("d=%g h=%g storie=%d gLku=%g hdom100=%g G=%g dd=%g Z=%g mal=%g oji=%d tkg=%d dr=%d dnm=%d xt_thin=%d -> untr=%g", d, h, storie, gLku, hdom100, G, dd, Z, mal, oji, tkg, dr, dnm, xt_thin, untr))
    local c = peatc(mal, dd) * ojic(G, dd, mal, oji, tkg)
    return max(c * (exp(untr + (0.054+0.021+0.122)/2) - 4) / 10, 0)
end

local function id5_suo_koivu(
	d, h, storie, gLlehti,
	hdom100, hdom100_over, hdom100_retention, G, dd, Z, mal, oji, tkg, dr, dnm, xt_thin, xt_fert)
	hdom100 = xhdom100d(hdom100, hdom100_over, hdom100_retention, storie, h)
	if mal > forest then
		tkg = vatkg1
	end
	local untr = -7.332
		+ 0.148 * choose(min(dr, 9.9999-dr) >= 0)
		+ 0.081 * choose(min(dr-10, 14.9999-dr) >= 0)
		- 0.037 * choose(min(dr-20, 1000-dr) >= 0)
		+ 0.070 * choose(min(dnm, 5-dnm, dd-800) >= 0 and (tkg == mtkg2 or tkg == ptkg1 or tkg == ptkg2))
		+ 0.033 * choose(min(xt_thin, 5-xt_thin) >= 0)
		+ 0.064 * choose(tkg == rhtkg1 or tkg == rhtkg2)
		+ 0.239 * choose(min(xt_fert, 25-xt_fert) >= 0 and (tkg == mtkg2 or tkg == ptkg2))
		+ 0.666 * log(d)
		- 0.172 * log(G)
		- 0.022 * gLlehti
		- 0.074 * hdom100
		- 0.564 * d/hdom100
		+ 1.471 * log(dd)
		+ 0.001 * Z
    local c = peatc(mal, dd) * ojic(G, dd, mal, oji, tkg)
    return max(c * (exp(untr + (0.038+0.014+0.139)/2) - 4) / 10, 0)
end

local function id5small(spe, h, ih5, rdfl, rdflma, rdflku, rdfl_lehti, cr, crkor, snt,
	mty, mal, dd, rdf, rdfma, rdfku, rdf_lehti, jd, step)
	if h + ih5 < 1.3 then
		return 0
	end
	step = step or 5
	local ig = ig5_figu(spe, h, 0.01, rdfl, rdflma, rdflku, rdfl_lehti, cr, crkor, snt,
		mty, mal, dd, rdf, rdfma, rdfku, rdf_lehti, jd)
	local ga = 2
	local da = g2du(ga)
	return da + (g2du(ga+ig)-da)*(step/5.0)*(1-(1.3-h)/ih5)
end

return {
	id5_suo_manty = id5_suo_manty,
	id5_suo_kuusi = id5_suo_kuusi,
	id5_suo_koivu = id5_suo_koivu,
	id5small      = id5small
}
