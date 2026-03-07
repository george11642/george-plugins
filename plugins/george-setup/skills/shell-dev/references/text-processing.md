# Text Processing: awk, sed, and Pipeline Patterns

Deep dive into awk and sed for log analysis, data transformation, and stream processing.

---

## 1. awk Fundamentals

### Core Variables

| Variable | Meaning |
|----------|---------|
| `NR` | Current record number (line count across all files) |
| `FNR` | Record number within current file |
| `NF` | Number of fields in current record |
| `FS` | Input field separator (default: whitespace) |
| `RS` | Input record separator (default: newline) |
| `OFS` | Output field separator (default: space) |
| `ORS` | Output record separator (default: newline) |
| `FILENAME` | Name of current input file |
| `$0` | Entire current record |
| `$1`, `$2`, ... | Individual fields |

### One-liners

```bash
# Print specific fields (like cut but smarter)
awk '{print $1, $3}' file.txt               # Fields 1 and 3, space-separated
awk '{print $NF}' file.txt                  # Last field of each line
awk '{print $(NF-1)}' file.txt              # Second-to-last field

# Filtering with conditions
awk '$3 > 100' file.txt                     # Lines where field 3 > 100
awk 'NR >= 5 && NR <= 20' file.txt          # Lines 5-20 (like sed -n '5,20p')
awk 'NF > 0' file.txt                       # Skip blank lines
awk '!seen[$0]++' file.txt                  # Remove duplicate lines (preserves order)

# Math
awk '{sum += $1} END {print sum}' nums.txt          # Sum column 1
awk '{sum += $1; count++} END {print sum/count}' f  # Average
awk 'NR==1{max=$1} $1>max{max=$1} END{print max}' f # Max value

# Field manipulation
awk '{$2 = toupper($2); print}' file.txt    # Uppercase field 2
awk 'OFS=","{$1=$1; print}' file.txt        # Reformat: space-sep to CSV
awk '{$1=""; print substr($0,2)}' file.txt  # Remove first field

# Line numbering
awk '{print NR": "$0}' file.txt             # Add line numbers
awk '{printf "%5d  %s\n", NR, $0}' file.txt # Right-aligned line numbers
```

---

## 2. awk Programs with BEGIN/END Blocks

```bash
# BEGIN: runs before any input; END: runs after all input
awk '
BEGIN {
    FS=","
    OFS="\t"
    print "Name\tScore\tGrade"
    print "----\t-----\t-----"
}
NR > 1 {                        # Skip header (line 1)
    name = $1
    score = $2 + 0              # Force numeric
    if      (score >= 90) grade = "A"
    else if (score >= 80) grade = "B"
    else if (score >= 70) grade = "C"
    else                  grade = "F"
    print name, score, grade
    total += score
    count++
}
END {
    printf "\nAverage: %.1f\n", total/count
}
' grades.csv
```

### Multi-file Processing with FNR

```bash
awk '
FNR == 1 { print "=== File:", FILENAME, "===" }
{ print FNR": "$0 }
' file1.txt file2.txt
```

---

## 3. awk Associative Arrays

```bash
# Count occurrences (word frequency)
awk '{for(i=1;i<=NF;i++) freq[$i]++}
     END {for (w in freq) print freq[w], w}' text.txt | sort -rn | head -20

# Group and aggregate
awk -F, '
NR > 1 {
    dept[$2] += $3          # Sum salary by department
    count[$2]++
}
END {
    for (d in dept)
        printf "%-20s  total=%d  avg=%.0f\n", d, dept[d], dept[d]/count[d]
}
' employees.csv | sort

# Two-file join (print lines from file2 that match keys in file1)
awk '
NR==FNR { keys[$1]=1; next }   # Load file1 keys
$1 in keys { print }            # Print matching lines from file2
' file1.txt file2.txt

# Invert: print lines NOT in file1
awk 'NR==FNR{keys[$1]=1;next} !($1 in keys)' file1.txt file2.txt
```

---

## 4. awk String Functions

```bash
# substr, index, split, sub, gsub, match, sprintf
awk '{print substr($0, 5, 10)}' file.txt        # Chars 5-14
awk '{print index($0, "ERROR")}' file.txt        # Position of "ERROR" (0=not found)
awk '{n=split($0,a,":"); for(i=1;i<=n;i++) print a[i]}' /etc/passwd

# sub replaces FIRST match; gsub replaces ALL matches
awk '{gsub(/foo/, "bar"); print}' file.txt       # Replace all "foo" with "bar"
awk '{sub(/^[[:space:]]+/, ""); print}' f        # Trim leading whitespace
awk '{gsub(/[[:space:]]+/, " "); print}' f       # Collapse multiple spaces

# match: sets RSTART and RLENGTH
awk 'match($0, /[0-9]+\.[0-9]+/) {
    print substr($0, RSTART, RLENGTH)            # Extract matched portion
}' file.txt

# sprintf for formatting
awk '{printf "%-10s %8.2f\n", $1, $2}' data.txt
```

---

## 5. awk Patterns and Regex

