# CanchariOS - Análisis descriptivo integral
options(encoding="UTF-8")

run_analisis_descriptivo <- function(df, items, var_name, scale_min=1, scale_max=5,
                                      levels=c("Bajo","Medio","Alto"), method="tercil") {
  tryCatch({
    desc <- run_descriptives_full(df,items,var_name,scale_min,scale_max)
    if(!is.null(desc$error))return(desc)
    br <- run_baremos_only(df,items,var_name,scale_min,scale_max,levels,method)
    if(isTRUE(br$blocked)||!is.null(br$error))return(br)
    normal_txt <- if(!isTRUE(desc$normality_available)) {
      "no pudo evaluarse mediante Shapiro–Wilk (fuera del rango 3–5000 o variable constante)"
    } else if(isTRUE(desc$normal)) "se ajustó a una distribución normal" else "no se ajustó a una distribución normal"
    p_txt <- if(!isTRUE(desc$normality_available)) "no disponible" else if(desc$sw_p<.001)"< .001"else paste0("= ",sub("^0","",sprintf("%.3f",desc$sw_p)))
    w_txt <- if(!isTRUE(desc$normality_available))"no disponible"else sub("^0","",sprintf("%.3f",desc$sw_W))
    texto_descriptivo <- paste0("La variable ",var_name," (n = ",desc$n,", k = ",desc$k," ítems) presentó una media de ",desc$mean," (DE = ",desc$sd,"). La distribución ",normal_txt," (Shapiro–Wilk: W = ",w_txt,", p ",p_txt,").")
    c(desc,list(method=br$method,cuts=br$cuts,cuts_raw=br$cuts_raw,levels=br$levels,baremo=br$baremo,distribution=br$distribution,
      texto_baremo=br$texto_baremo,texto_niveles=br$texto_niveles,texto_descriptivo=texto_descriptivo,percentiles=br$percentiles))
  },error=function(e)list(error=conditionMessage(e)))
}
