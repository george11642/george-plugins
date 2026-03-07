# Statistical Analysis Reference

## Overview

Guided statistical analysis: test selection, assumption checking, power analysis, effect sizes, and APA-formatted reporting. Python implementation with scipy, statsmodels, pingouin, pymc.

## Test Selection Quick Reference

**Comparing Two Groups**:
| Data Type | Normal | Non-Normal |
|-----------|--------|------------|
| Independent | Independent t-test | Mann-Whitney U |
| Paired | Paired t-test | Wilcoxon signed-rank |
| Binary | Chi-square / Fisher's exact | -- |

**Comparing 3+ Groups**:
| Data Type | Normal | Non-Normal |
|-----------|--------|------------|
| Independent | One-way ANOVA | Kruskal-Wallis |
| Paired | Repeated measures ANOVA | Friedman |

**Relationships**:
- Two continuous: Pearson (normal) or Spearman (non-normal) correlation
- Continuous outcome + predictors: Linear regression
- Binary outcome + predictors: Logistic regression

## Assumption Checking (ALWAYS DO FIRST)

```python
from scripts.assumption_checks import comprehensive_assumption_check
results = comprehensive_assumption_check(data=df, value_col='score', group_col='group')
```

**Normality violated**: n>30 mild violation -> proceed; moderate -> non-parametric; severe -> transform or non-parametric
**Variance violated**: t-test -> Welch's; ANOVA -> Welch's ANOVA
**Linearity violated**: polynomial terms, transforms, or non-linear models

## Effect Sizes (ALWAYS REPORT)

| Test | Effect Size | Small | Medium | Large |
|------|-------------|-------|--------|-------|
| T-test | Cohen's d | 0.20 | 0.50 | 0.80 |
| ANOVA | partial eta-sq | 0.01 | 0.06 | 0.14 |
| Correlation | r | 0.10 | 0.30 | 0.50 |
| Regression | R-sq | 0.02 | 0.13 | 0.26 |
| Chi-square | Cramer's V | 0.07 | 0.21 | 0.35 |

Always report with confidence intervals. Distinguish statistical from practical significance.

## Power Analysis

```python
from statsmodels.stats.power import tt_ind_solve_power
n = tt_ind_solve_power(effect_size=0.5, alpha=0.05, power=0.80, ratio=1.0)
```

Post-hoc power analysis is not recommended. Use sensitivity analysis instead.

## APA Reporting Templates

**T-test**: "Group A (n=48, M=75.2, SD=8.5) scored significantly higher than Group B (n=52, M=68.3, SD=9.2), t(98)=3.82, p<.001, d=0.77, 95% CI [0.36, 1.18]."

**ANOVA**: "A significant main effect of treatment was found, F(2,147)=8.45, p<.001, partial eta-sq=.10. Tukey's HSD: A>B (p=.002, d=0.87), A>C (p<.001, d=1.07)."

**Regression**: "The model was significant, F(3,146)=45.2, p<.001, R-sq=.48. Study hours (B=1.80, beta=.35, p<.001) and GPA (B=8.52, beta=.28, p<.001) were significant predictors."

**Bayesian**: "Posterior: M_diff=6.8, 95% credible interval [3.2, 10.4]. BF10=45.3 (very strong evidence). P(mu1>mu2|data)=99.8%."

## Bayesian Statistics

Use when: prior information available, want direct probability statements, small samples, need evidence for null hypothesis, complex hierarchical models.

Key advantages: intuitive interpretation, evidence for null, no p-hacking concerns, full uncertainty quantification.

## Best Practices

1. Pre-register analyses when possible
2. Always check assumptions before interpreting
3. Report effect sizes with CIs
4. Report ALL planned analyses including non-significant
5. Distinguish statistical from practical significance
6. Visualize data before and after analysis
7. Share data and code for reproducibility
8. Be transparent about violations and decisions

## Common Pitfalls

1. P-hacking (testing multiple ways until significant)
2. HARKing (presenting exploratory as confirmatory)
3. Ignoring assumptions
4. Confusing significance with importance
5. Not reporting effect sizes
6. Cherry-picking results
7. Misinterpreting p-values (not P(H|data))
8. No multiple comparison correction
9. Ignoring missing data mechanisms
10. Overinterpreting non-significant results
