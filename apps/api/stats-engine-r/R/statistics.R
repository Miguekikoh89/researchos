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

    data.frame(
      variable  = v,
      n         = length(x),
      mean      = round(mean(x), 3),
      median    = round(median(x), 3),
      mode      = round(moda_v, 3),
      sd        = round(sd(x), 3),
      min       = round(min(x), 3),
      max       = round(max(x), 3),
      skewness  = round(psych::skew(x), 3),
      kurtosis  = round(psych::kurtosi(x), 3),
      cv_pct    = round(sd(x) / mean(x) * 100, 1),
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
# ResearchOS — Cronbach Completo SPSS-identico
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

    # Factor analysis con 1 factor (igual que SPSS)
    fa_res <- factanal(df_items, factors = 1, rotation = "none")
    loadings <- as.numeric(fa_res$loadings)
    uniqueness <- fa_res$uniquenesses

    # Varianza explicada por el factor
    sum_load_sq <- sum(loadings)^2
    sum_uniq    <- sum(uniqueness)
    var_total   <- sum_load_sq + sum_uniq

    omega_t <- sum_load_sq / var_total
    # omega_h = omega_t para un solo factor (son iguales)
    omega_h <- omega_t

    list(
      omega_h    = round(omega_h, 3),
      omega_t    = round(omega_t, 3),
      loadings   = round(loadings, 3),
      uniqueness = round(uniqueness, 3)
    )
  }, error = function(e) {
    list(omega_h = NA, omega_t = NA, loadings = NULL, uniqueness = NULL)
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
  al <- max(0, min(1, (k / (k - 1)) * (1 - vi / vt)))

  # Alfa estandarizado (basado en correlaciones — igual SPSS)
  R_mat  <- cor(df_items)
  r_mean <- mean(R_mat[lower.tri(R_mat)])
  al_std <- (k * r_mean) / (1 + (k - 1) * r_mean)

  # IC de Feldt (1965) — mismo metodo que SPSS
  Fu <- qf(0.975, n - 1, (n - 1) * (k - 1))
  Fl <- qf(0.025, n - 1, (n - 1) * (k - 1))
  ci_lower <- round(max(0, 1 - (1 - al) * Fu), 3)
  ci_upper <- round(min(1, 1 - (1 - al) * Fl), 3)

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
      max(0, min(1, (k2 / (k2 - 1)) * (1 - vi2 / vt2))) else NA

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
    alpha_std        = round(al_std, 3),
    ci_lower         = ci_lower,
    ci_upper         = ci_upper,
    k                = k,
    n                = n,
    interpretation   = interpret_alpha(al),
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
                           method  = "percentil",
                           scale   = c(1, 5),
                           levels  = c("Bajo", "Medio", "Alto"),
                           cuts    = NULL) {
  x <- x[!is.na(x)]
  if (length(x) < 5) {
    stop(paste0("Muestra insuficiente para calcular baremo de: ", var_name))
  }

  # Calcular cortes según método
  cortes <- switch(method,
    teorico   = c(scale[1],
                  scale[1] + diff(scale) / 3,
                  scale[1] + 2 * diff(scale) / 3,
                  scale[2]),
    percentil = c(min(x), quantile(x, .33), quantile(x, .67), max(x)),
    tercil    = c(min(x), quantile(x, 1/3), quantile(x, 2/3), max(x)),
    custom_cut = {
      if (is.null(cuts) || length(cuts) < 2)
        stop("Para custom_cut se requieren 2 puntos de corte.")
      c(min(x), cuts[1], cuts[2], max(x))
    },
    # default = percentil
    c(min(x), quantile(x, .33), quantile(x, .67), max(x))
  )

  cortes <- unique(round(cortes, 2))
  if (length(cortes) < 4) {
    stop("No se pudieron determinar cortes únicos para el baremo.")
  }

  # Tabla de baremo
  tabla <- data.frame(
    nivel = levels,
    desde = cortes[1:3],
    hasta = cortes[2:4],
    stringsAsFactors = FALSE
  )

  # Frecuencias
  cats  <- cut(x, breaks = cortes, labels = levels, include.lowest = TRUE)
  freq  <- as.data.frame(table(cats, useNA = "no"))
  names(freq) <- c("nivel", "f")
  freq$pct    <- round(freq$f / length(x) * 100, 1)
  freq$pct_ac <- cumsum(freq$pct)

  list(
    variable    = var_name,
    table       = tabla,
    frequencies = freq,
    cuts        = cortes,
    levels      = levels,
    n           = length(x),
    method      = method
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
        row$sw_p <- as.numeric(formatC(sw$p.value, digits=4, format="f"))
        row$sw_normal    <- sw$p.value >= alpha
      }
    }

    # Kolmogorov-Smirnov (Lilliefors) — sin límite de n
    if ("ks" %in% tests && length(x) >= 3) {
      ks <- tryCatch(nortest::lillie.test(x), error = function(e) NULL)
      if (!is.null(ks)) {
        row$ks_statistic <- round(ks$statistic, 4)
        row$ks_p <- as.numeric(formatC(ks$p.value, digits=4, format="f"))
        row$ks_normal    <- ks$p.value >= alpha
      }
    }

    # Decisión final: normal solo si TODAS las pruebas indican normalidad
    flags <- c()
    if (!is.null(row$sw_normal)) flags <- c(flags, row$sw_normal)
    if (!is.null(row$ks_normal)) flags <- c(flags, row$ks_normal)
    row$decision <- if (length(flags) > 0 && all(flags)) "Normal" else "No normal"

    as.data.frame(row, stringsAsFactors = FALSE)
  })

  do.call(dplyr::bind_rows, rows)
}

