// Motor de recomendacion metodologica centralizado — version basada en tabla de decision
// Arquitectura: el Asistente selecciona la FAMILIA del metodo (esta logica);
// el motor estadistico interno evalua supuestos y decide la prueba especifica
// (Pearson/Spearman, t-Student/Mann-Whitney, ANOVA/Kruskal-Wallis, Chi2/Fisher).
//
// Tabla de decision basada en: escala de la variable resultado + escala de la
// variable explicativa + presencia/tipo de covariable + proposito minimo
// (solo para desambiguar Continua+Continua y Continua+Nominal).
//
// Fuentes: Flores-Ruiz, Miranda-Novales y Villasis-Keever (2017), Revista Alergia
// Mexico 64(3); Field (2013) Discovering Statistics Using IBM SPSS;
// Hair et al. (2019) Multivariate Data Analysis; IBM SPSS Statistics Docs.

export type Confidence = 'alta' | 'media' | 'baja';

export type ScaleResultado = 'continua' | 'ordinal' | 'nominal_2' | 'nominal_3mas';
export type ScaleExplicativa = 'continua' | 'ordinal' | 'nominal_2' | 'nominal_3mas';
export type CovariateType = 'no' | 'continua' | 'categorica';
export type Purpose = 'relacionar' | 'predecir' | 'comparar' | 'clasificar' | 'asociar';

export interface MinimalInputs {
  resultado: ScaleResultado;
  explicativa: ScaleExplicativa;
  covariate: CovariateType;
  purpose?: Purpose; // solo requerido cuando hay ambiguedad (continua+continua, continua+nominal)
  hasDims?: boolean; // si las variables tienen multiples items/indicadores (afecta PLS-SEM)
}

export interface MethodRecommendation {
  recommendedMethod: string;
  methodSlug: string;
  confidence: Confidence;
  justification: string;
  citation?: string;
  preliminary?: string[];
  assumptions?: string[];
  alternatives?: { method: string; reason: string }[];
  warnings?: string[];
  needsPurpose?: boolean; // true si esta combinacion requiere preguntar el proposito
}

export const methodRoutes: Record<string, string> = {
  correlacional: '/analysis/new?method=correlacional',
  regresion: '/analysis/new?method=regresion',
  regresion_ordinal: '/analysis/new?method=regresion_ordinal',
  regresion_jerarquica: '/analysis/new?method=regresion_jerarquica',
  logistica: '/analysis/new?method=logistica',
  comparacion: '/analysis/new?method=comparacion',
  anova: '/analysis/new?method=anova',
  ancova: '/analysis/new?method=ancova',
  discriminante: '/analysis/new?method=discriminante',
  chi_cuadrado: '/analysis/new?method=chi_cuadrado',
  cluster: '/analysis/new?method=cluster',
  instrumentos: '/analysis/new?method=instrumentos',
  cronbach: '/analysis/new?method=cronbach',
  descriptivo: '/analysis/new?method=descriptivo',
  structural_model: '/analysis/new?method=structural_model',
};

const METHOD_LABELS: Record<string, string> = {
  correlacional: 'Correlación', regresion: 'Regresión lineal',
  regresion_ordinal: 'Regresión ordinal', regresion_jerarquica: 'Regresión jerárquica',
  logistica: 'Regresión logística', comparacion: 'Comparación de grupos',
  anova: 'ANOVA', ancova: 'ANCOVA', discriminante: 'Análisis discriminante',
  chi_cuadrado: 'Chi-cuadrado', cluster: 'Análisis clúster',
  instrumentos: 'Validación de instrumento', cronbach: 'Alfa de Cronbach',
  descriptivo: 'Análisis descriptivo', structural_model: 'PLS-SEM',
};

