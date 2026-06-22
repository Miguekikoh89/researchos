# ============================================================================
# CanchariOS - Suite de validacion numerica automatizada
# Compara los motores R de CanchariOS contra valores de referencia calculados
# con R base puro, usando el dataset publico mtcars (reproducible por cualquiera).
#
# Uso: Rscript tests/validate_mtcars.R
# Debe ejecutarse desde el directorio raiz de stats-engine-r, o ajustar R_DIR abajo.
#
# Si CUALQUIER prueba falla, el script termina con exit code 1 (util para CI/CD).
# ============================================================================

R_DIR <- Sys.getenv("CANCHARIOS_R_DIR", unset = "/app/stats-engine-r/R")
TOLERANCE <- 0.01  # tolerancia absoluta para comparar floats (redondeo)

source(file.path(R_DIR, "helpers.R"))
source(file.path(R_DIR, "statistics.R"))
source(file.path(R_DIR, "regression.R"))
source(file.path(R_DIR, "anova.R"))
source(file.path(R_DIR, "t_test.R"))
source(file.path(R_DIR, "chi_square.R"))
source(file.path(R_DIR, "logistic.R"))
source(file.path(R_DIR, "logistic_multinomial.R"))
source(file.path(R_DIR, "cronbach_only.R"))
source(file.path(R_DIR, "ancova.R"))
source(file.path(R_DIR, "discriminant.R"))
source(file.path(R_DIR, "cluster.R"))
source(file.path(R_DIR, "ordinal_regression.R"))

# ── Dataset de prueba: mtcars (publico, reproducible con data(mtcars)) ──────
data(mtcars)
df <- mtcars
df$am_label <- ifelse(df$am == 1, "Manual", "Automatico")
df$cyl_label <- as.character(df$cyl)
cuts <- quantile(df$mpg, probs = c(1/3, 2/3))
df$mpg_ord <- cut(df$mpg, breaks = c(-Inf, cuts, Inf), labels = c("Bajo","Medio","Alto"), ordered_result = TRUE)

# ── Helpers de comparacion ───────────────────────────────────────────────────
results <- list()
check <- function(test_name, actual, expected, tol = TOLERANCE) {
  passed <- !is.na(actual) && !is.na(expected) && abs(actual - expected) <= tol
  results[[length(results) + 1]] <<- list(test = test_name, actual = actual, expected = expected, passed = passed)
  status <- if (passed) "OK  " else "FAIL"
  cat(sprintf("[%s] %-55s actual=%-12s esperado=%-12s\n", status, test_name, round(actual,4), round(expected,4)))
}

cat("============================================================\n")
cat("CanchariOS - Suite de validacion numerica (dataset: mtcars)\n")
cat("============================================================\n\n")

# ── 1. Correlacion Pearson (mpg, wt) ──────────────────────────────────────────
cat("--- 1. Correlacion Pearson ---\n")
r1 <- correlate_pearson(df$mpg, df$wt, alpha = 0.05)
check("Correlacion: r", r1$r, -0.8677)
check("Correlacion: t", r1$t, -9.559)
check("Correlacion: IC inferior", r1$ci_lower, -0.9338, tol = 0.01)

# ── 2. Regresion lineal (mpg ~ wt) ────────────────────────────────────────────
cat("\n--- 2. Regresion lineal ---\n")
r2 <- compute_regression(y = df$mpg, X = data.frame(wt = df$wt), var_names = "wt", alpha = 0.05)
check("Regresion: Intercepto", r2$coefficients[[1]]$B, 37.2851)
check("Regresion: Pendiente wt", r2$coefficients[[2]]$B, -5.3445)
check("Regresion: R2", r2$R2, 0.7528)
check("Regresion: F", r2$F, 91.3753, tol = 0.1)

# ── 3. ANOVA (mpg ~ cyl_label) ─────────────────────────────────────────────────
cat("\n--- 3. ANOVA ---\n")
r3 <- compute_anova(y = df$mpg, grupos = df$cyl_label, alpha = 0.05)
check("ANOVA: F", r3$F, 39.70, tol = 0.1)
check("ANOVA: df_between", r3$df_between, 2)
check("ANOVA: df_within", r3$df_within, 29)

# ── 4. Comparacion t-test Welch (mpg ~ am) ────────────────────────────────────
cat("\n--- 4. Comparacion (t-test, Welch esperado por heterogeneidad) ---\n")
x1 <- df$mpg[df$am == 0]; x2 <- df$mpg[df$am == 1]
r4 <- compute_ttest(x1, x2, type = "independiente", alpha = 0.05, group_names = c("Automatico","Manual"))
check("Comparacion: t (Welch)", r4$t, -3.7671, tol = 0.01)
check("Comparacion: df (Welch)", r4$df, 18.33, tol = 0.1)

