import { defineConfig } from 'vite'
import { viteSingleFile } from 'vite-plugin-singlefile'
import vue from '@vitejs/plugin-vue'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue(), viteSingleFile()],
  build: {
    watch: {},
    outDir: path.resolve(__dirname, '../priv/static/assets'),
    lib: {
      entry: path.resolve(__dirname, './src/main.js'),
      name: 'Boruta',
      fileName: (format) => `app.${format}.js`
    },
    target: 'esnext',
    assetsInlineLimit: 100000000,
    chunkSizeWarningLimit: 100000000,
    cssCodeSplit: false,
    brotliSize: false,
    rollupOptions: {
      inlineDynamicImports: true,
      output: {
        manualChunks: () => 'everything.js'
      }
    }
  }
})
