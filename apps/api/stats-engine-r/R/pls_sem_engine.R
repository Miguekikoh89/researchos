# ============================================================================
# CANCHARIOS PLS-SEM ENGINE — núcleo certificable
# El núcleo de medición, rutas estructurales y bootstrap se estima con seminr.
# Los módulos avanzados sin referencia numérica independiente permanecen
# desactivados de forma explícita (fail-closed).
# ============================================================================
suppressPackageStartupMessages({
  library(seminr); library(jsonlite); library(dplyr); library(openxlsx)
})
`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b
safe_num <- function(x, digits=3) { val <- suppressWarnings(as.numeric(x[1])); if(is.na(val)) NA_real_ else round(val,digits) }


normalize_boot_name <- function(x) {
  gsub("[^a-z0-9]+", "", tolower(as.character(x)))
}

find_boot_col <- function(tbl, candidates) {
  if (is.null(tbl) || !ncol(tbl)) return(NA_integer_)
  nn <- normalize_boot_name(names(tbl))
  cc <- normalize_boot_name(candidates)
  hit <- match(cc, nn, nomatch=0L)
  hit <- hit[hit > 0L]
  if (length(hit)) return(hit[1])
  for (pat in cc) {
    idx <- grep(pat, nn, fixed=TRUE)
    if (length(idx)) return(idx[1])
  }
  NA_integer_
}

extract_boot_table <- function(tbl, table_name="bootstrap") {
  if (is.null(tbl) || !is.data.frame(tbl) || nrow(tbl) < 1L) return(NULL)

  estimate_col <- find_boot_col(tbl, c(
    "original estimate", "original est", "original", "estimate", "path estimate"
  ))
  se_col <- find_boot_col(tbl, c(
    "bootstrap sd", "boot sd", "standard error", "std error", "stdev", "std dev", "se"
  ))
  lower_col <- find_boot_col(tbl, c(
    "2.5% ci", "2.5 ci", "lower ci", "ci lower", "lower", "025", "2.5%"
  ))
  upper_col <- find_boot_col(tbl, c(
    "97.5% ci", "97.5 ci", "upper ci", "ci upper", "upper", "975", "97.5%"
  ))

  required <- c(estimate=estimate_col, se=se_col, lower=lower_col, upper=upper_col)
  if (any(is.na(required))) {
    return(list(
      error=paste0(
        "Esquema de columnas bootstrap no reconocido en ", table_name,
        ". Columnas disponibles: ", paste(names(tbl), collapse=", ")
      ),
      mapping=as.list(required)
    ))
  }

  labels <- rownames(tbl)
  if (is.null(labels) || identical(labels, as.character(seq_len(nrow(tbl))))) {
    char_cols <- which(vapply(tbl, function(x) is.character(x) || is.factor(x), logical(1)))
    path_col <- char_cols[vapply(char_cols, function(i) any(grepl("->", as.character(tbl[[i]]), fixed=TRUE)), logical(1))]
    if (length(path_col)) labels <- as.character(tbl[[path_col[1]]])
  }
  if (is.null(labels) || length(labels) != nrow(tbl)) labels <- as.character(seq_len(nrow(tbl)))

  out <- data.frame(
    Path=trimws(labels),
    Estimate=suppressWarnings(as.numeric(tbl[[estimate_col]])),
    SE=suppressWarnings(as.numeric(tbl[[se_col]])),
    CI_Lower=suppressWarnings(as.numeric(tbl[[lower_col]])),
    CI_Upper=suppressWarnings(as.numeric(tbl[[upper_col]])),
    stringsAsFactors=FALSE
  )
  if (any(!is.finite(as.matrix(out[, c("Estimate", "SE", "CI_Lower", "CI_Upper")])))) {
    return(list(
      error=paste0("El bootstrap de ", table_name, " contiene valores no finitos."),
      mapping=as.list(required)
    ))
  }
  if (any(out$SE <= 0)) {
    return(list(
      error=paste0("El bootstrap de ", table_name, " contiene errores estándar no positivos."),
      mapping=as.list(required)
    ))
  }
  list(
    data=out,
    mapping=list(
      estimate=names(tbl)[estimate_col],
      se=names(tbl)[se_col],
      lower=names(tbl)[lower_col],
      upper=names(tbl)[upper_col]
    )
  )
}

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

calc_indirect <- function(paths_tbl, p_df, boot_est, n_boot=500L, alpha=.05) {
  # SEMinR no expone una tabla bootstrapped_indirect_paths en summary().
  # Los efectos específicos se obtienen directamente de boot_paths, exactamente
  # como specific_effect_significance() del paquete seminr: producto de rutas
  # en cada remuestra, IC percentil y p empírico bilateral por signo.
  tryCatch({
    boot_paths <- boot_est$boot_paths
    orig_paths <- boot_est$path_coef
    if (is.null(boot_paths) || length(dim(boot_paths)) != 3L || is.null(orig_paths)) {
      return(NULL)
    }

    edge_key <- paste0(as.character(p_df$from), "\r", as.character(p_df$to))
    edge_set <- unique(edge_key)
    nodes <- unique(c(as.character(p_df$from), as.character(p_df$to)))
    adjacency <- split(as.character(p_df$to), as.character(p_df$from))

    # Enumerar caminos simples con al menos un mediador. Se limita a cuatro
    # mediadores para mantener el mismo alcance documentado por SEMinR.
    paths_found <- list()
    walk <- function(current, visited, max_edges=5L) {
      next_nodes <- unique(adjacency[[current]] %||% character())
      if (!length(next_nodes)) return(invisible(NULL))
      for (nxt in next_nodes) {
        if (nxt %in% visited) next
        seq_nodes <- c(visited, nxt)
        n_edges <- length(seq_nodes) - 1L
        if (n_edges >= 2L) {
          key <- paste(seq_nodes, collapse=" -> ")
          paths_found[[key]] <<- seq_nodes
        }
        if (n_edges < max_edges) walk(nxt, seq_nodes, max_edges=max_edges)
      }
      invisible(NULL)
    }
    for (origin in nodes) walk(origin, origin, max_edges=5L)
    if (!length(paths_found)) return(NULL)

    boot_n <- dim(boot_paths)[3]
    rows <- list()
    for (seq_nodes in paths_found) {
      froms <- head(seq_nodes, -1L)
      tos <- tail(seq_nodes, -1L)
      keys <- paste0(froms, "\r", tos)
      if (!all(keys %in% edge_set)) next
      if (!all(froms %in% rownames(orig_paths)) || !all(tos %in% colnames(orig_paths))) next
      if (!all(froms %in% dimnames(boot_paths)[[1]]) || !all(tos %in% dimnames(boot_paths)[[2]])) next

      original_effect <- prod(vapply(seq_along(froms), function(i) {
        as.numeric(orig_paths[froms[i], tos[i]])
      }, numeric(1)))

      boot_effect <- rep(1, boot_n)
      for (i in seq_along(froms)) {
        boot_effect <- boot_effect * as.numeric(boot_paths[froms[i], tos[i], ])
      }
      boot_effect <- boot_effect[is.finite(boot_effect)]
      if (length(boot_effect) < max(100L, floor(.90 * boot_n))) next

      se <- stats::sd(boot_effect)
      if (!is.finite(original_effect) || !is.finite(se) || se <= 0) next
      ci <- as.numeric(stats::quantile(
        boot_effect,
        probs=c(alpha/2, 1-alpha/2),
        names=FALSE,
        type=7,
        na.rm=TRUE
      ))
      p_empirical <- min(1, 2 * min(
        mean(boot_effect <= 0),
        mean(boot_effect > 0)
      ))
      ci_sig <- (ci[1] > 0 && ci[2] > 0) || (ci[1] < 0 && ci[2] < 0)

      rows[[length(rows)+1L]] <- data.frame(
        Path=paste(seq_nodes, collapse=" -> "),
        Beta_ind=original_effect,
        Bootstrap_Mean=mean(boot_effect),
        STDEV=se,
        T_Valor=original_effect/se,
        P_Valor=p_empirical,
        IC_2.5=ci[1],
        IC_97.5=ci[2],
        CI_Significant=ci_sig,
        Sig=ifelse(ci_sig, "CI excluye 0", "CI incluye 0"),
        Inference_Primary="percentile_bootstrap_ci",
        P_Method="empirical_two_sided_bootstrap_sign",
        Bootstrap_Valid=length(boot_effect),
        stringsAsFactors=FALSE
      )
    }
    if (!length(rows)) return(NULL)
    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    out
  }, error=function(e) NULL)
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

# ============================================================================
# MÓDULOS PLS-SEM AVANZADOS — implementación defendible y fail-closed
# Estas definiciones sustituyen las aproximaciones heredadas anteriores.
# ============================================================================
as_flag <- function(x, default=FALSE) {
  if (is.null(x) || !length(x)) return(default)
  if (is.logical(x)) return(isTRUE(x[1]))
  tolower(trimws(as.character(x[1]))) %in% c("1","true","t","yes","si","sí","on")
}

safe_int <- function(x, default, min_value=NULL, max_value=NULL) {
  v <- suppressWarnings(as.integer(x %||% default))
  if (is.na(v)) v <- as.integer(default)
  if (!is.null(min_value)) v <- max(v, as.integer(min_value))
  if (!is.null(max_value)) v <- min(v, as.integer(max_value))
  v
}

path_matrix_to_named <- function(model, p_df=NULL) {
  pm <- tryCatch(as.matrix(model$path_coef), error=function(e) NULL)
  if (is.null(pm)) return(NULL)
  out <- numeric()
  if (!is.null(p_df) && nrow(p_df)) {
    for (i in seq_len(nrow(p_df))) {
      r <- as.character(p_df$from[i]); cl <- as.character(p_df$to[i])
      if (!r %in% rownames(pm) || !cl %in% colnames(pm)) next
      v <- suppressWarnings(as.numeric(pm[r,cl]))
      if (is.finite(v)) out[paste0(trimws(r)," -> ",trimws(cl))] <- v
    }
    return(out)
  }
  for (r in rownames(pm)) for (cl in colnames(pm)) {
    v <- suppressWarnings(as.numeric(pm[r,cl]))
    if (is.finite(v) && abs(v) > 1e-12) out[paste0(trimws(r)," -> ",trimws(cl))] <- v
  }
  out
}

construct_for_item <- function(item, construct_items) {
  hit <- names(construct_items)[vapply(construct_items, function(z) item %in% z, logical(1))]
  if (length(hit)) hit[1] else NA_character_
}

q2_predict_level <- function(q2) {
  if (!is.finite(q2)) return("N/D")
  if (q2 >= .35) "Alta" else if (q2 >= .15) "Moderada" else if (q2 > 0) "Baja" else "Sin poder predictivo"
}

# PLS-Predict oficial de SEMinR. Cada repetición vuelve a dividir la muestra y
# SEMinR reestima el modelo en cada fold. El benchmark ingenuo usa únicamente
# la media del fold de entrenamiento, evitando fuga de información.
calc_pls_predict <- function(pls_est, raw_df, p_df, construct_items,
                             k_folds=10L, reps=1L, seed=42L) {
    n <- nrow(raw_df)
    if (n < 30L || !exists("predict_pls", where=asNamespace("seminr"), inherits=FALSE)) return(NULL)
    k_folds <- safe_int(k_folds, 10L, 2L, max(2L, floor(n/5L)))
    reps <- safe_int(reps, 1L, 1L, 20L)
    endogenous <- unique(as.character(p_df$to))
    endogenous_items <- unique(unlist(construct_items[endogenous], use.names=FALSE))
    endogenous_items <- intersect(endogenous_items, names(raw_df))
    if (!length(endogenous_items)) return(NULL)

    pls_sum <- matrix(0, nrow=n, ncol=length(endogenous_items), dimnames=list(rownames(raw_df), endogenous_items))
    lm_sum <- pls_sum
    naive_sum <- pls_sum
    actual_ref <- as.matrix(raw_df[,endogenous_items,drop=FALSE])
    valid_reps <- 0L

    for (rep_i in seq_len(reps)) {
      rep_seed <- as.integer(seed) + rep_i - 1L
      set.seed(rep_seed)
      ord <- sample(seq_len(n), n, replace=FALSE)
      ordered_rows <- rownames(raw_df)[ord]
      folds_ordered <- cut(seq_len(n), breaks=k_folds, labels=FALSE)
      fold_by_row <- setNames(folds_ordered, ordered_rows)

      naive <- matrix(NA_real_, nrow=n, ncol=length(endogenous_items),
                      dimnames=list(rownames(raw_df), endogenous_items))
      for (fold_i in seq_len(k_folds)) {
        test_rows <- names(fold_by_row)[fold_by_row == fold_i]
        train_rows <- setdiff(rownames(raw_df), test_rows)
        if (!length(test_rows) || !length(train_rows)) next
        train_means <- colMeans(raw_df[train_rows,endogenous_items,drop=FALSE], na.rm=TRUE)
        naive[test_rows,] <- matrix(rep(train_means, each=length(test_rows)),
                                   nrow=length(test_rows), byrow=FALSE,
                                   dimnames=list(test_rows,endogenous_items))
      }

      set.seed(rep_seed)
      pred <- tryCatch(
        seminr::predict_pls(model=pls_est, technique=seminr::predict_DA,
                            noFolds=k_folds, reps=NULL, cores=NULL),
        error=function(e) NULL
      )
      if (is.null(pred) || is.null(pred$items)) next
      pls_oos <- tryCatch(as.matrix(pred$items$PLS_out_of_sample), error=function(e) NULL)
      lm_oos <- tryCatch(as.matrix(pred$items$lm_out_of_sample), error=function(e) NULL)
      actual <- tryCatch(as.matrix(pred$items$item_actuals), error=function(e) NULL)
      if (is.null(pls_oos) || is.null(lm_oos) || is.null(actual)) next
      common <- Reduce(intersect, list(endogenous_items, colnames(pls_oos), colnames(lm_oos), colnames(actual)))
      if (!setequal(common, endogenous_items)) next
      common_rows <- Reduce(intersect, list(rownames(raw_df), rownames(pls_oos), rownames(lm_oos), rownames(actual)))
      if (length(common_rows) != n) next
      pls_sum[common_rows,common] <- pls_sum[common_rows,common] + pls_oos[common_rows,common,drop=FALSE]
      lm_sum[common_rows,common] <- lm_sum[common_rows,common] + lm_oos[common_rows,common,drop=FALSE]
      naive_sum[common_rows,common] <- naive_sum[common_rows,common] + naive[common_rows,common,drop=FALSE]
      actual_ref[common_rows,common] <- actual[common_rows,common,drop=FALSE]
      valid_reps <- valid_reps + 1L
    }
    if (valid_reps < reps) return(NULL)
    pls_avg <- pls_sum / valid_reps
    lm_avg <- lm_sum / valid_reps
    naive_avg <- naive_sum / valid_reps

    rows <- lapply(endogenous_items, function(item) {
      y <- actual_ref[,item]
      yp <- pls_avg[,item]
      yl <- lm_avg[,item]
      yn <- naive_avg[,item]
      ok <- is.finite(y) & is.finite(yp) & is.finite(yl) & is.finite(yn)
      if (sum(ok) < max(20L, floor(.8*n))) return(NULL)
      e_pls <- y[ok]-yp[ok]; e_lm <- y[ok]-yl[ok]; e_naive <- y[ok]-yn[ok]
      sse_pls <- sum(e_pls^2); sse_naive <- sum(e_naive^2)
      q2p <- if (sse_naive > 1e-12) 1-sse_pls/sse_naive else NA_real_
      data.frame(
        Indicador=item,
        Constructo=construct_for_item(item, construct_items),
        RMSE_modelo=sqrt(mean(e_pls^2)), MAE_modelo=mean(abs(e_pls)),
        RMSE_naive=sqrt(mean(e_naive^2)), MAE_naive=mean(abs(e_naive)),
        RMSE_LM=sqrt(mean(e_lm^2)), MAE_LM=mean(abs(e_lm)),
        Q2_predict=q2p,
        Mejor_naive=ifelse(sqrt(mean(e_pls^2)) < sqrt(mean(e_naive^2)), "Sí", "No"),
        Mejor_LM=ifelse(sqrt(mean(e_pls^2)) < sqrt(mean(e_lm^2)), "Sí", "No"),
        Nivel=q2_predict_level(q2p),
        Folds=k_folds, Repeticiones=valid_reps,
        Metodo="SEMinR predict_pls: reestimación PLS por fold; benchmark LM y media de entrenamiento",
        stringsAsFactors=FALSE
      )
    })
    rows <- Filter(Negate(is.null), rows)
    if (!length(rows)) return(NULL)
    out <- do.call(rbind, rows); rownames(out) <- NULL; out
}

# Q² Stone-Geisser por omisión sistemática de celdas en indicadores endógenos.
# Cada ronda vuelve a estimar el modelo con las celdas omitidas y reconstruye el
# indicador desde el score y su loading. SSO usa la media del conjunto no omitido.

calc_q2 <- function(raw_df, p_df, d=7L, m_model=NULL, s_model=NULL,
                    construct_items=NULL, seed=42L) {
    if (is.null(m_model) || is.null(s_model) || is.null(construct_items)) return(NULL)
    n <- nrow(raw_df); d <- safe_int(d, 7L, 5L, 12L)
    candidates <- 5:12
    valid_d <- candidates[n %% candidates != 0L]
    if (n %% d == 0L) d <- if (length(valid_d)) valid_d[which.min(abs(valid_d-d))] else return(NULL)
    endogenous <- unique(as.character(p_df$to))
    item_construct <- unlist(lapply(endogenous, function(cn) setNames(rep(cn, length(construct_items[[cn]])), construct_items[[cn]])))
    end_items <- intersect(names(item_construct), names(raw_df))
    if (!length(end_items)) return(NULL)

    pos <- expand.grid(row=seq_len(n), item=end_items, stringsAsFactors=FALSE)
    pos$sequence <- seq_len(nrow(pos))
    stats_by_item <- setNames(lapply(end_items, function(x) c(SSE=0, SSO=0, valid=0, expected=0)), end_items)
    set.seed(seed)

    for (h in 0:(d-1L)) {
      omit <- pos[(pos$sequence-1L) %% d == h,,drop=FALSE]
      if (!nrow(omit)) next
      masked <- raw_df
      for (k in seq_len(nrow(omit))) masked[omit$row[k], omit$item[k]] <- NA_real_
      fit <- tryCatch(seminr::estimate_pls(data=masked, measurement_model=m_model,
                                           structural_model=s_model,
                                           missing=seminr::mean_replacement),
                      error=function(e) NULL)
      if (is.null(fit)) next
      sc <- tryCatch(as.matrix(fit$construct_scores), error=function(e) NULL)
      ld <- tryCatch(as.matrix(fit$outer_loadings), error=function(e) NULL)
      mean_raw <- tryCatch(fit$meanData, error=function(e) NULL)
      sd_raw <- tryCatch(fit$sdData, error=function(e) NULL)
      means <- tryCatch(as.numeric(mean_raw), error=function(e) NULL)
      sds <- tryCatch(as.numeric(sd_raw), error=function(e) NULL)
      manifest_names <- names(mean_raw)
      if (is.null(manifest_names) || length(manifest_names) != length(means)) manifest_names <- fit$mmVariables
      if (is.null(manifest_names) || length(manifest_names) != length(means)) manifest_names <- colnames(fit$rawdata)
      if (!is.null(means) && length(manifest_names) == length(means)) names(means) <- manifest_names
      if (!is.null(sds) && length(manifest_names) == length(sds)) names(sds) <- manifest_names
      if (is.null(sc) || is.null(ld) || is.null(means) || is.null(sds) ||
          is.null(names(means)) || is.null(names(sds))) next
      for (item in unique(omit$item)) {
        cn <- unname(item_construct[item]); idx <- omit$row[omit$item==item]
        stats_by_item[[item]]["expected"] <- stats_by_item[[item]]["expected"] + length(idx)
        if (!cn %in% colnames(sc) || !item %in% rownames(ld) || !cn %in% colnames(ld)) next
        train_mean <- mean(masked[[item]], na.rm=TRUE)
        preds <- unique(as.character(p_df$from[p_df$to == cn]))
        pm <- tryCatch(as.matrix(fit$path_coef), error=function(e) NULL)
        if (!is.finite(train_mean) || !is.finite(sds[item]) || sds[item] <= 0 ||
            is.null(pm) || !length(preds) || !all(preds %in% colnames(sc)) ||
            !all(preds %in% rownames(pm)) || !cn %in% colnames(pm)) next
        eta_pred <- as.numeric(as.matrix(sc[idx,preds,drop=FALSE]) %*% as.numeric(pm[preds,cn]))
        pred <- means[item] + eta_pred * ld[item,cn] * sds[item]
        obs <- raw_df[idx,item]
        ok <- is.finite(obs) & is.finite(pred)
        if (!any(ok)) next
        stats_by_item[[item]]["SSE"] <- stats_by_item[[item]]["SSE"] + sum((obs[ok]-pred[ok])^2)
        stats_by_item[[item]]["SSO"] <- stats_by_item[[item]]["SSO"] + sum((obs[ok]-train_mean)^2)
        stats_by_item[[item]]["valid"] <- stats_by_item[[item]]["valid"] + sum(ok)
      }
    }

    item_rows <- lapply(end_items, function(item) {
      z <- stats_by_item[[item]]
      if (z["expected"] < 1 || z["valid"] < .8*z["expected"] || z["SSO"] <= 1e-12) return(NULL)
      data.frame(Item=item, Constructo=unname(item_construct[item]),
                 SSE=z["SSE"], SSO=z["SSO"], Valid_Omissions=z["valid"],
                 Q2=1-z["SSE"]/z["SSO"], stringsAsFactors=FALSE)
    })
    item_rows <- Filter(Negate(is.null), item_rows)
    if (!length(item_rows)) return(NULL)
    items_tbl <- do.call(rbind,item_rows)
    rows <- lapply(split(items_tbl, items_tbl$Constructo), function(z) {
      q <- 1-sum(z$SSE)/sum(z$SSO)
      data.frame(Constructo=z$Constructo[1], Q2=q, SSE=sum(z$SSE), SSO=sum(z$SSO),
                 Indicadores=nrow(z), Omisiones_validas=sum(z$Valid_Omissions),
                 Distancia_omision=d, Nivel=q2_predict_level(q),
                 Metodo="Stone-Geisser cross-validated redundancy: omisión sistemática, reestimación y predicción estructural del constructo endógeno",
                 stringsAsFactors=FALSE)
    })
    out <- do.call(rbind,rows); rownames(out)<-NULL; out
}

latent_correlation_implied <- function(path_coef, observed_phi) {
  P <- tryCatch(as.matrix(path_coef),error=function(e) NULL)
  Phi <- tryCatch(as.matrix(observed_phi),error=function(e) NULL)
  if (is.null(P) || is.null(Phi)) return(NULL)
  nodes <- intersect(intersect(rownames(P),colnames(P)),intersect(rownames(Phi),colnames(Phi)))
  if (!length(nodes)) return(NULL)
  P <- P[nodes,nodes,drop=FALSE]; P[!is.finite(P)] <- 0
  diag(P) <- 0
  parents <- lapply(nodes,function(y) nodes[abs(P[nodes,y])>1e-12]); names(parents)<-nodes
  indegree <- vapply(parents,length,integer(1))
  queue <- nodes[indegree==0L]; order <- character()
  while(length(queue)) {
    v <- queue[1]; queue <- queue[-1]; order <- c(order,v)
    children <- nodes[abs(P[v,nodes])>1e-12]
    for(ch in children) {
      indegree[ch] <- indegree[ch]-1L
      if(indegree[ch]==0L) queue <- c(queue,ch)
    }
  }
  if(length(order)!=length(nodes)) return(NULL)
  S <- matrix(0,length(nodes),length(nodes),dimnames=list(nodes,nodes))
  exo <- nodes[vapply(parents,length,integer(1))==0L]
  if(length(exo)) S[exo,exo] <- Phi[exo,exo,drop=FALSE]
  for(e in exo) S[e,e] <- 1
  done <- exo
  for(y in order) {
    pr <- parents[[y]]
    if(!length(pr)) next
    if(!all(pr %in% done)) return(NULL)
    b <- as.numeric(P[pr,y])
    for(z in done) {
      cv <- sum(b*S[pr,z])
      S[y,z] <- S[z,y] <- cv
    }
    explained <- as.numeric(t(b)%*%S[pr,pr,drop=FALSE]%*%b)
    if(!is.finite(explained) || explained < -1e-8 || explained > 1+1e-6) return(NULL)
    S[y,y] <- 1
    done <- unique(c(done,y))
  }
  S
}

calc_srmr <- function(pls_est, summ, raw_df=NULL) {
    ld <- tryCatch(as.matrix(summ$loadings), error=function(e) NULL)
    sc <- tryCatch(as.data.frame(pls_est$construct_scores), error=function(e) NULL)
    if (is.null(ld) || is.null(sc) || is.null(raw_df)) return(NULL)
    items <- intersect(rownames(ld), names(raw_df)); cons <- intersect(colnames(ld), names(sc))
    if (length(items)<2L || length(cons)<1L) return(NULL)
    S <- stats::cor(raw_df[,items,drop=FALSE], use="pairwise.complete.obs")
    Phi <- if (length(cons)==1L) matrix(1,1,1,dimnames=list(cons,cons)) else
      stats::cor(sc[,cons,drop=FALSE],use="pairwise.complete.obs")
    Lam <- ld[items,cons,drop=FALSE]
    make_row <- function(phi_model,index,type,method) {
      implied <- Lam %*% phi_model %*% t(Lam)
      diag(implied) <- 1
      resid <- S-implied
      lower <- resid[lower.tri(resid)]
      v <- sqrt(mean(lower^2,na.rm=TRUE))
      if(!is.finite(v)) return(NULL)
      data.frame(
        Indice=index, Valor=v,
        Criterio=ifelse(v<=.08,"≤ .08",ifelse(v<=.10,".08–.10","> .10")),
        Tipo=type,
        d_ULS=sum(lower^2,na.rm=TRUE),
        Advertencia="Diagnóstico descriptivo; no constituye por sí solo una prueba global concluyente de ajuste PLS-SEM.",
        Metodo=method,
        stringsAsFactors=FALSE)
    }
    rows <- list(make_row(Phi,"SRMR_saturated_composite","Modelo saturado compuesto",
      "Correlaciones observadas frente a Lambda-Phi-Lambda' con correlaciones empíricas entre constructos"))
    phi_est <- latent_correlation_implied(pls_est$path_coef,Phi)
    if(!is.null(phi_est)) rows[[length(rows)+1L]] <- make_row(phi_est,
      "SRMR_estimated_composite","Modelo estructural estimado",
      "Correlaciones observadas frente a Lambda-Phi_modelo-Lambda'; Phi_modelo se deriva recursivamente de rutas PLS estandarizadas y covarianzas exógenas")
    rows <- Filter(Negate(is.null),rows)
    if(!length(rows)) return(NULL)
    out<-do.call(rbind,rows);rownames(out)<-NULL;out
}

# Intervalos HTMT obtenidos del mismo bootstrap SEMinR usado para las rutas.

calc_htmt_ci <- function(boot_est, summ, alpha=.05) {
    arr <- boot_est$boot_HTMT
    if (is.null(arr) || length(dim(arr))!=3L) return(NULL)
    orig <- tryCatch(as.matrix(summ$validity$htmt), error=function(e) NULL)
    if (is.null(orig)) return(NULL)
    cons <- intersect(rownames(orig), dimnames(arr)[[1]])
    if (length(cons)<2L) return(NULL)
    B <- dim(arr)[3]; min_valid <- max(100L, ceiling(.8*B)); rows <- list()
    for (i in seq_len(length(cons)-1L)) for (j in (i+1L):length(cons)) {
      a<-cons[i]; b<-cons[j]
      vals_ab <- as.numeric(arr[a,b,]); vals_ba <- as.numeric(arr[b,a,])
      vals_ab <- vals_ab[is.finite(vals_ab)]; vals_ba <- vals_ba[is.finite(vals_ba)]
      vals <- if (length(vals_ab) >= length(vals_ba)) vals_ab else vals_ba
      if (length(vals)<min_valid) next
      ci <- as.numeric(stats::quantile(vals,c(alpha/2,1-alpha/2),names=FALSE,type=7))
      h_ab <- suppressWarnings(as.numeric(orig[a,b])); h_ba <- suppressWarnings(as.numeric(orig[b,a]))
      h <- if (is.finite(h_ab)) h_ab else h_ba
      if (!is.finite(h)) next
      rows[[length(rows)+1L]] <- data.frame(
        Par=paste0(a," ↔ ",b), C1=a, C2=b, HTMT=h,
        IC_2.5=ci[1], IC_97.5=ci[2], Bootstrap_Valid=length(vals),
        OK_CI=ifelse(ci[2]<.85,"IC superior < .85",ifelse(ci[2]<.90,"IC superior < .90 (liberal)","IC superior ≥ .90")),
        Inference_Primary="percentile_bootstrap_ci_from_seminr_boot_HTMT",
        stringsAsFactors=FALSE)
    }
    if(!length(rows)) return(NULL); out<-do.call(rbind,rows);rownames(out)<-NULL;out
}

calc_vaf_mediation <- function(paths_tbl, indirect_tbl, p_df, boot_est=NULL, alpha=.05) {
    if (is.null(paths_tbl) || is.null(indirect_tbl) || !nrow(indirect_tbl)) return(NULL)
    endpoint <- function(s) {
      z <- trimws(strsplit(as.character(s), " -> ", fixed=TRUE)[[1]])
      if (length(z) < 2L) return(NA_character_)
      paste0(z[1], " -> ", z[length(z)])
    }
    indirect_tbl$Endpoint <- vapply(indirect_tbl$Path, endpoint, character(1))
    indirect_tbl <- indirect_tbl[is.finite(indirect_tbl$Beta_ind) & !is.na(indirect_tbl$Endpoint),,drop=FALSE]
    if (!nrow(indirect_tbl)) return(NULL)

    boot_paths <- tryCatch(boot_est$boot_paths, error=function(e) NULL)
    boot_n <- if (!is.null(boot_paths) && length(dim(boot_paths)) == 3L) dim(boot_paths)[3] else 0L
    groups <- split(indirect_tbl, indirect_tbl$Endpoint)
    rows <- list()

    for (ep in names(groups)) {
      z <- groups[[ep]]
      direct_row <- paths_tbl[gsub("\\s+", "", paths_tbl$Path) == gsub("\\s+", "", ep),,drop=FALSE]
      has_direct <- nrow(direct_row) > 0L
      direct <- if (has_direct) as.numeric(direct_row$Beta[1]) else 0
      direct_sig <- has_direct && isTRUE(direct_row$CI_Significant[1])
      ind_total <- sum(as.numeric(z$Beta_ind), na.rm=TRUE)
      total <- direct + ind_total

      ind_boot <- NULL
      if (boot_n > 0L) {
        holder <- matrix(NA_real_, nrow=boot_n, ncol=nrow(z))
        for (j in seq_len(nrow(z))) {
          nodes <- trimws(strsplit(as.character(z$Path[j]), " -> ", fixed=TRUE)[[1]])
          froms <- head(nodes,-1L); tos <- tail(nodes,-1L)
          if (!length(froms) || !all(froms %in% dimnames(boot_paths)[[1]]) ||
              !all(tos %in% dimnames(boot_paths)[[2]])) next
          vals <- rep(1, boot_n)
          for (k in seq_along(froms)) vals <- vals * as.numeric(boot_paths[froms[k],tos[k],])
          holder[,j] <- vals
        }
        complete_boot <- apply(holder,1,function(v) all(is.finite(v)))
        if (sum(complete_boot) >= max(100L, floor(.8*boot_n))) {
          ind_boot <- rowSums(holder[complete_boot,,drop=FALSE])
        }
      }

      if (!is.null(ind_boot)) {
        ind_ci <- as.numeric(stats::quantile(ind_boot,c(alpha/2,1-alpha/2),names=FALSE,type=7))
        ind_sig <- (ind_ci[1] > 0 && ind_ci[2] > 0) || (ind_ci[1] < 0 && ind_ci[2] < 0)
      } else {
        # Conservador: sin distribución conjunta solo se declara significativo si
        # todos los efectos específicos tienen IC bootstrap significativo y el mismo signo.
        ind_ci <- c(NA_real_,NA_real_)
        ind_sig <- all(z$CI_Significant %in% TRUE) && length(unique(sign(z$Beta_ind))) == 1L
      }

      same_sign <- direct_sig && ind_sig && sign(ind_total) == sign(direct)
      type <- if (ind_sig && direct_sig && same_sign) "Mediación complementaria" else
        if (ind_sig && direct_sig && !same_sign) "Mediación competitiva" else
        if (ind_sig && !direct_sig) "Mediación solo indirecta" else
        if (!ind_sig && direct_sig) "No mediación: solo efecto directo" else
        "No mediación: sin efecto significativo"
      vaf_ok <- has_direct && same_sign && abs(total) > 1e-9

      rows[[length(rows)+1L]] <- data.frame(
        Ruta_indirecta=paste(as.character(z$Path), collapse=" + "), Endpoint=ep,
        N_rutas_indirectas=nrow(z),
        Beta_directo=if (has_direct) direct else NA_real_,
        Beta_indirecto=ind_total, Beta_total=total,
        IC_indirecto_2.5=ind_ci[1], IC_indirecto_97.5=ind_ci[2],
        Bootstrap_Valid=if (is.null(ind_boot)) NA_integer_ else length(ind_boot),
        VAF_pct=if (vaf_ok) 100*ind_total/total else NA_real_,
        Tipo_mediacion=type,
        Directo_significativo_IC=direct_sig,
        Indirecto_significativo_IC=ind_sig,
        Criterio="Clasificación Zhao basada en el IC bootstrap conjunto del efecto indirecto total; VAF solo descriptivo cuando directo e indirecto son significativos, concordantes y el total es estable",
        stringsAsFactors=FALSE)
    }
    if (!length(rows)) return(NULL)
    out <- do.call(rbind,rows); rownames(out) <- NULL; out
}

calc_full_vif <- function(scores_df, threshold=3.3) {
    if(is.null(scores_df)||ncol(scores_df)<2L)return(NULL)
    rows<-lapply(names(scores_df),function(lv){
      others<-setdiff(names(scores_df),lv)
      fit<-tryCatch(stats::lm(stats::reformulate(others,response=lv),data=scores_df),error=function(e)NULL)
      if(is.null(fit))return(NULL);r2<-summary(fit)$r.squared;v<-if(is.finite(r2)&&r2<.999999)1/(1-r2) else 9999
      data.frame(Variable_Latente=lv,VIF_Full=v,Umbral=threshold,
                 Estado=ifelse(v<threshold,"Debajo del umbral diagnóstico","Sobre el umbral diagnóstico"),
                 Alcance="Diagnóstico de colinealidad total; no prueba concluyente de sesgo de método común",
                 stringsAsFactors=FALSE)
    })
    rows<-Filter(Negate(is.null),rows);if(!length(rows))return(NULL);out<-do.call(rbind,rows);rownames(out)<-NULL;out
}

adjusted_ecdf_copula <- function(z) {
  z <- as.numeric(z); n <- length(z)
  if (n < 3L || any(!is.finite(z)) || length(unique(z)) < 3L) return(NULL)
  # Liengaard et al. (2025), F4(x) = 1/(2n) + ((n-1)/n) * ECDF(x).
  f4 <- 1/(2*n) + ((n-1)/(n^2)) * rank(z, ties.method="max")
  f4 <- pmin(1-1e-10,pmax(1e-10,f4))
  stats::qnorm(f4)
}

extend_pls_with_single_item <- function(m_model, p_df, gc_construct, gc_item, target) {
  mm_specs <- unname(as.list(m_model))
  mm_specs[[length(mm_specs)+1L]] <- seminr::composite(gc_construct, seminr::single_item(gc_item))
  mm_ext <- tryCatch(do.call(seminr::constructs, mm_specs), error=function(e) NULL)
  if (is.null(mm_ext)) return(NULL)
  sm_specs <- lapply(seq_len(nrow(p_df)), function(i) {
    seminr::paths(from=as.character(p_df$from[i]), to=as.character(p_df$to[i]))
  })
  sm_specs[[length(sm_specs)+1L]] <- seminr::paths(from=gc_construct,to=target)
  sm_ext <- tryCatch(do.call(seminr::relationships,sm_specs),error=function(e) NULL)
  if (is.null(sm_ext)) return(NULL)
  list(mm=mm_ext,sm=sm_ext)
}

# Cópula gaussiana PLS-SEM de dos etapas. El término se construye desde el
# puntaje del predictor, se incorpora como constructo de un solo indicador y el
# modelo aumentado se reestima y bootstrappea con SEMinR. Se mantiene opt-in.
calc_gaussian_copula <- function(pls_est, raw_df, p_df, m_model=NULL,
                                 n_boot=1000L, seed=42L, alpha=.05) {
    if (is.null(pls_est) || is.null(raw_df) || is.null(m_model)) return(NULL)
    scores_df <- tryCatch(as.data.frame(pls_est$construct_scores),error=function(e) NULL)
    if (is.null(scores_df) || nrow(scores_df) != nrow(raw_df)) return(NULL)
    n_boot <- safe_int(n_boot,1000L,200L,10000L)
    rows <- list()

    for (i in seq_len(nrow(p_df))) {
      xn <- as.character(p_df$from[i]); endo <- as.character(p_df$to[i])
      if (!xn %in% names(scores_df) || !endo %in% names(scores_df)) next
      x <- as.numeric(scores_df[[xn]])
      if (length(x) < 50L || length(unique(x)) < 10L) next
      normal_p <- tryCatch(
        if (requireNamespace("nortest",quietly=TRUE)) nortest::ad.test(x)$p.value
        else stats::shapiro.test(sample(x,min(5000,length(x))))$p.value,
        error=function(e) NA_real_)
      if (!is.finite(normal_p) || normal_p >= .05) next

      gc <- adjusted_ecdf_copula(x)
      if (is.null(gc) || stats::sd(gc) <= 1e-12) next
      cor_x_gc <- suppressWarnings(stats::cor(x,gc,use="complete.obs"))
      omega_simple <- if (is.finite(cor_x_gc)) max(0,min(1,1-cor_x_gc^2)) else NA_real_
      if (!all(is.finite(c(cor_x_gc,omega_simple)))) next
      gc_item <- make.names(paste0("copula__",xn,"__",endo))
      while (gc_item %in% names(raw_df)) gc_item <- paste0(gc_item,"_x")
      gc_construct <- make.names(paste0("GC_",xn,"_",endo))
      while (gc_construct %in% names(scores_df) || gc_construct %in% unique(c(p_df$from,p_df$to))) {
        gc_construct <- paste0(gc_construct,"_x")
      }
      ext <- extend_pls_with_single_item(m_model,p_df,gc_construct,gc_item,endo)
      if (is.null(ext)) next
      dat_ext <- raw_df; dat_ext[[gc_item]] <- gc
      aug_fit <- tryCatch(seminr::estimate_pls(data=dat_ext,
        measurement_model=ext$mm,structural_model=ext$sm),error=function(e) NULL)
      if (is.null(aug_fit)) next
      pm <- tryCatch(as.matrix(aug_fit$path_coef),error=function(e) NULL)
      if (is.null(pm) || !gc_construct %in% rownames(pm) || !endo %in% colnames(pm) ||
          !xn %in% rownames(pm)) next
      coef_gc <- as.numeric(pm[gc_construct,endo])
      beta_corrected <- as.numeric(pm[xn,endo])
      beta_original <- tryCatch(as.numeric(pls_est$path_coef[xn,endo]),error=function(e) NA_real_)
      if (!all(is.finite(c(coef_gc,beta_corrected,beta_original)))) next

      boot_aug <- tryCatch(seminr::bootstrap_model(seminr_model=aug_fit,
        nboot=n_boot,cores=1,seed=as.integer(seed)+i),error=function(e) NULL)
      bp <- tryCatch(boot_aug$boot_paths,error=function(e) NULL)
      if (is.null(bp) || length(dim(bp)) != 3L ||
          !gc_construct %in% dimnames(bp)[[1]] || !endo %in% dimnames(bp)[[2]] ||
          !xn %in% dimnames(bp)[[1]]) next
      vals_gc <- as.numeric(bp[gc_construct,endo,])
      vals_beta <- as.numeric(bp[xn,endo,])
      ok <- is.finite(vals_gc) & is.finite(vals_beta)
      vals_gc <- vals_gc[ok]; vals_beta <- vals_beta[ok]
      if (length(vals_gc) < ceiling(.8*n_boot)) next
      sd_boot <- stats::sd(vals_gc)
      if (!is.finite(sd_boot) || sd_boot <= 1e-12) next
      ci_gc <- as.numeric(stats::quantile(vals_gc,c(alpha/2,1-alpha/2),names=FALSE,type=7))
      ci_beta <- as.numeric(stats::quantile(vals_beta,c(alpha/2,1-alpha/2),names=FALSE,type=7))
      pemp <- min(1,2*min((1+sum(vals_gc<=0))/(length(vals_gc)+1),
                          (1+sum(vals_gc>=0))/(length(vals_gc)+1)))
      ci_sig <- (ci_gc[1] > 0 && ci_gc[2] > 0) || (ci_gc[1] < 0 && ci_gc[2] < 0)

      rows[[length(rows)+1L]] <- data.frame(
        Ruta=paste0(xn," -> ",endo),
        PLS_Beta_Original=beta_original,
        PLS_Beta_Corregido=beta_corrected,
        Beta_Corregido_IC_lo=ci_beta[1], Beta_Corregido_IC_hi=ci_beta[2],
        Copula_Coef=coef_gc, Std_Error=sd_boot, t_valor=coef_gc/sd_boot,
        p_valor=pemp, IC_lo=ci_gc[1], IC_hi=ci_gc[2],
        Normalidad_p=normal_p, Cor_X_Copula=cor_x_gc, Omega_Simple=omega_simple,
        Bootstrap_Valid=length(vals_gc),
        Calidad_bootstrap=ifelse(n_boot>=5000L,"Confirmatoria (≥5000)","Exploratoria (<5000)"),
        Bootstrap_Alcance="Bootstrap condicional al término copular generado en la etapa 1",
        Interpretacion=ifelse(ci_sig,
          "Término copular significativo: evidencia compatible con endogeneidad",
          "Término copular no significativo: sin evidencia concluyente; no demuestra exogeneidad"),
        Supuesto="Predictor no normal verificado; normalidad del error y estructura copular gaussiana no son plenamente observables",
        Metodo="PLS-SEM aumentado con constructo copular de un ítem, ECDF ajustada F4 de Liengaard et al. (2025) y bootstrap SEMinR",
        Alcance="Análisis de sensibilidad por ruta; requiere justificación teórica previa y no sustituye un diseño causal",
        stringsAsFactors=FALSE)
    }
    if (!length(rows)) return(NULL)
    out <- do.call(rbind,rows); rownames(out) <- NULL; out
}

normalize_weights <- function(w, ref=NULL) {
  w<-as.numeric(w);if(!all(is.finite(w))||sqrt(sum(w^2))<1e-12)return(NULL);w<-w/sqrt(sum(w^2))
  if(!is.null(ref)){ref<-as.numeric(ref);if(length(ref)==length(w)&&sum(w*ref,na.rm=TRUE)<0)w<--w};w
}

estimate_group_model <- function(dat,m_model,s_model,min_n=20L){
  dat<-as.data.frame(lapply(dat,function(x)suppressWarnings(as.numeric(as.character(x)))))
  dat<-dat[complete.cases(dat),,drop=FALSE];if(nrow(dat)<min_n)return(NULL)
  tryCatch(seminr::estimate_pls(data=dat,measurement_model=m_model,structural_model=s_model),error=function(e)NULL)
}

calc_micom <- function(raw_df, p_df, pls_est, summ, group_var, n_permut=5000L,
                       m_model=NULL, s_model=NULL, seed=42L) {
  if (is.null(group_var) || !group_var %in% names(raw_df) ||
      is.null(m_model) || is.null(s_model)) return(NULL)

  n_permut <- safe_int(n_permut, 5000L, 50L, 20000L)
  set.seed(seed)
  groups_all <- as.character(raw_df[[group_var]])
  tab <- table(groups_all, useNA="no")
  groups <- sort(names(tab)[tab >= 30L])
  if (length(groups) < 2L) return(NULL)

  item_cols <- setdiff(names(raw_df), group_var)
  Xall <- as.data.frame(lapply(raw_df[, item_cols, drop=FALSE], function(x) {
    suppressWarnings(as.numeric(as.character(x)))
  }))
  pairs <- combn(groups, 2, simplify=FALSE)
  rows <- list()
  min_valid <- max(20L, ceiling(.8 * n_permut))

  for (pr in pairs) {
    g1 <- pr[1]; g2 <- pr[2]
    pair_idx <- which(groups_all %in% pr)
    labels <- groups_all[pair_idx]
    Xp <- Xall[pair_idx, , drop=FALSE]

    pooled_fit <- estimate_group_model(Xp, m_model, s_model, min_n=60L)
    f1 <- estimate_group_model(Xp[labels == g1, , drop=FALSE], m_model, s_model, min_n=30L)
    f2 <- estimate_group_model(Xp[labels == g2, , drop=FALSE], m_model, s_model, min_n=30L)
    if (is.null(pooled_fit) || is.null(f1) || is.null(f2)) next

    refw <- tryCatch(as.matrix(pooled_fit$outer_weights), error=function(e) NULL)
    w1 <- tryCatch(as.matrix(f1$outer_weights), error=function(e) NULL)
    w2 <- tryCatch(as.matrix(f2$outer_weights), error=function(e) NULL)
    pooled_scores <- tryCatch(as.matrix(pooled_fit$construct_scores), error=function(e) NULL)
    if (is.null(refw) || is.null(w1) || is.null(w2) || is.null(pooled_scores)) next

    constructs <- Reduce(intersect, list(colnames(refw), colnames(w1), colnames(w2), colnames(pooled_scores)))
    manifest <- intersect(rownames(refw), names(Xp))
    if (!length(constructs) || !length(manifest)) next
    Xz <- scale(as.matrix(Xp[, manifest, drop=FALSE]))
    Xz[!is.finite(Xz)] <- 0

    observed_c <- list()
    for (cn in constructs) {
      its <- manifest[abs(refw[manifest, cn]) > 1e-12]
      its <- intersect(its, intersect(rownames(w1), rownames(w2)))
      if (!length(its)) next
      a <- normalize_weights(w1[its, cn], refw[its, cn])
      b <- normalize_weights(w2[its, cn], refw[its, cn])
      if (is.null(a) || is.null(b)) next
      c0 <- suppressWarnings(stats::cor(
        as.numeric(Xz[, its, drop=FALSE] %*% a),
        as.numeric(Xz[, its, drop=FALSE] %*% b)
      ))
      if (is.finite(c0)) observed_c[[cn]] <- c0
    }
    if (!length(observed_c)) next

    perm_corr <- matrix(NA_real_, nrow=n_permut, ncol=length(observed_c),
                        dimnames=list(NULL, names(observed_c)))
    for (b in seq_len(n_permut)) {
      perm_labels <- sample(labels, length(labels), replace=FALSE)
      a1 <- estimate_group_model(Xp[perm_labels == g1, , drop=FALSE], m_model, s_model, min_n=30L)
      a2 <- estimate_group_model(Xp[perm_labels == g2, , drop=FALSE], m_model, s_model, min_n=30L)
      if (is.null(a1) || is.null(a2)) next
      wa <- tryCatch(as.matrix(a1$outer_weights), error=function(e) NULL)
      wb <- tryCatch(as.matrix(a2$outer_weights), error=function(e) NULL)
      if (is.null(wa) || is.null(wb)) next

      for (cn in names(observed_c)) {
        its <- manifest[abs(refw[manifest, cn]) > 1e-12]
        its <- intersect(its, intersect(rownames(wa), rownames(wb)))
        if (!length(its) || !cn %in% colnames(wa) || !cn %in% colnames(wb)) next
        va <- normalize_weights(wa[its, cn], refw[its, cn])
        vb <- normalize_weights(wb[its, cn], refw[its, cn])
        if (is.null(va) || is.null(vb)) next
        perm_corr[b, cn] <- suppressWarnings(stats::cor(
          as.numeric(Xz[, its, drop=FALSE] %*% va),
          as.numeric(Xz[, its, drop=FALSE] %*% vb)
        ))
      }
    }

    for (cn in names(observed_c)) {
      vals <- perm_corr[, cn]
      vals <- vals[is.finite(vals)]
      if (length(vals) < min_valid || !cn %in% colnames(pooled_scores)) next

      q05 <- as.numeric(stats::quantile(vals, .05, names=FALSE, type=7))
      pcomp <- (1 + sum(vals <= observed_c[[cn]])) / (length(vals) + 1)

      cs <- as.numeric(pooled_scores[, cn])
      ok_cs <- is.finite(cs) & !is.na(labels)
      cs <- cs[ok_cs]
      labels_cs <- labels[ok_cs]
      v1 <- stats::var(cs[labels_cs == g1]); v2 <- stats::var(cs[labels_cs == g2])
      if (!is.finite(v1) || !is.finite(v2) || v1 <= 0 || v2 <= 0) next

      obs_md <- mean(cs[labels_cs == g1]) - mean(cs[labels_cs == g2])
      obs_vd <- log(v1) - log(v2)
      md <- vd <- rep(NA_real_, n_permut)
      for (b in seq_len(n_permut)) {
        lp <- sample(labels_cs, length(labels_cs), replace=FALSE)
        vb1 <- stats::var(cs[lp == g1]); vb2 <- stats::var(cs[lp == g2])
        md[b] <- mean(cs[lp == g1]) - mean(cs[lp == g2])
        if (is.finite(vb1) && is.finite(vb2) && vb1 > 0 && vb2 > 0) vd[b] <- log(vb1) - log(vb2)
      }
      md <- md[is.finite(md)]; vd <- vd[is.finite(vd)]
      if (length(md) < min_valid || length(vd) < min_valid) next
      pmean <- (1 + sum(abs(md) >= abs(obs_md))) / (length(md) + 1)
      pvar <- (1 + sum(abs(vd) >= abs(obs_vd))) / (length(vd) + 1)

      rows[[length(rows) + 1L]] <- data.frame(
        Constructo=cn,
        Grupos=paste0(g1, " vs ", g2),
        Configuracional=TRUE,
        Configuracional_Criterio="Misma especificación de medición/estructura, algoritmo, tratamiento de datos y configuración en ambos grupos",
        Correlacion_original=observed_c[[cn]],
        Percentil_5_perm=q05,
        p_permutacion=pcomp,
        Compositional_Invariance=observed_c[[cn]] >= q05 && pcomp >= .05,
        Invarianza_composicional=NA_character_,
        Diferencia_medias=obs_md,
        p_dif_medias=pmean,
        Diferencia_log_varianzas=obs_vd,
        p_dif_varianzas=pvar,
        Permutaciones_validas=length(vals),
        Permutaciones_solicitadas=n_permut,
        Calidad_permutaciones=ifelse(n_permut >= 5000L, "Confirmatoria (≥5000)", "Exploratoria (<5000)"),
        Resultado=NA_character_,
        Metodo="MICOM 3 pasos; modelo y pesos reestimados en cada permutación; varianzas comparadas en escala logarítmica",
        stringsAsFactors=FALSE
      )
    }
  }

  if (!length(rows)) return(NULL)
  out <- do.call(rbind, rows)
  rownames(out) <- NULL

  adjust_within_construct <- function(p) {
    adjusted <- rep(NA_real_, length(p))
    for (ix in split(seq_along(p), out$Constructo)) {
      adjusted[ix] <- stats::p.adjust(p[ix], method="holm")
    }
    adjusted
  }
  out$p_permutacion_ajustado <- as.numeric(adjust_within_construct(out$p_permutacion))
  out$p_dif_medias_ajustado <- as.numeric(adjust_within_construct(out$p_dif_medias))
  out$p_dif_varianzas_ajustado <- as.numeric(adjust_within_construct(out$p_dif_varianzas))
  out$Compositional_Invariance <- with(out,
    Correlacion_original >= Percentil_5_perm & p_permutacion_ajustado >= .05)
  out$Invarianza_composicional <- ifelse(out$Compositional_Invariance, "Sí", "No")
  out$Resultado <- ifelse(!out$Compositional_Invariance,
    "Sin invarianza composicional",
    ifelse(out$p_dif_medias_ajustado >= .05 & out$p_dif_varianzas_ajustado >= .05,
      "Invarianza total", "Invarianza parcial"))
  out
}

calc_mga <- function(raw_df, p_df, group_var, n_permut=5000L,
                     m_model=NULL, s_model=NULL, micom_tbl=NULL, seed=42L) {
  if (is.null(group_var) || !group_var %in% names(raw_df) ||
      is.null(m_model) || is.null(s_model) || is.null(micom_tbl)) return(NULL)

  n_permut <- safe_int(n_permut, 5000L, 50L, 20000L)
  set.seed(seed)
  labels_all <- as.character(raw_df[[group_var]])
  tab <- table(labels_all, useNA="no")
  groups <- sort(names(tab)[tab >= 30L])
  if (length(groups) < 2L) return(NULL)

  item_cols <- setdiff(names(raw_df), group_var)
  Xall <- raw_df[, item_cols, drop=FALSE]
  pairs <- combn(groups, 2, simplify=FALSE)
  rows <- list()
  min_valid <- max(20L, ceiling(.8 * n_permut))

  for (pr in pairs) {
    g1 <- pr[1]; g2 <- pr[2]
    pair_name <- paste0(g1, " vs ", g2)
    micp <- micom_tbl[micom_tbl$Grupos == pair_name, , drop=FALSE]
    required_constructs <- unique(c(as.character(p_df$from),as.character(p_df$to)))
    micp_required <- micp[micp$Constructo %in% required_constructs,,drop=FALSE]
    if (!all(required_constructs %in% micp_required$Constructo) ||
        !all(micp_required$Compositional_Invariance %in% TRUE)) next
    eligible <- required_constructs

    idx <- which(labels_all %in% pr)
    lab <- labels_all[idx]
    Xp <- Xall[idx, , drop=FALSE]
    f1 <- estimate_group_model(Xp[lab == g1, , drop=FALSE], m_model, s_model, min_n=30L)
    f2 <- estimate_group_model(Xp[lab == g2, , drop=FALSE], m_model, s_model, min_n=30L)
    if (is.null(f1) || is.null(f2)) next

    b1 <- path_matrix_to_named(f1,p_df)
    b2 <- path_matrix_to_named(f2,p_df)
    common <- intersect(names(b1), names(b2))
    common <- common[vapply(strsplit(common, " -> ", fixed=TRUE), function(z) {
      length(z) == 2L && all(z %in% eligible)
    }, logical(1))]
    if (!length(common)) next

    perm_diff <- matrix(NA_real_, nrow=n_permut, ncol=length(common),
                        dimnames=list(NULL, common))
    for (b in seq_len(n_permut)) {
      lp <- sample(lab, length(lab), replace=FALSE)
      a1 <- estimate_group_model(Xp[lp == g1, , drop=FALSE], m_model, s_model, min_n=30L)
      a2 <- estimate_group_model(Xp[lp == g2, , drop=FALSE], m_model, s_model, min_n=30L)
      if (is.null(a1) || is.null(a2)) next
      q1 <- path_matrix_to_named(a1,p_df); q2 <- path_matrix_to_named(a2,p_df)
      for (pth in common) {
        if (pth %in% names(q1) && pth %in% names(q2)) perm_diff[b, pth] <- q1[pth] - q2[pth]
      }
    }

    for (pth in common) {
      vals <- perm_diff[, pth]
      vals <- vals[is.finite(vals)]
      if (length(vals) < min_valid) next
      observed_diff <- b1[pth] - b2[pth]
      p_raw <- (1 + sum(abs(vals) >= abs(observed_diff))) / (length(vals) + 1)
      ref_q <- as.numeric(stats::quantile(vals, c(.025, .975), names=FALSE, type=7))
      rows[[length(rows) + 1L]] <- data.frame(
        Relacion=pth,
        Grupos=pair_name,
        Beta_Grupo1=b1[pth],
        Beta_Grupo2=b2[pth],
        Diferencia=observed_diff,
        IC_2.5=ref_q[1],
        IC_97.5=ref_q[2],
        p_valor=p_raw,
        Permutaciones_validas=length(vals),
        Permutaciones_solicitadas=n_permut,
        Calidad_permutaciones=ifelse(n_permut >= 5000L, "Confirmatoria (≥5000)", "Exploratoria (<5000)"),
        MICOM_composicional=TRUE,
        Metodo="MGA por permutación con reestimación PLS en cada réplica, condicionado a MICOM",
        stringsAsFactors=FALSE
      )
    }
  }

  if (!length(rows)) return(NULL)
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out$p_ajustado <- stats::p.adjust(out$p_valor, method="holm")
  out$Sig <- ifelse(out$p_ajustado < .001, "***",
    ifelse(out$p_ajustado < .01, "**", ifelse(out$p_ajustado < .05, "*", "n.s.")))
  out
}

total_effect_matrix <- function(pls_est) {
  B<-tryCatch(as.matrix(pls_est$path_coef),error=function(e)NULL);if(is.null(B))return(NULL)
  nodes<-union(rownames(B),colnames(B));M<-matrix(0,length(nodes),length(nodes),dimnames=list(nodes,nodes));M[rownames(B),colnames(B)]<-B
  tryCatch(solve(diag(length(nodes))-M)-diag(length(nodes)),error=function(e)NULL)
}

calc_ipma <- function(pls_est,raw_df,p_df,construct_items,target=NULL,scale_min=1,scale_max=5) {
    scale_min<-as.numeric(scale_min);scale_max<-as.numeric(scale_max)
    if(!is.finite(scale_min)||!is.finite(scale_max)||scale_max<=scale_min)return(NULL)
    endo<-unique(as.character(p_df$to))
    if(is.null(target)||!nzchar(target))target<-tail(endo,1)
    if(!target%in%names(construct_items))return(NULL)
    all_items<-unique(unlist(construct_items,use.names=FALSE))
    item_cols<-intersect(all_items,names(raw_df))
    if(!length(item_cols))return(NULL)
    vals<-unlist(raw_df[,item_cols,drop=FALSE],use.names=FALSE)
    if(any(!is.finite(vals)) || any(vals<scale_min|vals>scale_max))return(NULL)

    W<-tryCatch(as.matrix(pls_est$outer_weights),error=function(e)NULL)
    if(is.null(W))return(NULL)
    score100<-list(); performance<-numeric()
    constructs<-intersect(names(construct_items),colnames(W))
    for(cn in constructs){
      its<-intersect(construct_items[[cn]],intersect(names(raw_df),rownames(W)))
      if(!length(its))next
      X<-as.matrix(raw_df[,its,drop=FALSE])
      sdi<-apply(X,2,stats::sd)
      w_std<-as.numeric(W[its,cn])
      ok<-is.finite(sdi)&sdi>1e-12&is.finite(w_std)
      X<-X[,ok,drop=FALSE];sdi<-sdi[ok];w_std<-w_std[ok]
      if(!length(w_std))next
      w_raw<-w_std/sdi
      norm_w<-sqrt(sum(w_raw^2))
      if(!is.finite(norm_w)||norm_w<1e-12)next
      w_raw<-w_raw/norm_w
      score<-as.numeric(X%*%w_raw)
      theoretical_low<-sum(ifelse(w_raw>=0,scale_min*w_raw,scale_max*w_raw))
      theoretical_high<-sum(ifelse(w_raw>=0,scale_max*w_raw,scale_min*w_raw))
      if(!is.finite(theoretical_low)||!is.finite(theoretical_high)||theoretical_high<=theoretical_low)next
      s100<-100*(score-theoretical_low)/(theoretical_high-theoretical_low)
      if(any(!is.finite(s100)) || any(s100 < -1e-8) || any(s100 > 100+1e-8))next
      score100[[cn]]<-pmin(100,pmax(0,s100))
      performance[cn]<-mean(score100[[cn]])
    }
    required<-unique(c(as.character(p_df$from),as.character(p_df$to)))
    if(!all(required%in%names(score100))||!target%in%names(score100))return(NULL)
    score_df<-as.data.frame(score100,check.names=FALSE)

    # Los coeficientes estructurales se reexpresan sobre scores 0–100. Esta
    # transformación conserva el modelo lineal y produce efectos totales no
    # estandarizados comparables, como requiere IPMA.
    nodes<-required
    B<-matrix(0,length(nodes),length(nodes),dimnames=list(nodes,nodes))
    for(y in unique(as.character(p_df$to))){
      preds<-unique(as.character(p_df$from[p_df$to==y]))
      if(!length(preds)||!all(c(y,preds)%in%names(score_df)))next
      Xreg<-cbind(`(Intercept)`=1,as.matrix(score_df[,preds,drop=FALSE]))
      fit<-tryCatch(stats::lm.fit(x=Xreg,y=as.numeric(score_df[[y]])),error=function(e)NULL)
      if(is.null(fit)||length(fit$coefficients)!=(length(preds)+1L))next
      co<-as.numeric(fit$coefficients[-1L]);names(co)<-preds
      for(x in preds)if(is.finite(co[x]))B[x,y]<-as.numeric(co[x])
    }
    T<-tryCatch(solve(diag(length(nodes))-B)-diag(length(nodes)),error=function(e)NULL)
    if(is.null(T)||!target%in%colnames(T))return(NULL)
    preds<-rownames(T)[is.finite(T[,target])&abs(T[,target])>1e-12]
    preds<-setdiff(preds,target)
    if(!length(preds))return(NULL)
    importance<-as.numeric(T[preds,target])
    perf<-as.numeric(performance[preds])
    keep<-is.finite(importance)&is.finite(perf)
    preds<-preds[keep];importance<-importance[keep];perf<-perf[keep]
    if(!length(preds))return(NULL)
    positive_importance<-importance[importance>0]
    mi<-if(length(positive_importance))mean(positive_importance) else NA_real_
    mp<-mean(perf)
    quadrant<-ifelse(importance<=0,"Efecto total negativo — interpretar antes de priorizar",
      ifelse(importance>=mi&perf<mp,"Alta imp. / bajo rend.: mejorar",
      ifelse(importance>=mi&perf>=mp,"Alta imp. / alto rend.: mantener",
      ifelse(importance<mi&perf<mp,"Baja imp. / bajo rend.: monitorear",
      "Baja imp. / alto rend.: revisar"))))
    data.frame(Target=target,Predictor=preds,Importancia_Efecto_Total=importance,
      Direccion_Efecto=ifelse(importance>0,"Positiva",ifelse(importance<0,"Negativa","Nula")),
      Performance_0_100=perf,Cuadrante=quadrant,
      Prioridad=ifelse(grepl("mejorar",quadrant),"Alta",ifelse(importance<=0,"No automática","Normal")),
      Scale_Min=scale_min,Scale_Max=scale_max,
      Metodo="Scores 0–100 con pesos desestandarizados y límites teóricos; efectos totales no estandarizados sobre esos scores",
      stringsAsFactors=FALSE)
}


# FIMIX-PLS oficial mediante seminrExtras. Se mantiene opt-in porque puede ser
# intensivo y requiere evaluar varias soluciones K con inicios aleatorios.
calc_fimix <- function(pls_est, k_min=2L, k_max=4L, nstart=10L,
                       max_iter=5000L, stop_criterion=1e-6, seed=123L) {
  if (!requireNamespace("seminrExtras", quietly=TRUE)) {
    stop("El módulo FIMIX-PLS requiere el paquete R 'seminrExtras' (>= 1.0.2). Ejecute npm run install:r.")
  }
  n <- tryCatch(nrow(as.data.frame(pls_est$construct_scores)), error=function(e) 0L)
  if (n < 60L) stop("FIMIX-PLS requiere al menos 60 observaciones para evaluar dos segmentos con un mínimo operativo de 30 casos por segmento.")
  max_feasible <- max(2L, floor(n/30L))
  k_min <- safe_int(k_min, 2L, 2L, max_feasible)
  k_max <- safe_int(k_max, max(k_min,4L), k_min, min(8L,max_feasible))
  nstart <- safe_int(nstart,10L,1L,50L)
  max_iter <- safe_int(max_iter,5000L,100L,50000L)
  stop_criterion <- suppressWarnings(as.numeric(stop_criterion[1]))
  if (!is.finite(stop_criterion) || stop_criterion <= 0 || stop_criterion >= .1) stop_criterion <- 1e-6
  seed <- safe_int(seed,123L,1L)

  cmp <- seminrExtras::assess_fimix_compare(
    pls_est, K_range=seq.int(k_min,k_max), nstart=nstart,
    max_iter=max_iter, stop_criterion=stop_criterion, seed=seed)
  fit <- tryCatch(as.data.frame(cmp$fit_table), error=function(e) NULL)
  if (is.null(fit) || !nrow(fit)) stop("seminrExtras no devolvió la tabla de comparación FIMIX.")
  if (!"K" %in% names(fit)) {
    kval <- suppressWarnings(as.integer(gsub("[^0-9]", "", rownames(fit))))
    if (any(!is.finite(kval))) kval <- seq.int(k_min, length.out=nrow(fit))
    fit <- cbind(K=kval, fit)
  }
  rownames(fit) <- NULL

  find_col <- function(patterns) {
    nn <- normalize_boot_name(names(fit))
    for (pat in patterns) {
      idx <- which(nn == normalize_boot_name(pat))
      if (length(idx)) return(names(fit)[idx[1]])
    }
    NA_character_
  }
  aic3_col <- find_col(c("AIC3")); caic_col <- find_col(c("CAIC")); aic4_col <- find_col(c("AIC4"));
  choose_min <- function(col) {
    if (is.na(col)) return(NA_integer_)
    vals <- suppressWarnings(as.numeric(fit[[col]]));
    if (!any(is.finite(vals))) return(NA_integer_)
    as.integer(fit$K[which.min(vals)])
  }
  k_aic3 <- choose_min(aic3_col); k_caic <- choose_min(caic_col); k_aic4 <- choose_min(aic4_col)
  if (is.finite(k_aic3) && is.finite(k_caic) && k_aic3 == k_caic) {
    selected_k <- k_aic3; selection_rule <- "Coincidencia AIC3 + CAIC"
  } else if (is.finite(k_aic4)) {
    selected_k <- k_aic4; selection_rule <- "Mínimo AIC4 ante desacuerdo AIC3/CAIC"
  } else {
    selected_k <- as.integer(fit$K[1]); selection_rule <- "Primera solución convergente disponible"
  }

  solutions <- cmp$solutions
  if (is.null(solutions) || !length(solutions)) stop("FIMIX no devolvió soluciones por K.")
  sol_names <- names(solutions) %||% rep("",length(solutions))
  idx <- which(grepl(paste0("(^|[^0-9])",selected_k,"([^0-9]|$)"), sol_names))
  if (!length(idx)) idx <- which(as.integer(fit$K) == selected_k)
  if (!length(idx) || idx[1] > length(solutions)) idx <- 1L
  sol <- solutions[[idx[1]]]

  assignment <- suppressWarnings(as.integer(sol$segment_assignment))
  posterior <- tryCatch(as.matrix(sol$posterior),error=function(e)NULL)
  if (length(assignment) != n) stop("La asignación FIMIX no coincide con el número de observaciones.")
  tab <- table(factor(assignment, levels=seq_len(selected_k)))
  props <- suppressWarnings(as.numeric(sol$segment_proportions))
  if (length(props) != selected_k) props <- as.numeric(tab)/sum(tab)
  segments <- data.frame(
    Segmento=seq_len(selected_k), N=as.integer(tab), Proporcion=props,
    K_seleccionado=selected_k, Regla_seleccion=selection_rule,
    Convergio=isTRUE(sol$converged), Iteraciones=as.integer(sol$iterations %||% NA_integer_),
    Inicios_completados=as.integer(sol$n_starts_completed %||% NA_integer_),
    stringsAsFactors=FALSE)

  path_rows <- list()
  sp <- sol$segment_paths %||% list()
  for (g in seq_along(sp)) {
    mat <- tryCatch(as.matrix(sp[[g]]),error=function(e)NULL)
    if (is.null(mat) || is.null(rownames(mat)) || is.null(colnames(mat))) next
    ix <- which(is.finite(mat) & abs(mat) > 1e-12, arr.ind=TRUE)
    if (!nrow(ix)) next
    for (j in seq_len(nrow(ix))) {
      path_rows[[length(path_rows)+1L]] <- data.frame(
        Segmento=g, Desde=rownames(mat)[ix[j,1]], Hacia=colnames(mat)[ix[j,2]],
        Ruta=paste0(rownames(mat)[ix[j,1]]," -> ",colnames(mat)[ix[j,2]]),
        Beta=as.numeric(mat[ix[j,1],ix[j,2]]), stringsAsFactors=FALSE)
    }
  }
  paths <- if(length(path_rows)) do.call(rbind,path_rows) else NULL
  post_max <- if(!is.null(posterior) && nrow(posterior)==n) apply(posterior,1,max,na.rm=TRUE) else rep(NA_real_,n)
  assignments <- data.frame(Fila_analitica=seq_len(n), Segmento=assignment,
                            Probabilidad_posterior_max=post_max, stringsAsFactors=FALSE)
  fit$Seleccionado <- as.integer(fit$K) == selected_k
  fit$Regla_seleccion <- ifelse(fit$Seleccionado,selection_rule,"")
  list(fit=fit, segments=segments, paths=paths, assignments=assignments,
       assignment=assignment, selected_k=selected_k, selection_rule=selection_rule)
}

# Comparación descriptiva y predictiva homogénea de tres especificaciones
# frecuentes en mediación: directa, paralela y secuencial. No se presenta como
# prueba de diferencia causal; permite contrastar R2, Q2 y SRMR bajo la misma
# medición y los mismos casos.
calc_model_comparison <- function(raw_df, m_model, roles, construct_names,
                                  construct_items, control_paths=NULL,
                                  omission_distance=7L, seed=123L) {
  x <- trimws(as.character(roles$x %||% "")); m1 <- trimws(as.character(roles$m1 %||% ""))
  m2 <- trimws(as.character(roles$m2 %||% "")); y <- trimws(as.character(roles$y %||% ""))
  rr <- c(x,m1,m2,y)
  if (any(!nzchar(rr)) || length(unique(rr)) != 4L || any(!rr %in% construct_names)) {
    stop("La comparación directo/paralelo/secuencial requiere cuatro constructos distintos: X, M1, M2 e Y.")
  }
  specs <- list(
    Directo=data.frame(from=x,to=y,stringsAsFactors=FALSE),
    Paralelo=data.frame(from=c(x,x,m1,m2),to=c(m1,m2,y,y),stringsAsFactors=FALSE),
    Secuencial=data.frame(from=c(x,m1,m2,x),to=c(m1,m2,y,y),stringsAsFactors=FALSE)
  )
  rows <- list()
  for (nm in names(specs)) {
    pdf <- specs[[nm]]
    if (!is.null(control_paths) && is.data.frame(control_paths) && nrow(control_paths)) {
      pdf <- unique(rbind(pdf, control_paths[,c("from","to"),drop=FALSE]))
    }
    sm_list <- lapply(seq_len(nrow(pdf)), function(i) seminr::paths(from=pdf$from[i],to=pdf$to[i]))
    sm <- tryCatch(do.call(seminr::relationships,sm_list),error=function(e)NULL)
    if (is.null(sm)) next
    est <- tryCatch(seminr::estimate_pls(data=raw_df,measurement_model=m_model,structural_model=sm),error=function(e)NULL)
    if (is.null(est)) next
    sc <- tryCatch(as.data.frame(est$construct_scores),error=function(e)NULL)
    r2vals <- adjvals <- numeric()
    if (!is.null(sc)) for (endo in unique(pdf$to)) {
      pred <- unique(pdf$from[pdf$to==endo]); pred <- pred[pred %in% names(sc)]
      if (!length(pred) || !endo %in% names(sc)) next
      f <- tryCatch(stats::lm(stats::reformulate(pred,response=endo),data=sc),error=function(e)NULL)
      if(!is.null(f)){ ss<-summary(f); r2vals<-c(r2vals,ss$r.squared); adjvals<-c(adjvals,ss$adj.r.squared) }
    }
    q2 <- tryCatch(calc_q2(raw_df,pdf,d=omission_distance,m_model=m_model,s_model=sm,
                            construct_items=construct_items,seed=seed),error=function(e)NULL)
    q2mean <- if(!is.null(q2)&&nrow(q2)) mean(as.numeric(q2$Q2),na.rm=TRUE) else NA_real_
    sr <- tryCatch(calc_srmr(est,summary(est),raw_df),error=function(e)NULL)
    sr_est <- NA_real_; sr_sat <- NA_real_
    if(!is.null(sr)&&nrow(sr)){
      iest<-grep("estimated",tolower(sr$Indice));isat<-grep("saturated",tolower(sr$Indice))
      if(length(iest))sr_est<-as.numeric(sr$Valor[iest[1]]);if(length(isat))sr_sat<-as.numeric(sr$Valor[isat[1]])
    }
    rows[[length(rows)+1L]] <- data.frame(
      Modelo=nm, Rutas=paste(paste0(pdf$from," -> ",pdf$to),collapse="; "),
      N_rutas=nrow(pdf), N_endogenos=length(unique(pdf$to)),
      R2_promedio=if(length(r2vals))mean(r2vals)else NA_real_,
      R2_ajustado_promedio=if(length(adjvals))mean(adjvals)else NA_real_,
      Q2_promedio=q2mean, SRMR_saturado=sr_sat, SRMR_estimado=sr_est,
      Alcance="Comparación descriptiva/predictiva bajo idéntica medición; no constituye por sí sola una prueba de superioridad causal",
      stringsAsFactors=FALSE)
  }
  if(!length(rows))return(NULL)
  out<-do.call(rbind,rows);rownames(out)<-NULL;out
}

run_pls_sem <- function(params) {
  tryCatch(message("[HOC_DEBUG] hoc_specs=", paste(names(params$hoc_specs %||% list()), collapse=",")), error=function(e) NULL)
  tryCatch(message("[HOC_DEBUG] constructs=", paste(sapply(params$constructs, function(ct) paste0(ct$name,"(hoc=",isTRUE(ct$is_hoc_placeholder %||% FALSE),")")), collapse=",")), error=function(e) NULL)
  ext <- tolower(tools::file_ext(params$data_path))
  df_raw <- if (ext %in% c("xlsx", "xls")) {
    openxlsx::read.xlsx(params$data_path)
  } else {
    read.csv(params$data_path, stringsAsFactors=FALSE, check.names=FALSE)
  }

  if (is.null(params$constructs) || length(params$constructs) < 2L) {
    return(list(success=FALSE, blocked=TRUE, reason="CONSTRUCTS_INVALID",
      error="PLS-SEM requiere al menos dos constructos definidos."))
  }
  construct_names <- vapply(params$constructs, function(ct) trimws(as.character(ct$name %||% "")), character(1))
  if (any(!nzchar(construct_names)) || anyDuplicated(construct_names)) {
    return(list(success=FALSE, blocked=TRUE, reason="CONSTRUCT_NAMES_INVALID",
      error="Los nombres de constructos deben ser no vacíos y únicos."))
  }

  # Variables de control: se integran como constructos de un indicador y rutas
  # hacia los resultados seleccionados. Deben ser numéricas o dummy; no se
  # duplican indicadores ni se agrega ruido artificial.
  control_specs <- params$control_variables %||% list()
  control_names <- character()
  if (length(control_specs)) {
    base_names <- construct_names
    for (ctrl in control_specs) {
      ctrl_col <- trimws(as.character(ctrl$column %||% ""))
      ctrl_name <- trimws(as.character(ctrl$name %||% ctrl_col))
      ctrl_targets <- unique(trimws(as.character(ctrl$targets %||% character())))
      ctrl_targets <- ctrl_targets[nzchar(ctrl_targets)]
      if (!nzchar(ctrl_col) || !nzchar(ctrl_name) || !length(ctrl_targets)) {
        return(list(success=FALSE, blocked=TRUE, reason="CONTROL_VARIABLE_INVALID",
          error="Cada variable de control requiere nombre, columna y al menos un constructo objetivo."))
      }
      if (!ctrl_col %in% names(df_raw)) {
        return(list(success=FALSE, blocked=TRUE, reason="CONTROL_COLUMN_NOT_FOUND",
          error=paste0("No se encontró la columna de control: ", ctrl_col)))
      }
      if (ctrl_name %in% c(base_names, control_names)) {
        return(list(success=FALSE, blocked=TRUE, reason="CONTROL_NAME_DUPLICATED",
          error=paste0("El nombre de control está duplicado o coincide con un constructo: ", ctrl_name)))
      }
      invalid_targets <- setdiff(ctrl_targets, base_names)
      if (length(invalid_targets)) {
        return(list(success=FALSE, blocked=TRUE, reason="CONTROL_TARGET_INVALID",
          error=paste0("Objetivos de control desconocidos: ", paste(invalid_targets, collapse=", "))))
      }
      params$constructs[[length(params$constructs)+1L]] <- list(
        name=ctrl_name, items=list(ctrl_col), is_control=TRUE, source_column=ctrl_col)
      for (target in ctrl_targets) {
        params$paths[[length(params$paths)+1L]] <- list(from=ctrl_name, to=target, is_control=TRUE)
      }
      control_names <- c(control_names, ctrl_name)
    }
    construct_names <- vapply(params$constructs, function(ct) trimws(as.character(ct$name %||% "")), character(1))
  }

  indicator_map <- lapply(params$constructs, function(ct) if(isTRUE(ct$is_hoc_placeholder %||% FALSE)) character(0) else unique(as.character(ct$items %||% character())))
  all_indicator_assignments <- unlist(indicator_map, use.names=FALSE)
  duplicate_indicators <- unique(all_indicator_assignments[duplicated(all_indicator_assignments)])
  if (length(duplicate_indicators)) {
    return(list(success=FALSE, blocked=TRUE, reason="INDICATOR_ASSIGNED_MULTIPLE_CONSTRUCTS",
      error=paste0("Cada indicador debe pertenecer a un solo constructo. Duplicados: ",
        paste(duplicate_indicators, collapse=", ")),
      duplicate_indicators=duplicate_indicators))
  }
  all_indicators <- unique(all_indicator_assignments)
  if (!length(all_indicators)) {
    return(list(success=FALSE, blocked=TRUE, reason="INDICATORS_MISSING",
      error="No se definieron indicadores para el modelo PLS-SEM."))
  }
  missing_indicators <- setdiff(all_indicators, names(df_raw))
  if (length(missing_indicators)) {
    return(list(success=FALSE, blocked=TRUE, reason="INDICATORS_NOT_FOUND",
      error=paste0("No se encontraron estos indicadores en la base: ", paste(missing_indicators, collapse=", ")),
      missing_indicators=missing_indicators))
  }

  df_num <- data.frame(row.names=seq_len(nrow(df_raw)))
  conversion_losses <- list()
  for (nm in all_indicators) {
    original <- df_raw[[nm]]
    text <- trimws(as.character(original))
    nonmissing_original <- !(is.na(original) | text == "")
    converted <- suppressWarnings(as.numeric(text))
    bad <- which(nonmissing_original & is.na(converted))
    if (length(bad)) conversion_losses[[nm]] <- bad
    df_num[[nm]] <- converted
  }
  if (length(conversion_losses)) {
    details <- vapply(names(conversion_losses), function(nm) {
      paste0(nm, " (filas ", paste(head(conversion_losses[[nm]], 10L), collapse=", "),
             if (length(conversion_losses[[nm]]) > 10L) ", ..." else "", ")")
    }, character(1))
    return(list(success=FALSE, blocked=TRUE, reason="NON_NUMERIC_INDICATORS",
      error=paste0("Se detectaron valores no numéricos en indicadores PLS-SEM: ", paste(details, collapse="; ")),
      conversion_losses=conversion_losses))
  }

  complete_idx <- complete.cases(df_num[, all_indicators, drop=FALSE])
  df_j <- df_num[complete_idx, all_indicators, drop=FALSE]
  raw_df <- df_j
  group_var_requested <- trimws(as.character(params$group_var %||% ""))
  analysis_df <- raw_df
  if (nzchar(group_var_requested)) {
    if (!group_var_requested %in% names(df_raw)) {
      return(list(success=FALSE, blocked=TRUE, reason="GROUP_VARIABLE_NOT_FOUND",
        error=paste0("La variable de grupo no existe en la base: ", group_var_requested)))
    }
    gv_original <- df_raw[[group_var_requested]][complete_idx]
    gv_text <- trimws(as.character(gv_original))
    gv_text[is.na(gv_original) | gv_text == ""] <- NA_character_
    analysis_df[[group_var_requested]] <- gv_text
  }
  N <- nrow(df_j)
  if (N < 30L) return(list(success=FALSE, blocked=TRUE, reason="MUESTRA_INSUFICIENTE",
    error=paste0("PLS-SEM requiere al menos 30 casos completos en los indicadores; n=", N, "."),
    n_original=nrow(df_raw), n_complete=N, n_excluded=sum(!complete_idx)))

  item_counts <- vapply(indicator_map, length, integer(1))
  is_control_construct <- vapply(params$constructs, function(ct) isTRUE(ct$is_control %||% FALSE), logical(1))
  is_hoc_placeholder <- vapply(params$constructs, function(ct) isTRUE(ct$is_hoc_placeholder %||% FALSE), logical(1))
  invalid_single <- item_counts < 2L & !is_control_construct & !is_hoc_placeholder
  if (any(invalid_single)) {
    bad <- construct_names[invalid_single]
    return(list(success=FALSE, blocked=TRUE, reason="SINGLE_ITEM_CONSTRUCTS",
      error=paste0("Los constructos [", paste(bad, collapse=", "),
        "] tienen menos de dos indicadores. Solo las variables de control declaradas pueden ser de un indicador; no se duplican indicadores ni se agrega jitter."),
      single_item_constructs=bad))
  }

  if (is.null(params$paths) || !length(params$paths)) {
    return(list(success=FALSE, blocked=TRUE, reason="PATHS_MISSING",
      error="Debe definirse al menos una relación estructural."))
  }
  path_from <- vapply(params$paths, function(pt) as.character(pt$from %||% ""), character(1))
  path_to <- vapply(params$paths, function(pt) as.character(pt$to %||% ""), character(1))
  # Agregar nombres HOC a construct_names para validacion de rutas
  hoc_names_early <- names(params$hoc_specs %||% list())
  construct_names_with_hoc <- unique(c(construct_names, hoc_names_early))
  invalid_endpoints <- setdiff(unique(c(path_from, path_to)), construct_names_with_hoc)
  if (length(invalid_endpoints) || any(!nzchar(path_from)) || any(!nzchar(path_to)) || any(path_from == path_to)) {
    return(list(success=FALSE, blocked=TRUE, reason="PATHS_INVALID",
      error=paste0("Rutas estructurales inválidas. Extremos desconocidos: ",
        paste(invalid_endpoints, collapse=", "), ". No se permiten autorutas.")))
  }
  path_keys_input <- paste(path_from, path_to, sep=" -> ")
  if (anyDuplicated(path_keys_input)) {
    return(list(success=FALSE, blocked=TRUE, reason="DUPLICATE_PATHS",
      error=paste0("Existen rutas estructurales duplicadas: ",
        paste(unique(path_keys_input[duplicated(path_keys_input)]), collapse=", "))))
  }

  c_seminr <- list()
  for (i in seq_along(params$constructs)) {
    ct <- params$constructs[[i]]
    items <- indicator_map[[i]]
    if (isTRUE(ct$is_hoc_placeholder %||% FALSE)) {
      # HOC placeholder - se reemplazara en Two-Stage, omitir de c_seminr por ahora
      next
    } else if (isTRUE(ct$is_control %||% FALSE)) {
      c_seminr[[length(c_seminr)+1L]] <- seminr::composite(ct$name, seminr::single_item(items[1]))
    } else {
      c_seminr[[length(c_seminr)+1L]] <- seminr::composite(ct$name, seminr::multi_items("", items))
    }
  }
  # ── HOC Two-Stage ─────────────────────────────────────────────────────────
  hoc_specs <- params$hoc_specs %||% list()
  hoc_names <- names(hoc_specs)
  hoc_loc_map <- list()
  if (length(hoc_names) > 0) {
    for (hn in hoc_names) hoc_loc_map[[hn]] <- as.character(unlist(hoc_specs[[hn]]))
    # STAGE 1: modelo saturado con todos los LOC
    loc_all <- unique(unlist(hoc_loc_map))
    stage1_names <- construct_names[!construct_names %in% hoc_names]
    stage1_c <- c_seminr[construct_names %in% stage1_names]
    s1_paths <- list()
    for (fi in seq_along(stage1_names)) for (ti in seq_along(stage1_names)) {
      if (fi==ti) next
      s1_paths[[length(s1_paths)+1]] <- seminr::paths(from=stage1_names[fi],to=stage1_names[ti])
    }
    sc_s1 <- tryCatch({
      s1m <- do.call(seminr::constructs,stage1_c)
      s1s <- do.call(seminr::relationships,s1_paths)
      as.data.frame(estimate_pls(data=df_j,measurement_model=s1m,structural_model=s1s)$construct_scores)
    }, error=function(e) NULL)
    # STAGE 2: scores de LOC como indicadores del HOC
    df_stage2 <- df_j
    hoc_c_seminr <- list()
    for (hn in hoc_names) {
      sc_cols <- c()
      for (ln in hoc_loc_map[[hn]]) {
        cn <- paste0("__hoc_",hn,"_",ln)
        if (!is.null(sc_s1) && ln %in% names(sc_s1)) {
          df_stage2[[cn]] <- as.numeric(sc_s1[[ln]])
        } else {
          idx_ln <- which(construct_names==ln)[1]
          if (!is.na(idx_ln)) df_stage2[[cn]] <- rowMeans(df_j[,indicator_map[[idx_ln]],drop=FALSE],na.rm=TRUE)
        }
        sc_cols <- c(sc_cols,cn)
      }
      if (length(sc_cols)>=2) hoc_c_seminr[[length(hoc_c_seminr)+1]] <- seminr::composite(hn,seminr::multi_items("",sc_cols))
    }
    df_j <- df_stage2
    c_seminr <- c(c_seminr, hoc_c_seminr)
  }
  # ───────────────────────────────────────────────────────────────────────────
  m_model <- do.call(seminr::constructs,c_seminr)

  p_seminr <- list(); p_df <- data.frame(from=character(),to=character(),stringsAsFactors=FALSE)
  for (pt in params$paths) {
    p_seminr[[length(p_seminr)+1]] <- seminr::paths(from=pt$from,to=pt$to)
    p_df <- rbind(p_df,data.frame(from=pt$from,to=pt$to,stringsAsFactors=FALSE))
  }
  if (!length(p_seminr)) stop("Ninguna relacion estructural.")
  s_model <- do.call(seminr::relationships,p_seminr)

  pls_est <- tryCatch(
    estimate_pls(data=df_j,measurement_model=m_model,structural_model=s_model),
    error=function(e) structure(list(error=conditionMessage(e)),class="pls_fit_error")
  )
  if (inherits(pls_est,"pls_fit_error")) return(list(success=FALSE,blocked=TRUE,reason="PLS_ESTIMATION_FAILED",error=pls_est$error))
  summ     <- summary(pls_est)
  scores_df <- tryCatch(as.data.frame(pls_est$construct_scores),error=function(e) NULL)

  n_boot <- suppressWarnings(as.integer(params$n_boot %||% 1000L))
  if (is.na(n_boot) || n_boot < 1000L) n_boot <- 1000L
  bootstrap_seed <- suppressWarnings(as.integer(params$bootstrap_seed %||% 20260704L))
  if (is.na(bootstrap_seed)) bootstrap_seed <- 20260704L
  had_seed <- exists(".Random.seed", envir=.GlobalEnv, inherits=FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir=.GlobalEnv, inherits=FALSE)
  on.exit({
    if (had_seed) assign(".Random.seed", old_seed, envir=.GlobalEnv)
    else if (exists(".Random.seed", envir=.GlobalEnv, inherits=FALSE)) rm(".Random.seed", envir=.GlobalEnv)
  }, add=TRUE)
  set.seed(bootstrap_seed)
  boot_est <- tryCatch(
    bootstrap_model(seminr_model=pls_est, nboot=n_boot, cores=1, seed=bootstrap_seed),
    error=function(e) structure(list(error=conditionMessage(e)), class="pls_boot_error")
  )
  if (inherits(boot_est,"pls_boot_error")) return(list(success=FALSE,blocked=TRUE,reason="PLS_BOOTSTRAP_FAILED",error=boot_est$error))
  boot_summ <- tryCatch(summary(boot_est),error=function(e) NULL)
  if (is.null(boot_summ)) return(list(success=FALSE,blocked=TRUE,reason="PLS_BOOTSTRAP_SUMMARY_FAILED",error="No se pudo resumir el bootstrap PLS."))
  bp <- tryCatch(as.data.frame(boot_summ$bootstrapped_paths),error=function(e) NULL)
  if (is.null(bp) || nrow(bp)==0) return(list(success=FALSE,blocked=TRUE,reason="PLS_BOOTSTRAP_PATHS_MISSING",error="El bootstrap no devolvió rutas estructurales."))

  path_keys <- paste0(p_df$from, " -> ", p_df$to)
  extracted_paths <- extract_boot_table(bp, "direct_paths")
  if (is.null(extracted_paths) || !is.null(extracted_paths$error)) {
    return(list(success=FALSE, blocked=TRUE, reason="PLS_BOOTSTRAP_SCHEMA_UNRECOGNIZED",
      error=extracted_paths$error %||% "No se pudo interpretar la tabla bootstrap de rutas.",
      available_columns=names(bp), mapping=extracted_paths$mapping %||% NULL))
  }
  boot_paths <- extracted_paths$data
  norm_boot <- gsub("\\s+", "", boot_paths$Path)
  norm_expected <- gsub("\\s+", "", path_keys)
  idx <- match(norm_expected, norm_boot)
  if (anyNA(idx)) {
    return(list(success=FALSE, blocked=TRUE, reason="PLS_BOOTSTRAP_PATH_MISMATCH",
      error=paste0("El bootstrap no devolvió todas las rutas esperadas: ",
        paste(path_keys[is.na(idx)], collapse=", ")),
      returned_paths=boot_paths$Path))
  }
  boot_paths <- boot_paths[idx, , drop=FALSE]
  path_lbl <- path_keys
  beta_v <- boot_paths$Estimate
  STDEV_raw <- boot_paths$SE
  ci_lo_v <- boot_paths$CI_Lower
  ci_hi_v <- boot_paths$CI_Upper
  T_raw <- beta_v / STDEV_raw
  p_raw <- 2 * stats::pnorm(abs(T_raw), lower.tail=FALSE)
  ci_sig <- (ci_lo_v > 0 & ci_hi_v > 0) | (ci_lo_v < 0 & ci_hi_v < 0)

  f2_tbl <- calc_f2(scores_df,p_df)
  f2_map <- if(!is.null(f2_tbl)) setNames(f2_tbl$f2,gsub("\\s+","",f2_tbl$Path)) else c()

  paths_tbl <- data.frame(
    Path=path_lbl,
    Tipo_Ruta=ifelse(p_df$from %in% control_names,"Control","Hipótesis estructural"),
    Beta=beta_v,
    STDEV=STDEV_raw,
    T_Valor=T_raw,
    P_Valor=p_raw,
    IC_2.5=ci_lo_v,
    IC_97.5=ci_hi_v,
    CI_Significant=ci_sig,
    Sig=ifelse(ci_sig, "CI excluye 0", "CI incluye 0"),
    Inference_Primary="percentile_bootstrap_ci",
    P_Method="normal_approximation_from_bootstrap_se",
    f2=sapply(gsub("\\s+", "", path_lbl), function(k) f2_map[k] %||% NA_real_),
    stringsAsFactors=FALSE
  )

  rel_raw <- tryCatch(as.data.frame(summ$reliability),error=function(e) NULL)
  cr_ave_calc <- calc_cr_ave(summ$loadings); constructs_rel <- if(!is.null(rel_raw)) rownames(rel_raw) else cr_ave_calc$Constructo
  cr_map <- setNames(cr_ave_calc$CR,cr_ave_calc$Constructo); ave_map <- setNames(cr_ave_calc$AVE,cr_ave_calc$Constructo)
  alpha_v <- if(!is.null(rel_raw)) { idx<-grep("cronbach|alpha",tolower(names(rel_raw)))[1]; if(!is.na(idx)) suppressWarnings(as.numeric(rel_raw[[idx]])) else rep(NA_real_,length(constructs_rel)) } else rep(NA_real_,length(constructs_rel))
  rhoa_v  <- if(!is.null(rel_raw)) { idx<-grep("rho_a|rhoa",tolower(names(rel_raw)))[1]; if(!is.na(idx)) suppressWarnings(as.numeric(rel_raw[[idx]])) else rep(NA_real_,length(constructs_rel)) } else rep(NA_real_,length(constructs_rel))

  reliability_tbl <- data.frame(Constructo=constructs_rel,Cronbach_Alpha=round(alpha_v,3),rho_A=round(rhoa_v,3),
    Composite_Reliability_CR=sapply(cr_map[constructs_rel],safe_num),AVE=sapply(ave_map[constructs_rel],safe_num),check.names=FALSE,stringsAsFactors=FALSE)
  reliability_tbl$Tipo <- ifelse(reliability_tbl$Constructo %in% control_names,
    "Control de un indicador (consistencia interna no aplicable)", "Constructo del modelo de medición")
  # Etiquetar HOC y LOC en reliability_tbl
  if (length(hoc_names) > 0) {
    all_loc <- unique(unlist(hoc_loc_map))
    reliability_tbl$Tipo[reliability_tbl$Constructo %in% hoc_names] <- "Constructo de segundo orden (HOC)"
    reliability_tbl$Tipo[reliability_tbl$Constructo %in% all_loc] <- "Constructo de primer orden (LOC)"
    # Tabla HOC: cargas de LOC sobre HOC
    hoc_loadings_list <- list()
    for (hn in hoc_names) {
      loc_names_h <- hoc_loc_map[[hn]]
      hoc_cols <- paste0("__hoc_", hn, "_", loc_names_h)
      hoc_cols_exist <- hoc_cols[hoc_cols %in% rownames(as.matrix(summ$loadings))]
      if (length(hoc_cols_exist) > 0) {
        ld_mat_h <- as.matrix(summ$loadings)
        for (ci in seq_along(hoc_cols_exist)) {
          col_h <- hoc_cols_exist[ci]
          load_val <- if (hn %in% colnames(ld_mat_h) && col_h %in% rownames(ld_mat_h)) round(ld_mat_h[col_h, hn], 3) else NA_real_
          loc_label <- loc_names_h[ci]
          hoc_loadings_list[[length(hoc_loadings_list)+1]] <- data.frame(
            HOC=hn, LOC=loc_label, Carga=load_val,
            OK=ifelse(!is.na(load_val) & load_val>=0.7, "✓", ifelse(!is.na(load_val) & load_val>=0.4, "⚠", "✗")),
            stringsAsFactors=FALSE)
        }
      }
    }
    hoc_loadings_tbl <- if (length(hoc_loadings_list)>0) do.call(rbind, hoc_loadings_list) else data.frame()
  } else {
    hoc_loadings_tbl <- data.frame()
  }
  if (length(control_names)) {
    reliability_tbl$Cronbach_Alpha[reliability_tbl$Constructo %in% control_names] <- NA_real_
    reliability_tbl$rho_A[reliability_tbl$Constructo %in% control_names] <- NA_real_
  }

  ld <- summ$loadings
  loadings_tbl <- as.data.frame(as.table(ld)) %>% filter(Freq!=0) %>% rename(Item=Var1,Constructo=Var2,Loading=Freq) %>%
    mutate(Loading=round(as.numeric(Loading),3),OK=ifelse(Loading>=0.7,"\u2713",ifelse(Loading>=0.4,"\u26a0","\u2717")),
           Tipo=ifelse(Constructo %in% control_names,"Control de un indicador","Indicador del constructo")) %>%
    filter(!grepl("^__hoc_", Item))  # Excluir scores HOC de cargas de primer orden

  r2_tbl <- data.frame(Constructo=character(),R2=numeric(),R2_adj=numeric(),Nivel=character(),stringsAsFactors=FALSE)
  for (endo in unique(p_df$to)) {
    preds <- unique(p_df$from[p_df$to==endo]); preds <- preds[preds %in% names(scores_df)]
    if (!length(preds)||!endo %in% names(scores_df)) next
    fit <- tryCatch(stats::lm(y~.,data=data.frame(y=scores_df[[endo]],scores_df[,preds,drop=FALSE])),error=function(e) NULL)
    if (!is.null(fit)) { s<-summary(fit); r2_tbl <- rbind(r2_tbl,data.frame(Constructo=endo,R2=round(s$r.squared,3),R2_adj=round(s$adj.r.squared,3),Nivel=ifelse(s$r.squared>=0.75,"Sustancial",ifelse(s$r.squared>=0.50,"Moderado",ifelse(s$r.squared>=0.25,"D\u00e9bil","Muy d\u00e9bil"))),stringsAsFactors=FALSE)) }
  }

  main_path_idx <- which(!(p_df$from %in% control_names))
  # Leer direcciones esperadas desde params$paths (campo direction de cada ruta)
  # direction: "positiva" | "negativa" | "no_direccional" (default)
  hyp_directions <- tryCatch({
    dirs <- list()
    for (pt in params$paths) {
      if (!isTRUE(pt$is_control)) {
        path_key <- paste0(pt$from, " -> ", pt$to)
        dirs[[path_key]] <- tolower(trimws(as.character(pt$direction %||% "no_direccional")))
      }
    }
    dirs
  }, error = function(e) list())

  decide_hypothesis <- function(beta, ci_sig, path, h_idx) {
    ci_ok  <- isTRUE(ci_sig)
    beta_n <- suppressWarnings(as.numeric(beta))
    # Buscar direccion esperada por ruta o por indice
    dir_exp <- hyp_directions[[path]] %||%
               hyp_directions[[paste0("H", h_idx)]] %||%
               "no_direccional"
    if (!ci_ok) return("✗ No soportada")
    if (dir_exp == "positiva") {
      if (!is.na(beta_n) && beta_n > 0) return("✓ Soportada")
      if (!is.na(beta_n) && beta_n < 0) return("✗ No soportada: signo contrario a la hipotesis")
    } else if (dir_exp == "negativa") {
      if (!is.na(beta_n) && beta_n < 0) return("✓ Soportada")
      if (!is.na(beta_n) && beta_n > 0) return("✗ No soportada: signo contrario a la hipotesis")
    }
    # No direccional o sin info: solo importa CI
    "✓ Soportada"
  }

  hyp_rows <- lapply(seq_along(main_path_idx), function(h) {
    k <- main_path_idx[h]
    path_k <- as.character(paths_tbl$Path[k])
    beta_k <- paths_tbl$Beta[k]
    ci_k   <- paths_tbl$CI_Significant[k]
    decision_k <- decide_hypothesis(beta_k, ci_k, path_k, h)
    data.frame(
      Hipotesis        = paste0("H", h),
      Relacion         = path_k,
      Beta             = beta_k,
      T_Valor          = paths_tbl$T_Valor[k],
      P_Valor          = paths_tbl$P_Valor[k],
      Sig              = paths_tbl$Sig[k],
      Decision         = decision_k,
      Criterio_Primario = "IC bootstrap percentil del 95% excluye cero",
      stringsAsFactors = FALSE)
  })
  hypotheses_tbl <- if(length(hyp_rows)) do.call(rbind,hyp_rows) else NULL
  controls_tbl <- if(length(control_names)) data.frame(
    Control=control_names,
    Columna=vapply(params$constructs[construct_names %in% control_names], function(ct) as.character(ct$source_column %||% ct$items[[1]]), character(1)),
    Destinos=vapply(control_names, function(nm) paste(p_df$to[p_df$from==nm],collapse=", "), character(1)),
    stringsAsFactors=FALSE) else NULL

  indirect_tbl <- calc_indirect(paths_tbl, p_df, boot_est, n_boot=n_boot, alpha=.05)
  total_tbl    <- calc_total(paths_tbl,indirect_tbl,p_df)
  construct_items_map <- setNames(
    lapply(params$constructs, function(ct) as.character(ct$items)),
    sapply(params$constructs, function(ct) as.character(ct$name)))

  advanced_enabled <- as_flag(params$advanced_pls, TRUE)
  module_status <- list()
  run_advanced <- function(name, enabled, expr) {
    if (!enabled) {
      module_status[[name]] <<- "disabled_by_configuration"
      return(NULL)
    }
    value <- tryCatch(force(expr), error=function(e) structure(list(message=conditionMessage(e)), class="advanced_failure"))
    if (inherits(value, "advanced_failure")) {
      module_status[[name]] <<- paste0("failed_closed: ", value$message)
      return(NULL)
    }
    if (is.null(value) || (is.data.frame(value) && nrow(value)==0L)) {
      module_status[[name]] <<- "not_applicable"
      return(NULL)
    }
    module_status[[name]] <<- "implemented"
    value
  }

  q2_tbl <- run_advanced("Q2", advanced_enabled && as_flag(params$calc_q2, TRUE),
    calc_q2(raw_df, p_df,
      d=safe_int(params$q2_omission_distance, 7L, 5L, 12L),
      m_model=m_model, s_model=s_model, construct_items=construct_items_map,
      seed=safe_int(params$advanced_seed, bootstrap_seed, 1L)))

  pls_predict_tbl <- run_advanced("PLSPredict", advanced_enabled && as_flag(params$calc_pls_predict, TRUE),
    calc_pls_predict(pls_est, raw_df, p_df, construct_items_map,
      k_folds=safe_int(params$pls_predict_folds, 10L, 2L),
      reps=safe_int(params$pls_predict_reps, 10L, 1L, 20L),
      seed=safe_int(params$advanced_seed, bootstrap_seed, 1L)))

  srmr_tbl <- run_advanced("SRMR", advanced_enabled && as_flag(params$calc_srmr, TRUE),
    calc_srmr(pls_est, summ, raw_df))
  htmt_ci_tbl <- run_advanced("HTMT_CI", advanced_enabled && as_flag(params$calc_htmt_ci, TRUE),
    calc_htmt_ci(boot_est, summ, alpha=.05))
  full_vif_tbl <- run_advanced("FullVIF_CMB", advanced_enabled && as_flag(params$calc_full_vif, TRUE),
    calc_full_vif(scores_df[,setdiff(names(scores_df),control_names),drop=FALSE],
      threshold=as.numeric(params$full_vif_threshold %||% 3.3)))
  vaf_tbl <- run_advanced("VAF", advanced_enabled && as_flag(params$calc_vaf, TRUE),
    calc_vaf_mediation(paths_tbl, indirect_tbl, p_df, boot_est=boot_est))
  ipma_tbl <- run_advanced("IPMA", advanced_enabled && as_flag(params$calc_ipma, TRUE),
    calc_ipma(pls_est, raw_df, p_df[!(p_df$from %in% control_names),,drop=FALSE],
      construct_items_map[setdiff(names(construct_items_map),control_names)],
      target=as.character(params$ipma_target %||% ""),
      scale_min=as.numeric(params$scale_min %||% 1),
      scale_max=as.numeric(params$scale_max %||% 5)))

  copula_tbl <- run_advanced("GaussianCopula",
    advanced_enabled && as_flag(params$calc_gaussian_copula, FALSE),
    calc_gaussian_copula(pls_est,raw_df,p_df,m_model=m_model,
      n_boot=safe_int(params$copula_boot, 5000L, 1000L, 10000L),
      seed=safe_int(params$advanced_seed, bootstrap_seed, 1L)))

  # Heterogeneidad no observada. FIMIX es opt-in y usa la implementación
  # oficial de seminrExtras. La solución elegida puede alimentar MICOM/MGA.
  fimix_obj <- run_advanced("FIMIX",
    advanced_enabled && as_flag(params$calc_fimix, FALSE),
    calc_fimix(pls_est,
      k_min=safe_int(params$fimix_k_min,2L,2L,8L),
      k_max=safe_int(params$fimix_k_max,4L,2L,8L),
      nstart=safe_int(params$fimix_nstart,10L,1L,50L),
      max_iter=safe_int(params$fimix_max_iter,5000L,100L,50000L),
      stop_criterion=as.numeric(params$fimix_stop_criterion %||% 1e-6),
      seed=safe_int(params$advanced_seed, bootstrap_seed, 1L)+20000L))
  fimix_fit_tbl <- if(is.list(fimix_obj)) fimix_obj$fit else NULL
  fimix_segments_tbl <- if(is.list(fimix_obj)) fimix_obj$segments else NULL
  fimix_paths_tbl <- if(is.list(fimix_obj)) fimix_obj$paths else NULL
  fimix_assignments_tbl <- if(is.list(fimix_obj)) fimix_obj$assignments else NULL

  model_comparison_tbl <- run_advanced("ModelComparison",
    advanced_enabled && as_flag(params$compare_models, FALSE),
    calc_model_comparison(raw_df,m_model,params$comparison_roles %||% list(),
      setdiff(construct_names,control_names),construct_items_map,
      control_paths=p_df[p_df$from %in% control_names,c("from","to"),drop=FALSE],
      omission_distance=safe_int(params$q2_omission_distance,7L,5L,12L),
      seed=safe_int(params$advanced_seed, bootstrap_seed, 1L)+30000L))

  group_var <- group_var_requested
  group_source <- if(nzchar(group_var)) "observed_variable" else "none"
  if (!nzchar(group_var) && as_flag(params$use_fimix_for_mga, TRUE) &&
      is.list(fimix_obj) && length(fimix_obj$assignment)==nrow(analysis_df)) {
    group_var <- ".FIMIX_SEGMENT"
    analysis_df[[group_var]] <- paste0("Segmento ",as.integer(fimix_obj$assignment))
    group_source <- paste0("fimix_selected_k_",fimix_obj$selected_k)
  }

  group_enabled <- advanced_enabled && nzchar(group_var)
  n_permut_advanced <- safe_int(params$n_permut, 5000L, 50L, 20000L)
  micom_tbl <- run_advanced("MICOM",
    group_enabled && as_flag(params$calc_micom, TRUE),
    calc_micom(analysis_df,p_df,pls_est,summ,group_var,
      n_permut=n_permut_advanced,
      m_model=m_model,s_model=s_model,
      seed=safe_int(params$advanced_seed, bootstrap_seed, 1L)))
  mga_tbl <- run_advanced("MGA",
    group_enabled && as_flag(params$calc_mga, TRUE) && !is.null(micom_tbl),
    calc_mga(analysis_df,p_df,group_var,
      n_permut=n_permut_advanced,
      m_model=m_model,s_model=s_model,micom_tbl=micom_tbl,
      seed=safe_int(params$advanced_seed, bootstrap_seed, 1L)+10000L))
  if (!is.null(micom_tbl) && n_permut_advanced < 5000L)
    module_status$MICOM <- "implemented_exploratory_lt_5000_permutations"
  if (!is.null(mga_tbl) && n_permut_advanced < 5000L)
    module_status$MGA <- "implemented_exploratory_lt_5000_permutations"

  if (!advanced_enabled) {
    for (nm in c("Q2","PLSPredict","SRMR","HTMT_CI","FullVIF_CMB","VAF","IPMA","GaussianCopula","FIMIX","MICOM","MGA","ModelComparison"))
      if (is.null(module_status[[nm]])) module_status[[nm]] <- "disabled_by_configuration"
  } else {
    if (!nzchar(group_var)) {
      module_status$MICOM <- "not_applicable_without_group_variable_or_fimix_assignment"
      module_status$MGA <- "not_applicable_without_group_variable_or_fimix_assignment"
    }
    if (!as_flag(params$calc_gaussian_copula, FALSE)) module_status$GaussianCopula <- "disabled_by_configuration_opt_in"
    if (!as_flag(params$calc_fimix, FALSE)) module_status$FIMIX <- "disabled_by_configuration_opt_in"
    if (!as_flag(params$compare_models, FALSE)) module_status$ModelComparison <- "disabled_by_configuration_opt_in"
  }
  module_status$Controls <- if(length(control_names)) "implemented_single_item_controls" else "not_applicable"
  module_status$IndirectEffects <- if(is.null(indirect_tbl)) "not_applicable" else "implemented_from_seminr_boot_paths"

  htmt_tbl <- calc_htmt(summ,raw_df)
  if (!is.null(htmt_tbl) && length(control_names))
    htmt_tbl <- htmt_tbl[!(htmt_tbl$C1 %in% control_names | htmt_tbl$C2 %in% control_names),,drop=FALSE]
  if (!is.null(htmt_ci_tbl) && length(control_names))
    htmt_ci_tbl <- htmt_ci_tbl[!(htmt_ci_tbl$C1 %in% control_names | htmt_ci_tbl$C2 %in% control_names),,drop=FALSE]
  fl_tbl <- calc_fornell_larcker(summ,scores_df)
  if (!is.null(fl_tbl) && length(control_names)) {
    fl_tbl <- fl_tbl[!(fl_tbl$Constructo %in% control_names),,drop=FALSE]
    fl_tbl <- fl_tbl[,setdiff(names(fl_tbl),control_names),drop=FALSE]
  }
  cross_tbl <- calc_cross_loadings(summ,scores_df,raw_df)

  list(
    success=TRUE,
    engine="cancharios_pls_sem_advanced_web_v2",
    advanced_enabled=advanced_enabled,
    n_observations=N,
    n_original=nrow(df_raw),
    n_excluded_missing=sum(!complete_idx),
    n_boot=n_boot,
    bootstrap_seed=bootstrap_seed,
    group_source=group_source,
    controls=control_names,
    bootstrap_column_mapping=extracted_paths$mapping,
    advanced_modules=module_status,
    tables=list(
      Paths=paths_tbl, Confiabilidad=reliability_tbl, Cargas=loadings_tbl,
      HOCLoadings=if(nrow(hoc_loadings_tbl)>0) hoc_loadings_tbl else NULL,
      hoc_specs=if(length(hoc_names)>0) hoc_loc_map else NULL,
      R2=r2_tbl, Hypotheses=hypotheses_tbl, Controls=controls_tbl,
      HTMT=htmt_tbl, FornellLarcker=fl_tbl,
      CrossLoadings=cross_tbl,
      VIF=calc_vif(scores_df,p_df),
      SRMR=srmr_tbl,
      Q2=q2_tbl,
      IndirectEffects=indirect_tbl, TotalEffects=total_tbl,
      PLSPredict=pls_predict_tbl,
      VAF_Mediacion=vaf_tbl,
      HTMT_CI=htmt_ci_tbl,
      FullVIF_CMB=full_vif_tbl,
      GaussianCopula=copula_tbl,
      FIMIX_Fit=fimix_fit_tbl,
      FIMIX_Segments=fimix_segments_tbl,
      FIMIX_Paths=fimix_paths_tbl,
      FIMIX_Assignments=fimix_assignments_tbl,
      ModelComparison=model_comparison_tbl,
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
