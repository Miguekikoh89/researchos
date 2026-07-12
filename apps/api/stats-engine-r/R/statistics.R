# ============================================================================
# ResearchOS Stats Engine — statistics.R
# Estadística descriptiva, Cronbach, Baremos, Normalidad, Correlaciones
# Extraído y refactorizado desde CorrelaStat Pro v4.0
# ============================================================================


# ============================================================================
# ESTADÍSTICA DESCRIPTIVA
# ============================================================================

#' Calcular estadísticos descriptivos APA 7
#'
#' @param scores data.frame de puntajes por variable
#' @return data.frame con M, DE, Mdn, Min, Max, Asimetría, Curtosis, CV
compute_descriptives <- function(scores) {
  rows <- lapply(names(scores), function(v) {
    x <- scores[[v]]
    x <- x[!is.na(x)]
    if (length(x) < 2) return(NULL)

    moda_v <- tryCatch({
      tt <- table(round(x, 2))
      as.numeric(names(tt)[which.max(tt)])
    }, error = function(e) NA)

    media_v <- mean(x)
    sd_v <- sd(x)
    data.frame(
      variable  = v,
      n         = length(x),
      mean      = round(media_v, 3),
      median    = round(median(x), 3),
      iqr       = round(IQR(x), 3),
      mode      = round(moda_v, 3),
      sd        = round(sd_v, 3),
      min       = round(min(x), 3),
      max       = round(max(x), 3),
      skewness  = if (is.finite(sd_v) && sd_v > 0) round(psych::skew(x), 3) else NA_real_,
      kurtosis  = if (is.finite(sd_v) && sd_v > 0) round(psych::kurtosi(x), 3) else NA_real_,
      cv_pct    = if (is.finite(media_v) && abs(media_v) > sqrt(.Machine$double.eps)) round(sd_v / media_v * 100, 1) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, Filter(Negate(is.null), rows))
}

# ============================================================================
# ALFA DE CRONBACH CON INTERVALO DE CONFIANZA
# ============================================================================

#' Calcular Alfa de Cronbach con IC 95% (Feldt, 1965)
#'
#' @param df_items data.frame con solo los ítems de la escala
#' @return lista con alpha, ci_lower, ci_upper, k, n
# ============================================================================
# CanchariOS — confiabilidad reproducible
# Alfa, IC Feldt, alfa si elimina item, correlacion item-total corregida,
# correlacion inter-item, omega de McDonald (hierarquico y total)
# Ref: SPSS Statistics 29, Feldt(1965), McDonald(1999), Zinbarg(2005)
# ============================================================================

# interpret_alpha definida canonicamente en helpers.R

# ── Omega de McDonald ────────────────────────────────────────────────────────
# omega_h (jerarquico): varianza factor general / varianza total
# omega_t (total): suma varianzas factores / varianza total
# Se estima via analisis factorial de 1 factor (SPSS v27+)

compute_omega <- function(df_items) {
  tryCatch({
    k <- ncol(df_items)
    if (k < 3) return(list(omega_h = NA, omega_t = NA))

    # Análisis factorial de un factor para omega total
    # Pre-check: matriz singular bloquea factanal con error no capturado
    df_complete <- df_items[complete.cases(df_items), ]
    if (nrow(df_complete) < k + 5) return(list(omega_h=NA_real_, omega_t=NA_real_, omega_t_raw=NA_real_, loadings=NULL, uniqueness=NULL, warning="Muestra insuficiente para omega", method="one_factor_factanal"))
    cor_mat <- tryCatch(cor(df_complete, use="complete.obs"), error=function(e) NULL)
    if (is.null(cor_mat) || any(!is.finite(cor_mat))) return(list(omega_h=NA_real_, omega_t=NA_real_, omega_t_raw=NA_real_, loadings=NULL, uniqueness=NULL, warning="Matriz no invertible", method="one_factor_factanal"))
    det_val <- tryCatch(det(cor_mat), error=function(e) 0)
    if (!is.finite(det_val) || abs(det_val) < 1e-10) return(list(omega_h=NA_real_, omega_t=NA_real_, omega_t_raw=NA_real_, loadings=NULL, uniqueness=NULL, warning="Matriz singular", method="one_factor_factanal"))
    fa_res <- factanal(df_complete, factors = 1, rotation = "none")
    loadings <- as.numeric(fa_res$loadings)
    uniqueness <- fa_res$uniquenesses

    # Varianza explicada por el factor
    sum_load_sq <- sum(loadings)^2
    sum_uniq    <- sum(uniqueness)
    var_total   <- sum_load_sq + sum_uniq

    omega_t <- sum_load_sq / var_total
    # omega_h requiere un modelo jerárquico/bifactorial; no se iguala artificialmente a omega_t.
    omega_h <- NA_real_

    list(
      omega_h    = omega_h,
      omega_t    = round(omega_t, 3),
      omega_t_raw= as.numeric(omega_t),
      loadings   = round(loadings, 3),
      uniqueness = round(uniqueness, 3),
      method     = "one_factor_factanal"
    )
  }, error = function(e) {
    list(omega_h = NA_real_, omega_t = NA_real_, omega_t_raw=NA_real_, loadings = NULL, uniqueness = NULL, warning=conditionMessage(e), method="one_factor_factanal")
  })
}

# ── Cronbach completo SPSS ───────────────────────────────────────────────────

cronbach_alpha_ic <- function(df_items) {
  df_items <- as.data.frame(lapply(df_items, function(x) as.numeric(unlist(x))), stringsAsFactors=FALSE)
  df_items <- df_items[complete.cases(df_items), , drop = FALSE]
  k <- ncol(df_items)
  n <- nrow(df_items)

  if (k < 2 || n < 3) {
    return(list(alpha=NA, ci_lower=NA, ci_upper=NA, n=n, k=k,
                interpretation=NA, item_stats=NULL, omega=NULL,
                inter_item_mean=NA, alpha_std=NA))
  }

  vt <- var(rowSums(df_items))
  vi <- sum(apply(df_items, 2, var))

  if (vt == 0) {
    return(list(alpha=NA, ci_lower=NA, ci_upper=NA, n=n, k=k,
                interpretation=NA, item_stats=NULL, omega=NULL,
                inter_item_mean=NA, alpha_std=NA))
  }

  # Alfa de Cronbach clasico
  al <- (k / (k - 1)) * (1 - vi / vt)

  # Alfa estandarizado basado en la correlación inter-ítem media
  R_mat  <- cor(df_items)
  r_mean <- mean(R_mat[lower.tri(R_mat)])
  al_std <- (k * r_mean) / (1 + (k - 1) * r_mean)

  # IC de Feldt (1965)
  Fu <- qf(0.975, n - 1, (n - 1) * (k - 1))
  Fl <- qf(0.025, n - 1, (n - 1) * (k - 1))
  ci_lower <- 1 - (1 - al) * Fu
  ci_upper <- 1 - (1 - al) * Fl

  # ── Estadisticos por item (tabla SPSS "Estadisticos total-elemento") ───────
  item_stats <- lapply(seq_len(k), function(i) {
    item_name <- names(df_items)[i]
    xi        <- df_items[, i]
    resto     <- rowSums(df_items[, -i, drop = FALSE])
    total     <- rowSums(df_items)

    # Correlacion item-total corregida (sin el item en el total — SPSS)
    r_it_corr <- cor(xi, resto)

    # Correlacion item-total sin corregir
    r_it_raw <- cor(xi, total)

    # Media y SD del item
    m_item <- mean(xi, na.rm = TRUE)
    sd_item <- sd(xi, na.rm = TRUE)

    # Media de la escala si se elimina el item
    m_scale_del <- mean(resto)

    # Varianza de la escala si se elimina el item
    v_scale_del <- var(resto)

    # Alfa si se elimina el item
    df_sin_i <- df_items[, -i, drop = FALSE]
    k2 <- k - 1
    vt2 <- var(rowSums(df_sin_i))
    vi2 <- sum(apply(df_sin_i, 2, var))
    al_del <- if (vt2 > 0 && k2 >= 2)
      (k2 / (k2 - 1)) * (1 - vi2 / vt2) else NA

    # Correlacion multiple al cuadrado (R² — SPSS lo reporta)
    tryCatch({
      lm_res <- lm(xi ~ ., data = df_items[, -i, drop = FALSE])
      r2 <- summary(lm_res)$r.squared
    }, error = function(e) { r2 <<- NA })

    list(
      item              = item_name,
      mean              = round(m_item, 3),
      sd                = round(sd_item, 3),
      mean_scale_del    = round(m_scale_del, 3),
      var_scale_del     = round(v_scale_del, 3),
      r_item_total_corr = round(r_it_corr, 3),
      r_item_total_raw  = round(r_it_raw, 3),
      r_squared_mult    = round(tryCatch(r2, error=function(e) NA), 3),
      alpha_if_deleted  = round(al_del, 3),
      interpretation_del = interpret_alpha(al_del)
    )
  })
  names(item_stats) <- names(df_items)

  # Correlacion inter-item media (SPSS "Estadisticos de resumen")
  inter_item_mean <- round(r_mean, 3)
  inter_item_min  <- round(min(R_mat[lower.tri(R_mat)]), 3)
  inter_item_max  <- round(max(R_mat[lower.tri(R_mat)]), 3)

  # Omega de McDonald
  omega <- compute_omega(df_items)

  list(
    alpha            = round(al, 3),
    alpha_raw        = as.numeric(al),
    alpha_std        = round(al_std, 3),
    alpha_std_raw    = as.numeric(al_std),
    ci_lower         = as.numeric(ci_lower),
    ci_upper         = as.numeric(ci_upper),
    ci_method        = "Feldt",
    k                = k,
    n                = n,
    interpretation   = interpret_alpha(al),
    negative_alpha   = is.finite(al) && al < 0,
    inter_item_mean  = inter_item_mean,
    inter_item_min   = inter_item_min,
    inter_item_max   = inter_item_max,
    item_stats       = item_stats,
    omega            = omega
  )
}

# ── compute_reliability actualizado ─────────────────────────────────────────

compute_reliability <- function(raw_data, items_map) {
  results <- lapply(names(items_map), function(nm) {
    items <- as.character(unlist(items_map[[nm]]))
    cols  <- intersect(items, names(raw_data))
    if (length(cols) < 2) return(NULL)
    df_sub <- raw_data[, cols, drop = FALSE]
    cr <- cronbach_alpha_ic(df_sub)
    cr$name <- nm
    cr
  })
  Filter(Negate(is.null), results)
}
#' Calcular baremo para una variable
#'
#' @param x        vector numérico de puntajes
#' @param var_name nombre de la variable
#' @param method   "teorico", "percentil", "tercil", "custom_cut"
#' @param scale    vector c(min, max) de la escala
#' @param levels   vector de 3 etiquetas de nivel
#' @param cuts     vector c(corte1, corte2) para method="custom_cut"
#' @return lista con tabla, frecuencias, metadatos
compute_baremo <- function(x, var_name,
                           method  = "teorico",
                           scale   = c(1, 5),
                           levels  = c("Bajo", "Medio", "Alto"),
                           cuts    = NULL) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]

  if (length(x) < 5) {
    stop(paste0("Muestra insuficiente para calcular baremo de: ", var_name))
  }

  if (length(levels) != 3) {
    stop("El baremo requiere exactamente tres niveles.")
  }

  method <- tolower(trimws(as.character(method)))

  cortes <- switch(
    method,
    teorico = c(
      scale[1],
      scale[1] + diff(scale) / 3,
      scale[1] + 2 * diff(scale) / 3,
      scale[2]
    ),
    percentil = c(
      min(x),
      unname(quantile(x, 0.25, na.rm = TRUE, type = 7)),
      unname(quantile(x, 0.75, na.rm = TRUE, type = 7)),
      max(x)
    ),
    tercil = c(
      min(x),
      unname(quantile(x, 1 / 3, na.rm = TRUE, type = 7)),
      unname(quantile(x, 2 / 3, na.rm = TRUE, type = 7)),
      max(x)
    ),
    custom_cut = {
      if (is.null(cuts) || length(cuts) < 2) {
        stop("Para custom_cut se requieren dos puntos de corte.")
      }
      c(min(x), as.numeric(cuts[1]), as.numeric(cuts[2]), max(x))
    },
    stop(paste0("Método de baremo no reconocido: ", method))
  )

  if (length(cortes) != 4 || any(!is.finite(cortes)) || any(diff(cortes) <= 0)) {
    stop("No se pudieron determinar cortes válidos y crecientes para el baremo.")
  }

  # Se conservan los cortes exactos para evitar errores por redondeo.
  # Los extremos infinitos garantizan que ningún participante quede sin clasificar.
  # Tolerancia numérica para incluir correctamente los valores situados
  # exactamente en los límites teóricos (por ejemplo, 28/12).
  tolerancia <- sqrt(.Machine$double.eps) *
    max(1, abs(cortes[2]), abs(cortes[3]))

  if (method == "teorico") {
    cortes_clasificacion <- c(
      -Inf,
      cortes[2] + tolerancia,
      cortes[3] + tolerancia,
      Inf
    )
  } else {
    cortes_clasificacion <- c(-Inf, cortes[2], cortes[3], Inf)
  }

  cats <- cut(
    x,
    breaks = cortes_clasificacion,
    labels = levels,
    include.lowest = TRUE,
    right = TRUE
  )

  if (any(is.na(cats))) {
    stop("Existen participantes sin clasificar en el baremo.")
  }

  frecuencias <- as.integer(table(factor(cats, levels = levels)))

  if (sum(frecuencias) != length(x)) {
    stop("La suma de frecuencias del baremo no coincide con el tamaño de la muestra.")
  }

  freq <- data.frame(
    nivel = levels,
    f = frecuencias,
    stringsAsFactors = FALSE
  )
  freq$pct <- round(freq$f / length(x) * 100, 2)
  freq$pct_ac <- round(cumsum(freq$f) / length(x) * 100, 2)

  tabla <- data.frame(
    nivel = levels,
    desde = cortes[1:3],
    hasta = cortes[2:4],
    stringsAsFactors = FALSE
  )

  list(
    variable = var_name,
    table = tabla,
    frequencies = freq,
    cuts = cortes,
    levels = levels,
    n = length(x),
    method = method
  )
}

