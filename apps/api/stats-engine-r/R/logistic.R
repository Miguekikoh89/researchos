# ============================================================================
# ResearchOS - Regresion Logistica Binaria, Multinomial y Ordinal
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

classification_table <- function(y, p_hat, threshold=0.5) {
  pred <- ifelse(p_hat >= threshold, 1, 0)
  tp <- sum(y==1 & pred==1); tn <- sum(y==0 & pred==0)
  fp <- sum(y==0 & pred==1); fn <- sum(y==1 & pred==0)
  n  <- length(y)
  list(
    threshold_used=threshold,
    tp=tp, tn=tn, fp=fp, fn=fn,
    sensitivity = round(tp/(tp+fn),3),
    specificity = round(tn/(tn+fp),3),
    accuracy    = round((tp+tn)/n,3),
    overall_pct = round((tp+tn)/n*100,1)
  )
}

roc_auc <- function(y, p_hat) {
  tryCatch({
    thresholds <- sort(unique(c(0, p_hat, 1)), decreasing=TRUE)
    roc_pts <- lapply(thresholds, function(th) {
      pred <- ifelse(p_hat >= th, 1, 0)
      tp <- sum(y==1 & pred==1); fn <- sum(y==1 & pred==0)
      fp <- sum(y==0 & pred==1); tn <- sum(y==0 & pred==0)
      list(tpr=if((tp+fn)>0) tp/(tp+fn) else 0, fpr=if((fp+tn)>0) fp/(fp+tn) else 0)
    })
    tpr_v <- sapply(roc_pts, function(p) p$tpr)
    fpr_v <- sapply(roc_pts, function(p) p$fpr)
    ord <- order(fpr_v)
    fpr_s <- fpr_v[ord]; tpr_s <- tpr_v[ord]
    auc <- sum(diff(fpr_s) * (head(tpr_s,-1)+tail(tpr_s,-1))/2)
    auc_interp <- if(auc>=0.9)"Excelente" else if(auc>=0.8)"Bueno" else if(auc>=0.7)"Aceptable" else if(auc>=0.6)"Pobre" else "Sin discriminacion"
    n_points <- min(length(fpr_s), 25)
    sel_idx <- round(seq(1, length(fpr_s), length.out=n_points))
    list(auc=round(auc,3), auc_interpret=auc_interp,
         curve=lapply(sel_idx, function(i) list(fpr=round(fpr_s[i],3), tpr=round(tpr_s[i],3))))
  }, error=function(e) list(auc=NA, auc_interpret="No calculado", curve=list()))
}

