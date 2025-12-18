%DEMO_BRUSH_DESIGNER_QUICKSTART  Quick demo of interactive brush design
%
% Shows the basic workflow:
%   1. Create designer
%   2. Evaluate kernel on Lambda
%   3. Adjust parameters
%   4. Finalize

clearvars; clc;
bioctree_start;

% Load mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

%% Quick Example: Heat Kernel Parameter Tuning

% Create designer with initial tau=0.1
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 100, 'kernel', 'heat', 'tau', 0.1));

% Evaluate on Lambda axis
H1 = designer.evaluateKernel();
designer.plotKernelResponse();
fprintf('tau=0.1: %d modes > 1%% threshold\n', sum(H1 > 0.01));

% Increase diffusion
designer.setParameter('tau', 0.3);
H2 = designer.evaluateKernel();
designer.plotKernelResponse();
fprintf('tau=0.3: %d modes > 1%% threshold\n', sum(H2 > 0.01));

% Preview spatial pattern
designer.preview();

% Finalize
w = designer.finalize();
fprintf('Generated brush: [%d×1]\n', size(w, 1));

% Create signal
sig = bct.Signal.fromBrush('spectral', B, 'source', 100, 'kernel', 'heat', 'tau', 0.3);
sig.plot();