# ============================================================================
# NORMALIDAD
# ============================================================================

#' Pruebas de normalidad (Shapiro-Wilk y Kolmogorov-Smirnov/Lilliefors)
#'
#' @param scores    data.frame de puntajes
#' @param alpha     nivel de significancia
#' @param tests     vector: "sw" y/o "ks"
#' @return data.frame con resultados y decisión
compute_normality <- function(scores, alpha = 0.05, tests = c("sw", "ks")) {
  rows <- lapply(names(scores), function(v) {
    x   <- scores[[v]]
    x   <- x[!is.na(x)]
    row <- list(variable = v, n = length(x))

    # Shapiro-Wilk (n entre 3 y 5000)
    if ("sw" %in% tests && length(x) >= 3 && length(x) <= 5000) {
      sw <- tryCatch(shapiro.test(x), error = function(e) NULL)
      if (!is.null(sw)) {
        row$sw_statistic <- round(sw$statistic, 4)
        row$sw_p <- as.numeric(sw$p.value)
        row$sw_normal    <- sw$p.value >= alpha
      }
    }

    # Kolmogorov-Smirnov (Lilliefors) — sin límite de n
    if ("ks" %in% tests && length(x) >= 3) {
      ks <- tryCatch(nortest::lillie.test(x), error = function(e) NULL)
      if (!is.null(ks)) {
        row$ks_statistic <- round(ks$statistic, 4)
        row$ks_p <- as.numeric(ks$p.value)
        row$ks_normal    <- ks$p.value >= alpha
      }
    }

    # Decisión final: normal solo si TODAS las pruebas calculadas indican normalidad.
    # Si ninguna prueba pudo calcularse, no se inventa una decisión.
    flags <- c()
    if (!is.null(row$sw_normal)) flags <- c(flags, row$sw_normal)
    if (!is.null(row$ks_normal)) flags <- c(flags, row$ks_normal)
    row$decision <- if (length(flags) == 0) "No disponible" else if (all(flags)) "Normal" else "No normal"

    as.data.frame(row, stringsAsFactors = FALSE)
  })

  do.call(dplyr::bind_rows, rows)
}

