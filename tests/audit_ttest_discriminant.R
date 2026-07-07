# FASE 3D — T-test / Discriminante / Cluster / Descriptivos
# Secciones O (30), P (15), Q (11), R (4) = 60 tests
options(encoding = "UTF-8")

`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && !is.na(a[1]) && a[1] != "") a else b

.script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    f <- sub("--file=", "", grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE))
    if (length(f) > 0) dirname(normalizePath(f)) else getwd()
  }
)
r_dir <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "R")

source(file.path(r_dir, "helpers.R"))
source(file.path(r_dir, "t_test.R"))
source(file.path(r_dir, "discriminant.R"))
source(file.path(r_dir, "cluster.R"))
source(file.path(r_dir, "descriptives_full.R"))

pass_count <- 0L; fail_count <- 0L
chk <- function(id, desc, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) FALSE)
  if (ok) { pass_count <<- pass_count + 1L; cat(sprintf("  [PASS] %s: %s\n", id, desc)) }
  else     { fail_count <<- fail_count + 1L; cat(sprintf("  [FAIL] %s: %s\n", id, desc)) }
}

# -----------------------------------------------------------------------
# DATOS COMPARTIDOS
# -----------------------------------------------------------------------
set.seed(42)
x1_ind <- rnorm(60, mean = 5.0, sd = 1.2)
x2_ind <- rnorm(60, mean = 4.2, sd = 1.5)

set.seed(99)
x1_par <- rnorm(40, mean = 3.5, sd = 1.0)
x2_par <- x1_par + rnorm(40, mean = 0.8, sd = 0.5)

x1_mw <- c(2,3,4,3,5,2,3,4,5,4)
x2_mw <- c(5,6,7,5,8,6,7,6,5,7)

# -----------------------------------------------------------------------
# SECCION O — T-TEST (30 tests)
# -----------------------------------------------------------------------
cat("\n=== SECCION O — T-TEST ===\n\n")

res_tind <- t_independent(x1_ind, x2_ind)
ref_twe  <- t.test(x1_ind, x2_ind, var.equal = FALSE)
ref_teq  <- t.test(x1_ind, x2_ind, var.equal = TRUE)
n1t <- sum(!is.na(x1_ind)); n2t <- sum(!is.na(x2_ind))
sp  <- sqrt(((n1t-1)*var(x1_ind) + (n2t-1)*var(x2_ind)) / (n1t+n2t-2))
d_ref_ind <- round((mean(x1_ind) - mean(x2_ind)) / sp, 3)

cat("--- [O.TIND] t independiente ---\n")
chk("O.TIND.01", "test_type = 't_independiente'",
    res_tind$test_type == "t_independiente")
chk("O.TIND.02", "t_welch vs t.test(var.equal=FALSE)$statistic con 4dp",
    abs(res_tind$t_welch - round(ref_twe$statistic, 4)) < 1e-10)
chk("O.TIND.03", "df_welch vs t.test(var.equal=FALSE)$parameter con 2dp",
    abs(res_tind$df_welch - round(ref_twe$parameter, 2)) < 1e-10)
chk("O.TIND.04", "p_welch vs t.test(var.equal=FALSE)$p.value con 4dp",
    abs(res_tind$p_welch - round(ref_twe$p.value, 4)) < 1e-10)
chk("O.TIND.05", "t_student vs t.test(var.equal=TRUE)$statistic con 4dp",
    abs(res_tind$t_student - round(ref_teq$statistic, 4)) < 1e-10)
chk("O.TIND.06", "ci_lower vs t.test(Welch)$conf.int[1] con 3dp",
    abs(res_tind$ci_lower - round(ref_twe$conf.int[1], 3)) < 1e-10)
chk("O.TIND.07", "ci_upper vs t.test(Welch)$conf.int[2] con 3dp",
    abs(res_tind$ci_upper - round(ref_twe$conf.int[2], 3)) < 1e-10)
chk("O.TIND.08", "mean_diff = round(mean(x1)-mean(x2), 3)",
    abs(res_tind$mean_diff - round(mean(x1_ind) - mean(x2_ind), 3)) < 1e-10)
chk("O.TIND.09", "d_cohen = (mean1-mean2)/sd_pooled con 3dp",
    abs(res_tind$d - d_ref_ind) < 1e-10)
chk("O.TIND.10", "levene$F es numerico positivo",
    is.numeric(res_tind$levene$F) && !is.na(res_tind$levene$F) && res_tind$levene$F > 0)
chk("O.TIND.11", "levene$equal_variances es logico",
    is.logical(res_tind$levene$equal_variances))
chk("O.TIND.12", "method_used consistente con levene$equal_variances",
    if (!res_tind$levene$equal_variances) grepl("Welch", res_tind$method_used)
    else grepl("Student", res_tind$method_used))
chk("O.TIND.13", "significant = (p < alpha)",
    res_tind$significant == (res_tind$p < 0.05))
chk("O.TIND.14", "guard n<3 retorna $error",
    !is.null(compute_ttest(c(1, 2), c(1, 2, 3, 4, 5))$error))
chk("O.TIND.15", "descriptives group1$n = n valido de x1",
    res_tind$descriptives$group1$n == sum(!is.na(x1_ind)))

cat("\n--- [O.TPAR] t pareada ---\n")
res_tpar <- t_paired(x1_par, x2_par)
ref_tp   <- t.test(x1_par, x2_par, paired = TRUE)
valid_p  <- complete.cases(x1_par, x2_par)
dif_par  <- x1_par[valid_p] - x2_par[valid_p]
d_ref_par <- round(mean(dif_par) / sd(dif_par), 3)

chk("O.TPAR.01", "test_type = 't_pareada'",
    res_tpar$test_type == "t_pareada")
chk("O.TPAR.02", "t vs t.test(paired=TRUE)$statistic con 4dp",
    abs(res_tpar$t - round(ref_tp$statistic, 4)) < 1e-10)
chk("O.TPAR.03", "df = n_pares - 1",
    res_tpar$df == length(dif_par) - 1)
chk("O.TPAR.04", "p vs t.test(paired=TRUE)$p.value con 4dp",
    abs(res_tpar$p - round(ref_tp$p.value, 4)) < 1e-10)
chk("O.TPAR.05", "mean_diff = round(mean(dif), 3)",
    abs(res_tpar$mean_diff - round(mean(dif_par), 3)) < 1e-10)
chk("O.TPAR.06", "sd_diff = round(sd(dif), 3)",
    abs(res_tpar$sd_diff - round(sd(dif_par), 3)) < 1e-10)
chk("O.TPAR.07", "d_cohen_pareado = round(mean(dif)/sd(dif), 3)",
    abs(res_tpar$d - d_ref_par) < 1e-10)
chk("O.TPAR.08", "normality_diff$W es numerico no-NA",
    is.numeric(res_tpar$normality_diff$W) && !is.na(res_tpar$normality_diff$W))

cat("\n--- [O.MW] Mann-Whitney ---\n")
res_mw <- mann_whitney(x1_mw, x2_mw)
ref_mw <- wilcox.test(x1_mw, x2_mw, correct = TRUE, conf.int = TRUE)
n1_mw  <- length(x1_mw); n2_mw <- length(x2_mw)
r_rb_ref <- round(1 - 2*as.numeric(ref_mw$statistic)/(n1_mw*n2_mw), 3)

chk("O.MW.01", "test_type = 'mann_whitney'",
    res_mw$test_type == "mann_whitney")
chk("O.MW.02", "U vs wilcox.test()$statistic",
    abs(res_mw$U - as.numeric(ref_mw$statistic)) < 1e-10)
chk("O.MW.03", "p vs wilcox.test(correct=TRUE)$p.value con 4dp",
    abs(res_mw$p - round(ref_mw$p.value, 4)) < 1e-10)
chk("O.MW.04", "r_rb = 1 - 2*U/(n1*n2) con 3dp",
    abs(res_mw$r_rb - r_rb_ref) < 1e-10)
chk("O.MW.05", "descriptives group1 tiene median numerico",
    !is.null(res_mw$descriptives$group1$median) &&
    is.numeric(res_mw$descriptives$group1$median))
chk("O.MW.06", "compute_ttest fuerza Mann-Whitney con force_nonparametric=TRUE",
    compute_ttest(x1_mw, x2_mw, force_nonparametric = TRUE)$test_type == "mann_whitney")

# -----------------------------------------------------------------------
# SECCION P — DISCRIMINANTE (15 tests)
# -----------------------------------------------------------------------
cat("\n=== SECCION P — DISCRIMINANTE ===\n\n")

set.seed(42)
grupo_disc <- rep(c("A", "B", "C"), each = 30)
x1_disc <- c(rnorm(30,2,0.8), rnorm(30,4,0.8), rnorm(30,6,0.8))
x2_disc <- c(rnorm(30,3,1.0), rnorm(30,5,1.0), rnorm(30,7,1.0))
df_disc  <- data.frame(x1 = x1_disc, x2 = x2_disc, grupo = grupo_disc, stringsAsFactors = FALSE)

res_disc <- run_discriminant(df_disc, c("x1","x2"), "grupo")

lda_ref  <- MASS::lda(grupo ~ x1 + x2, data = df_disc)
eig_ref  <- lda_ref$svd^2
wilks_u  <- 1/prod(1 + eig_ref)
k_d <- 2L; g_d <- 3L; n_d <- nrow(df_disc)
chi2_ref_d <- round(-(n_d - 1 - (k_d + g_d)/2) * log(wilks_u), 3)
p_ref_d    <- round(pchisq(chi2_ref_d, df = k_d*(g_d-1), lower.tail = FALSE), 4)

chk("P.DISC.01", "run_discriminant no retorna $error",
    is.null(res_disc$error))
chk("P.DISC.02", "n = complete.cases del data.frame",
    res_disc$n == sum(complete.cases(df_disc)))
chk("P.DISC.03", "precision en (0, 100]",
    is.numeric(res_disc$precision) && res_disc$precision > 0 && res_disc$precision <= 100)
chk("P.DISC.04", "wilks_lambda = round(1/prod(1+eig), 4)",
    abs(res_disc$wilks_lambda - round(wilks_u, 4)) < 1e-10)
chk("P.DISC.05", "wilks_chi2 = -(n-1-(k+g)/2)*log(wilks) con 3dp",
    abs(res_disc$wilks_chi2 - chi2_ref_d) < 1e-10)
chk("P.DISC.06", "wilks_df = k*(g-1)",
    res_disc$wilks_df == k_d * (g_d - 1L))
chk("P.DISC.07", "wilks_p vs pchisq(chi2, df) con 4dp",
    abs(res_disc$wilks_p - p_ref_d) < 1e-10)
chk("P.DISC.08", "variance_explained suma ~100",
    abs(sum(res_disc$variance_explained) - 100) < 0.2)
chk("P.DISC.09", "n_functions = g-1 = 2 para 3 grupos",
    res_disc$n_functions == 2L)
chk("P.DISC.10", "coefficients tiene k=2 elementos (uno por predictor)",
    length(res_disc$coefficients) == 2L)
chk("P.DISC.11", "MASS NOT en search() tras run_discriminant (P1 fix)",
    !any(grepl("^MASS$", search())))
res_disc_cv <- run_discriminant(df_disc, c("x1","x2"), "grupo", cv = "yes")
chk("P.DISC.12", "cv='yes' activa cross_validation con precision_cv numerica",
    !is.null(res_disc_cv$cross_validation) &&
    is.numeric(res_disc_cv$cross_validation$precision_cv))
disc_src <- readLines(file.path(r_dir, "discriminant.R"))
chk("P.DISC.13", "library(MASS) eliminado de discriminant.R (P1 fix)",
    !any(grepl("^\\s*library\\(MASS\\)", disc_src)))
chk("P.DISC.14", "MASS::lda usado en discriminant.R (namespace-qualified)",
    any(grepl("MASS::lda", disc_src)))
chk("P.DISC.15", "cross_validation is NULL cuando cv='no'",
    is.null(res_disc$cross_validation))

# -----------------------------------------------------------------------
# SECCION Q — CLUSTER (11 tests)
# -----------------------------------------------------------------------
cat("\n=== SECCION Q — CLUSTER ===\n\n")

set.seed(42)
df_cl <- data.frame(
  v1 = c(rnorm(30,2,0.5), rnorm(30,5,0.5), rnorm(30,8,0.5)),
  v2 = c(rnorm(30,2,0.5), rnorm(30,5,0.5), rnorm(30,8,0.5))
)
res_cl <- run_cluster(df_cl, c("v1","v2"), n_clusters = 3, seed = 42)

set.seed(42)
km_ref <- kmeans(scale(df_cl), centers = 3, nstart = 25)

chk("Q.CLUST.01", "run_cluster no retorna $error",
    is.null(res_cl$error))
chk("Q.CLUST.02", "n = complete.cases del data.frame",
    res_cl$n == sum(complete.cases(df_cl)))
chk("Q.CLUST.03", "n_clusters = 3 (parametro)",
    res_cl$n_clusters == 3L)
chk("Q.CLUST.04", "within_ss = round(kmeans()$tot.withinss, 3)",
    abs(res_cl$within_ss - round(km_ref$tot.withinss, 3)) < 0.01)
chk("Q.CLUST.05", "between_ss = round(kmeans()$betweenss, 3)",
    abs(res_cl$between_ss - round(km_ref$betweenss, 3)) < 0.01)
chk("Q.CLUST.06", "silhouette en (-1, 1]",
    is.numeric(res_cl$silhouette) && res_cl$silhouette > -1 && res_cl$silhouette <= 1)
chk("Q.CLUST.07", "silhouette_interpret es string no vacio",
    is.character(res_cl$silhouette_interpret) && nchar(res_cl$silhouette_interpret) > 0)
chk("Q.CLUST.08", "suma de cluster sizes = n",
    sum(sapply(res_cl$clusters, function(cl) cl$n)) == res_cl$n)
chk("Q.CLUST.09", "cluster NOT en search() tras run_cluster (P1 fix)",
    !any(grepl("^cluster$", search())))
cl_src <- readLines(file.path(r_dir, "cluster.R"))
chk("Q.CLUST.10", "library(cluster) eliminado de cluster.R (P1 fix)",
    !any(grepl("^\\s*library\\(cluster\\)", cl_src)))
chk("Q.CLUST.11", "cluster::silhouette usado en cluster.R (namespace-qualified)",
    any(grepl("cluster::silhouette", cl_src)))

# -----------------------------------------------------------------------
# SECCION R — DESCRIPTIVOS (4 tests)
# -----------------------------------------------------------------------
cat("\n=== SECCION R — DESCRIPTIVOS ===\n\n")

set.seed(42)
df_desc <- data.frame(
  i1 = pmax(1, pmin(5, round(rnorm(80, 3.5, 0.9)))),
  i2 = pmax(1, pmin(5, round(rnorm(80, 3.2, 1.0)))),
  i3 = pmax(1, pmin(5, round(rnorm(80, 3.8, 0.8))))
)
res_desc <- run_descriptives_full(df_desc, c("i1","i2","i3"), "Test")
score_ref <- rowMeans(df_desc[, c("i1","i2","i3")])
n_ref <- sum(!is.na(score_ref)); m_ref <- mean(score_ref); s_ref <- sd(score_ref)
ci_lo_ref <- m_ref - qt(0.975, n_ref-1) * (s_ref/sqrt(n_ref))

chk("R.DESC.01", "run_descriptives_full no retorna $error",
    is.null(res_desc$error))
chk("R.DESC.02", "mean = round(rowMeans, 2)",
    abs(res_desc$mean - round(m_ref, 2)) < 1e-10)
chk("R.DESC.03", "ci_lower = m - qt(0.975,n-1)*se con 2dp",
    abs(res_desc$ci_lower - round(ci_lo_ref, 2)) < 1e-10)
chk("R.DESC.04", "item_stats tiene k=3 elementos",
    length(res_desc$item_stats) == 3L)

# -----------------------------------------------------------------------
# RESULTADO FINAL
# -----------------------------------------------------------------------
total <- pass_count + fail_count
cat(sprintf("\n=== RESULTADO FINAL ===\n"))
cat(sprintf("PASO O-R: %d PASS / %d FAIL / %d TOTAL\n", pass_count, fail_count, total))
if (fail_count == 0L) {
  cat("PASO O-R: COMPLETO — todos los tests pasaron.\n")
  quit(status = 0L)
} else {
  cat("PASO O-R: FALLO — ver tests [FAIL] arriba.\n")
  quit(status = 1L)
}
