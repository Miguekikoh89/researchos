# CanchariOS — Documentación Técnica del Motor Estadístico

**Versión:** 1.0 (auditoría completa, junio 2026)
**Autor:** Miguel Angel Canchari-Preciado
**Repositorio:** https://github.com/Miguekikoh89/researchos

---

## 1. Resumen

CanchariOS es una plataforma web que automatiza el análisis estadístico para
investigación en ciencias sociales y administrativas, integrando un motor de
cálculo en R, un asistente metodológico basado en reglas de decisión citadas
académicamente, y generación automática de reportes en formato APA 7 (Word).

Esta documentación describe la arquitectura del motor estadístico, los 17
métodos implementados, la metodología de validación numérica, y las
limitaciones conocidas del sistema en su estado actual.

---

## 2. Arquitectura

```
Frontend (Next.js/React/TypeScript)
  └─ Wizard de 6 pasos: Método → Subir datos → Configurar → Analizar → Resultados → Exportar
  └─ Asistente metodológico: Variables → Dimensiones → Objetivo → Hipótesis → Recomendación
  └─ Motor de recomendación (lib/methodRecommendation.ts) — TypeScript, sin dependencias R

Backend (NestJS/TypeScript)
  └─ analysis.service.ts — orquesta la ejecución del motor R via subprocess (Rscript)
  └─ Prisma/PostgreSQL — persistencia de resultados (JSON por método)

Motor estadístico (R, ejecutado vía Rscript en contenedor Docker)
  └─ run_analysis.R — punto de entrada único, despacha segun analysis_category
  └─ 17 archivos .R, uno o mas por método estadístico (ver Sección 3)
  └─ word_export.R — generación de reportes .docx con tablas APA 7
```

El motor R se invoca como subproceso desde Node.js (NestJS), recibiendo un
JSON de configuración y devolviendo un JSON de resultados. No hay estado
compartido entre invocaciones; cada análisis es una ejecución independiente
de `Rscript run_analysis.R <config.json> <output_dir>`.

---

## 3. Métodos estadísticos implementados (17)

| # | Método | Archivo(s) R | Paquetes R externos |
|---|--------|--------------|----------------------|
| 1 | PLS-SEM | `pls_sem_engine.R` | `seminr` |
| 2 | Correlación (Pearson/Spearman/Kendall) | `statistics.R` | base R |
| 3 | Regresión lineal (Enter/Stepwise/Forward/Backward) | `regression.R` | base R |
| 4 | Regresión ordinal | `ordinal_regression.R` | `MASS` |
| 5 | Regresión jerárquica | `hierarchical_regression.R` | base R |
| 6 | Regresión logística binaria | `logistic.R` | base R |
| 6b | Regresión logística multinomial | `logistic_multinomial.R` | `nnet` |
| 7 | Comparación de grupos (t/Welch/Mann-Whitney/Wilcoxon) | `t_test.R` | base R |
| 8 | ANOVA (+ post-hoc Tukey/Bonferroni/Scheffé/Games-Howell/Dunn) | `anova.R` | base R |
| 9 | ANCOVA | `ancova.R` | `emmeans` |
| 10 | Análisis discriminante | `discriminant.R` | `MASS`, `klaR` |
| 11 | Chi-cuadrado (Pearson/Yates/Fisher) | `chi_square.R` | base R |
| 12 | Análisis clúster (K-means) | `cluster.R` | `cluster` |
| 13 | Validación de instrumento (KMO, AFE, AFC, HTMT, V de Aiken) | `instruments.R` | `psych`, `lavaan` |
| 14 | Alfa de Cronbach (+ Omega McDonald) | `cronbach_only.R` | `psych` |
| 15 | Análisis Descriptivo (+ baremos, niveles) | `analisis_descriptivo.R` | base R |

Cada método selecciona automáticamente entre alternativas paramétricas y no
paramétricas según pruebas de supuestos (normalidad vía Shapiro-Wilk,
homogeneidad de varianzas vía Levene), evaluadas internamente antes de
reportar el resultado final.

---

## 4. Motor de recomendación metodológica

El archivo `apps/web/src/lib/methodRecommendation.ts` implementa una tabla de
decisión que recomienda el método estadístico adecuado a partir de:

- Escala de medición de la variable resultado (Nominal/Ordinal/Intervalo/Razón)
- Escala de la variable explicativa
- Presencia y tipo de covariable (ninguna/continua/categórica)
- Propósito de la investigación (relacionar/predecir/comparar/clasificar/asociar),
  solicitado únicamente cuando la combinación de escalas es ambigua

### 4.1 Fundamento académico

La lógica de decisión está basada en:

