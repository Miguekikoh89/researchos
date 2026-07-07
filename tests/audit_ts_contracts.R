# tests/audit_ts_contracts.R
# Suite S — Contrato TypeScript: AnalysisConfig, analysis_category, helpers
#
# Estrategia: inspeccion estatica de archivos TS/Prisma desde R.
# No requiere Node.js — verifica presencia de campos criticos en el codigo fuente.
# Uso: Rscript tests/audit_ts_contracts.R
# Exit: 0 = todos PASS, 1 = al menos un FAIL

pass <- 0L; fail <- 0L

check <- function(id, desc, cond) {
  label <- if (isTRUE(cond)) "PASS" else "FAIL"
  cat(sprintf("  [%s] %s: %s\n", label, id, desc))
  if (isTRUE(cond)) pass <<- pass + 1L else fail <<- fail + 1L
  invisible(isTRUE(cond))
}

grep_file <- function(pattern, file, ...) {
  if (!file.exists(file)) return(FALSE)
  any(grepl(pattern, readLines(file, warn = FALSE), ...))
}

.script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    args <- commandArgs(trailingOnly = FALSE)
    f    <- sub("--file=", "", grep("--file=", args, value = TRUE))
    if (length(f) > 0) dirname(normalizePath(f)) else getwd()
  }
)
repo_root    <- normalizePath(file.path(.script_dir, ".."))
service_ts   <- file.path(repo_root, "apps", "api", "src", "analysis", "analysis.service.ts")
steptrun_tsx <- file.path(repo_root, "apps", "web", "src", "components", "wizard", "StepRun.tsx")
schema_pris  <- file.path(repo_root, "apps", "api", "prisma", "schema.prisma")
run_r        <- file.path(repo_root, "apps", "api", "stats-engine-r", "run_analysis.R")

cat("=== SUITE S — TypeScript / Prisma Contracts ===\n\n")

# ── S1: AnalysisConfig — nuevos campos de nivel de medición ──────────────────
cat("── S1: AnalysisConfig — campos de nivel de medicion ──\n")
check("TS.01", "measurement_level_a presente en AnalysisConfig",
      grep_file("measurement_level_a", service_ts))
check("TS.02", "measurement_level_b presente en AnalysisConfig",
      grep_file("measurement_level_b", service_ts))
check("TS.03", "ordered_levels presente en AnalysisConfig",
      grep_file("ordered_levels", service_ts))
check("TS.04", "event_level presente en AnalysisConfig",
      grep_file("event_level", service_ts))
check("TS.05", "reference_level presente en AnalysisConfig",
      grep_file("reference_level", service_ts))

# ── S2: AnalysisConfig — campos de mediacion ─────────────────────────────────
cat("\n── S2: AnalysisConfig — campos mediacion ──\n")
check("TS.06", "mediator presente en AnalysisConfig",
      grep_file("mediator\\?:", service_ts))
check("TS.07", "mediators (plural) presente en AnalysisConfig",
      grep_file("mediators\\?:", service_ts))
check("TS.08", "bootstrap field presente en AnalysisConfig",
      grep_file("bootstrap\\?:", service_ts))
check("TS.09", "logistic_type presente en AnalysisConfig",
      grep_file("logistic_type", service_ts))

# ── S3: analysis_category union — todos los valores esperados ────────────────
cat("\n── S3: analysis_category union ──\n")
expected_cats <- c("correlacional", "comparacion", "regresion", "factorial",
                   "structural_model", "regresion_ordinal", "regresion_jerarquica",
                   "ancova", "discriminante", "frecuencias", "cluster", "cronbach",
                   "baremos", "descriptivos", "descriptivo", "anova", "logistica",
                   "chi_cuadrado", "instrumentos", "mediacion")
for (cat_val in expected_cats) {
  check(sprintf("TS.10.%s", cat_val),
        sprintf("analysis_category incluye '%s'", cat_val),
        grep_file(cat_val, service_ts))
}

