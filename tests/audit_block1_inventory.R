#!/usr/bin/env Rscript
# ============================================================================
# FASE 3E — BLOQUE 1: INVENTARIO DE CONTRATO DE MÉTODOS
# Audit file: establece el ground truth de qué está implementado por capa.
# ============================================================================
# COLUMNAS:
#   method_id      — identificador canónico (analysis_category en config JSON)
#   label          — nombre visible en frontend
#   frontend_vis   — TRUE si aparece en el selector de métodos de la UI
#   frontend_fields— campos de UI disponibles para ese método
#   ts_type        — si está en AnalysisConfig.analysis_category (backend TS)
#   node_routed    — si tiene routing en analysis.service.ts o run_analysis.R
#   r_function     — función R principal que lo ejecuta
#   r_file         — archivo R que contiene la función
#   db_column      — columna en AnalysisResult donde se persiste
#   word_supported — si genera Word APA automáticamente
#   validated_ci   — si tiene suite de tests en CI (paso X del workflow)
#   status         — VALIDATED / VALIDATED_WITH_RESTRICTIONS / EXPERIMENTAL /
#                    NOT_IMPLEMENTED / HIDDEN
# ============================================================================

suppressPackageStartupMessages(library(jsonlite))

INVENTORY <- list(
  list(
    method_id      = "correlacional",
    label          = "Correlacional (Pearson/Spearman/Kendall)",
    frontend_vis   = TRUE,
    frontend_fields= c("varAName","varAItems","varADimensions","varBName","varBItems","varBDimensions",
                       "methodForce","analysisTypes","hypothesisType","confidenceLevel","multipleCorrection",
                       "scale","baremoLevels"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "compute_correlations()",
    r_file         = "statistics.R",
    db_column      = "correlations",
    word_supported = TRUE,
    validated_ci   = "A-H (audit_fase3a_correlacion.R, audit_guards_comprehensive.R)",
    status         = "VALIDATED"
  ),
  list(
    method_id      = "comparacion",
    label          = "Comparación de grupos (t-test / U de Mann-Whitney / Wilcoxon)",
    frontend_vis   = TRUE,
    frontend_fields= c("varAName","varAItems","varADimensions","groupVar","groupValues","comparisonType",
                       "hypothesisType","effectSize","leveneTest","scale","baremoLevels"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "compute_ttest()",
    r_file         = "t_test.R",
    db_column      = "ttest",
    word_supported = TRUE,
    validated_ci   = "I (audit_ttest_discriminant.R)",
    status         = "VALIDATED"
  ),
  list(
    method_id      = "anova",
    label          = "ANOVA (Welch / Kruskal-Wallis + post-hoc)",
    frontend_vis   = TRUE,
    frontend_fields= c("varAName","varAItems","varADimensions","groupVar","posthoc","effectSize",
                       "leveneTest","scale","baremoLevels"),
    ts_type        = FALSE,
    node_routed    = TRUE,
    r_function     = "compute_anova()",
    r_file         = "anova.R",
    db_column      = "anova",
    word_supported = TRUE,
    validated_ci   = "J (audit_anova_ancova.R)",
    status         = "VALIDATED_WITH_RESTRICTIONS",
    notes          = "P2-WELCH: label Welch vs Kruskal. P2-GH-P: Games-Howell p valores aproximados."
  ),
  list(
    method_id      = "ancova",
    label          = "ANCOVA",
    frontend_vis   = FALSE,
    frontend_fields= c("varAName","varAItems","varBName","varBItems","groupVar","posthoc","homogeneitySlopes"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "run_ancova()",
    r_file         = "ancova.R",
    db_column      = "ancova",
    word_supported = FALSE,
    validated_ci   = "J (audit_anova_ancova.R)",
    status         = "VALIDATED_WITH_RESTRICTIONS",
    notes          = "frontend_vis=FALSE: accessible via ?method=ancova URL. No Word export."
  ),
  list(
    method_id      = "regresion",
    label          = "Regresión lineal (simple y múltiple)",
    frontend_vis   = TRUE,
    frontend_fields= c("varAName","varAItems","varBName","varBItems","extraPredictors",
                       "regressionMethod","checkAssumptions","coefCI","handleOutliers","vifThreshold"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "compute_regression()",
    r_file         = "regression.R",
    db_column      = "regression",
    word_supported = TRUE,
    validated_ci   = "K (audit_regression.R)",
    status         = "VALIDATED"
  ),
  list(
    method_id      = "regresion_jerarquica",
    label          = "Regresión jerárquica",
    frontend_vis   = FALSE,
    frontend_fields= c("varBName","varBItems","hierBlocks","hierMethod","reportDeltaR2"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "run_hierarchical_regression()",
    r_file         = "hierarchical_regression.R",
    db_column      = "hierarchical_regression",
    word_supported = FALSE,
    validated_ci   = "K (audit_regression.R)",
    status         = "VALIDATED_WITH_RESTRICTIONS",
    notes          = "P2-HIER-N: no verifica n >= p+5 antes de ejecutar. No Word export."
  ),
  list(
    method_id      = "logistica_binaria",
    label          = "Regresión logística binaria",
    frontend_vis   = TRUE,
    frontend_fields= c("varAName","varAItems","varBName","varBItems","logisticType","eventLevel",
                       "logisticEntry","cutPoint","pseudoR2","hosmerLemeshow","rocCurve"),
    ts_type        = FALSE,
    node_routed    = TRUE,
    r_function     = "compute_logistic(type='binaria')",
    r_file         = "logistic.R",
    db_column      = "logistic",
    word_supported = TRUE,
    validated_ci   = "L (audit_logistic_chisq.R)",
    status         = "VALIDATED_WITH_RESTRICTIONS",
    notes          = "F-023: event_level obligatorio. Bloqueado si no se declara (EVENTO_NO_DECLARADO). ts_type=FALSE: 'logistica' no está en AnalysisConfig.analysis_category del backend TS."
  ),
  list(
    method_id      = "logistica_multinomial",
    label          = "Regresión logística multinomial",
    frontend_vis   = TRUE,
    frontend_fields= c("varAName","varAItems","varBName","varBItems","logisticType","referenceLevel",
                       "logisticEntry","pseudoR2"),
    ts_type        = FALSE,
    node_routed    = TRUE,
    r_function     = "compute_logistic_multinomial()",
    r_file         = "logistic_multinomial.R",
    db_column      = "logistic",
    word_supported = FALSE,
    validated_ci   = "L (audit_logistic_chisq.R)",
    status         = "EXPERIMENTAL",
    notes          = "reference_level no implementado como guard. No Word export para multinomial."
  ),
  list(
    method_id      = "regresion_ordinal",
    label          = "Regresión ordinal (proporcional de odds)",
    frontend_vis   = FALSE,
    frontend_fields= c("varAName","varAItems","varBName","varBItems","extraPredictors",
                       "linkFunction","ordinalizacion","pseudoR2","orderedLevels","measurementLevelB"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "run_ordinal_regression()",
    r_file         = "ordinal_regression.R",
    db_column      = "ordinal_regression",
    word_supported = FALSE,
    validated_ci   = "L (audit_logistic_chisq.R)",
    status         = "VALIDATED_WITH_RESTRICTIONS",
    notes          = "F-022: measurement_level_b=nominal bloquea. F-024 (ORDEN_NO_DECLARADO) PENDIENTE. No Word export."
  ),
  list(
    method_id      = "chi_cuadrado",
    label          = "Chi-cuadrado de Pearson / exacta de Fisher",
    frontend_vis   = TRUE,
    frontend_fields= c("varAName","varAItems","varBName","varBItems","chiVarType","measurementLevelA",
                       "measurementLevelB","yatesCorrection","chiEffectSize","minExpected"),
    ts_type        = FALSE,
    node_routed    = TRUE,
    r_function     = "compute_chisquare()",
    r_file         = "chi_square.R",
    db_column      = "chi_square",
    word_supported = TRUE,
    validated_ci   = "L (audit_logistic_chisq.R)",
    status         = "VALIDATED_WITH_RESTRICTIONS",
    notes          = "F-021: measurement_level='nominal' exime de guard continuidad. ts_type=FALSE: 'chi_cuadrado' no en AnalysisConfig.analysis_category backend."
  ),
  list(
    method_id      = "discriminante",
    label          = "Análisis discriminante lineal (LDA)",
    frontend_vis   = FALSE,
    frontend_fields= c("varAName","varAItems","groupVar","ldaMethod","ldaCV"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "run_discriminant()",
    r_file         = "discriminant.R",
    db_column      = "discriminant",
    word_supported = FALSE,
    validated_ci   = "I (audit_ttest_discriminant.R)",
    status         = "EXPERIMENTAL",
    notes          = "No Word export. No singular matrix guard (P2-SINGULAR). frontend via ?method=discriminante."
  ),
  list(
    method_id      = "cluster",
    label          = "Análisis de clústeres (k-means)",
    frontend_vis   = TRUE,
    frontend_fields= c("varAName","varAItems","nClusters","standardize","seed"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "run_cluster()",
    r_file         = "cluster.R",
    db_column      = "cluster",
    word_supported = FALSE,
    validated_ci   = "NONE",
    status         = "EXPERIMENTAL",
    notes          = "No suite de tests en CI actual. No Word export."
  ),
  list(
    method_id      = "instrumentos",
    label          = "Validación de instrumento (AFE + AFC + Alpha + CR + AVE + HTMT + V Aiken)",
    frontend_vis   = TRUE,
    frontend_fields= c("varAName","varAItems","varADimensions","varBName","varBItems","nFactors",
                       "rotation","estimator","enableVAiken","vAikenJudges","vAikenScaleMin","vAikenScaleMax","vAikenMatrix"),
    ts_type        = FALSE,
    node_routed    = TRUE,
    r_function     = "compute_instruments()",
    r_file         = "instruments.R",
    db_column      = "instruments",
    word_supported = TRUE,
    validated_ci   = "O (audit_guards_comprehensive.R), P (audit_afe.R), Q (audit_afc.R)",
    status         = "VALIDATED",
    notes          = "AFE: 33/33 tests green. AFC: 36/36 green. Guards: 30/30. ts_type=FALSE: 'instrumentos' no en AnalysisConfig.analysis_category del backend."
  ),
  list(
    method_id      = "cronbach",
    label          = "Confiabilidad — Alfa de Cronbach + Omega McDonald",
    frontend_vis   = FALSE,
    frontend_fields= c("varAName","varAItems","minRIT","calcOmega","bootstrapCI","alphaModel"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "run_cronbach_only()",
    r_file         = "cronbach_only.R",
    db_column      = "cronbach_only",
    word_supported = FALSE,
    validated_ci   = "M (audit_reliability.R)",
    status         = "VALIDATED",
    notes          = "frontend via ?method=cronbach."
  ),
  list(
    method_id      = "descriptivo",
    label          = "Análisis descriptivo completo (M+DE+Baremos+Frecuencias+Normalidad)",
    frontend_vis   = FALSE,
    frontend_fields= c("varAName","varAItems","scale","baremoMethod","baremoLevels","normalityTest","confidenceLevel"),
    ts_type        = FALSE,
    node_routed    = TRUE,
    r_function     = "run_analisis_descriptivo()",
    r_file         = "analisis_descriptivo.R",
    db_column      = "analisis_descriptivo",
    word_supported = FALSE,
    validated_ci   = "NONE",
    status         = "EXPERIMENTAL",
    notes          = "DB column exists in schema but NOT persisted by analysis.service.ts (gap). No Word. frontend via ?method=descriptivo."
  ),
  list(
    method_id      = "frecuencias",
    label          = "Frecuencias",
    frontend_vis   = FALSE,
    frontend_fields= c("varAName","varAItems","scale"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "run_frequencies()",
    r_file         = "frequencies.R",
    db_column      = "frequencies",
    word_supported = FALSE,
    validated_ci   = "NONE",
    status         = "EXPERIMENTAL",
    notes          = "frontend via ?method=frecuencias. No Word export."
  ),
  list(
    method_id      = "baremos",
    label          = "Baremos",
    frontend_vis   = FALSE,
    frontend_fields= c("varAName","varAItems","scale","baremoMethod","baremoLevels"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "run_baremos_only()",
    r_file         = "baremos_only.R",
    db_column      = "baremos_only",
    word_supported = FALSE,
    validated_ci   = "NONE",
    status         = "EXPERIMENTAL",
    notes          = "frontend via ?method=baremos. No Word export."
  ),
  list(
    method_id      = "descriptivos",
    label          = "Descriptivos completos (tabla APA extendida)",
    frontend_vis   = FALSE,
    frontend_fields= c("varAName","varAItems","scale"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "run_descriptives_full()",
    r_file         = "descriptives_full.R",
    db_column      = "descriptives_full",
    word_supported = FALSE,
    validated_ci   = "NONE",
    status         = "EXPERIMENTAL",
    notes          = "frontend via ?method=descriptivos. No Word export."
  ),
  list(
    method_id      = "structural_model",
    label          = "PLS-SEM (Modelos de ecuaciones estructurales PLS)",
    frontend_vis   = TRUE,
    frontend_fields= c("plsConstructs","plsPaths","nBoot","groupVar","scaleMin","scaleMax","ipmaTarget"),
    ts_type        = TRUE,
    node_routed    = TRUE,
    r_function     = "pls_sem_engine.R (standalone script)",
    r_file         = "pls_sem_engine.R",
    db_column      = "interpretations (pls sub-field)",
    word_supported = TRUE,
    validated_ci   = "NONE",
    status         = "EXPERIMENTAL",
    notes          = "Ruta separada: invokePlsEngine() — no usa run_analysis.R. Word via pls_word_wrapper.R."
  ),
  list(
    method_id      = "mediacion_simple",
    label          = "Mediación simple (OLS + Bootstrap IC percentil)",
    frontend_vis   = FALSE,
    frontend_fields= NULL,
    ts_type        = FALSE,
    node_routed    = FALSE,
    r_function     = "run_mediation_simple()",
    r_file         = "mediation.R",
    db_column      = NULL,
    word_supported = FALSE,
    validated_ci   = "N (audit_mediation.R) — función R validada, routing PENDIENTE",
    status         = "NOT_IMPLEMENTED",
    notes          = "mediation.R y tests audit_mediation.R existen. Falta: routing en run_analysis.R, analysis_category='mediacion', frontend UI, DB column."
  ),
  list(
    method_id      = "mediacion_serial",
    label          = "Mediación serial (2+ mediadores)",
    frontend_vis   = FALSE,
    frontend_fields= NULL,
    ts_type        = FALSE,
    node_routed    = FALSE,
    r_function     = NULL,
    r_file         = NULL,
    db_column      = NULL,
    word_supported = FALSE,
    validated_ci   = "NONE",
    status         = "NOT_IMPLEMENTED",
    notes          = "No hay función R, no hay routing, no hay frontend. Marcado como próximamente."
  ),
  list(
    method_id      = "factorial",
    label          = "Análisis factorial confirmatorio / exploratorio avanzado",
    frontend_vis   = FALSE,
    frontend_fields= NULL,
    ts_type        = FALSE,
    node_routed    = FALSE,
    r_function     = NULL,
    r_file         = NULL,
    db_column      = NULL,
    word_supported = FALSE,
    validated_ci   = "NONE",
    status         = "NOT_IMPLEMENTED",
    notes          = "Visible en grid de análisis pero available=false (disabled). No routing. Etiqueta 'Próximamente' en UI."
  )
)

# ── Verificaciones de integridad ─────────────────────────────────────────────

PASS <- 0; FAIL <- 0
assert <- function(id, desc, cond, val="") {
  if (isTRUE(cond)) { cat(sprintf("[PASS] R.%s: %s\n", id, desc)); PASS <<- PASS + 1 }
  else { cat(sprintf("[FAIL] R.%s: %s — got: %s\n", id, desc, toString(val))); FAIL <<- FAIL + 1 }
}

# R.INV.01 — hay exactamente 22 métodos en el inventario
assert("INV.01", "Inventario contiene 22 entradas",
       length(INVENTORY) == 22, length(INVENTORY))

# R.INV.02 — todos los métodos tienen method_id
assert("INV.02", "Todos los métodos tienen method_id no vacío",
       all(sapply(INVENTORY, function(m) nchar(m$method_id) > 0)))

# R.INV.03 — status válidos
valid_statuses <- c("VALIDATED","VALIDATED_WITH_RESTRICTIONS","EXPERIMENTAL","NOT_IMPLEMENTED","HIDDEN")
assert("INV.03", "Todos los status son válidos",
       all(sapply(INVENTORY, function(m) m$status %in% valid_statuses)),
       paste(sapply(INVENTORY, function(m) if (!m$status %in% valid_statuses) m$method_id else NULL), collapse=", "))

# R.INV.04 — métodos VALIDATED tienen validated_ci no vacío
validated <- Filter(function(m) m$status %in% c("VALIDATED","VALIDATED_WITH_RESTRICTIONS"), INVENTORY)
assert("INV.04", "Métodos VALIDATED/VALIDATED_WITH_RESTRICTIONS tienen validated_ci",
       all(sapply(validated, function(m) !is.null(m$validated_ci) && nchar(as.character(m$validated_ci)) > 0)))

# R.INV.05 — métodos NOT_IMPLEMENTED NO tienen node_routed=TRUE
not_impl <- Filter(function(m) m$status == "NOT_IMPLEMENTED", INVENTORY)
assert("INV.05", "Métodos NOT_IMPLEMENTED no tienen node_routed=TRUE",
       all(sapply(not_impl, function(m) !isTRUE(m$node_routed))))

# R.INV.06 — métodos con Word support tienen db_column
with_word <- Filter(function(m) isTRUE(m$word_supported), INVENTORY)
assert("INV.06", "Métodos con word_supported=TRUE tienen db_column",
       all(sapply(with_word, function(m) !is.null(m$db_column) && nchar(as.character(m$db_column)) > 0)))

# R.INV.07 — correlacional está VALIDATED y node_routed
corr <- Filter(function(m) m$method_id == "correlacional", INVENTORY)[[1]]
assert("INV.07", "Correlacional es VALIDATED y node_routed",
       corr$status == "VALIDATED" && isTRUE(corr$node_routed))

# R.INV.08 — mediacion_simple es NOT_IMPLEMENTED y node_routed=FALSE
med <- Filter(function(m) m$method_id == "mediacion_simple", INVENTORY)[[1]]
assert("INV.08", "Mediación simple es NOT_IMPLEMENTED y sin routing",
       med$status == "NOT_IMPLEMENTED" && !isTRUE(med$node_routed))

# R.INV.09 — mediacion_serial es NOT_IMPLEMENTED
med_s <- Filter(function(m) m$method_id == "mediacion_serial", INVENTORY)[[1]]
assert("INV.09", "Mediación serial es NOT_IMPLEMENTED",
       med_s$status == "NOT_IMPLEMENTED")

# R.INV.10 — instrumentos es VALIDATED
instr <- Filter(function(m) m$method_id == "instrumentos", INVENTORY)[[1]]
assert("INV.10", "Instrumentos es VALIDATED",
       instr$status == "VALIDATED")

# R.INV.11 — factorial es NOT_IMPLEMENTED
fact <- Filter(function(m) m$method_id == "factorial", INVENTORY)[[1]]
assert("INV.11", "Factorial es NOT_IMPLEMENTED",
       fact$status == "NOT_IMPLEMENTED")

# R.INV.12 — regresion_ordinal tiene nota sobre F-024 PENDIENTE
ord <- Filter(function(m) m$method_id == "regresion_ordinal", INVENTORY)[[1]]
assert("INV.12", "regresion_ordinal tiene nota sobre F-024 PENDIENTE",
       grepl("F-024", ord$notes %||% ""))

# R.INV.13 — descriptivo tiene nota sobre gap en service.ts
desc_m <- Filter(function(m) m$method_id == "descriptivo", INVENTORY)[[1]]
assert("INV.13", "descriptivo documenta gap de persistencia en service.ts",
       grepl("gap|NOT persisted|service.ts", desc_m$notes %||% ""))

# R.INV.14 — frontend_visible: los métodos en ANALYSIS_TYPES grid son TRUE
grid_methods <- c("structural_model","correlacional","regresion","comparacion","anova","logistica","chi_cuadrado","instrumentos")
for (mid in grid_methods) {
  m <- Filter(function(x) x$method_id == mid || (mid == "logistica" && x$method_id == "logistica_binaria"), INVENTORY)
  if (length(m) == 0) m <- Filter(function(x) grepl(mid, x$method_id), INVENTORY)
  if (length(m) > 0) {
    assert(paste0("INV.14.", mid), paste0(mid, " es frontend_visible"),
           isTRUE(m[[1]]$frontend_vis))
  }
}

# ── Resumen ──────────────────────────────────────────────────────────────────
cat(sprintf("\n=== RESUMEN [R - Block1 Inventory]: %d PASS  %d FAIL ===\n", PASS, FAIL))

# Conteo por status
statuses <- table(sapply(INVENTORY, function(m) m$status))
cat("Status breakdown:\n")
for (s in names(statuses)) cat(sprintf("  %-35s: %d\n", s, statuses[[s]]))

if (FAIL > 0) quit(status=1)
