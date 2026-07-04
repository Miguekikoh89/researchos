source("tests/certification/helpers.R");require_pkg("seminr");require_pkg("jsonlite");require_pkg("dplyr");require_pkg("openxlsx");source_r("pls_sem_engine.R")
set.seed(701);n<-180;x<-rnorm(n);m<-.65*x+rnorm(n,.0,.7);y<-.25*x+.7*m+rnorm(n,.0,.7);D<-data.frame(x1=.8*x+rnorm(n,.0,.5),x2=.75*x+rnorm(n,.0,.55),x3=.7*x+rnorm(n,.0,.6),m1=.8*m+rnorm(n,.0,.5),m2=.75*m+rnorm(n,.0,.55),m3=.7*m+rnorm(n,.0,.6),y1=.8*y+rnorm(n,.0,.5),y2=.75*y+rnorm(n,.0,.55),y3=.7*y+rnorm(n,.0,.6),sexo=rep(c("F","M"),length.out=n))
f<-tempfile(fileext=".csv");write.csv(D,f,row.names=FALSE);on.exit(unlink(f),add=TRUE)
params<-list(data_path=f,constructs=list(list(name="X",items=c("x1","x2","x3")),list(name="M",items=c("m1","m2","m3")),list(name="Y",items=c("y1","y2","y3"))),paths=list(list(from="X",to="M"),list(from="X",to="Y"),list(from="M",to="Y")),n_boot=1000,bootstrap_seed=1234,advanced_pls=FALSE)
r<-run_pls_sem(params);expect_true(isTRUE(r$success)&&!isTRUE(r$blocked),r$error %||% "PLS bloqueado")
mm<-seminr::constructs(seminr::composite("X",seminr::multi_items("",c("x1","x2","x3"))),seminr::composite("M",seminr::multi_items("",c("m1","m2","m3"))),seminr::composite("Y",seminr::multi_items("",c("y1","y2","y3"))))
sm<-seminr::relationships(seminr::paths(from="X",to="M"),seminr::paths(from="X",to="Y"),seminr::paths(from="M",to="Y"));fit<-seminr::estimate_pls(D[,1:9],mm,sm);pm<-as.matrix(fit$path_coef);summ<-summary(fit);scores<-as.data.frame(fit$construct_scores)
for(i in seq_len(nrow(r$tables$Paths))){row<-r$tables$Paths[i,,drop=FALSE];ep<-strsplit(as.character(row$Path)," -> ",fixed=TRUE)[[1]];expect_close(row$Beta,pm[ep[1],ep[2]],tol=1e-8);expect_true(row$STDEV>0&&row$`IC_2.5`<=row$`IC_97.5`&&is.logical(row$CI_Significant));preds<-unique(c("X","M"))[unique(c("X","M"))%in%names(scores)];if(ep[2]=="M")preds<-"X" else if(ep[2]=="Y")preds<-c("X","M");full<-lm(scores[[ep[2]]]~.,data=scores[,preds,drop=FALSE]);r2f<-summary(full)$r.squared;pr<-setdiff(preds,ep[1]);r2r<-if(length(pr))summary(lm(scores[[ep[2]]]~.,data=scores[,pr,drop=FALSE]))$r.squared else 0;expect_close(row$f2,round((r2f-r2r)/(1-r2f),3),tol=1e-12)}
# Modelo de medición: cargas, CR y AVE se contrastan con las cargas del objeto seminr.
L<-as.matrix(summ$loadings)
for(i in seq_len(nrow(r$tables$Cargas))){z<-r$tables$Cargas[i,,drop=FALSE];expect_close(z$Loading,round(L[as.character(z$Item),as.character(z$Constructo)],3),tol=1e-12)}
for(cn in colnames(L)){lam<-as.numeric(L[,cn]);lam<-lam[is.finite(lam)&lam!=0];cr<-(sum(lam)^2)/(sum(lam)^2+sum(1-lam^2));ave<-mean(lam^2);z<-r$tables$Confiabilidad[r$tables$Confiabilidad$Constructo==cn,,drop=FALSE];expect_close(z$Composite_Reliability_CR,round(cr,3),tol=1e-12);expect_close(z$AVE,round(ave,3),tol=1e-12)}
# R², VIF, Fornell-Larcker, cargas cruzadas y HTMT se verifican con fórmulas directas sobre scores/indicadores.
for(endo in c("M","Y")){preds<-if(endo=="M")"X" else c("X","M");fit_r2<-lm(scores[[endo]]~.,data=scores[,preds,drop=FALSE]);z<-r$tables$R2[r$tables$R2$Constructo==endo,,drop=FALSE];expect_close(z$R2,round(summary(fit_r2)$r.squared,3),tol=1e-12);expect_close(z$R2_adj,round(summary(fit_r2)$adj.r.squared,3),tol=1e-12)}
vify<-r$tables$VIF[r$tables$VIF$Constructo=="Y",,drop=FALSE];for(i in seq_len(nrow(vify))){pred<-as.character(vify$Predictor[i]);other<-setdiff(c("X","M"),pred);ref_vif<-1/(1-summary(lm(scores[[pred]]~scores[[other]]))$r.squared);expect_close(vify$VIF[i],round(ref_vif,3),tol=1e-12)}
fl<-r$tables$FornellLarcker;for(cn in c("X","M","Y")){z<-r$tables$Confiabilidad[r$tables$Confiabilidad$Constructo==cn,,drop=FALSE];expect_close(fl[fl$Constructo==cn,cn],round(sqrt(z$AVE),3),tol=1e-12)}
cl<-r$tables$CrossLoadings;z<-cl[cl$Item=="x1",,drop=FALSE];expect_close(z$X,round(cor(D$x1,scores$X),3),tol=1e-12)
mean_abs_tri<-function(R)mean(abs(R[upper.tri(R)]));ht_ref<-mean(abs(cor(D[,1:3],D[,4:6])))/sqrt(mean_abs_tri(cor(D[,1:3]))*mean_abs_tri(cor(D[,4:6])));ht<-r$tables$HTMT;z<-ht[(ht$C1=="X"&ht$C2=="M")|(ht$C1=="M"&ht$C2=="X"),,drop=FALSE];expect_close(z$HTMT,round(ht_ref,3),tol=1e-12)
# Efecto indirecto y total: el estimador original debe respetar el producto de rutas.
expect_true(!is.null(r$tables$IndirectEffects)&&nrow(r$tables$IndirectEffects)>=1,"Debe existir el efecto indirecto X -> M -> Y")
ind<-r$tables$IndirectEffects[grepl("X",r$tables$IndirectEffects$Path)&grepl("M",r$tables$IndirectEffects$Path)&grepl("Y",r$tables$IndirectEffects$Path),,drop=FALSE];expect_true(nrow(ind)>=1);expect_close(ind$Beta_ind[1],pm["X","M"]*pm["M","Y"],tol=1e-8);expect_true(ind$IC_2.5[1]<=ind$IC_97.5[1]&&is.logical(ind$CI_Significant[1]))
tot<-r$tables$TotalEffects[r$tables$TotalEffects$Relacion=="X -> Y",,drop=FALSE];expect_true(nrow(tot)==1);expect_close(tot$Total,round(pm["X","Y"]+pm["X","M"]*pm["M","Y"],3),tol=1e-12)
expect_true(r$n_observations==n&&r$n_excluded_missing==0&&r$n_boot>=1000&&r$bootstrap_seed==1234)
for(k in c("SRMR","Q2","PLSPredict","HTMT_CI","FullVIF_CMB","GaussianCopula","MICOM","MGA","IPMA","VAF_Mediacion"))expect_true(is.null(r$tables[[k]]),paste(k,"debe estar desactivado"))
# La columna textual ajena al modelo no debe eliminar filas. Los indicadores no numéricos sí deben bloquearse antes de estimar.
expect_true(r$n_observations==n, "Una columna textual no usada no debe afectar la muestra del modelo")
D3<-D;D3$x1<-as.character(D3$x1);D3$x1[2]<-"texto";write.csv(D3,f,row.names=FALSE);r3<-run_pls_sem(params);expect_true(isTRUE(r3$blocked)&&r3$reason=="NON_NUMERIC_INDICATORS")
cat("PASS núcleo PLS-SEM y bootstrap con módulos avanzados desactivados explícitamente\n")
