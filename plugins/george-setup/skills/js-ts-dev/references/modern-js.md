# Modern JavaScript Patterns - Full Reference

Detailed code examples for the js-ts-dev skill. See SKILL.md for summary.

## Arrow Functions

```javascript
const add = (a, b) => a + b;
const double = x => x * 2;
const createUser = (name, age) => ({ name, age }); // return object

// Lexical this
class Counter {
  count = 0;
  increment = () => { this.count++; }; // arrow preserves this
  delayed() {
    setTimeout(() => { this.count++; }, 1000); // arrow preserves this
  }
}
```

## Destructuring

```javascript
// Object
const { name, email } = user;
const { name: userName, age = 25 } = user;
const { address: { city } } = user;
const { id, ...rest } = user;

// Array
const [first, ...tail] = numbers;
const [, , third] = numbers; // skip
let a = 1, b = 2; [a, b] = [b, a]; // swap

// Function params
function greet({ name, age = 18 }) { console.log(`Hello ${name}`); }
```

## Spread & Rest

```javascript
const combined = [...arr1, ...arr2];
const settings = { ...defaults, ...userPrefs };
const copy = [...arr]; const objCopy = { ...obj };
function sum(...numbers) { return numbers.reduce((t, n) => t + n, 0); }
```

## Modules (ES6)

```javascript
// Named exports
export const PI = 3.14159;
export function add(a, b) { return a + b; }

// Default export
export default class Calculator { /* ... */ }

// Importing
import Calculator, { PI, add } from "./math.js";
import { add as sum } from "./math.js";
import * as Math from "./math.js";

// Dynamic imports - code splitting, conditional loading
const module = await import("./feature.js");
if (condition) {
  const { init } = await import("./optional-feature.js");
  init();
}
```

## Promises

```javascript
Promise.all([p1, p2, p3]);        // fail-fast, all must succeed
Promise.allSettled([p1, p2, p3]); // wait for all, get status
Promise.race([p1, p2]);           // first to settle
Promise.any([p1, p2]);            // first to succeed (ignores rejections)

// Creating promises
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Sequential promise execution from array
async function sequential(tasks) {
  const results = [];
  for (const task of tasks) {
    results.push(await task());
  }
  return results;
}
```

## Async/Await

```javascript
// Sequential vs parallel
const [a, b] = await Promise.all([fetchA(), fetchB()]); // parallel

// Retry with exponential backoff
async function fetchWithRetry(url, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try { return await fetch(url); }
    catch (e) {
      if (i === retries - 1) throw e;
      await new Promise(r => setTimeout(r, 1000 * 2 ** i));
    }
  }
}

// Timeout wrapper
async function withTimeout(promise, ms) {
  return Promise.race([promise, new Promise((_, reject) => setTimeout(() => reject(new Error("Timeout")), ms))]);
}

// Async error boundary
async function safe(fn) {
  try { return [await fn(), null]; }
  catch (e) { return [null, e]; }
}
const [data, error] = await safe(() => fetch("/api"));
```

## Functional Patterns

```javascript
// Currying
const multiply = a => b => a * b;
const double = multiply(2);

// Partial application
const partial = (fn, ...first) => (...rest) => fn(...first, ...rest);
const add10 = partial(add, 10);

// Memoization
function memoize(fn) {
  const cache = new Map();
  return (...args) => {
    const key = JSON.stringify(args);
    if (cache.has(key)) return cache.get(key);
    const result = fn(...args);
    cache.set(key, result);
    return result;
  };
}

// Pipe & compose
const pipe = (...fns) => x => fns.reduce((acc, fn) => fn(acc), x);
const compose = (...fns) => x => fns.reduceRight((acc, fn) => fn(acc), x);

// Practical pipe example
const processUser = pipe(
  normalize,      // lowercase email
  validate,       // check required fields
  hashPassword,   // security
  save,           // persist
);
```

## Immutability

```javascript
// Array ops (no mutation)
const withItem = [...arr, newItem];
const without = arr.filter(x => x !== target);
const updated = arr.map(x => x.id === id ? { ...x, ...changes } : x);

// Object ops
const updated = { ...obj, key: newValue };
const { removed, ...rest } = obj;

// Deep clone
const clone = structuredClone(obj);

// Frozen objects (shallow freeze)
const config = Object.freeze({ api: "https://...", timeout: 5000 });
```

## Iterators & Generators

```javascript
// Custom iterator protocol
const range = {
  from: 1, to: 5,
  [Symbol.iterator]() {
    let current = this.from;
    const last = this.to;
    return { next() { return current <= last ? { done: false, value: current++ } : { done: true }; } };
  },
};

// Generator function
function* range(from, to) {
  for (let i = from; i <= to; i++) yield i;
}

// Infinite generator
function* fibonacci() {
  let [prev, curr] = [0, 1];
  while (true) { yield curr; [prev, curr] = [curr, prev + curr]; }
}

// Async generator - paginated API fetching
async function* fetchPages(url) {
  let page = 1;
  while (true) {
    const data = await fetch(`${url}?page=${page}`).then(r => r.json());
    if (!data.length) break;
    yield data;
    page++;
  }
}

for await (const page of fetchPages("/api/users")) {
  console.log(page);
}

// Generator as lazy pipeline
function* map(iterable, fn) { for (const x of iterable) yield fn(x); }
function* filter(iterable, fn) { for (const x of iterable) if (fn(x)) yield x; }
function* take(iterable, n) { let i = 0; for (const x of iterable) { if (i++ >= n) break; yield x; } }

// Process millions lazily: only computes what's needed
const result = [...take(filter(map(hugeArray, x => x * 2), x => x > 100), 10)];
```

## Modern Class Features

```javascript
class User {
  #password;           // private field
  static count = 0;    // static field

  constructor(name, password) {
    this.name = name;
    this.#password = password;
    User.count++;
  }

  get displayName() { return this.name.toUpperCase(); }
  set password(v) { this.#password = this.#hash(v); }
  #hash(v) { return `hashed_${v}`; } // private method
}
```

## Modern Operators

```javascript
user?.address?.city          // optional chaining
value ?? 'default'           // nullish coalescing (null/undefined only)
a ??= 'default'             // logical nullish assignment
obj.count ||= 1             // logical OR assignment
obj.count &&= 2             // logical AND assignment
```

## Performance Utilities

```javascript
function debounce(fn, delay) {
  let id;
  return (...args) => { clearTimeout(id); id = setTimeout(() => fn(...args), delay); };
}

function throttle(fn, limit) {
  let blocked;
  return (...args) => {
    if (!blocked) { fn(...args); blocked = true; setTimeout(() => blocked = false, limit); }
  };
}

// AbortController for cancellable fetch
const controller = new AbortController();
fetch("/api/data", { signal: controller.signal }).catch(e => {
  if (e.name === "AbortError") console.log("Request cancelled");
});
controller.abort(); // cancel the request
```
