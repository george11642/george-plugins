# Advanced Statistics: Causal Inference, Multilevel Models, and SEM

## Overview

This reference covers statistical methods beyond standard ANOVA/regression: causal inference with DAGs, multilevel modeling for nested data, longitudinal analysis, structural equation modeling, and the distinction between prediction and causal models. These methods are increasingly expected in social, biomedical, and behavioral research.

---

## Causal Inference

**The fundamental problem of causal inference**: We can never observe the same unit under both treatment and control at the same time. All causal claims require assumptions beyond the data.

### Directed Acyclic Graphs (DAGs)

DAGs are the key tool for making causal assumptions explicit and identifying valid adjustment strategies.

**Components**:
- **Nodes**: Variables (observed or unobserved/latent)
- **Directed edges (arrows)**: Assumed causal direction (X → Y means X causally influences Y)
- **Acyclic**: No variable can cause itself (no feedback loops in the DAG, even if the real system has feedback)
- **Paths**: Any sequence of connected edges (following or ignoring arrow direction)

**Path types**:
- **Causal path**: Arrows flow in one direction from exposure to outcome (X → M → Y)
- **Backdoor path**: Non-causal path from exposure to outcome through a common cause (X ← C → Y)
- **Collider**: A variable where two arrows point in (X → C ← Y); conditioning on a collider opens a spurious path

**Key concepts**:

**Backdoor criterion**: A set of variables Z satisfies the backdoor criterion for estimating the causal effect of X on Y if: (1) Z blocks all backdoor paths from X to Y, and (2) Z does not contain descendants of X. If Z satisfies the backdoor criterion, adjusting for Z gives the unconfounded causal effect.

**Collider bias**: If you condition on (include in regression, stratify by, or select on) a collider, you open a spurious association between its causes. Example: Berkson's paradox — in a hospital sample (selected on hospitalization = a collider of disease and injury), disease and injury appear negatively correlated even if unrelated in the population.

**Mediator**: A variable on the causal path from X to Y (X → M → Y). Including a mediator in a regression will block the indirect effect and give only the direct effect. Use mediation analysis rather than "controlling for" mediators.

### Drawing and Analyzing DAGs in Practice

**Tools**:
- **DAGitty** (dagitty.net): Free browser-based tool. Draw your DAG, and it automatically identifies: minimal sufficient adjustment sets, testable implications, backdoor paths.
- **ggdag** (R): `ggplot2`-based visualization of DAGitty DAGs
- **causalgraphicalmodels** (Python): DAG analysis in Python
- **CausalNex** (Python/PyData): Bayesian network learning with causal interpretation

**Workflow**:
1. Identify all variables relevant to your research question
2. Draw arrows representing causal assumptions (use domain knowledge, prior literature)
3. In DAGitty, identify the minimal adjustment set
4. Check for testable implications (conditional independencies) and compare to your data
5. Conduct sensitivity analysis: what would an unmeasured confounder need to look like to explain away your result? (E-value)

### Propensity Score Methods

Propensity score (PS): the probability of receiving treatment given observed covariates, P(T=1|X). Balances observed covariates between treatment groups.

**PS estimation**: Usually logistic regression or machine learning (random forest, CBPS). Include all pre-treatment variables that predict treatment or outcome (use your DAG to identify adjustment set).

**PS matching**:
- Match treated and untreated units with similar PS
- 1:1 or 1:k matching; nearest-neighbor, caliper, exact
- Check balance after matching (standardized mean differences < 0.1)
- Analyze matched sample like an RCT

**Inverse Probability of Treatment Weighting (IPTW)**:
- Weight each unit by 1/PS (treated) or 1/(1-PS) (untreated)
- Creates a pseudo-population where treatment is independent of covariates
- Better for average treatment effect (ATE); matching better for ATT

**Limitations**:
- Only addresses observed confounding — unmeasured confounders remain a problem
- PS methods do not solve violations of positivity (no overlap in PS distributions)
- Sensitivity analysis for unmeasured confounding (E-values, Rosenbaum bounds) is mandatory

### Instrumental Variables (IV)

An instrumental variable Z causes X but affects Y only through X (exclusion restriction).

**IV assumptions**:
1. **Relevance**: Z is correlated with X (testable; F-statistic > 10 in first stage)
2. **Exclusion**: Z affects Y only through X (untestable; requires domain knowledge)
3. **Independence**: Z is independent of unmeasured confounders of X-Y (untestable)

**Common instruments**: Randomized encouragement to treatment (in trials), geographic access to care, policy changes, genetic variants (Mendelian randomization)

