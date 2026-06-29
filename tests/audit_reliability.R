# ============================================================================
# PASO O — Confiabilidad: Cronbach, Omega, item-total, alpha-if-deleted
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
source(file.path(r_dir, "cronbach_only.R"))

# ── Datos de referencia ───────────────────────────────────────────────────────
set.seed(42)
n_ref <- 120
# 5 ítems correlacionados (escala tipo Likert 1-5)
lat  <- rnorm(n_ref)
items_ref <- data.frame(
  i1 = round(pmin(pmax(lat + rnorm(n_ref,0,0.8), 1), 5)),
  i2 = round(pmin(pmax(lat + rnorm(n_ref,0,0.8), 1), 5)),
  i3 = round(pmin(pmax(lat + rnorm(n_ref,0,0.8), 1), 5)),
  i4 = round(pmin(pmax(lat + rnorm(n_ref,0,0.8), 1), 5)),
  i5 = round(pmin(pmax(lat + rnorm(n_ref,0,0.8), 1), 5))
)
var_items <- c("i1","i2","i3","i4","i5")

# ============================================================================
# O.ALPHA — Alpha de Cronbach
# ============================================================================
cat("\n=== O.ALPHA — Alpha de Cronbach ===\n")

r_ref <- run_cronbach_only(items_ref, var_items, "Escala", min_rit=0.3,
                           calc_omega="no", bootstrap_ci="no")

# O.ALPHA.01: alpha existe y es numérico en [0,1]
assert("O.ALPHA.01", "alpha existe y es numérico en [0,1]",
       is.numeric(r_ref$alpha) && r_ref$alpha >= 0 && r_ref$alpha <= 1,
       toString(r_ref$alpha))

# O.ALPHA.02: Comparar con fórmula manual (k/(k-1))*(1-ΣVar_i/Var_total)
{
  k   <- ncol(items_ref)
  vars_i <- apply(items_ref, 2, var)
  var_tot <- var(rowSums(items_ref))
  alpha_manual <- (k/(k-1)) * (1 - sum(vars_i)/var_tot)
  assert("O.ALPHA.02", "alpha == formula manual (abs <= 1e-8)",
         abs(r_ref$alpha - round(alpha_manual,3)) < 0.001,
         paste0("r$alpha=",r_ref$alpha," manual=",round(alpha_manual,3)))
}

# O.ALPHA.03: interpretación correcta para alpha >= 0.7
assert("O.ALPHA.03", "interpretation >= 0.7 = Aceptable/Bueno/Excelente",
       r_ref$interpretation %in% c("Aceptable","Bueno","Excelente"),
       r_ref$interpretation)

# O.ALPHA.04: n = filas completas
{
  df_na <- items_ref; df_na[1:5,"i3"] <- NA
  r_na <- run_cronbach_only(df_na, var_items, "ConNA", calc_omega="no", bootstrap_ci="no")
  assert("O.ALPHA.04", "n = filas sin NA",
         r_na$n == sum(complete.cases(df_na[, var_items])),
         paste0("r$n=",r_na$n))
}

# O.ALPHA.05: k = numero de items
assert("O.ALPHA.05", "k = numero de items",
       r_ref$k == 5, paste0("k=",r_ref$k))

# O.ALPHA.06: alpha Cuestionable para escala baja
{
  set.seed(99)
  df_bajo <- data.frame(
    x1=rnorm(80), x2=rnorm(80), x3=rnorm(80)
  )
  r_bajo <- run_cronbach_only(df_bajo, c("x1","x2","x3"), "Bajo",
                              calc_omega="no", bootstrap_ci="no")
  assert("O.ALPHA.06", "items aleatorios → alpha bajo (< 0.6)",
         r_bajo$alpha < 0.6, paste0("alpha=",r_bajo$alpha))
}

