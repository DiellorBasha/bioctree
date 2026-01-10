Below is a refactoring strategy that (1) makes `bct.Manifold` cache the **DECLab** `DiscreteExteriorCalculus` backend directly, (2) removes the `bct.DEC` + `bct.dec.*` redundancy, and (3) keeps your **registry/runtime discipline** so that *operators remain non-scope* (i.e., not “owned” by `Manifold`, but executed via `bct.registry` + `bct.runtime`).

I am grounding this plan in your current `Manifold` port/caching pattern, your current `bct.DEC` wrapper behavior (it already constructs the backend and caches derived operators), and the fact that your operator specs currently bind DEC operators to `representation = "bct.DEC"`. I am also respecting the “operators are non-scope / pure” intent expressed in your operator contract and the routing/validation responsibilities you’ve defined for runtime.

---

## 1) Target architecture (end state)

### Roles and boundaries

**A. `bct.Manifold` (geometry authority)**

* Owns immutable geometry/topology (`Vertices`, `Faces`, `Edges`, etc.) and caches *representations* via ports (your current design).
* Will cache **one DEC backend object**: `DiscreteExteriorCalculus(F,V)` (DECLab).

**B. `bct.registry` (declarative operator catalog)**

* Holds *metadata* about operators: ID, domain, representation requirement, parameters, and the function handle to execute (as you already do). This remains “what exists” and “what it needs,” not “how to obtain it.”

**C. `bct.runtime` (operator execution)**

* Receives an operator request `{id, context, inputs}` and:

  1. resolves representation from context,
  2. validates applicability (`representation` + `requires`),
  3. dispatches to the operator function handle. This is consistent with your runtime contract.

**D. DEC operator implementations (thin, pure functions)**

* These are simple functions that call DECLab methods on the backend, with minimal normalization/validation.
* They are “operators” (non-scope), so they must *not* live as `Manifold.gradient()` style methods, per your discipline.

**Key point:** You do *not* need a new façade class. Your runtime already *is* the façade, and your registry already *is* the catalog.

---

## 2) Refactor plan (phased, low-risk)

### Phase 0 — Inventory + compatibility constraints (1 short pass)

Deliverables:

* List of all operator IDs in the DEC domain (`dec_gradient`, `dec_divergence`, `dec_curl`, `dec_laplacian*`, etc.).
* Identify any code that directly depends on:

  * `M.DEC()` returning a `bct.DEC` wrapper,
  * `specs.*.representation = "bct.DEC"` in the registry,
  * `bct.dec.*` functions referenced by registry specs (as above).

This ensures you don’t “strand” any operator IDs mid-refactor.

---

### Phase 1 — Change `bct.Manifold` to cache `DiscreteExteriorCalculus` directly

Right now `M.DEC()` lazily creates `bct.DEC(obj)` and caches it. Replace that with direct construction of the DECLab backend.

**Implementation change:**

* Keep the port name `DEC()` for continuity, but change its return type from `bct.DEC` to `DiscreteExteriorCalculus`.

```matlab
function dec = DEC(obj)
    %DEC Get DECLab DEC backend (lazy creation with caching)
    % Returns:
    %   dec - DiscreteExteriorCalculus (DECLab)

    if ~isKey(obj.Cache, "DEC")
        F = double(obj.Faces);
        V = double(obj.Vertices);
        obj.Cache("DEC") = DiscreteExteriorCalculus(F, V);
    end
    dec = obj.Cache("DEC");
end
```

**Why this is aligned with your design:**

* `Manifold` already uses ports + cache for representations.
* `bct.DEC`’s primary “real” work is backend construction anyway. You’re simply moving construction to the port.

**Optional improvement (recommended):**

* Add a private helper `createDEC_()` so you have a single place to adapt if DECLab changes constructor signature later.

---

### Phase 2 — Introduce a DEC “representation key” convention for runtime context

