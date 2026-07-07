options(stringsAsFactors=FALSE, encoding="UTF-8")
repo_root <- normalizePath(getwd(), winslash="/", mustWork=TRUE)
source_r <- function(name) source(file.path(repo_root,"apps/api/stats-engine-r/R",name), local=.GlobalEnv)
expect_true <- function(x,msg="Condición no satisfecha") if(!isTRUE(x)) stop(msg,call.=FALSE)
expect_close <- function(a,b,tol=1e-8,msg=NULL){
  a<-as.numeric(a);b<-as.numeric(b)
  if(length(a)!=length(b)||any(!is.finite(a))||any(!is.finite(b))||max(abs(a-b))>tol)
    stop(msg %||% paste0("No coincide: ",paste(a,collapse=",")," vs ",paste(b,collapse=","),"; tol=",tol),call.=FALSE)
}
`%||%` <- function(a,b) if(!is.null(a)&&length(a)>0)a else b
require_pkg <- function(pkg){if(!requireNamespace(pkg,quietly=TRUE))stop("Paquete obligatorio no instalado: ",pkg,call.=FALSE)}
