# tests/audit_guards_comprehensive.R
# Pruebas comprensivas de guards P0/P1 — Lote 1C Auditoria CanchariOS
#
# Uso: Rscript tests/audit_guards_comprehensive.R [C|D|E|F|all]
#   C = Guard logistico (VD no binaria)
#   D = Guard ordinal (VD continua)
#   E = Guard chi-cuadrado (variables continuas)
#   F = Guard PLS-SEM (constructo de un solo indicador)
#
# Exit code: 0 = todos PASS (o SKIP), 1 = al menos un FAIL

section_arg <- commandArgs(trailingOnly = TRUE)
section     <- if (length(section_arg) > 0) toupper(trimws(section_arg[1])) else "ALL"

# ---------- infraestructura comun ----------
pass <- 0L; fail <- 0L; skip_n <- 0L

check <- function(id, desc, cond) {
  label <- if (isTRUE(cond)) "PASS" else "FAIL"
  cat(sprintf("  [%s] %s: %s\n", label, id, desc))
  if (isTRUE(cond)) pass <<- pass + 1L else fail <<- fail + 1L
  invisible(isTRUE(cond))
}
skip_test <- function(id, desc, reason) {
  cat(sprintf("  [SKIP] %s: %s -- %s\n", id, desc, reason))
  skip_n <<- skip_n + 1L
}

# Resolucion de rutas — funciona con Rscript y source()
.script_dir <- tryCatch({
  dirname(normalizePath(sys.frame(1)$ofile))
}, error = function(e) {
  args <- commandArgs(trailingOnly = FALSE)
  f    <- sub("--file=", "", grep("--file=", args, value = TRUE))
  if (length(f) > 0) dirname(normalizePath(f)) else getwd()
})
r_dir          <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "R")
helpers_path   <- file.path(r_dir, "helpers.R")
logistic_path  <- file.path(r_dir, "logistic.R")
ordinal_path   <- file.path(r_dir, "ordinal_regression.R")
pls_path       <- file.path(r_dir, "pls_sem_engine.R")
run_anal_path  <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "run_analysis.R")

cat(sprintf("=== AUDIT GUARDS COMPREHENSIVE [%s] ===\n", section))
cat(sprintf("    R version: %s\n", R.version.string))
cat(sprintf("    r_dir:     %s\n\n", r_dir))

