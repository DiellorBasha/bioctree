# BCT UI Component System

A professional HTML/CSS/JS component library for MATLAB App Designer applications, providing reusable, interactive UI elements with bidirectional MATLAB-JavaScript communication.

## 📋 Overview

The `bct.ui` package provides a complete framework for building modern, interactive user interfaces within MATLAB App Designer using HTML5, CSS3, and JavaScript. All components inherit from a shared base class and follow a consistent architecture for communication between MATLAB and JavaScript.

## 🏗️ Architecture

### Component Hierarchy

```
bct.ui.Component (abstract base class)
├── bct.ui.Toolstrip
├── bct.ui.Sidebar
├── bct.ui.Console
└── bct.ui.PlotPanel
```

### Directory Structure

```
toolbox/+bct/+ui/
├── Component.m          # Abstract base class
├── Toolstrip.m          # Toolbar component
├── Sidebar.m            # Navigation/controls component
├── Console.m            # Logging component
├── PlotPanel.m          # Visualization component
├── html/                # HTML templates
│   ├── toolstrip.html
│   ├── sidebar.html
│   ├── console.html
│   └── plotpanel.html
├── js/                  # JavaScript logic
│   ├── bct-common.js    # Shared utilities
│   ├── toolstrip.js
│   ├── sidebar.js
│   ├── console.js
│   └── plotpanel.js
└── css/                 # Stylesheets
    ├── bct-common.css   # Design system & utilities
    ├── toolstrip.css
    ├── sidebar.css
    ├── console.css
    └── plotpanel.css
```

## 🚀 Getting Started

### 1. Create HTML UI Components in App Designer

In your App Designer application:

1. Drag **HTML UI Component** widgets onto your canvas
2. Name them appropriately (e.g., `HTMLToolstrip`, `HTMLSidebar`, `HTMLConsole`, `HTMLPlot`)
3. Size and position them as needed

### 2. Initialize Components in startupFcn

```matlab
function startupFcn(app)
    % Initialize UI components
    app.Toolstrip = bct.ui.Toolstrip(app, app.HTMLToolstrip);
    app.Sidebar = bct.ui.Sidebar(app, app.HTMLSidebar);
    app.Console = bct.ui.Console(app, app.HTMLConsole);
    app.PlotPanel = bct.ui.PlotPanel(app, app.HTMLPlot);
    
    % Log initialization
    app.Console.log('Application initialized');
end
```

### 3. Use Components in Your App

```matlab
% Toolstrip - responds to button clicks automatically
% Just implement the methods it calls:
function loadMesh(app)
    app.Console.log('Loading mesh...');
    % Your mesh loading code
end

function computeEigenbasis(app)
    app.Console.log('Computing eigenbasis...');
    app.Toolstrip.disableButton('computeEigenbasis');
    % Your computation code
    app.Toolstrip.enableButton('computeEigenbasis');
    app.Console.success('Eigenbasis computed');
end

% Sidebar - add custom sections
function setupSidebar(app)
    meshInfo = struct(...
        'id', 'meshInfo', ...
        'title', 'Mesh Properties', ...
        'content', struct(...
            'Vertices', 10242, ...
            'Faces', 20480, ...
            'Type', 'Cortical Surface'));
    app.Sidebar.addSection(meshInfo);
    
    params = struct(...
        'id', 'params', ...
        'title', 'Parameters', ...
        'content', struct(...
            'Eigenmodes', 50, ...
            'Smoothing', 0.5, ...
            'Threshold', 0.01));
    app.Sidebar.addSection(params);
end

% Console - log messages with different levels
function processData(app)
    app.Console.log('Processing started');
    app.Console.warn('Using default parameters');
    
    try
        % Process data
        app.Console.success('Processing complete');
    catch ME
        app.Console.error('Processing failed: %s', ME.message);
    end
end

% PlotPanel - visualize data
function plotMeshData(app, vertices, faces, signal)
    if isempty(signal)
        app.PlotPanel.plotMesh(vertices, faces);
    else
        app.PlotPanel.plotSignal(vertices, faces, signal, ...
            'Colormap', 'parula', ...
            'CLim', [min(signal), max(signal)]);
    end
end
```

