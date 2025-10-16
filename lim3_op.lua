local buffer = require "string.buffer"

data.include "def.fhk"
data.include "attributes.fhk"
data.include "eco.fhk"
data.include "harvest.fhk"
data.include "op.fhk"
data.include "param.fhk"

data.define [[
	table site
	table tree[site.N]
	table stratum[site.M]
]]

---- Operations ----------------------------------------------------------------

local OP_CONF_ORDER = 100
local global_opno = 1 -- 0 is reserved for np
-- TODO: m3: data.bind(var, memslot) -> make `lim3_op` a cdata integer
-- memslot:bind(tab, var) ?
local setop = data.transaction():update("global", {lim3_op=data.arg()})

local function op__control(op)
	return op.ctr
end

local function op_configtab(buf, op, tab, config)
	buf:put("model(", OP_CONF_ORDER, ") ", tab, " where global.lim3_op=", op.no, " {")
	for k,v in pairs(config) do
		buf:put(k, "=", v, " ")
	end
	buf:put("}")
end

local function op_config(op, tab, config)
	local buf = buffer.new()
	if type(tab) == "table" then
		for _,t in ipairs(tab) do
			op_configtab(buf, op, t, config)
		end
	else
		op_configtab(buf, op, tab, config)
	end
	data.define(buf)
	return op
end

local op_mt = {
	__m3_control = op__control,
	config       = op_config
}
op_mt.__index = op_mt

local function newop(ctr)
	local no = global_opno
	global_opno = global_opno+1
	return setmetatable({
		ctr = control.all { control.call(setop, no), ctr },
		no  = no
	}, op_mt)
end

local function lazy(f)
	local x
	return function()
		if not x then
			x = f()
		end
		return x
	end
end

---- Natural processes ---------------------------------------------------------

local grow = data.transaction()
	:bind("step", data.arg())
	:update("site", {
		year = "year + query.step"
	})
	:update("tree", function(name)
		local gname = string.format("grow'{%s}", name)
		if data.defined("tree", gname) then
			return gname
		end
	end)
	:update("tree", { t13 = "select(h<1.3, site.year+query.step, t13)" })
	:update("stratum", { last_Npros = "Npros" })
	:insert(function(tab,name)
		if data.defined("site", string.format("ingrowth'{%s.%s}", tab, name)) then
			return string.format("site.ingrowth'{%s.%s}", tab, name)
		end
	end)

local movestrata

-- TODO (m3): m3 should have a hook to run this when `f` changes
local cleantrees = data.transaction():delete("tree", "f<0.1")

local function np(step)
	setop(0)
	cleantrees()
	grow(step)
	if movestrata then
		-- TODO: this should also be hooked on condition change
		movestrata()
	end
end

local function define_movestrata(cond)
	data.define(string.format("model global stratum_exit_early = which(stratum._'{not (%s)})", cond))
	movestrata = data.transaction()
		:delete("stratum", string.format("_'{not (%s)}", cond))
		:insert("tree", function(name)
			if data.defined("stratum_tree", name) and name ~= "thin_mark" then
				return string.format("stratum_tree.%s[(stratum_exit_early,:)]", name)
			end
		end)
end

---- Cutting -------------------------------------------------------------------

-- TODO: tree.w should be a query parameter when fhk gets support for tensor-valued query params
data.define [[
	model tree default'w = 0
]]

local getselect = lazy(function()
	data.define [[
		model global stratum_select_remove = which(stratum.select_f > 1)
	]]
	return data.transaction()
	-- TODO: m3: implement deletion by index and use stratum_select_remove here
		:delete("stratum", "select_f>1")
		:update("tree", { w = "select_f" })
		:insert("tree", function(name)
			if name == "w" then name = "select_f" end
			if data.defined("site", "NN") == "data" and data.defined("stratum_tree", name) then
				return string.format("stratum_tree.%s[(stratum_select_remove,:)]", name)
			end
		end)
end)

local getselectall = lazy(function()
	return data.transaction()
		:delete("stratum", "true") -- TODO (m3): delete("stratum") should delete everything
		:update("tree", {
			w = "f"
		})
		:insert("tree", function(name)
			if name == "w" then name = "f" end
			if data.defined("stratum_tree", name) then
				return string.format("stratum_tree.%s[::]", name)
			end
		end)
end)

local getcut = lazy(function()
	return data.transaction()
		:update("site", function(name)
			local hvar = string.format("h_%s", name)
			if data.defined("site", hvar) then
				return string.format("%s + %s", name, hvar)
			end
		end)
		:update("tree", {
			f = "f - w",
			w = "0"
		})
end)

local function thinning(var, target, profile)
	return newop(control.all { getselect(), getcut() })
		:config({"tree", "stratum_tree"}, {select_var=var})
		:config("site", {
			select_target = target,
			select_profile = profile
		})
end

local function clearcut()
	return newop(control.all { getselectall(), getcut() })
end

---- Planting ------------------------------------------------------------------

local function planting(specs, plantlevel)
	local s, N = assert(specs.s, "missing planting species"), specs.N
	specs.s, specs.N = nil, nil
	return newop(data.transaction()
		:bind("plant_s", s)
		:bind("plant_N", N or 1)
		:insert(function(level, name)
			if not plantlevel then
				-- if early growth is enabled, default to stratum, otherwise trees
				plantlevel = data.defined("site", "M") == "data" and "stratum" or "tree"
			end
			if level ~= plantlevel then
				return
			end
			if plantlevel == "stratum" then
				local m = name:match("^meas_(%w+)$")
				if m then name = m end
			end
			if specs[name] then
				return specs[name]
			end
			if data.defined("site", string.format("plant'{%s.%s}", level, name)) then
				return string.format("site.ingrowth'{%s.%s}", level, name)
			end
		end))
end

--------------------------------------------------------------------------------

local function setup(settings)
	if settings.grow == "metsi" or settings.grow == nil then
		data.include("metsi.fhk")
	elseif settings.grow == "acta" then
		data.include("acta.fhk")
	elseif settings.grow == "pukkala2021" then
		data.include("pukkala2021.fhk")
		data.include("naslund.fhk")
	end
	if settings.early then
		data.include("early.fhk")
		define_movestrata(settings.early)
	else
		-- TODO: allow defining these automatically with m3
		data.define [[
			table stratum_tree[0,0]
			model site { M = 0 NN = 0 }
			model stratum { s = 0 g = 0 f = 0 da = 0 dgm = 0 ha = 0 hgm = 0 hdom = 0 t0 = 0 t13 = 0 }
			model stratum_tree { s = 0 f = 0 d = 0 h = 0 g = 0 t0 = 0 t13 = 0 }
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
