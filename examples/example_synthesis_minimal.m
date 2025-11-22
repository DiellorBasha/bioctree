%% Minimal Example: Signal Synthesis with Bct Class
% This demonstrates the complete workflow from filter design to signal generation

%% Load or create Bct object
% Assuming you have a Bct object with Manifold and Time already set
% B = bct('path/to/your/data.h5');

% Or create from scratch:
% M = bct.manifold.Manifold(vertices, faces);
% M.Time = bct.manifold.Time(500, 250);  % 500 samples at 250 Hz
% B = bct();
% B.Manifold = M;

%% Three-step workflow

% STEP 1: Design a spatial filter
% Create bandpass filter for 10-50mm wavelengths
filt = B.designFilter([10, 50], 'wavelength', 'band', ...
    'label', 'alpha_band', 'taper', 'hann');

% STEP 2: Synthesize spectral coefficients
% Generate random spectral coefficients following filter specification
B.Synthesize('alpha_band', ...
    'envelope', 'gaussian', ...  % Gaussian temporal envelope
    't0', 1.0, ...              % Center at 1 second
    'sigma_t', 0.2, ...         % 0.2 second spread
    'velocity', 5, ...          % 5 mm/s traveling wave
    'direction', [1 0 0]);      % Direction in X

% STEP 3: Generate signal in spatial-temporal domain
% Reconstruct signal using inverse graph Fourier + inverse FFT
sig = B.Generate('label', 'my_wave', 'add', true);

% Signal is now in B.Signals(end) and can be accessed as:
% - sig.Data: [N × T] matrix of signal values
% - sig.Label: 'my_wave'
% - sig.Manifold: reference to the manifold

%% Display results
fprintf('Generated signal: %s\n', sig.Label);
fprintf('Size: %d vertices × %d time points\n', sig.N, sig.T);
fprintf('Value range: [%.4f, %.4f]\n', min(sig.Data(:)), max(sig.Data(:)));

%% Alternative: Simpler workflow for standing wave
% Just create a standing wave pattern (no traveling component)
B.designFilter([0.1, 0.5], 'lambda', 'band', 'label', 'simple_wave');
B.Synthesize('simple_wave');  % Use defaults
sig2 = B.Generate('label', 'standing_wave');

%% Alternative: Using wavenumber or frequency specifications
% Design using wavenumber (rad/mm)
B.designFilter([0.2, 1.0], 'wavenumber', 'band', 'label', 'beta');
B.Synthesize('beta');
sig3 = B.Generate('label', 'beta_wave');

% Or using spatial frequency (cycles/mm)
B.designFilter([0.05, 0.15], 'freq', 'band', 'label', 'gamma');
B.Synthesize('gamma');
sig4 = B.Generate('label', 'gamma_wave');

