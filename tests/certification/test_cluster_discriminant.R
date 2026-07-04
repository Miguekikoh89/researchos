source("tests/certification/helpers.R");source_r("cluster.R");source_r("discriminant.R");require_pkg("cluster");require_pkg("MASS")
set.seed(601);X<-rbind(cbind(rnorm(60,-2,.5),rnorm(60,-2,.5)),cbind(rnorm(60,2,.5),rnorm(60,2,.5)));df<-data.frame(x1=X[,1],x2=X[,2])
r<-run_cluster(df,c("x1","x2"),2,seed=99);set.seed(99);km<-kmeans(scale(df),2,nstart=25,algorithm="Hartigan-Wong");sil<-mean(cluster::silhouette(km$cluster,dist(scale(df)))[,3]);expect_close(r$within_ss_raw,km$tot.withinss);expect_close(r$between_ss_raw,km$betweenss);expect_close(r$silhouette_raw,sil)
# LDA
set.seed(602);g<-factor(rep(c("A","B","C"),each=70));x1<-rnorm(210,rep(c(-1,0,1),each=70),1);x2<-rnorm(210,rep(c(0,1,-1),each=70),1);dd<-data.frame(x1=x1,x2=x2,g=g)
d<-run_discriminant(dd,c("x1","x2"),"g",cv="yes");lda<-MASS::lda(g~x1+x2,dd);eig<-lda$svd^2;wilks<-1/prod(1+eig);chi<--(210-1-(2+3)/2)*log(wilks);p<-pchisq(chi,4,lower.tail=FALSE);expect_close(d$wilks_p,p);expect_close(d$wilks_lambda,round(wilks,4));expect_true(!is.null(d$cross_validation))
blk<-run_discriminant(dd,c("x1","x2"),"g",method="stepwise");expect_true(isTRUE(blk$blocked))
cat("PASS clúster y discriminante\n")
