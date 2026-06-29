# 06 — CHANGELOG DE AUDITORÍA
## ResearchOS / CanchariOS — Rama `claude/cancharios-stats-audit-0pnx4q`

Este archivo registra ÚNICAMENTE cambios realizados al código como parte de la auditoría. No se incluyen cambios previos.

---

## [2026-06-28] — Fase 0: Inspección inicial (solo lectura)

### Sin modificaciones al código

Archivos leídos durante la inspección inicial:
- `package.json` (raíz)
- `apps/web/package.json`
- `apps/api/stats-engine-r/install_packages.R`
- `apps/api/stats-engine-r/run_analysis.R` (944 líneas)
- `apps/api/stats-engine-r/pls_sem_engine.R` (952 líneas)
- `apps/api/stats-engine-r/pls_word_wrapper.R`
- `apps/api/stats-engine-r/R/helpers.R`
- `apps/api/stats-engine-r/R/statistics.R`
- `apps/api/stats-engine-r/R/data_cleaning.R`
- `apps/api/stats-engine-r/R/word_export.R` (1285 líneas)
- `apps/api/stats-engine-r/R/t_test.R`
- `apps/api/stats-engine-r/R/anova.R`
- `apps/api/stats-engine-r/R/regression.R`
- `apps/api/stats-engine-r/R/logistic.R`
- `apps/api/stats-engine-r/R/logistic_multinomial.R`
- `apps/api/stats-engine-r/R/chi_square.R`
- `apps/api/stats-engine-r/R/instruments.R`
- `apps/api/stats-engine-r/R/ordinal_regression.R`
- `apps/api/stats-engine-r/R/hierarchical_regression.R`
- `apps/api/stats-engine-r/R/ancova.R`
- `apps/api/stats-engine-r/R/discriminant.R`
- `apps/api/stats-engine-r/R/cluster.R`
- `apps/api/stats-engine-r/R/frequencies.R`
- `apps/api/stats-engine-r/R/cronbach_only.R`
- `apps/api/stats-engine-r/R/baremos_only.R`
- `apps/api/stats-engine-r/R/descriptives_full.R`
- `apps/api/stats-engine-r/R/analisis_descriptivo.R`
- `apps/api/src/analysis/analysis.service.ts`
- `apps/api/src/analysis/analysis.controller.ts`
- `apps/api/prisma/schema.prisma`
- `apps/api/Dockerfile`
- `apps/web/src/lib/methodRecommendation.ts`
- `tests/validate_mtcars.R`

### Archivos creados (documentación de auditoría)
- `AUDIT/00_SYSTEM_INVENTORY.md` — Inventario completo del sistema
- `AUDIT/01_METHODS_MATRIX.md` — Matriz de 18 métodos estadísticos
- `AUDIT/02_RISK_REGISTER.md` — 23 hallazgos clasificados P0-P3
- `AUDIT/03_TEST_PLAN.md` — Plan de pruebas (35 casos propuestos)
- `AUDIT/04_STATISTICAL_REFERENCES.md` — Referencias verificadas en código
- `AUDIT/05_FINDINGS.md` — Hallazgos detallados con evidencia de código
- `AUDIT/06_CHANGELOG.md` — Este archivo
- `AUDIT/07_VALIDATION_RESULTS.md` — (creado, pendiente de ejecución de pruebas)
- `AUDIT/08_FINAL_READINESS_REPORT.md` — (creado, en estado IN PROGRESS)

---

## [2026-06-28] — Lote 1: Guards de contención P0/P1 + pruebas de reproducción

### Archivos creados
- `tests/reproduce_scientific_bugs.R` — 15 pruebas que documentan los 5 problemas científicos y verifican que los guards funcionan (F-005, F-006, F-007, ordinal, PLS single-item)

### Correcciones aplicadas (guards, sin reescritura de algoritmos)

#### F-007 — Guard en logistic.R (bloqueado, no solo advertencia)
**Archivo:** `apps/api/stats-engine-r/R/logistic.R`  
**Líneas:** 84-107 (reemplazó líneas 84-87)  
**Cambio:** Eliminada binarización silenciosa por mediana. La función ahora:
- Cuenta valores únicos de y. Si ≠ 2 → `return(list(blocked=TRUE, reason="VD_NO_BINARIA", error=...))`.
- Si exactamente 2 valores (no {0,1}) → recodifica a 0/1 sin cambiar cuál es evento/referencia.
- `error=` contiene mensaje metodológico descriptivo para el usuario.

#### F-005 — Guard en run_analysis.R (bloque chi-cuadrado)
**Archivo:** `apps/api/stats-engine-r/run_analysis.R`  
**Líneas:** 725-750 (reemplazó líneas 725-731)  
**Cambio:** Eliminada tricotomización con `cut(breaks=3)`. La función ahora:
- Mueve la definición de `group_var`/`has_grp` antes del guard.
- Detecta variables continuas: >10 valores únicos O con decimales.
- Si var_a o var_b (cuando no hay group_var) son continuas → `return(result)` con `blocked=TRUE, reason="VARIABLES_CONTINUAS"`.
- Si pasan el guard → usa las variables tal como están en los datos (como factor).

#### Guard ordinal — ordinal_regression.R
**Archivo:** `apps/api/stats-engine-r/R/ordinal_regression.R`  
**Líneas:** 9-26 (insertadas después de score_b)  
**Cambio:** Antes de la tricotomización con `cuts <- switch(...)`, se detecta si score_b es continua (>10 valores únicos o con decimales). Si es continua → `return(list(blocked=TRUE, reason="VD_CONTINUA", error=...))`.

#### Guard PLS single-item — pls_sem_engine.R
**Archivo:** `apps/api/stats-engine-r/R/pls_sem_engine.R`  
**Líneas:** 786-810 (reemplazó líneas 786-791)  
**Cambio:** Eliminada duplicación con jitter (`avail[1]__dup__`). Antes del loop de construcción de modelos, se detectan todos los constructos con un solo indicador disponible. Si hay alguno → `return(list(blocked=TRUE, reason="SINGLE_ITEM_CONSTRUCTS", error=..., single_item_constructs=...))`. El loop ya no contiene código de duplicación.

