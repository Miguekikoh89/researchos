suppressPackageStartupMessages({
  library(readxl)
  library(jsonlite)
})

dataset <- "tests/golden-data/correlation/PGV_IER_384.xlsx"
output  <- "tests/reference/r/PGV_IER_384_expected.json"

pgv_items <- paste0("PGV", 1:12)
ier_items <- paste0("IER", 1:12)

df <- read_excel(dataset, sheet = 1)

required <- c(pgv_items, ier_items)
missing_columns <- setdiff(required, names(df))

if (length(missing_columns) > 0) {
  stop(paste("Columnas faltantes:", paste(missing_columns, collapse = ", ")))
}

pgv_total <- rowSums(df[, pgv_items], na.rm = FALSE)
ier_total <- rowSums(df[, ier_items], na.rm = FALSE)

valid <- complete.cases(pgv_total, ier_total)
pgv_total <- pgv_total[valid]
ier_total <- ier_total[valid]

pearson  <- cor.test(pgv_total, ier_total, method = "pearson")
spearman <- cor.test(pgv_total, ier_total, method = "spearman", exact = FALSE)
kendall  <- cor.test(pgv_total, ier_total, method = "kendall", exact = FALSE)

baremo <- function(x) {
  categoria <- cut(
    x,
    breaks = c(-Inf, 28, 44, Inf),
    labels = c("Bajo", "Medio", "Alto"),
    include.lowest = TRUE,
    right = TRUE
  )

  if (any(is.na(categoria))) {
    stop("Existen participantes sin clasificar.")
  }

  frecuencias <- table(factor(
    categoria,
    levels = c("Bajo", "Medio", "Alto")
  ))

  resultado <- as.list(as.integer(frecuencias))
  names(resultado) <- names(frecuencias)

  if (sum(unlist(resultado)) != length(x)) {
    stop("Las frecuencias no suman N.")
  }

  resultado
}

pgv_baremo <- baremo(pgv_total)
ier_baremo <- baremo(ier_total)

stopifnot(
  length(pgv_total) == 384,
  abs(unname(spearman$estimate) - 0.7867272) < 1e-6,
  identical(unlist(pgv_baremo), c(Bajo = 115L, Medio = 143L, Alto = 126L)),
  identical(unlist(ier_baremo), c(Bajo = 79L, Medio = 218L, Alto = 87L))
)

resultado <- list(
  dataset = dataset,
  n = length(pgv_total),
  pearson = list(
    r = unname(pearson$estimate),
    p_value = pearson$p.value
  ),
  spearman = list(
    rho = unname(spearman$estimate),
    p_value = spearman$p.value
  ),
  kendall = list(
    tau_b = unname(kendall$estimate),
    p_value = kendall$p.value
  ),
  baremos_teoricos = list(
    criterio_total = list(
      Bajo = "12–28",
      Medio = "29–44",
      Alto = "45–60"
    ),
    PGV = pgv_baremo,
    IER = ier_baremo
  ),
  status = "PASS"
)

write_json(
  resultado,
  output,
  pretty = TRUE,
  auto_unbox = TRUE,
  digits = 16
)

cat(toJSON(
  resultado,
  pretty = TRUE,
  auto_unbox = TRUE,
  digits = 16
), "\n")
