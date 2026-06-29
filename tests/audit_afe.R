# ============================================================================
# PASO P — AFE: KMO, Bartlett, cargas, comunalidades, Heywood
# ============================================================================
options(encoding="UTF-8")

pass_count <- 0L
fail_count <- 0L
fail_msgs  <- character(0)

ok <- function(id, desc) {
  pass_count <<- pass_count + 1L
  cat(sprintf("[PASS] %s: %s\n", id, desc))
}
fail <- function(id, desc, detail="") {
  fail_count <<- fail_count + 1L
  msg <- sprintf("[FAIL] %s: %s%s", id, desc, if(nchar(detail)>0) paste0(" — ", detail) else "")
  fail_msgs  <<- c(fail_msgs, msg)
  cat(msg, "\n")
}
assert <- function(id, desc, cond, detail="") {
  if (isTRUE(cond)) ok(id, desc) else fail(id, desc, detail)
}

r_dir <- file.path("apps", "api", "stats-engine-r", "R")
source(file.path(r_dir, "statistics.R"))
source(file.path(r_dir, "instruments.R"))

# ── Datos de referencia (n=200, 6 ítems, 2 factores) ────────────────────────
set.seed(42)
n_ref <- 200
f1 <- rnorm(n_ref); f2 <- rnorm(n_ref)
df_ref <- data.frame(
  i1 = round(pmin(pmax(0.7*f1 + 0.2*f2 + rnorm(n_ref,0,0.5), 1), 5)),
  i2 = round(pmin(pmax(0.8*f1 + 0.1*f2 + rnorm(n_ref,0,0.4), 1), 5)),
  i3 = round(pmin(pmax(0.75*f1 + rnorm(n_ref,0,0.5), 1), 5)),
  i4 = round(pmin(pmax(0.8*f2 + 0.1*f1 + rnorm(n_ref,0,0.4), 1), 5)),
  i5 = round(pmin(pmax(0.7*f2 + rnorm(n_ref,0,0.5), 1), 5)),
  i6 = round(pmin(pmax(0.75*f2 + rnorm(n_ref,0,0.4), 1), 5))
)

# ============================================================================
# P.KMO — KMO y Bartlett
# ============================================================================
cat("\n=== P.KMO — KMO y Bartlett ===\n")

kmo_ref <- compute_kmo(df_ref)

# P.KMO.01: KMO overall en [0,1]
assert("P.KMO.01", "KMO overall en [0,1]",
       is.numeric(kmo_ref$kmo_overall) && kmo_ref$kmo_overall >= 0 && kmo_ref$kmo_overall <= 1,
       toString(kmo_ref$kmo_overall))

# P.KMO.02: Bartlett chi2 > 0
assert("P.KMO.02", "Bartlett chi2 > 0",
       is.numeric(kmo_ref$bartlett_chi2) && kmo_ref$bartlett_chi2 > 0,
       toString(kmo_ref$bartlett_chi2))

# P.KMO.03: Bartlett p < 0.05 para datos correlacionados
assert("P.KMO.03", "Bartlett p < 0.05 para items correlacionados",
       !is.na(kmo_ref$bartlett_p) && kmo_ref$bartlett_p < 0.05,
       toString(kmo_ref$bartlett_p))

# P.KMO.04: factorizable=TRUE cuando KMO>=0.5 y p<0.05
assert("P.KMO.04", "factorizable=TRUE cuando KMO>=0.5 y p<0.05",
       isTRUE(kmo_ref$factorizable),
       paste0("kmo=",kmo_ref$kmo_overall," p=",kmo_ref$bartlett_p))

# ============================================================================
# P.PA — Análisis paralelo
# ============================================================================
cat("\n=== P.PA — Análisis paralelo ===\n")

# P.PA.01: n_factors_pa >= 1
{
  r_afe <- compute_afe(df_ref)
  assert("P.PA.01", "n_factors_pa >= 1",
         !is.null(r_afe$n_factors_pa) && r_afe$n_factors_pa >= 1,
         toString(r_afe$n_factors_pa))
}

# ============================================================================
# P.LOAD — Cargas factoriales
# ============================================================================
cat("\n=== P.LOAD — Cargas factoriales ===\n")

r_afe2 <- compute_afe(df_ref, n_factors=2)

# P.LOAD.01: loadings es lista no vacía
assert("P.LOAD.01", "loadings no vacío",
       is.list(r_afe2$loadings) && length(r_afe2$loadings) > 0)

