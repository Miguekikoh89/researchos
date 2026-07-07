// ============================================================================
// Suite AK — Seguridad dinamica a nivel Node + Word real vs JSON (Fases J y K)
//
// Ejecuta (no inspecciona): path traversal, MIME falso, archivo vacio,
// tamano excedido, timeout real, concurrencia y limpieza de temporales.
// Ademas genera un Word real via pipeline y compara su contenido con el
// JSON persistido.
// ============================================================================

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import {
  prisma, makeService, check, finish,
  buildStandardCsv, writeCsv, seedProjectWithDataset, waitForJob, baseConfig,
} from './_harness.mjs';

console.log('=== SUITE AK — SEGURIDAD DINAMICA + WORD REAL (NODE) ===\n');

const csvPath = buildStandardCsv();
const { project, dataset } = await seedProjectWithDataset(csvPath, 'ak');
const service = makeService();

async function runWithStoredPath(storedPath, cfg = {}, svc = service, sizeBytes = 1) {
  const ds = await prisma.dataset.create({
    data: {
      projectId: project.id,
      originalName: path.basename(storedPath),
      storedPath,
      mimeType: 'text/csv',
      sizeBytes,
    },
  });
  const job = await svc.createJob(project.id, ds.id, baseConfig({ analysis_category: 'correlacional', ...cfg }));
  const { job: done } = await waitForJob(job.id, 90000);
  return done;
}

const tmpFilesSnapshot = () =>
  fs.readdirSync(os.tmpdir()).filter((f) => /^analysis_.*_config\.json$/.test(f));

const tmpBefore = tmpFilesSnapshot();

// ── AK.TRAV — Path traversal ─────────────────────────────────────────────────
console.log('--- [AK.TRAV] Path traversal ---');
const trav1 = await runWithStoredPath('../../../../etc/passwd');
check('AK.TRAV.01', `ruta relativa maliciosa → FAILED (${trav1.status})`, trav1.status === 'FAILED');
check('AK.TRAV.02', 'sin resultado persistido', trav1.result === null);

const trav2 = await runWithStoredPath('/etc/passwd');
check('AK.TRAV.03', `/etc/passwd (sin extension valida) → FAILED (${trav2.status})`, trav2.status === 'FAILED');
check('AK.TRAV.04', 'errorMsg NO expone contenido del archivo',
  !/root:|:0:0:/.test(trav2.errorMsg ?? ''));

// ── AK.MIME — MIME falso: binario con extension .csv ────────────────────────
console.log('\n--- [AK.MIME] Contenido binario con extension .csv ---');
const binDir = fs.mkdtempSync(path.join(os.tmpdir(), 'cancharios-bin-'));
const binPath = path.join(binDir, 'falso.csv');
fs.writeFileSync(binPath, Buffer.from([0x7f, 0x45, 0x4c, 0x46, 0x00, 0x01, 0xff, 0xfe, 0x00, 0x9c]));
const mime = await runWithStoredPath(binPath);
check('AK.MIME.01', `binario .csv → estado terminal controlado (${mime.status})`,
  mime.status === 'FAILED' || mime.status === 'COMPLETED');
check('AK.MIME.02', 'si fallo, errorMsg presente; nunca cuelga el proceso',
  mime.status !== 'FAILED' || (mime.errorMsg ?? '').length > 0);

// ── AK.EMPTY — Archivo vacio ─────────────────────────────────────────────────
console.log('\n--- [AK.EMPTY] Archivo vacio ---');
const emptyPath = path.join(binDir, 'vacio.csv');
fs.writeFileSync(emptyPath, '');
const empty = await runWithStoredPath(emptyPath);
check('AK.EMPTY.01', `csv vacio → FAILED (${empty.status})`, empty.status === 'FAILED');
check('AK.EMPTY.02', 'error controlado con mensaje', (empty.errorMsg ?? '').length > 0);

