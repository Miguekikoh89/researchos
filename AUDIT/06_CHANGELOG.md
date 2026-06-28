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

## [PENDIENTE] — Lote 2 (requiere autorización)

- [ ] F-002: Eliminar bloque ANOVA duplicado en run_analysis.R
- [ ] F-004: Eliminar funciones duplicadas de statistics.R
- [ ] F-003: Unificar interpret_r() a escala canónica de 6 niveles
- [ ] F-006: Corregir imputación vectorizada en instruments.R (probar en Docker primero)
- [ ] F-001: Verificar y corregir compute_omega() (requiere relectura)

---

*Formato: [YYYY-MM-DD] Descripción de cambio — Archivo(s) modificado(s) — Hallazgo(s) corregido(s)*
