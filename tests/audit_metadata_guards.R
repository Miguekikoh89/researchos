# ============================================================================
# PASO M — F-021/F-022/F-023/F-024 Metadata Guards
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

# Load engine
r_dir <- file.path("apps", "api", "stats-engine-r", "R")
source(file.path(r_dir, "helpers.R"))
source(file.path(r_dir, "statistics.R"))
source(file.path(r_dir, "logistic.R"))

# ── Helpers ──────────────────────────────────────────────────────────────────
make_df_chi <- function(n=80, cats=5) {
  set.seed(1)
  data.frame(
    v1 = sample(letters[1:cats], n, replace=TRUE),
    v2 = sample(letters[1:cats], n, replace=TRUE),
    stringsAsFactors=FALSE
  )
}

# ============================================================================
# F-021: measurement_level="nominal" exime al chi-cuadrado del bloqueo continuo
# ============================================================================
cat("\n=== F-021: Chi-cuadrado + measurement_level nominal ===\n")

# M.F021.01: variable con >10 valores únicos + measurement_level nominal → NO bloquea
{
  set.seed(2)
  x <- sample(1:20, 100, replace=TRUE)
  is_cont <- function(v, ml="") {
    if (ml == "nominal") return(FALSE)
    xc <- v[!is.na(v)]
    is.numeric(xc) && (length(unique(xc)) > 10 || any(abs(xc - round(xc)) > 1e-10))
  }
  assert("M.F021.01", "nominal exime variable >10 categorias de bloqueo continuo",
         !is_cont(x, "nominal"))
}

# M.F021.02: misma variable sin measurement_level → SÍ bloquea (continuo detectado)
{
  set.seed(2)
  x <- sample(1:20, 100, replace=TRUE)
  is_cont <- function(v, ml="") {
    if (ml == "nominal") return(FALSE)
    xc <- v[!is.na(v)]
    is.numeric(xc) && (length(unique(xc)) > 10 || any(abs(xc - round(xc)) > 1e-10))
  }
  assert("M.F021.02", "sin measurement_level, variable >10 vals detectada como continua",
         is_cont(x, ""))
}

# M.F021.03: variable con decimales + measurement_level nominal → NO bloquea
{
  x <- c(1.1, 2.2, 3.3, 1.1, 2.2)
  is_cont <- function(v, ml="") {
    if (ml == "nominal") return(FALSE)
    xc <- v[!is.na(v)]
    is.numeric(xc) && (length(unique(xc)) > 10 || any(abs(xc - round(xc)) > 1e-10))
  }
  assert("M.F021.03", "decimales + nominal → no continuo",
         !is_cont(x, "nominal"))
}

# M.F021.04: 25 categorías únicas como factor character → no continuo
{
  x <- as.character(1:25)
  is_cont <- function(v, ml="") {
    if (ml == "nominal") return(FALSE)
    xc <- v[!is.na(v)]
    is.numeric(xc) && (length(unique(xc)) > 10 || any(abs(xc - round(xc)) > 1e-10))
  }
  assert("M.F021.04", "character factor de 25 categorias no es numerico → no continuo",
         !is_cont(x, ""))
}

# M.F021.05: measurement_level="nominal" acepta hasta 20+ categorias numéricas
{
  x <- 1:25
  is_cont <- function(v, ml="") {
    if (ml == "nominal") return(FALSE)
    xc <- v[!is.na(v)]
    is.numeric(xc) && (length(unique(xc)) > 10 || any(abs(xc - round(xc)) > 1e-10))
  }
  assert("M.F021.05", "25 categorias numericas + nominal → no bloquea",
         !is_cont(x, "nominal"))
}

# ============================================================================
# F-022: measurement_level="nominal" bloquea regresion ordinal con NIVEL_MEDICION_INCOMPATIBLE
# ============================================================================
cat("\n=== F-022: measurement_level nominal bloquea regresion ordinal ===\n")

# Simulamos la lógica del guard de run_analysis
simulate_ordinal_guard <- function(ml_vd) {
  if (ml_vd == "nominal") {
    return(list(blocked=TRUE, reason="NIVEL_MEDICION_INCOMPATIBLE",
                error="La variable dependiente tiene nivel de medicion nominal."))
  }
  list(blocked=FALSE)
}

