# File Processing: PDF, Excel, and Word Automation

Python patterns for reading, writing, and transforming PDF, Excel (.xlsx), and Word (.docx) files.

---

## PDF Processing

### Library Selection

| Need | Library |
|------|---------|
| Merge, split, rotate, password | `pypdf` |
| Text/table extraction with layout | `pdfplumber` |
| Create PDFs from scratch | `reportlab` |
| OCR scanned PDFs | `pytesseract` + `pdf2image` |
| Command-line operations | `qpdf`, `pdftotext`, `pdfimages` |

Install: `uv add pypdf pdfplumber reportlab pdf2image pytesseract`

---

### pypdf — Basic Operations

#### Merge PDFs
```python
from pypdf import PdfReader, PdfWriter

def merge_pdfs(paths: list[str], output: str) -> None:
    writer = PdfWriter()
    for path in paths:
        reader = PdfReader(path)
        for page in reader.pages:
            writer.add_page(page)
    with open(output, "wb") as f:
        writer.write(f)

merge_pdfs(["doc1.pdf", "doc2.pdf", "doc3.pdf"], "merged.pdf")
```

#### Split PDF (one page per file)
```python
from pypdf import PdfReader, PdfWriter
from pathlib import Path

def split_pdf(input_path: str, output_dir: str) -> list[str]:
    reader = PdfReader(input_path)
    out_dir = Path(output_dir)
    out_dir.mkdir(exist_ok=True)
    outputs = []
    for i, page in enumerate(reader.pages):
        writer = PdfWriter()
        writer.add_page(page)
        out_path = str(out_dir / f"page_{i + 1:04d}.pdf")
        with open(out_path, "wb") as f:
            writer.write(f)
        outputs.append(out_path)
    return outputs
```

#### Split PDF by page range
```python
def extract_pages(input_path: str, start: int, end: int, output_path: str) -> None:
    """Extract pages start..end (1-indexed, inclusive)."""
    reader = PdfReader(input_path)
    writer = PdfWriter()
    for i in range(start - 1, min(end, len(reader.pages))):
        writer.add_page(reader.pages[i])
    with open(output_path, "wb") as f:
        writer.write(f)
```

#### Rotate pages
```python
from pypdf import PdfReader, PdfWriter

reader = PdfReader("input.pdf")
writer = PdfWriter()
for page in reader.pages:
    page.rotate(90)  # 90, 180, or 270 degrees clockwise
    writer.add_page(page)
with open("rotated.pdf", "wb") as f:
    writer.write(f)
```

#### Extract metadata
```python
from pypdf import PdfReader

reader = PdfReader("document.pdf")
meta = reader.metadata
print(f"Title:   {meta.title}")
print(f"Author:  {meta.author}")
print(f"Subject: {meta.subject}")
print(f"Creator: {meta.creator}")
print(f"Pages:   {len(reader.pages)}")
```

#### Password protection
```python
from pypdf import PdfReader, PdfWriter

# Encrypt
def encrypt_pdf(input_path: str, output_path: str, user_pw: str, owner_pw: str) -> None:
    reader = PdfReader(input_path)
    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)
    writer.encrypt(user_pw, owner_pw)
    with open(output_path, "wb") as f:
        writer.write(f)

# Decrypt
def decrypt_pdf(input_path: str, output_path: str, password: str) -> None:
    reader = PdfReader(input_path)
    reader.decrypt(password)
    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)
    with open(output_path, "wb") as f:
        writer.write(f)
```

#### Add watermark
```python
from pypdf import PdfReader, PdfWriter

def watermark_pdf(input_path: str, watermark_path: str, output_path: str) -> None:
    watermark_page = PdfReader(watermark_path).pages[0]
    reader = PdfReader(input_path)
    writer = PdfWriter()
    for page in reader.pages:
        page.merge_page(watermark_page)
        writer.add_page(page)
    with open(output_path, "wb") as f:
        writer.write(f)
```

---

### pdfplumber — Text and Table Extraction

pdfplumber gives precise control over text coordinates and table detection. Prefer it over pypdf for any extraction task.

