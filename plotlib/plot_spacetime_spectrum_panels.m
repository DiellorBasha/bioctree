function plot_spacetime_spectrum_panels(Fk, ax, info, varargin)
%PLOT_SPACETIME_SPECTRUM_PANELS
%  Center: |Fk| (time on X, space on Y)
%  Top   : temporal marginal
%  Right : spatial marginal
%
% Usage (line × time):
%   plot_spacetime_spectrum_panels(Fk, ax, info, ...
%       Units="frequency", TimePosOnly=true, SpacePosOnly=false);
%
% Name-Value options (subset mirrors previous helper)
%   Units         : 'frequency'|'angular'|'physical'|'normalized' (default 'frequency')
%   SpatialDims   : which spatial dim on Y (default 1)
%   Slice         : indices for remaining dims (default centers)
%   TimePosOnly   : keep only f>=0 (default true)
%   SpacePosOnly  : keep only k>=0 on plotted spatial dim (default false)
%   TemporalAgg   : 'mag-mean'|'mag-sum'|'power-mean'|'power-sum' (default 'power-mean')
%   SpatialAgg    : aggregation for spatial marginal (same choices; default 'power-mean')
%   LogMag        : true/false → dB-like scaling (default false)
%   Colormap      : colormap name (default 'parula')
%   Title         : figure title (default auto)
%   TopHeightFrac : 0–1 height of top band (default 0.18)
%   RightWidthFrac: 0–1 width of right band (default 0.18)

    % ---------- parse ----------
    p = inputParser;
    addParameter(p,'Units','frequency');
    addParameter(p,'SpatialDims',1,@(x)isnumeric(x)&&isscalar(x));
    addParameter(p,'Slice',[]);
    addParameter(p,'TimePosOnly',true,@islogical);
    addParameter(p,'SpacePosOnly',false,@islogical);
    addParameter(p,'TemporalAgg','power-mean');
    addParameter(p,'SpatialAgg','power-mean');
    addParameter(p,'LogMag',false,@islogical);
    addParameter(p,'Colormap','parula');
    addParameter(p,'Title','');
    addParameter(p,'TopHeightFrac',0.18,@(x)isnumeric(x)&&isscalar(x)&&x>0&&x<0.9);
    addParameter(p,'RightWidthFrac',0.18,@(x)isnumeric(x)&&isscalar(x)&&x>0&&x<0.9);
    parse(p,varargin{:});
    o = p.Results;

    nd   = ndims(Fk);
    tDim = 2;               % from fftn_spacetime (alignTimeSecond = true)
    sDim = o.SpatialDims;
    sz   = size(Fk);

    % ---------- slice higher dims to get a 2D matrix [space × time] ----------
    slicer = cell(1,nd);
    for d=1:nd
        if d==sDim || d==tDim
            slicer{d}=':';
        else
            if isempty(o.Slice)
                slicer{d} = round(sz(d)/2);
            elseif iscell(o.Slice)
                slicer{d} = o.Slice{d};
            else
                slicer{d} = o.Slice(1);
            end
        end
    end
    F2 = squeeze(Fk(slicer{:}));          % [Nspace × Ntime]
    k_rad_m = ax{sDim};                   % rad/m
    f_Hz    = ax{tDim};                   % Hz

    % masks (pos halves if requested)
    tMask = true(size(f_Hz)); if o.TimePosOnly,  tMask = (f_Hz>=0);     end
    sMask = true(size(k_rad_m)); if o.SpacePosOnly, sMask = (k_rad_m>=0); end

    F2 = F2(sMask, tMask);
    k_rad_m = k_rad_m(sMask);
    f_Hz    = f_Hz(tMask);

    % ---------- unit conversions & axis labels ----------
    yDirNormal = false;
    switch lower(o.Units)
        case 'frequency'   % space: cycles/m ; time: Hz
            X = f_Hz;                      xLabel = 'Temporal frequency (Hz)';
            Y = k_rad_m/(2*pi);            yLabel = 'Spatial frequency (cycles/m)';

        case 'angular'     % space: rad/m ; time: rad/s
            X = 2*pi*f_Hz;                 xLabel = 'Angular frequency \omega (rad/s)';
            Y = k_rad_m;                   yLabel = 'Wavenumber k (rad/m)';

        case 'physical'    % space: wavelength (m) ; time: period (s)
            cyc_m  = k_rad_m/(2*pi);
            pos_s  = cyc_m>0;   pos_t = f_Hz>0;
            F2     = F2(pos_s, pos_t);
            Y      = 1./cyc_m(pos_s);      yLabel = 'Wavelength \lambda (m)';
            X      = 1./f_Hz(pos_t);       xLabel = 'Period T (s)';
            yDirNormal = true;              % larger λ upward

        case 'normalized'  % cycles/sample each
            dx = info.spacings(sDim); dt = info.spacings(tDim);
            X = f_Hz*dt;                    xLabel = 'Temporal freq (cycles/sample)';
            Y = (k_rad_m/(2*pi))*dx;        yLabel = 'Spatial freq (cycles/sample)';

        otherwise
            error('Unknown Units: %s', o.Units);
    end

    % ---------- magnitude matrix ----------
    M = abs(F2);
    if o.LogMag, M = 20*log10(M+eps); end

    % ---------- build marginals ----------
    temporalLine = aggregate_rows(F2, o.TemporalAgg, o.LogMag); % over space → vs time (X)
    spatialLine  = aggregate_cols(F2, o.SpatialAgg, o.LogMag);  % over time  → vs space (Y)

    % ---------- layout: fine grid + spanning ----------
