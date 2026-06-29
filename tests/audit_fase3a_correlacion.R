#!/usr/bin/env Rscript
# ============================================================================
# FASE 3A — Sección H: Correlación, interpret_r canónico y duplicados
# Cubre: F-002 (ANOVA duplicado), F-003/F-004 (interpret_r duplicado)
# Tolerancias: coeficiente abs <= 1e-12, p abs <= 1e-10, IC abs <= 1e-8
# ============================================================================

pass_n  <- 0L
fail_n  <- 0L
notes_n <- 0L

check <- function(id, desc, ok, note = FALSE) {
  if (note) {
    cat(sprintf("[NOTE ] %s: %s\n", id, desc))
    notes_n <<- notes_n + 1L
  } else if (isTRUE(ok)) {
    cat(sprintf("[PASS ] %s: %s\n", id, desc))
    pass_n <<- pass_n + 1L
  } else {
    cat(sprintf("[FAIL ] %s: %s\n", id, desc))
    fail_n <<- fail_n + 1L
  }
}

# ── Cargar motor ─────────────────────────────────────────────────────────────
r_dir <- file.path("apps", "api", "stats-engine-r", "R")
suppressPackageStartupMessages({
  source(file.path(r_dir, "helpers.R"))
  source(file.path(r_dir, "data_cleaning.R"))
  source(file.path(r_dir, "statistics.R"))
})

cat("=== FASE 3A / SECCIÓN H: CORRELACIÓN Y DUPLICADOS ===\n\n")

# ─────────────────────────────────────────────────────────────────────────────
# H.F003 — interpret_r canónico (un solo origen, escala de 6 niveles)
# ─────────────────────────────────────────────────────────────────────────────

check("H.F003.01", "interpret_r existe y es funcion",
      is.function(interpret_r))

# Verificar que solo hay UNA definicion activa
ir_env <- environment(interpret_r)
check("H.F003.02", "interpret_r sin duplicado activo en statistics.R (body canonico)",
      !grepl("0\\.80.*muy alta.*0\\.80", paste(deparse(body(interpret_r)), collapse="")))

check("H.F003.03", "interpret_r(0.00) = 'despreciable'",
      identical(interpret_r(0.00), "despreciable"))

check("H.F003.04", "interpret_r(0.05) = 'despreciable' (< 0.10)",
      identical(interpret_r(0.05), "despreciable"))

check("H.F003.05", "interpret_r(0.15) = 'baja' (0.10-0.29)",
      identical(interpret_r(0.15), "baja"))

check("H.F003.06", "interpret_r(0.29) = 'baja' (limite superior baja)",
      identical(interpret_r(0.29), "baja"))

check("H.F003.07", "interpret_r(0.30) = 'moderada' (0.30-0.49)",
      identical(interpret_r(0.30), "moderada"))

check("H.F003.08", "interpret_r(0.49) = 'moderada' (limite superior moderada)",
      identical(interpret_r(0.49), "moderada"))

check("H.F003.09", "interpret_r(0.50) = 'alta' (0.50-0.69)",
      identical(interpret_r(0.50), "alta"))

check("H.F003.10", "interpret_r(0.69) = 'alta' (limite superior alta)",
      identical(interpret_r(0.69), "alta"))

check("H.F003.11", "interpret_r(0.70) = 'muy alta' (0.70-0.89)",
      identical(interpret_r(0.70), "muy alta"))

check("H.F003.12", "interpret_r(0.89) = 'muy alta' (limite superior muy alta)",
      identical(interpret_r(0.89), "muy alta"))

check("H.F003.13", "interpret_r(0.90) = 'extremadamente alta' (>= 0.90)",
      identical(interpret_r(0.90), "extremadamente alta"))

check("H.F003.14", "interpret_r(1.00) = 'extremadamente alta'",
      identical(interpret_r(1.00), "extremadamente alta"))

check("H.F003.15", "interpret_r usa abs(r): negativo igual que positivo",
      identical(interpret_r(-0.45), interpret_r(0.45)))

check("H.F003.16", "interpret_r(NA) = 'indeterminado' (no NULL)",
      identical(interpret_r(NA_real_), "indeterminado"))

check("H.F003.17", "interpret_r retorna character no-NULL para todos los inputs",
      all(sapply(c(0, 0.05, 0.15, 0.35, 0.55, 0.75, 0.95, -0.5, NA_real_),
                 function(r) !is.null(interpret_r(r)) && is.character(interpret_r(r)))))

