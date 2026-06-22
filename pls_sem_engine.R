# ============================================================================
# CANCHARI PLS-SEM ENGINE — Módulo para CanchariOS
# Extraído y adaptado de Canchari PLS-SEM PRO V6.0
# Entrada: JSON con parámetros del modelo
# Salida:  JSON con resultados para el frontend
# ============================================================================

suppressPackageStartupMessages({
  library(seminr)
  library(jsonlite)
  library(dplyr)
  library(openxlsx)
  library(officer)
  library(flextable)
})

# ── Helpers ──────────────────────────────────────────────────────────────────

`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b

safe_num <- function(x, digits = 3) {
  if (is.null(x) || length(x) == 0) return(NA_real_)
  val <- suppressWarnings(as.numeric(x[1]))
  if (is.na(val)) return(NA_real_)
  round(val, digits)
}

clean_names <- function(n) {
  n <- gsub("[^[:alnum:]]", "_", n)
  n <- gsub("^([0-9])", "X\\1", n)
  n
}

parse_item_range <- function(range_str, data_names) {
  if (is.null(range_str) || trimws(range_str) == "") return(NULL)
  parts <- unlist(strsplit(range_str, ","))
  final <- c()
  for (p in parts) {
    p <- trimws(p)
    if (grepl("-", p)) {
      rp <- strsplit(p, "-")[[1]]
      if (length(rp) == 2) {
        prefix <- sub("[0-9]+$", "", trimws(rp[1]))
        s <- suppressWarnings(as.numeric(sub("^.*?([0-9]+)$", "\\1", trimws(rp[1]))))
        e <- suppressWarnings(as.numeric(sub("^.*?([0-9]+)$", "\\1", trimws(rp[2]))))
        if (!is.na(s) && !is.na(e)) final <- c(final, paste0(prefix, s:e))
      }
    } else {
      final <- c(final, p)
    }
  }
  valid <- data_names[match(tolower(final), tolower(data_names))]
  unique(valid[!is.na(valid)])
}

calc_cr_ave <- function(L) {
  if (is.null(L)) return(data.frame(Constructo = character(), CR = numeric(), AVE = numeric()))
  L <- as.matrix(L)
  constructs <- colnames(L)
  out <- data.frame(Constructo = constructs, CR = NA_real_, AVE = NA_real_, stringsAsFactors = FALSE)
  for (j in seq_along(constructs)) {
    lam <- suppressWarnings(as.numeric(L[, j]))
    lam <- lam[!is.na(lam) & lam != 0]
    if (!length(lam)) next
    cr  <- (sum(lam)^2) / ((sum(lam)^2) + sum(1 - lam^2))
    ave <- sum(lam^2) / length(lam)
    out$CR[j]  <- round(cr, 3)
    out$AVE[j] <- round(ave, 3)
  }
  out
}

format_p_apa <- function(p) {
  if (is.na(p)) return("N/D")
  if (p < 0.001) return("< .001")
  formatC(p, digits = 3, format = "f")
}

# ── Función principal ─────────────────────────────────────────────────────────
#
# Parámetros de entrada (JSON → list):
#   data_path        : ruta al Excel/CSV con los datos
#   constructs       : list( name="C1", items=c("P1","P2","P3") )
#   paths            : list( from="C1", to="C2" )
#   n_boot           : número de bootstraps (default 5000)
#   calc_q2          : calcular Q² blindfolding (default TRUE)
#   omission_distance: distancia de omisión para Q² (default 7)
#   study_title      : título del estudio
#   language         : "es" | "en"
#
run_pls_sem <- function(params) {

  # ── 1. Cargar datos ──────────────────────────────────────────────────────
  data_path <- params$data_path
  ext <- tolower(tools::file_ext(data_path))
  if (ext %in% c("xlsx", "xls")) {
    df_raw <- openxlsx::read.xlsx(data_path)
  } else {
    df_raw <- read.csv(data_path, stringsAsFactors = FALSE)
  }

  # Convertir a numérico y limpiar nombres
  df_num <- as.data.frame(lapply(df_raw, function(x)
    suppressWarnings(as.numeric(as.character(x)))))
  names(df_num) <- clean_names(names(df_raw))
  df_num <- df_num[complete.cases(df_num), ]

  # Jitter mínimo para estabilidad numérica
  set.seed(42)
  df_j <- as.data.frame(lapply(df_num, function(col)
    if (is.numeric(col) && length(unique(col)) > 5) jitter(col, amount = 1e-4) else col))
  N <- nrow(df_j)

  # ── 2. Modelo de medida ──────────────────────────────────────────────────
  constructs_list <- params$constructs  # list of {name, items}
  paths_list      <- params$paths       # list of {from, to}

  c_seminr <- list()
  construct_items_map <- list()

  for (ct in constructs_list) {
    nm    <- ct$name
    items <- ct$items
    # Resolver items que existen en los datos
    avail <- intersect(items, names(df_j))
    if (length(avail) == 0) next
    # Single-item fix: duplicar con jitter mínimo
    if (length(avail) == 1) {
      dup_col <- paste0(avail[1], "__dup__")
      df_j[[dup_col]] <- jitter(df_j[[avail[1]]], amount = 1e-9)
      avail <- c(avail, dup_col)
    }
    c_seminr[[length(c_seminr) + 1]] <- composite(nm, avail)
    construct_items_map[[nm]] <- avail
  }

  if (length(c_seminr) == 0) stop("Ningún constructo válido en los datos.")
  m_model <- do.call(constructs, c_seminr)

  # ── 3. Modelo estructural ─────────────────────────────────────────────────
  p_seminr <- list()
  p_df     <- data.frame(from = character(), to = character(), stringsAsFactors = FALSE)

  for (pt in paths_list) {
    p_seminr[[length(p_seminr) + 1]] <- paths(from = pt$from, to = pt$to)
    p_df <- rbind(p_df, data.frame(from = pt$from, to = pt$to, stringsAsFactors = FALSE))
  }

  if (length(p_seminr) == 0) stop("Ninguna relación estructural definida.")
  s_model <- do.call(relationships, p_seminr)

  # ── 4. Estimación PLS-SEM ────────────────────────────────────────────────
  pls_est <- tryCatch(
    estimate_pls(data = df_j, measurement_model = m_model, structural_model = s_model),
    error = function(e) {
      # Rescue con jitter mayor
      df_rescue <- as.data.frame(lapply(df_j, function(col)
        if (is.numeric(col)) jitter(col, amount = 0.001) else col))
      estimate_pls(data = df_rescue, measurement_model = m_model, structural_model = s_model)
    }
  )
  summ <- summary(pls_est)

  # Construct scores
  scores_df <- tryCatch(as.data.frame(pls_est$construct_scores), error = function(e) NULL)

  # ── 5. Bootstrapping ─────────────────────────────────────────────────────
  n_boot <- as.integer(params$n_boot %||% 5000)
  set.seed(123)

  boot_est  <- tryCatch(
    bootstrap_model(seminr_model = pls_est, nboot = n_boot, cores = 1, seed = 123),
    error = function(e) NULL
  )
  boot_summ <- if (!is.null(boot_est))
    tryCatch(summary(boot_est), error = function(e) NULL) else NULL

  # Extraer coeficientes bootstrapped
  bp <- if (!is.null(boot_summ))
    tryCatch(as.data.frame(boot_summ$bootstrapped_paths), error = function(e) NULL) else NULL

  path_keys <- paste0(p_df$from, " -> ", p_df$to)
  df_t <- max(N - 1, 1)

  if (!is.null(bp) && nrow(bp) > 0) {
    path_lbl <- rownames(bp) %||% paste0("Path_", seq_len(nrow(bp)))
    beta_v   <- suppressWarnings(as.numeric(bp[[1]]))
    se_v     <- if (ncol(bp) >= 3) suppressWarnings(as.numeric(bp[[3]])) else rep(NA_real_, nrow(bp))
    ci_lo_v  <- if (ncol(bp) >= 5) suppressWarnings(as.numeric(bp[[5]])) else beta_v - 1.96 * se_v
    ci_hi_v  <- if (ncol(bp) >= 6) suppressWarnings(as.numeric(bp[[6]])) else beta_v + 1.96 * se_v
  } else {
    # Fallback sin bootstrap
    pm_fb <- tryCatch(as.matrix(pls_est$path_coef), error = function(e) NULL)
    path_lbl <- path_keys
    beta_v   <- sapply(path_keys, function(pk) {
      pt <- strsplit(pk, " -> ")[[1]]
      if (!is.null(pm_fb) && length(pt) == 2 &&
          pt[1] %in% rownames(pm_fb) && pt[2] %in% colnames(pm_fb))
        as.numeric(pm_fb[pt[1], pt[2]]) else NA_real_
    })
    se_v    <- rep(NA_real_, length(path_keys))
    ci_lo_v <- rep(NA_real_, length(path_keys))
    ci_hi_v <- rep(NA_real_, length(path_keys))
  }

  STDEV_raw <- suppressWarnings(as.numeric(se_v)); STDEV_raw[STDEV_raw == 0] <- NA
  beta_v    <- suppressWarnings(as.numeric(beta_v))
  T_raw     <- beta_v / STDEV_raw
  p_raw     <- 2 * (1 - pt(abs(T_raw), df = df_t))

  paths_tbl <- data.frame(
    Path    = path_lbl,
    Beta    = round(beta_v, 3),
    STDEV   = round(STDEV_raw, 3),
    T_Valor = round(T_raw, 3),
    P_Valor = round(p_raw, 4),
    IC_2.5  = round(ci_lo_v, 3),
    IC_97.5 = round(ci_hi_v, 3),
    Sig     = ifelse(p_raw < 0.001, "***",
              ifelse(p_raw < 0.01,  "**",
              ifelse(p_raw < 0.05,  "*",
              ifelse(p_raw < 0.10,  "†", "n.s.")))),
    stringsAsFactors = FALSE
  )

  # ── 6. Confiabilidad y validez convergente ────────────────────────────────
  rel_raw <- tryCatch(as.data.frame(summ$reliability), error = function(e) NULL)
  cr_ave  <- calc_cr_ave(summ$loadings)

  alpha_v <- if (!is.null(rel_raw))
    suppressWarnings(as.numeric(rel_raw[[
      grep("cronbach|alpha", tolower(names(rel_raw)), value = FALSE)[1]
    ]])) else rep(NA_real_, nrow(cr_ave))

  reliability_tbl <- data.frame(
    Constructo             = cr_ave$Constructo,
    Cronbach_Alpha         = round(alpha_v, 3),
    Composite_Reliability  = cr_ave$CR,
    AVE                    = cr_ave$AVE,
    stringsAsFactors = FALSE
  )

  # ── 7. Cargas factoriales ─────────────────────────────────────────────────
  ld <- summ$loadings
  loadings_tbl <- as.data.frame(as.table(ld)) %>%
    filter(Freq != 0) %>%
    rename(Item = Var1, Constructo = Var2, Loading = Freq) %>%
    mutate(Loading = round(as.numeric(Loading), 3),
           OK = ifelse(Loading >= 0.7, "✓", ifelse(Loading >= 0.4, "⚠", "✗")))

  # ── 8. HTMT ──────────────────────────────────────────────────────────────
  validity_obj <- tryCatch(summ$validity, error = function(e) NULL)
  htmt_obj     <- if (!is.null(validity_obj)) tryCatch(validity_obj$htmt, error = function(e) NULL) else NULL

  htmt_tbl <- if (!is.null(htmt_obj)) {
    h <- as.data.frame(as.table(htmt_obj))
    h %>%
      filter(!is.na(Freq) & Var1 != Var2) %>%
      rename(C1 = Var1, C2 = Var2, HTMT = Freq) %>%
      mutate(HTMT = round(as.numeric(HTMT), 3),
             OK   = ifelse(HTMT < 0.85, "✓ <0.85",
                    ifelse(HTMT < 0.90, "⚠ <0.90", "✗ ≥0.90")))
  } else data.frame(Nota = "HTMT no disponible")

  # ── 9. Fornell-Larcker ───────────────────────────────────────────────────
  fl_tbl <- NULL
  if (!is.null(scores_df) && nrow(cr_ave) > 0) {
    ave_map  <- setNames(cr_ave$AVE, cr_ave$Constructo)
    cons_fl  <- cr_ave$Constructo[cr_ave$Constructo %in% names(scores_df)]
    if (length(cons_fl) >= 2) {
      phi <- round(cor(scores_df[, cons_fl, drop = FALSE], use = "pairwise.complete.obs"), 3)
      fl_mat <- phi
      diag(fl_mat) <- round(sqrt(ave_map[cons_fl]), 3)
      fl_df <- as.data.frame(fl_mat)
      fl_df$Constructo <- rownames(fl_df)
      fl_df$OK <- sapply(rownames(phi), function(r) {
        diag_val <- sqrt(ave_map[r])
        off_max  <- max(abs(phi[r, setdiff(colnames(phi), r)]), na.rm = TRUE)
        if (!is.na(diag_val) && !is.na(off_max) && diag_val > off_max) "✓ OK" else "✗ REVISAR"
      })
      fl_tbl <- fl_df
    }
  }

  # ── 10. R² ───────────────────────────────────────────────────────────────
  r2_tbl <- data.frame(Constructo = character(), R2 = numeric(), R2_adj = numeric(), stringsAsFactors = FALSE)
  endos  <- unique(p_df$to)

  for (endo in endos) {
    preds <- unique(p_df$from[p_df$to == endo])
    preds <- preds[preds %in% names(scores_df)]
    if (!length(preds) || !endo %in% names(scores_df)) next
    d   <- data.frame(y = scores_df[[endo]], scores_df[, preds, drop = FALSE])
    fit <- tryCatch(stats::lm(y ~ ., data = d), error = function(e) NULL)
    if (!is.null(fit)) {
      s <- summary(fit)
      r2_tbl <- rbind(r2_tbl, data.frame(
        Constructo = endo,
        R2         = round(s$r.squared, 3),
        R2_adj     = round(s$adj.r.squared, 3),
        Nivel      = ifelse(s$r.squared >= 0.75, "Sustancial",
                    ifelse(s$r.squared >= 0.50, "Moderado",
                    ifelse(s$r.squared >= 0.25, "Débil", "Muy débil"))),
        stringsAsFactors = FALSE
      ))
    }
  }

  # ── 11. Q² Blindfolding ───────────────────────────────────────────────────
  q2_tbl <- data.frame(Constructo = character(), Q2 = numeric(), stringsAsFactors = FALSE)

  if (isTRUE(params$calc_q2 %||% TRUE) && !is.null(scores_df)) {
    d_omit <- as.integer(params$omission_distance %||% 7)

    for (endo in endos) {
      preds <- unique(p_df$from[p_df$to == endo])
      preds <- preds[preds %in% names(scores_df)]
      if (!length(preds) || !endo %in% names(scores_df)) next

      y_all  <- scores_df[[endo]]
      X_all  <- as.matrix(scores_df[, preds, drop = FALSE])
      n_obs  <- length(y_all)
      SSO    <- sum(y_all^2)
      SSE_bf <- 0

      for (k in seq_len(d_omit)) {
        omit_idx <- seq(k, n_obs, by = d_omit)
        keep_idx <- setdiff(seq_len(n_obs), omit_idx)
        if (length(keep_idx) < ncol(X_all) + 2) next
        X_k <- X_all[keep_idx, , drop = FALSE]
        y_k <- y_all[keep_idx]
        fit_k <- tryCatch(stats::lm(y_k ~ X_k), error = function(e) NULL)
        if (is.null(fit_k)) next
        cf <- coef(fit_k)
        yhat_omit <- cf[1] + X_all[omit_idx, , drop = FALSE] %*% cf[-1]
        SSE_bf <- SSE_bf + sum((y_all[omit_idx] - yhat_omit)^2)
      }

      q2_val <- if (SSO > 0) round(1 - SSE_bf / SSO, 3) else NA_real_
      q2_tbl <- rbind(q2_tbl, data.frame(
        Constructo = endo,
        Q2         = q2_val,
        Nivel      = ifelse(!is.na(q2_val) & q2_val >= 0.35, "Alta",
                    ifelse(!is.na(q2_val) & q2_val >= 0.15, "Mediana",
                    ifelse(!is.na(q2_val) & q2_val >  0,    "Baja",
                           "Sin relevancia predictiva"))),
        stringsAsFactors = FALSE
      ))
    }
  }

  # ── 12. VIF ───────────────────────────────────────────────────────────────
  vif_rows <- list()
  if (!is.null(scores_df)) {
    for (endo in endos) {
      preds <- unique(p_df$from[p_df$to == endo])
      preds <- preds[preds %in% names(scores_df)]
      if (length(preds) == 0) next
      if (length(preds) == 1) {
        vif_rows[[length(vif_rows) + 1]] <- data.frame(
          Endogeno = endo, Predictor = preds, VIF = 1.0, stringsAsFactors = FALSE)
        next
      }
      for (x in preds) {
        otros <- setdiff(preds, x)
        fml   <- as.formula(paste0("`", x, "` ~ ",
                  paste0("`", otros, "`", collapse = " + ")))
        fit <- tryCatch(stats::lm(fml, data = scores_df[, c(x, otros), drop = FALSE]),
                        error = function(e) NULL)
        if (!is.null(fit)) {
          r2x  <- summary(fit)$r.squared
          vif_v <- if (!is.na(r2x) && r2x < 0.9999) round(1 / (1 - r2x), 3) else 999.0
          vif_rows[[length(vif_rows) + 1]] <- data.frame(
            Endogeno = endo, Predictor = x, VIF = vif_v,
            OK = ifelse(vif_v < 3.3, "✓ <3.3", ifelse(vif_v < 5, "⚠ <5", "✗ ≥5")),
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  vif_tbl <- if (length(vif_rows) > 0) do.call(rbind, vif_rows)
             else data.frame(Nota = "VIF no disponible")

  # ── 13. SRMR ─────────────────────────────────────────────────────────────
  srmr_val <- NA_real_
  for (nm in c("it_criteria", "quality", "model_criteria", "fit", "criteria")) {
    obj_s <- tryCatch(summ[[nm]]$srmr %||% summ[[nm]][["SRMR"]], error = function(e) NULL)
    if (!is.null(obj_s) && is.numeric(obj_s)) { srmr_val <- round(obj_s[1], 4); break }
  }

  srmr_tbl <- data.frame(
    Metrica  = "SRMR",
    Valor    = srmr_val,
    Criterio = "<= 0.08",
    OK       = if (!is.na(srmr_val))
                 ifelse(srmr_val <= 0.08, "✓ Buen ajuste", "⚠ Revisar")
               else "N/D",
    stringsAsFactors = FALSE
  )

  # ── 14. Efectos indirectos ────────────────────────────────────────────────
  ind_boot <- if (!is.null(boot_summ))
    tryCatch(as.data.frame(boot_summ$bootstrapped_indirect_paths), error = function(e) NULL)
  else NULL

  indirect_tbl <- NULL
  if (!is.null(ind_boot) && nrow(ind_boot) > 0) {
    ind_beta <- suppressWarnings(as.numeric(ind_boot[[1]]))
    ind_se   <- if (ncol(ind_boot) >= 3) suppressWarnings(as.numeric(ind_boot[[3]])) else rep(NA_real_, nrow(ind_boot))
    ind_lo   <- if (ncol(ind_boot) >= 5) suppressWarnings(as.numeric(ind_boot[[5]])) else ind_beta - 1.96 * ind_se
    ind_hi   <- if (ncol(ind_boot) >= 6) suppressWarnings(as.numeric(ind_boot[[6]])) else ind_beta + 1.96 * ind_se
    ind_T    <- ind_beta / ind_se
    ind_p    <- 2 * (1 - pt(abs(ind_T), df = df_t))

    indirect_tbl <- data.frame(
      Path     = rownames(ind_boot) %||% paste0("Ind_", seq_len(nrow(ind_boot))),
      Beta_ind = round(ind_beta, 3),
      STDEV    = round(ind_se,   3),
      T_Valor  = round(ind_T,    3),
      P_Valor  = round(ind_p,    4),
      IC_2.5   = round(ind_lo,   3),
      IC_97.5  = round(ind_hi,   3),
      Sig      = ifelse(ind_p < 0.001, "***",
                 ifelse(ind_p < 0.01,  "**",
                 ifelse(ind_p < 0.05,  "*", "n.s."))),
      stringsAsFactors = FALSE
    )
  }

  # ── 15. Tabla de hipótesis ────────────────────────────────────────────────
  hyp_rows <- list()
  for (k in seq_len(nrow(paths_tbl))) {
    hyp_rows[[k]] <- data.frame(
      Hipotesis = paste0("H", k),
      Relacion  = paths_tbl$Path[k],
      Beta      = paths_tbl$Beta[k],
      T_Valor   = paths_tbl$T_Valor[k],
      P_Valor   = paths_tbl$P_Valor[k],
      IC_2.5    = paths_tbl$IC_2.5[k],
      IC_97.5   = paths_tbl$IC_97.5[k],
      Sig       = paths_tbl$Sig[k],
      Decision  = ifelse(!is.na(paths_tbl$P_Valor[k]) & paths_tbl$P_Valor[k] < 0.05,
                         "✓ Soportada", "✗ Rechazada"),
      stringsAsFactors = FALSE
    )
  }
  hypothesis_tbl <- if (length(hyp_rows) > 0) do.call(rbind, hyp_rows) else data.frame()

  # ── 16. Interpretación automática ─────────────────────────────────────────
  lang <- params$language %||% "es"
  es   <- (lang == "es")

  interpretacion <- tryCatch({
    lines <- character(0)

    # Validez convergente
    ave_check <- all(reliability_tbl$AVE >= 0.5, na.rm = TRUE)
    cr_check  <- all(reliability_tbl$Composite_Reliability >= 0.7, na.rm = TRUE)
    lines <- c(lines, paste0(
      if (es) "Modelo de Medida: " else "Measurement Model: ",
      if (ave_check && cr_check) (if(es) "✓ AVE≥0.5 y CR≥0.7 confirmados en todos los constructos."
                                  else "✓ AVE≥0.5 and CR≥0.7 confirmed for all constructs.")
      else (if(es) "⚠ Revise AVE o CR en algunos constructos." else "⚠ Review AVE or CR in some constructs.")
    ))

    # HTMT
    if (is.data.frame(htmt_tbl) && "HTMT" %in% names(htmt_tbl)) {
      htmt_vals <- suppressWarnings(as.numeric(htmt_tbl$HTMT))
      ok_htmt   <- all(htmt_vals < 0.85, na.rm = TRUE)
      lines <- c(lines, paste0(
        if (es) "Validez Discriminante (HTMT): " else "Discriminant Validity (HTMT): ",
        if (ok_htmt) (if(es) "✓ Todos los HTMT < 0.85." else "✓ All HTMT < 0.85.")
        else (if(es) "⚠ Algunos HTMT ≥ 0.85, revisar." else "⚠ Some HTMT ≥ 0.85, review required.")
      ))
    }

    # R²
    if (nrow(r2_tbl) > 0) {
      for (i in seq_len(nrow(r2_tbl))) {
        r2v <- r2_tbl$R2[i]
        lines <- c(lines, paste0(
          if(es) "R² " else "R² ",
          r2_tbl$Constructo[i], " = ", r2v, " → ", r2_tbl$Nivel[i]
        ))
      }
    }

    # Hipótesis
    for (i in seq_len(nrow(paths_tbl))) {
      b  <- paths_tbl$Beta[i]
      pv <- paths_tbl$P_Valor[i]
      sig <- paths_tbl$Sig[i]
      lines <- c(lines, paste0(
        paths_tbl$Path[i], ": β=", b, ", p=", format_p_apa(pv), " ", sig,
        " → ", if (!is.na(pv) && pv < 0.05)
          (if(es) "✓ Soportada" else "✓ Supported")
        else
          (if(es) "✗ Rechazada" else "✗ Rejected")
      ))
    }

    paste(lines, collapse = "\n")
  }, error = function(e) "Interpretación no disponible")

  # ── 17. Resultado final ────────────────────────────────────────────────────
  list(
    success          = TRUE,
    engine           = "canchari_pls_sem_v5",
    n_observations   = N,
    n_boot           = n_boot,
    study_title      = params$study_title %||% "Modelo PLS-SEM",
    tables = list(
      Paths            = paths_tbl,
      Confiabilidad    = reliability_tbl,
      Cargas           = loadings_tbl,
      HTMT             = htmt_tbl,
      FornellLarcker   = fl_tbl,
      R2               = r2_tbl,
      Q2               = if (nrow(q2_tbl) > 0) q2_tbl else NULL,
      VIF              = vif_tbl,
      SRMR             = srmr_tbl,
      IndirectEffects  = indirect_tbl,
      Hypotheses       = hypothesis_tbl
    ),
    interpretacion   = interpretacion,
    pls_est_available = TRUE
  )
}

# ── CLI entry point ────────────────────────────────────────────────────────────
# Uso: Rscript pls_sem_engine.R '{"data_path":"...", "constructs":[...], "paths":[...], ...}'
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    cat(toJSON(list(success = FALSE, error = "No se proporcionaron parámetros."), auto_unbox = TRUE))
    quit(status = 1)
  }

  params <- tryCatch(
    fromJSON(args[1], simplifyVector = FALSE),
    error = function(e) NULL
  )

  if (is.null(params)) {
    cat(toJSON(list(success = FALSE, error = "JSON inválido."), auto_unbox = TRUE))
    quit(status = 1)
  }

  result <- tryCatch(
    run_pls_sem(params),
    error = function(e) list(success = FALSE, error = e$message)
  )

  cat(toJSON(result, auto_unbox = TRUE, na = "null"))
}
