# MCP Server Development (Python / FastMCP)

Guide for building Model Context Protocol servers in Python using the FastMCP framework.

---

## Quick Reference

```python
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field, field_validator, ConfigDict
from typing import Optional, List, Dict, Any
from enum import Enum
import httpx
import json

mcp = FastMCP("service_mcp")   # server name format: {service}_mcp

@mcp.tool(name="service_action_resource", annotations={"readOnlyHint": True})
async def my_tool(params: InputModel) -> str:
    """Tool docstring becomes its MCP description."""
    ...

if __name__ == "__main__":
    mcp.run()  # stdio (default) or mcp.run(transport="streamable_http", port=8000)
```

Install: `uv add mcp` (includes FastMCP)

---

## Server Naming

- **Format**: `{service}_mcp` (lowercase, underscores)
- **Examples**: `github_mcp`, `slack_mcp`, `stripe_mcp`
- General, not tied to specific features. No version numbers.

---

## Tool Registration

### Decorator Pattern

```python
@mcp.tool(
    name="service_action_resource",    # snake_case with service prefix
    annotations={
        "title": "Human-Readable Title",
        "readOnlyHint": True,    # does not modify environment
        "destructiveHint": False, # does not delete/overwrite
        "idempotentHint": True,  # safe to repeat
        "openWorldHint": True,   # contacts external APIs
    }
)
async def service_action_resource(params: ActionInput) -> str:
    """Concise description of what this tool does.

    Longer explanation if needed. This docstring is auto-extracted
    as the MCP tool description.
    """
    ...
```

### Tool Annotation Reference

| Annotation | Type | Default | When True |
|-----------|------|---------|-----------|
| `readOnlyHint` | bool | false | Tool only reads, never writes |
| `destructiveHint` | bool | true | Tool may delete or overwrite data |
| `idempotentHint` | bool | false | Repeating the call has no extra effect |
| `openWorldHint` | bool | true | Tool contacts external services |

Annotations are hints to clients, not security enforcement.

---

## Input Validation with Pydantic v2

### Standard Model Pattern

```python
from pydantic import BaseModel, Field, field_validator, ConfigDict

class SearchInput(BaseModel):
    model_config = ConfigDict(
        str_strip_whitespace=True,   # auto-strip string whitespace
        validate_assignment=True,    # re-validate on attribute set
        extra="forbid",              # reject unknown fields
    )

    query: str = Field(
        ...,
        description="Search string (e.g., 'john@example.com', 'team:marketing')",
        min_length=2,
        max_length=200,
    )
    limit: Optional[int] = Field(default=20, description="Max results (1-100)", ge=1, le=100)
    offset: Optional[int] = Field(default=0, description="Pagination offset", ge=0)

    @field_validator("query")
    @classmethod
    def validate_query(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Query cannot be empty or whitespace only")
        return v.strip()
```

### Pydantic v2 Migration Notes

- Use `model_config = ConfigDict(...)` — NOT nested `class Config:`
- Use `@field_validator` — NOT `@validator` (deprecated)
- Use `model_dump()` — NOT `.dict()` (deprecated)
- Validators require `@classmethod` decorator
- All validator methods need type hints on parameters

```python
# v2 correct
class MyModel(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    email: str

    @field_validator("email")
    @classmethod
    def normalize_email(cls, v: str) -> str:
        return v.lower()
```

---

## Response Formats

Support both JSON (machine-readable) and Markdown (human-readable) via a format parameter:

```python
class ResponseFormat(str, Enum):
    MARKDOWN = "markdown"
    JSON = "json"

class ListInput(BaseModel):
    query: str = Field(..., description="Search query")
    response_format: ResponseFormat = Field(
        default=ResponseFormat.MARKDOWN,
        description="Output format: 'markdown' (default) or 'json'",
    )
```

**Markdown guidelines**:
- Use `## headers`, `**bold**`, and bullet lists
- Convert epoch timestamps to `"2024-01-15 10:30:00 UTC"` format
- Show display names with IDs: `"@john.doe (U123456)"`
- Omit verbose metadata (e.g., show one image URL, not all sizes)

**JSON guidelines**:
- Return all available fields
- Consistent key names and types
- Suitable for programmatic downstream processing

```python
def format_response(items: list[dict], fmt: ResponseFormat) -> str:
    if fmt == ResponseFormat.JSON:
        return json.dumps({"count": len(items), "items": items}, indent=2)
    # Markdown
    lines = [f"Found {len(items)} results", ""]
    for item in items:
        lines.append(f"## {item['name']} (`{item['id']}`)")
        lines.append(f"- Status: {item['status']}")
        lines.append("")
    return "\n".join(lines)
```

