---
name: db-supabase
description: "Use when working with Supabase database, running SQL, applying migrations, or deploying edge functions. Triggers on Supabase, Supabase migration, Supabase SQL, Supabase edge function, Supabase RLS, row-level security, Supabase branch, Supabase table, execute_sql, apply_migration, list_tables, Supabase MCP, Supabase database."
---

# DB Supabase

Access via Supabase MCP (lazy-loaded via ToolSearch).

## MCP Tools
| Task | Tool |
|------|------|
| Execute SQL | `mcp__plugin_supabase_supabase__execute_sql` |
| Apply migration | `mcp__plugin_supabase_supabase__apply_migration` |
| List tables | `mcp__plugin_supabase_supabase__list_tables` |
| List migrations | `mcp__plugin_supabase_supabase__list_migrations` |
| Create branch | `mcp__plugin_supabase_supabase__create_branch` |
| Deploy edge function | `mcp__plugin_supabase_supabase__deploy_edge_function` |

## Usage Pattern
1. Use `ToolSearch` to discover Supabase MCP tools
2. Call MCP tools directly — no CLI needed
3. For complex queries, use `execute_sql`
4. For schema changes, use `apply_migration`

## Best Practices
- Always use migrations for schema changes (not raw SQL)
- Use branches for testing schema changes before prod
- Edge functions for serverless logic close to the database
- RLS policies for row-level security
