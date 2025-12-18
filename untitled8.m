%% Create delta signal (impulse at single vertex)
seed_vertex = 300;  % Choose your seed vertex

% Create delta signal: 1 at seed, 0 elsewhere
delta = zeros(fs6.Manifold.N, 1);
delta(seed_vertex) = 1;

% Create Signal object
sig_delta = bct.Signal(delta, fs6.Manifold);
sig_delta.Meta.Description = sprintf('Delta function at vertex %d', seed_vertex);

%% Visualize spatial domain (delta signal on mesh)
viewer.setScalarField(sig_delta.Data);
viewer.setColormap('jet');
viewer.showColorbar();
viewer.setTitle(sprintf('Delta signal δ(x - x_%d)', seed_vertex));



%% Transform to spectral domain (MFT)
sig_spectral = bct.operator.transform.mft(sig_delta);

fprintf('Delta signal transformed:\n');
fprintf('  Spatial: [%d × 1]\n', sig_delta.N);
fprintf('  Spectral: [%d × 1]\n', length(sig_spectral.Data));

%% Visualize eigenspectrum
figure('Position', [100 100 1200 800], 'Color', 'w');

% Multiple views of the spectrum
subplot(2, 3, 1);
bct.show.eigenspectrum(sig_spectral, ...
    'PlotType', 'power', ...
    'XAxisUnits', 'eigenvalue');

subplot(2, 3, 2);
bct.show.eigenspectrum(sig_spectral, ...
    'PlotType', 'power', ...
    'XAxisUnits', 'wavenumber');

subplot(2, 3, 3);
bct.show.eigenspectrum(sig_spectral, ...
    'PlotType', 'loglog', ...
    'XAxisUnits', 'eigenvalue');

subplot(2, 3, 4);
bct.show.eigenspectrum(sig_spectral, ...
    'PlotType', 'index', ...
    'TopModes', 20);

subplot(2, 3, 5);
bct.show.eigenspectrum(sig_spectral, ...
    'PlotType', 'bands', ...
    'XAxisUnits', 'wavelength');

subplot(2, 3, 6);
% Show spectral coefficients (real and imaginary)
coeffs = sig_spectral.Data;
plot(1:length(coeffs), real(coeffs), 'b-', 'LineWidth', 1.5);
hold on;
plot(1:length(coeffs), imag(coeffs), 'r-', 'LineWidth', 1.5);
legend('Real', 'Imag');
grid on;
xlabel('Eigenmode index');
ylabel('Coefficient value');
title('Spectral coefficients');

sgtitle(sprintf('Eigenspectrum of delta function at vertex %d', seed_vertex));

%% Verify reconstruction (inverse MFT)
sig_reconstructed = bct.operator.transform.imft(sig_spectral);

reconstruction_error = norm(sig_delta.Data - sig_reconstructed.Data) / norm(sig_delta.Data);
fprintf('\nReconstruction error: %.2e\n', reconstruction_error);

% Visualize reconstruction
viewer.setScalarField(sig_reconstructed.Data);
viewer.setTitle(sprintf('Reconstructed delta (error = %.2e)', reconstruction_error));