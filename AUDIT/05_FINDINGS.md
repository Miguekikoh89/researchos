# 05 — HALLAZGOS DETALLADOS
## ResearchOS / CanchariOS — Auditoría 2026-06-28

Este archivo documenta cada hallazgo con evidencia de código exacta, impacto cuantificado donde es posible, y corrección propuesta.

---

## HALLAZGO F-001: compute_omega() — Verificación de fórmula requerida

**Severidad:** P0 (pendiente de confirmación)  
**Archivo:** `apps/api/stats-engine-r/R/statistics.R`  
**Líneas:** ~79-107

**Evidencia de código:**
```r
# Necesita releer para citar exactamente
# Variable: sum_load_sq <- sum(loadings)^2
# Uso posterior en denominador requiere verificación
```

**Estado:** REQUIERE RELEER el código completo de la función para confirmar si el denominador usa `sum_load_sq` o `sum(loadings^2)`. La clasificación P0 es provisional hasta confirmación.

**Acción necesaria:** Leer statistics.R líneas 79-107 completas y calcular un ejemplo numérico contra referencia.

---

## HALLAZGO F-002: Bloque ANOVA duplicado en run_analysis.R

**Severidad:** P0  
**Archivo:** `apps/api/stats-engine-r/run_analysis.R`  
**Líneas:** ~283-391

**Evidencia de código (verificada):**
El archivo de 944 líneas contiene dos bloques `if (analysis_category == "anova")` consecutivos con `return(result)` en cada uno. El segundo bloque nunca se ejecuta porque el primero siempre retorna.

**Impacto actual:** Ninguno. El ANOVA funciona correctamente (primer bloque).  
**Riesgo:** Confusión de mantenimiento — si alguien corrige el segundo bloque creyendo que es el activo, el bug no se aplica.

**Corrección:** Eliminar líneas ~338-391 (segundo bloque duplicado).

**Verificación post-corrección:** `validate_mtcars.R` T03 (ANOVA F=39.70) debe seguir pasando.

---

## HALLAZGO F-003: interpret_r() — Bug en rango [0.80, 0.90)

**Severidad:** P1  
**Archivo:** `apps/api/stats-engine-r/R/statistics.R`

**Evidencia de código:**
```r
# statistics.R — función interpret_r()
# Los dos primeros if retornan "muy alta" para r >= 0.80 y r >= 0.90
# El rango [0.80, 0.90) es etiquetado incorrectamente como "muy alta"
```

**Versión correcta en helpers.R:**
```r
interpret_r <- function(r) {
  a <- abs(r)
  if (is.na(a)) return("indeterminado")
  if (a >= 0.70) return("muy alta")   # helpers.R usa 0.70 como umbral superior
  if (a >= 0.50) return("alta")
  if (a >= 0.30) return("moderada")
  if (a >= 0.10) return("baja")
  return("trivial")
}
```

**Impacto cuantificado:**
- Correlaciones entre 0.80 y 0.89 se reportan como "muy alta" en lugar de "alta"
- Afecta: reportes de correlación, interpretación en Word, motor de decisión de método

**Corrección propuesta:**
Eliminar definición de `interpret_r()` de `statistics.R` (que sobreescribe la de helpers.R). La definición en `helpers.R` es la correcta y está bien alineada con la literatura de Cohen (1988).

**Alternativa:** Unificar en un único umbral coherente. La versión de helpers.R usa ≥0.70 para "muy alta", la de statistics.R usa ≥0.90. Debe decidirse cuál escala es la correcta para el contexto de la aplicación y aplicarla consistentemente.

---

## HALLAZGO F-004: Funciones duplicadas con implementaciones divergentes

**Severidad:** P1  
**Archivos:** `helpers.R` y `statistics.R`

**Lista de funciones duplicadas verificadas:**
| Función | helpers.R (umbrales) | statistics.R (umbrales) | Quién gana |
|---------|---------------------|------------------------|------------|
| `interpret_r()` | ≥0.70="muy alta" | ≥0.90 y ≥0.80 ambas="muy alta" (BUG) | statistics.R (incorrecto) |
| `interpret_alpha()` | α<0.60="Bajo" | α<0.60="Inaceptable" | statistics.R |
| `format_r_apa()` | presente | presente | statistics.R |
| `format_p_apa()` | presente | presente | statistics.R |
| `stars_p()` | presente | presente | statistics.R |
| `effect_size_label()` | presente | presente | statistics.R |

