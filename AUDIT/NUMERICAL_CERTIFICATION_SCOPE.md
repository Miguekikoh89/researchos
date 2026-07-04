# Auditoría de certificación numérica integral

## Objetivo

Evitar que CanchariOS marque un análisis como exitoso únicamente porque el código se ejecutó. Cada familia activa debe tener una referencia numérica reproducible y cada salida incompleta debe fallar de forma cerrada.

## Cambios centrales

1. Contrato API recursivo para errores anidados y números no finitos.
2. Precisión completa para inferencia; redondeo solo en presentación.
3. Reglas explícitas de muestra, varianza, niveles y convergencia.
4. Semillas reproducibles y restauración del RNG.
5. Pruebas de fórmulas y wrappers frente a R base y paquetes de referencia.
6. Estado explícito por módulo: implementado, exploratorio, no aplicable, desactivado o `failed_closed`.
7. Único motor R canónico: `apps/api/stats-engine-r`, sincronizado con las dos copias de despliegue.
8. Conversión numérica estricta: etiquetas numéricas válidas se preservan; texto, `Inf` y `-Inf` se bloquean.
9. PLS-SEM avanzado conectado a API, pantalla y Word con una prueba numérica independiente nueva.

## PLS-SEM avanzado cubierto por la nueva prueba

`tests/certification/test_pls_sem_advanced.R` contrasta:

- PLS-Predict contra las matrices fuera de muestra de `seminr::predict_pls`;
- IC HTMT contra cuantiles directos de `boot_HTMT`;
- identidad Q² = `1 - SSE/SSO` y omisiones válidas;
- Full VIF contra regresiones auxiliares directas;
- IPMA contra pesos desestandarizados y límites teóricos;
- VAF/Zhao con suma bootstrap de rutas indirectas, SRMR saturado/estimado y estados fail-closed;
- MICOM y MGA con reestimación por permutación, ajuste Holm y requisito de invarianza composicional completa;
- cópula gaussiana con ECDF ajustada F4, constructo de un indicador, reestimación PLS, no normalidad previa y bootstrap.

## Criterio de aprobación

```text
Regresión histórica: 0 FAIL
Certificación por familias: 0 FAIL
Sintaxis R: correcta
API build: correcto
Web build: correcto
Docker: DB healthy, web 200, API protegida 401
Casos E2E: pantalla = Word = referencia
```

## Estado

El núcleo anterior fue ejecutado por el usuario con 13 PASS y 0 FAIL. La ampliación avanzada todavía debe ejecutar la nueva puerta en un entorno con R y las dependencias instaladas. Hasta entonces, la etiqueta correcta para estos módulos es **implementación candidata pendiente de certificación local**.
