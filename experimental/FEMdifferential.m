bioctree_start
fs6 = bct_fsaverage('lh', 'saved');
%% 

Manifold=fs6.Manifold;
% Gaussian patch with 20mm width
params.source = 1000;
params.sigma = 4;  % Gaussian width (standard deviation)
params.metric = "geometry";  % optional

w = bct.brush.apply('patch_gaussian', Manifold, params);
TR = triangulation(double(Manifold.Faces), Manifold.Vertices);

V = TR.Points;        % N × 3
F = TR.ConnectivityList;  % M × 3

w = w(:);             % N × 1 scalar field on vertices
faceNormal = TR.faceNormal;
dblA = vecnorm(faceNormal,2,2);
faceNormal = faceNormal ./ dblA;   % unit normal

grad_phi1 = cross(faceNormal, v3 - v2, 2) ./ dblA;
grad_phi2 = cross(faceNormal, v1 - v3, 2) ./ dblA;
grad_phi3 = cross(faceNormal, v2 - v1, 2) ./ dblA;
grad_w = ...
    grad_phi1 .* w(F(:,1)) + ...
    grad_phi2 .* w(F(:,2)) + ...
    grad_phi3 .* w(F(:,3));

%% Divergence
% Flux edge vectors opposite vertices
e1 = v3 - v2;
e2 = v1 - v3;
e3 = v2 - v1;
n1 = cross(faceNormal, e1, 2);
n2 = cross(faceNormal, e2, 2);
n3 = cross(faceNormal, e3, 2);
flux1 = dot(grad_w, n1, 2) * 0.5;
flux2 = dot(grad_w, n2, 2) * 0.5;
flux3 = dot(grad_w, n3, 2) * 0.5;

div = zeros(size(V,1),1);

for f = 1:size(F,1)
    div(F(f,1)) = div(F(f,1)) + flux1(f);
    div(F(f,2)) = div(F(f,2)) + flux2(f);
    div(F(f,3)) = div(F(f,3)) + flux3(f);
end

Adual = full(sum(fs6.Manifold.MassMatrix,2));
div = div ./ Adual;
%% Advection
%Step 3.1 — Interpolate vector field to vertices (optional)

%For vertex-based advection:

grad_w_vtx = zeros(size(V));

FA = TR.vertexAttachments;
for i = 1:size(V,1)
    faces = FA{i};
    grad_w_vtx(i,:) = mean(grad_w(faces,:),1);
end

%Step 3.2 — Semi-Lagrangian advection step

%For each vertex:

dt = 0.5;  % time step

x0 = V;                         % current positions
x1 = x0 - dt * grad_w_vtx;      % backtraced positions

%%
%Step 3.3 — Sample w at backtraced positions
neighbors = TR.neighbors;   % nF × 3 (face neighbors across edges)
[face, bc, pos] = stepFaceWalk(TR, v_f, face, bc, dt);
streamline = integrateStreamlineFaceWalk(TR, v_f, face0, bc0, dt, nSteps);
%Use triangulation queries:
%OPTION B — Project + nearest-face (practical, fast)

%This is the recommended compromise for MEG-scale analysis.

%B1. Vertex-normal projection
VN = TR.vertexNormal;   % N × 3

%%
ti = TR.pointLocation(x1);
bc = TR.cartesianToBarycentric(ti, x1);

w_new = nan(size(w));

valid = ~isnan(ti);
w_new(valid) = ...
    bc(valid,1).*w(F(ti(valid),1)) + ...
    bc(valid,2).*w(F(ti(valid),2)) + ...
    bc(valid,3).*w(F(ti(valid),3));

%%
%4. Phase velocity field (from phase gradient)

%If w = phase(x,t):

omega = temporal_frequency;   % scalar or per-vertex


%Then phase velocity (per face):

v_phase = -omega * grad_w ./ (vecnorm(grad_w,2,2).^2 + eps);


%Tangent vector field

%Direction of propagation

%Units: mm/s if geometry is in mm

%% LIC
%5. Line Integral Convolution (LIC) on the surface

