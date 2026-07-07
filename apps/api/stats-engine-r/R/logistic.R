# ============================================================================
# ResearchOS - Regresion Logistica Binaria, Multinomial y Ordinal
# Implementación verificable con glm y fórmulas reproducibles; sin equivalencia propietaria implícita.
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
    probs <- unique(quantile(p_hat, probs=seq(0,1,length.out=g+1), na.rm=TRUE, type=7))
    if (length(probs) < 4) stop("Probabilidades predichas insuficientemente distintas para Hosmer-Lemeshow.")
    probs[1] <- -Inf; probs[length(probs)] <- Inf
    grupos <- cut(p_hat, breaks=probs, include.lowest=TRUE, labels=FALSE)
    used <- sort(unique(grupos[!is.na(grupos)])); stat <- 0
    for (i in used) { idx <- grupos==i; o1<-sum(y[idx]);o0<-sum(1-y[idx]);e1<-sum(p_hat[idx]);e0<-sum(1-p_hat[idx]);if(e1>0)stat<-stat+(o1-e1)^2/e1;if(e0>0)stat<-stat+(o0-e0)^2/e0 }
    df <- length(used)-2; if(df<1)stop("Menos de 3 grupos efectivos en Hosmer-Lemeshow.")
    p <- pchisq(stat,df=df,lower.tail=FALSE)
    list(calculated=TRUE,chi2=as.numeric(stat),df=df,p=as.numeric(p),ok=isTRUE(p>=.05),groups_used=length(used),interpretation=if(p<.05)"Evidencia de falta de ajuste"else"Sin evidencia de falta de ajuste")
  },error=function(e)list(calculated=FALSE,chi2=NA_real_,df=NA_integer_,p=NA_real_,ok=NA,interpretation="No calculado",error=conditionMessage(e)))
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
    y <- as.integer(y); p_hat <- as.numeric(p_hat)
    ok <- is.finite(p_hat) & y %in% c(0L,1L); y <- y[ok]; p_hat <- p_hat[ok]
    n1 <- sum(y==1L); n0 <- sum(y==0L)
    if(n1==0L||n0==0L) stop("AUC requiere observaciones de ambas clases.")
    ranks <- rank(p_hat, ties.method="average")
    U <- sum(ranks[y==1L]) - n1*(n1+1)/2
    auc <- U/(n1*n0)
    thresholds <- c(Inf, sort(unique(p_hat), decreasing=TRUE), -Inf)
    roc_pts <- lapply(thresholds,function(th){pred<-as.integer(p_hat>=th);tp<-sum(y==1L&pred==1L);fn<-sum(y==1L&pred==0L);fp<-sum(y==0L&pred==1L);tn<-sum(y==0L&pred==0L);list(threshold=th,tpr=tp/(tp+fn),fpr=fp/(fp+tn))})
    n_points<-min(length(roc_pts),25L);sel<-unique(round(seq(1,length(roc_pts),length.out=n_points)))
    auc_interp<-if(auc>=.9)"Excelente"else if(auc>=.8)"Bueno"else if(auc>=.7)"Aceptable"else if(auc>=.6)"Pobre"else"Sin discriminación"
    list(auc=round(auc,3),auc_raw=as.numeric(auc),auc_method="Mann–Whitney/rangos con corrección de empates",auc_interpret=auc_interp,
      curve=lapply(sel,function(i)list(fpr=round(roc_pts[[i]]$fpr,3),tpr=round(roc_pts[[i]]$tpr,3))))
  },error=function(e)list(auc=NA_real_,auc_raw=NA_real_,auc_interpret="No calculado",curve=list(),error=conditionMessage(e)))
}

