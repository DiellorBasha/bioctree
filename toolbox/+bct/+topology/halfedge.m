function he = halfedge(V, F)
%HALFEDGE Build a halfedge connectivity structure for a triangular mesh.
%
%   he = halfedge(V,F)
%
% Inputs
%   V : #V x 3 (or #V x dim) vertex coordinates
%   F : #F x 3 triangle vertex indices (1-based)
%
% Output (struct) fields
%   he.nV, he.nF, he.nH
%   he.v        : #H x 1 tail vertex of halfedge
%   he.to       : #H x 1 head vertex of halfedge
%   he.face     : #H x 1 incident face id (1..#F)
%   he.next     : #H x 1 next halfedge around the face (CCW)
%   he.prev     : #H x 1 prev halfedge around the face (CCW)
%   he.twin     : #H x 1 opposite halfedge across undirected edge (0 if boundary)
%   he.edge     : #H x 1 undirected edge id (1..#E)
%   he.isBoundary : #H x 1 logical boundary flag (twin==0)
%   he.E        : #E x 2 list of undirected edges (sorted vertex ids)
%   he.fh       : #F x 3 halfedge ids per face in order [h12 h23 h31]
%
% Convention:
%   For each face f = [v1 v2 v3], we create three halfedges:
%     h12: v1 -> v2
%     h23: v2 -> v3
%     h31: v3 -> v1
%   and next pointers: h12->h23->h31->h12.

  %#ok<*NASGU>

  if size(F,2) ~= 3
    error('halfedge: only triangular faces (#F x 3) are supported.');
  end
  nV = size(V,1);
  nF = size(F,1);
  nH = 3*nF;

  % Halfedges per face in fixed indexing blocks:
  % h12 = (1:nF)', h23 = (1:nF)'+nF, h31 = (1:nF)'+2nF
  h12 = (1:nF)';
  h23 = h12 + nF;
  h31 = h23 + nF;

  % Tail/head vertices
  v_tail = [F(:,1); F(:,2); F(:,3)];
  v_head = [F(:,2); F(:,3); F(:,1)];

  % Face ids
  face_id = [ (1:nF)'; (1:nF)'; (1:nF)' ];

  % Next/prev around face (CCW)
  nxt = zeros(nH,1);
  prv = zeros(nH,1);
  nxt(h12) = h23;  nxt(h23) = h31;  nxt(h31) = h12;
  prv(h12) = h31;  prv(h23) = h12;  prv(h31) = h23;

  % Twin lookup via sparse directed-edge matrix D(tail, head) = halfedge_id.
  % For a valid manifold triangle mesh, each directed edge appears at most once.
  D = sparse(v_tail, v_head, (1:nH)', nV, nV);
  twin = full(D(sub2ind([nV nV], v_head, v_tail))); % D(head,tail)
  % twin is 0 for boundary halfedges (no opposite direction found)

  % Undirected edges: assign an edge id to each halfedge by unique(min,max).
  a = min(v_tail, v_head);
  b = max(v_tail, v_head);
  [E, ~, edge_id] = unique([a b], 'rows', 'stable');

  he = struct();
  he.nV = nV;
  he.nF = nF;
  he.nH = nH;

  he.v = v_tail;
  he.to = v_head;
  he.face = face_id;

  he.next = nxt;
  he.prev = prv;
  he.twin = twin;

  he.edge = edge_id;
  he.E = E;

  he.isBoundary = (twin == 0);

  % Halfedge ids per face [h12 h23 h31]
  he.fh = [h12, h23, h31];
end
