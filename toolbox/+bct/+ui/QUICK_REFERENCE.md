# BCT UI Components - Quick Reference

## Component Initialization

```matlab
% In App Designer startupFcn:
app.Toolstrip = bct.ui.Toolstrip(app, app.HTMLToolstrip);
app.Sidebar = bct.ui.Sidebar(app, app.HTMLSidebar);
app.Console = bct.ui.Console(app, app.HTMLConsole);
app.PlotPanel = bct.ui.PlotPanel(app, app.HTMLPlot);
```

## Toolstrip

### Add Custom Button
```matlab
app.Toolstrip.addButton('myBtn', 'My Action', '🎯', 'custom');
```

### Control Button State
```matlab
app.Toolstrip.enableButton('myBtn');
app.Toolstrip.disableButton('myBtn');
app.Toolstrip.setButtonState('myBtn', true);  % Toggle active
```

### App Methods Called
```matlab
function loadMesh(app)
function loadSignal(app)
function saveData(app)
function computeEigenbasis(app)
function performTransform(app)
function openFilterDesigner(app)
function plot3D(app)
function plotSpectrum(app)
function animateSignal(app)
function handleCustomButton(app, buttonId)
```

## Sidebar

### Add Section
```matlab
section = struct(...
    'id', 'mySection', ...
    'title', 'My Section', ...
    'content', struct('Property1', value1, 'Property2', value2));
app.Sidebar.addSection(section);
```

### Update Section
```matlab
app.Sidebar.updateSection('mySection', newContent);
```

### Control Visibility
```matlab
app.Sidebar.collapse();
app.Sidebar.expand();
app.Sidebar.toggle();
```

### App Methods Called
```matlab
function onSidebarSectionToggle(app, sectionId, collapsed)
function onSidebarPropertyChange(app, sectionId, property, value)
```

## Console

### Log Messages
```matlab
app.Console.log('Information message');
app.Console.warn('Warning message');
app.Console.error('Error message');
app.Console.success('Success message');
```

### Formatted Messages
```matlab
app.Console.log('Loaded %d vertices', count);
app.Console.warn('Value %.2f exceeds threshold', value);
```

### Control Console
```matlab
app.Console.clear();
app.Console.setFilter(2);  % 0=all, 1=info+, 2=warn+, 3=error
app.Console.setMaxMessages(500);
app.Console.setAutoScroll(true);
app.Console.exportLog('log.txt');
```

### App Methods Called
```matlab
function handleConsoleCommand(app, input)
```

## PlotPanel

### Plot Mesh
```matlab
app.PlotPanel.plotMesh(vertices, faces);
app.PlotPanel.plotMesh(vertices, faces, ...
    'FaceColor', [0.8 0.8 0.8], ...
    'FaceAlpha', 1.0);
```

### Plot Signal
```matlab
app.PlotPanel.plotSignal(vertices, faces, signal);
app.PlotPanel.plotSignal(vertices, faces, signal, ...
    'Colormap', 'parula', ...
    'CLim', [min(signal), max(signal)]);
```

### Plot Spectrum
```matlab
app.PlotPanel.plotSpectrum(frequencies, values);
app.PlotPanel.plotSpectrum(frequencies, values, ...
    'LineColor', 'blue', ...
    'LineWidth', 2);
```

### Control View
```matlab
app.PlotPanel.clear();
app.PlotPanel.resetView();
app.PlotPanel.setInteractionMode('rotate');  % 'rotate', 'pan', 'zoom', 'select'
app.PlotPanel.exportImage('plot.png');
```

### Set Options
```matlab
options = struct(...
    'colormap', 'parula', ...
    'lighting', true, ...
    'background', [1 1 1]);
app.PlotPanel.setViewOptions(options);
```

### App Methods Called
```matlab
function onPlotViewChanged(app, data)
function onMeshClicked(app, vertexId, position)
```

## Common Component Methods

All components inherit these methods from `bct.ui.Component`:

```matlab
% Send custom message to JavaScript
obj.send(struct('cmd', 'myCommand', 'data', myData));

% Update component state
obj.setState(struct('property', value));

% Get current state
state = obj.getState();

% Enable/disable component
obj.enable();
obj.disable();
```

## JavaScript Utilities

### Communication
```javascript
// Send to MATLAB
BCT.sendToMatlab(componentId, 'command', {data: value});

// Listen for MATLAB messages
BCT.onMatlabMessage((data) => {
    if (data.id === componentId && data.cmd === 'myCommand') {
        // Handle message
    }
});
```

