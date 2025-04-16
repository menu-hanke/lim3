local coding = require "metsi.coding"
require "table.new"
local mineralsoil = coding.alr.mineralsoil
local exp, max, min, pi, sqrt = math.exp, math.max, math.min, math.pi, math.sqrt

-- xs: tree x
-- hs: tree height
-- os: output indices, os[0] is the largest tree and so on
local function idxhsort(xs, hs, os)
	local idx = table.new(#xs, 0)
	for i=1, #xs do idx[i] = i-1 end
	table.sort(idx, function(a, b) return xs[a] + hs[a]*0.001 > xs[b] + hs[b]*0.001 end)
	for i=1, #xs do os[i-1] = idx[i] end
end

local function dnz(d, alr)
	print("dnz", d, alr)
	if d == 0 and alr == mineralsoil then
		return 0.01
	end
	return d
end

local function clamp(a, x, b)
	return min(max(a, x), b)
end

local function expm1(x)
	return exp(x) - 1
end

local function choose(c, a, b)
	if c then
		return a or 1
	else
		return b or 0
	end
end

local function sgn1(x)
	if x >= 0 then
		return 1
	else
		return -1
	end
end

local function tolmax(x, lim, k)
    if x < lim then
        return k
    else
        return x
	end
end

local function tolmin(x, lim, k)
    if x > lim then
        return k
    else
        return x
	end
end

---- Transforms ----------------------------------------------------------------

local KD2G  = pi/4
local KD2GX = (pi/4)/10000
local KG2D  = 2/sqrt(pi)
local KG2DX = 100*2/sqrt(pi)

local function d2gu(d)
	return KD2G * d^2
end

local function d2g(d)
	return KD2GX * d^2
end

local function g2du(g)
	return KG2D * sqrt(g)
end

local function g2d(g)
	return KG2DX * sqrt(g)
end

local function delta_d2g(d, deltad)
	return KD2GX * ((d+deltad)^2 - d^2)
	--return d2g(d+deltad) - d2g(d)
end

local function delta_g2d(g, deltag)
	return KG2DX * (sqrt(g+deltag) - sqrt(g))
	--return g2d(g+deltag) - g2d(g)
end

---- Labels --------------------------------------------------------------------

local labels = {}
do
	local function addlabels(xs)
		for k,v in pairs(xs) do labels[k] = v end
	end
	addlabels(coding.spe)
	addlabels(coding.storie)
end
labels.birch = {labels.silver_birch, labels.downy_birch}
labels.deciduous = {
	labels.silver_birch,
	labels.downy_birch,
	labels.aspen,
	labels.gray_alder,
	labels.black_alder,
	labels.xdeciduous
}

local function label(l)
	return labels[l] or error(string.format("undefined label: `%s'", l))
end

---- Loops ---------------------------------------------------------------------

-- metsi-style prefix sum.
-- if idx is given, then xs is sparse with idx being the nonzeros.
local function spsum(out, order, prio, xs, idx)
	local n = #order
	if n == 0 then return end
	if idx then
		for i=0, n-1 do out[i] = 0 end
		for i=0, #idx-1 do out[idx[i]] = xs[i] end
		xs = out
	end
	local j = order[0]
	local p = prio[j]
	local t, s, k = 0, xs[j], 0
	for i=1, n-1 do
		local j = order[i]
		local pp = prio[j]
		if pp < p then
			while k < i do
				out[order[k]] = t+0.5*s
				k = k+1
			end
			t = t+s
			s = 0
			p = pp
		end
		s = s+xs[j]
	end
	while k < n do
		out[order[k]] = t+0.5*s
		k = k+1
	end
	--print("=>spsum", out)
end

local function vmax(xs, default)
	local m = default or -math.huge
	for i=0, #xs-1 do
		if xs[i] > m then
			m = xs[i]
		end
	end
	return m
end

--------------------------------------------------------------------------------

return {
	idxhsort   = idxhsort,
	dnz        = dnz,
	clamp      = clamp,
	expm1      = expm1,
	choose     = choose,
	sgn1       = sgn1,
	tolmax     = tolmax,
	tolmin     = tolmin,
	d2gu       = d2gu,
	d2g        = d2g,
	g2du       = g2du,
	g2d        = g2d,
	delta_g2d  = delta_g2d,
	delta_d2g  = delta_d2g,
	label      = label,
	spsum      = spsum,
	vmax       = vmax
}
