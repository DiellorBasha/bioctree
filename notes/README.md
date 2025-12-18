# BCT Portable UI System

Modern, portable UI components for MATLAB applications using Tailwind CSS.

## 🎯 Overview

This directory contains a **portable UI system** that can be used in **any MATLAB project**. It's not tied to the BCT package structure, making it easy to share and reuse.

### What's Inside

```
ui/
├── matlab/                      # MATLAB wrapper classes
│   ├── Component.m              # Abstract base class
│   ├── TailwindToolstrip.m      # Toolstrip component
│   ├── TailwindSidebar.m        # Sidebar component
│   └── TailwindPlotPanel.m      # Plot panel component
│
├── tailwind/                    # Tailwind UI framework
│   ├── components/              # HTML component files
│   ├── dist/                    # Compiled CSS/JS
│   ├── src/                     # Source files
│   └── node_modules/            # npm dependencies
│
├── test_portable_ui.m           # Test script
└── REFACTORING_SUMMARY.md       # Migration guide
```

## 🚀 Quick Start

### 1. Add to Path

```matlab
% Add ui/matlab to your MATLAB path
addpath('ui/matlab');
```

### 2. Use in App Designer

In your App Designer app's `startupFcn`:

```matlab
function startupFcn(app)
    % Add path (if not already done)
    addpath('ui/matlab');
    
    % Create component wrappers
    app.Toolstrip = TailwindToolstrip(app, app.HTMLToolstrip);
    app.Sidebar = TailwindSidebar(app, app.HTMLSidebar);
    app.PlotPanel = TailwindPlotPanel(app, app.HTMLPlotPanel);
    
    % Configure components
    app.Toolstrip.addGroup(struct(...
        'id', 'file', ...
        'label', 'File', ...
        'buttons', {{
            struct('id', 'open', 'label', 'Open', 'icon', 'folder-open')
            struct('id', 'save', 'label', 'Save', 'icon', 'save')
        }}));
    
    app.Sidebar.addSection(struct(...
        'id', 'settings', ...
        'title', 'Settings', ...
        'controls', {{
            struct('id', 'threshold', 'type', 'slider', ...
                   'label', 'Threshold', 'min', 0, 'max', 100, 'value', 50)
        }}));
end
```

### 3. Handle Callbacks

Component interactions automatically call methods in your app:

```matlab
% Button clicks call: <buttonId>ButtonPushed()
function openButtonPushed(app)
    [file, path] = uigetfile('*.mat');
    if file ~= 0
        % Load file...
    end
end

% Control changes call: <controlId>Changed(value)
function thresholdChanged(app, value)
    app.ThresholdValue = value;
    % Update visualization...
end
```

## 📚 Components

### TailwindToolstrip

Horizontal toolbar with button groups.

```matlab
app.Toolstrip = TailwindToolstrip(app, app.HTMLToolstrip);

% Add button groups
app.Toolstrip.addGroup(struct(...
    'id', 'view', ...
    'label', 'View', ...
    'buttons', {{
        struct('id', 'zoomIn', 'label', 'Zoom In', 'icon', 'zoom-in')
        struct('id', 'zoomOut', 'label', 'Zoom Out', 'icon', 'zoom-out')
        struct('id', 'resetView', 'label', 'Reset', 'icon', 'refresh')
    }}));

% Update buttons
app.Toolstrip.updateButton('view', 'zoomIn', struct('disabled', true));
```

### TailwindSidebar

Collapsible sidebar with sections and controls.

```matlab
app.Sidebar = TailwindSidebar(app, app.HTMLSidebar);

% Add sections with controls
app.Sidebar.addSection(struct(...
    'id', 'filter', ...
    'title', 'Filter Parameters', ...
    'collapsed', false, ...
    'controls', {{
        struct('id', 'center', 'type', 'slider', ...
               'label', 'Center', 'min', 0, 'max', 100, 'value', 50)
        struct('id', 'sigma', 'type', 'slider', ...
               'label', 'Bandwidth', 'min', 1, 'max', 20, 'value', 10)
        struct('id', 'enable', 'type', 'toggle', ...
               'label', 'Enable', 'value', true)
    }}));

% Update control values
app.Sidebar.updateControl('filter', 'center', 75);

% Get control values
value = app.Sidebar.getControlValue('center');
```

### TailwindPlotPanel

Interactive visualization panel.

```matlab
app.PlotPanel = TailwindPlotPanel(app, app.HTMLPlotPanel);

% Plot mesh
app.PlotPanel.plotMesh(vertices, faces, 'Signal', signalData);

% Plot signal
app.PlotPanel.plotSignal(data, 'XData', timePoints, ...
    'Title', 'Signal', 'XLabel', 'Time (s)', 'YLabel', 'Amplitude');

% Plot spectrum
app.PlotPanel.plotSpectrum(frequencies, magnitudes, 'LogScale', true);

% Set interaction mode
app.PlotPanel.setMode('rotate');  % 'rotate', 'pan', 'zoom', 'select'

% Reset view
app.PlotPanel.resetView();
```

## 🧪 Testing

Run the test script to verify everything works:

```matlab
cd ui
test_portable_ui
```

Expected output:
```
✅ All tests passed! Portable UI system is working.
```

## 📖 Documentation

- **[APP_DESIGNER_GUIDE.md](tailwind/APP_DESIGNER_GUIDE.md)** - Complete integration guide
- **[REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)** - Migration details

## 🎨 Customization

The Tailwind CSS can be customized by editing:

```
ui/tailwind/tailwind.config.js    # Tailwind configuration
ui/tailwind/src/input.css          # Custom styles
```

After making changes, rebuild:

```bash
cd ui/tailwind
npm run build
```

## 🔧 Troubleshooting

### Components not loading

1. Verify path is added: `addpath('ui/matlab')`
2. Check resources exist: `dir('ui/tailwind/dist')`
3. Run test: `test_portable_ui`

### CSS not applying

1. Verify CSS compiled: `ui/tailwind/dist/bct-ui.css` should exist
2. Rebuild if needed: `cd ui/tailwind && npm run build`

### Callbacks not firing

1. Check method names match: `<buttonId>ButtonPushed()`, `<controlId>Changed(value)`
2. Verify app has the methods defined
3. Check MATLAB Command Window for warnings

## 💡 Tips

1. **Path Management**: Add `addpath('ui/matlab')` to your project's startup script
2. **Component Reuse**: The entire `ui/` folder can be copied to other projects
3. **Demo Scripts**: See `ui/tailwind/demo_tailwind_sidebar.m` for examples
4. **Hot Reload**: Changes to JavaScript/CSS require app restart

## 📦 Portability

This UI system is **completely portable**:

- ✅ No package dependencies
- ✅ Self-contained (all resources in `/ui`)
- ✅ Works in any MATLAB project
- ✅ Easy to share and version control

To use in another project, just copy the `/ui` folder and add `ui/matlab` to the path!

## 🤝 Contributing

The UI system uses:
- **Tailwind CSS 3.4.0** for styling
- **MATLAB OOP** for component architecture
- **HTML UI Components** for rendering
- **JavaScript** for interactivity

To contribute:
1. Make changes to wrapper classes in `ui/matlab/`
2. Update HTML/CSS/JS in `ui/tailwind/`
3. Test with `test_portable_ui.m`
4. Update documentation

## 📄 License

Part of the BCT (bioctree) toolbox for MATLAB.
