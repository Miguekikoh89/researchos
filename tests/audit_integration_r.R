#!/usr/bin/env Rscript
# tests/audit_integration_r.R
# Suite Z — Tests de integracion R end-to-end (sin mocks)
#
# Ejecuta el motor R con datos reales para 9 metodos y verifica
# que la salida JSON tiene la estructura correcta.
# Total: >= 20 tests
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

for (f in c("helpers.R","statistics.R","regression.R","hierarchical_regression.R",
            "logistic.R","ordinal_regression.R","instruments.R",
            "anova.R","t_test.R","chi_square.R","mediation.R","analisis_descriptivo.R")) {
  tryCatch(source(file.path(r_dir, f)), error=function(e) NULL)
}

cat("=== SUITE Z — INTEGRACION R END-TO-END ===\n")
cat(sprintf("    R version: %s\n\n", R.version.string))

set.seed(42)
N <- 80

# Datos comunes
x1 <- rnorm(N)
x2 <- rnorm(N)
y_cont <- 2*x1 + 1.5*x2 + rnorm(N)
y_bin  <- as.integer(plogis(0.5*x1 + 0.3*x2) > 0.5)
y_ord  <- cut(y_cont, breaks=3, labels=c("Bajo","Medio","Alto"))
y_group <- c(rep("G1", N/2), rep("G2", N/2))
df_base <- data.frame(x1=x1, x2=x2, y=y_cont, y_bin=y_bin, y_ord=y_ord, grp=y_group)

# ── Z.REG — Regresion lineal multiple ──
cat("--- [Z.REG] Regresion lineal multiple ---\n")
res_reg <- compute_regression(y_cont, data.frame(x1=x1, x2=x2), var_names=c("x1","x2"))
check("Z.REG.01", "resultado no es error", is.null(res_reg$error) && is.null(res_reg$blocked))
check("Z.REG.02", "test_type es regresion_multiple", identical(res_reg$test_type, "regresion_multiple"))
check("Z.REG.03", "R2 entre 0 y 1", !is.null(res_reg$R2) && res_reg$R2 >= 0 && res_reg$R2 <= 1)
check("Z.REG.04", "coefficients tiene 3 entradas (intercepto + 2 pred)", length(res_reg$coefficients) == 3)
check("Z.REG.05", "n == N", res_reg$n == N)

# ── Z.LOG — Logistica binaria con event_level ──
cat("\n--- [Z.LOG] Logistica binaria con event_level=1 ---\n")
res_log <- compute_logistic_binary(y_bin, data.frame(x1=x1, x2=x2),
                                   var_names=c("x1","x2"), event_level="1")
check("Z.LOG.01", "no blocked", is.null(res_log$blocked))
check("Z.LOG.02", "test_type logistica_binaria", identical(res_log$test_type, "logistica_binaria"))
check("Z.LOG.03", "event_level == '1'", identical(res_log$event_level, "1"))
check("Z.LOG.04", "roc$auc entre 0 y 1", !is.null(res_log$roc$auc) && !is.na(res_log$roc$auc) && res_log$roc$auc >= 0 && res_log$roc$auc <= 1)

# ── Z.ORD — Regresion ordinal ──
cat("\n--- [Z.ORD] Regresion ordinal ---\n")
res_ord <- tryCatch(
  compute_logistic_ordinal(as.character(y_ord), data.frame(x1=x1, x2=x2), var_names=c("x1","x2")),
  error = function(e) list(error=e$message)
)
check("Z.ORD.01", "no error en ordinal", is.null(res_ord$error))
check("Z.ORD.02", "test_type logistica_ordinal", identical(res_ord$test_type, "logistica_ordinal"))

# ── Z.HIER — Regresion jerarquica ──
cat("\n--- [Z.HIER] Regresion jerarquica ---\n")
blocks_z <- list(list(name="B1", items=list("x1")), list(name="B2", items=list("x2")))
res_hier <- run_hierarchical_regression(df_base, blocks_z, "y", "Y_test")
check("Z.HIER.01", "no error", is.null(res_hier$error))
check("Z.HIER.02", "2 bloques", length(res_hier$blocks) == 2)
check("Z.HIER.03", "R2 bloque 2 >= R2 bloque 1", res_hier$blocks[[2]]$r2 >= res_hier$blocks[[1]]$r2)

# ── Z.AFE — AFE con datos validos ──
cat("\n--- [Z.AFE] AFE con 6 items ──\n")
set.seed(5)
mat6 <- matrix(0, nrow=N, ncol=6)
for(i in 1:3) mat6[,i] <- rnorm(N) + 0.8*rnorm(N)
for(i in 4:6) mat6[,i] <- rnorm(N) + 0.8*rnorm(N)
colnames(mat6) <- paste0("i",1:6)
res_afe <- compute_afe(data.frame(mat6), n_factors=2)
check("Z.AFE.01", "no blocked/error con 6 items", is.null(res_afe$blocked) && is.null(res_afe$error))
check("Z.AFE.02", "n_factors == 2", !is.null(res_afe$n_factors) && res_afe$n_factors == 2)
check("Z.AFE.03", "loadings tiene 6 items", length(res_afe$loadings) == 6)

# ── Z.CHI — Chi-cuadrado ──
cat("\n--- [Z.CHI] Chi-cuadrado ---\n")
source(file.path(r_dir, "chi_square.R"))
v1 <- sample(c("A","B","C"), N, replace=TRUE)
v2 <- sample(c("X","Y"), N, replace=TRUE)
res_chi <- tryCatch(
  compute_chisquare(v1, v2, alpha=0.05),
  error = function(e) list(error=e$message)
)
check("Z.CHI.01", "chi-cuadrado: no error", is.null(res_chi$error))
check("Z.CHI.02", "chi-cuadrado: chi2 >= 0", !is.null(res_chi$chi2) && res_chi$chi2 >= 0)

# ── Z.ANOVA — ANOVA ──
cat("\n--- [Z.ANOVA] ANOVA ---\n")
y_aov <- c(rnorm(25, 10), rnorm(25, 12), rnorm(25, 14))
grp_aov <- rep(c("G1","G2","G3"), each=25)
res_aov <- tryCatch(
  compute_anova(y_aov, grp_aov, alpha=0.05),
  error = function(e) list(error=e$message)
)
check("Z.ANOVA.01", "anova: no error", is.null(res_aov$error))
check("Z.ANOVA.02", "anova: F >= 0", !is.null(res_aov$F) && res_aov$F >= 0)

# ── Z.MED — Mediacion ──
cat("\n--- [Z.MED] Mediacion simple ──\n")
set.seed(7)
x_m <- rnorm(N); m_m <- 0.5*x_m + rnorm(N, 0, 0.5); y_m <- 0.4*m_m + 0.3*x_m + rnorm(N, 0, 0.5)
df_med <- data.frame(x=x_m, m=m_m, y=y_m)
res_med <- tryCatch(
  run_mediation_simple(df_med, x_var="x", m_var="m", y_var="y", n_boot=200, seed=42),
  error = function(e) list(error=e$message)
)
check("Z.MED.01", "mediacion: no error", is.null(res_med$error))
check("Z.MED.02", "indirect existe", !is.null(res_med$indirect))

# ── Resumen ──
cat(sprintf("\n=== SUITE Z: %d PASS / %d FAIL ===\n", pass, fail))
if (fail > 0) quit(status=1L)
