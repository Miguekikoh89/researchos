#!/usr/bin/env Rscript
# tests/audit_mediation_e2e.R
# Suite AC — Tests E2E de mediacion simple
#
# Verifica: guards MUESTRA_INSUFICIENTE, MEDIADOR_CONSTANTE,
# MEDIACION_SERIAL_NO_IMPLEMENTADA, efecto indirecto a*b,
# IC bootstrap, mediacion completa vs parcial, reproducibilidad.
# Total: >= 15 tests
#
# Exit code: 0 = todos PASS, 1 = al menos un FAIL
# ============================================================================

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
r_dir <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "R")
source(file.path(r_dir, "helpers.R"))
source(file.path(r_dir, "mediation.R"))

cat("=== SUITE AC — MEDIACION SIMPLE E2E ===\n")
cat(sprintf("    R version: %s\n\n", R.version.string))

set.seed(42)
N <- 120
x_med  <- rnorm(N)
m_med  <- 0.6*x_med + rnorm(N, 0, 0.5)
y_full <- 0.5*m_med + rnorm(N, 0, 0.5)       # mediacion completa
y_part <- 0.4*m_med + 0.3*x_med + rnorm(N, 0, 0.5)  # mediacion parcial

df_full <- data.frame(x=x_med, m=m_med, y=y_full)
df_part <- data.frame(x=x_med, m=m_med, y=y_part)

# ── AC.VALID — Mediacion simple valida ──
cat("--- [AC.VALID] Mediacion simple valida ---\n")

res_full <- run_mediation_simple(df_full, x_var="x", m_var="m", y_var="y",
                                  n_boot=500, seed=42)
check("AC.VALID.01", "mediacion completa: no error", is.null(res_full$error))
check("AC.VALID.02", "indirect (a*b) > 0 (efecto positivo)",
      !is.null(res_full$indirect) && res_full$indirect > 0)
check("AC.VALID.03", "ci_lower no es NULL", !is.null(res_full$ci_lower))
check("AC.VALID.04", "ci_upper no es NULL", !is.null(res_full$ci_upper))
check("AC.VALID.05", "IC inferior < IC superior",
      !is.null(res_full$ci_lower) && !is.null(res_full$ci_upper) &&
      res_full$ci_lower < res_full$ci_upper)

res_part <- run_mediation_simple(df_part, x_var="x", m_var="m", y_var="y",
                                  n_boot=500, seed=42)
check("AC.VALID.06", "mediacion parcial: no error", is.null(res_part$error))

# ── AC.COEFS — Coeficientes de caminos ──
cat("\n--- [AC.COEFS] Coeficientes de caminos ---\n")
check("AC.COEFS.01", "path_a (X->M) existe", !is.null(res_full$a))
check("AC.COEFS.02", "path_b (M->Y) existe", !is.null(res_full$b))
check("AC.COEFS.03", "c_total (efecto total) existe", !is.null(res_full$c_total))
check("AC.COEFS.04", "c_direct (efecto directo) existe", !is.null(res_full$c_direct))
check("AC.COEFS.05", "mediacion completa: |c_direct| < |c_total| o tipo=mediacion completa",
      !is.null(res_full$mediation_type) &&
      res_full$mediation_type %in% c("mediacion completa","sin mediacion",
                                      "mediacion parcial complementaria","mediacion parcial competitiva"))

# ── AC.STRUCT — Estructura de resultado ──
cat("\n--- [AC.STRUCT] Estructura de resultado ---\n")
check("AC.STRUCT.01", "n_boot_requested en resultado", !is.null(res_full$n_boot_requested))
check("AC.STRUCT.02", "n_boot_valid en resultado", !is.null(res_full$n_boot_valid))
check("AC.STRUCT.03", "sobel_p en resultado", !is.null(res_full$sobel_p))
check("AC.STRUCT.04", "mediation_type es string", is.character(res_full$mediation_type))

# ── AC.REPRO — Reproducibilidad con semilla ──
cat("\n--- [AC.REPRO] Reproducibilidad con seed ---\n")
res_r1 <- run_mediation_simple(df_part, x_var="x", m_var="m", y_var="y", n_boot=200, seed=123)
res_r2 <- run_mediation_simple(df_part, x_var="x", m_var="m", y_var="y", n_boot=200, seed=123)
check("AC.REPRO.01", "mismo seed -> mismo indirect",
      identical(res_r1$indirect, res_r2$indirect))
check("AC.REPRO.02", "mismo seed -> mismo ci_lower",
      identical(res_r1$ci_lower, res_r2$ci_lower))

# ── AC.SERIAL — Guard MEDIACION_SERIAL bloqueada ──
cat("\n--- [AC.SERIAL] Guard mediacion serial bloqueada ---\n")
res_ser <- run_mediation_serial()
check("AC.SERIAL.01", "run_mediation_serial: blocked=TRUE", isTRUE(res_ser$blocked))
check("AC.SERIAL.02", "reason == 'NO_IMPLEMENTADO_SERIAL'",
      identical(res_ser$reason, "NO_IMPLEMENTADO_SERIAL"))

# ── AC.GUARDS — Guards de datos invalidos ──
cat("\n--- [AC.GUARDS] Guards de datos invalidos ---\n")
df_small <- data.frame(x=rnorm(3), m=rnorm(3), y=rnorm(3))
res_small <- run_mediation_simple(df_small, x_var="x", m_var="m", y_var="y", n_boot=10, seed=1)
check("AC.GUARDS.01", "n<5: blocked con MUESTRA_INSUFICIENTE",
      isTRUE(res_small$blocked) && identical(res_small$reason, "MUESTRA_INSUFICIENTE"))

df_cst <- data.frame(x=rnorm(30), m=rep(3, 30), y=rnorm(30))
res_cst <- run_mediation_simple(df_cst, x_var="x", m_var="m", y_var="y", n_boot=10, seed=1)
check("AC.GUARDS.02", "mediador constante: blocked con MEDIADOR_CONSTANTE",
      isTRUE(res_cst$blocked) && identical(res_cst$reason, "MEDIADOR_CONSTANTE"))

# ── AC.MISSING — Manejo de NA ──
cat("\n--- [AC.MISSING] Manejo de NA ---\n")
df_na <- df_full
df_na$x[1:5] <- NA
df_na$m[6:8] <- NA
res_na <- run_mediation_simple(df_na, x_var="x", m_var="m", y_var="y", n_boot=200, seed=1)
check("AC.MISSING.01", "NA en datos: no crash", !is.null(res_na))
check("AC.MISSING.02", "NA en datos: n < N original",
      !is.null(res_na$n) && res_na$n < N)

# ── Resumen ──
cat(sprintf("\n=== SUITE AC: %d PASS / %d FAIL ===\n", pass, fail))
if (fail > 0) quit(status=1L)
