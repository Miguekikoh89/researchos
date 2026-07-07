# 08 — REPORTE FINAL DE APTITUD
## ResearchOS / CanchariOS Stats Engine — Auditoría 2026-06-28
**Estado del reporte:** IN PROGRESS — Inspección completada, correcciones pendientes

---

## 1. RESUMEN EJECUTIVO

El sistema ResearchOS / CanchariOS Stats Engine es una plataforma web para análisis estadísticos en investigación social y psicológica. Integra un backend NestJS, un motor estadístico R, y un frontend Next.js.

**Alcance auditado:** 18 métodos estadísticos, 21 módulos R, arquitectura NestJS-R, schema de base de datos, Dockerfile, suite de validación numérica, motor de recomendación metodológica.

**Veredicto preliminar:** El sistema demuestra cobertura estadística amplia y una arquitectura técnica coherente. Se identificaron **23 hallazgos** (2 P0, 5 P1, 11 P2, 5 P3). Los bugs más críticos son localizados y corregibles sin refactorización mayor. **El sistema NO debería operar en producción sin resolver al menos los 7 hallazgos P0/P1.**

---

## 2. COBERTURA DE MÉTODOS — ESTADO POR CATEGORÍA

| Categoría | Métodos | Implementado | Correcto | Issues |
|-----------|---------|-------------|----------|--------|
| Comparación | t-test, Mann-Whitney, Wilcoxon, ANOVA, Kruskal-Wallis | ✅ | ✅ | Bug dispatch ANOVA (F-002) |
| Correlación | Pearson, Spearman, Matriz | ✅ | ⚠️ | Bug interpret_r (F-003, F-004) |
| Regresión lineal | Simple, Múltiple, Enter, Stepwise | ✅ | ✅ | Bug menor significancia (F-regression) |
| Regresión logística | Binaria, Multinomial | ✅ | ⚠️ | Binarización silenciosa (F-007), sin IC OR multinomial (F-008) |
| Regresión ordinal | Ordinal (polr) | ✅ | ⚠️ | Test líneas paralelas incompleto (F-013), tricotomización (F-017) |
| Regresión jerárquica | Bloques | ✅ | ⚠️ | Agregación por bloques limita precisión (F-hierarchical) |
| ANCOVA | ANCOVA + emmeans | ✅ | ⚠️ | Sin η² parcial (F-010) |
| Discriminante | LDA + CV | ✅ | ⚠️ | Sin Box's M, sin matriz estructura (F-011, F-012) |
| Cluster | K-means | ✅ | ⚠️ | Solo K-means, etiquetas heurísticas (F-018) |
| Chi-cuadrado | Pearson, Fisher, V Cramér | ✅ | ⚠️ | Sin residuos ajustados (F-009), datos continuos (F-005) |
| Psicometría | AFE, AFC, HTMT, Cronbach, Omega | ✅ | ⚠️ | Bug omega en statistics.R (F-001), imputación (F-006) |
| PLS-SEM | 17 sub-análisis | ✅ | ⚠️ | Jitter datos (F-014), df hardcoded (F-015) |
| Descriptivo | Descriptivos, Baremos, Frecuencias | ✅ | ⚠️ | Sin ítems invertidos (F-016) |

---

## 3. ARQUITECTURA TÉCNICA — EVALUACIÓN

| Componente | Estado | Observación |
|------------|--------|-------------|
| Puente Node-R (spawn) | ✅ Funcional | Timeout razonable (120s/600s) |
| Comunicación vía JSON | ✅ Correcto | Config.json → R → stdout JSON → DB |
| Base de datos (Prisma) | ✅ Coherente | Schema bien diseñado por método |
| Autenticación JWT | ✅ Implementado | Todos los endpoints protegidos |
| Docker multi-stage | ✅ Correcto | node:20-slim + rocker/r-ver:4.3.2 |
| Exportación Word (officer) | ✅ Funcional | 1285 líneas, cobertura completa de métodos |
| Motor de recomendación | ✅ Sólido | Lógica de decisión bien estructurada con fuentes citadas |
| Storage persistente | ⚠️ Riesgo | Archivos Word en filesystem efímero (Railway) |
| Directorio R hardcoded | ⚠️ Limitación | `/app/stats-engine-r/R` fijo (F-019) |

---

## 4. RIESGOS CRÍTICOS QUE BLOQUEAN PRODUCCIÓN

### 4.1 Resultados estadísticos incorrectos (P0/P1)

| Hallazgo | Método afectado | Impacto en usuario |
|----------|----------------|--------------------|
| F-003: interpret_r() bug | Correlación (r entre 0.80-0.89) | "muy alta" en lugar de "alta" — error en reporte |
| F-004: Funciones duplicadas | Correlación, confiabilidad | interpret_r() incorrecta activa en producción |
| F-005: Chi² con datos continuos | Chi-cuadrado | Resultados sobre datos artificialmente categorizados |
| F-006: Imputación desalineada | Instrumentos/AFE/AFC | Cargas factoriales potencialmente incorrectas |
| F-007: Binarización silenciosa | Logística binaria | OR calculados sobre variable modificada sin advertencia |
| F-001: Omega (requiere verificación) | Instrumentos/Cronbach | Omega puede ser incorrecto si bug confirmado |

### 4.2 Código muerto con riesgo de mantenimiento (P0)

| Hallazgo | Archivo | Riesgo |
|----------|---------|--------|
| F-002: ANOVA duplicado | run_analysis.R | Divergencia si se edita bloque incorrecto |

---

## 5. PLAN DE CORRECCIÓN — ORDEN DE PRIORIDAD

