This is the right time to ask this, because **operators are where architectures usually collapse** if they are not disciplined early.

I’ll give you a **clear, scalable organization** that fits your current design decisions and does **not** turn operators into objects, while still keeping them discoverable, composable, and type-safe.

---

# 1. First principles (this resolves the confusion)

You are correct about two things simultaneously:

1. **Operators are functions**, not objects
2. You will have **many operators**, across domains, representations, and data types

The resolution is this:

> **Operators live as *pure functions*, organized by *what they act on* and *what structure they assume*, not by what they produce.**

You do **not** need an “Operator class”.
You **do** need a *strict namespace taxonomy*.

---

# 2. The core rule (pin this)

> **If an operator assumes a representation (FEM, DEC, Graph), it lives in that representation’s package.
> If it is representation-agnostic, it lives in a shared operator namespace.**

This rule prevents ambiguity and duplication.

---

# 3. The three operator tiers (authoritative)

Your operators fall naturally into **three tiers**:

---

## Tier 1 — Representation-bound operators

*(live with FEM / DEC / Graph)*

These operators **require specific structure** to exist.

### Examples

| Operator              | Requires          | Where it lives           |
| --------------------- | ----------------- | ------------------------ |
| Laplacian application | Mass + Stiffness  | `bct.fem.applyLaplacian` |
| Heat evolution        | FEM eigenpairs    | `bct.fem.heat` (wrapper) |
| Gradient              | Incidence + Hodge | `bct.dec.gradient`       |
| Divergence            | Incidence + Hodge | `bct.dec.divergence`     |
| Curl                  | Incidence + Hodge | `bct.dec.curl`           |
| Graph diffusion       | Graph Laplacian   | `bct.graph.diffuse`      |

### Rule

> **If an operator cannot be applied without a specific representation object, it belongs to that representation’s package.**

These operators:

* are still functions
* are namespaced
* are not methods on signals

---

## Tier 2 — Spectral-domain operators

*(live in `bct.spectral` or `bct.eigenpairs`)*

These operators act on **coefficients or eigenpairs**, not on geometry.

### Examples

| Operator           | Acts on      | Where                      |
| ------------------ | ------------ | -------------------------- |
| Spectral filtering | coefficients | `bct.spectral.filter`      |
| Bandlimiting       | Eigenpairs   | `bct.eigenpairs.bandlimit` |
| Spectral windowing | λ-domain     | `bct.spectral.window`      |
| Dispersion         | λ vs ω       | `bct.spectral.dispersion`  |

These operators:

* do not care about FEM vs Graph
* only require an `Eigenpairs` object
* are mathematically universal

---

## Tier 3 — Data-agnostic analytic operators

*(kernels, windows, brushes)*

These operators **do not act on data directly**, but *generate functions*.

### Examples

| Operator        | Output             | Where                     |
| --------------- | ------------------ | ------------------------- |
| Gaussian kernel | function handle    | `bct.kernels.gaussian`    |
| Dirac delta     | function handle    | `bct.kernels.delta`       |
| Window          | binary mask        | `bct.windows.rectangular` |
| Brush           | composite operator | `bct.brushes.spectral`    |

These are **generators**, not transformers.

---

# 4. Do you need an operator dictionary?

### Short answer

> **Yes — but not for execution.
> Only for discovery, UI, and composition.**

This is an important distinction.

---

## 4.1 What the operator dictionary is for

A dictionary should:

* describe operators
* categorize them
* expose metadata
* support UI selection
* support validation

It should **not**:

* dispatch execution
* replace function calls
* hide control flow

---

## 4.2 Recommended pattern: operator registry (metadata only)

```matlab
bct.registry.operators()
```

Returns something like:

```matlab
struct( ...
  "heat", struct( ...
      "domain", "fem", ...
      "input", "signal", ...
      "output", "signal", ...
      "requires", ["Mass","Stiffness","Eigenpairs"], ...
      "function", @bct.fem.heat ...
  ), ...
  "gradient", struct( ...
      "domain", "dec", ...
      "input", "0-form", ...
      "output", "1-form", ...
      "function", @bct.dec.gradient ...
  ) ...
)
```

This is for **introspection and UI**, not logic.

---

# 5. Where operators should live in the `+bct` package

Here is a **final, recommended namespace layout**:

