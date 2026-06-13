# ============================================================================
# ResearchOS — Regresion Logistica Binaria, Multinomial y Ordinal
# Ref: SPSS Statistics 29, Hosmer & Lemeshow(2000), Field(2013)
# ============================================================================

interpret_nagelkerke <- function(r2) {
  if (is.na(r2)) return("indeterminado")
  if (r2 >= 0.50) return("grande")
  if (r2 >= 0.30) return("mediano")
  if (r2 >= 0.10) return("pequeno")
  return("trivial")
}

interpret_vif <- function(vif) {
  if (is.na(vif)) return("OK")
  if (vif >= 10) return("Multicolinealidad grave")
  if (vif >= 5)  return("Multicolinealidad moderada")
  return("OK")
}


# ── Hosmer-Lemeshow goodness of fit ─────────────────────────────────────────
hosmer_lemeshow <- function(y, p_hat, g=10) {
  tryCatch({
    n <- length(y)
    cuts <- quantile(p_hat, probs=seq(0,1,1/g), na.rm=TRUE)
    cuts[1] <- cuts[1] - 0.001
    grupos <- cut(p_hat, breaks=cuts, labels=FALSE)
    hl_stat <- 0
    for (i in 1:g) {
      idx <- grupos==i & !is.na(grupos)
      if (sum(idx)==0) next
      obs1 <- sum(y[idx]); obs0 <- sum(1-y[idx])
      exp1 <- sum(p_hat[idx]); exp0 <- sum(1-p_hat[idx])
      if (exp1>0) hl_stat <- hl_stat + (obs1-exp1)^2/exp1
      if (exp0>0) hl_stat <- hl_stat + (obs0-exp0)^2/exp0
    }
    p <- pchisq(hl_stat, df=g-2, lower.tail=FALSE)
    list(chi2=round(hl_stat,3), df=g-2, p=round(p,4),
         ok=p>=0.05,
         interpretation=if(p<0.05)"Mal ajuste del modelo" else "Buen ajuste del modelo")
  }, error=function(e) list(chi2=NA,df=NA,p=NA,ok=TRUE,interpretation="No calculado"))
}

# ── Tabla de clasificacion ───────────────────────────────────────────────────
classification_table <- function(y, p_hat, threshold=0.5) {
  pred <- ifelse(p_hat >= threshold, 1, 0)
  tp <- sum(y==1 & pred==1); tn <- sum(y==0 & pred==0)
  fp <- sum(y==0 & pred==1); fn <- sum(y==1 & pred==0)
  n  <- length(y)
  list(
    tp=tp, tn=tn, fp=fp, fn=fn,
    sensitivity = round(tp/(tp+fn),3),
    specificity = round(tn/(tn+fp),3),
    accuracy    = round((tp+tn)/n,3),
    overall_pct = round((tp+tn)/n*100,1)
  )
}

# ── Regresion Logistica Binaria ──────────────────────────────────────────────
compute_logistic_binary <- function(y, X, var_names=NULL, alpha=0.05) {
  if (is.null(var_names)) var_names <- paste0("X",1:ncol(as.matrix(X)))
  X <- as.data.frame(lapply(as.data.frame(X), as.numeric))
  y <- as.numeric(y)
  # Binarizar si no lo es
  if (!all(y %in% c(0,1))) {
    threshold <- median(y, na.rm=TRUE)
    y <- ifelse(y > threshold, 1, 0)
  }
  valid <- complete.cases(y, X)
  y <- y[valid]; X <- X[valid,,drop=FALSE]
  n <- length(y); k <- ncol(X)
  if (n < k*10) warning(paste0("Muestra pequena: se recomienda n >= ", k*10, " eventos"))

  colnames(X) <- var_names
  df_model <- data.frame(y=y, X)
  
  # Modelo nulo y completo
  model_null <- glm(y ~ 1, data=df_model, family=binomial)
  model_full <- glm(y ~ ., data=df_model, family=binomial)
  
  # Estadisticos del modelo
  ll_null <- logLik(model_null)[1]
  ll_full <- logLik(model_full)[1]
  ll_ratio <- -2*(ll_null - ll_full)
  df_lr    <- k
  p_lr     <- pchisq(ll_ratio, df=df_lr, lower.tail=FALSE)
  
  # R2 pseudos
  n_obs    <- nrow(df_model)
  r2_cox   <- 1 - exp((2/n_obs)*(ll_null-ll_full))
  r2_max   <- 1 - exp((2/n_obs)*ll_null)
  r2_nagel <- r2_cox / r2_max
  
  # Coeficientes
  sm <- summary(model_full)
  ci <- tryCatch(confint(model_full, level=1-alpha), error=function(e) matrix(NA,nrow=k+1,ncol=2))
  
  coefs <- lapply(rownames(sm$coefficients), function(nm) {
    b  <- sm$coefficients[nm,"Estimate"]
    se <- sm$coefficients[nm,"Std. Error"]
    z  <- sm$coefficients[nm,"z value"]
    p  <- sm$coefficients[nm,"Pr(>|z|)"]
    or <- exp(b)
    list(
      term        = nm,
      B           = round(b,3),
      SE          = round(se,3),
      Wald        = round(z^2,3),
      p           = round(p,4),
      p_apa       = if(p<.001)"< .001" else paste0("= ",formatC(p,digits=3,format="f")),
      OR          = round(or,3),
      OR_ci_lower = round(exp(ci[nm,1]),3),
      OR_ci_upper = round(exp(ci[nm,2]),3),
      significant = p < alpha
    )
  })
  
  # VIF
  vif_vals <- if(k>1) {
    lapply(var_names, function(nm) {
      X_other <- X[,setdiff(var_names,nm),drop=FALSE]
      r2_vif  <- summary(lm(X[[nm]]~.,data=X_other))$r.squared
      list(term=nm, vif=round(1/(1-r2_vif),3), interpretation=interpret_vif(1/(1-r2_vif)))
    })
  } else NULL
  
  # Hosmer-Lemeshow
  p_hat <- fitted(model_full)
  hl    <- hosmer_lemeshow(y, p_hat)
  ct    <- classification_table(y, p_hat)
  
  sig <- p_lr < alpha
  list(
    test_type    = "logistica_binaria",
    n            = n,
    k            = k,
    ll_null      = round(ll_null,3),
    ll_full      = round(ll_full,3),
    ll_ratio     = round(ll_ratio,3),
    df_lr        = df_lr,
    p_lr         = round(p_lr,4),
    p_apa        = if(p_lr<.001)"< .001" else paste0("= ",formatC(p_lr,digits=3,format="f")),
    r2_cox_snell = round(r2_cox,3),
    r2_nagelkerke= round(r2_nagel,3),
    r2_interpret = interpret_nagelkerke(r2_nagel),
    coefficients = coefs,
    vif          = vif_vals,
    hosmer_lemeshow = hl,
    classification  = ct,
    significant  = sig,
    decision     = if(sig)"Se rechaza H0" else "No se rechaza H0",
    alpha        = alpha
  )
}

