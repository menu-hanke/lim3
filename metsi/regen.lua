local mm = require "metsi.math"
local choose, clamp = mm.choose, mm.clamp
local exp, log, max, min, sqrt = math.exp, math.log, math.max, math.min, math.sqrt
local coding = require "metsi.coding"
local pine, spruce, silver_birch, downy_birch, gray_alder, xconiferous
	= coding.spe.pine, coding.spe.spruce, coding.spe.silver_birch, coding.spe.downy_birch, coding.spe.gray_alder, coding.spe.xconiferous
local OMT, MT, VT, CT, ClT, ROCK, MTN
	= coding.mty.OMT, coding.mty.MT, coding.mty.VT, coding.mty.CT, coding.mty.ClT, coding.mty.ROCK, coding.mty.MTN
local peat_spruce, peat_pine = coding.alr.peat_spruce, coding.alr.peat_pine
local soilprep_none = coding.soilprep.none
local natural, seeded = coding.snt.natural, coding.snt.seeded
local wet, stony, moss = coding.verlt.wet, coding.verlt.stony, coding.verlt.moss
local natural, infeasible = coding.feas.natural, coding.feas.infeasible
local ffi = require "ffi"
local tnew = require "table.new"

local NPL = 9

local function hvalta_manty(age, mty, snt, dd, verlt)
	local plnhd = -3.54554
		- 8.33716  * age^-0.5
		+ 1.039037 * log(dd)
		+ 0.428068 * choose(snt == planted, 1/sqrt(age))
		+ 0.300919 * choose(snt == seeded, 1/sqrt(age))
		+ 0.242263 * choose(mty <= OMT)
		+ 0.112042 * choose(mty == MT)
		- 0.15247  * choose(mty == CT)
		- 0.26735  * choose(mty >= ClT)
		- 0.04337  * choose(verlt == wet)
		- 0.17154  * choose(verlt == stony or verlt == moss)
		- 0.1      * choose(mty >= ROCK)
		- 0.1      * choose(mty >= MTN)
    return exp(plnhd+.03810/2)
end

local function hvalta_kuusi(age, mty, snt, dd, verlt)
	local plnhd = -1.84155
		- 0.54546 * log(age)
		- 91.1669 * 1/(age+10)
		+ 1.1676  * log(dd)
		+ 0.160   * choose(mty <= OMT)
		- 0.272   * choose(mty >= VT)
		- 0.075   * choose(verlt == wet)
		- 0.10    * choose(verlt == stony or verlt == moss)
		+ 0.047   * choose(snt == planted)
		- 0.2     * choose(mty >= CT)
		- 0.1     * choose(mty >= ClT)
		- 0.1     * choose(mty >= ROCK)
		- 0.1     * choose(mty >= MTN)
    return exp(plnhd+.031977/2)
end

local function hvalta_lehti(spe, age, mty, snt, dd, verlt)
	local plnhd = -4.02488
		- 7.58258  * 1/sqrt(age)
		+ 1.137578 * log(dd)
		- 0.16127  * choose(spe == downy_birch or spe >= gray_alder)
		+ 0.077555 * choose(mty <= OMT)
		- 0.25924  * choose(mty >= VT)
		- 0.1      * choose(verlt == wet)
		- 0.05     * choose(verlt == stony or verlt == moss)
		- 0.1      * choose(mty >= CT)
		- 0.1      * choose(mty >= ClT)
		- 0.1      * choose(mty >= ROCK)
		- 0.1      * choose(mty >= MTN)
		+ 0.4      * choose(snt >= seeded) * 1/sqrt(age)
    return math.exp(plnhd+.022461/2)
end

local function hvalta(spe, age, mty, snt, dd, verlt)
	if spe == pine or spe == xconiferous then
		return hvalta_manty(age, mty, snt, dd, verlt)
	elseif spe == spruce then
		return hvalta_kuusi(age, mty, snt, dd, verlt)
	else
		return hvalta_lehti(spe, age, mty, snt, dd, verlt)
	end
end

local function agekri(spe, mty, snt, dd, verlt, a, hlim, alim)
	if not alim then alim = 50 end
	if not hlim then hlim = 8 end
	if not a then a = 2 end
	while a < alim and hvalta(spe, a+1, mty, snt, dd, verlt) < hlim do
		a = a + 1
	end
	return a
end

