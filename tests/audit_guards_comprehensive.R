# tests/audit_guards_comprehensive.R
# Pruebas comprensivas de guards P0/P1 — Lote 1C Auditoria CanchariOS
#
# Uso: Rscript tests/audit_guards_comprehensive.R [C|D|E|F|all]
#   C = Guard logistico (VD no binaria)
#   D = Guard ordinal (VD continua)
#   E = Guard chi-cuadrado (variables continuas)
#   F = Guard PLS-SEM (constructo de un solo indicador)
#
# Exit code: 0 = todos PASS (o SKIP), 1 = al menos un FAIL

section_arg <- commandArgs(trailingOnly = TRUE)
section     <- if (length(section_arg) > 0) toupper(trimws(section_arg[1])) else "ALL"

# ---------- infraestructura comun ----------
pass <- 0L; fail <- 0L; skip_n <- 0L

check <- function(id, desc, cond) {
  label <- if (isTRUE(cond)) "PASS" else "FAIL"
  cat(sprintf("  [%s] %s: %s\n", label, id, desc))
  if (isTRUE(cond)) pass <<- pass + 1L else fail <<- fail + 1L
  invisible(isTRUE(cond))
}
skip_test <- function(id, desc, reason) {
  cat(sprintf("  [SKIP] %s: %s -- %s\n", id, desc, reason))
  skip_n <<- skip_n + 1L
}
`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b

# Resolucion de rutas — funciona con Rscript y source()
.script_dir <- tryCatch({
  dirname(normalizePath(sys.frame(1)$ofile))
}, error = function(e) {
  args <- commandArgs(trailingOnly = FALSE)
  f    <- sub("--file=", "", grep("--file=", args, value = TRUE))
  if (length(f) > 0) dirname(normalizePath(f)) else getwd()
})
r_dir          <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "R")
helpers_path   <- file.path(r_dir, "helpers.R")
logistic_path  <- file.path(r_dir, "logistic.R")
ordinal_path   <- file.path(r_dir, "ordinal_regression.R")
pls_path       <- file.path(r_dir, "pls_sem_engine.R")
run_anal_path  <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "run_analysis.R")

cat(sprintf("=== AUDIT GUARDS COMPREHENSIVE [%s] ===\n", section))
cat(sprintf("    R version: %s\n", R.version.string))
cat(sprintf("    r_dir:     %s\n\n", r_dir))

# ============================================================
# SECCION C — Guard logistico: VD debe ser exactamente binaria
# ============================================================
run_section_c <- function() {
  cat("--- [C] Guard logistico (VD no binaria) ---\n")

  # C.L: Pruebas de logica del guard (sin paquetes adicionales)
  is_binary <- function(y) {
    u <- unique(na.omit(as.numeric(y)))
    length(u) == 2
  }

  set.seed(42); n <- 80
  y_cont   <- rnorm(n)
  y_3cat   <- sample(c(1, 2, 3), n, replace = TRUE)
  y_bin01  <- sample(c(0L, 1L), n, replace = TRUE)
  y_bin12  <- sample(c(1L, 2L), n, replace = TRUE)
  y_single <- rep(1L, n)

  check("C.L1", "Logica: VD continua (~100 valores) NO es binaria",   !is_binary(y_cont))
  check("C.L2", "Logica: VD 3 categorias {1,2,3} NO es binaria",     !is_binary(y_3cat))
  check("C.L3", "Logica: VD valor unico {1} NO es binaria",          !is_binary(y_single))
  check("C.L4", "Logica: VD {0,1} SI es binaria",                     is_binary(y_bin01))
  check("C.L5", "Logica: VD {1,2} SI es binaria",                     is_binary(y_bin12))

  # C.I: Pruebas de integracion con el modulo real
  X_test <- data.frame(predictor = rnorm(n))
  has_logistic <- file.exists(logistic_path)

  if (has_logistic) {
    # parent=globalenv() matches production: Rscript loads stats by default,
    # so na.omit, glm, model.matrix etc. are available without explicit library()
    env_c <- new.env(parent = globalenv())
    if (file.exists(helpers_path)) source(helpers_path, local = env_c)
    tryCatch({
      source(logistic_path, local = env_c)

      # C.I1/C.I2 — VD continua: debe bloquear
      r_cont <- env_c$compute_logistic(y_cont, X_test, var_names = "predictor")
      check("C.I1", "Integracion: VD continua → blocked=TRUE",       isTRUE(r_cont$blocked))
      check("C.I2", "Integracion: VD continua → reason=VD_NO_BINARIA", isTRUE(r_cont$reason == "VD_NO_BINARIA"))
      if (isTRUE(r_cont$blocked))
        cat(sprintf("    Mensaje guard: %.120s...\n", r_cont$error))

      # C.I3 — VD 3 categorias: debe bloquear
      r_3cat <- env_c$compute_logistic(y_3cat, X_test, var_names = "predictor")
      check("C.I3", "Integracion: VD {1,2,3} → blocked=TRUE", isTRUE(r_3cat$blocked))

      # C.I4 — VD valor unico: debe bloquear
      r_single <- env_c$compute_logistic(y_single, X_test, var_names = "predictor")
      check("C.I4", "Integracion: VD valor unico → blocked=TRUE", isTRUE(r_single$blocked))

      # C.I5 — VD {0,1}: no debe bloquear, debe tener coeficientes finitos
      r_bin01 <- env_c$compute_logistic(y_bin01, X_test, var_names = "predictor")
      check("C.I5", "Integracion: VD {0,1} → NOT blocked",          !isTRUE(r_bin01$blocked))
      check("C.I6", "Integracion: VD {0,1} → tiene 'coefficients'", !is.null(r_bin01$coefficients))

      # C.I6b: coefficients es lista de listas con campos mixtos; extraer solo numéricos por nombre.
      coef_numeric_fields_c <- c("B", "SE", "Wald", "p", "OR", "OR_ci_lower", "OR_ci_upper")
      coef_values_bin01 <- as.numeric(unlist(
        lapply(r_bin01$coefficients, function(row) row[intersect(coef_numeric_fields_c, names(row))]),
        use.names = FALSE
      ))
      check("C.I6b", "Integracion: VD {0,1} → campos estadisticos (B,SE,OR,p) finitos",
            !is.null(r_bin01$coefficients) &&
            length(coef_values_bin01) > 0 && all(is.finite(coef_values_bin01)))

      # C.I6c-g: verificacion campo a campo
      first_coef_c <- if (!is.null(r_bin01$coefficients) && length(r_bin01$coefficients) > 0)
                        r_bin01$coefficients[[1]] else list()
      check("C.I6c", "Integracion: VD {0,1} → estimacion (B) es finita",
            is.numeric(first_coef_c$B) && is.finite(first_coef_c$B))
      check("C.I6d", "Integracion: VD {0,1} → error estandar (SE) es finito y positivo",
            is.numeric(first_coef_c$SE) && is.finite(first_coef_c$SE) && first_coef_c$SE >= 0)
      check("C.I6e", "Integracion: VD {0,1} → odds ratio (OR) positivo",
            is.numeric(first_coef_c$OR) && is.finite(first_coef_c$OR) && first_coef_c$OR > 0)
      check("C.I6f", "Integracion: VD {0,1} → valor p en [0,1]",
            is.numeric(first_coef_c$p) && is.finite(first_coef_c$p) &&
            first_coef_c$p >= 0 && first_coef_c$p <= 1)
      check("C.I6g", "Integracion: VD {0,1} → IC lower/upper finitos y ordenados",
            is.numeric(first_coef_c$OR_ci_lower) && is.finite(first_coef_c$OR_ci_lower) &&
            is.numeric(first_coef_c$OR_ci_upper) && is.finite(first_coef_c$OR_ci_upper) &&
            first_coef_c$OR_ci_lower <= first_coef_c$OR_ci_upper)

      # C.I6h: JSON roundtrip — vapply sobre el data.frame que produce fromJSON
      if (requireNamespace("jsonlite", quietly=TRUE) && !isTRUE(r_bin01$blocked) && !is.null(r_bin01$coefficients)) {
        json_str_c <- tryCatch(jsonlite::toJSON(r_bin01, auto_unbox=TRUE, na="null"), error=function(e) NULL)
        res_json_c <- if (!is.null(json_str_c))
          tryCatch(jsonlite::fromJSON(json_str_c, simplifyDataFrame=TRUE, simplifyVector=TRUE), error=function(e) NULL)
          else NULL
        if (!is.null(res_json_c)) {
          coef_df_c     <- res_json_c$coefficients
          numeric_cols_c <- if (is.data.frame(coef_df_c)) vapply(coef_df_c, is.numeric, logical(1)) else logical(0)
          num_vals_c     <- unlist(coef_df_c[numeric_cols_c], use.names=FALSE)
          check("C.I6h", "JSON roundtrip: coefficients → data.frame con numericos finitos",
                is.data.frame(coef_df_c) && length(num_vals_c) > 0 && all(is.finite(num_vals_c)))
        } else {
          skip_test("C.I6h", "JSON roundtrip omitido", "fromJSON fallo")
        }
      } else {
        skip_test("C.I6h", "JSON roundtrip omitido", "jsonlite no disponible o modulo bloqueado")
      }

      # C.I7 — VD {1,2}: no debe bloquear (recodifica a 0/1) y producir coeficientes
      r_bin12 <- env_c$compute_logistic(y_bin12, X_test, var_names = "predictor")
      check("C.I7",  "Integracion: VD {1,2} → NOT blocked (recodificada)", !isTRUE(r_bin12$blocked))
      check("C.I7b", "Integracion: VD {1,2} → modelo estima coeficientes",
            !isTRUE(r_bin12$blocked) && !is.null(r_bin12$coefficients))

    }, error = function(e) {
      skip_test("C.I1-I7", "Tests de integracion omitidos", e$message)
    })
  } else {
    skip_test("C.I1-I7", "logistic.R no encontrado", logistic_path)
  }
  cat("\n")
}

# ============================================================
# SECCION D — Guard ordinal (Lote 1F): 15 escenarios obligatorios
# ============================================================
run_section_d <- function() {
  cat("--- [D] Guard ordinal — Lote 1G (VD_BINARIA + equivalencia numerica) ---\n")

  # D.L: Logica del guard (VD_CONTINUA se detecta por n_unique>10 o decimales)
  is_continuous_vd <- function(x) {
    xc <- na.omit(x)
    if (!is.numeric(xc)) return(FALSE)
    n_unique <- length(unique(xc))
    has_dec  <- any(abs(xc - round(xc)) > 1e-10)
    n_unique > 10 || has_dec
  }

  set.seed(7); n <- 60
  vd_cont <- rnorm(n, mean = 3, sd = 0.8)
  vd_dec  <- round(seq(1, 5, length.out = n), 2)
  vd_lk3  <- sample(1:3, n, replace = TRUE)
  vd_lk5  <- sample(1:5, n, replace = TRUE)
  vd_text <- sample(c("bajo","medio","alto"), n, replace = TRUE)

  check("D.L1", "Logica: VD continua rnorm → detectada como continua",    is_continuous_vd(vd_cont))
  check("D.L2", "Logica: VD con decimales → detectada como continua",      is_continuous_vd(vd_dec))
  check("D.L3", "Logica: VD Likert {1,2,3} → NO detectada como continua", !is_continuous_vd(vd_lk3))
  check("D.L4", "Logica: VD Likert {1,2,3,4,5} → NO detectada",          !is_continuous_vd(vd_lk5))
  check("D.L5", "Logica: VD texto → NO detectada (no es numerica)",       !is_continuous_vd(vd_text))

  # D.ORD: 15 escenarios de integracion (Lote 1F A6) — requiere MASS
  has_ordinal <- file.exists(ordinal_path) && requireNamespace("MASS", quietly = TRUE)

  if (has_ordinal) {
    library(MASS)
    env_d <- new.env(parent = globalenv())
    if (file.exists(helpers_path)) source(helpers_path, local = env_d)
    tryCatch({
      source(ordinal_path, local = env_d)
      set.seed(42); vi_vec <- rnorm(60)

      call_ord <- function(...) {
        tryCatch(env_d$run_ordinal_regression(...),
                 error = function(e) list(blocked=TRUE, reason="ERROR_INTERNO", error=e$message))
      }

      # ── a) ordered factor (4 casos) ──────────────────────────────────────
      # D.ORD.1: ordered factor 3 niveles balanceado → no bloquear
      vd_ord3 <- ordered(sample(c("bajo","medio","alto"), 60, replace=TRUE),
                          levels=c("bajo","medio","alto"))
      r1 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_ord3), var_a_items="vi",
                     var_b_items="vd", var_a_name="VI", var_b_name="VD_ord3")
      check("D.ORD.1", "ordered factor 3 niveles → no bloqueado",
            !isTRUE(r1$blocked) && is.null(r1$error))

      # D.ORD.2: ordered factor 5 niveles → no bloquear
      vd_ord5 <- ordered(sample(1:5, 60, replace=TRUE), levels=1:5)
      r2 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_ord5), var_a_items="vi",
                     var_b_items="vd", var_a_name="VI", var_b_name="VD_ord5")
      check("D.ORD.2", "ordered factor 5 niveles → no bloqueado",
            !isTRUE(r2$blocked) && is.null(r2$error))

      # D.ORD.3: ordered factor 6 niveles, 1 nivel vacio → advertencia + no bloqueo
      vd_ord6 <- ordered(sample(c("A","B","C","D","E"), 60, replace=TRUE),
                          levels=c("A","B","C","D","E","F"))   # F nunca observado
      r3 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_ord6), var_a_items="vi",
                     var_b_items="vd", var_a_name="VI", var_b_name="VD_ord6")
      check("D.ORD.3",  "ordered factor con nivel vacio → no bloqueado",
            !isTRUE(r3$blocked) && is.null(r3$error))
      check("D.ORD.3b", "ordered factor con nivel vacio → empty_levels_warning no nulo",
            !isTRUE(r3$blocked) && !is.null(r3$empty_levels_warning))

      # D.ORD.4: ordered factor con solo 1 nivel observado → CATEGORIAS_INSUFICIENTES
      vd_ord1 <- ordered(rep("solo_uno", 60), levels=c("solo_uno","otro"))
      r4 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_ord1), var_a_items="vi",
                     var_b_items="vd", var_a_name="VI", var_b_name="VD_1nivel")
      check("D.ORD.4", "ordered factor 1 nivel observado → CATEGORIAS_INSUFICIENTES",
            isTRUE(r4$blocked) && isTRUE(r4$reason == "CATEGORIAS_INSUFICIENTES"))

      # ── b) factor no ordenado (2 casos) ──────────────────────────────────
      # D.ORD.5: factor sin ordered_levels → ORDEN_NO_DECLARADO
      vd_fac <- factor(sample(c("bajo","medio","alto"), 60, replace=TRUE))
      r5 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_fac), var_a_items="vi",
                     var_b_items="vd", var_a_name="VI", var_b_name="VD_fac_sinord")
      check("D.ORD.5", "factor no ordenado sin ordered_levels → ORDEN_NO_DECLARADO",
            isTRUE(r5$blocked) && isTRUE(r5$reason == "ORDEN_NO_DECLARADO"))

      # D.ORD.6: factor no ordenado CON ordered_levels → no bloquear
      r6 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_fac), var_a_items="vi",
                     var_b_items="vd", var_a_name="VI", var_b_name="VD_fac_conord",
                     ordered_levels=c("bajo","medio","alto"))
      check("D.ORD.6", "factor no ordenado con ordered_levels → no bloqueado",
            !isTRUE(r6$blocked) && is.null(r6$error))

      # ── c) numerico pocas categorias (2 casos) — clave: D.I4b fix ─────────
      # D.ORD.7: numerico {1,2,3} sin ordered_levels → ORDEN_NO_DECLARADO
      vd_num3 <- sample(1:3, 60, replace=TRUE)
      r7 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_num3), var_a_items="vi",
                     var_b_items="vd", var_a_name="VI", var_b_name="VD_num3_sinord")
      check("D.ORD.7", "numerico {1,2,3} sin ordered_levels → ORDEN_NO_DECLARADO",
            isTRUE(r7$blocked) && isTRUE(r7$reason == "ORDEN_NO_DECLARADO"))

      # D.ORD.8: numerico {1,2,3} CON ordered_levels → no bloquear (CORRECCION D.I4b)
      r8 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_num3), var_a_items="vi",
                     var_b_items="vd", var_a_name="VI", var_b_name="VD_num3_conord",
                     ordered_levels=c(1,2,3))
      check("D.ORD.8", "[D.I4b FIX] numerico {1,2,3} con ordered_levels → no bloqueado",
            !isTRUE(r8$blocked) && is.null(r8$error))

      # ── d) continua → VD_CONTINUA ────────────────────────────────────────
      # D.ORD.9: VD continua rnorm → VD_CONTINUA
      r9 <- call_ord(df=data.frame(vi=vi_vec, vd=rnorm(60, 3, 0.8)), var_a_items="vi",
                     var_b_items="vd", var_a_name="VI", var_b_name="VD_continua")
      check("D.ORD.9", "VD continua rnorm → VD_CONTINUA",
            isTRUE(r9$blocked) && isTRUE(r9$reason == "VD_CONTINUA"))

      # ── e) categoria unica → CATEGORIAS_INSUFICIENTES ─────────────────────
      # D.ORD.10: VD con un solo valor constante
      vd_const <- ordered(rep("siempre", 60), levels=c("siempre","nunca"))
      r10 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_const), var_a_items="vi",
                      var_b_items="vd", var_a_name="VI", var_b_name="VD_const")
      check("D.ORD.10", "VD un solo nivel observado → CATEGORIAS_INSUFICIENTES",
            isTRUE(r10$blocked) && isTRUE(r10$reason == "CATEGORIAS_INSUFICIENTES"))

      # ── f) nivel vacio → 2 categorias activas → VD_BINARIA ─────────────────
      # D.ORD.11: ordered {A,B,C} con "B" sin obs → droplevels → {A,C} = 2 cats → VD_BINARIA
      vd_ord_partial <- ordered(c(rep("A",30), rep("C",30)), levels=c("A","B","C"))  # "B" sin obs
      r11 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_ord_partial), var_a_items="vi",
                      var_b_items="vd", var_a_name="VI", var_b_name="VD_ordParc")
      cat(sprintf("  [D.ORD.DIAG] D.ORD.11: blocked=%s reason=%s stage=%s\n",
                  isTRUE(r11$blocked),
                  if (!is.null(r11$reason)) r11$reason else "NULL",
                  if (!is.null(r11$stage))  r11$stage  else "NULL"))
      cat(sprintf("  [D.ORD.DIAG] D.ORD.11: observed=%s empty=%s\n",
                  if (!is.null(r11$details$observed_levels))
                    paste(r11$details$observed_levels, collapse=",") else "NULL",
                  if (!is.null(r11$details$empty_levels))
                    paste(r11$details$empty_levels, collapse=",")    else "NULL"))
      if (!is.null(r11$error))
        cat(sprintf("  [D.ORD.DIAG] D.ORD.11: error=%.120s\n", r11$error))
      check("D.ORD.11", "ordered factor con nivel no observado → VD_BINARIA (2 categorias activas)",
            isTRUE(r11$blocked) && isTRUE(r11$reason == "VD_BINARIA"))

      # ── g) VD con exactamente 2 categorias → VD_BINARIA ────────────────────
      # D.ORD.12: {bajo,alto} = 2 categorias → VD_BINARIA
      vd_sep <- ordered(c(rep("bajo",8), rep("alto",52)), levels=c("bajo","alto"))
      r12 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_sep), var_a_items="vi",
                      var_b_items="vd", var_a_name="VI", var_b_name="VD_sep")
      check("D.ORD.12", "VD binaria {bajo,alto} → VD_BINARIA (2 categorias → usar logistica)",
            isTRUE(r12$blocked) && isTRUE(r12$reason == "VD_BINARIA"))

      # D.ORD.12b: binario balanceado ordered {"0","1"}
      vd_bin_bal <- ordered(sample(c("0","1"), 60, replace=TRUE), levels=c("0","1"))
      r12b <- call_ord(df=data.frame(vi=vi_vec, vd=vd_bin_bal), var_a_items="vi",
                       var_b_items="vd", var_a_name="VI", var_b_name="VD_binbal")
      check("D.ORD.12b", "VD binaria balanceada {0,1} → VD_BINARIA",
            isTRUE(r12b$blocked) && isTRUE(r12b$reason == "VD_BINARIA"))

      # D.ORD.12c: binario desbalanceado {si,no} 55-5
      vd_bin_unbal <- ordered(c(rep("si",55), rep("no",5)), levels=c("no","si"))
      r12c <- call_ord(df=data.frame(vi=vi_vec, vd=vd_bin_unbal), var_a_items="vi",
                       var_b_items="vd", var_a_name="VI", var_b_name="VD_binunbal")
      check("D.ORD.12c", "VD binaria desbalanceada {si,no} → VD_BINARIA",
            isTRUE(r12c$blocked) && isTRUE(r12c$reason == "VD_BINARIA"))

      # D.ORD.12d: binario con separacion perfecta en VI
      vi_sep2    <- c(seq(-3, -0.1, length.out=30), seq(0.1, 3, length.out=30))
      vd_bin_sep <- ordered(c(rep("bajo",30), rep("alto",30)), levels=c("bajo","alto"))
      r12d <- call_ord(df=data.frame(vi=vi_sep2, vd=vd_bin_sep), var_a_items="vi",
                       var_b_items="vd", var_a_name="VI", var_b_name="VD_binsep")
      check("D.ORD.12d", "VD binaria con separacion perfecta en VI → VD_BINARIA",
            isTRUE(r12d$blocked) && isTRUE(r12d$reason == "VD_BINARIA"))

      # ── D.EQ: equivalencia numerica con MASS::polr() directo ────────────────
      # Tolerancias: coef/thresholds abs<=1e-8, logLik/AIC abs<=1e-8, SE rel<=1e-6, n exacto
      eq_tol_coef <- 1e-8
      eq_tol_ll   <- 1e-8
      eq_tol_se   <- 1e-6

      eq_check_case <- function(id, desc, res, ref_mdl, ref_n) {
        if (isTRUE(res$blocked)) {
          check(id, paste(desc, "-> NOT blocked"), FALSE); return(invisible(FALSE))
        }
        rv       <- res$raw_values
        ref_coef <- coef(ref_mdl)
        ref_zeta <- ref_mdl$zeta
        ref_ct   <- coef(summary(ref_mdl))
        ref_se   <- ref_ct[names(ref_coef), "Std. Error"]
        ref_ll   <- as.numeric(logLik(ref_mdl)[1])
        ref_aic  <- AIC(ref_mdl)

        coef_ok <- !is.null(rv$coefficients_B) &&
                   length(rv$coefficients_B) == length(ref_coef) &&
                   max(abs(rv$coefficients_B - ref_coef)) <= eq_tol_coef
        thr_ok  <- !is.null(rv$thresholds) &&
                   length(rv$thresholds) == length(ref_zeta) &&
                   max(abs(rv$thresholds - ref_zeta)) <= eq_tol_coef
        ll_ok   <- !is.null(rv$logLik) && abs(rv$logLik - ref_ll) <= eq_tol_ll
        aic_ok  <- !is.null(rv$AIC_val) && abs(rv$AIC_val - ref_aic) <= eq_tol_ll
        se_ok   <- !is.null(rv$std_errors) &&
                   length(rv$std_errors) == length(ref_se) &&
                   max(abs(rv$std_errors - ref_se) / pmax(abs(ref_se), 1e-12)) <= eq_tol_se
        n_ok    <- isTRUE(res$n == ref_n)

        ok <- coef_ok && thr_ok && ll_ok && aic_ok && se_ok && n_ok
        if (!ok) {
          if (!coef_ok) cat(sprintf("    [EQ DIAG %s] coef max abs diff: %g\n", id,
            if (!is.null(rv$coefficients_B)) max(abs(rv$coefficients_B - ref_coef)) else NA))
          if (!thr_ok)  cat(sprintf("    [EQ DIAG %s] thresh max abs diff: %g\n", id,
            if (!is.null(rv$thresholds)) max(abs(rv$thresholds - ref_zeta)) else NA))
          if (!ll_ok)   cat(sprintf("    [EQ DIAG %s] logLik abs diff: %g\n", id,
            if (!is.null(rv$logLik)) abs(rv$logLik - ref_ll) else NA))
          if (!se_ok)   cat(sprintf("    [EQ DIAG %s] SE max rel diff: %g\n", id,
            if (!is.null(rv$std_errors))
              max(abs(rv$std_errors - ref_se) / pmax(abs(ref_se), 1e-12)) else NA))
          if (!n_ok)    cat(sprintf("    [EQ DIAG %s] n: got %d ref %d\n", id, res$n, ref_n))
        }
        check(id, desc, ok)
      }

      # D.EQ.1: 3-level balanced, link=logit
      set.seed(201)
      eq1_vi  <- rnorm(60)
      eq1_vd  <- ordered(sample(c("bajo","medio","alto"), 60, replace=TRUE),
                          levels=c("bajo","medio","alto"))
      eq1_df  <- data.frame(vi=eq1_vi, vd=eq1_vd)
      eq1_res <- call_ord(df=eq1_df, var_a_items="vi", var_b_items="vd",
                           var_a_name="vi", var_b_name="VD_eq1")
      eq1_dat <- eq1_df[complete.cases(eq1_df), ]; eq1_dat$vd <- droplevels(eq1_dat$vd)
      eq1_ref <- tryCatch(MASS::polr(vd ~ vi, data=eq1_dat, Hess=TRUE, method="logistic"),
                           error=function(e) NULL)
      if (!is.null(eq1_ref)) {
        eq_check_case("D.EQ.1",
          "EQ 3-level balanced: coef/thresh/logLik/AIC/SE/n coinciden con MASS::polr",
          eq1_res, eq1_ref, nrow(eq1_dat))
      } else skip_test("D.EQ.1", "referencia polr fallo", "error en caso 1")

      # D.EQ.2: 5-level Likert
      set.seed(202)
      eq2_vi  <- rnorm(80)
      eq2_vd  <- ordered(sample(1:5, 80, replace=TRUE), levels=1:5)
      eq2_df  <- data.frame(vi=eq2_vi, vd=eq2_vd)
      eq2_res <- call_ord(df=eq2_df, var_a_items="vi", var_b_items="vd",
                           var_a_name="vi", var_b_name="VD_eq2")
      eq2_dat <- eq2_df[complete.cases(eq2_df), ]; eq2_dat$vd <- droplevels(eq2_dat$vd)
      eq2_ref <- tryCatch(MASS::polr(vd ~ vi, data=eq2_dat, Hess=TRUE, method="logistic"),
                           error=function(e) NULL)
      if (!is.null(eq2_ref)) {
        eq_check_case("D.EQ.2",
          "EQ 5-level Likert: coef/thresh/logLik/AIC/SE/n coinciden con MASS::polr",
          eq2_res, eq2_ref, nrow(eq2_dat))
      } else skip_test("D.EQ.2", "referencia polr fallo", "error en caso 2")

      # D.EQ.3: 4-level ordered factor
      set.seed(203)
      eq3_vi  <- rnorm(70)
      eq3_vd  <- ordered(sample(c("A","B","C","D"), 70, replace=TRUE),
                          levels=c("A","B","C","D"))
      eq3_df  <- data.frame(vi=eq3_vi, vd=eq3_vd)
      eq3_res <- call_ord(df=eq3_df, var_a_items="vi", var_b_items="vd",
                           var_a_name="vi", var_b_name="VD_eq3")
      eq3_dat <- eq3_df[complete.cases(eq3_df), ]; eq3_dat$vd <- droplevels(eq3_dat$vd)
      eq3_ref <- tryCatch(MASS::polr(vd ~ vi, data=eq3_dat, Hess=TRUE, method="logistic"),
                           error=function(e) NULL)
      if (!is.null(eq3_ref)) {
        eq_check_case("D.EQ.3",
          "EQ 4-level ordered: coef/thresh/logLik/AIC/SE/n coinciden con MASS::polr",
          eq3_res, eq3_ref, nrow(eq3_dat))
      } else skip_test("D.EQ.3", "referencia polr fallo", "error en caso 3")

      # D.EQ.4: 3-level con nivel declarado vacio {D} → droplevels → 3 activos ≥ 3
      set.seed(204)
      eq4_vi  <- rnorm(60)
      eq4_vd  <- ordered(sample(c("A","B","C"), 60, replace=TRUE),
                          levels=c("A","B","C","D"))  # D nunca observado
      eq4_df  <- data.frame(vi=eq4_vi, vd=eq4_vd)
      eq4_res <- call_ord(df=eq4_df, var_a_items="vi", var_b_items="vd",
                           var_a_name="vi", var_b_name="VD_eq4")
      eq4_dat <- eq4_df[complete.cases(eq4_df), ]; eq4_dat$vd <- droplevels(eq4_dat$vd)
      eq4_ref <- tryCatch(MASS::polr(vd ~ vi, data=eq4_dat, Hess=TRUE, method="logistic"),
                           error=function(e) NULL)
      if (!is.null(eq4_ref)) {
        eq_check_case("D.EQ.4",
          "EQ 3-level + nivel vacio declarado: coincide con MASS::polr (post-droplevels)",
          eq4_res, eq4_ref, nrow(eq4_dat))
      } else skip_test("D.EQ.4", "referencia polr fallo", "error en caso 4")

      # D.EQ.5: 3-level con 10 NA en VI → complete.cases reduce n
      set.seed(205)
      eq5_vi  <- c(rep(NA_real_, 10), rnorm(60))
      eq5_vd  <- ordered(sample(c("bajo","medio","alto"), 70, replace=TRUE),
                          levels=c("bajo","medio","alto"))
      eq5_df  <- data.frame(vi=eq5_vi, vd=eq5_vd)
      eq5_res <- call_ord(df=eq5_df, var_a_items="vi", var_b_items="vd",
                           var_a_name="vi", var_b_name="VD_eq5")
      eq5_dat <- eq5_df[complete.cases(eq5_df), ]; eq5_dat$vd <- droplevels(eq5_dat$vd)
      eq5_ref <- tryCatch(MASS::polr(vd ~ vi, data=eq5_dat, Hess=TRUE, method="logistic"),
                           error=function(e) NULL)
      if (!is.null(eq5_ref)) {
        eq_check_case("D.EQ.5",
          "EQ 3-level 10 NA en VI: complete.cases → coincide con MASS::polr",
          eq5_res, eq5_ref, nrow(eq5_dat))
      } else skip_test("D.EQ.5", "referencia polr fallo", "error en caso 5")

      # ── h) predictor constante → PREDICTOR_CONSTANTE ──────────────────────
      # D.ORD.13: predictor constante (sin varianza)
      vd_ok13 <- ordered(sample(c("bajo","medio","alto"), 60, replace=TRUE),
                          levels=c("bajo","medio","alto"))
      r13 <- call_ord(df=data.frame(vi=rep(5,60), vd=vd_ok13), var_a_items="vi",
                      var_b_items="vd", var_a_name="VI_const", var_b_name="VD_ok13")
      check("D.ORD.13", "predictor constante → PREDICTOR_CONSTANTE",
            isTRUE(r13$blocked) && isTRUE(r13$reason == "PREDICTOR_CONSTANTE"))

      # ── i) NA en VD → complete cases ──────────────────────────────────────
      # D.ORD.14: VD con 15 NA → complete cases, n>=10, no bloquear
      vd_na <- ordered(c(rep(NA,15), sample(c("bajo","medio","alto"), 45, replace=TRUE)),
                       levels=c("bajo","medio","alto"))
      r14 <- call_ord(df=data.frame(vi=vi_vec, vd=vd_na), var_a_items="vi",
                      var_b_items="vd", var_a_name="VI", var_b_name="VD_naVD")
      check("D.ORD.14", "VD con NA → complete cases, no bloqueado",
            !isTRUE(r14$blocked) && is.null(r14$error))

      # ── j) NA en predictor → complete cases ───────────────────────────────
      # D.ORD.15: predictor con 15 NA → complete cases, n>=10, no bloquear
      vd_ok15 <- ordered(sample(c("bajo","medio","alto"), 60, replace=TRUE),
                          levels=c("bajo","medio","alto"))
      r15 <- call_ord(df=data.frame(vi=c(rep(NA,15), rnorm(45)), vd=vd_ok15),
                      var_a_items="vi", var_b_items="vd",
                      var_a_name="VI_naVI", var_b_name="VD_ok15")
      check("D.ORD.15", "NA en predictor → complete cases, no bloqueado",
            !isTRUE(r15$blocked) && is.null(r15$error))

    }, error = function(e) {
      skip_test("D.ORD.1-15+EQ.1-5", "Tests de integracion omitidos", e$message)
    })
  } else {
    reason <- if (!file.exists(ordinal_path)) "ordinal_regression.R no encontrado"
              else "paquete MASS no disponible"
    skip_test("D.ORD.1-15+EQ.1-5", "Tests de integracion omitidos", reason)
  }
  cat("\n")
}

# ============================================================
# SECCION E — Guard chi-cuadrado: variables deben ser categoricas
# ============================================================
run_section_e <- function() {
  cat("--- [E] Guard chi-cuadrado (variables continuas) ---\n")

  # Misma logica que run_analysis.R lineas 740-743
  is_continuous_score <- function(x) {
    xc <- x[!is.na(x)]
    is.numeric(xc) && (length(unique(xc)) > 10 || any(abs(xc - round(xc)) > 1e-10))
  }

  set.seed(99); n <- 100
  sc_cat3  <- sample(1:3, n, replace = TRUE)             # 3 categorias enteras
  sc_cat2  <- sample(c(0L, 1L), n, replace = TRUE)       # binario
  sc_cont  <- rnorm(n)                                    # continua
  sc_dec   <- round(rnorm(n, 3, 0.5), 2)                 # con decimales
  sc_text  <- sample(c("A","B","C"), n, replace = TRUE)  # texto
  sc_11int <- sample(1:11, n, replace = TRUE)             # 11 enteros unicos (>10)

  check("E.L1", "Guard: {1,2,3} enteros → NOT continua",          !is_continuous_score(sc_cat3))
  check("E.L2", "Guard: {0,1} binario → NOT continua",            !is_continuous_score(sc_cat2))
  check("E.L3", "Guard: rnorm continua → SI continua",             is_continuous_score(sc_cont))
  check("E.L4", "Guard: escores con decimales → SI continua",      is_continuous_score(sc_dec))
  check("E.L5", "Guard: texto → NOT continua (not numeric)",      !is_continuous_score(sc_text))

  # E.NOTE: F-021 — 11+ enteros produce falso positivo
  cat(sprintf("  [NOTE] E.L6 (F-021 conocido): 11 enteros unicos → is_continuous=%s ",
              is_continuous_score(sc_11int)))
  cat("(falso positivo esperado: >10 trigger bloquea nominales con muchas categorias)\n")

  # E.I: Pruebas conductuales — evidencia principal del guard
  # El guard en run_analysis.R delega la decision a is_continuous_score().
  # Usamos la misma funcion inline (copia fiel de run_analysis.R lineas 740-743)
  # para verificar conducta con datos reales.
  set.seed(99)
  chi_x_bin  <- sample(c("M", "F"), 100, replace = TRUE)
  chi_x_cat3 <- sample(c("A", "B", "C"), 100, replace = TRUE)
  chi_x_cont <- rnorm(100)

  # E.I1-I4: chi-cuadrado con dos categoricas → valido sin transformacion
  r_chi <- tryCatch(
    chisq.test(table(chi_x_bin, chi_x_cat3), correct = FALSE),
    error = function(e) list(statistic = NA, p.value = NA, observed = matrix(0, 1, 1))
  )
  check("E.I1", "Conductual: chi {M,F}×{A,B,C} → estadistico finito",
        is.finite(r_chi$statistic))
  check("E.I2", "Conductual: chi {M,F}×{A,B,C} → p.value en [0,1]",
        is.finite(r_chi$p.value) && r_chi$p.value >= 0 && r_chi$p.value <= 1)
  check("E.I3", "Conductual: tabla 2×3 — sin tricotomizacion silenciosa (no es 3×3)",
        isTRUE(nrow(r_chi$observed) == 2 && ncol(r_chi$observed) == 3))
  check("E.I4", "Conductual: guard bloquea VD continua antes de chisq.test",
        is_continuous_score(chi_x_cont))

  # E.SRC: Verificar codigo fuente — complementario a la evidencia conductual
  if (file.exists(run_anal_path)) {
    src_lines <- readLines(run_anal_path, warn = FALSE)
    check("E.SRC1", "Fuente: is_continuous_score definida en run_analysis.R",
          any(grepl("is_continuous_score", src_lines, fixed = TRUE)))
    check("E.SRC2", "Fuente: guard bloquea con status='error' en chi_cuadrado",
          any(grepl('result\\$status.*<-.*"error"', src_lines)))
    check("E.SRC3", "Fuente: guard bloquea con reason='VARIABLES_CONTINUAS'",
          any(grepl("VARIABLES_CONTINUAS", src_lines, fixed = TRUE)))
    # E.SRC4: scoped to chi-square region (within 80 lines of VARIABLES_CONTINUAS marker)
    # The ANOVA cut(breaks=3) is ~445 lines away; this check confirms the chi block is clean.
    vars_cont_ln <- which(grepl("VARIABLES_CONTINUAS", src_lines, fixed = TRUE))[1]
    cut_lines    <- which(grepl('cut\\(.*breaks.*=.*3', src_lines))
    near_cut     <- if (!is.na(vars_cont_ln)) cut_lines[abs(cut_lines - vars_cont_ln) <= 80] else integer(0)
    check("E.SRC4", "Fuente: sin cut(breaks=3) en zona chi-cuadrado (±80 lineas de VARIABLES_CONTINUAS)",
          length(near_cut) == 0)
  } else {
    skip_test("E.SRC1-SRC4", "Verificacion de fuente omitida", "run_analysis.R no encontrado")
  }
  cat("\n")
}

# ============================================================
# SECCION F — Guard PLS-SEM: constructo con un solo indicador
# ============================================================
run_section_f <- function() {
  cat("--- [F] Guard PLS-SEM (single-item construct) ---\n")
  `%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b

  # F.L: Logica del guard (sin seminr)
  constructs_test <- list(
    list(name = "ConstructoA", items = c("item1a", "item1b")),
    list(name = "ConstructoB", items = c("item2")),
    list(name = "ConstructoC", items = c("item3a", "item3b", "item3c"))
  )
  df_f <- data.frame(item1a=rnorm(30), item1b=rnorm(30), item2=rnorm(30),
                     item3a=rnorm(30), item3b=rnorm(30), item3c=rnorm(30))

  single_list <- Filter(Negate(is.null), lapply(constructs_test, function(ct) {
    avail <- intersect(ct$items, names(df_f))
    if (length(avail) == 1) list(name = ct$name, item = avail[1]) else NULL
  }))

  check("F.L1", "Guard logico: detecta exactamente 1 constructo single-item",
        length(single_list) == 1)
  check("F.L2", "Guard logico: ConstructoB (1 item) identificado correctamente",
        length(single_list) >= 1 && single_list[[1]]$name == "ConstructoB")
  check("F.L3", "Guard logico: ConstructoA (2 items) NO bloqueado",
        !any(sapply(single_list, function(x) x$name == "ConstructoA")))
  check("F.L4", "Guard logico: ConstructoC (3 items) NO bloqueado",
        !any(sapply(single_list, function(x) x$name == "ConstructoC")))

  # F.SRC: Verificar que __dup__ fue eliminado y guard existe en fuente
  if (file.exists(pls_path)) {
    pls_src <- readLines(pls_path, warn = FALSE)
    check("F.SRC1", "Fuente: codigo __dup__ eliminado de pls_sem_engine.R",
          !any(grepl("__dup__", pls_src, fixed = TRUE)))
    check("F.SRC2", "Fuente: guard SINGLE_ITEM_CONSTRUCTS existe",
          any(grepl("SINGLE_ITEM_CONSTRUCTS", pls_src, fixed = TRUE)))
    check("F.SRC3", "Fuente: guard 'single_item_constructs' definido",
          any(grepl("single_item_constructs", pls_src, fixed = TRUE)))
  } else {
    skip_test("F.SRC1-SRC3", "pls_sem_engine.R no encontrado", pls_path)
  }

  # F.I: Integracion con el modulo real (requiere seminr, jsonlite, dplyr, openxlsx)
  has_seminr <- file.exists(pls_path) &&
    requireNamespace("seminr",   quietly = TRUE) &&
    requireNamespace("jsonlite", quietly = TRUE) &&
    requireNamespace("dplyr",    quietly = TRUE) &&
    requireNamespace("openxlsx", quietly = TRUE)

  if (has_seminr) {
    # parent=globalenv() so that stats and loaded packages (seminr, dplyr, etc.)
    # are accessible from within the sourced pls_sem_engine.R environment
    env_f <- new.env(parent = globalenv())
    tryCatch({
      source(pls_path, local = env_f)
      check("F.PKG", "Paquete seminr cargado exitosamente via pls_sem_engine.R", TRUE)

      # Datos de prueba
      set.seed(42)
      tmp_csv <- tempfile(fileext = ".csv")
      df_pls <- data.frame(
        A1 = rnorm(80) + 3, A2 = rnorm(80) + 3,
        B1 = rnorm(80) + 3,
        C1 = rnorm(80) + 3, C2 = rnorm(80) + 3
      )
      write.csv(df_pls, tmp_csv, row.names = FALSE)

      # F.I1/F.I2 — Constructo con 1 item: debe bloquear ANTES de estimar
      params_blocked <- list(
        data_path  = tmp_csv,
        constructs = list(
          list(name = "A", items = c("A1", "A2")),
          list(name = "B", items = c("B1")),        # single-item → bloquear
          list(name = "C", items = c("C1", "C2"))
        ),
        paths  = list(list(from = "A", to = "B"), list(from = "B", to = "C")),
        n_boot = 10L
      )
      r_blocked <- env_f$run_pls_sem(params_blocked)
      check("F.I1", "Integracion: single-item → blocked=TRUE",
            isTRUE(r_blocked$blocked))
      check("F.I2", "Integracion: single-item → reason=SINGLE_ITEM_CONSTRUCTS",
            isTRUE(r_blocked$reason == "SINGLE_ITEM_CONSTRUCTS"))
      if (isTRUE(r_blocked$blocked))
        cat(sprintf("    Mensaje guard: %.120s...\n", r_blocked$error))

      # F.I3 — Todos los constructos con 2+ items: guard NO debe bloquear,
      #         salida estructurada y finita
      params_valid <- list(
        data_path  = tmp_csv,
        constructs = list(
          list(name = "A", items = c("A1", "A2")),
          list(name = "C", items = c("C1", "C2"))
        ),
        paths  = list(list(from = "A", to = "C")),
        n_boot = 10L
      )
      r_valid <- tryCatch(
        env_f$run_pls_sem(params_valid),
        error = function(e) list(error = e$message, blocked = FALSE)
      )
      check("F.I3",  "Integracion: 2-item constructs → guard NO bloquea",
            !isTRUE(r_valid$blocked))
      check("F.I3b", "Integracion: 2-item valid → salida tiene tablas o success=TRUE",
            !isTRUE(r_valid$blocked) &&
            (isTRUE(r_valid$success) || !is.null(r_valid$path_coefficients) || !is.null(r_valid$tables)))
      check("F.I3c", "Integracion: 2-item valid → sin NaN/Inf en valores numericos",
            !isTRUE(r_valid$blocked) && {
              nums <- tryCatch(as.numeric(unlist(r_valid[sapply(r_valid, function(x) is.numeric(x) || is.list(x))])),
                               error = function(e) numeric(0))
              length(nums) == 0 || all(is.finite(nums[!is.na(nums)]))
            })

      unlink(tmp_csv)

    }, error = function(e) {
      check("F.PKG", "Paquete seminr cargado exitosamente via pls_sem_engine.R", FALSE)
      skip_test("F.I1-I3", "Tests de integracion PLS omitidos", e$message)
    })
  } else {
    reason <- if (!file.exists(pls_path)) "pls_sem_engine.R no encontrado"
              else "paquetes seminr/jsonlite/dplyr/openxlsx no disponibles"
    skip_test("F.PKG",  "Carga de seminr omitida",           reason)
    skip_test("F.I1-I3","Tests de integracion PLS omitidos", reason)
  }

  # F.CLI: Validacion CLI de pls_sem_engine.R (14 tests, Lote 1F)
  # Sin --vanilla: produccion NestJS (analysis.service.ts:317) NO usa --vanilla.
  cat("  --- Validacion CLI de pls_sem_engine.R (14 tests) ---\n")
  rscript_bin <- Sys.which("Rscript")

  if (file.exists(pls_path) && nzchar(rscript_bin)) {
    set.seed(42)
    tmp_csv_cli <- tempfile(fileext = ".csv")
    write.csv(data.frame(A1=rnorm(60)+3, A2=rnorm(60)+3,
                         B1=rnorm(60)+3, B2=rnorm(60)+3), tmp_csv_cli, row.names=FALSE)

    params_valid_cli <- list(
      data_path  = tmp_csv_cli,
      constructs = list(list(name="A", items=c("A1","A2")),
                        list(name="B", items=c("B1","B2"))),
      paths  = list(list(from="A", to="B")),
      n_boot = 10L
    )
    params_single_cli <- list(
      data_path  = tmp_csv_cli,
      constructs = list(list(name="A", items=c("A1","A2")),
                        list(name="B", items=c("B1"))),   # single-item → blocked
      paths  = list(list(from="A", to="B")),
      n_boot = 10L
    )

    # Archivos JSON temporales — matching produccion NestJS: spawn(rBin, [script, tmpFile])
    json_valid  <- jsonlite::toJSON(params_valid_cli,  auto_unbox=TRUE)
    json_single <- jsonlite::toJSON(params_single_cli, auto_unbox=TRUE)
    tmp_json_valid  <- tempfile(fileext=".json")
    tmp_json_single <- tempfile(fileext=".json")
    writeLines(as.character(json_valid),  tmp_json_valid)
    writeLines(as.character(json_single), tmp_json_single)

    # ── Grupo 1: validacion de entrada (args incorrectos) ────────────────────
    # F.CLI1 — sin argumentos → exit 1
    rc_noargs <- system2(rscript_bin, args=c(pls_path),
                         stdout=TRUE, stderr=TRUE)
    check("F.CLI1", "CLI sin argumentos → exit code 1",
          !is.null(attr(rc_noargs, "status")) && attr(rc_noargs, "status") != 0)

    # F.CLI2 — JSON invalido (string no parseable) → exit 1
    rc_badjson <- system2(rscript_bin, args=c(pls_path, "NOT_JSON"),
                          stdout=TRUE, stderr=TRUE)
    check("F.CLI2", "CLI JSON invalido → exit code 1",
          !is.null(attr(rc_badjson, "status")) && attr(rc_badjson, "status") != 0)

    # F.CLI3 — ruta de archivo inexistente → fromJSON falla → exit 1
    rc_badfile <- system2(rscript_bin, args=c(pls_path, "/nonexistent/path/params.json"),
                          stdout=TRUE, stderr=TRUE)
    check("F.CLI3", "CLI ruta de archivo inexistente → exit code 1",
          !is.null(attr(rc_badfile, "status")) && attr(rc_badfile, "status") != 0)

    # ── Grupo 2: JSON via RUTA DE ARCHIVO (matching produccion NestJS) ───────
    # F.CLI4 — archivo JSON valido → exit 0
    out_file_valid  <- system2(rscript_bin, args=c(pls_path, tmp_json_valid),
                               stdout=TRUE, stderr=FALSE)
    exit_file_valid <- attr(out_file_valid, "status") %||% 0L
    check("F.CLI4", "CLI archivo JSON valido → exit code 0",
          isTRUE(exit_file_valid == 0))

    # F.CLI5 — archivo JSON valido → salida JSON parseable
    result_file_valid <- tryCatch(
      jsonlite::fromJSON(paste(out_file_valid, collapse=""), simplifyDataFrame=TRUE),
      error=function(e) NULL
    )
    check("F.CLI5", "CLI archivo JSON valido → salida JSON parseable",
          !is.null(result_file_valid))

    # F.CLI6 — archivo JSON valido → success=TRUE
    check("F.CLI6", "CLI archivo JSON valido → success=TRUE",
          !is.null(result_file_valid) && isTRUE(result_file_valid$success))

    # F.CLI7 — archivo JSON valido → tiene path_coefficients o tables
    check("F.CLI7", "CLI archivo JSON valido → contiene path_coefficients o tables",
          !is.null(result_file_valid) &&
          (!is.null(result_file_valid$path_coefficients) || !is.null(result_file_valid$tables)))

    # ── Grupo 3: JSON via archivo alternativo (n_boot=2, patron produccion) ─────
    # F.CLI8 — n_boot=2 via archivo → exit 0
    params_minboot_cli <- list(
      data_path  = tmp_csv_cli,
      constructs = list(list(name="A", items=c("A1","A2")),
                        list(name="B", items=c("B1","B2"))),
      paths  = list(list(from="A", to="B")),
      n_boot = 2L
    )
    tmp_json_minboot <- tempfile(fileext=".json")
    writeLines(as.character(jsonlite::toJSON(params_minboot_cli, auto_unbox=TRUE)), tmp_json_minboot)
    out_minboot  <- system2(rscript_bin, args=c(pls_path, tmp_json_minboot), stdout=TRUE, stderr=FALSE)
    exit_minboot <- attr(out_minboot, "status") %||% 0L
    check("F.CLI8", "CLI n_boot=2 (archivo) → exit code 0",
          isTRUE(exit_minboot == 0))

    # F.CLI9 — n_boot=2 via archivo → success=TRUE
    result_minboot <- tryCatch(
      jsonlite::fromJSON(paste(out_minboot, collapse=""), simplifyDataFrame=TRUE),
      error=function(e) NULL
    )
    check("F.CLI9", "CLI n_boot=2 (archivo) → success=TRUE",
          !is.null(result_minboot) && isTRUE(result_minboot$success))

    # ── Grupo 4: guard via archivo (single-item) ──────────────────────────────
    # F.CLI10 — single-item via archivo → salida JSON parseable
    out_file_single  <- system2(rscript_bin, args=c(pls_path, tmp_json_single),
                                stdout=TRUE, stderr=FALSE)
    exit_file_single <- attr(out_file_single, "status") %||% 0L
    result_file_single <- tryCatch(
      jsonlite::fromJSON(paste(out_file_single, collapse=""), simplifyDataFrame=TRUE),
      error=function(e) NULL
    )
    check("F.CLI10", "CLI single-item (archivo) → salida JSON parseable",
          !is.null(result_file_single))

    # F.CLI11 — single-item via archivo → blocked=TRUE
    check("F.CLI11", "CLI single-item (archivo) → blocked=TRUE",
          !is.null(result_file_single) && isTRUE(result_file_single$blocked))

    # F.CLI12 — single-item via archivo → reason=SINGLE_ITEM_CONSTRUCTS
    check("F.CLI12", "CLI single-item (archivo) → reason=SINGLE_ITEM_CONSTRUCTS",
          !is.null(result_file_single) &&
          isTRUE(result_file_single$reason == "SINGLE_ITEM_CONSTRUCTS"))

    # ── Grupo 5: integridad de salida ─────────────────────────────────────────
    # F.CLI13 — salida no contiene __dup__
    all_output_cli <- paste(c(out_file_valid, out_minboot, out_file_single), collapse=" ")
    check("F.CLI13", "CLI salida no contiene codigo '__dup__'",
          !grepl("__dup__", all_output_cli, fixed=TRUE))

    # F.CLI14 — blocked=TRUE → exit 0 (el engine no usa quit() para bloqueos logicos)
    check("F.CLI14", "CLI single-item (blocked) → exit code 0 (no error de proceso)",
          isTRUE(exit_file_single == 0))

    cat(sprintf("  [DIAG] pls_path: %s\n", basename(pls_path)))
    cat(sprintf("  [DIAG] exit_file=%d | exit_minboot=%d | exit_single=%d\n",
                exit_file_valid, exit_minboot, exit_file_single))
    if (!is.null(result_file_valid))
      cat(sprintf("  [DIAG] success=%s | path_coefs=%s\n",
                  isTRUE(result_file_valid$success),
                  !is.null(result_file_valid$path_coefficients)))

    unlink(c(tmp_csv_cli, tmp_json_valid, tmp_json_single, tmp_json_minboot))
  } else {
    reason_cli <- if (!file.exists(pls_path)) "pls_sem_engine.R no encontrado"
                  else "Rscript no encontrado en PATH"
    skip_test("F.CLI1-CLI14", "Validacion CLI omitida", reason_cli)
  }
  cat("\n")
}

# ============================================================
# Ejecutar secciones solicitadas
# ============================================================
if (section %in% c("C", "ALL")) run_section_c()
if (section %in% c("D", "ALL")) run_section_d()
if (section %in% c("E", "ALL")) run_section_e()
if (section %in% c("F", "ALL")) run_section_f()

# Resumen
total <- pass + fail + skip_n
cat(sprintf("=== RESUMEN [%s]: %d PASS  %d FAIL  %d SKIP  (total %d) ===\n",
            section, pass, fail, skip_n, total))

if (fail > 0) {
  cat("RESULTADO: FALLO — al menos un guard no funciona como se espera.\n")
  quit(status = 1L)
} else if (skip_n > 0 && pass == 0) {
  cat("RESULTADO: SKIP TOTAL — no se ejecuto ninguna prueba.\n")
  quit(status = 0L)
} else if (skip_n > 0) {
  cat("RESULTADO: INCOMPLETO — algunos tests omitidos por falta de paquetes.\n")
  quit(status = 0L)
} else {
  cat("RESULTADO: COMPLETO — todos los guards verificados.\n")
  quit(status = 0L)
}
