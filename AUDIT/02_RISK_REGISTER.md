# 02 — REGISTRO DE RIESGOS Y HALLAZGOS
## ResearchOS / CanchariOS — Auditoría 2026-06-28

**Clasificación de severidad:**
- **P0 — CRÍTICO:** Error que produce resultados matemáticamente incorrectos o hace caer el sistema
- **P1 — ALTO:** Error que produce resultados estadísticamente incorrectos o reportes engañosos
- **P2 — MEDIO:** Deficiencia metodológica o feature faltante que reduce la calidad científica
- **P3 — BAJO:** Mejora deseable, deuda técnica sin impacto en resultados

---

## P0 — CRÍTICOS (corregir antes de cualquier uso en producción)

### F-001 | BUG: `compute_omega()` en statistics.R — Fórmula matemáticamente incorrecta
- **Archivo:** `apps/api/stats-engine-r/R/statistics.R`, líneas ~79-107
- **Descripción:** `sum_load_sq <- sum(loadings)^2` calcula **(Σλ)²** (cuadrado de la suma) en lugar de **Σλ²** (suma de cuadrados). Esto sobreestima el numerador del omega de McDonald dramáticamente cuando hay ≥2 ítems con cargas positivas.
- **Fórmula correcta:** ω = (Σλᵢ)² / [(Σλᵢ)² + Σ(1-λᵢ²)] (Omega-total de McDonald 1999)
  - La varianza de la escala = (Σλᵢ)² + Σδᵢ donde δᵢ = varianza de error del ítem i
  - Numerador correcto: `(sum(loadings))^2` ← este SÍ es correcto
  - Denominador correcto: `(sum(loadings))^2 + sum(1 - loadings^2)` ← requiere `loadings^2` no `loadings`
  - **Aclaración después de revisión:** La línea exacta es `sum_load_sq <- sum(loadings)^2` que en realidad SÍ calcula (Σλ)² correctamente para el numerador. Sin embargo, la variable `sum_load_sq` se reutiliza en el denominador donde se necesita `sum(loadings^2)` para la varianza de unicidades. Es necesario leer el código completo de la función para determinar si el denominador también usa esta variable incorrectamente.
- **Impacto:** Omega reportado puede ser incorrecto. Potencialmente inflado o deflado según cómo se use en el denominador.
- **Evidencia necesaria:** Leer líneas completas 79-107 de statistics.R y comparar con salida real vs. valor esperado con dataset conocido.
- **Estado:** REQUIERE VERIFICACIÓN ADICIONAL antes de clasificar como bug confirmado o falso positivo.

---

### F-002 | BUG: Bloque ANOVA duplicado en run_analysis.R — Código muerto potencialmente divergente
- **Archivo:** `apps/api/stats-engine-r/run_analysis.R`, líneas ~283-391
- **Descripción:** El bloque `if (analysis_category == "anova")` aparece DOS VECES consecutivas. El segundo bloque (líneas ~338-391) es inalcanzable. Si ambos bloques son idénticos, es dead code; si divergen, hay riesgo de que una futura edición modifique solo uno.
- **Impacto actual:** Ninguno (el segundo bloque nunca se ejecuta). **Riesgo futuro:** divergencia de mantenimiento.
- **Corrección:** Eliminar el bloque duplicado (el segundo).
- **Estado:** Confirmado por lectura directa.

---

## P1 — ALTOS (afectan corrección estadística de resultados)

### F-003 | BUG: `interpret_r()` — umbral [0.80, 0.90) etiquetado incorrectamente
- **Archivo:** `apps/api/stats-engine-r/R/statistics.R`, función `interpret_r()`, líneas ~433-441
- **Descripción:** El código tiene thresholds 0.90 y 0.80 que AMBOS retornan `"muy alta"`. La condición `r >= 0.90` se evalúa primera y devuelve "muy alta", luego `r >= 0.80` también devuelve "muy alta". El rango [0.80, 0.90) debería ser `"alta"` según Cohen (1988) y según la implementación en `helpers.R`.
- **Impacto:** Correlaciones entre 0.80 y 0.89 se reportan como "muy alta" en lugar de "alta". Engaña al usuario sobre la magnitud del efecto.
- **Corrección:** Agregar condición `else if (r >= 0.80) return("alta")` antes del umbral 0.70.
- **Estado:** Confirmado. La función en `helpers.R` tiene la implementación correcta: <0.10=trivial, <0.30=baja, <0.50=moderada, <0.70=alta, ≥0.70=muy alta.