local MTAPAP = {25.,30.,25.,25.,15.,25.}
local SLOPMT = {5.0,5.0,10.0,15.0,25.0,25.0,25.0,25.0}
local CERMT = {
    {0.4, 0.4, 0.5, 0.6, 0.8, 0.9, 1.0, 1.0},
    {0.6, 0.6, 0.6, 0.6, 0.8, 0.9, 1.0, 1.0},
    {0.6, 0.6, 0.6, 0.6, 0.8, 0.9, 1.0, 1.0}
}

local function mpkmmannut(mty, alr, dd, muok, t_muok)
	local t = clamp(0, t_muok, 10)
	local xos = -t^2
	local xnim = SLOPMT[mty] * (1400.0/dd)^1.25
	local tu = CERMT[min(alr,1)][mty]
	if (not muok) or muok == soilprep_none then
		return tu * (tu + (1-tu)*exp(xos/xnim))
	else
		return (tu + (1-tu)*exp(xos/xnim)) * 299*MTAPAP[muok]/5415
	end
end

local function casc(ftot, snt, G_seed, f_vilj, violet)
	if ftot == 0 then return 0 end
	local casu = 1 - exp((
		-2181.0936
		- 26.9142  * choose(snt == natural)
		- 200.9218 * choose(snt >= seeded)
	) / ftot)
	if snt >= seeded and f_vilj > 0 then
		casu = casu ^ exp(-(f_vilj-violet)/(ftot^0.95))
	end
	if G_seed > 15 then
		casu = casu * 0.75
	end
	return ftot * casu
end

local PLRIV_KANGAS = {
	{1,2,3,4,6,6,6,1,6},
	{1,2,3,4,6,6,6,1,6},
	{1,7,3,4,6,6,6,1,6},
	{9,9,11,11,6,6,6,9,6},
	{12,12,12,12,12,12,12,12,12},
	{12,12,12,12,12,12,12,12,12},
	{14,14,14,14,14,14,14,14,14},
	{14,14,14,14,14,14,14,14,14},
}

local PLRIV_SUO = {
	{1,2,3,5,6,6,6,1,6},
	{1,2,3,5,6,6,6,1,6},
	{1,8,3,5,6,6,6,1,6},
	{10,10,11,11,6,6,6,10,6},
	{13,13,13,13,13,13,13,13,13},
	{13,13,13,13,13,13,13,13,13},
	{14,14,14,14,14,14,14,14,14},
	{14,14,14,14,14,14,14,14,14},
}

local function plriv(spe, mty, alr)
	if alr == mineral then
		return PLRIV_KANGAS[mty][spe]
	else
		return PLRIV_SUO[mty][spe]
	end
end

local IPOLE = {
	{4,4,4,1,1,1,1,1},
	{4,4,4,1,1,1,1,1},
	{4,4,4,1,1,1,1,1}
}

local function tapula_luont(alr, mty, dd, G_seed, retaos, kpl, ypl)
	local tpl = IPOLE[alr][mty]
	if tpl == silver_birch and dd <= 1000 then
		tpl = Species.DOWNY_BIRCH
	end
	ypl = ypl or tpl
	local yer, plerc = 0/0, 0/0
	if G_seed <= 0.01 and not kpl and (mty == VT or (mty == MT and alr == peat_pine)) then
		yer, plerc = 0.2, 0.5
	end
	if G_seed > 0.01 then
		plerc = 1.0
		if mty <= MT and (
				(ypl >= silver_birch and G_seed >= 15.0)
				or (ypl == pine and G_seed >= 25.0)) then
			tpl = spruce
		elseif mty >= CT then
			tpl = pine
		else
			tpl = ypl
		end
	end
	if kpl and kpl ~= tpl then
		if G_seed > 0 then
			yer, plerc = 0.5, 0.4
			tpl = kpl
		elseif kpl == pine then
			yer, plerc = 0.2, 0.5
		elseif kpl == spruce then
			yer, plerc = 0.1, 0.4
		end
		if kpl ~= ypl then
			if kpl == pine then
				if G_seed >= 15 and mty <= MT then
					yer, plerc = 0.15, 0.2
				else
					yer, plerc = 0.2, 0.3
				end
			elseif kpl == spruce then
				if mty >= VT then
					yer, plerc = 0.1, 0.2
				end
				if alr == peat_spruce then
					yer = yer + 0.2
					plerc = plerc + 0.2
				end
			else
				if mty == VT then
					yer, plerc = 0.3, 0.5
				elseif mty >= CT then
					yer, plerc = 0.2, 0.3
				end
			end
		end
	end
	if G_seed <= 0.1 and kpl then
		local retak, retae
		if kpl == pine then
			retak, retae = 0.7, 0.2
		elseif kpl == spruce then
			retak, retae = 0.6, 0.1
		else
			retak, retae = 0.8, 0.3
		end
		if retaos > 0 then
			local reu
			if tpl > spruce then
				reu = 100
			else
				reu = 50
			end
			retaos = min(max(100 * (retaos-(reu/100)^2)/retaos, 0), 1)
		end
		yer = (retaos/100)*retak + (1-(retaos/100))*retae
		tpl = kpl
	end
	return tpl, clamp(0, yer, 1), clamp(0, plerc, 1)