#### Extract text (preserving layout)
```python
import pdfplumber

def extract_text(pdf_path: str) -> str:
    pages = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text()
            if text:
                pages.append(text)
    return "\n\n".join(pages)
```

#### Extract text with coordinates (bounding boxes)
```python
with pdfplumber.open("document.pdf") as pdf:
    page = pdf.pages[0]
    words = page.extract_words()  # list of dicts with x0, y0, x1, y1, text
    for word in words:
        print(f"{word['text']} at ({word['x0']:.1f}, {word['top']:.1f})")
```

#### Extract tables → pandas DataFrame
```python
import pdfplumber
import pandas as pd

def extract_tables(pdf_path: str) -> list[pd.DataFrame]:
    """Extract all tables from a PDF as DataFrames."""
    results = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            tables = page.extract_tables()
            for table in tables:
                if not table:
                    continue
                # First row as header
                df = pd.DataFrame(table[1:], columns=table[0])
                results.append(df)
    return results

# Combine all tables into one DataFrame
dfs = extract_tables("report.pdf")
combined = pd.concat(dfs, ignore_index=True)
combined.to_excel("extracted.xlsx", index=False)
```

#### Fine-tune table detection
```python
with pdfplumber.open("document.pdf") as pdf:
    page = pdf.pages[0]
    # Adjust snap_tolerance and join_tolerance for imperfect tables
    tables = page.extract_tables({
        "vertical_strategy": "lines",
        "horizontal_strategy": "lines",
        "snap_tolerance": 3,
        "join_tolerance": 3,
        "edge_min_length": 3,
    })
```

#### Extract from a specific region
```python
with pdfplumber.open("document.pdf") as pdf:
    page = pdf.pages[0]
    # Crop to bounding box (x0, top, x1, bottom) in PDF points
    cropped = page.crop((50, 100, 550, 400))
    text = cropped.extract_text()
```

---

### reportlab — Create PDFs from Scratch

#### Simple canvas (low-level)
```python
from reportlab.lib.pagesizes import letter, A4
from reportlab.pdfgen import canvas

def create_simple_pdf(output_path: str) -> None:
    c = canvas.Canvas(output_path, pagesize=letter)
    width, height = letter  # 612 x 792 points

    # Text
    c.setFont("Helvetica-Bold", 18)
    c.drawString(72, height - 72, "Report Title")

    c.setFont("Helvetica", 11)
    c.drawString(72, height - 100, "Body text goes here.")

    # Horizontal rule
    c.setLineWidth(1)
    c.line(72, height - 110, width - 72, height - 110)

    # Rectangle
    c.rect(72, 200, 200, 100, stroke=1, fill=0)

    c.save()
```

#### Platypus (high-level flow layout)
```python
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image
)

def build_report(output_path: str, data: list[dict]) -> None:
    doc = SimpleDocTemplate(
        output_path,
        pagesize=letter,
        leftMargin=inch,
        rightMargin=inch,
        topMargin=inch,
        bottomMargin=inch,
    )
    styles = getSampleStyleSheet()
    story = []

    # Title
    story.append(Paragraph("Quarterly Report", styles["Title"]))
    story.append(Spacer(1, 0.25 * inch))

    # Body paragraph
    story.append(Paragraph(
        "This report summarizes Q4 results across all regions.",
        styles["Normal"],
    ))
    story.append(Spacer(1, 0.2 * inch))

    # Table
    table_data = [["Region", "Revenue", "Growth"]]
    for row in data:
        table_data.append([row["region"], f"${row['revenue']:,.0f}", f"{row['growth']:.1%}"])

    table = Table(table_data, colWidths=[2 * inch, 2 * inch, 2 * inch])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#003366")),
        ("TEXTCOLOR",  (0, 0), (-1, 0), colors.white),
        ("FONTNAME",   (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE",   (0, 0), (-1, 0), 10),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F0F4F8")]),
        ("GRID",       (0, 0), (-1, -1), 0.5, colors.grey),
        ("ALIGN",      (1, 0), (-1, -1), "RIGHT"),
    ]))
    story.append(table)
    story.append(PageBreak())

    # Page 2
    story.append(Paragraph("Appendix", styles["Heading1"]))

    doc.build(story)
```

