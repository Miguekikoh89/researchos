from pathlib import Path

root = Path(__file__).resolve().parents[2]
configure = (root / "apps/web/src/components/wizard/StepConfigure.tsx").read_text()
run = (root / "apps/web/src/components/wizard/StepRun.tsx").read_text()
results = (root / "apps/web/src/components/wizard/StepResults.tsx").read_text()
api = (root / "apps/api/src/analysis/analysis.service.ts").read_text()
word = (root / "apps/api/stats-engine-r/R/word_export.R").read_text()
engine = (root / "apps/api/stats-engine-r/R/pls_sem_engine.R").read_text()
installer = (root / "apps/api/stats-engine-r/install_packages.R").read_text()

for token in ["Modo avanzado", "FIMIX-PLS", "Variables de control", "Comparar modelos directo, paralelo y secuencial"]:
    assert token in configure, token
for token in ["calc_fimix", "control_variables", "comparison_roles", "calc_pls_predict"]:
    assert token in run and token in api, token
for token in ["FIMIX_Fit", "FIMIX_Segments", "ModelComparison", "Controls"]:
    assert token in engine and token in results and token in word, token
assert "seminrExtras" in installer
assert "assess_fimix_compare" in engine
assert "single_item" in engine
assert "failed_closed" in results and "failed_closed" in engine

copies = [
    root / "apps/api/stats-engine-r/R/pls_sem_engine.R",
    root / "apps/stats-engine-r/R/pls_sem_engine.R",
    root / "pls_sem_engine.R",
]
assert len({p.read_bytes() for p in copies}) == 1, "Las tres copias del motor PLS-SEM no estan sincronizadas"
print("PASS contrato web PLS-SEM avanzado, FIMIX, controles y exportacion Word")