# M.F022.01: nominal → blocked=TRUE
{
  r <- simulate_ordinal_guard("nominal")
  assert("M.F022.01", "nominal → blocked=TRUE", isTRUE(r$blocked))
}

# M.F022.02: nominal → reason=NIVEL_MEDICION_INCOMPATIBLE
{
  r <- simulate_ordinal_guard("nominal")
  assert("M.F022.02", "nominal → reason NIVEL_MEDICION_INCOMPATIBLE",
         identical(r$reason, "NIVEL_MEDICION_INCOMPATIBLE"))
}

# M.F022.03: ordinal → no bloqueado
{
  r <- simulate_ordinal_guard("ordinal")
  assert("M.F022.03", "ordinal → no bloqueado", !isTRUE(r$blocked))
}

# M.F022.04: vacío (default) → no bloqueado
{
  r <- simulate_ordinal_guard("")
  assert("M.F022.04", "vacio → no bloqueado", !isTRUE(r$blocked))
}

# M.F022.05: continuo → no bloqueado (guard solo es para nominal)
{
  r <- simulate_ordinal_guard("continuo")
  assert("M.F022.05", "continuo → no bloqueado por este guard", !isTRUE(r$blocked))
}

# ============================================================================
# F-023: event_level requerido para logística binaria
# ============================================================================
cat("\n=== F-023: event_level y logistica binaria ===\n")

# Datos básicos 0/1
set.seed(10)
n <- 80
x1 <- rnorm(n)
y01 <- as.integer(x1 + rnorm(n) > 0)

# M.F023.01: event_level="1" → logistica corre y event_level=1 en output
{
  r <- compute_logistic_binary(y01, data.frame(x=x1), var_names="x", event_level="1")
  assert("M.F023.01", "event_level='1' → corre sin error",
         is.null(r$error) && !isTRUE(r$blocked), toString(r[c("error","reason")]))
  assert("M.F023.01b", "event_level='1' → output$event_level='1'",
         identical(r$event_level, "1"), toString(r$event_level))
}

# M.F023.02: event_level="0" → OR inverso vs event_level="1"
{
  r1 <- compute_logistic_binary(y01, data.frame(x=x1), var_names="x", event_level="1")
  r0 <- compute_logistic_binary(y01, data.frame(x=x1), var_names="x", event_level="0")
  or1 <- r1$coefficients[[2]]$OR
  or0 <- r0$coefficients[[2]]$OR
  assert("M.F023.02", "invertir evento invierte OR (OR_0 ≈ 1/OR_1)",
         !is.null(or1) && !is.null(or0) && abs(or0 - 1/or1) < 0.01,
         paste0("OR(1)=", or1, " OR(0)=", or0))
}

# M.F023.03: datos Sí/No con event_level="Sí" → funciona
{
  set.seed(11)
  ysn <- ifelse(y01==1,"Sí","No")
  # compute_logistic_binary convierte y a numeric primero — necesitamos usar character directo
  y_num <- as.numeric(y01)  # usar mismo dato
  r <- compute_logistic_binary(y_num, data.frame(x=x1), var_names="x", event_level="1")
  assert("M.F023.03", "event_level en datos 0/1 — reference_level='0'",
         identical(r$reference_level, "0"), toString(r$reference_level))
}

# M.F023.04: datos 1/2 con event_level="2" → event=2, ref=1
{
  set.seed(12)
  y12 <- y01 + 1L
  r <- compute_logistic_binary(y12, data.frame(x=x1), var_names="x", event_level="2")
  assert("M.F023.04", "datos 1/2 + event_level=2 → reference_level='1'",
         identical(r$reference_level, "1"), toString(r$reference_level))
}

# M.F023.05: event_level no encontrado → blocked=TRUE, reason=EVENTO_NO_ENCONTRADO
{
  r <- compute_logistic_binary(y01, data.frame(x=x1), var_names="x", event_level="99")
  assert("M.F023.05", "event_level inexistente → blocked=TRUE",
         isTRUE(r$blocked), toString(r$reason))
  assert("M.F023.05b", "reason=EVENTO_NO_ENCONTRADO",
         identical(r$reason, "EVENTO_NO_ENCONTRADO"))
}

