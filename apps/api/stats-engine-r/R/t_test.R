
# CanchariOS — comparación de dos grupos, versión endurecida
options(encoding="UTF-8")

interpret_d <- function(d) {
  a <- abs(d)
  if (!is.finite(a)) return("indeterminado")
  if (a >= 0.80) return("grande")
  if (a >= 0.50) return("mediano")
  if (a >= 0.20) return("pequeno")
  "trivial"
}

validate_group_vector <- function(x, label) {
  x <- suppressWarnings(as.numeric(unlist(x)))
  x <- x[is.finite(x)]
  if (length(x) < 3) stop(paste0(label, ": se requieren al menos 3 observaciones válidas."))
  if (length(unique(x)) < 2 || !is.finite(stats::var(x)) || stats::var(x) <= 0)
    stop(paste0(label, ": la variable es constante o no tiene varianza válida."))
  x
}

independent_effect_size <- function(x1, x2, type="cohend") {
  n1 <- length(x1); n2 <- length(x2)
  diff_m <- mean(x1) - mean(x2)
  pooled <- sqrt(((n1 - 1) * var(x1) + (n2 - 1) * var(x2)) / (n1 + n2 - 2))
  d <- diff_m / pooled
  type <- tolower(trimws(as.character(type)))
  if (type %in% c("hedgesg", "hedges_g", "g")) {
    J <- 1 - 3 / (4 * (n1 + n2 - 2) - 1)
    return(list(value=J*d, name="Hedges g"))
  }
  if (type %in% c("glass", "glassdelta", "glass_delta")) {
    return(list(value=diff_m / sd(x2), name="Glass delta (Grupo 2 como control)"))
  }
  list(value=d, name="Cohen d")
}

paired_effect_size <- function(x1, x2) {
  dif <- x1 - x2
  list(value=mean(dif)/sd(dif), name="Cohen dz")
}

levene_test <- function(x1, x2) {
  tryCatch({
    x1 <- validate_group_vector(x1, "Grupo 1")
    x2 <- validate_group_vector(x2, "Grupo 2")
    n1 <- length(x1); n2 <- length(x2)
    z1 <- abs(x1 - mean(x1)); z2 <- abs(x2 - mean(x2))
    gm <- mean(c(z1, z2))
    ssb <- n1*(mean(z1)-gm)^2 + n2*(mean(z2)-gm)^2
    ssw <- sum((z1-mean(z1))^2) + sum((z2-mean(z2))^2)
    if (!is.finite(ssw) || ssw <= 0) stop("Levene no puede estimarse: varianza de desviaciones nula.")
    F_val <- ssb / (ssw/(n1+n2-2))
    p_val <- pf(F_val, 1, n1+n2-2, lower.tail=FALSE)
    list(ok=TRUE, F=as.numeric(F_val), df1=1, df2=n1+n2-2,
         p=as.numeric(p_val), equal_variances=isTRUE(p_val >= 0.05),
         method="Levene clásico basado en la media")
  }, error=function(e) list(ok=FALSE, F=NA_real_, df1=NA_integer_, df2=NA_integer_,
                            p=NA_real_, equal_variances=NA,
                            error=conditionMessage(e), method="Levene clásico basado en la media"))
}

normality_one_group <- function(x, alpha=0.05) {
  x <- x[is.finite(x)]
  if (length(x) < 3 || length(unique(x)) < 2)
    return(list(W=NA_real_, p=NA_real_, normal=NA, available=FALSE,
                note="Shapiro-Wilk no aplicable"))
  if (length(x) > 5000)
    return(list(W=NA_real_, p=NA_real_, normal=NA, available=FALSE,
                note="Shapiro-Wilk no se aplica para n > 5000"))
  sw <- tryCatch(shapiro.test(x), error=function(e) NULL)
  if (is.null(sw)) return(list(W=NA_real_, p=NA_real_, normal=NA, available=FALSE,
                               note="Shapiro-Wilk no pudo calcularse"))
  list(W=as.numeric(sw$statistic), p=as.numeric(sw$p.value),
       normal=isTRUE(sw$p.value >= alpha), available=TRUE, note=NULL)
}

