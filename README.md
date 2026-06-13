# ResearchOS Stats Engine

Plataforma SaaS para análisis estadístico de tesis. Los estudiantes suben su base de datos, configuran variables e ítems, y obtienen resultados en formato APA 7 listos para sustentar.

---

## Stack

| Capa | Tecnología |
|------|-----------|
| Frontend | Next.js 14, Tailwind CSS, TypeScript |
| Backend | NestJS 10, Prisma 5, JWT |
| Base de datos | PostgreSQL 16 |
| Motor estadístico | R (scripts modulares) |
| Infraestructura | Docker Compose |

---

## Estructura del monorepo

```
researchos-stats-engine/
├── apps/
│   ├── web/                   # Next.js frontend
│   │   ├── src/app/           # Páginas (App Router)
│   │   └── src/components/    # Wizard steps
│   ├── api/                   # NestJS backend
│   │   ├── src/
│   │   │   ├── auth/          # JWT auth
│   │   │   ├── projects/      # CRUD proyectos
│   │   │   ├── datasets/      # Upload archivos
│   │   │   ├── analysis/      # Jobs + motor R
│   │   │   └── common/        # PrismaService
│   │   └── prisma/            # Schema + seed
│   └── stats-engine-r/        # Motor estadístico R
│       ├── R/
│       │   ├── helpers.R      # Formatos APA, interpretadores
│       │   ├── data_cleaning.R
│       │   ├── statistics.R
│       │   └── word_export.R
│       ├── run_analysis.R     # Orquestador principal
│       └── install_packages.R
├── docker-compose.yml
├── .env.example
└── README.md
```

---

## Instalación rápida (Docker)

```bash
# 1. Clonar y configurar
git clone <repo>
cd researchos-stats-engine
cp .env.example .env
# Edita .env con tus valores seguros

# 2. Levantar todo
docker-compose up -d

# 3. Listo → abrir http://localhost:3000
```

---

## Instalación manual (desarrollo)

### Requisitos
- Node.js 20+
- PostgreSQL 16
- R 4.3+ con paquetes: `readxl dplyr tidyr psych nortest officer flextable openxlsx jsonlite`

### 1. Instalar dependencias

```bash
# API
cd apps/api && npm install

# Frontend
cd apps/web && npm install

# Paquetes R
Rscript apps/stats-engine-r/install_packages.R
```

### 2. Configurar entorno

```bash
# API
cp .env.example apps/api/.env
# Edita apps/api/.env con tu DATABASE_URL, JWT_SECRET, etc.

# Frontend
echo "NEXT_PUBLIC_API_URL=http://localhost:4000/api/v1" > apps/web/.env.local
```

### 3. Base de datos

```bash
cd apps/api
npx prisma migrate dev --name init
npx prisma db seed       # crea usuarios demo
```

### 4. Correr servicios

```bash
# Terminal 1 — API (puerto 4000)
cd apps/api && npm run start:dev

# Terminal 2 — Frontend (puerto 3000)
cd apps/web && npm run dev
```

---

## Variables de entorno

### API (`apps/api/.env`)

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `DATABASE_URL` | Conexión PostgreSQL | `postgresql://user:pass@localhost:5432/researchos` |
| `JWT_SECRET` | Secreto JWT (mín. 32 chars) | `un-secreto-muy-largo-y-aleatorio` |
| `UPLOAD_DIR` | Carpeta de uploads | `/tmp/researchos/uploads` |
| `OUTPUT_DIR` | Carpeta de resultados R | `/tmp/researchos/outputs` |
| `R_ENGINE_PATH` | Ruta al script R principal | `./apps/stats-engine-r/run_analysis.R` |
| `R_BIN` | Ruta al ejecutable R | `Rscript` |
| `R_TIMEOUT_MS` | Timeout del motor R (ms) | `120000` |

### Frontend (`apps/web/.env.local`)

| Variable | Descripción |
|----------|-------------|
| `NEXT_PUBLIC_API_URL` | URL del API NestJS |

---

## Flujo de usuario

