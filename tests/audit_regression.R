#!/usr/bin/env Rscript
# tests/audit_regression.R
# FASE 3B — Sección J: Regresión lineal simple, múltiple, jerárquica, supuestos
#
# Grupos: J.SIMPLE (8), J.MULTI (8), J.HIER (9), J.ASSUMP (9), J.CONTRACT (11)
# Total: 45 tests  (umbral mínimo: 45)
#
# Exit code: 0 = todos PASS, 1 = al menos un FAIL
# ============================================================

pass <- 0L; fail <- 0L

check <- function(id, desc, cond) {
  label <- if (isTRUE(cond)) "PASS" else "FAIL"
  cat(sprintf("  [%s] %s: %s\n", label, id, desc))
  if (isTRUE(cond)) pass <<- pass + 1L else fail <<- fail + 1L
  invisible(isTRUE(cond))
}

.script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    f <- sub("--file=", "", grep("--file=", commandArgs(trailingOnly=FALSE), value=TRUE))
    if (length(f) > 0) dirname(normalizePath(f)) else getwd()
  }
)
r_dir        <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "R")
run_anal_path <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "run_analysis.R")

source(file.path(r_dir, "helpers.R"))
source(file.path(r_dir, "regression.R"))
source(file.path(r_dir, "hierarchical_regression.R"))

cat("=== AUDIT FASE 3B — SECCIÓN J: REGRESIÓN LINEAL ===\n")
cat(sprintf("    R version: %s\n\n", R.version.string))

# ──────────────────────────────────────────────────────────────────────────────
# Datos para regresión simple (1 predictor)
# ──────────────────────────────────────────────────────────────────────────────
set.seed(42)
n_sim <- 100
x_sim <- rnorm(n_sim)
y_sim <- 3 + 2.5 * x_sim + rnorm(n_sim, 0, 1)

X_sim <- data.frame(x1 = x_sim)
ref_lm_sim <- lm(y_sim ~ x_sim)
ref_sm_sim <- summary(ref_lm_sim)

res_simple <- compute_regression(y_sim, X_sim, var_names="x1", alpha=0.05)

# ──────────────────────────────────────────────────────────────────────────────
# J.SIMPLE — Regresión lineal simple
# ──────────────────────────────────────────────────────────────────────────────
cat("--- [J.SIMPLE] Regresión lineal simple (k=1) ---\n")

check("J.SIMPLE.01", "test_type == 'regresion_simple' para 1 predictor",
      identical(res_simple$test_type, "regresion_simple"))

check("J.SIMPLE.02", "R2 coincide con lm() r.squared redondeado a 3dp",
      abs(res_simple$R2 - round(ref_sm_sim$r.squared, 3)) < 1e-12)

check("J.SIMPLE.03", "F coincide con lm() fstatistic redondeado a 3dp",
      abs(res_simple$F - round(ref_sm_sim$fstatistic[1], 3)) < 1e-12)

ref_p_sim <- pf(ref_sm_sim$fstatistic[1], ref_sm_sim$fstatistic[2], ref_sm_sim$fstatistic[3], lower.tail=FALSE)
check("J.SIMPLE.04", "p coincide con pf(F, df1, df2) redondeado a 4dp",
      abs(res_simple$p - round(ref_p_sim, 4)) < 1e-12)

ref_coefs_sim <- coef(ref_lm_sim)
intercept_row <- Filter(function(c) c$term == "(Intercept)", res_simple$coefficients)[[1]]
x1_row        <- Filter(function(c) c$term == "x1",          res_simple$coefficients)[[1]]

check("J.SIMPLE.05", "B (intercepto) coincide con lm() redondeado a 3dp",
      abs(intercept_row$B - round(ref_coefs_sim["(Intercept)"], 3)) < 1e-12)

check("J.SIMPLE.06", "B (pendiente x1) coincide con lm() redondeado a 3dp",
      abs(x1_row$B - round(ref_coefs_sim["x_sim"], 3)) < 1e-12)

check("J.SIMPLE.07", "n coincide con length(y) completo (sin NA)",
      res_simple$n == n_sim)

check("J.SIMPLE.08", "SE_est coincide con lm() sigma redondeado a 3dp",
      abs(res_simple$SE_est - round(ref_sm_sim$sigma, 3)) < 1e-12)

