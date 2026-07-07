source("tests/certification/helpers.R");source_r("ordinal_regression.R");source_r("ancova.R");require_pkg("MASS");require_pkg("emmeans")
set.seed(301);n<-300;x<-rnorm(n);latent<-.2+1.2*x+rlogis(n);y<-cut(latent,c(-Inf,-.7,.8,Inf),labels=c("Bajo","Medio","Alto"),ordered_result=TRUE);df<-data.frame(x=x,y=y)
r<-run_ordinal_regression(df,"x","y","X","Y",ordered_levels=c("Bajo","Medio","Alto"))
ref<-MASS::polr(y~x,df,Hess=TRUE,method="logistic");null<-MASS::polr(y~1,df,Hess=TRUE,method="logistic");lr<--2*(as.numeric(logLik(null))-as.numeric(logLik(ref)));expect_true(is.null(r$error)&&!isTRUE(r$blocked))
expect_close(r$lr_chi2,round(lr,3),tol=1e-12);expect_close(r$lr_p,pchisq(lr,1,lower.tail=FALSE));expect_close(r$raw_values$coefficients_B["X"],coef(ref)["x"])
# No fabricar VD ordinal promediando múltiples ítems
blk<-run_ordinal_regression(data.frame(x=x,y1=y,y2=y),"x",c("y1","y2"),"X","Y",ordered_levels=c("Bajo","Medio","Alto"));expect_true(isTRUE(blk$blocked)&&blk$reason=="VD_ORDINAL_DEBE_SER_UNA_COLUMNA")
# ANCOVA
set.seed(302);g<-factor(rep(c("A","B","C"),each=60));cov<-rnorm(180);yy<-2+.8*cov+c(A=0,B=.5,C=1.1)[g]+rnorm(180,.0,.8);da<-data.frame(yy=yy,g=g,cov=cov)
a<-run_ancova(da,"yy","g","cov","Y",check_slopes="no",posthoc="none");mod<-lm(yy~cov+g,da);tb<-anova(mod);expect_close(a$p_grupo,tb["g","Pr(>F)"]);pe<-tb["g","Sum Sq"]/(tb["g","Sum Sq"]+tb["Residuals","Sum Sq"]);expect_close(a$partial_eta2_group,pe)
pe_cov<-tb["cov","Sum Sq"]/(tb["cov","Sum Sq"]+tb["Residuals","Sum Sq"]);expect_close(a$partial_eta2_covariate,pe_cov);expect_close(a$delta_r2_covariate,summary(mod)$r.squared-summary(lm(yy~g,da))$r.squared)
emm_ref<-as.data.frame(emmeans::emmeans(mod,"g"));for(z in a$adjusted_means){i<-match(z$group,as.character(emm_ref$g));expect_close(z$mean_adj,emm_ref$emmean[i]);expect_close(z$se,emm_ref$SE[i]);expect_close(z$ci_lower,emm_ref$lower.CL[i]);expect_close(z$ci_upper,emm_ref$upper.CL[i])}
cat("PASS regresión ordinal y ANCOVA\n")
