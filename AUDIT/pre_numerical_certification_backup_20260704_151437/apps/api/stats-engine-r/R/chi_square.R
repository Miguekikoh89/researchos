
# CanchariOS — Chi-cuadrado/Fisher coherente
options(encoding="UTF-8")
interpret_v_cramer <- function(v,df_min){if(!is.finite(v))return("indeterminado");if(df_min<=1){if(v>=.50)"grande"else if(v>=.30)"mediano"else if(v>=.10)"pequeno"else"trivial"}else if(df_min==2){if(v>=.35)"grande"else if(v>=.21)"mediano"else if(v>=.07)"pequeno"else"trivial"}else{if(v>=.29)"grande"else if(v>=.17)"mediano"else if(v>=.06)"pequeno"else"trivial"}}
compute_chisquare <- function(var1,var2,alpha=.05,yates="auto",effect_size="cramer",min_expected=5){
  v1<-as.character(unlist(var1));v2<-as.character(unlist(var2));ok<-!is.na(v1)&!is.na(v2)&v1!=""&v2!="";v1<-v1[ok];v2<-v2[ok];n<-length(v1)
  if(n<10)return(list(error="Muestra insuficiente (n < 10)"));tab<-table(v1,v2);r<-nrow(tab);c<-ncol(tab);if(r<2||c<2)return(list(blocked=TRUE,reason="TABLA_DEGENERADA",error="Cada variable debe tener al menos 2 categorías observadas."))
  expct<-outer(rowSums(tab),colSums(tab))/n;thr<-as.numeric(min_expected);pctlow<-mean(expct<thr)*100;minobs<-min(expct)
  pear<-suppressWarnings(chisq.test(tab,correct=FALSE));ych<-if(r==2&&c==2)suppressWarnings(chisq.test(tab,correct=TRUE))else NULL
  ychoice<-tolower(as.character(yates));want_yates<-r==2&&c==2&&ychoice%in%c("auto","always","siempre","yes")
  sparse<-pctlow>20||minobs<1
  use_fisher_2x2<-r==2&&c==2&&any(expct<thr)
  fisher<-NULL;method<-NULL;stat<-NA_real_;df<-NA_real_;p<-NA_real_
  if(use_fisher_2x2){fisher<-fisher.test(tab);method<-"Fisher exacto";p<-as.numeric(fisher$p.value)}
  else if(sparse&&!(r==2&&c==2)){set.seed(20260704);fisher<-fisher.test(tab,simulate.p.value=TRUE,B=20000);method<-"Fisher-Freeman-Halton Monte Carlo (20 000 réplicas)";p<-as.numeric(fisher$p.value)}
  else if(want_yates){method<-"Chi-cuadrado con corrección de Yates";stat<-as.numeric(ych$statistic);df<-as.numeric(ych$parameter);p<-as.numeric(ych$p.value)}
  else{method<-"Chi-cuadrado de Pearson";stat<-as.numeric(pear$statistic);df<-as.numeric(pear$parameter);p<-as.numeric(pear$p.value)}
  chiPear<-as.numeric(pear$statistic);dfmin<-min(r-1,c-1);V<-sqrt(chiPear/(n*dfmin));phi<-if(r==2&&c==2)sqrt(chiPear/n)else NULL
  cells<-list();for(i in rownames(tab))for(j in colnames(tab))cells[[length(cells)+1]]<-list(row=i,col=j,observed=as.integer(tab[i,j]),expected=as.numeric(expct[i,j]),residual=(tab[i,j]-expct[i,j])/sqrt(expct[i,j]))
  sig<-isTRUE(p<alpha);list(test_type="chi_cuadrado",method_used=method,n=n,r=r,c=c,chi2=stat,df=df,p=p,p_apa=if(p<.001)"< .001"else paste0("= ",formatC(p,digits=3,format="f")),
    chi2_pearson=chiPear,p_pearson=as.numeric(pear$p.value),chi2_yates=if(!is.null(ych))as.numeric(ych$statistic)else NULL,p_yates=if(!is.null(ych))as.numeric(ych$p.value)else NULL,
    yates_applied=identical(method,"Chi-cuadrado con corrección de Yates"),p_fisher=if(!is.null(fisher))as.numeric(fisher$p.value)else NULL,or_fisher=if(!is.null(fisher)&&!is.null(fisher$estimate))as.numeric(fisher$estimate)else NULL,
    phi=phi,v_cramer=V,v_interpret=interpret_v_cramer(V,dfmin),effect_size_basis="Chi-cuadrado de Pearson",effect_size_requested=effect_size,min_expected_threshold_used=thr,min_expected=minobs,pct_low_expected=pctlow,
    assumption_ok=!sparse,assumption_note=if(sparse)paste0(round(pctlow,1),"% de celdas con esperado < ",thr,"; se usó prueba exacta/Monte Carlo cuando correspondía.")else"Supuestos de Cochran compatibles.",
    use_fisher=grepl("Fisher",method),contingency_table=cells,row_names=rownames(tab),col_names=colnames(tab),row_totals=as.list(rowSums(tab)),col_totals=as.list(colSums(tab)),significant=sig,decision=if(sig)"Se rechaza H0"else"No se rechaza H0",alpha=alpha)
}
