# JavaScript Testing Patterns - Full Reference

Detailed code examples for the js-ts-dev skill. See SKILL.md for summary.

## Jest Config

```typescript
const config: Config = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src"],
  testMatch: ["**/__tests__/**/*.ts", "**/?(*.)+(spec|test).ts"],
  coverageThreshold: { global: { branches: 80, functions: 80, lines: 80, statements: 80 } },
  moduleNameMapper: { "^@/(.*)$": "<rootDir>/src/$1" }, // path aliases
};
```

## Vitest Config

```typescript
export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    coverage: { provider: "v8", reporter: ["text", "json", "html"] },
    include: ["src/**/*.{test,spec}.{ts,tsx}"],
    setupFiles: ["./src/test/setup.ts"],
  },
});
```

## Unit Testing

```typescript
// Pure functions
describe("divide", () => {
  it("should divide two numbers", () => expect(divide(10, 2)).toBe(5));
  it("should throw on zero", () => expect(() => divide(10, 0)).toThrow("Division by zero"));
});

// Async functions
describe("fetchUser", () => {
  it("should fetch successfully", async () => {
    (fetch as any).mockResolvedValueOnce({ ok: true, json: async () => mockUser });
    const user = await service.fetchUser("1");
    expect(user).toEqual(mockUser);
  });
  it("should throw if not found", async () => {
    (fetch as any).mockResolvedValueOnce({ ok: false });
    await expect(service.fetchUser("999")).rejects.toThrow("User not found");
  });
});
```

## Mocking Patterns

```typescript
// Module mock - replace entire module
vi.mock("nodemailer", () => ({
  default: { createTransport: vi.fn(() => ({ sendMail: vi.fn().mockResolvedValue({ messageId: "123" }) })) },
}));

// DI mock - interface-based, preferred for testability
const mockRepository: IUserRepository = { findById: vi.fn(), create: vi.fn() };
const service = new UserService(mockRepository);
vi.mocked(mockRepository.findById).mockResolvedValue(mockUser);

// Spy - observe without replacing
const loggerSpy = vi.spyOn(logger, "info");
await service.processOrder("123");
expect(loggerSpy).toHaveBeenCalledWith("Processing order 123");
loggerSpy.mockRestore();

// Partial mock - keep real implementation, override specific exports
vi.mock("./utils", async () => {
  const actual = await vi.importActual("./utils");
  return { ...actual, sendEmail: vi.fn() };
});

// Mock return sequences
vi.mocked(api.fetch)
  .mockRejectedValueOnce(new Error("Network error")) // 1st call fails
  .mockResolvedValueOnce({ data: "ok" });             // 2nd call succeeds
```

## Timer Mocking

```typescript
it("should call after delay", () => {
  vi.useFakeTimers();
  const callback = vi.fn();
  setTimeout(callback, 1000);
  expect(callback).not.toHaveBeenCalled();
  vi.advanceTimersByTime(1000);
  expect(callback).toHaveBeenCalled();
  vi.useRealTimers();
});

// Date mocking
it("should use mocked date", () => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date("2025-01-01"));
  expect(new Date().getFullYear()).toBe(2025);
  vi.useRealTimers();
});
```

## Integration Testing

```typescript
describe("User API", () => {
  beforeAll(async () => { await pool.query("CREATE TABLE IF NOT EXISTS users (...)"); });
  afterAll(async () => { await pool.query("DROP TABLE IF EXISTS users"); await pool.end(); });
  beforeEach(async () => { await pool.query("TRUNCATE TABLE users CASCADE"); });

  it("should create a user", async () => {
    const res = await request(app).post("/api/users").send({ name: "John", email: "john@example.com", password: "password123" }).expect(201);
    expect(res.body).toHaveProperty("id");
    expect(res.body).not.toHaveProperty("password");
  });

  it("should require auth", async () => {
    await request(app).get("/api/users/me").expect(401);
  });

  // Auth flow test
  it("should login and access protected route", async () => {
    await request(app).post("/api/auth/register").send({ email: "a@b.com", password: "pass1234" });
    const login = await request(app).post("/api/auth/login").send({ email: "a@b.com", password: "pass1234" });
    const token = login.body.token;
    const me = await request(app).get("/api/users/me").set("Authorization", `Bearer ${token}`).expect(200);
    expect(me.body.email).toBe("a@b.com");
  });
});
```

## E2E Testing with Playwright

```typescript
import { test, expect } from "@playwright/test";

test("user signup flow", async ({ page }) => {
  await page.goto("/signup");
  await page.fill('[name="email"]', "test@example.com");
  await page.fill('[name="password"]', "SecurePass123");
  await page.click('button[type="submit"]');
  await expect(page).toHaveURL("/dashboard");
  await expect(page.locator("h1")).toContainText("Welcome");
});

// Playwright config essentials
export default defineConfig({
  testDir: "./e2e",
  use: { baseURL: "http://localhost:3000", screenshot: "only-on-failure" },
  webServer: { command: "npm run dev", port: 3000, reuseExistingServer: !process.env.CI },
});
```

## React Component Testing

```typescript
import { render, screen, fireEvent, waitFor } from '@testing-library/react';

it('should call onSubmit with form data', () => {
  const onSubmit = vi.fn();
  render(<UserForm onSubmit={onSubmit} />);
  fireEvent.change(screen.getByPlaceholderText('Name'), { target: { value: 'John' } });
  fireEvent.change(screen.getByPlaceholderText('Email'), { target: { value: 'john@example.com' } });
  fireEvent.click(screen.getByRole('button', { name: 'Submit' }));
  expect(onSubmit).toHaveBeenCalledWith({ name: 'John', email: 'john@example.com' });
});

// Async component with loading state
it('should show data after loading', async () => {
  render(<UserProfile userId="1" />);
  expect(screen.getByText('Loading...')).toBeInTheDocument();
  await waitFor(() => expect(screen.getByText('John Doe')).toBeInTheDocument());
});
```

## Hook Testing

```typescript
import { renderHook, act } from "@testing-library/react";

it("should increment count", () => {
  const { result } = renderHook(() => useCounter());
  act(() => { result.current.increment(); });
  expect(result.current.count).toBe(1);
});
```

## Test Fixtures

```typescript
import { faker } from "@faker-js/faker";

function createUserFixture(overrides?: Partial<User>): User {
  return {
    id: faker.string.uuid(),
    name: faker.person.fullName(),
    email: faker.internet.email(),
    ...overrides,
  };
}
```

## Best Practices

- **AAA pattern**: Arrange, Act, Assert in every test
- **One concept per test**: Test one behavior, not multiple
- **Test behavior, not implementation**: Refactors should not break tests
- **Use `data-testid` sparingly**: Prefer semantic queries (role, label, text)
- **Mock at boundaries**: External APIs, databases, file system. Not internal modules
- **Coverage target**: 80%+ lines/branches. 100% on critical paths (auth, payments)
- **Organize**: `describe('Class') > describe('method') > it('should...')`
- **Clean up**: `afterEach` for DOM cleanup, `afterAll` for DB connections
