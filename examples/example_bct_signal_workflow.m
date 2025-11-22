%% Example: Complete BCT + Signal Workflow
% Demonstrates how to use the refactored BCT architecture with
% Manifold, Time, and Signal objects

clear all;
close all;

% Add paths
root = fileparts(pwd);
addpath(fullfile(root, 'toolbox'));
addpath(fullfile(root, 'external'));

fprintf('=== BCT + Signal Complete Workflow ===\n\n');

%% Step 1: Create a BCT object with mesh geometry
fprintf('Step 1: Create BCT object with mesh\n');
[V, F] = icosphere(3);  % 642 vertices
B = bct.bct.fromMesh(V, F);

fprintf('  Created BCT with %d vertices\n', B.Manifold.N);
fprintf('  Manifold type: %s\n', B.Manifold.Type);
fprintf('  Vertices: [%d × %d]\n', size(B.Manifold.V, 1), size(B.Manifold.V, 2));
fprintf('  Faces: [%d × %d]\n\n', size(B.Manifold.F, 1), size(B.Manifold.F, 2));

%% Step 2: Add temporal information
fprintf('Step 2: Add temporal dimension\n');
B.Manifold.Time = bct.manifold.Time(200, 500);  % 200 time points at 500 Hz

fprintf('  Time points: %d\n', B.Manifold.Time.T);
fprintf('  Sampling frequency: %.1f Hz\n', B.Manifold.Time.fs);
fprintf('  Duration: %.3f seconds\n', B.Manifold.Time.get_duration());
fprintf('  Nyquist frequency: %.1f Hz\n\n', B.Manifold.Time.get_nyquist_freq());

%% Step 3: Compute graph spectrum for signal synthesis (optional)
fprintf('Step 3: Compute graph spectrum (optional)\n');
k = 100;
try
    [B.Manifold.Eigenvectors, B.Manifold.Eigenvalues] = meshFourier(B.Manifold, k);
    fprintf('  Computed %d eigenmodes\n', k);
    fprintf('  Eigenvalue range: [%.4f, %.4f]\n\n', ...
        min(B.Manifold.Eigenvalues), max(B.Manifold.Eigenvalues));
    has_spectrum = true;
catch ME
    fprintf('  Note: Skipping spectrum computation (requires gptoolbox)\n');
    fprintf('        %s\n\n', ME.message);
    has_spectrum = false;
end

%% Step 4: Generate synthetic signals
fprintf('Step 4: Generate synthetic signals\n');

% Scalar static signal (activation map)
fprintf('  Generating scalar static signal...\n');
if has_spectrum
    power_spec = exp(-B.Manifold.Eigenvalues / 10);
    data_scalar_static = bct.sim.synth_mesh_signal(B.Manifold, power_spec);
else
    % Fallback: random smooth signal
    data_scalar_static = randn(B.Manifold.N, 1);
end
sig1 = bct.Signal(B.Manifold, data_scalar_static, 'activation_map');
B.addSignal(sig1);

% Scalar dynamic signal (time series)
fprintf('  Generating scalar dynamic signal...\n');
data_scalar_dynamic = zeros(B.Manifold.N, B.Manifold.Time.T);
if has_spectrum
    for t = 1:B.Manifold.Time.T
        power_spec_t = exp(-B.Manifold.Eigenvalues / 10) .* sin(2*pi*t/50);
        data_scalar_dynamic(:, t) = bct.sim.synth_mesh_signal(B.Manifold, power_spec_t);
    end
else
    % Fallback: random time series
    data_scalar_dynamic = randn(B.Manifold.N, B.Manifold.Time.T);
end
sig2 = bct.Signal(B.Manifold, data_scalar_dynamic, 'dynamic_pattern');
B.addSignal(sig2);

% Vector static signal (gradient field)
fprintf('  Generating vector static signal...\n');
data_vector_static = randn(B.Manifold.N, 3);
data_vector_static = data_vector_static ./ vecnorm(data_vector_static, 2, 2);
sig3 = bct.Signal(B.Manifold, data_vector_static, 'tangent_field');
B.addSignal(sig3);

