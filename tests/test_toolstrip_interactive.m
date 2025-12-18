%% TailwindToolstrip Quick Test
% Run this script section by section in MATLAB to test the toolstrip
clear
%% Step 1: Setup - Add portable UI to path
addpath('ui/matlab');
fprintf('✓ Added ui/matlab to path\n');

%% Step 2: Create figure and HTML component
fig = uifigure('Name', 'Toolstrip Test', 'Position', [100 100 1000 150]);
htmlToolstrip = uihtml(fig);
htmlToolstrip.Position = [10 10 980 130];
fprintf('✓ Created figure and HTML component\n');

%% Step 3: Create toolstrip wrapper
app = struct('fig', fig);
toolstrip = TailwindToolstrip(app, htmlToolstrip);
fprintf('✓ Created TailwindToolstrip wrapper\n');

%% Step 4: Wait for HTML to load (IMPORTANT!)
pause(1);
fprintf('✓ HTML loaded\n');

%% Step 5: Add button groups
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

fprintf('✓ Added 3 button groups\n\n');
fprintf('The toolstrip should now be visible!\n');
fprintf('Try clicking buttons to test.\n');

%% Step 6: Test button updates
% Disable a button
toolstrip.setButtonEnabled('save', false);
fprintf('✓ Disabled Save button\n');

% Re-enable it
toolstrip.setButtonEnabled('save', true);
fprintf('✓ Re-enabled Save button\n');

%% Step 7: Test adding more buttons dynamically
toolstrip.addGroup(struct(...
    'id', 'tools', ...
    'label', 'Tools', ...
    'buttons', {{
        struct('id', 'settings', 'label', 'Settings', 'icon', 'cog')
        struct('id', 'help', 'label', 'Help', 'icon', 'question-circle')
    }}));
fprintf('✓ Added Tools group\n');

%% Step 8: Remove a group
% toolstrip.removeGroup('tools');
% fprintf('✓ Removed Tools group\n');

%% Clean up (run when done testing)
close(fig);
fprintf('✓ Closed figure\n');
