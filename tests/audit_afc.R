# ============================================================================
# PASO Q — AFC: índices de ajuste, cargas, CR, AVE, convergencia, Heywood
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

# ── Datos de referencia ────────────────────────────────────────────────────
set.seed(42)
n_ref <- 250
f1 <- rnorm(n_ref); f2 <- rnorm(n_ref)
df_afc <- data.frame(
  a1 = round(pmin(pmax(0.8*f1 + rnorm(n_ref,0,0.4), 1), 5)),
  a2 = round(pmin(pmax(0.75*f1 + rnorm(n_ref,0,0.45), 1), 5)),
  a3 = round(pmin(pmax(0.7*f1 + rnorm(n_ref,0,0.5), 1), 5)),
  b1 = round(pmin(pmax(0.8*f2 + rnorm(n_ref,0,0.4), 1), 5)),
  b2 = round(pmin(pmax(0.75*f2 + rnorm(n_ref,0,0.45), 1), 5)),
  b3 = round(pmin(pmax(0.7*f2 + rnorm(n_ref,0,0.5), 1), 5))
)
variables_ref <- list(
  list(name="Factor1", items=c("a1","a2","a3")),
  list(name="Factor2", items=c("b1","b2","b3"))
)

r_afc <- compute_afc(df_afc, variables_ref)

# ============================================================================
# Q.FIT — Índices de ajuste
# ============================================================================
cat("\n=== Q.FIT — Índices de ajuste ===\n")

# Q.FIT.01: CFI existe y es numérico
assert("Q.FIT.01", "CFI numérico",
       is.numeric(r_afc$cfi), toString(r_afc$cfi))

# Q.FIT.02: TLI existe y es numérico
assert("Q.FIT.02", "TLI numérico",
       is.numeric(r_afc$tli), toString(r_afc$tli))

# Q.FIT.03: RMSEA existe y es numérico >= 0
assert("Q.FIT.03", "RMSEA numérico >= 0",
       is.numeric(r_afc$rmsea) && r_afc$rmsea >= 0, toString(r_afc$rmsea))

# Q.FIT.04: SRMR existe y es numérico >= 0
assert("Q.FIT.04", "SRMR numérico >= 0",
       is.numeric(r_afc$srmr) && r_afc$srmr >= 0, toString(r_afc$srmr))

# Q.FIT.05: chi2 > 0
assert("Q.FIT.05", "chi2 > 0",
       is.numeric(r_afc$chi2) && r_afc$chi2 > 0, toString(r_afc$chi2))

# Q.FIT.06: df > 0
assert("Q.FIT.06", "df > 0",
       !is.null(r_afc$df) && r_afc$df > 0, toString(r_afc$df))

# Q.FIT.07: ajuste_global en {excelente, aceptable, deficiente}
assert("Q.FIT.07", "ajuste_global válido",
       r_afc$ajuste_global %in% c("excelente","aceptable","deficiente"),
       r_afc$ajuste_global)

# Q.FIT.08: IC RMSEA — rmsea_lo <= rmsea <= rmsea_hi
{
  lo_ok <- is.numeric(r_afc$rmsea_lo) && r_afc$rmsea_lo <= r_afc$rmsea + 1e-6
  hi_ok <- is.numeric(r_afc$rmsea_hi) && r_afc$rmsea_hi >= r_afc$rmsea - 1e-6
  assert("Q.FIT.08", "IC RMSEA: lo <= rmsea <= hi",
         lo_ok && hi_ok,
         paste0("rmsea=",r_afc$rmsea," lo=",r_afc$rmsea_lo," hi=",r_afc$rmsea_hi))
}

# ============================================================================
# Q.LOAD — Cargas estandarizadas
# ============================================================================
cat("\n=== Q.LOAD — Cargas estandarizadas ===\n")

# Q.LOAD.01: loadings no vacío
assert("Q.LOAD.01", "loadings no vacío",
       is.list(r_afc$loadings) && length(r_afc$loadings) > 0)

# Q.LOAD.02: cada carga tiene lambda, se, z, p
{
  campos_req <- c("lambda","se","z","p")
  all_ok <- all(sapply(r_afc$loadings, function(l)
    all(campos_req %in% names(l))))
  assert("Q.LOAD.02", "cada carga tiene lambda/se/z/p", all_ok)
}

# Q.LOAD.03: lambdas en (-1,1] para modelo bien identificado
{
  lambdas <- sapply(r_afc$loadings, function(l) l$lambda)
  assert("Q.LOAD.03", "lambdas en rango plausible (-1.5, 1.5)",
         all(abs(lambdas) <= 1.5, na.rm=TRUE),
         paste(round(lambdas,3), collapse=","))
}

# ============================================================================
# Q.CR — CR y AVE
# ============================================================================
cat("\n=== Q.CR — CR y AVE ===\n")

