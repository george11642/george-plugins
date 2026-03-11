# Build Tools: Modern (Vite, esbuild, Turbopack, tsconfig, ESLint)

## Vite

Vite is the default choice for new frontend projects. Dev server uses native ESM; production builds use Rollup (Rolldown in Vite 7+).

### vite.config.ts Structure

```typescript
import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react-swc'
import { resolve } from 'path'

export default defineConfig(({ command, mode }) => {
  const env = loadEnv(mode, process.cwd(), '')

  return {
    plugins: [
      react(), // uses SWC — faster than Babel-based plugin
    ],

    resolve: {
      alias: {
        '@': resolve(__dirname, 'src'),
        '@components': resolve(__dirname, 'src/components'),
        '@utils': resolve(__dirname, 'src/utils'),
        '@hooks': resolve(__dirname, 'src/hooks'),
      },
    },

    server: {
      port: 3000,
      proxy: {
        '/api': {
          target: 'http://localhost:4000',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api/, ''),
        },
      },
    },

    build: {
      target: 'baseline-widely-available', // Vite 7+ default
      sourcemap: mode !== 'production',
      rollupOptions: {
        output: {
          manualChunks: {
            vendor: ['react', 'react-dom'],
            router: ['react-router-dom'],
            ui: ['@radix-ui/react-dialog', '@radix-ui/react-dropdown-menu'],
          },
        },
      },
    },

    // Pre-bundle CJS deps for faster dev starts
    optimizeDeps: {
      include: ['react', 'react-dom', 'axios'],
    },
  }
})
```

### Plugin Ecosystem

| Plugin | Purpose |
|--------|---------|
| `@vitejs/plugin-react` | React support via Babel (slower but more plugin-compatible) |
| `@vitejs/plugin-react-swc` | React support via SWC (faster, use by default) |
| `vite-plugin-svgr` | Import SVGs as React components |
| `rollup-plugin-visualizer` | Bundle size visualizer — run after build |
| `vite-plugin-pwa` | Progressive Web App manifest + service worker |
| `vite-tsconfig-paths` | Resolve TS path aliases automatically |
| `@vitejs/plugin-vue` | Vue 3 SFC support |

```typescript
// rollup-plugin-visualizer usage
import { visualizer } from 'rollup-plugin-visualizer'

plugins: [
  react(),
  visualizer({ open: true, gzipSize: true }), // generates stats.html after build
]
```

### HMR Configuration

Vite's HMR is automatic for React (via Fast Refresh). For custom HMR behavior in plugins:

```typescript
// In a Vite plugin
handleHotUpdate({ file, server, modules }) {
  if (file.endsWith('.data.ts')) {
    // Invalidate all modules that import this file
    server.ws.send({ type: 'full-reload' })
    return []
  }
  // Default HMR for other files
}
```

For client-side HMR acceptance in a module:
```typescript
if (import.meta.hot) {
  import.meta.hot.accept('./dep', (newDep) => {
    // re-run module with new dep
  })
  import.meta.hot.dispose(() => {
    // cleanup before module is replaced
  })
}
```

### Library Mode (Publishing Packages)

```typescript
// vite.config.ts for a library
import { defineConfig } from 'vite'
import { resolve } from 'path'
import dts from 'vite-plugin-dts'

export default defineConfig({
  plugins: [dts({ include: ['src'] })],
  build: {
    lib: {
      entry: resolve(__dirname, 'src/index.ts'),
      name: 'MyLib',
      fileName: (format) => `my-lib.${format}.js`,
      formats: ['es', 'cjs'], // ESM + CommonJS
    },
    rollupOptions: {
      // Externalize peer dependencies — don't bundle them
      external: ['react', 'react-dom'],
      output: {
        globals: {
          react: 'React',
          'react-dom': 'ReactDOM',
        },
      },
    },
  },
})
```

### Environment Variables

Vite loads `.env` files based on mode:

```
.env               # loaded always
.env.local         # loaded always, git-ignored
.env.development   # loaded in dev mode only
.env.production    # loaded in production only
.env.test          # loaded in test mode
```

Only variables prefixed with `VITE_` are exposed to client code:

```typescript
// In source code
const apiUrl = import.meta.env.VITE_API_URL
const isProd = import.meta.env.PROD    // boolean
const isDev = import.meta.env.DEV      // boolean
const mode = import.meta.env.MODE      // 'development' | 'production' | custom

// Type safety — add to src/vite-env.d.ts
interface ImportMetaEnv {
  readonly VITE_API_URL: string
  readonly VITE_APP_TITLE: string
}
interface ImportMeta {
  readonly env: ImportMetaEnv
}
```

### Proxy Configuration for Dev API

```typescript
server: {
  proxy: {
    // Simple string rewrite
    '/api': 'http://localhost:4000',

    // Full options
    '/graphql': {
      target: 'http://localhost:4000',
      changeOrigin: true,
      secure: false,
      ws: true, // proxy WebSocket connections too
    },

    // RegExp pattern
    '^/auth/.*': {
      target: 'http://localhost:4001',
      changeOrigin: true,
    },
  },
}
```

### Tree-Shaking and Code Splitting

Vite/Rollup performs tree-shaking automatically on ES modules. Ensure:
- Import named exports, not the whole module: `import { debounce } from 'lodash-es'`
- Use `sideEffects: false` in `package.json` for libraries
- Dynamic imports for route-level splitting:

