# BCT UI Component System - Visual Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     MATLAB App Designer App                      │
│                                                                  │
│  Properties:                                                     │
│    • Toolstrip  : bct.ui.Toolstrip                              │
│    • Sidebar    : bct.ui.Sidebar                                │
│    • Console    : bct.ui.Console                                │
│    • PlotPanel  : bct.ui.PlotPanel                              │
│                                                                  │
│  Methods:                                                        │
│    • loadMesh()                                                 │
│    • computeEigenbasis()                                        │
│    • openFilterDesigner()                                       │
│    • onSidebarPropertyChange()                                  │
│    • onPlotViewChanged()                                        │
│    • etc...                                                     │
└───────────────────┬──────────────────────────────────────────────┘
                    │
                    │ creates & manages
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                    UI Component Instances                        │
├──────────────┬──────────────┬──────────────┬───────────────────┤
│  Toolstrip   │   Sidebar    │   Console    │    PlotPanel      │
│              │              │              │                   │
│  • Buttons   │  • Sections  │  • Messages  │  • Canvas         │
│  • Groups    │  • Props     │  • Filter    │  • Camera         │
│  • State     │  • Collapse  │  • Input     │  • Interaction    │
└──────┬───────┴──────┬───────┴──────┬───────┴──────┬────────────┘
       │              │              │              │
       │ inherits     │ inherits     │ inherits     │ inherits
       ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│               bct.ui.Component (Abstract Base)                   │
│                                                                  │
│  Properties:                                                     │
│    • App    : Reference to parent app                           │
│    • HTML   : HTML UI Component handle                          │
│    • ID     : Component identifier                              │
│    • State  : Component state                                   │
│                                                                  │
│  Methods:                                                        │
│    • send(message)           : MATLAB → JavaScript              │
│    • onMessage(data)         : JavaScript → MATLAB (abstract)   │
│    • loadHTML(filename)      : Load HTML template               │
│    • setState(state)         : Update state                     │
│    • enable() / disable()    : Control component                │
└───────────────────────┬──────────────────────────────────────────┘
                        │
                        │ communicates via
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│              HTML UI Component (MATLAB Built-in)                 │
│                                                                  │
│  Properties:                                                     │
│    • HTMLSource      : Path to HTML file                        │
│    • Data            : Data to send to JavaScript               │
│    • DataChangedFcn  : Callback for JavaScript messages         │
│                                                                  │
│  Flow:                                                           │
│    MATLAB → JS:  Set Data property                              │
│    JS → MATLAB:  DataChangedFcn triggered                       │
└───────────────────────┬──────────────────────────────────────────┘
                        │
                        │ loads & displays
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                HTML/CSS/JS Environment (Browser)                 │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                  HTML Template                             │ │
│  │  (toolstrip.html, sidebar.html, console.html, etc.)       │ │
│  │                                                            │ │
│  │  • Structure: <div>, <button>, <canvas>, etc.            │ │
│  │  • Links:     <link rel="stylesheet">                    │ │
│  │  • Scripts:   <script src="...">                         │ │
│  └─────────────────────┬──────────────────┬───────────────────┘ │
│                        │                  │                     │
│         ┌──────────────┘                  └────────────┐        │
│         ▼                                              ▼        │
│  ┌──────────────────┐                        ┌────────────────┐│
│  │   CSS Files      │                        │   JS Files     ││
│  │                  │                        │                ││
│  │ • bct-common.css │                        │ • bct-common.js││
│  │ • component.css  │                        │ • component.js ││
│  │                  │                        │                ││
│  │ Design System:   │                        │ Utilities:     ││
│  │ • Variables      │                        │ • BCT.*        ││
│  │ • Utilities      │                        │ • StateManager ││
│  │ • Components     │                        │ • DOM helpers  ││
│  └──────────────────┘                        └────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Communication Flow

### User Action → App Method

```
┌─────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  User   │────▶│JavaScript│────▶│  MATLAB  │────▶│   App    │
│ clicks  │     │sends msg │     │Component │     │ Method   │
│ button  │     │          │     │onMessage │     │          │
└─────────┘     └──────────┘     └──────────┘     └──────────┘
   (1)              (2)               (3)              (4)

1. User clicks button in HTML UI
2. JavaScript: BCT.sendToMatlab(id, 'buttonClick', {id: 'load'})
3. MATLAB: DataChangedFcn → obj.onMessage(data)
4. App: Component routes to app.loadMesh()
```

### State Update → UI Refresh

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌─────────┐
│   App    │────▶│  MATLAB  │────▶│JavaScript│────▶│   DOM   │
│  Logic   │     │Component │     │ receives │     │  Update │
│          │     │  send()  │     │ message  │     │         │
└──────────┘     └──────────┘     └──────────┘     └─────────┘
   (1)              (2)               (3)              (4)

1. App updates data: app.Sidebar.addSection(section)
2. MATLAB: obj.send(struct('cmd', 'addSection', ...))
3. JavaScript: BCT.onMatlabMessage receives message
4. DOM: JavaScript updates HTML elements
```

## File Dependencies

```
Component.m  ──┐
               ├──▶ Toolstrip.m
               ├──▶ Sidebar.m
               ├──▶ Console.m
               └──▶ PlotPanel.m

toolstrip.html ──┬──▶ bct-common.css
                 ├──▶ toolstrip.css
                 ├──▶ bct-common.js
                 └──▶ toolstrip.js

sidebar.html ────┬──▶ bct-common.css
                 ├──▶ sidebar.css
                 ├──▶ bct-common.js
                 └──▶ sidebar.js

