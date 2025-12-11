# BCT Tailwind UI System - Complete Guide

## Overview

The BCT Tailwind UI System is a modern, portable design system built with Tailwind CSS for the BCT Toolbox. It provides reusable UI components that work seamlessly with MATLAB App Designer while remaining portable to Electron, web applications, and other platforms.

## Key Features

- **🎨 Modern Design**: Built with Tailwind CSS utility classes
- **🌓 Dark/Light Mode**: Automatic theme switching with localStorage persistence
- **📱 Responsive**: Mobile-first design with responsive breakpoints
- **🔌 Portable**: Works in MATLAB, Electron, and web browsers
- **🎭 Component Library**: Pre-built Toolstrip, Sidebar, Console, PlotPanel, Modal
- **🧩 Element Kit**: Reusable buttons, inputs, sliders, toggles, tabs, badges
- **💬 MATLAB Bridge**: Bidirectional communication API
- **⚡ Performance**: Optimized with debounce, throttle, RAF helpers
- **🎯 Type-Safe**: Structured state management with observers

## Quick Start

### 1. Build Tailwind CSS

```bash
cd toolbox/+bct/+ui/tailwind
npm install
npm run build
```

This generates `dist/bct-ui.css` (minified, ~100KB).

### 2. Use in HTML Components

```html
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="../dist/bct-ui.css">
</head>
<body>
  <div class="card">
    <div class="card-header">My Component</div>
    <div class="card-body">
      <button class="btn btn-primary">Action</button>
    </div>
  </div>
  
  <script src="../dist/bct-ui.js"></script>
  <script src="./my-component.js"></script>
</body>
</html>
```

### 3. Integrate with MATLAB

```matlab
classdef MyComponent < bct.ui.Component
    methods
        function obj = MyComponent(app, htmlControl)
            obj@bct.ui.Component(app, htmlControl);
            obj.HTMLPath = fullfile(obj.getUIPath(), 'tailwind', 'components', 'my-component.html');
            obj.loadHTML();
        end
        
        function onMessage(obj, data)
            switch data.cmd
                case 'buttonClick'
                    obj.App.handleButtonClick();
            end
        end
    end
end
```

## Architecture

### Component System

```
BCT.StateManager          - Observable state management
BCT.sendToMatlab()        - Send messages to MATLAB
BCT.onMatlabMessage()     - Receive messages from MATLAB
BCT.createElement()       - DOM manipulation helper
BCT.debounce/throttle()   - Performance utilities
BCT.NotificationManager   - Toast notification system
BCT.getIcon()             - SVG icon library
```

### Communication Flow

```
MATLAB ←→ HTML UI Component ←→ JavaScript
  ↓                              ↓
bct.ui.Component            BCT utilities
  ↓                              ↓
onMessage()                 sendToMatlab()
```

## Components

### Toolstrip

Horizontal toolbar with grouped action buttons.

**Features:**
- Button groups with separators
- Active/inactive states
- Icon buttons with labels
- Theme toggle
- Settings button

**Usage:**
```javascript
BctToolstrip.init({
  data: {
    id: 'data',
    label: 'Data',
    buttons: [
      { id: 'load', label: 'Load', icon: 'upload', cmd: 'loadMesh' }
    ]
  }
});

// Add button dynamically
BctToolstrip.addButton('data', {
  id: 'save',
  label: 'Save',
  icon: 'save',
  cmd: 'saveMesh'
});

// Enable/disable button
BctToolstrip.setButtonEnabled('load', false);
```

**MATLAB Integration:**
```matlab
% In App Designer startup
app.Toolstrip = bct.ui.Toolstrip(app, app.HTMLToolstrip);

% Handle button click
function loadMesh(app)
    % Load mesh logic
end
```

### Sidebar

Collapsible sidebar with sectioned controls.

**Features:**
- Collapsible sections
- Multiple control types (slider, toggle, dropdown, input, button)
- Dynamic updates
- Card-based layout