# ── Regresion Logistica Ordinal ──────────────────────────────────────────────
compute_logistic_ordinal <- function(y, X, var_names=NULL, alpha=0.05) {
  if (!requireNamespace("MASS", quietly=TRUE)) return(list(error="Paquete MASS no disponible"))
  if (is.null(var_names)) var_names <- paste0("X",1:ncol(as.matrix(X)))
  X <- as.data.frame(lapply(as.data.frame(X), as.numeric))
  y_ord <- factor(y, ordered=TRUE)
  valid <- complete.cases(y_ord, X)
  y_ord <- y_ord[valid]; X <- X[valid,,drop=FALSE]
  n <- length(y_ord); k <- ncol(X)
  colnames(X) <- var_names
  df_model <- data.frame(y=y_ord, X)
  
  model <- MASS::polr(y ~ ., data=df_model, Hess=TRUE)
  sm    <- summary(model)
  
  # p-values (polr no los incluye directamente)
  ctable <- coef(sm)
  p_vals <- 2*pnorm(abs(ctable[,"t value"]), lower.tail=FALSE)
  
  coefs <- lapply(var_names, function(nm) {
    b  <- ctable[nm,"Value"]
    se <- ctable[nm,"Std. Error"]
    t  <- ctable[nm,"t value"]
    p  <- p_vals[nm]
    or <- exp(b)
    list(term=nm, B=round(b,3), SE=round(se,3),
         t=round(t,3), p=round(p,4),
         p_apa=if(p<.001)"< .001" else paste0("= ",formatC(p,digits=3,format="f")),
         OR=round(or,3), significant=p<alpha)
  })
  
  ll_null <- logLik(MASS::polr(y~1,data=df_model,Hess=TRUE))[1]
  ll_full <- logLik(model)[1]
  ll_ratio<- -2*(ll_null-ll_full)
  p_lr    <- pchisq(ll_ratio, df=k, lower.tail=FALSE)
  r2_nagel<- (1-exp((2/n)*(ll_null-ll_full)))/(1-exp((2/n)*ll_null))
  
  list(
    test_type    = "logistica_ordinal",
    n=n, k=k,
    ll_ratio     = round(ll_ratio,3),
    p_apa        = if(p_lr<.001)"< .001" else paste0("= ",formatC(p_lr,digits=3,format="f")),
    r2_nagelkerke= round(r2_nagel,3),
    r2_interpret = interpret_nagelkerke(r2_nagel),
    coefficients = coefs,
    significant  = p_lr < alpha,
    decision     = if(p_lr<alpha)"Se rechaza H0" else "No se rechaza H0",
    alpha        = alpha
  )
}

# ── Funcion principal ─────────────────────────────────────────────────────────
compute_logistic <- function(y, X, type="binaria", var_names=NULL, alpha=0.05) {
  y <- as.numeric(unlist(y))
  X <- as.data.frame(lapply(as.data.frame(X), function(x) as.numeric(unlist(x))))
  if (type=="ordinal") return(compute_logistic_ordinal(y, X, var_names, alpha))
  return(compute_logistic_binary(y, X, var_names, alpha))
}
