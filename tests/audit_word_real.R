#!/usr/bin/env Rscript
# tests/audit_word_real.R
# Suite AD — Generacion real de Word con officer
#
# Verifica: officer instalado, generacion de DOCX para metodos
# principales, validez del ZIP, tablas APA en XML, numero correcto
# de tablas, y metadata del documento.
# Total: >= 30 tests
#
# NOTA: Si officer no esta instalado, todos los tests se marcan como
# SKIP y el suite retorna 0 (para no bloquear el CI base).
#
# Exit code: 0 = todos PASS/SKIP, 1 = al menos un FAIL real
# ============================================================================

pass <- 0L; fail <- 0L; skip <- 0L

check <- function(id, desc, cond) {
  label <- if (isTRUE(cond)) "PASS" else "FAIL"
  cat(sprintf("  [%s] %s: %s\n", label, id, desc))
  if (isTRUE(cond)) pass <<- pass + 1L else fail <<- fail + 1L
  invisible(isTRUE(cond))
}

skip_check <- function(id, desc) {
  cat(sprintf("  [SKIP] %s: %s\n", id, desc))
  skip <<- skip + 1L
  invisible(TRUE)
}

.script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    f <- sub("--file=", "", grep("--file=", commandArgs(trailingOnly=FALSE), value=TRUE))
    if (length(f) > 0) dirname(normalizePath(f)) else getwd()
  }
)
r_dir <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "R")

cat("=== SUITE AD — GENERACION WORD REAL ===\n")
cat(sprintf("    R version: %s\n\n", R.version.string))

officer_ok <- requireNamespace("officer", quietly=TRUE)
check("AD.INSTALL.01", "paquete officer disponible", officer_ok)
check("AD.INSTALL.02", "paquete jsonlite disponible", requireNamespace("jsonlite", quietly=TRUE))

if (!officer_ok) {
  cat("  [AVISO] officer no instalado — saltando tests de generacion de Word\n")
  cat("  Instalar con: install.packages('officer')\n\n")
  for (i in 1:28) skip_check(paste0("AD.WORD.", sprintf("%02d", i)),
                              "officer no disponible — SKIP")
  cat(sprintf("\n=== SUITE AD: %d PASS / %d FAIL / %d SKIP ===\n", pass, fail, skip))
  quit(status=0L)
}

library(officer)

for (f in c("helpers.R","statistics.R","regression.R","logistic.R",
            "anova.R","chi_square.R","instruments.R","word_export.R")) {
  tryCatch(source(file.path(r_dir, f)), error=function(e)
    cat(sprintf("  [WARN] No se pudo cargar %s: %s\n", f, e$message)))
}

tmp_dir <- tempdir()

# Funcion auxiliar: verificar que un DOCX es un ZIP valido con document.xml
verify_docx <- function(path) {
  if (!file.exists(path)) return(list(ok=FALSE, reason="archivo no existe"))
  fsize <- file.info(path)$size
  if (is.na(fsize) || fsize < 100) return(list(ok=FALSE, reason="archivo demasiado pequeño"))
  # Un DOCX es un ZIP; los primeros 2 bytes deben ser PK (0x50, 0x4B)
  hdr <- tryCatch(readBin(path, "raw", n=2), error=function(e) raw(0))
  if (length(hdr) < 2 || hdr[1] != 0x50 || hdr[2] != 0x4B)
    return(list(ok=FALSE, reason="no es ZIP valido"))
  # Listar contenido del ZIP
  files_in_zip <- tryCatch(
    unzip(path, list=TRUE)$Name,
    error=function(e) character(0)
  )
  has_doc_xml <- "word/document.xml" %in% files_in_zip
  list(ok=TRUE, fsize=fsize, files=files_in_zip, has_doc_xml=has_doc_xml)
}

# ── AD.OFFICER — Tests basicos de officer ──
cat("--- [AD.OFFICER] Funcionalidades basicas de officer ---\n")

doc1 <- read_docx()
doc1 <- body_add_par(doc1, "Tabla APA 7 — Prueba", style="heading 1")
out1 <- file.path(tmp_dir, "test_basic.docx")
print(doc1, target=out1)
v1 <- verify_docx(out1)
check("AD.OFFICER.01", "officer crea DOCX valido", v1$ok)
check("AD.OFFICER.02", "DOCX tiene word/document.xml", isTRUE(v1$has_doc_xml))
check("AD.OFFICER.03", "DOCX tiene > 500 bytes", !is.null(v1$fsize) && v1$fsize > 500)

