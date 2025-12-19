Below are **three separate, extensive contract/design documents**, written as if they were standalone `.md` files you can drop directly into your repository (e.g., `/docs/architecture/`).

They are intentionally **normative** (they define rules, not suggestions) and **explanatory**, because—as you said—they are meant to **guide all future development** of the `bct` package.

---

# 📄 `OPERATORS.md`

```markdown
# BCT Operators — Design Contract

## 1. Purpose

This document defines what an **operator** is in the `bct` ecosystem, how operators are represented in code, and where they live in the package namespace.

Operators are the *actions* of the system: they transform data using mathematical structure supplied by representations such as FEM, DEC, Graphs, or spectral bases.

This document is **authoritative**. Any future operator added to `bct` must comply with this contract.

---

## 2. Definition of an Operator

In `bct`, an **operator** is:

> A **pure function** that transforms data, assuming a specific mathematical structure.

Key properties:
- Operators are **functions**, not objects
- Operators do **not** own data
- Operators do **not** store state
- Operators do **not** perform implicit dispatch
- Operators are **explicitly executed**

An operator always answers the question:
> “Given this representation and this data, what is the result?”

---

## 3. Operators vs Representations

Operators do not exist in isolation. They **assume structure** provided by representations.

| Representation | Supplies |
|---------------|----------|
| `bct.FEM` | Variational inner product, Laplace–Beltrami |
| `bct.DEC` | Incidence operators, Hodge stars |
| `bct.Graph` | Adjacency, graph Laplacian |
| `bct.Eigenpairs` | Spectral basis and inner product |

An operator **never constructs** these structures—it only *uses* them.

---

## 4. Operator Taxonomy

All operators in `bct` fall into one of the following categories.

### 4.1 Representation-bound operators

Operators that **require a specific representation**.

Examples:
- FEM heat evolution
- DEC gradient
- Graph diffusion

These operators live in representation namespaces:

```

bct.fem.*
bct.dec.*
bct.graph.*

```

They are still functions, not methods on data.

---

### 4.2 Spectral operators

Operators that act on:
- Eigenpairs
- Spectral coefficients
- λ-domain representations

Examples:
- Spectral filtering
- Bandlimiting
- Spectral windows

These live in:

```

bct.spectral.*
bct.eigenpairs.*

```

They are representation-agnostic once Eigenpairs are provided.

---

### 4.3 Analytic generators (kernels, windows, brushes)

These do **not transform data directly**.  
They generate functions, masks, or composite operators.

Examples:
- Gaussian kernels
- Dirac delta
- Morlet wavelets
- Brushes

They live in:

```

bct.kernels.*
bct.windows.*
bct.brushes.*

````

---

## 5. What Operators Must NOT Do

Operators must never:

- Store internal state
- Inspect UI state
- Modify Manifold, FEM, DEC, Graph objects
- Select other operators implicitly
- Perform registry or runtime lookup
- Mutate Eigenpairs

If an operator needs context, that context must be passed explicitly.

---

## 6. Explicit Execution Rule (Critical)

Operators are **never auto-dispatched**.

Correct:
```matlab
y = bct.fem.heat(FEM, x, t, k);
````

Incorrect:

```matlab
y = operators("heat")(x);   % hidden semantics
```

Execution must always show:

* which operator
* which representation
* which data

---

## 7. Guiding Principle (Pin This)

> Operators are pure functions.
> Representations supply structure.
> Execution is explicit.

Any violation of this principle is a design error.

---

````

---

# 📄 `REGISTRY.md`

```markdown
# BCT Operator Registry — Design Contract

## 1. Purpose

The `bct.registry` layer provides a **declarative catalog** of all operators available in the `bct` ecosystem.

The registry answers:
> “What operators exist, what do they require, and what do they do?”

It does **not** execute operators.

---

## 2. What the Registry Is

The registry is:
- Declarative
- Static
- Authoritative
- Representation-aware
- Execution-agnostic

It defines **truth**, not behavior.

---

## 3. What the Registry Is NOT

The registry is NOT:
- A dispatcher
- A runtime lookup table
- A dictionary for execution
- A place to store objects
- A UI state container

If registry content changes based on runtime state, it is incorrect.

