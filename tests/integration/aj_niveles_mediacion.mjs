// ============================================================================
// Suite AJ — event_level, ordered_levels y mediacion END-TO-END (Node→R→DB)
//
// FASE E: inversion del evento — B2 ≈ -B1 y OR2 ≈ 1/OR1 (tolerancia 1e-8)
// FASE F: guards ORDEN_NO_DECLARADO / ORDEN_INCOMPLETO / ORDEN_INVALIDO
// FASE G: payload de mediacion completo + reproducibilidad por seed
// ============================================================================

import {
  makeService, check, finish,
  buildStandardCsv, seedProjectWithDataset, waitForJob, baseConfig,
} from './_harness.mjs';

console.log('=== SUITE AJ — EVENT_LEVEL / ORDERED_LEVELS / MEDIACION E2E ===\n');

const csvPath = buildStandardCsv();
const { project, dataset } = await seedProjectWithDataset(csvPath, 'aj');
const service = makeService();

async function runToEnd(config) {
  const job = await service.createJob(project.id, dataset.id, config);
  const { job: done } = await waitForJob(job.id);
  return done;
}

const logisticCfg = (eventLevel) => baseConfig({
  analysis_category: 'logistica',
  logistic_type: 'binaria',
  var_b: { name: 'VDBin', items: ['YBIN'], dimensions: [] },
  event_level: eventLevel,
});

// ── AJ.INV — FASE E: inversion del evento ────────────────────────────────────
console.log('--- [AJ.INV] Logistica con evento invertido ---');
const run1 = await runToEnd(logisticCfg('1'));
const run2 = await runToEnd(logisticCfg('0'));
check('AJ.INV.01', 'evento=1: COMPLETED', run1.status === 'COMPLETED');
check('AJ.INV.02', 'evento=0: COMPLETED', run2.status === 'COMPLETED');

const lg1 = run1.result?.logistic ?? {};
const lg2 = run2.result?.logistic ?? {};
check('AJ.INV.03', `evento persistido run1 == '1' (${lg1.event_level})`, String(lg1.event_level) === '1');
check('AJ.INV.04', `evento persistido run2 == '0' (${lg2.event_level})`, String(lg2.event_level) === '0');
check('AJ.INV.05', `referencia run1 == '0' (${lg1.reference_level})`, String(lg1.reference_level ?? '0') === '0');

const coef1 = (lg1.coefficients ?? []).find((c) => !/intercept/i.test(c.term));
const coef2 = (lg2.coefficients ?? []).find((c) => !/intercept/i.test(c.term));
const b1 = Number(coef1?.B), b2 = Number(coef2?.B);
const or1 = Number(coef1?.OR), or2 = Number(coef2?.OR);
// La identidad de inversion a tolerancia 1e-8 se verifica sobre B: el motor
// redondea a 3 decimales de forma simetrica (round(x)= -round(-x)), asi que
// si el modelo es correcto B1+B2 es EXACTAMENTE 0 en lo persistido.
check('AJ.INV.06', `B2 = -B1 con |B1+B2| <= 1e-8 (B1=${b1}, B2=${b2}, diff=${Math.abs(b1 + b2)})`,
  Number.isFinite(b1) && Number.isFinite(b2) && Math.abs(b1 + b2) <= 1e-8);
// OR se persiste con redondeo de presentacion a 3 decimales (logistic.R:174),
// que propaga un error de hasta ~OR*5e-4 en el producto. La tolerancia 1e-2
// es la minima compatible con esa precision persistida; la identidad exacta
// ya quedo demostrada sobre B en AJ.INV.06 (OR = exp(B)).
check('AJ.INV.07', `OR2 = 1/OR1 dentro del redondeo persistido (OR1=${or1}, OR2=${or2}, |OR1*OR2-1|=${Math.abs(or1 * or2 - 1).toExponential(2)})`,
  Number.isFinite(or1) && Number.isFinite(or2) && Math.abs(or1 * or2 - 1) <= 1e-2);
check('AJ.INV.07b', 'coherencia OR = exp(B) en ambos sentidos (tol redondeo 3 dec)',
  Math.abs(or1 - Math.exp(b1)) <= 0.05 && Math.abs(or2 - Math.exp(b2)) <= 0.05);

// Evento inexistente → guard EVENTO_NO_ENCONTRADO por la via completa
const runBad = await runToEnd(logisticCfg('99'));
check('AJ.INV.08', `evento inexistente termina FAILED (${runBad.status})`, runBad.status === 'FAILED');
check('AJ.INV.09', 'errorMsg explica evento no encontrado',
  /no.*(encontr|existe)|evento/i.test(runBad.errorMsg ?? ''));
check('AJ.INV.10', 'sin resultado persistido con evento inexistente', runBad.result === null);

