from pathlib import Path
s=Path("apps/api/stats-engine-r/R/instruments.R").read_text()
assert "((p - n_factors_use)^2 - (p + n_factors_use)) / 2" in s
print("PASS AFE df formula")
