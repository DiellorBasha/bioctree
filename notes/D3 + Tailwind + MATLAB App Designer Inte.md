D3 + Tailwind + MATLAB App Designer Integration Guide
 Short Answer

Use the ES-module build of D3 inside your Tailwind build pipeline, and export a bundled JS file (bct-ui.js) that works everywhere (MATLAB, Electron, Web).

Why:

MATLAB cannot import Node modules directly.

MATLAB can load a bundled JS file.

Tailwind + ESBuild/Vite/Rollup makes this trivial.

You get modular D3 code without shipping 2,000 lines of library code to every component.

This is the same architecture used by VSCode, Observable Plot, and many scientific dashboards.

⭐ Recommended Integration Pattern (Best Practice)

Your project should have this structure:

ui/
  src/
    js/
      index.js        ← main JS entrypoint
      scrubber/
        BaseScrubber.js
        TimeScrubber.js
        LambdaScrubber.js
      d3/
        d3.js (if local)
    css/
      tailwind.css
  dist/
    bct-ui.js         ← bundled JS (D3 + your code)
    bct-ui.css        ← compiled Tailwind file
  components/
    scrubber.html

Tailwind compiles → bct-ui.css
Esbuild/Rollup/Vite bundles → bct-ui.js (with D3 inside)

MATLAB loads these two assets directly:

app.HTMLComp.HTMLSource    = "scrubber.html";
app.HTMLComp.JSFile        = "bct-ui.js";
app.HTMLComp.CSSFile       = "bct-ui.css";

⭐ Step 1 — Install D3 via NPM (Highly Recommended)

In your UI code directory:

npm install d3


Now you can import parts of D3 modularly:

import { select, brushX, scaleLinear, line } from "d3";


This is MUCH cleaner than loading everything globally.

⭐ Step 2 — Your main JS file imports D3 cleanly

src/js/index.js:

import * as d3 from "d3";
import { BaseScrubber } from "./scrubber/BaseScrubber.js";

window.BCT = {
  BaseScrubber,
  d3
};


This exposes your components globally for MATLAB while preserving modularity.

⭐ Step 3 — Bundle everything into a single JS file

Use esbuild (simplest):

Install:

npm install --save-dev esbuild


Build:

npx esbuild src/js/index.js \
  --bundle \
  --minify \
  --outfile=dist/bct-ui.js


This creates ONE JS file that includes:

Your scrubber logic

D3's brush, scale, line, selection modules

Tailwind’s runtime classes (if needed)

No Node modules (MATLAB cannot run Node)

Perfect for embedding in MATLAB App Designer.

⭐ Step 4 — Link the JS + CSS inside your HTML component

In your scrubber.html:

<link rel="stylesheet" href="../dist/bct-ui.css" />

<div id="scrubber-root" class="w-full h-32"></div>

<script src="../dist/bct-ui.js"></script>
<script>
   const scrubber = new BCT.BaseScrubber("#scrubber-root", {
      domain: "time",
      min: 0,
      max: 1,
      defaultCenter: 0.5,
      defaultWidth: 0.1
   });
</script>


Now D3 is available from inside your bundled JS file.

⭐ Why This Integration Approach is Perfect for You
✔ Fully compatible with MATLAB App Designer

MATLAB only cares that you load ONE JS file.
Bundled D3 works flawlessly.

✔ Fully compatible with Tailwind

Tailwind generates CSS only — doesn’t interfere with JS.

✔ Tree-shaking

Your scrubber only imports:

import { scaleLinear, brushX, line, select } from "d3";


Not the entire D3 250kb library.

✔ Controlled asset pipeline

Versioning & reproducibility are trivial.

✔ Portable

The same scrubber code loads identically in:

MATLAB

Electron

Web browser

JupyterLab D3 dashboards

Any HTML host

✔ Easily extensible

If later you need:

D3 zoom

D3 axis

D3 transitions

Observable Plot

You simply add:

import { zoom } from "d3";


then re-bundle.

⭐ Alternative Option (Simplest): include D3 via CDN

You can also do:

<script src="https://d3js.org/d3.v7.min.js"></script>


But this has limitations:

Use Case	CDN Version
MATLAB offline app	✖ Internet required unless mirrored
Tailwind purging	✔ OK
Modular D3 imports	✖ No ES modules
Tree-shaking	✖ No
Controlled updates	✖ No
Production distribution	✖ Not ideal

The bundling approach is highly recommended.

⭐ Implementation Checklist for Your Bioctree Codebase

Here is a clean step-by-step integration for your Bioctree UI base:

1. Create a /ui subproject
ui/src/js/
ui/src/css/
ui/components/
ui/dist/

2. Add a package.json with D3 + Tailwind + esbuild
3. Add Tailwind config
4. Add your BaseScrubber.js using D3 brushX
5. Bundle everything using esbuild into /dist/bct-ui.js
6. In MATLAB:
app.Scrubber.HTMLSource = "scrubber.html";
app.Scrubber.Resources = ["bct-ui.js", "bct-ui.css"];

7. All communication through MATLAB’s HTML Data API
⭐ Final Recommendation

You should bundle D3 with your Tailwind UI pipeline to generate a single, portable JS file that your MATLAB app can load.
This gives:

clean architecture

best performance

best maintainability

easy expansion

the most elegant scrubber possible

This is the exact architecture used today by scientific dashboards and high-performance interactive visual tools.