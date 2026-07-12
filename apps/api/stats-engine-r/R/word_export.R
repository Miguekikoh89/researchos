# -*- coding: utf-8 -*-
options(encoding="UTF-8")
# ============================================================================
# ResearchOS ??? Word Export APA 7 Completo
# Correlacion, t-test, ANOVA, Regresion, Logistica, Chi-cuadrado
# ============================================================================
library(officer)
library(flextable)

# Decodificar caracteres UTF-8
decode_utf8 <- function(x) {
  if (is.null(x) || is.na(x)) return(x)
  x <- as.character(x)
  x <- gsub("<c3><b3>","\u00f3",x)
  x <- gsub("<c3><a1>","\u00e1",x)
  x <- gsub("<c3><a9>","\u00e9",x)
  x <- gsub("<c3><ad>","\u00ed",x)
  x <- gsub("<c3><ba>","\u00fa",x)
  x <- gsub("<c3><b1>","\u00f1",x)
  x <- gsub("<c3><93>","\u00d3",x)
  x <- gsub("<c3><81>","\u00c1",x)
  x
}


`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && !is.na(a[1])) a else b


as_numeric_scalar <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_real_)
  suppressWarnings(as.numeric(as.character(x)[1]))
}

format_apa_number <- function(x, digits = 3, leading_zero = FALSE) {
  value <- as_numeric_scalar(x)
  if (!is.finite(value)) return("-")
  out <- sprintf(paste0("%.", digits, "f"), value)
  if (!leading_zero && abs(value) < 1) {
    out <- sub("^(-?)0\\.", "\\1.", out)
  }
  out
}

format_apa_p <- function(x, include_equals = FALSE) {
  value <- as_numeric_scalar(x)
  if (!is.finite(value)) return("-")
  if (value < .001) return("< .001")
  out <- format_apa_number(value, digits = 3, leading_zero = FALSE)
  if (include_equals) paste0("= ", out) else out
}

format_apa_ci <- function(lower, upper, digits = 3) {
  paste0(
    "[", format_apa_number(lower, digits, leading_zero = FALSE),
    ", ", format_apa_number(upper, digits, leading_zero = FALSE), "]"
  )
}

format_baremo_table <- function(tbl_data) {
  df <- to_df(tbl_data)
  if (!all(c("nivel", "desde", "hasta") %in% names(df))) return(df)
  desde <- suppressWarnings(as.numeric(as.character(df$desde)))
  hasta <- suppressWarnings(as.numeric(as.character(df$hasta)))
  rango <- vapply(seq_len(nrow(df)), function(i) {
    izquierda <- format_apa_number(desde[i], 2, leading_zero = TRUE)
    derecha   <- format_apa_number(hasta[i], 2, leading_zero = TRUE)
    if (i == 1) {
      paste0(izquierda, " ≤ puntaje ≤ ", derecha)
    } else {
      paste0(izquierda, " < puntaje ≤ ", derecha)
    }
  }, character(1))
  data.frame(Nivel = as.character(df$nivel), Rango = rango, check.names = FALSE)
}

#' Sanea texto para evitar XML invalido en el Word (caracteres mal codificados,
#' bytes UTF-8 incompletos provenientes de la lectura del Excel original).
sanitize_text <- function(txt) {
  txt <- as.character(txt)
  txt <- enc2utf8(txt)
  # Reemplaza bytes invalidos/incompletos por el caracter de reemplazo Unicode,
  # evitando que XML quede con una etiqueta <w:t> truncada a mitad de caracter.
  txt <- iconv(txt, from = "UTF-8", to = "UTF-8", sub = "")
  # Elimina caracteres de control (excepto tab/newline) que tambien rompen el XML.
  txt <- gsub("[\x01-\x08\x0B\x0C\x0E-\x1F]", "", txt, perl = TRUE)
  txt
}

add_p <- function(doc, txt, bold=FALSE, italic=FALSE, keep_next=FALSE) {
  prop <- officer::fp_text(bold=bold, italic=italic, font.size=12, font.family="Arial")
  par_prop <- officer::fp_par(keep_with_next=keep_next)
  doc <- officer::body_add_fpar(
    doc,
    officer::fpar(officer::ftext(sanitize_text(txt), prop), fp_p=par_prop)
  )
  doc
}
add_heading     <- function(doc, txt) add_p(doc, txt, bold=TRUE, keep_next=TRUE)
add_table_num   <- function(doc, n)   add_p(doc, paste0("Tabla ", n), bold=TRUE, keep_next=TRUE)
add_table_title <- function(doc, txt) add_p(doc, txt, italic=TRUE, keep_next=TRUE)
add_note <- function(doc, txt) {
  note_prop <- officer::fp_text(font.size=10, font.family="Arial", italic=TRUE)
  body_prop <- officer::fp_text(font.size=10, font.family="Arial", italic=FALSE)
  doc <- officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext("Nota.", note_prop),
      officer::ftext(sanitize_text(paste0(" ", txt)), body_prop)
    )
  )
  doc
}
add_blank <- function(doc) officer::body_add_par(doc, "", style="Normal")

add_apa_table <- function(doc, value) {
  df <- to_df(value)
  ft <- flextable::flextable(df)
  ft <- flextable::theme_apa(ft)
  ft <- flextable::font(ft, fontname="Arial", part="all")
  ft <- flextable::fontsize(ft, size=if (ncol(df) >= 7) 9 else 10, part="all")
  ft <- flextable::bold(ft, bold=TRUE, part="header")
  ft <- flextable::align(ft, align="left", part="all")
  ft <- flextable::valign(ft, valign="center", part="all")
  ft <- flextable::padding(ft, padding=3, part="all")
  ft <- flextable::autofit(ft)
  ft <- flextable::set_table_properties(ft, layout="autofit", width=1)
  flextable::body_add_flextable(doc, value=ft)
}

to_df <- function(x) {
  if (is.data.frame(x)) return(x)
  as.data.frame(x, stringsAsFactors=FALSE)
}

# ?????? Seccion Confiabilidad ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
add_reliability_section <- function(doc, reliability, tbl_n) {
  if (length(reliability) == 0) return(list(doc=doc, tbl_n=tbl_n))
  doc <- add_heading(doc, "Análisis de confiabilidad")
  doc <- add_blank(doc)
  doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
  doc <- add_table_title(doc, "Estadísticos de confiabilidad de las escalas de medición")
  rel_df <- do.call(rbind, lapply(reliability, function(r) {
    data.frame(
      Variable       = as.character(r[["name"]] %||% ""),
      k              = as.character(r[["k"]] %||% ""),
      n              = as.character(r[["n"]] %||% ""),
      Alfa           = format_apa_number(r[["alpha"]], 3),
      IC95           = format_apa_ci(r[["ci_lower"]], r[["ci_upper"]], 3),
      Omega          = format_apa_number(r[["omega"]][["omega_t"]], 3),
      Interpretacion = as.character(r[["interpretation"]] %||% ""),
      stringsAsFactors=FALSE, check.names=FALSE)
  }))
  names(rel_df)[4] <- "α de Cronbach"
  names(rel_df)[5] <- "IC 95%"
  names(rel_df)[6] <- "ω de McDonald"
  names(rel_df)[7] <- "Interpretación"
  doc <- add_apa_table(doc, value=to_df(rel_df))
  doc <- add_blank(doc)
  doc <- add_note(doc, "α = alfa de Cronbach; ω = omega total de McDonald; k = número de ítems; IC = intervalo de confianza del 95%.")
  doc <- add_blank(doc)
  list(doc=doc, tbl_n=tbl_n)
}

# Sección Normalidad ?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
add_normality_section <- function(doc, normality, tbl_n) {
  if (is.null(normality) || nrow(normality) == 0) return(list(doc=doc, tbl_n=tbl_n))
  doc <- add_heading(doc, "Prueba de normalidad")
  doc <- add_blank(doc)
  doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
  doc <- add_table_title(doc, "Prueba de normalidad de las variables de estudio")
  n_rows <- nrow(normality)
  col_or_na <- function(nm) {
    v <- normality[[nm]]
    if (is.null(v) || length(v) != n_rows) rep(NA_real_, n_rows) else v
  }
  col_or_dash <- function(nm) {
    v <- normality[[nm]]
    if (is.null(v) || length(v) != n_rows) rep("-", n_rows) else as.character(v)
  }
  norm_df <- data.frame(
    Variable  = col_or_dash("variable"),
    n         = col_or_dash("n"),
    SW_W      = vapply(col_or_na("sw_statistic"), format_apa_number, character(1), digits=4, leading_zero=FALSE),
    p_SW      = vapply(col_or_na("sw_p"), format_apa_p, character(1), include_equals=FALSE),
    KS_D      = vapply(col_or_na("ks_statistic"), format_apa_number, character(1), digits=4, leading_zero=FALSE),
    p_KS      = vapply(col_or_na("ks_p"), format_apa_p, character(1), include_equals=FALSE),
    Decision  = sapply(col_or_dash("decision"), function(d) if(d=="Normal") "No se rechaza la normalidad" else if(d=="No normal") "Se rechaza la normalidad" else d),
    stringsAsFactors=FALSE, check.names=FALSE)
  names(norm_df) <- c("Variable","n","SW (W)","p (SW)","KS (D)","p (KS)","Decisión")
  doc <- add_apa_table(doc, value=to_df(norm_df))
  doc <- add_blank(doc)
  doc <- add_note(doc, "SW = Shapiro–Wilk; KS = Kolmogorov–Smirnov con corrección de Lilliefors. Un valor p < .05 indica una desviación estadísticamente significativa de la normalidad.")
  doc <- add_blank(doc)
  list(doc=doc, tbl_n=tbl_n)
}

# Sección t-test ?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
add_ttest_section <- function(doc, ttest, tbl_n) {
  if (is.null(ttest) || !is.null(ttest[["error"]])) return(list(doc=doc, tbl_n=tbl_n))
  doc <- add_heading(doc, "Comparacion de grupos")
  doc <- add_blank(doc)
  tt   <- ttest[["test_type"]] %||% ""
  met  <- ttest[["auto_selected"]] %||% tt
  desc <- ttest[["descriptives"]]
  g1   <- desc[["group1"]]; g2 <- desc[["group2"]]

  # Tabla descriptivos por grupo
  doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
  doc <- add_table_title(doc, "Estadisticos descriptivos por grupo")
  gdf <- data.frame(
    Grupo   = c(as.character(g1[["name"]] %||% "Grupo 1"), as.character(g2[["name"]] %||% "Grupo 2")),
    n       = c(as.character(g1[["n"]] %||% ""), as.character(g2[["n"]] %||% "")),
    M       = c(as.character(g1[["mean"]] %||% ""), as.character(g2[["mean"]] %||% "")),
    DE      = c(as.character(g1[["sd"]] %||% ""), as.character(g2[["sd"]] %||% "")),
    Mediana = c(as.character(g1[["median"]] %||% "-"), as.character(g2[["median"]] %||% "-")),
    stringsAsFactors=FALSE)
  names(gdf) <- c("Grupo","n","M","DE","Mediana")
  doc <- add_apa_table(doc, value=gdf)
  doc <- add_blank(doc)

  # Tabla resultado
  doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
  if (grepl("mann|whitney|wilcoxon", tolower(tt))) {
    doc <- add_table_title(doc, paste0("Resultado de la prueba ", met))
    U_or_W <- if(grepl("mann", tolower(tt))) ttest[["U"]] %||% "-" else ttest[["W"]] %||% "-"
    stat_name <- if(grepl("mann", tolower(tt))) "U" else "W"
    rdf <- data.frame(
      Estadistico = as.character(U_or_W),
      p           = as.character(ttest[["p_apa"]] %||% ""),
      r_rb        = as.character(ttest[["r_rb"]] %||% ""),
      Efecto      = as.character(ttest[["r_interpret"]] %||% ""),
      Decision    = as.character(ttest[["decision"]] %||% ""),
      stringsAsFactors=FALSE)
    names(rdf) <- c(stat_name, "p", "r rango biserial", "Magnitud efecto", "Decision")
    doc <- add_apa_table(doc, value=rdf)
    doc <- add_blank(doc)
    doc <- add_note(doc, paste0(stat_name, " = estadistico ", met, "; r = r de rango biserial (tamano del efecto)."))
    doc <- add_blank(doc)
    # Redaccion
    p_val <- as.character(ttest[["p_apa"]] %||% "")
    sig   <- ttest[["significant"]] %||% FALSE
    g1n   <- as.character(g1[["name"]] %||% "Grupo 1")
    g2n   <- as.character(g2[["name"]] %||% "Grupo 2")
    doc <- add_p(doc, paste0(
      "Los resultados de la prueba ", met, " indican que ",
      if(sig) "existen diferencias estadisticamente significativas" else "no existen diferencias estadisticamente significativas",
      " entre ", g1n, " (Mdn = ", g1[["median"]] %||% "-", ") y ", g2n,
      " (Mdn = ", g2[["median"]] %||% "-", "), ",
      stat_name, " = ", U_or_W, ", p ", p_val, ". ",
      if(sig) "Por tanto, se rechaza la hipotesis nula." else "Por tanto, no se rechaza la hipotesis nula."
    ))
  } else {
    doc <- add_table_title(doc, paste0("Resultado de la ", met))
    lev <- ttest[["levene"]]
    rdf <- data.frame(
      t        = as.character(ttest[["t"]] %||% ""),
      gl       = as.character(ttest[["df"]] %||% ""),
      p        = as.character(ttest[["p_apa"]] %||% ""),
      IC_inf   = as.character(ttest[["ci_lower"]] %||% ""),
      IC_sup   = as.character(ttest[["ci_upper"]] %||% ""),
      d_Cohen  = as.character(ttest[["d"]] %||% ""),
      Magnitud = as.character(ttest[["d_interpret"]] %||% ""),
      Decision = as.character(ttest[["decision"]] %||% ""),
      stringsAsFactors=FALSE)
    names(rdf) <- c("t","gl","p","IC 95% inf","IC 95% sup","d de Cohen","Magnitud","Decision")
    doc <- add_apa_table(doc, value=rdf)
    doc <- add_blank(doc)
    if (!is.null(lev)) {
      doc <- add_note(doc, paste0(
        "t = estadistico t; gl = grados de libertad; d = d de Cohen. ",
        "Prueba de Levene: F = ", lev[["F"]] %||% "-", ", p = ", lev[["p"]] %||% "-",
        " (varianzas ", if(lev[["equal_variances"]] %||% TRUE) "iguales" else "desiguales", ")."))
    }
    doc <- add_blank(doc)
    # Redaccion
    t_v  <- ttest[["t"]] %||% "-"
    df_v <- ttest[["df"]] %||% "-"
    p_v  <- ttest[["p_apa"]] %||% "-"
    d_v  <- ttest[["d"]] %||% "-"
    sig  <- ttest[["significant"]] %||% FALSE
    g1n  <- as.character(g1[["name"]] %||% "Grupo 1")
    g2n  <- as.character(g2[["name"]] %||% "Grupo 2")
    doc <- add_p(doc, paste0(
      "Los resultados de la ", met, " indican que ",
      if(sig) "existen diferencias estadisticamente significativas" else "no existen diferencias estadisticamente significativas",
      " entre ", g1n, " (M = ", g1[["mean"]] %||% "-", ", DE = ", g1[["sd"]] %||% "-", ") y ",
      g2n, " (M = ", g2[["mean"]] %||% "-", ", DE = ", g2[["sd"]] %||% "-", "), ",
      "t(", df_v, ") = ", t_v, ", p ", p_v, ", d = ", d_v, ". ",
      if(sig) "Por tanto, se rechaza la hipotesis nula." else "Por tanto, no se rechaza la hipotesis nula."
    ))
  }
  doc <- add_blank(doc)
  list(doc=doc, tbl_n=tbl_n)
}

# ?????? Seccion ANOVA ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
add_anova_section <- function(doc, anova, tbl_n, user_obj="", user_h1="") {
  if (is.null(anova) || !is.null(anova[["error"]])) return(list(doc=doc, tbl_n=tbl_n))
  doc <- add_heading(doc, "Analisis de varianza (ANOVA)")
  doc <- add_blank(doc)
  if (nchar(trimws(user_obj)) > 0) {
    doc <- add_p(doc, paste0("Objetivo: ", user_obj)); doc <- add_blank(doc)
  }
  if (nchar(trimws(user_h1)) > 0) {
    doc <- add_p(doc, paste0("Hipótesis (H1): ", user_h1)); doc <- add_blank(doc)
  }
  tt  <- anova[["test_type"]] %||% ""
  met <- anova[["auto_selected"]] %||% tt

  # Descriptivos por grupo
  descs <- anova[["descriptives"]]
  if (!is.null(descs) && length(descs) > 0) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Estadisticos descriptivos por grupo")
    desc_rows <- do.call(rbind, lapply(descs, function(g) data.frame(
      Grupo   = as.character(g[["group"]] %||% ""),
      n       = as.character(g[["n"]] %||% ""),
      M       = sprintf("%.3f", as.numeric(g[["mean"]] %||% NA)),
      DE      = sprintf("%.3f", as.numeric(g[["sd"]] %||% NA)),
      Mediana = if (!is.null(g[["median"]]) && !is.na(suppressWarnings(as.numeric(g[["median"]])))) sprintf("%.3f", as.numeric(g[["median"]])) else "-",
      stringsAsFactors=FALSE)))
    doc <- add_apa_table(doc, value=desc_rows)
    doc <- add_blank(doc)
  }

  # Tabla resultado
  doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
  if (tt == "kruskal_wallis") {
    doc <- add_table_title(doc, "Resultado de la prueba Kruskal-Wallis")
    rdf <- data.frame(H=as.character(anova[["H"]] %||% ""), gl=as.character(anova[["df"]] %||% ""),
      p=as.character(anova[["p_apa"]] %||% ""), epsilon2=as.character(anova[["epsilon2"]] %||% ""),
      Magnitud=as.character(anova[["epsilon2_interpret"]] %||% ""),
      Decision=as.character(anova[["decision"]] %||% ""), stringsAsFactors=FALSE)
    names(rdf) <- c("H","gl","p","epsilon cuadrado","Magnitud","Decision")
    doc <- add_apa_table(doc, value=rdf)
    doc <- add_blank(doc)
    doc <- add_note(doc, "H = estadistico Kruskal-Wallis; epsilon2 = tamano del efecto.")
  } else {
    welch_mode <- isTRUE(anova[["welch_mode"]])
    if (welch_mode) {
      doc <- add_table_title(doc, "Welch ANOVA (varianzas heterogeneas)")
      rdf <- data.frame(
        F_Welch  = sprintf("%.4f", as.numeric(anova[["F"]] %||% NA)),
        gl_num   = as.character(round(as.numeric(anova[["df_between"]] %||% NA), 0)),
        gl_den   = sprintf("%.2f", as.numeric(anova[["df_within"]] %||% NA)),
        p        = as.character(anova[["p_apa"]] %||% ""),
        omega2   = sprintf("%.3f", as.numeric(anova[["omega2_welch"]] %||% NA)),
        Magnitud = as.character(anova[["omega2_welch_interpret"]] %||% ""),
        Decision = as.character(anova[["decision"]] %||% ""),
        stringsAsFactors=FALSE)
      names(rdf) <- c("F Welch","gl num","gl den","p","omega cuadrado","Magnitud","Decision")
      doc <- add_apa_table(doc, value=rdf)
      doc <- add_blank(doc)
      doc <- add_note(doc, "Welch ANOVA corrige los gl cuando las varianzas son heterogeneas. omega2 segun Richardson (2011).")
    } else {
      doc <- add_table_title(doc, "Tabla ANOVA de un factor")
      rdf <- data.frame(
        Fuente  = c("Entre grupos","Dentro grupos","Total"),
        SC      = c(as.character(anova[["ss_between"]] %||% ""),as.character(anova[["ss_within"]] %||% ""),as.character(anova[["ss_total"]] %||% "")),
        gl      = c(as.character(anova[["df_between"]] %||% ""),as.character(anova[["df_within"]] %||% ""),as.character((anova[["df_between"]] %||% 0)+(anova[["df_within"]] %||% 0))),
        CM      = c(as.character(anova[["ms_between"]] %||% ""),as.character(anova[["ms_within"]] %||% ""),"-"),
        F_val   = c(as.character(anova[["F"]] %||% ""),"-","-"),
        p_val   = c(as.character(anova[["p_apa"]] %||% ""),"-","-"),
        eta2    = c(as.character(anova[["eta2"]] %||% ""),"-","-"),
        stringsAsFactors=FALSE)
      names(rdf) <- c("Fuente","SC","gl","CM","F","p","eta2")
      doc <- add_apa_table(doc, value=rdf)
      doc <- add_blank(doc)
      doc <- add_note(doc, "SC = suma de cuadrados; CM = cuadrado medio; F = estadistico F; eta2 = eta cuadrado.")
    }
  }
  doc <- add_blank(doc)

  # Post-hoc
  posthoc <- anova[["posthoc"]]
  if (!is.null(posthoc) && length(posthoc) > 0) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    pm <- anova[["posthoc_method"]] %||% "Post-hoc"
    doc <- add_table_title(doc, paste0("Comparaciones multiples - ", pm))
    if (tt == "kruskal_wallis") {
      fmt_p <- function(p) { pn <- suppressWarnings(as.numeric(p)); if(is.na(pn)) return(as.character(p)); if(pn<.001) return("< .001"); sub("^0\\.", ".", formatC(pn,digits=3,format="f")) }
      ph_rows <- do.call(rbind, lapply(posthoc, function(r) data.frame(
        Comparacion=as.character(r[["comparison"]] %||% ""), z=sprintf("%.3f", round(as.numeric(r[["z"]] %||% 0),3)),
        p_raw=fmt_p(r[["p_raw"]] %||% ""), p_bonf=fmt_p(r[["p_bonf"]] %||% ""),
        Sig=if(isTRUE(r[["significant"]]))"*" else "ns", stringsAsFactors=FALSE)))
      names(ph_rows) <- c("Comparacion","z","p sin ajuste","p (Bonferroni)","Sig.")
    } else {
      ph_rows <- do.call(rbind, lapply(seq_len(nrow(as.data.frame(posthoc))), function(i) {
        r <- posthoc[i,]; data.frame(
          Comparacion=as.character(r[["comparison"]] %||% ""), diff=as.character(r[["diff"]] %||% ""),
          IC_inf=as.character(r[["ci_lower"]] %||% ""), IC_sup=as.character(r[["ci_upper"]] %||% ""),
          p_adj=as.character(r[["p_adj_apa"]] %||% { pv <- suppressWarnings(as.numeric(r[["p_adj"]] %||% NA)); if(!is.na(pv) && pv < .001) "< .001" else if(!is.na(pv)) sub("^0\\.", ".", sprintf("%.3f", pv)) else "-" }),
          Sig=if(r[["significant"]] %||% FALSE)"*" else "ns", stringsAsFactors=FALSE)
      }))
      names(ph_rows) <- c("Comparacion","Diferencia","IC inf","IC sup","p ajustado","Sig.")
    }
    doc <- add_apa_table(doc, value=ph_rows)
    doc <- add_blank(doc)
    doc <- add_note(doc, paste0(pm, ". * p < .05; ns = no significativo."))
    doc <- add_blank(doc)
  }

  # Redaccion
  sig <- anova[["significant"]] %||% FALSE
  p_v <- anova[["p_apa"]] %||% "-"
  if (tt == "kruskal_wallis") {
    doc <- add_p(doc, paste0("La prueba Kruskal-Wallis indica que ",
      if(sig)"existen diferencias estadisticamente significativas" else "no existen diferencias estadisticamente significativas",
      " entre los grupos, H(", anova[["df"]] %||% "-", ") = ", anova[["H"]] %||% "-",
      ", p ", p_v, ", epsilon2 = ", anova[["epsilon2"]] %||% "-", " (",anova[["epsilon2_interpret"]] %||% "-","). ",
      if(sig)"Por tanto, se rechaza la hipotesis nula." else "Por tanto, no se rechaza la hipotesis nula."))
  } else {
    if (welch_mode) {
      doc <- add_p(doc, paste0("El analisis de varianza de Welch indica que ",
        if(sig)"existen diferencias estadisticamente significativas" else "no existen diferencias estadisticamente significativas",
        " entre los grupos, F(", round(as.numeric(anova[["df_between"]] %||% 0), 0), ", ",
        sprintf("%.2f", as.numeric(anova[["df_within"]] %||% 0)),
        ") = ", sprintf("%.4f", as.numeric(anova[["F"]] %||% 0)), ", p ", p_v,
        ", omega2 = ", anova[["omega2_welch"]] %||% "-", " (", anova[["omega2_welch_interpret"]] %||% "-", "). ",
        if(sig)"Por tanto, se rechaza la hipotesis nula." else "Por tanto, no se rechaza la hipotesis nula."))
    } else {
      doc <- add_p(doc, paste0("El analisis de varianza de un factor indica que ",
        if(sig)"existen diferencias estadisticamente significativas" else "no existen diferencias estadisticamente significativas",
        " entre los grupos, F(", anova[["df_between"]] %||% "-", ", ", anova[["df_within"]] %||% "-",
        ") = ", anova[["F"]] %||% "-", ", p ", p_v,
        ", eta2 = ", anova[["eta2"]] %||% "-", " (", anova[["eta2_interpret"]] %||% "-", "). ",
        if(sig)"Por tanto, se rechaza la hipotesis nula." else "Por tanto, no se rechaza la hipotesis nula."))
    }
  }
  doc <- add_blank(doc)
  # Prueba de Levene
  lev_anova <- anova[["levene"]]
  if (!is.null(lev_anova) && !is.null(lev_anova[["F"]])) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Prueba de homogeneidad de varianzas (Levene)")
    p_lev <- as.numeric(lev_anova[["p"]] %||% 1)
    lev_df <- data.frame(
      F_lev = sprintf("%.3f", as.numeric(lev_anova[["F"]] %||% NA)),
      p_lev = if(p_lev < .001) "< .001" else sub("^0\\.", ".", formatC(p_lev, digits=3, format="f")),
      Varianzas = if(isTRUE(lev_anova[["equal_variances"]])) "Iguales" else "Desiguales",
      stringsAsFactors=FALSE)
    names(lev_df) <- c("F Levene", "p", "Varianzas")
    doc <- add_apa_table(doc, value=lev_df)
    doc <- add_blank(doc)
    doc <- add_note(doc, "Levene: p < .05 indica varianzas desiguales entre grupos.")
    doc <- add_blank(doc)
  }
  list(doc=doc, tbl_n=tbl_n)
}

# ?????? Seccion Regresion Lineal ???????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
add_regression_section <- function(doc, regression, tbl_n) {
  if (is.null(regression) || !is.null(regression[["error"]])) return(list(doc=doc, tbl_n=tbl_n))
  tipo <- if((regression[["k"]] %||% 1) == 1) "simple" else "multiple"
  doc <- add_heading(doc, paste0("Regresion lineal ", tipo))
  doc <- add_blank(doc)

  # Tabla resumen del modelo
  doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
  doc <- add_table_title(doc, "Resumen del modelo de regresion")
  mdf <- data.frame(R=as.character(regression[["R"]] %||% ""),
    R2=as.character(regression[["R2"]] %||% ""),
    R2_adj=as.character(regression[["R2_adj"]] %||% ""),
    F_val=as.character(regression[["F"]] %||% ""),
    p=as.character(regression[["p_apa"]] %||% ""),
    SE=as.character(regression[["SE_est"]] %||% ""),
    Magnitud=as.character(regression[["R2_interpret"]] %||% ""),
    stringsAsFactors=FALSE)
  names(mdf) <- c("R","R cuadrado","R cuadrado ajustado","F","p","Error tipico","Magnitud")
  doc <- add_apa_table(doc, value=mdf)
  doc <- add_blank(doc)
  doc <- add_note(doc, "R = coeficiente de correlacion multiple; R2 = coeficiente de determinacion.")
  doc <- add_blank(doc)

  # Tabla coeficientes
  doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
  doc <- add_table_title(doc, "Coeficientes del modelo de regresion")
  coefs <- regression[["coefficients"]]
  if (!is.null(coefs) && length(coefs) > 0) {
    cdf <- do.call(rbind, lapply(coefs, function(c) data.frame(
      Variable=as.character(c[["term"]] %||% ""), B=as.character(c[["B"]] %||% ""),
      SE=as.character(c[["SE"]] %||% ""), Beta=as.character(c[["beta"]] %||% "-"),
      t=as.character(c[["t"]] %||% ""), p=as.character(c[["p_apa"]] %||% ""),
      IC_inf=as.character(c[["ci_lower"]] %||% ""), IC_sup=as.character(c[["ci_upper"]] %||% ""),
      Sig=if(c[["significant"]] %||% FALSE)"*" else "ns", stringsAsFactors=FALSE)))
    names(cdf) <- c("Variable","B","SE","beta","t","p","IC 95% inf","IC 95% sup","Sig.")
    doc <- add_apa_table(doc, value=cdf)
    doc <- add_blank(doc)
    doc <- add_note(doc, "B = coeficiente no estandarizado; beta = coeficiente estandarizado; SE = error tipico; IC = intervalo de confianza.")
    doc <- add_blank(doc)
  }

  # Supuestos
  asmp <- regression[["assumptions"]]
  if (!is.null(asmp)) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Verificacion de supuestos del modelo de regresion")
    sdf <- data.frame(
      Supuesto  = c("Normalidad residuos (SW)","Independencia (Durbin-Watson)","Homocedasticidad (Breusch-Pagan)","Outliers influyentes (Cook)","Especificacion (RESET)"),
      Resultado = c(paste0("W = ",asmp[["normality_residuals"]][["W"]] %||% "-",", p = ",asmp[["normality_residuals"]][["p"]] %||% "-"),
                    paste0("DW = ",asmp[["independence"]][["dw"]] %||% "-"),
                    paste0("p = ",asmp[["homoscedasticity"]][["p"]] %||% "-"),
                    paste0("n = ",asmp[["influential_cases"]][["n_outliers"]] %||% "< .001"),
                    paste0("p = ",asmp[["model_specification"]][["p"]] %||% "-")),
      Estado    = c(asmp[["normality_residuals"]][["interpretation"]] %||% "-",
                    asmp[["independence"]][["interpretation"]] %||% "-",
                    asmp[["homoscedasticity"]][["interpretation"]] %||% "-",
                    asmp[["influential_cases"]][["interpretation"]] %||% "-",
                    asmp[["model_specification"]][["interpretation"]] %||% "-"),
      stringsAsFactors=FALSE)
    doc <- add_apa_table(doc, value=sdf)
    doc <- add_blank(doc)
    doc <- add_note(doc, "SW = Shapiro-Wilk; DW = Durbin-Watson; Cook = distancia de Cook.")
    doc <- add_blank(doc)
  }

  # Redaccion
  r2  <- regression[["R2"]] %||% "-"
  f_v <- regression[["F"]] %||% "-"
  p_v <- regression[["p_apa"]] %||% "-"
  sig <- regression[["significant"]] %||% FALSE
  doc <- add_p(doc, paste0(
    "El modelo de regresion lineal ", tipo, if(sig)" resulto estadisticamente significativo" else " no resulto estadisticamente significativo",
    ", F = ", f_v, ", p ", p_v, ". El coeficiente de determinacion R2 = ", r2,
    " indica que el modelo explica el ", round(as.numeric(r2)*100, 1), "% de la varianza de la variable dependiente (",
    regression[["R2_interpret"]] %||% "-", "). ",
    if(sig)"Por tanto, se rechaza la hipotesis nula." else "Por tanto, no se rechaza la hipotesis nula."))
  doc <- add_blank(doc)
  list(doc=doc, tbl_n=tbl_n)
}

# ?????? Seccion Regresion Logistica ??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
add_logistic_section <- function(doc, logistic, tbl_n) {
  if (is.null(logistic) || !is.null(logistic[["error"]])) return(list(doc=doc, tbl_n=tbl_n))
  tipo <- if(logistic[["test_type"]] %||% "" == "logistica_ordinal") "ordinal" else "binaria"
  doc <- add_heading(doc, paste0("Regresion logistica ", tipo))
  doc <- add_blank(doc)

  # Resumen modelo
  doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
  doc <- add_table_title(doc, "Resumen del modelo de regresion logistica")
  mdf <- data.frame(
    n          = as.character(logistic[["n"]] %||% ""),
    LL_ratio   = as.character(logistic[["ll_ratio"]] %||% ""),
    p          = as.character(logistic[["p_apa"]] %||% ""),
    R2_Cox     = as.character(logistic[["r2_cox_snell"]] %||% ""),
    R2_Nagel   = as.character(logistic[["r2_nagelkerke"]] %||% ""),
    Magnitud   = as.character(logistic[["r2_interpret"]] %||% ""),
    Decision   = as.character(logistic[["decision"]] %||% ""),
    stringsAsFactors=FALSE)
  names(mdf) <- c("n","-2LL ratio","p","R2 Cox-Snell","R2 Nagelkerke","Magnitud","Decision")
  doc <- add_apa_table(doc, value=mdf)
  doc <- add_blank(doc)
  doc <- add_note(doc, "R2 Nagelkerke = pseudo R cuadrado; OR = odds ratio.")
  doc <- add_blank(doc)

  # Coeficientes
  coefs <- logistic[["coefficients"]]
  if (!is.null(coefs) && length(coefs) > 0) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Coeficientes del modelo logistico (Odds Ratio)")
    cdf <- do.call(rbind, lapply(coefs, function(c) data.frame(
      Variable=as.character(c[["term"]] %||% ""), B=as.character(c[["B"]] %||% ""),
      SE=as.character(c[["SE"]] %||% ""), Wald=as.character(c[["Wald"]] %||% ""),
      p=as.character(c[["p_apa"]] %||% ""), OR=as.character(c[["OR"]] %||% ""),
      IC_inf=as.character(c[["OR_ci_lower"]] %||% ""), IC_sup=as.character(c[["OR_ci_upper"]] %||% ""),
      Sig=if(c[["significant"]] %||% FALSE)"*" else "ns", stringsAsFactors=FALSE)))
    names(cdf) <- c("Variable","B","SE","Wald","p","OR","IC OR inf","IC OR sup","Sig.")
    doc <- add_apa_table(doc, value=cdf)
    doc <- add_blank(doc)
    doc <- add_note(doc, "OR = odds ratio; IC = intervalo de confianza 95%; Wald = estadistico de Wald.")
    doc <- add_blank(doc)
  }

  # Clasificacion
  cl <- logistic[["classification"]]
  if (!is.null(cl)) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Tabla de clasificacion del modelo")
    cldf <- data.frame(
      Indicador = c("Accuracy","Sensibilidad","Especificidad"),
      Valor     = c(paste0(cl[["overall_pct"]] %||% "-", "%"),
                    as.character(cl[["sensitivity"]] %||% "-"),
                    as.character(cl[["specificity"]] %||% "-")),
      stringsAsFactors=FALSE)
    doc <- add_apa_table(doc, value=cldf)
    doc <- add_blank(doc)
  }

  # Redaccion
  r2n <- logistic[["r2_nagelkerke"]] %||% "-"
  p_v <- logistic[["p_apa"]] %||% "-"
  sig <- logistic[["significant"]] %||% FALSE
  doc <- add_p(doc, paste0(
    "El modelo de regresion logistica ", tipo,
    if(sig)" resulto estadisticamente significativo" else " no resulto estadisticamente significativo",
    ", -2LL ratio = ", logistic[["ll_ratio"]] %||% "-", ", p ", p_v,
    ". El R2 de Nagelkerke = ", r2n, " indica un ajuste ",
    logistic[["r2_interpret"]] %||% "-", ". ",
    if(!is.null(cl)) paste0("La precision de clasificacion del modelo fue de ", cl[["overall_pct"]] %||% "-", "%. ") else "",
    if(sig)"Por tanto, se rechaza la hipotesis nula." else "Por tanto, no se rechaza la hipotesis nula."))
  doc <- add_blank(doc)
  list(doc=doc, tbl_n=tbl_n)
}

# ?????? Seccion Chi-cuadrado ???????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
add_chisquare_section <- function(doc, chi_sq, tbl_n) {
  if (is.null(chi_sq) || !is.null(chi_sq[["error"]])) return(list(doc=doc, tbl_n=tbl_n))
  doc <- add_heading(doc, "Prueba Chi-cuadrado")
  doc <- add_blank(doc)

  # Tabla de contingencia
  cells <- chi_sq[["contingency_table"]]
  rows  <- chi_sq[["row_names"]]
  cols  <- chi_sq[["col_names"]]
  if (!is.null(cells) && !is.null(rows) && !is.null(cols)) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Tabla de contingencia (frecuencias observadas y esperadas)")
    ct_mat <- matrix("", nrow=length(rows), ncol=length(cols)+1)
    rownames(ct_mat) <- rows; colnames(ct_mat) <- c("", cols)
    ct_mat[,1] <- rows
    for (cell in cells) {
      ri <- which(rows == cell[["row"]]); ci <- which(cols == cell[["col"]]) + 1
      if (length(ri)>0 && length(ci)>0)
        ct_mat[ri, ci] <- paste0(cell[["observed"]], " (", cell[["expected"]], ")")
    }
    ct_df <- as.data.frame(ct_mat, stringsAsFactors=FALSE)
    names(ct_df)[1] <- ""
    doc <- add_apa_table(doc, value=ct_df)
    doc <- add_blank(doc)
    doc <- add_note(doc, "Frecuencias observadas. Entre parentesis: frecuencias esperadas.")
    doc <- add_blank(doc)
  }

  # Tabla resultado
  doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
  doc <- add_table_title(doc, paste0("Resultado de la prueba ", chi_sq[["method_used"]] %||% "Chi-cuadrado"))
  rdf <- data.frame(
    chi2     = as.character(chi_sq[["chi2"]] %||% ""),
    gl       = as.character(chi_sq[["df"]] %||% ""),
    p        = as.character(chi_sq[["p_apa"]] %||% ""),
    V_Cramer = as.character(chi_sq[["v_cramer"]] %||% ""),
    Phi      = as.character(chi_sq[["phi"]] %||% ""),
    Magnitud = as.character(chi_sq[["v_interpret"]] %||% ""),
    Decision = as.character(chi_sq[["decision"]] %||% ""),
    stringsAsFactors=FALSE)
  names(rdf) <- c("chi2","gl","p","V de Cramer","Phi","Magnitud","Decision")
  doc <- add_apa_table(doc, value=rdf)
  doc <- add_blank(doc)
  doc <- add_note(doc, "chi2 = estadistico chi-cuadrado; V de Cramer = tamano del efecto; gl = grados de libertad.")
  doc <- add_blank(doc)

  # Redaccion
  chi2v <- chi_sq[["chi2"]] %||% "-"
  df_v  <- chi_sq[["df"]] %||% "-"
  p_v   <- chi_sq[["p_apa"]] %||% "-"
  v_v   <- chi_sq[["v_cramer"]] %||% "-"
  mag   <- chi_sq[["v_interpret"]] %||% "-"
  sig   <- chi_sq[["significant"]] %||% FALSE
  doc <- add_p(doc, paste0(
    "Los resultados de la prueba ", chi_sq[["method_used"]] %||% "Chi-cuadrado",
    " indican que ", if(sig)"existe asociacion estadisticamente significativa" else "no existe asociacion estadisticamente significativa",
    " entre las variables, chi2(", df_v, ") = ", chi2v, ", p ", p_v,
    ". La V de Cramer = ", v_v, " indica una magnitud de efecto ", mag, ". ",
    if(sig)"Por tanto, se rechaza la hipotesis nula." else "Por tanto, no se rechaza la hipotesis nula."))
  doc <- add_blank(doc)
  list(doc=doc, tbl_n=tbl_n)
}

# ?????? Funcion principal generate_word ???????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

# ?????? Seccion Validacion de Instrumentos ???????????????????????????????????????????????????????????????????????????????????????????????????????????????
add_instruments_section <- function(doc, instr, tbl_n) {
  if (is.null(instr)) return(list(doc=doc, tbl_n=tbl_n))
  doc <- add_heading(doc, "Validacion psicometrica del instrumento")
  doc <- add_blank(doc)

  # KMO
  if (!is.null(instr$kmo)) {
    doc <- add_heading(doc, "Analisis de adecuacion muestral (KMO)")
    doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "KMO y Prueba de esfericidad de Bartlett")
    kmo_df <- data.frame(
      Indice=c("KMO","Interpretacion","Chi-cuadrado Bartlett","gl","p"),
      Valor=c(as.character(instr$kmo$kmo_overall), as.character(instr$kmo$kmo_interpret),
              as.character(instr$kmo$bartlett_chi2), as.character(instr$kmo$bartlett_df),
              as.character(instr$kmo$bartlett_p_apa)),
      stringsAsFactors=FALSE)
    doc <- add_apa_table(doc, value=kmo_df)
    doc <- add_blank(doc)
    doc <- add_note(doc, "KMO >= .70 = aceptable para AFE; Bartlett p < .05 = factorizacion viable.")
    doc <- add_blank(doc)
    doc <- add_p(doc, paste0("El KMO = ", instr$kmo$kmo_overall, " (", instr$kmo$kmo_interpret,
      ") y la prueba de Bartlett resultaron significativos (p ", instr$kmo$bartlett_p_apa,
      "), confirmando la adecuacion de los datos para el analisis factorial."))
    doc <- add_blank(doc)
  }

  # Confiabilidad
  if (!is.null(instr$reliability) && length(instr$reliability) > 0) {
    doc <- add_heading(doc, "Analisis de confiabilidad")
    doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Estadisticos de confiabilidad por variable")
    rel_rows <- do.call(rbind, lapply(instr$reliability, function(r) {
      data.frame(Variable=as.character(r$name), k=as.character(r$k), n=as.character(r$n),
        Alpha=as.character(r$alpha), Omega=as.character(r$omega %||% "-"),
        IC=paste0("[",r$ci_lower,", ",r$ci_upper,"]"),
        Interpretacion =as.character(r$interpretation), stringsAsFactors=FALSE)
    }))
    names(rel_rows) <- c("Variable","k","n","Alfa de Cronbach","Omega","IC 95%","Interpretacion")
    doc <- add_apa_table(doc, value=rel_rows)
    doc <- add_blank(doc)
    doc <- add_note(doc, "k = numero de items; alfa = Alfa de Cronbach; omega = Omega de McDonald.")
    doc <- add_blank(doc)
  }

  # AFE
  if (!is.null(instr$afe) && is.null(instr$afe$error)) {
    doc <- add_heading(doc, paste0("Analisis Factorial Exploratorio (", instr$afe$n_factors, " factores)"))
    doc <- add_blank(doc)
    # Varianza explicada
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Varianza explicada por factor")
    var_df <- instr$afe$variance
    var_rows <- data.frame(Factor=as.character(var_df$factor), SS=as.character(var_df$ss_load),
      Pct=paste0(var_df$pct_var,"%"), Acum=paste0(var_df$cum_var,"%"), stringsAsFactors=FALSE)
    names(var_rows) <- c("Factor","SS Cargas","% Varianza","% Acumulado")
    doc <- add_apa_table(doc, value=var_rows)
    doc <- add_blank(doc)
    # Cargas factoriales
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, paste0("Cargas factoriales (rotacion ", instr$afe$rotation, ")"))

    n_f <- instr$afe$n_factors
    load_rows <- do.call(rbind, lapply(instr$afe$loadings, function(row) {
      base <- data.frame(Item=as.character(row$item), stringsAsFactors=FALSE)
      for(f in 1:n_f) base[[paste0("F",f)]] <- as.character(row[[paste0("F",f)]] %||% "-")
      base[["h2"]] <- as.character(row$h2)
      base
    }))
    names(load_rows)[ncol(load_rows)] <- "h2"
    doc <- add_apa_table(doc, value=load_rows)
    doc <- add_blank(doc)
    doc <- add_note(doc, "Cargas > .40 en negrita indican pertenencia al factor. h2 = comunalidad.")
    doc <- add_blank(doc)
  }

  # AFC
  if (!is.null(instr$afc) && is.null(instr$afc$error)) {
    doc <- add_heading(doc, "Analisis Factorial Confirmatorio (AFC)")
    doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, paste0("Indices de ajuste del modelo (estimador ", instr$afc$estimator, ")"))
    fit_rows <- do.call(rbind, lapply(instr$afc$fit_table, function(row) {
      data.frame(Indice=as.character(row$indice), Valor=as.character(row$valor),
        Criterio=as.character(row$criterio), Evaluacion=decode_utf8(as.character(row$eval)),
        stringsAsFactors=FALSE)
    }))
    names(fit_rows) <- c("Indice","Valor","Criterio","Evaluacion")
    doc <- add_apa_table(doc, value=fit_rows)
    doc <- add_blank(doc)
    doc <- add_note(doc, "CFI/TLI >= .95 = excelente; RMSEA <= .06 = excelente; SRMR <= .08 = excelente.")
    doc <- add_blank(doc)
    # Redaccion
    aj <- instr$afc$ajuste_global %||% "deficiente"
    doc <- add_p(doc, paste0("El modelo de medida presento un ajuste ",aj,
      ", CFI = ", instr$afc$cfi, ", TLI = ", instr$afc$tli,
      ", RMSEA = ", instr$afc$rmsea, " [IC90%: ", instr$afc$rmsea_lo, ", ", instr$afc$rmsea_hi, "]",
      ", SRMR = ", instr$afc$srmr, "."))
    doc <- add_blank(doc)
  }

  # HTMT
  if (!is.null(instr$htmt) && is.null(instr$htmt$error) && length(instr$htmt$pairs) > 0) {
    doc <- add_heading(doc, "Validez discriminante (HTMT)")
    doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, paste0("Indice HTMT con IC 95% bootstrapped (n = ", instr$htmt$n_boot, ")"))
    htmt_rows <- do.call(rbind, lapply(instr$htmt$pairs, function(p) {
      data.frame(Par=decode_utf8(as.character(p$par)), HTMT=as.character(p$htmt),
        IC_inf=as.character(p$ic_low), IC_sup=as.character(p$ic_high),
        Veredicto=as.character(p$verdict), stringsAsFactors=FALSE)
    }))
    names(htmt_rows) <- c("Par de constructos","HTMT","IC 95% inf","IC 95% sup","Veredicto")
    doc <- add_apa_table(doc, value=htmt_rows)
    doc <- add_blank(doc)
    doc <- add_note(doc, "HTMT < .85 indica validez discriminante adecuada (Henseler et al., 2015).")
    doc <- add_blank(doc)
  }

  list(doc=doc, tbl_n=tbl_n)
}

generate_word <- function(result, config, output_dir, tbl_start=1) {
  doc   <- officer::read_docx()
  tbl_n <- tbl_start

  partic     <- tryCatch(as.character(config[["participants"]]), error=function(e) "los participantes")
  var_a_name <- tryCatch(as.character(config[["var_a"]][["name"]]), error=function(e) "Variable A")
  var_b_name <- tryCatch(as.character(config[["var_b"]][["name"]]), error=function(e) "Variable B")
  method     <- tryCatch(as.character(result[["method"]]), error=function(e) "spearman")
  sym        <- if(method=="pearson") "r" else if(method=="kendall") "τb" else "ρ"
  met        <- if(method=="pearson") "r de Pearson" else if(method=="kendall") "τb de Kendall" else "ρ de Spearman"
  obj        <- tryCatch(as.character(config[["objective"]]), error=function(e) "")

  reliability  <- tryCatch(result[["reliability"]],  error=function(e) list())
  normality    <- tryCatch(as.data.frame(do.call(rbind, lapply(result[["normality"]], as.data.frame))), error=function(e) NULL)
  correlations <- tryCatch(as.data.frame(do.call(rbind, lapply(result[["correlations"]], as.data.frame))), error=function(e) data.frame())
  descriptives <- tryCatch(as.data.frame(do.call(rbind, lapply(result[["descriptives"]], as.data.frame))), error=function(e) NULL)
  baremo_a     <- tryCatch(result[["baremo_a"]], error=function(e) NULL)
  baremo_b     <- tryCatch(result[["baremo_b"]], error=function(e) NULL)
  ttest        <- tryCatch(result[["ttest"]],    error=function(e) NULL)
  anova_res    <- tryCatch(result[["anova"]],    error=function(e) NULL)
  regression   <- tryCatch(result[["regression"]], error=function(e) NULL)
  logistic     <- tryCatch(result[["logistic"]], error=function(e) NULL)
  chi_sq       <- tryCatch(result[["chi_square"]], error=function(e) NULL)

  # ?????? Confiabilidad
  res <- add_reliability_section(doc, reliability, tbl_n)
  doc <- res$doc; tbl_n <- res$tbl_n

  # ?????? Normalidad
  res <- add_normality_section(doc, normality, tbl_n)
  doc <- res$doc; tbl_n <- res$tbl_n

  # ?????? Correlacion (si aplica)
  if (!is.null(correlations) && nrow(correlations) > 0) {
    corr_g <- correlations[correlations[["type"]] == "general",, drop=FALSE]
    if (nrow(corr_g) > 0) {
      user_obj <- tryCatch(as.character(result[["objective"]]), error=function(e) "")
      user_h1  <- tryCatch(as.character(result[["hypothesis_h1"]]), error=function(e) "")
      if (nchar(trimws(user_obj)) > 0) obj <- user_obj
      if (nchar(trimws(obj)) == 0) obj <- paste0("Determinar la relación entre ", var_a_name, " y ", var_b_name, ".")
      doc <- add_heading(doc, "Objetivo general"); doc <- add_blank(doc)
      doc <- add_p(doc, obj); doc <- add_blank(doc)
      if (nchar(trimws(user_h1)) > 0) {
        doc <- add_p(doc, paste0("Hipótesis (H1): ", user_h1)); doc <- add_blank(doc)
      }
      # ── Tabla de supuestos (Punto 1) ─────────────────────────────────────
      asmp <- tryCatch(attr(corr_g, "assumptions_general"), error=function(e) NULL)
      if (!is.null(asmp) && !is.null(asmp[["supuestos_tabla"]]) && length(asmp[["supuestos_tabla"]]) > 0) {
        doc <- add_heading(doc, "Verificacion de supuestos del analisis correlacional")
        doc <- add_blank(doc)
        doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
        doc <- add_table_title(doc, "Verificacion de supuestos para el coeficiente de correlacion")
        st <- asmp[["supuestos_tabla"]]
        sup_names <- c(linealidad="Linealidad", homocedasticidad="Homocedasticidad",
                       outliers="Valores atipicos bivariados", influencia="Influencia")
        rows_sup <- lapply(names(sup_names), function(k) {
          s <- st[[k]]; if (is.null(s)) return(NULL)
          data.frame(Supuesto=sup_names[[k]], Procedimiento=as.character(s[["procedimiento"]]),
                     Resultado=as.character(s[["resultado"]]), Decision=as.character(s[["decision"]]),
                     stringsAsFactors=FALSE)
        })
        rows_sup <- Filter(Negate(is.null), rows_sup)
        if (length(rows_sup) > 0) {
          sup_df <- do.call(rbind, rows_sup)
          names(sup_df) <- c("Supuesto","Procedimiento","Resultado","Decision")
          doc <- add_apa_table(doc, value=to_df(sup_df))
          doc <- add_blank(doc)
          # Redaccion automatica de justificacion
          met_row <- tryCatch(as.character(corr_g[1,"method"]), error=function(e) "pearson")
          if (tolower(met_row) == "pearson") {
            lin_ok  <- !grepl("curvatura", tolower(as.character(st[["linealidad"]][["decision"]])))
            hom_ok  <- !grepl("detecto hetero", tolower(as.character(st[["homocedasticidad"]][["decision"]])))
            out_ok  <- grepl("razonablemente|0 caso", tolower(as.character(st[["outliers"]][["decision"]])))
            inf_ok  <- grepl("sin influencia|0 caso", tolower(as.character(st[["influencia"]][["decision"]])))
            doc <- add_p(doc, paste0(
              "Se verifico que la relacion entre ", var_a_name, " y ", var_b_name, " fuera aproximadamente lineal",
              if (lin_ok) " (no se detecto curvatura significativa)" else " (se detecto posible curvatura; interprete con precaucion)",
              ". ",
              if (hom_ok) "No se encontraron evidencias estadisticamente significativas de heterocedasticidad. " else "Se detecto heterocedasticidad; interprete Pearson con precaucion. ",
              if (out_ok && inf_ok) "No se identificaron observaciones extremadamente influyentes. " else "Se detectaron observaciones potencialmente influyentes; revise los datos. ",
              "En consecuencia, se considero adecuado emplear el coeficiente de correlacion de Pearson."
            ))
            doc <- add_blank(doc)
          }
        }
      }
      doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
      doc <- add_table_title(doc, paste0("Relación entre ", var_a_name, " y ", var_b_name))
      row <- corr_g[1,]
      r_val  <- tryCatch(as.numeric(as.character(row[["r_apa"]])), error=function(e) 0)
      n_val  <- tryCatch(as.integer(row[["n"]]), error=function(e) NA_integer_)
      gl_val <- if (!is.na(n_val)) as.character(n_val - 2L) else "-"
      r2_val <- if (!is.na(r_val) && is.finite(r_val)) sub("^0\\.", ".", sprintf("%.3f", r_val^2)) else "-"
      met_row <- tryCatch(as.character(row[["method"]]), error=function(e) "pearson")
      # P1+P2: gl y r² solo para Pearson; para Spearman/Kendall mostrar "-"
      es_pearson <- tolower(met_row) == "pearson"
      cdf <- data.frame(
        Variables = paste0(as.character(row[["var_a"]])," y ",as.character(row[["var_b"]])),
        n         = as.character(n_val),
        Coef      = row[["r_apa"]],
        gl        = if (es_pearson) gl_val else "-",
        p         = as.character(row[["p_apa"]]),
        IC        = if (!is.null(row[["ci_lower"]])) format_apa_ci(row[["ci_lower"]], row[["ci_upper"]], 3) else "-",
        r2        = if (es_pearson) r2_val else "-",
        Decision  = as.character(row[["decision"]]),
        stringsAsFactors=FALSE, check.names=FALSE)
      names(cdf)[3] <- met
      names(cdf)[7] <- if (es_pearson) "r\u00b2" else "-"
      names(cdf)[8] <- "Decisi\u00f3n"
      doc <- add_apa_table(doc, value=to_df(cdf))
      doc <- add_blank(doc)
      hip_type_txt <- tryCatch(as.character(result[["hypothesis_type"]] %||% "bilateral"), error=function(e) "bilateral")
      alfa_val <- tryCatch(as.numeric(result[["alpha"]] %||% 0.05), error=function(e) 0.05)
      prueba_txt <- switch(hip_type_txt, unilateral_pos="unilateral positiva", unilateral_neg="unilateral negativa", "bilateral")
      alfa_fmt <- sub("^0\\.", ".", sprintf("%.2f", alfa_val))
      note_txt <- paste0(sym, " = coeficiente ", met,
        if (es_pearson) "; gl = grados de libertad (n - 2); r2 = coeficiente de determinacion" else "",
        "; IC = intervalo de confianza del 95%.",
        " Se utilizo una prueba ", prueba_txt, " con nivel de significancia de alfa = ", alfa_fmt, ".")
      doc <- add_note(doc, note_txt)
      doc <- add_blank(doc)
      mag   <- if(abs(r_val)>=0.8)"muy alta" else if(abs(r_val)>=0.6)"alta" else if(abs(r_val)>=0.4)"moderada" else "baja"
      dir_r <- if(r_val>0)"positiva" else "negativa"
      sig_corr <- tryCatch(as.logical(row[["significant"]]), error=function(e) grepl("Se rechaza", as.character(row[["decision"]])))
      r2_pct <- if (es_pearson && !is.na(r_val) && is.finite(r_val)) sprintf("%.1f", r_val^2 * 100) else NULL
      # P3: redaccion con IC, r² y clausula de causalidad
      ic_txt <- if (!is.null(row[["ci_lower"]]) && !is.na(row[["ci_lower"]])) paste0(", IC 95% ", format_apa_ci(row[["ci_lower"]], row[["ci_upper"]], 3)) else ""
      gl_txt <- if (es_pearson && !is.na(n_val)) paste0("(", n_val - 2L, ")") else ""
      doc <- add_p(doc, paste0(
        "Los hallazgos muestran una relaci\u00f3n ", dir_r, ", ", mag, " y ",
        if (isTRUE(sig_corr)) "estad\u00edsticamente significativa" else "no estad\u00edsticamente significativa",
        " entre ", var_a_name, " y ", var_b_name, ", ", sym, gl_txt, " = ", row[["r_apa"]],
        ", p ", row[["p_apa"]], ic_txt,
        if (es_pearson && !is.null(r2_pct)) paste0(". El coeficiente de determinaci\u00f3n fue r\u00b2 = ", r2_val, ", lo que representa aproximadamente un ", r2_pct, "% de varianza compartida") else "",
        ". Este resultado no implica causalidad."
      ))
      doc <- add_blank(doc)
    }
  }

  # ?????? Descriptivos
  if (!is.null(descriptives) && nrow(descriptives) > 0) {
    doc <- add_heading(doc, "Estadística descriptiva"); doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Estadísticos descriptivos de las variables de estudio")
    # Mediana e IQR: usar si disponibles, si no calcular desde los datos
    get_col <- function(nm, digits=3, lz=TRUE) {
      v <- descriptives[[nm]]
      if (!is.null(v) && length(v) == length(descriptives[["variable"]]))
        vapply(v, format_apa_number, character(1), digits=digits, leading_zero=lz)
      else rep("-", length(descriptives[["variable"]]))
    }
    desc_df <- data.frame(
      Variable  = as.character(descriptives[["variable"]]),
      n         = as.character(descriptives[["n"]]),
      M         = get_col("mean",  2, TRUE),
      DE        = get_col("sd",    2, TRUE),
      Mediana   = get_col("median",3, TRUE),
      IQR       = get_col("iqr",   3, TRUE),
      Min       = get_col("min",   3, TRUE),
      Max       = get_col("max",   3, TRUE),
      Asimetria = get_col("skewness", 3, FALSE),
      Curtosis  = get_col("kurtosis", 3, FALSE),
      stringsAsFactors=FALSE)
    names(desc_df) <- c("Variable","n","M","DE","Mediana","IQR","Mín.","Máx.","Asimetría","Curtosis")
    doc <- add_apa_table(doc, value=to_df(desc_df))
    doc <- add_blank(doc)
    doc <- add_note(doc, "M = media; DE = desviación estándar; IQR = rango intercuartílico.")
    doc <- add_blank(doc)
  }

  # ?????? Baremos
  for (br_info in list(list(br=baremo_a,name=var_a_name), list(br=baremo_b,name=var_b_name))) {
    br <- br_info[["br"]]; nm <- br_info[["name"]]
    if (is.null(br)) next
    tbl_data <- br[["table"]]; if (is.null(tbl_data)) next
    doc <- add_heading(doc, paste0("Baremo de ", nm))
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, paste0("Baremo de la variable ", nm))
    br_df_raw <- if(is.data.frame(tbl_data)) to_df(tbl_data) else
      do.call(rbind.data.frame, lapply(tbl_data, function(r) as.data.frame(lapply(r,function(x)as.character(x[[1]])),stringsAsFactors=FALSE)))
    br_df <- format_baremo_table(br_df_raw)
    doc <- add_apa_table(doc, value=br_df)
    doc <- add_blank(doc)
    doc <- add_note(doc, "Los niveles fueron obtenidos mediante intervalos de igual amplitud: amplitud = (5 - 1) / 3 = 1.33. La categorizacion de puntuaciones continuas implica perdida de informacion; para los analisis inferenciales se utilizaron las puntuaciones originales.")
    freq_data <- br[["frequencies"]]
    if (!is.null(freq_data) && length(freq_data) > 0) {
      doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
      doc <- add_table_title(doc, paste0("Distribución de niveles de ", nm))
      freq_df <- if(is.data.frame(freq_data))
        data.frame(Nivel=as.character(freq_data[["nivel"]]),f=as.character(freq_data[["f"]]),Pct=paste0(sprintf("%.1f",as.numeric(freq_data[["pct"]])),"%"),Pct_ac=paste0(sprintf("%.1f",as.numeric(freq_data[["pct_ac"]])),"%"),stringsAsFactors=FALSE)
      else
        do.call(rbind.data.frame, lapply(freq_data,function(r) data.frame(Nivel=as.character(r[["nivel"]]),f=as.character(r[["f"]]),Pct=paste0(sprintf("%.1f",as.numeric(r[["pct"]])),"%"),Pct_ac=paste0(sprintf("%.1f",as.numeric(r[["pct_ac"]])),"%"),stringsAsFactors=FALSE)))
      names(freq_df) <- c("Nivel","f","%","% acumulado")
      doc <- add_apa_table(doc, value=freq_df)
      doc <- add_blank(doc)
      lvl <- tryCatch(decode_utf8(as.character(br[["levels_text"]])),error=function(e)"")
      if(length(lvl)>0 && nchar(trimws(lvl[1]))>0){doc<-add_p(doc,decode_utf8(lvl[1]));doc<-add_blank(doc)}
    }
  }

  # ?????? Analisis Descriptivo (combinado: descriptivos + baremo + distribucion)
  ad <- tryCatch(result[["analisis_descriptivo"]], error=function(e) NULL)
  if (!is.null(ad)) {
    ad_name <- tryCatch(as.character(ad[["var_name"]]), error=function(e) "Variable")
    doc <- add_heading(doc, paste0("Análisis descriptivo de ", ad_name)); doc <- add_blank(doc)

    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, paste0("Estadísticos descriptivos de ", ad_name))
    desc_ad_df <- data.frame(
      Variable=ad_name,
      n=as.character(ad[["n"]]), M=as.character(ad[["mean"]]), Mediana=as.character(ad[["median"]]),
      Moda=as.character(ad[["mode"]]), DE=as.character(ad[["sd"]]), Min=as.character(ad[["min"]]),
      Max=as.character(ad[["max"]]), Asimetria=as.character(ad[["skewness"]]), Curtosis=as.character(ad[["kurtosis"]]),
      stringsAsFactors=FALSE)
    doc <- add_apa_table(doc, value=desc_ad_df)
    doc <- add_blank(doc)
    doc <- add_note(doc, "M = media; DE = desviación estándar.")
    doc <- add_blank(doc)

    sw_p_ad <- tryCatch(as.numeric(ad[["sw_p"]]), error=function(e) NA)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, paste0("Prueba de normalidad de ", ad_name))
    norm_ad_df <- data.frame(
      Variable=ad_name, n=as.character(ad[["n"]]),
      SW=format_apa_number(ad[["sw_W"]], 4), p=format_apa_p(ad[["sw_p"]]),
      Decision=if(!is.na(sw_p_ad) && sw_p_ad > 0.05) "Normal" else "No normal",
      stringsAsFactors=FALSE)
    doc <- add_apa_table(doc, value=norm_ad_df)
    doc <- add_blank(doc)
    doc <- add_note(doc, "SW = Shapiro–Wilk. Un valor p < .05 indica una desviación estadísticamente significativa de la normalidad.")
    doc <- add_blank(doc)

    baremo_ad <- tryCatch(ad[["baremo"]], error=function(e) NULL)
    if (!is.null(baremo_ad) && length(baremo_ad) > 0) {
      doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
      doc <- add_table_title(doc, paste0("Baremo de la variable ", ad_name))
      baremo_ad_df_raw <- do.call(rbind.data.frame, lapply(baremo_ad, function(r) data.frame(
        nivel=as.character(r[["nivel"]]), desde=as.character(r[["desde"]]), hasta=as.character(r[["hasta"]]),
        stringsAsFactors=FALSE)))
      baremo_ad_df <- format_baremo_table(baremo_ad_df_raw)
      doc <- add_apa_table(doc, value=baremo_ad_df)
      doc <- add_blank(doc)
      txt_baremo_ad <- tryCatch(decode_utf8(as.character(ad[["texto_baremo"]])), error=function(e) "")
      if (length(txt_baremo_ad) > 0 && nchar(trimws(txt_baremo_ad[1])) > 0) {
        doc <- add_p(doc, decode_utf8(txt_baremo_ad[1])); doc <- add_blank(doc)
      }
    }

    dist_ad <- tryCatch(ad[["distribution"]], error=function(e) NULL)
    if (!is.null(dist_ad) && length(dist_ad) > 0) {
      doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
      doc <- add_table_title(doc, paste0("Distribución de niveles de ", ad_name))
      dist_ad_df <- do.call(rbind.data.frame, lapply(dist_ad, function(r) data.frame(
        Nivel=as.character(r[["nivel"]]), f=as.character(r[["f"]]),
        Pct=paste0(sprintf("%.1f",as.numeric(r[["pct"]])),"%"), Pct_ac=paste0(sprintf("%.1f",as.numeric(r[["pct_ac"]])),"%"),
        stringsAsFactors=FALSE)))
      names(dist_ad_df) <- c("Nivel","f","%","% acumulado")
      doc <- add_apa_table(doc, value=dist_ad_df)
      doc <- add_blank(doc)
      txt_niveles_ad <- tryCatch(decode_utf8(as.character(ad[["texto_niveles"]])), error=function(e) "")
      if (length(txt_niveles_ad) > 0 && nchar(trimws(txt_niveles_ad[1])) > 0) {
        doc <- add_p(doc, decode_utf8(txt_niveles_ad[1])); doc <- add_blank(doc)
      }
    }
  }
  # ====== Cronbach independiente ======
  cro <- tryCatch(result[["cronbach_only"]], error=function(e) NULL)
  if (!is.null(cro) && is.null(cro[["error"]])) {
    cro_name <- tryCatch(as.character(cro[["var_name"]]), error=function(e) "Variable")
    doc <- add_heading(doc, paste0("Confiabilidad de ", cro_name)); doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, paste0("Estadísticos de confiabilidad de ", cro_name))
    cro_df <- data.frame(
      Variable=cro_name, n=as.character(cro[["n"]]), k=as.character(cro[["k"]]),
      Alfa=format_apa_number(cro[["alpha"]], 3),
      IC95=format_apa_ci(cro[["ci_lower"]], cro[["ci_upper"]], 3),
      Omega=format_apa_number(cro[["omega"]], 3),
      Interpretacion=as.character(cro[["interpretation"]]), stringsAsFactors=FALSE, check.names=FALSE)
    names(cro_df) <- c("Variable","n","k","α de Cronbach","IC 95%","ω de McDonald","Interpretación")
    doc <- add_apa_table(doc, value=cro_df)
    doc <- add_blank(doc)
    doc <- add_note(doc, "Alfa >= .90 Excelente; >= .80 Bueno; >= .70 Aceptable; >= .60 Cuestionable; < .60 Inaceptable.")
    doc <- add_blank(doc)
    cro_items <- tryCatch(cro[["item_stats"]], error=function(e) NULL)
    if (!is.null(cro_items) && length(cro_items) > 0) {
      doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
      doc <- add_table_title(doc, paste0("Estadisticos de elemento-total de ", cro_name))
      cro_items_df <- do.call(rbind.data.frame, lapply(cro_items, function(it) data.frame(
        Item=as.character(it[["item"]]), M=as.character(it[["mean"]]), DE=as.character(it[["sd"]]),
        r_item_total=as.character(it[["r_item_total"]]), Alfa_si_elimina=as.character(it[["alpha_if_deleted"]]),
        Decision=as.character(it[["interpretation"]]), stringsAsFactors=FALSE)))
      names(cro_items_df) <- c("Item","M","DE","r item-total","Alfa si se elimina","Decision")
      doc <- add_apa_table(doc, value=cro_items_df)
      doc <- add_blank(doc)
    }
  }

  # ====== Cluster (K-means) ======
  clu <- tryCatch(result[["cluster"]], error=function(e) NULL)
  if (!is.null(clu) && is.null(clu[["error"]])) {
    clu_name <- tryCatch(as.character(clu[["var_name"]]), error=function(e) "Variable")
    doc <- add_heading(doc, paste0("Analisis de clusteres de ", clu_name)); doc <- add_blank(doc)
    doc <- add_p(doc, paste0("Se aplico el algoritmo K-means con ", clu[["n_clusters"]], " clusteres sobre n = ", clu[["n"]], " casos. ",
      "El indice de silueta promedio fue de ", clu[["silhouette"]], ", lo cual indica una ", tolower(as.character(clu[["silhouette_interpret"]])), "."))
    doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, paste0("Descripcion de los clusteres de ", clu_name))
    clu_clusters <- tryCatch(clu[["clusters"]], error=function(e) NULL)
    if (!is.null(clu_clusters) && length(clu_clusters) > 0) {
      clu_df <- do.call(rbind.data.frame, lapply(clu_clusters, function(c) data.frame(
        Cluster=as.character(c[["cluster"]]), n=as.character(c[["n"]]), Pct=paste0(c[["pct"]],"%"),
        M=as.character(c[["mean"]]), DE=as.character(c[["sd"]]), Nivel=as.character(c[["label"]]), stringsAsFactors=FALSE)))
      names(clu_df) <- c("Cluster","n","%","M","DE","Nivel")
      doc <- add_apa_table(doc, value=clu_df)
      doc <- add_blank(doc)
    }
    doc <- add_note(doc, paste0("SC intra-cluster = ", clu[["within_ss"]], "; SC inter-cluster = ", clu[["between_ss"]], "."))
    doc <- add_blank(doc)
  }

  # ====== Discriminante ======
  dis <- tryCatch(result[["discriminant"]], error=function(e) NULL)
  if (!is.null(dis) && is.null(dis[["error"]])) {
    doc <- add_heading(doc, "Analisis discriminante"); doc <- add_blank(doc)
    doc <- add_p(doc, paste0("Se estimo un modelo discriminante (", as.character(dis[["method_used"]]), ") con n = ", dis[["n"]],
      " casos sobre la variable de agrupacion ", as.character(dis[["group_var"]]), ". ",
      "Lambda de Wilks = ", dis[["wilks_lambda"]], ", chi2(", dis[["wilks_df"]], ") = ", dis[["wilks_chi2"]],
      ", p ", if(!is.null(dis[["wilks_p"]]) && dis[["wilks_p"]]<.001) "< .001" else paste0("= ", round(dis[["wilks_p"]],3)), "."))
    doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Matriz de clasificacion del modelo discriminante")
    dis_cm <- tryCatch(dis[["confusion_matrix"]], error=function(e) NULL)
    if (!is.null(dis_cm)) {
      dis_cm_df <- tryCatch(as.data.frame(dis_cm), error=function(e) NULL)
      if (!is.null(dis_cm_df)) {
        doc <- add_apa_table(doc, value=to_df(dis_cm_df))
        doc <- add_blank(doc)
      }
    }
    doc <- add_note(doc, paste0("Porcentaje de clasificacion correcta global = ", dis[["precision"]], "%."))
    doc <- add_blank(doc)
    dis_cv <- tryCatch(dis[["cross_validation"]], error=function(e) NULL)
    if (!is.null(dis_cv)) {
      doc <- add_p(doc, paste0("Validacion cruzada (Leave-One-Out): precision = ", dis_cv[["precision_cv"]], "%."))
      doc <- add_blank(doc)
    }
  }

  # ====== ANCOVA ======
  anc <- tryCatch(result[["ancova"]], error=function(e) NULL)
  if (!is.null(anc) && is.null(anc[["error"]])) {
    doc <- add_heading(doc, paste0("ANCOVA de ", as.character(anc[["dep_var"]]))); doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, paste0("Tabla ANCOVA para ", as.character(anc[["dep_var"]])))
    anc_rows <- tryCatch(anc[["ancova_table"]], error=function(e) NULL)
    if (!is.null(anc_rows) && length(anc_rows) > 0) {
      anc_df <- do.call(rbind.data.frame, lapply(anc_rows, function(r) data.frame(
        Fuente=as.character(r[["source"]]), SC=as.character(r[["SS"]]), gl=as.character(r[["df"]]),
        MC=as.character(r[["MS"]]), F=as.character(r[["F"]]), p=as.character(r[["p_apa"]]), stringsAsFactors=FALSE)))
      doc <- add_apa_table(doc, value=anc_df)
      doc <- add_blank(doc)
    }
    doc <- add_note(doc, paste0("R2 ANCOVA = ", anc[["r2_ancova"]], "; R2 ANOVA (sin covariable) = ", anc[["r2_anova"]], "; mejora = ", anc[["r2_improvement"]], "."))
    doc <- add_blank(doc)
    anc_slopes <- tryCatch(anc[["homogeneity_slopes"]], error=function(e) NULL)
    if (!is.null(anc_slopes)) {
      doc <- add_p(doc, paste0("Prueba de homogeneidad de pendientes de regresion: F = ", anc_slopes[["F"]], ", p = ", anc_slopes[["p"]], ". ", as.character(anc_slopes[["interpretation"]]), "."))
      doc <- add_blank(doc)
    }
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Medias ajustadas por grupo")
    anc_means <- tryCatch(anc[["adjusted_means"]], error=function(e) NULL)
    if (!is.null(anc_means) && length(anc_means) > 0) {
      anc_means_df <- do.call(rbind.data.frame, lapply(anc_means, function(m) data.frame(
        Grupo=as.character(m[["group"]]), Media_ajustada=as.character(m[["mean_adj"]]), EE=as.character(m[["se"]]),
        IC_inf=as.character(m[["ci_lower"]]), IC_sup=as.character(m[["ci_upper"]]), stringsAsFactors=FALSE)))
      names(anc_means_df) <- c("Grupo","Media ajustada","EE","IC 95% inf","IC 95% sup")
      doc <- add_apa_table(doc, value=anc_means_df)
      doc <- add_blank(doc)
    }
    doc <- add_p(doc, decode_utf8(as.character(anc[["decision"]]))); doc <- add_blank(doc)
  }

  # ====== Regresion ordinal ======
  ord <- tryCatch(result[["ordinal_regression"]], error=function(e) NULL)
  if (!is.null(ord) && is.null(ord[["error"]])) {
    doc <- add_heading(doc, paste0("Regresion ordinal de ", as.character(ord[["var_b"]]))); doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Coeficientes del modelo de regresion ordinal")
    ord_coefs <- tryCatch(ord[["coefficients"]], error=function(e) NULL)
    if (!is.null(ord_coefs) && length(ord_coefs) > 0) {
      ord_df <- do.call(rbind.data.frame, lapply(ord_coefs, function(c) data.frame(
        Termino=as.character(c[["term"]]), B=as.character(c[["B"]]), OR=as.character(c[["OR"]]),
        IC_inf=as.character(c[["ci_lower"]]), IC_sup=as.character(c[["ci_upper"]]),
        p=as.character(c[["p_apa"]]), stringsAsFactors=FALSE)))
      names(ord_df) <- c("Termino","B","OR","IC 95% inf","IC 95% sup","p")
      doc <- add_apa_table(doc, value=ord_df)
      doc <- add_blank(doc)
    }
    doc <- add_note(doc, paste0("Pseudo R2 de Nagelkerke = ", ord[["nagelkerke_r2"]], "; AIC = ", ord[["aic"]], "."))
    doc <- add_blank(doc)
    ord_parallel <- tryCatch(ord[["parallel_lines_test"]], error=function(e) NULL)
    if (!is.null(ord_parallel)) {
      doc <- add_p(doc, paste0("Prueba de lineas paralelas: z = ", ord_parallel[["z"]], ", p = ", ord_parallel[["p"]], ". ", as.character(ord_parallel[["interpretation"]]), "."))
      doc <- add_blank(doc)
    }
    doc <- add_p(doc, decode_utf8(as.character(ord[["decision"]]))); doc <- add_blank(doc)
  }

  # ====== Regresion jerarquica ======
  jer <- tryCatch(result[["hierarchical_regression"]], error=function(e) NULL)
  if (!is.null(jer) && is.null(jer[["error"]])) {
    doc <- add_heading(doc, paste0("Regresion jerarquica de ", as.character(jer[["var_b"]]))); doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Resumen de modelos por bloque")
    jer_blocks <- tryCatch(jer[["blocks"]], error=function(e) NULL)
    if (!is.null(jer_blocks) && length(jer_blocks) > 0) {
      jer_df <- do.call(rbind.data.frame, lapply(jer_blocks, function(b) data.frame(
        Bloque=as.character(b[["name"]]), R2=as.character(b[["r2"]]), R2_ajustado=as.character(b[["r2_adj"]]),
        Delta_R2=as.character(b[["delta_r2"]]), F_cambio=as.character(b[["f_change"]]), p_cambio=as.character(b[["p_change_apa"]]),
        stringsAsFactors=FALSE)))
      names(jer_df) <- c("Bloque","R2","R2 ajustado","Delta R2","F de cambio","p de cambio")
      doc <- add_apa_table(doc, value=jer_df)
      doc <- add_blank(doc)
    }
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Coeficientes del modelo final")
    jer_coefs <- tryCatch(jer[["final_coefficients"]], error=function(e) NULL)
    if (!is.null(jer_coefs) && length(jer_coefs) > 0) {
      jer_coefs_df <- do.call(rbind.data.frame, lapply(jer_coefs, function(c) data.frame(
        Termino=as.character(c[["term"]]), B=as.character(c[["B"]]), EE=as.character(c[["SE"]]),
        t=as.character(c[["t"]]), p=as.character(c[["p_apa"]]), stringsAsFactors=FALSE)))
      names(jer_coefs_df) <- c("Termino","B","EE","t","p")
      doc <- add_apa_table(doc, value=jer_coefs_df)
      doc <- add_blank(doc)
    }
    doc <- add_note(doc, paste0("R2 final = ", jer[["final_r2"]], "; R2 ajustado final = ", jer[["final_r2_adj"]], "."))
    doc <- add_blank(doc)
  }

  # ?????? Objetivos especificos (correlaciones dimensiones)
  if (!is.null(correlations) && nrow(correlations) > 0) {
    corr_d <- correlations[correlations[["type"]] != "general",, drop=FALSE]
    if (nrow(corr_d) > 0) {
      doc <- add_heading(doc, "Objetivos especificos"); doc <- add_blank(doc)
      for (i in seq_len(nrow(corr_d))) {
        row <- corr_d[i,]
        vA <- as.character(row[["var_a"]]); vB <- as.character(row[["var_b"]])
        doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
        doc <- add_table_title(doc, paste0("Relación entre ", vA, " y ", vB))
        ddf <- data.frame(Variables=paste0(vA," y ",vB), n=as.character(row[["n"]]),
          Coef=paste0(sym," = ",row[["r_apa"]],row[["stars"]]), p=as.character(row[["p_apa"]]),
          IC=if(!is.null(row[["ci_lower"]])) format_apa_ci(row[["ci_lower"]], row[["ci_upper"]], 3) else "-",
          Decision=as.character(row[["decision"]]), stringsAsFactors=FALSE, check.names=FALSE)
        names(ddf)[3] <- met; names(ddf)[5] <- "IC 95%"; names(ddf)[6] <- "Decisión"
        doc <- add_apa_table(doc, value=to_df(ddf))
        doc <- add_blank(doc)
        r_v <- tryCatch(as.numeric(as.character(row[["r_apa"]])),error=function(e)0)
        mag <- if(abs(r_v)>=0.8)"muy alta" else if(abs(r_v)>=0.6)"alta" else if(abs(r_v)>=0.4)"moderada" else "baja"
        ic_txt <- if(!is.null(row[["ci_lower"]]) && !is.na(row[["ci_lower"]])) paste0(", IC 95% ", format_apa_ci(row[["ci_lower"]], row[["ci_upper"]], 3)) else ""
        sig_oe <- tryCatch(as.logical(row[["significant"]]), error=function(e) grepl("Se rechaza", as.character(row[["decision"]])))
        doc <- add_p(doc, paste0(
          "Los hallazgos muestran una relación ", if(r_v>0)"positiva" else "negativa", ", ", mag, " y ",
          if(isTRUE(sig_oe))"estadísticamente significativa" else "no estadísticamente significativa",
          " entre ", vA, " y ", vB, ", ", sym, " = ", row[["r_apa"]], ", p ", row[["p_apa"]], ic_txt, "."))
        doc <- add_blank(doc)
      }
    }
  }

  # ?????? t-test
  res <- add_ttest_section(doc, ttest, tbl_n)
  doc <- res$doc; tbl_n <- res$tbl_n

  # ?????? ANOVA
  res <- add_anova_section(doc, anova_res, tbl_n, as.character(result[["objective"]] %||% ""), as.character(result[["hypothesis_h1"]] %||% ""))
  doc <- res$doc; tbl_n <- res$tbl_n

  # ?????? Regresion lineal
  res <- add_regression_section(doc, regression, tbl_n)
  doc <- res$doc; tbl_n <- res$tbl_n

  # ?????? Regresion logistica
  res <- add_logistic_section(doc, logistic, tbl_n)
  doc <- res$doc; tbl_n <- res$tbl_n

  # ?????? Chi-cuadrado
  res <- add_chisquare_section(doc, chi_sq, tbl_n)

  # Instrumentos
  instruments_data <- tryCatch(result[["instruments"]], error=function(e) NULL)
  if (!is.null(instruments_data)) {
    res <- add_instruments_section(doc, instruments_data, tbl_n)
    doc <- res$doc; tbl_n <- res$tbl_n
  }


  # Instrumentos
  instruments_data <- tryCatch(result[["instruments"]], error=function(e) NULL)
  if (!is.null(instruments_data)) {
    res <- add_instruments_section(doc, instruments_data, tbl_n)
    doc <- res$doc; tbl_n <- res$tbl_n
  }


  # Instrumentos
  instruments_data <- tryCatch(result[["instruments"]], error=function(e) NULL)
  if (!is.null(instruments_data)) {
    res <- add_instruments_section(doc, instruments_data, tbl_n)
    doc <- res$doc; tbl_n <- res$tbl_n
  }

  doc <- res$doc; tbl_n <- res$tbl_n

  doc
}


# ?????? Word export exclusivo para instrumentos ???????????????????????????????????????????????????????????????????????????????????????????????????
generate_word_instruments <- function(result, config, output_dir, tbl_start=1) {
  doc   <- officer::read_docx()
  tbl_n <- tbl_start
  instr <- tryCatch(result[["instruments"]], error=function(e) NULL)
  if (!is.null(instr)) {
    res <- add_instruments_section(doc, instr, tbl_n)
    doc <- res$doc
    tbl_n <- res$tbl_n
  }
  va <- tryCatch(result[["vaiken"]], error=function(e) NULL)
  if (!is.null(va) && is.null(va[["error"]])) {
    va_items <- tryCatch(va[["items"]], error=function(e) NULL)
    if (!is.null(va_items) && length(va_items) > 0) {
      doc <- add_heading(doc, "Validez de contenido - V de Aiken"); doc <- add_blank(doc)
      doc <- add_p(doc, paste0("Se evaluo la validez de contenido mediante el coeficiente V de Aiken, con la participacion de ", va[["n_judges"]], " jueces expertos, sobre una escala de ", va[["scale_min"]], " a ", va[["scale_max"]], "."))
      doc <- add_blank(doc)
      doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
      doc <- add_table_title(doc, "Coeficiente V de Aiken por item")
      va_df <- do.call(rbind.data.frame, lapply(va_items, function(it) data.frame(
        Item=as.character(it[["item"]]), n_jueces=as.character(it[["n_jueces"]]),
        V=as.character(it[["V"]]), IC_inf=as.character(it[["IC_low"]]), IC_sup=as.character(it[["IC_high"]]),
        Veredicto=as.character(it[["veredicto"]]), stringsAsFactors=FALSE)))
      names(va_df) <- c("Item","n jueces","V de Aiken","IC 95% inf","IC 95% sup","Veredicto")
      doc <- add_apa_table(doc, value=va_df)
      doc <- add_blank(doc)
      doc <- add_note(doc, "V >= .80 Valido; V >= .70 Aceptable (revisar); V < .70 Rechazado. Penfield y Giacobbi (2004).")
      doc <- add_blank(doc)
    }
  }
  doc
}

save_word <- function(doc, output_dir, job_id=NULL) {
  fname <- if (!is.null(job_id) && nchar(as.character(job_id)) > 0)
    paste0("ResultadosAPA_", job_id, ".docx") else "ResultadosAPA.docx"
  fpath <- file.path(output_dir, fname)
  print(doc, target=fpath)
  fpath
}


# ──────────────────────────────────────────────────────────────────────────────
# Word export exclusivo para PLS-SEM
# Modulo independiente. No modifica pls_sem_engine.R (motor blindado).
# ──────────────────────────────────────────────────────────────────────────────
df_from_list <- function(lst) {
  if (is.null(lst) || length(lst) == 0) return(NULL)
  tryCatch(do.call(rbind.data.frame, c(lapply(lst, function(x) as.data.frame(x, stringsAsFactors = FALSE)), stringsAsFactors = FALSE)),
           error = function(e) NULL)
}

fmt_p_apa <- function(p_col) {
  sapply(as.numeric(p_col), function(pv) if (is.na(pv)) "" else if (pv < .001) "< .001" else formatC(pv, digits = 3, format = "f"))
}


select_rename <- function(df, mapping) {
  if (is.null(df) || !nrow(df)) return(NULL)
  keep <- intersect(names(mapping), names(df))
  if (!length(keep)) return(NULL)
  out <- df[, keep, drop=FALSE]
  names(out) <- unname(mapping[keep])
  out
}

add_optional_pls_table <- function(doc, tbl, title, note, tbl_n, cols=NULL) {
  df <- df_from_list(tbl)
  if (is.null(df) || !nrow(df)) return(list(doc=doc,tbl_n=tbl_n))
  if (!is.null(cols)) {
    keep <- intersect(cols, names(df))
    if (length(keep) > 0) df <- df[, keep, drop=FALSE]
  }
  doc <- add_table_num(doc,tbl_n); tbl_n <- tbl_n+1
  doc <- add_table_title(doc,title)
  doc <- add_apa_table(doc,value=to_df(df)); doc <- add_blank(doc)
  if (!is.null(note) && nzchar(note)) { doc <- add_note(doc,note); doc <- add_blank(doc) }
  list(doc=doc,tbl_n=tbl_n)
}

generate_word_pls_sem <- function(result, config, output_dir, tbl_start = 1) {
  doc   <- officer::read_docx()
  tbl_n <- tbl_start
  study_title <- tryCatch(sanitize_text(config[["study_title"]] %||% "Modelo de ecuaciones estructurales (PLS-SEM)"), error = function(e) "Modelo PLS-SEM")

  doc <- add_heading(doc, study_title); doc <- add_blank(doc)
  n_obs <- tryCatch(result[["n_observations"]], error = function(e) NULL)
  n_boot <- tryCatch(result[["n_boot"]], error = function(e) NULL)
  if (!is.null(n_obs)) {
    doc <- add_p(doc, paste0("Se estimo un modelo PLS-SEM con n = ", n_obs, " observaciones validas",
                              if (!is.null(n_boot)) paste0(", utilizando bootstrapping con ", n_boot, " remuestreos para la inferencia.") else "."))
    doc <- add_blank(doc)
  }

  tbl <- tryCatch(result[["tables"]], error = function(e) NULL)
  if (is.null(tbl)) {
    doc <- add_p(doc, "No se encontraron tablas de resultados para este modelo.")
    return(doc)
  }

  rel_df <- df_from_list(tbl[["Confiabilidad"]])
  if (!is.null(rel_df) && nrow(rel_df) > 0) {
    doc <- add_heading(doc, "Confiabilidad y validez convergente del modelo de medicion"); doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Confiabilidad compuesta y validez convergente por constructo")
    rel_df <- select_rename(rel_df, c(Constructo="Constructo",Cronbach_Alpha="Alfa de Cronbach",rho_A="rho_A",
      Composite_Reliability_CR="Confiabilidad Compuesta (CR)",AVE="AVE",Tipo="Tipo"))
    doc <- add_apa_table(doc, value=to_df(rel_df))
    doc <- add_blank(doc)
    doc <- add_note(doc, "AVE = varianza media extraida; CR >= .70 y AVE >= .50 indican confiabilidad y validez convergente adecuadas (Hair et al., 2022).")
    doc <- add_blank(doc)
  }

  load_df <- df_from_list(tbl[["Cargas"]])
  if (!is.null(load_df) && nrow(load_df) > 0) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Cargas factoriales estandarizadas por indicador (criterio mayor o igual a .708)")
    load_df <- select_rename(load_df, c(Item="Item",Constructo="Constructo",Loading="Carga",OK="Cumple",Tipo="Tipo"))
    doc <- add_apa_table(doc, value=to_df(load_df))
    doc <- add_blank(doc)
    doc <- add_note(doc, "Se recomienda revisar indicadores con cargas menores a .708 (Hair et al., 2022).")
    doc <- add_blank(doc)
  }

  htmt_df <- df_from_list(tbl[["HTMT"]])
  if (!is.null(htmt_df) && nrow(htmt_df) > 0) {
    doc <- add_heading(doc, "Validez discriminante"); doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Razon Heterotrait-Monotrait (HTMT) entre constructos")
    names(htmt_df) <- c("Constructo 1", "Constructo 2", "HTMT", "Criterio")
    doc <- add_apa_table(doc, value=to_df(htmt_df))
    doc <- add_blank(doc)
    doc <- add_note(doc, "HTMT < .85 (criterio estricto) o < .90 (criterio liberal) indica validez discriminante adecuada (Henseler et al., 2015).")
    doc <- add_blank(doc)
  }

  fl_df <- df_from_list(tbl[["FornellLarcker"]])
  if (!is.null(fl_df) && nrow(fl_df) > 0) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Criterio de Fornell-Larcker")
    doc <- add_apa_table(doc, value=to_df(fl_df))
    doc <- add_blank(doc)
    doc <- add_note(doc, "La raiz de AVE (diagonal) debe ser mayor que las correlaciones con los demas constructos (Fornell y Larcker, 1981).")
    doc <- add_blank(doc)
  }

  paths_df <- df_from_list(tbl[["Paths"]])
  if (!is.null(paths_df) && nrow(paths_df) > 0) {
    doc <- add_heading(doc, "Evaluacion del modelo estructural"); doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Coeficientes de ruta (bootstrapping)")
    paths_df$P_Valor <- fmt_p_apa(paths_df$P_Valor)
    paths_df <- select_rename(paths_df, c(Path="Relacion",Beta="Beta",STDEV="DE",T_Valor="t",P_Valor="p",
      `IC_2.5`="IC 2.5%",`IC_97.5`="IC 97.5%",CI_Significant="IC excluye cero",f2="f2"))
    doc <- add_apa_table(doc, value=to_df(paths_df))
    doc <- add_blank(doc)
    doc <- add_note(doc, "DE = desviacion estandar bootstrap. ***p < .001; **p < .01; *p < .05; n.s. = no significativo.")
    doc <- add_blank(doc)
  }

  controls_df <- df_from_list(tbl[["Controls"]])
  if (!is.null(controls_df) && nrow(controls_df) > 0) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Variables de control incorporadas al modelo estructural")
    doc <- add_apa_table(doc, value=to_df(controls_df))
    doc <- add_blank(doc)
    doc <- add_note(doc, "Cada variable de control fue estimada como constructo de un indicador con rutas explicitas hacia los resultados seleccionados.")
    doc <- add_blank(doc)
  }

  r2_df <- df_from_list(tbl[["R2"]])
  if (!is.null(r2_df) && nrow(r2_df) > 0) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Coeficiente de determinacion (R2) por constructo endogeno")
    names(r2_df) <- c("Constructo", "R2", "R2 ajustado", "Nivel")
    doc <- add_apa_table(doc, value=to_df(r2_df))
    doc <- add_blank(doc)
    doc <- add_note(doc, "Niveles de R2 segun Hair et al. (2022): >= .75 sustancial; >= .50 moderado; >= .25 debil.")
    doc <- add_blank(doc)
  }

  q2_df <- df_from_list(tbl[["Q2"]])
  if (!is.null(q2_df) && nrow(q2_df) > 0) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Relevancia predictiva (Q2) por blindfolding")
    q2_cols <- intersect(c("Constructo","Q2","SSE","SSO","Indicadores","Distancia_omision","Nivel"), names(q2_df))
    doc <- add_apa_table(doc, value=to_df(q2_df[, q2_cols, drop=FALSE]))
    doc <- add_blank(doc)
    doc <- add_note(doc, "Q2 > 0 indica relevancia predictiva del modelo para el constructo (Hair et al., 2022).")
    doc <- add_blank(doc)
  }

  vif_df <- df_from_list(tbl[["VIF"]])
  if (!is.null(vif_df) && nrow(vif_df) > 0) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Factor de inflacion de varianza (VIF) de predictores")
    doc <- add_apa_table(doc, value=to_df(vif_df))
    doc <- add_blank(doc)
    doc <- add_note(doc, "VIF < 3.3 indica ausencia de multicolinealidad problematica (Hair et al., 2022).")
    doc <- add_blank(doc)
  }

  srmr_df <- df_from_list(tbl[["SRMR"]])
  if (!is.null(srmr_df) && nrow(srmr_df) > 0) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Diagnostico SRMR compuesto: modelos saturado y estimado")
    srmr_cols <- intersect(c("Indice","Valor","Criterio","Tipo","d_ULS"), names(srmr_df))
    doc <- add_apa_table(doc, value=to_df(srmr_df[, srmr_cols, drop=FALSE]))
    doc <- add_blank(doc)
    doc <- add_note(doc, "El SRMR se interpreta como diagnostico descriptivo y no constituye por si solo una prueba global concluyente de ajuste en PLS-SEM.")
    doc <- add_blank(doc)
  }

  hyp_df <- df_from_list(tbl[["Hypotheses"]])
  if (!is.null(hyp_df) && nrow(hyp_df) > 0) {
    doc <- add_heading(doc, "Contrastacion de hipotesis"); doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Resultados de la contrastacion de hipotesis")
    hyp_df$P_Valor <- fmt_p_apa(hyp_df$P_Valor)
    hyp_df <- select_rename(hyp_df, c(Hipotesis="Hipotesis",Relacion="Relacion",Beta="Beta",T_Valor="t",
      P_Valor="p",Sig="Significancia",Decision="Decision"))
    doc <- add_apa_table(doc, value=to_df(hyp_df))
    doc <- add_blank(doc)
  }

  ind_df <- df_from_list(tbl[["IndirectEffects"]])
  if (!is.null(ind_df) && nrow(ind_df) > 0) {
    doc <- add_heading(doc, "Efectos indirectos (mediacion)"); doc <- add_blank(doc)
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Efectos indirectos bootstrap")
    ind_df$P_Valor <- fmt_p_apa(ind_df$P_Valor)
    ind_df <- select_rename(ind_df, c(Path="Ruta indirecta",Beta_ind="Beta indirecto",STDEV="DE",T_Valor="t",
      P_Valor="p",`IC_2.5`="IC 2.5%",`IC_97.5`="IC 97.5%",CI_Significant="IC excluye cero",
      Bootstrap_Valid="Bootstrap valido"))
    doc <- add_apa_table(doc, value=to_df(ind_df))
    doc <- add_blank(doc)
    doc <- add_note(doc, "Efecto indirecto significativo si el intervalo de confianza bootstrap no contiene cero (Hair et al., 2022).")
    doc <- add_blank(doc)
  }

  total_df <- df_from_list(tbl[["TotalEffects"]])
  if (!is.null(total_df) && nrow(total_df) > 0) {
    doc <- add_table_num(doc, tbl_n); tbl_n <- tbl_n + 1
    doc <- add_table_title(doc, "Efectos directos, indirectos y totales")
    total_df <- select_rename(total_df, c(Relacion="Relacion",Directo="Efecto directo",Indirecto="Efecto indirecto total",Total="Efecto total"))
    doc <- add_apa_table(doc, value=to_df(total_df))
    doc <- add_blank(doc)
    doc <- add_note(doc, "Efecto total = efecto directo + suma de todos los efectos indirectos especificos con los mismos extremos.")
    doc <- add_blank(doc)
  }

  # Procedimientos PLS-SEM avanzados
  advanced_tables <- list(
    list(key="HTMT_CI", title="HTMT inferencial con intervalo bootstrap", note="Los intervalos provienen del objeto boot_HTMT de SEMinR.", cols=c("C1","C2","HTMT","IC_2.5","IC_97.5","OK_CI")),
    list(key="PLSPredict", title="PLS-Predict a nivel de indicadores endogenos", note="Predicciones fuera de muestra con 10 folds y 10 repeticiones; benchmark: LM y media de entrenamiento.", cols=c("Indicador","Constructo","RMSE_modelo","MAE_modelo","RMSE_LM","MAE_LM","Q2_predict","Nivel")),
    list(key="VAF_Mediacion", title="Clasificacion de la mediacion", note="La clasificacion sigue la logica de Zhao y usa el intervalo bootstrap conjunto del efecto indirecto total; el VAF es descriptivo y solo se informa cuando directo e indirecto son significativos y concordantes."),
    list(key="FullVIF_CMB", title="VIF de colinealidad total", note="Es un diagnostico de posible sesgo de metodo comun, no una prueba concluyente.", cols=c("Variable_Latente","VIF_Full","Umbral","Estado")),
    list(key="GaussianCopula", title="Sensibilidad de endogeneidad mediante copula gaussiana", note="Procedimiento opt-in: verifica no normalidad, usa la ECDF ajustada F4, incorpora un constructo copular de un indicador y reestima el modelo PLS. El bootstrap es condicional al termino copular generado en la etapa 1; un resultado no significativo no demuestra exogeneidad."),
    list(key="FIMIX_Fit", title="FIMIX-PLS: criterios de informacion y seleccion del numero de segmentos", note="La seleccion considera conjuntamente AIC3 y CAIC; ante desacuerdo se presenta AIC4 como criterio unico auxiliar. Los segmentos requieren interpretacion teorica y estabilidad."),
    list(key="FIMIX_Segments", title="FIMIX-PLS: tamano y proporcion de segmentos", note="Los segmentos provienen de asignacion probabilistica EM y no deben interpretarse automaticamente como grupos sustantivos."),
    list(key="FIMIX_Paths", title="FIMIX-PLS: coeficientes de ruta por segmento", note="Coeficientes estructurales estimados para la solucion FIMIX seleccionada."),
    list(key="ModelComparison", title="Comparacion de modelos directo, paralelo y secuencial", note="Comparacion descriptiva y predictiva bajo la misma medicion y los mismos casos; no constituye por si sola una prueba de superioridad causal."),
    list(key="MICOM", title="Invarianza de medicion de modelos compuestos (MICOM)", note="Los pesos se reestiman en cada permutacion; las varianzas se comparan en escala logaritmica y los valores p se ajustan con Holm."),
    list(key="MGA", title="Analisis multigrupo por permutacion", note="Se reporta solo cuando todos los constructos del modelo alcanzaron invarianza composicional para el par de grupos; los intervalos corresponden a la distribucion de referencia por permutacion y los valores p se ajustan con Holm."),
    list(key="IPMA", title="Mapa importancia-rendimiento (IPMA)", note="El rendimiento se escala con los limites teoricos de la escala; la importancia corresponde a efectos totales no estandarizados sobre scores 0–100 construidos con pesos desestandarizados.", cols=c("Target","Predictor","Importancia_Efecto_Total","Direccion_Efecto","Performance_0_100","Cuadrante","Prioridad"))
  )
  for (spec in advanced_tables) {
    sec <- add_optional_pls_table(doc, tbl[[spec$key]], spec$title, spec$note, tbl_n, cols=spec$cols)
    doc <- sec$doc; tbl_n <- sec$tbl_n
  }

  group_source <- tryCatch(as.character(result[["group_source"]] %||% "none"),error=function(e)"none")
  if (!identical(group_source,"none")) {
    doc <- add_p(doc,paste0("Fuente de agrupacion utilizada por MICOM/MGA: ",group_source,"."))
    doc <- add_blank(doc)
  }

  # Tabla de estado de modulos omitida del Word (informacion tecnica interna)

  doc
}
