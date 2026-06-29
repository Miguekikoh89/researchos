# ResearchOS - Analisis Discriminante
options(encoding="UTF-8")
run_discriminant <- function(df, predictor_items, group_var, alpha=0.05, method="simultaneo", cv="no") {
  tryCatch({
    if(!requireNamespace("MASS",quietly=TRUE))
      stop("El paquete 'MASS' es necesario para el analisis discriminante.")

    predictors <- df[,predictor_items,drop=FALSE]
    grupo <- as.factor(df[[group_var]])
    datos <- data.frame(predictors, grupo=grupo)
    datos <- datos[complete.cases(datos),]
    n <- nrow(datos)

    method_l <- tolower(as.character(method))
    use_stepwise <- method_l %in% c("stepwise","paso a paso")

    selected_vars <- predictor_items
    if (use_stepwise) {
      tryCatch({
        if(!requireNamespace("klaR",quietly=TRUE))
          stop("El paquete 'klaR' es necesario para el analisis discriminante paso a paso.")
        sw <- klaR::stepclass(grupo ~ ., data=datos, method="lda", criterion="AC", improvement=0.01)
        selected_vars <- sw$model$model[-1]
        if (length(selected_vars) < 1) selected_vars <- predictor_items
      }, error=function(e) { selected_vars <<- predictor_items })
    }

    datos_sel <- datos[, c(selected_vars, "grupo"), drop=FALSE]
    lda_mod <- MASS::lda(grupo ~ ., data=datos_sel)
    pred <- predict(lda_mod, datos_sel)

    tabla_conf <- table(Real=datos_sel$grupo, Predicho=pred$class)
    precision <- sum(diag(tabla_conf))/sum(tabla_conf)

    eig <- lda_mod$svd^2
    var_exp <- round(eig/sum(eig)*100, 1)

    coefs <- as.data.frame(lda_mod$scaling)
    coef_list <- lapply(rownames(coefs), function(nm) {
      row <- as.list(round(coefs[nm,],3))
      row$variable <- nm
      row
    })

    wilks <- 1/prod(1+eig)
    k_pred <- length(selected_vars)
    g_groups <- nlevels(datos_sel$grupo)
    df1_wilks <- k_pred * (g_groups-1)
    chi2_wilks <- -(n - 1 - (k_pred + g_groups)/2) * log(wilks)
    p_wilks <- pchisq(chi2_wilks, df=df1_wilks, lower.tail=FALSE)

    # Validacion cruzada Leave-One-Out
    cv_result <- NULL
    do_cv <- tolower(as.character(cv)) %in% c("yes","si","true","1")
    if (do_cv) {
      lda_cv <- MASS::lda(grupo ~ ., data=datos_sel, CV=TRUE)
      tabla_cv <- table(Real=datos_sel$grupo, Predicho=lda_cv$class)
      precision_cv <- sum(diag(tabla_cv))/sum(tabla_cv)
      cv_result <- list(
        precision_cv=round(precision_cv*100,1),
        confusion_matrix_cv=as.list(as.data.frame(tabla_cv))
      )
    }

    list(
      n=n, group_var=group_var,
      method_used=if(use_stepwise) "Paso a paso (stepwise)" else "Simultaneo (directo)",
      selected_variables=selected_vars,
      n_functions=length(eig),
      eigenvalues=round(eig,3),
      variance_explained=var_exp,
      wilks_lambda=round(wilks,4),
      wilks_chi2=round(chi2_wilks,3),
      wilks_df=df1_wilks,
      wilks_p=round(p_wilks,4),
      wilks_significant=p_wilks<alpha,
      precision=round(precision*100,1),
      confusion_matrix=as.list(as.data.frame(tabla_conf)),
      coefficients=coef_list,
      groups=levels(datos_sel$grupo),
      cross_validation=cv_result,
      decision=paste0("El modelo discriminante clasifica correctamente el ",round(precision*100,1),"% de los casos. Wilks Lambda = ",round(wilks,4)," (",if(p_wilks<alpha)"significativo" else "no significativo",", p ",if(p_wilks<.001)"< .001" else paste0("= ",round(p_wilks,3)),")")
    )
  }, error=function(e) list(error=e$message))
}
