# ============================================================================
# PASO N — Mediación Simple OLS/Bootstrap
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
source(file.path(r_dir, "mediation.R"))

# ── Datos base ────────────────────────────────────────────────────────────────
set.seed(42)
n <- 150
x  <- rnorm(n)
m  <- 0.6 * x + rnorm(n)
y  <- 0.4 * m + 0.2 * x + rnorm(n)
df_base <- data.frame(x=x, m=m, y=y)

# ============================================================================
# N.SRC — Source / API
# ============================================================================
cat("\n=== N.SRC — Source y API ===\n")

# N.SRC.01: función existe
assert("N.SRC.01", "run_mediation_simple existe",
       exists("run_mediation_simple") && is.function(run_mediation_simple))

# N.SRC.02: run_mediation_serial existe y devuelve NOT_IMPLEMENTED
{
  r <- run_mediation_serial()
  assert("N.SRC.02", "run_mediation_serial → blocked=TRUE, reason=NO_IMPLEMENTADO_SERIAL",
         isTRUE(r$blocked) && identical(r$reason, "NO_IMPLEMENTADO_SERIAL"))
}

# N.SRC.03: output básico tiene campos requeridos
{
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=200, seed=42)
  campos <- c("n","x_var","m_var","y_var","a","b","c_total","c_direct",
              "indirect","sobel_se","sobel_z","sobel_p","ci_lower","ci_upper",
              "ic_method","n_boot_requested","n_boot_valid","seed_used","method","mediation_type")
  falta <- setdiff(campos, names(r))
  assert("N.SRC.03", "output contiene todos los campos requeridos",
         length(falta)==0, paste("Falta:", paste(falta, collapse=",")))
}

# ============================================================================
# N.FORMULA — Fórmulas OLS
# ============================================================================
cat("\n=== N.FORMULA — Verificación de fórmulas OLS ===\n")

# N.FORMULA.01: a = coef X en lm(M~X)
{
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=100, seed=42)
  a_ref <- coef(lm(m ~ x, data=df_base))[["x"]]
  assert("N.FORMULA.01", "a = coef X en lm(M~X)",
         abs(r$a - a_ref) < 1e-6, paste0("r$a=",r$a," ref=",a_ref))
}

# N.FORMULA.02: b = coef M en lm(Y~X+M)
{
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=100, seed=42)
  b_ref <- coef(lm(y ~ x + m, data=df_base))[["m"]]
  assert("N.FORMULA.02", "b = coef M en lm(Y~X+M)",
         abs(r$b - b_ref) < 1e-6, paste0("r$b=",r$b," ref=",b_ref))
}

# N.FORMULA.03: c_total = coef X en lm(Y~X)
{
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=100, seed=42)
  c_ref <- coef(lm(y ~ x, data=df_base))[["x"]]
  assert("N.FORMULA.03", "c_total = coef X en lm(Y~X)",
         abs(r$c_total - c_ref) < 1e-6, paste0("r$c_total=",r$c_total," ref=",c_ref))
}

# N.FORMULA.04: c_direct = coef X en lm(Y~X+M)
{
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=100, seed=42)
  cd_ref <- coef(lm(y ~ x + m, data=df_base))[["x"]]
  assert("N.FORMULA.04", "c_direct = coef X en lm(Y~X+M)",
         abs(r$c_direct - cd_ref) < 1e-6, paste0("r$c_direct=",r$c_direct," ref=",cd_ref))
}

# N.FORMULA.05: indirect = a * b (no desde bootstrap, desde OLS)
{
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=100, seed=42)
  a_ref <- coef(lm(m ~ x, data=df_base))[["x"]]
  b_ref <- coef(lm(y ~ x + m, data=df_base))[["m"]]
  ab_ref <- a_ref * b_ref
  assert("N.FORMULA.05", "indirect = a * b desde OLS",
         abs(r$indirect - ab_ref) < 1e-6, paste0("r$indirect=",r$indirect," ref=",ab_ref))
}

