# 03 — PLAN DE PRUEBAS
## ResearchOS / CanchariOS — Auditoría 2026-06-28

---

## 1. ESTRATEGIA GENERAL

Tres niveles de prueba:
1. **Validación numérica (ya existe):** `tests/validate_mtcars.R` — comparación vs. valores de referencia con tolerancia 0.01
2. **Pruebas de supuestos y edge cases:** datasets diseñados para violar o estresar supuestos estadísticos
3. **Pruebas de regresión de bugs:** casos específicos que demuestran los hallazgos F-001 a F-023

---

## 2. ESTADO ACTUAL DE LA SUITE DE VALIDACIÓN

### tests/validate_mtcars.R — 12 pruebas implementadas

| ID | Método | Variable de prueba | Estado |
|----|--------|--------------------|--------|
| T01 | Correlación Pearson (mpg, wt) | r=-0.8677, t=-9.559, IC_inf=-0.9338 | ❓ NO EJECUTADO |
| T02 | Regresión lineal (mpg~wt) | B_intercept=37.2851, B_wt=-5.3445, R²=0.7528, F=91.3753 | ❓ NO EJECUTADO |
| T03 | ANOVA (mpg~cyl) | F=39.70, df1=2, df2=29 | ❓ NO EJECUTADO |
| T04 | t-test Welch (mpg~am) | t=-3.7671, df=18.33 | ❓ NO EJECUTADO |
| T05 | Chi-cuadrado con Yates (am vs vs) | χ²=0.3475 | ❓ NO EJECUTADO |
| T06 | Logística binaria (am~mpg) | B_interc=-6.6035, B_mpg=0.307, LR=13.5546 | ❓ NO EJECUTADO |
| T07 | Alfa de Cronbach (wt, qsec, drat) | α=-0.5449 (valor negativo esperado — prueba extrema) | ❓ NO EJECUTADO |
| T08 | ANCOVA (mpg~cyl+hp) | F_hp=68.5305, F_cyl=8.6124 | ❓ NO EJECUTADO |
| T09 | Discriminante (cyl~mpg+hp+wt) | precisión=87.5% | ❓ NO EJECUTADO |
| T10 | K-means (mpg, wt, hp, k=3) | within_ss=23.739, between_ss=69.261 | ❓ NO EJECUTADO |
| T11 | Regresión ordinal (mpg_ord~wt) | AIC=42.879, B_wt=-3.957 | ❓ NO EJECUTADO |
| T12 | Logística multinomial (cyl~mpg) | LR=51.7884, B_mpg(nivel6)=-2.2054 | ❓ NO EJECUTADO |

**Métodos NO cubiertos por la suite actual:**
- Mann-Whitney U / Wilcoxon pareado
- Kruskal-Wallis + post-hoc Dunn
- Correlación Spearman
- Correlación matricial
- PLS-SEM
- Instrumentos (AFE + AFC + HTMT)
- Frecuencias
- Baremos
- Descriptivos completos
- Regresión jerárquica
- ANCOVA post-hoc

---

## 3. CASOS DE PRUEBA ADICIONALES PLANIFICADOS

### 3.1 Pruebas de Regresión de Bugs

#### T-BUG-001: Bug F-003 — interpret_r() con r=0.85
```r
# Esperado según Cohen (1988) y helpers.R: "alta"
# Bug en statistics.R devuelve: "muy alta"
result <- interpret_r(0.85)  # debe ser "alta" no "muy alta"
```
**Dataset:** Cualquier dato con correlación entre 0.80 y 0.89
**Valor esperado:** `"alta"`
**Método de comparación:** Llamada directa a la función

#### T-BUG-002: Bug F-001 — compute_omega() verificación
```r
# Dataset con cargas conocidas: λ = [0.8, 0.7, 0.9]
# ω esperado = (0.8+0.7+0.9)² / [(0.8+0.7+0.9)² + (1-0.64)+(1-0.49)+(1-0.81)]
# ω esperado = (2.4)² / [(2.4)² + 0.36+0.51+0.19]
# ω esperado = 5.76 / (5.76 + 1.06) = 5.76 / 6.82 ≈ 0.844
```
**Dataset:** Matriz de correlaciones con cargas conocidas
**Método:** Comparar output con cálculo manual

#### T-BUG-003: Bug F-006 — Imputación desalineada instruments.R
```r
# Crear dataset con NAs en distintas columnas distintas filas
df_test <- data.frame(
  i1 = c(1, NA, 3, 4, 5),
  i2 = c(NA, 2, 3, 4, 5),
  i3 = c(1, 2, 3, NA, 5)
)
# Verificar que cada NA se reemplaza con la media de SU columna
```

#### T-BUG-004: Bug F-007 — Binarización silenciosa logística
```r
# y con valores continuos 1-5
y_continuo <- c(1, 2, 3, 4, 5, 3, 2, 4, 1, 5)
result <- compute_logistic(y_continuo, X_data, type="binaria")
# Verificar que result contiene campo "warning" sobre binarización
```

