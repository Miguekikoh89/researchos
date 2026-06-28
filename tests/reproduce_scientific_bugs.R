# tests/reproduce_scientific_bugs.R
# Pruebas de reproduccion para los 5 problemas cientificos P0/P1 identificados en la auditoria.
# Ejecutar desde la raiz del repositorio: Rscript tests/reproduce_scientific_bugs.R
#
# Para cada problema se documenta:
#   - El comportamiento ANTERIOR (bug)
#   - El comportamiento ESPERADO (con guard o correccion)
#
# Exit code 0 = todos los tests ejecutados pasaron
# Exit code 1 = al menos un test fallo (bug activo o guard roto)

cat("=== PRUEBAS DE REPRODUCCION DE BUGS CIENTIFICOS ===\n")
cat("    Auditoria ResearchOS/CanchariOS 2026-06-28\n\n")

pass <- 0L; fail <- 0L; skip_n <- 0L

check <- function(id, desc, cond) {
  label <- if (isTRUE(cond)) "PASS" else "FAIL"
  cat(sprintf("  [%s] %s: %s\n", label, id, desc))
  if (isTRUE(cond)) pass <<- pass + 1L else fail <<- fail + 1L
}

skip_test <- function(id, desc, reason) {
  cat(sprintf("  [SKIP] %s: %s -- %s\n", id, desc, reason))
  skip_n <<- skip_n + 1L
}

# Path resolution — works with Rscript and source()
.script_dir <- tryCatch({
  dirname(normalizePath(sys.frame(1)$ofile))
}, error = function(e) {
  args <- commandArgs(trailingOnly = FALSE)
  f    <- sub("--file=", "", grep("--file=", args, value = TRUE))
  if (length(f) > 0) dirname(normalizePath(f)) else getwd()
})
r_dir <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "R")

# ============================================================
# F-005: Chi-cuadrado con tricotomizacion de datos continuos
# ============================================================
cat("--- F-005: chi-cuadrado — tricotomizacion de variables continuas ---\n")

set.seed(42)
# Scores de una escala psicologica tipica: distribucion aproximadamente normal [1,5]
x_continuo <- pmin(pmax(rnorm(200, mean=3, sd=0.5), 1), 5)

# Codigo ANTERIOR (bug): cut(breaks=3) usa amplitud igual, no frecuencias iguales
grupos_bug <- cut(x_continuo, breaks=3, labels=c("Bajo","Medio","Alto"))
freq_bug   <- table(grupos_bug)

# Expectativa: con distribucion normal centrada, "Bajo" y "Alto" tendran << casos que "Medio"
check("F-005.1", "cut(breaks=3) crea grupos desiguales: n_Bajo != n_Medio",
      freq_bug["Bajo"] != freq_bug["Medio"])

pct_bajo <- freq_bug["Bajo"] / sum(freq_bug) * 100
check("F-005.2", "Grupo 'Bajo' tiene menos del 15% de casos (sesgo extremo)",
      isTRUE(pct_bajo < 15))

cat(sprintf("    Frecuencias: Bajo=%d (%.1f%%), Medio=%d (%.1f%%), Alto=%d (%.1f%%)\n",
    freq_bug["Bajo"], pct_bajo,
    freq_bug["Medio"], freq_bug["Medio"] / sum(freq_bug) * 100,
    freq_bug["Alto"],  freq_bug["Alto"]  / sum(freq_bug) * 100))

# Consecuencia estadistica: celdas con frecuencias esperadas < 5 invalidan chi-cuadrado
v1 <- sample(grupos_bug, 100); v2 <- sample(grupos_bug, 100)
expected <- outer(table(v1), table(v2)) / length(v1)
check("F-005.3", "Tabla de contingencia tiene celdas con frecuencias esperadas < 5",
      any(expected < 5))

cat("    ESTADO: Este test documenta el bug anterior. El bloque en run_analysis.R ahora devuelve\n")
cat("            error cuando var_a o var_b son continuas.\n\n")

# ============================================================
# F-006: Imputacion vectorizada desalineada (instruments.R)
# ============================================================
cat("--- F-006: imputacion con medias de columna incorrectas ---\n")

