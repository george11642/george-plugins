# Advanced JavaScript Patterns - Full Reference

Proxy/Reflect, Symbol, WeakMap/WeakSet, private class fields, tagged templates, async iteration. See modern-js.md for core ES6+.

## Proxy and Reflect

```javascript
// Validation proxy - enforce invariants on every property set
function createValidatedUser(data) {
  const validators = {
    age: (v) => typeof v === 'number' && v >= 0 && v <= 150,
    email: (v) => typeof v === 'string' && v.includes('@'),
    name: (v) => typeof v === 'string' && v.length > 0,
  };

  return new Proxy({ ...data }, {
    set(target, prop, value) {
      const validate = validators[prop];
      if (validate && !validate(value)) {
        throw new TypeError(`Invalid value for ${String(prop)}: ${value}`);
      }
      return Reflect.set(target, prop, value);  // Reflect preserves semantics
    },
    get(target, prop) {
      return Reflect.get(target, prop);
    },
  });
}

const user = createValidatedUser({ name: 'Alice', age: 30, email: 'alice@x.com' });
user.age = 25;       // OK
user.age = -1;       // Throws: Invalid value for age: -1
user.email = 'bad';  // Throws: Invalid value for email: bad

// Logging proxy - observe all property access and mutation
function createObservable(target, onChange) {
  return new Proxy(target, {
    get(obj, prop) {
      const value = Reflect.get(obj, prop);
      // Proxy nested objects too
      return value !== null && typeof value === 'object'
        ? createObservable(value, onChange)
        : value;
    },
    set(obj, prop, value) {
      const old = obj[prop];
      const result = Reflect.set(obj, prop, value);
      if (old !== value) onChange({ prop: String(prop), old, new: value });
      return result;
    },
    deleteProperty(obj, prop) {
      const result = Reflect.deleteProperty(obj, prop);
      onChange({ prop: String(prop), deleted: true });
      return result;
    },
  });
}

const state = createObservable({ count: 0, name: 'app' }, (change) => {
  console.log('State changed:', change);
});
state.count = 1;  // Logs: State changed: { prop: 'count', old: 0, new: 1 }

// Default values proxy - never throws on missing keys
const config = new Proxy({}, {
  get(target, prop) {
    return prop in target ? target[prop] : null;
  },
});
config.missingKey;  // null, not undefined/error

// Revocable proxy - useful for temporary API access tokens
const { proxy: tempAccess, revoke } = Proxy.revocable(sensitiveData, {
  get(target, prop) {
    return Reflect.get(target, prop);
  },
});
// Later: deny all further access
revoke();
tempAccess.anything;  // Throws TypeError
```

## Symbol

```javascript
// Unique identifiers - Symbol('x') !== Symbol('x')
const ID = Symbol('id');
const obj = { [ID]: 'internal-id-123', name: 'public' };
obj[ID];                   // 'internal-id-123'
JSON.stringify(obj);       // '{"name":"public"}' — symbols are excluded
Object.keys(obj);          // ['name'] — symbols are non-enumerable

// Well-known symbols — override built-in JS behaviors
class Collection {
  #items;

  constructor(...items) { this.#items = items; }

  // Make it iterable with for...of
  [Symbol.iterator]() {
    let index = 0;
    return {
      next: () => index < this.#items.length
        ? { done: false, value: this.#items[index++] }
        : { done: true, value: undefined },
    };
  }

  // Control instanceof behavior
  static [Symbol.hasInstance](instance) {
    return Array.isArray(instance['__isCollection']);
  }

  // Control what happens in template literals
  [Symbol.toPrimitive](hint) {
    if (hint === 'number') return this.#items.length;
    if (hint === 'string') return `Collection(${this.#items.join(', ')})`;
    return this.#items.length;
  }
}

const c = new Collection(1, 2, 3);
for (const item of c) console.log(item);  // 1, 2, 3
`${c}`;   // 'Collection(1, 2, 3)'
+c;       // 3

// Symbol.for — global symbol registry, shared across modules/realms
const SHARED = Symbol.for('app.sharedKey');
Symbol.for('app.sharedKey') === SHARED;  // true (same symbol)
Symbol.keyFor(SHARED);                   // 'app.sharedKey'

