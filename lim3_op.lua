data.include "coding.fhk"
data.include "auxiliary.fhk"
data.include "eco.fhk"
data.include "biomass.fhk"
data.include "tapio.fhk"
data.include "growthfunc.fhk"

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
	:update("tree", function(name)
		local gname = string.format("grow'{%s}", name)
		if data.defined("tree", gname) then
			return gname
		end
	end)
	:update("tree", { t13 = "t13_" })
	:update("stratum", { last_Npros = "Npros" })
	:insert(function(tab,name)
		if data.defined("site", string.format("ingrowth'{%s.%s}", tab, name)) then
			return string.format("site.ingrowth'{%s.%s}", tab, name)
		end
	end)

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
				if data.defined("site", "NN") == "data" and data.defined("stratum_tree", name) then
					return string.format("stratum_tree.%s[(stratum_thin_remove,:)]", name)
				end
			end)
	end
	return thin
end

local cut_var = { RC="vtot", income="value" }

local function getcut()
	if not cut then
		cut = data.transaction()
			:update("site", function(name)
				local stem, filter = name:match("^([^']*)'?(.*)$")
				if cut_var[stem] then
					if filter ~= "" then
						if filter:sub(1,1) == "{" then
							filter = filter:sub(2,-2)
						end
						return string.format("%s + sumT'{mark*%s where %s}", name, cut_var[stem], filter)
					else
						return string.format("%s + sum(tree.mark*tree.%s)", name, cut_var[stem])
					end
				end
			end)
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
		snt = 3,
		hgm = 0.3 -- TODO (model?)
	},
	tree = {
		t0  = "site.year",
		t13 = "site.year",
		snt = 3,
		d   = 0,
		h   = 0.3 -- TODO (model?)
	}
}

local function planting(specs, N, plantlevel)
	return data.transaction()
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
			if name == "f" and specs.s then
				-- TODO (fhk): uncomment this when indexing arbitrary expressions is supported
				-- local expr = string.format("(site.rlv_f)[%s-1]", specs.spe)
				local expr = string.format("rlv_f(%s)", specs.s)
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
	elseif settings.grow == "pukkala2021" then
		grow:include("pukkala2021.fhk")
		data.include("naslund.fhk")
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
