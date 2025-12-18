%DEMO_BRUSH_DESIGNER  Demonstrates interactive brush design with parameter manipulation
%
% This demo shows how to use BrushDesigner to:
%   1. Create a brush design with initial parameters
%   2. Evaluate kernel on Lambda axis to preview spectral coverage
%   3. Adjust parameters interactively
%   4. Visualize kernel response
%   5. Preview spatial brush pattern
%   6. Finalize to generate brush weights
%
% The key advantage is being able to manipulate parameters and see
% spectral coverage BEFORE generating the final brush.

clearvars; clc;
bioctree_start;

%% 1. Setup Mesh and Initialize BCT
fprintf('Loading mesh...\n');
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);
fprintf('Mesh: %d vertices, %d faces\n', B.Manifold.N, size(B.Manifold.F, 1));

%% 2. Create Interactive Designer for Spectral Heat Brush
fprintf('\n=== Example 1: Heat Kernel on Lambda ===\n');

% Create designer with initial tau
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 100, 'kernel', 'heat', 'tau', 0.1));

% Evaluate kernel on Lambda axis
H_tau01 = designer.evaluateKernel();
fprintf('Heat kernel with tau=0.1:\n');
fprintf('  Max response: %.4f\n', max(H_tau01));
fprintf('  Min response: %.4f\n', min(H_tau01));
fprintf('  Modes > 1%% threshold: %d\n', sum(H_tau01 > 0.01));

% Visualize spectral response
designer.plotKernelResponse();

% Adjust tau for more diffusion
designer.setParameter('tau', 0.3);
H_tau03 = designer.evaluateKernel();
fprintf('\nHeat kernel with tau=0.3:\n');
fprintf('  Max response: %.4f\n', max(H_tau03));
fprintf('  Min response: %.4f\n', min(H_tau03));
fprintf('  Modes > 1%% threshold: %d\n', sum(H_tau03 > 0.01));

designer.plotKernelResponse();

% Compare tau values
figure('Name', 'Heat Kernel Comparison');
lambda = designer.Lambda.lambda;
plot(lambda, H_tau01, 'b-', 'LineWidth', 2, 'DisplayName', '\tau=0.1');
hold on;
plot(lambda, H_tau03, 'r-', 'LineWidth', 2, 'DisplayName', '\tau=0.3');
grid on;
xlabel('Eigenvalue \lambda');
ylabel('Kernel Response H(\lambda)');
title('Heat Kernel: Effect of \tau');
legend('Location', 'best');
set(gca, 'YScale', 'log');

% Preview spatial pattern
designer.preview();

% Finalize
w_heat = designer.finalize();
fprintf('\nGenerated heat brush: [%d×1]\n', size(w_heat, 1));

%% 3. Gaussian Bandpass Filter on Lambda
fprintf('\n=== Example 2: Gaussian Bandpass ===\n');

% Create designer for Gaussian centered at eigenvalue 100
designer2 = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 500, 'kernel', 'gaussian', 'center', 100, 'bandwidth', 20));

% Initial response
H_bw20 = designer2.evaluateKernel();
fprintf('Gaussian bandpass (center=100, bandwidth=20):\n');
fprintf('  Peak response: %.4f at lambda=%.2f\n', max(H_bw20), ...
    lambda(H_bw20 == max(H_bw20)));

designer2.plotKernelResponse();

% Widen the bandwidth
designer2.setParameter('bandwidth', 50);
H_bw50 = designer2.evaluateKernel();
fprintf('\nGaussian bandpass (center=100, bandwidth=50):\n');
fprintf('  Peak response: %.4f at lambda=%.2f\n', max(H_bw50), ...
    lambda(H_bw50 == max(H_bw50)));

designer2.plotKernelResponse();

% Compare bandwidths
figure('Name', 'Gaussian Bandpass Comparison');
plot(lambda, H_bw20, 'b-', 'LineWidth', 2, 'DisplayName', 'BW=20');
hold on;
plot(lambda, H_bw50, 'r-', 'LineWidth', 2, 'DisplayName', 'BW=50');
grid on;
xlabel('Eigenvalue \lambda');
ylabel('Kernel Response H(\lambda)');
title('Gaussian Bandpass: Effect of Bandwidth');
legend('Location', 'best');

% Preview
designer2.preview();

w_gaussian = designer2.finalize();
fprintf('\nGenerated Gaussian brush: [%d×1]\n', size(w_gaussian, 1));

%% 4. Time-Varying Spectral Brush
fprintf('\n=== Example 3: Time-Varying Heat ===\n');

% Create Time domain
T = 100;
B.Time = bct.Time(T, 'SampleRate', 100);

