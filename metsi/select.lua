-- ported from metsi:
-- https://github.com/lukefi/Mela2.0/blob/main/lukefi/metsi/data/util/select_units.py
-- unoptimized scalar implementation

local abs, floor, max, min = math.abs, math.floor, math.max, math.min

local EPSILON = 0.001

local function odds(p)
	return p/(1-p)
end

-- if
--   ∑ { z_i : i=0..N-1, p_i>0 }  <  Z
-- then adjust
--   p'_i = EPSILON where p'_i=0
-- otherwise
--   p' = p
-- output
--   p' (in p)
--   min { p'_i : i=0..N-1, p'_i > 0 }
--   max { p'_i : i=0..N-1 }
--   ∑ { z_i : i=0..N-1, p'_i > 0 }
local function adjustprofile(p, z, N, ZZ)
	local l, u, ZZp = 1, 0, 0
	for i=0, N-1 do
		if p[i] > 0 then
			ZZp = ZZp + z[i]
			l = min(l, p[i])
		end
		u = max(u, p[i])
	end
	if ZZp < ZZ then
		for i=0, N-1 do
			p[i] = max(p[i], EPSILON)
		end
		l = EPSILON
		ZZp = ZZ
	end
	return l, u, ZZp
end

-- solve
--    N-1
--     ∑ w(p_i)z_i  =  Z
--    i=0
-- where
--   w(p) = min(max(0, p+c), 1)
--   c ∈ [-max(p), min(p)+1]
-- output
--   w
local function select_level(w, p, z, N, Z, ZZ)
	-- if relative secant step is smaller than this, fall back to bisection.
	-- found with a parameter search over a 1k sample of North Karelia stands.
	local LEVEL_BISECT_MIN_FALLBACK = 0.175
	local zl, zu = 0, ZZ
	local pm, pM = 1/0, -1/0
	for i=0, N-1 do
		pm = min(pm, p[i])
		pM = max(pM, p[i])
	end
	local l, u = -pM, pm+1
	local bisect = false
	local ztot
	repeat
		if bisect then
			c = 0.5*(u+l)
		else
			c = l + (u-l)*(Z-zl)/(zu-zl)
		end
		ztot = 0
		for i=0, N-1 do
			local wi = min(max(0, p[i] + c), 1)
			w[i] = wi
			ztot = ztot + wi*z[i]
		end
		-- print(string.format("z=%g [%g, %g] Z=%g c=%g [%g, %g]", ztot, zl, zu, Z, c, l, u))
		local s = u-l
		local sz
		if ztot > Z then
			u, zu, sz = c, ztot, u-c
		else
			l, zl, sz = c, ztot, c-l
		end
		-- if secant step was too small, take a bisection step.
		bisect = (not bisect) and sz <= LEVEL_BISECT_MIN_FALLBACK*s
		--print("ztot", ztot, "ZZ", ZZ, "Z", Z)
	until abs(ztot-Z) <= EPSILON*Z
end

-- solve
--    N-1
--     ∑ w(p_i)z_i  =  Z
--    i=0
-- where
--   w(p) = min(cp, 1)
--   c >= 0
-- output
--   w
local function select_scale(w, p, z, N, Z, Lp, ZZp)
	local zl, zu, l, u = 0, ZZp, 0, 1/Lp
	local ztot
	repeat
		local c = l + (u-l)*(Z-zl)/(zu-zl)
		ztot = 0
		for i=0, N-1 do
			local wi = min(c*p[i], 1)
			w[i] = wi
			ztot = ztot + wi*z[i]
		end
		if ztot > Z then
			u, zu = c, ztot
		else
			l, zl = c, ztot
		end
	until abs(ztot-Z) <= EPSILON*Z
end

-- solve
--    N-1
--     ∑ w(p_i)z_i  =  Z
--    i=0
-- where
--   w(p) = iodds(cp)
--   iodds(t) = t/(t+1)
--   c >= 0
-- output
--   w
local function select_iodds(w, p, z, N, Z, ZZ)
	local l, zl, u, zu = 0, -Z, 1/0, ZZ-Z
	local r = 1
	local c = Z/ZZ
	local z0, z1, z2
	repeat
		-- z0 = z(c)
		-- z1 = z'(c)
		-- z2 = -0.5*z''(c)
		z0, z1, z2 = -Z, 0, 0
		for i=0, N-1 do
			local cp1 = 1/(c*p[i]+1)
			local cp2 = cp1^2
			local wi = c*p[i]*cp1
			w[i] = wi
			z0 = z0 + z[i]*wi
			z1 = z1 + z[i]*p[i]*cp2
			z2 = z2 + z[i]*p[i]^2*cp1*cp2
		end
		if z0 > 0 then
			u, zu = c, z0
		else
			l, zl = c, z0
		end
		-- Halley step: c* = c - z(c)z'(c)/[(z'(c))^2 - 0.5*z(c)z''(c)]
		c = c - z0*z1/(z1^2+z0*z2)
		if c < l or c > u then
			-- Halley fell off bounds, fallback to secant.
			local uu = u
			if uu == 1/0 then
				r = r*2
				uu = r
			end
			c = l + (l-uu)*zl/(zu-zl)
			z0 = 1/0
		end
		-- print(c, z0, z1, z2, u, l)
	until abs(z0) <= EPSILON*Z
