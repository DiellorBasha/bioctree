function [header, C] = cotan(meshInput, varargin)
%COTAN Cotangents per face (triangle mesh) using halfedge connectivity
%
%   [header, C] = bct.manifold.geometry.face.cotan(M)
%   [header, C] = bct.manifold.geometry.face.cotan(V, F)
%
% Inputs:
%   M - bct.Manifold object
%   OR
%   V - [N×3] vertex coordinates
%   F - [nF×3] face connectivity (triangular mesh)
%
% Outputs:
%   header - Structure containing:
%            .method - 'halfedge'
%            .scaling - 0.5 (FEM convention)
%   C  - [nF×3] cotangent values per face, where:
%        C(:,1) = (1/2)*cot(angle at v1) opposite edge (v2,v3)
%        C(:,2) = (1/2)*cot(angle at v2) opposite edge (v3,v1)
%        C(:,3) = (1/2)*cot(angle at v3) opposite edge (v1,v2)
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
%   % Compute cotangents from Manifold
%   [header, C] = bct.manifold.geometry.face.cotan(M);
%
%   % Compute cotangents from V, F
%   [header, C] = bct.manifold.geometry.face.cotan(V, F);
%
% See also: bct.manifold.topology.halfedge, bct.manifold.operator.stiffness

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:geometry:face:cotan:NoInput', ...
        'At least one input required: cotan(M) or cotan(V, F)');
end

% Check if first argument is Manifold, surfaceMesh, or numeric
if isa(meshInput, 'surfaceMesh')
    % Case: cotan(surfaceMesh) - optimization path
    V = meshInput.Vertices;
    F = meshInput.Faces;
elseif isa(meshInput, 'bct.Manifold')
    % Case: cotan(M)
    V = meshInput.Vertices;
    F = meshInput.Faces;
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    % Case: cotan(V, F)
    V = meshInput;
    F = varargin{1};
    
    % Validate V, F
    if size(V, 2) ~= 3
        error('bct:geometry:face:cotan:InvalidVertices', ...
            'V must be an [N×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:geometry:face:cotan:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:geometry:face:cotan:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:geometry:face:cotan:InvalidFaces', ...
            'F references vertex index %d but V has only %d vertices.', ...
            max(F(:)), size(V, 1));
    end
else
    error('bct:geometry:face:cotan:InvalidInput', ...
        'Input must be cotan(M), cotan(surfaceMesh), or cotan(V, F). Got %s.', class(meshInput));
end

if size(F,2) ~= 3
    error('bct:geometry:face:cotan:NonTriangular', ...
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
  
  % Build header
  header = struct();
  header.method = 'halfedge';
  header.scaling = 0.5;  % FEM convention factor
end
