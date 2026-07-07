# CanchariOS - Estadísticos descriptivos completos (fail-closed)
options(encoding="UTF-8")

.safe_shape <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x); s <- if (n >= 2) stats::sd(x) else NA_real_
  if (n < 3 || !is.finite(s) || s <= sqrt(.Machine$double.eps))
    return(list(skew=NA_real_, kurt=NA_real_))
  z <- (x - mean(x)) / s
  list(skew=mean(z^3), kurt=mean(z^4)-3)
}

run_descriptives_full <- function(df, items, var_name, scale_min=1, scale_max=5) {
  tryCatch({
    items <- as.character(unlist(items))
    if (length(items) < 1 || !all(items %in% names(df))) stop("Ítems descriptivos inexistentes.")

    raw_items <- df[, items, drop=FALSE]
    converted <- lapply(raw_items, function(x) {
      if (is.numeric(x)) return(as.numeric(x))
      txt <- trimws(as.character(x))
      suppressWarnings(as.numeric(txt))
    })
    conversion_losses <- vapply(seq_along(items), function(j) {
      raw <- raw_items[[j]]
      txt <- trimws(as.character(raw))
      present <- !is.na(raw) & nzchar(txt)
      sum(present & is.na(converted[[j]]))
    }, integer(1))
    nonfinite_counts <- vapply(converted, function(x) sum(!is.na(x) & !is.finite(x)), integer(1))
    if (any(conversion_losses > 0L)) {
      bad <- paste0(items[conversion_losses > 0L], " (", conversion_losses[conversion_losses > 0L], ")")
      stop(paste0("VALORES_NO_NUMERICOS: se detectaron valores no convertibles en ", paste(bad, collapse=", "), "."))
    }
    if (any(nonfinite_counts > 0L)) {
      bad <- paste0(items[nonfinite_counts > 0L], " (", nonfinite_counts[nonfinite_counts > 0L], ")")
      stop(paste0("VALORES_NO_FINITOS: se detectaron Inf/-Inf en ", paste(bad, collapse=", "), "."))
    }
    m_score <- as.data.frame(converted, check.names=FALSE)
    names(m_score) <- items
    valid_count <- rowSums(!is.na(m_score))
    score <- rowMeans(m_score,na.rm=TRUE)
    score[valid_count < ceiling(length(items)*0.80)] <- NA_real_
    score[!is.finite(score)] <- NA_real_
    score <- score[is.finite(score)]
    n <- length(score)
    if (n < 2) stop("Se requieren al menos 2 puntajes válidos.")

    m <- mean(score); s <- sd(score); shape <- .safe_shape(score)
    sw <- if(n>=3 && n<=5000 && length(unique(score))>1) tryCatch(shapiro.test(score),error=function(e)NULL) else NULL
    se <- s/sqrt(n)
    ci_low <- m - qt(0.975,n-1)*se; ci_high <- m + qt(0.975,n-1)*se

    item_stats <- lapply(items, function(item) {
      x <- m_score[[item]]; x <- x[is.finite(x)]
      sh <- .safe_shape(x); mx <- if(length(x)) mean(x) else NA_real_; sx <- if(length(x)>=2) sd(x) else NA_real_
      list(item=item,n=length(x),mean=if(length(x))round(mx,2)else NA_real_,median=if(length(x))round(median(x),2)else NA_real_,
        mode=if(length(x))as.numeric(names(which.max(table(x))))else NA_real_,sd=round(sx,2),var=round(sx^2,2),
        min=if(length(x))min(x)else NA_real_,max=if(length(x))max(x)else NA_real_,range=if(length(x))diff(range(x))else NA_real_,
        skewness=round(sh$skew,3),kurtosis=round(sh$kurt,3),
        cv=if(is.finite(mx)&&abs(mx)>sqrt(.Machine$double.eps)&&is.finite(sx))round(sx/mx*100,1)else NA_real_,
        p25=if(length(x))round(quantile(x,.25,names=FALSE),2)else NA_real_,p50=if(length(x))round(median(x),2)else NA_real_,p75=if(length(x))round(quantile(x,.75,names=FALSE),2)else NA_real_)
    })

    list(var_name=var_name,n=n,k=length(items),mean=round(m,2),median=round(median(score),2),
      mode=as.numeric(names(which.max(table(round(score,1))))),sd=round(s,2),variance=round(s^2,2),se=round(se,3),
      ci_lower=round(ci_low,2),ci_upper=round(ci_high,2),min=round(min(score),2),max=round(max(score),2),range=round(diff(range(score)),2),
      skewness=round(shape$skew,3),kurtosis=round(shape$kurt,3),
      skewness_interpret=if(!is.finite(shape$skew))"No disponible"else if(abs(shape$skew)<.5)"Simétrica"else if(abs(shape$skew)<1)"Moderadamente asimétrica"else"Muy asimétrica",
      kurtosis_interpret=if(!is.finite(shape$kurt))"No disponible"else if(abs(shape$kurt)<.5)"Mesocúrtica"else if(shape$kurt>0)"Leptocúrtica"else"Platicúrtica",
      sw_W=if(!is.null(sw))as.numeric(sw$statistic)else NA_real_,sw_p=if(!is.null(sw))as.numeric(sw$p.value)else NA_real_,
      normal=if(!is.null(sw))isTRUE(sw$p.value>.05)else NA,normality_available=!is.null(sw),
      p25=round(quantile(score,.25,names=FALSE),2),p50=round(median(score),2),p75=round(quantile(score,.75,names=FALSE),2),
      iqr=round(IQR(score),2),cv=if(abs(m)>sqrt(.Machine$double.eps))round(s/m*100,1)else NA_real_,item_stats=item_stats)
  }, error=function(e) list(error=conditionMessage(e)))
}
