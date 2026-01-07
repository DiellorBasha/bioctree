function [C, he] = cotan(V, F)
%COTAN Cotangents per face (triangle mesh) using bct.manifold.halfedge connectivity.
%
%   C = cotan(V,F)
%   [C,he] = cotangent_bct.manifold.halfedge(V,F)
%
% This matches the *triangle* behavior of gptoolbox cotangent(V,F):
%   - Output C is #F x 3
%   - Columns correspond to edges 23, 31, 12 (i.e., opposite vertices 1,2,3)
%   - Values are (cot(angle))/2  (gptoolbox divides by dblA/4 => cot/2)
%
% Numerically, for each face (v1,v2,v3):
%   C(:,1) = (1/2)*cot(angle at v1)  opposite edge (v2,v3)
%   C(:,2) = (1/2)*cot(angle at v2)  opposite edge (v3,v1)
%   C(:,3) = (1/2)*cot(angle at v3)  opposite edge (v1,v2)

  if size(F,2) ~= 3
    error('cotangent_bct.manifold.halfedge: only triangular faces (#F x 3) are supported.');
  end

  he = bct.manifold.halfedge(V,F);

  % For each bct.manifold.halfedge h = i->j in face, the vertex opposite this edge is:
  %   k = head( next(h) )
  % (Given ordering h12->h23->h31->h12)
  i = he.v;                  % tail
  j = he.to;                 % head
  k = he.to(he.next);        % opposite vertex in that face (triangle's third vertex)

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
  cot_half = 0.5 * cot_full;       % match gptoolbox (/dblA/4 equivalent)

  % Now place into face-local columns matching gptoolbox:
  %   Column 1 corresponds to edge 23 -> bct.manifold.halfedge h23 (v2->v3) = he.fh(:,2)
  %   Column 2 corresponds to edge 31 -> bct.manifold.halfedge h31 (v3->v1) = he.fh(:,3)
  %   Column 3 corresponds to edge 12 -> bct.manifold.halfedge h12 (v1->v2) = he.fh(:,1)
  h12 = he.fh(:,1);
  h23 = he.fh(:,2);
  h31 = he.fh(:,3);

  C = [ cot_half(h23), cot_half(h31), cot_half(h12) ];
end
