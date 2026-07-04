source("tests/certification/helpers.R");source_r("statistics.R")
set.seed(81);x<-rnorm(120);y<-.55*x+rnorm(120,.0,.8)
rp<-correlate_pair(x,y,method="pearson");refp<-cor.test(x,y,method="pearson")
expect_close(rp$r_raw,unname(refp$estimate));expect_close(rp$p,refp$p.value);expect_close(rp$t,round(unname(refp$statistic),4),tol=1e-12)
z<-atanh(unname(refp$estimate));se<-1/sqrt(length(x)-3);ci<-tanh(z+c(-1,1)*qnorm(.975)*se);expect_close(c(rp$ci_lower,rp$ci_upper),round(ci,3),tol=1e-12)
# Empates: Spearman debe declarar aproximación asintótica y coincidir con cor.test exact=FALSE.
xs<-rep(1:10,each=4);ys<-c(rep(1:5,each=8))+rep(c(0,1),20);rs<-correlate_pair(xs,ys,method="spearman");refs<-suppressWarnings(cor.test(xs,ys,method="spearman",exact=FALSE))
expect_close(rs$r_raw,unname(refs$estimate));expect_close(rs$p,refs$p.value);expect_true(rs$p_method=="asymptotic");expect_true(rs$ci_method=="fisher_z_approximation")
# Correlación perfecta: el coeficiente es válido, pero el estadístico t infinito no se persiste.
perfect<-correlate_pair(1:20,2*(1:20)+3,method="pearson");expect_close(perfect$r_raw,1);expect_true(is.na(perfect$t),"t infinito debe reportarse no disponible")
# Kendall con empates: tau y p asintótico coinciden y el IC bootstrap es válido.
xk<-c(1,1,2,2,3,3,4,4,5,5);yk<-c(1,2,1,3,2,4,3,5,4,5);rk<-correlate_pair(xk,yk,method="kendall");refk<-suppressWarnings(cor.test(xk,yk,method="kendall",exact=FALSE))
expect_close(rk$r_raw,unname(refk$estimate));expect_close(rk$p,refk$p.value);expect_true(rk$ci_lower>=-1&&rk$ci_upper<=1&&rk$ci_lower<=rk$r_raw&&rk$r_raw<=rk$ci_upper)
cat("PASS Pearson, Spearman con empates, Kendall y correlación perfecta\n")
