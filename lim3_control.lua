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
			report_leaf(node)
		end
		return control.nothing
	elseif year < nextyear then
		np(math.min(5, nextyear-year))
		return step
	else
		if report_node then
			node = node+1
			report_node(node)
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
			local get = data.transaction():read(e.when)
			local event = control.all { function() if not get() then return false end end, e.action }
			table.insert(events, (e.branch == false and control.try or control.optional)(event))
		end
	end
	if settings.nodes then
		for i,y in ipairs(settings.nodes.years) do periods[i] = y end
		if settings.output == "console" then
			report_node = data.transaction():call(console_node, period, settings.nodes.values)
		else
			local rep = { id = data.arg(1), parent = prevnode }
			for k,v in pairs(settings.nodes.values) do rep[k] = v end
			report_node = data.transaction()
				:set(prevnode, data.arg(1))
				:sql_insert(settings.nodes.table, rep)
		end
	end
	if settings.leaves then
		if settings.leaves.year and (not periods[1] or settings.leaves.year > periods[#periods]) then
			table.insert(periods, settings.leaves.year)
		end
		if settings.output == "console" then
			report_leaf = data.transaction():call(console_node, period, settings.leaves.values)
		else
			local rep = {}
			if settings.nodes then rep.parent = data.arg(1) end
			for k,v in pairs(settings.leaves.values) do rep[k] = v end
			report_leaf = data.transaction():sql_insert(settings.leaves.table, rep)
		end
	end
end

return {
	setup = setup
}