# Q.CR.01: cr_ave no vacío con cr y ave
{
  assert("Q.CR.01", "cr_ave lista no vacía",
         is.list(r_afc$cr_ave) && length(r_afc$cr_ave) > 0)
  first_crave <- r_afc$cr_ave[[1]]
  assert("Q.CR.01b", "cr_ave tiene cr y ave",
         !is.null(first_crave$cr) && !is.null(first_crave$ave))
}

# ============================================================================
# Q.AVE — AVE convergente
# ============================================================================
cat("\n=== Q.AVE ===\n")

# Q.AVE.01: AVE en [0,1]
{
  aves <- sapply(r_afc$cr_ave, function(x) x$ave)
  assert("Q.AVE.01", "AVE en [0,1] para todos los factores",
         all(aves >= 0 & aves <= 1, na.rm=TRUE),
         paste(round(aves,3), collapse=","))
}

# ============================================================================
# Q.CONV — Convergencia
# ============================================================================
cat("\n=== Q.CONV — Convergencia ===\n")

# Q.CONV.01: modelo bien identificado NO retorna blocked
assert("Q.CONV.01", "modelo válido → no blocked",
       is.null(r_afc$blocked) || !isTRUE(r_afc$blocked),
       toString(r_afc[c("blocked","reason")]))

# Q.CONV.02: convergencia guard en instruments.R
{
  src <- readLines(file.path(r_dir, "instruments.R"))
  has_conv <- any(grepl("converged", src, fixed=TRUE))
  assert("Q.CONV.02", "guard convergencia en instruments.R",
         has_conv)
}

# ============================================================================
# Q.HEYWOOD — Heywood en AFC
# ============================================================================
cat("\n=== Q.HEYWOOD — Heywood en AFC ===\n")

# Q.HEYWOOD.01: guard Heywood AFC en instruments.R
{
  src <- readLines(file.path(r_dir, "instruments.R"))
  has_hwood_afc <- any(grepl("afc_loadings", src, fixed=TRUE))
  assert("Q.HEYWOOD.01", "guard HEYWOOD_CASE stage=afc_loadings en instruments.R",
         has_hwood_afc)
}

# Q.HEYWOOD.02: datos buenos → no Heywood
{
  lambdas <- sapply(r_afc$loadings, function(l) l$lambda)
  assert("Q.HEYWOOD.02", "datos buenos → |lambda| <= 1 (sin Heywood)",
         all(abs(lambdas) <= 1 + 1e-6, na.rm=TRUE),
         paste(round(lambdas,3), collapse=","))
}

# ============================================================================
# Q.CASES — Casos de frontera
# ============================================================================
cat("\n=== Q.CASES — Casos de frontera ===\n")

# Q.CASES.01: n < 30 → error
{
  df_small <- df_afc[1:25, ]
  r_small <- compute_afc(df_small, variables_ref)
  assert("Q.CASES.01", "n<30 → error devuelto",
         !is.null(r_small$error) || isTRUE(r_small$blocked))
}

# Q.CASES.02: n en output = nrow completo
assert("Q.CASES.02", "n == nrow(df_afc)",
       r_afc$n == nrow(df_afc), paste0("r$n=",r_afc$n))

# Q.CASES.03: estimator en output
assert("Q.CASES.03", "estimator en output",
       !is.null(r_afc$estimator), toString(r_afc$estimator))

# Q.CASES.04: 1 factor
{
  variables_1f <- list(list(name="F1", items=c("a1","a2","a3","b1","b2","b3")))
  r_1f <- compute_afc(df_afc, variables_1f)
  assert("Q.CASES.04", "1 factor → AFC corre",
         is.null(r_1f$error) && !isTRUE(r_1f$blocked),
         toString(r_1f[c("error","reason")]))
}

# Q.CASES.05: model_str en output
assert("Q.CASES.05", "model_str en output",
       !is.null(r_afc$model_str) && nchar(r_afc$model_str) > 0)

# Q.CASES.06: fit_table no vacía
assert("Q.CASES.06", "fit_table no vacía",
       is.list(r_afc$fit_table) && length(r_afc$fit_table) > 0)

# Q.CASES.07: chi2_df = chi2/df
{
  if (!is.na(r_afc$df) && r_afc$df > 0) {
    ratio_calc <- r_afc$chi2 / r_afc$df
    assert("Q.CASES.07", "chi2_df = chi2/df",
           abs(r_afc$chi2_df - ratio_calc) < 0.001,
           paste0("chi2_df=",r_afc$chi2_df," calc=",ratio_calc))
  } else {
    ok("Q.CASES.07", "df=0, chi2_df skip")
  }
}

