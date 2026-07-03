# ============================================================================
# ResearchOS - ANOVA de un factor SPSS-identico
# ANOVA, Levene, post-hoc Tukey/Bonferroni/Scheffe/Games-Howell, Kruskal-Wallis, eta2/omega2
# Ref: SPSS Statistics 29, Games & Howell(1976), Cohen(1988)
# ============================================================================

interpret_eta2 <- function(eta2) {
  if (is.na(eta2)) return("indeterminado")
  if (eta2 >= 0.14) return("grande")
  if (eta2 >= 0.06) return("mediano")
  if (eta2 >= 0.01) return("pequeno")
  return("trivial")
}

interpret_epsilon2 <- function(e2) {
  if (is.na(e2)) return("indeterminado")
  if (e2 >= 0.14) return("grande")
  if (e2 >= 0.06) return("mediano")
  if (e2 >= 0.01) return("pequeno")
  return("trivial")
}

# P2-LEVENE-LABEL: esta es la prueba de Levene CLASICA (Levene, 1960),
# basada en desviaciones absolutas respecto de la MEDIA de cada grupo.
# No es Brown-Forsythe (que usa la mediana y es lo que SPSS reporta como
# "based on median"). El nombre "Levene" es correcto para lo que se computa;
# la diferencia queda documentada aqui y en AUDIT/07_VALIDATION_RESULTS.md.
levene_anova <- function(y, grupos) {
  tryCatch({
    grupos <- as.factor(grupos)
    niveles <- levels(grupos)
    z_list <- lapply(niveles, function(g) {
      xi <- y[grupos == g]
      abs(xi - mean(xi, na.rm=TRUE))
    })
    ns <- sapply(z_list, length)
    N  <- sum(ns)
    k  <- length(niveles)
    z_means <- sapply(z_list, mean)
    z_grand  <- mean(unlist(z_list))
    ss_bet <- sum(ns * (z_means - z_grand)^2)
    ss_wit <- sum(sapply(z_list, function(z) sum((z - mean(z))^2)))
    df1 <- k - 1; df2 <- N - k
    F_val <- (ss_bet/df1) / (ss_wit/df2)
    p_val <- pf(F_val, df1, df2, lower.tail=FALSE)
    list(F=round(F_val,3), df1=df1, df2=df2, p=round(p_val,4),
         equal_variances=p_val>=0.05)
  }, error=function(e) list(F=NA,df1=NA,df2=NA,p=NA,equal_variances=TRUE))
}

tukey_hsd <- function(y, grupos, alpha=0.05) {
  tryCatch({
    grupos <- as.factor(grupos)
    fit <- aov(y ~ grupos)
    tk  <- TukeyHSD(fit, conf.level=1-alpha)$grupos
    res <- data.frame(
      comparison = rownames(tk),
      diff       = round(tk[,"diff"], 3),
      ci_lower   = round(tk[,"lwr"],  3),
      ci_upper   = round(tk[,"upr"],  3),
      p_adj      = round(tk[,"p adj"],4),
      significant= tk[,"p adj"] < alpha,
      stringsAsFactors=FALSE
    )
    res
  }, error=function(e) NULL)
}

bonferroni_posthoc <- function(y, grupos, alpha=0.05) {
  tryCatch({
    grupos <- as.factor(grupos)
    niveles <- levels(grupos)
    k <- length(niveles)
    n_comp <- k*(k-1)/2
    res <- data.frame()
    for (i in 1:(k-1)) {
      for (j in (i+1):k) {
        g1 <- niveles[i]; g2 <- niveles[j]
        x1 <- y[grupos==g1]; x2 <- y[grupos==g2]
        tt <- t.test(x1, x2, var.equal=TRUE)
        p_adj <- min(1, tt$p.value * n_comp)
        res <- rbind(res, data.frame(
          comparison=paste0(g1," - ",g2),
          diff=round(mean(x1)-mean(x2),3),
          ci_lower=round(tt$conf.int[1],3), ci_upper=round(tt$conf.int[2],3),
          p_adj=round(p_adj,4), significant=p_adj<alpha, stringsAsFactors=FALSE))
      }
    }
    res
  }, error=function(e) NULL)
}

scheffe_posthoc <- function(y, grupos, alpha=0.05) {
  tryCatch({
    grupos <- as.factor(grupos)
    niveles <- levels(grupos)
    k <- length(niveles)
    fit <- aov(y ~ grupos)
    ms_within <- summary(fit)[[1]]["Residuals","Mean Sq"]
    df_within <- summary(fit)[[1]]["Residuals","Df"]
    f_crit <- qf(1-alpha, k-1, df_within)
    res <- data.frame()
    for (i in 1:(k-1)) {
      for (j in (i+1):k) {
        g1 <- niveles[i]; g2 <- niveles[j]
        x1 <- y[grupos==g1]; x2 <- y[grupos==g2]
        n1 <- length(x1); n2 <- length(x2)
        diff_m <- mean(x1)-mean(x2)
        se_diff <- sqrt(ms_within*(1/n1+1/n2))
        scheffe_stat <- diff_m / se_diff
        f_stat <- scheffe_stat^2/(k-1)
        p_val <- pf(f_stat, k-1, df_within, lower.tail=FALSE)
        ci_half <- sqrt((k-1)*f_crit)*se_diff
        res <- rbind(res, data.frame(
          comparison=paste0(g1," - ",g2),
          diff=round(diff_m,3),
          ci_lower=round(diff_m-ci_half,3), ci_upper=round(diff_m+ci_half,3),
          p_adj=round(p_val,4), significant=p_val<alpha, stringsAsFactors=FALSE))
      }
    }
    res
  }, error=function(e) NULL)
}

