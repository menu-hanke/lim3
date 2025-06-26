-- reference: Pukkala, T., Vauhkonen, J., Korhonen, K.T. and Packalen, T., 2021. Self-learning growth simulator for modelling forest stand dynamics in changing conditions. Forestry: An International Journal of Forest Research, 94(3), pp.333-346.

local coding = require "metsi.coding"
local mm = require "metsi.math"
local choose, sigmoid = mm.choose, mm.sigmoid
local SILVER_BIRCH, DOWNY_BIRCH, ASPEN = coding.spe.silver_birch, coding.spe.downy_birch, coding.spe.aspen
local MINERALSOIL = coding.alr.mineralsoil
local OMT, VT = coding.mty.OMT, coding.mty.VT
local exp, log, sqrt = math.exp, math.log, math.sqrt

---- diameter increment (Table 3) ----------------------------------------------

local function id5_pine(d, gL, G, dd, mty, alr)
	return exp(
		-7.1552
		+ 0.4415 * sqrt(d)
		- 0.0685 * d
		- 0.2027 * log(G + 1)
		- 0.1236 * gL / sqrt(d + 1)
		+ 1.1198 * log(dd)
		+ 0.1438 * choose(mty <= OMT)
		- 0.1754 * choose(mty == VT)
		- 0.5163 * choose(mty > VT)
		- 0.2425 * choose(alr ~= MINERALSOIL)
	)
end

local function id5_spruce(d, gL, gL_spruce, G, dd, mty)
	return exp(
		-12.7527
		+ 0.1693 * sqrt(d)
		- 0.0301 * d
		- 0.1875 * log(G + 1)
		- 0.0563 * gL / sqrt(d + 1)
		- 0.0870 * gL_spruce / sqrt(d + 1)
		+ 1.9747 * log(dd)
		+ 0.2688 * choose(mty <= OMT)
		- 0.2145 * choose(mty == VT)
		- 0.6179 * choose(mty > VT)
	)
end

local function id5_deciduous(s, d, gL_notpine, G, dd, mty)
	return exp(
		-8.6306
		+ 0.5097 * sqrt(d)
		- 0.0829 * d
		- 0.3864 * log(G + 1)
		- 0.0545 * gL_notpine / sqrt(d + 1)
		- 1.3163 * log(dd)
		+ 0.2566 * choose(mty <= OMT)
		- 0.2256 * choose(mty == VT)
		- 0.3237 * choose(mty > VT)
		+ 0.0256 * choose(s == SILVER_BIRCH or s == ASPEN, d)
	)
end

----- mixed-effects survival (Table 4) -----------------------------------------

local function sp5_mix_pine(d, gL, alr)
	return sigmoid(
		4.1505
		+ 3.1513 * sqrt(d)
		- 0.3575 * d
		- 0.4001 * gL / sqrt(d + 1)
		- 0.3813 * choose(alr ~= MINERALSOIL)
	)
end

local function sp5_mix_spruce(d, gL_spruce, alr)
	return sigmoid(
		9.6649
		+ 1.0157 * sqrt(d)
		- 0.1577 * d
		- 0.3244 * gL_spruce / sqrt(d + 1)
		- 0.7366 * choose(alr ~= MINERALSOIL)
	)
end

local function sp5_mix_deciduous(s, d, gL, gL_pine, alr)
	return sigmoid(
		3.6655
		+ 1.0650 * sqrt(d)
		- 0.1509 * d
		- 0.0326 * gL_pine / sqrt(d + 1)
		- 0.2768 * (gL - gL_pine) / sqrt(d + 1)
		- 0.3884 * choose(alr ~= MINERALSOIL)
		- 0.0562 * choose(s == ASPEN)
		+ 1.0780 * choose(s == SILVER_BIRCH or s == DOWNY_BIRCH)
	)
end

----- fixed-effects survival (Table 5) -----------------------------------------

local function sp5_fix_pine(d, gL, alr)
	return sigmoid(
		1.41223
		+ 1.88520 * sqrt(d)
		- 0.21317 * d
		- 0.25637 * gL / sqrt(d + 1)
		- 0.39878 * choose(alr ~= MINERALSOIL)
	)
end

local function sp5_fix_spruce(d, gL_spruce, alr)
	return sigmoid(
		5.01677
		+ 0.36902 * sqrt(d)
		- 0.07504 * d
		- 0.23190 * gL_spruce / sqrt(d + 1)
		- 0.47361 * choose(alr ~= MINERALSOIL)
	)
end

local function sp5_fix_deciduous(s, d, gL, gL_pine, alr)
	return sigmoid(
		1.60895
		+ 0.71578 * sqrt(d)
		- 0.08236 * d
		- 0.04814 * gL_pine / sqrt(d + 1)
		- 0.13481 * (gL - gL_pine) / sqrt(d + 1)
		- 0.31789 * choose(alr ~= MINERALSOIL)
		+ 0.56311 * choose(s == ASPEN)
		+ 1.40145 * choose(s == SILVER_BIRCH or s == DOWNY_BIRCH)
	)
end

----- ingrowth (Table 6) -------------------------------------------------------

local function ing5_pine(dd, G, mty)
	return exp(
		-6.6933
		+ 1.9051 * log(dd)
		- 0.5035 * sqrt(G)
		- 1.3223 * choose(mty <= OMT)
		+ 0.7679 * choose(mty == VT)
	)
end

local function ing5_spruce(dd, G, G_pine, mty)
	return exp(
		-9.6128
		+ 2.2897 * log(dd)
		- 0.8739 * sqrt(G)
		+ 0.7121 * sqrt(G_pine)
		- 1.6702 * choose(mty >= VT)
	)
end

local function ing5_birch(dd, G, G_pine, mty)
	return exp(
		-3.2919
		+ 1.5438 * log(dd)
		- 1.2920 * sqrt(G)
		+ 0.9436 * sqrt(G_pine)
		- 0.8891 * choose(mty >= VT)
	)
end

local function ing5_other(dd, G, mty)
	return exp(
		-48.4331
		+ 7.6107 * log(dd)
		- 0.2227 * sqrt(G)
		+ 1.3402 * choose(mty <= OMT)
		- 0.9439 * choose(mty >= VT)
	)
end

--------------------------------------------------------------------------------

return {
	id5_pine          = id5_pine,
	id5_spruce        = id5_spruce,
	id5_deciduous     = id5_deciduous,
	sp5_mix_pine      = sp5_mix_pine,
	sp5_mix_spruce    = sp5_mix_spruce,
	sp5_mix_deciduous = sp5_mix_deciduous,
	sp5_fix_pine      = sp5_fix_pine,
	sp5_fix_spruce    = sp5_fix_spruce,
	sp5_fix_deciduous = sp5_fix_deciduous,
	ing5_pine         = ing5_pine,
	ing5_spruce       = ing5_spruce,
	ing5_birch        = ing5_birch,
	ing5_other        = ing5_other
}
