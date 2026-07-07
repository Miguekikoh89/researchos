#!/usr/bin/env Rscript
# tests/audit_anova_ancova.R
# FASE 3B — Sección I: ANOVA de un factor, Levene, post-hoc, ANCOVA
#
# Grupos: I.ANOVA (12), I.LEVENE (5), I.TUKEY (5), I.GH (5), I.ANCOVA (7), I.CONTRACT (5)
# Total: 39 tests  (umbral mínimo: 35)
#
# Exit code: 0 = todos PASS, 1 = al menos un FAIL
# ============================================================

pass <- 0L; fail <- 0L

check <- function(id, desc, cond) {
  label <- if (isTRUE(cond)) "PASS" else "FAIL"
  cat(sprintf("  [%s] %s: %s\n", label, id, desc))
  if (isTRUE(cond)) pass <<- pass + 1L else fail <<- fail + 1L
  invisible(isTRUE(cond))
}

.script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    f <- sub("--file=", "", grep("--file=", commandArgs(trailingOnly=FALSE), value=TRUE))
    if (length(f) > 0) dirname(normalizePath(f)) else getwd()
  }
)
r_dir        <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "R")
run_anal_path <- file.path(.script_dir, "..", "apps", "api", "stats-engine-r", "run_analysis.R")

source(file.path(r_dir, "helpers.R"))
source(file.path(r_dir, "anova.R"))
source(file.path(r_dir, "ancova.R"))

cat("=== AUDIT FASE 3B — SECCIÓN I: ANOVA / LEVENE / POST-HOC / ANCOVA ===\n")
cat(sprintf("    R version: %s\n\n", R.version.string))

# ──────────────────────────────────────────────────────────────────────────────
# Datos compartidos: 3 grupos normales con diferencias claras
# ──────────────────────────────────────────────────────────────────────────────
set.seed(42)
n_g <- 30
y_anova <- c(rnorm(n_g, 10, 2), rnorm(n_g, 14, 2), rnorm(n_g, 10, 2))
g_anova  <- rep(c("A","B","C"), each=n_g)

ref_aov <- summary(aov(y_anova ~ as.factor(g_anova)))[[1]]
ref_F   <- ref_aov["as.factor(g_anova)","F value"]
ref_p   <- ref_aov["as.factor(g_anova)","Pr(>F)"]
ref_dfB <- ref_aov["as.factor(g_anova)","Df"]
ref_dfW <- ref_aov["Residuals","Df"]
ref_ssB <- ref_aov["as.factor(g_anova)","Sum Sq"]
ref_ssW <- ref_aov["Residuals","Sum Sq"]
N_total <- length(y_anova)

res_anova <- compute_anova(y_anova, g_anova, alpha=0.05, posthoc="tukey")

# ──────────────────────────────────────────────────────────────────────────────
# I.ANOVA — Cálculo ANOVA paramétrico
# ──────────────────────────────────────────────────────────────────────────────
cat("--- [I.ANOVA] ANOVA paramétrico ---\n")

check("I.ANOVA.01", "test_type == 'anova' para 3 grupos normales",
      identical(res_anova$test_type, "anova"))

check("I.ANOVA.02", "F statistic coincide con aov() redondeado a 4dp",
      abs(res_anova$F - round(ref_F, 4)) < 1e-12)

check("I.ANOVA.03", "p value coincide con aov() redondeado a 4dp",
      abs(res_anova$p - round(ref_p, 4)) < 1e-12)

check("I.ANOVA.04", "df_between = k-1 = 2",
      res_anova$df_between == 2)

check("I.ANOVA.05", "df_within = N-k = 87",
      res_anova$df_within == (N_total - 3))

check("I.ANOVA.06", "eta2 = ss_between / ss_total",
      abs(res_anova$eta2 - round(ref_ssB / (ref_ssB + ref_ssW), 3)) < 1e-12)

check("I.ANOVA.07", "omega2 >= 0 (clamping activo cuando negativo)",
      !is.null(res_anova$omega2) && !is.na(res_anova$omega2) && res_anova$omega2 >= 0)

check("I.ANOVA.08", "Kruskal-Wallis cuando force_nonparametric=TRUE",
      identical(compute_anova(y_anova, g_anova, force_nonparametric=TRUE)$test_type, "kruskal_wallis"))