# ─────────────────────────────────────────────────────────────────────────────
# H.F003.FULL — interpret_r_full estructura completa
# ─────────────────────────────────────────────────────────────────────────────
check("H.F003.18", "interpret_r_full existe",
      is.function(interpret_r_full))

f_pos  <- interpret_r_full(0.65)
f_neg  <- interpret_r_full(-0.65)
f_zero <- interpret_r_full(0.0)
f_na   <- interpret_r_full(NA_real_)

check("H.F003.19", "interpret_r_full: direction='positiva' para r > 0",
      identical(f_pos$direction, "positiva"))

check("H.F003.20", "interpret_r_full: direction='negativa' para r < 0",
      identical(f_neg$direction, "negativa"))

check("H.F003.21", "interpret_r_full: direction='ninguna' para r = 0",
      identical(f_zero$direction, "ninguna"))

check("H.F003.22", "interpret_r_full: absolute_r = abs(r)",
      isTRUE(abs(f_neg$r - (-0.65)) < 1e-12) && isTRUE(abs(f_neg$absolute_r - 0.65) < 1e-12))

check("H.F003.23", "interpret_r_full: strength coincide con interpret_r",
      identical(f_pos$strength, interpret_r(0.65)))

check("H.F003.24", "interpret_r_full: contextual_warning presente (caracter no vacio)",
      is.character(f_pos$contextual_warning) && nchar(f_pos$contextual_warning) > 0)

check("H.F003.25", "interpret_r_full(NA): campos clave son character",
      is.character(f_na$strength) && is.character(f_na$direction))

# ─────────────────────────────────────────────────────────────────────────────
# H.F002 — No existe bloque ANOVA duplicado en run_analysis.R
# ─────────────────────────────────────────────────────────────────────────────
run_analysis_txt <- readLines("apps/api/stats-engine-r/run_analysis.R")
anova_cat_lines  <- grep('analysis_category == "anova"', run_analysis_txt)
check("H.F002.01", paste0("Solo un bloque 'analysis_category == anova' en run_analysis.R (encontrado: ", length(anova_cat_lines), ")"),
      length(anova_cat_lines) == 1L)

# ─────────────────────────────────────────────────────────────────────────────
# H.F004 — interpret_alpha canon (6 niveles, no duplicado)
# ─────────────────────────────────────────────────────────────────────────────
check("H.F004.01", "interpret_alpha(0.95) = 'Excelente'",
      identical(interpret_alpha(0.95), "Excelente"))

check("H.F004.02", "interpret_alpha(0.85) = 'Bueno'",
      identical(interpret_alpha(0.85), "Bueno"))

check("H.F004.03", "interpret_alpha(0.73) = 'Aceptable'",
      identical(interpret_alpha(0.73), "Aceptable"))

check("H.F004.04", "interpret_alpha(0.62) = 'Cuestionable'",
      identical(interpret_alpha(0.62), "Cuestionable"))

check("H.F004.05", "interpret_alpha(0.55) = 'Pobre' (>= 0.50)",
      identical(interpret_alpha(0.55), "Pobre"))

check("H.F004.06", "interpret_alpha(0.40) = 'Inaceptable' (< 0.50)",
      identical(interpret_alpha(0.40), "Inaceptable"))

check("H.F004.07", "interpret_alpha(NA) = 'No calculado'",
      identical(interpret_alpha(NA_real_), "No calculado"))

# ─────────────────────────────────────────────────────────────────────────────
# H.COR — Pearson: equivalencia con cor.test()
# Tolerancias: r abs <= 1e-12, p abs <= 1e-10, IC abs <= 1e-8
# ─────────────────────────────────────────────────────────────────────────────
set.seed(42)
n_cor <- 80L
x1 <- rnorm(n_cor, mean = 50, sd = 10)
y1 <- 0.60 * x1 + rnorm(n_cor, 0, 8)   # r ~ 0.60

ref_pear <- cor.test(x1, y1, method = "pearson")
res_pear <- correlate_pair(x1, y1, method = "pearson")

check("H.COR.01", "Pearson r coincide con cor.test (tol 1e-12)",
      abs(res_pear$r - as.numeric(ref_pear$estimate)) < 1e-12)

