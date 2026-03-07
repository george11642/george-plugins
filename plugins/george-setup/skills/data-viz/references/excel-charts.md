# Excel Charts Reference

Creating charts, pivot tables, conditional formatting, and data validation in Excel using openpyxl and pandas.

## Library Setup

```python
import pandas as pd
from openpyxl import Workbook, load_workbook
from openpyxl.chart import BarChart, LineChart, PieChart, ScatterChart, AreaChart, Reference
from openpyxl.chart.series import DataPoint
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side, numbers
from openpyxl.formatting.rule import ColorScaleRule, DataBarRule, CellIsRule, FormulaRule
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
```

---

## Chart Types

### Column Chart (Vertical Bars)

```python
from openpyxl.chart import BarChart, Reference

chart = BarChart()
chart.type = "col"           # "col" for vertical, "bar" for horizontal
chart.grouping = "clustered"  # "clustered", "stacked", "percentStacked"
chart.title = "Revenue by Quarter"
chart.y_axis.title = "Revenue ($mm)"
chart.x_axis.title = "Quarter"

data = Reference(ws, min_col=2, max_col=4, min_row=1, max_row=10)
cats = Reference(ws, min_col=1, min_row=2, max_row=10)

chart.add_data(data, titles_from_data=True)
chart.set_categories(cats)
chart.shape = 4
chart.width = 20
chart.height = 15

ws.add_chart(chart, "A12")
```

### Bar Chart (Horizontal)

```python
chart = BarChart()
chart.type = "bar"           # horizontal orientation
chart.grouping = "stacked"
chart.title = "Market Share by Segment"
chart.style = 10

data = Reference(ws, min_col=2, max_col=2, min_row=1, max_row=8)
cats = Reference(ws, min_col=1, min_row=2, max_row=8)
chart.add_data(data, titles_from_data=True)
chart.set_categories(cats)
ws.add_chart(chart, "D2")
```

### Line Chart

```python
from openpyxl.chart import LineChart

chart = LineChart()
chart.title = "Monthly Trend"
chart.style = 10
chart.y_axis.title = "Value"
chart.x_axis.title = "Month"
chart.y_axis.crossAx = 500
chart.x_axis.crossAx = 500

data = Reference(ws, min_col=2, max_col=4, min_row=1, max_row=13)
chart.add_data(data, titles_from_data=True)
chart.set_categories(Reference(ws, min_col=1, min_row=2, max_row=13))

# Line style per series
for s in chart.series:
    s.graphicalProperties.line.width = 25400  # in EMU (1pt = 12700)
    s.smooth = True  # smooth curve

ws.add_chart(chart, "F2")
```

### Pie Chart

```python
from openpyxl.chart import PieChart, ProjectedPieChart
from openpyxl.chart.series import DataPoint

chart = PieChart()
labels = Reference(ws, min_col=1, min_row=2, max_row=7)
data = Reference(ws, min_col=2, min_row=1, max_row=7)
chart.add_data(data, titles_from_data=True)
chart.set_categories(labels)
chart.title = "Segment Breakdown"

# Explode the first slice
slice_style = DataPoint(idx=0, explosion=20)
chart.series[0].data_points = [slice_style]

ws.add_chart(chart, "A10")
```

### Scatter Chart

```python
from openpyxl.chart import ScatterChart
from openpyxl.chart import Reference, Series

chart = ScatterChart()
chart.title = "Revenue vs. Headcount"
chart.style = 13
chart.x_axis.title = "Headcount"
chart.y_axis.title = "Revenue ($mm)"

xvalues = Reference(ws, min_col=1, min_row=2, max_row=20)
yvalues = Reference(ws, min_col=2, min_row=2, max_row=20)
series = Series(yvalues, xvalues, title="Companies")
series.marker.symbol = "circle"
series.marker.size = 7
series.graphicalProperties.line.noFill = True  # points only, no line
chart.series.append(series)

ws.add_chart(chart, "D2")
```

### Area Chart

```python
from openpyxl.chart import AreaChart

chart = AreaChart()
chart.title = "Cumulative Revenue"
chart.style = 10
chart.grouping = "stacked"  # or "percentStacked"

data = Reference(ws, min_col=2, max_col=4, min_row=1, max_row=13)
chart.add_data(data, titles_from_data=True)
chart.set_categories(Reference(ws, min_col=1, min_row=2, max_row=13))
ws.add_chart(chart, "A16")
```

### Stock Chart (OHLC/Candlestick)

