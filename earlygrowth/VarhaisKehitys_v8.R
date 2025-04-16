# TODO: Add comment
# 
# Author: 03191657
# Laurin sovittamat sekamalliversiot 8.12.2023
# KOrjattu Reetan esittämien ongelmatapausten pohjalta 4.1.2024
# Reetan ongelmatapaukset 18.1.2024 korjattu 8.3.2024. 
# 21.3.2024. Malleissa käytössä vain Npros. koodi muuttunut vain ohejden osalta. 
# 15.8.2024. GrowJakos-funktio jaettu  kolmeen funktioon, joiden tehtävät: 
# 1. satunnaisvaikutusten ennustaminen,
# 2. kasvun ennustaminen
# 3. kuvauspuiden muodostus. 
# Lisäksi recoveryskriptit on muokattu uuteen uskoon niin, että muotopareamerin rajoituksilla estetään
# liian suuret läpimitat. SAmalla koodi on uuudelleenjärjestetty funktioihin 
# recovd, recovh ja generoi.kuvauspuut.recov. 
# attribuuttina plautetaan tieto miten recovery on tehty. 
# 3.9.2024. Lisätty kuvauspuiden poimimiseen optio fixw
###############################################################################

library(Matrix)

# Jaksotason kasvumalli
# Input: data frame new, johon funktio lisää seuraavat muuttujat
# - Gos: ositteen ennustettu PPA, m2/ha, 
# - Nos: ositteen ennustettu Runkoluku, 1/ha
# - DA: aritmeettinen keskiläpimitta, cm
# - DGM: ppa:lla painitettu keskiläpimitta, cm
# - HA: aritmeettinen keskipituus, m
# - HGM: PPA:lla painotettu keskipituus, m
# - HDOM: valtapituus, m 
# input-datassa pitää olal sauraavat muuttujat
# - DDY:   lämpösumma
# - T:     ikä
# - kasvup:kasvupaikka (numeerinen, VMI-luokittelu) 
# - sois: soistuneisuustieto (0/1) 
# - maankas: tieto maankäsitelystä, 0 ei, 1 lannoitus, 2 ojitus, 3 lann+oji, 4 muokkaus, 5 lann+muok, 6 maaluokka muutos, 7 muu
# - auraus: onko aurattu (0: ei, 1:on)
# - synty: syntytapa (1, luontainen, 2: kylvetty, 3:istutettu)
# - Npros: Jakson osuus metsikön kokonaisrunkoluvusta simuloinnin alkuhetkellä (0-1)
# - recent: TRUE tai FALSE, oletetaanko puiden kehittyvän uusimpien SEKAVA-datojen mukaisesti. 
#           Käytössä vain kuusen mallissa. Kuvannee paremmin nykyisten istutuskuusikoiden varhaiskehitystä, mutta ko. malleilla 
#           varttuneiden metsien (yli 20 v) kehitys erityisesti PPA:n osalta on epärealistinen.  
# model: varhaiskehitysmalliobjekti, joka on tuotettu 
# R-skripti fitModels.R tuottaa tällaisten mallien listan. 
# Argumenttina voidaan antaa esim ko. listan elementti pine, spruce tai birch. 
# 
# model on lista, joka sisältää elementit: 
# beta: kiinteän osan kertoimet matriisissa, jonka rivit on nimetty niin että nistä saa muodostetua 
# R-formulan ja sarakkeina vastemuuttujat samanlaisessa muodossa. 
# D: metsikkävaikutusten varianssitieto listassa, jossa alkiot
# - var: varianssi-kovarianssimatriisi
# - cor: korrelaatiomatriisi 
# - formula: lista satunnaisosien formuloista siinä muodossa kun se on annettu lme-funktiolle
#            listasa yksi alkio jokaista beta-matriisin saraketta kohti. 
# - vektori jossa kukin vastemuuttuja on toistettu yhtämonta kertaa kuin ko. vastemuuttujan mallissa 
#   on metsikkävaikutuksia. 
# R: jäännösvirheen varianssitieto
# - cor: jäännösten korrelaatiomatriisi mallien välisille virheille (8*8)
# - sigma: variansifunktion skaalaustermi
# - delta: varPower-muotisen varianssifunktion potenssi
# - v: lsita varianssifunktion selittäjät merkkijonona, josta voi muodostaa  R-formulan
#  
# 
# Data frame meas sisältää vastemuuttujien kalibrointimittaukset. 
# datassa on oltava samannimiset sarakkeet kuin on put-datassa. 
# Muuttujissa Gos, Nos, DA, DGM, HA, HGM ja HDOM annetaan kalibrointimitaukset. 
# Muuttuja jota ei tunneta, annetaan puuttuvana (NA) 
# Kalibrointimitauksia voi ola usealta eri ajankohdalta. Jos näin ona, datassa on useita rivejä. 
# Mittausten välissä ei ole saanut tapahtua hakkuita. 
# 
# measurementError: Yhden rivin data frame, jossa on kalibrointimittausten suhteelliset 
# mittausvirheiden variaatiokertoimet. (0.1-> mittauksen keskihajonta 10% mitatusta arvosta).
#   
# - models sisältää tarvittavat jaksomallit listana, sovitettu mallilista tiedostosta Jaksomallit80.RData
# - which skalaari, joika kertoo monettako mallia y, listasta käytetään kullekin jaksolle (1=männyn, 2=kuusen, 3=koivun malli)  
#   Numero 1 viittaa mäntydatasta estimoituun malliin, numero 2 kuusidatasta ja numero 3 koivudatasta estimoituun malliin. 
# 
# inputs-listassa annetuissa datoissa pitää olla sama määrä rivejä 
# ja niiden pitää vastata samaa kalenterivuotta, mutta iät voi vaihdella, koska 
# kuvauspuiden laskennassa hyödynnetään ennustettujen jaskon ppa:n ja runkoluvun summaa. 
# n: montako kuvauspuuta tuotetaan per jakso, 
# tapa: kuvauspuiden valintatapa "dcons" tai "fcons"
# draja: jos DGM tai DA on tätä rajaa pienempi, 
# kuvauspuille tuotetaan pituudet weibull-jakaumasta, joka toteuttaa jakoslle ennnustetun 
# valtapituuden ja keskipituuden. Muussa tapauksessa kuvauspuut muodostetaan läpimittaan
# perustuvan recoveryn avulla. parametrin draja on oltava nollaa suurempi. 
predictRandomEffectsJaksomalli<-function(model,meas=NA,measurementError=NA) {
   if (!all(is.na(meas))) {  # jos joku vastemuuttuja on mitattu, kalibroidaan mallia
      nmods<-ncol(model$beta)
      modForm<-terms(as.formula(paste(c("~1",rownames(model$beta)[-1]), collapse=" + ")),keep.order=TRUE) # mallin lauseke 
      #respForm<-as.formula(paste(c("~-1",colnames(beta)[-1]), collapse=" + ")) 
      betavek<-as.vector(model$beta)
      sd<-sqrt(diag(model$D$var))
      D<-diag(sd)%*%model$D$cor%*%diag(sd)
      meas$Dk<-2+1.25*meas$DA
      meas$DGk<-2+1.25*meas$DGM
      responses<-colnames(model$beta)
      respForm<-as.formula(paste(c("~-1",colnames(model$beta)), collapse=" + "))
      meas2<-meas[,c("Gos","Nos","Dk","DGk","HA","HGM","HDOM")]
      missing<-is.na(meas2)
      meas2[missing]<-1000 # laitetan puuttuvien tilalle numerot että R ei tiputa niiden rivejä pois
      yo<-as.numeric(model.matrix(respForm,data=meas2))[!missing,drop=FALSE]
      if (length(measurementError)>1) {
         measErrVar<-diag((measurementError[!missing]*yo)^2,ncol=sum(!missing)) 
         } else {
         measErrVar<-matrix(0,ncol=sum(!missing),nrow=sum(!missing))
         }
      Xo<-kronecker(diag(nmods),model.matrix(modForm,data=meas))[!missing,,drop=FALSE] # mittausten kiinteän osan mallimatriisi
      Zo<-as.matrix(bdiag(lapply(1:nmods,function(x) model.matrix(model$D$formula[[x]],data=meas))))[!missing,,drop=FALSE]
      Ro<-diag(as.numeric(sapply(1:nmods,function(i) model$R$sigma[[i]]^2*model.matrix(as.formula(model$R$v[[i]]),data=meas)^(2*model$R$delta[[i]]))))[!missing,!missing,drop=FALSE]
      b<-D%*%t(Zo)%*%solve(Zo%*%D%*%t(Zo)+Ro+measErrVar)%*%(yo-Xo%*%betavek)
      varb<-D-D%*%t(Zo)%*%solve(Zo%*%D%*%t(Zo)+Ro+measErrVar)%*%Zo%*%D # tätä ei käytetä
      bpred<-list(b=b,varb=varb)
      } else {
      bpred<-list(b=NA,varb=NA)
      }
   bpred
   }
	 
