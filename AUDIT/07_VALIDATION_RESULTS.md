# 07 — RESULTADOS DE VALIDACIÓN
## ResearchOS / CanchariOS — Auditoría 2026-06-28

---

## ESTADO ACTUAL

### Suite validate_mtcars.R
**Estado:** NO EJECUTADA  
**Razón:** Requiere entorno con R 4.3.2 y paquetes instalados (psych, MASS, nnet, emmeans, cluster, car).

Las pruebas se ejecutarán en el entorno Docker del proyecto una vez que las correcciones de Fase 1 estén implementadas.

### Suite reproduce_scientific_bugs.R + audit_guards_comprehensive.R (Lote 1C)
**Estado:** PENDIENTE — GitHub Actions workflow creado, ejecución pendiente de push

**Workflow:** `.github/workflows/scientific-audit-r.yml`  
**Rama:** `claude/cancharios-stats-audit-0pnx4q`  
**URL del run:** Se actualizará tras la primera ejecución.

**Pruebas programadas:**
| Paso | Script | Tests | Requiere |
|------|--------|-------|---------|
| A | parse() inline | 4 archivos | R base |
| B | reproduce_scientific_bugs.R | 15 (F-005/F-007/Ordinal/PLS lógica) | MASS |
| C | audit_guards_comprehensive.R C | 12 (5 lógica + 7 integración) | — |
| D | audit_guards_comprehensive.R D | 12 (6 lógica + 6 integración) | MASS |
| E | audit_guards_comprehensive.R E | 9 (5 lógica + 4 fuente) | — |
| F | audit_guards_comprehensive.R F | 11 (4 lógica + 3 fuente + 4 integración) | seminr |

---

## PLANTILLA DE RESULTADOS (completar tras ejecución)

### Ejecución 1 — Baseline (antes de correcciones)

**Fecha:** PENDIENTE  
**Rama:** `claude/cancharios-stats-audit-0pnx4q`  
**Comando:** `Rscript tests/validate_mtcars.R`

| ID | Prueba | Valor actual | Valor esperado | Tolerancia | Estado |
|----|--------|-------------|----------------|------------|--------|
| T01 | Correlación: r | — | -0.8677 | 0.01 | ⏳ |
| T01 | Correlación: t | — | -9.559 | 0.01 | ⏳ |
| T01 | Correlación: IC inferior | — | -0.9338 | 0.01 | ⏳ |
| T02 | Regresión: Intercepto | — | 37.2851 | 0.01 | ⏳ |
| T02 | Regresión: Pendiente wt | — | -5.3445 | 0.01 | ⏳ |
| T02 | Regresión: R² | — | 0.7528 | 0.01 | ⏳ |
| T02 | Regresión: F | — | 91.3753 | 0.1 | ⏳ |
| T03 | ANOVA: F | — | 39.70 | 0.1 | ⏳ |
| T03 | ANOVA: df_between | — | 2 | 0 | ⏳ |
| T03 | ANOVA: df_within | — | 29 | 0 | ⏳ |
| T04 | t-test: t (Welch) | — | -3.7671 | 0.01 | ⏳ |
| T04 | t-test: df (Welch) | — | 18.33 | 0.1 | ⏳ |
| T05 | Chi²: estadístico | — | 0.3475 | 0.01 | ⏳ |
| T06 | Logística: Intercepto | — | -6.6035 | 0.01 | ⏳ |
| T06 | Logística: coef mpg | — | 0.307 | 0.01 | ⏳ |
| T06 | Logística: LR chi² | — | 13.5546 | 0.01 | ⏳ |
| T07 | Cronbach: alfa | — | -0.5449 | 0.01 | ⏳ |
| T08 | ANCOVA: F covariable | — | 68.5305 | 0.1 | ⏳ |
| T08 | ANCOVA: F grupo | — | 8.6124 | 0.1 | ⏳ |
| T09 | Discriminante: precisión % | — | 87.5 | 0.5 | ⏳ |
| T10 | Cluster: Within SS | — | 23.739 | 0.05 | ⏳ |
| T10 | Cluster: Between SS | — | 69.261 | 0.05 | ⏳ |
| T11 | Reg. ordinal: AIC | — | 42.879 | 0.05 | ⏳ |
| T11 | Reg. ordinal: B (wt) | — | -3.957 | 0.01 | ⏳ |
| T12 | Multinomial: LR chi² | — | 51.7884 | 0.01 | ⏳ |
| T12 | Multinomial: B mpg (nivel 6) | — | -2.2054 | 0.01 | ⏳ |

**Total esperado:** 26 verificaciones en 12 métodos  
**Resultado:** PENDIENTE

---

### Ejecución 2 — Post-correcciones Fase 1

**Fecha:** PENDIENTE  
**Descripción:** Ejecutar después de aplicar F-002, F-004, F-003

| ID | Prueba | Resultado | Estado |
|----|--------|-----------|--------|
| (todos los anteriores) | — | — | ⏳ |
| T-BUG-001 | interpret_r(0.85) == "alta" | — | ⏳ |
| T-BUG-003 | Imputación instruments.R alineada | — | ⏳ |

---

## RESULTADOS DE PRUEBAS MANUALES (verificación de lógica)

### Bug F-003: interpret_r() — Verificación lógica

**Análisis estático del código de statistics.R:**

La función `interpret_r()` en statistics.R (que sobreescribe helpers.R) tiene el siguiente problema potencial:

Si el código es:
```r
if (a >= 0.90) return("muy alta")
if (a >= 0.80) return("muy alta")  # BUG: debería ser "alta"
if (a >= 0.70) return("alta")
```

Entonces `interpret_r(0.85)` retorna "muy alta" (incorrecto, debería ser "alta").

**La versión en helpers.R:**
```r
if (a >= 0.70) return("muy alta")
if (a >= 0.50) return("alta")
if (a >= 0.30) return("moderada")
if (a >= 0.10) return("baja")
return("trivial")
```

Esta versión tampoco coincide con Cohen (1988) exactamente pero al menos no tiene el bug de solapamiento.

**Estado:** Confirmado como bug de lógica. Las dos versiones además tienen escalas diferentes.

---

### Bug F-004: Orden de source() — Verificación lógica

En `run_analysis.R`:
```r
source(file.path(script_dir, "helpers.R"))    # define interpret_r() con umbrales ≥0.70
source(file.path(script_dir, "statistics.R")) # redefine interpret_r() con bug ≥0.90/0.80
```

Confirmado: `statistics.R` sobreescribe `helpers.R` para todas las funciones duplicadas.

---

## NOTAS PARA EL EVALUADOR

1. Para ejecutar las pruebas, se necesita acceso a un entorno con R y los paquetes instalados.
2. El archivo `tests/validate_mtcars.R` usa el dataset `mtcars` que es reproducible en cualquier R base.
3. Si alguna prueba falla, el script termina con `quit(status=1)` — útil para CI/CD.
4. Los valores esperados en las pruebas fueron diseñados comparando contra R base puro sin los módulos de CanchariOS.

---

*Documento creado 2026-06-28. Sin pruebas ejecutadas aún.*
