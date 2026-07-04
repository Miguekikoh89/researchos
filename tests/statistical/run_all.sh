#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

passed=0
failed=0
failed_tests=()

echo "============================================================"
echo " CANCHARIOS — PUERTA DE REGRESIÓN ESTADÍSTICA"
echo "============================================================"

for test_file in tests/statistical/test_*.R; do
  echo
  echo "▶ Ejecutando: $test_file"

  if Rscript "$test_file"; then
    passed=$((passed + 1))
    echo "✅ PASS: $test_file"
  else
    failed=$((failed + 1))
    failed_tests+=("$test_file")
    echo "❌ FAIL: $test_file"
  fi
done

for test_file in tests/statistical/test_*.py; do
  [ -e "$test_file" ] || continue
  echo
  echo "▶ Ejecutando: $test_file"
  if python3 "$test_file"; then
    passed=$((passed + 1)); echo "✅ PASS: $test_file"
  else
    failed=$((failed + 1)); failed_tests+=("$test_file"); echo "❌ FAIL: $test_file"
  fi
done

echo
echo "▶ Referencia independiente R"
if Rscript tests/reference/r/validate_pgv_ier.R >/dev/null; then
  passed=$((passed + 1))
  echo "✅ PASS: referencia R PGV–IER"
else
  failed=$((failed + 1))
  failed_tests+=("tests/reference/r/validate_pgv_ier.R")
fi

echo
echo "▶ Referencia independiente Python"
if python3 tests/reference/python/validate_pgv_ier.py >/dev/null; then
  passed=$((passed + 1))
  echo "✅ PASS: referencia Python PGV–IER"
else
  failed=$((failed + 1))
  failed_tests+=("tests/reference/python/validate_pgv_ier.py")
fi

echo
echo "============================================================"
echo " RESULTADO: $passed PASS | $failed FAIL"
echo "============================================================"

if (( failed > 0 )); then
  echo "Pruebas fallidas:"
  printf ' - %s\n' "${failed_tests[@]}"
  exit 1
fi

echo "PUERTA ESTADÍSTICA SUPERADA."