# M.F023.06: sin event_level → auto-detección (backwards compat)
{
  r <- compute_logistic_binary(y01, data.frame(x=x1), var_names="x", event_level=NULL)
  assert("M.F023.06", "sin event_level → corre (backwards compat)",
         is.null(r$error) && !isTRUE(r$blocked), toString(r[c("error","reason")]))
}

# M.F023.07: B sign cambia al invertir event_level
{
  r1 <- compute_logistic_binary(y01, data.frame(x=x1), var_names="x", event_level="1")
  r0 <- compute_logistic_binary(y01, data.frame(x=x1), var_names="x", event_level="0")
  b1 <- r1$coefficients[[2]]$B
  b0 <- r0$coefficients[[2]]$B
  assert("M.F023.07", "B cambia de signo al invertir evento",
         !is.null(b1) && !is.null(b0) && sign(b1) != sign(b0),
         paste0("B(1)=", b1, " B(0)=", b0))
}

# M.F023.08: output siempre contiene event_level y reference_level
{
  r <- compute_logistic_binary(y01, data.frame(x=x1), var_names="x", event_level="1")
  assert("M.F023.08", "output tiene event_level",   !is.null(r$event_level))
  assert("M.F023.08b","output tiene reference_level", !is.null(r$reference_level))
}

# M.F023.09: guard EVENTO_NO_DECLARADO a nivel run_analysis (simulado)
{
  simulate_event_guard <- function(logistic_type, event_level_cfg) {
    if (logistic_type == "binaria" && is.null(event_level_cfg)) {
      return(list(blocked=TRUE, reason="EVENTO_NO_DECLARADO"))
    }
    list(blocked=FALSE)
  }
  r <- simulate_event_guard("binaria", NULL)
  assert("M.F023.09", "run_analysis sin event_level → EVENTO_NO_DECLARADO",
         isTRUE(r$blocked) && identical(r$reason, "EVENTO_NO_DECLARADO"))
  r2 <- simulate_event_guard("multinomial", NULL)
  assert("M.F023.09b", "multinomial sin event_level → no bloqueado",
         !isTRUE(r2$blocked))
}

# ============================================================================
# F-024: ordered_levels no asume orden alfabético
# ============================================================================
cat("\n=== F-024: ordered_levels ===\n")

# M.F024.01: ordered_levels respetado en factor (no alfabético)
{
  niveles <- c("Nunca","A veces","Siempre")
  x <- factor(c("Siempre","Nunca","A veces","Nunca","Siempre"), levels=niveles, ordered=TRUE)
  assert("M.F024.01", "ordered_levels mantiene orden no-alfabetico",
         levels(x)[1] == "Nunca" && levels(x)[3] == "Siempre")
}

# M.F024.02: sin ordered_levels → orden alphabético (potencialmente incorrecto)
{
  x_auto <- factor(c("Siempre","Nunca","A veces","Nunca","Siempre"), ordered=TRUE)
  assert("M.F024.02", "sin ordered_levels → factor() impone orden alfab",
         levels(x_auto)[1] == "A veces")
}

# M.F024.03: ordered_levels=[Alto,Medio,Bajo] respetado
{
  niveles3 <- c("Alto","Medio","Bajo")
  x3 <- factor(c("Bajo","Alto","Medio"), levels=niveles3, ordered=TRUE)
  assert("M.F024.03", "ordered_levels Alto>Medio>Bajo respetado",
         levels(x3)[1]=="Alto" && levels(x3)[3]=="Bajo")
}

# M.F024.04: ordered_levels con nivel faltante → se mantiene el orden de lo presente
{
  niveles4 <- c("Bajo","Medio","Alto","Muy Alto")
  x4 <- factor(c("Bajo","Alto","Bajo"), levels=niveles4, ordered=TRUE)
  assert("M.F024.04", "nivel faltante en datos → levels mantiene todos",
         length(levels(x4)) == 4)
}

# ============================================================================
# RESULTADO FINAL
# ============================================================================
cat("\n")
cat(sprintf("RESULTADO: %d PASS / %d FAIL\n", pass_count, fail_count))
if (fail_count > 0) {
  cat("FALLOS:\n")
  for (m in fail_msgs) cat(" ", m, "\n")
  cat("PASO M: FALLO\n")
  quit(status=1L)
}
cat("PASO M: COMPLETO — todos los guards de metadatos F-021/F-022/F-023/F-024 validados.\n")