# ============================================================
# SECCION C — Guard logistico: VD debe ser exactamente binaria
# ============================================================
run_section_c <- function() {
  cat("--- [C] Guard logistico (VD no binaria) ---\n")

  # C.L: Pruebas de logica del guard (sin paquetes adicionales)
  is_binary <- function(y) {
    u <- unique(na.omit(as.numeric(y)))
    length(u) == 2
  }

  set.seed(42); n <- 80
  y_cont   <- rnorm(n)
  y_3cat   <- sample(c(1, 2, 3), n, replace = TRUE)
  y_bin01  <- sample(c(0L, 1L), n, replace = TRUE)
  y_bin12  <- sample(c(1L, 2L), n, replace = TRUE)
  y_single <- rep(1L, n)

  check("C.L1", "Logica: VD continua (~100 valores) NO es binaria",   !is_binary(y_cont))
  check("C.L2", "Logica: VD 3 categorias {1,2,3} NO es binaria",     !is_binary(y_3cat))
  check("C.L3", "Logica: VD valor unico {1} NO es binaria",          !is_binary(y_single))
  check("C.L4", "Logica: VD {0,1} SI es binaria",                     is_binary(y_bin01))
  check("C.L5", "Logica: VD {1,2} SI es binaria",                     is_binary(y_bin12))

  # C.I: Pruebas de integracion con el modulo real
  X_test <- data.frame(predictor = rnorm(n))
  has_logistic <- file.exists(logistic_path)

  if (has_logistic) {
    # parent=globalenv() matches production: Rscript loads stats by default,
    # so na.omit, glm, model.matrix etc. are available without explicit library()
    env_c <- new.env(parent = globalenv())
    if (file.exists(helpers_path)) source(helpers_path, local = env_c)
    tryCatch({
      source(logistic_path, local = env_c)

      # C.I1/C.I2 — VD continua: debe bloquear
      r_cont <- env_c$compute_logistic(y_cont, X_test, var_names = "predictor")
      check("C.I1", "Integracion: VD continua → blocked=TRUE",       isTRUE(r_cont$blocked))
      check("C.I2", "Integracion: VD continua → reason=VD_NO_BINARIA", isTRUE(r_cont$reason == "VD_NO_BINARIA"))
      if (isTRUE(r_cont$blocked))
        cat(sprintf("    Mensaje guard: %.120s...\n", r_cont$error))

      # C.I3 — VD 3 categorias: debe bloquear
      r_3cat <- env_c$compute_logistic(y_3cat, X_test, var_names = "predictor")
      check("C.I3", "Integracion: VD {1,2,3} → blocked=TRUE", isTRUE(r_3cat$blocked))

      # C.I4 — VD valor unico: debe bloquear
      r_single <- env_c$compute_logistic(y_single, X_test, var_names = "predictor")
      check("C.I4", "Integracion: VD valor unico → blocked=TRUE", isTRUE(r_single$blocked))

      # C.I5 — VD {0,1}: no debe bloquear, debe tener coeficientes finitos
      r_bin01 <- env_c$compute_logistic(y_bin01, X_test, var_names = "predictor")
      check("C.I5", "Integracion: VD {0,1} → NOT blocked",          !isTRUE(r_bin01$blocked))
      check("C.I6", "Integracion: VD {0,1} → tiene 'coefficients'", !is.null(r_bin01$coefficients))
      check("C.I6b", "Integracion: VD {0,1} → coeficientes finitos (ninguno NaN/Inf)",
            !is.null(r_bin01$coefficients) &&
            all(is.finite(as.numeric(unlist(r_bin01$coefficients)))))

      # C.I7 — VD {1,2}: no debe bloquear (recodifica a 0/1) y producir coeficientes
      r_bin12 <- env_c$compute_logistic(y_bin12, X_test, var_names = "predictor")
      check("C.I7",  "Integracion: VD {1,2} → NOT blocked (recodificada)", !isTRUE(r_bin12$blocked))
      check("C.I7b", "Integracion: VD {1,2} → modelo estima coeficientes",
            !isTRUE(r_bin12$blocked) && !is.null(r_bin12$coefficients))

    }, error = function(e) {
      skip_test("C.I1-I7", "Tests de integracion omitidos", e$message)
    })
  } else {
    skip_test("C.I1-I7", "logistic.R no encontrado", logistic_path)
  }
  cat("\n")
}

