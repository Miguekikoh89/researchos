# ResearchOS - Regresion Ordinal
options(encoding="UTF-8")
run_ordinal_regression <- function(df, var_a_items, var_b_items, var_a_name, var_b_name, alpha=0.05, link_function="logit", ordinalizacion="tercil", pseudo_r2_type="nagelkerke") {
  tryCatch({
    if(!requireNamespace("MASS",quietly=TRUE)) install.packages("MASS",repos="https://cran.r-project.org")
    library(MASS)

    score_a <- if(length(var_a_items)>1) rowMeans(df[,var_a_items,drop=FALSE],na.rm=TRUE) else df[[var_a_items]]
    score_b <- if(length(var_b_items)>1) rowMeans(df[,var_b_items,drop=FALSE],na.rm=TRUE) else df[[var_b_items]]

    cuts <- switch(tolower(as.character(ordinalizacion)),
      "percentil" = quantile(score_b, probs=c(0.25,0.75), na.rm=TRUE),
      "teorico"   = { rng <- max(score_b,na.rm=TRUE)-min(score_b,na.rm=TRUE); c(min(score_b,na.rm=TRUE)+rng/3, min(score_b,na.rm=TRUE)+2*rng/3) },
      quantile(score_b, probs=c(1/3, 2/3), na.rm=TRUE)
    )
    vd_ord <- cut(score_b, breaks=c(-Inf, cuts, Inf), labels=c("Bajo","Medio","Alto"), ordered_result=TRUE)

    datos <- data.frame(vd=vd_ord, vi=score_a)
    datos <- datos[complete.cases(datos),]

    polr_method <- switch(tolower(as.character(link_function)), "probit"="probit", "loglog"="loglog", "cloglog"="cloglog", "logistic")
    modelo <- polr(vd ~ vi, data=datos, Hess=TRUE, method=polr_method)
    modelo_nulo <- polr(vd ~ 1, data=datos, Hess=TRUE, method=polr_method)
    ctable <- coef(summary(modelo))
    p_vals <- pnorm(abs(ctable[,"t value"]), lower.tail=FALSE)*2

    ci <- confint(modelo)
    or <- exp(coef(modelo))
    if (is.null(dim(ci))) {
      # confint devolvio un vector (ocurre cuando hay un solo predictor)
      or_ci <- matrix(exp(ci), nrow=1, dimnames=list(names(coef(modelo)), names(ci)))
    } else {
      or_ci <- exp(ci[names(coef(modelo)),,drop=FALSE])
    }

    ll_null <- logLik(modelo_nulo)[1]
    ll_full <- logLik(modelo)[1]
    n_obs <- nrow(datos)
    k_pred <- length(coef(modelo))
    lr_stat <- -2*(ll_null-ll_full)
    p_lr <- pchisq(lr_stat, df=k_pred, lower.tail=FALSE)

    r2_cox_snell <- 1 - exp((2/n_obs)*(ll_null-ll_full))
    r2_mcfadden  <- 1 - (ll_full/ll_null)
    r2_max <- 1 - exp((2/n_obs)*ll_null)
    r2_nagelkerke <- r2_cox_snell / r2_max

    # Test de lineas paralelas (Brant aproximado via comparacion logit binario por corte)
    parallel_test <- tryCatch({
      niveles <- levels(vd_ord)
      bin1 <- ifelse(as.integer(vd_ord) <= 1, 0, 1)
      bin2 <- ifelse(as.integer(vd_ord) <= 2, 0, 1)
      m1 <- glm(bin1 ~ vi, data=datos, family=binomial(link=if(polr_method=="probit") "probit" else "logit"))
      m2 <- glm(bin2 ~ vi, data=datos, family=binomial(link=if(polr_method=="probit") "probit" else "logit"))
      b1 <- coef(m1)["vi"]; b2 <- coef(m2)["vi"]
      se1 <- summary(m1)$coefficients["vi","Std. Error"]; se2 <- summary(m2)$coefficients["vi","Std. Error"]
      z_diff <- (b1-b2)/sqrt(se1^2+se2^2)
      p_diff <- 2*pnorm(abs(z_diff), lower.tail=FALSE)
      list(z=round(z_diff,3), p=round(p_diff,4), ok=p_diff>=0.05,
           interpretation=if(p_diff<0.05) "Posible violacion del supuesto de lineas paralelas" else "Supuesto de lineas paralelas razonable")
    }, error=function(e) list(z=NA,p=NA,ok=TRUE,interpretation="No calculado"))

    coefs <- lapply(names(coef(modelo)), function(nm) {
      list(
        term=nm, B=round(coef(modelo)[nm],3),
        OR=round(or[nm],3),
        ci_lower=round(or_ci[nm,1],3), ci_upper=round(or_ci[nm,2],3),
        t=round(ctable[nm,"t value"],3),
        p=round(p_vals[nm],4),
        p_apa=if(p_vals[nm]<.001)"< .001" else paste0("= ",round(p_vals[nm],3)),
        significant=p_vals[nm]<alpha
      )
    })

    dist_table <- as.data.frame(table(vd_ord))
    colnames(dist_table) <- c("Nivel","n")
    dist_table$pct <- round(dist_table$n/sum(dist_table$n)*100,1)

    list(
      n=nrow(datos), var_a=var_a_name, var_b=var_b_name,
      link_function_used=polr_method,
      ordinalizacion_used=ordinalizacion,
      lr_chi2=round(lr_stat,3), lr_df=k_pred, lr_p=round(p_lr,4),
      r2_cox_snell=round(r2_cox_snell,3),
      r2_mcfadden=round(r2_mcfadden,3),
      nagelkerke_r2=round(r2_nagelkerke,3),
      pseudo_r2_requested=pseudo_r2_type,
      aic=round(AIC(modelo),3),
      parallel_lines_test=parallel_test,
      coefficients=coefs,
      distribution=split(dist_table, seq(nrow(dist_table))),
      significant=any(p_vals[names(coef(modelo))] < alpha),
      decision=if(any(p_vals[names(coef(modelo))]<alpha)) paste0("El predictor tiene efecto significativo sobre ",var_b_name," ordinal (p < ",alpha,")") else paste0("El predictor no tiene efecto significativo sobre ",var_b_name," ordinal")
    )
  }, error=function(e) list(error=e$message))
}
