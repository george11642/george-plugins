# React Testing Library

## Setup

```bash
pnpm add -D @testing-library/react @testing-library/user-event @testing-library/jest-dom
# For MSW (API mocking):
pnpm add -D msw
```

```typescript
// vitest.setup.ts or jest.setup.ts
import '@testing-library/jest-dom'
```

---

## Core Concepts

### Render and Screen

```typescript
import { render, screen } from '@testing-library/react'

test('shows heading', () => {
  render(<MyComponent />)
  // screen has all queries pre-bound to document.body
  expect(screen.getByRole('heading', { name: /welcome/i })).toBeInTheDocument()
})
```

### Query Priority (Most to Least Preferred)

1. **`getByRole`** — mirrors accessibility tree; most resilient
2. **`getByLabelText`** — for form inputs
3. **`getByPlaceholderText`** — fallback for inputs without labels
4. **`getByText`** — for non-interactive text content
5. **`getByDisplayValue`** — for select/input current values
6. **`getByAltText`** — for images
7. **`getByTitle`** — for title attributes
8. **`getByTestId`** — last resort; use `data-testid` sparingly

```typescript
// Prefer getByRole with accessible name
screen.getByRole('button', { name: /submit/i })
screen.getByRole('textbox', { name: /email address/i })
screen.getByRole('combobox', { name: /country/i })
screen.getByRole('checkbox', { name: /agree to terms/i })

// Avoid — brittle, couples to implementation
screen.getByTestId('submit-btn')
```

### Query Variants

| Prefix | Returns | If missing | If multiple |
|--------|---------|------------|-------------|
| `getBy` | Element | throws | throws |
| `queryBy` | Element or null | null | throws |
| `findBy` | Promise\<Element\> | rejects after timeout | rejects |
| `getAllBy` | Element[] | throws | ok |
| `queryAllBy` | Element[] | [] | ok |
| `findAllBy` | Promise\<Element[]\> | rejects | ok |

Use `queryBy` to assert element is NOT present:
```typescript
expect(screen.queryByText('Error')).not.toBeInTheDocument()
```

Use `findBy` for async appearance:
```typescript
const heading = await screen.findByRole('heading', { name: /loaded/i })
```

---

## User Interactions

### userEvent (Preferred)

`userEvent` fires realistic browser events (keydown, keypress, keyup, pointer events, etc.).

```typescript
import userEvent from '@testing-library/user-event'

test('form submission', async () => {
  // Create a user session — set up ONCE per test
  const user = userEvent.setup()

  render(<LoginForm onSubmit={mockSubmit} />)

  await user.type(screen.getByLabelText(/email/i), 'user@example.com')
  await user.type(screen.getByLabelText(/password/i), 'secret123')
  await user.click(screen.getByRole('button', { name: /sign in/i }))

  expect(mockSubmit).toHaveBeenCalledWith({
    email: 'user@example.com',
    password: 'secret123',
  })
})
```

### userEvent API Reference

```typescript
const user = userEvent.setup()

await user.click(element)
await user.dblClick(element)
await user.type(element, 'text')        // types char by char
await user.clear(element)               // clears input
await user.selectOptions(select, ['value1'])
await user.deselectOptions(select, ['value1'])
await user.upload(fileInput, file)
await user.keyboard('{Enter}')
await user.tab()                        // focus next element
await user.hover(element)
await user.unhover(element)
await user.paste('pasted text')
```

### fireEvent (Use Sparingly)

`fireEvent` dispatches a single DOM event — suitable for events that `userEvent` can't reproduce (e.g., custom events, drag-and-drop):

```typescript
import { fireEvent } from '@testing-library/react'

fireEvent.change(input, { target: { value: 'new value' } })
fireEvent.keyDown(input, { key: 'Escape', code: 'Escape' })
```

---

## Async Patterns

### waitFor

```typescript
import { waitFor } from '@testing-library/react'

test('shows data after load', async () => {
  render(<DataTable />)

  // Wait for loading to finish
  await waitFor(() => {
    expect(screen.queryByText('Loading...')).not.toBeInTheDocument()
  })

  expect(screen.getByRole('table')).toBeInTheDocument()
})
```

`waitFor` retries the callback until it passes or times out (default 1000ms). Do NOT put side effects inside — only assertions.

### findBy Queries (Preferred for Async)

```typescript
// findBy = waitFor + getBy — cleaner for single elements
const row = await screen.findByRole('row', { name: /john doe/i })
expect(row).toBeInTheDocument()
```

---

## Testing Custom Hooks (renderHook)

```typescript
import { renderHook, act } from '@testing-library/react'
import { useCounter } from './useCounter'

test('counter increments', () => {
  const { result } = renderHook(() => useCounter(0))

  expect(result.current.count).toBe(0)

  act(() => {
    result.current.increment()
  })

  expect(result.current.count).toBe(1)
})

test('async hook', async () => {
  const { result } = renderHook(() => useUsers())

  expect(result.current.loading).toBe(true)

  await waitFor(() => {
    expect(result.current.loading).toBe(false)
  })

  expect(result.current.users).toHaveLength(3)
})
```

---

## Custom Render with Providers

```typescript
// test-utils.tsx
import { render, RenderOptions } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter } from 'react-router-dom'
import type { ReactElement } from 'react'

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })
}

interface TestProviders {
  children: React.ReactNode
  initialEntries?: string[]
}

function AllProviders({ children }: TestProviders) {
  const queryClient = createTestQueryClient()
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>{children}</BrowserRouter>
    </QueryClientProvider>
  )
}

function customRender(ui: ReactElement, options?: Omit<RenderOptions, 'wrapper'>) {
  return render(ui, { wrapper: AllProviders, ...options })
}

// Re-export everything
export * from '@testing-library/react'
export { customRender as render }
```