end

-- solve
--    N-1
--     ∑ w_i*z_i  =  Z
--    i=0
-- where
--   w_i = s_i*y'_{k_i+1} + (1-s_i)*y'{k_i}
--   y'_k = iodds(c*y_k)
--   c >= 0
-- output
--   w
local function select_odds_profile(w, s, k, y, z, N, Z, ZZ)
	local l, zl, u, zu = 0, -Z, 1/0, ZZ-Z
	local r = 1
	local c = Z/ZZ
	local z0, z1, z2
	repeat
		z0, z1, z2 = -Z, 0, 0
		for i=0, N-1 do
			local ki = k[i]
			local yki = y[ki]
			local yki1 = y[ki+1]
			local icyki = 1/(c*yki+1)
			local icyki1 = 1/(c*yki1+1)
			local si = s[i]
			local wi = c*(si*yki1*icyki1 + (1-si)*yki*icyki)
			w[i] = wi
			z0 = z0 + z[i]*wi
			z1 = z1 + z[i]*(si*yki1*icyki1^2 + (1-si)*yki*icyki^2)
			z2 = z2 + z[i]*(si*yki1^2*icyki1^2*icyki1 + (1-si)*yki^2*icyki^2*icyki)
		end
		if z0 > 0 then
			u, zu = c, z0
		else
			l, zl = c, z0
		end
		c = c - z0*z1/(z1^2+z0*z2)
		if c < l or c > u then
			local uu = u
			if uu == 1/0 then
				r = r*2
				uu = r
			end
			c = l + (l-uu)*zl/(zu-zl)
			z0 = 1/0
		end
		-- print(c, z0, z1, z2, u, l)
	until abs(z0) <= EPSILON*Z
end

-- (non-ffi) temporary work arrays to avoid allocations:
-- local work1 = {}
-- local work2 = {}
-- local work3 = {}
-- local work4 = {}
-- local work5 = {}
-- local work6 = {}

local work_zz = {}
local work_zi = {}
local work_zp = {}
local work_k = {}
local work_s = {}
local work_x = {}
local work_xx = {}
local work_yy = {}