check("I.ANOVA.09", "Error con menos de 2 grupos",
      !is.null(compute_anova(y_anova[g_anova=="A"], rep("A", n_g))$error))

check("I.ANOVA.10", "Error con muestra insuficiente (n < k*3)",
      !is.null(compute_anova(c(1,2,3,4,5), c("A","A","B","B","C"))$error))

check("I.ANOVA.11", "NA en y son filtrados correctamente",
      {
        y_na <- y_anova; y_na[c(1,31,61)] <- NA
        res_na <- compute_anova(y_na, g_anova)
        !is.null(res_na$F) && is.null(res_na$error)
      })

check("I.ANOVA.12", "significant=TRUE cuando p < 0.05 (grupos muy diferentes)",
      isTRUE(res_anova$significant))

# ──────────────────────────────────────────────────────────────────────────────
# I.LEVENE — Test de Levene basado en media (no Brown-Forsythe)
# ──────────────────────────────────────────────────────────────────────────────
cat("--- [I.LEVENE] Test de Levene (media-based) ---\n")

res_lev <- levene_anova(y_anova, g_anova)

check("I.LEVENE.01", "levene_anova() retorna F, df1, df2, p, equal_variances",
      all(c("F","df1","df2","p","equal_variances") %in% names(res_lev)))

# Cálculo manual (misma fórmula que la implementación)
g_f <- as.factor(g_anova); niv_f <- levels(g_f)
z_list_f <- lapply(niv_f, function(g) { xi <- y_anova[g_f==g]; abs(xi - mean(xi)) })
ns_f <- sapply(z_list_f, length); N_f <- sum(ns_f); k_f <- length(niv_f)
z_m_f <- sapply(z_list_f, mean); z_g_f <- mean(unlist(z_list_f))
ssB_f <- sum(ns_f * (z_m_f - z_g_f)^2)
ssW_f <- sum(sapply(z_list_f, function(z) sum((z - mean(z))^2)))
F_ref_lev <- (ssB_f/(k_f-1)) / (ssW_f/(N_f-k_f))

check("I.LEVENE.02", "F coincide con cálculo manual mean-based",
      abs(res_lev$F - round(F_ref_lev, 3)) < 1e-12)

check("I.LEVENE.03", "df1 = k-1 = 2",
      res_lev$df1 == 2)

check("I.LEVENE.04", "df2 = N-k = 87",
      res_lev$df2 == 87)

# Grupos con varianzas muy distintas: equal_variances=FALSE
set.seed(7)
y_uneq <- c(rnorm(30, 10, 1), rnorm(30, 10, 8))
g_uneq  <- rep(c("A","B"), each=30)
res_lev_uneq <- levene_anova(y_uneq, g_uneq)

check("I.LEVENE.05", "equal_variances=FALSE para grupos con varianzas muy distintas",
      isFALSE(res_lev_uneq$equal_variances))

# ──────────────────────────────────────────────────────────────────────────────
# I.TUKEY — Post-hoc Tukey HSD
# ──────────────────────────────────────────────────────────────────────────────
cat("--- [I.TUKEY] Post-hoc Tukey HSD ---\n")

res_tukey <- tukey_hsd(y_anova, g_anova)
ref_tk    <- TukeyHSD(aov(y_anova ~ as.factor(g_anova)))$`as.factor(g_anova)`

check("I.TUKEY.01", "tukey_hsd() retorna data.frame con columna 'comparison'",
      is.data.frame(res_tukey) && "comparison" %in% names(res_tukey))

check("I.TUKEY.02", "Número de comparaciones = k*(k-1)/2 = 3",
      nrow(res_tukey) == 3)

# Primer par (B-A por orden lexicográfico de TukeyHSD)
ba_row <- res_tukey[res_tukey$comparison == "B-A", ]
ref_ba_diff <- round(ref_tk["B-A","diff"], 3)
ref_ba_padj <- round(ref_tk["B-A","p adj"], 4)

check("I.TUKEY.03", "diff B-A coincide con TukeyHSD() redondeado a 3dp",
      nrow(ba_row) == 1 && abs(ba_row$diff - ref_ba_diff) < 1e-12)

check("I.TUKEY.04", "p_adj B-A coincide con TukeyHSD() redondeado a 4dp",
      nrow(ba_row) == 1 && abs(ba_row$p_adj - ref_ba_padj) < 1e-12)

