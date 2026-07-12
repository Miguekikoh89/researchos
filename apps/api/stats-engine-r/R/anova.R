# ============================================================================
# ResearchOS — ANOVA de un factor
# ANOVA clasico, Welch ANOVA, Levene, post-hoc Tukey/Games-Howell,
# Kruskal-Wallis, eta2, omega2
# Ref: SPSS Statistics 29, Games & Howell(1976), Cohen(1988),
#      Richardson(2011) para omega2 Welch
# CORRECCIONES 2026-07-12:
#   - Welch ANOVA real via oneway.test() cuando Levene detecta desigualdad
#   - median añadida a descriptivos por grupo
#   - p_adj_apa en games_howell (formato APA < .001)
#   - omega2_welch calculado y devuelto
#   - welch_mode flag para que el frontend renderice correctamente
# ============================================================================

interpret_eta2 <- function(eta2) {
  if (is.na(eta2) || is.null(eta2)) return("indeterminado")
  if (eta2 >= 0.14) return("grande")
  if (eta2 >= 0.06) return("mediano")
  if (eta2 >= 0.01) return("pequeno")
  return("trivial")
}

interpret_epsilon2 <- function(e2) {
  if (is.na(e2) || is.null(e2)) return("indeterminado")
  if (e2 >= 0.14) return("grande")
  if (e2 >= 0.06) return("mediano")
  if (e2 >= 0.01) return("pequeno")
  return("trivial")
}

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
      p_adj_apa  = sapply(tk[,"p adj"], function(p)
                     if (p < .001) "< .001" else sub("^0\\.", ".", sprintf("%.3f", p))),
      significant= tk[,"p adj"] < alpha,
      stringsAsFactors=FALSE
    )
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
        p_val   <- 2 * pt(abs(t_val), df_gh, lower.tail=FALSE)
        q_crit  <- qtukey(1-alpha, k, df_gh) / sqrt(2)
        ci_half <- q_crit * se_diff
        p_apa   <- if (p_val < .001) "< .001" else
                   sub("^0\\.", ".", sprintf("%.3f", p_val))
        res <- rbind(res, data.frame(
          comparison  = paste0(g1," - ",g2),
          diff        = round(diff_m,3),
          ci_lower    = round(diff_m - ci_half, 3),
          ci_upper    = round(diff_m + ci_half, 3),
          p_adj       = round(p_val, 4),
          p_adj_apa   = p_apa,
          significant = p_val < alpha,
          stringsAsFactors=FALSE
        ))
      }
    }
    res
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
    list(group=g, n=length(xi),
         median = round(median(xi), 3),
         iqr    = round(IQR(xi),    3),
         mean   = round(mean(xi),   3),
         sd     = round(sd(xi),     3))
  })

  dunn_res <- tryCatch({
    niveles <- levels(grupos)
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
      p_bonf <- min(1, comparisons[[i]]$p_raw * n_comp)
      comparisons[[i]]$p_bonf     <- round(p_bonf, 4)
      comparisons[[i]]$p_bonf_apa <- if (p_bonf < .001) "< .001" else
                                      sub("^0\\.", ".", sprintf("%.3f", p_bonf))
      comparisons[[i]]$significant <- p_bonf < alpha
    }
    comparisons
  }, error=function(e) NULL)

  list(
    test_type    = "kruskal_wallis",
    welch_mode   = FALSE,
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

compute_anova <- function(y, grupos, alpha=0.05, force_nonparametric=FALSE) {
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

  lev <- levene_anova(y, grupos)

  if (force_nonparametric || !all_normal) {
    res <- kruskal_wallis_test(y, grupos, alpha)
    res$normality <- norm_list
    res$levene    <- lev
    res$auto_selected <- "Kruskal-Wallis (distribucion no normal)"
    return(res)
  }

  if (!lev$equal_variances) {
    welch_fit  <- oneway.test(y ~ as.factor(grupos), var.equal = FALSE)
    F_val      <- as.numeric(welch_fit$statistic)
    df_between <- as.numeric(welch_fit$parameter[1])
    df_within  <- as.numeric(welch_fit$parameter[2])
    p_val      <- welch_fit$p.value
    ss_between <- NA; ss_within <- NA; ss_total <- NA
    ms_between <- NA; ms_within <- NA
    eta2       <- NA; eta2_part <- NA
    omega2_w   <- max(0, (F_val - 1) / (F_val + (df_within + 1) / df_between))
    welch_mode <- TRUE
  } else {
    welch_mode <- FALSE
    fit <- aov(y ~ as.factor(grupos))
    sm  <- summary(fit)[[1]]
    ss_between <- sm[1,"Sum Sq"]; ss_within <- sm[2,"Sum Sq"]
    ss_total   <- ss_between + ss_within
    df_between <- sm[1,"Df"];    df_within  <- sm[2,"Df"]
    ms_between <- round(ss_between/df_between, 3)
    ms_within  <- round(ss_within/df_within,   3)
    F_val      <- sm[1,"F value"]
    p_val      <- sm[1,"Pr(>F)"]
    eta2       <- ss_between / ss_total
    eta2_part  <- ss_between / (ss_between + ss_within)
    omega2_w   <- NA
  }
  N   <- length(y)
  sig <- p_val < alpha

  desc <- lapply(niveles, function(g) {
    xi <- y[grupos==g]
    list(group  = g,
         n      = length(xi),
         mean   = round(mean(xi),   3),
         sd     = round(sd(xi),     3),
         median = round(median(xi), 3),
         se     = round(sd(xi)/sqrt(length(xi)), 3))
  })

  if (lev$equal_variances) {
    posthoc <- tukey_hsd(y, grupos, alpha)
    posthoc_method <- "Tukey HSD (varianzas iguales)"
  } else {
    posthoc <- games_howell(y, grupos, alpha)
    posthoc_method <- "Games-Howell (varianzas desiguales)"
  }

  list(
    test_type      = "anova",
    welch_mode     = welch_mode,
    auto_selected  = if (welch_mode) "Welch ANOVA + Games-Howell"
                     else if (lev$equal_variances) "ANOVA + Tukey HSD"
                     else "ANOVA + Games-Howell",
    F              = round(F_val, 4),
    df_between     = round(df_between, 4),
    df_within      = round(df_within,  4),
    p              = round(p_val, 4),
    p_apa          = if(p_val<.001)"< .001" else paste0("= ",formatC(p_val,digits=3,format="f")),
    ss_between     = if (!is.na(ss_between)) round(ss_between, 3) else NULL,
    ss_within      = if (!is.na(ss_within))  round(ss_within,  3) else NULL,
    ss_total       = if (!is.na(ss_total))   round(ss_total,   3) else NULL,
    ms_between     = if (!is.na(ms_between)) ms_between else NULL,
    ms_within      = if (!is.na(ms_within))  ms_within  else NULL,
    eta2           = if (!is.na(eta2)) round(eta2, 3) else NULL,
    eta2_interpret = if (!is.na(eta2)) interpret_eta2(eta2) else NULL,
    eta2_partial   = if (!is.na(eta2_part)) round(eta2_part, 3) else NULL,
    omega2_welch   = if (!is.na(omega2_w)) round(omega2_w, 3) else NULL,
    omega2_welch_interpret = if (!is.na(omega2_w)) interpret_eta2(omega2_w) else NULL,
    normality      = norm_list,
    levene         = lev,
    descriptives   = desc,
    posthoc        = posthoc,
    posthoc_method = posthoc_method,
    significant    = sig,
    decision       = if(sig)"Se rechaza H0" else "No se rechaza H0",
    alpha          = alpha
  )
}