end

local PLSKAS_LUONT = {
    {0.7930,0.1240,0.0320,0.0510,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.0130,0.8552,0.0348,0.0922,0.0013,0.0030,0.0004,0.0000,0.0000},
    {0.0744,0.1110,0.7142,0.0924,0.0031,0.0025,0.0000,0.0000,0.0025},
    {0.0340,0.1021,0.0563,0.7691,0.0252,0.0118,0.0000,0.0000,0.0015},
    {0.0620,0.0965,0.0120,0.8222,0.0000,0.0021,0.0042,0.0000,0.0010},
    {0.0133,0.0307,0.0467,0.0707,0.2653,0.4240,0.0107,0.0000,0.1387},
    {0.0774,0.8236,0.0396,0.0561,0.0015,0.0015,0.0002,0.0000,0.0000},
    {0.0342,0.8449,0.0037,0.1171,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.9128,0.0519,0.0142,0.0210,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.8913,0.0495,0.0012,0.0579,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.2018,0.0371,0.0564,0.7047,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.9754,0.0040,0.0064,0.0141,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.9777,0.0012,0.0002,0.0209,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.9144,0.0367,0.0272,0.0122,0.0095,0.0000,0.0000,0.0000,0.0000}
}

local PLSKAS_VILJ = {
    {0.8252,0.0704,0.0494,0.0419,0.0000,0.0000,0.0000,0.0132,0.0000},
    {0.0162,0.8880,0.0552,0.0391,0.0007,0.0009,0.0000,0.0000,0.0000},
    {0.0338,0.0375,0.8889,0.0348,0.0043,0.0003,0.0000,0.0000,0.0005},
    {0.0000,0.0000,0.1029,0.8971,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.0000,0.0000,0.0000,0.0000,1.0000,0.0000,0.0000,0.0000,0.0000},
    {0.0000,0.0420,0.0000,0.0000,0.3631,0.5803,0.0146,0.0000,0.0000},
    {0.0631,0.8474,0.0592,0.0286,0.0000,0.0017,0.0000,0.0000,0.0000},
    {0.0400,0.8629,0.0114,0.0857,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.9295,0.0273,0.0246,0.0184,0.0001,0.0000,0.0000,0.0000,0.0000},
    {0.8773,0.0307,0.0000,0.0920,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.2308,0.0000,0.0000,0.7692,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.9982,0.0000,0.0018,0.0000,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.9696,0.0000,0.0000,0.0304,0.0000,0.0000,0.0000,0.0000,0.0000},
    {0.8929,0.0536,0.0536,0.0000,0.0000,0.0000,0.0000,0.0000,0.0000}
}

local function ykask(tspe, mty, alr, snt)
	return (snt == natural and PLSKAS_LUONT or PLSKAS_VILJ)[plriv(tspe, mty, alr)]
end

local function ysync(tspe, ftot, y, fkas, ykas)
    if y[tspe] < 0.3 then
        local yc = 0.7 / (1-y[tspe])
		for i=1, NPL do
			y[i] = y[i] * (i == tspe and 0.3 or yc)
		end
	end
    if ykas[tspe] < 0.5 then
        local ykc = 0.5 / (1-ykas[tspe])
		for i=1, NPL do
			ykas[i] = ykas[i] * (i == tspe and 0.5 or ykc)
		end
	end
    local ctpaa = ftot * y[tspe]
    local ckaspaa = fkas * ykas[tspe]
    if ckaspaa > ctpaa then
        local yc = (1-(ckaspaa/ftot))/(1-y[tspe])
		for i=1, NPL do
			y[i] = i == tspe and (ckaspaa/ftot) or (y[i]*yc)
		end
	end
	local tn, tk = tnew(NPL, 0), tnew(NPL, 0)
	for i=1, NPL do
		tn[i] = y[i]*ftot
		tk[i] = ykas[i]*fkas
	end
	for i=1, NPL do
		if tk[i] > tn[i] then
			ftot = ftot + tk[i] - tn[i]
			tn[i] = tk[i]
		end
	end
	if ftot > 0 then
		for i=1, NPL do y[i] = tn[i]/ftot end
	else
		for i=1, NPL do y[i] = 0 end
	end
	return ftot
