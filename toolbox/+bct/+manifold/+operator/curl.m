function dataset = curl(meshInput, varargin)
%CURL Construct DEC curl operator (edge 1-form -> face/vertex scalar)
%
% Syntax:
%   dataset = bct.manifold.operator.curl(M)
%   dataset = bct.manifold.operator.curl(M, 'route', 'primal')
%   dataset = bct.manifold.operator.curl(M, 'route', 'dual')
%   dataset = bct.manifold.operator.curl(V, F, ...)
%
% Inputs:
%   M       - bct.Manifold object
%   OR
%   V       - [nV×3] vertex coordinates
%   F       - [nF×3] face connectivity (1-based)
%
% Name-Value Parameters:
%   route   - 'primal' (default) or 'dual'
%             'primal': primal 1-form → dual 0-form (faces)
%             'dual':   dual 1-form → primal 0-form (vertices)
%
% Outputs:
%   dataset - Schema-compliant structure:
%       .value      - Sparse curl operator matrix
%                     Primal route: [nF×nE] (faces × edges)
%                     Dual route:   [nV×nE] (vertices × edges)
%       .attributes - Metadata struct with fields:
%           .name           = "curl"
%           .route          = "primal" | "dual"
%           .composition    = operator composition string
%           .inputSupport   = "edge"
%           .outputSupport  = "face" | "vertex"
%           .outputValueType = "scalar"
%           .computedBy     = "bct.manifold.operator.curl"
%
% Description:
%   Implements DECLab's curl operator for 1-forms using two routes:
%
%   **Primal Route (default):**
%   Maps primal 1-forms (edge circulations) to dual 0-forms (face values):
%       Curl = hd2 * d1
%   
%   This is the discrete curl that measures circulation per face.
%   Output represents the "twist" or rotation at each face center.
%
%   **Dual Route:**
%   Maps dual 1-forms to primal 0-forms (vertex values):
%       Curl = hdd2 * dd1
%   
%   This measures circulation around vertices using the dual complex.
%
%   Mathematical properties:
%   - Primal curl: exterior derivative d1 with Hodge dual to faces
%   - Dual curl: dual exterior derivative dd1 with inverse Hodge to vertices
%   - Related to vorticity in fluid dynamics
%   - Complementary to divergence operator
%
% Notes:
%   - For 2D manifolds, curl produces scalar (0-form) outputs
%   - In 3D, curl would produce vector fields (not applicable here)
%   - Satisfies curl(grad(f)) = 0 (up to numerical precision)
%
% Examples:
%   % Primal curl (default): 1-form on edges → scalar on faces
%   M = bct.Manifold(V, F);
%   [header, Curl_primal] = bct.manifold.operator.curl(M);
%   
%   % Apply to primal 1-form
%   U = randn(M.numEdges(), 1);  % Primal 1-form on edges
%   curlU = Curl_primal * U;     % Curl on faces [nF×1]
%   
%   % Dual curl: 1-form on edges → scalar on vertices
%   [header, Curl_dual] = bct.manifold.operator.curl(M, 'route', 'dual');
%   curlU_dual = Curl_dual * U;  % Curl on vertices [nV×1]
%   
%   % Verify curl(gradient) = 0
%   [~, grad] = bct.manifold.operator.gradient(M);
%   [~, curl] = bct.manifold.operator.curl(M);
%   f = randn(M.numVertices(), 1);
%   curl_of_grad = curl * (grad * f);  % Should be ~0
%   
%   % From V, F directly
%   [header, Curl] = bct.manifold.operator.curl(V, F);
%   
%   % Check operator sizes
%   assert(size(Curl_primal, 1) == M.numFaces());
%   assert(size(Curl_primal, 2) == M.numEdges());
%   assert(size(Curl_dual, 1) == M.numVertices());
%
% See also: bct.manifold.operator.dec, bct.manifold.operator.gradient,
%           bct.manifold.operator.divergence, DiscreteExteriorCalculus.curl

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
    error('bct:manifold:operator:curl:InvalidRoute', ...
        'Route must be "primal" or "dual".');
end

