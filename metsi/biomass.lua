-- Crown ratio based biomass models.
-- Repola J. (2013). Modelling tree biomasses in Finland
-- Repola J. (2009) Silva Fennica 43(4) Biomass equations for Scots pine and Norway spruce in Finland
-- Repola J. (2008) Silva Fennica 42(4) Biomass equations for birch in Finland

local exp, log = math.exp, math.log

local function bm_stem_pine(dk, h, a13)
	return exp(
		-4.018 + (0.001 + 0.008) / 2
		+ 8.358 * (dk / (dk + 14))
		+ 4.646 * (h / (h + 10))
		+ 0.041 * log(a13)
	)
end

local function bm_stem_spruce(dk, h, a13)
	return exp(
		-4.000 + (0.003 + 0.008) / 2
		+ 8.881 * (dk / (dk + 12))
		+ 0.728 * log(h)
		+ 0.022 * h
		- 0.273 * dk / a13
	)
end

local function bm_stem_birch(d, dk, h, a13)
	return exp(
		-4.886 + (0.002 + 0.005) / 2
		+ 9.965 * (dk / (dk + 12))
		+ 0.966 * log(h)
		- 0.135 * d / a13
	)
end

local function bm_bark_pine(dk, h)
	return exp(
		-4.695 + (0.014 + 0.057) / 2
		+ 8.727 * (dk / (dk + 14))
		+ 0.357 * log(h)
	)
end

local function bm_bark_spruce(dk, h)
	return exp(
		-4.437 + (0.019 + 0.039) / 2
		+ 10.071 * (dk / (dk + 18))
		+ 0.261 * log(h)
	)
end

local function bm_bark_birch(dk, h)
	return exp(
		-5.433 + (0.011 + 0.0044) / 2
		+ 10.121 * (dk / (dk + 12))
		+ 2.647 * (h / (h + 20))
	)
end

local function bm_live_branches_pine(dk, h, cl)
	return exp(
		-5.224 + (0.02 + 0.067) / 2
		+ 13.022 * (dk / (dk + 12))
		- 4.867 * (h / (h + 8))
		+ 1.058 * log(cl)
	)
end

local function bm_live_branches_spruce(dk, h, cl)
	return exp(
		-2.945 + (0.013 + 0.072) / 2
		+ 12.698 * (dk / (dk + 14))
		- 6.183 * (h / (h + 5))
		+ 0.959 * log(cl)
	)
end

local function bm_live_branches_birch(dk, h, cl)
	return exp(
        -4.837 + (0.013 + 0.054) / 2
		+ 13.222 * (dk / (dk + 12))
		- 4.639 * (h / (h + 12))
		+ 0.135 * cl
	)
end

local function bm_dead_branches_pine(dk)
	return 0.913 * exp(
		-5.318
		+ 10.771 * (dk / (dk + 16))
	)
end

local function bm_dead_branches_spruce(dk, h)
	return 1.208 * exp(
		-5.317
		+ 6.384 * (dk / (dk + 18))
		+ 0.982 * log(h)
	)
end

local function bm_dead_branches_birch(dk)
	return 2.1491 * exp(
		-7.996
		+ 11.824 * (dk / (dk + 16))
	)
end

local function bm_foliage_pine(dk, h, cl)
	return exp(
		-1.748 + (0.032 + 0.093) / 2
		+ 14.824 * (dk / (dk + 4))
		- 12.684 * (h / (h + 1))
		+ 1.209 * log(cl)
	)
end

local function bm_foliage_spruce(dk, h, cl)
	return exp(
		-0.085 + (0.028 + 0.087) / 2
		+ 15.222 * (dk / (dk + 4))
		- 14.446 * (h / (h + 1))
		+ 1.273 * log(cl)
	)
end

local function bm_foliage_birch(dk, cr)
	return exp(
		-20.856 + (0.011 + 0.044) / 2
		+ 22.320 * (dk / (dk + 2))
		+ 2.819 * cr
	)
end

