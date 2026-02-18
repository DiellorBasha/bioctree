function [header, dTheta_h] = transport(M, options)
%TRANSPORT Compute no-rotation parallel transport across edges
%
%   [header, dTheta_h] = bct.manifold.geometry.face.transport(M)
%   [header, dTheta_h] = bct.manifold.geometry.face.transport(M, 'precision', p)
%   [header, dTheta_h] = bct.manifold.geometry.face.transport(M, 'tangent1', t1, 'tangent2', t2)
%
% Inputs
%   M : bct.Manifold object (requires topology and face tangent frames)
%
% Name-Value Parameters
%   precision : 'double' (default) | 'single'
%   tangent1  : [nF×3] Pre-computed first tangent vectors (optional, avoids recomputation)
%   tangent2  : [nF×3] Pre-computed second tangent vectors (optional, avoids recomputation)
%
% Outputs
%   header   : struct with metadata
%     .name         : 'transport'
%     .schema       : 'bct.manifold.geometry.face.transport@1.0.0'
%     .description  : Description of transport angles
%     .shape        : [nH, 1]
%     .dtype        : precision used
%     .units        : 'radians'
%     .support      : 'halfedge'
%     .formula      : Transport formula
%   dTheta_h : [nH × 1] rotation angle when transporting direction across edge
%
% Description
%   Computes the rotation angle change when parallel-transporting a 
%   direction from one face to an adjacent face across a shared edge.
%   This is the discrete analog of the connection 1-form for parallel
%   transport on a Riemannian manifold.
%
%   For each halfedge h with tail→head edge vector e:
%   - Let f_i = face of halfedge h
%   - Let f_j = face of twin halfedge (across edge)
%   - Compute theta_i = atan2(<e, t2_i>, <e, t1_i>) in face i's frame
%   - Compute theta_j = atan2(<e, t2_j>, <e, t1_j>) in face j's frame
%   - dTheta_h = -theta_i + theta_j
%
%   If a direction has angle alpha_i in face i, after transporting across
%   the edge to face j, it has angle alpha_j = alpha_i + dTheta_h in face j.
%
% Algorithm
%   Based on geometry-processing-js transportNoRotation function.
%   Uses face tangent frames (t1, t2) to measure the angle of the edge 
%   vector in each face's coordinate system.
%
% Example
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   [header, dTheta] = bct.manifold.geometry.face.transport(M);
%   
%   % Use in direction field transport
%   topo = M.topology();
%   geom = M.geometry();
%   alpha_i = rand(size(M.Faces, 1), 1) * 2*pi;  % Random angles in each face
%   % To transport from face i to face j across halfedge h:
%   % alpha_j = alpha_i + dTheta(h)
%
% See also: bct.manifold.connection.trivial, bct.manifold.geometry.face

arguments
    M (1,1) bct.Manifold
    options.precision (1,1) string {mustBeMember(options.precision, ...
        ["double", "single"])} = "double"
    options.tangent1 (:,3) double = []
    options.tangent2 (:,3) double = []
end

% Get topology (halfedge connectivity)
topo = M.topology();

tail  = topo.tailVertex.value;   % |H| x 1
head  = topo.headVertex.value;   % |H| x 1
faceH = topo.face.value;         % |H| x 1
twinH = topo.twin.value;         % |H| x 1

% Get face tangent bases
if isempty(options.tangent1) || isempty(options.tangent2)
    % Compute tangent frames (only if not provided)
    tempFaceGeom = bct.manifold.geometry.face(M, 'precision', options.precision);
    t1 = tempFaceGeom.tangent1.value;        % |F| x 3
    t2 = tempFaceGeom.tangent2.value;        % |F| x 3
else
    % Use pre-computed tangent frames (avoids circular dependency)
    t1 = options.tangent1;
    t2 = options.tangent2;
end

% Vertex positions
V = M.Vertices;                           % |V| x 3

nH = numel(tail);
nF = size(t1, 1);

% ============================================================
% Compute dTheta_h for each halfedge
% dTheta_h = -theta_i(edge) + theta_j(edge)
% where theta_f(edge) = atan2( <e,t2_f>, <e,t1_f> )
% ============================================================

% Edge vectors per halfedge (tail -> head)
E = V(head, :) - V(tail, :);              % |H| x 3

fi = faceH;                                % face on halfedge h
fj = faceH(twinH);                         % neighboring face across edge (via twin)

% Valid interior halfedges: both faces exist
% (For closed manifolds, all should be valid; for open, boundary halfedges excluded)
valid = (fj > 0) & (fi > 0) & (twinH > 0);

% Angle of edge direction in face-i tangent coordinates
ei = E(valid, :);
fi_v = fi(valid);

% Project edge onto face-i tangent basis: theta_i = atan2(<e, t2_i>, <e, t1_i>)
dot_t1_i = sum(ei .* t1(fi_v, :), 2);
dot_t2_i = sum(ei .* t2(fi_v, :), 2);
thetaI = atan2(dot_t2_i, dot_t1_i);

% Same geometric edge direction expressed in face-j tangent coordinates
fj_v = fj(valid);
dot_t1_j = sum(ei .* t1(fj_v, :), 2);
dot_t2_j = sum(ei .* t2(fj_v, :), 2);
thetaJ = atan2(dot_t2_j, dot_t1_j);

% Compute rotation angle change
dTheta_h = zeros(nH, 1, options.precision);
dTheta_h(valid) = -thetaI + thetaJ;        % JS: alpha_j = alpha_i + dTheta

% Wrap to (-pi, pi] for numerical stability
dTheta_h = mod(dTheta_h + pi, 2*pi) - pi;

% Build header
header = struct();
header.name = 'transport';
header.path = 'geometry/face/transport';
header.schema = 'bct.manifold.geometry.face.transport@1.0.0';
header.description = 'No-rotation parallel transport angle change across edges';
header.shape = [nH, 1];
header.dtype = char(options.precision);
header.units = 'radians';
header.support = 'halfedge';
header.formula = 'dTheta_h = -theta_i(edge) + theta_j(edge)';
header.computedBy = 'bct.manifold.geometry.face.transport';
header.nHalfedges = nH;
header.nFaces = nF;
header.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

end
