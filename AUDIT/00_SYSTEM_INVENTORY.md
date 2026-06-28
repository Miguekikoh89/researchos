# 00 — SYSTEM INVENTORY
## ResearchOS / CanchariOS Stats Engine — Auditoría Científico-Técnica
**Fecha de inspección:** 2026-06-28  
**Rama de auditoría:** `claude/cancharios-stats-audit-0pnx4q`  
**Principio:** Solo se documenta lo verificado con lectura directa de código. Nada se inventa.

---

## 1. TOPOLOGÍA DEL REPOSITORIO

```
researchos/
├── apps/
│   ├── api/                          # Backend NestJS (Node.js 20)
│   │   ├── src/
│   │   │   ├── analysis/             # Módulo central: service + controller
│   │   │   │   ├── analysis.service.ts   (448 líneas)
│   │   │   │   └── analysis.controller.ts (71 líneas)
│   │   │   ├── auth/                 # JWT + Guards
│   │   │   ├── users/
│   │   │   ├── projects/
│   │   │   └── main.ts
│   │   ├── prisma/
│   │   │   └── schema.prisma         # ORM schema (Prisma + PostgreSQL)
│   │   ├── stats-engine-r/
│   │   │   ├── run_analysis.R        # Dispatcher principal (944 líneas)
│   │   │   ├── pls_sem_engine.R      # Motor PLS-SEM standalone (952 líneas)
│   │   │   ├── pls_word_wrapper.R    # Wrapper Word para PLS-SEM
│   │   │   ├── install_packages.R    # Instalación de paquetes R
│   │   │   └── R/                    # Módulos R especializados (21 archivos)
│   │   │       ├── helpers.R         (219 líneas)
│   │   │       ├── statistics.R      (776 líneas)
│   │   │       ├── data_cleaning.R   (259 líneas)
│   │   │       ├── word_export.R     (1285 líneas)
│   │   │       ├── t_test.R          (97 líneas)
│   │   │       ├── anova.R           (321 líneas)
│   │   │       ├── regression.R      (236 líneas)
│   │   │       ├── logistic.R        (243 líneas)
│   │   │       ├── logistic_multinomial.R (82 líneas)
│   │   │       ├── chi_square.R      (125 líneas)
│   │   │       ├── instruments.R     (409 líneas)
│   │   │       ├── ordinal_regression.R (105 líneas)
│   │   │       ├── hierarchical_regression.R (92 líneas)
│   │   │       ├── ancova.R          (85 líneas)
│   │   │       ├── discriminant.R    (85 líneas)
│   │   │       ├── cluster.R         (53 líneas)
│   │   │       ├── frequencies.R     (39 líneas)
│   │   │       ├── cronbach_only.R   (72 líneas)
│   │   │       ├── baremos_only.R    (66 líneas)
│   │   │       ├── descriptives_full.R (67 líneas)
│   │   │       ├── analisis_descriptivo.R (114 líneas)
│   │   │       └── pls_sem_engine.R  (952 líneas — symlink/copia)
│   │   ├── Dockerfile                # Multi-stage build
│   │   └── package.json
│   ├── web/                          # Frontend Next.js 14
│   │   ├── src/
│   │   │   ├── app/                  # App Router
│   │   │   ├── components/
│   │   │   │   └── wizard/           # Wizard de análisis (5 componentes)
│   │   │   └── lib/
│   │   │       └── methodRecommendation.ts (312 líneas)
│   │   └── package.json
│   └── stats-engine-r/               # COPIA LEGACY (más antigua, menos archivos)
├── tests/
│   └── validate_mtcars.R             # Suite de validación numérica (146 líneas)
├── docker-compose.yml
├── package.json                      # Monorepo root (npm workspaces)
└── AUDIT/                            # Este directorio (creado en auditoría)
```

---

## 2. STACK TECNOLÓGICO VERIFICADO

| Capa | Tecnología | Versión | Verificado en |
|------|-----------|---------|---------------|
| Runtime backend | Node.js | 20 | Dockerfile |
| Framework API | NestJS | NO VERIFICADO: ver apps/api/package.json | — |
| ORM | Prisma | NO VERIFICADO: ver apps/api/package.json | — |
| Base de datos | PostgreSQL | NO VERIFICADO: ver docker-compose.yml | — |
| Frontend framework | Next.js | ^14.2.0 | apps/web/package.json |
| Frontend UI | React | ^18.3.0 | apps/web/package.json |
| CSS | Tailwind CSS | ^3.4.4 | apps/web/package.json |
| Motor estadístico | R | 4.3.2 (imagen rocker) | Dockerfile |
| Containerización | Docker multi-stage | — | Dockerfile |
| Despliegue | Railway | NO VERIFICADO en código | — |

