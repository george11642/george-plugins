# Statistical Plots Reference

Covers Seaborn deep dives (pairplot, clustermap, lmplot), multi-variate encoding, error bars, statistical annotations, QQ plots, empirical CDF, survival analysis, Bland-Altman plots, forest plots, and publication-ready templates.

---

## Seaborn Setup

```python
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# Recommended theme for publication figures
sns.set_theme(
    style="whitegrid",    # "whitegrid" | "darkgrid" | "white" | "dark" | "ticks"
    palette="colorblind", # automatically colorblind-safe (Okabe-Ito)
    font="sans-serif",
    font_scale=1.2,
    rc={"figure.dpi": 150, "savefig.dpi": 300}
)
```

---

## 1. pairplot — Multi-Variable Relationships

Plots all pairwise scatter plots + diagonal univariate distributions. Essential for EDA.

```python
import seaborn as sns
import matplotlib.pyplot as plt

df = sns.load_dataset("penguins").dropna()

# Full pairplot with hue
g = sns.pairplot(
    df,
    hue="species",             # color by categorical variable
    vars=["bill_length_mm", "bill_depth_mm", "flipper_length_mm", "body_mass_g"],
    diag_kind="kde",           # diagonal: "hist" | "kde" | "auto"
    plot_kws=dict(alpha=0.6, s=30, edgecolors="none"),
    diag_kws=dict(fill=True, alpha=0.4),
    palette="colorblind",
    corner=False               # True = lower triangle only (faster)
)

# Add correlation coefficients to upper triangle
from scipy import stats

def corrfunc(x, y, **kwargs):
    r, p = stats.pearsonr(x, y)
    color = kwargs.get("color", "black")
    ax = plt.gca()
    ax.annotate(
        f"r = {r:.2f}\np = {p:.3f}",
        xy=(0.5, 0.5), xycoords="axes fraction",
        ha="center", va="center",
        fontsize=9,
        color="red" if p < 0.05 else "gray"
    )

g.map_upper(corrfunc)

g.fig.suptitle("Penguin Morphometrics by Species", y=1.02, fontsize=16)
plt.tight_layout()
plt.savefig("pairplot.png", dpi=200, bbox_inches="tight")
plt.show()
```

### pairplot variations

```python
# Regression lines in lower triangle
g = sns.pairplot(df, hue="species", kind="reg",    # adds linear regression
                 plot_kws=dict(scatter_kws=dict(alpha=0.3, s=20),
                               line_kws=dict(lw=1.5)))

# KDE contours instead of scatter
g = sns.pairplot(df, hue="species", kind="kde")

# With custom marker per hue level
markers = {"Adelie": "o", "Chinstrap": "s", "Gentoo": "^"}
g = sns.pairplot(df, hue="species", markers=markers)
```

---

## 2. clustermap — Hierarchical Clustering Heatmap

Shows clustered rows and columns with dendrograms. Essential for gene expression, correlation matrices.

```python
import seaborn as sns
import pandas as pd
import numpy as np

# Example: correlation matrix of numeric features
df = sns.load_dataset("flights").pivot(index="month", columns="year", values="passengers")

g = sns.clustermap(
    df,
    method="ward",           # linkage: "ward" | "complete" | "average" | "single"
    metric="euclidean",      # distance metric
    z_score=1,               # normalize: 0=rows, 1=columns, None=off
    cmap="RdBu_r",           # diverging for z-scores
    figsize=(12, 10),
    linewidths=0.5,
    linecolor="white",
    annot=True,              # show values in cells
    fmt=".0f",               # format for annotations
    cbar_kws={"label": "Z-score", "shrink": 0.5},
    dendrogram_ratio=(0.15, 0.15),  # (row, col) dendrogram size fraction
    col_cluster=True,        # cluster columns
    row_cluster=True,        # cluster rows
)

# Reorder axes labels
g.ax_heatmap.set_xlabel("Year", fontsize=12)
g.ax_heatmap.set_ylabel("Month", fontsize=12)
g.fig.suptitle("Flight Passengers (Z-score normalized)", y=1.01, fontsize=14)
plt.savefig("clustermap.png", dpi=200, bbox_inches="tight")
```

