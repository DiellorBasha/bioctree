% Test script for complete synthesis workflow
% Tests: designFilter -> Synthesize -> Generate pipeline

%% Setup
clear; close all; clc;

fprintf('=== Testing Bct Synthesis Workflow ===\n\n');

% Try to find an example .h5 file
example_files = dir('**/*.h5');
if isempty(example_files)
    fprintf('No .h5 files found. Creating minimal test setup...\n');
    % You would need to create a proper Bct object here
    return;
end

fprintf('Loading: %s\n', example_files(1).name);
try
    B = bct(fullfile(example_files(1).folder, example_files(1).name));
catch ME
    fprintf('Error loading file: %s\n', ME.message);
    return;
end

% Validate setup
if isempty(B.Manifold)
    fprintf('Error: Manifold not set\n');
    return;
end
if isempty(B.Time)
    fprintf('Error: Time not set. Setting default...\n');
    B.Time = bct.manifold.Time(500, 250);  % 2 seconds at 250 Hz
end

fprintf('Loaded: N=%d nodes, T=%d time points, fs=%.1f Hz\n\n', ...
    B.N, B.Time.T, B.Time.fs);

%% Test 1: Complete workflow for alpha band (8-12 Hz) spatial wave
fprintf('=== Test 1: Alpha Band Spatial Wave ===\n');
try
    % Step 1: Design filter for 10-50mm wavelengths
    fprintf('Step 1: Designing bandpass filter (10-50mm wavelength)...\n');
    filt_alpha = B.designFilter([10, 50], 'wavelength', 'band', ...
        'label', 'alpha_spatial', 'taper', 'hann');
    fprintf('  ✓ Filter designed: lambda band [%.4f, %.4f]\n', ...
        filt_alpha.lambda_band(1), filt_alpha.lambda_band(2));
    
    % Step 2: Synthesize spectral coefficients
    fprintf('Step 2: Synthesizing spectral coefficients...\n');
    B.Synthesize('alpha_spatial', 'envelope', 'none');
    fprintf('  ✓ Spectral grid populated\n');
    
    % Step 3: Generate signal
    fprintf('Step 3: Generating signal in spatial domain...\n');
    sig_alpha = B.Generate('label', 'alpha_wave', 'add', true);
    fprintf('  ✓ Signal generated: %s\n', sig_alpha.Label);
    fprintf('  Signal statistics:\n');
    fprintf('    Range: [%.4f, %.4f]\n', min(sig_alpha.Data(:)), max(sig_alpha.Data(:)));
    fprintf('    Mean: %.4f, Std: %.4f\n', mean(sig_alpha.Data(:)), std(sig_alpha.Data(:)));
    
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
    fprintf('     Stack: %s\n', ME.stack(1).name);
end
fprintf('\n');

%% Test 2: Gaussian packet with traveling wave
fprintf('=== Test 2: Gaussian Wave Packet (Traveling) ===\n');
try
    % Design filter for narrower band
    fprintf('Step 1: Designing filter (20-40mm wavelength)...\n');
    filt_packet = B.designFilter([20, 40], 'wavelength', 'band', ...
        'label', 'wave_packet');
    fprintf('  ✓ Filter designed\n');
    
    % Synthesize with Gaussian envelope and traveling wave
    fprintf('Step 2: Synthesizing with Gaussian envelope and velocity=5 mm/s...\n');
    B.Synthesize('wave_packet', ...
        'envelope', 'gaussian', ...
        't0', 1.0, ...
        'sigma_t', 0.2, ...
        'velocity', 5, ...
        'direction', [1 0 0]);
    fprintf('  ✓ Traveling wave packet synthesized\n');
    
    % Generate signal
    fprintf('Step 3: Generating signal...\n');
    sig_packet = B.Generate('label', 'traveling_packet', 'add', true);
    fprintf('  ✓ Signal generated: %s\n', sig_packet.Label);
    
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end
fprintf('\n');

%% Test 3: Heat diffusion filter
fprintf('=== Test 3: Heat Diffusion Filter ===\n');
try
    % Design heat diffusion filter
    fprintf('Step 1: Designing heat diffusion filter...\n');
    filt_heat = B.designFilter([0.01, 1.0], 'lambda', 'heat', ...
        'label', 'diffusion', 'time', 0.5);
    fprintf('  ✓ Heat filter designed\n');
    
    % Synthesize standing wave
    fprintf('Step 2: Synthesizing (standing wave)...\n');
    B.Synthesize('diffusion', 'velocity', 0);
    fprintf('  ✓ Spectral coefficients generated\n');
    
    % Generate signal
    fprintf('Step 3: Generating signal...\n');
    sig_heat = B.Generate('label', 'heat_diffusion', 'add', true);
    fprintf('  ✓ Signal generated: %s\n', sig_heat.Label);
    
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end
fprintf('\n');

%% Test 4: Using wavenumber specification
fprintf('=== Test 4: Wavenumber-based Filter ===\n');
try
    % Design using wavenumber
    fprintf('Step 1: Designing filter (0.1-0.5 rad/mm wavenumber)...\n');
    filt_k = B.designFilter([0.1, 0.5], 'wavenumber', 'band', ...
        'label', 'beta_band');
    fprintf('  ✓ Filter designed\n');
    
    % Synthesize
    fprintf('Step 2: Synthesizing...\n');
    B.Synthesize('beta_band', 'numModes', 100);
    fprintf('  ✓ Using 100 spatial modes\n');
    
    % Generate
    fprintf('Step 3: Generating signal...\n');
    sig_k = B.Generate('label', 'beta_wave', 'add', true);
    fprintf('  ✓ Signal generated: %s\n', sig_k.Label);
    
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end
fprintf('\n');

%% Test 5: List all generated signals
fprintf('=== Test 5: Summary ===\n');
fprintf('Total signals in Bct object: %d\n', length(B.Signals));
for i = 1:length(B.Signals)
    sig = B.Signals(i);
    fprintf('  [%d] %s - Size: [%d × %d]\n', i, sig.Label, sig.N, sig.T);
end
fprintf('\n');

%% Test 6: Verify filterbank state
fprintf('=== Filterbank Status ===\n');
B.listFilters();

%% Optional: Visualization (if plotting is available)
try
    fprintf('=== Attempting Visualization ===\n');
    
    % Plot first signal at a few time points
    if ~isempty(B.Signals)
        sig = B.Signals(1);
        
        figure('Name', 'Synthesized Signal Snapshots', 'Position', [100 100 1200 400]);
        
        % Select 3 time points
        t_idx = round(linspace(1, sig.T, 3));
        
        for i = 1:3
            subplot(1, 3, i);
            
            % Simple vertex plot if Manifold has V
            if isprop(B.Manifold, 'V') && ~isempty(B.Manifold.V)
                scatter3(B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
                    20, sig.Data(:, t_idx(i)), 'filled');
                colorbar;
                axis equal;
                title(sprintf('%s - t=%.3fs', sig.Label, (t_idx(i)-1)/B.Time.fs));
                xlabel('X'); ylabel('Y'); zlabel('Z');
            else
                plot(sig.Data(:, t_idx(i)));
                title(sprintf('Time point %d', t_idx(i)));
                xlabel('Vertex'); ylabel('Amplitude');
            end
        end
        
        fprintf('  ✓ Visualization created\n');
    end
catch ME
    fprintf('  ⚠ Visualization skipped: %s\n', ME.message);
end

fprintf('\n=== All Tests Complete ===\n');