end

local NLUONT = {
	{
		{7332,5992,11435,11635,16156,15994,8955,5064,7504},
		{8022,9057,16478,12592,16681,16456,14765,6634,13989},
		{7250,8175,11570,7332,16991,9713,6634,5710,8022},
		{6076,4494,5875,5903,9647,5167,5167,4817,6374},
		{4625,3569,4447,3076,6974,4230,4230,3752,5271},
		{4477,2981,3641,2441,5486,3498,3498,3498,4188},
		{4098,2515,2807,2208,3984,2779,2779,3262,3134},
		{1998,1998,1998,1998,1998,1998,1998,1604,1998}
	},
	{
		{7864,9344,9997,9164,7332,7332,7332,6248,7332},
		{10183,10549,27846,12877,10199,10199,10199,7631,11968},
		{10984,10451,23587,17678,13095,13095,13095,8955,13095},
		{15560,9624,18215,11902,5710,5710,5710,11384,5710},
		{11499,7480,13905,8866,4447,4447,4447,9228,4447},
		{8250,5636,10000,6500,3250,3250,3250,6600,3250},
		{5000,3682,6000,4286,2143,2143,2143,4000,2143},
		{2000,2000,2000,2000,1000,1000,1000,1600,1000}
	},
	{
		{3000,3000,4800,6000,4800,4800,4800,2400,4800},
		{4428,5000,5886,7412,5886,5886,5886,3437,5886},
		{7245,7394,9600,12104,9600,9600,9600,5972,9600},
		{5498,12708,11355,14204,7097,7097,7097,4542,7097},
		{4447,10471,9350,11731,5844,5844,5844,3530,5844},
		{4017,7765,7850,8323,4162,4162,4162,3072,4162},
		{2900,4824,4700,5226,2613,2613,2613,2320,2613},
		{2000,2000,2000,2000,1000,1000,1000,1600,1000}
	}
}

local NVILJ = {
	{
		{5772,8021,3124,4722,3200,3200,3200,3197,3200},
		{8891,8444,7341,8267,6600,6600,6600,8778,6600},
		{7795,9038,8320,10991,8266,8266,8266,7611,8266},
		{6490,7000,7083,8900,4450,4450,4450,6503,4450},
		{4519,5591,5917,7200,3600,3600,3600,5208,3600},
		{3545,4409,4625,5400,2700,2700,2700,4000,2700},
		{2976,3128,3292,3650,1825,1825,1825,2708,1825},
		{2000,2000,2000,2000,1000,1000,1000,1500,1000},
	},
	{
		{8604,2926,1588,1806,1334,1334,1334,3000,1334},
		{12232,8611,7452,9701,10400,10400,10400,12967,10400},
		{14132,9438,6664,8667,6934,6934,6934,9400,6934},
		{15233,8000,5645,7063,3532,3532,3532,8300,3532},
		{11461,6500,4774,5750,2875,2875,2875,7000,2875},
		{8308,5000,3806,4500,2250,2250,2250,5600,2250},
		{5154,3500,2903,3250,1625,1625,2625,4250,1625},
		{2000,2000,2000,2000,1000,1000,1000,3000,1000},
	},
	{
		{3000,3000,1600,1667,1334,1334,1334,3000,1334},
		{8188,8224,6333,13000,10400,10400,10400,10000,10400},
		{13233,7333,6500,8667,6934,6934,6934,9400,6934},
		{10444,6417,5645,7063,3532,3532,3532,8300,3532},
		{6000,5292,4774,5750,2875,2875,2875,7000,2875},
		{4438,4167,3839,4500,2250,2250,2250,5600,2250},
		{3250,3042,2903,3250,1625,1625,1625,4250,1625},
		{2000,2000,2000,2000,1000,1000,1000,3000,1000}
	}
}

