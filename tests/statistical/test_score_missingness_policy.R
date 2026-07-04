source("apps/api/stats-engine-r/R/data_cleaning.R")

items <- paste0("I", 1:12)

datos <- as.data.frame(matrix(3, nrow = 3, ncol = 12))
names(datos) <- items

# Caso 1: 12/12 respuestas válidas.
# Caso 2: 10/12 respuestas válidas.
# Caso 3: solo 1/12 respuestas válidas.
datos[2, 11:12] <- NA
datos[3, 2:12] <- NA

config <- list(
  var_a = list(
    name = "Escala",
    items = items,
    dimensions = list()
  ),
  var_b = list(
    name = "",
    items = list(),
    dimensions = list()
  )
)

resultado <- compute_scores(datos, config)
puntajes <- resultado$scores$Escala

cat("=== POLÍTICA DE RESPUESTAS MÍNIMAS POR ESCALA ===\n")
cat("Caso 12/12 válidos:", puntajes[1], "\n")
cat("Caso 10/12 válidos:", puntajes[2], "\n")
cat("Caso  1/12 válido: ", puntajes[3], "\n")

stopifnot(is.finite(puntajes[1]))
stopifnot(is.finite(puntajes[2]))

# Política mínima exigida: una escala no puede calcularse con solo
# una respuesta válida de doce ítems.
stopifnot(is.na(puntajes[3]))

cat("PASS: los puntajes incompletos extremos no son tratados como válidos.\n")
