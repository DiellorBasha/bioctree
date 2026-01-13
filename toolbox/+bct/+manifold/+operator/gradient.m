function [header, grad] = gradient(meshInput, varargin)
%GRADIENT Construct gradient operator from DEC operators
%
% Syntax:
%   [header, grad] = bct.manifold.operator.gradient(M)
%   [header, grad] = bct.manifold.operator.gradient(V, F)
%   [header, grad] = bct.manifold.operator.gradient(d0, sharpPD)
%
% Inputs:
%   M - bct.Manifold object (uses cached DEC operators if available)
%   OR
%   V - [N×3] vertex coordinates
%   F - [M×3] face connectivity
%   OR
%   d0      - Exterior derivative operator d0: C⁰ → C¹
%   sharpPD - Sharp operator: primal 1-forms → tangent vector fields
%
% Outputs:
%   header - Structure with metadata about gradient computation:
%            .method       - 'DEC'
%            .composition  - 'sharpPD * d0'
%            .domain       - 'vertex' (scalar field on vertices)
%            .codomain     - 'face' (vector field on faces)
%            .numVertices  - Number of vertices (if available)
%            .numFaces     - Number of faces (if available)
%
%   grad - [nF×nV] sparse gradient operator matrix
%          Maps scalar fields on vertices to tangent vector fields on faces
%
% Description:
%   Constructs the discrete gradient operator using DEC composition:
%
%   grad = sharpPD * d0
%
%   Where:
%   - d0: Exterior derivative mapping 0-forms (vertex values) to 1-forms (edge circulations)
%   - sharpPD: Sharp operator mapping primal 1-forms to tangent vector fields
%
%   The resulting gradient operator maps scalar functions defined on vertices
%   to tangent vector fields defined on faces. This is the canonical gradient
%   representation in bct, where gradients are face-mapped vectors suitable
%   for advection, flow visualization, and vector field analysis.
%
%   Mathematical properties:
%   - Domain: Scalar fields on vertices (0-forms)
%   - Codomain: Tangent vector fields on faces (intrinsic 2D vectors)
%   - Metric-aware: Incorporates mesh geometry via sharp operator
%   - Compatible with DEC differential operators
%
% Examples:
%   % From Manifold (uses cached operators if available)
%   M = bct.Manifold(V, F);
%   [header, grad] = bct.manifold.operator.gradient(M);
%   
%   % Apply gradient to scalar field
%   f = rand(M.numVertices(), 1);  % Scalar field on vertices
%   gradf = grad * f;               % Gradient on faces (2*nF vector)
%   
%   % Extract x and y components
%   nF = M.numFaces();
%   gradf_x = gradf(1:nF);
%   gradf_y = gradf(nF+1:end);
%   
%   % From V, F directly
%   [header, grad] = bct.manifold.operator.gradient(V, F);
%   
%   % From DEC operators directly
%   [~, ops] = bct.manifold.operator.dec(M);
%   [header, grad] = bct.manifold.operator.gradient(ops.d0, ops.sharpPD);
%
% See also: bct.manifold.operator.dec, bct.manifold.operator.divergence,
%           DiscreteExteriorCalculus

% Parse inputs
if nargin == 1
    % Case 1: Manifold object
    if isa(meshInput, 'bct.Manifold')
        M = meshInput;
        
        % Try to get operators from cached operators
        if ~isempty(fieldnames(M.Cache.operators.data))
            % Use cached operators
            ops = M.Cache.operators.data;
            if isfield(ops, 'dec') && isfield(ops.dec, 'd0') && isfield(ops.dec, 'sharpPD')
                d0 = ops.dec.d0;
                sharpPD = ops.dec.sharpPD;
            else
                error('bct:manifold:operator:gradient:MissingOperators', ...
                    'Cached operators do not contain d0 and sharpPD');
            end
        else
            % Compute DEC operators
            [~, dec_ops] = bct.manifold.operator.dec(M);
            d0 = dec_ops.d0;
            sharpPD = dec_ops.sharpPD;
        end
        
        numVertices = M.numVertices();
        numFaces = M.numFaces();
    else
        error('bct:manifold:operator:gradient:InvalidInput', ...
            'First argument must be bct.Manifold object when called with 1 argument');
    end
    
elseif nargin == 2
    % Case 2: Two arguments - could be (V, F) or (d0, sharpPD)
    arg1 = meshInput;
    arg2 = varargin{1};
    
    % Check if arguments are V, F (numeric arrays) or d0, sharpPD (sparse matrices)
    if isnumeric(arg1) && isnumeric(arg2) && ~issparse(arg1)
        % Likely V, F
        V = arg1;
        F = arg2;
        
        % Validate dimensions
        if size(V, 2) ~= 3
            error('bct:manifold:operator:gradient:InvalidVertices', ...
                'V must be N×3 array of vertex coordinates');
        end
        if size(F, 2) ~= 3
            error('bct:manifold:operator:gradient:InvalidFaces', ...
                'F must be M×3 array of face indices');
        end
        
        % Compute DEC operators
        [~, dec_ops] = bct.manifold.operator.dec(V, F);
        d0 = dec_ops.d0;
        sharpPD = dec_ops.sharpPD;
        
        numVertices = size(V, 1);
        numFaces = size(F, 1);
    elseif issparse(arg1) && issparse(arg2)
        % Direct operators: d0 and sharpPD
        d0 = arg1;
        sharpPD = arg2;
        
        numVertices = size(d0, 2);  % d0 is [nE × nV]
        numFaces = size(sharpPD, 1) / 2;  % sharpPD is [2*nF × nE]
    else
        error('bct:manifold:operator:gradient:InvalidInput', ...
            'With 2 arguments, provide either (V, F) or (d0, sharpPD)');
    end
    
else
    error('bct:manifold:operator:gradient:InvalidInput', ...
        'Usage: gradient(Manifold) or gradient(V, F) or gradient(d0, sharpPD)');
end

% Compute gradient operator: grad = sharpPD * d0
grad = sharpPD * d0;

% Build header with metadata
header = struct();
header.method = 'DEC';
header.composition = 'sharpPD * d0';
header.domain = 'vertex';
header.codomain = 'face';
header.numVertices = numVertices;
header.numFaces = numFaces;

end