**Usage:**
```javascript
BctSidebar.init({
  meshProperties: {
    id: 'meshProperties',
    title: 'Mesh Properties',
    controls: [
      {
        id: 'opacity',
        type: 'slider',
        label: 'Opacity',
        min: 0,
        max: 1,
        step: 0.1,
        value: 1
      },
      {
        id: 'wireframe',
        type: 'toggle',
        label: 'Wireframe',
        value: false
      }
    ]
  }
});

// Update control value
BctSidebar.updateControl('meshProperties', 'opacity', 0.5);
```

**MATLAB Integration:**
```matlab
app.Sidebar = bct.ui.Sidebar(app, app.HTMLSidebar);

% Handle control change
function handleControlChange(app, controlId, value)
    switch controlId
        case 'opacity'
            app.setMeshOpacity(value);
    end
end
```

### Console

Terminal-style logging panel with command input.

**Features:**
- Color-coded log levels (info, success, warning, error)
- Command input with history
- Message filtering
- Export log to file
- Auto-scroll
- Clear all

**Usage:**
```javascript
BctConsole.init();

// Log messages
BctConsole.log('Regular message');
BctConsole.info('Information');
BctConsole.success('Operation successful');
BctConsole.warn('Warning message');
BctConsole.error('Error occurred');

// Clear console
BctConsole.clear();
```

**MATLAB Integration:**
```matlab
app.Console = bct.ui.Console(app, app.HTMLConsole);

app.Console.log('info', 'BCT initialized');
app.Console.success('Mesh loaded successfully');
```

### PlotPanel

Interactive 2D/3D visualization container.

**Features:**
- Canvas, SVG, and WebGL support
- Interaction modes (rotate, pan, zoom, select)
- Mouse/wheel controls
- Status bar with coordinates and FPS
- Reset view
- Export image
- Loading overlay

**Usage:**
```javascript
BctPlotPanel.init();

// Plot mesh
BctPlotPanel.plotMesh({
  vertices: [...],
  faces: [...]
});

// Plot signal
BctPlotPanel.plotSignal(signalData, {
  colormap: 'jet',
  range: [0, 1]
});

// Set interaction mode
BctPlotPanel.setMode('pan');

// Reset view
BctPlotPanel.resetView();
```

**MATLAB Integration:**
```matlab
app.PlotPanel = bct.ui.PlotPanel(app, app.HTMLPlotPanel);

% Plot mesh
app.PlotPanel.plotMesh(struct('vertices', V, 'faces', F));

% Handle interaction
function handleRotate(app, dx, dy)
    % Update view
end
```

### Modal

Reusable modal dialog system.

**Features:**
- Alert (OK only)
- Confirm (OK/Cancel)
- Prompt (input field)
- Custom HTML content
- Backdrop click to close
- Escape key support
- Animation

**Usage:**
```javascript
// Alert
BctModal.alert('Success', 'Operation completed', () => {
  console.log('User clicked OK');
});

// Confirm
BctModal.confirm('Delete', 'Are you sure?', 
  () => console.log('Confirmed'),
  () => console.log('Cancelled')
);

// Prompt
BctModal.prompt('Enter Name', 'Please enter your name:', 'Default', 
  (value) => console.log('Entered:', value)
);

// Custom
const customContent = BCT.createElement('div', {},
  BCT.createElement('p', {}, 'Custom HTML content')
);
BctModal.custom('Custom Dialog', customContent);
```

**MATLAB Integration:**
```matlab
app.Modal = bct.ui.Modal(app, app.HTMLModal);

app.Modal.alert('Information', 'Process complete');
app.Modal.confirm('Confirm Action', 'Continue?');
```

## UI Elements

### Buttons