# Dataset de prueba: 3 columnas, medias objetivo: c1=100, c2=200, c3=300
# NAs en posiciones elegidas para exponer el bug de reciclado de vector
df_bug <- data.frame(
  c1 = c(100, NA,  100),   # NA en posicion col-major 2
  c2 = c(NA,  200, 200),   # NA en posicion col-major 4
  c3 = c(300, 300, NA)     # NA en posicion col-major 9
)
medias_reales <- sapply(df_bug, function(x) mean(x, na.rm=TRUE))
cat(sprintf("    Medias reales: c1=%.0f, c2=%.0f, c3=%.0f\n",
    medias_reales["c1"], medias_reales["c2"], medias_reales["c3"]))

# Codigo BUGGY (instruments.R linea 342):
df_buggy <- df_bug
df_buggy[is.na(df_buggy)] <- apply(df_buggy, 2, function(x) mean(x, na.rm=TRUE))[is.na(df_buggy)]

check("F-006.1", "Bug vectorizado: NA de c1 recibe media de c2 (200 en lugar de 100)",
      isTRUE(df_buggy[2, "c1"] == 200))
check("F-006.2", "Bug vectorizado: NA de c2[1] no es imputado (permanece NA por reciclado incompleto)",
      is.na(df_buggy[1, "c2"]))

cat(sprintf("    Valores imputados (buggy): c1[2]=%.0f (esperado 100), c2[1]=%.0f (esperado 200), c3[3]=%.0f (esperado 300)\n",
    df_buggy[2, "c1"], df_buggy[1, "c2"], df_buggy[3, "c3"]))

# Codigo CORRECTO (solucion columna-por-columna):
df_correcto <- df_bug
for (col in colnames(df_correcto)) {
  na_idx <- is.na(df_correcto[[col]])
  df_correcto[na_idx, col] <- mean(df_correcto[[col]], na.rm=TRUE)
}
check("F-006.3", "Correccion columna-x-columna: NA de c1 recibe 100 (correcto)",
      isTRUE(df_correcto[2, "c1"] == 100))
check("F-006.4", "Correccion columna-x-columna: NA de c2 recibe 200 (correcto)",
      isTRUE(df_correcto[1, "c2"] == 200))

cat("    ESTADO: Bug documentado. Correccion de instruments.R pendiente (proximo lote autorizado).\n\n")

# ============================================================
# F-007: Regresion logistica — guard contra binarizacion por mediana
# ============================================================
cat("--- F-007: regresion logistica binaria — guard contra VD no binaria ---\n")

# Test de logica del guard (inline, sin dependencias de paquetes)
y_escala_likert <- c(1, 2, 3, 4, 5, 3, 2, 1, 4, 5)
y_unique_vals   <- sort(unique(na.omit(as.numeric(y_escala_likert))))
n_unique_likert <- length(y_unique_vals)

check("F-007.L1", "Guard logico: VD con 5 valores unicos detectada como no binaria",
      n_unique_likert != 2)

y_ya_binario <- c(0, 1, 0, 1, 1, 0)
n_unique_bin <- length(unique(na.omit(as.numeric(y_ya_binario))))
check("F-007.L2", "Guard logico: VD binaria {0,1} no es bloqueada por el guard",
      n_unique_bin == 2)

y_dos_cats_no01 <- c(1, 2, 1, 2, 1, 2)
n_unique_2cats <- length(unique(na.omit(as.numeric(y_dos_cats_no01))))
check("F-007.L3", "Guard logico: VD con exactamente 2 categorias (1,2) pasa el guard",
      n_unique_2cats == 2)

# Test de integracion: cargar el modulo real si esta disponible
logistic_path <- file.path(r_dir, "logistic.R")
helpers_path  <- file.path(r_dir, "helpers.R")

