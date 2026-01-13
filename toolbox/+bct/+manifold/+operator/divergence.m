function [header, Div] = divergence(meshInput, varargin)
%DIVERGENCE Construct DEC divergence operator (edge 1-form -> vertex/face scalar)
%
% Syntax:
%   [header, Div] = bct.manifold.operator.divergence(M)
%   [header, Div] = bct.manifold.operator.divergence(M, 'route', 'primal')
%   [header, Div] = bct.manifold.operator.divergence(M, 'route', 'dual')
%   [header, Div] = bct.manifold.operator.divergence(V, F, ...)
%
% Inputs:
%   M       - bct.Manifold object
%   OR
%   V       - [nV×3] vertex coordinates
%   F       - [nF×3] face connectivity (1-based)
%
% Name-Value Parameters:
%   route   - 'primal' (default) or 'dual'
%             'primal': primal 1-form → primal 0-form (vertices)
%             'dual':   dual 1-form → dual 0-form (faces)
%
% Outputs:
%   header  - struct with metadata:
%       .method                = "dec"
%       .backend               = "declab"
%       .route                 = "primal" | "dual"
%       .composition           = operator composition string
%       .inputSupport          = "edge"
%       .inputValueType        = "primal1form" | "dual1form"
%       .outputSupport         = "vertex" | "face"
%       .outputValueType       = "scalar"
%       .numVertices, .numEdges, .numFaces
%
%   Div     - Sparse divergence operator matrix:
%             Primal route: [nV×nE] (vertices × edges)
%             Dual route:   [nF×nE] (faces × edges)
%
% Description:
%   Implements DECLab's divergence operator for 1-forms using two routes:
%
%   **Primal Route (default):**
%   Maps primal 1-forms (edge circulations) to primal 0-forms (vertex values):
%       Div = hdd2 * dd1 * hd1
%   Corresponds to: divU = inv(hd0) * dd1 * hd1 * U
%
%   **Dual Route:**
%   Maps dual 1-forms to dual 0-forms (face values):
%       Div = hd2 * d1 * hdd1
%   Corresponds to: divU = hd2 * d1 * inv(hd1) * U
%
%   This is the *linear operator* portion of DECLab's divergence method.
%   Conversion from vector fields to 1-forms (via flat operators) is not
%   included and should be handled separately when standardized.
%
%   Mathematical properties:
%   - Primal divergence: adjoint of exterior derivative d0
%   - Dual divergence: relates to dual exterior calculus
%   - Compatible with DEC operator compositions
%
% Notes:
%   - Does not handle vector field inputs (requires flat operator composition)
%   - Face vector support will be added when stacking conventions standardize
%   - For face vector → vertex divergence: compose with flatDP later
%
% Examples:
%   % Primal divergence (default): 1-form on edges → scalar on vertices
%   M = bct.Manifold(V, F);
%   [header, Div_primal] = bct.manifold.operator.divergence(M);
%   
%   % Apply to primal 1-form
%   U = randn(M.numEdges(), 1);  % Primal 1-form on edges
%   divU = Div_primal * U;       % Divergence on vertices [nV×1]
%   
%   % Dual divergence: 1-form on edges → scalar on faces
%   [header, Div_dual] = bct.manifold.operator.divergence(M, 'route', 'dual');
%   divU_dual = Div_dual * U;    % Divergence on faces [nF×1]
%   
%   % From V, F directly
%   [header, Div] = bct.manifold.operator.divergence(V, F);
%   
%   % Check operator sizes
%   assert(size(Div_primal, 1) == M.numVertices());
%   assert(size(Div_primal, 2) == M.numEdges());
%   assert(size(Div_dual, 1) == M.numFaces());
%
% See also: bct.manifold.operator.dec, bct.manifold.operator.gradient,
%           DiscreteExteriorCalculus.divergence

% ----------------------------
% Parse Name-Value parameters
% ----------------------------
p = inputParser;
p.addParameter('route', "primal", @(s) any(strcmpi(s, ["primal", "dual"])));
p.KeepUnmatched = false;
p.parse(varargin{:});

route = lower(string(p.Results.route));

% Validate route
if ~ismember(route, ["primal", "dual"])
    error('bct:manifold:operator:divergence:InvalidRoute', ...
        'Route must be "primal" or "dual".');
end

% ----------------------------
% Parse mesh inputs and acquire DEC operators
% ----------------------------
if nargin >= 1 && isa(meshInput, 'bct.Manifold')
    % Case: divergence(M, ...)
    M = meshInput;

    % Prefer cached operators; otherwise compute via bct.manifold.operator.dec
    if M.hasCached('operators')
        opsAll = M.operators(); % returns cached only
    else
        [~, opsAll] = bct.manifold.operator.dec(M); % compute primitives
    end

    if isfield(opsAll, 'dec')
        ops = opsAll.dec; % if cache stores operators under .dec
    else
        ops = opsAll;
    end

    numVertices = M.numVertices();
    numFaces    = M.numFaces();
    numEdges    = M.numEdges();

