function [X, X_sum, info] = synth_mesh_5band(U, lam, d, opts)
% synth_mesh_5band - Synthesize 5 narrowband signals on mesh with different wavelengths
%
% Generates multiple narrowband signals with log-spaced center frequencies,
% useful for analyzing multi-scale patterns on triangular meshes.
%
% Syntax:
%   [X, X_sum, info] = synth_mesh_5band(U, lam, d)
%   [X, X_sum, info] = synth_mesh_5band(U, lam, d, opts)
%
% Inputs:
%   U    - [N×K] eigenvector matrix from meshFourier
%   lam  - [K×1] eigenvalue vector from meshFourier
%   d    - [N×1] diagonal of mass matrix M (from diag(M))
%   opts - (optional) Structure with fields:
%          .nBands   - Number of bands to generate (default: 5)
%          .bw_frac  - Bandwidth as fraction of center freq (default: 0.20)
%          .margin_lo - Lower frequency margin multiplier (default: 1.15)
%          .margin_hi - Upper frequency margin multiplier (default: 0.85)
%          .seed     - Random seed for reproducibility (default: 7)
%
% Outputs:
%   X      - {nBands×1} cell array of synthesized signals [N×1 each]
%   X_sum  - [N×1] sum of all band signals (M-energy normalized)
%   info   - Structure with fields:
%            .f0s        - [nBands×1] center frequencies (cycles/mm)
%            .Pdes       - {nBands×1} designed power spectra
%            .FreqBands  - {nBands×1} frequency vectors
%            .coeffs     - {nBands×1} spectral coefficients
%            .P_sum      - [K×1] power spectrum of summed signal
%            .f_range    - [fmin, fmax] available frequency range
%
% Notes:
%   - Requires synth_mesh_signal function
%   - Generates signals from long to short wavelengths (log-spaced)
%   - All signals are M-energy normalized
%   - Use synth_mesh_signal_plot for visualization
%
% Example:
%   [U, lam, K, M] = meshFourier(mesh, 600);
%   d = full(diag(M));
%   [X, X_sum, info] = synth_mesh_5band(U, lam, d);
%   synth_mesh_signal_plot(mesh, X, X_sum, info);
%
% See also: synth_mesh_signal, meshFourier, synth_mesh_signal_plot

% Parse options
if nargin < 4 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'nBands'),    opts.nBands = 5; end
if ~isfield(opts, 'bw_frac'),   opts.bw_frac = 0.20; end
if ~isfield(opts, 'margin_lo'), opts.margin_lo = 1.15; end  % 15% above fmin
if ~isfield(opts, 'margin_hi'), opts.margin_hi = 0.85; end  % 15% below fmax
if ~isfield(opts, 'seed'),      opts.seed = 7; end

% Extract parameters
nBands = opts.nBands;
bw_frac = opts.bw_frac;

% Compute frequency range
f_all = sqrt(lam)/(2*pi);
fmin = min(f_all(f_all>0));
fmax = max(f_all);

% Keep margin away from edges so Gaussian isn't clipped
f_lo = opts.margin_lo * fmin;
f_hi = opts.margin_hi * fmax;

% Log-spaced centers from long -> short wavelengths
f0s = logspace(log10(f_lo), log10(f_hi), nBands);

% Set random seed for reproducibility
rng(opts.seed);

% Synthesize each band
X = cell(nBands, 1);
Pdes = cell(nBands, 1);
FreqBands = cell(nBands, 1);
coeffs = cell(nBands, 1);

for i = 1:nBands
    f0 = f0s(i);
    spec = struct('type', 'narrowband', 'f0', f0, 'bw_frac', bw_frac);
    [x_i, a_i, f] = synth_mesh_signal(U, lam, d, spec);
    X{i} = x_i;
    Pdes{i} = a_i.^2;           % designed power per eigenmode
    FreqBands{i} = f;           % eigenmode frequencies
    coeffs{i} = a_i;            % spectral coefficients
end

% Create multi-band sum
x_sum = zeros(size(X{1}));
for i = 1:nBands
    x_sum = x_sum + X{i};
end

% Normalize total M-energy
Mdiag = spdiags(d, 0, numel(d), numel(d));
E = x_sum' * (Mdiag * x_sum);
if E > 0
    x_sum = x_sum / sqrt(E);
end
X_sum = x_sum;

% Compute spectrum of the sum
Sinv = spdiags(1./sqrt(d), 0, numel(d), numel(d));
a_sum = U' * (Sinv * x_sum);
P_sum = a_sum.^2;

% Package info structure
info = struct();
info.f0s = f0s(:);
info.Pdes = Pdes;
info.FreqBands = FreqBands;
info.coeffs = coeffs;
info.P_sum = P_sum;
info.f_range = [fmin, fmax];
info.bw_frac = bw_frac;
info.nBands = nBands;

end
