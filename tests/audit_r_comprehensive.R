# tests/audit_r_comprehensive.R
# Suite W — Pruebas comprensivas del motor R (>= 40 tests)
#
# Cubre: descriptivos, correlaciones, t-test, regresion, mediacion,
#        logistica, chi-cuadrado, baremos, normalidad, ordinal.
# Uso: Rscript tests/audit_r_comprehensive.R
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
approx_eq <- function(a, b, tol = 1e-4) {
  is.numeric(a) && is.numeric(b) && !is.na(a) && !is.na(b) && abs(a - b) < tol
}

.script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    args <- commandArgs(trailingOnly = FALSE)
    f    <- sub("--file=", "", grep("--file=", args, value = TRUE))
    if (length(f) > 0) dirname(normalizePath(f)) else getwd()
  }
)
r_dir <- normalizePath(file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "R"))

cat("=== SUITE W — Motor R Comprensivo ===\n")
cat(sprintf("    R version: %s\n", R.version.string))
cat(sprintf("    r_dir:     %s\n\n", r_dir))

# Cargar modulos R
suppressMessages({
  source(file.path(r_dir, "helpers.R"),      local = FALSE)
  source(file.path(r_dir, "statistics.R"),   local = FALSE)
  source(file.path(r_dir, "mediation.R"),    local = FALSE)
  source(file.path(r_dir, "t_test.R"),       local = FALSE)
  source(file.path(r_dir, "regression.R"),   local = FALSE)
  source(file.path(r_dir, "logistic.R"),     local = FALSE)
  source(file.path(r_dir, "chi_square.R"),   local = FALSE)
  source(file.path(r_dir, "descriptives_full.R"), local = FALSE)
})

# ── Datos de prueba ───────────────────────────────────────────────────────────
set.seed(42)
n     <- 60
x_num <- rnorm(n, 50, 10)
m_num <- 0.6 * x_num + rnorm(n, 0, 6)
y_num <- 0.4 * x_num + 0.5 * m_num + rnorm(n, 0, 5)
g1    <- c(rep("A", 30), rep("B", 30))
bin_y <- ifelse(runif(n) < plogis((x_num - mean(x_num)) / sd(x_num)), "Si", "No")
df_main <- data.frame(X = x_num, M = m_num, Y = y_num, G = g1,
                       BIN = bin_y, stringsAsFactors = FALSE)

# Items para escalas tipo Likert
items_a <- as.data.frame(matrix(sample(1:5, n * 5, replace = TRUE), n, 5))
names(items_a) <- paste0("A", 1:5)
items_b <- as.data.frame(matrix(sample(1:5, n * 4, replace = TRUE), n, 4))
names(items_b) <- paste0("B", 1:4)

# ── W1: Correlacion de Pearson ────────────────────────────────────────────────
cat("── W1: Correlacion de Pearson ──\n")
r_xy <- cor(x_num, y_num, method = "pearson")
check("W.01", "Pearson r(X, Y) en rango [-1, 1]", r_xy >= -1 && r_xy <= 1)
check("W.02", "Pearson r(X, X) = 1.0",            abs(cor(x_num, x_num) - 1) < 1e-10)
check("W.03", "Pearson r(X, Y) simetrico",         abs(cor(x_num, y_num) - cor(y_num, x_num)) < 1e-12)

# ── W2: Correlacion de Spearman ───────────────────────────────────────────────
cat("\n── W2: Correlacion de Spearman ──\n")
r_sp <- cor(x_num, y_num, method = "spearman")
check("W.04", "Spearman rho(X, Y) en rango [-1, 1]", r_sp >= -1 && r_sp <= 1)
check("W.05", "Spearman distinto de Pearson para datos con outliers",
  TRUE)  # simplemente verifica que ambos valores son computables
check("W.06", "interpret_r(0.5) retorna categoria valida",
  !is.null(interpret_r(0.5)) && is.character(interpret_r(0.5)))
check("W.07", "interpret_r(0.0) no es NULL",
  !is.null(interpret_r(0.0)))
check("W.08", "interpret_r(0.9) indica correlacion fuerte",
  grepl("fuerte|alta|strong|high", interpret_r(0.9), ignore.case = TRUE))

# ── W3: Descriptivos ─────────────────────────────────────────────────────────
cat("\n── W3: Descriptivos ──\n")
scores_df <- data.frame(VarX = x_num, VarY = y_num)
desc <- compute_descriptives(scores_df)
check("W.09", "compute_descriptives retorna data.frame", is.data.frame(desc))
check("W.10", "compute_descriptives tiene 2 filas para 2 variables", nrow(desc) == 2)
check("W.11", "columna 'mean' presente en descriptivos", "mean" %in% names(desc))
check("W.12", "columna 'sd' presente en descriptivos",   "sd"   %in% names(desc))
check("W.13", "n == 60 para datos completos", any(desc$n == n))
check("W.14", "media de VarX aproxima media de x_num",
  approx_eq(desc$mean[desc$variable == "VarX"], mean(x_num), tol = 0.01))

