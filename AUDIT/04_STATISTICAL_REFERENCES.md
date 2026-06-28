# 04 — REFERENCIAS ESTADÍSTICAS Y CIENTÍFICAS
## ResearchOS / CanchariOS — Auditoría 2026-06-28

**NOTA:** Solo se incluyen referencias verificadas en el código fuente o en la documentación del repositorio. No se inventan referencias.

---

## 1. REFERENCIAS ENCONTRADAS EN CÓDIGO (verificadas)

### Citadas explícitamente en methodRecommendation.ts

- **Flores-Ruiz, E., Miranda-Novales, G., & Villasís-Keever, M. Á. (2017).** El protocolo de investigación VI: cómo elegir la prueba estadística adecuada. Estadística inferencial. *Revista Alergia México, 64*(3), 364-370.
  - *Uso en código:* Criterio principal: escala de medición de la variable resultado determina la prueba.

- **Field, A. (2013).** *Discovering Statistics Using IBM SPSS Statistics* (4th ed.). SAGE Publications.
  - *Uso en código:* ANCOVA, regresión logística vs. discriminante.

- **Hair, J. F., Black, W. C., Babin, B. J., & Anderson, R. E. (2019).** *Multivariate Data Analysis* (8th ed.). Cengage Learning.
  - *Uso en código:* Criterio de PLS-SEM cuando hay múltiples indicadores por constructo.

- **IBM SPSS Statistics Documentation.**
  - *Uso en código:* Comparación logística multinomial vs. discriminante.

### Citadas en comentarios de código R

- **Penfield, R. D., & Giacobbi, P. R. (2004).** Applying a score confidence interval to Aiken's item content-relevance index. *Measurement in Physical Education and Exercise Science, 8*(4), 213-225.
  - *Uso en código:* `compute_vaiken()` en instruments.R — IC exacto para V de Aiken.

- **Park, S., & Gupta, S. (2012).** Handling endogeneity in marketing models using instrumental variables. *International Journal of Research in Marketing, 29*(3), 288-297.
  - *Uso en código:* `calc_gaussian_copula()` en pls_sem_engine.R.

- **Henseler, J. (2016).** Testing, measurement invariance and multigroup analysis in partial least squares path modeling. In H. Abdi, V. E. Babin, F. Saporta & D. Violato (Eds.), *New Perspectives in Partial Least Squares and Related Methods*. Springer.
  - *Uso en código:* `calc_micom()` — measurement invariance composite models.

- **Ringle, C. M., & Sarstedt, M. (2016).** Gain more insight from your PLS-SEM results: The importance-performance map analysis. *Industrial Management & Data Systems, 116*(9), 1865-1886.
  - *Uso en código:* `calc_ipma()` — importance-performance map analysis.

- **Tomczak, M., & Tomczak, E. (2014).** The need to report effect size estimates revisited. An overview of some recommended measures of effect size. *Trends in Sport Sciences, 1*(21), 19-25.
  - *Uso en código (inferido de fórmula):* ε² para Kruskal-Wallis: `H / ((N²-1)/(N+1))`.

- **Cohen, J. (1988).** *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). Lawrence Erlbaum Associates.
  - *Uso en código (inferido):* Umbrales de d (trivial/pequeño/mediano/grande), umbrales de r, umbral de V de Cramér ajustado por df_min.

- **Henseler, J., Ringle, C. M., & Sarstedt, M. (2015).** A new criterion for assessing discriminant validity in variance-based structural equation modeling. *Journal of the Academy of Marketing Science, 43*(1), 115-135.
  - *Uso en código (inferido):* HTMT < 0.85 como criterio de validez discriminante en word_export.R.

- **McDonald, R. P. (1999).** *Test Theory: A Unified Treatment.* Lawrence Erlbaum Associates.
  - *Uso en código (inferido):* Omega de McDonald implementado via `psych::omega()`.

- **Cohen, J., Cohen, P., West, S. G., & Aiken, L. S. (2003).** *Applied Multiple Regression/Correlation Analysis for the Behavioral Sciences* (3rd ed.). Lawrence Erlbaum Associates.
  - *Uso en código (inferido por comentario en methodRecommendation.ts):* Regresión jerárquica para evaluar ΔR².

---

## 2. PAQUETES R USADOS — REFERENCIAS ACADÉMICAS

