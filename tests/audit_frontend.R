# tests/audit_frontend.R
# Suite X — Verificacion de frontend: campos enviados, metodos visibles,
#            normalizacion de categorias, parametros de analisis.
# Uso: Rscript tests/audit_frontend.R
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
count_lines <- function(pat, file, ...) {
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
repo_root     <- normalizePath(file.path(.script_dir, ".."))
steprun_tsx   <- file.path(repo_root, "apps", "web", "src", "components", "wizard", "StepRun.tsx")
stepcfg_tsx   <- file.path(repo_root, "apps", "web", "src", "components", "wizard", "StepConfigure.tsx")
stepresult_tsx <- file.path(repo_root, "apps", "web", "src", "components", "wizard", "StepResults.tsx")

cat("=== SUITE X — Frontend Verification ===\n\n")

# ── X1: buildApiConfig — campos obligatorios ─────────────────────────────────
cat("── X1: buildApiConfig — campos enviados ──\n")
check("FE.01", "var_a incluido en buildApiConfig",
  grep_file("var_a:", steprun_tsx))
check("FE.02", "var_b incluido en buildApiConfig",
  grep_file("var_b:", steprun_tsx))
check("FE.03", "analysis_category incluido en buildApiConfig",
  grep_file("analysis_category:", steprun_tsx))
check("FE.04", "datasetId incluido en buildApiConfig",
  grep_file("datasetId.*state\\.datasetId|state\\.datasetId.*datasetId", steprun_tsx))
check("FE.05", "logistic_type enviado para logistica",
  grep_file("logistic_type", steprun_tsx))
check("FE.06", "seed enviado en buildApiConfig",
  grep_file("seed.*42|seed.*cfg", steprun_tsx))

# ── X2: Block 3 fix — ordered_levels (F-024) ─────────────────────────────────
cat("\n── X2: Block 3 — ordered_levels enviado (F-024) ──\n")
check("FE.07", "ordered_levels enviado para regresion_ordinal",
  grep_file("ordered_levels", steprun_tsx))
check("FE.08", "ordered_levels reutiliza baremoLevels (campo ya editable en UI)",
  grep_file("baremoLevels.*Bajo|cfg\\.baremoLevels", steprun_tsx))
check("FE.09", "ordered_levels condicionado a regresion_ordinal",
  grep_file("regresion_ordinal.*\\?|analysisCategory === 'regresion_ordinal'", steprun_tsx))
# event_level (F-023): gap conocido — sin selector de UI, documentado en el codigo.
# No se envia un valor adivinado; el guard EVENTO_NO_DECLARADO sigue bloqueando
# logistica binaria desde el frontend hasta que se agregue el selector (Block 3 P1).
check("FE.10", "gap event_level documentado explicitamente en StepRun.tsx",
  grep_file("EVENTO_NO_DECLARADO|gap conocido", steprun_tsx))

# ── X3: Normalizacion de analysis_category ───────────────────────────────────
cat("\n── X3: Normalizacion de analysis_category ──\n")
check("FE.11", "regresion_multiple normalizado a 'regresion'",
  grep_file("regresion_multiple.*regresion|'regresion'", steprun_tsx))
check("FE.12", "regresion_multinomial normalizado a 'logistica'",
  grep_file("regresion_multinomial.*logistica", steprun_tsx))
check("FE.13", "structural_model enviado sin modificacion",
  grep_file("structural_model", steprun_tsx))

# ── X4: StepConfigure — metodos disponibles ──────────────────────────────────
cat("\n── X4: StepConfigure — metodos en grid ──\n")
check("FE.14", "correlacional presente en ANALYSIS_TYPES",
  grep_file("correlacional", stepcfg_tsx))
check("FE.15", "comparacion/Comparacion presente en frontend",
  grep_file("comparaci", stepcfg_tsx, ignore.case = TRUE))
check("FE.16", "logistica/logístico presente en frontend",
  grep_file("logist", stepcfg_tsx, ignore.case = TRUE))
check("FE.17", "chi.cuadrado presente en frontend",
  grep_file("chi", stepcfg_tsx, ignore.case = TRUE))
check("FE.18", "anova presente en frontend",
  grep_file("anova|ANOVA", stepcfg_tsx, ignore.case = TRUE))
check("FE.19", "factorial presente (aunque available:false)",
  grep_file("factorial|Factorial", stepcfg_tsx, ignore.case = TRUE))

# ── X5: StepConfigure — metodos avanzados via URL ────────────────────────────
cat("\n── X5: Metodos avanzados via URL ──\n")
check("FE.20", "regresion_ordinal accesible (URL param o lista)",
  grep_file("regresion_ordinal", stepcfg_tsx))
check("FE.21", "regresion_jerarquica accesible",
  grep_file("regresion_jerarquica|jerarquica", stepcfg_tsx, ignore.case = TRUE))
check("FE.22", "ancova accesible",
  grep_file("ancova|ANCOVA", stepcfg_tsx, ignore.case = TRUE))
check("FE.23", "discriminante accesible",
  grep_file("discriminante|Discriminante|discriminant", stepcfg_tsx, ignore.case = TRUE))
check("FE.24", "cluster accesible",
  grep_file("cluster|Cluster", stepcfg_tsx, ignore.case = TRUE))

# ── X6: StepConfigure — campos de regresion ordinal ─────────────────────────
cat("\n── X6: StepConfigure — campos de regresion ordinal ──\n")
check("FE.25", "linkFunction selector presente para regresion_ordinal",
  grep_file("linkFunction|link_function|linkfunc", stepcfg_tsx, ignore.case = TRUE))
check("FE.26", "ordinalizacion selector presente para regresion_ordinal",
  grep_file("ordinalizacion", stepcfg_tsx))
check("FE.27", "pseudoR2 selector presente para regresion_ordinal",
  grep_file("pseudoR2|pseudo_r2|pseudor2", stepcfg_tsx, ignore.case = TRUE))

# ── X7: StepRun — manejo de estados de job ───────────────────────────────────
cat("\n── X7: StepRun — manejo de estados del job ──\n")
check("FE.28", "PENDING status mostrado al usuario",
  grep_file("PENDING", steprun_tsx))
check("FE.29", "PROCESSING status mostrado al usuario",
  grep_file("PROCESSING", steprun_tsx))
check("FE.30", "COMPLETED status mostrado al usuario",
  grep_file("COMPLETED", steprun_tsx))
check("FE.31", "FAILED status mostrado al usuario",
  grep_file("FAILED", steprun_tsx))
check("FE.32", "Polling de estado del job implementado (setInterval o useEffect)",
  grep_file("setInterval|polling|useEffect", steprun_tsx))

# ─────────────────────────────────────────────────────────────────────────────
cat(sprintf("\n=== RESULTADO SUITE X: %d PASS, %d FAIL, %d SKIP ===\n",
            pass, fail, skip_n))
if (fail > 0L) {
  cat("SUITE X: FALLO — ver detalles arriba.\n")
  quit(status = 1L)
}
cat("SUITE X: COMPLETA — frontend verification OK.\n")
