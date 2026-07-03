# ResearchOS - Regresion Jerarquica
options(encoding="UTF-8")
run_hierarchical_regression <- function(df, blocks, var_b_items, var_b_name, alpha=0.05, hier_method="enter") {
  tryCatch({
    score_b <- if(length(var_b_items)>1) rowMeans(df[,var_b_items,drop=FALSE],na.rm=TRUE) else df[[var_b_items]]

    models <- list()
    results <- list()
    method_l <- tolower(as.character(hier_method))

    all_predictors <- c()
    n_total <- nrow(df)
    for(i in seq_along(blocks)) {
      block <- blocks[[i]]
      # block$items llega como lista R (no vector) cuando se parsea desde JSON
      # con simplifyVector=FALSE; unlist() lo normaliza a vector de caracteres,
      # igual que se hace con var_a/var_b$items en run_analysis.R.
      block_items <- as.character(unlist(block$items))
      block_name <- as.character(block$name)
      score_pred <- if(length(block_items)>1) rowMeans(df[,block_items,drop=FALSE],na.rm=TRUE) else df[[block_items]]
      colname <- paste0("bloque_",i)
      df[[colname]] <- score_pred
      all_predictors <- c(all_predictors, colname)

      formula_str <- paste("score_b ~", paste(all_predictors, collapse=" + "))
      mod_enter <- lm(as.formula(formula_str), data=df)

      if (method_l == "stepwise" && length(all_predictors) > 1) {
        mod <- step(mod_enter, direction="both", trace=0)
      } else {
        mod <- mod_enter
      }
      models[[i]] <- mod

      r2 <- summary(mod)$r.squared
      r2_adj <- summary(mod)$adj.r.squared
      f_stat <- summary(mod)$fstatistic
      p_val <- pf(f_stat[1], f_stat[2], f_stat[3], lower.tail=FALSE)

      delta_r2 <- if(i==1) r2 else r2 - summary(models[[i-1]])$r.squared

      # F de cambio (F change) - prueba de significancia del incremento en R2
      f_change <- NA; df1_change <- NA; df2_change <- NA; p_change <- NA
      if (i > 1) {
        k_prev <- length(coef(models[[i-1]])) - 1
        k_curr <- length(coef(mod)) - 1
        df1_change <- k_curr - k_prev
        df2_change <- nobs(mod) - k_curr - 1
        if (df1_change > 0 && df2_change > 0) {
          f_change <- ((r2 - summary(models[[i-1]])$r.squared) / df1_change) / ((1-r2) / df2_change)
          p_change <- pf(f_change, df1_change, df2_change, lower.tail=FALSE)
        }
      } else {
        f_change <- f_stat[1]; df1_change <- f_stat[2]; df2_change <- f_stat[3]; p_change <- p_val
      }

      results[[i]] <- list(
        block=i, name=block_name,
        r2=round(r2,3), r2_adj=round(r2_adj,3),
        delta_r2=round(delta_r2,3),
        F=round(f_stat[1],3),
        p=round(p_val,4),
        p_apa=if(p_val<.001)"< .001" else paste0("= ",round(p_val,3)),
        f_change=round(f_change,3),
        df1_change=df1_change, df2_change=round(df2_change,1),
        p_change=round(p_change,4),
        p_change_apa=if(!is.na(p_change) && p_change<.001)"< .001" else paste0("= ",round(p_change,3)),
        significant_change=!is.na(p_change) && p_change<alpha,
        significant=p_val<alpha,
        predictors=block_name
      )
    }

    final_mod <- models[[length(models)]]
    coef_sum <- summary(final_mod)$coefficients
    coefs <- lapply(rownames(coef_sum)[-1], function(nm) {
      list(term=nm, B=round(coef_sum[nm,1],3), SE=round(coef_sum[nm,2],3),
           t=round(coef_sum[nm,3],3), p=round(coef_sum[nm,4],4),
           p_apa=if(coef_sum[nm,4]<.001)"< .001" else paste0("= ",round(coef_sum[nm,4],3)),
           significant=coef_sum[nm,4]<alpha)
    })

    list(
      n=nobs(models[[length(models)]]), var_b=var_b_name,
      method_used=method_l,
      blocks=results,
      final_coefficients=coefs,
      final_r2=round(summary(final_mod)$r.squared,3),
      final_r2_adj=round(summary(final_mod)$adj.r.squared,3)
    )
  }, error=function(e) list(error=e$message))
}
