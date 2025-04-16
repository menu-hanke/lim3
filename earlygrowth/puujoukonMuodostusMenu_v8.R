# TODO: Add comment
# 
# Author: Lauri Meht�talo 21.6.2023
# Muutos 21.6. 
# - skaalataan jakaumasta lasketut ppa:t uudelleen, jotta 
#   Weibull-jakauman paksu h�nt� ei tiputa pohjapinta-alaa. 
#   korjaus muuttaa tuloksia vain metisk�iss� joissa on tosi leve� kokojakauma. 
# - jos tapa on fcons, ensimm�isen l�pimittaluokan yl�rajaksi pakotetaan v�hint��n 1 cm
#   jotta runkoluku ei nouse mahdotomaksi.
# - Weibull poimnita omaan funktioonsa, koska samaa proseduuria tarvitaan myös recoevryn yhteydessä. 
#   Outputista tiputettiin samalla pois integroimallalla lasketut kuvauspuiden runkoluvut. 
# 6.10.2023
#  1. Kuvauspuiden poiminta weibull-jakaumasta omassa funktiossaan, koska samaa proseduuria tarvitaan myös varhaiskehitysmallien recoveryn jälkimainingeissa. 
#  2. Molemmat pituusmallit kaikille kolmelle puulajille on samassa objektissa, jota kutsuu uusi  funktio Hpred2. Se käy läpi mallit prioriteettijärjestyksessä kalibroiden ja kalibroimatta, kunnes saadaan järkevän näköinen pituuskäyrä. Jos mikään malli ei anna järkevää, palautetaan viimeisimmän mallin ennuste ilman kalibrointia, ja palautetun kuvauspuutaulukon attribuuttina palautettava NaslundOK saa arvon FALSE. Attribuutin NaslundOK attribuuttina palautetaan myös tieto käytetystä mallista ja kalibroitiinko vai ei.  
#  3. Jos jonkun Hpred2:lle annetun mallin selittäjiä puuttuu, Hpred2 yrittää listasta seuraavaa mallia (tämä hoitaa pois mm ongelman että joskus kuviotiedoista puuttuu HGM).
#  4. Kokojakauman skaalaus tehdään ensisijaisesti ppa:lla (Gos), mutta jos ppa on 0, käytetään runkolukua (Nos). Käyttäjän on huolehdittava että näistä jompikumpi tai kumpikin on nollaa suurempi eikä ole puuttuva.
#  5. Pienimmän läpimittaluokan yläraja on parametrina, jonka oletusarvon nostin kovakoodatusta 1cm:stä 2 cm:iin. 
#  6. Funktio palauttaa edelleen läpimittaluokkia joiden leveys on alle 1 cm. Minusta se ei ole ongelma, joten annoin sen olla. 
# 12.10. lisättiin funktioon "kuvauspuut.weibull" pienifrekvenssisten luokkien poistaminen 
# 30.8.2024. kuvauspuut.weibull-funktiossa keskipuiden läpimitta on läpimitaluokan puolisuunnikasjakauma-approksimaation odotusarvo. 
# 3.10.2024 Hpred2 -funktion "if (is.na())" ehto muokattu if (all(is.na())) (kaatoi muuten vmi-datan puiden generoinnin)
# 4.10.2024. Lisätty funktioon kuvauspuut.weibull rajoite ositteen kokonaisrunkoluvulle, oletus 2000. Jos ylittyy, niin tiputetaan pienimpiä puita pois.
# 30.10.2024. Lisätty generoi.kuvauspuut -funktiooon uusia parametreja:
#            - mind (oletusarvo 0) ja minshape (oletusarvo 2).
#            - vmi-koalan säteet ja relaskooppikertoimet, joiden oletusarvoina vmi13 arvot. 
###############################################################################

library(stats4)
library(lmfor)

winit<-function(d,minf=1e-6) {
       s<-sd(d)
       if (is.na(s)) s<-0.1
       shape<-20/s
       scale<-mean(d)
       while (min(dweibull(d,shape,scale))<minf) shape<-0.99*shape
       c(shape=shape,scale=scale)
       }


