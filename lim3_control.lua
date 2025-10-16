local op = require "lim3_op"
local np = op.np

local periods = {}
local report_node, report_leaf

--------------------------------------------------------------------------------

local period = data.cdata { ctype="int16_t", init=1 }
local prevnode = data.cdata { ctype="int32_t" }
local getstate = data.transaction():read(period, "site.year")
local setperiod = data.transaction():write(period)

local node = 0
local driver, step

driver = control.dynamic(function()
	local period, year = getstate()
	local nextyear = periods[period]
	if not nextyear then
		if report_leaf then
			report_leaf(control.worker()*2^24 + node)
		end
		return control.nothing
	elseif year < nextyear then
		np(math.min(5, nextyear-year))
		return step
	else
		if report_node then
			node = node+1
			report_node(control.worker()*2^24 + node)
		end
		setperiod(period+1)
		return driver
	end
end)

local events = control.all {}
step = control.all { events, driver }
control.simulate = driver

local function console_node(period, node)
	print(string.format("%s[%s] %s",
		string.rep("\t", period-1),
		periods[period] or "LEAF",
		pretty(node)
	))
end

local function setup(settings)
	if settings.events then
		for _,e in ipairs(settings.events) do
			-- TODO: m3 should handle string inside instruction
			local get = data.transaction():read(string.format("site._'{%s}", e.when))
			local event = control.all { function() if not get() then return false end end, e.action }
			table.insert(events, (e.branch == false and control.try or control.optional)(event))
		end
	end
	if settings.nodes then
		local tables = {}
		for k,v in pairs(settings.nodes) do
			if type(k) == "number" then
				periods[k] = v
			else
				tables[k] = v
			end
		end
		report_node = data.transaction()
		if settings.output == "console" then
			report_node:call(console_node, period, tables)
		else
			report_node:set(prevnode, data.arg(1))
			for tab,fs in pairs(tables) do
				local rep = { id = data.arg(1), parent = prevnode }
				for k,v in pairs(fs) do rep[k] = v end
				report_node:sql_insert(tab, rep)
			end
		end
	end
	if settings.leaves then
		if settings.leaves[1] and (not periods[1] or settings.leaves[1] > periods[#periods]) then
			table.insert(periods, settings.leaves[1])
		end
		local tables = {}
		for k,v in pairs(settings.leaves) do
			if type(k) == "string" then
				tables[k] = v
			end
		end
		report_leaf = data.transaction()
		if settings.output == "console" then
			report_leaf:call(console_node, period, tables)
		else
			for tab,fs in pairs(tables) do
				local rep = {}
				if settings.nodes then rep.parent = data.arg(1) end
				for k,v in pairs(fs) do rep[k] = v end
				report_leaf:sql_insert(tab, rep)
			end
		end
	end
end

return {
	setup = setup
}
