local function h_pine(d)
	return (d / (0.894 + 0.185*d))^2 + 1.3
end

local function h_spruce(d)
	return (d / (1.811 + 0.308*d))^3 + 1.3
end

local function h_birch(d)
	return (d / (0.898 + 0.242*d))^2 + 1.3
end

return {
	h_pine   = h_pine,
	h_spruce = h_spruce,
	h_birch  = h_birch
}
