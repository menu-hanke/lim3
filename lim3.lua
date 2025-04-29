data.include "coding.fhk"
data.include "auxiliary.fhk"
data.include "cut.fhk"
data.include "eco.fhk"
data.include "biomass.fhk"

data.define [[
	table site
	table tree[site.N]
	table stratum[site.M]
]]

local periods = {}
local report_node, report_leaf

---- Natural processes ---------------------------------------------------------

-- TODO: muuta nämä yhtälöt muotoon x = ix_step, ja laita ix_step = ... kaavat mallikirjastoon
local grow = data.transaction()
	-- :param("step")
	:update("site", {
		year = "year + site.step"
	})
	:update("tree", {
		d = "d + id5*site.step/5",
		h = "h + ih5*site.step/5",
		f = "f * sp5^(site.step/5)"
	})
	:update("stratum", {
		last_Npros = "Npros"
	})

local movestrata

-- TODO (m3): m3 should have a hook to run this when `f` changes
local cleantrees = data.transaction():delete("tree", "f<0.1")

-- TODO: replace with query parameter when implemented in fhk/m3
-- TODO: should be global.step
local setstep = data.transaction():update("site", {step=data.arg()})

local function np(step)
	cleantrees()
	setstep(step or 5)
	grow()
	if movestrata then
		-- TODO: this should also be hooked on condition change
		movestrata()
	end
end

local function define_movestrata(cond)
	movestrata = data.transaction()
		:define(string.format("model global stratum_exit_early = which(stratum._'{not (%s)})", cond))
		:delete("stratum", string.format("_'{not (%s)}", cond))
		:insert("tree", function(name)
			if data.defined("stratum_tree", name) and name ~= "thin_mark" then
				return string.format("stratum_tree.%s[(stratum_exit_early,:)]", name)
			end
		end)
end

---- Cutting -------------------------------------------------------------------

local thin, cut

local function getthin()
	if not thin then
		thin = data.transaction()
			-- :param("thin_method")
			:define([[
				model stratum thin_remove = any(stratum_tree.thin_mark > 1)
				model global stratum_thin_remove = which(stratum.thin_remove)
			]])
			:delete("stratum", "thin_remove")
			:update("tree", {
				mark = "thin_mark"
			})
			:insert("tree", function(name)
				if name == "mark" then name = "thin_mark" end
				if data.defined("stratum_tree", name) then
					return string.format("stratum_tree.%s[(stratum_thin_remove,:)]", name)
				end
			end)
	end
	return thin
end

local function getcut()
	if not cut then
		cut = data.transaction()
			:update("site", function(name)
				local discount = name:match("^npv'{(%d+)}$")
				if discount then
					return string.format("%s + sum(tree.mark*tree.cc_C)*(1+%g)^(%d-year)",
						name, discount/100, periods[1])
				end
			end)
			:update("site", {
				RC = "RC + sum(tree.mark*tree.vtot)"
			})
			:update("tree", {
				f = "f - mark",
				mark = "0"
			})
	end
	return cut
end

local thinid = 0
local function thinning(var, target, profile)
	local thid = thinid
	thinid = thinid+1
	local thin = getthin()
	thin:define(string.format([=[
		model site tree.thin_mark, stratum_tree.thin_mark[::]
				= call Lua["return require('metsi.thin').new(%s)"] (
			%s,
			[..tree.d, ..stratum_tree.d[::]],
			[..tree.f, ..stratum_tree.f[::]],
			[..tree._'{%s}, ..stratum_tree._'{%s}[::]],
			out[N], out[NN]
		) where thin_method=%d
	]=],
		profile,
		target,
		var, var,
		thid
	))
	local setthid = data.transaction():update("site", {thin_method=thid})
	return control.all {
		setthid,
		getthin(),
		getcut()
	}
end

local function clearcut()
	return control.all {
		data.transaction()
			:delete("stratum", "true") -- TODO (m3): delete("stratum") should delete everything
			:update("tree", {
				mark = "f"
			})
			:insert("tree", function(name)
				if name == "mark" then name = "f" end
				if data.defined("stratum_tree", name) then
					return string.format("stratum_tree.%s[::]", name)
				end
			end),
		getcut()
	}
end

---- Planting ------------------------------------------------------------------

local plant_default = {
	t0  = "[site.year]",
	snt = "[3]"
}

local function planting(specs)
	local level = specs.level or "stratum"
	return data.transaction()
		:insert(level, function(name)
			if level == "stratum" then
				local m = name:match("^meas_(%w+)$")
				if m then name = m end
			end
			return specs[name] or plant_default[name]
		end)
end

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

-- settings:
--   grow = ["metsi"]|"acta"
--   early = [true]|false
--   output = ["sql"]|"console"
--   events = {[
--     {
--       when = string,
--       action = instruction
--     }
--   ]}
--   nodes = {
--     years = {[number]}
--     table = string
--     values = { [string]=string }
--   }
--   leaves = {
--     year = number
--     table = string
--     values = { [string]=string }
--   }
local function setup(settings)
	if settings.grow == "metsi" or settings.grow == nil then
		grow:include("metsi.fhk")
	elseif settings.grow == "acta" then
		grow:include("acta.fhk")
	end
	if settings.early then
		grow:include("early.fhk")
		define_movestrata(settings.early)
	else
		-- TODO: allow defining these automatically with m3
		data.define [[
			table stratum_tree[0,0]
			model site { M = 0 NN = 0 }
			model stratum { s = 0 g = 0 f = 0 da = 0 dgm = 0 ha = 0 hgm = 0 hdom = 0 t0 = 0 t13 = 0 }
			model stratum_tree { s = 0 f = 0 d = 0 h = 0 g = 0 t0 = 0 t13 = 0}
		]]
	end
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
	if not cut then
		data.define [[
			macro var site npv'$_ = 0
			model site RC = 0
		]]
	end
end

return {
	setup    = setup,
	np       = np,
	thinning = thinning,
	clearcut = clearcut,
	planting = planting
}