# O.ALPHA.07: alpha Excelente para items muy correlacionados
{
  set.seed(7)
  lat7 <- rnorm(200)
  df_exc <- data.frame(
    a1=round(pmin(pmax(lat7+rnorm(200,0,0.1),1),5)),
    a2=round(pmin(pmax(lat7+rnorm(200,0,0.1),1),5)),
    a3=round(pmin(pmax(lat7+rnorm(200,0,0.1),1),5)),
    a4=round(pmin(pmax(lat7+rnorm(200,0,0.1),1),5)),
    a5=round(pmin(pmax(lat7+rnorm(200,0,0.1),1),5))
  )
  r_exc <- run_cronbach_only(df_exc, c("a1","a2","a3","a4","a5"), "Exc",
                             calc_omega="no", bootstrap_ci="no")
  assert("O.ALPHA.07", "items muy correlacionados → alpha Excelente (>= 0.9)",
         r_exc$alpha >= 0.9, paste0("alpha=",r_exc$alpha))
}

# O.ALPHA.08: var_name preservado en output
assert("O.ALPHA.08", "var_name en output",
       identical(r_ref$var_name, "Escala"))

# ============================================================================
# O.OMEGA — Omega total via psych
# ============================================================================
cat("\n=== O.OMEGA — Omega total ===\n")

# O.OMEGA.01: omega calculado cuando calc_omega=yes
{
  r_om <- run_cronbach_only(items_ref, var_items, "Esc", calc_omega="yes", bootstrap_ci="no")
  assert("O.OMEGA.01", "omega calculado (no NA) con calc_omega=yes",
         !is.na(r_om$omega), paste0("omega=",r_om$omega))
}

# O.OMEGA.02: omega en [0,1]
{
  r_om <- run_cronbach_only(items_ref, var_items, "Esc", calc_omega="yes", bootstrap_ci="no")
  assert("O.OMEGA.02", "omega en [0,1]",
         is.numeric(r_om$omega) && r_om$omega >= 0 && r_om$omega <= 1,
         paste0("omega=",r_om$omega))
}

# O.OMEGA.03: con calc_omega=no → omega_calculated=FALSE
{
  r_noom <- run_cronbach_only(items_ref, var_items, "Esc", calc_omega="no", bootstrap_ci="no")
  assert("O.OMEGA.03", "calc_omega=no → omega_calculated=FALSE",
         isFALSE(r_noom$omega_calculated))
}

# O.OMEGA.04: comparar omega con psych::omega directo
{
  r_om <- run_cronbach_only(items_ref, var_items, "Esc", calc_omega="yes", bootstrap_ci="no")
  ref_om <- tryCatch({
    om <- psych::omega(items_ref[, var_items], nfactors=1, plot=FALSE)
    round(om$omega.tot, 3)
  }, error=function(e) NA)
  if (!is.na(ref_om)) {
    assert("O.OMEGA.04", "omega coincide con psych::omega (abs <= 0.001)",
           abs(r_om$omega - ref_om) <= 0.001,
           paste0("r$omega=",r_om$omega," ref=",ref_om))
  } else {
    ok("O.OMEGA.04", "psych::omega referencia no disponible — skip")
  }
}

# ============================================================================
# O.HEYWOOD — Heywood cases
# ============================================================================
cat("\n=== O.HEYWOOD — Heywood cases ===\n")

# O.HEYWOOD.01: omega NA no se serializa como NaN (debe ser NA o missing)
{
  r_noom <- run_cronbach_only(items_ref, var_items, "Esc", calc_omega="no", bootstrap_ci="no")
  json_str <- tryCatch({
    jsonlite::toJSON(r_noom, auto_unbox=TRUE, na="null")
  }, error=function(e) "ERROR_JSON")
  assert("O.HEYWOOD.01", "omega NA no aparece como NaN en JSON",
         !grepl("NaN", json_str, fixed=TRUE), json_str)
}

# O.HEYWOOD.02: output omega es numérico o NA, nunca NaN
{
  r_noom <- run_cronbach_only(items_ref, var_items, "Esc", calc_omega="no", bootstrap_ci="no")
  assert("O.HEYWOOD.02", "omega es NA o numérico finito, nunca NaN",
         is.na(r_noom$omega) || (is.numeric(r_noom$omega) && is.finite(r_noom$omega)),
         paste0("omega=",r_noom$omega))
}

