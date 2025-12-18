function demo_toolstrip()
    %DEMO_TOOLSTRIP Quick test of TailwindToolstrip component
    %
    %   Creates a simple figure with the Toolstrip component to verify
    %   it loads and displays correctly.
    
    % Add portable UI to path
    addpath('matlab');
    
    % Create figure with HTML component
    fig = uifigure('Name', 'Toolstrip Demo', 'Position', [100 100 1000 150]);
    
    % Create HTML UI component for toolstrip
    htmlToolstrip = uihtml(fig);
    htmlToolstrip.Position = [10 10 980 130];
    
    % Create mock app structure
    app = struct();
    app.fig = fig;
    
    % Create TailwindToolstrip wrapper
    toolstrip = TailwindToolstrip(app, htmlToolstrip);
    
    % Wait for HTML to load
    pause(0.5);
    
    % Add some button groups to test
    toolstrip.addGroup(struct(...
        'id', 'file', ...
        'label', 'File', ...
        'buttons', {{
            struct('id', 'open', 'label', 'Open', 'icon', 'folder-open')
            struct('id', 'save', 'label', 'Save', 'icon', 'save')
            struct('id', 'export', 'label', 'Export', 'icon', 'download')
        }}));
    
    toolstrip.addGroup(struct(...
        'id', 'edit', ...
        'label', 'Edit', ...
        'buttons', {{
            struct('id', 'undo', 'label', 'Undo', 'icon', 'undo')
            struct('id', 'redo', 'label', 'Redo', 'icon', 'redo')
            struct('id', 'copy', 'label', 'Copy', 'icon', 'copy')
        }}));
    
    toolstrip.addGroup(struct(...
        'id', 'view', ...
        'label', 'View', ...
        'buttons', {{
            struct('id', 'zoomIn', 'label', 'Zoom In', 'icon', 'zoom-in')
            struct('id', 'zoomOut', 'label', 'Zoom Out', 'icon', 'zoom-out')
            struct('id', 'resetView', 'label', 'Reset', 'icon', 'refresh')
        }}));
    
    % Store in figure for access
    fig.UserData = struct('toolstrip', toolstrip);
    
    fprintf('\n✅ Toolstrip Demo Loaded!\n\n');
    fprintf('The toolstrip should now be visible with three button groups:\n');
    fprintf('  - File: Open, Save, Export\n');
    fprintf('  - Edit: Undo, Redo, Copy\n');
    fprintf('  - View: Zoom In, Zoom Out, Reset\n\n');
    fprintf('Try clicking buttons to test interactivity.\n');
    fprintf('(Note: Callbacks will show warnings since app methods don''t exist)\n\n');
end
