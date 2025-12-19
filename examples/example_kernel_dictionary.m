%% bct.kernel.dictionary Integration Example
% Demonstrates how dictionary integrates with the kernel package

clear; close all;

%% 1. Get Dictionary
fprintf('=== Dictionary Access ===\n');
D = bct.kernel.dictionary();
fprintf('Dictionary contains %d pure function handles\n', numEntries(D));

% List available kernels
kernelNames = keys(D);
fprintf('First 5 kernels: %s\n', strjoin(kernelNames(1:5), ', '));

%% 2. Direct Function Access
fprintf('\n=== Direct Function Access ===\n');

% Get a kernel function
gaussian = D("Gaussian");
fprintf('Retrieved Gaussian kernel function\n');

% Apply to data
x = linspace(-5, 5, 100);
mu = 0;
sigma = 1;
y = gaussian(x, mu, sigma);

fprintf('Applied Gaussian(x, mu=%.1f, sigma=%.1f)\n', mu, sigma);
fprintf('Output range: [%.4f, %.4f]\n', min(y), max(y));

%% 3. Integration with Registry
fprintf('\n=== Integration with Registry ===\n');

% Registry provides metadata
r = bct.kernel.registry();
fprintf('Registry contains %d kernel definitions\n', length(fieldnames(r)));

% Dictionary provides pure functions
fprintf('Dictionary provides lightweight function access\n');

% Example: Use registry for UI, dictionary for computation
kernelName = "Heat";
meta = r.(kernelName);
func = D(kernelName);

fprintf('\nKernel: %s\n', meta.Name);
fprintf('Equation: %s\n', meta.EquationLatex);
fprintf('Parameters: %s\n', strjoin(meta.ParamNames, ', '));

% Apply function
lambda = linspace(0, 100, 50);
tau = 0.5;
g = func(lambda, tau);
fprintf('Computed heat kernel with tau=%.2f\n', tau);

%% 4. Using bct.kernel.get
fprintf('\n=== Using bct.kernel.get ===\n');

% Unified access through get
f = bct.kernel.get("Gaussian");
y2 = f(x, 0, 1);
fprintf('Got Gaussian via bct.kernel.get()\n');
fprintf('Result matches: %s\n', string(isequal(y, y2)));

%% 5. Composability
fprintf('\n=== Composability ===\n');

% Combine multiple kernels
heat = D("Heat");
mexican_hat = D("SpectralMexicanHat");

% Create composite kernel
composite = @(x, tau1, tau2) heat(x, tau1) + mexican_hat(x, tau2);

lambda = linspace(0, 50, 100);
y_composite = composite(lambda, 0.1, 0.5);

fprintf('Created composite kernel: Heat + SpectralMexicanHat\n');
fprintf('Composite output range: [%.4f, %.4f]\n', ...
    min(y_composite), max(y_composite));

%% 6. Visualization
fprintf('\n=== Visualization ===\n');

figure('Name', 'Kernel Dictionary Examples', 'Position', [100 100 1200 400]);

% Plot several kernels
subplot(1, 3, 1);
x = linspace(-5, 5, 200);
plot(x, D("Gaussian")(x, 0, 1), 'LineWidth', 2);
title('Gaussian');
grid on;

subplot(1, 3, 2);
lambda = linspace(0, 50, 200);
plot(lambda, D("Heat")(lambda, 0.5), 'LineWidth', 2);
title('Heat Kernel');
grid on;

subplot(1, 3, 3);
plot(lambda, D("SpectralMexicanHat")(lambda, 1), 'LineWidth', 2);
title('Spectral Mexican Hat');
grid on;

fprintf('Created visualization of 3 kernels\n');

%% 7. Iterator Pattern
fprintf('\n=== Iterator Pattern ===\n');

% Process multiple kernels
basic_kernels = ["Gaussian", "Heat", "Laplacian", "Cauchy"];
fprintf('Processing basic kernels:\n');

for name = basic_kernels
    if isKey(D, name)
        f = D(name);
        fprintf('  ✓ %s - function ready\n', name);
    else
        fprintf('  ✗ %s - not found\n', name);
    end
end

%% 8. Performance Comparison
fprintf('\n=== Performance ===\n');

% Dictionary access is fast
tic;
for i = 1:1000
    f = D("Gaussian");
end
t_dict = toc;

% Registry access has overhead
tic;
for i = 1:1000
    r = bct.kernel.registry();
    f = r.Gaussian.Function;
end
t_reg = toc;

fprintf('Dictionary access (1000x): %.4f sec\n', t_dict);
fprintf('Registry access (1000x):   %.4f sec\n', t_reg);
fprintf('Speedup: %.1fx\n', t_reg / t_dict);

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('✓ Dictionary provides pure function handles\n');
fprintf('✓ Integrates with registry for metadata\n');
fprintf('✓ Unified access via bct.kernel.get()\n');
fprintf('✓ Lightweight and composable\n');
fprintf('✓ Perfect for UI integration (KernelFactoryUI)\n');
