load("menu/VarhaisKehitysMallit/Jaksomallit80.RData")
load("menu/HDmod_Siipilehto_Kangas_2015.RData")
source("menu/VarhaisKehitys_v8.R")
source("menu/PuujoukonMuodostusMenu_v7.R")

## Wrapper varhaiskehitysmallien kutusmiseen C-kieleisestä menusta. 
## Lauri Mehtätalo 18.10.1014. 
##
## Käytössä on neljä funktiota:
## 
## predictRandomEffectsJakosmalli:
## Ennustaa annetun metsikön annetulle ositteelle satunnaisvaikutukset.
## Satunnaisvaikutuksia ei palauteta c-ohjelmalle, vaan ne pidetään tallessa R:n globaalissa
## työtilassa listassa RandomEffects. 
## Aina kun ennustetaan uudelle metsikälle uudet satunnaisvaikutukset, 
## ne kirjoitetaan ko. listan loppuun, ja funktion palautusarvo on luku 2. 
## Jos ennustetaan satunnaisvaikutukset samalle metsikälle uudestaan, ne kirjoitetaan 
## entisten tilalle, ja palautetaan luku 1. 
## R:n globaalissa ympäristössä ylläpidetään vektoreita metsId, osId sekä listaa RandomEffects,
## joiden kaikkien pituus on sama. 
## Funktio growJakso käyttää siis aina viimeisimpiä ko. metiskälle laskettuja satunnaisvaikutuksia
## ja osaa poimia ne oikeasta kohtaa listaa noiden metsId ja osId vektorien perusteella. 
##
## growJakso
## kasvattaa jakostunnuksia annettuun ikään. 
##
## generoiKuvauspuut
## generoi recoveryllä kuvauspuut ositteelle, jolta tunnetaan funktion growJAkso ennustamat tunnukset
##
## addHD
## lisää pituudet tai läpimitat generoiduille kuvauspuille riippuen siitä, kummat puuttuvat. 

RandomEffects<-list()
metsId=c()
osId=c()


## satunnaisvaikutusten laskenta
## Input on numeerinen vektori, jonka alkiot ovat järjestyksessä
## 1: käytettävä malli (1, 2 tai 3 puulajin mukaan), 2: metsikköid, 3: osite-id, 
## 4-18: ositteen muutujia, joista puuttuvat annettu negatiivisina,
## 19-25: virheet
predictRandomEffectsJaksomalliWrapper<-function(inputLen,input) {
    model<-input[1]   # millä mallilla lasketaan (1: mnnyn, 2: kuusen, 3:koivujen)
	metsid<-input[2]  # metsid ja osid: R:n sisäinen tieto jolla varmistetaan että ei ennusteta väärän metisiköm  
	osid<-input[3]    # ja ositteen satunnaisvaikutuksilla.
	input[input<0]<-NA  # Inputissa puuttuvat koodattu negtiivisilla arvoilla
	nyt<-data.frame(DDY=input[4],                     # Lämpösumma 1980-luvulla, arvo 700-1400
                    T=input[5],                       # Ositteen ikä, vuotta
					kasvup=input[6],                  # Kasvupaikka, integer 1-9
					wet=input[7],                     # Märkyys: dat$wet<-as.numeric(dat$sois >= 2 |dat$maankas == 2 | dat$maankas == 3)
					muokattu=input[8],                # dat$muokattu<-as.numeric(dat$auraus == 1 | dat$maankas == 4 | dat$maankas==5)
                    synty=input[9],                   # syntytapa, arvot 1-3
					Npros=input[10],                  # Ositteen osuus kokonaisrunkoluvusta, 0-1
					recent=c(FALSE,TRUE)[input[11]+1],  # Halutaanko kasvattaa sekava-aineiston mukaisesti
	# Mittaustiedot. Puuttuvat tulevat NA:na kosak yllä ne udelleenkoodattin niin
					Gos=input[12],                    # Ositteen ppa, m2/ha                    
					Nos=input[13],                    # Ositteen runkolukum kpl/ha
					DA=input[14],                     # Ositteen aritmeettinen keskiläpimitta, cm 
					DGM=input[15],                    # Ositteen ppa:lla painotettu keskiläpimitta, cm
					HA=input[16],                     # Ositteen aritmeettinen keskiläpimitta, m
					HGM=input[17],                    # Ositteen ppa:lla painotettu keskipituus, m                   
					HDOM=input[18])                   # Ositteen valtapituus, m
			
  #  print(nyt) # tarkistustulostus
    merr<-data.frame(Gos=input[19],                   # Muuttujien mittausvirheiden variaatiokertoimet, 0-1, Gos, ..., HDOM kuten yllä. 
                     Nos=input[20],
                     DA=input[21],
                     DGM=input[22],
                     HA=input[23],
                     HGM=input[24],
					 HDOM=input[25])
  #  print(merr) # tarkistuttulostus
	metss<-.GlobalEnv[["metsId"]]
	osits<-.GlobalEnv[["osId"]]
	if (!(any(metss==metsid&osits==osid))) {
        .GlobalEnv[["metsId"]]<-c(.GlobalEnv[["metsId"]],metsid)
        .GlobalEnv[["osId"]]<-c(.GlobalEnv[["osId"]],osid)
		.GlobalEnv[["RandomEffects"]][[length(.GlobalEnv[["metsId"]])]]<-predictRandomEffectsJaksomalli(model= models[[model]],meas=nyt,measurementError=merr)    
		return<-2
		} else {
        index<-(1:length(.GlobalEnv[["metsId"]]))[.GlobalEnv[["metsId"]]==metsid&.GlobalEnv[["osId"]]==osid]
        .GlobalEnv[["RandomEffects"]][[index]]<-predictRandomEffectsJaksomalli(model= models[[model]],meas=nyt,measurementError=merr)
		return<-1
        }
	return
    #    list(metsid, osid, )
    }

