function xRecon = reconstructFromModes(info, cSpectral, opts)
%RECONSTRUCTFROMMODES Reconstruct vertex-space data from spectral coefficients.
%
%   Given spectral coefficients c [kTotal × T] produced by
%   buildSpectralProjection, reconstruct vertex-space signals on the full
%   surface or on a single hemisphere, optionally selecting a band of modes.
%
% Syntax:
%   xRecon = reconstructFromModes(info, cSpectral)
%   xRecon = reconstructFromModes(info, cSpectral, 'Hemisphere', 'left')
%   xRecon = reconstructFromModes(info, cSpectral, 'ModeRange', [10 50])
%   xRecon = reconstructFromModes(info, cSpectral, 'Hemisphere', 'left', ...
%                                 'ModeRange', [10 50])
%
% Inputs:
%   info      - struct from buildSpectralProjection (contains UL, UR, kL, kR)
%   cSpectral - [kTotal × T] spectral coefficient matrix
%               Rows 1:kL are left-hemisphere modes, kL+1:kTotal are right.
%
% Name-Value Arguments:
%   Hemisphere - 'both' (default), 'left', or 'right'
%                Selects which hemisphere(s) to reconstruct.
%   ModeRange  - [modeStart modeEnd] 1-based mode indices (per hemisphere)
%                Default: all modes [1, kL] for left, [1, kR] for right.
%                If a scalar k, uses [1, k] (first k modes).
%                These are indices into each hemisphere's own mode set.
%   Envelope   - logical (default false). If true, apply Hilbert transform
%                and return amplitude envelope instead of signed signal.
%
% Outputs:
%   xRecon - Reconstructed vertex-space data:
%            'both'  → [nDestTotal × T]
%            'left'  → [nDestL × T]
%            'right' → [nDestR × T]
%
% Examples:
%   %% Full reconstruction (all modes, both hemispheres)
%   xFull = reconstructFromModes(info, cSpectral);
%   % xFull: [20484 × T]
%
%   %% Left hemisphere only
%   xLeft = reconstructFromModes(info, cSpectral, 'Hemisphere', 'left');
%   % xLeft: [10242 × T]
%
%   %% Smooth spatial patterns (first 50 modes, left)
%   xSmooth = reconstructFromModes(info, cSpectral, ...
%       'Hemisphere', 'left', 'ModeRange', 50);
%   % xSmooth: [10242 × T]
%
%   %% Spatial frequency band (modes 50-200, left)
%   xBand = reconstructFromModes(info, cSpectral, ...
%       'Hemisphere', 'left', 'ModeRange', [50 200]);
%   % xBand: [10242 × T]
%
%   %% Amplitude envelope of smooth reconstruction
%   xEnv = reconstructFromModes(info, cSpectral, ...
%       'Hemisphere', 'left', 'ModeRange', 50, 'Envelope', true);
%
% See also: buildSpectralProjection, SourceExplorer

arguments
    info      (1,1) struct
    cSpectral (:,:) double
    opts.Hemisphere (1,1) string {mustBeMember(opts.Hemisphere, ...
        ["both", "left", "right"])} = "both"
    opts.ModeRange  = []
    opts.Envelope   (1,1) logical = false
end

kL = info.kL;
kR = info.kR;

%% Parse mode range
if isempty(opts.ModeRange)
    rangeL = 1:kL;
    rangeR = 1:kR;
elseif isscalar(opts.ModeRange)
    rangeL = 1:min(opts.ModeRange, kL);
    rangeR = 1:min(opts.ModeRange, kR);
else
    m1 = opts.ModeRange(1);
    m2 = opts.ModeRange(2);
    rangeL = m1:min(m2, kL);
    rangeR = m1:min(m2, kR);
end

%% Extract spectral coefficients for each hemisphere
cL = cSpectral(rangeL, :);              % [nModesL × T]
cR = cSpectral(kL + rangeR, :);         % [nModesR × T]

%% Reconstruct
switch opts.Hemisphere
    case "left"
        xRecon = info.UL(:, rangeL) * cL;       % [nDestL × T]
    case "right"
        xRecon = info.UR(:, rangeR) * cR;        % [nDestR × T]
    case "both"
        xL = info.UL(:, rangeL) * cL;            % [nDestL × T]
        xR = info.UR(:, rangeR) * cR;            % [nDestR × T]
        xRecon = [xL; xR];                        % [nDestTotal × T]
end

%% Optional: Hilbert amplitude envelope
if opts.Envelope
    % hilbert() operates along dim 1, so transpose: time becomes dim 1
    analytic = hilbert(xRecon.');    % [T × nVert]
    xRecon = abs(analytic).';       % [nVert × T]
end

end