// ── AJ.ORD — FASE F: guards de ordered_levels ────────────────────────────────
console.log('\n--- [AJ.ORD] Guards de ordered_levels ---');
const ordCfg = (orderedLevels) => baseConfig({
  analysis_category: 'regresion_ordinal',
  var_b: { name: 'VDOrd', items: ['YORD'], dimensions: [] },
  measurement_level_b: 'ordinal',
  ...(orderedLevels !== undefined ? { ordered_levels: orderedLevels } : {}),
});

const ordNone = await runToEnd(ordCfg(undefined));
check('AJ.ORD.01', `sin orden → FAILED (${ordNone.status})`, ordNone.status === 'FAILED');
check('AJ.ORD.02', 'errorMsg menciona ordered_levels/orden',
  /ordered_levels|orden/i.test(ordNone.errorMsg ?? ''));

const ordIncomplete = await runToEnd(ordCfg(['1', '2']));
check('AJ.ORD.03', `orden incompleto → FAILED (${ordIncomplete.status})`, ordIncomplete.status === 'FAILED');
check('AJ.ORD.04', 'errorMsg reporta categorias no declaradas (ORDEN_INCOMPLETO)',
  /no figuran|ORDEN_INCOMPLETO|no declaradas/i.test(ordIncomplete.errorMsg ?? ''));

const ordDup = await runToEnd(ordCfg(['1', '2', '2', '3']));
check('AJ.ORD.05', `orden con duplicados → FAILED (${ordDup.status})`, ordDup.status === 'FAILED');
check('AJ.ORD.06', 'errorMsg reporta duplicados (ORDEN_INVALIDO)',
  /duplicad/i.test(ordDup.errorMsg ?? ''));

const ordOk = await runToEnd(ordCfg(['1', '2', '3']));
check('AJ.ORD.07', `orden correcto → COMPLETED (${ordOk.status})`, ordOk.status === 'COMPLETED');
const thr = (ordOk.result?.ordinal_regression?.thresholds ?? []).map((t) => t.threshold);
check('AJ.ORD.08', `modelo usa exactamente el orden declarado (umbrales ${thr.join(', ')})`,
  thr.length === 2 && thr[0] === '1|2' && thr[1] === '2|3');

// ── AJ.MED — FASE G: mediacion E2E ───────────────────────────────────────────
console.log('\n--- [AJ.MED] Mediacion: payload completo y reproducibilidad ---');
const medCfg = (seed) => baseConfig({
  analysis_category: 'mediacion',
  var_a: { name: 'X', items: ['X'], dimensions: [] },
  var_b: { name: 'Y', items: ['Y'], dimensions: [] },
  mediator: 'M',
  n_boot: 500,
  seed,
});

const medA = await runToEnd(medCfg(12345));
const medB = await runToEnd(medCfg(12345));
const medC = await runToEnd(medCfg(99999));
check('AJ.MED.01', 'mediacion seed=12345 COMPLETED', medA.status === 'COMPLETED');

const mA = medA.result?.mediation ?? {};
const mB = medB.result?.mediation ?? {};
const mC = medC.result?.mediation ?? {};
const requiredFields = ['a', 'b', 'c_total', 'c_direct', 'indirect', 'ci_lower', 'ci_upper', 'n_boot_requested', 'n_boot_valid'];
for (const f of requiredFields) {
  check(`AJ.MED.field.${f}`, `campo ${f} presente`, mA[f] !== undefined && mA[f] !== null);
}
// a, b, indirect se persisten redondeados a 6 decimales (mediation.R:65-69);
// el error propagado maximo de a*b vs indirect es ~(|a|+|b|+1)*5e-7 < 2e-6.
check('AJ.MED.02', 'indirect == a*b (coherencia interna a precision persistida, tol 2e-6)',
  Math.abs(Number(mA.a) * Number(mA.b) - Number(mA.indirect)) <= 2e-6);
check('AJ.MED.03', 'c_total == c_direct + indirect (tol 2e-6, precision persistida)',
  Math.abs(Number(mA.c_direct) + Number(mA.indirect) - Number(mA.c_total)) <= 2e-6);
check('AJ.MED.04', 'mismo seed → indirect identico', mA.indirect === mB.indirect);
check('AJ.MED.05', 'mismo seed → ci_lower identico', mA.ci_lower === mB.ci_lower);
check('AJ.MED.06', 'mismo seed → ci_upper identico', mA.ci_upper === mB.ci_upper);
check('AJ.MED.07', 'distinto seed → CI bootstrap distinto',
  mA.ci_lower !== mC.ci_lower || mA.ci_upper !== mC.ci_upper);
check('AJ.MED.08', 'distinto seed → efectos puntuales identicos (OLS, no bootstrap)',
  mA.indirect === mC.indirect && mA.a === mC.a);

await finish('AJ');
