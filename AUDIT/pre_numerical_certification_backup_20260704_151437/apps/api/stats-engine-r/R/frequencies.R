# ResearchOS - Analisis de Frecuencias
options(encoding="UTF-8")
run_frequencies <- function(df, items, var_name, scale_min=1, scale_max=5) {
  tryCatch({
    results <- lapply(items, function(item) {
      x <- df[[item]]
      x <- x[!is.na(x)]
      freq_table <- as.data.frame(table(x))
      colnames(freq_table) <- c("valor","n")
      freq_table$pct <- round(freq_table$n/sum(freq_table$n)*100,1)
      freq_table$pct_acum <- round(cumsum(freq_table$n)/sum(freq_table$n)*100,1)
      list(
        item=item,
        n=length(x),
        mean=round(mean(x,na.rm=TRUE),2),
        median=round(median(x,na.rm=TRUE),2),
        mode=as.numeric(names(which.max(table(x)))),
        sd=round(sd(x,na.rm=TRUE),2),
        min=min(x,na.rm=TRUE),
        max=max(x,na.rm=TRUE),
        skewness=round(mean(((x-mean(x,na.rm=TRUE))/sd(x,na.rm=TRUE))^3,na.rm=TRUE),3),
        kurtosis=round(mean(((x-mean(x,na.rm=TRUE))/sd(x,na.rm=TRUE))^4,na.rm=TRUE)-3,3),
        frequency_table=split(freq_table,seq(nrow(freq_table)))
      )
    })
    
    # Puntaje total
    m_score <- df[,items,drop=FALSE]
    valid_count <- rowSums(!is.na(m_score))
    score <- rowMeans(m_score,na.rm=TRUE)
    score[valid_count < ceiling(length(items)*0.80)] <- NA_real_
    score[!is.finite(score)] <- NA_real_
    list(
      var_name=var_name, n=nrow(df), k=length(items),
      items=results,
      total_mean=round(mean(score,na.rm=TRUE),2),
      total_sd=round(sd(score,na.rm=TRUE),2),
      total_median=round(median(score,na.rm=TRUE),2),
      total_min=round(min(score,na.rm=TRUE),2),
      total_max=round(max(score,na.rm=TRUE),2)
    )
  }, error=function(e) list(error=e$message))
}
