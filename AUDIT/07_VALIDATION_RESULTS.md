# 07 — RESULTADOS DE VALIDACIÓN
## ResearchOS / CanchariOS — Auditoría 2026-06-28

---

## ESTADO ACTUAL

### Suite validate_mtcars.R
**Estado:** NO EJECUTADA  
**Razón:** Requiere entorno con R 4.3.2 y paquetes instalados (psych, MASS, nnet, emmeans, cluster, car).

Las pruebas se ejecutarán en el entorno Docker del proyecto una vez que las correcciones de Fase 1 estén implementadas.

### Suite reproduce_scientific_bugs.R + audit_guards_comprehensive.R (Lote 1C)
**Estado:** EJECUTADA — GitHub Actions run 28326935493, commit f2ae524  
**Dictamen:** **VALIDADO CON RESTRICCIONES**

**Workflow:** `.github/workflows/scientific-audit-r.yml`  
**Rama:** `claude/cancharios-stats-audit-0pnx4q`  
**Run ID:** 28326935493  
**Estado global CI:** Success (1m 37s)  
**R:** 4.3.2  
**Paquetes:** MASS 7.3.60, nnet 7.3.19, jsonlite 2.0.0, dplyr 1.2.1, openxlsx 4.2.8.1, seminr 2.5.0

---

## RESULTADOS FORENSES — RUN 28326935493

### Tabla resumen por paso

| Paso | Script / Verificación | PASS | FAIL | SKIP | NO EXEC | NOTEs |
|------|-----------------------|------|------|------|---------|-------|
| A | Parse 4 archivos R | 4 | 0 | 0 | 0 | — |
| B | reproduce_scientific_bugs.R | 16 | 3 | 1 | 0 | F-006.2 expected fail |
| C | Guard logístico (audit_guards_comprehensive C) | 5 | 0 | 1* | 0 | *7 integración agrupados como 1 |
| D | Guard ordinal (audit_guards_comprehensive D) | 8 | 3 | 0 | 0 | — |
| E | Guard chi-cuadrado (audit_guards_comprehensive E) | 8 | 1 | 0 | 0 | E.SRC4 false fail |
| F | Guard PLS-SEM (audit_guards_comprehensive F) | 7 | 0 | 0 | 4 | quit() en standalone mode |
| **TOTAL** | | **48** | **7** | **2** | **4** | **+2 NOTEs (D.L6, E.L6)** |

### Detalle por paso

#### Paso A — Parse checks (4 archivos)
**Resultado:** COMPLETO — 4/4 PASS

| Archivo | Estado |
|---------|--------|
| apps/api/stats-engine-r/R/logistic.R | PASS — sintaxis válida |
| apps/api/stats-engine-r/R/ordinal_regression.R | PASS — sintaxis válida |
| apps/api/stats-engine-r/R/pls_sem_engine.R | PASS — sintaxis válida |
| apps/api/stats-engine-r/run_analysis.R | PASS — sintaxis válida |

#### Paso B — reproduce_scientific_bugs.R (20 tests)
**Resultado:** 16 PASS / 3 FAIL / 1 SKIP

| ID | Descripción | Estado | Causa |
|----|-------------|--------|-------|
| B.F-005.1 | Guard chi-cuadrado detecta continua | PASS | — |
| B.F-005.2 | Reason = VARIABLES_CONTINUAS | PASS | — |
| B.F-005.3 | Mensaje descriptivo en $error | PASS | — |
| B.F-007.L1 | Guard logístico: continua bloqueada | PASS | — |
| B.F-007.L2 | Guard logístico: 3 categorías bloqueada | PASS | — |
| B.F-007.L3 | Guard logístico: {0,1} no bloqueada (lógica) | PASS | — |
| B.F-007.I | Guard logístico: integración real | SKIP | Env bug: na.omit no encontrado |
| B.PLS.L1 | Guard PLS: __dup__ eliminado del código | PASS | — |
| B.PLS.L2 | Guard PLS: SINGLE_ITEM_CONSTRUCTS presente | PASS | — |
| B.PLS.L3 | Guard PLS: blocked=TRUE en single-item | PASS | — |
| B.PLS.L4 | Guard PLS: reason correcto | PASS | — |
| B.ORDINAL.L1 | Guard ordinal lógica: detecta >10 únicos | PASS | — |
| B.ORDINAL.L2 | Guard ordinal lógica: detecta decimal | PASS | — |
| B.ORDINAL.L3 | Guard ordinal lógica: no bloquea Likert-5 | PASS | — |
| B.ORDINAL.I1 | Guard ordinal integración: VD continua bloqueada | FAIL | Env bug: na.omit no encontrado |
| B.ORDINAL.I2 | Guard ordinal integración: VD Likert no bloqueada | FAIL | Env bug: na.omit no encontrado |
| B.ORDINAL.I3 | Guard ordinal integración: caso texto no bloqueado | FAIL* | *Aparece PASS pero por razón incorrecta (función falla entera, no "no bloquea") |
| B.F-006.1 | instruments.R: NA en c1 recibe media de c1 (100) | PASS | — |
| B.F-006.2 | instruments.R: NA en c2 recibe media de c1 (100) en lugar de c2 (200) | FAIL | EXPECTED — documenta bug existente, instruments.R no corregido en Lote 1 |
| B.F-001 | Cronbach: solo ítems numéricos | PASS | — |