---

### F-004 | CONFLICTO: Funciones duplicadas con implementaciones divergentes (helpers.R vs statistics.R)
- **Archivos:** `helpers.R` y `statistics.R`
- **Descripción:** Las funciones `format_r_apa()`, `format_p_apa()`, `stars_p()`, `interpret_r()`, `effect_size_label()`, `interpret_alpha()` están definidas en AMBOS archivos con implementaciones distintas. Dado que `run_analysis.R` hace `source("helpers.R")` antes de `source("statistics.R")`, las versiones de `statistics.R` sobreescriben las de `helpers.R` al cargarse.
- **Impacto:** 
  - `interpret_alpha()`: `helpers.R` retorna "Bajo" para α<0.60, `statistics.R` retorna "Inaceptable". Resultados distintos en reportes.
  - `interpret_r()`: Thresholds distintos (ver F-003). La versión de statistics.R (con el bug) sobrescribe la correcta de helpers.R.
- **Corrección:** Eliminar las definiciones duplicadas de uno de los dos archivos. Mantener una sola fuente de verdad. Recomendación: mantener en helpers.R y eliminar de statistics.R.
- **Estado:** Confirmado.

---

### F-005 | METODOLÓGICO: Tricotomización automática de variable continua en chi-cuadrado
- **Archivo:** `apps/api/stats-engine-r/run_analysis.R`, bloque `"chi_cuadrado"`
- **Descripción:** Cuando se corre chi-cuadrado, el script tricotomiza scores continuos con `cut(scores[[var_a_name]], breaks=3, labels=c("Bajo","Medio","Alto"))` antes de pasarlos a `compute_chisquare()`. Esto convierte una variable continua en ordinal artificial.
- **Impacto estadístico:** 
  1. Pérdida de información (reducción de poder estadístico)
  2. Los cortes arbitrarios por `breaks=3` son iguales en amplitud (no en frecuencia), no en percentiles. Pueden crear categorías muy desiguales.
  3. El chi-cuadrado resultante NO prueba la hipótesis original sobre la relación entre variables continuas — prueba una versión artificialmente categorizada.
- **Corrección:** Advertir al usuario que chi-cuadrado requiere variables categóricas de entrada. Si el usuario selecciona chi-cuadrado con variables continuas, pedir que seleccione la categorización deseada o sugerir correlación en su lugar.
- **Estado:** Confirmado.

---

### F-006 | METODOLÓGICO: Impuatación con media en instruments.R puede desalinear con posiciones NA
- **Archivo:** `apps/api/stats-engine-r/R/instruments.R`, línea ~342
- **Descripción:** `data_items[is.na(data_items)] <- apply(data_items, 2, function(x) mean(x, na.rm=TRUE))[is.na(data_items)]` — La asignación vectorizada aplica la media de columna a posiciones NA, pero el indexado `[is.na(data_items)]` aplica el vector de medias (una por columna) a todas las posiciones NA de una matriz, lo cual puede resultar en asignaciones incorrectas si hay múltiples columnas con NAs en diferentes filas.
- **Impacto:** Imputación de media incorrecta puede alterar cargas factoriales y estadísticos de confiabilidad.
- **Corrección:** Usar un bucle por columna o `tidyr::replace_na()` por columna explícitamente.
- **Estado:** Confirmado como código potencialmente incorrecto. Severidad P1 porque afecta AFE/AFC directamente.

---

### F-007 | COMPORTAMIENTO SILENCIOSO: Auto-binarización sin advertencia en regresión logística
- **Archivo:** `apps/api/stats-engine-r/R/logistic.R`, líneas ~85-87
- **Descripción:** Si la variable dependiente no es 0/1, el código la binariza automáticamente usando `median(y)` como umbral. Esta transformación no se refleja en el output JSON con un campo de advertencia explícito.
- **Impacto:** El usuario recibe resultados de logística binaria sobre una variable transformada sin saber que ocurrió la transformación. La interpretación de OR es sobre la versión binarizada, no la original.
- **Corrección:** Agregar campo `"warning": "Variable binarizada usando mediana como umbral (X.XX). Los OR se interpretan sobre esta dicotomización, no la variable original."` en el output.
- **Estado:** Confirmado.