fprintf('  Added %d signals to BCT\n\n', length(B.Signals));

%% Step 5: Query and analyze signals
fprintf('Step 5: Query and analyze signals\n');

% List all signals
fprintf('  All signals:\n');
for i = 1:length(B.Signals)
    s = B.Signals(i);
    type_str = 'Unknown';
    if s.IsStatic && ~s.IsVector
        type_str = 'Scalar static';
    elseif s.IsDynamic && ~s.IsVector
        type_str = 'Scalar dynamic';
    elseif s.IsStatic && s.IsVector
        type_str = 'Vector static';
    elseif s.IsDynamic && s.IsVector
        type_str = 'Vector dynamic';
    end
    fprintf('    %d. "%s" (%s) [%s]\n', i, s.Label, type_str, mat2str(size(s.Data)));
end
fprintf('\n');

% Access specific signal
sig = B.getSignalByLabel('dynamic_pattern');
fprintf('  Retrieved signal "%s"\n', sig.Label);
fprintf('    Shape: [%d × %d]\n', size(sig.Data, 1), size(sig.Data, 2));
fprintf('    Is dynamic: %s\n', mat2str(sig.IsDynamic));

% Get temporal trace at vertex 100
trace = sig.get_temporal_trace(100);
fprintf('    Temporal trace at vertex 100: [%d × 1]\n', length(trace));

% Get spatial snapshot at t=50
snapshot = sig.get_spatial_snapshot(50);
fprintf('    Spatial snapshot at t=50: [%d × 1]\n\n', length(snapshot));

%% Step 6: Demonstrate dimension validation
fprintf('Step 6: Dimension validation\n');

% Try to add signal with wrong dimensions
wrong_data = randn(100, 1);  % Wrong N
M_wrong = bct.manifold.Manifold(V(1:100,:), F(1:50,:));
sig_bad = bct.Signal(M_wrong, wrong_data, 'incompatible');

try
    B.addSignal(sig_bad);
    fprintf('  ERROR: Should have rejected signal!\n');
catch ME
    fprintf('  ✓ Correctly rejected signal with N=%d (expected N=%d)\n', ...
        sig_bad.N, B.Manifold.N);
    fprintf('    Error: %s\n\n', ME.message);
end

%% Step 7: Signal management operations
fprintf('Step 7: Signal management\n');

% Remove a signal
fprintf('  Signals before removal: %d\n', length(B.Signals));
B.removeSignal('activation_map');
fprintf('  Signals after removal: %d\n', length(B.Signals));

% Add it back
B.addSignal(sig1);
fprintf('  Signals after adding back: %d\n\n', length(B.Signals));

%% Summary
fprintf('=== Workflow Complete ===\n\n');

fprintf('New BCT Architecture:\n');
fprintf('  • B.Manifold            - Mesh/graph geometry\n');
fprintf('  • B.Manifold.Time       - Temporal dimension\n');
fprintf('  • B.Signals             - Array of Signal objects\n');
fprintf('  • B.Signals(i)          - Access signal by index\n');
fprintf('  • B.getSignalByLabel()  - Find signal by label\n\n');

fprintf('Signal Types Supported:\n');
fprintf('  • Scalar static   [N × 1]       - Single map on manifold\n');
fprintf('  • Scalar dynamic  [N × T]       - Time series on manifold\n');
fprintf('  • Vector static   [N × 3]       - Vector field on manifold\n');
fprintf('  • Vector dynamic  [N × T × 3]   - Time-varying vector field\n\n');

fprintf('Validation:\n');
fprintf('  • Signal.N must match Manifold.N\n');
fprintf('  • Signal.T must match Manifold.Time.T (dynamic signals)\n');
fprintf('  • Enforced automatically via validateSignalDimensions()\n');

