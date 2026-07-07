# ============================================================================
# CanchariOS - Regresión lineal simple y múltiple reproducible
# 7 supuestos: linealidad, independencia, homocedasticidad, normalidad
# residuos, no multicolinealidad, no outliers, especificacion correcta
# Método habilitado: ENTER. Stepwise/forward/backward permanecen bloqueados.
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
  n <- length(residuals); den <- sum(residuals^2)
  if(n < 2 || !is.finite(den) || den <= 0) return(list(dw=NA_real_,ok=NA,interpretation="No calculado"))
  dw <- sum(diff(residuals)^2) / den
  list(dw=round(dw,3), dw_raw=as.numeric(dw), ok=dw>=1.5 && dw<=2.5,
       interpretation=if(dw<1.5)"Autocorrelacion positiva" else if(dw>2.5)"Autocorrelacion negativa" else "Sin autocorrelacion")
}

check_breusch_pagan <- function(model) {
  tryCatch({
    mm <- model.matrix(model)
    if (ncol(mm) <= 1) stop("El modelo no contiene predictores.")
    X <- as.data.frame(mm[, -1, drop=FALSE])
    res2 <- residuals(model)^2
    aux <- lm(res2 ~ ., data=X)
    statistic <- length(res2) * summary(aux)$r.squared
    df <- ncol(X)
    p <- pchisq(statistic, df=df, lower.tail=FALSE)
    list(statistic=round(as.numeric(statistic),3), df=df, p=round(as.numeric(p),4), ok=isTRUE(p>=0.05),
         interpretation=if(p<0.05)"Heterocedasticidad detectada" else "Homocedasticidad compatible")
  }, error=function(e) list(statistic=NA_real_,df=NA_integer_,p=NA_real_,ok=NA,
                            interpretation="No calculado",error=conditionMessage(e)))
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
    list(F=round(F_reset,3), p=round(as.numeric(p_reset),4),
         ok=p_reset>=0.05,
         interpretation=if(p_reset<0.05)"Posible mal especificacion del modelo" else "Especificacion correcta")
  }, error=function(e) list(F=NA_real_,p=NA_real_,ok=NA,interpretation="No calculado",error=conditionMessage(e)))
}

# -- Regresion lineal (simple y multiple), con metodos de entrada SPSS -------

