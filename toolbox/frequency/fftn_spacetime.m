function [Fk, axes, info] = fftn_spacetime(X, spacings, nfft, timeDim, doWindow, windowType, doShift, alignTimeSecond)
%FFTN_SPACETIME  N-D FFT for space×...×time arrays (line/plane/volume + time)
%
% [Fk, axes, info] = fftn_spacetime(X, spacings, nfft, timeDim, doWindow, windowType, doShift, alignTimeSecond)
%
% New:
%   alignTimeSecond (logical, default=true): if true, permute output so that
%   the time-frequency axis is the 2nd dim. This makes plotting with time on
%   the x-axis straightforward for 2-D (space×time) data:
%       imagesc( f, kx/(2*pi), abs(Fk) ); axis xy
%
% Other args/behavior: identical to the previous version you have.

    arguments
        X {mustBeNumeric, mustBeNonempty}
        spacings (1,:) double {mustBePositive}
        nfft (1,:) double {mustBePositive, mustBeInteger} = []
        timeDim (1,1) double {mustBePositive, mustBeInteger} = ndims(X)
        doWindow (1,1) logical = false
        windowType (1,:) char {mustBeMember(windowType, {'hann','hamming','rect'})} = 'hann'
        doShift (1,1) logical = true
        alignTimeSecond (1,1) logical = true
    end

    nd = ndims(X);
    sz = size(X);
    if numel(spacings) ~= nd
        error('spacings must have one value per dimension of X (length %d).', nd);
    end
    if isempty(nfft), nfft = sz; end
    if numel(nfft) ~= nd
        error('nfft must have one value per dimension of X (length %d).', nd);
    end
    if timeDim < 1 || timeDim > nd
        error('timeDim must be between 1 and ndims(X).');
    end

    % Optional separable window (per-dimension)
    if doWindow
        X = applySeparableWindow(X, windowType, sz);
    end

    % N-D FFT with explicit lengths
    Fk = fftn(X, nfft);

    % Build per-dimension axes (two-sided)
    axes = cell(1, nd);
    for d = 1:nd
        N = nfft(d);
        if doShift
            idx = (-floor(N/2):ceil(N/2)-1);
        else
            idx = (0:N-1);
        end
        if d == timeDim     % time axis in Hz
            dt = spacings(d);
            axes{d} = idx / (N*dt);
        else                % space axes in rad/unit
            dx = spacings(d);
            axes{d} = (2*pi) * (idx / (N*dx));
        end
    end

    % Shift DC to center if requested
    if doShift
        for d = 1:nd
            Fk = fftshift(Fk, d);
        end
    end

    % Optionally permute so time-frequency is dimension 2 (columns)
    if alignTimeSecond && timeDim ~= 2
        order = 1:nd;
        order(2) = timeDim;        % put time at position 2
        order(timeDim) = 2;        % swap old 2 with timeDim
        Fk = permute(Fk, order);
        axes = axes(order);
        nfft = nfft(order);
        sz = sz(order);
        timeDim = 2;
    end

    info = struct('size', sz, 'nfft', nfft, 'timeDim', timeDim, ...
                  'spacings', spacings, 'fs', 1./spacings);

    % ------------- helpers -------------
    function Xw = applySeparableWindow(Xin, kind, szIn)
        Xw = Xin;
        for dim = 1:nd
            Ndim = szIn(dim);
            switch kind
                case 'hann',    w = hann(Ndim, 'periodic');
                case 'hamming', w = hamming(Ndim, 'periodic');
                case 'rect',    w = ones(Ndim,1);
            end
            shp = ones(1, nd); shp(dim) = Ndim;
            w = reshape(w, shp);
            Xw = Xw .* w;
        end
    end
end
