# Using Tailwind Components in MATLAB App Designer

Complete step-by-step guide for integrating BCT Tailwind UI components into your MATLAB App Designer applications.

## ⚠️ NEW: Portable UI Structure

The Tailwind UI system is now **portable** and located in `/ui` (not in the `+bct` package).

**Benefits:**
- No package dependencies
- Can be used in any MATLAB project
- Simpler path management
- Easier to share and reuse

## Quick Start

### 1. Add UI Path

Add the portable UI wrapper classes to your path:

```matlab
% In your startup script or app startupFcn
addpath('ui/matlab');  % Relative to project root
```

### 2. Add HTML UI Component in App Designer

1. Open App Designer
2. From the **Component Library**, drag **HTML UI Component** onto your canvas
3. Resize it to fill the desired area
4. Note its property name (e.g., `HTMLComponent`, `HTMLToolstrip`, `HTMLSidebar`)

### 3. Initialize Components in App Startup

In your App Designer's `startupFcn`:

```matlab
function startupFcn(app)
    % Add ui/matlab to path (if not already done globally)
    addpath('ui/matlab');
    
    % Create Tailwind component wrappers (NO package namespace)
    app.Toolstrip = TailwindToolstrip(app, app.HTMLToolstrip);
    app.Sidebar = TailwindSidebar(app, app.HTMLSidebar);
    app.PlotPanel = TailwindPlotPanel(app, app.HTMLPlotPanel);
    % Create wrapper for Tailwind component
    app.Toolstrip = bct.ui.TailwindToolstrip(app, app.HTMLToolstrip);
    
    % Configure component
    app.Toolstrip.addGroup(struct(...
        'id', 'file', ...
        'label', 'File', ...
        'buttons', {{
            struct('id', 'load', 'label', 'Load', 'icon', 'folder-open', 'cmd', 'loadData')
            struct('id', 'save', 'label', 'Save', 'icon', 'save', 'cmd', 'saveData')
        }}...
    ));
end
```

---

## Complete Integration Examples

### Example 1: Toolstrip with File Operations

#### Step 1: App Designer Setup

Add HTML UI Component named `HTMLToolstrip` to your app.

#### Step 2: Create Wrapper (`+bct/+ui/TailwindToolstrip.m`)

```matlab
classdef TailwindToolstrip < bct.ui.Component
    properties (Access = private)
        ButtonGroups = {}
    end
    
    methods
        function obj = TailwindToolstrip(app, htmlControl)
            obj@bct.ui.Component(app, htmlControl);
            obj.HTMLPath = fullfile(fileparts(mfilename('fullpath')), ...
                'tailwind', 'components', 'toolstrip.html');
            obj.loadHTML();
        end
        
        function addGroup(obj, groupConfig)
            obj.ButtonGroups{end+1} = groupConfig;
            obj.send(struct('cmd', 'addGroup', 'group', groupConfig));
        end
        
        function setButtonEnabled(obj, buttonId, enabled)
            obj.send(struct('cmd', 'setButtonEnabled', ...
                'buttonId', buttonId, 'enabled', enabled));
        end
        
        function onMessage(obj, data)
            % Route button clicks to app methods
            if strcmp(data.cmd, 'buttonClick')
                methodName = data.button.cmd;
                if ismethod(obj.App, methodName)
                    obj.App.(methodName)();
                end
            end
        end
    end
end
```

#### Step 3: Use in App Designer

```matlab
properties (Access = public)
    Toolstrip  % bct.ui.TailwindToolstrip
    CurrentBCT % bct.bct object
end

methods (Access = private)
    function startupFcn(app)
        % Initialize Toolstrip
        app.Toolstrip = bct.ui.TailwindToolstrip(app, app.HTMLToolstrip);
        
        % Add button groups
        app.Toolstrip.addGroup(struct(...
            'id', 'data', ...
            'label', 'Data', ...
            'buttons', {{
                struct('id', 'load', 'label', 'Load Mesh', ...
                       'icon', 'cube', 'cmd', 'loadMesh')
                struct('id', 'compute', 'label', 'Compute', ...
                       'icon', 'calculator', 'cmd', 'computeEigenbasis')
            }}...
        ));
    end
    
    % Button callback methods
    function loadMesh(app)
        [file, path] = uigetfile('*.mat', 'Select Mesh');
        if file ~= 0
            data = load(fullfile(path, file));
            app.CurrentBCT = bct.bct.fromMesh(data.V, data.F);
            disp('Mesh loaded');
        end
    end
    
    function computeEigenbasis(app)
        if ~isempty(app.CurrentBCT)
            app.Toolstrip.setButtonEnabled('compute', false);
            app.CurrentBCT = app.CurrentBCT.computeEigenbasis(500);
            app.Toolstrip.setButtonEnabled('compute', true);
            disp('Eigenbasis computed');
        end
    end
end
```

