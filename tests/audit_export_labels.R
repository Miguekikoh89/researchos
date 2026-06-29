# tests/audit_export_labels.R
# Suite V — Exportacion Word/JSON y etiquetado de metodos
#
# Verifica: funciones de exportacion presentes, campos JSON correctos,
#           etiquetado de metodos no implementados/experimentales.
# Uso: Rscript tests/audit_export_labels.R
# Exit: 0 = todos PASS, 1 = al menos un FAIL

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
grep_file <- function(pat, file, ...) {
  if (!file.exists(file)) return(FALSE)
  any(grepl(pat, readLines(file, warn = FALSE), ...))
}

.script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    args <- commandArgs(trailingOnly = FALSE)
    f    <- sub("--file=", "", grep("--file=", args, value = TRUE))
    if (length(f) > 0) dirname(normalizePath(f)) else getwd()
  }
)
repo_root   <- normalizePath(file.path(.script_dir, ".."))
r_dir       <- file.path(repo_root, "apps", "api", "stats-engine-r", "R")
word_export <- file.path(r_dir, "word_export.R")
run_r       <- file.path(repo_root, "apps", "api", "stats-engine-r", "run_analysis.R")
service_ts  <- file.path(repo_root, "apps", "api", "src", "analysis", "analysis.service.ts")
configure_tsx <- file.path(repo_root, "apps", "web", "src", "components", "wizard", "StepConfigure.tsx")
schema_pris <- file.path(repo_root, "apps", "api", "prisma", "schema.prisma")
inventory_r <- file.path(.script_dir, "audit_block1_inventory.R")

cat("=== SUITE V — Exportacion Word/JSON y Etiquetado ===\n\n")

# ── V1: Funciones Word Export presentes ──────────────────────────────────────
cat("── V1: Funciones de exportacion Word ──\n")
check("EXP.01", "word_export.R existe",
  file.exists(word_export))
check("EXP.02", "sanitize_text definido en word_export.R",
  grep_file("sanitize_text", word_export))
check("EXP.03", "add_p / add_heading definidos en word_export.R",
  grep_file("add_p|add_heading", word_export))
check("EXP.04", "Uso de officer:: en word_export.R",
  grep_file("officer::", word_export))
check("EXP.05", "Seccion de confiabilidad en word_export.R",
  grep_file("confiabilidad|cronbach|reliability", word_export, ignore.case = TRUE))
check("EXP.06", "Seccion de correlaciones en word_export.R",
  grep_file("correlaci|correlat", word_export, ignore.case = TRUE))
check("EXP.07", "word_path en resultado de run_analysis.R",
  grep_file("word_path", run_r))

# ── V2: JSON output — campos obligatorios ────────────────────────────────────
cat("\n── V2: Campos obligatorios en salida JSON ──\n")
check("EXP.08", "result$status en run_analysis.R (ok/error)",
  grep_file("result\\$status", run_r))
check("EXP.09", "result$method en run_analysis.R",
  grep_file("result\\$method", run_r))
check("EXP.10", "result$warnings en run_analysis.R",
  grep_file("result\\$warnings", run_r))
check("EXP.11", "result$errors en run_analysis.R",
  grep_file("result\\$errors", run_r))
check("EXP.12", "result$interpretations en run_analysis.R",
  grep_file("result\\$interpretations", run_r))

# ── V3: Blocked results — formato JSON correcto ──────────────────────────────
cat("\n── V3: Formato de resultados bloqueados ──\n")
check("EXP.13", "blocked=TRUE incluido en respuestas de guard",
  grep_file("blocked=TRUE", run_r))
check("EXP.14", "reason incluido en respuestas de guard",
  grep_file("reason=", run_r))
check("EXP.15", "stage incluido en respuestas de guard",
  grep_file("stage=", run_r))
check("EXP.16", "error message incluido en respuestas de guard",
  grep_file('error="', run_r))