predictGrowthJaksomalli<-function(new,model,bpred) {
   # lisätään 5v havainto lopusa tehtävää interpolointia varten
   new<-rbind(new[1,],new)
   new$T[1]<-5
   nmods<-ncol(model$beta)
   modForm<-terms(as.formula(paste(c("~1",rownames(model$beta)[-1]), collapse=" + ")),keep.order=TRUE) # mallin lauseke 
   betavek<-as.vector(model$beta)
#   sd<-sqrt(diag(model$D$var))
#   D<-diag(sd)%*%model$D$cor%*%diag(sd)
   
   X0<-kronecker(diag(nmods),model.matrix(modForm,data=new))
   Z0<-bdiag(lapply(1:nmods,function(x) model.matrix(model$D$formula[[x]],data=new)))
   mu0<-matrix(X0%*%betavek,ncol=nmods)
   sdFix<-sqrt(#matrix(diag(Z0%*%D%*%t(Z0)),ncol=8)+
          sapply(1:nmods,function(i) model$R$sigma[[i]]^2*model.matrix(as.formula(model$R$v[[i]]),data=new)^(2*model$R$delta[[i]])))
   val0<-sapply(1:nmods,function(i) model$back[[i]](mu0[,i]))
   val1<-0.5*(sapply(1:nmods,function(i) model$back[[i]](mu0[,i]-sdFix[,i]))+
         sapply(1:nmods,function(i) model$back[[i]](mu0[,i]+sdFix[,i])))
   if (!is.na(bpred$b[1])) {  # jos satunnaisvaikutukset ennustettiin  
      ytilde<-mu0+matrix(Z0%*%bpred$b,ncol=nmods)
      sdytilde<-matrix(sqrt(pmax(0,#diag(Z0%*%bpred$varb%*%t(Z0))+
         sapply(1:nmods,function(i) model$R$sigma[[i]]^2*model.matrix(as.formula(model$R$v[[i]]),data=new)^(2*model$R$delta[[i]])))),ncol=nmods)
      val2<-sapply(1:nmods,function(i) model$back[[i]](ytilde[,i]))
      val3<-0.5*(sapply(1:nmods,function(i) model$back[[i]](ytilde[,i]-sdytilde[,i]))+
            sapply(1:nmods,function(i) model$back[[i]](ytilde[,i]+sdytilde[,i])))
      } else { 
      val3<-val1
      val2<-NA # tätä käytetään lopussa
      } 
   colnames(val0)<-colnames(val1)<-colnames(val3)<-c("Gos","Nos","DA","DGM","HA","HGM","HDOM")
   val0[,c("DA","DGM")]<-(val0[,c("DA","DGM")]-2)/1.25
   val1[,c("DA","DGM")]<-(val1[,c("DA","DGM")]-2)/1.25
   if (!is.na(val2)[1]) {
      colnames(val2)<-colnames(val3)
      val2[,c("DA","DGM")]<-(val2[,c("DA","DGM")]-2)/1.25
      }
   val3[,c("DA","DGM")]<-(val3[,c("DA","DGM")]-2)/1.25
   # poistetaan negatiiviset ennusteet
   val0<-pmax(val0,0) # kiinteän osan ennuste ilman harhankorjausta
   val1<-pmax(val1,0) # kiinteän osan ennuste 2-pisteharhankorjauksella
   val2<-pmax(val2,0) # kiinteä + satunaninen, ei harjhankorjausta, jos ei kalibrointimittausta niin sama kuin val0. 
   val3<-pmax(val3,0) # kiinteä + satunnainen, harhankorjaus mukana, jos ei ole kalibrointimittausta niin sama kuin val1. 
   # interpoloidaan alle 5v ennusteet muille kuin runkoluvulle. 
   if (min(new$T)<5) {
      val0[new$T<5,-2]<-matrix(rep(new$T[new$T<5],each=nmods-1),ncol=nmods-1,byrow=TRUE)/5*matrix(val0[1,-2],byrow=TRUE,ncol=nmods-1,nrow=sum(new$T<5))
      val1[new$T<5,-2]<-matrix(rep(new$T[new$T<5],each=nmods-1),ncol=nmods-1,byrow=TRUE)/5*matrix(val1[1,-2],byrow=TRUE,ncol=nmods-1,nrow=sum(new$T<5))
      if (!is.na(val2[1])) val2[new$T<5,-2]<-matrix(rep(new$T[new$T<5],each=nmods-1),ncol=nmods-1,byrow=TRUE)/5*matrix(val2[1,-2],byrow=TRUE,ncol=nmods-1,nrow=sum(new$T<5))
      val3[new$T<5,-2]<-matrix(rep(new$T[new$T<5],each=nmods-1),ncol=nmods-1,byrow=TRUE)/5*matrix(val3[1,-2],byrow=TRUE,ncol=nmods-1,nrow=sum(new$T<5))
      }
   # palautetaan kalibroidut harhakorjatut ennusteet
   # muut palautetaan attribuutteina
   result<-data.frame(val3[-1,,drop=FALSE])
   if (is.na(val2[1])) {
      attr(result,"cal.nobc")<-val2
      } else {
      attr(result,"cal.nobc")<-data.frame(val2[-1,])
      }
   attr(result,"nocal.bc")<-data.frame(val1[-1,])
   attr(result,"nocal.nobc")<-data.frame(val0[-1,])
   result
   }


