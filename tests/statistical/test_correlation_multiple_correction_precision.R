source("apps/api/stats-engine-r/R/helpers.R")
source("apps/api/stats-engine-r/R/statistics.R")

# Sustituimos temporalmente el cálculo individual para probar exclusivamente
# la capa de corrección múltiple con valores p controlados.
original_correlate_pair <- correlate_pair

contador <- 0L

correlate_pair <- function(x, y, method = "pearson",
                           alpha = 0.05,
                           hypothesis_type = "bilateral") {
  contador <<- contador + 1L

  p_controlado <- c(
    0.02498,  # Bonferroni: 0.04996, todavía significativo
    0.04000   # Bonferroni: 0.08000, no significativo
  )[contador]

  list(
    r = 0.30,
    p = p_controlado,
    n = length(x),
    r_apa = ".300",
    p_apa = paste0("= ", p_controlado),
    stars = "",
    magnitude = "Moderada",
    effect_size = "Moderado",
    decision = if (p_controlado < alpha)
      "Se rechaza H0"
    else
      "No se rechaza H0",
    significant = p_controlado < alpha,
    ci_lower = 0.10,
    ci_upper = 0.48,
    power = 0.80
  )
}

on.exit({
  correlate_pair <- original_correlate_pair
}, add = TRUE)

scores <- data.frame(
  A = 1:20,
  B = 2:21,
  B1 = 3:22
)

config <- list(
  var_a = list(
    name = "A",
    dimensions = list()
  ),
  var_b = list(
    name = "B",
    dimensions = list(
      list(name = "B1")
    )
  )
)

resultado <- compute_correlations(
  scores = scores,
  config = config,
  method = "pearson",
  alpha = 0.05,
  analysis_types = c("vv", "vdB"),
  hypothesis_type = "bilateral",
  multiple_correction = "bonferroni"
)

cat("=== PRECISIÓN EN CORRECCIÓN MÚLTIPLE ===\n")
cat(sprintf(
  "p original 1:  %.12f\n",
  resultado$p[1]
))
cat(sprintf(
  "p ajustado 1:  %.12f\n",
  resultado$p_adjusted[1]
))
cat(sprintf(
  "Significativo: %s\n",
  resultado$significant[1]
))
cat(sprintf(
  "p ajustado 2:  %.12f\n",
  resultado$p_adjusted[2]
))

stopifnot(
  abs(resultado$p[1] - 0.02498) < 1e-12
)

stopifnot(
  abs(resultado$p_adjusted[1] - 0.04996) < 1e-12
)

stopifnot(
  isTRUE(resultado$significant[1])
)

stopifnot(
  abs(resultado$p_adjusted[2] - 0.08) < 1e-12
)

stopifnot(
  !resultado$significant[2]
)

cat("PASS: la corrección múltiple conserva la precisión completa.\n")