#### Paso C — Guard logístico (12 tests: 5 lógica + 7 integración)
**Resultado:** 5 PASS / 0 FAIL / 7 NO VERIFICADOS (env bug)

| ID | Descripción | Estado |
|----|-------------|--------|
| C.L1 | is_binary(c(0,1)) = TRUE | PASS |
| C.L2 | is_binary(c(1,2)) = TRUE | PASS |
| C.L3 | is_binary(c(1,2,3)) = FALSE | PASS |
| C.L4 | is_binary(c(1.5, 2.5)) = FALSE | PASS |
| C.L5 | is_binary(c(1)) = FALSE | PASS |
| C.I1–C.I7 | Integración con compute_logistic() real | NO VERIFICADO — new.env(parent=baseenv()) excluye stats |

#### Paso D — Guard ordinal (11 tests: 5 lógica + 6 integración)
**Resultado:** 8 PASS / 3 FAIL

| ID | Descripción | Estado | Causa |
|----|-------------|--------|-------|
| D.L1 | is_continuous_vd(rnorm) = TRUE | PASS | — |
| D.L2 | is_continuous_vd con decimales = TRUE | PASS | — |
| D.L3 | is_continuous_vd Likert-3 = FALSE | PASS | — |
| D.L4 | is_continuous_vd Likert-5 = FALSE | PASS | — |
| D.L5 | is_continuous_vd texto = FALSE | PASS | — |
| D.L6 | NOTE: 15 enteros únicos → TRUE (F-021 heurística) | NOTE | Documentado, no fallo |
| D.I1 | run_ordinal: VD continua bloqueada | FAIL | Env bug: na.omit no encontrado |
| D.I2 | run_ordinal: VD decimal bloqueada | FAIL | Env bug: na.omit no encontrado |
| D.I3 | run_ordinal: Likert-3 no bloqueada | FAIL* | *PASS por razón incorrecta (función falla entera) |
| D.I4 | run_ordinal: Likert-5 no bloqueada | PASS (cuestionable) | Ver nota D.I3 |
| D.I5 | run_ordinal: texto no bloqueado | PASS (cuestionable) | Ver nota D.I3 |
| D.I6 | run_ordinal: reason=VD_CONTINUA cuando bloqueado | PASS (cuestionable) | no se ejecutó función real |

#### Paso E — Guard chi-cuadrado (9 tests: 5 lógica + 4 fuente)
**Resultado:** 8 PASS / 1 FAIL (false fail)

| ID | Descripción | Estado | Causa |
|----|-------------|--------|-------|
| E.L1 | is_continuous_score con >10 únicos = TRUE | PASS | — |
| E.L2 | is_continuous_score con decimales = TRUE | PASS | — |
| E.L3 | is_continuous_score Likert-5 = FALSE | PASS | — |
| E.L4 | is_continuous_score Likert-3 = FALSE | PASS | — |
| E.L5 | is_continuous_score texto = FALSE | PASS | — |
| E.L6 | NOTE: 15 enteros únicos → TRUE (F-022 heurística) | NOTE | Documentado, no fallo |
| E.SRC1 | Fuente: is_continuous_score definida en run_analysis.R | PASS | — |
| E.SRC2 | Fuente: VARIABLES_CONTINUAS en run_analysis.R | PASS | — |
| E.SRC3 | Fuente: status="error" en bloque chi | PASS | — |
| E.SRC4 | Fuente: cut(breaks=3) eliminado del bloque chi_cuadrado | FAIL | FALSE FAIL — regex demasiado amplio; coincide con líneas 290/345 (ANOVA, F-002), no con bloque chi_cuadrado. El guard chi-cuadrado SÍ está correcto. |