---

## 4. OperatorSpec Schema (Authoritative)

Each operator is described by an `OperatorSpec`.

```matlab
OperatorSpec = struct(
    id              string,
    name            string,
    domain          string,
    representation  string,
    inputType       string,
    outputType      string,
    formDegree      double | [],
    parameters      struct,
    requires        string[],
    function        function_handle,
    purity          string,
    description     string
);
````

All fields are mandatory unless explicitly stated otherwise.

---

## 5. Required Fields Explained

### `id`

Stable, canonical identifier (used by UI and runtime).

### `domain`

One of:

* `"fem"`
* `"dec"`
* `"graph"`
* `"spectral"`

### `representation`

Fully qualified class name required (e.g., `bct.FEM`).

### `inputType` / `outputType`

Semantic data type, e.g.:

* `"signal"`
* `"coefficients"`
* `"0-form"`
* `"1-form"`

### `requires`

Capabilities assumed by the operator (used for validation).

### `function`

Function handle to the operator implementation.

### `purity`

Should almost always be `"pure"`.

---

## 6. Registry API Contract

```matlab
spec = bct.registry.operators();
```

* Returns a struct keyed by operator `id`
* Content must be deterministic
* No runtime objects allowed

---

## 7. Why the Registry Exists

The registry enables:

* Operator discovery
* UI population
* Compatibility validation
* Documentation generation
* Future extensibility

It prevents:

* Hidden assumptions
* Implicit dispatch
* Representation confusion

---

## 8. Guiding Principle (Pin This)

> The registry describes *what exists*.
> It never decides *what runs*.

---

````

---

# 📄 `RUNTIME.md`

```markdown
# BCT Runtime Layer — Design Contract

## 1. Purpose

The `bct.runtime` layer adapts the **static operator registry** to a **specific execution context**.

It answers:
> “Which operators are usable *right now*, given this Manifold and its representations?”

---

## 2. What Runtime Is

Runtime is:
- Contextual
- Dynamic
- Session-specific
- Explicitly bound

It bridges:
````

Registry → Live Objects → Execution

````

---

## 3. What Runtime Is NOT

Runtime is NOT:
- A registry
- A solver
- A dispatcher
- A place for scientific meaning

Runtime contains *plumbing*, not mathematics.

---

## 4. Runtime Context

Runtime operates on an explicit context:

```matlab
context = struct(
    "Manifold", M,
    "FEM", M.FEM(),
    "DEC", M.DEC(),
    "Graph", M.Graph()
);
````

No global state is allowed.

---

## 5. `bct.runtime.operators` (Authoritative Entry Point)

```matlab
rtOps = bct.runtime.operators(context);
```

### Returns

A **MATLAB `dictionary`**:

```matlab
dictionary(string, function_handle)
```

Only operators that:

* exist in the registry
* are compatible with the context

are included.

---

## 6. What Runtime Operators Do

Each runtime operator:

* Is a thin binding over a registry operator
* Captures required representation explicitly
* Exposes a clean execution signature

Example:

```matlab
f = rtOps("heat");
y = f(x, t, k);
```

Internally:

```matlab
@() bct.fem.heat(context.FEM, ...)
```

---

## 7. Runtime Responsibilities

Runtime may:

* Filter operators
* Bind representations
* Validate requirements
* Provide dictionaries for UI

Runtime must NOT:

* Decide which operator to use
* Execute automatically
* Hide representation usage
* Change operator semantics

---

## 8. Supporting Runtime Utilities

Recommended helpers:

```
bct.runtime.isApplicable
bct.runtime.validateCall
bct.runtime.bind
bct.runtime.context
```

These functions improve safety and clarity.

---

## 9. Why Runtime Uses `dictionary`

`dictionary` is ideal for runtime because:

* It is fast
* It is explicit
* It maps naturally to UI elements
* It is ephemeral

It must never replace the registry.

---

## 10. Guiding Principle (Pin This)

> Registry defines *truth*.
> Runtime adapts *context*.
> Execution is always explicit.

---

```

---

## ✅ Summary

You now have:

- **A formal operator philosophy**
- **A declarative registry contract**
- **A runtime execution contract**
- **Clear separation of meaning, structure, and execution**

