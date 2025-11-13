local ffi = require "ffi"
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

local function wrap(ctr)
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

---- Selection -----------------------------------------------------------------

-- TODO: tree.w should be a query parameter when fhk gets support for tensor-valued query params
data.define [[
	model tree default'w = 0
]]

local getselect_trees = lazy(function()
	return data.transaction():update("tree", {w=data.arg()})
end)

local getselect_strata = lazy(function()
	-- TODO: this will not work until fhk gets vector query parameter support
	data.define [[
		model site stratum_tree.lim3_select_f[::] = query.lim3_select_stratum_tree_f
		model stratum lim3_select_f = sum(stratum_tree.lim3_select_f)
		model global lim3_select_remove_strata = which(stratum.lim3_select_f > 1)
	]]
	return data.transaction()
		:bind("lim3_select_stratum_tree_f", data.arg(2))
		-- TODO: m3: implement deletion by index and use stratum_select_remove here
		:delete("stratum", "lim3_select_f>1")
		:update("tree", { w=data.arg(1) })
		:insert("tree", function(name)
			if name == "w" then name = "lim3_select_f" end
			if data.defined("site", "NN") == "data" and data.defined("stratum_tree", name) then
				return string.format("stratum_tree.%s[(lim3_select_remove_strata,:)]", name)
			end
		end)
end)

local function selector_maketab(x, method)
	if not x then return end
	local s = x[0] and 0 or 1
	local xx = {}
	if method == "level" then
		-- don't scale
		local j = 0
		for i=s, #x do
			xx[j] = x[i]
			j = j+1
		end
	else
		local M = -1/0
		for i=s, #x do
			M = math.max(M, x[i])
		end
		local j = 0
		for i=s, #x do
			xx[j] = x[i] / M
			j = j+1
		end
	end
	return xx
end

local function selector_treeexpr(expr, strata)
	if strata then
		return string.format("[..tree._'{%s}, ..stratum_tree._'{%s}[::]]", expr, expr)
	else
		return string.format("tree._'{%s}", expr)
	end
end