# ──────────────────────────────────────────────────────────────────────────────
# Datos para regresión múltiple (2 predictores correlacionados)
# ──────────────────────────────────────────────────────────────────────────────
set.seed(7)
n_mul <- 120
x1_mul <- rnorm(n_mul)
x2_mul <- 0.6 * x1_mul + rnorm(n_mul, 0, 0.8)   # correlación ~0.6
y_mul  <- 2 + 1.5*x1_mul + 0.8*x2_mul + rnorm(n_mul, 0, 1)
X_mul  <- data.frame(x1=x1_mul, x2=x2_mul)
ref_lm_mul <- lm(y_mul ~ x1_mul + x2_mul)
ref_sm_mul <- summary(ref_lm_mul)

res_multi <- compute_regression(y_mul, X_mul, var_names=c("x1","x2"), alpha=0.05)

# ──────────────────────────────────────────────────────────────────────────────
# J.MULTI — Regresión múltiple
# ──────────────────────────────────────────────────────────────────────────────
cat("--- [J.MULTI] Regresión múltiple (k=2) ---\n")

check("J.MULTI.01", "test_type == 'regresion_multiple' para 2 predictores",
      identical(res_multi$test_type, "regresion_multiple"))

check("J.MULTI.02", "R2_adj coincide con lm() adj.r.squared redondeado a 3dp",
      abs(res_multi$R2_adj - round(ref_sm_mul$adj.r.squared, 3)) < 1e-12)

check("J.MULTI.03", "vif no es NULL para k > 1",
      !is.null(res_multi$vif) && length(res_multi$vif) == 2)

# Con x1 y x2 correlacionados (r~0.6) el VIF debe ser > 1
vif_x1 <- Filter(function(v) v$term == "x1", res_multi$vif)[[1]]$vif
check("J.MULTI.04", "VIF > 1 para predictores correlacionados",
      vif_x1 > 1)

# Verificar fórmula VIF = 1/(1-R2_xj~resto)
r2_x1_on_x2 <- summary(lm(x1_mul ~ x2_mul))$r.squared
vif_x1_ref   <- round(1/(1-r2_x1_on_x2), 3)
check("J.MULTI.05", "VIF x1 = 1/(1-R2_x1~x2) (fórmula custom, no car::vif)",
      abs(vif_x1 - vif_x1_ref) < 1e-12)

x2_row_multi <- Filter(function(c) c$term == "x2", res_multi$coefficients)[[1]]
check("J.MULTI.06", "beta (estandarizado) no es NA para predictores",
      !is.null(x2_row_multi$beta) && !is.na(x2_row_multi$beta))

check("J.MULTI.07", "coeficientes tiene k+1 elementos (intercepto + k predictores)",
      length(res_multi$coefficients) == 3)

res_simple_vif <- compute_regression(y_sim, X_sim, var_names="x1")
check("J.MULTI.08", "vif es NULL para regresión simple (k=1)",
      is.null(res_simple_vif$vif))

# ──────────────────────────────────────────────────────────────────────────────
# Datos para regresión jerárquica (2 bloques)
# ──────────────────────────────────────────────────────────────────────────────
set.seed(13)
n_hier <- 100
x_b1 <- rnorm(n_hier)
x_b2 <- rnorm(n_hier)
y_hier <- 1 + 2*x_b1 + 1.5*x_b2 + rnorm(n_hier, 0, 1)

df_hier <- data.frame(y_var=y_hier, pred1=x_b1, pred2=x_b2)

blocks_hier <- list(
  list(name="Bloque1", items=list("pred1")),
  list(name="Bloque2", items=list("pred2"))
)
res_hier <- run_hierarchical_regression(df_hier, blocks_hier, var_b_items="y_var", var_b_name="Y")

ref_b1 <- lm(y_hier ~ x_b1); sm_b1 <- summary(ref_b1)
ref_b2 <- lm(y_hier ~ x_b1 + x_b2); sm_b2 <- summary(ref_b2)

# ──────────────────────────────────────────────────────────────────────────────
# J.HIER — Regresión jerárquica
# ──────────────────────────────────────────────────────────────────────────────
cat("--- [J.HIER] Regresión jerárquica ---\n")

check("J.HIER.01", "run_hierarchical_regression() retorna lista con $blocks",
      is.list(res_hier) && is.null(res_hier$error) && is.list(res_hier$blocks))

check("J.HIER.02", "blocks tiene 2 elementos para 2 bloques",
      length(res_hier$blocks) == 2)

check("J.HIER.03", "R2 bloque 1 coincide con lm() r.squared redondeado a 3dp",
      abs(res_hier$blocks[[1]]$r2 - round(sm_b1$r.squared, 3)) < 1e-12)

