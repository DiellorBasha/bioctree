function spectrum = jointSpectrum(M, F, options)
%JOINTSPECTRUM Compute joint lambda-omega Fourier transform for time-varying field
%
%   spectrum = bct.spectral.jointSpectrum(M, F)
%   spectrum = bct.spectral.jointSpectrum(M, F, Name, Value)
%
% Purpose
%   Computes the joint time-vertex Fourier transform of a time-varying
%   scalar field defined on a manifold. This transforms the signal into
%   a 2D representation showing energy distribution across both eigenmode
%   indices (lambda) and temporal frequencies (omega).
%
% Inputs
%   M - bct.Manifold object with precomputed eigenmodes
%   F - Time-varying scalar Field struct (from bct.fields.make)
%
% Name-Value Arguments
%   NumEigenmodes   - Number of eigenmodes to use (default: all available)
%   TemporalFFT     - FFT size for temporal dimension (default: nT)
%   Normalize       - Normalize spectrum (default: true)
%   ReturnComplex   - Return complex spectrum (default: false, returns magnitude)
%
% Output
%   spectrum - Struct with fields:
%       .magnitude      - [K×F] magnitude spectrum (abs(Xhat))
%       .complex        - [K×F] complex spectrum (if ReturnComplex=true)
%       .eigenvalues    - [K×1] eigenvalues used
%       .frequencies    - [1×F] frequency axis (Hz)
%       .eigenmodeAxis  - [K×1] eigenmode indices
%       .powerEigen     - [K×1] marginal power spectrum over eigenmodes
%       .powerFreq      - [1×F] marginal power spectrum over frequencies
%
%   Where K = number of eigenmodes, F = number of frequencies
%
% Algorithm
%   Following gsp_jft (GSPBox):
%   1. Graph Fourier Transform: X_graph = U' * Mass * X
%   2. Temporal Fourier Transform: X_joint = fft(X_graph, NFFT, 2)
%   3. Result: Xhat(k,f) represents energy in eigenmode k and frequency f
%
% Requirements
%   - F must be time-varying scalar vertex field
%   - M must have eigenmodes precomputed (M.eigenmodes(K))
%   - F.time must contain valid time metadata
%
% Examples
%   % Basic usage
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   eigen = M.eigenmodes(500);
%   
%   % Create time-varying signal
%   fs = 100; T = 10; nT = fs*T;
%   t = (0:1/fs:T-1/fs)';
%   X = randn(M.numVertices(), nT);
%   F = bct.field.make('support', 'vertex', 'valueType', 'scalar', ...
%                       'value', X, 'time', struct('t0', 0, 'dt', 1/fs, 'unit', 's'));
%   
%   % Compute joint spectrum
%   spec = bct.spectral.jointSpectrum(M, F);
%   
%   % Visualize
%   figure;
%   imagesc(spec.frequencies, spec.eigenmodeAxis, log10(spec.magnitude + eps));
%   axis xy; colorbar;
%   xlabel('Frequency (Hz)'); ylabel('Eigenmode Index');
%   title('Joint \lambda-\omega Spectrum');
%
%   % Custom parameters
%   spec = bct.spectral.jointSpectrum(M, F, 'NumEigenmodes', 200, ...
%                                        'TemporalFFT', 2048);
%
% See also: bct.field.make, bct.Manifold.eigenmodes, bct.filter.analysis

arguments
    M bct.Manifold
    F struct
    options.NumEigenmodes {mustBeInteger, mustBePositive} = []
    options.TemporalFFT {mustBeInteger, mustBePositive} = []
    options.Normalize (1,1) logical = true
    options.ReturnComplex (1,1) logical = false
end

%% Validate Inputs

% Check field is time-varying scalar vertex field
if ~bct.field.isTimeVarying(F)
    error('bct:spectral:NotTimeVarying', ...
        'Field must be time-varying for joint spectrum computation');
end

if ~strcmp(F.support, 'vertex')
    error('bct:spectral:InvalidSupport', ...
        'Field must have vertex support (got: %s)', F.support);
end

if ~strcmp(F.valueType, 'scalar')
    error('bct:spectral:InvalidValueType', ...
        'Field must be scalar (got: %s)', F.valueType);
end

% Check manifold has eigenmodes
if ~M.hasCached('eigenmodes')
    error('bct:spectral:NoEigenmodes', ...
        'Manifold has no precomputed eigenmodes. Call M.eigenmodes(K) first.');
end

%% Extract Data

% Get cached eigenmodes
eigen = M.eigenmodes();  % Returns cached data without recomputing
U = eigen.eigenvectors.value;   % [nV × K]
lambda = eigen.eigenvalues.value;  % [K × 1]
nV = M.numVertices();
K_available = length(lambda);

% Determine number of eigenmodes to use
if isempty(options.NumEigenmodes)
    K = K_available;
else
    K = min(options.NumEigenmodes, K_available);
end

% Truncate to requested number
U = U(:, 1:K);
lambda = lambda(1:K);

% Get signal
X = F.value;  % [nV × nT]
[nV_sig, nT] = size(X);

if nV_sig ~= nV
    error('bct:spectral:SizeMismatch', ...
        'Field size (%d) does not match manifold vertices (%d)', nV_sig, nV);
end

% Get mass matrix
ops = M.operators();
Mass = ops.mass.value;  % Extract sparse matrix from dataset structure

% Get temporal parameters
if isfield(F, 'time') && ~isempty(F.time)
    dt = F.time.dt;
    fs = 1 / dt;  % Sampling frequency
else
    warning('bct:spectral:NoTimeMetadata', ...
        'Field missing time metadata, assuming dt=1, fs=1');
    dt = 1;
    fs = 1;
end

% Determine FFT size
if isempty(options.TemporalFFT)
    NFFT = nT;
else
    NFFT = options.TemporalFFT;
end

%% Compute Joint Spectrum

% Step 1: Graph Fourier Transform (project onto eigenmodes)
% X_graph = U' * Mass * X    [K × nT]
X_graph = U' * Mass * X;

% Step 2: Temporal Fourier Transform
% X_joint = fft(X_graph, NFFT, 2)    [K × NFFT]
X_joint = fft(X_graph, NFFT, 2);

% Normalize if requested
if options.Normalize
    X_joint = X_joint / sqrt(NFFT);
end

% Magnitude spectrum
Xhat_mag = abs(X_joint);

%% Compute Frequency Axis

% Frequency vector (Hz)
freqs = (0:NFFT-1) * (fs / NFFT);

%% Compute Marginal Spectra

% Power spectrum over eigenmodes (sum over frequencies)
powerEigen = sum(abs(X_joint).^2, 2);  % [K × 1]

% Power spectrum over frequencies (sum over eigenmodes)
powerFreq = sum(abs(X_joint).^2, 1);   % [1 × NFFT]

%% Package Output

spectrum = struct();

% Main spectrum
spectrum.magnitude = Xhat_mag;          % [K × NFFT]

if options.ReturnComplex
    spectrum.complex = X_joint;         % [K × NFFT]
end

% Axes
spectrum.eigenvalues = lambda;          % [K × 1]
spectrum.frequencies = freqs;           % [1 × NFFT]
spectrum.eigenmodeAxis = (1:K)';        % [K × 1]

% Marginals
spectrum.powerEigen = powerEigen;       % [K × 1]
spectrum.powerFreq = powerFreq;         % [1 × NFFT]

% Metadata
spectrum.numEigenmodes = K;
spectrum.numFrequencies = NFFT;
spectrum.samplingFreq = fs;
spectrum.timeStep = dt;
spectrum.numTimeSamples = nT;

end