compute_logistic_binary <- function(y, X, var_names=NULL, alpha=0.05, entry_method="enter", cut_point=0.5, do_hl="yes", do_roc="yes", event_level=NULL) {
  if (is.null(var_names)) var_names <- paste0("X",1:ncol(as.matrix(X)))
  y_raw <- unlist(y, use.names=FALSE)
  X <- as.data.frame(lapply(as.data.frame(X), function(z)suppressWarnings(as.numeric(unlist(z)))), check.names=FALSE)
  y_chr <- trimws(as.character(y_raw))
  y_chr[is.na(y_raw) | y_chr==""] <- NA_character_
  unique_y <- unique(y_chr[!is.na(y_chr)])
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
  # Exactamente 2 valores: el evento debe ser explícito, salvo codificación inequívoca 0/1.
  avail <- as.character(unique_y)
  if (!is.null(event_level) && length(event_level)>0 && nzchar(as.character(event_level)[1])) {
    evt_char <- trimws(as.character(event_level)[1])
    if (!evt_char %in% avail) return(list(blocked=TRUE,reason="EVENTO_NO_ENCONTRADO",error=paste0("event_level='",evt_char,"' no encontrado. Disponibles: ",paste(avail,collapse=", "))))
  } else if (setequal(avail,c("0","1"))) {
    evt_char <- "1"
  } else {
    return(list(blocked=TRUE,reason="EVENTO_NO_DECLARADO",error=paste0("Declare event_level. Categorías observadas: ",paste(avail,collapse=", "))))
  }
  ref_char <- setdiff(avail,evt_char)[1]
  y <- ifelse(is.na(y_chr),NA_integer_,ifelse(y_chr==evt_char,1L,0L))
  valid <- complete.cases(y, X)
  y <- y[valid]; X <- X[valid,,drop=FALSE]
  n <- length(y); k <- ncol(X); events <- sum(y==1L); nonevents <- sum(y==0L); epv <- if(k>0)min(events,nonevents)/k else NA_real_
  sample_warning <- if(is.finite(epv)&&epv<10)paste0("Eventos por predictor = ",round(epv,2),"; interpretar con cautela.")else NULL

  original_names <- as.character(var_names); safe_names <- make.names(original_names,unique=TRUE); colnames(X) <- safe_names
  term_display <- setNames(original_names,safe_names)
  df_model <- data.frame(y=y, X)

  model_null <- glm(y ~ 1, data=df_model, family=binomial)
  model_full_enter <- glm(y ~ ., data=df_model, family=binomial)

  method_l <- tolower(as.character(entry_method))
  if (!(method_l %in% c("enter", "simultaneo", "simultaneous"))) {
    return(list(blocked=TRUE, reason="SELECCION_AUTOMATICA_NO_VALIDADA",
                error="Forward/backward AIC no equivalen al procedimiento SPSS y permanecen bloqueados. Use ENTER."))
  }
  method_l <- "enter"
  model_full <- model_full_enter
  if (!isTRUE(model_full$converged) || any(!is.finite(coef(model_full)))) {
    return(list(blocked=TRUE, reason="NO_CONVERGENCIA", error="La regresión logística no convergió o produjo coeficientes no finitos."))
  }
  separation_warning <- any(abs(coef(model_full)) > 20) || any(summary(model_full)$coefficients[,"Std. Error"] > 1000) ||
    any(fitted(model_full) < 1e-8 | fitted(model_full) > 1-1e-8)
  if (separation_warning) {
    return(list(blocked=TRUE, reason="SEPARACION", error="Se detectó separación completa/cuasi-completa; los OR y valores p no son confiables."))
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
      term_display = if(nm=="(Intercept)")"(Intercept)"else if(nm %in% names(term_display)) unname(term_display[nm]) else nm,
      B           = round(b,3),
      B_raw       = as.numeric(b),
      SE          = round(se,3),
      SE_raw      = as.numeric(se),
      Wald        = round(z^2,3),
      Wald_raw    = as.numeric(z^2),
      p           = as.numeric(p),
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
      r2_vif  <- tryCatch(summary(lm(X[[nm]]~.,data=X_other))$r.squared,error=function(e)NA_real_)
      vv <- if(!is.finite(r2_vif)||r2_vif>=1)Inf else 1/(1-r2_vif)
      list(term=nm,term_display=if(nm %in% names(term_display)) unname(term_display[nm]) else nm,vif=if(is.finite(vv))round(vv,3)else Inf,interpretation=interpret_vif(vv))
    })
  } else NULL

  p_hat <- fitted(model_full)
  cp <- as.numeric(cut_point)
  hl <- if(tolower(as.character(do_hl)) %in% c("yes","si","true","1")) hosmer_lemeshow(y, p_hat) else list(chi2=NA,df=NA,p=NA,ok=TRUE,interpretation="No solicitado")
  ct <- classification_table(y, p_hat, threshold=cp)
  roc <- if(tolower(as.character(do_roc)) %in% c("yes","si","true","1")) roc_auc(y, p_hat) else list(auc=NA, auc_interpret="No solicitado", curve=list())

  sig <- p_lr < alpha
  list(
    test_type       = "logistica_binaria",
    entry_method_used = method_l,
    event_level     = evt_char,
    reference_level = ref_char,
    n            = n,
    k            = k,
    events       = events,
    non_events   = nonevents,
    events_per_predictor = epv,
    sample_warning = sample_warning,
    ll_null      = round(ll_null,3),
    ll_full      = round(ll_full,3),
    ll_ratio     = round(ll_ratio,3),
    df_lr        = df_lr,
    p_lr         = as.numeric(p_lr),
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

compute_logistic <- function(y, X, type="binaria", var_names=NULL, alpha=0.05, entry_method="enter", cut_point=0.5, hosmer_lemeshow="yes", roc_curve="yes", pseudo_r2="nagelkerke", event_level=NULL) {
  X <- as.data.frame(lapply(as.data.frame(X), function(x) suppressWarnings(as.numeric(unlist(x)))))
  if (type=="ordinal") return(list(blocked=TRUE,reason="RUTA_ORDINAL_DUPLICADA",error="Use el módulo canónico de regresión ordinal."))
  return(compute_logistic_binary(y, X, var_names, alpha, entry_method, cut_point, hosmer_lemeshow, roc_curve, event_level=event_level))
}