---

## [2026-06-28] — Lote 1B: Correcciones de contrato R–Node

### Incompatibilidades demostradas y corregidas

#### Contrato 1 — Chi-cuadrado: status="blocked" no activaba flujo de error en Node
**Archivo:** `apps/api/stats-engine-r/run_analysis.R`  
**Problema:** `result$status = "blocked"` + `result$error = ...` → Node NO lanzaba excepción (solo verifica `status === "error"`). El job quedaba COMPLETED con `chi_square: null` y sin mensaje al usuario.  
**Fix:** `status = "error"` + `errors = list(block_msg)`. Los campos `blocked` y `reason` se mantienen para trazabilidad.

#### Contrato 2 — Logística: `result$status = "ok"` incondicional sobreescribía el bloqueo
**Archivo:** `apps/api/stats-engine-r/run_analysis.R`  
**Problema:** Después de `result$logistic <- log_result`, el código siempre ponía `result$status = "ok"`. Job COMPLETED con `logistic: {blocked: true}` pero el frontend renderizaba la sección con campos undefined.  
**Fix:** Check `isTRUE(log_result$blocked)` antes del status assignment. Si blocked → `status = "error"`, `errors = list(...)`, `return(result)`.

#### Contrato 3 — Ordinal: resultado bloqueado never propagaba a result$status
**Archivo:** `apps/api/stats-engine-r/run_analysis.R`  
**Problema:** El bloque ordinal nunca asignaba `result$status`. Con el guard, `result$ordinal_regression = {blocked: true}` pero `result$status = NULL` → Node procesaba como si fuera válido → COMPLETED con sección ordinal renderizando campos undefined.  
**Fix:** Check `isTRUE(result$ordinal_regression$blocked)` después del tryCatch. Si blocked → `status = "error"`, `errors = list(...)`, `return(result)`.

#### Contrato 4 — PLS-SEM: blocked result no era detectado en analysis.service.ts
**Archivo:** `apps/api/src/analysis/analysis.service.ts`  
**Problema:** El flujo PLS no tenía check de `rResult.blocked`. Guardaba job COMPLETED con `interpretations.pls = {blocked: true, ...}`.  
**Fix:** `if (rResult.blocked) throw new Error(rResult.error ?? '...')` al inicio del bloque `if (isPls)`.

#### Fix adicional — Guard ordinal: error de tipo con variables categóricas texto
**Archivos:** `apps/api/stats-engine-r/R/ordinal_regression.R`, `run_analysis.R`  
**Problema:** `abs(score_b_clean - round(score_b_clean))` lanzaba error con vectores character.  
**Fix:** Agregado `is_numeric_b <- is.numeric(score_b_clean)` y condición `if (is_numeric_b && (...))`.

#### Fix adicional — tests/reproduce_scientific_bugs.R: ruta PLS incorrecta
**Archivo:** `tests/reproduce_scientific_bugs.R`  
**Problema:** `pls_path = file.path(r_dir, "..", "pls_sem_engine.R")` → ruta errónea (archivo está en R/, no en el padre).  
**Fix:** `pls_path = file.path(r_dir, "pls_sem_engine.R")`.

---

## [2026-06-28] — Lote 1C: GitHub Actions para ejecución real de pruebas

### Archivos creados

#### `.github/workflows/scientific-audit-r.yml`
**Disparadores:** `workflow_dispatch`, push a `claude/cancharios-stats-audit-0pnx4q`, `pull_request` a main (sin deploy).  
**Job:** `scientific-audit` — R 4.3.2, `ubuntu-latest`, `r-lib/actions/setup-r@v2` con RSPM binario.  
**Pasos:**
- Setup R + cache de paquetes (`actions/cache@v4`, clave `r-4.3.2-audit-v1-*`)
- Instalación: MASS, nnet, jsonlite, dplyr, openxlsx, **seminr**
- **[A]** Parse checks en 4 archivos modificados (logistic.R, ordinal_regression.R, pls_sem_engine.R, run_analysis.R)
- **[B]** `Rscript tests/reproduce_scientific_bugs.R` — 15 tests del Lote 1
- **[C]** Guard logístico: 5 casos lógicos + 7 de integración (válidos e inválidos)
- **[D]** Guard ordinal: 6 casos lógicos + 6 de integración (con MASS)
- **[E]** Guard chi-cuadrado: 5 casos lógicos + 4 verificaciones de código fuente
- **[F]** Guard PLS: 4 casos lógicos + 3 fuente + 4 de integración (con seminr)
- Cada paso B-F: `if: always()` — garantiza ejecución aunque un paso anterior falle
- Ningún paso crítico tiene `continue-on-error: true`
- Artefactos: `audit-output/*.txt` + `session_info.txt` + `audit_summary.md` (90 días)

#### `tests/audit_guards_comprehensive.R`
**Uso:** `Rscript tests/audit_guards_comprehensive.R [C|D|E|F|all]`  
**Cobertura:**
- **C** (logístico): is_binary lógico + `compute_logistic()` con {continua, 3-cat, valor-único, {0,1}, {1,2}}
- **D** (ordinal): is_continuous_vd lógico + `run_ordinal_regression()` con {continua, decimal, Likert-3, Likert-5, texto}
- **E** (chi-cuadrado): `is_continuous_score` lógico + verificación de código fuente en run_analysis.R
- **F** (PLS): logic guard + fuente (__dup__ eliminado) + `run_pls_sem()` con {single-item, 2-item constructs}
- Documenta F-021 (falso positivo >10 enteros) y F-022 (Likert-15 enteros) como NOTEs en la salida

---

## [2026-06-28] — Lote 1C: Cierre forense (run 28326935493)

### Ejecución real confirmada

