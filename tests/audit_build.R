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

# ── Y.P2B — P2 secundarios: GH-P, USE-FISHER, LEVENE-LABEL ──
cat("\n--- [Y.P2B] P2 secundarios (GH-P, USE-FISHER, LEVENE-LABEL) ---\n")

source(file.path(r_dir, "anova.R"))
source(file.path(r_dir, "chi_square.R"))

# P2-GH-P: p de Games-Howell debe salir de ptukey (rango estudentizado),
# consistente con el IC que ya usaba qtukey.
set.seed(11)
y_gh <- c(rnorm(20, 0, 1), rnorm(20, 1, 2), rnorm(20, 2, 4))
g_gh <- rep(c("A","B","C"), each=20)
gh <- games_howell(y_gh, g_gh)
check("Y.P2B.01", "P2-GH-P: games_howell devuelve comparaciones", !is.null(gh) && nrow(gh) == 3)
# Recalcular a mano el p de la primera comparacion con ptukey
s_a <- y_gh[g_gh=="A"]; s_b <- y_gh[g_gh=="B"]
se_ab <- sqrt(var(s_a)/20 + var(s_b)/20)
df_ab <- (var(s_a)/20 + var(s_b)/20)^2 / ((var(s_a)/20)^2/19 + (var(s_b)/20)^2/19)
t_ab  <- (mean(s_a)-mean(s_b))/se_ab
p_ref <- ptukey(abs(t_ab)*sqrt(2), nmeans=3, df=df_ab, lower.tail=FALSE)
check("Y.P2B.02", "P2-GH-P: p_adj coincide con ptukey de referencia (tol 1e-3)",
      abs(gh$p_adj[1] - round(p_ref,4)) <= 1e-3)
# El p ajustado por familia nunca es menor que el p pareado sin ajustar
p_unadj <- 2*pt(abs(t_ab), df_ab, lower.tail=FALSE)
check("Y.P2B.03", "P2-GH-P: p ajustado >= p sin ajustar (correccion por familia)",
      gh$p_adj[1] >= round(p_unadj,4) - 1e-6)
# Coherencia p/IC: significativo <=> IC excluye 0 (misma base ptukey/qtukey)
coh <- all(gh$significant == (gh$ci_lower > 0 | gh$ci_upper < 0))
check("Y.P2B.04", "P2-GH-P: decision por p coincide con IC (misma distribucion)", coh)

# P2-USE-FISHER: con esperados sanos NO usa Fisher; con esperado < 1 si.
set.seed(12)
v_ok1 <- rep(c("A","B"), each=40)
v_ok2 <- sample(c("X","Y"), 80, replace=TRUE)
chi_ok <- compute_chisquare(v_ok1, v_ok2, alpha=0.05)
check("Y.P2B.05", "P2-USE-FISHER: tabla 2x2 sana no usa Fisher",
      !grepl("Fisher", chi_ok$method_used %||% chi_ok$method %||% ""))
# Tabla con celda de esperado << 1 (39/1 vs 1/1: esperado minimo = 2*2/42 < 1)
v_low1 <- c(rep("A",40), rep("B",2))
v_low2 <- c(rep("X",39), "Y", "X", "Y")
chi_low <- compute_chisquare(v_low1, v_low2, alpha=0.05)
check("Y.P2B.06", "P2-USE-FISHER: esperado minimo < 1 activa Fisher exacto",
      grepl("Fisher", chi_low$method_used %||% chi_low$method %||% ""))

# P2-LEVENE-LABEL: documentado en codigo que es Levene clasico (media), no Brown-Forsythe
anova_src <- readLines(file.path(r_dir, "anova.R"))
check("Y.P2B.07", "P2-LEVENE-LABEL: diferencia con Brown-Forsythe documentada en anova.R",
      any(grepl("Brown-Forsythe", anova_src, fixed=TRUE)))

# ── Resumen ──
cat(sprintf("\n=== SUITE Y: %d PASS / %d FAIL ===\n", pass, fail))
if (fail > 0) quit(status=1L)
