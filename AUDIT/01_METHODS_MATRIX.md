# 01 — MATRIZ DE MÉTODOS ESTADÍSTICOS
## ResearchOS / CanchariOS — Auditoría 2026-06-28

**Leyenda de estado:**
- ✅ Implementado y verificado en código
- ⚠️ Implementado con deficiencias identificadas
- ❌ No implementado / ausente
- ❓ NO VERIFICADO: requiere evidencia adicional

---

## MÉTODO 1: CORRELACIÓN (Pearson / Spearman)

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `statistics.R` — `correlate_pearson()`, `correlate_spearman()`, `correlate_matrix()` |
| **Dispatch** | ✅ | `analysis_category == "correlacional"` → `run_analysis.R` |
| **Selección automática** | ✅ | `decide_method()` evalúa normalidad (SW), linealidad (Harvey-Collier manual), outliers (Cook's D >1) → elige Pearson o Spearman |
| **Estadístico principal** | ✅ | `r` (Pearson) / `rho` (Spearman) con exactitud `exact=(n<=30)` |
| **p-value** | ✅ | t-distribución para Pearson; tabla exacta/asintótica para Spearman |
| **IC 95%** | ✅ | Fisher Z para Pearson; Fisher Z en rangos para Spearman |
| **Tamaño del efecto** | ⚠️ | `interpret_r()` definida en AMBOS `helpers.R` y `statistics.R` con umbrales distintos. La de `statistics.R` tiene BUG: rango [0.80, 0.90) devuelve "muy alta" igual que ≥0.90. |
| **Supuestos verificados** | ⚠️ | Normalidad (SW), linealidad, outliers. Sin prueba de Shapiro para n > 5000 (no aplica aquí). |
| **Formato APA 7** | ✅ | `r(n-2) = X, p Y, IC95%[a, b]` |
| **Exportación Word** | ✅ | `add_correlation_section()` en word_export.R |
| **Limitación conocida** | ⚠️ | `interpret_r()` con thresholds incorrectos (ver FINDINGS F-003) |

---

## MÉTODO 2: COMPARACIÓN DE GRUPOS (t-test / Mann-Whitney / Wilcoxon)

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `t_test.R` — `compute_ttest()` orquestador |
| **Dispatch** | ✅ | `analysis_category == "comparacion"` |
| **Selección automática** | ✅ | Pareado: normalidad de diferencias → t_paired vs wilcoxon_paired. Independiente: normalidad de ambos grupos → t_independent vs mann_whitney |
| **Levene test** | ✅ | Implementación manual con desviaciones absolutas. Selecciona Student vs Welch. |
| **Cohen's d** | ✅ | Fórmula correcta: pooled SD (independiente), `mean(diff)/sd(diff)` (pareado) |
| **Mann-Whitney U** | ✅ | `wilcox.test(correct=TRUE, conf.int=TRUE)` — con corrección de continuidad |
| **Efecto no paramétrico** | ⚠️ | `r_rb = 1 - 2U/(n1*n2)` — fórmula de rango biserial. Wilcoxon pareado usa `W/(n*(n+1)/2)` que da proporción de pares positivos, no el r estándar de Field (2013). |
| **p-value APA** | ✅ | `"< .001"` o `"= X.XXX"` |
| **IC 95%** | ✅ | Para diferencia de medias (t-test) y estimador Hodges-Lehmann (Mann-Whitney via conf.int) |
| **Formato APA 7** | ✅ | `t(df) = X, p Y, d = Z` / `U = X, p Y, r = Z` |
| **Exportación Word** | ✅ | `add_ttest_section()` |

---

## MÉTODO 3: ANOVA (Paramétrico / Kruskal-Wallis)

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `anova.R` — `compute_anova()` |
| **Dispatch** | ⚠️ | **BUG CRÍTICO:** bloque `"anova"` DUPLICADO en run_analysis.R (líneas 283-336 y 338-391). Segundo bloque es código muerto. |
| **Selección automática** | ✅ | Shapiro-Wilk por grupo → ANOVA o Kruskal-Wallis |
| **η²** | ✅ | `SS_between / SS_total` — correcto |
| **ω²** | ✅ | `(SS_between - df_between * MS_within) / (SS_total + MS_within)` |
| **ε² (Kruskal)** | ✅ | `H / ((N²-1)/(N+1))` — fórmula Tomczak & Tomczak (2014) |
| **Post-hoc** | ✅ | Tukey HSD, Bonferroni, Scheffé, Games-Howell, Dunn (Kruskal) — todos implementados |
| **Levene** | ✅ | `levene_anova()` — implementación manual |
| **Formato APA 7** | ✅ | `F(df1, df2) = X, p Y, η² = Z` |
| **Exportación Word** | ✅ | `add_anova_section()` |

---

## MÉTODO 4: REGRESIÓN LINEAL (Simple / Múltiple)

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `regression.R` — `compute_regression()` |
| **Métodos** | ✅ | Enter (simultánea), Stepwise, Forward, Backward — via `step()` |
| **R², R² ajustado** | ✅ | Calculados correctamente |
| **β estandarizado** | ✅ | `b * sd(X) / sd(y)` — correcto |
| **VIF** | ✅ | Calculado manualmente via R² de cada predictor vs. resto |
| **Supuestos** | ✅ | Normalidad residuos (SW), independencia (DW), homocedasticidad (BP), outliers influyentes (Cook's D, umbral 4/n), especificación (RESET) |
| **IC coeficientes** | ✅ | `confint()` estándar |
| **BUG menor** | ⚠️ | `significant = p < ci_alpha` donde `ci_alpha = 1 - coef_ci`. Con coef_ci=0.95, ci_alpha=0.05 (correcto por coincidencia), pero semánticamente es confuso e incorrecto. |
| **Formato APA 7** | ✅ | Tabla de coeficientes con B, SE, β, t, p, IC 95% |
| **Exportación Word** | ✅ | `add_regression_section()` |

---

## MÉTODO 5: REGRESIÓN LOGÍSTICA BINARIA

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `logistic.R` — `compute_logistic(type="binaria")` |
| **Pseudo-R²** | ✅ | Cox-Snell y Nagelkerke — fórmulas correctas |
| **OR con IC** | ✅ | `exp(coef)` y `exp(confint())` |
| **Hosmer-Lemeshow** | ✅ | Implementación manual con g=10 grupos |
| **ROC/AUC** | ✅ | Implementación manual (trapecio) |
| **Tabla clasificación** | ✅ | Sensibilidad, especificidad, accuracy |
| **BUG comportamiento** | ⚠️ | Si y no es 0/1, auto-binariza usando `median(y)` como umbral SIN advertencia explícita al usuario en el output (líneas 85-87 logistic.R) |
| **Estadístico de Wald** | ✅ | `(B/SE)²` |
| **Formato APA 7** | ✅ | |
| **Exportación Word** | ✅ | `add_logistic_section()` |

---

## MÉTODO 6: REGRESIÓN LOGÍSTICA MULTINOMIAL

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `logistic_multinomial.R` — `compute_logistic_multinomial()` |
| **Paquete** | ✅ | `nnet::multinom()` |
| **LR Chi²** | ✅ | Comparación modelo nulo vs. completo |
| **OR por nivel** | ✅ | `exp(B)` por cada comparación vs. nivel referencia |
| **z-tests** | ✅ | `B/SE` con distribución normal asintótica |
| **Pseudo-R²** | ✅ | Cox-Snell y Nagelkerke |
| **Tabla confusión** | ✅ | `table(Real, Predicho)` |
| **IC 95% para OR** | ❌ | **Ausente.** Solo se reporta OR sin IC para cada coeficiente. |
| **Separación completa** | ❌ | No detecta ni advierte sobre separación completa. |

---

## MÉTODO 7: REGRESIÓN ORDINAL

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `ordinal_regression.R` — `run_ordinal_regression()` |
| **Paquete** | ✅ | `MASS::polr()` |
| **p-values** | ⚠️ | Aproximación t (no se usa distribución chi² exacta para Wald) — práctica común |
| **DV continua** | ⚠️ | Tricotomiza la VD continua via terciles/percentiles/teórico. Convierte variable continua a ordinal artificialmente. |
| **Test líneas paralelas** | ⚠️ | Solo para primer predictor (comparación de coeficientes en dos puntos de corte) — no es el test de Brant completo |
| **Pseudo-R²** | ✅ | Cox-Snell, McFadden, Nagelkerke |
| **OR** | ✅ | `exp(B)` |
| **IC 95% para OR** | ✅ | |

---

## MÉTODO 8: REGRESIÓN JERÁRQUICA

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `hierarchical_regression.R` — `run_hierarchical_regression()` |
| **F-cambio** | ✅ | `((R²curr - R²prev)/df1) / ((1-R²curr)/df2)` — correcto |
| **Agregación** | ⚠️ | Usa `rowMeans()` de ítems por bloque como scores. Pierde varianza de ítems individuales. |
| **Predictores** | ⚠️ | Etiquetas son nombres de bloque, no nombres de ítems individuales |
| **Supuestos** | ❓ | NO VERIFICADO si se reportan supuestos por cada bloque o solo el modelo final |

---

## MÉTODO 9: ANCOVA

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `ancova.R` — `run_ancova()` |
| **Paquete** | ✅ | `emmeans` para medias ajustadas y post-hoc |
| **Homogeneidad de pendientes** | ✅ | Término de interacción `covariable * grupo` |
| **η² parcial** | ❌ | **Ausente.** Solo se reporta R² del modelo, no η² parcial por factor. |
| **Post-hoc ajustado** | ✅ | `emmeans` con Bonferroni |
| **Supuesto normalidad residuos** | ❓ | NO VERIFICADO si se verifica en el output |

---

## MÉTODO 10: ANÁLISIS DISCRIMINANTE

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `discriminant.R` — `run_discriminant()` |
| **Paquete** | ✅ | `MASS::lda(CV=TRUE)` — validación cruzada LOO |
| **Wilks Lambda** | ✅ | Calculado manualmente via SVD de eigenvalores |
| **Función discriminante** | ✅ | Coeficientes LDA |
| **Matriz de confusión** | ✅ | Clasificación observada vs. predicha |
| **Box's M** | ❌ | **Ausente.** Prueba de igualdad de matrices de covarianza no implementada. |
| **Matriz de estructura** | ❌ | **Ausente.** Correlaciones entre predictores y funciones discriminantes. |
| **Coeficientes estandarizados** | ❌ | **Ausentes.** |

---

## MÉTODO 11: ANÁLISIS CLUSTER (K-means)

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `cluster.R` — `run_cluster()` |
| **Algoritmo** | ✅ | `kmeans(nstart=25)` |
| **Índice silhouette** | ✅ | `cluster::silhouette()` |
| **Gráfico de codo** | ✅ | Within-SS para k=1 a min(6, n-1) |
| **Etiquetas de cluster** | ⚠️ | "Alto/Medio/Bajo" por comparación media del cluster vs. media global ± 0.3 SD — heurístico no estándar |
| **Clustering jerárquico** | ❌ | **Ausente.** Solo K-means. |
| **Gap statistic** | ❌ | **Ausente.** |
| **Estabilidad** | ❌ | **Ausente.** No hay análisis de estabilidad de clusters. |

---

## MÉTODO 12: CHI-CUADRADO

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `chi_square.R` — `compute_chisquare()` |
| **Pearson χ²** | ✅ | Correcto |
| **Corrección Yates** | ✅ | Auto para tablas 2×2 |
| **Fisher exact** | ✅ | `fisher.test()` |
| **V de Cramér** | ✅ | Ajuste por `df_min = min(r-1, c-1)` — Cohen 1988 |
| **Phi** | ✅ | Para tablas 2×2 |
| **Residuos ajustados** | ❌ | Solo residuos de Pearson `(obs-exp)/sqrt(exp)`. **Faltan residuos estandarizados ajustados** `(obs-exp)/sqrt(exp*(1-row_pct)*(1-col_pct))` |
| **Uso con datos continuos** | ⚠️ | `run_analysis.R` tricotomiza scores continuos con `cut(..., breaks=3)` antes de chi-cuadrado — metodológicamente inválido |

---

## MÉTODO 13: VALIDACIÓN DE INSTRUMENTOS (AFE + AFC + HTMT + KMO + Confiabilidad)

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `instruments.R` — `compute_instruments()` |
| **KMO** | ✅ | `psych::KMO()` + `psych::cortest.bartlett()` |
| **AFE** | ✅ | `psych::fa.parallel()` (determinación factores) + `psych::fa()` (extracción) |
| **AFC** | ✅ | `lavaan::cfa()` con estimador configurable (default MLR) |
| **Índices de ajuste AFC** | ✅ | CFI, TLI, RMSEA (con IC 90%), SRMR |
| **HTMT** | ✅ | Cálculo manual con bootstrap 200 remuestras |
| **V de Aiken** | ✅ | Con IC exacto Penfield & Giacobbi (2004) |
| **Omega** | ⚠️ | En `statistics.R::compute_omega()`: `sum_load_sq <- sum(loadings)^2` — BUG: calcula (Σλ)² en lugar de Σλ². Numerador del omega incorrecto. |
| **Imputación** | ⚠️ | Reemplaza fuera de rango con NA, luego imputa con media de columna. La asignación vectorizada puede estar desalineada con posiciones NA. |
| **Normalidad multivariada** | ✅ | Mardia (skewness y kurtosis multivariada) |
| **Confiabilidad** | ✅ | Alfa de Cronbach + IC bootstrap + omega (cuando disponible) |

---

## MÉTODO 14: ANÁLISIS DESCRIPTIVO (Completo)

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `analisis_descriptivo.R` — `run_analisis_descriptivo()` |
| **Estadísticos** | ✅ | M, Mdn, Mo, DE, Var, Min, Max, Rango, CV, IQR, P25/P50/P75 |
| **Asimetría/Curtosis** | ✅ | Calculadas manualmente con fórmulas estándar (momento central / σ³ y σ⁴) |
| **Normalidad** | ✅ | Shapiro-Wilk + IC para la media |
| **Baremo** | ✅ | Tercil/percentil/teórico — distribución por niveles + texto APA automático |
| **Por ítem** | ✅ | Estadísticos por ítem incluidos |
| **Texto automático** | ✅ | Plantilla de redacción con valores reales insertados |
| **Ítems invertidos** | ❌ | `compute_scores()` usa `rowMeans()` sin manejo de ítems invertidos |

---

## MÉTODO 15: ALFA DE CRONBACH (Standalone)

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `cronbach_only.R` — `run_cronbach_only()` |
| **Fórmula** | ✅ | `(k/(k-1)) * (1 - Σvar_i / var_total)` — correcto |
| **Bootstrap IC** | ✅ | 1000 iteraciones, seed=42, percentil 2.5/97.5 |
| **Omega** | ✅ | `psych::omega(nfactors=1)` — usa la función del paquete (no el compute_omega con bug) |
| **r ítem-total** | ✅ | Correlación ítem con suma del resto |
| **α si se elimina** | ✅ | Calculado para cada ítem |
| **Interpretación** | ✅ | Excelente/Bueno/Aceptable/Cuestionable/Inaceptable (umbrales .90/.80/.70/.60) |

---

## MÉTODO 16: BAREMOS (Standalone)

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `baremos_only.R` — `run_baremos_only()` |
| **Métodos de corte** | ✅ | Teórico, percentil (P25/P75), tercil (P33/P67) |
| **Distribución** | ✅ | Frecuencia, porcentaje, porcentaje acumulado por nivel |
| **Percentiles** | ✅ | P0 a P100 en intervalos de 10% |
| **Texto automático** | ✅ | Plantilla narrativa con porcentajes reales |

---

## MÉTODO 17: FRECUENCIAS (Standalone)

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `frequencies.R` — `run_frequencies()` |
| **Tablas por ítem** | ✅ | Frecuencia, %, % acumulado |
| **Estadísticos** | ✅ | M, Mdn, Mo, DE, Min, Max, Asimetría, Curtosis |
| **Asimetría/Curtosis manuales** | ✅ | Usando momentos estándar |
| **Exportación Word** | ❓ | NO VERIFICADO: `word_export.R` tiene sección de `analisis_descriptivo` pero no sección explícita de `frequencies` |

---

## MÉTODO 18: PLS-SEM (Modelo de Ecuaciones Estructurales Mínimos Cuadrados Parciales)

| Dimensión | Estado | Detalle |
|-----------|--------|---------|
| **Archivo** | ✅ | `pls_sem_engine.R` (952 líneas) — motor standalone |
| **Paquete** | ✅ | `seminr` |
| **Medidas de confiabilidad** | ✅ | CR, AVE via `calc_cr_ave()` |
| **Validez convergente** | ✅ | AVE ≥ 0.50 |
| **Validez discriminante** | ✅ | HTMT, Fornell-Larcker, Cross-loadings |
| **VIF (colinealidad)** | ✅ | VIF por indicador |
| **f² (efecto)** | ✅ | `calc_f2()` |
| **q² (predictivo)** | ✅ | `calc_q2()` — blindfolding d=7 |
| **SRMR** | ✅ | `calc_srmr()` — cálculo manual con `S_hat = Λ Φ Λ'` |
| **Efectos indirectos** | ✅ | Bootstrap; fallback Sobel con simulación normal (seed=456) |
| **PLS-Predict (10-fold CV)** | ✅ | `calc_pls_predict()` |
| **VAF (mediación)** | ✅ | `calc_vaf_mediation()` |
| **HTMT CI bootstrap** | ✅ | `calc_htmt_ci()` |
| **CMB (Full-collinearity VIF)** | ✅ | `calc_full_vif()` |
| **Copula Gaussiana** | ✅ | `calc_gaussian_copula()` — Park & Gupta (2012) |
| **MICOM** | ✅ | `calc_micom()` — Henseler (2016) |
| **MGA** | ✅ | `calc_mga()` — permutation multigroup analysis |
| **IPMA** | ✅ | `calc_ipma()` — Ringle & Sarstedt (2016) |
| **Jitter en datos** | ⚠️ | `jitter(amount=1e-4)` aplicado a columnas numéricas — modifica datos sutilmente |
| **Ítems únicos duplicados** | ⚠️ | `df_j[[paste0(avail[1],"__dup__")]] <- jitter(...)` — heurístico metodológicamente cuestionable |
| **df hardcoded en p-values indirectos** | ⚠️ | `df=max(384-1, 1)` — valor 384 parece arbitrario, no derivado de los datos |
| **Exportación Word** | ✅ | `pls_word_wrapper.R` → `generate_word_pls_sem()` en word_export.R |

---

## RESUMEN EJECUTIVO DE COBERTURA

| Categoría | Métodos cubiertos | Estado general |
|-----------|-------------------|----------------|
| Comparación | t-test, Mann-Whitney, Wilcoxon, ANOVA, Kruskal-Wallis | ✅ con observaciones |
| Correlación | Pearson, Spearman, Matriz | ✅ con BUG en interpret_r() |
| Regresión | Lineal (4 métodos), Ordinal, Jerárquica, Logística binaria, Logística multinomial | ⚠️ multiple issues |
| Predicción/Clasificación | Discriminante, Cluster K-means | ⚠️ missing features |
| Psicometría | AFE, AFC, HTMT, Cronbach, Omega, V Aiken | ⚠️ BUG omega en statistics.R |
| Estructural | PLS-SEM completo (17 sub-análisis) | ⚠️ issues menores |
| Descriptivo | Descriptivos completos, Baremos, Frecuencias | ✅ sin ítems invertidos |
| Contingencia | Chi-cuadrado, Fisher, V Cramér | ⚠️ residuos ausentes |
| ANCOVA | ANCOVA + emmeans | ⚠️ sin η² parcial |

**Total de métodos implementados:** ≥18 análisis estadísticos cubiertos  
**Hallazgos críticos identificados:** Ver AUDIT/02_RISK_REGISTER.md