check("J.HIER.04", "delta_r2 bloque 2 = R2_b2 - R2_b1 redondeado a 3dp",
      {
        expected_delta <- round(sm_b2$r.squared - sm_b1$r.squared, 3)
        abs(res_hier$blocks[[2]]$delta_r2 - expected_delta) < 1e-12
      })

check("J.HIER.05", "f_change no es NA para bloque 2",
      !is.na(res_hier$blocks[[2]]$f_change))

check("J.HIER.06", "df1_change bloque 2 = predictores adicionales (1)",
      res_hier$blocks[[2]]$df1_change == 1)

check("J.HIER.07", "df2_change bloque 2 = n_total - k_curr - 1",
      {
        n_total_hier <- nrow(df_hier); k_curr_hier <- 2
        expected_df2 <- round(n_total_hier - k_curr_hier - 1, 1)
        abs(res_hier$blocks[[2]]$df2_change - expected_df2) < 1e-12
      })

check("J.HIER.08", "p_change bloque 1 coincide con p del modelo F",
      {
        p_b1_ref <- pf(sm_b1$fstatistic[1], sm_b1$fstatistic[2], sm_b1$fstatistic[3], lower.tail=FALSE)
        abs(res_hier$blocks[[1]]$p_change - round(p_b1_ref, 4)) < 1e-12
      })

check("J.HIER.09", "final_r2 coincide con R2 del bloque final",
      abs(res_hier$final_r2 - res_hier$blocks[[length(res_hier$blocks)]]$r2) < 1e-12)

# ──────────────────────────────────────────────────────────────────────────────
# J.ASSUMP — Supuestos de regresión
# ──────────────────────────────────────────────────────────────────────────────
cat("--- [J.ASSUMP] Supuestos del modelo ---\n")

res_assump <- compute_regression(y_sim, X_sim, var_names="x1", check_assumptions="yes")

check("J.ASSUMP.01", "assumptions$normality_residuals tiene W y p",
      is.list(res_assump$assumptions) &&
        all(c("W","p") %in% names(res_assump$assumptions$normality_residuals)))

# Para datos generados con errores normales, DW debe estar en [1.5, 2.5]
check("J.ASSUMP.02", "DW en [1.5, 2.5] para datos iid (sin autocorrelación)",
      {
        dw_val <- res_assump$assumptions$independence$dw
        !is.null(dw_val) && dw_val >= 1.5 && dw_val <= 2.5
      })

check("J.ASSUMP.03", "assumptions$homoscedasticity tiene statistic y p",
      all(c("statistic","p") %in% names(res_assump$assumptions$homoscedasticity)))

check("J.ASSUMP.04", "assumptions$influential_cases tiene n_outliers",
      "n_outliers" %in% names(res_assump$assumptions$influential_cases))

check("J.ASSUMP.05", "assumptions$model_specification tiene F y p",
      all(c("F","p") %in% names(res_assump$assumptions$model_specification)))

# Cook's threshold = 4/n por defecto
check("J.ASSUMP.06", "Cook's threshold = 4/n cuando no especificado",
      abs(res_assump$assumptions$influential_cases$threshold - 4/n_sim) < 1e-10)

# Verificar fórmula DW = sum(diff(e)^2)/sum(e^2)
ref_model_sim  <- lm(y_sim ~ x_sim)
resids_sim     <- residuals(ref_model_sim)
dw_ref         <- round(sum(diff(resids_sim)^2) / sum(resids_sim^2), 3)
check("J.ASSUMP.07", "DW = sum(diff(resid)^2)/sum(resid^2)",
      abs(res_assump$assumptions$independence$dw - dw_ref) < 1e-12)

# Breusch-Pagan custom: chi2 = n * R2_resid2~fitted
res2_ref <- resids_sim^2
fitted_ref <- fitted(ref_model_sim)
bp_r2 <- summary(lm(res2_ref ~ fitted_ref))$r.squared
chi2_ref <- round(n_sim * bp_r2, 3)
check("J.ASSUMP.08", "Breusch-Pagan custom: chi2 = n*R2 (no lmtest::bptest)",
      abs(res_assump$assumptions$homoscedasticity$statistic - chi2_ref) < 1e-12)

res_no_assump <- compute_regression(y_sim, X_sim, var_names="x1", check_assumptions="no")
check("J.ASSUMP.09", "assumptions es NULL cuando check_assumptions='no'",
      is.null(res_no_assump$assumptions))

# ──────────────────────────────────────────────────────────────────────────────
# J.CONTRACT — Contratos y casos borde
# ──────────────────────────────────────────────────────────────────────────────
cat("--- [J.CONTRACT] Contratos y routing ---\n")