# T�ss� lasketaan skaalaustermi analyyttisesti paitsi 
# alle 4.5 cm:n puille se integroidaan numeerisesti.
# Yo funktiossa sama lasketaan kokonaan numeerisesti,
# jolloin funktiota on helpompi yleist�� muihin tilanteisiin.                   
dVMIweib<-function(d,shape,scale,q=1.5,r1=5.64,r2=9.00,d1=4.5,d2=9.5) {
#	                print(r1)
#					print(d)
                    f<-d^2*dweibull(d,shape,scale)
                    f[d>=d1]<-q*(100*r1/50)^2*dweibull(d[d>=d1],shape,scale)
                    f[d>=d2]<-q*(100*r2/50)^2*dweibull(d[d>=d2],shape,scale)
                    EW<-integrate(function(x) x^2*dweibull(x,shape,scale),0,d1)$value+
                        (pweibull(d2,shape,scale)-pweibull(d1,shape,scale))*q*(100*r1/50)^2+
                        (1-pweibull(d2,shape,scale))*q*(100*r2/50)^2
                    f/EW
                    }


nll.recml.VMI<-function(d,lshape,D,Dtype,trace,minshape,q,r1,r2,d1,d2) {  
	shape<-exp(lshape)+minshape
	if (Dtype=="A") {
		scale<-scaleDMean1(D,shape)
	} else if (Dtype=="B") {
		scale<-scaleDGMean1(D,shape)
	} else if (Dtype=="C") {
		scale<-scaleDMed1(D,shape)
	} else if (Dtype=="D") {
		scale<-scaleDGMed1(D,shape)
	} else stop("Dtype should be any of 'A', 'B', 'C', 'D'")
    if (trace) cat(shape,scale," ")
	nll<-try(-sum(log(dVMIweib(d,shape,scale,q,r1,r2,d1,d2))),silent=TRUE)
	if (class(nll)=="try-error") nll<-Inf
	if (trace) cat(nll,"\n")
	attributes(nll)<-list(parms=c(shape=shape,scale=scale))
	nll
}

#fitRMLVMI2<-function(d,D,Dtype,init=NA,trace=FALSE,minshape=0.05,q=1.5,r1=5.64,r2=9.00,d1=4.5,d2=9.5) {
#             if (is.na(init[1])) init<-winit(d)[1]
#             linit<-log(init-minshape)
#             nll<-function(lshape) nll.recml.VMI(d,lshape,D,Dtype,trace,minshape,q,r1,r2,d1,d2)   
#             if (all(D==d)) {
#                est1<-nll(3)
#                } else { 
#                fail<-Inf
#                attr(fail,"coef")<-c(NA,NA)
#                estim<-function(ini) {
#                       est<-try(mle(nll,start=list(lshape=ini)))
#                       if (class(est)=="try-error") {
#                          est<-fail 
#                          } else {
#                          est<-nll(coef(est))
#                          }
#                       }
#                est1<-lapply(linit,estim)
#                est1<-est1[unlist(est1)==min(unlist(est1))][[1]]
#                }
#             est1
#             }

fitRMLVMI<-function(d,D,Dtype,init=NA,trace=FALSE,minshape,q,r1,r2,d1,d2,shdef) {
             if (is.na(init)) init<-winit(d)[1]
             linit<-log(init-0.01)
             nll<-function(lshape) nll.recml.VMI(d,lshape,D,Dtype,trace,0.01,q,r1,r2,d1,d2) 
             ok<-TRUE  
             if (length(d)==0) {
                est1<-log(shdef-0.01)
                } else if (all(D==d)) {
				print("kukkuluuruu")
                est1<-3
                } else { 
                est1<-try(coef(mle(nll,start=list(lshape=linit))),silent=TRUE)
                if (class(est1)=="try-error") {
                   est1<- -1000
                   ok<-FALSE
                   }
                }
             sol<-nll(max(est1,log(minshape-0.01)))
             attr(sol,"ok")<-ok
             sol
             }
           
