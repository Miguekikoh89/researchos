# ============================================================================
# CANCHARI PLS-SEM ENGINE — Fase 1 Completa
# Basado en CANCHARI PLS-SEM PRO V6.0 (publicado en Scopus)
# Módulos: Medición, Estructural, Validez Discriminante, Q², f², VIF,
#          Fornell-Larcker, Cross-Loadings, SRMR, Efectos Indirectos/Totales
# ============================================================================
suppressPackageStartupMessages({
  library(seminr); library(jsonlite); library(dplyr); library(openxlsx)
})
`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b
safe_num <- function(x, digits=3) { val <- suppressWarnings(as.numeric(x[1])); if(is.na(val)) NA_real_ else round(val,digits) }

calc_cr_ave <- function(L) {
  if (is.null(L)) return(data.frame(Constructo=character(),CR=numeric(),AVE=numeric()))
  L <- as.matrix(L); constructs <- colnames(L)
  out <- data.frame(Constructo=constructs,CR=NA_real_,AVE=NA_real_,stringsAsFactors=FALSE)
  for (j in seq_along(constructs)) {
    lam <- suppressWarnings(as.numeric(L[,j])); lam <- lam[!is.na(lam) & lam!=0]
    if (!length(lam)) next
    cr <- (sum(lam)^2)/((sum(lam)^2)+sum(1-lam^2)); ave <- sum(lam^2)/length(lam)
    out$CR[j] <- round(cr,3); out$AVE[j] <- round(ave,3)
  }
  out
}

calc_htmt <- function(summ, raw_df) {
  tryCatch({
    htmt_obj <- tryCatch(summ$validity$htmt, error=function(e) NULL)
    if (!is.null(htmt_obj)) {
      h <- as.data.frame(as.table(as.matrix(htmt_obj)))
      result <- h %>% filter(!is.na(Freq) & Var1!=Var2) %>%
        rename(C1=Var1,C2=Var2,HTMT=Freq) %>%
        mutate(HTMT=round(as.numeric(HTMT),3),
               OK=ifelse(HTMT<0.85,"\u2713 <0.85 (estricto)",ifelse(HTMT<0.90,"\u26a0 <0.90 (liberal)","\u2717 \u22650.90 (cr\u00edtico)")))
      result <- result[!duplicated(t(apply(result[,c("C1","C2")],1,sort))),]
      if (nrow(result)>0) return(result)
    }
    ld_mat <- tryCatch(as.matrix(summ$loadings),error=function(e) NULL)
    if (is.null(ld_mat)||is.null(raw_df)) return(NULL)
    cons <- colnames(ld_mat)
    if (length(cons)<2) return(NULL)
    item_map <- list()
    for (cn in cons) { its <- rownames(ld_mat)[abs(ld_mat[,cn])>0.001]; its <- its[its %in% names(raw_df)]; if (length(its)>=1) item_map[[cn]] <- its }
    safe_tri <- function(R) { if(nrow(R)<2) return(1.0); tri <- R[lower.tri(R)]; mean(abs(tri),na.rm=TRUE) }
    htmt_val <- function(d,ii,jj) { Rij <- cor(d[,ii,drop=FALSE],d[,jj,drop=FALSE],use="pairwise.complete.obs"); mean(abs(Rij),na.rm=TRUE)/sqrt(safe_tri(cor(d[,ii,drop=FALSE],use="pairwise.complete.obs"))*safe_tri(cor(d[,jj,drop=FALSE],use="pairwise.complete.obs"))) }
    cv <- names(item_map); if (length(cv)<2) return(NULL)
    rows <- list()
    for (i in 1:(length(cv)-1)) for (j in (i+1):length(cv)) {
      val <- tryCatch(htmt_val(raw_df,item_map[[cv[i]]],item_map[[cv[j]]]),error=function(e) NA_real_)
      rows[[length(rows)+1]] <- data.frame(C1=cv[i],C2=cv[j],HTMT=round(val,3),
        OK=ifelse(!is.na(val)&val<0.85,"\u2713 <0.85 (estricto)",ifelse(!is.na(val)&val<0.90,"\u26a0 <0.90 (liberal)","\u2717 \u22650.90 (cr\u00edtico)")),stringsAsFactors=FALSE)
    }
    if (length(rows)>0) do.call(rbind,rows) else NULL
  },error=function(e) NULL)
}

calc_fornell_larcker <- function(summ, scores_df) {
  tryCatch({
    cr_ave_fl <- calc_cr_ave(summ$loadings); if (is.null(cr_ave_fl)||nrow(cr_ave_fl)==0) return(NULL)
    cons_fl <- cr_ave_fl$Constructo; ave_fl <- setNames(cr_ave_fl$AVE,cons_fl)
    if (is.null(scores_df)) return(NULL)
    cis <- cons_fl[cons_fl %in% names(scores_df)]; if (length(cis)<2) return(NULL)
    phi <- round(cor(scores_df[,cis,drop=FALSE],use="pairwise.complete.obs"),3)
    fl_mat <- phi; diag(fl_mat) <- round(sqrt(ave_fl[cis]),3)
    fl_df <- as.data.frame(fl_mat); fl_df <- cbind(Constructo=rownames(fl_df),fl_df)
    fl_df$OK <- sapply(rownames(phi),function(r) { dv <- sqrt(ave_fl[r]); om <- max(abs(phi[r,setdiff(colnames(phi),r)]),na.rm=TRUE); if(is.na(dv)||is.na(om)) "N/D" else if(dv>om) "\u2713 OK" else "\u2717 REVISAR" })
    fl_df
  },error=function(e) NULL)
}

calc_cross_loadings <- function(summ, scores_df, raw_df) {
  tryCatch({
    ld_mat <- as.matrix(summ$loadings); if (is.null(ld_mat)||is.null(scores_df)||is.null(raw_df)) return(NULL)
    items <- rownames(ld_mat)[rownames(ld_mat) %in% names(raw_df)]
    cons  <- intersect(colnames(ld_mat),colnames(scores_df))
    if (!length(items)||!length(cons)) return(NULL)
    cl_mat <- matrix(NA_real_,nrow=length(items),ncol=length(cons),dimnames=list(items,cons))
    for (it in items) for (cn in cons) cl_mat[it,cn] <- suppressWarnings(cor(raw_df[[it]],scores_df[[cn]],use="pairwise.complete.obs"))
    cl_df <- as.data.frame(round(cl_mat,3))
    cl_df <- cbind(Item=rownames(cl_mat), cl_df)
    cl_df$Asignado_a <- apply(ld_mat[items,,drop=FALSE],1,function(r){mx<-which.max(abs(r));if(length(mx))names(r)[mx] else NA_character_})
    rownames(cl_df) <- NULL
    cl_df
  },error=function(e) NULL)
}

calc_vif <- function(scores_df, p_df) {
  tryCatch({
    if (is.null(scores_df)) return(NULL)
    rows <- list()
    for (endo in unique(p_df$to)) {
      preds <- unique(p_df$from[p_df$to==endo]); preds <- preds[preds %in% names(scores_df)]
      if (!length(preds)) next
      if (length(preds)==1) { rows[[length(rows)+1]] <- data.frame(Constructo=endo,Predictor=preds,VIF=1.000,OK="\u2713 <3.3 Ideal",stringsAsFactors=FALSE); next }
      for (k in seq_along(preds)) {
        fit_v <- tryCatch(stats::lm(scores_df[[preds[k]]]~.,data=scores_df[,preds[-k],drop=FALSE]),error=function(e) NULL)
        if (is.null(fit_v)) next
        r2v <- summary(fit_v)$r.squared; vif_v <- if(r2v>=0.9999) 9999 else round(1/(1-r2v),3)
        rows[[length(rows)+1]] <- data.frame(Constructo=endo,Predictor=preds[k],VIF=vif_v,OK=ifelse(vif_v<3.3,"\u2713 <3.3 Ideal",ifelse(vif_v<5,"\u26a0 <5 Aceptable","\u2717 \u22655 Problema")),stringsAsFactors=FALSE)
      }
    }
    if (length(rows)>0) do.call(rbind,rows) else NULL
  },error=function(e) NULL)
}

calc_f2 <- function(scores_df, p_df) {
  tryCatch({
    if (is.null(scores_df)) return(NULL)
    rows <- list()
    for (endo in unique(p_df$to)) {
      preds <- unique(p_df$from[p_df$to==endo]); preds <- preds[preds %in% names(scores_df)]
      if (!endo %in% names(scores_df)||!length(preds)) next
      fit_f <- tryCatch(stats::lm(as.formula(paste0("`",endo,"` ~ ",paste0("`",preds,"`",collapse="+"))),data=scores_df),error=function(e) NULL)
      if (is.null(fit_f)) next
      r2f <- min(summary(fit_f)$r.squared,0.999999)
      for (x in preds) {
        pr <- setdiff(preds,x)
        f2v <- if (!length(pr)) r2f/(1-r2f) else {
          ftr <- tryCatch(stats::lm(as.formula(paste0("`",endo,"` ~ ",paste0("`",pr,"`",collapse="+"))),data=scores_df),error=function(e) NULL)
          if (is.null(ftr)) NA_real_ else (r2f-summary(ftr)$r.squared)/(1-r2f)
        }
        rows[[length(rows)+1]] <- data.frame(Path=paste0(x," -> ",endo),f2=round(f2v,3),
          Nivel=ifelse(is.na(f2v),"N/D",ifelse(f2v>=0.35,"Grande",ifelse(f2v>=0.15,"Mediano",ifelse(f2v>=0.02,"Peque\u00f1o","Negligible")))),stringsAsFactors=FALSE)
      }
    }
    if (length(rows)>0) do.call(rbind,rows) else NULL
  },error=function(e) NULL)
}

calc_q2 <- function(scores_df, p_df, d=7L) {
  tryCatch({
    if (is.null(scores_df)) return(NULL)
    d <- as.integer(d); if(is.na(d)||d<2) d <- 7L
    rows <- list()
    for (endo in unique(p_df$to)) {
      preds <- unique(p_df$from[p_df$to==endo]); preds <- preds[preds %in% names(scores_df)]
      if (!endo %in% names(scores_df)||!length(preds)) next
      y <- scores_df[[endo]]; X <- as.matrix(scores_df[,preds,drop=FALSE]); n <- length(y)
      SSO <- sum(y^2); SSE <- 0; vp <- 0
      for (k in seq_len(d)) {
        omit <- seq(k,n,by=d); keep <- setdiff(seq_len(n),omit)
        if (length(keep)<(length(preds)+2)) next
        fk <- tryCatch(stats::lm(y[keep]~X[keep,,drop=FALSE]),error=function(e) NULL)
        if (is.null(fk)) next
        co <- coef(fk); yp <- co[1]+X[omit,,drop=FALSE]%*%co[-1]
        SSE <- SSE+sum((y[omit]-yp)^2); vp <- vp+length(omit)
      }
      q2v <- if(SSO>0&&vp>0) round(1-SSE/SSO,3) else NA_real_
      rows[[length(rows)+1]] <- data.frame(Constructo=endo,Q2=q2v,
        Metodo=paste0("Blindfolding (d=",d,")"),
        Nivel=ifelse(is.na(q2v),"N/D",ifelse(q2v>=0.35,"Alta \u2605\u2605\u2605",ifelse(q2v>=0.15,"Moderada \u2605\u2605",ifelse(q2v>0,"Baja \u2605","Sin relevancia")))),
        stringsAsFactors=FALSE)
    }
    if (length(rows)>0) do.call(rbind,rows) else NULL
  },error=function(e) NULL)
}

calc_srmr <- function(pls_est, summ, raw_df=NULL) {
  tryCatch({
    v <- tryCatch(as.numeric(summ$fit$srmr),error=function(e) NULL) %||%
         tryCatch(as.numeric(pls_est$fit$srmr),error=function(e) NULL) %||%
         tryCatch(as.numeric(summ$model_fit$srmr),error=function(e) NULL)
    # Calcular SRMR manualmente (seminr no lo expone en esta version)
    if (is.null(v)||is.na(v)) {
      tryCatch({
        sc  <- tryCatch(as.data.frame(pls_est$construct_scores), error=function(e) NULL)
        ld  <- tryCatch(as.matrix(summ$loadings), error=function(e) NULL)
        if (!is.null(sc) && !is.null(ld) && !is.null(raw_df)) {
          items <- rownames(ld)[rownames(ld) %in% names(raw_df)]
          cons  <- colnames(ld)[colnames(ld) %in% names(sc)]
          if (length(items) >= 2 && length(cons) >= 1) {
            S     <- cor(raw_df[,items,drop=FALSE], use="pairwise.complete.obs")
            phi   <- cor(sc[,cons,drop=FALSE], use="pairwise.complete.obs")
            lam   <- ld[items,cons,drop=FALSE]
            S_hat <- lam %*% phi %*% t(lam)
            diag(S_hat) <- 1
            p     <- nrow(S)
            resid <- S - S_hat
            v     <- round(sqrt(sum(resid[lower.tri(resid)]^2) / (p*(p-1)/2)), 4)
          }
        }
      }, error=function(e) NULL)
    }
    if (is.null(v)||is.na(v)) return(NULL)
    data.frame(Indice="SRMR",Valor=round(v,4),
      Criterio=ifelse(v<=0.08,"\u2713 Buen ajuste (\u22640.08)",ifelse(v<=0.10,"\u26a0 Aceptable (\u22640.10)","\u2717 Cuestionable (>0.10)")),
      Referencia="Hu & Bentler (1999); Hair et al. (2022)",stringsAsFactors=FALSE)
  },error=function(e) NULL)
}

calc_indirect <- function(paths_tbl, p_df, boot_summ, pls_est=NULL, scores_df=NULL, n_boot=500) {
  tryCatch({
    ind_boot <- tryCatch(as.data.frame(boot_summ$bootstrapped_indirect_paths),error=function(e) NULL)
    if (!is.null(ind_boot)&&nrow(ind_boot)>0) {
      lbl <- rownames(ind_boot)
      nc <- which(sapply(ind_boot,function(x)!all(is.na(suppressWarnings(as.numeric(x))))))
      bi <- if(length(nc)>=1) suppressWarnings(as.numeric(ind_boot[[nc[1]]])) else rep(NA_real_,nrow(ind_boot))
      se <- if(length(nc)>=3) suppressWarnings(as.numeric(ind_boot[[nc[3]]])) else rep(NA_real_,nrow(ind_boot))
      lo <- if(length(nc)>=5) suppressWarnings(as.numeric(ind_boot[[nc[5]]])) else bi-1.96*se
      hi <- if(length(nc)>=6) suppressWarnings(as.numeric(ind_boot[[nc[6]]])) else bi+1.96*se
      Ti <- bi/se; pi <- 2*(1-pt(abs(Ti),df=max(nrow(ind_boot)-1,1)))
      return(data.frame(Path=lbl,Beta_ind=round(bi,3),STDEV=round(se,3),T_Valor=round(Ti,3),P_Valor=round(pi,4),
        IC_2.5=round(lo,3),IC_97.5=round(hi,3),
        Sig=ifelse(pi<0.001,"***",ifelse(pi<0.01,"**",ifelse(pi<0.05,"*",ifelse(pi<0.10,"\u2020","n.s.")))),stringsAsFactors=FALSE))
    }
    if (is.null(paths_tbl)||nrow(paths_tbl)==0) return(NULL)
    bmap <- setNames(paths_tbl$Beta, gsub("\\s+","",paths_tbl$Path))
    se_map <- setNames(paths_tbl$STDEV, gsub("\\s+","",paths_tbl$Path))
    meds <- intersect(p_df$from, p_df$to)
    if (!length(meds)) return(NULL)

    # Construir todas las rutas indirectas (2-step y 3-step)
    indirect_paths <- list()

    # 2-step: X -> M -> Y
    for (med in meds) {
      exos <- p_df$from[p_df$to==med]
      ends <- p_df$to[p_df$from==med]
      for (ex in exos) for (en in ends) {
        if (ex==en) next
        k1 <- paste0(ex,"->",med); k2 <- paste0(med,"->",en)
        b1 <- bmap[k1]; b2 <- bmap[k2]
        if (is.na(b1)||is.na(b2)) next
        indirect_paths[[length(indirect_paths)+1]] <- list(
          path=paste0(ex," -> ",med," -> ",en),
          keys=c(k1,k2), beta=round(b1*b2,3), steps="2-step")
      }
    }

    # 3-step: X -> M1 -> M2 -> Y
    meds2 <- meds
    for (m1 in meds) {
      for (m2 in p_df$to[p_df$from==m1]) {
        if (!m2 %in% meds) next
        exos3 <- p_df$from[p_df$to==m1]
        ends3 <- p_df$to[p_df$from==m2]
        for (ex in exos3) for (en in ends3) {
          if (ex==m1||ex==m2||en==m1||en==m2) next
          k1 <- paste0(ex,"->",m1); k2 <- paste0(m1,"->",m2); k3 <- paste0(m2,"->",en)
          b1 <- bmap[k1]; b2 <- bmap[k2]; b3 <- bmap[k3]
          if (is.na(b1)||is.na(b2)||is.na(b3)) next
          indirect_paths[[length(indirect_paths)+1]] <- list(
            path=paste0(ex," -> ",m1," -> ",m2," -> ",en),
            keys=c(k1,k2,k3), beta=round(b1*b2*b3,3), steps="3-step")
        }
      }
    }

    if (!length(indirect_paths)) return(NULL)

    # Bootstrap manual de productos de coeficientes
    rows <- list()
    for (ip in indirect_paths) {
      beta_ind <- ip$beta

      # Bootstrap via producto de distribuciones normales (Sobel approximation mejorada)
      # Más robusto: usar STDEV de cada ruta para simular distribución bootstrap
      se_vals <- suppressWarnings(as.numeric(se_map[ip$keys]))
      beta_vals <- suppressWarnings(as.numeric(bmap[ip$keys]))

      if (!any(is.na(se_vals)) && !any(is.na(beta_vals)) && all(se_vals > 0)) {
        set.seed(456)
        n_sim <- max(n_boot, 1000L)
        # Simular productos bootstrap via distribuciones normales independientes
        sim_mat <- matrix(NA_real_, nrow=n_sim, ncol=length(beta_vals))
        for (j in seq_along(beta_vals)) {
          sim_mat[,j] <- rnorm(n_sim, mean=beta_vals[j], sd=se_vals[j])
        }
        sim_prod <- apply(sim_mat, 1, prod)
        se_ind   <- round(sd(sim_prod), 3)
        ci_lo    <- round(quantile(sim_prod, 0.025), 3)
        ci_hi    <- round(quantile(sim_prod, 0.975), 3)
        T_ind    <- round(beta_ind / se_ind, 3)
        p_ind    <- round(2*(1-pt(abs(T_ind), df=max(384-1,1))), 4)
        sig_ind  <- ifelse(p_ind<0.001,"***",ifelse(p_ind<0.01,"**",ifelse(p_ind<0.05,"*",ifelse(p_ind<0.10,"\u2020","n.s."))))
      } else {
        se_ind <- NA_real_; ci_lo <- NA_real_; ci_hi <- NA_real_
        T_ind  <- NA_real_; p_ind <- NA_real_; sig_ind <- "N/D"
      }

      rows[[length(rows)+1]] <- data.frame(
        Path=ip$path, Beta_ind=beta_ind, STDEV=se_ind,
        T_Valor=T_ind, P_Valor=p_ind,
        IC_2.5=ci_lo, IC_97.5=ci_hi, Sig=sig_ind,
        Steps=ip$steps, stringsAsFactors=FALSE)
    }
    if (length(rows)>0) do.call(rbind,rows) else NULL
  },error=function(e) NULL)
}

calc_total <- function(paths_tbl, indirect_tbl, p_df) {
  tryCatch({
    if (is.null(paths_tbl)||nrow(paths_tbl)==0) return(NULL)
    get_endpoints <- function(path_str) {
      nodes <- trimws(strsplit(path_str, " -> ")[[1]])
      if (length(nodes) < 2) return(path_str)
      paste0(nodes[1], " -> ", nodes[length(nodes)])
    }
    p_df_eff <- paths_tbl
    i_df_eff <- indirect_tbl
    if (!is.null(i_df_eff) && nrow(i_df_eff) > 0) {
      i_df_eff$Endpoint <- vapply(i_df_eff$Path, get_endpoints, character(1))
    } else {
      i_df_eff <- data.frame(Path=character(),Beta_ind=numeric(),Endpoint=character(),stringsAsFactors=FALSE)
    }
    # Normalizar paths: un solo espacio alrededor de ->
    p_df_eff$Path <- gsub("\\s*->\\s*", " -> ", trimws(p_df_eff$Path))
    if (nrow(i_df_eff)>0) i_df_eff$Endpoint <- gsub("\\s*->\\s*", " -> ", trimws(i_df_eff$Endpoint))
    all_endpoints <- unique(c(p_df_eff$Path, i_df_eff$Endpoint))
    tot_rows <- list()
    for (pth in all_endpoints) {
      d_val <- if (pth %in% p_df_eff$Path) as.numeric(p_df_eff$Beta[p_df_eff$Path==pth][1]) else 0
      matching_ind <- i_df_eff[i_df_eff$Endpoint==pth,,drop=FALSE]
      i_val <- if (nrow(matching_ind)>0) sum(as.numeric(matching_ind$Beta_ind),na.rm=TRUE) else 0
      tot_rows[[length(tot_rows)+1]] <- data.frame(
        Relacion=pth,Directo=round(d_val,3),
        Indirecto=round(i_val,3),Total=round(d_val+i_val,3),
        stringsAsFactors=FALSE)
    }
    if (length(tot_rows)>0) { out<-do.call(rbind,tot_rows); rownames(out)<-NULL; out } else NULL
  },error=function(e) NULL)
}

calc_pls_predict <- function(pls_est, summ, scores_df, raw_df, p_df, construct_items, k_folds=10L, seed=42L) {
  tryCatch({
    k_folds <- as.integer(k_folds); set.seed(seed)
    endogenous <- unique(p_df$to)
    q2_interpret <- function(q2) {
      if (is.na(q2)||is.null(q2)) return("N/D")
      if (q2>=0.35) return("Alta ★★★") else if (q2>=0.15) return("Mediana ★★")
      else if (q2>0) return("Baja ★") else return("Sin poder predictivo")
    }
    ind_rows <- list()
    for (endo_nm in endogenous) {
      raw_items <- construct_items[[endo_nm]]
      raw_items <- raw_items[raw_items %in% names(raw_df)]
      if (length(raw_items)==0L) {
        if (endo_nm %in% names(scores_df)) raw_items <- endo_nm else next
      }
      preds_endo <- p_df$from[p_df$to==endo_nm]
      preds_endo <- preds_endo[preds_endo %in% names(scores_df)]
      if (length(preds_endo)==0L) next
      X_scores <- as.matrix(scores_df[,preds_endo,drop=FALSE])
      for (ind_nm in raw_items) {
        y_raw <- if (ind_nm %in% names(raw_df)) as.numeric(raw_df[[ind_nm]]) else as.numeric(scores_df[[ind_nm]])
        if (sum(!is.na(y_raw)) < k_folds*3L) next
        n_obs <- length(y_raw)
        folds <- sample(rep(seq_len(k_folds), length.out=n_obs))
        yhat_pls <- numeric(n_obs); yhat_lm <- numeric(n_obs)
        for (fold_i in seq_len(k_folds)) {
          tr <- which(folds!=fold_i); te <- which(folds==fold_i)
          if (length(tr)<ncol(X_scores)+2L||length(te)<1L) next
          X_tr <- cbind(1,X_scores[tr,,drop=FALSE]); X_te <- cbind(1,X_scores[te,,drop=FALSE])
          beta_pls <- tryCatch({ XtX <- crossprod(X_tr)+1e-9*diag(ncol(X_tr)); solve(XtX,crossprod(X_tr,y_raw[tr])) },error=function(e) NULL)
          if (is.null(beta_pls)) next
          yhat_pls[te] <- as.numeric(X_te %*% beta_pls)
          lm_fit <- tryCatch(stats::lm.fit(X_tr,y_raw[tr]),error=function(e) NULL)
          yhat_lm[te] <- if (!is.null(lm_fit)) as.numeric(X_te %*% lm_fit$coefficients) else yhat_pls[te]
        }
        valid <- !is.na(y_raw) & !is.na(yhat_pls)
        y_v <- y_raw[valid]; yp_v <- yhat_pls[valid]; yl_v <- yhat_lm[valid]
        if (length(y_v)<3L) next
        rmse_pls <- sqrt(mean((y_v-yp_v)^2)); rmse_lm <- sqrt(mean((y_v-yl_v)^2))
        rmse_naive <- sd(y_v); mae_pls <- mean(abs(y_v-yp_v))
        ss_res <- sum((y_v-yp_v)^2); ss_tot <- sum((y_v-mean(y_v))^2)
        q2 <- if (ss_tot>1e-12) round(1-ss_res/ss_tot,4) else NA_real_
        ind_rows[[length(ind_rows)+1L]] <- data.frame(
          Indicador=ind_nm, Constructo=endo_nm,
          RMSE_modelo=round(rmse_pls,4), MAE_modelo=round(mae_pls,4),
          RMSE_naive=round(rmse_naive,4), RMSE_LM=round(rmse_lm,4),
          Q2_predict=q2,
          Mejor_naive=if(!is.na(rmse_pls)&&rmse_pls<rmse_naive) "\u2713 S\u00ed" else "\u2717 No",
          Mejor_LM=if(!is.na(rmse_pls)&&!is.na(rmse_lm)&&rmse_pls<rmse_lm) "\u2713 S\u00ed" else "\u2248 Similar",
          Nivel=q2_interpret(q2),
          Metodo=paste0("10-fold CV construct scores (",k_folds,"-fold)"),
          stringsAsFactors=FALSE)
      }
    }
    if (length(ind_rows)==0L) return(NULL)
    ind_tbl <- do.call(rbind,ind_rows); rownames(ind_tbl) <- NULL
    ind_tbl
  },error=function(e) NULL)
}


# ── VAF + Tipo de mediación (Zhao et al., 2010) ──────────────────────────────
calc_vaf_mediation <- function(paths_tbl, indirect_tbl, p_df) {
  tryCatch({
    if (is.null(paths_tbl)||is.null(indirect_tbl)||nrow(paths_tbl)==0||nrow(indirect_tbl)==0) return(NULL)
    get_ep <- function(s) { nd<-trimws(strsplit(s," -> ")[[1]]); paste0(nd[1]," -> ",nd[length(nd)]) }
    rows <- list()
    for (i in seq_len(nrow(indirect_tbl))) {
      path_ind <- indirect_tbl$Path[i]
      ep       <- get_ep(path_ind)
      beta_ind <- as.numeric(indirect_tbl$Beta_ind[i])
      # Efecto directo
      dir_row  <- paths_tbl[gsub("\\s+","",paths_tbl$Path)==gsub("\\s+","",ep),,drop=FALSE]
      beta_dir <- if (nrow(dir_row)>0) as.numeric(dir_row$Beta[1]) else 0
      p_dir    <- if (nrow(dir_row)>0) as.numeric(dir_row$P_Valor[1]) else NA_real_
      beta_tot <- beta_dir + beta_ind
      vaf      <- if (abs(beta_tot)>1e-9) round(beta_ind/beta_tot*100,1) else NA_real_
      # Tipo de mediación — Zhao et al. (2010)
      # Si no hay ruta directa entre X e Y en el modelo, VAF no aplica
      hay_ruta_directa <- nrow(dir_row) > 0
      tipo <- if (!hay_ruta_directa) {
        # No existe ruta directa X->Y — solo efecto indirecto via mediador
        "Solo efecto indirecto (sin ruta directa X→Y)"
      } else if (is.na(p_dir) || p_dir >= 0.05) {
        # Ruta directa existe pero no significativa
        if (abs(beta_ind) > 1e-9) "Mediación completa (Zhao et al., 2010)" else "Sin mediación"
      } else {
        # Ruta directa significativa
        if (sign(beta_dir)==sign(beta_ind)) {
          if (!is.na(vaf) && vaf>=80) "Mediación complementaria (VAF≥80%)" else "Mediación parcial complementaria"
        } else {
          "Mediación competitiva (signos opuestos)"
        }
      }
      # VAF solo aplica cuando hay ruta directa
      if (!hay_ruta_directa) vaf <- NA_real_
      rows[[length(rows)+1]] <- data.frame(
        Ruta_indirecta=path_ind, Endpoint=ep,
        Beta_directo=round(beta_dir,3), Beta_indirecto=round(beta_ind,3),
        Beta_total=round(beta_tot,3), VAF_pct=vaf,
        Tipo_mediacion=tipo, Referencia="Zhao et al. (2010); Hair et al. (2022)",
        stringsAsFactors=FALSE)
    }
    if (length(rows)>0) { out<-do.call(rbind,rows); rownames(out)<-NULL; out } else NULL
  },error=function(e) NULL)
}

# ── HTMT con IC bootstrapped ─────────────────────────────────────────────────
calc_htmt_ci <- function(raw_df, summ, n_boot=500L, seed=123L) {
  tryCatch({
    set.seed(seed); n_boot <- as.integer(n_boot)
    ld_mat <- tryCatch(as.matrix(summ$loadings),error=function(e) NULL)
    if (is.null(ld_mat)||is.null(raw_df)) return(NULL)
    cons <- colnames(ld_mat)
    if (length(cons)<2) return(NULL)
    item_map <- list()
    for (cn in cons) { its<-rownames(ld_mat)[abs(ld_mat[,cn])>0.001]; its<-its[its%in%names(raw_df)]; if(length(its)>=2) item_map[[cn]]<-its }
    calc_htmt_pair <- function(d,ii,jj) {
      Rij<-cor(d[,ii,drop=FALSE],d[,jj,drop=FALSE],use="pairwise.complete.obs")
      Rii<-cor(d[,ii,drop=FALSE],use="pairwise.complete.obs"); Rjj<-cor(d[,jj,drop=FALSE],use="pairwise.complete.obs")
      tri_mean<-function(R) { if(nrow(R)<2) return(1); mean(abs(R[lower.tri(R)]),na.rm=TRUE) }
      mean(abs(Rij),na.rm=TRUE)/sqrt(tri_mean(Rii)*tri_mean(Rjj))
    }
    cv <- names(item_map); if (length(cv)<2) return(NULL)
    rows <- list()
    for (i in 1:(length(cv)-1)) for (j in (i+1):length(cv)) {
      ci_h<-cv[i]; cj_h<-cv[j]
      htmt_orig <- tryCatch(calc_htmt_pair(raw_df,item_map[[ci_h]],item_map[[cj_h]]),error=function(e) NA_real_)
      boot_vals <- replicate(n_boot, {
        idx<-sample(nrow(raw_df),nrow(raw_df),replace=TRUE)
        tryCatch(calc_htmt_pair(raw_df[idx,,drop=FALSE],item_map[[ci_h]],item_map[[cj_h]]),error=function(e) NA_real_)
      })
      boot_vals <- boot_vals[!is.na(boot_vals)]
      if (length(boot_vals)<10) next
      ci_lo<-round(quantile(boot_vals,0.025),3); ci_hi<-round(quantile(boot_vals,0.975),3)
      rows[[length(rows)+1]] <- data.frame(
        Par=paste0(ci_h," ↔ ",cj_h), HTMT=round(htmt_orig,3),
        IC_2.5=ci_lo, IC_97.5=ci_hi,
        OK_CI=ifelse(!is.na(ci_hi)&&ci_hi<0.85,"✓ IC sup <0.85",
               ifelse(!is.na(ci_hi)&&ci_hi<0.90,"⚠ IC sup 0.85-0.90 (marginal)","✗ IC sup ≥0.90")),
        Referencia="Henseler et al. (2015)",stringsAsFactors=FALSE)
    }
    if (length(rows)>0) { out<-do.call(rbind,rows); rownames(out)<-NULL; out } else NULL
  },error=function(e) NULL)
}

# ── Full Collinearity VIF — CMB (Kock, 2015) ─────────────────────────────────
calc_full_vif <- function(scores_df) {
  tryCatch({
    if (is.null(scores_df)||ncol(scores_df)<2) return(NULL)
    all_lv <- names(scores_df)
    rows <- list()
    for (lv in all_lv) {
      otros <- setdiff(all_lv,lv); otros<-otros[otros%in%names(scores_df)]
      if (!length(otros)) next
      fml <- as.formula(paste0("`",lv,"` ~ ",paste0("`",otros,"`",collapse="+")))
      fit <- tryCatch(stats::lm(fml,data=scores_df[,c(lv,otros),drop=FALSE]),error=function(e) NULL)
      if (is.null(fit)) next
      r2 <- summary(fit)$r.squared
      vif_v <- if (!is.na(r2)&&r2<0.9999) round(1/(1-r2),3) else 999.0
      rows[[length(rows)+1]] <- data.frame(
        Variable_Latente=lv, VIF_Full=vif_v,
        Estado=ifelse(vif_v<3.3,"✓ Sin riesgo CMB (<3.3)","✗ Posible CMB (≥3.3)"),
        Referencia="Kock (2015)",stringsAsFactors=FALSE)
    }
    if (length(rows)>0) { out<-do.call(rbind,rows); rownames(out)<-NULL; out } else NULL
  },error=function(e) NULL)
}

# ── Gaussian Copula Endogeneity Test — Park & Gupta (2012) ───────────────────
calc_gaussian_copula <- function(scores_df, p_df, paths_tbl=NULL) {
  tryCatch({
    if (is.null(scores_df)||is.null(p_df)) return(NULL)
    endogenous <- intersect(unique(p_df$to),names(scores_df))
    exogenous  <- intersect(setdiff(unique(p_df$from),endogenous),names(scores_df))
    if (!length(exogenous)||!length(endogenous)) return(NULL)
    pls_beta_lookup <- list()
    if (!is.null(paths_tbl)&&is.data.frame(paths_tbl)&&nrow(paths_tbl)>0) {
      for (k in seq_len(nrow(paths_tbl))) {
        key <- gsub("\\s+","",as.character(paths_tbl$Path[k]))
        pls_beta_lookup[[key]] <- suppressWarnings(as.numeric(paths_tbl$Beta[k]))
      }
    }
    rows <- list()
    for (y_nm in endogenous) {
      preds <- intersect(p_df$from[p_df$to==y_nm],names(scores_df))
      if (!length(preds)) next
      y_vec <- as.numeric(scores_df[[y_nm]])
      for (x_nm in preds) {
        x_vec <- as.numeric(scores_df[[x_nm]])
        valid <- !is.na(x_vec)&!is.na(y_vec)
        if (sum(valid)<10) next
        xv<-x_vec[valid]; yv<-y_vec[valid]; n<-length(xv)
        ranks <- rank(xv,ties.method="average")
        uniform <- ranks/(n+1)
        copula_term <- qnorm(uniform)
        other_preds <- setdiff(preds,x_nm)
        reg_data <- data.frame(Y_end=yv,X_pred=xv,Cop_term=copula_term,stringsAsFactors=FALSE)
        op_safe <- character(0)
        for (op in other_preds) {
          sn <- paste0("ctrl_",make.names(op))
          reg_data[[sn]] <- as.numeric(scores_df[[op]])[valid]
          op_safe <- c(op_safe,sn)
        }
        reg_data <- reg_data[complete.cases(reg_data),,drop=FALSE]
        if (nrow(reg_data)<10) next
        fml <- as.formula(paste0("Y_end ~ X_pred + Cop_term",if(length(op_safe)) paste0(" + ",paste(op_safe,collapse=" + ")) else ""))
        fit <- tryCatch(stats::lm(fml,data=reg_data),error=function(e) NULL)
        if (is.null(fit)) next
        cs <- tryCatch(summary(fit)$coefficients,error=function(e) NULL)
        if (is.null(cs)||!"Cop_term"%in%rownames(cs)) next
        copula_coef<-cs["Cop_term","Estimate"]; copula_se<-cs["Cop_term","Std. Error"]
        copula_t<-cs["Cop_term","t value"]; copula_p<-cs["Cop_term","Pr(>|t|)"]
        ci_lo<-copula_coef-1.96*copula_se; ci_hi<-copula_coef+1.96*copula_se
        path_key <- gsub("\\s+","",paste0(x_nm,"->",y_nm))
        pls_beta <- pls_beta_lookup[[path_key]] %||% NA_real_
        interp <- if (is.na(copula_p)) "N/A" else if (copula_p<0.05) "⚠ Posible endogeneidad (p < 0.05)" else "✓ Sin evidencia de endogeneidad (p ≥ 0.05)"
        rows[[length(rows)+1]] <- data.frame(
          Ruta=paste0(x_nm," → ",y_nm), Predictor=x_nm, Endogeno=y_nm,
          PLS_Beta=round(pls_beta,4), Copula_Coef=round(copula_coef,4),
          Std_Error=round(copula_se,4), t_valor=round(copula_t,3),
          p_valor=round(copula_p,4), IC_lo=round(ci_lo,4), IC_hi=round(ci_hi,4),
          N=nrow(reg_data), Interpretacion=interp,
          Referencia="Park & Gupta (2012)",stringsAsFactors=FALSE)
      }
    }
    if (length(rows)>0) { out<-do.call(rbind,rows); rownames(out)<-NULL; out } else NULL
  },error=function(e) NULL)
}


# ── MICOM: Measurement Invariance of Composite Models ────────────────────────
# Henseler et al. (2016) / Hair et al. (2022, Ch.7)
calc_micom <- function(raw_df, p_df, pls_est, summ, group_var, n_permut=500L, m_model=NULL, s_model=NULL) {
  tryCatch({
    if(is.null(group_var)||!nzchar(group_var)||!group_var%in%names(raw_df)) return(NULL)
    grupos <- sort(unique(as.character(raw_df[[group_var]])))
    if(length(grupos)<2) return(NULL)
    item_cols <- setdiff(names(raw_df),group_var)
    ld <- as.matrix(summ$loadings)
    constructs_nm <- colnames(ld)
    # Estimar PLS por grupo
    suppressPackageStartupMessages({library(seminr)})
    weights_g <- list(); scores_g <- list()
    for(g in grupos) {
      dat_g <- raw_df[as.character(raw_df[[group_var]])==g,item_cols,drop=FALSE]
      dat_g <- as.data.frame(lapply(dat_g,function(x)suppressWarnings(as.numeric(as.character(x)))))
      dat_g <- dat_g[complete.cases(dat_g),]
      if(nrow(dat_g)<10) next
      pls_g <- tryCatch(estimate_pls(data=dat_g,
        measurement_model=m_model,
        structural_model=s_model),error=function(e)NULL)
      if(is.null(pls_g)) next
      weights_g[[g]] <- tryCatch(as.matrix(pls_g$outer_weights),error=function(e)NULL)
      scores_g[[g]]  <- tryCatch(as.data.frame(pls_g$construct_scores),error=function(e)NULL)
    }
    if(length(weights_g)<2) return(NULL)
    pairs <- combn(grupos,2,simplify=FALSE)
    rows <- list()
    for(pr in pairs) {
      g1<-pr[1]; g2<-pr[2]
      if(is.null(weights_g[[g1]])||is.null(weights_g[[g2]])) next
      w1<-weights_g[[g1]]; w2<-weights_g[[g2]]
      dat1<-raw_df[as.character(raw_df[[group_var]])==g1,item_cols,drop=FALSE]
      dat2<-raw_df[as.character(raw_df[[group_var]])==g2,item_cols,drop=FALSE]
      dat1<-as.data.frame(lapply(dat1,function(x)suppressWarnings(as.numeric(as.character(x)))))
      dat2<-as.data.frame(lapply(dat2,function(x)suppressWarnings(as.numeric(as.character(x)))))
      for(cn in constructs_nm) {
        if(!cn%in%colnames(w1)||!cn%in%colnames(w2)) next
        items_cn <- intersect(rownames(w1),rownames(w2))
        items_cn <- items_cn[items_cn%in%names(dat1)&items_cn%in%names(dat2)]
        if(!length(items_cn)) next
        w1v<-w1[items_cn,cn]; w2v<-w2[items_cn,cn]
        X_pool <- as.matrix(rbind(dat1[,items_cn,drop=FALSE],dat2[,items_cn,drop=FALSE]))
        X_pool[is.na(X_pool)] <- 0
        c1<-as.numeric(X_pool%*%w1v); c2<-as.numeric(X_pool%*%w2v)
        r_orig <- tryCatch(cor(c1,c2),error=function(e)NA_real_)
        if(is.na(r_orig)) next
        r_perms <- replicate(n_permut,{
          Xs<-X_pool[sample(nrow(X_pool)),,drop=FALSE]
          tryCatch(cor(as.numeric(Xs%*%w1v),as.numeric(Xs%*%w2v)),error=function(e)NA_real_)
        })
        r_perms <- r_perms[!is.na(r_perms)]
        p_r <- if(length(r_perms)>0) mean(r_perms>=r_orig) else NA_real_
        inv_comp <- !is.na(r_orig)&&r_orig>=0.90
        # Paso 3: medias y varianzas
        sc1 <- scores_g[[g1]]; sc2 <- scores_g[[g2]]
        p_med <- p_var <- NA_real_
        if(!is.null(sc1)&&!is.null(sc2)&&cn%in%names(sc1)&&cn%in%names(sc2)) {
          v1<-sc1[[cn]]; v2<-sc2[[cn]]
          obs_md<-mean(v1)-mean(v2); obs_vd<-var(v1)-var(v2)
          all_sc<-c(v1,v2); n1<-length(v1)
          pm_dist<-replicate(n_permut,{s<-sample(all_sc); mean(s[1:n1])-mean(s[(n1+1):length(s)])})
          pv_dist<-replicate(n_permut,{s<-sample(all_sc); var(s[1:n1])-var(s[(n1+1):length(s)])})
          p_med<-round(mean(abs(pm_dist)>=abs(obs_md)),3)
          p_var<-round(mean(abs(pv_dist)>=abs(obs_vd)),3)
        }
        resultado <- if(!inv_comp) "No invariante" else if(!is.na(p_med)&&!is.na(p_var)&&p_med>=0.05&&p_var>=0.05) "Invarianza total" else "Invarianza parcial"
        rows[[length(rows)+1]] <- data.frame(
          Constructo=cn, Grupos=paste0(g1," vs ",g2),
          Correlacion_original=round(r_orig,3), p_permutacion=round(p_r,3),
          Invarianza_composicional=ifelse(inv_comp,"Si (r>=0.90)","No (r<0.90)"),
          p_dif_medias=p_med, p_dif_varianzas=p_var, Resultado=resultado,
          Referencia="Henseler et al.(2016); Hair et al.(2022,Ch.7)",
          stringsAsFactors=FALSE)
      }
    }
    if(length(rows)>0){out<-do.call(rbind,rows);rownames(out)<-NULL;out} else NULL
  },error=function(e)NULL)
}

# ── MGA: Multi-Group Analysis (Permutation Test) ────────────────────────────
# Implementacion exacta de Henseler, Ringle & Sarstedt (2016) / SmartPLS 4
calc_mga <- function(raw_df, paths_tbl, pls_est, summ, group_var, n_permut=500L, m_model=NULL, s_model=NULL) {
  tryCatch({
    if(is.null(group_var)||!nzchar(group_var)||!group_var%in%names(raw_df)) return(NULL)
    if(is.null(m_model)||is.null(s_model)) return(NULL)
    n_tab  <- table(as.character(raw_df[[group_var]]))
    grupos <- sort(names(n_tab)[n_tab>=20])
    if(length(grupos)<2) return(NULL)
    item_cols <- setdiff(names(raw_df),group_var)
    suppressPackageStartupMessages({library(seminr)})

    get_paths_mga <- function(dat) {
      dat_n <- as.data.frame(lapply(dat,function(x)suppressWarnings(as.numeric(as.character(x)))))
      dat_n <- dat_n[complete.cases(dat_n),]
      if(nrow(dat_n)<10) return(NULL)
      pls_g <- tryCatch(
        estimate_pls(data=dat_n, measurement_model=m_model, structural_model=s_model),
        error=function(e) {
          if(grepl("singular|dgesv|rank-deficient",e$message,ignore.case=TRUE)) {
            dat_r <- as.data.frame(lapply(dat_n,function(col)if(is.numeric(col))jitter(col,amount=0.001) else col))
            tryCatch(estimate_pls(data=dat_r,measurement_model=m_model,structural_model=s_model),error=function(e2)NULL)
          } else NULL
        })
      if(is.null(pls_g)) return(NULL)
      pm <- tryCatch({p<-pls_g$path_coef; if(is.null(p)) p<-as.matrix(summary(pls_g)$paths); as.matrix(p)},error=function(e)NULL)
      if(is.null(pm)) return(NULL)
      out <- list()
      for(r in rownames(pm)) for(cl in colnames(pm)) {
        val <- suppressWarnings(as.numeric(pm[r,cl]))
        if(!is.na(val)&&abs(val)>1e-10) out[[paste0(trimws(r)," -> ",trimws(cl))]] <- val
      }
      out
    }

    paths_obs <- list()
    for(g in grupos) {
      dat_g <- raw_df[raw_df[[group_var]]==g,item_cols,drop=FALSE]
      paths_obs[[g]] <- get_paths_mga(dat_g)
      if(is.null(paths_obs[[g]])) return(NULL)
    }
    paths_comunes <- Reduce(intersect,lapply(paths_obs,names))
    if(!length(paths_comunes)) return(NULL)

    pairs <- combn(grupos,2,simplify=FALSE)
    rows <- list()
    for(pr in pairs) {
      g1<-pr[1]; g2<-pr[2]
      dat1<-raw_df[raw_df[[group_var]]==g1,item_cols,drop=FALSE]
      dat2<-raw_df[raw_df[[group_var]]==g2,item_cols,drop=FALSE]
      dat_pair<-rbind(dat1,dat2); n1<-nrow(dat1)
      for(path_nm in paths_comunes) {
        b1<-paths_obs[[g1]][[path_nm]]; b2<-paths_obs[[g2]][[path_nm]]
        if(is.null(b1)||is.null(b2)) next
        obs_diff <- b1-b2
        perm_diffs <- replicate(n_permut,{
          idx<-sample(nrow(dat_pair))
          dp1<-dat_pair[idx[1:n1],item_cols,drop=FALSE]
          dp2<-dat_pair[idx[(n1+1):nrow(dat_pair)],item_cols,drop=FALSE]
          bt1<-tryCatch({b<-get_paths_mga(dp1);if(!is.null(b)&&!is.null(b[[path_nm]]))b[[path_nm]] else NA_real_},error=function(e)NA_real_)
          bt2<-tryCatch({b<-get_paths_mga(dp2);if(!is.null(b)&&!is.null(b[[path_nm]]))b[[path_nm]] else NA_real_},error=function(e)NA_real_)
          if(is.na(bt1)||is.na(bt2)) NA_real_ else bt1-bt2
        })
        pd_ok <- perm_diffs[!is.na(perm_diffs)]
        if(length(pd_ok)<3){p_val<-pd_mu<-pd_lo<-pd_hi<-NA_real_} else {
          p_val<-round(mean(abs(pd_ok)>=abs(obs_diff)),3)
          pd_mu<-round(mean(pd_ok),3)
          pd_lo<-round(quantile(pd_ok,0.025),3)
          pd_hi<-round(quantile(pd_ok,0.975),3)
        }
        sig<-if(is.na(p_val))"N/D" else if(p_val<0.001)"***" else if(p_val<0.01)"**" else if(p_val<0.05)"*" else "n.s."
        row_df <- data.frame(Relacion=path_nm,stringsAsFactors=FALSE)
        row_df[[paste0("Beta_",g1)]] <- round(b1,3)
        row_df[[paste0("Beta_",g2)]] <- round(b2,3)
        row_df$Diferencia <- round(obs_diff,3)
        row_df$Media_perm <- pd_mu
        row_df$IC_2.5     <- pd_lo
        row_df$IC_97.5    <- pd_hi
        row_df$p_valor    <- p_val
        row_df$Sig        <- sig
        row_df$Grupos     <- paste0(g1," vs ",g2)
        rows[[length(rows)+1]] <- row_df
      }
    }
    if(length(rows)>0){
      # Convertir cada data.frame de 1 fila a lista plana
      lapply(rows, function(df) as.list(df[1,,drop=FALSE]))
    } else NULL
  },error=function(e)NULL)
}

# ── IPMA: Importance-Performance Map Analysis ─────────────────────────────────
# Ringle & Sarstedt (2016) / Hair et al. (2022, Ch.9)
calc_ipma <- function(pls_est, summ, scores_df, raw_df, total_tbl, p_df,
                      target=NULL, scale_min=1, scale_max=5) {
  tryCatch({
    if(is.null(scores_df)||is.null(total_tbl)||!length(total_tbl)) return(NULL)
    endogenous <- unique(p_df$to)
    if(is.null(target)) target <- endogenous[length(endogenous)]
    if(!target%in%names(scores_df)) return(NULL)
    # Importancia = efecto total sobre el target
    te_rows <- total_tbl[grepl(paste0("->[[:space:]]*",target,"$"),total_tbl$Relacion),]
    if(!nrow(te_rows)) return(NULL)
    te_rows$Predictor <- trimws(sub("[[:space:]]*->.*","",te_rows$Relacion))
    # Performance: media rescalada a 0-100
    perf_cs <- sapply(names(scores_df),function(cn) {
      raw_sc <- scores_df[[cn]]
      m <- mean(raw_sc,na.rm=TRUE)
      if(abs(m)<0.5&&sd(raw_sc,na.rm=TRUE)<2) {
        mn<-min(raw_sc,na.rm=TRUE); mx<-max(raw_sc,na.rm=TRUE)
        if(mx==mn) return(50)
        return(round((m-mn)/(mx-mn)*100,2))
      }
      rng <- scale_max-scale_min
      if(rng<=0) return(NA_real_)
      round(pmax(0,pmin(100,(m-scale_min)/rng*100)),2)
    })
    preds <- te_rows$Predictor
    imp   <- as.numeric(te_rows$Total)
    perf  <- perf_cs[preds]
    mean_imp  <- mean(abs(imp),na.rm=TRUE)
    mean_perf <- mean(perf,na.rm=TRUE)
    quadrant  <- ifelse(abs(imp)>=mean_imp&perf<mean_perf,"Alta Imp / Baja Perf — MEJORAR",
                 ifelse(abs(imp)>=mean_imp&perf>=mean_perf,"Alta Imp / Alta Perf — MANTENER",
                 ifelse(abs(imp)<mean_imp&perf<mean_perf,"Baja Imp / Baja Perf — MONITOREAR",
                        "Baja Imp / Alta Perf — Sobreinversión?")))
    out <- data.frame(
      Target=target, Predictor=preds,
      Importancia_Efecto_Total=round(imp,4),
      Performance_0_100=round(perf,2),
      Cuadrante=quadrant,
      Prioridad=ifelse(quadrant=="Alta Imp / Baja Perf — MEJORAR","Alta","Normal"),
      Referencia="Ringle & Sarstedt (2016); Hair et al.(2022,Ch.9)",
      stringsAsFactors=FALSE)
    rownames(out) <- NULL; out
  },error=function(e)NULL)
}


run_pls_sem <- function(params) {
  ext <- tolower(tools::file_ext(params$data_path))
  df_raw <- if (ext %in% c("xlsx","xls")) openxlsx::read.xlsx(params$data_path) else read.csv(params$data_path,stringsAsFactors=FALSE)
  df_num <- as.data.frame(lapply(df_raw,function(x) suppressWarnings(as.numeric(as.character(x)))))
  names(df_num) <- gsub("[^[:alnum:]]","_",names(df_raw))
  df_num <- df_num[complete.cases(df_num),]
  raw_df <- df_num
  set.seed(42)
  df_j <- as.data.frame(lapply(df_num,function(col) if(is.numeric(col)&&length(unique(col))>5) jitter(col,amount=1e-4) else col))
  N <- nrow(df_j)

  # Guard: detectar constructos de un solo indicador antes de procesar
  single_item_constructs <- Filter(Negate(is.null), lapply(params$constructs, function(ct) {
    avail <- intersect(ct$items, names(df_j))
    if (length(avail) == 1) list(name=ct$name, item=avail[1]) else NULL
  }))
  if (length(single_item_constructs) > 0) {
    bad_names <- sapply(single_item_constructs, function(x) x$name)
    return(list(
      blocked = TRUE,
      reason  = "SINGLE_ITEM_CONSTRUCTS",
      error   = paste0(
        "Los constructos [", paste(bad_names, collapse=", "), "] tienen un solo indicador disponible. ",
        "PLS-SEM requiere al menos 2 indicadores por constructo para estimar cargas factoriales. ",
        "La duplicacion de indicadores con jitter es metodologicamente invalida y produce resultados ",
        "artificiales. Agregue al menos un indicador adicional a cada constructo afectado, ",
        "o elimine el constructo del modelo."
      ),
      single_item_constructs = single_item_constructs
    ))
  }
  c_seminr <- list()
  for (ct in params$constructs) {
    avail <- intersect(ct$items,names(df_j)); if (!length(avail)) next
    c_seminr[[length(c_seminr)+1]] <- seminr::composite(ct$name,seminr::multi_items("",avail))
  }
  if (!length(c_seminr)) stop("Ningun constructo valido.")
  m_model <- do.call(seminr::constructs,c_seminr)

  p_seminr <- list(); p_df <- data.frame(from=character(),to=character(),stringsAsFactors=FALSE)
  for (pt in params$paths) {
    p_seminr[[length(p_seminr)+1]] <- seminr::paths(from=pt$from,to=pt$to)
    p_df <- rbind(p_df,data.frame(from=pt$from,to=pt$to,stringsAsFactors=FALSE))
  }
  if (!length(p_seminr)) stop("Ninguna relacion estructural.")
  s_model <- do.call(seminr::relationships,p_seminr)

  pls_est <- tryCatch(estimate_pls(data=df_j,measurement_model=m_model,structural_model=s_model),
    error=function(e) { df_r <- as.data.frame(lapply(df_j,function(col) if(is.numeric(col)) jitter(col,amount=0.001) else col)); estimate_pls(data=df_r,measurement_model=m_model,structural_model=s_model) })
  summ     <- summary(pls_est)
  scores_df <- tryCatch(as.data.frame(pls_est$construct_scores),error=function(e) NULL)

  n_boot <- as.integer(params$n_boot %||% 500)
  set.seed(123)
  boot_est  <- tryCatch(bootstrap_model(seminr_model=pls_est,nboot=n_boot,cores=1,seed=123),error=function(e) NULL)
  boot_summ <- if (!is.null(boot_est)) tryCatch(summary(boot_est),error=function(e) NULL) else NULL
  bp        <- if (!is.null(boot_summ)) tryCatch(as.data.frame(boot_summ$bootstrapped_paths),error=function(e) NULL) else NULL

  path_keys <- paste0(p_df$from," -> ",p_df$to); df_t <- max(N-1,1)

  if (!is.null(bp)&&nrow(bp)>0) {
    path_lbl <- rownames(bp)
    nc <- which(sapply(bp,function(x)!all(is.na(suppressWarnings(as.numeric(x))))))
    beta_v  <- if(length(nc)>=1) suppressWarnings(as.numeric(bp[[nc[1]]])) else rep(NA_real_,nrow(bp))
    se_v    <- if(length(nc)>=3) suppressWarnings(as.numeric(bp[[nc[3]]])) else rep(NA_real_,nrow(bp))
    ci_lo_v <- if(length(nc)>=5) suppressWarnings(as.numeric(bp[[nc[5]]])) else beta_v-1.96*se_v
    ci_hi_v <- if(length(nc)>=6) suppressWarnings(as.numeric(bp[[nc[6]]])) else beta_v+1.96*se_v
  } else {
    pm_fb <- tryCatch(as.matrix(pls_est$path_coef),error=function(e) NULL)
    path_lbl <- path_keys
    beta_v <- sapply(path_keys,function(pk){ pt<-strsplit(pk," -> ")[[1]]; if(!is.null(pm_fb)&&length(pt)==2&&pt[1]%in%rownames(pm_fb)&&pt[2]%in%colnames(pm_fb)) as.numeric(pm_fb[pt[1],pt[2]]) else NA_real_ })
    se_v <- ci_lo_v <- ci_hi_v <- rep(NA_real_,length(path_keys))
  }

  STDEV_raw <- suppressWarnings(as.numeric(se_v)); STDEV_raw[STDEV_raw==0] <- NA
  beta_v <- suppressWarnings(as.numeric(beta_v)); T_raw <- beta_v/STDEV_raw; p_raw <- 2*(1-pt(abs(T_raw),df=df_t))

  f2_tbl <- calc_f2(scores_df,p_df)
  f2_map <- if(!is.null(f2_tbl)) setNames(f2_tbl$f2,gsub("\\s+","",f2_tbl$Path)) else c()

  paths_tbl <- data.frame(Path=path_lbl,Beta=round(beta_v,3),STDEV=round(STDEV_raw,3),T_Valor=round(T_raw,3),P_Valor=round(p_raw,4),
    IC_2.5=round(ci_lo_v,3),IC_97.5=round(ci_hi_v,3),
    Sig=ifelse(p_raw<0.001,"***",ifelse(p_raw<0.01,"**",ifelse(p_raw<0.05,"*",ifelse(p_raw<0.10,"\u2020","n.s.")))),
    f2=sapply(gsub("\\s+","",path_lbl),function(k) f2_map[k]%||%NA_real_),stringsAsFactors=FALSE)

  rel_raw <- tryCatch(as.data.frame(summ$reliability),error=function(e) NULL)
  cr_ave_calc <- calc_cr_ave(summ$loadings); constructs_rel <- if(!is.null(rel_raw)) rownames(rel_raw) else cr_ave_calc$Constructo
  cr_map <- setNames(cr_ave_calc$CR,cr_ave_calc$Constructo); ave_map <- setNames(cr_ave_calc$AVE,cr_ave_calc$Constructo)
  alpha_v <- if(!is.null(rel_raw)) { idx<-grep("cronbach|alpha",tolower(names(rel_raw)))[1]; if(!is.na(idx)) suppressWarnings(as.numeric(rel_raw[[idx]])) else rep(NA_real_,length(constructs_rel)) } else rep(NA_real_,length(constructs_rel))
  rhoa_v  <- if(!is.null(rel_raw)) { idx<-grep("rho_a|rhoa",tolower(names(rel_raw)))[1]; if(!is.na(idx)) suppressWarnings(as.numeric(rel_raw[[idx]])) else rep(NA_real_,length(constructs_rel)) } else rep(NA_real_,length(constructs_rel))

  reliability_tbl <- data.frame(Constructo=constructs_rel,Cronbach_Alpha=round(alpha_v,3),rho_A=round(rhoa_v,3),
    Composite_Reliability_CR=sapply(cr_map[constructs_rel],safe_num),AVE=sapply(ave_map[constructs_rel],safe_num),check.names=FALSE,stringsAsFactors=FALSE)

  ld <- summ$loadings
  loadings_tbl <- as.data.frame(as.table(ld)) %>% filter(Freq!=0) %>% rename(Item=Var1,Constructo=Var2,Loading=Freq) %>%
    mutate(Loading=round(as.numeric(Loading),3),OK=ifelse(Loading>=0.7,"\u2713",ifelse(Loading>=0.4,"\u26a0","\u2717")))

  r2_tbl <- data.frame(Constructo=character(),R2=numeric(),R2_adj=numeric(),Nivel=character(),stringsAsFactors=FALSE)
  for (endo in unique(p_df$to)) {
    preds <- unique(p_df$from[p_df$to==endo]); preds <- preds[preds %in% names(scores_df)]
    if (!length(preds)||!endo %in% names(scores_df)) next
    fit <- tryCatch(stats::lm(y~.,data=data.frame(y=scores_df[[endo]],scores_df[,preds,drop=FALSE])),error=function(e) NULL)
    if (!is.null(fit)) { s<-summary(fit); r2_tbl <- rbind(r2_tbl,data.frame(Constructo=endo,R2=round(s$r.squared,3),R2_adj=round(s$adj.r.squared,3),Nivel=ifelse(s$r.squared>=0.75,"Sustancial",ifelse(s$r.squared>=0.50,"Moderado",ifelse(s$r.squared>=0.25,"D\u00e9bil","Muy d\u00e9bil"))),stringsAsFactors=FALSE)) }
  }

  hyp_rows <- lapply(seq_len(nrow(paths_tbl)),function(k) data.frame(Hipotesis=paste0("H",k),Relacion=paths_tbl$Path[k],Beta=paths_tbl$Beta[k],T_Valor=paths_tbl$T_Valor[k],P_Valor=paths_tbl$P_Valor[k],Sig=paths_tbl$Sig[k],Decision=ifelse(!is.na(paths_tbl$P_Valor[k])&paths_tbl$P_Valor[k]<0.05,"\u2713 Soportada","\u2717 Rechazada"),stringsAsFactors=FALSE))

  indirect_tbl <- calc_indirect(paths_tbl,p_df,boot_summ)
  total_tbl    <- calc_total(paths_tbl,indirect_tbl,p_df)
  # Mapa de items por constructo
  construct_items_map <- setNames(
    lapply(params$constructs, function(ct) ct$items),
    sapply(params$constructs, function(ct) ct$name))
  pls_predict_tbl <- if (as.logical(params$calc_predict %||% TRUE))
    calc_pls_predict(pls_est,summ,scores_df,raw_df,p_df,construct_items_map,k_folds=10L,seed=42L) else NULL
  vaf_tbl          <- calc_vaf_mediation(paths_tbl,indirect_tbl,p_df)
  group_var        <- params$group_var %||% NULL
  micom_tbl        <- if(!is.null(group_var)&&nzchar(group_var)) calc_micom(raw_df,p_df,pls_est,summ,group_var,n_permut=min(as.integer(n_boot),500L),m_model=m_model,s_model=s_model) else NULL
  mga_tbl          <- if(!is.null(group_var)&&nzchar(group_var)) calc_mga(raw_df,paths_tbl,pls_est,summ,group_var,n_permut=min(as.integer(n_boot),500L),m_model=m_model,s_model=s_model) else NULL
  ipma_target      <- params$ipma_target %||% NULL
  scale_min        <- as.numeric(params$scale_min %||% 1)
  scale_max        <- as.numeric(params$scale_max %||% 5)
  ipma_tbl         <- calc_ipma(pls_est,summ,scores_df,raw_df,total_tbl,p_df,ipma_target,scale_min,scale_max)
  htmt_ci_tbl      <- calc_htmt_ci(raw_df,summ,n_boot=min(as.integer(n_boot),500L),seed=123L)
  full_vif_tbl     <- calc_full_vif(scores_df)
  copula_tbl       <- calc_gaussian_copula(scores_df,p_df,paths_tbl)
  q2_flag      <- as.logical(params$calc_q2 %||% FALSE)

  list(success=TRUE,engine="canchari_pls_sem_v5",n_observations=N,n_boot=n_boot,
    tables=list(
      Paths=paths_tbl, Confiabilidad=reliability_tbl, Cargas=loadings_tbl,
      R2=r2_tbl, Hypotheses=do.call(rbind,hyp_rows),
      HTMT=calc_htmt(summ,raw_df), FornellLarcker=calc_fornell_larcker(summ,scores_df),
      CrossLoadings=calc_cross_loadings(summ,scores_df,raw_df),
      VIF=calc_vif(scores_df,p_df),
      SRMR=tryCatch({
        sc_s <- tryCatch(as.data.frame(pls_est$construct_scores),error=function(e)NULL)
        ld_s <- tryCatch(as.matrix(summ$loadings),error=function(e)NULL)
        if(!is.null(sc_s)&&!is.null(ld_s)&&!is.null(raw_df)){
          its <- rownames(ld_s)[rownames(ld_s)%in%names(raw_df)]
          cns <- colnames(ld_s)[colnames(ld_s)%in%names(sc_s)]
          if(length(its)>=2&&length(cns)>=1){
            S <- cor(raw_df[,its,drop=FALSE],use="pairwise.complete.obs")
            phi <- cor(sc_s[,cns,drop=FALSE],use="pairwise.complete.obs")
            lam <- ld_s[its,cns,drop=FALSE]
            S_hat <- lam%*%phi%*%t(lam); diag(S_hat)<-1
            p2 <- nrow(S); resid2 <- S-S_hat
            v2 <- round(sqrt(sum(resid2[lower.tri(resid2)]^2)/(p2*(p2-1)/2)),4)
            data.frame(Indice="SRMR",Valor=v2,
              Criterio=ifelse(v2<=0.08,"\u2713 Buen ajuste (\u2264 0.08)",ifelse(v2<=0.10,"\u26a0 Aceptable (\u2264 0.10)","\u2717 Cuestionable (>0.10)")),
              Referencia="Hu & Bentler (1999); Hair et al. (2022)",stringsAsFactors=FALSE)
          } else NULL
        } else NULL
      },error=function(e)NULL),
      Q2=if(q2_flag) calc_q2(scores_df,p_df,as.integer(params$omission_distance%||%7)) else NULL,
      IndirectEffects=indirect_tbl, TotalEffects=total_tbl,
      PLSPredict=pls_predict_tbl,
      VAF_Mediacion=vaf_tbl,
      HTMT_CI=htmt_ci_tbl,
      FullVIF_CMB=full_vif_tbl,
      GaussianCopula=copula_tbl,
      MICOM=micom_tbl,
      MGA=mga_tbl,
      IPMA=ipma_tbl))
}

# Limpiar columnas _row de todos los data.frames en la lista de tablas
clean_tables <- function(tables) {
  lapply(tables, function(tbl) {
    if (is.data.frame(tbl) && nrow(tbl) > 0) {
      tbl <- tbl[, !names(tbl) %in% c("_row"), drop=FALSE]
      rownames(tbl) <- NULL
      # Para data.frames con 1 fila o columnas dinámicas, forzar como lista de listas
      return(tbl)
    } else if (is.data.frame(tbl) && nrow(tbl) == 0) {
      return(NULL)
    } else if (is.list(tbl) && !is.data.frame(tbl)) {
      tbl <- lapply(tbl, function(x) {
        if (is.data.frame(x)) { x <- x[, !names(x) %in% c("_row"), drop=FALSE]; rownames(x) <- NULL }
        x
      })
    }
    tbl
  })
}

# Guard: only run CLI block when this file is the main script being executed.
# When source()d from tests, .pls_sem_is_main() returns FALSE and the block is skipped,
# which prevents quit() from terminating the calling R process.
.pls_sem_is_main <- function() {
  fa <- commandArgs(trailingOnly = FALSE)
  f  <- sub("--file=", "", grep("--file=", fa, value = TRUE))
  length(f) > 0 && grepl("pls_sem_engine\\.R$", normalizePath(f, mustWork = FALSE))
}

if (!interactive() && .pls_sem_is_main()) {
  args <- commandArgs(trailingOnly=TRUE)
  if (!length(args)) { cat(jsonlite::toJSON(list(success=FALSE,error="Sin parametros"),auto_unbox=TRUE)); quit(status=1) }
  params <- tryCatch(jsonlite::fromJSON(args[1],simplifyVector=FALSE),error=function(e) NULL)
  if (is.null(params)) { cat(jsonlite::toJSON(list(success=FALSE,error="JSON invalido"),auto_unbox=TRUE)); quit(status=1) }
  result <- tryCatch(run_pls_sem(params),error=function(e) list(success=FALSE,error=e$message))
  if (!is.null(result$tables)) result$tables <- clean_tables(result$tables)
  cat(jsonlite::toJSON(result,auto_unbox=TRUE,na="null"))
}
