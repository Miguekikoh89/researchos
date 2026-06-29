# ResearchOS - Regresion Logistica Multinomial
# Archivo NUEVO e independiente. No modifica logistic.R (binaria/ordinal intactas).
options(encoding="UTF-8")

compute_logistic_multinomial <- function(y_raw, X, var_names=NULL, alpha=0.05) {
  tryCatch({
    if (!requireNamespace("nnet", quietly=TRUE))
      stop("El paquete 'nnet' es necesario para la regresion logistica multinomial.")

    if (is.null(var_names)) var_names <- paste0("X", 1:ncol(as.matrix(X)))
    X <- as.data.frame(lapply(as.data.frame(X), function(x) as.numeric(unlist(x))))
    colnames(X) <- var_names

    y_fac <- as.factor(as.character(unlist(y_raw)))
    n_levels <- nlevels(y_fac)
    if (n_levels < 3) {
      return(list(error="La variable dependiente tiene menos de 3 categorias. Use Regresion logistica binaria en su lugar."))
    }

    valid <- complete.cases(y_fac, X)
    y_fac <- y_fac[valid]; X <- X[valid,, drop=FALSE]
    n <- length(y_fac); k <- ncol(X)

    ref_level <- levels(y_fac)[1]
    y_fac <- relevel(y_fac, ref=ref_level)

    df_model <- data.frame(y=y_fac, X)
    model_full <- nnet::multinom(y ~ ., data=df_model, trace=FALSE)
    model_null <- nnet::multinom(y ~ 1, data=df_model, trace=FALSE)

    ll_full <- logLik(model_full)
    ll_null <- logLik(model_null)
    lr_stat <- -2 * (as.numeric(ll_null) - as.numeric(ll_full))
    df_lr <- attr(ll_full, "df") - attr(ll_null, "df")
    p_lr <- pchisq(lr_stat, df=df_lr, lower.tail=FALSE)

    r2_cox_snell <- 1 - exp((2/n) * (as.numeric(ll_null) - as.numeric(ll_full)))
    r2_max <- 1 - exp((2/n) * as.numeric(ll_null))
    r2_nagel <- r2_cox_snell / r2_max

    sm <- summary(model_full)
    coefs_mat <- sm$coefficients
    se_mat <- sm$standard.errors
    if (is.null(dim(coefs_mat))) {
      coefs_mat <- matrix(coefs_mat, nrow=1, dimnames=list(levels(y_fac)[-1], names(coefs_mat)))
      se_mat <- matrix(se_mat, nrow=1, dimnames=list(levels(y_fac)[-1], names(se_mat)))
    }
    z_mat <- coefs_mat / se_mat
    p_mat <- 2 * (1 - pnorm(abs(z_mat)))

    comparisons <- list()
    for (lvl in rownames(coefs_mat)) {
      coefs_lvl <- lapply(colnames(coefs_mat), function(term) {
        b <- coefs_mat[lvl, term]; se <- se_mat[lvl, term]; z <- z_mat[lvl, term]; p <- p_mat[lvl, term]
        or <- exp(b)
        list(term=term, B=round(b,3), SE=round(se,3), z=round(z,3), p=round(p,4),
             p_apa=if(p<.001)"< .001" else paste0("= ", formatC(p, digits=3, format="f")),
             OR=round(or,3), significant=p<alpha)
      })
      comparisons[[length(comparisons)+1]] <- list(level=lvl, vs_reference=ref_level, coefficients=coefs_lvl)
    }

    pred_class <- predict(model_full, df_model)
    tabla_conf <- table(Real=y_fac, Predicho=pred_class)
    precision <- sum(diag(tabla_conf)) / sum(tabla_conf)

    list(
      test_type = "logistica_multinomial",
      n=n, k=k, n_levels=n_levels, reference_level=ref_level,
      levels=levels(y_fac),
      ll_null=round(as.numeric(ll_null),3), ll_full=round(as.numeric(ll_full),3),
      lr_chi2=round(lr_stat,3), lr_df=df_lr, lr_p=round(p_lr,4),
      lr_p_apa=if(p_lr<.001)"< .001" else paste0("= ", formatC(p_lr, digits=3, format="f")),
      r2_cox_snell=round(r2_cox_snell,3), r2_nagelkerke=round(r2_nagel,3),
      comparisons=comparisons,
      precision=round(precision*100,1),
      confusion_matrix=as.list(as.data.frame(tabla_conf)),
      significant=p_lr<alpha,
      decision=if(p_lr<alpha) "El modelo es significativo: los predictores distinguen entre las categorias de la variable dependiente (p < alpha)" else "El modelo no es significativo"
    )
  }, error=function(e) list(error=e$message))
}
