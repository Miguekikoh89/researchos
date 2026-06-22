# ============================================================================
# ResearchOS Stats Engine — data_cleaning.R
# Carga, limpieza e imputación de datos Excel/CSV
# Extraído y refactorizado desde CorrelaStat Pro v4.0
# ============================================================================

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
})

#' Cargar archivo Excel o CSV
#'
#' @param filepath Ruta al archivo
#' @param sheet    Número de hoja (para Excel)
#' @param header   Si la primera fila es encabezado
#' @return data.frame o error
load_file <- function(filepath, sheet = 1, header = TRUE) {
  ext <- tolower(tools::file_ext(filepath))

  if (!(ext %in% c("xlsx", "xls", "csv"))) {
    stop(paste0("Tipo de archivo no soportado: .", ext,
                ". Use .xlsx, .xls o .csv"))
  }

  if (!file.exists(filepath)) {
    stop("El archivo no existe en la ruta especificada.")
  }

  file_size_mb <- file.info(filepath)$size / (1024 * 1024)
  if (file_size_mb > 50) {
    stop("El archivo supera el límite de 50 MB.")
  }

  df <- tryCatch({
    if (ext %in% c("xlsx", "xls")) {
      as.data.frame(
        read_excel(filepath, sheet = sheet, col_names = header),
        stringsAsFactors = FALSE
      )
    } else {
      read.csv(filepath, header = header,
               stringsAsFactors = FALSE, encoding = "UTF-8",
               na.strings = c("", "NA", "N/A", "#N/A", "null", "NULL"))
    }
  }, error = function(e) {
    stop(paste0("Error al leer el archivo: ", e$message))
  })

  df
}

#' Limpiar base de datos de forma robusta
#'
#' Elimina filas/columnas vacías, sanitiza nombres,
#' convierte valores Likert texto a número
#'
#' @param df data.frame a limpiar
#' @return data.frame limpio
clean_data <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)

  # Eliminar columnas completamente vacías
  df <- df[, !sapply(df, function(x)
    all(is.na(x) | trimws(as.character(x)) == "")), drop = FALSE]

  # Eliminar filas completamente vacías
  df <- df[!apply(df, 1, function(z)
    all(is.na(z) | trimws(as.character(z)) == "")), , drop = FALSE]

  if (ncol(df) == 0 || nrow(df) == 0) {
    stop("El archivo no contiene datos válidos después de la limpieza.")
  }

  # Sanitizar nombres de columnas (sin caracteres peligrosos)
  nombres_limpios <- names(df)
  nombres_limpios <- trimws(nombres_limpios)
  nombres_limpios <- gsub("[^a-zA-Z0-9_áéíóúÁÉÍÓÚñÑüÜ\\s\\-\\.()]", "", nombres_limpios)
  nombres_limpios <- make.unique(nombres_limpios, sep = "_")
  names(df) <- nombres_limpios

  # Convertir columnas tipo Likert texto → número
  convertir_col <- function(x) {
    if (is.numeric(x)) return(x)
    if (is.factor(x)) x <- as.character(x)
    if (!is.character(x)) return(x)
    z <- trimws(gsub(",", ".", x))
    z[z == ""] <- NA
    # Intento directo
    num <- suppressWarnings(as.numeric(z))
    if (mean(!is.na(num[!is.na(z)])) >= 0.70) return(num)
    # Intento extrayendo primer número
    z2  <- sub("^\\s*([0-9]+(?:\\.[0-9]+)?).*$", "\\1", z)
    num2 <- suppressWarnings(as.numeric(z2))
    if (mean(!is.na(num2[!is.na(z)])) >= 0.70) return(num2)
    x  # devolver original si no se pudo convertir
  }
  df[] <- lapply(df, convertir_col)

  df
}

#' Imputar valores perdidos
#'
#' @param df  data.frame
#' @param met "media" o "mediana"
#' @return data.frame con NA imputados en columnas numéricas
impute_data <- function(df, method = "media") {
  for (v in names(df)) {
    if (is.numeric(df[[v]]) && any(is.na(df[[v]]))) {
      val <- if (method == "media")
        mean(df[[v]], na.rm = TRUE)
      else
        median(df[[v]], na.rm = TRUE)
      df[[v]][is.na(df[[v]])] <- round(val, 3)
    }
  }
  df
}

#' Detectar outliers mediante criterio IQR × 1.5
#'
#' @param x vector numérico
#' @return índices de outliers
detect_outliers <- function(x) {
  q  <- quantile(x, c(0.25, 0.75), na.rm = TRUE)
  iq <- q[2] - q[1]
  which(x < q[1] - 1.5 * iq | x > q[2] + 1.5 * iq)
}