Hpred<-function(lpuut,kpuut,malli,m) {
        lpuut$Y<-1    
        muLp<-predict(malli,newdata=lpuut,level=0)    
        ZLp<-model.matrix(malli$modelStruct$reStruct,data=lpuut)  
        D<-getVarCov(malli)
        sigma<-malli$sigma
        delta<-attr(malli$apVar,"Pars")[4]
        if (sum(names(lpuut)=="DDY")) lpuut$invDDY<-1000/lpuut$DDY
        if (sum(names(lpuut)=="HGM")) lpuut$lnHg_Dg_2<-log(lpuut$HGM/lpuut$DGM+2)
        varFix<-sigma^2*model.matrix(as.formula(malli$call[[5]][[2]]),data=lpuut)[,-1]^(2*delta)+diag(ZLp%*%D%*%t(ZLp))
        predHFix<-lpuut$lpm^m/muLp^m+1.3
        predHFixBC<-predHFix+0.5*m*(m+1)*lpuut$lpm^m/muLp^(m+2)*varFix
        lpuut$predHFix<-predHFix
        lpuut$predHFixBC<-lpuut$pred<-predHFixBC
#        ok<-TRUE
        if (nrow(kpuut)>0) {
           if (sum(names(kpuut)=="DDY")) kpuut$invDDY<-1000/kpuut$DDY
           if (sum(names(kpuut)=="HGM")) kpuut$lnHg_Dg_2<-log(kpuut$HGM/kpuut$DGM+2)
           kpuut$Y<-1
           mu<-predict(malli,newdata=kpuut,level=0)
           y<-kpuut$lpm/(kpuut$height-1.3)^(1/m)
           Z<-model.matrix(malli$modelStruct$reStruct,data=kpuut)
           R<-sigma^2*model.matrix(as.formula(malli$call[[5]][[2]]),data=kpuut)[,-1]^(2*delta)
           if (length(R)>1) R<-diag(R)
           b<-D%*%t(Z)%*%solve(Z%*%D%*%t(Z)+R)%*%(y-mu)
           varb<-D-D%*%t(Z)%*%solve(Z%*%D%*%t(Z)+R)%*%Z%*%D
           # ennustet lukupuille
           alpha<-1
           muPlusbLp<-muLp+ZLp%*%b
           # T�m� silmukka varmistaa, ett� kalibrointi ei v��nn� pituusk�yr�� laskevaksi.
           # Edellytt�� ett� lukupuut on jrjestetty nousevasti. 
#           while (!all(lpuut$lpm/muPlusbLp==cummax(lpuut$lpm/muPlusbLp))) {
#                 alpha<-alpha*0.9
#                 muPlusbLp<-muLp+alpha*ZLp%*%b
#                 ok<-FALSE
#                 } 
           varFixRan<-sigma^2*model.matrix(as.formula(malli$call[[5]][[2]]),data=lpuut)[,-1]^(2*delta)+diag(ZLp%*%varb%*%t(ZLp))
           predHFixRan<-lpuut$lpm^m/muPlusbLp^m+1.3
           predHFixRanBC<-predHFixRan+0.5*m*(m+1)*lpuut$lpm^m/muPlusbLp^(m+2)*varFixRan
           lpuut$predHFixRan<-predHFixRan
           lpuut$predHFixRanBC<-lpuut$pred<-predHFixRanBC 
#           lpuut$predHFixRanBC<-lpuut$pred<-predHFixRan 
           }
        attr(lpuut,"ok")<-all(diff(lpuut$pred[order(lpuut$lpm)])>0)
        lpuut
        }
        
# Kutsutaan Hpred-funktiota monilla eri spekseillä
# Kunnes saadaan kasvava ennustekäyrä
# listassa "Mallit" on mallit prioriteettijärjestyksessä
Hpred2<-function(lpuut,kpuut,mallit,m) {
        if (all(is.na(kpuut))) kpuut<-lpuut[-(1:nrow(lpuut)),]
        nmod<-length(mallit)
        ok<-FALSE
        i<-0
        kalib<-TRUE
        while (!ok&(i<nmod)) { # käydään kaikki läpi kalibroiden
              i<-i+1
              res<-try(Hpred(lpuut,kpuut,mallit[[i]],m=m),silent=TRUE)
              if (class(res)!="try-error") ok<-attributes(res)$ok # tämä hoitaa sen että jos HGM puuttuu, mennään simple-malliin
#              cat("yritettiin kalibroimalla mallia",i,"\n")
              }
        if (!ok & nrow(kpuut)>0) { # Jos ei onnistunut kalibroimalla..
           kpuut0<-kpuut[-(1:nrow(kpuut)),]
           kalib<-FALSE
           i<-0
           }
        while (!ok&(i<nmod)) { # käydään kaikki läpi ilman kalibrointia
              i<-i+1
              res<-try(Hpred(lpuut,kpuut0,mallit[[i]],m=m),silent=TRUE)
              if (class(res)!="try-error") ok<-attributes(res)$ok # tämä hoitaa sen että jos HGM puuttuu, mennään simple-malliin
#              cat("yritettiin kalibroimatta mallia",i,"\n")
              }
        attr(attr(res,"ok"),"details")<-list(malli=i,kalib=kalib)
        res
        }
        