**Run ID:** 28326935493  
**Commit:** f2ae524  
**Rama:** `claude/cancharios-stats-audit-0pnx4q`  
**Estado global CI:** Success (1m 37s)  
**R:** 4.3.2 | Paquetes: MASS 7.3.60, nnet 7.3.19, jsonlite 2.0.0, dplyr 1.2.1, openxlsx 4.2.8.1, seminr 2.5.0

### Resultados por paso

| Paso | PASS | FAIL | SKIP | NO EXEC |
|------|------|------|------|---------|
| A — Parse 4 archivos | 4 | 0 | 0 | 0 |
| B — reproduce_scientific_bugs.R | 16 | 3 | 1 | 0 |
| C — Guard logístico | 5 | 0 | 0 | 7 |
| D — Guard ordinal | 8 | 3 | 0 | 0 |
| E — Guard chi-cuadrado | 8 | 1 | 0 | 0 |
| F — Guard PLS-SEM | 7 | 0 | 0 | 4 |
| **TOTAL** | **48** | **7** | **1** | **11** |

### Defectos de infraestructura de pruebas registrados

| ID | Defecto | Impacto |
|----|---------|---------|
| DEF-T01 | `new.env(parent=baseenv())` excluye paquete stats — na.omit no encontrado | C.I1-7, B.F-007.I, B.ORDINAL.I1-2, D.I1-2 no verificados |
| DEF-T02 | pls_sem_engine.R en modo non-interactive llama `quit(status=1)` al ser sourced | F.PKG, F.I1-F.I3 no ejecutados |
| DEF-T03 | Workflow sin `-o pipefail` — exit code de Rscript no propagado por tee | Pasos B/D/E reportan success con fallos internos |
| DEF-T04 | Regex E.SRC4 demasiado amplio — coincide con líneas ANOVA (290/345, F-002) | E.SRC4 false fail; guard chi-cuadrado SÍ es correcto |

### Advertencia P3 técnico
- Node.js 20 deprecation warning en GitHub Actions — no es fallo científico. Node 20 en LTS activo (EOL oct 2026).

### Dictamen
**VALIDADO CON RESTRICCIONES** — Guards P0/P1 tienen lógica correcta y están presentes en código fuente. Integración real no verificada por DEF-T01/T02. Ver 07_VALIDATION_RESULTS.md para detalle completo.

### Archivos modificados
- `AUDIT/07_VALIDATION_RESULTS.md` — resultados forenses completos, tabla por paso, defectos registrados, dictamen

---

## [2026-06-28] — Lote 1D: Reparación de infraestructura de pruebas

### Motivación
El dictamen "VALIDADO CON RESTRICCIONES" del Lote 1C fue rechazado. Con 7 FAIL, 11 NO EJECUTADOS, y un workflow que aparecía verde pese a fallos internos, el dictamen correcto era NO VALIDADO. El Lote 1D repara los 4 defectos de infraestructura y añade casos válidos obligatorios.

### DEF-T03 — Propagación de exit code en workflow
**Archivo:** `.github/workflows/scientific-audit-r.yml`  
**Cambios:**
- Añadido `shell: bash` a todos los pasos críticos (A–F) y pasos de soporte
- Añadido `set -euo pipefail` al inicio de cada bloque `run:` crítico
- Añadido paso `[VERIFY]` que usa `PIPESTATUS` para confirmar explícitamente que `Rscript exit(1)` se propaga a través del pipe; falla el step si pipefail no funciona
- Clave de caché cambiada de `audit-v1` a `audit-v2` para forzar reinstalación limpia de paquetes
- URL RSPM actualizada de `jammy` a `noble` (ubuntu-latest usa noble desde 2024)
- Resumen markdown incluye paso VERIFY

### DEF-T01 — Entorno aislado excluye paquete stats
**Archivos:** `tests/audit_guards_comprehensive.R` (3 instancias), `tests/reproduce_scientific_bugs.R` (2 instancias)  
**Cambio:** `new.env(parent=baseenv())` → `new.env(parent=globalenv())`  
**Justificación:** En producción R carga stats por defecto. `parent=globalenv()` replica la cadena de herencia correcta. `parent=baseenv()` excluía stats, causando `could not find function 'na.omit'` en logistic.R y ordinal_regression.R.  
**Tests desbloqueados:** C.I1-I7, D.I1-I6, B.F-007.I1-I5, B.ORDINAL.I1-I4, F.PKG, F.I1-F.I3

### DEF-T02 — pls_sem_engine.R llama quit() al ser sourced
**Archivo:** `apps/api/stats-engine-r/R/pls_sem_engine.R`  
**Cambio:** Añadida función `.pls_sem_is_main()` que verifica si el script es el archivo principal invocado por Rscript. El bloque CLI (con `quit()`) ahora se protege con `if (!interactive() && .pls_sem_is_main())` en lugar de solo `if (!interactive())`.  
**Efecto:** Al hacer `source("pls_sem_engine.R")` desde tests, el bloque CLI no se ejecuta → R no termina → F.PKG e F.I1-I3 pueden ejecutarse.  
**Producción intacta:** `Rscript pls_sem_engine.R '{"json":...}'` sigue activando el bloque CLI normalmente.

### DEF-T04 — E.SRC4 regex demasiado amplio
**Archivo:** `tests/audit_guards_comprehensive.R` (sección E)  
**Cambio:** E.SRC4 (texto puro, global) reemplazado por:
- Tests conductuales E.I1-E.I4 (evidencia principal): chi-cuadrado real con {M,F}×{A,B,C} → estadístico/p/tabla finitos; guard confirma que continua es detectada antes de chisq.test
- E.SRC4 convertido a check acotado: busca `cut(breaks=3)` solo dentro de ±80 líneas de `VARIABLES_CONTINUAS`, distinguiendo del código ANOVA (F-002) a ~445 líneas de distancia

