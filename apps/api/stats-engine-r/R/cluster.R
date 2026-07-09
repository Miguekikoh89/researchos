# CanchariOS - Análisis clúster K-means reproducible
options(encoding="UTF-8")
run_cluster <- function(df, items, n_clusters=3, var_name="Variable", standardize="yes", seed=42) {
  tryCatch({
    items<-as.character(unlist(items));if(length(items)<1||!all(items%in%names(df)))stop("Ítems no encontrados.")
    datos<-as.data.frame(lapply(df[,items,drop=FALSE],function(x)suppressWarnings(as.numeric(x))))
    datos<-datos[complete.cases(datos),,drop=FALSE];n<-nrow(datos);k<-suppressWarnings(as.integer(n_clusters)[1])
    if(!is.finite(k)||k<2||k>=n)return(list(blocked=TRUE,reason="NUMERO_CLUSTERS_INVALIDO",error=paste0("n_clusters debe ser entero entre 2 y ",max(1,n-1),".")))
    if(n<5)return(list(blocked=TRUE,reason="MUESTRA_INSUFICIENTE",error="Se requieren al menos 5 casos completos."))
    vars<-vapply(datos,var,numeric(1));if(any(!is.finite(vars)|vars<=0))return(list(blocked=TRUE,reason="VARIABLE_CONSTANTE",error=paste0("Variables sin varianza: ",paste(names(vars)[!is.finite(vars)|vars<=0],collapse=", "))))
    use_std<-tolower(as.character(standardize))%in%c("yes","si","true","1");datos_scaled<-if(use_std)scale(datos)else as.matrix(datos)
    had<-exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE);if(had)old<-get(".Random.seed",envir=.GlobalEnv);on.exit({if(had)assign(".Random.seed",old,envir=.GlobalEnv)else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))rm(".Random.seed",envir=.GlobalEnv)},add=TRUE);set.seed(as.integer(seed))
    km<-kmeans(datos_scaled,centers=k,nstart=25,algorithm="Hartigan-Wong")
    if(any(tabulate(km$cluster,nbins=k)<2))return(list(blocked=TRUE,reason="CLUSTER_DEGENERADO",error="Al menos un clúster tiene menos de 2 casos; la solución no es estable para describir."))
    if(!requireNamespace("cluster",quietly=TRUE))stop("El paquete cluster es obligatorio.")
    sil<-cluster::silhouette(km$cluster,dist(datos_scaled));sil_raw<-mean(sil[,3])
    df_cl<-datos;df_cl$cluster<-km$cluster
    cluster_desc<-lapply(seq_len(k),function(z){sub<-df_cl[df_cl$cluster==z,items,drop=FALSE];sc<-rowMeans(sub);list(cluster=z,n=nrow(sub),pct=round(100*nrow(sub)/n,1),mean=round(mean(sc),2),sd=round(sd(sc),2),label=paste0("Cluster ",z),nivel=NA)})
    means_vec<-sapply(cluster_desc,function(x)x$mean);ranks<-rank(means_vec,ties.method="first");nivel_labels<-if(k==2)c("Bajo","Alto")else if(k==3)c("Bajo","Medio","Alto")else paste0("Nivel ",seq_len(k));cluster_desc<-lapply(seq_len(k),function(z){cd<-cluster_desc[[z]];cd$nivel<-nivel_labels[ranks[z]];cd})
    max_k<-min(6L,n-1L);elbow<-sapply(seq_len(max_k),function(kk){set.seed(as.integer(seed));kmeans(datos_scaled,centers=kk,nstart=10)$tot.withinss})
    list(var_name=var_name,n=n,n_clusters=k,standardize_used=use_std,centers_scale=if(use_std)"z_scores"else"original",seed_used=as.integer(seed),
      silhouette=round(sil_raw,3),silhouette_raw=sil_raw,silhouette_interpret=if(sil_raw>.7)"Estructura fuerte"else if(sil_raw>.5)"Estructura razonable"else if(sil_raw>.25)"Estructura débil"else"Sin estructura clara",
      within_ss=round(km$tot.withinss,3),within_ss_raw=km$tot.withinss,between_ss=round(km$betweenss,3),between_ss_raw=km$betweenss,
      elbow_wss=round(elbow,2),clusters=cluster_desc,centers=unname(split(as.data.frame(km$centers),seq_len(nrow(km$centers)))),analysis_status="exploratorio_no_confirmatorio")
  },error=function(e)list(error=conditionMessage(e)))
}