% ----- layout: fine grid + spanning, with *zero* spacing -----
nRows = 40; nCols = 40;
topRows   = max(2, round(o.TopHeightFrac*nRows));
rightCols = max(2, round(o.RightWidthFrac*nCols));
midRows   = nRows - topRows;
midCols   = nCols - rightCols;

% Create layout with no spacing/padding (fallback if not supported)
try
    tl = tiledlayout(nRows, nCols, 'TileSpacing','none', 'Padding','none');
catch
    % Older releases: use 'compact'
    tl = tiledlayout(nRows, nCols, 'TileSpacing','compact', 'Padding','compact');
end

% Top (temporal marginal): span topRows × midCols
axTop = nexttile(tl, [topRows, midCols]);

% Center (joint): span midRows × midCols
axMid = nexttile(tl, [midRows, midCols]);

% Right (spatial marginal): span midRows × rightCols
axRight = nexttile(tl, [midRows, rightCols]);

% --- IMPORTANT: do NOT create the blank top-right tile anymore ---
% (That was causing an extra gap in some MATLAB versions.)

    % Top (temporal marginal) spans first topRows × midCols
    axTop = nexttile(tl, [topRows, midCols]);
    plot(axTop, X, temporalLine, 'LineWidth',1.05); %grid(axTop,'on');
   % xlabel(axTop, xLabel); 
    ylabel(axTop,'Aggregate');
   % title(axTop,'Temporal FFT (aggregated over space)');
    axTop.XAxis.Visible="off";
    axTop.YAxis.Visible="on ";
    % Skip top-right (keep it empty to reserve space for right marginal)
    nexttile(tl, [topRows, rightCols]); axis off

    % Center (joint)
    axMid = nexttile(tl, [midRows, midCols]);
    imagesc(axMid, X, Y, M);
    if yDirNormal, set(axMid,'YDir','normal'); else, axis(axMid,'xy'); end
    colormap(axMid, o.Colormap); %colorbar(axMid);
  % Instead of default colorbar at the right of axMid:
% cb = colorbar(axMid);  % <-- this can push the right panel away

% Put the colorbar *below* the center panel (spans width cleanly)
cb = colorbar(axMid, 'Location','southoutside');
cb.Layout.Tile = 'south';   % attaches to the layout’s bottom band (R2020b+)

    xlabel(axMid, xLabel); ylabel(axMid, yLabel);
   % title(axMid, '|F| (joint)');
   % axis(axMid,'tight'); try axis(axMid,'image'); catch, end

    % Right (spatial marginal): spans midRows × rightCols
    axRight = nexttile(tl, [midRows, rightCols]);
    plot(axRight, spatialLine, Y, 'LineWidth',1.05); %grid(axRight,'on');
    set(axRight,'YAxisLocation','right');
     ylabel(axRight, yLabel); 
    % xlabel(axRight,'Aggregate');
    % title(axRight,'Spatial FFT (aggregated over time)');
      axRight.XAxis.Visible="off";
    axRight.YAxis.Visible="on";
    if yDirNormal, set(axRight,'YDir','normal'); end

    % Global title
    if isempty(o.Title)
        ttl = sprintf('Joint + Marginals (%s units)', o.Units);
    else
        ttl = char(o.Title);
    end
    title(tl, ttl);

    % ---------- helpers ----------
    function lineX = aggregate_rows(A, how, logmag)
        % A: [space × time] → collapse over space → 1×time
        switch lower(how)
            case 'mag-mean',   lineX = mean(abs(A),1);
            case 'mag-sum',    lineX = sum(abs(A),1);
            case 'power-mean', lineX = mean(abs(A).^2,1);
            case 'power-sum',  lineX = sum(abs(A).^2,1);
            otherwise, error('Unknown TemporalAgg: %s', how);
        end
        if logmag, lineX = 20*log10(lineX+eps); end
    end

    function lineY = aggregate_cols(A, how, logmag)
        % A: [space × time] → collapse over time → space×1
        switch lower(how)
            case 'mag-mean',   lineY = mean(abs(A),2);
            case 'mag-sum',    lineY = sum(abs(A),2);
            case 'power-mean', lineY = mean(abs(A).^2,2);
            case 'power-sum',  lineY = sum(abs(A).^2,2);
            otherwise, error('Unknown SpatialAgg: %s', how);
        end
        lineY = squeeze(lineY);
        if logmag, lineY = 20*log10(lineY+eps); end
    end
end