local PLSTOT_LUONT = {
    {0.3423,0.0828,0.0353,0.4633,0.0078+0.0297,0,0.0297,0.0000,0.0092},
    {0.0064,0.3582,0.0208,0.3075,0.0339+0.0687,0,0.0687,0.0000,0.1359},
    {0.0138,0.0211,0.7204,0.1808,0.0355+0.0117,0,0.0117,0.0000,0.0050},
    {0.0293,0.0557,0.0041,0.7587,0.0750+0.0147,0,0.0147,0.0000,0.0478},
    {0.0217,0.0466,0.0027,0.8869,0.0081+0.0128,0,0.0128,0.0000,0.0085},
    {0.0047,0.0075,0.0487,0.0648,0.1925+0.4891,0,0.0500,0.0003,0.1424},
    {0.0181,0.4796,0.0556,0.2626,0.1051+0.0161,0,0.0161,0.0000,0.0468},
    {0.0845,0.3775,0.0315,0.4717,0.0026+0.0114,0,0.0114,0.0005,0.0090},
    {0.5581,0.1041,0.0573,0.1982,0.0305+0.0080,0,0.0080,0.0007,0.0351},
    {0.4823,0.0576,0.0225,0.4316,0.0019+0.0018,0,0.0018,0.0005,0.0000},
    {0.0411,0.0288,0.0026,0.9018,0.0052+0.0020,0,0.0020,0.0000,0.0165},
    {0.9148,0.0347,0.0045,0.0395,0.0000+0.0033,0,0.0033,0.0000,0.0000},
    {0.7273,0.0061,0.0050,0.2615,0.0000+0.0001,0,0.0001,0.0000,0.0000},
    {0.4900,0.1507,0.0969,0.0854,0.1056+0.0000,0,0.0000,0.0078,0.0636},
}

local PLSTOT_VILJ = {
    {0.3957,0.0643,0.1010,0.3232,0.0347+0.0188,0,0.0188,0.0112,0.0323},
    {0.0164,0.2135,0.0192,0.1525,0.0601+0.1877,0,0.1877,0.0069,0.1560},
    {0.0032,0.0286,0.6608,0.0997,0.1521+0.0081,0,0.0081,0.0000,0.0395},
    {0.0000,0.0000,0.0108,0.7715,0.2177+0.0000,0,0.0000,0.0000,0.0000},
    {0.0000,0.0000,0.0000,0.9032,0.0000+0.0484,0,0.0484,0.0000,0.0000},
    {0.0000,0.0115,0.0000,0.0000,0.6763+0.2622,0,0.0500,0.0000,0.0000},
    {0.0268,0.3998,0.0147,0.1753,0.0160+0.0576,0,0.0576,0.0000,0.2522},
    {0.1117,0.1140,0.0037,0.7551,0.0000+0.0077,0,0.0077,0.0000,0.0000},
    {0.6104,0.0518,0.0549,0.2006,0.0398+0.0124,0,0.0124,0.0001,0.0177},
    {0.4300,0.0153,0.0000,0.5547,0.0000+0.0000,0,0.0000,0.0000,0.0000},
    {0.2542,0.0000,0.0000,0.4916,0.2542+0.0000,0,0.0000,0.0000,0.0000},
    {0.9948,0.0000,0.0052,0.0000,0.0000+0.0000,0,0.0000,0.0000,0.0000},
    {0.4378,0.0000,0.0000,0.5622,0.0000+0.0000,0,0.0000,0.0000,0.0000},
    {0.3003,0.1095,0.0975,0.0000,0.0000+0.0000,0,0.0000,0.0000,0.4927}
}

local function plsx_y(tspe, mty, alr, snt)
	return (snt == natural and PLSTOT_LUONT or PLSTOT_VILJ)[plriv(tspe, mty, alr)]
end

local function plsx_rt(alr, mty, snt, tspe, dd, mood)
	local ntot
	if (snt == natural) or mood then
		ntot = NLUONT[min(alr,1)][mty][tspe]
	else
		ntot = NVILJ[min(alr,1)][mty][tspe]
	end
	local ddyc = -13.5476 + 2.3809*log(dd-400) - 0.0028*(dd-400)
	return exp(log(ntot) + ddyc)
end

local function copytab(t,n)
	if not n then n = #t end
	local r = tnew(n, 0)
	for i=1, n do r[i] = t[i] end
	return r
end

local function synt0(ykt, yrt)
	for i=0, NPL-1 do
		ykt[i] = 0
		yrt[i] = 0
	end
