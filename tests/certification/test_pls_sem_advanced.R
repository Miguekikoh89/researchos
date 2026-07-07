source("tests/certification/helpers.R")
require_pkg("seminr"); require_pkg("jsonlite"); require_pkg("dplyr"); require_pkg("openxlsx"); require_pkg("nortest")
source_r("pls_sem_engine.R")

# Datos continuos acotados en la escala teórica 1–5, con mediación X -> M -> Y.
set.seed(260704)
n <- 150
x <- rnorm(n)
m <- .70*x + rnorm(n, 0, .65)
y <- .25*x + .68*m + rnorm(n, 0, .65)
likert_cont <- function(z, loading, noise=.55) 1 + 4*pnorm(loading*z + rnorm(length(z),0,noise))
D <- data.frame(
  x1=likert_cont(x,.90), x2=likert_cont(x,.85), x3=likert_cont(x,.80),
  m1=likert_cont(m,.90), m2=likert_cont(m,.85), m3=likert_cont(m,.80),
  y1=likert_cont(y,.90), y2=likert_cont(y,.85), y3=likert_cont(y,.80)
)
rownames(D) <- as.character(seq_len(nrow(D)))
construct_items <- list(X=c("x1","x2","x3"), M=c("m1","m2","m3"), Y=c("y1","y2","y3"))
p_df <- data.frame(from=c("X","X","M"),to=c("M","Y","Y"),stringsAsFactors=FALSE)
mm <- seminr::constructs(
  seminr::composite("X",seminr::multi_items("",construct_items$X)),
  seminr::composite("M",seminr::multi_items("",construct_items$M)),
  seminr::composite("Y",seminr::multi_items("",construct_items$Y)))
sm <- seminr::relationships(
  seminr::paths(from="X",to="M"),
  seminr::paths(from="X",to="Y"),
  seminr::paths(from="M",to="Y"))
fit <- seminr::estimate_pls(D,mm,sm)
summ <- summary(fit)

f <- tempfile(fileext=".csv"); write.csv(D,f,row.names=FALSE); on.exit(unlink(f),add=TRUE)
params <- list(
  data_path=f,
  constructs=lapply(names(construct_items),function(cn)list(name=cn,items=construct_items[[cn]])),
  paths=list(list(from="X",to="M"),list(from="X",to="Y"),list(from="M",to="Y")),
  n_boot=1000, bootstrap_seed=8241,
  advanced_pls=TRUE, calc_q2=TRUE, q2_omission_distance=7,
  calc_pls_predict=TRUE, pls_predict_folds=5, pls_predict_reps=1,
  calc_srmr=TRUE, calc_htmt_ci=TRUE, calc_full_vif=TRUE,
  calc_vaf=TRUE, calc_ipma=TRUE, ipma_target="Y", scale_min=1, scale_max=5,
  calc_gaussian_copula=FALSE, advanced_seed=7721)
r <- run_pls_sem(params)
expect_true(isTRUE(r$success) && !isTRUE(r$blocked), r$error %||% "PLS avanzado bloqueado")
expect_true(identical(r$engine,"cancharios_pls_sem_advanced_web_v2"))
for(k in c("Q2","PLSPredict","SRMR","HTMT_CI","FullVIF_CMB","VAF_Mediacion","IPMA")) {
  expect_true(!is.null(r$tables[[k]]) && nrow(r$tables[[k]])>0,paste("Falta tabla avanzada",k))
}
expect_true(all(unlist(r$advanced_modules[c("Q2","PLSPredict","SRMR","HTMT_CI","FullVIF_CMB","VAF","IPMA")])=="implemented"))
expect_true(identical(r$advanced_modules$GaussianCopula,"disabled_by_configuration_opt_in"))
expect_true(identical(r$advanced_modules$MICOM,"not_applicable_without_group_variable_or_fimix_assignment"),
  paste0("Estado MICOM inesperado: ", r$advanced_modules$MICOM %||% "NULL"))
expect_true(identical(r$advanced_modules$MGA,"not_applicable_without_group_variable_or_fimix_assignment"),
  paste0("Estado MGA inesperado: ", r$advanced_modules$MGA %||% "NULL"))