elseif nargin >= 2 && isnumeric(meshInput) && ~issparse(meshInput)
    % Case: divergence(V, F, ...)
    V = meshInput;
    F = varargin{1};
    
    % Remove V, F from varargin for further parameter parsing
    varargin = varargin(2:end);
    
    % Re-parse parameters after removing V, F
    p = inputParser;
    p.addParameter('route', "primal", @(s) any(strcmpi(s, ["primal", "dual"])));
    p.parse(varargin{:});
    route = lower(string(p.Results.route));

    % Validate V, F
    if size(V, 2) ~= 3
        error('bct:manifold:operator:divergence:InvalidVertices', ...
            'V must be an [nV×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:manifold:operator:divergence:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:manifold:operator:divergence:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:manifold:operator:divergence:InvalidFaces', ...
            'F references vertex index %d but V has only %d vertices.', ...
            max(F(:)), size(V, 1));
    end

    % Compute DEC primitives from V, F
    [~, ops] = bct.manifold.operator.dec(V, F);

    numVertices = size(V, 1);
    numFaces    = size(F, 1);
    
    % Get numEdges from DEC operators
    if isfield(ops, 'hd1')
        numEdges = size(ops.hd1, 1);
    elseif isfield(ops, 'd0')
        numEdges = size(ops.d0, 1);
    else
        error('bct:manifold:operator:divergence:MissingOperators', ...
            'Cannot determine number of edges from DEC operators.');
    end

else
    error('bct:manifold:operator:divergence:InvalidInput', ...
        'Usage: divergence(M, ...) or divergence(V, F, ...).');
end

% ----------------------------
% Validate required DEC operators based on route
% ----------------------------
if strcmpi(route, "primal")
    % Primal route requires: hd1, dd1, hdd2
    requiredOps = {'hd1', 'dd1', 'hdd2'};
    for i = 1:length(requiredOps)
        if ~isfield(ops, requiredOps{i})
            error('bct:manifold:operator:divergence:MissingOperators', ...
                'Primal route requires operator: %s', requiredOps{i});
        end
    end
    
    % Validate dimensions
    if size(ops.hd1, 1) ~= numEdges || size(ops.hd1, 2) ~= numEdges
        error('bct:manifold:operator:divergence:DimMismatch', ...
            'hd1 must be [%d×%d] but is [%d×%d].', ...
            numEdges, numEdges, size(ops.hd1, 1), size(ops.hd1, 2));
    end
    if size(ops.dd1, 2) ~= numEdges
        error('bct:manifold:operator:divergence:DimMismatch', ...
            'dd1 columns (%d) must equal numEdges (%d).', ...
            size(ops.dd1, 2), numEdges);
    end
    if size(ops.hdd2, 1) ~= numVertices || size(ops.hdd2, 2) ~= numVertices
        error('bct:manifold:operator:divergence:DimMismatch', ...
            'hdd2 must be [%d×%d] but is [%d×%d].', ...
            numVertices, numVertices, size(ops.hdd2, 1), size(ops.hdd2, 2));
    end
    
else % dual route
    % Dual route requires: hdd1, d1, hd2
    requiredOps = {'hdd1', 'd1', 'hd2'};
    for i = 1:length(requiredOps)
        if ~isfield(ops, requiredOps{i})
            error('bct:manifold:operator:divergence:MissingOperators', ...
                'Dual route requires operator: %s', requiredOps{i});
        end
    end
    
    % Validate dimensions
    if size(ops.hdd1, 1) ~= numEdges || size(ops.hdd1, 2) ~= numEdges
        error('bct:manifold:operator:divergence:DimMismatch', ...
            'hdd1 must be [%d×%d] but is [%d×%d].', ...
            numEdges, numEdges, size(ops.hdd1, 1), size(ops.hdd1, 2));
    end
    if size(ops.d1, 2) ~= numEdges
        error('bct:manifold:operator:divergence:DimMismatch', ...
            'd1 columns (%d) must equal numEdges (%d).', ...
            size(ops.d1, 2), numEdges);
    end
    if size(ops.hd2, 1) ~= numFaces || size(ops.hd2, 2) ~= numFaces
        error('bct:manifold:operator:divergence:DimMismatch', ...
            'hd2 must be [%d×%d] but is [%d×%d].', ...
            numFaces, numFaces, size(ops.hd2, 1), size(ops.hd2, 2));
    end
end

% ----------------------------
% Construct divergence operator based on route
% ----------------------------
if strcmpi(route, "primal")
    % Primal divergence: hdd2 * dd1 * hd1
    % Maps primal 1-form (edges) → primal 0-form (vertices)
    % Size: [nV × nE]
    Div = ops.hdd2 * ops.dd1 * ops.hd1;
    composition = "hdd2 * dd1 * hd1";
    inputValueType = "primal1form";
    outputSupport = "vertex";
    
else % dual route
    % Dual divergence: hd2 * d1 * hdd1
    % Maps dual 1-form (edges) → dual 0-form (faces)
    % Size: [nF × nE]
    Div = ops.hd2 * ops.d1 * ops.hdd1;
    composition = "hd2 * d1 * hdd1";
    inputValueType = "dual1form";
    outputSupport = "face";
end

% ----------------------------
% Build header with metadata
% ----------------------------
header = struct();
header.method = "dec";
header.backend = "declab";
header.route = route;
header.composition = composition;

header.inputSupport = "edge";
header.inputValueType = inputValueType;

header.outputSupport = outputSupport;
header.outputValueType = "scalar";

header.numVertices = numVertices;
header.numEdges = numEdges;
header.numFaces = numFaces;

% Validate output dimensions
if strcmpi(route, "primal")
    if size(Div, 1) ~= numVertices || size(Div, 2) ~= numEdges
        error('bct:manifold:operator:divergence:DimMismatch', ...
            'Primal divergence operator should be [%d×%d] but is [%d×%d].', ...
            numVertices, numEdges, size(Div, 1), size(Div, 2));
    end
else
    if size(Div, 1) ~= numFaces || size(Div, 2) ~= numEdges
        error('bct:manifold:operator:divergence:DimMismatch', ...
            'Dual divergence operator should be [%d×%d] but is [%d×%d].', ...
            numFaces, numEdges, size(Div, 1), size(Div, 2));
    end
end

end