```html
<button class="btn btn-primary">Primary</button>
<button class="btn btn-secondary">Secondary</button>
<button class="btn btn-ghost">Ghost</button>
<button class="btn-icon"><svg>...</svg></button>
<button class="btn-icon active"><svg>...</svg></button>
```

### Inputs

```html
<input type="text" class="input w-full" placeholder="Text">
<input type="number" class="input w-full" placeholder="Number">
<select class="select w-full"><option>...</option></select>
```

### Sliders

```html
<input type="range" class="slider" min="0" max="100" value="50">
```

### Toggles

```html
<button class="toggle">
  <span class="toggle-thumb"></span>
</button>
<button class="toggle active">
  <span class="toggle-thumb"></span>
</button>
```

### Tabs

```html
<div class="tabs">
  <button class="tab active">Tab 1</button>
  <button class="tab">Tab 2</button>
</div>
```

### Cards

```html
<div class="card">
  <div class="card-header">Title</div>
  <div class="card-body">Content</div>
</div>
```

### Badges

```html
<span class="badge badge-primary">Primary</span>
<span class="badge badge-success">Success</span>
<span class="badge badge-warning">Warning</span>
<span class="badge badge-error">Error</span>
```

### Notifications

```javascript
BCT.notify.show('Message', 'info', 5000);  // type: info, success, warning, error
BCT.notify.dismiss(id);
BCT.notify.clear();
```

## Theming

### Dark/Light Mode

```javascript
// Toggle theme
BCT.toggleDarkMode();

// Set specific theme
BCT.setTheme('dark');  // or 'light'

// Get current theme
const theme = BCT.getTheme();  // returns 'dark' or 'light'

// Initialize theme (auto-runs on load)
BCT.initTheme();
```

The theme is stored in `localStorage` and persists across sessions.

### Custom Colors

Tailwind config defines BCT brand colors:

```javascript
colors: {
  bct: {
    primary: '#2563eb',
    secondary: '#7c3aed',
    accent: '#06b6d4',
    success: '#10b981',
    warning: '#f59e0b',
    error: '#ef4444',
    info: '#3b82f6'
  }
}
```

Use in HTML:
```html
<div class="bg-bct-primary text-white">Primary colored</div>
<button class="text-bct-accent">Accent text</button>
```

## State Management

```javascript
// Create state manager
const state = new BCT.StateManager({ count: 0 });

// Get state
const count = state.get('count');
const all = state.get();

// Set state
state.set('count', 1);
state.set({ count: 2, name: 'Test' });

// Subscribe to changes
const unsubscribe = state.subscribe((newState, oldState) => {
  console.log('State changed:', newState);
});

// Subscribe to specific keys
state.subscribe((newState) => {
  console.log('Count changed');
}, ['count']);

// Undo
state.undo();

// Clear
state.clear();
```

## Utilities

### DOM Helpers

```javascript
// Create element
const btn = BCT.createElement('button', {
  className: 'btn btn-primary',
  onClick: () => console.log('Clicked')
}, 'Click Me');

// Query selectors
const element = BCT.$('#my-id');
const elements = BCT.$$('.my-class');

// Event listeners with cleanup
const remove = BCT.on(element, 'click', handler);
remove();  // Remove listener
```

### Performance

```javascript
// Debounce (wait until user stops typing)
const search = BCT.debounce((query) => {
  console.log('Searching:', query);
}, 300);

// Throttle (limit rate)
const scroll = BCT.throttle(() => {
  console.log('Scrolled');
}, 100);

// Request animation frame
BCT.raf(() => {
  // Animation logic
});
```

### Data Formatting

```javascript
// Format numbers
BCT.formatNumber(1500);      // "1.50K"
BCT.formatNumber(2500000);   // "2.50M"
BCT.formatNumber(3e9);       // "3.00G"

// Format time
BCT.formatTime();  // "14:30:45"

// Clamp value
BCT.clamp(150, 0, 100);  // 100

// Linear interpolation
BCT.lerp(0, 100, 0.5);  // 50
```

