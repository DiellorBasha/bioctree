function out = mass(meshInput, varargin)
%MASS Assemble FEM mass matrix from Manifold or mesh data
%
% Syntax:
%   mass = bct.manifold.operator.mass(M)
%   mass = bct.manifold.operator.mass(V, F)
%   mass = bct.manifold.operator.mass(..., Name, Value)
%
% Inputs:
%   M       - bct.Manifold object
%   OR
%   V       - [N×3] vertex coordinates
%   F       - [nF×3] face connectivity (1-based)
%
% Name-Value Parameters:
%   variant    - Mass matrix variant (default: 'voronoi')
%                'voronoi'     - Voronoi area cells (diagonal, default)
%                'barycentric' - Equal area distribution (diagonal)
%                'full'        - Consistent FEM mass matrix (sparse)
%   symmetrize - Force symmetrization (default: true)
%   precision  - Output precision (default: 'double')
%                'double' - Double precision
%                'single' - Single precision
%
% Outputs:
%   out - Structure matching mass dataset schema:
%     .attributes - Dataset-level metadata:
%       .variant    - Mass matrix variant used
%       .symmetrize - Whether symmetrization was applied
%       .precision  - Precision of output matrix
%       .path       - HDF5/Zarr path for this dataset
%       .description - Dataset description
%     .value - [N×N] sparse mass matrix defining FEM inner product
%
% Description:
%   Assembles the FEM mass matrix using gptoolbox. The mass matrix defines
%   the L2 inner product on the manifold:
%
%   ⟨u, v⟩ = u' * M * v
%
%   Three variants available:
%   - 'voronoi': Diagonal matrix with true Voronoi areas (handles obtuse
%     triangles), best for most applications
%   - 'barycentric': Diagonal matrix distributing triangle area equally
%     to vertices (area/3 per vertex)
%   - 'full': Consistent FEM mass with off-diagonal coupling, more
%     accurate but denser
%
%   This function delegates to gptoolbox massmatrix() which is the
%   authoritative implementation. Dependency path is resolved via bct.config.
%
% Examples:
%   % Using Manifold object (default voronoi, double precision, symmetrized)
%   mass = bct.manifold.operator.mass(manifold);
%   M = mass.value;
%
%   % Using explicit V, F
%   mass = bct.manifold.operator.mass(V, F);
%
%   % Barycentric lumped mass
%   mass = bct.manifold.operator.mass(manifold, 'variant', 'barycentric');
%
%   % Full consistent mass without symmetrization
%   mass = bct.manifold.operator.mass(V, F, ...
%       'variant', 'full', 'symmetrize', false);
%
%   % Single precision output
%   mass = bct.manifold.operator.mass(manifold, ...
%       'variant', 'voronoi', 'precision', 'single');
%
%   % Use with FEM inner product
%   mass = bct.manifold.operator.mass(manifold);
%   M = mass.value;
%   norm_u = sqrt(u' * M * u);
%
% See also: bct.manifold.operator.stiffness, bct.manifold.operator.gradient, massmatrix

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:manifold:operator:mass:NoInput', ...
        'At least one input required: mass(M) or mass(V, F)');
end

% Check if first argument is Manifold or numeric
if isa(meshInput, 'bct.Manifold')
    % Case: mass(M, Name=Value...)
    V = meshInput.Vertices;
    F = meshInput.Faces;
    nameValueStart = 1;
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    % Case: mass(V, F, Name=Value...)
    V = meshInput;
    F = varargin{1};
    nameValueStart = 2;
    
    % Validate V, F
    if size(V, 2) ~= 3
        error('bct:manifold:operator:mass:InvalidVertices', ...
            'V must be an [N×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:manifold:operator:mass:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:manifold:operator:mass:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:manifold:operator:mass:InvalidFaces', ...
            'F references vertex index %d but V has only %d vertices.', ...
            max(F(:)), size(V, 1));
    end
else
    error('bct:manifold:operator:mass:InvalidInput', ...
        'Input must be either mass(M) or mass(V, F). Got %s.', class(meshInput));
end