#' Determinar método de correlación automáticamente
#'
#' @param norm_res  data.frame de resultados de normalidad
#' @param force     "auto", "pearson" o "spearman"
#' @return "pearson" o "spearman"
decide_method <- function(norm_res, force = "auto", x = NULL, y = NULL) {
  if (force %in% c("pearson", "spearman", "kendall")) return(force)

  # Fallback: sin datos crudos disponibles, conserva el criterio anterior (solo normalidad)
  if (is.null(x) || is.null(y)) {
    if (is.null(norm_res) || nrow(norm_res) == 0) return("spearman")
    return(if (all(norm_res$decision == "Normal")) "pearson" else "spearman")
  }

  valid <- complete.cases(x, y)
  x <- x[valid]; y <- y[valid]; n <- length(x)
  if (n < 4) return("spearman")

  # Kendall: muestras pequenas o con muchos empates
  prop_ties <- max(mean(duplicated(x)), mean(duplicated(y)))
  if (n < 10 || prop_ties > 0.25) return("kendall")

  is_normal <- !is.null(norm_res) && nrow(norm_res) > 0 && all(norm_res$decision == "Normal")

  # Comparar ajuste lineal vs. monotonico (basado en rangos)
  r2_linear <- suppressWarnings(tryCatch(cor(x, y)^2, error = function(e) NA))
  r2_monotonic <- suppressWarnings(tryCatch(cor(rank(x), rank(y))^2, error = function(e) NA))
  monotonic_much_better <- !is.na(r2_linear) && !is.na(r2_monotonic) && (r2_monotonic - r2_linear) > 0.10

  # Outliers influyentes via distancia de Cook (regresion simple)
  # Cook (1977): D > 1 es el umbral clasico de observacion verdaderamente
  # influyente; 4/n es solo una señal de alerta exploratoria, demasiado
  # sensible en muestras pequeñas para usarse como criterio de decision unico.
  has_influential_outliers <- tryCatch({
    m <- lm(y ~ x)
    ck <- cooks.distance(m)
    any(ck > 1, na.rm = TRUE)
  }, error = function(e) FALSE)

  if (is_normal && !monotonic_much_better && !has_influential_outliers) "pearson" else "spearman"
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
# ResearchOS — Módulo de Correlación SPSS-idéntico
# IC Fisher, corrección empates Spearman, Kendall tau-b
# Referencia: SPSS Statistics 29, Conover (1999), Fieller et al. (1957)
# ============================================================================

# format_r_apa, format_p_apa, stars_p, interpret_r, effect_size_label
# definidas canonicamente en helpers.R — no duplicar aqui.

# ── IC de Fisher para Pearson y Spearman ────────────────────────────────────
# SPSS usa transformacion z de Fisher: z = arctanh(r)
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
  df   <- n - 2
  ci   <- fisher_ci(r, n, alpha)
  list(
    r        = round(r, 4),
    t        = round(t_val, 4),
    df       = df,
    p        = round(p, 4),
    ci_lower = ci$lower,
    ci_upper = ci$upper,
    power    = power_r(r, n, alpha),
    method   = "pearson"
  )
}

