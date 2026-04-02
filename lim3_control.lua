local op = require "lim3_op"
local np = op.np

local periods = {}
local report_node, report_tail

---- Main loop -----------------------------------------------------------------

local period = data.cdata { ctype="int16_t", init=1 }
-- node id is a double to avoid boxed int64 cdata, but get more range than int32
local prevnode = data.cdata { ctype="double" }
local getstate = data.transaction():read(period, "site.year")
local setperiod = data.transaction():write(period)
local getstopcond

local node = 0
local driver, step, steptail

local function getnodeid()
	return control.worker()*2^32 + node
end

driver = control.dynamic(function()
	local period, year = getstate()
	local nextyear = periods[period]
	if not nextyear then
		if report_tail then
			if not getstopcond() then
				np(5)
				return steptail
			end
			report_tail()
		end
		return control.nothing
	elseif year < nextyear then
		np(math.min(5, nextyear-year))
		return step
	else
		if report_node then
			node = node+1
			report_node()
		end
		setperiod(period+1)
		return driver
	end
end)

---- Debugging -----------------------------------------------------------------

local function console_node(period, node)
	print(string.format("%s[%s] %s",
		string.rep("\t", period-1),
		periods[period] or "TAIL",
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

local function makereport(tx, data, settings, extra)
	if settings.output == false then
		return
	end
	local tables = {}
	for k,v in pairs(data) do
		if type(k) == "string" then
			tables[k] = v
		end
	end
	if settings.output == "console" then
		tx:call(console_node, period, tables)
	else
		for tab,cols in pairs(tables) do
			local rep = {}
			if extra then
				for k,v in pairs(extra) do
					rep[k] = v
				end
			end
			for k,v in pairs(cols) do
				rep[k] = v
			end
			tx:sql_insert(tab, rep)
		end
	end
end

local function setup(settings)
	local events = settings.events or control.nothing
	step = control.all { events, driver }
	control.simulate = step
	if settings.nodes then
		for k,v in pairs(settings.nodes) do
			if type(k) == "number" then
				periods[k] = v
			end
		end
		report_node = data.transaction()
		if settings.output and settings.output ~= "console" then
			report_node:set(prevnode, getnodeid)
		end
		makereport(report_node, settings.nodes, settings, { id=getnodeid, parent=prevnode })
	end
	if settings.tail or settings.trace then
		report_tail = data.transaction()
		if settings.tail then
			if settings.tail[1] then
				if type(settings.tail[1]) == "string" then
					getstopcond = data.transaction():read(settings.tail[1])
				else
					getstopcond = settings.tail[1]
				end
				steptail = control.all { control.single(events), driver }
			end
			local extra = {}
			if settings.nodes then extra.id = getnodeid end
			makereport(report_tail, settings.tail, settings, extra)
		end
		if settings.trace then
			report_tail:call(trace_dump)
			traceon()
		end
		if not getstopcond then
			getstopcond = function() return true end
		end
	end
	if not settings.trace then
		traceoff()
	end
	if settings.cuttings then
		local extra = {}
		if settings.nodes then extra.id = getnodeid end
		makereport(op.getcut(), settings.cuttings, settings, extra)
	end
end

return {
	setup = setup,
	trace = trace
}
