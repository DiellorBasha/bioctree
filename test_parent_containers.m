% Test visualization with different parent containers
% Tests uipanel, GridLayout, and Tab as parents

clear; close all;
bioctree_start;

%% Load mesh
fprintf('Loading FreeSurfer mesh...\n');
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
B = bct.io.import.mesh(path);
fprintf('Loaded %d vertices\n\n', B.Manifold.N);

%% Test 1: uipanel parent
fprintf('Test 1: Visualization in uipanel...\n');
try
    fig1 = uifigure('Name', 'Test 1: uipanel Parent', 'Position', [100 100 800 600]);
    panel = uipanel(fig1, 'Position', [10 10 780 580], 'Title', 'Mesh in Panel');
    
    B.showMesh('Parent', panel, 'ColorMap', 'turbo');
    fprintf('   PASS: Mesh displayed in uipanel\n\n');
    pause(3);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 2: GridLayout parent
fprintf('Test 2: Visualization in GridLayout...\n');
try
    fig2 = uifigure('Name', 'Test 2: GridLayout Parent', 'Position', [150 150 1000 600]);
    grid = uigridlayout(fig2, [1 2]);
    
    % Left side: mesh
    B.showMesh('Parent', grid, 'ColorMap', 'cool');
    
    % Right side: another view
    B.showMesh('Parent', grid, 'ColorMap', 'hot', 'WireFrame', true);
    
    fprintf('   PASS: Two meshes displayed in GridLayout\n\n');
    pause(3);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 3: Tab parent
fprintf('Test 3: Visualization in Tab...\n');
try
    fig3 = uifigure('Name', 'Test 3: Tab Parent', 'Position', [200 200 800 600]);
    tabgroup = uitabgroup(fig3, 'Position', [10 10 780 580]);
    tab1 = uitab(tabgroup, 'Title', 'Default Mesh');
    tab2 = uitab(tabgroup, 'Title', 'Turbo Colormap');
    
    % Tab 1: default mesh
    B.showMesh('Parent', tab1);
    
    % Tab 2: with colormap
    B.showMesh('Parent', tab2, 'ColorMap', 'turbo');
    
    fprintf('   PASS: Meshes displayed in Tabs\n\n');
    pause(3);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 4: Direct visualizer call with uipanel
fprintf('Test 4: Direct bct.show.visualizer with uipanel...\n');
try
    fig4 = uifigure('Name', 'Test 4: Direct Visualizer', 'Position', [250 250 800 600]);
    panel = uipanel(fig4, 'Position', [10 10 780 580], 'Title', 'Direct Visualizer');
    
    viewer = bct.show.visualizer(B, 'Parent', panel, 'ColorMap', 'jet');
    fprintf('   PASS: Direct visualizer in uipanel\n');
    fprintf('   Viewer type: %s\n', class(viewer));
    fprintf('   Viewer parent type: %s\n\n', class(viewer.Parent));
    pause(3);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

fprintf('All parent container tests completed!\n');
fprintf('Close the figures when done viewing.\n');

