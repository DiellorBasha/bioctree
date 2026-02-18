function X = generateTestSignal(M, components, t, options)
%GENERATETESTSIGNAL Generate time-varying signal with known spectral content
%
%   X = bct.spectral.generateTestSignal(M, components, t)
%   X = bct.spectral.generateTestSignal(M, components, t, Name, Value)
%
% Purpose
%   Creates a time-varying vertex signal on a manifold with specified
%   eigenmode and temporal frequency content. Useful for testing and
%   validating spectral analysis methods.
%
% Inputs
%   M          - bct.Manifold with precomputed eigenmodes
%   components - [K×3] matrix defining signal components:
%                [eigenmode_idx, freq_Hz, amplitude]
%                Each row is one component
%   t          - [T×1] time vector in seconds
%
% Name-Value Arguments
%   Phase       - [K×1] phase offset for each component (radians, default: 0)
%   NoiseLevel  - Additive Gaussian noise std (default: 0)
%   Modulation  - 'none' | 'amplitude' | 'frequency' (default: 'none')
%   Normalized  - Normalize output to unit variance (default: false)
%
% Output
%   X - [N×T] signal matrix (N vertices, T time samples)
%
% Examples
%   % Single component: eigenmode 100, 10 Hz
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   eigen = M.eigenmodes(500);
%   fs = 100; T = 10;
%   t = (0:1/fs:T-1/fs)';
%   
%   X = bct.spectral.generateTestSignal(M, [100, 10.0, 1.0], t);
%
%   % Multiple components
%   components = [
%       50,   5.0,  1.0;
%       100, 10.0,  0.8;
%       200, 15.0,  0.6;
%   ];
%   X = bct.spectral.generateTestSignal(M, components, t, 'NoiseLevel', 0.1);
%
%   % With phase offsets
%   phases = [0; pi/4; pi/2];
%   X = bct.spectral.generateTestSignal(M, components, t, 'Phase', phases);
%
% See also: bct.spectral.jointSpectrum, bct.Manifold.eigenmodes

arguments
    M bct.Manifold
    components (:,3) double {mustBeNumeric}
    t (:,1) double {mustBeNumeric}
    options.Phase (:,1) double = []
    options.NoiseLevel (1,1) double {mustBeNonnegative} = 0
    options.Modulation (1,1) string {mustBeMember(options.Modulation, ["none", "amplitude", "frequency"])} = "none"
    options.Normalized (1,1) logical = false
end

%% Validate Inputs

% Check manifold has eigenmodes
if ~M.hasCached('eigenmodes')
    error('bct:spectral:NoEigenmodes', ...
        'Manifold has no precomputed eigenmodes. Call M.eigenmodes(K) first.');
end

nComponents = size(components, 1);

% Validate component indices
maxEigenmode = max(components(:,1));
eigen_cached = M.eigenmodes();  % Get cached data
availableEigenmodes = eigen_cached.attributes.numModes;

if maxEigenmode > availableEigenmodes
    error('bct:spectral:InvalidEigenmode', ...
        'Requested eigenmode %d exceeds available eigenmodes (%d)', ...
        maxEigenmode, availableEigenmodes);
end

% Validate phases
if isempty(options.Phase)
    phases = zeros(nComponents, 1);
elseif length(options.Phase) ~= nComponents
    error('bct:spectral:PhaseMismatch', ...
        'Phase vector length (%d) must match number of components (%d)', ...
        length(options.Phase), nComponents);
else
    phases = options.Phase;
end

%% Extract Data

% Get cached eigenmodes
eigen = M.eigenmodes();  % Returns cached data without recomputing
U = eigen.eigenvectors.value;  % [N×K]
nV = M.numVertices();
nT = length(t);

%% Generate Signal

X = zeros(nV, nT);

fprintf('Generating signal with %d components:\n', nComponents);
fprintf('  Component | Eigenmode | Freq (Hz) | Amplitude | Phase (rad)\n');
fprintf('  ----------+-----------+-----------+-----------+------------\n');

for i = 1:nComponents
    eig_idx = round(components(i, 1));
    freq_Hz = components(i, 2);
    amplitude = components(i, 3);
    phase = phases(i);
    
    % Spatial pattern: eigenmode
    spatial = U(:, eig_idx);
    
    % Temporal pattern based on modulation type
    switch options.Modulation
        case 'none'
            % Simple sinusoid
            temporal = amplitude * cos(2*pi*freq_Hz*t + phase);
            
        case 'amplitude'
            % Amplitude modulated
            mod_freq = freq_Hz / 10;  % Modulation at 1/10 carrier frequency
            envelope = 0.5 + 0.5*cos(2*pi*mod_freq*t);
            temporal = amplitude * envelope .* cos(2*pi*freq_Hz*t + phase);
            
        case 'frequency'
            % Frequency modulated (chirp-like)
            freq_deviation = freq_Hz * 0.2;  % ±20% frequency deviation
            instantaneous_freq = freq_Hz + freq_deviation*sin(2*pi*0.5*t);
            phase_integral = 2*pi*cumsum(instantaneous_freq) * (t(2)-t(1));
            temporal = amplitude * cos(phase_integral + phase);
    end
    
    % Add component (outer product)
    X = X + spatial * temporal';
    
    fprintf('  %9d | %9d | %9.2f | %9.3f | %11.3f\n', ...
        i, eig_idx, freq_Hz, amplitude, phase);
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
