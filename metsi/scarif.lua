-- (Hämäläinen and Kaila 1985) Metsämaan äestyksen ja aurauksen työvaikeustekijät, ajankäytön
--   jakautuminen ja tuottavuus. Metsätehon raportti 393.
--   [https://www.metsateho.fi/wp-content/uploads/tiedotus-1985_393-compressed.pdf]

local COEF = {
	-- äestys
	{
		b1 = { 1.024, 1.142, 1.319 },
		b2 = -0.086,
		a1 = 1.333
	},
	-- auraus
	{
		b1 = { 1.104, 1.285, 1.548 },
		b2 = -0.115,
		a1 = 1.176
	}
}

local function scarif(area, alr, verlt, tc, mt)
	if alr > 1 or verlt == 2 then
		mt = 1
	elseif (not mt) or mt <= 0 then
		if verlt == 3 then
			mt = 2
		else
			mt = 1
		end
	end
	if (not tc) or tc <= 0 then
		if alr > 1 or verlt <= 2 then
			tc = 2
		else
			tc = 1
		end
	end
	local coef = COEF[mt]
	local a1, b1, b2 = coef.a1, coef.b1[tc], coef.b2
	local tc1 = area^b2
	return 3*1.2*a1*b1*tc1, tc1
end

return {
	scarif = scarif
}
