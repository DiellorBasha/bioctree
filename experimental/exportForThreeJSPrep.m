%% make_eulerian_export_bunny.m
% End-to-end: load mesh -> compute heat field -> DEC gradient -> outward flow -> export for Three.js/WebGPU

clear; clc;

% -----------------------------
% Inputs
% -----------------------------
mPath = 'toolbox\+bct\+data\assets\bunny.obj';
outBase = fullfile('C:\CodingProjects\Bioctreeapp\data', 'particle_vis_eulerian');  % writes .json + .bin

vD = 100;      % source vertex index for heat (choose any valid vertex)
tHeat = 0.1;   % diffusion time parameter for heat field

% -----------------------------
% Load Manifold + geometry/topology
% -----------------------------
M = bct.Manifold.read(mPath);

fg = M.faceGeometry;
vg = M.vertexGeometry;
topo = M.topology;

% -----------------------------
% DEC Lab (DECLab) object for gradient
% -----------------------------
decM = DiscreteExteriorCalculus(M.Faces, M.Vertices);

% Heat field generation uses eigenmodes as a lowpass filter per your pipeline
M.eigenmodes(500);
eigen=M.eigenmodes;
 [gradHeader, grad]=M.gradient;
% Prepare gradient eigenbasis
nF = M.numFaces;
gradPsiFace = zeros(M.numFaces, max(eigen.k), 3, 'single');
Gpsi = grad * eigen.vectors;     
Gx = Gpsi(1:nF, :);
Gy = Gpsi(nF+1:2*nF, :);
Gz = Gpsi(2*nF+1:3*nF, :);
gradPsiFace = single(cat(3, Gx, Gy, Gz));    % [nF x K x 3]
% --- Tangent projection (face-wise) ---
N = single(fg.normals);                     % [nF x 3]
N = N ./ max(vecnorm(N,2,2), eps('single'));% ensure unit normals

% dot(f,k) = <u(f,k), n(f)>
dotUN = gradPsiFace(:,:,1).*N(:,1) + gradPsiFace(:,:,2).*N(:,2) + gradPsiFace(:,:,3).*N(:,3);  % [nF x K]

% u_tan = u - dotUN * n
gradPsiFace(:,:,1) = gradPsiFace(:,:,1) - dotUN .* N(:,1);
gradPsiFace(:,:,2) = gradPsiFace(:,:,2) - dotUN .* N(:,2);
gradPsiFace(:,:,3) = gradPsiFace(:,:,3) - dotUN .* N(:,3);
                   % [3*nF x K]
%%
opts = struct();
opts.Kexport            = 256;
opts.exportPsi          = true;
opts.exportGradPsi      = true;
opts.tangentProject     = true;
opts.exportFaceAreas    = true;
opts.exportFaceTangents = false;
opts.exportMass         = true;   % IMPORTANT

outBase = string(fullfile('C:\CodingProjects\Bioctreeapp\src\app\data\bct', 'bunny_spectral'));
manifest = exportForThreeJS_spectral(M, fg, topo, eigen, outBase, opts);

%%
% Compute the gradient of the heat field
F1 = bct.field.generate.heat(M, vD, tHeat);

% -----------------------------
% Compute face-based gradient and outward field
% -----------------------------
decGrad = decM.gradient(F1.value);

% Ensure decGrad is [nF x 3]
nF = size(M.Faces,1);
if isvector(decGrad) && numel(decGrad) == 3*nF
    decGrad = reshape(decGrad, [3, nF]).';  % [nF x 3]
end
assert( size(decGrad,1) == nF && size(decGrad,2) == 3, 'decGrad must be [nF x 3].' );

U_face = -decGrad;  % outward flow (per your convention)

% Enforce tangency (safety; should already be tangent from DEC)
Nf = fg.normals;                % [nF x 3]
U_face = U_face - (sum(U_face .* Nf, 2)) .* Nf;

F = int32(M.Faces);          % [nF x 3], 1-based
Hv = F1.value(:);            % [nV x 1]
H_face = (Hv(F(:,1)) + Hv(F(:,2)) + Hv(F(:,3))) / 3;


% Optional: clamp extreme magnitudes (keeps dt/speedGain safe on GPU)
Umag = sqrt(sum(U_face.^2,2));
p95  = prctile(Umag, 95);
eps0 = 1e-12;
scale = min(1, p95 ./ max(Umag, eps0));
U_face = U_face .* scale;

% -----------------------------
% Build neighbor table in opposite-vertex convention
% -----------------------------
faceNeighborsOpp0 = computeFaceNeighbors(M.Faces, topo.halfedge); % [nF x 3], 0-based, boundary = -1

% -----------------------------
% Export package for Three.js
% -----------------------------
exportForThreeJS_eulerian( ...
    M, fg, vg, ...
    faceNeighborsOpp0, ...
    U_face, ...
    H_face, ...
    outBase );

fprintf('Done.\n');
