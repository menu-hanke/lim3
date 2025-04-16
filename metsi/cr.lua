local coding = require "metsi.coding"
local mm = require "metsi.math"
local dkan = require "metsi.dkan"
local OMaT, OMT, MT, VT, CT, ClT = coding.mty.OMaT, coding.mty.OMT, coding.mty.MT,
	coding.mty.VT, coding.mty.CT, coding.mty.ClT
local spe4 = coding.spe4
local choose = mm.choose
local dk13 = dkan.dk
local exp, log, min = math.exp, math.log, math.min

local PF = {
    {
        3.861,-.172, -.172, 0.,.066,-.090,-.090,-.462,0.,0.,
        -0.635,-2.079,-0.996,    0.,0.,0.,-.261,-.239,.1632,.1283,
    },
    {
        5.524, .218, .229,0.,.381,.381,.381,-.187,0.,0.,
        -0.884,-1.833,-1.362,    0.,0.,0.,   0.,   0.,.3480,.2336,
    },
    {
        2.218, .248, .084,0.,  0.,  0.,  0.,-.595,0.,0.,
        -0.198,-0.988,-0.889,    0.,0.,0.,   0.,   0.,.1269,.1798,
    },
    {
        2.197, .248, .084,0.,  0.,  0.,  0.,-.595,0.,0.,
        -0.198,-0.988,-0.889,    0.,0.,0.,   0.,   0.,.1269,.1798
    }
}

local PLKOR = {1.,1.,1.,1.,.99,.98,.97,.96,.95}

local function cr(spe, rdfl, mty, dd, dg, hg, rdf)
	--print("cr", spe, rdfl, mty, dd, dg, hg, rdf)
    if 0 < hg and hg <= 3 then
        dkw = exp(0.4163+1.0360*log(hg))
    else
        dkw = dk13(dg)
	end
    local pf = PF[spe4[spe]]
    local A = (
        pf[1]
        + pf[2] * choose(mty == OMaT)
        + pf[3] * choose(mty == OMT)
        + pf[4] * choose(mty == MT)
        + pf[5] * choose(mty == VT)
        + pf[6] * choose(mty >= CT)
        + pf[7] * choose(mty >= ClT)
        + pf[8] * dd/1000
    )
    local crf = (
        A
        + pf[11] * log(dkw)
        + pf[12] * log(1+rdf)
        + pf[13] * log(1+rdfl)
        + pf[14] * log(1+rdf*rdfl)
    )
    local kor = PLKOR[spe4[spe]]
    crexp = exp(crf*kor)
    return min(crexp/(1+crexp), 0.99)
end

return {
	cr = cr
}