# Tällä funktiolla generoidaan kuvauspuut 
# funktiossa growJaksot 
# recovery lmfor:recweib
# pituuksien ennustaminen Siipilehdon ja kankaan malleilla (tiedostosta puujoukonmuodostusMenu_vX.R)

recweibh<-function(HA,HDOM,N,Npros=1,shmin=3) {
          fn1<-function(theta) exp(theta[2])*gamma(1+1/exp(theta[1]))-HA
          fn2<-function(theta) {
               qweibull((N/Npros-100)/(N/Npros),exp(theta[1]),exp(theta[2]))-HDOM
               }
          fnlist<-list(fn1,fn2)
          momrec<-try(NRnum(log(c(shmin,HA)),fnlist),silent=TRUE)
		  soltype<-3
          if (class(momrec)!="try-error") {
			  sol<-list(shape=exp(momrec$par)[1],scale=exp(momrec$par)[1],HA=HA,HDOM=HDOM,N=Npros,soltype=soltype)
			  if (sol$shape<shmin) soltype<-4
              } else {
              soltype<-4
              } 
          if (soltype==4) {
			  sol<-list(shape=shmin,scale=HA/gamma(1+1/shmin),HA=HA,HDOM=HDOM,N=Npros,soltype=soltype)
              }
          sol
          }
		   
