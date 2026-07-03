// ============================================================================
// Suite AI — JSON finito: rejectNonFinite() dinamico + persistencia real
//
// Prueba la funcion exportada del servicio compilado (no una copia) con el
// objeto exacto del protocolo, y persiste el resultado en PostgreSQL para
// verificar que la base nunca contiene NaN/Infinity/undefined.
// ============================================================================

import {
  prisma, rejectNonFinite, check, finish,
  buildStandardCsv, seedProjectWithDataset, containsNonFinite,
} from './_harness.mjs';

console.log('=== SUITE AI — JSON FINITO (rejectNonFinite + PostgreSQL) ===\n');

check('AI.EXPORT.01', 'rejectNonFinite exportada desde el servicio compilado',
  typeof rejectNonFinite === 'function');

// ── AI.FN — Caso del protocolo ───────────────────────────────────────────────
console.log('--- [AI.FN] Objeto del protocolo ---');
const input = {
  a: NaN,
  b: Infinity,
  c: -Infinity,
  d: undefined,
  nested: { x: [1, NaN, 3] },
};
const out = rejectNonFinite(input);
check('AI.FN.01', 'a: NaN → null', out.a === null);
check('AI.FN.02', 'b: Infinity → null', out.b === null);
check('AI.FN.03', 'c: -Infinity → null', out.c === null);
check('AI.FN.04', 'd: undefined → null', out.d === null);
check('AI.FN.05', 'nested.x → [1, null, 3]',
  Array.isArray(out.nested.x) && out.nested.x[0] === 1 && out.nested.x[1] === null && out.nested.x[2] === 3);
check('AI.FN.06', 'valores finitos intactos', rejectNonFinite({ k: 2.5, s: 'ok', b: true }).k === 2.5);
check('AI.FN.07', 'strings "NaN" (texto legitimo) no se tocan', rejectNonFinite({ s: 'NaN' }).s === 'NaN');
check('AI.FN.08', 'null se conserva como null', rejectNonFinite(null) === null);
check('AI.FN.09', 'numeros anidados profundos saneados',
  rejectNonFinite({ a: { b: { c: [Infinity] } } }).a.b.c[0] === null);

// ── AI.DB — Persistencia real en PostgreSQL ──────────────────────────────────
console.log('\n--- [AI.DB] Persistencia del objeto saneado ---');
const csvPath = buildStandardCsv();
const { project, dataset } = await seedProjectWithDataset(csvPath, 'ai');

const job = await prisma.analysisJob.create({
  data: {
    projectId: project.id,
    datasetId: dataset.id,
    status: 'COMPLETED',
    config: {},
    startedAt: new Date(),
    finishedAt: new Date(),
  },
});
const row = await prisma.analysisResult.create({
  data: {
    jobId: job.id,
    method: 'ai_suite_probe',
    diagnostic: out,
    descriptives: [],
    reliability: [],
    normality: [],
    correlations: [],
    interpretations: {},
    warnings: [],
  },
});

const rawText = await prisma.$queryRaw`
  SELECT diagnostic::text AS txt FROM analysis_results WHERE id = ${row.id}
`;
const txt = rawText[0].txt;
check('AI.DB.01', 'fila persistida y recuperada', typeof txt === 'string' && txt.length > 0);
check('AI.DB.02', 'texto SQL sin token NaN', !/\bNaN\b/.test(txt));
check('AI.DB.03', 'texto SQL sin token Infinity', !/Infinity/.test(txt));
check('AI.DB.04', 'texto SQL sin undefined', !/undefined/.test(txt));

const readBack = await prisma.analysisResult.findUnique({ where: { id: row.id } });
check('AI.DB.05', 'a/b/c/d leidos como null',
  readBack.diagnostic.a === null && readBack.diagnostic.b === null &&
  readBack.diagnostic.c === null && readBack.diagnostic.d === null);
check('AI.DB.06', 'nested.x == [1,null,3]',
  JSON.stringify(readBack.diagnostic.nested.x) === '[1,null,3]');
check('AI.DB.07', 'containsNonFinite() del objeto leido es false', !containsNonFinite(readBack.diagnostic));

// ── AI.ALL — Barrido de TODOS los resultados de la base CI ──────────────────
console.log('\n--- [AI.ALL] Barrido global de analysis_results ---');
const offenders = await prisma.$queryRaw`
  SELECT id FROM analysis_results
  WHERE diagnostic::text ~ '(NaN|Infinity)'
     OR regression::text ~ '(NaN|Infinity)'
     OR logistic::text ~ '(NaN|Infinity)'
     OR mediation::text ~ '(NaN|Infinity)'
     OR ordinal_regression::text ~ '(NaN|Infinity)'
`;
check('AI.ALL.01', `ningun resultado en la base contiene NaN/Infinity (${offenders.length} filas)`, offenders.length === 0);

await finish('AI');
