function [header, Lap] = hodgelaplacian(meshInput, varargin)
%HODGELAPLACIAN Construct DEC Hodge Laplacian operator
%
% Syntax:
%   [header, Lap] = bct.manifold.operator.hodgelaplacian(M)
%   [header, Lap] = bct.manifold.operator.hodgelaplacian(M, 'kform', 0)
%   [header, Lap] = bct.manifold.operator.hodgelaplacian(M, 'kform', 1)
%   [header, Lap] = bct.manifold.operator.hodgelaplacian(M, 'kform', 2)
%   [header, Lap] = bct.manifold.operator.hodgelaplacian(M, 'normalize', false)
%   [header, Lap] = bct.manifold.operator.hodgelaplacian(V, F, ...)
%
% Inputs:
%   M       - bct.Manifold object
%   OR
%   V       - [nV×3] vertex coordinates
%   F       - [nF×3] face connectivity (1-based)
%
% Name-Value Parameters:
%   kform     - 0 (default), 1, or 2
%               Specifies which Hodge Laplacian to construct (k-form)
%   normalize - true (default) or false (only for kform=0)
%               If true, normalizes by dual 2-simplex areas (vertex Voronoi cells)
%               If false, returns unnormalized cotangent Laplacian
%
% Outputs:
%   header  - struct with metadata:
%       .operator        = "hodgelaplacian"
%       .kform           = 0 | 1 | 2
%       .method          = "dec"
%       .backend         = "declab"
%       .composition     = operator composition string
%       .normalized      = true | false (for kform=0 only)
%       .inputSupport    = "vertex" | "edge" | "face"
%       .outputSupport   = "vertex" | "edge" | "face"
%       .numVertices, .numEdges, .numFaces
%
%   Lap     - Sparse Hodge Laplacian operator matrix:
%             kform=0: [nV×nV] (vertices → vertices)
%             kform=1: [nE×nE] (edges → edges)
%             kform=2: [nF×nF] (faces → faces)
%
% Description:
%   Implements DECLab's Hodge Laplacian operators for differential k-forms.
%   This is distinct from the Laplace-Beltrami operator (bct.manifold.operator.laplacebeltrami).
%
%   **0-form Hodge Laplacian (k=0, scalar fields on vertices):**
%   
%   Normalized (default):
%       Lap = hdd2 * dd1 * hd1 * d0  [nV×nV]
%   
%   Output is a primal 0-form (vertex values representing Laplacian density).
%   This includes area normalization by vertex Voronoi cells.
%   
%   Unnormalized:
%       Lap = dd1 * hd1 * d0  [nV×nV]
%   
%   Output is a dual 2-form (integrated Laplacian per vertex cell).
%   This is equivalent to the classical FEM cotangent Laplacian with no area weights.
%   Note: This differs from M.cotmatrix() which returns the stiffness matrix (positive).
%
%   **1-form Hodge Laplacian (k=1, edge circulations):**
%       Lap = hd1 * d0 * hdd2 * dd1 + dd0 * hd2 * d1 * hdd1  [nE×nE]
%   
%   This is the "dual route" from DECLab's implementation.
%   Acts on primal 1-forms (edge-based fields).
%
%   **2-form Hodge Laplacian (k=2, face-based scalar fields):**
%       Lap = d1 * hdd1 * dd0 * hd2  [nF×nF]
%   
%   Acts on primal 2-forms (integrated values over faces).
%
%   Mathematical properties:
%   - All Laplacians are symmetric
%   - 0-form and 2-form Laplacians are negative semi-definite
%   - Related to heat diffusion, harmonic analysis, spectral geometry
%   - Satisfies Hodge decomposition theory
%
% Notes:
%   - This is the **Hodge Laplacian** (different from Laplace-Beltrami)
%   - M.cotmatrix() returns positive stiffness matrix K
%   - M.massmatrix() returns mass matrix M
%   - Laplace-Beltrami: Δ = M^(-1) * K
%   - Hodge 0-form (normalized): Δ = -M^(-1) * K (different sign convention)
%   - For unnormalized, closely related to cotangent Laplacian
%
% Examples:
%   % 0-form Hodge Laplacian (default, normalized)
%   M = bct.Manifold(V, F);
%   [header, Lap0] = bct.manifold.operator.hodgelaplacian(M);
%   f = randn(M.numVertices(), 1);  % Scalar field on vertices
%   Lap_f = Lap0 * f;                % Laplacian [nV×1]
%   
%   % Unnormalized 0-form Laplacian (FEM cotangent Laplacian)
%   [header, Lap0_unnorm] = bct.manifold.operator.hodgelaplacian(M, 'normalize', false);
%   
%   % 1-form Hodge Laplacian
%   [header, Lap1] = bct.manifold.operator.hodgelaplacian(M, 'kform', 1);
%   U = randn(M.numEdges(), 1);  % 1-form on edges
%   Lap_U = Lap1 * U;             % Laplacian [nE×1]
%   
%   % 2-form Hodge Laplacian
%   [header, Lap2] = bct.manifold.operator.hodgelaplacian(M, 'kform', 2);
%   omega = randn(M.numFaces(), 1);  % 2-form on faces
%   Lap_omega = Lap2 * omega;         % Laplacian [nF×1]
%   
%   % From V, F directly
%   [header, Lap] = bct.manifold.operator.hodgelaplacian(V, F, 'kform', 1);
%   
%   % Check symmetry
%   assert(issymmetric(Lap0));
%   assert(issymmetric(Lap1));
%   assert(issymmetric(Lap2));
%
% See also: bct.manifold.operator.dec, bct.manifold.operator.laplacebeltrami,
%           bct.Manifold.cotmatrix, bct.Manifold.massmatrix, DiscreteExteriorCalculus.laplacian

