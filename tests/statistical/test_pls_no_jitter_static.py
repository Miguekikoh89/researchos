from pathlib import Path

engine_path = Path("apps/api/stats-engine-r/R/pls_sem_engine.R")
assert engine_path.exists(), f"No se encontró el motor PLS-SEM: {engine_path}"

source = engine_path.read_text(encoding="utf-8")

# 1. El motor no debe reparar datos/modelos mediante perturbaciones aleatorias.
for forbidden in (
    "jitter(col",
    "stats::jitter(",
    "base::jitter(",
):
    assert forbidden not in source, (
        f"Se detectó perturbación artificial no permitida en PLS-SEM: {forbidden}"
    )

# 2. El bootstrap debe conservar su contrato de fallo explícito.
assert "PLS_BOOTSTRAP_FAILED" in source, (
    "Falta el código de error explícito PLS_BOOTSTRAP_FAILED."
)

# 3. Q² ya está implementado: verificar conexión real, no el antiguo Q2=NULL.
assert "calc_q2 <- function" in source, "No se encontró la implementación calc_q2()."
assert 'run_advanced("Q2"' in source, "Q² no está conectado al ejecutor avanzado."
assert "Q2=q2_tbl" in source or "Q2 = q2_tbl" in source, (
    "La tabla Q² no está conectada a la respuesta final del motor."
)

# 4. Los módulos avanzados deben fallar cerrados y declarar su estado.
assert "failed_closed:" in source, (
    "No se encontró el estado failed_closed para errores de módulos avanzados."
)
assert "advanced_modules=module_status" in source or "advanced_modules = module_status" in source, (
    "La respuesta no expone el estado de los módulos avanzados."
)

# 5. Evitar que reaparezca el contrato obsoleto que exigía desactivar Q².
assert "Q2=NULL" not in source and "Q2 = NULL" not in source, (
    "Persistió el contrato obsoleto que fuerza Q² a NULL."
)

print("PASS PLS fail-closed/no jitter y Q2 avanzado conectado")