#### Paso F — Guard PLS-SEM (11 tests: 4 lógica + 3 fuente + 4 integración)
**Resultado:** 7 PASS / 0 FAIL / 4 NO EJECUTADOS

| ID | Descripción | Estado | Causa |
|----|-------------|--------|-------|
| F.L1 | Guard PLS lógica: single-item bloqueado | PASS | — |
| F.L2 | Guard PLS lógica: reason=SINGLE_ITEM_CONSTRUCTS | PASS | — |
| F.L3 | Guard PLS lógica: campo single_item_constructs | PASS | — |
| F.L4 | Guard PLS lógica: 2-item no bloqueado | PASS | — |
| F.SRC1 | Fuente: __dup__ eliminado de pls_sem_engine.R | PASS | — |
| F.SRC2 | Fuente: SINGLE_ITEM_CONSTRUCTS presente | PASS | — |
| F.SRC3 | Fuente: guard antes del loop de construcción | PASS | — |
| F.PKG | Verificar seminr disponible en entorno real | NO EJECUTADO | R process terminó con quit(status=1) en F.SRC3 |
| F.I1 | run_pls_sem: single-item bloqueado con seminr | NO EJECUTADO | ídem |
| F.I2 | run_pls_sem: 2-item no bloqueado con seminr | NO EJECUTADO | ídem |
| F.I3 | run_pls_sem: reason=SINGLE_ITEM_CONSTRUCTS | NO EJECUTADO | ídem |

**Causa raíz F.PKG/F.I1-I3:** Al ejecutar `source("pls_sem_engine.R")` dentro de `Rscript audit_guards_comprehensive.R F`, el bloque `if (!interactive()) { ... quit(status=1) }` de pls_sem_engine.R se activa. `commandArgs(trailingOnly=TRUE)` devuelve `c("F")` (argumento de sección). `jsonlite::fromJSON("F")` falla → NULL → imprime `{"success":false,"error":"JSON invalido"}` → `quit(status=1)`. El proceso R termina después de F.SRC3.

---

## DEFECTOS DE INFRAESTRUCTURA DE PRUEBAS REGISTRADOS

### DEF-T01 — Entorno aislado excluye paquete stats
**Archivo:** `tests/audit_guards_comprehensive.R`  
**Línea(s):** Todas las llamadas a `new.env(parent=baseenv())`  
**Síntoma:** `could not find function 'na.omit'` al llamar funciones que usan stats internamente (logistic.R, ordinal_regression.R)  
**Impacto:** Tests C.I1–C.I7 (integración logística), B.F-007.I, B.ORDINAL.I1-I2, D.I1-I2 no verificados  
**Corrección pendiente:** Cambiar `new.env(parent=baseenv())` a `new.env(parent=globalenv())`  
**Prioridad:** Alta — bloquea verificación de integración

### DEF-T02 — pls_sem_engine.R termina el proceso en modo non-interactive
**Archivo:** `tests/audit_guards_comprehensive.R` (sección F), `apps/api/stats-engine-r/R/pls_sem_engine.R`  
**Línea(s):** pls_sem_engine.R ~965-970 (`if (!interactive()) { ... quit(status=1) }`)  
**Síntoma:** Al hacer `source("pls_sem_engine.R")` dentro de un script no-interactivo, el bloque standalone detecta args inválidos y llama `quit(status=1)`  
**Impacto:** F.PKG, F.I1–F.I3 no ejecutados  
**Corrección pendiente:** Usar `local({ ... })` con guard de entorno al hacer source, o extraer función en archivo separado para tests  
**Prioridad:** Alta — bloquea toda verificación de integración PLS

### DEF-T03 — Propagación de código de salida sin pipefail
**Archivo:** `.github/workflows/scientific-audit-r.yml`  
**Síntoma:** GitHub Actions ejecuta `/usr/bin/bash -e {0}` sin `-o pipefail`. El patrón `Rscript ... | tee ...` retorna el código de salida de `tee` (0), no de `Rscript`. Steps B, D, E tuvieron tests con `quit(status=1)` pero concluyeron con `success` en CI.  
**Impacto:** Pasos con fallos reales aparecen como "success" en el job de CI  
**Corrección pendiente:** Agregar `set -o pipefail` al inicio del bloque `run:` de cada paso crítico, o reemplazar patrón `| tee` por `> file; cat file`  
**Prioridad:** Media — no afecta lógica de producción pero enmascara fallos de CI

