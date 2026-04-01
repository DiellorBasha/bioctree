function fig = plot_fourier_superposition(x1, fs, epochWin, bands, opts)
% PLOT_FOURIER_SUPERPOSITION  Visualise a signal as a sum of bandpassed components.
%
%   fig = plot_fourier_superposition(x1, fs, epochWin, bands)
%   fig = plot_fourier_superposition(x1, fs, epochWin, bands, opts)
%
% --------------------------------------------------------------------------
% INPUTS
%   x1        — (1 x N) or (N x 1) signal vector (assumed z-scored)
%
%   fs        — sampling frequency in Hz (scalar)
%
%   epochWin  — [t_start  t_end] in seconds, e.g. [0 3]
%               Use [] to auto-select the highest-variance epoch of the
%               same duration as diff(epochWin) would imply (defaults to 3s)
%
%   bands     — (B x 3) matrix, one band per row:
%                 [ f_low   f_high   filterOrder ]
%               Set f_low = 0 for a low-pass band.
%               Set f_high = Inf (or > fs/2) to use fs/2-1.
%               Example:
%                 bands = [0   1   4;   % sub-delta / DC
%                          1   4   4;   % delta
%                          4   8   4;   % theta
%                          8  13   4;   % alpha
%                         13  30   4];  % beta
%
%   opts      — (optional) struct with any of these fields:
%     .chanIdx      channel index label shown in subtitle (default: [])
%     .bandLabels   cell array of strings, one per band (default: auto)
%     .exportPath   full path for PNG export; '' = no export (default: '')
%     .exportDPI    resolution for exportgraphics (default: 200)
%     .figTitle     figure title string (default: 'A signal is a sum of sinusoids')
%
% OUTPUT
%   fig   — handle to the created figure
%
% --------------------------------------------------------------------------
% EXAMPLE
%   bands = [0  1  4; 1  4  4; 4  8  4; 8 13  4; 13 30  4];
%   fig   = plot_fourier_superposition(x1, fs, [10 13], bands);
%
% --------------------------------------------------------------------------

arguments
    x1        (1,:) double
    fs        (1,1) double {mustBePositive}
    epochWin  (1,:) double                         % [] or [t0 t1]
    bands     (:,3) double {mustBeNonnegative}
    opts.chanIdx    (1,1) double  = NaN
    opts.bandLabels cell          = {}
    opts.exportPath char          = ''
    opts.exportDPI  (1,1) double  = 200
    opts.figTitle   char          = 'A signal is a sum of sinusoids'
end

% =========================================================================
% 0. Input validation
% =========================================================================
assert(all(bands(:,2) > 0),  'bands: f_high (col 2) must be > 0.');
assert(all(bands(:,3) > 0),  'bands: filter order (col 3) must be > 0.');
assert(all(bands(:,1) >= 0), 'bands: f_low (col 1) must be >= 0.');
assert(all(bands(:,2) > bands(:,1)), ...
    'bands: f_high must exceed f_low for every row.');

% =========================================================================
% 1. Design tokens — microscopy-ui darkfield
% =========================================================================
CLR.bg      = [0.08 0.08 0.10];
CLR.axes    = [0.13 0.13 0.16];
CLR.grid    = [0.22 0.22 0.26];
CLR.text    = [0.82 0.82 0.86];
CLR.dimtext = [0.50 0.50 0.55];
CLR.orig    = [0.82 0.82 0.86];
CLR.sum_clr = [0.95 0.22 0.62];   % Rhodamine — sum row

% Colour palette cycling across bands
palette = [
    0.22 0.82 0.95;   % DAPI cyan
    0.55 0.45 0.95;   % violet
    0.18 0.90 0.42;   % GFP green
    0.98 0.72 0.18;   % amber
    0.95 0.55 0.22;   % orange
    0.85 0.25 0.55;   % deep rose
    0.30 0.75 0.90;   % sky
];

% =========================================================================
% 1. Parse & validate inputs
% =========================================================================
x1 = x1(:)';                        % ensure row vector
N  = numel(x1);
tVec = (0:N-1) / fs;                % time axis in seconds

nBands = size(bands, 1);

% Clamp f_high to Nyquist - 1 Hz
nyq = fs / 2;
bands(:,2) = min(bands(:,2), nyq - 1);

