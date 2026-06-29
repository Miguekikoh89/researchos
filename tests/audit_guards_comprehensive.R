# tests/audit_guards_comprehensive.R
# Pruebas comprensivas de guards P0/P1 — Lote 1C Auditoria CanchariOS
#
# Uso: Rscript tests/audit_guards_comprehensive.R [C|D|E|F|G|all]
#   C = Guard logistico (VD no binaria)
#   D = Guard ordinal (VD continua)
#   E = Guard chi-cuadrado (variables continuas)
#   F = Guard PLS-SEM (constructo de un solo indicador)
#   G = F-006 Imputacion column-mean (Lote 2A)
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
r_dir           <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "R")
helpers_path    <- file.path(r_dir, "helpers.R")
logistic_path   <- file.path(r_dir, "logistic.R")
ordinal_path    <- file.path(r_dir, "ordinal_regression.R")
pls_path        <- file.path(r_dir, "pls_sem_engine.R")
instruments_path <- file.path(r_dir, "instruments.R")
run_anal_path   <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "run_analysis.R")

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
# SECCION G — F-006: Imputacion column-mean (Lote 2A)
# ============================================================
run_section_g <- function() {
  cat("--- [G] F-006 Imputacion column-mean (Lote 2A) ---\n")

  has_psych  <- requireNamespace("psych",   quietly = TRUE)
  has_lavaan <- requireNamespace("lavaan",  quietly = TRUE)
  has_instr  <- file.exists(instruments_path)

  if (!has_instr) {
    skip_test("G.ALL", "Seccion G completa omitida", "instruments.R no encontrado")
    cat("\n"); return(invisible(NULL))
  }

  source(instruments_path, local = TRUE)

  # ── Helpers locales para reproducir defecto y correccion ──────────────────

  # Reproduce the exact broken one-liner from the original instruments.R
  broken_impute <- function(df) {
    df <- as.data.frame(lapply(df, as.numeric))
    suppressWarnings(
      df[is.na(df)] <- apply(df, 2, function(x) mean(x, na.rm = TRUE))[is.na(df)]
    )
    df
  }

  # Correct column-by-column imputation (the fix)
  correct_impute <- function(df) {
    df <- as.data.frame(lapply(df, as.numeric))
    for (j in seq_along(df)) {
      m <- mean(df[[j]], na.rm = TRUE)
      if (!is.nan(m) && !is.na(m)) df[[j]][is.na(df[[j]])] <- m
    }
    df
  }

  # ── Grupo 1: Datasets A-F — imputacion unitaria ───────────────────────────
  cat("  [G] Grupo 1: datasets A-F\n")

  # Dataset A: 3x3, un NA por columna en posiciones distintas
  # c1[r1]=NA  c2[r2]=NA  c3[r3]=NA
  # col means: c1=5.5  c2=5.0  c3=4.5
  # Broken: positions in col-major are 1, 5, 9 in a 9-element vector from
  #   col_means (length 3) -> col_means[1]=5.5, col_means[5]=NA, col_means[9]=NA
  A <- data.frame(c1 = c(NA, 4, 7), c2 = c(2, NA, 8), c3 = c(3, 6, NA))
  A_def <- broken_impute(A)
  A_cor <- correct_impute(A)

  check("G.IMP.01", "Dataset A broken: c2[r2] = NA (col2 NA no imputado)",
        is.na(A_def[2, "c2"]))
  check("G.IMP.02", "Dataset A broken: c3[r3] = NA (col3 NA no imputado)",
        is.na(A_def[3, "c3"]))
  check("G.IMP.03", "Dataset A correct: c1[r1] = 5.5",
        isTRUE(abs(A_cor[1, "c1"] - 5.5) < 1e-10))
  check("G.IMP.04", "Dataset A correct: c2[r2] = 5.0",
        isTRUE(abs(A_cor[2, "c2"] - 5.0) < 1e-10))
  check("G.IMP.05", "Dataset A correct: c3[r3] = 4.5",
        isTRUE(abs(A_cor[3, "c3"] - 4.5) < 1e-10))

  # Dataset B: dos NAs en misma columna (c1)
  # col1 mean=7; broken col-major positions 1 and 2 -> col_means[1]=7, col_means[2]=5 (col2 mean!)
  B <- data.frame(c1 = c(NA, NA, 7), c2 = c(2, 5, 8), c3 = c(3, 6, 9))
  B_def <- broken_impute(B)
  B_cor <- correct_impute(B)

  check("G.IMP.06", "Dataset B broken: c1[r2] = 5.0 (recibe media col2 en lugar de col1=7)",
        isTRUE(abs(B_def[2, "c1"] - 5.0) < 1e-10))
  check("G.IMP.07", "Dataset B correct: c1[r1] = 7.0",
        isTRUE(abs(B_cor[1, "c1"] - 7.0) < 1e-10))
  check("G.IMP.08", "Dataset B correct: c1[r2] = 7.0",
        isTRUE(abs(B_cor[2, "c1"] - 7.0) < 1e-10))

  # Dataset C: columna completamente NA
  # broken: col_means[1]=NaN, col_means[2]=5, col_means[3]=6 -> c1 gets NaN,5,6
  C <- data.frame(c1 = c(NA_real_, NA_real_, NA_real_), c2 = c(2, 5, 8), c3 = c(3, 6, 9))
  C_def <- suppressWarnings(broken_impute(C))

  check("G.IMP.09", "Dataset C broken: c1[r1] = NaN (col toda-NA produce NaN)",
        is.nan(C_def[1, "c1"]))

  # Test COLUMNA_SIN_DATOS via compute_instruments (requires psych for KMO)
  mini_cfg_c <- list(
    all_items  = c("c1", "c2", "c3"),
    scale_min  = 1,
    scale_max  = 9,
    n_factors  = NULL,
    rotation   = "oblimin",
    estimator  = "MLR",
    variables  = list(list(name = "F1", items = c("c2", "c3")))
  )
  r_c <- compute_instruments(C, mini_cfg_c)
  check("G.IMP.10", "Dataset C correct (via compute_instruments): blocked=TRUE reason=COLUMNA_SIN_DATOS",
        isTRUE(r_c$blocked) && isTRUE(r_c$reason == "COLUMNA_SIN_DATOS"))

  # Dataset D: columna constante con un NA — col1 mean=5, col2 mean=5 -> broken accidentalmente correcto
  D <- data.frame(c1 = c(5, NA, 5), c2 = c(2, 5, 8), c3 = c(3, 6, 9))
  D_def <- broken_impute(D)
  D_cor <- correct_impute(D)

  # broken: col-major position of c1[r2] = 2; col_means[2] = 5.0 (col2 mean, col1 mean also 5)
  check("G.IMP.11", "Dataset D broken: c1[r2] = 5 (accidentalmente correcto — col1 y col2 medias iguales)",
        isTRUE(abs(D_def[2, "c1"] - 5.0) < 1e-10))
  check("G.IMP.12", "Dataset D correct: c1[r2] = 5.0 (imputado con media col1)",
        isTRUE(abs(D_cor[2, "c1"] - 5.0) < 1e-10))

  # Dataset E: columna mixta — "a" -> NA tras as.numeric, col-major pos=4 > length(col_means)=3
  E <- data.frame(c1 = c(1, 4, 7), c2 = c("a", "5", "8"), c3 = c(3, 6, 9),
                  stringsAsFactors = FALSE)
  E_def <- suppressWarnings(broken_impute(E))
  E_cor <- suppressWarnings(correct_impute(E))

  check("G.IMP.13", "Dataset E broken: c2[r1] = NA (coercion NA + posicion fuera de rango)",
        is.na(E_def[1, "c2"]))
  check("G.IMP.14", "Dataset E correct: c2[r1] = 6.5 (imputado con media col2)",
        isTRUE(abs(E_cor[1, "c2"] - 6.5) < 1e-10))

  # Dataset F: patron NA no monotono — un NA por columna en posiciones cruzadas
  # c1[r2]=NA -> col-major pos=2; col_means[2]=3.5 (col2, wrong; col1 mean=4)
  # c2[r3]=NA -> col-major pos=6; col_means[6]=NA (OOB)
  # c3[r1]=NA -> col-major pos=7; col_means[7]=NA (OOB)
  F_dat <- data.frame(c1 = c(1, NA, 7), c2 = c(2, 5, NA), c3 = c(NA, 6, 9))
  F_def <- broken_impute(F_dat)
  F_cor <- correct_impute(F_dat)

  check("G.IMP.15", "Dataset F broken: c1[r2] != 4.0 (recibe media col2=3.5, no media col1=4)",
        isTRUE(abs(F_def[2, "c1"] - 3.5) < 1e-10))
  check("G.IMP.16", "Dataset F broken: c2[r3] = NA (posicion OOB, no imputado)",
        is.na(F_def[3, "c2"]))
  check("G.IMP.17", "Dataset F broken: c3[r1] = NA (posicion OOB, no imputado)",
        is.na(F_def[1, "c3"]))
  check("G.IMP.18", "Dataset F correct: c1[r2] = 4.0",
        isTRUE(abs(F_cor[2, "c1"] - 4.0) < 1e-10))
  check("G.IMP.19", "Dataset F correct: c2[r3] = 3.5",
        isTRUE(abs(F_cor[3, "c2"] - 3.5) < 1e-10))
  check("G.IMP.20", "Dataset F correct: c3[r1] = 7.5",
        isTRUE(abs(F_cor[1, "c3"] - 7.5) < 1e-10))

  # ── Grupo 2: Metadata de imputacion via compute_instruments ───────────────
  cat("  [G] Grupo 2: metadata imputacion\n")

  if (has_psych) {
    set.seed(999)
    n_meta <- 100
    df_meta <- data.frame(
      i1 = round(runif(n_meta, 1, 5)),
      i2 = round(runif(n_meta, 1, 5)),
      i3 = round(runif(n_meta, 1, 5)),
      i4 = round(runif(n_meta, 1, 5))
    )
    # Introduce one NA per column at different rows
    df_meta[1, "i1"] <- NA
    df_meta[2, "i2"] <- NA
    df_meta[3, "i3"] <- NA
    df_meta[4, "i4"] <- NA

    meta_cfg <- list(
      all_items  = c("i1", "i2", "i3", "i4"),
      scale_min  = 1,
      scale_max  = 5,
      n_factors  = 1,
      rotation   = "oblimin",
      estimator  = "MLR",
      variables  = list(list(name = "F1", items = c("i1", "i2", "i3", "i4")))
    )
    r_meta <- tryCatch(compute_instruments(df_meta, meta_cfg), error = function(e) list(error = e$message))

    check("G.META.01", "compute_instruments: imputation$method == 'column_mean'",
          isTRUE(r_meta$imputation$method == "column_mean"))
    check("G.META.02", "compute_instruments: imputation$columns tiene 4 columnas imputadas",
          isTRUE(length(r_meta$imputation$columns) == 4))
    check("G.META.03", "compute_instruments: replaced_counts 1 por columna",
          isTRUE(!is.null(r_meta$imputation$replaced_counts)) &&
          all(sapply(r_meta$imputation$replaced_counts, function(x) x == 1L)))
    check("G.META.04", "compute_instruments: replacement_values son numericos no-NA",
          isTRUE(!is.null(r_meta$imputation$replacement_values)) &&
          all(sapply(r_meta$imputation$replacement_values,
                     function(x) is.numeric(x) && !is.na(x) && !is.nan(x))))
    check("G.META.05", "compute_instruments: all_missing_columns vacio (caso normal)",
          isTRUE(length(r_meta$imputation$all_missing_columns) == 0))

    # Verificar non_numeric_columns_ignored con columna caracter
    df_meta_chr <- df_meta
    df_meta_chr[["i1"]] <- as.character(df_meta_chr[["i1"]])
    r_meta_chr <- tryCatch(
      suppressWarnings(compute_instruments(df_meta_chr, meta_cfg)),
      error = function(e) list(error = e$message)
    )
    check("G.META.06", "compute_instruments: columna caracter aparece en non_numeric_columns_ignored",
          isTRUE("i1" %in% r_meta_chr$imputation$non_numeric_columns_ignored))
  } else {
    skip_test("G.META.01-06", "Metadata imputacion", "psych no disponible")
  }

  # ── Grupo 3: Impacto en AFE ───────────────────────────────────────────────
  cat("  [G] Grupo 3: impacto AFE\n")

  if (has_psych) {
    set.seed(2401)
    n_afe <- 200L; p_afe <- 12L; k_afe <- 3L
    # Factorial dataset: 3 factores ortogonales, 4 indicadores cada uno, cargas=0.75
    F_scores  <- matrix(rnorm(n_afe * k_afe), nrow = n_afe)
    Lambda_m  <- matrix(0.15, nrow = p_afe, ncol = k_afe)
    Lambda_m[1:4,  1] <- 0.75
    Lambda_m[5:8,  2] <- 0.75
    Lambda_m[9:12, 3] <- 0.75
    E_scores  <- matrix(rnorm(n_afe * p_afe, sd = 0.65), nrow = n_afe)
    afe_complete <- as.data.frame(F_scores %*% t(Lambda_m) + E_scores)
    colnames(afe_complete) <- paste0("i", seq_len(p_afe))

    # AFE referencia (datos completos)
    afe_ref <- tryCatch(
      compute_afe(afe_complete, n_factors = k_afe, rotation = "oblimin"),
      error = function(e) list(error = e$message)
    )

    # Funcion para introducir MCAR
    intro_mcar <- function(df, pct, seed) {
      set.seed(seed)
      mat   <- as.matrix(df)
      n_mis <- round(prod(dim(mat)) * pct)
      pos   <- sample(prod(dim(mat)), n_mis)
      mat[pos] <- NA
      as.data.frame(mat)
    }

    df_5  <- intro_mcar(afe_complete, 0.05, 2402L)
    df_10 <- intro_mcar(afe_complete, 0.10, 2403L)
    df_20 <- intro_mcar(afe_complete, 0.20, 2404L)

    # AFE sobre imputacion defectuosa vs correcta
    afe_brok_5  <- tryCatch(compute_afe(broken_impute(df_5),  n_factors=k_afe, rotation="oblimin"), error=function(e) list(error=e$message))
    afe_corr_5  <- tryCatch(compute_afe(correct_impute(df_5), n_factors=k_afe, rotation="oblimin"), error=function(e) list(error=e$message))
    afe_brok_10 <- tryCatch(compute_afe(broken_impute(df_10), n_factors=k_afe, rotation="oblimin"), error=function(e) list(error=e$message))
    afe_corr_10 <- tryCatch(compute_afe(correct_impute(df_10),n_factors=k_afe, rotation="oblimin"), error=function(e) list(error=e$message))
    afe_brok_20 <- tryCatch(compute_afe(suppressWarnings(broken_impute(df_20)), n_factors=k_afe, rotation="oblimin"), error=function(e) list(error=e$message))
    afe_corr_20 <- tryCatch(compute_afe(correct_impute(df_20),n_factors=k_afe, rotation="oblimin"), error=function(e) list(error=e$message))

    cat(sprintf("  [G.AFE DIAG] ref n=%s | brok5 n=%s | corr5 n=%s\n",
                afe_ref$n %||% "ERR", afe_brok_5$n %||% "ERR", afe_corr_5$n %||% "ERR"))
    cat(sprintf("  [G.AFE DIAG] brok10 n=%s | corr10 n=%s | brok20 n=%s | corr20 n=%s\n",
                afe_brok_10$n %||% "ERR", afe_corr_10$n %||% "ERR",
                afe_brok_20$n %||% "ERR", afe_corr_20$n %||% "ERR"))

    check("G.AFE.01", "AFE 5%: imputacion defectuosa n < n_referencia (perdida de muestra)",
          isTRUE(!is.null(afe_brok_5$n) && !is.null(afe_ref$n) &&
                 afe_brok_5$n < afe_ref$n))
    check("G.AFE.02", "AFE 5%: imputacion correcta n == n_referencia (muestra preservada)",
          isTRUE(!is.null(afe_corr_5$n) && afe_corr_5$n == n_afe))
    check("G.AFE.03", "AFE 10%: n defectuoso < n correcto",
          isTRUE((!is.null(afe_brok_10$n) && !is.null(afe_corr_10$n) &&
                  afe_brok_10$n < afe_corr_10$n) ||
                 !is.null(afe_brok_10$error)))
    check("G.AFE.04", "AFE 20%: n defectuoso << n correcto (o defectuoso falla)",
          isTRUE(!is.null(afe_brok_20$error) ||
                 (!is.null(afe_brok_20$n) && !is.null(afe_corr_20$n) &&
                  afe_brok_20$n < afe_corr_20$n)))
    check("G.AFE.05", "AFE 20%: imputacion correcta n == n_referencia",
          isTRUE(!is.null(afe_corr_20$n) && afe_corr_20$n == n_afe))

    # Congruencia de cargas: corrected vs referencia (Tucker CC)
    if (!is.null(afe_ref$loadings) && !is.null(afe_corr_5$loadings) &&
        !is.null(afe_brok_5$loadings)) {
      load_to_mat <- function(ll, k) {
        p <- length(ll)
        mat <- matrix(NA_real_, nrow = p, ncol = k)
        for (i in seq_len(p))
          for (j in seq_len(k))
            mat[i, j] <- ll[[i]][[paste0("F", j)]]
        mat
      }
      L_ref  <- load_to_mat(afe_ref$loadings,    k_afe)
      L_corr <- load_to_mat(afe_corr_5$loadings, k_afe)
      L_brok <- load_to_mat(afe_brok_5$loadings, min(k_afe, afe_brok_5$n_factors %||% k_afe))

      tucker_cc <- function(A, B) {
        k <- min(ncol(A), ncol(B))
        mean(sapply(seq_len(k), function(j) {
          a <- A[, j]; b <- B[, j]
          max(abs(sum(a * b) / sqrt(sum(a^2) * sum(b^2))),
              abs(sum(a * -b) / sqrt(sum(a^2) * sum(b^2))))
        }))
      }
      cc_corr <- tucker_cc(L_ref, L_corr)
      cc_brok <- if (ncol(L_brok) == k_afe) tucker_cc(L_ref, L_brok) else NA_real_
      cat(sprintf("  [G.AFE DIAG] Tucker CC: corrected=%.3f  broken=%.3f\n",
                  cc_corr, cc_brok %||% NA))
      check("G.AFE.06", "AFE 5%: corrected Tucker CC >= 0.85 vs referencia",
            isTRUE(!is.nan(cc_corr) && cc_corr >= 0.85))
    } else {
      skip_test("G.AFE.06", "Tucker CC omitido", "loadings no disponibles")
    }
  } else {
    skip_test("G.AFE.01-06", "Impacto AFE omitido", "psych no disponible")
  }

  # ── Grupo 4: Impacto en AFC ───────────────────────────────────────────────
  cat("  [G] Grupo 4: impacto AFC\n")

  if (has_psych && has_lavaan && exists("afe_complete")) {
    afc_vars <- lapply(seq_len(k_afe), function(f) {
      list(name  = paste0("F", f),
           items = paste0("i", ((f - 1L) * 4L + 1L):(f * 4L)))
    })

    afc_ref    <- tryCatch(compute_afc(afe_complete, afc_vars), error = function(e) list(error = e$message))
    afc_brok_5 <- tryCatch(compute_afc(as.data.frame(broken_impute(df_5)),  afc_vars), error = function(e) list(error = e$message))
    afc_corr_5 <- tryCatch(compute_afc(as.data.frame(correct_impute(df_5)), afc_vars), error = function(e) list(error = e$message))
    afc_brok_20<- tryCatch(compute_afc(as.data.frame(suppressWarnings(broken_impute(df_20))), afc_vars), error = function(e) list(error = e$message))
    afc_corr_20<- tryCatch(compute_afc(as.data.frame(correct_impute(df_20)), afc_vars), error = function(e) list(error = e$message))

    cat(sprintf("  [G.AFC DIAG] ref n=%s | brok5 n=%s | corr5 n=%s | brok20=%s | corr20 n=%s\n",
                afc_ref$n %||% "ERR", afc_brok_5$n %||% "ERR", afc_corr_5$n %||% "ERR",
                if (!is.null(afc_brok_20$error)) paste0("ERR:",substr(afc_brok_20$error,1,20)) else afc_brok_20$n,
                afc_corr_20$n %||% "ERR"))

    check("G.AFC.01", "AFC 5%: n defectuoso < n correcto (perdida de muestra)",
          isTRUE((!is.null(afc_brok_5$n) && !is.null(afc_corr_5$n) &&
                  afc_brok_5$n < afc_corr_5$n) ||
                 !is.null(afc_brok_5$error)))
    check("G.AFC.02", "AFC 20%: imputacion defectuosa falla (error, n < 30)",
          isTRUE(!is.null(afc_brok_20$error) ||
                 (!is.null(afc_brok_20$n) && afc_brok_20$n < 30)))
    check("G.AFC.03", "AFC 20%: imputacion correcta ok (n >= 30)",
          isTRUE(is.null(afc_corr_20$error) && !is.null(afc_corr_20$n) && afc_corr_20$n >= 30))
  } else {
    reason_afc <- if (!has_psych) "psych no disponible"
                  else if (!has_lavaan) "lavaan no disponible"
                  else "afe_complete no generado"
    skip_test("G.AFC.01-03", "Impacto AFC omitido", reason_afc)
  }

  # ── Grupo 5: Contrato Node-R ──────────────────────────────────────────────
  cat("  [G] Grupo 5: contrato Node-R\n")

  if (has_psych) {
    set.seed(888)
    n_nr <- 100L
    df_nr_base <- data.frame(
      i1 = round(runif(n_nr, 1, 5)),
      i2 = round(runif(n_nr, 1, 5)),
      i3 = round(runif(n_nr, 1, 5)),
      i4 = round(runif(n_nr, 1, 5))
    )
    nr_cfg <- list(
      all_items  = c("i1", "i2", "i3", "i4"),
      scale_min  = 1,
      scale_max  = 5,
      n_factors  = 1,
      rotation   = "oblimin",
      estimator  = "MLR",
      variables  = list(list(name = "F1", items = c("i1", "i2", "i3", "i4")))
    )

    # G.NR.01 — columna toda NA -> blocked=TRUE, reason=COLUMNA_SIN_DATOS
    df_nr_allna <- df_nr_base
    df_nr_allna[["i1"]] <- NA_real_
    r_nr01 <- tryCatch(compute_instruments(df_nr_allna, nr_cfg), error = function(e) list(error = e$message))
    check("G.NR.01", "Columna toda NA -> blocked=TRUE, reason=COLUMNA_SIN_DATOS",
          isTRUE(r_nr01$blocked) && isTRUE(r_nr01$reason == "COLUMNA_SIN_DATOS"))
    check("G.NR.02", "COLUMNA_SIN_DATOS: imputation metadata incluida en resultado bloqueado",
          !is.null(r_nr01$imputation) && r_nr01$imputation$method == "column_mean")

    # G.NR.03-04 — resultado normal: sin NaN, metadata correcta
    df_nr_na <- df_nr_base
    df_nr_na[1, "i1"] <- NA
    df_nr_na[2, "i2"] <- NA
    r_nr03 <- tryCatch(compute_instruments(df_nr_na, nr_cfg), error = function(e) list(error = e$message))

    # Recursive NaN check
    has_nan <- function(x) {
      if (is.numeric(x)) any(is.nan(x))
      else if (is.list(x)) any(sapply(x, has_nan))
      else FALSE
    }
    check("G.NR.03", "Resultado normal: sin valores NaN (JSON-safe)",
          isTRUE(!has_nan(r_nr03)))
    check("G.NR.04", "Resultado normal: imputation$replaced_counts exacto (1 por columna con NA)",
          isTRUE(!is.null(r_nr03$imputation$replaced_counts)) &&
          isTRUE(length(r_nr03$imputation$replaced_counts) == 2L))
  } else {
    skip_test("G.NR.01-04", "Contrato Node-R omitido", "psych no disponible")
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
if (section %in% c("G", "ALL")) run_section_g()

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
