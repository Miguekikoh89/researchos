# Alcance de certificación numérica de CanchariOS

**Fecha de actualización:** 2026-07-04  
**Estado:** el núcleo previamente certificado conserva sus pruebas; la ampliación PLS-SEM avanzada queda como **candidata pendiente de ejecutar la nueva puerta R completa**.

## Qué significa “certificado”

Un método solo puede marcarse como **CERTIFICADO LOCALMENTE** cuando cumple simultáneamente:

1. su resultado se contrasta con una función o fórmula de referencia independiente;
2. coinciden el estadístico, el valor *p*, los grados de libertad, los intervalos y el tamaño de efecto aplicable;
3. no se redondea antes de tomar decisiones;
4. cualquier NaN, infinito, error embebido o resultado incompleto hace fallar el job o el módulo de forma explícita;
5. el resultado coincide entre R, API, pantalla y Word en una prueba extremo a extremo;
6. las puertas de pruebas, las compilaciones y Docker terminan sin errores.

“Certificado” no significa equivalencia universal con todos los programas comerciales. Significa que el cálculo fue reproducido dentro de los casos, supuestos y restricciones documentados.

## Puertas obligatorias

```bash
tests/run_numerical_certification.sh
npm run build --workspace apps/api
npm run build --workspace apps/web
docker compose up -d --build
```

No debe liberarse una ampliación cuando alguna orden falla.

## Estado histórico previo a esta ampliación

El 4 de julio de 2026 el usuario ejecutó la puerta anterior y obtuvo:

```text
CERTIFICACIÓN: 13 PASS | 0 FAIL
PUERTA DE CERTIFICACIÓN NUMÉRICA SUPERADA
RESULTADO GLOBAL: CERTIFICACIÓN LOCAL SUPERADA
```

Ese resultado certificó el alcance anterior. La incorporación de `test_pls_sem_advanced.R` modifica la puerta y exige una nueva ejecución local antes de declarar certificados los módulos avanzados.

## Núcleo PLS-SEM activo

- Cargas externas.
- Alfa, rho_A, fiabilidad compuesta y AVE.
- HTMT puntual, Fornell–Larcker y cargas cruzadas.
- VIF de constructos.
- Rutas estructurales con bootstrap de al menos 1,000 remuestras.
- IC bootstrap percentil como criterio inferencial primario.
- R², R² ajustado y f².
- Efectos indirectos y totales cuando el esquema bootstrap de `seminr` es reconocido.

## Ampliación PLS-SEM avanzada implementada

- **Q² de Stone–Geisser:** omisión sistemática de indicadores endógenos, reestimación del modelo y predicción estructural del constructo.
- **PLS-Predict:** reestimación PLS por fold mediante `seminr::predict_pls`, comparación con LM y media del entrenamiento, RMSE, MAE y Q²_predict. Configuración productiva predeterminada: 10 folds y 10 repeticiones.
- **HTMT inferencial:** IC percentil desde `boot_HTMT` del mismo bootstrap SEMinR.
- **SRMR compuesto saturado y estimado:** dos diagnósticos descriptivos diferenciados; ninguno se presenta como prueba global concluyente.
- **Full collinearity VIF:** diagnóstico de posible CMB, no prueba definitiva de sesgo de método común.
- **VAF y mediación:** suma todas las rutas indirectas específicas que comparten origen y destino, reconstruye el IC bootstrap del efecto indirecto total conjunto y aplica la clasificación de Zhao; VAF solo se informa cuando directo e indirecto son significativos, concordantes y el total es estable.
- **IPMA:** efectos totales como importancia y desempeño 0–100 calculado con pesos desestandarizados y límites teóricos de la escala.
- **Cópula gaussiana:** opt-in por ruta; exige no normalidad previa del predictor, usa la ECDF ajustada F4, incorpora un constructo copular de un indicador, reestima el modelo PLS y aplica bootstrap condicional al término copular generado en la etapa 1. Un término no significativo no demuestra exogeneidad.
- **MICOM:** modelo agrupado de referencia, pesos reestimados en cada permutación, correlación composicional, diferencias de medias, diferencias logarítmicas de varianzas y ajuste Holm.
- **MGA por permutación:** solo después de que todos los constructos requeridos alcancen invarianza composicional en el par de grupos; reestimación PLS en cada réplica y ajuste Holm.

## Configuración confirmatoria

- Bootstrap PLS-SEM: mínimo 1,000; predeterminado de la API: 5,000.
- MICOM/MGA: predeterminado 5,000 permutaciones; ejecuciones menores quedan rotuladas `implemented_exploratory_lt_5000_permutations`.
- Cópula gaussiana: desactivada por defecto, activable de manera explícita y con 5,000 bootstrap por defecto; menos de 5,000 queda rotulado como exploratorio.
- MICOM/MGA: solo aplican cuando se especifica una variable de grupo con al menos dos grupos de 30 casos válidos cada uno.
- IPMA: requiere límites teóricos correctos de la escala y bloquea valores fuera de rango.

## Estados de módulos

- `implemented`: cálculo completado con contrato válido.
- `implemented_exploratory_lt_5000_permutations`: cálculo válido, pero con menos de 5,000 permutaciones.
- `not_applicable...`: no corresponde al modelo o a los datos.
- `disabled_by_configuration...`: desactivado por configuración.
- `failed_closed: ...`: se produjo un error y el motor bloqueó ese procedimiento en lugar de inventar una aproximación.

## Procedimientos que continúan bloqueados

- Stepwise, forward y backward en regresión lineal.
- Selección automática stepwise en discriminante y logística.
- Mediación serial o paralela múltiple fuera del módulo PLS-SEM sin una certificación separada; dentro de PLS-SEM, los efectos específicos y el efecto indirecto total conjunto permanecen pendientes de la nueva puerta avanzada.
- Fabricar una variable ordinal promediando varios ítems.
- IC de V de Aiken no contrastado.
- Cualquier análisis PLS-SEM avanzado que no supere su tabla, contrato y prueba específica.

## Tolerancias

- Valores sin redondear: tolerancia general `1e-8`, salvo que una prueba documente otra.
- Salidas deliberadamente redondeadas: igualdad al número de decimales persistido.
- Bootstrap: semilla fija y restauración del estado aleatorio.
- HTMT bootstrap, MICOM, MGA y cópula: al menos 80% de réplicas válidas.

## Estado de esta entrega

La revisión estática, la sincronización de las tres copias del motor y el contrato Python se verifican dentro del entorno de preparación. Este entorno no dispone de R, por lo que `test_pls_sem_advanced.R` debe ejecutarse en la Mac del usuario antes de declarar **14 PASS | 0 FAIL** o cualquier otra cifra final.

## Ampliación web avanzada — 2026-07-04

Después de la certificación histórica de 14 pruebas numéricas, la interfaz, API y Word se ampliaron para exponer el motor avanzado. Esta nueva entrega añade dos pruebas y modifica el alcance de liberación:

- **Fase 1:** 21 pruebas de regresión estadística.
- **Fase 2:** 16 pruebas de certificación, incluidas integración web y flujo R con controles, mediación, comparación de modelos y FIMIX.
- **Resultado exigido:** 37 PASS | 0 FAIL en el consolidado.

Hasta ejecutar la puerta completa en un entorno con R y `seminrExtras`, la ampliación web se considera implementada y compilada, pero pendiente de recertificación local. La certificación anterior de 35 pruebas continúa siendo válida para la línea base anterior, no para las funciones web añadidas en esta entrega.