% ----------------------------
% Parse Name-Value parameters
% ----------------------------
p = inputParser;
p.addParameter('kform', 0, @(x) isnumeric(x) && isscalar(x) && ismember(x, [0, 1, 2]));
p.addParameter('normalize', true, @islogical);
p.KeepUnmatched = false;
p.parse(varargin{:});

kform = p.Results.kform;
normalize = p.Results.normalize;

% Validate k-form
if ~ismember(kform, [0, 1, 2])
    error('bct:manifold:operator:hodgelaplacian:InvalidKForm', ...
        'kform must be 0, 1, or 2.');
end

% ----------------------------
% Parse mesh inputs and acquire DEC operators
% ----------------------------
if nargin >= 1 && isa(meshInput, 'bct.Manifold')
    % Case: hodgelaplacian(M, ...)
    M = meshInput;

    % Prefer cached operators; otherwise compute via bct.manifold.operator.dec
    if M.hasCached('operators')
        opsAll = M.operators(); % returns cached only
    else
        [~, opsAll] = bct.manifold.operator.dec(M); % compute primitives
    end

    % Operators are at top level (no .dec nesting)
    ops = opsAll;

    numVertices = M.numVertices();
    numFaces    = M.numFaces();
    numEdges    = M.numEdges();

elseif nargin >= 2 && isnumeric(meshInput) && ~issparse(meshInput)
    % Case: hodgelaplacian(V, F, ...)
    V = meshInput;
    F = varargin{1};
    
    % Remove V, F from varargin for further parameter parsing
    varargin = varargin(2:end);
    
    % Re-parse parameters after removing V, F
    p = inputParser;
    p.addParameter('kform', 0, @(x) isnumeric(x) && isscalar(x) && ismember(x, [0, 1, 2]));
    p.addParameter('normalize', true, @islogical);
    p.parse(varargin{:});
    kform = p.Results.kform;
    normalize = p.Results.normalize;

    % Validate V, F
    if size(V, 2) ~= 3
        error('bct:manifold:operator:hodgelaplacian:InvalidVertices', ...
            'V must be an [nV×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:manifold:operator:hodgelaplacian:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:manifold:operator:hodgelaplacian:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:manifold:operator:hodgelaplacian:InvalidFaces', ...
            'F references vertex index %d but V has only %d vertices.', ...
            max(F(:)), size(V, 1));
    end

    % Compute DEC primitives from V, F
    [~, ops] = bct.manifold.operator.dec(V, F);

    numVertices = size(V, 1);
    numFaces    = size(F, 1);
    
    % Get numEdges from DEC operators
    if isfield(ops, 'hd1')
        numEdges = size(ops.hd1.value, 1);
    elseif isfield(ops, 'd0')
        numEdges = size(ops.d0.value, 1);
    else
        error('bct:manifold:operator:hodgelaplacian:MissingOperators', ...
            'Cannot determine number of edges from DEC operators.');
    end

else
    error('bct:manifold:operator:hodgelaplacian:InvalidInput', ...
        'Usage: hodgelaplacian(M, ...) or hodgelaplacian(V, F, ...).');