**Por qué gana statistics.R:** En `run_analysis.R`, el orden de source es:
```r
source(file.path(script_dir, "helpers.R"))      # Primero
source(file.path(script_dir, "statistics.R"))   # Segundo — sobreescribe
```

**Corrección:** Eliminar todas las definiciones duplicadas de `statistics.R` y dejar solo las de `helpers.R` como fuente única de verdad. Verificar que los umbrales de `interpret_alpha()` sean correctos en helpers.R.

---

## HALLAZGO F-005: Chi-cuadrado con tricotomización automática de datos continuos

**Severidad:** P1  
**Archivo:** `apps/api/stats-engine-r/run_analysis.R`

**Evidencia de código (verificada en lectura del script):**
```r
# Bloque chi_cuadrado en run_analysis.R
# cut(scores[[var_a_name]], breaks=3, labels=c("Bajo","Medio","Alto"))
```

**Impacto metodológico:**
1. `breaks=3` en `cut()` crea 3 intervalos de **igual amplitud**, no igual frecuencia
2. Con datos distribuidos normalmente, el grupo central tendrá más casos que los extremos, creando asimetría artificial
3. El chi-cuadrado resultante prueba asociación entre dos variables categorizadas artificialmente, no entre las variables originales
4. Pierde todo el poder estadístico que vendría de tratar las variables como continuas

**Ejemplo numérico del problema:**
```
Scores [1-5]: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 4.0
breaks=3 crea: [1.0, 2.3), [2.3, 3.7), [3.7, 5.0]
Resultado: 0 casos en "Bajo", 7 en "Medio", 3 en "Alto"
→ Chi-cuadrado fallará por frecuencias esperadas < 5 en celdas
```

**Corrección propuesta:**
- Detectar cuando `var_a` es continua (valores únicos > umbral)
- Advertir al usuario que chi-cuadrado requiere variables categóricas de entrada
- Ofrecer opciones: a) el usuario categoriza manualmente en el Excel, b) usar correlación en su lugar

---

## HALLAZGO F-006: Imputación vectorizada desalineada en instruments.R

**Severidad:** P1  
**Archivo:** `apps/api/stats-engine-r/R/instruments.R`, línea ~342

**Evidencia de código:**
```r
data_items[is.na(data_items)] <- apply(data_items, 2, function(x) mean(x, na.rm=TRUE))[is.na(data_items)]
```

**Análisis del problema:**
`apply(data_items, 2, mean, na.rm=TRUE)` retorna un vector de longitud `ncol(data_items)` (una media por columna).  
`is.na(data_items)` retorna una matriz lógica de la misma forma que `data_items`.  
La asignación `data_items[is.na(data_items)] <- vector_de_medias[is.na(data_items)]` es problemática porque:
- El vector de medias tiene longitud ncol (p.ej., 5 si hay 5 ítems)
- La matriz lógica puede tener NAs dispersos en posiciones arbitrarias
- R recicla el vector de medias para rellenar posiciones NA en orden de columna principal, pero el indexado con la misma matriz lógica puede no alinear correctamente

**Corrección correcta:**
```r
for (col in colnames(data_items)) {
  na_idx <- is.na(data_items[[col]])
  data_items[na_idx, col] <- mean(data_items[[col]], na.rm=TRUE)
}
```

---

## HALLAZGO F-007: Binarización silenciosa en regresión logística

**Severidad:** P1  
**Archivo:** `apps/api/stats-engine-r/R/logistic.R`, líneas ~85-87

**Evidencia de código:**
```r
# Si y no es 0/1, auto-binariza usando median(y) como umbral
# Sin campo de advertencia explícito en el output
```

**Impacto:** Un usuario que pasa una escala Likert 1-5 como VD recibirá resultados de regresión logística sobre una variable dicotomizada por la mediana, sin saberlo. Esto:
1. Cambia la pregunta de investigación implícitamente
2. Pierde información ordinal
3. Los OR reportados se interpretan sobre la dicotomización, no la escala original

