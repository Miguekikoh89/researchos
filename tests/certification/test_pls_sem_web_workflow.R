source("tests/certification/helpers.R")
require_pkg("seminr"); require_pkg("seminrExtras"); require_pkg("jsonlite")
require_pkg("dplyr"); require_pkg("openxlsx"); require_pkg("nortest")
source_r("pls_sem_engine.R")

# Flujo web completo: cuatro constructos, mediacion secuencial, control numerico,
# comparacion de modelos y FIMIX-PLS oficial.
set.seed(20260704)
n <- 180
seg <- rep(1:2, each=n/2)
x <- rnorm(n)
m1 <- .65*x + rnorm(n,0,.65)
m2 <- ifelse(seg==1,.75,.30)*m1 + rnorm(n,0,.65)
y <- .18*x + ifelse(seg==1,.70,.25)*m2 + rnorm(n,0,.65)
age <- 18 + 42*runif(n)
mk <- function(z,l=.85) 1 + 4*pnorm(l*z+rnorm(length(z),0,.55))
D <- data.frame(
  x1=mk(x,.90),x2=mk(x,.85),x3=mk(x,.80),
  a1=mk(m1,.90),a2=mk(m1,.85),a3=mk(m1,.80),
  b1=mk(m2,.90),b2=mk(m2,.85),b3=mk(m2,.80),
  y1=mk(y,.90),y2=mk(y,.85),y3=mk(y,.80),
  edad=age)

f <- tempfile(fileext=".csv"); write.csv(D,f,row.names=FALSE); on.exit(unlink(f),add=TRUE)
params <- list(
  data_path=f,
  constructs=list(
    list(name="X",items=c("x1","x2","x3")),
    list(name="M1",items=c("a1","a2","a3")),
    list(name="M2",items=c("b1","b2","b3")),
    list(name="Y",items=c("y1","y2","y3"))),
  paths=list(list(from="X",to="M1"),list(from="M1",to="M2"),
             list(from="M2",to="Y"),list(from="X",to="Y")),
  control_variables=list(list(name="Edad",column="edad",targets=c("Y"))),
  n_boot=1000,bootstrap_seed=20260704,advanced_seed=20260704,
  advanced_pls=TRUE,calc_srmr=TRUE,calc_q2=TRUE,q2_omission_distance=7,
  calc_pls_predict=FALSE,calc_htmt_ci=FALSE,calc_full_vif=TRUE,
  calc_vaf=TRUE,calc_ipma=FALSE,calc_gaussian_copula=FALSE,
  calc_fimix=TRUE,fimix_k_min=2,fimix_k_max=2,fimix_nstart=3,
  fimix_max_iter=1500,fimix_stop_criterion=1e-6,use_fimix_for_mga=FALSE,
  calc_micom=FALSE,calc_mga=FALSE,compare_models=TRUE,
  comparison_roles=list(x="X",m1="M1",m2="M2",y="Y"),
  scale_min=1,scale_max=5)

r <- run_pls_sem(params)
expect_true(isTRUE(r$success) && !isTRUE(r$blocked), r$error %||% "Flujo web PLS-SEM bloqueado")
expect_true(identical(r$engine,"cancharios_pls_sem_advanced_web_v2"))
expect_true(!is.null(r$tables$Controls) && nrow(r$tables$Controls)==1)
expect_true(r$tables$Controls$Control[1]=="Edad")
expect_true(any(r$tables$Paths$Tipo_Ruta=="Control"))
expect_true(!any(grepl("Edad",r$tables$Hypotheses$Relacion,fixed=TRUE)))
expect_true(!is.null(r$tables$IndirectEffects) && nrow(r$tables$IndirectEffects)>0)
expect_true(!is.null(r$tables$TotalEffects) && nrow(r$tables$TotalEffects)>0)
expect_true(!is.null(r$tables$ModelComparison) && nrow(r$tables$ModelComparison)==3)
expect_true(setequal(r$tables$ModelComparison$Modelo,c("Directo","Paralelo","Secuencial")))
expect_true(!is.null(r$tables$FIMIX_Fit) && nrow(r$tables$FIMIX_Fit)==1)
expect_true(sum(r$tables$FIMIX_Fit$Seleccionado)==1)
expect_true(!is.null(r$tables$FIMIX_Segments) && nrow(r$tables$FIMIX_Segments)==2)
expect_true(sum(r$tables$FIMIX_Segments$N)==n)
expect_close(sum(r$tables$FIMIX_Segments$Proporcion),1,tol=1e-8)
expect_true(!is.null(r$tables$FIMIX_Assignments) && nrow(r$tables$FIMIX_Assignments)==n)
expect_true(r$advanced_modules$Controls=="implemented_single_item_controls")
expect_true(r$advanced_modules$FIMIX=="implemented")
expect_true(r$advanced_modules$ModelComparison=="implemented")

cat("PASS flujo web PLS-SEM avanzado: controles, mediacion, comparacion de modelos y FIMIX\n")