games_howell <- function(y, grupos, alpha=0.05) {
  tryCatch({
    grupos <- as.factor(grupos)
    niveles <- levels(grupos)
    k <- length(niveles)
    stats <- lapply(niveles, function(g) {
      xi <- y[grupos==g & !is.na(y)]
      list(n=length(xi), mean=mean(xi), var=var(xi))
    })
    names(stats) <- niveles
    res <- data.frame()
    for (i in 1:(k-1)) {
      for (j in (i+1):k) {
        g1 <- niveles[i]; g2 <- niveles[j]
        s1 <- stats[[g1]]; s2 <- stats[[g2]]
        diff_m <- s1$mean - s2$mean
        se_diff <- sqrt(s1$var/s1$n + s2$var/s2$n)
        df_gh   <- (s1$var/s1$n + s2$var/s2$n)^2 /
                   ((s1$var/s1$n)^2/(s1$n-1) + (s2$var/s2$n)^2/(s2$n-1))
        t_val   <- diff_m / se_diff
        # P2-GH-P: Games-Howell usa la distribucion del rango estudentizado
        # (q = t*sqrt(2), Games & Howell 1976), igual que el IC de abajo.
        # Antes se usaba 2*pt() (Welch pareado SIN ajuste por familia), lo que
        # podia contradecir al IC basado en qtukey.
        p_val   <- ptukey(abs(t_val) * sqrt(2), nmeans=k, df=df_gh, lower.tail=FALSE)
        q_crit  <- qtukey(1-alpha, k, df_gh) / sqrt(2)
        ci_half <- q_crit * se_diff
        res <- rbind(res, data.frame(
          comparison  = paste0(g1," - ",g2),
          diff        = round(diff_m,3),
          ci_lower    = round(diff_m - ci_half, 3),
          ci_upper    = round(diff_m + ci_half, 3),
          p_adj       = round(p_val,4),
          significant = p_val < alpha,
          stringsAsFactors=FALSE
        ))
      }
    }
    res
  }, error=function(e) NULL)
}

dunn_posthoc <- function(y, grupos, alpha=0.05) {
  tryCatch({
    grupos <- as.factor(grupos)
    niveles <- levels(grupos)
    N <- length(y)
    k2 <- length(niveles)
    comparisons <- list()
    for (i in 1:(k2-1)) {
      for (j in (i+1):k2) {
        g1 <- niveles[i]; g2 <- niveles[j]
        y1 <- rank(y)[grupos==g1]; y2 <- rank(y)[grupos==g2]
        n1 <- length(y1); n2 <- length(y2)
        z  <- (mean(y1)-mean(y2)) / sqrt((N*(N+1)/12)*(1/n1+1/n2))
        p  <- 2*pnorm(abs(z), lower.tail=FALSE)
        comparisons[[length(comparisons)+1]] <- list(
          comparison=paste0(g1," - ",g2), z=round(z,3), p_raw=round(p,4))
      }
    }
    n_comp <- length(comparisons)
    for (i in seq_along(comparisons)) {
      comparisons[[i]]$p_bonf <- round(min(1, comparisons[[i]]$p_raw * n_comp), 4)
      comparisons[[i]]$significant <- comparisons[[i]]$p_bonf < alpha
    }
    comparisons
  }, error=function(e) NULL)
}

kruskal_wallis_test <- function(y, grupos, alpha=0.05) {
  grupos <- as.factor(grupos)
  test   <- kruskal.test(y ~ grupos)
  N      <- length(y)
  k      <- nlevels(grupos)
  H      <- as.numeric(test$statistic)
  epsilon2 <- H / ((N^2 - 1) / (N + 1))
  sig    <- test$p.value < alpha

  desc <- lapply(levels(grupos), function(g) {
    xi <- y[grupos==g & !is.na(y)]
    list(group=g, n=length(xi), median=round(median(xi),3),
         iqr=round(IQR(xi),3), mean=round(mean(xi),3))
  })

  dunn_res <- dunn_posthoc(y, grupos, alpha)

  list(
    test_type    = "kruskal_wallis",
    H            = round(H, 4),
    df           = test$parameter,
    p            = round(test$p.value, 4),
    p_apa        = if(test$p.value<.001)"< .001" else paste0("= ",formatC(test$p.value,digits=3,format="f")),
    epsilon2     = round(epsilon2, 3),
    epsilon2_interpret = interpret_epsilon2(epsilon2),
    descriptives = desc,
    posthoc      = dunn_res,
    posthoc_method = "Dunn (correccion Bonferroni)",
    significant  = sig,
    decision     = if(sig)"Se rechaza H0" else "No se rechaza H0",
    alpha        = alpha
  )
}