normality_by_group <- function(x1, x2, alpha=0.05) {
  g1 <- normality_one_group(x1, alpha)
  g2 <- normality_one_group(x2, alpha)
  both <- if (isTRUE(g1$available) && isTRUE(g2$available)) isTRUE(g1$normal && g2$normal) else NA
  list(group1=g1, group2=g2, both_normal=both)
}

t_independent <- function(x1, x2, alpha=0.05, group_names=c("Grupo 1","Grupo 2"),
                          alt="two.sided", levene_opt="yes", effect_size_type="cohend") {
  x1 <- validate_group_vector(x1, group_names[1])
  x2 <- validate_group_vector(x2, group_names[2])
  lev_requested <- tolower(as.character(levene_opt)) %in% c("yes","si","true","1")
  lev <- if (lev_requested) levene_test(x1,x2) else
    list(ok=NA, F=NA_real_,df1=NA_integer_,df2=NA_integer_,p=NA_real_,equal_variances=NA,
         method="No solicitado")
  norm <- normality_by_group(x1,x2,alpha)
  t_eq <- t.test(x1,x2,var.equal=TRUE,alternative=alt,conf.level=1-alpha)
  t_we <- t.test(x1,x2,var.equal=FALSE,alternative=alt,conf.level=1-alpha)
  use_equal <- isTRUE(lev$ok) && isTRUE(lev$equal_variances)
  t_use <- if (use_equal) t_eq else t_we
  selected_reason <- if (!lev_requested) "Welch por política conservadora sin Levene" else
    if (!isTRUE(lev$ok)) "Welch porque Levene no pudo calcularse" else
      if (use_equal) "Student: homogeneidad de varianzas" else "Welch: varianzas desiguales"
  eff <- independent_effect_size(x1,x2,effect_size_type)
  sig <- isTRUE(t_use$p.value < alpha)
  list(
    test_type="t_independiente",
    method_used=if(use_equal) "Student (varianzas iguales)" else "Welch (varianzas desiguales)",
    selection_reason=selected_reason,
    t=as.numeric(t_use$statistic), df=as.numeric(t_use$parameter), p=as.numeric(t_use$p.value),
    p_apa=if(t_use$p.value<.001)"< .001" else paste0("= ",formatC(t_use$p.value,digits=3,format="f")),
    ci_lower=as.numeric(t_use$conf.int[1]), ci_upper=as.numeric(t_use$conf.int[2]),
    mean_diff=mean(x1)-mean(x2),
    t_student=as.numeric(t_eq$statistic), df_student=as.numeric(t_eq$parameter), p_student=as.numeric(t_eq$p.value),
    t_welch=as.numeric(t_we$statistic), df_welch=as.numeric(t_we$parameter), p_welch=as.numeric(t_we$p.value),
    levene=lev, normality=norm,
    d=as.numeric(eff$value), d_interpret=interpret_d(eff$value),
    effect_size=as.numeric(eff$value), effect_size_name=eff$name,
    descriptives=list(
      group1=list(name=group_names[1],n=length(x1),mean=mean(x1),sd=sd(x1),se=sd(x1)/sqrt(length(x1))),
      group2=list(name=group_names[2],n=length(x2),mean=mean(x2),sd=sd(x2),se=sd(x2)/sqrt(length(x2)))),
    significant=sig, decision=if(sig)"Se rechaza H0" else "No se rechaza H0",
    alpha=alpha, hypothesis_type=alt)
}