# ── 5. Chi-cuadrado (am vs vs) con Yates ──────────────────────────────────────
cat("\n--- 5. Chi-cuadrado (con correccion Yates) ---\n")
r5 <- compute_chisquare(df$am, df$vs, alpha = 0.05)
check("Chi-cuadrado: estadistico (CON Yates)", r5$chi2, 0.3475, tol = 0.01)

# ── 6. Logistica binaria (am ~ mpg) ───────────────────────────────────────────
cat("\n--- 6. Regresion logistica binaria ---\n")
r6 <- compute_logistic(y = df$am, X = data.frame(mpg = df$mpg), type = "binaria", var_names = "mpg", alpha = 0.05)
check("Logistica: Intercepto", r6$coefficients[[1]]$B, -6.6035)
check("Logistica: Coef mpg", r6$coefficients[[2]]$B, 0.307, tol = 0.01)
check("Logistica: LR chi2", r6$ll_ratio, 13.5546, tol = 0.01)

# ── 7. Alfa de Cronbach (wt, qsec, drat - SIN estandarizar) ───────────────────
cat("\n--- 7. Alfa de Cronbach ---\n")
r7 <- run_cronbach_only(df, c("wt","qsec","drat"), "TestConstruct")
check("Cronbach: alfa", r7$alpha, -0.5449, tol = 0.01)

# ── 8. ANCOVA (mpg ~ cyl_label + hp) ──────────────────────────────────────────
cat("\n--- 8. ANCOVA ---\n")
r8 <- run_ancova(df, dep_items = "mpg", group_var = "cyl_label", covariate_items = "hp", dep_name = "mpg")
hp_row <- r8$ancova_table[[1]]
grp_row <- r8$ancova_table[[2]]
check("ANCOVA: F covariable (hp)", hp_row$F, 68.5305, tol = 0.1)
check("ANCOVA: F grupo (cyl)", grp_row$F, 8.6124, tol = 0.1)

# ── 9. Discriminante (cyl_label ~ mpg+hp+wt) ──────────────────────────────────
cat("\n--- 9. Analisis discriminante ---\n")
r9 <- run_discriminant(df, predictor_items = c("mpg","hp","wt"), group_var = "cyl_label")
check("Discriminante: precision %", r9$precision, 87.5, tol = 0.5)

# ── 10. Cluster K-means (mpg, wt, hp), k=3 ────────────────────────────────────
cat("\n--- 10. Analisis cluster ---\n")
r10 <- run_cluster(df, items = c("mpg","wt","hp"), n_clusters = 3, var_name = "Test", seed = 42)
check("Cluster: Within SS", r10$within_ss, 23.739, tol = 0.05)
check("Cluster: Between SS", r10$between_ss, 69.261, tol = 0.05)

# ── 11. Regresion ordinal (mpg_ord ~ wt) ──────────────────────────────────────
cat("\n--- 11. Regresion ordinal ---\n")
r11 <- run_ordinal_regression(df, var_a_items = "wt", var_b_items = "mpg", var_a_name = "wt", var_b_name = "mpg", ordinalizacion = "tercil")
check("Reg. ordinal: AIC", r11$aic, 42.879, tol = 0.05)
check("Reg. ordinal: B (wt)", r11$coefficients[[1]]$B, -3.957, tol = 0.01)

# ── 12. Logistica multinomial (cyl_label ~ mpg) ───────────────────────────────
cat("\n--- 12. Regresion logistica multinomial ---\n")
r12 <- compute_logistic_multinomial(y_raw = df$cyl_label, X = data.frame(mpg = df$mpg), var_names = "mpg", alpha = 0.05)
check("Multinomial: LR chi2", r12$lr_chi2, 51.7884, tol = 0.01)
comp6 <- r12$comparisons[[1]]$coefficients[[2]]
check("Multinomial: B mpg (nivel 6)", comp6$B, -2.2054, tol = 0.01)

# ── RESUMEN FINAL ──────────────────────────────────────────────────────────────
cat("\n============================================================\n")
n_total <- length(results)
n_passed <- sum(sapply(results, function(r) r$passed))
n_failed <- n_total - n_passed
cat(sprintf("RESUMEN: %d/%d pruebas pasaron. %d fallaron.\n", n_passed, n_total, n_failed))
cat("============================================================\n")

if (n_failed > 0) {
  cat("\nPRUEBAS FALLIDAS:\n")
  for (r in results) {
    if (!r$passed) cat(sprintf("  - %s: actual=%s, esperado=%s\n", r$test, r$actual, r$expected))
  }
  quit(status = 1)
} else {
  cat("\nTodas las pruebas pasaron correctamente.\n")
  quit(status = 0)
}
