function M = mass(Manifold, options)
%MASS Assemble FEM mass matrix from Manifold
%
% Syntax:
%   M = bct.manifold.operator.mass(Manifold)
%   M = bct.manifold.operator.mass(Manifold, 'Type', massType)
%
% Inputs:
%   Manifold - bct.Manifold object
%
% Name-Value Parameters:
%   Type - Mass matrix type (default: 'voronoi')
%          'voronoi'     - Voronoi area cells (diagonal, default for triangles)
%          'barycentric' - Equal area distribution (diagonal)
%          'full'        - Consistent FEM mass matrix (sparse, with off-diagonal)
%
% Outputs:
%   M - [N×N] sparse mass matrix defining FEM inner product
%
% Description:
%   Assembles the FEM mass matrix using gptoolbox. The mass matrix defines
%   the L2 inner product on the manifold:
%
%   ⟨u, v⟩ = u' * M * v
%
%   Three types available:
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
%   % Default (voronoi)
%   M = bct.manifold.operator.mass(manifold);
%
%   % Barycentric lumped mass
%   M = bct.manifold.operator.mass(manifold, 'Type', 'barycentric');
%
%   % Full consistent mass
%   M = bct.manifold.operator.mass(manifold, 'Type', 'full');
%
%   % Use with FEM inner product
%   norm_u = sqrt(u' * M * u);
%
% See also: bct.manifold.operator.stiffness, massmatrix

arguments
    Manifold (1,1) bct.Manifold
    options.Type (1,1) string {mustBeMember(options.Type, ["voronoi","barycentric","full"])} = "voronoi"
end

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
    M = massmatrix(V, F, char(options.Type));
catch ME
    error('bct:manifold:operator:mass:GPToolboxError', ...
        'Failed to call gptoolbox massmatrix: %s\nPath: %s', ...
        ME.message, gptoolboxPath);
end

% Symmetrize for numerical safety
M = (M + M') / 2;

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
