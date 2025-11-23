%% EXAMPLE: Spatiotemporal Pattern Generation on Graphs
% This script demonstrates how to use the new spatiotemporal pattern
% generation functions to create test data for graph signal processing.

%% Clear workspace and add paths
clear; clc; close all;

% Add simulation functions to path (if needed)
addpath(genpath('./toolbox/simulations'));

fprintf('=== Spatiotemporal Pattern Generation Examples ===\n\n');

%% Example 1: Basic Patch Signal on 2D Grid
fprintf('--- Example 1: Patch Signals on 2D Grid ---\n');

% Create a 2D grid graph with temporal structure
G1 = createTestGraphWithTime('grid2d', 'N', 100, 'T', 50, 'fs', 10);

% Generate different types of patch signals
fprintf('Generating patch signals...\n');

% Static patch
[signal_static, params_static] = generatePatchSignal(G1, ...
    'patchSize', 0.15, 'growthMode', 'none');

% Growing patch
[signal_growing, params_growing] = generatePatchSignal(G1, ...
    'patchSize', 0.05, 'growthMode', 'grow', 'growthRate', 1.5);

% Moving patch
[signal_moving, params_moving] = generatePatchSignal(G1, ...
    'patchSize', 0.1, 'growthMode', 'move', 'moveSpeed', 1);

% Growing and moving patch
[signal_both, params_both] = generatePatchSignal(G1, ...
    'patchSize', 0.08, 'growthMode', 'grow_and_move', ...
    'growthRate', 1.2, 'moveSpeed', 0.8);

fprintf('  Static patch: %d active nodes\n', sum(signal_static(:,1) > 0));
fprintf('  Growing patch: %d -> %d active nodes\n', ...
    sum(signal_growing(:,1) > 0), sum(signal_growing(:,end) > 0));

%% Example 2: Various Spatiotemporal Patterns on Spherical Mesh
fprintf('\n--- Example 2: Spatiotemporal Patterns on Sphere ---\n');

% Create spherical mesh
G2 = createTestGraphWithTime('sphere', 'N', 300, 'T', 100, 'fs', 20);

% Generate different pattern types
patterns = {'wave', 'ripple', 'oscillation', 'burst', 'gradient'};
signals = cell(length(patterns), 1);
params_all = cell(length(patterns), 1);

for i = 1:length(patterns)
    fprintf('Generating %s pattern...\n', patterns{i});
    [signals{i}, params_all{i}] = generateSpatioTemporalPattern(G2, patterns{i}, ...
        'amplitude', 1, 'frequency', 2);
end

%% Example 3: Noise Patterns for Baseline Comparison
fprintf('\n--- Example 3: Structured Noise Patterns ---\n');

% Create random geometric graph
G3 = createTestGraphWithTime('random', 'N', 150, 'T', 80, 'fs', 15);

% Generate different noise types
noise_types = {'white', 'colored', 'structured'};
noise_signals = cell(length(noise_types), 1);

for i = 1:length(noise_types)
    fprintf('Generating %s noise...\n', noise_types{i});
    [noise_signals{i}, ~] = generateSpatioTemporalPattern(G3, 'noise', ...
        'noiseType', noise_types{i}, 'correlation', 0.3);
end

%% Example 4: Comprehensive Demo with Visualization
fprintf('\n--- Example 4: Comprehensive Demo ---\n');

% Create brain-like surface
G4 = createTestGraphWithTime('brain', 'N', 200, 'T', 60, 'fs', 12);

% Run comprehensive demo
demoSpatioTemporalPatterns(G4, ...
    'patterns', {'patch', 'wave', 'ripple', 'oscillation'}, ...
    'showPlots', true, ...
    'saveResults', false);

%% Example 5: Custom Pattern with Specific Parameters
fprintf('\n--- Example 5: Custom Pattern Design ---\n');

% Create 3D grid for complex patterns
G5 = createTestGraphWithTime('grid3d', 'N', 125, 'T', 40, 'fs', 8);

