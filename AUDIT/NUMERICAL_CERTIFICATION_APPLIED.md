# Certificación numérica candidata aplicada

- Fecha local: 2026-07-04T15:14:37
- Respaldo: `AUDIT/pre_numerical_certification_backup_20260704_151437`
- Archivos aplicados: 43

## Importante

La aplicación del parche no certifica por sí sola los métodos. La certificación local solo se alcanza cuando `tests/run_numerical_certification.sh`, las compilaciones y la prueba Docker finalizan con cero errores.

## Archivos

- `AUDIT/METHOD_CERTIFICATION_MATRIX.csv`
- `AUDIT/NUMERICAL_CERTIFICATION_SCOPE.md`
- `README.md`
- `TECHNICAL_DOCUMENTATION.md`
- `VALIDATION_SCOPE.md`
- `apps/api/src/analysis/analysis.service.ts`
- `apps/api/stats-engine-r/R/analisis_descriptivo.R`
- `apps/api/stats-engine-r/R/ancova.R`
- `apps/api/stats-engine-r/R/anova.R`
- `apps/api/stats-engine-r/R/baremos_only.R`
- `apps/api/stats-engine-r/R/chi_square.R`
- `apps/api/stats-engine-r/R/cluster.R`
- `apps/api/stats-engine-r/R/data_cleaning.R`
- `apps/api/stats-engine-r/R/descriptives_full.R`
- `apps/api/stats-engine-r/R/discriminant.R`
- `apps/api/stats-engine-r/R/frequencies.R`
- `apps/api/stats-engine-r/R/hierarchical_regression.R`
- `apps/api/stats-engine-r/R/instruments.R`
- `apps/api/stats-engine-r/R/logistic.R`
- `apps/api/stats-engine-r/R/mediation.R`
- `apps/api/stats-engine-r/R/ordinal_regression.R`
- `apps/api/stats-engine-r/R/pls_sem_engine.R`
- `apps/api/stats-engine-r/R/regression.R`
- `apps/api/stats-engine-r/R/statistics.R`
- `apps/api/stats-engine-r/install_packages.R`
- `apps/api/stats-engine-r/run_analysis.R`
- `package.json`
- `tests/certification/helpers.R`
- `tests/certification/run_all.sh`
- `tests/certification/test_anova_family.R`
- `tests/certification/test_chisquare_family.R`
- `tests/certification/test_cluster_discriminant.R`
- `tests/certification/test_correlation_reference.R`
- `tests/certification/test_descriptives_baremos.R`
- `tests/certification/test_fail_closed_static.py`
- `tests/certification/test_frequencies.R`
- `tests/certification/test_logistic_binary_multinomial.R`
- `tests/certification/test_mediation.R`
- `tests/certification/test_ordinal_ancova.R`
- `tests/certification/test_pls_sem_core.R`
- `tests/certification/test_regression_hierarchical.R`
- `tests/certification/test_reliability_instruments.R`
- `tests/run_numerical_certification.sh`
