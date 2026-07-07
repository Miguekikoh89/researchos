# VALIDATION_SCOPE — Qué significa "validado" en CanchariOS

**Rama de auditoría:** `claude/cancharios-stats-audit-0pnx4q` · **Fecha:** 2026-07-03

Este documento fija el alcance exacto de la validación científico-computacional.
"Validado" aquí NO significa infalible ni universalmente correcto: significa que
**el 100% de los criterios del protocolo de validación documentado fueron
ejecutados y aprobados dentro del alcance descrito abajo.**

---

## 1. Qué SÍ significa "validado"

Para cada método marcado VALIDATED en `AUDIT/01_METHODS_MATRIX.md`:

1. **Ruta funcional completa** demostrada dinámicamente: configuración →
   `AnalysisService.createJob()` (código de producción compilado) → job en
   PostgreSQL real → `Rscript run_analysis.R` (script de producción, layout
   `/app/stats-engine-r`) → JSON parseado → `rejectNonFinite()` →
   `analysis_results` → consulta — sin mocks en ningún eslabón.
2. **Estados correctos**: PENDING→PROCESSING→COMPLETED en éxito;
   PENDING→PROCESSING→FAILED en bloqueo metodológico y en error técnico;
   ningún COMPLETED sin resultado, ningún FAILED con resultado, ningún
   resultado con error embebido marcado COMPLETED (invariantes AH.NEVER).
3. **Exactitud numérica** contrastada contra R base / cálculos de referencia
   independientes dentro de las tolerancias de la sección 4.
4. **JSON finito**: lo persistido nunca contiene NaN/Infinity/−Infinity/undefined
   (barrido SQL AI.ALL sobre toda la base de CI).
5. **Seguridad de entrada**: path traversal, contenido binario con extensión
   falsa, archivo vacío, >50 MB, timeout del proceso R y nombres/valores
   maliciosos terminan en FAILED controlado sin ejecución de código, sin
   exposición de credenciales en `errorMsg` y sin temporales huérfanos.

## 2. Qué NO significa "validado"

- **No** garantiza corrección sobre datasets con estructuras no cubiertas por
  los fixtures (p.ej. cientos de columnas, encodings exóticos, Excel con
  fórmulas).
- **No** cubre la interfaz gráfica pixel a pixel ni interacciones de navegador:
  la capa UI se validó a nivel de **contrato de payload** (lo que StepRun envía)
  y los guards del motor bloquean todo payload inválido. No se ejecutó Playwright.
- **No** valida el despliegue (Railway/Docker) ni la base de producción: toda la
  validación corrió contra PostgreSQL 16 efímero de CI con `DATABASE_URL`
  exclusiva.
- **No** valida PLS-SEM dinámicamente en esta fase (auditoría estática previa;
  ver restricciones en la matriz).
- **No** constituye una prueba de equivalencia completa con SPSS/Stata; las
  referencias son R base y fórmulas publicadas (ver `AUDIT/04_STATISTICAL_REFERENCES.md`).

## 3. Datasets de validación

- **CSV estándar sintético** (N=120, semilla LCG determinista 20260703):
  ítems Likert 1–5 correlacionados (A1–A4, B1–B4), predictor continuo C1,
  grupo de 3 niveles, VD binaria 0/1, VD ordinal 1/2/3, tripleta de mediación
  X→M→Y con efectos conocidos, categóricas CatA/CatB.
- **Fixtures adversariales**: binario ELF renombrado a .csv, CSV vacío,
  CSV de 52 MB, rutas de traversal, columna constante, NaN/Inf inyectados.
- **Fixtures R** (suites Y–AF): normales/logísticas/ordinales simuladas con
  `set.seed` fijo por test.

## 4. Versiones y tolerancias

| Ítem | Valor |
|------|-------|
| R | 4.3.2 (CI) / 4.3.3 (local) |
| Node.js | 20.x (CI) |
| PostgreSQL | 16 |
| Prisma | 5.22.0 |
| Tolerancia identidades algebraicas (B de inversión de evento) | ≤ 1e-8 (cumplida de forma exacta sobre lo persistido) |
| Tolerancia coherencia mediación (a·b vs indirect) | ≤ 2e-6 (precisión persistida: 6 decimales) |
| Tolerancia OR recíprocos | ≤ 1e-2 (precisión persistida: 3 decimales; identidad exacta demostrada sobre B) |
| Estadísticos vs referencia R base | igualdad al redondeo que persiste el motor (3–4 decimales según campo) |

## 5. Métodos y estados

Ver matriz completa en `AUDIT/01_METHODS_MATRIX.md`. Resumen: 10 VALIDATED,
8 VALIDATED_WITH_RESTRICTIONS (validación R previa sin E2E Node en esta fase),
1 NOT_IMPLEMENTED no visible (mediación serial, bloqueada con razón explícita),
1 HIDDEN (factorial, tarjeta deshabilitada). Cero métodos visibles sin ruta.

## 6. Restricciones conocidas

- **F-032**: la UI captura `event_level`/`ordered_levels` como texto libre; no
  lista los niveles observados (requiere endpoint de valores). Todo valor
  inválido es bloqueado por el motor con mensaje explícito.
- **F-033**: `reason`/`stage` de los fallos viajan dentro de `errorMsg` (sin
  columnas dedicadas en el schema).
- **F-034**: directorios de salida vacíos no se eliminan (los temporales de
  configuración sí).
- **P2-WELCH**: omnibus Welch no implementado; mitigado por Levene reportado y
  fallback automático a Games-Howell.
- Los Word generados viven en el filesystem efímero del contenedor (hallazgo
  previo F-020): un redeploy los pierde.

## 7. Riesgos residuales

1. Cobertura E2E Node parcial para 8 métodos secundarios (solo validación R).
2. PLS-SEM sin ejercicio dinámico en CI (dependencias pesadas de seminr).
3. La equivalencia con software comercial (SPSS) se infiere de fórmulas, no de
   corridas cruzadas automatizadas.
4. La validación de UI es de contrato, no de interacción real de navegador.
