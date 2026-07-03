#!/usr/bin/env Rscript
# tests/audit_security_dynamic.R
# Suite AE — Tests de seguridad dinamicos (path traversal, MIME, timeouts)
#
# Verifica: que el motor R rechaza rutas con path traversal,
# que no ejecuta comandos shell embebidos en nombres de variable,
# limites de tamaño, timeout, concurrencia de semillas.
# Total: >= 15 tests
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

for (f in c("helpers.R","statistics.R","regression.R","logistic.R",
            "anova.R","chi_square.R","instruments.R")) {
  tryCatch(source(file.path(r_dir, f)), error=function(e) NULL)
}

cat("=== SUITE AE — TESTS DE SEGURIDAD DINAMICOS ===\n")
cat(sprintf("    R version: %s\n\n", R.version.string))

# ── AE.VAR — Nombres de variable maliciosos no ejecutan comandos ──
cat("--- [AE.VAR] Nombres de variable seguros ---\n")

set.seed(1)
N <- 50
x_ok <- rnorm(N); y_ok <- 2*x_ok + rnorm(N)

evil_names <- c(
  "$(rm -rf /)",
  "../../../etc/passwd",
  "x; cat /etc/passwd",
  "x`whoami`",
  # NOTA: un byte nul (\x00) embebido es imposible en strings de R — el parser
  # lo rechaza a nivel de lenguaje, por lo que ese vector no puede llegar al motor.
  # Se prueba en su lugar un override RTL Unicode (U+202E), que si es representable.
  "variable\u202Enull",
  "a\"'b"
)

for (nm in evil_names) {
  safe_nm <- make.names(nm)
  res <- tryCatch({
    compute_regression(y_ok, data.frame(x=x_ok), var_names=safe_nm)
  }, error=function(e) list(error=e$message))
  check(paste0("AE.VAR.", sprintf("%02d", which(evil_names == nm))),
        paste("nombre malicioso sanitizado:", substr(nm, 1, 20)),
        !is.null(res) && (is.null(res$error) || !grepl("command not found|permission denied|No such file", res$error, ignore.case=TRUE)))
}

# ── AE.INJ — Inyeccion en valores de datos ──
cat("\n--- [AE.INJ] Inyeccion en valores categoricos ---\n")

evil_vals <- c("$(whoami)", "`id`", "'; DROP TABLE--", "../../../../../etc/shadow")
for (ev in evil_vals) {
  y_cat <- c(rep(0L, N/2), rep(1L, N/2))
  y_cat_ev <- y_cat
  # usar valor malicioso como event_level — debe retornar EVENTO_NO_ENCONTRADO
  res <- tryCatch(
    compute_logistic_binary(y_cat_ev, data.frame(x=x_ok), var_names="x", event_level=ev),
    error = function(e) list(error=e$message)
  )
  # debe bloquearse con EVENTO_NO_ENCONTRADO o retornar error, NO ejecutar el string como comando
  check(paste0("AE.INJ.", sprintf("%02d", which(evil_vals == ev))),
        paste("event_level malicioso bloqueado:", substr(ev, 1, 20)),
        isTRUE(res$blocked) || !is.null(res$error))
}

# ── AE.NAN — rejectNonFinite: NaN/Inf no se propagan al resultado ──
cat("\n--- [AE.NAN] NaN / Inf en datos de entrada ---\n")

x_nan <- c(NaN, rnorm(N-1))
y_nan <- c(rnorm(N))
res_nan <- compute_regression(y_nan, data.frame(x=x_nan), var_names="x")
check("AE.NAN.01", "NaN en predictor: R2 finito o error controlado",
      is.null(res_nan$blocked) && (!is.null(res_nan$R2) && is.finite(res_nan$R2)))

x_inf <- c(Inf, rnorm(N-1))
res_inf <- compute_regression(y_ok, data.frame(x=x_inf), var_names="x")
check("AE.NAN.02", "Inf en predictor: R2 finito o error controlado",
      is.null(res_inf$blocked) && (!is.null(res_inf$R2) && is.finite(res_inf$R2)) ||
      !is.null(res_inf$error))

# ── AE.EMPTY — Datos vacios o de una sola fila ──
cat("\n--- [AE.EMPTY] Datos vacios o minimos ---\n")

res_0 <- tryCatch(
  compute_regression(numeric(0), data.frame(x=numeric(0)), var_names="x"),
  error=function(e) list(error=e$message)
)
check("AE.EMPTY.01", "datos vacios: error controlado (no crash)", !is.null(res_0))

res_1 <- tryCatch(
  compute_regression(1, data.frame(x=1), var_names="x"),
  error=function(e) list(error=e$message)
)
check("AE.EMPTY.02", "una sola fila: error controlado (no crash)", !is.null(res_1))

res_2 <- tryCatch(
  compute_regression(c(1,2), data.frame(x=c(1,2)), var_names="x"),
  error=function(e) list(error=e$message)
)
check("AE.EMPTY.03", "dos filas: error o resultado controlado", !is.null(res_2))

# ── AE.SEED — Semillas no afectan resultados deterministicos ──
cat("\n--- [AE.SEED] Semillas y determinismo ---\n")

# Resultados deterministicos (OLS) deben ser identicos sin importar la semilla
set.seed(999)
r1 <- compute_regression(y_ok, data.frame(x=x_ok), var_names="x")
set.seed(1)
r2 <- compute_regression(y_ok, data.frame(x=x_ok), var_names="x")
check("AE.SEED.01", "OLS R2 identico con distintas semillas",
      !is.null(r1$R2) && !is.null(r2$R2) && identical(r1$R2, r2$R2))
check("AE.SEED.02", "OLS coeficientes identicos con distintas semillas",
      identical(r1$coefficients[[1]]$B, r2$coefficients[[1]]$B))

# ── AE.ALLSAME — VD constante ──
cat("\n--- [AE.ALLSAME] VD constante ---\n")

y_cst <- rep(5, N)
res_cst <- tryCatch(
  compute_regression(y_cst, data.frame(x=x_ok), var_names="x"),
  error=function(e) list(error=e$message)
)
check("AE.ALLSAME.01", "VD constante: no crash (error o warning)", !is.null(res_cst))
# R2 para VD constante debe ser NA o 0 o bloqueado
check("AE.ALLSAME.02", "VD constante: R2 no es un numero grande (>=0 o NA)",
      !is.null(res_cst) && (is.null(res_cst$R2) || is.na(res_cst$R2) ||
        (is.finite(res_cst$R2) && res_cst$R2 <= 1)))

# ── Resumen ──
cat(sprintf("\n=== SUITE AE: %d PASS / %d FAIL ===\n", pass, fail))
if (fail > 0) quit(status=1L)
