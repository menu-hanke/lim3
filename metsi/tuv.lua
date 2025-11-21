local exp, log, max, min, sqrt = math.exp, math.log, math.max, math.min, math.sqrt

-- ad-hoc viritys:
-- * pohj<6740, itä<150 --> ahvenanmaa
-- * pohj>7100          --> pohjois-suomi (kainuu, pohjois-pohjanmaa, lappi)
-- (oikeaoppisesti tässä kuuluisi katsoa metsäkeskus-id, mutta sitä ei ole smk-datassa)
local function ahv(X, Y) if X<150 and Y<6740 then return 1 else return 0 end end
local function pohj(Y) if Y>7100 then return 1 else return 0 end end

-- suo -> 1, kangas - >0
local function suo(alr)
	return min(alr-1, 1)
end

-- OMaT, OMT -> 1
local function reh(mty)
	return min(max(0, 3-mty), 1)
end

-- CT tai karumpi -> 1
local function kar(mty)
	return min(max(0, mty-4), 1)
end

-- istutettu -> 1, kylvetty tai luontaisesti syntynyt -> 0
local function ist(snt)
	if snt == 1 or snt == 3 then
		return 1
	else
		return 0
	end
end

local function sigm20(x)
	x = min(x, 20)
	return exp(x) / (1+exp(x))
end

-- etelä-suomi mänty metsämaa
local function tuv_esmame(X, Y, Z, mty, alr, a13, d)
	if d <= 0.1 or Y <= 6600 or a13 <= 0 then return 1 end
	return sigm20(
		0.0041763 * Y
		+ 0.28321 * suo(alr)
		+ 0.46073 * reh(mty)
		+ 0.63234 * kar(mty)
		+ 0.038147 * a13
		- 0.79743 * log(Y-6600)
		- 3.56806 * log(a13)
		+ 1.59042 * ahv(X, Y)
		+ 0.0030901 * d^2
		- 0.21835 * d
		- 0.45486 * log(Z+1)
		- 7.30094
	)
end

-- pohjois-suomi mänty metsämaa
local function tuv_psmame(X, Y, Z, mty, alr, dd, a13, d)
	if d <= 0.1 or dd <= 0 or a13 <= 0 then return 1 end
	return sigm20(
		0.54559 * suo(alr)
		+ 0.60294 * reh(mty)
		+ 0.1714 * d
		- 0.29093 * log(Z+1)
		+ 131.85364/d
		- 2.93903 * log(dd)
		+ 5.14414 * log(a13)
		- 0.00128026 * X
		+ 0.0205328 * max(0, 11.0/80.0*Y-741.25)
		+ 98.18684 / sqrt(a13)
		- 21.9458
	)
end

-- koko suomi mänty kitumaa
local function tuv_ksmaki(Y, Z, a13, d)
	if d <= 0.1 or a13 <= 0 then return 1 end
	return sigm20(
		2.22696 * log(a13)
		+ 206.52322 / a13
		- 0.00413268 * Z
		+ 0.0141555 * max(0, 11.0/80.0*Y-741.25)
		+ 0.073237 * d
		- 12.76967
	)
end

-- etelä-suomi kuusi metsämaa
local function tuv_eskume(X, Y, Z, mty, alr, dd, a13, d, snt)
	if d <= 0.1 then return 1 end
	return sigm20(
		0.28839 * ist(snt)
		+ 0.71816 * ahv(X, Y)
		+ 0.1893 * d
		- 8.18644 * log(d)
		+ 0.15384 * suo(alr)
		+ 3.63824 * reh(mty)
		+ 0.000055601 * a13^2
		+ 1.49262 * d/a13
		- 0.0048525 * a13
		- 0.0159994 * min(60, Z)
		- 0.00249276 * dd*reh(mty)
		- 0.00382568 * Z*reh(mty)
		+ 20.60669
	)
end

