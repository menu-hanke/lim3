-- Tapio silvicultural recommendation tables.

local coding = require "metsi.coding"
local pine, spruce, silver_birch, downy_birch, aspen, gray_alder, black_alder, xconiferous, xdeciduous
	= coding.spe.pine, coding.spe.spruce, coding.spe.silver_birch, coding.spe.downy_birch, coding.spe.aspen, coding.spe.gray_alder, coding.spe.black_alder, coding.spe.xconiferous, coding.spe.xdeciduous
local OMaT, OMT, MT, VT, CT, ClT, ROCK, MTN = coding.mty.OMaT, coding.mty.OMT, coding.mty.MT,
	coding.mty.VT, coding.mty.CT, coding.mty.ClT, coding.mty.ROCK, coding.mty.MTN
local inf = math.huge
local type = type

---- Cutting models common -----------------------------------------------------

local function kalr2(t)
	return { t.mineralsoil, t.peat, t.peat, t.peat, t.peat }
end

local function kmty4(t)
	return {
		[OMaT] = t.OMT or t.Rhtkg,
		[OMT]  = t.OMT or t.Rhtkg,
		[MT]   = t.MT  or t.Mtkg,
		[VT]   = t.VT  or t.Ptkg,
		[CT]   = t.CT  or t.Vatkg,
		[ClT]  = t.CT  or t.Vatkg,
		[ROCK] = t.CT  or t.Vatkg,
		[MTN]  = t.CT  or t.Vatkg
	}
end

local function kspe4(t)
	return {
		[pine]         = t.pine,
		[spruce]       = t.spruce,
		[silver_birch] = t.silver_birch,
		[downy_birch]  = t.downy_birch,
		[aspen]        = t.silver_birch,
		[gray_alder]   = t.downy_birch,
		[black_alder]  = t.downy_birch,
		[xconiferous]  = t.pine,
		[xdeciduous]   = t.downy_birch
	}
end

local function xtab(t,f,...)
	if f then
		for k,v in pairs(t) do
			t[k] = xtab(v,...)
		end
		return f(t)
	else
		return t
	end
end

---- Clearcut model ------------------------------------------------------------

local CCD0 = xtab({
	OMT = { pine=26, spruce=28, silver_birch=23, downy_birch=23 },
	MT  = { pine=26, spruce=26, silver_birch=23, downy_birch=23 },
	VT  = { pine=25, spruce=24, silver_birch=25, downy_birch=21 },
	CT  = { pine=22, spruce=22, silver_birch=22, downy_birch=19 }
}, kmty4, kspe4)

local CCA0 = xtab({
	OMT = { pine=70, spruce=60, silver_birch=60, downy_birch=50 },
	MT  = { pine=70, spruce=70, silver_birch=60, downy_birch=50 },
	VT  = { pine=80, spruce=60, silver_birch=60, downy_birch=50 },
	CT  = { pine=90, spruce=60, silver_birch=60, downy_birch=50 }
}, kmty4, kspe4)

local function cc_d0(mty, spe)
	return CCD0[mty][spe] or inf
end

local function cc_a0(mty, spe)
	return CCA0[mty][spe] or inf
end

---- Thinning model ------------------------------------------------------------

local GHDOM =              { 10,   12,   14,   16,   18,   20,   22,   24,   26 }
local NHDOM = #GHDOM

