source("apps/api/stats-engine-r/R/helpers.R")
source("apps/api/stats-engine-r/R/statistics.R")

# Construye una correlación Pearson con p bilateral = 0.04996.
# Es significativa con alfa = .05, pero redondearla antes de decidir
# produce p = .0500 y cambia erróneamente la conclusión.

n <- 100
alpha <- 0.05
target_p <- 0.04996
df <- n - 2

target_t <- qt(1 - target_p / 2, df = df)
target_r <- target_t / sqrt(target_t^2 + df)

x <- as.numeric(scale(seq_len(n)))

z0 <- sin(seq_len(n))
z <- z0 - mean(z0)
z <- z - sum(z * x) / sum(x^2) * x
z <- z / sd(z)

y <- target_r * x + sqrt(1 - target_r^2) * z

reference <- cor.test(
  x,
  y,
  method = "pearson",
  alternative = "two.sided"
)

cancharios <- correlate_pair(
  x,
  y,
  method = "pearson",
  alpha = alpha,
  hypothesis_type = "bilateral"
)

cat("=== PRUEBA DE PRECISIÓN DEL VALOR p ===\n")
cat(sprintf("r de referencia:       %.12f\n", unname(reference$estimate)))
cat(sprintf("p real de referencia:  %.12f\n", reference$p.value))
cat(sprintf("p guardado por app:     %.12f\n", cancharios$p))
cat(sprintf("Decisión correcta:      %s\n", reference$p.value < alpha))
cat(sprintf("Decisión de la app:     %s\n", cancharios$significant))

stopifnot(reference$p.value < alpha)
stopifnot(abs(reference$p.value - target_p) < 1e-8)

# Estas condiciones representan el comportamiento científicamente correcto.
# Deben fallar con la implementación actual y pasar después de corregirla.
stopifnot(abs(cancharios$p - reference$p.value) < 1e-12)
stopifnot(isTRUE(cancharios$significant))

cat("PASS: se conserva la precisión completa del valor p.\n")