## 📦 Components

### bct.ui.Toolstrip

**Purpose**: Horizontal toolbar with grouped buttons for common operations.

**Key Methods**:
- `addButton(id, label, icon, group)` - Add custom button
- `removeButton(id)` - Remove button
- `enableButton(id)` / `disableButton(id)` - Control button state
- `setButtonState(id, isActive)` - Set toggle state

**Default Button Groups**:
- **Data**: Load Mesh, Load Signal, Save
- **Analysis**: Compute Eigenbasis, Transform, Filter Designer
- **Visualization**: 3D Plot, Spectrum, Animate

**App Methods Called** (implement these in your app):
- `loadMesh()`, `loadSignal()`, `saveData()`
- `computeEigenbasis()`, `performTransform()`, `openFilterDesigner()`
- `plot3D()`, `plotSpectrum()`, `animateSignal()`
- `handleCustomButton(buttonId)` - For custom buttons

---

### bct.ui.Sidebar

**Purpose**: Collapsible panel with sections for properties and controls.

**Key Methods**:
- `addSection(section)` - Add section with title and content
- `removeSection(id)` - Remove section
- `updateSection(id, content)` - Update section content
- `collapse()` / `expand()` / `toggle()` - Control visibility
- `setWidth(width)` - Set sidebar width in pixels

**Section Structure**:
```matlab
section = struct(...
    'id', 'uniqueId', ...
    'title', 'Section Title', ...
    'content', struct('Property1', value1, 'Property2', value2), ...
    'collapsed', false);
```

**App Methods Called** (optional):
- `onSidebarSectionToggle(sectionId, collapsed)`
- `onSidebarPropertyChange(sectionId, propertyName, value)`

---

### bct.ui.Console

**Purpose**: Terminal-style logging panel with filtering and command input.

**Key Methods**:
- `log(message, ...)` - Log info message
- `warn(message, ...)` - Log warning
- `error(message, ...)` - Log error
- `success(message, ...)` - Log success
- `clear()` - Clear all messages
- `setFilter(level)` - Set filter level (0=all, 1=info+, 2=warn+, 3=error)
- `exportLog(filename)` - Export to file
- `setMaxMessages(max)` - Set message limit
- `setAutoScroll(enabled)` - Enable/disable auto-scroll

**Message Levels**:
- **Info** (ℹ): General information
- **Success** (✓): Operation completed successfully
- **Warning** (⚠): Important notices
- **Error** (✗): Errors and failures

**App Methods Called** (optional):
- `handleConsoleCommand(input)` - Handle command line input

---

### bct.ui.PlotPanel

**Purpose**: Interactive canvas for 3D meshes, signals, and plots.

**Key Methods**:
- `plotMesh(vertices, faces, ...)` - Display 3D mesh
- `plotSignal(vertices, faces, signal, ...)` - Display signal on mesh
- `plotSpectrum(frequencies, values, ...)` - Display spectrum
- `clear()` - Clear plot
- `resetView()` - Reset camera
- `setInteractionMode(mode)` - Set mode ('rotate', 'pan', 'zoom', 'select')
- `exportImage(filename)` - Export as image
- `setViewOptions(options)` - Set view configuration

**View Options**:
```matlab
options = struct(...
    'colormap', 'parula', ...
    'lighting', true, ...
    'showAxes', false, ...
    'background', [1 1 1]);
```

**App Methods Called** (optional):
- `onPlotViewChanged(data)` - View/camera changed
- `onMeshClicked(vertexId, position)` - Mesh vertex clicked

---

## 🎨 Design System

The component system includes a comprehensive design system with:

### CSS Variables
- **Colors**: Primary, secondary, status (success, warning, error, info)
- **Spacing**: xs (4px), sm (8px), md (16px), lg (24px), xl (32px)
- **Typography**: Font families, sizes, weights
- **Borders**: Radii, widths
- **Shadows**: Small, medium, large
- **Transitions**: Fast (150ms), normal (250ms), slow (350ms)

