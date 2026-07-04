# CanchariOS — motor estadístico reproducible

CanchariOS integra Next.js, NestJS, PostgreSQL y R para ejecutar análisis estadísticos y generar resultados en pantalla y Word APA 7.

## Estado

Este código contiene una **puerta de certificación numérica candidata**. No se debe afirmar que todos los métodos están certificados hasta ejecutar localmente:

```bash
tests/run_numerical_certification.sh
npm run build --workspace apps/api
npm run build --workspace apps/web
```

El alcance y las restricciones se documentan en:

- [`VALIDATION_SCOPE.md`](VALIDATION_SCOPE.md)
- [`TECHNICAL_DOCUMENTATION.md`](TECHNICAL_DOCUMENTATION.md)
- [`AUDIT/METHOD_CERTIFICATION_MATRIX.csv`](AUDIT/METHOD_CERTIFICATION_MATRIX.csv)

## Instalación

```bash
cp .env.example .env
npm install
npm run install:r
docker compose up -d --build
```

Aplicación: `http://127.0.0.1:3000`  
API: `http://127.0.0.1:4000`

## Motor canónico

```text
apps/api/stats-engine-r/
├── run_analysis.R
├── install_packages.R
└── R/
```

No utilice copias antiguas ubicadas fuera de `apps/api/stats-engine-r`.

## Principios de seguridad científica

- Sin imputación oculta.
- Sin redondeo previo a decisiones.
- Sin grupos o variables fabricadas.
- Sin resultados silenciosamente parciales.
- Sin conversión silenciosa de texto a datos faltantes ni de factores a códigos internos.
- Errores, no finitos y contratos incompletos terminan en `FAILED`.
- Los procedimientos no validados permanecen bloqueados; los módulos avanzados informan `implemented`, `not_applicable`, `disabled_by_configuration` o `failed_closed`.

## Pruebas

```bash
# Puerta histórica y casos dorados existentes
tests/statistical/run_all.sh

# Nuevas referencias por familia
tests/certification/run_all.sh

# Ambas puertas
tests/run_numerical_certification.sh
```

## Métodos

Se incluyen correlaciones, comparación de grupos, ANOVA y alternativas, chi-cuadrado/Fisher, regresiones, ANCOVA, mediación simple, descriptivos, frecuencias, baremos, confiabilidad, instrumentos, clúster, discriminante y un motor PLS-SEM ampliado con Q² Stone–Geisser, PLS-Predict, HTMT inferencial, SRMR compuesto saturado y estimado, Full VIF, VAF/Zhao sobre el efecto indirecto total conjunto, IPMA, cópula gaussiana opt-in con ECDF ajustada F4 y reestimación PLS, MICOM y MGA por permutación. La ampliación se entrega con una prueba nueva y debe volver a ejecutar la puerta local antes de declararse certificada. Consulte `VALIDATION_SCOPE.md`.

## PLS-SEM avanzado en la aplicación web

La interfaz web ya expone el flujo avanzado completo. El usuario puede configurar y obtener en pantalla y Word:

- Q² Stone–Geisser y PLS-Predict;
- HTMT inferencial, SRMR saturado/estimado y Full VIF/CMB;
- efectos directos, indirectos específicos, totales y clasificación VAF/Zhao;
- variables de control explícitas como constructos de un indicador;
- IPMA y cópula gaussiana opt-in;
- FIMIX-PLS mediante `seminrExtras`, con comparación de K y asignación probabilística;
- MICOM y MGA con variable de grupo observada o, opcionalmente, con el segmento FIMIX seleccionado;
- comparación descriptiva/predictiva de modelos directo, paralelo y secuencial.

La configuración avanzada se encuentra en el paso **Configurar PLS-SEM**. Los módulos costosos o que requieren una decisión metodológica —cópula, FIMIX y comparación de modelos— permanecen opt-in. La nueva puerta añade `test_pls_sem_web_workflow.R` y `test_pls_sem_web_contract_static.py`; por ello, esta versión debe cerrar con **16 PASS | 0 FAIL** en la fase de certificación y **37 pruebas aprobadas** en el consolidado local.