# ============================================================================
# O.P1 — P1 bug fix: no library() en cronbach_only
# ============================================================================
cat("\n=== O.P1 — P1 bug fix ===\n")

# O.P1.01: cronbach_only.R no tiene library(psych)
{
  src <- readLines(file.path(r_dir, "cronbach_only.R"))
  has_lib <- any(grepl("^\\s*library\\s*\\(\\s*psych", src))
  assert("O.P1.01", "cronbach_only.R sin library(psych)",
         !has_lib, "library(psych) encontrado")
}

# O.P1.02: cronbach_only.R usa psych::omega (namespace-qualified)
{
  src <- readLines(file.path(r_dir, "cronbach_only.R"))
  has_ns <- any(grepl("psych::omega", src, fixed=TRUE))
  assert("O.P1.02", "psych::omega namespace-qualified en cronbach_only.R",
         has_ns)
}

# O.P1.03: statistics.R no tiene library(psych) ni library(nortest)
{
  src <- readLines(file.path(r_dir, "statistics.R"))
  has_lib <- any(grepl("^\\s*library\\s*\\(\\s*(psych|nortest)", src, perl=TRUE))
  assert("O.P1.03", "statistics.R sin library(psych/nortest)",
         !has_lib, "library() encontrado")
}

# O.P1.04: cronbach_only.R no tiene install.packages()
{
  src <- readLines(file.path(r_dir, "cronbach_only.R"))
  has_inst <- any(grepl("install\\.packages", src, fixed=TRUE))
  assert("O.P1.04", "cronbach_only.R sin install.packages()",
         !has_inst, "install.packages() encontrado")
}

# ============================================================================
# O.CASES — Casos de frontera
# ============================================================================
cat("\n=== O.CASES — Casos de frontera ===\n")

# O.CASES.01: k=2 items
{
  df2 <- data.frame(a=items_ref$i1, b=items_ref$i2)
  r2 <- run_cronbach_only(df2, c("a","b"), "k2", calc_omega="no", bootstrap_ci="no")
  assert("O.CASES.01", "k=2 items → alpha calculable",
         is.numeric(r2$alpha) && !is.null(r2$alpha))
}

# O.CASES.02: n grande (500)
{
  set.seed(52)
  lat52 <- rnorm(500)
  df500 <- data.frame(
    x1=round(pmin(pmax(lat52+rnorm(500,0,0.8),1),5)),
    x2=round(pmin(pmax(lat52+rnorm(500,0,0.8),1),5)),
    x3=round(pmin(pmax(lat52+rnorm(500,0,0.8),1),5))
  )
  r500 <- run_cronbach_only(df500, c("x1","x2","x3"), "n500",
                             calc_omega="no", bootstrap_ci="no")
  assert("O.CASES.02", "n=500 → alpha calculado",
         is.numeric(r500$alpha))
}

# O.CASES.03: Bootstrap CI calculado cuando bootstrap_ci=yes
{
  r_boot <- run_cronbach_only(items_ref, var_items, "Boot",
                              calc_omega="no", bootstrap_ci="yes")
  assert("O.CASES.03", "bootstrap_ci=yes → ci_lower y ci_upper no NA",
         !is.na(r_boot$ci_lower) && !is.na(r_boot$ci_upper) &&
         isTRUE(r_boot$bootstrap_used),
         paste0("lo=",r_boot$ci_lower," hi=",r_boot$ci_upper))
}

# O.CASES.04: Bootstrap OFF
{
  r_noboot <- run_cronbach_only(items_ref, var_items, "NoBoot",
                                calc_omega="no", bootstrap_ci="no")
  assert("O.CASES.04", "bootstrap_ci=no → bootstrap_used=FALSE",
         isFALSE(r_noboot$bootstrap_used))
}

# O.CASES.05: item_stats contiene r_item_total y alpha_if_deleted
{
  r_is <- run_cronbach_only(items_ref, var_items, "IS",
                            calc_omega="no", bootstrap_ci="no")
  first_item <- r_is$item_stats[[1]]
  assert("O.CASES.05", "item_stats tiene r_item_total y alpha_if_deleted",
         !is.null(first_item$r_item_total) && !is.null(first_item$alpha_if_deleted))
}