### F-006.2 — Expectativa incorrecta sobre manifestación del bug
**Archivo:** `tests/reproduce_scientific_bugs.R`  
**Cambio:** `isTRUE(df_buggy[1, "c2"] == 100)` → `is.na(df_buggy[1, "c2"])`  
**Explicación:** La imputation vectorizada buggy deja c2[1] como NA (no imputado), no con el valor 100 (que sería la media equivocada). El bug es igualmente grave — solo se manifestaba de forma diferente a lo documentado originalmente. La nueva expectativa es correcta y el test pasa → documenta el bug fielmente.

### Casos válidos añadidos (obligatorios según especificación Lote 1D)
- **C.I6b**: VD {0,1} → coeficientes finitos (ningún NaN/Inf)
- **C.I7b**: VD {1,2} recodificada → modelo estima coeficientes
- **D.I4b**: Likert {1,2,3} → resultado sin campo `$error`
- **D.I5b**: Likert {1,2,3,4,5} → resultado sin campo `$error`
- **E.I1-E.I4**: chi-cuadrado conductual con datos reales (estadístico finito, p∈[0,1], tabla 2×3, guard detecta continua)
- **F.I3b**: 2-item valid → `success=TRUE` o tiene `path_coefficients`/`tables`
- **F.I3c**: 2-item valid → sin NaN/Inf en valores numéricos
- **ORDINAL.I4**: VD ordinal {1,2,3} → resultado sin `$error`
- **F-007.I5**: VD binaria {0,1} → coeficientes finitos en modulo real

### Archivos modificados
- `apps/api/stats-engine-r/R/pls_sem_engine.R` (guard is_main_script)
- `tests/reproduce_scientific_bugs.R` (DEF-T01 ×2, F-006.2, F-007.I5, ORDINAL.I4)
- `tests/audit_guards_comprehensive.R` (DEF-T01 ×3, DEF-T04, casos válidos)
- `.github/workflows/scientific-audit-r.yml` (DEF-T03, paso VERIFY, noble RSPM)
- `AUDIT/07_VALIDATION_RESULTS.md` (corrección dictamen + sección Lote 1D)

---

## [2026-06-28] — Lote 1E: Reparación de infraestructura CI, corrección de tests mal formulados, investigación Likert-3

### Motivación
El dictamen del Lote 1D fue NO VALIDADO (run 28334118789): VERIFY falló con PIPESTATUS[1] unbound (exit 1); Paso A fue SKIPPED (sin `if: always()`); Resumen abortó con `ls` exit 2 (sin `|| true`); F-007.I5 y C.I6b fallaron por test mal formulado (unlist en lista mixta).

### Infraestructura CI — `.github/workflows/scientific-audit-r.yml`

#### [VERIFY] — Captura atómica de PIPESTATUS
**Problema:** `RSCRIPT_RC=${PIPESTATUS[0]}` luego `TEE_RC=${PIPESTATUS[1]}` — la primera asignación reseteaba PIPESTATUS a `(0)`, dejando PIPESTATUS[1] unbound bajo `set -u` → exit 1.  
**Fix aplicado en Lote 1D:** `set +e; pipeline | tee; _ps=("${PIPESTATUS[@]}"); set -e; rscript_rc="${_ps[0]:-999}"; tee_rc="${_ps[1]:-999}"`; verifica ambos valores explícitamente.

#### [A] — `if: always()` añadido al Paso A
**Problema:** Sin `if: always()`, el Paso A era SKIPPED cuando VERIFY fallaba.  
**Fix:** Añadido `if: always()` al paso `[A] Parse checks`.

#### Resumen — `|| true` en búsqueda `ls` con glob
**Problema:** `fmatch=$(ls audit-output/${paso}-*.txt 2>/dev/null | head -1)` — cuando el archivo no existe, bash pasa el glob literal a `ls`, que devuelve exit 2. Con `set -e` activo en el shell de GitHub Actions, el script abortaba en la primera iteración (paso=A, skipped).  
**Fix:** `fmatch=$(ls audit-output/${paso}-*.txt 2>/dev/null | head -1 || true)` — captura solo errores de búsqueda donde resultado vacío es válido.

#### Título del resumen actualizado: "Lote 1D" → "Lote 1E"

### Corrección de tests mal formulados

#### F-007.I5 — `tests/reproduce_scientific_bugs.R`
**Problema:** `all(is.finite(as.numeric(unlist(res_bin$coefficients))))` — `compute_logistic_binary` devuelve `$coefficients` como **lista de listas** con campos mixtos (`term`=char, `p_apa`=char, `significant`=logical). `unlist()` coerciona todo a character → `as.numeric()` devuelve NA → `is.finite(NA)` = FALSE → test FAIL.  
**Clasificación:** ERROR DE TEST (la estructura lista-de-listas es el contrato correcto de la función).  
**Fix:** Extraer campos estadísticos numéricos por nombre (`B`, `SE`, `Wald`, `p`, `OR`, `OR_ci_lower`, `OR_ci_upper`) usando `lapply(coefs, function(row) row[intersect(numeric_fields, names(row))])`. No se usan `Filter(is.numeric, unlist(...))`.  
**Añadido F-007.I6:** JSON roundtrip — `toJSON()` + `fromJSON(simplifyDataFrame=TRUE)` convierte la lista-de-listas en data.frame; `vapply(coef_df, is.numeric, logical(1))` selecciona columnas numéricas; verifica que todos los valores sean finitos.

#### C.I6b — `tests/audit_guards_comprehensive.R`
**Problema:** Mismo error que F-007.I5 — `unlist()` de lista mixta.  
**Fix:** Misma extracción por nombre de campos. **Añadidos** C.I6c (B finita), C.I6d (SE≥0), C.I6e (OR>0), C.I6f (p∈[0,1]), C.I6g (IC lower≤upper), C.I6h (JSON roundtrip con vapply).

### Investigación D.I4b — 5 escenarios Likert-3 con seed explícita