# ── Spearman con IC Fisher y correccion empates (SPSS) ──────────────────────
# SPSS calcula p exacta con distribucion t cuando n <= 30
# Para n > 30 usa aproximacion z con correccion de empates de Conover (1999)

correlate_spearman <- function(x, y, alpha = 0.05, alternative = "two.sided") {
  n    <- length(x)
  test <- cor.test(x, y, method = "spearman",
                   alternative = alternative, exact = (n <= 30))
  r    <- as.numeric(test$estimate)
  p    <- as.numeric(test$p.value)

  # Estadístico t para IC (aproximación de Fisher sobre rho de Spearman)
  t_val <- r * sqrt((n - 2) / (1 - r^2))
  df    <- n - 2

  # IC via Fisher (misma formula que Pearson — SPSS hace esto)
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
    t              = round(t_val, 4),
    df             = df,
    p              = round(p, 4),
    ci_lower       = ci$lower,
    ci_upper       = ci$upper,
    power          = power_r(r, n, alpha),
    tie_correction = tie_correction,
    method         = "spearman"
  )
}

# ── Kendall tau-b (SPSS Statistics) ─────────────────────────────────────────
# SPSS reporta tau-b (corregido por empates en X e Y)
# Formula exacta: tau_b = (P - Q) / sqrt((P+Q+Tx)(P+Q+Ty))

correlate_kendall <- function(x, y, alpha = 0.05, alternative = "two.sided") {
  n    <- length(x)
  test <- cor.test(x, y, method = "kendall", alternative = alternative,
                   exact = (n <= 50))
  tau  <- as.numeric(test$estimate)
  p    <- as.numeric(test$p.value)
  z    <- as.numeric(test$statistic)

  # SE aproximado de Kendall (Fieller, Hartley & Pearson 1957)
  se_tau <- sqrt((2 * (2 * n + 5)) / (9 * n * (n - 1)))

  # IC directo (sin Fisher — Kendall no usa transformacion atanh)
  z_crit <- qnorm(1 - alpha / 2)
  ci_lower <- round(tau - z_crit * se_tau, 3)
  ci_upper <- round(tau + z_crit * se_tau, 3)

  list(
    r        = round(tau, 4),
    z        = round(z, 4),
    p        = round(p, 4),
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    se       = round(se_tau, 4),
    power    = power_r(tau, n, alpha),
    method   = "kendall"
  )
}

# ── Verificacion de supuestos ────────────────────────────────────────────────

check_correlation_assumptions <- function(x, y, method, alpha = 0.05) {
  n <- length(x)
  warnings <- character(0)
  notes    <- character(0)

  # 1. Tamaño muestral
  if (n < 30) {
    warnings <- c(warnings, paste0("Muestra pequeña (n = ", n, "). Se recomienda n ≥ 30 para mayor potencia."))
  }

  # 2. Outliers bivariados — Distancia de Mahalanobis
  tryCatch({
    datos <- cbind(x, y)
    centro <- colMeans(datos)
    S      <- cov(datos)
    D2     <- mahalanobis(datos, centro, S)
    umbral <- qchisq(0.975, df = 2)
    n_out  <- sum(D2 > umbral)
    if (n_out > 0) {
      warnings <- c(warnings, paste0(n_out, " outlier(s) bivariado(s) detectado(s) (Mahalanobis, p < .025)."))
    }
  }, error = function(e) NULL)

  # 3. Linealidad (solo Pearson)
  if (method == "pearson") {
    tryCatch({
      r_lin  <- cor(x, y, method = "pearson")
      # Eta cuadrado via ANOVA
      grupos <- cut(x, breaks = 5)
      eta2   <- summary(aov(y ~ grupos))[[1]][1, 2] / sum((y - mean(y))^2)
      if (!is.na(eta2) && !is.na(r_lin) && eta2 > r_lin^2 + 0.1) {
        notes <- c(notes, "Posible relacion no lineal detectada. Considere Spearman.")
      }
    }, error = function(e) NULL)
  }

  # 4. Potencia estadística
  r_obs <- cor(x, y, method = method)
  pow   <- power_r(r_obs, n, alpha)
  if (!is.na(pow) && pow < 0.80) {
    notes <- c(notes, paste0("Potencia estadística = ", round(pow * 100), "% (recomendado ≥ 80%)."))
  }

  list(warnings = warnings, notes = notes, n = n, power = pow)
}

