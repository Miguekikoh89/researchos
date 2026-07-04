
# CanchariOS — regresión jerárquica con muestra común y modelos anidados
options(encoding="UTF-8")
score_hier <- function(df,items,prop=.80){items<-as.character(unlist(items));m<-df[,items,drop=FALSE];v<-rowSums(!is.na(m));s<-rowMeans(m,na.rm=TRUE);s[v<ceiling(length(items)*prop)]<-NA_real_;s[!is.finite(s)]<-NA_real_;s}
run_hierarchical_regression <- function(df,blocks,var_b_items,var_b_name,alpha=.05,hier_method="enter"){
  tryCatch({
    if(tolower(as.character(hier_method))!="enter")return(list(blocked=TRUE,reason="METODO_NO_VALIDADO",error="La regresión jerárquica exige entrada ENTER por bloques; stepwise invalida la comparación anidada."))
    if(length(blocks)<1)stop("Debe definirse al menos un bloque.")
    dat<-data.frame(score_b=score_hier(df,var_b_items));block_names<-character()
    for(i in seq_along(blocks)){it<-as.character(unlist(blocks[[i]]$items));if(!length(it)||!all(it%in%names(df)))stop(paste0("Bloque ",i," contiene ítems inexistentes."));nm<-paste0("bloque_",i);dat[[nm]]<-score_hier(df,it);block_names<-c(block_names,nm)}
    dat<-dat[complete.cases(dat),,drop=FALSE];n<-nrow(dat);if(n<ncol(dat)+10)return(list(blocked=TRUE,reason="MUESTRA_INSUFICIENTE",error=paste0("n=",n," insuficiente para ",length(block_names)," bloques.")))
    models<-list();results<-list()
    for(i in seq_along(block_names)){preds<-block_names[1:i];mod<-lm(as.formula(paste("score_b ~",paste(preds,collapse=" + "))),data=dat);models[[i]]<-mod;sm<-summary(mod);fs<-sm$fstatistic;pmod<-pf(fs[1],fs[2],fs[3],lower.tail=FALSE)
      if(i==1){dr2<-sm$r.squared;Fch<-as.numeric(fs[1]);df1<-as.numeric(fs[2]);df2<-as.numeric(fs[3]);pch<-pmod}else{cmp<-anova(models[[i-1]],mod);dr2<-sm$r.squared-summary(models[[i-1]])$r.squared;Fch<-cmp$F[2];df1<-cmp$Df[2];df2<-df.residual(mod);pch<-cmp$`Pr(>F)`[2]}
      results[[i]]<-list(block=i,name=as.character(blocks[[i]]$name),r2=sm$r.squared,r2_adj=sm$adj.r.squared,delta_r2=dr2,F=as.numeric(fs[1]),p=as.numeric(pmod),p_apa=if(pmod<.001)"< .001"else paste0("= ",formatC(pmod,digits=3,format="f")),f_change=as.numeric(Fch),df1_change=as.numeric(df1),df2_change=as.numeric(df2),p_change=as.numeric(pch),p_change_apa=if(pch<.001)"< .001"else paste0("= ",formatC(pch,digits=3,format="f")),significant_change=pch<alpha,significant=pmod<alpha,predictors=preds,n=nobs(mod))}
    final<-models[[length(models)]];cs<-summary(final)$coefficients;coefs<-lapply(rownames(cs)[-1],function(nm)list(term=nm,B=cs[nm,1],SE=cs[nm,2],t=cs[nm,3],p=cs[nm,4],p_apa=if(cs[nm,4]<.001)"< .001"else paste0("= ",formatC(cs[nm,4],digits=3,format="f")),significant=cs[nm,4]<alpha))
    list(n=n,var_b=var_b_name,method_used="enter",common_sample=TRUE,blocks=results,final_coefficients=coefs,final_r2=summary(final)$r.squared,final_r2_adj=summary(final)$adj.r.squared)
  },error=function(e)list(error=conditionMessage(e)))
}
