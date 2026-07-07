#!/usr/bin/env Rscript
options(repos=c(CRAN="https://cloud.r-project.org"))
required_packages <- c(
  "readxl","dplyr","tidyr","psych","nortest","officer","flextable",
  "openxlsx","jsonlite","lavaan","GPArotation","htmlwidgets","visNetwork",
  "DiagrammeR","DiagrammeRsvg","seminr","seminrExtras","MASS","nnet","cluster"
)
optional_packages <- c(
  "ordinal",  # prueba adicional de líneas paralelas; el modelo polr funciona sin él
  "car",      # utilidades heredadas, no requerido por el núcleo certificado
  "klaR"      # extensión discriminante opcional
)
install_missing <- function(pkg, required=TRUE){
  if(requireNamespace(pkg,quietly=TRUE)){
    cat("  ✓ Ya instalado: ",pkg,"\n",sep="");return(TRUE)
  }
  cat(if(required)"  Instalando requerido: " else "  Opcional no instalado: ",pkg,"\n",sep="")
  if(!required && tolower(Sys.getenv("INSTALL_OPTIONAL_R_PACKAGES","false"))!="true")return(FALSE)
  try(suppressWarnings(install.packages(pkg,quiet=TRUE)),silent=TRUE)
  ok<-requireNamespace(pkg,quietly=TRUE)
  cat(if(ok)"  ✓ Instalado: " else if(required)"  ✗ FALTA requerido: " else "  ○ No disponible opcional: ",pkg,"\n",sep="")
  ok
}
cat("Instalando/verificando dependencias del motor estadístico CanchariOS...\n\n")
required_ok<-vapply(required_packages,install_missing,logical(1),required=TRUE)
invisible(vapply(optional_packages,install_missing,logical(1),required=FALSE))
if(!all(required_ok)){
  cat("\n❌ Faltan paquetes R obligatorios: ",paste(required_packages[!required_ok],collapse=", "),"\n",sep="")
  quit(status=1)
}
cat("\n✅ Todas las dependencias obligatorias están disponibles.\n")
