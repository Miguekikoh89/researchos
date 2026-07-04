source("tests/certification/helpers.R");source_r("frequencies.R")
df<-data.frame(i1=c(1,1,2,3,3,3,4,5),i2=c(1,2,2,3,4,4,5,5))
r<-run_frequencies(df,c("i1","i2"),"X")
expect_true(is.null(r$error));expect_close(r$total_mean,mean(rowMeans(df)));expect_close(r$total_sd,sd(rowMeans(df)))
ft<-do.call(rbind,r$items[[1]]$frequency_table);expect_true(sum(ft$n)==nrow(df));expect_close(tail(ft$pct_acum,1),100,tol=.11)
cst<-run_frequencies(data.frame(a=rep(3,10),b=rep(3,10)),c("a","b"),"C");expect_true(is.na(cst$items[[1]]$skewness)&&is.na(cst$items[[1]]$kurtosis))
cat("PASS frecuencias y puntajes agregados\n")

factor_df<-data.frame(
  i1=factor(c("1","2","3","4","5"),levels=c("5","4","3","2","1")),
  i2=factor(c("1","2","3","4","5"),levels=c("5","4","3","2","1"))
)
rf<-run_frequencies(factor_df,c("i1","i2"),"Factor")
expect_true(is.null(rf$error),rf$error %||% "factor numérico bloqueado")
expect_close(rf$total_mean,3)

bad<-run_frequencies(data.frame(i1=c("1","2","x","4"),i2=c(1,2,3,4)),c("i1","i2"),"Bad")
expect_true(!is.null(bad$error)&&grepl("VALORES_NO_NUMERICOS",bad$error),"Frecuencias aceptó texto no numérico")
inf_bad<-run_frequencies(data.frame(i1=c(1,2,Inf,4),i2=c(1,2,3,4)),c("i1","i2"),"Inf")
expect_true(!is.null(inf_bad$error)&&grepl("VALORES_NO_FINITOS",inf_bad$error),"Frecuencias aceptó Inf")
cat("PASS validación estricta de insumos en frecuencias\n")
