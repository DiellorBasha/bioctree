function S = loadBrainstormSource(fileOrFolder, varargin)
% LOADBRAINSTORMSOURCE Load Brainstorm source results and anatomy
%
% S = loadBrainstormSource(fileOrFolder) loads Brainstorm source results
% from a .mat file or folder containing results_MEG_* and anatomy files.
%
% S = loadBrainstormSource(fileOrFolder, 'param', value, ...) specifies
% additional parameters:
%   'WeightType'     - 'geodesic' (default) or 'cotangent' for graph weights
%   'NormalizedLap'  - true/false to compute normalized Laplacian (default: true)
%   'Verbose'        - true/false for detailed output (default: false)
%
% Returns:
%   S - Structure with fields:
%     .V         - Vertices (N x 3)
%     .F         - Faces (F x 3)  
%     .vertconn  - Vertex connectivity matrix (sparse N x N)
%     .LG        - Graph Laplacian matrix (sparse N x N)
%     .X_src     - Source time series (N x T)
%     .fs        - Sampling rate (Hz)
%     .tvec      - Time vector (1 x T)
%     .X_sens    - Sensor time series (M x T, optional)
%     .kernel    - Imaging kernel (N x M, optional)
%     .chanNames - Channel names (cell array, optional)
%     .subject   - Subject identifier (string, optional)
%
% Example:
%   S = meg_gsp.io.loadBrainstormSource('results_MEG_sample.mat');
%   S = meg_gsp.io.loadBrainstormSource('/path/to/study/', 'WeightType', 'cotangent');
%
% References:
%   This function implements loading of cortical surface graphs following
%   the mesh connectivity and Laplacian construction from GSPBOX.
%
% See also: exportDerivedMaps, meg_gsp.graph.fromCortex

% Input validation and parameter parsing
p = inputParser;
addRequired(p, 'fileOrFolder', @(x) ischar(x) || isstring(x));
addParameter(p, 'WeightType', 'geodesic', @(x) ismember(x, {'geodesic', 'cotangent'}));
addParameter(p, 'NormalizedLap', true, @islogical);
addParameter(p, 'Verbose', false, @islogical);
parse(p, fileOrFolder, varargin{:});

opts = p.Results;

if opts.Verbose
    fprintf('Loading Brainstorm source data from: %s\n', fileOrFolder);
end

% Initialize output structure
S = struct();