local G0 = xtab({
	mineralsoil = {
		OMT = {
			pine         = { 24.0, 24.0, 24.0, 26.1, 27.4, 28.1, 28.0, 28.0, 28.0 },
			spruce       = { 24.0, 24.0, 27.0, 30.0, 32.0, 33.0, 33.0, 33.0, 33.0 },
			silver_birch = { 16.0, 16.0, 16.9, 18.9, 19.8, 20.7, 20.7, 20.7, 20.7 },
			downy_birch  = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 }
		},
		MT = {
			pine         = { 24.0, 24.0, 24.0, 26.1, 27.4, 28.1, 28.0, 28.0, 28.0 },
			spruce       = { 24.0, 24.0, 24.0, 26.1, 27.4, 28.1, 28.0, 28.0, 28.0 },
			silver_birch = { 16.0, 16.0, 16.9, 18.9, 19.8, 20.7, 20.7, 20.7, 20.7 },
			downy_birch  = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 }
		},
		VT = {
			pine         = { 20.0, 20.0, 21.9, 24.9, 25.8, 25.7, 25.7, 25.7, 25.7 },
			spruce       = { 24.0, 24.0, 24.0, 26.1, 27.4, 28.1, 28.0, 28.0, 28.0 },
			silver_birch = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 },
			downy_birch  = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 }
		},
		CT = {
			pine         = { 18.0, 18.0, 18.9, 21.9, 22.8, 22.7, 22.7, 22.7, 22.7 },
			spruce       = { 18.0, 18.0, 18.9, 21.9, 22.8, 22.7, 22.7, 22.7, 22.7 },
			silver_birch = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 },
			downy_birch  = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 }
		}
	},
	peat = {
		Rhtkg = {
			pine         = { 21.0, 21.0, 24.5, 26.7, 27.7, 28.3, 28.4, 28.4, 28.4 },
			spruce       = { 24.0, 24.0, 27.0, 30.0, 32.0, 33.0, 33.0, 33.0, 33.0 },
			silver_birch = { 16.0, 16.0, 16.9, 18.9, 19.8, 20.7, 20.7, 20.7, 20.7 },
			downy_birch  = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 }
		},
		Mtkg = {
			pine         = { 21.0, 21.0, 24.5, 26.7, 27.7, 28.3, 28.4, 28.4, 28.4 },
			spruce       = { 24.0, 24.0, 24.0, 26.1, 27.4, 28.1, 28.0, 28.0, 28.0 },
			silver_birch = { 16.0, 16.0, 16.9, 18.9, 19.8, 20.7, 20.7, 20.7, 20.7 },
			downy_birch  = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 }
		},
		Ptkg = {
			pine         = { 19.5, 19.5, 23.2, 25.2, 26.1, 26.4, 26.4, 26.4, 26.4 },
			spruce       = { 24.0, 24.0, 24.0, 26.1, 27.4, 28.1, 28.0, 28.0, 28.0 },
			silver_birch = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 },
			downy_birch  = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 }
		},
		Vatkg = {
			pine         = { 17.5, 17.5, 21.2, 23.1, 23.8, 23.8, 23.8, 23.8, 23.8 },
			spruce       = { 17.5, 17.5, 21.2, 23.1, 23.8, 23.8, 23.8, 23.8, 23.8 },
			silver_birch = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 },
			downy_birch  = { 14.0, 14.0, 16.0, 17.4, 18.9, 18.9, 18.9, 18.9, 18.9 }
		}
	}
}, kalr2, kmty4, kspe4)

local G1 = xtab({
	mineralsoil = {
		OMT = {
			pine         = { 15.3, 15.3, 17.6, 19.0, 19.6, 19.9, 19.9, 19.9, 19.9 },
			spruce       = { 15.2, 15.2, 18.4, 20.9, 22.8, 23.9, 23.9, 23.9, 23.9 },
			silver_birch = {  8.5,  8.5, 10.9, 12.7, 14.1, 15.0, 15.0, 15.0, 15.0 },
			downy_birch  = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 }
		},
		MT = {
			pine         = { 15.3, 15.3, 17.6, 19.0, 19.6, 19.9, 19.9, 19.9, 19.9 },
			spruce       = { 15.3, 15.3, 17.6, 19.0, 19.6, 19.9, 19.9, 19.9, 19.9 },
			silver_birch = {  8.5,  8.5, 10.9, 12.7, 14.1, 15.0, 15.0, 15.0, 15.0 },
			downy_birch  = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 }
		},
		VT = {
			pine         = { 14.2, 14.2, 15.9, 17.0, 17.6, 17.9, 18.1, 18.1, 18.1 },
			spruce       = { 15.3, 15.3, 17.6, 19.0, 19.6, 19.9, 19.9, 19.9, 19.9 },
			silver_birch = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 },
			downy_birch  = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 }
		},
		CT = {
			pine         = { 12.0, 12.0, 14.1, 15.5, 16.1, 16.1, 16.1, 16.1, 16.1 },
			spruce       = { 12.0, 12.0, 14.1, 15.5, 16.1, 16.1, 16.1, 16.1, 16.1 },
			silver_birch = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 },
			downy_birch  = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 }
		}
	},
	peat = {
		Rhtkg = {
			pine         = { 15.3, 15.3, 17.6, 19.0, 19.6, 19.9, 19.9, 19.9, 19.9 },
			spruce       = { 15.2, 15.2, 18.4, 20.9, 22.8, 23.9, 23.9, 23.9, 23.9 },
			silver_birch = {  8.5,  8.5, 10.9, 12.7, 14.1, 15.0, 15.0, 15.0, 15.0 },
			downy_birch  = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 }
		},
		Mtkg = {
			pine         = { 14.0, 14.0, 17.4, 18.4, 18.9, 19.3, 19.3, 19.3, 19.3 },
			spruce       = { 15.3, 15.3, 17.6, 19.0, 19.6, 19.9, 19.9, 19.9, 19.9 },
			silver_birch = {  8.5,  8.5, 10.9, 12.7, 14.1, 15.0, 15.0, 15.0, 15.0 },
			downy_birch  = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 }
		},
		Ptkg = {
			pine         = { 13.2, 13.2, 16.3, 17.3, 17.8, 18.0, 18.0, 18.0, 18.0 },
			spruce       = { 15.3, 15.3, 17.6, 19.0, 19.6, 19.9, 19.9, 19.9, 19.9 },
			silver_birch = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 },
			downy_birch  = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 }
		},
		Vatkg = {
			pine         = { 12.8, 12.8, 15.3, 16.1, 16.5, 16.5, 16.5, 16.5, 16.5 },
			spruce       = { 12.8, 12.8, 15.3, 16.1, 16.5, 16.5, 16.5, 16.5, 16.5 },
			silver_birch = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 },
			downy_birch  = { 10.4, 10.4, 11.7, 12.7, 13.4, 13.4, 13.4, 13.4, 13.4 }
		}
	}
}, kalr2, kmty4, kspe4)