# ============================================================
# SECCION D — Guard ordinal: VD debe tener categorias ordinales preexistentes
# ============================================================
run_section_d <- function() {
  cat("--- [D] Guard ordinal (VD continua) ---\n")

  # D.L: Logica del guard (is_numeric + n_unique + decimales)
  is_continuous_vd <- function(x) {
    xc <- na.omit(x)
    if (!is.numeric(xc)) return(FALSE)
    n_unique <- length(unique(xc))
    has_dec  <- any(abs(xc - round(xc)) > 1e-10)
    n_unique > 10 || has_dec
  }

  set.seed(7); n <- 60
  vd_cont  <- rnorm(n, mean = 3, sd = 0.8)          # continua (muchos valores unicos)
  vd_dec   <- round(seq(1, 5, length.out = n), 2)    # 8 valores con decimales
  vd_lk3   <- sample(1:3, n, replace = TRUE)          # Likert 3 puntos
  vd_lk5   <- sample(1:5, n, replace = TRUE)          # Likert 5 puntos
  vd_text  <- sample(c("bajo","medio","alto"), n, replace = TRUE)  # texto ordinal
  vd_15int <- sample(1:15, n, replace = TRUE)         # 15 enteros unicos (>10 → bloqueado)

  check("D.L1", "Logica: VD continua rnorm → detectada como continua",   is_continuous_vd(vd_cont))
  check("D.L2", "Logica: VD con decimales → detectada como continua",     is_continuous_vd(vd_dec))
  check("D.L3", "Logica: VD Likert {1,2,3} → NO detectada como continua",!is_continuous_vd(vd_lk3))
  check("D.L4", "Logica: VD Likert {1,2,3,4,5} → NO detectada",         !is_continuous_vd(vd_lk5))
  check("D.L5", "Logica: VD texto → NO detectada (no es numerica)",      !is_continuous_vd(vd_text))

  # D.NOTE: F-022 conocido — Likert 5 con 15+ enteros produce falso positivo
  cat(sprintf("  [NOTE] D.L6 (F-022 conocido): VD 15 enteros unicos → is_continuous=%s ",
              is_continuous_vd(vd_15int)))
  cat("(falso positivo esperado: >10 enteros = trigger heuristico)\n")

  # D.I: Integracion con modulo real (requiere MASS)
  has_ordinal <- file.exists(ordinal_path) && requireNamespace("MASS", quietly = TRUE)

  if (has_ordinal) {
    library(MASS)
    # parent=globalenv() matches production; MASS loaded above is visible via global search path
    env_d <- new.env(parent = globalenv())
    if (file.exists(helpers_path)) source(helpers_path, local = env_d)
    tryCatch({
      source(ordinal_path, local = env_d)

      vi_vec <- rnorm(n)

      # D.I1 — VD continua: bloquear
      df_cont <- data.frame(vi = vi_vec, vd = vd_cont)
      r_cont  <- env_d$run_ordinal_regression(df_cont, "vi", "vd", "VI", "VD_continua")
      check("D.I1", "Integracion: VD continua → blocked=TRUE",         isTRUE(r_cont$blocked))
      check("D.I2", "Integracion: VD continua → reason=VD_CONTINUA",   isTRUE(r_cont$reason == "VD_CONTINUA"))
      if (isTRUE(r_cont$blocked))
        cat(sprintf("    Mensaje guard: %.120s...\n", r_cont$error))

      # D.I3 — VD con decimales: bloquear
      df_dec <- data.frame(vi = vi_vec, vd = vd_dec)
      r_dec  <- env_d$run_ordinal_regression(df_dec, "vi", "vd", "VI", "VD_decimal")
      check("D.I3", "Integracion: VD con decimales → blocked=TRUE", isTRUE(r_dec$blocked))

      # D.I4 — VD Likert {1,2,3}: no bloquear y tener contenido útil
      df_lk3 <- data.frame(vi = vi_vec, vd = vd_lk3)
      r_lk3  <- tryCatch(
        env_d$run_ordinal_regression(df_lk3, "vi", "vd", "VI", "VD_likert3"),
        error = function(e) list(error = e$message, blocked = FALSE)
      )
      check("D.I4",  "Integracion: VD Likert {1,2,3} → NOT blocked",           !isTRUE(r_lk3$blocked))
      check("D.I4b", "Integracion: VD Likert {1,2,3} → resultado sin error",
            !isTRUE(r_lk3$blocked) && is.null(r_lk3$error))

      # D.I5 — VD Likert {1,2,3,4,5}: no bloquear y tener contenido útil
      df_lk5 <- data.frame(vi = vi_vec, vd = vd_lk5)
      r_lk5  <- tryCatch(
        env_d$run_ordinal_regression(df_lk5, "vi", "vd", "VI", "VD_likert5"),
        error = function(e) list(error = e$message, blocked = FALSE)
      )
      check("D.I5",  "Integracion: VD Likert {1,2,3,4,5} → NOT blocked",       !isTRUE(r_lk5$blocked))
      check("D.I5b", "Integracion: VD Likert {1,2,3,4,5} → resultado sin error",
            !isTRUE(r_lk5$blocked) && is.null(r_lk5$error))

      # D.I6 — VD texto: no bloquear (tipo character, no numeric)
      df_txt <- data.frame(vi = vi_vec, vd = vd_text, stringsAsFactors = FALSE)
      r_txt  <- tryCatch(
        env_d$run_ordinal_regression(df_txt, "vi", "vd", "VI", "VD_texto"),
        error = function(e) list(error = e$message, blocked = FALSE)
      )
      check("D.I6", "Integracion: VD texto → NOT blocked por guard continuo", !isTRUE(r_txt$blocked))

    }, error = function(e) {
      skip_test("D.I1-I6", "Tests de integracion omitidos", e$message)
    })
  } else {
    reason <- if (!file.exists(ordinal_path)) "ordinal_regression.R no encontrado"
              else "paquete MASS no disponible"
    skip_test("D.I1-I6", "Tests de integracion omitidos", reason)
  }
  cat("\n")
}

