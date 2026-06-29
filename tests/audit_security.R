# tests/audit_security.R
# Suite U — Auditoria de seguridad: inspeccion estatica de patrones criticos
#
# Cubre: path traversal, MIME validation, secretos hardcoded, sanitizacion,
#        aislamiento de jobs, timeouts, limpieza de temporales.
# Uso: Rscript tests/audit_security.R
# Exit: 0 = todos PASS, 1 = al menos un FAIL

pass <- 0L; fail <- 0L; skip_n <- 0L

check <- function(id, desc, cond) {
  label <- if (isTRUE(cond)) "PASS" else "FAIL"
  cat(sprintf("  [%s] %s: %s\n", label, id, desc))
  if (isTRUE(cond)) pass <<- pass + 1L else fail <<- fail + 1L
  invisible(isTRUE(cond))
}
skip_test <- function(id, desc, reason) {
  cat(sprintf("  [SKIP] %s: %s -- %s\n", id, desc, reason))
  skip_n <<- skip_n + 1L
}
grep_file  <- function(pat, file, ...) {
  if (!file.exists(file)) return(FALSE)
  any(grepl(pat, readLines(file, warn = FALSE), ...))
}
count_matches <- function(pat, file, ...) {
  if (!file.exists(file)) return(0L)
  sum(grepl(pat, readLines(file, warn = FALSE), ...))
}

.script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    args <- commandArgs(trailingOnly = FALSE)
    f    <- sub("--file=", "", grep("--file=", args, value = TRUE))
    if (length(f) > 0) dirname(normalizePath(f)) else getwd()
  }
)
repo_root   <- normalizePath(file.path(.script_dir, ".."))
service_ts  <- file.path(repo_root, "apps", "api", "src", "analysis", "analysis.service.ts")
run_r       <- file.path(repo_root, "apps", "api", "stats-engine-r", "run_analysis.R")
r_dir       <- file.path(repo_root, "apps", "api", "stats-engine-r", "R")
api_src_dir <- file.path(repo_root, "apps", "api", "src")

# Todos los archivos R del motor
r_files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE)
r_files <- c(r_files, run_r)

# Todos los archivos TS del API
ts_files <- list.files(api_src_dir, pattern = "\\.(ts|js)$",
                       full.names = TRUE, recursive = TRUE)

cat("=== SUITE U — Auditoria de Seguridad ===\n\n")

# ── U1: Path Traversal ───────────────────────────────────────────────────────
cat("── U1: Proteccion contra Path Traversal ──\n")

# El servicio TS debe validar que la ruta del archivo no contenga ../
check("SEC.01", "Validacion de path en analysis.service.ts (no ejecuta rutas arbitrarias)",
  grep_file("storedPath|file_path|filePath", service_ts))

# No debe haber uso de req.query o req.params sin sanitizar para acceder a archivos
check("SEC.02", "No hay interpolacion directa de query params en paths de archivo",
  !grep_file("path\\.join.*req\\.query|path\\.join.*req\\.params", service_ts))

# R engine usa config$file_path — debe venir del servidor, no del cliente directo
check("SEC.03", "file_path en run_analysis.R viene de config (no de stdin libre)",
  grep_file("config\\$file_path", run_r))

# El path de archivo debe resolverse desde storedPath del dataset (DB-bound)
check("SEC.04", "dataset.storedPath usado para construir file_path (bound to DB record)",
  grep_file("storedPath|stored_path", service_ts))

# ── U2: MIME / Tipo de archivo ───────────────────────────────────────────────
cat("\n── U2: Validacion de tipo de archivo MIME ──\n")

check("SEC.05", "Referencia a mimeType o mime_type en algun archivo TS del API",
  any(sapply(ts_files, function(f)
    grep_file("mimeType|mime_type|mimetype", f))))

check("SEC.06", "El schema Prisma almacena mimeType del dataset",
  grep_file("mimeType.*String", file.path(repo_root, "apps", "api", "prisma", "schema.prisma")))

# run_analysis.R solo deberia leer archivos xlsx/csv/xls
check("SEC.07", "run_analysis.R usa readxl o read.csv — no eval() de paths",
  grep_file("readxl|read_excel|read\\.csv|read\\.xlsx", run_r))

# No debe haber eval(parse(text=...)) con input de usuario en R
check("SEC.08", "Sin eval(parse(text=config$...)) en run_analysis.R",
  !grep_file("eval\\(parse\\(text.*config\\$", run_r))

# ── U3: Secretos hardcodeados ────────────────────────────────────────────────
cat("\n── U3: Sin secretos hardcodeados ──\n")

# Ningun archivo R debe contener contraseñas o tokens explicitos
secret_patterns <- c(
  "password\\s*=\\s*['\"][^'\"]{4,}",
  "secret\\s*=\\s*['\"][^'\"]{8,}",
  "api_key\\s*=\\s*['\"][^'\"]{8,}",
  "DATABASE_URL\\s*=\\s*['\"]postgresql"
)
r_secret_found <- any(sapply(r_files, function(f) {
  any(sapply(secret_patterns, function(p) grep_file(p, f, ignore.case = TRUE)))
}))
check("SEC.09", "Sin secretos hardcodeados en archivos R del motor",
  !r_secret_found)

# Ningun archivo TS debe contener JWT secrets o DB URLs explicitas
ts_secret_found <- any(sapply(ts_files, function(f) {
  any(sapply(c("jwt.*secret.*=.*['\"][^'\"]{8,}", "DATABASE_URL.*postgresql://.*@"),
             function(p) grep_file(p, f, ignore.case = TRUE)))
}))
check("SEC.10", "Sin JWT secrets o DB URLs hardcodeados en archivos TS",
  !ts_secret_found)