# ── Función principal: correlate_pair SPSS-idéntico ─────────────────────────

correlate_pair <- function(x, y, method = "spearman", alpha = 0.05, hypothesis_type = "bilateral") {
  valid <- complete.cases(x, y)
  x <- x[valid]; y <- y[valid]
  n <- length(x)

  if (n < 3) {
    return(list(r=NA, p=NA, n=n, method=method, significant=FALSE,
                decision="Muestra insuficiente", r_apa="NA", p_apa="NA",
                stars="", magnitude="NA", effect_size="NA",
                ci_lower=NA, ci_upper=NA, power=NA))
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
    p              = p,
    n              = n,
    t              = res$t %||% NA,
    df             = res$df %||% NA,
    z              = res$z %||% NA,
    ci_lower       = res$ci_lower,
    ci_upper       = res$ci_upper,
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

  add_corr <- function(name_a, name_b) {
    if (!(name_a %in% names(scores)) || !(name_b %in% names(scores))) return()
    cr <- correlate_pair(scores[[name_a]], scores[[name_b]], method, alpha, hypothesis_type)
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
      method      = method,
      type        = "general",
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
    for (db in dims_b) {
      cr <- correlate_pair(scores[[var_a_name]], scores[[db]], method, alpha, hypothesis_type)
      results[[length(results) + 1]] <- data.frame(
        var_a = var_a_name, var_b = db,
        r = cr$r, p = cr$p, n = cr$n,
        r_apa = cr$r_apa, p_apa = cr$p_apa, stars = cr$stars,
        magnitude = cr$magnitude, effect_size = cr$effect_size,
        decision = cr$decision, significant = cr$significant,
        method = method, type = "vdB", ci_lower = cr$ci_lower, ci_upper = cr$ci_upper, power = cr$power, stringsAsFactors = FALSE
      )
    }
  }

  # Variable B × Dimensiones de A
  if ("vdA" %in% analysis_types && length(dims_a) > 0) {
    for (da in dims_a) {
      cr <- correlate_pair(scores[[da]], scores[[var_b_name]], method, alpha, hypothesis_type)
      results[[length(results) + 1]] <- data.frame(
        var_a = da, var_b = var_b_name,
        r = cr$r, p = cr$p, n = cr$n,
        r_apa = cr$r_apa, p_apa = cr$p_apa, stars = cr$stars,
        magnitude = cr$magnitude, effect_size = cr$effect_size,
        decision = cr$decision, significant = cr$significant,
        method = method, type = "vdA", ci_lower = cr$ci_lower, ci_upper = cr$ci_upper, power = cr$power, stringsAsFactors = FALSE
      )
    }
  }

  # Dimensiones A × Dimensiones B
  if ("dd" %in% analysis_types && length(dims_a) > 0 && length(dims_b) > 0) {
    for (da in dims_a) {
      for (db in dims_b) {
        cr <- correlate_pair(scores[[da]], scores[[db]], method, alpha, hypothesis_type)
        results[[length(results) + 1]] <- data.frame(
          var_a = da, var_b = db,
          r = cr$r, p = cr$p, n = cr$n,
          r_apa = cr$r_apa, p_apa = cr$p_apa, stars = cr$stars,
          magnitude = cr$magnitude, effect_size = cr$effect_size,
          decision = cr$decision, significant = cr$significant,
          method = method, type = "dd", ci_lower = cr$ci_lower, ci_upper = cr$ci_upper, power = cr$power, stringsAsFactors = FALSE
        )
      }
    }
  }

  final_df <- do.call(rbind, results)
  if (is.data.frame(final_df) && nrow(final_df) > 1 && tolower(as.character(multiple_correction)) != "none") {
    method_adj <- switch(tolower(as.character(multiple_correction)),
      "bonferroni" = "bonferroni", "fdr" = "fdr", "holm" = "holm", "bonferroni")
    final_df$p_adjusted <- round(p.adjust(final_df$p, method = method_adj), 4)
    final_df$significant <- final_df$p_adjusted < alpha
    final_df$p_apa <- sapply(final_df$p_adjusted, function(p) if(is.na(p)) "NA" else if(p<.001) "< .001" else paste0("= ", formatC(p, digits=3, format="f")))
    final_df$decision <- ifelse(final_df$significant, "Se rechaza H0", "No se rechaza H0")
    final_df$correction_applied <- method_adj
  }
  final_df
}
