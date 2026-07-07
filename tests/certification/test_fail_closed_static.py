from pathlib import Path

root = Path(__file__).resolve().parents[2]
checks = {
    'apps/api/stats-engine-r/R/pls_sem_engine.R': [
        'INDICATOR_ASSIGNED_MULTIPLE_CONSTRUCTS',
        'PLS_BOOTSTRAP_SCHEMA_UNRECOGNIZED',
        'seminr::predict_pls',
        'boot_HTMT',
        'Stone-Geisser cross-validated redundancy',
        'predicción estructural del constructo endógeno',
        'Compositional_Invariance',
        'stats::p.adjust',
        'pesos desestandarizados',
        'failed_closed:',
        'disabled_by_configuration_opt_in',
        'VAF_Mediacion=vaf_tbl',
        'percentile_bootstrap_ci',
        'adjusted_ecdf_copula',
        'seminr::single_item',
        'SRMR_estimated_composite',
        'IC_indirecto_2.5',
        'required_constructs',
        'Bootstrap_Alcance',
        'Omega_Simple',
    ],
    'apps/api/stats-engine-r/R/ordinal_regression.R': ['VD_ORDINAL_DEBE_SER_UNA_COLUMNA'],
    'apps/api/stats-engine-r/R/logistic.R': ['RUTA_ORDINAL_DUPLICADA', 'Mann–Whitney/rangos'],
    'apps/api/stats-engine-r/R/discriminant.R': ['SELECCION_AUTOMATICA_NO_VALIDADA'],
    'apps/api/src/analysis/analysis.service.ts': [
        'validatePlsContract',
        'validateMethodContract',
        'assertAllNumbersFinite',
        'embeddedError',
        'advanced_pls',
        'calc_pls_predict',
        'q2_omission_distance',
        'n_permut',
        "optionalTable('PLSPredict')",
        "optionalTable('MICOM')",
        "optionalTable('MGA')",
        'VAF_Mediacion',
        'PLS_Beta_Corregido',
        'Bootstrap_Alcance',
        'Omega_Simple',
    ],
    'apps/api/stats-engine-r/R/word_export.R': [
        'HTMT inferencial con intervalo bootstrap',
        'PLS-Predict a nivel de indicadores endogenos',
        'Estado de los modulos PLS-SEM avanzados',
        'Diagnostico SRMR compuesto: modelos saturado y estimado',
    ],
    'apps/web/src/components/wizard/StepResults.tsx': [
        'Validación cruzada con reestimación PLS por fold',
        'p ajustado de Holm',
        'Diagnóstico del modelo — SRMR',
        'row.Compositional_Invariance',
        'row.p_ajustado',
        'ECDF ajustada F4',
    ],
}
for rel, tokens in checks.items():
    text = (root / rel).read_text(encoding='utf-8')
    for token in tokens:
        assert token in text, f'{rel}: falta {token}'

pls_path = root / 'apps/api/stats-engine-r/R/pls_sem_engine.R'
pls = pls_path.read_text(encoding='utf-8')
pls_lower = pls.lower()
run_start = pls_lower.find('run_pls_sem <- function')
assert run_start >= 0
assert 'rnorm(' not in pls_lower[run_start:], 'No se permite ruido sintético en run_pls_sem'
assert pls.count('calc_pls_predict <- function') == 1, 'Debe existir una sola implementación PLS-Predict'
assert pls.count('calc_q2 <- function') == 1, 'Debe existir una sola implementación Q2'
assert pls.count('calc_micom <- function') == 1, 'Debe existir una sola implementación MICOM'
assert pls.count('calc_mga <- function') == 1, 'Debe existir una sola implementación MGA'
assert 'disabledTables' not in (root / 'apps/api/src/analysis/analysis.service.ts').read_text(encoding='utf-8')
assert 'SRMR=NULL' not in pls, 'SRMR no debe forzarse a null en el resultado final'

# Las tres copias desplegables del motor deben ser byte-a-byte idénticas.
engine_copies = [
    root / 'pls_sem_engine.R',
    root / 'apps/stats-engine-r/R/pls_sem_engine.R',
    root / 'apps/api/stats-engine-r/R/pls_sem_engine.R',
]
contents = [p.read_bytes() for p in engine_copies]
assert contents[0] == contents[1] == contents[2], 'Las copias del motor PLS-SEM no están sincronizadas'

print('PASS contratos fail-closed, módulos PLS-SEM avanzados y validación API')