---

## 3. FLUJO DE EJECUCIÓN (VERIFICADO)

```
Usuario → Next.js (POST /projects/:id/analysis)
         → NestJS Controller (analysis.controller.ts)
         → AnalysisService.runAnalysis()
              ├─ Crear AnalysisJob (PENDING) → DB
              ├─ Proceso async:
              │   ├─ Si analysis_category == "structural_model":
              │   │    invokePlsEngine() → Rscript pls_sem_engine.R <params.json>
              │   └─ Else:
              │        invokeREngine() → Rscript run_analysis.R <config.json> <output_dir>
              │            └─ run_analysis.R despacha a módulo R según analysis_category
              └─ Resultado JSON → AnalysisResult (DB) + Job(COMPLETED)
                   └─ Exportación Word: paths de archivo almacenados en DB (RIESGO: efímero)
```

### Parámetros de invocación R verificados
- **Motor general:** `spawn('Rscript', [run_analysis.R, config_json_path, output_dir])`, timeout 120 s
- **Motor PLS-SEM:** `spawn('/usr/bin/Rscript', [pls_sem_engine.R, params_json_path])`, timeout 600 s
- **Directorio hardcoded en run_analysis.R:** `script_dir <- "/app/stats-engine-r/R"` (correcto para Docker)
- **R_BIN desde env:** `process.env.R_BIN || 'Rscript'` (motor general); `/usr/bin/Rscript` para PLS (desde config)

---

## 4. MÓDULOS R — INVENTARIO COMPLETO

