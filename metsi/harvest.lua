-- viitteet:
-- (Asikainen et al. 2001) [epäselvää mikä julkaisu on kyseessä]
-- (Kuitto et al. 1994) Puutavaran koneellinen hakkuu ja metsäkuljetus, Metsätehon tiedotus 410.
--   [https://www.metsateho.fi/wp-content/uploads/tiedotus-1994_410-compressed.pdf]
-- (Kärhä et al. 2004) Hakkuutähteen paalauksen ja paalien metsäkuljetuksen tuottavuus ja
--   kustannukset, Metsätehon raportti 179.
--   [https://www.metsateho.fi/wp-content/uploads/2015/02/metsatehon_raportti_179.pdf]
-- (Laitila et al. 2004) Pienpuuhakkeen tuotannon kustannustekijät ja toimituslogistiikka,
--   Metlan työraportteja 3.
--   [https://jukuri.luke.fi/items/738c3a17-8b1f-441c-b4c1-0bbebceb6196]
-- (Laitila et al. 2006) Cost calculators for the procurement of small sized thinning wood,
--   delimbed energy wood, logging residues and stumps for energy.
-- (Laitila et al. 2007) Kantojen noston ja metsäkuljetuksen tuottavuus, Metlan työraportteja 46.
--   [https://jukuri.luke.fi/items/6f6f1fd6-b085-4519-a53a-f69bfe78efd3]
-- (Laitila 2010) Kantojen korjuun tuottavuus, Metlan työraportteja 150.
--   [https://jukuri.luke.fi/items/f5e8abab-1ba6-488a-81b2-28c649b4618d]
-- (Rajamäki et al. 1996) Koneellisen harvennushakkuun tuottavuus, Metsätehon raportti 8.
--   [https://www.metsateho.fi/wp-content/uploads/2015/02/metsatehon_raportti_008.pdf]
-- (Rummukainen et al. 1995) Wood procurement in the pressure of change,
--   Acta Forestalia Fennica 248.
--   [https://www.silvafennica.fi/article/7510]
-- (Väkevä et al. 2001) Puutavaran metsäkuljetuksen ajanmenekki, Metsätehon raportti 123.
--   [https://www.metsateho.fi/wp-content/uploads/2015/02/metsatehon_raportti_123.pdf]

-- suositeltavaa luettavaa: koneellisen puunkorjuun perusteet
--   [https://puuhuolto.fi/koneellinen-puunkorjuu/]

local coding = require "metsi.coding"
local mm = require "metsi.math"
local spe3 = coding.spe3
local clamp = mm.clamp
local ceil, floor, fmod, exp, log, max, min, sqrt = math.ceil, math.floor, math.fmod, math.exp, math.log, math.max, math.min, math.sqrt

-- TODO POISTA VÄLIAIKAINEN KOKEILU !!!!!!!!!!!!!!!!!!!!!!!!!111
jit.opt.start("maxmcode=4096")
jit.opt.start("maxtrace=4000")

---- Koneellinen ainespuunkorjuu -----------------------------------------------

local MOTO_COEF = 1.197 * 1.276 -- (Kuitto et al. 1994) s. 32
-- TODO: maastoluokkakerroin (1; 0.765; 0.643)

-- (Kuitto et al. 1994) siirtymisaika motolla päätehakkuussa (min/runko)
-- y: poistuman tiheys (1/ha)
local function moto_z_pth(y)
	return MOTO_COEF * (-0.6347 + 0.000219*y + 945.36/(y + 1060))
end

-- (Kuitto et al. 1994) siirtymisaika motolla harvennushakkuussa (min/runko)
-- y: poistuman tiheys (1/ha)
local function moto_z_hh(y)
	local a1 = 0.000414*y - 0.03039
	if a1 <= 0 then
		-- ???: mistä tämä vakio tulee
		a1 = 0.000246
	end
	return MOTO_COEF * -.07255 * log(a1)
end

-- moton siirtymisaika (min/runko)
local function moto_z(y, ht)
	if ht == "clearcut" then
		return moto_z_pth(y)
	else
		return moto_z_hh(y)
	end
end

-- moton siirtymisaika (h/ha)
local function moto_zz(y, ht)
	return (1/60) * y * moto_z(y, ht)
end

local MOTO_K_COEF = {
	clearcut = {
		{ .52967,  .00089,  -205.89, -719.45, }, -- mänty
		{ .44472,  .00094,  -146.17, -862.05, }, -- kuusi
		{ -16.96600, -.00099, -143905.,   8341., }, -- koivu
	},
	thinning = {
		{ .65739,  .00041,  -85.413, -201.34, }, -- mänty
		{ .50001,  .00059,  -22.386, -85.621, }, -- kuusi
		{ .45624,  .00064,  -17.078,  -73.34 }, -- koivu
	}
}

-- (Kuitto et al. 1994) puun käsittelyaika motolla (h/runko)
-- s: puulaji
-- x: rungon koko (m^3)
-- ht: hakkuutapa "clearcut" | "thinning"
local function moto_k(s, x, ht)
	local b = MOTO_K_COEF[ht][spe3[s]]
	return (1/60) * (b[1] + b[2]*x*1000 + b[3]/(x*1000 - b[4]))
end

-- harvennushakkuun tuottavuuden kasvu
-- oletettavasti sovitettu (Rajamäki et al. 1996) taulukkoon 5
-- x: rungon koko (m^3)
local function moto_kmod_hh(x)
	if x >= 0.05 then
		if x <= 0.125 then
			return 1.+(0.01675+0.425*x)
		elseif x <= 0.2 then
			return 1.07
		elseif x <= 0.475 then
			return 1.+(0.12-0.25*x)
		end
	end
	return 1
end

-- puun käsittelyaika motolla (h/runko)
-- s: puulajikoodi
-- x: rungon koko (m^3)
-- ht: hakkuutapa "clearcut" | "thinning"
local function moto_ptime(s, x, ht)
	local k = moto_k(s, x, ht)
	if ht == "thinning" then
		k = k / moto_kmod_hh(x)
	end
	return MOTO_COEF * k
end

---- Manuhakkuu ----------------------------------------------------------------

local MANU_B1 = {
	{0.3270, 0.1040, 0.0730, 0.1010, 0.2350, 0.0703, 0.00000042, 0.0000000000000487, 0. }, -- mänty
	{-0.0468, 0.0824, -0.0720, -0.1240, -0.1310, 0.0571, -0.000000305, 0.0000000000000319, 0.}, -- kuusi
	{0.4580, 0.0984, -0.0745, -0.1270, -0.3910, 0.1100, 0.000000284, 0., -0.00167} -- koivu
}

local MANU_B2 = {
	{-0.613,  0.0491,  -0.0883,  0.281,  -0.0136}, -- mänty
	{-0.978,  0.0543,  -0.0933,  0.320,  -0.0160}, -- kuusi
	{-0.789,  0.0650,  -0.0955,  0.343,  -0.0180}, -- koivu
}

local function manup1(s3, xmt, snow, vb)
	local b = MANU_B2[s3]
	return 0.85 * exp(
		b[1]
		+ (xmt and b[2] or 0)
		+ b[3] * snow
		+ b[4] * log(1000*vb)
		+ b[5] * sqrt(1000*vb)
	)
end

local function manupx(s3, xmt, xht, snow, vb)
	local b = MANU_B1[s3]
	return 0.85 * exp(
		b[1]
		+ (xmt and b[2] or 0)
		+ b[3] * snow
		+ (xht and b[4] or 0)
		+ b[5] * log(1000*vb)
		+ b[6] * log(1000*vb)^2
		+ b[7] * (1000*vb)^2
		+ b[8] * (1000*vb)^4
		+ b[9] * 1000*vb
	)
end

-- h/runko
local function tmanu(sp, vbar, snow, xmt, ht, ifcut)
	local s3 = spe3[sp]
	local vb = min(vbar, 2.5)
	local p
	if ifcut then
		p = manup1(s3, xmt, snow, vb)
	else
		p = manupx(s3, xmt, ht == "thinning", snow, vb)
	end
	return vbar/p
end

---- Metsäkuljetus -------------------------------------------------------------

local AUV = 20 -- ajouraväli (m)
local AUM = 100 / AUV -- ajouramäärä 100m/ha
local AUM1 = 1 / AUM -- ajouravarsitiheyden kerroin (ha/100m)

-- v: kuljetettava määrä (m^3/ha)
-- k: kuorman koko (m^3)
-- *
-- d: lisä(?)kuljetusmatka (m)   [kaavan lähde epäselvä]
-- s: kuormausajomatka (m)
-- n: ajokertojen määrä
local function haulx(v, k)
	local s, n
	if v > k then
		s = 100 * k/(v*AUM1)
		n = ceil(v/k)
	else
		s = 100 * AUM
		n = 1
	end
	local d
	if n <= 15 then
		d = -3.5714*n + 143.5
	else
		d = -0.2963*n + 94.5
	end
	return d, s, n
end

-- (Kuitto et al. 1994) s.34
-- d: metsäkuljetusmatka (m)
-- v: kuljetettava määrä (m^3/ha)
-- k: kuorman koko (m^3)
-- *
-- m1: ajomatka kuormattuna (m)
-- m2: ajomatka tyhjänä (m)
-- s: kuormausajomatka (m)
-- n: ajokertojen määrä
local function hauldist(d, v, k)
	local aput, s, n = haulx(v, k)
	local trip = d + aput
	local m1 = max(trip-s*0.5, 50)
	local m2 = max(2*trip-m1, 50)
	return m1, m2, s, n
end

---- Ainespuun metsäkuljetus ---------------------------------------------------

-- keskimääräinen kuormankoko (Kuitto et al. 1994) s.33
local FORHAU_XLOADK = {
	coniferous = { st=12.8, ps=10.0, pl=11.6 },
	deciduous = { st=10.2, ps=8.0,  pl=9.3 }
}

-- keskimääräinen kuormankoko (Väkevä et al. 2001) taulukko 22 / 1998
local FORHAU_XLOADV = {
	coniferous = { st=13.4, ps=8.0, pl=11.3 },
	deciduous = { st=12.7, ps=6.9, pl=9.5 }
}

-- (Kuitto et al. 1994) taulukko 18
local FORHAU_FLOAD = {
	clearcut = {
		st = {0.1504, 0.616, 0.33599},
		ps = {0.3120, 1.178, 0.26002},
		pl = {0.1596, 0.894, 0.26415},
	},
	thinning = {
		st = {0.0942, 0.839,  0.32428},
		ps = {0.2770, 0.944,  0.18711},
		pl = {0.1642, 1.1838, 0.21249},
	}
}

-- (Kuitto et al. 1994) s.34 metsätraktorin ajonopeus maastoluokalla (m/min)
local FORHAU_FSPEED = { 29, 24, 21 }

-- (Kuitto et al. 1994) s.34 lehtipuun ajanmenekkikerroin
local FORHAU_FDECI = {
	clearcut = { st=1.14, ps=1.23, pl=1.14 },
	thinning = { st=1.08, ps=1.16, pl=1.08 }
}

-- (Kuitto et al. 1994) taulukko 19 ajoaikafunktion kertoimet
local FORHAU_FDRIVE1 = { 2.37, 2.88, 3.48 }
local FORHAU_FDRIVE2 = { 2.01, 2.34, 2.83 }

-- (Kuitto et al. 1994) taulukko 20 purkamisaikafunktion kertoimet
local FORHAU_FULOAD = {
	coniferous = { st=0.57, ps=0.80, pl=0.56 },
	deciduous = { st=0.57, ps=0.90, pl=0.60 }
}

-- (Kuitto et al. 1994) ss.33-34 puutavaran metsäkuljetuksen ajanmenekki metsätraktorilla (h/ha)
-- v: kuljetettava määrä (m^3/ha)
-- d: metsäkuljetusmatka (m)
-- tc: maastoluokka
-- isp: puulaji "coniferous" | "deciduous"
-- ht: hakkuutapa "clearcut" | "thinning"
-- ita: puutavaralaji "st" | "ps" | "pl"
local function forhau_forwarder_k(v, d, tc, isp, ht, ita)
	local k = FORHAU_XLOADK[isp][ita]
	local m1, m2, s = hauldist(d, v, k)
	local x = v * AUM1
	local y1_b = FORHAU_FLOAD[ht][ita]
	local z = y1_b[3] * sqrt(x)
	local y1 = 0.11 + (y1_b[1] + y1_b[2]*z)/z
	if isp == "deciduous" then
		y1 = y1 * FORHAU_FDECI[ht][ita]
	end
	local y2 = (0.04*k/z + s/FORHAU_FSPEED[tc])/k
	local y3 = (0.19 + m1*0.01*(FORHAU_FDRIVE1[tc] - 0.346*log(m1*0.01)))/k
	local y4 = (0.27 + m2*0.01*(FORHAU_FDRIVE2[tc] - 0.389*log(m2*0.01)))/k
	local y5 = 0.02 + 0.3/k + FORHAU_FULOAD[isp][ita]
	return 1.084 * 1.224 * (1/60) * v * (y1+y2+y3+y4+y5)
end

-- (Väkevä et al. 2001) taulukko 6-7 (a*b*c)
local FORHAU_VT67 = {
	clearcut = {
		coniferous = { st=1.0160, ps=0.9957, pl=1.0160 },
		deciduous = { st=1.0272, ps=1.0566, pl=1.0272 },
	},
	thinning = {
		coniferous = { st=1.0630, ps=1.0478, pl=1.0692 },
		deciduous = { st=1.0747, ps=1.1119, pl=1.0809 }
	}
}

-- (Väkevä et al. 2001) taulukko 8
local FORHAU_VT8 = {
	clearcut = { 0.03678, 0.04377 },
	thinning = { 0.03863, 0.04597 }
}

-- (Väkevä et al. 2001) taulukko 9
local FORHAU_VT9A = { 1.00, 0.62, 0.53 }
local FORHAU_VT9B = { 1.00, 0.75, 0.59 }

-- (Väkevä et al. 2001) taulukko 10
local FORHAU_VT10 = {
	coniferous = { st=0.55, ps=1.0, pl=0.58 }, -- havu
	deciduous = { st=0.77, ps=0.9, pl=0.73 } -- lehti
}

local FORHAU_VC = {
	clearcut = 1.007,
	thinning = 1.008
}

local FORHAU_VCEF = {
	clearcut = 1.224,
	thinning = 1.272
}

-- (Väkevä et al. 2001) puutavaran metsäkuljetuksen ajanmenekki metsätraktorilla (h/ha)
-- v: kuljetettava määrä (m^3/ha)
-- d: metsäkuljetusmatka (m)
-- zz: työmaan keskijäreys (m^3/runko)
-- tc: maastoluokka
-- isp: puulaji "coniferous" | "deciduous"
-- ht: hakkuutapa "clearcut" | "thinning"
-- ita: puutavaralaji "st" | "ps" | "pl"
local function forhau_forwarder_v(v, d, zz, tc, isp, ht, ita)
	local k = FORHAU_XLOADV[isp][ita]
	local m1, m2 = hauldist(d, v, k)
	local z = min(1000*zz, 1.5)  -- virhe alkuperäisessä? pitäisikö olla 1000*min(zz, 1.5)?
	local y1 = (52.6278 - 0.02057*z + 13898.4548/(z+111.5614)) * FORHAU_VT67[ht][isp][ita] * 0.01
	if ita ~= "st" then
		y1 = y1 * (1.099 + 0.00166*z)
	end
	local x = v * AUM1
	local s = 64.864 / sqrt(x)
	local y2 = s * FORHAU_VT8[ht][min(tc, 2)]
	local n1 = 5.8272 * log(18.1013*m1 - 53.7465)
	local y3 = m1 / (n1 * k * FORHAU_VT9A[tc])
	local n2 = 10.492 * log(1.02966*m2 - 3.12)
	local y4 = m2 / (n2 * k * FORHAU_VT9B[tc])
	local f = 0.067
	local g = 0.024
	local y5 = (FORHAU_VT10[isp][ita] + f + g) * FORHAU_VC[ht]
	return 1.084 * (1/60) * FORHAU_VCEF[ht] * v * (y1+y2+y3+y4+y5)
end

local function forhau_load(v, k)
	if v < 0.75*k then
		return 0, v
	end
	local r = fmod(v, k)
	if r < 0.75*k then
		return v-r, r
	end
	return v, 0
end

-- metsäkuljetuksen ajanmenekki metsätraktorilla (h/ha)
-- xdis: metsäkuljetusmatka kuvion ulkopuolella (m)
-- tc: maastoluokka
-- ht: hakkuutapa "clearcut" | "thinning"
-- v_*: tilavuus (m^3/puu)
-- w_*: pois kuljetettava runkoluku (1/ha)
local function forhau_forwarder(
	xdis, tc, ht,
	v_mantytukki, v_kuusitukki, v_koivutukki,
	v_mantykuitu, v_kuusikuitu, v_koivukuitu,
	w_mantytukki, w_kuusitukki, w_koivutukki
)
	local vajaa = 0
	local t = 0
	-- mäntytukki (Väkevä et al)
	do
		local v, r = forhau_load(v_mantytukki, FORHAU_XLOADV.coniferous.st)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_forwarder_v(v, xdis, v_mantytukki/w_mantytukki, tc, "coniferous", ht, "st")
		end
	end
	-- kuusitukki (Väkevä et al)
	do
		local v, r = forhau_load(v_kuusitukki, FORHAU_XLOADV.coniferous.st)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_forwarder_v(v, xdis, v_kuusitukki/w_kuusitukki, tc, "coniferous", ht, "st")
		end
	end
	-- koivutukki (Väkevä et al)
	do
		local v, r = forhau_load(v_koivutukki, FORHAU_XLOADV.deciduous.st)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_forwarder_v(v, xdis, v_koivutukki/w_koivutukki, tc, "deciduous", ht, "st")
		end
	end
	-- mäntykuitu (Kuitto et al; pitkä kuitupuu)
	do
		local v, r = forhau_load(v_mantykuitu, FORHAU_XLOADK.coniferous.pl)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_forwarder_k(v, xdis, tc, "coniferous", ht, "pl")
		end
	end
	-- kuusikuitu (Kuitto et al; pitkä kuitupuu)
	do
		local v, r = forhau_load(v_kuusikuitu, FORHAU_XLOADK.coniferous.pl)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_forwarder_k(v, xdis, tc, "coniferous", ht, "pl")
		end
	end
	-- koivukuitu (Kuitto et al; lyhyt kuitupuu)
	do
		local v, r = forhau_load(v_koivukuitu, FORHAU_XLOADK.deciduous.ps)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_forwarder_k(v, xdis, tc, "deciduous", ht, "ps")
		end
	end
	-- ylijäämät Kuiton pitkän koivukuidun malleilla
	if vajaa > 0 then
		t = t + forhau_forwarder_k(vajaa, xdis, tc, "deciduous", ht, "pl")
	end
	-- print("v_mäntytukki", v_mantytukki)
	-- print("v_kuusitukki", v_kuusitukki)
	-- print("v_koivutukki", v_koivutukki)
	-- print("v_mäntykuitu", v_mantykuitu)
	-- print("v_kuusikuitu", v_kuusikuitu)
	-- print("v_koivukuitu", v_koivukuitu)
	-- print("w_mäntytukki", w_mantytukki)
	-- print("w_kuusitukki", w_kuusitukki)
	-- print("w_koivutukki", w_koivutukki)
	-- print("t", t)
	return t
end

-- (Rummukainen et al. 1993) kaavat (28) ja (30)
-- tukkipuun metsäkuljetuksen ajanmenekki maataloustraktorilla (h/ha)
-- v: kuljetettava määrä (m^3/ha)
-- k: kuormakoko (m^3)
-- xdis: metsäkuljetusmatka kuvion ulkopuolella (m)
-- s: lumen syvyys (cm)
-- ht: hakkuutapa "clearcut" | "thinning"
local function forhau_saw_farmtractor(v, k, xdis, s, ht)
	local d = xdis + haulx(v, k)
	local l = v * AUM1
	local CE_mpt = 1 / exp(
		1.46
		- 0.00531 * s
		- 0.000000000201 * s^5
		+ 0.428 * log(l)
		- 0.124 * log(l)^2
		+ 0.162 * sqrt(l)
		+ 0.104 * log(d)
		- 0.0535 * sqrt(d)
	)
	if ht == "thinning" then
		CE_mpt = 1.07 * CE_mpt
	end
	return 1.043 * v * CE_mpt
end

-- (Rummukainen et al. 1993) kaavat (29) ja (31)
-- kuitupuun metsäkuljetuksen ajanmenekki maataloustraktorilla (h/ha)
-- v: kuljetettava määrä (m^3/ha)
-- k: kuormakoko (m^3)
-- xdis: metsäkuljetusmatka kuvion ulkopuolella (m)
-- s: lumen syvyys (cm)
-- ht: hakkuutapa "clearcut" | "thinning"
local function forhau_pulp_farmtractor(v, k, xdis, s, ht)
	local d = xdis + haulx(v, k)
	local l = v * AUM1
	local CE_mpk3 = 1 / exp(
		2.18
		- 0.000158 * s^2
		- 0.01 * sqrt(s)
		+ 0.280 * log(l)
		- 0.0328 * log(l)^2
		- 0.0446 * sqrt(d)
	)
	if ht == "thinning" then
		CE_mpk3 = 1.025 * CE_mpk3
	end
	return 1.043 * v * CE_mpk3
end

-- metsäkuljetuksen ajanmenekki maataloustraktorilla (h/ha)
-- s: lumen syvyys (cm)
-- xdis: metsäkuljetusmatka kuvion ulkopuolella (m)
-- ht: hakkuutapa "clearcut" | "thinning"
-- v_*: tilavuus (m^3/puu)
local function forhau_farmtractor(
	s, xdis,
	v_mantytukki, v_kuusitukki, v_koivutukki,
	v_mantykuitu, v_kuusikuitu, v_koivukuitu
)
	local vajaa = 0
	local t = 0
	-- mäntytukki
	do
		local v, r = forhau_load(v_mantytukki, FORHAU_XLOADV.coniferous.st)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_saw_farmtractor(v_mantytukki, FORHAU_XLOADV.coniferous.st, xdis, s, ht)
		end
	end
	-- kuusitukki
	do
		local v, r = forhau_load(v_kuusitukki, FORHAU_XLOADV.coniferous.st)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_saw_farmtractor(v_kuusitukki, FORHAU_XLOADV.coniferous.st, xdis, s, ht)
		end
	end
	-- koivutukki
	do
		local v, r = forhau_load(v_koivutukki, FORHAU_XLOADV.deciduous.st)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_saw_farmtractor(v_koivutukki, FORHAU_XLOADV.deciduous.st, xdis, s, ht)
		end
	end
	-- mäntykuitu (pitkä)
	do
		local v, r = forhau_load(v_mantykuitu, FORHAU_XLOADK.coniferous.pl)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_pulp_farmtractor(v_mantykuitu, FORHAU_XLOADK.coniferous.pl, xdis, s, ht)
		end
	end
	-- kuusikuitu (pitkä)
	do
		local v, r = forhau_load(v_kuusikuitu, FORHAU_XLOADK.coniferous.pl)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_pulp_farmtractor(v_kuusikuitu, FORHAU_XLOADK.coniferous.pl, xdis, s, ht)
		end
	end
	-- koivukuitu (lyhyt)
	do
		local v, r = forhau_load(v_koivukuitu, FORHAU_XLOADK.deciduous.ps)
		vajaa = vajaa+r
		if v > 0 then
			t = t + forhau_pulp_farmtractor(v_koivukuitu, FORHAU_XLOADK.deciduous.ps, xdis, s, ht)
		end
	end
	-- ylijäämä pitkänä koivukuituna
	if vajaa > 0 then
		t = t + forhau_pulp_farmtractor(vajaa, FORHAU_XLOADK.deciduous.pl, s, ht)
	end
	return t
end

---- Energiapuukertymä ---------------------------------------------------------

-- puun katkonta 5m pätkiin
local function eker(d, h, v)
	-- oletus: läpimitta alenee d13sta latvaan lineaarisesti
	local ez2 = d / (h-1.3)
	-- jätetaan vähintään 1-2 m patka metsään
	-- jätetaan 3 cm latvalapimitasta lähtien metsään
	local patka = max(min(h%5, 3/ez2), min(floor(h/5), 2))
	-- lasketaan karkea arvio pätkän tilavuudesta ympyräkartion kaavalla
	-- (pii*r^2*h)/3:
	-- lasketaan uudelleen katkonta d
	-- 3.142*/(3*4)= n. 0.262
	-- metsään jäävä latvuksen tilavuus ez4
	local ez4 = 0.262 * patka * (0.01*patka*ez2)^2
	-- korjattava tilavuusosuus
	return clamp(1-ez4/v, 0, 1)
end

---- Energiapuu ----------------------------------------------------------------

local ECOEF1 = 1.3  -- metsäkuljetus
local ECOEF2 = 1.2  -- motohakkuu
local ECOEF3 = 1.25 -- korjuri

-- (Laitila et al. 2004) s. 24 metsätraktorin tyhjänä ajon ajanmenekki (s/kuorma)
-- l_t: tyhjänäajomatka (m)
local function ew_T_tyh_ajo(l_t)
	return 10.868+1.241*l_t
end

-- (Laitila et al. 2004) s. 29 metsätraktorin kuormattuna ajon ajanmenekki (s/kuorma)
-- l_k: kuormattuna-ajomatka (m)
local function ew_T_k(l_k)
	return 3.99+1.493*l_k
end

---- Energiapuun korjuu (tapa 1: kaato motolla ja kuljetus metsätraktorilla) ---

-- (Laitila et al. 2004) ss. 19-20 motolla kaato (h/ha)
-- x: poistuma (runkoa/ha)
-- v: kokopuun keskitilavuus (m^3)
local function ew_tmoto1(x, v)
	local T_siirt = 0.277 + 2412.301/x  -- s/puu
	local y = 2.488 + 0.000667*x - 33.68*v
	y = clamp(1, y, 6) -- ei julkaisussa
	local T_kasitt = 22.815 + 31.2*v - 3.373*y  -- s/puu
	return ECOEF1 * 1.25 * (1/3600) * x * (T_siirt+T_kasitt) -- h/ha
end

-- (Laitila et al. 2004) ss. 27-28 metsätraktorilla kuljetus (h/ha)
-- v: poistuma (m^3/ha)
-- l_t: tyhjänäajomatka (m)
-- l_k: kuormattuna-ajomatka (m)
-- v_k: kuormakoko (m^3)
local function ew_thaul1(v, l_t, l_k, v_k)
	local z = v*AUM1
	local x_kk = 0.138 + 0.04107*z
	local v_tkk = 0.0678 + 0.21*sqrt(x_kk)
	local T_kuorm_kk = -81.429 + 43.906/v_tkk
	local T_ka_k = 4.925 + 233.094/z
	local T_p = 15.154 + (16.689/0.6)
	return ECOEF2 * 1.2 * (1/3600) * v
		* (T_kuorm_kk + T_ka_k + T_p + (ew_T_tyh_ajo(l_t)+ew_T_k(l_k))/v_k)
end

local function ew_t1(x, v, v_k, l_k, l_t)
	return ew_tmoto1(x, v), ew_thaul1(v, l_t, l_k, v_k)
end

---- Energiapuun korjuu (tapa 2: kaato ja kuljetus korjurilla) -----------------

-- (Laitila et al. 2006) korjurilla kaato ja metsäkuljetus (h/ha)
-- evol: poistuma (m^3/ha)
-- rl: poistuma (runkoa/ha)
-- xkuorma: kuormakoko (m^3)
-- xtrip1: kuormattuna-ajomatka (m)
-- xtrip2: tyhjänäajomatka (m)
-- apuy: kuormausajomatka (m)
-- kpl: ajokertojen määrä
local function ew_t2(evol, rl, xkuorma, xtrip1, xtrip2, apuy, kpl)
	local vbar = evol/rl
	local vol100 = evol * AUM1
	local ua = -10.474 + 460*vbar + 0.007534*rl
	if ua <= 0 then
		ua = 3.6
	end
	local tura = apuy * ua * kpl
	local tsiirt2 = 0.373*rl + 1990.103
	local apu1 = min(4.616 + 0.0001987*rl - 46.7*vbar, 8)
	if apu1 <= 0 then
		apu1 = 1
	end
	local tkaato = rl*(17.848 + 73.04*vbar - 1.883*apu1)
	local tc_el2 = ECOEF3 * 1.25 * (1/3600) * (tura*0.5 + tsiirt2 + tkaato)
	local tpiste = 0.0727 + 0.02095*vol100
	local taakka = 0.01935 + 0.524*tpiste
	local tkmaus = 36.981 + 22.962/taakka
	local tkmajo = tura/(2*evol)
	local tpurku = 49.69
	local tc_eh2 = ECOEF3 * 1.2 * (1/3600) * evol
		* (tkmaus + tkmajo + tpurku + (ew_T_tyh_ajo(xtrip2)+ew_T_k(xtrip1))/xkuorma)
	return tc_el2, tc_eh2
end

---- Energiapuun korjuu (tapa 3: metsurihakkuu ja kuljetus metsätraktorilla) ---

local XMANU = {
	{75.8, 1737., 7.559, -9.0},
	{118.3, 1130., 5.227, -7.0},
	{141.4, 1373., 7.093, -8.0}
}

-- metsurihakkuu (lähde?) (h/ha)
-- pet: poistuma puulajeittain (m^3/ha)     1: mänty, 2: kuusi, 3: koivu
-- erl: poistuma puulajeittain (runkoa/ha)  1: mänty, 2: kuusi, 3: koivu
local function ew_tmanu3(pet, erl)
	local evol = pet[1] + pet[2] + pet[3]
	local rl = erl[1] + erl[2] + erl[3]
	local apusum = 0
	for j=1, 3 do
		if erl[j] > 0 and pet[j] > 0 then
			local vb = min(pet[j]/erl[j], 0.201)
			local b = XMANU[j]
			local apu = (b[1] + b[2]*vb + b[3]/vb + b[4]*vb^2) * pet[j]/evol
			apusum = apusum + apu*(1/7)
		end
	end
	if apusum == 0 then
		return 1/0
	end
	return rl / (1.25*apusum)
end

-- (Laitila et al. 2004) ss.27-30 metsurihakkuuseen perustuva metsäkuljetus (h/ha)
-- v: poistuma (m^3/ha)
-- l_t: tyhjänäajomatka (m)
-- l_k: kuormattuna-ajomatka (m)
-- v_k: kuormakoko (m^3)
local function ew_thaul3(v, l_t, l_k, v_k)
	local z = v*AUM1
	local x_kk = 0.174 + 0.01704*z
	local v_tmets = 0.0467 + 0.08652*sqrt(x_kk)
	-- ei vastaa julkaisua, päivitetty Laitilan excel-laskentaohjelmasta
	local T_kuorm_mets = 28.113 + 27.323/v_tmets
	local T_ka_m = 8.626 + 193.525/z
	local T_p = 15.154 + (16.689/0.6)
	return ECOEF2 * 1.2 * (1/3600) * v
		* (T_kuorm_mets + T_ka_m + T_p + (ew_T_tyh_ajo(l_t)+ew_T_k(l_k)/v_k))
end

local function ew_t3(pet, erl, v_k, l_k, l_t)
	return ew_tmanu3(pet, erl), ew_thaul3(pet[1]+pet[2]+pet[3], l_t, l_k, v_k)
end

---- Energiapuun korjuu (tapa 123: halvin tapa) --------------------------------

local function nnan(x)
	if x == x then return x end
end

-- hakkuun ja kuljetuksen ajanmenekki ja kustannus (h/ha), (€/ha)
-- pet: poistuma puulajeittain (m^3/ha)     0: mänty, 1: kuusi, 2: koivu
-- erl: poistuma puulajeittain (runkoa/ha)  0: mänty, 1: kuusi, 2: koivu
-- xdis: metsäkuljetusmatka kuvion ulkopuolella (m)
-- osapuu: true->osapuu, false->kokopuu
-- ecost1: moton kustannus (€/h)                puuttuu -> ei kokeilla motoa
-- ecost2: metsurihakkuun kustannus (€/h)       puuttuu -> ei kokeilla metsuria
-- ecost3: korjurin kustannus (€/h)             puuttuu -> ei kokeilla korjuria
-- ecost4: metsätraktorin kustannus (€/h)       puuttuu -> ei kokeilla motoa eikä metsuria
-- ecost12: koneiden siirtokustannus (€/ha)
local function ew_tc123(pet, erl, xdis, osapuu, ecost1, ecost2, ecost3, ecost4, ecost12)
	local evol = pet[1] + pet[2] + pet[3]
	local rl = erl[1] + erl[2] + erl[3]
	if evol == 0 or rl == 0 then
		-- ei korjattavaa
		return 0, 0, 0, 0
	end
	ecost1 = nnan(ecost1)
	ecost2 = nnan(ecost2)
	ecost3 = nnan(ecost3)
	ecost4 = nnan(ecost4)
	local xkuorma = 7
	local cosapuu = osapuu and 1.3 or 1.0
	local m1, m2, s, n = hauldist(xdis, evol, xkuorma)
	local tc_el1, tc_eh1, c_el1, c_eh1
	local tc_el2, tc_eh2, c_el2, c_eh2
	local tc_el3, tc_eh3, c_el3, c_eh3
	local enco1, enco2, enco3 = 1/0, 1/0, 1/0
	if ecost1 and ecost4 then
		tc_el1, tc_eh1 = ew_t1(rl, evol/rl, xkuorma, m1, m2)
		c_el1, c_eh1 = ecost1*tc_el1+ecost12, ecost4*tc_eh1 + 2*ecost12
		if tc_el1+tc_eh1 > 0 then enco1 = c_el1+c_eh1 end
	end
	if ecost3 then
		tc_el2, tc_eh2 = ew_t2(evol, rl, xkuorma, m1, m2, s, n)
		c_el2, c_eh2 = ecost3*tc_el2+0.5*ecost12, ecost3*tc_eh2+0.5*ecost12
		if tc_el2+tc_eh2 > 0 then enco2 = c_el2+c_eh2 end
	end
	if ecost2 and ecost4 then
		tc_el3, tc_eh3 = ew_t3(pet, erl, xkuorma, m1, m2)
		c_el3, c_eh3 = ecost2*tc_el3, ecost4*tc_el3+ecost12
		if tc_el3+tc_eh3 > 0 then enco3 = c_el3+c_eh3 end
	end
	local ecmin = min(enco1, enco2, enco3)
	if ecmin == 1/0 then
		return 0, 0, 0, 0
	elseif ecmin == enco1 then
		return tc_el1*cosapuu, tc_eh1, c_el1*cosapuu, c_eh1
	elseif ecmin == enco2 then
		return tc_el2*cosapuu, tc_eh2, c_el2*cosapuu, c_eh2
	else
		return tc_el3*cosapuu, tc_eh3, c_el3*cosapuu, c_eh3
	end
end

---- Energiapuun korjuu (rankahakkuu) ------------------------------------------

-- (Laitila et al. 2006) siirtymisen ja prosessoinnin ajanmenekki (h/ha)
-- v: poistuma (m^3/ha)
-- f: poistuma (runkoa/ha)
local function ew_tmoto4(v, f)
	local tsiirt = 0.6*13.2366*exp(-0.0005*f)
	local rpros = 0.6*(29.173 + 125*v/f - 0.00268*f)
	return (1/3600)*1.25*f*(tsiirt+rpros)
end

-- (Kuitto et al. 1994) s.34-35 puutavaran metsäkuljetuksen ajanmenekki (h/ha)
-- v: kuljetettava määrä (m^3/ha)
-- m1: ajomatka kuormattuna (m)
-- m2: ajomatka tyhjänä (m)
-- k: kuormakoko (m^3)
-- s: kuormausajomatka (m)
local function ew_thaul4(v, m1, m2, k, s)
	local x = v * AUM1
	local t19_b1, t19_b2 = 2.37, 2.01 -- TODO: taulukko 19
	local y3 = (0.19 + 0.01*m1*(t19_b1-0.346*log(0.01*m1)))/k
	local y4 = (0.27 + 0.01*m2*(t19_b2-0.389*log(0.01*m2)))/k
	local t18_b3 = 0.21249 -- TODO: taulukko 18
	local z = t18_b3*sqrt(x)
	local y1 = 0.11+(0.1642+1.1838*z)/z
	local y2_b1 = 29 -- TODO: s.34 maastoluokan mukaan päättely
	local y2 = (0.04*k/z + s/y2_b1)/k
	local t20_b1 = 0.58 -- TODO: taulukko 20
	local y5 = 0.02 + 0.3/k + t20_b1
	return (1/60)*1.12*1.2*v*(y1+y2+y3+y4+y5)
end

local function ew_t4(estevol, rl, xdis)
	local xkuorma = 7
	local m1, m2, s = hauldist(xdis, estevol, xkuorma)
	return ew_tmoto4(estevol, rl), ew_thaul4(estevol, m1, m2, xkuorma+2, s)
end

-- energiapuun korjuun ajanmenekki (h/ha) ja kustannus (€/ha) rankahakkuuna
-- estevol: runkotilavuus (m^3/ha)
-- rl: runkoluku (1/ha)
-- xdis: metsäkuljetusmatka kuvion ulkopuolella (m)
-- ecost1: harvesterin kustannus (€/h)
-- ecost4: metsätraktorin kustannus (€/h)
-- ecost12: koneiden siirtokustannus (€/ha)
local function ew_tc4(estevol, rl, xdis, ecost1, ecost4, ecost12)
	local tc_el4, tc_eh4 = ew_t4(estevol, rl, xdis)
	local c_el4 = tc_el4 > 0 and ecost1*tc_el4+ecost12 or 0
	local c_eh4 = tc_eh4 > 0 and ecost4*tc_eh4+ecost12 or 0
	return tc_el4, tc_eh4, c_el4, c_eh4
end

---- Hakkuutähteen korjuu (tapa 1: irtorisu) -----------------------------------

-- (Asikainen et al. 2001) hakkuutähteen korjuun ajanmenekki irtorisu itapa=1 (h/m^3)
-- tvol: hakkuutähteen määrä (m^3)
-- xdis: metsäkuljetusmatka kuvion ulkopuolella (m)
local function ht_t1(tvol, xdis)
	local xload = 7.8
	local xload1 = 1/xload
	local m1, m2 = hauldist(xdis, tvol, xload)
	local vol100 = tvol * AUM1
	local xaut = 0.06*vol100
	local taakka = log(max(0.290 + 0.120*log(xaut), 0.1))
	local y1 = 0.60 + 0.059 - 0.78*taakka
	local y2 = 0.039/xaut + 0.250 + 2.44/vol100
	local y3 = (0.50 + 0.018*0.53*m2) * xload1
	local y4 = 0.87 + 0.019*0.47*m1
	local vk = 24.55 + 96.33 * xload1
	local zk = vk * (1/50)
	y4 = y4 / (xload*zk)
	local y5 = 0.20 + 0.28 - 0.4*taakka
	return 1.2 * (1/60) * (y1+y2+y3+y4+y5)
end

---- Hakkuutähteen korjuu (tapa 2: risutukki) ----------------------------------

-- (Kärhä et al. 2004) hakkuutähteen korjuun ajanmenekki risutukin paalaus itapa=2 (h/m^3)
-- tvol: hakkuutähteen määrä (m^3/ha)
local function ht_t2a(tvol)
	local vol100 = tvol * AUM1 -- ajouravarsitiheys (m^3/100m)
	local rt1 = 0 -- hakkuutähdekasojen ja -karheiden laatu (0: hyvä, 1: huono)
	local rt2 = 0 -- kuormaustapa (0: yhdeltä puolelta, 1: molemmilta puolilta ajouraa)
	local xaut = 0.5364 + 0.0089*vol100 - 0.0260*rt1 + 0.1540*rt2 -- työpisteen koko
	local rt3 = sqrt(xaut)
	local yy1 = 4.7914/rt3 -- kuormausajomatka
	-- paalauksen tehoajanmenekki (Timberjack & Pika RS 2000)
	local yy2 = (1.1328+0.1496*xaut) * 0.5*(2.5654+3.7328) / rt3
	-- palstalla-ajoajanmenekki (min/kuorma):
	--   y = -36.753 + 7.1321*log(x+185.838)
	-- missä
	--   x = palstalla-ajomatka
	-- mallin laadinta-aineistossa x keskimäärin 43m:
	--   -36.753 + 7.1321*log(43+185.838) = 1.9958015003635339
	-- laadinta-aineistossa hakkuutähdekertymä keskimäärin 62m^3.
	-- alkuperäisessä koodissa lukee 1.9958/(tvol/62) [ = 62*1.9958/tvol],
	-- mutta jos yy3 on min/m^3 niin eikö tässä ei pitäisi olla 1.9958 min / 62 m^3 ?
	local yy3 = 62*1.9958 / tvol
	return 1.2 * (1/60) * (yy1+yy2+yy3)
end

-- (Kärhä et al. 2004) hakkuutähteen korjuun ajanmenekki risutukkipaalien metsäkuljetus (h/m^3)
-- tvol: hakkuutähteen määrä (m^3/ha)
-- xdis: metsäkuljetusmatka kuvion ulkopuolella (m)
local function ht_t2b(tvol, xdis)
	local xload = 10.0
	local xload1 = 1/xload
	local m1, m2 = hauldist(xdis, tvol, xload)
	local vol100 = tvol * AUM1
	local xaut1 = 0.2727 * sqrt(vol100)
	local y1 = -24.4052 + 8.9719*log(xaut1+15.3049)
	y1 = y1*xload1 + 0.02
	local apuy1 = 7.2436/sqrt(xaut1)
	local y2 = -8.6699 + 2.0646*log(apuy1+70.6716)
	y2 = (y2+0.08)*xload1
	local y3 = -124.4531 + 18.0638*log(m2+990.633)
	y3 = (y3+0.19)*xload1
	local y4 = -106.841 + 16.5735*log(m1+630.318)
	y4 = (y4+0.16)*xload1
	local y5 = -6.1060 + 5.1620*log(xload+0.7604)
	y5 = y5*xload1 + 0.01
	return 1.2 * (1/60) * (y1+y2+y3+y4+y5)
end

---- Hakkuutähteen korjuu (tapa 3: palstahaketus) ------------------------------

-- (Asikainen et al. 2001) hakkuutähteen korjuun ajanmenekki palstahaketus itapa=3 (h/m^3)
-- tvol: hakkuutähteen määrä (m^3/ha)
-- xdis: metsäkuljetusmatka kuvion ulkopuolella (m)
local function ht_t3(tvol, xdis)
	local xload = 7.0
	local xload1 = 1/xload
	local m1, m2 = hauldist(xdis, tvol, xload)
	local vol100 = tvol * AUM1
	local xaut = 0.06*vol100
	local taakka = log(max(0.072 + 0.022*log(xaut), 0.1))
	local y1 = 0.64 - 2.49  - 1.78*taakka
	local y2 = 0.023/xaut + 0.135 + 3.07/vol100
	local y3 = (0.26 + 0.017*0.47*m2) * xload1
	local y4 = (1.11 + 0.017*0.53*m1) * xload1
	local y5 = 0.27 + 0.31
	return 1.5 * (1/60) * (y1+y2+y3+y4+y5)
end

---- Hakkuutähteen korjuu (tapa 123: halvin tapa) ------------------------------

-- TODO: kaukokuljetus ja haketus välivarastolla/käyttöpisteessä puuttuu.
-- alkuperäisessä koodissa haketus välivarastolla tai käyttöpisteessä lasketaan mukaan
-- kaukokuljetuskustannuksiin, tästä puuttuu kaukokuljetuskustannukset.
-- tämä ei varmaan mene ihan taiteen sääntöjen mukaan koska tapa 3 haketus on mukana ajanmenekissä

-- hakkuutähteen ajanmenekki halvimmalla tavalla (h/ha)
-- tvol: hakkuutähteen määrä (m^3/ha)
-- xdist: metsäkuljetusmatka kuvion ulkopuolella (m)
-- ecost4: metsätraktorin kustannus (€/h)
-- ecost5: paalaimen kustannus (€/h)
-- ecost12: koneiden siirtokustannus (€/ha)
-- ht1: kokeillaanko irtorisuna?
-- ht2: kokeillaanko risutukkina?
-- ht3: kokeillaanko palstahaketuksena?
local function ht_tc123(tvol, xdist, ecost4, ecost5, ecost12, ht1, ht2, ht3)
	local tc_hth1, tc_hth2, tc_hth3
	local yc1, yc2, yc3 = 1/0, 1/0, 1/0
	if ht1 ~= false then
		tc_hth1 = ht_t1(tvol, xdist)
		yc1 = ecost4*tc_hth1
	end
	if ht2 ~= false then
		local y = ht_t2a(tvol)
		local yy = ht_t2b(tvol, xdist)
		tc_hth2 = y+yy
		yc2 = ecost4*y + ecost5*yy
	end
	if ht3 ~= false then
		tc_hth3 = ht_t3(tvol, xdist)
		yc3 = ecost4*tc_hth3
	end
	local yc = min(yc1, yc2, yc3)
	local tc_hth
	if yc == 1/0 then
		return 0, 0
	elseif yc == yc1 then
		tc_hth = tc_hth1
	elseif yc == yc2 then
		tc_hth = tc_hth2
	else
		tc_hth = tc_hth3
	end
	return 1.2*tc_hth*tvol, 1.2*yc*tvol+ecost12
end

---- Kannot --------------------------------------------------------------------

local STUMP_COEF = 1.2 * 1.25

-- (Laitila et al. 2010) kokonaissiirtymäaika kannonnostossa (h/ha)
-- x: runkoja/ha
local function stump_tmove(x)
	return STUMP_COEF * (1/3600) * (1.647*x + 1097.165)
end

-- kannonnoston ajanmenekki. kaavan alkuperä epäselvä. (h/kanto)
-- s: puulaji
-- d: läpimitta (cm)
local function stump_tlift(s, d)
	local t = 8.0155 + 0.01823 * (1.33*d)^2
	if s ~= 2 then
		t = 1.24 * t
	end
	return STUMP_COEF * (1/3600) * t
end

local function stump_hauldist(hdis, evol, xkuorma)
	local apuy, aput
	local apu100 = 100 / AUV
	local vol100 = evol * AUM1
	if evol > xkuorma then
		apuy = 100*xkuorma/vol100
		local kpl = max(ceil(evol/xkuorma), 1)
		local ikpl = ceil(kpl/2)
		-- alkuperäisessä:
		--            ikpl             kpl-ikpl
		--   aput = [ sum  (apuy*i)  +   sum  (apuy*j) ] * 0.85/kpl
		--            i=1                j=1
		aput = apuy * 0.5 * (ikpl*(ikpl+1) + (kpl-ikpl)*(kpl-ikpl+1)) * 0.85 / kpl
	else
		apuy = 100*apu100
		aput = apuy
	end
	local trip = hdis + aput
	local xtrip1 = max(trip-apuy*0.5, 50)
	local xtrip2 = max(2*trip-xtrip1, 50)
	return xtrip1, xtrip2
end

-- (Laitila et al. 2010) kantojen metsäkuljetuksen ajanmenekki (h/ha)
-- v: tilavuus (kannot+juuristo m^3/ha)
-- d: metsäkuljetusmatka (m)
local function stump_thaul(v, d)
	if v < 0.1 then
		-- alkuperäisessä koodissa tänne mennään jos v>0, mutta y15-termi räjähtää jos v on pieni,
		-- joten tässä skipataan. TODO: testaa tapahtuuko tämä myös alkuperäisessä.
		return 0
	end
	local k = 10.0
	local x_k, x_t = stump_hauldist(d, v, k)
	local z = v * AUM1
	local y10 = 7.863 + 1.063*x_t
	local y11 = 17.708 + 1.391*x_k
	local y12 = 0.922 + 0.03782*z
	local y13 = 0.159 + 0.05404*sqrt(y12)
	local y14 = 188.950 - 382.162*y13
	local y15 = 2.552 + 227.229/z
	local y16 = 37.172
	return 1.2*1.2*(1/3600)*((y10+y11)/k + y14 + y15 + y16)
end

---- Valvonta ja suunnittelu ---------------------------------------------------

-- työpäivän pituus (cmin)
local ADMI_LD = 44000

-- (Rummukainen et al. 1995) 3.3.5.1.2 matkustusaika (cmin) kaava (45)
-- area: kuvion pinta-ala (ha)
-- xdis: metsäkuljetusmatka kuvion ulkopuolella (m)
local function admi_travel(area, xdis)
	local c_kv = 1000
	local d_a = 85
	local d_j = 2*(max(0, xdis - 100*sqrt(area)/2) / 1000)
	return c_kv + 404 + 83.4*d_a + 1500*d_j
end

-- (Rummukainen et al. 1995) 3.3.5.1.3 suunnitteluaika (cmin) kaava (46)
-- a_l: leimikon pinta-ala (ha)
-- h_t: harvennushakkuu-dummy (true/false)
local function admi_pla(a_l, h_t)
	-- Rummukaisen malli perustuu Halisen (1984) mittausaineistoon, eli vanhentuneeseeen
	-- mittausmenetelmään, eikä toimi liian isoilla kuvioilla, joten pysähdytään 3.75ha.
	-- (Halinen 1984) Pystymittauksen ajanmenekki, Metsätehon raportti 390.
	a_l = min(a_l, 3.75)
	-- TODO: tästä puuttuu melan q1
	return a_l * 0.7 * (9788-1759*a_l + 240*a_l^2 + (h_t and 3536 or 0))
end

-- (Rummukainen et al. 1995) 3.3.5.1.4 valvonnan ajanmenekki (cmin)
-- kaava (48) englanninkielisessä julkaisussa, vähän erilainen
-- totvo: tilavuus (m^3)
-- manu: manuaalinen korjuu-dummy (true/false)
local function admi_sup(totvo, manu)
	local tsup = 2500 -- yhden valvontakierroksen pituus (cmin)
	local v_vt = manu and 150 or 2000 -- hakkuumäärä valvontakierrosten välissä (m^3)
	return (1 + floor(totvo/v_vt))*tsup
end

-- (Rummukainen et al. 1995) 3.3.5.1.6 mittaus tienvarressa kaava (52) tukki (cmin/m^3)
-- v_tt: tukkipuun määrä (m^3)
local function admi_t1s(v_tt)
	local d_ktm = 0.15
	local d_kpl = 12
	local v_tkpl = 0.23
	local d_tl = 300
	local d_tv = 350
	local v_tp = 50
	return (1+d_ktm)*(d_kpl*v_tt/v_tkpl + (d_tl+d_tv)*v_tt/v_tp)
end

-- (Rummukainen et al. 1995) 3.3.5.1.6 kuitupuun mittaus tienvarressa kaava (55) (cmin/m^3)
-- v_kt: kuitu- ja energiapuun määrä (m^3)
local function admi_t1pa(v_kt)
	local v_kp = 39
	return 34.7*v_kt + 1095*v_kt/v_kp
end

-- (Rummukainen et al. 1995) 3.3.5.1.6 kuitupuun mittaustulosten laskenta kaava (56) (cmin/m^3)
-- v_kt: kuitu- ja energiapuun määrä (m^3)
local function admi_t1pb(v_kt)
	local v_kp = 39
	return 1.15*v_kt + 95*v_kt/v_kp
end

-- (Rummukainen et al. 1995) 3.3.5.1.6 puun mittaus tienvarressa kaava (58) (h/ha)
-- area: kuvion pinta-ala (ha)
-- xdis: metsäkuljetusmatka kuvion ulkopuolella (m)
-- v_tt: tukkipuun määrä (m^3)
-- v_kt: kuitupuun määrä (m^3)
-- h_t: harvennushakkuu-dummy (true/false)
-- manu: manuaalinen korjuu-dummy (true/false)
local function admi_t1(area, xdis, v_tt, v_kt, h_t, manu)
	local ct_kaj = admi_travel(area, xdis)
	local cwtkm_cepmm, ce_pml = 0, 0
	if v_tt > 0 then
		cwtkm_cepmm = cwtkm_cepmm + admi_t1s(v_tt)
	end
	if v_kt > 0 then
		cwtkm_cepmm = cwtkm_cepmm + admi_t1pa(v_kt)
		ce_pml = admi_t1pb(v_kt)
	end
	local tpile = cwtkm_cepmm + (cwtkm_cepmm/(ADMI_LD-ct_kaj))*ct_kaj
	local c_ttil = 1500
	local cw_ls = admi_pla(area, h_t)
	local ct_mrsm = cw_ls + (cw_ls/(ADMI_LD-ct_kaj))*ct_kaj
	local ab = admi_sup(v_tt+v_kt, manu)
	local totsup = ab + (ab/(ADMI_LD-ct_kaj))*ct_kaj
	return (1/6000) * (ct_mrsm + tpile + totsup + ce_pml + c_ttil) / area
end

-- vbar = 1000*vol/tntr
local function admi_t2(area, xdis, totvo, vbar, manu)
	local ttra = admi_travel(area, xdis)
	local ab = admi_sup(totvo, manu)
	local totsup = ab + (ab/(ADMI_LD-ttra))*ttra
	local tsca = totvo*0.9*exp(6.9 + 76.4/vbar - 0.161*log(totvo))
	local tcal = 500
	local trep = 500
	return (1/6000) * (tsca + totsup + tcal + trep) / area
end

local function admi_t34(area, xdis, totvo, vbar, manu, h_t, xnp)
	local ttra = admi_travel(area, xdis)
	local ab = admi_sup(totvo, manu)
	local totsup = ab + (ab/(ADMI_LD-ttra))*ttra
	local tsca = totvo*0.9*(295 - 5737/vbar + 24780/totvo)
	local tpla = admi_pla(area, h_t)
	local a1 = tpla/xnp + tsca
	local totpla = a1 + (a1/(ADMI_LD-ttra))*ttra*xnp
	local tcal = 1000
	local trep = 500
	return (1/6000) * (totpla + totsup + tcal + trep) / area
end

local function admi_t3(area, xdis, totvo, vbar, manu, h_t)
	return admi_t34(area, xdis, totvo, vbar, manu, h_t, 2)
end

local function admi_t4(area, xdis, totvo, vbar, manu, h_t)
	return admi_t34(area, xdis, totvo, vbar, manu, h_t, 1)
end

local function admi_t5(area, xdis, totvo, manu, h_t)
	local ttra = admi_travel(area, xdis)
	local ab = admi_sup(totvo, manu)
	local totsup = ab + (ab/(ADMI_LD-ttra))*ttra
	local tpla = 0.6 * admi_pla(area, h_t)
	local totpla = tpla + (tpla/(ADMI_LD-ttra))*ttra
	local b1 = (totvo*9000)/2000
	local tcont = 2 * (b1 + (b1/(ADMI_LD-ttra))*ttra)
	local tenco = 2500 + (2500/(ADMI_LD-ttra))*ttra
	local tacc = 1000
	return (1/6000) * (totpla + totsup + tcont + tenco + tacc) / area
end

local function admi_t6(area, xdis, totvo)
	local ttra = admi_travel(area, xdis)
	local tpre = 1500 + (1500/(ADMI_LD-ttra))*ttra
	local b2 = (totvo*9000)/3000
	local tcont = 2 * (b2 + (b2/(ADMI_LD-ttra))*ttra)
	local tenco = 1500 + (1500/(ADMI_LD-ttra))*ttra
	local trep = 1000
	return (1/6000) * (tpre + tcont + tenco + trep) / area
end

-- muihin metsänhoitotöihin liittyvä siirtymisaikakerroin
local function admi_ttra(area, xdis)
	local ttra = admi_travel(area, xdis)
	return ttra / (ADMI_LD - ttra)
end

---- Apufunktiot ---------------------------------------------------------------

-- puulaji- ja puutavaralajikohtaiset poistumat
-- s: puulajivektori
-- w: poistumavektori (1/ha)
-- vs: tukkitilavuusvektori (m^3/puu)
-- vp: kuitutilavuusvektori (m^3/puu)
-- *
-- v_mantytukki, v_kuusitukki, v_koivutukki, v_mantykuitu, v_kuusikuitu, v_koivukuitu (m^3/puu)
-- w_mantytukki, w_kuusitukki, w_koivutukki, w_mantykuitu, w_kuusikuitu, w_koivukuitu (1/ha)
local function itas(s, w, vs, vp)
	local pxx = {0, 0, 0}
	local pxy = {0, 0, 0}
	local xrl1 = {0, 0, 0}
	-- local xrl2 = {0, 0, 0}    -- ei tarvita
	for i=0, #s-1 do
		local s3 = spe3[s[i]]
		pxx[s3] = pxx[s3] + w[i]*vs[i]
		pxy[s3] = pxy[s3] + w[i]*vp[i]
		if vs[i] > 0 then xrl1[s3] = xrl1[s3] + w[i] end
		-- if vp[i] > 0 then xrl2[s3] = xrl2[s3] + w[i] end
	end
	return pxx[1], pxx[2], pxx[3], pxy[1], pxy[2], pxy[3],
		xrl1[1], xrl1[2], xrl1[3]
		-- , xrl2[1], xrl2[2], xrl2[3]
end

-- forhau-wrapperi
-- s, w, vs, vp kuten yllä
-- snow, xdis, tc, ht kuten forhau_*
-- haulm: "forwarder" | "farmtractor"
local function forhau(s, w, vs, vp, snow, xdis, tc, ht, haulm)
	if haulm == "farmtractor" then
		return forhau_farmtractor(snow, xdis, itas(s, w, vs, vp))
	else
		return forhau_forwarder(xdis, tc, ht, itas(s, w, vs, vp))
	end
end

-- s: puulajivektori
-- w: poistumavektori (1/ha)
-- vst: energiatilavuus runko+oksat+lehvästö (m^3)
-- ipu: energia(runko)puu-dummy
-- *
-- erl: poistuma 1: mänty/ 2: kuusi/ 3: koivu (1/ha)
-- pet: poistuma 1: mänty/ 2: kuusi/ 3: koivu (m^3)
local function esum(s, w, vst, ipu)
	local erl, pet = {0,0,0}, {0,0,0}
	for i=0, #s-1 do
		-- print(w[i], ipu[i], vst[i], w[i]*vst[i])
		local s3 = spe3[s[i]]
		if ipu[i] then
			erl[s3] = erl[s3] + w[i]
		end
		pet[s3] = pet[s3] + w[i]*vst[i]
	end
	return pet, erl
end

-- ew_tc123-wrapperi puutason tiedoilla
local function ew_tc123t(s, w, vt, ipu, xdis, osapuu, ecost1, ecost2, ecost3, ecost4,
		ecost12)
	local pet, erl = esum(s, w, vt, ipu)
	return ew_tc123(pet, erl, xdis, osapuu, ecost1, ecost2, ecost3, ecost4, ecost12)
end

--------------------------------------------------------------------------------

return {
	moto_z = moto_z,
	moto_zz = moto_zz,
	moto_ptime = moto_ptime,
	tmanu = tmanu,
	forhau_forwarder = forhau_forwarder,
	forhau_farmtractor = forhau_farmtractor,
	forhau = forhau,
	eker = eker,
	ew_t1 = ew_t1,
	ew_t2 = ew_t2,
	ew_t3 = ew_t3,
	ew_tc123 = ew_tc123,
	ew_tc123t = ew_tc123t,
	ew_t4 = ew_t4,
	ew_tc4 = ew_tc4,
	ht_t1 = ht_t1,
	ht_t2a = ht_t2a,
	ht_t2b = ht_t2b,
	ht_t3 = ht_t3,
	ht_tc123 = ht_tc123,
	stump_tmove = stump_tmove,
	stump_tlift = stump_tlift,
	stump_thaul = stump_thaul,
	itas = itas,
	admi_t1 = admi_t1,
	admi_t2 = admi_t2,
	admi_t3 = admi_t3,
	admi_t4 = admi_t4,
	admi_t5 = admi_t5,
	admi_t6 = admi_t6,
	admi_ttra = admi_ttra
}
