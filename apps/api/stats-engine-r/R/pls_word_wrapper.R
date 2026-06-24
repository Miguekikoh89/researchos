#!/usr/bin/env Rscript
# Wrapper: genera el Word de PLS-SEM a partir del JSON de resultado ya calculado
# por pls_sem_engine.R. No vuelve a ejecutar el modelo (motor blindado intacto).
invisible(suppressWarnings(Sys.setlocale("LC_ALL", "en_US.utf8")))
args <- commandArgs(trailingOnly = TRUE)
result_json_path <- args[1]
output_dir <- args[2]
study_title <- if (length(args) >= 3) args[3] else "Modelo PLS-SEM"

r_dir <- Sys.getenv("CANCHARIOS_R_DIR", unset = "/app/stats-engine-r/R")
source(file.path(r_dir, "helpers.R"))
source(file.path(r_dir, "word_export.R"))

library(jsonlite)
result <- fromJSON(result_json_path, simplifyVector = FALSE)
config <- list(study_title = study_title)

doc <- generate_word_pls_sem(result, config, output_dir, 1)
fpath <- save_word(doc, output_dir)
cat(toJSON(list(word_path = fpath), auto_unbox = TRUE))
