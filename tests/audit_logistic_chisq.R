#!/usr/bin/env Rscript
# tests/audit_logistic_chisq.R
# FASE 3C — Sección K: logística binaria / L: multinomial / M: chi-cuadrado / N: contratos
#
# Grupos: K.BIN (20), L.MUL (12), M.CHI (16), N.CONTRACT (10)
# Total: 58 tests  (umbral mínimo: 45)
#
# Exit code: 0 = todos PASS, 1 = al menos un FAIL
# ===========================================================================

pass_c <- 0L; fail_c <- 0L

chk <- function(id, desc, cond) {
  label <- if (isTRUE(cond)) "PASS" else "FAIL"
  cat(sprintf("  [%s] %s: %s\n", label, id, desc))
  if (isTRUE(cond)) pass_c <<- pass_c + 1L else fail_c <<- fail_c + 1L
  invisible(isTRUE(cond))
}

`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && !is.na(a[1]) && a[1] != "") a else b

.script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    f <- sub("--file=", "", grep("--file=", commandArgs(trailingOnly=FALSE), value=TRUE))
    if (length(f) > 0) dirname(normalizePath(f)) else getwd()
  }
)
r_dir         <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "R")
run_anal_path <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "run_analysis.R")

source(file.path(r_dir, "helpers.R"))
source(file.path(r_dir, "logistic.R"))
source(file.path(r_dir, "logistic_multinomial.R"))
source(file.path(r_dir, "chi_square.R"))
source(file.path(r_dir, "ordinal_regression.R"))

cat("=== AUDIT FASE 3C — Sección K/L/M/N: logística / chi-cuadrado / contratos ===\n")
cat(sprintf("    R version: %s\n\n", R.version.string))

# ──────────────────────────────────────────────────────────────────────────────
# SECCION K — LOGÍSTICA BINARIA
# ──────────────────────────────────────────────────────────────────────────────
cat("=== SECCION K — LOGISTICA BINARIA ===\n\n")

set.seed(314)
n_bin  <- 120
X1_bin <- rnorm(n_bin, mean = 0, sd = 1)
X2_bin <- rnorm(n_bin, mean = 0, sd = 1)
logit  <- -0.5 + 1.2 * X1_bin + 0.6 * X2_bin
y_bin  <- rbinom(n_bin, 1, plogis(logit))
while (length(unique(y_bin)) < 2) y_bin <- rbinom(n_bin, 1, plogis(logit))

Xmat_bin <- data.frame(X1 = X1_bin, X2 = X2_bin)
res_bin  <- compute_logistic_binary(y_bin, Xmat_bin, var_names = c("X1", "X2"), alpha = 0.05)

# Referencia con glm()
df_glm    <- data.frame(y = y_bin, X1 = X1_bin, X2 = X2_bin)
m_full    <- glm(y ~ X1 + X2, data = df_glm, family = binomial)
m_null    <- glm(y ~ 1,       data = df_glm, family = binomial)
ll_null_r <- as.numeric(logLik(m_null))
ll_full_r <- as.numeric(logLik(m_full))
lr_ratio_r <- -2 * (ll_null_r - ll_full_r)
n_r        <- nrow(df_glm)
r2_cs_r   <- 1 - exp((2 / n_r) * (ll_null_r - ll_full_r))
r2_max_r  <- 1 - exp((2 / n_r) * ll_null_r)
r2_nag_r  <- r2_cs_r / r2_max_r
sm_r      <- summary(m_full)$coefficients

get_cf <- function(lst, term, field) {
  for (i in seq_along(lst)) if (identical(lst[[i]]$term, term)) return(lst[[i]][[field]])
  NA_real_
}

chk("K.BIN.01", "test_type = 'logistica_binaria'",
    identical(res_bin$test_type, "logistica_binaria"))

chk("K.BIN.02", "n = complete.cases(y, X)",
    isTRUE(res_bin$n == n_r))

chk("K.BIN.03", "ll_null vs logLik(glm(y~1)) con tolerancia 3dp",
    abs(res_bin$ll_null - round(ll_null_r, 3)) < 1e-10)

chk("K.BIN.04", "ll_full vs logLik(glm(y~X1+X2)) con tolerancia 3dp",
    abs(res_bin$ll_full - round(ll_full_r, 3)) < 1e-10)

chk("K.BIN.05", "ll_ratio = -2*(ll_null - ll_full) con tolerancia 3dp",
    abs(res_bin$ll_ratio - round(lr_ratio_r, 3)) < 1e-10)

chk("K.BIN.06", "p_lr vs pchisq(lr_ratio, df=2) con tolerancia 4dp",
    abs(res_bin$p_lr - round(pchisq(lr_ratio_r, df = 2, lower.tail = FALSE), 4)) < 1e-8)

chk("K.BIN.07", "r2_cox_snell = 1 - exp(2/n*(ll_null-ll_full)) con tolerancia 3dp",
    abs(res_bin$r2_cox_snell - round(r2_cs_r, 3)) < 1e-10)

chk("K.BIN.08", "r2_nagelkerke = r2_cox / r2_max con tolerancia 3dp",
    abs(res_bin$r2_nagelkerke - round(r2_nag_r, 3)) < 1e-10)

b_int_r <- coef(m_full)["(Intercept)"]
b_x1_r  <- coef(m_full)["X1"]
b_x2_r  <- coef(m_full)["X2"]
se_int_r <- sm_r["(Intercept)", "Std. Error"]

chk("K.BIN.09", "B intercept vs coef(glm()) con tolerancia 3dp",
    abs(get_cf(res_bin$coefficients, "(Intercept)", "B") - round(b_int_r, 3)) < 1e-10)

chk("K.BIN.10", "B slope X1 vs coef(glm()) con tolerancia 3dp",
    abs(get_cf(res_bin$coefficients, "X1", "B") - round(b_x1_r, 3)) < 1e-10)

chk("K.BIN.11", "OR = exp(B) para X2",
    {
      b_x2  <- get_cf(res_bin$coefficients, "X2", "B")
      or_x2 <- get_cf(res_bin$coefficients, "X2", "OR")
      abs(or_x2 - round(exp(b_x2_r), 3)) < 1e-10
    })

chk("K.BIN.12", "SE intercept vs summary(glm()) con tolerancia 3dp",
    abs(get_cf(res_bin$coefficients, "(Intercept)", "SE") - round(se_int_r, 3)) < 1e-10)

chk("K.BIN.13", "classification: accuracy = (TP+TN)/n con tolerancia 3dp",
    {
      ct  <- res_bin$classification
      acc <- (ct$tp + ct$tn) / n_r
      abs(ct$accuracy - round(acc, 3)) < 1e-10
    })

chk("K.BIN.14", "classification: sensitivity = TP/(TP+FN) con tolerancia 3dp",
    {
      ct   <- res_bin$classification
      sens <- if ((ct$tp + ct$fn) > 0) ct$tp / (ct$tp + ct$fn) else NA
      isTRUE(!is.na(sens) && abs(ct$sensitivity - round(sens, 3)) < 1e-10)
    })

chk("K.BIN.15", "AUC en (0, 1]",
    isTRUE(is.numeric(res_bin$roc$auc) && res_bin$roc$auc > 0 && res_bin$roc$auc <= 1))

chk("K.BIN.16", "guard VD_NO_BINARIA: blocked=TRUE, reason=VD_NO_BINARIA",
    {
      y_cont   <- rnorm(50)
      X_guard  <- data.frame(X1 = rnorm(50))
      res_guard <- compute_logistic_binary(y_cont, X_guard, var_names = "X1")
      isTRUE(res_guard$blocked) && isTRUE(res_guard$reason == "VD_NO_BINARIA")
    })

chk("K.BIN.17", "vif = NULL para k=1 (un predictor)",
    {
      res_k1 <- compute_logistic_binary(y_bin, data.frame(X1 = X1_bin), var_names = "X1")
      is.null(res_k1$vif)
    })

chk("K.BIN.18", "VIF > 1 para predictores correlacionados",
    {
      X2_cor  <- X1_bin + rnorm(n_bin, 0, 0.3)
      y_vif   <- rbinom(n_bin, 1, plogis(-0.5 + X1_bin))
      res_vif <- compute_logistic_binary(y_vif, data.frame(X1 = X1_bin, X2 = X2_cor),
                                          var_names = c("X1", "X2"))
      !is.null(res_vif$vif) && length(res_vif$vif) > 0 &&
        isTRUE(res_vif$vif[[1]]$vif > 1)
    })

chk("K.BIN.19", "hosmer_lemeshow tiene chi2 y p numericos",
    isTRUE(is.numeric(res_bin$hosmer_lemeshow$chi2) &&
           is.numeric(res_bin$hosmer_lemeshow$p)))

chk("K.BIN.20", "roc$curve tiene al menos 2 puntos (fpr, tpr)",
    isTRUE(length(res_bin$roc$curve) >= 2 &&
           !is.null(res_bin$roc$curve[[1]]$fpr) &&
           !is.null(res_bin$roc$curve[[1]]$tpr)))

# ──────────────────────────────────────────────────────────────────────────────
# SECCION L — LOGÍSTICA MULTINOMIAL
# ──────────────────────────────────────────────────────────────────────────────
cat("\n=== SECCION L — LOGISTICA MULTINOMIAL ===\n\n")

set.seed(271)
n_mul  <- 150
X_mul  <- rnorm(n_mul)
logit2 <- 0.8 * X_mul
logit3 <- -0.5 + 1.5 * X_mul
probs  <- cbind(1, exp(logit2), exp(logit3))
probs  <- probs / rowSums(probs)
y_mul  <- apply(probs, 1, function(p) sample(c("A", "B", "C"), 1, prob = p))

Xmat_mul <- data.frame(X = X_mul)
res_mul  <- compute_logistic_multinomial(y_mul, Xmat_mul, var_names = "X")

mul_ok <- is.null(res_mul$error)
if (!mul_ok) cat(sprintf("  NOTE: compute_logistic_multinomial retorno error: %s\n", res_mul$error))

# Referencia con nnet (namespace-qualified)
requireNamespace("nnet", quietly = TRUE)
df_mul_r <- data.frame(y = factor(y_mul), X = X_mul)
m_mul_f  <- nnet::multinom(y ~ X, data = df_mul_r, trace = FALSE)
m_mul_n  <- nnet::multinom(y ~ 1, data = df_mul_r, trace = FALSE)
ll_mul_f <- as.numeric(logLik(m_mul_f))
ll_mul_n <- as.numeric(logLik(m_mul_n))
lr_mul   <- -2 * (ll_mul_n - ll_mul_f)
df_lr_mul <- attr(logLik(m_mul_f), "df") - attr(logLik(m_mul_n), "df")
p_lr_mul  <- pchisq(lr_mul, df = df_lr_mul, lower.tail = FALSE)
r2_cs_mul  <- 1 - exp((2 / n_mul) * (ll_mul_n - ll_mul_f))
r2_max_mul <- 1 - exp((2 / n_mul) * ll_mul_n)
r2_nag_mul <- r2_cs_mul / r2_max_mul
sm_mul     <- summary(m_mul_f)

get_lvl_b <- function(lst, lvl, term) {
  for (cc in lst) if (cc$level == lvl) for (cf in cc$coefficients) if (cf$term == term) return(cf$B)
  NA_real_
}

chk("L.MUL.01", "test_type = 'logistica_multinomial'",
    mul_ok && identical(res_mul$test_type, "logistica_multinomial"))

chk("L.MUL.02", "n = complete.cases",
    mul_ok && isTRUE(res_mul$n == n_mul))

chk("L.MUL.03", "n_levels = 3 para VD de 3 categorias",
    mul_ok && isTRUE(res_mul$n_levels == 3))

chk("L.MUL.04", "lr_chi2 = -2*(ll_null - ll_full) con tolerancia 3dp",
    mul_ok && abs(res_mul$lr_chi2 - round(lr_mul, 3)) < 1e-10)

chk("L.MUL.05", "lr_p vs pchisq(lr_chi2, df=lr_df) con tolerancia 4dp",
    mul_ok && abs(res_mul$lr_p - round(p_lr_mul, 4)) < 1e-8)

chk("L.MUL.06", "r2_nagelkerke = r2_cox / r2_max con tolerancia 3dp",
    mul_ok && abs(res_mul$r2_nagelkerke - round(r2_nag_mul, 3)) < 1e-10)

b_b_ref <- sm_mul$coefficients["B", "X"]
chk("L.MUL.07", "B nivel B vs coef(multinom()) con tolerancia 3dp",
    mul_ok && {
      b_b_prod <- get_lvl_b(res_mul$comparisons, "B", "X")
      isTRUE(!is.na(b_b_prod) && abs(b_b_prod - round(b_b_ref, 3)) < 1e-10)
    })

chk("L.MUL.08", "reference_level = primer nivel del factor",
    mul_ok && isTRUE(res_mul$reference_level == levels(factor(y_mul))[1]))

chk("L.MUL.09", "precision es numerico en [0, 100]",
    mul_ok && isTRUE(is.numeric(res_mul$precision) &&
                     !is.na(res_mul$precision) &&
                     res_mul$precision >= 0 &&
                     res_mul$precision <= 100))

chk("L.MUL.10", "guard <3 niveles retorna campo $error",
    {
      y_bin2   <- c("A", "B")[rbinom(50, 1, 0.5) + 1]
      res_mul2 <- compute_logistic_multinomial(y_bin2, data.frame(X = rnorm(50)), var_names = "X")
      !is.null(res_mul2$error) && nchar(res_mul2$error) > 0
    })

chk("L.MUL.11", "nnet NO en search() despues de llamada (P1 fix requireNamespace)",
    !("package:nnet" %in% search()))

chk("L.MUL.12", "comparisons tiene n_levels-1 entradas",
    mul_ok && isTRUE(length(res_mul$comparisons) == res_mul$n_levels - 1))

# ──────────────────────────────────────────────────────────────────────────────
# SECCION M — CHI-CUADRADO
# ──────────────────────────────────────────────────────────────────────────────
cat("\n=== SECCION M — CHI-CUADRADO ===\n\n")

set.seed(159)
n_chi <- 100
var_a <- sample(c("M", "F"), n_chi, replace = TRUE, prob = c(0.5, 0.5))
var_b <- ifelse(var_a == "M",
                sample(c("A","B","C"), n_chi, replace=TRUE, prob=c(0.6,0.3,0.1)),
                sample(c("A","B","C"), n_chi, replace=TRUE, prob=c(0.2,0.4,0.4)))

res_chi <- compute_chisquare(var_a, var_b, alpha = 0.05, yates = "never")

tab_r   <- table(var_a, var_b)
chi_r   <- chisq.test(tab_r, correct = FALSE)
n_chi_r <- sum(tab_r)
df_min_r <- min(nrow(tab_r) - 1, ncol(tab_r) - 1)
v_cr_r  <- sqrt(chi_r$statistic / (n_chi_r * df_min_r))
exp_r   <- outer(rowSums(tab_r), colSums(tab_r)) / n_chi_r

chk("M.CHI.01", "test_type = 'chi_cuadrado'",
    identical(res_chi$test_type, "chi_cuadrado"))

chk("M.CHI.02", "n = casos validos",
    isTRUE(res_chi$n == n_chi_r))

chk("M.CHI.03", "chi2 vs chisq.test()$statistic sin Yates con tolerancia 3dp",
    abs(res_chi$chi2 - round(chi_r$statistic, 3)) < 1e-10)

chk("M.CHI.04", "df = (r-1)*(c-1)",
    isTRUE(res_chi$df == as.integer(chi_r$parameter)))

chk("M.CHI.05", "p vs chisq.test()$p.value con tolerancia 4dp",
    abs(res_chi$p - round(chi_r$p.value, 4)) < 1e-8)

chk("M.CHI.06", "v_cramer = sqrt(chi2/(n*df_min)) con tolerancia 3dp",
    abs(res_chi$v_cramer - round(v_cr_r, 3)) < 1e-10)

chk("M.CHI.07", "tabla 2x3: r=2, c=3",
    isTRUE(res_chi$r == 2 && res_chi$c == 3))

chk("M.CHI.08", "contingency_table tiene r*c = 6 entradas",
    isTRUE(length(res_chi$contingency_table) == 6))

chk("M.CHI.09", "expected en primera celda vs outer(rowSums,colSums)/n con tolerancia 2dp",
    {
      cell1 <- res_chi$contingency_table[[1]]
      r_nm  <- cell1$row
      c_nm  <- cell1$col
      exp_v <- if (r_nm %in% rownames(exp_r) && c_nm %in% colnames(exp_r))
                  exp_r[r_nm, c_nm]
                else NA
      isTRUE(!is.na(exp_v) && abs(cell1$expected - round(exp_v, 2)) < 1e-10)
    })

chk("M.CHI.10", "residual = (obs-exp)/sqrt(exp) para primera celda con tolerancia 3dp",
    {
      cell1  <- res_chi$contingency_table[[1]]
      res_v  <- (cell1$observed - cell1$expected) / sqrt(cell1$expected)
      abs(cell1$residual - round(res_v, 3)) < 1e-10
    })

# Tabla 2x2 con Yates
set.seed(200)
var_a2   <- sample(c("M","F"), 60, replace = TRUE)
var_b2   <- sample(c("Si","No"), 60, replace = TRUE)
res_chi2 <- compute_chisquare(var_a2, var_b2, yates = "auto")
tab2     <- table(var_a2, var_b2)
chi_y2   <- chisq.test(tab2, correct = TRUE)
chi_p2   <- chisq.test(tab2, correct = FALSE)
fish2    <- fisher.test(tab2)
phi_r2   <- sqrt(chi_p2$statistic / sum(tab2))

chk("M.CHI.11", "yates_applied=TRUE para tabla 2x2 con yates='auto'",
    isTRUE(res_chi2$yates_applied))

chk("M.CHI.12", "chi2_yates vs chisq.test(correct=TRUE)$statistic con tolerancia 3dp",
    isTRUE(!is.null(res_chi2$chi2_yates) &&
           abs(res_chi2$chi2_yates - round(chi_y2$statistic, 3)) < 1e-10))

chk("M.CHI.13", "p_yates vs chisq.test(correct=TRUE)$p.value con tolerancia 4dp",
    isTRUE(!is.null(res_chi2$p_yates) &&
           abs(res_chi2$p_yates - round(chi_y2$p.value, 4)) < 1e-8))

chk("M.CHI.14", "p_fisher vs fisher.test()$p.value para tabla 2x2 con tolerancia 4dp",
    isTRUE(!is.null(res_chi2$p_fisher) &&
           abs(res_chi2$p_fisher - round(fish2$p.value, 4)) < 1e-8))

chk("M.CHI.15", "phi = sqrt(chi2_pearson/n) para 2x2 con tolerancia 3dp",
    abs(res_chi2$phi - round(phi_r2, 3)) < 1e-10)

chk("M.CHI.16", "guard n<10 retorna campo $error",
    {
      res_small <- compute_chisquare(c("M","F"), c("A","B"), alpha = 0.05)
      !is.null(res_small$error) && nchar(res_small$error) > 0
    })

chk("M.CHI.17", "assumption_ok es logico",
    isTRUE(is.logical(res_chi$assumption_ok)))

chk("M.CHI.18", "significant es logico",
    isTRUE(is.logical(res_chi$significant)))

# ──────────────────────────────────────────────────────────────────────────────
# SECCION N — CONTRATOS P1/P2
# ──────────────────────────────────────────────────────────────────────────────
cat("\n=== SECCION N — CONTRATOS ===\n\n")

ord_src <- readLines(file.path(r_dir, "ordinal_regression.R"))
mul_src <- readLines(file.path(r_dir, "logistic_multinomial.R"))

chk("N.CONTRACT.01", "library(MASS) eliminado de ordinal_regression.R (P1 fix)",
    !any(grepl("^\\s*library\\s*\\(\\s*MASS\\s*\\)", ord_src)))

chk("N.CONTRACT.02", "library(nnet) eliminado de logistic_multinomial.R (P1 fix)",
    !any(grepl("^\\s*library\\s*\\(\\s*nnet\\s*\\)", mul_src)))

chk("N.CONTRACT.03", "install.packages eliminado de ordinal_regression.R",
    !any(grepl("install\\.packages", ord_src)))

chk("N.CONTRACT.04", "install.packages eliminado de logistic_multinomial.R",
    !any(grepl("install\\.packages", mul_src)))

chk("N.CONTRACT.05", "MASS::polr usado en ordinal_regression.R (namespace-qualified)",
    any(grepl("MASS::polr", ord_src)))

chk("N.CONTRACT.06", "nnet::multinom usado en logistic_multinomial.R (namespace-qualified)",
    any(grepl("nnet::multinom", mul_src)))

# MASS NO en search() despues de run_ordinal_regression
set.seed(42)
df_ord_n <- data.frame(
  X = rnorm(60),
  y = ordered(sample(1:3, 60, TRUE, prob = c(0.3, 0.4, 0.3)), levels = 1:3)
)
res_ord_n <- tryCatch(
  run_ordinal_regression(df_ord_n, "X", "y", "X", "y", ordered_levels = c(1, 2, 3)),
  error = function(e) list(error_outer = e$message)
)

chk("N.CONTRACT.07", "MASS NO en search() despues de run_ordinal_regression (P1 fix)",
    !("package:MASS" %in% search()))

chk("N.CONTRACT.08", "run_ordinal_regression con 3 cats no retorna blocked ni error",
    isTRUE(!isTRUE(res_ord_n$blocked) && is.null(res_ord_n$error)))

chk("N.CONTRACT.09", "nnet NO en search() despues de compute_logistic_multinomial",
    !("package:nnet" %in% search()))

# interpret_nagelkerke thresholds
chk("N.CONTRACT.10", "interpret_nagelkerke: umbrales 0.50/0.30/0.10 correctos",
    isTRUE(interpret_nagelkerke(0.55) == "grande") &&
    isTRUE(interpret_nagelkerke(0.35) == "mediano") &&
    isTRUE(interpret_nagelkerke(0.15) == "pequeno") &&
    isTRUE(interpret_nagelkerke(0.05) == "trivial"))

# ──────────────────────────────────────────────────────────────────────────────
# RESUMEN
# ──────────────────────────────────────────────────────────────────────────────
total <- pass_c + fail_c
cat(sprintf("\n=== RESULTADO FINAL ===\n"))
cat(sprintf("PASO K-N: %d PASS / %d FAIL / %d TOTAL\n", pass_c, fail_c, total))

if (fail_c == 0L) {
  cat("PASO K-N: COMPLETO — todos los tests pasaron.\n")
  quit(status = 0L)
} else {
  cat(sprintf("PASO K-N: FALLO — %d test(s) no pasaron.\n", fail_c))
  quit(status = 1L)
}
