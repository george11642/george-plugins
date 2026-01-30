#!/bin/bash
# detect-stack.sh - Auto-detect project tech stack for Ralph Marketer
# Run from the project root. Outputs JSON to stdout.
# chmod +x scripts/detect-stack.sh
set -euo pipefail

has_file() { [[ -f "$1" ]]; }
has_dir()  { [[ -d "$1" ]]; }
json_arr() {
  if [[ $# -eq 0 ]]; then echo '[]'; return; fi
  printf '%s\n' "$@" | jq -R . | jq -s .
}

# Check package.json (root + one level deep for monorepos)
pkg_has() {
  has_file "package.json" && grep -q "\"$1\"" package.json 2>/dev/null && return 0
  for sub in */package.json; do
    has_file "$sub" && grep -q "\"$1\"" "$sub" 2>/dev/null && return 0
  done
  return 1
}

extract_description() {
  local file=""
  has_file "CLAUDE.md" && file="CLAUDE.md" || { has_file "README.md" && file="README.md"; }
  [[ -z "$file" ]] && { echo ""; return; }
  grep -v '^\s*$' "$file" | grep -v '^#' | head -1 | sed 's/^[[:space:]]*//' | cut -c1-200
}

extract_project_name() {
  if has_file "package.json" && command -v jq &>/dev/null; then
    local n; n=$(jq -r '.name // empty' package.json 2>/dev/null || true)
    [[ -n "$n" ]] && { echo "$n"; return; }
  fi
  for f in CLAUDE.md README.md; do
    if has_file "$f"; then
      local h; h=$(grep -m1 '^#\s' "$f" 2>/dev/null | sed 's/^#\s*//' | sed 's/\s*[-–].*//')
      [[ -n "$h" ]] && { echo "$h"; return; }
    fi
  done
  basename "$PWD"
}

# ── Detect Stack ─────────────────────────────────────────────────────────────
stack=(); has_blog="false"; blog_location=""; has_supa="false"

if pkg_has "next"; then
  stack+=("nextjs"); has_blog="true"
  if has_dir "web/app"; then blog_location="web/app/blog"
  elif has_dir "app"; then blog_location="app/blog"
  elif has_dir "src/app"; then blog_location="src/app/blog"
  elif has_dir "pages"; then blog_location="pages/blog"; fi
fi
if has_dir "supabase" || pkg_has "@supabase/supabase-js"; then
  stack+=("supabase"); has_supa="true"
fi
if has_dir "wp-content" || has_file "wp-config.php"; then
  stack+=("wordpress"); has_blog="true"; blog_location="wp-content/posts"
fi
if has_file "_config.yml" && grep -q "jekyll\|baseurl\|permalink" _config.yml 2>/dev/null; then
  stack+=("jekyll"); has_blog="true"
  has_dir "_posts" && blog_location="_posts"
fi
if has_file "hugo.toml" || has_file "hugo.yaml" || has_file "hugo.json"; then
  stack+=("hugo"); has_blog="true"; blog_location="content/posts"
fi
if compgen -G "gatsby-config.*" &>/dev/null; then
  stack+=("gatsby"); has_blog="true"; blog_location="src/pages/blog"
fi
if compgen -G "astro.config.*" &>/dev/null; then
  stack+=("astro"); has_blog="true"; blog_location="src/content/blog"
fi
if has_file "tsconfig.json" || pkg_has "typescript"; then stack+=("typescript"); fi
if pkg_has "react-native" || pkg_has "expo"; then stack+=("react-native")
elif pkg_has "react"; then stack+=("react"); fi
if has_file "requirements.txt" || has_file "pyproject.toml" || has_file "setup.py"; then
  stack+=("python")
  has_file "manage.py" && stack+=("django")
  grep -q "flask" requirements.txt 2>/dev/null && stack+=("flask")
fi
has_file "go.mod" && stack+=("go")
has_file "Cargo.toml" && stack+=("rust")

# ── Env File Detection ───────────────────────────────────────────────────────
has_env="false"; env_keys=()

scan_env() {
  local f="$1"
  has_file "$f" || return 0
  has_env="true"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    local key="${line%%=*}"; key="${key// /}"
    [[ -n "$key" ]] && env_keys+=("$key")
  done < "$f"
}

for ef in .env .env.local .env.development .env.production; do scan_env "$ef"; done
for ef in */.env */.env.local; do scan_env "$ef"; done

# Deduplicate
if [[ ${#env_keys[@]} -gt 0 ]]; then
  mapfile -t env_keys < <(printf '%s\n' "${env_keys[@]}" | sort -u)
fi

# ── Output JSON ──────────────────────────────────────────────────────────────
jq -n \
  --argjson detected_stack "$(json_arr "${stack[@]+"${stack[@]}"}")" \
  --arg project_name "$(extract_project_name)" \
  --arg project_description "$(extract_description)" \
  --argjson has_blog_location "$has_blog" \
  --arg suggested_blog_location "$blog_location" \
  --argjson has_supabase "$has_supa" \
  --argjson has_env_files "$has_env" \
  --argjson env_keys_found "$(json_arr "${env_keys[@]+"${env_keys[@]}"}")" \
  '{
    detected_stack: $detected_stack,
    project_name: $project_name,
    project_description: $project_description,
    has_blog_location: $has_blog_location,
    suggested_blog_location: $suggested_blog_location,
    has_supabase: $has_supabase,
    has_env_files: $has_env_files,
    env_keys_found: $env_keys_found
  }'
