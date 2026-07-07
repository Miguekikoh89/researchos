// ============================================================================
// Suite AG — Integracion Node → R → PostgreSQL (11 metodos, sin mocks)
//
// Cada test: crea CSV real → registra dataset en DB → createJob() (el mismo
// codigo de produccion) → el servicio lanza Rscript run_analysis.R → espera
// estado terminal → verifica persistencia en analysis_results.
// ============================================================================

import {
  prisma, makeService, check, finish,
  buildStandardCsv, seedProjectWithDataset, waitForJob, baseConfig,
  containsNonFinite,
} from './_harness.mjs';

console.log('=== SUITE AG — NODE → R → POSTGRESQL (11 METODOS) ===\n');

const csvPath = buildStandardCsv();
const { project, dataset } = await seedProjectWithDataset(csvPath, 'ag');
const service = makeService();

// ── AG.DB — CRUD basico contra PostgreSQL real ──────────────────────────────
console.log('--- [AG.DB] Conexion, insercion, actualizacion, consulta, limpieza ---');

const ping = await prisma.$queryRaw`SELECT 1 AS ok`;
check('AG.DB.01', 'conexion a PostgreSQL (SELECT 1)', Array.isArray(ping) && Number(ping[0].ok) === 1);

check('AG.DB.02', 'insercion: dataset creado con id', typeof dataset.id === 'string' && dataset.id.length > 0);

const updated = await prisma.dataset.update({
  where: { id: dataset.id },
  data: { rowCount: 120, columnCount: 17 },
});
check('AG.DB.03', 'actualizacion: rowCount=120 persistido', updated.rowCount === 120);

const fetched = await prisma.dataset.findUnique({ where: { id: dataset.id } });
check('AG.DB.04', 'consulta: dataset recuperado con columnas actualizadas', fetched.columnCount === 17);

const tmp = await prisma.project.create({ data: { name: 'tmp-rollback', userId: project.userId } });
await prisma.project.delete({ where: { id: tmp.id } });
const gone = await prisma.project.findUnique({ where: { id: tmp.id } });
check('AG.DB.05', 'limpieza: proyecto temporal eliminado', gone === null);

// ── Ejecutor comun por metodo ────────────────────────────────────────────────
async function runMethod(id, label, config, assertions) {
  const job = await service.createJob(project.id, dataset.id, config);
  check(`${id}.job`, `${label}: job creado (PENDING inicial)`, job.status === 'PENDING');
  const { job: done, timedOut } = await waitForJob(job.id);
  const okState = !timedOut && done.status === 'COMPLETED';
  check(`${id}.done`, `${label}: estado terminal COMPLETED (fue: ${done.status}${timedOut ? ', TIMEOUT' : ''}${done.errorMsg ? ', err=' + String(done.errorMsg).slice(0, 120) : ''})`, okState);
  const hasResult = done.result != null;
  check(`${id}.row`, `${label}: fila en analysis_results`, hasResult);
  if (hasResult) {
    check(`${id}.finite`, `${label}: JSON persistido sin NaN/Infinity/undefined`,
      !containsNonFinite(JSON.parse(JSON.stringify(done.result))));
    await assertions(done.result, done);
  }
  return done;
}

// ── AG.COR — Correlacion ─────────────────────────────────────────────────────
console.log('\n--- [AG.COR] Correlacion ---');
await runMethod('AG.COR', 'correlacion', baseConfig({ analysis_category: 'correlacional', analysis_types: ['vv'] }), async (r) => {
  // decide_method() elige kendall con muestras chicas o >25% de empates
  // (frecuente en puntajes Likert promediados): los tres son validos.
  check('AG.COR.method', `method es pearson/spearman/kendall (${r.method})`,
    ['pearson', 'spearman', 'kendall'].includes(r.method));
  const corr = r.correlations;
  check('AG.COR.rows', 'correlations no vacio', Array.isArray(corr) && corr.length > 0);
  const first = Array.isArray(corr) && corr[0] ? corr[0] : {};
  const rho = Number(first.r ?? first.rho ?? first.coefficient);
  check('AG.COR.rho', `r en [-1,1] (r=${rho})`, Number.isFinite(rho) && rho >= -1 && rho <= 1);
  check('AG.COR.desc', 'descriptives persistidos', Array.isArray(r.descriptives) && r.descriptives.length >= 2);
  check('AG.COR.alpha', 'reliability persistida (alfa de VarA/VarB)', Array.isArray(r.reliability) && r.reliability.length >= 1);
});

