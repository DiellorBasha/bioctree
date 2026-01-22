function twin = twins(v, to, nV)
%TWINS Compute twin halfedge pointers (opposite halfedges)
%
% Syntax:
%   twin = bct.manifold.topology.twins(v, to, nV)
%
% Inputs:
%   v  - [nH×1] Tail vertex indices
%   to - [nH×1] Head vertex indices
%   nV - Number of vertices
%
% Outputs:
%   twin - [nH×1 uint32] Twin halfedge index (0 if boundary)
%
% Description:
%   For each halfedge h: v->to, finds the opposite halfedge h': to->v.
%   Uses sparse matrix lookup for O(nH) complexity.
%
%   Boundary halfedges (no opposite) have twin=0.
%
%   SAFETY: Detects duplicate directed edges which indicate non-manifold
%   topology or duplicated faces.
%
% See also: bct.manifold.topology.vertices

nH = length(v);

% Safety check: detect duplicate directed edges
ij = [double(v), double(to)];
[~, ~, ic] = unique(ij, 'rows');
counts = accumarray(ic, 1);
if any(counts > 1)
    error('bct:topology:halfedge:twins:DuplicateDirectedEdge', ...
        'Duplicate directed edges detected. Mesh may be non-manifold or contain duplicated faces.');
end

% Build sparse directed-edge lookup: D(tail, head) = halfedge_id
D = sparse(double(v), double(to), 1:nH, nV, nV);

% Find twins: for each halfedge v->to, look up to->v
twin = uint32(full(D(sub2ind([nV, nV], double(to), double(v)))));

% twin=0 indicates boundary (no opposite halfedge found)

end