// ── AK.SIZE — Limite de 50 MB ────────────────────────────────────────────────
console.log('\n--- [AK.SIZE] Archivo > 50 MB rechazado ---');
const bigPath = path.join(binDir, 'grande.csv');
const chunk = 'A1,A2\n' + '3,4\n'.repeat(1024 * 256); // ~1MB
const fd = fs.openSync(bigPath, 'w');
for (let i = 0; i < 52; i++) fs.writeSync(fd, chunk);
fs.closeSync(fd);
const big = await runWithStoredPath(bigPath, {}, service, fs.statSync(bigPath).size);
check('AK.SIZE.01', `csv de ${(fs.statSync(bigPath).size / 1048576).toFixed(0)}MB → FAILED (${big.status})`, big.status === 'FAILED');
check('AK.SIZE.02', 'errorMsg menciona el limite de tamano', /50\s*MB|limite|supera/i.test(big.errorMsg ?? ''));
fs.rmSync(bigPath, { force: true });

// ── AK.TIMEOUT — Timeout real del motor R ────────────────────────────────────
console.log('\n--- [AK.TIMEOUT] Timeout del proceso R ---');
const fastTimeoutService = makeService({ R_TIMEOUT_MS: '2500' });
const slow = await (async () => {
  const job = await fastTimeoutService.createJob(project.id, dataset.id, baseConfig({
    analysis_category: 'mediacion',
    var_a: { name: 'X', items: ['X'], dimensions: [] },
    var_b: { name: 'Y', items: ['Y'], dimensions: [] },
    mediator: 'M',
    n_boot: 2000000, // fuerza a exceder los 2.5s del timeout
    seed: 7,
  }));
  const { job: done } = await waitForJob(job.id, 90000);
  return done;
})();
check('AK.TIMEOUT.01', `job con R colgado termina FAILED (${slow.status})`, slow.status === 'FAILED');
check('AK.TIMEOUT.02', 'errorMsg registrado tras timeout', (slow.errorMsg ?? '').length > 0);
check('AK.TIMEOUT.03', 'sin resultado persistido tras timeout', slow.result === null);

// ── AK.CONC — Concurrencia: dos jobs simultaneos no se mezclan ───────────────
console.log('\n--- [AK.CONC] Dos jobs simultaneos ---');
// Dataset B con relacion X→Y distinta para distinguir resultados
const rows2 = [];
for (let i = 0; i < 60; i++) {
  const x = (i % 10) + 1;
  rows2.push([x, 11 - x]); // correlacion negativa perfecta-ish
}
const csv2 = writeCsv('inverso.csv', ['P1', 'Q1'], rows2);
const ds2 = await prisma.dataset.create({
  data: {
    projectId: project.id, originalName: 'inverso.csv', storedPath: csv2,
    mimeType: 'text/csv', sizeBytes: fs.statSync(csv2).size,
  },
});
const cfgA = baseConfig({ analysis_category: 'regresion' });
const cfgB = baseConfig({
  analysis_category: 'regresion',
  var_a: { name: 'P', items: ['P1'], dimensions: [] },
  var_b: { name: 'Q', items: ['Q1'], dimensions: [] },
});
const [jobA, jobB] = await Promise.all([
  service.createJob(project.id, dataset.id, cfgA),
  service.createJob(project.id, ds2.id, cfgB),
]);
const [doneA, doneB] = await Promise.all([waitForJob(jobA.id), waitForJob(jobB.id)]);
check('AK.CONC.01', `job A COMPLETED (${doneA.job.status})`, doneA.job.status === 'COMPLETED');
check('AK.CONC.02', `job B COMPLETED (${doneB.job.status})`, doneB.job.status === 'COMPLETED');
const slopeA = (doneA.job.result?.regression?.coefficients ?? []).find((c) => !/intercept/i.test(c.term))?.B;
const slopeB = (doneB.job.result?.regression?.coefficients ?? []).find((c) => !/intercept/i.test(c.term))?.B;
check('AK.CONC.03', `resultados no mezclados: pendiente A>0 (${slopeA}) y B<0 (${slopeB})`,
  Number(slopeA) > 0 && Number(slopeB) < 0);
