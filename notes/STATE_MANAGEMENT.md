# State Management System

## Overview

The `bct.ui.manifold.viewer` now uses a centralized **finite state machine** (FSM) to manage application state, coordinate async operations, prevent race conditions, and gate user actions.

## Architecture

### Top-Level States (AppState)

```
idle → loading → ready ⇄ computing → ready
  ↓       ↓        ↓         ↓
  └───────┴────────┴─────────┴──→ error → ready
```

| State | Description | Allowed Actions |
|-------|-------------|-----------------|
| `idle` | No mesh loaded | Load mesh, Reset |
| `loading` | Asset/data load in progress | Cancel |
| `ready` | Interactive, stable | Load mesh, Load data, Compute, Clear, Reset |
| `computing` | Compute job running | Cancel |
| `error` | Recoverable error state | Recover, Reset |
| `canceling` | Canceling operation | (none - transitional) |

### Sub-State Slices

Each subsystem maintains its own state slice:

**Mesh State:**
```javascript
{
  status: 'none' | 'loading' | 'loaded' | 'failed',
  vertexCount: number,
  faceCount: number,
  bounds: Box3 | null
}
```

**Compute State:**
```javascript
{
  status: 'idle' | 'running' | 'failed',
  operation: string | null,
  progress: number (0-100),
  requestId: number | null
}
```

**Visualization State:**
```javascript
{
  status: 'idle' | 'attached' | 'rendering' | 'failed',
  material: 'default' | 'wireframe',
  helpers: { vertexNormals: bool, tangents: bool }
}
```

**Data State:**
```javascript
{
  status: 'none' | 'loading' | 'ready' | 'failed',
  type: 'scalar' | 'vector' | null,
  count: number,
  range: [min, max]
}
```

## Event-Driven Transitions

State changes are triggered by **events**, not direct mutations:

### Mesh Events
- `LOAD_MESH_REQUESTED` - User requests mesh load
- `LOAD_MESH_SUCCEEDED` - Mesh loaded successfully
- `LOAD_MESH_FAILED` - Mesh load error
- `CLEAR_MESH_REQUESTED` - Clear current mesh

### Data Events
- `LOAD_DATA_REQUESTED` - Scalar/vector data load requested
- `LOAD_DATA_SUCCEEDED` - Data loaded successfully
- `LOAD_DATA_FAILED` - Data load error
- `CLEAR_DATA_REQUESTED` - Clear scalar data

### Compute Events (Future)
- `COMPUTE_REQUESTED` - Start computation (eigenpairs, DEC, etc.)
- `COMPUTE_PROGRESS` - Progress update
- `COMPUTE_SUCCEEDED` - Computation complete
- `COMPUTE_FAILED` - Computation error

### Control Events
- `CANCEL_REQUESTED` - Cancel current operation
- `ERROR_RECOVERED` - Recover from error
- `RESET_REQUESTED` - Reset to idle state

## Request Token System

To prevent **race conditions** and **stale responses**, all async operations use request tokens:

```javascript
// Generate token when starting operation
const requestId = stateManager.generateRequestId(); // e.g., 42

// Dispatch event with token
stateManager.dispatch(StateEvent.LOAD_MESH_REQUESTED, { requestId });

// When response arrives, check token
if (payload.requestId !== stateManager.mesh.requestId) {
  // Stale response - ignore
  return;
}
```

**Prevents:**
- User clicks "Load Mesh A" then "Load Mesh B" - only B loads
- Old compute results overwriting new results
- Mesh switching mid-computation causing corruption

## Integration Points

### render.js (Main Orchestrator)
```javascript
import { StateManager, StateEvent, AppState } from './core/stateManager.js';

// Initialize
stateManager = new StateManager();

// Check before action
if (!stateManager.canPerformAction(StateEvent.LOAD_MESH_REQUESTED)) {
  console.warn('Cannot load mesh in current state');
  return;
}

// Dispatch events
const requestId = stateManager.generateRequestId();
stateManager.dispatch(StateEvent.LOAD_MESH_REQUESTED, { requestId });

// ... perform operation ...

stateManager.dispatch(StateEvent.LOAD_MESH_SUCCEEDED, {
  requestId,
  vertexCount,
  faceCount,
  bounds
});
```

### Event Listeners
```javascript
// Subscribe to specific events
stateManager.on(StateEvent.LOAD_MESH_SUCCEEDED, (current, previous) => {
  console.log('Mesh loaded:', current.mesh);
});

// Subscribe to all events (global listener)
stateManager.on('*', (event, current, previous) => {
  console.log('State transition:', event);
});
```

## Usage Examples

### Loading a Mesh
```javascript
// From MATLAB: v.setMesh(M)
// JavaScript internally:

const requestId = stateManager.generateRequestId();
stateManager.dispatch(StateEvent.LOAD_MESH_REQUESTED, { requestId });

try {
  meshManager.setMeshFromBuffers(meshData);
  stateManager.dispatch(StateEvent.LOAD_MESH_SUCCEEDED, {
    requestId,
    vertexCount: 10242,
    faceCount: 20480
  });
} catch (err) {
  stateManager.dispatch(StateEvent.LOAD_MESH_FAILED, { error: err.message });
}
```

