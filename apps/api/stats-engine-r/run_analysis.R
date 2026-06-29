#!/usr/bin/env Rscript
# IMPORTANTE: forzar locale "C" rompia el manejo de UTF-8 (tildes, enie) en todo
# el pipeline, corrompiendo el texto leido del Excel y, en consecuencia, el Word
# exportado ("Premature end of data in tag t" por bytes UTF-8 truncados). Se usa
# un locale UTF-8 real, e invisible() evita que el valor de retorno (un string)
# se autoimprima en stdout y contamine el JSON de salida.
invisible(suppressWarnings(Sys.setlocale("LC_ALL", "en_US.utf8")))
# ============================================================================
# ResearchOS Stats Engine — run_analysis.R
# Script principal: recibe JSON config → ejecuta análisis → devuelve JSON
#
# Uso desde NestJS:
#   Rscript run_analysis.R <config_json_path> <output_dir>
#
# Entrada (config JSON):
# {
#   "file_path": "/tmp/uploads/abc123.xlsx",
#   "sheet": 1,
#   "has_header": true,
#   "imputation": "media",           // "none" | "media" | "mediana"
#   "var_a": {
#     "name": "Gestión del conocimiento",
#     "items": ["GC1","GC2","GC3"],
#     "dimensions": [
#       { "name": "Dimensión 1", "items": ["GC1","GC2"] },
#       { "name": "Dimensión 2", "items": ["GC3"] }
#     ]
#   },
#   "var_b": {
#     "name": "Desempeño docente",
#     "items": ["DD1","DD2","DD3"],
#     "dimensions": []
#   },
#   "scale": { "min": 1, "max": 5 },
#   "baremo_method": "percentil",     // "teorico" | "percentil" | "tercil" | "custom_cut"
#   "baremo_levels": ["Bajo","Medio","Alto"],
#   "normality_tests": ["sw","ks"],
#   "method_force": "auto",           // "auto" | "pearson" | "spearman"
#   "analysis_types": ["vv","vdB"],   // "vv","vdA","vdB","dd"
#   "alpha": 0.05,
#   "participants": "los docentes evaluados",
#   "study_title": "Gestión del conocimiento y desempeño docente",
#   "objective": "Determinar la relación entre...",
#   "include_reliability": true,
#   "export_word": true,
#   "table_start": 1
# }
#
# Salida JSON:
# {
#   "status": "ok",
#   "method": "spearman",
#   "diagnostic": {...},
#   "descriptives": [...],
#   "reliability": [...],
#   "baremo_a": {...},
#   "baremo_b": {...},
#   "normality": [...],
#   "correlations": [...],
#   "interpretations": {...},
#   "word_path": "/tmp/output/ResultadosAPA.docx",
#   "warnings": [...],
#   "errors": []
# }
# ============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
})

# ── Rutas de scripts modulares ───────────────────────────────────────────────
script_dir <- "/app/stats-engine-r/R"
if (is.null(script_dir) || script_dir == "") {
  script_dir <- getwd()
}

r_dir <- script_dir
source(file.path(r_dir, "helpers.R"))
source(file.path(r_dir, "data_cleaning.R"))
source(file.path(r_dir, "statistics.R"))
source(file.path(r_dir, "word_export.R"))
source(file.path(r_dir, "t_test.R"))
source(file.path(r_dir, "anova.R"))
source(file.path(r_dir, "regression.R"))
source(file.path(r_dir, "logistic.R"))
source(file.path(r_dir, "logistic_multinomial.R"))
source(file.path(r_dir, "chi_square.R"))
source(file.path(r_dir, "instruments.R"))
source(file.path(r_dir, "ordinal_regression.R"))
source(file.path(r_dir, "hierarchical_regression.R"))
source(file.path(r_dir, "ancova.R"))
source(file.path(r_dir, "discriminant.R"))
source(file.path(r_dir, "frequencies.R"))
source(file.path(r_dir, "cluster.R"))
source(file.path(r_dir, "cronbach_only.R"))
source(file.path(r_dir, "mediation.R"))
source(file.path(r_dir, "baremos_only.R"))
source(file.path(r_dir, "descriptives_full.R"))
source(file.path(r_dir, "analisis_descriptivo.R"))

# ── Captura de argumentos ────────────────────────────────────────────────────
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  cat(toJSON(list(
    status = "error",
    errors = list("Uso: Rscript run_analysis.R <config_json_path> <output_dir>")
  ), auto_unbox = TRUE))
  quit(status = 1)
}

config_path <- args[1]
output_dir  <- args[2]

# ── Leer configuración ───────────────────────────────────────────────────────
config <- tryCatch(
  fromJSON(config_path, simplifyVector = FALSE),
  error = function(e) {
    cat(toJSON(list(status = "error",
                    errors = list(paste0("No se pudo leer la configuración: ", e$message))),
               auto_unbox = TRUE))
    quit(status = 1)
  }
)

