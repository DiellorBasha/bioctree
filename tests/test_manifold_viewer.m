%% Test ManifoldViewer Component
% Demonstrates all functionality of the ManifoldViewer component

clear; clc;
addpath('ui/matlab');

%% Load test mesh data
% You'll need to have a Bct object with mesh data
% Example: B = bct.bct.fromMesh(V, F);  % or load from file

% For this demo, we'll assume you have a Bct object
% Uncomment and modify the following line:
% B = bct.io.import.mesh('data/mesh/fsaverage_rh_pial.mat');

% Or create from existing data:
% data = load('data/mesh/fsaverage_rh_pial.mat');
% B = bct.bct.fromMesh(data.V, data.F);

% For testing without data, we'll create a placeholder
disp('Note: You need to load a Bct object to test the viewer');
disp('Example:');
disp('  data = load(''data/mesh/fsaverage_rh_pial.mat'');');
disp('  B = bct.bct.fromMesh(data.V, data.F);');
disp(' ');

%% Create figure and viewer
fig = uifigure('Name', 'Manifold Viewer Test', 'Position', [100 100 1000 700]);

% Create panel for 3D viewer
viewerPanel = uipanel(fig, ...
    'Position', [10 150 980 540], ...
    'Title', '3D Visualization', ...
    'FontSize', 12);

% Create control panel
controlPanel = uipanel(fig, ...
    'Position', [10 10 980 130], ...
    'Title', 'Controls', ...
    'FontSize', 12);

%% Create ManifoldViewer
viewer = ManifoldViewer([], viewerPanel);

%% Create control buttons
btnY = 90;
btnLoadMesh = uibutton(controlPanel, ...
    'Position', [20 btnY 120 30], ...
    'Text', 'Load Bct Object', ...
    'ButtonPushedFcn', @(~,~) loadBctCallback(viewer));

btnShowMesh = uibutton(controlPanel, ...
    'Position', [150 btnY 100 30], ...
    'Text', 'Show Mesh', ...
    'ButtonPushedFcn', @(~,~) viewer.showMesh());

btnShowSignal = uibutton(controlPanel, ...
    'Position', [260 btnY 100 30], ...
    'Text', 'Show Signal 1', ...
    'ButtonPushedFcn', @(~,~) viewer.showSignal(1));

btnAnimate = uibutton(controlPanel, ...
    'Position', [370 btnY 100 30], ...
    'Text', 'Toggle Animation', ...
    'ButtonPushedFcn', @(~,~) viewer.animate());

btnReset = uibutton(controlPanel, ...
    'Position', [480 btnY 80 30], ...
    'Text', 'Reset', ...
    'ButtonPushedFcn', @(~,~) viewer.reset());

btnExport = uibutton(controlPanel, ...
    'Position', [570 btnY 100 30], ...
    'Text', 'Export Image', ...
    'ButtonPushedFcn', @(~,~) exportCallback(viewer));

%% Colormap selection
btnY2 = 50;
uilabel(controlPanel, 'Position', [20 btnY2+5 80 20], 'Text', 'Colormap:');
cmapDropdown = uidropdown(controlPanel, ...
    'Position', [100 btnY2 120 30], ...
    'Items', {'parula', 'turbo', 'jet', 'hot', 'viridis', 'plasma'}, ...
    'Value', 'parula', ...
    'ValueChangedFcn', @(src,~) viewer.setColorMap(src.Value));

%% Transparency slider
uilabel(controlPanel, 'Position', [240 btnY2+5 80 20], 'Text', 'Transparency:');
alphaSlider = uislider(controlPanel, ...
    'Position', [320 btnY2+15 150 3], ...
    'Limits', [0 1], ...
    'Value', 1, ...
    'ValueChangedFcn', @(src,~) viewer.setAlpha(src.Value));

%% Wireframe toggle
wireframeCheck = uicheckbox(controlPanel, ...
    'Position', [490 btnY2 100 30], ...
    'Text', 'Wireframe', ...
    'Value', false, ...
    'ValueChangedFcn', @(src,~) viewer.setWireframe(src.Value));

