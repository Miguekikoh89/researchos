
# CanchariOS — ANOVA/Kruskal-Wallis endurecido
options(encoding="UTF-8")

interpret_eta2 <- function(x){if(!is.finite(x))"indeterminado" else if(x>=.14)"grande" else if(x>=.06)"mediano" else if(x>=.01)"pequeno" else "trivial"}
interpret_epsilon2 <- interpret_eta2

levene_anova <- function(y, grupos, alpha=.05) {
  tryCatch({
    d <- data.frame(y=as.numeric(y),g=factor(grupos)); d <- d[complete.cases(d),]
    if(nlevels(d$g)<2) stop("Se requieren al menos dos grupos.")
    ns <- table(d$g); if(any(ns<3)) stop("Levene requiere al menos 3 casos por grupo.")
    z <- ave(d$y,d$g,FUN=function(x)abs(x-mean(x)))
    fit <- aov(z~d$g); sm <- summary(fit)[[1]]
    Fv <- sm[1,"F value"]; p <- sm[1,"Pr(>F)"]
    list(ok=TRUE,F=as.numeric(Fv),df1=as.numeric(sm[1,"Df"]),df2=as.numeric(sm[2,"Df"]),
         p=as.numeric(p),equal_variances=isTRUE(p>=alpha),method="Levene clásico basado en la media")
  },error=function(e)list(ok=FALSE,F=NA_real_,df1=NA_real_,df2=NA_real_,p=NA_real_,
                          equal_variances=NA,error=conditionMessage(e),method="Levene clásico basado en la media"))
}

normality_group <- function(x,alpha){
  x<-x[is.finite(x)]; n<-length(x)
  if(n<3||length(unique(x))<2)return(list(n=n,W=NA_real_,p=NA_real_,normal=NA,available=FALSE))
  if(n>5000)return(list(n=n,W=NA_real_,p=NA_real_,normal=NA,available=FALSE,note="n > 5000"))
  sw<-tryCatch(shapiro.test(x),error=function(e)NULL)
  if(is.null(sw))return(list(n=n,W=NA_real_,p=NA_real_,normal=NA,available=FALSE))
  list(n=n,W=as.numeric(sw$statistic),p=as.numeric(sw$p.value),normal=isTRUE(sw$p.value>=alpha),available=TRUE)
}

tukey_hsd <- function(y,grupos,alpha=.05){
  fit<-aov(y~factor(grupos)); tk<-TukeyHSD(fit,conf.level=1-alpha)[[1]]
  data.frame(comparison=rownames(tk),diff=tk[,"diff"],ci_lower=tk[,"lwr"],ci_upper=tk[,"upr"],
             p_adj=tk[,"p adj"],significant=tk[,"p adj"]<alpha,stringsAsFactors=FALSE)
}

bonferroni_posthoc <- function(y,grupos,alpha=.05){
  g<-factor(grupos); lv<-levels(g); m<-choose(length(lv),2); out<-list()
  for(i in seq_len(length(lv)-1))for(j in (i+1):length(lv)){
    x1<-y[g==lv[i]];x2<-y[g==lv[j]]
    tt<-t.test(x1,x2,var.equal=TRUE,conf.level=1-alpha/m)
    pa<-min(1,tt$p.value*m)
    out[[length(out)+1]]<-data.frame(comparison=paste0(lv[i]," - ",lv[j]),diff=mean(x1)-mean(x2),
      ci_lower=tt$conf.int[1],ci_upper=tt$conf.int[2],p_adj=pa,significant=pa<alpha,stringsAsFactors=FALSE)
  }
  do.call(rbind,out)
}

scheffe_posthoc <- function(y,grupos,alpha=.05){
  g<-factor(grupos);lv<-levels(g);fit<-aov(y~g);sm<-summary(fit)[[1]];mse<-sm["Residuals","Mean Sq"];
  dfr<-sm["Residuals","Df"];k<-length(lv);fc<-qf(1-alpha,k-1,dfr);out<-list()
  for(i in seq_len(k-1))for(j in (i+1):k){
    x1<-y[g==lv[i]];x2<-y[g==lv[j]];dif<-mean(x1)-mean(x2);se<-sqrt(mse*(1/length(x1)+1/length(x2)))
    Fv<-(dif/se)^2/(k-1);p<-pf(Fv,k-1,dfr,lower.tail=FALSE);half<-sqrt((k-1)*fc)*se
    out[[length(out)+1]]<-data.frame(comparison=paste0(lv[i]," - ",lv[j]),diff=dif,ci_lower=dif-half,
      ci_upper=dif+half,p_adj=p,significant=p<alpha,stringsAsFactors=FALSE)
  };do.call(rbind,out)
}

