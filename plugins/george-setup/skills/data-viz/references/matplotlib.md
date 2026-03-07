# Matplotlib Reference

Python's foundational visualization library for static, animated, and interactive plots.

## Hierarchy

1. **Figure** - Top-level container
2. **Axes** - Plotting area (one Figure can have multiple Axes)
3. **Artist** - Everything visible (lines, text, ticks)
4. **Axis** - Number line objects (x-axis, y-axis)

## Two Interfaces

### Object-Oriented (Recommended)
```python
fig, ax = plt.subplots(figsize=(10, 6))
ax.plot([1, 2, 3, 4])
ax.set_ylabel('values')
```

### pyplot (Quick exploration only)
```python
plt.plot([1, 2, 3, 4])
plt.ylabel('values')
plt.show()
```

## Subplot Layouts

### Regular Grid
```python
fig, axes = plt.subplots(2, 2, figsize=(12, 10))
axes[0, 0].plot(x, y1)
axes[0, 1].scatter(x, y2)
```

### Mosaic (Flexible naming)
```python
fig, axes = plt.subplot_mosaic([['left', 'right_top'],
                                 ['left', 'right_bottom']],
                                figsize=(10, 8))
axes['left'].plot(x, y)
```

### GridSpec (Maximum control)
```python
from matplotlib.gridspec import GridSpec
fig = plt.figure(figsize=(12, 8))
gs = GridSpec(3, 3, figure=fig)
ax1 = fig.add_subplot(gs[0, :])    # Top row, all columns
ax2 = fig.add_subplot(gs[1:, 0])   # Bottom rows, first column
ax3 = fig.add_subplot(gs[1:, 1:])  # Bottom rows, last columns
```

## Plot Types

**Line**: `ax.plot(x, y, linewidth=2, linestyle='--', marker='o', color='blue')`
**Scatter**: `ax.scatter(x, y, s=sizes, c=colors, alpha=0.6, cmap='viridis')`
**Bar**: `ax.bar(categories, values, color='steelblue', edgecolor='black')`
**Horizontal bar**: `ax.barh(categories, values)`
**Histogram**: `ax.hist(data, bins=30, edgecolor='black', alpha=0.7)`
**Heatmap**: `im = ax.imshow(matrix, cmap='coolwarm', aspect='auto'); plt.colorbar(im, ax=ax)`
**Contour**: `contour = ax.contour(X, Y, Z, levels=10); ax.clabel(contour, inline=True)`
**Box**: `ax.boxplot([data1, data2], labels=['A', 'B'])`
**Violin**: `ax.violinplot([data1, data2], positions=[1, 2])`

## Styling

### Colors
- Named: `'red'`, `'steelblue'`
- Hex: `'#FF5733'`
- RGB tuple: `(0.1, 0.2, 0.3)`
- Colormaps: `cmap='viridis'`

### Style Sheets
```python
plt.style.use('seaborn-v0_8-darkgrid')
print(plt.style.available)  # List all
```

### rcParams
```python
plt.rcParams['font.size'] = 12
plt.rcParams['axes.labelsize'] = 14
plt.rcParams['axes.titlesize'] = 16
```

### Annotations
```python
ax.text(x, y, 'label', fontsize=12, ha='center')
ax.annotate('point', xy=(x, y), xytext=(x+1, y+1),
            arrowprops=dict(arrowstyle='->', color='red'))
```

## Saving

```python
plt.savefig('fig.png', dpi=300, bbox_inches='tight', facecolor='white')
plt.savefig('fig.pdf', bbox_inches='tight')       # Vector
plt.savefig('fig.svg', bbox_inches='tight')       # Vector
plt.savefig('fig.png', transparent=True)          # Transparent bg
```

## 3D Plots

```python
from mpl_toolkits.mplot3d import Axes3D
fig = plt.figure(figsize=(10, 8))
ax = fig.add_subplot(111, projection='3d')
ax.plot_surface(X, Y, Z, cmap='viridis')
ax.scatter(x, y, z, c=colors, marker='o')
```

## Best Practices

1. Use OO interface for production code
2. Set `constrained_layout=True` to prevent overlapping
3. Close figures with `plt.close(fig)` to avoid memory leaks
4. Use `rasterized=True` for large datasets to reduce file size
5. Avoid `jet` colormap; prefer `viridis` or `cividis` for accessibility
6. DPI: 300 for print, 150 for web, 72 for screen
7. `figsize` is in inches: `pixels = dpi * inches`

## Common Gotchas

- Overlapping elements: use `constrained_layout=True`
- State confusion: always use OO interface
- Memory leaks: close figures explicitly
- Font warnings: set `plt.rcParams['font.sans-serif']`

## Integration

- **NumPy/Pandas**: Direct plotting from arrays and DataFrames
- **Seaborn**: High-level statistical viz built on matplotlib
- **Jupyter**: `%matplotlib inline` or `%matplotlib widget`
- **GUI**: Embedding in Tkinter, Qt, wxPython