local function bm_stump_pine(dk)
	return exp(
		-6.753 + (0.010 + 0.044) / 2
		+ 12.681 * (dk / (dk + 12))
	)
end

local function bm_stump_spruce(dk)
	return exp(
		-3.964 + (0.065 + 0.058) / 2
		+ 11.730 * (dk / (dk + 26))
	)
end

local function bm_stump_birch(dk)
	return exp(
		-3.574 + (0.02154 + 0.04542) / 2
		+ 11.304 * (dk / (dk + 26))
	)
end

-- code to precompute small tree biomass:
-- local d, dk, h, a13, cl, cr = 0.1, 2.125, 1.3, 1, 1.1, 1.1/1.3
-- print(string.format("bm_stem = h*%g where spe=~spe'pine", bm_stem_pine(dk, h, a13)/1.3))
-- print(string.format("bm_stem = h*%g where spe=~spe'spruce", bm_stem_spruce(dk, h, a13)/1.3))
-- print(string.format("bm_stem = h*%g", bm_stem_birch(d, dk, h, a13)/1.3))
-- print(string.format("bm_bark = h*%g where spe=~spe'pine", bm_bark_pine(dk, h)/1.3))
-- print(string.format("bm_bark = h*%g where spe=~spe'spruce", bm_bark_spruce(dk, h)/1.3))
-- print(string.format("bm_bark = h*%g", bm_bark_birch(dk, h)/1.3))
-- print(string.format("bm_live_branches = h*%g where spe=~spe'pine", bm_live_branches_pine(dk, h, cl)/1.3))
-- print(string.format("bm_live_branches = h*%g where spe=~spe'spruce", bm_live_branches_spruce(dk, h, cl)/1.3))
-- print(string.format("bm_live_branches = h*%g", bm_live_branches_birch(dk, h, cl)/1.3))
-- print(string.format("bm_dead_branches = h*%g where spe=~spe'pine", bm_dead_branches_pine(dk)/1.3))
-- print(string.format("bm_dead_branches = h*%g where spe=~spe'spruce", bm_dead_branches_spruce(dk, h)/1.3))
-- print(string.format("bm_dead_branches = h*%g", bm_dead_branches_birch(dk)/1.3))
-- print(string.format("bm_foliage = h*%g where spe=~spe'pine", bm_foliage_pine(dk, h, cl)/1.3))
-- print(string.format("bm_foliage = h*%g where spe=~spe'spruce", bm_foliage_spruce(dk, h, cl)/1.3))
-- print(string.format("bm_foliage = h*%g", bm_foliage_birch(dk, cr)/1.3))
-- print(string.format("bm_stump = h*%g where spe=~spe'pine", bm_stump_pine(dk)/1.3))
-- print(string.format("bm_stump = h*%g where spe=~spe'spruce", bm_stump_spruce(dk)/1.3))
-- print(string.format("bm_stump = h*%g", bm_stump_birch(dk)/1.3))

return {
	bm_stem_pine            = bm_stem_pine,
	bm_stem_spruce          = bm_stem_spruce,
	bm_stem_birch           = bm_stem_birch,
	bm_bark_pine            = bm_bark_pine,
	bm_bark_spruce          = bm_bark_spruce,
	bm_bark_birch           = bm_bark_birch,
	bm_live_branches_pine   = bm_live_branches_pine,
	bm_live_branches_spruce = bm_live_branches_spruce,
	bm_live_branches_birch  = bm_live_branches_birch,
	bm_dead_branches_pine   = bm_dead_branches_pine,
	bm_dead_branches_spruce = bm_dead_branches_spruce,
	bm_dead_branches_birch  = bm_dead_branches_birch,
	bm_foliage_pine         = bm_foliage_pine,
	bm_foliage_spruce       = bm_foliage_spruce,
	bm_foliage_birch        = bm_foliage_birch,
	bm_stump_pine           = bm_stump_pine,
	bm_stump_spruce         = bm_stump_spruce,
	bm_stump_birch          = bm_stump_birch
}