# recovery läpimittatunnisten perusteella
# D on joko aritmeettinen (Dtype="A") tai ppa:lla painotettu (Dtype="B") keskiläpimitta 
# Jos yhtälä ei ole ratkeava tai shape-parametrin arvoksi tulee alle shmin,
# Palautetaan ratkaisu, joka toteuttaa annetun keskiläpimitan ja muotoparametri
# saa arvon shmin. Tällöin ratkaisu ei toteuta annettua ppa/runkolukusuhdetta. 
recweibd<-function(G,N,D,Dtype,shmin=2) {
   sol<-try(recweib(G,N,D,Dtype),silent=TRUE)
   soltype<-1
   if (class(sol)!="try-error") {
      if (is.na(sol$shape)) {
         soltype<-2
	     } else if (sol$shape<=shmin) {
         soltype<-2
         }
      } else {
      soltype<-2
      }
   if (soltype==2) {
      sol=list(shape=shmin,scale=NA,G=G,N=N,D=D,Dtype=Dtype,val=0)
	  if (Dtype=="A") sol$scale=scaleDMean1(D,shmin)
	  if (Dtype=="B") sol$scale=scaleDGMean1(D,shmin)
     }
   sol$soltype<-soltype
   sol
   }

# LM 4.1.2024. Ei ennusteta pituuksia tässä vaiheessa
# LM 15.8.2024. Lisätty muotoparametrirajoituksia yms, ks tiedoston alun selitykset. 
# LM 3.9.2024. Lisätty optio poimia kuvauspuut tasavälein. Tällöin pituuskuokkien leveys on width/4. 
generoi.kuvauspuut.recov<-function(puusto,n=10,tapa="dcons",draja=5,minlkm=1,minshape=3,width=2) {
#             if (!all(toteuttavat==FALSE)) {   # jos joku rivi toteuttaa kuvausuuehdon,
#              sel<-min((1:length(toteuttavat))[toteuttavat]) 
#              eka<-strata[sel,]  # valitaan niistä ensimmäinen
#   print(c(puusto[,c("Gos","Nos","DGM")],dlim))
   DGok<-puusto$Gos/(pi*(puusto$DGM/200)^2)<(puusto$Nos-50)
   DAok<-puusto$Gos/(pi*(puusto$DA/200)^2)>(puusto$Nos+50)
   # ensisijaisesti recovery N,G,DG
   # Toissijaisesti N,G,DA
   # jos ei onnistu niin sitten recovery N,G,DG niin, että muotoparametri on fiksattu minimiinsä 
   iso<-TRUE
   Dtype<-"H"
   if (puusto$DGM<draja||puusto$DA<draja) {
      sol<-recweibh(N=puusto$Nos,H=puusto$HA,HDOM=puusto$HDOM,Npros=puusto$Npros,shmin=minshape)
      iso<-FALSE
      } else if (DGok) {
      Dtype<-"B"
      sol<-recweibd(puusto$Gos,puusto$Nos,puusto$DGM,Dtype="B",shmin=minshape)
      } else if (DAok) {
      Dtype<-"A"
      sol<-recweibd(puusto$Gos,puusto$Nos,puusto$DA,Dtype="A",shmin=minshape)
	  } else {
      Dtype<-"B"
      sol<-recweibd(puusto$Gos,puusto$Nos,puusto$DGM,Dtype="B",shmin=minshape)  
	  }
   if (!iso) {
	   kuvauspuut<-kuvauspuut.weibull(c(sol$shape,sol$scale),tapa=tapa,n=n,N=puusto$Nos,mind=0,dmax=1.3*puusto$HDOM,minlkm=minlkm,width=width/4) # pituusmaksimi 1.3*HDOM 
	   kuvauspuut$h<-kuvauspuut$lpm
	   kuvauspuut$lpm<-NA
	   scaltype="N"
       } else if (puusto$HDOM<8) { 
       # jos HDOM<8 ja puut isoja, skaalataan runkoluvulla, muuten PPA:lla
       # tällä on merkitystä vain jos recovery ei ole ratkennut alkuperäisillä ennusteilla.  
       kuvauspuut<-kuvauspuut.weibull(c(sol$shape,sol$scale),tapa=tapa,n=n,N=puusto$Nos,minlkm=minlkm,width=width)
	   scaltype="N"
       } else {
       kuvauspuut<-kuvauspuut.weibull(c(sol$shape,sol$scale),tapa=tapa,n=n,G=puusto$Gos,minlkm=minlkm,width=width)
	   scaltype="G"
       } # kuvauspuiden laskennalliset runkoluvu
   kuvauspuut<-merge(cbind(puusto,osite=1),cbind(kuvauspuut,osite=1))   
   if (iso) kuvauspuut$h<- NA
   attr(kuvauspuut,"rectype")<-paste(Dtype,sol$soltype,scaltype,sep="")
   attr(kuvauspuut,"sol")<-sol
   attr(kuvauspuut,"iso")<-iso
   kuvauspuut
   }


