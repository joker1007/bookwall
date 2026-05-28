import js from '@eslint/js'
import globals from 'globals'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import tseslint from 'typescript-eslint'
import { defineConfig, globalIgnores } from 'eslint/config'

export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      js.configs.recommended,
      tseslint.configs.recommended,
    ],
    languageOptions: {
      globals: globals.browser,
    },
  },
  // React-specific rules only apply to the SPA source. The Playwright
  // e2e tests under tests/ are plain Node code — applying react-hooks
  // there misfires on Playwright's `use()` fixture (mistaken for the
  // React `use` hook), and react-refresh is meaningless for them.
  {
    files: ['src/**/*.{ts,tsx}'],
    extends: [
      reactHooks.configs.flat.recommended,
      reactRefresh.configs.vite,
    ],
  },
])