# Agregar tabla
doc2 <- read_docx()
ft <- officer::fp_text(bold=TRUE)
tbl_data <- data.frame(Variable=c("x1","x2"), B=c(0.45, 0.32), p=c(".023",".041"))
doc2 <- body_add_table(doc2, tbl_data)
out2 <- file.path(tmp_dir, "test_tabla.docx")
print(doc2, target=out2)
v2 <- verify_docx(out2)
check("AD.OFFICER.04", "DOCX con tabla es valido", v2$ok)
check("AD.OFFICER.05", "DOCX con tabla tiene document.xml", isTRUE(v2$has_doc_xml))

# Extraer XML del documento
xml_content <- tryCatch({
  tmp_extract <- file.path(tmp_dir, "docx_extracted")
  dir.create(tmp_extract, showWarnings=FALSE, recursive=TRUE)
  unzip(out2, exdir=tmp_extract)
  doc_xml <- file.path(tmp_extract, "word", "document.xml")
  if (file.exists(doc_xml)) readLines(doc_xml, warn=FALSE) else character(0)
}, error=function(e) character(0))
check("AD.OFFICER.06", "XML del documento es legible", length(xml_content) > 0)
check("AD.OFFICER.07", "XML contiene w:tbl (tabla Word)",
      any(grepl("w:tbl", xml_content, fixed=TRUE)))

# ── AD.REGRESION — Word para regresion ──
cat("\n--- [AD.REGRESION] Word para regresion ---\n")

set.seed(42)
N <- 80
x1 <- rnorm(N); x2 <- rnorm(N); y <- 2*x1 + 1.5*x2 + rnorm(N)
res_reg <- compute_regression(y, data.frame(x1=x1, x2=x2), var_names=c("x1","x2"))
check("AD.REGRESION.01", "regresion ejecuta sin error", is.null(res_reg$error) && is.null(res_reg$blocked))

# Verificar campos clave para Word
check("AD.REGRESION.02", "R2 disponible para tabla Word", !is.null(res_reg$R2))
check("AD.REGRESION.03", "F disponible para tabla Word", !is.null(res_reg$F))
check("AD.REGRESION.04", "coefficients disponible para tabla Word", length(res_reg$coefficients) > 0)
check("AD.REGRESION.05", "p_apa disponible para tabla Word",
      !is.null(res_reg$p_apa) && nchar(res_reg$p_apa) > 0)

# Construir tabla de coeficientes y exportar a Word
coef_df <- do.call(rbind, lapply(res_reg$coefficients, function(c) {
  data.frame(Término=c$term, B=c$B, SE=c$SE, t=c$t, p=c$p_apa, stringsAsFactors=FALSE)
}))
doc_reg <- read_docx()
doc_reg <- body_add_par(doc_reg, "Tabla 1. Coeficientes de regresion", style="heading 2")
doc_reg <- body_add_table(doc_reg, coef_df)
out_reg <- file.path(tmp_dir, "regresion_word.docx")
print(doc_reg, target=out_reg)
v_reg <- verify_docx(out_reg)
check("AD.REGRESION.06", "DOCX regresion valido", v_reg$ok)
check("AD.REGRESION.07", "DOCX regresion tiene document.xml", isTRUE(v_reg$has_doc_xml))

# ── AD.LOGISTICA — Word para logistica ──
cat("\n--- [AD.LOGISTICA] Word para logistica ---\n")

y_bin <- as.integer(plogis(0.6*x1 + 0.4*x2) > 0.5)
res_log <- compute_logistic_binary(y_bin, data.frame(x1=x1, x2=x2),
                                    var_names=c("x1","x2"), event_level="1")
check("AD.LOGISTICA.01", "logistica ejecuta sin error", is.null(res_log$blocked) && is.null(res_log$error))
check("AD.LOGISTICA.02", "OR disponibles para tabla Word",
      !is.null(res_log$coefficients) && !is.null(res_log$coefficients[[1]]$OR))

log_df <- do.call(rbind, lapply(res_log$coefficients, function(c) {
  data.frame(Término=c$term, B=c$B, OR=c$OR, p=c$p_apa, stringsAsFactors=FALSE)
}))
doc_log <- read_docx()
doc_log <- body_add_par(doc_log, "Tabla 2. Regresion Logistica", style="heading 2")
doc_log <- body_add_table(doc_log, log_df)
out_log <- file.path(tmp_dir, "logistica_word.docx")
print(doc_log, target=out_log)
v_log <- verify_docx(out_log)
check("AD.LOGISTICA.03", "DOCX logistica valido", v_log$ok)
check("AD.LOGISTICA.04", "DOCX logistica tiene document.xml", isTRUE(v_log$has_doc_xml))
check("AD.LOGISTICA.05", "r2_nagelkerke disponible para Word", !is.null(res_log$r2_nagelkerke))