## testi
#myInput<-c(1,1000,1,1122,1,2,0,0,3,1,1,-1,2000,-1,-1,-1,0.1,-1,0.32,0.8,0.235,0.196,0.2,0.154,0.154)
#predictRandomEffectsJaksomalliWrapper(length(myInput),myInput)
#myInput2<-c(1,1001,1,1122,1,2,0,0,3,1,1,-1,2000,-1,-1,-1,0.1,-1,0.32,0.8,0.235,0.196,0.2,0.154,0.154)
#predictRandomEffectsJaksomalliWrapper(length(myInput2),myInput2)
## päivitetään metsikän 1001 satunnaisvaikutukset
#myInput3<-c(1,1001,1,1122,1,2,0,0,3,1,1,-1,3000,-1,-1,-1,0.1,-1,0.32,0.8,0.235,0.196,0.2,0.154,0.154)
#predictRandomEffectsJaksomalliWrapper(length(myInput3),myInput3)

predictGrowthJaksomalliWrapper<-function(inputLen,input) {
    model<-input[1]   # millä mallilla lasketaan (1: m'nnyn, 2: kuusen, 3:koivujen)
    metsid<-input[2]  # metsid ja osid: R:n sisäinen tieto jolla varmistetaan että ei ennusteta väärän metisiköm  
    osid<-input[3]    # ja ositteen satunnaisvaikutuksilla.
    kohta<-data.frame(DDY=input[4],             # Lämpösumma 1980-luvulla, arvo 700-1400
                      T=input[5],                       # Ositteen ikä, vuotta
                      kasvup=input[6],                  # Kasvupaikka, integer 1-9
                      wet=input[7],                     # Märkyys: dat$wet<-as.numeric(dat$sois >= 2 |dat$maankas == 2 | dat$maankas == 3)
                      muokattu=input[8],                # dat$muokattu<-as.numeric(dat$auraus == 1 | dat$maankas == 4 | dat$maankas==5)
                      synty=input[9],                   # syntytapa, arvot 1-3
                      Npros=input[10],                  # Ositteen osuus kokonaisrunkoluvusta, 0-1
                      recent=c(FALSE,TRUE)[input[11]+1])  # Halutaanko kasvattaa sekava-aineiston mukaisesti
    index<-(1:length(.GlobalEnv[["metsId"]]))[.GlobalEnv[["metsId"]]==metsid&.GlobalEnv[["osId"]]==osid]
    if (length(index)==1) { 
       RanEf<-.GlobalEnv[["RandomEffects"]][[index]]
	   predType<-1
       } else {
       RanEf<-predictRandomEffectsJaksomalli(model)
	   predType<-2
	   } 
	# PAlautetaan vektori, jossa on 
	# 1. Ennusteen tyyppi (1=satunnaisvaikutuksia on käytetty, 2 ei ole käytetty)
	# 2. Ositteen ppa, m2/ha                    
	# 3. Ositteen runkolukum kpl/ha
	# 4. Ositteen aritmeettinen keskiläpimitta, cm 
	# 5. Ositteen ppa:lla painotettu keskiläpimitta, cm
	# 6. Ositteen aritmeettinen keskiläpimitta, m
	# 7. Ositteen ppa:lla painotettu keskipituus, m                   
	# 8. Ositteen valtapituus, m
    c(predType,as.numeric(predictGrowthJaksomalli(new=kohta,model=models[[model]],bpred=RanEf)))
    }

