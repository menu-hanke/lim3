local exp, log = math.exp, math.log

local function id5p_pine(d, h, ag, dg, G, hdom)
	return  0.01 * exp(
		5.4625
		- 0.6675 * log(ag)
		- 0.4758 * log(G)
		+ 0.1173 * log(dg)
		- 0.9442 * log(hdom)
		- 0.3631 * log(d)
		+ 0.7762 * log(h)
	)
end

local function id5p_spruce(d, h, ag, dg, hg, G)
	return 0.01 * exp(
		6.9342
		- 0.8808 * log(ag)
		- 0.4982 * log(G)
		+ 0.4159 * log(dg)
		- 0.3865 * log(hg)
		- 0.6267 * log(d)
		+ 0.1287 * log(h)
	)
end

local function ih5p_pine(h, ag, dg)
	return 0.01 * exp(
		5.4636
		- 0.9002 * log(ag)
		+ 0.5475 * log(dg)
		- 1.1339 * log(h)
	)
end

local function ih5p_spruce(d, h, ag, dg, hg, G)
	-- NO exp here.
	return 0.01 * (
		12.7402
		- 1.1786 * log(ag)
		- 0.0937 * log(G)
		- 0.1434 * log(dg)
		- 0.8070 * log(hg)
		+ 0.7563 * log(d)
		- 2.0522 * log(h)
	)
end

return {
	id5p_pine   = id5p_pine,
	id5p_spruce = id5p_spruce,
	ih5p_pine   = ih5p_pine,
	ih5p_spruce = ih5p_spruce
}
