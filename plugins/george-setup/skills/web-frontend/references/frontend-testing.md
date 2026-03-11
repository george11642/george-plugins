# Frontend Testing Patterns

Consolidated from: js-ts-dev (testing-library-react.md, testing.md, testing-advanced.md), webapp-testing

## React Testing Library

### Core API
```tsx
import { render, screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"

test("submits form with valid data", async () => {
  const user = userEvent.setup()
  render(<LoginForm onSubmit={mockSubmit} />)
  
  await user.type(screen.getByLabelText("Email"), "test@example.com")
  await user.type(screen.getByLabelText("Password"), "secret123")
  await user.click(screen.getByRole("button", { name: "Sign In" }))
  
  expect(mockSubmit).toHaveBeenCalledWith({
    email: "test@example.com",
    password: "secret123"
  })
})
```

### Query Priority (most to least preferred)
1. `getByRole` — accessible roles (button, heading, textbox)
2. `getByLabelText` — form inputs with labels
3. `getByPlaceholderText` — when no label exists
4. `getByText` — non-interactive elements
5. `getByDisplayValue` — current input value
6. `getByTestId` — last resort, data-testid attribute

### Async Queries
```tsx
// Wait for element to appear
const alert = await screen.findByRole("alert")

// Wait for condition
await waitFor(() => {
  expect(screen.getByText("Success")).toBeInTheDocument()
})

// Wait for element to disappear
await waitForElementToBeRemoved(() => screen.queryByText("Loading..."))
```

### Custom Hook Testing
```tsx
import { renderHook, act } from "@testing-library/react"

test("increments counter", () => {
  const { result } = renderHook(() => useCounter())
  
  act(() => { result.current.increment() })
  
  expect(result.current.count).toBe(1)
})
```

## MSW (Mock Service Worker)

```tsx
import { http, HttpResponse } from "msw"
import { setupServer } from "msw/node"

const server = setupServer(
  http.get("/api/users", () => {
    return HttpResponse.json([
      { id: 1, name: "Alice" },
      { id: 2, name: "Bob" }
    ])
  })
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

// Override for specific test
test("handles error", async () => {
  server.use(
    http.get("/api/users", () => {
      return new HttpResponse(null, { status: 500 })
    })
  )
  // ... test error handling
})
```

## Playwright E2E

### Setup
```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto("http://localhost:3000")
    page.wait_for_load_state("networkidle")  # CRITICAL: wait for JS
```

### Common Patterns
```typescript
// Navigation and assertions
await page.goto("/dashboard")
await expect(page).toHaveURL("/dashboard")
await expect(page.getByRole("heading")).toHaveText("Dashboard")

// Forms
await page.getByLabel("Email").fill("test@example.com")
await page.getByRole("button", { name: "Submit" }).click()

// Wait for network
await page.waitForResponse(resp => resp.url().includes("/api/data"))

// Screenshots
await page.screenshot({ path: "screenshot.png", fullPage: true })
```

### Server Lifecycle (webapp-testing helper)
```bash
# Start dev server and run tests
python scripts/with_server.py --server "npm run dev" --port 3000 -- python test_script.py
```

## Vitest for Components

```tsx
import { describe, it, expect, vi } from "vitest"

describe("Button", () => {
  it("calls onClick when clicked", async () => {
    const onClick = vi.fn()
    render(<Button onClick={onClick}>Click me</Button>)
    
    await userEvent.click(screen.getByRole("button"))
    expect(onClick).toHaveBeenCalledOnce()
  })

  it("shows loading spinner when pending", () => {
    render(<Button loading>Submit</Button>)
    expect(screen.getByRole("button")).toBeDisabled()
    expect(screen.getByTestId("spinner")).toBeInTheDocument()
  })
})
```

## Testing Principles
- Test behavior, not implementation details
- AAA pattern: Arrange, Act, Assert
- Prefer `userEvent` over `fireEvent` (simulates real user)
- Query by accessible role/label first
- Mock network, not components
- 80%+ coverage target, focus on critical paths
