% Test visualization in uipanel
clear; close all;

% Initialize
bioctree_start;

% Load mesh
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
B = bct.io.import.mesh(path);

% Create UI figure and panel
fig = uifigure('Name', 'Bct Visualization in Panel', 'Position', [100 100 800 600]);
panel = uipanel(fig, 'Position', [10 10 780 580], 'Title', 'Brain Mesh');

% Try to show mesh in panel
try
    B.showMesh('Parent', panel);
    disp('SUCCESS: Mesh displayed in panel');
catch ME
    disp('ERROR:');
    disp(ME.message);
    disp(' ');
    disp('Stack:');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end
