local op = require "lim3_op"
local ctr = require "lim3_control"

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
	op.setup(settings)
	ctr.setup(settings)
end

return {
	setup        = setup,
	trace        = ctr.trace,
	np           = op.np,
	wrap         = op.wrap,
	selector     = op.selector,
	cutting      = op.cutting,
	split        = op.split,
	regeneration = op.regeneration,
}
