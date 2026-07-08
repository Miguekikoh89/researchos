# CanchariOS — Chi-cuadrado/Fisher coherente y reproducible
options(encoding="UTF-8")
interpret_v_cramer <- function(v,df_min){if(!is.finite(v))return("indeterminado");if(df_min<=1){if(v>=.50)"grande"else if(v>=.30)"mediano"else if(v>=.10)"pequeño"else"trivial"}else if(df_min==2){if(v>=.35)"grande"else if(v>=.21)"mediano"else if(v>=.07)"pequeño"else"trivial"}else{if(v>=.29)"grande"else if(v>=.17)"mediano"else if(v>=.06)"pequeño"else"trivial"}}
compute_chisquare <- function(var1,var2,alpha=.05,yates="auto",effect_size="cramer",min_expected=5){
  alpha<-suppressWarnings(as.numeric(alpha)[1]);if(!is.finite(alpha)||alpha<=0||alpha>=1)return(list(error="alpha debe estar entre 0 y 1."))
  thr<-suppressWarnings(as.numeric(min_expected)[1]);if(!is.finite(thr)||thr<=0)return(list(error="min_expected debe ser positivo."))
  effect_size<-tolower(as.character(effect_size));if(!effect_size%in%c("cramer","phi","auto"))return(list(error="effect_size debe ser cramer, phi o auto."))
  v1<-as.character(unlist(var1));v2<-as.character(unlist(var2));ok<-!is.na(v1)&!is.na(v2)&v1!=""&v2!="";v1<-v1[ok];v2<-v2[ok];n<-length(v1)
  if(n<10)return(list(error="Muestra insuficiente (n < 10)"));tab<-table(v1,v2);r<-nrow(tab);c<-ncol(tab);if(r<2||c<2)return(list(blocked=TRUE,reason="TABLA_DEGENERADA",error="Cada variable debe tener al menos 2 categorías observadas."))
  expct<-outer(rowSums(tab),colSums(tab))/n;pctlow<-mean(expct<thr)*100;minobs<-min(expct);cochran_ok<-minobs>=1&&pctlow<=20
  pear<-suppressWarnings(chisq.test(tab,correct=FALSE));ych<-if(r==2&&c==2)suppressWarnings(chisq.test(tab,correct=TRUE))else NULL
  ychoice<-tolower(as.character(yates));want_yates<-r==2&&c==2&&ychoice%in%c("auto","always","siempre","yes")
  use_fisher_2x2<-r==2&&c==2&&any(expct<thr);use_mc<-!cochran_ok&&!(r==2&&c==2);fisher<-NULL;method<-NULL;stat<-NA_real_;df<-NA_real_;p<-NA_real_;mc_B<-NULL;mc_seed<-NULL
  if(use_fisher_2x2){fisher<-fisher.test(tab);method<-"Fisher exacto";p<-as.numeric(fisher$p.value)}
  else if(use_mc){mc_seed<-20260704L;mc_B<-20000L;had<-exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE);if(had)old<-get(".Random.seed",envir=.GlobalEnv);on.exit({if(had)assign(".Random.seed",old,envir=.GlobalEnv)else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))rm(".Random.seed",envir=.GlobalEnv)},add=TRUE);set.seed(mc_seed);fisher<-fisher.test(tab,simulate.p.value=TRUE,B=mc_B);method<-paste0("Fisher-Freeman-Halton Monte Carlo (",format(mc_B,big.mark=" ")," réplicas)");p<-as.numeric(fisher$p.value)}
  else if(want_yates){method<-"Chi-cuadrado con corrección de Yates";stat<-as.numeric(ych$statistic);df<-as.numeric(ych$parameter);p<-as.numeric(ych$p.value)}
  else{method<-"Chi-cuadrado de Pearson";stat<-as.numeric(pear$statistic);df<-as.numeric(pear$parameter);p<-as.numeric(pear$p.value)}
  chiPear<-as.numeric(pear$statistic);dfmin<-min(r-1,c-1);V<-round(sqrt(chiPear/(n*dfmin)),3);phi<-if(r==2&&c==2)round(sqrt(chiPear/n),3)else NULL
  row_prop<-rowSums(tab)/n;col_prop<-colSums(tab)/n;cells<-list();for(i in seq_len(r))for(j in seq_len(c)){pr<-(tab[i,j]-expct[i,j])/sqrt(expct[i,j]);den<-sqrt(expct[i,j]*(1-row_prop[i])*(1-col_prop[j]));ar<-if(den>0)(tab[i,j]-expct[i,j])/den else NA_real_;cells[[length(cells)+1]]<-list(row=rownames(tab)[i],col=colnames(tab)[j],observed=as.integer(tab[i,j]),expected=as.numeric(expct[i,j]),pearson_residual=as.numeric(pr),adjusted_residual=as.numeric(ar))}
  selected_effect<-if(effect_size=="phi"){if(is.null(phi))return(list(blocked=TRUE,reason="PHI_SOLO_2X2",error="Phi solo está definido para tablas 2 × 2."));list(name="phi",value=phi)}else if(effect_size=="auto"&&r==2&&c==2)list(name="phi",value=phi)else list(name="cramer_v",value=V)
  sig<-isTRUE(p<alpha);list(test_type="chi_cuadrado",method_used=method,n=n,r=r,c=c,chi2=if(is.finite(stat))round(stat,3)else stat,df=if(is.finite(df))round(df,3)else df,p=if(is.finite(p))round(p,4)else p,p_apa=if(p<.001)"< .001"else paste0("= ",formatC(p,digits=3,format="f")),
    chi2_pearson=chiPear,p_pearson=as.numeric(pear$p.value),chi2_yates=if(!is.null(ych))as.numeric(ych$statistic)else NULL,p_yates=if(!is.null(ych))as.numeric(ych$p.value)else NULL,
    yates_applied=identical(method,"Chi-cuadrado con corrección de Yates"),p_fisher=if(!is.null(fisher))as.numeric(fisher$p.value)else NULL,or_fisher=if(!is.null(fisher)&&!is.null(fisher$estimate))as.numeric(fisher$estimate)else NULL,
    monte_carlo_B=mc_B,monte_carlo_seed=mc_seed,phi=phi,v_cramer=V,v_interpret=interpret_v_cramer(V,dfmin),selected_effect=selected_effect,effect_size_basis="Chi-cuadrado de Pearson",effect_size_requested=effect_size,
    min_expected_threshold_used=thr,min_expected=minobs,pct_low_expected=pctlow,assumption_ok=cochran_ok,
    assumption_note=if(cochran_ok)"Supuestos de Cochran compatibles."else paste0(round(pctlow,1),"% de celdas con esperado < ",thr," y mínimo esperado = ",round(minobs,3),"; se utilizó prueba exacta/Monte Carlo cuando correspondía."),
    use_fisher=grepl("Fisher",method),contingency_table=cells,row_names=rownames(tab),col_names=colnames(tab),row_totals=as.list(rowSums(tab)),col_totals=as.list(colSums(tab)),significant=sig,decision=if(sig)"Se rechaza H0"else"No se rechaza H0",alpha=alpha)
}
