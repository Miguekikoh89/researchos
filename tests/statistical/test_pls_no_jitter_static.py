from pathlib import Path
s=Path("apps/api/stats-engine-r/R/pls_sem_engine.R").read_text()
assert "jitter(col" not in s
assert "PLS_BOOTSTRAP_FAILED" in s
assert "Q2=NULL" in s
print("PASS PLS fail-closed/no jitter")
