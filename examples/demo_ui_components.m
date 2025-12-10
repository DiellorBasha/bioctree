%% BCT UI Components - Complete Usage Example
%
% This script demonstrates how to use the bct.ui component system
% in a MATLAB App Designer application.
%
% To use these components in your app:
% 1. Create HTML UI Component widgets in App Designer
% 2. Initialize components in startupFcn
% 3. Implement callback methods as shown below

%% Example App Designer Code

% In your App Designer class properties:
%{
properties (Access = public)
    Toolstrip    bct.ui.Toolstrip
    Sidebar      bct.ui.Sidebar
    Console      bct.ui.Console
    PlotPanel    bct.ui.PlotPanel
    
    % Your data properties
    Mesh         struct
    Signal       double
    Bct          bct.bct
end
%}

% In startupFcn:
%{
function startupFcn(app)
    % Initialize UI components
    app.Toolstrip = bct.ui.Toolstrip(app, app.HTMLToolstrip);
    app.Sidebar = bct.ui.Sidebar(app, app.HTMLSidebar);
    app.Console = bct.ui.Console(app, app.HTMLConsole);
    app.PlotPanel = bct.ui.PlotPanel(app, app.HTMLPlot);
    
    % Configure components
    setupComponents(app);
    
    % Log startup
    app.Console.log('BCT Application initialized');
    app.Console.log('Ready to load mesh data');
end
%}

%% Component Setup

%{
function setupComponents(app)
    % Configure console
    app.Console.setMaxMessages(500);
    app.Console.setAutoScroll(true);
    
    % Configure sidebar with initial sections
    welcomeSection = struct(...
        'id', 'welcome', ...
        'title', 'Welcome', ...
        'content', 'Load a mesh to begin analysis');
    app.Sidebar.addSection(welcomeSection);
    
    % Configure plot panel
    app.PlotPanel.setViewOptions(struct(...
        'colormap', 'parula', ...
        'lighting', true, ...
        'background', [1 1 1]));
    
    % Add custom toolstrip buttons if needed
    app.Toolstrip.addButton('export', 'Export', '📤', 'data');
end
%}

%% Toolstrip Button Handlers

