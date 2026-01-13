function [header, K] = stiffness(Manifold, options)
%STIFFNESS Assemble FEM stiffness matrix from Manifold
%
% Syntax:
%   [header, K] = bct.manifold.operator.stiffness(Manifold)
%   [header, K] = bct.manifold.operator.stiffness(Manifold, Name, Value, ...)
%
% Inputs:
%   Manifold - bct.Manifold object
%
% Name-Value Parameters:
%   variant    - Stiffness matrix variant (default: 'cotan')
%                'cotan' - Cotangent Laplacian (only option currently)
%   sign       - Sign convention (default: 'positive')
%                'positive' - Positive semidefinite (λ ≥ 0)
%                'negative' - Negative semidefinite (λ ≤ 0, as in gptoolbox)
%   symmetrize - Force symmetric matrix (default: true)
%   precision  - Matrix precision (default: 'double')
%                'double' - Double precision
%                'single' - Single precision
%
% Outputs:
%   header - Struct containing parameters used:
%            .variant    - Stiffness variant used
%            .sign       - Sign convention applied
%            .symmetrize - Whether matrix was symmetrized
%            .precision  - Matrix precision
%   K      - [N×N] sparse stiffness matrix (cotangent Laplacian)
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
%   - Positive semidefinite on closed manifolds (λ ≥ 0) with sign='positive'
%   - Null space corresponds to constant functions
%
%   Note: gptoolbox cotmatrix() returns negative semidefinite form
%   (negative diagonal). By default, this function negates it to get positive
%   semidefinite form K*u = λ*M*u with λ ≥ 0.
%
%   Dependency path is resolved via bct.config/bct.install system.
%
% Examples:
%   % Default: cotangent Laplacian, positive semidefinite, symmetrized
%   [header, K] = bct.manifold.operator.stiffness(M);
%
%   % Get negative form (as gptoolbox returns)
%   [header, K] = bct.manifold.operator.stiffness(M, 'sign', 'negative');
%
%   % Single precision
%   [header, K] = bct.manifold.operator.stiffness(M, 'precision', 'single');
%
%   % Dirichlet energy
%   [~, M0] = bct.manifold.operator.mass(M);
%   energy = u' * K * u;
%
%   % Laplace-Beltrami operator application
%   Lu = M0 \ (K * u);
%
%   % Eigenvalue problem
%   [V, D] = eigs(K, M0, 100, 'sm');
%
% See also: bct.manifold.operator.mass, bct.Manifold.cotmatrix

arguments
    Manifold (1,1) bct.Manifold
    options.variant (1,1) string {mustBeMember(options.variant, ["cotan"])} = "cotan"
    options.sign (1,1) string {mustBeMember(options.sign, ["positive","negative"])} = "positive"
    options.symmetrize (1,1) logical = true
    options.precision (1,1) string {mustBeMember(options.precision, ["double","single"])} = "double"
end

% Build header with parameters used
header = struct();
header.variant = char(options.variant);
header.sign = char(options.sign);
header.symmetrize = options.symmetrize;
header.precision = char(options.precision);

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
    error('bct:manifold:operator:stiffness:GPToolboxError', ...
        'Failed to call gptoolbox cotmatrix: %s\nPath: %s', ...
        ME.message, gptoolboxPath);
end

% Apply sign convention
% gptoolbox returns negative semidefinite form
% Default is to negate for positive semidefinite (λ ≥ 0)
if strcmp(header.sign, 'positive')
    K = -K_gptoolbox;
else
    K = K_gptoolbox;
end

% Symmetrize for numerical safety
if header.symmetrize
    K = (K + K') / 2;
end

% Apply precision
if strcmp(header.precision, 'single')
    K = single(K);
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
% Returns path to gptoolbox/mesh subfolder where cotmatrix.m lives.

% Get dependency root using bct.install.internal
try
    [depsRoot, ~] = bct.install.internal.resolveRoot('');
catch ME
    error('bct:manifold:operator:stiffness:ConfigError', ...
        'Failed to resolve dependency root: %s', ME.message);
end

% Load manifest to get gptoolbox folder name
try
    manifest = bct.config.deps();
    if ~isfield(manifest, 'gptoolbox')
        error('bct:manifold:operator:stiffness:ManifestError', ...
            'gptoolbox not found in dependency manifest');
    end
    gptoolboxFolder = manifest.gptoolbox.folder;
catch ME
    % Fallback to hardcoded folder name
    warning('bct:manifold:operator:stiffness:ManifestWarning', ...
        'Could not load manifest, using default folder name: %s', ME.message);
    gptoolboxFolder = 'gptoolbox';
end

% Construct path to gptoolbox/mesh (where cotmatrix.m lives)
gptoolboxPath = fullfile(depsRoot, gptoolboxFolder, 'mesh');

% Validate path exists
if ~exist(gptoolboxPath, 'dir')
    error('bct:manifold:operator:stiffness:PathNotFound', ...
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
    error('bct:manifold:operator:stiffness:FunctionNotFound', ...
        'cotmatrix.m not found in: %s', gptoolboxPath);
end

end
