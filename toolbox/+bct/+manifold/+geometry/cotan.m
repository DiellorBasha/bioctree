function [C, he] = cotan(V, F)
%COTAN Cotangents per face (triangle mesh) using halfedge connectivity
%
%   C = bct.manifold.geometry.cotan(V, F)
%   [C, he] = bct.manifold.geometry.cotan(V, F)
%
% Inputs:
%   V - [N×3] vertex coordinates
%   F - [M×3] face connectivity (triangular mesh)
%
% Outputs:
%   C  - [M×3] cotangent values per face, where:
%        C(:,1) = (1/2)*cot(angle at v1) opposite edge (v2,v3)
%        C(:,2) = (1/2)*cot(angle at v2) opposite edge (v3,v1)
%        C(:,3) = (1/2)*cot(angle at v3) opposite edge (v1,v2)
%   he - halfedge structure (optional, from bct.manifold.topology.halfedge)
%
% Description:
%   Computes cotangent values at each face vertex, matching gptoolbox
%   cotangent(V,F) behavior. The cotangents are scaled by 1/2 to match
%   the finite element discretization convention.
%
%   Output C is [#F × 3] where columns correspond to edges 23, 31, 12
%   (opposite vertices 1, 2, 3 respectively).
%
% Examples:
%   % Compute cotangents
%   [V, F] = meshgrid_to_mesh(X, Y, Z);
%   C = bct.manifold.geometry.cotan(V, F);
%
%   % Get halfedge structure too
%   [C, he] = bct.manifold.geometry.cotan(V, F);
%
% See also: bct.manifold.topology.halfedge, bct.manifold.cotmatrix

  if size(F,2) ~= 3
    error('bct:geometry:cotan', ...
        'Only triangular faces (#F x 3) are supported.');
  end

  he = bct.manifold.topology.halfedge(V, F);

  % For each halfedge h = i->j in face, the vertex opposite this edge is:
  %   k = head(next(h))
  % (Given ordering h12->h23->h31->h12)
  i = he.v;                  % tail vertex
  j = he.to;                 % head vertex
  k = he.to(he.next);        % opposite vertex in triangle

  % Vectors from k to i and k to j
  ui = V(i,:) - V(k,:);
  uj = V(j,:) - V(k,:);

  % cot(angle at k) = dot(ui,uj) / ||cross(ui,uj)||
  % cross norm equals 2*Area = dblA
  dotu = sum(ui .* uj, 2);
  cr = cross(ui, uj, 2);
  dblA = sqrt(sum(cr.^2, 2));

  % Robustness for degenerate triangles
  denom = dblA;
  denom(denom == 0) = eps;

  cot_full = dotu ./ denom;        % cot(angle at k)
  cot_half = 0.5 * cot_full;       % match gptoolbox convention

  % Place into face-local columns matching gptoolbox:
  %   Column 1 corresponds to edge 23 -> halfedge h23 (v2->v3) = he.fh(:,2)
  %   Column 2 corresponds to edge 31 -> halfedge h31 (v3->v1) = he.fh(:,3)
  %   Column 3 corresponds to edge 12 -> halfedge h12 (v1->v2) = he.fh(:,1)
  h12 = he.fh(:,1);
  h23 = he.fh(:,2);
  h31 = he.fh(:,3);

  C = [ cot_half(h23), cot_half(h31), cot_half(h12) ];
end