const CITE_FLORES = 'Flores-Ruiz, Miranda-Novales y Villasís-Keever (2017): la escala de medición de la variable resultado es el criterio principal para seleccionar la prueba estadística.';
const CITE_HAIR = 'Hair, Black, Babin y Anderson (2019): el número y naturaleza de las variables latentes/manifiestas determina si corresponde un modelo de regresión clásico o un modelo de ecuaciones estructurales.';
const CITE_FIELD = 'Field (2013), Discovering Statistics Using IBM SPSS: ANCOVA evalúa si un factor categórico de 2 o más niveles influye en la variable resultado una vez eliminada la influencia de una covariable cuantitativa continua.';
const CITE_CHI2 = 'Guía de bioestadística aplicada: la prueba Chi-cuadrado evalúa la asociación entre dos variables categóricas mediante tablas de contingencia; no sustituye a la comparación de medias cuando una variable es cuantitativa.';
const CITE_DISCRIM = 'IBM SPSS Statistics (Documentación de Regresión Logística): el análisis discriminante exige normalidad multivariada e igualdad de matrices de covarianza; la regresión logística multinomial es la alternativa moderna cuando esos supuestos no se cumplen.';

function label(slug: string) { return METHOD_LABELS[slug] || slug; }

/**
 * Determina si la combinacion resultado+explicativa requiere preguntar el proposito.
 * Segun la tabla acordada, solo 2 casos son ambiguos sin ayuda del proposito:
 * - Continua + Continua (puede ser Correlacion o Regresion lineal)
 * - Continua + Nominal (puede ser Comparacion/ANOVA o Regresion con dummy)
 */
export function needsPurposeQuestion(resultado: ScaleResultado, explicativa: ScaleExplicativa): boolean {
  if (resultado === 'continua' && explicativa === 'continua') return true;
  if (resultado === 'continua' && (explicativa === 'nominal_2' || explicativa === 'nominal_3mas')) return true;
  if (resultado === 'continua' && explicativa === 'ordinal') return true;
  // Resultado Ordinal: relacionar -> Correlacion (Spearman); predecir -> Regresion ordinal
  if (resultado === 'ordinal') return true;
  // Nominal 3+ x Nominal: asociar -> Chi-cuadrado; predecir/clasificar -> Logistica multinomial
  // (Nominal_2 x Nominal siempre usa Logistica binaria, sin ambiguedad real)
  if (resultado === 'nominal_3mas' && (explicativa === 'nominal_2' || explicativa === 'nominal_3mas')) return true;
  return false;
}