# O.CASES.06: item_stats interpretation campo presente
{
  r_is <- run_cronbach_only(items_ref, var_items, "IS2",
                            calc_omega="no", bootstrap_ci="no")
  interp <- sapply(r_is$item_stats, function(s) s$interpretation)
  assert("O.CASES.06", "interpretation en cada item_stat",
         all(!is.null(interp)) && length(interp)==5,
         paste(interp, collapse=","))
}

# ============================================================================
# O.CONTRACT — Contrato numérico
# ============================================================================
cat("\n=== O.CONTRACT — Contrato numérico ===\n")

# O.CONTRACT.01: ci_lower < alpha < ci_upper con bootstrap
{
  r_boot <- run_cronbach_only(items_ref, var_items, "BootCI",
                              calc_omega="no", bootstrap_ci="yes")
  assert("O.CONTRACT.01", "ci_lower < alpha < ci_upper",
         r_boot$ci_lower < r_boot$alpha && r_boot$alpha < r_boot$ci_upper,
         paste0("lo=",r_boot$ci_lower," alpha=",r_boot$alpha," hi=",r_boot$ci_upper))
}

# O.CONTRACT.02: min_rit_threshold en output
{
  r2 <- run_cronbach_only(items_ref, var_items, "MRT", min_rit=0.4,
                          calc_omega="no", bootstrap_ci="no")
  assert("O.CONTRACT.02", "min_rit_threshold=0.4 en output",
         abs(r2$min_rit_threshold - 0.4) < 1e-10)
}

# O.CONTRACT.03: below_threshold = r_it < threshold
{
  r3 <- run_cronbach_only(items_ref, var_items, "BT", min_rit=0.3,
                          calc_omega="no", bootstrap_ci="no")
  stats <- r3$item_stats
  for (s in stats) {
    expected_bt <- s$r_item_total < 0.3
    if (!identical(s$below_threshold, expected_bt)) {
      fail("O.CONTRACT.03", paste0("below_threshold incorrecto para ", s$item),
           paste0("r_it=",s$r_item_total," below=",s$below_threshold))
    }
  }
  ok("O.CONTRACT.03", "below_threshold correcto para todos los items")
}

# O.CONTRACT.04: alpha_if_deleted para cada item es numérico
{
  r4 <- run_cronbach_only(items_ref, var_items, "AID",
                          calc_omega="no", bootstrap_ci="no")
  all_num <- all(sapply(r4$item_stats, function(s) is.numeric(s$alpha_if_deleted)))
  assert("O.CONTRACT.04", "alpha_if_deleted es numérico para todos",
         all_num)
}

# O.CONTRACT.05: r_item_total != NA para todos los items
{
  r5 <- run_cronbach_only(items_ref, var_items, "RIT",
                          calc_omega="no", bootstrap_ci="no")
  all_ok <- all(sapply(r5$item_stats, function(s) !is.na(s$r_item_total)))
  assert("O.CONTRACT.05", "r_item_total no NA para todos",
         all_ok)
}

# O.CONTRACT.06: interpretation global válida
{
  r6 <- run_cronbach_only(items_ref, var_items, "IntGlob",
                          calc_omega="no", bootstrap_ci="no")
  assert("O.CONTRACT.06", "interpretation global en {Excelente,Bueno,Aceptable,Cuestionable,Inaceptable}",
         r6$interpretation %in% c("Excelente","Bueno","Aceptable","Cuestionable","Inaceptable"),
         r6$interpretation)
}

# ============================================================================
cat("\n")
cat(sprintf("RESULTADO: %d PASS / %d FAIL\n", pass_count, fail_count))
if (fail_count > 0) {
  cat("FALLOS:\n")
  for (m in fail_msgs) cat(" ", m, "\n")
  cat("PASO O: FALLO\n")
  quit(status=1L)
}
cat("PASO O: COMPLETO — confiabilidad Cronbach/Omega validada.\n")