**Escenario ESC1** (n=120, seed=42, balanceado): Control positivo — n grande reduce probabilidad de cuantiles duplicados.  
**Escenario ESC2** (n=90, seed=7, prob=c(0.30,0.40,0.30)): Desbalanceado pero con ≥20 en cada categoría.  
**Escenario ESC3** (n=60, seed=7): Replica condiciones exactas de D.I4b — documenta si el fallo es reproducible con la seed del test original.  
**Escenario ESC4** (n=60, seed=123, prob=c(0.05,0.90,0.05)): Separación intencional — cat1 y cat3 muy poco frecuentes.  
**Escenario ESC5** (n=60, seed=42, Likert-5): Control positivo — 5 categorías evitan cuantiles duplicados.

**Clasificación D.I4b:** BUG PRODUCTIVO + MANEJO DE ERRORES DEFICIENTE  
- `run_ordinal_regression` aplica `quantile(probs=c(1/3,2/3))` a datos Likert-3. Con distribuciones donde cat1 y cat3 tienen pocas observaciones, ambos cuantiles colapsan al valor 2 → `cut(breaks=c(-Inf,2,2,Inf))` → "some 'breaks' are not distinct".  
- El `tryCatch` externo captura silenciosamente → `list(error=e$message)` sin `$blocked=TRUE` ni `$reason` → el contrato R-Node no puede propagar el error correctamente.  
- **Nota:** No se modifica `ordinal_regression.R` en este lote (autorización explícita del usuario).

### Validación CLI de pls_sem_engine.R — `tests/audit_guards_comprehensive.R` sección F.CLI

Añadidos tests F.CLI1-F.CLI6 usando `system2(Sys.which("Rscript"), ...)`:
- F.CLI1: Sin argumentos → exit code ≠ 0
- F.CLI2: JSON inválido → exit code ≠ 0
- F.CLI3: Params válidos (2-item) → exit 0
- F.CLI4: Params válidos → JSON parseable con `success=TRUE`
- F.CLI5: Single-item → `blocked=TRUE`, `reason=SINGLE_ITEM_CONSTRUCTS` en JSON
- F.CLI6: Ninguna salida contiene `__dup__`

### Archivos modificados
- `.github/workflows/scientific-audit-r.yml` (if:always() en A; `|| true` en Resumen; título Lote 1E)
- `tests/reproduce_scientific_bugs.R` (F-007.I5 fix; F-007.I6 JSON roundtrip añadido)
- `tests/audit_guards_comprehensive.R` (C.I6b fix; C.I6c-C.I6h; 5 escenarios Likert-3; F.CLI1-F.CLI6)
- `AUDIT/06_CHANGELOG.md` — esta entrada
- `AUDIT/07_VALIDATION_RESULTS.md` — sección Lote 1E añadida

---

## [2026-06-29] — Lote 1F: Corrección bug D.I4b + corrección CLI F.CLI3-CLI5

### Motivación
El dictamen del Lote 1E fue NO VALIDADO (run 28335331099): D.I4b BUG PRODUCTIVO confirmado (Likert-3 con cuantiles iguales → error sin $blocked); F.CLI3-CLI5 NUEVA FINDING (invocación CLI con `--vanilla` falla con exit=1 para JSON válido).

### A. Corrección bug D.I4b — `ordinal_regression.R`
**Archivo:** `apps/api/stats-engine-r/R/ordinal_regression.R`  
**Cambio:** Reescritura completa — eliminados `cut()`, `quantile()`, jitter y recategorización artificial.

**Nueva firma:**
```r
run_ordinal_regression(df, var_a_items, var_b_items, var_a_name, var_b_name,
  alpha, link_function, ordinalizacion=NULL, pseudo_r2_type, extra_predictors=NULL,
  ordered_levels=NULL)
```

**6 casos de clasificación de VD (sin recategorización):**
1. `is.ordered(raw_b)` → usar directamente; advertir si hay niveles vacíos (`empty_levels_warning`)
2. `is.factor(raw_b)` sin `ordered_levels` → `ORDEN_NO_DECLARADO`
3. Numérico ≤10 categorías enteras sin `ordered_levels` → `ORDEN_NO_DECLARADO`
4. Numérico >10 únicos O con decimales → `VD_CONTINUA`
5. Numérico <2 valores únicos → `CATEGORIAS_INSUFICIENTES`
6. Character: con `ordered_levels` → OK; sin → `ORDEN_NO_DECLARADO`

**Guards adicionales:** `MUESTRA_INSUFICIENTE` (n<10), `PREDICTOR_CONSTANTE`, `ERROR_INTERNO` (tryCatch externo con `$blocked=TRUE`).

**Advertencias polr capturadas** via `withCallingHandlers(..., warning=...)` — incluidas en `result$warnings`.

**Nuevos campos de salida:** `ordered_levels_used`, `converged`, `warnings`, `empty_levels_warning`, `thresholds`.

### B. Propagación `ordered_levels` — `run_analysis.R`
**Archivo:** `apps/api/stats-engine-r/run_analysis.R`  
**Cambio mínimo compatible:**
- Parámetro `ordered_levels=if(!is.null(config$ordered_levels)) unlist(config$ordered_levels) else NULL` añadido a la llamada de `run_ordinal_regression()`
- `result$reason <- result$ordinal_regression$reason` añadido al bloque de propagación de error bloqueado

### C. Corrección F.CLI3-CLI5 — `tests/audit_guards_comprehensive.R`
**Causa raíz:** `system2(..., args=c("--vanilla", pls_path, json))` usaba `--vanilla`, que impide carga de `.libPaths()` normales → `library(seminr)` falla en el proceso hijo → exit 1 antes de ejecutar el bloque CLI. Los tests F.I3/F.I3b/F.I3c (función directa) pasaban porque `seminr` se cargaba correctamente vía el entorno padre.

