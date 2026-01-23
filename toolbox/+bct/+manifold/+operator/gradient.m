function dataset = gradient(meshInput, varargin)
%GRADIENT Construct DEC gradient operator (vertex scalar -> face vector)
%
% Syntax:
%   dataset = bct.manifold.operator.gradient(M)
%   dataset = bct.manifold.operator.gradient(V, F)
%   dataset = bct.manifold.operator.gradient(d0, sharpPD)
%
% Inputs:
%   M       - bct.Manifold object
%   OR
%   V       - [nV×3] vertex coordinates
%   F       - [nF×3] face connectivity (1-based)
%   OR
%   d0      - [nE×nV] exterior derivative mapping primal 0-forms to primal 1-forms
%   sharpPD - [(3*nF)×nE] sharp operator mapping primal 1-forms to stacked face vectors
%
% Outputs:
%   dataset - Schema-compliant structure:
%       .value      - [(3*nF)×nV] sparse gradient operator matrix
%       .attributes - Metadata struct with fields:
%           .name                    = "gradient"
%           .description             = "DEC gradient operator"
%           .shape                   = [3*nF, nV]
%           .dtype                   = "double"
%           .format                  = "coo"
%           .nnz                     = number of non-zeros
%           .method                  = "dec"
%           .backend                 = "declab"
%           .composition             = "sharpPD * d0"
%           .inputSupport            = "vertex"
%           .inputValueType          = "scalar"
%           .outputSupport           = "face"
%           .outputValueType         = "tangent2"
%           .requiresTangentProjection = true
%           .computedBy              = "bct.manifold.operator.gradient"
%
% Description:
%   Matches the *linear* portion of DECLab's gradient implementation:
%       gradS = primal1FormToDualVector(d0 * S)
%   where primal1FormToDualVector applies:
%       sharpPD * (d0 * S) and then projects to face tangents.
%
%   This function returns only the linear operator:
%       grad = sharpPD * d0
%   Tangent projection is expected to be enforced later by bct.Operator.apply,
%   based on operator metadata.
%
% Notes:
%   - Output stacking convention is not yet standardized in bct. Do not reshape/slice outputs
%     unless you explicitly know the convention used by sharpPD.
%
% See also: bct.manifold.operator.dec, bct.manifold.operator.divergence

% ----------------------------
% Parse inputs and acquire d0/sharpPD
% ----------------------------
if nargin == 1
    % Case: gradient(M)
    if ~isa(meshInput, 'bct.Manifold')
        error('bct:manifold:operator:gradient:InvalidInput', ...
            'With one input, expected a bct.Manifold object.');
    end
    M = meshInput;

    % Prefer cached operators; otherwise compute via bct.manifold.operator.dec
    if M.hasCached('operators')
        opsAll = M.operators(); % returns cached only (per your API)
    else
        [~, opsAll] = bct.manifold.operator.dec(M); % compute primitives
        % Optional: if you later decide dec(M) should populate cache, do it there
    end

    if isfield(opsAll, 'dec')
        opsAll = opsAll.dec; % if your cache stores operators under .dec
    end

    if ~isfield(opsAll, 'd0') || ~isfield(opsAll, 'sharpPD')
        error('bct:manifold:operator:gradient:MissingOperators', ...
            'Operators must contain fields d0 and sharpPD.');
    end

    d0 = opsAll.d0;
    sharpPD = opsAll.sharpPD;

    numVertices = M.numVertices();
    numFaces    = M.numFaces();
    numEdges    = size(d0, 1);