#' Determinar método de correlación automáticamente
#'
#' @param norm_res  data.frame de resultados de normalidad
#' @param force     "auto", "pearson" o "spearman"
#' @return "pearson" o "spearman"
decide_method <- function(norm_res, force = "auto", x = NULL, y = NULL, alpha = 0.05) {
  if (force %in% c("pearson", "spearman", "kendall")) return(force)

  # Fallback: sin datos crudos disponibles, conserva el criterio anterior (solo normalidad)
  if (is.null(x) || is.null(y)) {
    if (is.null(norm_res) || nrow(norm_res) == 0) return("spearman")
    return(if (all(norm_res$decision == "Normal")) "pearson" else "spearman")
  }

  valid <- complete.cases(x, y)
  x <- x[valid]; y <- y[valid]; n <- length(x)
  if (n < 4) return("spearman")

  # Spearman admite empates mediante rangos promedio.
  # Kendall solo se utiliza cuando el usuario lo selecciona expresamente.

  # La selección automática debe depender únicamente del par analizado.
  # No se utilizan aquí las dimensiones u otras variables incluidas en
  # norm_res, porque podrían cambiar indebidamente el método del par principal.
  vector_is_normal <- function(v) {
    v <- v[is.finite(v)]

    if (length(v) < 3 || length(unique(v)) < 2) {
      return(FALSE)
    }

    # Shapiro-Wilk está definido en R para 3 <= n <= 5000.
    # Para muestras mayores se adopta una decisión conservadora.
    if (length(v) > 5000) {
      return(FALSE)
    }

    prueba <- tryCatch(
      shapiro.test(v),
      error = function(e) NULL
    )

    !is.null(prueba) &&
      is.finite(prueba$p.value) &&
      prueba$p.value >= alpha
  }

  is_normal <- vector_is_normal(x) && vector_is_normal(y)

  # P4: Kendall cuando pocas categorias unicas o muchos empates
  n_unique_x <- length(unique(x)); n_unique_y <- length(unique(y))
  few_categories <- n_unique_x <= 5 || n_unique_y <= 5
  prop_ties_x <- 1 - n_unique_x / n; prop_ties_y <- 1 - n_unique_y / n
  many_ties <- prop_ties_x > 0.30 || prop_ties_y > 0.30
  small_n   <- n < 20
  use_kendall <- (few_categories && many_ties) || (small_n && many_ties)

  # Comparar ajuste lineal vs monotonico
  r2_linear    <- suppressWarnings(tryCatch(cor(x, y)^2,            error=function(e) NA))
  r2_monotonic <- suppressWarnings(tryCatch(cor(rank(x),rank(y))^2, error=function(e) NA))
  monotonic_much_better <- !is.na(r2_linear) && !is.na(r2_monotonic) && (r2_monotonic - r2_linear) > 0.10

  # P8: Deteccion de relacion no monotonica (curva U)
  non_monotonic_warning <- tryCatch({
    lm_lin  <- lm(y ~ x)
    lm_quad <- lm(y ~ x + I(x^2))
    p_quad  <- anova(lm_lin, lm_quad)[["Pr(>F)"]][2]
    r2_lin  <- summary(lm_lin)$r.squared
    r2_quad <- summary(lm_quad)$r.squared
    !is.na(p_quad) && p_quad < 0.05 && (r2_quad - r2_lin) > 0.05
  }, error=function(e) FALSE)

  # Outliers influyentes via Cook
  has_influential_outliers <- tryCatch({
    m  <- lm(y ~ x)
    ck <- cooks.distance(m)
    any(ck > 1, na.rm = TRUE)
  }, error=function(e) FALSE)

  # Decision final
  method_chosen <- if (use_kendall) "kendall" else if (is_normal && !monotonic_much_better && !has_influential_outliers) "pearson" else "spearman"
  attr(method_chosen, "non_monotonic_warning") <- non_monotonic_warning
  attr(method_chosen, "use_kendall_reason") <- if (use_kendall) paste0("Variables con pocas categorias o muchos empates (", round(max(prop_ties_x,prop_ties_y)*100), "pct). Kendall tau-b es mas estable.") else NULL
  method_chosen
}