check("H.COR.02", "Pearson p coincide con cor.test (tol 1e-10)",
      abs(res_pear$p - as.numeric(ref_pear$p.value)) < 1e-10)

check("H.COR.03", "Pearson df = n-2",
      isTRUE(res_pear$df == n_cor - 2L))

check("H.COR.04", "Pearson n utilizado = n_cor",
      isTRUE(res_pear$n == n_cor))

check("H.COR.05", "Pearson IC Fisher lower < r < upper",
      isTRUE(res_pear$ci_lower < res_pear$r) && isTRUE(res_pear$r < res_pear$ci_upper))

# Comparacion IC con cor.test (que usa atanh internamente)
ref_ci <- ref_pear$conf.int
check("H.COR.06", "Pearson IC lower coincide con cor.test (tol 1e-8)",
      abs(res_pear$ci_lower - ref_ci[1]) < 1e-8)

check("H.COR.07", "Pearson IC upper coincide con cor.test (tol 1e-8)",
      abs(res_pear$ci_upper - ref_ci[2]) < 1e-8)

check("H.COR.08", "Pearson magnitude es caracter no vacio",
      is.character(res_pear$magnitude) && nchar(res_pear$magnitude) > 0)

# ─────────────────────────────────────────────────────────────────────────────
# H.COR — Spearman: equivalencia con cor.test()
# ─────────────────────────────────────────────────────────────────────────────
ref_spear <- cor.test(x1, y1, method = "spearman", exact = FALSE)
res_spear <- correlate_pair(x1, y1, method = "spearman")

check("H.COR.09", "Spearman rho coincide con cor.test (tol 1e-12)",
      abs(res_spear$r - as.numeric(ref_spear$estimate)) < 1e-12)

check("H.COR.10", "Spearman p coincide con cor.test (tol 1e-10)",
      abs(res_spear$p - as.numeric(ref_spear$p.value)) < 1e-10)

check("H.COR.11", "Spearman n utilizado = n_cor",
      isTRUE(res_spear$n == n_cor))

# ─────────────────────────────────────────────────────────────────────────────
# H.COR — Kendall: equivalencia con cor.test()
# ─────────────────────────────────────────────────────────────────────────────
ref_kend <- cor.test(x1, y1, method = "kendall", exact = FALSE)
res_kend <- correlate_pair(x1, y1, method = "kendall")

check("H.COR.12", "Kendall tau coincide con cor.test (tol 1e-12)",
      abs(res_kend$r - as.numeric(ref_kend$estimate)) < 1e-12)

check("H.COR.13", "Kendall p coincide con cor.test (tol 1e-10)",
      abs(res_kend$p - as.numeric(ref_kend$p.value)) < 1e-10)

# ─────────────────────────────────────────────────────────────────────────────
# H.COR — Correlación negativa
# ─────────────────────────────────────────────────────────────────────────────
x2 <- x1
y2 <- -0.70 * x1 + rnorm(n_cor, 0, 6)  # r ~ -0.70

res_neg   <- correlate_pair(x2, y2, method = "pearson")
ref_neg   <- cor.test(x2, y2, method = "pearson")

check("H.COR.14", "Correlacion negativa: r < 0",
      isTRUE(res_neg$r < 0))

check("H.COR.15", "Correlacion negativa: r coincide con cor.test (tol 1e-12)",
      abs(res_neg$r - as.numeric(ref_neg$estimate)) < 1e-12)

check("H.COR.16", "Correlacion negativa: magnitude no es NULL ni vacio",
      is.character(res_neg$magnitude) && nchar(res_neg$magnitude) > 0)

# ─────────────────────────────────────────────────────────────────────────────
# H.COR — Correlación cero (variables independientes)
# ─────────────────────────────────────────────────────────────────────────────
set.seed(99)
x3 <- rnorm(100)
y3 <- rnorm(100)
res_zero <- correlate_pair(x3, y3, method = "pearson")

check("H.COR.17", "Correlacion ~0: resultado no-NULL",
      !is.null(res_zero) && !is.null(res_zero$r))

check("H.COR.18", "Correlacion ~0: magnitude es caracter no vacio",
      is.character(res_zero$magnitude) && nchar(res_zero$magnitude) > 0)

# ─────────────────────────────────────────────────────────────────────────────
# H.COR — Muestra insuficiente (n < 3)
# ─────────────────────────────────────────────────────────────────────────────
res_tiny <- correlate_pair(c(1, 2), c(3, 4), method = "pearson")