end

% ----------------------------
% Validate required DEC operators based on k-form
% ----------------------------
if kform == 0
    % 0-form Laplacian requires: d0, hd1, dd1, hdd2 (if normalized)
    if normalize
        requiredOps = {'d0', 'hd1', 'dd1', 'hdd2'};
    else
        requiredOps = {'d0', 'hd1', 'dd1'};
    end
    
elseif kform == 1
    % 1-form Laplacian requires: d0, hd1, dd1, hdd2, dd0, hd2, d1, hdd1
    requiredOps = {'d0', 'hd1', 'dd1', 'hdd2', 'dd0', 'hd2', 'd1', 'hdd1'};
    
else % kform == 2
    % 2-form Laplacian requires: d1, hdd1, dd0, hd2
    requiredOps = {'d1', 'hdd1', 'dd0', 'hd2'};
end

% Check for required operators
for i = 1:length(requiredOps)
    if ~isfield(ops, requiredOps{i})
        error('bct:manifold:operator:hodgelaplacian:MissingOperators', ...
            '%d-form Laplacian requires operator: %s', kform, requiredOps{i});
    end
end

% ----------------------------
% Construct Hodge Laplacian operator based on k-form
% ----------------------------
if kform == 0
    % 0-form Hodge Laplacian (scalar Laplacian)
    if normalize
        % Normalized: hdd2 * dd1 * hd1 * d0
        % Size: [nV × nV]
        % Output is primal 0-form (vertex values)
        Lap = ops.hdd2.value * ops.dd1.value * ops.hd1.value * ops.d0.value;
        composition = "hdd2 * dd1 * hd1 * d0";
    else
        % Unnormalized: dd1 * hd1 * d0
        % Size: [nV × nV]
        % Output is dual 2-form (integrated per vertex cell)
        Lap = ops.dd1.value * ops.hd1.value * ops.d0.value;
        composition = "dd1 * hd1 * d0";
    end
    inputSupport = "vertex";
    outputSupport = "vertex";
    
elseif kform == 1
    % 1-form Hodge Laplacian (dual route from DECLab)
    % hd1 * d0 * hdd2 * dd1 + dd0 * hd2 * d1 * hdd1
    % Size: [nE × nE]
    term1 = ops.hd1.value * ops.d0.value * ops.hdd2.value * ops.dd1.value;
    term2 = ops.dd0.value * ops.hd2.value * ops.d1.value * ops.hdd1.value;
    Lap = term1 + term2;
    composition = "hd1 * d0 * hdd2 * dd1 + dd0 * hd2 * d1 * hdd1";
    inputSupport = "edge";
    outputSupport = "edge";
    
else % kform == 2
    % 2-form Hodge Laplacian
    % d1 * hdd1 * dd0 * hd2
    % Size: [nF × nF]
    Lap = ops.d1.value * ops.hdd1.value * ops.dd0.value * ops.hd2.value;
    composition = "d1 * hdd1 * dd0 * hd2";
    inputSupport = "face";
    outputSupport = "face";
end

% ----------------------------
% Build header with metadata
% ----------------------------
header = struct();
header.operator = "hodgelaplacian";
header.kform = kform;
header.method = "dec";
header.backend = "declab";
header.composition = composition;

if kform == 0
    header.normalized = normalize;
end

header.inputSupport = inputSupport;
header.outputSupport = outputSupport;

header.numVertices = numVertices;
header.numEdges = numEdges;
header.numFaces = numFaces;

% Validate output dimensions
if kform == 0
    expectedDim = numVertices;
elseif kform == 1
    expectedDim = numEdges;
else % kform == 2
    expectedDim = numFaces;
end

if size(Lap, 1) ~= expectedDim || size(Lap, 2) ~= expectedDim
    error('bct:manifold:operator:hodgelaplacian:DimMismatch', ...
        '%d-form Laplacian operator should be [%d×%d] but is [%d×%d].', ...
        kform, expectedDim, expectedDim, size(Lap, 1), size(Lap, 2));
end

% Verify symmetry (all Hodge Laplacians should be symmetric)
if ~issymmetric(Lap)
    warning('bct:manifold:operator:hodgelaplacian:NotSymmetric', ...
        '%d-form Hodge Laplacian is not symmetric (max asymmetry: %.2e).', ...
        kform, max(abs(Lap - Lap'), [], 'all'));
end

end
