source("apps/api/stats-engine-r/R/helpers.R")
source("apps/api/stats-engine-r/R/statistics.R")

x <- 1:12
y <- 1:12

result <- correlate_pair(
  x,
  y,
  method = "kendall",
  alpha = 0.05,
  hypothesis_type = "bilateral"
)

cat("=== INTERVALO DE CONFIANZA KENDALL ===\n")
cat(sprintf("tau-b:     %.12f\n", result$r))
cat(sprintf("IC inferior: %.12f\n", result$ci_lower))
cat(sprintf("IC superior: %.12f\n", result$ci_upper))

stopifnot(is.finite(result$ci_lower))
stopifnot(is.finite(result$ci_upper))
stopifnot(result$ci_lower >= -1)
stopifnot(result$ci_upper <= 1)
stopifnot(result$ci_lower <= result$r)
stopifnot(result$ci_upper >= result$r)

cat("PASS: el IC de Kendall permanece dentro de [-1, 1] y contiene tau-b.\n")
