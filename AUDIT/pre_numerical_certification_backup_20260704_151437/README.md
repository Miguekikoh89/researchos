# CanchariOS (ResearchOS Stats Engine)

Plataforma SaaS para análisis estadístico de tesis e investigación científica.
Los usuarios suben su base de datos, configuran variables, y obtienen resultados
completos en formato APA 7 listos para sustentar — con un asistente metodológico
opcional que recomienda el método estadístico adecuado según el tipo de variables
y el objetivo de investigación.

📄 Ver [`TECHNICAL_DOCUMENTATION.md`](./TECHNICAL_DOCUMENTATION.md) para detalle
del motor estadístico, fundamento académico y resultados de validación numérica.

---

## Stack

| Capa | Tecnología |
|------|-----------|
| Frontend | Next.js 14, Tailwind CSS, TypeScript |
| Backend | NestJS 10, Prisma 5, JWT |
| Base de datos | PostgreSQL 16 |
| Motor estadístico | R (22 scripts modulares) |
| Infraestructura | Docker Compose |

---

## Métodos estadísticos disponibles (17)

| Método | Uso típico |
|--------|------------|
| PLS-SEM | Modelos de ecuaciones estructurales con constructos latentes |
| Correlación (Pearson/Spearman/Kendall) | Asociación entre variables cuantitativas/ordinales |
| Regresión lineal (Enter/Stepwise/Forward/Backward) | Predicción de variable continua |
| Regresión ordinal | Predicción de variable ordinal (bajo/medio/alto) |
| Regresión jerárquica | Predictores en bloques teóricos sucesivos |
| Regresión logística (binaria y multinomial) | Predicción de variable categórica |
| Comparación de grupos (t/Welch/Mann-Whitney/Wilcoxon) | Diferencias entre 2 grupos |
| ANOVA (+ post-hoc) | Diferencias entre 3+ grupos |
| ANCOVA | ANOVA controlando una covariable continua |
| Análisis discriminante | Clasificación en grupos categóricos |
| Chi-cuadrado (Pearson/Yates/Fisher) | Asociación entre variables categóricas |
| Análisis clúster (K-means) | Agrupación de casos similares |
| Validación de instrumento (KMO, AFE, AFC, HTMT, V de Aiken) | Validez y confiabilidad de escalas |
| Alfa de Cronbach (+ Omega) | Confiabilidad de un constructo |
| Análisis Descriptivo (+ baremos y niveles) | Caracterización de una variable |

Cada método selecciona automáticamente entre alternativas paramétricas y no
paramétricas según pruebas de supuestos evaluadas internamente (normalidad,
homogeneidad de varianzas, homogeneidad de pendientes, etc.).

### Asistente metodológico

Para usuarios que no saben qué método aplicar, CanchariOS ofrece un asistente
guiado (`/research`) que recomienda el método adecuado a partir de:

- Escala de medición de las variables (Nominal/Ordinal/Intervalo/Razón)
- Presencia de covariables
- Propósito de la investigación (solo si la combinación de escalas es ambigua)

La lógica de recomendación está fundamentada en literatura citada (Flores-Ruiz
et al. 2017, Field 2013, Hair et al. 2019, Cohen et al. 2003) — ver
`apps/web/src/lib/methodRecommendation.ts`.

---

## Validación numérica