# ── Función principal ────────────────────────────────────────────────────────
run_full_analysis <- function(config, output_dir) {
  result  <- list(status = "ok", warnings = list(), errors = list())
  result$objective <- as.character(config$objective %||% "")
  result$hypothesis_h1 <- as.character(config$hypothesis_h1 %||% "")
  all_warnings <- character(0)

  tryCatch({

    # 1. CARGAR Y LIMPIAR DATOS ──────────────────────────────────────────────
    raw_df <- load_file(
      filepath = config$file_path,
      sheet    = config$sheet %||% 1,
      header   = isTRUE(config$has_header %||% TRUE)
    )
    raw_df <- clean_data(raw_df)

    if (!is.null(config$imputation) && config$imputation != "none") {
      raw_df <- impute_data(raw_df, config$imputation)
    }

    # 2. DIAGNÓSTICO ─────────────────────────────────────────────────────────
    diag <- diagnose_data(raw_df)
    result$diagnostic <- list(
      n_rows       = diag$n_rows,
      n_cols       = diag$n_cols,
      numeric_cols = diag$numeric_cols,
      text_cols    = diag$text_cols,
      missing_pct  = diag$missing_pct,
      warnings     = diag$warnings,
      col_summary  = lapply(diag$col_diagnose, function(c) {
        list(name = c$name, type = c$type,
             missing = c$missing, unique = c$unique, apt = c$apt)
      })
    )
    all_warnings <- c(all_warnings, diag$warnings)

    # 3. CALCULAR PUNTAJES ───────────────────────────────────────────────────
    scores_result <- compute_scores(raw_df, config)
    scores    <- scores_result$scores
    items_map <- scores_result$items_map

    if (ncol(scores) == 0) stop("No se pudieron calcular puntajes. Verifica la configuración de ítems.")

    # 4. DESCRIPTIVOS ────────────────────────────────────────────────────────
    desc <- compute_descriptives(scores)
    result$descriptives <- lapply(seq_len(nrow(desc)), function(i) {
      as.list(desc[i, ])
    })

    # 5. CONFIABILIDAD ───────────────────────────────────────────────────────
    reliability <- compute_reliability(raw_df, items_map)
    result$reliability <- lapply(reliability, function(r) {
      list(
        name            = r$name,
        alpha           = r$alpha,
        alpha_std       = r$alpha_std,
        ci_lower        = r$ci_lower,
        ci_upper        = r$ci_upper,
        k               = r$k,
        n               = r$n,
        interpretation  = interpret_alpha(r$alpha),
        inter_item_mean = r$inter_item_mean,
        omega           = r$omega,
        item_stats      = r$item_stats
      )
    })
    for (r in reliability) {
      if (!is.na(r$alpha) && r$alpha < 0.70) {
        all_warnings <- c(all_warnings,
          paste0("Alfa de Cronbach bajo para ", r$name, " (α = ", r$alpha,
                 "). Revisar la escala antes de continuar."))
      }
    }

    # 6. BAREMOS ─────────────────────────────────────────────────────────────
    # as.character()/fallback necesarios: regresion_jerarquica no envia
    # config$var_a en absoluto (usa hier_blocks en su lugar), por lo que
    # config$var_a$name es NULL aqui, y un NULL sin convertir rompia el
    # chequeo 'var_a_name %in% names(scores)' mas abajo con "argument is
    # of length zero".
    var_a_name <- as.character(config$var_a$name %||% "")
    var_b_name <- as.character(config$var_b$name %||% "")
    scale_range <- c(
      config$scale$min %||% 1,
      config$scale$max %||% 5
    )
    baremo_levels <- if (!is.null(config$baremo_levels) && length(config$baremo_levels) == 3)
      unlist(config$baremo_levels)
    else
      c("Bajo", "Medio", "Alto")
    baremo_method <- config$baremo_method %||% "percentil"

    baremo_a <- NULL
    if (var_a_name %in% names(scores)) {
      baremo_a <- tryCatch(
        compute_baremo(scores[[var_a_name]], var_a_name,
                       method = baremo_method, scale = scale_range,
                       levels = baremo_levels),
        error = function(e) {
          all_warnings <<- c(all_warnings, paste0("No se pudo calcular baremo de ", var_a_name, ": ", e$message))
          NULL
        }
      )
    }

    baremo_b <- NULL
    if (var_b_name %in% names(scores)) {
      baremo_b <- tryCatch(
        compute_baremo(scores[[var_b_name]], var_b_name,
                       method = baremo_method, scale = scale_range,
                       levels = baremo_levels),
        error = function(e) {
          all_warnings <<- c(all_warnings, paste0("No se pudo calcular baremo de ", var_b_name, ": ", e$message))
          NULL
        }
      )
    }

    # Convertir baremos a formato JSON-friendly
    baremo_to_json <- function(br) {
      if (is.null(br)) return(NULL)
      list(
        variable    = br$variable,
        method      = br$method,
        n           = br$n,
        levels      = br$levels,
        table       = lapply(seq_len(nrow(br$table)), function(i) as.list(br$table[i,])),
        frequencies = lapply(seq_len(nrow(br$frequencies)), function(i) as.list(br$frequencies[i,])),
        interpretation = redact_baremo(br),
        levels_text    = redact_levels(br, config$participants %||% "los participantes")
      )
    }
    result$baremo_a <- baremo_to_json(baremo_a)
    result$baremo_b <- baremo_to_json(baremo_b)

    # 7. NORMALIDAD ──────────────────────────────────────────────────────────
    norm_tests  <- unlist(config$normality_tests %||% list("sw", "ks"))
    norm_alpha  <- config$alpha %||% 0.05
    norm_res    <- compute_normality(scores, alpha = norm_alpha, tests = norm_tests)
    result$normality <- lapply(seq_len(nrow(norm_res)), function(i) {
      row <- as.list(norm_res[i,])
      row$interpretation <- if (row$decision == "Normal")
        "La variable presenta distribución normal."
      else
        "La variable no presenta distribución normal."
      row
    })

    # 8. MÉTODO DE CORRELACIÓN ───────────────────────────────────────────────
    method <- decide_method(norm_res, config$method_force %||% "auto", x = scores[[var_a_name]], y = scores[[var_b_name]])
    result$method <- method
    result$method_reason <- redact_normality(norm_res, norm_alpha)

    # 9. CORRELACIONES ───────────────────────────────────────────────────────

  # ── Comparacion de grupos ───────────────────────────────────────────────
  analysis_category <- as.character(config$analysis_category %||% "correlacional")
  if (analysis_category == "anova") {
    group_var  <- as.character(config$group_var %||% "")
    var_a_name <- as.character(config$var_a$name); if(var_a_name==""||is.null(var_a_name)) var_a_name <- "Variable A"
    y          <- scores_result$scores[[var_a_name]]
    if (group_var != "" && group_var %in% names(raw_df)) {
      grupos <- as.character(unlist(raw_df[[group_var]]))
    } else {
      result$status  <- "error"
      result$stage   <- "anova_routing"
      result$reason  <- "SIN_VARIABLE_GRUPO"
      result$error   <- "La variable de agrupacion (group_var) es requerida para ANOVA y no fue proporcionada o no se encuentra en los datos."
      result$blocked <- TRUE
      result$warnings <- as.list(all_warnings)
      return(result)
    }
    anova_result <- tryCatch(
      compute_anova(y, grupos, alpha=norm_alpha,
        posthoc=as.character(config$posthoc %||% "tukey"),
        effect_size=as.character(config$effect_size %||% "eta2"),
        levene=as.character(config$levene_test %||% "yes")),
      error=function(e) list(error=e$message)
    )
    result$anova    <- anova_result
    result$status   <- "ok"
    result$warnings <- as.list(all_warnings)
    if (isTRUE(config$export_word)) {
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      word_filename <- paste0("ResultadosAPA_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx")
      word_path     <- file.path(output_dir, word_filename)

      # Separar correlaciones generales vs dimensionales
      corr_general <- NULL
      corr_dims    <- NULL
      if (!is.null(NULL) && nrow(NULL) > 0) {
        mask_gral  <- NULL$var_a == var_a_name & NULL$var_b == var_b_name
        if (sum(mask_gral) > 0)  corr_general <- NULL[mask_gral, , drop = FALSE]
        if (sum(!mask_gral) > 0) corr_dims    <- NULL[!mask_gral, , drop = FALSE]
      }
      tryCatch({
        doc <- generate_word(
          result     = result,
          config     = config,
          output_dir = output_dir,
          tbl_start  = as.numeric(config$table_start %||% 1)
        )





        word_file <- save_word(doc, output_dir, job_id=NULL)
        result$word_path <- word_file
      }, error = function(e) {
        all_warnings <<- c(all_warnings,
          paste0("No se pudo generar el Word: ", e$message))
        result$word_path <<- NULL
      })
    }
    return(result)
  }
  if (analysis_category == "regresion") {
    var_a_name <- as.character(config$var_a$name); if(var_a_name==""||is.null(var_a_name)) var_a_name <- "Variable A"
    var_b_name <- as.character(config$var_b$name)
    y  <- scores_result$scores[[var_b_name]]
    predictors <- config$regression_predictors
    if (is.null(predictors) || length(predictors)==0) {
      X <- scores_result$scores[[var_a_name]]
      X <- as.data.frame(X); colnames(X) <- var_a_name
      var_names <- var_a_name
    } else {
      X <- as.data.frame(scores_result$scores[as.character(unlist(predictors))])
      var_names <- as.character(unlist(predictors))
    }
    reg_result <- tryCatch(
      compute_regression(y, X, var_names=var_names, alpha=norm_alpha,
        method=as.character(config$regression_method %||% "enter"),
        check_assumptions=as.character(config$check_assumptions %||% "yes"),
        vif_threshold=as.numeric(config$vif_threshold %||% 5),
        coef_ci=as.numeric(config$coef_ci %||% 0.95),
        handle_outliers=as.character(config$handle_outliers %||% "report")),
      error=function(e) list(error=e$message)
    )
    result$regression <- reg_result
    result$status     <- "ok"
    result$warnings   <- as.list(all_warnings)
    if (isTRUE(config$export_word)) {
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      word_filename <- paste0("ResultadosAPA_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx")
      word_path     <- file.path(output_dir, word_filename)

      # Separar correlaciones generales vs dimensionales
      corr_general <- NULL
      corr_dims    <- NULL
      if (!is.null(NULL) && nrow(NULL) > 0) {
        mask_gral  <- NULL$var_a == var_a_name & NULL$var_b == var_b_name
        if (sum(mask_gral) > 0)  corr_general <- NULL[mask_gral, , drop = FALSE]
        if (sum(!mask_gral) > 0) corr_dims    <- NULL[!mask_gral, , drop = FALSE]
      }
      tryCatch({
        doc <- generate_word(
          result     = result,
          config     = config,
          output_dir = output_dir,
          tbl_start  = as.numeric(config$table_start %||% 1)
        )





        word_file <- save_word(doc, output_dir, job_id=NULL)
        result$word_path <- word_file
      }, error = function(e) {
        all_warnings <<- c(all_warnings,
          paste0("No se pudo generar el Word: ", e$message))
        result$word_path <<- NULL
      })
    }
    return(result)
  }

  if (analysis_category == "logistica") {
    var_a_name   <- as.character(config$var_a$name)
    var_b_name   <- as.character(config$var_b$name)
    y            <- scores_result$scores[[var_b_name]]
    logistic_type <- as.character(config$logistic_type %||% "binaria")
    predictors   <- config$regression_predictors
    if (is.null(predictors) || length(predictors)==0) {
      X <- as.data.frame(scores_result$scores[[var_a_name]])
      colnames(X) <- var_a_name
      var_names <- var_a_name
    } else {
      X <- as.data.frame(scores_result$scores[as.character(unlist(predictors))])
      var_names <- as.character(unlist(predictors))
    }
    # F-023: event_level requerido para logística binaria
    event_level_cfg <- if (!is.null(config$event_level) && nchar(as.character(config$event_level)) > 0)
      as.character(config$event_level) else NULL
    if (logistic_type == "binaria" && is.null(event_level_cfg)) {
      result$logistic <- list(blocked=TRUE, reason="EVENTO_NO_DECLARADO",
        stage="event_level_check",
        error="La regresion logistica binaria requiere declarar explicitamente el evento (event_level).")
      result$status   <- "error"
      result$reason   <- "EVENTO_NO_DECLARADO"
      result$stage    <- "event_level_check"
      result$errors   <- list(result$logistic$error)
      result$warnings <- as.list(all_warnings)
      return(result)
    }
    log_result <- if (logistic_type == "multinomial") {
      tryCatch(
        compute_logistic_multinomial(y, X, var_names=var_names, alpha=norm_alpha),
        error=function(e) list(error=e$message)
      )
    } else {
      tryCatch(
        compute_logistic(y, X, type=logistic_type, var_names=var_names, alpha=norm_alpha,
          entry_method=as.character(config$logistic_entry %||% "enter"),
          cut_point=as.numeric(config$cut_point %||% 0.5),
          hosmer_lemeshow=as.character(config$hosmer_lemeshow %||% "yes"),
          roc_curve=as.character(config$roc_curve %||% "yes"),
          pseudo_r2_type=as.character(config$pseudo_r2 %||% "nagelkerke"),
          event_level=event_level_cfg),
        error=function(e) list(error=e$message)
      )
    }
    result$logistic  <- log_result
    if (isTRUE(log_result$blocked)) {
      result$status  <- "error"
      result$errors  <- list(log_result$error)
      result$warnings <- as.list(all_warnings)
      return(result)
    }
    result$status    <- "ok"
    result$warnings  <- as.list(all_warnings)
    if (isTRUE(config$export_word)) {
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      word_filename <- paste0("ResultadosAPA_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx")
      word_path     <- file.path(output_dir, word_filename)

      # Separar correlaciones generales vs dimensionales
      corr_general <- NULL
      corr_dims    <- NULL
      if (!is.null(NULL) && nrow(NULL) > 0) {
        mask_gral  <- NULL$var_a == var_a_name & NULL$var_b == var_b_name
        if (sum(mask_gral) > 0)  corr_general <- NULL[mask_gral, , drop = FALSE]
        if (sum(!mask_gral) > 0) corr_dims    <- NULL[!mask_gral, , drop = FALSE]
      }
      tryCatch({
        doc <- generate_word(
          result     = result,
          config     = config,
          output_dir = output_dir,
          tbl_start  = as.numeric(config$table_start %||% 1)
        )





        word_file <- save_word(doc, output_dir, job_id=NULL)
        result$word_path <- word_file
      }, error = function(e) {
        all_warnings <<- c(all_warnings,
          paste0("No se pudo generar el Word: ", e$message))
        result$word_path <<- NULL
      })
    }
    return(result)
  }

  # ── Regresion ordinal ──────────────────────────────────────────────────
  if (analysis_category == "regresion_ordinal") {
    # F-022: measurement_level nominal bloquea regresion ordinal
    ml_vd_ord <- as.character(config$measurement_level_b %||% "")
    if (ml_vd_ord == "nominal") {
      result$ordinal_regression <- list(
        blocked=TRUE, reason="NIVEL_MEDICION_INCOMPATIBLE", stage="measurement_level_check",
        error="La variable dependiente tiene nivel de medicion nominal. La regresion ordinal requiere variable ordinal.")
      result$status   <- "error"
      result$reason   <- "NIVEL_MEDICION_INCOMPATIBLE"
      result$stage    <- "measurement_level_check"
      result$errors   <- list(result$ordinal_regression$error)
      result$warnings <- as.list(all_warnings)
      return(result)
    }
    var_a_name <- as.character(config$var_a$name); if(var_a_name==""||is.null(var_a_name)) var_a_name <- "Variable A"
    var_b_name <- as.character(config$var_b$name)
    var_a_items <- as.character(unlist(config$var_a$items))
    var_b_items <- as.character(unlist(config$var_b$items))
    # Predictores adicionales (2+ predictores): usa los scores ya calculados
    # por compute_scores() (via config$extra_predictors), no los items crudos,
    # ya que run_ordinal_regression() ahora acepta list(name=..., score=...).
    extra_preds_ord <- NULL
    if (!is.null(config$extra_predictors) && length(config$extra_predictors) > 0) {
      extra_preds_ord <- lapply(config$extra_predictors, function(p) {
        pname <- as.character(p$name)
        if (is.null(pname) || pname == "" || is.null(scores_result$scores[[pname]])) return(NULL)
        list(name = pname, score = scores_result$scores[[pname]])
      })
      extra_preds_ord <- Filter(Negate(is.null), extra_preds_ord)
      if (length(extra_preds_ord) == 0) extra_preds_ord <- NULL
    }
    result$ordinal_regression <- tryCatch(
      run_ordinal_regression(raw_df, var_a_items, var_b_items, var_a_name, var_b_name, alpha=norm_alpha,
        link_function=as.character(config$link_function %||% "logit"),
        ordinalizacion=as.character(config$ordinalizacion %||% "terciles"),
        pseudo_r2_type=as.character(config$pseudo_r2 %||% "nagelkerke"),
        extra_predictors=extra_preds_ord,
        ordered_levels=if (!is.null(config$ordered_levels)) unlist(config$ordered_levels) else NULL),
      error=function(e) list(error=e$message)
    )
    if (isTRUE(result$ordinal_regression$blocked)) {
      result$status   <- "error"
      result$reason   <- result$ordinal_regression$reason
      result$stage    <- result$ordinal_regression$stage
      result$errors   <- list(result$ordinal_regression$error)
      result$warnings <- as.list(all_warnings)
      return(result)
    }
  }

  # ── Regresion jerarquica ───────────────────────────────────────────────────
  if (analysis_category == "regresion_jerarquica") {
    var_b_name  <- as.character(config$var_b$name)
    var_b_items <- as.character(unlist(config$var_b$items))
    blocks      <- if(!is.null(config$hier_blocks) && length(config$hier_blocks)>0) config$hier_blocks else config$hierarchical_blocks
    result$hierarchical_regression <- tryCatch(
      run_hierarchical_regression(raw_df, blocks, var_b_items, var_b_name, alpha=norm_alpha, hier_method=as.character(config$hier_method %||% "enter")),
      error=function(e) list(error=e$message)
    )
    if (!is.null(result$hierarchical_regression$error)) {
      result$status  <- "error"
      result$stage   <- "regresion_jerarquica"
      result$error   <- result$hierarchical_regression$error
      result$blocked <- TRUE
    } else {
      result$status  <- "ok"
    }
    result$warnings <- as.list(all_warnings)
    return(result)
  }

  # ── ANCOVA ─────────────────────────────────────────────────────────────────
  if (analysis_category == "ancova") {
    dep_items       <- as.character(unlist(config$var_a$items))
    dep_name        <- as.character(config$var_a$name)
    group_var       <- as.character(config$group_var %||% "")
    covariate_items <- as.character(unlist(config$var_b$items))
    if (group_var == "" || !group_var %in% names(raw_df)) {
      result$status  <- "error"
      result$stage   <- "ancova_routing"
      result$reason  <- "SIN_VARIABLE_GRUPO"
      result$error   <- "La variable de agrupacion (group_var) es requerida para ANCOVA."
      result$blocked <- TRUE
      result$warnings <- as.list(all_warnings)
      return(result)
    }
    result$ancova <- tryCatch(
      run_ancova(raw_df, dep_items, group_var, covariate_items, dep_name, alpha=norm_alpha,
        posthoc=as.character(config$posthoc %||% "tukey"),
        check_slopes=as.character(config$homogeneity_slopes %||% "yes")),
      error=function(e) list(error=e$message)
    )
    if (!is.null(result$ancova$error)) {
      result$status  <- "error"
      result$stage   <- "ancova"
      result$error   <- result$ancova$error
      result$blocked <- TRUE
    } else {
      result$status  <- "ok"
    }
    result$warnings <- as.list(all_warnings)
    return(result)
  }

  # ── Analisis discriminante ─────────────────────────────────────────────────
  if (analysis_category == "discriminante") {
    predictor_items <- as.character(unlist(config$var_a$items))
    group_var       <- as.character(config$group_var %||% "")
    result$discriminant <- tryCatch(
      run_discriminant(raw_df, predictor_items, group_var, alpha=norm_alpha,
        method=as.character(config$lda_method %||% "simultaneous"),
        cv=as.character(config$lda_cv %||% "yes")),
      error=function(e) list(error=e$message)
    )
  }

  # ── Frecuencias ────────────────────────────────────────────────────────────
  if (analysis_category == "descriptivo") {
    var_a_items   <- as.character(unlist(config$var_a$items))
    var_a_name    <- as.character(config$var_a$name); if(var_a_name==""||is.null(var_a_name)) var_a_name <- "Variable"
    scale_min     <- as.numeric(config$scale$min %||% 1)
    scale_max     <- as.numeric(config$scale$max %||% 5)
    baremo_method <- as.character(config$baremo_method %||% "tercil")
    baremo_levels <- as.character(unlist(config$baremo_levels %||% list("Bajo","Medio","Alto")))
    result$analisis_descriptivo <- tryCatch(
      run_analisis_descriptivo(raw_df, var_a_items, var_a_name, scale_min, scale_max, baremo_levels, baremo_method),
      error=function(e) list(error=e$message)
    )
  }
  if (analysis_category == "frecuencias") {
    var_a_items <- as.character(unlist(config$var_a$items))
    var_a_name  <- as.character(config$var_a$name)
    scale_min   <- as.numeric(config$scale$min %||% 1)
    scale_max   <- as.numeric(config$scale$max %||% 5)
    result$frequencies <- tryCatch(
      run_frequencies(raw_df, var_a_items, var_a_name, scale_min, scale_max),
      error=function(e) list(error=e$message)
    )
  }

  # ── Cluster ────────────────────────────────────────────────────────────────
  if (analysis_category == "cluster") {
    var_a_items <- as.character(unlist(config$var_a$items))
    var_a_name  <- as.character(config$var_a$name)
    n_clusters  <- as.numeric(config$n_clusters %||% 3)
    standardize <- as.character(config$standardize %||% "yes")
    seed_val    <- as.numeric(config$seed %||% 42)
    result$cluster <- tryCatch(
      run_cluster(raw_df, var_a_items, n_clusters, var_a_name, standardize=standardize, seed=seed_val),
      error=function(e) list(error=e$message)
    )
  }

  # ── Cronbach independiente ─────────────────────────────────────────────────
  if (analysis_category == "cronbach") {
    var_a_items <- as.character(unlist(config$var_a$items))
    var_a_name  <- as.character(config$var_a$name)
    result$cronbach_only <- tryCatch(
      run_cronbach_only(raw_df, var_a_items, var_a_name,
        min_rit=as.numeric(config$min_rit %||% 0.3),
        calc_omega=as.character(config$calc_omega %||% "yes"),
        bootstrap_ci=as.character(config$bootstrap_ci %||% "yes")),
      error=function(e) list(error=e$message)
    )
  }

  # ── Baremos independiente ──────────────────────────────────────────────────
  if (analysis_category == "baremos") {
    var_a_items   <- as.character(unlist(config$var_a$items))
    var_a_name    <- as.character(config$var_a$name); if(var_a_name==""||is.null(var_a_name)) var_a_name <- "Variable"
    scale_min     <- as.numeric(config$scale$min %||% 1)
    scale_max     <- as.numeric(config$scale$max %||% 5)
    baremo_method <- as.character(config$baremo_method %||% "tercil")
    baremo_levels <- as.character(unlist(config$baremo_levels %||% list("Bajo","Medio","Alto")))
    result$baremos_only <- tryCatch(
      run_baremos_only(raw_df, var_a_items, var_a_name, scale_min, scale_max, baremo_levels, baremo_method),
      error=function(e) list(error=e$message)
    )
  }

  # ── Descriptivos completos ─────────────────────────────────────────────────
  if (analysis_category == "descriptivos") {
    var_a_items <- as.character(unlist(config$var_a$items))
    var_a_name  <- as.character(config$var_a$name)
    scale_min   <- as.numeric(config$scale$min %||% 1)
    scale_max   <- as.numeric(config$scale$max %||% 5)
    result$descriptives_full <- tryCatch(
      run_descriptives_full(raw_df, var_a_items, var_a_name, scale_min, scale_max),
      error=function(e) list(error=e$message)
    )
  }

  if (analysis_category == "instrumentos") {
    instr_config <- list(
      all_items  = unique(c(as.character(unlist(config$var_a$items)), as.character(unlist(config$var_b$items)))),
      scale_min  = as.numeric(config$scale$min %||% 1),
      scale_max  = as.numeric(config$scale$max %||% 5),
      n_factors  = if(!is.null(config$n_factors) && length(config$n_factors)>0 && !is.na(config$n_factors)) as.integer(config$n_factors) else NULL,
      rotation   = as.character(config$rotation %||% "oblimin"),
      estimator  = as.character(config$estimator %||% "MLR"),
      variables  = lapply(c(
        if(length(config$var_a$dimensions)>0) config$var_a$dimensions
        else list(list(name=as.character(config$var_a$name), items=as.character(unlist(config$var_a$items)))),
        if(length(config$var_b$dimensions)>0) config$var_b$dimensions
        else list(list(name=as.character(config$var_b$name), items=as.character(unlist(config$var_b$items))))
      ), function(d) list(name=as.character(d$name), items=as.character(unlist(d$items))))
    )
    instr_result <- tryCatch(
      compute_instruments(raw_df, instr_config),
      error=function(e) list(error=e$message)
    )
    result$instruments <- instr_result
    if (isTRUE(instr_result$blocked)) {
      result$status   <- "error"
      result$reason   <- instr_result$reason
      result$errors   <- list(instr_result$error)
      result$warnings <- as.list(all_warnings)
      return(result)
    }

    # V de Aiken (validez de contenido) - opcional, requiere matriz de jueces ingresada en la UI
    if (!is.null(config$enable_v_aiken) && as.character(config$enable_v_aiken) %in% c("yes","true","TRUE","1")) {
      va_matrix_raw <- config$v_aiken_matrix
      va_items <- names(va_matrix_raw)
      if (!is.null(va_matrix_raw) && length(va_items) > 0) {
        n_judges <- as.integer(config$v_aiken_judges %||% 5)
        va_scale_min <- as.numeric(config$v_aiken_scale_min %||% 1)
        va_scale_max <- as.numeric(config$v_aiken_scale_max %||% 4)
        va_mat <- matrix(NA_real_, nrow=length(va_items), ncol=n_judges)
        rownames(va_mat) <- va_items
        for (i in seq_along(va_items)) {
          vals <- as.numeric(unlist(va_matrix_raw[[va_items[i]]]))
          if (length(vals) > 0) va_mat[i, 1:min(length(vals), n_judges)] <- vals[1:min(length(vals), n_judges)]
        }
        result$vaiken <- tryCatch(
          compute_vaiken(va_mat, n_judges, va_scale_max, va_scale_min),
          error=function(e) list(error=e$message)
        )
      }
    }
    result$status      <- "ok"
    result$warnings    <- as.list(all_warnings)
    if (isTRUE(config$export_word)) {
      dir.create(output_dir, recursive=TRUE, showWarnings=FALSE)
      tryCatch({
        doc <- generate_word_instruments(result, config, output_dir, as.numeric(config$table_start %||% 1))
        word_file <- save_word(doc, output_dir, job_id=NULL)
        result$word_path <- word_file
      }, error=function(e) {
        all_warnings <<- c(all_warnings, paste0("Word no generado: ", e$message))
      })
    }
    return(result)
  }

  if (analysis_category == "chi_cuadrado") {
    var_a_name <- as.character(config$var_a$name); if(var_a_name==""||is.null(var_a_name)) var_a_name <- "Variable A"
    var_b_name <- as.character(config$var_b$name)
    scores     <- scores_result$scores
    group_var  <- as.character(config$group_var %||% "")
    has_grp    <- (group_var != "" && group_var %in% names(raw_df))
    # Guard F-005: bloquear variables continuas — chi-cuadrado requiere categorias preexistentes
    # F-021: measurement_level="nominal" exime de la prueba de continuidad
    is_continuous_score <- function(x) {
      xc <- x[!is.na(x)]
      is.numeric(xc) && (length(unique(xc)) > 10 || any(abs(xc - round(xc)) > 1e-10))
    }
    ml_a_chi <- as.character(config$measurement_level_a %||% "")
    ml_b_chi <- as.character(config$measurement_level_b %||% "")
    continuous_vars <- character(0)
    if (ml_a_chi != "nominal" && is_continuous_score(scores[[var_a_name]])) continuous_vars <- c(continuous_vars, var_a_name)
    if (!has_grp && ml_b_chi != "nominal" && is_continuous_score(scores[[var_b_name]])) continuous_vars <- c(continuous_vars, var_b_name)
    if (length(continuous_vars) > 0) {
      block_msg <- paste0(
        "Bloqueo metodologico: las variables [", paste(continuous_vars, collapse=", "), "] son continuas ",
        "(mas de 10 valores unicos o con decimales). ",
        "El chi-cuadrado de Pearson requiere variables categoricas preexistentes en los datos. ",
        "Alternativas: correlacion de Pearson/Spearman para variables continuas; ",
        "recodifique manualmente en categorias en su archivo Excel si el diseno lo justifica."
      )
      result$status  <- "error"
      result$errors  <- list(block_msg)
      result$blocked <- TRUE
      result$reason  <- "VARIABLES_CONTINUAS"
      result$warnings <- as.list(all_warnings)
      return(result)
    }
    v1 <- as.factor(scores[[var_a_name]])
    v2 <- if (has_grp) as.factor(as.character(unlist(raw_df[[group_var]]))) else as.factor(scores[[var_b_name]])
    chi_result <- tryCatch(
      compute_chisquare(v1, v2, alpha=norm_alpha, yates=as.character(config$yates_correction %||% "auto"), effect_size=as.character(config$chi_effect_size %||% "cramer"), min_expected=as.numeric(config$min_expected %||% 5)),
      error=function(e) list(error=e$message)
    )
    result$chi_square <- chi_result
    result$status     <- "ok"
    result$warnings   <- as.list(all_warnings)
    if (isTRUE(config$export_word)) {
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      word_filename <- paste0("ResultadosAPA_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx")
      word_path     <- file.path(output_dir, word_filename)

      # Separar correlaciones generales vs dimensionales
      corr_general <- NULL
      corr_dims    <- NULL
      if (!is.null(NULL) && nrow(NULL) > 0) {
        mask_gral  <- NULL$var_a == var_a_name & NULL$var_b == var_b_name
        if (sum(mask_gral) > 0)  corr_general <- NULL[mask_gral, , drop = FALSE]
        if (sum(!mask_gral) > 0) corr_dims    <- NULL[!mask_gral, , drop = FALSE]
      }
      tryCatch({
        doc <- generate_word(
          result     = result,
          config     = config,
          output_dir = output_dir,
          tbl_start  = as.numeric(config$table_start %||% 1)
        )





        word_file <- save_word(doc, output_dir, job_id=NULL)
        result$word_path <- word_file
      }, error = function(e) {
        all_warnings <<- c(all_warnings,
          paste0("No se pudo generar el Word: ", e$message))
        result$word_path <<- NULL
      })
    }
    return(result)
  }

  if (analysis_category == "comparacion") {
    comparison_type <- as.character(config$comparison_type %||% "auto")
    group_var       <- as.character(config$group_var %||% "")
    group_values    <- as.character(unlist(config$group_values %||% list()))
    
    # Obtener vectores de cada grupo
    var_a_name <- as.character(config$var_a$name); if(var_a_name==""||is.null(var_a_name)) var_a_name <- "Variable A"
    scores_all <- scores_result$scores
    
    if (length(group_values) >= 2 && group_var != "" && group_var %in% names(raw_df)) {
      mask1 <- as.character(raw_df[[group_var]]) == group_values[1]
      mask2 <- as.character(raw_df[[group_var]]) == group_values[2]
      x1 <- scores_all[[var_a_name]][mask1]
      x2 <- scores_all[[var_a_name]][mask2]
    } else {
      # Sin variable de grupo: dividir por mitad (demo)
      x_all <- scores_all[[var_a_name]]
      n_half <- length(x_all) %/% 2
      x1 <- x_all[1:n_half]
      x2 <- x_all[(n_half+1):length(x_all)]
      group_values <- c("Grupo 1", "Grupo 2")
    }
    
    ttest_result <- tryCatch(
      compute_ttest(x1, x2, type=comparison_type, alpha=norm_alpha,
                    group_names=as.character(group_values[1:2]),
        hypothesis_type=as.character(config$hypothesis_type %||% "bilateral"),
        effect_size_type=as.character(config$effect_size %||% "cohend"),
        levene=as.character(config$levene_test %||% "yes")),
      error=function(e) list(error=e$message)
    )
    result$ttest      <- ttest_result
    result$status     <- "ok"
    result$warnings   <- as.list(all_warnings)
    if (isTRUE(config$export_word)) {
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      word_filename <- paste0("ResultadosAPA_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx")
      word_path     <- file.path(output_dir, word_filename)

      # Separar correlaciones generales vs dimensionales
      corr_general <- NULL
      corr_dims    <- NULL
      if (!is.null(NULL) && nrow(NULL) > 0) {
        mask_gral  <- NULL$var_a == var_a_name & NULL$var_b == var_b_name
        if (sum(mask_gral) > 0)  corr_general <- NULL[mask_gral, , drop = FALSE]
        if (sum(!mask_gral) > 0) corr_dims    <- NULL[!mask_gral, , drop = FALSE]
      }
      tryCatch({
        doc <- generate_word(
          result     = result,
          config     = config,
          output_dir = output_dir,
          tbl_start  = as.numeric(config$table_start %||% 1)
        )





        word_file <- save_word(doc, output_dir, job_id=NULL)
        result$word_path <- word_file
      }, error = function(e) {
        all_warnings <<- c(all_warnings,
          paste0("No se pudo generar el Word: ", e$message))
        result$word_path <<- NULL
      })
    }
    return(result)
  }

    analysis_types <- unlist(config$analysis_types %||% list("vv"))
    # Filtrar analysis_types si las dimensiones estan vacias
    dims_a <- Filter(function(d) length(unlist(d$items))>0, config$var_a$dimensions %||% list())
    dims_b <- Filter(function(d) length(unlist(d$items))>0, config$var_b$dimensions %||% list())
    if(length(dims_a)==0) analysis_types <- analysis_types[!analysis_types %in% c("vdA","dd")]
    if(length(dims_b)==0) analysis_types <- analysis_types[!analysis_types %in% c("vdB","dd")]
    if(length(analysis_types)==0) analysis_types <- "vv"
    corr_df <- tryCatch(
      compute_correlations(
        scores         = scores,
        config         = config,
        method         = method,
        alpha          = norm_alpha,
        analysis_types = analysis_types,
        hypothesis_type = as.character(config$hypothesis_type %||% "bilateral"),
        multiple_correction = as.character(config$multiple_correction %||% "none")
      ),
      error = function(e) {
        all_warnings <<- c(all_warnings, paste0("Error en correlaciones: ", e$message))
        NULL
      }
    )

    if (!is.null(corr_df) && nrow(corr_df) > 0) {
      result$correlations <- lapply(seq_len(nrow(corr_df)), function(i) {
        row <- as.list(corr_df[i,])
        row$text_apa <- redact_correlation(
          r            = row$r,
          p            = row$p,
          var1         = row$var_a,
          var2         = row$var_b,
          method       = method,
          alpha        = norm_alpha,
          participants = config$participants %||% "los participantes evaluados"
        )
        row
      })
    } else {
      result$correlations <- list()
    }

    # 10. INTERPRETACIONES ACADÉMICAS ────────────────────────────────────────
    result$interpretations <- list(
      normality_text      = redact_normality(norm_res, norm_alpha),
      descriptives_text   = redact_descriptives(desc),
      reliability_text    = redact_reliability(reliability),
      method_recommended  = if (method == "pearson") "r de Pearson" else "Rho de Spearman",
      method_justification = redact_normality(norm_res, norm_alpha)
    )

    # 11. EXPORTAR WORD ──────────────────────────────────────────────────────
    word_path <- NULL
    if (isTRUE(config$export_word)) {
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      word_filename <- paste0("ResultadosAPA_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx")
      word_path     <- file.path(output_dir, word_filename)

      # Separar correlaciones generales vs dimensionales
      corr_general <- NULL
      corr_dims    <- NULL
      if (!is.null(corr_df) && nrow(corr_df) > 0) {
        mask_gral  <- corr_df$var_a == var_a_name & corr_df$var_b == var_b_name
        if (sum(mask_gral) > 0)  corr_general <- corr_df[mask_gral, , drop = FALSE]
        if (sum(!mask_gral) > 0) corr_dims    <- corr_df[!mask_gral, , drop = FALSE]
      }
      tryCatch({
        doc <- generate_word(
          result     = result,
          config     = config,
          output_dir = output_dir,
          tbl_start  = as.numeric(config$table_start %||% 1)
        )





        word_file <- save_word(doc, output_dir, job_id=NULL)
        result$word_path <- word_file
      }, error = function(e) {
        all_warnings <<- c(all_warnings,
          paste0("No se pudo generar el Word: ", e$message))
        result$word_path <<- NULL
      })
    }

    result$warnings <- as.list(all_warnings)

  }, error = function(e) {
    result$status <<- "error"
    result$errors <<- list(e$message)
  })

  result
}

# ── Ejecutar y emitir resultado ──────────────────────────────────────────────
final_result <- run_full_analysis(config, output_dir)
cat(toJSON(final_result, auto_unbox = TRUE, na = "null", digits = 6))
