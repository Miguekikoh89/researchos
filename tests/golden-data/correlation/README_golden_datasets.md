# CanchariOS — Golden Datasets

Reproducible datasets for the illustrative examples in the SoftwareX manuscript.
All datasets were generated with fixed random seeds in R 4.3.x.
Upload this folder to `tests/golden-data/` in the repository.

| File | Example | Method | n | Variables |
|------|---------|--------|---|-----------|
| `ejemplo_3.1_correlacion_spearman_n50.xlsx` | 3.1 | Spearman correlation | 50 | SL1–SL10, DD1–DD10 |
| `ejemplo_3.2_kruskal_wallis_n45.xlsx` | 3.2 | Kruskal-Wallis + Dunn post-hoc | 45 | DA1–DA10, grupo |
| `ejemplo_3.3_regresion_multiple_n384.xlsx` | 3.3 | Multiple linear regression | 384 | CAL1–CAL8, FIDE1–FIDE8, Y1–Y8 |
| `ejemplo_3.4_logistica_ordinal_n384.xlsx` | 3.4 | Ordinal logistic regression | 384 | CAL1–CAL8, FIDE1–FIDE8, nivel_satisfaccion |
| `ejemplo_3.5_chi_cuadrado_n384.xlsx` | 3.5 | Chi-square + Cramér's V | 384 | VAR1_1–VAR1_12, VAR2_1–VAR2_12 |
| `ejemplo_3.6_pls_sem_serial_mediacion_n384.xlsx` | 3.6 | PLS-SEM serial mediation | 384 | ICSR1–ICSR14, IND1–IND4, GRP1–GRP4, ORG1–ORG4 |

## Variable descriptions

### Example 3.1 — Work Satisfaction & Teaching Performance
- `SL1–SL10`: Work Satisfaction (Satisfacción Laboral), Likert 1–5
- `DD1–DD10`: Teaching Performance (Desempeño Docente), Likert 1–5
- Generated with `set.seed(31)`, latent factor ρ ≈ .99, λ = .97

### Example 3.2 — Academic Performance by Institution Type
- `DA1–DA10`: Academic Performance (Desempeño Académico), Likert 1–5
- `grupo`: Institution type (1 = Type A, 2 = Type B, 3 = Type C)
- Three balanced groups (n₁ = n₂ = n₃ = 15)

### Example 3.3 — Multiple Linear Regression
- `CAL1–CAL8`: Predictor 1 (Calidad), Likert 1–5
- `FIDE1–FIDE8`: Predictor 2 (Fidelidad), Likert 1–5
- `Y1–Y8`: Outcome variable, Likert 1–5

### Example 3.4 — Ordinal Logistic Regression
- `CAL1–CAL8`: Predictor 1, Likert 1–5
- `FIDE1–FIDE8`: Predictor 2, Likert 1–5
- `nivel_satisfaccion`: Ordered outcome (Bajo / Medio / Alto), classified via theoretical baremo cuts at 2.33 and 3.67 on a 1–5 scale

### Example 3.5 — Chi-Square
- `VAR1_1–VAR1_12`: Variable 1, Likert 1–5
- `VAR2_1–VAR2_12`: Variable 2, Likert 1–5
- Both classified into Bajo/Medio/Alto before chi-square test

### Example 3.6 — PLS-SEM Serial Mediation
- `ICSR1–ICSR14`: Corporate Social Responsibility (14 reflective indicators)
- `IND1–IND4`: Individual outcome (4 reflective indicators)
- `GRP1–GRP4`: Group outcome (4 reflective indicators)
- `ORG1–ORG4`: Organizational outcome (4 reflective indicators)
- Structural model: ICSR → IND → GRP → ORG (serial mediation)
- Generated with `set.seed(361)`, seminr 2.5.0

## Reproduction

```r
# Reproduce Example 3.6 results:
library(seminr)
df <- readxl::read_xlsx("ejemplo_3.6_pls_sem_serial_mediacion_n384.xlsx")
mm <- constructs(
  composite("ICSR", paste0("ICSR", 1:14)),
  composite("IND",  paste0("IND",  1:4)),
  composite("GRP",  paste0("GRP",  1:4)),
  composite("ORG",  paste0("ORG",  1:4))
)
sm <- relationships(
  paths(from = "ICSR", to = c("IND", "ORG")),
  paths(from = "IND",  to = "GRP"),
  paths(from = "GRP",  to = "ORG")
)
fit  <- estimate_pls(df, mm, sm)
boot <- bootstrap_model(fit, nboot = 5000, seed = 2024)
summary(boot)$bootstrapped_paths
```

## Note on numerical differences

Results produced by CanchariOS may differ from the values in the manuscript
by small amounts (|Δβ| < 0.005 for path coefficients; |ΔIC| < 0.01 for
bootstrap intervals with nboot = 5,000) due to Monte Carlo variation in
bootstrapping. This is expected and does not indicate an error.
All structural conclusions (significance, direction, magnitude class)
are invariant to this variation.