```python
from openpyxl.chart import StockChart

# Requires data in order: Open, High, Low, Close
chart = StockChart()
labels = Reference(ws, min_col=1, min_row=2, max_row=20)
data = Reference(ws, min_col=2, max_col=5, min_row=1, max_row=20)
chart.add_data(data, titles_from_data=True)
chart.set_categories(labels)

# Candlestick style
from openpyxl.chart.updown_bars import UpDownBars
chart.upDownBars = UpDownBars()
chart.hiLowLines = True

ws.add_chart(chart, "H2")
```

### Combo Chart (Bar + Line)

```python
from openpyxl.chart import BarChart, LineChart
from openpyxl.chart.chartspace import ChartContainer
from copy import deepcopy

# Primary: bar chart for revenue
bar = BarChart()
bar.type = "col"
bar.grouping = "clustered"
bar_data = Reference(ws, min_col=2, max_col=2, min_row=1, max_row=9)
bar.add_data(bar_data, titles_from_data=True)

# Secondary: line chart for margin
line = LineChart()
line_data = Reference(ws, min_col=3, max_col=3, min_row=1, max_row=9)
line.add_data(line_data, titles_from_data=True)

# Set line series to use secondary y-axis
line.y_axis.axId = 200
line.y_axis.crosses = "max"
line.y_axis.title = "Margin (%)"

bar += line  # merge line into bar
bar.set_categories(Reference(ws, min_col=1, min_row=2, max_row=9))
bar.title = "Revenue & Margin"
ws.add_chart(bar, "E2")
```

---

## Pivot Tables with openpyxl

openpyxl does not generate true Excel PivotTables (they require cached data from Excel engine). Use pandas to create pivot DataFrames, then write to Excel with formatting to create pivot-like summary sheets.

### pandas → Pivot → Excel

```python
import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment

df = pd.read_excel('data.xlsx')

# Create pivot
pivot = df.pivot_table(
    values='Revenue',
    index='Region',
    columns='Quarter',
    aggfunc='sum',
    margins=True,
    margins_name='Total'
)

# Write to Excel
wb = Workbook()
ws = wb.active
ws.title = "Pivot Summary"

# Header row styling
header_fill = PatternFill("solid", fgColor="1a2332")
header_font = Font(color="FFFFFF", bold=True)

# Write column headers
ws.cell(1, 1, "Region")
for col_idx, col_name in enumerate(pivot.columns, start=2):
    cell = ws.cell(1, col_idx, str(col_name))
    cell.fill = header_fill
    cell.font = header_font
    cell.alignment = Alignment(horizontal='center')

# Write data rows
for row_idx, (row_label, row_data) in enumerate(pivot.iterrows(), start=2):
    ws.cell(row_idx, 1, row_label).font = Font(bold=(row_label == 'Total'))
    for col_idx, val in enumerate(row_data, start=2):
        cell = ws.cell(row_idx, col_idx, val if pd.notna(val) else 0)
        cell.number_format = '$#,##0;($#,##0);-'

wb.save('pivot_summary.xlsx')
```

### Adding a Chart to a Pivot Sheet

After writing the pivot data to a sheet, create a chart referencing those cells:

```python
chart = BarChart()
chart.type = "col"
chart.title = "Revenue by Region and Quarter"

# Reference the pivot data (excluding Total row/col)
data = Reference(ws, min_col=2, max_col=5, min_row=1, max_row=6)
cats = Reference(ws, min_col=1, min_row=2, max_row=6)
chart.add_data(data, titles_from_data=True)
chart.set_categories(cats)
chart.width = 24
chart.height = 16

ws.add_chart(chart, "A10")
```

---

## Dynamic Named Ranges

Named ranges allow charts and formulas to reference by name rather than cell address, making them auto-updateable when data grows.

```python
from openpyxl.workbook.defined_name import DefinedName
from openpyxl.utils import quote_sheetname, absolute_coordinate

# Define a named range for a data column
ws_name = quote_sheetname(ws.title)
ref = f"{ws_name}!$B$2:$B$100"
wb.defined_names["RevenueData"] = DefinedName("RevenueData", attr_text=ref)

# Dynamic range using OFFSET (written as Excel formula in a cell)
# Put in a helper cell: =OFFSET($B$2,0,0,COUNTA($B:$B)-1,1)
# Then name that cell reference
ws["H1"] = "=OFFSET($B$2,0,0,COUNTA($B:$B)-1,1)"

# Reference a named range from a chart
data = Reference(ws, min_col=2, max_col=2, min_row=2, max_row=50)
chart.add_data(data)
```

For truly dynamic charts that auto-expand as rows are added:
1. Convert the data range to an Excel Table (ListObject) — openpyxl has limited Table support; use xlsxwriter or create the table in a template.
2. Reference the table column in the chart: the table auto-expands.

---

## Conditional Formatting (Heatmap-Style)

### Color Scale (Heatmap)