// Simulate private metadata without WeakMap
const _validate = Symbol('validate');
class Form {
  [_validate](field, value) { /* not truly private but non-enumerable */ }
  submit(data) { this[_validate]('email', data.email); }
}
```

## WeakMap and WeakSet

```javascript
// WeakMap: keys must be objects, not prevented from GC — no memory leaks
const cache = new WeakMap();

function expensiveCompute(obj) {
  if (cache.has(obj)) return cache.get(obj);
  const result = /* expensive operation */ ({ processed: obj.value * 2 });
  cache.set(obj, result);
  return result;
}

// When obj goes out of scope, WeakMap entry is automatically GC'd
// Unlike Map, which would keep obj alive forever

// Private data pattern (before # syntax)
const _privateData = new WeakMap();

class BankAccount {
  constructor(balance) {
    _privateData.set(this, { balance, transactions: [] });
  }

  deposit(amount) {
    const data = _privateData.get(this);
    data.balance += amount;
    data.transactions.push({ type: 'deposit', amount, date: new Date() });
  }

  get balance() {
    return _privateData.get(this).balance;
  }
}

const account = new BankAccount(1000);
account.balance;                 // 1000
_privateData.get(account);      // accessible but requires the WeakMap reference

// DOM element metadata — auto-cleaned when element is removed
const elementMeta = new WeakMap();

function attachTooltip(element, text) {
  elementMeta.set(element, { tooltip: text, shown: false });
  element.addEventListener('mouseenter', () => {
    const meta = elementMeta.get(element);
    if (!meta.shown) { showTooltip(text); meta.shown = true; }
  });
}
// When element is removed from DOM, WeakMap entry is eligible for GC

// WeakSet: track object identity without preventing GC
const processing = new WeakSet();

async function processOnce(task) {
  if (processing.has(task)) return;  // already running
  processing.add(task);
  try {
    await task.run();
  } finally {
    processing.delete(task);
  }
}

// Track visited nodes in a graph traversal without mutation
function detectCycle(node) {
  const visited = new WeakSet();
  function dfs(current) {
    if (visited.has(current)) return true;
    visited.add(current);
    return current.children?.some(dfs) ?? false;
  }
  return dfs(node);
}
```

## Private Class Fields and Static Blocks

```javascript
class Config {
  // Private fields — truly inaccessible outside the class
  #apiKey;
  #baseUrl;
  #timeout;

  // Private static field
  static #instances = new Map();

  // Static initialization block — runs once when class is defined
  // Use for complex static setup that can't fit in a field initializer
  static {
    Config.#instances.set('default', new Config({
      apiKey: process.env.API_KEY ?? '',
      baseUrl: process.env.API_URL ?? 'http://localhost:3000',
      timeout: 5000,
    }));
    console.log('Config class initialized');
  }

  constructor({ apiKey, baseUrl, timeout = 5000 }) {
    this.#apiKey = apiKey;
    this.#baseUrl = baseUrl;
    this.#timeout = timeout;
  }

  static getInstance(name = 'default') {
    return Config.#instances.get(name);
  }

  // Private method
  #buildHeaders() {
    return { 'X-API-Key': this.#apiKey, 'Content-Type': 'application/json' };
  }

  async fetch(path) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.#timeout);
    try {
      return await fetch(`${this.#baseUrl}${path}`, {
        headers: this.#buildHeaders(),
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timer);
    }
  }

  // Check if object is an instance (useful for validation)
  static isConfig(obj) {
    try {
      obj.#apiKey;  // throws if obj isn't a Config instance
      return true;
    } catch {
      return false;
    }
  }
}

const config = Config.getInstance();
config.fetch('/users');       // works
config.#apiKey;               // SyntaxError: Private field not accessible
```

## Tagged Template Literals

```javascript
// SQL query builder — prevents injection, adds type safety
function sql(strings, ...values) {
  const query = strings.reduce((acc, str, i) => {
    return acc + str + (i < values.length ? `$${i + 1}` : '');
  }, '');
  return { query, params: values };
}

