%EXAMPLE_SIGNAL_EIGENSPECTRUM  Simple example: spectral brush → eigenspectrum
%
% Demonstrates:
%   1. Generate signal from spectral patch brush
%   2. Visualize eigenspectrum

clearvars; clc;
bioctree_start;

%% Load mesh and initialize
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

%% Generate signal from spectral heat brush
fprintf('Generating spectral heat brush signal (tau=0.2)...\n');

sig = bct.Signal.fromBrush(B.Manifold, 'Category', 'patch', ...
    'Type', 'spectral', 'Source', 1000, 'Kernel', 'heat', 'Tau', 0.2);

%% Visualize spatial pattern
viewer = B.Manifold.plot('data', sig.Data, 'colormap', 'jet', ...
    'title', 'Heat Brush Signal (tau=0.2, source=1000)');

%% Plot eigenspectrum
fprintf('Computing and plotting eigenspectrum...\n');

% Basic power spectrum
bct.show.eigenspectrum(sig);

% Index spectrum with log scale (clearer view)
bct.show.eigenspectrum(sig, 'Type', 'index', 'Scale', 'log');

% Normalized energy with 90% threshold
bct.show.eigenspectrum(sig, 'Type', 'normalized', ...
    'ShowThreshold', true, 'ThresholdValue', 90);

% Show top 4 modes
bct.show.eigenspectrum(sig, 'TopModes', 4);

fprintf('\nDone! Generated spectral heat brush and visualized its eigenspectrum.\n');