---

### Example 2: Sidebar with Interactive Controls

#### Step 1: Create Sidebar Wrapper

```matlab
classdef TailwindSidebar < bct.ui.Component
    properties (Access = private)
        Sections = struct()
    end
    
    methods
        function obj = TailwindSidebar(app, htmlControl)
            obj@bct.ui.Component(app, htmlControl);
            obj.HTMLPath = fullfile(fileparts(mfilename('fullpath')), ...
                'tailwind', 'components', 'sidebar.html');
            obj.loadHTML();
        end
        
        function addSection(obj, sectionConfig)
            obj.Sections.(sectionConfig.id) = sectionConfig;
            obj.send(struct('cmd', 'addSection', 'section', sectionConfig));
        end
        
        function updateControl(obj, sectionId, controlId, value)
            obj.send(struct('cmd', 'updateControl', ...
                'sectionId', sectionId, 'controlId', controlId, 'value', value));
        end
        
        function onMessage(obj, data)
            % Handle control value changes from JavaScript
            if strcmp(data.cmd, 'controlChange')
                % Call app method: <controlId>Changed(value)
                methodName = sprintf('%sChanged', data.controlId);
                if ismethod(obj.App, methodName)
                    obj.App.(methodName)(data.value);
                end
            end
        end
    end
end
```

#### Step 2: Use in App Designer

```matlab
properties (Access = public)
    Sidebar           % bct.ui.TailwindSidebar
    FilterDesigner    % bct.filters.FilterDesigner
    CurrentFilter     % bct.filters.Filter
end

methods (Access = private)
    function startupFcn(app)
        % Initialize Sidebar
        app.Sidebar = bct.ui.TailwindSidebar(app, app.HTMLSidebar);
        
        % Add filter parameters section
        app.Sidebar.addSection(struct(...
            'id', 'filter', ...
            'title', 'Filter Parameters', ...
            'collapsed', false, ...
            'controls', {{
                struct('id', 'center', 'type', 'slider', ...
                       'label', 'Center', 'min', 0, 'max', 100, 'value', 50)
                struct('id', 'sigma', 'type', 'slider', ...
                       'label', 'Bandwidth', 'min', 1, 'max', 20, 'value', 10)
                struct('id', 'kernelType', 'type', 'dropdown', ...
                       'label', 'Kernel Type', ...
                       'options', {{'gaussian', 'heat', 'bandpass'}}, ...
                       'value', 'gaussian')
            }}...
        ));
        
        % Initialize filter
        app.FilterDesigner = bct.filters.FilterDesigner(app.CurrentBCT);
        app.CurrentFilter = app.FilterDesigner.spatial('gaussian', ...
            'center', 50, 'sigma', 10);
    end
    
    % Control change callbacks
    function centerChanged(app, value)
        if ~isempty(app.CurrentFilter)
            app.CurrentFilter.center = value;
            app.updatePlot();
        end
    end
    
    function sigmaChanged(app, value)
        if ~isempty(app.CurrentFilter)
            app.CurrentFilter.sigma = value;
            app.updatePlot();
        end
    end
    
    function kernelTypeChanged(app, value)
        if ~isempty(app.CurrentFilter)
            center = app.CurrentFilter.center;
            sigma = app.CurrentFilter.sigma;
            app.CurrentFilter = app.FilterDesigner.spatial(value, ...
                'center', center, 'sigma', sigma);
            app.updatePlot();
        end
    end
end
```

---

### Example 3: Console for Logging

#### Step 1: Create Console Wrapper

```matlab
classdef TailwindConsole < bct.ui.Component
    methods
        function obj = TailwindConsole(app, htmlControl)
            obj@bct.ui.Component(app, htmlControl);
            obj.HTMLPath = fullfile(fileparts(mfilename('fullpath')), ...
                'tailwind', 'components', 'console.html');
            obj.loadHTML();
        end
        
        function log(obj, message)
            obj.send(struct('cmd', 'log', 'message', message, 'level', 'log'));
        end
        
        function info(obj, message)
            obj.send(struct('cmd', 'log', 'message', message, 'level', 'info'));
        end
        
        function success(obj, message)
            obj.send(struct('cmd', 'log', 'message', message, 'level', 'success'));
        end
        
        function warn(obj, message)
            obj.send(struct('cmd', 'log', 'message', message, 'level', 'warning'));
        end
        
        function error(obj, message)
            obj.send(struct('cmd', 'log', 'message', message, 'level', 'error'));
        end
        
        function clear(obj)
            obj.send(struct('cmd', 'clear'));
        end
        
        function onMessage(obj, data)
            % Handle command input from console
            if strcmp(data.cmd, 'command')
                try
                    result = evalin('base', data.command);
                    if ~isempty(result)
                        obj.log(evalc('disp(result)'));
                    end
                catch ME
                    obj.error(ME.message);
                end
            end
        end
    end
end
```

