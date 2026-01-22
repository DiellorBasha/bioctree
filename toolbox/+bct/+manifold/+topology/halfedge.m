function he = halfedge(V, F)
%HALFEDGE Build halfedge connectivity structure (convenience aggregator)
%
% Syntax:
%   he = bct.manifold.topology.halfedge(V, F)
%
% Inputs:
%   V - [nV×3] Vertex coordinates
%   F - [nF×3] Face connectivity (1-indexed)
%
% Outputs:
%   he - Structure with fields (for convenience, not schema-compliant):
%     .numVertices     - Number of vertices
%     .numFaces        - Number of faces
%     .numHalfedges    - Number of halfedges
%     .tailVertex      - [nH×1 uint32] Tail vertex indices
%     .headVertex      - [nH×1 uint32] Head vertex indices
%     .face            - [nH×1 uint32] Incident face indices
%     .next            - [nH×1 uint32] Next halfedge (CCW)
%     .prev            - [nH×1 uint32] Previous halfedge (CCW)
%     .twin            - [nH×1 uint32] Twin halfedge (0 if boundary)
%     .edge            - [nH×1 uint32] Undirected edge indices
%     .isBoundary      - [nH×1 logical] Boundary flags
%     .edgeList        - [nE×2 uint32] Undirected edge list
%     .faceHalfedges   - [nF×3 uint32] Halfedge indices per face
%     .faceNeighbors   - [nF×3 int32] Adjacent face indices
%     .neighborEdge    - [nF×3 uint8] Local edge index in neighbors
%
% Description:
%   Convenience aggregator that computes halfedge connectivity structure
%   using modular subfunctions. This is a standalone halfedge structure
%   for use in algorithms that need only halfedge navigation.
%
%   For schema-compliant topology (includes halfedge + edges + adjacency),
%   use bct.manifold.topology() instead.
%
%   Halfedge convention:
%     - For face [v1 v2 v3]: h12 (v1->v2), h23 (v2->v3), h31 (v3->v1)
%     - CCW circulation: h12->h23->h31->h12
%     - Boundary halfedges have twin=0
%
% Examples:
%   % Build halfedge structure
%   M = bct.Manifold(V, F);
%   he = bct.manifold.topology.halfedge(M.Vertices, M.Faces);
%   
%   % Navigate around a face
%   h = he.faceHalfedges(1, 1);  % First halfedge of face 1
%   h_next = he.next(h);
%   h_prev = he.prev(h);
%   
%   % Find twin across edge
%   h_twin = he.twin(h);
%   if h_twin == 0
%       disp('Boundary edge');
%   end
%
% See also: bct.manifold.topology, bct.manifold.topology.edges

if size(F, 2) ~= 3
    error('bct:topology:halfedge:InvalidInput', ...
        'Only triangular faces (nF×3) are supported');
end

nV = size(V, 1);
nF = size(F, 1);
nH = 3 * nF;

% Initialize output structure (not schema-compliant, for convenience)
he = struct();

% Mesh size metadata
he.numVertices = nV;
he.numFaces = nF;
he.numHalfedges = nH;

% Compute datasets using modular functions
% Tail and head vertices
[he.tailVertex, he.headVertex] = bct.manifold.topology.vertices(F);

% Incident face indices
he.face = bct.manifold.topology.faces(F);

% Next/prev circulation
[he.next, he.prev] = bct.manifold.topology.circulation(F);

% Twin halfedges
he.twin = bct.manifold.topology.twins(he.tailVertex, he.headVertex, nV);

% Edge indices
he.edge = bct.manifold.topology.edgeIndices(F);

% Boundary flags
he.isBoundary = (he.twin == 0);

% Undirected edge list
he.edgeList = bct.manifold.topology.edges(F);

% Face halfedges
he.faceHalfedges = bct.manifold.topology.faceHalfedges(F);

% Face neighbors
[he.faceNeighbors, he.neighborEdge] = bct.manifold.topology.neighbors(...
    F, he.faceHalfedges, he.twin, he.face);

end