**Mendelian randomization**: Uses genetic variants as instruments to estimate causal effects of modifiable exposures on health outcomes. Two-sample MR uses GWAS summary statistics. Assumptions: (1) genetic variant associates with exposure; (2) not associated with confounders; (3) no pleiotropic effects.

**Implementation**:
- R: `ivreg` (AER package), `ivmodel`
- Python: `linearmodels` (IV2SLS)
- For MR: `TwoSampleMR`, `MendelianRandomization` R packages

### Regression Discontinuity Design (RDD)

Exploits a cutoff in an assignment variable that determines treatment.

**Sharp RDD**: Units above cutoff receive treatment; below do not. Estimate causal effect at the cutoff by comparing units just above and just below.

**Key assumptions**:
- No precise manipulation of the assignment variable around the cutoff
- No other discontinuous changes at the cutoff
- Continuity of potential outcomes at the cutoff

**Bandwidth selection**: Optimal bandwidth (Calonico-Cattaneo-Titiunik) balances bias-variance tradeoff. Always test sensitivity to bandwidth choice.

**Implementation**: R: `rdrobust`, `rdd`; Python: `rdrobust` (via rpy2 or native ports)

**Validity checks**: Density test (McCrary) for manipulation; placebo tests at other cutoffs; balance on predetermined covariates

### Difference-in-Differences (DiD)

Compares change over time in a treated group to change in a control group, under the parallel trends assumption.

**Basic DiD estimator**:
ATT = (Y_treated,post - Y_treated,pre) - (Y_control,post - Y_control,pre)

**Key assumption — parallel trends**: In the absence of treatment, treated and control groups would have followed parallel trends. Assess with pre-treatment trend plots; test formally with event-study specification.

**Modern DiD concerns (post-2020 literature)**:
- **Staggered adoption DiD**: When different units are treated at different times, the classic two-way fixed effects (TWFE) estimator can be badly biased. Use: Callaway & Sant'Anna estimator, Sun & Abraham, de Chaisemartin & D'Haultfoeuille.
- R: `did`, `didimputation`, `fixest` packages; Python: `pyfixest`

---

## Multilevel / Mixed Models

### When to Use

Use multilevel (hierarchical) models when data are nested:
- Students within classrooms within schools
- Patients within clinics within hospitals
- Repeated observations within participants
- Respondents within neighborhoods
- Animals within litters

**The problem with ignoring nesting**: Standard regression assumes observations are independent. Nested data violate this — two students from the same class are more similar than two random students. Ignoring this: inflates sample size, underestimates standard errors, produces false precision.

### Fixed vs Random Effects

**Fixed effects**: Parameters estimated for specific levels (e.g., one estimate per school). Appropriate when you want to control for between-group differences and make inferences only about those specific groups.

**Random effects**: Groups are treated as drawn from a distribution; we estimate the distribution's parameters (variance), not individual group effects. Appropriate when groups are a random sample of a larger population and you want to generalize.

**Mixed model**: Includes both fixed effects (predictors of interest) and random effects (accounting for grouping structure).

### Model Specification

**Random intercepts model**: Each group has its own baseline level, but slopes are the same across groups.
```
Y_ij = β0 + u0j + β1*X_ij + ε_ij
```
Where u0j ~ N(0, τ²) is the random intercept for group j.

**Random slopes model**: Slopes also vary across groups.
```
Y_ij = β0 + u0j + (β1 + u1j)*X_ij + ε_ij
```
Start with random intercepts; add random slopes only when theoretically justified or if fit improves substantially.

**Cross-level interactions**: How does a group-level variable moderate the effect of an individual-level predictor?

### Software

**R (lme4)**:
```r
library(lme4)
# Random intercepts
m1 <- lmer(outcome ~ predictor + (1 | group), data = df, REML = TRUE)
# Random slopes
m2 <- lmer(outcome ~ predictor + (1 + predictor | group), data = df)
# Significance testing
library(lmerTest)  # adds p-values via Satterthwaite df
summary(m1)
```

**Python (statsmodels)**:
```python
import statsmodels.formula.api as smf
model = smf.mixedlm("outcome ~ predictor", data=df, groups=df["group"])
result = model.fit()
print(result.summary())
```

**Bayesian multilevel models**:
- R: `brms` (Stan backend) — full posterior distributions, flexible priors
- Python: `bambi` (PyMC backend)

### Interpreting Output

**Intraclass Correlation Coefficient (ICC)**:
ICC = τ² / (τ² + σ²)

Proportion of variance attributable to group differences. ICC = 0 → no grouping structure; ICC = 0.20 → 20% of variance is between groups. Rule of thumb: ICC > 0.05 warrants multilevel modeling.

