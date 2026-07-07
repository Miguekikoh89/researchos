# CanchariOS - Baremos independientes con cortes exactos
options(encoding="UTF-8")

run_baremos_only <- function(df, items, var_name, scale_min=1, scale_max=5,
                              levels=c("Bajo","Medio","Alto"), method="tercil") {
  tryCatch({
    items<-as.character(unlist(items)); if(length(items)<1||!all(items%in%names(df)))stop("Ítems no encontrados.")
    if(length(levels)!=3)stop("Se requieren exactamente tres niveles.")
    if(!is.numeric(scale_min)||!is.numeric(scale_max)||length(scale_min)!=1||length(scale_max)!=1||
       !is.finite(scale_min)||!is.finite(scale_max)||scale_min>=scale_max) stop("Rango teórico inválido: scale_min debe ser menor que scale_max.")

    raw_items<-df[,items,drop=FALSE]
    converted<-lapply(raw_items,function(x){
      if(is.numeric(x))return(as.numeric(x))
      txt<-trimws(as.character(x));suppressWarnings(as.numeric(txt))
    })
    conversion_losses<-vapply(seq_along(items),function(j){
      raw<-raw_items[[j]];txt<-trimws(as.character(raw));present<-!is.na(raw)&nzchar(txt)
      sum(present&is.na(converted[[j]]))
    },integer(1))
    nonfinite_counts<-vapply(converted,function(x)sum(!is.na(x)&!is.finite(x)),integer(1))
    if(any(conversion_losses>0L)){
      bad<-paste0(items[conversion_losses>0L]," (",conversion_losses[conversion_losses>0L],")")
      stop(paste0("VALORES_NO_NUMERICOS: se detectaron valores no convertibles en ",paste(bad,collapse=", "),"."))
    }
    if(any(nonfinite_counts>0L)){
      bad<-paste0(items[nonfinite_counts>0L]," (",nonfinite_counts[nonfinite_counts>0L],")")
      stop(paste0("VALORES_NO_FINITOS: se detectaron Inf/-Inf en ",paste(bad,collapse=", "),"."))
    }
    m_score<-as.data.frame(converted,check.names=FALSE);names(m_score)<-items
    valid_count<-rowSums(!is.na(m_score));score<-rowMeans(m_score,na.rm=TRUE)
    score[valid_count<ceiling(length(items)*.80)]<-NA_real_;score<-score[is.finite(score)];n<-length(score)
    if(n<5)stop("Muestra insuficiente para construir baremos.")
    method<-tolower(as.character(method))
    if(method=="teorico"){
      observed<-unlist(m_score,use.names=FALSE);observed<-observed[is.finite(observed)]
      tol_scale<-sqrt(.Machine$double.eps)*max(1,abs(c(scale_min,scale_max)))
      if(any(observed<scale_min-tol_scale|observed>scale_max+tol_scale))
        return(list(blocked=TRUE,reason="VALORES_FUERA_ESCALA",error=paste0("Existen respuestas fuera del rango teórico [",scale_min,", ",scale_max,"].")))
    }
    cuts_raw<-switch(method,
      teorico=c(scale_min,scale_min+(scale_max-scale_min)/3,scale_min+2*(scale_max-scale_min)/3,scale_max),
      percentil=c(min(score),unname(quantile(score,.25,type=7)),unname(quantile(score,.75,type=7)),max(score)),
      tercil=c(min(score),unname(quantile(score,1/3,type=7)),unname(quantile(score,2/3,type=7)),max(score)),
      stop(paste0("Método de baremo no reconocido: ",method)))
    cuts_raw<-as.numeric(cuts_raw)
    if(length(cuts_raw)!=4||any(!is.finite(cuts_raw))||any(diff(cuts_raw)<=0))
      return(list(blocked=TRUE,reason="CORTES_NO_DISTINTOS",error="Los datos no permiten formar tres intervalos empíricos distintos. Use baremo teórico o revise la distribución.",cuts_raw=cuts_raw))
    tol<-sqrt(.Machine$double.eps)*max(1,abs(cuts_raw[2:3]))
    class_breaks<-if(method=="teorico")c(-Inf,cuts_raw[2]+tol,cuts_raw[3]+tol,Inf)else c(-Inf,cuts_raw[2],cuts_raw[3],Inf)
    nivel<-cut(score,breaks=class_breaks,labels=levels,include.lowest=TRUE,right=TRUE)
    if(anyNA(nivel))stop("Existen casos sin clasificar.")
    fs<-as.integer(table(factor(nivel,levels=levels)))
    dist_table<-lapply(seq_along(levels),function(i)list(nivel=levels[i],f=fs[i],pct=round(100*fs[i]/n,2),pct_ac=round(100*sum(fs[seq_len(i)])/n,2)))
    baremo_table<-lapply(seq_along(levels),function(i)list(nivel=levels[i],desde=round(cuts_raw[i],2),hasta=round(cuts_raw[i+1],2)))
    ord<-order(-fs);mx<-dist_table[[ord[1]]];nd<-dist_table[[ord[2]]];mn<-dist_table[[ord[3]]]
    texto_baremo<-paste0("El baremo de la variable ",var_name," se organizó en tres niveles: ",paste(tolower(levels),collapse=", ")," (n = ",n,").")
    texto_niveles<-paste0("Los resultados muestran que el ",mx$pct,"% presentó un nivel ",tolower(mx$nivel)," de ",var_name,", el ",nd$pct,"% un nivel ",tolower(nd$nivel)," y el ",mn$pct,"% un nivel ",tolower(mn$nivel),". ",if(mx$pct>50)"La mayoría"else"La mayor proporción"," se ubicó en el nivel ",tolower(mx$nivel),".")
    per<-quantile(score,probs=seq(0,1,.1),type=7);perc_table<-lapply(seq_along(per),function(i)list(percentile=names(per)[i],value=round(as.numeric(per[i]),2)))
    list(var_name=var_name,n=n,k=length(items),method=method,cuts=round(cuts_raw,2),cuts_raw=cuts_raw,levels=levels,baremo=baremo_table,
      distribution=dist_table,texto_baremo=texto_baremo,texto_niveles=texto_niveles,percentiles=perc_table,total_mean=round(mean(score),2),total_sd=round(sd(score),2))
  },error=function(e)list(error=conditionMessage(e)))
}