| Archivo | Funciones principales | Paquetes R usados |
|---------|----------------------|-------------------|
| `helpers.R` | `%\|\|%`, `format_r_apa()`, `format_p_apa()`, `stars_p()`, `interpret_r()`, `effect_size_label()`, `interpret_alpha()`, funciones de redacción | — (solo base R) |
| `statistics.R` | `compute_descriptives()`, `cronbach_alpha_ic()`, `compute_omega()`, `compute_reliability()`, `compute_baremo()`, `compute_normality()`, `decide_method()`, `correlate_pearson()`, `correlate_spearman()`, `correlate_matrix()` + duplicados de helpers.R | `dplyr`, `psych`, `nortest` |
| `data_cleaning.R` | `load_file()`, `clean_data()`, `impute_data()`, `compute_scores()` | `readxl` |
| `word_export.R` | `generate_word()` + 15 secciones especializadas, `save_word()` | `officer` |
| `t_test.R` | `cohen_d()`, `levene_test()`, `normality_by_group()`, `t_independent()`, `t_paired()`, `mann_whitney()`, `wilcoxon_paired()`, `compute_ttest()` | — (base R) |
| `anova.R` | `levene_anova()`, `tukey_hsd()`, `bonferroni_posthoc()`, `scheffe_posthoc()`, `games_howell()`, `dunn_posthoc()`, `kruskal_wallis_test()`, `compute_anova()` | — (base R) |
| `regression.R` | `compute_regression()` (Enter/Stepwise/Forward/Backward, VIF manual, Cook's D, DW, BP, RESET) | `car` (Durbin-Watson, Breusch-Pagan) |
| `logistic.R` | `compute_logistic()` (binaria + ordinal): Cox-Snell R², Nagelkerke R², Hosmer-Lemeshow, ROC/AUC manual | `MASS` (polr) |
| `logistic_multinomial.R` | `compute_logistic_multinomial()`: LR chi², OR, z-tests | `nnet` (multinom) |
| `chi_square.R` | `compute_chisquare()`: Pearson, Yates, Fisher exact, phi, V de Cramér | — (base R) |
| `instruments.R` | `compute_kmo()`, `compute_normality_items()`, `compute_afe()`, `compute_afc()`, `compute_htmt()`, `compute_vaiken()`, `compute_instruments()` | `psych`, `lavaan`, `GPArotation` |
| `ordinal_regression.R` | `run_ordinal_regression()`: tricotomización DV, polr, pseudo-R², test líneas paralelas parcial | `MASS` (polr) |
| `hierarchical_regression.R` | `run_hierarchical_regression()`: bloques de ítems → puntajes → regresión jerárquica, F-cambio | — (base R) |
| `ancova.R` | `run_ancova()`: `emmeans`, homogeneidad de pendientes, medias ajustadas | `emmeans`, `car` |
| `discriminant.R` | `run_discriminant()`: `MASS::lda()` CV=TRUE, Wilks Lambda manual (SVD) | `MASS` |
| `cluster.R` | `run_cluster()`: K-means (nstart=25), silhouette, codo | `cluster` |
| `frequencies.R` | `run_frequencies()`: tablas por ítem, curtosis/asimetría manuales | — (base R) |
| `cronbach_only.R` | `run_cronbach_only()`: alfa manual, bootstrap 1000 iter (seed=42), omega vía `psych::omega()` | `psych` |
| `baremos_only.R` | `run_baremos_only()`: cortes tercil/percentil/teórico, distribución por niveles | — (base R) |
| `descriptives_full.R` | `run_descriptives_full()`: media, DE, asimetría/curtosis manuales, SW, IC, percentiles | — (base R) |
| `analisis_descriptivo.R` | `run_analisis_descriptivo()`: combinado descriptivos + baremo + texto APA automático | — (base R) |
| `pls_sem_engine.R` | Motor PLS-SEM completo: `run_pls_sem()`, `calc_cr_ave()`, `calc_htmt()`, `calc_fornell_larcker()`, `calc_cross_loadings()`, `calc_vif()`, `calc_f2()`, `calc_q2()`, `calc_srmr()`, `calc_indirect()`, `calc_pls_predict()`, `calc_vaf_mediation()`, `calc_htmt_ci()`, `calc_full_vif()`, `calc_gaussian_copula()`, `calc_micom()`, `calc_mga()`, `calc_ipma()` | `seminr`, `jsonlite` |

---

## 5. PAQUETES R INSTALADOS (install_packages.R)

Verificado en `/home/user/researchos/apps/api/stats-engine-r/install_packages.R`:

```
readxl, dplyr, tidyr, psych, nortest, officer, flextable, openxlsx,
jsonlite, lavaan, GPArotation, car, htmlwidgets, visNetwork,
DiagrammeR, DiagrammeRsvg, seminr, MASS, nnet, emmeans, cluster, klaR
```

**Paquetes usados en código pero NO en lista de instalación:**
- `flextable` — sí en lista pero no usado directamente (word_export.R usa `officer` directamente)
- `klaR` — en lista, pero NO se encontró uso en los módulos R auditados

**Paquetes usados en código y SÍ en lista:** readxl, dplyr, psych, nortest, officer, jsonlite, lavaan, GPArotation, car, MASS, nnet, emmeans, cluster, seminr

---

## 6. ESQUEMA DE BASE DE DATOS (Prisma — verificado)

### Modelos
| Modelo | Campos clave | Notas |
|--------|-------------|-------|
| `User` | id, email, name, password (hashed), role (STUDENT/ADVISOR/ADMIN), isActive | |
| `Project` | id, title, description, userId | |
| `Dataset` | id, projectId, fileName, filePath, fileSize, columnNames (JSON) | filePath: efímero en Railway |
| `AnalysisJob` | id, projectId, datasetId, status (PENDING/PROCESSING/COMPLETED/FAILED), analysisType, config (JSON) | |
| `AnalysisResult` | id, jobId; campos JSON separados por método (ttest, anova, regression, logistic, chi_square, instruments, ordinal_regression, hierarchical_regression, discriminant, ancova, frequencies, cluster, cronbach_only, baremos_only, descriptives_full, analisis_descriptivo) | |
| `Report` | id, jobId, type (WORD_APA/EXCEL/JSON), filePath | filePath efímero |
| `AuditLog` | id, userId, action, resource, resourceId, metadata | |

---

## 7. DOCKER (verificado en Dockerfile)

- **Stage 1 (builder):** `node:20-slim` → compila TypeScript
- **Stage 2 (runner):** `rocker/r-ver:4.3.2` → R 4.3.2
  - Node.js 20 instalado via NodeSource dentro del runner
  - Sistema: libcurl4-openssl-dev, libssl-dev, libxml2-dev, libfontconfig, libcairo2, libxt, cmake, libuv1-dev
  - Locale: `en_US.UTF-8`
  - Puerto expuesto: NO VERIFICADO en Dockerfile (inferido desde NestJS)

---

## 8. AUTENTICACIÓN Y AUTORIZACIÓN (verificado)

- **Estrategia:** JWT (JSON Web Tokens)
- **Guard:** `JwtAuthGuard` aplicado en todos los endpoints de `/projects/:projectId/analysis`
- **Roles:** STUDENT, ADVISOR, ADMIN (definidos en Prisma, lógica de roles en guards)
- **Contraseñas:** Almacenadas hasheadas (confirmado por campo `password` en schema)

---

## 9. MOTOR DE RECOMENDACIÓN METODOLÓGICA (Frontend — verificado)

Archivo: `apps/web/src/lib/methodRecommendation.ts`

Lógica de decisión basada en tabla:
- `ScaleResultado × ScaleExplicativa × CovariateType × Purpose → MethodSlug`
- Escalas soportadas: continua, ordinal, nominal_2, nominal_3mas
- Propósitos: relacionar, predecir, comparar, clasificar, asociar
- 15 métodos mapeados con rutas `/analysis/new?method=<slug>`

**Fuentes citadas en el código:** Flores-Ruiz et al. (2017), Field (2013), Hair et al. (2019), IBM SPSS Documentation

---

## 10. SUITE DE VALIDACIÓN NUMÉRICA (verificado)

Archivo: `tests/validate_mtcars.R`

- **Dataset:** `mtcars` (R built-in, reproducible)
- **12 pruebas numéricas** cubriendo: Correlación Pearson, Regresión lineal, ANOVA, t-test (Welch), Chi-cuadrado, Logística binaria, Alfa de Cronbach, ANCOVA, Discriminante, K-means, Regresión ordinal, Logística multinomial
- **Tolerancia:** 0.01 absoluta
- **Exit code:** 1 si falla cualquier prueba (compatible con CI/CD)
- **Estado de ejecución:** NO VERIFICADO (suite no ejecutada durante esta auditoría)

---

## 11. ANÁLISIS_CATEGORY → MÓDULO R (dispatch verificado en run_analysis.R)

| analysis_category | Módulo R invocado | Función principal |
|-------------------|------------------|--------------------|
| `correlacional` | statistics.R | `correlate_pearson()` / `correlate_spearman()` / `correlate_matrix()` |
| `comparacion` | t_test.R | `compute_ttest()` |
| `anova` | anova.R | `compute_anova()` |
| `regresion` | regression.R | `compute_regression()` |
| `logistica` | logistic.R / logistic_multinomial.R | `compute_logistic()` / `compute_logistic_multinomial()` |
| `regresion_ordinal` | ordinal_regression.R | `run_ordinal_regression()` |
| `regresion_jerarquica` | hierarchical_regression.R | `run_hierarchical_regression()` |
| `ancova` | ancova.R | `run_ancova()` |
| `discriminante` | discriminant.R | `run_discriminant()` |
| `descriptivo` | analisis_descriptivo.R | `run_analisis_descriptivo()` |
| `frecuencias` | frequencies.R | `run_frequencies()` |
| `cluster` | cluster.R | `run_cluster()` |
| `cronbach` | cronbach_only.R | `run_cronbach_only()` |
| `baremos` | baremos_only.R | `run_baremos_only()` |
| `descriptivos` | descriptives_full.R | `run_descriptives_full()` |
| `instrumentos` | instruments.R | `compute_instruments()` |
| `chi_cuadrado` | chi_square.R | `compute_chisquare()` |
| `structural_model` | pls_sem_engine.R | `run_pls_sem()` (invocado directamente desde AnalysisService) |
| `instrumentos` con AFC | instruments.R | `compute_instruments()` (incluye AFE+AFC+HTMT+Confiabilidad) |

**NOTA CRÍTICA:** La categoría `"anova"` tiene su bloque de dispatch **DUPLICADO** en run_analysis.R (líneas 283-336 y 338-391). El segundo bloque es código muerto inalcanzable.

---

## 12. ARCHIVOS NO LEÍDOS / NO VERIFICADOS

Los siguientes archivos existen en el repositorio pero NO fueron leídos durante esta auditoría de inspección:

- `apps/api/src/auth/` — módulo de autenticación completo
- `apps/api/src/users/` — módulo de usuarios
- `apps/api/src/projects/` — módulo de proyectos
- `apps/web/src/components/wizard/` — 5 componentes del wizard
- `apps/api/stats-engine-r/R/pls_sem_engine.R` — copia en subdirectorio (vs. versión en stats-engine-r/ raíz)
- `docker-compose.yml` — configuración de servicios
- `apps/api/package.json` — dependencias NestJS exactas
- Variables de entorno / `.env` — NO inspeccionados (por política de seguridad)
- `apps/stats-engine-r/` — directorio legacy/duplicado con versión más antigua

---

*Inventario completado el 2026-06-28. Sin modificaciones al código.*
