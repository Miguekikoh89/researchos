#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "============================================================"
echo " FASE 1 — REGRESIÓN ESTADÍSTICA EXISTENTE"
echo "============================================================"
tests/statistical/run_all.sh
echo
echo "============================================================"
echo " FASE 2 — REFERENCIAS NUMÉRICAS INDEPENDIENTES"
echo "============================================================"
tests/certification/run_all.sh
echo
echo "============================================================"
echo " RESULTADO GLOBAL: CERTIFICACIÓN LOCAL SUPERADA"
echo "============================================================"