# PLS-Predict: comparación exacta de RMSE PLS/LM con la salida oficial de SEMinR
# usando la misma semilla y partición de folds.
set.seed(7721)
pred_ref <- seminr::predict_pls(model=fit,technique=seminr::predict_DA,noFolds=5,reps=NULL,cores=NULL)
for(item in unlist(construct_items[c("M","Y")],use.names=FALSE)) {
  z <- r$tables$PLSPredict[r$tables$PLSPredict$Indicador==item,,drop=FALSE]
  expect_true(nrow(z)==1,paste("Falta indicador PLS-Predict",item))
  yp <- pred_ref$items$PLS_out_of_sample[,item]
  yl <- pred_ref$items$lm_out_of_sample[,item]
  ya <- pred_ref$items$item_actuals[,item]
  expect_close(z$RMSE_modelo,sqrt(mean((ya-yp)^2)),tol=1e-8)
  expect_close(z$MAE_modelo,mean(abs(ya-yp)),tol=1e-8)
  expect_close(z$RMSE_LM,sqrt(mean((ya-yl)^2)),tol=1e-8)
  expect_close(z$MAE_LM,mean(abs(ya-yl)),tol=1e-8)
}

# HTMT inferencial: el IC debe ser el percentil del mismo arreglo boot_HTMT.
set.seed(8242)
boot_ref <- seminr::bootstrap_model(fit,nboot=200,cores=1,seed=8242)
ht_ref_tbl <- calc_htmt_ci(boot_ref,summ,alpha=.05)
arr <- boot_ref$boot_HTMT
for(i in seq_len(nrow(ht_ref_tbl))) {
  z <- ht_ref_tbl[i,,drop=FALSE]; a<-as.character(z$C1); b<-as.character(z$C2)
  va <- as.numeric(arr[a,b,]); vb <- as.numeric(arr[b,a,])
  va <- va[is.finite(va)]; vb <- vb[is.finite(vb)]; vals <- if(length(va)>=length(vb))va else vb
  ci <- as.numeric(quantile(vals,c(.025,.975),names=FALSE,type=7))
  expect_close(c(z$IC_2.5,z$IC_97.5),ci,tol=1e-8)
  expect_true(z$Bootstrap_Valid>=160)
}

# Q² Stone-Geisser: omisiones válidas, SSO positivo y fórmula 1-SSE/SSO.
q2 <- r$tables$Q2
expect_true(all(q2$SSO>0) && all(q2$SSE>=0) && all(q2$Omisiones_validas>0))
expect_true(all(q2$Distancia_omision>=5 & q2$Distancia_omision<=12))
expect_true(all(n %% q2$Distancia_omision != 0))
expect_close(q2$Q2,1-q2$SSE/q2$SSO,tol=1e-10)
expect_true(all(grepl("Stone-Geisser",q2$Metodo,fixed=TRUE)))

# Full-collinearity VIF contrastado con regresiones auxiliares directas.
scores <- as.data.frame(fit$construct_scores)
for(i in seq_len(nrow(r$tables$FullVIF_CMB))) {
  z <- r$tables$FullVIF_CMB[i,,drop=FALSE]; lv <- as.character(z$Variable_Latente)
  others <- setdiff(names(scores),lv)
  ref <- 1/(1-summary(lm(reformulate(others,response=lv),data=scores))$r.squared)
  expect_close(z$VIF_Full,ref,tol=1e-8)
  expect_true(grepl("no prueba concluyente",z$Alcance,fixed=TRUE))
}

# VAF: clasificación por significación de IC, sin usar umbrales mecánicos 20/80.
vaf <- r$tables$VAF_Mediacion
expect_true(any(grepl("X",vaf$Ruta_indirecta)&grepl("M",vaf$Ruta_indirecta)&grepl("Y",vaf$Ruta_indirecta)))
expect_true(all(grepl("Zhao",vaf$Criterio,fixed=TRUE)))
expect_true(all(vaf$N_rutas_indirectas>=1))
expect_true(all(grepl("conjunto",vaf$Criterio,fixed=TRUE)))
expect_true(all(is.finite(vaf$IC_indirecto_2.5)) & all(is.finite(vaf$IC_indirecto_97.5)))

