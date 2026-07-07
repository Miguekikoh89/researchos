from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import pandas as pd
from scipy import stats


ROOT = Path(__file__).resolve().parents[3]
DATASET = ROOT / "tests/golden-data/correlation/PGV_IER_384.xlsx"
OUTPUT = ROOT / "tests/reference/python/PGV_IER_384_expected.json"

PGV_ITEMS = [f"PGV{i}" for i in range(1, 13)]
IER_ITEMS = [f"IER{i}" for i in range(1, 13)]

EXPECTED = {
    "n": 384,
    "spearman_rho": 0.7867272,
    "pgv_baremo": {"Bajo": 115, "Medio": 143, "Alto": 126},
    "ier_baremo": {"Bajo": 79, "Medio": 218, "Alto": 87},
}


def theoretical_baremo(total: pd.Series) -> dict[str, int]:
    levels = pd.cut(
        total,
        bins=[-math.inf, 28, 44, math.inf],
        labels=["Bajo", "Medio", "Alto"],
        right=True,
        include_lowest=True,
    )

    if levels.isna().any():
        raise AssertionError("Hay participantes sin clasificar.")

    result = {
        level: int((levels == level).sum())
        for level in ["Bajo", "Medio", "Alto"]
    }

    if sum(result.values()) != len(total):
        raise AssertionError("Las frecuencias no suman N.")

    return result


if not DATASET.exists():
    raise FileNotFoundError(DATASET)

df = pd.read_excel(DATASET, sheet_name=0)

missing = sorted(set(PGV_ITEMS + IER_ITEMS) - set(df.columns))
if missing:
    raise AssertionError(f"Columnas faltantes: {missing}")

pgv_total = df[PGV_ITEMS].sum(axis=1, min_count=len(PGV_ITEMS))
ier_total = df[IER_ITEMS].sum(axis=1, min_count=len(IER_ITEMS))

valid = pd.concat(
    [pgv_total.rename("PGV"), ier_total.rename("IER")],
    axis=1,
).dropna()

pearson = stats.pearsonr(valid["PGV"], valid["IER"])
spearman = stats.spearmanr(valid["PGV"], valid["IER"])
kendall = stats.kendalltau(valid["PGV"], valid["IER"])

pgv_baremo = theoretical_baremo(valid["PGV"])
ier_baremo = theoretical_baremo(valid["IER"])

assert len(valid) == EXPECTED["n"], (len(valid), EXPECTED["n"])
assert abs(float(spearman.statistic) - EXPECTED["spearman_rho"]) < 1e-6
assert pgv_baremo == EXPECTED["pgv_baremo"], pgv_baremo
assert ier_baremo == EXPECTED["ier_baremo"], ier_baremo

result = {
    "dataset": str(DATASET.relative_to(ROOT)),
    "sha1": hashlib.sha1(DATASET.read_bytes()).hexdigest(),
    "n": len(valid),
    "pearson": {
        "r": float(pearson.statistic),
        "p_value": float(pearson.pvalue),
    },
    "spearman": {
        "rho": float(spearman.statistic),
        "p_value": float(spearman.pvalue),
    },
    "kendall": {
        "tau_b": float(kendall.statistic),
        "p_value": float(kendall.pvalue),
    },
    "baremos_teoricos": {
        "criterio_total": {
            "Bajo": "12–28",
            "Medio": "29–44",
            "Alto": "45–60",
        },
        "PGV": pgv_baremo,
        "IER": ier_baremo,
    },
    "status": "PASS",
}

OUTPUT.write_text(
    json.dumps(result, indent=2, ensure_ascii=False),
    encoding="utf-8",
)

print(json.dumps(result, indent=2, ensure_ascii=False))