#### Custom page template with header/footer
```python
from reportlab.platypus import BaseDocTemplate, Frame, PageTemplate
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch

def header_footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 9)
    canvas.drawString(inch, 0.5 * inch, f"Page {doc.page}")
    canvas.drawRightString(letter[0] - inch, 0.5 * inch, "Confidential")
    canvas.restoreState()

doc = BaseDocTemplate("report.pdf", pagesize=letter)
frame = Frame(inch, inch, letter[0] - 2*inch, letter[1] - 2*inch)
template = PageTemplate(id="main", frames=[frame], onPage=header_footer)
doc.addPageTemplates([template])
doc.build(story)
```

---

### OCR — Scanned PDFs

```python
import pytesseract
from pdf2image import convert_from_path
from pathlib import Path

def ocr_pdf(pdf_path: str, lang: str = "eng") -> str:
    """Extract text from scanned PDF using OCR."""
    # Requires: uv add pytesseract pdf2image
    # System: sudo apt-get install tesseract-ocr poppler-utils
    images = convert_from_path(pdf_path, dpi=300)
    pages = []
    for i, image in enumerate(images):
        text = pytesseract.image_to_string(image, lang=lang)
        pages.append(f"--- Page {i + 1} ---\n{text}")
    return "\n\n".join(pages)

def ocr_pdf_to_dataframe(pdf_path: str) -> list[dict]:
    """Extract structured data (bounding boxes) via OCR."""
    import pandas as pd
    images = convert_from_path(pdf_path, dpi=200)
    results = []
    for i, image in enumerate(images):
        data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
        df = pd.DataFrame(data)
        df = df[df["text"].str.strip() != ""]
        df["page"] = i + 1
        results.append(df)
    return results
```

---

### Command-Line PDF Tools

```bash
# pdftotext (poppler-utils) — fast text extraction
pdftotext input.pdf output.txt
pdftotext -layout input.pdf output.txt   # preserve columns
pdftotext -f 1 -l 5 input.pdf -          # pages 1-5 to stdout

# pdfimages — extract embedded images
pdfimages -j input.pdf images/prefix     # JPEG output
pdfimages -png input.pdf images/prefix   # PNG output

# qpdf — merge, split, decrypt
qpdf --empty --pages doc1.pdf doc2.pdf -- merged.pdf
qpdf input.pdf --pages . 1-10 -- first10.pdf
qpdf --password=secret --decrypt locked.pdf unlocked.pdf
qpdf --rotate=+90:1 input.pdf output.pdf  # rotate page 1

# pdftoppm — render pages to images (useful for thumbnails)
pdftoppm -jpeg -r 150 document.pdf page  # creates page-1.jpg, page-2.jpg ...
```

---

### Batch Processing Pattern

```python
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor
import pdfplumber

def process_single(pdf_path: Path) -> dict:
    try:
        with pdfplumber.open(pdf_path) as pdf:
            text = " ".join(
                page.extract_text() or ""
                for page in pdf.pages
            )
        return {"path": str(pdf_path), "chars": len(text), "text": text, "error": None}
    except Exception as e:
        return {"path": str(pdf_path), "chars": 0, "text": "", "error": str(e)}

def batch_extract(directory: str, workers: int = 4) -> list[dict]:
    paths = list(Path(directory).glob("**/*.pdf"))
    with ProcessPoolExecutor(max_workers=workers) as executor:
        results = list(executor.map(process_single, paths))
    return results
```

---

## Excel / Spreadsheet Processing

### Library Selection

| Need | Library |
|------|---------|
| Data analysis, bulk read/write | `pandas` |
| Formulas, formatting, cell styling | `openpyxl` |
| Large files (read-only) | `openpyxl` with `read_only=True` |
| Large files (write-only) | `openpyxl` with `write_only=True` |

Install: `uv add pandas openpyxl`

---