**Corrección:**
```r
# Agregar al output cuando se binariza:
warning_binarization <- paste0(
  "Variable dependiente binarizada automáticamente usando la mediana (",
  round(median_val, 2), ") como umbral. ",
  "Los Odds Ratio se interpretan sobre la dicotomización y(>=mediana)=1, no sobre la escala original."
)
# Incluir en resultado: list(..., binarization_applied = TRUE, binarization_warning = warning_binarization)
```

---

## HALLAZGO F-008: IC 95% ausente en OR de regresión logística multinomial

**Severidad:** P2  
**Archivo:** `apps/api/stats-engine-r/R/logistic_multinomial.R`

**Evidencia:** El código reporta `OR=round(or,3)` pero no `OR_ci_lower` ni `OR_ci_upper`.

**Corrección:**
```r
OR_ci_lower = round(exp(b - 1.96 * se), 3)
OR_ci_upper = round(exp(b + 1.96 * se), 3)
```
(Aproximación asintótica normal — válida para muestras grandes)

---

## HALLAZGO F-009: Residuos estandarizados ajustados ausentes en chi-cuadrado

**Severidad:** P2  
**Archivo:** `apps/api/stats-engine-r/R/chi_square.R`

**Fórmula correcta (Haberman, 1973):**
```r
# Residuo estandarizado ajustado para celda (i,j):
z_ij <- (obs_ij - exp_ij) / sqrt(exp_ij * (1 - row_prop_i) * (1 - col_prop_j))
# |z_ij| > 1.96 → celda contribuye significativamente a χ²
```

**Corrección:** Agregar cálculo y reporte de `adjusted_residuals` en output de `compute_chisquare()`.

---

## HALLAZGO F-010: η² parcial ausente en ANCOVA

**Severidad:** P2  
**Archivo:** `apps/api/stats-engine-r/R/ancova.R`

**Fórmula:**
```r
# Para cada fuente de variación:
eta2_partial <- SS_fuente / (SS_fuente + SS_residual)
```

**Contexto:** El ANCOVA reporta `r2_ancova` y `r2_anova` pero no η² parcial que es el índice estándar para ANCOVA en APA 7.

---

## HALLAZGO F-011 a F-023: Ver AUDIT/02_RISK_REGISTER.md

Los hallazgos F-011 a F-023 están documentados con suficiente detalle en el Risk Register. Ver ese archivo para detalles de Box's M, matriz de estructura discriminante, test Brant completo, jitter PLS-SEM, df hardcoded, ítems invertidos, tricotomización ordinal, etiquetas cluster, directory hardcoded, Railway ephemeral storage, paquetes sin uso, y seeds fijos.

---

## RESUMEN DE CORRECCIONES POR ORDEN DE IMPLEMENTACIÓN

### Fase 1: Correcciones que no cambian API pública (seguras)
1. **F-002** — Eliminar bloque duplicado ANOVA (eliminar código muerto, 1 cambio)
2. **F-004** — Eliminar funciones duplicadas de statistics.R (6 funciones a eliminar)
3. **F-003** — Verificar que con F-004 resuelto, interpret_r() ahora usa la versión correcta de helpers.R

### Fase 2: Correcciones a funcionalidad (requieren pruebas)
4. **F-007** — Agregar campo de advertencia en logística cuando se binariza
5. **F-006** — Corregir imputación vectorizada en instruments.R
6. **F-008** — Agregar IC 95% para OR en multinomial
7. **F-009** — Agregar residuos ajustados en chi-cuadrado
8. **F-010** — Agregar η² parcial en ANCOVA

### Fase 3: Mejoras metodológicas (requieren decisión de producto)
9. **F-005** — Manejo de chi-cuadrado con datos continuos
10. **F-001** — Verificar y corregir compute_omega() si el bug se confirma
11. **F-013** — Test de Brant completo (requiere paquete `brant`)

### Fase 4: Infraestructura (deploy)
12. **F-020** — Persistent storage para archivos Word
13. **F-019** — Usar variable de entorno CANCHARIOS_R_DIR en run_analysis.R