# ============================================================================
# CORRELACIONES
# ============================================================================

#' Calcular correlación entre dos vectores
#'
#' @param x, y  vectores numéricos
#' @param method "pearson" o "spearman"
#' @param alpha  nivel de significancia
#' @return lista con r/rho, p, n, decisión
# ============================================================================
# ResearchOS — Módulo de correlación reproducible
# IC Fisher, corrección empates Spearman, Kendall tau-b
# Referencia: SPSS Statistics 29, Conover (1999), Fieller et al. (1957)
# ============================================================================

# format_r_apa, format_p_apa, stars_p, interpret_r, effect_size_label
# definidas canonicamente en helpers.R — no duplicar aqui.

# ── IC de Fisher para Pearson y Spearman ────────────────────────────────────
# Aproximación z de Fisher: z = arctanh(r)
# SE(z) = 1/sqrt(n-3)
# IC: tanh(z ± z_alpha/2 * SE)

fisher_ci <- function(r, n, alpha = 0.05) {
  if (is.na(r) || n < 4) return(list(lower = NA, upper = NA))
  z     <- atanh(r)
  se    <- 1 / sqrt(n - 3)
  z_crit <- qnorm(1 - alpha / 2)
  lower <- tanh(z - z_crit * se)
  upper <- tanh(z + z_crit * se)
  list(
    lower = round(lower, 3),
    upper = round(upper, 3)
  )
}