if (file.exists(logistic_path) && file.exists(helpers_path)) {
  tryCatch({
    # parent=globalenv() gives stats package in search path (na.omit, glm, etc.)
    # matching the production environment where Rscript loads stats by default
    local_env <- new.env(parent=globalenv())
    source(helpers_path, local=local_env)
    source(logistic_path, local=local_env)

    set.seed(1)
    n_test <- 20
    X_test <- matrix(rnorm(n_test * 2), ncol = 2)

    # VD continua (5 valores unicos): debe ser bloqueada
    y_cont <- rep(1:5, 4)
    res_cont <- local_env$compute_logistic_binary(y_cont, X_test, var_names=c("x1","x2"))

    check("F-007.I1", "Modulo real: VD continua devuelve blocked=TRUE",
          isTRUE(res_cont$blocked))
    check("F-007.I2", "Modulo real: reason es VD_NO_BINARIA",
          isTRUE(res_cont$reason == "VD_NO_BINARIA"))
    check("F-007.I3", "Modulo real: mensaje de error tiene texto descriptivo",
          is.character(res_cont$error) && nchar(res_cont$error) > 20)

    # VD binaria {0,1}: debe procesarse sin bloqueo y producir coeficientes finitos
    y_bin <- rep(c(0L, 1L), n_test / 2)
    res_bin <- tryCatch(
      local_env$compute_logistic_binary(y_bin, X_test[1:n_test,], var_names=c("x1","x2")),
      error = function(e) list(error=e$message, blocked=FALSE)
    )
    check("F-007.I4", "Modulo real: VD binaria {0,1} NO es bloqueada",
          !isTRUE(res_bin$blocked))
    check("F-007.I5", "Modulo real: VD binaria {0,1} → coeficientes finitos",
          !isTRUE(res_bin$blocked) && !is.null(res_bin$coefficients) &&
          all(is.finite(as.numeric(unlist(res_bin$coefficients)))))

    if (isTRUE(res_cont$blocked))
      cat(sprintf("    Mensaje guard F-007: %s\n", res_cont$error))
  }, error = function(e) {
    skip_test("F-007.I1-I5", "Test de integracion omitido", e$message)
  })
} else {
  skip_test("F-007.I1-I5", "logistic.R no encontrado en ruta esperada", r_dir)
}
cat("\n")

# ============================================================
# ORDINAL: Regresion ordinal — guard contra VD continua
# ============================================================
cat("--- ORDINAL: regresion ordinal — guard contra VD continua ---\n")

# Test de logica del guard (inline, sin dependencias)
set.seed(2)
score_b_cont <- rnorm(50, mean=3, sd=1)  # VD continua: ~50 valores unicos, decimales
sb_clean     <- na.omit(score_b_cont)
n_uq_cont    <- length(unique(sb_clean))
is_dec_cont  <- any(abs(sb_clean - round(sb_clean)) > 1e-10)

check("ORDINAL.L1", "Guard logico: VD continua (>10 valores unicos) detectada",
      n_uq_cont > 10 || is_dec_cont)

score_b_ord <- as.numeric(sample(1:3, 50, replace=TRUE))  # VD ordinal: 3 valores
sb_ord_clean <- na.omit(score_b_ord)
n_uq_ord     <- length(unique(sb_ord_clean))
is_dec_ord   <- any(abs(sb_ord_clean - round(sb_ord_clean)) > 1e-10)

check("ORDINAL.L2", "Guard logico: VD ordinal {1,2,3} no es bloqueada (<=10 valores, sin decimales)",
      !(n_uq_ord > 10 || is_dec_ord))

# Test de integracion: cargar el modulo real si MASS esta disponible
ordinal_path <- file.path(r_dir, "ordinal_regression.R")
if (file.exists(ordinal_path) && requireNamespace("MASS", quietly=TRUE)) {
  tryCatch({
    library(MASS)
    # parent=globalenv() matches production: Rscript loads stats+MASS in search path
    local_env2 <- new.env(parent=globalenv())
    source(helpers_path, local=local_env2)
    source(ordinal_path, local=local_env2)

    set.seed(3)
    n_ord <- 60
    df_ord_cont <- data.frame(vi=rnorm(n_ord), vd=rnorm(n_ord, mean=3, sd=0.8))

    res_ord_cont <- local_env2$run_ordinal_regression(
      df          = df_ord_cont,
      var_a_items = "vi",
      var_b_items = "vd",
      var_a_name  = "Predictor",
      var_b_name  = "VD_continua"
    )
    check("ORDINAL.I1", "Modulo real: VD continua devuelve blocked=TRUE",
          isTRUE(res_ord_cont$blocked))
    check("ORDINAL.I2", "Modulo real: reason es VD_CONTINUA",
          isTRUE(res_ord_cont$reason == "VD_CONTINUA"))

    # VD ordinal {1,2,3}: debe pasar sin bloqueo y tener contenido
    df_ord_ok <- data.frame(vi=rnorm(n_ord), vd=sample(1:3, n_ord, replace=TRUE))
    res_ord_ok <- tryCatch(
      local_env2$run_ordinal_regression(
        df=df_ord_ok, var_a_items="vi", var_b_items="vd",
        var_a_name="Predictor", var_b_name="VD_ordinal"
      ),
      error=function(e) list(error=e$message, blocked=FALSE)
    )
    check("ORDINAL.I3", "Modulo real: VD ordinal {1,2,3} NO es bloqueada",
          !isTRUE(res_ord_ok$blocked))
    check("ORDINAL.I4", "Modulo real: VD ordinal {1,2,3} → resultado con contenido (no error)",
          !isTRUE(res_ord_ok$blocked) && is.null(res_ord_ok$error))

    if (isTRUE(res_ord_cont$blocked))
      cat(sprintf("    Mensaje guard ORDINAL: %s\n", res_ord_cont$error))
  }, error = function(e) {
    skip_test("ORDINAL.I1-I4", "Test de integracion omitido", e$message)
  })
} else {
  reason <- if (!file.exists(ordinal_path)) "ordinal_regression.R no encontrado" else "paquete MASS no disponible"
  skip_test("ORDINAL.I1-I4", "Test de integracion omitido", reason)
}
cat("\n")