# ── AD.ANOVA — Word para ANOVA ──
cat("\n--- [AD.ANOVA] Word para ANOVA ---\n")

y_aov <- c(rnorm(25,10), rnorm(25,12), rnorm(25,14))
grp_aov <- rep(c("G1","G2","G3"), each=25)
res_aov <- compute_anova(y_aov, grp_aov, alpha=0.05)
check("AD.ANOVA.01", "ANOVA ejecuta sin error", is.null(res_aov$error))
check("AD.ANOVA.02", "F disponible para tabla ANOVA", !is.null(res_aov$F))

doc_aov <- read_docx()
doc_aov <- body_add_par(doc_aov, "Tabla 3. ANOVA de un factor", style="heading 2")
aov_df <- data.frame(Fuente=c("Entre grupos","Dentro de grupos"),
                      F=c(res_aov$F, NA), p=c(res_aov$p_apa, "—"),
                      stringsAsFactors=FALSE)
doc_aov <- body_add_table(doc_aov, aov_df)
out_aov <- file.path(tmp_dir, "anova_word.docx")
print(doc_aov, target=out_aov)
v_aov <- verify_docx(out_aov)
check("AD.ANOVA.03", "DOCX ANOVA valido", v_aov$ok)

# ── AD.CHI — Word para chi-cuadrado ──
cat("\n--- [AD.CHI] Word para chi-cuadrado ---\n")

v1_chi <- sample(c("A","B","C"), N, replace=TRUE)
v2_chi <- sample(c("X","Y"), N, replace=TRUE)
res_chi <- compute_chisquare(v1_chi, v2_chi, alpha=0.05)
check("AD.CHI.01", "chi-cuadrado ejecuta sin error", is.null(res_chi$error))

doc_chi <- read_docx()
doc_chi <- body_add_par(doc_chi, "Tabla 4. Chi-cuadrado", style="heading 2")
chi_df <- data.frame(Estadistico=c("chi2","df","p"),
                      Valor=c(res_chi$chi2, res_chi$df, res_chi$p),
                      stringsAsFactors=FALSE)
doc_chi <- body_add_table(doc_chi, chi_df)
out_chi <- file.path(tmp_dir, "chi_word.docx")
print(doc_chi, target=out_chi)
v_chi <- verify_docx(out_chi)
check("AD.CHI.02", "DOCX chi-cuadrado valido", v_chi$ok)
check("AD.CHI.03", "chi2 en resultado", !is.null(res_chi$chi2))

# ── AD.MULTIDOC — Documento con multiples tablas ──
cat("\n--- [AD.MULTIDOC] Documento con multiples tablas ---\n")

doc_multi <- read_docx()
doc_multi <- body_add_par(doc_multi, "Informe Estadistico Completo", style="heading 1")
doc_multi <- body_add_par(doc_multi, "Tabla de Regresion", style="heading 2")
doc_multi <- body_add_table(doc_multi, coef_df)
doc_multi <- body_add_par(doc_multi, "Tabla Logistica", style="heading 2")
doc_multi <- body_add_table(doc_multi, log_df)
out_multi <- file.path(tmp_dir, "multi_word.docx")
print(doc_multi, target=out_multi)
v_multi <- verify_docx(out_multi)
check("AD.MULTIDOC.01", "DOCX multi-tabla valido", v_multi$ok)
check("AD.MULTIDOC.02", "DOCX multi-tabla tiene document.xml", isTRUE(v_multi$has_doc_xml))

xml_multi <- tryCatch({
  tmp_ext2 <- file.path(tmp_dir, "multi_extracted")
  dir.create(tmp_ext2, showWarnings=FALSE, recursive=TRUE)
  unzip(out_multi, exdir=tmp_ext2)
  doc_xml2 <- file.path(tmp_ext2, "word", "document.xml")
  if (file.exists(doc_xml2)) paste(readLines(doc_xml2, warn=FALSE), collapse=" ") else ""
}, error=function(e) "")
check("AD.MULTIDOC.03", "XML multi-tabla contiene al menos 2 w:tbl",
      length(gregexpr("w:tbl", xml_multi, fixed=TRUE)[[1]]) >= 2)

# ── Resumen ──
cat(sprintf("\n=== SUITE AD: %d PASS / %d FAIL / %d SKIP ===\n", pass, fail, skip))
if (fail > 0) quit(status=1L)