### pandas — Data Analysis and I/O

```python
import pandas as pd

# Read Excel
df = pd.read_excel("file.xlsx")                          # first sheet
df = pd.read_excel("file.xlsx", sheet_name="Data")       # named sheet
all_sheets = pd.read_excel("file.xlsx", sheet_name=None) # {name: df}

# Control types at read time
df = pd.read_excel(
    "file.xlsx",
    dtype={"id": str, "code": str},   # force string cols (avoid int coercion)
    usecols=["A", "C", "E"],          # only load needed columns
    parse_dates=["date_column"],       # auto-parse date strings
    skiprows=2,                        # skip header rows
    na_values=["N/A", "—", ""],       # treat as NaN
)

# Write Excel
df.to_excel("output.xlsx", index=False)
df.to_excel("output.xlsx", sheet_name="Results", index=False)

# Multiple sheets
with pd.ExcelWriter("multi.xlsx", engine="openpyxl") as writer:
    df_summary.to_excel(writer, sheet_name="Summary", index=False)
    df_detail.to_excel(writer, sheet_name="Detail", index=False)

# Basic analysis
print(df.shape)          # (rows, cols)
print(df.dtypes)         # column types
print(df.describe())     # numeric stats
print(df.isnull().sum()) # missing values per column
```

---

### openpyxl — Formulas, Formatting, Cell Styling

#### Create a new workbook
```python
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

wb = Workbook()
ws = wb.active
ws.title = "Summary"

# Headers
headers = ["Region", "Q1", "Q2", "Q3", "Q4", "Total"]
ws.append(headers)

# Style header row
for col_idx, _ in enumerate(headers, start=1):
    cell = ws.cell(row=1, column=col_idx)
    cell.font = Font(bold=True, color="FFFFFF")
    cell.fill = PatternFill("solid", start_color="003366")
    cell.alignment = Alignment(horizontal="center")

# Data rows with formulas
data = [
    ("North", 100, 120, 130, 140),
    ("South", 90, 110, 115, 125),
]
for row_idx, row_data in enumerate(data, start=2):
    ws.append(list(row_data))
    # Total column as formula (NOT hardcoded Python sum)
    ws.cell(row=row_idx, column=6).value = f"=SUM(B{row_idx}:E{row_idx})"

# Column widths
for i, width in enumerate([12, 8, 8, 8, 8, 10], start=1):
    ws.column_dimensions[get_column_letter(i)].width = width

wb.save("output.xlsx")
```

#### Load and edit existing file (preserve formulas)
```python
from openpyxl import load_workbook

# IMPORTANT: do NOT use data_only=True if you plan to save —
# that replaces all formulas with their cached values permanently.
wb = load_workbook("existing.xlsx")
ws = wb.active  # or wb["SheetName"]

# Iterate sheets
for name in wb.sheetnames:
    sheet = wb[name]
    print(f"{name}: {sheet.max_row} rows x {sheet.max_column} cols")

# Modify specific cells
ws["B5"] = "=SUM(B2:B4)"           # formula
ws.cell(row=3, column=2).value = 42  # by coordinates (1-indexed)

# Insert / delete
ws.insert_rows(2)       # insert blank row before row 2
ws.delete_rows(5, 3)    # delete 3 rows starting at row 5
ws.insert_cols(3)       # insert blank column before col C
ws.delete_cols(4, 2)    # delete 2 columns starting at col D

# Add a new sheet
ws_new = wb.create_sheet("NewData")
ws_new["A1"] = "Header"

wb.save("modified.xlsx")
```

#### Large file handling
```python
from openpyxl import load_workbook

# Read-only mode — much lower memory for large files
wb = load_workbook("large.xlsx", read_only=True)
ws = wb.active
for row in ws.iter_rows(min_row=2, values_only=True):
    process(row)
wb.close()  # MUST close manually in read_only mode

# Write-only mode — stream rows without holding in memory
from openpyxl import Workbook
wb = Workbook(write_only=True)
ws = wb.create_sheet()
ws.append(["ID", "Name", "Value"])  # header
for record in generate_records():   # generator
    ws.append([record.id, record.name, record.value])
wb.save("streamed.xlsx")
```