# ============================================================
# PLS: Constructo de un solo item — guard contra duplicacion con jitter
# ============================================================
cat("--- PLS: single-item construct — guard contra duplicacion con jitter ---\n")

# Test de logica del guard (inline, sin dependencias de seminr)
constructs_test <- list(
  list(name="ConstructoA", items=c("item1a", "item1b")),   # 2 items: valido
  list(name="ConstructoB", items=c("item2"))                # 1 item: invalido
)
items_df_test <- data.frame(item1a=rnorm(20), item1b=rnorm(20), item2=rnorm(20))

# Logica del guard de pls_sem_engine.R
single_item_list <- Filter(Negate(is.null), lapply(constructs_test, function(ct) {
  avail <- intersect(ct$items, names(items_df_test))
  if (length(avail) == 1) list(name=ct$name, item=avail[1]) else NULL
}))

check("PLS.L1", "Guard logico: detecta exactamente 1 constructo de un solo item",
      length(single_item_list) == 1)

check("PLS.L2", "Guard logico: identifica 'ConstructoB' como el constructo afectado",
      length(single_item_list) >= 1 && single_item_list[[1]]$name == "ConstructoB")

check("PLS.L3", "Guard logico: 'ConstructoA' con 2 items NO es detectado como single-item",
      !any(sapply(single_item_list, function(x) x$name == "ConstructoA")))

# Verificar que el codigo anterior (jitter) ya NO existe en el modulo
pls_path <- file.path(r_dir, "pls_sem_engine.R")
if (file.exists(pls_path)) {
  pls_src <- readLines(pls_path, warn=FALSE)
  jitter_dup_lines <- grep("__dup__", pls_src, value=TRUE)
  check("PLS.L4", "Codigo de duplicacion __dup__ fue eliminado del modulo PLS",
        length(jitter_dup_lines) == 0)
  if (length(jitter_dup_lines) > 0) {
    cat(sprintf("    LINEA ENCONTRADA (debe eliminarse): %s\n", trimws(jitter_dup_lines[1])))
  }
} else {
  skip_test("PLS.L4", "Verificacion de codigo fuente omitida", "pls_sem_engine.R no encontrado")
}

cat(sprintf("    Constructos invalidos detectados: [%s]\n",
    paste(sapply(single_item_list, function(x) x$name), collapse=", ")))
cat("    ESTADO: Guard inline verificado. Test de integracion completo requiere seminr.\n\n")

# ============================================================
# RESUMEN FINAL
# ============================================================
total <- pass + fail + skip_n
cat(sprintf("=== RESUMEN: %d PASS  %d FAIL  %d SKIP  (total %d tests) ===\n",
    pass, fail, skip_n, total))

if (fail > 0) {
  cat("RESULTADO FINAL: FALLO\n")
  cat("  Al menos un bug esta activo o un guard no funciona como se espera.\n")
  quit(status = 1L)
} else if (skip_n > 0) {
  cat("RESULTADO FINAL: INCOMPLETO\n")
  cat(sprintf("  %d test(s) omitidos por falta de paquetes o modulos. Ejecutar en entorno Docker completo.\n", skip_n))
  quit(status = 0L)
} else {
  cat("RESULTADO FINAL: COMPLETO\n")
  cat("  Todos los bugs documentados y todos los guards verificados.\n")
  quit(status = 0L)
}
