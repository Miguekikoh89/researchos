source("apps/api/stats-engine-r/R/t_test.R")

n <- 50
alpha <- 0.05
target_p <- 0.04996
df <- 2 * n - 2

target_t <- qt(1 - target_p / 2, df = df)

# Vector aproximadamente normal con media 0 y DE muestral 1.
z <- qnorm(ppoints(n))
z <- as.numeric(scale(z))

# Para dos grupos con igual n y varianza:
# t = diferencia_media / sqrt(2/n)
delta <- target_t * sqrt(2 / n)

x1 <- z + delta / 2
x2 <- z - delta / 2

reference <- t.test(
  x1,
  x2,
  var.equal = TRUE,
  alternative = "two.sided"
)

cancharios <- t_independent(
  x1,
  x2,
  alpha = alpha,
  group_names = c("Grupo 1", "Grupo 2"),
  alt = "two.sided",
  levene_opt = "yes"
)

cat("=== PRECISIÓN DEL VALOR p EN t DE STUDENT ===\n")
cat(sprintf("t de referencia:       %.12f\n", unname(reference$statistic)))
cat(sprintf("p real de referencia:  %.12f\n", reference$p.value))
cat(sprintf("p guardado por app:     %.12f\n", cancharios$p))
cat(sprintf("Decisión correcta:      %s\n", reference$p.value < alpha))
cat(sprintf("Decisión de la app:     %s\n", cancharios$significant))

stopifnot(abs(reference$p.value - target_p) < 1e-10)
stopifnot(isTRUE(reference$p.value < alpha))
stopifnot(isTRUE(cancharios$significant))

# El resultado persistido debe conservar la precisión completa.
stopifnot(abs(cancharios$p - reference$p.value) < 1e-12)

cat("PASS: la prueba t conserva la precisión completa del valor p.\n")