**Fixed effects**: Interpreted like standard regression coefficients (average across all groups).

**Random effects variance components**: τ² (between-group variance in intercepts), σ² (within-group residual variance). Report both with confidence intervals.

**Report**: Fixed effects, their SEs, df (or Satterthwaite), t/z values, p-values, CIs; random effects variances; ICC; model fit (AIC, BIC, or Bayes factor if Bayesian).

---

## Longitudinal Data Analysis

### Growth Curve Models

Linear growth curve model: latent intercept and slope for each individual.
```r
# In lme4: time as fixed and random effect
m <- lmer(outcome ~ time + (1 + time | id), data = df_long)
```
- Fixed effect of time: average growth rate across all individuals
- Random effect of time: individual variation around average growth rate

Nonlinear growth: Add time² for quadratic; use `nlme` or `brms` for nonlinear functions (logistic growth, etc.)

### Autoregressive Models

When observations are closely spaced in time and adjacent values are correlated:
- **AR(1) residual structure**: corr(ε_t, ε_t-1) = ρ
- R: `nlme::gls` or `lme` with `corAR1` correlation structure
- Cross-lagged panel models: assess bidirectional effects between two variables over time

### Handling Missing Data

**Mechanisms**:
- **MCAR (Missing Completely At Random)**: Missingness unrelated to any variable. Rare in practice. Complete-case analysis unbiased but inefficient.
- **MAR (Missing At Random)**: Missingness depends on observed data only (not missing data itself). Multiple imputation valid.
- **MNAR (Missing Not At Random)**: Missingness depends on the missing value itself. Most serious; requires sensitivity analysis or selection models.

**Multiple imputation (MI)**:
1. Create M imputed datasets (typically M = 20-100)
2. Analyze each dataset with your planned analysis
3. Pool estimates using Rubin's rules (average estimates; variance = within-imputation variance + between-imputation variance)

R: `mice` package (most flexible); `Amelia` (for time series data)
Python: `sklearn.impute.IterativeImputer`; `miceforest`

**Full Information Maximum Likelihood (FIML)**:
- For SEM and multilevel models
- Uses all available data without explicitly imputing
- Valid under MAR; efficient; preferable to listwise deletion

---

## Structural Equation Modeling (SEM)

SEM combines measurement models (confirmatory factor analysis) and structural models (path analysis) into a unified framework.

### Path Diagrams

Conventions:
- **Rectangles/squares**: Observed (manifest) variables
- **Ovals/circles**: Latent (unobserved) variables
- **Single-headed arrow**: Regression path (directional effect)
- **Double-headed curved arrow**: Covariance (non-directional association)
- Small circle with arrow → observed variable: residual/error term

### Measurement Model (CFA)

**Confirmatory Factor Analysis** tests whether a specified set of indicators measures the hypothesized latent construct.

```r
library(lavaan)
model_cfa <- '
  # Measurement model
  anxiety =~ anx1 + anx2 + anx3 + anx4
  depression =~ dep1 + dep2 + dep3
'
fit_cfa <- cfa(model_cfa, data = df, estimator = "MLR")
summary(fit_cfa, fit.measures = TRUE, standardized = TRUE)
```

### Full SEM

```r
model_sem <- '
  # Measurement model
  anxiety =~ anx1 + anx2 + anx3 + anx4
  depression =~ dep1 + dep2 + dep3

  # Structural model
  depression ~ anxiety + stressor
  anxiety ~ stressor
'
fit_sem <- sem(model_sem, data = df, estimator = "MLR")
```

### Goodness-of-Fit Indices

| Index | Acceptable | Good |
|---|---|---|
| **CFI** (Comparative Fit Index) | ≥ .90 | ≥ .95 |
| **TLI** (Tucker-Lewis Index) | ≥ .90 | ≥ .95 |
| **RMSEA** (Root Mean Square Error of Approximation) | ≤ .08 | ≤ .05 |
| **SRMR** (Standardized Root Mean Square Residual) | ≤ .08 | ≤ .05 |
| **chi-squared** | Not significant (p > .05) | — but sensitive to n |

Report multiple fit indices. Never rely on chi-squared alone (it is always significant with n > 200).

**Modification indices**: If fit is poor, lavaan outputs MIs suggesting which parameters to free. Only modify on theoretical grounds — purely data-driven modifications capitalize on chance.

### Python SEM

```python
# semopy
import semopy
model_desc = """
  anxiety =~ anx1 + anx2 + anx3 + anx4
  depression =~ dep1 + dep2 + dep3
  depression ~ anxiety
"""
model = semopy.Model(model_desc)
result = model.fit(df)
stats = semopy.calc_stats(model)
```

