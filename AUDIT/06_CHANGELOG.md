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

## [PENDIENTE] — Fase 1: Correcciones P0/P1

Las siguientes correcciones están planificadas pero NO ejecutadas aún:

- [ ] F-002: Eliminar bloque ANOVA duplicado en run_analysis.R
- [ ] F-004: Eliminar funciones duplicadas de statistics.R
- [ ] F-003: Verificar interpret_r() una vez F-004 resuelto
- [ ] F-007: Agregar campo warning en binarización logística
- [ ] F-006: Corregir imputación vectorizada en instruments.R
- [ ] F-001: Verificar y corregir compute_omega() (requiere relectura)

---

*Formato: [YYYY-MM-DD] Descripción de cambio — Archivo(s) modificado(s) — Hallazgo(s) corregido(s)*