# IPMA: rendimiento con límites teóricos 1–5 e importancia como efecto total
# no estandarizado sobre scores 0–100 reconstruidos de manera independiente.
ip <- r$tables$IPMA
W <- as.matrix(fit$outer_weights)
score100_ref <- list()
for(cn in names(construct_items)) {
  its<-construct_items[[cn]]; X<-as.matrix(D[,its,drop=FALSE])
  w<-as.numeric(W[its,cn])/apply(X,2,sd); w<-w/sqrt(sum(w^2))
  score<-as.numeric(X%*%w)
  lo<-sum(ifelse(w>=0,1*w,5*w)); hi<-sum(ifelse(w>=0,5*w,1*w))
  score100_ref[[cn]]<-100*(score-lo)/(hi-lo)
}
score100_ref<-as.data.frame(score100_ref,check.names=FALSE)
B_ref<-matrix(0,3,3,dimnames=list(c("X","M","Y"),c("X","M","Y")))
fit_m_ref<-lm.fit(cbind(1,score100_ref$X),score100_ref$M)
B_ref["X","M"]<-fit_m_ref$coefficients[2]
fit_y_ref<-lm.fit(cbind(1,score100_ref$X,score100_ref$M),score100_ref$Y)
B_ref[c("X","M"),"Y"]<-fit_y_ref$coefficients[2:3]
T_ref<-solve(diag(3)-B_ref)-diag(3)
for(i in seq_len(nrow(ip))) {
  cn <- as.character(ip$Predictor[i])
  expect_close(ip$Performance_0_100[i],mean(score100_ref[[cn]]),tol=1e-8)
  expect_close(ip$Importancia_Efecto_Total[i],T_ref[cn,"Y"],tol=1e-8)
  expect_true(ip$Scale_Min[i]==1 && ip$Scale_Max[i]==5)
  expect_true(grepl("pesos desestandarizados",ip$Metodo[i],fixed=TRUE))
  expect_true(grepl("no estandarizados",ip$Metodo[i],fixed=TRUE))
}

# SRMR: variantes saturada y estimada, finitas y con alcance explícito.
expect_true(nrow(r$tables$SRMR)>=2)
expect_true(all(c("SRMR_saturated_composite","SRMR_estimated_composite")%in%r$tables$SRMR$Indice))
expect_true(all(is.finite(r$tables$SRMR$Valor) & r$tables$SRMR$Valor>=0))
expect_true(all(is.finite(r$tables$SRMR$d_ULS) & r$tables$SRMR$d_ULS>=0))
expect_true(all(grepl("no constituye",r$tables$SRMR$Advertencia,fixed=TRUE)))

# MICOM/MGA: dos grupos generados desde la misma población. Se exige reestimación
# válida en al menos 80% de las permutaciones y MGA solo después de MICOM.
set.seed(1729)
base <- D[1:60,]
base_mat <- as.matrix(base)
noise_mat <- matrix(
  rnorm(nrow(base_mat) * ncol(base_mat), 0, .008),
  nrow = nrow(base_mat),
  ncol = ncol(base_mat),
  dimnames = dimnames(base_mat)
)
base2_mat <- base_mat + noise_mat
base2_mat[base2_mat < 1] <- 1
base2_mat[base2_mat > 5] <- 5
base2 <- as.data.frame(base2_mat, check.names = FALSE)
names(base2) <- names(base)
expect_true(identical(dim(base2), dim(base)), "La réplica MICOM/MGA debe conservar 60 filas y 9 indicadores")
Dg <- rbind(base,base2)
Dg$grupo <- rep(c("A","B"),each=nrow(base))
fit_g <- seminr::estimate_pls(Dg[,names(D),drop=FALSE],mm,sm)
mic <- calc_micom(Dg,p_df,fit_g,summary(fit_g),"grupo",n_permut=50,m_model=mm,s_model=sm,seed=701)
expect_true(!is.null(mic)&&nrow(mic)>0,"MICOM no devolvió resultados")
expect_true(all(mic$Permutaciones_validas>=40))
expect_true(all(mic$p_permutacion_ajustado>=0 & mic$p_permutacion_ajustado<=1))
expect_true(all(mic$p_dif_medias_ajustado>=0 & mic$p_dif_medias_ajustado<=1))
expect_true(all(mic$p_dif_varianzas_ajustado>=0 & mic$p_dif_varianzas_ajustado<=1))
expect_true(all(mic$Configuracional%in%TRUE))
expect_true(all(grepl("reestimados",mic$Metodo,fixed=TRUE)))
expect_true(all(grepl("logarítmica",mic$Metodo,fixed=TRUE)))
expect_true(any(mic$Compositional_Invariance%in%TRUE),"MICOM no alcanzó invarianza composicional en datos equivalentes")
mga <- calc_mga(Dg,p_df,"grupo",n_permut=50,m_model=mm,s_model=sm,micom_tbl=mic,seed=702)
expect_true(!is.null(mga)&&nrow(mga)>0,"MGA no se ejecutó después de MICOM")
expect_true(all(mga$Permutaciones_validas>=40))
expect_true(all(mga$p_ajustado>=0 & mga$p_ajustado<=1))
expect_true(all(mga$MICOM_composicional%in%TRUE))

