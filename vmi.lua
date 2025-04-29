data.ddl [[
	CREATE TEMP VIEW tree AS
	SELECT trees.*, stands.year - trees.a AS t0, stands.year - trees.a13 AS t13
	FROM stands, trees
	WHERE trees.stand_id=stands.id;

	CREATE TEMP VIEW stratum AS
	SELECT strata.*, stands.year - strata.a AS t0
	FROM stands, strata
	WHERE strata.stand_id=stands.id;
]]

table.insert(data.mappers, {
	site = {
		table = "stands",
		where = "stands.id = ?1"
	},
	tree = {
		where = "tree.stand_id = ?1"
	},
	stratum = {
		where = "stratum.stand_id = ?1",
		map = {
			meas_a = "a",
			meas_f = "f",
			meas_g = "g",
			meas_dgm = "d",
			meas_hgm = "h"
		}
	}
})

data.task = "SELECT id FROM stands"