---

## Pagination

All list/search tools must support pagination. Never load all results into memory.

```python
class ListInput(BaseModel):
    limit: Optional[int] = Field(default=20, ge=1, le=100, description="Max results to return")
    offset: Optional[int] = Field(default=0, ge=0, description="Skip N results")

async def list_items(params: ListInput) -> str:
    data = await api_request("/items", params={"limit": params.limit, "offset": params.offset})
    items = data["items"]
    total = data["total"]
    has_more = total > params.offset + len(items)

    response = {
        "total": total,
        "count": len(items),
        "offset": params.offset,
        "has_more": has_more,
        "next_offset": params.offset + len(items) if has_more else None,
        "items": items,
    }
    return json.dumps(response, indent=2)
```

---

## Error Handling

Return errors as string responses (not protocol-level exceptions). Messages must be actionable.

```python
def _handle_api_error(e: Exception) -> str:
    """Consistent error formatting across all tools."""
    if isinstance(e, httpx.HTTPStatusError):
        status = e.response.status_code
        if status == 401:
            return "Error: Authentication failed. Check that your API key is valid."
        if status == 403:
            return "Error: Permission denied. You don't have access to this resource."
        if status == 404:
            return "Error: Resource not found. Verify the ID is correct."
        if status == 429:
            return "Error: Rate limit exceeded. Wait before retrying."
        return f"Error: API request failed with HTTP {status}."
    if isinstance(e, httpx.TimeoutException):
        return "Error: Request timed out. Try again or reduce the scope of your query."
    if isinstance(e, httpx.ConnectError):
        return "Error: Could not connect to the API. Check network connectivity."
    return f"Error: Unexpected error ({type(e).__name__}): {e}"
```

Do NOT expose internal stack traces or implementation details to callers.

---

## Shared HTTP Utilities

Extract the HTTP client into a shared function rather than repeating `httpx.AsyncClient()` in every tool.

```python
import os
import httpx

API_BASE_URL = "https://api.example.com/v1"
API_KEY = os.environ["EXAMPLE_API_KEY"]   # always from env, never hardcoded

async def _api_request(
    endpoint: str,
    method: str = "GET",
    *,
    params: dict | None = None,
    json_body: dict | None = None,
) -> dict:
    """Reusable authenticated API client."""
    async with httpx.AsyncClient(
        base_url=API_BASE_URL,
        headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
        timeout=30.0,
    ) as client:
        response = await client.request(method, endpoint, params=params, json=json_body)
        response.raise_for_status()
        return response.json()
```

---

## Context Injection

FastMCP injects a `Context` parameter automatically when present in the function signature.

```python
from mcp.server.fastmcp import FastMCP, Context

@mcp.tool()
async def long_running_task(query: str, ctx: Context) -> str:
    """Tool with progress reporting and logging."""

    await ctx.report_progress(0.0, "Starting...")
    await ctx.log_info("Processing query", {"query": query})

    results = await fetch_first_batch(query)
    await ctx.report_progress(0.5, "Halfway done...")

    final = await fetch_second_batch(results)
    await ctx.report_progress(1.0, "Complete")

    return format_results(final)

@mcp.tool()
async def secure_tool(resource_id: str, ctx: Context) -> str:
    """Tool that prompts for sensitive input at runtime."""
    api_key = await ctx.elicit(
        prompt="Please provide your API key to continue:",
        input_type="password",
    )
    return await api_call(resource_id, api_key)
```

**Context methods**:

| Method | Purpose |
|--------|---------|
| `ctx.report_progress(fraction, message)` | Update progress (0.0–1.0) |
| `ctx.log_info(msg, data)` | Debug logging |
| `ctx.log_error(msg, data)` | Error logging |
| `ctx.log_debug(msg, data)` | Verbose debug logging |
| `ctx.elicit(prompt, input_type)` | Request user input at runtime |
| `ctx.read_resource(uri)` | Read an MCP resource |
| `ctx.fastmcp.name` | Access server name |

---

## Resource Registration

Register data endpoints as MCP resources (URI-based access with templates).

```python
@mcp.resource("file://documents/{name}")
async def get_document(name: str) -> str:
    """Expose local documents as MCP resources."""
    path = Path(f"./docs/{name}")
    return path.read_text()

@mcp.resource("config://settings/{key}")
async def get_setting(key: str, ctx: Context) -> str:
    """Expose configuration values as resources."""
    settings = await load_settings()
    return json.dumps(settings.get(key, {}))
```