export function recommendMethod(inputs: MinimalInputs): MethodRecommendation {
  const { resultado, explicativa, covariate, purpose, hasDims } = inputs;

  // ── PLS-SEM: si hay constructos con multiples indicadores y el proposito es relacionar/predecir estructuras ──
  if (hasDims && (purpose === 'relacionar' || purpose === 'predecir')) {
    return {
      recommendedMethod: label('structural_model'), methodSlug: 'structural_model', confidence: 'media',
      justification: 'Detectamos que tus variables tienen múltiples ítems/indicadores (constructos). Cuando se busca modelar relaciones entre variables latentes, el modelo de ecuaciones estructurales (PLS-SEM) es más adecuado que una regresión o correlación simple sobre puntajes promedio.',
      citation: CITE_HAIR,
      preliminary: ['Confiabilidad (Alfa, Omega) de cada constructo', 'Validez convergente (AVE) y discriminante (HTMT)'],
      assumptions: ['Tamaño de muestra adecuado para el número de indicadores'],
      alternatives: [{ method: purpose === 'relacionar' ? label('correlacional') : label('regresion'), reason: 'Si prefieres trabajar con el puntaje promedio de cada constructo en lugar del modelo completo de indicadores.' }],
    };
  }

  // ── Resultado: Nominal 2 categorías → Logistica binaria (mas usada), Discriminante valido tambien ──
  if (resultado === 'nominal_2') {
    return {
      recommendedMethod: label('logistica'), methodSlug: 'logistica', confidence: 'alta',
      justification: 'Tu variable resultado es dicotómica (2 categorías). La regresión logística binaria estima la probabilidad de pertenecer a una categoría en función de tus predictores, reportando Odds Ratio (OR). No exige normalidad multivariada de los predictores, por lo que suele preferirse sobre el discriminante en la práctica.',
      citation: CITE_FLORES,
      preliminary: ['Estadísticos descriptivos de la variable resultado por categoría'],
      assumptions: ['Observaciones independientes', 'Ausencia de multicolinealidad severa entre predictores', 'Linealidad entre predictores continuos y el logit', 'Ausencia de separación completa y de casos muy influyentes', 'Tamaño muestral suficiente por parámetro (la regla de "10 casos por predictor" es orientativa, no exacta)'],
      alternatives: [{ method: label('discriminante'), reason: 'También es válido con 2 grupos si tus predictores cumplen normalidad multivariada e igualdad de matrices de covarianza entre grupos.' }],
    };
  }

  // ── Resultado: Nominal 3+ categorías ──
  if (resultado === 'nominal_3mas') {
    if (explicativa === 'nominal_2' || explicativa === 'nominal_3mas') {
      // Nominal x Nominal: distinguir asociar (Chi2) de predecir (Logistica multinomial)
      if (purpose === 'predecir' || purpose === 'clasificar') {
        return {
          recommendedMethod: label('logistica') + ' (multinomial)', methodSlug: 'logistica', confidence: 'alta',
          justification: 'Tu variable resultado es categórica con 3 o más grupos y deseas predecir su probabilidad a partir de otra variable categórica. La regresión logística multinomial está diseñada precisamente para resultados nominales con varias categorías.',
          citation: CITE_FLORES,
          assumptions: ['Observaciones independientes', 'Ausencia de multicolinealidad severa', 'Tamaño muestral suficiente por categoría y parámetro'],
          alternatives: [{ method: label('discriminante'), reason: 'Válido con condiciones más estrictas (normalidad multivariada e igualdad de matrices de covarianza).' }],
        };
      }
      return {
        recommendedMethod: label('chi_cuadrado'), methodSlug: 'chi_cuadrado', confidence: 'alta',
        justification: 'Ambas variables son categóricas (Nominales) y tu propósito es analizar asociación, no predicción. La prueba Chi-cuadrado de Pearson evalúa la asociación entre sus categorías mediante tabla de contingencia.',
        citation: CITE_CHI2,
        assumptions: ['Observaciones independientes', 'Categorías mutuamente excluyentes', 'Frecuencias esperadas suficientemente grandes (la regla "todas ≥5" es conservadora; con frecuencias pequeñas en tablas 2x2, el motor usa la prueba exacta de Fisher)'],
        alternatives: [{ method: label('logistica') + ' multinomial', reason: 'Si en realidad buscas predecir la categoría de tu variable resultado a partir de la otra, no solo analizar asociación.' }],
      };
    }
    // Resultado nominal 3+, explicativa cuantitativa/ordinal: Multinomial es la recomendacion principal (ya implementada)
    return {
      recommendedMethod: label('logistica') + ' (multinomial)', methodSlug: 'logistica', confidence: 'alta',
      justification: 'Tu variable resultado es categórica con 3 o más grupos sin orden. La regresión logística multinomial está diseñada para este caso y exige menos supuestos distribucionales que el análisis discriminante.',
      citation: CITE_FLORES,
      assumptions: ['Observaciones independientes', 'Ausencia de multicolinealidad severa', 'Tamaño muestral suficiente por categoría y parámetro'],
      alternatives: [{ method: label('discriminante'), reason: 'Alternativa válida si tus predictores cumplen normalidad multivariada e igualdad de matrices de covarianza entre grupos; exige supuestos más estrictos que la logística multinomial.' }],
    };
  }

  // ── Resultado: Ordinal ──
  if (resultado === 'ordinal') {
    const explicativaIsNominal = explicativa === 'nominal_2' || explicativa === 'nominal_3mas';

    // Caso especial: Ordinal x Nominal (sin orden). La correlacion NO es automatica aqui,
    // porque la variable nominal no tiene un orden que correlacionar (Hallazgo de auditoria).
    if (explicativaIsNominal) {
      if (purpose === 'predecir' || purpose === 'clasificar') {
        return {
          recommendedMethod: label('regresion_ordinal'), methodSlug: 'regresion_ordinal', confidence: 'alta',
          justification: 'Tu variable resultado es ordinal y tu predictor es categórico (Nominal). La regresión ordinal admite predictores categóricos correctamente codificados (como factor), por lo que sigue siendo el método adecuado para predecir.',
          citation: CITE_FLORES,
          assumptions: ['Independencia de las observaciones', 'Supuesto de probabilidades proporcionales (líneas paralelas) entre categorías'],
        };
      }
      // relacionar/comparar/asociar (o sin propósito): NO es correlacion (la nominal no tiene orden).
      const nGroups = explicativa === 'nominal_3mas' ? 3 : 2;
      return {
        recommendedMethod: label(nGroups >= 3 ? 'anova' : 'comparacion'), methodSlug: nGroups >= 3 ? 'anova' : 'comparacion', confidence: 'media',
        justification: 'Tu variable resultado es ordinal, pero tu variable explicativa es categórica (Nominal) sin orden. Una correlación no es apropiada aquí porque la variable nominal no posee un orden que correlacionar; lo adecuado es comparar los niveles de tu variable ordinal entre los grupos de la variable nominal (tratándola como rangos o con pruebas no paramétricas como Kruskal-Wallis).',
        citation: CITE_FLORES,
        warnings: ['CanchariOS trata tu variable ordinal como cuantitativa aproximada para esta comparación; si tiene pocas categorías, los resultados no paramétricos (Mann-Whitney/Kruskal-Wallis) serán los más confiables.'],
        alternatives: [{ method: label('regresion_ordinal'), reason: 'Si tu propósito real es predecir la categoría ordinal a partir del grupo nominal, no solo compararlas.' }],
      };
    }

    // Ordinal x (Continua u Ordinal): aqui si aplica la disyuntiva Correlacion/Regresion ordinal
    if (purpose === 'relacionar') {
      return {
        recommendedMethod: label('correlacional'), methodSlug: 'correlacional', confidence: 'alta',
        justification: 'Tu variable resultado es ordinal y la explicativa es cuantitativa u ordinal (ambas pueden ordenarse). La correlación de Spearman es adecuada para analizar la asociación, sin asumir distancias exactas entre categorías.',
        citation: CITE_FLORES,
        preliminary: ['Confiabilidad de cada escala'],
        assumptions: ['Independencia de las observaciones', 'Relación monotónica entre las variables', 'Ausencia de valores atípicos influyentes'],
      };
    }
    return {
      recommendedMethod: label('regresion_ordinal'), methodSlug: 'regresion_ordinal', confidence: 'alta',
      justification: 'Tu variable resultado presenta categorías ordenadas (ej. bajo/medio/alto) y tu propósito es predecir. La regresión ordinal modela la probabilidad de pertenecer a cada categoría respetando ese orden.',
      citation: CITE_FLORES,
      assumptions: ['Independencia de las observaciones', 'Ausencia de multicolinealidad severa', 'Supuesto de probabilidades proporcionales (líneas paralelas) entre categorías'],
      alternatives: [{ method: label('correlacional'), reason: 'Si tu propósito es analizar asociación entre las variables, no predicción.' }],
    };
  }

  // ── Resultado: Continua ──────────────────────────────────────────────────────
  // Continua + Continua → depende del proposito (Relacionar=Correlacion, Predecir=Regresion)
  if (explicativa === 'continua') {
    if (purpose === 'relacionar') {
      return {
        recommendedMethod: label('correlacional'), methodSlug: 'correlacional', confidence: 'alta',
        justification: 'Ambas variables son cuantitativas y tu propósito es analizar asociación, sin establecer dirección de causalidad explícita. La correlación estima la fuerza y dirección de la relación; el motor evalúa normalidad, linealidad y outliers para elegir entre Pearson y Spearman, no solo la normalidad.',
        citation: CITE_FLORES,
        preliminary: ['Confiabilidad de cada escala', 'Prueba de normalidad (Shapiro-Wilk, n < 2000) como uno de los criterios para decidir entre Pearson y Spearman'],
        assumptions: ['Independencia de las observaciones', 'Relación lineal entre las variables (para Pearson) o monotónica (para Spearman)', 'Ausencia de valores atípicos influyentes'],
      };
    }
    // purpose === 'predecir' o no especificado: Regresion lineal multiple es la recomendacion por defecto,
    // incluso con covariable. La jerarquica NO se activa automaticamente por tener una covariable
    // (ese es un error metodologico): solo corresponde si el usuario desea ingresar predictores en
    // bloques teoricos sucesivos para evaluar el cambio en R2 (Cohen, Cohen, West y Aiken, 2003).
    if (covariate !== 'no') {
      return {
        recommendedMethod: label('regresion'), methodSlug: 'regresion', confidence: 'media',
        justification: 'Registraste una covariable adicional junto a tu predictor principal. Si solo deseas controlar su efecto, una regresión lineal múltiple (con ambos predictores ingresados simultáneamente) es suficiente.',
        citation: CITE_FLORES,
        assumptions: ['Linealidad', 'Normalidad de residuos', 'Homocedasticidad', 'Independencia de errores', 'No multicolinealidad (VIF)'],
        alternatives: [{ method: label('regresion_jerarquica'), reason: 'Úsala solo si quieres ingresar tus predictores en bloques teóricos sucesivos (ej. variables de control primero, luego tu predictor principal) para evaluar el cambio en R² (ΔR²) al añadir cada bloque. No es automática por tener una covariable.' }],
      };
    }
    return {
      recommendedMethod: label('regresion'), methodSlug: 'regresion', confidence: 'alta',
      justification: 'Tu propósito es predecir una variable cuantitativa continua a partir de otra. La regresión lineal estima el peso del predictor y la varianza explicada (R²).',
      citation: CITE_FLORES,
      preliminary: ['Correlación entre predictor y variable resultado', 'Estadísticos descriptivos'],
      assumptions: ['Linealidad', 'Normalidad de residuos', 'Homocedasticidad', 'Independencia de errores'],
    };
  }

  // Continua + Ordinal → tratamos como regresion (ordinal como predictor numerico aproximado) o correlacion si relacionar
  if (explicativa === 'ordinal') {
    if (purpose === 'relacionar') {
      return {
        recommendedMethod: label('correlacional'), methodSlug: 'correlacional', confidence: 'media',
        justification: 'Tu variable resultado es continua y la explicativa es ordinal. La correlación de Spearman es adecuada para esta combinación, ya que no exige que ambas variables sean de intervalo/razón.',
        citation: CITE_FLORES,
        assumptions: ['No requiere normalidad multivariada estricta'],
      };
    }
    return {
      recommendedMethod: label('regresion'), methodSlug: 'regresion', confidence: 'media',
      justification: 'Tu variable resultado es continua y deseas predecirla a partir de una variable ordinal. Puedes usar la variable ordinal como predictor numérico en una regresión lineal, interpretando con cautela la escala.',
      citation: CITE_FLORES,
      assumptions: ['Linealidad', 'Normalidad de residuos', 'Homocedasticidad'],
      warnings: ['Tratar una variable ordinal como numérica en regresión lineal es una aproximación común pero no exacta; si tu variable ordinal tiene pocas categorías, considera tratarla como factor categórico (ANOVA) en su lugar.'],
    };
  }

  // Continua + Nominal (2 o 3+ grupos) → depende del proposito y la covariable
  if (explicativa === 'nominal_2' || explicativa === 'nominal_3mas') {
    const nGroups = explicativa === 'nominal_2' ? 2 : 3;
    const wantsCompare = purpose === 'comparar' || !purpose;

    if (wantsCompare) {
      if (covariate === 'continua') {
        return {
          recommendedMethod: label('ancova'), methodSlug: 'ancova', confidence: 'alta',
          justification: `Tu variable explicativa agrupa en ${nGroups === 2 ? '2 grupos' : '3 o más grupos'} y registraste una covariable continua a controlar. El ANCOVA compara las medias ajustadas entre grupos, eliminando estadísticamente el efecto lineal de esa covariable.`,
          citation: CITE_FIELD,
          preliminary: ['Estadísticos descriptivos por grupo', 'Correlación entre la covariable y la variable resultado'],
          assumptions: ['Homogeneidad de pendientes de regresión', 'Normalidad de residuos', 'Homogeneidad de varianzas'],
        };
      }
      if (covariate === 'categorica') {
        return {
          recommendedMethod: label(nGroups >= 3 ? 'anova' : 'comparacion'), methodSlug: nGroups >= 3 ? 'anova' : 'comparacion', confidence: 'media',
          justification: 'Registraste una covariable, pero ANCOVA requiere que esa covariable sea continua (cuantitativa). Como la tuya es categórica, te recomendamos la comparación estándar sin ajuste; si tu covariable es en realidad numérica, decláralo así para habilitar ANCOVA.',
          citation: CITE_FIELD,
          warnings: ['Tu covariable es categórica. ANCOVA solo ajusta por covariables continuas.'],
        };
      }
      if (nGroups >= 3) {
        return {
          recommendedMethod: label('anova'), methodSlug: 'anova', confidence: 'alta',
          justification: 'Tu variable explicativa agrupa en 3 o más grupos. Para comparar medias entre 3 o más grupos se usa ANOVA (o Kruskal-Wallis si no hay normalidad), no comparaciones de a dos, que inflarían el error tipo I.',
          citation: CITE_FLORES,
          preliminary: ['Estadísticos descriptivos por grupo', 'Prueba de normalidad (idealmente sobre los residuos del modelo; CanchariOS también la evalúa por grupo como referencia)', 'Homogeneidad de varianzas (Levene)'],
          assumptions: ['Independencia de las observaciones', 'Residuos aproximadamente normales', 'Homogeneidad de varianzas'],
          alternatives: [{ method: label('ancova'), reason: 'Si además quieres controlar una covariable continua.' }],
        };
      }
      return {
        recommendedMethod: label('comparacion'), methodSlug: 'comparacion', confidence: 'alta',
        justification: 'Tu variable explicativa agrupa en 2 grupos (independientes o relacionados/pre-post). Según la normalidad de los datos, se aplicará t de Student/Welch o su alternativa no paramétrica (Mann-Whitney/Wilcoxon).',
        citation: CITE_FLORES,
        preliminary: ['Estadísticos descriptivos por grupo', 'Prueba de normalidad (Shapiro-Wilk)', 'Homogeneidad de varianzas (Levene)'],
        assumptions: ['Normalidad por grupo', 'Homogeneidad de varianzas (si es paramétrica)'],
        alternatives: [{ method: label('ancova'), reason: 'Si quieres controlar una covariable continua entre tus 2 grupos.' }],
      };
    }

    // purpose === 'predecir' explicito con nominal como predictor dummy en regresion
    return {
      recommendedMethod: label('regresion'), methodSlug: 'regresion', confidence: 'media',
      justification: 'Tu propósito es predecir (no comparar) y tu predictor es categórico. Puedes incluirlo como variable dummy/indicadora dentro de una regresión lineal.',
      citation: CITE_FLORES,
      assumptions: ['Linealidad', 'Normalidad de residuos', 'Homocedasticidad'],
      alternatives: [{ method: label('comparacion'), reason: 'Si en realidad buscas comparar medias entre los grupos, no predecir con ellos como predictor.' }],
    };
  }

  // ── Fallback ─────────────────────────────────────────────────────────────────
  return {
    recommendedMethod: label('correlacional'), methodSlug: 'correlacional', confidence: 'baja',
    justification: 'No contamos con suficiente información de la escala de tus variables para una recomendación precisa.',
    warnings: ['Esta recomendación tiene confianza baja. Revisa la escala de tus variables o elige el método manualmente.'],
  };
}
