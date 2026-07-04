cohen_d <- function(x1, x2, paired=FALSE) {
  if (paired) { d <- mean(x1-x2,na.rm=TRUE)/sd(x1-x2,na.rm=TRUE) }
  else { n1<-sum(!is.na(x1)); n2<-sum(!is.na(x2)); s_pool<-sqrt(((n1-1)*var(x1,na.rm=TRUE)+(n2-1)*var(x2,na.rm=TRUE))/(n1+n2-2)); d<-(mean(x1,na.rm=TRUE)-mean(x2,na.rm=TRUE))/s_pool }
  round(d,3)
}
interpret_d <- function(d) { a<-abs(d); if(is.na(a))return("indeterminado"); if(a>=0.80)return("grande"); if(a>=0.50)return("mediano"); if(a>=0.20)return("pequeno"); return("trivial") }
levene_test <- function(x1,x2) {
  tryCatch({
    x1<-x1[!is.na(x1)]; x2<-x2[!is.na(x2)]; n1<-length(x1); n2<-length(x2)
    z1<-abs(x1-mean(x1)); z2<-abs(x2-mean(x2)); gm<-mean(c(z1,z2))
    ssb<-n1*(mean(z1)-gm)^2+n2*(mean(z2)-gm)^2; ssw<-sum((z1-mean(z1))^2)+sum((z2-mean(z2))^2)
    F_val<-(ssb/1)/((ssw)/(n1+n2-2)); p_val<-pf(F_val,1,n1+n2-2,lower.tail=FALSE)
    list(F=round(F_val,3),df1=1,df2=n1+n2-2,p=p_val,equal_variances=p_val>=0.05)
  },error=function(e) list(F=NA,df1=NA,df2=NA,p=NA,equal_variances=TRUE))
}
normality_by_group <- function(x1,x2,alpha=0.05) {
  t1<-tryCatch(shapiro.test(x1),error=function(e)NULL); t2<-tryCatch(shapiro.test(x2),error=function(e)NULL)
  list(group1=list(W=round(t1$statistic,4),p=t1$p.value,normal=t1$p.value>=alpha),
       group2=list(W=round(t2$statistic,4),p=t2$p.value,normal=t2$p.value>=alpha),
       both_normal=(!is.null(t1)&&t1$p.value>=alpha)&&(!is.null(t2)&&t2$p.value>=alpha))
}
t_independent <- function(x1,x2,alpha=0.05,group_names=c("Grupo 1","Grupo 2"),alt="two.sided",levene_opt="yes") {
  x1<-x1[!is.na(x1)]; x2<-x2[!is.na(x2)]; n1<-length(x1); n2<-length(x2)
  lev<-if(levene_opt=="yes") levene_test(x1,x2) else list(F=NA,df1=NA,df2=NA,p=NA,equal_variances=TRUE)
  norm<-normality_by_group(x1,x2,alpha)
  t_eq<-t.test(x1,x2,var.equal=TRUE,alternative=alt)
  t_we<-t.test(x1,x2,var.equal=FALSE,alternative=alt)
  t_use<-if(lev$equal_variances) t_eq else t_we
  d<-cohen_d(x1,x2,paired=FALSE); sig<-t_use$p.value<alpha
  list(test_type="t_independiente",method_used=if(lev$equal_variances)"Student (varianzas iguales)" else "Welch (varianzas desiguales)",
    t=round(t_use$statistic,4),df=round(t_use$parameter,2),p=t_use$p.value,
    p_apa=if(t_use$p.value<.001)"< .001" else paste0("= ",formatC(t_use$p.value,digits=3,format="f")),
    ci_lower=round(t_use$conf.int[1],3),ci_upper=round(t_use$conf.int[2],3),
    mean_diff=round(mean(x1)-mean(x2),3),
    t_student=round(t_eq$statistic,4),df_student=t_eq$parameter,p_student=t_eq$p.value,
    t_welch=round(t_we$statistic,4),df_welch=round(t_we$parameter,2),p_welch=t_we$p.value,
    levene=lev,normality=norm,d=d,d_interpret=interpret_d(d),
    descriptives=list(
      group1=list(name=group_names[1],n=n1,mean=round(mean(x1),3),sd=round(sd(x1),3),se=round(sd(x1)/sqrt(n1),3)),
      group2=list(name=group_names[2],n=n2,mean=round(mean(x2),3),sd=round(sd(x2),3),se=round(sd(x2)/sqrt(n2),3))),
    significant=sig,decision=if(sig)"Se rechaza H0" else "No se rechaza H0",alpha=alpha,hypothesis_type=alt)
}
t_paired <- function(x1,x2,alpha=0.05,group_names=c("Pre","Post"),alt="two.sided") {
  valid<-complete.cases(x1,x2); x1<-x1[valid]; x2<-x2[valid]; n<-length(x1); dif<-x1-x2
  sw<-tryCatch(shapiro.test(dif),error=function(e)NULL)
  t_res<-t.test(x1,x2,paired=TRUE,alternative=alt); d<-cohen_d(x1,x2,paired=TRUE); sig<-t_res$p.value<alpha
  list(test_type="t_pareada",t=round(t_res$statistic,4),df=t_res$parameter,p=t_res$p.value,
    p_apa=if(t_res$p.value<.001)"< .001" else paste0("= ",formatC(t_res$p.value,digits=3,format="f")),
    ci_lower=round(t_res$conf.int[1],3),ci_upper=round(t_res$conf.int[2],3),
    mean_diff=round(mean(dif),3),sd_diff=round(sd(dif),3),se_diff=round(sd(dif)/sqrt(n),3),
    normality_diff=if(!is.null(sw))list(W=round(sw$statistic,4),p=sw$p.value,normal=sw$p.value>=alpha) else list(W=NA,p=NA,normal=NA),
    d=d,d_interpret=interpret_d(d),
    descriptives=list(group1=list(name=group_names[1],n=n,mean=round(mean(x1),3),sd=round(sd(x1),3)),
                      group2=list(name=group_names[2],n=n,mean=round(mean(x2),3),sd=round(sd(x2),3))),
    significant=sig,decision=if(sig)"Se rechaza H0" else "No se rechaza H0",alpha=alpha,hypothesis_type=alt)
}
mann_whitney <- function(x1,x2,alpha=0.05,group_names=c("Grupo 1","Grupo 2"),alt="two.sided") {
  x1<-x1[!is.na(x1)]; x2<-x2[!is.na(x2)]; n1<-length(x1); n2<-length(x2)
  test<-wilcox.test(x1,x2,alternative=alt,correct=TRUE,conf.int=TRUE)
  U<-test$statistic; r_rb<-(2*U)/(n1*n2)-1; sig<-test$p.value<alpha
  list(test_type="mann_whitney",U=as.numeric(U),p=test$p.value,
    p_apa=if(test$p.value<.001)"< .001" else paste0("= ",formatC(test$p.value,digits=3,format="f")),
    ci_lower=round(test$conf.int[1],3),ci_upper=round(test$conf.int[2],3),
    r_rb=r_rb,r_interpret=if(abs(r_rb)>=0.5)"grande" else if(abs(r_rb)>=0.3)"mediano" else if(abs(r_rb)>=0.1)"pequeno" else "trivial",
    descriptives=list(group1=list(name=group_names[1],n=n1,median=round(median(x1),3),iqr=round(IQR(x1),3),mean=round(mean(x1),3)),
                      group2=list(name=group_names[2],n=n2,median=round(median(x2),3),iqr=round(IQR(x2),3),mean=round(mean(x2),3))),
    significant=sig,decision=if(sig)"Se rechaza H0" else "No se rechaza H0",alpha=alpha,hypothesis_type=alt)
}
wilcoxon_paired <- function(x1,x2,alpha=0.05,group_names=c("Pre","Post"),alt="two.sided") {
  valid<-complete.cases(x1,x2)
  x1<-x1[valid]
  x2<-x2[valid]
  n<-length(x1)

  diferencias <- x1 - x2
  diferencias_no_cero <- diferencias[diferencias != 0]

  if (length(diferencias_no_cero) < 1) {
    stop("Wilcoxon pareado no puede calcularse: todas las diferencias son iguales a cero.")
  }

  test<-suppressWarnings(
    wilcox.test(
      x1,
      x2,
      paired=TRUE,
      alternative=alt,
      correct=TRUE,
      exact=FALSE
    )
  )

  W<-as.numeric(test$statistic)

  rangos <- rank(abs(diferencias_no_cero), ties.method="average")
  w_pos <- sum(rangos[diferencias_no_cero > 0])
  w_neg <- sum(rangos[diferencias_no_cero < 0])
  total_rangos <- w_pos + w_neg

  r_rb <- if (total_rangos > 0)
    (w_pos - w_neg) / total_rangos
  else
    NA_real_

  sig<-test$p.value<alpha
  list(test_type="wilcoxon_pareado",W=as.numeric(W),p=test$p.value,
    p_apa=if(test$p.value<.001)"< .001" else paste0("= ",formatC(test$p.value,digits=3,format="f")),
    r_rb=round(r_rb,3),
    descriptives=list(group1=list(name=group_names[1],n=n,median=round(median(x1),3),mean=round(mean(x1),3)),
                      group2=list(name=group_names[2],n=n,median=round(median(x2),3),mean=round(mean(x2),3))),
    significant=sig,decision=if(sig)"Se rechaza H0" else "No se rechaza H0",alpha=alpha,hypothesis_type=alt)
}
compute_ttest <- function(x1,x2,type="independiente",alpha=0.05,group_names=c("Grupo 1","Grupo 2"),force_nonparametric=FALSE,hypothesis_type="bilateral",effect_size_type="cohend",levene="yes") {
  x1<-as.numeric(unlist(x1)); x2<-as.numeric(unlist(x2))
  n1<-sum(!is.na(x1)); n2<-sum(!is.na(x2))
  if(n1<3||n2<3) return(list(error="Muestra insuficiente (n < 3 por grupo)"))
  alt <- if(hypothesis_type=="unilateral") "less" else if(hypothesis_type=="unilateral_pos") "greater" else "two.sided"
  if(type=="pareada") {
    valid<-complete.cases(x1,x2); dif<-x1[valid]-x2[valid]
    sw<-tryCatch(shapiro.test(dif),error=function(e)list(p.value=1))
    if(force_nonparametric||sw$p.value<alpha) { res<-wilcoxon_paired(x1,x2,alpha,group_names,alt); res$auto_selected<-"Wilcoxon (diferencias no normales)" }
    else { res<-t_paired(x1,x2,alpha,group_names,alt); res$auto_selected<-"t pareada (diferencias normales)" }
  } else {
    norm<-normality_by_group(x1,x2,alpha)
    if(force_nonparametric||!norm$both_normal) { res<-mann_whitney(x1,x2,alpha,group_names,alt); res$auto_selected<-"Mann-Whitney (distribucion no normal)" }
    else { res<-t_independent(x1,x2,alpha,group_names,alt,levene); res$auto_selected<-res$method_used }
  }
  res$effect_size_type_used <- effect_size_type
  res
}
