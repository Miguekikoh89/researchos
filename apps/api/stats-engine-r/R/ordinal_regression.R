# ResearchOS — Regresion Ordinal (Lote 1G)
# VD ordinal debe ser declarada explicitamente (ordered factor o ordered_levels).
# Etapas instrumentadas individualmente para diagnostico de fallos.
# VD con exactamente 2 categorias observadas → VD_BINARIA (usar logistica binaria).
options(encoding = "UTF-8")

run_ordinal_regression <- function(df, var_a_items, var_b_items, var_a_name, var_b_name,
                                    alpha = 0.05, link_function = "logit",
                                    ordinalizacion = NULL,   # obsoleto — ignorado
                                    pseudo_r2_type = "nagelkerke",
                                    extra_predictors = NULL,
                                    ordered_levels = NULL) {
  current_stage <- "init"

  if (!is.null(ordinalizacion)) {
    warning(
      "El parametro 'ordinalizacion' esta obsoleto y es ignorado. ",
      "La variable dependiente ordinal debe declararse como ordered factor ",
      "o mediante el parametro ordered_levels.",
      call. = FALSE
    )
  }

  tryCatch({
    if (!requireNamespace("MASS", quietly = TRUE))
      stop("El paquete 'MASS' es necesario para la regresion ordinal.")

    # ─── Etapa: preparacion de datos ────────────────────────────────────────
    current_stage <- "data_prep"
    var_a_items <- as.character(unlist(var_a_items)); var_b_items <- as.character(unlist(var_b_items))
    if(!all(c(var_a_items,var_b_items)%in%names(df)))stop("Variables/ítems no encontrados.")
    a_mat <- as.data.frame(lapply(df[,var_a_items,drop=FALSE],function(x)suppressWarnings(as.numeric(x))))
    a_valid <- rowSums(!is.na(a_mat)); score_a <- rowMeans(a_mat,na.rm=TRUE)
    score_a[a_valid < ceiling(length(var_a_items)*.80)] <- NA_real_; score_a[!is.finite(score_a)] <- NA_real_
    # Variable B: promediar items si hay multiples (estandar para escalas Likert)
    if(length(var_b_items) == 1) {
      raw_b <- suppressWarnings(as.numeric(df[[var_b_items[1]]]))
    } else {
      b_mat <- as.data.frame(lapply(df[,var_b_items,drop=FALSE],function(x)suppressWarnings(as.numeric(x))))
      raw_b <- rowMeans(b_mat, na.rm=TRUE)
      raw_b[!is.finite(raw_b)] <- NA_real_
      # Con multiples items, la VD se construye por baremos teoricos.
      # ordered_levels del usuario no aplica (se ignora).
      ordered_levels <- NULL
    }

    # ─── Etapa: validacion de ordered_levels declarados (F-024b) ────────────
    # Duplicados -> ORDEN_INVALIDO. Categorias observadas fuera de la lista
    # declarada -> ORDEN_INCOMPLETO (antes se convertian silenciosamente en NA
    # y se perdian filas sin aviso).
    current_stage <- "ordered_levels_validation"
    if (!is.null(ordered_levels) && length(ordered_levels) > 0) {
      ord_chr <- as.character(unlist(ordered_levels))
      dups <- unique(ord_chr[duplicated(ord_chr)])
      if (length(dups) > 0) {
        return(list(
          blocked = TRUE, reason = "ORDEN_INVALIDO", stage = current_stage,
          error   = paste0(
            "ordered_levels contiene niveles duplicados: ",
            paste(dups, collapse = ", "),
            ". Cada categoria debe declararse exactamente una vez."
          ),
          details = list(ordered_levels = ord_chr)
        ))
      }
      obs_vals <- unique(as.character(raw_b[!is.na(raw_b)]))
      no_declarados <- setdiff(obs_vals, ord_chr)
      if (length(no_declarados) > 0) {
        return(list(
          blocked = TRUE, reason = "ORDEN_INCOMPLETO", stage = current_stage,
          error   = paste0(
            "Categorias observadas en '", var_b_name,
            "' que no figuran en ordered_levels: ",
            paste(no_declarados, collapse = ", "),
            ". Declare TODAS las categorias observadas en su orden correcto."
          ),
          details = list(ordered_levels = ord_chr, observed_levels = obs_vals)
        ))
      }
    }

    # ─── Etapa: clasificacion y construccion de VD ordinal ──────────────────
    current_stage <- "vd_classification"
    vd_ord     <- NULL
    warn_empty <- NULL

    if (is.ordered(raw_b)) {
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
          stage   = current_stage,
          error   = paste0(
            "La variable dependiente '", var_b_name, "' tiene solo ",
            length(obs_lvls), " categoria observada tras eliminar niveles vacios. ",
            "Se necesitan al menos 2 categorias con observaciones."
          ),
          details = list(observed_levels = obs_lvls, empty_levels = empty_lvls)
        ))
      }
      if (length(obs_lvls) == 2) {
        return(list(
          blocked = TRUE, reason = "VD_BINARIA",
          stage   = current_stage,
          error   = paste(
            "La variable dependiente conserva solamente dos categorias observadas.",
            "Utilice regresion logistica binaria."
          ),
          details = list(
            observed_levels = obs_lvls,
            empty_levels    = if (length(empty_lvls) > 0) empty_lvls else character(0)
          )
        ))
      }
      vd_ord <- droplevels(raw_b)

    } else if (is.factor(raw_b)) {
      if (is.null(ordered_levels)) {
        return(list(
          blocked = TRUE, reason = "ORDEN_NO_DECLARADO",
          stage   = current_stage,
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
        vd_ord   <- droplevels(vd_ord)
        obs_lvls <- levels(vd_ord)
      }
      if (length(obs_lvls) < 2) {
        return(list(
          blocked = TRUE, reason = "CATEGORIAS_INSUFICIENTES",
          stage   = current_stage,
          error   = paste0(
            "La variable dependiente '", var_b_name, "' tiene menos de 2 niveles ",
            "observados entre los declarados en ordered_levels."
          ),
          details = list(ordered_levels = ordered_chars, observed_levels = obs_lvls)
        ))
      }
      if (length(obs_lvls) == 2) {
        return(list(
          blocked = TRUE, reason = "VD_BINARIA",
          stage   = current_stage,
          error   = paste(
            "La variable dependiente conserva solamente dos categorias observadas.",
            "Utilice regresion logistica binaria."
          ),
          details = list(
            observed_levels = obs_lvls,
            empty_levels    = if (length(empty_lvls) > 0) empty_lvls else character(0)
          )
        ))
      }

    } else if (is.numeric(raw_b) || is.integer(raw_b)) {
      raw_b_clean <- na.omit(raw_b)
      n_unique    <- length(unique(raw_b_clean))
      is_decimal  <- any(abs(raw_b_clean - round(raw_b_clean)) > 1e-10)

      if (n_unique > 10 || is_decimal) {
        # Ordinalizacion automatica para puntajes continuos de escala Likert.
        # Baremos teoricos predeterminados (rangos iguales en escala 1-5):
        # Bajo: 1.00-2.33, Medio: 2.34-3.67, Alto: 3.68-5.00
        ord_method <- tolower(as.character(ordinalizacion %||% "teorico"))
        cuts <- switch(ord_method,
          "percentil" = quantile(raw_b, probs = c(0.25, 0.75), na.rm = TRUE),
          "terciles"  = quantile(raw_b, probs = c(1/3, 2/3),   na.rm = TRUE),
          "tercil"    = quantile(raw_b, probs = c(1/3, 2/3),   na.rm = TRUE),
          c(1 + (5-1)/3, 1 + 2*(5-1)/3)
        )
        vd_ord <- cut(raw_b, breaks = c(-Inf, cuts, Inf),
                      labels = c("Bajo", "Medio", "Alto"), ordered_result = TRUE)
        ord_label <- switch(ord_method,
          "percentil" = "percentiles P25/P75",
          "terciles"  = "terciles P33/P67",
          "tercil"    = "terciles P33/P67",
          "baremos teoricos (cortes 2.33 y 3.67 en escala 1-5)"
        )
        warn_empty <- paste0(
          "La VD '", var_b_name, "' fue categorizada mediante ", ord_label,
          ". Verifique coherencia con su marco teorico."
        )
      }
      if (n_unique < 2) {
        return(list(
          blocked = TRUE, reason = "CATEGORIAS_INSUFICIENTES",
          stage   = current_stage,
          error   = paste0(
            "La variable dependiente '", var_b_name, "' tiene ", n_unique,
            " categoria observada. Se necesitan al menos 2."
          ),
          details = list(n_unique = n_unique, observed = sort(unique(raw_b_clean)))
        ))
      }
      if (is.null(vd_ord) && is.null(ordered_levels)) {
        return(list(
          blocked = TRUE, reason = "ORDEN_NO_DECLARADO",
          stage   = current_stage,
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
      if (is.null(vd_ord)) vd_ord <- ordered(raw_b, levels = ordered_levels)
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
          stage   = current_stage,
          error   = paste0(
            "La variable dependiente '", var_b_name,
            "' tiene menos de 2 categorias observadas con los niveles declarados."
          ),
          details = list(ordered_levels  = as.character(ordered_levels),
                          observed_levels = obs_lvls)
        ))
      }
      if (length(obs_lvls) == 2) {
        return(list(
          blocked = TRUE, reason = "VD_BINARIA",
          stage   = current_stage,
          error   = paste(
            "La variable dependiente conserva solamente dos categorias observadas.",
            "Utilice regresion logistica binaria."
          ),
          details = list(
            observed_levels = obs_lvls,
            empty_levels    = if (length(empty_lvls) > 0) empty_lvls else character(0)
          )
        ))
      }

    } else {
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
            stage   = current_stage,
            error   = paste0("'", var_b_name, "': menos de 2 categorias observadas."),
            details = list(ordered_levels  = as.character(ordered_levels),
                            observed_levels = obs_lvls)
          ))
        }
        if (length(obs_lvls) == 2) {
          return(list(
            blocked = TRUE, reason = "VD_BINARIA",
            stage   = current_stage,
            error   = paste(
              "La variable dependiente conserva solamente dos categorias observadas.",
              "Utilice regresion logistica binaria."
            ),
            details = list(
              observed_levels = obs_lvls,
              empty_levels    = if (length(empty_lvls) > 0) empty_lvls else character(0)
            )
          ))
        }
      } else {
        return(list(
          blocked = TRUE, reason = "ORDEN_NO_DECLARADO",
          stage   = current_stage,
          error   = paste0(
            "La variable dependiente '", var_b_name,
            "' no es numerica ni factor. Conviertala a factor ordenado ",
            "o proporcione ordered_levels."
          ),
          details = list(class = class(raw_b))
        ))
      }
    }

    # ─── Etapa: preparacion de predictores ──────────────────────────────────
    current_stage <- "predictor_prep"
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
        stage   = current_stage,
        error   = paste0(
          "Solo ", n_complete, " observaciones completas. ",
          "Se necesitan al menos 10 para la regresion ordinal."
        ),
        details = list(n_complete = n_complete)
      ))
    }

    constant_preds <- pred_names[vapply(pred_names, function(p) {
      v <- datos[[p]]
      length(unique(na.omit(v))) < 2
    }, logical(1))]
    if (length(constant_preds) > 0) {
      return(list(
        blocked = TRUE, reason = "PREDICTOR_CONSTANTE",
        stage   = current_stage,
        error   = paste0(
          "Predictor(es) constante(s) detectado(s): ",
          paste(constant_preds, collapse = ", "),
          ". La regresion ordinal no puede estimar coeficientes para predictores sin varianza."
        ),
        details = list(constant_predictors = constant_preds)
      ))
    }

    # ─── Etapa: ajuste del modelo polr ──────────────────────────────────────
    current_stage <- "polr_fit"
    formula_str <- paste("vd ~", paste(pred_names, collapse = " + "))
    polr_method <- switch(tolower(as.character(link_function)),
                           "probit"  = "probit",
                           "loglog"  = "loglog",
                           "cloglog" = "cloglog",
                           "logistic")

    warn_msgs <- character(0)
    modelo <- withCallingHandlers(
      MASS::polr(as.formula(formula_str), data = datos, Hess = TRUE, method = polr_method),
      warning = function(w) {
        warn_msgs <<- c(warn_msgs, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )

    converged <- isTRUE(modelo$convergence == 0)
    if (!converged) {
      return(list(blocked=TRUE, reason="NO_CONVERGENCIA", stage="polr_fit",
                  error=paste0("polr no convergió (convergence=", modelo$convergence, ").")))
    }

    # ─── Etapa: vcov y estadisticos de resumen ──────────────────────────────
    current_stage <- "vcov"
    ctable   <- coef(summary(modelo))
    vcov_mat <- vcov(modelo)
    p_vals   <- pnorm(abs(ctable[, "t value"]), lower.tail = FALSE) * 2
    or       <- exp(coef(modelo))
    se_coefs <- ctable[names(coef(modelo)), "Std. Error"]

    thresholds_vec <- modelo$zeta

    # ─── Etapa: IC perfil (con fallback Wald) ───────────────────────────────
    current_stage <- "profile_confint"
    ci_method <- "profile_likelihood"
    ci_err    <- NULL
    ci        <- NULL

    ci <- withCallingHandlers(
      tryCatch(
        confint(modelo),
        error = function(e) { ci_err <<- conditionMessage(e); NULL }
      ),
      warning = function(w) {
        warn_msgs <<- c(warn_msgs, paste0("confint: ", conditionMessage(w)))
        invokeRestart("muffleWarning")
      }
    )

    if (is.null(ci)) {
      current_stage <- "wald_confint"
      ci_method     <- "wald"
      coef_names    <- names(coef(modelo))
      z_alpha       <- qnorm(1 - alpha / 2)
      ci_wald       <- matrix(NA_real_, nrow = length(coef_names), ncol = 2,
                               dimnames = list(coef_names, c("2.5 %", "97.5 %")))
      for (nm in coef_names) {
        if (nm %in% rownames(vcov_mat) && nm %in% colnames(vcov_mat)) {
          se_nm          <- sqrt(vcov_mat[nm, nm])
          ci_wald[nm, 1] <- coef(modelo)[nm] - z_alpha * se_nm
          ci_wald[nm, 2] <- coef(modelo)[nm] + z_alpha * se_nm
        }
      }
      ci <- ci_wald
      if (!is.null(ci_err)) {
        warn_msgs <- c(warn_msgs,
          paste0("confint (perfil) fallo; se usaron IC de Wald: ", ci_err))
      }
    }

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

    # ─── Etapa: modelo nulo ─────────────────────────────────────────────────
    current_stage <- "null_model"
    modelo_nulo <- tryCatch(
      withCallingHandlers(
        MASS::polr(vd ~ 1, data = datos, Hess = TRUE, method = polr_method),
        warning = function(w) {
          warn_msgs <<- c(warn_msgs, paste0("Modelo nulo: ", conditionMessage(w)))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) NULL
    )

    # ─── Etapa: pseudo R² ───────────────────────────────────────────────────
    current_stage <- "pseudo_r2"
    if (!is.null(modelo_nulo)) {
      ll_null   <- as.numeric(logLik(modelo_nulo)[1])
      ll_full   <- as.numeric(logLik(modelo)[1])
      k_pred    <- length(coef(modelo))
      lr_stat   <- -2 * (ll_null - ll_full)
      p_lr      <- pchisq(lr_stat, df = k_pred, lower.tail = FALSE)
      r2_cs     <- 1 - exp((2 / n_complete) * (ll_null - ll_full))
      r2_mcf    <- 1 - (ll_full / ll_null)
      r2_max    <- 1 - exp((2 / n_complete) * ll_null)
      r2_nag    <- r2_cs / r2_max
    } else {
      ll_null <- NA_real_; ll_full <- as.numeric(logLik(modelo)[1])
      lr_stat <- NA_real_; p_lr    <- NA_real_
      r2_cs   <- NA_real_; r2_mcf  <- NA_real_; r2_nag <- NA_real_
      k_pred  <- length(coef(modelo))
    }

    # ─── Etapa: test de lineas paralelas ────────────────────────────────────
    current_stage <- "parallel_test"
    parallel_test <- tryCatch({
      if (!requireNamespace("ordinal", quietly=TRUE)) {
        list(calculated=FALSE, p=NA_real_, ok=NA,
             method="No disponible: requiere paquete ordinal",
             interpretation="No se afirmó el supuesto de líneas paralelas.")
      } else {
        clm_fit <- ordinal::clm(as.formula(formula_str), data=datos, link=if(polr_method=="logistic")"logit"else polr_method)
        nt <- as.data.frame(ordinal::nominal_test(clm_fit))
        p_col <- grep("Pr(>Chi)", names(nt), value=TRUE, fixed=TRUE)[1]
        if(is.na(p_col)||is.null(p_col))stop("nominal_test no devolvió valores p.")
        rn <- rownames(nt); p_all <- suppressWarnings(as.numeric(nt[[p_col]]))
        keep <- is.finite(p_all); terms <- lapply(which(keep),function(i)list(term=rn[i],p=as.numeric(p_all[i]),violates=p_all[i]<alpha))
        if(!length(terms))stop("nominal_test no devolvió términos evaluables.")
        any_violation <- any(vapply(terms,function(x)isTRUE(x$violates),logical(1)))
        list(calculated=TRUE,p=NA_real_,ok=!any_violation,terms=terms,
             method="ordinal::nominal_test por término (no se reporta el mínimo como prueba global)",
             interpretation=if(any_violation)"Al menos un predictor muestra evidencia contra odds proporcionales"else"No se detectó evidencia contra odds proporcionales en los términos evaluados")
      }
    }, error=function(e) list(calculated=FALSE,p=NA_real_,ok=NA,method="No calculado",
                              interpretation="No se afirmó el supuesto de líneas paralelas.",error=conditionMessage(e)))

    # ─── Etapa: serializacion del resultado ─────────────────────────────────
    current_stage <- "serialization"
    thresholds_lst <- lapply(names(thresholds_vec), function(nm) {
      list(threshold = nm, estimate = round(thresholds_vec[[nm]], 3))
    })

    coefs <- lapply(names(coef(modelo)), function(nm) {
      list(
        term        = nm,
        B           = round(coef(modelo)[nm], 3),
        OR          = round(or[nm], 3),
        ci_lower    = round(or_ci[nm, 1], 3),
        ci_upper    = round(or_ci[nm, 2], 3),
        t           = round(ctable[nm, "t value"], 3),
        p           = as.numeric(p_vals[nm]),
        p_apa       = if (p_vals[nm] < .001) "< .001"
                      else paste0("= ", formatC(p_vals[nm],digits=3,format="f")),
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
      lr_p                 = as.numeric(p_lr),
      r2_cox_snell         = round(r2_cs, 3),
      r2_mcfadden          = round(r2_mcf, 3),
      nagelkerke_r2        = round(r2_nag, 3),
      pseudo_r2_requested  = pseudo_r2_type,
      aic                  = round(AIC(modelo), 3),
      converged            = converged,
      ci_method            = ci_method,
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
      significant = is.finite(p_lr) && p_lr < alpha,
      any_predictor_significant = any(p_vals[names(coef(modelo))] < alpha),
      decision    = if (is.finite(p_lr) && p_lr < alpha)
                     paste0("El modelo ordinal global es significativo para ",var_b_name," (prueba LR).")
                   else
                     paste0("El modelo ordinal global no es significativo para ",var_b_name," (prueba LR)."),
      raw_values = list(
        coefficients_B = coef(modelo),
        thresholds     = thresholds_vec,
        logLik         = ll_full,
        logLik_null    = ll_null,
        AIC_val        = AIC(modelo),
        std_errors     = se_coefs
      )
    )

  }, error = function(e) {
    list(
      blocked = TRUE,
      reason  = "ERROR_INTERNO",
      error   = conditionMessage(e),
      stage   = current_stage,
      details = list()
    )
  })
}
