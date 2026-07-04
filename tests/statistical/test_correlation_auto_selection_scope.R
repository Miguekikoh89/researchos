source("apps/api/stats-engine-r/R/helpers.R")
source("apps/api/stats-engine-r/R/statistics.R")

set.seed(20260703)

n <- 300
x <- rnorm(n)
y <- 0.65 * x + rnorm(n, sd = 0.75)

# Las dos variables principales cumplen normalidad.
# Una dimensión ajena se marca como no normal.
normality_all <- data.frame(
  variable = c("Variable A", "Variable B", "Dimensión ajena"),
  decision = c("Normal", "Normal", "No normal"),
  stringsAsFactors = FALSE
)

normality_main_pair <- subset(
  normality_all,
  variable %in% c("Variable A", "Variable B")
)

method_with_irrelevant_dimension <- decide_method(
  normality_all,
  force = "auto",
  x = x,
  y = y
)

method_main_pair_only <- decide_method(
  normality_main_pair,
  force = "auto",
  x = x,
  y = y
)

cat("=== ALCANCE DE LA SELECCIÓN AUTOMÁTICA ===\n")
cat("Método usando todas las dimensiones: ", method_with_irrelevant_dimension, "\n", sep = "")
cat("Método usando solo el par principal:  ", method_main_pair_only, "\n", sep = "")

stopifnot(method_main_pair_only == "pearson")

# La presencia de una dimensión ajena no debe modificar el método
# correspondiente a Variable A × Variable B.
stopifnot(method_with_irrelevant_dimension == method_main_pair_only)

cat("PASS: la selección automática depende únicamente del par analizado.\n")