try
    % Determine if input is file or folder
    if isfolder(fileOrFolder)
        [sourceFile, anatomyFile] = findBrainstormFiles(fileOrFolder);
    else
        sourceFile = fileOrFolder;
        anatomyFile = []; % Will try to find automatically
    end
    
    % Load source results
    if opts.Verbose
        fprintf('  Loading source file: %s\n', sourceFile);
    end
    sourceData = load(sourceFile);
    
    % Extract source time series
    if isfield(sourceData, 'ImageGridAmp')
        S.X_src = sourceData.ImageGridAmp;
    elseif isfield(sourceData, 'F')
        S.X_src = sourceData.F;
    else
        error('No source time series found in file. Expected ImageGridAmp or F field.');
    end
    
    % Extract time information
    if isfield(sourceData, 'Time')
        S.tvec = sourceData.Time;
        S.fs = 1 / (S.tvec(2) - S.tvec(1));
    else
        warning('No time vector found. Using default sampling rate of 1000 Hz.');
        [~, T] = size(S.X_src);
        S.fs = 1000;
        S.tvec = (0:T-1) / S.fs;
    end
    
    % Extract sensor data if available
    if isfield(sourceData, 'SensorData')
        S.X_sens = sourceData.SensorData;
    end
    
    % Extract imaging kernel if available
    if isfield(sourceData, 'ImagingKernel')
        S.kernel = sourceData.ImagingKernel;
    end
    
    % Extract channel names if available
    if isfield(sourceData, 'ChannelFlag') || isfield(sourceData, 'ChannelNames')
        if isfield(sourceData, 'ChannelNames')
            S.chanNames = sourceData.ChannelNames;
        end
    end
    
    % Load anatomy (surface mesh)
    if isempty(anatomyFile)
        anatomyFile = findAnatomyFile(sourceFile);
    end
    
    if ~isempty(anatomyFile) && exist(anatomyFile, 'file')
        if opts.Verbose
            fprintf('  Loading anatomy file: %s\n', anatomyFile);
        end
        anatomyData = load(anatomyFile);
        
        % Extract vertices and faces
        if isfield(anatomyData, 'Vertices')
            S.V = anatomyData.Vertices;
        else
            error('No vertices found in anatomy file. Expected Vertices field.');
        end
        
        if isfield(anatomyData, 'Faces')
            S.F = anatomyData.Faces;
        else
            error('No faces found in anatomy file. Expected Faces field.');
        end
        
        % Extract subject info if available
        if isfield(anatomyData, 'Comment')
            S.subject = anatomyData.Comment;
        end
        
    else
        % Try to extract from source file itself
        if isfield(sourceData, 'SurfaceFile') || isfield(sourceData, 'GridLoc')
            if isfield(sourceData, 'GridLoc')
                S.V = sourceData.GridLoc;
                % Generate minimal connectivity for volume sources
                S.F = [];
                if opts.Verbose
                    fprintf('  Using volume grid locations as vertices\n');
                end
            end
        else
            error('No surface anatomy found. Please provide anatomy file or ensure source file contains surface information.');
        end
    end
    
    % Validate dimensions
    [N, T] = size(S.X_src);
    if ~isempty(S.V) && size(S.V, 1) ~= N
        error('Mismatch between number of sources (%d) and vertices (%d)', N, size(S.V, 1));
    end
    
    if length(S.tvec) ~= T
        warning('Time vector length (%d) does not match data length (%d)', length(S.tvec), T);
        S.tvec = (0:T-1) / S.fs;
    end
    
    % Build graph connectivity and Laplacian
    if ~isempty(S.F)
        if opts.Verbose
            fprintf('  Building cortical graph (WeightType: %s)\n', opts.WeightType);
        end
        
        % Create GSPBOX graph structure
        G = meg_gsp.graph.fromCortex(S.V, S.F, struct('WeightType', opts.WeightType, ...
                                                     'NormalizedLap', opts.NormalizedLap));
        S.vertconn = G.W;
        S.LG = G.L;
    else
        % For volume sources, create minimal connectivity
        warning('No face connectivity available. Creating identity graph.');
        S.vertconn = speye(N);
        S.LG = speye(N);
    end
    
    if opts.Verbose
        fprintf('Successfully loaded: %d vertices, %d time points, %.1f seconds\n', ...
                N, T, T/S.fs);
    end
    
catch ME
    error('Failed to load Brainstorm source data: %s', ME.message);
end

end

function [sourceFile, anatomyFile] = findBrainstormFiles(folderPath)
% Find Brainstorm result and anatomy files in folder
sourceFile = [];
anatomyFile = [];

% Look for results files
resultFiles = dir(fullfile(folderPath, 'results_*.mat'));
if ~isempty(resultFiles)
    sourceFile = fullfile(folderPath, resultFiles(1).name);
end

% Look for anatomy files
anatFiles = dir(fullfile(folderPath, '*cortex*.mat'));
if isempty(anatFiles)
    anatFiles = dir(fullfile(folderPath, 'tess_*.mat'));
end
if ~isempty(anatFiles)
    anatomyFile = fullfile(folderPath, anatFiles(1).name);
end

if isempty(sourceFile)
    error('No Brainstorm results file found in folder: %s', folderPath);
end
end

function anatomyFile = findAnatomyFile(sourceFile)
% Try to find corresponding anatomy file
anatomyFile = [];
[pathStr, name, ~] = fileparts(sourceFile);

% Common patterns for anatomy files
patterns = {
    fullfile(pathStr, '*cortex*.mat'),
    fullfile(pathStr, 'tess_*.mat'),
    fullfile(pathStr, [name(1:end-8), 'cortex.mat']),  % Remove 'results_' prefix
};

for i = 1:length(patterns)
    files = dir(patterns{i});
    if ~isempty(files)
        anatomyFile = fullfile(pathStr, files(1).name);
        break;
    end
end
end