```python
# Annotate specific clusters with colored row labels
row_colors = pd.Series(
    {"Jan": "blue", "Feb": "blue", "Mar": "green",
     "Apr": "green", "May": "green", "Jun": "red",
     "Jul": "red", "Aug": "red", "Sep": "orange",
     "Oct": "orange", "Nov": "blue", "Dec": "blue"},
    name="Season"
)
g = sns.clustermap(df, row_colors=row_colors, cmap="YlOrRd")
```

---

## 3. lmplot — Regression with Facets

Combines scatter + regression line + confidence interval + faceting.

```python
import seaborn as sns

df = sns.load_dataset("tips")

# Faceted regression: separate plots per smoker/time combination
g = sns.lmplot(
    data=df,
    x="total_bill",
    y="tip",
    hue="sex",             # color by variable (separate regression lines)
    col="time",            # facet columns
    row="smoker",          # facet rows
    height=4,
    aspect=1.2,
    scatter_kws=dict(alpha=0.5, s=30),
    line_kws=dict(lw=2),
    ci=95,                 # confidence interval width
    order=1,               # polynomial order (1=linear, 2=quadratic)
    robust=False,          # True = use robust regression (less sensitive to outliers)
    truncate=True          # don't extrapolate regression line beyond data range
)

g.set_axis_labels("Total Bill ($)", "Tip ($)")
g.set_titles(col_template="{col_name}", row_template="Smoker: {row_name}")
g.fig.suptitle("Tip vs Bill by Demographics", y=1.02)
plt.tight_layout()
```

---

## 4. Multi-Variate Encoding

Encode up to 5 dimensions simultaneously: x, y, color (hue), size, shape.

```python
import seaborn as sns
import matplotlib.pyplot as plt

df = sns.load_dataset("penguins").dropna()

fig, ax = plt.subplots(figsize=(10, 7))

scatter = sns.scatterplot(
    data=df,
    x="flipper_length_mm",
    y="body_mass_g",
    hue="species",         # color = 3rd dimension
    size="bill_length_mm", # size = 4th dimension
    style="island",        # marker shape = 5th dimension
    sizes=(40, 300),       # min/max marker size
    alpha=0.8,
    palette="colorblind",
    ax=ax
)

ax.set_xlabel("Flipper Length (mm)", fontsize=13)
ax.set_ylabel("Body Mass (g)", fontsize=13)
ax.set_title("5-Dimensional Penguin Encoding", fontsize=15)

# Separate legends for hue and size
h, l = ax.get_legend_handles_labels()
# Hue legend
ax.legend(h[:4], l[:4], title="Species", loc="upper left")
# Size legend (second legend)
from matplotlib.legend import Legend
leg2 = Legend(ax, h[4:], l[4:], title="Bill Length (mm)", loc="lower right")
ax.add_artist(leg2)

plt.tight_layout()
```

---

## 5. Error Bars and Confidence Intervals

```python
import matplotlib.pyplot as plt
import numpy as np
from scipy import stats

# --- ax.errorbar ---
fig, axes = plt.subplots(1, 3, figsize=(15, 5))

x = np.arange(5)
y = np.array([3.2, 4.1, 2.8, 5.0, 3.7])
yerr = np.array([0.3, 0.5, 0.2, 0.4, 0.3])
yerr_asym = np.array([[0.2, 0.3, 0.1, 0.3, 0.2],   # lower errors
                       [0.4, 0.6, 0.3, 0.5, 0.4]])  # upper errors

# Symmetric error bars
axes[0].errorbar(x, y, yerr=yerr, fmt="o-", capsize=5, capthick=1.5,
                 elinewidth=1.5, color="steelblue", ecolor="gray", markersize=8)
axes[0].set_title("Symmetric Error Bars")

# Asymmetric error bars
axes[1].errorbar(x, y, yerr=yerr_asym, fmt="s--", capsize=5,
                 color="coral", ecolor="brown")
axes[1].set_title("Asymmetric Error Bars")

# Shaded confidence interval (better for dense time series)
t = np.linspace(0, 4*np.pi, 100)
y_mean = np.sin(t)
y_std = 0.3 + 0.1 * np.abs(np.cos(t))
axes[2].plot(t, y_mean, color="steelblue", lw=2, label="Mean")
axes[2].fill_between(t, y_mean - y_std, y_mean + y_std,
                     alpha=0.3, color="steelblue", label="±1 SD")
axes[2].fill_between(t, y_mean - 2*y_std, y_mean + 2*y_std,
                     alpha=0.15, color="steelblue", label="±2 SD")
axes[2].legend()
axes[2].set_title("Shaded Confidence Band")

plt.tight_layout()
```

