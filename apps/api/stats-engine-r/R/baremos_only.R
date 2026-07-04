# ResearchOS - Baremos (parte del Analisis Descriptivo)
options(encoding="UTF-8")
run_baremos_only <- function(df, items, var_name, scale_min=1, scale_max=5,
                              levels=c("Bajo","Medio","Alto"),
                              method="tercil") {
  tryCatch({
    m_score <- df[,items,drop=FALSE]
    valid_count <- rowSums(!is.na(m_score))
    score <- rowMeans(m_score,na.rm=TRUE)
    score[valid_count < ceiling(length(items)*0.80)] <- NA_real_
    score[!is.finite(score)] <- NA_real_
    score <- score[is.na(score) == FALSE]
    n <- length(score)

    cortes <- switch(method,
      teorico   = c(scale_min, scale_min+(scale_max-scale_min)/3, scale_min+2*(scale_max-scale_min)/3, scale_max),
      percentil = c(min(score), quantile(score,.25,na.rm=TRUE), quantile(score,.75,na.rm=TRUE), max(score)),
      tercil    = c(min(score), quantile(score,1/3,na.rm=TRUE), quantile(score,2/3,na.rm=TRUE), max(score)),
      c(min(score), quantile(score,1/3,na.rm=TRUE), quantile(score,2/3,na.rm=TRUE), max(score))
    )
    cortes <- unique(round(as.numeric(cortes), 2))
    if(length(cortes) < 4) cortes <- c(min(score), quantile(score,1/3,na.rm=TRUE), quantile(score,2/3,na.rm=TRUE), max(score))
    cortes <- round(cortes, 2)

    baremo_table <- lapply(seq_along(levels), function(i) {
      list(nivel=levels[i], desde=cortes[i], hasta=cortes[i+1])
    })

    nivel_fct <- cut(score, breaks=cortes, labels=levels, include.lowest=TRUE)
    freq_tab <- table(nivel_fct, useNA="no")
    dist_table <- lapply(levels, function(lv) {
      f <- as.numeric(freq_tab[lv]); if(is.na(f)) f <- 0
      list(nivel=lv, f=f, pct=round(f/n*100,1))
    })
    acc <- 0
    dist_table <- lapply(dist_table, function(d) { acc <<- acc + d$pct; d$pct_ac <- round(acc,1); d })

    fs <- sapply(dist_table, function(d) d$f)
    ord <- order(-fs)
    mx <- dist_table[[ord[1]]]; nd <- dist_table[[ord[2]]]; mn <- dist_table[[ord[3]]]
    texto_baremo <- paste0(
      "El baremo de la variable ", var_name, " se organizo en tres niveles: ",
      tolower(levels[1]), ", ", tolower(levels[2]), " y ", tolower(levels[3]), ". ",
      "Esta clasificacion permite interpretar los puntajes obtenidos por los participantes ",
      "de acuerdo con los rangos establecidos segun el metodo seleccionado (n = ", n, ")."
    )
    texto_niveles <- paste0(
      "Los resultados muestran que el ", mx$pct, "% de los participantes presento un nivel ",
      tolower(mx$nivel), " de ", var_name, ", mientras que el ", nd$pct, "% se ubico en nivel ",
      tolower(nd$nivel), " y el ", mn$pct, "% en nivel ", tolower(mn$nivel), ". ",
      "Esto evidencia que la mayoria de los participantes se ubica en el nivel ", tolower(mx$nivel),
      " en la variable evaluada."
    )

    percentiles <- quantile(score, probs=seq(0,1,0.1), na.rm=TRUE)
    perc_table <- lapply(names(percentiles), function(p) {
      list(percentile=p, value=round(percentiles[[p]],2))
    })

    list(
      var_name=var_name, n=n, k=length(items),
      method=method, cuts=cortes, levels=levels,
      baremo=baremo_table, distribution=dist_table,
      texto_baremo=texto_baremo, texto_niveles=texto_niveles,
      percentiles=perc_table,
      total_mean=round(mean(score,na.rm=TRUE),2),
      total_sd=round(sd(score,na.rm=TRUE),2)
    )
  }, error=function(e) list(error=e$message))
}
