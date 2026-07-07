source("tests/certification/helpers.R");source_r("ordinal_regression.R");source_r("ancova.R");require_pkg("MASS")
set.seed(301);n<-300;x<-rnorm(n);latent<-.2+1.2*x+rlogis(n);y<-cut(latent,c(-Inf,-.7,.8,Inf),labels=c("Bajo","Medio","Alto"),ordered_result=TRUE);df<-data.frame(x=x,y=y)
r<-run_ordinal_regression(df,"x","y","X","Y",ordered_levels=c("Bajo","Medio","Alto"))
ref<-MASS::polr(y~x,df,Hess=TRUE,method="logistic");null<-MASS::polr(y~1,df,Hess=TRUE,method="logistic");lr<--2*(as.numeric(logLik(null))-as.numeric(logLik(ref)));expect_true(is.null(r$error)&&!isTRUE(r$blocked))
expect_close(r$lr_chi2,round(lr,3),tol=1e-12);expect_close(r$lr_p,pchisq(lr,1,lower.tail=FALSE));expect_close(r$raw_values$coefficients_B["X"],coef(ref)["x"])
blk<-run_ordinal_regression(data.frame(x=x,y1=y,y2=y),"x",c("y1","y2"),"X","Y",ordered_levels=c("Bajo","Medio","Alto"));expect_true(isTRUE(blk$blocked)&&blk$reason=="VD_ORDINAL_DEBE_SER_UNA_COLUMNA")

set.seed(302);g<-factor(rep(c("A","B","C"),each=60));cov<-rnorm(180);yy<-2+.8*cov+c(A=0,B=.5,C=1.1)[g]+rnorm(180,.0,.8);da<-data.frame(yy=yy,g=g,cov=cov)
a<-run_ancova(da,"yy","g","cov","Y",check_slopes="no",posthoc="none")
dref<-data.frame(dep=yy,grupo=g,covariable=cov);mod<-lm(dep~covariable+grupo,dref);tb<-anova(mod)
expect_true(is.null(a$error)&&!isTRUE(a$blocked));expect_close(a$p_grupo,tb["grupo","Pr(>F)"])
pe<-tb["grupo","Sum Sq"]/(tb["grupo","Sum Sq"]+tb["Residuals","Sum Sq"]);expect_close(a$partial_eta2_group,pe)
pe_cov<-tb["covariable","Sum Sq"]/(tb["covariable","Sum Sq"]+tb["Residuals","Sum Sq"]);expect_close(a$partial_eta2_covariate,pe_cov);expect_close(a$delta_r2_covariate,summary(mod)$r.squared-summary(lm(dep~grupo,dref))$r.squared)
lvls<-levels(g);nd<-data.frame(covariable=rep(mean(cov),length(lvls)),grupo=factor(lvls,levels=lvls));pr<-predict(mod,newdata=nd,se.fit=TRUE);crit<-qt(.975,pr$df)
for(z in a$adjusted_means){i<-match(z$group,lvls);expect_close(z$mean_adj,pr$fit[i]);expect_close(z$se,pr$se.fit[i]);expect_close(z$ci_lower,pr$fit[i]-crit*pr$se.fit[i]);expect_close(z$ci_upper,pr$fit[i]+crit*pr$se.fit[i])}
expect_true(a$adjusted_means_engine=="base_r_model_matrix")

ap<-run_ancova(da,"yy","g","cov","Y",check_slopes="no",posthoc="bonferroni")
trm<-delete.response(terms(mod));X<-model.matrix(trm,nd,contrasts.arg=mod$contrasts,xlev=mod$xlevels);L<-X[1,]-X[2,];est<-sum(L*coef(mod));se<-sqrt(drop(t(L)%*%vcov(mod)%*%L));tv<-est/se;praw<-2*pt(abs(tv),df.residual(mod),lower.tail=FALSE);padj<-p.adjust(c(praw,NA,NA),method="bonferroni",n=3)[1]
z<-ap$posthoc_adjusted_means[[1]];expect_close(z$estimate,est);expect_close(z$se,se);expect_close(z$t,tv);expect_close(z$p_raw,praw);expect_close(z$p_adj,padj)
cat("PASS regresión ordinal y ANCOVA sin dependencia de emmeans\n")