elseif nargin == 2
    % Case: gradient(V,F) OR gradient(d0,sharpPD)
    arg1 = meshInput;
    arg2 = varargin{1};

    if issparse(arg1) && issparse(arg2)
        % gradient(d0, sharpPD)
        d0 = arg1;
        sharpPD = arg2;

        numVertices = size(d0, 2);
        numEdges    = size(d0, 1);

        if size(sharpPD, 2) ~= numEdges
            error('bct:manifold:operator:gradient:DimMismatch', ...
                'sharpPD columns (%d) must equal d0 rows / numEdges (%d).', ...
                size(sharpPD, 2), numEdges);
        end

        nOut = size(sharpPD, 1);
        if mod(nOut, 3) ~= 0
            error('bct:manifold:operator:gradient:InvalidSharpPD', ...
                'sharpPD rows (%d) must be divisible by 3 to represent face vector3 stacking.', nOut);
        end
        numFaces = nOut / 3;

    elseif isnumeric(arg1) && isnumeric(arg2) && ~issparse(arg1) && ~issparse(arg2)
        % gradient(V, F)
        V = arg1;
        F = arg2;

        % Validate V, F
        if size(V, 2) ~= 3
            error('bct:manifold:operator:gradient:InvalidVertices', ...
                'V must be an [nV×3] numeric array.');
        end
        if size(F, 2) ~= 3
            error('bct:manifold:operator:gradient:InvalidFaces', ...
                'F must be an [nF×3] numeric array of vertex indices.');
        end
        if any(F(:) < 1) || any(F(:) ~= round(F(:)))
            error('bct:manifold:operator:gradient:InvalidFaces', ...
                'F must contain positive 1-based integer indices.');
        end
        if max(F(:)) > size(V, 1)
            error('bct:manifold:operator:gradient:InvalidFaces', ...
                'F references vertex index %d but V has only %d vertices.', ...
                max(F(:)), size(V, 1));
        end

        % Compute DEC primitives from V,F
        [~, dec_ops] = bct.manifold.operator.dec(V, F);
        d0 = dec_ops.d0;
        sharpPD = dec_ops.sharpPD;

        numVertices = size(V, 1);
        numFaces    = size(F, 1);
        numEdges    = size(d0, 1);

        % Sanity check against sharpPD shape
        if size(sharpPD, 2) ~= numEdges
            error('bct:manifold:operator:gradient:DimMismatch', ...
                'sharpPD columns (%d) must equal d0 rows / numEdges (%d).', ...
                size(sharpPD, 2), numEdges);
        end
        if size(sharpPD, 1) ~= 3 * numFaces
            error('bct:manifold:operator:gradient:DimMismatch', ...
                'sharpPD rows (%d) must equal 3*numFaces (%d).', ...
                size(sharpPD, 1), 3 * numFaces);
        end

    else
        error('bct:manifold:operator:gradient:InvalidInput', ...
            'With two inputs, provide either (V,F) numeric arrays or (d0,sharpPD) sparse matrices.');
    end

else
    error('bct:manifold:operator:gradient:InvalidNumArgs', ...
        'Usage: gradient(M) or gradient(V,F) or gradient(d0,sharpPD).');
end

% ----------------------------
% Validate operator dimensions
% ----------------------------
if size(d0, 1) ~= size(sharpPD, 2)
    error('bct:manifold:operator:gradient:DimMismatch', ...
        'Dimension mismatch: d0 is %dx%d and sharpPD is %dx%d (need size(d0,1)==size(sharpPD,2)).', ...
        size(d0,1), size(d0,2), size(sharpPD,1), size(sharpPD,2));
end

% ----------------------------
% Construct gradient operator (linear part)
% ----------------------------
grad = sharpPD * d0;  % (3*nF) x nV

% ----------------------------
% Build schema-compliant dataset structure
% ----------------------------
dataset = struct();
dataset.value = grad;
dataset.attributes = struct(...
    'name', 'gradient', ...
    'path', '/operators/gradient', ...
    'description', 'DEC gradient operator (vertex scalar → face tangent vector)', ...
    'shape', size(grad), ...
    'dtype', 'double', ...
    'format', 'coo', ...
    'nnz', nnz(grad), ...
    'symmetric', false, ...
    'method', 'dec', ...
    'backend', 'declab', ...
    'composition', 'sharpPD * d0', ...
    'inputSupport', 'vertex', ...
    'inputValueType', 'scalar', ...
    'outputSupport', 'face', ...
    'outputValueType', 'tangent2', ...
    'requiresTangentProjection', true, ...
    'numVertices', numVertices, ...
    'numEdges', numEdges, ...
    'numFaces', numFaces, ...
    'computedBy', 'bct.manifold.operator.gradient');

end
