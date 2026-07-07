# Implementación PLS-SEM avanzada — CanchariOS / ResearchOS

**Fecha:** 4 de julio de 2026  
**Estado de entrega:** **IMPLEMENTADO — PENDIENTE DE CERTIFICACIÓN NUMÉRICA R LOCAL**

## 1. Alcance incorporado

Se reemplazaron las aproximaciones avanzadas no defendibles y se conectaron al resultado final los siguientes procedimientos:

- **Q² de Stone–Geisser:** omisión sistemática, reestimación y predicción de indicadores endógenos; informa SSO, SSE, distancia y omisiones válidas.
- **PLS-Predict:** `seminr::predict_pls`, reestimación por fold, predicción a nivel de indicador, RMSE/MAE y comparación PLS frente a LM y media de entrenamiento.
- **HTMT inferencial:** intervalo percentil derivado de `boot_HTMT`, sin redondeo previo.
- **SRMR compuesto:** versiones saturada y estimada, junto con d_ULS y advertencia de alcance diagnóstico.
- **CMB por full-collinearity VIF:** regresiones auxiliares sobre scores de constructos, presentado como diagnóstico y no como prueba concluyente.
- **VAF y mediación:** suma conjunta de todas las rutas indirectas con el mismo origen y destino; clasificación por intervalos bootstrap siguiendo la lógica de Zhao; VAF solo cuando es interpretable.
- **IPMA:** rendimiento 0–100 calculado con límites teóricos y pesos desestandarizados; importancia como efecto total no estandarizado sobre los scores 0–100.
- **MICOM:** evaluación por pares de grupos, pesos reestimados en cada permutación, comparación de medias y log-varianzas, ajuste Holm.
- **MGA:** reestimación PLS en cada permutación, valores p ajustados con Holm y ejecución únicamente después de invarianza composicional completa para el par de grupos.
- **Cópula gaussiana:** procedimiento opt-in por ruta, requisito de predictor no normal, ECDF ajustada F4, constructo copular de un indicador, modelo PLS aumentado y bootstrap condicional al término copular generado en la etapa 1. Incluye correlación predictor–cópula y omega simple como diagnósticos.

## 2. Comportamiento fail-closed

Cada módulo avanzado devuelve uno de estos estados:

- `implemented`: cálculo finalizado y contrato validado.
- `not_applicable`: el modelo o los datos no permiten aplicar el procedimiento.
- `disabled_by_configuration...`: el usuario no lo activó o falta una configuración explícita.
- `failed_closed:...`: ocurrió un fallo inesperado y el motor bloqueó el resultado en lugar de devolver una tabla vacía o una aproximación falsa.

La cópula permanece desactivada por defecto y requiere activación explícita. MICOM y MGA requieren variable de grupo y tamaños mínimos. Para uso confirmatorio se mantienen **5,000** réplicas/permutaciones; valores menores quedan etiquetados como exploratorios.

## 3. Capas modificadas

- Motor R canónico: `apps/api/stats-engine-r/R/pls_sem_engine.R`
- Copias desplegables sincronizadas:
  - `pls_sem_engine.R`
  - `apps/stats-engine-r/R/pls_sem_engine.R`
- Contratos API: `apps/api/src/analysis/analysis.service.ts`
- Interfaz: `apps/web/src/components/wizard/StepResults.tsx`
- Exportación Word: `apps/api/stats-engine-r/R/word_export.R`
- Prueba numérica avanzada: `tests/certification/test_pls_sem_advanced.R`
- Contrato estático: `tests/certification/test_fail_closed_static.py`
- Documentación y matriz de certificación: `README.md`, `TECHNICAL_DOCUMENTATION.md`, `VALIDATION_SCOPE.md`, `AUDIT/*`

## 4. Verificaciones ejecutadas en este entorno

### Superadas

1. `python tests/certification/test_fail_closed_static.py`
   - Resultado: `PASS contratos fail-closed, módulos PLS-SEM avanzados y validación API`.
2. `python -m py_compile tests/certification/*.py`
   - Resultado: sin errores.
3. Escáner léxico de delimitadores y cadenas en **99 archivos R**.
   - Resultado: sin delimitadores ni cadenas sin cerrar.
4. Comparación SHA-256 de las tres copias del motor.
   - Resultado: copias idénticas.
5. `NEXT_TELEMETRY_DISABLED=1 npm run build:web`
   - Resultado: compilación, lint, comprobación de tipos y generación de 17 páginas estáticas completadas. Solo se omitió la optimización de la fuente remota de Google por falta de red.

### No ejecutables aquí

1. **Certificación numérica R:** este entorno no dispone de `R` ni `Rscript`. Por ello, no se declara que `test_pls_sem_advanced.R` haya pasado.
2. **Build completo de API:** Prisma no pudo descargar/generar su cliente por indisponibilidad de `binaries.prisma.sh`. `nest build` mostró únicamente errores derivados de los tipos Prisma no generados (`PrismaClient`, `JobStatus` y modelos), no errores de sintaxis en los contratos PLS incorporados.

## 5. Puerta obligatoria en el Mac del proyecto

Desde la raíz del repositorio:

```bash
npm run install:r
npm run db:generate
tests/run_numerical_certification.sh
npm run build:api
npm run build:web
```

La ampliación solo debe cambiar a **CERTIFICADA** cuando la salida final sea:

```text
CERTIFICACIÓN: 14 PASS | 0 FAIL
PUERTA DE CERTIFICACIÓN NUMÉRICA SUPERADA.
RESULTADO GLOBAL: CERTIFICACIÓN LOCAL SUPERADA
```

El total esperado aumenta de 13 a 14 porque se añadió `tests/certification/test_pls_sem_advanced.R`.

## 6. Criterio de liberación

No presentar estos módulos como certificados basándose únicamente en la compilación o en el contrato estático. La liberación exige:

1. nueva puerta R completa con 14/14;
2. generación correcta del cliente Prisma;
3. build de API y web;
4. una prueba end-to-end que confirme que API, interfaz y Word conservan los estados y las tablas avanzadas.
