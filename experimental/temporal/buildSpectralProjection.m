function [P, info] = buildSpectralProjection(WK, Mleft, Mright, opts)
%BUILDSPECTRALPROJECTION Build sensor-to-spectral projection matrix.
%
%   P maps raw sensor data directly to eigenmode coefficients on the
%   combined fsaverage5 cortical surface (left + right):
%
%       c = P * x_sensor        % [2*kModes × T] spectral coefficients
%
%   The math:
%       P = Ublock' * Mblock * WK
%
%   where   Ublock = blkdiag(U_L, U_R)   eigenvectors  [nVert × 2k]
%           Mblock = blkdiag(M_L, M_R)   mass matrices  [nVert × nVert]
%           WK     = W * K                              [nVert × nChan]
%
%   Because the Laplace-Beltrami operator decomposes into independent
%   hemispheres (they are disconnected manifolds), Ublock is exact — not
%   an approximation.
%
% Syntax:
%   [P, info] = buildSpectralProjection(WK, Mleft, Mright)
%   [P, info] = buildSpectralProjection(WK, Mleft, Mright, 'NumModes', 500)
%
% Inputs:
%   WK     - [nDestTotal × nChannels] Projection matrix (W * K)
%            where nDestTotal = nDestL + nDestR (typically 20484)
%   Mleft  - bct.Manifold for left hemisphere (with eigenmodes cached)
%   Mright - bct.Manifold for right hemisphere (with eigenmodes cached)
%
% Name-Value Arguments:
%   NumModes  - Number of modes per hemisphere to use (default: all cached)
%               If a scalar, uses the same number for both hemispheres.
%               If [kL kR], uses kL for left and kR for right.
%
% Outputs:
%   P    - [nModesTotal × nChannels] dense projection matrix
%          where nModesTotal = kL + kR
%   info - struct with fields:
%          .kL         - Number of left modes used
%          .kR         - Number of right modes used
%          .kTotal     - kL + kR
%          .nDestL     - Number of left-hemisphere vertices
%          .nDestR     - Number of right-hemisphere vertices
%          .nDestTotal - nDestL + nDestR
%          .nChannels  - Number of sensor channels
%          .lambdaL    - [kL × 1] left eigenvalues (ascending)
%          .lambdaR    - [kR × 1] right eigenvalues (ascending)
%          .lambda     - [kTotal × 1] concatenated [lambdaL; lambdaR]
%          .UL         - [nDestL × kL] left eigenvectors  (for reconstruction)
%          .UR         - [nDestR × kR] right eigenvectors (for reconstruction)
%          .Ublock     - blkdiag(UL, UR)  [nDestTotal × kTotal] (for full recon)
%
% Examples:
%   %% Setup
%   Mleft  = bct.file.read.manifold('lhfsaverage.zarr');
%   Mright = bct.file.read.manifold('rhfsaverage.zarr');
%   % (assumes eigenmodes already cached in the zarr files)
%
%   [P, info] = buildSpectralProjection(WK, Mleft, Mright);
%   % P: [2000 × 270]
%
%   %% Project sensor data to spectral coefficients
%   cSpectral = P * alphaCWT(:, iWin);   % [2000 × nSamp]
%
%   %% Reconstruct full vertices from spectral coefficients
%   xRecon = info.Ublock * cSpectral;    % [20484 × nSamp]
%
%   %% Reconstruct left hemisphere only
%   xLeft = info.UL * cSpectral(1:info.kL, :);  % [10242 × nSamp]
%
%   %% Reconstruct a spatial frequency band (modes 10-50, left)
%   band = 10:50;
%   xBand = info.UL(:, band) * cSpectral(band, :);
%
%   %% Use fewer modes
%   [P100, info100] = buildSpectralProjection(WK, Mleft, Mright, 'NumModes', 100);
%
% See also: buildProjectionMatrix, reconstructFromModes

arguments
    WK     (:,:) double
    Mleft  (1,1) bct.Manifold
    Mright (1,1) bct.Manifold
    opts.NumModes = []
end

%% Extract eigen data
EL = Mleft.eigenmodes();
ER = Mright.eigenmodes();

UL_full = EL.eigenvectors.value;    % [nVertL × kCachedL]
UR_full = ER.eigenvectors.value;    % [nVertR × kCachedR]
lamL_full = EL.eigenvalues.value;   % [kCachedL × 1]
lamR_full = ER.eigenvalues.value;   % [kCachedR × 1]

kCachedL = size(UL_full, 2);
kCachedR = size(UR_full, 2);

%% Determine number of modes to use
if isempty(opts.NumModes)
    kL = kCachedL;
    kR = kCachedR;
elseif isscalar(opts.NumModes)
    kL = min(opts.NumModes, kCachedL);
    kR = min(opts.NumModes, kCachedR);
else
    kL = min(opts.NumModes(1), kCachedL);
    kR = min(opts.NumModes(2), kCachedR);
end

UL = UL_full(:, 1:kL);
UR = UR_full(:, 1:kR);
lamL = lamL_full(1:kL);
lamR = lamR_full(1:kR);

nDestL = size(UL, 1);
nDestR = size(UR, 1);
nDestTotal = nDestL + nDestR;

%% Validate WK dimensions
assert(size(WK, 1) == nDestTotal, ...
    'buildSpectralProjection:DimensionMismatch', ...
    'WK has %d rows but expected %d (nDestL=%d + nDestR=%d)', ...
    size(WK, 1), nDestTotal, nDestL, nDestR);

nChannels = size(WK, 2);

%% Extract mass matrices
ML = Mleft.mass();   % struct with .value
MR = Mright.mass();

ML = ML.value;  % [nVertL × nVertL] sparse
MR = MR.value;  % [nVertR × nVertR] sparse

%% Build block-diagonal matrices
%   Ublock = blkdiag(UL, UR)     [nDestTotal × kTotal]
%   Mblock = blkdiag(ML, MR)     [nDestTotal × nDestTotal] sparse

Ublock = blkdiag(sparse(UL), sparse(UR));  % sparse for multiplication
Mblock = blkdiag(ML, MR);

%% Build P = Ublock' * Mblock * WK
%   [kTotal × nDestTotal] * [nDestTotal × nDestTotal] * [nDestTotal × nChan]
%   = [kTotal × nChan]
%
%   Do it in two steps to keep memory manageable:
%   1) MWK = Mblock * WK           [nDestTotal × nChan]
%   2) P   = Ublock' * MWK         [kTotal × nChan]

fprintf('Building spectral projection P [%d × %d]...\n', kL + kR, nChannels);

MWK = Mblock * WK;         % sparse × dense → dense [nDestTotal × nChan]
P   = full(Ublock' * MWK); % sparse' × dense → dense [kTotal × nChan]

fprintf('  ✓ P: [%d × %d] (%d left modes + %d right modes)\n', ...
    size(P, 1), size(P, 2), kL, kR);

%% Assemble info struct
% Store dense UL, UR for reconstruction (user needs them dense)
info.kL         = kL;
info.kR         = kR;
info.kTotal     = kL + kR;
info.nDestL     = nDestL;
info.nDestR     = nDestR;
info.nDestTotal = nDestTotal;
info.nChannels  = nChannels;
info.lambdaL    = lamL;
info.lambdaR    = lamR;
info.lambda     = [lamL; lamR];
info.UL         = UL_full(:, 1:kL);   % dense [nDestL × kL]
info.UR         = UR_full(:, 1:kR);   % dense [nDestR × kR]

% Build Ublock as dense for convenient full reconstruction
info.Ublock     = blkdiag(info.UL, info.UR);  % dense [nDestTotal × kTotal]

end
