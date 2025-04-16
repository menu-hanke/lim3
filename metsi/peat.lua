local log, min = math.log, math.min
local coding = require "metsi.coding"
local forest, scrub, waste = coding.mal.forest, coding.mal.scrub, coding.mal.waste
local rhtkg2, mtkg2 = coding.tkg.RHTKG2, coding.tkg.MTKG2
local peat_unditched = coding.oji.peat_unditched

-- peats/Ojittamaton.F90    real function ojittamattomuus
local function ojittamattomuus(G, dd, tkg)
	local c = 0.77
	if tkg then
		if tkg <= rhtkg2 then
			c = c + 0.15
		elseif tkg <= mtkg2 then
			c = c + 0.1
		end
	end
	local Glim
	if dd > 400 then
		Glim = 2*log(min(dd, 1000))
	else
		Glim = 15
	end
	if G >= Glim then
		c = c * 1.02
	end
	return c
end

-- peats/suoID5+suoIH5    ojittamattoman_kalibrointikerroin
local function ojic(G, dd, mal, oji, tkg)
	if oji == peat_unditched then
		if mal == forest then
			return ojittamattomuus(G, dd, tkg)
		else
			return 0.77
		end
	else
		return 1
	end
end

-- peats/Ojittamaton.F90     Kitumaankerroin * JoutomaanKerroin
local function peatc(mal, dd)
	local c = 1
	if mal >= scrub then c = c * 400/dd end
	if mal == waste then c = c * 100/dd end
	return c
end

--------------------------------------------------------------------------------

return {
	ojic  = ojic,
	peatc = peatc
}