#### Step 2: Use in App Designer

```matlab
properties (Access = public)
    Console  % bct.ui.TailwindConsole
end

methods (Access = private)
    function startupFcn(app)
        % Initialize Console
        app.Console = bct.ui.TailwindConsole(app, app.HTMLConsole);
        
        % Log startup
        app.Console.info('BCT App starting...');
        
        % Run initialization
        try
            bioctree_start;
            app.Console.success('BCT initialized successfully');
        catch ME
            app.Console.error(['Initialization failed: ' ME.message]);
        end
    end
    
    function loadMesh(app)
        app.Console.info('Loading mesh...');
        try
            data = load('data/mesh/fsaverage_rh_pial.mat');
            app.CurrentBCT = bct.bct.fromMesh(data.V, data.F);
            app.Console.success(sprintf('Mesh loaded: %d vertices', size(data.V, 1)));
        catch ME
            app.Console.error(['Load failed: ' ME.message]);
        end
    end
end
```

---

### Example 4: PlotPanel for Visualization

#### Step 1: Create PlotPanel Wrapper

```matlab
classdef TailwindPlotPanel < bct.ui.Component
    methods
        function obj = TailwindPlotPanel(app, htmlControl)
            obj@bct.ui.Component(app, htmlControl);
            obj.HTMLPath = fullfile(fileparts(mfilename('fullpath')), ...
                'tailwind', 'components', 'plotpanel.html');
            obj.loadHTML();
        end
        
        function plotMesh(obj, vertices, faces)
            obj.send(struct('cmd', 'plotMesh', ...
                'vertices', vertices, 'faces', faces));
        end
        
        function plotSignal(obj, data)
            obj.send(struct('cmd', 'plotSignal', 'data', data));
        end
        
        function clear(obj)
            obj.send(struct('cmd', 'clear'));
        end
        
        function setMode(obj, mode)
            % mode: 'rotate', 'pan', 'zoom', 'select'
            obj.send(struct('cmd', 'setMode', 'mode', mode));
        end
        
        function onMessage(obj, data)
            % Handle interactions from JavaScript
            switch data.cmd
                case 'vertexSelected'
                    if ismethod(obj.App, 'onVertexSelected')
                        obj.App.onVertexSelected(data.vertexIndex);
                    end
            end
        end
    end
end
```

---

## Complete App Example

Here's a complete MATLAB App Designer application using multiple Tailwind components:

```matlab
classdef BctTailwindApp < matlab.apps.AppBase
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        GridLayout          matlab.ui.container.GridLayout
        HTMLToolstrip       matlab.ui.control.HTML
        HTMLSidebar         matlab.ui.control.HTML
        HTMLPlotPanel       matlab.ui.control.HTML
        HTMLConsole         matlab.ui.control.HTML
        
        % BCT Components
        Toolstrip           bct.ui.TailwindToolstrip
        Sidebar             bct.ui.TailwindSidebar
        PlotPanel           bct.ui.TailwindPlotPanel
        Console             bct.ui.TailwindConsole
        
        % BCT Objects
        CurrentBCT          bct.bct
        FilterDesigner      bct.filters.FilterDesigner
        CurrentFilter       bct.filters.Filter
    end
    
    methods (Access = private)
        function startupFcn(app)
            % Initialize all components
            app.Toolstrip = bct.ui.TailwindToolstrip(app, app.HTMLToolstrip);
            app.Sidebar = bct.ui.TailwindSidebar(app, app.HTMLSidebar);
            app.PlotPanel = bct.ui.TailwindPlotPanel(app, app.HTMLPlotPanel);
            app.Console = bct.ui.TailwindConsole(app, app.HTMLConsole);
            
            % Configure Toolstrip
            app.Toolstrip.addGroup(struct(...
                'id', 'data', 'label', 'Data', ...
                'buttons', {{
                    struct('id', 'load', 'label', 'Load', 'icon', 'folder-open', 'cmd', 'loadMesh')
                    struct('id', 'compute', 'label', 'Compute', 'icon', 'calculator', 'cmd', 'computeEigenbasis')
                }}...
            ));
            
            % Configure Sidebar
            app.Sidebar.addSection(struct(...
                'id', 'filter', 'title', 'Filter', 'collapsed', false, ...
                'controls', {{
                    struct('id', 'center', 'type', 'slider', 'label', 'Center', ...
                           'min', 0, 'max', 100, 'value', 50)
                    struct('id', 'sigma', 'type', 'slider', 'label', 'Sigma', ...
                           'min', 1, 'max', 20, 'value', 10)
                }}...
            ));
            
            % Log startup
            app.Console.info('BCT Tailwind App started');
        end
        
        % Toolstrip callbacks
        function loadMesh(app)
            app.Console.info('Loading mesh...');
            data = load('data/mesh/fsaverage_rh_pial.mat');
            app.CurrentBCT = bct.bct.fromMesh(data.V, data.F);
            app.PlotPanel.plotMesh(data.V, data.F);
            app.Console.success('Mesh loaded');
        end
        
        function computeEigenbasis(app)
            if ~isempty(app.CurrentBCT)
                app.Console.info('Computing eigenbasis...');
                app.CurrentBCT = app.CurrentBCT.computeEigenbasis(500);
                app.FilterDesigner = bct.filters.FilterDesigner(app.CurrentBCT);
                app.Console.success('Eigenbasis computed');
            end
        end
        
        % Sidebar callbacks
        function centerChanged(app, value)
            if ~isempty(app.CurrentFilter)
                app.CurrentFilter.center = value;
                app.updateVisualization();
            end
        end
        
        function sigmaChanged(app, value)
            if ~isempty(app.CurrentFilter)
                app.CurrentFilter.sigma = value;
                app.updateVisualization();
            end
        end
        
        function updateVisualization(app)
            % Update plot based on current filter
            H = app.CurrentFilter.evaluate();
            app.PlotPanel.plotSignal(abs(H));
        end
    end
end
```