#pred1<-pred2<-c()
#for (i in 1:20) {
#    myInput3New<-c(1,1003,1,1122,1+i,2,0,0,3,1,1) # malli, metsikkö, osite, selittäjät. 
#    pred1<-rbind(pred1,predictGrowthJaksomalliWrapper(length(myInput3New),myInput3New))
#	myInput4New<-c(1,1001,1,1122,1+i,2,0,0,3,1,1) # malli, metsikkö, osite, selittäjät. 
#	pred2<-rbind(pred2,b<-predictGrowthJaksomalliWrapper(length(myInput4New),myInput4New))
#    }

	
## palautetaan vektori jossa 
# alkio 1 kertoo generoitiinko pituus- (0) vai läpimittajakauma (1)
# alkio 2 kertoo montako kuvauspuuta generoitiin (n)
# alkiot 3,...,n+2: puiden läpimitat (jos 1. alkio on 1) tai pituudet (jos 1. alkio on 0)
# alkiot n+3,...,2n+2: puiden lukumäärät (kpl/ha).
generoiKuvauspuutRecovWrapper<-function(inputlen,input) {
    n<-input[1]                            # montako kuvauspuuta
    tapa<-c("dcons","fcons","fixw")[input[2]]   # 1: dcons (tasavälein), 2: fcons (sama frekvenssi kaikille), fixw (fiksattu luokkaleveys)
	draja<-input[3]                             # tätä pienemmät pituusjakauman kautta 
    minlkm<-input[4]                            # jos läpimittaluokan runkoluku on tätä pienempi, luokkaa ei generoida. 
	minshape<-input[5]                          # Weibull.jakauman muotoparametrin alaraja. 
	width<-input[6]                             # luokkaleveys kun type=3 (fixw)
	puusto<-data.frame(Gos=input[7],                    # Ositteen ppa, m2/ha                    
			           Nos=input[8],                    # Ositteen runkolukum kpl/ha
					   DA=input[9],                     # Ositteen aritmeettinen keskiläpimitta, cm 
					   DGM=input[10],                    # Ositteen ppa:lla painotettu keskiläpimitta, cm
					   HA=input[11],                     # Ositteen aritmeettinen keskiläpimitta, m
					   HGM=input[12],                    # Ositteen ppa:lla painotettu keskipituus, m                   
					   HDOM=input[13])                   # valtapituus, m
    sol<-generoi.kuvauspuut.recov(puusto,n,tapa,draja,minlkm,minshape,width) 
	if (attributes(sol)$iso) {
	   c(nrow(sol),as.numeric(attributes(sol)$iso),malli=-1,Gos=-1,DGM=-1,HGM=-1,G=-1,N=-1,DDY=-1,sol$lpm,sol$lkm0)
       } else {
       c(nrow(sol),as.numeric(attributes(sol)$iso),malli=-1,Gos=-1,DGM=-1,HGM=-1,G=-1,N=-1,DDY=-1,sol$h,sol$lkm0)
	   }
    }

#inputGenkp<-c(20,1,5,1,3,0,b[-1])	
#inputAddHD<-unname(generoiKuvauspuutRecovWrapper(length(inputGenkp),inputGenkp))
#inputAddHD[3:9]<-c(1,10,10,10,10,1000,1000)

# input: vektori joka on tullut ulos funktiolta generoiKuvauspuutRecowWrapper,
# mutta johon puuttuvat arvot (puulaji jonka mallia käytetään, Gos, DGM, HGM, G, N, ja DDY) on lisätty.  
# output on vektori, joissa on joko puuiden ennuistetut pituudet tai läpimitat. 

addHDWrapper<-function(inputlen,input) {
        n<-input[1]
		iso<-c(FALSE,TRUE)[input[2]+1]
		malli<-input[3]
        kuvauspuut<-data.frame(Gos=input[4],
                               DGM=input[5],
							   HGM=input[6],
							   G=input[7],
							   N=input[8],
							   DDY=input[9],
							   lpm=rep(NA,n),
							   h=rep(NA,n))
        if (iso) {
           kuvauspuut$lpm<-input[10:(10+n-1)]
           } else {
           kuvauspuut$h<-input[10:(10+n-1)]   
		   }
       kuvauspuut<-addHD(kuvauspuut,hmalli=malli)
	   if (iso) {
          kuvauspuut$h 
          } else {
          kuvauspuut$lpm  
		  }
	   } 
		
#addHDWrapper(length(inputAddHD),inputAddHD)