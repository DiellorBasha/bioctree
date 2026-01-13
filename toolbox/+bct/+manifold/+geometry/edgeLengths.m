function [header, edgeLengths] = edgeLengths(meshOrManifold, options)
%EDGELENGTHS Compute length of each undirected edge.
%
%   [header, edgeLengths] = bct.manifold.geometry.edgeLengths(meshOrManifold)
%   [header, edgeLengths] = bct.manifold.geometry.edgeLengths(__, 'precision', p)
%
% Inputs
%   meshOrManifold : bct.Manifold object or {V, F} cell array
%
% Name-Value Parameters
%   precision : 'double' (default) | 'single'
%
% Outputs
%   header : struct with fields
%     .edgeSource : 'halfedge' | 'topology.edges'
%     .precision  : precision used
%   edgeLengths : [nE × 1] length of each edge in canonical edge list
%
% Edge Indexing
%   Uses canonical edge list from:
%   - Manifold.halfedge().E (preferred)
%   - bct.manifold.topology.edges(F) (fallback)
%
% Algorithm
%   For each edge (i, j):
%     length = ||V(i,:) - V(j,:)||
%
% Example
%   [header, L] = bct.manifold.geometry.edgeLengths(M);
%   minEdgeLength = min(L);
%   maxEdgeLength = max(L);
%
% See also: bct.manifold.geometry, bct.manifold.topology.edges

arguments
    meshOrManifold
    options.precision (1,1) string {mustBeMember(options.precision, ...
        ["double", "single"])} = "double"
end

% Normalize input
mesh = bct.manifold.health.internal.normalizeInput(meshOrManifold);
V = mesh.V;
F = mesh.F;

% Validate inputs
if ~mesh.hasV
    error('bct:manifold:geometry:edgeLengths:NoVertices', ...
        'Vertices required to compute edge lengths');
end

if mesh.nF == 0
    edgeLengths = zeros(0, 1, options.precision);
    header = struct('edgeSource', "none", 'precision', options.precision);
    return;
end

% Get canonical edge list
% Prefer halfedge if available (Manifold object)
if isa(meshOrManifold, 'bct.Manifold')
    he = meshOrManifold.halfedge();
    E = he.E;
    edgeSource = "halfedge";
else
    % Use topology.edges as fallback
    E = bct.manifold.topology.edges(F);
    edgeSource = "topology.edges";
end

nE = size(E, 1);

% Compute edge lengths (vectorized)
v1 = V(E(:,1), :);  % nE × 3
v2 = V(E(:,2), :);  % nE × 3

edgeVec = v2 - v1;  % nE × 3
edgeLengths = sqrt(sum(edgeVec.^2, 2));  % nE × 1

% Convert precision if requested
if options.precision == "single"
    edgeLengths = single(edgeLengths);
end

% Check for degenerate edges (zero or NaN length)
degenerateMask = isnan(edgeLengths) | (edgeLengths == 0);
if any(degenerateMask)
    degenerateIdx = find(degenerateMask);
    error('bct:manifold:geometry:edgeLengths:DegenerateEdges', ...
        '%d edges have zero or NaN length. Sample indices: %s', ...
        length(degenerateIdx), mat2str(degenerateIdx(1:min(5, end))'));
end

% Build header
header = struct( ...
    'edgeSource', edgeSource, ...
    'precision', options.precision ...
);

end
