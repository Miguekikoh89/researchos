source("tests/certification/helpers.R");source_r("anova.R")
g<-factor(rep(c("A","B","C"),each=20));base<-seq(-1,1,length.out=20);y<-c(base,base+.6,base+1.2)
r<-compute_anova(y,g,levene="no",posthoc="tukey",effect_size="both")
ref<-summary(aov(y~g))[[1]]
expect_true(r$test_type=="anova","No seleccionó ANOVA clásico")
expect_close(r$F,ref[1,"F value"]);expect_close(r$p,ref[1,"Pr(>F)"])
ssb<-ref[1,"Sum Sq"];ssw<-ref[2,"Sum Sq"];expect_close(r$eta2,ssb/(ssb+ssw))
rk<-compute_anova(y,g,force_nonparametric=TRUE,levene="no");kr<-kruskal.test(y~g)
expect_true(rk$test_type=="kruskal_wallis");expect_close(rk$H,kr$statistic);expect_close(rk$p,kr$p.value)
expect_close(rk$epsilon2,max(0,(as.numeric(kr$statistic)-nlevels(g)+1)/(length(y)-nlevels(g))))
# Welch: varianzas fuertemente distintas
x1<-seq(-1,1,length.out=30);x2<-seq(-10,10,length.out=30)+8;x3<-seq(-25,25,length.out=30)+20
yw<-c(x1,x2,x3);gw<-factor(rep(c("A","B","C"),each=30));rw<-compute_anova(yw,gw,levene="yes")
expect_true(rw$test_type=="welch_anova","No seleccionó Welch con heterocedasticidad fuerte")
wr<-oneway.test(yw~gw,var.equal=FALSE);expect_close(rw$F,wr$statistic);expect_close(rw$p,wr$p.value)
cat("PASS ANOVA, Welch, Kruskal y tamaños de efecto\n")
# Post hoc: Tukey HSD debe reproducir TukeyHSD de R.
tk_app<-r$posthoc;tk_ref<-TukeyHSD(aov(y~g),conf.level=.95)[[1]]
for(i in seq_len(nrow(tk_app))){nm<-as.character(tk_app$comparison[i]);expect_close(tk_app$diff[i],tk_ref[nm,"diff"]);expect_close(tk_app$ci_lower[i],tk_ref[nm,"lwr"]);expect_close(tk_app$ci_upper[i],tk_ref[nm,"upr"]);expect_close(tk_app$p_adj[i],tk_ref[nm,"p adj"])}
# Games-Howell: contraste directo con la definición basada en rango studentizado.
gh<-rw$posthoc;expect_true(nrow(gh)==3,"Games-Howell debe devolver tres comparaciones")
nm<-strsplit(as.character(gh$comparison[1])," - ",fixed=TRUE)[[1]];a<-yw[gw==nm[1]];b<-yw[gw==nm[2]];se<-sqrt(var(a)/length(a)+var(b)/length(b));dfgh<-(var(a)/length(a)+var(b)/length(b))^2/((var(a)/length(a))^2/(length(a)-1)+(var(b)/length(b))^2/(length(b)-1));q<-abs(mean(a)-mean(b))/se*sqrt(2);expect_close(gh$p_adj[1],ptukey(q,nmeans=3,df=dfgh,lower.tail=FALSE));half<-qtukey(.95,3,dfgh)/sqrt(2)*se;expect_close(gh$ci_lower[1],mean(a)-mean(b)-half);expect_close(gh$ci_upper[1],mean(a)-mean(b)+half)
# Dunn con empates: z y Bonferroni se recalculan desde los rangos promedio.
yd<-c(1,1,2,2,3,3,2,3,4,4,5,5,4,5,6,6,7,7);gd<-factor(rep(c("A","B","C"),each=6));rd<-compute_anova(yd,gd,force_nonparametric=TRUE,levene="no");du<-rd$posthoc[[1]];rr<-rank(yd,ties.method="average");N<-length(yd);ties<-table(yd);C<-1-sum(ties^3-ties)/(N^3-N);base_d<-N*(N+1)/12*C;zref<-(mean(rr[gd=="A"])-mean(rr[gd=="B"]))/sqrt(base_d*(1/6+1/6));praw<-2*pnorm(abs(zref),lower.tail=FALSE);expect_close(du$z,zref);expect_close(du$p_raw,praw);expect_close(du$p_adjusted,min(1,praw*3))
cat("PASS post hoc Tukey, Games-Howell y Dunn\n")
