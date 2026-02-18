function X = generateBandedSignal(M, bands, t, options)
%GENERATEBANDEDSIGNAL Generate signal with eigenmode and frequency bands
%
%   X = bct.spectral.generateBandedSignal(M, bands, t)
%   X = bct.spectral.generateBandedSignal(M, bands, t, Name, Value)
%
% Purpose
%   Creates a time-varying vertex signal with specified bands of eigenmodes
%   and temporal frequencies. More realistic than discrete components for
%   modeling brain activity with characteristic spatial and temporal scales.
%
% Inputs
%   M     - bct.Manifold with precomputed eigenmodes
%   bands - Struct array defining bands with fields:
%           .eigenmodeRange - [kmin, kmax] eigenmode index range
%           .freqRange      - [fmin, fmax] temporal frequency range (Hz)
%           .amplitude      - Overall amplitude for this band
%   t     - [T×1] time vector in seconds
%
% Name-Value Arguments
%   NumComponents   - Number of random components per band (default: 10)
%   Distribution    - Amplitude distribution: 'uniform' | 'gaussian' (default)
%   PhaseRandom     - Randomize phases (default: true)
%   NoiseLevel      - Additive Gaussian noise std (default: 0)
%   Normalized      - Normalize to unit variance (default: false)
%   RandomSeed      - Fix random seed for reproducibility (default: [])
%
% Output
%   X - [N×T] signal matrix (N vertices, T time samples)
%
% Examples
%   % Single band: low spatial freq (modes 1-100), alpha (8-12 Hz)
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   eigen = M.eigenmodes(500);
%   fs = 100; T = 10;
%   t = (0:1/fs:T-1/fs)';
%   
%   bands(1).eigenmodeRange = [1, 100];
%   bands(1).freqRange = [8, 12];
%   bands(1).amplitude = 1.0;
%   
%   X = bct.spectral.generateBandedSignal(M, bands, t);
%
%   % Multiple bands: alpha in low modes, beta in high modes
%   bands(1).eigenmodeRange = [1, 100];    % Low spatial freq
%   bands(1).freqRange = [8, 12];          % Alpha band
%   bands(1).amplitude = 1.0;
%   
%   bands(2).eigenmodeRange = [200, 400];  % Higher spatial freq
%   bands(2).freqRange = [15, 30];         % Beta band
%   bands(2).amplitude = 0.7;
%   
%   X = bct.spectral.generateBandedSignal(M, bands, t, 'NumComponents', 20);
%
%   % Reproducible signal
%   X = bct.spectral.generateBandedSignal(M, bands, t, 'RandomSeed', 42);
%
% See also: bct.spectral.generateTestSignal, bct.spectral.jointSpectrum

arguments
    M bct.Manifold
    bands struct
    t (:,1) double {mustBeNumeric}
    options.NumComponents (1,1) {mustBeInteger, mustBePositive} = 10
    options.Distribution (1,1) string {mustBeMember(options.Distribution, ["uniform", "gaussian"])} = "gaussian"
    options.PhaseRandom (1,1) logical = true
    options.NoiseLevel (1,1) double {mustBeNonnegative} = 0
    options.Normalized (1,1) logical = false
    options.RandomSeed {mustBeInteger} = []
end

%% Validate Inputs

% Check manifold has eigenmodes
if ~M.hasCached('eigenmodes')
    error('bct:spectral:NoEigenmodes', ...
        'Manifold has no precomputed eigenmodes. Call M.eigenmodes(K) first.');
end

% Validate bands structure
required_fields = {'eigenmodeRange', 'freqRange', 'amplitude'};
for i = 1:length(bands)
    for j = 1:length(required_fields)
        if ~isfield(bands(i), required_fields{j})
            error('bct:spectral:InvalidBands', ...
                'Band %d missing required field: %s', i, required_fields{j});
        end
    end
end

% Set random seed if provided
if ~isempty(options.RandomSeed)
    rng(options.RandomSeed);
end

%% Extract Data

% Get cached eigenmodes
eigen = M.eigenmodes();
U = eigen.eigenvectors.value;  % [N×K]
nV = M.numVertices();
nT = length(t);
K_available = eigen.attributes.numModes;

%% Generate Signal

X = zeros(nV, nT);

fprintf('Generating banded signal with %d band(s):\n', length(bands));
fprintf('  Band | Eigenmode Range | Freq Range (Hz) | Amplitude | Components\n');
fprintf('  -----+-----------------+-----------------+-----------+-----------\n');

for b = 1:length(bands)
    % Extract band parameters
    eig_range = bands(b).eigenmodeRange;
    freq_range = bands(b).freqRange;
    amp = bands(b).amplitude;
    
    % Validate ranges
    if eig_range(2) > K_available
        warning('bct:spectral:EigenmodeRangeExceeded', ...
            'Band %d eigenmode range [%d, %d] exceeds available modes (%d), truncating', ...
            b, eig_range(1), eig_range(2), K_available);
        eig_range(2) = K_available;
    end
    
    % Generate random components within this band
    nComp = options.NumComponents;
    
    % Random eigenmode indices within range
    eig_indices = randi([eig_range(1), eig_range(2)], nComp, 1);
    
    % Random frequencies within range
    freqs = freq_range(1) + (freq_range(2) - freq_range(1)) * rand(nComp, 1);
    
    % Random amplitudes
    switch options.Distribution
        case 'uniform'
            amplitudes = amp * rand(nComp, 1);
        case 'gaussian'
            amplitudes = amp * abs(randn(nComp, 1));
            amplitudes = amplitudes / mean(amplitudes);  % Normalize mean to amp
    end
    
    % Random phases
    if options.PhaseRandom
        phases = 2*pi * rand(nComp, 1);
    else
        phases = zeros(nComp, 1);
    end
    
    % Add components to signal
    for c = 1:nComp
        % Spatial pattern
        spatial = U(:, eig_indices(c));
        
        % Temporal pattern
        temporal = amplitudes(c) * cos(2*pi*freqs(c)*t + phases(c));
        
        % Add to signal
        X = X + spatial * temporal';
    end
    
    fprintf('  %4d | [%4d, %4d]    | [%5.1f, %5.1f]  | %9.3f | %10d\n', ...
        b, eig_range(1), eig_range(2), freq_range(1), freq_range(2), amp, nComp);
end

%% Add Noise

if options.NoiseLevel > 0
    noise = options.NoiseLevel * randn(nV, nT);
    X = X + noise;
    fprintf('Added Gaussian noise: std = %.4f\n', options.NoiseLevel);
end

%% Normalize

if options.Normalized
    X = X / std(X(:));
    fprintf('Normalized to unit variance\n');
end

fprintf('Signal generated: [%d × %d] (vertices × time)\n', size(X, 1), size(X, 2));

end