---

### Financial Model Color Coding Standards

Industry-standard conventions for financial spreadsheets:

| Color | RGB | Meaning |
|-------|-----|---------|
| Blue text | `0000FF` | Hardcoded inputs (user-controlled assumptions) |
| Black text | `000000` | All formulas and calculations |
| Green text | `008000` | Cross-sheet links (same workbook) |
| Red text | `FF0000` | External file links |
| Yellow fill | `FFFF00` | Key assumptions needing attention |

```python
from openpyxl.styles import Font

# Apply color coding
def style_input_cell(cell) -> None:
    """Blue = hardcoded input."""
    cell.font = Font(color="0000FF")

def style_formula_cell(cell) -> None:
    """Black = formula (default, but explicit)."""
    cell.font = Font(color="000000")

def style_cross_sheet_cell(cell) -> None:
    """Green = pulls from another sheet."""
    cell.font = Font(color="008000")
```

---

### Formula Best Practices

Always use Excel formulas instead of computing values in Python. The spreadsheet must remain dynamic.

```python
# WRONG — hardcodes the Python-computed result
total = df["Sales"].sum()
ws["B10"] = total          # static number, breaks when data changes

# CORRECT — let Excel compute it
ws["B10"] = "=SUM(B2:B9)"  # live formula

# WRONG — Python-computed growth rate
growth = (end - start) / start
ws["C5"] = growth

# CORRECT
ws["C5"] = "=(C4-C2)/C2"

# Cross-sheet reference
ws["D1"] = "=Assumptions!B3"

# Absolute reference (doesn't shift when rows are inserted)
ws["E2"] = "=$B$1 * (1 + $B$2)"
```

---

### Formula Verification Checklist

After creating any formula-heavy file:

- [ ] Run `recalc.py output.xlsx` (uses LibreOffice headless) to evaluate all formulas
- [ ] Check `recalc.py` JSON output — `"status": "errors_found"` means broken formulas
- [ ] Verify `#REF!` — invalid cell references (often caused by deleted rows/cols)
- [ ] Verify `#DIV/0!` — add `IFERROR(formula, 0)` guard where denominators can be zero
- [ ] Verify `#VALUE!` — type mismatch (e.g., text in a numeric formula)
- [ ] Verify `#NAME?` — typo in function name
- [ ] Remember: openpyxl rows and columns are **1-indexed** (A1 = row=1, column=1)
- [ ] Remember: `data_only=True` + save = **permanent formula loss**

---

## Word / DOCX Processing

### Workflow Decision Tree

| Scenario | Approach |
|----------|----------|
| Read text content | `pandoc --track-changes=all file.docx -o output.md` |
| Create new document | python-docx or docx-js |
| Simple edit to your own document | OOXML manipulation via Document library |
| Review someone else's document | Redlining workflow (tracked changes) |
| Legal / business / academic docs | Redlining workflow (required) |

Install: `uv add python-docx` or `sudo apt-get install pandoc`

---

### python-docx — Basic Document Creation

```python
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH

doc = Document()

# Title
title = doc.add_heading("Report Title", level=0)

# Normal paragraph
p = doc.add_paragraph("This is a paragraph with ")
run = p.add_run("bold text")
run.bold = True
p.add_run(" and more text.")

# Paragraph with specific font
p2 = doc.add_paragraph()
run2 = p2.add_run("Custom styled text")
run2.font.size = Pt(14)
run2.font.color.rgb = RGBColor(0x00, 0x33, 0x66)
p2.alignment = WD_ALIGN_PARAGRAPH.CENTER

# Table
table = doc.add_table(rows=1, cols=3)
table.style = "Table Grid"
hdr = table.rows[0].cells
hdr[0].text = "Name"
hdr[1].text = "Value"
hdr[2].text = "Notes"

data = [("Alpha", "100", "First"), ("Beta", "200", "Second")]
for name, value, notes in data:
    row = table.add_row().cells
    row[0].text = name
    row[1].text = value
    row[2].text = notes

# Image
doc.add_picture("chart.png", width=Inches(5))

doc.save("report.docx")
```

