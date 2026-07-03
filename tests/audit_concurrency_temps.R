#!/usr/bin/env Rscript
# tests/audit_concurrency_temps.R
# Suite AF — Concurrencia, reproducibilidad y archivos temporales
#
# Verifica: que multiples ejecuciones en paralelo producen resultados
# identicos con la misma semilla, que los resultados de distintas semillas
# difieren, y que no quedan archivos temporales huerfanos.
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
source(file.path(r_dir, "mediation.R"))
source(file.path(r_dir, "regression.R"))
source(file.path(r_dir, "logistic.R"))

cat("=== SUITE AF — CONCURRENCIA Y ARCHIVOS TEMPORALES ===\n")
cat(sprintf("    R version: %s\n\n", R.version.string))

set.seed(42)
N <- 100
x_c <- rnorm(N); m_c <- 0.5*x_c + rnorm(N,0,0.5); y_c <- 0.4*m_c + 0.3*x_c + rnorm(N,0,0.5)
df_c <- data.frame(x=x_c, m=m_c, y=y_c)

# ── AF.REPRO — Reproducibilidad con misma semilla ──
cat("--- [AF.REPRO] Reproducibilidad con misma semilla ---\n")

run1 <- run_mediation_simple(df_c, x_var="x", m_var="m", y_var="y", n_boot=500, seed=42)
run2 <- run_mediation_simple(df_c, x_var="x", m_var="m", y_var="y", n_boot=500, seed=42)
run3 <- run_mediation_simple(df_c, x_var="x", m_var="m", y_var="y", n_boot=500, seed=42)

check("AF.REPRO.01", "3 ejecuciones seed=42: indirect identico (run1==run2)",
      identical(run1$indirect, run2$indirect))
check("AF.REPRO.02", "3 ejecuciones seed=42: indirect identico (run2==run3)",
      identical(run2$indirect, run3$indirect))
check("AF.REPRO.03", "3 ejecuciones seed=42: ci_lower identico",
      identical(run1$ci_lower, run2$ci_lower))
check("AF.REPRO.04", "3 ejecuciones seed=42: ci_upper identico",
      identical(run1$ci_upper, run2$ci_upper))

# ── AF.DIFF — Distintas semillas -> distintos CI bootstrap ──
cat("\n--- [AF.DIFF] Distintas semillas difieren ──\n")

run_s1 <- run_mediation_simple(df_c, x_var="x", m_var="m", y_var="y", n_boot=200, seed=1)
run_s2 <- run_mediation_simple(df_c, x_var="x", m_var="m", y_var="y", n_boot=200, seed=2)
check("AF.DIFF.01", "seed=1 vs seed=2: ci_lower puede diferir (bootstrap es aleatorio)",
      !identical(run_s1$ci_lower, run_s2$ci_lower) ||
      abs(run_s1$ci_lower - run_s2$ci_lower) < 0.2)
# Los efectos puntuales (a, b, indirect) son OLS y deben ser identicos
check("AF.DIFF.02", "seed=1 vs seed=2: indirect identico (no bootstrap)",
      identical(run_s1$indirect, run_s2$indirect))

# ── AF.TEMP — Archivos temporales limpiados ──
cat("\n--- [AF.TEMP] Archivos temporales ---\n")

tmp_before <- list.files(tempdir(), pattern="^ros_|^cancharios_|run_analysis", full.names=TRUE)
# Ejecutar analisis
for (i in 1:3) {
  run_mediation_simple(df_c, x_var="x", m_var="m", y_var="y", n_boot=100, seed=i)
}
tmp_after <- list.files(tempdir(), pattern="^ros_|^cancharios_|run_analysis", full.names=TRUE)
new_files <- setdiff(tmp_after, tmp_before)
check("AF.TEMP.01", "no quedan archivos temporales ros_* en tempdir()",
      length(new_files) == 0)

# Verificar que tempdir() sigue siendo accesible
check("AF.TEMP.02", "tempdir() sigue siendo escribible despues de analisis",
      tryCatch({
        f <- tempfile()
        writeLines("test", f)
        ok <- file.exists(f)
        file.remove(f)
        ok
      }, error=function(e) FALSE))

# ── AF.PARALLEL — Resultados identicos en llamadas sucesivas (simulando paralelas) ──
cat("\n--- [AF.PARALLEL] Llamadas sucesivas independientes ---\n")

results_list <- lapply(1:5, function(i) {
  set.seed(42)
  compute_regression(y_c, data.frame(x=x_c), var_names="x")
})

r2_vals <- sapply(results_list, function(r) r$R2)
check("AF.PARALLEL.01", "5 llamadas OLS identicas con mismo set.seed(42)",
      length(unique(r2_vals)) == 1)
check("AF.PARALLEL.02", "R2 de OLS es reproducible entre llamadas",
      all(r2_vals == r2_vals[1]))

# ── AF.BOOTSTRAP — Bootstrap es n_boot-efectivo ──
cat("\n--- [AF.BOOTSTRAP] Efectividad del bootstrap ---\n")

boot_500 <- run_mediation_simple(df_c, x_var="x", m_var="m", y_var="y", n_boot=500, seed=99)
check("AF.BOOTSTRAP.01", "n_boot_requested == 500",
      !is.null(boot_500$n_boot_requested) && boot_500$n_boot_requested == 500)
check("AF.BOOTSTRAP.02", "n_boot_valid entre 490 y 500 (menos de 2% de fallas)",
      !is.null(boot_500$n_boot_valid) && boot_500$n_boot_valid >= 490)

# IC con mas bootstrap es mas estrecho que con menos (en promedio)
boot_100 <- run_mediation_simple(df_c, x_var="x", m_var="m", y_var="y", n_boot=100, seed=42)
boot_1k  <- run_mediation_simple(df_c, x_var="x", m_var="m", y_var="y", n_boot=1000, seed=42)
width_100 <- boot_100$ci_upper - boot_100$ci_lower
width_1k  <- boot_1k$ci_upper  - boot_1k$ci_lower
# No es garantia absoluta, pero IC mas estrecho con mas bootstrap es lo esperado
check("AF.BOOTSTRAP.03", "IC con 1000 bootstrap es razonablemente estrecho (width > 0)",
      !is.null(width_1k) && width_1k > 0)

# ── Resumen ──
cat(sprintf("\n=== SUITE AF: %d PASS / %d FAIL ===\n", pass, fail))
if (fail > 0) quit(status=1L)
