
# CanchariOS — mediación simple OLS/Bootstrap endurecida
options(encoding="UTF-8")
run_mediation_simple <- function(df,x_var,m_var,y_var,n_boot=5000,seed=42,alpha=.05){
  tryCatch({
    for(v in c(x_var,m_var,y_var))if(!v%in%names(df))stop(paste0("Variable '",v,"' no encontrada."))
    d<-as.data.frame(lapply(df[,c(x_var,m_var,y_var),drop=FALSE],function(x)suppressWarnings(as.numeric(x))));d<-d[complete.cases(d),];n<-nrow(d)
    if(n<30)return(list(blocked=TRUE,reason="MUESTRA_INSUFICIENTE",error=paste0("n=",n,". Se requieren al menos 30 casos completos para mediación bootstrap."),n=n))
    x<-d[[1]];m<-d[[2]];y<-d[[3]];if(var(x)<=1e-10||var(m)<=1e-10||var(y)<=1e-10)return(list(blocked=TRUE,reason="VARIABLE_CONSTANTE",error="X, M y Y deben presentar varianza."))
    mm<-lm(m~x);my<-lm(y~x+m);mc<-lm(y~x);a<-coef(mm)["x"];b<-coef(my)["m"];ct<-coef(mc)["x"];cd<-coef(my)["x"];ab<-a*b
    sa<-summary(mm)$coefficients["x","Std. Error"];sb<-summary(my)$coefficients["m","Std. Error"];ses<-sqrt(a^2*sb^2+b^2*sa^2);zs<-ab/ses;ps<-2*pnorm(-abs(zs));pd<-summary(my)$coefficients["x","Pr(>|t|)"]
    nb<-max(1000L,as.integer(n_boot));had<-exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE);if(had)old<-get(".Random.seed",envir=.GlobalEnv);on.exit({if(had)assign(".Random.seed",old,envir=.GlobalEnv)else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))rm(".Random.seed",envir=.GlobalEnv)},add=TRUE);set.seed(as.integer(seed))
    vals<-rep(NA_real_,nb);for(i in seq_len(nb)){idx<-sample.int(n,n,replace=TRUE);vals[i]<-tryCatch(coef(lm(m[idx]~x[idx]))[2]*coef(lm(y[idx]~x[idx]+m[idx]))[3],error=function(e)NA_real_)};vals<-vals[is.finite(vals)];minvalid<-max(800L,ceiling(.80*nb));if(length(vals)<minvalid)return(list(blocked=TRUE,reason="BOOTSTRAP_INSUFICIENTE",error=paste0("Solo ",length(vals)," de ",nb," réplicas válidas."),n=n))
    ci<-quantile(vals,c(alpha/2,1-alpha/2),type=6,names=FALSE);ind<-ci[1]>0||ci[2]<0;direct<-isTRUE(pd<alpha);typ<-if(ind&&direct&&sign(ab)==sign(cd))"mediacion complementaria"else if(ind&&direct&&sign(ab)!=sign(cd))"mediacion competitiva"else if(ind&&!direct)"mediacion solo indirecta"else if(!ind&&direct)"solo efecto directo (sin mediacion)"else"sin efecto directo ni indirecto"
    identity_error <- as.numeric(ct-(cd+ab))
    list(n=n,x_var=x_var,m_var=m_var,y_var=y_var,a=as.numeric(a),b=as.numeric(b),c_total=as.numeric(ct),c_direct=as.numeric(cd),indirect=as.numeric(ab),
      total_effect_identity_error=identity_error,total_effect_identity_ok=abs(identity_error)<1e-8,se_a=sa,se_b=sb,sobel_se=ses,sobel_z=zs,sobel_p=ps,direct_p=as.numeric(pd),ci_lower=as.numeric(ci[1]),ci_upper=as.numeric(ci[2]),ic_method="bootstrap_percentil",n_boot_requested=nb,n_boot_valid=length(vals),seed_used=as.integer(seed),alpha=alpha,method="bootstrap_percentile_type6",causal_note="Diseño observacional: los coeficientes no demuestran causalidad por sí solos.",indirect_significant=ind,direct_significant=direct,mediation_type=typ)
  },error=function(e)list(error=conditionMessage(e)))
}
run_mediation_serial <- function(...)list(blocked=TRUE,reason="NO_IMPLEMENTADO_SERIAL",error="La mediación serial no está implementada y permanece bloqueada.")
