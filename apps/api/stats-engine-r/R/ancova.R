
# CanchariOS — ANCOVA endurecida
options(encoding="UTF-8")
score_min_valid <- function(df,items,prop=.80){m<-df[,items,drop=FALSE];nvalid<-rowSums(!is.na(m));s<-rowMeans(m,na.rm=TRUE);s[nvalid<ceiling(length(items)*prop)]<-NA_real_;s[!is.finite(s)]<-NA_real_;s}
run_ancova <- function(df,dep_items,group_var,covariate_items,dep_name,alpha=.05,posthoc="bonferroni",check_slopes="yes"){
  tryCatch({
    dep_items<-as.character(unlist(dep_items));covariate_items<-as.character(unlist(covariate_items))
    if(!group_var%in%names(df))stop("Variable de grupo no encontrada.")
    if(!all(dep_items%in%names(df))||!all(covariate_items%in%names(df)))stop("Ítems dependientes o covariable no encontrados.")
    dep<-score_min_valid(df,dep_items);covs<-score_min_valid(df,covariate_items);grupo<-droplevels(factor(df[[group_var]]));datos<-data.frame(dep=dep,grupo=grupo,covariable=covs);datos<-datos[complete.cases(datos),]
    if(nrow(datos)<20) return(list(blocked=TRUE,reason="MUESTRA_INSUFICIENTE",error="ANCOVA requiere al menos 20 casos completos."))
    ns<-table(datos$grupo);if(nlevels(datos$grupo)<2||any(ns<5))return(list(blocked=TRUE,reason="GRUPOS_INSUFICIENTES",error=paste0("Se requieren al menos 2 grupos y n >= 5 por grupo. ",paste(names(ns),ns,collapse=", "))))
    mod_main<-lm(dep~covariable+grupo,data=datos)
    slopes_requested<-tolower(as.character(check_slopes))%in%c("yes","si","true","1")
    slopes<-if(slopes_requested)tryCatch({mi<-lm(dep~covariable*grupo,data=datos);cmp<-anova(mod_main,mi);p<-cmp$`Pr(>F)`[2];Fv<-cmp$F[2];list(ok=isTRUE(p>=alpha),F=as.numeric(Fv),p=as.numeric(p),method="Comparación global del término covariable × grupo",interpretation=if(p<alpha)"Se viola la homogeneidad de pendientes"else"Homogeneidad de pendientes compatible con los datos")},error=function(e)list(ok=FALSE,p=NA_real_,F=NA_real_,error=conditionMessage(e)))else list(ok=NA,p=NA,F=NA,method="No solicitado")
    if(slopes_requested&&!isTRUE(slopes$ok))return(list(blocked=TRUE,reason="PENDIENTES_HETEROGENEAS",error=slopes$error%||%slopes$interpretation,homogeneity_slopes=slopes,n=nrow(datos)))
    tab<-anova(mod_main);gp<-tab["grupo","Pr(>F)"];r2a<-summary(mod_main)$r.squared;mod0<-lm(dep~grupo,data=datos);r20<-summary(mod0)$r.squared
    if(!requireNamespace("emmeans",quietly=TRUE))stop("El paquete emmeans es obligatorio.")
    emm<-emmeans::emmeans(mod_main,"grupo");md<-as.data.frame(emm);adj<-lapply(seq_len(nrow(md)),function(i)list(group=as.character(md$grupo[i]),mean_adj=md$emmean[i],se=md$SE[i],ci_lower=md$lower.CL[i],ci_upper=md$upper.CL[i]))
    am<-switch(tolower(posthoc),tukey="tukey",scheffe="scheffe",none="none","bonferroni")
    pairs_out<-if(am=="none"||!isTRUE(gp<alpha))list()else{pw<-as.data.frame(emmeans::pairs(emm,adjust=am));lapply(seq_len(nrow(pw)),function(i)list(comparison=as.character(pw$contrast[i]),estimate=pw$estimate[i],se=pw$SE[i],t=pw$t.ratio[i],p_adj=pw$p.value[i],significant=pw$p.value[i]<alpha))}
    rows<-lapply(rownames(tab),function(nm)list(source=nm,SS=tab[nm,"Sum Sq"],df=tab[nm,"Df"],MS=tab[nm,"Mean Sq"],F=tab[nm,"F value"],p=tab[nm,"Pr(>F)"],p_apa=if(!is.na(tab[nm,"Pr(>F)"])&&tab[nm,"Pr(>F)"]<.001)"< .001"else paste0("= ",formatC(tab[nm,"Pr(>F)"],digits=3,format="f"))))
    list(n=nrow(datos),dep_var=dep_name,group_var=group_var,ancova_table=rows,adjusted_means=adj,posthoc_adjusted_means=pairs_out,posthoc_method=am,homogeneity_slopes=slopes,
      r2_ancova=r2a,r2_anova=r20,r2_improvement=r2a-r20,significant=isTRUE(gp<alpha),p_grupo=as.numeric(gp),decision=if(gp<alpha)paste0("Existen diferencias significativas en ",dep_name," entre grupos, controlando la covariable")else"No existen diferencias significativas entre grupos al controlar la covariable")
  },error=function(e)list(error=conditionMessage(e)))
}
