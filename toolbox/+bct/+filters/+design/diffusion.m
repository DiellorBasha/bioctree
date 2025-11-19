function filt = diffusion(bct_obj, varargin)
%DIFFUSION Design diffusion-coupled spatiotemporal filter
%
%   Creates a joint mesh-time filter with heat diffusion dispersion:
%       W(λ,t) = exp(-t*λ) * ψ_mesh(λ) * φ_time(t)
%
%   The filter combines:
%     - Spatial kernel ψ_mesh: Mexican hat wavelet on mesh spectrum
%     - Temporal kernel φ_time: Gabor wavelet in time
%     - Dispersion K(λ,t): Heat diffusion kernel exp(-t*λ)
%
%   Syntax:
%     filt = bct.filters.design.diffusion(B)
%     filt = bct.filters.design.diffusion(B, 'param', value, ...)
%
%   Inputs:
%     bct_obj - bct.bct object with Manifold and Time
%
%   Parameters:
%     'lambda_band'  - Spatial frequency band [lambda_min, lambda_max]
%                      Default: [0, 5]
%     'freq_band'    - Temporal frequency band [f_min, f_max] in Hz
%                      Default: [8, 12] (alpha band)
%     'sx'           - Spatial scale parameter (controls spatial bandwidth)
%                      Default: 5
%     'st'           - Temporal scale parameter (controls temporal envelope)
%                      Default: 20 (in samples)
%     'omega0'       - Center frequency for temporal wavelet (rad/s)
%                      Default: 2*pi*10 (10 Hz)
%     'freq_hz'      - Center frequency in Hz (alternative to omega0)
%                      If provided, overrides omega0
%     'spatial_kernel'  - Spatial kernel type: 'mexican_hat', 'morlet', 'gabor'
%                      Default: 'mexican_hat'
%     'temporal_kernel' - Temporal kernel type: 'gabor', 'morlet', 'gaussian'
%                      Default: 'gabor'
%     'numModes'     - Number of eigenmodes to compute
%                      Default: min(200, N-1)
%
%   Returns:
%     filt - bct.filters.JointFilter object with configured kernels
%
%   Example:
%     % Design diffusion filter for alpha oscillations (8-12 Hz)
%     B = bct.bct();
%     B.Manifold = bct.manifold.Manifold(V, F);
%     B.Time = bct.manifold.Time(1000, 250);  % 1000 samples @ 250 Hz
%     
%     filt = bct.filters.design.diffusion(B, ...
%         'lambda_band', [0, 5], ...
%         'freq_hz', 10, ...    % 10 Hz center frequency
%         'sx', 2, ...          % Spatial scale
%         'st', 0.05);          % 50 ms temporal scale
%     
%     % Synthesize on spectral grid
%     filt.synthesize();
%     
%     % Visualize
%     filt.plotJoint();
%     filt.plotMarginals();
%
%   See also: bct.filters.JointFilter, bct.filters.design.wave,
%             bct.bct.buildSpectralGrid

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
addParameter(p, 'spatial_kernel', 'mexican_hat', @ischar);
addParameter(p, 'temporal_kernel', 'gabor', @ischar);
addParameter(p, 'numModes', [], @isnumeric);
parse(p, bct_obj, varargin{:});

lambda_band = p.Results.lambda_band;
freq_band = p.Results.freq_band;
sx = p.Results.sx;
st = p.Results.st;
omega0 = p.Results.omega0;
freq_hz = p.Results.freq_hz;
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

% Set lambda band
filt.lambda_band = lambda_band;
filt.time_band = freq_band;
filt.band_type = "freq";

%% Configure spatial kernel
filt.setSpatialKernel(spatial_kernel, 'sx', sx);

%% Configure temporal kernel
filt.setTemporalKernel(temporal_kernel, 'st', st, 'omega0', omega0);

%% Configure heat diffusion dispersion
filt.setDispersion('heat');

%% Display configuration
fprintf('[bct.filters.design.diffusion] Filter configured:\n');
fprintf('  Spatial: %s wavelet (sx=%.2f) on λ ∈ [%.2f, %.2f]\n', ...
    spatial_kernel, sx, lambda_band(1), lambda_band(2));
fprintf('  Temporal: %s wavelet (st=%.2f, f₀=%.2f Hz)\n', ...
    temporal_kernel, st, omega0/(2*pi));
fprintf('  Dispersion: Heat diffusion K(λ,t) = exp(-t·λ)\n');

if ~isempty(numModes)
    fprintf('  Modes: %d\n', numModes);
end

fprintf('\nNext steps:\n');
fprintf('  1. filt.synthesize()  - Build spectral grid and evaluate filter\n');
fprintf('  2. filt.plotJoint()   - Visualize joint filter W(λ,t)\n');
fprintf('  3. Apply to signal using bct.transform\n');

end
