%DEMO_ANALYSIS  Complete analysis workflow with manifold, operators, and fields
%
% Demonstrates BCT analysis workflow:
%   - Manifold construction and caching
%   - Operator computation (DEC, spectral transforms)
%   - Field generation and spectral analysis
%   - Gradient computation on field amplitude

clear; close all; clc;

%% Load mesh
meshFile = fullfile('data', 'mesh', 'fsaverage_rh_pial.mat');
if ~isfile(meshFile)
    error('Mesh file not found: %s', meshFile);
end
data = load(meshFile);
V = data.V;
F = data.F;

%% Create Manifold
M = bct.Manifold(V, F);
M = M.flip();

%% Compute eigenmodes
E = M.eigenmodes(100);


%% Cache geometry and topology
geom = M.geometry();
fgeom = M.faceGeometry;
vgeom = M.vertexGeometry;
topo = M.topology();

%% Compute differential operators
dec = M.dec();
[~, grad_op] = M.gradient();
[~, div_op] = M.divergence();

%% Compute spectral transform operators
[~, mft_op] = M.mft();
[~, imft_op] = M.imft();

%% Generate heat field
sourceIdx = 1000;
t_heat = 10.0;
heatField = bct.field.generate.heat(M, sourceIdx, t_heat);

%% Compute field spectrum
spectrum = mft_op * heatField.value;

%% Generate heat advection field (time-varying)
fromVertex = 500;
toVertex = 3000;
tau = 15.0;
heatAdvField = bct.field.generate.heatadvection(fromVertex, toVertex, M, tau);

%% Compute spectrum of time-averaged heat advection field
nTimePoints = size(heatAdvField.value, 2);
timeAvgField = mean(heatAdvField.value, 2);
advSpectrum = mft_op * timeAvgField;
plot(advSpectrum)

timeSumField = sum(heatAdvField.value, 2);
[viewer , fig] =bct.ui.show(M);
viewer.setScalar(timeSumField);
viewer.setScalar(timeAvgField);
%% Compute gradient of field amplitude
amplitude = abs(timeAvgField);
gradAmplitude = grad_op * amplitude;
nF = M.numFaces();
gradAmplitude_reshaped = reshape(gradAmplitude, nF, 3);
gradMagnitude = sqrt(sum(gradAmplitude_reshaped.^2, 2));
%%
dec = DiscreteExteriorCalculus(double(M.Faces), double(M.Vertices));
U=dec.gradient(amplitude);
% Project onto the tangent space of the surface if necessary
U = U - dot(U, N) * N;
% Perform Helmholtz-Hodge decomposition
[divU, rotU, harmU, scalarP, vectorP] = ...
    dec.helmholtzHodgeDecomposition(U, 1e-8);

% Normalize rows for plotting
plotU = U ./ vecnorm(U, 2, 2);
plotDivU = divU ./ vecnorm(divU, 2, 2);
plotRotU = rotU ./ vecnorm(rotU, 2, 2);
plotHU = harmU ./ vecnorm(harmU, 2, 2);

% Option 1: Show gradient magnitude as colors
viewer.setScalar(gradMagnitude);  % Map magnitude to face colors (interpolated to vertices)

% Option 2: Show gradient vectors as arrows
viewer.setVector(gradAmplitude_reshaped, 'Support', 'face', 'Stride', 5, 'LengthScale', 1.0);
viewer.setVector(divU, 'Support', 'face', 'Stride', 5, 'LengthScale', 1.0);
viewer.setVector(rotU, 'Support', 'face', 'Stride', 5, 'LengthScale', 1.0);

%% Compute gradient of field amplitude
amplitude = abs(heatField.value);
gradAmplitude = grad_op * amplitude;
nF = M.numFaces();
gradAmplitude_reshaped = reshape(gradAmplitude, nF, 3);
gradMagnitude = sqrt(sum(gradAmplitude_reshaped.^2, 2));

%% Visualizations
% Heat field
figure('Name', 'Heat Field', 'Position', [100 100 800 600]);
bct.ui.show(M, heatField);
title(sprintf('Heat Field (t=%.1f, source=%d)', t_heat, sourceIdx));
colorbar;

% Field amplitude
figure('Name', 'Field Amplitude', 'Position', [150 150 800 600]);
bct.ui.show(M, amplitude);
title('Field Amplitude |u|');
colorbar;

% Gradient magnitude
figure('Name', 'Gradient Magnitude', 'Position', [200 200 800 600]);
gradField = bct.field.make(M, gradMagnitude, 'support', 'face', 'valueType', 'scalar');
bct.ui.show(M, gradField);
title('Gradient Magnitude |\nabla|u||');
colorbar;

% Spectrum
figure('Name', 'Spectral Coefficients', 'Position', [250 250 800 600]);
subplot(2,1,1);
plot(abs(spectrum), 'LineWidth', 1.5);
xlabel('Mode Index');
ylabel('|Coefficient|');
title('Spectral Coefficient Magnitude');
grid on;

subplot(2,1,2);
semilogy(abs(spectrum), 'LineWidth', 1.5);
xlabel('Mode Index');
ylabel('|Coefficient| (log scale)');
title('Spectral Coefficient Magnitude (Log Scale)');
grid on;

% Heat advection field (show first, middle, and last frames)
figure('Name', 'Heat Advection Field', 'Position', [300 300 1200 400]);
timeIndices = [1, ceil(nTimePoints/2), nTimePoints];
for i = 1:3
    subplot(1,3,i);
    t = timeIndices(i);
    trisurf(M.Faces, M.Vertices(:,1), M.Vertices(:,2), M.Vertices(:,3), heatAdvField.value(:,t));
    shading interp;
    axis equal tight off;
    view(90, 0);
    colorbar;
    title(sprintf('Time %d/%d (vertex %d)', t, nTimePoints, heatAdvField.meta.pathIndices(t)));
end
colormap('hot');

% Time-averaged heat advection field and its spectrum
figure('Name', 'Time-Averaged Heat Advection', 'Position', [350 350 1200 400]);
subplot(1,2,1);
trisurf(M.Faces, M.Vertices(:,1), M.Vertices(:,2), M.Vertices(:,3), timeAvgField);
shading interp;
axis equal tight off;
view(90, 0);
colorbar;
title('Time-Averaged Field');
colormap('hot');

subplot(1,2,2);
plot(abs(advSpectrum), 'LineWidth', 1.5);
xlabel('Mode Index');
ylabel('|Coefficient|');
title('Spectrum of Time-Averaged Field');
grid on;

%% Health check
h = M.health();

