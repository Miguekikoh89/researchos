# ResearchOS - Analisis Cluster K-means
options(encoding="UTF-8")
run_cluster <- function(df, items, n_clusters=3, var_name="Variable", standardize="yes", seed=42) {
  tryCatch({
    datos <- df[,items,drop=FALSE]
    datos <- datos[complete.cases(datos),]
    datos_scaled <- if(tolower(as.character(standardize)) %in% c("yes","si","true","1")) scale(datos) else as.matrix(datos)

    set.seed(as.numeric(seed))
    km <- kmeans(datos_scaled, centers=n_clusters, nstart=25)

    if(!requireNamespace("cluster",quietly=TRUE)) install.packages("cluster",repos="https://cran.r-project.org")
    library(cluster)
    sil <- silhouette(km$cluster, dist(datos_scaled))
    sil_mean <- round(mean(sil[,3]),3)

    df_cl <- as.data.frame(datos)
    df_cl$cluster <- km$cluster

    cluster_desc <- lapply(1:n_clusters, function(k) {
      sub <- df_cl[df_cl$cluster==k, items, drop=FALSE]
      score <- rowMeans(sub, na.rm=TRUE)
      list(
        cluster=k, n=nrow(sub),
        pct=round(nrow(sub)/nrow(df_cl)*100,1),
        mean=round(mean(score,na.rm=TRUE),2),
        sd=round(sd(score,na.rm=TRUE),2),
        label=if(mean(score,na.rm=TRUE)>mean(rowMeans(datos,na.rm=TRUE),na.rm=TRUE)+0.3*sd(rowMeans(datos,na.rm=TRUE),na.rm=TRUE)) "Alto" else if(mean(score,na.rm=TRUE)<mean(rowMeans(datos,na.rm=TRUE),na.rm=TRUE)-0.3*sd(rowMeans(datos,na.rm=TRUE),na.rm=TRUE)) "Bajo" else "Medio"
      )
    })

    elbow <- tryCatch({
      max_k <- min(6, nrow(datos_scaled)-1)
      sapply(1:max_k, function(kk) {
        set.seed(as.numeric(seed))
        kmeans(datos_scaled, centers=kk, nstart=10)$tot.withinss
      })
    }, error=function(e) NULL)

    list(
      var_name=var_name, n=nrow(df_cl),
      n_clusters=n_clusters,
      standardize_used=standardize,
      seed_used=seed,
      silhouette=sil_mean,
      silhouette_interpret=if(sil_mean>0.7)"Estructura fuerte" else if(sil_mean>0.5)"Estructura razonable" else if(sil_mean>0.25)"Estructura debil" else "Sin estructura",
      within_ss=round(km$tot.withinss,3),
      between_ss=round(km$betweenss,3),
      elbow_wss=if(!is.null(elbow)) round(elbow,2) else NULL,
      clusters=cluster_desc
    )
  }, error=function(e) list(error=e$message))
}
