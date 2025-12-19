%% Advanced Kernel Functions Example
% Demonstrates Hermite, Meyer, Daubechies, and Slepian kernels
% Shows the distinction between analytic kernels and operator-defined generators

clear; close all;

%% Setup
fprintf('=== BCT Advanced Kernels Demo ===\n\n');

%% 1. Hermite Functions (Analytic, Closed-Form)
fprintf('1. HERMITE FUNCTIONS\n');
fprintf('   Quantum harmonic oscillator eigenstates\n');
fprintf('   True continuous basis with perfect balance\n\n');

% Get Hermite kernel from dictionary
hermite = bct.kernel.get("Hermite");

% Evaluate for different orders
x = linspace(-5, 5, 500);

figure('Name', 'Hermite Functions', 'Position', [100 100 1200 400]);

for n = 0:3
    subplot(1,4,n+1);
    psi_n = hermite(x, n);
    plot(x, psi_n, 'LineWidth', 2);
    grid on;
    title(sprintf('\\psi_%d(x) - Order %d', n, n));
    xlabel('x');
    ylabel('\psi(x)');
    
    if n == 0
        annotation('textbox', [0.15 0.02 0.2 0.05], ...
            'String', 'n=0: Gaussian ground state', ...
            'EdgeColor', 'none', 'FontSize', 9);
    end
end

sgtitle('Hermite Functions: Increasing Complexity with Perfect Balance');

fprintf('   ✓ n=0: Gaussian (most balanced)\n');
fprintf('   ✓ Increasing n → more oscillations\n');
fprintf('   ✓ Orthogonal basis functions\n\n');

%% 2. Meyer Wavelet (Frequency-Domain Analytic)
fprintf('2. MEYER WAVELET\n');
fprintf('   Infinitely smooth, compact in frequency\n');
fprintf('   Ideal spectral filter for λ-space\n\n');

% Get Meyer frequency response
meyerHat = bct.kernel.get("MeyerHat");

% Evaluate in frequency domain
w = linspace(-4*pi, 4*pi, 1000);
Y = meyerHat(w);

figure('Name', 'Meyer Wavelet', 'Position', [100 200 1200 400]);

subplot(1,2,1);
plot(w/pi, abs(Y), 'LineWidth', 2);
grid on;
title('Meyer Wavelet - Magnitude Spectrum');
xlabel('\omega / \pi');
ylabel('|\Psi(\omega)|');
xlim([-4 4]);

subplot(1,2,2);
plot(w/pi, angle(Y), 'LineWidth', 2);
grid on;
title('Meyer Wavelet - Phase');
xlabel('\omega / \pi');
ylabel('Phase (rad)');
xlim([-4 4]);

sgtitle('Meyer Wavelet: Perfect Spectral Localization');

fprintf('   ✓ Compact support in frequency: [2π/3, 8π/3]\n');
fprintf('   ✓ Infinitely smooth transitions\n');
fprintf('   ✓ Apply on eigenvalue (λ) axis for spectral filtering\n\n');

%% 3. Daubechies Wavelets (Operator-Defined, No Closed Form)
fprintf('3. DAUBECHIES WAVELETS\n');
fprintf('   Discrete basis generators\n');
fprintf('   Defined by filter coefficients\n\n');

% Get Daubechies generator
dbGenerator = bct.kernel.get("Daubechies", 'Type', 'generator');

% Generate db2, db4, db8
figure('Name', 'Daubechies Wavelets', 'Position', [100 300 1200 400]);

orders = [2, 4, 8];
for i = 1:3
    N = orders(i);
    [phi, psi, xval] = dbGenerator(N);
    
    subplot(2,3,i);
    plot(xval, phi, 'LineWidth', 2);
    grid on;
    title(sprintf('db%d Scaling Function', N));
    xlabel('x');
    ylabel('\phi(x)');
    
    subplot(2,3,i+3);
    plot(xval, psi, 'LineWidth', 2);
    grid on;
    title(sprintf('db%d Wavelet', N));
    xlabel('x');
    ylabel('\psi(x)');
end

sgtitle('Daubechies Wavelets: Compact Support, Increasing Vanishing Moments');

fprintf('   ✓ No closed-form expression\n');
fprintf('   ✓ Compact support\n');
fprintf('   ✓ Increasing N → more vanishing moments\n');
fprintf('   ✓ For use: [C,L] = wavedec(signal, level, ''db4'')\n\n');

%% 4. Slepian Functions (Optimal Concentration)
fprintf('4. SLEPIAN FUNCTIONS (DPSS)\n');
fprintf('   Eigenfunctions of band-limited operator\n');
fprintf('   Optimal time-frequency concentration\n\n');