# Cópula gaussiana: ECDF ajustada F4, constructo copular de un ítem,
# reestimación PLS y bootstrap del modelo aumentado.
set.seed(9901)
nc <- 180
xc <- rexp(nc)
mc <- .55*xc + rnorm(nc,0,.55)
Dc <- data.frame(
  x1=xc+rnorm(nc,0,.08), x2=.9*xc+rnorm(nc,0,.08), x3=1.1*xc+rnorm(nc,0,.08),
  m1=mc+rnorm(nc,0,.08), m2=.9*mc+rnorm(nc,0,.08), m3=1.1*mc+rnorm(nc,0,.08))
mm_c <- seminr::constructs(
  seminr::composite("X",seminr::multi_items("",c("x1","x2","x3"))),
  seminr::composite("M",seminr::multi_items("",c("m1","m2","m3"))))
sm_c <- seminr::relationships(seminr::paths(from="X",to="M"))
fit_c <- seminr::estimate_pls(Dc,mm_c,sm_c)
p_c <- data.frame(from="X",to="M",stringsAsFactors=FALSE)
cop <- calc_gaussian_copula(fit_c,Dc,p_c,m_model=mm_c,n_boot=200,seed=9902)
expect_true(!is.null(cop)&&nrow(cop)==1,"Cópula gaussiana no devolvió el modelo aumentado")
expect_true(cop$Normalidad_p[1]<.05)
expect_true(cop$Bootstrap_Valid[1]>=160)
expect_true(is.finite(cop$Cor_X_Copula[1]) && abs(cop$Cor_X_Copula[1])<=1)
expect_true(is.finite(cop$Omega_Simple[1]) && cop$Omega_Simple[1]>=0 && cop$Omega_Simple[1]<=1)
expect_close(cop$Omega_Simple[1],1-cop$Cor_X_Copula[1]^2,tol=1e-12)
expect_true(grepl("condicional",cop$Bootstrap_Alcance[1],fixed=TRUE))
expect_true(cop$IC_lo[1]<=cop$IC_hi[1])
expect_true(cop$Beta_Corregido_IC_lo[1]<=cop$Beta_Corregido_IC_hi[1])
expect_true(all(vapply(cop[,c("PLS_Beta_Original","PLS_Beta_Corregido","Copula_Coef"),drop=FALSE], function(z) all(is.finite(z)), logical(1))))
expect_true(grepl("ECDF ajustada F4",cop$Metodo[1],fixed=TRUE))
expect_true(grepl("constructo copular de un ítem",cop$Metodo[1],fixed=TRUE))
expect_true(grepl("Exploratoria",cop$Calidad_bootstrap[1],fixed=TRUE))
f4 <- adjusted_ecdf_copula(xc)
expected_f4 <- qnorm(1/(2*nc)+((nc-1)/(nc^2))*rank(xc,ties.method="max"))
expect_close(f4,expected_f4,tol=1e-12)

# Fallos cerrados: IPMA fuera de rango y cópula sin no normalidad no inventan tablas.
D_bad <- D; D_bad$x1[1] <- 9
expect_true(is.null(calc_ipma(fit,D_bad,p_df,construct_items,target="Y",scale_min=1,scale_max=5)))
nn <- 160; nq <- qnorm(((1:nn)-.5)/nn)
fake_fit <- fit
fake_fit$construct_scores <- cbind(X=nq,M=rev(nq),Y=c(nq[-1],nq[1]))
D_fake <- D[rep(seq_len(nrow(D)),length.out=nn),,drop=FALSE]
expect_true(is.null(calc_gaussian_copula(fake_fit,D_fake,p_df,m_model=mm,n_boot=200,seed=9)))

cat("PASS PLS-SEM avanzado: Q2, PLS-Predict, HTMT-CI, SRMR, CMB, VAF, IPMA, MICOM, MGA y copula\n")