% Create designer with time-varying tau
% tau increases linearly from 0.1 to 0.4 over time
tau_func = @(t, T) 0.1 + 0.3 * (t-1) / (T-1);

designer3 = bct.brush.design.create('time', 'spectral', B.Manifold, ...
    struct('source', 300, 'kernel', 'heat', 'tau', tau_func), B.Time);

% Evaluate kernel at first time point (tau=0.1)
H_t1 = designer3.evaluateKernel();
fprintf('Time-varying heat at t=1 (tau=0.1):\n');
fprintf('  Modes > 1%% threshold: %d\n', sum(H_t1 > 0.01));

% Change to constant tau
designer3.setParameter('tau', 0.25);
H_const = designer3.evaluateKernel();
fprintf('\nConstant heat (tau=0.25):\n');
fprintf('  Modes > 1%% threshold: %d\n', sum(H_const > 0.01));

% Compare
figure('Name', 'Time-Varying vs Constant');
plot(lambda, H_t1, 'b-', 'LineWidth', 2, 'DisplayName', 'Varying (t=1)');
hold on;
plot(lambda, H_const, 'r-', 'LineWidth', 2, 'DisplayName', 'Constant');
grid on;
xlabel('Eigenvalue \lambda');
ylabel('Kernel Response');
title('Heat Kernel: Time-Varying vs Constant');
legend('Location', 'best');
set(gca, 'YScale', 'log');

% Preview at different time points
figure('Name', 'Time-Varying Preview');
for t_idx = [1, 25, 50, 75, 100]
    subplot(2, 3, find([1, 25, 50, 75, 100] == t_idx));
    designer3.preview('TimeIndex', t_idx);
    title(sprintf('t=%d', t_idx));
end

% Finalize
w_time = designer3.finalize();
fprintf('\nGenerated time-varying brush: [%d×%d]\n', size(w_time, 1), size(w_time, 2));

%% 5. Custom Kernel Evaluation Points
fprintf('\n=== Example 4: Custom Lambda Evaluation ===\n');

% Create designer
designer4 = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 200, 'kernel', 'heat', 'tau', 0.2));

% Evaluate on full Lambda axis
H_full = designer4.evaluateKernel();

% Evaluate on subset of eigenvalues
lambda_subset = linspace(0, max(lambda), 200);
H_subset = designer4.evaluateKernel(lambda_subset);

% Compare
figure('Name', 'Custom Evaluation');
plot(lambda, H_full, 'b.', 'MarkerSize', 8, 'DisplayName', 'Full Lambda');
hold on;
plot(lambda_subset, H_subset, 'r-', 'LineWidth', 2, 'DisplayName', 'Custom Points');
grid on;
xlabel('Eigenvalue \lambda');
ylabel('Kernel Response');
title('Custom Lambda Evaluation');
legend('Location', 'best');
set(gca, 'YScale', 'log');

fprintf('Full evaluation: %d points\n', length(H_full));
fprintf('Custom evaluation: %d points\n', length(H_subset));

%% 6. Parameter Batch Update
fprintf('\n=== Example 5: Batch Parameter Update ===\n');

% Create designer
designer5 = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 400, 'kernel', 'gaussian', 'center', 50, 'bandwidth', 10));

% Initial response
H_initial = designer5.evaluateKernel();
designer5.plotKernelResponse();

% Update multiple parameters at once
new_params = struct('center', 150, 'bandwidth', 30, 'source', 600);
designer5.setParameters(new_params);

H_updated = designer5.evaluateKernel();
designer5.plotKernelResponse();

% Compare
figure('Name', 'Batch Update Comparison');
plot(lambda, H_initial, 'b-', 'LineWidth', 2, 'DisplayName', 'Initial');
hold on;
plot(lambda, H_updated, 'r-', 'LineWidth', 2, 'DisplayName', 'Updated');
grid on;
xlabel('Eigenvalue \lambda');
ylabel('Kernel Response');
title('Effect of Batch Parameter Update');
legend('Location', 'best');

fprintf('Parameters updated successfully\n');

%% Summary
fprintf('\n=== Demo Complete ===\n');
fprintf('BrushDesigner provides:\n');
fprintf('  ✓ Interactive parameter manipulation\n');
fprintf('  ✓ Kernel evaluation on Lambda axis\n');
fprintf('  ✓ Spectral coverage visualization\n');
fprintf('  ✓ Spatial pattern preview\n');
fprintf('  ✓ Flexible finalization workflow\n');
fprintf('\nUse this workflow to tune brush parameters before generating\n');
fprintf('final weights, ensuring desired spectral coverage.\n');
