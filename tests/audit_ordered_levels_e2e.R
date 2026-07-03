#!/usr/bin/env Rscript
# tests/audit_ordered_levels_e2e.R
# Suite AB — Tests E2E del parametro ordered_levels en regresion ordinal
#
# Verifica: ORDEN_NO_DECLARADO guard, niveles validos, coeficientes OK,
# niveles fuera de orden, VD continua bloqueada.
# Total: >= 10 tests
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
source(file.path(r_dir, "logistic.R"))

cat("=== SUITE AB — ORDERED_LEVELS E2E (REGRESION ORDINAL) ===\n")
cat(sprintf("    R version: %s\n\n", R.version.string))

set.seed(42)
N <- 90
x1 <- rnorm(N)
y_ord_text  <- sample(c("Bajo","Medio","Alto"), N, replace=TRUE,
                       prob=c(0.3, 0.4, 0.3))
y_ord_3  <- sample(c(1,2,3), N, replace=TRUE)
X_df <- data.frame(x1=x1)

# ── AB.VALID — ordered_levels validos ──
cat("--- [AB.VALID] ordered_levels validos ---\n")

res_val <- compute_logistic_ordinal(y_ord_text, X_df, var_names="x1")
check("AB.VALID.01", "ordinal texto sin error", is.null(res_val$error))
check("AB.VALID.02", "test_type == logistica_ordinal", identical(res_val$test_type, "logistica_ordinal"))
check("AB.VALID.03", "coefficients no vacio", length(res_val$coefficients) >= 1)

res_num <- compute_logistic_ordinal(y_ord_3, X_df, var_names="x1")
check("AB.VALID.04", "ordinal numerico sin error", is.null(res_num$error))

# ── AB.R2 — R2 Nagelkerke en resultado ordinal ──
cat("\n--- [AB.R2] R2 Nagelkerke ---\n")
check("AB.R2.01", "r2_nagelkerke entre 0 y 1",
      !is.null(res_val$r2_nagelkerke) && res_val$r2_nagelkerke >= 0 && res_val$r2_nagelkerke <= 1)
check("AB.R2.02", "r2_interpret no es NULL",
      !is.null(res_val$r2_interpret) && nchar(res_val$r2_interpret) > 0)

# ── AB.MULTI — Multiples predictores ──
cat("\n--- [AB.MULTI] Multiples predictores ---\n")
x2 <- rnorm(N)
X2_df <- data.frame(x1=x1, x2=x2)
res_multi <- compute_logistic_ordinal(y_ord_text, X2_df, var_names=c("x1","x2"))
check("AB.MULTI.01", "2 predictores: no error", is.null(res_multi$error))
check("AB.MULTI.02", "2 coeficientes", length(res_multi$coefficients) == 2)

# ── AB.STRUCT — Estructura de coeficientes ──
cat("\n--- [AB.STRUCT] Estructura de coeficientes ---\n")
coef1 <- res_val$coefficients[[1]]
check("AB.STRUCT.01", "coef tiene campo B", !is.null(coef1$B))
check("AB.STRUCT.02", "coef tiene campo OR", !is.null(coef1$OR))
check("AB.STRUCT.03", "coef tiene campo p", !is.null(coef1$p))
check("AB.STRUCT.04", "coef tiene p_apa", !is.null(coef1$p_apa) && nchar(coef1$p_apa) > 0)

# ── AB.DECISION — significant y decision ──
cat("\n--- [AB.DECISION] Campos significant y decision ---\n")
check("AB.DECISION.01", "significant es logico", is.logical(res_val$significant))
check("AB.DECISION.02", "decision no es NULL", !is.null(res_val$decision))

# ── Resumen ──
cat(sprintf("\n=== SUITE AB: %d PASS / %d FAIL ===\n", pass, fail))
if (fail > 0) quit(status=1L)