% Create custom multi-component pattern
fprintf('Generating custom multi-component pattern...\n');

% Component 1: Growing patch at one location
[comp1, ~] = generatePatchSignal(G5, ...
    'patchCenter', 20, 'patchSize', 0.1, 'growthMode', 'grow', ...
    'patchValue', 1, 'growthRate', 1);

% Component 2: Oscillating patch at another location
[comp2, ~] = generateSpatioTemporalPattern(G5, 'oscillation', ...
    'amplitude', 0.8, 'frequency', 3);

% Component 3: Background noise
[comp3, ~] = generateSpatioTemporalPattern(G5, 'noise', ...
    'noiseType', 'colored', 'amplitude', 0.2, 'correlation', 0.15);

% Combine components
custom_signal = comp1 + comp2 + comp3;

fprintf('Custom signal statistics:\n');
fprintf('  Range: [%.3f, %.3f]\n', min(custom_signal(:)), max(custom_signal(:)));
fprintf('  Mean energy per time step: %.3f\n', mean(sum(custom_signal.^2, 1)));

%% Example 6: Batch Generation for Dataset Creation
fprintf('\n--- Example 6: Batch Dataset Generation ---\n');

% Parameters for batch generation
num_samples = 5;
graph_types = {'grid2d', 'sphere', 'random'};
pattern_types = {'patch', 'wave', 'ripple'};

% Create dataset
dataset = struct();
sample_count = 0;

for g = 1:length(graph_types)
    for p = 1:length(pattern_types)
        for s = 1:num_samples
            sample_count = sample_count + 1;
            
            % Create graph
            G_temp = createTestGraphWithTime(graph_types{g}, ...
                'N', 100 + randi(50), 'T', 30 + randi(20), 'fs', 10);
            
            % Generate pattern with random parameters
            if strcmp(pattern_types{p}, 'patch')
                [signal, params] = generatePatchSignal(G_temp, ...
                    'patchSize', 0.05 + 0.15*rand(), ...
                    'growthMode', 'grow', ...
                    'growthRate', 0.5 + 1.5*rand());
            else
                [signal, params] = generateSpatioTemporalPattern(G_temp, pattern_types{p}, ...
                    'amplitude', 0.5 + 0.5*rand(), ...
                    'frequency', 1 + 2*rand());
            end
            
            % Store in dataset
            dataset(sample_count).graph_type = graph_types{g};
            dataset(sample_count).pattern_type = pattern_types{p};
            dataset(sample_count).G = G_temp;
            dataset(sample_count).signal = signal;
            dataset(sample_count).params = params;
        end
    end
end

fprintf('Generated dataset with %d samples\n', sample_count);
fprintf('Graph types: %s\n', strjoin(graph_types, ', '));
fprintf('Pattern types: %s\n', strjoin(pattern_types, ', '));

%% Summary and Usage Tips
fprintf('\n=== Usage Summary ===\n');
fprintf('Functions created:\n');
fprintf('1. generatePatchSignal() - Core patch signal generator\n');
fprintf('2. generateSpatioTemporalPattern() - Multi-pattern generator\n');
fprintf('3. demoSpatioTemporalPatterns() - Visualization demo\n');
fprintf('4. createTestGraphWithTime() - Test graph creator\n');
fprintf('\nKey features:\n');
fprintf('- Automatic handling of static vs temporal signals\n');
fprintf('- Flexible patch growth and movement\n');
fprintf('- Multiple pattern types (wave, ripple, oscillation, etc.)\n');
fprintf('- Support for various graph topologies\n');
fprintf('- Comprehensive visualization capabilities\n');
fprintf('\nNext steps:\n');
fprintf('- Use these signals to test your GSP algorithms\n');
fprintf('- Modify parameters to create specific scenarios\n');
fprintf('- Add custom pattern types as needed\n');
fprintf('- Validate algorithm performance on known ground truth\n');

fprintf('\n=== Examples Complete ===\n');