---

## 6. Statistical Annotations — p-Values and Significance Brackets

```python
# pip install statannotations
from statannotations.Annotator import Annotator
import seaborn as sns
import matplotlib.pyplot as plt
from scipy import stats

df = sns.load_dataset("tips")

fig, ax = plt.subplots(figsize=(8, 6))
sns.boxplot(data=df, x="day", y="total_bill", palette="colorblind", ax=ax)

# Define pairs to compare
pairs = [("Thur", "Fri"), ("Thur", "Sat"), ("Fri", "Sun")]

annotator = Annotator(ax, pairs, data=df, x="day", y="total_bill")
annotator.configure(
    test="Mann-Whitney",      # "t-test_ind" | "Mann-Whitney" | "Kruskal" | "Wilcoxon"
    text_format="star",       # "star" (*,**,***) | "simple" (p=0.03) | "full"
    loc="outside",            # "inside" | "outside"
    verbose=False
)
annotator.apply_and_annotate()

ax.set_title("Tips by Day with Significance Brackets")
ax.set_xlabel("Day of Week")
ax.set_ylabel("Total Bill ($)")
plt.tight_layout()
```

### Manual p-value annotation without statannotations

```python
def add_significance_bracket(ax, x1, x2, y, h, p_val):
    """Draw a significance bracket between positions x1 and x2."""
    if p_val < 0.001:
        sig = "***"
    elif p_val < 0.01:
        sig = "**"
    elif p_val < 0.05:
        sig = "*"
    else:
        sig = "ns"

    ax.plot([x1, x1, x2, x2], [y, y+h, y+h, y], lw=1.2, color="black")
    ax.text((x1+x2)/2, y+h, sig, ha="center", va="bottom", fontsize=12)

# Usage:
add_significance_bracket(ax, 0, 1, y=25, h=0.5, p_val=0.003)
```

---

## 7. Distribution Comparison

### QQ Plot

```python
import scipy.stats as stats
import matplotlib.pyplot as plt
import numpy as np

# Test if data is normally distributed
data = np.random.lognormal(0, 0.5, 200)

fig, axes = plt.subplots(1, 2, figsize=(12, 5))

# Against normal distribution
(osm, osr), (slope, intercept, r) = stats.probplot(data, dist="norm")
axes[0].plot(osm, osr, "o", alpha=0.6, markersize=4, color="steelblue")
axes[0].plot(osm, slope*np.array(osm) + intercept, "r-", lw=2, label=f"R²={r**2:.3f}")
axes[0].set_xlabel("Theoretical Quantiles")
axes[0].set_ylabel("Sample Quantiles")
axes[0].set_title("Q-Q Plot vs Normal")
axes[0].legend()
axes[0].grid(True, alpha=0.3)

# Against lognormal
(osm, osr), (slope, intercept, r) = stats.probplot(np.log(data), dist="norm")
axes[1].plot(osm, osr, "o", alpha=0.6, markersize=4, color="coral")
axes[1].plot(osm, slope*np.array(osm) + intercept, "r-", lw=2, label=f"R²={r**2:.3f}")
axes[1].set_xlabel("Theoretical Quantiles (log scale)")
axes[1].set_ylabel("Sample Quantiles (log)")
axes[1].set_title("Q-Q Plot vs Lognormal")
axes[1].legend()
axes[1].grid(True, alpha=0.3)

plt.suptitle("Distribution Fit Assessment", fontsize=14, y=1.02)
plt.tight_layout()
```

### Empirical CDF