% Parse Name-Value pairs
p = inputParser;
p.addParameter('variant', 'voronoi', @(x) ismember(x, ["voronoi","barycentric","full"]));
p.addParameter('symmetrize', true, @islogical);
p.addParameter('precision', 'double', @(x) ismember(x, ["double","single"]));
p.parse(varargin{nameValueStart:end});

% Extract parameters
variant = char(p.Results.variant);
symmetrize = p.Results.symmetrize;
precision = char(p.Results.precision);

% Resolve gptoolbox path via bct.config
gptoolboxPath = resolveGPToolboxPath();

% Call gptoolbox massmatrix function
% Add path temporarily if not already present
needsPath = ~contains(path, gptoolboxPath);
if needsPath
    addpath(gptoolboxPath);
    cleanup = onCleanup(@() rmpath(gptoolboxPath));
end

try
    M = massmatrix(V, F, variant);
catch ME
    error('bct:manifold:operator:mass:GPToolboxError', ...
        'Failed to call gptoolbox massmatrix: %s\nPath: %s', ...
        ME.message, gptoolboxPath);
end

% Symmetrize if requested
if symmetrize
    M = (M + M') / 2;
end

% Convert precision if requested
if strcmp(precision, 'single')
    M = single(M);
end

% Build output structure with dataset and attributes
out = struct();

% Dataset-level attributes (metadata for this specific dataset)
out.attributes = struct();
out.attributes.name = 'mass';
out.attributes.path = 'operator/mass';
out.attributes.description = 'FEM mass matrix (area-weighted inner product)';
out.attributes.variant = variant;
out.attributes.symmetrize = symmetrize;
out.attributes.precision = precision;
out.attributes.units = 'area_units';
out.attributes.shape = [size(V, 1), size(V, 1)];
out.attributes.nnz = nnz(M);
out.attributes.storage = 'sparse';

% The actual dataset (sparse matrix)
out.value = M;
end

%% ========================================================================
% HELPER: RESOLVE GPTOOLBOX PATH
%% ========================================================================

function gptoolboxPath = resolveGPToolboxPath()
%RESOLVEGPTOOLBOXPATH Get path to gptoolbox mesh folder from bct.config
%
% Uses bct.install system to locate installed dependencies.
% Path precedence:
%   1. Environment variable BCT_DEPS_ROOT
%   2. MATLAB preference bct/depsRoot
%   3. Default: userpath/ThirdParty/bct
%
% Returns path to gptoolbox/mesh subfolder where massmatrix.m lives.

% Get dependency root using bct.install.internal
try
    [depsRoot, ~] = bct.install.internal.resolveRoot('');
catch ME
    error('bct:manifold:operator:mass:ConfigError', ...
        'Failed to resolve dependency root: %s', ME.message);
end

% Load manifest to get gptoolbox folder name
try
    manifest = bct.config.deps();
    if ~isfield(manifest, 'gptoolbox')
        error('bct:manifold:operator:mass:ManifestError', ...
            'gptoolbox not found in dependency manifest');
    end
    gptoolboxFolder = manifest.gptoolbox.folder;
catch ME
    % Fallback to hardcoded folder name
    warning('bct:manifold:operator:mass:ManifestWarning', ...
        'Could not load manifest, using default folder name: %s', ME.message);
    gptoolboxFolder = 'gptoolbox';
end

% Construct path to gptoolbox/mesh (where massmatrix.m lives)
gptoolboxPath = fullfile(depsRoot, gptoolboxFolder, 'mesh');

% Validate path exists
if ~exist(gptoolboxPath, 'dir')
    error('bct:manifold:operator:mass:PathNotFound', ...
        ['gptoolbox mesh folder not found: %s\n\n' ...
         'Install dependencies with:\n' ...
         '  bct.install.deps\n\n' ...
         'Or configure existing installation with:\n' ...
         '  bct.install.configure(''path/to/deps'')'], ...
        gptoolboxPath);
end

% Validate massmatrix.m exists
massmatrixFile = fullfile(gptoolboxPath, 'massmatrix.m');
if ~exist(massmatrixFile, 'file')
    error('bct:manifold:operator:mass:FunctionNotFound', ...
        'massmatrix.m not found in: %s', gptoolboxPath);
end

end
