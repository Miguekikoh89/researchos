# ============================================================================
# ResearchOS Stats Engine — helpers.R
# Utilidades APA 7, interpretación estadística, formateo
# Extraído y refactorizado desde CorrelaStat Pro v4.0
# ============================================================================

`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b

# ----------------------------------------------------------------------------
# FORMATEO APA 7
# ----------------------------------------------------------------------------

#' Formato APA sin cero inicial: .482 no 0.482
format_r_apa <- function(r) {
  if (is.na(r)) return(NA_character_)
  s <- sprintf("%.3f", r)
  sub("^0\\.", ".", sub("^-0\\.", "-.", s))
}

#' Formato p-value APA
format_p_apa <- function(p) {
  if (is.na(p)) return(NA_character_)
  if (p < 0.001) return("< .001")
  s <- sprintf("%.3f", p)
  sub("^0\\.", ".", s)
}

#' Estrellas de significancia
stars_p <- function(p) {
  if (is.na(p)) return("")
  if      (p < 0.001) "***"
  else if (p < 0.01)  "**"
  else if (p < 0.05)  "*"
  else                "ns"
}

# ----------------------------------------------------------------------------
# INTERPRETACIÓN ESTADÍSTICA
# ----------------------------------------------------------------------------

#' Magnitud de correlación (escala canónica ResearchOS, basada en Cohen 1988)
#' Nota: los rangos son orientativos; la interpretación depende del campo.
interpret_r <- function(r) {
  # Cohen (1988): despreciable <.10, debil .10-.29, moderada .30-.49,
  # fuerte .50-.69, muy fuerte >=.70
  a <- abs(r)
  if (is.na(a)) return("indeterminado")
  if (a >= 0.70) return("muy fuerte")
  if (a >= 0.50) return("fuerte")
  if (a >= 0.30) return("moderada")
  if (a >= 0.10) return("debil")
  return("despreciable")
}

#' Interpretación estructurada de correlación con dirección y advertencia contextual
interpret_r_full <- function(r) {
  if (is.na(r)) {
    return(list(r = r, absolute_r = NA, direction = "indeterminado",
                strength = "indeterminado", interpretation_scale = "Cohen (1988) orientativo",
                contextual_warning = "Coeficiente no disponible."))
  }
  list(
    r                   = r,
    absolute_r          = abs(r),
    direction           = if (r > 0) "positiva" else if (r < 0) "negativa" else "ninguna",
    strength            = interpret_r(r),
    interpretation_scale = "Cohen (1988): despreciable <.10, debil .10-.29, moderada .30-.49, fuerte .50-.69, muy fuerte >=.70",
    contextual_warning  = "Los rangos son orientativos. La magnitud relevante depende del campo de investigacion y del constructo medido."
  )
}

#' Tamaño de efecto según Cohen (1988)
effect_size_label <- function(r) {
  r <- abs(r)
  if      (r < 0.10) "trivial"
  else if (r < 0.30) "pequeño"
  else if (r < 0.50) "mediano"
  else if (r < 0.70) "grande"
  else               "muy grande"
}

#' Interpretación Alfa de Cronbach según George & Mallery (2020)
interpret_alpha <- function(al) {
  if (is.na(al))  return("No calculado")
  if (al >= 0.90) return("Excelente")
  if (al >= 0.80) return("Bueno")
  if (al >= 0.70) return("Aceptable")
  if (al >= 0.60) return("Cuestionable")
  if (al >= 0.50) return("Pobre")
  return("Inaceptable")
}

# ----------------------------------------------------------------------------
# REDACCIÓN ACADÉMICA APA 7
# ----------------------------------------------------------------------------

#' Redactar párrafo de normalidad
redact_normality <- function(norm_res, alpha = 0.05) {
  if (is.null(norm_res) || nrow(norm_res) == 0) return("")
  todas_normal  <- all(norm_res$decision == "Normal")
  alguna_normal <- any(norm_res$decision == "Normal")

  if (todas_normal) {
    paste0(
      "Los resultados de la prueba de normalidad evidencian que las variables evaluadas ",
      "presentan distribución normal, dado que los valores de significancia fueron iguales ",
      "o mayores a .05. En consecuencia, se empleó el coeficiente r de Pearson para el ",
      "análisis correlacional, al tratarse de una prueba paramétrica adecuada cuando se ",
      "cumple el supuesto de normalidad."
    )
  } else if (!alguna_normal) {
    paste0(
      "Los resultados de la prueba de normalidad evidencian que las variables y dimensiones ",
      "no presentan distribución normal, dado que los valores de significancia fueron menores ",
      "a .05. Por ello, se empleó el coeficiente Rho de Spearman, al tratarse de una prueba ",
      "no paramétrica adecuada para analizar la relación entre variables que no cumplen el ",
      "supuesto de normalidad."
    )
  } else {
    paste0(
      "Los resultados de la prueba de normalidad muestran resultados mixtos entre las variables ",
      "evaluadas: algunas presentan distribución normal (p ≥ .05) y otras no (p < .05). ",
      "Ante esta situación, se optó por emplear el coeficiente Rho de Spearman para todas las ",
      "correlaciones, criterio más conservador que garantiza la validez de las inferencias ",
      "estadísticas independientemente de la distribución de las variables."
    )
  }
}

#' Redactar párrafo de correlación APA 7
redact_correlation <- function(r, p, var1, var2, method,
                               alpha = 0.05,
                               participants = "los participantes evaluados") {
  dir     <- if (r >= 0) "positiva" else "negativa"
  mag     <- interpret_r(r)
  sym     <- if (method == "pearson") "r" else "ρ"
  met_str <- if (method == "pearson") "r de Pearson" else "Rho de Spearman"
  r_str   <- format_r_apa(r)
  p_str   <- if (p < 0.001) "p < .001" else paste0("p = ", format_p_apa(p))
  sig     <- p < alpha

  intros <- c(
    "Los resultados evidencian",
    "Los hallazgos muestran",
    "Se observa",
    "El análisis permitió identificar"
  )
  intro <- intros[sample(length(intros), 1)]

  if (sig) {
    paste0(
      intro, " una relación ", dir, ", ", mag,
      " y estadísticamente significativa entre ", var1, " y ", var2,
      ", ", sym, " = ", r_str, ", ", p_str, ". ",
      if (r >= 0)
        paste0("Esto indica que, a mayores niveles de ", var1,
               ", tienden a presentarse mayores niveles de ", var2,
               " en ", participants, ".")
      else
        paste0("Esto indica que, a mayores niveles de ", var1,
               ", tienden a presentarse menores niveles de ", var2,
               " en ", participants, "."),
      " Por tanto, se rechaza la hipótesis nula."
    )
  } else {
    paste0(
      "No se encontró una relación estadísticamente significativa entre ", var1,
      " y ", var2, ", ", sym, " = ", r_str, ", ", p_str, ". ",
      "Los datos no permiten concluir que exista una asociación sistemática entre ",
      "ambas variables en ", participants, ". ",
      "Por tanto, no se rechaza la hipótesis nula."
    )
  }
}

#' Redactar descriptivos
redact_descriptives <- function(desc_res) {
  if (is.null(desc_res) || nrow(desc_res) == 0) return("")
  ord  <- desc_res[order(-desc_res$mean), ]
  mx   <- ord[1, ]
  mn   <- ord[nrow(ord), ]
  paste0(
    "En la tabla de estadísticos descriptivos se observa que las variables evaluadas ",
    "presentan medias que oscilan entre ", format_r_apa(mn$mean), " y ", format_r_apa(mx$mean), ". ",
    "La media más elevada corresponde a ", mx$variable, " (M = ", format_r_apa(mx$mean),
    ", DE = ", format_r_apa(mx$sd), "), ",
    if (nrow(ord) > 1)
      paste0("seguida de ", ord[2, "variable"], " (M = ", format_r_apa(ord[2, "mean"]), "). ")
    else "",
    "Estos valores reflejan la distribución de las puntuaciones obtenidas por los participantes ",
    "en cada una de las variables del estudio."
  )
}

#' Redactar baremo
redact_baremo <- function(br) {
  if (is.null(br)) return("")
  paste0(
    "El baremo de la variable ", br$variable, " se organizó en tres niveles: ",
    tolower(br$levels[1]), ", ", tolower(br$levels[2]), " y ", tolower(br$levels[3]), ". ",
    "Esta clasificación permite interpretar los puntajes obtenidos por los participantes ",
    "de acuerdo con los rangos establecidos según el método seleccionado (n = ", br$n, ")."
  )
}

#' Redactar niveles/frecuencias
redact_levels <- function(br, participants = "los participantes") {
  if (is.null(br)) return("")
  freq <- br$frequencies
  ord  <- order(-freq$f)
  mx   <- freq[ord[1], ]
  nd   <- freq[ord[2], ]
  mn_r <- freq[ord[3], ]
  cierre <- if (is.finite(mx$pct) && mx$pct > 50) {
    paste0(
      "Esto evidencia que la mayoría de los participantes se ubicó en el nivel ",
      tolower(mx$nivel), " en la variable evaluada."
    )
  } else {
    paste0(
      "La mayor proporción de participantes se ubicó en el nivel ",
      tolower(mx$nivel), " en la variable evaluada."
    )
  }
  paste0(
    "Los resultados muestran que el ", mx$pct, "% de ", participants,
    " presentó un nivel ", tolower(mx$nivel), " de ", br$variable, ", ",
    "mientras que el ", nd$pct, "% se ubicó en nivel ", tolower(nd$nivel),
    " y el ", mn_r$pct, "% en nivel ", tolower(mn_r$nivel), ". ",
    cierre
  )
}

#' Redactar confiabilidad APA
redact_reliability <- function(cr_list) {
  if (is.null(cr_list) || length(cr_list) == 0) return("")
  textos <- lapply(cr_list, function(r) {
    al  <- r$alpha
    nom <- r$name
    if (is.na(al)) return(NULL)
    cal <- interpret_alpha(al)
    paste0(
      "La escala de ", nom, " presentó un Alfa de Cronbach de α = ",
      format_r_apa(al),
      " (IC 95% [", format_r_apa(r$ci_lower), ", ", format_r_apa(r$ci_upper), "]), ",
      "con k = ", r$k, " ítems y n = ", r$n, " observaciones válidas, ",
      "lo que indica una consistencia interna ", tolower(cal), " según los criterios de ",
      "George y Mallery (2020)."
    )
  })
  paste(Filter(Negate(is.null), textos), collapse = " ")
}
# force rebuild Tue Jul  7 13:20:07 -05 2026
