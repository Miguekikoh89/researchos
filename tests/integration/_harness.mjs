// ============================================================================
// tests/integration/_harness.mjs
// Harness compartido para las suites de integracion Node → R → PostgreSQL.
//
// NO mockea R: instancia el AnalysisService compilado (apps/api/dist) con un
// PrismaClient real contra la base de CI y deja que el servicio lance
// Rscript run_analysis.R exactamente como en produccion.
//
// Requiere:
//   - DATABASE_URL apuntando a una base PostgreSQL exclusiva de CI
//   - apps/api compilada (npm run build)
//   - /app/stats-engine-r -> apps/api/stats-engine-r (symlink, layout prod)
// ============================================================================

import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const REPO_ROOT = path.resolve(__dirname, '..', '..');
const API_DIST = path.join(REPO_ROOT, 'apps', 'api', 'dist');

const { PrismaClient } = require('@prisma/client');
const serviceModule = require(path.join(API_DIST, 'analysis', 'analysis.service.js'));

export const AnalysisService = serviceModule.AnalysisService;
export const rejectNonFinite = serviceModule.rejectNonFinite;

if (!process.env.DATABASE_URL) {
  console.error('[FATAL] DATABASE_URL no definida — esta suite requiere PostgreSQL de CI.');
  process.exit(1);
}
if (/railway|prod/i.test(process.env.DATABASE_URL)) {
  console.error('[FATAL] DATABASE_URL parece apuntar a produccion. Abortando.');
  process.exit(1);
}

export const prisma = new PrismaClient();

// ── ConfigService minimo (mismo contrato .get(key) que @nestjs/config) ──────
export function makeConfigService(overrides = {}) {
  const defaults = {
    R_ENGINE_PATH: path.join(REPO_ROOT, 'apps', 'api', 'stats-engine-r', 'run_analysis.R'),
    R_BIN: 'Rscript',
    R_TIMEOUT_MS: '120000',
    OUTPUT_DIR: path.join(os.tmpdir(), 'researchos-outputs'),
  };
  const map = { ...defaults, ...overrides };
  return { get: (key) => map[key] ?? process.env[key] };
}

export function makeService(configOverrides = {}) {
  return new AnalysisService(prisma, makeConfigService(configOverrides));
}

// ── Contadores PASS/FAIL (mismo convenio que las suites R) ──────────────────
let pass = 0, fail = 0, skip = 0;

export function check(id, desc, cond) {
  const ok = cond === true;
  console.log(`  [${ok ? 'PASS' : 'FAIL'}] ${id}: ${desc}`);
  if (ok) pass++; else fail++;
  return ok;
}

export function skipCheck(id, desc) {
  console.log(`  [SKIP] ${id}: ${desc}`);
  skip++;
}

export function summary(suiteName) {
  console.log(`\n=== SUITE ${suiteName}: ${pass} PASS / ${fail} FAIL${skip ? ` / ${skip} SKIP` : ''} ===`);
  return fail;
}

export async function finish(suiteName) {
  const failures = summary(suiteName);
  await prisma.$disconnect();
  process.exit(failures > 0 ? 1 : 0);
}