# ── S4: rejectNonFinite sanitizer ────────────────────────────────────────────
cat("\n── S4: rejectNonFinite sanitizer ──\n")
check("TS.11", "funcion rejectNonFinite definida",
      grep_file("function rejectNonFinite", service_ts))
check("TS.12", "rejectNonFinite aplicado al resultado R (safeResult)",
      grep_file("rejectNonFinite\\(rResult\\)", service_ts))
check("TS.13", "manejo de NaN en rejectNonFinite (Number.isFinite)",
      grep_file("Number\\.isFinite", service_ts))
check("TS.14", "rejectNonFinite recursivo en arrays",
      grep_file("Array\\.isArray.*map.*rejectNonFinite|value\\.map\\(rejectNonFinite\\)", service_ts))

# ── S5: Persist — columnas criticas ──────────────────────────────────────────
cat("\n── S5: Persistencia DB — columnas criticas ──\n")
check("TS.15", "analisis_descriptivo persisted (safeResult.analisis_descriptivo)",
      grep_file("analisis_descriptivo.*safeResult|safeResult.*analisis_descriptivo", service_ts))
check("TS.16", "mediation persisted (safeResult.mediation)",
      grep_file("mediation.*safeResult|safeResult.*mediation", service_ts))
check("TS.17", "blocked=true detectado en error propagation",
      grep_file("blocked.*true|blocked === true", service_ts))

# ── S6: Prisma schema — columnas nuevas ──────────────────────────────────────
cat("\n── S6: Prisma schema — columnas nuevas ──\n")
check("TS.18", "columna mediation Json? en schema.prisma",
      grep_file("mediation.*Json\\?", schema_pris))
check("TS.19", "columna analisis_descriptivo Json? en schema.prisma",
      grep_file("analisis_descriptivo.*Json\\?", schema_pris))
check("TS.20", "AnalysisResult tiene jobId unico (@@unique / @unique)",
      grep_file("jobId.*@unique|@unique.*jobId", schema_pris))

# ── S7: Run_analysis.R — categorias enrutadas ────────────────────────────────
cat("\n── S7: run_analysis.R — categorias enrutadas ──\n")
check("TS.21", "mediacion enrutada en run_analysis.R",
      grep_file('analysis_category == "mediacion"', run_r))
check("TS.22", "regresion_ordinal enrutada en run_analysis.R",
      grep_file('analysis_category == "regresion_ordinal"', run_r))
check("TS.23", "F-024 ORDEN_NO_DECLARADO guard en run_analysis.R",
      grep_file("ORDEN_NO_DECLARADO", run_r))
check("TS.24", "MEDIADOR_NO_DECLARADO guard en run_analysis.R",
      grep_file("MEDIADOR_NO_DECLARADO", run_r))
check("TS.25", "MEDIACION_SERIAL_NO_IMPLEMENTADA guard en run_analysis.R",
      grep_file("MEDIACION_SERIAL_NO_IMPLEMENTADA", run_r))

# ── S8: StepRun.tsx — campos enviados ────────────────────────────────────────
cat("\n── S8: StepRun.tsx — campos enviados al API ──\n")
check("TS.26", "logistic_type enviado desde buildApiConfig",
      grep_file("logistic_type", steptrun_tsx))
check("TS.27", "analysis_category normalizado (regresion_multiple -> regresion)",
      grep_file("regresion_multiple.*regresion|regresion.*regresion_multiple", steptrun_tsx))
check("TS.28", "seed enviado desde StepRun.tsx",
      grep_file("seed.*cfg|cfg.*seed", steptrun_tsx))

# ─────────────────────────────────────────────────────────────────────────────
cat(sprintf("\n=== RESULTADO SUITE S: %d PASS, %d FAIL ===\n", pass, fail))
if (fail > 0L) {
  cat("SUITE S: FALLO — ver detalles arriba.\n")
  quit(status = 1L)
}
cat("SUITE S: COMPLETA — todos los contratos TS/Prisma verificados.\n")