check("J.CONTRACT.01", "compute_regression() con n < k+3 retorna $error",
      !is.null(compute_regression(c(1,2,3), data.frame(x=c(1,2,3)))$error))

check("J.CONTRACT.02", "NA en y son eliminados antes del ajuste",
      {
        y_na <- y_sim; y_na[c(1,2,3)] <- NA
        res_na <- compute_regression(y_na, X_sim, var_names="x1")
        is.null(res_na$error) && res_na$n == (n_sim - 3)
      })

check("J.CONTRACT.03", "method='stepwise' devuelve modelo válido",
      {
        res_step <- compute_regression(y_mul, X_mul, var_names=c("x1","x2"), method="stepwise")
        is.null(res_step$error) && !is.null(res_step$R2)
      })

check("J.CONTRACT.04", "run_hierarchical_regression() con blocks=NULL retorna $error",
      !is.null(run_hierarchical_regression(df_hier, NULL, "y_var", "Y")$error))

# Verificar que run_analysis.R tiene return() en bloque regresion_jerarquica
src_lines_ra <- readLines(run_anal_path)
src_str_ra   <- paste(src_lines_ra, collapse="\n")

check("J.CONTRACT.05", "run_analysis.R: regresion_jerarquica tiene return(result) propio",
      {
        hier_idx <- which(grepl('analysis_category == "regresion_jerarquica"', src_lines_ra))[1]
        ret_idx  <- which(grepl("return\\(result\\)", src_lines_ra) & seq_along(src_lines_ra) > hier_idx)[1]
        # El return debe estar dentro de las 30 líneas siguientes al bloque
        !is.na(hier_idx) && !is.na(ret_idx) && (ret_idx - hier_idx) <= 30
      })

check("J.CONTRACT.06", "run_analysis.R: ancova tiene return(result) propio",
      {
        anc_idx <- which(grepl('analysis_category == "ancova"', src_lines_ra))[1]
        ret_idx  <- which(grepl("return\\(result\\)", src_lines_ra) & seq_along(src_lines_ra) > anc_idx)[1]
        !is.na(anc_idx) && !is.na(ret_idx) && (ret_idx - anc_idx) <= 35
      })

check("J.CONTRACT.07", "handle_outliers='remove' elimina outliers influyentes",
      {
        set.seed(1)
        y_out <- c(rnorm(95), 100)   # outlier extremo
        X_out <- data.frame(x=c(rnorm(95), 0))
        res_out <- compute_regression(y_out, X_out, var_names="x", handle_outliers="remove")
        is.null(res_out$error) && res_out$outliers_removed >= 1
      })

# VIF interpretation: OK cuando vif < threshold
check("J.CONTRACT.08", "VIF interpretation 'OK' cuando vif < threshold (default 5)",
      {
        v <- interpret_vif_dyn(2.5, threshold=5)
        identical(v, "OK")
      })

# VIF interpretation: moderada cuando threshold <= vif < 2*threshold
check("J.CONTRACT.09", "VIF interpretation 'Multicolinealidad moderada' cuando vif >= 5",
      {
        v <- interpret_vif_dyn(7, threshold=5)
        identical(v, "Multicolinealidad moderada")
      })

# R = sqrt(R2)
check("J.CONTRACT.10", "R = sqrt(R2) redondeado a 3dp",
      abs(res_simple$R - round(sqrt(res_simple$R2), 3)) < 1e-12)

# interpret_r2 umbrales Cohen: grande >= 0.26, mediano >= 0.13, pequeño >= 0.02
check("J.CONTRACT.11", "interpret_r2() umbrales: grande>=0.26, mediano>=0.13, pequeno>=0.02",
      identical(interpret_r2(0.27), "grande") &&
      identical(interpret_r2(0.14), "mediano") &&
      identical(interpret_r2(0.03), "pequeno") &&
      identical(interpret_r2(0.01), "trivial"))

# ──────────────────────────────────────────────────────────────────────────────
# Resumen final
# ──────────────────────────────────────────────────────────────────────────────
total <- pass + fail
cat(sprintf("\nRESULTADO SECCIÓN J: %d PASS / %d FAIL / %d TOTAL\n", pass, fail, total))

if (fail > 0) {
  cat("SECCIÓN J: FALLO — se detectaron tests fallidos.\n")
  quit(status = 1L)
}
cat("SECCIÓN J: COMPLETO — todos los tests pasaron.\n")