---

## MSW for API Mocking

```typescript
// src/mocks/handlers.ts
import { http, HttpResponse } from 'msw'

export const handlers = [
  http.get('/api/users', () => {
    return HttpResponse.json([
      { id: '1', name: 'Alice', email: 'alice@example.com' },
      { id: '2', name: 'Bob', email: 'bob@example.com' },
    ])
  }),

  http.post('/api/users', async ({ request }) => {
    const body = await request.json() as { name: string; email: string }
    return HttpResponse.json({ id: '3', ...body }, { status: 201 })
  }),

  http.get('/api/users/:id', ({ params }) => {
    if (params.id === '999') {
      return new HttpResponse(null, { status: 404 })
    }
    return HttpResponse.json({ id: params.id, name: 'Alice' })
  }),
]

// src/mocks/server.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)

// vitest.setup.ts
import { server } from './src/mocks/server'

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

Override handlers per test:
```typescript
import { server } from '../../mocks/server'
import { http, HttpResponse } from 'msw'

test('shows error on server failure', async () => {
  server.use(
    http.get('/api/users', () => {
      return HttpResponse.json({ message: 'Server error' }, { status: 500 })
    })
  )

  render(<UserList />)

  await screen.findByText(/something went wrong/i)
})
```

---

## Complete Test Examples

### Example 1: Form Submission

```typescript
test('submits login form with valid credentials', async () => {
  const onSubmit = vi.fn()
  const user = userEvent.setup()

  render(<LoginForm onSubmit={onSubmit} />)

  await user.type(screen.getByLabelText(/email/i), 'test@example.com')
  await user.type(screen.getByLabelText(/password/i), 'password123')
  await user.click(screen.getByRole('button', { name: /log in/i }))

  expect(onSubmit).toHaveBeenCalledOnce()
  expect(onSubmit).toHaveBeenCalledWith({
    email: 'test@example.com',
    password: 'password123',
  })
})

test('shows validation errors on empty submit', async () => {
  const user = userEvent.setup()
  render(<LoginForm onSubmit={vi.fn()} />)

  await user.click(screen.getByRole('button', { name: /log in/i }))

  expect(screen.getByText(/email is required/i)).toBeInTheDocument()
  expect(screen.getByText(/password is required/i)).toBeInTheDocument()
})
```

### Example 2: Loading States

```typescript
test('shows loading spinner then data', async () => {
  render(<UserList />)

  // Loading state
  expect(screen.getByRole('progressbar')).toBeInTheDocument()

  // Resolves after MSW responds
  await waitFor(() => {
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
  })

  expect(screen.getByText('Alice')).toBeInTheDocument()
  expect(screen.getByText('Bob')).toBeInTheDocument()
})
```

### Example 3: Conditional Rendering

```typescript
test('shows delete button only for admins', () => {
  render(<UserCard user={user} role="admin" />)
  expect(screen.getByRole('button', { name: /delete/i })).toBeInTheDocument()
})

test('hides delete button for regular users', () => {
  render(<UserCard user={user} role="user" />)
  expect(screen.queryByRole('button', { name: /delete/i })).not.toBeInTheDocument()
})
```

### Example 4: Accessibility Assertions

```typescript
test('modal is accessible', async () => {
  const user = userEvent.setup()
  render(<Modal trigger={<button>Open</button>} title="Settings" />)

  await user.click(screen.getByRole('button', { name: /open/i }))

  const dialog = screen.getByRole('dialog', { name: /settings/i })
  expect(dialog).toBeInTheDocument()
  expect(dialog).toHaveAttribute('aria-modal', 'true')

  // Close with Escape
  await user.keyboard('{Escape}')
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
})
```

### Example 5: Testing Next.js Components

```typescript
// Mock next/navigation
vi.mock('next/navigation', () => ({
  useRouter: vi.fn(() => ({
    push: vi.fn(),
    back: vi.fn(),
    replace: vi.fn(),
  })),
  usePathname: vi.fn(() => '/dashboard'),
  useSearchParams: vi.fn(() => new URLSearchParams()),
}))

// Mock next/router (Pages Router)
vi.mock('next/router', () => ({
  useRouter: vi.fn(() => ({
    route: '/',
    pathname: '/',
    query: {},
    push: vi.fn(),
  })),
}))

test('navigates on button click', async () => {
  const { useRouter } = await import('next/navigation')
  const mockPush = vi.fn()
  vi.mocked(useRouter).mockReturnValue({ push: mockPush } as any)

  const user = userEvent.setup()
  render(<BackButton />)

  await user.click(screen.getByRole('button', { name: /back/i }))
  expect(mockPush).toHaveBeenCalledWith('/dashboard')
})
```

Note: React Server Components cannot be rendered in RTL (they're async functions that run server-side). Test server components via E2E tests (Playwright) or by extracting their logic into testable pure functions.

---

## act() — When You Need It

RTL's `render`, `userEvent`, and `findBy*` already wrap things in `act()`. You only need `act()` explicitly when:

- Triggering state updates outside of RTL utilities (e.g., dispatching Redux actions directly)
- Using `renderHook` and calling returned functions that trigger state updates
- Wrapping timer-based updates when using `vi.useFakeTimers()`

```typescript
// With fake timers
vi.useFakeTimers()
render(<Debounced />)
act(() => {
  vi.advanceTimersByTime(500)
})
expect(screen.getByText('Updated')).toBeInTheDocument()
vi.useRealTimers()
```
