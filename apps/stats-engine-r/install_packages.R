#!/usr/bin/env Rscript
# ============================================================================
# ResearchOS Stats Engine — install_packages.R
# Instalar dependencias del motor estadístico
# ============================================================================

packages <- c(
  "readxl",    # Leer Excel
  "dplyr",     # Manipulación de datos
  "tidyr",     # Reshape
  "psych",     # Estadísticos descriptivos (skew, kurtosi)
  "nortest",   # Lilliefors (KS normalidad)
  "officer",   # Exportación Word
  "flextable", # Tablas APA en Word
  "openxlsx",  # Exportación Excel
  "jsonlite",  # Entrada/Salida JSON
  "lavaan",    # CFA/SEM (AFC)
  "GPArotation", # Rotaciones AFE
  "car",        # Tests adicionales
  "htmlwidgets", # Dependencia DiagrammeR
  "visNetwork",  # Dependencia DiagrammeR
  "DiagrammeR",  # Diagramas PLS-SEM
  "DiagrammeRsvg", # Export SVG
  "seminr"       # Motor PLS-SEM
)

cat("Instalando paquetes del motor estadístico ResearchOS...\n\n")

for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("  Instalando: ", pkg, "...\n"))
    install.packages(pkg, repos = "https://cloud.r-project.org", quiet = TRUE)
  } else {
    cat(paste0("  ✓ Ya instalado: ", pkg, "\n"))
  }
}

cat("\n✅ Dependencias listas.\n")
cat("\nPrueba de verificación:\n")
for (pkg in packages) {
  loaded <- tryCatch({
    library(pkg, character.only = TRUE, quietly = TRUE)
    TRUE
  }, error = function(e) FALSE)
  cat(paste0("  ", if (loaded) "✓" else "✗", " ", pkg, "\n"))
}