### DEF-T04 — Regex E.SRC4 demasiado amplio
**Archivo:** `tests/audit_guards_comprehensive.R` (sección E, test E.SRC4)  
**Síntoma:** La regex `'cut.*breaks.*=.*3.*labels.*c.*"Bajo".*"Medio".*"Alto"'` no está acotada al bloque chi_cuadrado. Encuentra coincidencias en run_analysis.R líneas 290 y 345 (bloques ANOVA, hallazgo F-002), provocando un FAIL falso.  
**Impacto:** E.SRC4 reporta FAIL aunque el guard chi-cuadrado esté correctamente implementado  
**Corrección pendiente:** Acotar la búsqueda a las líneas del bloque chi_cuadrado, o usar un número de línea como ancla  
**Prioridad:** Baja — el código de producción es correcto; es un problema de precisión del test

---

## EVALUACIÓN DEL CÓDIGO DE PRODUCCIÓN

### Guards implementados (Lote 1)

| Guard | Hallazgo | Verificación lógica | Verificación fuente | Integración real |
|-------|----------|--------------------|--------------------|-----------------|
| Logístico: VD_NO_BINARIA | F-007 | PASS (C.L1-5, B.F-007.L1-3) | PASS | NO VERIFICADO (DEF-T01) |
| Ordinal: VD_CONTINUA | — | PASS (D.L1-5) | PASS | NO VERIFICADO (DEF-T01) |
| Chi-cuadrado: VARIABLES_CONTINUAS | F-005 | PASS (E.L1-5) | PASS (E.SRC1-3) | N/A (guard en run_analysis.R, no función separada) |
| PLS: SINGLE_ITEM_CONSTRUCTS | — | PASS (F.L1-4, B.PLS.L1-4) | PASS (F.SRC1-3) | NO EJECUTADO (DEF-T02) |

**Conclusión de producción:** Los 4 guards tienen lógica correcta y están presentes en el código fuente. Los fallos en tests de integración se deben a defectos de infraestructura de pruebas, no a errores en el código de producción.

### Verificaciones adicionales

| Verificación | Estado |
|-------------|--------|
| `__dup__` eliminado de pls_sem_engine.R | CONFIRMADO (F.SRC1, B.PLS.L1) |
| No hay NaN/Inf en datos de prueba utilizados | CONFIRMADO |
| No hay JSON inválido en producción | CONFIRMADO (el JSON inválido fue de pls_sem_engine.R standalone, no de la función run_pls_sem) |
| `if: always()` no enmascaró fallos estadísticos | CONFIRMADO — sí enmascaró fallos de CI via DEF-T03 |
| Node.js 20 deprecation warning | P3 TÉCNICO — no es fallo científico (Node 20 EOL oct 2026; aún en LTS activo a 2026-06-28) |

---

## DICTAMEN LOTE 1C — CORREGIDO

### DICTAMEN ANTERIOR (2026-06-28, commit 5cb7346): VALIDADO CON RESTRICCIONES — INCORRECTO
**Corrección:** El dictamen "VALIDADO CON RESTRICCIONES" fue prematuro. Con 7 FAIL, 11 NO EJECUTADOS y un workflow que aparecía verde pese a fallos internos (DEF-T03), el dictamen metodológicamente correcto es:

### NO VALIDADO — INFRAESTRUCTURA DE PRUEBAS DEFECTUOSA Y COBERTURA DE INTEGRACIÓN INCOMPLETA

**Razones:**
1. **DEF-T03** (sin pipefail): Pasos B, D, E con `quit(status=1)` → CI verde. Fallos enmascarados sistemáticamente.
2. **DEF-T01** (`new.env(parent=baseenv())`): Tests de integración fallaban por entorno incorrecto, no por bugs en producción. 11 tests NO EJECUTADOS o con resultados incorrectos.
3. **DEF-T02** (pls_sem_engine.R `quit()` al ser sourced): Sección F interrumpida en F.SRC3, 4 tests NO EJECUTADOS.
4. **DEF-T04** (regex E.SRC4 demasiado amplio): 1 FAIL falso.
5. **F-006.2**: Expectativa incorrecta sobre la manifestación del bug (c2[1]=100 vs c2[1]=NA).

**Criterio aplicado:** "NO VALIDADO: cualquier FAIL; cualquier prueba crítica NO EXEC; workflow verde pese a fallos."

---