local function ghdomint(g, hdom)
	if not g then return inf end
	if hdom <= GHDOM[1] then
		return g[1]
	elseif hdom >= GHDOM[NHDOM] then
		return g[NHDOM]
	else
		for i=2, NHDOM do
			if hdom <= GHDOM[i] then
				local s = (GHDOM[i]-hdom)/(GHDOM[i]-GHDOM[i-1])
				return g[i-1]*s + g[i]*(1-s)
			end
		end
	end
	error("shouldn't go here")
end

local function th_g0(alr, mty, sdom, hdom)
	return ghdomint(G0[alr][mty][sdom], hdom)
end

local function th_g1(alr, mty, sdom, hdom)
	return ghdomint(G1[alr][mty][sdom], hdom)
end

---- First thinning ------------------------------------------------------------

local FF1 = xtab({
	OMT = { pine = 1250, spruce = 1000, silver_birch = 750, downy_birch = 950 },
	MT  = { pine = 1100, spruce = 1000, silver_birch = 750, downy_birch = 950 },
	VT  = { pine = 1000, spruce = 1000, silver_birch = 750, downy_birch = 950 },
	CT  = { pine = 1000, spruce = 1000, silver_birch = 750, downy_birch = 950 }
}, kmty4, kspe4)

local function fth_f1(mty, sdom)
	return FF1[mty][sdom] or inf
end

---- Cultivated stems ----------------------------------------------------------

local RLV = xtab({
	OMT = { pine=2400, spruce=2000, silver_birch=1600, downy_birch=1600 },
	MT  = { pine=2200, spruce=1800, silver_birch=1600, downy_birch=1600 },
	VT  = { pine=2200, spruce=1600, silver_birch=1600, downy_birch=1600 },
	CT  = { pine=2000, spruce=1600, silver_birch=1600, downy_birch=1600 }
}, kmty4, kspe4)

-- TODO: use the same vectorized lookup logic elsewhere too
local function rlv_f(mty, spe)
	if type(spe) == "number" then
		return RLV[mty][spe]
	elseif type(spe) == "cdata" then
		-- TODO: allow using out parameter
		local ret = {}
		for i=0, #spe-1 do
			ret[i+1] = RLV[mty][spe]
		end
		return ret
	else
		return RLV[mty]
	end
end

--------------------------------------------------------------------------------

return {
	cc_d0  = cc_d0,
	cc_a0  = cc_a0,
	th_g0  = th_g0,
	th_g1  = th_g1,
	fth_f1 = fth_f1,
	rlv_f  = rlv_f
}