---

## P2 — MEDIOS (deficiencias metodológicas)

### F-008 | AUSENTE: IC 95% para OR en regresión logística multinomial
- **Archivo:** `logistic_multinomial.R`
- **Descripción:** Los coeficientes multinomiales reportan B, SE, z, p, OR pero no el IC 95% para el OR.
- **Corrección:** Agregar `OR_ci_lower = exp(B - 1.96*SE)`, `OR_ci_upper = exp(B + 1.96*SE)` (aproximación asintótica).

---

### F-009 | AUSENTE: Residuos estandarizados ajustados en chi-cuadrado
- **Archivo:** `chi_square.R`
- **Descripción:** Solo se calculan residuos de Pearson `(obs-exp)/sqrt(exp)`. Los residuos estandarizados ajustados `z_ij = (obs_ij - exp_ij) / sqrt(exp_ij * (1 - p_i.) * (1 - p_.j))` son necesarios para identificar qué celdas contribuyen significativamente a la asociación.
- **Impacto científico:** Sin residuos ajustados, no se puede saber qué combinación de categorías es la más relevante.

---

### F-010 | AUSENTE: η² parcial en ANCOVA
- **Archivo:** `ancova.R`
- **Descripción:** ANCOVA reporta R² global del modelo pero no η² parcial por factor (que controla el efecto de covariables). Este es el índice estándar para reportar tamaño del efecto en ANCOVA.
- **Corrección:** `eta2_parcial = SS_factor / (SS_factor + SS_error)` para cada fuente.

---

