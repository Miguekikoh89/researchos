source("tests/certification/helpers.R");source_r("logistic.R");source_r("logistic_multinomial.R")
set.seed(202);n<-350;x1<-rnorm(n);x2<-rnorm(n);pr<-plogis(-.3+1.1*x1-.7*x2);yb<-ifelse(runif(n)<pr,"Sí","No")
r<-compute_logistic_binary(yb,data.frame(x1=x1,x2=x2),c("x1","x2"),event_level="Sí",do_hl="no",do_roc="yes")
ref<-glm(as.integer(yb=="Sí")~x1+x2,family=binomial);expect_true(is.null(r$error)&&!isTRUE(r$blocked))
expect_close(r$p_lr,pchisq(-2*(logLik(glm(as.integer(yb=="Sí")~1,family=binomial))-logLik(ref)),2,lower.tail=FALSE))
for(co in r$coefficients){expect_close(co$B_raw,coef(ref)[co$term]);expect_close(co$p,summary(ref)$coefficients[co$term,"Pr(>|z|)"])}
y01<-as.integer(yb=="Sí");rk<-rank(fitted(ref),ties.method="average");auc<-(sum(rk[y01==1])-sum(y01)*(sum(y01)+1)/2)/(sum(y01)*sum(y01==0));expect_close(r$roc$auc_raw,auc)
# Multinomial
require_pkg("nnet");set.seed(203);n<-420;x1<-rnorm(n);x2<-rnorm(n);etaB<-.2+.7*x1;etaC<--.3-.5*x1+.8*x2;den<-1+exp(etaB)+exp(etaC);P<-cbind(A=1/den,B=exp(etaB)/den,C=exp(etaC)/den);u<-runif(n);ym<-apply(cbind(u,P),1,function(z){if(z[1]<z[2])"A"else if(z[1]<z[2]+z[3])"B"else"C"})
rm<-compute_logistic_multinomial(ym,data.frame(x1=x1,x2=x2),c("x1","x2"),reference_level="A")
d<-data.frame(y=relevel(factor(ym),ref="A"),x1=x1,x2=x2);fm<-nnet::multinom(y~x1+x2,d,trace=FALSE,Hess=TRUE);f0<-nnet::multinom(y~1,d,trace=FALSE);lr<--2*(as.numeric(logLik(f0))-as.numeric(logLik(fm)));df_lr<-attr(logLik(fm),"df")-attr(logLik(f0),"df")
expect_close(rm$lr_chi2,lr);expect_close(rm$lr_p,pchisq(lr,df_lr,lower.tail=FALSE));expect_true(rm$reference_level=="A")
smf<-summary(fm);Bref<-smf$coefficients;SEref<-smf$standard.errors
for(cmp in rm$comparisons){lv<-cmp$level;for(co in cmp$coefficients){term<-co$term;expect_close(co$B,Bref[lv,term]);expect_close(co$SE,SEref[lv,term]);expect_close(co$p,2*pnorm(abs(Bref[lv,term]/SEref[lv,term]),lower.tail=FALSE));expect_close(co$OR,exp(Bref[lv,term]))}}
cat("PASS logística binaria, etiquetas, AUC y multinomial\n")
