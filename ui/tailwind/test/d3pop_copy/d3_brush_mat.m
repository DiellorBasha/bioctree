% D3 Brush Snapping Component Example
% Based on https://observablehq.com/@d3/brush-snapping
clear

%% Setup component layout and data
f = uifigure('Name', 'D3 Brush Example');
set(f, 'Position', [100 100 800 200]);
g = uigridlayout(f, 'RowHeight', {'fit', '1x'}, 'ColumnWidth', {25, '1x', 25});

% Define the brush parameters
brushData = struct();
brushData.min = 0;          % Minimum value
brushData.max = 100;        % Maximum value
brushData.snapInterval = 5; % Snap to every 5 units
brushData.initialSelection = [20, 60]; % Initial brush selection

%% Create the UIHTML component which renders the D3 brush
brushComponent = uihtml(g, 'HTMLSource', 'd3_brush.html'); 
brushComponent.Layout.Row = 2;
brushComponent.Layout.Column = [1 3];
brushComponent.Data = brushData;

% Set up callbacks
brushComponent.CreateFcn            = @brushCreated;
brushComponent.DeleteFcn            = @brushDeleted;
brushComponent.DataChangedFcn       = @brushDataChanged;
brushComponent.HTMLEventReceivedFcn = @brushChanged;

% Add title
title = uilabel(g, "Text", "D3 Brush Snapping Example", 'HorizontalAlignment', 'center', 'FontSize', 18);
title.Layout.Row = 1;
title.Layout.Column = [1 3];

% Display instructions
fprintf('=== D3 Brush Component Test ===\n');
fprintf('1. Wait for the brush to appear in the figure\n');
fprintf('2. Press F12 to open browser console and check for errors\n');
fprintf('3. Drag the brush handles to change selection\n');
fprintf('4. Watch this console for brush events\n');
fprintf('================================\n\n');