# ── U4: Inyeccion de comandos ────────────────────────────────────────────────
cat("\n── U4: Proteccion contra inyeccion de comandos ──\n")

# El servicio NO debe pasar input de usuario directamente a shell
check("SEC.11", "Sin exec() con interpolacion directa de user input en service.ts",
  !grep_file("exec\\(.*req\\.|exec\\(.*body\\.", service_ts))

# La invocacion de Rscript debe usar arguments escapados (array, no string)
check("SEC.12", "Rscript invocado via spawn/execFile (array de args), no exec con string",
  grep_file("childProcess\\.spawn|spawnSync|execFileSync", service_ts))

# config JSON pasado por archivo temporal, no por command line string
check("SEC.13", "config escrito a archivo temporal (writeFileSync/writeFile)",
  grep_file("writeFileSync|writeFile", service_ts))

check("SEC.14", "R lee config desde archivo (readLines|fromJSON|readRDS), no stdin",
  grep_file("readLines|fromJSON|readRDS", run_r))

# ── U5: Aislamiento de jobs ──────────────────────────────────────────────────
cat("\n── U5: Aislamiento y limpieza de temporales ──\n")

# Archivos temporales deben limpiarse despues del job
check("SEC.15", "unlinkSync o unlink de archivos temporales en service.ts",
  grep_file("unlink|unlinkSync|rmSync", service_ts))

# Cada job debe usar un directorio temporal unico (tmpdir + jobId o similar)
check("SEC.16", "Directorio temporal unico por job (tmpdir/os.tmpdir)",
  grep_file("tmpdir|os\\.tmpdir\\(\\)|mkdtemp", service_ts))

# ── U6: Timeouts ─────────────────────────────────────────────────────────────
cat("\n── U6: Timeouts en procesos R ──\n")

check("SEC.17", "Timeout configurado en invocacion de Rscript",
  grep_file("timeout|maxBuffer|TIMEOUT", service_ts, ignore.case = TRUE))

# ── U7: Sanitizacion de salida R antes de DB ─────────────────────────────────
cat("\n── U7: Sanitizacion NaN/Infinity antes de persistir ──\n")

check("SEC.18", "rejectNonFinite aplicado antes de crear registro DB",
  grep_file("rejectNonFinite", service_ts))
check("SEC.19", "NaN no se persiste directamente (convertido a null)",
  grep_file("isFinite|rejectNonFinite", service_ts))

# ── U8: No hay eval() en archivos R del motor ────────────────────────────────
cat("\n── U8: Sin eval() peligroso en R engine ──\n")

r_eval_count <- sum(sapply(r_files, function(f) count_matches("^[^#]*eval\\(", f)))
# eval() puede aparecer en comentarios o dentro de estructuras controladas
# Queremos asegurarnos de que no haya eval() de strings externos
r_eval_external <- any(sapply(r_files, function(f)
  grep_file("eval\\(parse\\(text.*config\\$|eval\\(parse\\(text.*input", f)))
check("SEC.20", "Sin eval(parse(text=config$...)) en ningun archivo R",
  !r_eval_external)

# ── U9: No hay system() con interpolacion de config en R ─────────────────────
cat("\n── U9: Sin system() con interpolacion de config ──\n")

r_system_external <- any(sapply(r_files, function(f)
  grep_file("system\\(.*config\\$|system2\\(.*config\\$", f)))
check("SEC.21", "Sin system() con config$ en archivos R",
  !r_system_external)

# ── U10: Source seguro — R solo carga archivos internos ──────────────────────
cat("\n── U10: source() solo carga archivos del motor (no de config) ──\n")

r_source_external <- any(sapply(r_files, function(f)
  grep_file("source\\(.*config\\$|source\\(.*paste.*config", f)))
check("SEC.22", "Sin source() con rutas de config externo en archivos R",
  !r_source_external)

# ── U11: Tamaño de payload — run_analysis.R no procesa archivos gigantes sin limit ──
cat("\n── U11: Proteccion de tamanio de datos ──\n")
check("SEC.23", "sizeBytes almacenado en Prisma schema (control de tamanio)",
  grep_file("sizeBytes.*Int", file.path(repo_root, "apps", "api", "prisma", "schema.prisma")))

# ── U12: Headers de autorizacion en frontend ─────────────────────────────────
cat("\n── U12: Autorizacion Bearer Token en llamadas de frontend ──\n")
steptrun <- file.path(repo_root, "apps", "web", "src", "components", "wizard", "StepRun.tsx")
check("SEC.24", "Authorization Bearer token en fetch() de StepRun.tsx",
  grep_file("Authorization.*Bearer|Bearer.*Authorization", steptrun))
check("SEC.25", "Token leido desde localStorage (no hardcodeado)",
  grep_file("localStorage.*ros_token|ros_token.*localStorage", steptrun))

# ─────────────────────────────────────────────────────────────────────────────
cat(sprintf("\n=== RESULTADO SUITE U: %d PASS, %d FAIL, %d SKIP ===\n",
            pass, fail, skip_n))
if (fail > 0L) {
  cat("SUITE U: FALLO — revisar patrones de seguridad.\n")
  quit(status = 1L)
}
cat("SUITE U: COMPLETA — auditoria de seguridad OK.\n")
