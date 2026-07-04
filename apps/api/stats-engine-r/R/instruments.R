# ============================================================================
# ResearchOS — Módulo Validación de Instrumentos Psicométricos
# Portado desde Validador Psicométrico v6.0
# Métodos: Cronbach, Omega, CR, AVE, KMO, Bartlett, AFE, AFC, HTMT, V-Aiken
# ============================================================================

`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && !is.na(a[1])) a else b

# ── CR y AVE desde cargas (Fornell & Larcker 1981) ──────────────────────────
calc_cr_ave <- function(lambdas) {
  lambdas <- abs(lambdas[!is.na(lambdas)])
  if (length(lambdas) < 2) return(list(cr=NA, ave=NA))
  # Fornell-Larcker (1981): sin clipping — cargas estandarizadas sin restricción
  theta <- 1 - lambdas^2
  cr  <- round(sum(lambdas)^2 / (sum(lambdas)^2 + sum(theta)), 3)
  ave <- round(sum(lambdas^2) / length(lambdas), 3)
  list(cr=cr, ave=ave)
}

# ── KMO + Bartlett ──────────────────────────────────────────────────────────
compute_kmo <- function(data_mat) {
  tryCatch({
    complete <- data_mat[complete.cases(data_mat),,drop=FALSE]
    if (nrow(complete) < 10) stop("Casos completos insuficientes para KMO/Bartlett.")
    R <- cor(complete, use="complete.obs")
    kmo <- psych::KMO(R)
    bart <- psych::cortest.bartlett(R, n=nrow(complete))
    kmo_v <- round(kmo$MSA, 3)
    interp <- if(kmo_v>=.90)"Excelente" else if(kmo_v>=.80)"Muy bueno" else if(kmo_v>=.70)"Aceptable" else if(kmo_v>=.60)"Mediocre" else if(kmo_v>=.50)"Pobre" else "Inaceptable"
    list(
      kmo_overall    = kmo_v,
      kmo_interpret  = interp,
      kmo_items      = round(kmo$MSAi, 3),
      bartlett_chi2  = round(bart$chisq, 3),
      bartlett_df    = bart$df,
      bartlett_p     = round(bart$p.value, 4),
      bartlett_p_apa = if(bart$p.value<.001)"< .001" else paste0("= ",round(bart$p.value,4)),
      factorizable   = kmo_v >= 0.50 && bart$p.value < 0.05
    )
  }, error=function(e) list(error=e$message))
}

# ── Normalidad multivariante Mardia ─────────────────────────────────────────
compute_normality_items <- function(data_mat) {
  tryCatch({
    items_num <- data_mat[, sapply(data_mat, is.numeric), drop=FALSE]
    items_num <- items_num[complete.cases(items_num), ]
    por_item <- data.frame(
      item     = colnames(items_num),
      n        = nrow(items_num),
      media    = round(colMeans(items_num), 3),
      de       = round(apply(items_num, 2, sd), 3),
      skewness = round(apply(items_num, 2, function(x) {
        n<-length(x); m<-mean(x); s<-sd(x)
        (n/((n-1)*(n-2)))*sum(((x-m)/s)^3)
      }), 3),
      kurtosis = round(apply(items_num, 2, function(x) {
        n<-length(x); m<-mean(x); s<-sd(x)
        ((n*(n+1))/((n-1)*(n-2)*(n-3)))*sum(((x-m)/s)^4)-(3*(n-1)^2)/((n-2)*(n-3))
      }), 3),
      stringsAsFactors=FALSE
    )
    por_item$no_normal <- abs(por_item$skewness)>2 | abs(por_item$kurtosis)>7

    m_res <- tryCatch(psych::mardia(items_num, plot=FALSE), error=function(e) NULL)
    safe_v <- function(x) tryCatch(round(x[1],4), error=function(e) NA_real_)

    list(
      por_item          = por_item,
      mardia_skew       = if(!is.null(m_res)) safe_v(m_res$skew)     else NA,
      mardia_skew_p     = if(!is.null(m_res)) safe_v(m_res$p.skew)   else NA,
      mardia_kurt       = if(!is.null(m_res)) safe_v(m_res$kurtosis) else NA,
      mardia_kurt_p     = if(!is.null(m_res)) safe_v(m_res$p.kurt)   else NA,
      n_items_no_normal = sum(por_item$no_normal),
      recommend_mlr     = sum(por_item$no_normal) > 0
    )
  }, error=function(e) list(error=e$message))
}

# ── AFE ──────────────────────────────────────────────────────────────────────
compute_afe <- function(data_mat, n_factors=NULL, rotation="oblimin", estimator="minres") {
  tryCatch({
    items_num <- data_mat[, sapply(data_mat, is.numeric), drop=FALSE]
    items_num <- items_num[complete.cases(items_num), ]
    n <- nrow(items_num); p <- ncol(items_num)
    if (n < 10 || p < 2) return(list(error="Muestra o ítems insuficientes"))

    # Análisis paralelo para determinar n_factors
    pa <- tryCatch(psych::fa.parallel(items_num, plot=FALSE, fa="fa"), error=function(e) NULL)
    n_factors_pa <- if(!is.null(pa)) max(1, pa$nfact) else 1
    n_factors_use <- n_factors %||% n_factors_pa

    # P2-AFE-JUST-ID: detectar modelo justo-identificado o imposible (df <= 0)
    df_afe <- ((p - n_factors_use)^2 - (p + n_factors_use)) / 2
    if (df_afe < 0) {
      return(list(
        blocked=TRUE, reason="AFE_MODELO_NO_IDENTIFICADO", stage="afe",
        n_factors_pa=n_factors_pa, n_factors=n_factors_use,
        error=paste0("Modelo AFE no identificado: ", n_factors_use,
                     " factores con ", p, " items tiene df=", df_afe,
                     ". Reduzca el numero de factores o agregue mas items.")
      ))
    }

    # AFE — inner tryCatch: captura excepciones de psych::fa() antes del outer tryCatch
    # para que n_factors_pa y n_factors_use estén disponibles en el mensaje de error
    afe <- tryCatch(
      psych::fa(items_num, nfactors=n_factors_use, rotate=rotation, fm=estimator),
      error=function(e) structure(list(error=e$message), class="afe_error")
    )
    if (inherits(afe, "afe_error")) {
      return(list(
        blocked=TRUE, reason="AFE_NUMERIC_ERROR", stage="afe",
        n_factors_pa=n_factors_pa, n_factors=n_factors_use,
        error=paste0("Error en psych::fa(): ", afe$error)))
    }

    raw_load <- unclass(afe$loadings)
    if (is.null(dim(raw_load))) raw_load <- matrix(raw_load, ncol=1)

    # Comunalidades del modelo — correcto para oblicua (afe$communality usa Phi internamente)
    # rowSums(P^2) es incorrecto para oblimin porque ignora las correlaciones entre factores
    h2  <- afe$communality
    u2  <- afe$uniquenesses
    tol <- sqrt(.Machine$double.eps)  # ~1.49e-8: distingue Heywood real de ruido numérico

    # Guard 1: cargas no finitas → falta de convergencia o error numérico
    nonfinite_load <- !is.finite(raw_load)
    if (any(nonfinite_load)) {
      conv_ok <- isTRUE(tryCatch(afe$converged, error=function(e) FALSE))
      reason_nf <- if (isTRUE(conv_ok)) "AFE_NUMERIC_ERROR" else "AFE_NO_CONVERGENCIA"
      return(list(
        blocked=TRUE, reason=reason_nf, stage="afe",
        n_factors_pa=n_factors_pa, n_factors=n_factors_use,
        error=paste0("Cargas no finitas en AFE: ", sum(nonfinite_load), " valores"),
        details=list(n_nonfinite=sum(nonfinite_load),
                     items_affected=rownames(raw_load)[rowSums(nonfinite_load) > 0],
                     communalities=round(h2, 4))))
    }

    # Guard 2: Heywood real — comunalidad del modelo > 1 (fuente: afe$communality, no rowSums(P^2))
    heywood_h2 <- !is.na(h2) & (h2 > 1 + tol)
    heywood_u2 <- !is.na(u2) & (u2 < -tol)
    if (any(heywood_h2) || any(heywood_u2)) {
      heywood_items <- names(h2)[heywood_h2 | heywood_u2]
      return(list(
        blocked=TRUE, reason="HEYWOOD_CASE", stage="afe",
        n_factors_pa=n_factors_pa, n_factors=n_factors_use,
        error=paste0("Caso Heywood detectado: comunalidad > 1 en ",
                     paste(heywood_items, collapse=", ")),
        details=list(h2=round(h2,4), u2=round(u2,4),
                     heywood_items=heywood_items, tolerance=tol)))
    }

    # Cargas como lista de listas
    load_list <- lapply(rownames(raw_load), function(item) {
      row <- as.list(round(raw_load[item,], 3))
      names(row) <- paste0("F", seq_along(row))
      c(list(item=item, h2=round(h2[item],3), u2=round(u2[item],3)), row)
    })

    # Varianza explicada
    var_exp <- data.frame(
      factor   = paste0("F", 1:n_factors_use),
      ss_load  = round(colSums(raw_load^2), 3),
      pct_var  = round(colSums(raw_load^2)/p*100, 2),
      cum_var  = round(cumsum(colSums(raw_load^2)/p*100), 2),
      stringsAsFactors=FALSE
    )

    # Cargas cruzadas (items con carga alta en >1 factor)
    cross_load <- c()
    if (n_factors_use > 1) {
      for(i in 1:nrow(raw_load)) {
        high <- sum(abs(raw_load[i,]) >= 0.40)
        if(high > 1) cross_load <- c(cross_load, rownames(raw_load)[i])
      }
    }

    # Items sin carga principal
    no_load <- c()
    for(i in 1:nrow(raw_load)) {
      if(max(abs(raw_load[i,])) < 0.40) no_load <- c(no_load, rownames(raw_load)[i])
    }

    # CR y AVE por factor
    cr_ave <- lapply(1:n_factors_use, function(f) {
      # Asignar items al factor con mayor carga
      if(n_factors_use == 1) {
        lambdas <- raw_load[,1]
      } else {
        asig <- apply(abs(raw_load), 1, which.max)
        lambdas <- raw_load[asig==f, f]
      }
      res <- calc_cr_ave(lambdas)
      c(list(factor=paste0("F",f)), res)
    })

    list(
      n_factors       = n_factors_use,
      n_factors_pa    = n_factors_pa,
      rotation        = rotation,
      estimator       = estimator,
      n               = n,
      df              = df_afe,
      just_identified = isTRUE(df_afe == 0),
      variance_note   = if (tolower(rotation) %in% c("oblimin","promax")) "Con rotación oblicua, las sumas de cargas al cuadrado no son porcentajes aditivos de varianza." else "Varianza basada en sumas de cargas al cuadrado.",
      loadings        = load_list,
      variance        = var_exp,
      cr_ave          = cr_ave,
      cross_loadings  = cross_load,
      no_loadings     = no_load,
      rmsea           = round(afe$RMSEA[1], 3),
      tli             = round(afe$TLI, 3),
      fit_ok          = !is.null(afe$RMSEA) && afe$RMSEA[1] < 0.08
    )
  }, error=function(e) {
    # n_factors_pa y n_factors_use están en el environment de compute_afe:
    # si el error ocurrió después de asignarlos (líneas 87-89), son accesibles.
    list(
      error        = e$message,
      n_factors_pa = tryCatch(n_factors_pa,  error=function(e2) NULL),
      n_factors    = tryCatch(n_factors_use, error=function(e2) NULL)
    )
  })
}

# ── AFC ──────────────────────────────────────────────────────────────────────
compute_afc <- function(data_mat, variables, estimator="MLR") {
  tryCatch({
    items_num <- data_mat[, sapply(data_mat, is.numeric), drop=FALSE]
    items_num <- items_num[complete.cases(items_num), ]
    n <- nrow(items_num)
    if (n < 30) return(list(error="Muestra insuficiente para CFA (n < 30)"))

    # Construir sintaxis lavaan
    model_lines <- sapply(variables, function(v) {
      paste0(v$name, " =~ ", paste(v$items, collapse=" + "))
    })
    model_str <- paste(model_lines, collapse="\n")

    # Ajustar CFA
    fit <- lavaan::cfa(model_str, data=items_num, estimator=estimator,
                       std.lv=FALSE, missing="listwise")

    # Convergencia guard
    conv <- tryCatch(lavaan::lavInspect(fit, "converged"), error=function(e) FALSE)
    if (!isTRUE(conv)) {
      return(list(blocked=TRUE, reason="NO_CONVERGENCIA", stage="afc",
                  error="El modelo AFC no convergió. Revise la especificación del modelo o el tamaño muestral."))
    }

    # Índices de ajuste
    fi <- lavaan::fitMeasures(fit, c("chisq","df","pvalue","cfi","tli",
                                     "rmsea","rmsea.ci.lower","rmsea.ci.upper","srmr"))
    chi2_df <- if(fi["df"]>0) round(fi["chisq"]/fi["df"],3) else NA

    interp_cfi  <- if(is.na(fi["cfi"]))"N/D" else if(fi["cfi"]>=.95)"Excelente" else if(fi["cfi"]>=.90)"Aceptable" else "Deficiente"
    interp_tli  <- if(is.na(fi["tli"]))"N/D" else if(fi["tli"]>=.95)"Excelente" else if(fi["tli"]>=.90)"Aceptable" else "Deficiente"
    interp_rmsea<- if(is.na(fi["rmsea"]))"N/D" else if(fi["rmsea"]<=.05)"Excelente" else if(fi["rmsea"]<=.08)"Aceptable" else "Deficiente"
    interp_srmr <- if(is.na(fi["srmr"]))"N/D" else if(fi["srmr"]<=.08)"Excelente" else if(fi["srmr"]<=.10)"Aceptable" else "Deficiente"
    interp_ratio<- if(is.na(chi2_df))"N/D" else if(chi2_df<=2)"Excelente" else if(chi2_df<=3)"Aceptable" else "Deficiente"

    ajuste_global <- if(fi["cfi"]>=.95&&fi["rmsea"]<=.06&&fi["srmr"]<=.08)"excelente" else if(fi["cfi"]>=.90&&fi["rmsea"]<=.08)"aceptable" else "deficiente"

    # Cargas estandarizadas
    std_sol <- lavaan::standardizedSolution(fit)
    cargas <- std_sol[std_sol$op=="=~", c("lhs","rhs","est.std","se","z","pvalue")]
    names(cargas) <- c("factor","item","lambda","se","z","p")
    lambda_raw <- cargas$lambda
    cargas$lambda <- round(cargas$lambda, 3)
    cargas$se     <- round(cargas$se,     3)
    cargas$z      <- round(cargas$z,      3)
    cargas$p_apa  <- ifelse(cargas$p<.001,"< .001", paste0("= ",round(cargas$p,3)))
    cargas$ok     <- abs(cargas$lambda) >= 0.50

    # Heywood guard AFC: carga estandarizada > 1
    lambdas_all <- lambda_raw
    residual_vars <- std_sol[std_sol$op=="~~" & std_sol$lhs==std_sol$rhs, c("lhs","est.std")]
    bad_residual <- residual_vars$lhs[is.finite(residual_vars$est.std) & residual_vars$est.std < -1e-6]
    if (any(abs(lambdas_all) > 1 + 1e-6, na.rm=TRUE) || length(bad_residual) > 0) {
      heywood_items <- unique(c(cargas$item[abs(lambdas_all) > 1 + 1e-6], bad_residual))
      return(list(blocked=TRUE, reason="HEYWOOD_CASE", stage="afc_loadings",
                  error=paste0("Carga estandarizada > 1 en AFC: ", paste(heywood_items, collapse=", ")),
                  details=list(heywood_items=heywood_items, lambdas=round(lambdas_all,4))))
    }

    # CR y AVE por constructo
    cr_ave_list <- lapply(variables, function(v) {
      lambdas_v <- lambda_raw[cargas$factor==v$name]
      res <- calc_cr_ave(lambdas_v)
      list(
        variable = v$name,
        cr       = res$cr,
        ave      = res$ave,
        cr_ok    = !is.na(res$cr) && res$cr >= 0.70,
        ave_ok   = !is.na(res$ave) && res$ave >= 0.50
      )
    })

    # Fit indices table
    fit_table <- list(
      list(indice="chi2",         valor=round(fi["chisq"],3), criterio="-",          eval="-"),
      list(indice="gl",          valor=fi["df"],              criterio="-",          eval="-"),
      list(indice="p",           valor=round(fi["pvalue"],4), criterio="> .05",      eval=if(fi["pvalue"]>.05)"✓" else "x"),
      list(indice="chi2/gl",       valor=chi2_df,              criterio="<= 3",        eval=interp_ratio),
      list(indice="CFI",         valor=round(fi["cfi"],3),    criterio=">= .95",      eval=interp_cfi),
      list(indice="TLI",         valor=round(fi["tli"],3),    criterio=">= .95",      eval=interp_tli),
      list(indice="RMSEA",       valor=round(fi["rmsea"],3),  criterio="<= .06",      eval=interp_rmsea),
      list(indice="RMSEA IC90%", valor=paste0("[",round(fi["rmsea.ci.lower"],3),", ",round(fi["rmsea.ci.upper"],3),"]"), criterio="-", eval="-"),
      list(indice="SRMR",        valor=round(fi["srmr"],3),   criterio="<= .08",      eval=interp_srmr)
    )

    list(
      estimator    = estimator,
      n            = n,
      model_str    = model_str,
      fit_table    = fit_table,
      cfi          = round(fi["cfi"],3),
      tli          = round(fi["tli"],3),
      rmsea        = round(fi["rmsea"],3),
      rmsea_lo     = round(fi["rmsea.ci.lower"],3),
      rmsea_hi     = round(fi["rmsea.ci.upper"],3),
      srmr         = round(fi["srmr"],3),
      chi2         = round(fi["chisq"],3),
      df           = fi["df"],
      chi2_df      = chi2_df,
      ajuste_global= ajuste_global,
      loadings     = lapply(1:nrow(cargas), function(i) as.list(cargas[i,])),
      cr_ave       = cr_ave_list
    )
  }, error=function(e) list(error=e$message))
}

# ── HTMT ─────────────────────────────────────────────────────────────────────
compute_htmt <- function(data_mat, variables, n_boot=500, seed=20260704, threshold=.85) {
  tryCatch({
    n_vars<-length(variables);if(n_vars<2)stop("Se necesitan al menos 2 constructos.");names_v<-sapply(variables,function(v)v$name)
    calc_one<-function(dat){mat<-matrix(NA_real_,n_vars,n_vars,dimnames=list(names_v,names_v));diag(mat)<-1
      for(i in seq_len(n_vars-1))for(j in (i+1):n_vars){ii<-intersect(as.character(unlist(variables[[i]]$items)),names(dat));jj<-intersect(as.character(unlist(variables[[j]]$items)),names(dat));if(length(ii)<2||length(jj)<2)next
        het<-mean(abs(cor(dat[,ii,drop=FALSE],dat[,jj,drop=FALSE],use="pairwise.complete.obs")),na.rm=TRUE);rii<-abs(cor(dat[,ii,drop=FALSE],use="pairwise.complete.obs"));rjj<-abs(cor(dat[,jj,drop=FALSE],use="pairwise.complete.obs"));mi<-mean(rii[upper.tri(rii)],na.rm=TRUE);mj<-mean(rjj[upper.tri(rjj)],na.rm=TRUE);if(!is.finite(mi)||!is.finite(mj)||mi<=0||mj<=0)next;v<-het/sqrt(mi*mj);mat[i,j]<-mat[j,i]<-v};mat}
    dat<-data_mat[,sapply(data_mat,is.numeric),drop=FALSE];dat<-dat[complete.cases(dat),];if(nrow(dat)<20)stop("Casos completos insuficientes para HTMT bootstrap.");point<-calc_one(dat);set.seed(as.integer(seed));B<-max(500L,as.integer(n_boot));store<-array(NA_real_,c(n_vars,n_vars,B));for(b in seq_len(B))store[,,b]<-calc_one(dat[sample.int(nrow(dat),nrow(dat),replace=TRUE),,drop=FALSE]);lo<-apply(store,c(1,2),quantile,probs=.025,na.rm=TRUE,type=6);hi<-apply(store,c(1,2),quantile,probs=.975,na.rm=TRUE,type=6)
    pairs<-list();for(i in seq_len(n_vars-1))for(j in (i+1):n_vars){v<-point[i,j];u<-hi[i,j];ok<-is.finite(u)&&u<threshold;pairs[[length(pairs)+1]]<-list(par=paste0(names_v[i]," - ",names_v[j]),htmt=as.numeric(v),ic_low=as.numeric(lo[i,j]),ic_high=as.numeric(u),threshold=threshold,verdict=if(ok)"Validez discriminante respaldada por IC"else"IC no respalda validez discriminante",ok=ok)}
    list(pairs=pairs,n_boot=B,n=nrow(dat),seed=as.integer(seed),decision_basis="Límite superior del IC bootstrap")
  },error=function(e)list(error=conditionMessage(e)))
}

# ── V de Aiken ───────────────────────────────────────────────────────────────
compute_vaiken <- function(ratings_matrix, n_judges, scale_max, scale_min=1) {
  tryCatch({
    k <- scale_max - scale_min
    results <- lapply(1:nrow(ratings_matrix), function(i) {
      scores <- as.numeric(ratings_matrix[i,])
      scores <- scores[!is.na(scores)]
      n <- length(scores)
      if(n < 3) return(list(item=rownames(ratings_matrix)[i], n_jueces=n, V=NA, IC_low=NA, IC_high=NA, veredicto="Insuficiente jueces"))
      S  <- sum(scores - scale_min)
      V  <- round(S / (n * k), 3)
      # IC exacto (Penfield & Giacobbi 2004)
      z  <- 1.96
      p  <- V
      IC_low  <- round((p + z^2/(2*n) - z*sqrt(p*(1-p)/n + z^2/(4*n^2))) / (1 + z^2/n), 3)
      IC_high <- round((p + z^2/(2*n) + z*sqrt(p*(1-p)/n + z^2/(4*n^2))) / (1 + z^2/n), 3)
      verdict <- if(is.na(V))"N/D" else if(V>=.80)"Valido (ok) (V >= .80)" else if(V>=.70)"Aceptable (revisar)" else "Rechazado x"
      list(item=rownames(ratings_matrix)[i], n_jueces=n, suma_S=S, V=V,
           IC_low=IC_low, IC_high=IC_high, veredicto=verdict, valido=V>=.80)
    })
    list(items=results, scale_max=scale_max, scale_min=scale_min, n_judges=n_judges)
  }, error=function(e) list(error=e$message))
}

# ── Función principal compute_instruments ─────────────────────────────────
compute_instruments <- function(raw_df, config) {
  result <- list(status="ok", errors=list(), warnings=list())
  items_all <- as.character(unlist(config$all_items))
  items_all <- items_all[items_all %in% names(raw_df)]

  data_items <- raw_df[, items_all, drop=FALSE]

  # Track columns that are not numeric before coercion (for metadata)
  non_numeric_cols <- names(data_items)[!sapply(data_items, is.numeric)]

  data_items <- as.data.frame(lapply(data_items, as.numeric))
  data_items[data_items < config$scale_min | data_items > config$scale_max] <- NA

  imputation_method <- tolower(as.character(config$imputation %||% "none"))
  imp_columns <- character(0); imp_replaced <- integer(0); imp_values <- numeric(0)
  all_missing <- names(data_items)[vapply(data_items,function(x)all(is.na(x)),logical(1))]
  if(length(all_missing)>0)return(list(status="error",blocked=TRUE,reason="COLUMNA_SIN_DATOS",error=paste0("Columnas sin datos válidos: ",paste(all_missing,collapse=", "))))
  if(imputation_method %in% c("media","mean","mediana","median")){
    for(j in seq_along(data_items)){n_na<-sum(is.na(data_items[[j]]));if(!n_na)next;val<-if(imputation_method%in%c("mediana","median"))median(data_items[[j]],na.rm=TRUE)else mean(data_items[[j]],na.rm=TRUE);data_items[[j]][is.na(data_items[[j]])]<-val;nm<-names(data_items)[j];imp_columns<-c(imp_columns,nm);imp_replaced[nm]<-n_na;imp_values[nm]<-val}
  }
  result$imputation <- list(method=imputation_method,explicit=imputation_method!="none",columns=imp_columns,replaced_counts=as.list(imp_replaced),replacement_values=as.list(imp_values),non_numeric_columns_ignored=non_numeric_cols)

  n <- nrow(data_items)
  result$n <- n

  # 1. KMO + Bartlett
  result$kmo <- compute_kmo(data_items)

  # 2. Normalidad ítems
  result$normality <- compute_normality_items(data_items)

  # 3. Confiabilidad por variable/dimension
  variables <- config$variables
  rel_list <- list()
  for(v in variables) {
    v_items <- v$items[v$items %in% names(data_items)]
    if(length(v_items) < 2) next
    v_data <- data_items[, v_items, drop=FALSE]
    ar <- tryCatch(psych::alpha(v_data, check.keys=FALSE), error=function(e) NULL)
    om <- tryCatch({
      om_r <- psych::omega(v_data, nfactors=1, plot=FALSE, warnings=FALSE)
      round(om_r$omega.tot, 3)
    }, error=function(e) NA)
    if(is.null(ar)) next
    alpha_v <- round(ar$total$raw_alpha, 3)
    # IC Feldt
    n_v <- nrow(v_data); k_v <- ncol(v_data)
    F_lower <- qf(0.975, n_v-1, (n_v-1)*(k_v-1))
    F_upper <- qf(0.025, n_v-1, (n_v-1)*(k_v-1))
    ci_low <- round(1-(1-alpha_v)*F_lower, 3)
    ci_up  <- round(1-(1-alpha_v)*F_upper, 3)
    # item-total
    item_stats <- lapply(v_items[v_items %in% rownames(ar$item.stats)], function(it) {
      row <- ar$item.stats[it,]
      drop_row <- ar$alpha.drop[it,]
      list(item=it, mean=round(as.numeric(row["mean"]),3), sd=round(as.numeric(row["sd"]),3),
           r_cor=round(as.numeric(row["r.cor"]),3), alpha_drop=round(as.numeric(drop_row["raw_alpha"]),3))
    })
    rel_list[[v$name]] <- list(
      name=v$name, items=v_items, k=k_v, n=n_v,
      alpha=alpha_v, alpha_std=round(ar$total$std.alpha,3),
      ci_lower=max(0,ci_low), ci_upper=min(1,ci_up),
      omega=om, interpretation=if(alpha_v>=.90)"Excelente" else if(alpha_v>=.80)"Bueno" else if(alpha_v>=.70)"Aceptable" else if(alpha_v>=.60)"Cuestionable" else "Inaceptable",
      inter_item=round(mean(ar$item.stats$r.cor, na.rm=TRUE),3),
      item_stats=item_stats
    )
  }
  result$reliability <- rel_list

  # 4. AFE
  n_factors_cfg <- tryCatch(as.integer(config$n_factors), error=function(e) NULL)
  if(length(n_factors_cfg)==0 || is.null(n_factors_cfg) || is.na(n_factors_cfg[1])) n_factors_cfg <- NULL
  result$afe <- compute_afe(data_items, n_factors=n_factors_cfg,
                             rotation=config$rotation %||% "oblimin",
                             estimator=config$estimator_afe %||% "minres")

  # 5. AFC (si hay estructura definida con 2+ variables)
  if(length(variables) >= 1 && n >= 50) {
    result$afc <- compute_afc(data_items, variables,
                               estimator=config$estimator %||% "MLR")
  }

  # 6. HTMT (si hay 2+ variables)
  if(length(variables) >= 2) {
    result$htmt <- compute_htmt(data_items, variables, n_boot=200)
  }

  result
}