const userId = '123';
const minAge = 18;
const { query, params } = sql`
  SELECT * FROM users
  WHERE id = ${userId} AND age >= ${minAge}
`;
// query: 'SELECT * FROM users WHERE id = $1 AND age >= $2'
// params: ['123', 18]

// HTML escaping tag — XSS prevention
function html(strings, ...values) {
  const escape = (v) => String(v)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
  return strings.reduce((acc, str, i) => acc + str + (i < values.length ? escape(values[i]) : ''), '');
}

const userInput = '<script>alert("xss")</script>';
const safeHtml = html`<p>Hello, ${userInput}!</p>`;
// '<p>Hello, &lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;!</p>'

// Styled-components pattern — CSS-in-JS
function css(strings, ...values) {
  return strings.reduce((acc, str, i) => {
    const value = values[i];
    const resolved = typeof value === 'function' ? value({}) : value ?? '';
    return acc + str + resolved;
  }, '');
}

// i18n/localization tag
const messages = { greeting: 'Hola', farewell: 'Adiós' };
function i18n(strings, ...keys) {
  return strings.reduce((acc, str, i) => {
    const key = keys[i];
    return acc + str + (key ? (messages[key] ?? key) : '');
  }, '');
}

const greeting = i18n`${'greeting'}, world!`;  // 'Hola, world!'

// Highlight tag — debugging aid
function debug(strings, ...values) {
  return strings.reduce((acc, str, i) => {
    if (i < values.length) {
      const v = values[i];
      const type = typeof v;
      return acc + str + `[${type}:${JSON.stringify(v)}]`;
    }
    return acc + str;
  }, '');
}

debug`User ${user.name} has ${user.items.length} items`;
// 'User [string:"Alice"] has [number:5] items'
```

## Async Generators and Iteration

```javascript
// Async generator — produce values asynchronously
async function* paginate(url, pageSize = 20) {
  let page = 1;
  let hasMore = true;

  while (hasMore) {
    const response = await fetch(`${url}?page=${page}&limit=${pageSize}`);
    const { data, total } = await response.json();

    for (const item of data) yield item;  // yield one at a time

    hasMore = page * pageSize < total;
    page++;
  }
}

// Consume with for-await-of
for await (const user of paginate('/api/users')) {
  await processUser(user);
}

// Collect all
const allUsers = [];
for await (const user of paginate('/api/users')) {
  allUsers.push(user);
}

// Async pipeline — transform streams of data
async function* map(source, transform) {
  for await (const item of source) {
    yield await transform(item);
  }
}

async function* filter(source, predicate) {
  for await (const item of source) {
    if (await predicate(item)) yield item;
  }
}

async function* take(source, n) {
  let count = 0;
  for await (const item of source) {
    yield item;
    if (++count >= n) return;
  }
}

// Compose pipeline: fetch → filter active → map to summary → take first 10
const pipeline = take(
  map(
    filter(paginate('/api/users'), user => user.active),
    user => ({ id: user.id, name: user.name }),
  ),
  10,
);

for await (const summary of pipeline) {
  console.log(summary);
}

// Convert async generator to array helper
async function toArray(source) {
  const result = [];
  for await (const item of source) result.push(item);
  return result;
}

// Merge multiple async iterables
async function* merge(...sources) {
  await Promise.all(sources.map(async (source) => {
    for await (const item of source) yield item;
  }));
}

// Rate-limited async generator
async function* rateLimited(source, delayMs) {
  for await (const item of source) {
    yield item;
    await new Promise(resolve => setTimeout(resolve, delayMs));
  }
}

// Real-time event stream (SSE / WebSocket wrapper)
async function* sseStream(url) {
  const eventSource = new EventSource(url);
  const queue = [];
  let resolve;

  eventSource.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (resolve) { resolve(data); resolve = null; }
    else queue.push(data);
  };

  try {
    while (true) {
      if (queue.length > 0) {
        yield queue.shift();
      } else {
        yield await new Promise(r => { resolve = r; });
      }
    }
  } finally {
    eventSource.close();
  }
}
```