```python
import numpy as np
import matplotlib.pyplot as plt

groups = {
    "Control": np.random.normal(50, 10, 100),
    "Treatment A": np.random.normal(55, 8, 100),
    "Treatment B": np.random.normal(60, 12, 100)
}

fig, ax = plt.subplots(figsize=(9, 6))
colors = ["steelblue", "coral", "green"]

for (name, data), color in zip(groups.items(), colors):
    sorted_data = np.sort(data)
    cdf = np.arange(1, len(sorted_data)+1) / len(sorted_data)
    ax.plot(sorted_data, cdf, lw=2.5, label=name, color=color)

ax.set_xlabel("Value", fontsize=12)
ax.set_ylabel("Cumulative Probability", fontsize=12)
ax.set_title("Empirical CDF Comparison", fontsize=14)
ax.legend(fontsize=11)
ax.grid(True, alpha=0.3)
ax.axhline(0.5, color="gray", linestyle="--", alpha=0.5, label="Median (50th pct)")
plt.tight_layout()
```

---

## 8. Kaplan-Meier Survival Plot

```python
# pip install lifelines
from lifelines import KaplanMeierFitter
from lifelines.statistics import logrank_test
import matplotlib.pyplot as plt
import numpy as np

np.random.seed(42)
n = 100
# Simulate two groups
T_a = np.random.exponential(scale=20, size=n)
E_a = np.random.binomial(1, 0.8, size=n)  # 1 = event occurred
T_b = np.random.exponential(scale=30, size=n)
E_b = np.random.binomial(1, 0.6, size=n)

fig, ax = plt.subplots(figsize=(10, 6))

kmf_a = KaplanMeierFitter()
kmf_a.fit(T_a, E_a, label="Treatment A")
kmf_a.plot_survival_function(ax=ax, ci_show=True, color="steelblue")

kmf_b = KaplanMeierFitter()
kmf_b.fit(T_b, E_b, label="Treatment B")
kmf_b.plot_survival_function(ax=ax, ci_show=True, color="coral")

# Log-rank test
results = logrank_test(T_a, T_b, E_a, E_b)
ax.text(0.7, 0.9, f"Log-rank p = {results.p_value:.3f}",
        transform=ax.transAxes, fontsize=11,
        bbox=dict(boxstyle="round", facecolor="white", alpha=0.8))

ax.set_xlabel("Time (days)", fontsize=13)
ax.set_ylabel("Survival Probability", fontsize=13)
ax.set_title("Kaplan-Meier Survival Curves", fontsize=15)
ax.set_ylim(0, 1.05)
ax.grid(True, alpha=0.3)
plt.tight_layout()
```

---

## 9. Bland-Altman Plot — Method Comparison

Used to compare two measurement methods. Shows agreement and systematic bias.

```python
import numpy as np
import matplotlib.pyplot as plt

np.random.seed(42)
method_a = np.random.normal(100, 15, 50)
method_b = method_a + np.random.normal(2, 5, 50)  # slight bias + noise

mean_vals = (method_a + method_b) / 2
diff_vals = method_a - method_b

mean_diff = np.mean(diff_vals)
std_diff  = np.std(diff_vals, ddof=1)
loa_upper = mean_diff + 1.96 * std_diff
loa_lower = mean_diff - 1.96 * std_diff

fig, ax = plt.subplots(figsize=(9, 6))
ax.scatter(mean_vals, diff_vals, alpha=0.7, color="steelblue", s=40, zorder=3)

ax.axhline(mean_diff,  color="black",  lw=1.5, linestyle="-",  label=f"Bias: {mean_diff:.2f}")
ax.axhline(loa_upper, color="red",    lw=1.5, linestyle="--", label=f"+1.96 SD: {loa_upper:.2f}")
ax.axhline(loa_lower, color="red",    lw=1.5, linestyle="--", label=f"−1.96 SD: {loa_lower:.2f}")
ax.axhline(0, color="gray", lw=0.8, linestyle=":", alpha=0.5)

ax.fill_between(ax.get_xlim(), loa_lower, loa_upper, alpha=0.08, color="red")

ax.set_xlabel("Mean of Two Methods", fontsize=12)
ax.set_ylabel("Difference (A − B)", fontsize=12)
ax.set_title("Bland-Altman Plot: Method Agreement", fontsize=14)
ax.legend(loc="upper right", fontsize=10)
ax.grid(True, alpha=0.3)
plt.tight_layout()
```