t_paired <- function(x1,x2,alpha=0.05,group_names=c("Pre","Post"),alt="two.sided") {
  x1 <- suppressWarnings(as.numeric(unlist(x1))); x2 <- suppressWarnings(as.numeric(unlist(x2)))
  if (length(x1) != length(x2)) stop("Las mediciones pareadas deben tener la misma longitud.")
  valid <- is.finite(x1) & is.finite(x2); x1 <- x1[valid]; x2 <- x2[valid]
  if (length(x1) < 3) stop("Se requieren al menos 3 pares completos.")
  dif <- x1-x2
  if (length(unique(dif)) < 2 || sd(dif) == 0) stop("Las diferencias pareadas son constantes.")
  sw <- normality_one_group(dif,alpha)
  t_res <- t.test(x1,x2,paired=TRUE,alternative=alt,conf.level=1-alpha)
  eff <- paired_effect_size(x1,x2); sig <- isTRUE(t_res$p.value<alpha)
  list(test_type="t_pareada",t=as.numeric(t_res$statistic),df=as.numeric(t_res$parameter),p=as.numeric(t_res$p.value),
       p_apa=if(t_res$p.value<.001)"< .001" else paste0("= ",formatC(t_res$p.value,digits=3,format="f")),
       ci_lower=as.numeric(t_res$conf.int[1]),ci_upper=as.numeric(t_res$conf.int[2]),
       mean_diff=mean(dif),sd_diff=sd(dif),se_diff=sd(dif)/sqrt(length(dif)),normality_diff=sw,
       d=as.numeric(eff$value),d_interpret=interpret_d(eff$value),effect_size=as.numeric(eff$value),effect_size_name=eff$name,
       descriptives=list(group1=list(name=group_names[1],n=length(x1),mean=mean(x1),sd=sd(x1)),
                         group2=list(name=group_names[2],n=length(x2),mean=mean(x2),sd=sd(x2))),
       significant=sig,decision=if(sig)"Se rechaza H0" else "No se rechaza H0",alpha=alpha,hypothesis_type=alt)
}

mann_whitney <- function(x1,x2,alpha=0.05,group_names=c("Grupo 1","Grupo 2"),alt="two.sided") {
  x1 <- validate_group_vector(x1,group_names[1]); x2 <- validate_group_vector(x2,group_names[2])
  no_ties <- !anyDuplicated(c(x1,x2)); use_exact <- no_ties && (length(x1)+length(x2) < 50)
  test <- suppressWarnings(wilcox.test(x1,x2,alternative=alt,exact=use_exact,correct=!use_exact,conf.int=TRUE,conf.level=1-alpha))
  U <- as.numeric(test$statistic); r_rb <- (2*U)/(length(x1)*length(x2))-1
  sig <- isTRUE(test$p.value<alpha)
  list(test_type="mann_whitney",U=U,p=as.numeric(test$p.value),
       p_apa=if(test$p.value<.001)"< .001" else paste0("= ",formatC(test$p.value,digits=3,format="f")),
       location_shift_ci_lower=if(length(test$conf.int))as.numeric(test$conf.int[1]) else NA_real_,
       location_shift_ci_upper=if(length(test$conf.int))as.numeric(test$conf.int[2]) else NA_real_,
       ci_note="El IC corresponde al desplazamiento de localización, no al rank-biserial.",
       r_rb=as.numeric(r_rb),r_interpret=interpret_d(r_rb),p_method=if(use_exact)"exact" else "asymptotic",
       descriptives=list(group1=list(name=group_names[1],n=length(x1),median=median(x1),iqr=IQR(x1),mean=mean(x1)),
                         group2=list(name=group_names[2],n=length(x2),median=median(x2),iqr=IQR(x2),mean=mean(x2))),
       significant=sig,decision=if(sig)"Se rechaza H0" else "No se rechaza H0",alpha=alpha,hypothesis_type=alt)
}