# Jounin malli, yksiköt epäselvät. 
imputeSmallTreeDBH<-function(h,HA,DA,HDOM,factor=1) {
            dbh<-rep(NA,length(h))
            val<-0.3904+0.9119*log(h[h>1.3]-1)+0.05318*h[h>1.3]-
                      1.0845*log(HA)+0.9468*log(DA+1)-0.0311*HDOM
            dvari<-0.000478+0.000305+0.03199     
            dbh[h>1.3]<-exp(val+dvari/2)
            dbh
            }
            
            
            
# Valkosen malli metsätieteen aikakauskirja 3/1997
imputeSmallTreeDBH<-function(h,factor=1) {
            dbh<-rep(NA,length(h))
            lndi=1.5663+0.4559*log(h[h>1.3])+0.0324*h[h>1.3]
            dbh[h>1.3]<-exp(lndi+0.004713/2)-5
            dbh
            }

# Täydentää funktion "growJakso" tuottamaan kuvauspuulistaan isoille puilel pituudet ja 
# pienille (mutta yli 1.3m) puille läpimitat.
# kuvauspuut on data frame jossa on funktion growJakso palauttamaan data frameen lisätty metiskön 
# kaikkien ositeiden yhteenlasettu ppa muutujaan G ja runkioluku muuttujaan N. 
# lisäksi on lisätty lämpösumma muuttujaan DDY. 
# HDMod on objektissa HDmod_Siipilehto_Kangas_2015.RData oleva pituusmallilista.
# hmalli on integer joka kertoo käytetäänkö männyn (1), kuusen (2), vai koivun (3) pituusmallia.

