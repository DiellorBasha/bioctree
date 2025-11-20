function filt = separable(bct_obj, varargin)
%SEPARABLE Design separable spatiotemporal filter (no dispersion)
%
%   Creates a joint mesh-time filter without dispersion coupling:
%       W(λ,t) = ψ_mesh(λ) * φ_time(t)
%
%   The filter is a simple product of independent spatial and temporal kernels.
%   This is appropriate when spatial and temporal dynamics are uncoupled.
%
%   Syntax:
%     filt = bct.filters.design.separable(B)
%     filt = bct.filters.design.separable(B, 'param', value, ...)
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
%     'spatial_kernel'  - Spatial kernel type: 'mexican_hat', 'morlet', 'gabor', 'gaussian'
%                      Default: 'gabor'
%     'temporal_kernel' - Temporal kernel type: 'gabor', 'morlet', 'gaussian'
%                      Default: 'gabor'
%     'numModes'     - Number of eigenmodes to compute
%
%   Returns:
%     filt - bct.filters.JointFilter object with no dispersion
%
%   Example:
%     % Design separable Gabor filter for alpha band
%     filt = bct.filters.design.separable(B, ...
%         'lambda_band', [0.5, 10], ...
%         'freq_hz', 10, ...
%         'sx', 3, 'st', 0.1);
%     
%     filt.synthesize();
%     filt.plotJoint();
%     filt.plotMarginals();
%
%   See also: bct.filters.JointFilter, bct.filters.design.diffusion,
%             bct.filters.design.wave

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
addParameter(p, 'spatial_kernel', 'gabor', @ischar);
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

% Set bands
filt.lambda_band = lambda_band;
filt.time_band = freq_band;
filt.band_type = "freq";

%% Configure spatial kernel
filt.setSpatialKernel(spatial_kernel, 'sx', sx);

%% Configure temporal kernel
filt.setTemporalKernel(temporal_kernel, 'st', st, 'omega0', omega0);

%% No dispersion (separable filter)
filt.setDispersion('none');

%% Display configuration
fprintf('[bct.filters.design.separable] Filter configured:\n');
fprintf('  Spatial: %s kernel (sx=%.2f) on λ ∈ [%.2f, %.2f]\n', ...
    spatial_kernel, sx, lambda_band(1), lambda_band(2));
fprintf('  Temporal: %s kernel (st=%.2f, f₀=%.2f Hz)\n', ...
    temporal_kernel, st, omega0/(2*pi));
fprintf('  Dispersion: None (separable filter)\n');

if ~isempty(numModes)
    fprintf('  Modes: %d\n', numModes);
end

fprintf('\nNext steps:\n');
fprintf('  1. filt.synthesize()  - Build spectral grid and evaluate filter\n');
fprintf('  2. filt.plotJoint()   - Visualize joint filter W(λ,t)\n');
fprintf('  3. filt.plotMarginals() - View spatial and temporal components\n');

end
