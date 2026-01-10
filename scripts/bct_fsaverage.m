function B = bct_fsaverage(hemisphere, source)
% BCT_FSAVERAGE Load Bct object from fsaverage test mesh data
%
% Automatically loads mesh data from the test dataset and creates a Bct
% object for testing and development purposes. Can load from raw mesh
% or from pre-saved Bct objects with computed eigenbasis.
%
% Syntax:
%   B = bct_fsaverage()               % Loads left hemisphere from mesh
%   B = bct_fsaverage('lh')           % Loads left hemisphere from mesh
%   B = bct_fsaverage('rh')           % Loads right hemisphere from mesh
%   B = bct_fsaverage('rh', 'mesh')   % Explicitly load from mesh
%   B = bct_fsaverage('rh', 'saved')  % Load pre-saved Bct object (with eigenbasis)
%
% Inputs:
%   hemisphere - (Optional) String specifying hemisphere:
%                'lh' or 'left'  - Left hemisphere (default)
%                'rh' or 'right' - Right hemisphere
%   source     - (Optional) String specifying data source:
%                'mesh'  - Load from mesh and construct Bct (default)
%                'saved' - Load pre-saved Bct object (includes 600 eigenmodes)
%
% Outputs:
%   B - Bct object initialized with fsaverage mesh
%       'saved' source includes pre-computed eigenbasis with 600 modes
%
% Example:
%   % Load left hemisphere fsaverage mesh (construct from scratch)
%   B = bct_fsaverage('lh');
%   
%   % Load right hemisphere with pre-computed eigenbasis (fast!)
%   B = bct_fsaverage('rh', 'saved');
%   
%   % Add time domain for spatiotemporal analysis
%   B.Time = bct.Time(10, 100);  % 10 samples at 100 Hz
%   
%   % Create a signal on the manifold
%   signal_data = randn(B.Manifold.N, 1);
%   S = bct.Signal(B.Manifold, signal_data);
%
% See also: bct.bct, bct.bct.fromMesh

% Parse hemisphere argument
if nargin < 1
    hemisphere = 'lh';  % Default to left hemisphere
end

% Parse source argument
if nargin < 2
    source = 'mesh';  % Default to loading from mesh
end

% Normalize hemisphere string
hemisphere = lower(hemisphere);
if strcmp(hemisphere, 'left')
    hemisphere = 'lh';
elseif strcmp(hemisphere, 'right')
    hemisphere = 'rh';
end

% Validate hemisphere
if ~ismember(hemisphere, {'lh', 'rh'})
    error('bct:InvalidHemisphere', ...
          'Hemisphere must be ''lh'', ''rh'', ''left'', or ''right''. Got: %s', hemisphere);
end

% Validate source
source = lower(source);
if ~ismember(source, {'mesh', 'saved'})
    error('bct:InvalidSource', ...
          'Source must be ''mesh'' or ''saved''. Got: %s', source);
end

% Load based on source type
if strcmp(source, 'saved')
    % Load pre-saved Bct object with computed eigenbasis
    saved_file = sprintf('fs6_%s_pial.mat', hemisphere);
    saved_path = fullfile('data', 'bct', saved_file);
    
    % Check if file exists
    if ~exist(saved_path, 'file')
        error('bct:SavedFileNotFound', ...
              'Saved Bct file not found: %s\nMake sure you are in the bioctree root directory.', saved_path);
    end
    
    fprintf('Loading %s hemisphere fsaverage Bct object (saved)...\n', upper(hemisphere));
    loaded = load(saved_path, 'B');
    B = loaded.B;
    
    fprintf('✓ Bct object loaded with %d vertices, %d eigenmodes\n', ...
            B.Manifold.N, B.Lambda.K);
    
else
    % Load from mesh and construct Bct object
    % Construct file path
    mesh_file = sprintf('fsaverage_%s_pial.mat', hemisphere);
    mesh_path = fullfile('data', 'mesh', mesh_file);
    
    % Check if file exists
    if ~exist(mesh_path, 'file')
        error('bct:MeshFileNotFound', ...
              'Mesh file not found: %s\nMake sure you are in the bioctree root directory.', mesh_path);
    end
    
    % Load mesh data
    fprintf('Loading %s hemisphere fsaverage mesh...\n', upper(hemisphere));
    data = load(mesh_path);
    
    % Validate required variables
    if ~isfield(data, 'V') || ~isfield(data, 'F')
        error('bct:InvalidMeshFile', ...
              'Mesh file must contain ''V'' (vertices) and ''F'' (faces) variables.');
    end
    
    % Create Bct object from mesh
    fprintf('Creating Bct object...\n');
    B = bct.bct.fromMesh(data.V, data.F);
    
    fprintf('✓ Bct object created with %d vertices and %d faces\n', ...
            size(data.V, 1), size(data.F, 1));
end

end
