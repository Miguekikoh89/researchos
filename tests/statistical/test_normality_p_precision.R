#!/usr/bin/env Rscript
source("apps/api/stats-engine-r/R/helpers.R")
source("apps/api/stats-engine-r/R/statistics.R")

x <- c(rep(1, 50), rep(5, 50))
res <- compute_normality(data.frame(PGV = x), tests = "sw")

cat("=== PRECISIÓN DE p EN NORMALIDAD ===\n")
cat("p Shapiro-Wilk:", format(res$sw_p, digits=16), "\n")
stopifnot(is.numeric(res$sw_p))
stopifnot(is.finite(res$sw_p))
stopifnot(res$sw_p > 0)
stopifnot(res$sw_p < .001)
cat("PASS: normalidad conserva el valor p completo y no lo convierte en cero.\n")