**Resources vs Tools**:
- **Resources**: Simple parameter, URI-template access, semi-static data
- **Tools**: Complex business logic, validation, side effects

---

## Structured Output Types

FastMCP can serialize structured types automatically:

```python
from typing import TypedDict
from pydantic import BaseModel

# TypedDict — FastMCP serializes to JSON
class UserResult(TypedDict):
    id: str
    name: str
    email: str

@mcp.tool()
async def get_user(user_id: str) -> UserResult:
    user = await fetch_user(user_id)
    return {"id": user["id"], "name": user["name"], "email": user["email"]}

# Pydantic model — schema auto-generated for clients
class DetailedUser(BaseModel):
    id: str
    name: str
    email: str
    created_at: datetime
    metadata: Dict[str, Any]

@mcp.tool()
async def get_user_detail(user_id: str) -> DetailedUser:
    user = await fetch_user(user_id)
    return DetailedUser(**user)
```

---

## Lifespan Management

Use lifespan for resources that should persist across tool calls (DB connections, config, caches).

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def app_lifespan():
    """Initialize and clean up long-lived resources."""
    db = await connect_to_database(os.environ["DATABASE_URL"])
    config = load_configuration()
    cache = {}

    yield {"db": db, "config": config, "cache": cache}

    await db.close()

mcp = FastMCP("myservice_mcp", lifespan=app_lifespan)

@mcp.tool()
async def query_data(query: str, ctx: Context) -> str:
    """Access lifespan state via context."""
    db = ctx.request_context.lifespan_state["db"]
    rows = await db.fetch(query)
    return json.dumps(rows, indent=2)
```

---

## Transport Options

```python
# stdio — for local/subprocess execution (default)
if __name__ == "__main__":
    mcp.run()

# Streamable HTTP — for web services, multi-client
if __name__ == "__main__":
    mcp.run(transport="streamable_http", port=8000)
```

| Criterion | stdio | Streamable HTTP |
|-----------|-------|-----------------|
| Deployment | Local CLI / subprocess | Cloud / web service |
| Clients | Single | Multiple concurrent |
| Complexity | Low | Medium |
| Logging | Use stderr only | Normal logging |

**stdio rule**: Never write to stdout (it's the protocol channel). Use `ctx.log_*()` or write to stderr.

---

## Complete Working Example

```python
#!/usr/bin/env python3
"""MCP Server for the Example API."""

from __future__ import annotations

import json
import os
from enum import Enum
from typing import Any, Optional

import httpx
from mcp.server.fastmcp import FastMCP, Context
from pydantic import BaseModel, ConfigDict, Field, field_validator

mcp = FastMCP("example_mcp")

API_BASE_URL = "https://api.example.com/v1"
API_KEY = os.environ.get("EXAMPLE_API_KEY", "")


# --- Enums and Shared Models ---

class ResponseFormat(str, Enum):
    MARKDOWN = "markdown"
    JSON = "json"


# --- HTTP Client ---

async def _api_get(endpoint: str, params: dict | None = None) -> dict:
    async with httpx.AsyncClient(
        headers={"Authorization": f"Bearer {API_KEY}"},
        timeout=30.0,
    ) as client:
        r = await client.get(f"{API_BASE_URL}/{endpoint}", params=params)
        r.raise_for_status()
        return r.json()


def _handle_error(e: Exception) -> str:
    if isinstance(e, httpx.HTTPStatusError):
        code = e.response.status_code
        msgs = {
            401: "Authentication failed. Verify EXAMPLE_API_KEY.",
            403: "Permission denied.",
            404: "Resource not found. Check the ID.",
            429: "Rate limit exceeded. Retry after a delay.",
        }
        return f"Error: {msgs.get(code, f'HTTP {code}')}"
    if isinstance(e, httpx.TimeoutException):
        return "Error: Request timed out."
    return f"Error: {type(e).__name__}: {e}"


# --- Tool Definitions ---

class UserSearchInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")

    query: str = Field(..., description="Name or email to search (e.g., 'alice', '@example.com')", min_length=1)
    limit: Optional[int] = Field(default=20, ge=1, le=100, description="Max results")
    offset: Optional[int] = Field(default=0, ge=0, description="Pagination offset")
    response_format: ResponseFormat = Field(default=ResponseFormat.MARKDOWN)

    @field_validator("query")
    @classmethod
    def nonempty_query(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Query must not be empty")
        return v


@mcp.tool(
    name="example_search_users",
    annotations={
        "title": "Search Users",
        "readOnlyHint": True,
        "destructiveHint": False,
        "idempotentHint": True,
        "openWorldHint": True,
    },
)
async def example_search_users(params: UserSearchInput, ctx: Context) -> str:
    """Search for users in the Example system by name or email.

    Args:
        params: Validated input with query, limit, offset, and response_format.

    Returns:
        JSON or Markdown listing matched users with id, name, and email.
    """
    await ctx.log_info("Searching users", {"query": params.query})
    try:
        data = await _api_get(
            "users/search",
            params={"q": params.query, "limit": params.limit, "offset": params.offset},
        )
    except Exception as e:
        return _handle_error(e)

    users = data.get("users", [])
    total = data.get("total", 0)

    if not users:
        return f"No users found matching '{params.query}'."

    has_more = total > params.offset + len(users)

    if params.response_format == ResponseFormat.JSON:
        return json.dumps(
            {
                "total": total,
                "count": len(users),
                "offset": params.offset,
                "has_more": has_more,
                "next_offset": params.offset + len(users) if has_more else None,
                "users": users,
            },
            indent=2,
        )

    lines = [f"# Users matching '{params.query}'", f"Showing {len(users)} of {total}", ""]
    for u in users:
        lines.append(f"## {u['name']} (`{u['id']}`)")
        lines.append(f"- Email: {u['email']}")
        lines.append("")
    if has_more:
        lines.append(f"*More results available. Use offset={params.offset + len(users)}.*")
    return "\n".join(lines)


if __name__ == "__main__":
    mcp.run()
```

---

## Quality Checklist

### Design

- [ ] Tools reflect natural workflows, not just API endpoint wrappers
- [ ] Tool names: `{service}_{action}_{resource}` snake_case with service prefix
- [ ] Every tool has a clear docstring (becomes MCP description)
- [ ] Response format supports both markdown and JSON

### Pydantic / Validation

- [ ] Every tool uses a Pydantic `BaseModel` for input, NOT plain kwargs
- [ ] All fields have `Field(description=...)` with constraints (`min_length`, `ge`, `le`, etc.)
- [ ] `model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")`
- [ ] `@field_validator` with `@classmethod` (Pydantic v2)
- [ ] `model_dump()` not `.dict()`

### Implementation

- [ ] All network I/O uses `async def` + `await`
- [ ] HTTP client uses `async with httpx.AsyncClient(...)`
- [ ] Shared `_api_request()` helper — no duplicated HTTP code
- [ ] Shared `_handle_error()` — consistent error strings
- [ ] Constants in `UPPER_CASE` at module level
- [ ] API keys from `os.environ` — never hardcoded

### Annotations

- [ ] All tools set `readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`
- [ ] Server name follows `{service}_mcp` pattern

### Pagination

- [ ] List/search tools accept `limit` and `offset`
- [ ] Responses include `total`, `count`, `has_more`, `next_offset`
- [ ] Default limit is 20-50, maximum is ≤ 100

### Advanced (where applicable)

- [ ] `Context` injected for long-running tools (progress reporting, logging)
- [ ] `@mcp.resource(uri_template)` used for static/semi-static data
- [ ] Lifespan context manager for DB connections, config caches
- [ ] Transport selection: stdio for local, streamable_http for remote

### Testing

```bash
# Verify syntax and imports
python -m py_compile server.py

# Run server
python server.py

# Test with MCP Inspector
npx @modelcontextprotocol/inspector python server.py

# Check environment
echo $EXAMPLE_API_KEY
```

---

## Security

```python
# Store secrets in environment variables
API_KEY = os.environ["SERVICE_API_KEY"]  # crash on startup if missing (good)

# Validate keys on startup
if not API_KEY:
    raise RuntimeError("SERVICE_API_KEY environment variable is required")

# Sanitize file paths (prevent directory traversal)
def safe_path(base: str, user_input: str) -> Path:
    base_path = Path(base).resolve()
    target = (base_path / user_input).resolve()
    if not str(target).startswith(str(base_path)):
        raise ValueError("Path traversal attempt detected")
    return target

# stdio: log to stderr only
import sys
print("debug info", file=sys.stderr)   # OK
# print("debug info")                  # BAD — corrupts stdio protocol
```

---

## Further Reading

- MCP spec: `https://modelcontextprotocol.io/sitemap.xml` (fetch with `.md` suffix for markdown)
- Python SDK README: `https://raw.githubusercontent.com/modelcontextprotocol/python-sdk/main/README.md`
- Test interactively: `npx @modelcontextprotocol/inspector python server.py`
