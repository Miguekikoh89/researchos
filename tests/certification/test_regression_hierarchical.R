source("tests/certification/helpers.R");source_r("regression.R");source_r("hierarchical_regression.R")
set.seed(101);n<-180;x1<-rnorm(n);x2<-rnorm(n);e<-rnorm(n,sd=.7);y<-1+1.8*x1-.6*x2+e
r<-compute_regression(y,data.frame(x1=x1,x2=x2),c("x1","x2"),method="enter")
ref<-lm(y~x1+x2);sm<-summary(ref);expect_true(is.null(r$error)&&!isTRUE(r$blocked))
expect_close(r$R2_raw,sm$r.squared);expect_close(r$R2_adj_raw,sm$adj.r.squared);expect_close(r$p,pf(sm$fstatistic[1],sm$fstatistic[2],sm$fstatistic[3],lower.tail=FALSE))
for(co in r$coefficients){expect_close(co$B_raw,coef(ref)[co$term]);expect_close(co$p,sm$coefficients[co$term,"Pr(>|t|)"])}
df<-data.frame(y=y,x1=x1,x2=x2)
blocks<-list(list(name="B1",items="x1"),list(name="B2",items="x2"))
h<-run_hierarchical_regression(df,blocks,"y","Y")
m1<-lm(y~x1,df);m2<-lm(y~x1+x2,df);cmp<-anova(m1,m2)
expect_true(h$block_unit=="composite_mean_score"&&length(h$blocks)==2)
expect_close(h$blocks[[1]]$r2,summary(m1)$r.squared);expect_close(h$blocks[[2]]$r2,summary(m2)$r.squared);expect_close(h$blocks[[2]]$p_change,cmp$`Pr(>F)`[2])
blocked<-compute_regression(y,data.frame(x1=x1),"x1",method="stepwise");expect_true(isTRUE(blocked$blocked),"Stepwise debe permanecer bloqueado")
cat("PASS regresión lineal y jerárquica\n")
