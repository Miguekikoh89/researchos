# ResearchOS — Regresion Ordinal (Lote 1F)
# Cambio conceptual: la VD ordinal NO se recategoriza con cut()/quantile().
# La funcion detecta el tipo de VD y exige que el orden sea declarado
# explicitamente (ordered factor en el df, o parametro ordered_levels).
options(encoding = "UTF-8")

run_ordinal_regression <- function(df, var_a_items, var_b_items, var_a_name, var_b_name,
                                    alpha = 0.05, link_function = "logit",
                                    ordinalizacion = NULL,   # obsoleto, ignorado
                                    pseudo_r2_type = "nagelkerke",
                                    extra_predictors = NULL,
                                    ordered_levels = NULL) {
  tryCatch({
    if (!requireNamespace("MASS", quietly = TRUE))
      install.packages("MASS", repos = "https://cran.r-project.org")
    library(MASS)

    score_a <- if (length(var_a_items) > 1)
                 rowMeans(df[, var_a_items, drop = FALSE], na.rm = TRUE)
               else
                 df[[var_a_items]]

    # Para la VD: si es un solo item, preservar la estructura original (factor,
    # ordered factor, integer, etc.). Si son multiples items, calcular la media
    # (resultado numerico; requerira ordered_levels o sera bloqueado como continuo).
    raw_b <- if (length(var_b_items) == 1)
               df[[var_b_items]]
             else
               rowMeans(df[, var_b_items, drop = FALSE], na.rm = TRUE)

    # ─── Clasificar tipo de VD y construir ordered factor ────────────────────
    vd_ord     <- NULL
    warn_empty <- NULL

    if (is.ordered(raw_b)) {
      # Caso 1: ya es ordered factor → usar directamente, conservar levels
      obs_lvls   <- levels(droplevels(raw_b))
      empty_lvls <- setdiff(levels(raw_b), obs_lvls)
      if (length(empty_lvls) > 0) {
        warn_empty <- paste0(
          "Niveles declarados sin observaciones eliminados para la estimacion: ",
          paste(empty_lvls, collapse = ", ")
        )
      }
      if (length(obs_lvls) < 2) {
        return(list(
          blocked = TRUE, reason = "CATEGORIAS_INSUFICIENTES",
          error   = paste0(
            "La variable dependiente '", var_b_name, "' tiene solo ",
            length(obs_lvls), " categoria observada tras eliminar niveles vacios. ",
            "Se necesitan al menos 2 categorias con observaciones."
          ),
          details = list(observed_levels = obs_lvls, empty_levels = empty_lvls)
        ))
      }
      vd_ord <- droplevels(raw_b)

    } else if (is.factor(raw_b)) {
      # Caso 2: factor no ordenado → requiere ordered_levels o bloqueo
      if (is.null(ordered_levels)) {
        return(list(
          blocked = TRUE, reason = "ORDEN_NO_DECLARADO",
          error   = paste0(
            "La variable dependiente '", var_b_name,
            "' tiene categorias, pero su orden no fue declarado. ",
            "Proporcione ordered_levels para especificar el orden correcto (p.ej. ",
            "c('bajo','medio','alto'))."
          ),
          details = list(levels = levels(raw_b))
        ))
      }
      ordered_chars <- as.character(ordered_levels)
      vd_ord        <- ordered(as.character(raw_b), levels = ordered_chars)
      obs_lvls      <- levels(droplevels(vd_ord))
      empty_lvls    <- setdiff(ordered_chars, obs_lvls)
      if (length(empty_lvls) > 0) {
        warn_empty <- paste0(
          "Niveles declarados sin observaciones eliminados: ",
          paste(empty_lvls, collapse = ", ")
        )
        vd_ord <- droplevels(vd_ord)
        obs_lvls <- levels(vd_ord)
      }
      if (length(obs_lvls) < 2) {
        return(list(
          blocked = TRUE, reason = "CATEGORIAS_INSUFICIENTES",
          error   = paste0(
            "La variable dependiente '", var_b_name, "' tiene menos de 2 niveles ",
            "observados entre los declarados en ordered_levels."
          ),
          details = list(ordered_levels = ordered_chars, observed_levels = obs_lvls)
        ))
      }

    } else if (is.numeric(raw_b) || is.integer(raw_b)) {
      raw_b_clean <- na.omit(raw_b)
      n_unique    <- length(unique(raw_b_clean))
      is_decimal  <- any(abs(raw_b_clean - round(raw_b_clean)) > 1e-10)

      # Caso 4: continua
      if (n_unique > 10 || is_decimal) {
        return(list(
          blocked = TRUE, reason = "VD_CONTINUA",
          error   = paste0(
            "La variable dependiente '", var_b_name, "' es continua (",
            n_unique, " valores unicos",
            if (is_decimal) ", con decimales" else "", "). ",
            "La regresion ordinal requiere una variable dependiente con categorias ",
            "ordinales preexistentes en los datos (p.ej. 1/2/3 o bajo/medio/alto). ",
            "Si su variable es continua, utilice regresion lineal."
          ),
          details = list(n_unique = n_unique, has_decimals = is_decimal)
        ))
      }

      # Caso 5: menos de 2 categorias observadas
      if (n_unique < 2) {
        return(list(
          blocked = TRUE, reason = "CATEGORIAS_INSUFICIENTES",
          error   = paste0(
            "La variable dependiente '", var_b_name, "' tiene ", n_unique,
            " categoria observada. Se necesitan al menos 2."
          ),
          details = list(n_unique = n_unique,
                          observed = sort(unique(raw_b_clean)))
        ))
      }

      # Caso 3: numerica con pocas categorias → requiere ordered_levels
      if (is.null(ordered_levels)) {
        return(list(
          blocked = TRUE, reason = "ORDEN_NO_DECLARADO",
          error   = paste0(
            "La variable dependiente '", var_b_name, "' es numerica con ",
            n_unique, " categorias (",
            paste(sort(unique(raw_b_clean)), collapse = ", "), "). ",
            "Para regresion ordinal declare el orden mediante ordered_levels ",
            "(p.ej. c(1,2,3)) junto con measurement_level='ordinal'."
          ),
          details = list(observed_values = sort(unique(raw_b_clean)))
        ))
      }

      vd_ord     <- ordered(raw_b, levels = ordered_levels)
      obs_lvls   <- levels(droplevels(vd_ord))
      empty_lvls <- setdiff(as.character(ordered_levels), obs_lvls)
      if (length(empty_lvls) > 0) {
        warn_empty <- paste0(
          "Niveles declarados sin observaciones eliminados para la estimacion: ",
          paste(empty_lvls, collapse = ", ")
        )
        vd_ord   <- droplevels(vd_ord)
        obs_lvls <- levels(vd_ord)
      }
      if (length(obs_lvls) < 2) {
        return(list(
          blocked = TRUE, reason = "CATEGORIAS_INSUFICIENTES",
          error   = paste0(
            "La variable dependiente '", var_b_name,
            "' tiene menos de 2 categorias observadas con los niveles declarados."
          ),
          details = list(ordered_levels  = as.character(ordered_levels),
                          observed_levels = obs_lvls)
        ))
      }

    } else {
      # Caso: caracter u otro tipo — intentar con ordered_levels si se provee
      if (!is.null(ordered_levels)) {
        raw_b_char <- as.character(raw_b)
        vd_ord     <- ordered(raw_b_char, levels = as.character(ordered_levels))
        obs_lvls   <- levels(droplevels(vd_ord))
        empty_lvls <- setdiff(as.character(ordered_levels), obs_lvls)
        if (length(empty_lvls) > 0) {
          warn_empty <- paste0(
            "Niveles declarados sin observaciones eliminados: ",
            paste(empty_lvls, collapse = ", ")
          )
          vd_ord   <- droplevels(vd_ord)
          obs_lvls <- levels(vd_ord)
        }
        if (length(obs_lvls) < 2) {
          return(list(
            blocked = TRUE, reason = "CATEGORIAS_INSUFICIENTES",
            error   = paste0("'", var_b_name, "': menos de 2 categorias observadas."),
            details = list(ordered_levels = as.character(ordered_levels),
                            observed_levels = obs_lvls)
          ))
        }
      } else {
        return(list(
          blocked = TRUE, reason = "ORDEN_NO_DECLARADO",
          error   = paste0(
            "La variable dependiente '", var_b_name,
            "' no es numerica ni factor. Conviertala a factor ordenado ",
            "o proporcione ordered_levels."
          ),
          details = list(class = class(raw_b))
        ))
      }
    }

    # ─── Construir data.frame de predictores ────────────────────────────────
    pred_names <- make.names(c(
      var_a_name,
      if (!is.null(extra_predictors))
        sapply(extra_predictors, function(p) p$name)
      else character(0)
    ))
    pred_scores <- c(
      list(score_a),
      if (!is.null(extra_predictors))
        lapply(extra_predictors, function(p) p$score)
      else list()
    )
    datos <- data.frame(vd = vd_ord)
    for (i in seq_along(pred_names)) datos[[pred_names[i]]] <- pred_scores[[i]]
    datos <- datos[complete.cases(datos), ]
    n_complete <- nrow(datos)

    if (n_complete < 10) {
      return(list(
        blocked = TRUE, reason = "MUESTRA_INSUFICIENTE",
        error   = paste0(
          "Solo ", n_complete, " observaciones completas. ",
          "Se necesitan al menos 10 para la regresion ordinal."
        ),
        details = list(n_complete = n_complete)
      ))
    }

    # Predictor(es) constante(s)
    constant_preds <- pred_names[vapply(pred_names, function(p) {
      v <- datos[[p]]
      length(unique(na.omit(v))) < 2
    }, logical(1))]
    if (length(constant_preds) > 0) {
      return(list(
        blocked = TRUE, reason = "PREDICTOR_CONSTANTE",
        error   = paste0(
          "Predictor(es) constante(s) detectado(s): ",
          paste(constant_preds, collapse = ", "),
          ". La regresion ordinal no puede estimar coeficientes para predictores sin varianza."
        ),
        details = list(constant_predictors = constant_preds)
      ))
    }

    # ─── Ajustar modelo ─────────────────────────────────────────────────────
    formula_str <- paste("vd ~", paste(pred_names, collapse = " + "))
    polr_method <- switch(tolower(as.character(link_function)),
                           "probit"  = "probit",
                           "loglog"  = "loglog",
                           "cloglog" = "cloglog",
                           "logistic")

    warn_msgs <- character(0)
    modelo <- withCallingHandlers(
      polr(as.formula(formula_str), data = datos, Hess = TRUE, method = polr_method),
      warning = function(w) {
        warn_msgs <<- c(warn_msgs, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )

    converged <- isTRUE(modelo$convergence == 0)
    if (!converged) {
      warn_msgs <- c(warn_msgs,
        paste0("polr no convergio (convergence=", modelo$convergence, "). ",
               "Los resultados pueden ser inestables."))
    }

    modelo_nulo <- tryCatch(
      withCallingHandlers(
        polr(vd ~ 1, data = datos, Hess = TRUE, method = polr_method),
        warning = function(w) {
          warn_msgs <<- c(warn_msgs, paste0("Modelo nulo: ", conditionMessage(w)))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) NULL
    )

    # ─── Coeficientes, OR e IC ───────────────────────────────────────────────
    ctable <- coef(summary(modelo))
    p_vals  <- pnorm(abs(ctable[, "t value"]), lower.tail = FALSE) * 2
    ci      <- tryCatch(confint(modelo), error = function(e) NULL)
    or      <- exp(coef(modelo))

    if (!is.null(ci)) {
      if (is.null(dim(ci))) {
        or_ci <- matrix(exp(ci), nrow = 1,
                         dimnames = list(names(coef(modelo)), names(ci)))
      } else {
        or_ci <- exp(ci[names(coef(modelo)), , drop = FALSE])
      }
    } else {
      or_ci <- matrix(NA_real_, nrow = length(coef(modelo)), ncol = 2,
                       dimnames = list(names(coef(modelo)), c("2.5 %", "97.5 %")))
    }

    # Umbrales (thresholds / zetas del modelo)
    thresholds_vec <- modelo$zeta
    thresholds_lst <- lapply(names(thresholds_vec), function(nm) {
      list(threshold = nm, estimate = round(thresholds_vec[[nm]], 3))
    })

    # ─── Bondad de ajuste ────────────────────────────────────────────────────
    if (!is.null(modelo_nulo)) {
      ll_null   <- logLik(modelo_nulo)[1]
      ll_full   <- logLik(modelo)[1]
      k_pred    <- length(coef(modelo))
      lr_stat   <- -2 * (ll_null - ll_full)
      p_lr      <- pchisq(lr_stat, df = k_pred, lower.tail = FALSE)
      r2_cs     <- 1 - exp((2 / n_complete) * (ll_null - ll_full))
      r2_mcf    <- 1 - (ll_full / ll_null)
      r2_max    <- 1 - exp((2 / n_complete) * ll_null)
      r2_nag    <- r2_cs / r2_max
    } else {
      ll_null <- ll_full <- lr_stat <- p_lr <- r2_cs <- r2_mcf <- r2_nag <- NA
      k_pred  <- length(coef(modelo))
    }

    # ─── Test de lineas paralelas (Brant aproximado) ─────────────────────────
    parallel_test <- tryCatch({
      if (length(levels(datos$vd)) < 3) {
        list(z = NA, p = NA, ok = TRUE,
              interpretation = "Solo 2 categorias — test de lineas paralelas no aplicable")
      } else {
        lnk  <- if (polr_method == "probit") "probit" else "logit"
        bin1 <- as.integer(as.integer(datos$vd) <= 1)
        bin2 <- as.integer(as.integer(datos$vd) <= 2)
        datos$bin1 <- bin1
        datos$bin2 <- bin2
        bf1 <- paste("bin1 ~", paste(pred_names, collapse = " + "))
        bf2 <- paste("bin2 ~", paste(pred_names, collapse = " + "))
        m1  <- glm(as.formula(bf1), data = datos, family = binomial(link = lnk))
        m2  <- glm(as.formula(bf2), data = datos, family = binomial(link = lnk))
        ref <- pred_names[1]
        b1  <- coef(m1)[ref]; b2 <- coef(m2)[ref]
        s1  <- summary(m1)$coefficients[ref, "Std. Error"]
        s2  <- summary(m2)$coefficients[ref, "Std. Error"]
        z_d <- (b1 - b2) / sqrt(s1^2 + s2^2)
        p_d <- 2 * pnorm(abs(z_d), lower.tail = FALSE)
        list(z = round(z_d, 3), p = round(p_d, 4), ok = p_d >= 0.05,
              interpretation = if (p_d < 0.05)
                "Posible violacion del supuesto de lineas paralelas"
              else "Supuesto de lineas paralelas razonable")
      }
    }, error = function(e) {
      list(z = NA, p = NA, ok = TRUE, interpretation = "No calculado")
    })

    # ─── Lista de coeficientes ───────────────────────────────────────────────
    coefs <- lapply(names(coef(modelo)), function(nm) {
      list(
        term        = nm,
        B           = round(coef(modelo)[nm], 3),
        OR          = round(or[nm], 3),
        ci_lower    = round(or_ci[nm, 1], 3),
        ci_upper    = round(or_ci[nm, 2], 3),
        t           = round(ctable[nm, "t value"], 3),
        p           = round(p_vals[nm], 4),
        p_apa       = if (p_vals[nm] < .001) "< .001"
                      else paste0("= ", round(p_vals[nm], 3)),
        significant = p_vals[nm] < alpha
      )
    })

    dist_table <- as.data.frame(table(datos$vd))
    colnames(dist_table) <- c("Nivel", "n")
    dist_table$pct <- round(dist_table$n / sum(dist_table$n) * 100, 1)

    list(
      n                    = n_complete,
      var_a                = var_a_name,
      var_b                = var_b_name,
      link_function_used   = polr_method,
      ordered_levels_used  = levels(datos$vd),
      lr_chi2              = round(lr_stat, 3),
      lr_df                = k_pred,
      lr_p                 = round(p_lr, 4),
      r2_cox_snell         = round(r2_cs, 3),
      r2_mcfadden          = round(r2_mcf, 3),
      nagelkerke_r2        = round(r2_nag, 3),
      pseudo_r2_requested  = pseudo_r2_type,
      aic                  = round(AIC(modelo), 3),
      converged            = converged,
      warnings             = if (length(warn_msgs) > 0) as.list(warn_msgs) else list(),
      empty_levels_warning = warn_empty,
      parallel_lines_test  = parallel_test,
      thresholds           = thresholds_lst,
      coefficients         = coefs,
      distribution         = lapply(seq_len(nrow(dist_table)), function(i) list(
        Nivel = as.character(dist_table$Nivel[i]),
        n     = dist_table$n[i],
        pct   = dist_table$pct[i]
      )),
      significant = any(p_vals[names(coef(modelo))] < alpha),
      decision    = if (any(p_vals[names(coef(modelo))] < alpha))
                     paste0("El predictor tiene efecto significativo sobre ",
                            var_b_name, " ordinal (p < ", alpha, ")")
                   else
                     paste0("El predictor no tiene efecto significativo sobre ",
                            var_b_name, " ordinal")
    )

  }, error = function(e) {
    list(
      blocked = TRUE,
      reason  = "ERROR_INTERNO",
      error   = e$message,
      details = list()
    )
  })
}