// ── AG.ANOVA ────────────────────────────────────────────────────────────────
console.log('\n--- [AG.ANOVA] ANOVA un factor ---');
await runMethod('AG.ANOVA', 'anova', baseConfig({ analysis_category: 'anova', group_var: 'Grupo' }), async (r) => {
  const a = r.anova ?? {};
  check('AG.ANOVA.f', `F >= 0 (F=${a.F})`, Number.isFinite(Number(a.F)) && Number(a.F) >= 0);
  check('AG.ANOVA.p', 'p en [0,1]', Number.isFinite(Number(a.p)) && a.p >= 0 && a.p <= 1);
});

// ── AG.REG1 — Regresion simple ───────────────────────────────────────────────
console.log('\n--- [AG.REG1] Regresion lineal simple ---');
await runMethod('AG.REG1', 'regresion simple', baseConfig({ analysis_category: 'regresion' }), async (r) => {
  const reg = r.regression ?? {};
  check('AG.REG1.r2', `R2 en [0,1] (R2=${reg.R2})`, Number.isFinite(Number(reg.R2)) && reg.R2 >= 0 && reg.R2 <= 1);
  check('AG.REG1.coef', 'intercepto + 1 predictor', Array.isArray(reg.coefficients) && reg.coefficients.length === 2);
  check('AG.REG1.df2int', 'P2-DF2-ROUND: df2 es entero', Number.isInteger(reg.df2));
});

// ── AG.REGM — Regresion multiple ─────────────────────────────────────────────
console.log('\n--- [AG.REGM] Regresion lineal multiple (2 predictores) ---');
await runMethod('AG.REGM', 'regresion multiple', baseConfig({
  analysis_category: 'regresion',
  extra_predictors: [{ name: 'VarC', items: ['C1'], dimensions: [] }],
  regression_predictors: ['VarA', 'VarC'],
}), async (r) => {
  const reg = r.regression ?? {};
  check('AG.REGM.coef', 'intercepto + 2 predictores', Array.isArray(reg.coefficients) && reg.coefficients.length === 3);
  const terms = (reg.coefficients ?? []).map((c) => c.term);
  check('AG.REGM.terms', `terminos incluyen VarA y VarC (${terms.join('/')})`,
    terms.some((t) => String(t).includes('VarA')) && terms.some((t) => String(t).includes('VarC')));
});

// ── AG.LOG — Logistica binaria con event_level ───────────────────────────────
console.log('\n--- [AG.LOG] Logistica binaria (event_level=1) ---');
await runMethod('AG.LOG', 'logistica binaria', baseConfig({
  analysis_category: 'logistica',
  logistic_type: 'binaria',
  var_b: { name: 'VDBin', items: ['YBIN'], dimensions: [] },
  event_level: '1',
}), async (r) => {
  const lg = r.logistic ?? {};
  check('AG.LOG.event', `event_level persistido == '1' (${lg.event_level})`, String(lg.event_level) === '1');
  check('AG.LOG.auc', `AUC en [0,1] (${lg.roc?.auc})`, Number.isFinite(Number(lg.roc?.auc)) && lg.roc.auc >= 0 && lg.roc.auc <= 1);
  check('AG.LOG.or', 'coeficientes con OR', Array.isArray(lg.coefficients) && lg.coefficients.every((c) => 'OR' in c));
});