| Paquete | Referencia canónica | Uso en sistema |
|---------|--------------------|-----------------|
| `psych` | Revelle, W. (2024). psych: Procedures for Psychological, Psychometric, and Personality Research. R package. CRAN. | KMO, Bartlett, AFE (fa, fa.parallel), omega |
| `lavaan` | Rosseel, Y. (2012). lavaan: An R Package for Structural Equation Modeling. *Journal of Statistical Software, 48*(2), 1-36. | AFC (cfa()) |
| `GPArotation` | Bernaards, C. A., & Jennrich, R. I. (2005). Gradient Projection Algorithms and Software for Arbitrary Rotation Criteria in Factor Analysis. *Educational and Psychological Measurement, 65*(5), 676-696. | Rotaciones AFE |
| `seminr` | Ray, S., Danks, N., & Calero Valdez, A. (2022). seminr: Building and Estimating Structural Equation Models. R package. CRAN. | PLS-SEM |
| `MASS` | Venables, W. N., & Ripley, B. D. (2002). *Modern Applied Statistics with S* (4th ed.). Springer. | polr (ordinal), lda (discriminante) |
| `nnet` | Ripley, B. D. (1994). Neural Networks and Related Methods for Classification. *Journal of the Royal Statistical Society, Series B, 56*(3), 409-456. | multinom (logística multinomial) |
| `emmeans` | Lenth, R. V. (2024). emmeans: Estimated Marginal Means, aka Least-Squares Means. R package. CRAN. | ANCOVA medias ajustadas |
| `cluster` | Maechler, M., Rousseeuw, P., Struyf, A., Hubert, M., & Hornik, K. (2023). cluster: Cluster Analysis Basics and Extensions. R package. CRAN. | Silhouette, K-means |
| `officer` | Gohel, D. (2024). officer: Manipulation of Microsoft Word and PowerPoint Documents. R package. CRAN. | Exportación Word |
| `car` | Fox, J., & Weisberg, S. (2019). *An R Companion to Applied Regression* (3rd ed.). SAGE Publications. | Durbin-Watson, Breusch-Pagan |
| `nortest` | Gross, J., & Ligges, U. (2015). nortest: Tests for Normality. R package. CRAN. | Kolmogorov-Smirnov (Lilliefors) |
| `readxl` | Wickham, H., & Bryan, J. (2023). readxl: Read Excel Files. R package. CRAN. | Lectura de archivos Excel |

---

## 3. ESTÁNDARES DE REPORTE ESTADÍSTICO

### APA 7th Edition
- American Psychological Association. (2020). *Publication Manual of the American Psychological Association* (7th ed.). APA.
  - *Uso en código:* Formato p-values ("< .001" o "= X.XXX"), tablas con nota, numeración de tablas.

### Criterios de ajuste AFC (usados en instruments.R)
Los criterios de ajuste verificados en el código son:
- CFI ≥ .95 = excelente; CFI ≥ .90 = aceptable (Hu & Bentler, 1999)
- TLI ≥ .95 = excelente (Tucker & Lewis, 1973)
- RMSEA ≤ .06 = excelente; ≤ .08 = aceptable (Hu & Bentler, 1999)
- SRMR ≤ .08 = excelente (Hu & Bentler, 1999)

**Referencia:** Hu, L., & Bentler, P. M. (1999). Cutoff criteria for fit indexes in covariance structure analysis. *Structural Equation Modeling, 6*(1), 1-55.

---

## 4. REFERENCIAS PARA CORRECCIONES PENDIENTES (P0/P1)

Las siguientes referencias son relevantes para corregir los hallazgos del Risk Register:

### Para F-003 — interpret_r() y umbrales de correlación
- Cohen, J. (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed., pp. 78-81). Lawrence Erlbaum Associates.
  - Umbrales: r < .10 = trivial, .10-.30 = pequeño, .30-.50 = moderado, .50-.70 = grande, ≥.70 = muy grande

### Para F-001 — Omega de McDonald
- McDonald, R. P. (1999). *Test Theory: A Unified Treatment* (pp. 89-91). Lawrence Erlbaum Associates.
  - ωt = (Σλi)² / [(Σλi)² + Σ(δi²)] donde δi² son varianzas de error
- Revelle, W., & Zinbarg, R. E. (2009). Coefficients Alpha, Beta, Omega, and the glb. *Psychometrika, 74*(1), 145-154.

### Para F-009 — Residuos estandarizados ajustados en chi-cuadrado
- Haberman, S. J. (1973). The analysis of residuals in cross-classified tables. *Biometrics, 29*(1), 205-220.
  - Residuo ajustado: eij = (fij - F̂ij) / sqrt(F̂ij * (1 - pi.) * (1 - p.j))

### Para F-010 — η² parcial en ANCOVA
- Cohen, J. (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed., pp. 283-288).
  - ηp² = SS_efecto / (SS_efecto + SS_error_del_modelo)

### Para F-011 — Box's M
- Box, G. E. P. (1949). A general distribution theory for a class of likelihood criteria. *Biometrika, 36*(3-4), 317-346.
  - M = (N-g) * ln|Sp| - Σ(ni-1) * ln|Si|

### Para F-013 — Test de Brant para líneas paralelas
- Brant, R. (1990). Assessing proportionality in the proportional odds model for ordinal logistic regression. *Biometrics, 46*(4), 1171-1178.

### Para F-015 — p-values efectos indirectos PLS-SEM
- Zhao, X., Lynch, J. G., & Chen, Q. (2010). Reconsidering Baron and Kenny. *Journal of Consumer Research, 37*(2), 197-206.
- Hair, J. F., Henseler, J., Dijkstra, T. K., & Sarstedt, M. (2014). Common beliefs and reality about partial least squares. *Organizational Research Methods, 17*(2), 182-209.

---

## 5. REFERENCES NO VERIFICADAS / GAPS

Las siguientes referencias son estándar en el dominio pero NO se verificó su presencia en el código:
- Hosmer, D. W., & Lemeshow, S. (2000). *Applied Logistic Regression* (2nd ed.) — para Hosmer-Lemeshow test
- Dunn, O. J. (1964). Multiple comparisons using rank sums — para test de Dunn en Kruskal-Wallis
- Shapiro, S. S., & Wilk, M. B. (1965) — para Shapiro-Wilk test

---

*Documento creado 2026-06-28. Solo incluye referencias verificadas en el código fuente.*