### Mediation in SEM

SEM enables formal mediation testing with latent variables:
- Direct effect: X → Y (not through M)
- Indirect effect: X → M → Y (product of paths a and b)
- Total effect = direct + indirect

Bootstrap confidence intervals for indirect effects (not Sobel test — too conservative):
```r
fit_med <- sem(model, data = df, se = "bootstrap", bootstrap = 5000)
parameterEstimates(fit_med, ci = TRUE)  # check indirect effect CI
```

---

## ML vs Causal Inference: Prediction vs Explanation

### The Core Distinction

**Prediction models**: Minimize out-of-sample prediction error. Any feature that improves prediction is useful, regardless of causal role (including mediators, colliders, descendants of outcome).

**Causal models**: Estimate the causal effect of X on Y. Including colliders or descendants of Y introduces bias. Regularization (LASSO, ridge) shrinks true causal effects toward zero — biased for causal interpretation but fine for prediction.

**You cannot tell by looking at R² or RMSE which model is correct for causal questions.**

### When ML Undermines Causal Estimates

- **LASSO regression** selects features that predict outcome, not necessarily the causal set. Penalizing the true causal variable will bias causal estimates.
- **Black-box models** (random forests, neural nets) give feature importances that are not causal effects — they are prediction contributions, conflating direct and indirect paths.
- **Cross-validation** optimizes prediction; it does not validate causal identification.

### Causal Machine Learning

Methods that combine ML flexibility with causal identification:

**Double/Debiased Machine Learning (DML)** (Chernozhukov et al., 2018):
1. Regress treatment T on controls X using ML → get residuals ẽ
2. Regress outcome Y on controls X using ML → get residuals ỹ
3. Regress ỹ on ẽ → coefficient is the causal estimate
- Advantage: controls for high-dimensional confounders while recovering causal effect
- R: `DoubleML` package; Python: `doubleml` package

**Causal Forests** (Wager & Athey, 2018):
- Random forest variant designed to estimate heterogeneous treatment effects
- Each leaf is homogeneous in treatment effect, not just outcome
- R/Python: `grf` (Generalized Random Forests) package

**Key principle**: Before applying any ML method, decide: prediction or causal inference? If causal: (1) draw your DAG, (2) identify your adjustment set, (3) use causal ML methods designed for that purpose.

---

## Reporting Checklist for Advanced Methods

### DAG-Based Causal Analysis

- [ ] DAG drawn and made available (supplement or DAGitty link)
- [ ] Causal assumptions stated and justified
- [ ] Adjustment set identified from DAG (not ad hoc covariate selection)
- [ ] Sensitivity analysis for unmeasured confounding (E-value or similar)

### Multilevel Models

- [ ] Nesting structure described and justified
- [ ] ICC reported for null model
- [ ] Random effects structure justified (intercepts only, or slopes)
- [ ] Model fit compared between random-intercepts and random-slopes
- [ ] Fixed effects reported with SEs, df, t-values, p-values, CIs
- [ ] Random effects variances reported
- [ ] Software and version noted (lme4 version X, optimizer Y)

### SEM / CFA

- [ ] Path diagram in supplementary materials
- [ ] Estimator specified (ML, MLR, WLSMV)
- [ ] Sample size adequate (n ≥ 200, or 10 per parameter)
- [ ] Multiple fit indices reported (CFI, TLI, RMSEA, SRMR)
- [ ] Factor loadings and structural paths with SEs and CIs
- [ ] Modification indices reported if model was respecified
- [ ] Lavaan/semopy version noted

---

## Key References

- Pearl, J., Glymour, M., & Jewell, N.P. (2016). *Causal Inference in Statistics: A Primer*. Wiley.
- Cunningham, S. (2021). *Causal Inference: The Mixtape*. Yale University Press. (Free: https://mixtape.scunning.com)
- Hernan, M.A. & Robins, J.M. (2020). *Causal Inference: What If*. (Free: https://www.hsph.harvard.edu/miguel-hernan/causal-inference-book/)
- Snijders, T.A.B. & Bosker, R.J. (2012). *Multilevel Analysis* (2nd ed.). Sage.
- Kline, R.B. (2023). *Principles and Practice of Structural Equation Modeling* (5th ed.). Guilford.
- Chernozhukov, V. et al. (2018). Double/debiased machine learning. *Econometrics Journal, 21*(1), C1-C68.
- DAGitty: http://dagitty.net
- lavaan: https://lavaan.ugent.be
- lme4: https://cran.r-project.org/package=lme4
- DoubleML: https://docs.doubleml.org
