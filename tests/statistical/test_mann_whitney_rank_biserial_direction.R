source("apps/api/stats-engine-r/R/t_test.R")

# Separación completa: todos los valores del Grupo 1 son menores.
x1 <- c(1, 2, 3, 4, 5)
x2 <- c(11, 12, 13, 14, 15)

resultado <- mann_whitney(
  x1,
  x2,
  alpha = 0.05,
  group_names = c("Grupo 1", "Grupo 2"),
  alt = "two.sided"
)

referencia <- wilcox.test(
  x1,
  x2,
  alternative = "two.sided",
  exact = TRUE,
  correct = FALSE
)

U <- as.numeric(referencia$statistic)

# Convención direccional Grupo 1 − Grupo 2:
# +1 cuando todos los valores de G1 son mayores;
# −1 cuando todos los valores de G1 son menores.
r_rb_referencia <- (2 * U) / (length(x1) * length(x2)) - 1

cat("=== DIRECCIÓN DEL EFECTO MANN–WHITNEY ===\n")
cat(sprintf("U de referencia:       %.12f\n", U))
cat(sprintf("r_rb de referencia:    %.12f\n", r_rb_referencia))
cat(sprintf("r_rb de CanchariOS:    %.12f\n", resultado$r_rb))
cat(sprintf("Diferencia de medias:  %.12f\n", mean(x1) - mean(x2)))

stopifnot(r_rb_referencia == -1)
stopifnot(mean(x1) - mean(x2) < 0)

# El signo del efecto debe representar Grupo 1 − Grupo 2.
stopifnot(abs(resultado$r_rb - r_rb_referencia) < 1e-12)

cat("PASS: el rank-biserial conserva la dirección Grupo 1 − Grupo 2.\n")
