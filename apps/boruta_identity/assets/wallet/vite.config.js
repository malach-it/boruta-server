import path from 'path'
import { defineConfig } from 'vite'
import { viteSingleFile } from 'vite-plugin-singlefile'
import vue from '@vitejs/plugin-vue'
import { VitePWA } from 'vite-plugin-pwa'
import { nodePolyfills } from 'vite-plugin-node-polyfills'

const base_url = new URL(process.env.BORUTA_OAUTH_BASE_URL || 'http://localhost:4000')

const manifest = {
  "name": "boruta wallet",
  "theme_color": "#f5ba00",
  "background_color": "#333333",
  "display": "standalone",
  "scope": "/accounts/wallet",
  "start_url": "/accounts/wallet",
  "intent_filters": {
    "scope_url_scheme": base_url.protocol.slice(0, -1),
    "scope_url_host": base_url.host,
    "scope_url_path": "/accounts/wallet"
  },
  "capture_links": "existing-client-navigate",
  "url_handlers": [
    {
      "origin": `${base_url.toString()}/accounts/wallet`
    }
  ],
  "icons": [{
    "src": "/accounts/wallet/images/icons/logo-512x512.png",
    "sizes": "512x512",
    "type": "image/png",
    "purpose": "any"
  }]
}
// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    nodePolyfills({
      // To exclude specific polyfills, add them to this list.
      exclude: [
        'fs', // Excludes the polyfill for `fs` and `node:fs`.
      ],
      // Whether to polyfill specific globals.
      globals: {
        Buffer: true, // can also be 'build', 'dev', or false
        global: true,
        process: true,
      },
      // Whether to polyfill `node:` protocol imports.
      protocolImports: true,
    }),
    vue(),
    viteSingleFile(),
    VitePWA({
      injectRegister: 'auto',
      manifest
    })
  ],
  publicDir: false,
  build: {
    outDir: path.resolve(__dirname, '../../priv/static/wallet'),
    emptyOutDir: false,
    lib: {
      entry: path.resolve(__dirname, './src/main.ts'),
      name: 'Boruta',
      fileName: (format) => `app.${format}.js`
    },
    target: 'esnext',
    assetsInlineLimit: 100000000,
    chunkSizeWarningLimit: 100000000,
    cssCodeSplit: false,
    brotliSize: false
  }
})
