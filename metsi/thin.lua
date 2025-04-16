local ffi = require "ffi"
local floor, min, max, inf = math.floor, math.min, math.max, math.huge

--local EPSILON = 0.001
local EPSILON = 1e-6

local cast = ffi.cast
local workarray_ct = ffi.typeof "double[?]"
local doubleptr_ct = ffi.typeof "double *"
local workarray, workarray_size = nil, 0

local function allocwork(n)
	if n > workarray_size then
		workarray, workarray_size = workarray_ct(n), n
	end
	return cast(doubleptr_ct, workarray)
end

-- if one of the output arrays is large enough (ie. only one group is nonempty),
-- then use that output array. otherwise allocate a work array.
local function workarray(need, o, ...)
	if o then
		if #o > 0 then
			if #o < need then
				return allocwork(need)
			else
				return o.e
			end
		else
			return workarray(need, ...)
		end
	else
		return allocwork(need)
	end
end

local function constweights(w, n)
	for i=0, n-1 do
		w[i] = 1
	end
	return 1
end

-- NOTE: w and d are C arrays (0-based), profile is a lua table (1-based)
local function weights(w, d, n, profile)
	local nprof = #profile
	if nprof <= 1 then
		return constweights(w, n)
	end
	local m, M = inf, -inf
	for i=0, n-1 do
		m = min(m, d[i])
		M = max(M, d[i])
	end
	if m >= M then
		return constweights(w, n)
	end
	local t = (M-m)/(nprof-1)
	local t1 = 1/t
	local wmin = inf
	for i=0, n-1 do
		local di = d[i]-m
		local j = min(floor(di*t1), nprof-2)
		local s = (di-j*t)*t1
		local wi = profile[j+1]*(1-s) + profile[j+2]*s
		if wi < EPSILON then
			wi = 0
		else
			wmin = min(wmin, wi)
		end
		w[i] = wi
	end
	return wmin
end

local function remtarget(strength, f, x, n)
	local t = 0
	for i=0, n-1 do
		t = t + f[i]*x[i]
	end
	return strength*t
end

local function writeoutput(f, w, t, idx, out, ...)
	if not out then
		return
	end
	for _=0, #out-1 do
		-- return removed stems
		out[idx] = f[idx] * min(1, t*w[idx])
		idx = idx+1
	end
	return writeoutput(f, w, t, idx, ...)
end

local function thin(profile, target, d, f, x, ...)
	local n = #x
	local w = workarray(n, ...)
	local wmin = weights(w, d, n, profile)
	-- local target = remtarget(strength, f, x, n)
	local t
	if wmin < inf then
		local l, u = 0, 1/wmin
		local rem
		while true do
			t = 0.5*(l+u)
			local r = 0
			for i=0, n-1 do
				r = r + f[i]*x[i]*min(1, t*w[i])
			end
			-- print(string.format("[*] l=%.3f t=%.3f u=%.3f r=%.3f target=%.3f", l, t, u, r, target))
			if r < target+EPSILON then
				l = t
			elseif r > target+EPSILON then
				u = t
			else
				-- done
				break
			end
			if r == rem then
				-- stuck
				break
			end
			rem = r
		end
	else
		-- else: no positive weights, no removal
		t = 0
	end
	writeoutput(f, w, t, 0, ...)
end

local function new(...)
	--print("thin.new ->", ...)
	local profile = {...}
	return function(...) return thin(profile, ...) end
end

return {
	new = new
}