// ── AG.ORD — Regresion ordinal con ordered_levels ────────────────────────────
console.log('\n--- [AG.ORD] Regresion ordinal (ordered_levels=[1,2,3]) ---');
await runMethod('AG.ORD', 'regresion ordinal', baseConfig({
  analysis_category: 'regresion_ordinal',
  var_b: { name: 'VDOrd', items: ['YORD'], dimensions: [] },
  measurement_level_b: 'ordinal',
  ordered_levels: ['1', '2', '3'],
}), async (r) => {
  const od = r.ordinal_regression ?? {};
  check('AG.ORD.conv', `modelo convergio (converged=${od.converged})`, od.converged === true);
  check('AG.ORD.coef', 'coeficientes presentes', Array.isArray(od.coefficients) && od.coefficients.length >= 1);
  // Los umbrales "1|2","2|3" prueban que el modelo uso exactamente el orden declarado 1<2<3
  const thr = (od.thresholds ?? []).map((t) => t.threshold);
  check('AG.ORD.orden', `umbrales en orden declarado (${thr.join(',')})`,
    thr.length === 2 && thr[0] === '1|2' && thr[1] === '2|3');
});

// ── AG.CHI — Chi-cuadrado ────────────────────────────────────────────────────
console.log('\n--- [AG.CHI] Chi-cuadrado de independencia ---');
await runMethod('AG.CHI', 'chi-cuadrado', baseConfig({
  analysis_category: 'chi_cuadrado',
  var_a: { name: 'CatA', items: ['CatA'], dimensions: [] },
  var_b: { name: 'CatB', items: ['CatB'], dimensions: [] },
  measurement_level_a: 'nominal',
  measurement_level_b: 'nominal',
}), async (r) => {
  const chi = r.chi_square ?? {};
  const stat = Number(chi.chi2 ?? chi.statistic);
  check('AG.CHI.stat', `chi2 >= 0 (${stat})`, Number.isFinite(stat) && stat >= 0);
});

// ── AG.ALPHA — Confiabilidad (Cronbach) ──────────────────────────────────────
console.log('\n--- [AG.ALPHA] Confiabilidad (alfa de Cronbach) ---');
await runMethod('AG.ALPHA', 'cronbach', baseConfig({ analysis_category: 'cronbach' }), async (r) => {
  const cr = r.cronbach_only ?? {};
  const alpha = Number(cr.alpha ?? cr.alpha_total ?? cr.cronbach_alpha);
  check('AG.ALPHA.value', `alfa finito y <= 1 (${alpha})`, Number.isFinite(alpha) && alpha <= 1);
});

// ── AG.INSTR — Instrumentos: AFE + AFC ───────────────────────────────────────
console.log('\n--- [AG.INSTR] Instrumentos (AFE + AFC) ---');
await runMethod('AG.INSTR', 'instrumentos', baseConfig({
  analysis_category: 'instrumentos',
  n_factors: 2,
}), async (r) => {
  const inst = r.instruments ?? {};
  const afe = inst.afe ?? inst.efa ?? null;
  const afc = inst.afc ?? inst.cfa ?? null;
  check('AG.INSTR.afe', 'AFE presente en resultado', afe !== null && typeof afe === 'object');
  check('AG.INSTR.afc', 'AFC presente en resultado', afc !== null && typeof afc === 'object');
});

// ── AG.MED — Mediacion simple ────────────────────────────────────────────────
console.log('\n--- [AG.MED] Mediacion simple (X → M → Y) ---');
await runMethod('AG.MED', 'mediacion', baseConfig({
  analysis_category: 'mediacion',
  var_a: { name: 'X', items: ['X'], dimensions: [] },
  var_b: { name: 'Y', items: ['Y'], dimensions: [] },
  mediator: 'M',
  n_boot: 500,
  seed: 12345,
}), async (r) => {
  const med = r.mediation ?? {};
  for (const f of ['a', 'b', 'c_total', 'c_direct', 'indirect', 'ci_lower', 'ci_upper']) {
    check(`AG.MED.${f}`, `campo ${f} presente y finito`, Number.isFinite(Number(med[f])));
  }
  check('AG.MED.nboot', `n_boot_requested == 500 (${med.n_boot_requested})`, Number(med.n_boot_requested) === 500);
  check('AG.MED.type', 'mediation_type es string', typeof med.mediation_type === 'string' && med.mediation_type.length > 0);
});

await finish('AG');