compute_anova <- function(y, grupos, alpha=0.05, force_nonparametric=FALSE, posthoc="tukey", effect_size="eta2", levene="yes") {
  y      <- as.numeric(unlist(y))
  grupos <- as.character(unlist(grupos))
  valid  <- !is.na(y) & !is.na(grupos) & grupos != ""
  y      <- y[valid]; grupos <- grupos[valid]
  niveles <- unique(grupos)
  k       <- length(niveles)

  if (k < 2) return(list(error="Se necesitan al menos 2 grupos"))
  if (length(y) < k*3) return(list(error="Muestra insuficiente por grupo"))

  norm_list <- lapply(niveles, function(g) {
    xi <- y[grupos==g]
    sw <- tryCatch(shapiro.test(xi), error=function(e) list(statistic=NA,p.value=1))
    list(group=g, n=length(xi), W=round(sw$statistic,4),
         p=round(sw$p.value,4), normal=sw$p.value>=alpha)
  })
  all_normal <- all(sapply(norm_list, function(x) x$normal))

  lev <- if(levene=="yes") levene_anova(y, grupos) else list(F=NA,df1=NA,df2=NA,p=NA,equal_variances=TRUE)

  if (force_nonparametric || !all_normal) {
    res <- kruskal_wallis_test(y, grupos, alpha)
    res$normality <- norm_list
    res$levene    <- lev
    res$auto_selected <- "Kruskal-Wallis (distribucion no normal)"
    return(res)
  }

  fit <- aov(y ~ as.factor(grupos))
  sm  <- summary(fit)[[1]]
  N   <- length(y)
  ss_between <- sm[1,"Sum Sq"]
  ss_within  <- sm[2,"Sum Sq"]
  ss_total   <- ss_between + ss_within
  df_between <- sm[1,"Df"]
  df_within  <- sm[2,"Df"]
  F_val      <- sm[1,"F value"]
  p_val      <- sm[1,"Pr(>F)"]
  ms_within_v<- ss_within/df_within
  eta2       <- ss_between / ss_total
  eta2_part  <- ss_between / (ss_between + ss_within)
  omega2     <- (ss_between - df_between*ms_within_v) / (ss_total + ms_within_v)
  if (is.na(omega2) || omega2 < 0) omega2 <- 0
  sig        <- p_val < alpha

  desc <- lapply(niveles, function(g) {
    xi <- y[grupos==g]
    list(group=g, n=length(xi), mean=round(mean(xi),3),
         sd=round(sd(xi),3), se=round(sd(xi)/sqrt(length(xi)),3))
  })

  # Post-hoc segun seleccion real del usuario, con fallback automatico por Levene si es "auto"
  posthoc_choice <- tolower(as.character(posthoc))
  if (posthoc_choice %in% c("auto","")) {
    posthoc_choice <- if (lev$equal_variances) "tukey" else "games_howell"
  }
  posthoc_result <- switch(posthoc_choice,
    "tukey"        = tukey_hsd(y, grupos, alpha),
    "bonferroni"   = bonferroni_posthoc(y, grupos, alpha),
    "scheffe"      = scheffe_posthoc(y, grupos, alpha),
    "games_howell" = games_howell(y, grupos, alpha),
    "games-howell" = games_howell(y, grupos, alpha),
    tukey_hsd(y, grupos, alpha)
  )
  posthoc_method <- switch(posthoc_choice,
    "tukey"        = "Tukey HSD",
    "bonferroni"   = "Bonferroni",
    "scheffe"      = "Scheffe",
    "games_howell" = "Games-Howell (Welch)",
    "games-howell" = "Games-Howell (Welch)",
    "Tukey HSD"
  )

  list(
    test_type      = "anova",
    auto_selected  = paste0("ANOVA + ", posthoc_method),
    F              = round(F_val, 4),
    df_between     = df_between,
    df_within      = df_within,
    p              = round(p_val, 4),
    p_apa          = if(p_val<.001)"< .001" else paste0("= ",formatC(p_val,digits=3,format="f")),
    ss_between     = round(ss_between, 3),
    ss_within      = round(ss_within, 3),
    ss_total       = round(ss_total, 3),
    ms_between     = round(ss_between/df_between, 3),
    ms_within      = round(ss_within/df_within, 3),
    eta2           = round(eta2, 3),
    eta2_interpret = interpret_eta2(eta2),
    eta2_partial   = round(eta2_part, 3),
    omega2         = round(omega2, 3),
    omega2_interpret = interpret_eta2(omega2),
    effect_size_requested = effect_size,
    normality      = norm_list,
    levene         = lev,
    descriptives   = desc,
    posthoc        = posthoc_result,
    posthoc_method = posthoc_method,
    significant    = sig,
    decision       = if(sig)"Se rechaza H0" else "No se rechaza H0",
    alpha          = alpha
  )
}