# ── Potencia estadística (Cohen 1988) ───────────────────────────────────────
power_r <- function(r, n, alpha = 0.05) {
  if (is.na(r) || n < 4) return(NA)
  z_r    <- atanh(abs(r))
  se     <- 1 / sqrt(n - 3)
  z_crit <- qnorm(1 - alpha / 2)
  lambda <- z_r / se
  power  <- pnorm(lambda - z_crit) + pnorm(-lambda - z_crit)
  round(min(max(power, 0), 1), 3)
}

# ── Pearson con IC Fisher ────────────────────────────────────────────────────
correlate_pearson <- function(x, y, alpha = 0.05, alternative = "two.sided") {
  n    <- length(x)
  test <- cor.test(x, y, method = "pearson", alternative = alternative)
  r    <- as.numeric(test$estimate)
  p    <- as.numeric(test$p.value)
  t_val <- as.numeric(test$statistic)
  if (!is.finite(t_val)) t_val <- NA_real_
  df   <- n - 2
  ci   <- fisher_ci(r, n, alpha)
  list(
    r        = round(r, 4),
    r_raw    = r,
    t        = if(is.finite(t_val)) round(t_val, 4) else NA_real_,
    df       = df,
    p        = p,
    ci_lower = ci$lower,
    ci_upper = ci$upper,
    ci_method = "fisher_z",
    power    = power_r(r, n, alpha),
    power_note = "Potencia observada descriptiva; no reemplaza un análisis a priori",
    method   = "pearson"
  )
}

# ── Spearman con IC Fisher aproximado y diagnóstico de empates ──────────────
# El valor p exacto solo se solicita cuando n <= 30 y no existen empates.
# Con empates o muestras mayores, cor.test utiliza la aproximación asintótica.

correlate_spearman <- function(x, y, alpha = 0.05, alternative = "two.sided") {
  n    <- length(x)
  use_exact <- n <= 30 && !anyDuplicated(x) && !anyDuplicated(y)
  test <- suppressWarnings(cor.test(x, y, method = "spearman",
                   alternative = alternative, exact = use_exact))
  r    <- as.numeric(test$estimate)
  p    <- as.numeric(test$p.value)

  # Estadístico t diagnóstico; para |rho| = 1 el límite es infinito y se reporta no disponible.
  t_val <- if(abs(r) < 1) r * sqrt((n - 2) / (1 - r^2)) else NA_real_
  df    <- n - 2

  # IC aproximado mediante transformación z de Fisher
  ci <- fisher_ci(r, n, alpha)

  # Correccion por empates: factor CF = 1 - (sum_ties_x + sum_ties_y) / (n*(n^2-1)/3)
  ties_x <- table(rank(x))
  ties_y <- table(rank(y))
  cf_x   <- sum(ties_x^3 - ties_x) / 12
  cf_y   <- sum(ties_y^3 - ties_y) / 12
  cf_denom <- (n * (n^2 - 1) / 6)
  tie_correction <- if (cf_denom > 0) round(1 - (cf_x + cf_y) / cf_denom, 4) else 1

  list(
    r              = round(r, 4),
    r_raw          = r,
    t              = if(is.finite(t_val)) round(t_val, 4) else NA_real_,
    df             = df,
    p              = p,
    p_method       = if(use_exact) "exact_no_ties" else "asymptotic",
    ci_lower       = ci$lower,
    ci_upper       = ci$upper,
    ci_method      = "fisher_z_approximation",
    power          = power_r(r, n, alpha),
    power_note     = "Potencia observada descriptiva; no reemplaza un análisis a priori",
    tie_correction = tie_correction,
    method         = "spearman"
  )
}

