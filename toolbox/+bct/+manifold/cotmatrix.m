function K = cotmatrix(Manifold)
%COTMATRIX Assemble FEM stiffness (cotangent Laplacian) matrix from Manifold
%
% Syntax:
%   K = bct.manifold.cotmatrix(Manifold)
%
% Inputs:
%   Manifold - bct.Manifold object
%
% Outputs:
%   K - [N×N] sparse stiffness matrix (cotangent Laplacian)
%
% Description:
%   Assembles the FEM stiffness matrix using gptoolbox. The stiffness matrix
%   represents the discrete Dirichlet energy and Laplace-Beltrami operator:
%
%   E(u) = u' * K * u  (Dirichlet energy)
%   Δu = M^(-1) * K * u  (Laplace-Beltrami operator)
%
%   The matrix is constructed using cotangent weights:
%   - K(i,j) = cot(α) + cot(β) for edge (i,j), where α,β are opposite angles
%   - K(i,i) = -sum(K(i,:))  (negative row sum, ensures null space)
%
%   Physical meaning:
%   - Measures geometric connectivity via angles in triangulation
%   - Positive semidefinite on closed manifolds (λ ≥ 0)
%   - Null space corresponds to constant functions
%
%   Note: gptoolbox cotmatrix() returns negative semidefinite form
%   (negative diagonal). This function negates it to get positive
%   semidefinite form K*u = λ*M*u with λ ≥ 0.
%
%   Dependency path is resolved via bct.config/bct.install system.
%
% Examples:
%   % Compute stiffness matrix
%   K = bct.manifold.cotmatrix(manifold);
%
%   % Dirichlet energy
%   M = bct.manifold.massmatrix(manifold);
%   energy = u' * K * u;
%
%   % Laplace-Beltrami operator application
%   Lu = M \ (K * u);
%
%   % Eigenvalue problem
%   [V, D] = eigs(K, M, 100, 'sm');
%
% See also: bct.manifold.massmatrix, cotmatrix

arguments
    Manifold (1,1) bct.Manifold
end

% Resolve gptoolbox path via bct.config
gptoolboxPath = resolveGPToolboxPath();

% Get vertices and faces from manifold
V = Manifold.Vertices;
F = Manifold.Faces;

% Call gptoolbox cotmatrix function
% Add path temporarily if not already present
needsPath = ~contains(path, gptoolboxPath);
if needsPath
    addpath(gptoolboxPath);
    cleanup = onCleanup(@() rmpath(gptoolboxPath));
end

try
    K_gptoolbox = cotmatrix(V, F);
catch ME
    error('bct:manifold:cotmatrix:GPToolboxError', ...
        'Failed to call gptoolbox cotmatrix: %s\nPath: %s', ...
        ME.message, gptoolboxPath);
end

% Negate to get positive semidefinite form (gptoolbox returns negative)
% This allows eigenvalue problem: K*u = λ*M*u with λ ≥ 0
K = -K_gptoolbox;

% Symmetrize for numerical safety
K = (K + K') / 2;

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
% Returns path to gptoolbox/mesh subfolder where cotmatrix.m lives.

% Get dependency root using bct.install.internal
try
    [depsRoot, ~] = bct.install.internal.resolveRoot('');
catch ME
    error('bct:manifold:cotmatrix:ConfigError', ...
        'Failed to resolve dependency root: %s', ME.message);
end

% Load manifest to get gptoolbox folder name
try
    manifest = bct.config.deps();
    if ~isfield(manifest, 'gptoolbox')
        error('bct:manifold:cotmatrix:ManifestError', ...
            'gptoolbox not found in dependency manifest');
    end
    gptoolboxFolder = manifest.gptoolbox.folder;
catch ME
    % Fallback to hardcoded folder name
    warning('bct:manifold:cotmatrix:ManifestWarning', ...
        'Could not load manifest, using default folder name: %s', ME.message);
    gptoolboxFolder = 'gptoolbox';
end

% Construct path to gptoolbox/mesh (where cotmatrix.m lives)
gptoolboxPath = fullfile(depsRoot, gptoolboxFolder, 'mesh');

% Validate path exists
if ~exist(gptoolboxPath, 'dir')
    error('bct:manifold:cotmatrix:PathNotFound', ...
        ['gptoolbox mesh folder not found: %s\n\n' ...
         'Install dependencies with:\n' ...
         '  bct.install.deps\n\n' ...
         'Or configure existing installation with:\n' ...
         '  bct.install.configure(''path/to/deps'')'], ...
        gptoolboxPath);
end

% Validate cotmatrix.m exists
cotmatrixFile = fullfile(gptoolboxPath, 'cotmatrix.m');
if ~exist(cotmatrixFile, 'file')
    error('bct:manifold:cotmatrix:FunctionNotFound', ...
        'cotmatrix.m not found in: %s', gptoolboxPath);
end

end