-- pohjois-suomi kuusi metsämaa
local function tuv_pskume(X, Z, alr, dd, a13, d)
	if d <= 0.1 or dd <= 0 or X <= 0 then return 1 end
	return sigm20(
		0.33608 * suo(alr)
		+ 298.08296 / d
		- 3406.89048 / X
		+ 8.78602 * log(d)
		+ 96.45143 / a13
		- 5.06578 * log(dd)
		+ 0.0122883 * a13
		- 0.00568413 * Z
		+ 0.0162943 * max(0, 11.0/80.0*Y-741.25)
		- 0.01601867 * X
		+ 6.8407
	)
end

-- etelä-suomi kuusi kitumaa
local function tuv_eskuki()
	return 0.422378715
end

-- pohjois-suomi kuusi kitumaa
local function tuv_pskuki(a13, d)
	if d <= 0.1 or a13 <= 0 then return 1 end
	return sigm20(
		0.8221 * d
		- 25.11294 * log(d)
		+ 2.66821 * log(a13)
		+ 47.7563
	)
end

-- koko suomi rauduskoivu metsämaa
local function tuv_ksrame(X, Y, Z, mty, a13, d)
	if d <= 0.1 then return 1 end
	return sigm20(
		0.00116735 * Y
		+ 0.00686174 * Z
		+ 0.1046089 * d
		- 0.0221518 * a13
		- 0.0109198 * min(120, Z)
		+ 0.000172745 * a13^2
		+ 2.23907 * kar(mty)
		+ 73.48598 / d
		+ 1.40092 * ahv(X, Y)
		+ 0.61297 * pohj(Y)
		- 13.206
	)
end

-- koko suomi hieskoivu metsämaa
local function tuv_kshime(X, Y, a13, d)
	if d <= 0.1 or a13 <= 0 or Y <= 6600 then return 1 end
	return sigm20(
		0.14601 * d
		+ 81.25127 / d
		- 3.67475 * log(a13)
		+ 1.87078 * ahv(X, Y)
		- 1.10609 * log(Y-6600)
		+ 0.00661047 * Y
		+ 0.0532015 * a13
		- 34.42423
	)
end

-- koko suomi haapa metsämaa
local function tuv_kshame(X, Y, Z, alr, a13, d)
	if d <= 0.1 or X <= 0 or Y <= 6600 then return 1 end
	return sigm20(
		0.71908 * log(Y-6600)
		+ 0.7884 * log(X)
		- 1.18635 * log(Z+1)
		- 0.78538 * suo(alr)
		+ 0.51573 * pohj(Y)
		+ 0.01686212 * Z
		+ 0.023935 * d
		+ 0.0113667 * a13
		- 6.20556
	)
end

local function tuv(X, Y, Z, mty, mal, alr, dd, s, a13, d, snt)
	if s == 1 or s == 8 then
		if mal == 1 then
			if pohj(Y) == 0 then
				return tuv_esmame(X, Y, Z, mty, alr, a13, d)
			else
				return tuv_psmame(X, Y, Z, mty, alr, dd, a13, d)
			end
		else
			return tuv_ksmaki(Y, Z, a13, d)
		end
	elseif s == 2 then
		if mal == 1 then
			if pohj(Y) == 0 then
				return tuv_eskume(X, Y, Z, mty, alr, dd, a13, d, snt)
			else
				return tuv_pskume(X, Z, alr, dd, a13, d)
			end
		else
			if pohj(Y) == 0 then
				return tuv_eskuki()
			else
				return tuv_pskuki(a13, d)
			end
		end
	elseif s == 3 then
		if mal == 1 then
			return tuv_ksrame(X, Y, Z, mty, a13, d)
		end
	elseif s == 5 then
		if mal == 1 then
			return tuv_kshame(X, Y, Z, alr, a13, d)
		end
	else
		if mal == 1 then
			return tuv_kshime(X, Y, a13, d)
		end
	end
	return 1.0
end

return {
	tuv_esmame = tuv_esmame,
	tuv_psmame = tuv_psmame,
	tuv_ksmaki = tuv_ksmaki,
	tuv_eskume = tuv_eskume,
	tuv_pskume = tuv_pskume,
	tuv_eskuki = tuv_eskuki,
	tuv_pskuki = tuv_pskuki,
	tuv_ksrame = tuv_ksrame,
	tuv_kshime = tuv_kshime,
	tuv_kshame = tuv_kshame,
	tuv        = tuv
}