### Estudiante
1. **Registrarse** → rol STUDENT
2. **Crear proyecto** → Dashboard → "Nuevo análisis"
3. **Subir Excel/CSV** → vista previa automática
4. **Configurar** → seleccionar ítems de Variable A y B
5. **Lanzar análisis** → NestJS corre el motor R
6. **Ver resultados** → método, confiabilidad, normalidad, correlación
7. **Descargar Word APA** → listo para tesis

### Asesor (modo avanzado)
- Todo lo anterior +
- Configurar dimensiones con nombres personalizados
- Elegir método (auto/Pearson/Spearman)
- Seleccionar tipo de baremo
- Elegir tipos de correlación (VxV, VxDim, DimxDim)

---

## API endpoints

```
POST   /api/v1/auth/register
POST   /api/v1/auth/login
GET    /api/v1/auth/me

GET    /api/v1/projects
POST   /api/v1/projects
GET    /api/v1/projects/dashboard
GET    /api/v1/projects/:id

POST   /api/v1/projects/:id/datasets          (multipart)
GET    /api/v1/projects/:id/datasets
GET    /api/v1/projects/:id/datasets/:did/preview

POST   /api/v1/projects/:id/analysis          → { jobId }
GET    /api/v1/projects/:id/analysis/:jobId
GET    /api/v1/projects/:id/analysis/:jobId/result
GET    /api/v1/projects/:id/analysis/:jobId/download/word
```

---

## Motor R — Contrato JSON

### Entrada (config.json)

```json
{
  "file_path": "/data/uploads/abc123.xlsx",
  "output_dir": "/data/outputs",
  "study_name": "Correlación estrés-rendimiento",
  "participants": 120,
  "objective": "Determinar la correlación entre...",
  "scale_min": 1,
  "scale_max": 5,
  "items_a": ["P1", "P2", "P3", "P4", "P5"],
  "items_b": ["P6", "P7", "P8", "P9", "P10"],
  "dims_a": [
    { "name": "Dimensión 1", "items": ["P1", "P2"] },
    { "name": "Dimensión 2", "items": ["P3", "P4", "P5"] }
  ],
  "dims_b": [],
  "baremo_method": "percentil",
  "force_method": "auto",
  "analysis_types": ["vv", "vdB"],
  "alpha_level": 0.05
}
```

### Salida (stdout JSON)

```json
{
  "status": "ok",
  "method": "Spearman",
  "diagnostic": { "n_rows": 120, "n_cols": 10, "missing_pct": 0.0 },
  "descriptives": [...],
  "reliability": { "variable_a": { "alpha": 0.87, "ci_lower": 0.83, "ci_upper": 0.91 } },
  "normality": [...],
  "correlations": { "main": { "r": 0.54, "p": 0.001, "stars": "***" } },
  "baremo_a": { "method": "percentil", "table": [...] },
  "interpretations": { "main": "Existe correlación positiva moderada..." },
  "word_path": "/data/outputs/job_abc123.docx",
  "warnings": [],
  "errors": []
}
```

---

## Usuarios demo (seed)

| Email | Contraseña | Rol |
|-------|-----------|-----|
| `estudiante@demo.com` | `password123` | STUDENT |
| `asesor@demo.com` | `password123` | ADVISOR |

---

## Limitaciones del MVP

- El motor R corre como proceso hijo (sin cola de trabajos distribuida)
- No hay WebSockets; el frontend hace polling cada 2 segundos
- Máximo 50 MB por archivo
- Sin soporte para correlaciones parciales o análisis multivariado
- El Word exportado usa formato APA 7 básico (sin paginación avanzada)
- Sin soporte multiidioma (solo español)

---

## Roadmap

- [ ] WebSockets para actualizaciones en tiempo real
- [ ] Cola de trabajos con Bull/Redis para análisis concurrentes
- [ ] Exportación a Excel con tablas de resultados
- [ ] Módulo de IA para explicación de resultados y defensa de tesis
- [ ] Soporte para más pruebas: regresión, ANOVA, t-test
- [ ] Panel de administración para gestión de usuarios
- [ ] Modo colaborativo (asesor revisa análisis del estudiante)
- [ ] Historial de versiones por análisis
