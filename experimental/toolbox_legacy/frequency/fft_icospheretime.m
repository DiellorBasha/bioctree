function S = fft_icospheretime(G, X, Fs, varargin)
% FFT_ICOSPHERETIME  Spherical-harmonic (space) + FFT (time) joint spectrum.
%
% Usage:
%   S = fft_icospheretime(G, X, Fs, 'Lmax',40, 'NFFT',[], 'Detrend',true);
%
% Inputs:
%   G    : struct from build_icosphere(...) with fields .V [N×3], .F [M×3],
%          and (optionally) .vertexArea [N×1]
%   X    : [N×T] data on vertices over time
%   Fs   : sampling rate (Hz)
%
% Name-Value (optional):
%   'Lmax'     : max SH degree (default: floor(sqrt(N))-1)
%   'Weights'  : per-vertex weights [N×1] (default: vertex areas)
%   'NFFT'     : length of time FFT (default: T)
%   'Detrend'  : remove time-mean per SH mode (default: true)
%   'Window'   : time window [1×T] applied to SH coeffs before FFT (default: none)
%   'NormalizeWindow' : normalize window RMS to 1 (default: true)

% -------- parse options (inputParser only) --------
p = inputParser;
addParameter(p,'Lmax',[]);
addParameter(p,'Weights',[]);
addParameter(p,'NFFT',[]);
addParameter(p,'Detrend',true);
addParameter(p,'Window',[]);
addParameter(p,'NormalizeWindow',true);
parse(p,varargin{:});
Lmax   = p.Results.Lmax;
wIn    = p.Results.Weights;
NFFT   = p.Results.NFFT;
detrnd = p.Results.Detrend;
win    = p.Results.Window;
normW  = p.Results.NormalizeWindow;

% -------- validate sizes --------
[N,T] = size(X);
assert(size(G.V,1)==N, 'X must have one row per vertex in G.V');
if isempty(NFFT), NFFT = T; end
if isempty(Lmax), Lmax = max(0, floor(sqrt(N))-1); end
M = (Lmax+1)^2;

% -------- vertex areas (weights) --------
if isempty(wIn)
    if isfield(G,'vertexArea') && ~isempty(G.vertexArea)
        w = G.vertexArea(:);
    else
        % compute 1/3 of incident face areas
        V = G.V; F = G.F;
        u = V(F(:,2),:) - V(F(:,1),:);
        v = V(F(:,3),:) - V(F(:,1),:);
        Af = 0.5 * vecnorm(cross(u,v,2), 2, 2);
        w  = accumarray(F(:), repmat(Af/3,3,1), [N,1]);
    end
else
    w = wIn(:);
    assert(numel(w)==N, 'Weights must be N-by-1.');
end
W12 = sqrt(w);

% -------- spherical coordinates --------
V = G.V;
r  = sqrt(sum(V.^2,2));        r(r==0) = 1;
theta = acos( max(-1,min(1, V(:,3)./r)) );   % [0,pi]
phi   = atan2( V(:,2), V(:,1) );             % [-pi,pi]

% -------- real spherical-harmonic basis --------
[Y, lm] = local_sph_harm_basismatrix(theta, phi, Lmax);  % [N×M]

% -------- weighted least squares (vectorized over time) --------
YW = W12 .* Y;         % [N×M]
XW = W12 .* X;         % [N×T]
A  = YW \ XW;          % [M×T] SH coefficients

% optional detrend & window
if detrnd, A = A - mean(A,2); end
if ~isempty(win)
    win = win(:).';
    assert(numel(win)==T, 'Window length must equal T');
    if normW, win = win / sqrt(mean(win.^2)+eps); end
    A = A .* win;
end

% -------- FFT in time --------
A_fft = fft(A, NFFT, 2);           % [M×NFFT]
f = (0:NFFT-1) * (Fs/NFFT);        % Hz

% power and degree collapse
deg = lm(:,1);
Plm_f = abs(A_fft).^2;             % [M×NFFT]
Pell_f = zeros(Lmax+1, NFFT);
for l = 0:Lmax
    Pell_f(l+1,:) = sum(Plm_f(deg==l,:), 1);
end

% -------- package output --------
S = struct();
S.Y = Y; S.lm = lm;
S.A = A; S.A_fft = A_fft;
S.f = f; S.deg = deg;
S.Plm_f = Plm_f; S.Pell_f = Pell_f;
S.params = struct('Lmax',Lmax,'NFFT',NFFT,'Fs',Fs,'Detrend',detrnd, ...
                  'Window',win,'Weights','area');
end

% ===== helper: real spherical-harmonic basis up to Lmax =====
function [Y, lm] = local_sph_harm_basismatrix(theta, phi, Lmax)
N = numel(theta);
M = (Lmax+1)^2;
Y = zeros(N, M);
lm = zeros(M,2);
col = 1;
ct = cos(theta(:)).';
for l = 0:Lmax
    % fully-normalized associated Legendre polynomials (m=0..l)
    Plm = legendre(l, ct, 'norm');      % (l+1)×N
    Plm = reshape(Plm, l+1, N);
    % m = 0
    Y(:,col) = Plm(1,:).';   lm(col,:) = [l,0];  col = col+1;
    % m > 0 (real SH with sqrt(2))
    for m = 1:l
        P = Plm(m+1,:).';
        Y(:,col) = sqrt(2)*P.*cos(m*phi); lm(col,:) = [l, m];  col = col+1;
        Y(:,col) = sqrt(2)*P.*sin(m*phi); lm(col,:) = [l,-m];  col = col+1;
    end
end
end
