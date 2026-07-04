source("apps/api/stats-engine-r/R/helpers.R")
source("apps/api/stats-engine-r/R/statistics.R")

probar_error <- function(x, y, nombre) {
  error_capturado <- tryCatch(
    {
      correlate_pair(
        x,
        y,
        method = "pearson",
        alpha = 0.05,
        hypothesis_type = "bilateral"
      )
      NULL
    },
    error = function(e) e
  )

  cat("\n=== ", nombre, " ===\n", sep = "")

  if (is.null(error_capturado)) {
    cat("Resultado: la app NO bloqueó el análisis inválido.\n")
  } else {
    cat("Error correctamente capturado:", error_capturado$message, "\n")
  }

  stopifnot(inherits(error_capturado, "error"))
}

# Caso 1: Pearson no está definido cuando una variable no tiene varianza.
probar_error(
  rep(5, 30),
  1:30,
  "VARIABLE CONSTANTE"
)

# Caso 2: menos de tres pares válidos no permiten una correlación inferencial.
probar_error(
  c(1, 2),
  c(2, 4),
  "MUESTRA INSUFICIENTE"
)

cat("\nPASS: los insumos degenerados son bloqueados explícitamente.\n")