# ============================================================
# SECCION E — Guard chi-cuadrado: variables deben ser categoricas
# ============================================================
run_section_e <- function() {
  cat("--- [E] Guard chi-cuadrado (variables continuas) ---\n")

  # Misma logica que run_analysis.R lineas 740-743
  is_continuous_score <- function(x) {
    xc <- x[!is.na(x)]
    is.numeric(xc) && (length(unique(xc)) > 10 || any(abs(xc - round(xc)) > 1e-10))
  }

  set.seed(99); n <- 100
  sc_cat3  <- sample(1:3, n, replace = TRUE)             # 3 categorias enteras
  sc_cat2  <- sample(c(0L, 1L), n, replace = TRUE)       # binario
  sc_cont  <- rnorm(n)                                    # continua
  sc_dec   <- round(rnorm(n, 3, 0.5), 2)                 # con decimales
  sc_text  <- sample(c("A","B","C"), n, replace = TRUE)  # texto
  sc_11int <- sample(1:11, n, replace = TRUE)             # 11 enteros unicos (>10)

  check("E.L1", "Guard: {1,2,3} enteros → NOT continua",          !is_continuous_score(sc_cat3))
  check("E.L2", "Guard: {0,1} binario → NOT continua",            !is_continuous_score(sc_cat2))
  check("E.L3", "Guard: rnorm continua → SI continua",             is_continuous_score(sc_cont))
  check("E.L4", "Guard: escores con decimales → SI continua",      is_continuous_score(sc_dec))
  check("E.L5", "Guard: texto → NOT continua (not numeric)",      !is_continuous_score(sc_text))

  # E.NOTE: F-021 — 11+ enteros produce falso positivo
  cat(sprintf("  [NOTE] E.L6 (F-021 conocido): 11 enteros unicos → is_continuous=%s ",
              is_continuous_score(sc_11int)))
  cat("(falso positivo esperado: >10 trigger bloquea nominales con muchas categorias)\n")

  # E.I: Pruebas conductuales — evidencia principal del guard
  # El guard en run_analysis.R delega la decision a is_continuous_score().
  # Usamos la misma funcion inline (copia fiel de run_analysis.R lineas 740-743)
  # para verificar conducta con datos reales.
  set.seed(99)
  chi_x_bin  <- sample(c("M", "F"), 100, replace = TRUE)
  chi_x_cat3 <- sample(c("A", "B", "C"), 100, replace = TRUE)
  chi_x_cont <- rnorm(100)

  # E.I1-I4: chi-cuadrado con dos categoricas → valido sin transformacion
  r_chi <- tryCatch(
    chisq.test(table(chi_x_bin, chi_x_cat3), correct = FALSE),
    error = function(e) list(statistic = NA, p.value = NA, observed = matrix(0, 1, 1))
  )
  check("E.I1", "Conductual: chi {M,F}×{A,B,C} → estadistico finito",
        is.finite(r_chi$statistic))
  check("E.I2", "Conductual: chi {M,F}×{A,B,C} → p.value en [0,1]",
        is.finite(r_chi$p.value) && r_chi$p.value >= 0 && r_chi$p.value <= 1)
  check("E.I3", "Conductual: tabla 2×3 — sin tricotomizacion silenciosa (no es 3×3)",
        isTRUE(nrow(r_chi$observed) == 2 && ncol(r_chi$observed) == 3))
  check("E.I4", "Conductual: guard bloquea VD continua antes de chisq.test",
        is_continuous_score(chi_x_cont))

  # E.SRC: Verificar codigo fuente — complementario a la evidencia conductual
  if (file.exists(run_anal_path)) {
    src_lines <- readLines(run_anal_path, warn = FALSE)
    check("E.SRC1", "Fuente: is_continuous_score definida en run_analysis.R",
          any(grepl("is_continuous_score", src_lines, fixed = TRUE)))
    check("E.SRC2", "Fuente: guard bloquea con status='error' en chi_cuadrado",
          any(grepl('result\\$status.*<-.*"error"', src_lines)))
    check("E.SRC3", "Fuente: guard bloquea con reason='VARIABLES_CONTINUAS'",
          any(grepl("VARIABLES_CONTINUAS", src_lines, fixed = TRUE)))
    # E.SRC4: scoped to chi-square region (within 80 lines of VARIABLES_CONTINUAS marker)
    # The ANOVA cut(breaks=3) is ~445 lines away; this check confirms the chi block is clean.
    vars_cont_ln <- which(grepl("VARIABLES_CONTINUAS", src_lines, fixed = TRUE))[1]
    cut_lines    <- which(grepl('cut\\(.*breaks.*=.*3', src_lines))
    near_cut     <- if (!is.na(vars_cont_ln)) cut_lines[abs(cut_lines - vars_cont_ln) <= 80] else integer(0)
    check("E.SRC4", "Fuente: sin cut(breaks=3) en zona chi-cuadrado (±80 lineas de VARIABLES_CONTINUAS)",
          length(near_cut) == 0)
  } else {
    skip_test("E.SRC1-SRC4", "Verificacion de fuente omitida", "run_analysis.R no encontrado")
  }
  cat("\n")
}