// ── Fixtures de datos ────────────────────────────────────────────────────────
// PRNG determinista (LCG) para que los CSV sean reproducibles entre corridas.
export function makeRng(seed = 42) {
  let s = seed >>> 0;
  return () => {
    s = (1664525 * s + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

// Normal aproximada (suma de 12 uniformes, media 0, sd 1)
export function makeNormal(rng) {
  return () => {
    let acc = 0;
    for (let i = 0; i < 12; i++) acc += rng();
    return acc - 6;
  };
}

export function writeCsv(fileName, header, rows) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cancharios-it-'));
  const p = path.join(dir, fileName);
  const lines = [header.join(','), ...rows.map((r) => r.join(','))];
  fs.writeFileSync(p, lines.join('\n') + '\n', 'utf8');
  return p;
}

// Dataset estandar N=120: items Likert A1-A4/B1-B4 correlacionados,
// grupo de 3 niveles, VD binaria 0/1, VD ordinal 1/2/3, X/M/Y de mediacion,
// C1 predictor extra, CatA/CatB categoricas.
export function buildStandardCsv() {
  const rng = makeRng(20260703);
  const nrm = makeNormal(rng);
  const N = 120;
  const header = ['A1','A2','A3','A4','B1','B2','B3','B4','C1','Grupo','YBIN','YORD','X','M','Y','CatA','CatB'];
  const rows = [];
  const clamp15 = (v) => Math.min(5, Math.max(1, Math.round(v)));
  for (let i = 0; i < N; i++) {
    const latent = nrm();
    const a = [0, 1, 2, 3].map(() => clamp15(3 + 1.0 * latent + 0.7 * nrm()));
    const b = [0, 1, 2, 3].map(() => clamp15(3 + 0.8 * latent + 0.9 * nrm()));
    const c1 = +(2 + 0.5 * latent + nrm()).toFixed(4);
    const grupo = ['G1', 'G2', 'G3'][i % 3];
    const groupShift = { G1: -0.8, G2: 0, G3: 0.8 }[grupo];
    const x = +(latent + nrm() * 0.5 + groupShift).toFixed(4);
    const m = +(0.6 * x + nrm() * 0.6).toFixed(4);
    const y = +(0.5 * m + 0.3 * x + nrm() * 0.6).toFixed(4);
    const ybin = (1 / (1 + Math.exp(-(0.9 * latent + 0.3 * nrm())))) > 0.5 ? 1 : 0;
    const yord = latent < -0.45 ? 1 : latent < 0.45 ? 2 : 3;
    const catA = 1 + (i % 3);
    const catB = ybin + 1;
    rows.push([...a, ...b, c1, grupo, ybin, yord, x, m, y, catA, catB]);
  }
  return writeCsv('standard.csv', header, rows);
}

// ── Seed de entidades (usuario/proyecto/dataset) ─────────────────────────────
export async function seedProjectWithDataset(csvPath, tag) {
  const stamp = `${tag}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const user = await prisma.user.create({
    data: {
      email: `audit_${stamp}@ci.local`,
      name: `Auditoria CI ${tag}`,
      password: 'x'.repeat(60), // hash ficticio; no hay login en estos tests
    },
  });
  const project = await prisma.project.create({
    data: { name: `Proyecto CI ${stamp}`, userId: user.id },
  });
  const dataset = await prisma.dataset.create({
    data: {
      projectId: project.id,
      originalName: path.basename(csvPath),
      storedPath: csvPath,
      mimeType: 'text/csv',
      sizeBytes: fs.existsSync(csvPath) ? fs.statSync(csvPath).size : 0,
    },
  });
  return { user, project, dataset };
}

// ── Esperar a que un job alcance estado terminal ─────────────────────────────
export async function waitForJob(jobId, timeoutMs = 120000) {
  const started = Date.now();
  const seen = new Set();
  for (;;) {
    const job = await prisma.analysisJob.findUnique({
      where: { id: jobId },
      include: { result: true },
    });
    seen.add(job.status);
    if (job.status === 'COMPLETED' || job.status === 'FAILED') {
      return { job, statesSeen: seen };
    }
    if (Date.now() - started > timeoutMs) {
      return { job, statesSeen: seen, timedOut: true };
    }
    await new Promise((r) => setTimeout(r, 250));
  }
}

// Config base comun a todos los metodos (VarA/VarB Likert del CSV estandar)
export function baseConfig(extra = {}) {
  return {
    sheet: 1,
    has_header: true,
    imputation: 'none',
    var_a: { name: 'VarA', items: ['A1', 'A2', 'A3', 'A4'], dimensions: [] },
    var_b: { name: 'VarB', items: ['B1', 'B2', 'B3', 'B4'], dimensions: [] },
    scale: { min: 1, max: 5 },
    baremo_method: 'percentil',
    baremo_levels: ['Bajo', 'Medio', 'Alto'],
    normality_tests: ['sw'],
    method_force: 'auto',
    alpha: 0.05,
    include_reliability: true,
    export_word: false,
    ...extra,
  };
}

// Recorre un objeto JSON persistido y devuelve true si algun valor es
// NaN/Infinity (numerico o string) o undefined.
export function containsNonFinite(value) {
  if (value === null) return false;
  if (value === undefined) return true;
  if (typeof value === 'number') return !Number.isFinite(value);
  if (typeof value === 'string') {
    return value === 'NaN' || value === 'Infinity' || value === '-Infinity';
  }
  if (Array.isArray(value)) return value.some(containsNonFinite);
  if (typeof value === 'object') return Object.values(value).some(containsNonFinite);
  return false;
}