```python
from openpyxl.formatting.rule import ColorScaleRule

# 3-color scale: red → yellow → green
rule = ColorScaleRule(
    start_type='min', start_color='FF0000',
    mid_type='percentile', mid_value=50, mid_color='FFFF00',
    end_type='max', end_color='00FF00'
)
ws.conditional_formatting.add('B2:M20', rule)

# 2-color scale: white → blue
rule2 = ColorScaleRule(
    start_type='min', start_color='FFFFFF',
    end_type='max', end_color='0066CC'
)
ws.conditional_formatting.add('B2:M20', rule2)
```

### Data Bars

```python
from openpyxl.formatting.rule import DataBarRule

rule = DataBarRule(
    start_type='min', start_value=None, start_color='638EC6',
    end_type='max', end_value=None, end_color='638EC6',
    showValue=True
)
ws.conditional_formatting.add('C2:C30', rule)
```

### Cell Value Rules

```python
from openpyxl.formatting.rule import CellIsRule
from openpyxl.styles import PatternFill, Font

# Red fill for negative values
neg_fill = PatternFill(start_color='FFCCCC', end_color='FFCCCC', fill_type='solid')
neg_font = Font(color='9C0006')
ws.conditional_formatting.add(
    'D2:D50',
    CellIsRule(operator='lessThan', formula=['0'], fill=neg_fill, font=neg_font)
)

# Green fill for values above target
pos_fill = PatternFill(start_color='CCFFCC', end_color='CCFFCC', fill_type='solid')
ws.conditional_formatting.add(
    'D2:D50',
    CellIsRule(operator='greaterThan', formula=['100000'], fill=pos_fill)
)
```

### Formula-Based Rules

```python
from openpyxl.formatting.rule import FormulaRule

# Highlight entire row if column A = "Overdue"
overdue_fill = PatternFill(start_color='FFE0E0', end_color='FFE0E0', fill_type='solid')
ws.conditional_formatting.add(
    'A2:F50',
    FormulaRule(formula=['$A2="Overdue"'], fill=overdue_fill)
)
```

---

## Data Validation Dropdowns

Interactive dropdowns allow users to select from a list, making dashboards self-contained.

```python
from openpyxl.worksheet.datavalidation import DataValidation

# Simple dropdown from a list
dv = DataValidation(
    type="list",
    formula1='"Q1,Q2,Q3,Q4"',   # comma-separated, in quotes
    allow_blank=True,
    showDropDown=False,  # False = show the arrow
    showErrorMessage=True,
    errorTitle="Invalid Input",
    error="Please select a valid quarter.",
    showInputMessage=True,
    promptTitle="Quarter",
    prompt="Select a quarter from the dropdown."
)
ws.add_data_validation(dv)
dv.add('B1')  # or dv.sqref = 'B1:B1'

# Dropdown referencing a range on another sheet
dv2 = DataValidation(
    type="list",
    formula1="'Reference'!$A$2:$A$20",
    allow_blank=True
)
ws.add_data_validation(dv2)
dv2.sqref = "C2:C100"

# Number validation
num_dv = DataValidation(
    type="decimal",
    operator="between",
    formula1="0",
    formula2="1",
    showErrorMessage=True,
    errorTitle="Out of Range",
    error="Please enter a value between 0 and 1."
)
ws.add_data_validation(num_dv)
num_dv.add('D2:D50')
```

---

## Color Coding Standards

Industry-standard financial model color conventions (apply via `Font` color):

| Cell Type | Color | RGB | Hex |
|-----------|-------|-----|-----|
| Hardcoded input | Blue | (0, 0, 255) | `0000FF` |
| Formula / calculation | Black | (0, 0, 0) | `000000` |
| Cross-sheet link | Green | (0, 128, 0) | `008000` |
| External file link | Red | (255, 0, 0) | `FF0000` |
| Key assumption | Yellow bg | (255, 255, 0) | `FFFF00` |

```python
from openpyxl.styles import Font, PatternFill

def apply_cell_color(cell, cell_type):
    colors = {
        'input':    {'font': '0000FF'},
        'formula':  {'font': '000000'},
        'cross_sheet': {'font': '008000'},
        'external': {'font': 'FF0000'},
        'assumption': {'fill': 'FFFF00'},
    }
    c = colors.get(cell_type, {})
    if 'font' in c:
        cell.font = Font(color=c['font'])
    if 'fill' in c:
        cell.fill = PatternFill("solid", fgColor=c['fill'])
```

---

## Number Formatting Standards

