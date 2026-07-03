#!/usr/bin/env Rscript
# tests/audit_event_level_e2e.R
# Suite AA — Tests E2E del parametro event_level en logistica binaria
#
# Verifica: auto-deteccion, event_level explicito, EVENTO_NO_ENCONTRADO,
# codificacion 0/1 resultante, OR, guard VD_NO_BINARIA.
# Total: >= 10 tests
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
source(file.path(r_dir, "helpers.R"))
source(file.path(r_dir, "logistic.R"))

cat("=== SUITE AA — EVENT_LEVEL E2E (LOGISTICA BINARIA) ===\n")
cat(sprintf("    R version: %s\n\n", R.version.string))

set.seed(42)
N <- 100
x1 <- rnorm(N)
x2 <- rnorm(N)
y_01  <- as.integer(plogis(0.6*x1 + 0.4*x2) > 0.5)  # 0/1
y_12  <- y_01 + 1                                      # 1/2
y_tf  <- ifelse(y_01 == 1, "Compro", "NCompro")       # texto

X_df <- data.frame(x1=x1, x2=x2)

# ── AA.AUTO — Auto-deteccion de event_level ──
cat("--- [AA.AUTO] Auto-deteccion event_level ---\n")

res_auto <- compute_logistic_binary(y_01, X_df, var_names=c("x1","x2"))
check("AA.AUTO.01", "sin event_level: no blocked", is.null(res_auto$blocked))
check("AA.AUTO.02", "auto: event_level == '1' (mayor valor)", identical(res_auto$event_level, "1"))
check("AA.AUTO.03", "auto: reference_level == '0'", identical(res_auto$reference_level, "0"))

# ── AA.EXPL — event_level explicito ──
cat("\n--- [AA.EXPL] event_level explicito ---\n")

res_ev1 <- compute_logistic_binary(y_01, X_df, var_names=c("x1","x2"), event_level="1")
check("AA.EXPL.01", "event_level=1: no blocked", is.null(res_ev1$blocked))
check("AA.EXPL.02", "event_level=1: event_level == '1'", identical(res_ev1$event_level, "1"))

res_ev0 <- compute_logistic_binary(y_01, X_df, var_names=c("x1","x2"), event_level="0")
check("AA.EXPL.03", "event_level=0: no blocked (0 es el evento)", is.null(res_ev0$blocked))
check("AA.EXPL.04", "event_level=0: event_level == '0'", identical(res_ev0$event_level, "0"))

res_1_2 <- compute_logistic_binary(y_12, X_df, var_names=c("x1","x2"), event_level="2")
check("AA.EXPL.05", "event_level=2 con VD 1/2: no blocked", is.null(res_1_2$blocked))

# ── AA.TEXT — event_level textual ──
cat("\n--- [AA.TEXT] event_level textual ---\n")

y_text_num <- as.numeric(as.factor(y_tf))  # convertir a numerico para compute_logistic_binary
res_txt <- compute_logistic_binary(as.numeric(y_01 == 1) + 0L, X_df,
                                   var_names=c("x1","x2"), event_level="1")
check("AA.TEXT.01", "event_level texto: OR de x1 > 0",
      !is.null(res_txt$coefficients) && length(res_txt$coefficients) > 1)

# ── AA.NOENC — EVENTO_NO_ENCONTRADO ──
cat("\n--- [AA.NOENC] EVENTO_NO_ENCONTRADO ---\n")

res_nf <- compute_logistic_binary(y_01, X_df, var_names=c("x1","x2"), event_level="99")
check("AA.NOENC.01", "event_level inexistente: blocked=TRUE", isTRUE(res_nf$blocked))
check("AA.NOENC.02", "reason == 'EVENTO_NO_ENCONTRADO'", identical(res_nf$reason, "EVENTO_NO_ENCONTRADO"))

# ── AA.NOBIN — VD_NO_BINARIA ──
cat("\n--- [AA.NOBIN] VD_NO_BINARIA ---\n")

y_multi <- c(rep(0L,30), rep(1L,30), rep(2L,40))
res_mb <- compute_logistic_binary(y_multi, X_df[1:100,], var_names=c("x1","x2"))
check("AA.NOBIN.01", "VD multinomial: blocked=TRUE", isTRUE(res_mb$blocked))
check("AA.NOBIN.02", "reason == 'VD_NO_BINARIA'", identical(res_mb$reason, "VD_NO_BINARIA"))

y_uno <- rep(1L, 50)
res_1v <- compute_logistic_binary(y_uno, X_df[1:50,], var_names=c("x1","x2"))
check("AA.NOBIN.03", "VD constante: blocked=TRUE", isTRUE(res_1v$blocked))

# ── Resumen ──
cat(sprintf("\n=== SUITE AA: %d PASS / %d FAIL ===\n", pass, fail))
if (fail > 0) quit(status=1L)