games_howell <- function(y,grupos,alpha=.05){
  g<-factor(grupos);lv<-levels(g);k<-length(lv);st<-lapply(lv,function(z){x<-y[g==z];list(n=length(x),m=mean(x),v=var(x))});names(st)<-lv;out<-list()
  for(i in seq_len(k-1))for(j in (i+1):k){a<-st[[i]];b<-st[[j]];se<-sqrt(a$v/a$n+b$v/b$n)
    df<-(a$v/a$n+b$v/b$n)^2/((a$v/a$n)^2/(a$n-1)+(b$v/b$n)^2/(b$n-1));dif<-a$m-b$m
    q<-abs(dif/se)*sqrt(2);p<-ptukey(q,nmeans=k,df=df,lower.tail=FALSE);half<-qtukey(1-alpha,k,df)/sqrt(2)*se
    out[[length(out)+1]]<-data.frame(comparison=paste0(lv[i]," - ",lv[j]),diff=dif,ci_lower=dif-half,ci_upper=dif+half,
      p_adj=p,significant=p<alpha,df=df,stringsAsFactors=FALSE)};do.call(rbind,out)
}

dunn_posthoc <- function(y,grupos,alpha=.05,adjust="bonferroni"){
  d<-data.frame(y=as.numeric(y),g=factor(grupos));d<-d[complete.cases(d),];N<-nrow(d);lv<-levels(d$g);r<-rank(d$y,ties.method="average")
  ties<-table(d$y);C<-1-sum(ties^3-ties)/(N^3-N);base<-N*(N+1)/12*C;rows<-list();raw<-numeric()
  for(i in seq_len(length(lv)-1))for(j in (i+1):length(lv)){ri<-r[d$g==lv[i]];rj<-r[d$g==lv[j]]
    z<-(mean(ri)-mean(rj))/sqrt(base*(1/length(ri)+1/length(rj)));p<-2*pnorm(abs(z),lower.tail=FALSE);raw<-c(raw,p)
    rows[[length(rows)+1]]<-list(comparison=paste0(lv[i]," - ",lv[j]),z=as.numeric(z),p_raw=as.numeric(p))}
  adjp<-p.adjust(raw,method=adjust);for(i in seq_along(rows)){rows[[i]]$p_bonf<-as.numeric(adjp[i]);rows[[i]]$p_adjusted<-as.numeric(adjp[i]);rows[[i]]$adjust_method<-adjust;rows[[i]]$significant<-adjp[i]<alpha};rows
}

kruskal_wallis_test <- function(y,grupos,alpha=.05){
  d<-data.frame(y=as.numeric(y),g=factor(grupos));d<-d[complete.cases(d),];test<-kruskal.test(y~g,data=d);N<-nrow(d);k<-nlevels(d$g);H<-as.numeric(test$statistic)
  e2<-max(0,(H-k+1)/(N-k));desc<-lapply(levels(d$g),function(z){x<-d$y[d$g==z];list(group=z,n=length(x),median=median(x),iqr=IQR(x),mean=mean(x))})
  p<-as.numeric(test$p.value);list(test_type="kruskal_wallis",H=H,df=as.numeric(test$parameter),p=p,
    p_apa=if(p<.001)"< .001" else paste0("= ",formatC(p,digits=3,format="f")),epsilon2=e2,epsilon2_interpret=interpret_epsilon2(e2),
    descriptives=desc,posthoc=if(p<alpha)dunn_posthoc(d$y,d$g,alpha)else list(),posthoc_method="Dunn (Bonferroni con corrección por empates)",
    significant=p<alpha,decision=if(p<alpha)"Se rechaza H0" else "No se rechaza H0",alpha=alpha)
}