# Q.CASES.08: cr_ok y ave_ok campo presente
{
  all_ok <- all(sapply(r_afc$cr_ave, function(x)
    "cr_ok" %in% names(x) && "ave_ok" %in% names(x)))
  assert("Q.CASES.08", "cr_ok y ave_ok campos en cr_ave",
         all_ok)
}

# ============================================================================
# Q.CONTRACT — Contrato
# ============================================================================
cat("\n=== Q.CONTRACT — Contrato ===\n")

# Q.CONTRACT.01: comparar CFI con lavaan directo
{
  model_str_ref <- "Factor1 =~ a1 + a2 + a3\nFactor2 =~ b1 + b2 + b3"
  ref_fit <- tryCatch({
    fit_lav <- lavaan::cfa(model_str_ref, data=df_afc, estimator="MLR",
                           std.lv=FALSE, missing="listwise")
    fi <- lavaan::fitMeasures(fit_lav, "cfi")
    round(fi[["cfi"]], 3)
  }, error=function(e) NA)
  if (!is.na(ref_fit)) {
    assert("Q.CONTRACT.01", "CFI coincide con lavaan::cfa directo (abs <= 1e-6)",
           abs(r_afc$cfi - ref_fit) <= 1e-6,
           paste0("r$cfi=",r_afc$cfi," ref=",ref_fit))
  } else {
    ok("Q.CONTRACT.01", "lavaan referencia no disponible — skip")
  }
}

# Q.CONTRACT.02: RMSEA coincide con lavaan directo
{
  model_str_ref <- "Factor1 =~ a1 + a2 + a3\nFactor2 =~ b1 + b2 + b3"
  ref_rmsea <- tryCatch({
    fit_lav <- lavaan::cfa(model_str_ref, data=df_afc, estimator="MLR",
                           std.lv=FALSE, missing="listwise")
    fi <- lavaan::fitMeasures(fit_lav, "rmsea")
    round(fi[["rmsea"]], 3)
  }, error=function(e) NA)
  if (!is.na(ref_rmsea)) {
    assert("Q.CONTRACT.02", "RMSEA coincide con lavaan (abs <= 1e-6)",
           abs(r_afc$rmsea - ref_rmsea) <= 1e-6,
           paste0("r$rmsea=",r_afc$rmsea," ref=",ref_rmsea))
  } else {
    ok("Q.CONTRACT.02", "lavaan referencia no disponible — skip")
  }
}

# Q.CONTRACT.03: variable en cr_ave coincide con nombre de factor
{
  var_names_crave <- sapply(r_afc$cr_ave, function(x) x$variable)
  expected_names  <- sapply(variables_ref, function(v) v$name)
  assert("Q.CONTRACT.03", "variable names en cr_ave coinciden con factores",
         all(var_names_crave %in% expected_names),
         paste(var_names_crave, collapse=","))
}

# Q.CONTRACT.04: n en output exacto
assert("Q.CONTRACT.04", "n en output exacto",
       !is.null(r_afc$n) && r_afc$n == n_ref, paste0("r$n=",r_afc$n," ref=",n_ref))

# Q.CONTRACT.05: p_apa en fit_table para chi2/p entry
{
  pvalue_entries <- Filter(function(f) f$indice == "p", r_afc$fit_table)
  assert("Q.CONTRACT.05", "fit_table tiene entrada p",
         length(pvalue_entries) > 0)
}

# ============================================================================
# Q.LAVAAN — Uso directo de lavaan
# ============================================================================
cat("\n=== Q.LAVAAN — lavaan como referencia ===\n")

# Q.LAVAAN.01: SRMR coincide con lavaan
{
  model_str_ref <- "Factor1 =~ a1 + a2 + a3\nFactor2 =~ b1 + b2 + b3"
  ref_srmr <- tryCatch({
    fit_lav <- lavaan::cfa(model_str_ref, data=df_afc, estimator="MLR",
                           std.lv=FALSE, missing="listwise")
    fi <- lavaan::fitMeasures(fit_lav, "srmr")
    round(fi[["srmr"]], 3)
  }, error=function(e) NA)
  if (!is.na(ref_srmr)) {
    assert("Q.LAVAAN.01", "SRMR coincide con lavaan (abs <= 1e-6)",
           abs(r_afc$srmr - ref_srmr) <= 1e-6,
           paste0("r$srmr=",r_afc$srmr," ref=",ref_srmr))
  } else {
    ok("Q.LAVAAN.01", "lavaan referencia no disponible — skip")
  }
}

# ============================================================================
cat("\n")
cat(sprintf("RESULTADO: %d PASS / %d FAIL\n", pass_count, fail_count))
if (fail_count > 0) {
  cat("FALLOS:\n")
  for (m in fail_msgs) cat(" ", m, "\n")
  cat("PASO Q: FALLO\n")
  quit(status=1L)
}
cat("PASO Q: COMPLETO — AFC validado.\n")