%{
function loadMesh(app)
    % This is called when "Load Mesh" button is clicked
    app.Console.log('Opening mesh file...');
    
    % Disable button during loading
    app.Toolstrip.disableButton('loadMesh');
    
    try
        % Load mesh data
        [file, path] = uigetfile('*.mat', 'Select Mesh File');
        if isequal(file, 0)
            app.Console.warn('Mesh loading cancelled');
            app.Toolstrip.enableButton('loadMesh');
            return;
        end
        
        app.Console.log('Loading %s...', file);
        data = load(fullfile(path, file));
        
        % Store mesh
        app.Mesh = struct(...
            'vertices', data.V, ...
            'faces', data.F);
        
        % Update UI
        updateMeshInfo(app);
        
        % Plot mesh
        app.PlotPanel.plotMesh(app.Mesh.vertices, app.Mesh.faces, ...
            'FaceColor', [0.8 0.8 0.9], ...
            'FaceAlpha', 1.0);
        
        % Enable analysis buttons
        app.Toolstrip.enableButton('computeEigenbasis');
        app.Toolstrip.enableButton('plot3D');
        
        app.Console.success('Mesh loaded: %d vertices, %d faces', ...
            size(app.Mesh.vertices, 1), size(app.Mesh.faces, 1));
        
    catch ME
        app.Console.error('Failed to load mesh: %s', ME.message);
    end
    
    app.Toolstrip.enableButton('loadMesh');
end

function computeEigenbasis(app)
    % This is called when "Compute Eigenbasis" button is clicked
    if isempty(app.Mesh)
        app.Console.error('No mesh loaded');
        return;
    end
    
    app.Console.log('Computing eigenbasis...');
    app.Toolstrip.disableButton('computeEigenbasis');
    
    try
        % Initialize BCT if needed
        if isempty(app.Bct)
            app.Bct = bct.bct.fromMesh(app.Mesh.vertices, app.Mesh.faces);
        end
        
        % Compute eigenbasis
        numModes = 50;
        app.Console.log('Computing %d eigenmodes...', numModes);
        
        app.Bct = app.Bct.computeEigenbasis(numModes);
        
        % Update UI
        updateEigenbasisInfo(app);
        
        % Enable transform and filter buttons
        app.Toolstrip.enableButton('transform');
        app.Toolstrip.enableButton('filter');
        app.Toolstrip.enableButton('plotSpectrum');
        
        app.Console.success('Eigenbasis computed (%d modes)', numModes);
        
    catch ME
        app.Console.error('Eigenbasis computation failed: %s', ME.message);
    end
    
    app.Toolstrip.enableButton('computeEigenbasis');
end

function openFilterDesigner(app)
    % This is called when "Filter Designer" button is clicked
    app.Console.log('Opening filter designer...');
    
    try
        BctFilterDesigner;
    catch ME
        app.Console.error('Could not open filter designer: %s', ME.message);
    end
end

function plot3D(app)
    % This is called when "3D Plot" button is clicked
    if isempty(app.Mesh)
        app.Console.error('No mesh to plot');
        return;
    end
    
    app.Console.log('Plotting 3D mesh...');
    
    if ~isempty(app.Signal)
        app.PlotPanel.plotSignal(app.Mesh.vertices, app.Mesh.faces, ...
            app.Signal, 'Colormap', 'parula');
    else
        app.PlotPanel.plotMesh(app.Mesh.vertices, app.Mesh.faces);
    end
    
    app.Console.success('3D plot rendered');
end

function plotSpectrum(app)
    % This is called when "Spectrum" button is clicked
    if isempty(app.Bct) || ~app.Bct.hasEigenbasis()
        app.Console.error('No eigenbasis computed');
        return;
    end
    
    app.Console.log('Plotting eigenvalue spectrum...');
    
    eigenvalues = app.Bct.Lambda.eigenvalues;
    frequencies = sqrt(eigenvalues);
    
    app.PlotPanel.plotSpectrum(1:length(frequencies), frequencies, ...
        'LineColor', 'blue', 'LineWidth', 2);
    
    app.Console.success('Spectrum plotted');
end

function saveData(app)
    % This is called when "Save" button is clicked
    app.Console.log('Saving data...');
    
    [file, path] = uiputfile('*.mat', 'Save Data');
    if isequal(file, 0)
        app.Console.warn('Save cancelled');
        return;
    end
    
    try
        data = struct();
        if ~isempty(app.Mesh)
            data.mesh = app.Mesh;
        end
        if ~isempty(app.Signal)
            data.signal = app.Signal;
        end
        
        save(fullfile(path, file), '-struct', 'data');
        app.Console.success('Data saved to: %s', file);
        
    catch ME
        app.Console.error('Save failed: %s', ME.message);
    end
end

function handleCustomButton(app, buttonId)
    % Handle custom buttons added to toolstrip
    switch buttonId
        case "export"
            exportResults(app);
        otherwise
            app.Console.warn('Unknown button: %s', buttonId);
    end
end
%}

%% Sidebar Helpers

%{
function updateMeshInfo(app)
    % Update mesh information in sidebar
    meshInfo = struct(...
        'id', 'meshInfo', ...
        'title', 'Mesh Properties', ...
        'content', struct(...
            'Vertices', size(app.Mesh.vertices, 1), ...
            'Faces', size(app.Mesh.faces, 1), ...
            'Type', 'Triangular Mesh'));
    
    % Remove old section if exists
    try
        app.Sidebar.removeSection('welcome');
    catch
    end
    
    app.Sidebar.addSection(meshInfo);
end

function updateEigenbasisInfo(app)
    % Update eigenbasis information in sidebar
    eigenInfo = struct(...
        'id', 'eigenInfo', ...
        'title', 'Eigenbasis', ...
        'content', struct(...
            'Modes', app.Bct.Lambda.size, ...
            'MaxFreq', max(sqrt(app.Bct.Lambda.eigenvalues)), ...
            'Computed', datestr(now)));
    
    app.Sidebar.addSection(eigenInfo);
    
    % Add parameters section
    params = struct(...
        'id', 'params', ...
        'title', 'Parameters', ...
        'content', struct(...
            'Smoothing', 0.5, ...
            'Threshold', 0.01));
    
    app.Sidebar.addSection(params);
end
%}

%% Sidebar Callbacks (Optional)