- Flores-Ruiz, E., Miranda-Novales, M. G., & Villasís-Keever, M. Á. (2017).
  Selección de la prueba estadística adecuada. *Revista Alergia México*, 64(3), 364-370.
- Field, A. (2013). *Discovering Statistics Using IBM SPSS Statistics*. SAGE.
- Hair, J. F., Black, W. C., Babin, B. J., & Anderson, R. E. (2019).
  *Multivariate Data Analysis* (8th ed.). Cengage.
- Cohen, J., Cohen, P., West, S. G., & Aiken, L. S. (2003). *Applied Multiple
  Regression/Correlation Analysis for the Behavioral Sciences* (3rd ed.).

### 4.2 Cobertura de pruebas

La función `recommendMethod()` fue probada exhaustivamente con las **168
combinaciones posibles** de escala (resultado × explicativa) × covariable ×
propósito, confirmando 0 casos de fallback genérico y 0 recomendaciones de
confianza inesperadamente baja. El script de prueba no persiste en el
repositorio (se ejecutó de forma ad-hoc); se recomienda agregar como test
unitario formal (ver Sección 6, Limitaciones).

---

## 5. Validación numérica

### 5.1 Metodología

Se comparó la salida de 12 motores R de CanchariOS contra los mismos cálculos
realizados con funciones base de R (`cor.test`, `lm`, `aov`, `t.test`,
`chisq.test`, `glm`, `polr`, `multinom`, `lda`, `kmeans`), usando el dataset
público `mtcars` (32 observaciones, librería `datasets` de R base),
completamente reproducible por terceros sin necesidad de datos propietarios.

### 5.2 Resultados

26 aserciones numéricas en 12 métodos, con tolerancia de ±0.01 a ±0.1
(según la magnitud del estadístico) para absorber redondeo. Resultado:
**26/26 aserciones correctas** tras corrección de 4 errores detectados:

| Error encontrado | Método afectado | Causa | Estado |
|---|---|---|---|
| Etiqueta "corrección de Yates" no coincidía con el valor reportado | Chi-cuadrado | El campo de salida principal usaba el estadístico sin corregir, aunque la corrección sí se calculaba internamente | Corregido |
| Fallo silencioso por dependencia faltante | ANCOVA | Paquete `emmeans` no instalado en el entorno de ejecución | Corregido (paquete instalado) |
| Parámetros de personalización no aplicados | Análisis clúster | Regresión de código: una actualización previa no persistió correctamente en el entorno de ejecución | Corregido y re-verificado |
| Error de dimensiones con un único predictor | Regresión ordinal | `confint()` en objetos `polr` devuelve un vector (no matriz) cuando el modelo tiene un solo predictor | Corregido (manejo de ambos casos) |

El script de validación (`tests/validate_mtcars.R`) está disponible en el
repositorio y puede ejecutarse en cualquier momento para detectar regresiones:

```bash
Rscript tests/validate_mtcars.R
```

---

## 6. Limitaciones conocidas

1. **Cobertura de validación numérica parcial.** Se validaron 12 de 17
   métodos contra R base. Quedan pendientes: PLS-SEM, Validación de
   instrumento (AFE/AFC/V de Aiken), Análisis Descriptivo, y Regresión
   jerárquica, por la complejidad de construir un caso de referencia
   independiente para cada uno.
2. **Sin suite de tests unitarios formal en TypeScript.** El motor de
   recomendación fue probado exhaustivamente de forma ad-hoc (168
   combinaciones), pero esas pruebas no están versionadas como archivo de
   test ejecutable repetible (`*.test.ts`).
3. **Sin entorno de staging/CI-CD.** Los cambios se aplican directamente al
   contenedor de producción mediante scripts de despliegue manual; no existe
   un pipeline de integración continua que ejecute la suite de validación
   automáticamente antes de cada despliegue.
4. **Regresión logística multinomial sin selector visible en el dashboard.**
   Se accede únicamente desde el submenú de Regresión logística, no como
   método independiente en la pantalla principal.
5. **Sin periodo de uso real documentado.** El sistema no ha sido evaluado
   aún con usuarios reales (tesistas) en un periodo prolongado que permita
   reportar tasas de error, satisfacción de uso, o comparación con flujos
   de trabajo tradicionales (SPSS manual).

---

## 7. Cómo reproducir la validación

```bash
# Clonar el repositorio
git clone https://github.com/Miguekikoh89/researchos.git
cd researchos

# Ejecutar la suite de validacion (requiere R y los paquetes listados en Seccion 3)
Rscript tests/validate_mtcars.R
```

El script no requiere datos propietarios ni conexión a la base de datos de
producción: usa exclusivamente el dataset `mtcars`, incluido en la
instalación base de R.
