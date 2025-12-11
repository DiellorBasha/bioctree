% Copyright 2019 The MathWorks, Inc. 
%% Setup component layout and data
f = uifigure;
set(f,'Position',[100 100 900 600]);
g = uigridlayout(f, 'RowHeight', {'fit', 'fit', '1x'}, 'ColumnWidth', {25, '1x', 'fit', 'fit', 25});

year = 2000:2015;
country = "Japan";
populationCounts = generatePopulationCounts(year, country);

%% Create the UIHTML component which renders the D3 chart defined in the associated HTML file
populationPyramid = uihtml(g,'HTMLSource','d3_population_pyramid.html'); 
populationPyramid.Layout.Row = [2 3];
populationPyramid.Layout.Column = [1 5];
populationPyramid.Data = struct('Year', year(end), 'PopulationCounts', populationCounts);


% Setup additional components for year selection
title = uilabel(g, "Text", "Population Pyramid Example", 'HorizontalAlignment', 'center', 'FontSize', 22);
title.Layout.Row = 1;
title.Layout.Column = [1 5];

chartLabel = uilabel(g, "Text", num2str(year(end)) + " Gender Split by age groups", 'FontSize', 16);
chartLabel.Layout.Row = 2;
chartLabel.Layout.Column = 2;

yearLabel = uilabel(g, "Text", "Year", 'FontSize', 16);
yearLabel.Layout.Row = 2;
yearLabel.Layout.Column = 3;

yearDropdown = uidropdown(g,'Items', compose('%d', year), 'Value', num2str(year(end)), 'FontSize', 16, ...
    'ValueChangedFcn', @(src, event) updateData(src, event.Value, chartLabel, populationPyramid, populationCounts));
yearDropdown.Layout.Row = 2;
yearDropdown.Layout.Column = 4;