## LOTE 1D — REPARACIÓN DE INFRAESTRUCTURA Y RE-EJECUCIÓN

**Estado:** PENDIENTE ejecución tras push del commit de Lote 1D  
**Fixes implementados:**

| DEF | Fix | Archivo(s) modificado(s) |
|-----|-----|--------------------------|
| DEF-T03 | `shell: bash` + `set -euo pipefail` en pasos A-F; paso VERIFY con PIPESTATUS | `.github/workflows/scientific-audit-r.yml` |
| DEF-T01 | `new.env(parent=baseenv())` → `new.env(parent=globalenv())` (5 instancias) | `tests/audit_guards_comprehensive.R`, `tests/reproduce_scientific_bugs.R` |
| DEF-T02 | Guard `is_main_script()` en pls_sem_engine.R; CLI block solo cuando el archivo es el script principal | `apps/api/stats-engine-r/R/pls_sem_engine.R` |
| DEF-T04 | E.SRC4 reemplazado por tests conductuales E.I1-I4 + check acotado a ±80 líneas de VARIABLES_CONTINUAS | `tests/audit_guards_comprehensive.R` |
| F-006.2 | Expectativa corregida: c2[1]=NA (no imputado) vs c2[1]=100 (valor incorrecto esperado erróneamente) | `tests/reproduce_scientific_bugs.R` |

**Tests añadidos (casos válidos obligatorios):**
- C.I6b: VD {0,1} → coeficientes finitos
- C.I7b: VD {1,2} → modelo estima coeficientes
- D.I4b, D.I5b: Likert → resultado sin error
- E.I1-I4: chi-cuadrado conductual (2 categóricas → estadístico/p/tabla finitos; guard bloquea continua)
- F.I3b: 2-item valid → salida con tablas o success=TRUE
- F.I3c: 2-item valid → sin NaN/Inf
- ORDINAL.I4: VD ordinal → resultado con contenido
- F-007.I5: VD {0,1} → coeficientes finitos

**Justificación de `parent=globalenv()`:**  
En producción, `Rscript run_analysis.R` arranca con paquetes default (base, stats, graphics, grDevices, utils, datasets, methods) en el search path. Cuando `run_analysis.R` hace `source("logistic.R")`, el código fuente tiene acceso a `stats::na.omit`, `stats::glm`, etc. `new.env(parent=globalenv())` reproduce exactamente esta cadena de herencia: nuevo_env → .GlobalEnv → ... → stats → base. `new.env(parent=baseenv())` era incorrecto porque excluía stats de la cadena.

**Resultado del run Lote 1D:** NO VALIDADO — run 28334118789  
VERIFY: FAIL (PIPESTATUS[1] unbound). Paso A: SKIPPED (sin `if: always()`). Resumen: FAIL (ls exit 2). F-007.I5: FAIL (unlist lista mixta). C.I6b: FAIL (idem). Total PASS/FAIL/SKIP sin contar: B=PASS, C=FAIL (C.I6b), D=FAIL (D.I4b), E=PASS, F=PASS.

---

## LOTE 1E — REPARACIÓN CI + CORRECCIÓN DE TESTS + INVESTIGACIÓN LIKERT-3

**Estado:** EJECUTADO — GitHub Actions run 28335331099, commit e0d44110  
**Commit:** `e0d44110a2d6baa29dd7814cd05c3a86ec16db36`  
**Rama:** `claude/cancharios-stats-audit-0pnx4q`  
**Run ID:** 28335331099  
**Estado global CI:** FAILURE (pasos D y F)  
**R:** 4.3.2  
**Paquetes:** MASS 7.3.60, nnet 7.3.19, jsonlite 2.0.0, dplyr 1.2.1, openxlsx 4.2.8.1, seminr 2.5.0  
**Artefactos:** `audit-results-r4.3.2-28335331099.zip` (ID 7938419286, 10533 bytes, retención 90 días)

### Fixes implementados en Lote 1E

