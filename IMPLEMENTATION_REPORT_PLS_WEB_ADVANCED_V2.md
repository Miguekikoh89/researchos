# CanchariOS — PLS-SEM avanzado integrado en la aplicación web

**Fecha:** 4 de julio de 2026  
**Entrega:** Web Advanced V2

## Alcance implementado

La suite PLS-SEM dejó de ser una pantalla básica y ahora conecta de extremo a extremo la configuración web, el contrato API, el motor R, la visualización de resultados y el informe Word APA 7.

### Interfaz de configuración

- Modo avanzado activado por defecto.
- Bootstrap y semilla reproducible.
- Q² Stone–Geisser y distancia de omisión.
- PLS-Predict con folds y repeticiones.
- HTMT inferencial.
- SRMR saturado y estimado.
- Full-collinearity VIF/CMB.
- VAF y clasificación de mediación.
- IPMA con objetivo y límites teóricos de escala.
- Cópula gaussiana opt-in.
- Variables de control con nombre, columna y constructos objetivo.
- Variable de grupo para MICOM/MGA.
- FIMIX-PLS con K mínimo/máximo, inicios EM, iteraciones y tolerancia.
- Uso opcional de los segmentos FIMIX para MICOM/MGA.
- Comparación de modelos directo, paralelo y secuencial mediante roles X, M1, M2 e Y.

### Motor R

- Variables de control como constructos de un indicador mediante `seminr::single_item()`.
- Rutas de control distinguidas de las hipótesis estructurales.
- Efectos directos, indirectos específicos y totales.
- FIMIX-PLS mediante `seminrExtras::assess_fimix_compare()`.
- Selección de K mediante coincidencia AIC3+CAIC y AIC4 como criterio auxiliar ante desacuerdo.
- Tablas de ajuste FIMIX, segmentos, rutas y asignaciones probabilísticas.
- MICOM/MGA con variable observada o segmentos FIMIX seleccionados.
- Comparación homogénea de modelos directo, paralelo y secuencial con R², R² ajustado, Q² y SRMR.
- Estados explícitos `implemented`, `not_applicable`, `disabled_by_configuration` y `failed_closed`.

### Resultados web

Se añadieron secciones visibles para:

- variables de control;
- FIMIX-PLS y tamaños de segmentos;
- fuente de agrupación usada por MICOM/MGA;
- comparación de modelos;
- Q², PLS-Predict, cópula, MICOM, MGA e IPMA;
- efectos indirectos y totales.

### Word APA 7

El exportador ahora incluye:

- variables de control;
- efectos directos, indirectos y totales;
- FIMIX: criterios, segmentos y rutas;
- comparación de modelos;
- los módulos avanzados ya existentes;
- estado de cada módulo y fuente de agrupación MICOM/MGA.

## Pruebas añadidas

1. `tests/certification/test_pls_sem_web_contract_static.py`
   - comprueba la conexión interfaz → API → R → pantalla → Word;
   - verifica la dependencia `seminrExtras`;
   - confirma la sincronización de las tres copias del motor.

2. `tests/certification/test_pls_sem_web_workflow.R`
   - ejecuta un modelo secuencial de cuatro constructos;
   - incorpora una variable de control;
   - exige efectos indirectos y totales;
   - ejecuta comparación directo/paralelo/secuencial;
   - ejecuta FIMIX K=2 y comprueba segmentos y asignaciones.

## Verificaciones realizadas en el entorno de preparación

- Contratos Python y pruebas estáticas: **PASS**.
- Tres copias del motor PLS-SEM: **idénticas por SHA-256**.
- Compilación de la interfaz Next.js: **PASS**, 17 páginas estáticas.
- Validación de tipos de la interfaz: **PASS**.
- Compilación Nest TypeScript: **PASS** cuando se suministran los tipos de Prisma.
- Revisión estática de delimitadores R: **PASS**.

El entorno de preparación no dispone de R y no pudo descargar el binario de Prisma por restricción de red. Por eso la nueva prueba R y el `prisma generate` deben ejecutarse localmente antes de declarar esta nueva versión certificada.

## Certificación local requerida

```bash
npm run install:r
npm run db:generate
tests/run_numerical_certification.sh
npm run build:api
npm run build:web
```

Resultado esperado:

```text
FASE 1: 21 PASS | 0 FAIL
FASE 2: 16 PASS | 0 FAIL
RESULTADO GLOBAL: CERTIFICACIÓN LOCAL SUPERADA
```

La línea base anterior mantiene sus 35 pruebas aprobadas. Esta ampliación exige **37 pruebas aprobadas y ninguna fallida** antes de liberarse como nueva línea base estable.

## Consideraciones metodológicas

- Cópula, FIMIX y comparación de modelos son opt-in porque requieren una decisión metodológica explícita.
- FIMIX no convierte automáticamente segmentos probabilísticos en grupos sustantivos; se deben evaluar teoría, tamaño y estabilidad.
- MICOM precede a MGA.
- Una comparación con mejores indicadores predictivos no constituye, por sí sola, prueba de superioridad causal.
- Las variables de control deben ser numéricas o dummy y estar justificadas teóricamente.