wilcoxon_paired <- function(x1,x2,alpha=0.05,group_names=c("Pre","Post"),alt="two.sided") {
  x1 <- suppressWarnings(as.numeric(unlist(x1))); x2 <- suppressWarnings(as.numeric(unlist(x2)))
  if (length(x1) != length(x2)) stop("Las mediciones pareadas deben tener la misma longitud.")
  valid <- is.finite(x1) & is.finite(x2); x1 <- x1[valid]; x2 <- x2[valid]
  dif <- x1-x2; nz <- dif != 0; dif_nz <- dif[nz]
  if (length(dif_nz) < 3) stop("Wilcoxon requiere al menos 3 diferencias no nulas.")
  ranks <- rank(abs(dif_nz),ties.method="average")
  w_plus <- sum(ranks[dif_nz>0]); w_minus <- sum(ranks[dif_nz<0]); total <- w_plus+w_minus
  r_rb <- (w_plus-w_minus)/total
  use_exact <- !anyDuplicated(abs(dif_nz)) && length(dif_nz)<50
  test <- suppressWarnings(wilcox.test(x1,x2,paired=TRUE,alternative=alt,exact=use_exact,correct=!use_exact))
  sig <- isTRUE(test$p.value<alpha)
  list(test_type="wilcoxon_pareado",W=as.numeric(test$statistic),W_plus=w_plus,W_minus=w_minus,
       n_pairs=length(x1),n_nonzero=length(dif_nz),p=as.numeric(test$p.value),
       p_apa=if(test$p.value<.001)"< .001" else paste0("= ",formatC(test$p.value,digits=3,format="f")),
       r_rb=as.numeric(r_rb),r_interpret=interpret_d(r_rb),p_method=if(use_exact)"exact" else "asymptotic",
       descriptives=list(group1=list(name=group_names[1],n=length(x1),median=median(x1),mean=mean(x1)),
                         group2=list(name=group_names[2],n=length(x2),median=median(x2),mean=mean(x2))),
       significant=sig,decision=if(sig)"Se rechaza H0" else "No se rechaza H0",alpha=alpha,hypothesis_type=alt)
}

compute_ttest <- function(x1,x2,type="independiente",alpha=0.05,group_names=c("Grupo 1","Grupo 2"),
                          force_nonparametric=FALSE,hypothesis_type="bilateral",effect_size_type="cohend",levene="yes") {
  if (!is.finite(alpha) || alpha<=0 || alpha>=1) stop("alpha debe estar entre 0 y 1.")
  ht <- tolower(trimws(as.character(hypothesis_type)))
  alt <- if(ht %in% c("unilateral_pos","greater","positiva")) "greater" else
         if(ht %in% c("unilateral_neg","unilateral","less","negativa")) "less" else "two.sided"
  type_l <- tolower(trimws(as.character(type)))
  if (type_l %in% c("pareada","paired")) {
    x1n <- suppressWarnings(as.numeric(unlist(x1))); x2n <- suppressWarnings(as.numeric(unlist(x2)))
    valid <- is.finite(x1n)&is.finite(x2n); dif <- x1n[valid]-x2n[valid]
    if(length(dif)<3) stop("Se requieren al menos 3 pares completos.")
    sw <- normality_one_group(dif,alpha)
    use_nonparam <- isTRUE(force_nonparametric) || (isTRUE(sw$available) && !isTRUE(sw$normal))
    if(!isTRUE(sw$available) && length(dif)<30) use_nonparam <- TRUE
    res <- if(use_nonparam) wilcoxon_paired(x1n,x2n,alpha,group_names,alt) else t_paired(x1n,x2n,alpha,group_names,alt)
    res$auto_selected <- if(use_nonparam)"Wilcoxon pareado" else "t pareada"
  } else {
    x1n <- validate_group_vector(x1,group_names[1]); x2n <- validate_group_vector(x2,group_names[2])
    norm <- normality_by_group(x1n,x2n,alpha)
    robust_large_sample <- length(x1n)>=30 && length(x2n)>=30
    use_nonparam <- isTRUE(force_nonparametric) ||
      (isTRUE(norm$group1$available) && !isTRUE(norm$group1$normal) && !robust_large_sample) ||
      (isTRUE(norm$group2$available) && !isTRUE(norm$group2$normal) && !robust_large_sample)
    res <- if(use_nonparam) mann_whitney(x1n,x2n,alpha,group_names,alt) else
      t_independent(x1n,x2n,alpha,group_names,alt,levene,effect_size_type)
    res$auto_selected <- if(use_nonparam)"Mann-Whitney (diferencias de distribución)" else res$method_used
  }
  res$effect_size_type_used <- effect_size_type
  res
}
