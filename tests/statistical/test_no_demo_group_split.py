from pathlib import Path
s=Path("apps/api/stats-engine-r/run_analysis.R").read_text()
assert "dividir por mitad (demo)" not in s
assert "SIN_VARIABLE_GRUPO" in s
print("PASS no artificial groups")