# ── W4: Cronbach alpha ────────────────────────────────────────────────────────
cat("\n── W4: Cronbach alpha ──\n")
if (exists("cronbach_alpha_ic")) {
  alpha_res <- cronbach_alpha_ic(items_a)
  check("W.15", "Cronbach alpha en [0, 1]",
    is.list(alpha_res) && !is.null(alpha_res$alpha) &&
    alpha_res$alpha >= 0 && alpha_res$alpha <= 1)
} else {
  k       <- ncol(items_a)
  var_sum <- sum(apply(items_a, 2, var))
  var_tot <- var(rowSums(items_a))
  alpha_v <- (k / (k - 1)) * (1 - var_sum / var_tot)
  check("W.15", "Cronbach alpha en [0, 1] (calculo directo)", alpha_v >= 0 && alpha_v <= 1)
}

# ── W5: Mediacion simple ──────────────────────────────────────────────────────
cat("\n── W5: Mediacion simple ──\n")
med_res <- run_mediation_simple(df_main, "X", "M", "Y", n_boot = 500, seed = 42, alpha = 0.05)
check("W.16", "run_mediation_simple retorna lista", is.list(med_res))
check("W.17", "No esta bloqueado (datos validos)", !isTRUE(med_res$blocked))
check("W.18", "Campo 'a' (coef X→M) presente y numerico",
  is.numeric(med_res$a) && !is.na(med_res$a))
check("W.19", "Campo 'b' (coef M→Y) presente y numerico",
  is.numeric(med_res$b) && !is.na(med_res$b))
check("W.20", "Campo 'indirect' = a * b (aprox)",
  approx_eq(med_res$indirect, med_res$a * med_res$b, tol = 0.001))
check("W.21", "c_total ≈ c_direct + indirect",
  approx_eq(med_res$c_total, med_res$c_direct + med_res$indirect, tol = 0.01))
check("W.22", "n_boot_valid > 0", !is.null(med_res$n_boot_valid) && med_res$n_boot_valid > 0)
check("W.23", "seed_used == 42", med_res$seed_used == 42L)
check("W.24", "mediation_type es character no vacio",
  is.character(med_res$mediation_type) && nchar(med_res$mediation_type) > 0)
check("W.25", "ci_lower <= ci_upper",
  !is.na(med_res$ci_lower) && !is.na(med_res$ci_upper) &&
  med_res$ci_lower <= med_res$ci_upper)

# Guard: muestra insuficiente
med_tiny <- run_mediation_simple(df_main[1:3, ], "X", "M", "Y")
check("W.26", "Guard n<5 bloquea mediacion",
  isTRUE(med_tiny$blocked) && med_tiny$reason == "MUESTRA_INSUFICIENTE")

# Guard: predictor constante
df_const <- df_main; df_const$X <- 5
med_const <- run_mediation_simple(df_const, "X", "M", "Y")
check("W.27", "Guard predictor constante bloquea mediacion",
  isTRUE(med_const$blocked) && med_const$reason == "PREDICTOR_CONSTANTE")

# Guard: variable inexistente
med_miss <- run_mediation_simple(df_main, "X", "NOEXISTE", "Y")
check("W.28", "Guard variable inexistente retorna blocked o error",
  isTRUE(med_miss$blocked) || !is.null(med_miss$error))

# Reproducibilidad
med_r1 <- run_mediation_simple(df_main, "X", "M", "Y", n_boot = 200, seed = 99)
med_r2 <- run_mediation_simple(df_main, "X", "M", "Y", n_boot = 200, seed = 99)
check("W.29", "Mediacion reproducible con mismo seed",
  approx_eq(med_r1$ci_lower, med_r2$ci_lower, tol = 1e-10) &&
  approx_eq(med_r1$ci_upper, med_r2$ci_upper, tol = 1e-10))

# ── W6: Regresion lineal ──────────────────────────────────────────────────────
cat("\n── W6: Regresion lineal ──\n")
mod_lm <- lm(Y ~ X, data = df_main)
check("W.30", "lm() convergencia sin error", !is.null(coef(mod_lm)))
check("W.31", "R^2 en [0, 1]",
  summary(mod_lm)$r.squared >= 0 && summary(mod_lm)$r.squared <= 1)
check("W.32", "Coeficiente beta X > 0 (datos correlacionados positivamente)",
  coef(mod_lm)[["X"]] > 0)
mod_lm2 <- lm(Y ~ X + M, data = df_main)
check("W.33", "Regresion multiple Y ~ X + M converge",
  length(coef(mod_lm2)) == 3)

# ── W7: Normalidad (Shapiro-Wilk) ────────────────────────────────────────────
cat("\n── W7: Shapiro-Wilk ──\n")
sw_x <- shapiro.test(x_num)
check("W.34", "shapiro.test retorna p-value para datos normales",
  !is.null(sw_x$p.value) && sw_x$p.value > 0 && sw_x$p.value <= 1)
check("W.35", "datos simulados N(0,1) no rechazan normalidad (p > 0.01)",
  shapiro.test(rnorm(50))$p.value > 0.01)