**Fix:**
- Eliminado `--vanilla` de todos los `system2()` de la sección F.CLI
- JSON escrito a archivo temporal (`writeLines(json, tmp_json_file)`); ruta pasada como argumento — replica producción NestJS: `spawn(rBin, [plsScriptPath, tmpFile])`
- 6 tests (CLI1-CLI6) expandidos a 14 tests (CLI1-CLI14): grupo validación entrada / grupo archivo JSON / grupo inline JSON / grupo guard single-item / grupo integridad

### D. Actualización `reproduce_scientific_bugs.R`
**Archivo:** `tests/reproduce_scientific_bugs.R`  
**Cambio:** ORDINAL.I3 y ORDINAL.I4 añaden `ordered_levels=c(1,2,3)`. Con nueva implementación, `{1,2,3}` numérico sin `ordered_levels` → `ORDEN_NO_DECLARADO` (comportamiento correcto); con `ordered_levels` → modelo corre sin bloqueo.

### E. Sección D reemplazada — `tests/audit_guards_comprehensive.R`
**Archivo:** `tests/audit_guards_comprehensive.R`  
**Cambio:** Sección D completamente reemplazada con 15 escenarios D.ORD.1–D.ORD.15 (16 checks incluyendo D.ORD.3b):
- a) ordered factor: 3-lvl, 5-lvl, 6-lvl+nivel-vacío, 1-lvl-observado
- b) factor no ordenado: sin/con ordered_levels
- c) numérico pocas cats: sin/con ordered_levels [clave: D.I4b FIX en D.ORD.8]
- d) VD continua → VD_CONTINUA
- e) 1 valor único → CATEGORIAS_INSUFICIENTES
- f) nivel no observado → empty_levels_warning
- g) separación → no bloqueado
- h) predictor constante → PREDICTOR_CONSTANTE
- i) NA en VD → complete cases, OK
- j) NA en predictor → complete cases, OK

### Archivos modificados
- `apps/api/stats-engine-r/R/ordinal_regression.R` (reescritura completa)
- `apps/api/stats-engine-r/run_analysis.R` (ordered_levels + reason propagation)
- `tests/audit_guards_comprehensive.R` (D: 15 escenarios; F.CLI: 14 tests sin --vanilla)
- `tests/reproduce_scientific_bugs.R` (ORDINAL.I3/I4 con ordered_levels)
- `AUDIT/06_CHANGELOG.md` — esta entrada
- `AUDIT/07_VALIDATION_RESULTS.md` — sección Lote 1F añadida

---

## [2026-06-29] — Lote 1G: VD_BINARIA + Instrumentación de etapas + Equivalencia numérica

### Motivación

D.ORD.11 y D.ORD.12 seguían en FAIL tras Lote 1F (commit 90df025, run 28344236585: 109 PASS / 2 FAIL). Ambos devolvían `blocked=TRUE, reason="ERROR_INTERNO"` sin indicar qué etapa falló. Causa raíz: `ordered({A,C})` con 2 categorías observadas después de droplevels → `polr()` u otra etapa fallaba. El tryCatch externo capturaba el error sin diagnóstico.

Lote 1G: (a) implementa VD_BINARIA como regla metodológica oficial (≤2 categorías → bloquear antes de polr); (b) instrumenta etapas individuales con `current_stage`; (c) añade fallback IC de Wald si `confint()` falla; (d) agrega `raw_values` sin redondear; (e) propaga `stage` en run_analysis.R; (f) emite warning de deprecación para `ordinalizacion`.

### A. Reescritura `ordinal_regression.R`

**Archivo:** `apps/api/stats-engine-r/R/ordinal_regression.R`

**VD_BINARIA (nuevo):** En cada rama de clasificación de VD, tras determinar `obs_lvls`, si `length(obs_lvls) == 2` → bloqueo con `reason="VD_BINARIA"`. Se devuelve: `list(blocked=TRUE, reason="VD_BINARIA", stage=current_stage, error="...", details=list(observed_levels=obs_lvls, empty_levels=...))`.

**Etapas instrumentadas (`current_stage`):**
- `"data_prep"` — cálculo de score_a y raw_b
- `"vd_classification"` — construcción del ordered factor y detección obs_lvls
- `"predictor_prep"` — datos, complete.cases, guards muestra/constante
- `"polr_fit"` — MASS::polr()
- `"vcov"` — coef(summary()), vcov(), SE
- `"profile_confint"` — confint() por perfil de verosimilitud
- `"wald_confint"` — fallback IC de Wald desde vcov diagonal
- `"null_model"` — polr(vd ~ 1) para R²
- `"pseudo_r2"` — cálculo de logLik, LR, R² Cox-Snell/McFadden/Nagelkerke
- `"parallel_test"` — test aproximado de líneas paralelas (Brant)
- `"serialization"` — construcción de la lista de retorno

**IC con fallback Wald:** `confint(modelo)` envuelto en `withCallingHandlers+tryCatch`. Si falla → Wald IC desde `vcov(modelo)`. Campo `ci_method = "profile_likelihood" | "wald"` en resultado exitoso.

**`raw_values` (sin redondear):** `coefficients_B`, `thresholds`, `logLik`, `logLik_null`, `AIC_val`, `std_errors` — usados por D.EQ.1-5.

**Deprecación `ordinalizacion`:** `warning(...)` emitido cuando `ordinalizacion` no es NULL.

**Error externo (tryCatch):** Incluye `stage = current_stage` en retorno de error.

### B. Propagación `stage` — `run_analysis.R`

**Archivo:** `apps/api/stats-engine-r/run_analysis.R`  
**Cambio:** `result$stage <- result$ordinal_regression$stage` añadido al bloque de propagación de error bloqueado.

### C. Tests actualizados — `audit_guards_comprehensive.R`

