%% Example: Using synth_mesh_signal with Signal class
% Demonstrates the new Signal-based API for synth_mesh_signal

clear all;
close all;

% Add paths
root = fileparts(pwd);
addpath(fullfile(root, 'toolbox'));
addpath(fullfile(root, 'external'));

fprintf('=== synth_mesh_signal with Signal Class Example ===\n\n');

%% Setup: Create BCT object
[V, F] = icosphere(3);  % 642 vertices
B = bct.bct.fromMesh(V, F);

fprintf('Created BCT object:\n');
fprintf('  Vertices: %d\n', B.Manifold.N);
fprintf('  Faces: %d\n\n', size(B.Manifold.F, 1));

%% Example 1: Single narrowband signal
fprintf('Example 1: Single narrowband signal\n');

spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;

try
    B = bct.sim.synth_mesh_signal(B, spec, 'k', 100, 'label', 'alpha_band');
    
    fprintf('  ✓ Generated signal: "%s"\n', B.Signals(1).Label);
    fprintf('    Dimensions: [%d × %d]\n', size(B.Signals(1).Data));
    fprintf('    Type: %s\n\n', class(B.Signals(1).Data));
catch ME
    fprintf('  Note: %s\n\n', ME.message);
end

%% Example 2: Multiple frequency bands
fprintf('Example 2: Multiple frequency bands\n');

B2 = bct.bct.fromMesh(V, F);

specs = struct('type', {}, 'f0', {}, 'bw_abs', {});
freq_bands = [0.05, 0.10, 0.15, 0.20];  % Delta, theta, alpha, beta

for i = 1:length(freq_bands)
    specs(i).type = 'narrowband';
    specs(i).f0 = freq_bands(i);
    specs(i).bw_abs = 0.01;
end

try
    B2 = bct.sim.synth_mesh_signal(B2, specs, 'k', 100);
    
    fprintf('  ✓ Generated %d signals:\n', length(B2.Signals));
    for i = 1:length(B2.Signals)
        fprintf('    %d. %s\n', i, B2.Signals(i).Label);
    end
    fprintf('\n');
catch ME
    fprintf('  Note: %s\n\n', ME.message);
end

%% Example 3: Different signal types
fprintf('Example 3: Different signal types\n');

B3 = bct.bct.fromMesh(V, F);

try
    % White noise
    spec1.type = 'flat';
    B3 = bct.sim.synth_mesh_signal(B3, spec1, 'k', 100, 'label', 'white_noise');
    
    % Pink noise (1/f)
    spec2.type = 'powerlaw';
    spec2.alpha = 1;
    B3 = bct.sim.synth_mesh_signal(B3, spec2, 'k', 100, 'label', 'pink_noise');
    
    % Bandpass
    spec3.type = 'bandpass';
    spec3.fmin = 0.08;
    spec3.fmax = 0.12;
    B3 = bct.sim.synth_mesh_signal(B3, spec3, 'k', 100, 'label', 'alpha_filtered');
    
    fprintf('  ✓ Generated %d different signal types:\n', length(B3.Signals));
    for i = 1:length(B3.Signals)
        fprintf('    %d. %s\n', i, B3.Signals(i).Label);
    end
    fprintf('\n');
catch ME
    fprintf('  Note: %s\n\n', ME.message);
end

%% Example 4: Legacy mode (return raw data)
fprintf('Example 4: Legacy mode (backward compatibility)\n');

spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;

try
    x = bct.sim.synth_mesh_signal(B, spec, 'k', 100, 'return_raw', true, 'verbose', false);
    
    fprintf('  ✓ Legacy mode returns raw data\n');
    fprintf('    Data type: %s\n', class(x));
    fprintf('    Dimensions: [%d × %d]\n\n', size(x));
catch ME
    fprintf('  Note: %s\n\n', ME.message);
end

%% Summary
fprintf('=== Summary ===\n\n');

fprintf('New API Benefits:\n');
fprintf('  • Returns bct object with Signals automatically added\n');
fprintf('  • Supports multiple signal generation (spec array)\n');
fprintf('  • Automatic label generation from spec\n');
fprintf('  • Custom labels supported\n');
fprintf('  • Legacy mode for backward compatibility\n\n');

fprintf('Usage Patterns:\n');
fprintf('  B = synth_mesh_signal(B, spec)                    - Single signal\n');
fprintf('  B = synth_mesh_signal(B, spec, ''label'', L)        - Custom label\n');
fprintf('  B = synth_mesh_signal(B, [spec1, ...])            - Multiple signals\n');
fprintf('  x = synth_mesh_signal(B, spec, ''return_raw'', true) - Raw data\n\n');

fprintf('Signal Access:\n');
fprintf('  sig = B.Signals(i)           - Get i-th signal\n');
fprintf('  sig = B.getSignalByLabel(L)  - Get by label\n');
fprintf('  data = B.Signals(i).Data     - Get signal data\n');