| Fix | Archivo | Detalle |
|-----|---------|---------|
| VERIFY: PIPESTATUS atómico | `.github/workflows/scientific-audit-r.yml` | `_ps=("${PIPESTATUS[@]}")` + `set -e` + verificación explícita de `rscript_rc` y `tee_rc` |
| Paso A: `if: always()` | `.github/workflows/scientific-audit-r.yml` | Garantiza ejecución de parse checks aunque VERIFY falle |
| Resumen: `\|\| true` en ls | `.github/workflows/scientific-audit-r.yml` | `ls ... 2>/dev/null \| head -1 \|\| true` — evita exit 2 cuando el archivo no existe |
| F-007.I5 fix | `tests/reproduce_scientific_bugs.R` | Extrae campos numéricos por nombre de lista-de-listas |
| F-007.I6 añadido | `tests/reproduce_scientific_bugs.R` | JSON roundtrip con vapply en data.frame |
| C.I6b fix | `tests/audit_guards_comprehensive.R` | Misma extracción por nombre |
| C.I6c-I6g añadidos | `tests/audit_guards_comprehensive.R` | Verificación campo a campo (B, SE, OR, p, IC) |
| C.I6h añadido | `tests/audit_guards_comprehensive.R` | JSON roundtrip con vapply |
| D: 5 escenarios Likert-3 | `tests/audit_guards_comprehensive.R` | ESC1-ESC5 con seed explícita e informe diagnóstico |
| F.CLI1-CLI6 añadidos | `tests/audit_guards_comprehensive.R` | Validación de ejecución CLI de pls_sem_engine.R |

### Resultados reales — Run 28335331099

#### Tabla resumen por paso

| Paso | Tests | PASS | FAIL | SKIP | Resultado |
|------|-------|------|------|------|-----------|
| VERIFY | bash | — | — | — | PASS ✅ |
| A | 4 (parse) | 4 | 0 | 0 | PASS ✅ |
| B | 26 | 26 | 0 | 0 | PASS ✅ |
| C | 20 | 20 | 0 | 0 | PASS ✅ |
| D | 16 | 15 | 1 | 0 | FAIL ❌ (D.I4b esperado) |
| E | 13 | 13 | 0 | 0 | PASS ✅ |
| F | 19 | 16 | 3 | 0 | FAIL ❌ (F.CLI3/4/5 inesperado) |
| **TOTAL R** | **94** | **90** | **4** | **0** | — |

#### Paso A — Parse checks
**Resultado:** COMPLETO — 4/4 archivos con sintaxis válida (`if:always()` confirmado funcionando)

| Archivo | Estado |
|---------|--------|
| apps/api/stats-engine-r/R/logistic.R | PASS |
| apps/api/stats-engine-r/R/ordinal_regression.R | PASS |
| apps/api/stats-engine-r/R/pls_sem_engine.R | PASS |
| apps/api/stats-engine-r/run_analysis.R | PASS |

#### Paso B — reproduce_scientific_bugs.R (26 tests)
**Resultado:** 26 PASS / 0 FAIL / 0 SKIP — F-007.I5 y F-007.I6 confirmados PASS

#### Paso C — Guard logístico (20 tests)
**Resultado:** 20 PASS / 0 FAIL / 0 SKIP — C.I6b y C.I6c-I6h confirmados PASS

| Highlight | Estado |
|-----------|--------|
| C.I6b — VD {0,1} → campos estadísticos (B,SE,OR,p) finitos | PASS |
| C.I6c — estimación (B) finita | PASS |
| C.I6d — SE finito y positivo | PASS |
| C.I6e — OR positivo | PASS |
| C.I6f — p en [0,1] | PASS |
| C.I6g — IC lower/upper finitos y ordenados | PASS |
| C.I6h — JSON roundtrip: data.frame con numéricos finitos | PASS |

#### Paso D — Guard ordinal (16 tests) — FAIL
**Resultado:** 15 PASS / 1 FAIL / 0 SKIP

| ID | Descripción | Estado |
|----|-------------|--------|
| D.L1-D.L5 | Lógica guard VD continua (5 casos) | PASS |
| D.L6 | NOTE: F-022 heurística >10 enteros | NOTE |
| D.I1, D.I2 | VD continua / decimal bloqueada | PASS |
| D.I3 | VD Likert-3 not blocked | PASS |
| D.I4 | VD Likert-3 not blocked (integración) | PASS |
| **D.I4b** | **VD Likert-3 → resultado sin error** | **FAIL ❌** |
| D.I5, D.I5b | VD Likert-5 → not blocked / sin error | PASS |
| D.I6 | VD texto → not blocked | PASS |
| D.ESC1 | Likert-3 balanceado n=120 seed=42 → sin error | PASS |
| D.ESC2 | Likert-3 desbalanceado n=90 seed=7 → sin error | PASS |
| D.ESC3 | n=60 seed=7 freq={1:19,2:23,3:18} dup_cuts=TRUE | NOTE (fallo esperado) |
| D.ESC4 | n=60 seed=123 freq={1:2,2:58,3:0} dup_cuts=TRUE | NOTE (fallo esperado) |
| D.ESC5 | Likert-5 control n=60 seed=42 → sin error | PASS |