**Archivo:** `tests/audit_guards_comprehensive.R`  
**Cambios:**
- `%||%` definido globalmente (disponible en todas las secciones)
- D.ORD.11: expectativa cambiada de `empty_levels_warning` → `blocked=TRUE, reason="VD_BINARIA"`. DIAG block añadido.
- D.ORD.12: expectativa cambiada de `!blocked` → `blocked=TRUE, reason="VD_BINARIA"`
- D.ORD.12b/c/d: 3 nuevos casos binarios (balanceado, desbalanceado, separación perfecta) — todos esperan VD_BINARIA
- D.EQ.1-5: 5 tests de equivalencia numérica vs MASS::polr() directo (tolerancias: coef/thresh/logLik/AIC abs≤1e-8; SE rel≤1e-6; n exacto)

### Archivos modificados
- `apps/api/stats-engine-r/R/ordinal_regression.R` (Lote 1G reescritura)
- `apps/api/stats-engine-r/run_analysis.R` (stage propagation)
- `tests/audit_guards_comprehensive.R` (D.ORD.11/12 + nuevos tests)
- `AUDIT/06_CHANGELOG.md` — esta entrada
- `AUDIT/07_VALIDATION_RESULTS.md` — sección Lote 1G añadida

---

## [2026-06-29] — Lote 2A: F-006 Corrección imputación column-mean en instruments.R

### Motivación

F-006 identificado en Lote 1C (Registro de riesgos P1): la función `compute_instruments()` en `instruments.R` línea 342 usaba imputación vectorizada incorrecta. Tras Lote 1G (cerrado, VALIDADO), autorización para atacar F-006 exclusivamente.

**Causa raíz (F-006):** La expresión `apply(df, 2, mean, na.rm=TRUE)[is.na(df)]` indexa un vector de medias de longitud `p` (número de columnas) con una matriz lógica `n×p` que al convertirse a vector lineal tiene longitud `n*p`. Las posiciones de indexación > `p` producen NA. Resultado: solo las primeras `p` posiciones en columna 1 del dataframe reciben un valor (generalmente incorrecto), mientras el resto permanece NA.

**Consecuencias documentadas (Datasets A-F):**
- **A** (un NA por columna, posiciones distintas): col1 recibe media correcta; cols 2+ quedan con NA
- **B** (dos NAs en misma columna): segunda NA recibe media de col2, no col1
- **C** (columna toda NA): se propagaba NaN; nueva implementación → COLUMNA_SIN_DATOS
- **D** (columna constante con NA): accidentalmente correcto porque medias col1==col2
- **E** (columna no numérica): NA persistía tras coerción; nuevo código la imputa y registra
- **F** (patrón cruzado): c1[r2] recibía media de col2; c2,c3 quedaban NA

**Impacto en AFE/AFC:** La imputación defectuosa deja casi todos los NAs intactos. `compute_afe()` y `compute_afc()` usan `complete.cases()` internamente: con 5% MCAR, ~46% de filas se descartan (n≈108 de 200); con 10% ~72% (n≈56); con 20% ~93% (n≈14 → error o solución degenerada).

### A. Corrección `instruments.R`

**Archivo:** `apps/api/stats-engine-r/R/instruments.R`  
**Cambio:** Líneas 340-342 reemplazadas. La expresión vectorizada rota sustituida por bucle `for (j in seq_along(data_items))`.

**Lógica nueva:**
1. Antes de `as.numeric()`, se registran `non_numeric_cols` (columnas no numéricas en raw_df).
2. Loop `for (j in seq_along(data_items))` calcula `col_mean` para cada columna.
3. Si `col_mean` es NaN o NA (columna toda-NA), se agrega a `imp_missing_cols`.
4. Si hay columnas en `imp_missing_cols` al salir del loop → retorno inmediato con `blocked=TRUE, reason="COLUMNA_SIN_DATOS"`.
5. En caso normal: `result$imputation` se completa con metadata.

**Metadata de imputación (`result$imputation`):**
```
method                      = "column_mean"
columns                     = character vector: columnas donde se imputó
replaced_counts             = named list: número de NAs reemplazados por columna
replacement_values          = named list: valor utilizado para imputar por columna
all_missing_columns         = character(0) en caso normal; lista de columnas todas-NA en bloqueo
non_numeric_columns_ignored = columnas no numéricas en raw_df antes de coerción
```

**Retorno bloqueado (COLUMNA_SIN_DATOS):**
```r
list(
  status  = "error",
  blocked = TRUE,
  reason  = "COLUMNA_SIN_DATOS",
  error   = "Columna(s) sin datos validos: ...",
  details = list(all_missing_columns = ...),
  imputation = list(...)   # incluye columnas ya procesadas antes del bloqueo
)
```

### B. Tests — `audit_guards_comprehensive.R`

**Archivo:** `tests/audit_guards_comprehensive.R`  
**Cambios:**
- Comentario de uso actualizado (agrega `G`)
- `instruments_path` añadido a bloque de paths
- Nueva función `run_section_g()` añadida
- `if (section %in% c("G", "ALL")) run_section_g()` añadido al dispatcher

**Tests en Sección G (30 checks totales):**

Grupo 1 — Imputación unitaria (Datasets A-F):
- G.IMP.01-02: Dataset A broken: cols 2-3 permanecen NA
- G.IMP.03-05: Dataset A correct: c1=5.5, c2=5.0, c3=4.5
- G.IMP.06: Dataset B broken: c1[r2] recibe media col2 (5.0) en lugar de media col1 (7.0)
- G.IMP.07-08: Dataset B correct: ambas NAs en col1 = 7.0
- G.IMP.09: Dataset C broken: c1[r1] = NaN
- G.IMP.10: Dataset C vía compute_instruments: blocked=TRUE reason=COLUMNA_SIN_DATOS
- G.IMP.11-12: Dataset D: broken y correct dan 5.0 (coinciden; D confirma accidentalidad)
- G.IMP.13-14: Dataset E: broken → NA persiste; correct → c2[r1] = 6.5
- G.IMP.15-20: Dataset F: broken → valores incorrectos/NA; correct → c1=4.0, c2=3.5, c3=7.5

Grupo 2 — Metadata (G.META.01-06):
- method, columns, replaced_counts, replacement_values, all_missing_columns
- non_numeric_columns_ignored con columna carácter

