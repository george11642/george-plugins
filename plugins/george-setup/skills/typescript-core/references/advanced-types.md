# TypeScript Advanced Types - Full Reference

Detailed code examples for the js-ts-dev skill. See SKILL.md for summary.

## Generics

```typescript
// Basic generic function
function identity<T>(value: T): T { return value; }

// Constraints
interface HasLength { length: number; }
function logLength<T extends HasLength>(item: T): T {
  console.log(item.length);
  return item;
}

// Multiple type parameters
function merge<T, U>(obj1: T, obj2: U): T & U {
  return { ...obj1, ...obj2 };
}

// Generic with default
type Container<T = string> = { value: T };
```

## Conditional Types

```typescript
type IsString<T> = T extends string ? true : false;
type ReturnType<T> = T extends (...args: any[]) => infer R ? R : never;
type ToArray<T> = T extends any ? T[] : never; // distributive

type TypeName<T> = T extends string ? "string"
  : T extends number ? "number"
  : T extends boolean ? "boolean"
  : T extends Function ? "function"
  : "object";

// Extract array element type
type ElementType<T> = T extends (infer U)[] ? U : never;

// Extract promise type (unwrap nested promises)
type Awaited<T> = T extends Promise<infer U> ? Awaited<U> : T;

// Extract function parameters
type Parameters<T> = T extends (...args: infer P) => any ? P : never;
```

## Mapped Types

```typescript
// Key remapping
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};

// Filtering by value type
type PickByType<T, U> = {
  [K in keyof T as T[K] extends U ? K : never]: T[K];
};

// Make all methods async
type Asyncify<T> = {
  [K in keyof T]: T[K] extends (...args: infer A) => infer R
    ? (...args: A) => Promise<R>
    : T[K];
};
```

## Template Literal Types

```typescript
type EventName = "click" | "focus" | "blur";
type EventHandler = `on${Capitalize<EventName>}`; // "onClick" | "onFocus" | "onBlur"

// Recursive path builder for dot-notation access
type Path<T> = T extends object
  ? { [K in keyof T]: K extends string ? `${K}` | `${K}.${Path<T[K]>}` : never }[keyof T]
  : never;

// Type-safe CSS units
type CSSUnit = "px" | "rem" | "em" | "vh" | "vw" | "%";
type CSSValue = `${number}${CSSUnit}`;
```

## Pattern: Type-Safe Event Emitter

```typescript
type EventMap = {
  "user:created": { id: string; name: string };
  "user:deleted": { id: string };
};

class TypedEventEmitter<T extends Record<string, any>> {
  private listeners: { [K in keyof T]?: Array<(data: T[K]) => void> } = {};

  on<K extends keyof T>(event: K, callback: (data: T[K]) => void): void {
    if (!this.listeners[event]) this.listeners[event] = [];
    this.listeners[event]!.push(callback);
  }

  off<K extends keyof T>(event: K, callback: (data: T[K]) => void): void {
    this.listeners[event] = this.listeners[event]?.filter(cb => cb !== callback);
  }

  emit<K extends keyof T>(event: K, data: T[K]): void {
    this.listeners[event]?.forEach(cb => cb(data));
  }
}
```

## Pattern: Type-Safe API Client

```typescript
type EndpointConfig = {
  "/users": {
    GET: { response: User[] };
    POST: { body: { name: string; email: string }; response: User };
  };
  "/users/:id": {
    GET: { params: { id: string }; response: User };
    DELETE: { params: { id: string }; response: void };
  };
};

type ExtractParams<T> = T extends { params: infer P } ? P : never;
type ExtractBody<T> = T extends { body: infer B } ? B : never;
type ExtractResponse<T> = T extends { response: infer R } ? R : never;
```

## Pattern: Builder with Type-Level Tracking

Why: Prevents calling `build()` until all required fields are set. Compile-time safety.

```typescript
type RequiredKeys<T> = {
  [K in keyof T]-?: {} extends Pick<T, K> ? never : K;
}[keyof T];

class Builder<T, Set extends keyof T = never> {
  private state: Partial<T> = {};

  set<K extends keyof T>(key: K, value: T[K]): Builder<T, Set | K> {
    (this.state as any)[key] = value;
    return this as any;
  }

  // build() only available when all required keys are set
  build(this: RequiredKeys<T> extends Set ? Builder<T, Set> : never): T {
    return this.state as T;
  }
}

interface UserConfig { id: string; name: string; email: string; age?: number; }
const user = new Builder<UserConfig>()
  .set("id", "1").set("name", "John").set("email", "j@x.com")
  .build(); // OK - all required fields set
// new Builder<UserConfig>().set("id", "1").build(); // Error!
```

