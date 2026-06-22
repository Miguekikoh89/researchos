# ResearchOS - ANCOVA
options(encoding="UTF-8")
run_ancova <- function(df, dep_items, group_var, covariate_items, dep_name, alpha=0.05, posthoc="bonferroni", check_slopes="yes") {
  tryCatch({
    dep <- if(length(dep_items)>1) rowMeans(df[,dep_items,drop=FALSE],na.rm=TRUE) else df[[dep_items]]
    cov_score <- if(length(covariate_items)>1) rowMeans(df[,covariate_items,drop=FALSE],na.rm=TRUE) else df[[covariate_items]]
    grupo <- as.factor(df[[group_var]])

    datos <- data.frame(dep=dep, grupo=grupo, covariable=cov_score)
    datos <- datos[complete.cases(datos),]

    mod_ancova <- lm(dep ~ covariable + grupo, data=datos)
    mod_anova  <- lm(dep ~ grupo, data=datos)

    anc_table <- anova(mod_ancova)

    library(emmeans)
    emm <- emmeans(mod_ancova, "grupo")
    medias_adj <- as.data.frame(emm)

    r2_ancova <- summary(mod_ancova)$r.squared
    r2_anova  <- summary(mod_anova)$r.squared

    rows <- lapply(rownames(anc_table), function(nm) {
      list(source=nm, SS=round(anc_table[nm,"Sum Sq"],3),
           df=anc_table[nm,"Df"], MS=round(anc_table[nm,"Mean Sq"],3),
           F=round(anc_table[nm,"F value"],3),
           p=round(anc_table[nm,"Pr(>F)"],4),
           p_apa=if(!is.na(anc_table[nm,"Pr(>F)"]) && anc_table[nm,"Pr(>F)"]<.001)"< .001" else paste0("= ",round(anc_table[nm,"Pr(>F)"],3)))
    })

    adj_means <- lapply(seq_len(nrow(medias_adj)), function(i) {
      list(group=as.character(medias_adj$grupo[i]),
           mean_adj=round(medias_adj$emmean[i],3),
           se=round(medias_adj$SE[i],3),
           ci_lower=round(medias_adj$lower.CL[i],3),
           ci_upper=round(medias_adj$upper.CL[i],3))
    })

    # Homogeneidad de pendientes de regresion (supuesto critico de ANCOVA)
    slopes_test <- tryCatch({
      mod_interact <- lm(dep ~ covariable * grupo, data=datos)
      anc_interact <- anova(mod_interact)
      interact_row <- grep(":", rownames(anc_interact), value=TRUE)
      if (length(interact_row) > 0) {
        p_int <- anc_interact[interact_row[1], "Pr(>F)"]
        f_int <- anc_interact[interact_row[1], "F value"]
        list(F=round(f_int,3), p=round(p_int,4), ok=p_int>=0.05,
             interpretation=if(p_int<0.05) "Se viola el supuesto: las pendientes de regresion difieren entre grupos" else "Supuesto de homogeneidad de pendientes cumplido")
      } else list(F=NA,p=NA,ok=TRUE,interpretation="No calculado")
    }, error=function(e) list(F=NA,p=NA,ok=TRUE,interpretation="No calculado"))

    # Post-hoc sobre medias ajustadas (pairs de emmeans)
    posthoc_method_l <- tolower(as.character(posthoc))
    adj_method <- switch(posthoc_method_l, "bonferroni"="bonferroni", "tukey"="tukey", "scheffe"="scheffe", "none"="none", "bonferroni")
    posthoc_pairs <- tryCatch({
      pw <- pairs(emm, adjust=adj_method)
      pw_df <- as.data.frame(pw)
      lapply(seq_len(nrow(pw_df)), function(i) list(
        comparison=as.character(pw_df$contrast[i]),
        estimate=round(pw_df$estimate[i],3),
        se=round(pw_df$SE[i],3),
        t=round(pw_df$t.ratio[i],3),
        p_adj=round(pw_df$p.value[i],4),
        significant=pw_df$p.value[i]<alpha
      ))
    }, error=function(e) NULL)

    grupo_p <- anc_table["grupo","Pr(>F)"]
    list(
      n=nrow(datos), dep_var=dep_name, group_var=group_var,
      ancova_table=rows,
      adjusted_means=adj_means,
      posthoc_adjusted_means=posthoc_pairs,
      posthoc_method=adj_method,
      homogeneity_slopes=slopes_test,
      r2_ancova=round(r2_ancova,3),
      r2_anova=round(r2_anova,3),
      r2_improvement=round(r2_ancova-r2_anova,3),
      significant=!is.na(grupo_p) && grupo_p<alpha,
      p_grupo=round(grupo_p,4),
      decision=if(!is.na(grupo_p) && grupo_p<alpha) paste0("Existen diferencias significativas en ",dep_name," entre grupos, controlando la covariable (p < ",alpha,")") else paste0("No existen diferencias significativas entre grupos al controlar la covariable")
    )
  }, error=function(e) list(error=e$message))
}
