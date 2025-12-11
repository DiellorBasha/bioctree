%% Test TailwindPlotPanel Component
% Quick test script for the plot panel component

clear; clc;
addpath('matlab');

%% Create figure and plot panel
fig = uifigure('Name', 'PlotPanel Test', 'Position', [100 100 800 600]);

% Create plot panel component
panel = TailwindPlotPanel(fig, [0 0 800 600]);

%% Set initial mode
panel.send(struct('cmd', 'setMode', 'mode', 'rotate'));

%% Simulate loading data
panel.send(struct('cmd', 'setLoading', 'loading', true));
pause(1);

% Generate sample mesh data (simple sphere)
[X, Y, Z] = sphere(20);
vertices = [X(:), Y(:), Z(:)];

% Send mesh data
panel.send(struct(...
    'cmd', 'loadMesh', ...
    'vertices', vertices, ...
    'stats', struct('vertices', size(vertices, 1))...
));

panel.send(struct('cmd', 'setLoading', 'loading', false));

%% Test mode switching
disp('Testing mode switches...');
modes = {'rotate', 'pan', 'select', 'measure'};

for i = 1:length(modes)
    pause(1.5);
    panel.send(struct('cmd', 'setMode', 'mode', modes{i}));
    fprintf('Mode: %s\n', modes{i});
end

%% Update camera
pause(1);
panel.send(struct(...
    'cmd', 'updateCamera', ...
    'camera', struct('x', 10, 'y', 10, 'zoom', 1.5)...
));

disp('PlotPanel test complete!');
