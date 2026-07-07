# CanchariOS — ANCOVA endurecida y autocontenida
options(encoding="UTF-8")
if (!exists("%||%", mode="function")) `%||%` <- function(a,b) if(!is.null(a)&&length(a)>0)a else b

score_min_valid <- function(df,items,prop=.80){
  m<-df[,items,drop=FALSE]
  m<-as.data.frame(lapply(m,function(x)suppressWarnings(as.numeric(x))),stringsAsFactors=FALSE)
  nvalid<-rowSums(!is.na(m))
  s<-rowMeans(m,na.rm=TRUE)
  s[nvalid<ceiling(length(items)*prop)]<-NA_real_
  s[!is.finite(s)]<-NA_real_
  s
}

ancova_emmeans_base <- function(model, datos, alpha=.05){
  lvls<-levels(datos$grupo)
  cov_mean<-mean(datos$covariable)
  newdata<-data.frame(
    covariable=rep(cov_mean,length(lvls)),
    grupo=factor(lvls,levels=lvls)
  )
  pred<-stats::predict(model,newdata=newdata,se.fit=TRUE)
  crit<-stats::qt(1-alpha/2,df=pred$df)
  adjusted<-lapply(seq_along(lvls),function(i)list(
    group=lvls[i],
    mean_adj=as.numeric(pred$fit[i]),
    se=as.numeric(pred$se.fit[i]),
    ci_lower=as.numeric(pred$fit[i]-crit*pred$se.fit[i]),
    ci_upper=as.numeric(pred$fit[i]+crit*pred$se.fit[i])
  ))
  trm<-stats::delete.response(stats::terms(model))
  X<-stats::model.matrix(trm,newdata,
    contrasts.arg=model$contrasts,
    xlev=model$xlevels)
  beta<-stats::coef(model)
  V<-stats::vcov(model)
  keep<-intersect(colnames(X),names(beta))
  X<-X[,keep,drop=FALSE]
  beta<-beta[keep]
  V<-V[keep,keep,drop=FALSE]
  list(adjusted=adjusted,X=X,beta=beta,V=V,levels=lvls,
       df=stats::df.residual(model),covariate_mean=cov_mean)
}

ancova_pairwise_base <- function(emm, method="bonferroni", alpha=.05){
  k<-length(emm$levels)
  if(k<2)return(list())
  pairs<-utils::combn(seq_len(k),2,simplify=FALSE)
  raw<-lapply(pairs,function(ij){
    L<-emm$X[ij[1],]-emm$X[ij[2],]
    est<-as.numeric(sum(L*emm$beta))
    se<-as.numeric(sqrt(drop(t(L)%*%emm$V%*%L)))
    tval<-est/se
    p_raw<-2*stats::pt(abs(tval),df=emm$df,lower.tail=FALSE)
    list(i=ij[1],j=ij[2],estimate=est,se=se,t=tval,p_raw=p_raw)
  })
  p_raw<-vapply(raw,`[[`,numeric(1),"p_raw")
  method<-tolower(method)
  p_adj<-switch(method,
    tukey=vapply(raw,function(z)stats::ptukey(abs(z$t)*sqrt(2),nmeans=k,df=emm$df,lower.tail=FALSE),numeric(1)),
    scheffe=vapply(raw,function(z)stats::pf((z$t^2)/(k-1),df1=k-1,df2=emm$df,lower.tail=FALSE),numeric(1)),
    bonferroni=stats::p.adjust(p_raw,method="bonferroni"),
    stats::p.adjust(p_raw,method="bonferroni")
  )
  lapply(seq_along(raw),function(h){
    z<-raw[[h]]
    list(
      comparison=paste0(emm$levels[z$i]," - ",emm$levels[z$j]),
      estimate=z$estimate,
      se=z$se,
      t=z$t,
      p_raw=z$p_raw,
      p_adj=as.numeric(p_adj[h]),
      significant=is.finite(p_adj[h])&&p_adj[h]<alpha
    )
  })
}

