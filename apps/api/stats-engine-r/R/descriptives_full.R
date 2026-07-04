# ResearchOS - Estadisticos descriptivos completos
options(encoding="UTF-8")
run_descriptives_full <- function(df, items, var_name, scale_min=1, scale_max=5) {
  tryCatch({
    m_score <- df[,items,drop=FALSE]
    valid_count <- rowSums(!is.na(m_score))
    score <- rowMeans(m_score,na.rm=TRUE)
    score[valid_count < ceiling(length(items)*0.80)] <- NA_real_
    score[!is.finite(score)] <- NA_real_
    n <- length(score[!is.na(score)])
    
    m <- mean(score,na.rm=TRUE)
    s <- sd(score,na.rm=TRUE)
    skew <- mean(((score-m)/s)^3,na.rm=TRUE)
    kurt <- mean(((score-m)/s)^4,na.rm=TRUE)-3
    
    # Shapiro-Wilk
    sw_x <- score[!is.na(score)]
    sw <- if(length(sw_x)>=3 && length(sw_x)<=5000) shapiro.test(sw_x) else NULL
    
    # IC para la media
    se <- s/sqrt(n)
    ci_low <- m - qt(0.975,n-1)*se
    ci_high <- m + qt(0.975,n-1)*se
    
    # Por item
    item_stats <- lapply(items, function(item) {
      x <- df[[item]]
      x <- x[!is.na(x)]
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
    
    list(
      var_name=var_name, n=n, k=length(items),
      mean=round(m,2), median=round(median(score,na.rm=TRUE),2),
      mode=as.numeric(names(which.max(table(round(score,1))))),
      sd=round(s,2), variance=round(var(score,na.rm=TRUE),2),
      se=round(se,3),
      ci_lower=round(ci_low,2), ci_upper=round(ci_high,2),
      min=round(min(score,na.rm=TRUE),2),
      max=round(max(score,na.rm=TRUE),2),
      range=round(max(score,na.rm=TRUE)-min(score,na.rm=TRUE),2),
      skewness=round(skew,3),
      kurtosis=round(kurt,3),
      skewness_interpret=if(abs(skew)<0.5)"Simetrica" else if(abs(skew)<1)"Moderadamente asimetrica" else "Muy asimetrica",
      kurtosis_interpret=if(abs(kurt)<0.5)"Mesocurtica" else if(kurt>0)"Leptocurtica" else "Platicurtica",
      sw_W=if(!is.null(sw))as.numeric(sw$statistic)else NA_real_, sw_p=if(!is.null(sw))as.numeric(sw$p.value)else NA_real_,
      normal=sw$p.value>0.05,
      p25=round(quantile(score,0.25,na.rm=TRUE),2),
      p50=round(quantile(score,0.50,na.rm=TRUE),2),
      p75=round(quantile(score,0.75,na.rm=TRUE),2),
      iqr=round(IQR(score,na.rm=TRUE),2),
      cv=round(s/m*100,1),
      item_stats=item_stats
    )
  }, error=function(e) list(error=e$message))
}
