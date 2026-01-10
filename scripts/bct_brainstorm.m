function B = bct_brainstorm(resolution)
% BCT_BRAINSTORM Load Bct object from Brainstorm cortex mesh data
%
% Automatically loads mesh data from the Brainstorm test dataset and creates
% a Bct object for testing and development purposes.
%
% Syntax:
%   B = bct_brainstorm()            % Loads low resolution by default
%   B = bct_brainstorm('low')       % Loads low resolution mesh
%   B = bct_brainstorm('high')      % Loads high resolution mesh
%
% Inputs:
%   resolution - (Optional) String specifying mesh resolution:
%                'low'  - Low resolution mesh (default)
%                'high' - High resolution mesh
%
% Outputs:
%   B - Bct object initialized with Brainstorm cortex mesh
%
% Example:
%   % Load Brainstorm cortex mesh
%   B = bct_brainstorm();
%   
%   % Add time domain for spatiotemporal analysis
%   B.Time = bct.Time(10, 100);  % 10 samples at 100 Hz
%   
%   % Create a signal on the manifold
%   signal_data = randn(B.Manifold.N, 1);
%   S = bct.Signal(B.Manifold, signal_data);
%
% See also: bct.bct, bct.bct.fromMesh, bct_fsaverage

% Parse resolution argument
if nargin < 1
    resolution = 'low';  % Default to low resolution
end

% Normalize resolution string
resolution = lower(resolution);

% Validate resolution
if ~ismember(resolution, {'low', 'high'})
    error('bct:InvalidResolution', ...
          'Resolution must be ''low'' or ''high''. Got: %s', resolution);
end

% Construct file path
mesh_file = sprintf('tess_cortex_pial_%s.mat', resolution);
mesh_path = fullfile('data', 'mesh', 'external', 'brainstorm', 'anat', '@default_subject', mesh_file);

% Check if file exists
if ~exist(mesh_path, 'file')
    error('bct:MeshFileNotFound', ...
          'Brainstorm mesh file not found: %s\nMake sure you are in the bioctree root directory.', mesh_path);
end

% Load mesh data
fprintf('Loading Brainstorm cortex mesh...\n');
data = load(mesh_path);

% Validate required fields
% Brainstorm mesh files typically contain a struct with Vertices and Faces
if ~isfield(data, 'Vertices') || ~isfield(data, 'Faces')
    error('bct:InvalidMeshFile', ...
          'Brainstorm mesh file must contain ''Vertices'' and ''Faces'' fields.');
end

% Create Bct object from mesh
fprintf('Creating Bct object...\n');
B = bct.bct.fromMesh(data.Vertices, data.Faces);

fprintf('✓ Bct object created with %d vertices and %d faces\n', ...
        size(data.Vertices, 1), size(data.Faces, 1));

% Display additional info if available
if isfield(data, 'Comment')
    fprintf('  Mesh comment: %s\n', data.Comment);
end

end
