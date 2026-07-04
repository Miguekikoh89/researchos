#!/usr/bin/env Rscript
source("apps/api/stats-engine-r/R/word_export.R")

cat("=== FORMATO APA DEL INFORME WORD ===\n")
stopifnot(format_apa_p(0) == "< .001")
stopifnot(format_apa_p(0.0006) == "< .001")
stopifnot(format_apa_p(0.0038) == ".004")
stopifnot(format_apa_ci(0.925841819824583, 0.944854341249437) == "[.926, .945]")

br <- data.frame(
  nivel = c("Bajo", "Medio", "Alto"),
  desde = c(1, 2.33333333333333, 3.66666666666667),
  hasta = c(2.33333333333333, 3.66666666666667, 5)
)
fmt <- format_baremo_table(br)
stopifnot(fmt$Rango[1] == "1.00 ≤ puntaje ≤ 2.33")
stopifnot(fmt$Rango[2] == "2.33 < puntaje ≤ 3.67")
stopifnot(fmt$Rango[3] == "3.67 < puntaje ≤ 5.00")
cat("PASS: valores p, IC y rangos de baremo se exportan con formato APA inequívoco.\n")
