# ============================================================================
# ResearchOS — Chi-cuadrado SPSS-identico
# Chi2 Pearson, correccion Yates, Fisher exacto, V de Cramer, Phi
# Ref: SPSS Statistics 29, Agresti(2002)
# ============================================================================

interpret_v_cramer <- function(v, df_min) {
  if (is.na(v)) return("indeterminado")
  # Umbrales segun df_min (Cohen 1988 adaptado)
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

compute_chisquare <- function(var1, var2, alpha=0.05) {
  var1 <- as.character(unlist(var1))
  var2 <- as.character(unlist(var2))
  valid <- !is.na(var1) & !is.na(var2) & var1 != "" & var2 != ""
  var1 <- var1[valid]; var2 <- var2[valid]
  n <- length(var1)
  
  if (n < 10) return(list(error="Muestra insuficiente (n < 10)"))
  
  # Tabla de contingencia
  tabla <- table(var1, var2)
  r <- nrow(tabla); c <- ncol(tabla)
  
  # Frecuencias esperadas
  expected <- outer(rowSums(tabla), colSums(tabla)) / n
  min_expected <- min(expected)
  pct_low_expected <- mean(expected < 5) * 100
  
  # Chi-cuadrado de Pearson
  chi2_pearson <- chisq.test(tabla, correct=FALSE)
  
  # Correccion de Yates (solo tablas 2x2)
  chi2_yates <- if (r==2 && c==2) chisq.test(tabla, correct=TRUE) else NULL
  
  # Fisher exacto (solo tablas 2x2 o cuando esperados < 5)
  fisher_res <- if (r==2 && c==2) {
    tryCatch(fisher.test(tabla), error=function(e) NULL)
  } else NULL
  
  # Estadistico principal
  chi2_stat <- chi2_pearson$statistic
  df_chi    <- chi2_pearson$parameter
  p_pearson <- chi2_pearson$p.value
  
  # Si muchas celdas con esperado < 5, usar Fisher
  use_fisher <- !is.null(fisher_res) && pct_low_expected > 20
  
  # Tamaño de efecto
  phi <- sqrt(chi2_stat / n)
  df_min <- min(r-1, c-1)
  v_cramer <- sqrt(chi2_stat / (n * df_min))
  
  # Tabla de contingencia como lista
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
  
  # Marginals
  row_totals <- as.list(rowSums(tabla))
  col_totals <- as.list(colSums(tabla))
  
  sig <- p_pearson < alpha
  
  # Redaccion APA
  method_used <- if(use_fisher) "Fisher exacto" else if(!is.null(chi2_yates)) "Chi-cuadrado con correccion Yates" else "Chi-cuadrado de Pearson"
  
  list(
    test_type     = "chi_cuadrado",
    method_used   = method_used,
    n             = n,
    r             = r,
    c             = c,
    # Chi-cuadrado Pearson
    chi2          = round(chi2_stat, 3),
    df            = as.integer(df_chi),
    p             = round(p_pearson, 4),
    p_apa         = if(p_pearson<.001)"< .001" else paste0("= ",formatC(p_pearson,digits=3,format="f")),
    # Yates
    chi2_yates    = if(!is.null(chi2_yates)) round(chi2_yates$statistic,3) else NULL,
    p_yates       = if(!is.null(chi2_yates)) round(chi2_yates$p.value,4) else NULL,
    # Fisher
    p_fisher      = if(!is.null(fisher_res)) round(fisher_res$p.value,4) else NULL,
    or_fisher     = if(!is.null(fisher_res) && !is.null(fisher_res$estimate)) round(fisher_res$estimate,3) else NULL,
    # Tamaño de efecto
    phi           = round(phi, 3),
    v_cramer      = round(v_cramer, 3),
    v_interpret   = interpret_v_cramer(v_cramer, df_min),
    # Supuestos
    min_expected  = round(min_expected, 2),
    pct_low_expected = round(pct_low_expected, 1),
    assumption_ok = pct_low_expected <= 20,
    assumption_note = if(pct_low_expected>20) paste0(round(pct_low_expected),"% de celdas con frecuencia esperada < 5. Usar Fisher exacto.") else "Supuestos cumplidos.",
    use_fisher    = use_fisher,
    # Tabla
    contingency_table = tabla_list,
    row_names     = rownames(tabla),
    col_names     = colnames(tabla),
    row_totals    = as.list(rowSums(tabla)),
    col_totals    = as.list(colSums(tabla)),
    # Decision
    significant   = sig,
    decision      = if(sig)"Se rechaza H0" else "No se rechaza H0",
    alpha         = alpha
  )
}
