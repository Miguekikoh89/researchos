# ResearchOS - Analisis Descriptivo completo
# Combina: estadisticos descriptivos + normalidad + baremo + distribucion por niveles + redaccion APA
options(encoding="UTF-8")
run_analisis_descriptivo <- function(df, items, var_name, scale_min=1, scale_max=5,
                                      levels=c("Bajo","Medio","Alto"),
                                      method="tercil") {
  tryCatch({
    score <- rowMeans(df[,items,drop=FALSE],na.rm=TRUE)
    score <- score[is.na(score) == FALSE]
    n <- length(score)

    m <- mean(score,na.rm=TRUE)
    s <- sd(score,na.rm=TRUE)
    skew <- mean(((score-m)/s)^3,na.rm=TRUE)
    kurt <- mean(((score-m)/s)^4,na.rm=TRUE)-3
    sw <- shapiro.test(score)
    se <- s/sqrt(n)
    ci_low <- m - qt(0.975,n-1)*se
    ci_high <- m + qt(0.975,n-1)*se

    item_stats <- lapply(items, function(item) {
      x <- df[[item]]
      x <- x[is.na(x) == FALSE]
      sk <- mean(((x-mean(x))/sd(x))^3)
      ku <- mean(((x-mean(x))/sd(x))^4)-3
      list(
        item=item, n=length(x),
        mean=round(mean(x),2), median=round(median(x),2),
        mode=as.numeric(names(which.max(table(x)))),
        sd=round(sd(x),2), var=round(var(x),2),
        min=min(x), max=max(x),
        range=max(x)-min(x),
        skewness=round(sk,3),
        kurtosis=round(ku,3),
        cv=round(sd(x)/mean(x)*100,1),
        p25=round(quantile(x,0.25),2),
        p50=round(quantile(x,0.50),2),
        p75=round(quantile(x,0.75),2)
      )
    })

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
    texto_descriptivo <- paste0(
      "La variable ", var_name, " (n = ", n, ", k = ", length(items), " items) presento una media de ",
      round(m,2), " (DE = ", round(s,2), "). ",
      "La distribucion de los datos ", if(sw$p.value>0.05) "se ajusta a una distribucion normal" else "no se ajusta a una distribucion normal",
      " (Shapiro-Wilk: W = ", round(sw$statistic,3), ", p = ", round(sw$p.value,4), ")."
    )

    percentiles <- quantile(score, probs=seq(0,1,0.1), na.rm=TRUE)
    perc_table <- lapply(names(percentiles), function(p) {
      list(percentile=p, value=round(percentiles[[p]],2))
    })

    list(
      var_name=var_name, n=n, k=length(items),
      mean=round(m,2), median=round(median(score,na.rm=TRUE),2),
      mode=as.numeric(names(which.max(table(round(score,1))))),
      sd=round(s,2), variance=round(var(score,na.rm=TRUE),2),
      se=round(se,3), ci_lower=round(ci_low,2), ci_upper=round(ci_high,2),
      min=round(min(score,na.rm=TRUE),2), max=round(max(score,na.rm=TRUE),2),
      range=round(max(score,na.rm=TRUE)-min(score,na.rm=TRUE),2),
      skewness=round(skew,3), kurtosis=round(kurt,3),
      skewness_interpret=if(abs(skew)<0.5)"Simetrica" else if(abs(skew)<1)"Moderadamente asimetrica" else "Muy asimetrica",
      kurtosis_interpret=if(abs(kurt)<0.5)"Mesocurtica" else if(kurt>0)"Leptocurtica" else "Platicurtica",
      sw_W=round(sw$statistic,3), sw_p=round(sw$p.value,4), normal=sw$p.value>0.05,
      p25=round(quantile(score,0.25,na.rm=TRUE),2), p50=round(quantile(score,0.50,na.rm=TRUE),2), p75=round(quantile(score,0.75,na.rm=TRUE),2),
      iqr=round(IQR(score,na.rm=TRUE),2), cv=round(s/m*100,1),
      item_stats=item_stats,
      method=method, cuts=cortes, levels=levels,
      baremo=baremo_table, distribution=dist_table,
      texto_baremo=texto_baremo, texto_niveles=texto_niveles, texto_descriptivo=texto_descriptivo,
      percentiles=perc_table
    )
  }, error=function(e) list(error=e$message))
}
