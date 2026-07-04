source("tests/certification/helpers.R")
source_r("descriptives_full.R"); source_r("baremos_only.R")
df<-data.frame(i1=c(1,2,3,4,5,2,4,3,1,5),i2=c(1,2,3,4,5,3,4,2,1,5),i3=c(1,2,3,4,5,2,5,3,1,4))
score<-rowMeans(df)
r<-run_descriptives_full(df,names(df),"X",1,5)
expect_true(is.null(r$error),r$error %||% "error descriptivos")
expect_close(r$mean,round(mean(score),2));expect_close(r$sd,round(sd(score),2));expect_close(r$variance,round(var(score),2))
b<-run_baremos_only(df,names(df),"X",1,5,method="teorico")
expect_true(is.null(b$error)&&!isTRUE(b$blocked),b$error %||% "baremo bloqueado")
expect_close(b$cuts_raw,c(1,1+4/3,1+8/3,5))
tol<-sqrt(.Machine$double.eps)*max(1,abs(b$cuts_raw[2:3]));lev<-cut(score,c(-Inf,b$cuts_raw[2]+tol,b$cuts_raw[3]+tol,Inf),labels=c("Bajo","Medio","Alto"),include.lowest=TRUE,right=TRUE)
expect_true(identical(vapply(b$distribution,`[[`,integer(1),"f"),as.integer(table(factor(lev,levels=c("Bajo","Medio","Alto"))))),"Frecuencias de baremo no coinciden")
constant<-data.frame(a=rep(3,20),b=rep(3,20));rc<-run_descriptives_full(constant,c("a","b"),"C")
expect_true(is.na(rc$skewness)&&is.na(rc$kurtosis),"Variable constante debe reportar forma no disponible")
dup<-run_baremos_only(constant,c("a","b"),"C",method="tercil")
expect_true(isTRUE(dup$blocked)&&dup$reason=="CORTES_NO_DISTINTOS","Cortes duplicados no fueron bloqueados")
cat("PASS descriptivos y baremos\n")

# La conversión de factores numéricos debe usar sus etiquetas, no sus códigos internos.
factor_df <- data.frame(
  i1=factor(c("1","2","3","4","5"), levels=c("5","4","3","2","1")),
  i2=factor(c("1","2","3","4","5"), levels=c("5","4","3","2","1"))
)
rf <- run_descriptives_full(factor_df,c("i1","i2"),"Factor")
expect_true(is.null(rf$error),rf$error %||% "factor numérico bloqueado")
expect_close(rf$mean,3)

bad_text <- data.frame(i1=c("1","2","texto","4","5"),i2=c(1,2,3,4,5))
r_bad <- run_descriptives_full(bad_text,c("i1","i2"),"Texto")
expect_true(!is.null(r_bad$error)&&grepl("VALORES_NO_NUMERICOS",r_bad$error),"Texto no numérico fue convertido silenciosamente")

bad_inf <- data.frame(i1=c(1,2,Inf,4,5),i2=c(1,2,3,4,5))
r_inf <- run_descriptives_full(bad_inf,c("i1","i2"),"Inf")
expect_true(!is.null(r_inf$error)&&grepl("VALORES_NO_FINITOS",r_inf$error),"Inf no fue bloqueado")

out_scale <- data.frame(i1=c(1,2,3,4,6),i2=c(1,2,3,4,5))
b_out <- run_baremos_only(out_scale,c("i1","i2"),"Fuera",1,5,method="teorico")
expect_true(isTRUE(b_out$blocked)&&b_out$reason=="VALORES_FUERA_ESCALA","Baremo teórico aceptó respuestas fuera de la escala")
cat("PASS validación estricta de insumos descriptivos y baremos\n")