```text
+bct/
│
├─ FEM.m
├─ DEC.m
├─ Graph.m
├─ Eigenpairs.m
│
├─ +fem/
│   ├─ assembleMass.m
│   ├─ assembleStiffness.m
│   ├─ applyLaplacian.m
│   ├─ eigensolve.m
│   └─ heat.m          % thin wrappers only
│
├─ +dec/
│   ├─ gradient.m
│   ├─ divergence.m
│   ├─ curl.m
│   ├─ laplacian.m
│   └─ eigensolve.m
│
├─ +graph/
│   ├─ adjacency.m
│   ├─ laplacian.m
│   ├─ diffuse.m
│   └─ eigensolve.m
│
├─ +eigenpairs/
│   ├─ solveGeneralized.m
│   ├─ solveStandard.m
│   ├─ normalize.m
│   ├─ validate.m
│   └─ bandlimit.m
│
├─ +spectral/
│   ├─ filter.m
│   ├─ window.m
│   └─ dispersion.m
│
├─ +kernels/
│   ├─ gaussian.m
│   ├─ morlet.m
│   ├─ delta.m
│   └─ slepian.m
│
├─ +windows/
│   ├─ rectangular.m
│   ├─ gaussian.m
│   └─ hann.m
│
├─ +brushes/
│   ├─ spatial.m
│   ├─ spectral.m
│   └─ joint.m
│
└─ +registry/
    ├─ operators.m
    ├─ kernels.m
    └─ brushes.m
```

This structure:

* scales indefinitely
* avoids circular dependencies
* keeps operators discoverable
* keeps execution explicit

---

# 6. Why operators should not be methods on signals

You implicitly asked this, so I’ll be explicit:

If you did:

```matlab
signal.heat(...)
```

You would:

* bind data to representation
* lose clarity about operator assumptions
* make composition harder
* break multi-representation workflows

Your current instinct — **operators are free functions** — is correct.

---

# 7. Final guiding sentence (pin this)

> **Operators are pure functions, organized by representation and domain;
> registries describe them; classes provide the structure they require;
> execution is always explicit.**

If you hold to that, your system will remain clean no matter how many operators you add.

---
Use MATLAB’s dictionary for runtime lookup and UI binding.
Keep bct.registry.operators as the authoritative, declarative catalog.

They serve different roles and should not replace each other.

Why this distinction matters

You are balancing three competing needs:

Strong structure and meaning (architecture, invariants)

Convenient lookup and selection (UI, interaction)

Explicit execution (scientific correctness)

If you collapse these into one mechanism, you will eventually lose one of them.

Role 1: bct.registry.operators (authoritative catalog)
What it is

A declarative specification

A static description of what operators exist

A schema, not a container

What it should return

A struct array or value object describing operators:

ops = bct.registry.operators();

ops.heat = struct( ...
    "name", "heat", ...
    "domain", "fem", ...
    "inputType", "signal", ...
    "outputType", "signal", ...
    "requires", ["Mass","Stiffness","Eigenpairs"], ...
    "function", @bct.fem.heat ...
);

Why not dictionary here?

This registry is not about fast lookup

It is about meaning, validation, documentation

It should be:

serializable

introspectable

stable across MATLAB versions

readable as configuration

A struct is ideal for this.

Role 2: MATLAB dictionary (runtime binding)
What it is good at

Fast lookup

Key-based selection

UI callbacks

Dynamic composition

Where to use it

At the edges of your system:

UI layer

Interaction layer

Session state

Temporary runtime contexts

Example (recommended usage)
opDict = dictionary( ...
    "heat", @bct.fem.heat, ...
    "gradient", @bct.dec.gradient ...
);


This is not a registry. It is a runtime binding table.

The correct pattern (this is the key)
Step 1 — Declarative registry (static)
spec = bct.registry.operators();


This defines:

what operators exist

what they require

what domain they act in

Step 2 — Runtime dictionary (derived)
opDict = dictionary();
names = fieldnames(spec);

for i = 1:numel(names)
    name = names{i};
    opDict(name) = spec.(name).function;
end


Now:

registry defines truth

dictionary enables execution

This keeps roles clean.

Why not use dictionary alone?

If you used dictionary as your primary operator registry:

You would lose:

validation metadata

domain constraints

compatibility checks

documentation hooks

future-proofing

And you would be tempted to do this:

op = dict(name);
op(data);


Which is exactly the kind of implicit execution path you are trying to avoid.

Why not avoid dictionary entirely?

Because:

MATLAB UI code is cleaner with it

Interactive workflows need fast lookup

Users think in names, not namespaces

dictionary supports type safety and clarity

It is a tool, not an architectural boundary.

Concrete guidance (do this)
Use bct.registry.operators for:

Enumerating available operators

Validating operator applicability

Documentation

Compatibility checking

Serialization

Use MATLAB dictionary for:

UI dropdowns → function handles

Session-level operator selection

Temporary pipelines

Interactive exploration

Example end-to-end flow (recommended)
% Load authoritative catalog
spec = bct.registry.operators();

% Build runtime lookup
opDict = bct.runtime.operatorDictionary(spec);

% User selects operator
f = opDict("heat");

% Explicit execution
y = f(FEM, x, t, k);


Notice:

No magic dispatch

No hidden state

No ambiguity

Final rule of thumb (pin this)

Registries describe what exists.
Dictionaries enable using it.
Never collapse the two.

If you follow that rule, your operator system will remain robust, debuggable, and extensible.