addHD<-function(kuvauspuut,HDmod.=HDmod,hmalli) {
       if (length(unique(kuvauspuut$Gos))>1) stop("addHD: anna vain yksi osite kerrallaan")
       if (any(is.na(kuvauspuut$h))) kuvauspuut$h[is.na(kuvauspuut$h)]<-Hpred2(kuvauspuut[is.na(kuvauspuut$h),],kpuut=NA,mallit=HDmod.[[hmalli]],m=c(2,3,2)[hmalli])$pred
       factor<-1
       if (any(is.na(kuvauspuut$lpm[kuvauspuut$h>1.3]))) {
          kuvauspuut$lpm[is.na(kuvauspuut$lpm)]<-imputeSmallTreeDBH(kuvauspuut$h[is.na(kuvauspuut$lpm)])
#          while (sum(na.omit(kuvauspuut$lkm*pi*(kuvauspuut$lpm/200)^2))<kuvauspuut$Gos[1]) {
#                 factor<-1.01*factor
#                 kuvauspuut$lpm<-1.01*kuvauspuut$lpm
#                 kuvauspuut$h<-1.01*kuvauspuut$h
#                 }
#          while (sum(na.omit(kuvauspuut$lkm*pi*(kuvauspuut$lpm/200)^2))>kuvauspuut$Gos[1]) {
#                factor<-0.99*factor
#                kuvauspuut$lpm<-0.99*kuvauspuut$lpm 
#                kuvauspuut$h<-0.99*kuvauspuut$h 
#                }
#          print(factor)
          }
       kuvauspuut
       }