
# CanchariOS — confiabilidad independiente usando implementación canónica
options(encoding="UTF-8")
run_cronbach_only <- function(df,items,var_name,min_rit=.3,calc_omega="yes",bootstrap_ci="yes"){
  tryCatch({
    items<-as.character(unlist(items));if(length(items)<2||!all(items%in%names(df)))stop("Se requieren al menos 2 ítems válidos.")
    if(!exists("cronbach_alpha_ic",mode="function"))stop("cronbach_alpha_ic no está cargada.")
    res<-cronbach_alpha_ic(df[,items,drop=FALSE]);if(!is.finite(res$alpha))stop("No se pudo estimar alfa con los casos completos disponibles.")
    thr<-as.numeric(min_rit);its<-lapply(res$item_stats,function(it)list(item=it$item,mean=it$mean,sd=it$sd,r_item_total=it$r_item_total_corr,alpha_if_deleted=it$alpha_if_deleted,below_threshold=is.finite(it$r_item_total_corr)&&it$r_item_total_corr<thr,interpretation=if(is.finite(it$r_item_total_corr)&&it$r_item_total_corr<thr)"Revisar codificación o contenido"else"Conservar"))
    list(var_name=var_name,n=res$n,k=res$k,alpha=res$alpha,alpha_std=res$alpha_std,omega=if(tolower(calc_omega)%in%c("yes","si","true","1"))res$omega$omega_t else NA_real_,omega_h=NA_real_,omega_note="omega_h no se estima con un modelo unifactorial",ci_lower=res$ci_lower,ci_upper=res$ci_upper,bootstrap_used=FALSE,ci_method="Feldt",min_rit_threshold=thr,interpretation=res$interpretation,item_stats=its)
  },error=function(e)list(error=conditionMessage(e)))
}
