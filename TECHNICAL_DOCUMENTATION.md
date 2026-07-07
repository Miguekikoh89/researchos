# CanchariOS — documentación técnico-científica

**Versión candidata:** certificación numérica integral, 2026-07-04.

## 1. Arquitectura de cálculo

```text
Next.js → NestJS → run_analysis.R → módulos R → contrato numérico API
        → PostgreSQL → pantalla → Word APA 7
```

El motor canónico está en `apps/api/stats-engine-r`. El API valida los resultados antes de persistirlos:

- rechaza NaN, `Infinity` y `-Infinity`;
- rechaza errores o bloqueos anidados;
- comprueba probabilidades en `[0, 1]`;
- exige campos obligatorios por método;
- conserva estados explícitos por módulo PLS-SEM y bloquea con `failed_closed` cualquier cálculo avanzado que falle.

## 2. Política de datos

- La política predeterminada de faltantes es **sin imputación automática**.
- Cuando el usuario solicita imputación, se conserva la precisión de medias o medianas; no se redondean los valores imputados.
- Un puntaje compuesto requiere, por defecto, al menos 80% de ítems válidos.
- No se crean grupos artificiales ni variables ordinales artificiales.
- Las variables constantes, muestras insuficientes, niveles inexistentes y modelos inestables se bloquean.

## 3. Inferencia y presentación

- Las decisiones se toman con valores *p* de precisión completa.
- `p = 0` nunca se muestra; se presenta `p < .001` cuando corresponde.
- Los intervalos se verifican antes de persistir.
- En bootstrap se fija y documenta la semilla y se restaura el estado aleatorio.
- Pantalla y Word usan las mismas convenciones APA.

## 4. Referencias numéricas ejecutables

La carpeta `tests/certification` compara el código de producción con:

- funciones de R base: `cor.test`, `t.test`, `aov`, `TukeyHSD`, `oneway.test`, `kruskal.test`, `lm`, `glm`, `chisq.test`, `fisher.test` y `kmeans`;
- paquetes de referencia: `MASS`, `nnet`, `emmeans`, `psych`, `lavaan`, `cluster` y `seminr`;
- fórmulas directas para tamaños de efecto, AUC, CR, AVE, HTMT, VIF, f², V de Aiken y bootstrap.

La puerta global es:

```bash
tests/run_numerical_certification.sh
```

Primero ejecuta la regresión estadística histórica y luego la nueva certificación independiente. Un solo fallo detiene la liberación.

## 5. Motor PLS-SEM

El núcleo mantiene selección de columnas bootstrap por nombres y falla de forma cerrada si cambia el esquema de `seminr`. Además, la ampliación incorpora:

- Q² Stone–Geisser mediante omisión, reestimación y predicción estructural;
- PLS-Predict con reestimación por fold y benchmarks LM/media;
- HTMT inferencial desde `boot_HTMT`;
- SRMR compuesto saturado y estimado como diagnósticos descriptivos;
- Full VIF, VAF/Zhao sobre el efecto indirecto total conjunto e IPMA;
- cópula gaussiana opt-in con ECDF ajustada F4, constructo de un indicador, reestimación PLS y bootstrap;
- MICOM y MGA por permutación con reestimación PLS y corrección Holm.

Los módulos avanzados retornan un estado explícito. MICOM/MGA usan 5,000 permutaciones por defecto; un número menor queda marcado como exploratorio. La cópula solo se ejecuta cuando el usuario la activa y se confirma la no normalidad del predictor; su ausencia de significación no se interpreta como prueba de exogeneidad. MGA exige invarianza composicional de todos los constructos requeridos para el par de grupos.

## 6. Procedimientos no certificados

La lista oficial está en `VALIDATION_SCOPE.md` y `AUDIT/METHOD_CERTIFICATION_MATRIX.csv`. Los procedimientos bloqueados no deben presentarse como disponibles ni sustituirse por aproximaciones con otra etiqueta.

## 7. Reproducción local

```bash
npm run install:r
tests/run_numerical_certification.sh
npm run build --workspace apps/api
npm run build --workspace apps/web
docker compose up -d --build
```

Después se debe ejecutar al menos un caso extremo a extremo por familia y comprobar igualdad entre pantalla y Word.

## 8. Integración web PLS-SEM avanzada

La versión web avanzada conecta las cinco capas del flujo:

```text
Formulario Next.js → contrato NestJS → motor R → tablas web → Word APA 7
```

### 8.1 Configuración disponible

- bootstrap y semilla reproducible;
- Q²: distancia de omisión;
- PLS-Predict: folds y repeticiones;
- Full VIF: umbral configurable;
- IPMA: constructo objetivo y límites teóricos de la escala;
- cópula: activación explícita y número de remuestreos;
- MICOM/MGA: variable de agrupación y permutaciones;
- variables de control: columna, nombre y constructos resultado;
- FIMIX: K mínimo/máximo, inicios EM, iteraciones y tolerancia;
- comparación de modelos: roles X, M1, M2 e Y.

### 8.2 FIMIX-PLS

FIMIX usa `seminrExtras::assess_fimix_compare()` y conserva para cada K los criterios de información, convergencia y solución. La interfaz presenta la solución seleccionada, tamaños/proporciones, coeficientes por segmento y fuente de agrupación usada por MICOM/MGA. Las asignaciones observación-segmento permanecen en el contrato de resultados, pero no se insertan completas en Word para evitar informes innecesariamente extensos.

### 8.3 Controles y mediación

Las variables de control se modelan como constructos de un indicador mediante `seminr::single_item()`. Sus rutas se distinguen de las hipótesis y no se incluyen en la numeración H1...Hn. El reporte muestra por separado rutas directas, efectos indirectos específicos, suma indirecta total y efectos totales.

### 8.4 Comparación de modelos

Los modelos directo, paralelo y secuencial se reestiman bajo la misma medición y casos analíticos. Se reportan R² promedio, R² ajustado promedio, Q² promedio y SRMR saturado/estimado. La salida se rotula como descriptiva/predictiva y no como prueba automática de superioridad causal.

### 8.5 Puerta ampliada

La entrega agrega:

- `tests/certification/test_pls_sem_web_workflow.R`;
- `tests/certification/test_pls_sem_web_contract_static.py`.

El resultado local esperado es `16 PASS | 0 FAIL` en la Fase 2 y 37 pruebas aprobadas en el consolidado completo.
