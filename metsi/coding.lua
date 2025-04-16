return {

	-- puulajit
	spe = {
		pine          = 1,    -- mänty
		spruce        = 2,    -- kuusi
		silver_birch  = 3,    -- hieskoivu
		downy_birch   = 4,    -- rauduskoivu
		aspen         = 5,    -- haapa
		gray_alder    = 6,    -- harmaaleppä
		black_alder   = 7,    -- tervaleppä
		xconiferous   = 8,    -- havupuu
		xdeciduous    = 9     -- lehtipuu
	},

	-- 9 -> 4 puulajikoodaus
	spe4 = { 1, 2, 3, 4, 4, 4, 4, 1, 4 },

	-- jaksot
	storie = {
		none          = 0,    -- jaksoton? (tuntematon?)
		lower         = 1,    -- kasvatettava puusto: alempi jakso
		upper         = 2,    -- kasvatettava puusto: ylempi jakso
		over          = 3,    -- ylispuusto
		retention     = 4     -- säästöpuut
	},

	-- syntytapa (perustustapa, uudistustapa)
	snt = {
		natural       = 1,    -- luontainen
		seeded        = 2,    -- kylvetty
		planted       = 3     -- istutettu
	},

	-- maanmuokkaustapa
	soilprep = {
		none          = 0,    -- ei muokkausta
		scalping      = 1,    -- laikutus
		harrowing     = 2,    -- äestys
		patchmounding = 3,    -- laikkumätästys
		ditchmounding = 4,    -- ojitusmätästys
		inverting     = 5,    -- kääntömätästys
		other         = 6     -- "muokattu"
	},

	-- maaluokka
	mal = {
		forest        = 1,
		scrub         = 2,
		waste         = 3,
		other         = 4,
		agriculture   = 5,
		buildup       = 6,
		road          = 7,
		lake          = 8,
		sea           = 9
	},

	-- kasvupaikkatyyppi
	mty = {
		OMaT         = 1,
		OMT          = 2,
		MT           = 3,
		VT           = 4,
		CT           = 5,
		ClT          = 6,
		ROCK         = 7,
		MTN          = 8
	},

	-- alaryhmä
	alr = {
		mineralsoil  = 1,
		peat_spruce  = 2,
		peat_pine    = 3,
		peat_barren  = 4,
		peat_rich    = 5
	},

	-- veroluokan vähennys
	verlt = {
		none         = 0,
		stony        = 1,
		wet          = 2,
		moss         = 3,
		location     = 4
	},

	-- veroluokka
	verl = {
		IA           = 1,
		IB           = 2,
		II           = 3,
		III          = 4,
		IV           = 5,
		SCRUB        = 6,
		WASTE        = 7
	},

	-- ojitustilanne
	oji = {
		unknown         = -1,
		msoil_unditched = 0,  -- ojittamaton kangas
		msoil_ditched   = 1,  -- ojitettu kangas
		peat_unditched  = 2,  -- ojittamaton suo
		peat_unaffected = 3,  -- ojikko (suo, jolla ojitus ei vaikuta kasvuun)
		peat_affected   = 4,  -- muuttuma (suo, jolla ojituksella on selvä vaikutus)
		peat_tkg        = 5   -- turvekangas
	},

	-- ojien kunto
	ojik = {
		unknown      = -1,
		bad          = 0,
		good         = 1
	},

	-- turvekangastyyppi
	tkg = {
		RHTKG1       = 51,
		RHTKG2       = 52,
		MTKG1        = 53,
		MTKG2        = 54,
		PTKG1        = 55,
		PTKG2        = 56,
		VATKG1       = 57,
		VATKG2       = 58,
		JATK         = 59
	},

	-- suotyyppi
	sty = {
		VLK          = 1,
		KoLK         = 2,
		LhK          = 3,
		VLR          = 4,
		RLR          = 5,
		VL           = 6,
		RL           = 7,
		RhSK         = 8,
		RhK          = 9,
		RhSR         = 10,
		RhSN         = 11,
		RhRiN        = 12,
		VSK          = 13,
		MK           = 14,
		KgK          = 15,
		VSR          = 16,
		VRN          = 17,
		MKR          = 18,
		PK           = 19,
		PsK          = 20,
		PKgK         = 21,
		PsR          = 22,
		KgR          = 23,
		PKR          = 24,
		TSR          = 25,
		VkR          = 26,
		LkR          = 27,
		LkKN         = 28
	},

	-- taimityyppi
	feas = {
		cultivated   = 1,
		natural      = 2,
		infeasible   = 3
	},

	-- syntytapa
	origin = {
		natural      = 1,
		seeded       = 2,
		planted      = 3
	}

}
