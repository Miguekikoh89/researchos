# CanchariOS - Análisis de frecuencias (fail-closed)
options(encoding="UTF-8")

.freq_shape <- function(x){
  x<-x[is.finite(x)];s<-if(length(x)>=2)sd(x)else NA_real_
  if(length(x)<3||!is.finite(s)||s<=sqrt(.Machine$double.eps))return(list(skew=NA_real_,kurt=NA_real_))
  z<-(x-mean(x))/s;list(skew=mean(z^3),kurt=mean(z^4)-3)
}

run_frequencies <- function(df, items, var_name, scale_min=1, scale_max=5) {
  tryCatch({
    items<-as.character(unlist(items));if(length(items)<1||!all(items%in%names(df)))stop("Ítems no encontrados.")
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
    numeric_items<-as.data.frame(converted,check.names=FALSE);names(numeric_items)<-items
    results <- lapply(items, function(item) {
      x <- numeric_items[[item]];x<-x[is.finite(x)]
      if(!length(x))return(list(item=item,n=0,error="Sin datos numéricos válidos"))
      freq_table <- as.data.frame(table(x),stringsAsFactors=FALSE);colnames(freq_table)<-c("valor","n")
      freq_table$pct <- round(freq_table$n/sum(freq_table$n)*100,1)
      freq_table$pct_acum <- round(cumsum(freq_table$n)/sum(freq_table$n)*100,1)
      sh<-.freq_shape(x);sx<-if(length(x)>=2)sd(x)else NA_real_
      list(item=item,n=length(x),mean=mean(x),median=median(x),mode=as.numeric(names(which.max(table(x)))),sd=sx,
        min=min(x),max=max(x),skewness=sh$skew,kurtosis=sh$kurt,frequency_table=split(freq_table,seq_len(nrow(freq_table))))
    })
    m_score<-numeric_items
    valid_count<-rowSums(!is.na(m_score));score<-rowMeans(m_score,na.rm=TRUE);score[valid_count<ceiling(length(items)*.80)]<-NA_real_;score[!is.finite(score)]<-NA_real_;valid_score<-score[is.finite(score)]
    if(length(valid_score)<2)stop("Puntajes válidos insuficientes para frecuencias agregadas.")
    list(var_name=var_name,n=nrow(df),n_valid=length(valid_score),k=length(items),items=results,
      total_mean=mean(valid_score),total_sd=sd(valid_score),total_median=median(valid_score),total_min=min(valid_score),total_max=max(valid_score))
  },error=function(e)list(error=conditionMessage(e)))
}
