import { defineConfig } from 'vite'

export default defineConfig({
  root: '.',
  server: {
    port: 8080,
    open: true
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets'
  },
  assetsInclude: ['**/*.glb', '**/*.gltf', '**/*.bin', '**/*.npy']
})