% Band labels
if isempty(opts.bandLabels)
    bandLabels = cell(nBands, 1);
    for b = 1:nBands
        flo = bands(b,1);
        fhi = bands(b,2);
        if flo == 0
            bandLabels{b} = sprintf('Low-pass  \\leq %.0f Hz', fhi);
        else
            bandLabels{b} = sprintf('%.0f – %.0f Hz', flo, fhi);
        end
    end
else
    assert(numel(opts.bandLabels) == nBands, ...
        'opts.bandLabels must have one entry per band row.');
    bandLabels = opts.bandLabels(:);
end

% Assign colours (cycle if more bands than palette entries)
compColours = palette(mod(0:nBands-1, size(palette,1))+1, :);

% =========================================================================
% 2. Select epoch
% =========================================================================
if isempty(epochWin)
    epochDur  = 3.0;
    epochSamp = round(epochDur * fs);
    [t0, t1, x_ep, t_ep] = autoEpoch(x1, tVec, epochSamp);
else
    assert(numel(epochWin) == 2 && epochWin(2) > epochWin(1), ...
        'epochWin must be [t_start t_end] with t_end > t_start.');
    idx0  = max(1,   round(epochWin(1) * fs) + 1);
    idx1  = min(N,   round(epochWin(2) * fs));
    x_ep  = x1(idx0:idx1);
    t_ep  = tVec(idx0:idx1) - tVec(idx0);
    t0    = tVec(idx0);
    t1    = tVec(idx1);
end

epochDur  = t_ep(end) - t_ep(1);
N_ep      = numel(x_ep);

% =========================================================================
% 3. Bandpass each component
% =========================================================================
comps = zeros(nBands, N_ep);

for b = 1:nBands
    flo  = bands(b, 1);
    fhi  = bands(b, 2);
    ord  = bands(b, 3);

    if flo == 0
        % Low-pass
        filt = designfilt('lowpassiir', ...
            'FilterOrder',        ord, ...
            'HalfPowerFrequency', fhi, ...
            'SampleRate',         fs);
    else
        filt = designfilt('bandpassiir', ...
            'FilterOrder',         ord, ...
            'HalfPowerFrequency1', flo, ...
            'HalfPowerFrequency2', fhi, ...
            'SampleRate',          fs);
    end

    comps(b,:) = filtfilt(filt, double(x_ep));
end

x_sum = sum(comps, 1);

% =========================================================================
% 4. Layout
% =========================================================================
nRows  = nBands + 1;        % component rows + sum row
rowH   = min(0.11, 0.78 / nRows);
rowGap = 0.012;
leftM  = 0.10;
axW    = 0.84;
botM   = 0.07;
topM   = 0.12;               % space for title

totalH  = nRows * rowH + (nRows-1) * rowGap;
figH    = max(480, min(980, nRows * 110 + 140));

fig = figure('Color', CLR.bg, ...
             'Units', 'pixels', ...
             'Position', [100 80 1200 figH]);