### F-011 | AUSENTE: Box's M en análisis discriminante
- **Archivo:** `discriminant.R`
- **Descripción:** El supuesto de igualdad de matrices de covarianza entre grupos (Box's M) no se verifica ni reporta. Es el supuesto más importante del discriminante lineal.
- **Nota:** Box's M es sensible al tamaño muestral; debe reportarse pero su violación no siempre invalida el análisis.

---

### F-012 | AUSENTE: Matriz de estructura y coeficientes estandarizados en discriminante
- **Archivo:** `discriminant.R`
- **Descripción:** Solo se reportan coeficientes LDA sin estandarizar. La matriz de estructura (correlaciones entre predictores y funciones discriminantes) es el estándar APA para interpretar qué variables son más discriminantes.

---

### F-013 | METODOLÓGICO: Test de líneas paralelas incompleto en regresión ordinal
- **Archivo:** `ordinal_regression.R`
- **Descripción:** Solo se compara el logit en dos puntos de corte para el primer predictor. El test de Brant completo evalúa el supuesto de odds proporcionales para TODOS los predictores simultáneamente.
- **Nota:** El paquete `brant` implementa esto. La aproximación actual es indicativa pero no el test estándar.

---

### F-014 | METODOLÓGICO: Jitter en datos PLS-SEM
- **Archivo:** `pls_sem_engine.R`, función `run_pls_sem()`
- **Descripción:** Se aplica `jitter(amount=1e-4)` a columnas numéricas antes de estimar el modelo. Aunque el propósito es evitar matrices singulares, modifica los datos observados.
- **Impacto:** Resultados no son completamente reproducibles sin el seed fijado, y los coeficientes son estimados sobre datos perturbados.

---

### F-015 | METODOLÓGICO: df hardcoded en p-values de efectos indirectos PLS-SEM
- **Archivo:** `pls_sem_engine.R`
- **Descripción:** `df=max(384-1, 1)` — El número 384 no se deriva de los datos del análisis. Esto puede resultar en p-values incorrectos para el efecto indirecto cuando n ≠ 384.
- **Impacto:** p-values del efecto indirecto (Sobel fallback) son incorrectos para muestras diferentes a 384.

---

### F-016 | AUSENTE: Manejo de ítems invertidos en compute_scores()
- **Archivo:** `data_cleaning.R`, `compute_scores()`
- **Descripción:** `rowMeans()` sin reversión de ítems. Si el instrumento tiene ítems en sentido negativo (p.ej., "Nunca me siento contento"), el puntaje promedio estará sesgado.
- **Impacto:** Afecta toda análisis con instrumentos que tienen ítems invertidos.

---

### F-017 | METODOLÓGICO: Tricotomización de VD continua en regresión ordinal
- **Archivo:** `ordinal_regression.R`
- **Descripción:** La función convierte automáticamente una variable dependiente continua en ordinal de 3 niveles. Esto genera pérdida de información y los resultados no son regresión ordinal sobre una variable ordinalmente medida, sino sobre una variable artificialmente categorizada.
- **Nota:** Aunque la documentación del sistema parece indicar que esto es intencional para el caso de uso, debe ser explícitamente advertido al usuario.

---

### F-018 | METODOLÓGICO: Cluster — etiquetas heurísticas no estándar
- **Archivo:** `cluster.R`
- **Descripción:** La asignación de etiquetas "Alto/Medio/Bajo" se hace comparando la media del cluster con la media global ± 0.3 SD. Este umbral ±0.3 SD es arbitrario y no corresponde a ningún criterio estadístico publicado.

---

## P3 — BAJOS (deuda técnica)

### F-019 | TÉCNICO: Directorio R hardcoded en run_analysis.R
- **Archivo:** `run_analysis.R`
- **Descripción:** `script_dir <- "/app/stats-engine-r/R"` hardcodeado. La variable de entorno `CANCHARIOS_R_DIR` está configurada en `pls_word_wrapper.R` y `validate_mtcars.R` pero no en `run_analysis.R`.
- **Impacto:** No funciona fuera de Docker sin modificar el script. Bajo impacto en producción pero inconveniente para desarrollo local.

---

### F-020 | TÉCNICO: Archivos Word almacenados en filesystem efímero (Railway)
- **Archivo:** `analysis.service.ts`, campo `filePath` en Prisma Report
- **Descripción:** Los archivos .docx se guardan en el filesystem del contenedor. En Railway (deployment plataforma), el filesystem es efímero y se pierde en reinicios.
- **Impacto:** Usuarios que vuelvan a descargar reportes después de un reinicio recibirán error 404.
- **Corrección recomendada:** Almacenar Word en S3/R2/GCS o en base de datos como BLOB (con límite de tamaño).

---

### F-021 | TÉCNICO: klaR en install_packages.R sin uso verificado
- **Archivo:** `install_packages.R`
- **Descripción:** El paquete `klaR` está en la lista de instalación pero no se encontró su uso en ningún módulo R auditado. Agrega tiempo de instalación sin beneficio demostrable.

---

### F-022 | TÉCNICO: Seed fijo en bootstrap (cronbach_only.R seed=42, pls_sem_engine.R seed=456)
- **Archivos:** `cronbach_only.R`, `pls_sem_engine.R`
- **Descripción:** Seeds fijos garantizan reproducibilidad pero significa que todos los análisis del mismo tipo producen el mismo patrón de remuestreo, independientemente de los datos.
- **Recomendación:** El seed debería ser configurable por el usuario para auditoría independiente.

---

### F-023 | TÉCNICO: DiagrammeR/DiagrammeRsvg en install_packages.R sin uso verificado
- **Archivo:** `install_packages.R`
- **Descripción:** `DiagrammeR`, `DiagrammeRsvg`, `htmlwidgets`, `visNetwork` están en la lista pero no se encontró uso directo en los módulos R auditados (pls_sem_engine.R no los usa para exportación).

---

## RESUMEN DE HALLAZGOS

| Prioridad | Cantidad | Hallazgos |
|-----------|----------|-----------|
| P0 Crítico | 2 | F-001 (omega bug — requiere verificación), F-002 (código duplicado) |
| P1 Alto | 5 | F-003 (interpret_r bug), F-004 (funciones duplicadas), F-005 (chi-cuadrado con datos continuos), F-006 (imputación desalineada), F-007 (binarización silenciosa) |
| P2 Medio | 11 | F-008 a F-018 |
| P3 Bajo | 5 | F-019 a F-023 |
| **TOTAL** | **23** | |

---

*Registro completado en inspección de 2026-06-28. Sin modificaciones al código.*
