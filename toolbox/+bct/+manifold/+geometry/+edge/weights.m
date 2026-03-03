function [header, weights] = weights(meshInput, varargin)
%WEIGHTS Compute edge weights for graph algorithms
%
% Syntax:
%   [header, weights] = bct.manifold.geometry.edge.weights(M)
%   [header, weights] = bct.manifold.geometry.edge.weights(V, F)
%   [header, weights] = bct.manifold.geometry.edge.weights(..., 'Type', 'euclidean')
%
% Inputs:
%   M - bct.Manifold object
%   OR
%   V - [N×3] vertex coordinates
%   F - [nF×3] face connectivity (1-based)
%
% Name-Value Arguments:
%   Type - 'cotangent' (default) | 'euclidean'
%
% Outputs:
%   header  - Structure with computation metadata
%   weights - Structure with fields:
%             .cotangent - [nE×1] Cotangent weights from stiffness matrix
%             .euclidean - [nE×1] Euclidean edge lengths
%             .dec       - [nE×1] DEC weights (dual/primal edge length ratio)
%
% Description:
%   Computes edge weights suitable for graph-based algorithms (shortest
%   path, distances, etc.). Returns three weight types:
%   
%   - Cotangent weights: Extracted from the stiffness matrix, provide
%     better discrete approximation for spectral methods.
%   
%   - Euclidean weights: Geometric edge lengths.
%   
%   - DEC weights: Ratio of dual to primal edge lengths (ℓ_dual / ℓ_primal).
%     Used for discrete exterior calculus operators, particularly the
%     connection Laplacian in vector field methods.
%
% Notes:
%   - Cotangent weights may have small negative values due to numerical
%     precision; these are clamped to zero
%   - DEC weights handle both |E| and |H| indexing for dual edge lengths
%   - All weight types use the same edge ordering as M.Edges
%
% See also: bct.manifold.geometry.edge.lengths, bct.manifold.operator.stiffness

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:geometry:edge:weights:NoInput', ...
        'At least one input required: weights(M) or weights(V, F)');
end

% Check if first argument is Manifold or numeric
if isa(meshInput, 'bct.Manifold')
    % Case: weights(M, Name=Value...)
    M = meshInput;
    nameValueStart = 1;
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    % Case: weights(V, F, Name=Value...)
    V = meshInput;
    F = varargin{1};
    M = bct.Manifold(V, F);  % Create temporary Manifold
    nameValueStart = 2;
else
    error('bct:geometry:edge:weights:InvalidInput', ...
        'Input must be either weights(M) or weights(V, F). Got %s.', class(meshInput));
end

% Parse Name-Value pairs
p = inputParser;
p.addParameter('Type', 'cotangent', @(x) ismember(x, ["cotangent","euclidean"]));
p.parse(varargin{nameValueStart:end});

% Initialize weights structure
weightsOut = struct();

% Get edges
E = M.Edges;
nE = size(E, 1);

% Compute Euclidean edge lengths (always available)
[~, edgeLengths] = bct.manifold.geometry.edge.lengths(M);
weightsOut.euclidean = edgeLengths;

% Compute cotangent weights from stiffness matrix
if isa(meshInput, 'bct.Manifold')
    % Use Manifold method which caches (returns dataset structure)
    stiffnessData = M.stiffness('variant', 'cotan', 'sign', 'positive', 'symmetrize', true);
    K = stiffnessData.value;
else
    % Compute directly for V,F input
    stiffnessData = bct.manifold.operator.stiffness(M, ...
        'variant', 'cotan', ...
        'sign', 'positive', ...
        'symmetrize', true);
    K = stiffnessData.value;
end

% Extract cotangent weights for each edge
i = E(:,1);
j = E(:,2);
w = -K(sub2ind(size(K), i, j));

% Clamp negative values (numerical safety)
w(w < 0) = 0;
weightsOut.cotangent = w;

% Compute DEC weights (dual/primal edge length ratio)
% Call dual geometry directly to avoid infinite recursion with M.geometry()
dualData = bct.manifold.geometry.dual(M);
ellDualRaw = dualData.edgeLengths.value;

% Handle |H| vs |E| indexing for dual edge lengths
if numel(ellDualRaw) == nE
    % Already |E| indexed
    ellDual = ellDualRaw;
elseif numel(ellDualRaw) > nE
    % Likely |H| indexed - reduce to |E| by averaging over halfedge pairs
    topo = M.topology();
    edgeH = topo.edge.value;
    nH = numel(edgeH);
    
    if numel(ellDualRaw) == nH
        % Confirmed |H| indexed
        ellDual = accumarray(double(edgeH), double(ellDualRaw), [nE 1], @mean, 0);
    else
        error('bct:geometry:edge:weights:UnexpectedDualSize', ...
            'Dual edge lengths size %d does not match |E|=%d or |H|=%d', ...
            numel(ellDualRaw), nE, nH);
    end
else
    error('bct:geometry:edge:weights:InvalidDualSize', ...
        'Dual edge lengths size %d is smaller than |E|=%d', ...
        numel(ellDualRaw), nE);
end

% Compute DEC weights: w_dec = ellDual / ellPrimal
weightsOut.dec = ellDual ./ max(edgeLengths, 1e-12);

% Clamp negative values (should not occur but numerical safety)
if any(weightsOut.dec < -1e-14)
    warning('bct:geometry:edge:weights:NegativeDEC', ...
        'Some DEC weights are negative (unexpected). Clamping to zero.');
end
weightsOut.dec = max(weightsOut.dec, 0);

% Create header with metadata
header = struct();
header.type = char(p.Results.Type);
header.numEdges = nE;
header.cotangentRange = [min(weightsOut.cotangent), max(weightsOut.cotangent)];
header.euclideanRange = [min(weightsOut.euclidean), max(weightsOut.euclidean)];
header.decRange = [min(weightsOut.dec), max(weightsOut.dec)];

weights = weightsOut;

end