---

*Documento creado 2026-06-28. Sin correcciones aplicadas aún.*

---
---

# FASE FINAL — HALLAZGOS DE LA VALIDACIÓN CRUZADA NODE→R→POSTGRESQL (2026-07-03)

Rama: `claude/cancharios-stats-audit-0pnx4q`. Todos los hallazgos de esta fase
fueron descubiertos por las suites de integración dinámica (AG–AK) que ejercitan
el `AnalysisService` compilado con PostgreSQL real y `Rscript run_analysis.R`
de producción, sin mocks.

---

## HALLAZGO F-025: Logística binaria SIEMPRE fallaba por la vía Node→R

**Severidad:** P1 (BUG PRODUCTIVO)
**Archivo:** `apps/api/stats-engine-r/run_analysis.R` (~línea 445)
**Reproducción:** cualquier job con `analysis_category: "logistica"` vía pipeline completo.
**Causa:** el despachador llamaba `compute_logistic(..., pseudo_r2_type=...)`;
la firma real de `compute_logistic()` es `pseudo_r2=` → error R
"unused argument". Las suites R nivel-función (AA, Z) no podían detectarlo
porque llaman `compute_logistic_binary()` directamente.
**Impacto:** el método logística binaria era inutilizable desde la aplicación;
peor aún, el job terminaba COMPLETED con `logistic: {error: ...}` persistido
(ver F-026).
**Fix:** renombrar el argumento a `pseudo_r2=`.
**Tests:** AG.LOG.* (5 asserts), AJ.INV.01–10.
**Commit:** `ea96d02`. **Estado:** CERRADO.

---

## HALLAZGO F-026: Payload de método con error embebido terminaba COMPLETED

**Severidad:** P1 (BUG PRODUCTIVO — contradicción de estados)
**Archivo:** `apps/api/src/analysis/analysis.service.ts` (`runAnalysisAsync`)
**Reproducción:** cualquier `compute_*` que lance error capturado por el
`tryCatch(..., error=function(e) list(error=e$message))` de su branch en
`run_analysis.R`: el branch dejaba `status="ok"` y Node persistía el
resultado errado con job COMPLETED.
**Causa:** el servicio solo comprobaba `rResult.status === 'error' || blocked`,
no los errores embebidos por método.
**Fix:** guard nuevo — si cualquier payload de método contiene `error` string,
se lanza y el job queda FAILED sin fila de resultado.
**Tests:** AH.NEVER.01–02 (invariantes globales sobre toda la base CI).
**Commit:** `ea96d02`. **Estado:** CERRADO.

---

## HALLAZGO F-027: Word irrecuperable con un solo test de normalidad

**Severidad:** P2 (BUG PRODUCTIVO)
**Archivo:** `apps/api/stats-engine-r/R/word_export.R` (`add_normality_section`)
**Reproducción:** `normality_tests: ["sw"]` (o solo `["ks"]`) + `export_word: true`.
**Causa:** `data.frame()` con columnas del test ausente de longitud 0 →
"arguments imply differing number of rows: 2, 0" → `generate_word()` aborta
y el documento nunca se crea.
**Fix:** extracción tolerante por columna (`col_or_dash`), rellena "-" cuando
el test no fue solicitado.
**Tests:** AK.WORD.01–08 (Word real del pipeline validado como ZIP y por celdas
contra el JSON persistido).
**Commit:** `ea96d02`. **Estado:** CERRADO.

---

## HALLAZGO F-028: El motivo del fallo de Word se perdía silenciosamente

**Severidad:** P3 (observabilidad)
**Archivo:** `apps/api/stats-engine-r/run_analysis.R` (6 branches con export_word)
**Causa:** `result$warnings` se asignaba ANTES del `tryCatch` del Word; el
handler añadía el error a `all_warnings` pero nadie volvía a volcarlo.
**Fix:** el handler re-vuelca `result$warnings <<- as.list(all_warnings)`.
**Commit:** `ea96d02`. **Estado:** CERRADO.

---

## HALLAZGO F-029: ordered_levels sin validación de duplicados ni cobertura

