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
  lc <- pmin(lambdas, 1)
  cr  <- round(sum(lc)^2 / (sum(lc)^2 + sum(1 - lc^2)), 3)
  ave <- round(sum(lc^2) / length(lc), 3)
  list(cr=cr, ave=ave)
}

# ── KMO + Bartlett ──────────────────────────────────────────────────────────
compute_kmo <- function(data_mat) {
  tryCatch({
    R   <- cor(data_mat, use="pairwise.complete.obs")
    kmo <- psych::KMO(R)
    bart <- psych::cortest.bartlett(R, n=nrow(data_mat))
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

    # AFE
    afe <- psych::fa(items_num, nfactors=n_factors_use, rotate=rotation, fm=estimator)

    raw_load <- unclass(afe$loadings)
    if (is.null(dim(raw_load))) raw_load <- matrix(raw_load, ncol=1)

    # Comunalidades
    h2 <- rowSums(raw_load^2)
    u2 <- 1 - h2

    # Heywood guard: comunalidad > 1 o unicidad < 0
    if (any(h2 > 1 + 1e-6, na.rm=TRUE) || any(u2 < -1e-6, na.rm=TRUE) || any(!is.finite(raw_load))) {
      heywood_items <- rownames(raw_load)[!is.na(h2) & (h2 > 1 + 1e-6 | u2 < -1e-6)]
      return(list(
        blocked = TRUE, reason = "HEYWOOD_CASE", stage = "afe",
        error = paste0("Caso Heywood detectado: comunalidad > 1 o unicidad < 0 en ",
                       paste(heywood_items, collapse=", ")),
        details = list(h2=round(h2,4), u2=round(u2,4), heywood_items=heywood_items)
      ))
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
      loadings        = load_list,
      variance        = var_exp,
      cr_ave          = cr_ave,
      cross_loadings  = cross_load,
      no_loadings     = no_load,
      rmsea           = round(afe$RMSEA[1], 3),
      tli             = round(afe$TLI, 3),
      fit_ok          = !is.null(afe$RMSEA) && afe$RMSEA[1] < 0.08
    )
  }, error=function(e) list(error=e$message))
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
    cargas$lambda <- round(cargas$lambda, 3)
    cargas$se     <- round(cargas$se,     3)
    cargas$z      <- round(cargas$z,      3)
    cargas$p_apa  <- ifelse(cargas$p<.001,"< .001", paste0("= ",round(cargas$p,3)))
    cargas$ok     <- abs(cargas$lambda) >= 0.50

    # Heywood guard AFC: carga estandarizada > 1
    lambdas_all <- cargas$lambda
    if (any(abs(lambdas_all) > 1 + 1e-6, na.rm=TRUE)) {
      heywood_items <- cargas$item[abs(lambdas_all) > 1 + 1e-6]
      return(list(blocked=TRUE, reason="HEYWOOD_CASE", stage="afc_loadings",
                  error=paste0("Carga estandarizada > 1 en AFC: ", paste(heywood_items, collapse=", ")),
                  details=list(heywood_items=heywood_items, lambdas=round(lambdas_all,4))))
    }

    # CR y AVE por constructo
    cr_ave_list <- lapply(variables, function(v) {
      lambdas_v <- cargas$lambda[cargas$factor==v$name]
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
compute_htmt <- function(data_mat, variables, n_boot=500) {
  tryCatch({
    n_vars    <- length(variables)
    if(n_vars < 2) return(list(error="Se necesitan al menos 2 variables para HTMT"))
    var_names <- sapply(variables, function(v) v$name)

    calc_one <- function(dat) {
      mat <- matrix(NA, n_vars, n_vars, dimnames=list(var_names, var_names))
      for(i in 1:n_vars) for(j in 1:n_vars) {
        if(i==j){mat[i,j]<-1;next}
        ii <- variables[[i]]$items[variables[[i]]$items %in% colnames(dat)]
        jj <- variables[[j]]$items[variables[[j]]$items %in% colnames(dat)]
        if(length(ii)<2||length(jj)<2) next
        het  <- mean(abs(cor(dat[,ii,drop=FALSE], dat[,jj,drop=FALSE], use="pairwise.complete.obs")))
        r_ii <- cor(dat[,ii,drop=FALSE], use="pairwise.complete.obs")
        r_jj <- cor(dat[,jj,drop=FALSE], use="pairwise.complete.obs")
        mi <- mean(r_ii[upper.tri(r_ii)]); mj <- mean(r_jj[upper.tri(r_jj)])
        if(mi<=0||mj<=0) next
        mat[i,j] <- round(het/sqrt(mi*mj), 3)
      }
      mat
    }

    items_num <- data_mat[,sapply(data_mat,is.numeric),drop=FALSE]
    items_num <- items_num[complete.cases(items_num),]
    htmt_mat  <- calc_one(items_num)

    # Bootstrap IC
    n <- nrow(items_num)
    boot_store <- array(NA, dim=c(n_vars, n_vars, n_boot))
    for(b in 1:n_boot) {
      idx    <- sample(1:n, n, replace=TRUE)
      boot_store[,,b] <- calc_one(items_num[idx,,drop=FALSE])
    }
    ic_low  <- apply(boot_store, c(1,2), quantile, probs=0.025, na.rm=TRUE)
    ic_high <- apply(boot_store, c(1,2), quantile, probs=0.975, na.rm=TRUE)
    dimnames(ic_low)  <- list(var_names, var_names)
    dimnames(ic_high) <- list(var_names, var_names)

    # Tabla de resultados
    pairs <- list()
    for(i in 1:(n_vars-1)) for(j in (i+1):n_vars) {
      htmt_v <- htmt_mat[i,j]
      verdict <- if(is.na(htmt_v))"N/D" else if(htmt_v<.85)"Discriminante (ok)" else if(htmt_v<.90)"Revisar (revisar)" else "Problema x"
      pairs[[length(pairs)+1]] <- list(
        par      = paste0(var_names[i]," - ",var_names[j]),
        htmt     = htmt_v,
        ic_low   = round(ic_low[i,j],3),
        ic_high  = round(ic_high[i,j],3),
        verdict  = verdict,
        ok       = !is.na(htmt_v) && htmt_v < .85
      )
    }

    list(pairs=pairs, n_boot=n_boot, n=n)
  }, error=function(e) list(error=e$message))
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

  # F-006 fix: column-by-column mean imputation
  # The old vectorized form `apply(...)[is.na(df)]` mis-indexed because
  # it used an n×p logical matrix to index a length-p means vector — positions
  # beyond p returned NA, leaving virtually all cells in cols 2-p unimputed.
  imp_columns      <- character(0)
  imp_replaced     <- integer(0)
  imp_values       <- numeric(0)
  imp_missing_cols <- character(0)

  for (j in seq_along(data_items)) {
    n_na <- sum(is.na(data_items[[j]]))
    if (n_na == 0L) next
    col_name <- names(data_items)[j]
    col_mean <- mean(data_items[[j]], na.rm = TRUE)
    if (is.nan(col_mean) || is.na(col_mean)) {
      imp_missing_cols <- c(imp_missing_cols, col_name)
      next
    }
    data_items[[j]][is.na(data_items[[j]])] <- col_mean
    imp_columns            <- c(imp_columns, col_name)
    imp_replaced[col_name] <- n_na
    imp_values[col_name]   <- col_mean
  }

  if (length(imp_missing_cols) > 0) {
    return(list(
      status  = "error",
      blocked = TRUE,
      reason  = "COLUMNA_SIN_DATOS",
      error   = paste0("Columna(s) sin datos validos: ",
                       paste(imp_missing_cols, collapse = ", ")),
      details = list(all_missing_columns = imp_missing_cols),
      imputation = list(
        method                      = "column_mean",
        columns                     = imp_columns,
        replaced_counts             = as.list(imp_replaced),
        replacement_values          = as.list(imp_values),
        all_missing_columns         = imp_missing_cols,
        non_numeric_columns_ignored = non_numeric_cols
      )
    ))
  }

  result$imputation <- list(
    method                      = "column_mean",
    columns                     = imp_columns,
    replaced_counts             = as.list(imp_replaced),
    replacement_values          = as.list(imp_values),
    all_missing_columns         = character(0),
    non_numeric_columns_ignored = non_numeric_cols
  )

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
                             rotation=config$rotation %||% "oblimin")

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