```python
# Apply to cell.number_format
FORMAT_CURRENCY_MM    = '$#,##0;($#,##0);-'        # $ millions, zeros as dash
FORMAT_CURRENCY_K     = '$#,##0.0;($#,##0.0);-'    # $ thousands
FORMAT_PERCENT_1DP    = '0.0%;(0.0%);-'             # percentages, 1 decimal
FORMAT_MULTIPLE       = '0.0x'                       # EV/EBITDA multiples
FORMAT_YEAR           = '@'                          # years as text
FORMAT_INT_COMMA      = '#,##0'                      # integers with comma
FORMAT_NEG_PAREN      = '#,##0;(#,##0)'             # negatives in parens

# Usage
cell.number_format = FORMAT_CURRENCY_MM
cell.number_format = '0.0%'   # inline
```

---

## pandas → Excel Chart Pipeline

Full end-to-end workflow: query data with pandas, build formatted Excel file with openpyxl chart, recalculate.

```python
import pandas as pd
from openpyxl import Workbook
from openpyxl.chart import BarChart, LineChart, Reference
from openpyxl.styles import Font, PatternFill, Alignment
import subprocess

def dataframe_to_chart_excel(df: pd.DataFrame, output_path: str, title: str):
    wb = Workbook()
    ws = wb.active
    ws.title = "Data"

    # --- Write headers ---
    for col_idx, col_name in enumerate(df.columns, start=1):
        cell = ws.cell(1, col_idx, col_name)
        cell.font = Font(bold=True, color='FFFFFF')
        cell.fill = PatternFill("solid", fgColor="1a2332")
        cell.alignment = Alignment(horizontal='center')

    # --- Write data ---
    for row_idx, row in enumerate(df.itertuples(index=False), start=2):
        for col_idx, val in enumerate(row, start=1):
            ws.cell(row_idx, col_idx, val)

    # --- Auto column widths ---
    for col in ws.columns:
        max_len = max(len(str(cell.value or '')) for cell in col)
        ws.column_dimensions[get_column_letter(col[0].column)].width = min(max_len + 2, 40)

    # --- Create chart ---
    n_rows = len(df) + 1
    n_cols = len(df.columns)

    chart = BarChart()
    chart.type = "col"
    chart.title = title
    chart.width = 20
    chart.height = 15
    chart.add_data(Reference(ws, min_col=2, max_col=n_cols, min_row=1, max_row=n_rows), titles_from_data=True)
    chart.set_categories(Reference(ws, min_col=1, min_row=2, max_row=n_rows))
    ws.add_chart(chart, f"A{n_rows + 3}")

    wb.save(output_path)

    # --- Recalculate formulas ---
    result = subprocess.run(['python', 'recalc.py', output_path], capture_output=True, text=True)
    import json
    status = json.loads(result.stdout)
    if status.get('status') == 'errors_found':
        raise ValueError(f"Formula errors: {status['error_summary']}")

    return output_path
```

---

## Common Chart Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| Chart shows wrong series | `titles_from_data=True` but row 1 has no headers | Ensure header row exists at `min_row=1` |
| X-axis shows numbers not labels | Categories not set | Call `chart.set_categories(Reference(...))` |
| Pie chart has no labels | Labels referenced by row instead of column | Swap min/max row for column Reference |
| `AttributeError: NoneType` on chart add | `ws.add_chart` before defining chart dimensions | Set `chart.width` and `chart.height` before `add_chart` |
| #REF! after save | Cell references shifted by row/col insert | Use absolute references `$A$1` in formulas |
| #DIV/0! | Denominator cell empty or zero | Wrap formula: `=IFERROR(A1/B1, "-")` |
| #VALUE! | Text in numeric formula | Check source cells; use `=ISNUMBER()` validation |
| #NAME? | Typo in function name | Check formula string spelling |
| Chart is blank after openpyxl save | No Excel recalculation run | Run `recalc.py` to force formula recalc |
| Stacked bar wrong order | Series order reversed from data | Reverse `min_col`/`max_col` range in Reference |

### IFERROR Wrapper Pattern

Always wrap division or lookup formulas defensively:

```python
ws['C5'] = '=IFERROR(B5/B4-1, "-")'    # growth rate, safe
ws['D5'] = '=IFERROR(VLOOKUP(A5,Ref!$A:$B,2,0), "")'  # vlookup, safe
```

### recalc.py Error Handling Pattern

```python
import subprocess, json

def recalc_and_check(path: str):
    result = subprocess.run(['python', 'recalc.py', path, '60'],
                            capture_output=True, text=True, timeout=90)
    data = json.loads(result.stdout)
    if data['status'] == 'errors_found':
        for err_type, info in data['error_summary'].items():
            print(f"  {err_type}: {info['count']} at {info['locations'][:3]}")
        raise RuntimeError("Excel contains formula errors. Fix before delivering.")
    print(f"  OK: {data['total_formulas']} formulas, 0 errors.")
```