# poimii n kapplaetta kuvauspuita painottamattomasta Weibull-jakaumasta   
# palauttaa kuvauspuiden läpimitat ja niiden edustamat runkoluvut
# mind: pienin sallittu läpimittaluokan yläraja   
# minlkm: kuinka monta puuta läpimittaluokassa on vähintään oltava
# jos minlkm=NA, vaaditaan että puita on vähintään 10/n   
# Muutos 2.1.2024. parametriksi dmax (suurimman läpimittaluokan yläraja) 
# ja myös maksimiläpimitan käyttö muuttunut. 
# Muutos 3.9.2024. Lisätty tapa fixw + parametri width
kuvauspuut.weibull<-function(theta,tapa,n=10,G=NA,N=NA,mind=2,minlkm=NA,dmax=100,width=2,nmax=2000) {
      if (is.na(minlkm)) minlkm<-min(1,10/n)
      if (tapa=="dcons") {
         dlim <- seq(qweibull(1e-8,theta[1],theta[2]),min(dmax,qweibull(1-1e-8,theta[1],theta[2])),length=n+1)
         } else if (tapa=="fcons") {
         dlim <- qweibull(seq(1e-8,min(pweibull(dmax,theta[1],theta[2]),1-1e-8),length=n+1),theta[1],theta[2])
         } else if (tapa=="fixw") {
         dl<-qweibull(1e-8,theta[1],theta[2])
		 du<-min(dmax,qweibull(1-1e-8,theta[1],theta[2]))
		 du<-dl+width*(ceiling(du-dl)/width)
         dlim <- seq(dl,du,by=width)		 
		 }
      dlim[-1]<-pmax(mind,dlim[-1]) # ensimm�isen l�pimittaluokan yl�raja v�hint��n mind
      dlim<-pmin(dlim,dmax)
      dlim<-unique(dlim)
      n<-length(dlim)-1
	  flim<-dweibull(dlim,theta[1],theta[2])
	  dala<-dlim[-(n+1)]
	  dyla<-dlim[-1]
	  fdala<-dweibull(dala,theta[1],theta[2])
	  fdyla<-dweibull(dyla,theta[1],theta[2])
      lpm1<-(dala+dyla)/2 # luokan keskikohdat
	  lpm2<-(2/3*dyla+1/3*dala)
	  lpm2[fdala>fdyla]<-(1/3*dyla+2/3*dala)[fdala>fdyla]
	  lpm<-(pmin(fdala,fdyla)*lpm1+abs(fdala-fdyla)*lpm2)/pmax(fdala,fdyla)
      if (!is.na(G)) { # Jos ppa on annettu, skaalatan sillä
         g0<-diff(pgamma((dlim/theta[2])^theta[1],2/theta[1]+1)) # luokkien suhteelliset pohjapinta-alat
         g<-g0/(sum(g0)) # uudellenskaalataan luokkien suhteelliset ppa_t, koska
                         # joissain tapauksissa weibullin pitkän hännän vuoksi summa ei ole 1. 
         lkm<-40000*G*g/(pi*lpm^2) # runkoluku=luokan ppa jaettuna keskipuun ppa:lla
         keep<-lkm>=minlkm
         lkm<-lkm*sum(g)/sum(g[keep])
         } else if (!is.na(N)) {
         lkm<-N*diff(pweibull(dlim,theta[1],theta[2]))
         keep<-lkm>=minlkm
         lkm<-lkm*sum(lkm)/sum(lkm[keep])
         } else {
         stop("Skaalausta varten on annettava joko G tai N")
         }
      # tiputetaan läpimittaluokat joissa oli liian vähän puita
      # luokkien runkoluvut oli aiemmin uudelleenskaalattu niin, että
      # annettu kokonaismäärä täyttyy 
      sol<-data.frame(lpm=lpm[keep],                  # kuvauspuiden läpimitat
                 lkm0=lkm[keep])                  # kuvauspuiden edustamat runkoluvut
      # hävityksen kauhistus    
      sol$lkm<-diff(c(0,pmin(cumsum(sol$lkm0[nrow(sol):1]),nmax)))[nrow(sol):1]
	  sol
  }
        