```bash
# Pattern /regex/ runs action only on matching lines
awk '/ERROR/{print FILENAME, NR, $0}' *.log      # Errors with location
awk '!/^#/ && NF > 0' config.txt                 # Non-comment, non-blank lines
awk '/START/,/END/' file.txt                      # Range: lines between START and END (inclusive)
awk '/^---$/,/^---$/{if(!/^---$/) print}' f      # Between delimiters, excluding delimiters

# Negation and compound patterns
awk '$1 ~ /^[0-9]/ && $2 !~ /SKIP/' data.txt    # Field 1 starts with digit, field 2 not SKIP
awk '$0 ~ /warning/ || $0 ~ /error/' log.txt     # warning OR error (same as: /warning|error/)
```

---

## 6. sed Address Ranges and Substitutions

### Basic Substitution

```bash
sed 's/old/new/'        file.txt    # Replace first occurrence per line
sed 's/old/new/g'       file.txt    # Replace all occurrences (global)
sed 's/old/new/gi'      file.txt    # Case-insensitive global replace
sed 's/old/new/2'       file.txt    # Replace only 2nd occurrence
sed 's/old/new/2g'      file.txt    # Replace 2nd and all subsequent occurrences

# In-place editing
sed -i 's/old/new/g' file.txt              # GNU sed: modify in place
sed -i.bak 's/old/new/g' file.txt         # GNU sed: in-place with backup (.bak)
sed -i '' 's/old/new/g' file.txt          # macOS/BSD sed (POSIX)
```

### Address Ranges

```bash
sed -n '5p'           file.txt    # Print only line 5
sed -n '5,20p'        file.txt    # Print lines 5-20
sed '5,20d'           file.txt    # Delete lines 5-20
sed '1d'              file.txt    # Delete first line (header)
sed '$d'              file.txt    # Delete last line
sed '/pattern/d'      file.txt    # Delete lines matching pattern
sed '/START/,/END/d'  file.txt    # Delete range between patterns

# Apply substitution only in a range
sed '/BEGIN/,/END/ s/foo/bar/g' file.txt
```

### Backreferences

```bash
# Capture groups with \( \) in BRE, or ( ) in ERE (-E)
sed 's/\(first\) \(second\)/\2 \1/'      file.txt   # Swap two words (BRE)
sed -E 's/(first) (second)/\2 \1/'       file.txt   # Same with ERE

# Extract and reformat
echo "2024-01-15" | sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\3\/\2\/\1/'
# Output: 15/01/2024

# Add prefix/suffix to matching lines
sed '/^ERROR/ s/^/[ALERT] /'  log.txt    # Prepend [ALERT] to ERROR lines
sed '/warning/ s/$/ <-- WARN/' log.txt   # Append to matching lines
```

### sed -E for Extended Regex

```bash
sed -E 's/https?:\/\/[^ ]+/[URL]/g' text.txt          # Replace URLs
sed -E 's/[0-9]{1,3}(\.[0-9]{1,3}){3}/[IP]/g' f      # Replace IPv4 addresses
sed -E 's/\b[A-Z][a-z]+ [A-Z][a-z]+\b/[NAME]/g' f    # Replace proper names
sed -E '/^\s*#|^\s*$/d' config.txt                     # Remove comments and blank lines
```

### sed Multi-command and Append/Insert

```bash
# Multiple commands with -e or semicolons
sed -e 's/foo/bar/g' -e 's/baz/qux/g' file.txt
sed 's/foo/bar/g; s/baz/qux/g' file.txt

# Append a line after matching pattern
sed '/^SECTION_START/ a\    New line added after section start' file.txt

# Insert a line before matching pattern
sed '/^SECTION_END/ i\    New line added before section end' file.txt

# Print surrounding context (poor man's grep -C)
sed -n '/ERROR/{N;N;N;p}' log.txt   # Match + next 3 lines (fragile; prefer grep -A)
```

---

## 7. Complex Pipeline Patterns

```bash
# Count HTTP status codes from access log
awk '{print $9}' access.log | sort | uniq -c | sort -rn

# Top 10 IPs by request count
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -10

# Find log entries between two timestamps
awk '$0 >= "2024-01-15 10:00" && $0 <= "2024-01-15 11:00"' app.log

# Extract JSON field values from logs (when jq is overkill for simple case)
grep '"level":"error"' app.log | sed -E 's/.*"message":"([^"]+)".*/\1/'

# Process a config file: strip comments, blank lines, normalize whitespace
grep -v '^\s*#' config.txt | grep -v '^\s*$' | sed 's/[[:space:]]*=[[:space:]]*/=/'

# Convert Windows CRLF to Unix LF
sed 's/\r$//' windows-file.txt > unix-file.txt
# Or: tr -d '\r' < windows-file.txt > unix-file.txt

# Extract lines between two patterns (exclusive)
sed -n '/START_MARKER/{n; /END_MARKER/!{:loop; p; n; /END_MARKER/!b loop}}' file.txt

# Simpler range extraction with awk
awk '/START/{found=1; next} /END/{found=0} found' file.txt
```

---