check('AK.CONC.04', 'cada resultado apunta a su job', doneA.job.result.jobId === jobA.id && doneB.job.result.jobId === jobB.id);

// ── AK.LEAK — errorMsg no expone secretos ────────────────────────────────────
console.log('\n--- [AK.LEAK] errorMsg sin secretos ---');
const allFailed = await prisma.analysisJob.findMany({ where: { status: 'FAILED' }, select: { errorMsg: true } });
const dbUrl = process.env.DATABASE_URL;
const leaky = allFailed.filter((j) =>
  (j.errorMsg ?? '').includes(dbUrl) || /postgresql:\/\/[^\s]*:[^\s]*@/.test(j.errorMsg ?? ''));
check('AK.LEAK.01', `ningun errorMsg contiene DATABASE_URL ni credenciales (${allFailed.length} revisados)`, leaky.length === 0);

// ── AK.TEMP — Limpieza de temporales tras exito, fallo y timeout ────────────
console.log('\n--- [AK.TEMP] Temporales de configuracion limpiados ---');
const tmpAfter = tmpFilesSnapshot();
const leftovers = tmpAfter.filter((f) => !tmpBefore.includes(f));
check('AK.TEMP.01', `sin analysis_*_config.json huerfanos (${leftovers.length})`, leftovers.length === 0);

// ── AK.WORD — Word real generado por el pipeline vs JSON persistido ─────────
console.log('\n--- [AK.WORD] Word real (export_word) contra JSON ---');
const wordJob = await service.createJob(project.id, dataset.id, baseConfig({
  analysis_category: 'regresion',
  export_word: true,
  study_title: 'Auditoria AK Word',
}));
const { job: wordDone } = await waitForJob(wordJob.id);
check('AK.WORD.01', `job con export_word COMPLETED (${wordDone.status})`, wordDone.status === 'COMPLETED');
const wordPath = wordDone.result?.wordPath ?? null;
check('AK.WORD.02', `wordPath persistido (${wordPath})`, typeof wordPath === 'string' && wordPath.length > 0);

if (wordPath && fs.existsSync(wordPath)) {
  check('AK.WORD.03', 'archivo .docx existe en disco', true);
  const head = fs.readFileSync(wordPath).subarray(0, 2);
  check('AK.WORD.04', 'es ZIP valido (magia PK)', head[0] === 0x50 && head[1] === 0x4b);
  let xml = '';
  try {
    xml = execFileSync('unzip', ['-p', wordPath, 'word/document.xml'], { maxBuffer: 32 * 1024 * 1024 }).toString('utf8');
  } catch { /* unzip no disponible o docx corrupto */ }
  check('AK.WORD.05', 'word/document.xml extraible y no vacio', xml.length > 500);
  const cellTexts = [...xml.matchAll(/<w:t[^>]*>([^<]*)<\/w:t>/g)].map((m) => m[1]);
  const joined = cellTexts.join(' ');
  const reg = wordDone.result?.regression ?? {};
  const r2Str = Number(reg.R2).toFixed(3).replace(/^0\./, '.');
  const r2Alt = String(Number(reg.R2));
  check('AK.WORD.06', `R2 del JSON (${reg.R2}) aparece en el documento`,
    joined.includes(r2Alt) || joined.includes(r2Str) || joined.includes(Number(reg.R2).toFixed(3)));
  const slope = (reg.coefficients ?? []).find((c) => !/intercept/i.test(c.term));
  const bStr = slope ? String(slope.B) : '__no__';
  check('AK.WORD.07', `coeficiente B (${bStr}) aparece en las celdas del documento`,
    cellTexts.some((t) => t.includes(bStr) || t.includes(Number(bStr).toFixed(3))));
  check('AK.WORD.08', 'el documento menciona las variables del analisis',
    /VarA|VarB/.test(joined));
} else {
  check('AK.WORD.03', 'archivo .docx existe en disco', false);
}

await finish('AK');
