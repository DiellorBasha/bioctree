function gradU = faceGradient(M, u)
%FACEGRADIENT Compute face gradient using halfedge cross-normal accumulation
%
% Syntax:
%   gradU = bct.field.generate.faceGradient(M, u)
%
% Inputs:
%   M - bct.Manifold object
%   u - [nV×1] scalar field on vertices
%
% Outputs:
%   gradU - [nF×3] gradient vectors on faces in 3D world coordinates
%
% Description:
%   Computes the gradient of a vertex scalar field using the geometric
%   formula via halfedge cross-normal accumulation:
%   
%     gradU_f = (1/(2*A_f)) * Σ_{h in face} (n_f × e_h) * u(tail(h))
%   
%   where:
%     - A_f is the face area
%     - n_f is the face normal
%     - e_h is the edge vector of halfedge h
%     - tail(h) is the tail vertex of halfedge h
%   
%   This is the same method used in the heat distance solver for
%   computing gradients on faces. It produces 3D gradient vectors
%   tangent to the surface.
%
%   This is geometrically equivalent to but numerically more stable than
%   the DEC gradient (sharpPD * d0) for certain applications.
%
% Examples:
%   % Compute gradient of heat distance field
%   M = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
%   solver = M.solvers();
%   dA = solver.heatDistance.value(6653);
%   dP = solver.heatDistance.value(978);
%   
%   u = dA - dP;  % Signed coordinate
%   gradU = bct.field.generate.faceGradient(M, u);
%   
%   % Normalize for direction field
%   gradU_norm = gradU ./ max(vecnorm(gradU, 2, 2), 1e-12);
%
% See also: bct.manifold.solve.heatDistance, bct.manifold.operator.gradient

% Input validation
arguments
    M (1,1) {mustBeA(M, 'bct.Manifold')}
    u (:,1) double
end

nV = M.numVertices();
nF = M.numFaces();

% Validate u dimensions
if length(u) ~= nV
    error('bct:field:generate:faceGradient:SizeMismatch', ...
        'Scalar field u must have length %d (number of vertices), got %d', ...
        nV, length(u));
end

% Get topology
topo = M.topology();
tail = topo.tailVertex.value;    % [nH×1]
head = topo.headVertex.value;    % [nH×1]
faceH = topo.face.value;         % [nH×1]

% Get geometry
geom = M.geometry();
Nf = geom.face.normals.value;    % [nF×3] face normals
Af = geom.face.areas.value;      % [nF×1] face areas

% Compute halfedge edge vectors
V = M.Vertices;
E = V(head, :) - V(tail, :);     % [nH×3] edge vectors

% Expand face normals to halfedges
Nh = Nf(faceH, :);               % [nH×3] normal per halfedge

% Validate halfedge arrays
nH = length(tail);
if size(E, 1) ~= nH || size(Nh, 1) ~= nH
    error('bct:field:generate:faceGradient:InvalidTopology', ...
        'Halfedge arrays have inconsistent dimensions');
end

% Step 1: Lookup scalar values at tail vertices
u_tail = u(tail);  % [nH×1]

% Step 2: Compute cross product: n_f × e_h for each halfedge
C = cross(Nh, E, 2);  % [nH×3]

% Step 3: Weight by scalar values
Cx = C(:,1) .* u_tail;
Cy = C(:,2) .* u_tail;
Cz = C(:,3) .* u_tail;

% Step 4: Accumulate contributions to faces
% Each face receives contributions from its 3 halfedges
gradUx = accumarray(faceH, Cx, [nF 1], @sum, 0);
gradUy = accumarray(faceH, Cy, [nF 1], @sum, 0);
gradUz = accumarray(faceH, Cz, [nF 1], @sum, 0);

% Step 5: Divide by 2*Area to get gradient
gradU = [gradUx, gradUy, gradUz] ./ (2 * Af);  % [nF×3]

end