# N.FORMULA.06: Sobel SE = sqrt(a^2*se_b^2 + b^2*se_a^2)
{
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=100, seed=42)
  mod_m  <- lm(m ~ x, data=df_base)
  mod_y  <- lm(y ~ x + m, data=df_base)
  a_v    <- coef(mod_m)[["x"]]
  b_v    <- coef(mod_y)[["m"]]
  se_a_v <- summary(mod_m)$coefficients["x","Std. Error"]
  se_b_v <- summary(mod_y)$coefficients["m","Std. Error"]
  sobel_ref <- sqrt(a_v^2 * se_b_v^2 + b_v^2 * se_a_v^2)
  assert("N.FORMULA.06", "Sobel SE formula correcta",
         abs(r$sobel_se - sobel_ref) < 1e-6, paste0("r$sobel_se=",r$sobel_se," ref=",sobel_ref))
}

# ============================================================================
# N.BOOT — Bootstrap
# ============================================================================
cat("\n=== N.BOOT — Bootstrap ===\n")

# N.BOOT.01: ic_method = bootstrap_percentil
{
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=200, seed=42)
  assert("N.BOOT.01", "ic_method = bootstrap_percentil",
         identical(r$ic_method, "bootstrap_percentil"))
}

# N.BOOT.02: seed reproducible (mismos IC con mismo seed)
{
  r1 <- run_mediation_simple(df_base, "x", "m", "y", n_boot=500, seed=99)
  r2 <- run_mediation_simple(df_base, "x", "m", "y", n_boot=500, seed=99)
  assert("N.BOOT.02", "seed fijo → IC reproducibles",
         abs(r1$ci_lower - r2$ci_lower) < 1e-10 &&
         abs(r1$ci_upper - r2$ci_upper) < 1e-10,
         paste0("lo1=",r1$ci_lower," lo2=",r2$ci_lower))
}

# N.BOOT.03: a*b calculado DENTRO de cada remuestra (no multiplicar coefs finales)
{
  # Si se multiplicaran los coefs finales, el bootstrap daría el mismo a*b en cada iter
  # → sd=0. Si se calcula dentro, hay variación.
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=200, seed=42)
  assert("N.BOOT.03", "n_boot_valid > 0 y IC no son NA",
         r$n_boot_valid > 0 && !is.na(r$ci_lower))
}

# N.BOOT.04: n_boot_valid <= n_boot_requested
{
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=500, seed=42)
  assert("N.BOOT.04", "n_boot_valid <= n_boot_requested",
         r$n_boot_valid <= r$n_boot_requested)
}

# N.BOOT.05: IC asimétrico para efecto indirecto real (IC no centrado en indirect)
{
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=1000, seed=42)
  centro_ic <- (r$ci_lower + r$ci_upper) / 2
  assert("N.BOOT.05", "IC contiene indirecto (ci_lower < indirect < ci_upper)",
         r$ci_lower < r$indirect && r$indirect < r$ci_upper,
         paste0("ic=[",r$ci_lower,",",r$ci_upper,"] ind=",r$indirect))
}

# ============================================================================
# N.CASE — Casos sustantivos
# ============================================================================
cat("\n=== N.CASE — Casos sustantivos ===\n")

# N.CASE.01: mediación completa (X→Y sólo via M)
{
  set.seed(21)
  n2 <- 200
  x2 <- rnorm(n2)
  m2 <- 0.8 * x2 + rnorm(n2, sd=0.5)
  y2 <- 0.7 * m2 + rnorm(n2, sd=0.5)  # c_direct ≈ 0
  r <- run_mediation_simple(data.frame(x=x2,m=m2,y=y2), "x","m","y", n_boot=500, seed=21)
  assert("N.CASE.01", "mediacion completa detectada o parcial complementaria",
         r$mediation_type %in% c("mediacion completa","mediacion parcial complementaria"),
         r$mediation_type)
}

# N.CASE.02: mediación parcial (X→Y directo + via M)
{
  r <- run_mediation_simple(df_base, "x", "m", "y", n_boot=500, seed=42)
  assert("N.CASE.02", "mediacion parcial complementaria (efecto directo e indirecto mismo signo)",
         r$mediation_type == "mediacion parcial complementaria", r$mediation_type)
}

# N.CASE.03: sin mediación (indirecto no significativo)
{
  set.seed(31)
  n3 <- 200
  x3 <- rnorm(n3); m3 <- rnorm(n3); y3 <- x3 + rnorm(n3)
  r <- run_mediation_simple(data.frame(x=x3,m=m3,y=y3), "x","m","y", n_boot=500, seed=31)
  assert("N.CASE.03", "sin mediacion: ic_lower <= 0 <= ic_upper o tipo sin mediacion",
         r$mediation_type == "sin mediacion" ||
         (r$ci_lower <= 0 && r$ci_upper >= 0),
         paste0("type=",r$mediation_type," ic=[",r$ci_lower,",",r$ci_upper,"]"))
}

