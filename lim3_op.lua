data.include "coding.fhk"
data.include "auxiliary.fhk"
data.include "eco.fhk"
data.include "biomass.fhk"
data.include "tapio.fhk"

data.define [[
	table site
	table tree[site.N]
	table stratum[site.M]
]]

---- Natural processes ---------------------------------------------------------

-- TODO: add if-then-else expression to fhk, then this can be rewritten simply as
--   t13 = "if h<1.3 then site.year+site.step else t13"

data.define [[
	model tree {
		t13_ = site.year+site.step where h<1.3
		t13_ = t13
	}
]]

-- TODO: muuta nämä yhtälöt muotoon x = ix_step, ja laita ix_step = ... kaavat mallikirjastoon
local grow = data.transaction()
	-- :param("step")
	:update("site", {
		year = "year + site.step"
	})
	:update("tree", {
		d = "d + id5*site.step/5",
		h = "h + ih5*site.step/5",
		f = "f * sp5^(site.step/5)",
		t13 = "t13_"
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

data.define [[
	model tree default'mark = 0
	model tree default'thin_mark = 0
	model stratum_tree default'thin_mark = 0
]]

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

data.define [[
	model site RC_now = sum(tree.mark*tree.vtot)
	model site income_now = sum(tree.mark*tree.value)
]]

local function getcut()
	if not cut then
		cut = data.transaction()
			:update("site", {
				RC = "RC + RC_now",
				income = "income + income_now"
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
	stratum = {
		t0  = "site.year",
		snt = 3
	},
	tree = {
		t0  = "site.year",
		t13 = "site.year",
		snt = 3,
		d   = 0
	}
}

local function planting(specs, N, level)
	level = level or "stratum"
	return data.transaction()
		:insert(level, function(name)
			if level == "stratum" then
				local m = name:match("^meas_(%w+)$")
				if m then name = m end
			end
			if specs[name] then
				return specs[name]
			end
			if name == "f" and specs.s then
				-- TODO (fhk): uncomment this when indexing arbitrary expressions is supported
				-- local expr = string.format("(site.rlv_f)[%s-1]", specs.spe)
				local expr = string.format([[call Lua ["metsi.tapio":"rlv_f"] (site.mty, %s) ]], specs.s)
				if N then
					expr = string.format("%s/%s", expr, N)
				end
				return expr
			end
			return plant_default[level][name]
		end)
end

--------------------------------------------------------------------------------

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