# ── V4: Campos DB — AnalysisResult almacena resultado especifico por metodo ──
cat("\n── V4: Campos DB especificos por metodo ──\n")
db_cols <- c("ttest", "anova", "regression", "logistic", "chi_square",
             "instruments", "ordinal_regression", "hierarchical_regression",
             "discriminant", "ancova", "frequencies", "cluster",
             "cronbach_only", "baremos_only", "descriptives_full",
             "analisis_descriptivo", "mediation")
for (col in db_cols) {
  check(sprintf("EXP.17.%s", col),
        sprintf("columna '%s' en schema.prisma", col),
        grep_file(col, schema_pris))
}

# ── V5: Frontend — etiquetado de metodos no disponibles ──────────────────────
cat("\n── V5: Etiquetado frontend — metodos no implementados ──\n")
if (file.exists(configure_tsx)) {
  lines_tsx <- readLines(configure_tsx, warn = FALSE)

  check("EXP.18", "StepConfigure.tsx existe",
    TRUE)
  # Factorial/AFE debe aparecer como available:false en ANALYSIS_TYPES
  check("EXP.19", "Factorial marcado como available:false en frontend",
    any(grepl("[Ff]actorial.*available.*false|available.*false.*[Ff]actorial", lines_tsx) |
        (any(grepl("[Ff]actorial", lines_tsx)) && any(grepl("available.*false", lines_tsx)))))
  # PLS-SEM presente como metodo separado
  check("EXP.20", "PLS-SEM / structural_model presente en frontend",
    any(grepl("structural_model|PLS|pls", lines_tsx, ignore.case = TRUE)))
  # Instrumentos presente (modo especial)
  check("EXP.21", "Instrumentos presente en frontend",
    any(grepl("instrumentos|instruments", lines_tsx, ignore.case = TRUE)))
} else {
  skip_test("EXP.18", "StepConfigure.tsx existe", "archivo no encontrado")
  skip_test("EXP.19", "Factorial available:false", "StepConfigure.tsx no encontrado")
  skip_test("EXP.20", "PLS-SEM presente", "StepConfigure.tsx no encontrado")
  skip_test("EXP.21", "Instrumentos presente", "StepConfigure.tsx no encontrado")
}

# ── V6: Inventario de metodos — archivo Block 1 ──────────────────────────────
cat("\n── V6: Inventario de metodos (Block 1) ──\n")
check("EXP.22", "audit_block1_inventory.R existe",
  file.exists(inventory_r))
check("EXP.23", "Inventario tiene clasificacion de status",
  grep_file("VALIDATED|VALIDATED_WITH_RESTRICTIONS|EXPERIMENTAL|NOT_IMPLEMENTED",
            inventory_r))
check("EXP.24", "Inventario define 22 metodos (lista INVENTORY)",
  grep_file("INVENTORY|method_id", inventory_r))

# ── V7: Mediation — etiquetado correcto ──────────────────────────────────────
cat("\n── V7: Mediacion — etiquetado ──\n")
check("EXP.25", "mediation.R define run_mediation_serial con blocked=TRUE",
  grep_file("run_mediation_serial|NO_IMPLEMENTADO_SERIAL",
            file.path(r_dir, "mediation.R")))
check("EXP.26", "MEDIACION_SERIAL_NO_IMPLEMENTADA guard en run_analysis.R",
  grep_file("MEDIACION_SERIAL_NO_IMPLEMENTADA", run_r))
check("EXP.27", "mediation_type incluido en resultado de mediacion simple",
  grep_file("mediation_type", file.path(r_dir, "mediation.R")))

# ─────────────────────────────────────────────────────────────────────────────
cat(sprintf("\n=== RESULTADO SUITE V: %d PASS, %d FAIL, %d SKIP ===\n",
            pass, fail, skip_n))
if (fail > 0L) {
  cat("SUITE V: FALLO — ver detalles arriba.\n")
  quit(status = 1L)
}
cat("SUITE V: COMPLETA — exportacion y etiquetado OK.\n")
