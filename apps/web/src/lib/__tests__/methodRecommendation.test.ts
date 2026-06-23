import { describe, it, expect } from 'vitest';
import { recommendMethod, needsPurposeQuestion, type MinimalInputs } from '../methodRecommendation';

// ============================================================================
// Test suite for the methodological recommendation engine.
// Each test case is backed by a real decision branch in methodRecommendation.ts,
// verified against the methodological criteria cited in the function's
// inline documentation (Flores-Ruiz et al. 2017; Field 2013; Hair et al. 2019;
// Cohen et al. 2003).
// ============================================================================

describe('needsPurposeQuestion()', () => {
  it('requires purpose for continuous outcome x continuous predictor (correlation vs regression ambiguity)', () => {
    expect(needsPurposeQuestion('continua', 'continua')).toBe(true);
  });

  it('requires purpose for continuous outcome x nominal predictor (compare vs predict-with-dummy ambiguity)', () => {
    expect(needsPurposeQuestion('continua', 'nominal_2')).toBe(true);
    expect(needsPurposeQuestion('continua', 'nominal_3mas')).toBe(true);
  });

  it('requires purpose for continuous outcome x ordinal predictor', () => {
    expect(needsPurposeQuestion('continua', 'ordinal')).toBe(true);
  });

  it('requires purpose whenever the outcome is ordinal, regardless of predictor', () => {
    expect(needsPurposeQuestion('ordinal', 'continua')).toBe(true);
    expect(needsPurposeQuestion('ordinal', 'ordinal')).toBe(true);
    expect(needsPurposeQuestion('ordinal', 'nominal_2')).toBe(true);
    expect(needsPurposeQuestion('ordinal', 'nominal_3mas')).toBe(true);
  });

  it('requires purpose for nominal(3+) outcome x nominal predictor (chi-square vs multinomial logistic ambiguity)', () => {
    expect(needsPurposeQuestion('nominal_3mas', 'nominal_2')).toBe(true);
    expect(needsPurposeQuestion('nominal_3mas', 'nominal_3mas')).toBe(true);
  });

  it('does NOT require purpose for nominal(2) outcome (always binary logistic, no ambiguity)', () => {
    expect(needsPurposeQuestion('nominal_2', 'continua')).toBe(false);
    expect(needsPurposeQuestion('nominal_2', 'nominal_3mas')).toBe(false);
  });

  it('does NOT require purpose for nominal(3+) outcome x continuous predictor (always multinomial)', () => {
    expect(needsPurposeQuestion('nominal_3mas', 'continua')).toBe(false);
  });
});

describe('recommendMethod() — outcome scale: nominal with 2 categories', () => {
  it('always recommends binary logistic regression, regardless of predictor scale or purpose', () => {
    const r = recommendMethod({ resultado: 'nominal_2', explicativa: 'continua', covariate: 'no' });
    expect(r.methodSlug).toBe('logistica');
    expect(r.confidence).toBe('alta');
  });

  it('offers discriminant analysis as a valid alternative for 2 groups', () => {
    const r = recommendMethod({ resultado: 'nominal_2', explicativa: 'continua', covariate: 'no' });
    expect(r.alternatives?.some(a => a.method.toLowerCase().includes('discriminante'))).toBe(true);
  });
});

describe('recommendMethod() — outcome scale: nominal with 3+ categories', () => {
  it('recommends multinomial logistic when predictor is continuous (no ambiguity, no purpose needed)', () => {
    const r = recommendMethod({ resultado: 'nominal_3mas', explicativa: 'continua', covariate: 'no' });
    expect(r.methodSlug).toBe('logistica');
    expect(r.recommendedMethod.toLowerCase()).toContain('multinomial');
  });

  it('recommends chi-square when both variables are nominal and purpose is to associate', () => {
    const r = recommendMethod({ resultado: 'nominal_3mas', explicativa: 'nominal_2', covariate: 'no', purpose: 'asociar' });
    expect(r.methodSlug).toBe('chi_cuadrado');
  });

  it('recommends multinomial logistic when both variables are nominal but purpose is to predict/classify', () => {
    const r1 = recommendMethod({ resultado: 'nominal_3mas', explicativa: 'nominal_2', covariate: 'no', purpose: 'predecir' });
    const r2 = recommendMethod({ resultado: 'nominal_3mas', explicativa: 'nominal_3mas', covariate: 'no', purpose: 'clasificar' });
    expect(r1.methodSlug).toBe('logistica');
    expect(r2.methodSlug).toBe('logistica');
  });

  it('defaults to chi-square (association) when nominal x nominal and no purpose is given', () => {
    const r = recommendMethod({ resultado: 'nominal_3mas', explicativa: 'nominal_3mas', covariate: 'no' });
    expect(r.methodSlug).toBe('chi_cuadrado');
  });
});

describe('recommendMethod() — outcome scale: ordinal', () => {
  it('recommends correlation (Spearman) when predictor is also ordered (continuous/ordinal) and purpose is to relate', () => {
    const r1 = recommendMethod({ resultado: 'ordinal', explicativa: 'continua', covariate: 'no', purpose: 'relacionar' });
    const r2 = recommendMethod({ resultado: 'ordinal', explicativa: 'ordinal', covariate: 'no', purpose: 'relacionar' });
    expect(r1.methodSlug).toBe('correlacional');
    expect(r2.methodSlug).toBe('correlacional');
  });

  it('recommends ordinal regression when predictor is ordered and purpose is to predict', () => {
    const r = recommendMethod({ resultado: 'ordinal', explicativa: 'continua', covariate: 'no', purpose: 'predecir' });
    expect(r.methodSlug).toBe('regresion_ordinal');
  });

  it('does NOT recommend correlation when predictor is nominal (unordered), even if purpose is to relate', () => {
    const r = recommendMethod({ resultado: 'ordinal', explicativa: 'nominal_2', covariate: 'no', purpose: 'relacionar' });
    expect(r.methodSlug).not.toBe('correlacional');
    expect(['comparacion', 'anova']).toContain(r.methodSlug);
  });

  it('recommends ordinal regression for ordinal outcome x nominal predictor when purpose is to predict', () => {
    const r = recommendMethod({ resultado: 'ordinal', explicativa: 'nominal_3mas', covariate: 'no', purpose: 'predecir' });
    expect(r.methodSlug).toBe('regresion_ordinal');
  });
});

