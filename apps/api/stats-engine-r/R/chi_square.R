# ============================================================================
# ResearchOS - Chi-cuadrado SPSS-identico
# Chi2 Pearson, correccion Yates, Fisher exacto, V de Cramer, Phi
# Ref: SPSS Statistics 29, Agresti(2002)
# ============================================================================

interpret_v_cramer <- function(v, df_min) {
  if (is.na(v)) return("indeterminado")
  if (df_min == 1) {
    if (v >= 0.50) return("grande")
    if (v >= 0.30) return("mediano")
    if (v >= 0.10) return("pequeno")
  } else if (df_min == 2) {
    if (v >= 0.35) return("grande")
    if (v >= 0.21) return("mediano")
    if (v >= 0.07) return("pequeno")
  } else {
    if (v >= 0.29) return("grande")
    if (v >= 0.17) return("mediano")
    if (v >= 0.06) return("pequeno")
  }
  return("trivial")
}

compute_chisquare <- function(var1, var2, alpha=0.05, yates="auto", effect_size="cramer", min_expected=5) {
  var1 <- as.character(unlist(var1))
  var2 <- as.character(unlist(var2))
  valid <- !is.na(var1) & !is.na(var2) & var1 != "" & var2 != ""
  var1 <- var1[valid]; var2 <- var2[valid]
  n <- length(var1)

  if (n < 10) return(list(error="Muestra insuficiente (n < 10)"))

  min_expected_threshold <- as.numeric(min_expected)

  tabla <- table(var1, var2)
  r <- nrow(tabla); c <- ncol(tabla)

  expected <- outer(rowSums(tabla), colSums(tabla)) / n
  min_expected_obs <- min(expected)
  pct_low_expected <- mean(expected < min_expected_threshold) * 100

  chi2_pearson <- chisq.test(tabla, correct=FALSE)

  yates_choice <- tolower(as.character(yates))
  apply_yates <- if (yates_choice == "always" || yates_choice == "siempre" || yates_choice == "yes") {
    r==2 && c==2
  } else if (yates_choice == "never" || yates_choice == "no") {
    FALSE
  } else {
    r==2 && c==2
  }
  chi2_yates <- if (apply_yates) chisq.test(tabla, correct=TRUE) else NULL

  fisher_res <- if (r==2 && c==2) {
    tryCatch(fisher.test(tabla), error=function(e) NULL)
  } else NULL

  chi2_stat <- chi2_pearson$statistic
  df_chi    <- chi2_pearson$parameter
  p_pearson <- chi2_pearson$p.value

  # P2-USE-FISHER: regla de Cochran — Fisher si >20% de celdas con esperado
  # bajo O alguna frecuencia esperada OBSERVADA < 1. Antes se comparaba el
  # parametro min_expected_threshold (default 5) contra 1, que nunca es cierto
  # con el default y ademas no mira los datos.
  use_fisher <- !is.null(fisher_res) && (pct_low_expected > 20 || min_expected_obs < 1)

  phi <- sqrt(chi2_stat / n)
  df_min <- min(r-1, c-1)
  v_cramer <- sqrt(chi2_stat / (n * df_min))

  tabla_list <- list()
  for (i in rownames(tabla)) {
    for (j in colnames(tabla)) {
      tabla_list[[length(tabla_list)+1]] <- list(
        row=i, col=j,
        observed=as.integer(tabla[i,j]),
        expected=round(expected[i,j],2),
        residual=round((tabla[i,j]-expected[i,j])/sqrt(expected[i,j]),3)
      )
    }
  }

  row_totals <- as.list(rowSums(tabla))
  col_totals <- as.list(colSums(tabla))

  sig <- if(use_fisher) fisher_res$p.value < alpha else if(apply_yates && !is.null(chi2_yates)) chi2_yates$p.value < alpha else p_pearson < alpha

  method_used <- if(use_fisher) "Fisher exacto" else if(apply_yates && !is.null(chi2_yates)) "Chi-cuadrado con correccion Yates" else "Chi-cuadrado de Pearson"

  list(
    test_type     = "chi_cuadrado",
    method_used   = method_used,
    n             = n,
    r             = r,
    c             = c,
    chi2          = round(if(apply_yates && !is.null(chi2_yates)) chi2_yates$statistic else chi2_stat, 3),
    df            = as.integer(df_chi),
    p             = round(if(apply_yates && !is.null(chi2_yates)) chi2_yates$p.value else p_pearson, 4),
    p_apa         = {
      p_show <- if(apply_yates && !is.null(chi2_yates)) chi2_yates$p.value else p_pearson
      if(p_show<.001)"< .001" else paste0("= ",formatC(p_show,digits=3,format="f"))
    },
    chi2_yates    = if(!is.null(chi2_yates)) round(chi2_yates$statistic,3) else NULL,
    p_yates       = if(!is.null(chi2_yates)) round(chi2_yates$p.value,4) else NULL,
    yates_applied = apply_yates,
    p_fisher      = if(!is.null(fisher_res)) round(fisher_res$p.value,4) else NULL,
    or_fisher     = if(!is.null(fisher_res) && !is.null(fisher_res$estimate)) round(fisher_res$estimate,3) else NULL,
    phi           = round(phi, 3),
    v_cramer      = round(v_cramer, 3),
    v_interpret   = interpret_v_cramer(v_cramer, df_min),
    effect_size_requested = effect_size,
    min_expected_threshold_used = min_expected_threshold,
    min_expected  = round(min_expected_obs, 2),
    pct_low_expected = round(pct_low_expected, 1),
    assumption_ok = pct_low_expected <= 20,
    assumption_note = if(pct_low_expected>20) paste0(round(pct_low_expected),"% de celdas con frecuencia esperada < ",min_expected_threshold,". Usar Fisher exacto.") else "Supuestos cumplidos.",
    use_fisher    = use_fisher,
    contingency_table = tabla_list,
    row_names     = rownames(tabla),
    col_names     = colnames(tabla),
    row_totals    = as.list(rowSums(tabla)),
    col_totals    = as.list(colSums(tabla)),
    significant   = sig,
    decision      = if(sig)"Se rechaza H0" else "No se rechaza H0",
    alpha         = alpha
  )
}
