# Estado de certificación de CanchariOS

Fecha de cierre: 2026-07-05
Rama auditada: `release/pls-web-advanced-v2`

## Resultado consolidado

- Núcleo estadístico: **113/113 PASS**
- Métodos extendidos: **75/75 PASS**
- Total: **188/188 comprobaciones satisfactorias**
- Base real utilizada: **384 participantes**

## Corrección funcional incorporada

Se corrigió el enrutamiento de comparaciones pareadas en:

- `apps/api/stats-engine-r/run_analysis.R`
- `apps/stats-engine-r/run_analysis.R`

La comparación pareada ahora utiliza directamente `var_a` y `var_b`, sin exigir una variable de agrupación. La ruta para muestras independientes conserva el requisito de `group_var`.

## Alcance validado

La certificación cubre descriptivos, confiabilidad, baremos, frecuencias, regresiones, mediación, pruebas t, Welch, ANOVA, ANCOVA, chi-cuadrado, regresión logística binaria y multinomial, regresión ordinal, análisis discriminante y clúster.

El análisis discriminante final se verificó sin fuga del criterio, empleando PGV e IER para clasificar TV3_1.

## Evidencias

- `03c7_baremo_racional_final.txt`
- `04d1_discriminante_diagnostico_final.txt`
- `04d2_extended_final_numeric_audit_sin_fuga.txt`
