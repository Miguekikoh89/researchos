# ResearchOS - Mediacion Simple (OLS/Bootstrap)
options(encoding="UTF-8")

run_mediation_simple <- function(df, x_var, m_var, y_var,
                                 n_boot=1000, seed=42, alpha=0.05) {
  tryCatch({
    for (v in c(x_var, m_var, y_var))
      if (!v %in% names(df)) stop(paste0("Variable '", v, "' no encontrada."))
    datos <- df[, c(x_var, m_var, y_var), drop=FALSE]
    datos <- as.data.frame(lapply(datos, as.numeric))
    datos <- datos[complete.cases(datos), ]
    n <- nrow(datos)
    if (n < 5) return(list(blocked=TRUE, reason="MUESTRA_INSUFICIENTE",
                            error=paste0("n=", n, ". Minimo n=5."), n=n))
    x <- datos[[x_var]]; m <- datos[[m_var]]; y <- datos[[y_var]]
    if (var(x, na.rm=TRUE) < 1e-10) return(list(blocked=TRUE, reason="PREDICTOR_CONSTANTE",
      error=paste0("El predictor '", x_var, "' es constante."), n=n))
    if (var(m, na.rm=TRUE) < 1e-10) return(list(blocked=TRUE, reason="MEDIADOR_CONSTANTE",
      error=paste0("El mediador '", m_var, "' es constante."), n=n))

    mod_m <- lm(m ~ x)
    mod_y <- lm(y ~ x + m)
    mod_c <- lm(y ~ x)
    a     <- coef(mod_m)[["x"]]
    b     <- coef(mod_y)[["m"]]
    c_tot <- coef(mod_c)[["x"]]
    c_dir <- coef(mod_y)[["x"]]
    se_a  <- summary(mod_m)$coefficients["x", "Std. Error"]
    se_b  <- summary(mod_y)$coefficients["m", "Std. Error"]
    ab    <- a * b
    se_sobel <- sqrt(a^2 * se_b^2 + b^2 * se_a^2)
    z_sobel  <- if (se_sobel > 0) ab / se_sobel else NA_real_
    p_sobel  <- if (!is.na(z_sobel)) 2 * pnorm(-abs(z_sobel)) else NA_real_

    set.seed(as.integer(seed))
    n_boot_req <- as.integer(n_boot)
    boot_ab <- numeric(n_boot_req)
    for (i in seq_len(n_boot_req)) {
      idx <- sample(n, n, replace=TRUE)
      xb <- x[idx]; mb <- m[idx]; yb <- y[idx]
      boot_ab[i] <- tryCatch({
        a_b <- coef(lm(mb ~ xb))[["xb"]]
        b_b <- coef(lm(yb ~ xb + mb))[["mb"]]
        a_b * b_b
      }, error=function(e) NA_real_)
    }
    boot_valid <- boot_ab[!is.na(boot_ab)]
    n_boot_valid <- length(boot_valid)
    ic_lo <- if (n_boot_valid > 10) quantile(boot_valid, alpha / 2,     names=FALSE) else NA_real_
    ic_hi <- if (n_boot_valid > 10) quantile(boot_valid, 1 - alpha / 2, names=FALSE) else NA_real_
    sig_ind <- !is.na(ic_lo) && !is.na(ic_hi) && (ic_lo > 0 || ic_hi < 0)
    var_c_dir <- vcov(mod_y)["x", "x"]
    sig_dir   <- !is.na(var_c_dir) && var_c_dir > 0 &&
                 abs(c_dir) / sqrt(var_c_dir) > qnorm(1 - alpha / 2)
    mediation_type <- if (!sig_ind) "sin mediacion"
      else if (!sig_dir) "mediacion completa"
      else if (sign(c_tot) == sign(ab)) "mediacion parcial complementaria"
      else "mediacion parcial competitiva"

    list(
      n                = n,
      x_var            = x_var,
      m_var            = m_var,
      y_var            = y_var,
      a                = round(a, 6),
      b                = round(b, 6),
      c_total          = round(c_tot, 6),
      c_direct         = round(c_dir, 6),
      indirect         = round(ab, 6),
      se_a             = round(se_a, 6),
      se_b             = round(se_b, 6),
      sobel_se         = round(se_sobel, 6),
      sobel_z          = round(z_sobel, 4),
      sobel_p          = round(p_sobel, 4),
      ci_lower         = round(ic_lo, 6),
      ci_upper         = round(ic_hi, 6),
      ic_method        = "bootstrap_percentil",
      n_boot_requested = n_boot_req,
      n_boot_valid     = n_boot_valid,
      seed_used        = as.integer(seed),
      alpha            = alpha,
      method           = "bootstrap",
      mediation_type   = mediation_type
    )
  }, error=function(e) list(error=e$message))
}

run_mediation_serial <- function(...) {
  list(blocked=TRUE, reason="NO_IMPLEMENTADO_SERIAL",
       error="La mediacion serial (X->M1->M2->Y) no esta implementada en esta version.")
}
