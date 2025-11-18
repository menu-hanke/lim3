local floor, min = math.floor, math.min

-- [soil][scarif][plant type]
local TCD = {
	.642, .684, .745,  .674, .752, .857,
	.698, .752, .801,  .733, .827, .921,
	.745, .839, .946,  .782, .923,1.088,
	.885, .982,1.143,  .930,1.080,1.315,
	1.054,1.115,1.181, 1.107,1.227,1.358,
	1.157,1.246,1.349, 1.215,1.371,1.552,
	1.251,1.387,1.509, 1.313,1.525,1.735,
	1.424,1.581,1.780, 1.496,1.739,2.047,
	1.251,1.387,1.509, 1.313,1.525,1.735,
	1.424,1.581,1.780, 1.496,1.739,2.047,
	1.588,1.808,2.005, 1.668,1.989,2.306,
	1.780,2.036,2.296, 1.869,2.239,2.640
}

local function tcd(soil, scarif, ptype)
	return TCD[6*(ptype-1)+3*(scarif-1)+soil]
end

local FETCHING = {
	.037, .126, .262,
	.028, .089, .178,
	.019, .066, .117,
	.108, .178, .281,
	.080, .117, .187,
	.056, .089, .169
}

local function fetching(d, n, p)
	return FETCHING[(p-1)*9+(n-1)*3+d]
end

local SPOT = {0.0,0.094,0.178,0.801}

-- ajanmenekki h/puu
local function plting(sp, mty, verlt, itype, zdis)
	local ispot = 1
	local isoil
	if verlt > 0 then
		isoil = 3
	elseif mty == 5 or mty == 6 then
		isoil = 1
	else
		isoil = 2
	end
	local ipt
	if itype == 1 then
		ipt = 1
	elseif itype == 3 then
		ispot = 4
		if sp == 1 then
			ipt = 8
		else
			ipt = 14
		end
	elseif sp == 1 then
		if mty <= 3 then
			ipt = 4
		elseif isoil == 1 then
			ipt = 1
		else
			ipt = 2
		end
	else
		if mty < 3 then
			ipt = 10
		else
			ipt = 4
		end
	end
	local tc = tcd(isoil, 1, ipt) + 0.098 + SPOT[ispot]
	if itype > 1 then
		local nr, iipt
		if ipt <= 4 then
			nr = 3
			iipt = 1
		elseif ipt > 4 and ipt <= 8 then
			nr = 2
			iipt = 2
		else
			nr = 1
			iipt = 2
		end
		tc = tc + fetching(min(floor(zdis*0.01)+1, 3), nr, iipt)
	end
	-- days/1000 plants --> hours/plant
	return 7*0.001*tc
end

return {
	plting = plting
}