You want runtime routing through a dictionary (agreed), and you already have runtime semantics for “representation required” and “requires” validation.

**Standardize:**

* In runtime context, DEC backend is always accessible at:

  * `ctx.DEC` (instance of `DiscreteExteriorCalculus`)

Example context builder:

```matlab
ctx = struct();
ctx.Manifold = M;
ctx.DEC = M.DEC();    % now DiscreteExteriorCalculus
ctx.FEM = M.FEM();
ctx.Graph = M.Graph();
```

This avoids ambiguous “where do I find the representation instance?” logic.

---

### Phase 3 — Update the registry specs for DEC operators

Your DEC operator specs currently use `representation = "bct.DEC"`. Update them to target the actual backend type, e.g.:

* `representation = "DiscreteExteriorCalculus"`

And update the `function` handle to point to your new DEC operator implementations (see Phase 4).

Example (conceptual):

```matlab
specs.dec_gradient = struct( ...
  'id', "dec_gradient", ...
  'domain', "dec", ...
  'representation', "DiscreteExteriorCalculus", ...
  'function', @bct.ops.dec.gradient, ...
  'requires', ["d0"], ...
  'purity', "pure" ...
);
```

**About `requires`:**

* Today you use `requires` such as `["d0","hd1"]` etc..
* Keep that concept: it is valuable for early validation and introspection.
* But change the validation target from your wrapper’s cached fields to the backend’s exposed properties (DECLab typically exposes `d0`, `d1`, `hd0`, `hd1`, `hd2`, etc.; your old wrapper accessed these via `getBackendField_()`).

---

### Phase 4 — Replace `bct.dec.*` with minimal “DEC operator” functions that call DECLab methods directly

Your `bct.DEC` currently delegates to `bct.dec.*` functions and also caches derived operators. The refactor goal is to delete that layer.

**Recommended namespace:**

* Create **one** operator implementation package (not a class), e.g.:

  * `+bct/+ops/+dec/gradient.m`
  * `+bct/+ops/+dec/divergence.m`
  * `+bct/+ops/+dec/curl.m`
  * `+bct/+ops/+dec/laplacian0.m`, etc.

This preserves: operators are **non-scope**, and the code is clearly “operator land,” not “manifold land,” consistent with the “non-scope operator” framing.

**Example operator implementations (thin wrappers):**

```matlab
% +bct/+ops/+dec/gradient.m
function U = gradient(decBackend, f0, opts)
% decBackend: DiscreteExteriorCalculus
% f0: 0-form on vertices
arguments
    decBackend (1,1)
    f0 double
    opts struct = struct()
end
U = decBackend.gradient(f0);  % DECLab method call
end
```

```matlab
% +bct/+ops/+dec/divergence.m
function f0 = divergence(decBackend, U)
arguments
    decBackend (1,1)
    U double
end
f0 = decBackend.divergence(U);
end
```

```matlab
% +bct/+ops/+dec/curl.m
function a2 = curl(decBackend, U)
arguments
    decBackend (1,1)
    U double
end
a2 = decBackend.curl(U);
end
```

For Helmholtz-Hodge, call the backend method directly (DECLab exposes this explicitly).

---

### Phase 5 — Adjust runtime to resolve representation instances cleanly

Your runtime contract indicates runtime is responsible for routing and validation, and you already have runtime/operator code wiring in your system (see `bctruntimeoperators` in your uploads).

**Make representation resolution deterministic:**

* If `spec.representation == "DiscreteExteriorCalculus"`, runtime should fetch `ctx.DEC`.
* Then validate:

  * `isa(ctx.DEC, 'DiscreteExteriorCalculus')`
  * and for each entry in `spec.requires`, check `isprop(ctx.DEC, req)` (or a fallback mechanism if DECLab uses fields not properties).

**Dispatch signature standardization:**

* Operator function handle always accepts:

  1. representation instance (here: `DiscreteExteriorCalculus`)
  2. primary input(s) (signal or operator request payload)
  3. parameters/options (optional)

