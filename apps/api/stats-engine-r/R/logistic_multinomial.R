
# CanchariOS — regresión logística multinomial endurecida
options(encoding="UTF-8")
compute_logistic_multinomial <- function(y_raw,X,var_names=NULL,alpha=.05,reference_level=NULL){
  tryCatch({
    if(!requireNamespace("nnet",quietly=TRUE))stop("Paquete nnet no disponible.")
    X<-as.data.frame(lapply(as.data.frame(X),function(x)suppressWarnings(as.numeric(unlist(x)))));if(is.null(var_names))var_names<-paste0("X",seq_len(ncol(X)));colnames(X)<-var_names
    y<-factor(as.character(unlist(y_raw)));valid<-complete.cases(y,X);y<-droplevels(y[valid]);X<-X[valid,,drop=FALSE];if(nlevels(y)<3)return(list(error="La VD requiere al menos 3 categorías."))
    if(!is.null(reference_level)){reference_level<-as.character(reference_level);if(!reference_level%in%levels(y))return(list(blocked=TRUE,reason="REFERENCIA_INVALIDA",error="La categoría de referencia no existe."));y<-relevel(y,ref=reference_level)}
    ref<-levels(y)[1];d<-data.frame(y=y,X);warns<-character();fit<-withCallingHandlers(nnet::multinom(y~.,data=d,trace=FALSE,Hess=TRUE),warning=function(w){warns<<-c(warns,conditionMessage(w));invokeRestart("muffleWarning")})
    if(!isTRUE(fit$convergence==0))return(list(blocked=TRUE,reason="NO_CONVERGENCIA",error=paste0("multinom no convergió (",fit$convergence,").")))
    sm<-summary(fit);B<-sm$coefficients;SE<-sm$standard.errors;if(is.null(dim(B))){B<-matrix(B,nrow=1,dimnames=list(levels(y)[-1],names(B)));SE<-matrix(SE,nrow=1,dimnames=list(levels(y)[-1],names(SE)))}
    if(any(!is.finite(B))||any(!is.finite(SE))||any(SE>1000)||any(abs(B)>20))return(list(blocked=TRUE,reason="SEPARACION_O_INESTABILIDAD",error="Coeficientes extremos/no finitos sugieren separación o inestabilidad."))
    z<-B/SE;p<-2*pnorm(abs(z),lower.tail=FALSE);zcrit<-qnorm(1-alpha/2);cmp<-list();for(lv in rownames(B)){cc<-lapply(colnames(B),function(term){b<-B[lv,term];se<-SE[lv,term];list(term=term,B=b,SE=se,z=z[lv,term],p=p[lv,term],p_apa=if(p[lv,term]<.001)"< .001"else paste0("= ",formatC(p[lv,term],digits=3,format="f")),OR=exp(b),OR_ci_lower=exp(b-zcrit*se),OR_ci_upper=exp(b+zcrit*se),significant=p[lv,term]<alpha)});cmp[[length(cmp)+1]]<-list(level=lv,vs_reference=ref,coefficients=cc)}
    nul<-nnet::multinom(y~1,data=d,trace=FALSE);llf<-logLik(fit);ll0<-logLik(nul);lr<--2*(as.numeric(ll0)-as.numeric(llf));dflr<-attr(llf,"df")-attr(ll0,"df");plr<-pchisq(lr,dflr,lower.tail=FALSE);n<-nrow(d);cs<-1-exp((2/n)*(as.numeric(ll0)-as.numeric(llf)));mx<-1-exp((2/n)*as.numeric(ll0));nag<-cs/mx
    pred<-predict(fit,d);tab<-table(Real=y,Predicho=pred);acc<-sum(diag(tab))/sum(tab)
    list(test_type="logistica_multinomial",n=n,k=ncol(X),n_levels=nlevels(y),reference_level=ref,levels=levels(y),converged=TRUE,warnings=as.list(warns),ll_null=as.numeric(ll0),ll_full=as.numeric(llf),lr_chi2=lr,lr_df=dflr,lr_p=plr,lr_p_apa=if(plr<.001)"< .001"else paste0("= ",formatC(plr,digits=3,format="f")),r2_cox_snell=cs,r2_nagelkerke=nag,comparisons=cmp,precision=100*acc,precision_label="Aparente (misma muestra de entrenamiento)",confusion_matrix=as.list(as.data.frame(tab)),significant=plr<alpha,decision=if(plr<alpha)"El modelo global es significativo"else"El modelo global no es significativo")
  },error=function(e)list(error=conditionMessage(e)))
}
