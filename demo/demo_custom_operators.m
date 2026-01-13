%DEMO_CUSTOM_OPERATORS Demonstrate creating custom operator types
%
% This script shows how to create custom operators for:
%   1. Imaging kernels (MEG/EEG source reconstruction)
%   2. Spatial downsampling operators
%   3. Multi-scale operators
%   4. Custom differential operators
%
% Key principle: bct.Operator wraps ANY matrix with metadata

%% Setup
demoDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(demoDir);

addpath(fullfile(rootDir, 'toolbox'));
addpath(fullfile(rootDir, 'external'));
addpath(fullfile(rootDir, 'external', 'gptoolbox', 'mesh'));

%% Load test manifold
fprintf('=== Custom Operator Demo ===\n\n');
fprintf('Loading test manifold...\n');
[V, F] = icosphere(3);
M = bct.Manifold(struct('V', V, 'F', F));
fprintf('  Vertices: %d\n', M.numVertices());
fprintf('  Faces: %d\n\n', M.numFaces());

%% Example 1: Imaging Kernel (MEG/EEG forward operator)
fprintf('=== Example 1: MEG Imaging Kernel ===\n');

nChannels = 300;  % Number of MEG sensors
nVertices = M.numVertices();

% Create random imaging kernel (in practice, this would be computed
% from lead field matrix using inverse methods like MNE, LCMV, etc.)
imagingMatrix = randn(nVertices, nChannels);

% Wrap in bct.Operator
ImagingKernel = bct.Operator(M, imagingMatrix, ...
    'ID', "imaging_kernel", ...
    'Name', "MEG Imaging Kernel (MNE)", ...
    'Domain', "inverse_problem", ...
    'InputType', sprintf("%d-channel MEG", nChannels), ...
    'OutputType', "0-form (cortical sources)");

fprintf('\n');
disp(ImagingKernel);

% Apply to simulated sensor data
fprintf('\nApplying to simulated sensor data:\n');
sensorData = randn(nChannels, 1);
sourceEstimate = ImagingKernel * sensorData;
fprintf('  Sensor data: [%d × 1]\n', length(sensorData));
fprintf('  Source estimate: [%d × 1]\n', length(sourceEstimate));
fprintf('  Source range: [%.3f, %.3f]\n', min(sourceEstimate), max(sourceEstimate));

%% Example 2: Downsampling Operator
fprintf('\n=== Example 2: Spatial Downsampling ===\n');

% Create coarse mesh by random subsampling
nCoarse = 200;
downsampleIdx = randperm(nVertices, nCoarse);

% Build downsampling operator (sparse indicator matrix)
downsampleMatrix = sparse(1:nCoarse, downsampleIdx, 1, nCoarse, nVertices);

Downsample = bct.Operator(M, downsampleMatrix, ...
    'ID', "downsample", ...
    'Name', sprintf("Downsample (%d → %d)", nVertices, nCoarse), ...
    'Domain', "spatial", ...
    'InputType', "0-form (full resolution)", ...
    'OutputType', sprintf("0-form (%d vertices)", nCoarse));

fprintf('\n');
disp(Downsample);

% Apply downsampling
field = randn(nVertices, 1);
coarseField = Downsample * field;
fprintf('\nDownsampling result:\n');
fprintf('  Input: %d vertices\n', length(field));
fprintf('  Output: %d vertices\n', length(coarseField));

%% Example 3: Interpolation (upsampling)
fprintf('\n=== Example 3: Spatial Interpolation ===\n');

% Create interpolation operator (pseudo-inverse of downsampling)
% In practice, you'd use proper interpolation (e.g., barycentric)
interpolationMatrix = downsampleMatrix';  % Simple transpose (not ideal, just demo)

Upsample = bct.Operator(M, interpolationMatrix, ...
    'ID', "upsample", ...
    'Name', sprintf("Upsample (%d → %d)", nCoarse, nVertices), ...
    'Domain', "spatial", ...
    'InputType', sprintf("0-form (%d vertices)", nCoarse), ...
    'OutputType', "0-form (full resolution)");

fprintf('\n');
disp(Upsample);

% Apply upsampling
upsampled = Upsample * coarseField;
fprintf('\nUpsampling result:\n');
fprintf('  Input: %d vertices\n', length(coarseField));
fprintf('  Output: %d vertices\n', length(upsampled));
fprintf('  Reconstruction error: %.3f\n', norm(field - upsampled) / norm(field));

%% Example 4: Compose custom operators
fprintf('\n=== Example 4: Operator Composition ===\n');

% Compose downsampling with upsampling (lossy identity)
Projection = Upsample * Downsample;
fprintf('Composed operator: Upsample ∘ Downsample\n');
fprintf('  ID: %s\n', Projection.ID);
fprintf('  Size: [%d × %d]\n', Projection.Size(1), Projection.Size(2));