El motor estadístico fue validado contra R base puro usando el dataset público
`mtcars`, con **26 aserciones en 12 métodos, 26/26 correctas** tras corregir
4 errores reales detectados durante el proceso. Ver detalle completo en
[`TECHNICAL_DOCUMENTATION.md`](./TECHNICAL_DOCUMENTATION.md#5-validación-numérica).

```bash
# Ejecutar la suite de validacion (requiere R con los paquetes del motor)
Rscript tests/validate_mtcars.R
```

---

## Estructura del monorepo

```
researchos-stats-engine/
├── apps/
│   ├── web/                       # Next.js frontend
│   │   ├── src/app/                # Paginas (App Router)
│   │   │   ├── dashboard/          # Catalogo de 17 metodos
│   │   │   ├── start/              # Pantalla de decision (guiado vs directo)
│   │   │   ├── research/           # Asistente metodologico
│   │   │   └── analysis/new/       # Wizard de 6 pasos
│   │   ├── src/components/wizard/  # Steps del wizard
│   │   └── src/lib/methodRecommendation.ts  # Motor de recomendacion
│   ├── api/                       # NestJS backend
│   │   ├── src/analysis/           # Jobs + invocacion del motor R
│   │   └── prisma/                 # Schema + seed
│   └── stats-engine-r/            # Motor estadistico R
│       ├── R/                      # 22 archivos, uno o mas por metodo
│       └── run_analysis.R          # Orquestador principal
├── tests/
│   └── validate_mtcars.R          # Suite de validacion numerica
├── TECHNICAL_DOCUMENTATION.md     # Documentacion tecnica/cientifica
├── docker-compose.yml
└── README.md
```

---

## Instalación rápida (Docker)

```bash
git clone https://github.com/Miguekikoh89/researchos.git
cd researchos
cp .env.example .env
# Edita .env con tus valores seguros

docker-compose up -d
# Abrir http://localhost:3000
```

## Instalación manual (desarrollo)

### Requisitos
- Node.js 20+
- PostgreSQL 16
- R 4.3+ con paquetes: `readxl dplyr tidyr psych nortest officer flextable openxlsx jsonlite seminr MASS nnet emmeans cluster klaR lavaan GPArotation`

```bash
# Dependencias
cd apps/api && npm install
cd ../web && npm install
Rscript apps/stats-engine-r/install_packages.R

# Entorno
cp .env.example apps/api/.env
echo "NEXT_PUBLIC_API_URL=http://localhost:4000/api/v1" > apps/web/.env.local

# Base de datos
cd apps/api
npx prisma migrate dev --name init
npx prisma db seed

# Correr (2 terminales)
npm run start:dev      # API, puerto 4000
cd ../web && npm run dev  # Frontend, puerto 3000
```

---

## Variables de entorno

### API (`apps/api/.env`)

| Variable | Descripción |
|----------|-------------|
| `DATABASE_URL` | Conexión PostgreSQL |
| `JWT_SECRET` | Secreto JWT (mín. 32 chars) |
| `UPLOAD_DIR` | Carpeta de uploads |
| `OUTPUT_DIR` | Carpeta de resultados R |
| `R_BIN` | Ruta al ejecutable R (`Rscript`) |
| `R_TIMEOUT_MS` | Timeout del motor R (ms) |

### Frontend (`apps/web/.env.local`)

| Variable | Descripción |
|----------|-------------|
| `NEXT_PUBLIC_API_URL` | URL del API NestJS |

---

## Flujo de usuario

1. **Iniciar sesión** → pantalla `/start`: elegir ruta guiada o directa
2. **Ruta guiada** → asistente metodológico (`/research`): variables → objetivo → hipótesis → recomendación de método, con cita académica
3. **Ruta directa** → dashboard: elegir uno de los 17 métodos
4. **Subir Excel/CSV** → vista previa automática de columnas
5. **Configurar** → variables, ítems, dimensiones, parámetros específicos del método (con ejemplos guía por escala de medición)
6. **Analizar** → el motor R evalúa supuestos y ejecuta el método
7. **Resultados** → tablas APA 7 en pantalla, conectadas al objetivo de investigación
8. **Exportar Word** → documento completo, listo para tesis

---

## API endpoints principales

```
POST   /api/v1/auth/register
POST   /api/v1/auth/login

GET    /api/v1/projects
POST   /api/v1/projects

POST   /api/v1/projects/:id/datasets          (multipart)
GET    /api/v1/projects/:id/datasets/:did/preview

POST   /api/v1/projects/:id/analysis          → { jobId }
GET    /api/v1/projects/:id/analysis/:jobId/result
GET    /api/v1/projects/:id/analysis/:jobId/download/word
```

---

## Limitaciones conocidas

- Sin entorno de staging/CI-CD automatizado (ver `TECHNICAL_DOCUMENTATION.md`)
- Validación numérica cubre 12 de 17 métodos contra R base
- El motor R corre como proceso hijo, sin cola de trabajos distribuida
- Máximo 50 MB por archivo subido
- Regresión logística multinomial accesible solo desde el submenú de Regresión logística, no como card independiente

Ver lista completa y detallada en [`TECHNICAL_DOCUMENTATION.md`](./TECHNICAL_DOCUMENTATION.md#6-limitaciones-conocidas).

---

## Roadmap

- [ ] Suite de tests unitarios formal para el motor de recomendación (TypeScript)
- [ ] Validación numérica de los 5 métodos restantes (PLS-SEM, Instrumentos, Descriptivo, Jerárquica)
- [ ] Pipeline de CI/CD con ejecución automática de `tests/validate_mtcars.R`
- [ ] WebSockets para actualizaciones en tiempo real (actualmente polling)
- [ ] Cola de trabajos con Bull/Redis para análisis concurrentes
- [ ] Periodo de uso real con tesistas, documentado, antes de publicación científica