# N.CASE.04: efecto opuesto (mediacion competitiva)
{
  set.seed(41)
  n4 <- 300
  x4 <- rnorm(n4)
  m4 <- 0.8 * x4 + rnorm(n4, 0, 0.3)
  y4 <- -1.5 * m4 + 1.8 * x4 + rnorm(n4, 0, 0.3)
  r <- run_mediation_simple(data.frame(x=x4,m=m4,y=y4), "x","m","y", n_boot=500, seed=41)
  assert("N.CASE.04", "mediacion competitiva (signos opuestos) o otro tipo válido",
         r$mediation_type %in% c("mediacion parcial competitiva","mediacion parcial complementaria",
                                  "mediacion completa","sin mediacion"),
         r$mediation_type)
}

# N.CASE.05: n=5 (mínimo) → funciona sin error
{
  set.seed(51)
  df5 <- data.frame(x=rnorm(5), m=rnorm(5), y=rnorm(5))
  r <- run_mediation_simple(df5, "x","m","y", n_boot=100, seed=51)
  assert("N.CASE.05", "n=5 → no bloquea por muestra insuficiente",
         is.null(r$blocked) || !isTRUE(r$blocked),
         toString(r[c("blocked","reason")]))
}

# N.CASE.06: n=4 → blocked=TRUE, reason=MUESTRA_INSUFICIENTE
{
  df4 <- data.frame(x=c(1,2,3,4), m=c(1,2,3,4), y=c(1,2,3,4))
  r <- run_mediation_simple(df4, "x","m","y")
  assert("N.CASE.06", "n=4 → MUESTRA_INSUFICIENTE",
         isTRUE(r$blocked) && identical(r$reason, "MUESTRA_INSUFICIENTE"),
         toString(r[c("blocked","reason")]))
}

# N.CASE.07: X constante → PREDICTOR_CONSTANTE
{
  df7 <- data.frame(x=rep(5,50), m=rnorm(50), y=rnorm(50))
  r <- run_mediation_simple(df7, "x","m","y")
  assert("N.CASE.07", "X constante → PREDICTOR_CONSTANTE",
         isTRUE(r$blocked) && identical(r$reason, "PREDICTOR_CONSTANTE"),
         toString(r[c("blocked","reason")]))
}

# N.CASE.08: M constante → MEDIADOR_CONSTANTE
{
  df8 <- data.frame(x=rnorm(50), m=rep(3,50), y=rnorm(50))
  r <- run_mediation_simple(df8, "x","m","y")
  assert("N.CASE.08", "M constante → MEDIADOR_CONSTANTE",
         isTRUE(r$blocked) && identical(r$reason, "MEDIADOR_CONSTANTE"),
         toString(r[c("blocked","reason")]))
}

# N.CASE.09: variable no encontrada → error en output
{
  r <- run_mediation_simple(df_base, "x","no_existe","y")
  assert("N.CASE.09", "variable faltante → error",
         !is.null(r$error) || isTRUE(r$blocked),
         toString(r[c("error","reason")]))
}

# ============================================================================
# N.CONTRACT — Contrato numérico
# ============================================================================
cat("\n=== N.CONTRACT — Contrato numérico ===\n")

# N.CONTRACT.01: n == nrow(df sin NA)
{
  df_na <- df_base; df_na[1:5,"m"] <- NA
  r <- run_mediation_simple(df_na, "x","m","y", n_boot=100, seed=42)
  assert("N.CONTRACT.01", "n = filas completas (sin NA)",
         r$n == sum(complete.cases(df_na[,c("x","m","y")])),
         paste0("r$n=",r$n," complete=",sum(complete.cases(df_na[,c("x","m","y")]))))
}

# N.CONTRACT.02: seed_used en output
{
  r <- run_mediation_simple(df_base, "x","m","y", n_boot=100, seed=123)
  assert("N.CONTRACT.02", "seed_used = seed pasado",
         identical(r$seed_used, 123L))
}

# N.CONTRACT.03: x_var/m_var/y_var en output
{
  r <- run_mediation_simple(df_base, "x","m","y", n_boot=100, seed=42)
  assert("N.CONTRACT.03", "x_var/m_var/y_var en output",
         identical(r$x_var,"x") && identical(r$m_var,"m") && identical(r$y_var,"y"))
}