% Get Slepian generator
slepianGen = bct.kernel.get("Slepian", 'Type', 'generator');

% Generate Slepian sequences
N = 512;      % Sequence length
NW = 4;       % Time-bandwidth product
K = 8;        % Number of sequences

[v, lambda] = slepianGen(N, NW, K);

figure('Name', 'Slepian Sequences', 'Position', [100 400 1200 600]);

% Time-domain sequences
subplot(2,2,1);
plot(v(:,1:4), 'LineWidth', 1.5);
grid on;
title('First 4 Slepian Sequences (Time Domain)');
xlabel('Sample');
ylabel('Amplitude');
legend(arrayfun(@(k) sprintf('k=%d', k), 1:4, 'UniformOutput', false));

% Concentration eigenvalues
subplot(2,2,2);
stem(1:K, lambda, 'filled', 'LineWidth', 1.5);
grid on;
title('Concentration Eigenvalues');
xlabel('Index k');
ylabel('\lambda_k (Concentration Ratio)');
ylim([0 1.1]);

% Frequency response
subplot(2,2,3);
f = linspace(-0.5, 0.5, 1024);
V = fft(v, 1024);
plot(f, abs(fftshift(V(:,1:4))), 'LineWidth', 1.5);
grid on;
title('Frequency Response (First 4)');
xlabel('Normalized Frequency');
ylabel('Magnitude');

% Energy concentration
subplot(2,2,4);
bandwidth = NW/N;
inBand = abs(f) <= bandwidth;
energy = sum(abs(fftshift(V)).^2, 1);
energyInBand = sum(abs(fftshift(V(inBand,:))).^2, 1);
concentration = energyInBand ./ energy;

plot(1:K, concentration, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
grid on;
title('Measured Energy Concentration');
xlabel('Sequence Index');
ylabel('Fraction in Band');
ylim([0 1.1]);

sgtitle(sprintf('Slepian Functions: N=%d, NW=%d (Optimal for Bounded Domains)', N, NW));

fprintf('   ✓ Ordered by concentration ratio\n');
fprintf('   ✓ First K sequences optimally concentrated\n');
fprintf('   ✓ Gold standard for bounded meshes\n');
fprintf('   ✓ Manifold analogue: eigenfunctions of band-limited Laplacian\n\n');

%% 5. Kernel Taxonomy Summary
fprintf('=== KERNEL TAXONOMY ===\n\n');

fprintf('ANALYTIC (bct.kernel.dictionary):\n');
analyticKernels = bct.kernel.list('Type', 'analytic');
fprintf('   • %s\n', strjoin(analyticKernels(contains(analyticKernels, ["Hermite", "Meyer"])), ', '));
fprintf('   → Closed-form expressions\n');
fprintf('   → Pure function handles\n\n');

fprintf('GENERATORS (bct.kernel.generators):\n');
generators = bct.kernel.list('Type', 'generator');
fprintf('   • %s\n', strjoin(generators(contains(generators, ["Daubechies", "Slepian"])), ', '));
fprintf('   → Operator-defined\n');
fprintf('   → Factory functions\n\n');

fprintf('KEY INSIGHT:\n');
fprintf('   "The most balanced functions are eigenfunctions of\n');
fprintf('    symmetry-defining operators. Analytic kernels approximate\n');
fprintf('    this balance; Slepian and Hermite achieve it optimally."\n\n');

%% 6. Practical Usage Examples
fprintf('=== PRACTICAL USAGE ===\n\n');

fprintf('% Analytic kernel (direct application)\n');
fprintf('gaussian = bct.kernel.get("Gaussian");\n');
fprintf('y = gaussian(eigenvalues, mu, sigma);\n\n');

fprintf('% Hermite basis expansion\n');
fprintf('hermite = bct.kernel.get("Hermite");\n');
fprintf('for n = 0:10\n');
fprintf('    basis(:,n+1) = hermite(x, n);\n');
fprintf('end\n\n');

fprintf('% Meyer spectral filter\n');
fprintf('meyer = bct.kernel.get("MeyerHat");\n');
fprintf('spectralFilter = meyer(eigenvalues);\n');
fprintf('filtered = spectralFilter .* signalSpectrum;\n\n');

fprintf('% Daubechies wavelet decomposition\n');
fprintf('[C,L] = wavedec(signal, 4, ''db4'');\n\n');

fprintf('% Slepian multitaper\n');
fprintf('slepian = bct.kernel.get("Slepian");\n');
fprintf('[tapers, concentrations] = slepian(N, NW, K);\n');
fprintf('spectrum = mtm_spectrum(signal, tapers);\n\n');

fprintf('Demo complete!\n');
