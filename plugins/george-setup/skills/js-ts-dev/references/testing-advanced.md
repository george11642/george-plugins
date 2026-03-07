# Advanced Testing Patterns - Full Reference

Snapshot testing, fixtures, database integration, coverage configuration. See testing.md for basics.

## Snapshot Testing

```typescript
// Inline snapshots - stored in test file, auto-updated with `--updateSnapshot`
import { render } from '@testing-library/react';
import { describe, it, expect } from 'vitest';

it('renders user card correctly', () => {
  const { container } = render(<UserCard name="John" role="admin" />);
  expect(container.firstChild).toMatchInlineSnapshot(`
    <div class="user-card">
      <h2>John</h2>
      <span class="badge">admin</span>
    </div>
  `);
});

// File snapshots - stored in __snapshots__/ directory
it('renders dashboard layout', () => {
  const { container } = render(<Dashboard user={mockUser} />);
  expect(container.firstChild).toMatchSnapshot();
});

// Snapshot of non-DOM values
it('formats API response correctly', () => {
  const result = formatUserResponse(rawApiData);
  expect(result).toMatchInlineSnapshot(`
    {
      "id": "123",
      "displayName": "John Doe",
      "joinedAt": "Jan 2025",
    }
  `);
});

// Update snapshots: vitest --updateSnapshot  OR  jest --updateSnapshot
```

## Test Fixtures with Faker

```typescript
import { faker } from '@faker-js/faker';

// Single entity factory
function createUserFixture(overrides?: Partial<User>): User {
  return {
    id: faker.string.uuid(),
    name: faker.person.fullName(),
    email: faker.internet.email(),
    phone: faker.phone.number(),
    createdAt: faker.date.past(),
    ...overrides,
  };
}

// Related entity factory
function createPostFixture(overrides?: Partial<Post>): Post {
  return {
    id: faker.string.uuid(),
    authorId: faker.string.uuid(),
    title: faker.lorem.sentence(),
    body: faker.lorem.paragraphs(2),
    tags: faker.helpers.arrayElements(['tech', 'news', 'guide', 'tutorial'], 2),
    publishedAt: faker.date.recent(),
    ...overrides,
  };
}

// Batch factory
function createUsersFixture(count: number, overrides?: Partial<User>): User[] {
  return Array.from({ length: count }, () => createUserFixture(overrides));
}

// Nested/related data
function createOrderWithItemsFixture() {
  const user = createUserFixture();
  const items = Array.from({ length: faker.number.int({ min: 1, max: 5 }) }, () => ({
    productId: faker.string.uuid(),
    productName: faker.commerce.productName(),
    quantity: faker.number.int({ min: 1, max: 10 }),
    price: parseFloat(faker.commerce.price()),
  }));
  return {
    id: faker.string.uuid(),
    userId: user.id,
    user,
    items,
    total: items.reduce((sum, item) => sum + item.price * item.quantity, 0),
    status: faker.helpers.arrayElement(['pending', 'paid', 'shipped', 'delivered']),
  };
}

// Usage: pin specific values when assertions depend on them
it('sends welcome email with user name', async () => {
  const user = createUserFixture({ email: 'john@test.com', name: 'John Doe' });
  await emailService.sendWelcome(user);
  expect(mockTransport.sentMail[0].to).toBe('john@test.com');
  expect(mockTransport.sentMail[0].text).toContain('John Doe');
});
```

## Advanced Mocking Patterns

```typescript
// Return sequences - simulate retry/eventual success
vi.mocked(api.fetchData)
  .mockRejectedValueOnce(new Error('Network timeout'))    // 1st call: fail
  .mockRejectedValueOnce(new Error('Service unavailable')) // 2nd call: fail
  .mockResolvedValueOnce({ data: 'ok', status: 200 });    // 3rd call: succeed

it('retries on failure', async () => {
  const result = await fetchWithRetry('/api/data', 3);
  expect(api.fetchData).toHaveBeenCalledTimes(3);
  expect(result.data).toBe('ok');
});

// Implementation switching per test
const mockDbQuery = vi.fn()
  .mockResolvedValueOnce([])                              // first call: empty
  .mockResolvedValueOnce([{ id: '1', name: 'Alice' }]);  // second call: data

// Partial mock - preserve real implementations
vi.mock('./config', async () => {
  const actual = await vi.importActual('./config');
  return {
    ...actual,
    MAX_RETRIES: 2,  // override just this
    API_URL: 'http://localhost:3001',
  };
});

// Mock a class constructor
vi.mock('./EmailService', () => ({
  EmailService: vi.fn().mockImplementation(() => ({
    send: vi.fn().mockResolvedValue({ messageId: 'test-123' }),
    verify: vi.fn().mockResolvedValue(true),
  })),
}));

// Capture arguments for later assertion
const capturedCalls: any[] = [];
vi.mocked(logger.info).mockImplementation((...args) => {
  capturedCalls.push(args);
});
```