## Pattern: Type-Safe Form Validation

```typescript
type ValidationRule<T> = { validate: (value: T) => boolean; message: string };
type FieldValidation<T> = { [K in keyof T]?: ValidationRule<T[K]>[] };
type ValidationErrors<T> = { [K in keyof T]?: string[] };

class FormValidator<T extends Record<string, any>> {
  constructor(private rules: FieldValidation<T>) {}

  validate(data: T): ValidationErrors<T> | null {
    const errors: ValidationErrors<T> = {};
    let hasErrors = false;
    for (const key in this.rules) {
      const fieldErrors = this.rules[key]!
        .filter(rule => !rule.validate(data[key]))
        .map(rule => rule.message);
      if (fieldErrors.length) { errors[key] = fieldErrors; hasErrors = true; }
    }
    return hasErrors ? errors : null;
  }
}
```

## Pattern: Deep Readonly/Partial

```typescript
type DeepReadonly<T> = {
  readonly [P in keyof T]: T[P] extends object
    ? T[P] extends Function ? T[P] : DeepReadonly<T[P]>
    : T[P];
};

type DeepPartial<T> = {
  [P in keyof T]?: T[P] extends object
    ? T[P] extends Array<infer U> ? Array<DeepPartial<U>> : DeepPartial<T[P]>
    : T[P];
};
```

## Pattern: Discriminated Unions

```typescript
type AsyncState<T> =
  | { status: "success"; data: T }
  | { status: "error"; error: string }
  | { status: "loading" };

function handleState<T>(state: AsyncState<T>): void {
  switch (state.status) {
    case "success": console.log(state.data); break;
    case "error": console.log(state.error); break;
    case "loading": console.log("Loading..."); break;
  }
}

// Exhaustive check helper
function assertNever(x: never): never {
  throw new Error(`Unexpected value: ${x}`);
}
```

## Type Guards & Assertions

```typescript
function isString(value: unknown): value is string {
  return typeof value === "string";
}

function assertIsString(value: unknown): asserts value is string {
  if (typeof value !== "string") throw new Error("Not a string");
}

// Composable guard
function isArrayOf<T>(value: unknown, guard: (item: unknown) => item is T): value is T[] {
  return Array.isArray(value) && value.every(guard);
}
```

## Type Testing

```typescript
type AssertEqual<T, U> = [T] extends [U] ? [U] extends [T] ? true : false : false;
type Test1 = AssertEqual<string, string>; // true
type Test2 = AssertEqual<string, number>; // false

// Expect error helper - use to verify types that SHOULD fail
type ExpectError<T extends never> = T;
```

## Const Type Parameters (TS 5.0+)

```typescript
// `const` modifier infers literal types instead of widening
declare function fn<const T extends readonly unknown[]>(...args: T): T;
const result = fn("a", 1, true); // readonly ["a", 1, true] — not (string | number | boolean)[]

// Useful for config/route definitions
declare function defineRoutes<const T extends Record<string, string>>(routes: T): T;
const routes = defineRoutes({ home: "/", about: "/about" });
// typeof routes = { home: "/"; about: "/about" } — literal types preserved
```

## TypeScript 5.8+ Features

### `--erasableSyntaxOnly` Flag
Errors on TypeScript constructs with runtime behavior (enums, parameter properties, namespaces).
Use when targeting Node.js type-stripping (`--experimental-strip-types`) which only strips erasable syntax.

### Improved Return Type Narrowing
```typescript
// TS 5.8 narrows conditional expressions directly in return statements
function getLabel(status: "ok" | "err"): string {
  return status === "ok" ? "Success" : "Failure"; // each branch checked against return type
}
```

### TypeScript 5.9 (Preview)
- Conditional types with `extends` inlining for performance
- `--target es2024` support (from 5.7)
- `--rewriteRelativeImportExtensions` auto-rewrites `.ts` -> `.js` in output

## Common Pitfalls

- Over-using `any` defeats TypeScript's purpose. Use `unknown` and narrow
- Deeply nested conditional types slow the compiler. Keep recursion under 5 levels
- Circular type references cause hard-to-debug errors. Use interfaces to break cycles
- Forgetting `readonly` allows unintended mutations of config/state objects
- `--erasableSyntaxOnly` is required when using Node.js native TS execution (type stripping)
