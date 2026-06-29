# tests/audit_node_contracts.R
# Suite T — Contratos Node/API: inspeccion estatica de la capa de servicio
#
# Verifica que analysis.service.ts maneja correctamente la orquestacion:
# persist, error detection, sanitizacion, config forwarding.
# Uso: Rscript tests/audit_node_contracts.R
# Exit: 0 = todos PASS, 1 = al menos un FAIL

pass <- 0L; fail <- 0L; skip_n <- 0L

check <- function(id, desc, cond) {
  label <- if (isTRUE(cond)) "PASS" else "FAIL"
  cat(sprintf("  [%s] %s: %s\n", label, id, desc))
  if (isTRUE(cond)) pass <<- pass + 1L else fail <<- fail + 1L
  invisible(isTRUE(cond))
}
grep_file <- function(pat, file, ...) {
  if (!file.exists(file)) return(FALSE)
  any(grepl(pat, readLines(file, warn = FALSE), ...))
}
count_matches <- function(pat, file, ...) {
  if (!file.exists(file)) return(0L)
  sum(grepl(pat, readLines(file, warn = FALSE), ...))
}

.script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    args <- commandArgs(trailingOnly = FALSE)
    f    <- sub("--file=", "", grep("--file=", args, value = TRUE))
    if (length(f) > 0) dirname(normalizePath(f)) else getwd()
  }
)
repo_root  <- normalizePath(file.path(.script_dir, ".."))
service_ts <- file.path(repo_root, "apps", "api", "src", "analysis", "analysis.service.ts")
schema_pris <- file.path(repo_root, "apps", "api", "prisma", "schema.prisma")
run_r       <- file.path(repo_root, "apps", "api", "stats-engine-r", "run_analysis.R")

cat("=== SUITE T — Contratos Node/API ===\n\n")

# ── T1: Job lifecycle management ─────────────────────────────────────────────
cat("── T1: Ciclo de vida del Job ──\n")
check("NODE.01", "PENDING status asignado al crear job",
  grep_file("PENDING", service_ts))
check("NODE.02", "PROCESSING status asignado al iniciar ejecucion",
  grep_file("PROCESSING", service_ts))
check("NODE.03", "COMPLETED status asignado al terminar exitosamente",
  grep_file("COMPLETED", service_ts))
check("NODE.04", "FAILED status asignado en caso de error",
  grep_file("FAILED", service_ts))
check("NODE.05", "startedAt actualizado al iniciar",
  grep_file("startedAt.*new Date|startedAt.*Date\\.now", service_ts))
check("NODE.06", "finishedAt actualizado al terminar",
  grep_file("finishedAt.*new Date|finishedAt.*Date\\.now", service_ts))
check("NODE.07", "errorMsg almacenado en caso de fallo",
  grep_file("errorMsg", service_ts))

# ── T2: R engine invocation ──────────────────────────────────────────────────
cat("\n── T2: Invocacion del motor R ──\n")
check("NODE.08", "Rscript invocado para ejecutar run_analysis.R",
  grep_file("Rscript|run_analysis", service_ts))
check("NODE.09", "config serializado a JSON antes de pasar a R",
  grep_file("JSON\\.stringify", service_ts))
check("NODE.10", "resultado R parseado desde JSON",
  grep_file("JSON\\.parse", service_ts))
check("NODE.11", "stdout capturado del proceso R",
  grep_file("stdout|stdio", service_ts))

# ── T3: Error detection ──────────────────────────────────────────────────────
cat("\n── T3: Deteccion de errores del motor R ──\n")
check("NODE.12", "status 'error' de R detectado",
  grep_file("rResult\\.status.*error|status.*==.*error", service_ts))
check("NODE.13", "blocked=true de R detectado",
  grep_file("blocked.*true|blocked === true", service_ts))
check("NODE.14", "errores de R propagados a errorMsg del job",
  grep_file("errors\\.join|error.*join|errMsg", service_ts))
check("NODE.15", "exit code no-cero de Rscript detectado",
  grep_file("status.*!= 0|exitCode|exit.*code", service_ts))

# ── T4: Persist — todos los campos de AnalysisResult ────────────────────────
cat("\n── T4: Persistencia de AnalysisResult ──\n")
fields_required <- c("method", "diagnostic", "descriptives", "reliability",
                     "normality", "correlations", "interpretations", "warnings")
for (f in fields_required) {
  check(sprintf("NODE.16.%s", f),
        sprintf("campo '%s' persisted en analysisResult.create", f),
        grep_file(f, service_ts))
}
check("NODE.17", "mediation persisted",
  grep_file("mediation.*safeResult|safeResult.*mediation", service_ts))
check("NODE.18", "analisis_descriptivo persisted",
  grep_file("analisis_descriptivo", service_ts))
check("NODE.19", "ordinal_regression persisted",
  grep_file("ordinal_regression.*safeResult|safeResult.*ordinal_regression", service_ts))

# ── T5: Dataset linkage ──────────────────────────────────────────────────────
cat("\n── T5: Vinculacion con Dataset ──\n")
check("NODE.20", "datasetId validado antes de iniciar analisis",
  grep_file("datasetId|dataset\\.id", service_ts))
check("NODE.21", "storedPath del dataset usado para construir file_path",
  grep_file("storedPath|stored_path", service_ts))
check("NODE.22", "projectId validado (pertenencia del job al proyecto)",
  grep_file("projectId|project\\.id", service_ts))

# ── T6: Prisma schema — JobStatus enum ──────────────────────────────────────
cat("\n── T6: Prisma JobStatus enum ──\n")
statuses <- c("PENDING", "PROCESSING", "COMPLETED", "FAILED")
for (s in statuses) {
  check(sprintf("NODE.23.%s", s),
        sprintf("JobStatus.%s definido en schema.prisma", s),
        grep_file(s, schema_pris))
}

# ── T7: Config forwarding — campos criticos pasados a R ──────────────────────
cat("\n── T7: Config forwarding a R ──\n")
check("NODE.24", "analysis_category incluido en config JSON",
  grep_file("analysis_category", service_ts))
check("NODE.25", "var_a incluido en config JSON",
  grep_file("var_a", service_ts))
check("NODE.26", "var_b incluido en config JSON",
  grep_file("var_b", service_ts))

# ─────────────────────────────────────────────────────────────────────────────
cat(sprintf("\n=== RESULTADO SUITE T: %d PASS, %d FAIL, %d SKIP ===\n",
            pass, fail, skip_n))
if (fail > 0L) {
  cat("SUITE T: FALLO — ver detalles arriba.\n")
  quit(status = 1L)
}
cat("SUITE T: COMPLETA — contratos Node/API OK.\n")