% =========================================================================
% 5. Draw axes
% =========================================================================
for k = 1:nRows

    rowIdx = nRows - k;      % 0 = bottom row
    yPos   = botM + rowIdx * (rowH + rowGap);

    isBottomRow = (k == nRows);

    ax = axes('Parent', fig, ...
              'Position',  [leftM yPos axW rowH], ...
              'Color',     'none', ...
              'XColor',    CLR.dimtext, ...
              'YColor',    CLR.dimtext, ...
              'XGrid',     'off', ...
              'YGrid',     'off', ...
              'FontName',  'IBM Plex Sans', ...
              'FontSize',  8, ...
              'TickDir',   'out', ...
              'XTick',     [], ...
              'YTick',     [], ...
              'Box',       'off');
    hold(ax, 'on');

    xlim(ax, [t_ep(1) t_ep(end)]);

    % X ticks and label only on bottom (Sum) row
    if isBottomRow
        set(ax, 'XTickMode', 'auto');
    end

    if k <= nBands
        % ---- Component row
        lc = compColours(k,:);
        plot(ax, t_ep, comps(k,:), 'Color', lc, 'LineWidth', 1.4);

        yAbs = max(abs(comps(k,:)));
        if yAbs > 0
            ylim(ax, [-yAbs*1.6  yAbs*1.6]);
        end

        text(ax, -0.01, 0.5, bandLabels{k}, ...
            'Units',               'normalized', ...
            'HorizontalAlignment', 'right', ...
            'VerticalAlignment',   'middle', ...
            'Color',               lc, ...
            'FontName',            'IBM Plex Sans', ...
            'FontSize',            8);

    else
        % ---- Sum row
        plot(ax, t_ep, x_ep,   'Color', [CLR.orig 0.22], 'LineWidth', 0.9);
        plot(ax, t_ep, x_sum,  'Color', CLR.sum_clr,     'LineWidth', 2.0);

        yAbs = max(abs(x_ep)) * 1.35;
        ylim(ax, [-yAbs  yAbs]);

        text(ax, -0.01, 0.5, 'Sum', ...
            'Units',               'normalized', ...
            'HorizontalAlignment', 'right', ...
            'VerticalAlignment',   'middle', ...
            'Color',               CLR.sum_clr, ...
            'FontName',            'IBM Plex Sans', ...
            'FontSize',            9, ...
            'FontWeight',          'bold');

        legend(ax, {'Original', 'Band sum'}, ...
            'TextColor', CLR.dimtext, ...
            'Color',     CLR.bg, ...
            'EdgeColor', CLR.dimtext, ...
            'FontSize',  7, ...
            'Location',  'northeast');
    end

    % X-axis label only on bottom (Sum) row
    if isBottomRow
        xlabel(ax, 'Time (s)', ...
            'Color',    CLR.text, ...
            'FontName', 'IBM Plex Sans', ...
            'FontSize', 10);
    end
end

% =========================================================================
% 6. Title + subtitle annotations
% =========================================================================
annotation(fig, 'textbox', [leftM 0.935 axW 0.05], ...
    'String',             opts.figTitle, ...
    'Color',              CLR.text, ...
    'FontName',           'IBM Plex Sans', ...
    'FontSize',           13, ...
    'FontWeight',         'bold', ...
    'EdgeColor',          'none', ...
    'HorizontalAlignment','center');

if isnan(opts.chanIdx)
    subStr = sprintf('Epoch %.2f – %.2f s  |  fs = %d Hz', t0, t1, fs);
else
    subStr = sprintf('Channel %d  |  Epoch %.2f – %.2f s  |  fs = %d Hz', ...
                     opts.chanIdx, t0, t1, fs);
end

annotation(fig, 'textbox', [leftM 0.905 axW 0.04], ...
    'String',             subStr, ...
    'Color',              CLR.dimtext, ...
    'FontName',           'IBM Plex Sans', ...
    'FontSize',           8, ...
    'EdgeColor',          'none', ...
    'HorizontalAlignment','center');

% =========================================================================
% 7. Optional export — PNG + PDF (vector)
% =========================================================================
if ~isempty(opts.exportPath)
    % PNG (raster)
    exportgraphics(fig, opts.exportPath, ...
        'Resolution',      opts.exportDPI, ...
        'BackgroundColor', CLR.bg);
    fprintf('Saved PNG : %s\n', opts.exportPath);

    % PDF (vector) — same base name, .pdf extension
    [folder, stem, ~] = fileparts(opts.exportPath);
    pdfPath = fullfile(folder, [stem '.pdf']);
    exportgraphics(fig, pdfPath, ...
        'ContentType',     'vector', ...
        'BackgroundColor', CLR.bg);
    fprintf('Saved PDF : %s\n', pdfPath);
end

end % main function


% =========================================================================
% LOCAL HELPER
% =========================================================================
function [t0, t1, x_ep, t_ep] = autoEpoch(x1, tVec, epochSamp)
% Pick the highest-variance non-overlapping epoch of length epochSamp.
    N      = numel(x1);
    nSteps = floor(N / epochSamp);
    varVec = zeros(1, nSteps);
    for k = 1:nSteps
        seg = x1((k-1)*epochSamp+1 : k*epochSamp);
        varVec(k) = var(seg);
    end
    [~, best] = max(varVec);
    idx0  = (best-1)*epochSamp + 1;
    idx1  = idx0 + epochSamp - 1;
    x_ep  = x1(idx0:idx1);
    t_ep  = tVec(idx0:idx1) - tVec(idx0);
    t0    = tVec(idx0);
    t1    = tVec(idx1);
end
