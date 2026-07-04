source("apps/api/stats-engine-r/R/helpers.R")
source("apps/api/stats-engine-r/R/statistics.R")

# Muestra pequeña sin empates: la implementación activa exact = TRUE.
x <- 1:20
y <- c(1, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14, 17, 16, 19, 18, 20)

reference_exact <- cor.test(
  x, y,
  method = "kendall",
  alternative = "two.sided",
  exact = TRUE
)

reference_asymptotic <- cor.test(
  x, y,
  method = "kendall",
  alternative = "two.sided",
  exact = FALSE
)

cancharios <- correlate_pair(
  x, y,
  method = "kendall",
  alpha = 0.05,
  hypothesis_type = "bilateral"
)

cat("=== SEMÁNTICA DEL ESTADÍSTICO KENDALL ===\n")
cat(sprintf(
  "Estadístico exacto de R:       %s = %.12f\n",
  names(reference_exact$statistic),
  unname(reference_exact$statistic)
))
cat(sprintf(
  "Estadístico asintótico de R:   %s = %.12f\n",
  names(reference_asymptotic$statistic),
  unname(reference_asymptotic$statistic)
))
cat(sprintf(
  "Campo z reportado por la app:  z = %.12f\n",
  cancharios$z
))

stopifnot(tolower(names(reference_asymptotic$statistic)) == "z")

# Si la aplicación denomina el campo como z, debe contener el z asintótico,
# no el estadístico exacto T.
stopifnot(
  abs(cancharios$z - unname(reference_asymptotic$statistic)) < 1e-10
)

cat("PASS: Kendall reporta correctamente el estadístico z.\n")