---

### pandoc — Format Conversion

pandoc is the gold standard for converting between document formats. Prefer it over manual XML manipulation for format conversions.

```bash
# DOCX → Markdown (with tracked changes preserved)
pandoc --track-changes=all input.docx -o output.md

# Markdown → DOCX (with reference style)
pandoc input.md --reference-doc=template.docx -o output.docx

# DOCX → HTML
pandoc input.docx -o output.html

# DOCX → PDF (requires LaTeX or LibreOffice)
pandoc input.docx -o output.pdf

# Markdown → DOCX with custom styles
pandoc input.md \
    --reference-doc=company-template.docx \
    --toc \
    -o output.docx
```

```python
import subprocess
from pathlib import Path

def docx_to_markdown(docx_path: str, track_changes: str = "all") -> str:
    """Convert DOCX to markdown string. track_changes: all|accept|reject"""
    result = subprocess.run(
        ["pandoc", f"--track-changes={track_changes}", docx_path, "-t", "markdown"],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout

def markdown_to_docx(md_text: str, output_path: str, template: str | None = None) -> None:
    cmd = ["pandoc", "-f", "markdown", "-t", "docx", "-o", output_path]
    if template:
        cmd.extend(["--reference-doc", template])
    subprocess.run(cmd, input=md_text, text=True, check=True)
```

---

### Redlining Workflow (Tracked Changes)

Use when editing documents that belong to someone else, or for legal/business review.

```bash
# Step 1: Convert to markdown to understand the document
pandoc --track-changes=all document.docx -o current.md

# Step 2: Unpack DOCX (it's a ZIP of XML files)
python ooxml/scripts/unpack.py document.docx unpacked/

# Key XML files:
# unpacked/word/document.xml  — main body
# unpacked/word/comments.xml  — comments
# unpacked/word/media/        — embedded images

# Step 3: Find text to change (use unique context)
grep -n "specific phrase" unpacked/word/document.xml

# Step 4: Edit via Document library (see ooxml.md)
# Step 5: Pack back to DOCX
python ooxml/scripts/pack.py unpacked/ reviewed.docx

# Step 6: Verify
pandoc --track-changes=all reviewed.docx -o verification.md
grep "old phrase" verification.md  # should be absent
grep "new phrase" verification.md  # should be present
```

#### Minimal tracked change in OOXML XML

```python
# BAD: Replaces the entire sentence as one tracked change
bad = (
    '<w:del><w:r><w:delText>The term is 30 days.</w:delText></w:r></w:del>'
    '<w:ins><w:r><w:t>The term is 60 days.</w:t></w:r></w:ins>'
)

# GOOD: Only marks what actually changed, preserves unchanged runs
good = (
    '<w:r w:rsidR="00AB12CD"><w:t xml:space="preserve">The term is </w:t></w:r>'
    '<w:del><w:r><w:delText>30</w:delText></w:r></w:del>'
    '<w:ins><w:r><w:t>60</w:t></w:r></w:ins>'
    '<w:r w:rsidR="00AB12CD"><w:t> days.</w:t></w:r>'
)
```

---

### DOCX → Image (for visual review)

```bash
# Convert DOCX to PDF first, then PDF to images
soffice --headless --convert-to pdf document.docx
pdftoppm -jpeg -r 150 document.pdf page     # creates page-1.jpg, page-2.jpg ...
pdftoppm -jpeg -r 150 -f 2 -l 5 document.pdf page  # pages 2-5 only
```

---

### Dependencies Reference

```bash
# Python packages
uv add pypdf pdfplumber reportlab pdf2image pytesseract python-docx pandas openpyxl

# System packages (Ubuntu/Debian)
sudo apt-get install tesseract-ocr poppler-utils pandoc libreoffice

# Verify installations
python -c "import pypdf, pdfplumber, reportlab; print('PDF OK')"
python -c "import openpyxl, pandas; print('Excel OK')"
pandoc --version
```