%LIC requires streamline integration.

%Step 5.1 — Seed points (face incenters)
seedPts = incenter(TR);   % M × 3

%Step 5.2 — Streamline integration (Euler step)
nSteps = 20;
stepSize = 0.5;

stream = seedPts;

for k = 1:nSteps
    ti = TR.pointLocation(stream);
    bc = TR.cartesianToBarycentric(ti, stream);

    v = zeros(size(stream));

    valid = ~isnan(ti);
    v(valid,:) = grad_w(ti(valid),:);

    stream(valid,:) = stream(valid,:) + stepSize * v(valid,:);
end

%Step 5.3 — Convolution

%You now convolve noise along these streamlines. Conceptually:

%LIC_value(face) = sum( noise(sampled points along streamline) )


%This produces a texture aligned with flow, ideal for visualizing:
%traveling waves
%phase fronts
%transport pathways

%%
V = fs6.Manifold.Vertices;
F = fs6.Manifold.Faces;
TR = triangulation(double(Manifold.Faces), Manifold.Vertices);
V = TR.Points;
F = TR.ConnectivityList;

% Edge connectivity list
E = edges(TR);
% Calculate centroid of faces
COM = cat( 3, V(F(:,1), :), V(F(:,2), :), V(F(:,3), :) );
COM = mean( COM, 3 );

% Calculate edge midpoints
Emp = ( V(E(:,2), :) + V(E(:,1),:) ) ./ 2;

%--------------------------------------------------------------------------
% Generate Discrete Exterior Calculus Object
%--------------------------------------------------------------------------
% profile on
DEC = DiscreteExteriorCalculus( F, V );
 trisurf(TR);
 axis equal
syms theta phi x y z
assume( theta, 'real' ); assume( phi, 'real' );
assume( x, 'real'); assume( y, 'real'); assume( z, 'real' );
% The equation of the surface
R = [ sin(theta) * cos(phi); sin(theta) * sin(phi); cos(theta) ];

% The tangent vectors
Etheta = [ gradient(R(1), theta); gradient(R(2), theta); gradient(R(3), theta) ];
Ephi = [ gradient(R(1), phi); gradient(R(2), phi); gradient(R(3), phi) ];
% The unit normal vector
% N = cross(Etheta, Ephi);
% N = simplify( N ./ sqrt( sum( N.^2 ) ) );
N = R;

% The metric tensor
g = simplify( [ dot(Etheta, Etheta), dot(Etheta, Ephi); ...
    dot(Ephi, Etheta), dot(Ephi, Ephi) ] );
% The dual basis vectors
dtheta = Etheta;
dphi = Ephi ./ sin(theta).^2;

%==========================================================================
% Generate a Scalar Field on the Surface
%==========================================================================

%--------------------------------------------------------------------------
% Enter your favorite scalar field in Cartesian or spherical coordinates

% S = 1 / (1 + (x + 1/sqrt(2))^2 + z^2 ); DIVERGENT LAPLACIAN AT THETA = 0
S = (3/32) .* sqrt(77/pi) * sin(theta)^5 * cos(5*phi); % A spherical harmonic
% Transform to spherical coordinates if necessary
S = simplify(subs( S, [x y z], [R(1) R(2) R(3)] ));

% Calculate the gradient of the scalar field
gradS = simplify( gradient(S, theta) * Etheta + ...
    ( gradient(S, phi) / sin(theta) ) * ( Ephi / sin(theta) ) );

% Calculate the Laplacian of the scalar field
lapS = simplify( ...
    gradient( sin(theta) * gradient(S, theta), theta ) / sin(theta) + ...
    gradient( gradient( S, phi ), phi ) / sin(theta)^2 );

%==========================================================================
% Generate a Vector Field on the Surface
%==========================================================================

%--------------------------------------------------------------------------
% Enter your favorite vector field in Cartesian or spherical coordinates

U = [ x * z * ( z^2 - 1/4 ) - y; ...
    y * z * ( z^2 - 1/4 ) + x; ...
    -( x^2 + y^2 ) * ( z^2 - 1/4 ) ];