Grupo 3 — Impacto AFE (G.AFE.01-06):
- 5%: broken n<200, correct n=200
- 10%: broken n < correct n
- 20%: broken falla o n << correct; correct n=200
- Tucker CC corrected vs reference ≥ 0.85

Grupo 4 — Impacto AFC (G.AFC.01-03):
- 5%: broken n < correct n
- 20%: broken error (n<30); correct ok (n≥30)

Grupo 5 — Contrato Node-R (G.NR.01-04):
- COLUMNA_SIN_DATOS propagado
- metadata en resultado bloqueado
- sin NaN en resultado normal
- replaced_counts exactos

### Archivos modificados

- `apps/api/stats-engine-r/R/instruments.R` (F-006 fix: loop + COLUMNA_SIN_DATOS + metadata)
- `tests/audit_guards_comprehensive.R` (Sección G: 30 nuevos checks)
- `AUDIT/06_CHANGELOG.md` — esta entrada
- `AUDIT/07_VALIDATION_RESULTS.md` — sección Lote 2A añadida

---

## [RESUELTO] — Lote 2B+ (requiere autorización separada)

- [x] F-002: Eliminado bloque ANOVA duplicado en run_analysis.R — RESUELTO FASE 3A
- [x] F-004: Eliminadas funciones duplicadas de statistics.R — RESUELTO FASE 3A
- [x] F-003: Unificado interpret_r() a escala canónica de 6 niveles — RESUELTO FASE 3A
- [ ] DEF-T01: Corregir `new.env(parent=baseenv())` → `new.env(parent=globalenv())` en tests/audit_guards_comprehensive.R
- [ ] DEF-T02: Corregir integración PLS en tests (evitar trigger standalone de pls_sem_engine.R)
- [ ] DEF-T03: Agregar `set -o pipefail` al workflow o reemplazar patrón `| tee`
- [ ] DEF-T04: Acotar regex E.SRC4 al bloque chi_cuadrado en run_analysis.R
- [ ] F-001: Verificar y corregir compute_omega() (requiere relectura)

---

*Formato: [YYYY-MM-DD] Descripción de cambio — Archivo(s) modificado(s) — Hallazgo(s) corregido(s)*

---

## [2026-06-29] — FASE 3A: Correlación, interpret_r canónico, F-002/F-003/F-004

### Hallazgos corregidos

- **F-002**: Bloque ANOVA duplicado eliminado (`run_analysis.R` líneas 337-392 removed)
- **F-003**: `interpret_r()` sin fallback para r < 0.20 — corregido en `helpers.R`
- **F-004**: Duplicados en `statistics.R` eliminados (`format_r_apa`, `format_p_apa`, `stars_p`, `interpret_r`, `effect_size_label`, `interpret_alpha`)

### Cambios específicos

| Archivo | Cambio |
|---------|--------|
| `apps/api/stats-engine-r/R/helpers.R` | `interpret_r` → escala 6 niveles: despreciable/baja/moderada/alta/muy alta/extremadamente alta |
| `apps/api/stats-engine-r/R/helpers.R` | `interpret_r_full()` nuevo — retorna r, absolute_r, direction, strength, scale, warning |
| `apps/api/stats-engine-r/R/helpers.R` | `interpret_alpha` → 6 niveles con Pobre/Inaceptable |
| `apps/api/stats-engine-r/R/statistics.R` | Eliminados: `interpret_alpha`, `format_r_apa`, `format_p_apa`, `stars_p`, `interpret_r`, `effect_size_label` (duplicados) |
| `apps/api/stats-engine-r/run_analysis.R` | Eliminado segundo bloque `if (analysis_category == "anova")` (código muerto, 56 líneas) |
| `tests/audit_fase3a_correlacion.R` | Nuevo (27 tests: H.F002, H.F003, H.F004, H.COR) |
| `.github/workflows/scientific-audit-r.yml` | Paso H añadido; parse check amplía a helpers.R, statistics.R, audit_fase3a_correlacion.R |

### Tests nuevos (Sección H)

| Grupo | Tests | Descripción |
|-------|-------|-------------|
| H.F003 | 17 | interpret_r canónico — 6 niveles, abs(), fallback completo |
| H.F003 FULL | 8 | interpret_r_full — direction, absolute_r, contextual_warning |
| H.F002 | 1 | Único bloque ANOVA en run_analysis.R |
| H.F004 | 7 | interpret_alpha — 6 niveles incluyendo Pobre/Inaceptable |
| H.COR | 27 | Equivalencia Pearson/Spearman/Kendall vs cor.test(), IC Fisher, casos extremos, n=500, NA, constante |
| **Total** | **60** | |

### CI — FASE 3A (commit c70e325, run 28372915510)

**Commit inicial (c62a034):** Section H fallaba por `library(readxl)` en data_cleaning.R (no necesario) y falta de `nortest` en CI.  
**Commit fix-1 (cb4c1ea8):** Eliminada dependencia data_cleaning.R del test; añadido `nortest` al workflow. Resultado: 51 PASS / 9 FAIL en H (tolerancias `< 1e-12` vs salida redondeada a 4dp/3dp de correlate_pair).  
**Commit fix-2 (c70e325):** Corregidas tolerancias — comparaciones ahora usan `round(ref, ndp) < 1e-12` en lugar de `ref_full_precision < 1e-10`. Resultado: **60 PASS / 0 FAIL / 0 NOTE**.

**Resultado final:** Run 28372915510 — **SUCCESS** — 60/60 PASS en Section H, todas las secciones A-G intactas.

| Sección | Resultado |
|---------|-----------|
| VERIFY | ✅ PASS |
| A — Parse checks (8 archivos) | ✅ PASS |
| B–G — Guards P0/P1 (heredados) | ✅ PASS (159 tests) |
| H — FASE 3A correlación | ✅ 60 PASS / 0 FAIL |