## Database Integration Tests

### Postgres with Transaction Rollback

```typescript
import { Pool, PoolClient } from 'pg';

describe('UserRepository integration', () => {
  let pool: Pool;
  let client: PoolClient;

  beforeAll(async () => {
    pool = new Pool({ connectionString: process.env.TEST_DATABASE_URL });
  });

  afterAll(async () => {
    await pool.end();
  });

  // Transaction rollback: each test runs in a transaction that's rolled back
  // This is faster than TRUNCATE and avoids test pollution
  beforeEach(async () => {
    client = await pool.connect();
    await client.query('BEGIN');
  });

  afterEach(async () => {
    await client.query('ROLLBACK');
    client.release();
  });

  it('creates a user', async () => {
    const repo = new UserRepository(client as unknown as Pool);
    const user = await repo.create({ name: 'Alice', email: 'alice@test.com', password: 'hashed' });

    expect(user.id).toBeDefined();
    expect(user.name).toBe('Alice');

    // Verify in same transaction
    const found = await repo.findById(user.id);
    expect(found).not.toBeNull();
  });

  it('enforces unique email constraint', async () => {
    const repo = new UserRepository(client as unknown as Pool);
    await repo.create({ name: 'Bob', email: 'bob@test.com', password: 'hashed' });

    await expect(
      repo.create({ name: 'Bob2', email: 'bob@test.com', password: 'hashed' }),
    ).rejects.toThrow(/unique/i);
  });
});
```

### Testcontainers for Postgres

```typescript
import { PostgreSqlContainer, StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { Pool } from 'pg';

describe('UserRepository with testcontainers', () => {
  let container: StartedPostgreSqlContainer;
  let pool: Pool;

  beforeAll(async () => {
    container = await new PostgreSqlContainer('postgres:15')
      .withDatabase('testdb')
      .withUsername('testuser')
      .withPassword('testpass')
      .start();

    pool = new Pool({ connectionString: container.getConnectionUri() });

    // Run migrations
    await pool.query(`
      CREATE TABLE users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `);
  }, 60_000); // containers can take a moment to start

  afterAll(async () => {
    await pool.end();
    await container.stop();
  });

  beforeEach(async () => {
    await pool.query('TRUNCATE TABLE users CASCADE');
  });

  it('finds user by email', async () => {
    await pool.query(
      'INSERT INTO users (name, email, password) VALUES ($1, $2, $3)',
      ['Charlie', 'charlie@test.com', 'hashed'],
    );
    const repo = new UserRepository(pool);
    const user = await repo.findByEmail('charlie@test.com');
    expect(user?.name).toBe('Charlie');
  });
});
```

## Coverage Configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',  // or 'istanbul'
      reporter: ['text', 'json', 'html', 'lcov'],  // lcov for CI integrations
      reportsDirectory: './coverage',
      include: ['src/**/*.{ts,tsx}'],
      exclude: [
        '**/*.d.ts',
        '**/*.config.ts',
        '**/dist/**',
        '**/node_modules/**',
        'src/types/**',
        'src/**/*.test.ts',
      ],
      // Fail CI if thresholds not met
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 75,
        statements: 80,
        // Per-file thresholds for critical paths:
        // 'src/auth/**': { lines: 95, branches: 90 },
      },
    },
  },
});

// jest.config.ts equivalent
const config: Config = {
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts', '!src/**/index.ts'],
  coverageReporters: ['text', 'json', 'html', 'lcov'],
  coverageDirectory: 'coverage',
  coverageThreshold: {
    global: { branches: 75, functions: 80, lines: 80, statements: 80 },
    './src/auth/': { branches: 90, functions: 95, lines: 95, statements: 95 },
  },
};
```

```json
// package.json scripts
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:coverage": "vitest run --coverage",
    "test:ui": "vitest --ui",
    "test:watch": "vitest --watch"
  }
}
```

## MSW (Mock Service Worker) for API Mocking

```typescript
// Intercepts actual HTTP calls - works in both browser and Node
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';

const handlers = [
  http.get('/api/users/:id', ({ params }) => {
    return HttpResponse.json({ id: params.id, name: 'Test User' });
  }),
  http.post('/api/users', async ({ request }) => {
    const body = await request.json() as any;
    return HttpResponse.json({ id: 'new-id', ...body }, { status: 201 });
  }),
  http.get('/api/error', () => {
    return HttpResponse.json({ message: 'Server error' }, { status: 500 });
  }),
];

const server = setupServer(...handlers);

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// Override handler for specific test
it('handles 404', async () => {
  server.use(
    http.get('/api/users/:id', () => {
      return HttpResponse.json({ message: 'Not found' }, { status: 404 });
    }),
  );
  await expect(userService.getById('999')).rejects.toThrow('Not found');
});
```