end

local function synt(
	mty, alr, snt, dd, F, G_seed, t_muok, muok, tspe, yer, plerc, f_vilj, surv, mood, -- inputs
	ykt_out, yrt_out -- output
)
	local rst = plsx_rt(alr, mty, snt, tspe, dd, mood) * yer
	if 0.2 <= G_seed and G_seed < 8.0 then
		rst = rst - 0.5*F
	elseif G_seed >= 8.0 then
		rst = (1.471-0.05882*G_seed) * (rst-0.5*F)
	end
	if rst < 0 then
		return synt0(ykt_out, yrt_out)
	else
		local y = copytab(plsx_y(tspe, mty, alr, snt), NPL)
		local ycd = (1 - plerc*y[tspe]) / (1 - y[tspe])
		y[tspe] = y[tspe] * plerc
		for i=1, #y do
			if i ~= tspe then
				y[i] = y[i] * ycd
			end
		end
		local rt = rst * mpkmmannut(mty, alr, dd, muok, t_muok)
		if rt <= 200 then
			return synt0(ykt_out, yrt_out)
		end
		local rk = casc(rt, snt, G_seed, f_vilj, surv)
		local ykas = copytab(ykask(tspe, mty, alr, snt), NPL)
		local rt = ysync(tspe, rt, y, rk, ykas)
		for i=1, NPL do
			local yrt = rt*y[i]
			local ykt = rk*ykas[i]
			if yrt < 5 then yrt = 0 end
			if ykt < 5 then ykt = 0 end
			yrt_out[i-1] = yrt
			ykt_out[i-1] = ykt
		end
	end
end

local function ysynf(
	yrt, ykt, sspe, sf, sfeas, viti, vspe, -- in
	fkp, fkl -- out
)
	local fkpsu = tnew(NPL, 0)
	local fklsu = tnew(NPL, 0)
	for i=1, NPL do
		fkpsu[i] = 0
		fklsu[i] = 0
	end
	for i=1, #sspe do
		if sfeas[i-1] == infeasible then
			fklsu[i] = fklsu[i] + sf[i-1]
		else
			fkpsu[i] = fkpsu[i] + sf[i-1]
		end
	end
	for i=1, NPL do
		local fkpi = ykt[i-1]
		if viti > 0 then
			fkpi = fkpi - fkpsu[i-1]
		end
		if i == vspe then
			fkpi = fkpi - viti
		end
		fkp[i-1] = max(fkpi, 0)
	end
	for i=1, NPL do
		fkl[i-1] = max(yrt[i-1] - ykt[i-1] - fklsu[i])
	end
end

local ytmp_ct = ffi.typeof("double[$]", NPL)

local function syntyf(
	snt, viti, vspe, tspe, yer, plerc, surv, mood, -- in (parameters)
	mty, alr, dd, F, G_seed, t_muok, muok, -- in (site level)
	sspe, sf, sfeas, -- in (stratum level)
	fkp, fkl -- out (site level)
)
	local yrt, ykt = ytmp_ct(), ytmp_ct()
	synt(mty, alr, snt, dd, F, G_seed, t_muok, muok, tspe, yer, plerc, viti, surv, mood, ykt, yrt)
	ysynf(yrt, ykt, sspe, sf, sfeas, viti, vspe, fkp, fkl)
end

local function nposeps(x, n, eps)
	local nnz = 0
	for i=0, n-1 do
		if x[i] > eps then
			nnz = nnz+1
		end
	end
	return nnz
end

local EPS = 1

-- TODO istutus
local function nregen(fkp, fkl)
	return nposeps(fkp, NPL, EPS) + nposeps(fkl, NPL, EPS)
end

-- TODO istutus
local function regenerate(
	fkp, fkl, -- in
	f, spe, type -- out
)
	local j = 0
	for i=1, NPL do
		if fkp[i-1] > EPS then
			f[j] = fkp[i-1]
			spe[j] = i
			type[j] = natural
			j = j+1
		end
		if fkl[i-1] > EPS then
			f[j] = fkl[i-1]
			spe[j] = i
			type[j] = infeasible
			j = j+1
		end
	end
	--print("renegerated ", j, "wanted", #f)
end

--------------------------------------------------------------------------------

return {
	hvalta       = hvalta,
	agekri       = agekri,
	tapula_luont = tapula_luont,
	syntyf       = syntyf,
	nregen       = nregen,
	regenerate   = regenerate
}