# P.LOAD.02: cada loading tiene h2 y u2
{
  all_h2u2 <- all(sapply(r_afe2$loadings, function(l) !is.null(l$h2) && !is.null(l$u2)))
  assert("P.LOAD.02", "cada loading tiene h2 y u2", all_h2u2)
}

# P.LOAD.03: h2 en (0,1] y u2 = 1-h2 sin Heywood
{
  h2_vals <- sapply(r_afe2$loadings, function(l) l$h2)
  u2_vals <- sapply(r_afe2$loadings, function(l) l$u2)
  no_heywood <- all(h2_vals <= 1 + 1e-6) && all(u2_vals >= -1e-6)
  assert("P.LOAD.03", "sin Heywood: h2<=1, u2>=0",
         no_heywood,
         paste0("h2=",paste(round(h2_vals,3),collapse=","), " u2=",paste(round(u2_vals,3),collapse=",")))
}

# ============================================================================
# P.VAR — Varianza explicada
# ============================================================================
cat("\n=== P.VAR — Varianza explicada ===\n")

# P.VAR.01: variance data.frame con factor/ss_load/pct_var/cum_var
{
  assert("P.VAR.01", "variance tiene columnas factor/ss_load/pct_var/cum_var",
         all(c("factor","ss_load","pct_var","cum_var") %in% names(r_afe2$variance)))
}

# P.VAR.02: cum_var última fila <= 100
{
  last_cum <- tail(r_afe2$variance$cum_var, 1)
  assert("P.VAR.02", "cum_var final <= 100",
         last_cum <= 100 + 0.01, paste0("cum_var=",last_cum))
}

# ============================================================================
# P.RMSEA — RMSEA del modelo
# ============================================================================
cat("\n=== P.RMSEA — RMSEA ===\n")

# P.RMSEA.01: rmsea presente y numérico >= 0
assert("P.RMSEA.01", "rmsea numérico >= 0",
       is.numeric(r_afe2$rmsea) && r_afe2$rmsea >= 0,
       toString(r_afe2$rmsea))

# ============================================================================
# P.TLI — TLI del modelo
# ============================================================================
cat("\n=== P.TLI — TLI ===\n")

# P.TLI.01: tli presente y numérico
assert("P.TLI.01", "tli numérico",
       is.numeric(r_afe2$tli),
       toString(r_afe2$tli))

# ============================================================================
# P.HEYWOOD — Heywood guard
# ============================================================================
cat("\n=== P.HEYWOOD — Heywood cases ===\n")

# P.HEYWOOD.01: guard implementado en instruments.R
{
  src <- readLines(file.path(r_dir, "instruments.R"))
  has_guard <- any(grepl("HEYWOOD_CASE", src, fixed=TRUE))
  assert("P.HEYWOOD.01", "guard HEYWOOD_CASE presente en instruments.R",
         has_guard)
}

# P.HEYWOOD.02: guard comprueba h2 > 1 o u2 < 0
{
  src <- readLines(file.path(r_dir, "instruments.R"))
  has_h2_check <- any(grepl("h2.*>.*1", src, perl=TRUE))
  has_u2_check <- any(grepl("u2.*<.*-", src, perl=TRUE))
  assert("P.HEYWOOD.02", "guard verifica h2>1 y u2<0",
         has_h2_check || has_u2_check)
}

# P.HEYWOOD.03: sin Heywood en datos buenos → no bloqueado
{
  # r_afe2 ya calculado con datos buenos
  assert("P.HEYWOOD.03", "datos buenos → no blocked por Heywood",
         is.null(r_afe2$blocked) || !isTRUE(r_afe2$blocked),
         toString(r_afe2[c("blocked","reason")]))
}

# ============================================================================
# P.CASES — Casos de frontera
# ============================================================================
cat("\n=== P.CASES — Casos de frontera ===\n")

# P.CASES.01: n < 10 → error
{
  df_small <- df_ref[1:8, ]
  r_small <- compute_afe(df_small)
  assert("P.CASES.01", "n<10 → error devuelto",
         !is.null(r_small$error))
}

# P.CASES.02: 1 factor explícito
{
  r_1f <- compute_afe(df_ref, n_factors=1)
  assert("P.CASES.02", "n_factors=1 → n_factors=1 en output",
         r_1f$n_factors == 1, paste0("n_factors=",r_1f$n_factors))
}