### State Management
```javascript
const state = new BCT.StateManager({prop: value});
state.get('prop');
state.set('prop', newValue);
state.subscribe((newState) => console.log(newState));
```

### DOM Utilities
```javascript
// Create element
const elem = BCT.createElement('div', {
    classes: ['my-class'],
    attrs: {'data-id': '123'},
    text: 'Hello'
});

// Show notification
BCT.notify('Message', 'success', 3000);
```

### Performance
```javascript
// Debounce
const debouncedFunc = BCT.debounce(myFunc, 500);

// Throttle
const throttledFunc = BCT.throttle(myFunc, 100);
```

## CSS Classes

### Buttons
```html
<button class="bct-btn">Default</button>
<button class="bct-btn bct-btn-primary">Primary</button>
<button class="bct-btn bct-btn-success">Success</button>
<button class="bct-btn bct-btn-icon">🎯</button>
```

### Inputs
```html
<input class="bct-input" type="text">
<select class="bct-select"></select>
```

### Cards
```html
<div class="bct-card">
    <div class="bct-card-header">Title</div>
    <div class="bct-card-body">Content</div>
</div>
```

### Layout
```html
<div class="bct-flex bct-flex-gap-md">
    <div>Item 1</div>
    <div>Item 2</div>
</div>
```

### Spacing
```html
<div class="bct-mt-md bct-p-sm">Content</div>
```

## CSS Variables

```css
/* Use in custom styles */
.my-component {
    background-color: var(--bct-bg-primary);
    padding: var(--bct-spacing-md);
    border-radius: var(--bct-border-radius-md);
    color: var(--bct-text-primary);
}
```

## Error Handling

### MATLAB
```matlab
try
    % Operation
    result = doSomething();
    app.Console.success('Operation complete');
catch ME
    app.Console.error('Failed: %s', ME.message);
end
```

### JavaScript
```javascript
try {
    // Operation
    const result = doSomething();
    BCT.notify('Success', 'success');
} catch (error) {
    console.error(error);
    BCT.notify(error.message, 'error');
}
```

## File Structure

```
+bct/+ui/
├── Component.m              # Base class
├── Toolstrip.m              # Toolbar
├── Sidebar.m                # Sidebar
├── Console.m                # Console
├── PlotPanel.m              # Plot
├── html/
│   ├── toolstrip.html
│   ├── sidebar.html
│   ├── console.html
│   └── plotpanel.html
├── js/
│   ├── bct-common.js       # Utilities
│   ├── toolstrip.js
│   ├── sidebar.js
│   ├── console.js
│   └── plotpanel.js
└── css/
    ├── bct-common.css      # Design system
    ├── toolstrip.css
    ├── sidebar.css
    ├── console.css
    └── plotpanel.css
```

## Common Patterns

### Load and Display Data
```matlab
function loadAndDisplay(app)
    app.Console.log('Loading data...');
    app.Toolstrip.disableButton('load');
    
    try
        data = loadData();
        app.PlotPanel.plotMesh(data.V, data.F);
        updateSidebar(app, data);
        app.Console.success('Loaded successfully');
    catch ME
        app.Console.error('Load failed: %s', ME.message);
    end
    
    app.Toolstrip.enableButton('load');
end
```

### Progress Updates
```matlab
function processData(app)
    N = 100;
    app.Console.log('Processing %d items...', N);
    
    for i = 1:N
        % Process item
        if mod(i, 10) == 0
            app.Console.log('Progress: %d%%', round(100*i/N));
        end
    end
    
    app.Console.success('Processing complete');
end
```

### User Confirmation
```matlab
function deleteData(app)
    answer = uiconfirm(app.UIFigure, ...
        'Delete all data?', 'Confirm', ...
        'Options', {'Delete', 'Cancel'}, ...
        'DefaultOption', 2);
    
    if strcmp(answer, 'Delete')
        % Delete
        app.Console.warn('Data deleted');
    end
end
```

## Keyboard Shortcuts

Implement in App Designer:

```matlab
function UIFigureKeyPress(app, event)
    switch event.Key
        case 's'
            if ismember('control', event.Modifier)
                saveData(app);
            end
        case 'r'
            app.PlotPanel.resetView();
        case 'l'
            app.Console.clear();
    end
end
```

## Tips & Tricks

1. **Always disable buttons during operations**
2. **Use Console for all user feedback**
3. **Log operation start and completion**
4. **Validate inputs before processing**
5. **Handle errors gracefully**
6. **Keep UI responsive**
7. **Batch related updates**
8. **Use meaningful button/section IDs**
9. **Document component usage**
10. **Test error paths**
