%% Quick Toolstrip Test - Run All
% This script tests the toolstrip with proper CSS loading

clear; clc;

% Setup
cd C:\CodingProjects\bioctree
addpath('ui/matlab')
fprintf('✓ Path setup complete\n');

% Create figure
fig = uifigure('Name', 'Toolstrip Test', 'Position', [100 100 1000 150]);
html = uihtml(fig);
html.Position = [10 10 980 130];
fprintf('✓ Figure created\n');

% Create toolstrip (this will now load CSS properly)
app = struct('fig', fig);
toolstrip = TailwindToolstrip(app, html);
fprintf('✓ Toolstrip created (CSS should load now!)\n');

% Wait for HTML to load
pause(1);

% Add button groups
toolstrip.addGroup(struct('id', 'file', 'label', 'File', 'buttons', {{
    struct('id', 'open', 'label', 'Open', 'icon', 'folder-open')
    struct('id', 'save', 'label', 'Save', 'icon', 'save')
    struct('id', 'export', 'label', 'Export', 'icon', 'download')
}}));

toolstrip.addGroup(struct('id', 'edit', 'label', 'Edit', 'buttons', {{
    struct('id', 'undo', 'label', 'Undo', 'icon', 'undo')
    struct('id', 'redo', 'label', 'Redo', 'icon', 'redo')
}}));

toolstrip.addGroup(struct('id', 'view', 'label', 'View', 'buttons', {{
    struct('id', 'zoomIn', 'label', 'Zoom In', 'icon', 'zoom-in')
    struct('id', 'zoomOut', 'label', 'Zoom Out', 'icon', 'zoom-out')
    struct('id', 'reset', 'label', 'Reset', 'icon', 'refresh')
}}));

fprintf('✓ Added 3 button groups\n\n');
fprintf('🎉 The toolstrip should now be visible with proper styling!\n');
fprintf('   Look for:\n');
fprintf('   - Dark background\n');
fprintf('   - Styled buttons with hover effects\n');
fprintf('   - Icons next to labels\n');
fprintf('   - "BCT" logo on the left\n\n');

% Test disabling a button
pause(0.5);
toolstrip.setButtonEnabled('save', false);
fprintf('✓ Disabled "Save" button (should appear grayed out)\n');

pause(2);
toolstrip.setButtonEnabled('save', true);
fprintf('✓ Re-enabled "Save" button\n');