check("I.TUKEY.05", "columna 'significant' es lógica",
      is.logical(res_tukey$significant))

# ──────────────────────────────────────────────────────────────────────────────
# I.GH — Post-hoc Games-Howell (híbrido Welch t + qtukey CI)
# ──────────────────────────────────────────────────────────────────────────────
cat("--- [I.GH] Post-hoc Games-Howell ---\n")

set.seed(99)
y_gh <- c(rnorm(20, 10, 1), rnorm(30, 14, 4), rnorm(25, 11, 2))
g_gh  <- c(rep("A",20), rep("B",30), rep("C",25))
res_gh <- games_howell(y_gh, g_gh)

check("I.GH.01", "games_howell() retorna data.frame con 3 comparaciones",
      is.data.frame(res_gh) && nrow(res_gh) == 3)

# Referencia manual para el par A-B
y_A <- y_gh[g_gh=="A"]; y_B <- y_gh[g_gh=="B"]
n_A <- length(y_A); n_B <- length(y_B)
v_A <- var(y_A); v_B <- var(y_B)
diff_AB <- mean(y_A) - mean(y_B)
se_AB   <- sqrt(v_A/n_A + v_B/n_B)
df_AB   <- (v_A/n_A + v_B/n_B)^2 / ((v_A/n_A)^2/(n_A-1) + (v_B/n_B)^2/(n_B-1))

check("I.GH.02", "diff A-B coincide con cálculo manual redondeado a 3dp",
      {
        ab <- res_gh[res_gh$comparison=="A - B",]
        nrow(ab) == 1 && abs(ab$diff - round(diff_AB, 3)) < 1e-12
      })

p_AB_ref <- round(2 * pt(abs(diff_AB/se_AB), df_AB, lower.tail=FALSE), 4)
check("I.GH.03", "p_adj via 2*pt() con df Welch-Satterthwaite (no ptukey para p-valor)",
      {
        ab <- res_gh[res_gh$comparison=="A - B",]
        nrow(ab) == 1 && abs(ab$p_adj - p_AB_ref) < 1e-12
      })

k_gh <- length(unique(g_gh))
q_crit_AB <- qtukey(0.95, k_gh, df_AB) / sqrt(2)
ci_lo_ref  <- round(diff_AB - q_crit_AB * se_AB, 3)
ci_hi_ref  <- round(diff_AB + q_crit_AB * se_AB, 3)
check("I.GH.04", "CI via qtukey()/sqrt(2) * se_diff",
      {
        ab <- res_gh[res_gh$comparison=="A - B",]
        nrow(ab) == 1 &&
          abs(ab$ci_lower - ci_lo_ref) < 1e-12 &&
          abs(ab$ci_upper - ci_hi_ref) < 1e-12
      })

check("I.GH.05", "ci_lower < diff < ci_upper para toda comparación",
      all(res_gh$ci_lower < res_gh$diff & res_gh$diff < res_gh$ci_upper))

# ──────────────────────────────────────────────────────────────────────────────
# I.ANCOVA — ANCOVA con medias ajustadas (requiere emmeans)
# ──────────────────────────────────────────────────────────────────────────────
cat("--- [I.ANCOVA] ANCOVA con emmeans ---\n")

has_emmeans <- requireNamespace("emmeans", quietly=TRUE)