compute_logistic_binary <- function(y, X, var_names=NULL, alpha=0.05, entry_method="enter", cut_point=0.5, do_hl="yes", do_roc="yes") {
  if (is.null(var_names)) var_names <- paste0("X",1:ncol(as.matrix(X)))
  X <- as.data.frame(lapply(as.data.frame(X), as.numeric))
  y <- as.numeric(y)
  # Guard F-007: bloquear binarizacion silenciosa — la VD debe ser exactamente binaria
  unique_y <- sort(unique(na.omit(y)))
  n_unique  <- length(unique_y)
  if (n_unique != 2) {
    return(list(
      blocked = TRUE,
      reason  = "VD_NO_BINARIA",
      error   = paste0(
        "La variable dependiente tiene ", n_unique, " valor",
        if (n_unique != 1) "es" else "", " unico",
        if (n_unique != 1) "s" else "",
        " [", paste(head(unique_y, 6), collapse=", "),
        if (n_unique > 6) ", ..." else "", "]. ",
        "La regresion logistica binaria requiere exactamente 2 categorias (evento vs. referencia). ",
        "Recodifique la variable dependiente en 0/1 en su archivo de datos, o seleccione ",
        "las dos categorias que representan el evento de interes vs. la referencia."
      )
    ))
  }
  # Exactamente 2 valores: recodificar a 0/1 si no lo son ya, sin cambiar cual es evento
  if (!all(y %in% c(0, 1))) {
    ref_val <- unique_y[1]; evt_val <- unique_y[2]
    y <- ifelse(y == evt_val, 1, 0)
  }
  valid <- complete.cases(y, X)
  y <- y[valid]; X <- X[valid,,drop=FALSE]
  n <- length(y); k <- ncol(X)
  if (n < k*10) warning(paste0("Muestra pequena: se recomienda n >= ", k*10, " eventos"))

  colnames(X) <- var_names
  df_model <- data.frame(y=y, X)

  model_null <- glm(y ~ 1, data=df_model, family=binomial)
  model_full_enter <- glm(y ~ ., data=df_model, family=binomial)

  method_l <- tolower(as.character(entry_method))
  if (method_l == "forward") {
    model_full <- step(model_null, scope=list(lower=model_null, upper=model_full_enter), direction="forward", trace=0)
  } else if (method_l == "backward") {
    model_full <- step(model_full_enter, direction="backward", trace=0)
  } else {
    model_full <- model_full_enter
  }
  vars_in_model <- setdiff(names(coef(model_full)), "(Intercept)")
  k <- length(vars_in_model)

  ll_null <- logLik(model_null)[1]
  ll_full <- logLik(model_full)[1]
  ll_ratio <- -2*(ll_null - ll_full)
  df_lr    <- k
  p_lr     <- pchisq(ll_ratio, df=df_lr, lower.tail=FALSE)

  n_obs    <- nrow(df_model)
  r2_cox   <- 1 - exp((2/n_obs)*(ll_null-ll_full))
  r2_max   <- 1 - exp((2/n_obs)*ll_null)
  r2_nagel <- r2_cox / r2_max

  sm <- summary(model_full)
  ci <- tryCatch(confint(model_full, level=1-alpha), error=function(e) matrix(NA,nrow=k+1,ncol=2))

  coefs <- lapply(rownames(sm$coefficients), function(nm) {
    b  <- sm$coefficients[nm,"Estimate"]
    se <- sm$coefficients[nm,"Std. Error"]
    z  <- sm$coefficients[nm,"z value"]
    p  <- sm$coefficients[nm,"Pr(>|z|)"]
    or <- exp(b)
    ci_l <- if(nm %in% rownames(ci)) exp(ci[nm,1]) else NA
    ci_u <- if(nm %in% rownames(ci)) exp(ci[nm,2]) else NA
    list(
      term        = nm,
      B           = round(b,3),
      SE          = round(se,3),
      Wald        = round(z^2,3),
      p           = round(p,4),
      p_apa       = if(p<.001)"< .001" else paste0("= ",formatC(p,digits=3,format="f")),
      OR          = round(or,3),
      OR_ci_lower = round(ci_l,3),
      OR_ci_upper = round(ci_u,3),
      significant = p < alpha
    )
  })

  vif_vals <- if(k>1) {
    lapply(vars_in_model, function(nm) {
      X_other <- X[,setdiff(vars_in_model,nm),drop=FALSE]
      r2_vif  <- summary(lm(X[[nm]]~.,data=X_other))$r.squared
      list(term=nm, vif=round(1/(1-r2_vif),3), interpretation=interpret_vif(1/(1-r2_vif)))
    })
  } else NULL

  p_hat <- fitted(model_full)
  cp <- as.numeric(cut_point)
  hl <- if(tolower(as.character(do_hl)) %in% c("yes","si","true","1")) hosmer_lemeshow(y, p_hat) else list(chi2=NA,df=NA,p=NA,ok=TRUE,interpretation="No solicitado")
  ct <- classification_table(y, p_hat, threshold=cp)
  roc <- if(tolower(as.character(do_roc)) %in% c("yes","si","true","1")) roc_auc(y, p_hat) else list(auc=NA, auc_interpret="No solicitado", curve=list())

  sig <- p_lr < alpha
  list(
    test_type    = "logistica_binaria",
    entry_method_used = method_l,
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
    roc          = roc,
    significant  = sig,
    decision     = if(sig)"Se rechaza H0" else "No se rechaza H0",
    alpha        = alpha
  )
}

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

  ctable <- coef(sm)
  p_vals <- 2*pnorm(abs(ctable[,"t value"]), lower.tail=FALSE)

  ci <- tryCatch(confint(model), error=function(e) NULL)
  coefs <- lapply(var_names, function(nm) {
    b  <- ctable[nm,"Value"]
    se <- ctable[nm,"Std. Error"]
    t  <- ctable[nm,"t value"]
    p  <- p_vals[nm]
    or <- exp(b)
    or_l <- if(!is.null(ci) && nm %in% rownames(ci)) exp(ci[nm,1]) else NA
    or_u <- if(!is.null(ci) && nm %in% rownames(ci)) exp(ci[nm,2]) else NA
    list(term=nm, B=round(b,3), SE=round(se,3),
         t=round(t,3), p=round(p,4),
         p_apa=if(p<.001)"< .001" else paste0("= ",formatC(p,digits=3,format="f")),
         OR=round(or,3), OR_ci_lower=round(or_l,3), OR_ci_upper=round(or_u,3), significant=p<alpha)
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

compute_logistic <- function(y, X, type="binaria", var_names=NULL, alpha=0.05, entry_method="enter", cut_point=0.5, hosmer_lemeshow="yes", roc_curve="yes", pseudo_r2="nagelkerke") {
  y <- as.numeric(unlist(y))
  X <- as.data.frame(lapply(as.data.frame(X), function(x) as.numeric(unlist(x))))
  if (type=="ordinal") return(compute_logistic_ordinal(y, X, var_names, alpha))
  return(compute_logistic_binary(y, X, var_names, alpha, entry_method, cut_point, hosmer_lemeshow, roc_curve))
}