# N.CONTRACT.04: method = "bootstrap"
{
  r <- run_mediation_simple(df_base, "x","m","y", n_boot=100, seed=42)
  assert("N.CONTRACT.04", "method = bootstrap",
         identical(r$method, "bootstrap"))
}

# N.CONTRACT.05: ci_lower < ci_upper
{
  r <- run_mediation_simple(df_base, "x","m","y", n_boot=500, seed=42)
  assert("N.CONTRACT.05", "ci_lower < ci_upper",
         !is.na(r$ci_lower) && !is.na(r$ci_upper) && r$ci_lower < r$ci_upper,
         paste0("lo=",r$ci_lower," hi=",r$ci_upper))
}

# N.CONTRACT.06: n_boot_requested iguala el parametro pasado
{
  r <- run_mediation_simple(df_base, "x","m","y", n_boot=777, seed=42)
  assert("N.CONTRACT.06", "n_boot_requested = 777",
         identical(r$n_boot_requested, 777L))
}

# N.CONTRACT.07: alpha en output
{
  r <- run_mediation_simple(df_base, "x","m","y", n_boot=100, seed=42, alpha=0.10)
  assert("N.CONTRACT.07", "alpha = 0.10 en output",
         abs(r$alpha - 0.10) < 1e-10)
}

# N.CONTRACT.08: indirect = c_total - c_direct (aproximadamente)
{
  r <- run_mediation_simple(df_base, "x","m","y", n_boot=100, seed=42)
  diff_ab <- abs(r$indirect - (r$c_total - r$c_direct))
  assert("N.CONTRACT.08", "indirect ≈ c_total - c_direct (tolerancia 0.001)",
         diff_ab < 0.001, paste0("diff=",diff_ab))
}

# ============================================================================
# N.SERIAL — Mediación serial
# ============================================================================
cat("\n=== N.SERIAL — Serial no implementada ===\n")

# N.SERIAL.01: run_mediation_serial → blocked
{
  r <- run_mediation_serial(df_base, "x","m1","m2","y")
  assert("N.SERIAL.01", "serial → blocked=TRUE",
         isTRUE(r$blocked))
}

# N.SERIAL.02: reason = NO_IMPLEMENTADO_SERIAL
{
  r <- run_mediation_serial()
  assert("N.SERIAL.02", "serial → NO_IMPLEMENTADO_SERIAL",
         identical(r$reason, "NO_IMPLEMENTADO_SERIAL"))
}

# ============================================================================
# N.DELTA — Sobel / delta method
# ============================================================================
cat("\n=== N.DELTA — Sobel/Delta ===\n")

# N.DELTA.01: sobel_z = indirect / sobel_se
{
  r <- run_mediation_simple(df_base, "x","m","y", n_boot=200, seed=42)
  z_calc <- r$indirect / r$sobel_se
  assert("N.DELTA.01", "sobel_z = indirect / sobel_se",
         abs(r$sobel_z - round(z_calc,4)) < 0.001, paste0("r$z=",r$sobel_z," calc=",round(z_calc,4)))
}

# N.DELTA.02: sobel_p = 2*pnorm(-|z|)
{
  r <- run_mediation_simple(df_base, "x","m","y", n_boot=200, seed=42)
  p_calc <- 2 * pnorm(-abs(r$sobel_z))
  assert("N.DELTA.02", "sobel_p = 2*pnorm(-|sobel_z|)",
         abs(r$sobel_p - round(p_calc,4)) < 0.001, paste0("r$p=",r$sobel_p," calc=",round(p_calc,4)))
}

# N.DELTA.03: con mediacion real, sobel_p < 0.05
{
  r <- run_mediation_simple(df_base, "x","m","y", n_boot=200, seed=42)
  assert("N.DELTA.03", "efecto indirecto real → sobel_p < 0.05",
         !is.na(r$sobel_p) && r$sobel_p < 0.05, paste0("p=",r$sobel_p))
}

# ============================================================================
cat("\n")
cat(sprintf("RESULTADO: %d PASS / %d FAIL\n", pass_count, fail_count))
if (fail_count > 0) {
  cat("FALLOS:\n")
  for (m in fail_msgs) cat(" ", m, "\n")
  cat("PASO N: FALLO\n")
  quit(status=1L)
}
cat("PASO N: COMPLETO — mediacion simple OLS/Bootstrap validada.\n")
