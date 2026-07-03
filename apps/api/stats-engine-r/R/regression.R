# ============================================================================
# ResearchOS - Regresion Lineal Simple y Multiple SPSS-identico
# 7 supuestos: linealidad, independencia, homocedasticidad, normalidad
# residuos, no multicolinealidad, no outliers, especificacion correcta
# Metodos de entrada: Enter, Stepwise, Forward, Backward
# Ref: SPSS Statistics 29, Cohen(1988), Field(2013)
# ============================================================================

interpret_r2 <- function(r2) {
  if (is.na(r2)) return("indeterminado")
  if (r2 >= 0.26) return("grande")
  if (r2 >= 0.13) return("mediano")
  if (r2 >= 0.02) return("pequeno")
  return("trivial")
}

interpret_vif_dyn <- function(vif, threshold=5) {
  if (is.na(vif)) return("OK")
  if (vif >= threshold*2) return("Multicolinealidad grave")
  if (vif >= threshold)  return("Multicolinealidad moderada")
  return("OK")
}

check_durbin_watson <- function(residuals) {
  n <- length(residuals)
  dw <- sum(diff(residuals)^2) / sum(residuals^2)
  list(dw=round(dw,3), ok=dw>=1.5 && dw<=2.5,
       interpretation=if(dw<1.5)"Autocorrelacion positiva" else if(dw>2.5)"Autocorrelacion negativa" else "Sin autocorrelacion")
}

check_breusch_pagan <- function(model) {
  tryCatch({
    res2 <- residuals(model)^2
    fitted_vals <- fitted(model)
    bp_model <- lm(res2 ~ fitted_vals)
    n <- length(res2)
    r2_bp <- summary(bp_model)$r.squared
    chi2 <- n * r2_bp
    p <- pchisq(chi2, df=1, lower.tail=FALSE)
    list(statistic=round(chi2,3), p=round(p,4),
         ok=p>=0.05, interpretation=if(p<0.05)"Heterocedasticidad detectada" else "Homocedasticidad OK")
  }, error=function(e) list(statistic=NA,p=NA,ok=TRUE,interpretation="No calculado"))
}

check_cooks <- function(model, threshold=NULL) {
  n <- length(fitted(model))
  k <- length(coef(model)) - 1
  if (is.null(threshold)) threshold <- 4/n
  cd <- cooks.distance(model)
  outliers <- which(cd > threshold)
  list(threshold=round(threshold,4), n_outliers=length(outliers),
       outlier_ids=as.integer(outliers),
       ok=length(outliers)==0,
       interpretation=if(length(outliers)>0) paste0(length(outliers)," punto(s) influyente(s) detectado(s)") else "Sin outliers influyentes")
}

check_reset <- function(model) {
  tryCatch({
    y_hat <- fitted(model)
    y_hat2 <- y_hat^2
    y_hat3 <- y_hat^3
    data_ext <- data.frame(model.frame(model), y_hat2=y_hat2, y_hat3=y_hat3)
    formula_ext <- update(formula(model), . ~ . + y_hat2 + y_hat3)
    model_ext <- lm(formula_ext, data=data_ext)
    n <- length(fitted(model))
    k_orig <- length(coef(model)) - 1
    r2_orig <- summary(model)$r.squared
    r2_ext  <- summary(model_ext)$r.squared
    F_reset <- ((r2_ext - r2_orig)/2) / ((1-r2_ext)/(n-k_orig-3))
    p_reset <- pf(F_reset, 2, n-k_orig-3, lower.tail=FALSE)
    list(F=round(F_reset,3), p=round(p_reset,4),
         ok=p_reset>=0.05,
         interpretation=if(p_reset<0.05)"Posible mal especificacion del modelo" else "Especificacion correcta")
  }, error=function(e) list(F=NA,p=NA,ok=TRUE,interpretation="No calculado"))
}

# -- Regresion lineal (simple y multiple), con metodos de entrada SPSS -------