if (!has_emmeans) {
  for (id in paste0("I.ANCOVA.0", 1:7)) {
    cat(sprintf("  [SKIP] %s: emmeans no disponible\n", id))
  }
} else {
  set.seed(42)
  n_anc     <- 90
  cov_score <- rnorm(n_anc)
  # Covariable con efecto fuerte (b=2) + efecto de grupo
  dep_score <- 5 + 2*cov_score + c(rep(0,30), rep(3,30), rep(1.5,30)) + rnorm(n_anc, 0, 0.5)
  df_anc <- data.frame(dep=dep_score, cov=cov_score, grupo=rep(c("A","B","C"), each=30),
                       stringsAsFactors=FALSE)

  pkgs_antes <- search()
  res_anc <- run_ancova(df_anc, dep_items="dep", group_var="grupo",
                        covariate_items="cov", dep_name="DV")
  pkgs_despues <- search()

  check("I.ANCOVA.01", "run_ancova() retorna adjusted_means (lista no vacía)",
        is.list(res_anc) && is.null(res_anc$error) && length(res_anc$adjusted_means) > 0)

  check("I.ANCOVA.02", "n coincide con complete.cases del data.frame",
        !is.null(res_anc$n) && res_anc$n == sum(complete.cases(df_anc[,c("dep","cov","grupo")])))

  # ANCOVA con covariable fuerte debe mejorar R2 vs ANOVA sin covariable
  check("I.ANCOVA.03", "r2_ancova >= r2_anova cuando covariable correlaciona con VD",
        !is.null(res_anc$r2_ancova) && !is.null(res_anc$r2_anova) &&
          res_anc$r2_ancova >= res_anc$r2_anova)

  check("I.ANCOVA.04", "r2_improvement = r2_ancova - r2_anova redondeado a 3dp",
        !is.null(res_anc$r2_improvement) &&
          abs(res_anc$r2_improvement - round(res_anc$r2_ancova - res_anc$r2_anova, 3)) < 1e-12)

  check("I.ANCOVA.05", "homogeneity_slopes tiene F y p",
        is.list(res_anc$homogeneity_slopes) &&
          all(c("F","p") %in% names(res_anc$homogeneity_slopes)))

  check("I.ANCOVA.06", "posthoc_adjusted_means no es NULL con 3 grupos",
        !is.null(res_anc$posthoc_adjusted_means) && length(res_anc$posthoc_adjusted_means) > 0)

  # Verificar que emmeans NO fue adjuntado al search path (sin library())
  nuevamente_adjuntado <- "package:emmeans" %in% setdiff(pkgs_despues, pkgs_antes)
  check("I.ANCOVA.07", "emmeans NO se adjunta al search path tras run_ancova() (sin library() interno)",
        !nuevamente_adjuntado)
}

# ──────────────────────────────────────────────────────────────────────────────
# I.CONTRACT — Contratos de routing y bloqueo
# ──────────────────────────────────────────────────────────────────────────────
cat("--- [I.CONTRACT] Contratos de routing ---\n")

# Verificar que el source de run_analysis.R contiene el guard SIN_VARIABLE_GRUPO
src_lines <- readLines(run_anal_path)
src_str   <- paste(src_lines, collapse="\n")

check("I.CONTRACT.01", "run_analysis.R contiene guard SIN_VARIABLE_GRUPO para ANOVA",
      grepl("SIN_VARIABLE_GRUPO", src_str))

check("I.CONTRACT.02", "run_analysis.R: bloque ANOVA tiene return(result) tras el guard",
      {
        anova_block_start <- which(grepl('analysis_category == "anova"', src_lines))[1]
        guard_line <- which(grepl("SIN_VARIABLE_GRUPO", src_lines))[1]
        ret_line   <- which(grepl("return\\(result\\)", src_lines) & seq_along(src_lines) > guard_line)[1]
        !is.na(anova_block_start) && !is.na(guard_line) && !is.na(ret_line) &&
          ret_line > guard_line && ret_line < (anova_block_start + 30)
      })

check("I.CONTRACT.03", "compute_anova() con 1 grupo retorna lista con $error",
      !is.null(compute_anova(rnorm(30), rep("A",30))$error))

check("I.CONTRACT.04", "compute_anova() con muestra muy pequeña retorna $error",
      !is.null(compute_anova(c(1,2,3,4), c("A","A","B","C"))$error))

# run_ancova() sin group_var en df retorna error (no cuelga ni cae silenciosamente)
df_sin_grupo <- data.frame(dep=rnorm(30), cov=rnorm(30))
res_sin_g <- run_ancova(df_sin_grupo, dep_items="dep", group_var="NOEXISTE",
                        covariate_items="cov", dep_name="dep")
check("I.CONTRACT.05", "run_ancova() con group_var ausente del df retorna $error",
      !is.null(res_sin_g$error))

# ──────────────────────────────────────────────────────────────────────────────
# Resumen final
# ──────────────────────────────────────────────────────────────────────────────
total <- pass + fail
cat(sprintf("\nRESULTADO SECCIÓN I: %d PASS / %d FAIL / %d TOTAL\n", pass, fail, total))

if (fail > 0) {
  cat("SECCIÓN I: FALLO — se detectaron tests fallidos.\n")
  quit(status = 1L)
}
cat("SECCIÓN I: COMPLETO — todos los tests pasaron.\n")
