I have read the MATLAB tutorial carefully and internalized its execution model, data model, and constraints. Below is a **precise, workflow-oriented explanation** of how you should use `uihtml` in *your* system, grounded directly in the tutorial’s rules and examples .

I will not restate the tutorial; instead, I will translate it into **operational guidance** for your three.js viewer.

---

# How You Should Use `uihtml` in Your Workflow

## 1. The Mental Model You Must Adopt (Most Important)

From the tutorial, the key architectural fact is this:

> The HTML UI component is **not a shared-memory object**.
> It is a **message-synchronized boundary** with JSON serialization.

Everything else follows from this.

MATLAB and JavaScript:

* Do **not** share objects
* Do **not** share references
* Communicate only through:

  * **Component Data**
  * **Events**
  * **JSON serialization**

This means your workflow must be **command-oriented**, not state-sharing.

---

## 2. The `setup(htmlComponent)` Function Is the Boundary

The tutorial makes a critical point (page 1–2):

* MATLAB creates an HTML UI component
* The HTML file must define a `setup(htmlComponent)` function
* MATLAB injects a **local JavaScript object** (`htmlComponent`)
* This object is:

  * Only visible inside `setup`
  * The *only* bridge between MATLAB and JS

Implication for your system:

> You must treat `htmlComponent` as a **message port**, not an application object.

Your three.js runtime should **not be built around `htmlComponent`**.
It should be built around **pure JS modules**, with `htmlComponent` used only for I/O.

---

## 3. The Three Communication Mechanisms (and When to Use Each)

The tutorial explicitly defines **three distinct mechanisms** . You should use them differently.

---

### 3.1 Component Data (`HTMLComponent.Data`)

**What it is**

* A synchronized property
* Automatically JSON-encoded (`jsonencode` / `JSON.stringify`)
* Automatically JSON-decoded (`jsondecode` / `JSON.parse`)

**What it is for**

* Structured data transfer
* Declarative state updates
* Commands with payloads

**What it is NOT for**

* Streaming
* High-frequency updates
* Interactive events
* Continuous animation state

#### Correct usage in your workflow

Use `Data` for:

* Geometry initialization (once)
* Attribute updates (vertex/edge/face arrays)
* Viewer configuration commands

**Pattern**

MATLAB:

```matlab
comp.HTMLComponent.Data = struct( ...
    'command', 'setVertexData', ...
    'payload', values );
```

JavaScript:

```js
htmlComponent.addEventListener("DataChanged", (event) => {
  const { command, payload } = htmlComponent.Data;
  dispatchCommand(command, payload);
});
```

This exactly matches the tutorial’s “Respond to a change in component data” pattern (page 2–3).

---

### 3.2 Events from MATLAB → JavaScript

(`sendEventToHTMLSource`)

**What it is**

* Explicit, named event
* One-shot notification
* Payload serialized as JSON

**What it is for**

* Imperative triggers
* UI-driven commands
* Non-persistent actions

**What it is NOT for**

* Data ownership
* Long-lived state

#### Correct usage in your workflow

Use MATLAB → JS events for:

* “Reset view”
* “Flash selection”
* “Toggle debug overlay”
* “Recenter camera”

**Pattern**

MATLAB:

```matlab
sendEventToHTMLSource(comp.HTMLComponent, "resetView", []);
```

JavaScript (inside `setup`):

```js
htmlComponent.addEventListener("resetView", () => {
  viewer.resetCamera();
});
```

This matches the tutorial’s “Send and react to an event from MATLAB in JavaScript” section (page 2).

---

### 3.3 Events from JavaScript → MATLAB

(`htmlComponent.sendEventToMATLAB`)

**What it is**

* Notification of user interaction
* Explicit semantic signal
* Payload JSON-encoded

**What it is for**

* Picking results
* Brushing events
* Selection changes
* Interaction summaries

**What it is NOT for**

* Geometry updates
* Rendering instructions

#### Correct usage in your workflow

Use JS → MATLAB events for:

* Vertex / edge / face picked
* Region selected
* Interaction mode changed

**Pattern**

JavaScript:

```js
htmlComponent.sendEventToMATLAB("pick", {
  type: "vertex",
  index: 123
});
```

MATLAB:

```matlab
comp.HTMLComponent.HTMLEventReceivedFcn = ...
    @(src,event) handlePick(event.HTMLEventData);
```

This directly follows the tutorial’s “Send and react to an event from JavaScript in MATLAB” section (page 2–3).

---

## 4. How JSON Conversion Affects Your Design (Critical)

The tutorial explicitly states (page 2):

* MATLAB → JS: `jsonencode` → `JSON.parse`
* JS → MATLAB: `JSON.stringify` → `jsondecode`

### Consequences you must design around

1. **No typed arrays cross the boundary**

   * `single`, `double`, `int32` become plain JS arrays
2. **No functions**
3. **No circular references**
4. **No shared memory**
5. **Serialization cost is real**

#### Therefore:

* Send **geometry once**
* Cache everything in JS
* Send **indices and values**, not structures
* Never send three.js objects
* Never send handles or references

Your earlier decision to treat geometry as a one-time contract is **exactly correct** in light of this.

---

## 5. Recommended Operational Workflow (Step-by-Step)

### Step 1 — Viewer Initialization

* MATLAB creates `uihtml`
* HTML loads
* `setup(htmlComponent)` runs once

### Step 2 — Geometry Injection (once)

* MATLAB sets `HTMLComponent.Data = {command: 'setGeometry', payload: …}`
* JavaScript:

  * Receives `DataChanged`
  * Builds BufferGeometry
  * Caches it

### Step 3 — Data Updates (many times)

* MATLAB sets `Data = {command: 'setVertexData', payload: …}`
* JavaScript:

  * Updates attributes only
  * No geometry rebuild

### Step 4 — Interaction

* User clicks
* JavaScript computes index
* JavaScript sends event to MATLAB
* MATLAB updates application state

This is exactly the workflow the tutorial is designed to support.

---

## 6. What NOT to Do (Explicit Anti-Patterns)

The tutorial implicitly warns against these; in your system they would be fatal:

* ❌ Treating `Data` as a shared object
* ❌ Updating `Data` every animation frame
* ❌ Sending geometry repeatedly
* ❌ Encoding application logic in HTML
* ❌ Letting multiple JS modules talk to `htmlComponent`
* ❌ Expecting JS-side mutations of `Data` to be cheap

---

## 7. The Single Most Important Rule (from the tutorial)

> **Use `Data` for shared state, use events for actions.**

If you follow that rule, your system will:

* Be robust
* Be debuggable
* Scale in complexity
* Remain performant

---

## 8. Final Translation Into Your Project Context

In your workflow:

* `uihtml` is a **message bus**
* `htmlComponent` is a **port**
* JSON is a **serialization layer**, not a data model
* three.js is a **pure renderer**
* MATLAB is the **semantic authority**

The MATLAB tutorial fully supports — and in fact *requires* — the architecture you have been converging toward.

---
