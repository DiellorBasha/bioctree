function [header, M] = mass(Manifold, options)
%MASS Assemble FEM mass matrix from Manifold
%
% Syntax:
%   [header, M] = bct.manifold.operator.mass(Manifold)
%   [header, M] = bct.manifold.operator.mass(Manifold, Name, Value)
%
% Inputs:
%   Manifold - bct.Manifold object
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
%   header - Structure containing the parameters used:
%            .variant    - Mass matrix variant used
%            .symmetrize - Whether symmetrization was applied
%            .precision  - Precision of output matrix
%   M      - [N×N] sparse mass matrix defining FEM inner product
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
%   % Default (voronoi, double precision, symmetrized)
%   [header, M] = bct.manifold.operator.mass(manifold);
%
%   % Barycentric lumped mass
%   [header, M] = bct.manifold.operator.mass(manifold, 'variant', 'barycentric');
%
%   % Full consistent mass without symmetrization
%   [header, M] = bct.manifold.operator.mass(manifold, ...
%       'variant', 'full', 'symmetrize', false);
%
%   % Single precision output
%   [header, M] = bct.manifold.operator.mass(manifold, ...
%       'variant', 'voronoi', 'precision', 'single');
%
%   % Use with FEM inner product
%   [~, M] = bct.manifold.operator.mass(manifold);
%   norm_u = sqrt(u' * M * u);
%
% See also: bct.manifold.operator.stiffness, massmatrix

arguments
    Manifold (1,1) bct.Manifold
    options.variant (1,1) string {mustBeMember(options.variant, ["voronoi","barycentric","full"])} = "voronoi"
    options.symmetrize (1,1) logical = true
    options.precision (1,1) string {mustBeMember(options.precision, ["double","single"])} = "double"
end

% Build header structure with input parameters
header = struct();
header.variant = char(options.variant);
header.symmetrize = options.symmetrize;
header.precision = char(options.precision);

% Resolve gptoolbox path via bct.config
gptoolboxPath = resolveGPToolboxPath();

% Get vertices and faces from manifold
V = Manifold.Vertices;
F = Manifold.Faces;

% Call gptoolbox massmatrix function
% Add path temporarily if not already present
needsPath = ~contains(path, gptoolboxPath);
if needsPath
    addpath(gptoolboxPath);
    cleanup = onCleanup(@() rmpath(gptoolboxPath));
end

try
    M = massmatrix(V, F, header.variant);
catch ME
    error('bct:manifold:operator:mass:GPToolboxError', ...
        'Failed to call gptoolbox massmatrix: %s\nPath: %s', ...
        ME.message, gptoolboxPath);
end

% Symmetrize if requested
if header.symmetrize
    M = (M + M') / 2;
end

% Convert precision if requested
if strcmp(header.precision, 'single')
    M = single(M);
end

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