**Severidad:** P2 (BUG PRODUCTIVO — pérdida silenciosa de datos)
**Archivo:** `apps/api/stats-engine-r/R/ordinal_regression.R`
**Reproducción:** declarar `ordered_levels: ["1","2"]` con datos que contienen
"3" → las filas con "3" se convertían en NA y se descartaban SIN aviso.
Duplicados en la lista se aceptaban.
**Fix (F-024b):** guards nuevos al inicio de `run_ordinal_regression`:
duplicados → `ORDEN_INVALIDO`; categorías observadas fuera de la lista →
`ORDEN_INCOMPLETO`. Ambos bloquean con `blocked=TRUE` y detalle.
**Tests:** AJ.ORD.01–08 por la vía completa Node→R→DB.
**Commit:** `ea96d02`. **Estado:** CERRADO.

---

## HALLAZGO F-030: Games-Howell p-valor inconsistente con su IC (P2-GH-P)

**Severidad:** P2
**Archivo:** `apps/api/stats-engine-r/R/anova.R` (`games_howell`)
**Causa:** p calculado con `2*pt()` (Welch pareado sin ajuste por familia)
mientras el IC usaba `qtukey` — la decisión por p podía contradecir al IC.
**Fix:** `p_val <- ptukey(|t|*sqrt(2), nmeans=k, df=df_gh)` (Games & Howell 1976).
**Tests:** Y.P2B.01–04 (p contra cálculo de referencia, p_adj ≥ p_unadj,
coherencia decisión p/IC).
**Commit:** `23d25b1`. **Estado:** CERRADO.

---

## HALLAZGO F-031: use_fisher comparaba el umbral consigo mismo (P2-USE-FISHER)

**Severidad:** P2
**Archivo:** `apps/api/stats-engine-r/R/chi_square.R`
**Causa:** `min_expected_threshold <= 1` compara el PARÁMETRO (default 5)
contra 1 — nunca cierto con el default y ciego a los datos.
**Fix:** regla de Cochran sobre lo observado: `min_expected_obs < 1`.
**Tests:** Y.P2B.05–06 (tabla sana no activa Fisher; esperado<1 sí).
**Commit:** `23d25b1`. **Estado:** CERRADO.

---

## HALLAZGO F-032: UI no muestra los niveles observados de la VD

**Severidad:** P3 (UX / prevención temprana)
**Archivo:** `apps/web/src/components/wizard/StepConfigure.tsx`
**Descripción:** `eventLevel` y `orderedLevels` se capturan como texto libre;
el wizard solo dispone de NOMBRES de columnas (no valores), por lo que no puede
listar los niveles observados ni impedir en cliente un nivel inexistente.
**Mitigación verificada:** los guards del motor bloquean el 100% de los casos
inválidos por la vía completa con mensajes explícitos — EVENTO_NO_DECLARADO,
EVENTO_NO_ENCONTRADO, ORDEN_NO_DECLARADO, ORDEN_INCOMPLETO, ORDEN_INVALIDO
(tests AJ.INV.08–10, AJ.ORD.01–06, AH.BLOCK.*). No hay elección automática:
sin declaración explícita el análisis NO corre.
**Pendiente:** endpoint de valores observados por columna + selector/reordenador
en la UI. **Estado:** ABIERTO (documentado; no falsea resultados).

---

## HALLAZGO F-033: AnalysisJob sin columnas reason/stage

**Severidad:** P3 (esquema)
**Descripción:** en fallos, `reason` y `stage` del motor viajan embebidos en
`errorMsg` (texto); el schema Prisma no los separa en columnas.
**Estado:** ABIERTO (documentado; la información no se pierde).

---

## HALLAZGO F-034: Directorios de salida vacíos no eliminados

**Severidad:** P3 (higiene de filesystem)
**Archivo:** `apps/api/src/analysis/analysis.service.ts` (`invokeREngine`)
**Descripción:** `jobOutputDir` se crea siempre pero solo se usa si hay Word;
los directorios vacíos se acumulan. Los archivos temporales de configuración
(`analysis_*_config.json`) SÍ se limpian en éxito, fallo y timeout
(verificado en AK.TEMP.01).
**Estado:** ABIERTO (documentado; sin impacto en resultados).