run_ancova <- function(df,dep_items,group_var,covariate_items,dep_name,alpha=.05,posthoc="bonferroni",check_slopes="yes"){
  tryCatch({
    dep_items<-as.character(unlist(dep_items));covariate_items<-as.character(unlist(covariate_items))
    if(!group_var%in%names(df))stop("Variable de grupo no encontrada.")
    if(!all(dep_items%in%names(df))||!all(covariate_items%in%names(df)))stop("Ítems dependientes o covariable no encontrados.")
    dep<-score_min_valid(df,dep_items);covs<-score_min_valid(df,covariate_items);grupo<-droplevels(factor(df[[group_var]]))
    datos<-data.frame(dep=dep,grupo=grupo,covariable=covs);datos<-datos[complete.cases(datos),,drop=FALSE]
    if(nrow(datos)<20)return(list(blocked=TRUE,reason="MUESTRA_INSUFICIENTE",error="ANCOVA requiere al menos 20 casos completos."))
    ns<-table(datos$grupo)
    if(nlevels(datos$grupo)<2||any(ns<5))return(list(blocked=TRUE,reason="GRUPOS_INSUFICIENTES",error=paste0("Se requieren al menos 2 grupos y n >= 5 por grupo. ",paste(names(ns),ns,collapse=", "))))
    mod_main<-stats::lm(dep~covariable+grupo,data=datos)
    slopes_requested<-tolower(as.character(check_slopes))%in%c("yes","si","true","1")
    slopes<-if(slopes_requested)tryCatch({
      mi<-stats::lm(dep~covariable*grupo,data=datos);cmp<-stats::anova(mod_main,mi)
      p<-as.numeric(cmp$`Pr(>F)`[2]);Fv<-as.numeric(cmp$F[2])
      list(ok=isTRUE(p>=alpha),F=Fv,p=p,method="Comparación global del término covariable × grupo",interpretation=if(p<alpha)"Se viola la homogeneidad de pendientes"else"Homogeneidad de pendientes compatible con los datos")
    },error=function(e)list(ok=FALSE,p=NA_real_,F=NA_real_,error=conditionMessage(e))) else list(ok=NA,p=NA,F=NA,method="No solicitado")
    if(slopes_requested&&!isTRUE(slopes$ok))return(list(blocked=TRUE,reason="PENDIENTES_HETEROGENEAS",error=slopes$error%||%slopes$interpretation,homogeneity_slopes=slopes,n=nrow(datos)))
    tab<-stats::anova(mod_main);gp<-as.numeric(tab["grupo","Pr(>F)"])
    r2a<-summary(mod_main)$r.squared;mod0<-stats::lm(dep~grupo,data=datos);r20<-summary(mod0)$r.squared
    ss_error<-tab["Residuals","Sum Sq"];ss_group<-tab["grupo","Sum Sq"];ss_cov<-tab["covariable","Sum Sq"]
    pes_group<-ss_group/(ss_group+ss_error);pes_cov<-ss_cov/(ss_cov+ss_error)
    emm<-ancova_emmeans_base(mod_main,datos,alpha)
    adj<-emm$adjusted
    am<-switch(tolower(posthoc),tukey="tukey",scheffe="scheffe",none="none","bonferroni")
    pairs_out<-if(am=="none"||!isTRUE(gp<alpha))list()else ancova_pairwise_base(emm,am,alpha)
    rows<-lapply(rownames(tab),function(nm){
      pv<-as.numeric(tab[nm,"Pr(>F)"])
      list(source=nm,SS=as.numeric(tab[nm,"Sum Sq"]),df=as.numeric(tab[nm,"Df"]),MS=as.numeric(tab[nm,"Mean Sq"]),F=as.numeric(tab[nm,"F value"]),p=pv,p_apa=if(is.finite(pv)&&pv<.001)"< .001"else if(is.finite(pv))paste0("= ",formatC(pv,digits=3,format="f"))else NA_character_)
    })
    list(
      n=nrow(datos),dep_var=dep_name,group_var=group_var,ancova_table=rows,
      adjusted_means=adj,adjusted_means_engine="base_r_model_matrix",
      adjusted_means_covariate_value=emm$covariate_mean,
      posthoc_adjusted_means=pairs_out,posthoc_method=am,homogeneity_slopes=slopes,
      r2_ancova=r2a,r2_group_only=r20,delta_r2_covariate=r2a-r20,r2_improvement_deprecated=r2a-r20,
      partial_eta2_group=as.numeric(pes_group),partial_eta2_covariate=as.numeric(pes_cov),
      anova_type="Secuencial (Type I): covariable antes de grupo",
      significant=isTRUE(gp<alpha),p_grupo=gp,
      decision=if(gp<alpha)paste0("Existen diferencias significativas en ",dep_name," entre grupos, controlando la covariable")else"No existen diferencias significativas entre grupos al controlar la covariable"
    )
  },error=function(e)list(error=conditionMessage(e)))
}