compute_anova <- function(y,grupos,alpha=.05,force_nonparametric=FALSE,posthoc="auto",effect_size="eta2",levene="yes"){
  alpha<-suppressWarnings(as.numeric(alpha)[1]);if(!is.finite(alpha)||alpha<=0||alpha>=1)return(list(error="alpha debe estar entre 0 y 1."))
  effect_size<-tolower(as.character(effect_size));if(!effect_size%in%c("eta2","omega2","both"))return(list(error="effect_size debe ser eta2, omega2 o both."))
  y<-suppressWarnings(as.numeric(unlist(y)));grupos<-as.character(unlist(grupos));ok<-is.finite(y)&!is.na(grupos)&grupos!="";y<-y[ok];g<-droplevels(factor(grupos[ok]));k<-nlevels(g)
  if(k<2)return(list(error="Se necesitan al menos 2 grupos"));ns<-table(g);if(any(ns<3))return(list(blocked=TRUE,reason="MUESTRA_INSUFICIENTE_POR_GRUPO",error=paste0("Cada grupo requiere n >= 3. Conteos: ",paste(names(ns),ns,collapse=", "))))
  norm<-lapply(levels(g),function(z)c(list(group=z),normality_group(y[g==z],alpha)));all_normal<-all(vapply(norm,function(x)isTRUE(x$normal),logical(1)));large<-all(ns>=30)
  lev_req<-tolower(as.character(levene))%in%c("yes","si","true","1");lev<-if(lev_req)levene_anova(y,g,alpha)else list(ok=NA,equal_variances=NA,p=NA,method="No solicitado")
  if(lev_req&&!isTRUE(lev$ok))return(list(blocked=TRUE,reason="LEVENE_NO_CALCULABLE",error=lev$error,normality=norm,levene=lev))
  if(isTRUE(force_nonparametric)||(!all_normal&&!large)){res<-kruskal_wallis_test(y,g,alpha);res$normality<-norm;res$levene<-lev;res$auto_selected<-"Kruskal-Wallis";return(res)}
  if(lev_req&&!isTRUE(lev$equal_variances)){
    wt<-oneway.test(y~g,var.equal=FALSE);p<-as.numeric(wt$p.value);ph<-if(p<alpha)games_howell(y,g,alpha)else data.frame()
    return(list(test_type="welch_anova",auto_selected="Welch ANOVA + Games-Howell",F=as.numeric(wt$statistic),
      df_between=as.numeric(wt$parameter[1]),df_within=as.numeric(wt$parameter[2]),p=p,p_apa=if(p<.001)"< .001"else paste0("= ",formatC(p,digits=3,format="f")),
      eta2=NA_real_,eta2_interpret="No reportado para Welch",omega2=NA_real_,effect_size_requested=effect_size,normality=norm,levene=lev,
      descriptives=lapply(levels(g),function(z){x<-y[g==z];list(group=z,n=length(x),mean=mean(x),sd=sd(x),se=sd(x)/sqrt(length(x)))}),
      posthoc=ph,posthoc_method="Games-Howell",significant=p<alpha,decision=if(p<alpha)"Se rechaza H0"else"No se rechaza H0",alpha=alpha))
  }
  fit<-aov(y~g);sm<-summary(fit)[[1]];ssb<-sm[1,"Sum Sq"];ssw<-sm[2,"Sum Sq"];sst<-ssb+ssw;dfb<-sm[1,"Df"];dfw<-sm[2,"Df"];Fv<-sm[1,"F value"];p<-sm[1,"Pr(>F)"];mse<-ssw/dfw
  eta<-ssb/sst;om<-(ssb-dfb*mse)/(sst+mse);om<-max(0,om)
  choice<-tolower(as.character(posthoc));if(choice%in%c("auto",""))choice<-"tukey"
  ph<-if(p<alpha)switch(choice,tukey=tukey_hsd(y,g,alpha),bonferroni=bonferroni_posthoc(y,g,alpha),scheffe=scheffe_posthoc(y,g,alpha),games_howell=games_howell(y,g,alpha),tukey_hsd(y,g,alpha))else data.frame()
  phname<-switch(choice,tukey="Tukey HSD",bonferroni="Bonferroni con IC simultáneos",scheffe="Scheffe",games_howell="Games-Howell","Tukey HSD")
  list(test_type="anova",auto_selected=paste0("ANOVA + ",phname),F=as.numeric(Fv),df_between=as.numeric(dfb),df_within=as.numeric(dfw),p=as.numeric(p),
    p_apa=if(p<.001)"< .001"else paste0("= ",formatC(p,digits=3,format="f")),ss_between=ssb,ss_within=ssw,ss_total=sst,ms_between=ssb/dfb,ms_within=mse,
    eta2=eta,eta2_partial=eta,eta2_interpret=interpret_eta2(eta),omega2=om,omega2_interpret=interpret_eta2(om),effect_size_requested=effect_size,
    selected_effect=if(effect_size=="omega2")list(name="omega2",value=om,interpretation=interpret_eta2(om))else if(effect_size=="eta2")list(name="eta2",value=eta,interpretation=interpret_eta2(eta))else list(name="both",eta2=eta,omega2=om),
    normality=norm,levene=lev,descriptives=lapply(levels(g),function(z){x<-y[g==z];list(group=z,n=length(x),mean=mean(x),sd=sd(x),se=sd(x)/sqrt(length(x)))}),
    posthoc=ph,posthoc_method=phname,significant=p<alpha,decision=if(p<alpha)"Se rechaza H0"else"No se rechaza H0",alpha=alpha)
}