This keeps functions “pure” and testable while letting runtime own orchestration/validation.

---

### Phase 6 — Deprecate `bct.DEC` and `bct.dec.*` safely (do not hard-delete first)

You are correct to avoid breaking everything at once.

**Recommended deprecation approach:**

1. Keep `bct.DEC` file temporarily, but:

   * Mark clearly deprecated in docstring.
   * Convert it into a compatibility shim:

     * `obj.Backend = obj.Manifold.DEC()` (now already a backend)
     * Remove all caching of Gradient/Divergence/Curl matrices (or keep as pass-through only).
2. Keep `bct.dec.*` as compatibility wrappers:

   * Each function warns once and forwards to `bct.ops.dec.*`.

This is “boring engineering,” but it prevents your registry/runtimes and downstream analysis code from diverging while you migrate call sites.

---

## 3) How users will call operators after the refactor (ergonomic, non-scope)

You want to avoid `decGradient()` clunkiness, but also keep operators out of the `Manifold` namespace.

The most consistent pattern with your registry/runtime discipline is:

```matlab
ctx = bct.runtime.buildContext(M);   % or just a struct with ctx.DEC = M.DEC()
U   = bct.runtime.apply("dec_gradient", ctx, f0);
```

If you want *one* short entrypoint without polluting `Manifold`, add a single top-level convenience function (not a class):

```matlab
U = bct.op("dec_gradient", M, f0);
```

Internally it:

* builds `ctx` (with `ctx.DEC = M.DEC()`),
* calls runtime apply.

This keeps:

* operator definitions in registry,
* execution in runtime,
* geometry in manifold,
* and gives you the short call users want.

---

## 4) Concrete “checklist” of edits

### Edit A — `bct.Manifold`

* Update `DEC()` port to cache `DiscreteExteriorCalculus` directly (replace `bct.DEC(obj)` construction).

### Edit B — `bctregistryoperators`

* Update all DEC-domain operator specs:

  * `representation: "bct.DEC"` → `"DiscreteExteriorCalculus"`.
  * `function: @bct.dec.*` → `@bct.ops.dec.*` (new thin operator functions).

### Edit C — runtime representation resolver

* Ensure runtime reads `ctx.DEC` for DEC operators (and validates it).
* Keep “operators non-scope” by ensuring no `Manifold.gradient/divergence/curl` methods are introduced.

### Edit D — add `+bct/+ops/+dec/` implementations

* Implement: `gradient`, `divergence`, `curl`, `laplacian0/1/2`, `helmholtzHodgeDecomposition`, `eigensolve`, etc.
* Each function is a thin call to DECLab methods (no duplicate operator matrices).

### Edit E — deprecations

* `bct.DEC`: compatibility shim only; no caches (or very limited pass-through).
* `bct.dec.*`: compatibility wrappers only; warn and forward.

---

## 5) Design philosophy (why this is the “lean” version that still scales)

1. **Single source of truth for DEC math:** DECLab backend.
   Your current wrapper already admits this (“math authority”), but then recreates computed operator matrices (even if cached). Removing that prevents drift.

2. **Operators remain non-scope:** consistent with your contract language.
   `Manifold` provides representations; runtime executes operators.

3. **Registry remains declarative:** it should not “reach into” manifold or construct representations; it just states requirements and function handles. Runtime does the rest.

4. **Ergonomics via a single short dispatcher (`bct.op`) instead of fat `Manifold`:**
   This gives you the short call without violating the boundary.

---

If you want, in the next step I can draft the exact diffs for:

* `Manifold.DEC()` (new implementation),
* the DEC section of `bctregistryoperators` (representation + function handles),
* a minimal `bct.op()` dispatcher + `bct.runtime.buildContext()` helper,
* and 3–5 initial operator functions (`gradient/divergence/curl/laplacian0/hhd`) to prove the pattern end-to-end.
