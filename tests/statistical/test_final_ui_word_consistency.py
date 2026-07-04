#!/usr/bin/env python3
from pathlib import Path

web = Path("apps/web/src/components/wizard/StepResults.tsx").read_text(encoding="utf-8")
word = Path("apps/api/stats-engine-r/R/word_export.R").read_text(encoding="utf-8")

required_web = [
    "function formatApaP",
    "function formatApaCI",
    "function formatBaremoRange",
    "correlationLabel(method)",
    "formatApaP(row.sw_p)",
    "formatApaP(row.ks_p)",
    "ρ de Spearman",
    "headers={['Nivel','Rango']}",
]
for token in required_web:
    assert token in web, f"Falta en frontend: {token}"

for forbidden in ["Rho de Spearman", "{row.sw_p}</span>", "{row.ks_p}</span>"]:
    assert forbidden not in web, f"Persistió en frontend: {forbidden}"

required_word = [
    "library(flextable)",
    "flextable::theme_apa",
    "keep_with_next=keep_next",
    'officer::ftext("Nota.", note_prop)',
    'names(cdf)[6] <- "Decisión"',
    "format_apa_ci(row[[\"ci_lower\"]], row[[\"ci_upper\"]], 3)",
]
for token in required_word:
    assert token in word, f"Falta en Word: {token}"

assert "officer::body_add_table(doc" not in word, "Persisten tablas Word sin tema APA unificado"
print("PASS consistencia final APP–Word APA 7")