-- add more trees to selection.
-- inputs:
--   m   method: "level" | "scale" | "odds_units" | "odds_profile"
--   N   number of trees
--   Z   target amount to collect
--   f   stem count
--   p   priority variable
--   z   collected variable        (optional, default f)
--   K   number of profile points  (optional, default 0)
--   y   priority curve y points   (required if K>0)
--   x   priority curve x points   (optional, default evenly spaced)
--   xm  priority curve x mode     "relative"|"absolute" (optional, default relative)
--   w   current selected stem count (w >= 0, but w>f is explicitly allowed for masking)
-- outputs:
--   w   updated amount selected per tree (0 <= w <= f)
--   Δw^Tz total amount added to selection (0 <= Δw^Tz <= Z)
local function select_more(m, N, Z, f, p, z, K, y, x, xm, w)
	if Z < EPSILON then
		-- shortcut: go away if you don't want anything
		-- return Z instead of 0 here even though we selected nothing, so caller can check
		-- `return == Z` to determine if the selection was succesful.
		return Z
	end
	local NN = 0 -- number of nonzeros
	local zz = work_zz -- available per tree
	local zi = work_zi -- nonzero indices
	local zp = work_zp -- nonzero priority
	local ZZ = 0 -- total available
	local pm, pM = 1/0, -1/0 -- priority bounds
	if z then
		for i=0, N-1 do
			local zzi = max((f[i]-w[i])*z[i], 0)
			if zzi > 0 then
				zz[NN] = zzi
				zi[NN] = i
				zp[NN] = p[i]
				ZZ = ZZ + max((f[i]-w[i])*z[i], 0)
				pm, pM = min(pm, p[i]), max(pM, p[i])
				NN = NN+1
			end
		end
	else
		for i=0, N-1 do
			local zzi = max(f[i]-w[i], 0)
			if zzi > 0 then
				zz[NN] = zzi
				zi[NN] = i
				zp[NN] = p[i]
				ZZ = ZZ + max(f[i]-w[i], 0)
				pm, pM = min(pm, p[i]), max(pM, p[i])
				NN = NN+1
			end
		end
	end
	-- do we have enough?
	if ZZ <= (1+EPSILON)*Z then
		-- print(string.format("ZZ=%f Z=%f", ZZ, Z))
		-- we don't. don't bother searching.
		for i=0, NN-1 do
			w[zi[i]] = max(w[zi[i]], f[zi[i]])
		end
		return ZZ
	end
	if K == 0 or not y or pm >= pM then
		-- fast path: flat profile.
		for i=0, NN-1 do
			w[zi[i]] = w[zi[i]] + (Z/ZZ)*max(f[zi[i]]-w[zi[i]], 0)
		end
		return Z
	end
	-- else: invariants that i'm not going to bother checking but i'm assuming the caller upholds:
	-- (1) K >= 2
	-- (2) x_k < x_{k+1} for k=0,...,K-2   (strict inequality)
	-- (3) 0 <= y_k <= 1 for k=0,...,K-1   if m ~= "level"
	-- assign intervals (k ∈ 0..K-1) for each tree
	local k = work_k -- interval index [0..N-1]   (k ∈ 0..K-2)
	local s = work_s
	if x and #x > 0 then
		-- we were given explicit x points, make sure they cover the whole range
		-- (i.e. x ∈ [min(p), max(p)]), and scan for bucket indices
		if xm ~= "absolute" then
			-- transform relative x to absolute.
			-- do not simplify this expression to `pm + x[j]*(pM-pm)`.
			-- it's important that 0,1 map to pm,pM exactly, because of the next check.
			for j=0, K-1 do
				work_x[j] = x[j]*pM + (1-x[j])*pm
			end
			x = work_x
		end
		if x[0] > pm or x[K-1] < pM then
			-- augment profile to contain the range of p.
			local k = 0
			local xx = work_xx
			local yy = work_yy
			-- insert left endpoint
			if x[0] > pm then
				xx[k] = pm
				local b = (y[1]-y[0])/(x[1]-x[0])
				local y0 = y[0] - (x[0]-pm)*b
				if m == "level" or (y0 >= 0 and y0 <= 1) then
					yy[k] = y0
				else
					yy[k] = min(max(0, y0), 1)
					xx[k+1] = (y[0]-yy[k])/b
					yy[k+1] = yy[k]
					k = k+1
				end
				k = k+1
			end
			-- insert original profile
			for j=0, K-1 do
				xx[k] = x[j]
				yy[k] = y[j]
				k = k+1
			end
			-- insert right endpoint
			if x[K-1] < pM then
				local b = (y[K-1]-y[K-2])/(x[K-1]-x[K-2])
				local y0 = y[K-1] + (pM-x[K-1])*b
				if m == "level" or (y0 >= 0 and y0 <= 1) then
					yy[k] = y0
				else
					xx[k] = (yy[k]-y[K-1])/b
					yy[k] = min(max(0, y0), 1)
					yy[k+1] = yy[k]
					k = k+1
				end
				xx[k] = pM
				k = k+1
			end
			K = k
		end
		for i=0, NN-1 do
			local ki
			for j=1, K-2 do
				if zp[i] < x[j] then
					ki = j-1
					goto found
				end
			end
			ki = K-2
			::found::
			-- this is the slow path and there's an inner loop trace anyway so i'm not going to bother
			-- optimizing this path.
			local ss = (zp[i] - x[ki]) / (x[ki+1] - x[ki])
			if m == "level" or m == "scale" then
				ss = ss*y[ki+1] + (1-ss)*y[ki+1]
			elseif m == "odds_units" then
				ss = odds(min(max(EPSILON, ss*y[ki+1] + (1-ss)*y[ki+1]), 1-EPSILON))
			else -- odds_profile
				k[i] = ki
			end
			s[i] = ss
		end
	else
		x = work_x
		-- evenly spaced x
		local width = (pM-pm)/(K-1)
		local width1 = (K-1)/(pM-pm)
		for j=0, K-1 do
			x[j] = pm + j*width
		end
		-- do not combine these loops.
		-- the duplication here is intentional so that each case gets its own root trace.
		if m == "odds_profile" then
			for i=0, NN-1 do
				k[i] = min(floor((zp[i]-pm)*width1), K-2)
				s[i] = (zp[i]-x[k[i]])*width1
			end
		elseif m == "odds_units" then
			for i=0, NN-1 do
				local ki = min(floor((zp[i]-pm)*width1), K-2)
				local ss = (zp[i]-x[ki])*width1
				s[i] = odds(min(max(EPSILON, ss*y[ki+1] + (1-ss)*y[ki]), 1-EPSILON))
			end
		else -- scale | level
			for i=0, NN-1 do
				local ki = min(floor((zp[i]-pm)*width1), K-2)
				local ss = (zp[i]-x[ki])*width1
				s[i] = ss*y[ki+1] + (1-ss)*y[ki]
			end
		end
	end
	-- output: zw = relative w (0 <= w1 <= 1)
	-- we can reuse work_x here, x is not needed anymore.
	local zw = work_x
	if m == "odds_profile" then
		for j=0, K-1 do
			work5[j] = odds(y[j])
		end
		select_odds_profile(zw, s, k, work5, zz, NN, Z, ZZ)
	elseif m == "odds_units" then
		select_iodds(zw, s, zz, NN, Z, ZZ)
	elseif m == "level" then
		select_level(zw, s, zz, NN, Z, ZZ)
	else -- scale
		local l, _, ZZ = adjustprofile(s, zz, NN, ZZ)
		select_scale(zw, s, zz, NN, Z, l, ZZ)
	end
	-- transform relative w to absolute
	for i=0, NN-1 do
		w[zi[i]] = w[zi[i]] + max(zw[i]*(f[zi[i]]-w[zi[i]]), 0)
	end
	return Z
end

return {
	select_more = select_more
}
