function [header, weights] = edgeWeights(M, options)
%EDGEWEIGHTS Compute edge weights for graph algorithms
%
% Syntax:
%   [header, weights] = bct.manifold.geometry.edgeWeights(M)
%   [header, weights] = bct.manifold.geometry.edgeWeights(M, 'Type', 'euclidean')
%
% Inputs:
%   M - bct.Manifold object
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
% See also: bct.manifold.geometry.edgeLengths, bct.manifold.operator.stiffness

arguments
    M (1,1) bct.Manifold
    options.Type (1,1) string {mustBeMember(options.Type, ...
        ["cotangent", "euclidean"])} = "cotangent"
end

% Initialize weights structure
weights = struct();

% Get edges
E = M.Edges;
nE = size(E, 1);

% Compute Euclidean edge lengths (always available)
geom = M.geometry();
weights.euclidean = geom.edgeLengths;

% Compute cotangent weights from stiffness matrix
ops = M.operators();
K = ops.stiffness;

% Extract cotangent weights for each edge
i = E(:,1);
j = E(:,2);
w = -K(sub2ind(size(K), i, j));

% Clamp negative values (numerical safety)
w(w < 0) = 0;
weights.cotangent = w;

% Create header with metadata
header = struct();
header.type = options.Type;
header.numEdges = nE;
header.cotangentRange = [min(weights.cotangent), max(weights.cotangent)];
header.euclideanRange = [min(weights.euclidean), max(weights.euclidean)];

end
