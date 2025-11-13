local op = require "lim3_op"
local np = op.np

local periods = {}
local report_node, report_leaf

---- Main loop -----------------------------------------------------------------

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

control.simulate = driver

---- Debugging -----------------------------------------------------------------

local function console_node(period, node)
	print(string.format("%s[%s] %s",
		string.rep("\t", period-1),
		periods[period] or "LEAF",
		pretty(node)
	))
end

local tracecontrols = {}
local tracestack, tracetop, gettracetop, settracetop

local function trace(tag)
	local tracectr = control.all {}
	table.insert(tracecontrols, {ctr=tracectr, tag=tag})
	return tracectr
end

local function trace_push(tag)
	local _, year = getstate()
	local top = gettracetop()
	tracestack[top] = string.format("(%d) %s", year, tag)
	settracetop(top+1)
end

local function trace_dump()
	local period = getstate()
	local top = gettracetop()
	print(string.format("%s[TRACE] %s",
		string.rep("\t", period-1),
		table.concat(tracestack, " -> ", 0, top-1)
	))
end

local function traceon()
	tracetop = data.cdata { ctype="int32_t" }
	gettracetop = data.transaction():read(tracetop)
	settracetop = data.transaction():write(tracetop)
	tracestack = {}
	for _,t in ipairs(tracecontrols) do
		table.insert(t.ctr, control.call(trace_push, t.tag))
	end
end

local function traceoff()
	tracecontrols = nil
end

--------------------------------------------------------------------------------

local function setup(settings)
	step = control.all { settings.events or control.nothing, driver }
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
		elseif settings.output ~= false then
			report_node:set(prevnode, data.arg(1))
			for tab,fs in pairs(tables) do
				local rep = { id = data.arg(1), parent = prevnode }
				for k,v in pairs(fs) do rep[k] = v end
				report_node:sql_insert(tab, rep)
			end
		end
	end
	if settings.leaves or settings.trace then
		report_leaf = data.transaction()
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
			if settings.output == "console" then
				report_leaf:call(console_node, period, tables)
			elseif settings.output ~= false then
				for tab,fs in pairs(tables) do
					local rep = {}
					if settings.nodes then rep.parent = data.arg(1) end
					for k,v in pairs(fs) do rep[k] = v end
					report_leaf:sql_insert(tab, rep)
				end
			end
		end
		if settings.trace then
			report_leaf:call(trace_dump)
			traceon()
		end
	end
	if not settings.trace then
		traceoff()
	end
end

return {
	setup = setup,
	trace = trace
}