## 8. CSV/TSV Processing with awk

```bash
# Parse CSV (simple — no quoted commas)
awk -F, 'NR>1{print $1, $3}' data.csv          # Skip header, print cols 1 and 3

# TSV processing
awk -F'\t' '{print $2}' data.tsv                # Print column 2

# CSV to TSV conversion
awk 'BEGIN{FS=","; OFS="\t"} {$1=$1; print}' data.csv

# Print CSV header and matching rows
awk -F, 'NR==1 || $3 == "active"' users.csv

# Calculate totals from CSV
awk -F, 'NR>1{total += $4; count++} END{printf "Total: %.2f\nCount: %d\nAvg: %.2f\n", total, count, total/count}' sales.csv

# Filter and reorder columns
awk -F, 'BEGIN{OFS=","} NR>1 && $5=="Y" {print $2,$3,$1}' input.csv

# Handle quoted fields (robust CSV — requires gawk 4+)
awk 'BEGIN{FPAT="([^,]+)|(\"[^\"]+\")"} {print $1, $3}' complex.csv
```

---

## 9. Log File Analysis Patterns

```bash
# Error rate per minute from structured logs
awk '/ERROR/{
    match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}/, t)
    minutes[t[0]]++
}
END {
    for (m in minutes) print m, minutes[m]
}' app.log | sort

# Response time histogram from nginx logs
awk '{
    rt = $NF + 0           # Last field is response time
    if      (rt < 0.1)  bucket="<100ms"
    else if (rt < 0.5)  bucket="<500ms"
    else if (rt < 1.0)  bucket="<1s"
    else                bucket=">=1s"
    counts[bucket]++
}
END {
    for (b in counts) print counts[b], b
}' access.log | sort -k2

# Find slow requests (>1s) with their URL
awk '$NF > 1.0 {print $7, $NF}' access.log | sort -k2 -rn | head -20

# Count unique users per hour
awk '{
    match($4, /[0-9]{2}\/[A-Za-z]+\/[0-9]{4}:[0-9]{2}/, t)
    hour_user[t[0]" "$1] = 1
}
END {
    for (hu in hour_user) {
        split(hu, a, " ")
        hours[a[1]]++
    }
    for (h in hours) print h, hours[h]
}' access.log | sort
```

---

## 10. Performance: When to Use What

| Tool | Use When | Avoid When |
|------|----------|-----------|
| `grep` | Simple pattern matching, line extraction | Need field splitting or arithmetic |
| `sed` | Single-pass substitutions, line operations | Need associative arrays or complex logic |
| `awk` | Field-based processing, aggregation, joins | File > 10GB (consider datamash/python) |
| Pure `bash` | Simple variable manipulation in-memory | Processing files line-by-line (very slow) |
| `cut` | Simple fixed-delimiter field extraction | Variable whitespace delimiters |
| `sort \| uniq -c` | Frequency counting | When order matters during processing |
| `python` / `perl` | Complex parsing, multi-file joins, JSON/XML | When a one-liner suffices |

### Performance Tips

```bash
# Don't call awk/sed in a loop — process the whole file at once
# SLOW:
while IFS= read -r line; do
    echo "$line" | awk '{print $2}'   # Fork per line!
done < big_file.txt

# FAST:
awk '{print $2}' big_file.txt

# Use FS instead of multiple pipes
# SLOW: cut -d, -f1 file | grep pattern | awk '{print $2}'
# FAST: awk -F, '/pattern/{print $2}' file

# For very large files, avoid loading into memory
# SLOW: sort file | uniq -c    (sorts entire file)
# FAST for recent logs: awk '{counts[$0]++} END{for(k in counts)print counts[k],k}' f

# mawk is significantly faster than gawk for pure text processing
# gawk is needed for: FPAT, gensub(), nextfile, time functions
```

---

## 11. Practical One-liner Cheatsheet

```bash
# Remove blank lines
awk 'NF' file.txt
sed '/^[[:space:]]*$/d' file.txt

# Print between line numbers
awk 'NR==10,NR==20' file.txt

# Print last N lines without tail
awk '{lines[NR%5]=$0} END{for(i=NR+1;i<=NR+5;i++) if(lines[i%5]) print lines[i%5]}' f

# Double-space a file
sed 'G' file.txt

# Reverse line order (like tac)
awk '{lines[NR]=$0} END{for(i=NR;i>=1;i--)print lines[i]}' file.txt

# Print duplicate lines only
awk 'seen[$0]++' file.txt

# Number only non-blank lines
awk 'NF{print ++n": "$0; next} 1' file.txt

# Sum values matching a pattern
awk '/PAYMENT/{sum+=$NF} END{print "Total:", sum}' ledger.txt

# Replace nth occurrence of pattern
awk 'BEGIN{n=3; c=0} /pattern/{c++; if(c==n) sub(/pattern/, "replacement")} 1'

# Extract IP addresses from any text
grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' file.txt
# Or with awk:
awk 'match($0,/[0-9]{1,3}(\.[0-9]{1,3}){3}/){print substr($0,RSTART,RLENGTH)}' f
```