local function selector_target(settings)
	local buf = buffer.new()
	local upv = {}
	upv.doselect = settings.strata and getselect_strata() or getselect_trees()
	upv.select_more = require("metsi.select").select_more
	upv.doublearray_ct = ffi.typeof("double[?]")
	local z = assert(settings.var, "selection var missing")
	local f = settings.frequency or (z == "w" and "w") or "f"
	local q1 = {
		N = "site.N",
		f = selector_treeexpr(f, settings.strata),
	}
	assert(
		(settings.select or settings.leave) and not (settings.select and settings.leave),
		"exactly one of `select` or `leave` must be specifiec"
	)
	if settings.select then
		q1.Z = string.format("site._'{%s}", settings.select)
	else
		q1.Z = string.format("sum(tree.f*%s) - site._'{%s}", z, settings.leave)
	end
	if settings.strata then
		q1.NN = "site.NN"
	end
	local haveexpr = { f = f }
	if z ~= f then
		q1.z = selector_treeexpr(z, settings.strata)
		haveexpr[z] = "z"
	end
	local queries = { q1 }
	buf:put("return function()\nlocal q1 = query1()\nlocal N, Z, f = q1.N, q1.Z, q1.f\n")
	if z ~= f then
		buf:put("local z = q1.z\n")
	end
	local all_N
	if settings.strata then
		buf:put("local all_N = N + q1.NN")
		all_N = "all_N"
	else
		all_N = "N"
	end
	buf:put("local w = doublearray_ct(N) do\n")
	for i=1, math.max(#settings, 1) do
		local sub = settings[i] or {}
		local method = sub.method or settings.method or "odds_units"
		local y = sub.y or settings.y
		local x = sub.x or settings.x
		if x and y and #x ~= #y then error(string.format("x/y length mismatch: %d/%d", x, y)) end
		local K = (y and #y) or (x and #x) or 0
		upv[string.format("sub%d_y", i)] = selector_maketab(y, method)
		upv[string.format("sub%d_x", i)] = selector_maketab(x, method)
		local p = sub.priority or settings.priority or "d"
		local mask = sub.which or settings.which
		if not haveexpr[p] or (mask and not haveexpr[mask]) then
			if not queries[i] then
				queries[i] = {}
				buf:putf("local q%d = query%d()\n", i, i)
			end
			if not haveexpr[p] then
				queries[i].p = selector_treeexpr(p, settings.strata)
				haveexpr[p] = string.format("q%d.p", i)
			end
			if mask and not haveexpr[mask] then
				queries[i].mask = selector_treeexpr(string.format("select(%s, f, 0)", mask),
					settings.strata)
				haveexpr[mask] = string.format("q%d.mask", i)
			end
		end
		buf:put("do\n")
		buf:putf(
			"local ZZ = select_more('%s', %s, Z, %s, %s, z, %d, sub%d_y, sub%d_x, '%s', w)\n",
			method,
			all_N,
			mask and haveexpr[mask] or "f",
			haveexpr[p],
			K,
			i,
			i,
			sub.xm or settings.xm or "relative"
		)
		buf:put([[
			if ZZ == Z then goto doselect end
			Z = Z - ZZ
		]])
		buf:put("end\n")
	end
	buf:put("end ::doselect::\n")
	if settings.strata then
		buf:put("doselect(w, w+N)\n")
	else
		--buf:put("for i=0, N-1 do print('sel', i,w[i]) end\n")
		buf:put("doselect(w)\n")
	end
	buf:put("end\n")
	for i,v in pairs(queries) do
		upv[string.format("query%d", i)] = data.transaction():read(v)
	end
	local upval = {}
	local buf2 = buffer.new()
	buf2:put("local ")
	local upvalidx = 1
	for k,v in pairs(upv) do
		if upvalidx > 1 then buf2:put(",") end
		buf2:put(k)
		upval[upvalidx] = v
		upvalidx = upvalidx+1
	end
	buf2:put("= ...\n", buf)
	--print(buf2)
	return assert(load(buf2))(unpack(upval, 1, upvalidx))
end

local function selector_all(settings)
	local expr = settings.which
	for i=1, #settings do
		if settings[i].which then
			expr = expr and string.format("(%s) and (%s)", expr, settings[i].which) or settings[i].which
		end
	end
	if settings.strata then
		error("TODO")
	end
	return control.call(
		getselect_trees(),
		data.transaction():read(selector_treeexpr(string.format("select(%s, f, 0)", expr or "true")))
	)
end

local function selector_compile(settings)
	if settings.var then
		return selector_target(settings)
	else
		return selector_all(settings)
	end
end

local selector_cache = {}

-- settings (primary selector):
-- * var: collected variable (optional)
-- * select: amount of `var` to select (optional, required if var is given)
-- * leave: amount of `var` to NOT select (optional, mutually exclusive with `select`)
-- * priority: default subselector priority expression (optional, default `d`)
-- * which: default subselector tree-level boolean condition (optional, default true)
-- * method, y, x, xm: same meaning as in select_more (see select.lua)
-- zero or more subselectors:
-- * priority: priority expression (optional, default global.priority)
-- * which: tree-level boolean condition (optional, default global.which)
-- * method, y, x, xm: see select.lua (optional, default global)
local function selector(settings)
	if not selector_cache[settings] then
		selector_cache[settings] = selector_compile(settings)
	end
	return selector_cache[settings]
end

---- Cutting -------------------------------------------------------------------

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
			w = 0
		})
end)

local function cutting()
	return wrap(getcut())
end

---- Splitting -----------------------------------------------------------------

data.define [[
	model global lim3_trees_selected = which(tree.w > 0)
]]

local function split(set)
	return data.transaction()
		:update("tree", {
			f = "f-w",
			w = 0
		})
		:insert("tree", function(name)
			if set[name] then
				return set[name]
			end
			if name == "f" then
				name = "w"
			end
			return string.format("tree.%s[lim3_trees_selected]", name)
		end)
end

---- Planting ------------------------------------------------------------------

local function planting(prototype, plantlevel)
	local s, N = assert(prototype.s, "missing planting species"), prototype.N
	return wrap(data.transaction()
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
			if prototype[name] then
				return prototype[name]
			end
			if data.defined("site", string.format("plant'{%s.%s}", level, name)) then
				return string.format("site.plant'{%s.%s}", level, name)
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
	wrap     = wrap,
	selector = selector,
	cutting  = cutting,
	split    = split,
	planting = planting
}