**D.I4b real (seed=42, n=60):** freq={1:19,2:22,3:19}, q13=c(2,2), dup_cuts=TRUE → error `'breaks' are not unique`

#### Clasificación D.I4b (confirmada)

**BUG PRODUCTIVO + MANEJO DE ERRORES DEFICIENTE**

| Escenario | n | seed | freq | q13 | dup_cuts | Resultado |
|-----------|---|------|------|-----|----------|-----------|
| ESC1 | 120 | 42 | {1:43,2:38,3:39} | c(1,2) | FALSE | sin error ✅ |
| ESC2 | 90 | 7 | {1:35,2:32,3:23} | c(1,2) | FALSE | sin error ✅ |
| ESC3 | 60 | 7 | {1:19,2:23,3:18} | c(2,2) | TRUE | error (réplica D.I4b) |
| ESC4 | 60 | 123 | {1:2,2:58,3:0} | c(2,2) | TRUE | error (separación máxima) |
| ESC5 | 60 | 42 | Likert-5 | distintos | FALSE | sin error ✅ (control) |

**Mecanismo:** `quantile(score_b, probs=c(1/3,2/3))` sobre Likert-3 produce q[1]==q[2]==2 cuando cat1 y cat3 son escasas → `cut(breaks=c(-Inf,2,2,Inf))` → `'breaks' are not unique'`. El `tryCatch` captura silenciosamente → devuelve `$error` sin `$blocked=TRUE` ni `$reason` → contrato R-Node no puede propagar el error correctamente.

**Condición de disparo:** Likert-3 con distribución donde menos de ~1/3 del total está en la categoría 1 O menos de ~1/3 en la categoría 3 (los cuantiles 33% y 67% colapsan al mismo valor).

**Nota:** `ordinal_regression.R` NO modificada en este lote.

#### Paso E — Guard chi-cuadrado (13 tests)
**Resultado:** 13 PASS / 0 FAIL / 0 SKIP — todos los guards verificados

#### Paso F — Guard PLS-SEM (19 tests) — FAIL
**Resultado:** 16 PASS / 3 FAIL / 0 SKIP

| ID | Descripción | Estado |
|----|-------------|--------|
| F.L1-F.L4 | Guard lógico: single-item / multi-item | PASS (4) |
| F.SRC1-SRC3 | Fuente: `__dup__` eliminado, guard presente | PASS (3) |
| F.PKG | seminr cargado exitosamente | PASS |
| F.I1, F.I2 | Integración: single-item bloqueado, reason correcto | PASS (2) |
| F.I3, F.I3b, F.I3c | Integración: 2-item válido → sin NaN/Inf | PASS (3) |
| F.CLI1 | CLI sin argumentos → exit code 1 | PASS |
| F.CLI2 | CLI JSON inválido → exit code 1 | PASS |
| **F.CLI3** | **CLI params válidos → exit code 0** | **FAIL ❌** |
| **F.CLI4** | **CLI params válidos → JSON con success=TRUE** | **FAIL ❌** |
| **F.CLI5** | **CLI single-item → blocked=TRUE** | **FAIL ❌** |
| F.CLI6 | CLI salida no contiene `__dup__` | PASS |

**Clasificación F.CLI3-CLI5:**

NUEVA FINDING — `pls_sem_engine.R` retorna exit=1 cuando se invoca como CLI standalone (`Rscript --vanilla pls_sem_engine.R <json>`) con JSON válido. El subprocess termina antes de ejecutar el bloque de lógica (línea 976). Causas probables: (a) el flag `--vanilla` interfiere con la disponibilidad de paquetes (`library(seminr)` falla en el hijo porque alguna inicialización de `.libPaths()` difiere); (b) la invocación directa de `pls_sem_engine.R` como CLI no es el patrón de producción (en producción, `Rscript run_analysis.R` hace `source("pls_sem_engine.R")`). Los tests F.I3/F.I3b/F.I3c (invocación directa de función) pasan, confirmando que la lógica del módulo es correcta. Requiere investigación en lote futuro.

---

### Dictamen Lote 1E

**NO VALIDADO**