### Icons

```javascript
// Get icon SVG
const icon = BCT.getIcon('play');
element.innerHTML = icon;

// Available icons
BCT.ICONS.menu
BCT.ICONS.close
BCT.ICONS.check
BCT.ICONS.chevronDown
BCT.ICONS.play
BCT.ICONS.pause
BCT.ICONS.settings
BCT.ICONS.save
BCT.ICONS.upload
BCT.ICONS.download
```

## Responsive Design

Tailwind breakpoints:
- `sm:` - 640px+
- `md:` - 768px+
- `lg:` - 1024px+
- `xl:` - 1280px+
- `2xl:` - 1536px+

Example:
```html
<div class="hidden md:block">Visible on medium+ screens</div>
<div class="text-sm lg:text-lg">Responsive text size</div>
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <!-- Responsive grid -->
</div>
```

## Build & Deploy

### Development

```bash
npm run dev      # Build CSS (unminified)
npm run watch    # Watch mode (auto-rebuild)
```

### Production

```bash
npm run build    # Build CSS (minified)
```

### Integration Steps

1. **Build Tailwind CSS**
   ```bash
   cd toolbox/+bct/+ui/tailwind
   npm run build
   ```

2. **Create HTML Component**
   - Place in `components/`
   - Include `dist/bct-ui.css`
   - Include `dist/bct-ui.js`
   - Include component-specific JS

3. **Create MATLAB Wrapper**
   - Extend `bct.ui.Component`
   - Set `HTMLPath` to component HTML
   - Implement `onMessage()` handler

4. **Use in App Designer**
   - Add HTML UI Component to app
   - Initialize in `startupFcn`
   - Handle callbacks

## Examples

See:
- `components/elements/ui-elements.html` - All UI elements
- `components/elements/ELEMENT_REFERENCE.md` - Quick reference
- `components/*.html` - Component demos

## Portability

The system is designed to work in:

1. **MATLAB App Designer**
   - Uses `matlab.ui.control.HTML`
   - Communication via `Data` property
   - Full integration with `bct.ui.Component`

2. **Electron Apps**
   - Use `ipcRenderer` for communication
   - Replace `BCT.sendToMatlab()` with `ipcRenderer.send()`
   - Replace `BCT.onMatlabMessage()` with `ipcRenderer.on()`

3. **Web Apps**
   - Use WebSocket, REST API, or Server-Sent Events
   - Replace communication bridge
   - All UI components work as-is

## Performance Tips

1. **Debounce input handlers**
   ```javascript
   const handleInput = BCT.debounce((value) => {
     BCT.sendToMatlab('valueChanged', { value });
   }, 300);
   ```

2. **Throttle scroll/mouse handlers**
   ```javascript
   const handleScroll = BCT.throttle(() => {
     // Update UI
   }, 100);
   ```

3. **Use RAF for animations**
   ```javascript
   function animate() {
     // Animation logic
     BCT.raf(animate);
   }
   ```

4. **Minimize DOM updates**
   - Use state management
   - Batch updates
   - Use virtual DOM patterns

## Troubleshooting

### CSS not loading
- Verify `npm run build` completed successfully
- Check `dist/bct-ui.css` exists
- Verify path in HTML `<link>` tag

### MATLAB communication not working
- Check `HTMLPath` in MATLAB component
- Verify `loadHTML()` was called
- Check browser console for errors
- Verify `DataChangedFcn` is set

### Dark mode not persisting
- Check localStorage is enabled
- Verify `BCT.initTheme()` runs on load
- Check HTML has `class="dark"` attribute

### Components not rendering
- Verify Tailwind CSS is loaded
- Check browser console for JavaScript errors
- Verify component JS files are loaded in order

## License

MIT

## Support

For issues and questions:
1. Check this guide
2. Review component source code
3. Check browser console for errors
4. Review MATLAB command window for errors