# Sis��n menee ositerivi (yhden rivin data.frame) ja ositteen puut sis�lt�v� data frame. 
# Ositeriviss� on oltava ainakin seuraavat muuttujat
# DGM - ppa-mediaanipuun l�pimitta
# HGM - ppa-mediaanipuun pituus (jos k�yt�ss� HDmod. Jos on k�yt�ss� HDsimple, HGM:�� ei tarvita)
# G - kokonaisppa m2/ha
# Gos - ositteen PPA m2/ha
# DDY - l�mp�summa
# spe - ositteen puulaji
# Puutiedoissa on oltava
# lpm - puiden l�pimitat, cm
# height - koepuiden mitatut pituudet metrein� (lukupuille height=NA)
# Lis�ksi annetaan argumenttina
# n - kokonaisluku, montako kuvauspuuta halutaan
# tapa - miten kuvauspuut poimitaan: "dcons" vako l�pimittaluokan leveys 
#                                    "fcons" vakio luokan runkoluku
#                                    "fixw"  vakio luokkaleveys. 
# HDmod - Siipilehdon ja kankaan pituusmallit listana j�rjesteyksess� m�, ku, ko
#         Kukin malli voi olla lista malleja prioriteettijärjestyksessä
#         Jos ensimmäinen malli ei anna nousevaa käyrää, yritetään seuraavaa.
# hmalli - kokonaisluku, mink� puulajin pituusmallia ositteelle k�ytet��n (1, 2 tai 3)
# shdef - Weibull-jakauman muotoparametrin arvo (positiivinen reaaliluku). K�ytet��n jos nrow(lukupuut)=0. 
#         Mit� pienempi arvo, sit� leve�mpi jakauma. 
# shinit: muotoparametrin alkuarvaus
# width: luokkaleveys kun tapa=fixw
# minshape: muotoparametrin minimiarvo
# mind: pienimmän läpimittaluokan ylärajan minimiarvo
# q, r1, r2, d1, d2: vmi_koelaan käytetyt säteet, pienten puiden relaskooppikerroin sekä läpimittarajat. Oletuksena VMI13-mukaiset arrvot.  

generoi.kuvauspuut<-function(ositerivi,lukupuut,n,tapa,HDmod.=HDmod,hmalli=1,shdef=5,shinit=0.1,width=2,minshape=2,mind=0,q=1.5,r1=4,r2=9.00,d1=4.5,d2=9.5) {
   # kokojakauma
   sol<-fitRMLVMI(lukupuut$lpm,ositerivi$DGM,Dtype="D",init=shinit,trace=FALSE,minshape=minshape,shdef=shdef,q=q,r1=r1,r2=r2,d1=d1,d2=d2)
   theta<-attr(sol,"parms")
#   print(theta)
#   Nos<-40000/pi*ositerivi$Gos/(theta[2]^2*gamma(2/theta[1]+1)) # ositteen runkoluku
#   if (tapa=="dcons") {
#      dlim <- seq(qweibull(1e-8,theta[1],theta[2]),qweibull(1-1e-8,theta[1],theta[2]),length=n+1)
#      } else if (tapa=="fcons") {
#      dlim <- qweibull(seq(1e-8,1-1e-8,length=n+1),theta[1],theta[2])
#      }
#   dlim[-1]<-pmax(1,dlim[-1]) # ensimm�isen l�pimittaluokan yl�raja v�hint��n 1cm
#   dlim<-pmin(dlim,100)
#   dlim<-unique(dlim)
#   n<-length(dlim)-1
#   lpm<-(dlim[-1]+dlim[-(n+1)])/2
#   g0<-diff(pgamma((dlim/theta[2])^theta[1],2/theta[1]+1))
#   g<-g0/(sum(g0)) # uudellenskaalataan luokkien suhteelliset ppa_t, koska
#                   # joissain tapauksissa weibullin pitk�n h�nn�n vuoksi summa ei ole 1. 
#   lkm2<-40000*ositerivi$Gos*g/(pi*lpm^2)
   if (ositerivi$Gos>0) { # Jos PPA on suurempi kuin nolla, skaalataan sillä
      kuvauspuut<-kuvauspuut.weibull(theta,tapa,n=n,G=ositerivi$Gos,width=width,mind=mind)
      } else { # muutoin skaalataan runkoluvulla
      kuvauspuut<-kuvauspuut.weibull(theta,tapa,n=n,N=ositerivi$Nos,width=width,mind=mind)
      }
   kuvauspuut<-merge(cbind(ositerivi,osite=1),cbind(kuvauspuut,osite=1))                                      # kuvauspuiden laskennalliset runkoluvut
                                
   if (!all(is.na(lukupuut$height))) {
      koepuut<-merge(cbind(ositerivi,osite=1),cbind(lukupuut[!is.na(lukupuut$height),],osite=1))
      } else {
      koepuut<-lukupuut[!is.na(lukupuut$height),]
      }
   pit<- Hpred2(kuvauspuut,koepuut,mallit=HDmod.[[hmalli]],m=c(2,3,2)[hmalli])  # kuvauspuiden pituudet
   kuvauspuut$h <- pit$pred
#   cat(ositerivi$Gos,sum(pi*lpm^2/40000*lkm2),"\n") ppa:n tarkistus
   kuvauspuut
   attr(kuvauspuut,"WeibullOK")<-attr(sol,"ok")
   attr(kuvauspuut,"NaslundOK")<-attr(pit,"ok")
   attr(kuvauspuut,"Wpar")<-theta
   kuvauspuut
   }
   
   

