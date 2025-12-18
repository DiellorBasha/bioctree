function RGB = vector_hsv(amplitude, phase, opts)
%VECTOR_HSV  Map amplitude + phase to RGB using HSV
%
%   RGB = bct.color.vector_hsv(amplitude, phase)
%   RGB = bct.color.vector_hsv(amplitude, phase, opts)
%
%   Semantics:
%     Hue        <- phase (cyclic)
%     Value      <- amplitude (intensity)
%     Saturation <- optional confidence (default = 1)
%
%   Output shape:
%     Vector input (Nx1 or 1xN):  Returns Nx3 RGB matrix
%     2D grid input (MxN):        Returns MxNx3 RGB volume
%
%   Options (opts):
%     phaseRange   : [min max] (default [-pi pi])
%     maxAmplitude : scalar    (default = max(amplitude))
%     saturation   : [] | scalar | array in [0,1]
%     clip         : true/false (default true)

    arguments
        amplitude
        phase
        opts.phaseRange (1,2) double = [-pi pi]
        opts.maxAmplitude double = []
        opts.saturation = []          % ← optional
        opts.clip logical = true
    end

    % --- validate ---
    assert(isequal(size(amplitude), size(phase)), ...
        'Amplitude and phase must have the same size');

    % --- phase → hue ---
    pr = opts.phaseRange;
    H = (phase - pr(1)) ./ (pr(2) - pr(1));
    H = mod(H, 1);

    % --- amplitude → value ---
    if isempty(opts.maxAmplitude)
        maxAmp = max(amplitude(:));
        V = amplitude ./ max(maxAmp, eps);
    else
        V = amplitude ./ opts.maxAmplitude;
    end

    % --- saturation handling (optional) ---
    if isempty(opts.saturation)
        S = ones(size(amplitude));        % default: full saturation
    elseif isscalar(opts.saturation)
        S = opts.saturation * ones(size(amplitude));
    else
        S = opts.saturation;
        assert(isequal(size(S), size(amplitude)), ...
            'Saturation must be scalar or same size as amplitude');
    end

    % --- optional clipping ---
    if opts.clip
        V = min(max(V,0),1);
        S = min(max(S,0),1);
    end

    % --- assemble HSV and convert ---
    % Handle vector inputs (Nx1 or 1xN) -> return Nx3
    isVector = isvector(amplitude);
    if isVector
        N = numel(amplitude);
        HSV = [H(:), S(:), V(:)];  % Force Nx3
        RGB = hsv2rgb(HSV);
    else
        % For 2D grids (MxN) -> return MxNx3
        HSV = cat(ndims(amplitude)+1, H, S, V);
        RGB = hsv2rgb(HSV);
    end
end
