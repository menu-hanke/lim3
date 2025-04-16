load("earlygrowth/Jaksomallit80.RData")
load("earlygrowth/HDmod_Siipilehto_Kangas_2015_VMI13.RData")
source("earlygrowth/VarhaisKehitys_v8.R")
source("earlygrowth/puujoukonMuodostusMenu_v8.R")

ranefWrapper <- function(spe, snt, age, Npros, g, f, da, dgm, ha, hgm, hdom, dd, mty) {
	nyt <- data.frame(
		DDY = dd,
		T = ifelse(is.na(age), 1, age),  # tämä segfaulttaa jos T puuttuu
		kasvup = mty,
		wet = 0, # TODO
		muokattu = 0, # TODO
		synty = snt,
		Npros = Npros,
		recent = TRUE, # TODO logiikka
		Gos = g,
		Nos = f,
		DA = da,
		DGM = dgm,
		HA = ha,
		HGM = hgm,
		HDOM = hdom
	)
	# XXX: kertoimet kopioitu sim12:sta
	merr <- data.frame(
		Gos  = 0.32,
		Nos  = 0.80,
		DA   = 0.235,
		DGM  = 0.196,
		HA   = 0.20,
		HGM  = 0.154,
		HDOM = 0.154
	)
	ranef <- predictRandomEffectsJaksomalli(
		model = models[[min(spe,3)]],
		meas = nyt,
		measurementError = merr
	)
	# print(spe)
	# print(nyt)
	# print(ranef$b)
	# list(ranef$b, ranef$varb)
}

growWrapper <- function(spe, snt, age, last_Npros, b, varb, dd, mty) {
	#print(b)
	#print(varb)
	new <- data.frame(
		DDY = dd,
		T = age,
		kasvup = mty,
		wet = 0, # TODO
		muokattu = 0, # TODO
		synty = snt,
		Npros = last_Npros,
		recent = TRUE # TODO logiikka
	)
	ranef = list(b=b, varb=varb)
	pred <- predictGrowthJaksomalli(new=new, model=models[[min(spe,3)]], bpred=ranef)
	#print(new)
	#print(pred)
	list(pred$Gos, pred$Nos, pred$DA, pred$DGM, pred$HA, pred$HGM, pred$HDOM)
}

recweibhWrapper <- function(f, ha, hdom, Npros) {
	sol <- recweibh(N=f, H=ha, HDOM=hdom, Npros=Npros, shmin=3)
	list(sol$shape, sol$scale)
}

recweibdWrapper <- function(g, f, d, A=TRUE) {
	sol <- recweibd(g, f, d, ifelse(A,"A","B"), shmin=3)
	list(sol$shape, sol$scale)
}

kuvauspuutWrapperPieni <- function(shape, scale, f, hdom) {
	#print(shape)
	#print(scale)
	#print(f)
	#print(hdom)
	kuvauspuut <- kuvauspuut.weibull(
		c(shape, scale),
		tapa = "dcons",
		n = 10,
		N = f,
		mind = 0,
		dmax = 1.3*hdom,
		minlkm = 1,
		width = 0.5
	)
	#print("kuvauspuutWrapperPieni")
	#print(kuvauspuut$lkm0)
	list(kuvauspuut$lkm0, kuvauspuut$lpm)
}

kuvauspuutWrapperN <- function(shape, scale, f) {
	kuvauspuut <- kuvauspuut.weibull(
		c(shape, scale),
		tapa = "dcons",
		n = 10,
		N = f,
		minlkm = 1,
		width = 2
	)
	#print("kuvauspuutWrapperN")
	#print(kuvauspuut$lkm0)
	list(kuvauspuut$lkm0, kuvauspuut$lpm)
}

kuvauspuutWrapperG <- function(shape, scale, g) {
	kuvauspuut <- kuvauspuut.weibull(
		c(shape, scale),
		tapa = "dcons",
		n = 10,
		G = g,
		minlkm = 1,
		width = 2
	)
	#print("kuvauspuutWrapperN")
	#print(kuvauspuut$lkm0)
	list(kuvauspuut$lkm0, kuvauspuut$lpm)
}

Hpred2Wrapper <- function(spe, dgm, hgm, d, dd) {
	hmalli <- min(spe,3)
	Hpred2(
		data.frame(DDY=dd, DGM=dgm, HGM=hgm, lpm=d),
		kpuut = NA,
		mallit = HDmod[[hmalli]],
		m = c(2,3,2)[hmalli]
	)$pred
}

imputeSmallTreeDBHWrapper <- function(h) {
	d <- imputeSmallTreeDBH(h)
	# imputeSmallTreeDBH palauttaa NA jos h<1.3
	d[h<=1.3] <- 0
	d
}