compute_regression <- function(y, X, var_names=NULL, alpha=0.05, method="enter", check_assumptions="yes", vif_threshold=5, coef_ci=0.95, handle_outliers="report") {
  if (is.null(var_names)) var_names <- paste0("X", 1:ncol(as.matrix(X)))

  X <- as.data.frame(lapply(as.data.frame(X), as.numeric))
  y <- as.numeric(y)
  valid <- complete.cases(y, X)
  y <- y[valid]; X <- X[valid,, drop=FALSE]
  n <- length(y); n_initial <- n; k <- ncol(X)

  if (n < k+3) return(list(error="Muestra insuficiente"))

  colnames(X) <- var_names
  df_model <- data.frame(y=y, X)

  outliers_removed <- 0; removed_case_ids <- integer(0)
  if (tolower(as.character(handle_outliers)) %in% c("remove","eliminar")) {
    mod_tmp <- lm(y ~ ., data=df_model)
    cd_tmp <- cooks.distance(mod_tmp)
    thr_tmp <- 4/n
    keep <- cd_tmp <= thr_tmp
    outliers_removed <- sum(!keep); removed_case_ids <- which(!keep)
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

  if (!(method_l %in% c("enter", "simultaneo", "simultaneous"))) {
    return(list(
      blocked = TRUE,
      reason  = "SELECCION_AUTOMATICA_NO_VALIDADA",
      stage   = "regression",
      error   = "Stepwise/forward/backward basados en AIC no equivalen al procedimiento SPSS y permanecen bloqueados. Use método ENTER."
    ))
  }
  method_l <- "enter"
  model <- full_model
  vars_in_model <- setdiff(names(coef(model)), "(Intercept)")
  k <- length(vars_in_model)
  sm <- summary(model)
  model_data <- model.frame(model)
  y_model <- model.response(model_data)
  X_model <- model_data[, setdiff(names(model_data), names(model_data)[1]), drop=FALSE]

  coef_table <- as.data.frame(coef(sm))
  coef_ci <- as.numeric(coef_ci)
  if (!is.finite(coef_ci) || coef_ci <= 0 || coef_ci >= 1) coef_ci <- 0.95
  ci <- confint(model, level=coef_ci)

  coefs <- lapply(rownames(coef_table), function(nm) {
    b   <- coef_table[nm,"Estimate"]
    se  <- coef_table[nm,"Std. Error"]
    t   <- coef_table[nm,"t value"]
    p   <- coef_table[nm,"Pr(>|t|)"]
    list(
      term     = nm,
      B        = round(b, 3),
      B_raw    = as.numeric(b),
      SE       = round(se, 3),
      SE_raw   = as.numeric(se),
      beta     = if(nm=="(Intercept)") NA else {
        # R convierte nombres con espacios a puntos en la tabla de coeficientes
        # (ej. "Calidad de servicio" -> "Calidad.de.servicio"), por lo que la
        # comparacion directa nm %in% colnames(X) fallaba siempre para
        # variables con espacios en su nombre, devolviendo NA incorrectamente.
        orig_col <- colnames(X_model)[make.names(colnames(X_model)) == nm]
        if (length(orig_col) == 0) NA else round(b * sd(X_model[[orig_col[1]]], na.rm=TRUE) / sd(y_model, na.rm=TRUE), 3)
      },
      t        = round(t, 3),
      t_raw    = as.numeric(t),
      p        = as.numeric(p),
      p_apa    = if(p<.001)"< .001" else paste0("= ",formatC(p,digits=3,format="f")),
      ci_lower = round(ci[nm,1], 3),
      ci_upper = round(ci[nm,2], 3),
      significant = p < alpha
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
      lapply(vars_in_model, function(nm) {
        orig <- colnames(X_model)[make.names(colnames(X_model)) == nm]
        if (length(orig) != 1) return(list(term=nm,vif=NA_real_,interpretation="No calculado"))
        others <- setdiff(colnames(X_model), orig)
        r2_vif <- summary(lm(X_model[[orig]] ~ ., data=X_model[,others,drop=FALSE]))$r.squared
        vv <- 1/(1-r2_vif)
        list(term=nm,vif=as.numeric(vv),interpretation=interpret_vif_dyn(vv,as.numeric(vif_threshold)))
      })
    }, error=function(e) NULL)
  } else NULL

  do_assumptions <- tolower(as.character(check_assumptions)) %in% c("yes","si","true","1")
  assumptions <- NULL
  if (do_assumptions) {
    resids <- residuals(model)
    sw_resid <- if(length(resids)>=3 && length(resids)<=5000 && length(unique(resids))>1)
      tryCatch(shapiro.test(resids), error=function(e) NULL) else NULL
    assumptions <- list(
      normality_residuals = if(is.null(sw_resid)) list(
        calculated=FALSE,W=NA_real_,p=NA_real_,ok=NA,
        interpretation="No calculado: Shapiro–Wilk requiere 3–5000 residuos no constantes"
      ) else list(
        calculated=TRUE,W=round(as.numeric(sw_resid$statistic),4),p=round(as.numeric(sw_resid$p.value),4),
        ok=isTRUE(sw_resid$p.value>=alpha),
        interpretation=if(sw_resid$p.value<alpha)"Residuos no normales" else "Residuos compatibles con normalidad"
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
    p             = as.numeric(p_model),
    p_apa         = if(p_model<.001)"< .001" else paste0("= ",formatC(p_model,digits=3,format="f"))
  )

  sig <- p_model < alpha

  list(
    test_type    = if(k==1)"regresion_simple" else "regresion_multiple",
    method_used  = method_l,
    outliers_removed = outliers_removed,
    removed_case_ids = as.integer(removed_case_ids),
    n_initial    = n_initial,
    n            = n,
    k            = k,
    R            = round(r,3),
    R_raw        = as.numeric(r),
    R2           = round(r2,3),
    R2_raw       = as.numeric(r2),
    R2_adj       = round(r2_adj,3),
    R2_adj_raw   = as.numeric(r2_adj),
    R2_interpret = interpret_r2(r2),
    SE_est       = round(se_est,3),
    F            = round(f_stat,3),
    F_raw        = as.numeric(f_stat),
    df1          = df1,
    df2          = df2,
    p            = as.numeric(p_model),
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