console.html ────┬──▶ bct-common.css
                 ├──▶ console.css
                 ├──▶ bct-common.js
                 └──▶ console.js

plotpanel.html ──┬──▶ bct-common.css
                 ├──▶ plotpanel.css
                 ├──▶ bct-common.js
                 └──▶ plotpanel.js
```

## Component Lifecycle

```
┌──────────────────────────────────────────────────────────┐
│                    Component Lifecycle                    │
└──────────────────────────────────────────────────────────┘

1. CONSTRUCTION
   ┌────────────────────────────────────────┐
   │ app.Toolstrip = bct.ui.Toolstrip(...)  │
   │   • Set App, HTML, ID properties       │
   │   • Register DataChangedFcn            │
   │   • Initialize state                   │
   └────────────────┬───────────────────────┘
                    │
                    ▼
2. INITIALIZATION
   ┌────────────────────────────────────────┐
   │ obj.loadHTML("toolstrip.html")         │
   │   • HTMLSource set                     │
   │   • Browser loads HTML                 │
   │   • CSS and JS files load              │
   └────────────────┬───────────────────────┘
                    │
                    ▼
3. READY EVENT
   ┌────────────────────────────────────────┐
   │ JavaScript: BCT.sendToMatlab('ready')  │
   │   • JS initialization complete         │
   │   • DOM elements ready                 │
   │   • Event listeners attached           │
   └────────────────┬───────────────────────┘
                    │
                    ▼
4. CONFIGURATION
   ┌────────────────────────────────────────┐
   │ obj.sendConfiguration()                │
   │   • Send initial settings              │
   │   • JS configures UI                   │
   │   • Component ready for use            │
   └────────────────┬───────────────────────┘
                    │
                    ▼
5. OPERATION
   ┌────────────────────────────────────────┐
   │ Component Active                       │
   │   • Handle user interactions           │
   │   • Process messages                   │
   │   • Update state                       │
   │   • Trigger app callbacks              │
   └────────────────────────────────────────┘
```

## Message Structure

### MATLAB → JavaScript
```matlab
% Example message structure
message = struct(...
    'id', 'Toolstrip',              % Component ID
    'cmd', 'addButton',             % Command
    'timestamp', posixtime(now),    % Timestamp
    'button', struct(               % Additional data
        'id', 'myBtn',
        'label', 'My Button',
        'icon', '🎯'));

% Send via component
obj.send(message);

% Transmitted as JSON to JavaScript
```

### JavaScript → MATLAB
```javascript
// Example message structure
const message = {
    id: 'Toolstrip',           // Component ID
    cmd: 'buttonClick',        // Command
    timestamp: Date.now(),     // Timestamp
    buttonId: 'myBtn'          // Additional data
};

// Send via utility
BCT.sendToMatlab('Toolstrip', 'buttonClick', {
    buttonId: 'myBtn'
});

// Received in MATLAB DataChangedFcn
```

## Design System Hierarchy

```
bct-common.css
├── CSS Variables (:root)
│   ├── Colors (primary, secondary, status)
│   ├── Spacing (xs, sm, md, lg, xl)
│   ├── Typography (fonts, sizes, weights)
│   ├── Borders (radii, widths)
│   ├── Shadows (sm, md, lg)
│   └── Transitions (fast, normal, slow)
│
├── Base Styles
│   ├── .bct-component (reset & base)
│   └── Scrollbar styling
│
├── Component Classes
│   ├── .bct-btn (and variants)
│   ├── .bct-input
│   ├── .bct-select
│   ├── .bct-card
│   └── .bct-notification
│
└── Utility Classes
    ├── Layout (.bct-flex, .bct-flex-column)
    ├── Spacing (.bct-mt-*, .bct-p-*)
    └── Display (.bct-hidden, .bct-visible)

component.css (inherits from common)
└── Component-specific styles
    ├── .component-container
    ├── .component-element
    └── .component-modifier
```

## State Management

```
┌─────────────────────────────────────────────────────────┐
│                    State Flow                            │
└─────────────────────────────────────────────────────────┘

MATLAB Side:
┌──────────────────────────────────────────┐
│ Component.State (struct)                 │
│   • Property1: value1                    │
│   • Property2: value2                    │
│                                          │
│ Methods:                                 │
│   • setState(newState)                   │
│   • getState()                           │
└──────────────┬───────────────────────────┘
               │
               │ obj.send({cmd: 'stateUpdate', state: {...}})
               │
               ▼
JavaScript Side:
┌──────────────────────────────────────────┐
│ BCT.StateManager                         │
│   • state = {prop1: val1, prop2: val2}   │
│   • listeners = [fn1, fn2, ...]          │
│                                          │
│ Methods:                                 │
│   • get(key)                             │
│   • set(key, value)                      │
│   • subscribe(listener)                  │
│   • notify()                             │
└──────────────┬───────────────────────────┘
               │
               │ state changes trigger
               │
               ▼
┌──────────────────────────────────────────┐
│ UI Update                                │
│   • Re-render affected elements          │
│   • Update DOM                           │
│   • Trigger animations                   │
└──────────────────────────────────────────┘
```

## Error Handling Chain

```
Error occurs in:
  │
  ├─ JavaScript
  │    ├─ try-catch block
  │    ├─ console.error()
  │    ├─ BCT.notify(error, 'error')
  │    └─ Send error to MATLAB (optional)
  │
  └─ MATLAB
       ├─ try-catch block
       ├─ warning() with ID
       ├─ Log to Console component
       └─ Send error to JavaScript (optional)

Result: Error handled gracefully at each level
```

---

This visual architecture provides a comprehensive overview of how all pieces fit together in the BCT UI Component System.