compute_regression <- function(y, X, var_names=NULL, alpha=0.05, method="enter", check_assumptions="yes", vif_threshold=5, coef_ci=0.95, handle_outliers="report") {
  if (is.null(var_names)) var_names <- paste0("X", 1:ncol(as.matrix(X)))

  X <- as.data.frame(lapply(as.data.frame(X), as.numeric))
  y <- as.numeric(y)
  valid <- complete.cases(y, X)
  y <- y[valid]; X <- X[valid,, drop=FALSE]
  n <- length(y); k <- ncol(X)

  if (n < k+3) return(list(error="Muestra insuficiente"))

  colnames(X) <- var_names
  df_model <- data.frame(y=y, X)

  outliers_removed <- 0
  if (tolower(as.character(handle_outliers)) %in% c("remove","eliminar")) {
    mod_tmp <- lm(y ~ ., data=df_model)
    cd_tmp <- cooks.distance(mod_tmp)
    thr_tmp <- 4/n
    keep <- cd_tmp <= thr_tmp
    outliers_removed <- sum(!keep)
    if (outliers_removed > 0 && outliers_removed < n - k - 2) {
      df_model <- df_model[keep,]
      y <- df_model$y
      n <- nrow(df_model)
    }
  }

  method_l <- tolower(as.character(method))
  full_model <- lm(y ~ ., data=df_model)

  # P2-SINGULAR: detectar coeficientes aliasados (predictores linealmente dependientes)
  aliased <- is.na(coef(full_model))
  if (any(aliased)) {
    return(list(
      blocked = TRUE,
      reason  = "MODELO_SINGULAR",
      stage   = "regression",
      error   = paste0("Predictores linealmente dependientes: ",
                       paste(names(coef(full_model))[aliased], collapse=", "))
    ))
  }

  if (method_l == "stepwise") {
    model <- step(full_model, direction="both", trace=0)
  } else if (method_l == "forward") {
    null_model <- lm(y ~ 1, data=df_model)
    model <- step(null_model, scope=list(lower=null_model, upper=full_model), direction="forward", trace=0)
  } else if (method_l == "backward") {
    model <- step(full_model, direction="backward", trace=0)
  } else {
    model <- full_model
  }
  vars_in_model <- setdiff(names(coef(model)), "(Intercept)")
  k <- length(vars_in_model)
  sm <- summary(model)

  coef_table <- as.data.frame(coef(sm))
  ci_alpha <- 1 - as.numeric(coef_ci)
  ci <- confint(model, level=1-ci_alpha)

  coefs <- lapply(rownames(coef_table), function(nm) {
    b   <- coef_table[nm,"Estimate"]
    se  <- coef_table[nm,"Std. Error"]
    t   <- coef_table[nm,"t value"]
    p   <- coef_table[nm,"Pr(>|t|)"]
    list(
      term     = nm,
      B        = round(b, 3),
      SE       = round(se, 3),
      beta     = if(nm=="(Intercept)") NA else {
        # R convierte nombres con espacios a puntos en la tabla de coeficientes
        # (ej. "Calidad de servicio" -> "Calidad.de.servicio"), por lo que la
        # comparacion directa nm %in% colnames(X) fallaba siempre para
        # variables con espacios en su nombre, devolviendo NA incorrectamente.
        orig_col <- colnames(X)[make.names(colnames(X)) == nm]
        if (length(orig_col) == 0) NA else round(b * sd(X[[orig_col[1]]], na.rm=TRUE) / sd(y, na.rm=TRUE), 3)
      },
      t        = round(t, 3),
      p        = round(p, 4),
      p_apa    = if(p<.001)"< .001" else paste0("= ",formatC(p,digits=3,format="f")),
      ci_lower = round(ci[nm,1], 3),
      ci_upper = round(ci[nm,2], 3),
      significant = p < ci_alpha
    )
  })

  r2      <- sm$r.squared
  r2_adj  <- sm$adj.r.squared
  r       <- sqrt(r2)
  se_est  <- sm$sigma
  f_stat  <- sm$fstatistic[1]
  df1     <- sm$fstatistic[2]
  df2     <- as.integer(sm$fstatistic[3])
  p_model <- pf(f_stat, df1, df2, lower.tail=FALSE)

  vif_vals <- if (k > 1) {
    tryCatch({
      vif_list <- lapply(vars_in_model, function(nm) {
        X_other <- X[, setdiff(vars_in_model, nm), drop=FALSE]
        r2_vif  <- summary(lm(X[[nm]] ~ ., data=X_other))$r.squared
        1/(1-r2_vif)
      })
      names(vif_list) <- vars_in_model
      lapply(vars_in_model, function(nm) list(
        term=nm, vif=round(vif_list[[nm]],3),
        interpretation=interpret_vif_dyn(vif_list[[nm]], as.numeric(vif_threshold))
      ))
    }, error=function(e) NULL)
  } else NULL

  do_assumptions <- tolower(as.character(check_assumptions)) %in% c("yes","si","true","1")
  assumptions <- NULL
  if (do_assumptions) {
    resids <- residuals(model)
    sw_resid <- tryCatch(shapiro.test(resids), error=function(e) list(statistic=NA,p.value=1))
    assumptions <- list(
      normality_residuals = list(
        W=round(sw_resid$statistic,4), p=round(sw_resid$p.value,4),
        ok=sw_resid$p.value>=alpha,
        interpretation=if(sw_resid$p.value<alpha)"Residuos no normales" else "Residuos normales"
      ),
      independence = check_durbin_watson(resids),
      homoscedasticity = check_breusch_pagan(model),
      influential_cases = check_cooks(model),
      model_specification = check_reset(model)
    )
  }

  resids <- residuals(model)
  anova_table <- list(
    ss_regression = round(sum((fitted(model)-mean(y))^2),3),
    ss_residual   = round(sum(resids^2),3),
    ss_total      = round(sum((y-mean(y))^2),3),
    df_regression = k,
    df_residual   = n-k-1,
    ms_regression = round(sum((fitted(model)-mean(y))^2)/k,3),
    ms_residual   = round(sum(resids^2)/(n-k-1),3),
    F             = round(f_stat,3),
    p             = round(p_model,4),
    p_apa         = if(p_model<.001)"< .001" else paste0("= ",formatC(p_model,digits=3,format="f"))
  )

  sig <- p_model < alpha

  list(
    test_type    = if(k==1)"regresion_simple" else "regresion_multiple",
    method_used  = method_l,
    outliers_removed = outliers_removed,
    n            = n,
    k            = k,
    R            = round(r,3),
    R2           = round(r2,3),
    R2_adj       = round(r2_adj,3),
    R2_interpret = interpret_r2(r2),
    SE_est       = round(se_est,3),
    F            = round(f_stat,3),
    df1          = df1,
    df2          = df2,
    p            = round(p_model,4),
    p_apa        = if(p_model<.001)"< .001" else paste0("= ",formatC(p_model,digits=3,format="f")),
    coefficients = coefs,
    vif          = vif_vals,
    vif_threshold_used = as.numeric(vif_threshold),
    anova_table  = anova_table,
    assumptions  = assumptions,
    significant  = sig,
    decision     = if(sig)"Se rechaza H0" else "No se rechaza H0",
    alpha        = alpha
  )
}