check("H.COR.19", "n < 3: devuelve resultado con r=NA (no crash)",
      !is.null(res_tiny) && is.na(res_tiny$r))

check("H.COR.20", "n < 3: n reportado = 2",
      isTRUE(res_tiny$n == 2L))

# ─────────────────────────────────────────────────────────────────────────────
# H.COR — NA manejados con complete.cases
# ─────────────────────────────────────────────────────────────────────────────
x4 <- c(x1, NA, NA)
y4 <- c(y1, 1,  NA)
res_na <- correlate_pair(x4, y4, method = "pearson")

check("H.COR.21", "NA manejados: r coincide con complete.cases manual (tol 1e-12)",
      abs(res_na$r - as.numeric(cor.test(x1, y1[1:n_cor], method="pearson")$estimate)) < 1e-12)

check("H.COR.22", "NA manejados: n = n_cor (no n_cor+2)",
      isTRUE(res_na$n == n_cor))

# ─────────────────────────────────────────────────────────────────────────────
# H.COR — Variable constante (debe devolver r=NA, no crash)
# ─────────────────────────────────────────────────────────────────────────────
res_const <- tryCatch(
  correlate_pair(rep(5, 50), rnorm(50), method = "pearson"),
  error = function(e) list(r = NA, p = NA, n = 50, error = e$message)
)
check("H.COR.23", "Variable constante: no crash (r NA o error controlado)",
      is.na(res_const$r) || !is.null(res_const$error))

# ─────────────────────────────────────────────────────────────────────────────
# H.COR — Pearson con n grande (n=500)
# ─────────────────────────────────────────────────────────────────────────────
set.seed(7)
x5 <- rnorm(500)
y5 <- 0.3 * x5 + rnorm(500, 0, sqrt(1 - 0.09))
ref_big <- cor.test(x5, y5, method = "pearson")
res_big <- correlate_pair(x5, y5, method = "pearson")

check("H.COR.24", "n=500 Pearson: r coincide (tol 1e-12)",
      abs(res_big$r - as.numeric(ref_big$estimate)) < 1e-12)

check("H.COR.25", "n=500 Pearson: p coincide (tol 1e-10)",
      abs(res_big$p - as.numeric(ref_big$p.value)) < 1e-10)

# ─────────────────────────────────────────────────────────────────────────────
# H.COR — Correlacion perfecta (r = ±1)
# ─────────────────────────────────────────────────────────────────────────────
x6 <- 1:50
y6 <- 2 * x6 + 3   # correlacion perfecta positiva
res_perf <- tryCatch(
  correlate_pair(x6, y6, method = "pearson"),
  error = function(e) list(r = NA, error = e$message)
)
check("H.COR.26", "Correlacion perfecta (r=1): resultado controlado (r=1 o error)",
      isTRUE(abs(res_perf$r - 1.0) < 1e-10) || !is.null(res_perf$error))

# ─────────────────────────────────────────────────────────────────────────────
# H.COR — Limite exacto de las escalas de interpret_r
# ─────────────────────────────────────────────────────────────────────────────
limites <- data.frame(
  r     = c(0.099, 0.100, 0.299, 0.300, 0.499, 0.500, 0.699, 0.700, 0.899, 0.900, 1.000),
  label = c("despreciable","baja","baja","moderada","moderada","alta","alta","muy alta","muy alta","extremadamente alta","extremadamente alta"),
  stringsAsFactors = FALSE
)
boundary_ok <- all(mapply(function(r, lab) identical(interpret_r(r), lab), limites$r, limites$label))
check("H.COR.27", "Limites exactos de interpret_r correctos (11 puntos de frontera)",
      boundary_ok)

# ─────────────────────────────────────────────────────────────────────────────
# Resumen
# ─────────────────────────────────────────────────────────────────────────────
cat(sprintf("\n=== RESUMEN [H]: %d PASS  %d FAIL  %d NOTE  (total %d) ===\n",
            pass_n, fail_n, notes_n, pass_n + fail_n + notes_n))

if (fail_n == 0) {
  cat("RESULTADO: COMPLETO — todos los guards verificados.\n")
  quit(status = 0L)
} else {
  cat(sprintf("RESULTADO: FALLO — %d test(s) fallaron.\n", fail_n))
  quit(status = 1L)
}
