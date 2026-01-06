mesh = bct.data.load();
M = bct.manifold.load(mesh);
params = struct('source', 1000, 'kernel', 'heat', 'sigma', 10);
w = bct.brush.patch.spectral(M, params);

w = full(w(:));   % enforce column

% Create inspector and visualize
[inspector, fig] = bct.ui.show(M);
inspector.setScalarField(w);
%%
% Get DEC representation
dec = M.DEC();

% 1. GRADIENT: Scalar field (0-form) → Edge field (1-form)
%    w is [N×1] vertex values, gradient returns [E×1] edge values
a1 = dec.gradient(w);

% 2. DIVERGENCE: Edge field (1-form) → Scalar field (0-form)
%    a1 is [E×1] edge values, divergence returns [N×1] vertex values
div_w = dec.divergence(a1);

% 3. CURL: Edge field (1-form) → Face field (2-form)
%    Use the Curl operator directly
curl_a1 = dec.Curl * a1;  % Returns [F×1] face values

% Or access operators as properties for manual operations:
G = dec.Gradient;    % [E×V] gradient operator
D = dec.Divergence;  % [V×E] divergence operator  
C = dec.Curl;        % [F×E] curl operator

%%
dec = M.DEC();

% Now returns [F×3] face vectors (via bct.dec.gradient)
gradF = dec.gradient(w);  

% For raw 1-form [E×1], use property:
a1 = dec.Gradient * w;

% Visualize at face centroids
COM = (M.Vertices(M.Faces(:,1),:) + M.Vertices(M.Faces(:,2),:) + M.Vertices(M.Faces(:,3),:)) / 3;
plotGrad = gradF ./ vecnorm(gradF, 2, 2);
ssf = 50;
inspector.showVectorField(COM(1:ssf:end,:), ...
    plotGrad(1:ssf:end,1), plotGrad(1:ssf:end,2), plotGrad(1:ssf:end,3), ...
    'Color', 'cyan', 'LineWidth', 2);
%%
% Get a specific eigenvector (e.g., the 10th)
% Direct eigensolve method
[Psi, Lambda] = M.eigensolve(100);

% Access specific eigenvector
eigIdx = 10;
eigenvector = Psi(:, eigIdx);  % [N×1]
eigenvalue = Lambda(eigIdx);
%%
% Compute gradient [F×3] face vectors
gradF = dec.gradient(w);

% Compute divergence of gradient (Laplacian of w)
% divergence accepts [F×3] vector fields and returns [V×1] scalar
divGradW = dec.divergence(gradF);  % Returns [V×1] vertex-based scalar
inspector.setScalarField(divGradW);

% Visualize divergence as a scalar field on the mesh
inspector.showSignal(divGradW);
%%
% 1. Compute gradient of scalar signal w
% 1. Compute gradient of scalar signal w
gradW = dec.gradient(w);  % [F×3] face-based vector field

% 2. Perform Helmholtz-Hodge decomposition via DECLab backend
[divW, rotW, harmW, scalarP, vectorP] = ...
    dec.Backend.helmholtzHodgeDecomposition(gradW, 1e-8);

% 3. Get face centroids for vector field visualization
faceCentroids = M.centroids();  % [F×3]

% 4. Visualize each component

% Full gradient vector field
figure;
inspector = bct.ui.manifold.Inspector(M);
inspector.showVectorField(faceCentroids, gradW(:,1), gradW(:,2), gradW(:,3));
title('Full Gradient Field');

% Curl-free (irrotational) part with scalar potential

inspector.setScalarField(scalarP);  % [V×1] scalar potential on vertices
inspector.showVectorField(faceCentroids, divW(:,1), divW(:,2), divW(:,3));
title('Irrotational (Curl-Free) Part and Scalar Potential');

% Divergence-free (rotational) part
inspector.showVectorField(faceCentroids, rotW(:,1), rotW(:,2), rotW(:,3));
title('Rotational (Divergence-Free) Part');

% Harmonic part (should be ~0 for closed surfaces like cortex)
inspector.showVectorField(faceCentroids, harmW(:,1), harmW(:,2), harmW(:,3));