### Utility Classes
- Layout: `.bct-flex`, `.bct-flex-column`, `.bct-flex-center`
- Spacing: `.bct-mt-md`, `.bct-p-sm`, etc.
- Display: `.bct-hidden`, `.bct-visible`

### Common Components
- Buttons: `.bct-btn`, `.bct-btn-primary`, `.bct-btn-icon`
- Inputs: `.bct-input`, `.bct-select`
- Cards: `.bct-card`, `.bct-card-header`, `.bct-card-body`
- Notifications: Automatic toast notifications via `BCT.notify()`

---

## 🔧 JavaScript Utilities

The `bct-common.js` file provides shared utilities:

### Communication
```javascript
BCT.sendToMatlab(componentId, cmd, data)
BCT.onMatlabMessage(callback)
```

### State Management
```javascript
const state = new BCT.StateManager(initialState);
state.get(key)
state.set(key, value)
state.subscribe(listener)
```

### DOM Utilities
```javascript
BCT.createElement(tag, options)
BCT.notify(message, type, duration)
BCT.loadCSS(href)
BCT.loadScript(src)
```

### Helpers
```javascript
BCT.debounce(func, wait)
BCT.throttle(func, limit)
BCT.formatNumber(value, precision)
BCT.formatTime(timestamp)
```

---

## 💡 Best Practices

### 1. Component Initialization
- Always initialize components in `startupFcn`
- Store component instances as app properties
- Initialize in logical order (Toolstrip → Sidebar → Console → PlotPanel)

### 2. Error Handling
- Use try-catch blocks for operations that might fail
- Log errors to Console
- Disable UI elements during long operations
- Re-enable elements after completion or error

### 3. User Feedback
- Log operation start/completion to Console
- Use appropriate message levels (log, warn, error, success)
- Disable buttons during processing to prevent double-clicks
- Show loading states in PlotPanel for long renders

### 4. State Management
- Keep component state synchronized between MATLAB and JavaScript
- Use `setState()` methods to update component state
- Subscribe to state changes in JavaScript when needed

### 5. Performance
- Limit console messages (default 1000)
- Debounce rapid property changes
- Use throttling for continuous updates (e.g., mouse movement)
- Render large datasets asynchronously

---

## 🔌 Extending the System

### Creating Custom Components

```matlab
classdef MyComponent < bct.ui.Component
    methods
        function obj = MyComponent(app, htmlComponent)
            obj@bct.ui.Component(app, htmlComponent, "MyComponent");
            obj.loadHTML("mycomponent.html");
            obj.sendConfiguration();
        end
        
        function onMessage(obj, data)
            switch data.cmd
                case "myAction"
                    obj.handleMyAction(data);
            end
        end
    end
    
    methods (Access = private)
        function sendConfiguration(obj)
            config = struct('option1', value1);
            obj.send(struct('cmd', 'configure', 'config', config));
        end
        
        function handleMyAction(obj, data)
            % Process action
            if ismethod(obj.App, 'onMyAction')
                obj.App.onMyAction(data);
            end
        end
    end
end
```

### Adding HTML/CSS/JS Files

1. Create `mycomponent.html` in `+ui/html/`
2. Create `mycomponent.js` in `+ui/js/`
3. Create `mycomponent.css` in `+ui/css/`
4. Follow the patterns in existing components

---

## 📚 Example Application

See `examples/demo_ui_components.m` for a complete example application using all components.

---

## 🐛 Troubleshooting

### Component not displaying
- Check that HTML file path is correct
- Verify HTML UI Component is properly sized in App Designer
- Check browser console for JavaScript errors

### Messages not passing between MATLAB and JS
- Ensure `DataChangedFcn` is set up in Component base class
- Check that component IDs match
- Verify message format includes `id` field

### Performance issues
- Reduce max console messages
- Use debouncing/throttling for frequent updates
- Render complex visualizations asynchronously

---

## 📄 License

This component system is part of the BCT (Bioctree) toolbox.

---

## 👥 Contributing

To add new components:
1. Extend `bct.ui.Component`
2. Create HTML/CSS/JS files following naming conventions
3. Document all public methods and properties
4. Add examples to the demo application

---

## 📞 Support

For issues or questions, refer to the main BCT documentation or open an issue in the repository.
