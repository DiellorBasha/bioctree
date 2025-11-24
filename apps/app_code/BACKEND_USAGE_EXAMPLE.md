# BctAppBackend Usage Guide

## Architecture Overview

**Frontend** (`BctFilterDesigner.mlapp`):
- UI components only
- Event handlers (callbacks)
- Delegates all logic to backend

**Backend** (`BctAppBackend.m`):
- All custom business logic
- Reusable static methods
- Testable and git-friendly
- Editable in VS Code

## How to Update App Callbacks

### Before (Inside .mlapp)
```matlab
% Inside BctFilterDesigner.mlapp
function ScanButtonPushed(app, event)
    % Clear all existing children under DataNode
    delete(app.DataNode.Children);
    
    % Get all variables from base workspace
    vars = evalin('base', 'whos');
    
    % ... 50 more lines of logic ...
end
```

### After (Using Backend)
```matlab
% Inside BctFilterDesigner.mlapp
function ScanButtonPushed(app, event)
    BctAppBackend.scanWorkspace(app);
end
```

## Example Callback Updates

### 1. Scan Workspace
```matlab
% Button pushed function: ScanButton
function ScanButtonPushed(app, event)
    BctAppBackend.scanWorkspace(app);
end
```

### 2. Load BCT Object
```matlab
% Button pushed function: LoadButton
function LoadButtonPushed(app, event)
    node = app.Tree.SelectedNodes;
    
    if isempty(node)
        uialert(app.UIFigure, 'Please select a BCT object.', 'No Selection');
        return;
    end
    
    varName = node.NodeData;
    
    if isempty(varName) || ~isfield(app.BCTObjects, varName)
        uialert(app.UIFigure, 'Selected node is invalid.', 'Invalid Selection');
        return;
    end
    
    % Load object
    app.CurrentBCT = app.BCTObjects.(varName);
    
    % Initialize FilterDesigner
    app.FilterDesigner = bct.filters.FilterDesigner(app.CurrentBCT);
    
    % Create default filter - delegated to backend
    BctAppBackend.createDefaultFilter(app);
    
    % Update UI - delegated to backend
    BctAppBackend.updateUIAfterLoad(app);
    
    uialert(app.UIFigure, sprintf('Loaded BCT object: %s', varName), 'Success');
end
```

### 3. Show Mesh
```matlab
% Button pushed function: ShowMeshButton
function ShowMeshButtonPushed(app, event)
    BctAppBackend.attachViewer(app, app.CurrentBCT);
end
```

### 4. Synthesize Filter
```matlab
% Button pushed function: SynthesizeButton
function SynthesizeButtonPushed(app, event)
    B = app.CurrentBCT;
    
    % Validation (UI-specific logic stays in frontend)
    if isempty(app.CurrentFilter)
        uialert(app.UIFigure, 'No filter created. Load BCT object first.', 'No Filter');
        return;
    end
    
    if isempty(B.Lambda) || isempty(B.Lambda.lambda)
        uialert(app.UIFigure, 'Compute eigenbasis first (Eigenbasis button)', 'Eigenbasis Not Computed');
        return;
    end
    
    if isempty(B.Omega)
        uialert(app.UIFigure, 'Assign Time domain to BCT first', 'No Omega Domain');
        return;
    end
    
    % Ensure Joint domain exists
    if isempty(B.Joint)
        B = B.createJoint('Lambda', 'Omega');
        app.CurrentBCT = B;
    end
    
    % Evaluate filter
    try
        F = app.CurrentFilter.evaluate();
    catch ME
        uialert(app.UIFigure, sprintf('Filter evaluation failed: %s', ME.message), 'Error');
        return;
    end
    
    % Get grids for visualization
    LambdaGrid = B.Joint.A_grid;
    OmegaGrid = B.Joint.B_grid;
    freq_grid = OmegaGrid / (2*pi);
    
    % Visualize - delegated to backend
    BctAppBackend.visualizeJointFilter(app, freq_grid, LambdaGrid, F);
end
```

### 5. Update Kernel Preview on Slider Change
```matlab
% Value changed function: k0Slider
function k0SliderValueChanged(app, event)
    if ~isempty(app.CurrentFilter)
        app.CurrentFilter.setParameter('center_x', app.k0Slider.Value);
    end
    BctAppBackend.updateKernelPreview(app);
end

% Value changed function: sigma_kSlider
function sigma_kSliderValueChanged(app, event)
    if ~isempty(app.CurrentFilter)
        app.CurrentFilter.setParameter('sigma_x', app.sigma_kSlider.Value);
    end
    BctAppBackend.updateKernelPreview(app);
end

% Value changed function: omegaSlider
function omegaSliderValueChanged(app, event)
    if ~isempty(app.CurrentFilter)
        app.CurrentFilter.setParameter('center_y', app.omegaSlider.Value);
    end
    BctAppBackend.updateKernelPreview(app);
end

% Value changed function: sigma_oSlider
function sigma_oSliderValueChanged(app, event)
    if ~isempty(app.CurrentFilter)
        app.CurrentFilter.setParameter('sigma_y', app.sigma_oSlider.Value);
    end
    BctAppBackend.updateKernelPreview(app);
end
```

## Benefits

### ✅ Clean Separation
- `.mlapp` file: **Small** - only UI and routing
- `.m` file: **All logic** - editable, testable, reusable

### ✅ Git-Friendly
- Backend changes tracked cleanly in `.m` files
- No binary `.mlapp` conflicts
- Easy code review

### ✅ Testable
```matlab
% Can write unit tests for backend functions
function testScanWorkspace()
    % Mock app structure
    mockApp = struct();
    mockApp.DataNode = uitreenode();
    
    % Test backend function
    BctAppBackend.scanWorkspace(mockApp);
    
    % Assertions...
end
```

### ✅ Reusable
- Backend functions can be used by other apps
- Command-line usage possible
- Share logic across multiple UIs

### ✅ Editable in VS Code
- Full IntelliSense support
- Easy navigation
- Better refactoring tools
- No App Designer required for logic changes

## Migration Checklist

- [x] Create `BctAppBackend.m` with all custom functions
- [ ] Update `.mlapp` callbacks to use `BctAppBackend.method(app)`
- [ ] Test each callback after migration
- [ ] Remove old custom functions from `.mlapp` private methods section
- [ ] Add unit tests for backend functions (optional)

## Next Steps

1. Open `BctFilterDesigner.mlapp` in App Designer
2. Replace each callback body with `BctAppBackend.method(app)` calls
3. Delete the old private methods section (all functions now in backend)
4. Test thoroughly
5. Enjoy clean, maintainable code! 🎉