---

## Tips and Best Practices

### 1. Component Lifecycle

```matlab
function startupFcn(app)
    % ALWAYS initialize components in this order:
    % 1. Create wrapper instances
    app.Toolstrip = bct.ui.TailwindToolstrip(app, app.HTMLToolstrip);
    
    % 2. Configure components
    app.Toolstrip.addGroup(...);
    
    % 3. Initialize BCT objects
    app.CurrentBCT = bct.bct.fromMesh(V, F);
end
```

### 2. State Synchronization

Keep MATLAB state in sync with UI:

```matlab
function centerChanged(app, value)
    % Update MATLAB object
    app.CurrentFilter.center = value;
    
    % Update other UI components
    app.Sidebar.updateControl('filter', 'center', value);
    
    % Refresh visualization
    app.updatePlot();
end
```

### 3. Error Handling

Always wrap callbacks in try-catch:

```matlab
function loadMesh(app)
    try
        app.Console.info('Loading mesh...');
        data = load('mesh.mat');
        app.CurrentBCT = bct.bct.fromMesh(data.V, data.F);
        app.Console.success('Mesh loaded');
    catch ME
        app.Console.error(['Load failed: ' ME.message]);
    end
end
```

### 4. Performance

For intensive operations, use background workers:

```matlab
function computeEigenbasis(app)
    app.Toolstrip.setButtonEnabled('compute', false);
    app.Console.info('Computing eigenbasis...');
    
    % Run in background
    afterEach(parfeval(@computeHelper, 1, app.CurrentBCT), ...
        @(B) app.onComputeComplete(B));
end

function onComputeComplete(app, B)
    app.CurrentBCT = B;
    app.Toolstrip.setButtonEnabled('compute', true);
    app.Console.success('Eigenbasis computed');
end

function B = computeHelper(B)
    B = B.computeEigenbasis(500);
end
```

---

## Troubleshooting

### HTML Not Loading

**Problem**: Component appears blank

**Solution**:
```matlab
% Verify path
disp(obj.HTMLPath);  % Should point to .html file

% Check if file exists
if ~isfile(obj.HTMLPath)
    error('HTML file not found: %s', obj.HTMLPath);
end
```

### Communication Not Working

**Problem**: Button clicks don't trigger MATLAB callbacks

**Solution**: Check `onMessage` routing:
```matlab
function onMessage(obj, data)
    fprintf('Received: %s\n', jsonencode(data));  % Debug
    
    % Verify cmd field exists
    if ~isfield(data, 'cmd')
        warning('Message missing cmd field');
        return;
    end
    
    % Route to handler
    switch data.cmd
        case 'buttonClick'
            obj.handleButtonClick(data);
        otherwise
            warning('Unknown command: %s', data.cmd);
    end
end
```

### CSS Not Applied

**Problem**: Component looks unstyled

**Solution**: Verify CSS is loaded in HTML:
```html
<link rel="stylesheet" href="../dist/bct-ui.css">
```

---

## Next Steps

1. **Build the CSS**: `cd tailwind && npm run build`
2. **Preview components**: Open `components/*.html` in browser
3. **Create wrapper classes**: Extend `bct.ui.Component`
4. **Add to App Designer**: Drag HTML UI Components
5. **Initialize in startupFcn**: Create wrapper instances
6. **Test communication**: Add logging to debug messages

See also:
- `QUICKSTART.md` - 5-minute setup guide
- `TAILWIND_GUIDE.md` - Complete component reference
- `MATLAB_INTEGRATION_EXAMPLE.m` - Code examples
- `ELEMENT_REFERENCE.md` - UI element catalog
