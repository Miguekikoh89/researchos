source("apps/api/stats-engine-r/R/t_test.R")

# Todas las mediciones del primer momento son menores que las del segundo.
x1 <- c(1, 2, 3, 4, 5, 6)
x2 <- c(11, 12, 13, 14, 15, 16)

resultado <- wilcoxon_paired(
  x1,
  x2,
  alpha = 0.05,
  group_names = c("Momento 1", "Momento 2"),
  alt = "two.sided"
)

referencia <- suppressWarnings(
  wilcox.test(
    x1,
    x2,
    paired = TRUE,
    alternative = "two.sided",
    exact = TRUE,
    correct = FALSE
  )
)

V <- as.numeric(referencia$statistic)
n <- length(x1)
total_rangos <- n * (n + 1) / 2

# Convención direccional Momento 1 − Momento 2:
# +1 si todas las diferencias son positivas;
# −1 si todas son negativas.
r_rb_referencia <- (2 * V / total_rangos) - 1

cat("=== DIRECCIÓN DEL EFECTO WILCOXON PAREADO ===\n")
cat(sprintf("V de referencia:       %.12f\n", V))
cat(sprintf("r_rb de referencia:    %.12f\n", r_rb_referencia))
cat(sprintf("r_rb de CanchariOS:    %.12f\n", resultado$r_rb))
cat(sprintf("Diferencia media:      %.12f\n", mean(x1 - x2)))

stopifnot(r_rb_referencia == -1)
stopifnot(mean(x1 - x2) < 0)

# El efecto debe conservar la dirección Momento 1 − Momento 2.
stopifnot(abs(resultado$r_rb - r_rb_referencia) < 1e-12)

cat("PASS: el rank-biserial pareado conserva dirección y magnitud.\n")
