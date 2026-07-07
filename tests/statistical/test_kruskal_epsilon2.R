source("apps/api/stats-engine-r/R/anova.R")
y<-c(1:5,6:10,11:15);g<-rep(c("A","B","C"),each=5);r<-kruskal_wallis_test(y,g);ref<-max(0,(r$H-3+1)/(15-3));cat(r$epsilon2,ref,"\n");stopifnot(abs(r$epsilon2-ref)<1e-12);cat("PASS epsilon2\n")
