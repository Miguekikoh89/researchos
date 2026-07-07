# 09 — RELEASE READINESS
## AUDITORÍA CIENTÍFICO-COMPUTACIONAL Y VALIDACIÓN CRUZADA DE CANCHARIOS
### Fase Final — 2026-07-03

---

## Identificación

| Campo | Valor |
|-------|-------|
| RAMA | `claude/cancharios-stats-audit-0pnx4q` |
| COMMITS (fase final) | `318957a` → `b99483b` → `ea96d02` → `23d25b1` (+ documentación) |
| RUNS (dynamic-integration-audit.yml) | #1 `28661276126` (fail, diagnóstico) · #2 `28662679579` (fail, 1 suite) · #4 `28664207447` (**SUCCESS — 3/3 jobs verdes**) |
| VERSIÓN | monorepo `researchos-stats-engine` 1.0.0 (API `@researchos/api` 1.0.0, Web `@researchos/web` 1.0.0) |

## Resultados de tests — fase final (run #4, commit 23d25b1)

| Bloque | PASS | FAIL | SKIP | NOTE | NO EXEC |
|--------|------|------|------|------|---------|
| Suites R dinámicas Y–AF (motor) | 180 | 0 | 0 | 0 | 0 |
| Suites Node→R→PostgreSQL AG–AK | 181 | 0 | 1 | 0 | 0 |
| **TOTAL FASE FINAL** | **361** | **0** | **1** | **0** | **0** |

El único SKIP (AH.BLOCK.06) documenta que `reason`/`stage` no existen como
columnas del schema (F-033) — no es un test fallido ni omitido sin causa.
Las suites heredadas A–X de `scientific-audit-r.yml` permanecen intactas.

## Estado por criterio de cierre

| Criterio | Estado | Evidencia |
|----------|--------|-----------|
| BUILD BACKEND | ✅ | `npm ci` + `prisma generate` + `tsc --noEmit` + `nest build`, exit 0 (job 1 run #4) |
| BUILD FRONTEND | ✅ | `tsc --noEmit` + `next build` 17/17 páginas, exit 0 (job 1 run #4) |
| POSTGRESQL | ✅ | Service postgres:16 en CI, base exclusiva `cancharios_ci`; AG.DB.01–05 |
| PRISMA | ✅ | `prisma db push` + `generate` (el repo no versiona migraciones); cliente 5.22.0 |
| NODE→R | ✅ | 11 métodos por `AnalysisService` real + `Rscript run_analysis.R` (AG) |
| NODE→DB | ✅ | Persistencia y consulta verificadas por job (AG.*.row, AK.CONC.04) |
| EVENT_LEVEL | ✅ | AJ.INV.01–10: inversión B2=−B1 exacta (≤1e-8), evento/referencia persistidos, EVENTO_NO_ENCONTRADO bloquea |
| ORDERED_LEVELS | ✅ | AJ.ORD.01–08: ORDEN_NO_DECLARADO / ORDEN_INCOMPLETO / ORDEN_INVALIDO / orden exacto por umbrales |
| MEDIACIÓN | ✅ | AG.MED + AJ.MED: campos completos, indirect=a·b, reproducible por seed, serial bloqueada |
| WORD | ✅ | AD (30 tests R) + AK.WORD.01–08 (DOCX del pipeline: ZIP, XML, celdas vs JSON) |
| JSON FINITO | ✅ | AI (18 tests): protocolo exacto + barrido SQL sin NaN/Infinity |
| ESTADOS | ✅ | AH (23 tests): transiciones e invariantes globales |
| SEGURIDAD | ✅ | AE (19) + AK: traversal, MIME falso, vacío, >50MB, sin fuga de credenciales |
| CONCURRENCIA | ✅ | AK.CONC.01–04 + AF: jobs simultáneos sin mezcla |
| TEMPORALES | ✅ | AK.TEMP.01 + AF.TEMP: sin `analysis_*_config.json` huérfanos tras éxito/fallo/timeout |
| TIMEOUT | ✅ | AK.TIMEOUT.01–03: Rscript excedido → FAILED controlado |

## Hallazgos

| Severidad | Abiertos | Detalle |
|-----------|----------|---------|
| **P0** | **0** | — |
| **P1** | **0** | F-025 (logística rota vía pipeline) y F-026 (COMPLETED con error embebido) CERRADOS en `ea96d02` |
| **P2** | **1** | P2-WELCH (omnibus Welch ausente) — documentado, mitigado por Levene + fallback Games-Howell, no falsea resultados, no afecta métodos centrales |
| **P3** | **3** | F-032 (UI texto libre para niveles), F-033 (reason/stage en errorMsg), F-034 (dirs de salida vacíos) — documentados, sin impacto en resultados |

P2 cerrados en esta fase: SINGULAR, HIER-N, DF2-ROUND, AFE-JUST-ID, GH-P,
USE-FISHER, ORDINAL-LEGACY; LEVENE-LABEL mitigado/documentado.

## Métodos (ver matriz completa en 01_METHODS_MATRIX.md)

| Estado | Cantidad |
|--------|----------|
| VALIDATED | 10 |
| VALIDATED_WITH_RESTRICTIONS | 8 |
| EXPERIMENTAL | 0 |
| HIDDEN | 1 (factorial, tarjeta deshabilitada) |
| NOT_IMPLEMENTED | 1 (mediación serial — **no visible**, bloqueada con razón explícita) |
| **Métodos visibles sin ruta funcional** | **0** |

## Protocolo

- CRITERIOS DEL PROTOCOLO EJECUTADOS: 16/16 (fases A–N)
- CRITERIOS APROBADOS: 16/16
- PORCENTAJE DEL PROTOCOLO: **100% ejecutado y aprobado dentro del alcance documentado** (ver `VALIDATION_SCOPE.md`)
- AVANCE GLOBAL ESTIMADO DE RELEASE READINESS: **~96%** (rango defendible 95–97%)

## Riesgos residuales

1. 8 métodos secundarios validados a nivel R sin E2E Node en esta fase.
2. PLS-SEM sin ejercicio dinámico en CI (dependencias seminr pesadas).
3. Validación de UI por contrato de payload, no por navegador real.
4. Equivalencia con SPSS inferida de fórmulas publicadas, no de corridas cruzadas.
5. Word en filesystem efímero (F-020 previo): se pierde en redeploy.

## DICTAMEN FINAL

**LISTO PARA RELEASE CANDIDATE** dentro del alcance documentado en
`VALIDATION_SCOPE.md`: backend y frontend compilan; PostgreSQL y Prisma
funcionan en CI; el pipeline Node→R→DB funciona sin mocks para los 11 métodos
obligatorios; event_level, ordered_levels y mediación funcionan de extremo a
extremo; el Word real coincide con el JSON persistido; el JSON es finito; los
estados son correctos y sin contradicciones; la seguridad dinámica, la
concurrencia y la limpieza de temporales están aprobadas; 0 FAIL críticos,
0 NO EXEC críticos, 0 métodos visibles sin ruta, P0=0, P1=0.

Esto **no** es una declaración de perfección universal: es la afirmación de que
el 100% de los criterios del protocolo de validación fueron ejecutados y
aprobados dentro del alcance y las tolerancias documentadas.

*No se hizo merge a `main`. No se desplegó. No se tocó producción ni Railway.*