### Sprint 1 (inmediato — no requieren validación estadística externa)
1. **F-002:** Eliminar bloque ANOVA duplicado (5 minutos, 0 riesgo)
2. **F-004:** Eliminar funciones duplicadas de statistics.R (30 minutos, riesgo bajo)
3. **F-003:** Verificar interpret_r() queda correcto tras F-004 (automático si F-004 correcto)

### Sprint 2 (esta semana — requieren pruebas)
4. **F-007:** Agregar warning en binarización logística (15 minutos)
5. **F-006:** Corregir imputación vectorizada instruments.R (20 minutos)
6. **F-008:** Agregar IC 95% OR en multinomial (10 minutos)
7. **F-009:** Agregar residuos ajustados en chi-cuadrado (20 minutos)
8. **F-010:** Agregar η² parcial en ANCOVA (15 minutos)

### Sprint 3 (próxima semana — requieren decisión metodológica)
9. **F-001:** Verificar compute_omega() y corregir si hay bug
10. **F-005:** Definir estrategia para chi-cuadrado con datos continuos
11. **F-013:** Test de Brant completo (requiere paquete `brant`)
12. **F-015:** Corregir df en p-values indirectos PLS-SEM

### Sprint 4 (infraestructura)
13. **F-020:** Almacenamiento persistente para archivos Word
14. **F-019:** Variable de entorno para directorio R

---

## 6. PREGUNTAS SIN RESOLVER (BLOQUEOS REALES)

Las siguientes preguntas requieren decisión del equipo antes de implementar correcciones:

### P1: ¿Cuál es la escala correcta de interpret_r()?
- **helpers.R:** ≥0.70 = "muy alta", ≥0.50 = "alta", ≥0.30 = "moderada"
- **statistics.R:** ≥0.90 = "muy alta", ≥0.80 = "alta" (referencia a Cohen 1988)
- **Cohen (1988) original:** r=0.10 pequeño, r=0.30 mediano, r=0.50 grande (no menciona "muy alta")
- **Decisión requerida:** ¿Qué escala usar? ¿Cohen 1988? ¿Guía APA? ¿Criterio propio de la aplicación?

### P2: ¿Chi-cuadrado con datos continuos es intencional?
El flujo actual tricotomiza datos continuos antes del chi-cuadrado. ¿Es este el comportamiento deseado o es un bug?

### P3: ¿La tricotomización en regresión ordinal es un feature o un bug?
`run_ordinal_regression()` convierte la VD continua a ordinal automáticamente. ¿Debe el usuario poder elegir no tricotomizar si su variable ya es ordinal en el Excel?

### P4: ¿PLS-SEM debe funcionar con constructos de 1 ítem?
La duplicación de ítems únicos es una heurística. ¿Tiene soporte en la literatura de seminr para este caso?

### P5: ¿Los archivos Word deben persistir entre reinicios?
Actualmente se pierden. ¿Es aceptable re-generarlos bajo demanda o deben almacenarse permanentemente?

---

## 7. CRITERIOS DE APTITUD FINAL

El sistema estará listo para producción cuando:

| Criterio | Estado | Responsable |
|----------|--------|-------------|
| F-001 verificado y resuelto si hay bug | ⏳ | Auditoría |
| F-002 eliminado (código duplicado) | ⏳ | Auditoría |
| F-003/F-004 interpret_r() correcto | ⏳ | Auditoría |
| F-005 chi-cuadrado con datos continuos resuelto | ⏳ | Decisión + Auditoría |
| F-006 imputación corregida | ⏳ | Auditoría |
| F-007 warning de binarización | ⏳ | Auditoría |
| validate_mtcars.R: 26/26 pruebas pasan | ⏳ | Auditoría |
| Al menos 30/35 pruebas propuestas pasan | ⏳ | Auditoría |
| Preguntas P1-P5 respondidas por el equipo | ⏳ | Equipo de producto |

---

## 8. APTITUD POR MÉTODO — VEREDICTO ACTUAL

| Método | Aptitud actual | Aptitud post-corrección |
|--------|----------------|------------------------|
| Correlación | ⚠️ BUG interpret_r | ✅ tras F-003/F-004 |
| Comparación grupos | ✅ | ✅ |
| ANOVA | ✅ (bug F-002 es código muerto) | ✅ |
| Regresión lineal | ✅ | ✅ |
| Regresión logística binaria | ⚠️ binarización silenciosa | ✅ tras F-007 |
| Regresión logística multinomial | ⚠️ sin IC OR | ✅ tras F-008 |
| Regresión ordinal | ⚠️ tricotomización, Brant | ⚠️ (requiere decisión) |
| Regresión jerárquica | ⚠️ agregación bloques | ⚠️ (limitación de diseño) |
| ANCOVA | ⚠️ sin η² parcial | ✅ tras F-010 |
| Discriminante | ⚠️ sin Box's M, estructura | ⚠️ (P2, aceptable) |
| Cluster | ⚠️ solo K-means | ⚠️ (P2, aceptable) |
| Chi-cuadrado | ⚠️ datos continuos, sin residuos | ⚠️ (requiere decisión) |
| Instrumentos AFE/AFC | ⚠️ imputación, omega | ✅ tras F-006+F-001 |
| Cronbach standalone | ✅ (usa psych::omega, no bug) | ✅ |
| Baremos | ✅ | ✅ |
| Frecuencias | ✅ | ✅ |
| Descriptivos | ✅ | ✅ |
| PLS-SEM | ⚠️ jitter, df hardcoded | ⚠️ (P2, funcional) |

---

*Reporte en estado IN PROGRESS — Se actualizará tras implementación de correcciones.*  
*Completado inicialmente: 2026-06-28*