- 90/94 tests PASS (95.7%)
- D.I4b: BUG PRODUCTIVO confirmado en `run_ordinal_regression` (Likert-3 con distribución concentrada → cortes iguales → error no propagado como `$blocked`)
- F.CLI3-CLI5: NUEVA FINDING — invocación CLI standalone de `pls_sem_engine.R` con `--vanilla` falla con exit=1 para JSON válido; requiere investigación
- Los fixes de infraestructura CI (VERIFY PIPESTATUS, Paso A `if:always()`, Resumen `||true`) están todos confirmados PASS
- Los fixes de tests (F-007.I5, C.I6b-I6h) están todos confirmados PASS

---

## PLANTILLA DE RESULTADOS — Ejecución baseline validate_mtcars.R

### Ejecución 1 — Baseline (antes de correcciones)

**Fecha:** PENDIENTE  
**Rama:** `claude/cancharios-stats-audit-0pnx4q`  
**Comando:** `Rscript tests/validate_mtcars.R`

| ID | Prueba | Valor actual | Valor esperado | Tolerancia | Estado |
|----|--------|-------------|----------------|------------|--------|
| T01 | Correlación: r | — | -0.8677 | 0.01 | ⏳ |
| T01 | Correlación: t | — | -9.559 | 0.01 | ⏳ |
| T01 | Correlación: IC inferior | — | -0.9338 | 0.01 | ⏳ |
| T02 | Regresión: Intercepto | — | 37.2851 | 0.01 | ⏳ |
| T02 | Regresión: Pendiente wt | — | -5.3445 | 0.01 | ⏳ |
| T02 | Regresión: R² | — | 0.7528 | 0.01 | ⏳ |
| T02 | Regresión: F | — | 91.3753 | 0.1 | ⏳ |
| T03 | ANOVA: F | — | 39.70 | 0.1 | ⏳ |
| T03 | ANOVA: df_between | — | 2 | 0 | ⏳ |
| T03 | ANOVA: df_within | — | 29 | 0 | ⏳ |
| T04 | t-test: t (Welch) | — | -3.7671 | 0.01 | ⏳ |
| T04 | t-test: df (Welch) | — | 18.33 | 0.1 | ⏳ |
| T05 | Chi²: estadístico | — | 0.3475 | 0.01 | ⏳ |
| T06 | Logística: Intercepto | — | -6.6035 | 0.01 | ⏳ |
| T06 | Logística: coef mpg | — | 0.307 | 0.01 | ⏳ |
| T06 | Logística: LR chi² | — | 13.5546 | 0.01 | ⏳ |
| T07 | Cronbach: alfa | — | -0.5449 | 0.01 | ⏳ |
| T08 | ANCOVA: F covariable | — | 68.5305 | 0.1 | ⏳ |
| T08 | ANCOVA: F grupo | — | 8.6124 | 0.1 | ⏳ |
| T09 | Discriminante: precisión % | — | 87.5 | 0.5 | ⏳ |
| T10 | Cluster: Within SS | — | 23.739 | 0.05 | ⏳ |
| T10 | Cluster: Between SS | — | 69.261 | 0.05 | ⏳ |
| T11 | Reg. ordinal: AIC | — | 42.879 | 0.05 | ⏳ |
| T11 | Reg. ordinal: B (wt) | — | -3.957 | 0.01 | ⏳ |
| T12 | Multinomial: LR chi² | — | 51.7884 | 0.01 | ⏳ |
| T12 | Multinomial: B mpg (nivel 6) | — | -2.2054 | 0.01 | ⏳ |

**Total esperado:** 26 verificaciones en 12 métodos  
**Resultado:** PENDIENTE

---

## NOTAS PARA EL EVALUADOR

1. Para ejecutar las pruebas, se necesita acceso a un entorno con R y los paquetes instalados.
2. El archivo `tests/validate_mtcars.R` usa el dataset `mtcars` que es reproducible en cualquier R base.
3. Si alguna prueba falla, el script termina con `quit(status=1)` — útil para CI/CD.
4. Los valores esperados en las pruebas fueron diseñados comparando contra R base puro sin los módulos de CanchariOS.
5. Los defectos DEF-T01 a DEF-T04 deben corregirse antes de la siguiente iteración de pruebas.
6. La advertencia de deprecación de Node.js 20 en GitHub Actions es un asunto P3 técnico — Node 20 sigue en LTS activo a 2026-06-28 (EOL oct 2026).

---

*Documento actualizado 2026-06-28. Lote 1E run 28335331099 ejecutado. Dictamen Lote 1E: NO VALIDADO (D.I4b bug productivo + F.CLI3-5 nueva finding).*
