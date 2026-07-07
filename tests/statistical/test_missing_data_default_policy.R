source("apps/api/stats-engine-r/R/data_cleaning.R")

# Relación perfecta en los ocho pares realmente observados.
datos <- data.frame(
  x = 1:10,
  y = c(1:8, NA, NA)
)

validos <- complete.cases(datos$x, datos$y)

r_complete_cases <- cor(
  datos$x[validos],
  datos$y[validos],
  method = "pearson"
)

datos_imputados <- impute_data(datos, method = "media")

r_mean_imputation <- cor(
  datos_imputados$x,
  datos_imputados$y,
  method = "pearson"
)

frontend <- paste(
  readLines(
    "apps/web/src/components/wizard/StepRun.tsx",
    warn = FALSE,
    encoding = "UTF-8"
  ),
  collapse = "\n"
)

media_hardcoded <- grepl(
  "imputation:[[:space:]]*'media'",
  frontend
)

cat("=== POLÍTICA PREDETERMINADA DE DATOS FALTANTES ===\n")
cat(sprintf("r con casos completos:       %.12f\n", r_complete_cases))
cat(sprintf("r con imputación por media:  %.12f\n", r_mean_imputation))
cat(sprintf("Diferencia absoluta:         %.12f\n",
            abs(r_complete_cases - r_mean_imputation)))
cat("Media fijada en frontend:    ", media_hardcoded, "\n", sep = "")

stopifnot(r_complete_cases == 1)
stopifnot(abs(r_complete_cases - r_mean_imputation) > 0.05)

# Política exigida: la app no debe imponer silenciosamente
# imputación por media a todos los análisis.
stopifnot(!media_hardcoded)

cat("PASS: la imputación por media no está impuesta como política oculta.\n")