% Test round-trip
projected = Projection * field;
error = norm(field - projected) / norm(field);
fprintf('  Round-trip error: %.3f\n', error);

%% Example 5: Custom differential operator
fprintf('\n=== Example 5: Custom Gradient Operator ===\n');

% Build simple edge-based gradient (for demonstration)
E = M.Edges;
nEdges = size(E, 1);

% Gradient maps vertex values to edge differences
gradMatrix = sparse([1:nEdges, 1:nEdges], [E(:,2); E(:,1)], ...
    [ones(nEdges,1); -ones(nEdges,1)], nEdges, nVertices);

CustomGradient = bct.Operator(M, gradMatrix, ...
    'ID', "custom_gradient", ...
    'Name', "Custom Edge Gradient", ...
    'Domain', "custom", ...
    'InputType', "0-form (vertex)", ...
    'OutputType', "edge differences");

fprintf('\n');
disp(CustomGradient);

% Apply to smooth field
[theta, phi] = cart2sph(V(:,1), V(:,2), V(:,3));
smoothField = cos(theta);
edgeGrad = CustomGradient * smoothField;

fprintf('\nGradient statistics:\n');
fprintf('  Input range: [%.3f, %.3f]\n', min(smoothField), max(smoothField));
fprintf('  Gradient range: [%.3f, %.3f]\n', min(edgeGrad), max(edgeGrad));
fprintf('  Mean |gradient|: %.3f\n', mean(abs(edgeGrad)));

%% Example 6: Multi-scale operator
fprintf('\n=== Example 6: Multi-Scale Operator ===\n');

% Create multi-resolution operator (projects to multiple resolutions)
scales = [100, 200, 300];
nScales = length(scales);
totalRows = sum(scales);

% Build block-diagonal multi-scale operator
blocks = cell(nScales, 1);
rowOffset = 0;
for i = 1:nScales
    nSamples = scales(i);
    idx = randperm(nVertices, nSamples);
    blocks{i} = sparse(1:nSamples, idx, 1, nSamples, nVertices);
end
multiScaleMatrix = vertcat(blocks{:});

MultiScale = bct.Operator(M, multiScaleMatrix, ...
    'ID', "multiscale", ...
    'Name', "Multi-Resolution Projection", ...
    'Domain', "multiscale", ...
    'InputType', "0-form (full)", ...
    'OutputType', sprintf("multi-resolution (%d levels)", nScales));

fprintf('\n');
disp(MultiScale);

% Apply multi-scale projection
multiResField = MultiScale * smoothField;
fprintf('\nMulti-scale projection:\n');
fprintf('  Input: %d vertices\n', nVertices);
fprintf('  Output: %d samples across %d scales\n', totalRows, nScales);

% Extract each scale
offset = 0;
for i = 1:nScales
    scaleField = multiResField(offset + (1:scales(i)));
    fprintf('    Scale %d: %d samples, range [%.3f, %.3f]\n', ...
        i, scales(i), min(scaleField), max(scaleField));
    offset = offset + scales(i);
end

%% Example 7: Compose with DEC operators
fprintf('\n=== Example 7: Custom + DEC Composition ===\n');

% Get DEC gradient
d0 = M.d0();

% Compose imaging kernel with DEC gradient
% This computes gradient of source estimates directly from sensor data
ImagingGradient = d0 * ImagingKernel;

fprintf('Imaging-then-Gradient operator:\n');
fprintf('  ID: %s\n', ImagingGradient.ID);
fprintf('  Maps: %s → %s\n', ImagingKernel.InputType, d0.OutputType);
fprintf('  Size: [%d × %d]\n', ImagingGradient.Size(1), ImagingGradient.Size(2));

% Apply to sensor data
sensorData = randn(nChannels, 1);
sourceGradient = ImagingGradient * sensorData;
fprintf('  Input: %d channels\n', nChannels);
fprintf('  Output: %d edges (1-form)\n', length(sourceGradient));

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('✓ Created 7 custom operator types:\n');
fprintf('  1. MEG/EEG Imaging Kernel (%d × %d)\n', nVertices, nChannels);
fprintf('  2. Spatial Downsampling (%d × %d)\n', nCoarse, nVertices);
fprintf('  3. Spatial Upsampling (%d × %d)\n', nVertices, nCoarse);
fprintf('  4. Lossy Projection (composition)\n');
fprintf('  5. Custom Edge Gradient (%d × %d)\n', nEdges, nVertices);
fprintf('  6. Multi-Resolution (%d × %d)\n', totalRows, nVertices);
fprintf('  7. Imaging + DEC Gradient (composition)\n');
fprintf('\n✓ All operators support:\n');
fprintf('  - Operator application via * operator\n');
fprintf('  - Operator composition via * operator\n');
fprintf('  - Metadata (ID, Name, Domain, Input/Output types)\n');
fprintf('  - Matrix access via .Matrix property\n');
fprintf('\nKey insight: bct.Operator wraps ANY matrix with metadata!\n');
