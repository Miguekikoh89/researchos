// ============================================================================
// Suite AH — Estados dinamicos de jobs contra PostgreSQL real
//
// Exito:               PENDING → PROCESSING → COMPLETED
// Bloqueo metodologico: PENDING → PROCESSING → FAILED (guard del motor R)
// Error tecnico:        PENDING → PROCESSING → FAILED (archivo invalido)
//
// Regla dura: ningun analisis bloqueado o errado termina COMPLETED.
// ============================================================================

import {
  prisma, makeService, check, skipCheck, finish,
  buildStandardCsv, seedProjectWithDataset, waitForJob, baseConfig,
} from './_harness.mjs';

console.log('=== SUITE AH — ESTADOS DINAMICOS DE JOBS ===\n');

const csvPath = buildStandardCsv();
const { project, dataset } = await seedProjectWithDataset(csvPath, 'ah');
const service = makeService();

// ── AH.OK — Flujo de exito ───────────────────────────────────────────────────
console.log('--- [AH.OK] PENDING → PROCESSING → COMPLETED ---');
const okJob = await service.createJob(project.id, dataset.id, baseConfig({ analysis_category: 'correlacional' }));
check('AH.OK.01', 'estado inicial PENDING', okJob.status === 'PENDING');
const { job: okDone, statesSeen } = await waitForJob(okJob.id);
check('AH.OK.02', `estado terminal COMPLETED (${okDone.status})`, okDone.status === 'COMPLETED');
check('AH.OK.03', 'startedAt registrado', okDone.startedAt !== null);
check('AH.OK.04', 'finishedAt registrado', okDone.finishedAt !== null);
check('AH.OK.05', 'finishedAt >= startedAt', new Date(okDone.finishedAt) >= new Date(okDone.startedAt));
check('AH.OK.06', 'errorMsg es null en exito', okDone.errorMsg === null);
check('AH.OK.07', 'resultado persistido en exito', okDone.result !== null);
// PROCESSING es transitorio: si el poll fue mas lento que R puede no observarse,
// pero startedAt (que solo escribe la transicion a PROCESSING) lo demuestra.
check('AH.OK.08', `transicion por PROCESSING demostrada (visto=${[...statesSeen].join(',')} o startedAt)`,
  statesSeen.has('PROCESSING') || okDone.startedAt !== null);

// ── AH.BLOCK — Bloqueo metodologico ─────────────────────────────────────────
console.log('\n--- [AH.BLOCK] Guard metodologico → FAILED ---');
const blockJob = await service.createJob(project.id, dataset.id, baseConfig({
  analysis_category: 'logistica',
  logistic_type: 'binaria',
  var_b: { name: 'VDBin', items: ['YBIN'], dimensions: [] },
  // sin event_level → EVENTO_NO_DECLARADO
}));
const { job: blockDone } = await waitForJob(blockJob.id);
check('AH.BLOCK.01', `bloqueo metodologico termina FAILED (${blockDone.status})`, blockDone.status === 'FAILED');
check('AH.BLOCK.02', 'errorMsg presente', typeof blockDone.errorMsg === 'string' && blockDone.errorMsg.length > 0);
check('AH.BLOCK.03', `errorMsg explica el guard (${String(blockDone.errorMsg).slice(0, 60)}...)`,
  /event_level|evento/i.test(blockDone.errorMsg ?? ''));
check('AH.BLOCK.04', 'finishedAt registrado en fallo', blockDone.finishedAt !== null);
check('AH.BLOCK.05', 'SIN fila de resultado en bloqueo', blockDone.result === null);
// El schema de AnalysisJob no tiene columnas reason/stage/details separadas;
// esa informacion viaja en errorMsg. Restriccion documentada en la auditoria.
skipCheck('AH.BLOCK.06', 'reason/stage como columnas separadas — no existen en schema (documentado)');

// ── AH.SERIAL — Mediacion serial deshabilitada ──────────────────────────────
console.log('\n--- [AH.SERIAL] Mediacion serial → FAILED con razon ---');
const serialJob = await service.createJob(project.id, dataset.id, baseConfig({
  analysis_category: 'mediacion',
  var_a: { name: 'X', items: ['X'], dimensions: [] },
  var_b: { name: 'Y', items: ['Y'], dimensions: [] },
  mediator: 'M',
  mediators: ['M', 'A1'],
  n_boot: 100,
  seed: 1,
}));
const { job: serialDone } = await waitForJob(serialJob.id);
check('AH.SERIAL.01', `mediacion serial termina FAILED (${serialDone.status})`, serialDone.status === 'FAILED');
check('AH.SERIAL.02', 'errorMsg menciona mediacion serial no disponible',
  /serial/i.test(serialDone.errorMsg ?? ''));
check('AH.SERIAL.03', 'SIN resultado persistido', serialDone.result === null);

// ── AH.TECH — Error tecnico (archivo inexistente) ───────────────────────────
console.log('\n--- [AH.TECH] Error tecnico → FAILED controlado ---');
const ghost = await prisma.dataset.create({
  data: {
    projectId: project.id,
    originalName: 'no-existe.csv',
    storedPath: '/tmp/cancharios-no-existe-nunca.csv',
    mimeType: 'text/csv',
    sizeBytes: 0,
  },
});
const techJob = await service.createJob(project.id, ghost.id, baseConfig({ analysis_category: 'correlacional' }));
const { job: techDone } = await waitForJob(techJob.id);
check('AH.TECH.01', `archivo inexistente termina FAILED (${techDone.status})`, techDone.status === 'FAILED');
check('AH.TECH.02', 'errorMsg presente y controlado',
  typeof techDone.errorMsg === 'string' && techDone.errorMsg.length > 0);
check('AH.TECH.03', 'SIN resultado persistido', techDone.result === null);
check('AH.TECH.04', 'finishedAt registrado', techDone.finishedAt !== null);

// ── AH.NEVER — Invariante global sobre TODOS los jobs de la base CI ─────────
console.log('\n--- [AH.NEVER] Invariantes globales ---');
const badCompleted = await prisma.analysisJob.findMany({
  where: { status: 'COMPLETED', result: null },
});
check('AH.NEVER.01', 'ningun COMPLETED sin fila de resultado', badCompleted.length === 0);
const failedWithResult = await prisma.analysisJob.findMany({
  where: { status: 'FAILED', result: { isNot: null } },
});
check('AH.NEVER.02', 'ningun FAILED con resultado persistido', failedWithResult.length === 0);
const stuck = await prisma.analysisJob.findMany({
  where: { status: 'COMPLETED', OR: [{ startedAt: null }, { finishedAt: null }] },
});
check('AH.NEVER.03', 'todo COMPLETED tiene startedAt y finishedAt', stuck.length === 0);

await finish('AH');