# ── IC bootstrap percentil para Kendall tau-b ───────────────────────────────
kendall_bootstrap_ci <- function(x, y, alpha = 0.05,
                                 n_boot = 2000,
                                 seed = 20260703) {
  datos <- data.frame(
    x = as.numeric(x),
    y = as.numeric(y)
  )

  estadistico <- function(data, indices) {
    d <- data[indices, , drop = FALSE]

    if (length(unique(d$x)) < 2 || length(unique(d$y)) < 2) {
      return(NA_real_)
    }

    suppressWarnings(
      cor(
        d$x,
        d$y,
        method = "kendall",
        use = "complete.obs"
      )
    )
  }

  # Preservar el estado aleatorio global para no alterar otros análisis.
  tenia_seed <- exists(
    ".Random.seed",
    envir = .GlobalEnv,
    inherits = FALSE
  )

  if (tenia_seed) {
    seed_anterior <- get(
      ".Random.seed",
      envir = .GlobalEnv,
      inherits = FALSE
    )
  }

  on.exit({
    if (tenia_seed) {
      assign(
        ".Random.seed",
        seed_anterior,
        envir = .GlobalEnv
      )
    } else if (exists(
      ".Random.seed",
      envir = .GlobalEnv,
      inherits = FALSE
    )) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  set.seed(seed)

  boot_result <- boot::boot(
    data = datos,
    statistic = estadistico,
    R = n_boot
  )

  valores <- as.numeric(boot_result$t)
  valores <- valores[is.finite(valores)]

  minimo_valido <- max(200L, ceiling(n_boot * 0.80))

  if (length(valores) < minimo_valido) {
    return(list(
      lower = NA_real_,
      upper = NA_real_,
      valid = length(valores),
      requested = n_boot,
      method = "bootstrap_unavailable"
    ))
  }

  intervalo <- unname(
    quantile(
      valores,
      probs = c(alpha / 2, 1 - alpha / 2),
      type = 6,
      na.rm = TRUE
    )
  )

  list(
    lower = as.numeric(intervalo[1]),
    upper = as.numeric(intervalo[2]),
    valid = length(valores),
    requested = n_boot,
    method = "bootstrap_percentile"
  )
}

# ── Kendall tau-b (SPSS Statistics) ─────────────────────────────────────────
# SPSS reporta tau-b (corregido por empates en X e Y)
# Formula exacta: tau_b = (P - Q) / sqrt((P+Q+Tx)(P+Q+Ty))

correlate_kendall <- function(x, y, alpha = 0.05, alternative = "two.sided") {
  n <- length(x)

  # La prueba exacta de Kendall solo es válida cuando no existen empates.
  # El valor p puede ser exacto, pero el estadístico denominado "z" debe
  # provenir siempre de la aproximación asintótica, no del estadístico T.
  use_exact <- n <= 50 &&
    !anyDuplicated(x) &&
    !anyDuplicated(y)

  test_p <- suppressWarnings(
    cor.test(
      x, y,
      method = "kendall",
      alternative = alternative,
      exact = use_exact
    )
  )

  test_z <- suppressWarnings(
    cor.test(
      x, y,
      method = "kendall",
      alternative = alternative,
      exact = FALSE
    )
  )

  tau <- as.numeric(test_p$estimate)
  p   <- as.numeric(test_p$p.value)
  z   <- as.numeric(test_z$statistic)

  # Error estándar asintótico conservado únicamente como diagnóstico.
  se_tau <- sqrt((2 * (2 * n + 5)) / (9 * n * (n - 1)))

  # El IC de tau-b se estima mediante bootstrap percentil reproducible.
  # Esto respeta los límites naturales [-1, 1] y admite empates.
  ci_boot <- kendall_bootstrap_ci(
    x = x,
    y = y,
    alpha = alpha,
    n_boot = 2000,
    seed = 20260703
  )

  ci_lower <- ci_boot$lower
  ci_upper <- ci_boot$upper

  list(
    r        = round(tau, 4),
    r_raw    = tau,
    z        = z,
    p        = p,
    p_method = if (use_exact) "exact" else "asymptotic",
    ci_lower       = ci_lower,
    ci_upper       = ci_upper,
    ci_method      = ci_boot$method,
    bootstrap_valid = ci_boot$valid,
    bootstrap_requested = ci_boot$requested,
    se             = se_tau,
    power          = power_r(tau, n, alpha),
    method         = "kendall"
  )
}

# ── Verificacion de supuestos ────────────────────────────────────────────────

check_correlation_assumptions <- function(x, y, method, alpha = 0.05) {
  n <- length(x)
  warnings <- character(0)
  notes    <- character(0)
  supuestos_tabla <- list()

  if (n < 30)
    warnings <- c(warnings, paste0("Muestra pequena (n = ", n, "). Se recomienda n >= 30."))

  # 1. Linealidad: termino cuadratico
  linealidad <- list(procedimiento="Termino cuadratico", resultado="-", decision="No evaluado")
  if (method == "pearson") {
    linealidad <- tryCatch({
      lm_lin  <- lm(y ~ x)
      lm_quad <- lm(y ~ x + I(x^2))
      p_quad  <- anova(lm_lin, lm_quad)[["Pr(>F)"]][2]
      mejora  <- summary(lm_quad)$r.squared - summary(lm_lin)$r.squared
      es_curva <- !is.na(p_quad) && p_quad < alpha && mejora > 0.05
      if (es_curva) warnings <<- c(warnings, "Posible relacion no lineal. Considere Spearman.")
      list(procedimiento="Termino cuadratico",
           resultado=if(!is.na(p_quad)) paste0("p = ", sub("^0\\.",".",sprintf("%.3f",p_quad))) else "-",
           decision=if(es_curva)"Se detecto curvatura" else "No se detecto curvatura significativa")
    }, error=function(e) list(procedimiento="Termino cuadratico",resultado="-",decision="No calculado"))
  }
  supuestos_tabla[["linealidad"]] <- linealidad

  # 2. Homocedasticidad: Breusch-Pagan aproximado
  homoced <- list(procedimiento="Breusch-Pagan", resultado="-", decision="No evaluado")
  if (method == "pearson") {
    homoced <- tryCatch({
      m     <- lm(y ~ x)
      res2  <- residuals(m)^2
      bp_lm <- lm(res2 ~ x)
      bp_f  <- summary(bp_lm)$fstatistic
      bp_p  <- pf(bp_f[1], bp_f[2], bp_f[3], lower.tail=FALSE)
      hetero <- !is.na(bp_p) && bp_p < alpha
      if (hetero) notes <<- c(notes, "Heterocedasticidad detectada. Interprete Pearson con precaucion.")
      list(procedimiento="Breusch-Pagan",
           resultado=if(!is.na(bp_p)) paste0("p = ",sub("^0\\.",".",sprintf("%.3f",bp_p))) else "-",
           decision=if(hetero)"Se detecto heterocedasticidad" else "No se detecto heterocedasticidad")
    }, error=function(e) list(procedimiento="Breusch-Pagan",resultado="-",decision="No calculado"))
  }
  supuestos_tabla[["homocedasticidad"]] <- homoced

  # 3. Outliers bivariados: Mahalanobis
  outliers_biv <- tryCatch({
    D2    <- mahalanobis(cbind(x,y), colMeans(cbind(x,y)), cov(cbind(x,y)))
    n_out <- sum(D2 > qchisq(0.975, df=2))
    if (n_out > 0) warnings <<- c(warnings, paste0(n_out, " outlier(s) bivariado(s) (Mahalanobis)."))
    list(procedimiento="Distancia de Mahalanobis",
         resultado=paste0(n_out," caso(s) atipico(s)"),
         decision=if(n_out==0)"Supuesto razonablemente cumplido" else paste0(n_out," caso(s) detectado(s)"))
  }, error=function(e) list(procedimiento="Distancia de Mahalanobis",resultado="-",decision="No calculado"))
  supuestos_tabla[["outliers"]] <- outliers_biv

  # 4. Influencia: Cook
  cook_res <- tryCatch({
    ck    <- cooks.distance(lm(y ~ x))
    n_inf <- sum(ck > 1, na.rm=TRUE)
    if (n_inf > 0) notes <<- c(notes, paste0(n_inf," caso(s) influyente(s) (Cook > 1)."))
    list(procedimiento="Distancia de Cook",
         resultado=paste0("Max = ",round(max(ck,na.rm=TRUE),3)),
         decision=if(n_inf==0)"Sin influencia extrema" else paste0(n_inf," caso(s) influyente(s)"))
  }, error=function(e) list(procedimiento="Distancia de Cook",resultado="-",decision="No calculado"))
  supuestos_tabla[["influencia"]] <- cook_res

  r_obs <- tryCatch(cor(x, y, method=method), error=function(e) NA)
  pow   <- power_r(r_obs, n, alpha)
  if (!is.na(pow) && pow < 0.80)
    notes <- c(notes, paste0("Potencia = ",round(pow*100),"% (recomendado >= 80%)."))

  list(warnings=warnings, notes=notes, n=n, power=pow, supuestos_tabla=supuestos_tabla)
}

correlate_pair <- function(x, y, method = "spearman", alpha = 0.05, hypothesis_type = "bilateral") {
  method <- tolower(trimws(as.character(method)))
  hypothesis_type <- tolower(trimws(as.character(hypothesis_type)))

  if (!(method %in% c("pearson", "spearman", "kendall"))) {
    stop(paste0("Método de correlación no reconocido: ", method))
  }

  if (!is.numeric(alpha) || length(alpha) != 1 ||
      !is.finite(alpha) || alpha <= 0 || alpha >= 1) {
    stop("El nivel alfa debe ser un número entre 0 y 1.")
  }

  if (!(hypothesis_type %in%
        c("bilateral", "unilateral_pos", "unilateral_neg"))) {
    stop(paste0(
      "Tipo de hipótesis no reconocido: ",
      hypothesis_type
    ))
  }

  if (length(x) != length(y)) {
    stop("Las variables correlacionadas deben tener la misma cantidad de observaciones.")
  }

  x <- suppressWarnings(as.numeric(x))
  y <- suppressWarnings(as.numeric(y))

  valid <- complete.cases(x, y) & is.finite(x) & is.finite(y)
  x <- x[valid]
  y <- y[valid]
  n <- length(x)

  if (n < 3) {
    stop(paste0(
      "Muestra insuficiente para correlación: se requieren al menos 3 pares válidos; se encontraron ",
      n,
      "."
    ))
  }

  if (length(unique(x)) < 2) {
    stop("La primera variable es constante; la correlación no está definida.")
  }

  if (length(unique(y)) < 2) {
    stop("La segunda variable es constante; la correlación no está definida.")
  }

  # Calcular según método
  res <- tryCatch({
    alt <- if(hypothesis_type=="unilateral_neg") "less" else if(hypothesis_type=="unilateral_pos") "greater" else "two.sided"
    if (method == "pearson")  correlate_pearson(x, y, alpha, alt)
    else if (method == "kendall") correlate_kendall(x, y, alpha, alt)
    else correlate_spearman(x, y, alpha, alt)
  }, error = function(e) {
    list(r=NA, p=NA, t=NA, df=NA, ci_lower=NA, ci_upper=NA,
         power=NA, method=method)
  })

  r   <- res$r
  p   <- res$p
  sig <- !is.na(p) && p < alpha

  # Supuestos
  supuestos <- tryCatch(
    check_correlation_assumptions(x, y, method, alpha),
    error = function(e) list(warnings=character(0), notes=character(0))
  )

  list(
    r              = r,
    r_raw          = res$r_raw %||% r,
    p              = p,
    n              = n,
    t              = res$t %||% NA,
    df             = res$df %||% NA,
    z              = res$z %||% NA,
    p_method       = res$p_method %||% NULL,
    ci_lower       = res$ci_lower,
    ci_upper       = res$ci_upper,
    ci_method      = res$ci_method %||% NULL,
    bootstrap_valid = res$bootstrap_valid %||% NULL,
    bootstrap_requested = res$bootstrap_requested %||% NULL,
    power          = res$power,
    tie_correction = res$tie_correction %||% NULL,
    method         = method,
    significant    = sig,
    decision       = if (sig) "Se rechaza H\u2080" else "No se rechaza H\u2080",
    r_apa          = format_r_apa(r),
    p_apa          = format_p_apa(p),
    stars          = stars_p(p),
    magnitude      = interpret_r(r),
    effect_size    = effect_size_label(r),
    assumptions    = supuestos
  )
}
compute_correlations <- function(scores, config, method = "spearman", hypothesis_type = "bilateral", multiple_correction = "none",
                                 alpha = 0.05,
                                 analysis_types = c("vv")) {
  results <- list()
  var_a_name <- config$var_a$name
  var_b_name <- config$var_b$name
  dims_a     <- vapply(config$var_a$dimensions, function(d) d$name, character(1))
  dims_b     <- vapply(config$var_b$dimensions, function(d) d$name, character(1))

  add_corr <- function(name_a, name_b, type_label = "general") {
    if (!(name_a %in% names(scores)) || !(name_b %in% names(scores))) return()
    # Decidir metodo PAR A PAR: cada dimension tiene su propia normalidad
    m_pair <- if (method %in% c("pearson","spearman","kendall")) method else
      decide_method(NULL, "auto", x = scores[[name_a]], y = scores[[name_b]], alpha = alpha)
    cr <- correlate_pair(scores[[name_a]], scores[[name_b]], m_pair, alpha, hypothesis_type)
    results[[length(results) + 1]] <<- data.frame(
      var_a       = name_a,
      var_b       = name_b,
      r           = cr$r,
      p           = cr$p,
      n           = cr$n,
      r_apa       = cr$r_apa,
      p_apa       = cr$p_apa,
      stars       = cr$stars,
      magnitude   = cr$magnitude,
      effect_size = cr$effect_size,
      decision    = cr$decision,
      significant = cr$significant,
      method      = m_pair,
      type        = type_label,
      ci_lower    = cr$ci_lower,
      ci_upper    = cr$ci_upper,
      power       = cr$power,
      stringsAsFactors = FALSE
    )
  }

  # Variable A × Variable B (siempre)
  if ("vv" %in% analysis_types) {
    add_corr(var_a_name, var_b_name)
  }

  # Variable A × Dimensiones de B
  if ("vdB" %in% analysis_types && length(dims_b) > 0) {
    for (db in dims_b) add_corr(var_a_name, db, "vdB")
  }

  # Variable B × Dimensiones de A
  if ("vdA" %in% analysis_types && length(dims_a) > 0) {
    for (da in dims_a) add_corr(da, var_b_name, "vdA")
  }

  # Dimensiones A × Dimensiones B
  if ("dd" %in% analysis_types && length(dims_a) > 0 && length(dims_b) > 0) {
    for (da in dims_a) {
      for (db in dims_b) add_corr(da, db, "dd")
    }
  }

  final_df <- do.call(rbind, results)
  if (is.data.frame(final_df) && nrow(final_df) > 1 && tolower(as.character(multiple_correction)) != "none") {
    method_adj <- switch(tolower(as.character(multiple_correction)),
      "bonferroni" = "bonferroni", "fdr" = "fdr", "holm" = "holm", "bonferroni")
    final_df$p_adjusted <- p.adjust(final_df$p, method = method_adj)
    final_df$significant <- final_df$p_adjusted < alpha
    final_df$p_apa <- sapply(final_df$p_adjusted, function(p) if(is.na(p)) "NA" else if(p<.001) "< .001" else paste0("= ", formatC(p, digits=3, format="f")))
    final_df$decision <- ifelse(final_df$significant, "Se rechaza H0", "No se rechaza H0")
    final_df$correction_applied <- method_adj
  }
  final_df
}