# P.CASES.03: rotacion oblimin
{
  r_obl <- compute_afe(df_ref, n_factors=2, rotation="oblimin")
  assert("P.CASES.03", "rotation=oblimin en output",
         identical(r_obl$rotation, "oblimin"))
}

# P.CASES.04: rotacion varimax
{
  r_vm <- compute_afe(df_ref, n_factors=2, rotation="varimax")
  assert("P.CASES.04", "rotation=varimax en output",
         identical(r_vm$rotation, "varimax"))
}

# P.CASES.05: n en output = nrow completo
{
  r5 <- compute_afe(df_ref, n_factors=2)
  assert("P.CASES.05", "n == nrow(df_ref)",
         r5$n == nrow(df_ref), paste0("r$n=",r5$n))
}

# P.CASES.06: estimator en output
{
  r6 <- compute_afe(df_ref, n_factors=2, estimator="minres")
  assert("P.CASES.06", "estimator=minres en output",
         identical(r6$estimator, "minres"))
}

# P.CASES.07: CR y AVE calculados
{
  r7 <- compute_afe(df_ref, n_factors=2)
  assert("P.CASES.07", "cr_ave no vacío",
         is.list(r7$cr_ave) && length(r7$cr_ave) > 0)
}

# P.CASES.08: items con nombre en loadings
{
  r8 <- compute_afe(df_ref, n_factors=2)
  items_nombres <- sapply(r8$loadings, function(l) l$item)
  assert("P.CASES.08", "loadings tienen campo item",
         all(nchar(items_nombres) > 0))
}

# ============================================================================
# P.CROSS — Cargas cruzadas
# ============================================================================
cat("\n=== P.CROSS — Cargas cruzadas ===\n")

# P.CROSS.01: cross_loadings campo existe
{
  r_cross <- compute_afe(df_ref, n_factors=2)
  assert("P.CROSS.01", "cross_loadings campo existe en output",
         "cross_loadings" %in% names(r_cross))
}

# ============================================================================
# P.CONTRACT — Contrato
# ============================================================================
cat("\n=== P.CONTRACT — Contrato ===\n")

# P.CONTRACT.01: n_factors en output == n_factors pasado
{
  r_c1 <- compute_afe(df_ref, n_factors=3)
  assert("P.CONTRACT.01", "n_factors=3 respetado",
         r_c1$n_factors == 3, paste0("n_factors=",r_c1$n_factors))
}

# P.CONTRACT.02: fit_ok es lógico
{
  r_c2 <- compute_afe(df_ref, n_factors=2)
  assert("P.CONTRACT.02", "fit_ok es lógico",
         is.logical(r_c2$fit_ok))
}

# P.CONTRACT.03: no_loadings campo existe
{
  r_c3 <- compute_afe(df_ref, n_factors=2)
  assert("P.CONTRACT.03", "no_loadings campo existe",
         "no_loadings" %in% names(r_c3))
}

# P.CONTRACT.04: n_factors_pa en output
{
  r_c4 <- compute_afe(df_ref, n_factors=2)
  assert("P.CONTRACT.04", "n_factors_pa en output",
         "n_factors_pa" %in% names(r_c4))
}

# ============================================================================
# P.P1 — P1 bug fix
# ============================================================================
cat("\n=== P.P1 — P1 bug fix statistics.R ===\n")

# P.P1.01: statistics.R no tiene library(psych)
{
  src <- readLines(file.path(r_dir, "statistics.R"))
  has_lib <- any(grepl("^\\s*library\\s*\\(\\s*psych", src, perl=TRUE))
  assert("P.P1.01", "statistics.R sin library(psych)",
         !has_lib, "library(psych) encontrado")
}

# P.P1.02: statistics.R no tiene library(nortest)
{
  src <- readLines(file.path(r_dir, "statistics.R"))
  has_lib <- any(grepl("^\\s*library\\s*\\(\\s*nortest", src, perl=TRUE))
  assert("P.P1.02", "statistics.R sin library(nortest)",
         !has_lib, "library(nortest) encontrado")
}

# ============================================================================
cat("\n")
cat(sprintf("RESULTADO: %d PASS / %d FAIL\n", pass_count, fail_count))
if (fail_count > 0) {
  cat("FALLOS:\n")
  for (m in fail_msgs) cat(" ", m, "\n")
  cat("PASO P: FALLO\n")
  quit(status=1L)
}
cat("PASO P: COMPLETO — AFE validado.\n")