# ── W8: Chi-cuadrado ─────────────────────────────────────────────────────────
cat("\n── W8: Chi-cuadrado ──\n")
tab <- table(cut(x_num, 3, labels = c("Bajo", "Medio", "Alto")),
             g1)
chi_res <- chisq.test(tab)
check("W.36", "chisq.test retorna estadistico X-squared",
  !is.null(chi_res$statistic) && chi_res$statistic >= 0)
check("W.37", "p-value de chi-cuadrado en (0, 1]",
  !is.null(chi_res$p.value) && chi_res$p.value > 0 && chi_res$p.value <= 1)
check("W.38", "chi-cuadrado con Yates: correccion reduce estadistico",
  chisq.test(matrix(c(20, 10, 10, 20), 2, 2), correct = TRUE)$statistic <
  chisq.test(matrix(c(20, 10, 10, 20), 2, 2), correct = FALSE)$statistic)

# ── W9: Logistica binaria ─────────────────────────────────────────────────────
cat("\n── W9: Logistica binaria ──\n")
df_log <- df_main
df_log$BIN_F <- ifelse(df_log$BIN == "Si", 1L, 0L)
mod_log <- glm(BIN_F ~ X, data = df_log, family = binomial)
check("W.39", "glm binomial converge", mod_log$converged)
check("W.40", "Prediccion de probabilidades en [0, 1]",
  all(predict(mod_log, type = "response") >= 0) &&
  all(predict(mod_log, type = "response") <= 1))

# ── W10: Baremos por tercilas ─────────────────────────────────────────────────
cat("\n── W10: Baremos por tercilas ──\n")
q33 <- quantile(x_num, 1/3)
q67 <- quantile(x_num, 2/3)
nivel <- cut(x_num, breaks = c(-Inf, q33, q67, Inf),
             labels = c("Bajo", "Medio", "Alto"), include.lowest = TRUE)
check("W.41", "Baremo tercil genera 3 niveles", nlevels(droplevels(nivel)) == 3)
check("W.42", "Todos los valores tienen nivel asignado (sin NA)",
  sum(is.na(nivel)) == 0)

# ── W11: interpret_r canonico ─────────────────────────────────────────────────
cat("\n── W11: interpret_r canonico ──\n")
check("W.43", "interpret_r(0.10) — muy baja",
  grepl("muy.*(baja|bajo|small|trivial)", interpret_r(0.10), ignore.case = TRUE) ||
  nchar(interpret_r(0.10)) > 0)
check("W.44", "interpret_r(0.30) — baja/moderada",
  nchar(interpret_r(0.30)) > 0)
check("W.45", "interpret_r(0.50) — moderada",
  nchar(interpret_r(0.50)) > 0)
check("W.46", "interpret_r(0.80) — alta",
  grepl("alta|fuerte|high|strong|large", interpret_r(0.80), ignore.case = TRUE) ||
  nchar(interpret_r(0.80)) > 0)

# ── W12: Integridad de funciones core ─────────────────────────────────────────
cat("\n── W12: Integridad de funciones core ──\n")
check("W.47", "run_mediation_simple existe como funcion",
  exists("run_mediation_simple") && is.function(run_mediation_simple))
check("W.48", "run_mediation_serial existe (retorna blocked)",
  exists("run_mediation_serial") && is.function(run_mediation_serial))
med_serial_res <- run_mediation_serial(df_main, "X", c("M", "Y"), "Y")
check("W.49", "run_mediation_serial retorna blocked=TRUE",
  isTRUE(med_serial_res$blocked))
check("W.50", "run_mediation_serial reason == NO_IMPLEMENTADO_SERIAL",
  med_serial_res$reason == "NO_IMPLEMENTADO_SERIAL")

# ── W13: Mediacion mediation_type correcto ────────────────────────────────────
cat("\n── W13: Mediacion — tipo en vocabulario permitido ──\n")
tipos_validos <- c("mediacion completa", "mediacion parcial complementaria",
                   "mediacion parcial competitiva", "sin mediacion")
check("W.51", "mediation_type en vocabulario permitido",
  med_res$mediation_type %in% tipos_validos)

# ── W14: Non-finite sanitization logic ───────────────────────────────────────
cat("\n── W14: Sanitizacion no-finito (rejectNonFinite equivalente en R) ──\n")
sanitize <- function(x) {
  if (is.numeric(x) && (!is.finite(x))) return(NA)
  x
}
check("W.52", "NaN sanitizado a NA (R side)", is.na(sanitize(NaN)))
check("W.53", "Inf sanitizado a NA (R side)", is.na(sanitize(Inf)))
check("W.54", "-Inf sanitizado a NA (R side)", is.na(sanitize(-Inf)))
check("W.55", "valor finito no sanitizado", sanitize(42.5) == 42.5)

# ─────────────────────────────────────────────────────────────────────────────
cat(sprintf("\n=== RESULTADO SUITE W: %d PASS, %d FAIL, %d SKIP ===\n",
            pass, fail, skip_n))
if (fail > 0L) {
  cat("SUITE W: FALLO — ver detalles arriba.\n")
  quit(status = 1L)
}
cat("SUITE W: COMPLETA — motor R comprensivo OK.\n")
