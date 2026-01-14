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
%
% Description:
%   Computes edge weights suitable for graph-based algorithms (shortest
%   path, distances, etc.). Returns both cotangent and Euclidean weights.
%   
%   Cotangent weights are extracted from the stiffness matrix and provide
%   better discrete approximation for spectral methods.
%   
%   Euclidean weights are geometric edge lengths.
%
% Notes:
%   - Cotangent weights may have small negative values due to numerical
%     precision; these are clamped to zero
%   - Both weight types use the same edge ordering as M.Edges
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
    % Use Manifold method which caches (returns [header, K])
    [~, K] = M.stiffness('variant', 'cotan', 'sign', 'positive', 'symmetrize', true);
else
    % Compute directly for V,F input
    [~, K] = bct.manifold.operator.stiffness(M, ...
        'variant', 'cotan', ...
        'sign', 'positive', ...
        'symmetrize', true);
end

% Extract cotangent weights for each edge
i = E(:,1);
j = E(:,2);
w = -K(sub2ind(size(K), i, j));

% Clamp negative values (numerical safety)
w(w < 0) = 0;
weightsOut.cotangent = w;

% Create header with metadata
header = struct();
header.type = char(p.Results.Type);
header.numEdges = nE;
header.cotangentRange = [min(weightsOut.cotangent), max(weightsOut.cotangent)];
header.euclideanRange = [min(weightsOut.euclidean), max(weightsOut.euclidean)];

weights = weightsOut;

end
