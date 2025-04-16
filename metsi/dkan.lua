local function dk(d)
	return 2 + 1.25*d
end

local function dkjs_small(h)
	return math.exp(
        0.4102
        + 1.0360 * math.log(h)
        + (0.037+0.041)^2/2
	)
end

return {
	dk = dk,
	dkjs_small = dkjs_small
}