%% Center mesh toggle
centerCheck = uicheckbox(controlPanel, ...
    'Position', [600 btnY2 100 30], ...
    'Text', 'Center Mesh', ...
    'Value', true, ...
    'ValueChangedFcn', @(src,~) viewer.center(src.Value));

%% Animation speed control
btnY3 = 10;
uilabel(controlPanel, 'Position', [20 btnY3+5 120 20], 'Text', 'Animation Speed (FPS):');
speedSpinner = uispinner(controlPanel, ...
    'Position', [140 btnY3 80 30], ...
    'Limits', [1 120], ...
    'Value', 30, ...
    'ValueChangedFcn', @(src,~) viewer.setAnimationSpeed(src.Value));

%% Time point control
uilabel(controlPanel, 'Position', [240 btnY3+5 80 20], 'Text', 'Time Point:');
timeSpinner = uispinner(controlPanel, ...
    'Position', [320 btnY3 80 30], ...
    'Limits', [1 1000], ...
    'Value', 1, ...
    'ValueChangedFcn', @(src,~) viewer.setTimePoint(src.Value));

%% Status label
statusLabel = uilabel(controlPanel, ...
    'Position', [420 btnY3+5 550 20], ...
    'Text', 'Ready. Load a Bct object to begin visualization.', ...
    'FontColor', [0.5 0.5 0.5]);

%% Callback functions
function loadBctCallback(viewer)
    % Attempt to load from workspace or file
    vars = evalin('base', 'whos');
    bctVars = vars(strcmp({vars.class}, 'bct.bct'));
    
    if isempty(bctVars)
        % No Bct objects in workspace - try to load from file
        [file, path] = uigetfile('*.mat', 'Select mesh data file');
        if file ~= 0
            data = load(fullfile(path, file));
            if isfield(data, 'V') && isfield(data, 'F')
                B = bct.bct.fromMesh(data.V, data.F);
                viewer.loadBct(B);
                msgbox('Bct object loaded successfully!', 'Success');
            else
                errordlg('File must contain V (vertices) and F (faces) variables', 'Invalid File');
            end
        end
    else
        % Let user select from workspace
        varNames = {bctVars.name};
        [idx, tf] = listdlg('ListString', varNames, ...
            'SelectionMode', 'single', ...
            'PromptString', 'Select Bct object from workspace:');
        if tf
            B = evalin('base', varNames{idx});
            viewer.loadBct(B);
            msgbox(sprintf('Loaded: %s', varNames{idx}), 'Success');
        end
    end
end

function exportCallback(viewer)
    [file, path] = uiputfile({'*.png'; '*.jpg'; '*.pdf'; '*.eps'}, ...
        'Save visualization as...');
    if file ~= 0
        viewer.exportImage(fullfile(path, file));
        msgbox('Image exported successfully!', 'Success');
    end
end

%% Display instructions
disp('=== ManifoldViewer Test ===');
disp(' ');
disp('Instructions:');
disp('1. Load a Bct object using "Load Bct Object" button');
disp('   - Select from workspace variables, or');
disp('   - Load from .mat file containing V (vertices) and F (faces)');
disp(' ');
disp('2. Use controls to:');
disp('   - Show Mesh: Display mesh with gray coloring');
disp('   - Show Signal: Display first signal with colormap');
disp('   - Toggle Animation: Start/stop time-varying signal animation');
disp('   - Colormap: Change color scheme');
disp('   - Transparency: Adjust mesh opacity');
disp('   - Wireframe: Toggle wireframe display');
disp('   - Center Mesh: Toggle mesh centering');
disp('   - Animation Speed: Control playback FPS');
disp('   - Time Point: Jump to specific time point');
disp(' ');
disp('3. Export current view as image using "Export Image"');
disp(' ');
disp('Available colormaps: parula, turbo, jet, hot, viridis, plasma');
disp(' ');