% ----------------------------
% Parse mesh inputs and acquire DEC operators
% ----------------------------
if nargin >= 1 && isa(meshInput, 'bct.Manifold')
    % Case: curl(M, ...)
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
    % Case: curl(V, F, ...)
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
        error('bct:manifold:operator:curl:InvalidVertices', ...
            'V must be an [nV×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:manifold:operator:curl:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:manifold:operator:curl:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:manifold:operator:curl:InvalidFaces', ...
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
        error('bct:manifold:operator:curl:MissingOperators', ...
            'Cannot determine number of edges from DEC operators.');
    end

else
    error('bct:manifold:operator:curl:InvalidInput', ...
        'Usage: curl(M, ...) or curl(V, F, ...).');
end

% ----------------------------
% Validate required DEC operators based on route
% ----------------------------
if strcmpi(route, "primal")
    % Primal route requires: hd2, d1
    requiredOps = {'hd2', 'd1'};
    for i = 1:length(requiredOps)
        if ~isfield(ops, requiredOps{i})
            error('bct:manifold:operator:curl:MissingOperators', ...
                'Primal route requires operator: %s', requiredOps{i});
        end
    end
    
    % Validate dimensions
    if size(ops.hd2.value, 1) ~= numFaces || size(ops.hd2.value, 2) ~= numFaces
        error('bct:manifold:operator:curl:DimMismatch', ...
            'hd2 must be [%d×%d] but is [%d×%d].', ...
            numFaces, numFaces, size(ops.hd2.value, 1), size(ops.hd2.value, 2));
    end
    if size(ops.d1.value, 2) ~= numEdges
        error('bct:manifold:operator:curl:DimMismatch', ...
            'd1 columns (%d) must equal numEdges (%d).', ...
            size(ops.d1.value, 2), numEdges);
    end
    if size(ops.d1.value, 1) ~= numFaces
        error('bct:manifold:operator:curl:DimMismatch', ...
            'd1 rows (%d) must equal numFaces (%d).', ...
            size(ops.d1.value, 1), numFaces);
    end
    
else % dual route
    % Dual route requires: hdd2, dd1
    requiredOps = {'hdd2', 'dd1'};
    for i = 1:length(requiredOps)
        if ~isfield(ops, requiredOps{i})
            error('bct:manifold:operator:curl:MissingOperators', ...
                'Dual route requires operator: %s', requiredOps{i});
        end
    end
    
    % Validate dimensions
    if size(ops.hdd2.value, 1) ~= numVertices || size(ops.hdd2.value, 2) ~= numVertices
        error('bct:manifold:operator:curl:DimMismatch', ...
            'hdd2 must be [%d×%d] but is [%d×%d].', ...
            numVertices, numVertices, size(ops.hdd2.value, 1), size(ops.hdd2.value, 2));
    end
    if size(ops.dd1.value, 2) ~= numEdges
        error('bct:manifold:operator:curl:DimMismatch', ...
            'dd1 columns (%d) must equal numEdges (%d).', ...
            size(ops.dd1.value, 2), numEdges);
    end
    if size(ops.dd1.value, 1) ~= numVertices
        error('bct:manifold:operator:curl:DimMismatch', ...
            'dd1 rows (%d) must equal numVertices (%d).', ...
            size(ops.dd1.value, 1), numVertices);
    end
end

% ----------------------------
% Construct curl operator based on route
% ----------------------------
if strcmpi(route, "primal")
    % Primal curl: hd2 * d1
    % Maps primal 1-form (edges) → dual 0-form (faces)
    % Size: [nF × nE]
    Curl = ops.hd2.value * ops.d1.value;
    composition = "hd2 * d1";
    inputValueType = "primal1form";
    outputSupport = "face";
    
else % dual route
    % Dual curl: hdd2 * dd1
    % Maps dual 1-form (edges) → primal 0-form (vertices)
    % Size: [nV × nE]
    Curl = ops.hdd2.value * ops.dd1.value;
    composition = "hdd2 * dd1";
    inputValueType = "dual1form";
    outputSupport = "vertex";
end

% ----------------------------
% Build header with metadata
% ----------------------------
% Validate output dimensions
% ----------------------------
if strcmpi(route, "primal")
    if size(Curl, 1) ~= numFaces || size(Curl, 2) ~= numEdges
        error('bct:manifold:operator:curl:DimMismatch', ...
            'Primal curl operator should be [%d×%d] but is [%d×%d].', ...
            numFaces, numEdges, size(Curl, 1), size(Curl, 2));
    end
else
    if size(Curl, 1) ~= numVertices || size(Curl, 2) ~= numEdges
        error('bct:manifold:operator:curl:DimMismatch', ...
            'Dual curl operator should be [%d×%d] but is [%d×%d].', ...
            numVertices, numEdges, size(Curl, 1), size(Curl, 2));
    end
end

% ----------------------------
% Build schema-compliant dataset structure
% ----------------------------
dataset = struct();
dataset.value = Curl;
dataset.attributes = struct(...
    'name', 'curl', ...
    'path', '/operators/curl', ...
    'description', sprintf('DEC curl operator (%s route)', route), ...
    'shape', size(Curl), ...
    'dtype', 'double', ...
    'format', 'coo', ...
    'nnz', nnz(Curl), ...
    'symmetric', false, ...
    'method', 'dec', ...
    'backend', 'declab', ...
    'route', char(route), ...
    'composition', char(composition), ...
    'inputSupport', 'edge', ...
    'inputValueType', char(inputValueType), ...
    'outputSupport', char(outputSupport), ...
    'outputValueType', 'scalar', ...
    'numVertices', numVertices, ...
    'numEdges', numEdges, ...
    'numFaces', numFaces, ...
    'computedBy', 'bct.manifold.operator.curl');

end
