# ResearchOS - Alfa de Cronbach independiente
options(encoding="UTF-8")
run_cronbach_only <- function(df, items, var_name, min_rit=0.3, calc_omega="yes", bootstrap_ci="yes") {
  tryCatch({
    datos <- df[,items,drop=FALSE]
    datos <- datos[complete.cases(datos),]
    k <- ncol(datos)
    n <- nrow(datos)

    vars <- apply(datos,2,var,na.rm=TRUE)
    total_var <- var(rowSums(datos,na.rm=TRUE),na.rm=TRUE)
    alpha <- (k/(k-1))*(1-sum(vars)/total_var)

    do_boot <- tolower(as.character(bootstrap_ci)) %in% c("yes","si","true","1")
    if (do_boot) {
      set.seed(42)
      boot_alphas <- replicate(1000, {
        idx <- sample(n,n,replace=TRUE)
        d <- datos[idx,]
        v <- apply(d,2,var,na.rm=TRUE)
        tv <- var(rowSums(d,na.rm=TRUE),na.rm=TRUE)
        (k/(k-1))*(1-sum(v)/tv)
      })
      ci <- quantile(boot_alphas, c(0.025,0.975), na.rm=TRUE)
    } else {
      ci <- c(NA, NA)
    }

    do_omega <- tolower(as.character(calc_omega)) %in% c("yes","si","true","1")
    omega_val <- NA
    if (do_omega) {
      tryCatch({
        if(!requireNamespace("psych",quietly=TRUE))
          stop("El paquete 'psych' es necesario para calcular omega.")
        om <- psych::omega(datos, nfactors=1, plot=FALSE)
        omega_val <- round(om$omega.tot,3)
      }, error=function(e) { omega_val <<- NA })
    }

    rit_threshold <- as.numeric(min_rit)
    item_stats <- lapply(items, function(item) {
      rest <- rowSums(datos[,setdiff(items,item),drop=FALSE],na.rm=TRUE)
      r_it <- cor(datos[[item]],rest,use="pairwise.complete.obs")
      d2 <- datos[,setdiff(items,item),drop=FALSE]
      v2 <- apply(d2,2,var,na.rm=TRUE)
      tv2 <- var(rowSums(d2,na.rm=TRUE),na.rm=TRUE)
      k2 <- k-1
      alpha_del <- (k2/(k2-1))*(1-sum(v2)/tv2)
      list(item=item, mean=round(mean(datos[[item]],na.rm=TRUE),2),
           sd=round(sd(datos[[item]],na.rm=TRUE),2),
           r_item_total=round(r_it,3),
           alpha_if_deleted=round(alpha_del,3),
           below_threshold=round(r_it,3) < rit_threshold,
           interpretation=if(round(r_it,3) < rit_threshold) "Revisar (r < umbral)" else if(round(alpha_del,3)>round(alpha,3))"Eliminar" else "Conservar")
    })

    alpha_interp <- if(alpha>=0.9)"Excelente" else if(alpha>=0.8)"Bueno" else if(alpha>=0.7)"Aceptable" else if(alpha>=0.6)"Cuestionable" else "Inaceptable"

    list(
      var_name=var_name, n=n, k=k,
      alpha=round(alpha,3),
      omega=omega_val,
      omega_calculated=do_omega,
      ci_lower=round(ci[1],3),
      ci_upper=round(ci[2],3),
      bootstrap_used=do_boot,
      min_rit_threshold=rit_threshold,
      interpretation=alpha_interp,
      item_stats=item_stats
    )
  }, error=function(e) list(error=e$message))
}
