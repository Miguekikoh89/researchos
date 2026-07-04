# ============================================================================
# ResearchOS — Módulo Validación de Instrumentos Psicométricos
# Portado desde Validador Psicométrico v6.0
# Métodos: Cronbach, Omega, CR, AVE, KMO, Bartlett, AFE, AFC, HTMT, V-Aiken
# ============================================================================

`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && !is.na(a[1])) a else b

# ── CR y AVE desde cargas (Fornell & Larcker 1981) ──────────────────────────
calc_cr_ave <- function(lambdas) {
  lambdas <- suppressWarnings(as.numeric(lambdas)); lambdas <- lambdas[is.finite(lambdas)]
  if (length(lambdas) < 2) return(list(cr=NA_real_,ave=NA_real_,cr_raw=NA_real_,ave_raw=NA_real_,mixed_signs=NA))
  if (any(abs(lambdas) > 1 + 1e-6)) return(list(cr=NA_real_,ave=NA_real_,cr_raw=NA_real_,ave_raw=NA_real_,mixed_signs=NA,error="Cargas estandarizadas fuera de [-1,1]."))
  theta <- pmax(0, 1-lambdas^2)
  den <- sum(lambdas)^2 + sum(theta)
  cr_raw <- if(den>0)sum(lambdas)^2/den else NA_real_
  ave_raw <- mean(lambdas^2)
  list(cr=round(cr_raw,3),ave=round(ave_raw,3),cr_raw=cr_raw,ave_raw=ave_raw,mixed_signs=any(lambdas<0)&&any(lambdas>0))
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
      bartlett_p     = as.numeric(bart$p.value),
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
      mardia_skew_p     = if(!is.null(m_res)) suppressWarnings(as.numeric(m_res$p.skew[1])) else NA_real_,
      mardia_kurt       = if(!is.null(m_res)) safe_v(m_res$kurtosis) else NA,
      mardia_kurt_p     = if(!is.null(m_res)) suppressWarnings(as.numeric(m_res$p.kurt[1])) else NA_real_,
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

    # Análisis paralelo reproducible para determinar n_factors
    had_seed <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE); if(had_seed) old_seed <- get(".Random.seed",envir=.GlobalEnv)
    on.exit({if(had_seed)assign(".Random.seed",old_seed,envir=.GlobalEnv)else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))rm(".Random.seed",envir=.GlobalEnv)},add=TRUE)
    set.seed(20260704L)
    pa <- tryCatch(psych::fa.parallel(items_num, plot=FALSE, fa="fa", n.iter=100), error=function(e) NULL)
    n_factors_pa <- if(!is.null(pa)&&is.finite(pa$nfact)) max(1L,as.integer(pa$nfact)) else 1L
    n_factors_use <- if(is.null(n_factors))n_factors_pa else suppressWarnings(as.integer(n_factors)[1])
    if(!is.finite(n_factors_use)||n_factors_use<1||n_factors_use>=p)return(list(blocked=TRUE,reason="NUMERO_FACTORES_INVALIDO",error=paste0("n_factors debe ser entero entre 1 y ",p-1,".")))

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
      parallel_seed   = 20260704L,
      parallel_iterations = 100L,
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
    # Usar exclusivamente los indicadores declarados. Columnas numéricas ajenas
    # al modelo no deben reducir la muestra ni alterar el AFC.
    model_items <- unique(as.character(unlist(lapply(variables,function(v)unlist(v$items)))))
    missing_items <- setdiff(model_items,names(data_mat))
    if(length(missing_items))return(list(blocked=TRUE,reason="INDICADORES_NO_ENCONTRADOS",error=paste0("Indicadores no encontrados: ",paste(missing_items,collapse=", "))))
    items_num <- as.data.frame(lapply(data_mat[,model_items,drop=FALSE],function(x){
      original_nonmissing <- !is.na(x) & trimws(as.character(x))!=""
      z <- suppressWarnings(as.numeric(as.character(x)))
      if(any(original_nonmissing & is.na(z))) stop("Existen indicadores AFC con valores no numéricos.")
      z
    }),check.names=FALSE)
    items_num <- items_num[complete.cases(items_num),,drop=FALSE]
    n <- nrow(items_num)
    if (n < 30) return(list(blocked=TRUE,reason="MUESTRA_INSUFICIENTE",error="Muestra insuficiente para AFC (n < 30)"))

    # Validar estructura y nombres antes de construir sintaxis lavaan.
    for(v in variables){
      its<-as.character(unlist(v$items));if(length(its)<2)return(list(blocked=TRUE,reason="CONSTRUCTO_MENOS_DE_DOS_INDICADORES",error=paste0("El constructo '",v$name,"' requiere al menos 2 indicadores.")))
    }
    all_names<-c(vapply(variables,function(v)as.character(v$name),character(1)),unlist(lapply(variables,function(v)as.character(unlist(v$items)))))
    bad_names<-unique(all_names[!grepl("^[A-Za-z][A-Za-z0-9_.]*$",all_names)])
    if(length(bad_names))return(list(blocked=TRUE,reason="NOMBRES_LAVAAN_INVALIDOS",error=paste0("Use nombres alfanuméricos sin espacios para AFC: ",paste(bad_names,collapse=", "))))
    model_lines <- sapply(variables,function(v)paste0(v$name," =~ ",paste(v$items,collapse=" + ")))
    model_str <- paste(model_lines,collapse="\n")

    est_upper<-toupper(as.character(estimator));ordered_items<-if(est_upper%in%c("WLSMV","DWLS","ULSMV"))unique(unlist(lapply(variables,function(v)v$items)))else NULL
    fit <- lavaan::cfa(model_str,data=items_num,estimator=estimator,std.lv=FALSE,missing="listwise",ordered=ordered_items)

    # Convergencia guard
    conv <- tryCatch(lavaan::lavInspect(fit, "converged"), error=function(e) FALSE)
    if (!isTRUE(conv)) {
      return(list(blocked=TRUE, reason="NO_CONVERGENCIA", stage="afc",
                  error="El modelo AFC no convergió. Revise la especificación del modelo o el tamaño muestral."))
    }

    # Índices de ajuste. Con MLR se priorizan las variantes robustas/escaladas
    # cuando lavaan las proporciona; nunca se etiquetan índices estándar como robustos.
    fi_all <- lavaan::fitMeasures(fit)
    pick_fit <- function(primary, fallback) {
      val <- if(primary %in% names(fi_all)) suppressWarnings(as.numeric(fi_all[[primary]])) else NA_real_
      if(!is.finite(val) && fallback %in% names(fi_all)) val <- suppressWarnings(as.numeric(fi_all[[fallback]]))
      val
    }
    use_robust <- est_upper %in% c("MLR","MLM","MLMV","MLF","WLSMV","DWLS","ULSMV")
    chi2_val <- if(use_robust) pick_fit("chisq.scaled","chisq") else pick_fit("chisq","chisq")
    p_val    <- if(use_robust) pick_fit("pvalue.scaled","pvalue") else pick_fit("pvalue","pvalue")
    df_val   <- if(use_robust) pick_fit("df.scaled","df") else pick_fit("df","df")
    cfi_val  <- if(use_robust) pick_fit("cfi.robust","cfi") else pick_fit("cfi","cfi")
    tli_val  <- if(use_robust) pick_fit("tli.robust","tli") else pick_fit("tli","tli")
    rmsea_val<- if(use_robust) pick_fit("rmsea.robust","rmsea") else pick_fit("rmsea","rmsea")
    rmsea_lo <- if(use_robust) pick_fit("rmsea.ci.lower.robust","rmsea.ci.lower") else pick_fit("rmsea.ci.lower","rmsea.ci.lower")
    rmsea_hi <- if(use_robust) pick_fit("rmsea.ci.upper.robust","rmsea.ci.upper") else pick_fit("rmsea.ci.upper","rmsea.ci.upper")
    srmr_val <- pick_fit("srmr","srmr")
    fit_variant <- if(use_robust && "chisq.scaled" %in% names(fi_all) && is.finite(as.numeric(fi_all[["chisq.scaled"]]))) "robust_or_scaled" else "standard"
    chi2_df <- if(is.finite(df_val)&&df_val>0) round(chi2_val/df_val,3) else NA_real_

    interp_cfi  <- if(!is.finite(cfi_val))"N/D" else if(cfi_val>=.95)"Excelente" else if(cfi_val>=.90)"Aceptable" else "Deficiente"
    interp_tli  <- if(!is.finite(tli_val))"N/D" else if(tli_val>=.95)"Excelente" else if(tli_val>=.90)"Aceptable" else "Deficiente"
    interp_rmsea<- if(!is.finite(rmsea_val))"N/D" else if(rmsea_val<=.05)"Excelente" else if(rmsea_val<=.08)"Aceptable" else "Deficiente"
    interp_srmr <- if(!is.finite(srmr_val))"N/D" else if(srmr_val<=.08)"Excelente" else if(srmr_val<=.10)"Aceptable" else "Deficiente"
    interp_ratio<- if(!is.finite(chi2_df))"N/D" else if(chi2_df<=2)"Excelente" else if(chi2_df<=3)"Aceptable" else "Deficiente"

    ajuste_global <- if(is.finite(cfi_val)&&is.finite(rmsea_val)&&is.finite(srmr_val)&&cfi_val>=.95&&rmsea_val<=.06&&srmr_val<=.08)"excelente" else if(is.finite(cfi_val)&&is.finite(rmsea_val)&&cfi_val>=.90&&rmsea_val<=.08)"aceptable" else "deficiente"

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
      list(indice="chi2",         valor=round(chi2_val,3), criterio="-",          eval="-"),
      list(indice="gl",          valor=df_val,              criterio="-",          eval="-"),
      list(indice="p",           valor=round(p_val,4), criterio="> .05",      eval=if(is.finite(p_val)&&p_val>.05)"✓" else "x"),
      list(indice="chi2/gl",       valor=chi2_df,              criterio="<= 3",        eval=interp_ratio),
      list(indice="CFI",         valor=round(cfi_val,3),    criterio=">= .95",      eval=interp_cfi),
      list(indice="TLI",         valor=round(tli_val,3),    criterio=">= .95",      eval=interp_tli),
      list(indice="RMSEA",       valor=round(rmsea_val,3),  criterio="<= .06",      eval=interp_rmsea),
      list(indice="RMSEA IC90%", valor=paste0("[",round(rmsea_lo,3),", ",round(rmsea_hi,3),"]"), criterio="-", eval="-"),
      list(indice="SRMR",        valor=round(srmr_val,3),   criterio="<= .08",      eval=interp_srmr)
    )

    list(
      estimator    = estimator,
      fit_variant  = fit_variant,
      ordered_items = if(is.null(ordered_items))list()else as.list(ordered_items),
      n            = n,
      model_str    = model_str,
      fit_table    = fit_table,
      cfi          = round(cfi_val,3),
      tli          = round(tli_val,3),
      rmsea        = round(rmsea_val,3),
      rmsea_lo     = round(rmsea_lo,3),
      rmsea_hi     = round(rmsea_hi,3),
      srmr         = round(srmr_val,3),
      chi2         = round(chi2_val,3),
      chi2_raw     = as.numeric(chi2_val),
      p_value_raw  = as.numeric(p_val),
      df           = df_val,
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
    n_vars<-length(variables);if(n_vars<2)stop("Se necesitan al menos 2 constructos.");names_v<-vapply(variables,function(v)as.character(v$name),character(1))
    calc_one<-function(dat){mat<-matrix(NA_real_,n_vars,n_vars,dimnames=list(names_v,names_v));diag(mat)<-1
      for(i in seq_len(n_vars-1))for(j in (i+1):n_vars){ii<-intersect(as.character(unlist(variables[[i]]$items)),names(dat));jj<-intersect(as.character(unlist(variables[[j]]$items)),names(dat));if(length(ii)<2||length(jj)<2)next
        cross<-abs(cor(dat[,ii,drop=FALSE],dat[,jj,drop=FALSE],use="pairwise.complete.obs"));rii<-abs(cor(dat[,ii,drop=FALSE],use="pairwise.complete.obs"));rjj<-abs(cor(dat[,jj,drop=FALSE],use="pairwise.complete.obs"));
        het<-mean(cross[is.finite(cross)]);mi<-mean(rii[upper.tri(rii)&is.finite(rii)]);mj<-mean(rjj[upper.tri(rjj)&is.finite(rjj)]);if(!is.finite(het)||!is.finite(mi)||!is.finite(mj)||mi<=0||mj<=0)next;mat[i,j]<-mat[j,i]<-het/sqrt(mi*mj)};mat}
    dat<-data_mat[,sapply(data_mat,is.numeric),drop=FALSE];dat<-dat[complete.cases(dat),,drop=FALSE];if(nrow(dat)<20)stop("Casos completos insuficientes para HTMT bootstrap.")
    point<-calc_one(dat);B<-max(500L,as.integer(n_boot));had<-exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE);if(had)old<-get(".Random.seed",envir=.GlobalEnv);on.exit({if(had)assign(".Random.seed",old,envir=.GlobalEnv)else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))rm(".Random.seed",envir=.GlobalEnv)},add=TRUE);set.seed(as.integer(seed))
    store<-array(NA_real_,c(n_vars,n_vars,B));for(b in seq_len(B))store[,,b]<-calc_one(dat[sample.int(nrow(dat),nrow(dat),replace=TRUE),,drop=FALSE])
    pairs<-list();for(i in seq_len(n_vars-1))for(j in (i+1):n_vars){vals<-store[i,j,];vals<-vals[is.finite(vals)];min_valid<-ceiling(.80*B);lo<-hi<-NA_real_;if(length(vals)>=min_valid){lo<-unname(quantile(vals,.025,type=6));hi<-unname(quantile(vals,.975,type=6))};v<-point[i,j];ok<-is.finite(hi)&&hi<threshold
      pairs[[length(pairs)+1]]<-list(par=paste0(names_v[i]," - ",names_v[j]),htmt=as.numeric(v),ic_low=as.numeric(lo),ic_high=as.numeric(hi),bootstrap_valid=length(vals),bootstrap_requested=B,threshold=threshold,verdict=if(!is.finite(hi))"IC bootstrap no disponible"else if(ok)"Validez discriminante respaldada por IC"else"IC no respalda validez discriminante",ok=if(is.finite(hi))ok else NA)}
    list(pairs=pairs,n_boot=B,n=nrow(dat),seed=as.integer(seed),decision_basis="Límite superior del IC bootstrap percentil",ci_type="percentile_type6")
  },error=function(e)list(error=conditionMessage(e)))
}

# ── V de Aiken ───────────────────────────────────────────────────────────────
compute_vaiken <- function(ratings_matrix, n_judges, scale_max, scale_min=1) {
  tryCatch({
    ccat<-as.numeric(scale_max)-as.numeric(scale_min);if(!is.finite(ccat)||ccat<=0)stop("Rango de escala inválido.")
    results<-lapply(seq_len(nrow(ratings_matrix)),function(i){scores<-suppressWarnings(as.numeric(ratings_matrix[i,]));scores<-scores[is.finite(scores)];n<-length(scores);item_name<-rownames(ratings_matrix)[i] %||% paste0("Item ",i)
      if(n<3)return(list(item=item_name,n_jueces=n,V=NA_real_,IC_low=NA_real_,IC_high=NA_real_,ci_method="no_estimado",veredicto="Jueces insuficientes"))
      if(any(scores<scale_min|scores>scale_max))return(list(item=item_name,n_jueces=n,V=NA_real_,IC_low=NA_real_,IC_high=NA_real_,ci_method="no_estimado",veredicto="Puntuaciones fuera de escala"))
      S<-sum(scores-scale_min);V_raw<-S/(n*ccat);verdict<-if(V_raw>=.80)"V ≥ .80"else if(V_raw>=.70)"V entre .70 y .79; revisar"else"V < .70"
      list(item=item_name,n_jueces=n,suma_S=S,V=round(V_raw,3),V_raw=V_raw,IC_low=NA_real_,IC_high=NA_real_,ci_method="no reportado: el IC previo no era un IC exacto de V de Aiken",veredicto=verdict,valido=V_raw>=.80)})
    list(items=results,scale_max=scale_max,scale_min=scale_min,n_judges=n_judges,ci_status="disabled_until_validated")
  },error=function(e)list(error=conditionMessage(e)))
}

# ── Función principal compute_instruments ─────────────────────────────────
compute_instruments <- function(raw_df, config) {
  result <- list(status="ok", errors=list(), warnings=list())
  items_requested <- unique(as.character(unlist(config$all_items)))
  missing_requested <- setdiff(items_requested,names(raw_df))
  if(length(missing_requested)>0)return(list(status="error",blocked=TRUE,reason="ITEMS_NO_ENCONTRADOS",error=paste0("Ítems solicitados no encontrados: ",paste(missing_requested,collapse=", "))))
  items_all <- items_requested
  if(length(items_all)<2)return(list(status="error",blocked=TRUE,reason="ITEMS_INSUFICIENTES",error="Se requieren al menos dos ítems para validación de instrumentos."))

  data_items_raw <- raw_df[, items_all, drop=FALSE]
  non_numeric_cols <- names(data_items_raw)[!sapply(data_items_raw, is.numeric)]
  conversion_losses <- integer(length(items_all));names(conversion_losses)<-items_all
  data_items <- as.data.frame(lapply(seq_along(data_items_raw),function(j){
    x<-data_items_raw[[j]];present<-!is.na(x)&trimws(as.character(x))!="";z<-suppressWarnings(as.numeric(as.character(x)));conversion_losses[j]<<-sum(present&is.na(z));z
  }),check.names=FALSE);names(data_items)<-items_all
  if(any(conversion_losses>0))return(list(status="error",blocked=TRUE,reason="VALORES_NO_NUMERICOS",error=paste0("Valores no numéricos en ítems: ",paste(names(conversion_losses)[conversion_losses>0],conversion_losses[conversion_losses>0],sep="=",collapse=", "))))
  scale_min<-as.numeric(config$scale_min);scale_max<-as.numeric(config$scale_max)
  if(!is.finite(scale_min)||!is.finite(scale_max)||scale_min>=scale_max)return(list(status="error",blocked=TRUE,reason="ESCALA_INVALIDA",error="scale_min y scale_max deben ser finitos y scale_min < scale_max."))
  out_counts<-vapply(data_items,function(x)sum(is.finite(x)&(x<scale_min|x>scale_max)),integer(1))
  if(any(out_counts>0))return(list(status="error",blocked=TRUE,reason="VALORES_FUERA_ESCALA",error=paste0("Valores fuera de [",scale_min,", ",scale_max,"] en: ",paste(names(out_counts)[out_counts>0],out_counts[out_counts>0],sep="=",collapse=", "))))

  imputation_method <- tolower(as.character(config$imputation %||% "none"))
  imp_columns <- character(0); imp_replaced <- integer(0); imp_values <- numeric(0)
  all_missing <- names(data_items)[vapply(data_items,function(x)all(is.na(x)),logical(1))]
  if(length(all_missing)>0)return(list(status="error",blocked=TRUE,reason="COLUMNA_SIN_DATOS",error=paste0("Columnas sin datos válidos: ",paste(all_missing,collapse=", "))))
  constant_items <- names(data_items)[vapply(data_items,function(x){v<-stats::var(x,na.rm=TRUE);!is.finite(v)||v<=sqrt(.Machine$double.eps)},logical(1))]
  if(length(constant_items)>0)return(list(status="error",blocked=TRUE,reason="ITEM_CONSTANTE",error=paste0("Ítems sin varianza: ",paste(constant_items,collapse=", "))))
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
    cr <- tryCatch(cronbach_alpha_ic(v_data),error=function(e)NULL);if(is.null(cr)||!is.finite(cr$alpha))next
    item_stats<-lapply(cr$item_stats,function(it)list(item=it$item,mean=it$mean,sd=it$sd,r_cor=it$r_item_total_corr,alpha_drop=it$alpha_if_deleted))
    rel_list[[v$name]]<-list(name=v$name,items=v_items,k=cr$k,n=cr$n,alpha=cr$alpha,alpha_raw=cr$alpha_raw %||% cr$alpha,alpha_std=cr$alpha_std,
      ci_lower=cr$ci_lower,ci_upper=cr$ci_upper,omega=cr$omega$omega_t,omega_note=cr$omega$error %||% NULL,interpretation=cr$interpretation,
      inter_item=cr$inter_item_mean,inter_item_label="Correlación inter-ítem media",item_stats=item_stats,negative_alpha=is.finite(cr$alpha)&&cr$alpha<0)
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
    result$htmt <- compute_htmt(data_items, variables, n_boot=as.integer(config$htmt_boot %||% 1000), seed=as.integer(config$seed %||% 20260704))
  }

  result
}
