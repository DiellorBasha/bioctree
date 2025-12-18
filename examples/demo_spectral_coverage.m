%DEMO_SPECTRAL_COVERAGE  Demonstrates evaluating kernels on Lambda to check spectral coverage
%
% This is the exact use case: "take a spectral heat kernel and evaluate it 
% on the Lambda axis to see how it covers the eigenspace"

clearvars; clc;
bioctree_start;

%% Setup
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

lambda = B.Manifold.dual.lambda;
fprintf('Lambda domain: %d eigenvalues\n', length(lambda));
fprintf('Range: [%.4f, %.4f]\n', min(lambda), max(lambda));

%% Examine Heat Kernel Coverage at Different Tau Values

% Create designer for heat kernel
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 100, 'kernel', 'heat', 'tau', 0.05));

% Test multiple tau values to see eigenspace coverage
tau_values = [0.05, 0.1, 0.2, 0.4, 0.8];
coverage_results = struct();

figure('Name', 'Heat Kernel Coverage Analysis');

for i = 1:length(tau_values)
    tau = tau_values(i);
    designer.setParameter('tau', tau);
    H = designer.evaluateKernel();
    
    % Compute coverage metrics
    coverage_results(i).tau = tau;
    coverage_results(i).max_response = max(H);
    coverage_results(i).min_response = min(H);
    coverage_results(i).modes_1pct = sum(H > 0.01);      % 1% threshold
    coverage_results(i).modes_10pct = sum(H > 0.10);     % 10% threshold
    coverage_results(i).modes_50pct = sum(H > 0.50);     % 50% threshold
    coverage_results(i).effective_bandwidth = sum(H) / max(H);  % Approximate
    
    % Plot
    subplot(2, 3, i);
    plot(lambda, H, 'b-', 'LineWidth', 2);
    hold on;
    yline(0.01, 'r--', '1%');
    yline(0.10, 'g--', '10%');
    grid on;
    xlabel('\lambda');
    ylabel('H(\lambda)');
    title(sprintf('\\tau = %.2f', tau));
    set(gca, 'YScale', 'log');
    ylim([1e-6, 1.5]);
end

% Summary table
fprintf('\n=== Coverage Analysis ===\n');
fprintf('%-8s | %-8s | %-8s | %-8s | %-12s\n', ...
    'Tau', '>1%', '>10%', '>50%', 'Eff. BW');
fprintf('%s\n', repmat('-', 1, 60));
for i = 1:length(coverage_results)
    fprintf('%-8.2f | %-8d | %-8d | %-8d | %-12.1f\n', ...
        coverage_results(i).tau, ...
        coverage_results(i).modes_1pct, ...
        coverage_results(i).modes_10pct, ...
        coverage_results(i).modes_50pct, ...
        coverage_results(i).effective_bandwidth);
end

%% Compare Low-Frequency vs High-Frequency Coverage

% Low tau = sharp in space, broad in Lambda (many modes)
designer.setParameter('tau', 0.05);
H_sharp = designer.evaluateKernel();

% High tau = smooth in space, narrow in Lambda (few modes)
designer.setParameter('tau', 0.5);
H_smooth = designer.evaluateKernel();

figure('Name', 'Sharp vs Smooth Coverage');

subplot(2,2,1);
plot(lambda, H_sharp, 'b-', 'LineWidth', 2);
grid on; xlabel('\lambda'); ylabel('H(\lambda)');
title('Sharp (\tau=0.05) - Broad Coverage');
set(gca, 'YScale', 'log');

subplot(2,2,2);
plot(lambda, H_smooth, 'r-', 'LineWidth', 2);
grid on; xlabel('\lambda'); ylabel('H(\lambda)');
title('Smooth (\tau=0.5) - Narrow Coverage');
set(gca, 'YScale', 'log');

% Preview spatial patterns
designer.setParameter('tau', 0.05);
designer.preview();
set(gcf, 'Name', 'Sharp Pattern (tau=0.05)');

designer.setParameter('tau', 0.5);
designer.preview();
set(gcf, 'Name', 'Smooth Pattern (tau=0.5)');

fprintf('\nSharp pattern (tau=0.05): %d modes > 1%%\n', sum(H_sharp > 0.01));
fprintf('Smooth pattern (tau=0.5): %d modes > 1%%\n', sum(H_smooth > 0.01));

%% Find Optimal Tau for Desired Coverage

% Goal: Find tau that gives ~50 modes with >1% response
target_modes = 50;

tau_search = linspace(0.05, 0.8, 50);
mode_counts = zeros(size(tau_search));

for i = 1:length(tau_search)
    designer.setParameter('tau', tau_search(i));
    H = designer.evaluateKernel();
    mode_counts(i) = sum(H > 0.01);
end

% Find closest to target
[~, idx_best] = min(abs(mode_counts - target_modes));
tau_optimal = tau_search(idx_best);

figure('Name', 'Tau Optimization');
plot(tau_search, mode_counts, 'b-', 'LineWidth', 2);
hold on;
yline(target_modes, 'r--', sprintf('Target: %d modes', target_modes));
plot(tau_optimal, mode_counts(idx_best), 'ro', 'MarkerSize', 12, ...
    'LineWidth', 2, 'DisplayName', sprintf('Optimal \\tau=%.3f', tau_optimal));
grid on;
xlabel('\tau');
ylabel('Number of Modes > 1%');
title('Finding Optimal \tau for Target Coverage');
legend('Location', 'best');

fprintf('\n=== Optimization Result ===\n');
fprintf('Target modes: %d\n', target_modes);
fprintf('Optimal tau: %.4f\n', tau_optimal);
fprintf('Achieved modes: %d\n', mode_counts(idx_best));

% Verify with designer
designer.setParameter('tau', tau_optimal);
designer.plotKernelResponse();
designer.preview();

%% Gaussian Bandpass Coverage

fprintf('\n=== Gaussian Bandpass Coverage ===\n');

% Design bandpass centered at different eigenvalues
centers = [20, 50, 100, 200];
bandwidth = 30;

figure('Name', 'Gaussian Bandpass Coverage');
for i = 1:length(centers)
    designer_bp = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
        struct('source', 100, 'kernel', 'gaussian', 'center', centers(i), 'bandwidth', bandwidth));
    
    H = designer_bp.evaluateKernel();
    
    subplot(2, 2, i);
    plot(lambda, H, 'b-', 'LineWidth', 2);
    hold on;
    xline(centers(i), 'r--', 'Center');
    grid on;
    xlabel('\lambda');
    ylabel('H(\lambda)');
    title(sprintf('Center = %d', centers(i)));
    
    fprintf('Center=%d: Peak at lambda=%.2f, modes>10%% = %d\n', ...
        centers(i), lambda(H == max(H)), sum(H > 0.1));
end

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('Use BrushDesigner to:\n');
fprintf('  1. Evaluate kernel on Lambda axis\n');
fprintf('  2. Check spectral coverage (modes above threshold)\n');
fprintf('  3. Adjust parameters to achieve desired coverage\n');
fprintf('  4. Preview spatial pattern\n');
fprintf('  5. Finalize when satisfied\n');
fprintf('\nKey metrics:\n');
fprintf('  - Number of modes above threshold (1%%, 10%%, 50%%)\n');
fprintf('  - Effective bandwidth (sum/max)\n');
fprintf('  - Peak location on Lambda axis\n');