---

## 10. Forest Plot — Meta-Analysis

```python
import matplotlib.pyplot as plt
import numpy as np

# Studies: name, effect size (odds ratio), lower CI, upper CI, weight
studies = [
    ("Smith 2020",   1.32, 0.95, 1.82, 4.2),
    ("Jones 2021",   0.88, 0.71, 1.09, 8.1),
    ("Lee 2021",     1.54, 1.12, 2.12, 5.7),
    ("Garcia 2022",  1.18, 0.98, 1.43, 9.3),
    ("Brown 2023",   1.41, 1.05, 1.89, 6.8),
    ("Chen 2023",    0.95, 0.77, 1.17, 7.5),
    ("Pooled",       1.20, 1.08, 1.34, None),  # meta-analysis result
]

fig, ax = plt.subplots(figsize=(10, 7))
y_pos = list(range(len(studies)))

for i, (name, es, lo, hi, weight) in enumerate(studies):
    is_pooled = name == "Pooled"
    size = 200 if is_pooled else 60 + (weight or 0) * 8
    color = "black" if is_pooled else "steelblue"
    marker = "D" if is_pooled else "s"

    ax.plot([lo, hi], [i, i], color=color, lw=2 if is_pooled else 1.2, zorder=2)
    ax.scatter([es], [i], s=size, color=color, marker=marker, zorder=3)

    # Labels
    ax.text(-0.1, i, name, ha="right", va="center", fontsize=10,
            fontweight="bold" if is_pooled else "normal")
    ax.text(3.2, i, f"{es:.2f} [{lo:.2f}–{hi:.2f}]",
            ha="left", va="center", fontsize=9)

ax.axvline(x=1.0, color="gray", lw=1, linestyle="--", alpha=0.7)
ax.axhline(y=len(studies)-1.5, color="black", lw=0.8, alpha=0.5)  # separator before pooled

ax.set_xlabel("Odds Ratio (95% CI)", fontsize=12)
ax.set_xscale("log")
ax.set_xlim(0.5, 4.0)
ax.set_yticks([])
ax.set_title("Forest Plot — Meta-Analysis", fontsize=14)
ax.spines[["top", "right", "left"]].set_visible(False)
plt.tight_layout()
```

---

## 11. Publication-Ready Figure Template

```python
import matplotlib.pyplot as plt
import matplotlib as mpl

# Journal-quality settings
mpl.rcParams.update({
    "font.family": "sans-serif",
    "font.sans-serif": ["Arial", "Helvetica", "DejaVu Sans"],
    "font.size": 10,
    "axes.titlesize": 11,
    "axes.labelsize": 10,
    "xtick.labelsize": 9,
    "ytick.labelsize": 9,
    "legend.fontsize": 9,
    "figure.dpi": 150,
    "savefig.dpi": 300,
    "axes.linewidth": 0.8,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "grid.linewidth": 0.5,
    "grid.alpha": 0.4,
    "lines.linewidth": 1.5,
    "patch.linewidth": 0.5,
})

# Multi-panel figure with panel labels (A, B, C, D)
fig = plt.figure(figsize=(7.5, 6))  # Nature/Science: 7.5" wide for full page
gs = fig.add_gridspec(2, 2, hspace=0.45, wspace=0.35)

axes = [fig.add_subplot(gs[i, j]) for i in range(2) for j in range(2)]

for ax, label in zip(axes, ["A", "B", "C", "D"]):
    # Panel label in upper-left corner
    ax.text(-0.15, 1.05, label, transform=ax.transAxes,
            fontsize=14, fontweight="bold", va="top")
    ax.set_title(f"Panel {label}")

plt.savefig("figure1.pdf", bbox_inches="tight", format="pdf")
plt.savefig("figure1.png", bbox_inches="tight", dpi=300)
```
