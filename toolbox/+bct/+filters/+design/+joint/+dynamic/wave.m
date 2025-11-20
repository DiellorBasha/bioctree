function filt = wave(bct_obj, varargin)
%WAVE Design wave-coupled spatiotemporal filter
%
%   Creates a joint mesh-time filter with wave propagation dispersion:
%       W(λ,t) = cos(√λ·t/v) * ψ_mesh(λ) * φ_time(t)
%
%   The filter combines:
%     - Spatial kernel ψ_mesh: Wavelet on mesh spectrum
%     - Temporal kernel φ_time: Wavelet in time
%     - Dispersion K(λ,t): Wave propagation kernel cos(√λ·t/v)
%
%   Syntax:
%     filt = bct.filters.design.wave(B)
%     filt = bct.filters.design.wave(B, 'param', value, ...)
%
%   Inputs:
%     bct_obj - bct.bct object with Manifold and Time
%
%   Parameters:
%     'lambda_band'  - Spatial frequency band [lambda_min, lambda_max]
%                      Default: [0, 5]
%     'freq_band'    - Temporal frequency band [f_min, f_max] in Hz
%                      Default: [8, 12]
%     'sx'           - Spatial scale parameter
%                      Default: 5
%     'st'           - Temporal scale parameter
%                      Default: 20
%     'omega0'       - Center frequency for temporal wavelet (rad/s)
%                      Default: 2*pi*10
%     'freq_hz'      - Center frequency in Hz (alternative to omega0)
%     'velocity'     - Wave propagation velocity
%                      Default: 1.0
%     'spatial_kernel'  - Spatial kernel type
%                      Default: 'morlet'
%     'temporal_kernel' - Temporal kernel type
%                      Default: 'morlet'
%     'numModes'     - Number of eigenmodes to compute
%
%   Returns:
%     filt - bct.filters.JointFilter object with wave dispersion
%
%   Example:
%     % Design traveling wave filter
%     filt = bct.filters.design.wave(B, ...
%         'lambda_band', [1, 10], ...
%         'freq_hz', 10, ...
%         'velocity', 0.5, ...
%         'sx', 3, 'st', 0.04);
%     
%     filt.synthesize();
%     filt.plotJoint();
%
%   See also: bct.filters.JointFilter, bct.filters.design.diffusion

% Copyright (c) 2025 BioCTree Project

%% Parse inputs
p = inputParser;
addRequired(p, 'bct_obj');
addParameter(p, 'lambda_band', [0, 5], @(x) isnumeric(x) && numel(x)==2);
addParameter(p, 'freq_band', [8, 12], @(x) isnumeric(x) && numel(x)==2);
addParameter(p, 'sx', 5, @isnumeric);
addParameter(p, 'st', 20, @isnumeric);
addParameter(p, 'omega0', 2*pi*10, @isnumeric);
addParameter(p, 'freq_hz', [], @isnumeric);
addParameter(p, 'velocity', 1.0, @isnumeric);
addParameter(p, 'spatial_kernel', 'morlet', @ischar);
addParameter(p, 'temporal_kernel', 'morlet', @ischar);
addParameter(p, 'numModes', [], @isnumeric);
parse(p, bct_obj, varargin{:});

lambda_band = p.Results.lambda_band;
freq_band = p.Results.freq_band;
sx = p.Results.sx;
st = p.Results.st;
omega0 = p.Results.omega0;
freq_hz = p.Results.freq_hz;
velocity = p.Results.velocity;
spatial_kernel = p.Results.spatial_kernel;
temporal_kernel = p.Results.temporal_kernel;
numModes = p.Results.numModes;

% Convert freq_hz to omega0 if provided
if ~isempty(freq_hz)
    omega0 = 2*pi*freq_hz;
end

% Use center of freq_band if omega0 not explicitly set
if isempty(p.Results.freq_hz) && ~any(strcmp(p.UsingDefaults, 'freq_band'))
    omega0 = 2*pi*mean(freq_band);
end

%% Create JointFilter object
filt = bct.filters.JointFilter(bct_obj);

% Set bands
filt.lambda_band = lambda_band;
filt.time_band = freq_band;
filt.band_type = "freq";

%% Configure spatial kernel
filt.setSpatialKernel(spatial_kernel, 'sx', sx);

%% Configure temporal kernel
filt.setTemporalKernel(temporal_kernel, 'st', st, 'omega0', omega0);

%% Configure wave dispersion
filt.setDispersion('wave', 'velocity', velocity);

%% Display configuration
fprintf('[bct.filters.design.wave] Filter configured:\n');
fprintf('  Spatial: %s wavelet (sx=%.2f) on λ ∈ [%.2f, %.2f]\n', ...
    spatial_kernel, sx, lambda_band(1), lambda_band(2));
fprintf('  Temporal: %s wavelet (st=%.2f, f₀=%.2f Hz)\n', ...
    temporal_kernel, st, omega0/(2*pi));
fprintf('  Dispersion: Wave propagation K(λ,t) = cos(√λ·t/v), v=%.2f\n', velocity);

if ~isempty(numModes)
    fprintf('  Modes: %d\n', numModes);
end

fprintf('\nNext steps:\n');
fprintf('  1. filt.synthesize()  - Build spectral grid and evaluate filter\n');
fprintf('  2. filt.plotJoint()   - Visualize joint filter W(λ,t)\n');

end
