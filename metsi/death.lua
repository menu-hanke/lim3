local coding = require "metsi.coding"
local dkan = require "metsi.dkan"
local mm = require "metsi.math"
local pine, spruce, silver_birch, aspen, gray_alder, black_alder, xconiferous, xdeciduous
	= coding.spe.pine, coding.spe.spruce, coding.spe.silver_birch, coding.spe.aspen,
	coding.spe.gray_alder, coding.spe.black_alder, coding.spe.xconiferous, coding.spe.xdeciduous
local dk = dkan.dk
local choose, tolmax, tolmin = mm.choose, mm.tolmax, mm.tolmin
local exp, max, min = math.exp, math.max, math.min

---- jsdeath -----------------------------------------

local function _jsdeath(expn, step)
    return (1 + exp(-min(max(expn, -5.0), 40.0))) ^ (-step)
end

local function jsdeath_manty(d, rdfl, step)
    return _jsdeath(
        8.8165
        - 4.4671 * rdfl
        - 55.5793 * rdfl/dk(d)
    , step or 5)
end

local function jsdeath_kuusi(d, rdfl, step)
    return _jsdeath(
        8.3970
        - 4.9195 * rdfl
        - 35.6928 * rdfl/dk(d)
    , step or 5)
end

local function jsdeath_raudus(d, rdfl, step)
    return _jsdeath(
        8.5158
        - 4.8386 * rdfl
        - 34.9224 * rdfl/dk(d)
    , step or 5)
end

local function jsdeath_lehti(spe, d, rdfl, step)
    return _jsdeath(
        9.0959
        - 1.6857 * choose(spe == aspen or spe == black_alder)
        - 0.8259 * choose(spe == gray_alder)
        - 2.5000 * choose(spe == xdeciduous)
        - 5.7434 * rdfl
        - 21.3825 * rdfl/dk(d)
    , step or 5)
end

local function jsdeath(spe, d, rdfl, step)
	--print("jsdeath", spe, d, rdfl, step)
    if spe == pine or spe == xconiferous then
        return jsdeath_manty(d, rdfl, step)
	elseif spe == spruce then
        return jsdeath_kuusi(d, rdfl, step)
	elseif spe == silver_birch then
        return jsdeath_raudus(d, rdfl, step)
    else
        return jsdeath_lehti(spe, d, rdfl, step)
	end
end

---- pmodel3 -----------------------------------------

local function pmodel3a_suo_manty(d, baL, G, Grel_lehti, dg, step)
    d = max(d, 1.0)
    local expn = (
        5.855+0.04
        - 37.639 * 1/(d*10)
        - 2.02   * baL/G
        - 0.107  * G
        - 2.007  * Grel_lehti
        + 0.11   * dg
    )
    expn = max(tolmin(expn, 85, 40), -5.0)
    return (1.0 + exp(-expn))^(-(step or 5)/5.0)
end

---- bmodel3 ----------------------------------------

local function bmodel3_suo_koivu(d, baL, G, Grel_manty, dd, step)
    d = max(d, 1.0)
    Grel_manty = tolmax(Grel_manty, 0.01, 0.1)
    local expn = (
        12.34+0.08
        - 93.18 * 1/(10*d)
        - 1.847 * baL/G
        - 0.083 * G
        + 1.414 * Grel_manty
        - 0.0048 * dd
    )
    expn = max(tolmin(expn, 85, 40), -5.0)
    return (1 + math.exp(-expn))^(-(step or 5)/5.0)
end

---- famort -----------------------------------------

local RIAKT = {
    {-0.545454545, 1186.363636},
    {-0.181818182, 595.4545455},
    {-0.181818182, 445.4545455},
    {-0.136363636, 334.0909091},
    {-0.163636364, 400.9090909},
    {-0.090909091, 222.7272727},
    {-0.136363636, 334.0909091},
    {-0.090909091, 472.7272727},
    {-0.090909091, 222.7272727}
}

local function famort(spe, age13, dd)
	local r = RIAKT[spe]
    local a, b = r[1], r[2]
    local agemax = b + a*dd
    local r0 = math.exp(-10 + 10 * age13 / (0.82 * agemax))
    local r5 = math.exp(-10 + 10 * (age13 + 5) / (0.82 * agemax))
    local rfam0 = r0 / (1 + r0)
    local rfam5 = r5 / (1 + r5)
    -- return 1 - (rfam5 - rfam0) / (1 - rfam0)
    local fam = 1 - (rfam5 - rfam0) / (1 - rfam0)
	if fam ~= fam then
		print(spe, age13, dd)
	end
	assert(fam == fam)
	return fam
end

--------------------------------------------------------------------------------

return {
	jsdeath = jsdeath,
	pmodel3a_suo_manty = pmodel3a_suo_manty,
	bmodel3_suo_koivu = bmodel3_suo_koivu,
	famort = famort
}