### Loading Scalar Data
```javascript
// From MATLAB: v.setScalar(data)
// JavaScript internally:

const requestId = stateManager.generateRequestId();
stateManager.dispatch(StateEvent.LOAD_DATA_REQUESTED, { requestId });

try {
  scalarMapper.applyToMesh(mesh, data, { colormap, clim });
  stateManager.dispatch(StateEvent.LOAD_DATA_SUCCEEDED, {
    requestId,
    type: 'scalar',
    count: data.length,
    range: [min, max]
  });
} catch (err) {
  stateManager.dispatch(StateEvent.LOAD_DATA_FAILED, { error: err.message });
}
```

### Clearing Mesh
```javascript
// From MATLAB: v.clearMesh()
// JavaScript internally:

stateManager.dispatch(StateEvent.CLEAR_MESH_REQUESTED);
meshManager.clearModel();
// State automatically transitions: ready → idle
```

## Debugging

### Get Current State
```javascript
// In browser console or MATLAB
const state = getAppState(); // 'idle' | 'loading' | 'ready' | ...
```

### Get Full Snapshot
```javascript
const snapshot = getStateSnapshot();
console.log(snapshot);
// {
//   state: 'ready',
//   mesh: { status: 'loaded', vertexCount: 10242, ... },
//   compute: { status: 'idle', ... },
//   viz: { status: 'attached', ... },
//   data: { status: 'ready', type: 'scalar', ... }
// }
```

### View Transition History
```javascript
const history = getStateHistory();
console.log(history);
// [
//   { timestamp: 1736308800000, previousState: 'idle', 
//     event: 'LOAD_MESH_REQUESTED', newState: 'loading' },
//   { timestamp: 1736308801500, previousState: 'loading',
//     event: 'LOAD_MESH_SUCCEEDED', newState: 'ready' },
//   ...
// ]
```

## Benefits

### 1. **Deterministic Behavior**
- Actions only allowed in appropriate states
- Predictable state transitions
- No ambiguous "half-loaded" states

### 2. **Race Condition Prevention**
- Request tokens prevent stale responses
- Only matching requestId accepted
- Safe for rapid user interactions

### 3. **Error Recovery**
- Errors transition to `error` state
- Can recover to `ready` or `idle`
- No silent failures

### 4. **Debugging**
- Full state history tracking
- Event-driven transitions are auditable
- Single source of truth

### 5. **Future-Proof**
- Easy to add compute events (eigenpairs, DEC)
- Cancel/progress support built-in
- Multi-step pipeline ready

## Future Enhancements

### Compute Integration (To Be Implemented)
```javascript
// Start eigenpair computation
const requestId = stateManager.generateRequestId();
stateManager.dispatch(StateEvent.COMPUTE_REQUESTED, {
  requestId,
  operation: 'eigenpairs',
  params: { k: 100 }
});

// Progress updates from MATLAB
stateManager.dispatch(StateEvent.COMPUTE_PROGRESS, {
  requestId,
  progress: 45 // 45%
});

// Completion
stateManager.dispatch(StateEvent.COMPUTE_SUCCEEDED, {
  requestId
});
```

### Cancel Support
```javascript
// User clicks cancel
if (stateManager.canPerformAction(StateEvent.CANCEL_REQUESTED)) {
  stateManager.dispatch(StateEvent.CANCEL_REQUESTED);
  // Signal MATLAB to abort computation
  htmlComponent.sendEventToMATLAB('CancelCompute', { requestId });
}
```

### Multi-Step Pipelines
```javascript
// load → preprocess → compute → render
stateManager.on(StateEvent.LOAD_MESH_SUCCEEDED, () => {
  // Automatically start preprocessing
  startPreprocessing();
});

stateManager.on(StateEvent.COMPUTE_SUCCEEDED, () => {
  // Automatically apply results
  applyComputeResults();
});
```

## File Locations

- **State Manager Implementation**: `toolbox/+bct/+ui/+manifold/+viewer/web/core/stateManager.js`
- **Integration**: `toolbox/+bct/+ui/+manifold/+viewer/web/render.js`
- **Documentation**: `docs/STATE_MANAGEMENT.md`

## API Reference

### StateManager Class

#### Methods
- `getState()` - Get current app state
- `getSnapshot()` - Get complete state snapshot
- `generateRequestId()` - Generate unique request token
- `canPerformAction(action)` - Check if action is allowed
- `dispatch(event, payload)` - Dispatch state event
- `on(event, callback)` - Subscribe to events
- `getHistory()` - Get transition history
- `clearHistory()` - Clear history

#### Events
See `StateEvent` enum in `stateManager.js`

#### States
See `AppState`, `MeshStatus`, `ComputeStatus`, `VizStatus`, `DataStatus` enums
