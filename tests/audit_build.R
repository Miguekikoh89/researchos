#!/usr/bin/env Rscript
# tests/audit_build.R
# Suite Y — Verificacion de build y contratos de archivos
#
# Verifica: parseo de todos los archivos R del motor, existencia de
# funciones criticas, firma de argumentos, coherencia de nombres exportados.
# Total: >=15 tests
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

cat("=== SUITE Y — BUILD & ARCHIVO CONTRATOS ===\n")
cat(sprintf("    R version: %s\n\n", R.version.string))

# ── Y.PARSE — Todos los archivos R del motor parsean sin error ──
cat("--- [Y.PARSE] Parse checks de archivos R ---\n")

r_files <- c(
  "helpers.R", "statistics.R", "regression.R", "hierarchical_regression.R",
  "logistic.R", "logistic_multinomial.R", "ordinal_regression.R",
  "instruments.R", "anova.R", "ancova.R", "t_test.R",
  "chi_square.R", "discriminant.R", "cluster.R",
  "descriptives_full.R", "mediation.R", "analisis_descriptivo.R",
  "word_export.R", "pls_sem_engine.R"
)

for (f in r_files) {
  fp <- file.path(r_dir, f)
  ok <- isTRUE(tryCatch({ parse(file = fp); TRUE }, error = function(e) FALSE))
  check(paste0("Y.PARSE.", sub("\\.R$", "", f)), paste("Parse OK:", f), ok)
}

# ── Y.FUNC — Funciones criticas existen despues de source ──
cat("\n--- [Y.FUNC] Funciones criticas exportadas ---\n")

source(file.path(r_dir, "helpers.R"))
source(file.path(r_dir, "regression.R"))
source(file.path(r_dir, "hierarchical_regression.R"))
source(file.path(r_dir, "logistic.R"))
source(file.path(r_dir, "instruments.R"))
source(file.path(r_dir, "mediation.R"))

check("Y.FUNC.01", "compute_regression existe", exists("compute_regression") && is.function(compute_regression))
check("Y.FUNC.02", "run_hierarchical_regression existe", exists("run_hierarchical_regression") && is.function(run_hierarchical_regression))
check("Y.FUNC.03", "compute_logistic existe", exists("compute_logistic") && is.function(compute_logistic))
check("Y.FUNC.04", "compute_logistic_binary existe", exists("compute_logistic_binary") && is.function(compute_logistic_binary))
check("Y.FUNC.05", "compute_afe existe", exists("compute_afe") && is.function(compute_afe))
check("Y.FUNC.06", "run_mediation_simple existe", exists("run_mediation_simple") && is.function(run_mediation_simple))

# ── Y.P2FIX — Verificar correcciones P2 en el codigo fuente ──
cat("\n--- [Y.P2FIX] Verificacion de correcciones P2 en codigo fuente ---\n")

reg_src <- readLines(file.path(r_dir, "regression.R"))
hier_src <- readLines(file.path(r_dir, "hierarchical_regression.R"))
inst_src <- readLines(file.path(r_dir, "instruments.R"))

check("Y.P2FIX.01", "P2-SINGULAR: guard MODELO_SINGULAR en regression.R",
      any(grepl("MODELO_SINGULAR", reg_src, fixed=TRUE)))

check("Y.P2FIX.02", "P2-SINGULAR: comprobacion is.na(coef) en regression.R",
      any(grepl("is.na(coef", reg_src, fixed=TRUE)))

check("Y.P2FIX.03", "P2-DF2-ROUND: as.integer en df2 en regression.R",
      any(grepl("as.integer(sm$fstatistic[3])", reg_src, fixed=TRUE)))

check("Y.P2FIX.04", "P2-HIER-N: nobs(mod) en hierarchical_regression.R",
      any(grepl("nobs(mod)", hier_src, fixed=TRUE)))

check("Y.P2FIX.05", "P2-AFE-JUST-ID: guard AFE_MODELO_NO_IDENTIFICADO en instruments.R",
      any(grepl("AFE_MODELO_NO_IDENTIFICADO", inst_src, fixed=TRUE)))

check("Y.P2FIX.06", "P2-AFE-JUST-ID: formula df_afe en instruments.R",
      any(grepl("df_afe", inst_src, fixed=TRUE)))

# ── Y.GUARD — Comportamiento de guards P2 ──
cat("\n--- [Y.GUARD] Comportamiento de guards P2 ---\n")

# P2-SINGULAR: x1 = 2*x2 -> deberia retornar blocked
set.seed(1)
x1 <- rnorm(50)
x2 <- 2 * x1  # perfectamente colineal
y_s <- x1 + rnorm(50, 0, 0.1)
sing_res <- compute_regression(y_s, data.frame(x1=x1, x2=x2), var_names=c("x1","x2"))
check("Y.GUARD.01", "P2-SINGULAR: retorna blocked=TRUE para predictores colineales",
      isTRUE(sing_res$blocked))
check("Y.GUARD.02", "P2-SINGULAR: reason == 'MODELO_SINGULAR'",
      identical(sing_res$reason, "MODELO_SINGULAR"))

# P2-DF2-ROUND: df2 debe ser entero (no double)
set.seed(2)
xv <- rnorm(30); yv <- 2*xv + rnorm(30)
res_df2 <- compute_regression(yv, data.frame(x=xv), var_names="x")
check("Y.GUARD.03", "P2-DF2-ROUND: df2 es entero (integer o double sin decimales)",
      !is.null(res_df2$df2) && res_df2$df2 == as.integer(res_df2$df2))

# P2-AFE-JUST-ID: 2 items, 1 factor -> df=(2*1/2) - 1*(4-1-1)/2 = 1 - 1 = 0 -> bloqueado
set.seed(3)
mat2 <- matrix(rnorm(60), nrow=30, ncol=2)
colnames(mat2) <- c("i1","i2")
df2_afe <- data.frame(mat2)
res_afe_ji <- compute_afe(df2_afe, n_factors=1)
check("Y.GUARD.04", "P2-AFE-JUST-ID: 2 items, 1 factor -> blocked=TRUE",
      isTRUE(res_afe_ji$blocked) && identical(res_afe_ji$reason, "AFE_MODELO_NO_IDENTIFICADO"))

# P2-HIER-N: verificar que el n en el resultado usa nobs(mod) no nrow(df)
set.seed(4)
df_h <- data.frame(y=rnorm(40), x1=rnorm(40), x2=rnorm(40))
# introducir 5 NA en y para que nobs(mod) < nrow(df)
df_h$y[1:5] <- NA
blocks_h <- list(list(name="B1", items=list("x1")), list(name="B2", items=list("x2")))
res_hier <- run_hierarchical_regression(df_h, blocks_h, "y", "Y_test")
check("Y.GUARD.05", "P2-HIER-N: n en resultado <= nrow(df) original (usa nobs, no nrow)",
      !is.null(res_hier$n) && res_hier$n <= nrow(df_h))
check("Y.GUARD.06", "P2-HIER-N: n refleja observaciones reales del modelo (35, no 40)",
      !is.null(res_hier$n) && res_hier$n == 35)

# ── Resumen ──
cat(sprintf("\n=== SUITE Y: %d PASS / %d FAIL ===\n", pass, fail))
if (fail > 0) quit(status=1L)
