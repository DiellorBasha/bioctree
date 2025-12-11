% Simple D3 Scatter Plot Example
% Creates a basic scatter plot using D3.js in MATLAB uihtml

%% Setup figure and layout
f = uifigure('Name', 'D3 Scatter Plot Example');
set(f, 'Position', [100 100 800 600]);
g = uigridlayout(f, 'RowHeight', {'fit', '1x'}, 'ColumnWidth', {'1x'});

%% Generate simple scatter data
n = 50;  % number of points
x = randn(n, 1) * 10 + 50;  % x values centered around 50
y = 2 * x + randn(n, 1) * 15 + 10;  % y values with linear relationship + noise

% Package data for D3
scatterData = struct('x', x, 'y', y);

%% Create title
title = uilabel(g, 'Text', 'Simple D3 Scatter Plot', ...
    'HorizontalAlignment', 'center', 'FontSize', 20);
title.Layout.Row = 1;
title.Layout.Column = 1;

%% Create the UIHTML component which renders the D3 chart
scatterPlot = uihtml(g, 'HTMLSource', 'd3_scatter_plot.html'); 
scatterPlot.Layout.Row = 2;
scatterPlot.Layout.Column = 1;
scatterPlot.Data = scatterData;