%{
function onSidebarPropertyChange(app, sectionId, propertyName, value)
    % Called when a property is changed in the sidebar
    app.Console.log('Property changed: %s.%s = %s', ...
        sectionId, propertyName, string(value));
    
    % Handle parameter changes
    if strcmp(sectionId, 'params')
        switch propertyName
            case 'Smoothing'
                % Update smoothing parameter
                app.Console.log('Smoothing set to: %.2f', value);
            case 'Threshold'
                % Update threshold parameter
                app.Console.log('Threshold set to: %.4f', value);
        end
    end
end
%}

%% PlotPanel Callbacks (Optional)

%{
function onPlotViewChanged(app, data)
    % Called when the view/camera changes in plot panel
    if isfield(data, 'camera')
        app.Console.log('View changed: rotation=[%.1f, %.1f, %.1f]', ...
            data.camera.rotation);
    end
end

function onMeshClicked(app, vertexId, position)
    % Called when user clicks on the mesh
    app.Console.log('Vertex clicked: ID=%d, pos=[%.2f, %.2f, %.2f]', ...
        vertexId, position);
    
    % Highlight selected vertex or show details
    if ~isempty(app.Signal)
        value = app.Signal(vertexId);
        app.Console.log('Signal value at vertex: %.4f', value);
    end
end
%}

%% Console Callbacks (Optional)

%{
function handleConsoleCommand(app, input)
    % Called when user enters a command in the console
    app.Console.log('> %s', input);
    
    % Parse and execute command
    try
        % Simple command parser
        tokens = strsplit(input);
        cmd = tokens{1};
        
        switch lower(cmd)
            case 'clear'
                app.Console.clear();
                
            case 'reset'
                resetApplication(app);
                
            case 'export'
                exportResults(app);
                
            case 'help'
                showHelp(app);
                
            otherwise
                % Try to evaluate as MATLAB code
                evalin('base', input);
                app.Console.success('Command executed');
        end
        
    catch ME
        app.Console.error('Command failed: %s', ME.message);
    end
end
%}

%% Utility Functions

%{
function exportResults(app)
    app.Console.log('Exporting results...');
    
    % Export plot as image
    app.PlotPanel.exportImage('output.png');
    
    % Export console log
    app.Console.exportLog('console.txt');
    
    app.Console.success('Results exported');
end

function resetApplication(app)
    app.Console.log('Resetting application...');
    
    % Clear data
    app.Mesh = [];
    app.Signal = [];
    app.Bct = [];
    
    % Clear visualizations
    app.PlotPanel.clear();
    
    % Reset UI state
    app.Toolstrip.disableButton('computeEigenbasis');
    app.Toolstrip.disableButton('transform');
    app.Toolstrip.disableButton('filter');
    app.Toolstrip.disableButton('plotSpectrum');
    
    % Clear sidebar
    app.Sidebar.removeSection('meshInfo');
    app.Sidebar.removeSection('eigenInfo');
    app.Sidebar.removeSection('params');
    
    app.Console.success('Application reset');
end

function showHelp(app)
    app.Console.log('Available commands:');
    app.Console.log('  clear  - Clear console');
    app.Console.log('  reset  - Reset application');
    app.Console.log('  export - Export results');
    app.Console.log('  help   - Show this help');
end
%}

%% Example: Working with Signals

%{
function loadSignal(app)
    % Load or generate a signal
    if isempty(app.Mesh)
        app.Console.error('Load mesh first');
        return;
    end
    
    app.Console.log('Generating signal...');
    
    % Generate example signal (Gaussian bump)
    N = size(app.Mesh.vertices, 1);
    center = round(N/2);
    distances = sqrt(sum((app.Mesh.vertices - app.Mesh.vertices(center,:)).^2, 2));
    app.Signal = exp(-distances.^2 / (2*10^2));
    
    % Plot signal on mesh
    app.PlotPanel.plotSignal(app.Mesh.vertices, app.Mesh.faces, ...
        app.Signal, 'Colormap', 'parula');
    
    app.Console.success('Signal loaded and displayed');
end
%}

%% Notes:
%
% 1. All the code above should be placed in your App Designer class
% 2. HTML UI Components must be named: HTMLToolstrip, HTMLSidebar, 
%    HTMLConsole, HTMLPlot
% 3. Components are automatically configured to call specific methods
%    in your app when buttons are clicked or events occur
% 4. Implement only the methods you need - the system is flexible
% 5. Use the Console for all user feedback
% 6. Keep the UI responsive by disabling controls during long operations
