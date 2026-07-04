#!/usr/bin/env bash
set +e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0; FAILED=()
echo "============================================================"
echo " CANCHARIOS — CERTIFICACIÓN NUMÉRICA INDEPENDIENTE"
echo "============================================================"
for f in tests/certification/test_*.R tests/certification/test_*.py; do
  [ -e "$f" ] || continue
  echo; echo "▶ Ejecutando: $f"
  if [[ "$f" == *.R ]]; then Rscript "$f"; else python3 "$f"; fi
  if [ $? -eq 0 ]; then echo "✅ PASS: $f"; PASS=$((PASS+1)); else echo "❌ FAIL: $f"; FAIL=$((FAIL+1)); FAILED+=("$f"); fi
done
echo; echo "============================================================"
echo " CERTIFICACIÓN: $PASS PASS | $FAIL FAIL"
echo "============================================================"
if [ "$FAIL" -gt 0 ]; then printf ' - %s\n' "${FAILED[@]}"; exit 1; fi
echo "PUERTA DE CERTIFICACIÓN NUMÉRICA SUPERADA."