#' Diagnóstico completo del dataset
#'
#' @param df data.frame limpio
#' @return lista con metadatos y alertas
diagnose_data <- function(df) {
  n_rows <- nrow(df)
  n_cols <- ncol(df)
  numeric_cols <- names(df)[sapply(df, is.numeric)]
  text_cols    <- names(df)[sapply(df, function(x) is.character(x) || is.factor(x))]

  total_cells  <- n_rows * n_cols
  missing_cells <- sum(is.na(df))
  missing_pct  <- round(missing_cells / total_cells * 100, 1)

  # Outliers por columna numérica
  outlier_report <- lapply(numeric_cols, function(v) {
    outs <- detect_outliers(df[[v]][!is.na(df[[v]])])
    list(column = v, count = length(outs))
  })
  outlier_report <- Filter(function(x) x$count > 0, outlier_report)

  # Diagnóstico por columna
  col_diagnose <- lapply(names(df), function(v) {
    x    <- df[[v]]
    nas  <- sum(is.na(x))
    uniq <- length(unique(x[!is.na(x)]))
    type <- if (is.numeric(x)) "numeric" else "text"
    apt  <- is.numeric(x) && nas / length(x) < 0.20 && uniq > 1
    list(
      name    = v,
      type    = type,
      missing = nas,
      unique  = uniq,
      apt     = apt,
      min     = if (is.numeric(x)) min(x, na.rm = TRUE) else NA,
      max     = if (is.numeric(x)) max(x, na.rm = TRUE) else NA
    )
  })

  # Alertas
  warnings <- character(0)
  if (n_rows < 30)  warnings <- c(warnings, "n < 30: muestra muy pequeña para análisis correlacional.")
  if (n_rows < 100) warnings <- c(warnings, "n < 100: se recomienda Spearman por precaución.")
  if (missing_pct > 10) warnings <- c(warnings,
    paste0(missing_pct, "% de datos perdidos. Considere imputar antes del análisis."))
  if (length(outlier_report) > 0) warnings <- c(warnings,
    paste0("Outliers detectados en ", length(outlier_report), " variable(s)."))

  list(
    n_rows        = n_rows,
    n_cols        = n_cols,
    numeric_cols  = numeric_cols,
    text_cols     = text_cols,
    missing_pct   = missing_pct,
    outliers      = outlier_report,
    col_diagnose  = col_diagnose,
    warnings      = warnings
  )
}

#' Calcular puntajes por variable y dimensiones
#'
#' @param df      data.frame de datos crudos
#' @param config  lista con estructura de variables/dimensiones
#' @return data.frame de puntajes
compute_scores <- function(df, config) {
  # config estructura:
  # list(
  #   var_a = list(name="Variable A", items=c("P1","P2","P3"),
  #               dimensions=list(
  #                 list(name="Dim1", items=c("P1","P2")),
  #                 list(name="Dim2", items=c("P3"))
  #               )),
  #   var_b = list(name="Variable B", items=c("P4","P5","P6"), dimensions=list())
  # )

  pts <- data.frame(row.names = seq_len(nrow(df)))
  items_map <- list()  # mapa nombre → ítems, para Cronbach

  # Helper calcular promedio
  add_score <- function(name, items) {
    cols_valid <- intersect(as.character(unlist(items)), names(df))
    if (length(cols_valid) == 0) {
      warning(paste0("No se encontraron ítems válidos para: ", name))
      return(NULL)
    }
    # Solo columnas numéricas
    cols_num <- cols_valid[sapply(df[, cols_valid, drop = FALSE], is.numeric)]
    if (length(cols_num) == 0) return(NULL)
    pts[[name]] <<- rowMeans(df[, cols_num, drop = FALSE], na.rm = TRUE)
    items_map[[name]] <<- cols_num
  }

  # Variable A principal
  if (!is.null(config$var_a) && length(config$var_a$items) > 0) {
    add_score(if(is.null(config$var_a$name)||config$var_a$name=="") "Variable A" else config$var_a$name, config$var_a$items)
    # Dimensiones de A
    for (dim in config$var_a$dimensions) {
      if (!is.null(dim$name) && length(dim$items) > 0)
        add_score(dim$name, dim$items)
    }
  }

  # Variable B principal
  if (!is.null(config$var_b) && length(config$var_b$items) > 0) {
    add_score(if(is.null(config$var_b$name)||config$var_b$name=="") "Variable B" else config$var_b$name, config$var_b$items)
    # Dimensiones de B
    for (dim in config$var_b$dimensions) {
      if (!is.null(dim$name) && length(dim$items) > 0)
        add_score(dim$name, dim$items)
    }
  }

  list(scores = pts, items_map = items_map)
}