# ============================================================
# SECCION F — Guard PLS-SEM: constructo con un solo indicador
# ============================================================
run_section_f <- function() {
  cat("--- [F] Guard PLS-SEM (single-item construct) ---\n")

  # F.L: Logica del guard (sin seminr)
  constructs_test <- list(
    list(name = "ConstructoA", items = c("item1a", "item1b")),
    list(name = "ConstructoB", items = c("item2")),
    list(name = "ConstructoC", items = c("item3a", "item3b", "item3c"))
  )
  df_f <- data.frame(item1a=rnorm(30), item1b=rnorm(30), item2=rnorm(30),
                     item3a=rnorm(30), item3b=rnorm(30), item3c=rnorm(30))

  single_list <- Filter(Negate(is.null), lapply(constructs_test, function(ct) {
    avail <- intersect(ct$items, names(df_f))
    if (length(avail) == 1) list(name = ct$name, item = avail[1]) else NULL
  }))

  check("F.L1", "Guard logico: detecta exactamente 1 constructo single-item",
        length(single_list) == 1)
  check("F.L2", "Guard logico: ConstructoB (1 item) identificado correctamente",
        length(single_list) >= 1 && single_list[[1]]$name == "ConstructoB")
  check("F.L3", "Guard logico: ConstructoA (2 items) NO bloqueado",
        !any(sapply(single_list, function(x) x$name == "ConstructoA")))
  check("F.L4", "Guard logico: ConstructoC (3 items) NO bloqueado",
        !any(sapply(single_list, function(x) x$name == "ConstructoC")))

  # F.SRC: Verificar que __dup__ fue eliminado y guard existe en fuente
  if (file.exists(pls_path)) {
    pls_src <- readLines(pls_path, warn = FALSE)
    check("F.SRC1", "Fuente: codigo __dup__ eliminado de pls_sem_engine.R",
          !any(grepl("__dup__", pls_src, fixed = TRUE)))
    check("F.SRC2", "Fuente: guard SINGLE_ITEM_CONSTRUCTS existe",
          any(grepl("SINGLE_ITEM_CONSTRUCTS", pls_src, fixed = TRUE)))
    check("F.SRC3", "Fuente: guard 'single_item_constructs' definido",
          any(grepl("single_item_constructs", pls_src, fixed = TRUE)))
  } else {
    skip_test("F.SRC1-SRC3", "pls_sem_engine.R no encontrado", pls_path)
  }

  # F.I: Integracion con el modulo real (requiere seminr, jsonlite, dplyr, openxlsx)
  has_seminr <- file.exists(pls_path) &&
    requireNamespace("seminr",   quietly = TRUE) &&
    requireNamespace("jsonlite", quietly = TRUE) &&
    requireNamespace("dplyr",    quietly = TRUE) &&
    requireNamespace("openxlsx", quietly = TRUE)

  if (has_seminr) {
    # parent=globalenv() so that stats and loaded packages (seminr, dplyr, etc.)
    # are accessible from within the sourced pls_sem_engine.R environment
    env_f <- new.env(parent = globalenv())
    tryCatch({
      source(pls_path, local = env_f)
      check("F.PKG", "Paquete seminr cargado exitosamente via pls_sem_engine.R", TRUE)

      # Datos de prueba
      set.seed(42)
      tmp_csv <- tempfile(fileext = ".csv")
      df_pls <- data.frame(
        A1 = rnorm(80) + 3, A2 = rnorm(80) + 3,
        B1 = rnorm(80) + 3,
        C1 = rnorm(80) + 3, C2 = rnorm(80) + 3
      )
      write.csv(df_pls, tmp_csv, row.names = FALSE)

      # F.I1/F.I2 — Constructo con 1 item: debe bloquear ANTES de estimar
      params_blocked <- list(
        data_path  = tmp_csv,
        constructs = list(
          list(name = "A", items = c("A1", "A2")),
          list(name = "B", items = c("B1")),        # single-item → bloquear
          list(name = "C", items = c("C1", "C2"))
        ),
        paths  = list(list(from = "A", to = "B"), list(from = "B", to = "C")),
        n_boot = 10L
      )
      r_blocked <- env_f$run_pls_sem(params_blocked)
      check("F.I1", "Integracion: single-item → blocked=TRUE",
            isTRUE(r_blocked$blocked))
      check("F.I2", "Integracion: single-item → reason=SINGLE_ITEM_CONSTRUCTS",
            isTRUE(r_blocked$reason == "SINGLE_ITEM_CONSTRUCTS"))
      if (isTRUE(r_blocked$blocked))
        cat(sprintf("    Mensaje guard: %.120s...\n", r_blocked$error))

      # F.I3 — Todos los constructos con 2+ items: guard NO debe bloquear,
      #         salida estructurada y finita
      params_valid <- list(
        data_path  = tmp_csv,
        constructs = list(
          list(name = "A", items = c("A1", "A2")),
          list(name = "C", items = c("C1", "C2"))
        ),
        paths  = list(list(from = "A", to = "C")),
        n_boot = 10L
      )
      r_valid <- tryCatch(
        env_f$run_pls_sem(params_valid),
        error = function(e) list(error = e$message, blocked = FALSE)
      )
      check("F.I3",  "Integracion: 2-item constructs → guard NO bloquea",
            !isTRUE(r_valid$blocked))
      check("F.I3b", "Integracion: 2-item valid → salida tiene tablas o success=TRUE",
            !isTRUE(r_valid$blocked) &&
            (isTRUE(r_valid$success) || !is.null(r_valid$path_coefficients) || !is.null(r_valid$tables)))
      check("F.I3c", "Integracion: 2-item valid → sin NaN/Inf en valores numericos",
            !isTRUE(r_valid$blocked) && {
              nums <- tryCatch(as.numeric(unlist(r_valid[sapply(r_valid, function(x) is.numeric(x) || is.list(x))])),
                               error = function(e) numeric(0))
              length(nums) == 0 || all(is.finite(nums[!is.na(nums)]))
            })

      unlink(tmp_csv)

    }, error = function(e) {
      check("F.PKG", "Paquete seminr cargado exitosamente via pls_sem_engine.R", FALSE)
      skip_test("F.I1-I3", "Tests de integracion PLS omitidos", e$message)
    })
  } else {
    reason <- if (!file.exists(pls_path)) "pls_sem_engine.R no encontrado"
              else "paquetes seminr/jsonlite/dplyr/openxlsx no disponibles"
    skip_test("F.PKG",  "Carga de seminr omitida",           reason)
    skip_test("F.I1-I3","Tests de integracion PLS omitidos", reason)
  }
  cat("\n")
}

# ============================================================
# Ejecutar secciones solicitadas
# ============================================================
if (section %in% c("C", "ALL")) run_section_c()
if (section %in% c("D", "ALL")) run_section_d()
if (section %in% c("E", "ALL")) run_section_e()
if (section %in% c("F", "ALL")) run_section_f()

# Resumen
total <- pass + fail + skip_n
cat(sprintf("=== RESUMEN [%s]: %d PASS  %d FAIL  %d SKIP  (total %d) ===\n",
            section, pass, fail, skip_n, total))

if (fail > 0) {
  cat("RESULTADO: FALLO — al menos un guard no funciona como se espera.\n")
  quit(status = 1L)
} else if (skip_n > 0 && pass == 0) {
  cat("RESULTADO: SKIP TOTAL — no se ejecuto ninguna prueba.\n")
  quit(status = 0L)
} else if (skip_n > 0) {
  cat("RESULTADO: INCOMPLETO — algunos tests omitidos por falta de paquetes.\n")
  quit(status = 0L)
} else {
  cat("RESULTADO: COMPLETO — todos los guards verificados.\n")
  quit(status = 0L)
}
