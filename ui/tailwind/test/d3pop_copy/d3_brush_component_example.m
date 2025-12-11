% Example script demonstrating the d3Brush component
% This shows how to create, configure, and respond to a D3 brush control
clear  
close 

fprintf('=== D3 Brush Component Example ===\n\n');

fig = uifigure('Name', 'D3 Brush Component Example');
fig.Position = [100 100 900 400];

% Create grid layout with multiple sections
g = uigridlayout(fig, [5 2]);
g.RowHeight = {'fit', '1x', 'fit', 'fit', 'fit'};
g.ColumnWidth = {'1x', '1x'};

% Section 1: Title
titleLabel = uilabel(g, 'Text', 'Interactive D3 Brush Component', ...
    'HorizontalAlignment', 'center', 'FontSize', 20, 'FontWeight', 'bold');
titleLabel.Layout.Row = 1;
titleLabel.Layout.Column = [1 2];

% Section 2: Create the d3Brush component
brush = d3Brush(g);
brush.Layout.Row = 2;
brush.Layout.Column = [1 2];

% Configure brush properties
brush.Min = 0;
brush.Max = 100;
brush.SnapInterval = 5;
brush.Value = [20, 60];

%% Section 3: Value display
valueLabel = uilabel(g, 'Text', sprintf('Selected Range: [%.1f, %.1f]  |  Width: %.1f', ...
    brush.Value(1), brush.Value(2), brush.Value(2) - brush.Value(1)), ...
    'HorizontalAlignment', 'center', 'FontSize', 16, 'FontWeight', 'bold');
valueLabel.Layout.Row = 3;
valueLabel.Layout.Column = [1 2];

%% Section 4: Property controls (left column)
% Min control
minLabel = uilabel(g, 'Text', 'Min:', 'HorizontalAlignment', 'right');
minLabel.Layout.Row = 4;
minLabel.Layout.Column = 1;

minSpinner = uispinner(g, 'Value', brush.Min, 'Limits', [-100 100], ...
    'ValueChangedFcn', @(src, evt) updateMin(src, brush));
minSpinner.Layout.Row = 4;
minSpinner.Layout.Column = 1;

% Max control
maxLabel = uilabel(g, 'Text', 'Max:', 'HorizontalAlignment', 'right');
maxLabel.Layout.Row = 5;
maxLabel.Layout.Column = 1;

maxSpinner = uispinner(g, 'Value', brush.Max, 'Limits', [0 200], ...
    'ValueChangedFcn', @(src, evt) updateMax(src, brush));
maxSpinner.Layout.Row = 5;
maxSpinner.Layout.Column = 1;

%% Section 5: Property controls (right column)
% Snap interval control
snapLabel = uilabel(g, 'Text', 'Snap Interval:', 'HorizontalAlignment', 'right');
snapLabel.Layout.Row = 4;
snapLabel.Layout.Column = 3;

snapSpinner = uispinner(g, 'Value', brush.SnapInterval, 'Limits', [1 20], ...
    'ValueChangedFcn', @(src, evt) updateSnap(src, brush));
snapSpinner.Layout.Row = 4;
snapSpinner.Layout.Column = 4;

% Reset button
resetBtn = uibutton(g, 'Text', 'Reset to [20, 60]', ...
    'ButtonPushedFcn', @(~,~) resetBrush(brush));
resetBtn.Layout.Row = 5;
resetBtn.Layout.Column = [3 4];

%% Add event listeners to the brush
addlistener(brush, 'BrushStarted', @(src, evt) onBrushStarted());

addlistener(brush, 'ValueChanged', @(src, evt) onValueChanged(evt, valueLabel));

addlistener(brush, 'BrushEnded', @(src, evt) onBrushEnded(brush));

fprintf('Component created successfully!\n');
fprintf('Instructions:\n');
fprintf('  - Drag the brush handles to change the selection\n');
fprintf('  - Use the spinners to change Min, Max, or Snap Interval\n');
fprintf('  - Click Reset to restore default values\n');
fprintf('  - Watch the console for event logs\n\n');

%% Callback functions

function onBrushStarted()
    fprintf('[Event] Brush interaction started\n');
end

function onValueChanged(evt, label)
    fprintf('[Event] Value changed: [%.2f, %.2f] -> [%.2f, %.2f]\n', ...
        evt.PreviousValue(1), evt.PreviousValue(2), ...
        evt.Value(1), evt.Value(2));
    
    % Update the display label
    width = evt.Value(2) - evt.Value(1);
    label.Text = sprintf('Selected Range: [%.1f, %.1f]  |  Width: %.1f', ...
        evt.Value(1), evt.Value(2), width);
end

function onBrushEnded(brush)
    fprintf('[Event] Brush interaction ended. Final value: [%.2f, %.2f]\n\n', ...
        brush.Value(1), brush.Value(2));
end

function updateMin(spinner, brush)
    brush.Min = spinner.Value;
    fprintf('[Property] Min changed to %.1f\n', spinner.Value);
end

function updateMax(spinner, brush)
    brush.Max = spinner.Value;
    fprintf('[Property] Max changed to %.1f\n', spinner.Value);
end

function updateSnap(spinner, brush)
    brush.SnapInterval = spinner.Value;
    fprintf('[Property] Snap interval changed to %.1f\n', spinner.Value);
end

function resetBrush(brush)
    brush.Value = [20, 60];
    fprintf('[Action] Brush reset to [20, 60]\n');
end
