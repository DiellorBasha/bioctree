function plot_spacetime_spectrum(Fk, ax, info, varargin)
%PLOT_SPACETIME_SPECTRUM  Plot magnitude-like spacetime spectrum + top temporal line.
%
% plot_spacetime_spectrum(Fk, ax, info, Name=Value, ...)
%
% Required
%   Fk   : N-D spectrum (time is dim 2). Can be complex coefficients or real magnitudes.
%   ax   : cell array of axes vectors from your FFT routine
%           - space dims: wavenumber [rad/m]
%           - time dim : frequency [Hz]
%   info : struct (size, nfft, timeDim, spacings, etc.)
%
% Name-Value options
%   Units         : 'frequency' | 'angular' | 'physical' | 'normalized' (default 'frequency')
%   SpatialDims   : which spatial dimension to display on Y (default 1)
%   Slice         : indices for remaining dims (vector or cell). Default centers.
%   TimePosOnly   : true/false keep only f>=0 (default true)
%   SpacePosOnly  : true/false keep only k>=0 for plotted spatial dim (default false)
%   LogMag        : true/false plot in dB (20*log10 of a magnitude-like map) (default false)
%   Colormap      : e.g., 'parula' (default)
%   Title         : custom title (default auto)
%   TemporalAgg   : 'mag-mean'|'mag-sum'|'power-mean'|'power-sum' (default 'mag-mean')
%   TopHeightFrac : relative height of the top temporal subplot (default 0.22)
%   InputKind     : 'auto' | 'coeff' | 'magnitude' | 'power'  (default 'auto')
%
% Notes
% - If InputKind='auto':
%       complex Fk        -> treated as coefficients, uses abs(Fk)
%       real Fk with any negatives -> treated as signed coeffs, uses abs(Fk)
%       real Fk all >=0  -> assumed already magnitude-like (or power); no extra abs
%   If your input is **power**, and you set TemporalAgg='power-*', results are consistent.
%   If your input is power but you leave TemporalAgg='mag-*', we aggregate sqrt(power).
%
% - The top line uses the same subset as the image (same masks & units).

    % ----------- parse args -----------
    p = inputParser;
    addParameter(p, 'Units', 'frequency');
    addParameter(p, 'SpatialDims', 1);
    addParameter(p, 'Slice', []);
    addParameter(p, 'TimePosOnly', true);
    addParameter(p, 'SpacePosOnly', false);
    addParameter(p, 'LogMag', false);
    addParameter(p, 'Colormap', 'parula');
    addParameter(p, 'Title', '');
    addParameter(p, 'TemporalAgg', 'mag-mean');
    addParameter(p, 'TopHeightFrac', 0.22);
    addParameter(p, 'InputKind', 'auto');  % NEW
    parse(p, varargin{:});
    opt = p.Results;

    nd   = ndims(Fk);
    tDim = 2;                       % by design: time is dim 2
    sDim = opt.SpatialDims;

    % ----------- slicing -----------
    sz = size(Fk);
    slicer = cell(1, nd);
    for d = 1:nd
        if d==sDim || d==tDim
            slicer{d} = ':';
        else
            if isempty(opt.Slice)
                slicer{d} = round(sz(d)/2);   % center slice by default
            elseif iscell(opt.Slice)
                slicer{d} = opt.Slice{d};
            else
                slicer{d} = opt.Slice(1);
            end
        end
    end
    Fk2D = squeeze(Fk(slicer{:}));      % [Nspace x Ntime]

    % ----------- base axes from upstream -----------
    k_rad_per_m = ax{sDim};             % space in rad/m
    f_Hz        = ax{tDim};             % time in Hz

    % masks
    tMask = true(size(f_Hz));    if opt.TimePosOnly,  tMask = (f_Hz >= 0); end
    sMask = true(size(k_rad_per_m)); if opt.SpacePosOnly, sMask = (k_rad_per_m >= 0); end

    Fk2D = Fk2D(sMask, tMask);
    k_rad_per_m = k_rad_per_m(sMask);
    f_Hz        = f_Hz(tMask);

    % ----------- unit conversions (axes) -----------
    yDirNormal = false;  % default 'axis xy'
    switch lower(opt.Units)
        case 'frequency'    % space: cycles/m ; time: Hz
            y = k_rad_per_m/(2*pi);   x = f_Hz;
            yLabel = 'Spatial frequency (cycles/m)';
            xLabel = 'Temporal frequency (Hz)';
        case 'angular'      % space: rad/m ; time: rad/s
            y = k_rad_per_m;          x = 2*pi*f_Hz;
            yLabel = 'Wavenumber k (rad/m)';
            xLabel = 'Angular frequency \omega (rad/s)';
        case 'physical'     % space: wavelength (m); time: period (s)
            cyc_per_m = k_rad_per_m/(2*pi);
            pos_s = cyc_per_m > 0; pos_t = f_Hz > 0;
            Fk2D = Fk2D(pos_s, pos_t);
            y = 1 ./ cyc_per_m(pos_s);     % λ (m)
            x = 1 ./ f_Hz(pos_t);          % T (s)
            yLabel = 'Wavelength \lambda (m)';
            xLabel = 'Period T (s)';
            yDirNormal = true;             % increasing λ upward
        case 'normalized'   % cycles/sample (space & time)
            dx = info.spacings(sDim); dt = info.spacings(tDim);
            y = (k_rad_per_m/(2*pi)) * dx;
            x = f_Hz * dt;
            yLabel = 'Spatial freq (cycles/sample)';
            xLabel = 'Temporal freq (cycles/sample)';
        otherwise
            error('Unknown Units: %s', opt.Units);
    end

    % ----------- decide what to plot (auto abs if needed) -----------
    inputKind = lower(string(opt.InputKind));
    if inputKind == "auto"
        if ~isreal(Fk2D) || any(abs(imag(Fk2D(:))) > 10*eps)      % complex coefficients
            inputKind = "coeff";
        elseif any(Fk2D(:) < 0)                                   % signed real coeffs
            inputKind = "coeff";
        else
            inputKind = "magnitude";                               % already >= 0
        end
    end

    switch inputKind
        case "coeff"
            Mag = abs(Fk2D);          % magnitude from (possibly complex) coeffs
            Pow = Mag.^2;             % power from coeffs
        case "magnitude"
            Mag = Fk2D;               % trust it's a magnitude-like map
            Pow = Mag.^2;
        case "power"
            Pow = Fk2D;               % trust it's already power
            Mag = sqrt(max(Pow,0));
        otherwise
            error('InputKind must be auto|coeff|magnitude|power');
    end

    % Map to display
    M = Mag;
    if opt.LogMag
        % dB of a magnitude-like quantity (like 20*log10|X|).
        % NOTE: if your input is POWER and you want 10*log10(power), set
        %       InputKind='power' and change the next line to use Pow instead.
        M = 20*log10(M + eps);
    end

    % ----------- temporal aggregation (top line) -----------
    switch lower(opt.TemporalAgg)
        case 'mag-mean',    temporalLine = mean(Mag, 1);
        case 'mag-sum',     temporalLine = sum(Mag, 1);
        case 'power-mean',  temporalLine = mean(Pow, 1);
        case 'power-sum',   temporalLine = sum(Pow, 1);
        otherwise, error('Unknown TemporalAgg: %s', opt.TemporalAgg);
    end
    if opt.LogMag
        % match the image scale; if you used Pow above, prefer 10*log10.
        temporalLine = 20*log10(temporalLine + eps);
    end
    xTop = x;   % same x-units as the bottom panel

    % ----------- layout & plotting -----------
    nRows = 30;
    topRows = max(1, min(nRows-1, round(opt.TopHeightFrac*nRows)));
    botRows = nRows - topRows;

    tl = tiledlayout(nRows, 1, 'TileSpacing','compact','Padding','compact');

    % Top temporal line
    axTop = nexttile(tl, [topRows 1]);
    plot(axTop, xTop, temporalLine, 'LineWidth', 1.1);
    xlim(axTop, [min(xTop) max(xTop)]);
    ylabel(axTop,'Aggregate');
    title(axTop, 'Temporal FFT (aggregated over space)');
    grid(axTop,'on');

    % Bottom joint map
    axBot = nexttile(tl, [botRows 1]);
    imagesc(axBot, x, y, M);
    if yDirNormal, set(axBot,'YDir','normal'); else, axis(axBot,'xy'); end
    colormap(axBot, opt.Colormap); colorbar(axBot);
    xlabel(axBot, xLabel); ylabel(axBot, yLabel);

    % Global title
    if isempty(opt.Title)
        ttl = sprintf('Spatiotemporal spectrum |F| (%s units), InputKind=%s, TemporalAgg=%s', ...
                      opt.Units, inputKind, opt.TemporalAgg);
    else
        ttl = char(opt.Title);
    end
    title(tl, ttl);
end