```typescript
// React lazy loading triggers code splitting
const Dashboard = lazy(() => import('./pages/Dashboard'))
const Settings = lazy(() => import('./pages/Settings'))
```

Manual chunk strategy for better caching:
```typescript
rollupOptions: {
  output: {
    manualChunks(id) {
      if (id.includes('node_modules')) {
        if (id.includes('react')) return 'react-vendor'
        if (id.includes('@radix-ui')) return 'ui-vendor'
        return 'vendor'
      }
    },
  },
}
```

### SSR Mode

```typescript
// vite.config.ts with SSR
export default defineConfig({
  build: {
    ssr: true, // or path to SSR entry
    rollupOptions: {
      input: 'src/entry-server.ts',
    },
  },
})

// Detect SSR in plugin
resolveId(id, importer, options) {
  const isSSR = this.environment.config.consumer === 'server'
}
```

---

## esbuild (Libraries and CLIs)

Use esbuild directly for Node.js libraries and CLI tools where Rollup overhead is unnecessary.

```typescript
// build.ts — run with tsx build.ts
import { build } from 'esbuild'

await build({
  entryPoints: ['src/index.ts', 'src/cli.ts'],
  outdir: 'dist',
  bundle: true,
  platform: 'node',
  target: 'node20',
  format: 'esm',
  sourcemap: true,
  // Don't bundle deps that should remain external
  external: ['express', 'pg', 'ioredis', /^node:/],
  // Split output for better tree-shaking
  splitting: true,
})
```

For dual ESM + CJS output:
```typescript
// Build CJS
await build({ ...baseOptions, format: 'cjs', outExtension: { '.js': '.cjs' } })
// Build ESM
await build({ ...baseOptions, format: 'esm', outExtension: { '.js': '.mjs' } })
```

---

## Turbopack (Next.js 14+)

Turbopack is Rust-based and replaces Webpack inside Next.js. Enable with `--turbopack` flag:

```json
{
  "scripts": {
    "dev": "next dev --turbopack"
  }
}
```

`turbo.json` for Turborepo (monorepo task caching — separate from Turbopack):

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "test": {
      "outputs": ["coverage/**"]
    },
    "lint": {}
  }
}
```

**Turbopack vs Webpack**: Use Turbopack (via Next.js `--turbopack`) when you want faster dev server cold starts and HMR in a Next.js project. Webpack remains more configurable and has a wider plugin ecosystem; prefer it when you need custom loaders not yet supported by Turbopack.

---

## tsconfig.json Optimization

### Strict Mode and Beyond

```json
{
  "compilerOptions": {
    "strict": true,

    // Beyond strict — highly recommended
    "noUncheckedIndexedAccess": true,    // arr[0] is T | undefined
    "exactOptionalPropertyTypes": true,   // { x?: number } means x is number, not number | undefined
    "noImplicitReturns": true,            // all code paths must return
    "noFallthroughCasesInSwitch": true,
    "noUncheckedSideEffectImports": true, // TS 5.6+

    // Module resolution
    "module": "NodeNext",                // for Node 22+ ESM projects
    "moduleResolution": "NodeNext",
    "target": "ES2022",

    // Performance
    "skipLibCheck": true,                // skip type-checking .d.ts files
    "incremental": true,                 // .tsbuildinfo cache
    "tsBuildInfoFile": ".tsbuildinfo",

    // Output
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  }
}
```

### Path Aliases

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"],
      "@components/*": ["src/components/*"],
      "@utils/*": ["src/utils/*"]
    }
  }
}
```

Pair with `vite-tsconfig-paths` plugin or manual `resolve.alias` in `vite.config.ts`.

Note: `baseUrl` is deprecated in TS 7.0 — use `paths` with explicit roots.

### Target Selection

| Target | Use When |
|--------|---------|
| `ES2022` | Node 16+, modern browsers, includes class fields, top-level await |
| `ESNext` | Cutting-edge features; risks churn between TS versions |
| `ES2020` | Broader compat, includes optional chaining and nullish coalescing |
| `baseline-widely-available` | Vite 7 default build target (browser matrix) |

### Project References (Monorepos)

```json
// Root tsconfig.json
{
  "references": [
    { "path": "./packages/core" },
    { "path": "./packages/api" }
  ],
  "files": []
}

// packages/core/tsconfig.json
{
  "compilerOptions": {
    "composite": true,
    "outDir": "dist"
  }
}
```

Build with `tsc --build` for incremental cross-package compilation.

---

## ESLint Flat Config (eslint.config.js)

ESLint v9+ uses flat config. Migration from `.eslintrc`:

```javascript
// eslint.config.js
import js from '@eslint/js'
import tseslint from 'typescript-eslint'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import importPlugin from 'eslint-plugin-import'

export default tseslint.config(
  { ignores: ['dist', 'node_modules'] },
  {
    extends: [js.configs.recommended, ...tseslint.configs.strictTypeChecked],
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      parserOptions: {
        project: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
      import: importPlugin,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      'react-refresh/only-export-components': 'warn',
      // Import ordering
      'import/order': ['error', {
        groups: ['builtin', 'external', 'internal', 'parent', 'sibling'],
        'newlines-between': 'always',
        alphabetize: { order: 'asc' },
      }],
      // TS-specific
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/consistent-type-imports': 'error',
    },
  },
  {
    // Relax some rules for test files
    files: ['**/*.test.{ts,tsx}', '**/*.spec.{ts,tsx}'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
    },
  }
)
```