describe('recommendMethod() — outcome scale: continuous, predictor: continuous', () => {
  it('recommends correlation when purpose is to relate', () => {
    const r = recommendMethod({ resultado: 'continua', explicativa: 'continua', covariate: 'no', purpose: 'relacionar' });
    expect(r.methodSlug).toBe('correlacional');
  });

  it('recommends linear regression when purpose is to predict, with no covariate', () => {
    const r = recommendMethod({ resultado: 'continua', explicativa: 'continua', covariate: 'no', purpose: 'predecir' });
    expect(r.methodSlug).toBe('regresion');
    expect(r.confidence).toBe('alta');
  });

  it('recommends multiple linear regression (not automatically hierarchical) when a covariate is present', () => {
    const r = recommendMethod({ resultado: 'continua', explicativa: 'continua', covariate: 'continua', purpose: 'predecir' });
    expect(r.methodSlug).toBe('regresion');
    expect(r.justification.toLowerCase()).not.toContain('siempre');
  });

  it('offers hierarchical regression only as an alternative, never as the primary recommendation from a covariate alone', () => {
    const r = recommendMethod({ resultado: 'continua', explicativa: 'continua', covariate: 'continua', purpose: 'predecir' });
    expect(r.methodSlug).not.toBe('regresion_jerarquica');
    expect(r.alternatives?.some(a => a.method.toLowerCase().includes('jerárquica'))).toBe(true);
  });
});

describe('recommendMethod() — outcome scale: continuous, predictor: nominal', () => {
  it('recommends group comparison for 2 groups when purpose is to compare', () => {
    const r = recommendMethod({ resultado: 'continua', explicativa: 'nominal_2', covariate: 'no', purpose: 'comparar' });
    expect(r.methodSlug).toBe('comparacion');
  });

  it('recommends ANOVA for 3+ groups when purpose is to compare', () => {
    const r = recommendMethod({ resultado: 'continua', explicativa: 'nominal_3mas', covariate: 'no', purpose: 'comparar' });
    expect(r.methodSlug).toBe('anova');
  });

  it('recommends ANCOVA when comparing groups with a continuous covariate (2+ groups, not requiring 3+)', () => {
    const r2 = recommendMethod({ resultado: 'continua', explicativa: 'nominal_2', covariate: 'continua', purpose: 'comparar' });
    const r3 = recommendMethod({ resultado: 'continua', explicativa: 'nominal_3mas', covariate: 'continua', purpose: 'comparar' });
    expect(r2.methodSlug).toBe('ancova');
    expect(r3.methodSlug).toBe('ancova');
  });

  it('warns and falls back to plain comparison/ANOVA when the covariate is categorical, not continuous', () => {
    const r = recommendMethod({ resultado: 'continua', explicativa: 'nominal_3mas', covariate: 'categorica', purpose: 'comparar' });
    expect(r.methodSlug).toBe('anova');
    expect(r.warnings?.length).toBeGreaterThan(0);
  });

  it('recommends linear regression with dummy coding when purpose is explicitly to predict (not compare)', () => {
    const r = recommendMethod({ resultado: 'continua', explicativa: 'nominal_2', covariate: 'no', purpose: 'predecir' });
    expect(r.methodSlug).toBe('regresion');
  });
});

describe('recommendMethod() — PLS-SEM activation', () => {
  it('recommends PLS-SEM only when multi-item dimensions are present AND purpose is relate/predict', () => {
    const r = recommendMethod({ resultado: 'continua', explicativa: 'continua', covariate: 'no', purpose: 'relacionar', hasDims: true });
    expect(r.methodSlug).toBe('structural_model');
  });

  it('does NOT recommend PLS-SEM when dimensions are absent, even if purpose is relate/predict', () => {
    const r = recommendMethod({ resultado: 'continua', explicativa: 'continua', covariate: 'no', purpose: 'relacionar', hasDims: false });
    expect(r.methodSlug).not.toBe('structural_model');
  });
});

describe('recommendMethod() — exhaustive coverage (no fallback, no unexpectedly low confidence)', () => {
  const scales = ['continua', 'ordinal', 'nominal_2', 'nominal_3mas'] as const;
  const covariates = ['no', 'continua', 'categorica'] as const;
  const purposes = ['relacionar', 'predecir', 'comparar', 'clasificar', 'asociar'] as const;

  it('never falls back to the generic low-confidence default across all scale x covariate x purpose combinations', () => {
    let fallbackCount = 0;
    for (const resultado of scales) {
      for (const explicativa of scales) {
        for (const covariate of covariates) {
          for (const purpose of purposes) {
            const r = recommendMethod({ resultado, explicativa, covariate, purpose, hasDims: false });
            if (r.confidence === 'baja') fallbackCount++;
          }
        }
      }
    }
    expect(fallbackCount).toBe(0);
  });
});
