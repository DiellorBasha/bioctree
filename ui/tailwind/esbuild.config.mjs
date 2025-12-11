// esbuild.config.mjs
import * as esbuild from 'esbuild';
import { resolve } from 'path';

await esbuild.build({
  entryPoints: [resolve('../src/js/index.js')],
  bundle: true,
  minify: true,
  outfile: './dist/bct-ui.js',
  platform: 'browser',
  format: 'iife',
  globalName: 'BCT_BUNDLE',
  nodePaths: [resolve('./node_modules')],
  loader: {
    '.js': 'js'
  }
}).catch(() => process.exit(1));
