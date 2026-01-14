function [header, lengths] = lengths(meshInput, options)
%LENGTHS Compute length of each undirected edge.
%
%   [header, lengths] = bct.manifold.geometry.edge.lengths(M)
%   [header, lengths] = bct.manifold.geometry.edge.lengths(V, F)
%   [header, lengths] = bct.manifold.geometry.edge.lengths(__, 'precision', p)
%
% Inputs
%   M : bct.Manifold object
%   OR
%   V, F : Vertices [N×3] and Faces [nF×3] (can be passed as {V, F} cell)
%
% Name-Value Parameters
%   precision : 'double' (default) | 'single'
%
% Outputs
%   header : struct with fields
%     .edgeSource : 'halfedge' | 'topology.edges'
%     .precision  : precision used
%   lengths : [nE × 1] length of each edge in canonical edge list
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
%   [header, L] = bct.manifold.geometry.edge.lengths(M);
%   minEdgeLength = min(L);
%   maxEdgeLength = max(L);
%
% See also: bct.manifold.geometry.edge.weights, bct.manifold.topology.edges

arguments
    meshInput
    options.precision (1,1) string {mustBeMember(options.precision, ...
        ["double", "single"])} = "double"
end

% Normalize input
mesh = bct.manifold.health.internal.normalizeInput(meshInput);
V = mesh.V;
F = mesh.F;

% Validate inputs
if ~mesh.hasV
    error('bct:manifold:geometry:edge:lengths:NoVertices', ...
        'Vertices required to compute edge lengths');
end

if mesh.nF == 0
    lengths = zeros(0, 1, options.precision);
    header = struct('edgeSource', "none", 'precision', options.precision);
    return;
end

% Get canonical edge list
% Prefer halfedge if available (Manifold object)
if isa(meshInput, 'bct.Manifold')
    he = meshInput.halfedge();
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
lengths = sqrt(sum(edgeVec.^2, 2));  % nE × 1

% Convert precision if requested
if options.precision == "single"
    lengths = single(lengths);
end

% Check for degenerate edges (zero or NaN length)
degenerateMask = isnan(lengths) | (lengths == 0);
if any(degenerateMask)
    degenerateIdx = find(degenerateMask);
    error('bct:manifold:geometry:edge:lengths:DegenerateEdges', ...
        '%d edges have zero or NaN length. Sample indices: %s', ...
        length(degenerateIdx), mat2str(degenerateIdx(1:min(5, end))'));
end

% Build header
header = struct( ...
    'edgeSource', edgeSource, ...
    'precision', options.precision ...
);

end
