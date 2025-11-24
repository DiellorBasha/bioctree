function B = bct_fsaverage(hemisphere)
% BCT_FSAVERAGE Load Bct object from fsaverage test mesh data
%
% Automatically loads mesh data from the test dataset and creates a Bct
% object for testing and development purposes.
%
% Syntax:
%   B = bct_fsaverage()           % Loads left hemisphere by default
%   B = bct_fsaverage('lh')       % Loads left hemisphere
%   B = bct_fsaverage('rh')       % Loads right hemisphere
%
% Inputs:
%   hemisphere - (Optional) String specifying hemisphere:
%                'lh' or 'left'  - Left hemisphere (default)
%                'rh' or 'right' - Right hemisphere
%
% Outputs:
%   B - Bct object initialized with fsaverage mesh
%
% Example:
%   % Load left hemisphere fsaverage mesh
%   B = bct_fsaverage('lh');
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