#### T-BUG-005: Bug F-015 — df hardcoded en PLS-SEM indirecto
```r
# Con n=50 vs n=384: los p-values del efecto indirecto NO deberían ser idénticos
# Con df=max(384-1,1)=383 para ambos, serán casi idénticos (incorrecto)
```

---

### 3.2 Pruebas de Edge Cases

#### T-EDGE-001: Muestra mínima (n=3 por grupo)
```r
# t-test con n_min=3 (borde del umbral en compute_ttest)
x1 <- c(1, 2, 3)
x2 <- c(4, 5, 6)
result <- compute_ttest(x1, x2, type="independiente")
# Debe completar sin error
```

#### T-EDGE-002: Varianzas iguales a 0 (constante)
```r
x1 <- c(5, 5, 5, 5, 5)
x2 <- c(3, 4, 5, 6, 7)
# Levene debe detectar homocedasticidad extrema
# Cohen's d debe dar NA o Inf
```

#### T-EDGE-003: Alfa de Cronbach negativo (consistencia interna inversa)
```r
# mtcars wt + qsec + drat tiene alfa = -0.5449 (ya en T07)
# Verificar que se reporta correctamente como "Inaceptable" sin error
```

#### T-EDGE-004: Chi-cuadrado con frecuencias esperadas < 5
```r
# Tabla 3x3 con n=10: muchas celdas con expected < 5
# Fisher debe activarse automáticamente o advertencia debe generarse
```

#### T-EDGE-005: PLS-SEM con constructo de 1 ítem
```r
# Verificar que el constructo único se duplica correctamente
# y que los resultados son coherentes
```

#### T-EDGE-006: Regresión con multicolinealidad perfecta
```r
# X1 = X2 exactamente
# VIF debe dar Inf o valor muy grande
# Modelo debe manejarse sin crash
```

---

### 3.3 Pruebas de Dataset Adversarial

#### T-ADV-001: Dataset con outliers extremos
```r
# Outlier 10 DE por encima de la media
# Verificar que decide_method() cambia a no-paramétrico
```

#### T-ADV-002: Dataset con NAs masivos (>50% de valores faltantes)
```r
# Verificar comportamiento de imputación y si análisis procede o falla con error útil
```

#### T-ADV-003: Dataset con un solo nivel en variable categórica de ANOVA
```r
grupos <- rep("A", 30)  # Solo un grupo
# Debe fallar con error descriptivo, no crash R
```

#### T-ADV-004: Dataset pequeño para PLS-SEM (n < número de parámetros)
```r
# n=10 con 5 constructos de 3 ítems cada uno
# Debe advertir sobre poder estadístico insuficiente
```

---

## 4. COBERTURA OBJETIVO

| Área | Pruebas existentes | Pruebas nuevas propuestas | Total objetivo |
|------|-------------------|--------------------------|----------------|
| Bugs confirmados (F-001 a F-007) | 0 | 5 | 5 |
| Edge cases estadísticos | 1 (T07 alfa negativo) | 5 | 6 |
| Adversariales | 0 | 4 | 4 |
| Regresión numérica (métodos) | 12 | 8 (métodos faltantes) | 20 |
| **TOTAL** | **13** | **22** | **35** |

---

## 5. CÓMO EJECUTAR LAS PRUEBAS EXISTENTES

```bash
# Desde el directorio raíz del repositorio
# Requiere R instalado y paquetes del motor

export CANCHARIOS_R_DIR=/home/user/researchos/apps/api/stats-engine-r/R
Rscript tests/validate_mtcars.R

# Exit code 0 = todos pasaron
# Exit code 1 = al menos una prueba falló
```

**Prerequisito:** Los paquetes R deben estar instalados. En entorno Docker:
```bash
docker exec <container> Rscript /app/stats-engine-r/install_packages.R
docker exec <container> Rscript /app/tests/validate_mtcars.R
```

---

## 6. CRITERIOS DE ACEPTACIÓN

### Para considerar un método "validado":
1. Todas las pruebas numéricas pasan con tolerancia ≤ 0.01
2. No hay crashes con datasets de edge-case
3. Los mensajes de error son descriptivos (no stack traces de R)
4. El output JSON contiene todos los campos del estándar APA 7 para ese método

### Para considerar el sistema "listo para producción":
1. 100% de pruebas en `validate_mtcars.R` pasan
2. Los bugs P0 y P1 están corregidos y verificados
3. Al menos 30 de 35 pruebas propuestas pasan
4. El docker build completa sin error
5. Un análisis end-to-end (desde upload hasta Word descargado) funciona para cada método

---

*Plan de pruebas creado 2026-06-28. Ninguna prueba ejecutada aún.*
